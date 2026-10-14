import 'brawl_events.dart';
import 'brawl_monsters.dart';

/// Where the fight is in its story.
enum BrawlPhase {
  /// The fighter walks in; nothing can be hit yet.
  intro,
  fight,

  /// The monster is dazed and FINISH IT! is on screen.
  daze,
  finisher,

  /// The finisher is over; the result is ready.
  done,
}

enum BrawlFighterState {
  free,
  attack,
  dive,
  land,
  charge,
  slam,
  cast,
  call,
  superMove,
  hurt,
  down,
  getup,
  finish,
}

/// Animation names for the fighter, and for friends (who share the combo
/// moves, the run and the wave).
enum BrawlFighterAnim {
  idle,
  run,
  runBack,
  jump,
  fall,
  jab,
  cross,
  kick,
  upper,
  dive,
  diveLand,
  chargeSlam,
  slamRise,
  slamFall,
  slamLand,
  cast,
  call,
  superWind,
  superFlurry,
  superBlast,
  hurt,
  down,
  getup,
  finToss,
  pat,
  victory,
  inhale,
  blow,
  wave,
}

/// The monster's state. It is also its animation.
enum BrawlMonsterState { idle, telegraph, strike, recover, daze }

/// One melee move: timings in seconds, reach and height in pixels.
final class BrawlAttack {
  const BrawlAttack({
    required this.anim,
    required this.move,
    required this.start,
    required this.act,
    required this.rec,
    required this.cancel,
    required this.mult,
    required this.reach,
    required this.lunge,
    required this.stop,
    required this.heavy,
    required this.hy,
  });

  final BrawlFighterAnim anim;
  final BrawlMove move;
  final double start;
  final double act;
  final double rec;
  final double cancel;
  final double mult;
  final double reach;
  final double lunge;
  final double stop;
  final bool heavy;
  final double hy;
}

/// Jab, cross, kick, upper: the combo's four moves.
const List<BrawlAttack> kBrawlAttacks = [
  BrawlAttack(
    anim: BrawlFighterAnim.jab,
    move: BrawlMove.jab,
    start: 0.05,
    act: 0.05,
    rec: 0.15,
    cancel: 0.06,
    mult: 1.00,
    reach: 44,
    lunge: 14,
    stop: 0.05,
    heavy: false,
    hy: 34,
  ),
  BrawlAttack(
    anim: BrawlFighterAnim.cross,
    move: BrawlMove.cross,
    start: 0.05,
    act: 0.05,
    rec: 0.16,
    cancel: 0.06,
    mult: 1.00,
    reach: 46,
    lunge: 16,
    stop: 0.05,
    heavy: false,
    hy: 34,
  ),
  BrawlAttack(
    anim: BrawlFighterAnim.kick,
    move: BrawlMove.kick,
    start: 0.07,
    act: 0.06,
    rec: 0.20,
    cancel: 0.08,
    mult: 1.40,
    reach: 52,
    lunge: 18,
    stop: 0.05,
    heavy: false,
    hy: 26,
  ),
  BrawlAttack(
    anim: BrawlFighterAnim.upper,
    move: BrawlMove.upper,
    start: 0.08,
    act: 0.07,
    rec: 0.26,
    cancel: 0.10,
    mult: 1.90,
    reach: 44,
    lunge: 12,
    stop: 0.09,
    heavy: true,
    hy: 46,
  ),
];

/// The fighter. Every field is live: a renderer reads it each frame.
final class BrawlFighterBody {
  double x = 0;

  /// Height above the ground line.
  double h = 0;
  double vx = 0;
  double vh = 0;
  bool grounded = true;
  int jumps = 1;
  double coyote = 0;
  double gscale = 1;
  BrawlFighterState state = BrawlFighterState.free;

  /// Seconds in the current state.
  double st = 0;
  BrawlFighterAnim anim = BrawlFighterAnim.idle;
  double animT = 0;

  int atkIdx = 0;
  BrawlAttack atkDef = kBrawlAttacks[0];
  bool atkHit = false;
  double atkLunge = 0;
  double atkTargetX = 0;
  double dashLead = 0;
  int chainIdx = -1;
  double chainT = 0;

  double holdT = 0;

  /// Seconds the slam has been charging.
  double charge = 0;
  bool chargeReady = false;
  bool holdUsed = false;
  double slamPow = 0;
  double slamRecover = 0;
  bool castDone = false;
  bool callDone = false;
  bool cutArmed = false;
  double diveLock = 0;
  bool diveHit = false;

  int superI = 0;
  int superStage = 0;
  double superX = 0;
  double superX0 = 0;

  /// Seconds of not being hurtable.
  double invuln = 0;
  double hp = 0;
  double hpMax = 0;
  double lieT = 0;
  double lieDur = 0;
  bool caught = false;
  double lastLandV = 0;
  double finX = 0;
  double finX0 = 0;
}

/// The monster.
final class BrawlMonsterBody {
  BrawlMonsterBody({
    required this.kind,
    required this.rank,
    required this.scale,
    required this.x,
    required this.rx,
    required this.ry,
    required this.cy,
    required this.hpMax,
  }) : def = kind.def,
       hp = hpMax;

  final BrawlMonster kind;
  final BrawlMonsterDef def;

  /// 0 to 3, from the level.
  final int rank;

  /// How big it is drawn, relative to its base size.
  final double scale;
  double x;
  final double rx;
  final double ry;
  double cy;
  double bob = 0;
  final double hpMax;
  double hp;
  BrawlMonsterState state = BrawlMonsterState.idle;
  double st = 0;
  double animT = 0;
  double moveT = 7.2;
  double teleDur = 0;
  double strikeDur = 0;
}

/// A spell bolt in flight.
final class BrawlBolt {
  BrawlBolt({
    required this.x,
    required this.h,
    required this.v,
    required this.delay,
    required this.dmg,
    required this.big,
    required this.chain,
    required this.index,
  });

  double x;
  final double h;
  final double v;
  double delay;
  final double dmg;
  final bool big;
  final bool chain;
  final int index;
}

/// The Troll's cushion-slam wave rolling toward the fighter.
final class BrawlWave {
  BrawlWave({
    required this.x,
    required this.v,
    required this.w,
    required this.hgt,
  });

  double x;
  final double v;
  final double w;

  /// How high the wave is; jump over it.
  final double hgt;
  double age = 0;
  bool hit = false;
  bool passed = false;
}

enum BrawlDropState { mark, fall, splash }

/// One of the Fog's raindrops: marked on the floor, then it falls.
final class BrawlDrop {
  BrawlDrop({
    required this.x,
    required this.t,
    required this.fall,
    required this.r,
  });

  final double x;
  double t;
  final double fall;
  final double r;
  BrawlDropState state = BrawlDropState.mark;
}

enum BrawlFriendState { wait, enter, atk, wave, exit }

/// A friend who dashes in, does a combo and leaves.
final class BrawlFriend {
  BrawlFriend({required this.index, required this.x, required this.t});

  final int index;
  double x;
  double t;
  BrawlFriendState state = BrawlFriendState.wait;
  int hits = 0;
  BrawlFighterAnim anim = BrawlFighterAnim.run;
  double animT = 0;
}

/// The finisher in progress.
final class BrawlFinisher {
  BrawlFinisher({required this.kind, required this.dur});

  double t = 0;
  final BrawlMonster kind;
  final double dur;
  final Set<String> flags = {};
}

/// The combo counter.
final class BrawlCombo {
  int n = 0;

  /// Seconds left before the counter drops.
  double t = 0;
  int best = 0;
  double dmg = 0;
}

/// Seconds before each ability is ready again.
final class BrawlCooldowns {
  double spell = 0;
  double friend = 0;
  double slam = 0;
}

/// Damage by source, used for the victory breakdown and for tuning.
final class BrawlDamageBook {
  double fist = 0;
  double slam = 0;
  double spell = 0;
  double friend = 0;
  double superMove = 0;
  double focus = 0;
  double finisher = 0;

  double of(BrawlDamageSource source) => switch (source) {
    BrawlDamageSource.fist => fist,
    BrawlDamageSource.slam => slam,
    BrawlDamageSource.spell => spell,
    BrawlDamageSource.friend => friend,
    BrawlDamageSource.superMove => superMove,
    BrawlDamageSource.focus => focus,
    BrawlDamageSource.finisher => finisher,
  };

  void add(BrawlDamageSource source, double amount) {
    switch (source) {
      case BrawlDamageSource.fist:
        fist += amount;
      case BrawlDamageSource.slam:
        slam += amount;
      case BrawlDamageSource.spell:
        spell += amount;
      case BrawlDamageSource.friend:
        friend += amount;
      case BrawlDamageSource.superMove:
        superMove += amount;
      case BrawlDamageSource.focus:
        focus += amount;
      case BrawlDamageSource.finisher:
        finisher += amount;
    }
  }

  /// Everything dealt before the finisher.
  double get total => fist + slam + spell + friend + superMove + focus;
}

/// Counters for the victory screen and for tuning.
final class BrawlFightStats {
  final BrawlDamageBook dmg = BrawlDamageBook();
  int crits = 0;
  int dcrits = 0;
  int hits = 0;
  int whiffs = 0;
  int presses = 0;
  int attacks = 0;
  int supers = 0;
  int spells = 0;
  int calls = 0;
  int slams = 0;
  int dives = 0;
  int getups = 0;
  int maxCombo = 0;
}
