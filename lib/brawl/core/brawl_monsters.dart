import 'brawl_stats.dart';

/// Where a point of damage came from. The victory breakdown groups by these.
enum BrawlDamageSource {
  /// Plain punches and kicks (no stat; they scale with your level).
  fist,

  /// Strength: Power Slam and its ground wave.
  slam,

  /// Intellect: Spell Bolt.
  spell,

  /// Social: Call a Friend.
  friend,

  /// Discipline: the Super.
  superMove,

  /// Focus: the extra damage a critical hit adds on top of the base hit.
  focus,

  /// The finisher's share (the last slice of health, always the player's).
  finisher,
}

/// This week's monster. Even ISO weeks bring the Couch Troll, odd weeks the Fog.
enum BrawlMonster {
  troll,
  fog;

  String get key => name;

  /// The monster for a key ('troll' or 'fog'), or null for anything else.
  static BrawlMonster? fromKey(String? key) {
    for (final m in values) {
      if (m.key == key) return m;
    }
    return null;
  }

  BrawlMonsterDef get def => switch (this) {
    BrawlMonster.troll => _troll,
    BrawlMonster.fog => _fog,
  };
}

/// How hard each kind of hit lands on a monster. Above 1.4 reads as "weak to
/// this", at or under 0.8 reads as "resists this".
final class BrawlDamageMult {
  const BrawlDamageMult({
    required this.fist,
    required this.slam,
    required this.spell,
    required this.friend,
    required this.superMove,
  });

  final double fist;
  final double slam;
  final double spell;
  final double friend;
  final double superMove;

  double of(BrawlDamageSource source) => switch (source) {
    BrawlDamageSource.fist => fist,
    BrawlDamageSource.slam => slam,
    BrawlDamageSource.spell => spell,
    BrawlDamageSource.friend => friend,
    BrawlDamageSource.superMove => superMove,
    BrawlDamageSource.focus => 1,
    BrawlDamageSource.finisher => 1,
  };
}

/// Everything about a monster that does not change during a fight. Geometry
/// (the hurt ellipse) is in logical pixels; [x0] is where it rests.
final class BrawlMonsterDef {
  const BrawlMonsterDef({
    required this.key,
    required this.name,
    required this.the,
    required this.weak,
    required this.x0,
    required this.rx,
    required this.ry,
    required this.cy,
    required this.draw,
    required this.vis,
    required this.hpMult,
    required this.titles,
    required this.mult,
    required this.weakText,
    required this.weakLine,
    required this.moveName,
    required this.moveLine,
    required this.finisher,
    required this.door,
    required this.doorSub,
    required this.loot,
  });

  final String key;
  final String name;
  final String the;

  /// The stat whose ability this monster is weak to.
  final BrawlStat weak;
  final double x0;
  final double rx;
  final double ry;
  final double cy;
  final double draw;
  final double vis;

  /// Nudges the calibrated health so both monsters land on the same time.
  final double hpMult;

  /// Four ranks that grow grander with level (see [brawlRankOf]).
  final List<String> titles;
  final BrawlDamageMult mult;
  final String weakText;
  final String weakLine;
  final String moveName;
  final String moveLine;

  /// The line shown when the finisher lands.
  final String finisher;
  final String door;
  final String doorSub;

  /// Chest loot by tier (swift, steady, patient).
  final Map<BrawlChest, String> loot;
}

/// The chest you earn by speed.
enum BrawlChest { swift, steady, patient }

/// Swift chest at or under this many seconds.
const double kBrawlSwiftSeconds = 25;

/// Steady chest at or under this many seconds; Patient after.
const double kBrawlSteadySeconds = 50;

/// The chest for a finish time. The thresholds are the earlier 60 s and 120 s
/// scaled to the 70 s quiet-week target.
BrawlChest brawlChestFor(double seconds) {
  if (seconds <= kBrawlSwiftSeconds) return BrawlChest.swift;
  if (seconds <= kBrawlSteadySeconds) return BrawlChest.steady;
  return BrawlChest.patient;
}

/// 0 to 3: how grand the monster looks and sounds at this level.
int brawlRankOf(int level) {
  if (level < 4) return 0;
  if (level < 8) return 1;
  if (level < 13) return 2;
  return 3;
}

/// The monster's title at this level ("Cushion Squatter" up to "Duke of the
/// Recliner").
String brawlMonsterTitle(BrawlMonster monster, int level) =>
    monster.def.titles[brawlRankOf(level)];

/// A clock reading like 1:05 for a number of seconds.
String brawlFormatTime(double seconds) {
  final s = seconds < 0 ? 0 : seconds.round();
  final mm = s ~/ 60;
  final ss = s % 60;
  return '$mm:${ss.toString().padLeft(2, '0')}';
}

const BrawlMonsterDef _troll = BrawlMonsterDef(
  key: 'troll',
  name: 'Couch Troll',
  the: 'The Couch Troll',
  weak: BrawlStat.str,
  x0: 350,
  rx: 50,
  ry: 56,
  cy: 56,
  draw: 0.85,
  vis: 80,
  hpMult: 0.97,
  titles: [
    'Cushion Squatter',
    'Couch Troll',
    'Sofa Baron',
    'Duke of the Recliner',
  ],
  mult: BrawlDamageMult(
    fist: 1.15,
    slam: 1.9,
    spell: 1.0,
    friend: 1.1,
    superMove: 1.0,
  ),
  weakText: 'Weak to Strength',
  weakLine: 'Big slams make the sofa wobble.',
  moveName: 'Cushion slam',
  moveLine: 'Slow and loud. Jump over the wave.',
  finisher: 'You tucked the Couch Troll in for a nap.',
  door: 'The Couch Troll is blocking the door',
  doorSub: 'He is not angry. He is just very comfortable.',
  loot: {
    BrawlChest.swift: 'Golden Doormat',
    BrawlChest.steady: 'Porch Lantern',
    BrawlChest.patient: 'Doorstop Cushion',
  },
);

const BrawlMonsterDef _fog = BrawlMonsterDef(
  key: 'fog',
  name: 'The Fog',
  the: 'The Fog',
  weak: BrawlStat.intl,
  x0: 335,
  rx: 54,
  ry: 44,
  cy: 66,
  draw: 0.9,
  vis: 66,
  hpMult: 1.06,
  titles: ['Mist Wisp', 'The Fog', 'Thick Fog', 'Marquess of Murk'],
  mult: BrawlDamageMult(
    fist: 0.5,
    slam: 0.65,
    spell: 1.6,
    friend: 0.7,
    superMove: 1.0,
  ),
  weakText: 'Weak to Intellect',
  weakLine: 'Fists only half land on a cloud.',
  moveName: 'Drizzle',
  moveLine: 'Soft drops fall where it points. Step aside.',
  finisher: 'You blew the Fog into a little cloud. It watered the plant.',
  door: 'The Fog rolled in over the porch',
  doorSub: 'It is curious about you. Mostly.',
  loot: {
    BrawlChest.swift: 'Cloud Lamp',
    BrawlChest.steady: 'Rain Chain',
    BrawlChest.patient: 'Dew Jar',
  },
);
