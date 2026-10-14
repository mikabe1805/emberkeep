// The six abilities of the weekend brawl, one for each stat.
//
// Every stat is an ability, so the six stats are six different things to
// look forward to: Strength throws a Power Slam, Intellect a Spell Bolt,
// Social calls a Friend, Focus lands critical hits, Vitality is Second Wind
// and Discipline fills a Super meter. An ability unlocks at 10 in its stat and
// grows in tiers at 40, 80 and 150. This week's training boosts it on top
// (weekly_training.dart).
//
// Pure data and pure functions: no widgets, no clock, no engine. The Me page,
// the versus screen and the fight itself all read the same words from here, so
// a name or a threshold is changed in one place.
library;

import '../tokens.dart';

/// The stat values where an ability unlocks (tier 1) and where it grows to
/// tier 2, 3 and 4. Below the first, the ability is locked.
const List<int> abilityTierAt = [10, 40, 80, 150];

/// The highest tier an ability reaches.
const int abilityTopTier = 4;

/// One stat's ability: what it is called, and what it does in a sentence.
class BrawlAbility {
  const BrawlAbility({
    required this.stat,
    required this.name,
    required this.blurb,
    required this.perks,
  });

  final Stat stat;

  /// "Power Slam".
  final String name;

  /// One plain line for what it does, for someone who has never played a
  /// fighting game.
  final String blurb;

  /// What each tier gives, tier 1 first: [perks] always has four entries. The
  /// first is the ability itself, each after it is what that tier adds.
  final List<String> perks;

  /// What tier [tier] (1 to 4) adds, in a few plain words.
  String perk(int tier) => perks[(tier.clamp(1, abilityTopTier)) - 1];
}

/// The six abilities, keyed by the stat that powers them.
const Map<Stat, BrawlAbility> brawlAbilities = {
  Stat.str: BrawlAbility(
    stat: Stat.str,
    name: 'Power Slam',
    blurb: 'Hold Attack, then let go for a heavy hit.',
    perks: [
      'a heavy hit when you let go',
      'a fourth hit in your combo',
      'a bigger slam',
      'a wave along the ground',
    ],
  ),
  Stat.intl: BrawlAbility(
    stat: Stat.intl,
    name: 'Spell Bolt',
    blurb: 'Throw a bolt of light. It is ready again in a moment.',
    perks: [
      'a bolt that recharges quickly',
      'a twin bolt',
      'a bolt that jumps to a second hit',
      'a bigger blast',
    ],
  ),
  Stat.soc: BrawlAbility(
    stat: Stat.soc,
    name: 'Call a Friend',
    blurb: 'A friend dashes in and does a combo for you.',
    perks: [
      'a friend dashes in',
      'your friend comes more often',
      'two friends at once',
      'a longer combo from both',
    ],
  ),
  Stat.foc: BrawlAbility(
    stat: Stat.foc,
    name: 'Focus',
    blurb: 'More critical hits, and more time to chain your combo.',
    perks: [
      'more critical hits',
      'golden critical hits',
      'double critical hits',
      'the widest combo window',
    ],
  ),
  Stat.vit: BrawlAbility(
    stat: Stat.vit,
    name: 'Second Wind',
    blurb: 'More health, and you catch your breath faster.',
    perks: [
      'more health, and a quicker recovery',
      'a slow regain as you fight',
      'even more health',
      'a faster regain',
    ],
  ),
  Stat.dis: BrawlAbility(
    stat: Stat.dis,
    name: 'Super',
    blurb: 'A meter fills as you hit. When it is full, you unleash a Super.',
    perks: [
      'a Super meter that fills as you hit',
      'a meter that fills faster',
      'a bigger Super',
      'a Super that hits twice',
    ],
  ),
};

/// The ability a stat powers.
BrawlAbility abilityOf(Stat stat) => brawlAbilities[stat]!;

/// The tier [value] reaches: 0 is locked (below 10), then 1 at 10, 2 at 40, 3
/// at 80 and 4 at 150.
int tierOf(int value) {
  var tier = 0;
  for (var i = 0; i < abilityTierAt.length; i++) {
    if (value >= abilityTierAt[i]) tier = i + 1;
  }
  return tier;
}

/// Whether the ability is still waiting to be unlocked.
bool isLocked(int value) => tierOf(value) == 0;

/// The stat value of the next tier, or null at the top tier.
int? nextTierAt(int value) {
  final tier = tierOf(value);
  return tier >= abilityTopTier ? null : abilityTierAt[tier];
}

/// How far [value] is toward its next tier, from 0 to 1 (1 at the top).
double tierProgress(int value) {
  final tier = tierOf(value);
  if (tier >= abilityTopTier) return 1;
  final from = tier == 0 ? 0 : abilityTierAt[tier - 1];
  final to = abilityTierAt[tier];
  return ((value - from) / (to - from)).clamp(0.0, 1.0);
}

/// What a locked ability says, as an aspiration and never a scold:
/// "Reach Social 10 to unlock Call a Friend".
String lockedLine(Stat stat) =>
    'Reach ${stat.label} ${abilityTierAt.first} to unlock '
    '${abilityOf(stat).name}';

/// "Tier 2", or "Locked" below the first tier.
String tierName(int tier) => tier <= 0 ? 'Locked' : 'Tier $tier';

/// The line that says where the ability is going next: "Tier 3 at 80", or
/// "Top tier" once there is nowhere higher. A locked ability gets
/// [lockedLine] instead.
String nextLine(Stat stat, int value) {
  if (isLocked(value)) return lockedLine(stat);
  final next = nextTierAt(value);
  return next == null ? 'Top tier' : 'Tier ${tierOf(value) + 1} at $next';
}

/// The fuller next line, with what the tier will add: "Tier 3 at 80: a bigger
/// slam". The unlock line when locked, "Top tier" at the top.
String nextLineWithPerk(Stat stat, int value) {
  if (isLocked(value)) return lockedLine(stat);
  final next = nextTierAt(value);
  if (next == null) return 'Top tier';
  final tier = tierOf(value) + 1;
  return 'Tier $tier at $next: ${abilityOf(stat).perk(tier)}';
}

/// What a screen reader says for one stat's ability.
String abilitySpoken(Stat stat, int value) {
  final ability = abilityOf(stat);
  if (isLocked(value)) return '${lockedLine(stat)}.';
  return '${ability.name}, tier ${tierOf(value)}. ${nextLine(stat, value)}.';
}
