import 'dart:math' as math;

/// The six stats, with the names the saves already use. The order matches
/// `Stat` in lib/tokens.dart, so `BrawlStat.values.byName(stat.name)` (or the
/// index) maps one to the other. The core has no Flutter imports, so it keeps
/// its own copy of the enum.
enum BrawlStat {
  str,
  vit,
  intl,
  foc,
  soc,
  dis;

  /// The serialized key: `str`, `vit`, `intl`, `foc`, `soc`, `dis`.
  String get key => name;
}

/// Stat values that unlock tier 1 to 4 of an ability. Below the first, the
/// ability is locked.
const List<int> kBrawlTierAt = [10, 40, 80, 150];

/// 0 when locked, then 1 to 4.
int brawlTierOf(int value) {
  var tier = 0;
  for (var i = 0; i < kBrawlTierAt.length; i++) {
    if (value >= kBrawlTierAt[i]) tier = i + 1;
  }
  return tier;
}

/// The week's boost for one stat, from its training points (quests finished
/// for that stat since Monday 04:00, a timer-proven Quest counting 1.5).
/// 1 means no training; it tops out at 4.
double brawlBoostOf(double points) => 1 + math.min(3.0, 0.18 * points);

/// How much harder a trained ability hits than its [brawlBoostOf]: the boost
/// to the power 1.5, so a week with 8 quests in a stat (boost 2.44) hits 3.8
/// times as hard. It is written as `b * sqrt(b)` so that every device gets the
/// same bits; `pow` with a fractional exponent is not exact everywhere.
double brawlAbilityBoost(double boost) => boost * math.sqrt(boost);

/// Which of the six stats are in play, in a stable order.
const List<BrawlStat> kBrawlStats = BrawlStat.values;
