import 'brawl_monsters.dart';
import 'brawl_stats.dart';

/// What one fight is made of. Everything the simulation needs, nothing it
/// reads from the app, so the same config always plays out the same way.
final class BrawlConfig {
  const BrawlConfig({
    required this.level,
    required this.stats,
    required this.monster,
    this.training = const {},
    this.easy = false,
    this.seed = 1,
    this.hpMax,
  });

  /// The player's level. It sets base power and how grand the monster looks.
  final int level;

  /// The six stat values now (they already include this week's quests). A
  /// stat that is missing counts as 0.
  final Map<BrawlStat, int> stats;

  /// This week's training points per stat: quests finished for the stat since
  /// Monday 04:00, a timer-proven Quest counting 1.5. A stat that is missing
  /// counts as 0.
  final Map<BrawlStat, double> training;

  final BrawlMonster monster;

  /// Easy mode: tap anywhere to attack, a gentler monster, no knockdowns.
  final bool easy;

  /// Seeds every roll in the fight.
  final int seed;

  /// Overrides the calibrated monster health (tests and the calibration run).
  final double? hpMax;

  int statOf(BrawlStat stat) => stats[stat] ?? 0;
  double pointsOf(BrawlStat stat) => training[stat] ?? 0;

  BrawlConfig copyWith({
    int? level,
    Map<BrawlStat, int>? stats,
    Map<BrawlStat, double>? training,
    BrawlMonster? monster,
    bool? easy,
    int? seed,
    double? hpMax,
  }) {
    return BrawlConfig(
      level: level ?? this.level,
      stats: stats ?? this.stats,
      training: training ?? this.training,
      monster: monster ?? this.monster,
      easy: easy ?? this.easy,
      seed: seed ?? this.seed,
      hpMax: hpMax ?? this.hpMax,
    );
  }
}
