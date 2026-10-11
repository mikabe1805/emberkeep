import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/goal_planner.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/goal_workshop.dart';
import 'package:emberkeep/screens/goals.dart';
import 'package:emberkeep/screens/quick_goal_composer.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/goals_room_support.dart';

GoalPlan _plan(String title, Stat stat) => GoalPlanner.draft(
  GoalPlanInput(
    title: title,
    stat: stat,
    type: GoalRouteType.finish,
    outcome: '$title has visible proof',
    startingPoint: 'The first useful piece is not done yet',
    successProof: 'One concrete result exists',
    timeBudgetMinutes: 15,
    obstacleCue: 'the whole thing feels too large',
    now: Clock.now(),
  ),
);

Goal _goal(String title, Stat stat, {bool plan = true}) => Goal(
  title: title,
  stat: stat,
  kind: GoalKind.achieve,
  target: 4,
  plan: plan ? _plan(title, stat) : null,
  openingSeen: true,
);

/// A workshop over a [Navigator] so a leave-the-room pop can be seen.
Future<void> _pumpWorkshop(
  WidgetTester tester, {
  required GameState state,
  List<Quest> quests = const [],
  bool startNewGoal = false,
  Goal? shapeGoal,
  GoalWorkshopShape? onShapePlan,
  GoalWorkshopCreate? onCreateGoal,
  GoalWorkshopAction? onOpenGoal,
  Size size = const Size(430, 932),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('test-open-workshop'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GoalWorkshopScreen(
                    state: state,
                    quests: quests,
                    startNewGoal: startNewGoal,
                    shapeGoal: shapeGoal,
                    onOpenGoal: onOpenGoal ?? (_) async {},
                    onShapePlan: onShapePlan ?? (_, _) async {},
                    onCreateGoal: onCreateGoal ?? (_) async {},
                    onFocusGoal: (_) {},
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('test-open-workshop')));
  await tester.pumpAndSettle();
}

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('steward-ask-continue')));
  await tester.pumpAndSettle();
}

Future<void> _answer(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
  await _continue(tester);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    Sfx.instance.soundEnabled = false;
    Clock.freeze(DateTime(2026, 10, 9, 10));
  });
  tearDown(() {
    Sfx.instance.soundEnabled = true;
    Clock.reset();
  });

  group('workshop home', () {
    testWidgets('leads with the goal that most needs the Steward', (
      tester,
    ) async {
      final state = GameState()..reduceMotion = true;
      final onBoard = _goal('On the board', Stat.foc);
      final ready = _goal('Next step ready', Stat.dis);
      final bare = _goal('Needs a plan', Stat.vit, plan: false);
      state.goals.addAll([onBoard, ready, bare]);
      final decision = GoalPlanner.decide(onBoard, const [], Clock.now())!;
      final quests = [GoalPlanner.questFor(onBoard, decision, Clock.now())];
      await _pumpWorkshop(tester, state: state, quests: quests);

      Finder inLead(String text) => find.descendant(
        of: find.byKey(const Key('goal-workshop-lead')),
        matching: find.text(text),
      );
      expect(inLead('Needs a plan'), findsOneWidget);
      expect(inLead('NEEDS A PLAN'), findsOneWidget);
      expect(inLead('Shape a plan'), findsOneWidget);
      // The other two are listed under it, each with its own chip.
      expect(find.text('YOUR OTHER GOALS'), findsOneWidget);
      expect(find.text('NEXT STEP READY'), findsOneWidget);
      expect(find.text('ON YOUR BOARD'), findsOneWidget);
      expect(find.text('Next step ready'), findsOneWidget);
      expect(find.text('On the board'), findsOneWidget);

      // Without a goal that needs a plan, a ready step leads ...
      state.removeGoal(bare);
      await tester.pumpAndSettle();
      expect(inLead('Next step ready'), findsOneWidget);
      expect(inLead('Take the next step'), findsOneWidget);

      // ... and with only a goal on the board, that one leads.
      state.removeGoal(ready);
      await tester.pumpAndSettle();
      expect(inLead('On the board'), findsOneWidget);
      expect(inLead('Open the Quest'), findsOneWidget);
      expect(find.text('YOUR OTHER GOALS'), findsNothing);
    });

    testWidgets('says what the Steward does, in plain words', (tester) async {
      final state = GameState()..reduceMotion = true;
      state.goals.add(_goal('Finish the portfolio', Stat.foc));
      await _pumpWorkshop(tester, state: state);
      expect(
        find.textContaining('turn a goal into a short plan'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Nothing goes on your Quest board'),
        findsOneWidget,
      );
      for (final word in const ['route', 'marker', 'bench', 'cut']) {
        expect(
          find.textContaining(RegExp(word, caseSensitive: false)),
          findsNothing,
          reason: '"$word" is internal vocabulary',
        );
      }
    });

    testWidgets('a finished plan offers what comes next', (tester) async {
      final state = GameState()..reduceMotion = true;
      final goal = _goal('Finish the portfolio', Stat.foc);
      final done = goal.plan!.copyWith(
        steps: [
          for (final step in goal.plan!.steps)
            step.copyWith(
              completions: step.requiredCompletions,
              completedDay: Days.key(Clock.now()),
            ),
        ],
      );
      goal.plan = done;
      expect(done.complete, isTrue);
      state.goals.add(goal);
      GoalPlan? shaped;
      Goal? shapedGoal;
      await _pumpWorkshop(
        tester,
        state: state,
        onShapePlan: (g, plan) async {
          shapedGoal = g;
          shaped = plan;
        },
      );

      expect(find.text('PLAN COMPLETE'), findsOneWidget);
      expect(find.text('Shape what comes next'), findsOneWidget);
      await tester.tap(find.text('Shape what comes next'));
      await tester.pumpAndSettle();

      // The Steward asks about the next plan, without offering the old
      // outcome back as the answer.
      expect(
        find.text('What do you want to be different next?'),
        findsOneWidget,
      );
      final outcome = tester.widget<TextField>(
        find.byKey(const Key('steward-ask-outcome')),
      );
      expect(outcome.controller!.text, isEmpty);
      await _answer(tester, 'steward-ask-outcome', 'A second project page');
      await _continue(tester);
      await _answer(tester, 'steward-ask-starting-point', 'One page exists');
      await _answer(tester, 'steward-ask-proof', 'Two pages are published');
      await _continue(tester);
      await _answer(tester, 'steward-ask-snag', 'I keep polishing');
      await _continue(tester);

      expect(shapedGoal, same(goal));
      expect(shaped, isNotNull);
      expect(shaped!.steps, isNotEmpty);
      expect(shaped!.currentStep, isNotNull);
    });

    testWidgets('the footer asks for a new goal and keeps Talk quiet', (
      tester,
    ) async {
      final state = GameState()..reduceMotion = true;
      state.goals.add(_goal('Finish the portfolio', Stat.foc));
      await _pumpWorkshop(tester, state: state);
      expect(
        find.byKey(const Key('goal-workshop-home-new-goal')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('steward-hidden-card')), findsOneWidget);
      // Talk sits below the new-goal action, as a secondary link.
      expect(
        tester.getTopLeft(find.byKey(const Key('steward-hidden-card'))).dy,
        greaterThan(
          tester
              .getTopLeft(find.byKey(const Key('goal-workshop-home-new-goal')))
              .dy,
        ),
      );
    });
  });

  group('the Steward asks', () {
    testWidgets('a new goal: one question at a time, then the plan', (
      tester,
    ) async {
      final state = GameState()..reduceMotion = true;
      QuickGoalComposerResult? result;
      await _pumpWorkshop(
        tester,
        state: state,
        startNewGoal: true,
        onCreateGoal: (r) async => result = r,
      );

      // One question on screen at a time.
      expect(find.byKey(const Key('steward-ask-name')), findsOneWidget);
      expect(find.byKey(const Key('steward-ask-outcome')), findsNothing);
      expect(find.text('What do you want to work on?'), findsOneWidget);

      // An empty answer is asked for again, kindly, and goes nowhere.
      await _continue(tester);
      expect(find.text('Give this goal a short name.'), findsOneWidget);
      expect(find.byKey(const Key('steward-ask-outcome')), findsNothing);

      await _answer(tester, 'steward-ask-name', 'Learn to cook five dinners');
      expect(find.byKey(const Key('steward-ask-name')), findsNothing);
      await _answer(tester, 'steward-ask-outcome', 'I can make dinner at home');
      expect(find.text('What kind of goal is this?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('steward-ask-type-skill')));
      await tester.pump();
      await _continue(tester);
      expect(
        find.text('Which part of your life does it belong to?'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('steward-ask-stat-vit')));
      await tester.pump();
      await _continue(tester);

      // Back steps through the answers and keeps them.
      await tester.tap(find.byKey(const Key('steward-ask-back')));
      await tester.pumpAndSettle();
      expect(
        find.text('Which part of your life does it belong to?'),
        findsOneWidget,
      );
      await _continue(tester);

      await _answer(tester, 'steward-ask-starting-point', 'Two recipes');
      await _answer(tester, 'steward-ask-proof', 'Five dinners cooked');
      await tester.tap(find.byKey(const ValueKey('steward-ask-minutes-30')));
      await tester.pump();
      await _continue(tester);
      await _answer(tester, 'steward-ask-snag', 'tired after class');
      expect(find.text('Make my plan'), findsOneWidget);
      expect(
        result,
        isNull,
        reason: 'nothing is drafted before the last answer',
      );
      await _continue(tester);

      expect(result, isNotNull);
      expect(result!.exit, QuickGoalComposerExit.create);
      expect(result!.title, 'Learn to cook five dinners');
      expect(result!.stat, Stat.vit);
      final plan = result!.plan!;
      expect(plan.type, GoalRouteType.skill);
      expect(plan.outcome, 'I can make dinner at home');
      expect(plan.timeBudgetMinutes, 30);
      expect(plan.obstacleCue, 'tired after class');
      expect(plan.steps, isNotEmpty);
      expect(state.goals, isEmpty, reason: 'the workshop adds nothing itself');
    });

    testWidgets('a name already on the list is not asked for twice', (
      tester,
    ) async {
      final state = GameState()..reduceMotion = true;
      state.goals.add(_goal('Finish the portfolio', Stat.foc));
      await _pumpWorkshop(tester, state: state, startNewGoal: true);
      await _answer(tester, 'steward-ask-name', '  finish the PORTFOLIO ');
      expect(find.text('That goal is already on your list.'), findsOneWidget);
      expect(find.byKey(const Key('steward-ask-outcome')), findsNothing);
    });

    testWidgets('back from the first question leaves when it was the entry', (
      tester,
    ) async {
      final state = GameState()..reduceMotion = true;
      await _pumpWorkshop(tester, state: state, startNewGoal: true);
      expect(find.byKey(const Key('steward-intake')), findsOneWidget);
      await tester.tap(find.byKey(const Key('goal-workshop-home-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steward-intake')), findsNothing);
      expect(find.byKey(const Key('test-open-workshop')), findsOneWidget);
    });

    testWidgets('back from the first question returns to the home', (
      tester,
    ) async {
      final state = GameState()..reduceMotion = true;
      state.goals.add(_goal('Finish the portfolio', Stat.foc));
      await _pumpWorkshop(tester, state: state);
      await tester.tap(find.byKey(const Key('goal-workshop-home-new-goal')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steward-intake')), findsOneWidget);
      expect(find.byKey(const Key('goal-workshop-home')), findsNothing);

      // System back does the same as the on-screen button.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steward-intake')), findsNothing);
      expect(find.byKey(const Key('goal-workshop-home')), findsOneWidget);
    });

    testWidgets('ready-made plans and doing it by hand are still offered', (
      tester,
    ) async {
      final state = GameState()..reduceMotion = true;
      final exits = <QuickGoalComposerExit>[];
      await _pumpWorkshop(
        tester,
        state: state,
        startNewGoal: true,
        onCreateGoal: (r) async => exits.add(r.exit),
      );
      await tester.tap(find.byKey(const Key('steward-ask-browse')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('steward-ask-manual')));
      await tester.pumpAndSettle();
      expect(exits, [
        QuickGoalComposerExit.browse,
        QuickGoalComposerExit.advanced,
      ]);
    });

    testWidgets('stays usable on a small phone at large text', (tester) async {
      final state = GameState()..reduceMotion = true;
      await _pumpWorkshop(
        tester,
        state: state,
        startNewGoal: true,
        size: const Size(320, 568),
        textScale: 2,
      );
      for (final answer in const ['Name', 'Outcome']) {
        final key = answer == 'Name'
            ? 'steward-ask-name'
            : 'steward-ask-outcome';
        await tester.enterText(find.byKey(Key(key)), answer);
        await tester.pump();
        final next = find.byKey(const Key('steward-ask-continue'));
        expect(next.hitTestable(), findsOneWidget);
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      // The four kinds of goal scroll inside the panel; the button stays put.
      expect(
        find.byKey(const Key('steward-ask-continue')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the Goals door', () {
    Future<void> pumpGoals(
      WidgetTester tester,
      GameState state,
      List<Quest> quests,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoalsPage(
              state: state,
              quests: quests,
              onAdd: (quest) {
                quests.add(quest);
                return true;
              },
              onRemoveQuest: quests.remove,
              onRemoveGoal: state.removeGoal,
              onPersist: () {},
              onOpenQuest: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('names the Steward and what he does, with goals', (
      tester,
    ) async {
      final state = GameState()..reduceMotion = true;
      state.goals.add(_goal('Finish the portfolio', Stat.foc));
      await pumpGoals(tester, state, []);
      final door = find.byKey(const Key('goals-open-workshop'));
      expect(
        find.descendant(
          of: door,
          matching: find.text('The Steward’s workshop'),
        ),
        findsOneWidget,
      );
      // The sign binds its last two words so a line never ends on one word.
      expect(
        find.descendant(
          of: door,
          matching: find.text('Turn a goal into a first step'),
        ),
        findsOneWidget,
      );
      expect(find.text('Review & reshape'), findsNothing);
    });

    testWidgets('and with none', (tester) async {
      await pumpGoals(tester, GameState()..reduceMotion = true, []);
      final door = find.byKey(const Key('goals-open-workshop'));
      expect(
        find.descendant(
          of: door,
          matching: find.text('The Steward’s workshop'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: door,
          matching: find.text('Start a goal with help'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('New goal opens the Steward at his first question', (
      tester,
    ) async {
      final state = GameState()..reduceMotion = true;
      state.goals.add(_goal('Finish the portfolio', Stat.foc));
      await pumpGoals(tester, state, []);
      await revealOnGoalsPage(tester, find.byKey(const Key('goals-new-goal')));
      await tester.tap(find.byKey(const Key('goals-new-goal')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steward-intake')), findsOneWidget);
      expect(find.byKey(const Key('steward-ask-name')), findsOneWidget);
      expect(find.byKey(const Key('goal-workshop-tavern')), findsOneWidget);
    });
  });

  testWidgets('the arrival shows the XP the Quest will give', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = GameState()..reduceMotion = true;
    final goal = _goal('Finish the portfolio', Stat.foc);
    goal.openingSeen = false;
    state.goals.add(goal);
    final quests = <Quest>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoalsPage(
            state: state,
            quests: quests,
            onAdd: (quest) {
              quests.add(quest);
              return true;
            },
            onRemoveQuest: quests.remove,
            onRemoveGoal: state.removeGoal,
            onPersist: () {},
            onOpenQuest: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goals-open-workshop')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey<String>('goal-workshop-home-goal-Finish the portfolio'),
      ),
    );
    await tester.pumpAndSettle();

    final decision = GoalPlanner.decide(goal, quests, Clock.now())!;
    final quest = GoalPlanner.questFor(goal, decision, Clock.now());
    expect(
      find.descendant(
        of: find.byKey(const Key('goal-workshop-current-quest')),
        matching: find.text('+${state.xpPreview(quest)} XP'),
      ),
      findsOneWidget,
    );
    // The whole step title is on the card, not cut to fit.
    final title = tester.widget<Text>(
      find.byKey(const Key('goal-opening-action-title')),
    );
    expect(title.maxLines, isNull);
    expect(title.overflow, isNot(TextOverflow.ellipsis));
    expect(title.data, decision.actionTitle);
  });
}
