import 'package:emberkeep/content/day_planning.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

Quest _quest(
  String title, {
  QuestSchedule schedule = QuestSchedule.daily,
  DateTime? dueDate,
  bool priority = false,
  String? priorityDay,
  int? priorityRank,
  String? snoozedDay,
  List<int> weekdays = const [],
  bool allDay = false,
}) => Quest(
  title: title,
  stat: Stat.dis,
  difficulty: 3,
  schedule: schedule,
  dueDate: dueDate,
  priority: priority,
  priorityDay: priorityDay,
  priorityRank: priorityRank,
  snoozedDay: snoozedDay,
  weekdays: weekdays,
  allDay: allDay,
);

void main() {
  final day = DateTime(2026, 8, 30);
  final dayKey = Days.key(day);

  test(
    'applyDailyField writes deterministic ranks and retires eligible stars',
    () {
      final first = _quest('First', priority: true);
      final second = _quest('Second', priority: true);
      final third = _quest('Third');
      final elsewhere = _quest(
        'Elsewhere',
        priority: true,
        priorityDay: Days.key(day.add(const Duration(days: 1))),
        priorityRank: 2,
        weekdays: const [1],
      );
      final quests = [first, second, third, elsewhere];

      applyDailyField(quests, day, ['Third', 'First', 'Second', 'Ignored']);

      expect(first.priority, isFalse);
      expect(second.priority, isFalse);
      expect(third.priority, isFalse);
      expect(
        selectedDailyFieldForDay(quests, day).map((quest) => quest.title),
        ['Third', 'First', 'Second'],
      );
      expect(
        selectedDailyFieldForDay(
          quests,
          day,
        ).map((quest) => quest.priorityRank),
        [1, 2, 3],
      );
      expect(elsewhere.priority, isTrue);
      expect(elsewhere.priorityDay, Days.key(day.add(const Duration(days: 1))));
      expect(elsewhere.priorityRank, 2);
    },
  );

  test(
    'applyDailyField clears stale choices for the day but leaves other days',
    () {
      final staleVisible = _quest(
        'Stale visible',
        priorityDay: dayKey,
        priorityRank: 1,
      );
      final staleSnoozed = _quest(
        'Stale snoozed',
        priorityDay: dayKey,
        priorityRank: 2,
        snoozedDay: dayKey,
      );
      final tomorrow = _quest(
        'Tomorrow',
        priorityDay: Days.key(day.add(const Duration(days: 1))),
        priorityRank: 1,
      );
      final quests = [staleVisible, staleSnoozed, tomorrow];

      applyDailyField(quests, day, const []);

      expect(staleVisible.priorityDay, isNull);
      expect(staleVisible.priorityRank, isNull);
      expect(staleSnoozed.priorityDay, isNull);
      expect(staleSnoozed.priorityRank, isNull);
      expect(tomorrow.priorityDay, Days.key(day.add(const Duration(days: 1))));
      expect(tomorrow.priorityRank, 1);
      expect(hasDateScopedDailyField(quests, day), isFalse);
    },
  );

  test('dated commitments stay separate from the chosen field', () {
    final overdue = _quest(
      'Overdue form',
      schedule: QuestSchedule.once,
      dueDate: DateTime(2026, 8, 29, 17),
      priorityDay: dayKey,
      priorityRank: 1,
      snoozedDay: dayKey,
    );
    final dueToday = _quest(
      'Call dentist',
      schedule: QuestSchedule.once,
      dueDate: DateTime(2026, 8, 30, 16),
    );
    final ordinary = _quest('Read a chapter');
    final quests = [overdue, dueToday, ordinary];

    applyDailyField(quests, day, ['Overdue form', 'Read a chapter']);

    expect(hardCommitmentsForDay(quests, day).map((quest) => quest.title), [
      'Overdue form',
      'Call dentist',
    ]);
    expect(selectedDailyFieldForDay(quests, day).map((quest) => quest.title), [
      'Read a chapter',
    ]);
    expect(requiredQuestsForDay(quests, day).map((quest) => quest.title), [
      'Overdue form',
      'Call dentist',
      'Read a chapter',
    ]);
    expect(overdue.priorityDay, isNull);
  });

  test('a snoozed field remains required and cannot falsely clear the day', () {
    final chosen = _quest(
      'Walk',
      priorityDay: dayKey,
      priorityRank: 1,
      snoozedDay: dayKey,
    );
    final due = _quest(
      'Submit form',
      schedule: QuestSchedule.once,
      dueDate: day,
      snoozedDay: dayKey,
    );
    final quests = [chosen, due];

    expect(hasDateScopedDailyField(quests, day), isTrue);
    expect(selectedDailyFieldForDay(quests, day), [chosen]);
    expect(requiredQuestsForDay(quests, day), [due, chosen]);
  });

  test('an old completed commitment does not follow every future day', () {
    final yesterdayKey = Days.key(day.subtract(const Duration(days: 1)));
    final oldDone = _quest(
      'Old appointment',
      schedule: QuestSchedule.once,
      dueDate: day.subtract(const Duration(days: 3)),
    )..lastDoneDay = yesterdayKey;
    final doneToday = _quest(
      'Today appointment',
      schedule: QuestSchedule.once,
      dueDate: day,
    )..lastDoneDay = dayKey;

    expect(hardCommitmentsForDay([oldDone, doneToday], day), [doneToday]);
  });

  test('scheduled all-day confirmations stay in the honest boundary', () {
    final allDay = _quest('No caffeine after two', allDay: true);
    final notToday = _quest(
      'Sunday reset',
      schedule: QuestSchedule.daily,
      weekdays: const [1],
      allDay: true,
    );

    expect(hardCommitmentsForDay([allDay, notToday], day), [allDay]);
    expect(requiredQuestsForDay([allDay, notToday], day), [allDay]);
  });

  test(
    'selected field uses rank then source order and retains completed work',
    () {
      final unranked = _quest('Unranked', priorityDay: dayKey);
      final second = _quest('Second', priorityDay: dayKey, priorityRank: 2);
      final firstDone = _quest(
        'First done',
        priorityDay: dayKey,
        priorityRank: 1,
      )..lastDoneDay = dayKey;
      final quests = [unranked, second, firstDone];

      expect(
        selectedDailyFieldForDay(quests, day).map((quest) => quest.title),
        ['First done', 'Second', 'Unranked'],
      );
      expect(requiredQuestsForDay(quests, day).map((quest) => quest.title), [
        'First done',
        'Second',
        'Unranked',
      ]);
    },
  );
}
