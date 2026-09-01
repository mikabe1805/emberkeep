import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The one private photograph that can be placed in the keeper's room.
///
/// Its bytes are an app-created PNG, never a gallery path or an image URL.
/// It has no automatic cloud representation. A separate publisher may upload
/// this canonical value only after the keeper explicitly opts into showing it
/// in the shared room; GameState retains consent and the acknowledged handle,
/// never these source bytes.
@immutable
final class RoomPhotoData {
  RoomPhotoData({
    required Uint8List bytes,
    this.fillFrame = false,
    this.alignment = Alignment.center,
    required this.pixelWidth,
    required this.pixelHeight,
  }) : bytes = Uint8List.fromList(bytes).asUnmodifiableView() {
    _validatePresentation(alignment, pixelWidth, pixelHeight);
  }

  RoomPhotoData._trusted({
    required this.bytes,
    required this.fillFrame,
    required this.alignment,
    required this.pixelWidth,
    required this.pixelHeight,
  }) {
    _validatePresentation(alignment, pixelWidth, pixelHeight);
  }

  /// A stable, read-only view. One copy is made at import time; framing edits
  /// can then retain the exact same memory-image cache key.
  final Uint8List bytes;
  final bool fillFrame;
  final Alignment alignment;
  final int pixelWidth;
  final int pixelHeight;

  RoomPhotoData copyWith({bool? fillFrame, Alignment? alignment}) =>
      RoomPhotoData._trusted(
        bytes: bytes,
        fillFrame: fillFrame ?? this.fillFrame,
        alignment: alignment ?? this.alignment,
        pixelWidth: pixelWidth,
        pixelHeight: pixelHeight,
      );

  static void _validatePresentation(
    Alignment alignment,
    int pixelWidth,
    int pixelHeight,
  ) {
    if (pixelWidth < 1 || pixelHeight < 1) {
      throw ArgumentError.value(
        '$pixelWidth x $pixelHeight',
        'pixel dimensions',
        'must be positive',
      );
    }
    if (!alignment.x.isFinite ||
        !alignment.y.isFinite ||
        alignment.x < -1 ||
        alignment.x > 1 ||
        alignment.y < -1 ||
        alignment.y > 1) {
      throw ArgumentError.value(
        alignment,
        'alignment',
        'must be finite and bounded',
      );
    }
  }
}

typedef RoomPhotoPicker = Future<XFile?> Function();
typedef RoomPhotoCodec = Future<RoomPhotoData> Function(Uint8List bytes);
typedef RoomPhotoPreferences = Future<SharedPreferences> Function();

/// A deliberately small local persistence boundary for [RoomPhotoData].
///
/// This has its own SharedPreferences key rather than using Storage: Storage's
/// blob is mirrored to Firebase and exported as a backup. The source remains
/// private to this install; an explicit shared-room action can upload a bounded
/// copy without moving this local record into ordinary save or backup data.
final class RoomPhotoStore extends ChangeNotifier {
  RoomPhotoStore({
    RoomPhotoPicker? picker,
    RoomPhotoCodec? codec,
    RoomPhotoPreferences? preferences,
  }) : _picker = picker ?? _pickFromSystemLibrary,
       _codec = codec ?? canonicalizeRoomPhoto,
       _preferences = preferences ?? SharedPreferences.getInstance;

  static final RoomPhotoStore instance = RoomPhotoStore();

  static const storageKey = 'emberkeep_private_room_photo_v1';
  static const maxInputBytes = 20 * 1024 * 1024;
  static const maxCanonicalBytes = 800 * 1024;
  static const maxDimension = 1200;

  final RoomPhotoPicker _picker;
  final RoomPhotoCodec _codec;
  final RoomPhotoPreferences _preferences;

  RoomPhotoData? _photo;
  String? _ownerKey;
  bool _loaded = false;
  String? _lastError;
  int _generation = 0;
  int _writeGeneration = 0;
  Future<void> _writeTail = Future<void>.value();

  RoomPhotoData? get photo => _photo;
  String? get ownerKey => _ownerKey;
  bool get loaded => _loaded;

  /// A short user-displayable explanation for the most recent failed pick or
  /// save. A normal picker cancellation leaves this null.
  String? get lastError => _lastError;

  /// Makes [ownerKey] the sole owner whose photo may be displayed.
  ///
  /// Hiding happens before any asynchronous preferences work. The generation
  /// gate means a slow read for a previous account cannot repaint this one.
  Future<void> activateOwner(String ownerKey) async {
    final normalized = _validOwner(ownerKey);
    final generation = ++_generation;
    _ownerKey = normalized;
    _photo = null;
    _loaded = false;
    _lastError = null;
    notifyListeners();

    try {
      // If a reset is already clearing the private key, do not read its old
      // value between the reset's synchronous hide and asynchronous removal.
      await _writeTail;
      if (generation != _generation || _ownerKey != normalized) return;
      final prefs = await _preferences();
      if (generation != _generation || _ownerKey != normalized) return;
      final candidate = _readStored(prefs.getString(storageKey), normalized);
      RoomPhotoData? decoded;
      if (candidate != null) {
        // Decode the persisted PNG before handing it to the renderer. This
        // turns a corrupt preference value into an absent photo, rather than a
        // deferred rendering exception.
        decoded = await _codec(candidate.bytes);
        if (decoded.pixelWidth != candidate.pixelWidth ||
            decoded.pixelHeight != candidate.pixelHeight) {
          decoded = RoomPhotoData(
            bytes: decoded.bytes,
            fillFrame: candidate.fillFrame,
            alignment: candidate.alignment,
            pixelWidth: decoded.pixelWidth,
            pixelHeight: decoded.pixelHeight,
          );
        } else {
          decoded = RoomPhotoData(
            bytes: decoded.bytes,
            fillFrame: candidate.fillFrame,
            alignment: candidate.alignment,
            pixelWidth: candidate.pixelWidth,
            pixelHeight: candidate.pixelHeight,
          );
        }
      }
      if (generation != _generation || _ownerKey != normalized) return;
      _photo = decoded;
    } catch (_) {
      // Do not erase a record just because SharedPreferences was temporarily
      // unavailable. A later owner activation can retry it.
      if (generation == _generation && _ownerKey == normalized) {
        _lastError = 'The room photo could not be opened on this device.';
      }
    } finally {
      if (generation == _generation && _ownerKey == normalized) {
        _loaded = true;
        notifyListeners();
      }
    }
  }

  /// Opens the device library and returns one canonical PNG draft.
  ///
  /// It never changes persisted state. The caller must explicitly [save] the
  /// returned draft, which makes cancel and a failed crop harmless to the room
  /// already on display.
  Future<RoomPhotoData?> pickFromLibrary() async {
    final ownerAtStart = _ownerKey;
    final generation = _generation;
    _lastError = null;
    try {
      final picked = await _picker();
      if (picked == null) return null;
      return _preparePickedFile(picked, ownerAtStart, generation);
    } catch (_) {
      if (generation == _generation && ownerAtStart == _ownerKey) {
        _lastError = 'That photo could not be used. Try another image.';
        notifyListeners();
      }
      return null;
    }
  }

  /// Prepares a file returned by a platform picker into a one-time draft.
  ///
  /// The Android lost-picker coordinator uses this after it has confirmed that
  /// the pending picker intent belonged to the room photo. It must present the
  /// returned draft for confirmation and call [save] separately; recovery
  /// never changes the person's room by itself.
  Future<RoomPhotoData?> preparePickedFile(XFile picked) =>
      _preparePickedFile(picked, _ownerKey, _generation);

  Future<RoomPhotoData?> _preparePickedFile(
    XFile picked,
    String? ownerAtStart,
    int generation,
  ) async {
    _lastError = null;
    try {
      final length = await picked.length();
      if (length > maxInputBytes) {
        throw const RoomPhotoException(
          'Choose a photo smaller than 20 MB.',
          RoomPhotoFailure.inputTooLarge,
        );
      }
      final bytes = await picked.readAsBytes();
      if (bytes.length > maxInputBytes) {
        throw const RoomPhotoException(
          'Choose a photo smaller than 20 MB.',
          RoomPhotoFailure.inputTooLarge,
        );
      }
      final data = await _codec(bytes);
      // An old picker result belongs to the account that opened the sheet. It
      // must not become a draft for whoever signed in while it was open.
      if (generation != _generation || ownerAtStart != _ownerKey) return null;
      return data;
    } on RoomPhotoException catch (error) {
      if (generation == _generation && ownerAtStart == _ownerKey) {
        _lastError = error.message;
        notifyListeners();
      }
      return null;
    } catch (_) {
      if (generation == _generation && ownerAtStart == _ownerKey) {
        _lastError = 'That photo could not be used. Try another image.';
        notifyListeners();
      }
      return null;
    }
  }

  /// Commits [photo] only when [ownerKey] is still the active account.
  ///
  /// The preferences write completes before the in-memory publish. A failed
  /// write therefore leaves the current visible photo and persisted record
  /// unchanged.
  Future<void> save(RoomPhotoData? photo, {required String ownerKey}) async {
    final normalized = _validOwner(ownerKey);
    if (_ownerKey != normalized) {
      throw const RoomPhotoException(
        'This room changed before the photo could be saved.',
        RoomPhotoFailure.staleOwner,
      );
    }
    final generation = _generation;
    final writeGeneration = ++_writeGeneration;
    final beforeThisWrite = _writeTail;
    final settled = Completer<void>();
    _writeTail = settled.future;
    try {
      final canonical = photo == null
          ? null
          : await _canonicalWithPresentation(photo);
      await beforeThisWrite;
      if (generation != _generation || _ownerKey != normalized) {
        throw const RoomPhotoException(
          'This room changed before the photo could be saved.',
          RoomPhotoFailure.staleOwner,
        );
      }
      // A newer explicit save wins. This includes the case where its codec
      // finished first: waiting in this queue preserves call ordering while
      // preventing an older pending preferences write from landing last.
      if (writeGeneration != _writeGeneration) {
        throw const RoomPhotoException(
          'A newer room-photo change replaced this one.',
          RoomPhotoFailure.superseded,
        );
      }
      final encoded = canonical == null
          ? null
          : _encodeStored(normalized, canonical);
      final prefs = await _preferences();
      if (generation != _generation || _ownerKey != normalized) {
        throw const RoomPhotoException(
          'This room changed before the photo could be saved.',
          RoomPhotoFailure.staleOwner,
        );
      }
      if (writeGeneration != _writeGeneration) {
        throw const RoomPhotoException(
          'A newer room-photo change replaced this one.',
          RoomPhotoFailure.superseded,
        );
      }
      final saved = encoded == null
          ? await prefs.remove(storageKey)
          : await prefs.setString(storageKey, encoded);
      if (!saved) {
        throw const RoomPhotoException(
          'This device could not save the room photo.',
          RoomPhotoFailure.persistence,
        );
      }
      if (generation != _generation || _ownerKey != normalized) {
        throw const RoomPhotoException(
          'This room changed before the photo could be saved.',
          RoomPhotoFailure.staleOwner,
        );
      }
      if (writeGeneration != _writeGeneration) {
        throw const RoomPhotoException(
          'A newer room-photo change replaced this one.',
          RoomPhotoFailure.superseded,
        );
      }
      _photo = canonical;
      _loaded = true;
      _lastError = null;
      notifyListeners();
    } on RoomPhotoException {
      rethrow;
    } catch (_) {
      throw const RoomPhotoException(
        'This device could not save the room photo.',
        RoomPhotoFailure.persistence,
      );
    } finally {
      if (!settled.isCompleted) settled.complete();
    }
  }

  Future<RoomPhotoData> _canonicalWithPresentation(RoomPhotoData draft) async {
    if (draft.bytes.length > maxCanonicalBytes ||
        draft.pixelWidth > maxDimension ||
        draft.pixelHeight > maxDimension ||
        !draft.alignment.x.isFinite ||
        !draft.alignment.y.isFinite ||
        draft.alignment.x < -1 ||
        draft.alignment.x > 1 ||
        draft.alignment.y < -1 ||
        draft.alignment.y > 1) {
      throw const RoomPhotoException(
        'That photo is not a valid room-photo draft.',
        RoomPhotoFailure.unsupported,
      );
    }
    final canonical = await _codec(draft.bytes);
    if (canonical.bytes.length > maxCanonicalBytes ||
        canonical.pixelWidth > maxDimension ||
        canonical.pixelHeight > maxDimension) {
      throw const RoomPhotoException(
        'That photo could not be made small enough for this room.',
        RoomPhotoFailure.outputTooLarge,
      );
    }
    return RoomPhotoData(
      bytes: canonical.bytes,
      fillFrame: draft.fillFrame,
      alignment: draft.alignment,
      pixelWidth: canonical.pixelWidth,
      pixelHeight: canonical.pixelHeight,
    );
  }

  /// Removes the one local preference record and immediately hides the photo.
  Future<bool> clearAll() async {
    ++_generation;
    ++_writeGeneration;
    final beforeThisWrite = _writeTail;
    final settled = Completer<void>();
    _writeTail = settled.future;
    _photo = null;
    _loaded = true;
    _lastError = null;
    notifyListeners();
    try {
      await beforeThisWrite;
      final cleared = await (await _preferences()).remove(storageKey);
      return cleared;
    } catch (_) {
      // The visible image remains hidden, but callers such as Start over need
      // the false result so they never claim confirmed erasure.
      return false;
    } finally {
      if (!settled.isCompleted) settled.complete();
    }
  }

  static String _validOwner(String value) {
    final clean = value.trim();
    if (clean.isEmpty || clean.length > 180) {
      throw ArgumentError.value(value, 'ownerKey', 'must be a bounded ID');
    }
    return clean;
  }

  static String _encodeStored(String ownerKey, RoomPhotoData photo) =>
      jsonEncode({
        'v': 1,
        'ownerKey': ownerKey,
        'png': base64Encode(photo.bytes),
        'fillFrame': photo.fillFrame,
        'alignmentX': photo.alignment.x,
        'alignmentY': photo.alignment.y,
        'pixelWidth': photo.pixelWidth,
        'pixelHeight': photo.pixelHeight,
      });

  static RoomPhotoData? _readStored(String? raw, String expectedOwner) {
    if (raw == null || raw.length > maxCanonicalBytes * 2) return null;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      if (map['v'] != 1 || map['ownerKey'] != expectedOwner) return null;
      final encoded = map['png'];
      if (encoded is! String || encoded.length > maxCanonicalBytes * 2) {
        return null;
      }
      final bytes = base64Decode(encoded);
      final width = map['pixelWidth'];
      final height = map['pixelHeight'];
      final x = map['alignmentX'];
      final y = map['alignmentY'];
      if (bytes.isEmpty ||
          bytes.length > maxCanonicalBytes ||
          width is! int ||
          height is! int ||
          width < 1 ||
          height < 1 ||
          width > maxDimension ||
          height > maxDimension ||
          x is! num ||
          y is! num ||
          !x.isFinite ||
          !y.isFinite ||
          x < -1 ||
          x > 1 ||
          y < -1 ||
          y > 1) {
        return null;
      }
      return RoomPhotoData(
        bytes: bytes,
        fillFrame: map['fillFrame'] == true,
        alignment: Alignment(x.toDouble(), y.toDouble()),
        pixelWidth: width,
        pixelHeight: height,
      );
    } catch (_) {
      return null;
    }
  }
}

enum RoomPhotoFailure {
  inputTooLarge,
  unsupported,
  outputTooLarge,
  staleOwner,
  superseded,
  persistence,
}

final class RoomPhotoException implements Exception {
  const RoomPhotoException(this.message, this.failure);

  final String message;
  final RoomPhotoFailure failure;

  @override
  String toString() => message;
}

Future<XFile?> _pickFromSystemLibrary() => ImagePicker().pickImage(
  source: ImageSource.gallery,
  maxWidth: 1600,
  maxHeight: 1600,
  imageQuality: 82,
);

/// Decodes a gallery image and creates an EXIF-free, bounded PNG for room use.
///
/// The image engine accepts the platform-supported JPEG, PNG, and HEIC inputs;
/// its PNG output has no gallery filename, path, EXIF, or original orientation
/// metadata. Every engine resource is disposed before this future completes.
Future<RoomPhotoData> canonicalizeRoomPhoto(Uint8List input) async {
  if (input.isEmpty || input.length > RoomPhotoStore.maxInputBytes) {
    throw const RoomPhotoException(
      'Choose a photo smaller than 20 MB.',
      RoomPhotoFailure.inputTooLarge,
    );
  }
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    late final int sourceWidth;
    late final int sourceHeight;
    if (kIsWeb) {
      // On web ImageDescriptor.encoded deliberately does not expose width or
      // height. Decode once to enforce our source bounds, then dispose it
      // before the bounded encode below.
      ui.Codec? sourceCodec;
      ui.Image? sourceImage;
      try {
        sourceCodec = await ui.instantiateImageCodec(input);
        final frame = await sourceCodec.getNextFrame();
        sourceImage = frame.image;
        sourceWidth = sourceImage.width;
        sourceHeight = sourceImage.height;
      } finally {
        sourceImage?.dispose();
        sourceCodec?.dispose();
      }
    } else {
      buffer = await ui.ImmutableBuffer.fromUint8List(input);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      sourceWidth = descriptor.width;
      sourceHeight = descriptor.height;
    }
    if (sourceWidth < 1 ||
        sourceHeight < 1 ||
        sourceWidth > 16000 ||
        sourceHeight > 16000 ||
        sourceWidth * sourceHeight > 64000000) {
      throw const RoomPhotoException(
        'That photo is too large to prepare safely on this device.',
        RoomPhotoFailure.unsupported,
      );
    }
    final sourceLongest = sourceWidth > sourceHeight
        ? sourceWidth
        : sourceHeight;
    final longestAllowed = sourceLongest < RoomPhotoStore.maxDimension
        ? sourceLongest
        : RoomPhotoStore.maxDimension;
    final candidates = <int>{
      longestAllowed,
      for (final size in const [1200, 1000, 800, 640, 480, 360, 256])
        if (size <= longestAllowed) size,
    };
    for (final longest in candidates) {
      final scale = longest / sourceLongest;
      final targetWidth = (sourceWidth * scale)
          .round()
          .clamp(1, longest)
          .toInt();
      final targetHeight = (sourceHeight * scale)
          .round()
          .clamp(1, longest)
          .toInt();
      ui.Codec? codec;
      ui.Image? image;
      try {
        codec = kIsWeb
            ? await ui.instantiateImageCodec(
                input,
                targetWidth: targetWidth,
                targetHeight: targetHeight,
                allowUpscaling: false,
              )
            : await descriptor!.instantiateCodec(
                targetWidth: targetWidth,
                targetHeight: targetHeight,
              );
        final frame = await codec.getNextFrame();
        image = frame.image;
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) continue;
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        if (bytes.length <= RoomPhotoStore.maxCanonicalBytes) {
          return RoomPhotoData(
            bytes: bytes,
            pixelWidth: image.width,
            pixelHeight: image.height,
          );
        }
      } finally {
        image?.dispose();
        codec?.dispose();
      }
    }
    throw const RoomPhotoException(
      'That photo could not be made small enough for this room.',
      RoomPhotoFailure.outputTooLarge,
    );
  } on RoomPhotoException {
    rethrow;
  } catch (_) {
    throw const RoomPhotoException(
      'That photo format is not supported on this device.',
      RoomPhotoFailure.unsupported,
    );
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}
