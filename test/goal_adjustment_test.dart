import 'package:emberkeep/engine.dart';
import 'package:emberkeep/goal_adjustment.dart';
import 'package:emberkeep/goal_planner.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 6, 10);

  ({GameState state, Goal goal, Quest quest, List<Quest> quests}) fixture({
    int timerMinutes = 10,
    Verification verification = Verification.timer,
    int completions = 0,
  }) {
    final template = Quest(
      title: 'Sketch one object',
      stat: Stat.intl,
      difficulty: 3,
      schedule: QuestSchedule.daily,
      verification: verification,
      timerMinutes: timerMinutes,
      custom: true,
    );
    final step = GoalPlanStep(
      id: 'step-1',
      title: 'Practice the bottleneck',
      actionTitle: 'Sketch one object',
      proof: 'One dated sketch exists',
      whyNow: 'One ordinary attempt gives the route honest evidence.',
      ctaLabel: 'SKETCH NOW',
      minutes: 10,
      kind: GoalPlanStepKind.practice,
      requiredCompletions: 3,
      completions: completions,
      questTemplate: template,
    );
    final plan = GoalPlan(
      type: GoalRouteType.skill,
      outcome: 'Draw familiar objects with confidence',
      startingPoint: 'Simple forms are still difficult',
      successProof: 'Three dated sketches show clearer form',
      timeBudgetMinutes: 10,
      obstacleCue: 'a full practice feels too large',
      fallbackAction: 'Outline one object for five minutes',
      steps: [step],
      createdDay: Days.key(now),
    );
    final goal = Goal(
      title: 'Learn to sketch',
      stat: Stat.intl,
      target: 3,
      plan: plan,
      openingSeen: true,
    );
    final state = GameState()..addGoal(goal);
    final quest = GoalPlanner.questFor(
      goal,
      GoalPlanner.decide(goal, const [], now)!,
      now,
    );
    return (state: state, goal: goal, quest: quest, quests: [quest]);
  }

  test('building, editing, and cancelling a draft are pure', () {
    final f = fixture();
    final beforeState = f.state.toJson();
    final beforeQuests = [for (final quest in f.quests) quest.toJson()];
    var notifications = 0;
    f.state.addListener(() => notifications++);

    final draft = GoalAdjustment.buildDraft(
      state: f.state,
      goal: f.goal,
      quests: f.quests,
      signal: GoalPlanSignal.tooBig,
      now: now,
    );
    final edited = draft.withActionTitle('Outline the mug for five minutes');

    expect(draft.originalRevision, 1);
    expect(draft.originalQuest!.displayTitle, 'Sketch one object');
    expect(edited.currentAction, 'Outline the mug for five minutes');
    expect(f.state.toJson(), beforeState);
    expect([for (final quest in f.quests) quest.toJson()], beforeQuests);
    expect(notifications, 0);
  });

  test('draft keeps earned evidence when a recovery step resets to zero', () {
    final f = fixture(completions: 1);
    final recalibrated = GoalPlanner.recalibrate(
      f.goal,
      GoalPlanSignal.tooBig,
      now,
    );
    final revisedSteps = [...recalibrated.steps];
    revisedSteps[recalibrated.currentStepIndex] = recalibrated.currentStep!
        .copyWith(completions: 0);
    final revised = recalibrated.copyWith(steps: revisedSteps);

    final draft = GoalAdjustment.buildDraft(
      state: f.state,
      goal: f.goal,
      quests: f.quests,
      signal: GoalPlanSignal.tooBig,
      now: now,
      revisedPlan: revised,
    );

    expect(draft.revisedPlan.currentStep!.completions, 0);
    expect(draft.originalRecordedCompletions, 1);
  });

  test('legacy normalization does not make an edited draft falsely stale', () {
    final f = fixture(completions: 1);
    final original = f.quest;
    final normalizationProneQuest = Quest(
      title: original.title,
      stat: original.stat,
      difficulty: original.difficulty,
      schedule: original.schedule,
      verification: original.verification,
      timerMinutes: original.timerMinutes,
      custom: false,
      goalTitle: original.goalTitle,
      goalPlanStepId: original.goalPlanStepId,
      goalPlanRevision: original.goalPlanRevision,
      goalPlanAttempt: original.goalPlanAttempt,
      rising: true,
      risingStreak: Quest.risesAt,
      autoRise: true,
      ladder: const ['Sketch one object', 'Sketch two objects'],
    );
    f.quests[0] = normalizationProneQuest;
    expect(f.goal.plan!.currentStep!.masteryCompletions, 0);
    expect(normalizationProneQuest.rung, 0);

    final draft = GoalAdjustment.buildDraft(
      state: f.state,
      goal: f.goal,
      quests: f.quests,
      signal: GoalPlanSignal.tooBig,
      now: now,
    ).withActionTitle('Outline the cup for five minutes');
    final result = GoalAdjustment.accept(
      state: f.state,
      goal: f.goal,
      quests: f.quests,
      draft: draft,
      now: now,
    );

    expect(result.accepted, isTrue);
    expect(
      result.replacement!.displayTitle,
      'Outline the cup for five minutes',
    );
    expect(f.goal.plan!.steps.single.masteryCompletions, 0);
  });

  test('an action changed during review rejects without a partial write', () {
    final f = fixture();
    final draft = GoalAdjustment.buildDraft(
      state: f.state,
      goal: f.goal,
      quests: f.quests,
      signal: GoalPlanSignal.tooBig,
      now: now,
    );
    f.goal.plan = GoalPlanner.editCurrentActionDraft(
      plan: f.goal.plan!,
      actionTitle: 'A newer live action',
    );
    final livePlan = f.goal.plan!.toJson();
    final liveQuests = [for (final quest in f.quests) quest.toJson()];

    final result = GoalAdjustment.accept(
      state: f.state,
      goal: f.goal,
      quests: f.quests,
      draft: draft,
      now: now,
    );

    expect(result.accepted, isFalse);
    expect(result.rejection, GoalAdjustmentRejection.actionChanged);
    expect(f.goal.plan!.toJson(), livePlan);
    expect([for (final quest in f.quests) quest.toJson()], liveQuests);
  });

  test('a stale revision rejects without removing or adding a Quest', () {
    final f = fixture();
    final draft = GoalAdjustment.buildDraft(
      state: f.state,
      goal: f.goal,
      quests: f.quests,
      signal: GoalPlanSignal.tooBig,
      now: now,
    );
    f.goal.plan = GoalPlanner.recalibrate(f.goal, GoalPlanSignal.noTime, now);
    final livePlan = f.goal.plan!.toJson();
    final liveQuest = f.quests.single;

    final result = GoalAdjustment.accept(
      state: f.state,
      goal: f.goal,
      quests: f.quests,
      draft: draft,
      now: now,
    );

    expect(result.rejection, GoalAdjustmentRejection.planChanged);
    expect(f.goal.plan!.toJson(), livePlan);
    expect(f.quests, [same(liveQuest)]);
  });

  test(
    'accept replaces only the exact Quest and preserves field, proof, and notes',
    () {
      final f = fixture();
      f.quest
        ..priorityDay = Days.key(now)
        ..priorityRank = 2
        ..addNote('The ellipse is where I got stuck', now);
      final goalNote = Note(at: now, text: 'I want this to feel observational');
      f.goal.notes = [goalNote];
      final completedProof = Quest(
        title: 'Earlier contour study',
        stat: Stat.intl,
        difficulty: 2,
        schedule: QuestSchedule.once,
        goalTitle: f.goal.title,
        goalPlanStepId: 'earlier-step',
        goalPlanRevision: 1,
        goalPlanAttempt: 1,
        lastDoneDay: Days.key(now),
      );
      final tomorrow = DateTime(2026, 9, 7);
      final unrelated = Quest(
        title: 'Read ten pages',
        stat: Stat.intl,
        difficulty: 2,
        priorityDay: Days.key(tomorrow),
        priorityRank: 1,
      );
      f.quests.addAll([completedProof, unrelated]);
      final xpBefore = f.state.totalXp;
      final todayXpBefore = f.state.todayXp;
      final historyBefore = Map<String, int>.from(f.state.history);
      final draft = GoalAdjustment.buildDraft(
        state: f.state,
        goal: f.goal,
        quests: f.quests,
        signal: GoalPlanSignal.tooBig,
        now: now,
      );

      final result = GoalAdjustment.accept(
        state: f.state,
        goal: f.goal,
        quests: f.quests,
        draft: draft,
        now: now,
      );

      expect(result.accepted, isTrue);
      final replacement = result.replacement!;
      expect(f.quests, hasLength(3));
      expect(
        f.quests,
        containsAll(<Quest>[completedProof, unrelated, replacement]),
      );
      expect(f.quests, isNot(contains(f.quest)));
      expect(replacement.priorityDay, Days.key(now));
      expect(replacement.priorityRank, 2);
      expect(replacement.latestNote!.text, 'The ellipse is where I got stuck');
      expect(f.goal.notes.single.id, goalNote.id);
      expect(completedProof.lastDoneDay, Days.key(now));
      expect(unrelated.priorityDay, Days.key(tomorrow));
      expect(unrelated.priorityRank, 1);
      expect(f.state.totalXp, xpBefore);
      expect(f.state.todayXp, todayXpBefore);
      expect(f.state.history, historyBefore);
    },
  );

  test(
    'recovery runs for five minutes and restores the ten-minute practice',
    () {
      final f = fixture();
      final draft = GoalAdjustment.buildDraft(
        state: f.state,
        goal: f.goal,
        quests: f.quests,
        signal: GoalPlanSignal.tooBig,
        now: now,
      ).withActionTitle('Outline one object');

      expect(draft.replacementQuest.verification, Verification.timer);
      expect(draft.replacementQuest.effectiveTimerMinutes, 5);
      expect(draft.replacementQuest.goalPlanRevision, 2);
      expect(draft.replacementQuest.goalPlanAttempt, 1);
      expect(draft.restoresAfterRecovery, 'Sketch one object');

      final accepted = GoalAdjustment.accept(
        state: f.state,
        goal: f.goal,
        quests: f.quests,
        draft: draft,
        now: now,
      );
      final recovery = accepted.replacement!;
      f.state.commit(f.state.roll(recovery));

      final restoredStep = f.goal.plan!.currentStep!;
      expect(restoredStep.actionTitle, 'Sketch one object');
      expect(restoredStep.completions, 1);
      expect(restoredStep.resumeAfterRecovery, isNull);
      final regular = GoalPlanner.questFor(
        f.goal,
        GoalPlanner.decide(f.goal, const [], now)!,
        now,
      );
      expect(regular.verification, Verification.timer);
      expect(regular.effectiveTimerMinutes, 10);
      expect(regular.goalPlanRevision, 2);
      expect(regular.goalPlanAttempt, 2);
    },
  );

  test('route minutes never turn an ordinary action into a timer', () {
    final f = fixture(verification: Verification.honor, timerMinutes: 0);
    final ordinary = GoalPlanner.questFor(
      f.goal,
      GoalPlanner.decide(f.goal, const [], now)!,
      now,
    );
    final recovery = GoalAdjustment.buildDraft(
      state: f.state,
      goal: f.goal,
      quests: f.quests,
      signal: GoalPlanSignal.tooBig,
      now: now,
    ).replacementQuest;

    expect(ordinary.verification, Verification.honor);
    expect(ordinary.timerMinutes, 0);
    expect(recovery.verification, Verification.honor);
    expect(recovery.timerMinutes, 0);
  });

  test('a dormant first Quest appears only after review acceptance', () {
    final f = fixture();
    f.quests.clear();
    f.goal.openingSeen = false;
    final draft = GoalAdjustment.buildDraft(
      state: f.state,
      goal: f.goal,
      quests: f.quests,
      signal: GoalPlanSignal.noTime,
      now: now,
    );

    expect(f.quests, isEmpty);
    expect(draft.originalQuest, isNull);
    expect(f.goal.openingSeen, isFalse);

    final result = GoalAdjustment.accept(
      state: f.state,
      goal: f.goal,
      quests: f.quests,
      draft: draft,
      now: now,
    );

    expect(result.accepted, isTrue);
    expect(f.quests, [same(result.replacement)]);
    expect(f.goal.openingSeen, isTrue);
  });
}
