import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

const _listingPath = '../STORE-LISTING.md';

const _appStoreScreenshots = <String>[
  '01-quests-1290x2796.png',
  '02-reward-1290x2796.png',
  '03-my-space-1290x2796.png',
  '04-change-space-1290x2796.png',
  '05-journal-1290x2796.png',
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

Future<void> main() async {
  try {
    if (!File('pubspec.yaml').existsSync()) {
      throw StateError('Run this command from the app repository root.');
    }
    final listingFile = File(_listingPath).absolute;
    if (!listingFile.existsSync()) {
      throw StateError('Missing store listing: ${listingFile.path}');
    }
    final listing = await listingFile.readAsString();

    _section('Character-limited store fields');
    _checkField(listing, 'App name', 30);
    _checkField(listing, 'Apple subtitle (30 characters)', 30);
    _checkField(listing, 'Apple promotional text (170 characters max)', 170);
    _checkField(listing, 'Apple keywords (100 characters max)', 100);
    _checkField(
      listing,
      'Google Play short description (80 characters max)',
      80,
    );

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
      'web/delete-account.html',
      'web/support.html',
    ]) {
      if (!File(path).existsSync()) throw StateError('Missing $path.');
    }
    final pubspec = await File('pubspec.yaml').readAsString();
    final pubspecVersion = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);
    final candidate =
        jsonDecode(await File('release-candidate.json').readAsString())
            as Map<String, dynamic>;
    final candidateVersion =
        '${candidate['versionName']}+'
        '${candidate['versionCode']}';
    if (pubspecVersion != candidateVersion) {
      throw StateError(
        'pubspec version $pubspecVersion differs from candidate '
        '$candidateVersion.',
      );
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
      'deletion worksheet',
      normalizedListing,
      'verified requests are normally completed within seven days',
    );
    _expectContains(
      'photo disclosure',
      normalizedListing,
      'journal photos local and does not upload them',
    );
    _pass('public URLs, local pages, disclosures, and $candidateVersion agree');

    _section('Submission artwork');
    _verifyRgbPng('web/icons/Icon-1024.png', 1024, 1024);
    _verifyRgbPng('web/icons/Icon-512.png', 512, 512);
    _verifyRgbPng(
      'store-assets/google-play-feature-graphic-1024x500.png',
      1024,
      500,
    );
    _verifyScreenshotDirectory(
      'store-assets/screenshots/app-store',
      _appStoreScreenshots,
      1290,
      2796,
    );
    _verifyScreenshotDirectory(
      'store-assets/screenshots/google-play',
      _playScreenshots,
      1080,
      1920,
    );
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
      'The sequence is the same in both folders:',
    );
    for (final item in const [
      '1. Quests',
      '2. Reward',
      '3. My Space',
      '4. Change Space',
      '5. Journal',
    ]) {
      _expectContains('screenshot README', screenshotReadme, item);
    }
    _pass(
      'icons, feature graphic, and both five-image screenshot sets are RGB',
    );

    stdout.writeln();
    stdout.writeln('PASS: store submission packet is internally consistent.');
  } catch (error, stackTrace) {
    stderr.writeln('Store submission verification failed: $error');
    if (Platform.environment['ROOM_OF_DAYS_VERIFY_TRACE'] == '1') {
      stderr.writeln(stackTrace);
    }
    exitCode = 1;
  }
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
