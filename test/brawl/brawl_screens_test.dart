// The versus and victory screens, and the flow that joins them to the fight:
// the versus card is read from the real stats and this week's real training,
// the victory shows the chest by speed and which stats did the work, loot is
// saved once a weekend and replays are practice, and both screens hold up at
// 130% and 200% text with words for a screen reader.
import 'package:emberkeep/audio.dart';
import 'package:emberkeep/brawl/brawl_abilities.dart';
import 'package:emberkeep/brawl/brawl_loot.dart';
import 'package:emberkeep/brawl/core/brawl_core.dart';
import 'package:emberkeep/brawl/ui/brawl_fight_screen.dart';
import 'package:emberkeep/brawl/ui/brawl_flow.dart';
import 'package:emberkeep/brawl/ui/brawl_setup.dart';
import 'package:emberkeep/brawl/ui/brawl_versus_screen.dart';
import 'package:emberkeep/brawl/ui/brawl_victory_screen.dart';
import 'package:emberkeep/brawl/ui/brawl_feel.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'brawl_test_support.dart';
import 'brawl_ui_support.dart';

BrawlResult _result({
  BrawlMonster monster = BrawlMonster.troll,
  Map<BrawlStat, double> training = const {},
  Map<BrawlStat, int>? stats,
  int seed = 5,
}) {
  final fight = createBrawlFight(
    testConfig(monster: monster, training: training, stats: stats, seed: seed),
  );
  playBrawlWithBot(fight, untilDone: true);
  expect(fight.phase, BrawlPhase.done);
  return BrawlResult.of(fight);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    Sfx.instance.soundEnabled = false;
    BrawlDebug.seed = 7;
  });
  tearDown(() {
    Clock.reset();
    BrawlDebug.seed = null;
    BrawlDebug.openAnyDay = false;
    Sfx.instance.soundEnabled = true;
  });

  group('the setup', () {
    test('reads the real stats and this week\'s training from the save', () {
      final state = mikaState();
      Clock.freeze(fogSaturday);
      train(state, fogSaturday, {Stat.str: 3, Stat.intl: 2});
      final setup = setupFor(state, fogSaturday);
      expect(setup.level, 6);
      expect(setup.stats[Stat.dis], 110);
      expect(setup.dayName, 'Saturday');
      expect(setup.weekly.id, 'fog');
      expect(setup.monster, BrawlMonster.fog);
      expect(setup.practice, isFalse);
      final config = setup.toConfig(easy: true, seed: 9);
      expect(config.level, 6);
      expect(config.statOf(BrawlStat.str), 54);
      expect(config.pointsOf(BrawlStat.str), 3);
      expect(config.pointsOf(BrawlStat.intl), 2);
      expect(config.pointsOf(BrawlStat.soc), 0);
      expect(config.monster, BrawlMonster.fog);
      expect(config.easy, isTrue);
      expect(config.seed, 9);
    });

    test('a week\'s training never counts for more than the stat', () {
      final state = mikaState()..stats[Stat.soc] = 2;
      Clock.freeze(fogSaturday);
      train(state, fogSaturday, {Stat.soc: 9});
      expect(setupFor(state, fogSaturday).pointsOf(Stat.soc), 2);
    });

    test('the two weeks name their monsters for the core', () {
      final state = mikaState();
      expect(setupFor(state, trollSaturday).monster, BrawlMonster.troll);
      expect(setupFor(state, fogSaturday).monster, BrawlMonster.fog);
    });
  });

  group('the versus screen', () {
    Future<void> pump(
      WidgetTester tester,
      BrawlSetup setup, {
      double textScale = 1,
      bool easy = false,
      VoidCallback? onFight,
      ValueChanged<bool>? onEasy,
    }) async {
      phone(tester);
      await tester.pumpWidget(
        framed(
          BrawlVersusScreen(
            setup: setup,
            easy: easy,
            onEasyChanged: onEasy ?? (_) {},
            onFight: onFight ?? () {},
            onBack: () {},
            reduceMotion: true,
          ),
          textScale: textScale,
          reduceMotion: true,
        ),
      );
      await tester.pump();
    }

    Finder row(Stat stat) => find.byKey(ValueKey('brawl-stat-${stat.name}'));

    testWidgets('shows the six named stats with this week\'s training', (
      tester,
    ) async {
      final state = mikaState();
      Clock.freeze(trollSaturday);
      train(state, trollSaturday, {Stat.str: 6, Stat.dis: 5, Stat.foc: 1});
      await pump(tester, setupFor(state, trollSaturday));
      for (final stat in Stat.values) {
        expect(
          find.descendant(of: row(stat), matching: find.text(stat.label)),
          findsOneWidget,
          reason: stat.label,
        );
        expect(
          find.descendant(
            of: row(stat),
            matching: find.text('${state.stats[stat]}'),
          ),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: row(Stat.str), matching: find.text('+6 this week')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row(Stat.dis), matching: find.text('+5 this week')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row(Stat.foc), matching: find.text('+1 this week')),
        findsOneWidget,
      );
      // What was not trained says nothing.
      for (final stat in [Stat.vit, Stat.intl, Stat.soc]) {
        expect(
          find.descendant(
            of: row(stat),
            matching: find.textContaining('this week'),
          ),
          findsNothing,
          reason: stat.label,
        );
      }
      expect(find.text('YOUR STATS'), findsOneWidget);
      expect(find.text('LV 6'), findsOneWidget);
    });

    testWidgets('a quiet week lights nothing', (tester) async {
      await pump(tester, setupFor(mikaState(), trollSaturday));
      expect(find.textContaining('+'), findsNothing);
      expect(find.textContaining('+', skipOffstage: false), findsNothing);
      expect(find.textContaining('boost x', skipOffstage: false), findsNothing);
      expect(
        find.textContaining('THIS WEEK', skipOffstage: false),
        findsOneWidget,
        reason: 'only the monster title says it',
      );
    });

    testWidgets('abilities show their tiers and the locked one as a hope', (
      tester,
    ) async {
      final state = mikaState();
      Clock.freeze(trollSaturday);
      train(state, trollSaturday, {Stat.str: 6});
      await pump(tester, setupFor(state, trollSaturday));
      final abilities = find.byKey(const Key('brawl-abilities'));
      await tester.ensureVisible(abilities);
      for (final stat in Stat.values) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('brawl-ability-${stat.name}')),
            matching: find.text(abilityOf(stat).name),
            skipOffstage: false,
          ),
          findsOneWidget,
          reason: stat.label,
        );
      }
      // Social 5 is below the first tier.
      expect(
        find.text(
          'Reach Social 10 to unlock Call a Friend',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(find.text('SOC 5 of 10', skipOffstage: false), findsOneWidget);
      // Strength 54 is tier 2.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('brawl-ability-str')),
          matching: find.text('Tier 2: A fourth hit in your combo'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      // This week's training shows as a boost on the trained ability only.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('brawl-ability-str')),
          matching: find.text('+6 THIS WEEK'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('boost x', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('the monster card names the weakness for each week', (
      tester,
    ) async {
      await pump(tester, setupFor(mikaState(), trollSaturday));
      expect(
        find.text('Weak to Strength', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Couch Troll'), findsOneWidget);
      await pump(tester, setupFor(mikaState(), fogSaturday));
      expect(
        find.text('Weak to Intellect', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('The Fog'), findsOneWidget);
      expect(find.text('WEAK SPOT', skipOffstage: false), findsOneWidget);
    });

    testWidgets('FIGHT! fights, and Easy mode is a switch', (tester) async {
      var fights = 0;
      bool? easy;
      await pump(
        tester,
        setupFor(mikaState(), fogSaturday),
        onFight: () => fights++,
        onEasy: (v) => easy = v,
      );
      await tester.tap(find.byKey(const Key('brawl-fight')));
      expect(fights, 1);
      await tester.scrollUntilVisible(
        find.byKey(const Key('brawl-easy')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('brawl-easy-switch')));
      await tester.pump();
      expect(easy, isTrue);
    });

    testWidgets('a practice weekend says so', (tester) async {
      final state = mikaState();
      Clock.freeze(fogSaturday);
      state.recordBrawlWin(
        monster: BrawlMonster.fog,
        chest: BrawlChest.swift,
        loot: 'Cloud Lamp',
        seconds: 20,
        now: fogSaturday,
      );
      await pump(tester, setupFor(state, fogSaturday));
      expect(find.text('SATURDAY PRACTICE'), findsOneWidget);
      expect(find.textContaining('for practice'), findsOneWidget);
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('holds at ${(scale * 100).round()}% text', (tester) async {
        final state = mikaState();
        Clock.freeze(fogSaturday);
        train(state, fogSaturday, {for (final s in Stat.values) s: 4});
        await pump(tester, setupFor(state, fogSaturday), textScale: scale);
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byKey(const Key('brawl-versus-scroll')),
          const Offset(0, -3000),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('brawl-fight')), findsOneWidget);
      });
    }

    testWidgets('has words for a screen reader and 44 pt targets', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final state = mikaState();
      Clock.freeze(fogSaturday);
      train(state, fogSaturday, {Stat.intl: 3});
      await pump(tester, setupFor(state, fogSaturday));
      expect(find.bySemanticsLabel('Back to the house'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Fight')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'^Intellect 30, plus 3 this week\.')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Social 5\. Reach Social 10 to unlock')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Weak to Intellect.'), findsOneWidget);
      for (final key in ['brawl-versus-back', 'brawl-fight']) {
        final size = tester.getSize(find.byKey(Key(key)));
        expect(size.width, greaterThanOrEqualTo(44), reason: key);
        expect(size.height, greaterThanOrEqualTo(44), reason: key);
      }
      handle.dispose();
    });
  });

  group('the victory screen', () {
    Future<void> pump(
      WidgetTester tester,
      BrawlResult result, {
      BrawlLoot? earned,
      BrawlLoot? kept,
      double textScale = 1,
      VoidCallback? onDone,
      VoidCallback? onAgain,
    }) async {
      phone(tester);
      await tester.pumpWidget(
        framed(
          BrawlVictoryScreen(
            result: result,
            earned: earned,
            keptThisWeek: kept,
            onDone: onDone ?? () {},
            onAgain: onAgain ?? () {},
            reduceMotion: true,
          ),
          textScale: textScale,
          reduceMotion: true,
        ),
      );
      await tester.pump();
    }

    BrawlLoot lootFor(BrawlResult r) => BrawlLoot(
      week: brawlWeekKey(trollSaturday),
      monster: r.monster,
      chest: r.chest,
      loot: r.loot,
      seconds: r.seconds,
      at: trollSaturday,
    );

    testWidgets('shows the time, the chest, the loot and the breakdown', (
      tester,
    ) async {
      final result = _result(training: {BrawlStat.str: 8, BrawlStat.intl: 5});
      await pump(tester, result, earned: lootFor(result));
      expect(find.text('K.O.'), findsOneWidget);
      expect(find.text(result.finisherLine), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('brawl-victory-time'))).data,
        brawlFormatTime(result.seconds),
      );
      expect(find.byKey(const Key('brawl-chest-card')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('brawl-loot-name'))).data,
        result.loot,
      );
      expect(find.text('for your house'), findsOneWidget);
      expect(find.byKey(const Key('brawl-practice-card')), findsNothing);
      // The breakdown names a move and what in your week it stands for, and
      // the training this week glows on the rows it fed.
      for (final row in result.rows) {
        final words = brawlSourceWords(row.source);
        expect(
          find.textContaining(words.label, skipOffstage: false),
          findsWidgets,
          reason: words.label,
        );
      }
      expect(
        find.textContaining('+8 this week', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.textContaining('+5 this week', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('WHAT DID THE WORK', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('the credit line names what did the most', (tester) async {
      // Plain combos for a level 1 fighter with nothing unlocked.
      final plain = _result(stats: allStats(0), training: const {});
      expect(
        brawlCreditLine(plain),
        'Your steady combos did most of the work.',
      );
      final trained = _result(
        monster: BrawlMonster.fog,
        training: {BrawlStat.intl: 12},
      );
      final top = trained.rows.first;
      expect(top.source, BrawlDamageSource.spell);
      expect(
        brawlCreditLine(trained),
        'This week’s reading did most of the work.',
      );
      await pump(tester, trained, earned: lootFor(trained));
      expect(find.byKey(const Key('brawl-credit-line')), findsOneWidget);
    });

    testWidgets('practice shows no chest and says why', (tester) async {
      final result = _result();
      final kept = lootFor(result);
      await pump(tester, result, kept: kept);
      expect(find.byKey(const Key('brawl-practice-card')), findsOneWidget);
      expect(find.byKey(const Key('brawl-chest-card')), findsNothing);
      expect(find.textContaining('already yours'), findsOneWidget);
      expect(find.textContaining(kept.loot), findsOneWidget);
    });

    testWidgets('Done and Fight again do what they say', (tester) async {
      var done = 0, again = 0;
      final result = _result();
      await pump(
        tester,
        result,
        earned: lootFor(result),
        onDone: () => done++,
        onAgain: () => again++,
      );
      await tester.tap(find.byKey(const Key('brawl-done')));
      await tester.tap(find.byKey(const Key('brawl-again')));
      expect(done, 1);
      expect(again, 1);
    });

    testWidgets('a perfect fight says so', (tester) async {
      final result = _result();
      await pump(tester, result);
      expect(
        find.text(result.perfect ? 'K.O. and PERFECT' : 'K.O.'),
        findsOneWidget,
      );
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('holds at ${(scale * 100).round()}% text', (tester) async {
        final result = _result(
          training: {for (final s in BrawlStat.values) s: 6},
        );
        await pump(tester, result, earned: lootFor(result), textScale: scale);
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byKey(const Key('brawl-victory-scroll')),
          const Offset(0, -4000),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await pump(tester, result, kept: lootFor(result), textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('has words for a screen reader and 44 pt targets', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final result = _result(training: {BrawlStat.str: 6});
      await pump(tester, result, earned: lootFor(result));
      expect(
        find.bySemanticsLabel(RegExp(r'^Fight time \d+:\d\d$')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^(Swift|Steady|Patient) chest\. ')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Done\. Back to the house')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Fight again, for practice')),
        findsOneWidget,
      );
      for (final key in ['brawl-done', 'brawl-again']) {
        final size = tester.getSize(find.byKey(Key(key)));
        expect(size.height, greaterThanOrEqualTo(44), reason: key);
      }
      handle.dispose();
    });
  });

  group('the flow', () {
    late GameState state;
    var persists = 0;

    Future<void> openFlow(
      WidgetTester tester, {
      DateTime? at,
      BrawlStage startAt = BrawlStage.versus,
    }) async {
      phone(tester);
      final when = at ?? fogSaturday;
      Clock.freeze(when);
      await tester.pumpWidget(
        framed(
          BrawlFlowScreen(
            state: state,
            onPersist: () => persists++,
            now: when,
            feel: const SilentFeel(),
            hpMax: 700,
            startAt: startAt,
          ),
          reduceMotion: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }

    BrawlFlowScreenState flow(WidgetTester tester) =>
        tester.state<BrawlFlowScreenState>(find.byType(BrawlFlowScreen));

    Future<void> fightToVictory(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('brawl-fight')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final fight = tester.state<BrawlFightScreenState>(
        find.byType(BrawlFightScreen),
      );
      botAt(fight);
      await pumpUntil(
        tester,
        () => flow(tester).stage == BrawlStage.victory,
        maxSeconds: 90,
      );
      await tester.pump(const Duration(milliseconds: 400));
    }

    setUp(() {
      state = mikaState();
      persists = 0;
    });

    testWidgets('versus, fight, victory: a scripted fight won with fake time, '
        'and the weekend\'s loot is kept once', (tester) async {
      Clock.freeze(fogSaturday);
      train(state, fogSaturday, {Stat.intl: 6, Stat.str: 4});
      await openFlow(tester);
      expect(flow(tester).stage, BrawlStage.versus);
      await fightToVictory(tester);
      expect(flow(tester).stage, BrawlStage.victory);
      final first = flow(tester).earned;
      expect(
        first,
        isNotNull,
        reason: 'the first win of the week earns a chest',
      );
      expect(first!.monster, BrawlMonster.fog);
      expect(state.brawlLoot, hasLength(1));
      expect(state.brawlLoot.single.loot, first.loot);
      expect(persists, greaterThan(0));
      expect(find.byKey(const Key('brawl-chest-card')), findsOneWidget);
      expect(find.byKey(const Key('brawl-practice-card')), findsNothing);

      // Fight again: practice, and nothing more is kept.
      persists = 0;
      await tester.tap(find.byKey(const Key('brawl-again')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final fight = tester.state<BrawlFightScreenState>(
        find.byType(BrawlFightScreen),
      );
      botAt(fight, seed: 4);
      await pumpUntil(
        tester,
        () => flow(tester).stage == BrawlStage.victory,
        maxSeconds: 90,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(flow(tester).earned, isNull);
      expect(state.brawlLoot, hasLength(1), reason: 'replays are practice');
      expect(persists, 0);
      expect(find.byKey(const Key('brawl-practice-card')), findsOneWidget);
      expect(find.byKey(const Key('brawl-chest-card')), findsNothing);
      expect(find.textContaining(first.loot), findsWidgets);
    });

    testWidgets('Easy mode is remembered from the versus screen', (
      tester,
    ) async {
      await openFlow(tester);
      expect(state.brawlEasy, isFalse);
      await tester.scrollUntilVisible(
        find.byKey(const Key('brawl-easy')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('brawl-easy-switch')));
      await tester.pump();
      expect(state.brawlEasy, isTrue);
      expect(persists, 1);
      await tester.tap(find.byKey(const Key('brawl-fight')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final fight = tester.state<BrawlFightScreenState>(
        find.byType(BrawlFightScreen),
      );
      expect(fight.fight.easy, isTrue);
      expect(fight.scene!.easy, isTrue);
    });

    testWidgets('leaving the fight from the pause sheet goes back to versus', (
      tester,
    ) async {
      await openFlow(tester);
      await tester.tap(find.byKey(const Key('brawl-fight')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('brawl-pause')));
      await tester.pump();
      expect(find.byKey(const Key('brawl-paused')), findsOneWidget);
      await tester.tap(find.byKey(const Key('brawl-quit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(flow(tester).stage, BrawlStage.versus);
      expect(state.brawlLoot, isEmpty);
    });
  });
}
