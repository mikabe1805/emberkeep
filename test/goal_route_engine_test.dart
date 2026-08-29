import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/goal_planner.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 27, 10);

  GoalPlanInput homeInput({GoalRouteType type = GoalRouteType.reset}) =>
      GoalPlanInput(
        title: 'Make the apartment feel calm',
        stat: Stat.dis,
        type: type,
        outcome: 'I can use the kitchen without feeling overwhelmed',
        startingPoint:
            'The counter is crowded and I avoid deciding where things go',
        successProof: 'The counter stays usable for a normal week',
        timeBudgetMinutes: 15,
        obstacleCue: 'the whole thing feels too big after class',
        horizon: 'Before the semester begins',
        now: now,
      );

  Goal makeGoal(GoalPlan plan, {GoalKind kind = GoalKind.achieve}) => Goal(
    title: 'Make the apartment feel calm',
    stat: Stat.dis,
    kind: kind,
    target: plan.type == GoalRouteType.routine
        ? 25
        : plan.steps.fold(0, (total, step) => total + step.requiredCompletions),
    plan: plan,
  );

  setUp(() => Clock.freeze(now));
  tearDown(Clock.reset);

  test('draft works backward from outcome, reality, proof, and capacity', () {
    final plan = GoalPlanner.draft(homeInput());

    expect(plan.steps, hasLength(4));
    expect(plan.currentStep!.actionTitle.toLowerCase(), contains('counter'));
    expect(plan.currentStep!.actionTitle, contains('15 minutes'));
    expect(plan.startingPoint.toLowerCase(), contains('crowded'));
    expect(plan.currentStep!.whyNow.toLowerCase(), contains('proof'));
    expect(plan.successProof, contains('normal week'));
    expect(plan.obstacleCue, contains('after class'));
    expect(plan.fallbackAction.toLowerCase(), contains('hand-sized'));
    expect(plan.horizon, 'Before the semester begins');
  });

  test(
    'explicit aim beats the default stat when choosing the first action',
    () {
      final plan = GoalPlanner.draft(
        GoalPlanInput(
          title: 'Finish my portfolio',
          stat: Stat.dis,
          type: GoalRouteType.finish,
          outcome: 'A hiring manager can understand my best two projects',
          startingPoint: 'I have an outline but no rough draft',
          successProof: 'Two project pages are published and readable',
          timeBudgetMinutes: 30,
          obstacleCue: 'I start polishing before the story exists',
          now: now,
        ),
      );

      expect(plan.currentStep!.actionTitle.toLowerCase(), contains('outline'));
      expect(
        plan.currentStep!.actionTitle.toLowerCase(),
        isNot(contains('zone')),
      );
    },
  );

  test('route types produce distinct behavioral structures', () {
    final finish = GoalPlanner.draft(homeInput(type: GoalRouteType.finish));
    final skill = GoalPlanner.draft(homeInput(type: GoalRouteType.skill));
    final routine = GoalPlanner.draft(homeInput(type: GoalRouteType.routine));
    final reset = GoalPlanner.draft(homeInput());

    expect(finish.steps.map((step) => step.title), contains('Make the core'));
    expect(
      skill.steps.map((step) => step.title),
      contains('Practice the bottleneck'),
    );
    expect(
      routine.steps.map((step) => step.title),
      contains('Choose the anchor'),
    );
    expect(
      reset.steps.map((step) => step.title),
      contains('Clear one working zone'),
    );
    expect(routine.steps[2].requiredCompletions, 3);
  });

  test('decision selects only the current marker, revision, and attempt', () {
    final plan = GoalPlanner.draft(homeInput());
    final goal = makeGoal(plan);
    final current = plan.currentStep!;
    final later = plan.steps[1];
    final correct = Quest(
      title: current.actionTitle,
      stat: goal.stat,
      difficulty: 2,
      goalTitle: goal.title,
      goalPlanStepId: current.id,
      goalPlanRevision: plan.revision,
      goalPlanAttempt: 1,
    );
    final wrongAttempt = Quest(
      title: current.actionTitle,
      stat: goal.stat,
      difficulty: 1,
      goalTitle: goal.title,
      goalPlanStepId: current.id,
      goalPlanRevision: plan.revision,
      goalPlanAttempt: 2,
    );
    final laterQuest = Quest(
      title: later.actionTitle,
      stat: goal.stat,
      difficulty: 1,
      goalTitle: goal.title,
      goalPlanStepId: later.id,
      goalPlanRevision: plan.revision,
      goalPlanAttempt: 1,
    );

    final decision = GoalPlanner.decide(goal, [
      laterQuest,
      wrongAttempt,
      correct,
    ], now)!;

    expect(decision.quest, same(correct));
    expect(decision.routePosition, 'MARKER 1 OF 4');
    expect(decision.whyThisOne, current.whyNow);
  });

  test('quest creation stamps exact route identity and attempt', () {
    final plan = GoalPlanner.draft(homeInput());
    final goal = makeGoal(plan);
    final decision = GoalPlanner.decide(goal, const [], now)!;
    final quest = GoalPlanner.questFor(goal, decision, now);

    expect(quest.title, decision.actionTitle);
    expect(quest.goalPlanStepId, decision.step.id);
    expect(quest.goalPlanRevision, plan.revision);
    expect(quest.goalPlanAttempt, 1);
    expect(quest.schedule, QuestSchedule.once);
  });

  test(
    'configured Quest templates stay dormant and survive the workshop handoff',
    () {
      final template = Quest(
        title: 'Sketch at the desk',
        stat: Stat.intl,
        difficulty: 5,
        dread: true,
        schedule: QuestSchedule.weekly,
        verification: Verification.timer,
        timerMinutes: 20,
        custom: true,
        weekdays: const [2, 5],
        rising: true,
        ladder: const ['Sketch at the desk', 'Sketch a room from life'],
      );
      final plan = GoalPlanner.fromActions(
        title: 'Learn to sketch',
        stat: Stat.intl,
        type: GoalRouteType.skill,
        actions: [template.displayTitle],
        questTemplates: [template],
        now: now,
      );
      final restored = Goal.fromJson(
        Goal(
          title: 'Learn to sketch',
          stat: Stat.intl,
          target: 1,
          plan: plan,
          openingSeen: false,
        ).toJson(),
      );

      final offered = GoalPlanner.questFor(
        restored,
        GoalPlanner.decide(restored, const [], now)!,
        now,
      );

      expect(restored.plan!.currentStep!.questTemplate, isNotNull);
      expect(offered.title, 'Sketch at the desk');
      expect(offered.schedule, QuestSchedule.weekly);
      expect(offered.weekdays, [2, 5]);
      expect(offered.difficulty, 5);
      expect(offered.dread, isTrue);
      expect(offered.verification, Verification.timer);
      expect(offered.timerMinutes, 20);
      expect(offered.goalPlanStepId, restored.plan!.currentStep!.id);

      final revised = GoalPlanner.replaceCurrentAction(
        goal: restored,
        actionTitle: 'Draw one mug for five minutes',
        now: now,
      );
      restored.plan = revised;
      final edited = GoalPlanner.questFor(
        restored,
        GoalPlanner.decide(restored, const [], now)!,
        now,
      );
      expect(edited.displayTitle, 'Draw one mug for five minutes');
      expect(edited.schedule, QuestSchedule.weekly);
      expect(edited.weekdays, [2, 5]);
      expect(edited.ladder, isNull);
      expect(edited.rising, isFalse);
    },
  );

  test(
    'only the current route marker can advance or finish a planned goal',
    () {
      final state = GameState();
      final plan = GoalPlanner.draft(homeInput());
      final goal = makeGoal(plan);
      state.addGoal(goal);
      final later = plan.steps[1];
      final outOfOrder = Quest(
        title: later.actionTitle,
        stat: goal.stat,
        difficulty: 1,
        goalTitle: goal.title,
        goalPlanStepId: later.id,
        goalPlanRevision: plan.revision,
        goalPlanAttempt: 1,
      );

      state.commit(state.roll(outOfOrder));
      expect(goal.progress, 0);
      expect(goal.plan!.steps[1].completions, 0);
      expect(goal.complete, isFalse);

      while (!goal.complete) {
        final decision = GoalPlanner.decide(goal, const [], now)!;
        final quest = GoalPlanner.questFor(goal, decision, now);
        state.commit(state.roll(quest));
      }

      expect(goal.plan!.complete, isTrue);
      expect(goal.progress, goal.target);
      expect(goal.achievedDay, '2026-08-27');
    },
  );

  test('a stale pre-adjustment quest cannot move the revised route', () {
    final state = GameState();
    final plan = GoalPlanner.draft(homeInput());
    final goal = makeGoal(plan);
    state.addGoal(goal);
    final oldDecision = GoalPlanner.decide(goal, const [], now)!;
    final oldQuest = GoalPlanner.questFor(goal, oldDecision, now);
    final revised = GoalPlanner.recalibrate(goal, GoalPlanSignal.tooBig, now);
    state.updateGoalPlan(goal, revised);

    state.commit(state.roll(oldQuest));

    expect(goal.progress, 0);
    expect(goal.plan!.currentStep!.completions, 0);
    expect(goal.plan!.revision, plan.revision + 1);
    expect(goal.plan!.adjustments.single.fromAction, oldDecision.actionTitle);
    expect(goal.plan!.currentStep!.minutes, 5);
    final restored = Goal.fromJson(goal.toJson());
    expect(
      restored.plan!.currentStep!.resumeAfterRecovery!.actionTitle,
      oldDecision.actionTitle,
    );
  });

  test('a one-day rescue restores a repeated marker for the next attempt', () {
    final state = GameState();
    final plan = GoalPlanner.draft(homeInput(type: GoalRouteType.routine));
    final goal = makeGoal(plan, kind: GoalKind.become);
    state.addGoal(goal);

    while (goal.plan!.currentStepIndex < 2) {
      final decision = GoalPlanner.decide(goal, const [], now)!;
      state.commit(state.roll(GoalPlanner.questFor(goal, decision, now)));
    }
    final repeatedMarker = goal.plan!.currentStep!;
    state.commit(
      state.roll(
        GoalPlanner.questFor(
          goal,
          GoalPlanner.decide(goal, const [], now)!,
          now,
        ),
      ),
    );
    expect(goal.plan!.currentStep!.completions, 1);

    final rescue = GoalPlanner.recalibrate(goal, GoalPlanSignal.tooBig, now);
    state.updateGoalPlan(goal, rescue);
    expect(goal.plan!.currentStep!.actionTitle, rescue.fallbackAction);

    state.commit(
      state.roll(
        GoalPlanner.questFor(
          goal,
          GoalPlanner.decide(goal, const [], now)!,
          now,
        ),
      ),
    );

    final restored = goal.plan!.currentStep!;
    expect(restored.completions, 2);
    expect(restored.requiredCompletions, 3);
    expect(restored.actionTitle, repeatedMarker.actionTitle);
    expect(restored.kind, repeatedMarker.kind);
    expect(restored.resumeAfterRecovery, isNull);
    expect(
      GoalPlanner.decide(goal, const [], now)!.actionTitle,
      repeatedMarker.actionTitle,
    );
  });

  test('adding a route preserves progress earned before the route existed', () {
    final state = GameState();
    final goal = Goal(
      title: 'Make the apartment feel calm',
      stat: Stat.dis,
      target: 10,
      progress: 7,
    );
    state.addGoal(goal);
    final plan = GoalPlanner.draft(homeInput());
    final routeTarget = plan.steps.fold<int>(
      0,
      (total, step) => total + step.requiredCompletions,
    );

    state.updateGoalPlan(goal, plan);

    expect(goal.progress, 7);
    expect(goal.target, 7 + routeTarget);
    state.commit(
      state.roll(
        GoalPlanner.questFor(
          goal,
          GoalPlanner.decide(goal, const [], now)!,
          now,
        ),
      ),
    );
    expect(goal.progress, 8);
  });

  test(
    'changing the aim rebuilds the route and retains adjustment history',
    () {
      final original = GoalPlanner.draft(homeInput());
      final goal = makeGoal(original);
      final rebuilt = GoalPlanner.replaceOutcome(
        goal: goal,
        outcome: 'The kitchen is ready for two people to cook together',
        successProof: 'We cook dinner together twice without clearing first',
        now: now,
      );

      expect(rebuilt.outcome, contains('two people'));
      expect(rebuilt.successProof, contains('twice'));
      expect(rebuilt.revision, original.revision + 1);
      expect(rebuilt.adjustments.single.signal, GoalPlanSignal.changed);
      expect(
        rebuilt.currentStep!.actionTitle.toLowerCase(),
        contains('counter'),
      );
    },
  );

  test(
    'a completed routine opens a fresh evidence cycle instead of ending',
    () {
      final state = GameState();
      final plan = GoalPlanner.draft(homeInput(type: GoalRouteType.routine));
      final goal = makeGoal(plan, kind: GoalKind.become);
      state.addGoal(goal);

      final firstRevision = plan.revision;
      while (goal.plan!.cyclesCompleted == 0) {
        final decision = GoalPlanner.decide(goal, const [], now)!;
        state.commit(state.roll(GoalPlanner.questFor(goal, decision, now)));
      }

      expect(goal.complete, isFalse);
      expect(goal.plan!.revision, firstRevision + 1);
      expect(goal.plan!.cyclesCompleted, 1);
      expect(goal.plan!.steps.first.complete, isTrue);
      expect(goal.plan!.currentStepIndex, 1);
      expect(goal.plan!.currentStep!.title, 'Return to the anchor');
    },
  );

  test(
    'plan and quest route identity round-trip; legacy goals remain valid',
    () {
      final plan = GoalPlanner.draft(homeInput());
      final restored = Goal.fromJson(makeGoal(plan).toJson());
      final quest = GoalPlanner.questFor(
        restored,
        GoalPlanner.decide(restored, const [], now)!,
        now,
      );
      final restoredQuest = Quest.fromJson(quest.toJson());
      final legacy = Goal.fromJson({
        'title': 'Old goal',
        'stat': Stat.dis.index,
        'target': 25,
      });

      expect(restored.plan!.outcome, plan.outcome);
      expect(
        restored.plan!.steps.first.actionTitle,
        plan.steps.first.actionTitle,
      );
      expect(restoredQuest.goalPlanStepId, plan.steps.first.id);
      expect(restoredQuest.goalPlanRevision, plan.revision);
      expect(restoredQuest.goalPlanAttempt, 1);
      expect(legacy.plan, isNull);
    },
  );
}
