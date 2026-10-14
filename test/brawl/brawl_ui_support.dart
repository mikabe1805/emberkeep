// Shared by the brawl's screen tests: a save with Mika's numbers, a phone
// frame, and a bot at the controls of a fight on screen.
import 'package:emberkeep/audio.dart';
import 'package:emberkeep/brawl/core/brawl_core.dart';
import 'package:emberkeep/brawl/ui/brawl_fight_screen.dart';
import 'package:emberkeep/brawl/ui/brawl_setup.dart';
import 'package:emberkeep/brawl/weekly_training.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Saturday 10 October 2026, late morning: a Fog week (ISO week 41).
final DateTime fogSaturday = DateTime(2026, 10, 10, 11);

/// Saturday 3 October 2026: a Couch Troll week (ISO week 40).
final DateTime trollSaturday = DateTime(2026, 10, 3, 11);

/// Wednesday 7 October 2026.
final DateTime wednesday = DateTime(2026, 10, 7, 11);

/// Mika's numbers (LV 6): STR 54, VIT 90, INT 30, FOC 23, SOC 5, DIS 110.
GameState mikaState({int level = 6}) => GameState()
  ..onboarded = true
  ..reduceMotion = true
  ..soundEnabled = false
  ..level = level
  ..stats.addAll({
    Stat.str: 54,
    Stat.vit: 90,
    Stat.intl: 30,
    Stat.foc: 23,
    Stat.soc: 5,
    Stat.dis: 110,
  });

/// Finishes quests this week for [points] stats (the clock must be frozen
/// somewhere in the week): [count] each.
void train(GameState state, DateTime now, Map<Stat, int> points) {
  final monday = trainingWeekStart(now);
  var n = 0;
  points.forEach((stat, count) {
    for (var i = 0; i < count; i++) {
      state.markTraining(stat, at: monday.add(Duration(hours: 6 + n++)));
    }
  });
}

BrawlSetup setupFor(GameState state, DateTime now) {
  Clock.freeze(now);
  return BrawlSetup.fromState(state, now: now);
}

/// A phone, 393 x 852 points.
void phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(393, 852);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// A material app at 393 x 852 with the given text scale.
Widget framed(
  Widget child, {
  double textScale = 1,
  bool reduceMotion = false,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(393, 852),
      textScaler: TextScaler.linear(textScale),
      disableAnimations: reduceMotion,
      padding: const EdgeInsets.only(top: 47, bottom: 34),
    ),
    child: Material(color: Colors.black, child: child),
  ),
);

void silenceSound() {
  Sfx.instance.soundEnabled = false;
}

/// Hands the fight on screen to the average-player bot (through the scene's
/// own input, the way a thumb would).
void botAt(BrawlFightScreenState state, {int seed = 3}) {
  final scene = state.scene!;
  final bot = BrawlBot(state.fight, seed: seed);
  scene.beforeStep = () {
    bot.drive();
    final b = bot.input;
    scene.inp
      ..moveX = b.moveX
      ..attackHeld = b.attackHeld
      ..jumpHeld = b.jumpHeld
      ..pAtk = scene.inp.pAtk || b.pAtk
      ..pJump = scene.inp.pJump || b.pJump
      ..pSpell = scene.inp.pSpell || b.pSpell
      ..pFriend = scene.inp.pFriend || b.pFriend
      ..pSuper = scene.inp.pSuper || b.pSuper
      ..pFinish = scene.inp.pFinish || b.pFinish;
    b
      ..pAtk = false
      ..pJump = false
      ..pSpell = false
      ..pFriend = false
      ..pSuper = false
      ..pFinish = false;
  };
}

/// Pumps 60 fps frames (fake time) until [done] or [maxSeconds].
Future<int> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  double maxSeconds = 120,
}) async {
  var frames = 0;
  while (!done() && frames < maxSeconds * 60) {
    await tester.pump(const Duration(milliseconds: 16));
    frames++;
  }
  return frames;
}
