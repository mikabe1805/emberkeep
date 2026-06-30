import '../engine.dart';

/// "Your Space" — the cozy room behind your avatar that fills in as you grow
/// (round-40, the home/world scaffold). Every piece is EARNED by play, never
/// bought (the locked no-money-monetization rule). Painted in code for now
/// (widgets/home_room.dart); the ids are the contract the painter switches on.
///
/// Ordered easiest → hardest so "next up" surfaces the nearest piece.
class FurnitureItem {
  const FurnitureItem(this.id, this.name, this.hint, this.unlocked);
  final String id;
  final String name;

  /// How it's earned, in plain words ("level 4", "a perfect day").
  final String hint;
  final bool Function(GameState) unlocked;
}

final furniture = <FurnitureItem>[
  FurnitureItem('rug', 'a warm rug', 'level 2', (s) => s.level >= 2),
  FurnitureItem('plant', 'a little plant', 'a perfect day',
      (s) => s.perfectDays >= 1),
  FurnitureItem('lamp', 'a reading lamp', 'level 4', (s) => s.level >= 4),
  FurnitureItem('shelf', 'a bookshelf', '20 quests done',
      (s) => s.totalCompletions >= 20),
  FurnitureItem('picture', 'a framed picture', 'level 6', (s) => s.level >= 6),
  FurnitureItem('chair', 'a cozy armchair', '5 perfect days',
      (s) => s.perfectDays >= 5),
  FurnitureItem('pet', 'a little companion', 'level 12', (s) => s.level >= 12),
  FurnitureItem('hearth', 'a warm hearth', 'level 16', (s) => s.level >= 16),
];

/// The set of unlocked piece-ids (what the room painter draws).
Set<String> unlockedFurniture(GameState s) =>
    {for (final f in furniture) if (f.unlocked(s)) f.id};

/// The nearest still-locked piece (for the "next: a lamp at level 4" caption),
/// or null once the room is full.
FurnitureItem? nextFurniture(GameState s) {
  for (final f in furniture) {
    if (!f.unlocked(s)) return f;
  }
  return null;
}
