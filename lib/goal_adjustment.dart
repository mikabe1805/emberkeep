import 'dart:convert';

import 'engine.dart';
import 'goal_planner.dart';
import 'models.dart';

/// Why an adjustment could not be accepted against the live save.
enum GoalAdjustmentRejection {
  goalIsNoLongerLive,
  dayChanged,
  planChanged,
  actionChanged,
  originalQuestChanged,
  replacementAlreadyExists,
}

class GoalAdjustmentAcceptResult {
  const GoalAdjustmentAcceptResult._({this.replacement, this.rejection});

  const GoalAdjustmentAcceptResult.accepted(Quest replacement)
    : this._(replacement: replacement);

  const GoalAdjustmentAcceptResult.rejected(GoalAdjustmentRejection rejection)
    : this._(rejection: rejection);

  final Quest? replacement;
  final GoalAdjustmentRejection? rejection;

  bool get accepted => replacement != null;
}

/// A reviewable proposal. Its public models are defensive copies: opening,
/// editing, or cancelling a review cannot mutate the live save by accident.
class GoalAdjustmentDraft {
  GoalAdjustmentDraft._({
    required this._state,
    required this._goal,
    required this.signal,
    required this.day,
    required this.originalRevision,
    required this.originalStepId,
    required this.originalAttempt,
    required this.originalAction,
    required this.originalProof,
    required this._originalPlanFingerprint,
    required this._originalStepFingerprint,
    required this._originalQuestFingerprint,
    required GoalPlan originalPlan,
    required Quest? originalQuest,
    required GoalPlan revisedPlan,
    required Quest replacementQuest,
    required this._liveOriginalQuest,
  }) : _originalPlan = _clonePlan(originalPlan),
       _originalQuest = originalQuest == null
           ? null
           : _cloneQuest(originalQuest),
       _revisedPlan = _clonePlan(revisedPlan),
       _replacementQuest = _cloneQuest(replacementQuest);

  final GameState _state;
  final Goal _goal;
  final GoalPlanSignal signal;
  final String day;
  final int originalRevision;
  final String originalStepId;
  final int originalAttempt;
  final String originalAction;
  final String originalProof;
  final String _originalPlanFingerprint;
  final String _originalStepFingerprint;
  final String? _originalQuestFingerprint;
  final GoalPlan _originalPlan;
  final Quest? _originalQuest;
  final GoalPlan _revisedPlan;
  final Quest _replacementQuest;
  final Quest? _liveOriginalQuest;

  Quest? get originalQuest =>
      _originalQuest == null ? null : _cloneQuest(_originalQuest);

  GoalPlan get revisedPlan => _clonePlan(_revisedPlan);

  /// The concrete action that this review currently proposes.
  String get currentAction => _revisedPlan.currentStep!.actionTitle;

  String get proposedAction => currentAction;

  /// Route evidence already earned before this proposal was drafted.
  ///
  /// A recovery proposal starts its temporary step at zero, so the review
  /// reads this from the original snapshot rather than the revised plan.
  int get originalRecordedCompletions => _originalPlan.steps.fold<int>(
    0,
    (total, step) =>
        total + step.completions.clamp(0, step.requiredCompletions),
  );

  String? get restoresAfterRecovery =>
      _revisedPlan.currentStep?.resumeAfterRecovery?.actionTitle;

  /// The exact Quest that acceptance will put on the board, including timer
  /// and today's field metadata.
  Quest get replacementQuest => _cloneQuest(_replacementQuest);

  GoalAdjustmentDraft withActionTitle(String actionTitle) {
    final editedPlan = GoalPlanner.editCurrentActionDraft(
      plan: _revisedPlan,
      actionTitle: actionTitle,
    );
    final editedQuest = GoalAdjustment._replacementFor(
      goal: _goal,
      revisedPlan: editedPlan,
      originalQuest: _originalQuest,
      now: Days.parse(day),
    );
    return GoalAdjustmentDraft._(
      state: _state,
      goal: _goal,
      signal: signal,
      day: day,
      originalRevision: originalRevision,
      originalStepId: originalStepId,
      originalAttempt: originalAttempt,
      originalAction: originalAction,
      originalProof: originalProof,
      originalPlanFingerprint: _originalPlanFingerprint,
      originalStepFingerprint: _originalStepFingerprint,
      originalQuestFingerprint: _originalQuestFingerprint,
      originalPlan: _originalPlan,
      originalQuest: _originalQuest,
      revisedPlan: editedPlan,
      replacementQuest: editedQuest,
      liveOriginalQuest: _liveOriginalQuest,
    );
  }
}

/// Builds and accepts one bounded plan replacement. Drafting is pure;
/// acceptance first reconciles every live identity used by the preview, then
/// performs one synchronous Quest/plan replacement.
abstract final class GoalAdjustment {
  static GoalAdjustmentDraft buildDraft({
    required GameState state,
    required Goal goal,
    required List<Quest> quests,
    required GoalPlanSignal signal,
    required DateTime now,
    GoalPlan? revisedPlan,
  }) {
    if (!state.goals.contains(goal)) {
      throw StateError('The goal is not part of this save.');
    }
    if (signal == GoalPlanSignal.completed) {
      throw StateError('Completion is earned through a Quest, not adjustment.');
    }
    final plan = goal.plan;
    final step = plan?.currentStep;
    if (plan == null || step == null || plan.complete) {
      throw StateError('A live plan is required to draft an adjustment.');
    }

    final attempt = step.completions + 1;
    final matching = quests
        .where(
          (quest) =>
              _same(quest.goalTitle, goal.title) &&
              quest.goalPlanStepId == step.id &&
              quest.goalPlanRevision == plan.revision &&
              (quest.goalPlanAttempt ?? 1) == attempt &&
              !quest.doneFor(now),
        )
        .toList(growable: false);
    if (matching.length > 1) {
      throw StateError(
        'More than one unfinished Quest owns this route attempt.',
      );
    }
    final originalQuest = matching.firstOrNull;
    if (originalQuest != null &&
        !_same(originalQuest.displayTitle, step.actionTitle)) {
      throw StateError('The live Quest action no longer matches the plan.');
    }

    final proposed = revisedPlan ?? GoalPlanner.recalibrate(goal, signal, now);
    if (proposed.revision != plan.revision + 1 ||
        proposed.currentStep == null ||
        proposed.complete ||
        proposed.lastSignal != signal ||
        proposed.adjustments.isEmpty ||
        proposed.adjustments.last.signal != signal) {
      throw StateError('The proposed plan must own the next live revision.');
    }
    final replacement = _replacementFor(
      goal: goal,
      revisedPlan: proposed,
      originalQuest: originalQuest,
      now: now,
    );

    return GoalAdjustmentDraft._(
      state: state,
      goal: goal,
      signal: signal,
      day: Days.key(now),
      originalRevision: plan.revision,
      originalStepId: step.id,
      originalAttempt: attempt,
      originalAction: step.actionTitle,
      originalProof: step.proof,
      originalPlanFingerprint: _fingerprint(plan.toJson()),
      originalStepFingerprint: _fingerprint(step.toJson()),
      originalQuestFingerprint: originalQuest == null
          ? null
          : _fingerprint(originalQuest.toJson()),
      originalPlan: plan,
      originalQuest: originalQuest,
      revisedPlan: proposed,
      replacementQuest: replacement,
      liveOriginalQuest: originalQuest,
    );
  }

  static GoalAdjustmentAcceptResult accept({
    required GameState state,
    required Goal goal,
    required List<Quest> quests,
    required GoalAdjustmentDraft draft,
    required DateTime now,
  }) {
    if (!identical(draft._state, state) ||
        !identical(draft._goal, goal) ||
        !state.goals.contains(goal)) {
      return const GoalAdjustmentAcceptResult.rejected(
        GoalAdjustmentRejection.goalIsNoLongerLive,
      );
    }
    if (Days.key(now) != draft.day) {
      return const GoalAdjustmentAcceptResult.rejected(
        GoalAdjustmentRejection.dayChanged,
      );
    }
    final livePlan = goal.plan;
    final liveStep = livePlan?.currentStep;
    if (livePlan == null ||
        liveStep == null ||
        livePlan.complete ||
        livePlan.revision != draft.originalRevision ||
        liveStep.id != draft.originalStepId ||
        liveStep.completions + 1 != draft.originalAttempt) {
      return const GoalAdjustmentAcceptResult.rejected(
        GoalAdjustmentRejection.planChanged,
      );
    }
    if (!_same(liveStep.actionTitle, draft.originalAction)) {
      return const GoalAdjustmentAcceptResult.rejected(
        GoalAdjustmentRejection.actionChanged,
      );
    }
    if (_fingerprint(liveStep.toJson()) != draft._originalStepFingerprint) {
      return const GoalAdjustmentAcceptResult.rejected(
        GoalAdjustmentRejection.planChanged,
      );
    }
    if (_fingerprint(livePlan.toJson()) != draft._originalPlanFingerprint) {
      return const GoalAdjustmentAcceptResult.rejected(
        GoalAdjustmentRejection.planChanged,
      );
    }

    final exactLiveQuests = quests
        .where(
          (quest) =>
              _same(quest.goalTitle, goal.title) &&
              quest.goalPlanStepId == draft.originalStepId &&
              quest.goalPlanRevision == draft.originalRevision &&
              (quest.goalPlanAttempt ?? 1) == draft.originalAttempt &&
              !quest.doneFor(now),
        )
        .toList(growable: false);
    final liveOriginal = draft._liveOriginalQuest;
    if (liveOriginal == null) {
      if (exactLiveQuests.isNotEmpty) {
        return const GoalAdjustmentAcceptResult.rejected(
          GoalAdjustmentRejection.replacementAlreadyExists,
        );
      }
    } else if (exactLiveQuests.length != 1 ||
        !identical(exactLiveQuests.single, liveOriginal) ||
        _fingerprint(liveOriginal.toJson()) !=
            draft._originalQuestFingerprint) {
      return const GoalAdjustmentAcceptResult.rejected(
        GoalAdjustmentRejection.originalQuestChanged,
      );
    }

    final replacementStep = draft._revisedPlan.currentStep!;
    final replacementAttempt = replacementStep.completions + 1;
    if (quests.any(
      (quest) =>
          _same(quest.goalTitle, goal.title) &&
          quest.goalPlanStepId == replacementStep.id &&
          quest.goalPlanRevision == draft._revisedPlan.revision &&
          (quest.goalPlanAttempt ?? 1) == replacementAttempt &&
          !identical(quest, liveOriginal) &&
          !quest.doneFor(now),
    )) {
      return const GoalAdjustmentAcceptResult.rejected(
        GoalAdjustmentRejection.replacementAlreadyExists,
      );
    }

    final replacement = _cloneQuest(draft._replacementQuest);
    // This explicit review is the Workshop acceptance for a dormant first
    // Quest. Make the opening durable before the single notifying write so
    // listeners never observe the accepted Quest with an unopened route.
    goal.openingSeen = true;
    if (liveOriginal == null) {
      quests.add(replacement);
    } else {
      quests[quests.indexOf(liveOriginal)] = replacement;
    }
    // This is the only notifying write. Listeners therefore observe the new
    // plan and its accepted Quest together, after every stale check passed.
    state.updateGoalPlan(goal, draft._revisedPlan);
    return GoalAdjustmentAcceptResult.accepted(replacement);
  }

  static Quest _replacementFor({
    required Goal goal,
    required GoalPlan revisedPlan,
    required Quest? originalQuest,
    required DateTime now,
  }) {
    final previewGoal = Goal.fromJson(goal.toJson())
      ..plan = _clonePlan(revisedPlan);
    final decision = GoalPlanner.decide(previewGoal, const [], now);
    if (decision == null) {
      throw StateError('The proposed plan has no current action.');
    }
    final generated = GoalPlanner.questFor(previewGoal, decision, now);
    if (originalQuest == null) return generated;
    final data = Map<String, dynamic>.from(generated.toJson())
      ..['priority'] = originalQuest.priority
      ..['priorityDay'] = originalQuest.priorityDay
      ..['priorityRank'] = originalQuest.priorityRank
      ..['log'] = [for (final note in originalQuest.log) note.toJson()];
    return Quest.fromJson(data);
  }
}

GoalPlan _clonePlan(GoalPlan plan) => GoalPlan(
  type: plan.type,
  outcome: plan.outcome,
  startingPoint: plan.startingPoint,
  successProof: plan.successProof,
  timeBudgetMinutes: plan.timeBudgetMinutes,
  horizon: plan.horizon,
  obstacleCue: plan.obstacleCue,
  fallbackAction: plan.fallbackAction,
  steps: [for (final step in plan.steps) _clonePlanStep(step)],
  createdDay: plan.createdDay,
  revision: plan.revision,
  cyclesCompleted: plan.cyclesCompleted,
  lastSignal: plan.lastSignal,
  adjustments: [
    for (final adjustment in plan.adjustments)
      GoalPlanAdjustment(
        day: adjustment.day,
        signal: adjustment.signal,
        fromAction: adjustment.fromAction,
        toAction: adjustment.toAction,
      ),
  ],
);

GoalPlanStep _clonePlanStep(GoalPlanStep step) => GoalPlanStep(
  id: step.id,
  title: step.title,
  actionTitle: step.actionTitle,
  proof: step.proof,
  whyNow: step.whyNow,
  ctaLabel: step.ctaLabel,
  minutes: step.minutes,
  kind: step.kind,
  requiredCompletions: step.requiredCompletions,
  completions: step.completions,
  masteryCompletions: step.masteryCompletions,
  completedDay: step.completedDay,
  resumeAfterRecovery: step.resumeAfterRecovery == null
      ? null
      : _clonePlanStep(step.resumeAfterRecovery!),
  questTemplate: step.questTemplate == null
      ? null
      : _cloneQuest(step.questTemplate!),
);

Quest _cloneQuest(Quest quest) => Quest(
  title: quest.title,
  stat: quest.stat,
  difficulty: quest.difficulty,
  dread: quest.dread,
  ladderHint: quest.ladderHint,
  schedule: quest.schedule,
  verification: quest.verification,
  timerMinutes: quest.timerMinutes,
  custom: quest.custom,
  dueDate: quest.dueDate,
  lastDoneDay: quest.lastDoneDay,
  snoozedDay: quest.snoozedDay,
  goalTitle: quest.goalTitle,
  goalPlanStepId: quest.goalPlanStepId,
  goalPlanRevision: quest.goalPlanRevision,
  goalPlanAttempt: quest.goalPlanAttempt,
  priority: quest.priority,
  priorityDay: quest.priorityDay,
  priorityRank: quest.priorityRank,
  allDay: quest.allDay,
  weekdays: [...quest.weekdays],
  monthDay: quest.monthDay,
  rising: quest.rising,
  risingStreak: quest.risingStreak,
  autoRise: quest.autoRise,
  masteryCompletions: quest.masteryCompletions,
  ladder: quest.ladder == null ? null : [...quest.ladder!],
  rung: quest.rung,
  kin: quest.kin == null ? null : [...quest.kin!],
  bonus: quest.bonus,
  origin: quest.origin,
  workout: quest.workout,
  journalPrompt: quest.journalPrompt == null
      ? null
      : JournalQuestPrompt(
          starter: quest.journalPrompt!.starter,
          hint: quest.journalPrompt!.hint,
        ),
  createdDay: quest.createdDay,
  log: [
    for (final note in quest.log)
      Note(
        id: note.id,
        at: note.at,
        text: note.text,
        context: note.context,
        editedAt: note.editedAt,
        images: [...note.images],
        rich: note.rich,
        trace: note.trace,
        night: note.night,
        sourceQuestKey: note.sourceQuestKey,
      ),
  ],
);

String _fingerprint(Map<String, dynamic> value) => jsonEncode(value);

bool _same(String? a, String? b) =>
    (a ?? '').trim().toLowerCase() == (b ?? '').trim().toLowerCase();
