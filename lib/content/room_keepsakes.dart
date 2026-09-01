// Legacy wire values from the superseded room-mantel experiment.
//
// Build 39 deliberately gives these values no visible or semantic effect.
// The allowlist remains so older local saves, public-room documents, and
// older clients can continue to round-trip the bounded field without a risky
// schema migration during a visual polish release.

const maxRoomKeepsakes = 2;

const roomKeepsakeIds = <String>{
  'keepsake_books',
  'keepsake_sprout',
  'keepsake_camera',
  'keepsake_teapot',
  'keepsake_cat',
  'keepsake_record',
};

/// Keep wire order, discard duplicates and unknown values, and preserve the
/// historical two-value cap. Callers must not render or narrate the result.
List<String> sanitizeRoomKeepsakes(Object? value) {
  if (value is! Iterable) return const [];
  final selected = <String>[];
  for (final id in value) {
    if (id is String &&
        roomKeepsakeIds.contains(id) &&
        !selected.contains(id)) {
      selected.add(id);
      if (selected.length == maxRoomKeepsakes) break;
    }
  }
  return List.unmodifiable(selected);
}
