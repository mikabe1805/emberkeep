import 'package:emberkeep/cloud.dart';
import 'package:flutter_test/flutter_test.dart';

const _ownerKey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _code = 'ABC234';
const _oldPath = 'shared_rooms/$_ownerKey/$_code/room/ABCDEFGHIJKLMNOPQRSTUV';
const _newPath = 'shared_rooms/$_ownerKey/$_code/room/VWXYZabcdefghijklmnopq';

Map<String, dynamic> _photo({
  required String path,
  bool fill = true,
  double x = -0.5,
  double y = 0.25,
  int width = 1200,
  int height = 800,
}) => {
  'v': 8,
  'ownerKey': _ownerKey,
  'roomPhotoPath': path,
  'roomPhotoFill': fill,
  'roomPhotoX': x,
  'roomPhotoY': y,
  'roomPhotoWidth': width,
  'roomPhotoHeight': height,
};

void main() {
  group('queued room photo refresh', () {
    test('drops a stale incoming photo when the live room is blank', () {
      final result = mergeQueuedRoomPhotoProjection(
        incoming: {
          ..._photo(path: _oldPath),
          'weather': 'rain',
        },
        live: _photo(path: '', fill: false, x: 0, y: 0, width: 1, height: 1),
        ownerKey: _ownerKey,
        roomCode: _code,
      );

      expect(result, isNotNull);
      expect(result!['weather'], 'rain');
      expect(result['roomPhotoPath'], '');
      expect(result['roomPhotoFill'], isFalse);
      expect(result['roomPhotoX'], 0.0);
      expect(result['roomPhotoY'], 0.0);
      expect(result['roomPhotoWidth'], 1);
      expect(result['roomPhotoHeight'], 1);
    });

    test('adopts the live newer photo projection', () {
      final result = mergeQueuedRoomPhotoProjection(
        incoming: _photo(path: _oldPath),
        live: _photo(
          path: _newPath,
          fill: false,
          x: 0.75,
          y: -0.25,
          width: 640,
          height: 480,
        ),
        ownerKey: _ownerKey,
        roomCode: _code,
      );

      expect(result, isNotNull);
      expect(result!['roomPhotoPath'], _newPath);
      expect(result['roomPhotoFill'], isFalse);
      expect(result['roomPhotoX'], 0.75);
      expect(result['roomPhotoY'], -0.25);
      expect(result['roomPhotoWidth'], 640);
      expect(result['roomPhotoHeight'], 480);
    });

    test('blanks stale incoming room media for a v7 live room', () {
      final result = mergeQueuedRoomPhotoProjection(
        incoming: _photo(path: _oldPath),
        live: {'v': 7, 'ownerKey': _ownerKey},
        ownerKey: _ownerKey,
        roomCode: _code,
      );

      expect(result, isNotNull);
      expect(result!['roomPhotoPath'], '');
      expect(result['roomPhotoFill'], isFalse);
      expect(result['roomPhotoX'], 0.0);
      expect(result['roomPhotoY'], 0.0);
      expect(result['roomPhotoWidth'], 1);
      expect(result['roomPhotoHeight'], 1);
    });
  });
}
