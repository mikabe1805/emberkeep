import 'models.dart';
import 'tokens.dart';

/// Inputs Room of Days can actually defend when it drafts a route. The app
/// never pretends a title alone is enough to understand somebody's aim.
class GoalPlanInput {
  const GoalPlanInput({
    required this.title,
    required this.stat,
    required this.type,
    required this.outcome,
    required this.startingPoint,
    required this.successProof,
    required this.timeBudgetMinutes,
    required this.obstacleCue,
    required this.now,
    this.horizon,
  });

  final String title;
  final Stat stat;
  final GoalRouteType type;
  final String outcome;
  final String startingPoint;
  final String successProof;
  final int timeBudgetMinutes;
  final String obstacleCue;
  final String? horizon;
  final DateTime now;
}

class GoalActionDecision {
  const GoalActionDecision({
    required this.plan,
    required this.step,
    required this.actionTitle,
    required this.whyThisOne,
    required this.ctaLabel,
    required this.routePosition,
    this.quest,
  });

  final GoalPlan plan;
  final GoalPlanStep step;
  final String actionTitle;
  final String whyThisOne;
  final String ctaLabel;
  final String routePosition;
  final Quest? quest;
}

enum _GoalDomain {
  home,
  movement,
  study,
  creative,
  admin,
  people,
  care,
  general,
}

/// A local, deterministic route engine. It is intentionally inspectable: the
/// selected action is the first incomplete route marker that fits the time
/// budget, not a mysterious recommendation or a title-keyword substitute.
abstract final class GoalPlanner {
  static GoalPlan draft(GoalPlanInput input) {
    final budget = input.timeBudgetMinutes.clamp(5, 120);
    final domain = _domainFor(input);
    final first = _firstAction(input, domain, budget);
    final fallback = _fallbackAction(input, domain);
    final steps = switch (input.type) {
      GoalRouteType.finish => _finishSteps(input, first, budget),
      GoalRouteType.skill => _skillSteps(input, first, budget),
      GoalRouteType.routine => _routineSteps(input, first, budget),
      GoalRouteType.reset => _resetSteps(input, first, budget, domain),
    };
    final routedSteps = [...steps];
    routedSteps[0] = routedSteps.first.copyWith(
      whyNow: _firstWhy(input, domain),
    );
    return GoalPlan(
      type: input.type,
      outcome: _clean(input.outcome),
      startingPoint: _clean(input.startingPoint),
      successProof: _clean(input.successProof),
      timeBudgetMinutes: budget,
      horizon: _optional(input.horizon),
      obstacleCue: _clean(input.obstacleCue),
      fallbackAction: fallback,
      steps: routedSteps,
      createdDay: Days.key(input.now),
    );
  }

  /// Builds a truthful route around actions the person or a curated starting
  /// point already chose. It still adds markers and proof instead of treating
  /// a loose Quest pile as a plan.
  static GoalPlan fromActions({
    required String title,
    required Stat stat,
    required GoalRouteType type,
    required Iterable<String> actions,
    required DateTime now,
    String? outcome,
    String? successProof,
    String? obstacleCue,
    String? fallbackAction,
    Iterable<Quest>? questTemplates,
  }) {
    final kept = actions
        .map(_clean)
        .where((action) => action.isNotEmpty)
        .toList(growable: false);
    final normalized = kept.isEmpty
        ? <String>['Make one real start on $title']
        : kept;
    final templates = questTemplates
        ?.map((quest) => Quest.fromJson(quest.toJson()))
        .toList(growable: false);
    final steps = <GoalPlanStep>[
      for (var i = 0; i < normalized.length; i++)
        GoalPlanStep(
          id: 'step-${i + 1}',
          title: normalized[i],
          actionTitle: normalized[i],
          proof: i == normalized.length - 1
              ? (successProof ?? 'The result is visible in real life')
              : '${normalized[i]} is complete',
          whyNow: i == 0
              ? 'This is the first action in the route you chose.'
              : 'The earlier marker clears the way for this one.',
          ctaLabel: _ctaForAction(normalized[i]),
          minutes: 15,
          kind: i == 0 ? GoalPlanStepKind.prepare : GoalPlanStepKind.act,
          masteryCompletions: templates != null && i < templates.length
              ? templates[i].masteryCompletions
              : 0,
          questTemplate: templates != null && i < templates.length
              ? templates[i]
              : null,
        ),
    ];
    return GoalPlan(
      type: type,
      outcome: outcome ?? title,
      startingPoint: 'Using the actions already chosen',
      successProof: successProof ?? 'The intended result exists in real life',
      timeBudgetMinutes: 15,
      obstacleCue:
          _optional(obstacleCue) ??
          'The full version may ask for more than today has.',
      fallbackAction:
          _optional(fallbackAction) ?? 'Give $title five honest minutes',
      steps: steps,
      createdDay: Days.key(now),
    );
  }

  static GoalActionDecision? decide(
    Goal goal,
    Iterable<Quest> quests,
    DateTime now,
  ) {
    final plan = goal.plan;
    final step = plan?.currentStep;
    if (plan == null || step == null || plan.complete) return null;
    final candidates =
        quests
            .where(
              (quest) =>
                  _same(quest.goalTitle, goal.title) &&
                  quest.goalPlanStepId == step.id &&
                  quest.goalPlanRevision == plan.revision &&
                  (quest.goalPlanAttempt ?? 1) == step.completions + 1 &&
                  questActionableToday(quest, now) &&
                  !quest.doneFor(now),
            )
            .toList(growable: false)
          ..sort((a, b) {
            final priority = a
                .priorityRankOn(now)
                .compareTo(b.priorityRankOn(now));
            if (priority != 0) return priority;
            final date = (a.dueDate ?? DateTime(9999)).compareTo(
              b.dueDate ?? DateTime(9999),
            );
            if (date != 0) return date;
            return a.difficulty.compareTo(b.difficulty);
          });
    return GoalActionDecision(
      plan: plan,
      step: step,
      actionTitle: step.actionTitle,
      whyThisOne: step.whyNow,
      ctaLabel: step.ctaLabel,
      routePosition:
          'MARKER ${plan.currentStepIndex + 1} OF ${plan.steps.length}',
      quest: candidates.isEmpty ? null : candidates.first,
    );
  }

  static Quest questFor(Goal goal, GoalActionDecision decision, DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    final template = decision.step.questTemplate;
    if (template != null) {
      final data = Map<String, dynamic>.from(template.toJson())
        ..['title'] = decision.actionTitle
        ..['stat'] = goal.stat.index
        ..['goalTitle'] = goal.title
        ..['goalPlanStepId'] = decision.step.id
        ..['goalPlanRevision'] = decision.plan.revision
        ..['goalPlanAttempt'] = decision.step.completions + 1
        ..['lastDoneDay'] = null
        ..['snoozedDay'] = null
        ..['priority'] = false
        ..['priorityDay'] = null
        ..['priorityRank'] = null
        ..['risingStreak'] = 0
        ..['masteryCompletions'] =
            decision.step.masteryCompletions > template.masteryCompletions
            ? decision.step.masteryCompletions
            : template.masteryCompletions
        ..['bonus'] = false
        ..['createdDay'] = Days.key(now)
        ..['log'] = const <Object>[];
      if (_clean(template.displayTitle) != _clean(decision.actionTitle)) {
        // An edited or smaller cut keeps its scheduling intent, but an old
        // progression ladder must not replace the action the person accepted.
        data
          ..['ladderHint'] = null
          ..['ladder'] = null
          ..['rung'] = 0
          ..['rising'] = false;
      }
      return Quest.fromJson(data);
    }
    return Quest(
      title: decision.actionTitle,
      stat: goal.stat,
      difficulty: _difficultyForMinutes(decision.step.minutes),
      schedule: QuestSchedule.once,
      dueDate: day,
      custom: true,
      goalTitle: goal.title,
      goalPlanStepId: decision.step.id,
      goalPlanRevision: decision.plan.revision,
      goalPlanAttempt: decision.step.completions + 1,
      masteryCompletions: decision.step.masteryCompletions,
    );
  }

  static bool questActionableToday(Quest quest, DateTime now) {
    if (quest.snoozedDay == Days.key(now)) return false;
    if (quest.isEvent) {
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
      return !quest.dueDate!.isAfter(endOfToday);
    }
    return quest.scheduledOn(now);
  }

  /// Opens another evidence cycle for an ongoing rhythm. The original anchor
  /// stays earned; the workable repeat and review markers return with fresh
  /// route identity so old completed Quests can never satisfy the new cycle.
  static GoalPlan continueRoutine(GoalPlan plan) {
    if (plan.type != GoalRouteType.routine || !plan.complete) {
      throw StateError('A completed routine route is required.');
    }
    final steps = <GoalPlanStep>[];
    for (var index = 0; index < plan.steps.length; index++) {
      final step = plan.steps[index];
      if (index == 0) {
        steps.add(step);
        continue;
      }
      steps.add(
        step.copyWith(
          title: index == 1 ? 'Return to the anchor' : null,
          actionTitle: index == 1
              ? 'Do the workable version of ${_short(plan.outcome)} at the anchor'
              : null,
          whyNow: index == 1
              ? 'The last cycle found a version that fit real days. Begin there and adjust only from fresh evidence.'
              : null,
          ctaLabel: index == 1 ? 'RETURN TO THE ANCHOR' : null,
          completions: 0,
          clearCompletedDay: true,
        ),
      );
    }
    return plan.copyWith(
      steps: steps,
      revision: plan.revision + 1,
      cyclesCompleted: plan.cyclesCompleted + 1,
      lastSignal: GoalPlanSignal.completed,
    );
  }

  static GoalPlan recalibrate(Goal goal, GoalPlanSignal signal, DateTime now) {
    final plan = goal.plan;
    final current = plan?.currentStep;
    if (plan == null || current == null || plan.complete) {
      throw StateError('A live plan is required to recalibrate a goal.');
    }
    final routeMarker = current.resumeAfterRecovery ?? current;
    final changed = switch (signal) {
      GoalPlanSignal.tooBig => current.copyWith(
        actionTitle: plan.fallbackAction,
        whyNow: 'Same marker, smaller move. Your earlier proof stays.',
        ctaLabel: _ctaForAction(plan.fallbackAction),
        minutes: 5,
        kind: GoalPlanStepKind.recover,
        resumeAfterRecovery: routeMarker,
      ),
      GoalPlanSignal.noTime => current.copyWith(
        actionTitle: 'Give ${goal.title} five honest minutes',
        whyNow: 'Five honest minutes keeps the route alive today.',
        ctaLabel: _ctaForAction('Give ${goal.title} five honest minutes'),
        minutes: 5,
        kind: GoalPlanStepKind.recover,
        resumeAfterRecovery: routeMarker,
      ),
      GoalPlanSignal.lowEnergy => current.copyWith(
        actionTitle:
            'Set up the first thing needed for ${_short(plan.outcome)}',
        whyNow: 'Set up the return without asking for the whole action.',
        ctaLabel: _ctaForAction(
          'Set up the first thing needed for ${_short(plan.outcome)}',
        ),
        minutes: 5,
        kind: GoalPlanStepKind.prepare,
        resumeAfterRecovery: routeMarker,
      ),
      GoalPlanSignal.unclear => current.copyWith(
        actionTitle: 'Write the next visible proof for ${_short(plan.outcome)}',
        proof: 'The next result is concrete enough to act on',
        whyNow: 'Make the proof visible before spending more effort.',
        ctaLabel: _ctaForAction(
          'Write the next visible proof for ${_short(plan.outcome)}',
        ),
        minutes: 5,
        kind: GoalPlanStepKind.prepare,
        resumeAfterRecovery: routeMarker,
      ),
      GoalPlanSignal.changed => current.copyWith(
        actionTitle: 'Redefine what done means for ${_short(plan.outcome)}',
        whyNow: 'The aim changed. Pause before effort goes the wrong way.',
        ctaLabel: _ctaForAction(
          'Redefine what done means for ${_short(plan.outcome)}',
        ),
        minutes: 10,
        kind: GoalPlanStepKind.review,
      ),
      GoalPlanSignal.completed => current,
    };
    final steps = [...plan.steps];
    steps[plan.currentStepIndex] = changed;
    return plan.copyWith(
      steps: steps,
      revision: plan.revision + 1,
      lastSignal: signal,
      adjustments: [
        ...plan.adjustments,
        GoalPlanAdjustment(
          day: Days.key(now),
          signal: signal,
          fromAction: current.actionTitle,
          toAction: changed.actionTitle,
        ),
      ],
    );
  }

  static GoalPlan replaceOutcome({
    required Goal goal,
    required String outcome,
    required String successProof,
    required DateTime now,
  }) {
    final old = goal.plan;
    if (old == null) throw StateError('A live plan is required.');
    final rebuilt = draft(
      GoalPlanInput(
        title: goal.title,
        stat: goal.stat,
        type: old.type,
        outcome: outcome,
        startingPoint: old.startingPoint,
        successProof: successProof,
        timeBudgetMinutes: old.timeBudgetMinutes,
        obstacleCue: old.obstacleCue,
        horizon: old.horizon,
        now: now,
      ),
    );
    return rebuilt.copyWith(
      revision: old.revision + 1,
      lastSignal: GoalPlanSignal.changed,
      adjustments: [
        ...old.adjustments,
        GoalPlanAdjustment(
          day: Days.key(now),
          signal: GoalPlanSignal.changed,
          fromAction: old.currentStep?.actionTitle ?? old.outcome,
          toAction: rebuilt.currentStep?.actionTitle ?? outcome,
        ),
      ],
    );
  }

  /// Replaces only the current action while retaining the owned outcome,
  /// earlier proof, route order, and an honest adjustment record.
  static GoalPlan replaceCurrentAction({
    required Goal goal,
    required String actionTitle,
    required DateTime now,
  }) {
    final plan = goal.plan;
    final current = plan?.currentStep;
    final clean = _clean(actionTitle);
    if (plan == null || current == null || plan.complete || clean.isEmpty) {
      throw StateError('A live plan and a concrete action are required.');
    }
    final steps = [...plan.steps];
    steps[plan.currentStepIndex] = current.copyWith(
      actionTitle: clean,
      whyNow:
          'You chose this version of the marker, so the route will use it instead of guessing for you.',
      ctaLabel: _ctaForAction(clean),
      clearResumeAfterRecovery: true,
    );
    return plan.copyWith(
      steps: steps,
      revision: plan.revision + 1,
      lastSignal: GoalPlanSignal.changed,
      adjustments: [
        ...plan.adjustments,
        GoalPlanAdjustment(
          day: Days.key(now),
          signal: GoalPlanSignal.changed,
          fromAction: current.actionTitle,
          toAction: clean,
        ),
      ],
    );
  }

  static List<GoalPlanStep> _finishSteps(
    GoalPlanInput input,
    String first,
    int budget,
  ) => [
    _step(
      1,
      'Lock the finish line',
      first,
      'A concrete starting proof exists',
      'You are starting from ${_short(input.startingPoint)}. This creates the first proof within the time you said is realistic.',
      'MAKE THE START',
      budget,
      GoalPlanStepKind.prepare,
    ),
    _step(
      2,
      'Prepare the work',
      'Gather what the next real piece of ${_short(input.outcome)} needs',
      'The work can begin without another setup decision',
      'The first proof shows what the work actually needs next.',
      'SET IT UP',
      budget,
      GoalPlanStepKind.prepare,
    ),
    _step(
      3,
      'Make the core',
      'Build one real piece toward ${_short(input.successProof)}',
      'A usable piece of the result exists',
      'This spends effort on the result itself, not more planning.',
      'MAKE THE PIECE',
      budget,
      GoalPlanStepKind.act,
      required: 2,
    ),
    _step(
      4,
      'Finish and verify',
      'Complete and check: ${_short(input.successProof)}',
      input.successProof,
      'The route has reached the proof you chose at the start.',
      'CHECK THE PROOF',
      budget,
      GoalPlanStepKind.review,
    ),
  ];

  static List<GoalPlanStep> _skillSteps(
    GoalPlanInput input,
    String first,
    int budget,
  ) => [
    _step(
      1,
      'Take a starting sample',
      first,
      'A baseline attempt exists',
      'From ${_short(input.startingPoint)}, a real sample shows what to practice instead of guessing.',
      'TRY IT ONCE',
      budget,
      GoalPlanStepKind.act,
    ),
    _step(
      2,
      'Practice the bottleneck',
      'Practice the hardest part of ${_short(input.successProof)} for $budget minutes',
      'Three focused practices are kept',
      'The baseline makes this the clearest place to improve.',
      'PRACTICE NOW',
      budget,
      GoalPlanStepKind.practice,
      required: 3,
    ),
    _step(
      3,
      'Use it for real',
      'Make one real attempt at ${_short(input.successProof)}',
      'The skill has been used outside practice',
      'This tests whether practice transferred into something useful.',
      'USE IT FOR REAL',
      budget,
      GoalPlanStepKind.act,
    ),
    _step(
      4,
      'Compare and refine',
      'Compare the real attempt with the starting sample',
      input.successProof,
      'The comparison turns effort into a specific next refinement.',
      'REVIEW THE PROOF',
      budget,
      GoalPlanStepKind.review,
    ),
  ];

  static List<GoalPlanStep> _routineSteps(
    GoalPlanInput input,
    String first,
    int budget,
  ) => [
    _step(
      1,
      'Choose the anchor',
      first,
      'A when-and-where cue is chosen',
      'Because ${_short(input.startingPoint)}, the route begins by giving the routine a real place in an ordinary day.',
      'SET THE ANCHOR',
      budget,
      GoalPlanStepKind.prepare,
    ),
    _step(
      2,
      'Make the first repeat easy',
      'Do the $budget-minute version of ${_short(input.outcome)} at the anchor',
      'The first honest repetition is kept',
      'The first repeat tests the route before it asks for consistency.',
      'DO THE FIRST ONE',
      budget,
      GoalPlanStepKind.practice,
    ),
    _step(
      3,
      'Repeat while it fits',
      'Repeat the same workable version',
      'Three repetitions fit real days',
      'A few real repeats are better evidence than a perfect schedule on paper.',
      'KEEP THE RHYTHM',
      budget,
      GoalPlanStepKind.practice,
      required: 3,
    ),
    _step(
      4,
      'Review the fit',
      'Keep, shrink, or move the routine after three tries',
      input.successProof,
      'The route changes from evidence instead of blaming the person.',
      'REVIEW THE FIT',
      10,
      GoalPlanStepKind.review,
    ),
  ];

  static List<GoalPlanStep> _resetSteps(
    GoalPlanInput input,
    String first,
    int budget,
    _GoalDomain domain,
  ) => [
    _step(
      1,
      'Choose the visible standard',
      first,
      'One clear before-and-after change is chosen',
      'Starting from ${_short(input.startingPoint)}, a visible standard stops the reset from expanding without an edge.',
      'CHOOSE THE STANDARD',
      budget,
      GoalPlanStepKind.prepare,
    ),
    _step(
      2,
      _resetActionLabel(domain),
      _resetAction(domain, input, budget),
      _resetProof(domain),
      _resetWhy(domain),
      _resetCta(domain),
      budget,
      GoalPlanStepKind.act,
    ),
    _step(
      3,
      'Stabilize what changed',
      'Repeat the smallest action that keeps the change workable',
      'The reset survives two ordinary returns',
      'A reset matters when it can survive the next real day.',
      'STABILIZE IT',
      budget,
      GoalPlanStepKind.practice,
      required: 2,
    ),
    _step(
      4,
      'Leave a way back',
      'Set up the five-minute return for ${_short(input.outcome)}',
      input.successProof,
      'The route ends with a way back, not a demand for permanent perfection.',
      'LEAVE THE RETURN',
      5,
      GoalPlanStepKind.review,
    ),
  ];

  static String _resetActionLabel(_GoalDomain domain) => switch (domain) {
    _GoalDomain.home => 'Clear one working zone',
    _GoalDomain.study => 'Open one working block',
    _GoalDomain.movement => 'Take one workable movement block',
    _GoalDomain.creative => 'Reopen one working piece',
    _GoalDomain.admin => 'Resolve one open detail',
    _GoalDomain.people => 'Make one repairing contact',
    _GoalDomain.care => 'Set up one care return',
    _GoalDomain.general => 'Change one workable piece',
  };

  static String _resetAction(
    _GoalDomain domain,
    GoalPlanInput input,
    int budget,
  ) {
    final outcome = _short(input.outcome);
    return switch (domain) {
      _GoalDomain.home => 'Reset one $budget-minute zone toward $outcome',
      _GoalDomain.study =>
        'Work one focused $budget-minute study block toward $outcome',
      _GoalDomain.movement =>
        'Do one $budget-minute workable session toward $outcome',
      _GoalDomain.creative =>
        'Make one $budget-minute working piece toward $outcome',
      _GoalDomain.admin => 'Resolve one $budget-minute piece of $outcome',
      _GoalDomain.people => 'Make one $budget-minute repair toward $outcome',
      _GoalDomain.care => 'Set up one $budget-minute support toward $outcome',
      _GoalDomain.general => 'Change one $budget-minute piece toward $outcome',
    };
  }

  static String _resetProof(_GoalDomain domain) => switch (domain) {
    _GoalDomain.home => 'One useful area visibly works better',
    _GoalDomain.study => 'One useful study block is complete',
    _GoalDomain.movement => 'One workable session is complete',
    _GoalDomain.creative => 'One usable piece visibly exists',
    _GoalDomain.admin => 'One open detail is resolved',
    _GoalDomain.people => 'One point of contact is repaired',
    _GoalDomain.care => 'One useful support is ready to return to',
    _GoalDomain.general => 'One useful part of the situation changes',
  };

  static String _resetWhy(_GoalDomain domain) => switch (domain) {
    _GoalDomain.home =>
      'One finished zone creates proof without requiring the whole space.',
    _GoalDomain.study =>
      'One finished block creates proof without requiring the whole subject.',
    _GoalDomain.movement =>
      'One workable session creates proof without requiring a perfect routine.',
    _GoalDomain.creative =>
      'One finished piece creates proof without requiring the whole project.',
    _GoalDomain.admin =>
      'One resolved detail creates proof without requiring every open loop.',
    _GoalDomain.people =>
      'One honest contact creates proof without requiring the whole conversation.',
    _GoalDomain.care =>
      'One prepared support creates proof without requiring a perfect day.',
    _GoalDomain.general =>
      'One finished piece creates proof without requiring the whole situation.',
  };

  static String _resetCta(_GoalDomain domain) => switch (domain) {
    _GoalDomain.home => 'RESET ONE ZONE',
    _GoalDomain.study => 'OPEN ONE BLOCK',
    _GoalDomain.movement => 'TAKE ONE SESSION',
    _GoalDomain.creative => 'REOPEN ONE PIECE',
    _GoalDomain.admin => 'RESOLVE ONE DETAIL',
    _GoalDomain.people => 'MAKE ONE CONTACT',
    _GoalDomain.care => 'SET UP ONE SUPPORT',
    _GoalDomain.general => 'CHANGE ONE PIECE',
  };

  static GoalPlanStep _step(
    int index,
    String title,
    String action,
    String proof,
    String why,
    String cta,
    int minutes,
    GoalPlanStepKind kind, {
    int required = 1,
  }) {
    final exactActionLabel = _ctaForAction(action);
    return GoalPlanStep(
      id: 'step-$index',
      title: title,
      actionTitle: action,
      proof: proof,
      whyNow: why,
      ctaLabel: exactActionLabel.isEmpty ? cta : exactActionLabel,
      minutes: minutes,
      kind: kind,
      requiredCompletions: required,
    );
  }

  static _GoalDomain _domainFor(GoalPlanInput input) {
    final text = '${input.title} ${input.outcome} ${input.successProof}'
        .toLowerCase();
    bool has(String pattern) =>
        RegExp('(^|\\b)${RegExp.escape(pattern)}(\\b|\$)').hasMatch(text);
    if ([
      'apartment',
      'room',
      'home',
      'clean',
      'tidy',
      'organize',
      'organise',
      'kitchen',
      'desk',
    ].any(has)) {
      return _GoalDomain.home;
    }
    if ([
      'run',
      'walk',
      'gym',
      'lift',
      'fitness',
      'strength',
      'yoga',
      'workout',
      'exercise',
      'exercising',
      'movement',
    ].any(has)) {
      return _GoalDomain.movement;
    }
    if ([
      'study',
      'school',
      'exam',
      'quiz',
      'class',
      'classwork',
      'homework',
      'assignment',
      'lecture',
      'textbook',
      'semester',
      'grade',
      'grades',
      'gpa',
      'read',
      'learn',
      'course',
    ].any(has)) {
      return _GoalDomain.study;
    }
    if ([
      'write',
      'draw',
      'paint',
      'build',
      'project',
      'portfolio',
      'code',
      'draft',
      'design',
      'music',
      'guitar',
      'song',
      'compose',
      'composition',
      'illustrate',
      'craft',
      'photograph',
      'film',
      'video',
      'journal',
      'creative',
    ].any(has)) {
      return _GoalDomain.creative;
    }
    if ([
      'email',
      'form',
      'apply',
      'appointment',
      'budget',
      'money',
      'bill',
    ].any(has)) {
      return _GoalDomain.admin;
    }
    if ([
      'friend',
      'family',
      'call',
      'message',
      'relationship',
      'date',
    ].any(has)) {
      return _GoalDomain.people;
    }
    if ([
      'sleep',
      'meal',
      'water',
      'medicine',
      'medication',
      'care',
      'health',
    ].any(has)) {
      return _GoalDomain.care;
    }
    return switch (input.stat) {
      Stat.str => _GoalDomain.movement,
      Stat.intl => _GoalDomain.study,
      Stat.foc => _GoalDomain.creative,
      Stat.soc => _GoalDomain.people,
      Stat.vit => _GoalDomain.care,
      Stat.dis => _GoalDomain.general,
    };
  }

  static String _firstAction(
    GoalPlanInput input,
    _GoalDomain domain,
    int budget,
  ) {
    final outcome = _short(input.outcome);
    final proof = _short(input.successProof);
    final focus = _realityFocus(input.startingPoint, domain);
    if (input.type == GoalRouteType.routine) {
      return 'Choose an existing moment to anchor $outcome, then do the $budget-minute version once';
    }
    if (input.type == GoalRouteType.skill) {
      return switch (domain) {
        _GoalDomain.movement => 'Do one $budget-minute baseline toward $proof',
        _GoalDomain.study =>
          focus == null
              ? 'Try one real question or example toward $proof without preparing first'
              : 'Try one real question from $focus without preparing first',
        _GoalDomain.creative =>
          'Make one unpolished $budget-minute attempt at $proof',
        _ => 'Make one unpolished $budget-minute attempt at $proof',
      };
    }
    return switch (domain) {
      _GoalDomain.home =>
        focus == null
            ? 'Choose one $budget-minute zone that would make $outcome visible'
            : 'Reset the $focus for $budget minutes until one usable patch is visible',
      _GoalDomain.movement => 'Do one $budget-minute baseline toward $proof',
      _GoalDomain.study =>
        focus == null
            ? 'Open the material and answer one real question toward $proof'
            : 'Open $focus and answer one real question toward $proof',
      _GoalDomain.creative =>
        focus == null
            ? 'Make a rough $budget-minute first piece toward $proof'
            : 'Open the $focus and make one rough $budget-minute piece toward $proof',
      _GoalDomain.admin =>
        focus == null
            ? 'Gather the one detail currently blocking $outcome'
            : 'Find the first missing detail for the $focus',
      _GoalDomain.people =>
        'Draft the first message or invitation toward $outcome',
      _GoalDomain.care => 'Set up one $budget-minute support for $outcome',
      _GoalDomain.general =>
        'Create a $budget-minute starting proof toward $outcome',
    };
  }

  static String? _realityFocus(String startingPoint, _GoalDomain domain) {
    final text = _clean(startingPoint).toLowerCase();
    final chapter = RegExp(r'chapter\s+\d+[a-z]?').firstMatch(text);
    if (chapter != null) return chapter.group(0);
    final candidates = switch (domain) {
      _GoalDomain.home => const [
        'counter',
        'sink',
        'entry table',
        'table',
        'desk',
        'floor',
        'laundry',
        'closet',
        'kitchen',
        'bedroom',
      ],
      _GoalDomain.study => const [
        'problem set',
        'assignment',
        'lecture notes',
        'notes',
        'textbook',
        'practice exam',
      ],
      _GoalDomain.creative => const [
        'rough draft',
        'draft',
        'outline',
        'prototype',
        'project file',
        'canvas',
        'page',
      ],
      _GoalDomain.admin => const [
        'application',
        'form',
        'email',
        'bill',
        'appointment',
        'budget',
      ],
      _ => const <String>[],
    };
    for (final candidate in candidates) {
      final index = text.indexOf(candidate);
      if (index < 0) continue;
      final before = text.substring(index > 24 ? index - 24 : 0, index);
      if (RegExp(r'\b(no|not|without)\b[^,.;]{0,16}$').hasMatch(before)) {
        continue;
      }
      return candidate;
    }
    return null;
  }

  static String _fallbackAction(GoalPlanInput input, _GoalDomain domain) {
    final outcome = _short(input.outcome);
    final focus = _realityFocus(input.startingPoint, domain);
    return switch (domain) {
      _GoalDomain.home =>
        focus == null
            ? 'Clear one hand-sized surface'
            : 'Clear one hand-sized patch of the $focus',
      _GoalDomain.movement => 'Put on what you need and move for five minutes',
      _GoalDomain.study => 'Open the material and mark the next question',
      _GoalDomain.creative => 'Open the work and make one rough mark',
      _GoalDomain.admin => 'Find the first document or detail you need',
      _GoalDomain.people => 'Write the first sentence and leave it as a draft',
      _GoalDomain.care => 'Prepare the smallest support for the next return',
      _GoalDomain.general => 'Give $outcome five honest minutes',
    };
  }

  static String _firstWhy(GoalPlanInput input, _GoalDomain domain) {
    final focus = _realityFocus(input.startingPoint, domain);
    if (focus != null) {
      final namedFocus = '${focus[0].toUpperCase()}${focus.substring(1)}';
      return '$namedFocus first. One visible change is proof.';
    }
    return switch (input.type) {
      GoalRouteType.skill => 'Baseline first. It shows what needs practice.',
      GoalRouteType.routine =>
        'Anchor first. Give the routine a real time and place.',
      GoalRouteType.finish => 'Rough proof first. It reveals the real work.',
      GoalRouteType.reset => 'One bounded zone proves the reset can begin.',
    };
  }

  static int _difficultyForMinutes(int minutes) => switch (minutes) {
    <= 5 => 1,
    <= 15 => 2,
    <= 30 => 3,
    <= 60 => 4,
    _ => 5,
  };

  static String _ctaForAction(String action) {
    final clean = _clean(action);
    final lower = clean.toLowerCase();
    if (lower.startsWith('clear one hand-sized')) {
      return 'CLEAR ONE PATCH';
    }
    if (lower.startsWith('choose an existing moment') &&
        lower.contains('anchor')) {
      return 'CHOOSE THE ANCHOR';
    }
    if (lower.startsWith('gather ')) return 'GATHER WHAT YOU NEED';
    if (lower.startsWith('build one real piece')) {
      return 'BUILD THE REAL PIECE';
    }
    if (lower.startsWith('repeat the same workable') ||
        lower.startsWith('repeat the smallest')) {
      return 'REPEAT THE WORKABLE VERSION';
    }
    if (lower.startsWith('complete and check')) return 'CHECK THE FINISH';
    if (lower.startsWith('write the next visible proof')) {
      return 'WRITE THE NEXT PROOF';
    }
    if (lower.startsWith('set up the first thing')) {
      return 'SET UP THE NEXT RETURN';
    }
    if (lower.startsWith('redefine what done means')) {
      return 'RESHAPE THE ROUTE';
    }
    if (lower.startsWith('give ') && lower.contains('five honest minutes')) {
      return 'USE FIVE HONEST MINUTES';
    }
    if (lower.startsWith('draft the first message')) {
      return 'DRAFT THE FIRST MESSAGE';
    }
    final words = clean.split(' ');
    final kept = <String>[];
    const boundaries = {
      'for',
      'until',
      'toward',
      'towards',
      'at',
      'after',
      'before',
      'without',
      'and',
      'then',
      'of',
    };
    for (final word in words) {
      if (kept.length >= 2 && boundaries.contains(word.toLowerCase())) break;
      if (kept.length >= 6) break;
      kept.add(word);
    }
    return kept.isEmpty ? 'BEGIN THIS MOVE' : kept.join(' ').toUpperCase();
  }

  static bool _same(String? a, String b) =>
      a != null && a.trim().toLowerCase() == b.trim().toLowerCase();
  static String _clean(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');
  static String? _optional(String? value) {
    final clean = value == null ? '' : _clean(value);
    return clean.isEmpty ? null : clean;
  }

  static String _short(String value) {
    final clean = _clean(value);
    if (clean.length <= 48) return clean;
    final words = clean.split(' ');
    final kept = <String>[];
    var length = 0;
    for (final word in words) {
      if (length + word.length + (kept.isEmpty ? 0 : 1) > 45) break;
      kept.add(word);
      length += word.length + (kept.length == 1 ? 0 : 1);
    }
    return '${kept.join(' ')}…';
  }
}
