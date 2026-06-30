import '../engine.dart';
import 'achievements.dart';

/// "Your Space" — the cozy room behind your avatar (round-40 scaffold), now a
/// SHOP you furnish by choice (round-42). You earn Embers (✦) by playing and
/// spend them on the pieces you want, in any order — customization is about
/// options, not a fixed unlock track. A few special pieces are gated behind an
/// achievement first (you still pay for them), so trophies open new shelves.
///
/// Painted in code (widgets/home_room.dart); each [id] is the contract the
/// room painter switches on. Ordered roughly cheap → dear so the shop reads as
/// an aspirational climb.
class FurnitureItem {
  const FurnitureItem({
    required this.id,
    required this.name,
    required this.blurb,
    required this.price,
    this.zone = 'Decor',
    this.requires,
  });

  final String id;

  /// Display name ("a reading lamp").
  final String name;

  /// A cozy one-line pitch for the shop card.
  final String blurb;

  /// Cost in Embers (✦).
  final int price;

  /// Grouping label in the shop (Floor / Light / Wall / Companion / Hearth).
  final String zone;

  /// Achievement id that must be earned before this piece can be bought
  /// (null → on the shelf from day one).
  final String? requires;
}

final furniture = <FurnitureItem>[
  FurnitureItem(
    id: 'rug',
    name: 'a warm rug',
    blurb: 'Underfoot warmth — the first thing that makes a room yours.',
    price: 40,
    zone: 'Floor',
  ),
  FurnitureItem(
    id: 'cushion',
    name: 'a floor cushion',
    blurb: 'A soft place to land at the end of a long day.',
    price: 70,
    zone: 'Floor',
  ),
  FurnitureItem(
    id: 'plant',
    name: 'a little plant',
    blurb: 'Something living that grows alongside you.',
    price: 90,
    zone: 'Decor',
  ),
  FurnitureItem(
    id: 'candles',
    name: 'a cluster of candles',
    blurb: 'Three small flames. The room breathes warmer.',
    price: 120,
    zone: 'Light',
  ),
  FurnitureItem(
    id: 'lamp',
    name: 'a reading lamp',
    blurb: 'A pool of gold to read by long after dark.',
    price: 160,
    zone: 'Light',
  ),
  FurnitureItem(
    id: 'garland',
    name: 'a string of lights',
    blurb: 'Warm bulbs draped across the wall — instant cozy.',
    price: 200,
    zone: 'Light',
    requires: 'well-rounded',
  ),
  FurnitureItem(
    id: 'shelf',
    name: 'a bookshelf',
    blurb: 'Room for everything you mean to read.',
    price: 240,
    zone: 'Wall',
  ),
  FurnitureItem(
    id: 'picture',
    name: 'a framed picture',
    blurb: 'A memory worth hanging where you can see it.',
    price: 300,
    zone: 'Wall',
    requires: 'goal-getter',
  ),
  FurnitureItem(
    id: 'chair',
    name: 'a cozy armchair',
    blurb: 'The good chair. It only gets comfier.',
    price: 380,
    zone: 'Floor',
  ),
  FurnitureItem(
    id: 'pet',
    name: 'a little companion',
    blurb: 'A small sleeping friend who keeps you company.',
    price: 460,
    zone: 'Companion',
    requires: 'perfect-day',
  ),
  FurnitureItem(
    id: 'hearth',
    name: 'a warm hearth',
    blurb: 'A real fire. The heart the whole room gathers around.',
    price: 600,
    zone: 'Hearth',
    requires: 'week-of-fire',
  ),
];

FurnitureItem? furnitureById(String id) {
  for (final f in furniture) {
    if (f.id == id) return f;
  }
  return null;
}

/// Is this piece's achievement gate satisfied (so it can be bought)?
bool furnitureUnlocked(FurnitureItem f, GameState s) =>
    f.requires == null || s.unlockedAchievements.contains(f.requires);

/// The trophy title behind a gated piece ("Week of Fire"), for the shop card.
String? furnitureGateLabel(FurnitureItem f) {
  if (f.requires == null) return null;
  for (final a in achievements) {
    if (a.id == f.requires) return a.title;
  }
  return 'an achievement';
}

/// The cheapest piece you don't own yet whose gate is open — what to save up
/// for next (drives the "saving up for…" caption on the Me page).
FurnitureItem? nextToBuy(GameState s) {
  for (final f in furniture) {
    if (!s.ownedFurniture.contains(f.id) && furnitureUnlocked(f, s)) return f;
  }
  return null;
}
