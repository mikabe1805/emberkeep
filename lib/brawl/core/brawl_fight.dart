import 'dart:math' as math;

import 'brawl_config.dart';
import 'brawl_events.dart';
import 'brawl_input.dart';
import 'brawl_loadout.dart';
import 'brawl_monsters.dart';
import 'brawl_rng.dart';
import 'brawl_stats.dart';
import 'brawl_state.dart';
import 'brawl_tuning.dart';

double _clamp(double v, double a, double b) => v < a ? a : (v > b ? b : v);
double _lerp(double a, double b, double t) => a + (b - a) * t;
double _approach(double v, double t, double d) =>
    v < t ? math.min(t, v + d) : math.max(t, v - d);

final class _Pending {
  _Pending(this.t, this.fn);
  double t;
  final void Function() fn;
}

/// The weekend brawl, with no drawing and no sound: a side-view fight stepped
/// forward in small fixed slices. A renderer feeds it [BrawlInput] and reads
/// back the bodies, the [events] and the numbers on it.
///
/// Coordinates: x runs right in logical pixels, and `h` is the height above
/// the ground line (up is positive).
///
/// Build one with [createBrawlFight] (which sizes the monster's health for the
/// player) or, in tests, with [BrawlFight.new] and an explicit health.
final class BrawlFight {
  BrawlFight(this.config, {required double hpMax})
    : lo = BrawlLoadout.fromConfig(config),
      def = config.monster.def,
      easy = config.easy,
      _rng = BrawlRng(config.seed) {
    final rank = brawlRankOf(config.level);
    final rs = 0.92 + 0.045 * rank;
    seq = lo.chain == 4 ? _seq4 : _seq3;
    m = BrawlMonsterBody(
      kind: config.monster,
      rank: rank,
      scale: rs,
      x: def.x0,
      rx: def.rx * rs,
      ry: def.ry * rs,
      cy: def.cy * rs,
      hpMax: hpMax,
    );
    f = BrawlFighterBody()
      ..x = BrawlTune.startX
      ..hp = lo.vit.hpMax
      ..hpMax = lo.vit.hpMax;
    _emit(BrawlEvent(BrawlEventType.announce, cue: BrawlCue.round1));
  }

  static const List<int> _seq3 = [0, 1, 3];
  static const List<int> _seq4 = [0, 1, 2, 3];

  final BrawlConfig config;
  final BrawlLoadout lo;
  final BrawlMonsterDef def;
  final bool easy;
  final BrawlRng _rng;

  /// The melee chain: indexes into [kBrawlAttacks].
  late final List<int> seq;
  late final BrawlMonsterBody m;
  late final BrawlFighterBody f;

  final double w = BrawlTune.worldW;

  BrawlPhase phase = BrawlPhase.intro;

  /// Seconds since the fight began, counting the intro.
  double clock = 0;

  /// Seconds of actual fighting (this is the time the victory screen shows).
  double t = 0;
  double introT = 0;
  double dazeT = 0;

  /// Seconds of hit-stop left: the world holds still while this is above 0.
  double freeze = 0;

  /// 1 normally; the finisher eases it down for slow motion.
  double timeScale = 1;

  /// A cinematic (the Super) is playing: only the fighter acts.
  bool cine = false;
  double _dodgeCool = 0;

  /// What happened since the last [drainEvents].
  final List<BrawlEvent> events = [];

  final BrawlCooldowns cd = BrawlCooldowns();

  /// The Super meter, 0 to 100.
  double sup = 0;
  final BrawlCombo combo = BrawlCombo();
  final List<BrawlBolt> bolts = [];
  final List<BrawlWave> waves = [];
  final List<BrawlDrop> drops = [];
  final List<BrawlFriend> friends = [];
  final List<_Pending> _pend = [];
  BrawlFinisher? fin;

  /// The fight clock at the moment FINISH IT! was tapped. This is the time
  /// that earns the chest.
  double finishTime = 0;
  int hitsTaken = 0;
  int knockdowns = 0;
  bool perfect = true;
  final BrawlFightStats stats = BrawlFightStats();

  late BrawlInput _in;
  double _bAtk = 0;
  double _bJump = 0;
  double _bSpell = 0;
  double _bFriend = 0;
  double _bSup = 0;
  double _bFin = 0;

  bool get isDone => phase == BrawlPhase.done;

  /// Power Slam is unlocked and recharged (the ATTACK button can glow).
  bool get slamReady => lo.slam.on && cd.slam <= 0;

  /// Spell Bolt is unlocked and recharged.
  bool get spellReady => lo.spell.on && cd.spell <= 0;

  /// Call a Friend is unlocked and recharged.
  bool get friendReady => lo.friend.on && cd.friend <= 0;

  /// The Super is unlocked and the meter is full.
  bool get superReady => lo.dis.on && sup >= 100;

  /// The events since the last call, and forgets them.
  List<BrawlEvent> drainEvents() {
    final out = List<BrawlEvent>.of(events);
    events.clear();
    return out;
  }

  // ---------------------------------------------------------------- utils

  void _emit(BrawlEvent e) => events.add(e);

  void _cue(BrawlCue cue) =>
      _emit(BrawlEvent(BrawlEventType.announce, cue: cue));

  double _rand(double a, double c) => a + (c - a) * _rng.next();

  void _setAnim(BrawlFighterAnim name) {
    if (f.anim != name) {
      f.anim = name;
      f.animT = 0;
    }
  }

  void _setState(BrawlFighterState s) {
    f.state = s;
    f.st = 0;
  }

  /// The x of the monster's front edge at height [h].
  double frontAt(double h) {
    final d = (h - m.cy) / m.ry;
    return m.x - m.rx * math.sqrt(math.max(0.0, 1 - d * d));
  }

  bool _inEllipse(double px, double ph, double r) {
    final dx = (px - m.x) / (m.rx + r);
    final dy = (ph - m.cy) / (m.ry + r);
    return dx * dx + dy * dy <= 1;
  }

  /// The furthest right the fighter can stand.
  double solidX() => m.x - m.rx * 0.82 - 16;

  bool _monsterHurtable() =>
      phase == BrawlPhase.fight && m.state != BrawlMonsterState.daze;

  bool _busy() =>
      f.state == BrawlFighterState.down ||
      f.state == BrawlFighterState.getup ||
      f.state == BrawlFighterState.hurt ||
      f.state == BrawlFighterState.superMove ||
      f.state == BrawlFighterState.finish;

  // ---------------------------------------------------------------- input

  void _consume(BrawlInput inp, double dt) {
    if (inp.pAtk) {
      _bAtk = BrawlTune.atkBuf;
      inp.pAtk = false;
      f.holdT = 0;
      f.holdUsed = false;
      stats.presses++;
    }
    if (inp.pJump) {
      _bJump = BrawlTune.jumpBuf;
      inp.pJump = false;
    }
    if (inp.pSpell) {
      _bSpell = BrawlTune.abBuf;
      inp.pSpell = false;
    }
    if (inp.pFriend) {
      _bFriend = BrawlTune.abBuf;
      inp.pFriend = false;
    }
    if (inp.pSuper) {
      _bSup = BrawlTune.abBuf;
      inp.pSuper = false;
    }
    if (inp.pFinish) {
      _bFin = BrawlTune.abBuf;
      inp.pFinish = false;
    }
    if (inp.attackHeld) {
      f.holdT += dt;
    } else {
      f.holdT = 0;
    }
  }

  void _tickBuffers(double dt) {
    _bAtk = math.max(0.0, _bAtk - dt);
    _bJump = math.max(0.0, _bJump - dt);
    _bSpell = math.max(0.0, _bSpell - dt);
    _bFriend = math.max(0.0, _bFriend - dt);
    _bSup = math.max(0.0, _bSup - dt);
    _bFin = math.max(0.0, _bFin - dt);
  }

  // ---------------------------------------------------------------- damage

  void _addCombo() {
    combo.n++;
    combo.t = BrawlTune.comboKeep + lo.focus.window * 1.2;
    if (combo.n > combo.best) combo.best = combo.n;
    if (combo.n > stats.maxCombo) stats.maxCombo = combo.n;
  }

  double _hitMonster({
    required BrawlDamageSource kind,
    required double base,
    required double x,
    required double y,
    required BrawlMove move,
    bool heavy = false,
    double? stop,
    double shake = 0,
    bool big = false,
    String label = '',
    bool noCrit = false,
    bool noMeter = false,
  }) {
    if (!_monsterHurtable()) return 0;
    final mult = def.mult.of(kind);
    final raw = math.max(
      1,
      (base * mult * lo.aura * (1 + (_rng.next() - 0.5) * 0.12)).round(),
    );
    var dmg = raw.toDouble();
    var crit = 0;
    if (!noCrit && _rng.next() < lo.focus.chance) {
      crit = 1;
      dmg = raw * lo.focus.mult;
      if (lo.focus.dbl > 0 && _rng.next() < lo.focus.dbl) {
        crit = 2;
        dmg = raw * lo.focus.dblMult;
      }
    }
    final shown = math.max(1, dmg.round());
    final floor = (m.hpMax * BrawlTune.dazeAt).roundToDouble();
    final applied = (m.hp - shown <= floor)
        ? math.max(0.0, m.hp - floor)
        : shown.toDouble();
    m.hp -= applied;
    final baseShare = applied * (raw / shown);
    stats.dmg.add(kind, baseShare);
    stats.dmg.add(BrawlDamageSource.focus, applied - baseShare);
    stats.hits++;
    if (crit > 0) stats.crits++;
    if (crit == 2) stats.dcrits++;
    _addCombo();
    combo.dmg += applied;
    if (!noMeter && lo.dis.on) {
      final was = sup;
      sup = math.min(100.0, sup + lo.dis.fill * (heavy ? 1.8 : 1));
      if (was < 100 && sup >= 100) {
        _emit(const BrawlEvent(BrawlEventType.meterFull));
      }
    }
    final stopT = stop ?? (heavy ? 0.09 : 0.05);
    freeze = math.max(freeze, stopT);
    _emit(
      BrawlEvent(
        BrawlEventType.hit,
        source: kind,
        move: move,
        x: x,
        y: y,
        damage: shown,
        crit: crit,
        heavy: heavy,
        shake: shake,
        hitStop: stopT,
        label: label,
        weak: mult >= 1.4,
        resist: mult <= 0.8,
        combo: combo.n,
        big: big,
      ),
    );
    if (m.hp <= floor) _enterDaze();
    return applied;
  }

  void _enterDaze() {
    if (phase != BrawlPhase.fight) return;
    phase = BrawlPhase.daze;
    dazeT = 0;
    m.state = BrawlMonsterState.daze;
    m.st = 0;
    m.animT = 0;
    _pend.clear();
    waves.clear();
    drops.clear();
    _emit(const BrawlEvent(BrawlEventType.daze));
    _cue(BrawlCue.finishIt);
  }

  // ---------------------------------------------------------------- fighter: jumping, landing, integration

  void _doJump() {
    _bJump = 0;
    if (f.grounded || f.coyote > 0) {
      f.vh = BrawlTune.jumpV;
      f.grounded = false;
      f.coyote = 0;
      f.jumps = 1;
      f.gscale = 1;
      f.cutArmed = true;
      _emit(BrawlEvent(BrawlEventType.jump, x: f.x));
    } else if (f.jumps > 0) {
      f.jumps--;
      f.vh = BrawlTune.airJumpV;
      f.gscale = 1;
      f.cutArmed = false;
      _emit(BrawlEvent(BrawlEventType.jump, x: f.x, air: true));
    }
  }

  void _integrate(double dt) {
    f.x += f.vx * dt;
    if (!f.grounded) {
      f.h += f.vh * dt;
      f.vh -= BrawlTune.gravity * f.gscale * dt;
      if (f.h <= 0 && f.vh <= 0) {
        final v = -f.vh;
        f.h = 0;
        f.vh = 0;
        f.grounded = true;
        f.jumps = 1;
        f.gscale = 1;
        f.lastLandV = v;
        _emit(BrawlEvent(BrawlEventType.land, x: f.x, power: v));
        _onLand();
      }
    }
    final maxX = solidX();
    if (f.x > maxX) {
      f.x = maxX;
      if (f.vx > 0) f.vx = 0;
    }
    if (f.x < 14) {
      f.x = 14;
      if (f.vx < 0) f.vx = 0;
    }
  }

  void _onLand() {
    if (f.state == BrawlFighterState.dive) {
      _diveEnd(false);
    } else if (f.state == BrawlFighterState.slam) {
      _slamImpact();
    }
  }

  // ---------------------------------------------------------------- fighter: free state

  void _stFree(double dt) {
    final lock = phase == BrawlPhase.intro;
    final mx = lock ? 0.0 : _in.moveX;
    final target = mx * BrawlTune.runSpeed * (f.grounded ? 1 : 0.92);
    final rate = target == 0
        ? BrawlTune.friction * (f.grounded ? 1 : 0.35)
        : (f.grounded ? BrawlTune.accel : BrawlTune.airAccel);
    f.vx = _approach(f.vx, target, rate * dt);
    if (!lock && _bJump > 0) _doJump();
    // Variable jump height: letting go of the jump key early trims the rise.
    if (!f.grounded && f.cutArmed && f.vh > 160 && !_in.jumpHeld) {
      f.vh *= BrawlTune.jumpCut;
      f.cutArmed = false;
    }
    _integrate(dt);
    f.coyote = f.grounded ? BrawlTune.coyote : math.max(0.0, f.coyote - dt);
    if (!f.grounded) {
      _setAnim(f.vh > 40 ? BrawlFighterAnim.jump : BrawlFighterAnim.fall);
    } else if (f.vx.abs() > 24) {
      _setAnim(f.vx > 0 ? BrawlFighterAnim.run : BrawlFighterAnim.runBack);
    } else {
      _setAnim(BrawlFighterAnim.idle);
    }
    if (lock) return;
    _tryActions(false);
  }

  /// Shared by the free state and by recovery cancels. [fromAttack] means we
  /// are cancelling attack recovery.
  bool _tryActions(bool fromAttack) {
    if (phase == BrawlPhase.daze && (_bAtk > 0 || _bFin > 0)) {
      _startFinisher();
      return true;
    }
    if (_bSup > 0) {
      if (lo.dis.on && sup >= 100) {
        _startSuper();
        return true;
      }
      if (!lo.dis.on) {
        _bSup = 0;
        _emit(const BrawlEvent(BrawlEventType.locked, stat: BrawlStat.dis));
      }
    }
    if (_bSpell > 0) {
      if (!lo.spell.on) {
        _bSpell = 0;
        _emit(const BrawlEvent(BrawlEventType.locked, stat: BrawlStat.intl));
      } else if (cd.spell <= 0) {
        _startCast();
        return true;
      }
    }
    if (_bFriend > 0) {
      if (!lo.friend.on) {
        _bFriend = 0;
        _emit(const BrawlEvent(BrawlEventType.locked, stat: BrawlStat.soc));
      } else if (cd.friend <= 0) {
        _startCall();
        return true;
      }
    }
    if (_bJump > 0 && fromAttack) {
      _setState(BrawlFighterState.free);
      _doJump();
      return true;
    }
    if (_bAtk > 0 && !fromAttack) {
      if (f.grounded) {
        _startAttack(_nextIdx(false));
        return true;
      }
      if (f.h > 12 && !(f.diveLock > 0)) {
        _startDive();
        return true;
      }
    }
    if (!fromAttack &&
        _in.attackHeld &&
        f.grounded &&
        f.holdT >= BrawlTune.holdToSlam &&
        !f.holdUsed &&
        lo.slam.on &&
        cd.slam <= 0 &&
        _bAtk <= 0) {
      _startCharge();
      return true;
    }
    return false;
  }

  int _nextIdx(bool fromAttack) {
    if (fromAttack) {
      final n = f.chainIdx + 1;
      return n < seq.length ? n : -1;
    }
    if (f.chainT > 0 && f.chainIdx >= 0 && f.chainIdx < seq.length - 1) {
      return f.chainIdx + 1;
    }
    return 0;
  }

  // ---------------------------------------------------------------- fighter: melee chain

  void _startAttack(int ci) {
    _bAtk = 0;
    final a = kBrawlAttacks[seq[ci]];
    f.chainIdx = ci;
    f.atkIdx = seq[ci];
    f.atkDef = a;
    f.atkHit = false;
    _setState(BrawlFighterState.attack);
    f.st = 0;
    stats.attacks++;
    // Magnetism: slide toward the monster so combos stick.
    final standX = frontAt(a.hy) - (a.reach - 14);
    final gap = standX - f.x;
    final mag = easy ? BrawlTune.magnetEasy : BrawlTune.magnet;
    f.atkLunge = _clamp(gap, 0, mag);
    f.dashLead = 0;
    if (f.atkLunge > 90) {
      // Too far for a lunge: a quick dash first (easy mode).
      f.dashLead = f.atkLunge / BrawlTune.dashSpeed;
      f.st = -f.dashLead;
      f.atkTargetX = f.x + f.atkLunge;
      f.atkLunge = 0;
    }
    f.chainT = 0;
    _setAnim(a.anim);
    _emit(BrawlEvent(BrawlEventType.swing, move: a.move, x: f.x, index: ci));
  }

  void _stAttack(double dt) {
    final a = f.atkDef;
    if (f.st < 0) {
      // Dash lead.
      _setAnim(BrawlFighterAnim.run);
      f.vx = BrawlTune.dashSpeed;
      f.st += dt;
      f.x += f.vx * dt;
      if (f.x >= f.atkTargetX || f.st >= 0) {
        f.x = math.min(f.atkTargetX, solidX());
        f.st = math.max(f.st, 0.0);
        f.vx = 0;
        _setAnim(a.anim);
      }
      final mx = solidX();
      if (f.x > mx) f.x = mx;
      return;
    }
    f.st += dt;
    _setAnim(a.anim);
    if (f.st < a.start) {
      f.vx = f.atkLunge / a.start;
    } else {
      f.vx = _approach(f.vx, 0, BrawlTune.friction * dt);
    }
    _integrate(dt);
    if (!f.atkHit && f.st >= a.start) {
      f.atkHit = true;
      _doMelee();
    }
    final total = a.start + a.act + a.rec;
    if (f.st >= a.start + a.act) {
      // Abilities can cancel recovery at once.
      if (_tryActions(true)) return;
    }
    if (f.st >= a.start + a.act + a.cancel) {
      if (_bAtk > 0) {
        final n = _nextIdx(true);
        if (n >= 0) {
          _startAttack(n);
          return;
        }
      }
    }
    if (f.st >= total) {
      _setState(BrawlFighterState.free);
      f.chainT = BrawlTune.chainWin + lo.focus.window;
      if (f.chainIdx >= seq.length - 1) f.chainT = 0;
    }
  }

  void _doMelee() {
    final a = f.atkDef;
    final px = f.x + a.reach;
    final ph = f.h + a.hy;
    if (_monsterHurtable() && _inEllipse(px, ph, 12)) {
      final hx = _clamp(px, f.x + 20, frontAt(ph) + 8);
      _hitMonster(
        kind: BrawlDamageSource.fist,
        base: lo.fistPower * a.mult,
        heavy: a.heavy,
        stop: a.stop,
        x: hx,
        y: ph,
        move: a.move,
        shake: a.heavy ? 4 : 0,
      );
    } else {
      stats.whiffs++;
      _emit(BrawlEvent(BrawlEventType.whiff, x: px, y: ph));
    }
  }

  // ---------------------------------------------------------------- fighter: dive kick

  void _startDive() {
    _bAtk = 0;
    _setState(BrawlFighterState.dive);
    stats.dives++;
    f.vx = 300;
    f.vh = -690;
    f.gscale = 0;
    f.diveHit = false;
    _setAnim(BrawlFighterAnim.dive);
    _emit(BrawlEvent(BrawlEventType.dive, x: f.x));
  }

  void _stDive(double dt) {
    _integrate(dt);
    if (f.state != BrawlFighterState.dive) return;
    if (!f.diveHit && _monsterHurtable() && _inEllipse(f.x + 14, f.h + 4, 16)) {
      f.diveHit = true;
      _hitMonster(
        kind: BrawlDamageSource.fist,
        base: lo.fistPower * 1.8,
        heavy: true,
        stop: 0.09,
        x: f.x + 18,
        y: f.h + 6,
        move: BrawlMove.dive,
        shake: 7,
        big: true,
      );
      _diveEnd(true);
    }
  }

  void _diveEnd(bool hit) {
    f.gscale = 1;
    if (hit) {
      f.vh = 400;
      f.vx = -190;
      f.grounded = false;
      f.jumps = 1;
      f.diveLock = 0.4;
      _setState(BrawlFighterState.free);
      _setAnim(BrawlFighterAnim.jump);
      _emit(BrawlEvent(BrawlEventType.bounce, x: f.x, y: f.h));
    } else {
      _setState(BrawlFighterState.land);
      f.vx = 40;
      _setAnim(BrawlFighterAnim.diveLand);
    }
  }

  void _stLand(double dt) {
    f.st += dt;
    f.vx = _approach(f.vx, 0, BrawlTune.friction * dt);
    _integrate(dt);
    if (_bJump > 0 && f.st > 0.08) {
      _setState(BrawlFighterState.free);
      _doJump();
      return;
    }
    if (f.st >= 0.16) _setState(BrawlFighterState.free);
  }

  // ---------------------------------------------------------------- fighter: Power Slam

  void _startCharge() {
    f.holdUsed = true;
    _setState(BrawlFighterState.charge);
    f.charge = 0;
    f.chargeReady = false;
    f.vx = 0;
    _setAnim(BrawlFighterAnim.chargeSlam);
    _emit(const BrawlEvent(BrawlEventType.slamCharge));
  }

  void _stCharge(double dt) {
    if (phase == BrawlPhase.daze) {
      // Nothing left to slam: go finish it.
      _setState(BrawlFighterState.free);
      return;
    }
    f.st += dt;
    f.charge += dt;
    f.vx = _approach(f.vx, 0, BrawlTune.friction * dt);
    _integrate(dt);
    if (!f.chargeReady && f.charge >= BrawlTune.slamFull) {
      f.chargeReady = true;
      _emit(const BrawlEvent(BrawlEventType.slamReady));
    }
    if (!_in.attackHeld) _startSlam();
  }

  void _startSlam() {
    final pow = _clamp(0.55 + 0.45 * (f.charge / BrawlTune.slamFull), 0.55, 1);
    f.slamPow = pow;
    _setState(BrawlFighterState.slam);
    stats.slams++;
    cd.slam = lo.slam.cd;
    // Aim to land near the monster front.
    final stand = frontAt(30) - 34;
    final tx = math.min(stand, f.x + 120);
    const flight = 0.40;
    f.vx = _clamp((tx - f.x) / flight, 0, 520);
    f.vh = 700;
    f.grounded = false;
    f.gscale = 2.0;
    f.jumps = 0;
    _setAnim(BrawlFighterAnim.slamRise);
    _emit(BrawlEvent(BrawlEventType.slam, x: f.x, power: pow));
  }

  void _stSlam(double dt) {
    if (f.grounded) {
      // Recovery after impact.
      f.st += dt;
      f.vx = _approach(f.vx, 0, BrawlTune.friction * dt);
      _integrate(dt);
      if (f.st >= f.slamRecover) {
        _setState(BrawlFighterState.free);
        f.chainT = 0;
      }
      return;
    }
    _integrate(dt);
    if (f.state == BrawlFighterState.slam && !f.grounded) {
      _setAnim(
        f.vh > -80 ? BrawlFighterAnim.slamRise : BrawlFighterAnim.slamFall,
      );
    }
  }

  void _slamImpact() {
    // Called from _onLand while the state is slam.
    f.st = 0;
    f.slamRecover = 0.34;
    f.vx = 0;
    f.gscale = 1;
    _setAnim(BrawlFighterAnim.slamLand);
    final px = f.x + 40;
    final hitIn = _monsterHurtable() && _inEllipse(px, 24, 22);
    _emit(
      BrawlEvent(
        BrawlEventType.slamImpact,
        x: f.x,
        hitMonster: hitIn,
        shake: hitIn ? 9 : 5,
      ),
    );
    if (hitIn) {
      final base = _lerp(lo.slam.min, lo.slam.max, (f.slamPow - 0.55) / 0.45);
      _hitMonster(
        kind: BrawlDamageSource.slam,
        base: base,
        heavy: true,
        stop: 0.09,
        x: math.min(px, frontAt(30) + 6),
        y: 30,
        shake: 9,
        big: true,
        move: BrawlMove.slam,
      );
      if (lo.slam.wave) {
        final fx = f.x;
        _pend.add(
          _Pending(0.16, () {
            _emit(BrawlEvent(BrawlEventType.groundWave, x: fx + 30));
            _hitMonster(
              kind: BrawlDamageSource.slam,
              base: base * 0.6,
              stop: 0.06,
              x: frontAt(20) + 4,
              y: 22,
              label: 'wave',
              move: BrawlMove.wave,
              shake: 3,
            );
          }),
        );
      }
    } else if (lo.slam.wave && _monsterHurtable()) {
      // A whiffed slam still sends a ground wave rolling to the monster.
      final base =
          _lerp(lo.slam.min, lo.slam.max, (f.slamPow - 0.55) / 0.45) * 0.6;
      final dist = math.max(0.0, frontAt(20) - f.x);
      final fx = f.x;
      _pend.add(
        _Pending(dist / 420, () {
          _emit(BrawlEvent(BrawlEventType.groundWave, x: fx + 30));
          _hitMonster(
            kind: BrawlDamageSource.slam,
            base: base,
            stop: 0.06,
            x: frontAt(20) + 4,
            y: 22,
            label: 'wave',
            move: BrawlMove.wave,
            shake: 3,
          );
        }),
      );
    }
  }

  // ---------------------------------------------------------------- fighter: Spell Bolt

  void _startCast() {
    _bSpell = 0;
    _setState(BrawlFighterState.cast);
    f.castDone = false;
    stats.spells++;
    cd.spell = lo.spell.cd;
    _setAnim(BrawlFighterAnim.cast);
    _emit(BrawlEvent(BrawlEventType.cast, x: f.x, count: lo.spell.count));
  }

  void _stCast(double dt) {
    f.st += dt;
    f.vx = _approach(f.vx, 0, BrawlTune.friction * dt);
    _integrate(dt);
    if (!f.castDone && f.st >= 0.10) {
      f.castDone = true;
      for (var i = 0; i < lo.spell.count; i++) {
        bolts.add(
          BrawlBolt(
            x: f.x + 24,
            h: f.h + 38 + (i > 0 ? 12 : 0),
            v: 560,
            delay: i * 0.09,
            dmg: lo.spell.dmg * (i > 0 ? BrawlTune.twin : 1),
            big: lo.spell.blast,
            chain: lo.spell.chain,
            index: i,
          ),
        );
      }
      _emit(BrawlEvent(BrawlEventType.bolt, x: f.x + 24, y: f.h + 38));
    }
    if (f.st >= 0.30) _setState(BrawlFighterState.free);
  }

  void _updateBolts(double dt) {
    for (var i = bolts.length - 1; i >= 0; i--) {
      if (i >= bolts.length) continue;
      final bo = bolts[i];
      if (bo.delay > 0) {
        bo.delay -= dt;
        continue;
      }
      bo.x += bo.v * dt;
      if (_monsterHurtable() && _inEllipse(bo.x + 8, bo.h, 8)) {
        bolts.removeAt(i);
        final hx = math.min(bo.x + 8, frontAt(bo.h) + 10);
        _hitMonster(
          kind: BrawlDamageSource.spell,
          base: bo.dmg,
          heavy: bo.big,
          stop: bo.big ? 0.09 : 0.06,
          x: hx,
          y: bo.h,
          big: bo.big,
          shake: bo.big ? 6 : 0,
          move: BrawlMove.spell,
        );
        if (bo.chain && _monsterHurtable()) {
          _pend.add(
            _Pending(0.15, () {
              _emit(
                BrawlEvent(
                  BrawlEventType.chainBolt,
                  x: m.x - m.rx * 0.2,
                  y: m.cy + 14,
                ),
              );
              _hitMonster(
                kind: BrawlDamageSource.spell,
                base: bo.dmg * 0.55,
                stop: 0.05,
                x: m.x - m.rx * 0.45,
                y: m.cy + 14,
                label: 'chain',
                move: BrawlMove.chain,
              );
            }),
          );
        }
      } else if (bo.x > w + 60) {
        bolts.removeAt(i);
      }
    }
  }

  // ---------------------------------------------------------------- fighter: Call a Friend

  void _startCall() {
    _bFriend = 0;
    _setState(BrawlFighterState.call);
    f.callDone = false;
    stats.calls++;
    cd.friend = lo.friend.cd;
    _setAnim(BrawlFighterAnim.call);
    _emit(BrawlEvent(BrawlEventType.call, x: f.x));
    _cue(BrawlCue.friend);
  }

  void _stCall(double dt) {
    f.st += dt;
    f.vx = _approach(f.vx, 0, BrawlTune.friction * dt);
    _integrate(dt);
    if (!f.callDone && f.st >= 0.12) {
      f.callDone = true;
      for (var i = 0; i < lo.friend.count; i++) {
        friends.add(
          BrawlFriend(
            index: i,
            x: math.max(-40.0, f.x - 230 - i * 40),
            t: -i * 0.55,
          ),
        );
      }
    }
    if (f.st >= 0.36) _setState(BrawlFighterState.free);
  }

  static const List<double> _friendHitTimes = [0.08, 0.34, 0.60];
  static const List<BrawlFighterAnim> _friendHitAnims = [
    BrawlFighterAnim.jab,
    BrawlFighterAnim.cross,
    BrawlFighterAnim.kick,
  ];

  void _updateFriends(double dt) {
    for (var i = friends.length - 1; i >= 0; i--) {
      if (i >= friends.length) continue;
      final fr = friends[i];
      fr.t += dt;
      fr.animT += dt;
      if (fr.state == BrawlFriendState.wait) {
        if (fr.t >= 0) {
          fr.state = BrawlFriendState.enter;
          fr.t = 0;
          _emit(
            BrawlEvent(BrawlEventType.friendEnter, x: fr.x, index: fr.index),
          );
        }
        continue;
      }
      final stand = frontAt(30) - 40 - fr.index * 30;
      if (fr.state == BrawlFriendState.enter) {
        fr.anim = BrawlFighterAnim.run;
        fr.x += 470 * dt;
        if (fr.x >= stand) {
          fr.x = stand;
          fr.state = BrawlFriendState.atk;
          fr.t = 0;
          fr.hits = 0;
          fr.anim = BrawlFighterAnim.jab;
          fr.animT = 0;
        }
      } else if (fr.state == BrawlFriendState.atk) {
        // Three hits at 0.08, 0.34, 0.60.
        final k = fr.hits;
        if (k < 3 && fr.t >= _friendHitTimes[k]) {
          fr.anim = _friendHitAnims[k];
          fr.animT = 0;
          _hitMonster(
            kind: BrawlDamageSource.friend,
            base: lo.friend.dmg * (k == 2 ? 1.8 : 1),
            heavy: k == 2,
            stop: k == 2 ? 0.07 : 0.045,
            x: math.min(fr.x + 36, frontAt(30) + 8),
            y: 36,
            move: BrawlMove.friend,
          );
          fr.hits++;
        }
        if (fr.t >= 0.95) {
          fr.state = BrawlFriendState.wave;
          fr.t = 0;
          fr.anim = BrawlFighterAnim.wave;
          fr.animT = 0;
        }
      } else if (fr.state == BrawlFriendState.wave) {
        if (fr.t >= 0.45) {
          fr.state = BrawlFriendState.exit;
          fr.t = 0;
          fr.anim = BrawlFighterAnim.runBack;
          fr.animT = 0;
          _emit(BrawlEvent(BrawlEventType.friendLeave, x: fr.x));
        }
      } else if (fr.state == BrawlFriendState.exit) {
        fr.x -= 460 * dt;
        if (fr.x < -50) friends.removeAt(i);
      }
    }
  }

  // ---------------------------------------------------------------- fighter: Super

  void _startSuper() {
    _bSup = 0;
    _setState(BrawlFighterState.superMove);
    stats.supers++;
    sup = 0;
    f.invuln = 99;
    cine = true;
    f.superI = 0;
    f.superStage = 0;
    f.vx = 0;
    f.superX = frontAt(40) - 46;
    f.superX0 = f.x;
    f.grounded = false;
    f.vh = 0;
    f.gscale = 0;
    _setAnim(BrawlFighterAnim.superWind);
    _emit(BrawlEvent(BrawlEventType.superStart, x: f.x));
    _cue(BrawlCue.superMove);
  }

  void _stSuper(double dt) {
    f.st += dt;
    const wind = 0.55;
    const interval = 0.085;
    final n = lo.dis.hits;
    final per = lo.dis.total * 0.7 / n;
    final blast = lo.dis.total * 0.3;
    if (f.st < wind) {
      // Gather: rise a little and slide in.
      final u = f.st / wind;
      final e = 1 - (1 - u) * (1 - u);
      f.x = _lerp(f.superX0, math.max(f.superX0, f.superX), e);
      f.h = 26 * math.sin(u * math.pi * 0.5);
      f.vh = 0;
      return;
    }
    f.h = 26;
    f.vh = 0;
    final tt = f.st - wind;
    _setAnim(
      tt < n * interval + 0.12
          ? BrawlFighterAnim.superFlurry
          : BrawlFighterAnim.superBlast,
    );
    while (f.superI < n && tt >= f.superI * interval) {
      _hitMonster(
        kind: BrawlDamageSource.superMove,
        base: per,
        stop: 0.035,
        noCrit: true,
        noMeter: true,
        x: frontAt(46) + 8 + _rand(-6, 6),
        y: 40 + _rand(-14, 20),
        move: BrawlMove.superFlurry,
        label: 'super',
      );
      _emit(
        BrawlEvent(
          BrawlEventType.superHit,
          index: f.superI,
          total: n,
          shake: 2.5,
        ),
      );
      f.superI++;
    }
    if (f.superStage == 0 && tt >= n * interval + 0.16) {
      f.superStage = 1;
      _hitMonster(
        kind: BrawlDamageSource.superMove,
        base: blast,
        heavy: true,
        stop: 0.16,
        noCrit: true,
        noMeter: true,
        x: frontAt(50) + 10,
        y: 56,
        shake: 12,
        big: true,
        move: BrawlMove.superBlast,
        label: 'super',
      );
      _emit(BrawlEvent(BrawlEventType.superBlast, x: f.x, shake: 13));
    }
    if (f.superStage == 1 && tt >= n * interval + 0.16 + 0.55) {
      f.superStage = 2;
      f.gscale = 1;
      f.grounded = false;
      f.vh = -100;
      f.vx = -60;
      cine = false;
      f.invuln = 0.6;
      _setState(BrawlFighterState.free);
      _emit(const BrawlEvent(BrawlEventType.superEnd));
    }
  }

  // ---------------------------------------------------------------- being bumped

  void _hurtPlayer(BrawlHazard src) {
    if (f.invuln > 0 ||
        f.state == BrawlFighterState.down ||
        f.state == BrawlFighterState.getup ||
        f.state == BrawlFighterState.hurt ||
        f.state == BrawlFighterState.finish) {
      return;
    }
    hitsTaken++;
    perfect = false;
    freeze = math.max(freeze, 0.07);
    combo.n = 0;
    combo.t = 0;
    combo.dmg = 0;
    _bAtk = 0;
    _bSpell = 0;
    _bFriend = 0;
    _bSup = 0;
    if (easy) {
      // A gentle bump.
      _setState(BrawlFighterState.hurt);
      f.vx = -150;
      f.vh = 170;
      f.grounded = false;
      f.gscale = 1;
      f.invuln = 1.1;
      _setAnim(BrawlFighterAnim.hurt);
      _emit(
        BrawlEvent(
          BrawlEventType.hurt,
          hazard: src,
          x: f.x,
          shake: 6,
          hitStop: 0.07,
        ),
      );
      return;
    }
    f.hp -= f.hpMax * BrawlTune.hurtDmg;
    knockdowns++;
    stats.getups++;
    _setState(BrawlFighterState.down);
    f.vx = -170;
    f.vh = 250;
    f.grounded = false;
    f.gscale = 1;
    f.lieT = 0;
    f.lieDur = BrawlTune.downLie * lo.vit.getupMult;
    f.caught = false;
    if (f.hp <= 0) {
      // Never down for the count: catch your breath, then back up.
      f.lieDur = 2.1;
      f.caught = true;
      f.hp = f.hpMax * 0.7;
      _emit(const BrawlEvent(BrawlEventType.catchBreath));
    }
    _setAnim(BrawlFighterAnim.down);
    _emit(
      BrawlEvent(
        BrawlEventType.hurt,
        hazard: src,
        knockedDown: true,
        x: f.x,
        shake: 6,
        hitStop: 0.07,
      ),
    );
  }

  void _stHurt(double dt) {
    f.st += dt;
    f.vx = _approach(f.vx, 0, 500 * dt);
    _integrate(dt);
    if (f.state == BrawlFighterState.hurt && f.st >= 0.38 && f.grounded) {
      _setState(BrawlFighterState.free);
    }
  }

  void _stDown(double dt) {
    f.st += dt;
    if (!f.grounded) {
      _integrate(dt);
      return;
    }
    f.vx = _approach(f.vx, 0, 900 * dt);
    _integrate(dt);
    f.lieT += dt;
    _setAnim(BrawlFighterAnim.down);
    if (f.lieT >= f.lieDur) {
      _setState(BrawlFighterState.getup);
      _setAnim(BrawlFighterAnim.getup);
      _emit(BrawlEvent(BrawlEventType.getup, x: f.x));
    }
  }

  void _stGetup(double dt) {
    f.st += dt;
    f.invuln = math.max(f.invuln, BrawlTune.getupInv);
    _integrate(dt);
    if (f.st >= BrawlTune.getupT) {
      _setState(BrawlFighterState.free);
      if (lo.vit.on) {
        f.hp = math.min(f.hpMax, f.hp + f.hpMax * 0.2);
        _emit(BrawlEvent(BrawlEventType.secondWind, x: f.x));
      }
    }
  }

  // ---------------------------------------------------------------- finisher

  void _startFinisher() {
    if (phase != BrawlPhase.daze) return;
    _bAtk = 0;
    _bFin = 0;
    phase = BrawlPhase.finisher;
    finishTime = t;
    fin = BrawlFinisher(
      kind: config.monster,
      dur: config.monster == BrawlMonster.troll ? 3.2 : 3.4,
    );
    _setState(BrawlFighterState.finish);
    f.invuln = 99;
    f.vx = 0;
    f.vh = 0;
    f.h = 0;
    f.grounded = true;
    f.gscale = 1;
    f.finX = frontAt(30) - 60;
    f.finX0 = f.x;
    cine = true;
    _emit(BrawlEvent(BrawlEventType.finishStart, monster: config.monster));
  }

  void _stFinisher(double dt) {
    final fn = fin!;
    fn.t += dt * timeScale;
    // Time map: ease into slow motion, hold, ease back out near the K.O.
    final tt = fn.t;
    if (tt < 0.25) {
      timeScale = _lerp(1, 0.4, tt / 0.25);
    } else if (tt < 2.0) {
      timeScale = 0.4;
    } else {
      timeScale = _lerp(0.4, 1, _clamp((tt - 2.0) / 0.5, 0, 1));
    }
    final fl = fn.flags;
    final u = _clamp(tt / 0.4, 0, 1);
    f.x = _lerp(f.finX0, f.finX, u * (2 - u));
    bool once(String key, bool cond) {
      if (cond && !fl.contains(key)) {
        fl.add(key);
        return true;
      }
      return false;
    }

    if (config.monster == BrawlMonster.troll) {
      _setAnim(
        tt < 0.4
            ? BrawlFighterAnim.run
            : tt < 1.2
            ? BrawlFighterAnim.finToss
            : tt < 2.1
            ? BrawlFighterAnim.pat
            : BrawlFighterAnim.victory,
      );
      if (once('a', tt >= 0.4)) {
        _emit(const BrawlEvent(BrawlEventType.finBlanket));
      }
      if (once('b', tt >= 1.2)) {
        _emit(const BrawlEvent(BrawlEventType.finTuck));
      }
      if (once('c', tt >= 1.6)) {
        m.hp = 0;
        _emit(const BrawlEvent(BrawlEventType.finSnore));
      }
      if (once('d', tt >= 2.05)) {
        _emit(const BrawlEvent(BrawlEventType.ko));
        _cue(BrawlCue.ko);
      }
    } else {
      _setAnim(
        tt < 0.45
            ? BrawlFighterAnim.run
            : tt < 0.9
            ? BrawlFighterAnim.inhale
            : tt < 1.9
            ? BrawlFighterAnim.blow
            : BrawlFighterAnim.victory,
      );
      if (once('a', tt >= 0.9)) {
        _emit(const BrawlEvent(BrawlEventType.finBlow));
      }
      if (once('b', tt >= 1.4)) {
        _emit(const BrawlEvent(BrawlEventType.finCloud));
      }
      if (once('c', tt >= 1.9)) {
        m.hp = 0;
        _emit(const BrawlEvent(BrawlEventType.finWater));
      }
      if (once('d', tt >= 2.25)) {
        _emit(const BrawlEvent(BrawlEventType.ko));
        _cue(BrawlCue.ko);
      }
    }
    if (fl.contains('d') &&
        perfect &&
        !fl.contains('p') &&
        tt >= (config.monster == BrawlMonster.troll ? 2.45 : 2.65)) {
      fl.add('p');
      _emit(const BrawlEvent(BrawlEventType.perfect));
      _cue(BrawlCue.perfect);
    }
    if (tt >= fn.dur) {
      phase = BrawlPhase.done;
      timeScale = 1;
      _emit(const BrawlEvent(BrawlEventType.victory));
    }
  }

  // ---------------------------------------------------------------- monster AI

  void _startTelegraph() {
    m.state = BrawlMonsterState.telegraph;
    m.st = 0;
    m.animT = 0;
    if (config.monster == BrawlMonster.troll) {
      m.teleDur = easy ? 1.8 : 1.25;
      _emit(
        BrawlEvent(
          BrawlEventType.telegraph,
          monster: BrawlMonster.troll,
          duration: m.teleDur,
        ),
      );
    } else {
      m.teleDur = easy ? 2.1 : 1.6;
      final n = easy ? 2 : 3;
      drops.clear();
      const loX = 40.0;
      final hiX = math.max(80.0, m.x - m.rx - 24);
      for (var i = 0; i < n; i++) {
        var x = i == 0 ? f.x + _rand(-26, 26) : f.x + _rand(-120, 120);
        x = _clamp(x, loX, hiX);
        drops.add(
          BrawlDrop(
            x: x,
            t: -(m.teleDur) + i * 0.16,
            fall: 0.3,
            r: easy ? 24 : 32,
          ),
        );
      }
      _emit(
        BrawlEvent(
          BrawlEventType.telegraph,
          monster: BrawlMonster.fog,
          duration: m.teleDur,
        ),
      );
    }
  }

  void _doStrike() {
    m.state = BrawlMonsterState.strike;
    m.st = 0;
    m.animT = 0;
    if (config.monster == BrawlMonster.troll) {
      m.strikeDur = 0.5;
      waves.add(
        BrawlWave(
          x: m.x - m.rx * 0.75,
          v: easy ? -105 : -150,
          w: easy ? 26 : 30,
          hgt: easy ? 18 : 32,
        ),
      );
      _emit(
        const BrawlEvent(
          BrawlEventType.strike,
          monster: BrawlMonster.troll,
          shake: 6,
        ),
      );
    } else {
      m.strikeDur = (drops.length - 1) * 0.16 + 0.3 + 0.4;
      _emit(const BrawlEvent(BrawlEventType.strike, monster: BrawlMonster.fog));
    }
  }

  void _updateMonster(double dt) {
    m.st += dt;
    m.animT += dt;
    if (config.monster == BrawlMonster.fog) {
      m.x = def.x0 + 40 * math.sin(clock * 0.55);
      m.bob = 7 * math.sin(clock * 1.3);
      m.cy = def.cy * m.scale + m.bob;
    }
    if (phase != BrawlPhase.fight || cine) return;
    if (m.state == BrawlMonsterState.idle) {
      if (!_busy()) m.moveT -= dt;
      if (m.moveT <= 0) _startTelegraph();
    } else if (m.state == BrawlMonsterState.telegraph) {
      if (m.st >= m.teleDur) _doStrike();
    } else if (m.state == BrawlMonsterState.strike) {
      if (m.st >= m.strikeDur) {
        m.state = BrawlMonsterState.recover;
        m.st = 0;
        m.animT = 0;
      }
    } else if (m.state == BrawlMonsterState.recover) {
      if (m.st >= 0.9) {
        m.state = BrawlMonsterState.idle;
        m.st = 0;
        m.animT = 0;
        m.moveT =
            _rand(BrawlTune.moveMin, BrawlTune.moveMax) * (easy ? 1.12 : 1);
      }
    }
  }

  void _updateWaves(double dt) {
    for (var i = waves.length - 1; i >= 0; i--) {
      if (i >= waves.length) continue;
      final wv = waves[i];
      wv.x += wv.v * dt;
      wv.age += dt;
      if (f.h < wv.hgt - 4 && (wv.x - f.x).abs() < wv.w * 0.5) {
        wv.hit = true;
        _hurtPlayer(BrawlHazard.wave);
      }
      // A wave that rolls under a jumping fighter is a small win.
      if (!wv.passed && wv.x < f.x - 4) {
        wv.passed = true;
        if (!wv.hit) _emit(BrawlEvent(BrawlEventType.dodge, x: f.x, y: f.h));
      }
      if (wv.x < -70) waves.removeAt(i);
    }
  }

  void _updateDrops(double dt) {
    for (var i = drops.length - 1; i >= 0; i--) {
      if (i >= drops.length) continue;
      final d = drops[i];
      d.t += dt;
      if (d.state == BrawlDropState.mark && d.t >= 0) {
        d.state = BrawlDropState.fall;
        d.t = 0;
        _emit(BrawlEvent(BrawlEventType.drop, x: d.x));
      } else if (d.state == BrawlDropState.fall && d.t >= d.fall) {
        d.state = BrawlDropState.splash;
        d.t = 0;
        _emit(BrawlEvent(BrawlEventType.splash, x: d.x));
        if (f.h < 26 && (f.x - d.x).abs() < d.r) {
          _hurtPlayer(BrawlHazard.drop);
        } else if ((f.x - d.x).abs() < d.r + 34 && _dodgeCool <= 0) {
          _dodgeCool = 1.2;
          _emit(BrawlEvent(BrawlEventType.dodge, x: f.x, y: f.h));
        }
      } else if (d.state == BrawlDropState.splash && d.t > 0.5) {
        drops.removeAt(i);
      }
    }
  }

  // ---------------------------------------------------------------- main step

  /// Moves the fight forward by [dt] seconds with [inp] as the player's
  /// hands. Call it with small slices (1/60 s is what it is tuned for; never
  /// more than 1/30 s at once). One-shot presses in [inp] are cleared as they
  /// are read.
  void step(double dt, BrawlInput inp) {
    _in = inp;
    clock += dt;
    if (phase == BrawlPhase.fight || phase == BrawlPhase.daze) t += dt;
    _consume(inp, dt);
    if (freeze > 0) {
      freeze -= dt;
      _tickBuffers(dt);
      return;
    }
    final sdt = dt;
    f.animT += sdt * (phase == BrawlPhase.finisher ? timeScale : 1);
    f.invuln = math.max(0.0, f.invuln - sdt);
    _dodgeCool = math.max(0.0, _dodgeCool - sdt);
    if (f.diveLock > 0) f.diveLock -= sdt;
    if (combo.t > 0) {
      combo.t -= sdt;
      if (combo.t <= 0) {
        combo.n = 0;
        combo.dmg = 0;
      }
    }
    if (f.chainT > 0 && f.state == BrawlFighterState.free) f.chainT -= sdt;

    if (phase == BrawlPhase.intro) {
      introT += sdt;
      _stFree(sdt);
      if (introT >= 1.25) {
        phase = BrawlPhase.fight;
        t = 0;
        _emit(const BrawlEvent(BrawlEventType.fightStart));
        _cue(BrawlCue.fight);
        _bAtk = 0;
        _bJump = 0;
      }
      _tickBuffers(dt);
      return;
    }
    if (phase == BrawlPhase.done) {
      _tickBuffers(dt);
      return;
    }

    if (phase == BrawlPhase.finisher) {
      _stFinisher(sdt);
      _updateMonster(sdt);
      _tickBuffers(dt);
      return;
    }

    // Cooldowns and regen (paused during a cinematic).
    if (!cine) {
      cd.spell = math.max(0.0, cd.spell - sdt);
      cd.friend = math.max(0.0, cd.friend - sdt);
      cd.slam = math.max(0.0, cd.slam - sdt);
      if (lo.vit.regen > 0 && f.state != BrawlFighterState.down) {
        f.hp = math.min(f.hpMax, f.hp + lo.vit.regen * sdt);
      }
    }
    if (phase == BrawlPhase.daze) {
      dazeT += sdt;
      final wait = easy ? BrawlTune.finishWaitEasy : BrawlTune.finishWaitStd;
      if (dazeT >= wait) _bFin = 0.2;
    }

    switch (f.state) {
      case BrawlFighterState.free:
        _stFree(sdt);
      case BrawlFighterState.attack:
        _stAttack(sdt);
      case BrawlFighterState.dive:
        _stDive(sdt);
      case BrawlFighterState.land:
        _stLand(sdt);
      case BrawlFighterState.charge:
        _stCharge(sdt);
      case BrawlFighterState.slam:
        _stSlam(sdt);
      case BrawlFighterState.cast:
        _stCast(sdt);
      case BrawlFighterState.call:
        _stCall(sdt);
      case BrawlFighterState.superMove:
        _stSuper(sdt);
      case BrawlFighterState.hurt:
        _stHurt(sdt);
      case BrawlFighterState.down:
        _stDown(sdt);
      case BrawlFighterState.getup:
        _stGetup(sdt);
      case BrawlFighterState.finish:
        _stFree(sdt);
    }
    if (phase == BrawlPhase.daze &&
        f.state == BrawlFighterState.free &&
        _bFin > 0) {
      _startFinisher();
    }

    if (!cine) {
      _updateMonster(sdt);
      _updateBolts(sdt);
      _updateFriends(sdt);
      _updateWaves(sdt);
      _updateDrops(sdt);
    } else {
      // During the super only the fighter acts; keep fog drift smooth.
      if (config.monster == BrawlMonster.fog) _updateMonster(0);
    }
    for (var i = _pend.length - 1; i >= 0; i--) {
      if (i >= _pend.length) continue;
      final p = _pend[i];
      p.t -= sdt;
      if (p.t <= 0) {
        _pend.removeAt(i);
        p.fn();
      }
    }
    _tickBuffers(dt);
  }

  /// Steps by a whole frame's worth of time in slices of at most [maxSlice]
  /// seconds (the prototype used 1/30), and returns the events that happened.
  List<BrawlEvent> advance(
    double frameDt,
    BrawlInput inp, {
    double maxSlice = 1 / 30,
  }) {
    var rem = frameDt;
    while (rem > 1e-6) {
      final h = math.min(rem, maxSlice);
      step(h, inp);
      rem -= h;
    }
    return drainEvents();
  }

  /// Exposed for tests: bump the fighter as the monster's move would.
  void debugHurt(BrawlHazard src) => _hurtPlayer(src);
}
