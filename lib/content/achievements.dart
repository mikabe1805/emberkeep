import 'package:flutter/material.dart';

import '../engine.dart';
import '../tokens.dart';

/// The trophy case (DESIGN.md §7): achievements reward breadth and real
/// accomplishment, never login-streak grinding. Conditions read counters
/// the engine maintains; checks are idempotent.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.desc,
    required this.icon,
    required this.test,
    this.progress,
    this.cosmetic,
  });

  final String id;
  final String title;
  final String desc;
  final IconData icon;
  final bool Function(GameState) test;

  /// A legendary cosmetic (name from content/cosmetics.dart) granted into the
  /// wardrobe the moment this trophy unlocks — earned, never dropped.
  final String? cosmetic;

  /// Optional (current, target) for threshold trophies — powers the
  /// "62/100" hint and "closest trophy" nudge in the case
  /// (RESEARCH-momentum.md §7). Null for boolean/one-shot trophies.
  final (int, int) Function(GameState)? progress;
}

int _maxStat(GameState s) =>
    s.stats.values.fold(0, (m, v) => v > m ? v : m);

final achievements = <Achievement>[
  Achievement(
    id: 'first-step',
    title: 'First Step',
    desc: 'Complete your first quest',
    icon: Icons.flag,
    test: (s) => s.totalCompletions >= 1,
  ),
  Achievement(
    id: 'proof-positive',
    title: 'Proof Positive',
    desc: 'Finish a timer-verified quest',
    icon: Icons.verified,
    test: (s) => s.verifiedCompletions >= 1,
  ),
  Achievement(
    id: 'storm-chaser',
    title: 'Storm Chaser',
    desc: 'Complete 3 quests you dread',
    icon: Icons.thunderstorm,
    test: (s) => s.dreadCompletions >= 3,
    progress: (s) => (s.dreadCompletions, 3),
  ),
  Achievement(
    id: 'giant-slayer',
    title: 'Giant Slayer',
    desc: 'Clear an EPIC quest',
    icon: Icons.bolt,
    test: (s) => s.epicCompletions >= 1,
  ),
  Achievement(
    id: 'well-rounded',
    title: 'Well-Rounded',
    desc: 'Train all six stats',
    icon: Icons.donut_large,
    test: (s) => s.stats.values.every((v) => v > 0),
    progress: (s) => (s.stats.values.where((v) => v > 0).length, 6),
  ),
  Achievement(
    id: 'keeper-of-plans',
    title: 'Keeper of Plans',
    desc: 'Complete 3 calendar events',
    icon: Icons.event_available,
    test: (s) => s.eventCompletions >= 3,
    progress: (s) => (s.eventCompletions, 3),
  ),
  Achievement(
    id: 'week-of-fire',
    title: 'Week of Fire',
    desc: 'Reach a 7-day streak · earns the Weeklong Ember skin',
    icon: Icons.local_fire_department,
    test: (s) => s.streakDays >= 7,
    progress: (s) => (s.streakDays, 7),
    cosmetic: 'Weeklong Ember',
  ),
  Achievement(
    id: 'forge-hand',
    title: 'Forge Hand',
    desc: 'Complete 5 quests you forged yourself',
    icon: Icons.handyman,
    test: (s) => s.customCompletions >= 5,
    progress: (s) => (s.customCompletions, 5),
  ),
  Achievement(
    id: 'dedicated',
    title: 'Dedicated',
    desc: '25 quests completed',
    icon: Icons.military_tech,
    test: (s) => s.totalCompletions >= 25,
    progress: (s) => (s.totalCompletions, 25),
  ),
  Achievement(
    id: 'centurion',
    title: 'Centurion',
    desc: '100 quests completed',
    icon: Icons.workspace_premium,
    test: (s) => s.totalCompletions >= 100,
    progress: (s) => (s.totalCompletions, 100),
  ),
  Achievement(
    id: 'risen',
    title: 'Risen',
    desc: 'Reach level 5',
    icon: Icons.trending_up,
    test: (s) => s.level >= 5,
    progress: (s) => (s.level, 5),
  ),
  Achievement(
    id: 'specialist',
    title: 'Specialist',
    desc: 'Raise any stat to 50',
    icon: Icons.auto_awesome,
    test: (s) => s.stats.values.any((v) => v >= 50),
    progress: (s) => (_maxStat(s), 50),
  ),
  Achievement(
    id: 'goal-getter',
    title: 'Goal Getter',
    desc: 'Cross a finish line or reach a first milestone',
    icon: Icons.emoji_events,
    test: (s) => s.goals.any((g) => g.complete || g.progress >= 25),
  ),
  Achievement(
    id: 'night-owl',
    title: 'Rest Earned',
    desc: 'Close out your first day with the night routine',
    icon: Icons.nightlight_round,
    test: (s) => s.nightDoneDay != null,
  ),
  // ── round-11 additions ───────────────────────────────────────────
  Achievement(
    id: 'ascendant',
    title: 'Ascendant',
    desc: 'Reach level 10',
    icon: Icons.keyboard_double_arrow_up,
    test: (s) => s.level >= 10,
    progress: (s) => (s.level, 10),
  ),
  Achievement(
    id: 'comeback',
    title: 'Comeback',
    desc: 'Return and complete a quest after a missed day',
    icon: Icons.replay,
    test: (s) => s.comebacks >= 1,
  ),
  Achievement(
    id: 'perfect-day',
    title: 'Perfect Day',
    desc: 'Clear every quest on the board in one day',
    icon: Icons.done_all,
    test: (s) => s.perfectDays >= 1,
  ),
  Achievement(
    id: 'flawless-week',
    title: 'Flawless Week',
    desc: 'Have 5 perfect days · earns the Spotless Glow skin',
    icon: Icons.calendar_month,
    test: (s) => s.perfectDays >= 5,
    progress: (s) => (s.perfectDays, 5),
    cosmetic: 'Spotless Glow',
  ),
  Achievement(
    id: 'dawn-patrol',
    title: 'Dawn Patrol',
    desc: 'Complete a quest before 8am',
    icon: Icons.wb_twilight,
    test: (s) => s.dawnCompletions >= 1,
  ),
  Achievement(
    id: 'burning-late',
    title: 'Burning Late',
    desc: 'Complete a quest after 9pm',
    icon: Icons.bedtime,
    test: (s) => s.duskCompletions >= 1,
  ),
  Achievement(
    id: 'renaissance',
    title: 'Renaissance',
    desc: 'Raise all six stats to 10+ · earns the Renaissance Aura skin',
    icon: Icons.hexagon_outlined,
    test: (s) => s.stats.values.every((v) => v >= 10),
    progress: (s) => (s.stats.values.where((v) => v >= 10).length, 6),
    cosmetic: 'Renaissance Aura',
  ),
  Achievement(
    id: 'twin-peaks',
    title: 'Twin Peaks',
    desc: 'Raise two stats to 25+',
    icon: Icons.landscape,
    test: (s) => s.stats.values.where((v) => v >= 25).length >= 2,
    progress: (s) => (s.stats.values.where((v) => v >= 25).length, 2),
  ),
  Achievement(
    id: 'polymath',
    title: 'Polymath',
    desc: 'Raise any stat to 100',
    icon: Icons.diamond,
    test: (s) => s.stats.values.any((v) => v >= 100),
    progress: (s) => (_maxStat(s), 100),
  ),
  Achievement(
    id: 'pathmaker',
    title: 'Pathmaker',
    desc: 'Keep three goals at once',
    icon: Icons.alt_route,
    test: (s) => s.goals.length >= 3,
    progress: (s) => (s.goals.length, 3),
  ),
  Achievement(
    id: 'true-believer',
    title: 'True Believer',
    desc: 'Finish 10 timer-verified quests',
    icon: Icons.verified_user,
    test: (s) => s.verifiedCompletions >= 10,
    progress: (s) => (s.verifiedCompletions, 10),
  ),
  Achievement(
    id: 'month-of-fire',
    title: 'Month of Fire',
    desc: 'Reach a 30-day streak · earns the Eternal Flame skin',
    icon: Icons.whatshot,
    test: (s) => s.streakDays >= 30,
    progress: (s) => (s.streakDays, 30),
    cosmetic: 'Eternal Flame',
  ),
  Achievement(
    id: 'marathoner',
    title: 'Marathoner',
    desc: '500 quests completed · earns the Marathoner’s Mantle skin',
    icon: Icons.emoji_events_outlined,
    test: (s) => s.totalCompletions >= 500,
    progress: (s) => (s.totalCompletions, 500),
    cosmetic: 'Marathoner’s Mantle',
  ),
];

/// Quick lookup for the trophy case.
Achievement? achievementById(String id) {
  for (final a in achievements) {
    if (a.id == id) return a;
  }
  return null;
}

/// Color used for unlocked trophies.
const trophyColor = Palette.xpLight;
