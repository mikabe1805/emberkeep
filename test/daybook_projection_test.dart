import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart'
    hide CivilDate;
import 'package:emberkeep/daybook/domain/civil_date.dart';
import 'package:emberkeep/daybook/domain/daybook_event.dart';
import 'package:emberkeep/daybook/domain/daybook_task.dart';
import 'package:emberkeep/daybook/presentation/daybook_range_projection.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = CivilDate(2026, 8, 17);
  final now = DateTime(2026, 8, 17, 10);

  test(
    'projects every source into ordered all-day, timed, and due sections',
    () {
      final schedule = _scheduleFor(date);
      final result = DaybookRangeProjection.build(
        schedule: schedule,
        quests: [
          Quest(
            title: 'Quest plan',
            stat: Stat.dis,
            difficulty: 3,
            schedule: QuestSchedule.once,
            dueDate: DateTime(2026, 8, 17),
          ),
        ],
        first: date,
        last: date,
        now: now,
      );

      final day = result.dayOn(date);
      expect(day.entries.map((entry) => entry.displayKey), [
        'event:all-day@2026-08-17',
        'event:morning@2026-08-17',
        'study:study-1',
        'class:class-1',
        'task:submit',
        'work:work-1',
        'quest:Quest plan',
      ]);
      expect(day.entries.map((entry) => entry.section), [
        DaybookSection.allDay,
        DaybookSection.timed,
        DaybookSection.timed,
        DaybookSection.timed,
        DaybookSection.due,
        DaybookSection.due,
        DaybookSection.due,
      ]);
      expect(day.summary.scheduledMinutes, 130);
      expect(day.summary.weight, DaybookDayWeight.moderate);
      expect(day.summary.hasDeadline, isTrue);
      expect(day.summary.semanticLabel, contains('2 events'));
      expect(day.summary.semanticLabel, contains('1 class'));
      expect(day.summary.semanticLabel, contains('1 study block'));
      expect(day.summary.semanticLabel, contains('1 task'));
      expect(day.summary.semanticLabel, contains('1 academic work item'));
      expect(day.summary.semanticLabel, contains('1 quest plan'));
      expect(day.summary.conflicts, hasLength(1));
      expect(
        day.summary.conflicts.single.leftDisplayKey,
        'event:morning@2026-08-17',
      );
      expect(day.summary.conflicts.single.rightDisplayKey, 'study:study-1');
      expect(
        day.summary.conflicts.single.message,
        'Morning event overlaps Lab report',
      );
    },
  );

  test('Quest calendar intent separates deadlines focus and routines', () {
    final date = CivilDate(2026, 8, 18);
    final range = DaybookRangeProjection.build(
      schedule: AcademicSchedule.empty(),
      quests: <Quest>[
        Quest(title: 'Daily care', stat: Stat.vit, difficulty: 1),
        Quest(
          title: 'Tuesday care',
          stat: Stat.vit,
          difficulty: 1,
          weekdays: const [DateTime.tuesday],
        ),
        Quest(
          title: 'Weekly care',
          stat: Stat.vit,
          difficulty: 1,
          schedule: QuestSchedule.weekly,
        ),
        Quest(
          title: 'Monthly care',
          stat: Stat.vit,
          difficulty: 1,
          schedule: QuestSchedule.monthly,
          monthDay: 18,
        ),
        Quest(
          title: 'Until done',
          stat: Stat.foc,
          difficulty: 2,
          schedule: QuestSchedule.once,
        ),
        Quest(
          title: 'Standing main',
          stat: Stat.foc,
          difficulty: 2,
          priority: true,
        ),
        Quest(
          title: 'Chosen today',
          stat: Stat.foc,
          difficulty: 2,
          priority: true,
          priorityDay: '2026-08-18',
        ),
        Quest(
          title: 'Real deadline',
          stat: Stat.foc,
          difficulty: 3,
          schedule: QuestSchedule.once,
          dueDate: DateTime(2026, 8, 18, 15),
        ),
        Quest(
          title: 'Due wins',
          stat: Stat.foc,
          difficulty: 3,
          schedule: QuestSchedule.once,
          dueDate: DateTime(2026, 8, 18),
          priority: true,
          priorityDay: '2026-08-18',
        ),
      ],
      first: date.addDays(-1),
      last: date.addDays(1),
      now: DateTime(2026, 8, 18, 12),
    );

    expect(
      [
        for (final entry in range.dayOn(date).entries)
          (entry.title, entry.section),
      ],
      const [
        ('Real deadline', DaybookSection.due),
        ('Due wins', DaybookSection.due),
        ('Chosen today', DaybookSection.focus),
      ],
    );
    final titles = range.days.values
        .expand((day) => day.entries)
        .map((entry) => entry.title)
        .toSet();
    for (final hidden in const {
      'Daily care',
      'Tuesday care',
      'Weekly care',
      'Monthly care',
      'Until done',
      'Standing main',
    }) {
      expect(titles, isNot(contains(hidden)));
    }
  });

  test('Quest calendar intent hides snoozed focus but keeps snoozed due', () {
    final date = CivilDate(2026, 8, 18);
    final range = DaybookRangeProjection.build(
      schedule: AcademicSchedule.empty(),
      quests: [
        Quest(
          title: 'Snoozed focus',
          stat: Stat.foc,
          difficulty: 2,
          priorityDay: '2026-08-18',
          snoozedDay: '2026-08-18',
        ),
        Quest(
          title: 'Snoozed due',
          stat: Stat.foc,
          difficulty: 2,
          schedule: QuestSchedule.once,
          dueDate: DateTime(2026, 8, 18),
          snoozedDay: '2026-08-18',
        ),
      ],
      first: date,
      last: date,
      now: DateTime(2026, 8, 18, 12),
    );

    expect(range.dayOn(date).entries.map((entry) => entry.title), [
      'Snoozed due',
    ]);
    expect(range.dayOn(date).entries.single.section, DaybookSection.due);
  });

  test('Quest calendar summary separates fixed plans deadlines and focus', () {
    final date = CivilDate(2026, 8, 18);
    final timestamp = DateTime.utc(2026, 8, 1);
    final schedule = AcademicSchedule.empty().putEvent(
      DaybookEvent(
        eventId: 'morning',
        title: 'Morning event',
        startDate: date,
        endDate: date,
        timeZoneId: 'America/New_York',
        allDay: false,
        startMinute: 9 * 60,
        endMinute: 10 * 60,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
    final day = DaybookRangeProjection.build(
      schedule: schedule,
      quests: [
        Quest(
          title: 'Active deadline',
          stat: Stat.foc,
          difficulty: 3,
          schedule: QuestSchedule.once,
          dueDate: DateTime(2026, 8, 18, 15),
          timerMinutes: 240,
        ),
        Quest(
          title: 'Active focus',
          stat: Stat.foc,
          difficulty: 2,
          priorityDay: '2026-08-18',
          timerMinutes: 180,
        ),
        Quest(
          title: 'Completed deadline',
          stat: Stat.foc,
          difficulty: 3,
          schedule: QuestSchedule.once,
          dueDate: DateTime(2026, 8, 18),
          lastDoneDay: '2026-08-18',
        ),
        Quest(
          title: 'Completed focus',
          stat: Stat.foc,
          difficulty: 2,
          priorityDay: '2026-08-18',
          lastDoneDay: '2026-08-18',
        ),
      ],
      first: date,
      last: date,
      now: DateTime(2026, 8, 18, 12),
    ).dayOn(date);

    expect(day.summary.scheduledMinutes, 60);
    expect(day.summary.fixedPlanCount, 1);
    expect(day.summary.deadlineCount, 1);
    expect(day.summary.focusCount, 1);
    expect(day.summary.firstTimedStartMinute, 9 * 60);
    expect(day.summary.hasDeadline, isTrue);
  });

  test('Daybook fixed plan summary counts active all-day commitments', () {
    final date = CivilDate(2026, 8, 18);
    final timestamp = DateTime.utc(2026, 8, 1);
    DaybookEvent allDayEvent(String eventId) => DaybookEvent(
      eventId: eventId,
      title: eventId,
      startDate: date,
      endDate: date.addDays(1),
      timeZoneId: 'America/New_York',
      allDay: true,
      createdAt: timestamp,
      updatedAt: timestamp,
    );

    final allDayOnly = DaybookRangeProjection.build(
      schedule: AcademicSchedule.empty().putEvent(allDayEvent('all-day')),
      quests: const [],
      first: date,
      last: date,
      now: DateTime(2026, 8, 18, 12),
    ).dayOn(date);
    expect(allDayOnly.summary.fixedPlanCount, 1);

    final cancelledAllDay = DaybookEvent(
      eventId: 'cancelled-all-day',
      title: 'Cancelled all-day',
      startDate: date,
      endDate: date.addDays(1),
      timeZoneId: 'America/New_York',
      allDay: true,
      exceptions: [
        DaybookEventException(
          occurrenceKey: 'cancelled-all-day/${date.toString()}',
          originalDate: date,
          state: DaybookEventOccurrenceState.cancelled,
          updatedAt: timestamp,
        ),
      ],
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    final mixed = DaybookRangeProjection.build(
      schedule: AcademicSchedule.empty()
          .putEvent(allDayEvent('active-all-day'))
          .putEvent(
            DaybookEvent(
              eventId: 'timed',
              title: 'Timed',
              startDate: date,
              endDate: date,
              timeZoneId: 'America/New_York',
              allDay: false,
              startMinute: 9 * 60,
              endMinute: 10 * 60,
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          )
          .putEvent(cancelledAllDay),
      quests: const [],
      first: date,
      last: date,
      now: DateTime(2026, 8, 18, 12),
    ).dayOn(date);

    expect(mixed.summary.fixedPlanCount, 2);
    expect(
      mixed.entries
          .singleWhere((entry) => entry.title == 'Cancelled all-day')
          .cancelled,
      isTrue,
    );
  });

  test('clips overnight events to each projected day', () {
    final previous = date.addDays(-1);
    final schedule = AcademicSchedule.empty().putEvent(
      DaybookEvent(
        eventId: 'overnight',
        title: 'Overnight work',
        startDate: previous,
        endDate: date,
        timeZoneId: 'America/New_York',
        allDay: false,
        startMinute: 23 * 60,
        endMinute: 60,
        createdAt: now.toUtc(),
        updatedAt: now.toUtc(),
      ),
    );

    final result = DaybookRangeProjection.build(
      schedule: schedule,
      quests: const [],
      first: previous,
      last: date,
      now: now,
    );

    final firstEntry = result.dayOn(previous).entries.single;
    final secondEntry = result.dayOn(date).entries.single;
    expect((firstEntry.startMinute, firstEntry.endMinute), (23 * 60, 24 * 60));
    expect((secondEntry.startMinute, secondEntry.endMinute), (0, 60));
    expect(result.dayOn(previous).summary.scheduledMinutes, 60);
    expect(result.dayOn(date).summary.scheduledMinutes, 60);
  });

  test('an event ending at next-day midnight has no zero-minute end row', () {
    final previous = date.addDays(-1);
    final schedule = AcademicSchedule.empty().putEvent(
      DaybookEvent(
        eventId: 'midnight-end',
        title: 'Ends at midnight',
        startDate: previous,
        endDate: date,
        timeZoneId: 'America/New_York',
        allDay: false,
        startMinute: 23 * 60,
        endMinute: 0,
        createdAt: now.toUtc(),
        updatedAt: now.toUtc(),
      ),
    );

    final result = DaybookRangeProjection.build(
      schedule: schedule,
      quests: const [],
      first: previous,
      last: date,
      now: now,
    );

    expect(result.dayOn(previous).entries, hasLength(1));
    expect(
      (
        result.dayOn(previous).entries.single.startMinute,
        result.dayOn(previous).entries.single.endMinute,
      ),
      (23 * 60, 24 * 60),
    );
    expect(result.dayOn(date).entries, isEmpty);
    expect(result.dayOn(date).summary.scheduledMinutes, 0);
    expect(result.dayOn(date).summary.semanticLabel, isNot(contains('event')));
  });

  test('keeps an all-day event visible across its in-range days', () {
    final previous = date.addDays(-2);
    final schedule = AcademicSchedule.empty().putEvent(
      DaybookEvent(
        eventId: 'conference',
        title: 'Conference',
        startDate: previous,
        endDate: date.addDays(1),
        timeZoneId: 'America/New_York',
        allDay: true,
        createdAt: now.toUtc(),
        updatedAt: now.toUtc(),
      ),
    );

    final result = DaybookRangeProjection.build(
      schedule: schedule,
      quests: const [],
      first: date,
      last: date,
      now: now,
    );

    expect(result.dayOn(date).entries.single.title, 'Conference');
    expect(result.dayOn(date).entries.single.section, DaybookSection.allDay);
  });

  test('projects a moved all-day span that starts before the range', () {
    final originalDate = date.addDays(-10);
    final movedStart = date.addDays(-2);
    final movedEnd = date.addDays(2);
    var schedule = AcademicSchedule.empty().putEvent(
      DaybookEvent(
        eventId: 'moved-conference',
        title: 'Moved conference',
        startDate: originalDate,
        endDate: originalDate.addDays(1),
        timeZoneId: 'America/New_York',
        allDay: true,
        createdAt: now.toUtc(),
        updatedAt: now.toUtc(),
      ),
    );
    schedule = schedule.moveEventOccurrence(
      eventId: 'moved-conference',
      occurrenceKey: 'moved-conference@$originalDate',
      startDate: movedStart,
      endDate: movedEnd,
      updatedAt: now.toUtc(),
    );

    final result = DaybookRangeProjection.build(
      schedule: schedule,
      quests: const [],
      first: date,
      last: date.addDays(3),
      now: now,
    );

    expect(result.dayOn(date).entries.single.title, 'Moved conference');
    expect(
      result.dayOn(date.addDays(1)).entries.single.title,
      'Moved conference',
    );
    expect(result.dayOn(movedEnd).entries, isEmpty);
    expect(schedule.events.single.exceptions.single.movedStartDate, movedStart);
    expect(schedule.events.single.exceptions.single.movedEndDate, movedEnd);
  });

  test(
    'uses the specified month weights and keeps still-open tasks gentle',
    () {
      final first = CivilDate(2026, 8, 10);
      final schedule = AcademicSchedule.empty()
          .putEvent(_timedEvent('one', first, 1))
          .putEvent(_timedEvent('one-nineteen', first.addDays(1), 119))
          .putEvent(_timedEvent('one-twenty', first.addDays(2), 120))
          .putEvent(_timedEvent('two-thirty-nine', first.addDays(3), 239))
          .putEvent(_timedEvent('two-forty', first.addDays(4), 240))
          .putTask(
            DaybookTask(
              taskId: 'open-task',
              title: 'Kindly return this book',
              dueDate: first,
              createdAt: now.toUtc(),
              updatedAt: now.toUtc(),
            ),
          );
      final result = DaybookRangeProjection.build(
        schedule: schedule,
        quests: const [],
        first: first,
        last: first.addDays(5),
        now: DateTime(2026, 8, 15, 10),
      );

      expect(result.dayOn(first).summary.weight, DaybookDayWeight.light);
      expect(
        result.dayOn(first.addDays(1)).summary.weight,
        DaybookDayWeight.light,
      );
      expect(
        result.dayOn(first.addDays(2)).summary.weight,
        DaybookDayWeight.moderate,
      );
      expect(
        result.dayOn(first.addDays(3)).summary.weight,
        DaybookDayWeight.moderate,
      );
      expect(
        result.dayOn(first.addDays(4)).summary.weight,
        DaybookDayWeight.full,
      );
      expect(
        result.dayOn(first.addDays(5)).summary.weight,
        DaybookDayWeight.none,
      );

      final dueEntry = result
          .dayOn(first)
          .entries
          .singleWhere((entry) => entry.sourceId == 'open-task');
      final stillOpen = result.dayOn(first.addDays(5)).entries.single;
      expect(dueEntry.section, DaybookSection.due);
      expect(stillOpen.section, DaybookSection.stillOpen);
      expect(stillOpen.sourceId, 'open-task');
      expect(schedule.tasks.single.dueDate, first);
      expect(stillOpen.action, isA<DaybookTaskAction>());
    },
  );
}

AcademicSchedule _scheduleFor(CivilDate date) {
  final term = AcademicTerm(
    termId: 'term-1',
    name: 'Fall 2026',
    startDate: date,
    endDate: date.addDays(30),
    timeZoneId: 'America/New_York',
  );
  final course = AcademicCourse(
    courseId: 'course-1',
    termId: term.termId,
    code: 'ECE 101',
    title: 'Signals',
    colorValue: 0,
    colorLabel: 'Gold',
  );
  final timestamp = DateTime.utc(2026, 8, 1);
  var schedule = AcademicSchedule(
    terms: [term],
    courses: [course],
    meetingSeries: const [],
    occurrences: const [],
  );
  schedule = schedule.putMeeting(
    term: term,
    course: course,
    series: MeetingSeries(
      meetingSeriesId: 'series-1',
      courseId: course.courseId,
      kind: MeetingKind.lecture,
      weekdays: {date.weekday},
      localStartMinute: 9 * 60 + 30,
      localEndMinute: 10 * 60 + 30,
      firstDate: date,
      lastDate: date,
      timeZoneId: term.timeZoneId,
      place: CampusPlace(label: 'Engineering Building'),
      updatedAt: timestamp,
    ),
    updatedAt: timestamp,
    idFactory: (_) => 'class-1',
  );
  final work = AcademicWorkItem(
    workId: 'work-1',
    courseId: course.courseId,
    kind: AcademicWorkKind.assignment,
    title: 'Lab report',
    dueDate: date,
    dueMinute: 13 * 60,
    updatedAt: timestamp,
  );
  schedule = schedule.putWorkItem(work);
  schedule = schedule.putStudyPlan(
    plan: AcademicStudyPlan(
      workId: work.workId,
      totalMinutes: 30,
      sessionMinutes: 30,
      dailyStartMinute: 8 * 60,
      dailyEndMinute: 20 * 60,
      updatedAt: timestamp,
    ),
    blocks: [
      AcademicStudyBlock(
        studyBlockId: 'study-1',
        workId: work.workId,
        date: date,
        startMinute: 8 * 60 + 45,
        endMinute: 9 * 60 + 15,
        updatedAt: timestamp,
      ),
    ],
  );
  return schedule
      .putEvent(
        DaybookEvent(
          eventId: 'all-day',
          title: 'All-day event',
          startDate: date,
          endDate: date.addDays(1),
          timeZoneId: term.timeZoneId,
          allDay: true,
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      )
      .putEvent(
        DaybookEvent(
          eventId: 'morning',
          title: 'Morning event',
          startDate: date,
          endDate: date,
          timeZoneId: term.timeZoneId,
          allDay: false,
          startMinute: 8 * 60 + 30,
          endMinute: 9 * 60,
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      )
      .putTask(
        DaybookTask(
          taskId: 'submit',
          title: 'Submit form',
          dueDate: date,
          dueMinute: 12 * 60,
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
}

DaybookEvent _timedEvent(String id, CivilDate date, int duration) =>
    DaybookEvent(
      eventId: id,
      title: id,
      startDate: date,
      endDate: date,
      timeZoneId: 'America/New_York',
      allDay: false,
      startMinute: 0,
      endMinute: duration,
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
    );
