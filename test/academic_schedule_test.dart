import 'dart:convert';

import 'package:emberkeep/academic_calendar/data/academic_schedule_repository.dart';
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/services/notebook_handoff.dart';
import 'package:emberkeep/clock.dart';
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
      );
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
    },
  );

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

  test('schema 1 schedules migrate with an empty academic work list', () {
    final legacy = _fixtureSchedule(weekdays: const {DateTime.tuesday}).toJson()
      ..['schema'] = 1
      ..remove('workItems');

    final restored = AcademicSchedule.fromJson(legacy);

    expect(restored.workItems, isEmpty);
    expect(restored.occurrences, isNotEmpty);
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
    );

    expect(await repository.save(schedule), isTrue);
    final restored = await repository.load();

    expect(restored.occurrences, hasLength(schedule.occurrences.length));
    expect(
      restored.occurrences.map((item) => item.occurrenceKey),
      schedule.occurrences.map((item) => item.occurrenceKey),
    );
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
  });
}

AcademicSchedule _fixtureSchedule({
  required Set<int> weekdays,
  AcademicIdFactory idFactory = AcademicIds.create,
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
  final series = _series(weekdays: weekdays);
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
}) => MeetingSeries(
  meetingSeriesId: 'series_ece_345_lecture',
  courseId: 'course_ece_345',
  kind: MeetingKind.lecture,
  weekdays: weekdays,
  localStartMinute: startMinute,
  localEndMinute: endMinute,
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
