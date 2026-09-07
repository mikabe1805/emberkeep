param([string]$OutputDirectory = 'output/sharing-backend-verification')

$ErrorActionPreference = 'Stop'
$sharingProject = 'emberkeep-5b33b'
$sharingBucket = "$sharingProject.firebasestorage.app"
$sharingRegion = 'us-central1'
$sharingRoot = Split-Path -Parent $PSScriptRoot
$sharingFunctions = @(
  'setDiscoveryPublicName', 'reportDiscoverableSpace', 'publishSpaceProfile',
  'setCircleRelationship', 'setSpaceBlock', 'cleanupDeletedSpace',
  'cleanupReplacedPublicRoomPhoto'
)

function Get-SourceHash([string]$Text) {
  $hasher = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text.Replace("`r`n", "`n"))
    return ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally { $hasher.Dispose() }
}

function Read-GoogleResource([string]$Uri) {
  return Invoke-RestMethod -Uri $Uri -Headers $sharingHeaders
}

function Test-DeployedRules([string]$ReleaseName, [string]$LocalFile) {
  $release = Read-GoogleResource "https://firebaserules.googleapis.com/v1/$ReleaseName"
  $ruleset = Read-GoogleResource "https://firebaserules.googleapis.com/v1/$($release.rulesetName)"
  $files = @($ruleset.source.files)
  if ($files.Count -ne 1) { throw "Unexpected rules source count for $ReleaseName" }
  $localHash = Get-SourceHash ([IO.File]::ReadAllText((Join-Path $sharingRoot $LocalFile)))
  $deployedHash = Get-SourceHash $files[0].content
  if ($localHash -ne $deployedHash) { throw "Deployed $LocalFile differs from this source. Deploy and verify the matching backend before release." }
  return [ordered]@{release=$release.name; ruleset=$release.rulesetName; updatedAt=$release.updateTime; sha256=$deployedHash}
}

# This is read-only against Google Cloud. Authentication stays in memory.
# The receipt contains no credentials or environment-variable values. Downloaded
# source archives can contain deployment configuration: keep them local in the
# ignored output directory and never commit or publish them.
& npm --prefix (Join-Path $sharingRoot 'functions') run build
if ($LASTEXITCODE -ne 0) { throw 'Current Functions source did not compile.' }
$sharingToken = (& gcloud auth print-access-token 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or -not $sharingToken) { throw 'Sign in to the configured Google Cloud account first.' }
$sharingHeaders = @{Authorization="Bearer $sharingToken"; 'x-goog-user-project'=$sharingProject}
$sharingOutput = if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $sharingRoot $OutputDirectory }
New-Item -ItemType Directory -Force -Path $sharingOutput | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem

try {
  $firestoreProof = Test-DeployedRules "projects/$sharingProject/releases/cloud.firestore" 'firestore.rules'
  $storageProof = Test-DeployedRules "projects/$sharingProject/releases/firebase.storage/$sharingBucket" 'storage.rules'
  $bucket = Read-GoogleResource "https://firebasestorage.googleapis.com/v1alpha/projects/$sharingProject/defaultBucket"
  if ($bucket.bucket.name -ne "projects/$sharingProject/buckets/$sharingBucket") { throw 'The deployed default bucket differs from the app configuration.' }
  $storageRulesAgent = 'serviceAccount:service-8350777780@gcp-sa-firebasestorage.iam.gserviceaccount.com'
  $storageRulesRole = 'roles/firebaserules.firestoreServiceAgent'
  $policy = Invoke-RestMethod -Uri "https://cloudresourcemanager.googleapis.com/v1/projects/${sharingProject}:getIamPolicy" -Method Post -Headers $sharingHeaders -ContentType 'application/json' -Body '{"options":{"requestedPolicyVersion":3}}'
  $storageRulesGrant = @($policy.bindings | Where-Object { $_.role -eq $storageRulesRole -and $_.members -contains $storageRulesAgent -and -not $_.condition })
  if ($storageRulesGrant.Count -ne 1) { throw 'Storage rules cannot verify their Firestore ownership and live-photo pointers without the scoped cross-service role.' }

  $runtimeRoot = Join-Path $sharingRoot 'functions/lib'
  $runtimeFiles = @(Get-ChildItem -LiteralPath $runtimeRoot -File -Recurse -Filter '*.js' | Where-Object { $_.Name -notmatch '\.test\.js$' })
  if ($runtimeFiles.Count -eq 0) { throw 'Build the Functions source before checking the deployed implementation.' }
  $functionProofs = @()
  foreach ($functionName in $sharingFunctions) {
    $function = Read-GoogleResource "https://cloudfunctions.googleapis.com/v2/projects/$sharingProject/locations/$sharingRegion/functions/$functionName"
    if ($function.state -ne 'ACTIVE' -or $function.buildConfig.runtime -ne 'nodejs22') { throw "$functionName is not active on the expected runtime." }
    if ($functionName -notlike 'cleanup*' -and $function.serviceConfig.environmentVariables.DISCOVERY_ENFORCE_APP_CHECK -ne 'true') { throw "$functionName must enforce App Check." }
    if ($functionName -eq 'setDiscoveryPublicName' -and $function.serviceConfig.environmentVariables.DISCOVERY_PUBLIC_NAMES_ENABLED -ne 'true') { throw 'Public name moderation must be enabled for the released client.' }

    $source = $function.buildConfig.source.storageSource
    if (-not $source.bucket -or -not $source.object -or -not $source.generation) { throw "$functionName has no immutable source archive identity." }
    $archivePath = Join-Path $sharingOutput "$functionName-source.zip"
    $sourceUri = "https://storage.googleapis.com/storage/v1/b/$([Uri]::EscapeDataString($source.bucket))/o/$([Uri]::EscapeDataString($source.object))?alt=media&generation=$($source.generation)"
    Invoke-WebRequest -UseBasicParsing -Uri $sourceUri -Headers $sharingHeaders -OutFile $archivePath
    $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
      $sourceProof = [ordered]@{}
      foreach ($runtimeFile in $runtimeFiles) {
        $relative = $runtimeFile.FullName.Substring($runtimeRoot.Length + 1).Replace('\', '/')
        $entry = $archive.GetEntry("lib/$relative")
        if ($null -eq $entry) { throw "$functionName is missing lib/$relative in its deployed archive." }
        $reader = New-Object IO.StreamReader($entry.Open())
        try { $deployedText = $reader.ReadToEnd() } finally { $reader.Dispose() }
        $localHash = Get-SourceHash ([IO.File]::ReadAllText($runtimeFile.FullName))
        $deployedHash = Get-SourceHash $deployedText
        if ($localHash -ne $deployedHash) { throw "$functionName has stale deployed lib/$relative." }
        $sourceProof["lib/$relative"] = $deployedHash
      }
      $functionProofs += [ordered]@{name=$functionName; state=$function.state; updatedAt=$function.updateTime; sourceBucket=$source.bucket; sourceObject=$source.object; sourceGeneration=$source.generation; runtimeSources=$sourceProof}
    } finally { $archive.Dispose() }
    Write-Output "PASS: $functionName matches current compiled sharing sources."
  }
  $receipt = [ordered]@{verifiedAt=[DateTime]::UtcNow.ToString('o'); project=$sharingProject; firestore=$firestoreProof; storage=$storageProof; bucket=$bucket.bucket.name; storageRulesIam=@{member=$storageRulesAgent;role=$storageRulesRole}; functions=$functionProofs}
  $receipt | ConvertTo-Json -Depth 9 | Set-Content -LiteralPath (Join-Path $sharingOutput 'LIVE-BACKEND-RECEIPT.json') -Encoding UTF8
  Write-Output 'PASS: live Firestore and Storage rules, default bucket, App Check settings, and seven sharing functions match this release.'
} catch {
  Write-Error $_ -ErrorAction Continue
  exit 1
} finally {
  Remove-Variable sharingToken,sharingHeaders -ErrorAction SilentlyContinue
}
