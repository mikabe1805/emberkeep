// The weekend brawl as one route over the house: the versus screen, the fight,
// and the victory. The dock and the HUD step away because the route covers
// them; Done (or the back arrow) returns to the house.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../audio.dart' show Sfx;
import '../../clock.dart';
import '../../engine.dart';
import '../brawl_loot.dart';
import '../core/brawl_core.dart';
import '../weekly_training.dart' show WeeklyMonster;
import 'brawl_feel.dart';
import 'brawl_fight_screen.dart';
import 'brawl_setup.dart';
import 'brawl_versus_screen.dart';
import 'brawl_victory_screen.dart';

/// Opens the weekend brawl over the house. [monster] and [now] let a test or a
/// render choose the day and the monster; nothing in the app passes them.
Future<void> openBrawl(
  BuildContext context, {
  required GameState state,
  required VoidCallback onPersist,
  DateTime? now,
  WeeklyMonster? monster,
  BrawlFeel? feel,
  int? seed,
  double? hpMax,
}) {
  final at = now ?? Clock.now();
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, _, _) => BrawlFlowScreen(
        state: state,
        onPersist: onPersist,
        now: at,
        monster: monster,
        feel: feel,
        seed: seed,
        hpMax: hpMax,
      ),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

enum BrawlStage { versus, fight, victory }

class BrawlFlowScreen extends StatefulWidget {
  const BrawlFlowScreen({
    super.key,
    required this.state,
    required this.onPersist,
    required this.now,
    this.monster,
    this.feel,
    this.seed,
    this.hpMax,
    this.startAt = BrawlStage.versus,
  });

  final GameState state;
  final VoidCallback onPersist;
  final DateTime now;
  final WeeklyMonster? monster;
  final BrawlFeel? feel;
  final int? seed;
  final double? hpMax;
  final BrawlStage startAt;

  @override
  State<BrawlFlowScreen> createState() => BrawlFlowScreenState();
}

class BrawlFlowScreenState extends State<BrawlFlowScreen> {
  late BrawlSetup _setup;
  BrawlStage _stage = BrawlStage.versus;
  int _round = 0;
  BrawlResult? _result;
  BrawlLoot? _earned;
  BrawlLoot? _kept;
  final math.Random _rnd = math.Random();

  BrawlStage get stage => _stage;
  BrawlResult? get result => _result;
  BrawlLoot? get earned => _earned;

  bool get _reduce =>
      widget.state.reduceMotion ||
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  BrawlFeel? _cachedFeel;
  BrawlFeel get _feel =>
      _cachedFeel ??= widget.feel ?? AppBrawlFeel(reduceMotion: _reduce);

  @override
  void initState() {
    super.initState();
    _setup = BrawlSetup.fromState(
      widget.state,
      now: widget.now,
      monster: widget.monster,
    );
    _stage = widget.startAt;
  }

  int _nextSeed() =>
      widget.seed != null ? widget.seed! + _round : _rnd.nextInt(0x3fffffff);

  void _setEasy(bool value) {
    widget.state.setBrawlEasy(value);
    widget.onPersist();
    setState(() {});
  }

  void _setSound(bool value) {
    widget.state.setSound(value);
    Sfx.instance.soundEnabled = value;
    widget.onPersist();
    setState(() {});
  }

  void _fight() => setState(() {
    _round++;
    _setup = BrawlSetup.fromState(
      widget.state,
      now: widget.now,
      monster: widget.monster,
    );
    _stage = BrawlStage.fight;
  });

  void _finished(BrawlResult result, BrawlFight fight) {
    final earned = widget.state.recordBrawlWin(
      monster: result.monster,
      chest: result.chest,
      loot: result.loot,
      seconds: result.seconds,
      now: widget.now,
    );
    if (earned != null) widget.onPersist();
    setState(() {
      _result = result;
      _earned = earned;
      _kept = earned ?? widget.state.brawlLootThisWeek(widget.now);
      _stage = BrawlStage.victory;
    });
  }

  void _leave() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final Widget page = switch (_stage) {
      BrawlStage.versus => BrawlVersusScreen(
        key: const ValueKey('brawl-stage-versus'),
        setup: _setup,
        easy: widget.state.brawlEasy,
        onEasyChanged: _setEasy,
        onFight: _fight,
        onBack: _leave,
        reduceMotion: _reduce,
      ),
      BrawlStage.fight => BrawlFightScreen(
        key: ValueKey('brawl-stage-fight-$_round'),
        config: _setup.toConfig(
          easy: widget.state.brawlEasy,
          seed: _nextSeed(),
        ),
        feel: _feel,
        reduceMotion: _reduce,
        soundOn: widget.state.soundEnabled,
        onSoundChanged: _setSound,
        hpMax: widget.hpMax,
        onFinished: _finished,
        onQuit: () => setState(() => _stage = BrawlStage.versus),
      ),
      BrawlStage.victory => BrawlVictoryScreen(
        key: const ValueKey('brawl-stage-victory'),
        result: _result!,
        earned: _earned,
        keptThisWeek: _kept,
        feel: _feel,
        reduceMotion: _reduce,
        onDone: _leave,
        onAgain: _fight,
      ),
    };
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: const Color(0xFF130B07),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: page,
        ),
      ),
    );
  }
}
