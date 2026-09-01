import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import 'journal_media.dart' as journal_media;

const int maxSharedRoomPhotoBytes = 3 * 1024 * 1024;
const int maxPublicRoomPhotoBytes = 800 * 1024;

/// Every published revision receives a new unguessable object path, so old and
/// new bytes never alias in caches while a room edit is being acknowledged.
const String sharedRoomPhotoCacheControl = 'public,max-age=31536000,immutable';
const int sharedRoomMediaGenerationLength = 22;

enum SharedRoomMediaSlot {
  profile,
  season,
  room;

  String get wireName => name;

  static SharedRoomMediaSlot? tryParse(String value) {
    for (final slot in values) {
      if (slot.wireName == value) return slot;
    }
    return null;
  }
}

enum SharedRoomMediaFailure {
  invalidOwnerUid,
  invalidRoomCode,
  invalidSlot,
  invalidObjectPath,
  localFileUnavailable,
  emptyFile,
  fileTooLarge,
  unsupportedFileType,
  uploadFailed,
  deleteFailed,
  downloadUrlFailed,
}

final class SharedRoomMediaException implements Exception {
  const SharedRoomMediaException(
    this.failure,
    this.message, {
    this.slot,
    this.cause,
  });

  final SharedRoomMediaFailure failure;
  final String message;
  final SharedRoomMediaSlot? slot;
  final Object? cause;

  @override
  String toString() => message;
}

final RegExp _ownerUidPattern = RegExp(r'^[A-Za-z0-9._~-]{1,128}$');
final RegExp _ownerKeyPattern = RegExp(r'^[a-f0-9]{64}$');
final RegExp _roomCodePattern = RegExp(
  r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$',
);
final RegExp _generationPattern = RegExp(
  '^[A-Za-z0-9_-]{$sharedRoomMediaGenerationLength}\$',
);
final Random _secureRandom = Random.secure();

String _validatedOwnerUid(String ownerUid) {
  if (!_ownerUidPattern.hasMatch(ownerUid)) {
    throw const SharedRoomMediaException(
      SharedRoomMediaFailure.invalidOwnerUid,
      'The shared-room owner ID is not valid.',
    );
  }
  return ownerUid;
}

String _validatedOwnerKey(String ownerKey) {
  if (!_ownerKeyPattern.hasMatch(ownerKey)) {
    throw const SharedRoomMediaException(
      SharedRoomMediaFailure.invalidOwnerUid,
      'The shared-room owner key is not valid.',
    );
  }
  return ownerKey;
}

String _normalizedRoomCode(String roomCode) {
  final normalized = roomCode.trim().toUpperCase();
  if (!_roomCodePattern.hasMatch(normalized)) {
    throw const SharedRoomMediaException(
      SharedRoomMediaFailure.invalidRoomCode,
      'The room code must be a valid six-character share code.',
    );
  }
  return normalized;
}

SharedRoomMediaSlot _validatedSlot(String slot) {
  final parsed = SharedRoomMediaSlot.tryParse(slot);
  if (parsed == null) {
    throw const SharedRoomMediaException(
      SharedRoomMediaFailure.invalidSlot,
      'The shared-room photo slot must be profile, season, or room.',
    );
  }
  return parsed;
}

String _validatedGeneration(String generation) {
  if (!_generationPattern.hasMatch(generation)) {
    throw const SharedRoomMediaException(
      SharedRoomMediaFailure.invalidObjectPath,
      'The shared-room photo revision is not valid.',
    );
  }
  return generation;
}

String _newGeneration() {
  final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

/// Forms the only object path this feature is allowed to use.
///
/// Every segment is validated before interpolation; callers cannot smuggle a
/// slash or an extra Storage path into an owner ID, room code, or slot.
String sharedRoomMediaObjectPath({
  required String ownerUid,
  required String roomCode,
  required String slot,
  String? generation,
}) {
  final safeSlot = _validatedSlot(slot);
  final safeOwnerUid = safeSlot == SharedRoomMediaSlot.room
      ? _validatedOwnerKey(ownerUid)
      : _validatedOwnerUid(ownerUid);
  final safeRoomCode = _normalizedRoomCode(roomCode);
  final base = 'shared_rooms/$safeOwnerUid/$safeRoomCode/${safeSlot.wireName}';
  return generation == null
      ? base
      : '$base/${_validatedGeneration(generation)}';
}

final class SharedRoomMediaLocation {
  const SharedRoomMediaLocation._({
    required this.ownerUid,
    required this.roomCode,
    required this.slot,
    required this.generation,
    required this.objectPath,
  });

  final String ownerUid;

  /// The first path segment is an opaque owner key for the public room slot.
  /// Legacy profile/season paths used this same field for a Firebase uid.
  String get ownerKey => ownerUid;
  final String roomCode;
  final SharedRoomMediaSlot slot;
  final String? generation;
  final String objectPath;

  /// Validates a visitor-supplied object path and requires canonical casing.
  factory SharedRoomMediaLocation.fromObjectPath(String objectPath) {
    final parts = objectPath.split('/');
    if ((parts.length != 4 && parts.length != 5) ||
        parts.first != 'shared_rooms') {
      throw const SharedRoomMediaException(
        SharedRoomMediaFailure.invalidObjectPath,
        'The shared-room photo path is not valid.',
      );
    }

    try {
      final canonical = sharedRoomMediaObjectPath(
        ownerUid: parts[1],
        roomCode: parts[2],
        slot: parts[3],
        generation: parts.length == 5 ? parts[4] : null,
      );
      if (canonical != objectPath) {
        throw const SharedRoomMediaException(
          SharedRoomMediaFailure.invalidObjectPath,
          'The shared-room photo path is not canonical.',
        );
      }
      return SharedRoomMediaLocation._(
        ownerUid: parts[1],
        roomCode: parts[2],
        slot: _validatedSlot(parts[3]),
        generation: parts.length == 5 ? parts[4] : null,
        objectPath: canonical,
      );
    } on SharedRoomMediaException catch (error) {
      if (error.failure == SharedRoomMediaFailure.invalidObjectPath) rethrow;
      throw SharedRoomMediaException(
        SharedRoomMediaFailure.invalidObjectPath,
        'The shared-room photo path is not valid.',
        cause: error,
      );
    }
  }
}

final class SharedRoomMediaUploadRequest {
  const SharedRoomMediaUploadRequest({
    required this.objectPath,
    required this.slot,
    required this.bytes,
    required this.contentType,
    required this.cacheControl,
    required this.customMetadata,
  });

  final String objectPath;
  final SharedRoomMediaSlot slot;
  final Uint8List bytes;
  final String contentType;
  final String cacheControl;
  final Map<String, String> customMetadata;
}

typedef SharedRoomMediaLocalReader =
    Future<journal_media.JournalMediaUploadData> Function(String filename);
typedef SharedRoomMediaUploadWriter =
    Future<void> Function(SharedRoomMediaUploadRequest request);
typedef SharedRoomMediaObjectDeleter = Future<void> Function(String objectPath);
typedef SharedRoomMediaUrlResolver = Future<String> Function(String objectPath);
typedef SharedRoomMediaDataReader =
    Future<Uint8List?> Function(String objectPath, int maxBytes);

String _contentTypeFor(String filename, Uint8List bytes) {
  final extension = filename.contains('.')
      ? filename.substring(filename.lastIndexOf('.') + 1).toLowerCase()
      : '';
  final isJpeg =
      bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF;
  final isPng =
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A;
  final isWebp =
      bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;

  if ((extension == 'jpg' || extension == 'jpeg') && isJpeg) {
    return 'image/jpeg';
  }
  if (extension == 'png' && isPng) return 'image/png';
  if (extension == 'webp' && isWebp) return 'image/webp';

  throw const SharedRoomMediaException(
    SharedRoomMediaFailure.unsupportedFileType,
    'Shared photos must be JPEG, PNG, or WebP files.',
  );
}

/// Owns the narrow boundary between local source photos and their explicitly
/// selected public projections. It never writes source bytes into the save.
final class SharedRoomMediaService {
  SharedRoomMediaService({
    required SharedRoomMediaLocalReader readLocal,
    required SharedRoomMediaUploadWriter upload,
    required SharedRoomMediaObjectDeleter deleteObject,
    required SharedRoomMediaUrlResolver resolveUrl,
    SharedRoomMediaDataReader? downloadData,
  }) : this._(readLocal, upload, deleteObject, resolveUrl, downloadData);

  SharedRoomMediaService._(
    this._readLocal,
    this._upload,
    this._deleteObject,
    this._resolveUrl,
    this._downloadData,
  );

  factory SharedRoomMediaService.firebase({FirebaseStorage? storage}) {
    FirebaseStorage firebaseStorage() => storage ?? FirebaseStorage.instance;
    return SharedRoomMediaService(
      readLocal: journal_media.readForUpload,
      upload: (request) async {
        await firebaseStorage()
            .ref(request.objectPath)
            .putData(
              request.bytes,
              SettableMetadata(
                contentType: request.contentType,
                cacheControl: request.cacheControl,
                customMetadata: request.customMetadata,
              ),
            );
      },
      deleteObject: (objectPath) => firebaseStorage().ref(objectPath).delete(),
      resolveUrl: (objectPath) =>
          firebaseStorage().ref(objectPath).getDownloadURL(),
      downloadData: (objectPath, maxBytes) =>
          firebaseStorage().ref(objectPath).getData(maxBytes),
    );
  }

  static SharedRoomMediaService? _instance;
  static SharedRoomMediaService get instance =>
      _instance ??= SharedRoomMediaService.firebase();

  final SharedRoomMediaLocalReader _readLocal;
  final SharedRoomMediaUploadWriter _upload;
  final SharedRoomMediaObjectDeleter _deleteObject;
  final SharedRoomMediaUrlResolver _resolveUrl;
  final SharedRoomMediaDataReader? _downloadData;

  /// Uploads the app-created room PNG to a new immutable, opaque revision.
  /// The caller must already own [roomCode]; Storage rules bind its owner
  /// registry to [ownerKey] without exposing a Firebase uid to visitors.
  Future<String> uploadRoomPhoto({
    required String ownerKey,
    required String roomCode,
    required Uint8List bytes,
  }) async {
    final safeOwnerKey = _validatedOwnerKey(ownerKey);
    final safeRoomCode = _normalizedRoomCode(roomCode);
    if (bytes.isEmpty) {
      throw const SharedRoomMediaException(
        SharedRoomMediaFailure.emptyFile,
        'The room photo is empty.',
        slot: SharedRoomMediaSlot.room,
      );
    }
    if (bytes.length > maxPublicRoomPhotoBytes) {
      throw const SharedRoomMediaException(
        SharedRoomMediaFailure.fileTooLarge,
        'The room photo is larger than 800 KiB.',
        slot: SharedRoomMediaSlot.room,
      );
    }
    final contentType = _contentTypeFor('room.png', bytes);
    final objectPath = sharedRoomMediaObjectPath(
      ownerUid: safeOwnerKey,
      roomCode: safeRoomCode,
      slot: SharedRoomMediaSlot.room.wireName,
      generation: _newGeneration(),
    );
    final request = SharedRoomMediaUploadRequest(
      objectPath: objectPath,
      slot: SharedRoomMediaSlot.room,
      bytes: bytes,
      contentType: contentType,
      cacheControl: sharedRoomPhotoCacheControl,
      customMetadata: Map.unmodifiable({
        'ownerKey': safeOwnerKey,
        'roomCode': safeRoomCode,
        'slot': SharedRoomMediaSlot.room.wireName,
        'generation': objectPath.split('/').last,
      }),
    );
    try {
      await _upload(request);
      return objectPath;
    } catch (error) {
      try {
        await _deleteObject(objectPath);
      } catch (_) {
        // The unreferenced random revision remains unreachable from a room
        // document and can be collected by the server-side prefix cleanup.
      }
      throw SharedRoomMediaException(
        SharedRoomMediaFailure.uploadFailed,
        'The room photo could not be uploaded.',
        slot: SharedRoomMediaSlot.room,
        cause: error,
      );
    }
  }

  /// Uploads only explicitly selected slots and returns object paths suitable
  /// for a bounded room-share payload. URL tokens and bytes are never returned.
  Future<Map<SharedRoomMediaSlot, String>> syncSelected({
    required String ownerUid,
    required String roomCode,
    required Map<SharedRoomMediaSlot, String> selectedLocalFilenames,
  }) async {
    final safeOwnerUid = _validatedOwnerUid(ownerUid);
    final safeRoomCode = _normalizedRoomCode(roomCode);
    final pending = <SharedRoomMediaUploadRequest>[];

    // Stable ordering makes tests, logs, and partial network failures easier to
    // reason about. All local validation completes before either write starts.
    for (final slot in SharedRoomMediaSlot.values) {
      final filename = selectedLocalFilenames[slot];
      if (filename == null) continue;
      final objectPath = sharedRoomMediaObjectPath(
        ownerUid: safeOwnerUid,
        roomCode: safeRoomCode,
        slot: slot.wireName,
        generation: _newGeneration(),
      );

      late final journal_media.JournalMediaUploadData local;
      try {
        local = await _readLocal(filename);
      } on journal_media.JournalMediaReadException catch (error) {
        throw SharedRoomMediaException(
          SharedRoomMediaFailure.localFileUnavailable,
          error.message,
          slot: slot,
          cause: error,
        );
      } catch (error) {
        throw SharedRoomMediaException(
          SharedRoomMediaFailure.localFileUnavailable,
          'The selected ${slot.wireName} photo could not be read.',
          slot: slot,
          cause: error,
        );
      }

      if (local.bytes.isEmpty) {
        throw SharedRoomMediaException(
          SharedRoomMediaFailure.emptyFile,
          'The selected ${slot.wireName} photo is empty.',
          slot: slot,
        );
      }
      if (local.bytes.length > maxSharedRoomPhotoBytes) {
        throw SharedRoomMediaException(
          SharedRoomMediaFailure.fileTooLarge,
          'The selected ${slot.wireName} photo is larger than 3 MB.',
          slot: slot,
        );
      }

      late final String contentType;
      try {
        contentType = _contentTypeFor(local.filename, local.bytes);
      } on SharedRoomMediaException catch (error) {
        throw SharedRoomMediaException(
          error.failure,
          error.message,
          slot: slot,
          cause: error.cause,
        );
      }

      pending.add(
        SharedRoomMediaUploadRequest(
          objectPath: objectPath,
          slot: slot,
          bytes: local.bytes,
          contentType: contentType,
          cacheControl: sharedRoomPhotoCacheControl,
          customMetadata: Map.unmodifiable({
            'ownerUid': safeOwnerUid,
            'roomCode': safeRoomCode,
            'slot': slot.wireName,
            'generation': objectPath.split('/').last,
          }),
        ),
      );
    }

    final uploaded = <SharedRoomMediaSlot, String>{};
    for (final request in pending) {
      try {
        await _upload(request);
      } catch (error) {
        // A transport error can arrive after Storage accepted the bytes. New
        // revisions are still unreferenced, so delete every path this attempt
        // may have created before reporting failure.
        for (final objectPath in {...uploaded.values, request.objectPath}) {
          try {
            await _deleteObject(objectPath);
          } catch (_) {
            // The caller still reports failure. Stop Sharing/reset retain a
            // bounded cleanup path if a remote object did survive.
          }
        }
        throw SharedRoomMediaException(
          SharedRoomMediaFailure.uploadFailed,
          'The ${request.slot.wireName} photo could not be uploaded.',
          slot: request.slot,
          cause: error,
        );
      }
      uploaded[request.slot] = request.objectPath;
    }
    return Map.unmodifiable(uploaded);
  }

  /// Deletes validated exact object paths. Both legacy deterministic paths and
  /// new revisioned paths remain accepted so pre-release rooms migrate cleanly.
  Future<void> deleteObjectPaths(Iterable<String> objectPaths) async {
    final locations = <String, SharedRoomMediaLocation>{};
    for (final objectPath in objectPaths) {
      final location = SharedRoomMediaLocation.fromObjectPath(objectPath);
      locations[location.objectPath] = location;
    }

    for (final entry in locations.entries) {
      try {
        await _deleteObject(entry.key);
      } on FirebaseException catch (error) {
        if (error.code == 'object-not-found') continue;
        throw SharedRoomMediaException(
          SharedRoomMediaFailure.deleteFailed,
          'The ${entry.value.slot.wireName} photo could not be removed.',
          slot: entry.value.slot,
          cause: error,
        );
      } catch (error) {
        throw SharedRoomMediaException(
          SharedRoomMediaFailure.deleteFailed,
          'The ${entry.value.slot.wireName} photo could not be removed.',
          slot: entry.value.slot,
          cause: error,
        );
      }
    }
  }

  /// Legacy helper for deterministic pre-revision objects.
  Future<void> deleteSlots({
    required String ownerUid,
    required String roomCode,
    required Iterable<SharedRoomMediaSlot> slots,
  }) async {
    final safeOwnerUid = _validatedOwnerUid(ownerUid);
    final safeRoomCode = _normalizedRoomCode(roomCode);
    final paths = <SharedRoomMediaSlot, String>{};
    for (final slot in slots) {
      paths[slot] = sharedRoomMediaObjectPath(
        ownerUid: safeOwnerUid,
        roomCode: safeRoomCode,
        slot: slot.wireName,
      );
    }

    await deleteObjectPaths(paths.values);
  }

  /// Resolves a validated exact object path only when a visitor renders it.
  Future<String> downloadUrl(String objectPath) async {
    final location = SharedRoomMediaLocation.fromObjectPath(objectPath);
    try {
      return await _resolveUrl(location.objectPath);
    } catch (error) {
      throw SharedRoomMediaException(
        SharedRoomMediaFailure.downloadUrlFailed,
        'This shared photo is unavailable right now.',
        slot: location.slot,
        cause: error,
      );
    }
  }

  /// Fetches one validated object into a visit-only transient buffer.
  Future<Uint8List> downloadData(
    String objectPath, {
    int maxBytes = maxPublicRoomPhotoBytes,
  }) async {
    final location = SharedRoomMediaLocation.fromObjectPath(objectPath);
    final reader = _downloadData;
    if (location.slot != SharedRoomMediaSlot.room ||
        location.generation == null ||
        reader == null ||
        maxBytes < 1 ||
        maxBytes > maxPublicRoomPhotoBytes) {
      throw SharedRoomMediaException(
        SharedRoomMediaFailure.downloadUrlFailed,
        'This shared photo is unavailable right now.',
        slot: location.slot,
      );
    }
    try {
      final bytes = await reader(location.objectPath, maxBytes);
      if (bytes == null || bytes.isEmpty || bytes.length > maxBytes) {
        throw StateError('Shared room photo bytes were absent or too large.');
      }
      _contentTypeFor('room.png', bytes);
      return Uint8List.fromList(bytes).asUnmodifiableView();
    } catch (error) {
      throw SharedRoomMediaException(
        SharedRoomMediaFailure.downloadUrlFailed,
        'This shared photo is unavailable right now.',
        slot: location.slot,
        cause: error,
      );
    }
  }
}
