/// Every number that decides how the fight feels, in one place.
///
/// These are the prototype's v2.1 numbers (the fight Mika played and liked),
/// plus one retune (2026-10-14): the prototype was measured with 21 and 65
/// training points in a week, but a real "some training" week is about 8
/// quests and a "big" one about 12, so a trained ability now hits harder than
/// its boost (see [brawlAbilityBoost]) and the whole week adds an aura
/// ([auraPerPoint]). A quiet week is untouched. Distances are logical
/// pixels, x runs right, and h is height above the ground line.
abstract final class BrawlTune {
  static const double worldW = 460;
  static const double startX = 108;

  // Fighter movement.
  static const double runSpeed = 170;
  static const double accel = 1800;
  static const double friction = 2200;
  static const double airAccel = 1100;
  static const double gravity = 1600;
  static const double jumpV = 560;
  static const double airJumpV = 480;
  static const double jumpCut = 0.8;
  static const double coyote = 0.09;
  static const double jumpBuf = 0.13;
  static const double atkBuf = 0.20;
  static const double abBuf = 0.24;

  /// Seconds after an attack ends in which the next tap continues the chain.
  static const double chainWin = 0.42;

  /// Seconds a combo counter survives without a hit.
  static const double comboKeep = 1.7;

  /// Hold ATTACK this long to start charging Power Slam.
  static const double holdToSlam = 0.28;

  /// Charge time for full slam power.
  static const double slamFull = 0.55;
  static const double magnet = 80;
  static const double magnetEasy = 460;
  static const double dashSpeed = 720;

  // Power curve.
  static const double p0 = 10;
  static const double pGrow = 0.15;
  static const double fistK = 2.0;

  /// How strongly the weekly boost shortens cooldowns and speeds the meter.
  static const double cdBoost = 1.6;

  /// The training aura (retune 2026-10-14, see [brawlAbilityBoost]): every hit
  /// of the fight is multiplied by 1 + [auraPerPoint] x this week's training
  /// points, counting at most [auraCapPoints] of them. It is what lets a week
  /// of quests show up even in the fists, and what keeps a level 1 fighter's
  /// trained week as fast as a level 20 fighter's.
  static const double auraPerPoint = 0.033;
  static const double auraCapPoints = 20;

  /// Floors, so a huge week cannot turn an ability into a machine gun.
  static const double cdMinSpell = 1.5;
  static const double cdMinSlam = 1.7;
  static const double cdMinFriend = 4.5;

  // Abilities (multiples of the level's power).
  static const double slamMin = 3.4;
  static const double slamMax = 6.0;
  static const double slamCd = 3.6;
  static const double spellDmg = 3.6;
  static const double spellCd = 2.8;
  static const double twin = 0.6;
  static const double friendDmg = 1.0;
  static const double friendCd1 = 12;
  static const double friendCd2 = 8;
  static const double superBase = 22;
  static const double meterPerHit = 1.4;
  static const double critBase = 0.05;

  // The monster.

  /// The share of health left when the monster gets dazed and FINISH IT! shows.
  static const double dazeAt = 0.07;

  /// Seconds an untrained week should take (Mika, 2026-10-14: "a minute or a
  /// little more").
  static const double targetQuiet = 70;
  static const double calSeconds = 70;
  static const int calSeed = 7777;
  static const double calBias = 1.0;
  static const double moveMin = 6;
  static const double moveMax = 8;

  // Player safety.

  /// Fraction of max health a hit takes (normal mode).
  static const double hurtDmg = 0.34;
  static const double downLie = 0.95;
  static const double getupT = 0.35;
  static const double getupInv = 1.1;

  // Finisher.
  static const double finishWaitStd = 7;
  static const double finishWaitEasy = 2.5;

  /// The fixed step the fight is built for.
  static const double step = 1 / 60;
}
