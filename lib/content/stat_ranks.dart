import '../tokens.dart';

/// Per-stat ranks — a little title that grows with each attribute, so the
/// character sheet feels like a build you're leveling, not just numbers.
/// Same thresholds for every stat; the flavor word changes per stat.
class StatRank {
  const StatRank(this.tier, this.label);
  final int tier; // 0..5
  final String label;
}

const _thresholds = [0, 10, 25, 50, 100, 200];

/// Per-stat rank names, indexed by tier 0..5.
const _rankNames = <Stat, List<String>>{
  // BODY
  Stat.str: ['Soft', 'Limber', 'Trained', 'Strong', 'Mighty', 'Titan'],
  // CARE
  Stat.vit: ['Frail', 'Steady', 'Hale', 'Vital', 'Radiant', 'Undimmed'],
  // MIND
  Stat.intl: ['Curious', 'Learner', 'Sharp', 'Astute', 'Sage', 'Luminary'],
  // CRAFT — leveling a craft / career
  Stat.foc: ['Novice', 'Apprentice', 'Practiced', 'Skilled', 'Expert', 'Master'],
  // PEOPLE
  Stat.soc: ['Quiet', 'Warming', 'Kind', 'Beloved', 'Magnetic', 'Beacon'],
  // HOME — clutter to sanctuary
  Stat.dis: ['Cluttered', 'Tidying', 'Kept', 'Homey', 'Welcoming', 'Sanctuary'],
};

StatRank rankFor(Stat stat, int value) {
  var tier = 0;
  for (var i = 0; i < _thresholds.length; i++) {
    if (value >= _thresholds[i]) tier = i;
  }
  return StatRank(tier, _rankNames[stat]![tier]);
}

/// Progress 0..1 toward the next tier (1.0 if maxed).
double rankProgress(int value) {
  var tier = 0;
  for (var i = 0; i < _thresholds.length; i++) {
    if (value >= _thresholds[i]) tier = i;
  }
  if (tier >= _thresholds.length - 1) return 1.0;
  final lo = _thresholds[tier];
  final hi = _thresholds[tier + 1];
  return ((value - lo) / (hi - lo)).clamp(0.0, 1.0);
}

/// XP to the next tier, or null if maxed.
int? toNextTier(int value) {
  for (final t in _thresholds) {
    if (value < t) return t - value;
  }
  return null;
}
