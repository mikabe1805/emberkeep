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
  });

  final String id;
  final String name;
  final String subtitle;
  final String description;
  final int price;
  final String plateAsset;
  final String previewAsset;
  final Color accent;
}

const spaceThemes = <SpaceTheme>[
  SpaceTheme(
    id: 'wall_walnut',
    name: 'The Writer’s Hearth',
    subtitle: 'walnut, books, and a working fire',
    description: 'The original room—warm, practical, and already lived in.',
    price: 0,
    plateAsset: 'assets/rooms/wall_walnut-fireless-v3.webp',
    previewAsset: 'assets/rooms/previews/wall_walnut-fireless-v3.webp',
    accent: Color(0xFFD79A50),
  ),
  SpaceTheme(
    id: 'wall_conservatory',
    name: 'The Living Conservatory',
    subtitle: 'green things, oak, and rainy moonlight',
    description: 'A softer study shaped around things that keep growing.',
    price: 280,
    plateAsset: 'assets/rooms/wall_conservatory-fireless-v2.webp',
    previewAsset: 'assets/rooms/previews/wall_conservatory-fireless-v2.webp',
    accent: Color(0xFF84966B),
  ),
  SpaceTheme(
    id: 'wall_archive',
    name: 'The Moonlit Archive',
    subtitle: 'ink-blue shelves and long, quiet hours',
    description: 'A darker room for books, maps, and thinking past midnight.',
    price: 420,
    plateAsset: 'assets/rooms/wall_archive-fireless-v2.webp',
    previewAsset: 'assets/rooms/previews/wall_archive-fireless-v2.webp',
    accent: Color(0xFF7E91AA),
  ),
];

SpaceTheme? spaceThemeById(String id) {
  for (final theme in spaceThemes) {
    if (theme.id == id) return theme;
  }
  return null;
}

bool isSpaceThemeId(String id) => spaceThemeById(id) != null;
