import '../models.dart';

/// Open quests that can honestly be considered for [day]. This is shared by
/// the night planner, the guided daily Ember, and Gentle Mode shelter so each
/// surface tells the same story about what belongs to a day.
List<Quest> planningQuestsForDay(Iterable<Quest> quests, DateTime day) {
  final key = Days.key(day);
  final end = DateTime(day.year, day.month, day.day, 23, 59, 59);
  return [
    for (final quest in quests)
      if (quest.snoozedDay != key &&
          !quest.doneFor(day) &&
          (quest.isEvent
              ? !quest.dueDate!.isAfter(end)
              : quest.scheduledOn(day)))
        quest,
  ];
}

/// Work that is genuinely committed on [day]: dated work due today or earlier,
/// plus scheduled all-day confirmations that cannot honestly be completed
/// before the night check. A snooze is a compassionate hide for an ordinary
/// quest, not a way to erase a commitment from the day's honest shape.
///
/// Completed commitments stay in this list deliberately: callers deciding
/// whether the day is held can inspect their completion rather than watching a
/// requirement disappear as soon as it is done.
List<Quest> hardCommitmentsForDay(Iterable<Quest> quests, DateTime day) {
  final end = DateTime(day.year, day.month, day.day, 23, 59, 59);
  final key = Days.key(day);
  return [
    for (final quest in quests)
      if (((quest.isEvent && !quest.dueDate!.isAfter(end)) ||
              (quest.allDay && quest.scheduledOn(day))) &&
          (!quest.doneFor(day) || quest.lastDoneDay == key))
        quest,
  ];
}

/// Whether the keeper deliberately shaped a dated field for [day]. This is
/// about the saved choice, not whether every chosen quest remains visible: a
/// snoozed choice must not quietly turn the day back into an unshaped board.
bool hasDateScopedDailyField(Iterable<Quest> quests, DateTime day) {
  final key = Days.key(day);
  return quests.any(
    (quest) =>
        quest.priorityDay == key &&
        !quest.isEvent &&
        !quest.allDay &&
        quest.scheduledOn(day),
  );
}

/// The ordinary, keeper-chosen field for [day], in its explicit order.
///
/// Dated commitments are intentionally absent even if an old save happens to
/// carry a priority marker for one. A snoozed choice remains in the selected
/// field: setting it aside must not quietly make the shaped day look cleared.
/// Completed field quests likewise remain present so a caller can evaluate the
/// complete set honestly after some of the work is finished.
List<Quest> selectedDailyFieldForDay(Iterable<Quest> quests, DateTime day) {
  final key = Days.key(day);
  final source = quests.toList(growable: false);
  final sourceOrder = <Quest, int>{
    for (var index = 0; index < source.length; index++) source[index]: index,
  };
  final selected =
      source
          .where(
            (quest) =>
                quest.priorityDay == key &&
                !quest.isEvent &&
                !quest.allDay &&
                quest.scheduledOn(day),
          )
          .toList()
        ..sort((a, b) {
          final byRank = a.priorityRankOn(day).compareTo(b.priorityRankOn(day));
          if (byRank != 0) return byRank;
          return sourceOrder[a]!.compareTo(sourceOrder[b]!);
        });
  return selected.take(3).toList();
}

/// What counts toward a day that has been deliberately shaped: hard dated
/// commitments first, then the chosen field. The returned set is stable and
/// never duplicates a row if legacy state put the same Quest in both buckets.
List<Quest> requiredQuestsForDay(Iterable<Quest> quests, DateTime day) {
  final seenTitles = <String>{};
  return [
    for (final quest in [
      ...hardCommitmentsForDay(quests, day),
      ...selectedDailyFieldForDay(quests, day),
    ])
      if (seenTitles.add(quest.title)) quest,
  ];
}

/// Save the keeper's ordinary field for [day] using the existing dated
/// priority fields. This is intentionally narrow: at most three ordinary
/// schedulable quests lead the day, while due work remains a separate,
/// non-optional commitment.
///
/// Previous date-scoped choices for this day are cleared everywhere (including
/// choices that have since been snoozed or completed). Standing stars are
/// retired only for the current day's viable candidates, so planning today
/// cannot erase a standing favorite that does not belong on today's board.
void applyDailyField(
  Iterable<Quest> quests,
  DateTime day,
  Iterable<String> chosenTitles,
) {
  final key = Days.key(day);
  final source = quests.toList(growable: false);
  final candidates = planningQuestsForDay(
    source,
    day,
  ).where((quest) => !quest.allDay && !quest.isEvent).toList(growable: false);
  final candidatesByTitle = <String, Quest>{};
  for (final quest in candidates) {
    candidatesByTitle.putIfAbsent(quest.title, () => quest);
  }

  final chosen = <Quest>[];
  final seenTitles = <String>{};
  for (final title in chosenTitles) {
    if (!seenTitles.add(title)) continue;
    final quest = candidatesByTitle[title];
    if (quest != null) chosen.add(quest);
    if (chosen.length == 3) break;
  }

  for (final quest in source) {
    if (quest.priorityDay == key) {
      quest
        ..priorityDay = null
        ..priorityRank = null;
    }
  }
  for (final quest in candidates) {
    quest.priority = false;
    if (quest.priorityDay == null) quest.priorityRank = null;
  }
  for (var index = 0; index < chosen.length; index++) {
    chosen[index]
      ..priority = false
      ..priorityDay = key
      ..priorityRank = index + 1;
  }
}

/// Pick a compassionate starting three for a crowded Gentle Mode day. Urgent
/// dated commitments remain visible first, then a dated MAIN choice, then the
/// least-dreaded and lightest work. The result stays fixed until the keeper
/// explicitly edits it.
List<Quest> suggestedLowFlameQuests(Iterable<Quest> quests, DateTime day) {
  final start = DateTime(day.year, day.month, day.day);
  final candidates = quests.where((q) => !q.allDay && !q.doneFor(day)).toList()
    ..sort((a, b) {
      int tier(Quest q) {
        if (q.isEvent && q.dueDate!.isBefore(start)) return 0;
        if (q.isEvent) return 1;
        if (q.priorityOn(day)) return 2;
        if (q.bonus) return 4;
        return 3;
      }

      final byTier = tier(a).compareTo(tier(b));
      if (byTier != 0) return byTier;
      if (a.dread != b.dread) return a.dread ? 1 : -1;
      final byDifficulty = a.difficulty.compareTo(b.difficulty);
      if (byDifficulty != 0) return byDifficulty;
      return a.displayTitle.toLowerCase().compareTo(
        b.displayTitle.toLowerCase(),
      );
    });

  final seen = <String>{};
  return [
    for (final quest in candidates)
      if (seen.add(quest.title)) quest,
  ].take(3).toList();
}
