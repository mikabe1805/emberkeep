import 'package:flutter/material.dart';

/// Complete authored room identities. A theme is never an empty shell waiting
/// for ten purchases: each one is a finished place with its own furniture,
/// light, material palette, and silhouette.
class SpaceTheme {
  const SpaceTheme({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.price,
    required this.plateAsset,
    required this.previewAsset,
    required this.accent,
    this.hearthAnchor = const Offset(0.866, 0.662),
  });

  final String id;
  final String name;
  final String subtitle;
  final String description;
  final int price;
  final String plateAsset;
  final String previewAsset;
  final Color accent;

  final Offset hearthAnchor;
}

const spaceThemes = <SpaceTheme>[
  SpaceTheme(
    id: 'wall_walnut',
    name: 'The Writer’s Hearth',
    subtitle: 'walnut, books, and a working fire',
    description: 'The original room—warm, practical, and already lived in.',
    price: 0,
    plateAsset: 'assets/rooms/wall_walnut-quest-depth-v1.webp',
    previewAsset: 'assets/rooms/previews/wall_walnut-quest-depth-v1.webp',
    accent: Color(0xFFD79A50),
    hearthAnchor: Offset(0.887, 0.784),
  ),
  SpaceTheme(
    id: 'wall_conservatory',
    name: 'The Living Conservatory',
    subtitle: 'green things, oak, and rainy moonlight',
    description: 'A softer study shaped around things that keep growing.',
    price: 280,
    plateAsset: 'assets/rooms/wall_conservatory-fireless-v3.webp',
    previewAsset: 'assets/rooms/previews/wall_conservatory-fireless-v3.webp',
    accent: Color(0xFF84966B),
  ),
  SpaceTheme(
    id: 'wall_listening',
    name: 'The Listening Room',
    subtitle: 'records, lamplight, and one more side',
    description: 'A favourite record within reach. The good chair facing it.',
    price: 0,
    plateAsset: 'assets/rooms/wall_listening-fireless-v2.webp',
    previewAsset: 'assets/rooms/previews/wall_listening-fireless-v2.webp',
    accent: Color(0xFFC6A465),
  ),
  SpaceTheme(
    id: 'wall_archive',
    name: 'The Moonlit Archive',
    subtitle: 'ink-blue shelves and long, quiet hours',
    description: 'A darker room for books, maps, and thinking past midnight.',
    price: 420,
    plateAsset: 'assets/rooms/wall_archive-fireless-v3.webp',
    previewAsset: 'assets/rooms/previews/wall_archive-fireless-v3.webp',
    accent: Color(0xFF7E91AA),
  ),
  SpaceTheme(
    id: 'wall_rain',
    name: 'The Rain Room',
    subtitle: 'rain on the glass, a seat by the window',
    description: 'Leave the weather outside. Keep the blanket.',
    price: 0,
    plateAsset: 'assets/rooms/wall_rain-fireless-v1.webp',
    previewAsset: 'assets/rooms/previews/wall_rain-fireless-v1.webp',
    accent: Color(0xFF8CAFAD),
    hearthAnchor: Offset(0.866, 0.678),
  ),
  SpaceTheme(
    id: 'wall_atelier',
    name: 'The Painter’s Loft',
    subtitle: 'paint on the table and something in progress',
    description: 'An unfinished canvas. A good place to pick it up again.',
    price: 320,
    plateAsset: 'assets/rooms/wall_atelier-fireless-v1.webp',
    previewAsset: 'assets/rooms/previews/wall_atelier-fireless-v1.webp',
    accent: Color(0xFFD4A06C),
  ),
];

SpaceTheme? spaceThemeById(String id) {
  for (final theme in spaceThemes) {
    if (theme.id == id) return theme;
  }
  return null;
}

bool isSpaceThemeId(String id) => spaceThemeById(id) != null;
