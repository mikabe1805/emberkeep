import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

const _listingName = 'STORE-LISTING.md';
const _appStoreScreenshotManifest =
    'store-assets/screenshots/app-store/CANDIDATE-MANIFEST.json';

const _appStoreScreenshots = <String>[
  '01-quests-1290x2796.png',
  '02-reward-1290x2796.png',
  '03-goals-1290x2796.png',
  '04-workshop-1290x2796.png',
  '05-recovery-1290x2796.png',
  '06-plans-1290x2796.png',
  '07-my-space-1290x2796.png',
  '08-change-space-1290x2796.png',
  '09-journal-1290x2796.png',
  '10-discover-1290x2796.png',
];

const _playScreenshots = <String>[
  '01-quests-1080x1920.png',
  '02-reward-1080x1920.png',
  '03-my-space-1080x1920.png',
  '04-change-space-1080x1920.png',
  '05-journal-1080x1920.png',
];

const _legacyScreenshots = <String>[
  'store-assets/screenshots/01-quests-1290x2796.png',
  'store-assets/screenshots/02-reward-1290x2796.png',
  'store-assets/screenshots/03-tapestry-room-1290x2796.png',
  'store-assets/screenshots/04-shop-1290x2796.png',
  'store-assets/screenshots/05-insights-1290x2796.png',
];

Future<void> main(List<String> arguments) async {
  try {
    final mode = _parseMode(arguments);
    final iosOnly = mode != _VerificationMode.full;
    final testFlightOnly = mode == _VerificationMode.iosTestFlight;
    if (!File('pubspec.yaml').existsSync()) {
      throw StateError('Run this command from the app repository root.');
    }
    final listingFile = File(_listingName);
    if (!listingFile.existsSync()) {
      throw StateError(
        'Missing the versioned App Store submission source: $_listingName.',
      );
    }
    final listing = await listingFile.readAsString();

    _section('Character-limited store fields');
    _checkField(listing, 'App name', 30);
    _checkField(listing, 'Apple subtitle (30 characters)', 30);
    _checkField(listing, 'Apple promotional text (170 characters max)', 170);
    _checkField(listing, 'Apple keywords (100 characters max)', 100);
    if (!iosOnly) {
      _checkField(
        listing,
        'Google Play short description (80 characters max)',
        80,
      );
    }

    final fullDescription = _markdownSection(listing, 'Full description');
    final testFlightDescription = _markdownSection(
      listing,
      'TestFlight description',
    );
    _expectLength('Full description', fullDescription.trim(), 4000);
    _expectLength('TestFlight description', testFlightDescription.trim(), 4000);
    _pass(
      'full description ${fullDescription.trim().runes.length}/4000; '
      'TestFlight ${testFlightDescription.trim().runes.length}/4000',
    );

    _section('Truthful URLs and release identity');
    const expectedUrls = <String, String>{
      'Privacy policy': 'https://roomofdays.com/privacy',
      'Account deletion': 'https://roomofdays.com/delete-account',
      'Support URL': 'https://roomofdays.com/support',
      'Marketing URL': 'https://roomofdays.com/',
    };
    for (final entry in expectedUrls.entries) {
      final actual = _field(listing, entry.key);
      if (actual != entry.value) {
        throw StateError(
          '${entry.key} is "$actual"; expected "${entry.value}".',
        );
      }
    }
    for (final path in const [
      'web/privacy.html',
      'web/terms.html',
      'web/community.html',
      'web/delete-account.html',
      'web/support.html',
      'ACCOUNT-RECOVERY-RUNBOOK.md',
    ]) {
      if (!File(path).existsSync()) throw StateError('Missing $path.');
    }
    final privacyCopy = (await File(
      'web/privacy.html',
    ).readAsString()).replaceAll(RegExp(r'\s+'), ' ');
    final communityCopy = (await File(
      'web/community.html',
    ).readAsString()).replaceAll(RegExp(r'\s+'), ' ');
    final recoveryRunbook = (await File(
      'ACCOUNT-RECOVERY-RUNBOOK.md',
    ).readAsString()).replaceAll(RegExp(r'\s+'), ' ');
    final applePrivacyManifest = await File(
      'ios/Runner/PrivacyInfo.xcprivacy',
    ).readAsString();
    final iosInfoPlist = await File('ios/Runner/Info.plist').readAsString();
    final pubspec = await File('pubspec.yaml').readAsString();
    final pubspecVersion = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);
    _verifyListingWhatsNewIdentity(listing, pubspecVersion);
    _verifyCurrentInAppReleaseNotes(pubspecVersion);
    Map<String, dynamic>? candidate;
    List<String>? candidatePermissions;
    String? candidateVersion;
    if (!iosOnly) {
      candidate =
          jsonDecode(await File('release-candidate.json').readAsString())
              as Map<String, dynamic>;
      candidatePermissions = (candidate['permissions'] as List<dynamic>)
          .cast<String>();
      candidateVersion =
          '${candidate['versionName']}+'
          '${candidate['versionCode']}';
      if (pubspecVersion != candidateVersion) {
        throw StateError(
          'pubspec version $pubspecVersion differs from candidate '
          '$candidateVersion.',
        );
      }
    }
    final normalizedFullDescription = fullDescription.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    final normalizedListing = listing.replaceAll(RegExp(r'\s+'), ' ');
    _expectContains(
      'full description',
      normalizedFullDescription,
      'Room of Days works without an account.',
    );
    _expectContains(
      'full description',
      normalizedFullDescription,
      'There are no ads, subscriptions, paywalls, or paid cosmetics.',
    );
    _expectContains(
      'health disclaimer',
      normalizedFullDescription,
      'It is not a medical device and does not diagnose, treat, cure, or prevent any medical condition.',
    );
    _expectContains(
      'professional-advice reminder',
      normalizedFullDescription,
      'Consult a qualified healthcare professional for medical advice, diagnosis, or treatment.',
    );
    _expectContains(
      'deletion worksheet',
      normalizedListing,
      'verified requests are normally completed within seven days',
    );
    _expectContains(
      'photo disclosure',
      normalizedListing,
      'journal photos local and does not upload them',
    );
    for (final expected in const [
      'Device tilt only controls visual depth and is not stored or uploaded.',
      'NSPrivacyCollectedDataTypeHealth',
    ]) {
      final source = expected == 'NSPrivacyCollectedDataTypeHealth'
          ? applePrivacyManifest
          : normalizedListing;
      _expectContains('health disclosure', source, expected);
    }
    if (!iosOnly) {
      for (final expected in const [
        'Google Play Health apps declaration',
        "My app doesn't provide any health features",
        'Activity and Fitness',
        'Nutrition and Weight Management',
        'Sleep Management',
        'Stress Management, Relaxation, Mental Acuity',
        '| Health info | Yes | No | No | Optional | App functionality |',
        'Organization',
        'D-U-N-S number',
      ]) {
        _expectContains(
          'Google Play health disclosure',
          normalizedListing,
          expected,
        );
      }
    }
    for (final expected in const [
      'Apple App Store Connect completion key',
      'Content Rights:** **Yes',
      'SIL Open Font License',
      '2026 <legal rights holder>',
      'Digital Services Act (DSA) status',
      "My app doesn't provide any financial features",
      'non-purchasable, non-transferable progression counters',
      'Government apps:** No',
      'News and Magazine apps:** No',
      'COVID-19 contact tracing or status app:** No',
    ]) {
      _expectContains('console answer key', normalizedListing, expected);
    }
    if (!iosOnly) {
      for (final expected in const [
        'Google Play App content completion key',
        'All or some functionality is restricted',
        'dedicated, reusable review-only account',
        'Advertising ID:** No',
        'READ_MEDIA_IMAGES',
        'READ_MEDIA_VIDEO',
        'not a Social or Dating app',
      ]) {
        _expectContains(
          'Google Play console answer key',
          normalizedListing,
          expected,
        );
      }
    }
    for (final expected in const [
      'verified custom Auth email domain',
      'None may expose Emberkeep',
      'Never ask for or accept a current password',
      'the old password fails',
      "the new password signs in, and the account's cloud save is preserved",
    ]) {
      _expectContains('account recovery runbook', recoveryRunbook, expected);
    }
    if (!RegExp(
      r'<key>ITSAppUsesNonExemptEncryption</key>\s*<false\s*/>',
    ).hasMatch(iosInfoPlist)) {
      throw StateError(
        'iOS Info.plist must declare ITSAppUsesNonExemptEncryption=false.',
      );
    }
    if (!iosOnly) {
      for (final permission in const [
        'com.google.android.gms.permission.AD_ID',
        'android.permission.READ_MEDIA_IMAGES',
        'android.permission.READ_MEDIA_VIDEO',
        'android.permission.READ_EXTERNAL_STORAGE',
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.ACCESS_COARSE_LOCATION',
        'android.permission.READ_CONTACTS',
        'android.permission.SCHEDULE_EXACT_ALARM',
        'android.permission.USE_EXACT_ALARM',
        'android.permission.REQUEST_INSTALL_PACKAGES',
        'com.android.vending.BILLING',
      ]) {
        if (candidatePermissions!.contains(permission)) {
          throw StateError(
            'Store answer key says the candidate omits $permission, but the '
            'release permission inventory contains it.',
          );
        }
      }
    }
    for (final path in const [
      'ASSET-LICENSES.md',
      'assets/sfx/SOURCES.md',
      'assets/google_fonts/OFL-EBGaramond.txt',
      'assets/google_fonts/OFL-Fraunces.txt',
      'assets/google_fonts/OFL-Inter.txt',
      'assets/google_fonts/OFL-JetBrainsMono.txt',
    ]) {
      if (!File(path).existsSync()) {
        throw StateError('Missing third-party rights record: $path.');
      }
    }
    _expectContains(
      'public health disclosure',
      privacyCopy,
      'exercise, sleep, meals, medication, stress',
    );
    _expectContains(
      'public health disclaimer',
      privacyCopy,
      'does not diagnose, treat, cure, or prevent any medical condition',
    );
    for (final disclosure in const [
      'Block and report',
      'current and future public rooms',
      'reviews the report queue every day',
      'within 24 hours',
      'support@roomofdays.com',
    ]) {
      _expectContains('community safety page', communityCopy, disclosure);
    }
    _pass(
      'public URLs, local pages, privacy/health and console declarations, '
      '${iosOnly ? 'current in-app release notes' : 'candidate permissions'}, '
      'export status, licenses, and ${iosOnly ? pubspecVersion : candidateVersion} agree',
    );

    _section('Submission artwork');
    _verifyRgbPng('web/icons/Icon-1024.png', 1024, 1024);
    if (!testFlightOnly) {
      _verifyScreenshotDirectory(
        'store-assets/screenshots/app-store',
        _appStoreScreenshots,
        1290,
        2796,
      );
      _verifyAppStoreScreenshotManifest(pubspecVersion);
    }
    if (!iosOnly) {
      _verifyRgbPng('web/icons/Icon-512.png', 512, 512);
      _verifyRgbPng(
        'store-assets/google-play-feature-graphic-1024x500.png',
        1024,
        500,
      );
      _verifyScreenshotDirectory(
        'store-assets/screenshots/google-play',
        _playScreenshots,
        1080,
        1920,
      );
    }
    if (!testFlightOnly) {
      for (final path in _legacyScreenshots) {
        if (File(path).existsSync()) {
          throw StateError('Retired store screenshot still exists: $path');
        }
      }
      final screenshotReadme = await File(
        'store-assets/screenshots/README.md',
      ).readAsString();
      _expectContains(
        'screenshot README',
        screenshotReadme,
        'The App Store sequence is:',
      );
      for (final item in const [
        '1. Quests',
        '2. Reward',
        '3. Goals',
        '4. Workshop',
        '5. Recovery',
        '6. Plans',
        '7. My Space',
        '8. Change Space',
        '9. Journal',
        '10. Discover',
      ]) {
        _expectContains('screenshot README', screenshotReadme, item);
      }
      if (!iosOnly) {
        _expectContains(
          'screenshot README',
          screenshotReadme,
          'Google Play remains the earlier five-image core story',
        );
      }
    }
    _pass(
      testFlightOnly
          ? 'App Store icon is RGB; final screenshots and their strict receipt are deliberately excluded from the internal TestFlight candidate'
          : iosOnly
          ? 'App Store icon and ten-image screenshot set are RGB and candidate-bound'
          : 'icons, feature graphic, and both five-image screenshot sets are RGB',
    );

    stdout.writeln();
    stdout.writeln(
      testFlightOnly
          ? 'PASS: internal TestFlight metadata packet is internally consistent; App Store screenshot readiness is not claimed.'
          : 'PASS: store submission packet is internally consistent.',
    );
  } catch (error, stackTrace) {
    stderr.writeln('Store submission verification failed: $error');
    if (Platform.environment['ROOM_OF_DAYS_VERIFY_TRACE'] == '1') {
      stderr.writeln(stackTrace);
    }
    exitCode = 1;
  }
}

_VerificationMode _parseMode(List<String> arguments) {
  if (arguments.isEmpty) return _VerificationMode.full;
  if (arguments.length == 1 && arguments.single == '--ios-only') {
    return _VerificationMode.iosSubmission;
  }
  if (arguments.length == 1 && arguments.single == '--ios-testflight') {
    return _VerificationMode.iosTestFlight;
  }
  throw ArgumentError(
    'Usage: dart run tool/verify_store_submission.dart '
    '[--ios-only|--ios-testflight]',
  );
}

enum _VerificationMode { full, iosSubmission, iosTestFlight }

void _verifyCurrentInAppReleaseNotes(String? pubspecVersion) {
  if (pubspecVersion == null) {
    throw StateError('pubspec.yaml is missing a version.');
  }
  final releaseNotes = File('lib/content/release_notes.dart');
  if (!releaseNotes.existsSync()) {
    throw StateError('Missing lib/content/release_notes.dart.');
  }
  final source = releaseNotes.readAsStringSync();
  final match = RegExp(
    r"RoomReleaseNotes\(\s*id: '([^']+)',\s*versionLabel: '([^']+)'",
    dotAll: true,
  ).firstMatch(source);
  if (match == null) {
    throw StateError('Could not read the current in-app release notes.');
  }
  final noteVersion = match.group(1)!;
  if (noteVersion != pubspecVersion) {
    throw StateError(
      'pubspec version $pubspecVersion differs from current in-app release notes $noteVersion.',
    );
  }
  final versionMatch = RegExp(
    r'^(\d+\.\d+\.\d+)\+(\d+)$',
  ).firstMatch(pubspecVersion);
  if (versionMatch == null) {
    throw StateError('pubspec version $pubspecVersion is not version+build.');
  }
  final expectedLabel =
      'VERSION ${versionMatch.group(1)} · BUILD ${versionMatch.group(2)}';
  if (match.group(2) != expectedLabel) {
    throw StateError(
      'Current in-app release label is "${match.group(2)}"; expected "$expectedLabel".',
    );
  }
  _pass('pubspec $pubspecVersion matches current in-app release notes');
}

void _verifyListingWhatsNewIdentity(String listing, String? pubspecVersion) {
  if (pubspecVersion == null) {
    throw StateError('pubspec.yaml is missing a version.');
  }
  final versionMatch = RegExp(
    r'^(\d+\.\d+\.\d+)\+(\d+)$',
  ).firstMatch(pubspecVersion);
  if (versionMatch == null) {
    throw StateError('pubspec version $pubspecVersion is not version+build.');
  }
  final expectedHeading =
      '## App Store What\'s New — Version ${versionMatch.group(1)} '
      '(Build ${versionMatch.group(2)})';
  if (!listing.contains(expectedHeading)) {
    throw StateError(
      'Store listing must contain the exact current What\'s New heading: '
      '$expectedHeading.',
    );
  }
  _pass('store listing What\'s New heading matches pubspec $pubspecVersion');
}

void _verifyAppStoreScreenshotManifest(String? pubspecVersion) {
  if (pubspecVersion == null) {
    throw StateError('pubspec.yaml is missing a version.');
  }
  final manifestFile = File(_appStoreScreenshotManifest);
  if (!manifestFile.existsSync()) {
    throw StateError(
      'Missing App Store screenshot candidate manifest: '
      '$_appStoreScreenshotManifest.',
    );
  }

  final dynamic decoded;
  try {
    decoded = jsonDecode(manifestFile.readAsStringSync());
  } on FormatException catch (error) {
    throw StateError('Invalid screenshot candidate manifest JSON: $error');
  }
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Screenshot candidate manifest must be a JSON object.');
  }
  if (decoded['schema'] != 1) {
    throw StateError('Screenshot candidate manifest schema must be 1.');
  }
  final candidate = decoded['candidate'];
  if (candidate is! Map<String, dynamic>) {
    throw StateError(
      'Screenshot candidate manifest is missing candidate metadata.',
    );
  }
  if (candidate['version'] != pubspecVersion) {
    throw StateError(
      'Screenshot candidate manifest version ${candidate['version']} differs '
      'from pubspec $pubspecVersion.',
    );
  }
  final sourceRevision = candidate['sourceRevision'];
  if (sourceRevision is! String ||
      !RegExp(r'^[0-9a-f]{40}$').hasMatch(sourceRevision)) {
    throw StateError(
      'Screenshot candidate manifest sourceRevision must be a 40-character '
      'lowercase Git commit SHA.',
    );
  }
  final receiptRevision = _gitOutput(const ['rev-parse', 'HEAD']);
  final candidateRevision = _gitOutput(const ['rev-parse', 'HEAD^']);
  if (sourceRevision != candidateRevision) {
    throw StateError(
      'Screenshot candidate manifest sourceRevision $sourceRevision differs '
      'from the immediate parent candidate revision $candidateRevision.',
    );
  }
  final dirtyPaths = _gitOutput(const ['status', '--porcelain']);
  if (dirtyPaths.isNotEmpty) {
    throw StateError(
      'Screenshot candidate manifest receipt requires a clean Git checkout; found '
      'uncommitted changes.',
    );
  }
  final receiptPaths = _gitLines([
    'diff',
    '--name-only',
    '$candidateRevision..$receiptRevision',
  ]);
  if (receiptPaths.length != 1 ||
      receiptPaths.single != _appStoreScreenshotManifest) {
    throw StateError(
      'The manifest receipt commit may change only '
      '$_appStoreScreenshotManifest; changed '
      '${receiptPaths.isEmpty ? 'no paths' : receiptPaths.join(', ')}.',
    );
  }

  final screenshots = decoded['screenshots'];
  if (screenshots is! Map<String, dynamic>) {
    throw StateError('Screenshot candidate manifest is missing screenshots.');
  }
  final actualNames = screenshots.keys.cast<String>().toList()..sort();
  final expectedNames = [..._appStoreScreenshots]..sort();
  if (actualNames.join('\n') != expectedNames.join('\n')) {
    throw StateError(
      'Screenshot candidate manifest names ${actualNames.join(', ')}; expected '
      '${expectedNames.join(', ')}.',
    );
  }
  for (final name in _appStoreScreenshots) {
    final entry = screenshots[name];
    if (entry is! Map<String, dynamic>) {
      throw StateError(
        'Screenshot candidate manifest entry for $name is invalid.',
      );
    }
    final expectedHash = entry['sha256'];
    if (expectedHash is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(expectedHash)) {
      throw StateError(
        'Screenshot candidate manifest SHA-256 for $name must be 64 lowercase hex characters.',
      );
    }
    final actualHash = sha256
        .convert(
          File('store-assets/screenshots/app-store/$name').readAsBytesSync(),
        )
        .toString();
    if (actualHash != expectedHash) {
      throw StateError(
        'Screenshot candidate manifest SHA-256 for $name does not match the '
        'checked-in image.',
      );
    }
  }
  _pass(
    'App Store screenshot candidate manifest binds ${_appStoreScreenshots.length} '
    'images to $pubspecVersion at $candidateRevision; receipt $receiptRevision '
    'changes only the manifest',
  );
}

String _gitOutput(List<String> arguments) {
  final result = Process.runSync('git', arguments);
  if (result.exitCode != 0) {
    throw StateError(
      'Unable to read Git release identity: ${result.stderr.toString().trim()}',
    );
  }
  return result.stdout.toString().trim();
}

List<String> _gitLines(List<String> arguments) {
  final output = _gitOutput(arguments);
  return output.isEmpty ? const [] : output.split('\n');
}

void _checkField(String markdown, String label, int maximum) {
  final value = _field(markdown, label);
  _expectLength(label, value, maximum);
  _pass('$label ${value.runes.length}/$maximum');
}

String _field(String markdown, String label) {
  final match = RegExp(
    '^- \\*\\*${RegExp.escape(label)}:\\*\\*\\s*(.+)\\s*\$',
    multiLine: true,
  ).firstMatch(markdown);
  if (match == null) throw StateError('Missing store field: $label');
  return match.group(1)!.trim().replaceAll('`', '');
}

String _markdownSection(String markdown, String heading) {
  final marker = '## $heading';
  final start = markdown.indexOf(marker);
  if (start < 0) throw StateError('Missing section: $heading');
  final contentStart = markdown.indexOf('\n', start + marker.length);
  if (contentStart < 0) throw StateError('Section $heading has no content.');
  final end = markdown.indexOf('\n## ', contentStart + 1);
  return markdown.substring(contentStart + 1, end < 0 ? markdown.length : end);
}

void _expectLength(String label, String value, int maximum) {
  if (value.isEmpty) throw StateError('$label is empty.');
  final length = value.runes.length;
  if (length > maximum) {
    throw StateError('$label is $length characters; maximum is $maximum.');
  }
}

void _expectContains(String label, String source, String expected) {
  if (!source.contains(expected)) {
    throw StateError('$label is missing "$expected".');
  }
}

void _verifyScreenshotDirectory(
  String path,
  List<String> expectedNames,
  int width,
  int height,
) {
  final directory = Directory(path);
  if (!directory.existsSync()) throw StateError('Missing $path.');
  final actualNames =
      directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.png'))
          .map((file) => _basename(file.path))
          .toList()
        ..sort();
  final expected = [...expectedNames]..sort();
  if (actualNames.join('\n') != expected.join('\n')) {
    throw StateError(
      '$path contains ${actualNames.join(', ')}; expected ${expected.join(', ')}.',
    );
  }
  for (final name in expectedNames) {
    _verifyRgbPng('$path/$name', width, height);
  }
}

void _verifyRgbPng(String path, int width, int height) {
  final file = File(path);
  if (!file.existsSync()) throw StateError('Missing $path.');
  final bytes = file.readAsBytesSync();
  if (bytes.length < 26 || bytes[25] != 2) {
    throw StateError('$path is not a 24-bit truecolor RGB PNG.');
  }
  final decoded = img.decodePng(bytes);
  if (decoded == null) throw StateError('Could not decode $path.');
  if (decoded.width != width || decoded.height != height) {
    throw StateError(
      '$path is ${decoded.width}x${decoded.height}; expected ${width}x$height.',
    );
  }
  if (decoded.hasAlpha) throw StateError('$path unexpectedly has alpha.');
}

String _basename(String path) =>
    path.split(RegExp(r'[\\/]')).where((part) => part.isNotEmpty).last;

void _section(String label) {
  stdout.writeln();
  stdout.writeln(label);
}

void _pass(String message) => stdout.writeln('  PASS  $message');
