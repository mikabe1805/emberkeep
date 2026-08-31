import 'package:flutter_test/flutter_test.dart';

import '../tool/production_social_smoke.dart';

void main() {
  test('production smoke uses the generated-only v6 room contract', () {
    const uid = 'temporary-owner';
    final room = productionSmokeRoomFields(uid);

    expect(room['v'], 6);
    expect(room['ownerKey'], productionSmokeOwnerKey(uid));
    expect(room, isNot(contains('uid')));
    expect(room['profileVisible'], isFalse);
    expect(room['displayName'], isEmpty);
    expect(room['about'], isEmpty);
    expect(room['cardOrder'], isEmpty);
    expect(room['profilePhotoPath'], isEmpty);
    expect(room['seasonPhotoPath'], isEmpty);
  });

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
          label: 'room and owner anchor',
          action: () async {
            attempted.add('room and owner anchor');
          },
        ),
        (
          label: 'owner identity',
          action: () async {
            attempted.add('owner identity');
          },
        ),
      ]);

      expect(attempted, ['photo', 'room and owner anchor', 'owner identity']);
      expect(failures, hasLength(1));
      expect(failures.single, contains('photo'));
      expect(failures.single, contains('simulated deletion failure'));
    },
  );
}
