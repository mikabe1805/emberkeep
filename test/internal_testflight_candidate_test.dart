import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('internal TestFlight receipt excludes App Store screenshot evidence', () {
    final verifier = File(
      'tool/verify_internal_testflight_candidate.dart',
    ).readAsStringSync();
    final metadataVerifier = File(
      'tool/verify_store_submission.dart',
    ).readAsStringSync();

    expect(
      verifier,
      contains('release-evidence/internal-testflight/\$version/'),
    );
    expect(verifier, contains('internal_testflight_device_evidence'));
    expect(verifier, contains('sourceRevision'));
    expect(verifier, contains('internal-candidate-retry-1'));
    expect(verifier, contains("const ['rev-parse', 'HEAD^']"));
    expect(verifier, contains("'--name-only'"));
    expect(verifier, contains('receipt commit may change only'));
    expect(verifier, contains('CM_TAG'));
    expect(verifier, contains('--ios-testflight'));
    expect(verifier, isNot(contains('store-assets/screenshots/app-store')));
    expect(verifier, isNot(contains('_appStoreScreenshotManifest')));

    expect(metadataVerifier, contains('if (!testFlightOnly)'));
    expect(
      metadataVerifier,
      contains(
        'final screenshots and their strict receipt are deliberately excluded',
      ),
    );
    expect(
      metadataVerifier,
      contains('App Store screenshot readiness is not claimed'),
    );
  });

  test(
    'internal receipt statically locks the signed native widget identity',
    () {
      final verifier = File(
        'tool/verify_internal_testflight_candidate.dart',
      ).readAsStringSync();

      for (final expected in const [
        'com.mikabe.emberkeep',
        'com.mikabe.emberkeep.DayLedgerWidget',
        'group.com.mikabe.emberkeep',
        'RoomOfDaysWidgets.appex in Embed App Extensions',
        r'$(MARKETING_VERSION)',
        r'$(CURRENT_PROJECT_VERSION)',
        'com.apple.widgetkit-extension',
      ]) {
        expect(verifier, contains(expected));
      }
    },
  );
}
