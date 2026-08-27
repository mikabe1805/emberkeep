import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/rutgers_fall_2026_ics_fixture.dart';

void main() {
  test('imports the Rutgers Fall 2026 grid, designated days, and recess', () {
    final draft = AcademicScheduleIcsImporter.parse(
      rutgersFall2026IcsFixture(),
    );
    final once = draft.applyTo(
      AcademicSchedule.empty(),
      updatedAt: DateTime.utc(2026, 8, 27),
    );

    expect(draft.courses, hasLength(6));
    expect(draft.meetingSeriesCount, 12);
    expect(draft.projectedOccurrenceCount, 168);
    expect(
      once.occurrences.where((item) => item.state != OccurrenceState.cancelled),
      hasLength(168),
    );
    expect(_on(once, 2026, 9, 8), hasLength(3)); // designated Monday
    expect(_on(once, 2026, 11, 25), hasLength(2)); // designated Friday
    expect(
      _on(once, 2026, 9, 8).any((item) => item.originalDate != item.date),
      isTrue,
    );
    expect(
      _on(once, 2026, 11, 25).any((item) => item.originalDate != item.date),
      isTrue,
    );
    expect(
      once
          .occurrencesOn(CivilDate(2026, 9, 8))
          .any((item) => item.state == OccurrenceState.cancelled),
      isTrue,
    );
    expect(
      once
          .occurrencesOn(CivilDate(2026, 11, 25))
          .any((item) => item.state == OccurrenceState.cancelled),
      isTrue,
    );
    expect(
      once
          .occurrencesOn(CivilDate(2026, 11, 26))
          .every((item) => item.state == OccurrenceState.cancelled),
      isTrue,
    );
    final december = _on(once, 2026, 12, 7).first;
    expect(december.startInstant.timeZoneOffset, Duration.zero);
    expect(december.startInstant.hour, 13); // 08:30 EST after DST
    expect(once.meetingSeries.first.place.building, isNotNull);

    final twice = draft.applyTo(once, updatedAt: DateTime.utc(2026, 8, 28));
    expect(twice.terms, hasLength(1));
    expect(twice.courses, hasLength(6));
    expect(twice.meetingSeries, hasLength(12));
    expect(twice.occurrences, hasLength(once.occurrences.length));
    expect(
      twice.occurrences.map((item) => item.occurrenceKey).toSet(),
      once.occurrences.map((item) => item.occurrenceKey).toSet(),
    );
  });

  test('rejects an all-day or unsupported input', () {
    expect(
      () => AcademicScheduleIcsImporter.parse(
        'BEGIN:VEVENT\nDTSTART;VALUE=DATE:20260901\nEND:VEVENT',
      ),
      throwsFormatException,
    );
  });

  test('re-import preserves manual changes to source exceptions', () {
    final draft = AcademicScheduleIcsImporter.parse(
      rutgersFall2026IcsFixture(),
    );
    var schedule = draft.applyTo(
      AcademicSchedule.empty(),
      updatedAt: DateTime.utc(2026, 8, 27),
    );

    final movedBySource = schedule.occurrences.firstWhere(
      (item) => item.state == OccurrenceState.moved && item.userAdjusted,
    );
    schedule = schedule.cancelOccurrence(
      occurrenceKey: movedBySource.occurrenceKey,
      updatedAt: DateTime.utc(2026, 8, 28),
    );

    final cancelledBySource = schedule.occurrences.firstWhere(
      (item) =>
          item.occurrenceKey != movedBySource.occurrenceKey &&
          item.state == OccurrenceState.cancelled &&
          item.userAdjusted,
    );
    final manualDate = cancelledBySource.originalDate.addDays(2);
    schedule = schedule.moveOccurrence(
      occurrenceKey: cancelledBySource.occurrenceKey,
      date: manualDate,
      startMinute: 12 * 60,
      endMinute: 13 * 60,
      updatedAt: DateTime.utc(2026, 8, 28),
    );

    final refreshed = draft.applyTo(
      schedule,
      updatedAt: DateTime.utc(2026, 8, 29),
    );
    expect(
      refreshed.occurrenceByKey(movedBySource.occurrenceKey)?.state,
      OccurrenceState.cancelled,
    );
    final keptMove = refreshed.occurrenceByKey(cancelledBySource.occurrenceKey);
    expect(keptMove?.state, OccurrenceState.moved);
    expect(keptMove?.date, manualDate);
    expect(keptMove?.localStartMinute, 12 * 60);
    expect(keptMove?.localEndMinute, 13 * 60);
  });
}

List<ClassOccurrence> _on(
  AcademicSchedule schedule,
  int year,
  int month,
  int day,
) => schedule
    .occurrencesOn(CivilDate(year, month, day))
    .where((item) => item.state != OccurrenceState.cancelled)
    .toList();
