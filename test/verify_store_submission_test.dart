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
      expect(verifier, contains("final listingFile = File(_listingName)"));
      expect(verifier, isNot(contains('_findAncestorFile')));
      expect(
        verifier,
        contains('_verifyCurrentInAppReleaseNotes(pubspecVersion)'),
      );
      expect(verifier, contains('if (!iosOnly) {'));
      expect(verifier, contains("'03-plans-1290x2796.png'"));
      expect(verifier, contains("'06-journal-1290x2796.png'"));
      expect(verifier, contains("'07-discover-1290x2796.png'"));
      expect(
        verifier,
        contains('App Store icon and seven-image screenshot set are RGB'),
      );
    },
  );
}
