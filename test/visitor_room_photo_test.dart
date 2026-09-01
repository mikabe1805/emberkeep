import 'dart:typed_data';

import 'package:emberkeep/room_photo.dart';
import 'package:emberkeep/screens/visit_room.dart';
import 'package:emberkeep/shared_room_media.dart';
import 'package:emberkeep/widgets/home_room.dart';
import 'package:emberkeep/widgets/visitor_room_photo_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

late Uint8List _imageBytes;
late int _width;
late int _height;
const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _otherOwner =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _code = 'ABC234';

Map<String, dynamic> _room({String? path}) => {
  'wall': 'wall_walnut',
  'floor': 'floor_walnut',
  'window': 'moon',
  'ownerKey': _owner,
  'roomPhotoPath': path,
  'roomPhotoFill': true,
  'roomPhotoX': .25,
  'roomPhotoY': -.2,
  'roomPhotoWidth': _width,
  'roomPhotoHeight': _height,
};

Future<void> _pump(
  WidgetTester tester, {
  required Map<String, dynamic> room,
  RoomPhotoData? preview,
  VisitorRoomPhotoBytesLoader? loader,
  bool previewOnly = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: VisitRoomScreen(
        room: room,
        code: _code,
        lively: false,
        previewOnly: previewOnly,
        previewRoomPhoto: preview,
        roomPhotoBytesLoader: loader,
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Decoding uses the engine asynchronously. Let that work complete before
  // looking for the next frame; pumpAndSettle alone can observe no scheduled
  // frame while the codec is still resolving.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pumpAndSettle();
}

RoomPhotoData _localPhoto() => RoomPhotoData(
  bytes: Uint8List.fromList(_imageBytes),
  pixelWidth: 320,
  pixelHeight: 240,
);

void main() {
  setUpAll(() async {
    final asset = await rootBundle.load(
      'assets/brand/room-of-days-monochrome-v2.png',
    );
    _imageBytes = asset.buffer.asUint8List();
    final canonical = await canonicalizeRoomPhoto(_imageBytes);
    _width = canonical.pixelWidth;
    _height = canonical.pixelHeight;
  });

  testWidgets(
    'legacy room keepsake values remain inert in rendering, copy, and semantics',
    (tester) async {
      await _pump(
        tester,
        room: {
          ..._room(),
          'roomKeepsakes': ['keepsake_books', 'keepsake_teapot'],
        },
      );

      expect(find.byType(HomeRoom), findsOneWidget);
      expect(find.textContaining('Well-loved books'), findsNothing);
      expect(find.textContaining('Blue teapot'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('mantel|keepsake', caseSensitive: false)),
        findsNothing,
      );
    },
  );

  testWidgets('valid room photo bytes render in a visitor room', (
    tester,
  ) async {
    final path = sharedRoomMediaObjectPath(
      ownerUid: _owner,
      roomCode: _code,
      slot: SharedRoomMediaSlot.room.wireName,
      generation: 'abcdefghijklmnopqrstuv',
    );
    var calls = 0;
    await _pump(
      tester,
      room: _room(path: path),
      loader: (objectPath, maxBytes) async {
        calls++;
        expect(objectPath, path);
        expect(maxBytes, maxPublicRoomPhotoBytes);
        return _imageBytes;
      },
    );

    expect(calls, 1);
    expect(tester.widget<HomeRoom>(find.byType(HomeRoom)).roomPhoto, isNotNull);
  });

  testWidgets('cross-owner or cross-code path never loads or renders', (
    tester,
  ) async {
    final path = sharedRoomMediaObjectPath(
      ownerUid: _otherOwner,
      roomCode: _code,
      slot: SharedRoomMediaSlot.room.wireName,
      generation: 'abcdefghijklmnopqrstuv',
    );
    var calls = 0;
    await _pump(
      tester,
      room: _room(path: path),
      loader: (_, _) async {
        calls++;
        return _imageBytes;
      },
    );

    expect(calls, 0);
    expect(tester.widget<HomeRoom>(find.byType(HomeRoom)).roomPhoto, isNull);
  });

  testWidgets('cross-code and malformed paths stay absent', (tester) async {
    final crossCode = sharedRoomMediaObjectPath(
      ownerUid: _owner,
      roomCode: 'DEF678',
      slot: SharedRoomMediaSlot.room.wireName,
      generation: 'abcdefghijklmnopqrstuv',
    );
    var calls = 0;
    await _pump(
      tester,
      room: _room(path: crossCode),
      loader: (_, _) async {
        calls++;
        return _imageBytes;
      },
    );
    expect(calls, 0);
    expect(tester.widget<HomeRoom>(find.byType(HomeRoom)).roomPhoto, isNull);

    await _pump(
      tester,
      room: _room(path: 'shared_rooms/$_owner/ABC234/not-room/bad'),
      loader: (_, _) async {
        calls++;
        return _imageBytes;
      },
    );
    expect(calls, 0);
    expect(tester.widget<HomeRoom>(find.byType(HomeRoom)).roomPhoto, isNull);
  });

  testWidgets('a remote download failure quietly leaves the frame empty', (
    tester,
  ) async {
    final path = sharedRoomMediaObjectPath(
      ownerUid: _owner,
      roomCode: _code,
      slot: SharedRoomMediaSlot.room.wireName,
      generation: 'abcdefghijklmnopqrstuv',
    );
    await _pump(
      tester,
      room: _room(path: path),
      loader: (_, _) => Future<Uint8List>.error(StateError('offline')),
    );

    expect(tester.widget<HomeRoom>(find.byType(HomeRoom)).roomPhoto, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local public preview uses only its explicit photo input', (
    tester,
  ) async {
    var calls = 0;
    final preview = _localPhoto();
    await _pump(
      tester,
      room: _room(path: 'not-a-valid-path'),
      previewOnly: true,
      preview: preview,
      loader: (_, _) async {
        calls++;
        return _imageBytes;
      },
    );

    expect(calls, 0);
    expect(
      tester.widget<HomeRoom>(find.byType(HomeRoom)).roomPhoto,
      same(preview),
    );
  });
}
