import 'dart:math' as math;

import 'brawl_bot.dart';
import 'brawl_config.dart';
import 'brawl_fight.dart';
import 'brawl_stats.dart';
import 'brawl_tuning.dart';

/// Monster health is sized from the player's own untrained damage rate
/// ("level and expected stats"): the average-player bot fights an unkillable
/// copy for [BrawlTune.calSeconds] with no weekly training, and health is that
/// damage rate times the target time. Training raises the player's rate above
/// this baseline, which is exactly what makes a trained week faster, and a
/// higher level raises the baseline, so the monster never evaporates.
///
/// The answer depends only on the level, the six stats and the monster, so
/// it is remembered.
double brawlMonsterHp(BrawlConfig config) {
  final key = _cacheKey(config);
  final cached = _hpCache[key];
  if (cached != null) return cached;
  final cal = BrawlConfig(
    level: config.level,
    stats: config.stats,
    monster: config.monster,
    seed: BrawlTune.calSeed,
    hpMax: 1e9,
  );
  final g = BrawlFight(cal, hpMax: 1e9);
  final bot = BrawlBot(g, seed: BrawlTune.calSeed);
  final steps = (BrawlTune.calSeconds / BrawlTune.step).round();
  for (var i = 0; i < steps; i++) {
    bot.drive();
    g.step(BrawlTune.step, bot.input);
    g.events.clear();
  }
  final dps = g.stats.dmg.total / math.max(1.0, g.t - 1.25);
  // The last 7% belongs to the finisher, and the bot needs about half a
  // second to tap FINISH IT!
  final need =
      dps *
      (BrawlTune.targetQuiet - 0.6) /
      (1 - BrawlTune.dazeAt) *
      BrawlTune.calBias *
      config.monster.def.hpMult;
  final hp = math.max(500, (need / 50).round() * 50).toDouble();
  _hpCache[key] = hp;
  return hp;
}

final Map<String, double> _hpCache = {};

String _cacheKey(BrawlConfig c) {
  final b = StringBuffer('${c.monster.key}|${c.level}');
  for (final s in kBrawlStats) {
    b.write('|${c.statOf(s)}');
  }
  return b.toString();
}

/// Forgets every calibrated health (for tests that want a cold start).
void brawlClearMonsterHpCache() => _hpCache.clear();

/// Starts a fight with the monster's health sized for this player (or the
/// config's own [BrawlConfig.hpMax]).
BrawlFight createBrawlFight(BrawlConfig config) =>
    BrawlFight(config, hpMax: config.hpMax ?? brawlMonsterHp(config));
