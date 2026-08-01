import 'package:flutter/material.dart';

import '../engine.dart';
import '../models.dart';
import 'achievements.dart';

/// Room styling (round-46) — the wall + floor looks you can choose for "Your
/// Space," the signature Webkinz "room theme" axis. Bought/applied with embers
/// like furniture, but EXCLUSIVE per surface (own many, display one). Every
/// palette stays warm + candlelit (never corporate-cold — the owner's taste).
/// The two `price: 0` styles are the free defaults, always owned.
class RoomStyle {
  const RoomStyle({
    required this.id,
    required this.name,
    required this.kind,
    required this.price,
    required this.a,
    required this.b,
    this.requires,
  });

  final String id;
  final String name;
  final RoomStyleKind kind;

  /// Cost in embers (0 = a free default).
  final int price;

  /// Gradient stops — wall paints top→low, floor paints top→bottom.
  final Color a, b;

  /// Achievement id gate (null → on the shelf from day one).
  final String? requires;
}

// The free default. `a` used to be 0xFF34262F, which is a mauve-pink at hue
// ~332 — the starter wall was reading cold before a single skin was bought.
// Top is dark espresso, bottom is warm walnut catching the hearth.
const _walnutWall = RoomStyle(
  id: 'wall_walnut',
  name: 'Walnut',
  kind: RoomStyleKind.wall,
  price: 0,
  a: Color(0xFF2A201C),
  b: Color(0xFF3B2C24),
);
const _oakFloor = RoomStyle(
  id: 'floor_oak',
  name: 'Oak',
  kind: RoomStyleKind.floor,
  price: 0,
  a: Color(0xFF4A3322),
  b: Color(0xFF2A190F),
);

final roomStyles = <RoomStyle>[
  _walnutWall,
  // Dusk, not magenta. The old pair (0xFF312339 / 0xFF3E2E48) sat at ~0.38
  // saturation and was single-handedly responsible for most of the cold-hue
  // area on the quest board. Same plum read, a third of the chroma.
  const RoomStyle(
    id: 'wall_plum',
    name: 'Plum Dusk',
    kind: RoomStyleKind.wall,
    price: 140,
    a: Color(0xFF272029),
    b: Color(0xFF322A38),
  ),
  const RoomStyle(
    id: 'wall_sage',
    name: 'Sage',
    kind: RoomStyleKind.wall,
    price: 160,
    a: Color(0xFF27302A),
    b: Color(0xFF333E36),
  ),
  const RoomStyle(
    id: 'wall_clay',
    name: 'Rose Clay',
    kind: RoomStyleKind.wall,
    price: 180,
    a: Color(0xFF3A2A2A),
    b: Color(0xFF47352F),
  ),
  const RoomStyle(
    id: 'wall_amber',
    name: 'Amber Limewash',
    kind: RoomStyleKind.wall,
    price: 200,
    a: Color(0xFF38281F),
    b: Color(0xFF4A3525),
  ),
  const RoomStyle(
    id: 'wall_indigo',
    name: 'Midnight',
    kind: RoomStyleKind.wall,
    price: 220,
    a: Color(0xFF232A3C),
    b: Color(0xFF2F3A55),
    requires: 'night-owl',
  ),
  const RoomStyle(
    id: 'wall_berry',
    name: 'Mulled Berry',
    kind: RoomStyleKind.wall,
    price: 260,
    a: Color(0xFF351F2B),
    b: Color(0xFF4A2B3B),
    requires: 'goal-getter',
  ),
  _oakFloor,
  const RoomStyle(
    id: 'floor_ash',
    name: 'Ashwood',
    kind: RoomStyleKind.floor,
    price: 110,
    a: Color(0xFF35322C),
    b: Color(0xFF24201A),
  ),
  const RoomStyle(
    id: 'floor_walnut',
    name: 'Dark Walnut',
    kind: RoomStyleKind.floor,
    price: 150,
    a: Color(0xFF2C1E16),
    b: Color(0xFF1C120C),
  ),
  const RoomStyle(
    id: 'floor_terra',
    name: 'Terracotta',
    kind: RoomStyleKind.floor,
    price: 190,
    a: Color(0xFF4A2C1E),
    b: Color(0xFF31180E),
  ),
  const RoomStyle(
    id: 'floor_maple',
    name: 'Honey Maple',
    kind: RoomStyleKind.floor,
    price: 210,
    a: Color(0xFF4A3421),
    b: Color(0xFF2D1D12),
  ),
  const RoomStyle(
    id: 'floor_cherry',
    name: 'Smoked Cherry',
    kind: RoomStyleKind.floor,
    price: 260,
    a: Color(0xFF43251F),
    b: Color(0xFF281511),
    requires: 'dedicated',
  ),
];

RoomStyle? roomStyleById(String id) {
  for (final s in roomStyles) {
    if (s.id == id) return s;
  }
  return null;
}

/// Free defaults and purchased styles count as owned.
bool isStyleOwned(GameState s, RoomStyle st) =>
    st.price == 0 || s.ownedStyles.contains(st.id);

/// Is this style currently on its surface?
bool isStyleApplied(GameState s, RoomStyle st) => st.kind == RoomStyleKind.wall
    ? s.wallStyle == st.id
    : s.floorStyle == st.id;

bool styleUnlocked(RoomStyle st, GameState s) =>
    st.requires == null || s.unlockedAchievements.contains(st.requires);

String? styleGateLabel(RoomStyle st) {
  if (st.requires == null) return null;
  for (final a in achievements) {
    if (a.id == st.requires) return a.title;
  }
  return 'a trophy';
}

/// The wall gradient colours the room should paint, from the selected style.
List<Color> wallColorsFor(GameState s) {
  final st = roomStyleById(s.wallStyle) ?? _walnutWall;
  return [st.a, st.b];
}

/// The floor gradient colours, from the selected style.
List<Color> floorColorsFor(GameState s) {
  final st = roomStyleById(s.floorStyle) ?? _oakFloor;
  return [st.a, st.b];
}

/// By-id colour lookups (used to render a VISITED space from its share data,
/// where there's no local GameState).
List<Color> wallColorsById(String? id) {
  final st = roomStyleById(id ?? '') ?? _walnutWall;
  return [st.a, st.b];
}

List<Color> floorColorsById(String? id) {
  final st = roomStyleById(id ?? '') ?? _oakFloor;
  return [st.a, st.b];
}
