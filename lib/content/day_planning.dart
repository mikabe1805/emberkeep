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
