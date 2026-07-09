import 'package:flutter/painting.dart' show Alignment;

import '../engine.dart';
import 'achievements.dart';

/// Painted stages (round-60; code-painted round-62) — cozy scenes the creature
/// stands in at its hero moments (the skin try-on and the share card). Each is
/// drawn procedurally by widgets/stage_scene.dart's paintStageScene and
/// rendered by PaintedBackdrop (the round-60 SDXL webp backdrops were retired
/// as "obviously AI"). Exclusive (one on stage at a time); the free
/// 'hearthside' is implicitly owned.
class StageScene {
  const StageScene(
    this.id,
    this.name,
    this.price,
    this.blurb, {
    this.requires,
    this.stand = const Alignment(0, 0.45),
  });

  final String id;
  final String name;

  /// Ember cost; 0 = the free default.
  final int price;
  final String blurb;

  /// Achievement id that gates the purchase (see content/achievements.dart).
  final String? requires;

  /// Where the creature stands in this painting — each composition leaves its
  /// open spot somewhere else (a stump, a counter, a rug).
  final Alignment stand;
}

final stageScenes = <StageScene>[
  const StageScene('hearthside', 'Hearthside', 0,
      'home is where your fire is'),
  const StageScene('candleglow', 'Candleglow', 120,
      'one quiet bowl of warm light'),
  const StageScene('lamplight', 'Lamplight', 140,
      'reading hours in the study'),
  const StageScene('garden', 'Lantern Garden', 160,
      'dusk, lavender, fireflies',
      stand: Alignment(0, 0.55)),
  const StageScene('autumn', 'Golden Hollow', 180,
      'the forest saves you a stump',
      stand: Alignment(0, 0.35)),
  const StageScene('greenhouse', 'Night Greenhouse', 200,
      'glass, green and starlight',
      stand: Alignment(0, 0.55)),
  const StageScene('bakery', 'Warm Bakery', 220,
      'fresh bread, warmer company',
      stand: Alignment(0, 0.30)),
  const StageScene('library', 'Moonlit Stacks', 240,
      'shelves that never sleep',
      stand: Alignment(0, 0.55)),
  const StageScene('rooftop', 'Starry Rooftop', 260,
      'the city hums below you',
      requires: 'night-owl', stand: Alignment(0, 0.50)),
  const StageScene('seaside', 'Sea Porch', 280,
      'slow tides, long horizon',
      requires: 'dawn-patrol', stand: Alignment(-0.15, 0.50)),
  const StageScene('snownook', 'Snow Nook', 300,
      'blankets against the blizzard',
      requires: 'month-of-fire', stand: Alignment(0, 0.50)),
];

StageScene? stageSceneById(String id) {
  for (final s in stageScenes) {
    if (s.id == id) return s;
  }
  return null;
}

/// The scene currently on stage (falls back to the free default).
StageScene stageSceneFor(GameState s) =>
    stageSceneById(s.stageScene) ?? stageScenes.first;

bool isSceneOwned(GameState s, StageScene v) =>
    v.price == 0 || s.ownedScenes.contains(v.id);

bool isSceneApplied(GameState s, StageScene v) => s.stageScene == v.id;

bool sceneUnlocked(StageScene v, GameState s) =>
    v.requires == null || s.unlockedAchievements.contains(v.requires);

String? sceneGateLabel(StageScene v) {
  final id = v.requires;
  if (id == null) return null;
  for (final a in achievements) {
    if (a.id == id) return a.title;
  }
  return 'a trophy';
}
