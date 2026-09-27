import 'dart:convert';
import 'dart:io';

const _purpose = 'internal_testflight_device_evidence';
const _appBundleId = 'com.mikabe.emberkeep';
const _widgetBundleId = 'com.mikabe.emberkeep.DayLedgerWidget';
const _appGroupId = 'group.com.mikabe.emberkeep';

void main(List<String> arguments) {
  try {
    if (arguments.isNotEmpty) {
      throw ArgumentError(
        'Usage: dart run tool/verify_internal_testflight_candidate.dart',
      );
    }
    if (!File('pubspec.yaml').existsSync()) {
      throw StateError('Run this command from the app repository root.');
    }

    final version = _pubspecVersion();
    final versionMatch = RegExp(
      r'^(\d+\.\d+\.\d+)\+(\d+)$',
    ).firstMatch(version);
    if (versionMatch == null) {
      throw StateError('pubspec version $version is not version+build.');
    }
    final expectedTag =
        'room-of-days-${versionMatch.group(1)}-build-'
        '${versionMatch.group(2)}-internal-candidate';
    final receiptPath =
        'release-evidence/internal-testflight/$version/'
        'CANDIDATE-MANIFEST.json';
    final receiptFile = File(receiptPath);
    if (!receiptFile.existsSync()) {
      throw StateError('Missing internal TestFlight receipt: $receiptPath.');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(receiptFile.readAsStringSync());
    } on FormatException catch (error) {
      throw StateError('Invalid internal TestFlight receipt JSON: $error');
    }
    if (decoded is! Map<String, dynamic> || decoded['schema'] != 1) {
      throw StateError('Internal TestFlight receipt schema must be 1.');
    }
    if (decoded['purpose'] != _purpose) {
      throw StateError(
        'Internal TestFlight receipt purpose must be $_purpose.',
      );
    }
    final candidate = decoded['candidate'];
    if (candidate is! Map<String, dynamic>) {
      throw StateError(
        'Internal TestFlight receipt is missing candidate metadata.',
      );
    }
    if (candidate['version'] != version) {
      throw StateError(
        'Internal TestFlight receipt version ${candidate['version']} differs '
        'from pubspec $version.',
      );
    }
    if (candidate['tag'] != expectedTag) {
      throw StateError(
        'Internal TestFlight receipt tag ${candidate['tag']} differs from '
        '$expectedTag.',
      );
    }
    final sourceRevision = candidate['sourceRevision'];
    if (sourceRevision is! String ||
        !RegExp(r'^[0-9a-f]{40}$').hasMatch(sourceRevision)) {
      throw StateError(
        'Internal TestFlight sourceRevision must be a 40-character lowercase '
        'Git commit SHA.',
      );
    }

    final receiptRevision = _gitOutput(const ['rev-parse', 'HEAD']);
    final candidateRevision = _gitOutput(const ['rev-parse', 'HEAD^']);
    if (sourceRevision != candidateRevision) {
      throw StateError(
        'Internal TestFlight sourceRevision $sourceRevision differs from the '
        'immediate parent candidate revision $candidateRevision.',
      );
    }
    final dirtyPaths = _gitOutput(const ['status', '--porcelain']);
    if (dirtyPaths.isNotEmpty) {
      throw StateError(
        'Internal TestFlight receipt requires a clean Git checkout.',
      );
    }
    final receiptPaths = _gitLines([
      'diff',
      '--name-only',
      '$candidateRevision..$receiptRevision',
    ]);
    if (receiptPaths.length != 1 || receiptPaths.single != receiptPath) {
      throw StateError(
        'The internal TestFlight receipt commit may change only $receiptPath; '
        'changed ${receiptPaths.isEmpty ? 'no paths' : receiptPaths.join(', ')}.',
      );
    }
    final ciTag = Platform.environment['CM_TAG']?.trim();
    if (ciTag != null && ciTag.isNotEmpty && ciTag != expectedTag) {
      throw StateError('CM_TAG $ciTag differs from receipt tag $expectedTag.');
    }

    _verifyNativeWidgetContract(versionMatch.group(1)!, versionMatch.group(2)!);
    _runMetadataVerifier();

    stdout.writeln();
    stdout.writeln(
      'PASS: internal TestFlight receipt $receiptRevision binds $version to '
      '$candidateRevision for $expectedTag; App Store screenshots are outside '
      'this receipt.',
    );
  } catch (error, stackTrace) {
    stderr.writeln('Internal TestFlight verification failed: $error');
    if (Platform.environment['ROOM_OF_DAYS_VERIFY_TRACE'] == '1') {
      stderr.writeln(stackTrace);
    }
    exitCode = 1;
  }
}

String _pubspecVersion() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final match = RegExp(
    r'^version:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(pubspec);
  if (match == null) throw StateError('pubspec.yaml is missing a version.');
  return match.group(1)!;
}

void _verifyNativeWidgetContract(String versionName, String buildNumber) {
  final project = File(
    'ios/Runner.xcodeproj/project.pbxproj',
  ).readAsStringSync();
  final runnerEntitlements = File(
    'ios/Runner/Runner.entitlements',
  ).readAsStringSync();
  final widgetEntitlements = File(
    'ios/RoomOfDaysWidgets/RoomOfDaysWidgets.entitlements',
  ).readAsStringSync();
  final widgetInfo = File(
    'ios/RoomOfDaysWidgets/Info.plist',
  ).readAsStringSync();
  final widgetSource = File(
    'ios/RoomOfDaysWidgets/RoomOfDaysWidgets.swift',
  ).readAsStringSync();

  for (final source in [runnerEntitlements, widgetEntitlements, widgetSource]) {
    if (!source.contains(_appGroupId)) {
      throw StateError(
        'Native widget source is missing App Group $_appGroupId.',
      );
    }
  }
  for (final expected in [
    'PRODUCT_BUNDLE_IDENTIFIER = $_appBundleId;',
    'PRODUCT_BUNDLE_IDENTIFIER = $_widgetBundleId;',
    'RoomOfDaysWidgets.appex in Embed App Extensions',
    'CURRENT_PROJECT_VERSION = $buildNumber;',
    'MARKETING_VERSION = $versionName;',
  ]) {
    if (!project.contains(expected)) {
      throw StateError('Xcode project is missing "$expected".');
    }
  }
  for (final expected in [
    r'<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>',
    r'<string>$(EXECUTABLE_NAME)</string>',
    r'<string>$(MARKETING_VERSION)</string>',
    r'<string>$(CURRENT_PROJECT_VERSION)</string>',
    '<string>XPC!</string>',
    '<string>com.apple.widgetkit-extension</string>',
  ]) {
    if (!widgetInfo.contains(expected)) {
      throw StateError('Widget Info.plist is missing "$expected".');
    }
  }
}

void _runMetadataVerifier() {
  final result = Process.runSync(Platform.resolvedExecutable, const [
    'run',
    'tool/verify_store_submission.dart',
    '--ios-testflight',
  ]);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    throw StateError('Internal TestFlight metadata verification failed.');
  }
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
