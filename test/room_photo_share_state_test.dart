import 'package:emberkeep/engine.dart';
import 'package:flutter_test/flutter_test.dart';

const _ownerKey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _roomPhotoPath =
    'shared_rooms/$_ownerKey/ABC234/room/ABCDEFGHIJKLMNOPQRSTUV';

void main() {
  group('shared room-photo state', () {
    test('old saves remain private by default', () {
      final encoded = GameState().toJson()
        ..remove('shareRoomPhoto')
        ..remove('spaceRoomPhotoPath')
        ..remove('spaceRoomPhotoFill')
        ..remove('spaceRoomPhotoX')
        ..remove('spaceRoomPhotoY')
        ..remove('spaceRoomPhotoWidth')
        ..remove('spaceRoomPhotoHeight');

      final restored = GameState.fromJson(encoded);

      expect(restored.shareRoomPhoto, isFalse);
      expect(restored.spaceRoomPhotoPath, isEmpty);
      expect(restored.spaceRoomPhotoFill, isFalse);
      expect(restored.spaceRoomPhotoX, 0);
      expect(restored.spaceRoomPhotoY, 0);
      expect(restored.spaceRoomPhotoWidth, 1);
      expect(restored.spaceRoomPhotoHeight, 1);
    });

    test(
      'round-trips deliberate consent and acknowledged presentation only',
      () {
        final state = GameState();
        state.setRoomPhotoSharing(true);
        state.setSharedRoomPhotoProjection(
          path: _roomPhotoPath,
          fillFrame: true,
          alignmentX: -0.5,
          alignmentY: 0.75,
          pixelWidth: 800,
          pixelHeight: 600,
        );

        final encoded = state.toJson();
        final restored = GameState.fromJson(encoded);

        expect(encoded['shareRoomPhoto'], isTrue);
        expect(encoded['spaceRoomPhotoPath'], _roomPhotoPath);
        expect(restored.shareRoomPhoto, isTrue);
        expect(restored.spaceRoomPhotoPath, state.spaceRoomPhotoPath);
        expect(restored.spaceRoomPhotoFill, isTrue);
        expect(restored.spaceRoomPhotoX, -0.5);
        expect(restored.spaceRoomPhotoY, 0.75);
        expect(restored.spaceRoomPhotoWidth, 800);
        expect(restored.spaceRoomPhotoHeight, 600);
      },
    );

    test(
      'malformed public projection is bounded and cannot retain metadata',
      () {
        final encoded = GameState().toJson()
          ..['shareRoomPhoto'] = 'yes'
          ..['spaceRoomPhotoPath'] =
              'shared_rooms/raw-uid/ABC234/room/ABCDEFGHIJKLMNOPQRSTUV'
          ..['spaceRoomPhotoFill'] = true
          ..['spaceRoomPhotoX'] = double.nan
          ..['spaceRoomPhotoY'] = 2.0
          ..['spaceRoomPhotoWidth'] = 0
          ..['spaceRoomPhotoHeight'] = 1201;

        final restored = GameState.fromJson(encoded);

        expect(restored.shareRoomPhoto, isFalse);
        expect(restored.spaceRoomPhotoPath, isEmpty);
        expect(restored.spaceRoomPhotoFill, isFalse);
        expect(restored.spaceRoomPhotoX, 0);
        expect(restored.spaceRoomPhotoY, 0);
        expect(restored.spaceRoomPhotoWidth, 1);
        expect(restored.spaceRoomPhotoHeight, 1);
      },
    );

    test('valid path defaults each invalid presentation field safely', () {
      final encoded = GameState().toJson()
        ..['spaceRoomPhotoPath'] = _roomPhotoPath
        ..['spaceRoomPhotoFill'] = true
        ..['spaceRoomPhotoX'] = -1.1
        ..['spaceRoomPhotoY'] = 1.0
        ..['spaceRoomPhotoWidth'] = 1200
        ..['spaceRoomPhotoHeight'] = -4;

      final restored = GameState.fromJson(encoded);

      expect(restored.spaceRoomPhotoPath, isNotEmpty);
      expect(restored.spaceRoomPhotoFill, isTrue);
      expect(restored.spaceRoomPhotoX, 0);
      expect(restored.spaceRoomPhotoY, 1);
      expect(restored.spaceRoomPhotoWidth, 1200);
      expect(restored.spaceRoomPhotoHeight, 1);
    });

    test(
      'profile photo disable leaves independent room-photo choice alone',
      () {
        final state = GameState();
        state.setRoomPhotoSharing(true);
        state.setSharedRoomPhotoProjection(
          path: _roomPhotoPath,
          fillFrame: false,
          alignmentX: 0,
          alignmentY: 0,
          pixelWidth: 800,
          pixelHeight: 600,
        );

        expect(state.disableVisitorPhotoSharing(), isFalse);
        expect(state.disableVisitorProfileSharing(), isFalse);
        expect(state.shareRoomPhoto, isTrue);
        expect(state.spaceRoomPhotoPath, isNotEmpty);
      },
    );

    test(
      'projection clears on room removal while explicit retry intent remains',
      () {
        final state = GameState()..roomCode = 'ABC234';
        state.setRoomPhotoSharing(true);
        state.setSharedRoomPhotoProjection(
          path: _roomPhotoPath,
          fillFrame: true,
          alignmentX: 0.4,
          alignmentY: -0.4,
          pixelWidth: 800,
          pixelHeight: 600,
        );

        state.setRoomCode(null);

        expect(state.shareRoomPhoto, isTrue);
        expect(state.spaceRoomPhotoPath, isEmpty);
        expect(state.spaceRoomPhotoFill, isFalse);
        expect(state.spaceRoomPhotoX, 0);
        expect(state.spaceRoomPhotoY, 0);
        expect(state.spaceRoomPhotoWidth, 1);
        expect(state.spaceRoomPhotoHeight, 1);

        state.clearSharedRoomPhotoProjection(disableSharing: true);
        expect(state.shareRoomPhoto, isFalse);
      },
    );
  });
}
