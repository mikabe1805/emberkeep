// The fight on screen: a painted stage that only repaints, two thumbs' worth
// of controls with words for a screen reader, Easy mode (tap anywhere),
// Reduce Motion, pause, and the sounds and taps the fight makes (muted by the
// app's sound toggle, softened by Reduce Motion).
import 'package:emberkeep/audio.dart';
import 'package:emberkeep/brawl/core/brawl_core.dart';
import 'package:emberkeep/brawl/ui/brawl_feel.dart';
import 'package:emberkeep/brawl/ui/brawl_fight_screen.dart';
import 'package:emberkeep/brawl/ui/brawl_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'brawl_test_support.dart';
import 'brawl_ui_support.dart';

// A realistic week: about eight quests.
const _modestWeek = {
  BrawlStat.str: 3.0,
  BrawlStat.intl: 3.0,
  BrawlStat.dis: 2.0,
};

const _someWeek = {
  BrawlStat.str: 6.0,
  BrawlStat.vit: 3.0,
  BrawlStat.intl: 4.0,
  BrawlStat.foc: 3.0,
  BrawlStat.dis: 5.0,
};

const _bigWeek = {
  BrawlStat.str: 12.0,
  BrawlStat.vit: 12.0,
  BrawlStat.intl: 12.0,
  BrawlStat.foc: 12.0,
  BrawlStat.soc: 5.0,
  BrawlStat.dis: 12.0,
};

BrawlScene _scene(
  BrawlFight fight, {
  BrawlFeel feel = const SilentFeel(),
  bool reduceMotion = false,
}) => BrawlScene(
  core: fight,
  layout: BrawlLayout(const Size(393, 852), top: 47, bottom: 34),
  feel: feel,
  reduceMotion: reduceMotion,
);

/// Plays a whole fight through a scene with the bot, 60 steps a second.
({BrawlScene scene, double maxZoom, int frames}) _playScene(
  BrawlFight fight, {
  BrawlFeel feel = const SilentFeel(),
  bool reduceMotion = false,
  int botSeed = 3,
}) {
  final scene = _scene(fight, feel: feel, reduceMotion: reduceMotion);
  final bot = BrawlBot(fight, seed: botSeed);
  var maxZoom = 1.0;
  var frames = 0;
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
  var victory = false;
  scene.onVictory = () => victory = true;
  while (!victory && frames < 60 * 300) {
    scene.tick(1 / 60);
    maxZoom = maxZoom < scene.cam.zoom ? scene.cam.zoom : maxZoom;
    frames++;
  }
  expect(victory, isTrue, reason: 'the fight ends with the victory');
  return (scene: scene, maxZoom: maxZoom, frames: frames);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    Sfx.instance.soundEnabled = false;
  });
  tearDown(() {
    Sfx.instance.soundEnabled = true;
    Sfx.instance.debugOnPlay = null;
    Sfx.instance.debugOnPlayAsset = null;
    Sfx.instance.debugBypassPlayback = false;
  });

  group('the scene, driven with fake time', () {
    test('a scripted fight is won with the bot and opens the victory', () {
      final fight = createBrawlFight(
        testConfig(training: _someWeek, seed: 11, hpMax: 900),
      );
      final run = _playScene(fight);
      expect(fight.phase, BrawlPhase.done);
      expect(fight.m.hp, 0);
      expect(run.scene.announcerText.value, isNotEmpty);
      expect(BrawlResult.of(fight).rows, isNotEmpty);
    });

    test('the announcer says ROUND 1, FIGHT!, FINISH IT! and K.O.', () {
      final fight = createBrawlFight(
        testConfig(training: _someWeek, seed: 12, hpMax: 900),
      );
      final said = <String>[];
      final scene = _scene(fight);
      scene.announcerText.addListener(
        () => said.add(scene.announcerText.value),
      );
      final bot = BrawlBot(fight, seed: 3);
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
      var frames = 0;
      while (fight.phase != BrawlPhase.done && frames < 60 * 300) {
        scene.tick(1 / 60);
        frames++;
      }
      expect(
        said,
        containsAllInOrder(['ROUND 1', 'FIGHT!', 'FINISH IT!', 'K.O.']),
      );
    });

    test('Reduce Motion keeps the camera calm through the finisher', () {
      final calm = _playScene(
        createBrawlFight(testConfig(training: _bigWeek, seed: 13, hpMax: 900)),
        reduceMotion: true,
      );
      final lively = _playScene(
        createBrawlFight(testConfig(training: _bigWeek, seed: 13, hpMax: 900)),
      );
      expect(calm.maxZoom, lessThan(1.4));
      expect(lively.maxZoom, greaterThan(1.45));
    });

    test('the week\'s boost is made visible: aura and glows grow with it', () {
      final quiet = _scene(createBrawlFight(testConfig(seed: 1, hpMax: 900)));
      final some = _scene(
        createBrawlFight(
          testConfig(training: _modestWeek, seed: 1, hpMax: 900),
        ),
      );
      final big = _scene(
        createBrawlFight(testConfig(training: _bigWeek, seed: 1, hpMax: 900)),
      );
      expect(quiet.trainK, 0);
      expect(some.trainK, greaterThan(0.2));
      expect(some.trainK, lessThan(1));
      expect(big.trainK, greaterThan(some.trainK));
      expect(big.trainK, 1);
      // Trained stats glow; untrained ones do not.
      expect(quiet.boostK(BrawlStat.str), 0);
      expect(some.boostK(BrawlStat.str), greaterThan(0));
      expect(some.boostK(BrawlStat.soc), 0);
      expect(
        big.boostK(BrawlStat.str),
        greaterThan(some.boostK(BrawlStat.str)),
      );
      for (final s in [quiet, some, big]) {
        s.dispose();
      }
    });

    test('every sound the fight asks for is one the feel knows', () {
      final fight = createBrawlFight(
        testConfig(training: _bigWeek, seed: 14, hpMax: 1200),
      );
      final feel = RecordingFeel();
      _playScene(fight, feel: feel);
      for (final sound in [
        BrawlSound.round,
        BrawlSound.fight,
        BrawlSound.finishIt,
        BrawlSound.ko,
        BrawlSound.koRise,
      ]) {
        expect(feel.heard, contains(sound), reason: '$sound');
      }
      expect(
        feel.heard.any(
          (s) =>
              s == BrawlSound.hit ||
              s == BrawlSound.heavy ||
              s == BrawlSound.crit ||
              s == BrawlSound.spellHit,
        ),
        isTrue,
        reason: 'the hits are heard',
      );
    });
  });

  group('sounds and taps', () {
    test('nothing is heard while the app\'s sound is off', () {
      final heard = <String>[];
      Sfx.instance
        ..debugBypassPlayback = true
        ..debugOnPlay = heard.add
        ..soundEnabled = false;
      final feel = AppBrawlFeel();
      for (final s in BrawlSound.values) {
        feel.play(s, k: 5, power: 700);
      }
      expect(heard, isEmpty);
    });

    test('hits use the soft hand\'s materials, crits and the finisher the '
        'class chime\'s pitches', () {
      final assets = <String>[];
      Sfx.instance
        ..debugBypassPlayback = true
        ..debugOnPlayAsset = assets.add
        ..soundEnabled = true;
      final feel = AppBrawlFeel(reduceMotion: true);
      feel.play(BrawlSound.hit, k: 3);
      expect(assets.last, startsWith('room/'));
      expect(assets.last, isNot(contains('class_chime')));
      assets.clear();
      feel.play(BrawlSound.crit, k: 8);
      expect(assets.single, matches(RegExp(r'^room/class_chime/[1-6]$')));
      assets.clear();
      feel.play(BrawlSound.finishIt);
      expect(assets.single, 'room/class_chime/5');
      assets.clear();
      feel.play(BrawlSound.doubleCrit);
      expect(assets.single, 'room/class_chime/5');
    });

    testWidgets('Reduce Motion leaves plain hits without a tap', (
      tester,
    ) async {
      final taps = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            taps.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      Sfx.instance.soundEnabled = false;
      AppBrawlFeel(reduceMotion: true).play(BrawlSound.hit, k: 2);
      expect(taps, isEmpty);
      AppBrawlFeel().play(BrawlSound.hit, k: 2);
      expect(taps, ['HapticFeedbackType.selectionClick']);
    });
  });

  group('the screen', () {
    late BrawlFightScreenState state;
    late RecordingFeel feel;

    Future<void> open(
      WidgetTester tester, {
      bool easy = false,
      bool reduceMotion = false,
      Map<BrawlStat, double> training = _someWeek,
      Map<BrawlStat, int>? stats,
      double hpMax = 1e7,
      double textScale = 1,
    }) async {
      phone(tester);
      feel = RecordingFeel();
      await tester.pumpWidget(
        framed(
          BrawlFightScreen(
            config: testConfig(
              training: training,
              stats: stats,
              easy: easy,
              seed: 21,
            ),
            feel: feel,
            reduceMotion: reduceMotion,
            hpMax: hpMax,
            onFinished: (_, _) {},
            onQuit: () {},
          ),
          reduceMotion: reduceMotion,
          textScale: textScale,
        ),
      );
      await tester.pump();
      state = tester.state<BrawlFightScreenState>(
        find.byType(BrawlFightScreen),
      );
    }

    Future<void> intoTheFight(WidgetTester tester) => pumpUntil(
      tester,
      () => state.fight.phase == BrawlPhase.fight,
      maxSeconds: 5,
    );

    Offset at(BrawlCircle c) => Offset(
      c.x * state.scene!.layout.scale,
      c.y * state.scene!.layout.scale,
    );

    testWidgets('a frame repaints; it does not rebuild the widget tree', (
      tester,
    ) async {
      await open(tester);
      await intoTheFight(tester);
      final builds = state.buildCount;
      final frames = state.scene!.frames;
      botAt(state);
      await pumpUntil(tester, () => state.fight.t > 4, maxSeconds: 10);
      expect(state.scene!.frames - frames, greaterThan(150));
      expect(
        state.buildCount,
        builds,
        reason: 'the screen was not rebuilt while the fight ran',
      );
    });

    testWidgets('every control has words, locked ones say how to unlock', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      await intoTheFight(tester);
      expect(
        find.bySemanticsLabel(RegExp(r'^Attack\. Tap for a combo')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Spell Bolt, (ready|recharging)$')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Locked. Reach Social 10 to unlock Call a Friend',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp(r'^Super, ')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Move pad\.')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Pause')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Sound o')), findsOneWidget);
      // The announcer and both health bars are spoken too.
      expect(find.bySemanticsLabel('FIGHT!'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp(r'^Couch Troll health \d+ percent\. Your health'),
        ),
        findsOneWidget,
      );
      // Pause and sound are real 44 pt targets.
      for (final key in ['brawl-pause', 'brawl-sound']) {
        final size = tester.getSize(find.byKey(Key(key)));
        expect(size.width, greaterThanOrEqualTo(44), reason: key);
        expect(size.height, greaterThanOrEqualTo(44), reason: key);
      }
      handle.dispose();
    });

    testWidgets('a pressed locked ability says what it takes', (tester) async {
      await open(tester);
      await intoTheFight(tester);
      await tester.tapAt(at(state.scene!.layout.friend));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Reach Social 10 to unlock Call a Friend'),
        findsOneWidget,
      );
      expect(feel.heard, contains(BrawlSound.locked));
    });

    testWidgets('the left thumb slides to move and swipes up to jump', (
      tester,
    ) async {
      await open(tester);
      await intoTheFight(tester);
      final x0 = state.fight.f.x;
      final pad = at(state.scene!.layout.pad);
      final g = await tester.startGesture(pad);
      await g.moveBy(const Offset(40, 0));
      await pumpUntil(tester, (() => state.fight.f.x > x0 + 20), maxSeconds: 2);
      expect(state.fight.f.x, greaterThan(x0 + 20));
      await g.moveBy(const Offset(0, -50));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.fight.f.h, greaterThan(0), reason: 'the swipe jumped');
      await g.up();
      await tester.pump(const Duration(milliseconds: 600));
      expect(state.scene!.touch.padMove, 0);
    });

    testWidgets('a tap on ATTACK combos and a hold charges Power Slam', (
      tester,
    ) async {
      await open(tester);
      await intoTheFight(tester);
      // Walk up to the monster so swings land.
      final pad = at(state.scene!.layout.pad);
      final walk = await tester.startGesture(pad);
      await walk.moveBy(const Offset(40, 0));
      await pumpUntil(
        tester,
        () => (state.fight.frontAt(34) - 30 - state.fight.f.x).abs() < 30,
        maxSeconds: 4,
      );
      await walk.up();
      final attack = at(state.scene!.layout.attack);
      await tester.tapAt(attack);
      await tester.pump(const Duration(milliseconds: 200));
      expect(state.fight.stats.attacks, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 600));
      final hold = await tester.startGesture(attack);
      await pumpUntil(
        tester,
        () => state.fight.f.state == BrawlFighterState.charge,
        maxSeconds: 1.5,
      );
      expect(state.fight.f.state, BrawlFighterState.charge);
      await hold.up();
      await pumpUntil(tester, () => state.fight.stats.slams > 0, maxSeconds: 2);
      expect(state.fight.stats.slams, 1);
    });

    testWidgets('Easy mode: tap anywhere to attack, no pad on the screen', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await open(tester, easy: true);
      await intoTheFight(tester);
      expect(state.fight.easy, isTrue);
      expect(find.bySemanticsLabel(RegExp(r'^Move pad\.')), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp(r'^Attack\. Tap anywhere')),
        findsOneWidget,
      );
      final before = state.fight.stats.attacks;
      await tester.tapAt(const Offset(120, 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tapAt(const Offset(300, 200));
      await tester.pump(const Duration(milliseconds: 600));
      expect(state.fight.stats.attacks, greaterThan(before));
      expect(state.fight.f.x, greaterThan(108), reason: 'moved in by itself');
      handle.dispose();
    });

    testWidgets('a locked ability is shown locked and nothing fires', (
      tester,
    ) async {
      await open(tester, easy: true);
      await intoTheFight(tester);
      final calls = state.fight.stats.calls;
      await tester.tapAt(at(state.scene!.layout.eFriend));
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.fight.stats.calls, calls);
      expect(
        find.text('Reach Social 10 to unlock Call a Friend'),
        findsOneWidget,
      );
    });

    testWidgets('pause holds the fight and resume carries on', (tester) async {
      await open(tester);
      await intoTheFight(tester);
      await tester.tap(find.byKey(const Key('brawl-pause')));
      await tester.pump();
      expect(find.byKey(const Key('brawl-paused')), findsOneWidget);
      expect(state.paused, isTrue);
      final clock = state.fight.clock;
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(state.fight.clock, clock, reason: 'nothing moves while paused');
      await tester.tap(find.byKey(const Key('brawl-resume')));
      await tester.pump();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(state.fight.clock, greaterThan(clock));
      expect(find.byKey(const Key('brawl-paused')), findsNothing);
    });

    testWidgets('the sound button asks the app to mute', (tester) async {
      phone(tester);
      bool? sound;
      await tester.pumpWidget(
        framed(
          BrawlFightScreen(
            config: testConfig(seed: 3),
            feel: const SilentFeel(),
            onFinished: (_, _) {},
            onQuit: () {},
            onSoundChanged: (v) => sound = v,
            soundOn: true,
            hpMax: 1e7,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('brawl-sound')));
      await tester.pump();
      expect(sound, isFalse);
    });

    testWidgets('Reduce Motion plays the same fight, calmer', (tester) async {
      await open(tester, reduceMotion: true, hpMax: 900);
      await intoTheFight(tester);
      expect(state.scene!.reduceMotion, isTrue);
      botAt(state);
      var maxZoom = 1.0;
      var frames = 0;
      while (state.fight.phase != BrawlPhase.done && frames < 60 * 120) {
        await tester.pump(const Duration(milliseconds: 16));
        final z = state.scene!.cam.zoom;
        maxZoom = z > maxZoom ? z : maxZoom;
        frames++;
      }
      expect(state.fight.phase, BrawlPhase.done);
      expect(maxZoom, lessThan(1.4));
      expect(tester.takeException(), isNull);
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('the pause sheet holds at ${(scale * 100).round()}% text', (
        tester,
      ) async {
        await open(tester, textScale: scale);
        await intoTheFight(tester);
        await tester.tap(find.byKey(const Key('brawl-pause')));
        await tester.pump();
        expect(find.byKey(const Key('brawl-quit')), findsOneWidget);
        expect(tester.takeException(), isNull);
        final size = tester.getSize(find.byKey(const Key('brawl-quit')));
        expect(size.height, greaterThanOrEqualTo(44));
      });
    }
  });
}
