import 'dart:convert';

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/goal_planner.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/goal_workshop.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Goal _plannedGoal(String title, Stat stat) {
  final plan = GoalPlanner.draft(
    GoalPlanInput(
      title: title,
      stat: stat,
      type: GoalRouteType.finish,
      outcome: '$title leaves visible proof',
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

Future<void> _pumpWorkshop(
  WidgetTester tester, {
  required GameState state,
  required List<Quest> quests,
  Size size = const Size(430, 932),
  double textScale = 1,
  ValueChanged<Goal>? onOpenGoal,
  ValueChanged<Goal>? onBuildRoute,
  ValueChanged<Goal>? onFocusGoal,
  VoidCallback? onNewGoal,
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
      home: GoalWorkshopScreen(
        state: state,
        quests: quests,
        onOpenGoal: (goal) async => onOpenGoal?.call(goal),
        onBuildRoute: (goal) async => onBuildRoute?.call(goal),
        onFocusGoal: onFocusGoal ?? (_) {},
        onNewGoal: () async => onNewGoal?.call(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    Clock.freeze(DateTime(2026, 8, 29, 10));
    Sfx.instance.soundEnabled = false;
  });
  tearDown(() {
    Clock.reset();
    Sfx.instance.soundEnabled = true;
  });

  testWidgets(
    'mixed register conversation follows route priority without mutation',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final state = GameState()
        ..reduceMotion = true
        ..soundEnabled = false;
      final owned = _plannedGoal('Finish the portfolio', Stat.foc);
      final waiting = _plannedGoal('Make the apartment feel calm', Stat.dis);
      final needsRoute = Goal(
        title: 'Read books that stay with me',
        stat: Stat.foc,
        target: 25,
      );
      final completePlan = _plannedGoal(
        'Build a walking habit',
        Stat.vit,
      ).plan!;
      final routeComplete = Goal(
        title: 'Build a walking habit',
        stat: Stat.vit,
        kind: GoalKind.achieve,
        target: 4,
        plan: completePlan.copyWith(
          steps: [
            for (final step in completePlan.steps)
              step.copyWith(completions: step.requiredCompletions),
          ],
        ),
      );
      state.goals.addAll([owned, waiting, needsRoute, routeComplete]);
      final ownedDecision = GoalPlanner.decide(owned, const [], Clock.now())!;
      final quests = <Quest>[
        GoalPlanner.questFor(owned, ownedDecision, Clock.now()),
      ];
      final goalsBefore = jsonEncode([
        for (final goal in state.goals) goal.toJson(),
      ]);
      final questsBefore = jsonEncode([
        for (final quest in quests) quest.toJson(),
      ]);
      var routeCallbacks = 0;
      var newGoalCallbacks = 0;

      await _pumpWorkshop(
        tester,
        state: state,
        quests: quests,
        onOpenGoal: (_) => routeCallbacks++,
        onBuildRoute: (_) => routeCallbacks++,
        onFocusGoal: (_) => routeCallbacks++,
        onNewGoal: () => newGoalCallbacks++,
      );

      await tester.tap(find.byKey(const Key('goal-workshop-talk')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('goal-workshop-conversation')),
        findsOneWidget,
      );
      expect(find.text('What is waiting for me?'), findsOneWidget);
      expect(find.text('What makes a good cut?'), findsOneWidget);
      expect(find.text('What if today changes?'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'goal-workshop-conversation-option-waiting-cut',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('is the cut waiting for Make the apartment'),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(
              find.byKey(const Key('goal-workshop-conversation-response')),
            )
            .label,
        contains('only an offer.'),
      );
      expect(
        tester
            .getSemantics(
              find.byKey(const Key('goal-workshop-conversation-response')),
            )
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('goal-workshop-conversation-option-good-cut'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Small enough to begin'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(
          const ValueKey<String>(
            'goal-workshop-conversation-option-changing-day',
          ),
        ),
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'goal-workshop-conversation-option-changing-day',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Finished marks stay'), findsOneWidget);

      await tester.tap(find.byKey(const Key('goal-workshop-talk')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>(
            'goal-workshop-home-goal-Make the apartment feel calm',
          ),
        ),
        findsOneWidget,
      );
      expect(
        jsonEncode([for (final goal in state.goals) goal.toJson()]),
        goalsBefore,
      );
      expect(
        jsonEncode([for (final quest in quests) quest.toJson()]),
        questsBefore,
      );
      expect(routeCallbacks, 0);
      expect(newGoalCallbacks, 0);
      semantics.dispose();
    },
  );

  testWidgets('empty and completed benches tell the truth and assign nothing', (
    tester,
  ) async {
    final empty = GameState()
      ..reduceMotion = true
      ..soundEnabled = false;
    var callbackCount = 0;
    await _pumpWorkshop(
      tester,
      state: empty,
      quests: const [],
      onOpenGoal: (_) => callbackCount++,
      onBuildRoute: (_) => callbackCount++,
      onFocusGoal: (_) => callbackCount++,
      onNewGoal: () => callbackCount++,
    );
    await tester.tap(find.byKey(const Key('goal-workshop-talk')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey<String>('goal-workshop-conversation-option-empty-bench'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('An empty bench is allowed'), findsOneWidget);
    expect(callbackCount, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final completed = GameState()
      ..reduceMotion = true
      ..soundEnabled = false;
    final drafted = _plannedGoal('Build a walking habit', Stat.vit).plan!;
    completed.goals.add(
      Goal(
        title: 'Build a walking habit',
        stat: Stat.vit,
        kind: GoalKind.achieve,
        target: 4,
        plan: drafted.copyWith(
          steps: [
            for (final step in drafted.steps)
              step.copyWith(completions: step.requiredCompletions),
          ],
        ),
      ),
    );
    await _pumpWorkshop(tester, state: completed, quests: const []);
    await tester.tap(find.byKey(const Key('goal-workshop-talk')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'goal-workshop-conversation-option-route-complete',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('has enough proof for this route'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Nothing new is being assigned'),
      findsOneWidget,
    );
  });

  testWidgets('compact large text keeps every conversation action reachable', (
    tester,
  ) async {
    final state = GameState()
      ..reduceMotion = true
      ..soundEnabled = false;
    state.goals.add(_plannedGoal('Make the apartment feel calm', Stat.dis));
    await _pumpWorkshop(
      tester,
      state: state,
      quests: const [],
      size: const Size(320, 568),
      textScale: 1.5,
    );

    await tester.tap(find.byKey(const Key('goal-workshop-talk')));
    await tester.pumpAndSettle();
    final conversationScroll = find.descendant(
      of: find.byKey(
        const PageStorageKey<String>('goal-workshop-conversation-scroll'),
      ),
      matching: find.byType(Scrollable),
    );
    expect(conversationScroll, findsOneWidget);
    for (final entry in const {
      'waiting-cut': 'only an offer',
      'good-cut': 'Small enough to begin',
      'changing-day': 'Finished marks stay',
    }.entries) {
      final option = find.byKey(
        ValueKey<String>('goal-workshop-conversation-option-${entry.key}'),
      );
      expect(option, findsOneWidget);
      await tester.scrollUntilVisible(
        option,
        100,
        scrollable: conversationScroll,
      );
      await tester.pumpAndSettle();
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('goal-workshop-conversation-response')),
        findsOneWidget,
      );
      expect(find.textContaining(entry.value), findsOneWidget);
    }
    expect(
      find.byKey(const Key('goal-workshop-home-new-goal')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('goal-workshop-talk')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('goal-workshop-talk')));
    await tester.pumpAndSettle();
    expect(find.text('CUT WAITING'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
