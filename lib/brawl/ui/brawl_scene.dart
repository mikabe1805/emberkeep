// The fight's picture: everything that is not the simulation.
//
// A [BrawlScene] holds a running [BrawlFight] and the visual state around it
// (the camera, the monster's springs, hit flashes, the combo counter, the
// announcer) and turns the fight's events into effects, sound and feel. Two
// painters draw it: [BrawlWorldPainter] (the stage, the characters and the
// effects) and [BrawlHudPainter] (the bars, the counter, the announcer and
// the controls). Both repaint straight from the scene, so a frame never
// rebuilds the widget tree.
//
// Ported from the prototype's main.js. Logical width is 393 and the height
// follows the screen; [BrawlLayout] says where things sit.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show CustomPainter;

import '../../tokens.dart' show Stat;
import '../brawl_abilities.dart' show lockedLine;
import '../core/brawl_core.dart';
import 'brawl_art.dart';
import 'brawl_feel.dart';
import 'brawl_fx.dart';
import 'brawl_stage.dart';

const double kBrawlW = 393;
const double _tau = math.pi * 2;

double _clamp(double v, double a, double b) => v < a ? a : (v > b ? b : v);
double _lerp(double a, double b, double t) => a + (b - a) * t;
double _easeOut(double u) => 1 - math.pow(1 - u, 3).toDouble();
double _easeBack(double u) {
  const c1 = 1.8, c3 = c1 + 1;
  return 1 + c3 * math.pow(u - 1, 3) + c1 * math.pow(u - 1, 2);
}

double _easeIo(double u) =>
    u < 0.5 ? 2 * u * u : 1 - math.pow(-2 * u + 2, 2) / 2;

Color _hex(int rgb, [double a = 1]) =>
    Color.fromRGBO((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255, a);

/// A touch target in the fight's logical pixels.
class BrawlCircle {
  const BrawlCircle(this.x, this.y, this.r);
  final double x;
  final double y;
  final double r;

  bool contains(double px, double py, [double pad = 0]) {
    final dx = px - x, dy = py - y, rr = r + pad;
    return dx * dx + dy * dy <= rr * rr;
  }
}

/// Where the screen puts things. Width is always [kBrawlW]; [h] is whatever
/// height the screen has at that width.
class BrawlLayout {
  BrawlLayout(Size size, {double top = 0, double bottom = 0})
    : scale = size.width / kBrawlW,
      h = size.height / (size.width / kBrawlW),
      hudTop = math.max(0.0, top / (size.width / kBrawlW) - 18),
      lift = math.max(0.0, bottom / (size.width / kBrawlW) - 12) {
    gy = _clamp((h * 0.575).roundToDouble(), 300, 520);
    final a = BrawlCircle(kBrawlW - 82, h - 120 - lift, 58);
    BrawlCircle at(double deg) => BrawlCircle(
      a.x + 108 * math.cos(deg * math.pi / 180),
      a.y - 108 * math.sin(deg * math.pi / 180),
      29,
    );
    attack = a;
    spell = at(164);
    friend = at(126);
    sup = at(88);
    pad = BrawlCircle(84, h - 124 - lift, 54);
    padZoneRight = 176;
    padZoneTop = h - 330 - lift;
    final ey = h - 90 - lift;
    eSpell = BrawlCircle(kBrawlW / 2 - 112, ey, 40);
    eFriend = BrawlCircle(kBrawlW / 2, ey, 40);
    eSup = BrawlCircle(kBrawlW / 2 + 112, ey, 40);
    eFinish = BrawlCircle(kBrawlW / 2, h - 205 - lift, 62);
  }

  /// Screen pixels per logical pixel.
  final double scale;
  final double h;

  /// How far the HUD sits down from the top (a notch pushes it).
  final double hudTop;

  /// How far the controls lift for a home indicator.
  final double lift;
  late final double gy;
  late final BrawlCircle attack, spell, friend, sup, pad;
  late final double padZoneRight, padZoneTop;
  late final BrawlCircle eSpell, eFriend, eSup, eFinish;
}

/// The touch layer's state, drawn by the HUD.
class BrawlTouchState {
  bool padOn = false;
  double padOx = 0, padOy = 0, padKx = 0, padKy = 0, padMove = 0;
  bool usedPad = false, usedAtk = false;
  final Map<String, double> press = {
    'attack': 0,
    'spell': 0,
    'friend': 0,
    'sup': 0,
    'tap': 0,
  };
  final List<List<double>> ripples = []; // x, y, t
}

/// What the controls offer at this moment, for the words a screen reader
/// reads over them.
@immutable
class BrawlControlsState {
  const BrawlControlsState({
    required this.spellOn,
    required this.spellReady,
    required this.friendOn,
    required this.friendReady,
    required this.supOn,
    required this.supReady,
    required this.supPercent,
    required this.slamOn,
    required this.slamReady,
    required this.daze,
    required this.easy,
    required this.over,
  });

  static const start = BrawlControlsState(
    spellOn: false,
    spellReady: false,
    friendOn: false,
    friendReady: false,
    supOn: false,
    supReady: false,
    supPercent: 0,
    slamOn: false,
    slamReady: false,
    daze: false,
    easy: false,
    over: false,
  );

  final bool spellOn, spellReady, friendOn, friendReady, supOn, supReady;
  final int supPercent;
  final bool slamOn, slamReady, daze, easy, over;

  @override
  bool operator ==(Object other) =>
      other is BrawlControlsState &&
      other.spellOn == spellOn &&
      other.spellReady == spellReady &&
      other.friendOn == friendOn &&
      other.friendReady == friendReady &&
      other.supOn == supOn &&
      other.supReady == supReady &&
      other.supPercent == supPercent &&
      other.slamOn == slamOn &&
      other.slamReady == slamReady &&
      other.daze == daze &&
      other.easy == easy &&
      other.over == over;

  @override
  int get hashCode => Object.hash(
    spellOn,
    spellReady,
    friendOn,
    friendReady,
    supOn,
    supReady,
    supPercent,
    slamOn,
    slamReady,
    daze,
    easy,
    over,
  );
}

class BrawlAnnounce {
  BrawlAnnounce(
    this.text,
    this.dur,
    this.size,
    this.hold,
    this.y,
    this.col,
    this.shake,
  );
  final String text;
  double dur;
  final double size;
  final bool hold;
  final double y;
  final int col;
  final double shake;
  double t = 0;
}

class BrawlCam {
  double x = 0, zoom = 1, zp = 0, fx = kBrawlW / 2, fy = 400, shake = 0, kx = 0;
}

class BrawlMonVis {
  RigActor? actor;
  double flash = 0, rx = 0, rv = 0, rr = 0, rrv = 0, sq = 0, sqv = 0, jx = 0;
  double surprise = 0;
}

/// The fight's picture and its feel.
class BrawlScene extends ChangeNotifier {
  BrawlScene({
    required this.core,
    required this.layout,
    required this.feel,
    this.reduceMotion = false,
    int visualSeed = 1,
    BrawlInput? input,
  }) : rnd = math.Random(visualSeed),
       inp = input ?? BrawlInput(),
       fx = BrawlFx(math.Random(visualSeed + 1)) {
    stage = BrawlStage(kBrawlW, layout.h, layout.gy);
    _newVisuals();
  }

  final BrawlFight core;
  final BrawlLayout layout;
  final BrawlFeel feel;
  final math.Random rnd;
  final BrawlFx fx;
  late final BrawlStage stage;

  /// Reduce Motion: no shake, softer flashes, a calmer camera.
  final bool reduceMotion;

  /// What the player is doing. A touch or keyboard layer writes it; the bot
  /// of a test may own it.
  final BrawlInput inp;

  /// Called at the start of every tick, before the fight steps (tests drive a
  /// bot from here).
  VoidCallback? beforeStep;
  final BrawlTouchState touch = BrawlTouchState();

  /// A short line the screen shows and speaks (Catch your breath...).
  final ValueNotifier<String?> toast = ValueNotifier(null);

  /// What the controls say and do right now. It changes only when a label
  /// would, so the semantics over the canvas do not rebuild every frame.
  final ValueNotifier<BrawlControlsState> controls = ValueNotifier(
    BrawlControlsState.start,
  );

  /// The announcer's current word, for a screen reader.
  final ValueNotifier<String> announcerText = ValueNotifier('');

  /// Both health bars in words, in steps of ten percent.
  final ValueNotifier<String> status = ValueNotifier('');

  /// Called once when the finisher is over and the victory should open.
  VoidCallback? onVictory;

  final BrawlCam cam = BrawlCam();
  final BrawlMonVis mon = BrawlMonVis();
  RigActor? fighter;
  final Map<int, RigActor> _friendActors = {};

  double t = 0;
  double dt = 1 / 60;
  bool paused = false;
  double _toastT = 0;
  double fFlash = 0, fsq = 0, fsqv = 0, blinkT = 2, blink = 0;
  BrawlAnnounce? ann;
  final List<BrawlAnnounce> _annQ = [];
  double comboShown = 0, comboPop = 0, comboFade = 0;
  double chip = 1, chipDelay = 0, hpShown = 1;
  double plantK = 0.55;
  double finCover = 0, finFogScale = 1, _finRain = 0;
  bool _finSparked = false;
  double hintT = 0, meterGlow = 0, danger = 0, superT = 0, flashScreen = 0;
  double _dustT = 0, _zzzT = 0, _victoryTimer = 0, chargeFlash = 0;
  bool _victorySent = false;
  bool _toldSoft = false;

  /// Frames painted since the scene began (tests read it).
  int frames = 0;

  bool get easy => core.easy;
  double get _calm => reduceMotion ? 0 : (easy ? 0.5 : 1);

  double get gy => layout.gy;

  // ---------------------------------------------------------------- the week's boost, made visible

  /// 0 for a quiet week up to 1 for a big one (the fight's aura).
  double get trainK => _clamp((core.lo.aura - 1) / 0.6, 0, 1);

  /// 0 to 1: how much this week boosted one stat's ability.
  double boostK(BrawlStat stat) =>
      _clamp(((core.lo.boost[stat] ?? 1) - 1) / 3, 0, 1);

  /// How strongly the damage [source] was trained this week.
  double _sourceK(BrawlDamageSource? source) => switch (source) {
    BrawlDamageSource.slam => boostK(BrawlStat.str),
    BrawlDamageSource.spell => boostK(BrawlStat.intl),
    BrawlDamageSource.friend => boostK(BrawlStat.soc),
    BrawlDamageSource.superMove => boostK(BrawlStat.dis),
    BrawlDamageSource.focus => boostK(BrawlStat.foc),
    _ => trainK * 0.6,
  };

  // ---------------------------------------------------------------- setup

  void _newVisuals() {
    final m = core.m;
    fx.reset();
    cam
      ..x = (core.f.x - 46 + m.x + m.def.vis + 14) / 2 - kBrawlW / 2
      ..zoom = 1
      ..zp = 0
      ..shake = 0
      ..kx = 0
      ..fx = kBrawlW / 2
      ..fy = gy - 14;
    mon.actor = RigActor(
      m.kind == BrawlMonster.troll ? rigTroll : rigFog,
      m.kind.key,
      m.kind == BrawlMonster.troll ? kTrollPalette : kFogPalette,
    );
    fighter = RigActor(rigFighter, 'fighter', kFighterPalette);
    plantK = 0.5;
  }

  // ---------------------------------------------------------------- input from the touch layer

  void pressAttack() {
    inp
      ..pAtk = true
      ..attackHeld = true;
    touch.press['attack'] = 1;
    touch.usedAtk = true;
  }

  void pressTap() {
    inp
      ..pAtk = true
      ..attackHeld = true;
    touch.press['tap'] = 1;
    touch.usedAtk = true;
  }

  void pressSpell() {
    inp.pSpell = true;
    touch.press['spell'] = 1;
  }

  void pressFriend() {
    inp.pFriend = true;
    touch.press['friend'] = 1;
  }

  void pressSuper() {
    inp.pSuper = true;
    touch.press['sup'] = 1;
  }

  void pressJump() {
    inp
      ..pJump = true
      ..jumpHeld = true;
  }

  void releaseAttack() => inp.attackHeld = false;

  void releaseAll() {
    inp.reset();
    touch.padOn = false;
    touch.padMove = 0;
  }

  // ---------------------------------------------------------------- announcer, toasts and small helpers

  void announce(
    String text, {
    double dur = 1,
    double size = 64,
    bool hold = false,
    double y = 0.33,
    int col = 0,
    double shake = 0,
  }) {
    _annQ.add(BrawlAnnounce(text, dur, size, hold, y, col, shake));
    announcerText.value = text;
  }

  void _toast(String text, [double secs = 2.2]) {
    toast.value = text;
    _toastT = secs;
  }

  void _dust(double x, int n, double power) {
    for (var i = 0; i < n; i++) {
      final d = (i.isOdd ? 1 : -1) * (0.4 + rnd.nextDouble() * 0.8);
      fx.part(
        FxKind.dust,
        x + d * 6,
        gy - 3,
        d * (50 + 100 * power) * (0.5 + rnd.nextDouble()),
        -(10 + rnd.nextDouble() * 30),
        0.36 + rnd.nextDouble() * 0.3,
        4 + rnd.nextDouble() * 4,
        _hex(0xEBD3AC),
        size1: 11 + power * 9,
        drag: 3,
        front: false,
      );
    }
    if (n >= 5) {
      fx.ring(
        x,
        gy + 3,
        4,
        22 + 26 * power,
        0.28,
        const Color.fromRGBO(240, 218, 176, 0.75),
        2.5,
        0.2,
      );
    }
  }

  void _sparks(
    double x,
    double y,
    int n,
    Color col,
    double speed, {
    double? dir,
    double cone = 2.2,
    bool star = false,
    double size = 2.2,
    double life = 0.2,
    double grav = 160,
  }) {
    for (var i = 0; i < n; i++) {
      final a = dir != null
          ? dir + (rnd.nextDouble() - 0.5) * cone
          : rnd.nextDouble() * _tau;
      final sp = speed * (0.5 + rnd.nextDouble() * 0.8);
      fx.part(
        star ? FxKind.star : FxKind.spark,
        x,
        y,
        math.cos(a) * sp,
        math.sin(a) * sp,
        0.22 + rnd.nextDouble() * life,
        size,
        col,
        drag: 4,
        grav: grav,
        add: true,
        rot: rnd.nextDouble() * 3,
        vr: 8,
      );
    }
  }

  // ---------------------------------------------------------------- events

  static Color _kcol(BrawlDamageSource? s) => switch (s) {
    BrawlDamageSource.slam => _hex(0xFFE0A0),
    BrawlDamageSource.spell => _hex(0xBFF3EE),
    BrawlDamageSource.friend => _hex(0xC7E8B8),
    BrawlDamageSource.superMove => _hex(0xFFC76A),
    _ => _hex(0xFFF4D9),
  };

  void _monsterHurtFx(BrawlEvent e) {
    final M = mon;
    M.flash = 1;
    M.surprise = 0.5;
    M.rv +=
        (e.heavy ? 150 : 60) *
        (core.m.kind == BrawlMonster.fog && e.resist ? 0.5 : 1);
    M.rrv +=
        (e.heavy ? 1.6 : 0.5) * (core.m.kind == BrawlMonster.troll ? 1 : 0.4);
    M.sqv += (e.heavy ? 7 : 3) * (e.resist ? 0.4 : 1);
    cam.kx += (e.heavy ? 5 : 2.2) * (reduceMotion ? 0.3 : 1);
    cam.zp = math.max(
      cam.zp,
      (e.heavy ? 0.04 : 0.012) * (reduceMotion ? 0.3 : 1),
    );
    if (e.shake > 0) cam.shake = math.max(cam.shake, e.shake);
  }

  void _fxHit(BrawlEvent e) {
    final x = e.x, y = gy - e.y, m = core.m;
    _monsterHurtFx(e);
    final col = _kcol(e.source);
    final sk = _sourceK(e.source);
    final soft = e.resist && m.kind == BrawlMonster.fog;
    if (soft) {
      // Fists sink into the cloud: soft puffs, no hard sparks.
      for (var k = 0; k < 6; k++) {
        fx.part(
          FxKind.puff,
          x + (rnd.nextDouble() - 0.5) * 10,
          y + (rnd.nextDouble() - 0.5) * 10,
          20 + rnd.nextDouble() * 40,
          (rnd.nextDouble() - 0.5) * 50,
          0.45,
          5,
          _hex(0xE6EEF5),
          size1: 14,
          drag: 3,
          a: 0.8,
        );
      }
      fx.ring(
        x,
        y,
        3,
        22,
        0.28,
        const Color.fromRGBO(230, 238, 245, 0.8),
        2,
        1,
      );
    } else {
      fx.smear(
        Smear.burst(
          x: x,
          y: y,
          r: (e.heavy ? 34 : 22) * (1 + 0.35 * sk),
          rot: rnd.nextDouble() * 3,
          life: e.heavy ? 0.17 : 0.11,
          big: e.heavy,
        ),
      );
      _sparks(
        x,
        y,
        ((e.heavy ? 12 : 7) * (1 + 0.8 * sk)).round(),
        col,
        e.heavy ? 280 : 190,
        dir: math.pi + 0.15,
        cone: 3.0,
      );
      if (e.heavy) {
        fx.ring(
          x,
          y,
          6,
          52 * (1 + 0.3 * sk),
          0.26,
          const Color.fromRGBO(255, 255, 255, 0.8),
          3,
          1,
        );
      }
    }
    if (e.crit > 0) {
      final gold = core.lo.focus.gold;
      final fk = boostK(BrawlStat.foc);
      final n = (e.crit == 2 ? 24 : (gold ? 19 : 13)) * (1 + 0.9 * fk);
      _sparks(
        x,
        y,
        n.round(),
        _hex(0xFFD25A),
        330,
        star: true,
        size: (gold ? 5 : 4) * (1 + 0.3 * fk),
        life: 0.32,
        grav: 120,
      );
      fx.ring(
        x,
        y,
        4,
        (gold ? 58 : 46) * (1 + 0.4 * fk),
        0.3,
        const Color.fromRGBO(255, 210, 90, 0.95),
        3.5,
        1,
      );
      if (gold) {
        fx.ring(
          x,
          y,
          2,
          30,
          0.22,
          const Color.fromRGBO(255, 248, 200, 0.9),
          2.5,
          1,
        );
      }
    }
    if (e.weak) {
      fx.ring(
        x,
        y,
        5,
        34,
        0.26,
        const Color.fromRGBO(255, 170, 150, 0.9),
        2.5,
        1,
      );
    }
    // A super's flurry shows every other hit, small, so the blast number can
    // be the big one.
    final isSuper = e.source == BrawlDamageSource.superMove;
    final quiet = isSuper && !e.heavy && e.combo.isOdd;
    final base = isSuper
        ? (e.heavy ? 40.0 : 17.0)
        : e.crit == 2
        ? 38.0
        : e.crit > 0
        ? 31.0
        : e.heavy
        ? 27.0
        : 20.0;
    final sz = base * (1 + 0.3 * sk);
    final tint = e.crit > 0
        ? _hex(0xFFD25A)
        : e.resist
        ? _hex(0xC4D0DC)
        : _kcol(e.source) == _hex(0xFFF4D9)
        ? _hex(0xFFF4D9)
        : _kcol(e.source);
    if (!quiet) {
      fx.num(
        x - 8 + (rnd.nextDouble() - 0.5) * (isSuper ? 60 : 22),
        y - (isSuper && !e.heavy ? 14 + rnd.nextDouble() * 40 : 22),
        '${e.damage}',
        size: e.resist ? sz * 0.82 : sz,
        col: tint,
        crit: e.crit > 0,
        tag: e.crit == 2
            ? 'DOUBLE CRIT'
            : e.crit > 0
            ? 'CRIT'
            : (e.weak && e.heavy ? 'WEAK' : ''),
        pop: e.crit > 0 ? 1.9 : 1.5,
        life: e.crit > 0 ? 1.0 : 0.8,
      );
    }
    comboPop = 1;
    comboShown = e.combo.toDouble();
    comboFade = 0;
    if (e.crit == 2) {
      feel.play(BrawlSound.doubleCrit);
      feel.play(BrawlSound.hit, k: e.combo);
    } else if (e.crit > 0) {
      feel.play(BrawlSound.crit, k: e.combo);
      feel.play(BrawlSound.hit, k: e.combo);
    } else if (e.source == BrawlDamageSource.spell) {
      feel.play(BrawlSound.spellHit);
    } else if (soft) {
      feel.play(BrawlSound.soft);
    } else if (e.heavy) {
      feel.play(BrawlSound.heavy);
    } else {
      feel.play(BrawlSound.hit, k: math.min(10, e.combo));
    }
    if (e.source == BrawlDamageSource.friend) feel.play(BrawlSound.friendHit);
    if (soft && !_toldSoft) {
      _toldSoft = true;
      _toast('Fists only half land on a cloud. Try Spell Bolt!', 2.8);
    }
  }

  void _handleEvents(List<BrawlEvent> evs) {
    final f = core.f, m = core.m;
    for (final e in evs) {
      switch (e.type) {
        case BrawlEventType.announce:
          switch (e.cue) {
            case BrawlCue.round1:
              announce('ROUND 1', dur: 1.2, size: 66);
              feel.play(BrawlSound.round);
            case BrawlCue.fight:
              announce(
                'FIGHT!',
                dur: 0.95,
                size: 74,
                shake: reduceMotion ? 0 : 1,
              );
              feel.play(BrawlSound.fight);
              hintT = 0;
            case BrawlCue.friend:
              announce('FRIEND!', dur: 0.7, size: 40, y: 0.46);
              feel.play(BrawlSound.call);
            case BrawlCue.superMove:
              superT = 0;
              flashScreen = 0.5;
              announce('SUPER!', dur: 0.9, size: 70, y: 0.3, col: 1);
              feel.play(BrawlSound.superCharge);
            case BrawlCue.finishIt:
              announce(
                'FINISH IT!',
                dur: 99,
                size: 62,
                hold: true,
                y: 0.3,
                col: 2,
              );
              flashScreen = 0.35;
              feel.play(BrawlSound.finishIt);
            case BrawlCue.ko:
              announce(
                'K.O.',
                dur: 1.9,
                size: 92,
                y: 0.3,
                shake: reduceMotion ? 0 : 2,
              );
              feel.play(BrawlSound.ko);
              for (var i = 1; i <= 3; i++) {
                _timed.add((t + 0.14 * i, BrawlSound.koRise, i));
              }
              flashScreen = 0.8;
            case BrawlCue.perfect:
              announce('PERFECT', dur: 1.6, size: 56, y: 0.43, col: 1);
              feel.play(BrawlSound.perfect);
            case null:
              break;
          }
        case BrawlEventType.fightStart:
          break;
        case BrawlEventType.jump:
          _dust(e.x, e.air ? 0 : 4, 0.3);
          if (e.air) {
            fx.ring(
              e.x,
              gy - f.h - 6,
              4,
              22,
              0.25,
              const Color.fromRGBO(255, 244, 217, 0.8),
              2,
              0.35,
            );
          }
          fsqv += -5;
          feel.play(e.air ? BrawlSound.airJump : BrawlSound.jump);
        case BrawlEventType.land:
          _dust(e.x, e.power > 500 ? 9 : 5, _clamp(e.power / 800, 0.15, 1));
          fsqv += 6 * _clamp(e.power / 700, 0.2, 1);
          feel.play(BrawlSound.land, power: e.power);
        case BrawlEventType.swing:
          final x = f.x, y = gy - f.h;
          switch (e.move) {
            case BrawlMove.jab:
              fx.smear(
                Smear.streak(
                  x: x + 12,
                  y: y - 38,
                  ang: -0.05,
                  len: 54,
                  w: 8,
                  off: 4,
                  delay: 0.02,
                  life: 0.13,
                ),
              );
            case BrawlMove.cross:
              fx.smear(
                Smear.streak(
                  x: x + 10,
                  y: y - 35,
                  ang: 0.07,
                  len: 58,
                  w: 9,
                  off: 4,
                  delay: 0.02,
                  life: 0.14,
                ),
              );
            case BrawlMove.kick:
              fx.smear(
                Smear.arc(
                  x: x + 6,
                  y: y - 24,
                  r: 40,
                  a0: 0.75,
                  a1: -0.95,
                  w: 16,
                  delay: 0.03,
                  life: 0.17,
                ),
              );
            default:
              fx.smear(
                Smear.arc(
                  x: x + 20,
                  y: y - 20,
                  r: 36,
                  a0: 1.05,
                  a1: -1.95,
                  w: 20,
                  delay: 0.035,
                  life: 0.2,
                ),
              );
          }
          feel.play(BrawlSound.swing);
        case BrawlEventType.whiff:
          break;
        case BrawlEventType.hit:
          _fxHit(e);
        case BrawlEventType.dive:
          for (var k = 0; k < 4; k++) {
            fx.smear(
              Smear.speed(
                x: f.x - 6 - k * 5,
                y: gy - f.h - 44 + k * 9,
                dx: -34,
                dy: -30,
                w: 3,
                life: 0.2,
                delay: k * 0.01,
                a: 0.7,
              ),
            );
          }
          feel.play(BrawlSound.swing);
        case BrawlEventType.bounce:
          fx.ring(
            f.x + 16,
            gy - f.h,
            4,
            30,
            0.22,
            const Color.fromRGBO(255, 230, 170, 0.9),
            3,
            0.7,
          );
        case BrawlEventType.slamCharge:
          feel.play(BrawlSound.charge);
        case BrawlEventType.slamReady:
          chargeFlash = 1;
          feel.play(BrawlSound.ready);
          fx.ring(
            f.x,
            gy - f.h - 28,
            10,
            44,
            0.3,
            const Color.fromRGBO(255, 224, 150, 0.95),
            3,
            1,
          );
        case BrawlEventType.slam:
          fx.smear(
            Smear.arc(
              x: f.x + 14,
              y: gy - f.h - 50,
              r: 50,
              a0: -2.5,
              a1: -0.4,
              w: 24,
              delay: 0.1,
              life: 0.2,
            ),
          );
          feel.play(BrawlSound.slam);
        case BrawlEventType.slamImpact:
          final sk = boostK(BrawlStat.str);
          _dust(e.x + 20, 12 + (sk * 6).round(), 1);
          fx.ring(
            e.x + 30,
            gy + 4,
            6,
            92 * (1 + 0.5 * sk),
            0.38,
            const Color.fromRGBO(255, 226, 160, 0.9),
            5,
            0.2,
          );
          fx.ring(
            e.x + 30,
            gy + 4,
            4,
            58 * (1 + 0.5 * sk),
            0.3,
            const Color.fromRGBO(255, 255, 255, 0.8),
            3,
            0.2,
          );
          for (var k = 0; k < 5 + (sk * 6).round(); k++) {
            fx.part(
              FxKind.spark,
              e.x + 30 + (k - 2) * 8,
              gy.toDouble(),
              (k - 2) * 50,
              -40 - rnd.nextDouble() * 90,
              0.4,
              3,
              _hex(0xFFE0A0),
              grav: 380,
              add: true,
              drag: 1.5,
            );
          }
          cam.shake = math.max(cam.shake, e.hitMonster ? 9 : 5);
          cam.zp = math.max(cam.zp, 0.04 * (reduceMotion ? 0.3 : 1));
          fsqv += 9;
          feel.play(BrawlSound.heavy);
        case BrawlEventType.groundWave:
          fx.ring(
            e.x,
            gy + 3,
            6,
            150,
            0.45,
            const Color.fromRGBO(255, 226, 160, 0.8),
            4,
            0.12,
          );
          fx.smear(
            Smear.streak(
              x: e.x,
              y: gy - 6,
              len: 150,
              w: 10,
              off: 10,
              life: 0.3,
              a: 0.6,
            ),
          );
        case BrawlEventType.cast:
          fsqv += -2;
          feel.play(BrawlSound.cast);
        case BrawlEventType.bolt:
          final p = fighter!.pt('foreF', 0, 9);
          final ik = boostK(BrawlStat.intl);
          _sparks(
            p.dx + cam.x,
            p.dy,
            8 + (ik * 8).round(),
            _hex(0xBFF3EE),
            150,
            dir: 0,
            cone: 1.4,
            star: true,
          );
          fx.ring(
            p.dx + cam.x,
            p.dy,
            4,
            24 * (1 + 0.5 * ik),
            0.22,
            const Color.fromRGBO(191, 243, 238, 0.9),
            2.5,
            1,
          );
        case BrawlEventType.chainBolt:
          fx.arc(
            m.x - m.rx * 0.5,
            gy - m.cy + 10,
            m.x - m.rx * 0.2,
            gy - m.cy - 8,
          );
        case BrawlEventType.call:
          break;
        case BrawlEventType.friendEnter:
          _dust(e.x, 4, 0.4);
        case BrawlEventType.friendLeave:
          break;
        case BrawlEventType.superStart:
          break;
        case BrawlEventType.superHit:
          cam.shake = math.max(cam.shake, 2.5);
          feel.play(BrawlSound.superHit, index: e.index);
        case BrawlEventType.superBlast:
          final dk = boostK(BrawlStat.dis);
          flashScreen = 0.6;
          cam.shake = 13;
          fx.ring(
            m.x,
            gy - m.cy,
            8,
            130 * (1 + 0.4 * dk),
            0.5,
            const Color.fromRGBO(255, 230, 160, 0.95),
            6,
            1,
          );
          fx.ring(
            m.x,
            gy - m.cy,
            4,
            90 * (1 + 0.4 * dk),
            0.4,
            const Color.fromRGBO(255, 255, 255, 0.9),
            3,
            1,
          );
          _sparks(
            m.x - 20,
            gy - m.cy,
            30 + (dk * 18).round(),
            _hex(0xFFE0A0),
            360,
            star: true,
            size: 3.4,
            life: 0.4,
          );
          feel.play(BrawlSound.superBlast);
        case BrawlEventType.superEnd:
          break;
        case BrawlEventType.meterFull:
          meterGlow = 1;
          feel.play(BrawlSound.meter);
        case BrawlEventType.telegraph:
          danger = 1;
          feel.play(
            m.kind == BrawlMonster.troll
                ? BrawlSound.telegraph
                : BrawlSound.teleFog,
          );
        case BrawlEventType.strike:
          if (m.kind == BrawlMonster.troll) {
            _dust(m.x - m.rx - 20, 10, 1);
            cam.shake = math.max(cam.shake, 6);
            fx.ring(
              m.x - m.rx - 6,
              gy + 4,
              6,
              70,
              0.35,
              const Color.fromRGBO(255, 200, 140, 0.8),
              4,
              0.2,
            );
            feel.play(BrawlSound.wave);
          }
        case BrawlEventType.drop:
          feel.play(BrawlSound.drop);
        case BrawlEventType.splash:
          for (var k = 0; k < 9; k++) {
            fx.part(
              FxKind.drop,
              e.x + (rnd.nextDouble() - 0.5) * 8,
              gy - 2,
              (rnd.nextDouble() - 0.5) * 140,
              -90 - rnd.nextDouble() * 90,
              0.45,
              2.4,
              _hex(0xBFE0F4),
              grav: 520,
            );
          }
          fx.ring(
            e.x,
            gy + 3,
            4,
            34,
            0.35,
            const Color.fromRGBO(190, 224, 244, 0.9),
            3,
            0.28,
          );
          feel.play(BrawlSound.splash);
        case BrawlEventType.dodge:
          fx.part(
            FxKind.text,
            f.x,
            gy - f.h - 96,
            0,
            -34,
            0.95,
            18,
            _hex(0xFFE3A0),
            size1: 24,
            text: 'Nice!',
          );
          _sparks(
            f.x,
            gy - f.h - 40,
            8,
            _hex(0xFFE8A8),
            140,
            star: true,
            size: 3,
            life: 0.4,
            grav: -30,
          );
          feel.play(BrawlSound.dodge);
        case BrawlEventType.hurt:
          fFlash = 1;
          cam.shake = math.max(cam.shake, 6);
          _sparks(f.x, gy - f.h - 30, 8, _hex(0xFFF4D9), 160, star: true);
          for (var k = 0; k < 3; k++) {
            fx.part(
              FxKind.star,
              f.x + (k - 1) * 12,
              gy - f.h - 70,
              (k - 1) * 30.0,
              -50,
              0.7,
              5,
              _hex(0xFFE8A8),
              vr: 5,
              add: true,
            );
          }
          feel.play(BrawlSound.hurt);
        case BrawlEventType.catchBreath:
          _toast('Catch your breath. Take your time.', 2.6);
        case BrawlEventType.getup:
          _dust(e.x, 5, 0.4);
          feel.play(BrawlSound.getup);
        case BrawlEventType.secondWind:
          for (var k = 0; k < 7; k++) {
            fx.part(
              FxKind.plus,
              f.x + (rnd.nextDouble() - 0.5) * 26,
              gy - f.h - 10 - rnd.nextDouble() * 30,
              0,
              -34 - rnd.nextDouble() * 20,
              0.9,
              3.2,
              _hex(0xA8D49A),
              add: true,
            );
          }
          fx.part(
            FxKind.text,
            f.x,
            gy - f.h - 82,
            0,
            -22,
            1.0,
            17,
            _hex(0xCFEAB8),
            size1: 17,
            text: 'Second Wind',
          );
          feel.play(BrawlSound.wind);
        case BrawlEventType.locked:
          feel.play(BrawlSound.locked);
          final stat = e.stat;
          if (stat != null) {
            _toast(lockedLine(Stat.values.byName(stat.name)), 2.0);
          }
        case BrawlEventType.daze:
          break;
        case BrawlEventType.finishStart:
          _annQ.clear();
          final a = ann;
          if (a != null && a.hold) a.dur = 0.01;
        case BrawlEventType.finBlanket:
          feel.play(BrawlSound.finToss);
        case BrawlEventType.finTuck:
          _sparks(
            m.x,
            gy - 70,
            14,
            _hex(0xFFE8A8),
            120,
            star: true,
            size: 3,
            life: 0.5,
            grav: -20,
          );
          feel.play(BrawlSound.tuck);
          mon.sqv += 3;
        case BrawlEventType.finSnore:
          feel.play(BrawlSound.lullaby);
        case BrawlEventType.finBlow:
          feel.play(BrawlSound.blow);
          for (var k = 0; k < 10; k++) {
            fx.smear(
              Smear.speed(
                x: f.x + 18 + k * 12,
                y: gy - 44 - (k % 4) * 8,
                dx: -26,
                dy: 0,
                w: 2.4,
                life: 0.3,
                delay: k * 0.03,
                a: 0.5,
              ),
            );
          }
        case BrawlEventType.finCloud:
          break;
        case BrawlEventType.finWater:
          feel.play(BrawlSound.cloudWater);
          _bloomIn = 0.45;
        case BrawlEventType.ko:
          break;
        case BrawlEventType.perfect:
          break;
        case BrawlEventType.victory:
          _victoryTimer = 0.9;
      }
    }
  }

  double _bloomIn = -1;

  /// Sounds that come a little after the event that asked for them, by the
  /// scene's own clock (so a paused or disposed fight never makes a late one).
  final List<(double, BrawlSound, int)> _timed = [];

  // ---------------------------------------------------------------- the frame

  /// Advances the fight and the picture by [frameDt] seconds.
  void tick(double frameDt, {double keyMove = 0}) {
    if (paused) return;
    dt = frameDt;
    beforeStep?.call();
    final move = touch.padMove != 0 ? touch.padMove : keyMove;
    inp.moveX = move;
    final events = core.advance(frameDt, inp);
    _handleEvents(events);
    _updateVisuals(frameDt);
    if (_bloomIn >= 0) {
      _bloomIn -= frameDt;
      if (_bloomIn < 0) feel.play(BrawlSound.bloom);
    }
    notifyListeners();
  }

  void _updateVisuals(double dt) {
    final f = core.f, m = core.m, M = mon;
    final frozen = core.freeze > 0;
    final sc = core.timeScale;
    final fdt = dt * sc * (frozen ? 0.1 : 1);
    t += dt;
    // Fighting-game camera: wide while the fighter is far away, closing in as
    // he approaches, never losing either of them.
    final vis = m.def.vis;
    final left = f.x - 46, right = m.x + vis + 14;
    var zt = _clamp(kBrawlW / (right - left + 36), 1.0, 1.3);
    var tx = (left + right) / 2 - kBrawlW / 2;
    final fy = gy - 14;
    final big = reduceMotion ? 0.3 : 1.0;
    if (core.phase == BrawlPhase.finisher) {
      final F = core.fin!;
      if (m.kind == BrawlMonster.fog && F.t > 1.0) {
        zt = 1 + 0.34 * big;
        tx = 212 - kBrawlW / 2 + 70;
      } else {
        zt = 1 + 0.52 * big;
      }
    } else if (core.phase == BrawlPhase.daze) {
      zt = math.max(zt, 1 + 0.3 * big);
    } else if (f.state == BrawlFighterState.superMove) {
      zt = 1 + 0.42 * big;
      tx = (f.x + m.x) / 2 - kBrawlW / 2 - 10;
    }
    cam.x += (tx - cam.x) * math.min(1.0, dt * 5);
    cam.zoom +=
        (zt - cam.zoom) * math.min(1.0, dt * (zt > cam.zoom ? 4.5 : 3.2));
    cam.fx += (kBrawlW / 2 - cam.fx) * math.min(1.0, dt * 6);
    cam.fy += (fy - cam.fy) * math.min(1.0, dt * 6);
    cam.zp *= math.exp(-dt * 11);
    cam.shake *= math.exp(-dt * 9);
    cam.kx *= math.exp(-dt * 16);
    if (cam.shake < 0.05) cam.shake = 0;
    // Monster springs.
    M.flash = math.max(0.0, M.flash - dt * 9);
    const k = 190.0, d = 13.0;
    M.rv += (-k * M.rx - d * M.rv) * dt;
    M.rx += M.rv * dt * 0.1;
    M.rrv += (-120 * M.rr - 10 * M.rrv) * dt;
    M.rr += M.rrv * dt;
    M.sqv += (-160 * M.sq - 11 * M.sqv) * dt;
    M.sq += M.sqv * dt;
    M.jx = frozen && !reduceMotion ? (rnd.nextDouble() - 0.5) * 3 : 0;
    M.surprise = math.max(0.0, M.surprise - dt);
    // Fighter springs and flash.
    fFlash = math.max(0.0, fFlash - dt * 6);
    fsqv += (-190 * fsq - 14 * fsqv) * dt;
    fsq += fsqv * dt * 0.1;
    blinkT -= dt;
    if (blinkT <= 0) {
      blink = 0.12;
      blinkT = 2.2 + rnd.nextDouble() * 2.5;
    }
    blink = math.max(0.0, blink - dt);
    chargeFlash = math.max(0.0, chargeFlash - dt * 4);
    flashScreen = math.max(0.0, flashScreen - dt * 3);
    meterGlow = math.max(0.0, meterGlow - dt * 1.4);
    if (f.state == BrawlFighterState.superMove) {
      superT += dt;
    } else {
      superT = math.max(0.0, superT - dt * 3);
    }
    // Running dust.
    if (f.grounded && f.vx.abs() > 90 && f.state == BrawlFighterState.free) {
      _dustT -= dt;
      if (_dustT <= 0) {
        _dustT = 0.11;
        fx.part(
          FxKind.dust,
          f.x - f.vx.sign * 8,
          gy - 2,
          -f.vx.sign * 24,
          -10,
          0.3,
          2.5,
          _hex(0xD8BC94),
          size1: 6,
          drag: 2,
          front: false,
          a: 0.7,
        );
      }
    }
    // Health: an instant bar and a chip that lags behind it.
    final frac = m.hp / m.hpMax;
    if (frac < hpShown) chipDelay = 0.5;
    hpShown = frac;
    if (chip < frac) chip = frac;
    if (chipDelay > 0) {
      chipDelay -= dt;
    } else if (chip > frac) {
      chip = math.max(frac, chip - math.max(0.15, (chip - frac) * 3.2) * dt);
    }
    // The combo counter fades once the core resets it.
    final cb = core.combo;
    if (cb.n >= 2) {
      comboShown = cb.n.toDouble();
      comboFade = 0;
    } else if (comboShown >= 2) {
      comboFade += dt;
      if (comboFade > 0.9) comboShown = 0;
    }
    comboPop = math.max(0.0, comboPop - dt * 6);
    if (ann == null && _annQ.isNotEmpty) ann = _annQ.removeAt(0);
    final a = ann;
    if (a != null) {
      a.t += dt;
      if (a.t >= a.dur) ann = null;
    }
    if (m.state == BrawlMonsterState.telegraph ||
        m.state == BrawlMonsterState.strike) {
      danger = 1;
    } else {
      danger = math.max(0.0, danger - dt * 2);
    }
    // Sleepy z's while the Troll naps.
    if (m.kind == BrawlMonster.troll &&
        core.phase == BrawlPhase.finisher &&
        core.fin!.t > 1.6) {
      _zzzT -= dt;
      if (_zzzT <= 0) {
        _zzzT = 0.7;
        fx.part(
          FxKind.text,
          m.x + 6,
          gy - 118,
          12,
          -24,
          1.7,
          15,
          _hex(0xF3E6C8),
          size1: 28,
          a: 0.95,
          text: 'z',
        );
      }
    }
    if (core.phase == BrawlPhase.finisher) {
      final F = core.fin!;
      if (m.kind == BrawlMonster.troll) {
        finCover = _clamp((F.t - 1.2) / 0.55, 0, 1);
      } else {
        finFogScale = F.t < 0.9
            ? 1
            : _lerp(1, 0.34, _easeOut(_clamp((F.t - 0.9) / 0.5, 0, 1)));
        if (F.t > 1.4 && F.t < 2.3) {
          _finRain += dt;
          if (_finRain > 0.045) {
            _finRain = 0;
            fx.part(
              FxKind.drop,
              212 - 12 + rnd.nextDouble() * 24,
              gy - 118,
              0,
              40,
              0.55,
              2.2,
              _hex(0xBFE0F4),
              grav: 700,
            );
          }
        }
        plantK = F.t < 1.9
            ? 0.5
            : _lerp(0.5, 1, _easeOut(_clamp((F.t - 1.9) / 0.7, 0, 1)));
        if (F.t > 2.0 && !_finSparked) {
          _finSparked = true;
          _sparks(
            212,
            gy - 80,
            18,
            _hex(0xFFE8A8),
            120,
            star: true,
            size: 3,
            life: 0.6,
            grav: -30,
          );
        }
      }
    }
    if (core.phase == BrawlPhase.done && !_victorySent) {
      _victoryTimer -= dt;
      if (_victoryTimer <= 0) {
        _victorySent = true;
        onVictory?.call();
      }
    }
    fx.update(fdt);
    for (var i = _timed.length - 1; i >= 0; i--) {
      if (t >= _timed[i].$1) {
        final due = _timed.removeAt(i);
        feel.play(due.$2, index: due.$3);
      }
    }
    for (var i = touch.ripples.length - 1; i >= 0; i--) {
      touch.ripples[i][2] += dt;
      if (touch.ripples[i][2] > 0.5) touch.ripples.removeAt(i);
    }
    for (final key in touch.press.keys.toList()) {
      touch.press[key] = math.max(0.0, touch.press[key]! - dt * 7);
    }
    if (core.phase == BrawlPhase.fight || core.phase == BrawlPhase.daze) {
      hintT += dt;
    }
    if (_toastT > 0) {
      _toastT -= dt;
      if (_toastT <= 0) toast.value = null;
    }
    _syncControls();
  }

  void _syncControls() {
    final lo = core.lo;
    final next = BrawlControlsState(
      spellOn: lo.spell.on,
      spellReady: core.spellReady,
      friendOn: lo.friend.on,
      friendReady: core.friendReady,
      supOn: lo.dis.on,
      supReady: core.superReady,
      supPercent: (core.sup / 10).floor() * 10,
      slamOn: lo.slam.on,
      slamReady: core.slamReady,
      daze: core.phase == BrawlPhase.daze,
      easy: easy,
      over: core.phase == BrawlPhase.finisher || core.phase == BrawlPhase.done,
    );
    if (next != controls.value) controls.value = next;
    final hp = ((core.m.hp / core.m.hpMax) * 10).ceil() * 10;
    final me = ((core.f.hp / core.f.hpMax) * 10).ceil() * 10;
    final line =
        '${core.m.def.name} health $hp percent. Your health $me percent.';
    if (line != status.value) status.value = line;
  }

  @override
  void dispose() {
    toast.dispose();
    controls.dispose();
    announcerText.dispose();
    status.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- drawing: the world

  final BrawlPen _pen = BrawlPen();
  final Paint _p = Paint()..isAntiAlias = true;

  void _shadow(Canvas c, double x, double y, double rx, double h) {
    final k = _clamp(1 - h / 220, 0.35, 1);
    _p
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = Color.fromRGBO(0, 0, 0, 0.38 * k);
    c.drawOval(
      Rect.fromCenter(
        center: Offset(x, y + 3),
        width: rx * k * 2,
        height: 11 * k,
      ),
      _p,
    );
  }

  void paintWorld(Canvas c, Size size) {
    frames++;
    final m = core.m, camX = cam.x + cam.kx;
    c.save();
    c.scale(layout.scale);
    c.clipRect(Rect.fromLTWH(0, 0, kBrawlW, layout.h));
    final calm = _calm;
    final z = cam.zoom + cam.zp * (reduceMotion ? 0.3 : 1);
    final shx = cam.shake * calm * math.sin(t * 97.3);
    final shy = cam.shake * calm * math.cos(t * 81.7);
    c.save();
    c.translate(cam.fx + shx, cam.fy + shy);
    c.scale(z, z);
    c.translate(-cam.fx, -cam.fy);
    stage.draw(
      c,
      camX,
      t,
      plantK: plantK,
      haze: m.kind == BrawlMonster.fog ? 1 : 0,
    );
    fx.drawBack(c, camX);
    _drawGroundMarks(c, camX);
    _drawMonster(c, camX);
    _drawFriends(c, camX);
    _drawFighter(c, camX);
    _drawFinisherProps(c, camX);
    _drawWaves(c, camX);
    _drawBolts(c, camX);
    fx.drawFront(c, camX);
    fx.drawNums(c, camX);
    c.restore();
    _drawBackdropFx(c);
    _drawSpeedLines(c);
    stage.drawVignette(c);
    if (flashScreen > 0.01 && calm > 0) {
      c.drawRect(
        Rect.fromLTWH(0, 0, kBrawlW, layout.h),
        _p
          ..shader = null
          ..style = PaintingStyle.fill
          ..color = Color.fromRGBO(255, 244, 217, 0.55 * calm * flashScreen),
      );
    }
    c.restore();
  }

  void _drawMonster(Canvas c, double camX) {
    final m = core.m, A = mon.actor!, M = mon, o = A.o, def = m.def;
    var x = m.x - camX + M.jx, y = gy;
    var scale = def.draw * m.scale, alpha = 1.0;
    o.flash = M.flash;
    final F = core.fin;
    final finishing = core.phase == BrawlPhase.finisher;
    if (m.kind == BrawlMonster.troll) {
      final base = switch (m.state) {
        BrawlMonsterState.telegraph => 0.12,
        BrawlMonsterState.strike => 0.2,
        BrawlMonsterState.recover => 0.75,
        BrawlMonsterState.daze => 0.8,
        BrawlMonsterState.idle => 0.55,
      };
      final blinkOn = (t % 5.2) > 5.0 ? 1.0 : 0.0;
      o.lid = finishing
          ? _clamp((F!.t - 1.0) / 0.5, 0.0, 1) * 0.5 +
                (F.t > 1.4 ? 0.5 : 0) +
                (F.t < 1.0 ? 0.8 : 0)
          : _clamp(M.surprise > 0 ? 0.1 : base + blinkOn * 0.45, 0, 1);
      o.bubble = finishing && F!.t > 1.5
          ? 0.3 + 0.55 * math.max(0.0, math.sin(t * 1.3))
          : (m.state == BrawlMonsterState.daze
                ? 0
                : 0.1 + 0.4 * math.max(0.0, math.sin(t * 1.0)));
      o.cover = finCover;
      o.mouthO = m.state == BrawlMonsterState.strike
          ? 1
          : (m.state == BrawlMonsterState.daze ? 0.5 : 0);
      o.brow = m.state == BrawlMonsterState.telegraph
          ? -2.5
          : (m.state == BrawlMonsterState.daze ? 2 : 0);
      o.lookX = _clamp((core.f.x - m.x) / 90, -1.4, 0.2);
      A.update(
        finishing && F!.t > 1.2 ? 'nap' : m.state.name,
        finishing ? math.max(0.0, F!.t - 1.2) : m.animT,
        dur: m.teleDur,
      );
      final P = A.pose, bi = A.rig.idx['body']! * 5;
      P[bi + 1] += M.rx;
      P[bi] += M.rr;
      P[bi + 3] *= 1 + 0.13 * M.sq;
      P[bi + 4] *= 1 - 0.18 * M.sq;
      _shadow(c, x, y, 98 * scale, 0);
    } else {
      final lookX = _clamp((core.f.x - m.x) / 110, -1, 1);
      final lookY = _clamp((core.f.h - 30) / 100, -0.6, 0.6) + 0.2;
      o.lookX = lookX;
      o.lookY = lookY;
      o.lid = (t % 4.3) > 4.18 ? 0.9 : 0;
      o.mouth = m.state == BrawlMonsterState.telegraph
          ? 0.1
          : (M.surprise > 0 ? 1 : 0.5);
      final rain = m.state == BrawlMonsterState.telegraph
          ? _clamp(m.st / (m.teleDur <= 0 ? 1.5 : m.teleDur), 0, 1)
          : m.state == BrawlMonsterState.strike
          ? 1.0
          : m.state == BrawlMonsterState.recover
          ? 1 - _clamp(m.st / 0.9, 0, 1)
          : 0.0;
      o.rain = rain;
      y = gy - m.bob * def.draw;
      if (finishing) {
        final ft = F!.t, pl = 212 - camX;
        scale *= finFogScale;
        if (ft > 0.9) {
          final u = _easeIo(_clamp((ft - 0.9) / 0.5, 0, 1));
          final tx = pl, ty = gy - 100;
          x = _lerp(m.x - camX, tx, u) + (ft > 1.4 ? math.sin(t * 2) * 5 : 0);
          final cy0 = gy - m.cy, cy1 = ty;
          final cyNow =
              _lerp(cy0, cy1, u) -
              math.sin(math.pi * u) * 46 +
              (ft > 1.4 ? math.sin(t * 3) * 3 : 0);
          y = cyNow + 72 * scale;
          if (ft > 2.35) {
            final k2 = _clamp((ft - 2.35) / 0.8, 0, 1);
            y -= k2 * 40;
            alpha = 1 - k2;
          }
          o.rain = ft > 1.4 && ft < 2.3 ? 1 : 0;
          o.mouth = ft > 1.9 ? 0.9 : 0.4;
          o.lid = ft > 1.9 ? 0.7 : 0;
        }
      }
      A.update(finishing ? 'daze' : m.state.name, m.animT, dur: m.teleDur);
      final P = A.pose, ci = A.rig.idx['cloud']! * 5;
      P[ci + 1] += M.rx;
      P[ci] += M.rr * 0.5;
      P[ci + 3] *= 1 + 0.12 * M.sq;
      P[ci + 4] *= 1 - 0.14 * M.sq;
      if (!finishing || F!.t < 0.95) {
        _shadow(c, x, gy.toDouble(), 70 * scale, m.bob * 4 + 20);
      } else if (alpha > 0.1) {
        _shadow(c, 212 - camX, gy.toDouble(), 18 * scale + 10, 120);
      }
    }
    _pen.cv = c;
    if (alpha < 1) {
      c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    }
    A.draw(_pen, x, y, scale, 1);
    if (alpha < 1) c.restore();
    // Telegraph marker: an exclamation mark above the head.
    if (m.state == BrawlMonsterState.telegraph &&
        m.kind == BrawlMonster.troll) {
      final k = _clamp(m.st / m.teleDur, 0, 1);
      final px = x - 6, py = gy - 168 * scale - 8 - math.sin(t * 14) * 2;
      _pen.fillCircle(px, py, 14, Color.fromRGBO(242, 176, 74, 0.5 + 0.5 * k));
      BrawlText.draw(c, '!', px, py + 9, size: 24, fill: _hex(0x2a1608));
    }
    if (m.kind == BrawlMonster.fog && m.state == BrawlMonsterState.telegraph) {
      BrawlText.draw(
        c,
        '!',
        x - 6,
        gy - m.cy - 70,
        size: 24,
        fill: _hex(0xE9F1F8),
        stroke: const Color.fromRGBO(30, 40, 60, 0.8),
        strokeW: 4,
      );
    }
  }

  void _drawGroundMarks(Canvas c, double camX) {
    final m = core.m;
    if (m.kind == BrawlMonster.troll &&
        (m.state == BrawlMonsterState.telegraph || core.waves.isNotEmpty)) {
      final a = m.state == BrawlMonsterState.telegraph
          ? _clamp(m.st / m.teleDur, 0, 1)
          : 0.4;
      _p
        ..style = PaintingStyle.fill
        ..shader = null
        ..color = _hex(
          0xF2B04A,
          0.18 + 0.3 * a * (0.6 + 0.4 * math.sin(t * 12)),
        );
      final x0 = m.x - m.rx - 12 - camX;
      for (var i = 0; i < 6; i++) {
        final x = x0 - 34 - i * 46 - ((t * 60) % 46);
        if (x < -20) continue;
        c.drawPath(
          Path()
            ..moveTo(x, gy + 11)
            ..lineTo(x + 16, gy + 5)
            ..lineTo(x + 16, gy + 17)
            ..close(),
          _p,
        );
      }
    }
    for (final d in core.drops) {
      final x = d.x - camX;
      if (d.state == BrawlDropState.mark) {
        final k = _clamp(
          1 + d.t / (core.m.teleDur <= 0 ? 1.6 : core.m.teleDur),
          0,
          1,
        );
        final pulse = 0.5 + 0.5 * math.sin(t * 11);
        final rx = d.r * (0.7 + 0.3 * k), ry = rx * 0.26;
        _p
          ..style = PaintingStyle.fill
          ..color = Color.fromRGBO(
            160,
            205,
            235,
            0.12 + 0.26 * k * (0.6 + 0.4 * pulse),
          );
        c.drawOval(
          Rect.fromCenter(
            center: Offset(x, gy + 9),
            width: rx * 2,
            height: ry * 2,
          ),
          _p,
        );
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = Color.fromRGBO(214, 236, 250, 0.55 + 0.45 * k);
        c.drawOval(
          Rect.fromCenter(
            center: Offset(x, gy + 9),
            width: rx * 2,
            height: ry * 2,
          ),
          _p,
        );
        final by = gy - 14 - 4 * math.sin(t * 8);
        _p
          ..style = PaintingStyle.fill
          ..color = Color.fromRGBO(214, 236, 250, 0.55 + 0.4 * k);
        c.drawPath(
          Path()
            ..moveTo(x - 5, by - 6)
            ..lineTo(x + 5, by - 6)
            ..lineTo(x, by + 4)
            ..close(),
          _p,
        );
      } else if (d.state == BrawlDropState.fall) {
        final u = d.t / d.fall,
            top = gy - core.m.cy - 20,
            yy = _lerp(top, gy.toDouble(), u * u);
        _p
          ..style = PaintingStyle.fill
          ..color = _hex(0xBFE0F4);
        c.drawCircle(Offset(x, yy), 5, _p);
        c.drawPath(
          Path()
            ..moveTo(x - 5, yy)
            ..lineTo(x, yy - 14)
            ..lineTo(x + 5, yy)
            ..close(),
          _p,
        );
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color.fromRGBO(190, 224, 244, 0.5);
        c.drawLine(Offset(x, yy - 16), Offset(x, yy - 34), _p);
        _p.style = PaintingStyle.fill;
      }
    }
  }

  void _drawWaves(Canvas c, double camX) {
    for (final w in core.waves) {
      final x = w.x - camX, h = w.hgt, hw = w.w * 0.8;
      _p
        ..style = PaintingStyle.fill
        ..shader = null
        ..color = const Color.fromRGBO(0, 0, 0, 0.25);
      c.drawOval(
        Rect.fromCenter(center: Offset(x, gy + 4), width: hw * 2.1, height: 8),
        _p,
      );
      final body = Path()
        ..moveTo(x - hw, gy + 4)
        ..cubicTo(x - hw * 0.6, gy + 3, x - hw * 0.62, gy - h, x, gy - h)
        ..cubicTo(x + hw * 0.62, gy - h, x + hw * 0.6, gy + 3, x + hw, gy + 4)
        ..close();
      _p.shader = Gradient.linear(
        Offset(0, gy - h),
        Offset(0, gy.toDouble()),
        const [
          Color.fromRGBO(255, 240, 205, 0.96),
          Color.fromRGBO(244, 196, 130, 0.92),
          Color.fromRGBO(214, 150, 86, 0.9),
        ],
        const [0, 0.5, 1],
      );
      c.drawPath(body, _p);
      _p
        ..shader = null
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color.fromRGBO(255, 255, 255, 0.8);
      c.drawPath(
        Path()
          ..moveTo(x - hw * 0.7, gy - 1)
          ..cubicTo(
            x - hw * 0.5,
            gy - h * 0.8,
            x - hw * 0.3,
            gy - h,
            x,
            gy - h,
          ),
        _p,
      );
      _p.style = PaintingStyle.fill;
      if (rnd.nextDouble() < 0.5) {
        fx.part(
          FxKind.dust,
          w.x + 10 + rnd.nextDouble() * 14,
          gy - 1,
          14,
          -8 - rnd.nextDouble() * 20,
          0.35,
          3,
          _hex(0xE4C79C),
          size1: 8,
          front: false,
          a: 0.7,
          drag: 2,
        );
      }
    }
  }

  void _drawBolts(Canvas c, double camX) {
    final ik = boostK(BrawlStat.intl);
    for (final b in core.bolts) {
      if (b.delay > 0) continue;
      final x = b.x - camX, y = gy - b.h;
      final rr = (b.big ? 20.0 : 15.0) * (1 + 0.6 * ik);
      final trail = 56 * (1 + 0.5 * ik);
      _p
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.plus
        ..shader = Gradient.linear(Offset(x - trail, y), Offset(x, y), const [
          Color.fromRGBO(191, 243, 238, 0),
          Color.fromRGBO(191, 243, 238, 0.7),
        ]);
      c.drawPath(
        Path()
          ..moveTo(x - trail, y)
          ..lineTo(x, y - 7 * (1 + 0.5 * ik))
          ..lineTo(x, y + 7 * (1 + 0.5 * ik))
          ..close(),
        _p,
      );
      _p.shader = Gradient.radial(
        Offset(x, y),
        rr,
        const [
          Color.fromRGBO(255, 255, 255, 1),
          Color.fromRGBO(191, 243, 238, 0.9),
          Color.fromRGBO(127, 200, 210, 0),
        ],
        const [0, 0.35, 1],
        TileMode.clamp,
        null,
        Offset(x, y),
        1,
      );
      c.drawCircle(Offset(x, y), rr, _p);
      _p
        ..shader = null
        ..blendMode = BlendMode.srcOver;
      if (rnd.nextDouble() < 0.7) {
        fx.part(
          FxKind.star,
          b.x - 14,
          gy - b.h + (rnd.nextDouble() - 0.5) * 8,
          -30,
          (rnd.nextDouble() - 0.5) * 30,
          0.3,
          2.4 * (1 + 0.5 * ik),
          _hex(0xDFFBF8),
          add: true,
          vr: 6,
        );
      }
    }
  }

  void _glow(
    Canvas c,
    double x,
    double y,
    double r,
    Color inner, [
    Color? outer,
  ]) {
    _p
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.plus
      ..shader = Gradient.radial(
        Offset(x, y),
        r,
        [inner, outer ?? inner.withValues(alpha: 0)],
        const [0, 1],
      );
    c.drawCircle(Offset(x, y), r, _p);
    _p
      ..shader = null
      ..blendMode = BlendMode.srcOver;
  }

  void _drawFighter(Canvas c, double camX) {
    final f = core.f, A = fighter!, o = A.o;
    A.phase += f.vx.abs() * 0.75 * dt;
    final st = f.state, an = f.anim;
    o.face = (st == BrawlFighterState.hurt || st == BrawlFighterState.down)
        ? 'hit'
        : (an == BrawlFighterAnim.victory || an == BrawlFighterAnim.pat)
        ? 'happy'
        : switch (an) {
            BrawlFighterAnim.kick ||
            BrawlFighterAnim.upper ||
            BrawlFighterAnim.dive ||
            BrawlFighterAnim.chargeSlam ||
            BrawlFighterAnim.slamRise ||
            BrawlFighterAnim.slamFall ||
            BrawlFighterAnim.superFlurry ||
            BrawlFighterAnim.superBlast ||
            BrawlFighterAnim.slamLand => 'effort',
            BrawlFighterAnim.blow => 'blow',
            BrawlFighterAnim.inhale => 'puff',
            _ => 'normal',
          };
    o.blink = blink > 0 ? 1 : 0;
    o.flash = fFlash * 0.85 + (chargeFlash > 0 ? chargeFlash * 0.4 : 0);
    final chargeK = st == BrawlFighterState.charge
        ? _clamp(f.charge / BrawlTune.slamFull, 0, 1)
        : 0.0;
    A.update(an.name, f.animT, charge: chargeK);
    final P = A.pose;
    P[3] *= 1 + 0.22 * fsq;
    P[4] *= 1 - 0.22 * fsq;
    final x = f.x - camX, y = gy - f.h;
    _shadow(c, x, gy.toDouble(), 20, f.h);
    // The week's training wears as a warm aura round the fighter.
    final tk = trainK;
    if (tk > 0.02 && st != BrawlFighterState.superMove) {
      final r = 40 + 18 * tk + math.sin(t * 3) * 2;
      _glow(c, x, y - 34, r, Color.fromRGBO(255, 214, 120, 0.10 + 0.26 * tk));
      if (rnd.nextDouble() < 0.05 + 0.25 * tk * (reduceMotion ? 0.3 : 1)) {
        fx.part(
          FxKind.star,
          f.x + (rnd.nextDouble() - 0.5) * 34,
          y - 8 - rnd.nextDouble() * 50,
          0,
          -22 - rnd.nextDouble() * 20,
          0.8,
          2.2,
          _hex(0xFFE8A8),
          add: true,
          vr: 4,
        );
      }
    }
    // Aura while charging or in a super.
    if (st == BrawlFighterState.charge || st == BrawlFighterState.superMove) {
      final k = st == BrawlFighterState.superMove ? 1.0 : 0.3 + 0.7 * chargeK;
      final r = 34 + 22 * k + math.sin(t * 18) * 3;
      _glow(
        c,
        x,
        y - 36,
        r + 20,
        Color.fromRGBO(255, 236, 170, 0.5 * k),
        const Color.fromRGBO(255, 190, 90, 0),
      );
      if (st == BrawlFighterState.charge && rnd.nextDouble() < 0.6) {
        fx.part(
          FxKind.star,
          f.x + (rnd.nextDouble() - 0.5) * 40,
          y - 6 - rnd.nextDouble() * 6,
          0,
          -50 - rnd.nextDouble() * 40,
          0.5,
          2.4,
          _hex(0xFFE8A8),
          add: true,
        );
      }
    }
    _pen.cv = c;
    A.draw(_pen, x, y, 1.2, 1);
    if (st == BrawlFighterState.charge) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..shader = null
        ..color = f.chargeReady
            ? const Color.fromRGBO(255, 230, 140, 0.95)
            : const Color.fromRGBO(255, 226, 170, 0.7);
      c.drawArc(
        Rect.fromCircle(center: Offset(x, y - 36), radius: 30 + 10 * chargeK),
        -math.pi / 2,
        _tau * chargeK,
        false,
        _p,
      );
      _p.style = PaintingStyle.fill;
    }
    if (st == BrawlFighterState.cast) {
      final p = A.pt('foreF', 0, 9);
      final ik = boostK(BrawlStat.intl);
      _glow(
        c,
        p.dx,
        p.dy,
        20 * (1 + 0.5 * ik),
        const Color.fromRGBO(223, 251, 248, 0.95),
        const Color.fromRGBO(127, 200, 210, 0),
      );
    }
  }

  void _drawFriends(Canvas c, double camX) {
    for (final fr in core.friends) {
      if (fr.state == BrawlFriendState.wait) continue;
      final A = _friendActors.putIfAbsent(
        fr.index,
        () => RigActor(rigFighter, 'fighter', kFriendPalettes[fr.index % 2]),
      );
      final x = fr.x - camX;
      A.phase +=
          (fr.state == BrawlFriendState.enter ||
                  fr.state == BrawlFriendState.exit
              ? 470
              : 0) *
          0.75 *
          dt;
      A.o
        ..face = fr.anim == BrawlFighterAnim.wave
            ? 'happy'
            : (fr.anim == BrawlFighterAnim.kick ? 'effort' : 'normal')
        ..blink = 0
        ..flash = 0;
      A.update(fr.anim.name, fr.animT);
      _shadow(c, x, gy.toDouble(), 17, 0);
      _pen.cv = c;
      A.draw(_pen, x, gy.toDouble(), 1.05, 1);
      if (fr.state == BrawlFriendState.enter && rnd.nextDouble() < 0.5) {
        fx.part(
          FxKind.dust,
          fr.x - 14,
          gy - 2,
          -20,
          -8,
          0.3,
          2.4,
          _hex(0xD8BC94),
          size1: 6,
          front: false,
          a: 0.7,
        );
      }
    }
  }

  void _drawFinisherProps(Canvas c, double camX) {
    if (core.phase != BrawlPhase.finisher) return;
    final m = core.m, F = core.fin!;
    if (m.kind == BrawlMonster.troll && F.t > 0.4 && F.t < 1.25) {
      final u = _clamp((F.t - 0.4) / 0.8, 0, 1), e = _easeOut(u);
      final hand = fighter!.pt('foreF', 0, 9);
      final x = _lerp(hand.dx, m.x - camX, e);
      final y = _lerp(hand.dy - 20, gy - 70, e) - math.sin(math.pi * u) * 70;
      c.save();
      c.translate(x, y);
      c.rotate(u * 5.5);
      final s = _lerp(0.6, 1.2, u);
      c.scale(s, s);
      _pen.cv = c;
      _pen.fillRR(-22, -15, 44, 32, 6, kTrollPalette['quiltDark']!);
      _pen.fillRR(-22, -17, 44, 30, 6, kTrollPalette['quilt']!);
      final ln = kTrollPalette['quiltLine']!;
      _pen.dashed(-8, -15, -8, 13, 4, 3, 1.4, ln);
      _pen.dashed(8, -15, 8, 13, 4, 3, 1.4, ln);
      _pen.dashed(-20, -2, 20, -2, 4, 3, 1.4, ln);
      c.restore();
    }
  }

  void _drawBackdropFx(Canvas c) {
    if (superT > 0.02) {
      final k = _clamp(superT * 3, 0, 1);
      c.drawRect(
        Rect.fromLTRB(-40, -40, kBrawlW + 40, layout.h + 40),
        _p
          ..shader = null
          ..style = PaintingStyle.fill
          ..color = Color.fromRGBO(14, 7, 3, 0.5 * k),
      );
    }
  }

  void _drawSpeedLines(Canvas c) {
    final sup =
        core.f.state == BrawlFighterState.superMove ||
        (core.phase == BrawlPhase.finisher && core.timeScale < 0.8);
    if (!sup || reduceMotion) return;
    final k = core.f.state == BrawlFighterState.superMove
        ? _clamp(superT * 2.5, 0, 1)
        : 0.55;
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..blendMode = BlendMode.plus
      ..shader = null
      ..color = const Color.fromRGBO(255, 230, 170, 0.16);
    final cx = core.f.state == BrawlFighterState.superMove
        ? cam.fx
        : kBrawlW / 2;
    final cy = cam.fy - 10;
    final path = Path();
    for (var i = 0; i < 26; i++) {
      final a = i * (_tau / 26) + t * 0.8;
      final r0 = 90.0 + (i * 37 % 50);
      final r1 = r0 + 160 + 80 * k + (i * 53 % 90);
      path
        ..moveTo(cx + math.cos(a) * r0, cy + math.sin(a) * r0 * 1.1)
        ..lineTo(cx + math.cos(a) * r1, cy + math.sin(a) * r1 * 1.1);
    }
    c.drawPath(path, _p);
    _p
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.srcOver;
  }

  // ---------------------------------------------------------------- drawing: the HUD and the controls

  void _bar(
    Canvas c,
    double x,
    double y,
    double w,
    double h,
    double frac,
    double chipFrac,
    Color c1,
    Color c2,
    bool glow,
  ) {
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      Radius.circular(h / 2),
    );
    _p
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = const Color.fromRGBO(8, 4, 2, 0.55);
    c.drawRRect(rr, _p);
    c.save();
    c.clipRRect(rr);
    if (chipFrac > frac) {
      _p.color = const Color.fromRGBO(255, 244, 217, 0.9);
      c.drawRect(Rect.fromLTWH(x, y, w * chipFrac, h), _p);
    }
    if (frac > 0.002) {
      _p.shader = Gradient.linear(Offset(0, y), Offset(0, y + h), [c1, c2]);
      c.drawRect(Rect.fromLTWH(x, y, w * frac, h), _p);
      _p
        ..shader = null
        ..color = const Color.fromRGBO(255, 255, 255, 0.3);
      c.drawRect(Rect.fromLTWH(x, y + 1, w * frac, h * 0.28), _p);
    }
    c.restore();
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = glow ? 2 : 1.2
      ..color = glow
          ? Color.fromRGBO(255, 210, 120, 0.6 + 0.4 * math.sin(t * 8))
          : const Color.fromRGBO(255, 226, 170, 0.4);
    c.drawRRect(rr, _p);
    _p.style = PaintingStyle.fill;
  }

  static String _thousands(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  void paintHud(Canvas c, Size size) {
    c.save();
    c.scale(layout.scale);
    final core = this.core, m = core.m, f = core.f, lo = core.lo;
    final top = layout.hudTop;
    // The name line.
    BrawlText.draw(
      c,
      '${m.def.name.toUpperCase()}  LV ${lo.level}',
      kBrawlW / 2,
      36 + top,
      size: 12,
      weight: FontWeight.w500,
      family: kBrawlMono,
      fill: _hex(0xE5C896),
      stroke: const Color.fromRGBO(20, 10, 4, 0.8),
    );
    _bar(
      c,
      16,
      58 + top,
      kBrawlW - 32,
      15,
      m.hp / m.hpMax,
      chip,
      _hex(0xF6D089),
      _hex(0xD9A24C),
      false,
    );
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = null
      ..color = const Color.fromRGBO(20, 10, 4, 0.35);
    final ticks = Path();
    for (var i = 1; i < 10; i++) {
      final x = 16 + (kBrawlW - 32) * i / 10;
      ticks
        ..moveTo(x, 60 + top)
        ..lineTo(x, 71 + top);
    }
    c.drawPath(ticks, _p);
    _p.style = PaintingStyle.fill;
    // The fighter's health and the Super meter.
    _p.color = _hex(0xA8D49A);
    c.drawPath(
      Path()
        ..moveTo(25, 94 + top)
        ..cubicTo(14, 88 + top, 17, 79 + top, 25, 84 + top)
        ..cubicTo(33, 79 + top, 36, 88 + top, 25, 94 + top),
      _p,
    );
    _bar(
      c,
      40,
      83 + top,
      110,
      9,
      f.hp / f.hpMax,
      f.hp / f.hpMax,
      _hex(0xB8DDAA),
      _hex(0x6F9A66),
      false,
    );
    BrawlText.draw(
      c,
      brawlFormatTime(core.t),
      kBrawlW / 2,
      93 + top,
      size: 13,
      weight: FontWeight.w500,
      family: kBrawlMono,
      fill: _hex(0xFFF4D9),
      stroke: const Color.fromRGBO(20, 10, 4, 0.8),
    );
    final full = core.sup >= 100;
    _bar(
      c,
      kBrawlW - 150,
      83 + top,
      110,
      9,
      core.sup / 100,
      core.sup / 100,
      _hex(0xFFE3A0),
      _hex(0xF2A93F),
      full,
    );
    if (meterGlow > 0.01) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..blendMode = BlendMode.plus
        ..color = _hex(0xFFE9A8, meterGlow.clamp(0.0, 1.0));
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(kBrawlW - 152, 81 + top, 114, 13),
          const Radius.circular(6.5),
        ),
        _p,
      );
      _p
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.srcOver;
    }
    c.save();
    c.translate(kBrawlW - 25, 88 + top);
    final pulse = 1.0 + (full ? 0.12 * math.sin(t * 8) : 0.0);
    c.scale(pulse, pulse);
    brawlIcon(
      c,
      'super',
      0,
      0,
      20,
      full ? _hex(0xFFD25A) : const Color.fromRGBO(255, 226, 170, 0.45),
    );
    c.restore();
    // The combo counter.
    if (comboShown >= 2) {
      final a =
          (comboFade > 0 ? 1 - comboFade / 0.9 : 1.0) *
          (core.phase == BrawlPhase.finisher
              ? _clamp(1 - core.fin!.t * 2.5, 0, 1)
              : 1.0);
      final pop = 1 + comboPop * (reduceMotion ? 0.15 : 0.5);
      final n = comboShown.round();
      final col = n >= 20
          ? _hex(0xFFB38A)
          : n >= 10
          ? _hex(0xFFC75A)
          : n >= 5
          ? _hex(0xF6D089)
          : _hex(0xFFF4D9);
      c.save();
      c.translate(kBrawlW - 18, 150 + top);
      c.scale(pop, pop);
      BrawlText.draw(
        c,
        '$n',
        0,
        0,
        size: 46 + math.min(14, n * 0.5),
        italic: true,
        align: 1,
        fill: col,
        stroke: const Color.fromRGBO(30, 14, 6, 0.95),
        strokeW: 7,
        alpha: a,
      );
      BrawlText.draw(
        c,
        'HITS',
        0,
        18,
        size: 13,
        weight: FontWeight.w700,
        family: kBrawlMono,
        align: 1,
        fill: _hex(0xE5C896),
        stroke: const Color.fromRGBO(30, 14, 6, 0.95),
        strokeW: 4,
        alpha: a,
      );
      if (core.combo.dmg > 0) {
        BrawlText.draw(
          c,
          '${_thousands(core.combo.dmg.round())} dmg',
          0,
          34,
          size: 11,
          weight: FontWeight.w500,
          family: kBrawlMono,
          align: 1,
          fill: const Color.fromRGBO(246, 235, 214, 0.8),
          alpha: a,
        );
      }
      c.restore();
    }
    if (f.state == BrawlFighterState.down && !f.caught) {
      BrawlText.draw(
        c,
        'Catch your breath...',
        kBrawlW / 2,
        gy - 150,
        size: 20,
        weight: FontWeight.w700,
        italic: true,
        fill: _hex(0xFFF4D9),
        stroke: const Color.fromRGBO(30, 14, 6, 0.9),
        strokeW: 4,
      );
    }
    _paintHints(c);
    _paintControls(c);
    _paintAnnouncer(c);
    c.restore();
  }

  void _paintHints(Canvas c) {
    final core = this.core, lay = layout;
    if (core.phase == BrawlPhase.fight &&
        core.t > 1.2 &&
        core.t < 14 &&
        !easy) {
      final a = _clamp(1 - (core.t - 9) / 5, 0, 1) * 0.85;
      if (!touch.usedPad) {
        BrawlText.draw(
          c,
          'slide to move',
          18,
          lay.pad.y - lay.pad.r - 34,
          size: 11,
          weight: FontWeight.w500,
          family: kBrawlMono,
          align: -1,
          fill: _hex(0xE5C896),
          stroke: const Color.fromRGBO(20, 10, 4, 0.8),
          alpha: a,
        );
        BrawlText.draw(
          c,
          'swipe up to jump',
          18,
          lay.pad.y - lay.pad.r - 20,
          size: 11,
          weight: FontWeight.w500,
          family: kBrawlMono,
          align: -1,
          fill: _hex(0xE5C896),
          stroke: const Color.fromRGBO(20, 10, 4, 0.8),
          alpha: a,
        );
      }
      if (!touch.usedAtk) {
        BrawlText.draw(
          c,
          'tap to combo, hold for slam',
          kBrawlW - 14,
          lay.attack.y + lay.attack.r + 38,
          size: 11,
          weight: FontWeight.w500,
          family: kBrawlMono,
          align: 1,
          fill: _hex(0xE5C896),
          stroke: const Color.fromRGBO(20, 10, 4, 0.8),
          alpha: a,
        );
      }
    }
    if (core.phase == BrawlPhase.fight &&
        core.t > 1.2 &&
        core.t < 9 &&
        easy &&
        !touch.usedAtk) {
      BrawlText.draw(
        c,
        'TAP ANYWHERE TO ATTACK',
        kBrawlW / 2,
        lay.h - 196 - lay.lift,
        size: 14,
        weight: FontWeight.w700,
        family: kBrawlMono,
        fill: _hex(0xFFE3A0),
        stroke: const Color.fromRGBO(20, 10, 4, 0.85),
        strokeW: 4,
        alpha: 0.9,
      );
      BrawlText.draw(
        c,
        'hold for a big slam',
        kBrawlW / 2,
        lay.h - 178 - lay.lift,
        size: 11,
        weight: FontWeight.w500,
        family: kBrawlMono,
        fill: _hex(0xE5C896),
        stroke: const Color.fromRGBO(20, 10, 4, 0.85),
        alpha: 0.9,
      );
    }
  }

  void _paintAnnouncer(Canvas c) {
    final a = ann;
    if (a == null) return;
    final tt = a.t, dur = a.dur;
    final inK = _clamp(tt / 0.22, 0, 1);
    final s = a.hold
        ? 1 + 0.06 * math.sin(t * 9) * (reduceMotion ? 0.3 : 1)
        : (inK < 1
              ? _lerp(reduceMotion ? 1.2 : 2.4, 1, _easeBack(inK))
              : 1 + 0.03 * (tt / dur));
    final out = a.hold ? 1.0 : _clamp((dur - tt) / 0.25, 0, 1);
    final y = layout.h * a.y;
    c.save();
    c.translate(
      kBrawlW / 2 +
          (a.shake > 0 ? math.sin(tt * 90) * a.shake * (1 - inK) * 4 : 0),
      y,
    );
    c.scale(s, s);
    final alpha = math.min(1.0, inK * 1.4) * out;
    final w = BrawlText.width(a.text, a.size);
    final bounds = Rect.fromLTWH(-w / 2 - 20, -a.size, w + 40, a.size * 1.4);
    c.saveLayer(bounds, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    BrawlText.drawGold(c, a.text, a.size, a.col);
    // A shine that sweeps across once.
    if (!a.hold && tt < 0.7 && !reduceMotion) {
      final sx = _lerp(-a.size * 2, a.size * 2, tt / 0.7);
      c.drawRect(
        bounds,
        Paint()
          ..blendMode = BlendMode.srcATop
          ..shader = Gradient.linear(
            Offset(sx - 30, 0),
            Offset(sx + 30, 0),
            const [
              Color.fromRGBO(255, 255, 255, 0),
              Color.fromRGBO(255, 255, 255, 0.55),
              Color.fromRGBO(255, 255, 255, 0),
            ],
            const [0, 0.5, 1],
          ),
      );
    }
    c.restore();
    c.restore();
  }

  void _btn(
    Canvas c,
    BrawlCircle ci, {
    String icon = '',
    String label = '',
    bool ready = false,
    double cd = 0,
    bool locked = false,
    String lockText = '',
    double? meter,
    double press = 0,
    bool attack = false,
    bool finish = false,
    double trained = 0,
  }) {
    final sc = 1 - 0.07 * press, x = ci.x, y = ci.y, r = ci.r * sc;
    c.save();
    if (trained > 0 && !locked) {
      // A trained ability keeps a soft halo, stronger the bigger the week.
      final halo = 0.10 + 0.34 * trained;
      _glow(
        c,
        x,
        y,
        r * (1.35 + 0.25 * trained),
        Color.fromRGBO(255, 205, 110, halo * (0.8 + 0.2 * math.sin(t * 3))),
      );
    }
    if (ready) {
      final pulse = 0.5 + 0.5 * math.sin(t * 6);
      _glow(
        c,
        x,
        y,
        r * 1.55,
        Color.fromRGBO(255, 196, 100, 0.45 + 0.25 * pulse),
      );
    }
    _p
      ..style = PaintingStyle.fill
      ..shader = null;
    List<Color> cols;
    List<double> stops;
    if (finish) {
      cols = const [Color(0xFFFFF3CF), Color(0xFFF8CF7A), Color(0xFFD18A32)];
      stops = const [0, 0.45, 1];
    } else if (locked) {
      cols = const [
        Color.fromRGBO(255, 226, 170, 0.1),
        Color.fromRGBO(24, 14, 8, 0.78),
      ];
      stops = const [0, 1];
    } else if (ready) {
      cols = const [
        Color.fromRGBO(255, 236, 190, 0.52),
        Color.fromRGBO(120, 76, 30, 0.78),
        Color.fromRGBO(40, 24, 12, 0.9),
      ];
      stops = const [0, 0.7, 1];
    } else {
      cols = const [
        Color.fromRGBO(255, 226, 170, 0.22),
        Color.fromRGBO(24, 14, 8, 0.82),
      ];
      stops = const [0, 1];
    }
    _p.shader = Gradient.radial(
      Offset(x, y),
      r,
      cols,
      stops,
      TileMode.clamp,
      null,
      Offset(x - r * 0.3, y - r * 0.4),
      r * 0.1,
    );
    c.drawCircle(Offset(x, y), r, _p);
    _p.shader = null;
    // A specular drop of light.
    _p.color = Color.fromRGBO(255, 248, 226, finish ? 0.5 : 0.18);
    c.save();
    c.translate(x - r * 0.32, y - r * 0.5);
    c.rotate(-0.5);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 0.8, height: r * 0.4),
      _p,
    );
    c.restore();
    if (cd > 0 && !locked) {
      _p.color = const Color.fromRGBO(8, 4, 2, 0.55);
      c.drawPath(
        Path()
          ..moveTo(x, y)
          ..arcTo(
            Rect.fromCircle(center: Offset(x, y), radius: r - 1),
            -math.pi / 2,
            _tau * cd,
            false,
          )
          ..close(),
        _p,
      );
    }
    if (meter != null) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color.fromRGBO(255, 226, 170, 0.2);
      c.drawCircle(Offset(x, y), r + 5, _p);
      _p.color = ready ? _hex(0xFFD25A) : _hex(0xE5A94A);
      c.drawArc(
        Rect.fromCircle(center: Offset(x, y), radius: r + 5),
        -math.pi / 2,
        _tau * meter,
        false,
        _p,
      );
    }
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = ready || finish ? 2.4 : 1.4
      ..color = finish
          ? const Color.fromRGBO(255, 244, 200, 0.95)
          : ready
          ? const Color.fromRGBO(255, 214, 130, 0.95)
          : const Color.fromRGBO(255, 226, 170, 0.34);
    c.drawCircle(Offset(x, y), r, _p);
    _p.style = PaintingStyle.fill;
    if (locked) {
      brawlIcon(
        c,
        'lock',
        x,
        y - 5,
        r * 0.62,
        const Color.fromRGBO(246, 235, 214, 0.55),
        2.2,
      );
      BrawlText.draw(
        c,
        lockText,
        x,
        y + r * 0.62,
        size: math.max(11, (r * 0.3).roundToDouble()),
        weight: FontWeight.w700,
        family: kBrawlMono,
        fill: const Color.fromRGBO(246, 235, 214, 0.78),
      );
    } else if (finish) {
      BrawlText.draw(c, 'FINISH', x, y - 2, size: 21, fill: _hex(0x3a1d08));
      BrawlText.draw(c, 'IT!', x, y + 22, size: 26, fill: _hex(0x3a1d08));
    } else {
      brawlIcon(
        c,
        icon,
        x,
        y - r * 0.12,
        r * 0.74,
        ready || attack
            ? _hex(0xFFF4D9)
            : const Color.fromRGBO(255, 244, 217, 0.7),
        2.2,
      );
      BrawlText.draw(
        c,
        label,
        x,
        y + r * 0.7,
        size: math.max(11, (r * 0.24).roundToDouble()),
        weight: FontWeight.w700,
        family: kBrawlMono,
        fill: ready || attack
            ? _hex(0xFFE3A0)
            : const Color.fromRGBO(255, 226, 170, 0.78),
      );
    }
    if (trained > 0 && !locked) {
      c.save();
      c.translate(x + r * 0.72, y - r * 0.72);
      brawlIcon(c, 'sparkle', 0, 0, 17 + 5 * trained, _hex(0xFFD25A), 1);
      c.restore();
    }
    c.restore();
  }

  double _cdFrac(double cd, double total) =>
      total > 0 ? _clamp(cd / total, 0, 1) : 0;

  void _paintControls(Canvas c) {
    final core = this.core, lo = core.lo, f = core.f, lay = layout;
    final daze = core.phase == BrawlPhase.daze;
    final spellC = easy ? lay.eSpell : lay.spell;
    final friendC = easy ? lay.eFriend : lay.friend;
    final supC = easy ? lay.eSup : lay.sup;
    double tr(BrawlStat s, bool on) =>
        on ? math.max(boostK(s), (lo.points[s] ?? 0) > 0 ? 0.25 : 0.0) : 0.0;
    _btn(
      c,
      spellC,
      icon: 'bolt',
      label: 'SPELL',
      ready: lo.spell.on && core.cd.spell <= 0,
      cd: _cdFrac(core.cd.spell, lo.spell.cd),
      locked: !lo.spell.on,
      lockText: 'INT 10',
      trained: tr(BrawlStat.intl, lo.spell.on),
      press: touch.press['spell']!,
    );
    _btn(
      c,
      friendC,
      icon: 'friends',
      label: 'FRIEND',
      ready: lo.friend.on && core.cd.friend <= 0,
      cd: _cdFrac(core.cd.friend, lo.friend.cd),
      locked: !lo.friend.on,
      lockText: 'SOC 10',
      trained: tr(BrawlStat.soc, lo.friend.on),
      press: touch.press['friend']!,
    );
    _btn(
      c,
      supC,
      icon: 'super',
      label: 'SUPER',
      ready: lo.dis.on && core.sup >= 100,
      meter: lo.dis.on ? core.sup / 100 : 0,
      locked: !lo.dis.on,
      lockText: 'DIS 10',
      trained: tr(BrawlStat.dis, lo.dis.on),
      press: touch.press['sup']!,
    );
    if (!easy) {
      final px = touch.padOn ? touch.padOx : lay.pad.x,
          py = touch.padOn ? touch.padOy : lay.pad.y;
      _p
        ..style = PaintingStyle.fill
        ..shader = Gradient.radial(
          Offset(px, py),
          lay.pad.r,
          const [
            Color.fromRGBO(255, 226, 170, 0.07),
            Color.fromRGBO(255, 226, 170, 0.16),
          ],
          const [0, 1],
          TileMode.clamp,
          null,
          Offset(px, py),
          6,
        );
      c.drawCircle(Offset(px, py), lay.pad.r, _p);
      _p
        ..shader = null
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color.fromRGBO(255, 226, 170, 0.32);
      c.drawCircle(Offset(px, py), lay.pad.r, _p);
      _p
        ..style = PaintingStyle.fill
        ..color = const Color.fromRGBO(255, 226, 170, 0.5);
      final pr = lay.pad.r;
      c.drawPath(
        Path()
          ..moveTo(px - pr + 10, py)
          ..lineTo(px - pr + 21, py - 7)
          ..lineTo(px - pr + 21, py + 7)
          ..close(),
        _p,
      );
      c.drawPath(
        Path()
          ..moveTo(px + pr - 10, py)
          ..lineTo(px + pr - 21, py - 7)
          ..lineTo(px + pr - 21, py + 7)
          ..close(),
        _p,
      );
      c.drawPath(
        Path()
          ..moveTo(px, py - pr + 9)
          ..lineTo(px - 7, py - pr + 20)
          ..lineTo(px + 7, py - pr + 20)
          ..close(),
        _p,
      );
      final kx = px + (touch.padOn ? touch.padKx : 0),
          ky = py + (touch.padOn ? touch.padKy : 0);
      _p.shader = Gradient.radial(
        Offset(kx, ky),
        24,
        const [
          Color.fromRGBO(255, 240, 200, 0.7),
          Color.fromRGBO(201, 165, 106, 0.6),
        ],
        const [0, 1],
        TileMode.clamp,
        null,
        Offset(kx - 6, ky - 8),
        2,
      );
      c.drawCircle(Offset(kx, ky), 22, _p);
      _p
        ..shader = null
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color.fromRGBO(255, 244, 217, 0.6);
      c.drawCircle(Offset(kx, ky), 22, _p);
      _p.style = PaintingStyle.fill;
      final slamReady = lo.slam.on && core.cd.slam <= 0 && !daze;
      _btn(
        c,
        lay.attack,
        icon: 'fist',
        label: 'ATTACK',
        ready: slamReady,
        attack: true,
        finish: daze,
        press: touch.press['attack']!,
      );
      if (!daze && f.state != BrawlFighterState.charge && lo.slam.on) {
        if (core.cd.slam > 0) {
          _p
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color.fromRGBO(255, 226, 170, 0.55);
          c.drawArc(
            Rect.fromCircle(
              center: Offset(lay.attack.x, lay.attack.y),
              radius: lay.attack.r + 6,
            ),
            -math.pi / 2,
            _tau * (1 - _clamp(core.cd.slam / lo.slam.cd, 0, 1)),
            false,
            _p,
          );
          _p.style = PaintingStyle.fill;
        }
        BrawlText.draw(
          c,
          slamReady ? 'HOLD FOR SLAM' : 'SLAM RECHARGING',
          lay.attack.x,
          lay.attack.y + lay.attack.r + 17,
          size: 11,
          weight: FontWeight.w700,
          family: kBrawlMono,
          fill: slamReady
              ? _hex(0xFFD25A)
              : const Color.fromRGBO(246, 235, 214, 0.6),
          stroke: const Color.fromRGBO(20, 10, 4, 0.7),
        );
      }
      if (f.state == BrawlFighterState.charge) {
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = _hex(0xFFD25A);
        c.drawArc(
          Rect.fromCircle(
            center: Offset(lay.attack.x, lay.attack.y),
            radius: lay.attack.r + 7,
          ),
          -math.pi / 2,
          _tau * _clamp(f.charge / BrawlTune.slamFull, 0, 1),
          false,
          _p,
        );
        _p.style = PaintingStyle.fill;
      }
    } else {
      for (final rp in touch.ripples) {
        final u = rp[2] / 0.5;
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Color.fromRGBO(255, 226, 170, 0.7 * (1 - u));
        c.drawCircle(Offset(rp[0], rp[1]), 12 + 50 * u, _p);
      }
      _p.style = PaintingStyle.fill;
      if (daze) _btn(c, lay.eFinish, finish: true, press: touch.press['tap']!);
    }
  }
}

/// Paints the stage, the characters and the effects.
class BrawlWorldPainter extends CustomPainter {
  BrawlWorldPainter(this.scene) : super(repaint: scene);
  final BrawlScene scene;

  @override
  void paint(Canvas canvas, Size size) => scene.paintWorld(canvas, size);

  @override
  bool shouldRepaint(BrawlWorldPainter old) => old.scene != scene;
}

/// Paints the bars, the combo counter, the announcer and the controls.
class BrawlHudPainter extends CustomPainter {
  BrawlHudPainter(this.scene) : super(repaint: scene);
  final BrawlScene scene;

  @override
  void paint(Canvas canvas, Size size) => scene.paintHud(canvas, size);

  @override
  bool shouldRepaint(BrawlHudPainter old) => old.scene != scene;
}
