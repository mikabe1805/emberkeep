import 'package:flutter/material.dart';

/// A candlelit canvas theme — the room's ambient night, swappable once the
/// THEMES unlock (Lv 5) opens. The honey glass, accents, and specular shines
/// stay; what changes is the dark-warm canvas gradient and the soft pools of
/// light pooling behind it (RESEARCH-momentum.md §7). All cozy-dark, never
/// light, never cold grey.
class CanvasTheme {
  const CanvasTheme({
    required this.id,
    required this.name,
    required this.top,
    required this.bottom,
    required this.glows,
    this.locked = true,
  });

  final String id;
  final String name;

  /// Canvas gradient — warm night, top to bottom.
  final Color top;
  final Color bottom;

  /// Four soft light pools (already alpha'd) drifting behind the glass.
  final List<Color> glows;

  /// Requires the Lv-5 THEMES unlock (the default look is always free).
  final bool locked;
}

const canvasThemes = <CanvasTheme>[
  CanvasTheme(
    id: 'walnut',
    name: 'Walnut Night',
    locked: false,
    top: Color(0xFF191210),
    bottom: Color(0xFF231A20),
    glows: [
      Color(0x30E0A865),
      Color(0x26D88A8A),
      Color(0x226F8A6B),
      Color(0x1CC9A3DC),
    ],
  ),
  CanvasTheme(
    id: 'plum',
    name: 'Plum Dusk',
    top: Color(0xFF1B1320),
    bottom: Color(0xFF241526),
    glows: [
      Color(0x30E0A865),
      Color(0x2AC98AC0),
      Color(0x22B79BC8),
      Color(0x1C8FBAB6),
    ],
  ),
  CanvasTheme(
    id: 'forest',
    name: 'Forest Hearth',
    top: Color(0xFF121A14),
    bottom: Color(0xFF1A2418),
    glows: [
      Color(0x30E0A865),
      Color(0x2A6F8A6B),
      Color(0x22E8915A),
      Color(0x1C8FBAB6),
    ],
  ),
  CanvasTheme(
    id: 'ink',
    name: 'Ink & Ember',
    top: Color(0xFF14161C),
    bottom: Color(0xFF1B1E27),
    glows: [
      Color(0x30E8915A),
      Color(0x2493A7E0),
      Color(0x20E0A865),
      Color(0x1CC9A3DC),
    ],
  ),
  CanvasTheme(
    id: 'rose',
    name: 'Rose Hearth',
    top: Color(0xFF1E1416),
    bottom: Color(0xFF281A1C),
    glows: [
      Color(0x30E0A865),
      Color(0x2AE8A0A0),
      Color(0x22D88A8A),
      Color(0x1CC9A3DC),
    ],
  ),
  CanvasTheme(
    id: 'sea',
    name: 'Sea Cave',
    top: Color(0xFF101A1C),
    bottom: Color(0xFF162428),
    glows: [
      Color(0x2CE0A865),
      Color(0x268FBAB6),
      Color(0x2293A7E0),
      Color(0x1C6F8A6B),
    ],
  ),
  CanvasTheme(
    id: 'harvest',
    name: 'Harvest',
    top: Color(0xFF1A1410),
    bottom: Color(0xFF241B12),
    glows: [
      Color(0x32E0A865),
      Color(0x28E8915A),
      Color(0x226F8A6B),
      Color(0x1CF2CD93),
    ],
  ),
];

CanvasTheme canvasThemeById(String? id) {
  for (final t in canvasThemes) {
    if (t.id == id) return t;
  }
  return canvasThemes.first;
}
