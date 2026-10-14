import 'package:emberkeep/brawl/core/brawl_core.dart';

/// Mika's numbers (LV 6): the fighter the tuning is measured on.
const Map<BrawlStat, int> mikaStats = {
  BrawlStat.str: 54,
  BrawlStat.vit: 90,
  BrawlStat.intl: 30,
  BrawlStat.foc: 23,
  BrawlStat.soc: 5,
  BrawlStat.dis: 110,
};

/// Every stat at one value.
Map<BrawlStat, int> allStats(int value) => {
  for (final s in BrawlStat.values) s: value,
};

BrawlConfig testConfig({
  int level = 6,
  Map<BrawlStat, int>? stats,
  Map<BrawlStat, double> training = const {},
  BrawlMonster monster = BrawlMonster.troll,
  bool easy = false,
  int seed = 1,
  double? hpMax,
}) => BrawlConfig(
  level: level,
  stats: stats ?? mikaStats,
  training: training,
  monster: monster,
  easy: easy,
  seed: seed,
  hpMax: hpMax,
);

/// A fight with a big health bar (so nothing ends by accident) unless a test
/// says otherwise.
BrawlFight testFight({
  int level = 6,
  Map<BrawlStat, int>? stats,
  Map<BrawlStat, double> training = const {},
  BrawlMonster monster = BrawlMonster.troll,
  bool easy = false,
  int seed = 1,
  double hpMax = 1e7,
}) => BrawlFight(
  testConfig(
    level: level,
    stats: stats,
    training: training,
    monster: monster,
    easy: easy,
    seed: seed,
  ),
  hpMax: hpMax,
);

/// Drives a fight by hand and keeps every event it sees.
final class Rig {
  Rig(this.fight);

  final BrawlFight fight;
  final BrawlInput input = BrawlInput();
  final List<BrawlEvent> log = [];

  void step([int n = 1]) {
    for (var i = 0; i < n; i++) {
      fight.step(BrawlTune.step, input);
      log.addAll(fight.drainEvents());
    }
  }

  /// Steps for [seconds] of fight time.
  void run(double seconds) => step((seconds / BrawlTune.step).round());

  /// Steps until [cond] holds (at most [maxSeconds]); returns whether it did.
  bool until(bool Function() cond, {double maxSeconds = 30}) {
    final limit = (maxSeconds / BrawlTune.step).round();
    for (var i = 0; i < limit; i++) {
      if (cond()) return true;
      step();
    }
    return cond();
  }

  void pastIntro() {
    until(() => fight.phase != BrawlPhase.intro, maxSeconds: 3);
  }

  /// Walks right until the fighter stands in punching range.
  void walkToMonster() {
    input.moveX = 1;
    until(() => fight.f.x >= fight.frontAt(34) - 34, maxSeconds: 4);
    input.moveX = 0;
    run(0.25);
  }

  void tapAttack() => input.pAtk = true;

  Iterable<BrawlEvent> of(BrawlEventType type) =>
      log.where((e) => e.type == type);

  Iterable<BrawlEvent> hits([BrawlDamageSource? source]) => log.where(
    (e) =>
        e.type == BrawlEventType.hit && (source == null || e.source == source),
  );

  bool saw(BrawlEventType type) => log.any((e) => e.type == type);

  BrawlFighterBody get f => fight.f;
}

/// A rig that is already past the intro.
Rig startedRig({
  int level = 6,
  Map<BrawlStat, int>? stats,
  Map<BrawlStat, double> training = const {},
  BrawlMonster monster = BrawlMonster.troll,
  bool easy = false,
  int seed = 1,
  double hpMax = 1e7,
}) {
  final rig = Rig(
    testFight(
      level: level,
      stats: stats,
      training: training,
      monster: monster,
      easy: easy,
      seed: seed,
      hpMax: hpMax,
    ),
  );
  rig.pastIntro();
  return rig;
}
