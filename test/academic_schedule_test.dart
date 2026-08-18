import 'dart:convert';

import 'package:emberkeep/academic_calendar/data/academic_schedule_repository.dart';
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/services/notebook_handoff.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/daybook/domain/daybook_event.dart';
import 'package:emberkeep/daybook/domain/daybook_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(Clock.reset);

  test('Tue/Fri series materializes in term and keeps keys after reload', () {
    var id = 0;
    String nextId(String kind) => '${kind}_${++id}';
    final schedule = _fixtureSchedule(
      weekdays: {DateTime.tuesday, DateTime.friday},
      idFactory: nextId,
    );

    expect(schedule.occurrences, hasLength(34));
    expect(
      schedule.occurrences.every(
        (occurrence) =>
            occurrence.originalDate.weekday == DateTime.tuesday ||
            occurrence.originalDate.weekday == DateTime.friday,
      ),
      isTrue,
    );
    expect(schedule.occurrences.first.originalDate, CivilDate(2026, 8, 25));
    expect(schedule.occurrences.last.originalDate, CivilDate(2026, 12, 18));

    final before = [
      for (final occurrence in schedule.occurrences) occurrence.occurrenceKey,
    ];
    final restored = AcademicSchedule.fromJson(
      (jsonDecode(jsonEncode(schedule.toJson())) as Map)
          .cast<String, dynamic>(),
    );
    expect([
      for (final occurrence in restored.occurrences) occurrence.occurrenceKey,
    ], before);
  });

  test(
    'series rebuild preserves matching keys and tombstones removed dates',
    () {
      var id = 0;
      String nextId(String kind) => '${kind}_${++id}';
      final original = _fixtureSchedule(
        weekdays: {DateTime.tuesday, DateTime.friday},
        idFactory: nextId,
      ).putEvent(_generalEvent()).putTask(_generalTask());
      final priorTuesday = original.occurrences.firstWhere(
        (occurrence) => occurrence.originalDate.weekday == DateTime.tuesday,
      );
      final priorFriday = original.occurrences.firstWhere(
        (occurrence) => occurrence.originalDate.weekday == DateTime.friday,
      );
      final oldSeries = original.meetingSeries.single;
      final revisedSeries = MeetingSeries(
        meetingSeriesId: oldSeries.meetingSeriesId,
        courseId: oldSeries.courseId,
        kind: oldSeries.kind,
        weekdays: const {DateTime.tuesday},
        localStartMinute: oldSeries.localStartMinute,
        localEndMinute: oldSeries.localEndMinute,
        firstDate: oldSeries.firstDate,
        lastDate: oldSeries.lastDate,
        timeZoneId: oldSeries.timeZoneId,
        place: oldSeries.place,
        reminders: oldSeries.reminders,
        revision: 2,
        updatedAt: DateTime.utc(2026, 8, 12),
      );
      final rebuilt = original.putMeeting(
        term: original.terms.single,
        course: original.courses.single,
        series: revisedSeries,
        updatedAt: DateTime.utc(2026, 8, 12),
        idFactory: nextId,
      );

      expect(
        rebuilt.occurrences
            .singleWhere(
              (occurrence) =>
                  occurrence.originalDate == priorTuesday.originalDate,
            )
            .occurrenceKey,
        priorTuesday.occurrenceKey,
      );
      final cancelledFriday = rebuilt.occurrences.singleWhere(
        (occurrence) => occurrence.originalDate == priorFriday.originalDate,
      );
      expect(cancelledFriday.occurrenceKey, priorFriday.occurrenceKey);
      expect(cancelledFriday.state, OccurrenceState.cancelled);
      expect(cancelledFriday.tombstonedAt, isNotNull);
      expect(rebuilt.events.single.eventId, 'event_team');
      expect(rebuilt.tasks.single.taskId, 'task_submit');
    },
  );

  test('one class can move and restore without changing its weekly series', () {
    final schedule = _fixtureSchedule(
      weekdays: const {DateTime.tuesday, DateTime.friday},
    );
    final original = schedule.occurrences.first;
    final changedAt = DateTime.utc(2026, 8, 24, 14);

    final moved = schedule.moveOccurrence(
      occurrenceKey: original.occurrenceKey,
      date: CivilDate(2026, 8, 26),
      startMinute: 13 * 60,
      endMinute: 14 * 60 + 20,
      updatedAt: changedAt,
    );
    final adjusted = moved.occurrenceByKey(original.occurrenceKey)!;

    expect(adjusted.occurrenceKey, original.occurrenceKey);
    expect(adjusted.originalDate, original.originalDate);
    expect(adjusted.date, CivilDate(2026, 8, 26));
    expect(adjusted.localStartMinute, 13 * 60);
    expect(adjusted.localEndMinute, 14 * 60 + 20);
    expect(adjusted.state, OccurrenceState.moved);
    expect(adjusted.userAdjusted, isTrue);
    expect(adjusted.movedFrom, original.originalDate.toString());
    expect(moved.meetingSeries.single.localStartMinute, 10 * 60 + 20);
    expect(
      moved.occurrences
          .where((item) => item.occurrenceKey != original.occurrenceKey)
          .map((item) => item.originalDate),
      schedule.occurrences
          .where((item) => item.occurrenceKey != original.occurrenceKey)
          .map((item) => item.originalDate),
    );

    final restored = moved.restoreOccurrence(
      occurrenceKey: original.occurrenceKey,
      updatedAt: changedAt.add(const Duration(minutes: 1)),
    );
    final back = restored.occurrenceByKey(original.occurrenceKey)!;
    expect(back.date, original.originalDate);
    expect(
      back.localStartMinute,
      schedule.meetingSeries.single.localStartMinute,
    );
    expect(back.localEndMinute, schedule.meetingSeries.single.localEndMinute);
    expect(back.state, OccurrenceState.scheduled);
    expect(back.userAdjusted, isFalse);
    expect(back.movedFrom, isNull);
  });

  test('one class can cancel and restore without cancelling the series', () {
    final schedule = _fixtureSchedule(weekdays: const {DateTime.tuesday});
    final original = schedule.occurrences.first;

    final cancelled = schedule.cancelOccurrence(
      occurrenceKey: original.occurrenceKey,
      updatedAt: DateTime.utc(2026, 8, 24, 14),
    );
    final adjusted = cancelled.occurrenceByKey(original.occurrenceKey)!;

    expect(adjusted.state, OccurrenceState.cancelled);
    expect(adjusted.userAdjusted, isTrue);
    expect(adjusted.tombstonedAt, isNull);
    expect(cancelled.doorwayOccurrences(original.startInstant), isEmpty);
    expect(
      cancelled.occurrences.where(
        (item) => item.state == OccurrenceState.scheduled,
      ),
      isNotEmpty,
    );

    final restored = cancelled.restoreOccurrence(
      occurrenceKey: original.occurrenceKey,
      updatedAt: DateTime.utc(2026, 8, 24, 14, 1),
    );
    expect(
      restored.occurrenceByKey(original.occurrenceKey)!.state,
      OccurrenceState.scheduled,
    );
  });

  test('doorway is active from fifteen minutes before through class end', () {
    final schedule = _fixtureSchedule(weekdays: const {DateTime.tuesday});
    final occurrence = schedule.occurrences.first;

    Clock.freeze(occurrence.startInstant.subtract(const Duration(minutes: 15)));
    expect(schedule.doorwayOccurrences(Clock.now()), [occurrence]);

    Clock.freeze(occurrence.endInstant);
    expect(schedule.doorwayOccurrences(Clock.now()), [occurrence]);

    Clock.freeze(occurrence.endInstant.add(const Duration(milliseconds: 1)));
    expect(schedule.doorwayOccurrences(Clock.now()), isEmpty);
  });

  test('meeting conflicts find real overlap but not touching edges', () {
    final base = _fixtureSchedule(weekdays: const {DateTime.tuesday});
    final overlapping = _addClass(
      base,
      courseId: 'course_chem_161',
      seriesId: 'series_chem_161_lab',
      code: 'CHEM 161',
      startMinute: 11 * 60,
      endMinute: 12 * 60 + 20,
    );

    final conflicts = overlapping.meetingConflictsOn(CivilDate(2026, 8, 25));
    expect(conflicts, hasLength(1));
    expect(conflicts.single.overlapStartMinute, 11 * 60);
    expect(conflicts.single.overlapEndMinute, 11 * 60 + 40);
    expect(conflicts.single.overlapMinutes, 40);

    final touching = _addClass(
      base,
      courseId: 'course_hist_210',
      seriesId: 'series_hist_210_recitation',
      code: 'HIST 210',
      startMinute: 11 * 60 + 40,
      endMinute: 12 * 60 + 40,
    );
    expect(touching.meetingConflictsOn(CivilDate(2026, 8, 25)), isEmpty);
  });

  test('transition pressure respects both buffers without moving classes', () {
    final base = _fixtureSchedule(
      weekdays: const {DateTime.tuesday},
      transitionBufferMinutes: 5,
    );
    final tight = _addClass(
      base,
      courseId: 'course_chem_161',
      seriesId: 'series_chem_161_lab',
      code: 'CHEM 161',
      startMinute: 11 * 60 + 45,
      endMinute: 13 * 60,
      transitionBufferMinutes: 10,
    );

    expect(tight.meetingConflictsOn(CivilDate(2026, 8, 25)), isEmpty);
    final pressure = tight.transitionPressuresOn(CivilDate(2026, 8, 25)).single;
    expect(pressure.gapMinutes, 5);
    expect(pressure.requestedMinutes, 10);
    expect(pressure.before.localEndMinute, 11 * 60 + 40);
    expect(pressure.after.localStartMinute, 11 * 60 + 45);

    final enoughRoom = _addClass(
      base,
      courseId: 'course_hist_210',
      seriesId: 'series_hist_210_recitation',
      code: 'HIST 210',
      startMinute: 11 * 60 + 50,
      endMinute: 12 * 60 + 50,
      transitionBufferMinutes: 10,
    );
    expect(enoughRoom.transitionPressuresOn(CivilDate(2026, 8, 25)), isEmpty);
  });

  test('assignments and exams persist, sort, and complete independently', () {
    final schedule = _fixtureSchedule(weekdays: const {DateTime.tuesday});
    final course = schedule.courses.single;
    final updatedAt = DateTime.utc(2026, 8, 20, 14);
    final assignment = AcademicWorkItem(
      workId: 'work_assignment_1',
      courseId: course.courseId,
      kind: AcademicWorkKind.assignment,
      title: 'Problem set 2',
      dueDate: CivilDate(2026, 9, 3),
      dueMinute: 23 * 60 + 59,
      details: 'Problems 1–8',
      updatedAt: updatedAt,
    );
    final exam = AcademicWorkItem(
      workId: 'work_exam_1',
      courseId: course.courseId,
      kind: AcademicWorkKind.exam,
      title: 'Midterm',
      dueDate: CivilDate(2026, 9, 3),
      dueMinute: 10 * 60,
      updatedAt: updatedAt,
    );

    final withWork = schedule.putWorkItem(assignment).putWorkItem(exam);

    expect(
      withWork.workItemsOn(CivilDate(2026, 9, 3)).map((item) => item.workId),
      ['work_exam_1', 'work_assignment_1'],
    );
    final completed = withWork.setWorkItemCompleted(
      workId: assignment.workId,
      completed: true,
      updatedAt: updatedAt.add(const Duration(hours: 1)),
    );
    expect(
      completed.workItems
          .singleWhere((item) => item.workId == assignment.workId)
          .completed,
      isTrue,
    );
    expect(completed.occurrences, hasLength(schedule.occurrences.length));

    final restored = AcademicSchedule.fromJson(
      (jsonDecode(jsonEncode(completed.toJson())) as Map)
          .cast<String, dynamic>(),
    );
    expect(restored.workItems, hasLength(2));
    expect(
      restored.workItems
          .singleWhere((item) => item.workId == assignment.workId)
          .details,
      'Problems 1–8',
    );
  });

  test(
    'study suggestions honor class buffers, due time, and existing blocks',
    () {
      var schedule = _fixtureSchedule(
        weekdays: const {DateTime.tuesday},
        transitionBufferMinutes: 10,
      );
      final work = AcademicWorkItem(
        workId: 'work_problem_set',
        courseId: schedule.courses.single.courseId,
        kind: AcademicWorkKind.assignment,
        title: 'Problem set 4',
        dueDate: CivilDate(2026, 8, 26),
        dueMinute: 10 * 60,
        updatedAt: DateTime.utc(2026, 8, 24),
      );
      schedule = schedule.putWorkItem(work);
      schedule = schedule.putStudyPlan(
        plan: AcademicStudyPlan(
          workId: work.workId,
          totalMinutes: 30,
          sessionMinutes: 30,
          dailyStartMinute: 9 * 60,
          dailyEndMinute: 17 * 60,
          updatedAt: DateTime.utc(2026, 8, 24),
        ),
        blocks: [
          AcademicStudyBlock(
            studyBlockId: 'study_other',
            workId: work.workId,
            date: CivilDate(2026, 8, 24),
            startMinute: 9 * 60 + 30,
            endMinute: 10 * 60,
            completedAt: DateTime.utc(2026, 8, 24, 14),
            updatedAt: DateTime.utc(2026, 8, 24, 14),
          ),
        ],
      );

      var id = 0;
      final suggestion = schedule.suggestStudyBlocks(
        workId: work.workId,
        totalMinutes: 150,
        sessionMinutes: 60,
        dailyStartMinute: 9 * 60,
        dailyEndMinute: 17 * 60,
        now: DateTime(2026, 8, 25, 8),
        idFactory: (_) => 'study_${++id}',
      );

      expect(suggestion.completedMinutes, 30);
      expect(suggestion.scheduledMinutes, 120);
      expect(suggestion.unscheduledMinutes, 0);
      expect(suggestion.blocks, hasLength(2));
      expect(suggestion.blocks.first.date, CivilDate(2026, 8, 25));
      expect(suggestion.blocks.first.startMinute, 9 * 60);
      expect(suggestion.blocks.first.endMinute, 10 * 60);
      expect(suggestion.blocks.last.date, CivilDate(2026, 8, 26));
      expect(suggestion.blocks.last.startMinute, 9 * 60);
      expect(suggestion.blocks.last.endMinute, 10 * 60);
      expect(
        suggestion.blocks.any(
          (block) =>
              block.date == CivilDate(2026, 8, 26) && block.endMinute > 10 * 60,
        ),
        isFalse,
      );
    },
  );

  test(
    'study plan replaces only open blocks and persists completed history',
    () {
      final base = _fixtureSchedule(weekdays: const {DateTime.tuesday})
          .putWorkItem(
            AcademicWorkItem(
              workId: 'work_exam',
              courseId: 'course_ece_345',
              kind: AcademicWorkKind.exam,
              title: 'Midterm',
              dueDate: CivilDate(2026, 9, 8),
              dueMinute: 10 * 60,
              updatedAt: DateTime.utc(2026, 8, 24),
            ),
          );
      final plan = AcademicStudyPlan(
        workId: 'work_exam',
        totalMinutes: 120,
        sessionMinutes: 45,
        dailyStartMinute: 9 * 60,
        dailyEndMinute: 19 * 60,
        updatedAt: DateTime.utc(2026, 8, 24),
      );
      final first = base.putStudyPlan(
        plan: plan,
        blocks: [
          AcademicStudyBlock(
            studyBlockId: 'study_done',
            workId: 'work_exam',
            date: CivilDate(2026, 8, 24),
            startMinute: 9 * 60,
            endMinute: 9 * 60 + 30,
            completedAt: DateTime.utc(2026, 8, 24, 14),
            updatedAt: DateTime.utc(2026, 8, 24, 14),
          ),
          AcademicStudyBlock(
            studyBlockId: 'study_open',
            workId: 'work_exam',
            date: CivilDate(2026, 8, 25),
            startMinute: 13 * 60,
            endMinute: 13 * 60 + 45,
            updatedAt: DateTime.utc(2026, 8, 24),
          ),
        ],
      );
      final replanned = first.putStudyPlan(
        plan: AcademicStudyPlan(
          workId: plan.workId,
          totalMinutes: plan.totalMinutes,
          sessionMinutes: 30,
          dailyStartMinute: plan.dailyStartMinute,
          dailyEndMinute: plan.dailyEndMinute,
          revision: 2,
          updatedAt: DateTime.utc(2026, 8, 25),
        ),
        blocks: [
          AcademicStudyBlock(
            studyBlockId: 'study_new',
            workId: 'work_exam',
            date: CivilDate(2026, 8, 26),
            startMinute: 14 * 60,
            endMinute: 14 * 60 + 30,
            updatedAt: DateTime.utc(2026, 8, 25),
          ),
        ],
      );

      expect(
        replanned
            .studyBlocksFor('work_exam')
            .map((block) => block.studyBlockId),
        ['study_done', 'study_new'],
      );
      final restored = AcademicSchedule.fromJson(
        (jsonDecode(jsonEncode(replanned.toJson())) as Map)
            .cast<String, dynamic>(),
      );
      expect(restored.studyPlanFor('work_exam')?.sessionMinutes, 30);
      expect(restored.studyBlocksFor('work_exam'), hasLength(2));
    },
  );

  test(
    'completing course work clears future study blocks but keeps history',
    () {
      final base = _fixtureSchedule(weekdays: const {DateTime.tuesday})
          .putWorkItem(
            AcademicWorkItem(
              workId: 'work_exam',
              courseId: 'course_ece_345',
              kind: AcademicWorkKind.exam,
              title: 'Midterm',
              dueDate: CivilDate(2026, 9, 8),
              updatedAt: DateTime.utc(2026, 8, 24),
            ),
          );
      final withStudy = base.putStudyPlan(
        plan: AcademicStudyPlan(
          workId: 'work_exam',
          totalMinutes: 90,
          sessionMinutes: 45,
          dailyStartMinute: 9 * 60,
          dailyEndMinute: 18 * 60,
          updatedAt: DateTime.utc(2026, 8, 24),
        ),
        blocks: [
          AcademicStudyBlock(
            studyBlockId: 'study_done',
            workId: 'work_exam',
            date: CivilDate(2026, 8, 24),
            startMinute: 9 * 60,
            endMinute: 9 * 60 + 45,
            completedAt: DateTime.utc(2026, 8, 24, 14),
            updatedAt: DateTime.utc(2026, 8, 24, 14),
          ),
          AcademicStudyBlock(
            studyBlockId: 'study_future',
            workId: 'work_exam',
            date: CivilDate(2026, 8, 25),
            startMinute: 9 * 60,
            endMinute: 9 * 60 + 45,
            updatedAt: DateTime.utc(2026, 8, 24),
          ),
        ],
      );

      final completed = withStudy.setWorkItemCompleted(
        workId: 'work_exam',
        completed: true,
        updatedAt: DateTime.utc(2026, 8, 24, 15),
      );

      expect(completed.studyBlocksFor('work_exam'), hasLength(1));
      expect(completed.studyBlocksFor('work_exam').single.completed, isTrue);
      expect(completed.studyPlanFor('work_exam'), isNotNull);
    },
  );

  test(
    'moving a class refits open study blocks and preserves completed history',
    () {
      var schedule = _fixtureSchedule(weekdays: const {DateTime.tuesday});
      schedule = schedule.putWorkItem(
        AcademicWorkItem(
          workId: 'work_exam',
          courseId: schedule.courses.single.courseId,
          kind: AcademicWorkKind.exam,
          title: 'Midterm',
          dueDate: CivilDate(2026, 8, 28),
          dueMinute: 17 * 60,
          updatedAt: DateTime.utc(2026, 8, 24, 13),
        ),
      );
      schedule = schedule.putStudyPlan(
        plan: AcademicStudyPlan(
          workId: 'work_exam',
          totalMinutes: 90,
          sessionMinutes: 45,
          dailyStartMinute: 9 * 60,
          dailyEndMinute: 12 * 60,
          updatedAt: DateTime.utc(2026, 8, 24, 13),
        ),
        blocks: [
          AcademicStudyBlock(
            studyBlockId: 'study_done',
            workId: 'work_exam',
            date: CivilDate(2026, 8, 24),
            startMinute: 9 * 60,
            endMinute: 9 * 60 + 45,
            completedAt: DateTime.utc(2026, 8, 24, 14),
            updatedAt: DateTime.utc(2026, 8, 24, 14),
          ),
          AcademicStudyBlock(
            studyBlockId: 'study_stale',
            workId: 'work_exam',
            date: CivilDate(2026, 8, 26),
            startMinute: 10 * 60,
            endMinute: 10 * 60 + 45,
            updatedAt: DateTime.utc(2026, 8, 24, 13),
          ),
        ],
      );
      final occurrence = schedule.occurrences.first;
      var id = 0;

      final moved = schedule.moveOccurrence(
        occurrenceKey: occurrence.occurrenceKey,
        date: CivilDate(2026, 8, 26),
        startMinute: 9 * 60 + 30,
        endMinute: 11 * 60,
        updatedAt: DateTime.utc(2026, 8, 24, 15),
        idFactory: (_) => 'study_reflow_${++id}',
      );
      final blocks = moved.studyBlocksFor('work_exam');

      expect(blocks.where((block) => block.completed), hasLength(1));
      expect(
        blocks.singleWhere((block) => block.completed).studyBlockId,
        'study_done',
      );
      expect(
        blocks.any((block) => block.studyBlockId == 'study_stale'),
        isFalse,
      );
      expect(
        blocks
            .where((block) => !block.completed)
            .any(
              (block) =>
                  block.date == CivilDate(2026, 8, 26) &&
                  block.startMinute < 11 * 60 + 10 &&
                  block.endMinute > 9 * 60 + 20,
            ),
        isFalse,
      );
      expect(moved.plannedStudyMinutesFor('work_exam'), 90);
    },
  );

  test('schema 1 schedules migrate with an empty academic work list', () {
    final legacy = _fixtureSchedule(weekdays: const {DateTime.tuesday}).toJson()
      ..['schema'] = 1
      ..remove('workItems');

    final restored = AcademicSchedule.fromJson(legacy);

    expect(restored.workItems, isEmpty);
    expect(restored.occurrences, isNotEmpty);
  });

  test('schema 2 schedules adopt a ten minute transition buffer', () {
    final legacy = _fixtureSchedule(weekdays: const {DateTime.tuesday}).toJson()
      ..['schema'] = 2;
    for (final rawSeries in legacy['meetingSeries']! as List) {
      (rawSeries as Map).remove('transitionBufferMinutes');
    }

    final restored = AcademicSchedule.fromJson(legacy);

    expect(restored.meetingSeries.single.transitionBufferMinutes, 10);
    expect(restored.toJson()['schema'], AcademicSchedule.currentSchema);
  });

  test('schema 3 schedules migrate with no invented study plan', () {
    final legacy = _fixtureSchedule(weekdays: const {DateTime.tuesday}).toJson()
      ..['schema'] = 3
      ..remove('studyPlans')
      ..remove('studyBlocks');

    final restored = AcademicSchedule.fromJson(legacy);

    expect(restored.studyPlans, isEmpty);
    expect(restored.studyBlocks, isEmpty);
  });

  test('schemas 1 through 4 never invent neutral records', () {
    final combined = _fixtureSchedule(
      weekdays: const {DateTime.tuesday},
    ).putEvent(_generalEvent()).putTask(_generalTask());

    for (final schema in [1, 2, 3, 4]) {
      final legacy = combined.toJson()..['schema'] = schema;
      final restored = AcademicSchedule.fromJson(legacy);

      expect(restored.events, isEmpty, reason: 'schema $schema events');
      expect(restored.tasks, isEmpty, reason: 'schema $schema tasks');
      expect(restored.occurrences, isNotEmpty, reason: 'schema $schema class');
    }
  });

  test('schema 5 round-trips academic classes, events, and tasks', () {
    final combined = _fixtureSchedule(
      weekdays: const {DateTime.tuesday},
    ).putEvent(_generalEvent()).putTask(_generalTask());

    final restored = AcademicSchedule.fromJson(
      (jsonDecode(jsonEncode(combined.toJson())) as Map)
          .cast<String, dynamic>(),
    );

    expect(restored.toJson()['schema'], 5);
    expect(restored.occurrences, hasLength(combined.occurrences.length));
    expect(restored.events.single.eventId, 'event_team');
    expect(restored.tasks.single.taskId, 'task_submit');
  });

  test('general event mutations preserve moved and cancelled exceptions', () {
    final changedAt = DateTime.utc(2026, 8, 20, 15);
    var schedule = AcademicSchedule.empty()
        .putEvent(_generalEvent())
        .putTask(_generalTask());

    schedule = schedule.moveEventOccurrence(
      eventId: 'event_team',
      occurrenceKey: 'event_team@2026-08-10',
      startDate: CivilDate(2026, 8, 11),
      endDate: CivilDate(2026, 8, 11),
      startMinute: 11 * 60,
      endMinute: 12 * 60,
      updatedAt: changedAt,
    );
    schedule = schedule.cancelEventOccurrence(
      eventId: 'event_team',
      occurrenceKey: 'event_team@2026-08-17',
      updatedAt: changedAt.add(const Duration(minutes: 1)),
    );
    schedule = schedule.putEvent(
      schedule.events.single.copyWith(title: 'Team sync revised'),
    );

    schedule = AcademicSchedule.fromJson(
      (jsonDecode(jsonEncode(schedule.toJson())) as Map)
          .cast<String, dynamic>(),
    );

    final occurrences = schedule.eventOccurrencesBetween(
      CivilDate(2026, 8, 1),
      CivilDate(2026, 8, 31),
    );
    final moved = occurrences.singleWhere(
      (item) => item.occurrenceKey == 'event_team@2026-08-10',
    );
    final cancelled = occurrences.singleWhere(
      (item) => item.occurrenceKey == 'event_team@2026-08-17',
    );
    expect(moved.state, DaybookEventOccurrenceState.moved);
    expect(moved.startDate, CivilDate(2026, 8, 11));
    expect(cancelled.state, DaybookEventOccurrenceState.cancelled);
    expect(
      schedule.tasksOn(CivilDate(2026, 8, 21)).single.taskId,
      'task_submit',
    );

    final restored = schedule.restoreEventOccurrence(
      eventId: 'event_team',
      occurrenceKey: cancelled.occurrenceKey,
      updatedAt: changedAt.add(const Duration(minutes: 2)),
    );
    expect(
      restored
          .eventOccurrencesBetween(
            CivilDate(2026, 8, 17),
            CivilDate(2026, 8, 17),
          )
          .single
          .state,
      DaybookEventOccurrenceState.scheduled,
    );
    expect(restored.deleteEvent('event_team').events, isEmpty);
    expect(restored.deleteTask('task_submit').tasks, isEmpty);
  });

  test('every academic reconstruction preserves neutral collections', () {
    final event = _generalEvent();
    final task = _generalTask();
    final base = _fixtureSchedule(
      weekdays: const {DateTime.tuesday},
    ).putEvent(event).putTask(task);
    final work = AcademicWorkItem(
      workId: 'work_preservation',
      courseId: base.courses.single.courseId,
      kind: AcademicWorkKind.assignment,
      title: 'Preservation exercise',
      dueDate: CivilDate(2026, 9, 1),
      dueMinute: 17 * 60,
      updatedAt: DateTime.utc(2026, 8, 24),
    );
    final withWork = base.putWorkItem(work);
    final plan = AcademicStudyPlan(
      workId: work.workId,
      totalMinutes: 45,
      sessionMinutes: 45,
      dailyStartMinute: 13 * 60,
      dailyEndMinute: 18 * 60,
      updatedAt: DateTime.utc(2026, 8, 24),
    );
    final block = AcademicStudyBlock(
      studyBlockId: 'study_preservation',
      workId: work.workId,
      date: CivilDate(2026, 8, 27),
      startMinute: 13 * 60,
      endMinute: 13 * 60 + 45,
      updatedAt: DateTime.utc(2026, 8, 24),
    );
    final withStudy = withWork.putStudyPlan(plan: plan, blocks: [block]);
    final occurrence = withStudy.occurrences.first;
    final moved = withStudy.moveOccurrence(
      occurrenceKey: occurrence.occurrenceKey,
      date: occurrence.date.addDays(1),
      startMinute: occurrence.localStartMinute,
      endMinute: occurrence.localEndMinute,
      updatedAt: DateTime.utc(2026, 8, 24, 14),
    );

    final rebuiltMeeting = withStudy.putMeeting(
      term: withStudy.terms.single,
      course: withStudy.courses.single,
      series: withStudy.meetingSeries.single,
      updatedAt: DateTime.utc(2026, 8, 24, 14),
    );
    final cancelled = withStudy.cancelOccurrence(
      occurrenceKey: occurrence.occurrenceKey,
      updatedAt: DateTime.utc(2026, 8, 24, 14),
    );
    final restored = moved.restoreOccurrence(
      occurrenceKey: occurrence.occurrenceKey,
      updatedAt: DateTime.utc(2026, 8, 24, 14, 1),
    );
    final replanned = withStudy.reflowOpenStudyPlans(
      now: DateTime.utc(2026, 8, 24, 14),
      idFactory: (_) => 'study_replanned',
    );
    final replacedWork = withStudy.putWorkItem(
      AcademicWorkItem(
        workId: work.workId,
        courseId: work.courseId,
        kind: work.kind,
        title: 'Preservation exercise revised',
        dueDate: work.dueDate,
        dueMinute: work.dueMinute,
        updatedAt: DateTime.utc(2026, 8, 24, 14),
      ),
    );
    final replacedPlan = withStudy.putStudyPlan(
      plan: AcademicStudyPlan(
        workId: work.workId,
        totalMinutes: 30,
        sessionMinutes: 30,
        dailyStartMinute: 13 * 60,
        dailyEndMinute: 18 * 60,
        revision: 2,
        updatedAt: DateTime.utc(2026, 8, 24, 14),
      ),
      blocks: [
        AcademicStudyBlock(
          studyBlockId: 'study_replacement',
          workId: work.workId,
          date: CivilDate(2026, 8, 28),
          startMinute: 14 * 60,
          endMinute: 14 * 60 + 30,
          updatedAt: DateTime.utc(2026, 8, 24, 14),
        ),
      ],
    );
    final completedBlock = withStudy.setStudyBlockCompleted(
      studyBlockId: block.studyBlockId,
      completed: true,
      updatedAt: DateTime.utc(2026, 8, 24, 14),
    );
    final completedWork = withStudy.setWorkItemCompleted(
      workId: work.workId,
      completed: true,
      updatedAt: DateTime.utc(2026, 8, 24, 14),
    );

    for (final rebuilt in [
      rebuiltMeeting,
      moved,
      cancelled,
      restored,
      replanned,
      replacedWork,
      replacedPlan,
      completedBlock,
      completedWork,
    ]) {
      expect(rebuilt.events.single.eventId, event.eventId);
      expect(rebuilt.tasks.single.taskId, task.taskId);
    }
  });

  test('academic work must reference a course and stay inside its term', () {
    final schedule = _fixtureSchedule(weekdays: const {DateTime.tuesday});
    AcademicWorkItem item(String courseId, CivilDate date) => AcademicWorkItem(
      workId: 'work_1',
      courseId: courseId,
      kind: AcademicWorkKind.assignment,
      title: 'Problem set',
      dueDate: date,
      updatedAt: DateTime.utc(2026, 8, 20),
    );

    expect(
      () => schedule.putWorkItem(item('missing_course', CivilDate(2026, 9, 1))),
      throwsArgumentError,
    );
    expect(
      () => schedule.putWorkItem(
        item(schedule.courses.single.courseId, CivilDate(2027, 1, 1)),
      ),
      throwsArgumentError,
    );
  });

  test('local repository reloads the same occurrence identities', () async {
    final repository = LocalAcademicScheduleRepository();
    final schedule = _fixtureSchedule(
      weekdays: const {DateTime.monday, DateTime.wednesday},
    ).putEvent(_generalEvent()).putTask(_generalTask());

    expect(await repository.save(schedule), isTrue);
    final restored = await repository.load();

    expect(restored.occurrences, hasLength(schedule.occurrences.length));
    expect(
      restored.occurrences.map((item) => item.occurrenceKey),
      schedule.occurrences.map((item) => item.occurrenceKey),
    );
    expect(restored.events.single.eventId, 'event_team');
    expect(restored.tasks.single.taskId, 'task_submit');
    expect(repository.lastRecoveredRecordCount, 0);
  });

  test(
    'local repository quarantines malformed bytes before starting fresh',
    () async {
      SharedPreferences.setMockInitialValues({
        LocalAcademicScheduleRepository.storageKey: '{not-json',
      });
      final repository = LocalAcademicScheduleRepository();

      final restored = await repository.load();
      final preferences = await SharedPreferences.getInstance();

      expect(restored.occurrences, isEmpty);
      expect(
        preferences.getString(LocalAcademicScheduleRepository.corruptBackupKey),
        '{not-json',
      );
    },
  );

  test(
    'local repository recovers valid neutral records independently',
    () async {
      final combined = _fixtureSchedule(
        weekdays: const {DateTime.tuesday},
      ).putEvent(_generalEvent()).putTask(_generalTask());
      final root = combined.toJson();
      root['events'] = [
        _generalEvent().toJson(),
        {'eventId': 'malformed_event'},
      ];
      final raw = jsonEncode(root);
      SharedPreferences.setMockInitialValues({
        LocalAcademicScheduleRepository.storageKey: raw,
      });
      final repository = LocalAcademicScheduleRepository();

      final restored = await repository.load();
      final preferences = await SharedPreferences.getInstance();

      expect(restored.occurrences, isNotEmpty);
      expect(restored.events.single.eventId, 'event_team');
      expect(restored.tasks.single.taskId, 'task_submit');
      expect(repository.lastRecoveredRecordCount, 1);
      expect(
        preferences.getString(LocalAcademicScheduleRepository.corruptBackupKey),
        raw,
      );
    },
  );

  test('neutral recovery never hides an invalid academic graph', () async {
    final root = _fixtureSchedule(
      weekdays: const {DateTime.tuesday},
    ).putEvent(_generalEvent()).putTask(_generalTask()).toJson();
    root['terms'] = <Object>[];
    final raw = jsonEncode(root);
    SharedPreferences.setMockInitialValues({
      LocalAcademicScheduleRepository.storageKey: raw,
    });
    final repository = LocalAcademicScheduleRepository();

    final restored = await repository.load();
    final preferences = await SharedPreferences.getInstance();

    expect(restored.occurrences, isEmpty);
    expect(restored.events, isEmpty);
    expect(restored.tasks, isEmpty);
    expect(repository.lastRecoveredRecordCount, 0);
    expect(
      preferences.getString(LocalAcademicScheduleRepository.corruptBackupKey),
      raw,
    );
  });

  test('notebook handoff matches v2 and safely encodes opaque IDs', () {
    final codec = NotebookHandoffCodec.fromBase(
      'notebook-preview://calendar/open',
    );
    final uri = codec.encode(
      NotebookHandoffIntent(
        courseId: 'course/日本語 & physics',
        occurrenceKey: 'occurrence?Tue=10:20',
        notebookId: 'notebook #1',
        courseCode: 'PHYS 227',
        courseTitle: 'Waves & 日本語',
        occurrenceDate: '2026-10-08',
        startMinute: 9 * 60,
        endMinute: 10 * 60 + 20,
        meetingKind: 'lab',
        place: 'Physics / room A&B',
        courseColorValue: 0xFFB87952,
      ),
    );

    expect(uri.scheme, 'notebook-preview');
    expect(uri.host, 'calendar');
    expect(uri.path, '/open');
    expect(uri.queryParameters, {
      'v': '2',
      'courseId': 'course/日本語 & physics',
      'occurrenceKey': 'occurrence?Tue=10:20',
      'notebookId': 'notebook #1',
      'courseCode': 'PHYS 227',
      'courseTitle': 'Waves & 日本語',
      'occurrenceDate': '2026-10-08',
      'startMinute': '540',
      'endMinute': '620',
      'meetingKind': 'lab',
      'place': 'Physics / room A&B',
      'courseColor': 'FFB87952',
    });
    expect(uri.queryParameters.containsKey('pageId'), isFalse);
  });

  test('notebook handoff rejects malformed display hints', () {
    expect(
      () => NotebookHandoffIntent(
        courseId: 'course',
        occurrenceKey: 'occurrence',
        occurrenceDate: '2026-02-30',
      ),
      throwsArgumentError,
    );
    expect(
      () => NotebookHandoffIntent(
        courseId: 'course',
        occurrenceKey: 'occurrence',
        startMinute: 12 * 60,
        endMinute: 11 * 60,
      ),
      throwsArgumentError,
    );
  });

  test('meeting validation rejects missing days and backwards times', () {
    expect(() => _series(weekdays: const {}), throwsArgumentError);
    expect(
      () => _series(
        weekdays: const {DateTime.monday},
        startMinute: 12 * 60,
        endMinute: 11 * 60,
      ),
      throwsArgumentError,
    );
    expect(
      () => _series(
        weekdays: const {DateTime.monday},
        transitionBufferMinutes: 121,
      ),
      throwsArgumentError,
    );
  });
}

AcademicSchedule _fixtureSchedule({
  required Set<int> weekdays,
  AcademicIdFactory idFactory = AcademicIds.create,
  int transitionBufferMinutes = 10,
}) {
  final term = AcademicTerm(
    termId: 'term_fall_2026',
    name: 'Fall 2026',
    startDate: CivilDate(2026, 8, 24),
    endDate: CivilDate(2026, 12, 18),
    timeZoneId: 'America/New_York',
  );
  final course = AcademicCourse(
    courseId: 'course_ece_345',
    termId: term.termId,
    code: 'ECE 345',
    title: 'Linear Systems',
    colorValue: 0xFF8AAFC6,
    colorLabel: 'Dusk blue',
  );
  final series = _series(
    weekdays: weekdays,
    transitionBufferMinutes: transitionBufferMinutes,
  );
  return AcademicSchedule.empty().putMeeting(
    term: term,
    course: course,
    series: series,
    updatedAt: DateTime.utc(2026, 8, 11),
    idFactory: idFactory,
  );
}

MeetingSeries _series({
  required Set<int> weekdays,
  int startMinute = 10 * 60 + 20,
  int endMinute = 11 * 60 + 40,
  int transitionBufferMinutes = 10,
}) => MeetingSeries(
  meetingSeriesId: 'series_ece_345_lecture',
  courseId: 'course_ece_345',
  kind: MeetingKind.lecture,
  weekdays: weekdays,
  localStartMinute: startMinute,
  localEndMinute: endMinute,
  transitionBufferMinutes: transitionBufferMinutes,
  firstDate: CivilDate(2026, 8, 24),
  lastDate: CivilDate(2026, 12, 18),
  timeZoneId: 'America/New_York',
  place: CampusPlace(
    label: 'Hill Center 114',
    building: 'Hill Center',
    room: '114',
  ),
  reminders: [
    AcademicReminder(reminderId: 'reminder_ece_345_10m', offsetMinutes: 10),
  ],
  updatedAt: DateTime.utc(2026, 8, 11),
);

AcademicSchedule _addClass(
  AcademicSchedule schedule, {
  required String courseId,
  required String seriesId,
  required String code,
  required int startMinute,
  required int endMinute,
  int transitionBufferMinutes = 10,
}) {
  final term = schedule.terms.single;
  var occurrenceIndex = 0;
  final course = AcademicCourse(
    courseId: courseId,
    termId: term.termId,
    code: code,
    title: code,
    colorValue: 0xFF9CBC88,
    colorLabel: 'Moss',
  );
  return schedule.putMeeting(
    term: term,
    course: course,
    series: MeetingSeries(
      meetingSeriesId: seriesId,
      courseId: courseId,
      kind: MeetingKind.lab,
      weekdays: const {DateTime.tuesday},
      localStartMinute: startMinute,
      localEndMinute: endMinute,
      transitionBufferMinutes: transitionBufferMinutes,
      firstDate: term.startDate,
      lastDate: term.endDate,
      timeZoneId: term.timeZoneId,
      place: CampusPlace(label: 'Wright Labs B12'),
      updatedAt: DateTime.utc(2026, 8, 12),
    ),
    updatedAt: DateTime.utc(2026, 8, 12),
    idFactory: (_) => 'occurrence_${courseId}_${++occurrenceIndex}',
  );
}

DaybookEvent _generalEvent() => DaybookEvent(
  eventId: 'event_team',
  title: 'Team sync',
  startDate: CivilDate(2026, 8, 3),
  endDate: CivilDate(2026, 8, 3),
  timeZoneId: 'America/New_York',
  allDay: false,
  startMinute: 9 * 60,
  endMinute: 10 * 60,
  weeklyRule: WeeklyEventRule(weekdays: const {DateTime.monday}),
  createdAt: DateTime.utc(2026, 8, 1, 12),
  updatedAt: DateTime.utc(2026, 8, 2, 12),
);

DaybookTask _generalTask() => DaybookTask(
  taskId: 'task_submit',
  title: 'Submit form',
  dueDate: CivilDate(2026, 8, 21),
  dueMinute: 17 * 60,
  createdAt: DateTime.utc(2026, 8, 1, 12),
  updatedAt: DateTime.utc(2026, 8, 2, 12),
);
