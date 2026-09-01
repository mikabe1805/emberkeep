import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:emberkeep/room_photo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' hide Uint8List;
import 'package:shared_preferences/shared_preferences.dart';

RoomPhotoData _photo([int marker = 7]) => RoomPhotoData(
  bytes: Uint8List.fromList([marker, 2, 3]),
  pixelWidth: 12,
  pixelHeight: 8,
);

RoomPhotoStore _store({RoomPhotoPicker? picker, RoomPhotoCodec? codec}) =>
    RoomPhotoStore(
      picker: picker ?? () async => null,
      codec:
          codec ??
          (bytes) async =>
              RoomPhotoData(bytes: bytes, pixelWidth: 12, pixelHeight: 8),
      preferences: SharedPreferences.getInstance,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('cancel preserves the currently displayed room photo', () async {
    final store = _store();
    await store.activateOwner('keeper-a');
    final original = _photo();
    await store.save(original, ownerKey: 'keeper-a');

    expect(await store.pickFromLibrary(), isNull);
    expect(store.photo?.bytes, orderedEquals(original.bytes));
    expect(store.lastError, isNull);
  });

  test(
    'photo bytes are read-only and framing copies retain their cache key',
    () {
      final original = _photo();
      final framed = original.copyWith(
        fillFrame: true,
        alignment: Alignment.bottomRight,
      );

      expect(() => original.bytes[0] = 99, throwsUnsupportedError);
      expect(identical(original.bytes, framed.bytes), isTrue);
      expect(framed.fillFrame, isTrue);
      expect(framed.alignment, Alignment.bottomRight);
      expect(framed.pixelWidth, original.pixelWidth);
      expect(framed.pixelHeight, original.pixelHeight);
      expect(original.fillFrame, isFalse);
      expect(original.alignment, Alignment.center);
    },
  );

  test('a persisted photo never displays for another owner', () async {
    final raw = jsonEncode({
      'v': 1,
      'ownerKey': 'keeper-a',
      'png': base64Encode([7, 2, 3]),
      'fillFrame': false,
      'alignmentX': 0,
      'alignmentY': 0,
      'pixelWidth': 12,
      'pixelHeight': 8,
    });
    SharedPreferences.setMockInitialValues({RoomPhotoStore.storageKey: raw});
    final store = _store();

    await store.activateOwner('keeper-b');

    expect(store.loaded, isTrue);
    expect(store.ownerKey, 'keeper-b');
    expect(store.photo, isNull);
  });

  test('save persists before publishing the replacement', () async {
    final prefs = await SharedPreferences.getInstance();
    final write = Completer<bool>();
    final store = RoomPhotoStore(
      preferences: () async => _DelayedWritePreferences(prefs, write),
      codec: (bytes) async =>
          RoomPhotoData(bytes: bytes, pixelWidth: 12, pixelHeight: 8),
    );
    await store.activateOwner('keeper-a');
    final draft = _photo(9);
    final saving = store.save(draft, ownerKey: 'keeper-a');

    await Future<void>.delayed(Duration.zero);
    expect(store.photo, isNull);
    write.complete(true);
    await saving;

    expect(store.photo?.bytes, orderedEquals(draft.bytes));
  });

  test(
    'an owner switch hides the old photo before a delayed load completes',
    () async {
      final first = Completer<SharedPreferences>();
      var requests = 0;
      final store = RoomPhotoStore(
        preferences: () {
          requests++;
          if (requests == 1) return first.future;
          return SharedPreferences.getInstance();
        },
        codec: (_) async => _photo(),
      );

      final firstActivation = store.activateOwner('keeper-a');
      expect(store.loaded, isFalse);
      // Let the first activation claim the deliberately delayed preferences
      // request before the second activation is allowed to supersede it.
      await Future<void>.delayed(Duration.zero);
      await store.activateOwner('keeper-b');
      first.complete(await SharedPreferences.getInstance());
      await firstActivation;

      expect(store.ownerKey, 'keeper-b');
      expect(store.loaded, isTrue);
      expect(store.photo, isNull);
    },
  );

  test('stale drafts cannot be saved into another owners room', () async {
    final store = _store();
    await store.activateOwner('keeper-a');
    await store.activateOwner('keeper-b');

    expect(
      () => store.save(_photo(), ownerKey: 'keeper-a'),
      throwsA(
        isA<RoomPhotoException>().having(
          (error) => error.failure,
          'failure',
          RoomPhotoFailure.staleOwner,
        ),
      ),
    );
  });

  test('clearAll removes the private preference and hides its image', () async {
    final store = _store();
    await store.activateOwner('keeper-a');
    await store.save(_photo(), ownerKey: 'keeper-a');

    expect(await store.clearAll(), isTrue);
    expect(store.photo, isNull);
    expect(
      (await SharedPreferences.getInstance()).containsKey(
        RoomPhotoStore.storageKey,
      ),
      isFalse,
    );
  });

  test('a later save wins when an earlier preferences write is slow', () async {
    final prefs = await SharedPreferences.getInstance();
    final firstWrite = Completer<bool>();
    final delayedPrefs = _SequencedWritePreferences(prefs, firstWrite);
    final store = RoomPhotoStore(
      preferences: () async => delayedPrefs,
      codec: (bytes) async =>
          RoomPhotoData(bytes: bytes, pixelWidth: 12, pixelHeight: 8),
    );
    await store.activateOwner('keeper-a');
    final first = store.save(_photo(1), ownerKey: 'keeper-a');
    await Future<void>.delayed(Duration.zero);
    final second = store.save(_photo(2), ownerKey: 'keeper-a');
    firstWrite.complete(true);
    await expectLater(
      first,
      throwsA(
        isA<RoomPhotoException>().having(
          (error) => error.failure,
          'failure',
          RoomPhotoFailure.superseded,
        ),
      ),
    );
    await second;

    expect(store.photo?.bytes, orderedEquals(const [2, 2, 3]));
  });

  test(
    'clear then activation waits for removal instead of resurrecting a photo',
    () async {
      final raw = jsonEncode({
        'v': 1,
        'ownerKey': 'keeper-a',
        'png': base64Encode([7, 2, 3]),
        'fillFrame': false,
        'alignmentX': 0,
        'alignmentY': 0,
        'pixelWidth': 12,
        'pixelHeight': 8,
      });
      SharedPreferences.setMockInitialValues({RoomPhotoStore.storageKey: raw});
      final prefs = await SharedPreferences.getInstance();
      final remove = Completer<bool>();
      final delayedPrefs = _DelayedRemovePreferences(prefs, remove);
      final store = RoomPhotoStore(
        preferences: () async => delayedPrefs,
        codec: (bytes) async =>
            RoomPhotoData(bytes: bytes, pixelWidth: 12, pixelHeight: 8),
      );
      await store.activateOwner('keeper-a');
      expect(store.photo, isNotNull);

      final clearing = store.clearAll();
      final reactivating = store.activateOwner('keeper-a');
      remove.complete(true);
      await clearing;
      await reactivating;

      expect(store.loaded, isTrue);
      expect(store.photo, isNull);
    },
  );

  test('owner change during an in-flight write rejects the old save', () async {
    final prefs = await SharedPreferences.getInstance();
    final write = Completer<bool>();
    final delayedPrefs = _DelayedWritePreferences(prefs, write);
    final store = RoomPhotoStore(
      preferences: () async => delayedPrefs,
      codec: (bytes) async =>
          RoomPhotoData(bytes: bytes, pixelWidth: 12, pixelHeight: 8),
    );
    await store.activateOwner('keeper-a');
    final saving = store.save(_photo(), ownerKey: 'keeper-a');
    await Future<void>.delayed(Duration.zero);
    final activating = store.activateOwner('keeper-b');
    final rejected = expectLater(
      saving,
      throwsA(
        isA<RoomPhotoException>().having(
          (error) => error.failure,
          'failure',
          RoomPhotoFailure.staleOwner,
        ),
      ),
    );
    write.complete(true);
    await activating;

    await rejected;
    expect(store.ownerKey, 'keeper-b');
    expect(store.photo, isNull);
  });

  test(
    'canonical codec produces a bounded PNG without source metadata',
    () async {
      final source = (await rootBundle.load(
        'assets/brand/room-of-days-monochrome-v2.png',
      )).buffer.asUint8List();

      final photo = await canonicalizeRoomPhoto(source);

      expect(photo.pixelWidth, lessThanOrEqualTo(RoomPhotoStore.maxDimension));
      expect(photo.pixelHeight, lessThanOrEqualTo(RoomPhotoStore.maxDimension));
      expect(
        photo.bytes.length,
        lessThanOrEqualTo(RoomPhotoStore.maxCanonicalBytes),
      );
      expect(
        photo.bytes.take(8),
        orderedEquals(const [137, 80, 78, 71, 13, 10, 26, 10]),
      );
    },
  );
}

/// Keeps the test focused on the store's write-before-publish ordering.
final class _DelayedWritePreferences implements SharedPreferences {
  _DelayedWritePreferences(this._delegate, this._write);

  final SharedPreferences _delegate;
  final Completer<bool> _write;

  @override
  Future<bool> setString(String key, String value) => _write.future;

  @override
  noSuchMethod(Invocation invocation) => _delegate.noSuchMethod(invocation);
}

final class _SequencedWritePreferences implements SharedPreferences {
  _SequencedWritePreferences(this._delegate, this._firstWrite);

  final SharedPreferences _delegate;
  final Completer<bool> _firstWrite;
  var _writes = 0;

  @override
  Future<bool> setString(String key, String value) {
    _writes++;
    if (_writes == 1) return _firstWrite.future;
    return _delegate.setString(key, value);
  }

  @override
  noSuchMethod(Invocation invocation) => _delegate.noSuchMethod(invocation);
}

final class _DelayedRemovePreferences implements SharedPreferences {
  _DelayedRemovePreferences(this._delegate, this._remove);

  final SharedPreferences _delegate;
  final Completer<bool> _remove;

  @override
  String? getString(String key) => _delegate.getString(key);

  @override
  Future<bool> remove(String key) async {
    if (!await _remove.future) return false;
    return _delegate.remove(key);
  }

  @override
  noSuchMethod(Invocation invocation) => _delegate.noSuchMethod(invocation);
}
