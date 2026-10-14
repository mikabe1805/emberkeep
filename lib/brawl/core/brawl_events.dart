import 'brawl_monsters.dart';
import 'brawl_stats.dart';

/// Which move produced a hit. The values match the prototype's `idx`, so a
/// renderer can pick a sound or a smear by index too.
enum BrawlMove {
  jab,
  cross,
  kick,
  upper,
  dive,
  slam,
  wave,
  spell,
  chain,
  friend,
  superFlurry,
  superBlast,
}

/// What hurt the fighter.
enum BrawlHazard { wave, drop }

/// The big words the announcer shows.
enum BrawlCue {
  round1('ROUND 1'),
  fight('FIGHT!'),
  friend('FRIEND!'),
  superMove('SUPER!'),
  finishIt('FINISH IT!'),
  ko('K.O.'),
  perfect('PERFECT');

  const BrawlCue(this.text);
  final String text;
}

enum BrawlEventType {
  /// The intro is over; the fight has begun.
  fightStart,

  /// A big word for the announcer: see [BrawlEvent.cue]. The first event of
  /// every fight is ROUND 1.
  announce,

  jump,
  land,

  /// A melee swing began ([BrawlEvent.move] says which).
  swing,
  whiff,

  /// The monster was hit. Carries damage, crit level, shake and hit-stop.
  hit,
  dive,
  bounce,
  slamCharge,
  slamReady,
  slam,
  slamImpact,
  groundWave,
  cast,
  bolt,
  chainBolt,
  call,
  friendEnter,
  friendLeave,
  superStart,
  superHit,
  superBlast,
  superEnd,
  meterFull,
  telegraph,
  strike,
  drop,
  splash,

  /// You stepped or jumped clear of the monster's move.
  dodge,

  /// You were bumped. Never harmful: you catch your breath and get back up.
  hurt,
  catchBreath,
  getup,
  secondWind,

  /// A button for a locked ability was pressed ([BrawlEvent.stat]).
  locked,

  /// The monster is dazed: FINISH IT!
  daze,
  finishStart,
  finBlanket,
  finTuck,
  finSnore,
  finBlow,
  finCloud,
  finWater,
  ko,
  perfect,

  /// The finisher is over and the victory screen can open.
  victory,
}

/// One thing that happened in a step, for the renderer, the sound and the
/// announcer. Only the fields that belong to [type] are meaningful; the rest
/// stay at their defaults.
///
/// Positions are in the fight's logical pixels (x to the right, y is height
/// above the ground line for hits).
final class BrawlEvent {
  const BrawlEvent(
    this.type, {
    this.x = 0,
    this.y = 0,
    this.source,
    this.move,
    this.damage = 0,
    this.crit = 0,
    this.heavy = false,
    this.big = false,
    this.weak = false,
    this.resist = false,
    this.combo = 0,
    this.shake = 0,
    this.hitStop = 0,
    this.label = '',
    this.power = 0,
    this.air = false,
    this.hitMonster = false,
    this.count = 0,
    this.index = 0,
    this.total = 0,
    this.stat,
    this.monster,
    this.hazard,
    this.knockedDown = false,
    this.duration = 0,
    this.cue,
  });

  final BrawlEventType type;
  final double x;
  final double y;

  /// hit: which kind of damage it was.
  final BrawlDamageSource? source;

  /// hit and swing: which move.
  final BrawlMove? move;

  /// hit: the number to float up.
  final int damage;

  /// hit: 0 normal, 1 critical, 2 double critical.
  final int crit;
  final bool heavy;

  /// hit: a bigger version of its move (a charged slam, a blast, a dive).
  final bool big;

  /// hit: the monster is weak to this kind of hit.
  final bool weak;

  /// hit: the monster resists this kind of hit.
  final bool resist;

  /// hit: the combo count including this hit.
  final int combo;

  /// Screen shake in logical pixels (hit, slamImpact, strike, hurt,
  /// superHit, superBlast).
  final double shake;

  /// hit and hurt: seconds the world freezes for impact.
  final double hitStop;

  /// hit: 'wave', 'chain' or 'super' for hits that need a small tag.
  final String label;

  /// land and slam: how hard the landing or charge was.
  final double power;

  /// jump: this was the second jump in the air.
  final bool air;

  /// slamImpact: the slam connected.
  final bool hitMonster;

  /// cast: bolts fired.
  final int count;

  /// superHit: which flurry hit, of [total]. friendEnter: which friend.
  final int index;
  final int total;

  /// locked: which stat's ability is locked.
  final BrawlStat? stat;

  /// telegraph, strike, finishStart: whose move.
  final BrawlMonster? monster;

  /// hurt: what bumped the fighter.
  final BrawlHazard? hazard;

  /// hurt: the fighter was knocked down (false in Easy mode, a gentle bump).
  final bool knockedDown;

  /// telegraph: seconds of warning before the move lands.
  final double duration;

  /// announce: the word.
  final BrawlCue? cue;

  @override
  String toString() => 'BrawlEvent($type)';
}
