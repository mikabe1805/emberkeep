import 'dart:math' as math;

import 'brawl_config.dart';
import 'brawl_stats.dart';
import 'brawl_tuning.dart';

/// Strength: Power Slam.
final class BrawlSlamLoadout {
  const BrawlSlamLoadout({
    required this.on,
    required this.min,
    required this.max,
    required this.cd,
    required this.wave,
    required this.big,
  });

  final bool on;

  /// Damage for a barely charged slam and a fully charged one.
  final double min;
  final double max;

  /// Seconds before the slam is ready again.
  final double cd;

  /// Tier 4: a ground wave follows the slam.
  final bool wave;

  /// Tier 3: a bigger slam.
  final bool big;
}

/// Intellect: Spell Bolt.
final class BrawlSpellLoadout {
  const BrawlSpellLoadout({
    required this.on,
    required this.dmg,
    required this.cd,
    required this.count,
    required this.chain,
    required this.blast,
  });

  final bool on;
  final double dmg;
  final double cd;

  /// 1 bolt, or 2 from tier 2.
  final int count;

  /// Tier 3: the bolt chains for a second hit.
  final bool chain;

  /// Tier 4: a bigger blast.
  final bool blast;
}

/// Social: Call a Friend.
final class BrawlFriendLoadout {
  const BrawlFriendLoadout({
    required this.on,
    required this.dmg,
    required this.cd,
    required this.count,
  });

  final bool on;
  final double dmg;
  final double cd;

  /// 1 friend, or 2 from tier 3.
  final int count;
}

/// Focus: critical hits and a wider combo window.
final class BrawlFocusLoadout {
  const BrawlFocusLoadout({
    required this.on,
    required this.chance,
    required this.mult,
    required this.gold,
    required this.dbl,
    required this.dblMult,
    required this.window,
  });

  final bool on;

  /// Chance that a hit is a critical.
  final double chance;
  final double mult;

  /// Tier 2 up: golden crits.
  final bool gold;

  /// Tier 3 up: the chance that a crit is a double crit.
  final double dbl;
  final double dblMult;

  /// Extra seconds to chain the next hit.
  final double window;
}

/// Vitality: Second Wind (health and recovery).
final class BrawlVitalityLoadout {
  const BrawlVitalityLoadout({
    required this.on,
    required this.hpMax,
    required this.getupMult,
    required this.regen,
  });

  final bool on;
  final double hpMax;

  /// Multiplies how long you lie down after a bump (lower is quicker).
  final double getupMult;

  /// Health per second (0 below tier 2).
  final double regen;
}

/// Discipline: the Super meter.
final class BrawlSuperLoadout {
  const BrawlSuperLoadout({
    required this.on,
    required this.fill,
    required this.total,
    required this.hits,
  });

  final bool on;

  /// Meter points per landed hit (out of 100).
  final double fill;

  /// Total damage of the whole Super.
  final double total;

  /// Flurry hits before the blast.
  final int hits;
}

/// Who walks into the fight: the six stats, the tier each reaches, the week's
/// boost, and every number the abilities derive from them.
final class BrawlLoadout {
  const BrawlLoadout._({
    required this.level,
    required this.power,
    required this.eff,
    required this.tier,
    required this.boost,
    required this.points,
    required this.aura,
    required this.chain,
    required this.fistPower,
    required this.slam,
    required this.spell,
    required this.friend,
    required this.focus,
    required this.vit,
    required this.dis,
  });

  /// The level's base power.
  final int level;
  final double power;

  /// The stat values.
  final Map<BrawlStat, int> eff;

  /// 0 (locked) to 4, from the stat value.
  final Map<BrawlStat, int> tier;

  /// The week's boost per stat (1 to 4).
  final Map<BrawlStat, double> boost;

  /// The week's training points per stat, never more than the stat itself.
  final Map<BrawlStat, double> points;

  /// Every hit of this fight is multiplied by this: 1 for a quiet week, up to
  /// 1.6 for a week with 20 or more training points.
  final double aura;

  /// 3 melee hits in the combo, 4 from Strength tier 2.
  final int chain;
  final double fistPower;
  final BrawlSlamLoadout slam;
  final BrawlSpellLoadout spell;
  final BrawlFriendLoadout friend;
  final BrawlFocusLoadout focus;
  final BrawlVitalityLoadout vit;
  final BrawlSuperLoadout dis;

  /// True when the stat's ability is unlocked.
  bool unlocked(BrawlStat stat) => tier[stat]! >= 1;

  factory BrawlLoadout.fromConfig(BrawlConfig config) {
    final eff = <BrawlStat, int>{};
    final tier = <BrawlStat, int>{};
    final boost = <BrawlStat, double>{};
    final points = <BrawlStat, double>{};
    for (final stat in kBrawlStats) {
      final value = config.statOf(stat);
      eff[stat] = value;
      points[stat] = math.min(config.pointsOf(stat), value.toDouble());
      tier[stat] = brawlTierOf(value);
      boost[stat] = brawlBoostOf(points[stat]!);
    }
    final level = config.level;
    final p = brawlPowerOf(level);
    var totalPoints = 0.0;
    for (final stat in kBrawlStats) {
      totalPoints += points[stat]!;
    }
    // How hard each trained ability hits (the boost, made stronger).
    final hit = <BrawlStat, double>{
      for (final stat in kBrawlStats) stat: brawlAbilityBoost(boost[stat]!),
    };
    int e(BrawlStat s) => eff[s]!;
    int t(BrawlStat s) => tier[s]!;
    double b(BrawlStat s) => boost[s]!;

    // Strength.
    final sc = 1 + 0.0035 * e(BrawlStat.str);
    final slamBig = t(BrawlStat.str) >= 3 ? 1.35 : 1.0;
    final slam = BrawlSlamLoadout(
      on: t(BrawlStat.str) >= 1,
      min: p * BrawlTune.slamMin * sc * hit[BrawlStat.str]! * slamBig,
      max: p * BrawlTune.slamMax * sc * hit[BrawlStat.str]! * slamBig,
      cd: math.max(
        BrawlTune.cdMinSlam,
        BrawlTune.slamCd / (1 + BrawlTune.cdBoost * (b(BrawlStat.str) - 1)),
      ),
      wave: t(BrawlStat.str) >= 4,
      big: t(BrawlStat.str) >= 3,
    );
    // Intellect.
    final spell = BrawlSpellLoadout(
      on: t(BrawlStat.intl) >= 1,
      dmg:
          p *
          BrawlTune.spellDmg *
          (1 + 0.004 * e(BrawlStat.intl)) *
          hit[BrawlStat.intl]! *
          (t(BrawlStat.intl) >= 4 ? 1.5 : 1),
      cd: math.max(
        BrawlTune.cdMinSpell,
        BrawlTune.spellCd / (1 + BrawlTune.cdBoost * (b(BrawlStat.intl) - 1)),
      ),
      count: t(BrawlStat.intl) >= 2 ? 2 : 1,
      chain: t(BrawlStat.intl) >= 3,
      blast: t(BrawlStat.intl) >= 4,
    );
    // Social.
    final friend = BrawlFriendLoadout(
      on: t(BrawlStat.soc) >= 1,
      dmg:
          p *
          BrawlTune.friendDmg *
          (1 + 0.004 * e(BrawlStat.soc)) *
          hit[BrawlStat.soc]! *
          (t(BrawlStat.soc) >= 4 ? 1.3 : 1),
      cd: math.max(
        BrawlTune.cdMinFriend,
        (t(BrawlStat.soc) >= 2 ? BrawlTune.friendCd2 : BrawlTune.friendCd1) /
            (1 + BrawlTune.cdBoost * (b(BrawlStat.soc) - 1)),
      ),
      count: t(BrawlStat.soc) >= 3 ? 2 : 1,
    );
    // Focus.
    final fb = b(BrawlStat.foc);
    final focOn = t(BrawlStat.foc) >= 1;
    final chance = math.min(
      0.8,
      BrawlTune.critBase +
          (focOn ? (0.07 + 0.0012 * e(BrawlStat.foc)) * fb : 0),
    );
    final focus = BrawlFocusLoadout(
      on: focOn,
      chance: chance,
      mult: t(BrawlStat.foc) >= 2 ? 2.2 : 1.7,
      gold: t(BrawlStat.foc) >= 2,
      dbl: t(BrawlStat.foc) >= 3 ? 0.18 : 0,
      dblMult: 3.2,
      window: focOn
          ? (0.10 + (t(BrawlStat.foc) >= 4 ? 0.10 : 0)) * (1 + 0.4 * (fb - 1))
          : 0,
    );
    // Vitality.
    final vb = b(BrawlStat.vit);
    final vit = BrawlVitalityLoadout(
      on: t(BrawlStat.vit) >= 1,
      hpMax: (100 + 0.9 * e(BrawlStat.vit) * vb).roundToDouble(),
      getupMult:
          (t(BrawlStat.vit) >= 1 ? 0.75 : 1) *
          (t(BrawlStat.vit) >= 3 ? 0.8 : 1) /
          (1 + 0.35 * (vb - 1)),
      regen: t(BrawlStat.vit) >= 2
          ? (1.5 + 0.5 * vb) * (t(BrawlStat.vit) >= 4 ? 1.6 : 1)
          : 0,
    );
    // Discipline.
    final db = b(BrawlStat.dis);
    final dbig =
        (t(BrawlStat.dis) >= 3 ? 1.4 : 1.0) *
        (t(BrawlStat.dis) >= 4 ? 1.2 : 1.0);
    final dis = BrawlSuperLoadout(
      on: t(BrawlStat.dis) >= 1,
      fill:
          BrawlTune.meterPerHit *
          (t(BrawlStat.dis) >= 2 ? 1.4 : 1) *
          (t(BrawlStat.dis) >= 4 ? 1.3 : 1) *
          (1 + BrawlTune.cdBoost * (db - 1)),
      total:
          p *
          BrawlTune.superBase *
          dbig *
          hit[BrawlStat.dis]! *
          (1 + 0.003 * e(BrawlStat.dis)),
      hits: t(BrawlStat.dis) >= 4
          ? 12
          : t(BrawlStat.dis) >= 3
          ? 10
          : 8,
    );
    return BrawlLoadout._(
      level: level,
      power: p,
      eff: eff,
      tier: tier,
      boost: boost,
      points: points,
      aura:
          1 +
          BrawlTune.auraPerPoint *
              math.min(BrawlTune.auraCapPoints, totalPoints),
      chain: t(BrawlStat.str) >= 2 ? 4 : 3,
      fistPower: p * BrawlTune.fistK * (1 + 0.002 * e(BrawlStat.str)),
      slam: slam,
      spell: spell,
      friend: friend,
      focus: focus,
      vit: vit,
      dis: dis,
    );
  }
}

/// The level's base power: what an untrained punch is built from.
double brawlPowerOf(int level) =>
    BrawlTune.p0 * (1 + BrawlTune.pGrow * (level - 1));
