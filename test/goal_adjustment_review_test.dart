import 'package:emberkeep/engine.dart';
import 'package:emberkeep/goal_adjustment.dart';
import 'package:emberkeep/goal_planner.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/goal_adjustment_review.dart';
import 'package:emberkeep/widgets/working_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 9, 6, 10);
const _capture = bool.fromEnvironment('CAPTURE_GOAL_ADJUSTMENT');
const _capturePath = 'goldens/working_adjustment_430x932.png';

Finder get _reviewScrollable => find
    .descendant(
      of: find.byKey(const Key('goal-adjustment-review-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _loadFonts() async {
  final material = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  final garamond = FontLoader('EBGaramond')
    ..addFont(rootBundle.load('assets/google_fonts/EBGaramond-Variable.ttf'));
  final inter = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/google_fonts/Inter-Regular.ttf'))
    ..addFont(rootBundle.load('assets/google_fonts/Inter-Medium.ttf'));
  final mono = FontLoader(
    'JetBrainsMono',
  )..addFont(rootBundle.load('assets/google_fonts/JetBrainsMono-SemiBold.ttf'));
  await Future.wait([
    material.load(),
    garamond.load(),
    inter.load(),
    mono.load(),
  ]);
}

Future<void> _settleWorkingArt(WidgetTester tester) async {
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(
    () => precacheImage(const AssetImage(workingRoomAsset), context),
  );
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

({GameState state, Goal goal, List<Quest> quests, GoalAdjustmentDraft draft})
_fixture({GoalPlanSignal signal = GoalPlanSignal.tooBig}) {
  final template = Quest(
    title: 'Sketch one object',
    stat: Stat.intl,
    difficulty: 3,
    schedule: QuestSchedule.daily,
    verification: Verification.timer,
    timerMinutes: 10,
    custom: true,
  );
  final plan = GoalPlan(
    type: GoalRouteType.skill,
    outcome: 'Draw familiar objects with confidence',
    startingPoint: 'Simple forms are still difficult',
    successProof: 'Three dated sketches show clearer form',
    timeBudgetMinutes: 10,
    obstacleCue: 'a full practice feels too large',
    fallbackAction: 'Draw just the outline',
    steps: [
      GoalPlanStep(
        id: 'step-1',
        title: 'Practice the bottleneck',
        actionTitle: 'Sketch one object',
        proof: 'One dated sketch exists',
        whyNow: 'Leave the details. Keep one rough outline.',
        ctaLabel: 'SKETCH NOW',
        minutes: 10,
        kind: GoalPlanStepKind.practice,
        requiredCompletions: 3,
        completions: 1,
        questTemplate: template,
      ),
    ],
    createdDay: Days.key(_now),
  );
  final goal = Goal(
    title: 'Learn to sketch',
    stat: Stat.intl,
    target: 3,
    progress: 1,
    plan: plan,
    openingSeen: true,
  );
  final state = GameState()..addGoal(goal);
  final quest = GoalPlanner.questFor(
    goal,
    GoalPlanner.decide(goal, const [], _now)!,
    _now,
  );
  final quests = <Quest>[quest];
  final recalibrated = GoalPlanner.recalibrate(goal, signal, _now);
  final revisedSteps = [...recalibrated.steps];
  revisedSteps[recalibrated.currentStepIndex] = recalibrated.currentStep!
      .copyWith(completions: 0);
  final revised = recalibrated.copyWith(steps: revisedSteps);
  final draft = GoalAdjustment.buildDraft(
    state: state,
    goal: goal,
    quests: quests,
    signal: signal,
    now: _now,
    revisedPlan: revised,
  );
  return (state: state, goal: goal, quests: quests, draft: draft);
}

Future<GoalAdjustmentDraft?> _openReview(
  WidgetTester tester,
  GoalAdjustmentDraft draft, {
  Size size = const Size(430, 932),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  GoalAdjustmentDraft? result;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open-review'),
              onPressed: () async {
                result = await showGoalAdjustmentReview(context, draft: draft);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-review')));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('Keep original returns null and leaves transaction untouched', (
    tester,
  ) async {
    final f = _fixture();
    final stateBefore = f.state.toJson();
    final questsBefore = [for (final quest in f.quests) quest.toJson()];
    GoalAdjustmentDraft? returned;

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              returned = await showGoalAdjustmentReview(
                context,
                draft: f.draft,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(f.draft.revisedPlan.currentStep!.completions, 0);
    expect(find.text('Your 1 recorded practice stays.'), findsOneWidget);
    if (_capture) {
      await _settleWorkingArt(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(_capturePath),
      );
    }
    await tester.scrollUntilVisible(
      find.byKey(const Key('goal-adjustment-keep-original')),
      300,
      scrollable: _reviewScrollable,
    );
    await tester.tap(find.byKey(const Key('goal-adjustment-keep-original')));
    await tester.pumpAndSettle();

    expect(returned, isNull);
    expect(f.state.toJson(), stateBefore);
    expect([for (final quest in f.quests) quest.toJson()], questsBefore);
  });

  testWidgets('edited wording is returned as the same proposed route attempt', (
    tester,
  ) async {
    final f = _fixture();
    GoalAdjustmentDraft? returned;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              returned = await showGoalAdjustmentReview(
                context,
                draft: f.draft,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('goal-adjustment-edit-action')),
      240,
      scrollable: _reviewScrollable,
    );
    await tester.tap(find.byKey(const Key('goal-adjustment-edit-action')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('goal-adjustment-edit-field')),
      'Outline the coffee mug',
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('goal-adjustment-accept')),
      300,
      scrollable: _reviewScrollable,
    );
    await tester.tap(find.byKey(const Key('goal-adjustment-accept')));
    await tester.pumpAndSettle();

    expect(returned, isNotNull);
    expect(returned!.currentAction, 'Outline the coffee mug');
    expect(returned!.revisedPlan.revision, f.draft.revisedPlan.revision);
    expect(
      returned!.replacementQuest.goalPlanStepId,
      f.draft.replacementQuest.goalPlanStepId,
    );
    expect(
      returned!.replacementQuest.goalPlanAttempt,
      f.draft.replacementQuest.goalPlanAttempt,
    );
    expect(f.goal.plan!.revision, 1);
    expect(f.quests.single.goalPlanRevision, 1);
  });

  testWidgets('320 wide at 200 percent text scrolls through every action', (
    tester,
  ) async {
    final f = _fixture();
    await _openReview(
      tester,
      f.draft,
      size: const Size(320, 568),
      textScale: 2,
    );

    expect(find.byKey(const Key('goal-adjustment-back')), findsOneWidget);
    expect(
      find.byKey(const Key('goal-adjustment-restoration')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('goal-adjustment-accept')),
      300,
      scrollable: _reviewScrollable,
    );
    expect(
      find.byKey(const Key('goal-adjustment-accept')).hitTestable(),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('goal-adjustment-keep-original')),
      200,
      scrollable: _reviewScrollable,
    );
    expect(
      find.byKey(const Key('goal-adjustment-keep-original')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('changed plans use review language and promise no restoration', (
    tester,
  ) async {
    final f = _fixture(signal: GoalPlanSignal.changed);
    await _openReview(tester, f.draft);

    expect(find.text('Review this change.'), findsOneWidget);
    expect(find.text('PROPOSED CHANGE'), findsOneWidget);
    expect(find.byKey(const Key('goal-adjustment-restoration')), findsNothing);
    expect(find.text('Use this change'), findsOneWidget);
  });
}
