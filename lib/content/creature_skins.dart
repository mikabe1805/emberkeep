import 'package:flutter/material.dart';

import '../engine.dart';
import 'achievements.dart';

/// Creature skins (round-47) — the colour of your ember itself, the most
/// personal customization there is. Bought/worn with embers, exclusive like
/// room styles (own many, wear one). Every skin keeps the glassy candlelit
/// shading; only the hue changes. [colors] are the four body-gradient stops,
/// lightest → darkest (specular, mid, deep, rim) — feet, belly, catchlights
/// and the flame all derive from them so the whole creature stays cohesive.
class CreatureSkin {
  const CreatureSkin({
    required this.id,
    required this.name,
    required this.price,
    required this.colors,
    this.requires,
  });

  final String id;
  final String name;

  /// Cost in embers (0 = the free default).
  final int price;

  /// Four stops light→dark.
  final List<Color> colors;

  /// Achievement id gate (null → always on the shelf).
  final String? requires;
}

const _amber = CreatureSkin(
  id: 'ember_amber',
  name: 'Ember',
  price: 0,
  colors: [Color(0xFFFFF4D9), Color(0xFFF2CD93), Color(0xFFC58A4E), Color(0xFF6E451F)],
);

final creatureSkins = <CreatureSkin>[
  _amber,
  const CreatureSkin(
    id: 'rose_quartz',
    name: 'Rose Quartz',
    price: 160,
    colors: [Color(0xFFFFE9EC), Color(0xFFF4B8C4), Color(0xFFD77E96), Color(0xFF7E3A50)],
  ),
  const CreatureSkin(
    id: 'mint_glass',
    name: 'Mint',
    price: 180,
    colors: [Color(0xFFE9FBEF), Color(0xFFAEE6C6), Color(0xFF6FC79B), Color(0xFF2F6E55)],
  ),
  const CreatureSkin(
    id: 'periwinkle',
    name: 'Periwinkle',
    price: 200,
    colors: [Color(0xFFE9ECFF), Color(0xFFBCC4F4), Color(0xFF8E9AE0), Color(0xFF49507E)],
  ),
  const CreatureSkin(
    id: 'lilac',
    name: 'Lilac',
    price: 220,
    colors: [Color(0xFFF3E9FF), Color(0xFFD8BCF4), Color(0xFFB68EE0), Color(0xFF60497E)],
  ),
  const CreatureSkin(
    id: 'slate',
    name: 'Slate',
    price: 240,
    colors: [Color(0xFFEDF1F4), Color(0xFFB8C2C9), Color(0xFF8997A1), Color(0xFF47535B)],
    requires: 'well-rounded',
  ),
  const CreatureSkin(
    id: 'gilded',
    name: 'Gilded',
    price: 320,
    colors: [Color(0xFFFFF6D9), Color(0xFFFFE08A), Color(0xFFE8B44E), Color(0xFF8A6A1E)],
    requires: 'ascendant',
  ),
];

CreatureSkin? creatureSkinById(String id) {
  for (final s in creatureSkins) {
    if (s.id == id) return s;
  }
  return null;
}

bool isSkinOwned(GameState s, CreatureSkin sk) =>
    sk.price == 0 || s.ownedSkins.contains(sk.id);

bool isSkinApplied(GameState s, CreatureSkin sk) => s.creatureSkin == sk.id;

bool skinUnlocked(CreatureSkin sk, GameState s) =>
    sk.requires == null || s.unlockedAchievements.contains(sk.requires);

String? skinGateLabel(CreatureSkin sk) {
  if (sk.requires == null) return null;
  for (final a in achievements) {
    if (a.id == sk.requires) return a.title;
  }
  return 'a trophy';
}

/// The four body-gradient colours the portrait should paint, from the worn
/// skin (falls back to Ember).
List<Color> creatureColorsFor(GameState s) =>
    (creatureSkinById(s.creatureSkin) ?? _amber).colors;

/// By-id lookup (used to render a VISITED space, which has no GameState).
List<Color> creatureColorsById(String? id) =>
    (creatureSkinById(id ?? '') ?? _amber).colors;
