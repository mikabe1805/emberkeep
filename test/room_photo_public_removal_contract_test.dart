import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('whole-room removal revokes the public room before byte cleanup', () {
    final cloud = File('lib/cloud.dart').readAsStringSync();
    final deletion = cloud.substring(
      cloud.indexOf('Future<_OwnedRoomDeleteResult> _deleteOwnedRoom'),
      cloud.indexOf('Future<void> _deleteRoomPrivateChildren'),
    );

    expect(deletion, contains('await _deleteRoomPrivateChildren(room)'));
    expect(deletion, contains('..delete(room)'));
    expect(deletion, isNot(contains('deleteObjectPaths(')));
    expect(cloud, contains('trigger owns public room-photo byte cleanup'));
  });

  test('Start over does not complete ahead of public-room revocation', () {
    final shell = File('lib/screens/shell.dart').readAsStringSync();
    final reset = shell.substring(
      shell.indexOf('Future<String?> _reset() async'),
      shell.indexOf('Future<bool> _finishResetRemoteCleanup'),
    );

    final revoke = reset.indexOf(
      'if (!await _finishResetRemoteCleanup(oldRoomCode))',
    );
    final localErase = reset.indexOf('RoomPhotoStore.instance.clearAll()');
    final visibleFreshRoom = reset.indexOf('setState(() {');

    expect(revoke, greaterThanOrEqualTo(0));
    expect(localErase, greaterThan(revoke));
    expect(visibleFreshRoom, greaterThan(localErase));
    expect(reset, isNot(contains('unawaited(_finishResetRemoteCleanup')));
  });
}
