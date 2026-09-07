import 'package:emberkeep/content/quest_suggestions.dart';
import 'package:emberkeep/goal_planner.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

final _day = DateTime(2026, 9, 6, 10);

Quest _quest(
  String title, {
  QuestSchedule schedule = QuestSchedule.daily,
  Verification verification = Verification.honor,
  int timerMinutes = 0,
  bool allDay = false,
  String? snoozedDay,
  String? lastDoneDay,
  String? goalTitle,
  String? stepId,
  int? revision,
  int? attempt,
  bool priority = false,
  String? priorityDay,
  List<int> weekdays = const [],
  DateTime? dueDate,
}) => Quest(
  title: title,
  stat: Stat.foc,
  difficulty: 4,
  schedule: schedule,
  verification: verification,
  timerMinutes: timerMinutes,
  allDay: allDay,
  snoozedDay: snoozedDay,
  lastDoneDay: lastDoneDay,
  goalTitle: goalTitle,
  goalPlanStepId: stepId,
  goalPlanRevision: revision,
  goalPlanAttempt: attempt,
  priority: priority,
  priorityDay: priorityDay,
  weekdays: weekdays,
  dueDate: dueDate,
);

Goal _plannedGoal({bool openingSeen = true, String title = 'Learn sketching'}) {
  final plan = GoalPlanner.draft(
    GoalPlanInput(
      title: title,
      stat: Stat.foc,
      type: GoalRouteType.skill,
      outcome: 'Sketch an object with clear proportions',
      startingPoint: 'I am starting with basic shapes',
      successProof: 'One recognisable object sketch exists',
      timeBudgetMinutes: 15,
      obstacleCue: 'the blank page feels too large',
      now: _day,
    ),
  );
  return Goal(
    title: title,
    stat: Stat.foc,
    target: 6,
    openingSeen: openingSeen,
    plan: plan,
  );
}

void main() {
  test('keeps only exact accepted route work and configured timers', () {
    final goal = _plannedGoal();
    final step = goal.plan!.currentStep!;
    final liveGoalQuest = _quest(
      'Sketch a mug',
      goalTitle: goal.title,
      stepId: step.id,
      revision: goal.plan!.revision,
      attempt: step.completions + 1,
    );
    final timerQuest = _quest(
      'Read ten pages',
      verification: Verification.timer,
      timerMinutes: 10,
    );
    final plainQuest = _quest('Tidy desk');

    final suggestions = suggestQuests(
      candidates: [plainQuest, timerQuest, liveGoalQuest],
      goals: [goal],
      selectedTitles: const {},
      day: _day,
    );

    expect(suggestions.map((item) => item.quest), [liveGoalQuest, timerQuest]);
    expect(suggestions.first.reason, 'Current action for Learn sketching');
    expect(suggestions.first.timerMinutes, isNull);
    expect(suggestions.last.reason, 'Your saved 10-minute session');
    expect(suggestions.last.timerMinutes, 10);
  });

  test('rejects stale revisions but treats an exact board Quest as owned', () {
    final accepted = _plannedGoal();
    final current = accepted.plan!.currentStep!;
    final stale = _quest(
      'Old sketch action',
      verification: Verification.timer,
      timerMinutes: 10,
      goalTitle: accepted.title,
      stepId: current.id,
      revision: accepted.plan!.revision - 1,
      attempt: 1,
    );
    final unaccepted = _plannedGoal(
      openingSeen: false,
      title: 'Practice guitar',
    );
    final proposed = _quest(
      'Proposed sketch action',
      verification: Verification.timer,
      timerMinutes: 10,
      goalTitle: unaccepted.title,
      stepId: unaccepted.plan!.currentStep!.id,
      revision: unaccepted.plan!.revision,
      attempt: 1,
    );

    final suggestions = suggestQuests(
      candidates: [stale, proposed],
      goals: [accepted, unaccepted],
      selectedTitles: const {},
      day: _day,
    );

    expect(suggestions.map((item) => item.quest), [proposed]);
    expect(suggestions.single.reason, 'Current action for Practice guitar');
  });

  test(
    'Browse all excludes stale route work but keeps a live owned action',
    () {
      final goal = _plannedGoal();
      final current = goal.plan!.currentStep!;
      final live = _quest(
        'Sketch now',
        goalTitle: goal.title,
        stepId: current.id,
        revision: goal.plan!.revision,
        attempt: 1,
      );
      final stale = _quest(
        'Sketch before repair',
        goalTitle: goal.title,
        stepId: current.id,
        revision: goal.plan!.revision + 1,
        attempt: 1,
      );

      expect(
        isAvailableSuggestionCandidate(live, goals: [goal], day: _day),
        isTrue,
      );
      expect(
        isAvailableSuggestionCandidate(stale, goals: [goal], day: _day),
        isFalse,
      );
    },
  );

  test(
    'uses the first duplicate title and never suggests an already selected title',
    () {
      final first = _quest('Read ten pages');
      final second = _quest(
        'Read ten pages',
        verification: Verification.timer,
        timerMinutes: 10,
      );

      expect(
        suggestQuests(
          candidates: [first, second],
          goals: const [],
          selectedTitles: const {},
          day: _day,
        ),
        isEmpty,
      );
      expect(
        suggestQuests(
          candidates: [second],
          goals: const [],
          selectedTitles: {'read ten pages'},
          day: _day,
        ),
        isEmpty,
      );
    },
  );

  test('filters to real configured session durations without guessing', () {
    final shortTimer = _quest(
      'Walk',
      verification: Verification.timer,
      timerMinutes: 5,
    );
    final longTimer = _quest(
      'Read',
      verification: Verification.timer,
      timerMinutes: 20,
    );
    final untimedGoal = _plannedGoal();
    final step = untimedGoal.plan!.currentStep!;
    final exactUntimed = _quest(
      'Sketch',
      goalTitle: untimedGoal.title,
      stepId: step.id,
      revision: untimedGoal.plan!.revision,
      attempt: 1,
    );
    final titleOnly = _quest('Meditate 5 minutes');

    final any = suggestQuests(
      candidates: [longTimer, titleOnly, exactUntimed, shortTimer],
      goals: [untimedGoal],
      selectedTitles: const {},
      day: _day,
    );
    expect(any.map((item) => item.quest), [
      exactUntimed,
      shortTimer,
      longTimer,
    ]);
    final bounded = suggestQuests(
      candidates: [longTimer, titleOnly, exactUntimed, shortTimer],
      goals: [untimedGoal],
      selectedTitles: const {},
      day: _day,
      maxMinutes: 10,
    );
    expect(bounded.map((item) => item.quest), [shortTimer]);
  });

  test('excludes tomorrow, completed, snoozed, all-day, and event work', () {
    final tomorrowOnly = _quest('Tomorrow', weekdays: [_day.weekday + 1]);
    final completed = _quest(
      'Done',
      verification: Verification.timer,
      timerMinutes: 10,
      lastDoneDay: Days.key(_day),
    );
    final snoozed = _quest(
      'Set aside',
      verification: Verification.timer,
      timerMinutes: 10,
      snoozedDay: Days.key(_day),
    );
    final allDay = _quest(
      'Hold the line',
      verification: Verification.timer,
      timerMinutes: 10,
      allDay: true,
    );
    final event = _quest(
      'Appointment',
      schedule: QuestSchedule.once,
      verification: Verification.timer,
      timerMinutes: 10,
      dueDate: _day,
    );

    expect(
      suggestQuests(
        candidates: [tomorrowOnly, completed, snoozed, allDay, event],
        goals: const [],
        selectedTitles: const {},
        day: _day,
      ),
      isEmpty,
    );
  });

  test('orders priority before route relevance and short timers stably', () {
    final goal = _plannedGoal();
    final step = goal.plan!.currentStep!;
    final priorityTimer = _quest(
      'Priority reading',
      verification: Verification.timer,
      timerMinutes: 20,
      priorityDay: Days.key(_day),
    );
    final goalQuest = _quest(
      'Sketch',
      goalTitle: goal.title,
      stepId: step.id,
      revision: goal.plan!.revision,
      attempt: 1,
    );
    final shortTimer = _quest(
      'Short timer',
      verification: Verification.timer,
      timerMinutes: 5,
    );
    final laterShortTimer = _quest(
      'Later short timer',
      verification: Verification.timer,
      timerMinutes: 5,
    );

    final suggestions = suggestQuests(
      candidates: [laterShortTimer, goalQuest, priorityTimer, shortTimer],
      goals: [goal],
      selectedTitles: const {},
      day: _day,
    );

    expect(suggestions.map((item) => item.quest), [
      priorityTimer,
      goalQuest,
      laterShortTimer,
      shortTimer,
    ]);
  });
}
