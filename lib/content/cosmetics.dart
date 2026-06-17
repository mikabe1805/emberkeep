import 'package:flutter/material.dart';

import '../tokens.dart';

/// How rare a cosmetic is — colors its chip + the loot bubble. Legendary
/// skins are never random drops; they're earned from signature achievements.
enum Rarity { common, rare, legendary }

Color rarityColor(Rarity r) => switch (r) {
      Rarity.common => Palette.textMid,
      Rarity.rare => Palette.info,
      Rarity.legendary => Palette.xpLight,
    };

/// What a found/earned cosmetic *does* once equipped — honest cosmetics
/// (RESEARCH-momentum.md §7). One look at a time; equipping recolors the
/// portrait aura and the completion sparks, or pins a badge. Keys match the
/// engine's loot table / achievement grants exactly (and are save-stable).
class Cosmetic {
  const Cosmetic({
    required this.name,
    required this.rarity,
    this.blurb,
    this.aura,
    this.particles,
    this.badge = false,
  });

  final String name;
  final Rarity rarity;

  /// A one-line flavor tag shown in the wardrobe.
  final String? blurb;

  /// Overrides the dominant-stat aura on the portrait when equipped.
  final Color? aura;

  /// Recolors the completion particle burst when equipped.
  final List<Color>? particles;

  /// Pins a small founder mark on the portrait.
  final bool badge;
}

const cosmetics = <String, Cosmetic>{
  // ── common drops ─────────────────────────────────────────────────
  'Ember Flame Skin': Cosmetic(
    name: 'Ember Flame Skin',
    rarity: Rarity.common,
    blurb: 'a coal that never quite goes out',
    aura: Color(0xFFE8743B),
    particles: [Color(0xFFE8743B), Color(0xFFF2CD93), Color(0xFFD8584B)],
  ),
  'Moss Hearth': Cosmetic(
    name: 'Moss Hearth',
    rarity: Rarity.common,
    blurb: 'quiet green, steady growth',
    aura: Color(0xFF8FB97F),
    particles: [Color(0xFF8FB97F), Color(0xFFBFE0A8), Color(0xFFF2CD93)],
  ),
  'Bloomlight': Cosmetic(
    name: 'Bloomlight',
    rarity: Rarity.common,
    blurb: 'a soft rose glow',
    aura: Color(0xFFE8A0A0),
    particles: [Color(0xFFE8A0A0), Color(0xFFF0C0B8), Color(0xFFF2CD93)],
  ),
  'Honeyed Halo': Cosmetic(
    name: 'Honeyed Halo',
    rarity: Rarity.common,
    blurb: 'warm as a kitchen at dawn',
    aura: Color(0xFFF2CD93),
    particles: [Color(0xFFF2CD93), Color(0xFFFFF4D9), Color(0xFFE0A865)],
  ),
  'Candle Gold': Cosmetic(
    name: 'Candle Gold',
    rarity: Rarity.common,
    blurb: 'the flame on a long night',
    aura: Color(0xFFE0A865),
    particles: [Color(0xFFE0A865), Color(0xFFF2CD93), Color(0xFFFFF4D9)],
  ),

  // ── rare drops ───────────────────────────────────────────────────
  'Aurora Particle Style': Cosmetic(
    name: 'Aurora Particle Style',
    rarity: Rarity.rare,
    blurb: 'northern lights, bottled',
    aura: Color(0xFF6FD0C0),
    particles: [Color(0xFF6FD0C0), Color(0xFF8FE39A), Color(0xFF9C8AE6)],
  ),
  'Midnight Theme Shard': Cosmetic(
    name: 'Midnight Theme Shard',
    rarity: Rarity.rare,
    blurb: 'the hush after midnight',
    aura: Color(0xFF8A7BD8),
    particles: [Color(0xFF8A7BD8), Color(0xFF6F8FE0), Color(0xFFB9A8F0)],
  ),
  'Periwinkle Frost': Cosmetic(
    name: 'Periwinkle Frost',
    rarity: Rarity.rare,
    blurb: 'cool, clear, focused',
    aura: Color(0xFF93A7E0),
    particles: [Color(0xFF93A7E0), Color(0xFFB8C8F0), Color(0xFFFFF4D9)],
  ),
  'Plum Nebula': Cosmetic(
    name: 'Plum Nebula',
    rarity: Rarity.rare,
    blurb: 'a galaxy you grew yourself',
    aura: Color(0xFFC9A3DC),
    particles: [Color(0xFFC9A3DC), Color(0xFFE0A0C8), Color(0xFFF2CD93)],
  ),
  'Storm Steel': Cosmetic(
    name: 'Storm Steel',
    rarity: Rarity.rare,
    blurb: 'forged in the dreaded days',
    aura: Color(0xFF9AABB8),
    particles: [Color(0xFF9AABB8), Color(0xFF93A7E0), Color(0xFFFFF4D9)],
  ),
  'Rosewood Glow': Cosmetic(
    name: 'Rosewood Glow',
    rarity: Rarity.rare,
    blurb: 'caramel and warm grain',
    aura: Color(0xFFC98A6A),
    particles: [Color(0xFFC98A6A), Color(0xFFE8A0A0), Color(0xFFF2CD93)],
  ),
  'Founder Badge Fragment': Cosmetic(
    name: 'Founder Badge Fragment',
    rarity: Rarity.rare,
    blurb: 'you were here early',
    aura: Color(0xFFF2CD93),
    badge: true,
  ),

  // ── legendary — earned from signature achievements only ──────────
  'Weeklong Ember': Cosmetic(
    name: 'Weeklong Ember',
    rarity: Rarity.legendary,
    blurb: 'seven days, unbroken',
    aura: Color(0xFFE8915A),
    particles: [Color(0xFFE8915A), Color(0xFFF2CD93), Color(0xFFD8584B)],
  ),
  'Eternal Flame': Cosmetic(
    name: 'Eternal Flame',
    rarity: Rarity.legendary,
    blurb: 'a month of fire — the brightest burn',
    aura: Color(0xFFFFB347),
    particles: [Color(0xFFFFB347), Color(0xFFFFF4D9), Color(0xFFE8743B)],
  ),
  'Spotless Glow': Cosmetic(
    name: 'Spotless Glow',
    rarity: Rarity.legendary,
    blurb: 'not a single day missed',
    aura: Color(0xFFFFF4D9),
    particles: [Color(0xFFFFF4D9), Color(0xFFF2CD93), Color(0xFFE0A865)],
  ),
  'Renaissance Aura': Cosmetic(
    name: 'Renaissance Aura',
    rarity: Rarity.legendary,
    blurb: 'whole in every direction',
    aura: Color(0xFFD8A8C0),
    particles: [Color(0xFFE8A0A0), Color(0xFFF2CD93), Color(0xFF8FBAB6)],
  ),
  'Marathoner’s Mantle': Cosmetic(
    name: 'Marathoner’s Mantle',
    rarity: Rarity.legendary,
    blurb: 'five hundred quests walked to the end',
    aura: Color(0xFF9C6BC0),
    particles: [Color(0xFF9C6BC0), Color(0xFFC9A3DC), Color(0xFFF2CD93)],
  ),
};

/// The equipped cosmetic, if any (null name → null).
Cosmetic? cosmeticFor(String? name) => name == null ? null : cosmetics[name];

/// Names that can drop randomly from quests — common + rare only; legendary
/// skins are earned from achievements, never dropped.
const droppableLoot = <String>[
  'Ember Flame Skin',
  'Moss Hearth',
  'Bloomlight',
  'Honeyed Halo',
  'Candle Gold',
  'Aurora Particle Style',
  'Midnight Theme Shard',
  'Periwinkle Frost',
  'Plum Nebula',
  'Storm Steel',
  'Rosewood Glow',
  'Founder Badge Fragment',
];
