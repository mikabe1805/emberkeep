import 'package:cloud_firestore/cloud_firestore.dart';

import 'content/creature_skins.dart';
import 'content/room_styles.dart';
import 'content/space_themes.dart';
import 'content/window_scenes.dart';

/// The intentionally tiny schema exposed by the opt-in space directory.
///
/// This is not a second room document: it is a rendering-only projection.
/// Keep it free of activity, progress, and private writing. The one optional
/// authored field is a separately saved public name; it is never copied from
/// the private Me profile and can only be changed by the moderated callable.
/// A tap is the only point at which the app retrieves the bearer-code room.
const int discoverableSpaceVersion = 2;
const int discoverableSpaceBucketCount = 1000000;
const int discoveryPublicNameMaxLength = 32;
const Duration discoverableSpaceLease = Duration(days: 30);
const Duration discoverableSpaceQuerySafetyMargin = Duration(minutes: 5);

const _roomCodePattern = r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$';
final _roomCode = RegExp(_roomCodePattern);
final _wallIds =
    roomStyles
        .where((style) => style.kind.name == 'wall')
        .map((style) => style.id)
        .toSet()
      ..addAll(spaceThemes.map((theme) => theme.id));
final _floorIds = roomStyles
    .where((style) => style.kind.name == 'floor')
    .map((style) => style.id)
    .toSet();
final _skinIds = creatureSkins.map((skin) => skin.id).toSet();
final _windowIds = windowViews.map((view) => view.id).toSet();

/// Stable, non-personal shuffle position for a room code.
///
/// It is deliberately not a ranking, timestamp, or activity signal. The
/// caller never renders the code; it is used only to rotate a small finite
/// handful of opt-in spaces without needing a popularity feed.
int discoverableSpaceBucket(String roomCode) {
  final clean = roomCode.trim().toUpperCase();
  if (!_roomCode.hasMatch(clean)) {
    throw ArgumentError.value(
      roomCode,
      'roomCode',
      'must be a valid room code',
    );
  }
  var hash = 17;
  for (final unit in clean.codeUnits) {
    hash = (hash * 31 + unit) % discoverableSpaceBucketCount;
  }
  return hash;
}

String _safeTitle(Object? value) {
  if (value is! String) return 'BLANK SLATE';
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'BLANK SLATE';
  return String.fromCharCodes(trimmed.runes.take(64));
}

String _safeId(Object? value, Set<String> allowed, String fallback) {
  final id = value is String ? value.trim() : '';
  return allowed.contains(id) ? id : fallback;
}

int _safeLevel(Object? value) {
  if (value is! num) return 1;
  return value.toInt().clamp(1, 9999);
}

/// Client-side normalization for display and local persistence. This is not a
/// moderation boundary: the callable applies the authoritative character,
/// contact-info, rate-limit, and blocked-term checks before publishing.
String sanitizeDiscoveryPublicName(Object? value) {
  if (value is! String) return '';
  final output = StringBuffer();
  var pendingSpace = false;
  var length = 0;
  for (final rune in value.runes) {
    if (rune <= 0x1f || rune == 0x7f) {
      pendingSpace = output.isNotEmpty;
      continue;
    }
    final character = String.fromCharCode(rune);
    if (RegExp(r'\s', unicode: true).hasMatch(character)) {
      pendingSpace = output.isNotEmpty;
      continue;
    }
    if (pendingSpace && length < discoveryPublicNameMaxLength) {
      output.write(' ');
      length += 1;
    }
    pendingSpace = false;
    if (length >= discoveryPublicNameMaxLength) break;
    output.write(character);
    length += 1;
  }
  return output.toString().trim();
}

/// Removes everything except the visual identity a person explicitly chooses
/// to place in the directory. The source may be the full private-share room
/// display, so this function must be an allowlist rather than a copy/remove
/// transform.
Map<String, dynamic> discoverableSpaceDisplay(
  Map<String, dynamic> room, {
  required String roomCode,
}) => {
  'v': discoverableSpaceVersion,
  'title': _safeTitle(room['title']),
  'level': _safeLevel(room['level']),
  'wall': _safeId(room['wall'], _wallIds, 'wall_walnut'),
  'floor': _safeId(room['floor'], _floorIds, 'floor_oak'),
  'skin': _safeId(room['skin'], _skinIds, 'ember_amber'),
  'window': _safeId(room['window'], _windowIds, 'moon'),
  'bucket': discoverableSpaceBucket(roomCode),
  // Owners may create the directory projection only in anonymous form.
  // Ordinary visual refreshes preserve the existing server-approved value.
  'publicName': '',
};

/// Sanitized directory card. [code] comes from the Firestore document ID and
/// is deliberately never shown in the UI; it only authorizes the subsequent
/// one-room visit after a user taps this card.
class DiscoverableSpaceSummary {
  const DiscoverableSpaceSummary({
    required this.code,
    required this.buildTitle,
    required this.level,
    required this.wall,
    required this.floor,
    required this.skin,
    required this.window,
    required this.bucket,
    this.publicName = '',
  });

  final String code;
  final String buildTitle;
  final int level;
  final String wall;
  final String floor;
  final String skin;
  final String window;
  final int bucket;
  final String publicName;

  /// Returns null for the wrong schema, an invalid document id, or a malformed
  /// shuffle field. Cosmetic ids fall back safely because renderers should not
  /// be able to receive arbitrary network values even if a legacy document is
  /// malformed.
  static DiscoverableSpaceSummary? fromDocument(
    String documentId,
    Map<String, dynamic> data, {
    DateTime? now,
  }) {
    final code = documentId.trim().toUpperCase();
    final expiresAt = data['expiresAt'];
    if (!_roomCode.hasMatch(code) ||
        data['v'] != discoverableSpaceVersion ||
        data['publicName'] is! String ||
        expiresAt is! Timestamp ||
        !expiresAt.toDate().isAfter((now ?? DateTime.now()).toUtc())) {
      return null;
    }
    final bucket = data['bucket'];
    if (bucket is! num ||
        bucket < 0 ||
        bucket >= discoverableSpaceBucketCount) {
      return null;
    }
    return DiscoverableSpaceSummary(
      code: code,
      buildTitle: _safeTitle(data['title']),
      level: _safeLevel(data['level']),
      wall: _safeId(data['wall'], _wallIds, 'wall_walnut'),
      floor: _safeId(data['floor'], _floorIds, 'floor_oak'),
      skin: _safeId(data['skin'], _skinIds, 'ember_amber'),
      window: _safeId(data['window'], _windowIds, 'moon'),
      bucket: bucket.toInt(),
      publicName: sanitizeDiscoveryPublicName(data['publicName']),
    );
  }
}
