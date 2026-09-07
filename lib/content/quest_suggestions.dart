import '../models.dart';

/// A transparent reason for bringing an already-available Quest into focus.
///
/// Suggestions are deliberately conservative: the policy only surfaces a
/// Quest when the current save can point to either the exact accepted goal
/// marker it serves or a countdown the Quest is configured to run.
class QuestSuggestion {
  const QuestSuggestion({
    required this.quest,
    required this.reason,
    required this.timerMinutes,
  });

  final Quest quest;
  final String reason;

  /// The countdown this Quest actually runs, when it has one.
  final int? timerMinutes;
}

/// Finds a small, explainable subset of today's available ordinary Quests.
///
/// This does not learn from dismissals or infer duration from titles,
/// difficulty, or a goal route's capacity estimate. Untimed Quests can appear
/// in an unbounded browse, but a bounded session filter only admits real timer
/// sessions. Duplicate titles deliberately resolve to the first source Quest,
/// matching the existing title-keyed daily-field writer.
List<QuestSuggestion> suggestQuests({
  required Iterable<Quest> candidates,
  required Iterable<Goal> goals,
  required Set<String> selectedTitles,
  required DateTime day,
  int? maxMinutes,
}) {
  if (maxMinutes != null && maxMinutes < 0) return const [];

  final goalsByTitle = <String, Goal>{};
  for (final goal in goals) {
    goalsByTitle.putIfAbsent(_key(goal.title), () => goal);
  }

  final selected = selectedTitles.map(_key).toSet();
  final seenTitles = <String>{};
  final suggestions = <_RankedSuggestion>[];
  var sourceIndex = 0;

  for (final quest in candidates) {
    final index = sourceIndex++;
    final titleKey = _key(quest.title);
    // Daily-field selection also maps a title to its first viable source.
    // Never recommend a later duplicate which a title-keyed save would resolve
    // back to an earlier Quest.
    if (!seenTitles.add(titleKey)) continue;
    if (selected.contains(titleKey) ||
        !isAvailableSuggestionCandidate(
          quest,
          goals: goalsByTitle.values,
          day: day,
        )) {
      continue;
    }

    final goal = quest.goalTitle == null
        ? null
        : goalsByTitle[_key(quest.goalTitle!)];
    final exactGoalAction = _exactCurrentGoalAction(quest, goal);
    // A route-stamped Quest must remain attached to its current accepted
    // marker. Do not turn an old revision or an unaccepted proposal into a
    // generic timer suggestion.
    if (quest.goalPlanStepId != null && !exactGoalAction) continue;

    final timerMinutes = _configuredTimerMinutes(quest);
    if (maxMinutes != null &&
        (timerMinutes == null || timerMinutes > maxMinutes)) {
      continue;
    }
    if (!exactGoalAction && timerMinutes == null) continue;

    final reason = exactGoalAction
        ? 'Current action for ${goal!.title}'
        : 'Your saved $timerMinutes-minute session';
    suggestions.add(
      _RankedSuggestion(
        QuestSuggestion(
          quest: quest,
          reason: reason,
          timerMinutes: timerMinutes,
        ),
        priority: quest.priorityOn(day),
        exactGoalAction: exactGoalAction,
        sourceIndex: index,
      ),
    );
  }

  suggestions.sort((a, b) {
    if (a.priority != b.priority) return a.priority ? -1 : 1;
    if (a.exactGoalAction != b.exactGoalAction) {
      return a.exactGoalAction ? -1 : 1;
    }
    final aMinutes = a.suggestion.timerMinutes ?? 1 << 30;
    final bMinutes = b.suggestion.timerMinutes ?? 1 << 30;
    final byMinutes = aMinutes.compareTo(bMinutes);
    if (byMinutes != 0) return byMinutes;
    return a.sourceIndex.compareTo(b.sourceIndex);
  });
  return [for (final suggestion in suggestions) suggestion.suggestion];
}

/// Whether [quest] may appear in Browse all for [day].
///
/// A route-stamped Quest is available only when it is the exact current route
/// action. That is the same ownership test the Workshop uses: an existing
/// matching Quest is already on the board, even if an old save's
/// [Goal.openingSeen] flag is inconsistent.
bool isAvailableSuggestionCandidate(
  Quest quest, {
  required Iterable<Goal> goals,
  required DateTime day,
}) {
  final dayKey = Days.key(day);
  final ordinaryOpen =
      !quest.isEvent &&
      !quest.allDay &&
      !quest.doneFor(day) &&
      quest.snoozedDay != dayKey &&
      quest.scheduledOn(day);
  if (!ordinaryOpen) return false;
  if (quest.goalPlanStepId == null) return true;

  Goal? goal;
  final goalTitle = quest.goalTitle;
  if (goalTitle != null) {
    final wanted = _key(goalTitle);
    for (final candidate in goals) {
      if (_key(candidate.title) == wanted) {
        goal = candidate;
        break;
      }
    }
  }
  return _exactCurrentGoalAction(quest, goal);
}

bool _exactCurrentGoalAction(Quest quest, Goal? goal) {
  final plan = goal?.plan;
  final step = plan?.currentStep;
  return goal != null &&
      plan != null &&
      step != null &&
      !plan.complete &&
      quest.goalPlanStepId == step.id &&
      quest.goalPlanRevision == plan.revision &&
      (quest.goalPlanAttempt ?? 1) == step.completions + 1;
}

int? _configuredTimerMinutes(Quest quest) {
  final minutes = quest.effectiveTimerMinutes;
  return quest.verification == Verification.timer && minutes > 0
      ? minutes
      : null;
}

String _key(String value) => value.trim().toLowerCase();

class _RankedSuggestion {
  const _RankedSuggestion(
    this.suggestion, {
    required this.priority,
    required this.exactGoalAction,
    required this.sourceIndex,
  });

  final QuestSuggestion suggestion;
  final bool priority;
  final bool exactGoalAction;
  final int sourceIndex;
}
