import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'room_photo.dart';

/// The one durable routing marker for Android's process-recovered picker
/// result. `retrieveLostData` is global to image_picker: without this marker,
/// a room photo picked before Android reclaimed the app could land in whatever
/// Journal page happened to open first.
enum MediaPickerIntent { journal, roomPhoto }

/// Android alone offers image_picker's process-recovery channel. Other
/// platforms complete an interrupted marker as an empty, successful recovery
/// so it cannot permanently lock future picks or destructive cleanup.
bool supportsLostPickerRecovery({
  required bool isWeb,
  required TargetPlatform platform,
}) => !isWeb && platform == TargetPlatform.android;

final class MediaPickerIntentCoordinator {
  MediaPickerIntentCoordinator({
    Future<SharedPreferences> Function()? preferences,
    Future<LostDataResponse> Function()? lostData,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _lostData = lostData ?? _defaultLostData;

  static final instance = MediaPickerIntentCoordinator();

  static const _intentKey = 'emberkeep_media_picker_intent_v1';
  static const _localOwnerKey = 'emberkeep_room_photo_local_owner_v1';

  final Future<SharedPreferences> Function() _preferences;
  final Future<LostDataResponse> Function() _lostData;
  Future<void> _intentTail = Future<void>.value();
  String? _lastError;

  /// Null after a successful coordinator operation. Callers use this to make
  /// a blocked picker recoverable instead of silently treating it as cancel.
  String? get lastError => _lastError;

  static Future<LostDataResponse> _defaultLostData() {
    if (!supportsLostPickerRecovery(
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
    )) {
      return Future.value(LostDataResponse.empty());
    }
    return ImagePicker().retrieveLostData();
  }

  /// Returns false while any earlier pick is still protected. A Journal must
  /// not replace that marker and claim Android's global recovered file.
  Future<bool> beginJournal() => _serialized(() async {
    _lastError = null;
    final current = await _read();
    if (_lastError != null) return false;
    if (current != null) return false;
    return _write(const _StoredPickerIntent.journal());
  });

  /// Returns false until an earlier room recovery has been reviewed or safely
  /// discarded. Replacing that marker would make the old Android result
  /// ambiguous, even if the repeated pick belongs to the same owner.
  Future<bool> beginRoomPhoto(String ownerKey) => _serialized(() async {
    _lastError = null;
    final current = await _read();
    if (_lastError != null) return false;
    if (current != null) return false;
    return _write(_StoredPickerIntent.roomPhoto(_validOwner(ownerKey)));
  });

  /// Normal completion (including a deliberate cancel) has no result left for
  /// Android to recover. Only clear a marker the caller still owns, so an old
  /// completion cannot erase a newer pick begun by another surface.
  Future<void> completeJournal() =>
      _serialized(() => _clearIf(MediaPickerIntent.journal, null));

  Future<void> completeRoomPhoto(String ownerKey) => _serialized(
    () => _clearIf(MediaPickerIntent.roomPhoto, _validOwner(ownerKey)),
  );

  /// A Journal may recover its own older result, and legacy Journal results
  /// from before intent tracking. It must never call `retrieveLostData` while
  /// a room pick is pending: that would consume a private room image and add
  /// it to the Journal automatically.
  Future<bool> mayRecoverJournal() async {
    return _serialized(() async {
      final intent = await _read();
      if (_lastError != null) return false;
      return intent?.destination != MediaPickerIntent.roomPhoto;
    });
  }

  /// Claims a recovered room result only to discard it when the account that
  /// launched the picker is no longer active. This is deliberately a consume,
  /// not just marker cleanup: leaving the platform result behind would let a
  /// later Journal recovery mistake it for legacy Journal media.
  Future<bool> discardRecoveredRoomPhotoForOtherOwner(
    String activeOwnerKey, {
    bool Function()? stillActive,
  }) => _serialized(() async {
    _lastError = null;
    final active = _validOwner(activeOwnerKey);
    final intent = await _read();
    if (_lastError != null) return false;
    if (intent?.destination != MediaPickerIntent.roomPhoto ||
        intent?.ownerKey == active) {
      return false;
    }
    if (stillActive != null && !stillActive()) return false;
    try {
      // A successful call consumes the platform's one global result even
      // when it reports no file. If the call itself fails, retain the
      // marker so a Journal cannot claim an unobserved private result.
      await _lostData();
    } catch (_) {
      _lastError = 'Couldn’t safely recover the earlier room photo yet.';
      return false;
    }
    return await _clearIf(MediaPickerIntent.roomPhoto, intent?.ownerKey);
  });

  /// Clears only a pending room picker result during destructive local erasure.
  /// Journal recovery is intentionally outside this boundary. The Android
  /// result is consumed before its marker is removed, so a later Journal
  /// cannot claim a pre-reset room image as legacy Journal media.
  Future<bool> clearPendingRoomPhotoIntent() => _serialized(() async {
    _lastError = null;
    final intent = await _read();
    if (_lastError != null) return false;
    if (intent?.destination != MediaPickerIntent.roomPhoto) return true;
    try {
      await _lostData();
    } catch (_) {
      _lastError = 'Couldn’t safely clear the pending room photo yet.';
      return false;
    }
    return _clearIf(MediaPickerIntent.roomPhoto, intent?.ownerKey);
  });

  /// Recovers a room library result as a draft for precisely [ownerKey]. This
  /// never invokes [RoomPhotoStore.save]; the editor must show its normal
  /// draft/placement flow and the owner must deliberately commit it.
  Future<RoomPhotoData?> recoverRoomPhotoDraft(
    RoomPhotoStore store,
    String ownerKey,
  ) => _serialized(() async {
    _lastError = null;
    final expectedOwner = _validOwner(ownerKey);
    final intent = await _read();
    if (_lastError != null) return null;
    if (intent == null ||
        intent.destination != MediaPickerIntent.roomPhoto ||
        intent.ownerKey != expectedOwner ||
        store.ownerKey != expectedOwner) {
      return null;
    }
    try {
      final lost = await _lostData();
      final file =
          lost.file ??
          (lost.files?.isNotEmpty == true ? lost.files!.first : null);
      if (file == null) {
        await _clearIf(MediaPickerIntent.roomPhoto, expectedOwner);
        return null;
      }
      final draft = await store.preparePickedFile(file);
      // A picker result can be read only once. Clear the marker even for an
      // invalid file so it cannot later be mistaken for a new room draft.
      if (!await _clearIf(MediaPickerIntent.roomPhoto, expectedOwner)) {
        return null;
      }
      return draft;
    } catch (_) {
      // Do not clear a room marker if Android did not actually hand us its
      // global result. A later Journal must remain blocked rather than claim
      // an unobserved private image as legacy Journal media.
      _lastError = 'Couldn’t safely recover the earlier room photo yet.';
      return null;
    }
  });

  /// Serializes Journal's global Android recovery with intent inspection.
  /// The callback is called only after the coordinator knows that a room
  /// result is not waiting, so a room `begin` cannot interleave between a
  /// permissive check and `retrieveLostData`.
  Future<List<String>?> recoverJournalMedia(
    Future<List<String>> Function() recover,
  ) => _serialized(() async {
    _lastError = null;
    final intent = await _read();
    if (_lastError != null ||
        intent?.destination == MediaPickerIntent.roomPhoto) {
      return null;
    }
    try {
      final names = await recover();
      await _clearIf(MediaPickerIntent.journal, null);
      return names;
    } catch (_) {
      _lastError = 'Couldn’t safely recover the earlier photo yet.';
      return null;
    }
  });

  /// Local-only installations still need a stable, private scope. Existing
  /// Firebase identities take precedence; this fallback is generated once on
  /// device and is never placed in the cloud save or export.
  Future<String> roomPhotoOwnerKey({required String? firebaseUid}) async {
    final uid = firebaseUid?.trim();
    if (uid != null && uid.isNotEmpty) return 'firebase:$uid';
    final prefs = await _preferences();
    final existing = prefs.getString(_localOwnerKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final created =
        'device:${List<int>.generate(24, (_) => random.nextInt(256)).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    await prefs.setString(_localOwnerKey, created);
    return created;
  }

  Future<bool> _write(_StoredPickerIntent intent) async {
    try {
      final saved = await (await _preferences()).setString(
        _intentKey,
        jsonEncode(intent.toJson()),
      );
      if (!saved) {
        _lastError = 'Couldn’t prepare the photo picker. Try again.';
      }
      return saved;
    } catch (_) {
      _lastError = 'Couldn’t prepare the photo picker. Try again.';
      return false;
    }
  }

  Future<_StoredPickerIntent?> _read() async {
    try {
      final raw = (await _preferences()).getString(_intentKey);
      final intent = _StoredPickerIntent.parse(raw);
      if (raw != null && intent == null) {
        _lastError = 'Couldn’t safely check an earlier photo choice yet.';
      }
      return intent;
    } catch (_) {
      _lastError = 'Couldn’t safely check an earlier photo choice yet.';
      return null;
    }
  }

  Future<bool> _clearIf(MediaPickerIntent destination, String? ownerKey) async {
    try {
      final prefs = await _preferences();
      final current = _StoredPickerIntent.parse(prefs.getString(_intentKey));
      if (current?.destination != destination ||
          current?.ownerKey != ownerKey) {
        return true;
      }
      final cleared = await prefs.remove(_intentKey);
      if (!cleared) {
        _lastError = 'Couldn’t safely clear the earlier photo choice yet.';
      }
      return cleared;
    } catch (_) {
      _lastError = 'Couldn’t safely clear the earlier photo choice yet.';
      return false;
    }
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final previous = _intentTail;
    final settled = Completer<void>();
    _intentTail = settled.future;
    return () async {
      await previous;
      try {
        return await operation();
      } finally {
        settled.complete();
      }
    }();
  }

  static String _validOwner(String value) {
    final clean = value.trim();
    if (clean.isEmpty || clean.length > 180) {
      throw ArgumentError.value(value, 'ownerKey', 'must be a bounded ID');
    }
    return clean;
  }
}

final class _StoredPickerIntent {
  const _StoredPickerIntent.journal()
    : destination = MediaPickerIntent.journal,
      ownerKey = null;
  const _StoredPickerIntent.roomPhoto(this.ownerKey)
    : destination = MediaPickerIntent.roomPhoto;

  final MediaPickerIntent destination;
  final String? ownerKey;

  Map<String, Object?> toJson() => {
    'v': 1,
    'destination': destination.name,
    if (ownerKey != null) 'ownerKey': ownerKey,
  };

  static _StoredPickerIntent? parse(String? raw) {
    if (raw == null) return null;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      if (map['v'] != 1) return null;
      return switch (map['destination']) {
        'journal' => const _StoredPickerIntent.journal(),
        'roomPhoto'
            when map['ownerKey'] is String &&
                (map['ownerKey'] as String).trim().isNotEmpty =>
          _StoredPickerIntent.roomPhoto(map['ownerKey'] as String),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }
}
