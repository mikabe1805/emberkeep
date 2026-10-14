import 'brawl_fight.dart';
import 'brawl_monsters.dart';
import 'brawl_stats.dart';
import 'brawl_tuning.dart';

/// One line of the victory breakdown: which move, and so which stat and which
/// week's training, did the damage.
final class BrawlBreakdownRow {
  const BrawlBreakdownRow({
    required this.source,
    required this.stat,
    required this.damage,
    required this.percent,
    required this.trainedPoints,
  });

  /// Where the damage came from. [BrawlDamageSource.fist] and
  /// [BrawlDamageSource.finisher] belong to no stat.
  final BrawlDamageSource source;

  /// The stat behind it, or null for plain combos and the finisher.
  final BrawlStat? stat;
  final double damage;

  /// Share of all damage, 0 to 100.
  final double percent;

  /// This week's training points for [stat]; above 0 means "trained this
  /// week" and the row glows.
  final double trainedPoints;
}

/// What the victory screen shows.
final class BrawlResult {
  const BrawlResult({
    required this.seconds,
    required this.chest,
    required this.loot,
    required this.rows,
    required this.perfect,
    required this.knockdowns,
    required this.maxCombo,
    required this.crits,
    required this.doubleCrits,
    required this.supers,
    required this.friendsCalled,
    required this.monster,
    required this.finisherLine,
  });

  /// Fight time up to FINISH IT!, the time that earns the chest.
  final double seconds;
  final BrawlChest chest;
  final String loot;

  /// Biggest share first. Only sources that dealt damage are listed.
  final List<BrawlBreakdownRow> rows;

  /// Never bumped.
  final bool perfect;
  final int knockdowns;
  final int maxCombo;
  final int crits;
  final int doubleCrits;
  final int supers;
  final int friendsCalled;
  final BrawlMonster monster;
  final String finisherLine;

  /// The result of a finished fight (the finisher has begun).
  factory BrawlResult.of(BrawlFight fight) {
    final d = fight.stats.dmg;
    final lo = fight.lo;
    final finisherShare = fight.m.hpMax * BrawlTune.dazeAt;
    final entries = <(BrawlDamageSource, BrawlStat?, double)>[
      (BrawlDamageSource.fist, null, d.fist),
      (BrawlDamageSource.slam, BrawlStat.str, d.slam),
      (BrawlDamageSource.spell, BrawlStat.intl, d.spell),
      (BrawlDamageSource.friend, BrawlStat.soc, d.friend),
      (BrawlDamageSource.focus, BrawlStat.foc, d.focus),
      (BrawlDamageSource.superMove, BrawlStat.dis, d.superMove),
      (BrawlDamageSource.finisher, null, finisherShare),
    ];
    final total = entries.fold<double>(0, (a, e) => a + e.$3);
    final indexed = <(int, BrawlBreakdownRow)>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (e.$3 <= 0.5) continue;
      indexed.add((
        i,
        BrawlBreakdownRow(
          source: e.$1,
          stat: e.$2,
          damage: e.$3,
          percent: 100 * e.$3 / total,
          trainedPoints: e.$2 == null ? 0 : lo.points[e.$2]!,
        ),
      ));
    }
    // Biggest first; equal shares keep the order above.
    indexed.sort((a, b) {
      final c = b.$2.percent.compareTo(a.$2.percent);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    final seconds = fight.finishTime;
    final chest = brawlChestFor(seconds);
    return BrawlResult(
      seconds: seconds,
      chest: chest,
      loot: fight.def.loot[chest]!,
      rows: [for (final e in indexed) e.$2],
      perfect: fight.perfect,
      knockdowns: fight.knockdowns,
      maxCombo: fight.stats.maxCombo,
      crits: fight.stats.crits,
      doubleCrits: fight.stats.dcrits,
      supers: fight.stats.supers,
      friendsCalled: fight.stats.calls,
      monster: fight.config.monster,
      finisherLine: fight.def.finisher,
    );
  }
}
