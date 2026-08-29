import 'dart:convert';

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/routines.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/goal_planner.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/goal_detail.dart';
import 'package:emberkeep/screens/goal_opening.dart';
import 'package:emberkeep/screens/goal_wizard.dart';
import 'package:emberkeep/screens/goals.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/workout_flow.dart';
import 'package:emberkeep/widgets/goal_primary_button.dart';
import 'package:emberkeep/widgets/goal_steward.dart';
import 'package:emberkeep/widgets/goal_world.dart';
import 'package:emberkeep/widgets/pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

String _key(String title) => title.trim().toLowerCase();

Future<void> _pumpGoals(
  WidgetTester tester, {
  required GameState state,
  required List<Quest> quests,
  void Function(Quest)? onOpenQuest,
  VoidCallback? onPersist,
  bool disableAnimations = false,
  List<NavigatorObserver> navigatorObservers = const [],
  Size size = const Size(430, 932),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: navigatorObservers,
      builder: disableAnimations || textScale != 1
          ? (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: disableAnimations,
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            )
          : null,
      home: Scaffold(
        body: GoalsPage(
          state: state,
          quests: quests,
          onAdd: (quest) {
            if (quests.any((item) => _key(item.title) == _key(quest.title))) {
              return false;
            }
            quests.add(quest);
            return true;
          },
          onRemoveQuest: quests.remove,
          onRemoveGoal: state.removeGoal,
          onPersist: onPersist ?? () {},
          onOpenQuest: onOpenQuest ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openStartingPoints(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('goals-new-goal')));
  await tester.pumpAndSettle();
  final browse = find.byKey(const Key('quick-goal-browse'));
  await tester.ensureVisible(browse);
  await tester.tap(browse);
  await tester.pumpAndSettle();
}

Future<void> _openKeepYourSpace(WidgetTester tester) async {
  final toggle = find.byKey(
    const ValueKey<String>('goal-catalog-toggle-keep your space'),
    skipOffstage: false,
  );
  await tester.scrollUntilVisible(
    toggle,
    220,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

Future<void> _openKeepAJournal(WidgetTester tester) async {
  final toggle = find.byKey(
    const ValueKey<String>('goal-catalog-toggle-keep a journal'),
    skipOffstage: false,
  );
  await tester.scrollUntilVisible(
    toggle,
    220,
    maxScrolls: 24,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(toggle);
  await tester.pumpAndSettle();
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

Future<void> _finishQuickRoute(
  WidgetTester tester, {
  required String name,
  required String outcome,
  required String startingPoint,
  required String proof,
  required String obstacle,
  String? stat,
  String? type,
}) async {
  await tester.enterText(find.byKey(const Key('quick-goal-name')), name);
  await tester.enterText(find.byKey(const Key('quick-goal-outcome')), outcome);
  if (type != null) {
    final choice = find.byKey(ValueKey('quick-goal-type-$type'));
    await tester.ensureVisible(choice);
    await tester.tap(choice);
  }
  if (stat != null) {
    final choice = find.byKey(ValueKey('quick-goal-stat-$stat'));
    await tester.ensureVisible(choice);
    await tester.tap(choice);
  }
  await tester.tap(find.byKey(const Key('quick-goal-create')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('quick-goal-starting-point')),
    startingPoint,
  );
  await tester.enterText(find.byKey(const Key('quick-goal-proof')), proof);
  await tester.enterText(
    find.byKey(const Key('quick-goal-obstacle')),
    obstacle,
  );
  await tester.tap(find.byKey(const Key('quick-goal-create')));
  await tester.pumpAndSettle();
}

Future<void> _reachOpeningThreshold(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('goal-opening-show-plan')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('goal-room-wide-continue')), findsOneWidget);
  await tester.tap(find.byKey(const Key('goal-room-wide-continue')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('goal-room-arch-step-in')), findsOneWidget);
}

Future<void> _enterWorkshop(WidgetTester tester) async {
  await _reachOpeningThreshold(tester);
  await tester.tap(find.byKey(const Key('goal-room-arch-step-in')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('goal-workshop-screen')), findsOneWidget);
}

({GameState state, Goal goal, Quest quest, List<Quest> quests})
_focusedRecoveryFixture() {
  final drafted = GoalPlanner.draft(
    GoalPlanInput(
      title: 'Make the apartment feel calm',
      stat: Stat.dis,
      type: GoalRouteType.reset,
      outcome: 'The kitchen is usable after ordinary days',
      startingPoint: 'The counter is crowded',
      successProof: 'One clear surface stays usable for a week',
      timeBudgetMinutes: 15,
      obstacleCue: 'the whole room feels too big after class',
      now: Clock.now(),
    ),
  );
  final firstStep = drafted.steps.first;
  final plan = drafted.copyWith(
    steps: [
      firstStep.copyWith(
        completions: firstStep.requiredCompletions,
        completedDay: Days.key(Clock.now().subtract(const Duration(days: 2))),
      ),
      ...drafted.steps.skip(1),
    ],
  );
  final goal = Goal(
    title: 'Make the apartment feel calm',
    stat: Stat.dis,
    kind: GoalKind.achieve,
    target: plan.steps.fold(
      0,
      (total, step) => total + step.requiredCompletions,
    ),
    progress: 1,
    firstProofTitle: 'Cleared the table once',
    firstProofDay: Days.key(Clock.now().subtract(const Duration(days: 2))),
    plan: plan,
    openingSeen: true,
  );
  final decision = GoalPlanner.decide(goal, const [], Clock.now())!;
  final quest = GoalPlanner.questFor(goal, decision, Clock.now());
  final quests = <Quest>[quest];
  final state = GameState()..reduceMotion = true;
  state.goals.add(goal);
  return (state: state, goal: goal, quest: quest, quests: quests);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => Sfx.instance.soundEnabled = false);
  tearDown(() => Sfx.instance.soundEnabled = true);

  testWidgets('empty goals offers quick creation and starting points', (
    tester,
  ) async {
    await _pumpGoals(tester, state: GameState(), quests: []);

    expect(find.byKey(const Key('goals-create-first')), findsOneWidget);
    expect(
      find.byKey(const Key('goals-browse-starting-points')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('goals-create-first')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick-goal-name')), findsOneWidget);
    expect(find.byKey(const Key('quick-goal-outcome')), findsOneWidget);
    expect(find.byKey(const Key('quick-goal-create')), findsOneWidget);
    expect(find.byKey(const Key('quick-goal-browse')), findsOneWidget);
    expect(find.byKey(const Key('quick-goal-advanced')), findsOneWidget);
  });

  testWidgets('quick creation offers then starts its exact first Quest', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    final quests = <Quest>[];
    Quest? opened;
    var persisted = 0;
    await _pumpGoals(
      tester,
      state: state,
      quests: quests,
      onOpenQuest: (quest) => opened = quest,
      onPersist: () => persisted++,
    );

    await tester.tap(find.byKey(const Key('goals-create-first')));
    await tester.pumpAndSettle();
    await _finishQuickRoute(
      tester,
      name: 'Finish demo',
      outcome: 'A reviewer can understand the working demo',
      startingPoint: 'The demo works but I have no walkthrough yet',
      proof: 'A clear walkthrough video exists',
      obstacle: 'I polish details instead of recording',
      stat: 'foc',
      type: 'finish',
    );

    expect(state.goals, hasLength(1));
    expect(state.goals.single.title, 'Finish demo');
    expect(state.goals.single.stat, Stat.foc);
    expect(state.goals.single.plan, isNotNull);
    expect(state.goals.single.plan!.steps, hasLength(4));
    final offeredAction = state.goals.single.plan!.currentStep!.actionTitle;
    expect(quests, isEmpty);
    expect(state.goals.single.openingSeen, isFalse);
    expect(find.byType(GoalOpeningScreen), findsOneWidget);
    expect(find.byKey(const Key('goal-opening-show-plan')), findsOneWidget);
    expect(find.text('Your focus'), findsOneWidget);
    expect(persisted, 1);

    await _reachOpeningThreshold(tester);
    expect(find.byKey(const Key('goal-room-arch-step-in')), findsOneWidget);
    expect(find.byKey(const ValueKey('goal-room-arch-plan')), findsOneWidget);
    final thresholdPlan = tester.getRect(
      find.byKey(const ValueKey('goal-room-arch-plan')),
    );
    expect(
      thresholdPlan.center.dx,
      inInclusiveRange(250, 310),
      reason: 'the live plan should stay registered to the painted arch',
    );
    expect(
      thresholdPlan.center.dy,
      inInclusiveRange(470, 550),
      reason: 'the live plan should stay vertically inside the lit doorway',
    );
    expect(find.text(offeredAction), findsWidgets);

    await tester.tap(find.byKey(const Key('goal-room-arch-step-in')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-workshop-screen')), findsOneWidget);
    expect(find.byKey(const Key('goal-workshop-marker')), findsOneWidget);
    expect(
      find.byKey(const Key('goal-workshop-current-quest')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('goal-workshop-why')), findsOneWidget);
    expect(find.byKey(const Key('goal-workshop-proof')), findsOneWidget);
    expect(find.byKey(const Key('goal-workshop-route')), findsOneWidget);
    expect(find.byKey(const Key('goal-workshop-accept')), findsOneWidget);
    expect(quests, isEmpty);

    await tester.ensureVisible(find.byKey(const Key('goal-workshop-accept')));
    await tester.tap(find.byKey(const Key('goal-workshop-accept')));
    await tester.pumpAndSettle();
    expect(find.byType(GoalOpeningScreen), findsNothing);
    expect(state.goals.single.openingSeen, isTrue);
    expect(quests, hasLength(1));
    expect(quests.single.goalTitle, 'Finish demo');
    expect(
      quests.single.goalPlanStepId,
      state.goals.single.plan!.currentStep!.id,
    );
    expect(quests.single.goalPlanRevision, state.goals.single.plan!.revision);
    expect(quests.single.title, offeredAction);
    expect(quests.single.schedule, QuestSchedule.once);
    expect(identical(opened, quests.single), isTrue);
    expect(persisted, 2);

    await tester.tap(find.byKey(const Key('focus-goal-review')));
    await tester.pumpAndSettle();
    expect(find.byType(GoalOpeningScreen), findsNothing);
    expect(find.byType(GoalDetailScreen), findsOneWidget);
  });

  testWidgets(
    'returning from the workshop keeps the Goal and creates no Quest',
    (tester) async {
      final state = GameState()..reduceMotion = true;
      final quests = <Quest>[];
      await _pumpGoals(tester, state: state, quests: quests);

      await tester.tap(find.byKey(const Key('goals-create-first')));
      await tester.pumpAndSettle();
      await _finishQuickRoute(
        tester,
        name: 'Read before bed',
        outcome: 'Reading belongs to the end of an ordinary day',
        startingPoint: 'The book stays closed when I am tired',
        proof: 'I finish one book without forcing long sessions',
        obstacle: 'A whole chapter feels too large',
        stat: 'intl',
        type: 'routine',
      );
      await _enterWorkshop(tester);

      final goal = state.goals.single;
      expect(goal.openingSeen, isFalse);
      expect(quests, isEmpty);
      await tester.ensureVisible(find.byKey(const Key('goal-workshop-cancel')));
      await tester.tap(find.byKey(const Key('goal-workshop-cancel')));
      await tester.pumpAndSettle();

      expect(find.byType(GoalOpeningScreen), findsNothing);
      expect(state.goals.single, same(goal));
      expect(goal.plan, isNotNull);
      expect(goal.openingSeen, isFalse);
      expect(quests, isEmpty);

      await tester.tap(find.byKey(const Key('focus-goal-review')));
      await tester.pumpAndSettle();
      expect(find.byType(GoalOpeningScreen), findsOneWidget);
      expect(find.byKey(const Key('goal-opening-show-plan')), findsOneWidget);
    },
  );

  testWidgets('workshop acceptance is idempotent under a rapid double tap', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    final quests = <Quest>[];
    var opens = 0;
    await _pumpGoals(
      tester,
      state: state,
      quests: quests,
      onOpenQuest: (_) => opens++,
    );

    await tester.tap(find.byKey(const Key('goals-create-first')));
    await tester.pumpAndSettle();
    await _finishQuickRoute(
      tester,
      name: 'Finish demo',
      outcome: 'A reviewer can understand the working demo',
      startingPoint: 'The demo works but has no walkthrough',
      proof: 'A clear walkthrough video exists',
      obstacle: 'I polish instead of recording',
      stat: 'foc',
      type: 'finish',
    );
    await _enterWorkshop(tester);

    final accept = tester.widget<GoalPrimaryButton>(
      find.byKey(const Key('goal-workshop-accept')),
    );
    accept.onTap();
    accept.onTap();
    await tester.pumpAndSettle();

    expect(quests, hasLength(1));
    expect(opens, 1);
    expect(state.goals.single.openingSeen, isTrue);
  });

  testWidgets('changing the workshop cut revises the offer before acceptance', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    final quests = <Quest>[];
    await _pumpGoals(tester, state: state, quests: quests);

    await tester.tap(find.byKey(const Key('goals-create-first')));
    await tester.pumpAndSettle();
    await _finishQuickRoute(
      tester,
      name: 'Make the apartment feel calm',
      outcome: 'I can use the kitchen without feeling overwhelmed',
      startingPoint: 'The counter is crowded',
      proof: 'The counter stays usable for a normal week',
      obstacle: 'The whole room feels too big after class',
      stat: 'dis',
      type: 'reset',
    );
    await _enterWorkshop(tester);

    final goal = state.goals.single;
    final oldRevision = goal.plan!.revision;
    const revisedAction = 'Put the three loose cups in the cabinet';
    await tester.ensureVisible(
      find.byKey(const Key('goal-workshop-edit-action')),
    );
    await tester.tap(find.byKey(const Key('goal-workshop-edit-action')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('goal-workshop-edit-field')),
      revisedAction,
    );
    await tester.tap(find.byKey(const Key('goal-workshop-edit-save')));
    await tester.pumpAndSettle();

    expect(goal.plan!.revision, oldRevision + 1);
    expect(goal.plan!.currentStep!.actionTitle, revisedAction);
    expect(find.text(revisedAction), findsWidgets);
    expect(quests, isEmpty);

    await tester.ensureVisible(find.byKey(const Key('goal-workshop-accept')));
    await tester.tap(find.byKey(const Key('goal-workshop-accept')));
    await tester.pumpAndSettle();
    expect(quests, hasLength(1));
    expect(quests.single.title, revisedAction);
    expect(quests.single.goalPlanRevision, oldRevision + 1);
    expect(quests.single.goalPlanStepId, goal.plan!.currentStep!.id);
  });

  testWidgets('making the workshop Quest smaller revises before acceptance', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    final quests = <Quest>[];
    await _pumpGoals(tester, state: state, quests: quests);

    await tester.tap(find.byKey(const Key('goals-create-first')));
    await tester.pumpAndSettle();
    await _finishQuickRoute(
      tester,
      name: 'Build a walking habit',
      outcome: 'A short walk fits into ordinary afternoons',
      startingPoint: 'I stop moving after class',
      proof: 'I walk on three ordinary days in one week',
      obstacle: 'A walk feels like it has to be a full workout',
      stat: 'vit',
      type: 'routine',
    );
    await _enterWorkshop(tester);

    final goal = state.goals.single;
    final oldRevision = goal.plan!.revision;
    final smallerAction = goal.plan!.fallbackAction;
    await tester.ensureVisible(
      find.byKey(const Key('goal-workshop-smaller-action')),
    );
    await tester.tap(find.byKey(const Key('goal-workshop-smaller-action')));
    await tester.pumpAndSettle();

    expect(goal.plan!.revision, oldRevision + 1);
    expect(goal.plan!.lastSignal, GoalPlanSignal.tooBig);
    expect(goal.plan!.currentStep!.actionTitle, smallerAction);
    expect(find.text(smallerAction), findsWidgets);
    expect(quests, isEmpty);

    await tester.ensureVisible(find.byKey(const Key('goal-workshop-accept')));
    await tester.tap(find.byKey(const Key('goal-workshop-accept')));
    await tester.pumpAndSettle();
    expect(quests, hasLength(1));
    expect(quests.single.title, smallerAction);
    expect(quests.single.goalPlanRevision, oldRevision + 1);
    expect(quests.single.goalPlanStepId, goal.plan!.currentStep!.id);
  });

  testWidgets('opening back control is unavailable only while the room moves', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final goal = Goal(
      title: 'Make the apartment feel calm',
      stat: Stat.dis,
      target: 25,
      why: 'so coming home feels like an exhale',
      fallbackAction: 'clear one hand-sized surface',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GoalOpeningScreen(
          goal: goal,
          actionTitle: 'Clear the kitchen counter',
          fallbackAction: goal.fallbackAction,
          preparedByApp: true,
          onBegin: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Pressable>(find.byKey(const Key('goal-opening-back')))
          .enabled,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('goal-opening-show-plan')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump();
    expect(find.byKey(const Key('goal-opening-back')), findsOneWidget);
    expect(
      tester
          .widget<Pressable>(find.byKey(const Key('goal-opening-back')))
          .enabled,
      isFalse,
    );

    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('goal-opening-wide-room-stop')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('goal-room-wide-continue')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('goal-room-travel-motion-blur')),
      findsNothing,
      reason: 'every user-controlled room stop must resolve completely crisp',
    );
    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey('goal-opening-desk-opacity')),
          )
          .opacity,
      0,
      reason: 'the wide stop must expose the apartment and its live plan',
    );
    expect(
      tester
          .widget<Pressable>(find.byKey(const Key('goal-opening-back')))
          .enabled,
      isTrue,
    );

    final parkedPlanCenter = tester.getCenter(
      find.byKey(const ValueKey('goal-room-arch-plan')),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(
      find.byKey(const ValueKey('goal-opening-wide-room-stop')),
      findsOneWidget,
      reason: 'the camera must never leave the wide room on its own',
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('goal-room-arch-plan'))),
      parkedPlanCenter,
      reason: 'the live plan and room must remain parked until the tap',
    );
    expect(find.byKey(const Key('goal-room-arch-step-in')), findsNothing);

    await tester.tap(find.byKey(const Key('goal-room-wide-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(
      tester
          .widget<Pressable>(find.byKey(const Key('goal-opening-back')))
          .enabled,
      isFalse,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-room-arch-step-in')), findsOneWidget);
    expect(
      tester
          .widget<Pressable>(find.byKey(const Key('goal-opening-back')))
          .enabled,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('goal-room-arch-step-in')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump();
    expect(
      tester
          .widget<Pressable>(find.byKey(const Key('goal-opening-back')))
          .enabled,
      isFalse,
    );

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump();
    expect(
      tester
          .widget<Pressable>(find.byKey(const Key('goal-opening-back')))
          .enabled,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'opening gives completion and resilience distinct transition beats',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final goal = Goal(
        title: 'Make the apartment feel calm',
        stat: Stat.dis,
        target: 25,
        why: 'so coming home feels like an exhale',
        fallbackAction: 'clear one hand-sized surface',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GoalOpeningScreen(
            goal: goal,
            actionTitle: 'Clear the kitchen counter',
            fallbackAction: goal.fallbackAction,
            preparedByApp: true,
            onBegin: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('goal-opening-show-plan')));
      await tester.pumpAndSettle();

      Text archTitle() => tester.widget<Text>(
        find.byKey(const ValueKey('goal-room-arch-action-title')),
      );
      AnimatedOpacity archAction() => tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('goal-room-arch-action-opacity')),
      );

      expect(archTitle().data, 'Clear the kitchen counter is visibly done');
      expect(archTitle().style?.fontFamily, 'EBGaramond');
      expect(archTitle().style?.fontSize, 27);
      expect(archAction().opacity, 1);
      expect(find.byKey(const Key('goal-room-wide-continue')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('goal-room-travel-motion-blur')),
        findsNothing,
        reason: 'the parked wide-room plan must be completely crisp',
      );

      await tester.tap(find.byKey(const Key('goal-room-wide-continue')));
      await tester.pump();
      expect(archTitle().data, 'Clear the kitchen counter is visibly done');
      expect(archTitle().style?.fontFamily, 'EBGaramond');
      await tester.pump(Motion.quick);
      expect(archAction().opacity, 0);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('goal-room-arch-step-in')), findsOneWidget);
      expect(
        archTitle().data,
        'The full version may ask for more than today has.',
      );
      expect(archAction().opacity, 1);
      expect(find.text('What this plan should survive'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('goal-room-arch-plan')),
          matching: find.text('clear one hand-sized surface'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('goal-room-travel-motion-blur')),
        findsNothing,
        reason: 'the parked threshold must be completely crisp',
      );

      await tester.tap(find.byKey(const Key('goal-room-arch-step-in')));
      await tester.pump();
      expect(
        archTitle().data,
        'The full version may ask for more than today has.',
      );
      expect(archTitle().style?.fontFamily, 'EBGaramond');
      await tester.pump(Motion.quick);
      expect(archAction().opacity, 0);

      var sawTravelBlur = false;
      var sawWorkshopShell = false;
      for (var frame = 0; frame < 34; frame++) {
        await tester.pump(const Duration(microseconds: 33333));
        sawTravelBlur |= find
            .byKey(const ValueKey('goal-room-travel-motion-blur'))
            .evaluate()
            .isNotEmpty;
        final shell = tester.widget<Opacity>(
          find.byKey(const ValueKey('goal-workshop-shell-opacity')),
        );
        sawWorkshopShell |= shell.opacity > 0;
        final sourceOpacityFinder = find.byKey(
          const ValueKey('goal-room-arch-title-opacity'),
        );
        final sourceOpacity = sourceOpacityFinder.evaluate().isEmpty
            ? 0.0
            : tester.widget<Opacity>(sourceOpacityFinder).opacity;
        final workshopOpacity = tester
            .widget<Opacity>(
              find.byKey(const ValueKey('goal-workshop-cut-title-opacity')),
            )
            .opacity;
        expect(
          sourceOpacity > 0.01 && workshopOpacity > 0.01,
          isFalse,
          reason: 'the action title must never be rendered twice in one frame',
        );
      }
      expect(
        sawTravelBlur,
        isTrue,
        reason: 'only the painted room receives velocity softness in flight',
      );
      expect(sawWorkshopShell, isTrue);

      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('goal-room-travel-motion-blur')),
        findsNothing,
        reason: 'blur must resolve before the workshop becomes actionable',
      );
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('goal-workshop-cut-title-opacity')),
            )
            .opacity,
        1,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('goal-opening-action-title')))
            .style
            ?.fontFamily,
        'EBGaramond',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Reduced Motion parks each opening beat without travel blur', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final goal = Goal(
      title: 'Make the apartment feel calm',
      stat: Stat.dis,
      target: 25,
      fallbackAction: 'clear one hand-sized surface',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GoalOpeningScreen(
          goal: goal,
          actionTitle: 'Clear the kitchen counter',
          fallbackAction: goal.fallbackAction,
          preparedByApp: true,
          onBegin: () {},
          reduceMotion: true,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('goal-opening-show-plan')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('goal-room-travel-motion-blur')),
      findsNothing,
    );
    expect(find.byKey(const Key('goal-room-wide-continue')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('goal-room-arch-action-title')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('goal-room-wide-continue')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('goal-room-travel-motion-blur')),
      findsNothing,
    );
    expect(find.byKey(const Key('goal-room-arch-step-in')), findsOneWidget);

    await tester.tap(find.byKey(const Key('goal-room-arch-step-in')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('goal-room-travel-motion-blur')),
      findsNothing,
    );
    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey('goal-workshop-cut-title-opacity')),
          )
          .opacity,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact opening parks its folio at the wide-room stop', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final goal = Goal(
      title: 'Make the apartment feel calm',
      stat: Stat.dis,
      target: 25,
      fallbackAction: 'clear one hand-sized surface',
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: GoalOpeningScreen(
          goal: goal,
          actionTitle: 'Clear the kitchen counter',
          fallbackAction: goal.fallbackAction,
          preparedByApp: true,
          onBegin: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    Opacity routeStopOpacity() => tester.widget<Opacity>(
      find.byKey(const ValueKey('goal-opening-compact-route-stop-opacity')),
    );

    expect(routeStopOpacity().opacity, 0);
    await tester.ensureVisible(find.byKey(const Key('goal-opening-show-plan')));
    await tester.tap(find.byKey(const Key('goal-opening-show-plan')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump();
    expect(
      routeStopOpacity().opacity,
      lessThan(0.05),
      reason: 'the plan should not replace the desk on the first travel frame',
    );

    await tester.pump(const Duration(milliseconds: 1050));
    expect(routeStopOpacity().opacity, greaterThan(0.1));
    await tester.pumpAndSettle();
    expect(routeStopOpacity().opacity, 1);
    expect(find.byKey(const Key('goal-room-wide-continue')), findsOneWidget);
    expect(
      tester
          .widget<Pressable>(find.byKey(const Key('goal-opening-back')))
          .enabled,
      isTrue,
    );

    tester
        .widget<Pressable>(find.byKey(const Key('goal-opening-back')))
        .onTapUp!(Offset.zero);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
    expect(
      routeStopOpacity().opacity,
      lessThan(0.5),
      reason: 'the compact plan should dissolve before the desk returns',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(routeStopOpacity().opacity, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick goal gets an aim-based route and exact first move', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    final quests = <Quest>[];
    Quest? opened;
    await _pumpGoals(
      tester,
      state: state,
      quests: quests,
      onOpenQuest: (quest) => opened = quest,
    );

    await tester.tap(find.byKey(const Key('goals-create-first')));
    await tester.pumpAndSettle();
    await _finishQuickRoute(
      tester,
      name: 'Make the apartment feel calm',
      outcome: 'I can use the kitchen without feeling overwhelmed',
      startingPoint: 'The counter is crowded and I avoid deciding what moves',
      proof: 'The counter stays usable for a normal week',
      obstacle: 'the whole room feels too big after class',
      stat: 'dis',
      type: 'reset',
    );

    final goal = state.goals.single;
    expect(goal.plan, isNotNull);
    expect(quests, isEmpty);
    expect(find.text('Your focus'), findsOneWidget);
    expect(
      goal.plan!.currentStep!.actionTitle.toLowerCase(),
      contains('counter'),
    );
    expect(find.text(goal.plan!.currentStep!.actionTitle), findsWidgets);

    await _reachOpeningThreshold(tester);
    expect(find.textContaining(goal.plan!.fallbackAction), findsWidgets);
    await tester.tap(find.byKey(const Key('goal-room-arch-step-in')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-workshop-screen')), findsOneWidget);
    expect(find.byKey(const Key('goal-workshop-why')), findsOneWidget);
    expect(find.byKey(const Key('goal-workshop-proof')), findsOneWidget);
    expect(find.byKey(const Key('goal-workshop-route')), findsOneWidget);
    expect(quests, isEmpty);
    await tester.ensureVisible(find.byKey(const Key('goal-workshop-accept')));
    await tester.tap(find.byKey(const Key('goal-workshop-accept')));
    await tester.pumpAndSettle();

    expect(quests, hasLength(1));
    expect(quests.single.title, goal.plan!.steps.first.actionTitle);
    expect(quests.single.goalTitle, state.goals.single.title);
    expect(quests.single.goalPlanStepId, goal.plan!.steps.first.id);
    expect(identical(opened, quests.single), isTrue);
    expect(state.goals.single.openingSeen, isTrue);
    expect(state.goals.single.fallbackAction, goal.plan!.fallbackAction);
  });

  testWidgets('leaving the opening keeps it resumable until acceptance', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    final quests = <Quest>[];
    var persisted = 0;
    await _pumpGoals(
      tester,
      state: state,
      quests: quests,
      onPersist: () => persisted++,
    );

    await tester.tap(find.byKey(const Key('goals-create-first')));
    await tester.pumpAndSettle();
    await _finishQuickRoute(
      tester,
      name: 'Read before bed',
      outcome: 'Reading is part of winding down most nights',
      startingPoint: 'My book stays closed when I get into bed tired',
      proof: 'I finish one book without forcing a long nightly session',
      obstacle: 'I am too tired for a whole chapter',
      stat: 'intl',
      type: 'routine',
    );

    final goal = state.goals.single;
    expect(goal.openingSeen, isFalse);
    expect(persisted, 1);
    await _reachOpeningThreshold(tester);
    await tester.tap(find.byKey(const Key('goal-room-arch-step-in')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('goal-opening-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-room-arch-step-in')), findsOneWidget);
    await tester.tap(find.byKey(const Key('goal-opening-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-room-wide-continue')), findsOneWidget);
    await tester.tap(find.byKey(const Key('goal-opening-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-opening-show-plan')), findsOneWidget);
    await tester.tap(find.byKey(const Key('goal-opening-back')));
    await tester.pumpAndSettle();

    expect(find.byType(GoalOpeningScreen), findsNothing);
    expect(goal.openingSeen, isFalse);
    expect(quests, isEmpty);

    await tester.tap(find.byKey(const Key('focus-goal-review')));
    await tester.pumpAndSettle();
    expect(find.byType(GoalOpeningScreen), findsOneWidget);
    expect(find.byKey(const Key('goal-opening-show-plan')), findsOneWidget);

    await _reachOpeningThreshold(tester);
    await tester.tap(find.byKey(const Key('goal-room-arch-step-in')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('goal-workshop-accept')));
    await tester.tap(find.byKey(const Key('goal-workshop-accept')));
    await tester.pumpAndSettle();

    expect(goal.openingSeen, isTrue);
    expect(quests, hasLength(1));
    expect(quests.single.title, goal.plan!.steps.first.actionTitle);
    expect(persisted, 2);
  });

  testWidgets('system back during travel cannot discard the opening', (
    tester,
  ) async {
    final state = GameState();
    final quests = <Quest>[];
    await _pumpGoals(tester, state: state, quests: quests);

    await tester.tap(find.byKey(const Key('goals-create-first')));
    await tester.pumpAndSettle();
    await _finishQuickRoute(
      tester,
      name: 'Build a walking habit',
      outcome: 'A short walk fits into ordinary afternoons',
      startingPoint: 'I stop moving after class and stay at my desk',
      proof: 'I walk on three ordinary days in one week',
      obstacle: 'I feel like a walk has to be a full workout',
      stat: 'vit',
      type: 'routine',
    );

    await tester.tap(find.byKey(const Key('goal-opening-show-plan')));
    await tester.pump(const Duration(milliseconds: 180));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(GoalOpeningScreen), findsOneWidget);
    expect(state.goals.single.openingSeen, isFalse);

    await tester.pump(const Duration(milliseconds: 1250));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-room-wide-continue')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(GoalOpeningScreen), findsOneWidget);
    expect(find.byKey(const Key('goal-opening-show-plan')), findsOneWidget);
    expect(state.goals.single.openingSeen, isFalse);
  });

  testWidgets('focused goal hands off the exact due Quest directly', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 8, 25, 10));
    addTearDown(Clock.reset);
    final state = GameState()..reduceMotion = true;
    final goal = Goal(title: 'Ship the demo', stat: Stat.foc, target: 25);
    state.goals.add(goal);
    final snoozed = Quest(
      title: 'Snoozed action',
      stat: Stat.foc,
      difficulty: 1,
      goalTitle: goal.title,
      snoozedDay: '2026-08-25',
    );
    final due = Quest(
      title: 'Record the walkthrough',
      stat: Stat.foc,
      difficulty: 2,
      schedule: QuestSchedule.once,
      dueDate: DateTime(2026, 8, 25, 18),
      goalTitle: goal.title,
    );
    Quest? opened;
    await _pumpGoals(
      tester,
      state: state,
      quests: [snoozed, due],
      onOpenQuest: (quest) => opened = quest,
    );

    expect(find.text('Open Quest'), findsOneWidget);
    await tester.tap(find.byKey(const Key('focus-goal-action')));
    await tester.pumpAndSettle();

    expect(find.byType(GoalDetailScreen), findsNothing);
    expect(identical(opened, due), isTrue);
  });

  testWidgets('focused recovery can leave today exactly unchanged', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 8, 29, 10));
    addTearDown(Clock.reset);
    final fixture = _focusedRecoveryFixture();
    var persistCalls = 0;
    final goalBefore = jsonEncode(fixture.goal.toJson());
    final questsBefore = jsonEncode(
      fixture.quests.map((quest) => quest.toJson()).toList(),
    );

    await _pumpGoals(
      tester,
      state: fixture.state,
      quests: fixture.quests,
      onPersist: () => persistCalls++,
    );

    expect(find.text('this doesn’t fit today'), findsOneWidget);
    await tester.tap(find.byKey(const Key('focus-goal-fallback')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('goal-recovery-smaller')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('goal-recovery-prepareReturn')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('goal-recovery-leaveTodayAlone')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('goal-recovery-leaveTodayAlone')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Nothing changed. Your route is here when you want it.'),
      findsOneWidget,
    );
    expect(jsonEncode(fixture.goal.toJson()), goalBefore);
    expect(
      jsonEncode(fixture.quests.map((quest) => quest.toJson()).toList()),
      questsBefore,
    );
    expect(fixture.quests, hasLength(1));
    expect(identical(fixture.quests.single, fixture.quest), isTrue);
    expect(persistCalls, 0);
  });

  testWidgets(
    'focused recovery offers a smaller cut before creating its revised Quest',
    (tester) async {
      Clock.freeze(DateTime(2026, 8, 29, 10));
      addTearDown(Clock.reset);
      final fixture = _focusedRecoveryFixture();
      final oldRevision = fixture.goal.plan!.revision;
      final completedStepBefore = jsonEncode(
        fixture.goal.plan!.steps.first.toJson(),
      );
      final firstProofTitleBefore = fixture.goal.firstProofTitle;
      final firstProofDayBefore = fixture.goal.firstProofDay;
      Quest? opened;

      await _pumpGoals(
        tester,
        state: fixture.state,
        quests: fixture.quests,
        onOpenQuest: (quest) => opened = quest,
      );

      await tester.tap(find.byKey(const Key('focus-goal-fallback')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('goal-recovery-smaller')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('goal-workshop-screen')), findsOneWidget);
      expect(fixture.goal.openingSeen, isTrue);
      expect(fixture.goal.plan!.revision, oldRevision + 1);
      expect(fixture.goal.plan!.lastSignal, GoalPlanSignal.tooBig);
      expect(
        jsonEncode(fixture.goal.plan!.steps.first.toJson()),
        completedStepBefore,
      );
      expect(fixture.goal.firstProofTitle, firstProofTitleBefore);
      expect(fixture.goal.firstProofDay, firstProofDayBefore);
      expect(fixture.goal.plan!.currentStep!.kind, GoalPlanStepKind.recover);
      expect(fixture.quests, isNot(contains(fixture.quest)));
      expect(
        fixture.quests.where(
          (quest) => quest.goalPlanRevision == fixture.goal.plan!.revision,
        ),
        isEmpty,
      );

      await tester.ensureVisible(find.byKey(const Key('goal-workshop-accept')));
      await tester.tap(find.byKey(const Key('goal-workshop-accept')));
      await tester.pumpAndSettle();

      final accepted = fixture.quests.single;
      final current = fixture.goal.plan!.currentStep!;
      expect(accepted.goalPlanRevision, fixture.goal.plan!.revision);
      expect(accepted.goalPlanStepId, current.id);
      expect(accepted.goalPlanAttempt, current.completions + 1);
      expect(identical(opened, accepted), isTrue);
    },
  );

  testWidgets(
    'focused recovery can prepare the return without pre-creating a Quest',
    (tester) async {
      Clock.freeze(DateTime(2026, 8, 29, 10));
      addTearDown(Clock.reset);
      final fixture = _focusedRecoveryFixture();
      final oldRevision = fixture.goal.plan!.revision;
      final completedStepBefore = jsonEncode(
        fixture.goal.plan!.steps.first.toJson(),
      );
      final firstProofTitleBefore = fixture.goal.firstProofTitle;
      final firstProofDayBefore = fixture.goal.firstProofDay;

      await _pumpGoals(tester, state: fixture.state, quests: fixture.quests);

      await tester.tap(find.byKey(const Key('focus-goal-fallback')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('goal-recovery-prepareReturn')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('goal-workshop-screen')), findsOneWidget);
      expect(fixture.goal.plan!.revision, oldRevision + 1);
      expect(fixture.goal.plan!.lastSignal, GoalPlanSignal.lowEnergy);
      expect(
        jsonEncode(fixture.goal.plan!.steps.first.toJson()),
        completedStepBefore,
      );
      expect(fixture.goal.firstProofTitle, firstProofTitleBefore);
      expect(fixture.goal.firstProofDay, firstProofDayBefore);
      expect(fixture.goal.plan!.currentStep!.kind, GoalPlanStepKind.prepare);
      expect(
        fixture.quests.where(
          (quest) => quest.goalPlanRevision == fixture.goal.plan!.revision,
        ),
        isEmpty,
      );
    },
  );

  testWidgets('Goals threshold honors the OS reduced-motion preference', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = false;
    final goal = Goal(title: 'Ship the demo', stat: Stat.foc, target: 25);
    state.goals.add(goal);
    final quest = Quest(
      title: 'Record the walkthrough',
      stat: Stat.foc,
      difficulty: 2,
      goalTitle: goal.title,
    );
    Quest? opened;
    await _pumpGoals(
      tester,
      state: state,
      quests: [quest],
      disableAnimations: true,
      onOpenQuest: (value) => opened = value,
    );

    await tester.tap(find.byKey(const Key('focus-goal-action')));
    await tester.pump();
    expect(find.text('Opening'), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 460));
    await tester.pump(const Duration(milliseconds: 460));
    await tester.pump(const Duration(milliseconds: 10));

    // Reduced Motion may complete and remove the handoff route in one frame;
    // the contract is the exact Quest callback, not a visible hold.
    expect(
      find.byKey(const Key('goal-room-travel-backdrop')),
      findsNothing,
      reason:
          'Reduced Motion should fade between the real source and destination stills',
    );
    expect(
      find.byKey(const Key('detail-route-threshold-travel')),
      findsNothing,
    );
    expect(find.byKey(const Key('detail-route-shared-axis')), findsNothing);
    expect(find.byKey(const Key('detail-route-scale')), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byType(GoalDetailScreen), findsNothing);
    expect(identical(opened, quest), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quest handoff rejects rapid repeat entry', (tester) async {
    final state = GameState()..reduceMotion = false;
    final goal = Goal(title: 'Ship the demo', stat: Stat.foc, target: 25);
    state.goals.add(goal);
    final quest = Quest(
      title: 'Record the walkthrough',
      stat: Stat.foc,
      difficulty: 2,
      goalTitle: goal.title,
    );
    Quest? opened;
    await _pumpGoals(
      tester,
      state: state,
      quests: [quest],
      onOpenQuest: (value) => opened = value,
    );

    final action = find.byKey(
      const Key('focus-goal-action'),
      skipOffstage: false,
    );
    await tester.tap(action);
    await tester.tap(action);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1640));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));

    expect(identical(opened, quest), isTrue);
    expect(find.byType(GoalDetailScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('room travel reverses cleanly from the threshold', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = false;
    final goal = Goal(title: 'Ship the demo', stat: Stat.foc, target: 25);
    state.goals.add(goal);
    final quest = Quest(
      title: 'Record the walkthrough',
      stat: Stat.foc,
      difficulty: 2,
      goalTitle: goal.title,
    );
    Quest? opened;
    await _pumpGoals(
      tester,
      state: state,
      quests: [quest],
      onOpenQuest: (value) => opened = value,
    );

    await tester.tap(find.byKey(const Key('focus-goal-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    Navigator.of(tester.element(find.byType(GoalsPage))).pop();
    // The delayed arrival callback still owns its timer after a back pop;
    // advance past the hold so the cancellation path is fully drained.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 360));

    expect(find.byType(GoalDetailScreen), findsNothing);
    expect(opened, isNull);
    expect(find.byType(GoalDetailScreen), findsNothing);
    expect(find.text('Opening'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('focused goal without actions leads with add an action', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    state.goals.add(Goal(title: 'Read more', stat: Stat.foc, target: 25));
    await _pumpGoals(tester, state: state, quests: []);

    expect(find.text('Add a Quest'), findsOneWidget);
    await tester.tap(find.byKey(const Key('focus-goal-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ember-title')), findsOneWidget);
  });

  testWidgets(
    'workshop register distinguishes a waiting cut from an owned Quest',
    (tester) async {
      Clock.freeze(DateTime(2026, 8, 28, 10));
      addTearDown(Clock.reset);
      final state = GameState()..reduceMotion = true;
      Goal makeGoal(String title, Stat stat) {
        final plan = GoalPlanner.draft(
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
        return Goal(
          title: title,
          stat: stat,
          kind: GoalKind.achieve,
          target: 4,
          plan: plan,
          openingSeen: true,
        );
      }

      final ownedGoal = makeGoal('Finish the portfolio', Stat.foc);
      final waitingGoal = makeGoal('Make the apartment feel calm', Stat.dis);
      state.goals.addAll([ownedGoal, waitingGoal]);
      final ownedDecision = GoalPlanner.decide(
        ownedGoal,
        const [],
        Clock.now(),
      )!;
      final ownedQuest = GoalPlanner.questFor(
        ownedGoal,
        ownedDecision,
        Clock.now(),
      );
      final quests = <Quest>[ownedQuest];
      Quest? opened;
      await _pumpGoals(
        tester,
        state: state,
        quests: quests,
        onOpenQuest: (quest) => opened = quest,
      );

      await tester.tap(find.byKey(const Key('goals-open-workshop')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('goal-workshop-home')), findsOneWidget);
      expect(find.byKey(const Key('goal-workshop-steward')), findsOneWidget);
      final tavern = tester.widget<GoalStewardArtwork>(
        find.byKey(const Key('goal-workshop-tavern')),
      );
      expect(tavern.expression, GoalStewardExpression.ready);
      final readyImage = tester.widget<Image>(
        find.byKey(const ValueKey('goal-steward-expression-ready')),
      );
      expect(
        (readyImage.image as AssetImage).assetName,
        goalsWorkshopStewardReadyAsset,
      );
      expect(
        find.byKey(const Key('goal-workshop-steward-background')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('goal-workshop-steward-counter')),
        findsOneWidget,
      );
      expect(find.text('QUEST ON BOARD'), findsOneWidget);
      expect(find.text('CUT WAITING'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'goal-workshop-home-goal-Finish the portfolio',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('CURRENT QUEST'), findsOneWidget);
      expect(find.text('Open this Quest'), findsOneWidget);
      expect(
        tester
            .widget<GoalRoomTravelBackdrop>(find.byType(GoalRoomTravelBackdrop))
            .destinationExpression,
        GoalStewardExpression.acknowledging,
      );
      await tester.ensureVisible(find.byKey(const Key('goal-workshop-accept')));
      await tester.tap(find.byKey(const Key('goal-workshop-accept')));
      await tester.pumpAndSettle();
      expect(identical(opened, ownedQuest), isTrue);
      expect(quests, hasLength(1));
      expect(find.byKey(const Key('goal-workshop-home')), findsNothing);

      await tester.tap(find.byKey(const Key('goals-open-workshop')));
      await tester.pumpAndSettle();
      final waitingRow = find.byKey(
        const ValueKey<String>(
          'goal-workshop-home-goal-Make the apartment feel calm',
        ),
      );
      await tester.tap(waitingRow);
      await tester.pumpAndSettle();
      expect(find.text('THE CUT'), findsOneWidget);
      expect(find.text('Take this Quest'), findsOneWidget);
      expect(
        tester
            .widget<GoalRoomTravelBackdrop>(find.byType(GoalRoomTravelBackdrop))
            .destinationExpression,
        GoalStewardExpression.ready,
      );
      await tester.ensureVisible(find.byKey(const Key('goal-workshop-cancel')));
      await tester.tap(find.byKey(const Key('goal-workshop-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('goal-workshop-home')), findsOneWidget);
      expect(quests, hasLength(1));

      await tester.tap(waitingRow);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('goal-workshop-accept')));
      await tester.tap(find.byKey(const Key('goal-workshop-accept')));
      await tester.pumpAndSettle();
      expect(quests, hasLength(2));
      expect(opened?.goalTitle, waitingGoal.title);
      expect(opened?.goalPlanRevision, waitingGoal.plan!.revision);
    },
  );

  testWidgets('a legacy goal can build a structured route in place', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    final goal = Goal(
      title: 'Finish the portfolio',
      stat: Stat.foc,
      kind: GoalKind.achieve,
      target: 25,
    );
    state.goals.add(goal);
    final quests = <Quest>[];
    await _pumpGoals(tester, state: state, quests: quests);

    await tester.tap(find.byKey(const Key('goals-open-workshop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-workshop-home')), findsOneWidget);
    await tester.tap(
      find.byKey(
        const ValueKey<String>('goal-workshop-home-goal-Finish the portfolio'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Finish the portfolio'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('quick-goal-outcome')),
      'A hiring manager can understand my two strongest projects',
    );
    await tester.tap(find.byKey(const Key('quick-goal-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('quick-goal-starting-point')),
      'I have an outline but no project-page draft',
    );
    await tester.enterText(
      find.byKey(const Key('quick-goal-proof')),
      'Two readable project pages are published',
    );
    await tester.enterText(
      find.byKey(const Key('quick-goal-obstacle')),
      'I polish screenshots before the story exists',
    );
    await tester.tap(find.byKey(const Key('quick-goal-create')));
    await tester.pumpAndSettle();

    expect(goal.plan, isNotNull);
    expect(
      goal.target,
      goal.plan!.steps.fold(
        0,
        (total, step) => total + step.requiredCompletions,
      ),
    );
    expect(goal.openingSeen, isFalse);
    expect(quests, isEmpty);
    expect(find.byType(GoalOpeningScreen), findsOneWidget);

    await _enterWorkshop(tester);
    await tester.ensureVisible(find.byKey(const Key('goal-workshop-accept')));
    await tester.tap(find.byKey(const Key('goal-workshop-accept')));
    await tester.pumpAndSettle();

    expect(goal.openingSeen, isTrue);
    expect(quests, hasLength(1));
    expect(quests.single.goalPlanStepId, goal.plan!.currentStep!.id);
  });

  testWidgets(
    'catalog adoption reuses an existing goal with canonical casing',
    (tester) async {
      final state = GameState()..reduceMotion = true;
      final canonical = Goal(
        title: 'keep YOUR space',
        stat: Stat.dis,
        target: 25,
      );
      state.goals.add(canonical);
      final quests = <Quest>[];
      await _pumpGoals(tester, state: state, quests: quests);

      await _openStartingPoints(tester);
      await _openKeepYourSpace(tester);
      final adopt = find.text('ADD MISSING ACTIONS');
      await tester.scrollUntilVisible(
        adopt,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(adopt);
      await tester.pumpAndSettle();

      expect(state.goals, hasLength(1));
      expect(identical(state.goals.single, canonical), isTrue);
      expect(quests, isNotEmpty);
      expect(
        quests.every((quest) => quest.goalTitle == 'keep YOUR space'),
        isTrue,
      );
    },
  );

  testWidgets('a newly adopted starting point receives the opening', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    final quests = <Quest>[];
    await _pumpGoals(tester, state: state, quests: quests);

    await tester.tap(find.byKey(const Key('goals-browse-starting-points')));
    await tester.pumpAndSettle();
    await _openKeepYourSpace(tester);
    final adopt = find.text('ADOPT WHOLE GOAL');
    await tester.scrollUntilVisible(
      adopt,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(adopt);
    await tester.pumpAndSettle();

    expect(state.goals, hasLength(1));
    expect(state.goals.single.openingSeen, isFalse);
    expect(quests, isEmpty);
    expect(find.byType(GoalOpeningScreen), findsOneWidget);
    expect(find.byKey(const Key('goal-opening-show-plan')), findsOneWidget);

    await _enterWorkshop(tester);
    await tester.ensureVisible(find.byKey(const Key('goal-workshop-accept')));
    await tester.tap(find.byKey(const Key('goal-workshop-accept')));
    await tester.pumpAndSettle();

    expect(quests, hasLength(1));
    expect(quests.single.title, 'Make your bed');
    expect(quests.single.schedule, QuestSchedule.daily);
    expect(quests.single.difficulty, 1);
    expect(
      quests.single.goalPlanStepId,
      state.goals.single.plan!.steps.first.id,
    );
  });

  testWidgets(
    'Journal starting point advances through distinct beats with live artwork',
    (tester) async {
      // Keep the catalog itself still so it can settle, then let the opening
      // read live motion at the moment it is pushed.
      final state = GameState()..reduceMotion = true;
      final quests = <Quest>[];
      await _pumpGoals(tester, state: state, quests: quests);

      final goalsContext = tester.element(find.byType(GoalsPage));
      final failedAssets = <String>[];
      await tester.runAsync(() async {
        for (final asset in <String>[
          ...goalStewardAssets,
          goalsWorkshopStewardFallbackAsset,
        ]) {
          await precacheImage(
            AssetImage(asset),
            goalsContext,
            onError: (_, _) => failedAssets.add(asset),
          );
        }
      });
      expect(failedAssets, isEmpty);

      await tester.tap(find.byKey(const Key('goals-browse-starting-points')));
      await tester.pumpAndSettle();
      await _openKeepAJournal(tester);
      final adopt = find.text('ADOPT WHOLE GOAL');
      await tester.scrollUntilVisible(
        adopt,
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(adopt);
      await tester.pumpAndSettle();
      state.reduceMotion = false;
      await tester.tap(adopt);
      await tester.pumpAndSettle();

      expect(state.goals, hasLength(1));
      final journal = state.goals.single;
      expect(journal.title, 'Keep a journal');
      expect(journal.plan!.steps.map((step) => step.actionTitle), <String>[
        'One line a day',
        'Name three good things',
        'Empty your head before bed',
        'Write it all out',
        'Look back on your week',
      ]);
      expect(
        journal.plan!.steps.map((step) => step.title),
        journal.plan!.steps.map((step) => step.actionTitle),
      );
      expect(journal.plan!.fallbackAction, 'Write one sentence about today');
      expect(
        journal.plan!.steps.every(
          (step) => step.questTemplate?.journalPrompt != null,
        ),
        isTrue,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('goal-opening-title'))).data,
        'Keep a journal',
      );

      await tester.tap(find.byKey(const Key('goal-opening-show-plan')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      expect(find.byType(GoalRoomTravelBackdrop), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('goal-room-wide-continue')), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('goal-room-arch-action-title')),
            )
            .data,
        'You have a trail of entries that helps you recognize what your days feel like.',
      );
      expect(find.text('You’ll know this is complete when'), findsOneWidget);

      await tester.tap(find.byKey(const Key('goal-room-wide-continue')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      expect(find.byType(GoalRoomTravelBackdrop), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('goal-room-arch-step-in')), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('goal-room-arch-action-title')),
            )
            .data,
        'Some days may feel too full to turn into words.',
      );
      expect(find.text('What this plan should survive'), findsOneWidget);
      expect(find.text('Lighter version'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('goal-room-arch-plan')),
          matching: find.text('Write one sentence about today'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('goal-room-arch-step-in')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      expect(find.byType(GoalRoomTravelBackdrop), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('goal-workshop-screen')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('goal-opening-action-title')))
            .data,
        'One line a day',
      );
      expect(
        (tester
                    .widget<Image>(
                      find.byKey(
                        const ValueKey('goal-steward-expression-ready'),
                      ),
                    )
                    .image
                as AssetImage)
            .assetName,
        goalsWorkshopStewardReadyAsset,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    're-adopting an unaccepted catalog route returns to its workshop',
    (tester) async {
      final state = GameState()..reduceMotion = true;
      final quests = <Quest>[];
      await _pumpGoals(tester, state: state, quests: quests);

      await tester.tap(find.byKey(const Key('goals-browse-starting-points')));
      await tester.pumpAndSettle();
      await _openKeepAJournal(tester);
      var adopt = find.text('ADOPT WHOLE GOAL');
      await tester.scrollUntilVisible(
        adopt,
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(adopt);
      await tester.pumpAndSettle();
      await tester.tap(adopt);
      await tester.pumpAndSettle();

      final journal = state.goals.single;
      expect(journal.openingSeen, isFalse);
      expect(quests, isEmpty);
      await tester.tap(find.byKey(const Key('goal-opening-back')));
      await tester.pumpAndSettle();
      expect(find.byType(GoalOpeningScreen), findsNothing);

      await _openStartingPoints(tester);
      await _openKeepAJournal(tester);
      adopt = find.text('ADD MISSING ACTIONS');
      await tester.scrollUntilVisible(
        adopt,
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(adopt);
      await tester.pumpAndSettle();
      await tester.tap(adopt);
      await tester.pumpAndSettle();

      expect(find.byType(GoalOpeningScreen), findsOneWidget);
      expect(find.byKey(const Key('goal-opening-show-plan')), findsOneWidget);
      expect(journal.openingSeen, isFalse);
      expect(quests, isEmpty);
    },
  );

  testWidgets('detail quest row pops then opens that exact quest', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    final goal = Goal(title: 'Build a habit', stat: Stat.dis, target: 25);
    state.goals.add(goal);
    final quest = Quest(
      title: 'Put clothes away',
      stat: Stat.dis,
      difficulty: 1,
      goalTitle: goal.title,
    );
    Quest? opened;
    await _pumpGoals(
      tester,
      state: state,
      quests: [quest],
      onOpenQuest: (value) => opened = value,
    );

    await tester.tap(find.byKey(const Key('focus-goal-review')));
    await tester.pumpAndSettle();
    expect(find.byType(GoalDetailScreen), findsOneWidget);
    final row = find.byKey(ValueKey('goal-detail-quest-${quest.title}'));
    await tester.scrollUntilVisible(
      row,
      360,
      maxScrolls: 12,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.byType(GoalDetailScreen), findsNothing);
    expect(identical(opened, quest), isTrue);
  });

  testWidgets('support stays one quiet disclosure away', (tester) async {
    final state = GameState()..reduceMotion = true;
    final quests = <Quest>[];
    Quest? opened;
    await _pumpGoals(
      tester,
      state: state,
      quests: quests,
      onOpenQuest: (quest) => opened = quest,
    );

    expect(find.byKey(const Key('goals-support-toggle')), findsOneWidget);
    expect(find.byKey(const Key('goals-unstick-me')), findsNothing);
    expect(find.byKey(const Key('goals-guided-workouts')), findsNothing);

    await tester.tap(find.byKey(const Key('goals-support-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goals-unstick-me')), findsOneWidget);
    expect(find.byKey(const Key('goals-guided-workouts')), findsOneWidget);

    await tester.tap(find.byKey(const Key('goals-unstick-me')));
    await tester.pumpAndSettle();
    expect(find.text('Unstick Me'), findsWidgets);
    expect(find.byKey(const ValueKey('momentum-kit-text')), findsOneWidget);
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('goals-guided-workouts')));
    await tester.pumpAndSettle();
    expect(quests.where((quest) => quest.workout), hasLength(1));
    expect(opened?.workout, isTrue);
  });

  testWidgets('another goal exchanges into the folio instead of teleporting', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = false;
    final first = Goal(title: 'Tend the apartment', stat: Stat.dis, target: 25);
    final second = Goal(
      title: 'Read books slowly',
      stat: Stat.intl,
      target: 25,
    );
    state.goals.addAll([first, second]);
    state.featuredGoalTitles.add(first.title);
    await _pumpGoals(tester, state: state, quests: []);

    final disclosure = find.byKey(const Key('other-goals-disclosure'));
    await tester.scrollUntilVisible(
      disclosure,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(disclosure);
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey('active-goal-read books slowly'));
    await tester.scrollUntilVisible(
      row,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(row);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('goal-folio-tend the apartment')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('goal-folio-read books slowly')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 160));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('goal-folio-read books slowly')),
      findsOneWidget,
    );
    expect(find.byType(GoalDetailScreen), findsNothing);
  });

  testWidgets('a hard-day version creates a linked due-today Quest directly', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 8, 25, 10));
    addTearDown(Clock.reset);
    final state = GameState()..reduceMotion = true;
    final goal = Goal(
      title: 'Keep the kitchen calm',
      stat: Stat.dis,
      target: 25,
      fallbackCue: 'the whole room feels like too much',
      fallbackAction: 'clear one small surface',
    );
    state.goals.add(goal);
    final parked = Quest(
      title: 'Weekly kitchen reset',
      stat: Stat.dis,
      difficulty: 2,
      goalTitle: goal.title,
      snoozedDay: '2026-08-25',
    );
    final quests = <Quest>[parked];
    await _pumpGoals(tester, state: state, quests: quests);

    expect(find.textContaining('clear one'), findsOneWidget);
    expect(find.text('Open Quest'), findsOneWidget);
    expect(quests, hasLength(1));
    await tester.tap(find.byKey(const Key('focus-goal-action')));
    await tester.pumpAndSettle();
    expect(quests, hasLength(2));
    final fallback = quests.last;
    expect(fallback.title, 'clear one small surface');
    expect(fallback.goalTitle, goal.title);
    expect(fallback.schedule, QuestSchedule.once);
    expect(fallback.dueDate, DateTime(2026, 8, 25));
    expect(fallback.difficulty, 1);

    // Returning to the same lighter action reuses the linked Quest.
    await tester.tap(find.byKey(const Key('focus-goal-action')));
    await tester.pumpAndSettle();
    expect(quests, hasLength(2));
  });

  testWidgets(
    'fallback reuses a snoozed linked Quest and clears today snooze',
    (tester) async {
      Clock.freeze(DateTime(2026, 8, 25, 10));
      addTearDown(Clock.reset);
      final state = GameState()..reduceMotion = true;
      final goal = Goal(
        title: 'Keep mornings gentle',
        stat: Stat.vit,
        target: 25,
        fallbackAction: 'open the curtains and drink water',
      );
      state.goals.add(goal);
      final fallback = Quest(
        title: 'Open the curtains and drink water',
        stat: Stat.vit,
        difficulty: 1,
        schedule: QuestSchedule.once,
        dueDate: DateTime(2026, 8, 25),
        snoozedDay: '2026-08-25',
        goalTitle: goal.title,
      );
      Quest? opened;
      await _pumpGoals(
        tester,
        state: state,
        quests: [fallback],
        onOpenQuest: (value) => opened = value,
      );

      expect(find.text('Open Quest'), findsOneWidget);
      await tester.tap(find.byKey(const Key('focus-goal-action')));
      await tester.pumpAndSettle();

      expect(identical(opened, fallback), isTrue);
      expect(fallback.snoozedDay, isNull);
    },
  );

  testWidgets('fallback collision gets a unique goal-linked title', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 8, 25, 10));
    addTearDown(Clock.reset);
    final state = GameState()..reduceMotion = true;
    final goal = Goal(
      title: 'Keep the kitchen calm',
      stat: Stat.dis,
      target: 25,
      fallbackAction: 'clear one small surface',
    );
    state.goals.add(goal);
    final unrelated = Quest(
      title: 'Clear one small surface',
      stat: Stat.dis,
      difficulty: 1,
    );
    final quests = <Quest>[unrelated];
    Quest? opened;
    await _pumpGoals(
      tester,
      state: state,
      quests: quests,
      onOpenQuest: (value) => opened = value,
    );

    await tester.tap(find.byKey(const Key('focus-goal-action')));
    await tester.pumpAndSettle();

    expect(quests, hasLength(2));
    expect(
      quests.last.title,
      'clear one small surface · Keep the kitchen calm',
    );
    expect(quests.last.goalTitle, goal.title);
    expect(identical(opened, quests.last), isTrue);
  });

  testWidgets(
    'goal support remains optional, editable, and visible on return',
    (tester) async {
      final state = GameState()..reduceMotion = true;
      final goal = Goal(
        title: 'Make mornings gentler',
        stat: Stat.vit,
        target: 25,
      );
      state.goals.add(goal);
      await _pumpGoals(tester, state: state, quests: []);

      await tester.tap(find.byKey(const Key('focus-goal-review')));
      await tester.pumpAndSettle();
      final support = find.byKey(const Key('goal-support-plan'));
      await tester.scrollUntilVisible(
        support,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(support);
      await tester.pumpAndSettle();
      await tester.tap(support);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('goal-support-why')),
        'I want to arrive in the day without rushing.',
      );
      await tester.enterText(
        find.byKey(const Key('goal-support-cue')),
        'I wake up depleted',
      );
      await tester.enterText(
        find.byKey(const Key('goal-support-action')),
        'open the curtains and drink water',
      );
      await tester.tap(find.byKey(const Key('goal-support-save')));
      await tester.pumpAndSettle();

      expect(goal.why, 'I want to arrive in the day without rushing.');
      expect(goal.fallbackCue, 'I wake up depleted');
      expect(goal.fallbackAction, 'open the curtains and drink water');
      Navigator.of(tester.element(find.byType(GoalDetailScreen))).pop();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('open the curtains and drink water'),
        findsOneWidget,
      );
    },
  );

  testWidgets('quick composer routes advanced creation to the full wizard', (
    tester,
  ) async {
    await _pumpGoals(
      tester,
      state: GameState()..reduceMotion = true,
      quests: [],
    );

    await tester.tap(find.byKey(const Key('goals-create-first')));
    await tester.pumpAndSettle();
    final advanced = find.byKey(const Key('quick-goal-advanced'));
    await tester.ensureVisible(advanced);
    await tester.tap(advanced);
    await tester.pumpAndSettle();

    expect(find.byType(GoalWizardScreen), findsOneWidget);
  });

  testWidgets('advanced creation returns into the same one-time opening', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    final quests = <Quest>[];
    await _pumpGoals(tester, state: state, quests: quests);

    await tester.tap(find.byKey(const Key('goals-create-first')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('quick-goal-advanced')));
    await tester.tap(find.byKey(const Key('quick-goal-advanced')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Learn to sketch');
    await tester.scrollUntilVisible(
      find.byKey(const Key('goal-wizard-add-quest')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -170));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal-wizard-add-quest')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ember-title')),
      'Draw one object on the desk',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add →'));
    await tester.pump();
    await tester.tap(find.text('Add →'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('ember-title')), findsNothing);

    await tester.tap(find.text('DRAFT THIS ROUTE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(state.goals, hasLength(1));
    expect(state.goals.single.title, 'Learn to sketch');
    expect(state.goals.single.openingSeen, isFalse);
    expect(quests, isEmpty);
    expect(find.byType(GoalOpeningScreen), findsOneWidget);
    expect(find.text('Draw one object on the desk'), findsWidgets);

    await _enterWorkshop(tester);
    await tester.ensureVisible(find.byKey(const Key('goal-workshop-accept')));
    await tester.tap(find.byKey(const Key('goal-workshop-accept')));
    await tester.pumpAndSettle();
    expect(quests, hasLength(1));
    expect(quests.single.title, 'Draw one object on the desk');
    expect(quests.single.schedule, QuestSchedule.daily);
  });

  testWidgets(
    'meaningful repair returns directly to the workshop before a revised Quest exists',
    (tester) async {
      Clock.freeze(DateTime(2026, 8, 28, 10));
      addTearDown(Clock.reset);
      final state = GameState()..reduceMotion = true;
      final plan = GoalPlanner.draft(
        GoalPlanInput(
          title: 'Make the apartment feel calm',
          stat: Stat.dis,
          type: GoalRouteType.reset,
          outcome: 'The kitchen is usable after ordinary days',
          startingPoint: 'The counter is crowded',
          successProof: 'One clear surface stays usable for a week',
          timeBudgetMinutes: 15,
          obstacleCue: 'the whole room feels too big after class',
          now: Clock.now(),
        ),
      );
      final goal = Goal(
        title: 'Make the apartment feel calm',
        stat: Stat.dis,
        target: 4,
        plan: plan,
        openingSeen: true,
      );
      state.goals.add(goal);
      final current = plan.currentStep!;
      final completedProof = Quest(
        title: 'Earlier proof',
        stat: Stat.dis,
        difficulty: 1,
        schedule: QuestSchedule.once,
        goalTitle: goal.title,
        goalPlanStepId: current.id,
        goalPlanRevision: plan.revision,
        goalPlanAttempt: 1,
        lastDoneDay: Days.key(Clock.now()),
      );
      final staleUnfinished = GoalPlanner.questFor(
        goal,
        GoalPlanner.decide(goal, const [], Clock.now())!,
        Clock.now(),
      );
      final quests = <Quest>[completedProof, staleUnfinished];
      await _pumpGoals(tester, state: state, quests: quests);

      await tester.tap(find.byKey(const Key('goals-open-workshop')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'goal-workshop-home-goal-Make the apartment feel calm',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('goal-workshop-screen')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('goal-workshop-rework-route')),
      );
      await tester.tap(find.byKey(const Key('goal-workshop-rework-route')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('goal-plan-signal-tooBig')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('goal-workshop-screen')), findsOneWidget);
      expect(
        find.byKey(const Key('goal-opening-show-plan')).hitTestable(),
        findsNothing,
      );
      expect(goal.openingSeen, isTrue);
      expect(goal.plan!.revision, plan.revision + 1);
      expect(quests, contains(completedProof));
      expect(quests, isNot(contains(staleUnfinished)));
      expect(
        quests.where((quest) => quest.goalPlanRevision == goal.plan!.revision),
        isEmpty,
      );

      await tester.ensureVisible(find.byKey(const Key('goal-workshop-accept')));
      await tester.tap(find.byKey(const Key('goal-workshop-accept')));
      await tester.pumpAndSettle();

      expect(goal.openingSeen, isTrue);
      expect(
        quests.where((quest) => quest.goalPlanRevision == goal.plan!.revision),
        hasLength(1),
      );
    },
  );

  testWidgets('quest-board handoff puts the requested due quest first', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 8, 25, 10));
    addTearDown(Clock.reset);
    final state = GameState()..reduceMotion = true;
    final firstByDefault = Quest(
      title: 'Easy warm-up',
      stat: Stat.dis,
      difficulty: 1,
    );
    final requested = Quest(
      title: 'Requested deep work',
      stat: Stat.foc,
      difficulty: 5,
    );
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestsPage(
            state: state,
            quests: [firstByDefault, requested],
            focusQuestTitle: requested.title,
            focusRequestId: 1,
            onRefresh: () => 0,
            onPersist: () {},
            onAdd: (_) => true,
            onRemove: (_) {},
            onSnapshot: () => '',
            onRestore: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final requestedCard = find.byKey(ValueKey('card-${requested.title}'));
    final otherCard = find.byKey(ValueKey('card-${firstByDefault.title}'));
    expect(requestedCard, findsOneWidget);
    expect(otherCard, findsOneWidget);
    expect(find.byKey(const ValueKey('quest-arrival-1')), findsOneWidget);
    expect(
      tester.getTopLeft(requestedCard).dy,
      lessThan(tester.getTopLeft(otherCard).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'workout door enters the canonical runner even after one session',
    (tester) async {
      Clock.freeze(DateTime(2026, 8, 25, 10));
      addTearDown(Clock.reset);
      final state = GameState()..reduceMotion = true;
      final launcher = workoutLauncherQuest()
        ..lastDoneDay = Days.key(Clock.now());
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestsPage(
              state: state,
              quests: [launcher],
              workoutRequestId: 1,
              onRefresh: () => 0,
              onPersist: () {},
              onAdd: (_) => true,
              onRemove: (_) {},
              onSnapshot: () => '',
              onRestore: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(Motion.ack);

      expect(find.byType(WorkoutFlow), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Goals room camera progresses through the registered landmarks', (
    tester,
  ) async {
    final state = GameState();
    final goal = Goal(
      title: 'Make the apartment feel calm',
      stat: Stat.dis,
      target: 25,
      progress: 11,
    );
    state.goals.add(goal);
    Quest? opened;
    final quests = <Quest>[
      Quest(
        title: 'Clear the kitchen counter',
        stat: Stat.dis,
        difficulty: 2,
        goalTitle: goal.title,
      ),
    ];
    await _pumpGoals(
      tester,
      state: state,
      quests: quests,
      onOpenQuest: (value) => opened = value,
    );

    await tester.tap(find.byKey(const Key('focus-goal-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1640));
    expect(opened, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    expect(identical(opened, quests.single), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Goals narrow large text can enter detail without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });

    final state = GameState();
    final goal = Goal(
      title: 'Make the apartment feel calmer',
      stat: Stat.dis,
      target: 25,
      progress: 4,
    );
    state.goals.add(goal);
    final quests = <Quest>[
      Quest(
        title: 'Clear one small surface',
        stat: Stat.dis,
        difficulty: 2,
        goalTitle: goal.title,
      ),
    ];
    Quest? opened;
    await _pumpGoals(
      tester,
      state: state,
      size: const Size(320, 568),
      textScale: 1.5,
      quests: quests,
      onOpenQuest: (value) => opened = value,
    );

    final action = find.byKey(
      const Key('focus-goal-action'),
      skipOffstage: false,
    );
    await tester.scrollUntilVisible(
      action,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    // The compact layout keeps the action in the scrollable folio. Invoke the
    // same production callback after the layout/overflow check; hit testing
    // remains covered by the existing 430px journey tests.
    tester.widget<GoalPrimaryButton>(action).onTap();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1640));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(GoalDetailScreen), findsNothing);
    expect(tester.takeException(), isNull);
    expect(identical(opened, quests.single), isTrue);
  });
}
