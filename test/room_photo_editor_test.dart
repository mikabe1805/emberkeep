import 'dart:typed_data';

import 'package:emberkeep/engine.dart';
import 'package:emberkeep/media_picker_intent.dart';
import 'package:emberkeep/room_photo.dart';
import 'package:emberkeep/screens/room_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Real bundled PNG bytes exercise the renderer's MemoryImage route. A made-up
// byte sequence would conceal exactly the image-decoding failure this feature
// must avoid.
late Uint8List _pixel;

RoomPhotoData _photo() => RoomPhotoData(
  bytes: Uint8List.fromList(_pixel),
  pixelWidth: 1,
  pixelHeight: 1,
);

Future<void> _pumpEditor(
  WidgetTester tester,
  RoomPhotoStore store, {
  required String ownerKey,
  Size size = const Size(430, 932),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQueryData(size: size, textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const Key('open-room-photo-editor'),
              onPressed: () => Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => RoomPhotoScreen(
                    state: GameState()..reduceMotion = true,
                    ownerKey: ownerKey,
                    store: store,
                    pickerIntentCoordinator: MediaPickerIntentCoordinator(
                      preferences: SharedPreferences.getInstance,
                    ),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await _tap(tester, const Key('open-room-photo-editor'));
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final target = find.byKey(key);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget, reason: '$key must be tappable');
  await tester.tap(target, warnIfMissed: true);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<RoomPhotoStore> _store({
  Future<XFile?> Function()? picker,
  Future<SharedPreferences> Function()? preferences,
}) async {
  final store = RoomPhotoStore(
    picker: picker,
    preferences: preferences,
    codec: (_) async => _photo(),
  );
  await store.activateOwner('owner-a');
  return store;
}

void main() {
  setUpAll(() async {
    final asset = await rootBundle.load(
      'assets/brand/room-of-days-monochrome-v2.png',
    );
    _pixel = asset.buffer.asUint8List();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a cancelled library pick leaves the stored photo alone', (
    tester,
  ) async {
    var picks = 0;
    final original = _photo();
    final store = await _store(
      picker: () async {
        picks++;
        return null;
      },
    );
    await store.save(original, ownerKey: 'owner-a');
    final committed = store.photo;

    await _pumpEditor(tester, store, ownerKey: 'owner-a');
    await _tap(tester, const Key('replace-room-photo'));

    expect(picks, 1);
    expect(store.photo, same(committed));
    expect(store.photo!.bytes, orderedEquals(committed!.bytes));
    expect(find.byKey(const Key('save-room-photo')), findsOneWidget);
  });

  testWidgets('replace then Cancel leaves the original stored photo intact', (
    tester,
  ) async {
    var picks = 0;
    final original = _photo();
    final store = await _store(
      picker: () async {
        picks++;
        return XFile.fromData(_pixel);
      },
    );
    await store.save(original, ownerKey: 'owner-a');
    final committed = store.photo;

    await _pumpEditor(tester, store, ownerKey: 'owner-a');
    await _tap(tester, const Key('replace-room-photo'));
    expect(picks, 1);
    // The successful picker produced an unsaved replacement draft.
    expect(find.byKey(const Key('save-room-photo')), findsOneWidget);
    await _tap(tester, const Key('cancel-room-photo'));

    expect(find.byKey(const Key('cancel-room-photo')), findsNothing);
    expect(store.photo, same(committed));
    expect(store.photo!.bytes, orderedEquals(committed!.bytes));
  });

  testWidgets('Remove remains a draft until Save explicitly succeeds', (
    tester,
  ) async {
    final original = _photo();
    final store = await _store();
    await store.save(original, ownerKey: 'owner-a');
    final committed = store.photo;

    await _pumpEditor(tester, store, ownerKey: 'owner-a');
    await _tap(tester, const Key('remove-room-photo'));
    expect(store.photo, same(committed));
    expect(store.photo!.bytes, orderedEquals(committed!.bytes));

    await _tap(tester, const Key('save-room-photo'));
    expect(find.byKey(const Key('save-room-photo')), findsNothing);
    expect(store.photo, isNull);
  });

  testWidgets(
    'a save failure retains the old photo and leaves a visible retry',
    (tester) async {
      var failWrites = false;
      final original = _photo();
      final store = await _store(
        preferences: () async {
          if (failWrites) throw StateError('disk unavailable');
          return SharedPreferences.getInstance();
        },
      );
      await store.save(original, ownerKey: 'owner-a');
      final committed = store.photo;
      failWrites = true;

      await _pumpEditor(tester, store, ownerKey: 'owner-a');
      await _tap(tester, const Key('remove-room-photo'));
      await _tap(tester, const Key('save-room-photo'));

      expect(store.photo, same(committed));
      expect(store.photo!.bytes, orderedEquals(committed!.bytes));
      expect(
        find.text('This device could not save the room photo.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('save-room-photo')), findsOneWidget);
    },
  );

  testWidgets('an owner switch while editing cannot commit the old draft', (
    tester,
  ) async {
    final original = _photo();
    final store = await _store();
    await store.save(original, ownerKey: 'owner-a');
    await _pumpEditor(tester, store, ownerKey: 'owner-a');
    await _tap(tester, const Key('remove-room-photo'));

    await store.activateOwner('owner-b');
    await tester.pumpAndSettle();

    expect(store.ownerKey, 'owner-b');
    expect(store.photo, isNull);
    // The owner-bound store hides its prior value before the editor can pop.
    // A root-route editor may remain mounted, but it has no owner-A draft left
    // that could be committed into owner B.
  });

  testWidgets('a local reset clears an open editor draft too', (tester) async {
    final store = await _store();
    await store.save(_photo(), ownerKey: 'owner-a');
    await _pumpEditor(tester, store, ownerKey: 'owner-a');

    expect(await store.clearAll(), isTrue);
    await tester.pumpAndSettle();

    expect(store.photo, isNull);
    expect(find.byKey(const Key('choose-room-photo')), findsOneWidget);
    expect(find.byKey(const Key('save-room-photo')), findsOneWidget);
  });

  testWidgets('a compact 2x editor keeps its private job and actions usable', (
    tester,
  ) async {
    final store = await _store();
    await store.save(_photo(), ownerKey: 'owner-a');

    await _pumpEditor(
      tester,
      store,
      ownerKey: 'owner-a',
      size: const Size(320, 568),
      textScaler: const TextScaler.linear(2),
    );

    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Private on device.'), findsOneWidget);
    expect(find.text('Above the fireplace'), findsNothing);
    await _tap(tester, const Key('remove-room-photo'));
    await _tap(tester, const Key('save-room-photo'));
    expect(store.photo, isNull);
    expect(tester.takeException(), isNull);
  });
}
