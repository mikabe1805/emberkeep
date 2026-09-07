import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/goal_planner.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/goals.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => Sfx.instance.soundEnabled = false);
  tearDown(() {
    Sfx.instance.soundEnabled = true;
    Clock.reset();
  });

  for (final hasCurrentQuest in [false, true]) {
    testWidgets(
      'Workshop stays reachable with ${hasCurrentQuest ? 'an owned Quest' : 'no goals'} and preserves today',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final now = DateTime(2026, 9, 6, 10);
        Clock.freeze(now);
        final state = GameState()..reduceMotion = true;
        final quests = <Quest>[];
        if (hasCurrentQuest) {
          final plan = GoalPlanner.fromActions(
            title: 'Learn sketching',
            stat: Stat.foc,
            type: GoalRouteType.skill,
            actions: const ['Sketch one object'],
            now: now,
          );
          state.goals.add(
            Goal(
              title: 'Learn sketching',
              stat: Stat.foc,
              target: 8,
              openingSeen: true,
              plan: plan,
            ),
          );
          quests.add(
            Quest(
              title: 'Sketch one object',
              stat: Stat.foc,
              difficulty: 2,
              goalTitle: 'Learn sketching',
              goalPlanStepId: plan.currentStep!.id,
              goalPlanRevision: plan.revision,
              goalPlanAttempt: 1,
              priorityDay: Days.key(now),
              priorityRank: 1,
            ),
          );
        }
        final before = state.toJson();
        final questBefore = [for (final quest in quests) quest.toJson()];
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: GoalsPage(
                state: state,
                quests: quests,
                onAdd: (_) =>
                    throw StateError('Opening Workshop must not add a Quest'),
                onRemoveQuest: (_) {},
                onRemoveGoal: (_) {},
                onPersist: () {},
                onOpenQuest: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final entry = find.byKey(const Key('goals-open-workshop'));
        expect(entry.hitTestable(), findsOneWidget);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('goal-workshop-home')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('goal-workshop-home-back')));
        await tester.pumpAndSettle();
        expect(entry.hitTestable(), findsOneWidget);
        expect(state.toJson(), before);
        expect([for (final quest in quests) quest.toJson()], questBefore);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
