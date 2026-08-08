import 'package:flutter_test/flutter_test.dart';

import '../tool/production_social_smoke.dart';

void main() {
  test(
    'production cleanup attempts every resource after an earlier failure',
    () async {
      final attempted = <String>[];

      final failures = await runCleanupActions([
        (
          label: 'photo',
          action: () async {
            attempted.add('photo');
            throw StateError('simulated deletion failure');
          },
        ),
        (
          label: 'room',
          action: () async {
            attempted.add('room');
          },
        ),
        (
          label: 'owner identity',
          action: () async {
            attempted.add('owner identity');
          },
        ),
      ]);

      expect(attempted, ['photo', 'room', 'owner identity']);
      expect(failures, hasLength(1));
      expect(failures.single, contains('photo'));
      expect(failures.single, contains('simulated deletion failure'));
    },
  );
}
