import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String path) => File(path).readAsStringSync();

void main() {
  test('room-photo source remains private until separate sharing consent', () {
    final photo = _source('lib/room_photo.dart');
    final storage = _source('lib/storage.dart');
    final engine = _source('lib/engine.dart');

    expect(photo, contains("storageKey = 'emberkeep_private_room_photo_v1'"));
    expect(photo, contains('never a gallery path or an image URL'));
    expect(storage, isNot(contains('emberkeep_private_room_photo_v1')));
    expect(engine, contains('bool shareRoomPhoto = false;'));
    expect(engine, contains('void setRoomPhotoSharing(bool enabled)'));
    expect(
      engine,
      contains(
        'void clearSharedRoomPhotoProjection({bool disableSharing = false})',
      ),
    );
  });
  test('reset and account deletion confirm room-photo erasure', () {
    final shell = _source('lib/screens/shell.dart');

    expect(shell, contains('RoomPhotoStore.instance.clearAll()'));
    expect(shell, contains('clearPendingRoomPhotoIntent()'));
    expect(
      shell,
      contains("'Couldn’t confirm that private photos were erased."),
    );
  });

  test(
    'owner activation is epoch-fenced and imports do not touch room photos',
    () {
      final shell = _source('lib/screens/shell.dart');

      expect(shell, contains('int _roomPhotoOwnerEpoch = 0;'));
      expect(shell, contains('_syncRoomPhotoOwner(++_roomPhotoOwnerEpoch)'));
      expect(shell, contains('epoch != _roomPhotoOwnerEpoch'));
      expect(shell, contains('CloudSync.instance.socialUid != null'));
      expect(shell, contains("rememberedOwner.startsWith('device:')"));
      expect(shell, contains('store.ownerKey == rememberedOwner'));
      expect(shell, contains('mounted &&'));
      expect(shell, contains('unawaited(_refreshRoomPhotoOwner())'));

      final importStart = shell.indexOf(
        'Future<bool> _import(String raw) async',
      );
      final importEnd = shell.indexOf(
        'static List<Quest> _buildQuests()',
        importStart,
      );
      final import = shell.substring(importStart, importEnd);
      expect(import, contains('Storage.importRaw(raw)'));
      expect(import, isNot(contains('RoomPhotoStore')));
      expect(import, isNot(contains('clearAll')));
    },
  );
}
