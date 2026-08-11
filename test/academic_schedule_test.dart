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

  test('notebook handoff matches v1 and safely encodes opaque IDs', () {
    final codec = NotebookHandoffCodec.fromBase(
      'notebook-preview://calendar/open',
    );
    final uri = codec.encode(
      NotebookHandoffIntent(
        courseId: 'course/日本語 & physics',
        occurrenceKey: 'occurrence?Tue=10:20',
        notebookId: 'notebook #1',
      ),
    );

    expect(uri.scheme, 'notebook-preview');
    expect(uri.host, 'calendar');
    expect(uri.path, '/open');
    expect(uri.queryParameters, {
      'v': '1',
      'courseId': 'course/日本語 & physics',
      'occurrenceKey': 'occurrence?Tue=10:20',
      'notebookId': 'notebook #1',
    });
    expect(uri.queryParameters.containsKey('pageId'), isFalse);
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
