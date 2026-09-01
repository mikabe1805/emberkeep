import 'package:flutter/material.dart';

import '../engine.dart';
import 'achievements.dart';
import 'cosmetics.dart';

/// Hearth-flame colours (round-47 creature skins, repurposed round-62 for the
/// keep) — the colour of the fire in your space's hearth, the most personal
/// customization there is. Bought with embers, exclusive (own many, choose
/// one). [colors] are four warm stops, light → deep; the flame and its
/// firelight pool take the mid-tone, so a chosen colour warms the whole keep.
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
  colors: [
    Color(0xFFFFF4D9),
    Color(0xFFFFC44F),
    Color(0xFFF06A1A),
    Color(0xFF7E2415),
  ],
);

final creatureSkins = <CreatureSkin>[
  _amber,
  const CreatureSkin(
    id: 'rose_quartz',
    name: 'Rose Quartz',
    price: 160,
    colors: [
      Color(0xFFFFE9EC),
      Color(0xFFF4B8C4),
      Color(0xFFD77E96),
      Color(0xFF7E3A50),
    ],
  ),
  const CreatureSkin(
    id: 'mint_glass',
    name: 'Mint',
    price: 180,
    colors: [
      Color(0xFFE9FBEF),
      Color(0xFFAEE6C6),
      Color(0xFF6FC79B),
      Color(0xFF2F6E55),
    ],
  ),
  const CreatureSkin(
    id: 'periwinkle',
    name: 'Periwinkle',
    price: 200,
    colors: [
      Color(0xFFE9ECFF),
      Color(0xFFBCC4F4),
      Color(0xFF8E9AE0),
      Color(0xFF49507E),
    ],
  ),
  const CreatureSkin(
    id: 'lilac',
    name: 'Lilac',
    price: 220,
    colors: [
      Color(0xFFF3E9FF),
      Color(0xFFD8BCF4),
      Color(0xFFB68EE0),
      Color(0xFF60497E),
    ],
  ),
  const CreatureSkin(
    id: 'sunstone',
    name: 'Sunstone',
    price: 260,
    colors: [
      Color(0xFFFFF1E2),
      Color(0xFFF7C19F),
      Color(0xFFE67F5F),
      Color(0xFF7C3A2B),
    ],
  ),
  const CreatureSkin(
    id: 'sea_glass',
    name: 'Sea Glass',
    price: 280,
    colors: [
      Color(0xFFEAFBF7),
      Color(0xFFA7DED2),
      Color(0xFF54B5A3),
      Color(0xFF285E56),
    ],
    requires: 'proof-positive',
  ),
  const CreatureSkin(
    id: 'moon_pearl',
    name: 'Moonpearl',
    price: 300,
    colors: [
      Color(0xFFFFF9ED),
      Color(0xFFE8D9C4),
      Color(0xFFC5AE98),
      Color(0xFF6C584B),
    ],
    requires: 'perfect-day',
  ),
  const CreatureSkin(
    id: 'slate',
    name: 'Slate',
    price: 240,
    colors: [
      Color(0xFFEDF1F4),
      Color(0xFFB8C2C9),
      Color(0xFF8997A1),
      Color(0xFF47535B),
    ],
    requires: 'well-rounded',
  ),
  const CreatureSkin(
    id: 'gilded',
    name: 'Gilded',
    price: 320,
    colors: [
      Color(0xFFFFF6D9),
      Color(0xFFFFE08A),
      Color(0xFFE8B44E),
      Color(0xFF8A6A1E),
    ],
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

/// ASCII-only public ids for found flames. Cosmetic display names remain
/// save-stable local copy, while shared-room rules never have to parse spaces,
/// punctuation, or the typographic apostrophe in Marathoner's Mantle.
const _foundFlameIds = <String, String>{
  'Ember Flame Skin': 'found_ember',
  'Moss Hearth': 'found_moss',
  'Bloomlight': 'found_bloom',
  'Honeyed Halo': 'found_honey',
  'Candle Gold': 'found_candle',
  'Aurora Particle Style': 'found_aurora',
  'Midnight Theme Shard': 'found_midnight',
  'Periwinkle Frost': 'found_periwinkle',
  'Plum Nebula': 'found_plum',
  'Storm Steel': 'found_storm',
  'Rosewood Glow': 'found_rosewood',
  'Founder Badge Fragment': 'found_founder',
  'Weeklong Ember': 'found_weeklong',
  'Eternal Flame': 'found_eternal',
  'Spotless Glow': 'found_spotless',
  'Renaissance Aura': 'found_renaissance',
  'Marathoner’s Mantle': 'found_marathoner',
};

/// The bounded flame identities that may cross a room-sharing boundary.
///
/// A found wardrobe cosmetic is published as its stable `found_*` flame id,
/// rather than its private inventory name. Keeping this set beside that
/// translation prevents an owner room and a Discover card from disagreeing.
final Set<String> publishedFlameSkinIds = Set.unmodifiable([
  ...creatureSkins.map((skin) => skin.id),
  ..._foundFlameIds.values,
]);

String? _foundFlameNameById(String? id) {
  for (final entry in _foundFlameIds.entries) {
    if (entry.value == id) return entry.key;
  }
  return null;
}

/// THE FLAME'S OWN HUE for the room's hearth.
///
/// These palettes are still shaped as the old creature's shading ramp:
/// index 0 is a near-white highlight, 1 is a pale tint, 2 is the SATURATED
/// MID, 3 is the shadow. The hearth was wired to index 1, so every flame
/// rendered as a near-white candle no matter which colour you had bought —
/// the seven paid flame colours were nearly indistinguishable in the room.
///
/// The effective flame identity published to visitor rooms.
///
/// Found wardrobe skins pre-date the creature-to-hearth pivot and are stored
/// separately from shop-bought flame colours. Wearing one now deliberately
/// overrides the shop colour without destroying that underlying choice; taking
/// it off reveals the flame the keeper had selected before.
String flameSkinIdFor(GameState s) {
  final found = cosmeticFor(s.equippedSkin);
  return found?.aura == null
      ? s.creatureSkin
      : _foundFlameIds[found!.name] ?? s.creatureSkin;
}

/// Resolves both shop flame ids and save-stable wardrobe cosmetic names.
/// Unknown ids remain compatible with old/public room documents by falling
/// back to Ember rather than accepting an arbitrary colour from the network.
Color flameHueById(String? id) {
  final found = cosmeticFor(id) ?? cosmeticFor(_foundFlameNameById(id));
  if (found?.aura case final hue?) return asFlameHue(hue);
  return asFlameHue(creatureColorsById(id)[2]);
}

Color flameHueFor(GameState s) => flameHueById(flameSkinIdFor(s));

/// Achievement flames retain their restrained spark crown in both owner and
/// visitor renderers. This is derived from the same public identity as hue so
/// the two views cannot silently disagree.
bool heirloomFlameById(String? id) =>
    id == 'gilded' ||
    (cosmeticFor(id) ?? cosmeticFor(_foundFlameNameById(id)))?.rarity ==
        Rarity.legendary;

bool heirloomFlameFor(GameState s) => heirloomFlameById(flameSkinIdFor(s));

/// Pushes a palette's saturated mid into flame territory.
///
/// Even index 2 is body-shading, not firelight: the default Ember's is
/// `0xFFC58A4E`, which paints as candle wax next to the `0xFFE8915A` the room
/// painter falls back to. Lifting saturation and nudging lightness lands each
/// skin on its own believable fire while keeping it recognisably itself —
/// rose still burns rose, mint still burns mint — so the seven paid colours
/// stay distinguishable AND all seven look like flame.
///
/// Doing it here rather than by rewriting the palettes keeps the shop swatches
/// (which show the full four-stop ramp) exactly as authored.
Color asFlameHue(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withSaturation((hsl.saturation * 1.28 + 0.14).clamp(0.0, 0.94))
      .withLightness((hsl.lightness * 0.80 + 0.06).clamp(0.34, 0.56))
      .toColor();
}

/// By-id lookup (used to render a VISITED space, which has no GameState).
List<Color> creatureColorsById(String? id) =>
    (creatureSkinById(id ?? '') ?? _amber).colors;
