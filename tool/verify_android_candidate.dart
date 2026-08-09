import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

const _defaultManifest = 'release-candidate.json';

Future<void> main(List<String> arguments) async {
  try {
    final options = _Options.parse(arguments);
    if (options.help) {
      stdout.writeln(_usage);
      return;
    }
    await _verify(options);
  } catch (error, stackTrace) {
    stderr.writeln('Android candidate verification failed: $error');
    if (Platform.environment['ROOM_OF_DAYS_VERIFY_TRACE'] == '1') {
      stderr.writeln(stackTrace);
    }
    exitCode = 1;
  }
}

Future<void> _verify(_Options options) async {
  final manifestFile = File(options.manifestPath).absolute;
  if (!manifestFile.existsSync()) {
    throw StateError('Missing candidate manifest: ${manifestFile.path}');
  }
  final root = manifestFile.parent;
  final candidate = _Candidate.fromJson(
    jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>,
    root,
    bundletoolOverride: options.bundletoolPath,
  );

  _requireFile(candidate.aab, 'AAB');
  _requireFile(candidate.apk, 'APK');
  _requireFile(candidate.bundletool, 'bundletool');
  _requireFile(candidate.handoff, 'artifact handoff');

  final sdk = Directory(
    options.androidSdkPath ?? _findAndroidSdk(root),
  ).absolute;
  if (!sdk.existsSync()) {
    throw StateError('Android SDK not found at ${sdk.path}.');
  }
  final tools = _AndroidTools.discover(sdk, candidate.ndkVersion);

  _section('Immutable files');
  final aabHash = await _sha256(candidate.aab);
  final apkHash = await _sha256(candidate.apk);
  _expectEqual('AAB SHA-256', aabHash, candidate.aabSha256);
  _expectEqual('APK SHA-256', apkHash, candidate.apkSha256);
  final sourceObjectType = await _runOutput('candidate source commit', 'git', [
    'cat-file',
    '-t',
    candidate.sourceCommit,
  ]);
  _expectEqual('candidate source object', sourceObjectType.trim(), 'commit');
  final handoff = await candidate.handoff.readAsString();
  for (final expected in [
    candidate.sourceCommit,
    candidate.aabSha256,
    candidate.apkSha256,
    'room-of-days-${candidate.versionName}+${candidate.versionCode}-android.aab',
    'room-of-days-${candidate.versionName}+${candidate.versionCode}-android.apk',
  ]) {
    _expectContains('artifact handoff', handoff, expected);
  }
  _pass('AAB SHA-256 $aabHash');
  _pass('APK SHA-256 $apkHash');
  _pass('source commit ${candidate.sourceCommit.substring(0, 7)} and handoff');

  _section('APK identity and policy');
  final applicationId = await _runOutput(
    'APK application ID',
    tools.apkanalyzer,
    ['manifest', 'application-id', candidate.apk.path],
  );
  final versionCode = await _runOutput('APK version code', tools.apkanalyzer, [
    'manifest',
    'version-code',
    candidate.apk.path,
  ]);
  final versionName = await _runOutput('APK version name', tools.apkanalyzer, [
    'manifest',
    'version-name',
    candidate.apk.path,
  ]);
  final minSdk = await _runOutput('APK minimum SDK', tools.apkanalyzer, [
    'manifest',
    'min-sdk',
    candidate.apk.path,
  ]);
  final targetSdk = await _runOutput('APK target SDK', tools.apkanalyzer, [
    'manifest',
    'target-sdk',
    candidate.apk.path,
  ]);
  _expectEqual('application ID', applicationId.trim(), candidate.packageId);
  _expectEqual('version code', versionCode.trim(), '${candidate.versionCode}');
  _expectEqual('version name', versionName.trim(), candidate.versionName);
  _expectEqual('minimum SDK', minSdk.trim(), '${candidate.minSdk}');
  _expectEqual('target SDK', targetSdk.trim(), '${candidate.targetSdk}');
  _pass(
    '${candidate.packageId} ${candidate.versionName}+${candidate.versionCode} '
    '(API ${candidate.minSdk}-${candidate.targetSdk})',
  );

  final permissionOutput = await _runOutput(
    'APK permissions',
    tools.apkanalyzer,
    ['manifest', 'permissions', candidate.apk.path],
  );
  final actualPermissions = permissionOutput
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toSet();
  _expectSetsEqual('permissions', actualPermissions, candidate.permissions);
  _pass('${actualPermissions.length} expected permissions and no extras');

  final apkManifest = await _runOutput('APK manifest', tools.apkanalyzer, [
    'manifest',
    'print',
    candidate.apk.path,
  ]);
  _expectContains(
    'app-link host',
    apkManifest,
    'android:host="${candidate.appLinkHost}"',
  );
  for (final path in candidate.exactPaths) {
    _expectContains(
      'exact app-link path $path',
      apkManifest,
      'android:path="$path"',
    );
  }
  for (final prefix in candidate.pathPrefixes) {
    _expectContains(
      'app-link prefix $prefix',
      apkManifest,
      'android:pathPrefix="$prefix"',
    );
  }
  if (apkManifest.contains('android:host="www.${candidate.appLinkHost}"')) {
    throw StateError('APK unexpectedly claims www.${candidate.appLinkHost}.');
  }
  for (final prefix in candidate.pathPrefixes) {
    final broadPrefix = prefix.substring(0, prefix.length - 1);
    final broadPattern = RegExp(
      'android:pathPrefix="${RegExp.escape(broadPrefix)}"\\s*/>',
    );
    if (broadPattern.hasMatch(apkManifest)) {
      throw StateError('APK claims the over-broad prefix $broadPrefix.');
    }
  }
  _pass('exact /space and /room app-link scope');

  _section('Signing and packaging');
  final apkSigning = await _runOutput('APK signature', tools.apksigner, [
    'verify',
    '--verbose',
    '--print-certs',
    candidate.apk.path,
  ]);
  _expectContains('APK verifies', apkSigning, 'Verifies');
  _expectContains(
    'APK v2 signature',
    apkSigning,
    'Verified using v2 scheme (APK Signature Scheme v2): true',
  );
  _expectContains('single APK signer', apkSigning, 'Number of signers: 1');
  final apkCertificate = RegExp(
    r'Signer #1 certificate SHA-256 digest:\s*([0-9a-fA-F:]+)',
  ).firstMatch(apkSigning)?.group(1);
  if (apkCertificate == null) {
    throw StateError('Could not read the APK signer certificate digest.');
  }
  _expectEqual(
    'APK signer certificate',
    _normalizedHex(apkCertificate),
    _normalizedHex(candidate.certificateSha256),
  );
  await _runOutput('APK 16 KiB ZIP alignment', tools.zipalign, [
    '-c',
    '-P',
    '16',
    '4',
    candidate.apk.path,
  ]);
  _pass('one expected APK signer and 16 KiB ZIP alignment');

  await _runOutput('AAB validation', 'java', [
    '-jar',
    candidate.bundletool.path,
    'validate',
    '--bundle=${candidate.aab.path}',
  ]);
  final bundleConfig = await _runOutput('AAB configuration', 'java', [
    '-jar',
    candidate.bundletool.path,
    'dump',
    'config',
    '--bundle=${candidate.aab.path}',
  ]);
  _expectContains(
    'bundletool version',
    bundleConfig,
    '"version": "${candidate.bundletoolVersion}"',
  );
  _expectContains(
    'AAB native alignment',
    bundleConfig,
    '"alignment": "PAGE_ALIGNMENT_16K"',
  );
  final aabManifest = await _runOutput('AAB manifest', 'java', [
    '-jar',
    candidate.bundletool.path,
    'dump',
    'manifest',
    '--bundle=${candidate.aab.path}',
    '--module=base',
  ]);
  _expectContains(
    'AAB package',
    aabManifest,
    'package="${candidate.packageId}"',
  );
  _expectContains(
    'AAB version code',
    aabManifest,
    'android:versionCode="${candidate.versionCode}"',
  );
  _expectContains(
    'AAB version name',
    aabManifest,
    'android:versionName="${candidate.versionName}"',
  );
  _expectContains(
    'AAB minimum SDK',
    aabManifest,
    'android:minSdkVersion="${candidate.minSdk}"',
  );
  _expectContains(
    'AAB target SDK',
    aabManifest,
    'android:targetSdkVersion="${candidate.targetSdk}"',
  );
  await _runOutput('AAB JAR signature', 'jarsigner', [
    '-verify',
    candidate.aab.path,
  ]);
  final aabCertificateOutput = await _runOutput(
    'AAB signer certificate',
    'keytool',
    ['-printcert', '-jarfile', candidate.aab.path],
  );
  final aabCertificate = RegExp(
    r'SHA256:\s*([0-9a-fA-F:]+)',
  ).firstMatch(aabCertificateOutput)?.group(1);
  if (aabCertificate == null) {
    throw StateError('Could not read the AAB signer certificate digest.');
  }
  _expectEqual(
    'AAB signer certificate',
    _normalizedHex(aabCertificate),
    _normalizedHex(candidate.certificateSha256),
  );
  _pass(
    'bundletool ${candidate.bundletoolVersion}, PAGE_ALIGNMENT_16K, and '
    'the expected AAB signer',
  );

  _section('Native libraries');
  final nativeSummary = await _verifyNativeLibraries(candidate, tools.readelf);
  _expectEqual(
    'native library count',
    '${nativeSummary.libraryCount}',
    '${candidate.nativeLibraryCount}',
  );
  _expectSetsEqual('native ABIs', nativeSummary.abis, candidate.abis);
  _pass(
    '${nativeSummary.libraryCount} libraries across '
    '${nativeSummary.abis.join(', ')}; minimum LOAD alignment '
    '${nativeSummary.minimumAlignment} bytes',
  );

  stdout.writeln();
  stdout.writeln(
    'PASS: Android release candidate ${candidate.versionName}+'
    '${candidate.versionCode} matches release-candidate.json.',
  );
}

Future<_NativeSummary> _verifyNativeLibraries(
  _Candidate candidate,
  String readelf,
) async {
  final archive = ZipDecoder().decodeBytes(
    await candidate.apk.readAsBytes(),
    verify: true,
  );
  final nativePattern = RegExp(r'^lib/([^/]+)/[^/]+\.so$');
  final nativeFiles =
      archive.files
          .where((file) => file.isFile && nativePattern.hasMatch(file.name))
          .toList()
        ..sort((left, right) => left.name.compareTo(right.name));
  if (nativeFiles.isEmpty) {
    throw StateError('APK contains no native libraries.');
  }

  final temporary = await Directory.systemTemp.createTemp(
    'room-of-days-android-verify-',
  );
  var overallMinimum = 1 << 62;
  final abis = <String>{};
  try {
    for (final entry in nativeFiles) {
      final match = nativePattern.firstMatch(entry.name)!;
      abis.add(match.group(1)!);
      final extracted = File(
        '${temporary.path}${Platform.pathSeparator}'
        '${entry.name.replaceAll('/', '_')}',
      );
      await extracted.writeAsBytes(entry.content, flush: true);
      final output = await _runOutput(
        'ELF headers for ${entry.name}',
        readelf,
        ['--program-headers', '--wide', extracted.path],
      );
      final alignments = <int>[];
      for (final line in output.split(RegExp(r'\r?\n'))) {
        if (!RegExp(r'^\s*LOAD\s').hasMatch(line)) continue;
        final token = line.trim().split(RegExp(r'\s+')).last;
        if (!token.startsWith('0x')) {
          throw StateError('Unexpected LOAD alignment in ${entry.name}: $line');
        }
        alignments.add(int.parse(token.substring(2), radix: 16));
      }
      if (alignments.isEmpty) {
        throw StateError('No LOAD segments found in ${entry.name}.');
      }
      final minimum = alignments.reduce((a, b) => a < b ? a : b);
      if (minimum < candidate.nativeLoadAlignment) {
        throw StateError(
          '${entry.name} has $minimum-byte LOAD alignment; expected at least '
          '${candidate.nativeLoadAlignment}.',
        );
      }
      if (minimum < overallMinimum) overallMinimum = minimum;
    }
  } finally {
    if (temporary.existsSync()) {
      await temporary.delete(recursive: true);
    }
  }
  return _NativeSummary(
    libraryCount: nativeFiles.length,
    abis: abis,
    minimumAlignment: overallMinimum,
  );
}

Future<String> _runOutput(
  String label,
  String executable,
  List<String> arguments,
) async {
  final result = await Process.run(
    executable,
    arguments,
    runInShell:
        Platform.isWindows &&
        (executable.toLowerCase().endsWith('.bat') ||
            !executable.contains(Platform.pathSeparator)),
    stdoutEncoding: systemEncoding,
    stderrEncoding: systemEncoding,
  );
  if (result.exitCode != 0) {
    final output = '${result.stdout}\n${result.stderr}'.trim();
    throw StateError(
      '$label exited ${result.exitCode}${output.isEmpty ? '' : ': $output'}',
    );
  }
  return '${result.stdout}';
}

Future<String> _sha256(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString().toUpperCase();
}

String _findAndroidSdk(Directory root) {
  for (final key in const ['ANDROID_SDK_ROOT', 'ANDROID_HOME']) {
    final value = Platform.environment[key];
    if (value != null && value.trim().isNotEmpty) return value.trim();
  }
  final properties = File(
    '${root.path}${Platform.pathSeparator}android'
    '${Platform.pathSeparator}local.properties',
  );
  if (properties.existsSync()) {
    for (final line in properties.readAsLinesSync()) {
      if (!line.startsWith('sdk.dir=')) continue;
      return _decodePropertiesPath(line.substring('sdk.dir='.length));
    }
  }
  throw StateError(
    'Set ANDROID_SDK_ROOT or provide --android-sdk. '
    'android/local.properties did not contain sdk.dir.',
  );
}

String _decodePropertiesPath(String value) => value
    .replaceAll(r'\:', ':')
    .replaceAll(r'\\', Platform.pathSeparator)
    .replaceAll('/', Platform.pathSeparator);

void _requireFile(File file, String label) {
  if (!file.existsSync()) {
    throw StateError('$label not found: ${file.path}');
  }
}

void _expectEqual(String label, String actual, String expected) {
  if (actual != expected) {
    throw StateError('$label is "$actual"; expected "$expected".');
  }
}

void _expectContains(String label, String source, String expected) {
  if (!source.contains(expected)) {
    throw StateError('$label is missing "$expected".');
  }
}

void _expectSetsEqual(String label, Set<String> actual, Set<String> expected) {
  final missing = expected.difference(actual).toList()..sort();
  final extra = actual.difference(expected).toList()..sort();
  if (missing.isNotEmpty || extra.isNotEmpty) {
    throw StateError(
      '$label differ. Missing: ${missing.isEmpty ? 'none' : missing.join(', ')}; '
      'extra: ${extra.isEmpty ? 'none' : extra.join(', ')}.',
    );
  }
}

String _normalizedHex(String value) =>
    value.replaceAll(RegExp('[^0-9a-fA-F]'), '').toUpperCase();

void _section(String label) {
  stdout.writeln();
  stdout.writeln(label);
}

void _pass(String message) => stdout.writeln('  PASS  $message');

final class _AndroidTools {
  const _AndroidTools({
    required this.apkanalyzer,
    required this.apksigner,
    required this.zipalign,
    required this.readelf,
  });

  final String apkanalyzer;
  final String apksigner;
  final String zipalign;
  final String readelf;

  static _AndroidTools discover(Directory sdk, String ndkVersion) {
    final buildToolsRoot = Directory(
      '${sdk.path}${Platform.pathSeparator}build-tools',
    );
    final buildToolDirectories =
        buildToolsRoot.listSync().whereType<Directory>().where((directory) {
          return File(
                '${directory.path}${Platform.pathSeparator}'
                '${Platform.isWindows ? 'apksigner.bat' : 'apksigner'}',
              ).existsSync() &&
              File(
                '${directory.path}${Platform.pathSeparator}'
                '${Platform.isWindows ? 'zipalign.exe' : 'zipalign'}',
              ).existsSync();
        }).toList()..sort((left, right) {
          return _compareVersions(_basename(left.path), _basename(right.path));
        });
    if (buildToolDirectories.isEmpty) {
      throw StateError('No complete Android build-tools installation found.');
    }
    final buildTools = buildToolDirectories.last;

    final analyzerCandidates = <File>[
      File(
        '${sdk.path}${Platform.pathSeparator}cmdline-tools'
        '${Platform.pathSeparator}latest${Platform.pathSeparator}bin'
        '${Platform.pathSeparator}'
        '${Platform.isWindows ? 'apkanalyzer.bat' : 'apkanalyzer'}',
      ),
    ];
    final commandLineTools = Directory(
      '${sdk.path}${Platform.pathSeparator}cmdline-tools',
    );
    if (commandLineTools.existsSync()) {
      final directories =
          commandLineTools.listSync().whereType<Directory>().toList()
            ..sort((left, right) => right.path.compareTo(left.path));
      analyzerCandidates.addAll(
        directories.map(
          (directory) => File(
            '${directory.path}${Platform.pathSeparator}bin'
            '${Platform.pathSeparator}'
            '${Platform.isWindows ? 'apkanalyzer.bat' : 'apkanalyzer'}',
          ),
        ),
      );
    }
    final analyzer = analyzerCandidates
        .where((file) => file.existsSync())
        .firstOrNull;
    if (analyzer == null) {
      throw StateError('apkanalyzer was not found in Android cmdline-tools.');
    }

    final prebuiltRoot = Directory(
      '${sdk.path}${Platform.pathSeparator}ndk${Platform.pathSeparator}'
      '$ndkVersion${Platform.pathSeparator}toolchains'
      '${Platform.pathSeparator}llvm${Platform.pathSeparator}prebuilt',
    );
    if (!prebuiltRoot.existsSync()) {
      throw StateError('NDK $ndkVersion is not installed.');
    }
    File? readelf;
    for (final directory in prebuiltRoot.listSync().whereType<Directory>()) {
      final candidate = File(
        '${directory.path}${Platform.pathSeparator}bin'
        '${Platform.pathSeparator}'
        '${Platform.isWindows ? 'llvm-readelf.exe' : 'llvm-readelf'}',
      );
      if (candidate.existsSync()) {
        readelf = candidate;
        break;
      }
    }
    if (readelf == null) {
      throw StateError('llvm-readelf was not found in NDK $ndkVersion.');
    }

    return _AndroidTools(
      apkanalyzer: analyzer.path,
      apksigner:
          '${buildTools.path}${Platform.pathSeparator}'
          '${Platform.isWindows ? 'apksigner.bat' : 'apksigner'}',
      zipalign:
          '${buildTools.path}${Platform.pathSeparator}'
          '${Platform.isWindows ? 'zipalign.exe' : 'zipalign'}',
      readelf: readelf.path,
    );
  }
}

final class _Candidate {
  const _Candidate({
    required this.packageId,
    required this.versionName,
    required this.versionCode,
    required this.sourceCommit,
    required this.handoff,
    required this.minSdk,
    required this.targetSdk,
    required this.ndkVersion,
    required this.nativeLoadAlignment,
    required this.nativeLibraryCount,
    required this.abis,
    required this.certificateSha256,
    required this.aab,
    required this.aabSha256,
    required this.apk,
    required this.apkSha256,
    required this.bundletool,
    required this.bundletoolVersion,
    required this.permissions,
    required this.appLinkHost,
    required this.exactPaths,
    required this.pathPrefixes,
  });

  final String packageId;
  final String versionName;
  final int versionCode;
  final String sourceCommit;
  final File handoff;
  final int minSdk;
  final int targetSdk;
  final String ndkVersion;
  final int nativeLoadAlignment;
  final int nativeLibraryCount;
  final Set<String> abis;
  final String certificateSha256;
  final File aab;
  final String aabSha256;
  final File apk;
  final String apkSha256;
  final File bundletool;
  final String bundletoolVersion;
  final Set<String> permissions;
  final String appLinkHost;
  final List<String> exactPaths;
  final List<String> pathPrefixes;

  factory _Candidate.fromJson(
    Map<String, dynamic> json,
    Directory root, {
    String? bundletoolOverride,
  }) {
    if (json['schema'] != 1) {
      throw FormatException('Unsupported release candidate schema.');
    }
    final aab = Map<String, dynamic>.from(json['aab'] as Map);
    final apk = Map<String, dynamic>.from(json['apk'] as Map);
    final bundletool = Map<String, dynamic>.from(json['bundletool'] as Map);
    final links = Map<String, dynamic>.from(json['appLinks'] as Map);
    return _Candidate(
      packageId: json['packageId'] as String,
      versionName: json['versionName'] as String,
      versionCode: json['versionCode'] as int,
      sourceCommit: json['sourceCommit'] as String,
      handoff: File(_resolve(root, json['handoffPath'] as String)),
      minSdk: json['minSdk'] as int,
      targetSdk: json['targetSdk'] as int,
      ndkVersion: json['ndkVersion'] as String,
      nativeLoadAlignment: json['nativeLoadAlignment'] as int,
      nativeLibraryCount: json['nativeLibraryCount'] as int,
      abis: (json['abis'] as List).cast<String>().toSet(),
      certificateSha256: json['certificateSha256'] as String,
      aab: File(_resolve(root, aab['path'] as String)),
      aabSha256: aab['sha256'] as String,
      apk: File(_resolve(root, apk['path'] as String)),
      apkSha256: apk['sha256'] as String,
      bundletool: File(
        bundletoolOverride == null
            ? _resolve(root, bundletool['path'] as String)
            : File(bundletoolOverride).absolute.path,
      ),
      bundletoolVersion: bundletool['version'] as String,
      permissions: (json['permissions'] as List).cast<String>().toSet(),
      appLinkHost: links['host'] as String,
      exactPaths: (links['exactPaths'] as List).cast<String>(),
      pathPrefixes: (links['pathPrefixes'] as List).cast<String>(),
    );
  }
}

final class _NativeSummary {
  const _NativeSummary({
    required this.libraryCount,
    required this.abis,
    required this.minimumAlignment,
  });

  final int libraryCount;
  final Set<String> abis;
  final int minimumAlignment;
}

final class _Options {
  const _Options({
    required this.manifestPath,
    required this.androidSdkPath,
    required this.bundletoolPath,
    required this.help,
  });

  final String manifestPath;
  final String? androidSdkPath;
  final String? bundletoolPath;
  final bool help;

  factory _Options.parse(List<String> arguments) {
    var manifestPath = _defaultManifest;
    String? androidSdkPath;
    String? bundletoolPath;
    var help = false;
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      String nextValue() {
        if (index + 1 >= arguments.length) {
          throw FormatException('$argument requires a value.');
        }
        return arguments[++index];
      }

      switch (argument) {
        case '--manifest':
          manifestPath = nextValue();
        case '--android-sdk':
          androidSdkPath = nextValue();
        case '--bundletool':
          bundletoolPath = nextValue();
        case '--help':
        case '-h':
          help = true;
        default:
          throw FormatException('Unknown argument: $argument');
      }
    }
    return _Options(
      manifestPath: manifestPath,
      androidSdkPath: androidSdkPath,
      bundletoolPath: bundletoolPath,
      help: help,
    );
  }
}

String _resolve(Directory root, String path) {
  final normalized = path.replaceAll('/', Platform.pathSeparator);
  final isAbsolute = Platform.isWindows
      ? RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(normalized) ||
            normalized.startsWith(r'\\')
      : normalized.startsWith('/');
  return (isAbsolute
          ? File(normalized)
          : File('${root.path}${Platform.pathSeparator}$normalized'))
      .absolute
      .path;
}

String _basename(String path) =>
    path.split(RegExp(r'[\\/]')).where((part) => part.isNotEmpty).last;

int _compareVersions(String left, String right) {
  final leftParts = left
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .toList();
  final rightParts = right
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .toList();
  final length = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;
  for (var index = 0; index < length; index++) {
    final a = index < leftParts.length ? leftParts[index] : 0;
    final b = index < rightParts.length ? rightParts[index] : 0;
    if (a != b) return a.compareTo(b);
  }
  return 0;
}

const _usage = '''
Verify the immutable Room of Days Android release candidate.

Usage:
  dart run tool/verify_android_candidate.dart [options]

Options:
  --manifest <path>      Candidate manifest (default: release-candidate.json)
  --android-sdk <path>   Override ANDROID_SDK_ROOT/local.properties
  --bundletool <path>    Override the bundletool JAR from the manifest
  -h, --help             Show this help
''';
