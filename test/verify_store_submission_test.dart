import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'iOS-only verifier keeps Apple checks separate from frozen Android evidence',
    () {
      final verifier = File(
        'tool/verify_store_submission.dart',
      ).readAsStringSync();

      expect(verifier, contains("arguments.single == '--ios-only'"));
      expect(verifier, contains("arguments.single == '--ios-testflight'"));
      expect(verifier, contains('_VerificationMode.iosTestFlight'));
      expect(verifier, contains('if (!testFlightOnly)'));
      expect(verifier, contains("final listingFile = File(_listingName)"));
      expect(verifier, isNot(contains('_findAncestorFile')));
      expect(
        verifier,
        contains('_verifyCurrentInAppReleaseNotes(pubspecVersion)'),
      );
      expect(
        verifier,
        contains('_verifyListingWhatsNewIdentity(listing, pubspecVersion)'),
      );
      expect(verifier, contains('final expectedHeading'));
      expect(verifier, contains('versionMatch.group(2)'));
      expect(verifier, contains('CANDIDATE-MANIFEST.json'));
      expect(
        verifier,
        contains('_verifyAppStoreScreenshotManifest(pubspecVersion)'),
      );
      expect(verifier, contains('sourceRevision'));
      expect(verifier, contains('sha256'));
      expect(verifier, contains("const ['rev-parse', 'HEAD^']"));
      expect(verifier, contains("'diff',"));
      expect(verifier, contains("'--name-only',"));
      expect(verifier, contains('_appStoreScreenshotManifest; changed'));
      expect(verifier, contains("const ['status', '--porcelain']"));
      expect(verifier, contains('if (!iosOnly) {'));
      expect(verifier, contains("'03-goals-1290x2796.png'"));
      expect(verifier, contains("'05-recovery-1290x2796.png'"));
      expect(verifier, contains("'10-discover-1290x2796.png'"));
      expect(verifier, contains("'3. Goals'"));
      expect(verifier, contains("'4. Workshop'"));
      expect(verifier, contains("'5. Recovery'"));
      expect(verifier, contains("'6. Plans'"));
      expect(verifier, contains("'10. Discover'"));
      expect(
        verifier,
        contains('App Store icon and ten-image screenshot set are RGB'),
      );
    },
  );
}
