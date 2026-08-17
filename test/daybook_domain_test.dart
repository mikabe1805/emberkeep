import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart'
    hide CivilDate;
import 'package:emberkeep/daybook/adapters/campus_place_adapter.dart';
import 'package:emberkeep/daybook/domain/civil_date.dart';
import 'package:emberkeep/daybook/domain/daybook_event.dart';
import 'package:emberkeep/daybook/domain/daybook_place.dart';
import 'package:emberkeep/daybook/domain/daybook_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime.utc(2026, 8, 1, 12);
  final updatedAt = DateTime.utc(2026, 8, 2, 12);

  test('CivilDate remains a neutral date value', () {
    expect(CivilDate.parse('2026-08-17').addDays(1).toString(), '2026-08-18');
  });

  test('DaybookPlace preserves a Google destination in JSON', () {
    final place = DaybookPlace(
      savedName: 'Busch Student Center',
      routingText: '604 Bartholomew Road, Piscataway, NJ',
      building: 'Busch Student Center',
      room: '174',
      provider: DaybookPlaceProvider.google,
      providerPlaceId: 'ChIJBUSCH',
    );

    expect(place.hasGoogleDestination, isTrue);
    expect(place.hasAppleDestination, isFalse);
    expect(place.toJson(), {
      'savedName': 'Busch Student Center',
      'routingText': '604 Bartholomew Road, Piscataway, NJ',
      'building': 'Busch Student Center',
      'room': '174',
      'provider': 'google',
      'providerPlaceId': 'ChIJBUSCH',
    });
  });

  test('DaybookEvent serializes a valid overnight timed event', () {
    final event = DaybookEvent(
      eventId: 'event-1',
      title: 'Overnight lab',
      startDate: CivilDate(2026, 8, 17),
      endDate: CivilDate(2026, 8, 18),
      timeZoneId: 'America/New_York',
      allDay: false,
      startMinute: 23 * 60,
      endMinute: 60,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    expect(event.toJson(), containsPair('endDate', '2026-08-18'));
    expect(
      () => event.copyWith(endDate: CivilDate(2026, 8, 19)),
      throwsArgumentError,
    );
  });

  test('DaybookEvent rejects a timed event with no positive duration', () {
    final sameDayTimed = DaybookEvent(
      eventId: 'event-2',
      title: 'Study block',
      startDate: CivilDate(2026, 8, 17),
      endDate: CivilDate(2026, 8, 17),
      timeZoneId: 'America/New_York',
      allDay: false,
      startMinute: 9 * 60,
      endMinute: 10 * 60,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    expect(() => sameDayTimed.copyWith(endMinute: 540), throwsArgumentError);
  });

  test('DaybookEvent materializes exception state for a weekly occurrence', () {
    final event = DaybookEvent(
      eventId: 'event-3',
      title: 'Studio',
      startDate: CivilDate(2026, 8, 17),
      endDate: CivilDate(2026, 8, 17),
      timeZoneId: 'America/New_York',
      allDay: false,
      startMinute: 9 * 60,
      endMinute: 10 * 60,
      weeklyRule: WeeklyEventRule(weekdays: {DateTime.monday}),
      exceptions: [
        DaybookEventException(
          occurrenceKey: 'event-3/2026-08-24',
          originalDate: CivilDate(2026, 8, 24),
          state: DaybookEventOccurrenceState.moved,
          movedStartDate: CivilDate(2026, 8, 25),
          movedEndDate: CivilDate(2026, 8, 25),
          movedStartMinute: 11 * 60,
          movedEndMinute: 12 * 60,
          updatedAt: updatedAt,
        ),
      ],
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final occurrence = event.occurrenceFor(CivilDate(2026, 8, 24));
    expect(occurrence.state, DaybookEventOccurrenceState.moved);
    expect(occurrence.startDate, CivilDate(2026, 8, 25));
    expect(occurrence.startMinute, 11 * 60);
  });

  test('DaybookEventOccurrence copies and restores its JSON value', () {
    final occurrence = DaybookEventOccurrence(
      eventId: 'event-4',
      occurrenceKey: 'event-4/2026-08-17',
      originalDate: CivilDate(2026, 8, 17),
      startDate: CivilDate(2026, 8, 17),
      endDate: CivilDate(2026, 8, 17),
      allDay: false,
      startMinute: 9 * 60,
      endMinute: 10 * 60,
      state: DaybookEventOccurrenceState.scheduled,
    );

    expect(
      DaybookEventOccurrence.fromJson(
        occurrence.toJson(),
      ).copyWith(state: DaybookEventOccurrenceState.cancelled).state,
      DaybookEventOccurrenceState.cancelled,
    );
  });

  test(
    'DaybookTask completion can be undone without changing its due date',
    () {
      final completedAt = DateTime.utc(2026, 8, 16, 18);
      final task = DaybookTask(
        taskId: 'task-1',
        title: 'Submit lab report',
        dueDate: CivilDate(2026, 8, 17),
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      expect(
        task.complete(at: completedAt).undoCompletion().dueDate,
        CivilDate(2026, 8, 17),
      );
    },
  );

  test('CampusPlace adapter round-trips the legacy campus fields', () {
    final legacy = CampusPlace(
      label: 'Wright Labs B12',
      building: 'Wright Labs',
      room: 'B12',
      address: '123 Bevier Road, Piscataway, NJ',
      latitude: 40.5231,
      longitude: -74.4612,
      mapsProvider: 'google',
      placeId: 'ChIJWRIGHT',
      campusCode: 'BUSCH',
    );

    expect(
      CampusPlaceDaybookAdapter.toCampusPlace(
        CampusPlaceDaybookAdapter.fromCampusPlace(legacy),
        original: legacy,
      ).toJson(),
      legacy.toJson(),
    );
  });
}
