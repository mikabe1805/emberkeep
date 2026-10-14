// What one weekend fight is made of, read from the save: the fighter's level
// and six stats, this week's training, and the week's monster.
library;

import '../../clock.dart';
import '../../engine.dart';
import '../../tokens.dart';
import '../core/brawl_core.dart';
import '../weekly_training.dart';

/// The Stat for a core stat, and back. The core keeps its own enum (it has no
/// Flutter imports); the keys match.
BrawlStat brawlStatOf(Stat stat) => BrawlStat.values.byName(stat.name);
Stat appStatOf(BrawlStat stat) => Stat.values.byName(stat.name);

/// The core's monster for the week's [WeeklyMonster] (the ids differ: the
/// week says `couch_troll`, the core says `troll`).
BrawlMonster brawlMonsterOf(WeeklyMonster weekly) =>
    weekly.id == couchTroll.id ? BrawlMonster.troll : BrawlMonster.fog;

class BrawlSetup {
  const BrawlSetup({
    required this.level,
    required this.stats,
    required this.training,
    required this.weekly,
    required this.dayName,
    this.practice = false,
  });

  final int level;
  final Map<Stat, int> stats;
  final WeeklyTraining training;
  final WeeklyMonster weekly;

  /// "Saturday".
  final String dayName;

  /// This weekend's chest is already won: this fight is for practice.
  final bool practice;

  BrawlMonster get monster => brawlMonsterOf(weekly);

  /// The week's training points never count for more than the stat itself.
  double pointsOf(Stat stat) =>
      training.pointsOf(stat).clamp(0, (stats[stat] ?? 0).toDouble());

  /// Reads the save at [now]. [monster] overrides the week's monster (the
  /// renders and tests only).
  factory BrawlSetup.fromState(
    GameState state, {
    DateTime? now,
    WeeklyMonster? monster,
  }) {
    final at = now ?? Clock.now();
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return BrawlSetup(
      level: state.level,
      stats: {for (final s in Stat.values) s: state.stats[s] ?? 0},
      training: state.weeklyTraining(at),
      weekly: monster ?? monsterOfTheWeek(at),
      dayName: names[at.weekday - 1],
      practice: state.brawlWonThisWeek(at),
    );
  }

  BrawlConfig toConfig({bool easy = false, int seed = 1}) => BrawlConfig(
    level: level,
    stats: {for (final s in Stat.values) brawlStatOf(s): stats[s] ?? 0},
    training: {
      for (final s in Stat.values) brawlStatOf(s): training.pointsOf(s),
    },
    monster: monster,
    easy: easy,
    seed: seed,
  );
}
