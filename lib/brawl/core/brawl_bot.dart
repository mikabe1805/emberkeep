import 'dart:math' as math;

import 'brawl_fight.dart';
import 'brawl_input.dart';
import 'brawl_monsters.dart';
import 'brawl_rng.dart';
import 'brawl_state.dart';
import 'brawl_tuning.dart';

/// An average player, for tuning and for tests.
///
/// It taps ATTACK about [tapRate] times a second while free, holds for Power
/// Slam when it is ready, fires Spell, Friend and Super a beat after they
/// light up, dodges the monster's move about [dodgeP] of the time, and taps
/// FINISH IT! half a second after it appears. It drives the same
/// [BrawlInput] a touch or keyboard layer drives.
final class BrawlBot {
  BrawlBot(
    this.fight, {
    this.tapRate = 2.5,
    this.dodgeP = 0.7,
    this.react = 0.28,
    this.finishReact = 0.5,
    int seed = 1,
  }) : _rng = BrawlRng(seed * 104729 + 7);

  final BrawlFight fight;
  final double tapRate;
  final double dodgeP;
  final double react;
  final double finishReact;
  final BrawlRng _rng;

  /// Hand this to [BrawlFight.step].
  final BrawlInput input = BrawlInput();

  double _nextTap = 0.3;
  double _releaseAt = -1;
  double? _slamRelease;
  final Map<String, double?> _ready = {};
  double _dodgeMoveUntil = 0;
  double _dodgeDir = 0;
  bool _teleSeen = false;
  double _teleStart = 0;
  bool _teleDodge = false;
  double _finishAt = -1;
  double _jumpAt = -1;

  bool _when(String key, bool cond, double now) {
    if (!cond) {
      _ready[key] = null;
      return false;
    }
    _ready[key] ??= now + react * (0.5 + _rng.next());
    if (now >= _ready[key]!) {
      _ready[key] = null;
      return true;
    }
    return false;
  }

  /// Looks at the fight and decides what the hands do this step.
  void drive() {
    final g = fight;
    final f = g.f;
    final m = g.m;
    final inp = input;
    final now = g.clock;
    inp.moveX = 0;
    if (g.phase == BrawlPhase.intro) return;
    final stand = g.frontAt(34) - 30;
    if (now < _dodgeMoveUntil) {
      inp.moveX = _dodgeDir;
    } else if (f.x < stand - 12) {
      inp.moveX = 1;
    } else if (f.x > stand + 16) {
      inp.moveX = -1;
    }
    // The Troll's cushion slam: a person watches the raised cushion and jumps
    // about when it comes down.
    if (m.state == BrawlMonsterState.telegraph &&
        m.kind == BrawlMonster.troll) {
      if (!_teleSeen) {
        _teleSeen = true;
        _teleStart = now;
        _teleDodge = _rng.next() < dodgeP;
        _jumpAt =
            now + math.max(0.3, m.teleDur - 0.25 + (_rng.next() - 0.5) * 0.3);
      }
      if (_teleDodge && _jumpAt > 0 && now >= _jumpAt && f.grounded) {
        inp.pJump = true;
        _jumpAt = -1;
      }
    }
    if (m.state == BrawlMonsterState.telegraph && m.kind == BrawlMonster.fog) {
      if (!_teleSeen) {
        _teleSeen = true;
        _teleStart = now;
        _teleDodge = _rng.next() < dodgeP;
      }
      if (_teleDodge && now - _teleStart > 0.45 && now < _teleStart + 1.0) {
        for (final d in g.drops) {
          if ((d.x - f.x).abs() < d.r + 12 && now >= _dodgeMoveUntil) {
            _dodgeDir = d.x <= f.x ? 1 : -1;
            _dodgeMoveUntil = now + 0.5;
            break;
          }
        }
      }
    } else if (m.state == BrawlMonsterState.idle) {
      _teleSeen = false;
    }
    if (g.phase == BrawlPhase.daze) {
      inp.attackHeld = false;
      _slamRelease = null;
      if (_finishAt < 0) {
        _finishAt = now + finishReact * (0.8 + 0.4 * _rng.next());
      }
      if (now >= _finishAt) {
        inp.pFinish = true;
        inp.pAtk = true;
      }
      return;
    }
    final free =
        f.state == BrawlFighterState.free ||
        f.state == BrawlFighterState.attack;
    if (_when('spell', g.lo.spell.on && g.cd.spell <= 0 && free, now)) {
      inp.pSpell = true;
    }
    if (_when('friend', g.lo.friend.on && g.cd.friend <= 0 && free, now)) {
      inp.pFriend = true;
    }
    if (_when('super', g.lo.dis.on && g.sup >= 100 && free, now)) {
      inp.pSuper = true;
    }
    if (_slamRelease != null) {
      if (now >= _slamRelease!) {
        inp.attackHeld = false;
        _slamRelease = null;
        _nextTap = now + 0.55;
      }
      return;
    }
    if (_releaseAt > 0 && now >= _releaseAt) {
      inp.attackHeld = false;
      _releaseAt = -1;
    }
    if (now >= _nextTap &&
        f.state != BrawlFighterState.down &&
        f.state != BrawlFighterState.getup &&
        f.state != BrawlFighterState.hurt) {
      if (g.lo.slam.on &&
          g.cd.slam <= 0 &&
          f.grounded &&
          (f.state == BrawlFighterState.free ||
              f.state == BrawlFighterState.attack)) {
        inp.pAtk = true;
        inp.attackHeld = true;
        _slamRelease = now + BrawlTune.holdToSlam + 0.25 + _rng.next() * 0.25;
      } else {
        inp.pAtk = true;
        inp.attackHeld = true;
        _releaseAt = now + 0.07;
        _nextTap = now + math.max(0.22, 1 / tapRate + _rng.gauss() * 0.07);
      }
    }
  }
}

/// Plays a whole fight with the average-player bot at the tuned 1/60 s step
/// and returns it when the finisher begins (or at [maxSeconds]). Cheap enough
/// to run hundreds of times in a test.
BrawlFight playBrawlWithBot(
  BrawlFight fight, {
  int botSeed = 1,
  double tapRate = 2.5,
  double maxSeconds = 900,
  bool untilDone = false,
}) {
  final bot = BrawlBot(fight, seed: botSeed, tapRate: tapRate);
  while (fight.clock < maxSeconds) {
    if (!untilDone && fight.phase == BrawlPhase.finisher) break;
    if (fight.phase == BrawlPhase.done) break;
    bot.drive();
    fight.step(BrawlTune.step, bot.input);
    fight.events.clear();
  }
  return fight;
}
