import 'dart:async';

import 'package:emberkeep/media_picker_intent.dart';
import 'package:emberkeep/room_photo.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  MediaPickerIntentCoordinator coordinator() =>
      MediaPickerIntentCoordinator(preferences: SharedPreferences.getInstance);

  test(
    'a pending room picker cannot be replaced by Journal or another room pick',
    () async {
      final intents = coordinator();

      expect(await intents.beginRoomPhoto('firebase:keeper-a'), isTrue);
      expect(await intents.mayRecoverJournal(), isFalse);
      expect(await intents.beginJournal(), isFalse);
      expect(await intents.beginRoomPhoto('firebase:keeper-a'), isFalse);

      // A stale completion from another account cannot clear the live marker.
      await intents.completeRoomPhoto('firebase:keeper-b');
      expect(await intents.mayRecoverJournal(), isFalse);

      await intents.completeRoomPhoto('firebase:keeper-a');
      expect(await intents.mayRecoverJournal(), isTrue);
      expect(await intents.beginJournal(), isTrue);
    },
  );

  test('the local owner scope is stable but Firebase ownership wins', () async {
    final intents = coordinator();

    final first = await intents.roomPhotoOwnerKey(firebaseUid: null);
    final reopened = await intents.roomPhotoOwnerKey(firebaseUid: null);

    expect(first, startsWith('device:'));
    expect(reopened, first);
    expect(
      await intents.roomPhotoOwnerKey(firebaseUid: 'account-owner'),
      'firebase:account-owner',
    );
  });

  test('only Android uses the process-recovery channel', () {
    expect(
      supportsLostPickerRecovery(
        isWeb: false,
        platform: TargetPlatform.android,
      ),
      isTrue,
    );
    expect(
      supportsLostPickerRecovery(isWeb: true, platform: TargetPlatform.android),
      isFalse,
    );
    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.fuchsia,
    ]) {
      expect(
        supportsLostPickerRecovery(isWeb: false, platform: platform),
        isFalse,
      );
    }
  });

  test(
    'a stale owners room recovery is consumed before Journal can continue',
    () async {
      final intents = MediaPickerIntentCoordinator(
        preferences: SharedPreferences.getInstance,
        lostData: () async => LostDataResponse.empty(),
      );
      expect(await intents.beginRoomPhoto('firebase:former-owner'), isTrue);

      expect(
        await intents.discardRecoveredRoomPhotoForOtherOwner(
          'firebase:current-owner',
        ),
        isTrue,
      );
      expect(await intents.mayRecoverJournal(), isTrue);
      expect(await intents.beginJournal(), isTrue);
    },
  );

  test(
    'the active owner keeps their room recovery for deliberate review',
    () async {
      final intents = coordinator();
      expect(await intents.beginRoomPhoto('firebase:keeper-a'), isTrue);

      expect(
        await intents.discardRecoveredRoomPhotoForOtherOwner(
          'firebase:keeper-a',
        ),
        isFalse,
      );
      expect(await intents.mayRecoverJournal(), isFalse);
    },
  );

  test(
    'picker startup fails closed when its intent cannot be persisted',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final intents = MediaPickerIntentCoordinator(
        preferences: () async => _SetStringFailure(prefs),
      );

      expect(await intents.beginJournal(), isFalse);
      expect(intents.lastError, isNotNull);
    },
  );

  test('picker recovery fails closed when its intent cannot be read', () async {
    final prefs = await SharedPreferences.getInstance();
    final intents = MediaPickerIntentCoordinator(
      preferences: () async => _ReadFailure(prefs),
    );

    expect(await intents.mayRecoverJournal(), isFalse);
    expect(intents.lastError, isNotNull);
  });

  test('a failed room retrieve keeps its marker and blocks Journal', () async {
    final prefs = await SharedPreferences.getInstance();
    final intents = MediaPickerIntentCoordinator(
      preferences: SharedPreferences.getInstance,
      lostData: () async => throw StateError('picker unavailable'),
    );
    final store = RoomPhotoStore(
      preferences: SharedPreferences.getInstance,
      codec: (bytes) async =>
          RoomPhotoData(bytes: bytes, pixelWidth: 1, pixelHeight: 1),
    );
    await store.activateOwner('firebase:keeper-a');
    expect(await intents.beginRoomPhoto('firebase:keeper-a'), isTrue);

    expect(
      await intents.recoverRoomPhotoDraft(store, 'firebase:keeper-a'),
      isNull,
    );
    expect(intents.lastError, isNotNull);
    expect(await intents.mayRecoverJournal(), isFalse);
    expect(prefs.containsKey('emberkeep_media_picker_intent_v1'), isTrue);
  });

  test('an empty successful room recovery clears its marker', () async {
    final intents = MediaPickerIntentCoordinator(
      preferences: SharedPreferences.getInstance,
      lostData: () async => LostDataResponse.empty(),
    );
    final store = RoomPhotoStore(
      preferences: SharedPreferences.getInstance,
      codec: (bytes) async =>
          RoomPhotoData(bytes: bytes, pixelWidth: 1, pixelHeight: 1),
    );
    await store.activateOwner('firebase:keeper-a');
    expect(await intents.beginRoomPhoto('firebase:keeper-a'), isTrue);

    expect(
      await intents.recoverRoomPhotoDraft(store, 'firebase:keeper-a'),
      isNull,
    );
    expect(await intents.mayRecoverJournal(), isTrue);
  });

  test('destructive cleanup consumes only the pending room marker', () async {
    final intents = MediaPickerIntentCoordinator(
      preferences: SharedPreferences.getInstance,
      lostData: () async => LostDataResponse.empty(),
    );
    expect(await intents.beginRoomPhoto('firebase:keeper-a'), isTrue);

    expect(await intents.clearPendingRoomPhotoIntent(), isTrue);
    expect(await intents.mayRecoverJournal(), isTrue);
  });

  test(
    'Journal recovery holds the global picker claim until it finishes',
    () async {
      final intents = coordinator();
      final releaseRecovery = Completer<List<String>>();
      expect(await intents.beginJournal(), isTrue);

      final recovered = intents.recoverJournalMedia(
        () => releaseRecovery.future,
      );
      final roomBegin = intents.beginRoomPhoto('firebase:keeper-a');
      var roomBeginSettled = false;
      unawaited(roomBegin.then((_) => roomBeginSettled = true));
      await Future<void>.delayed(Duration.zero);
      expect(roomBeginSettled, isFalse);

      releaseRecovery.complete(const []);
      expect(await recovered, isEmpty);
      expect(await roomBegin, isTrue);
    },
  );
}

final class _SetStringFailure implements SharedPreferences {
  const _SetStringFailure(this._delegate);
  final SharedPreferences _delegate;

  @override
  Future<bool> setString(String key, String value) async => false;

  @override
  noSuchMethod(Invocation invocation) => _delegate.noSuchMethod(invocation);
}

final class _ReadFailure implements SharedPreferences {
  const _ReadFailure(this._delegate);
  final SharedPreferences _delegate;

  @override
  String? getString(String key) => throw StateError('preferences unavailable');

  @override
  noSuchMethod(Invocation invocation) => _delegate.noSuchMethod(invocation);
}
