import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart'
    hide CivilDate;
import 'package:emberkeep/daybook/adapters/campus_place_adapter.dart';
import 'package:emberkeep/daybook/domain/civil_date.dart';
import 'package:emberkeep/daybook/domain/daybook_event.dart';
import 'package:emberkeep/daybook/domain/daybook_place.dart';
import 'package:emberkeep/daybook/domain/daybook_task.dart';
import 'package:emberkeep/daybook/domain/weekly_event_materializer.dart';
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
    expect(place.hasAppleDestination, isTrue);
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

  test(
    'CampusPlace adapter preserves unknown legacy maps metadata until Google replaces it',
    () {
      final legacy = CampusPlace(
        label: 'Engineering Building',
        building: 'Engineering Building',
        room: '201',
        address: '98 Brett Road, Piscataway, NJ',
        latitude: 40.5224,
        longitude: -74.4639,
        mapsProvider: 'rutgers-campus-map',
        placeId: 'legacy-campus-place-201',
        campusCode: 'BUSCH',
      );
      final neutral = CampusPlaceDaybookAdapter.fromCampusPlace(legacy);

      expect(
        CampusPlaceDaybookAdapter.toCampusPlace(
          neutral,
          original: legacy,
        ).toJson(),
        legacy.toJson(),
      );
      expect(
        CampusPlaceDaybookAdapter.toCampusPlace(
          neutral.copyWith(
            provider: DaybookPlaceProvider.google,
            providerPlaceId: 'ChIJREPLACED',
          ),
          original: legacy,
        ).toJson(),
        containsPair('mapsProvider', 'google'),
      );
    },
  );

  test(
    'DaybookEvent rejects multiple exceptions for one original occurrence',
    () {
      final exception = DaybookEventException(
        occurrenceKey: 'event-5/2026-08-24/a',
        originalDate: CivilDate(2026, 8, 24),
        state: DaybookEventOccurrenceState.moved,
        movedStartDate: CivilDate(2026, 8, 25),
        movedEndDate: CivilDate(2026, 8, 25),
        movedStartMinute: 11 * 60,
        movedEndMinute: 12 * 60,
        updatedAt: updatedAt,
      );

      expect(
        () => DaybookEvent(
          eventId: 'event-5',
          title: 'Studio',
          startDate: CivilDate(2026, 8, 17),
          endDate: CivilDate(2026, 8, 17),
          timeZoneId: 'America/New_York',
          allDay: false,
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          weeklyRule: WeeklyEventRule(weekdays: {DateTime.monday}),
          exceptions: [
            exception,
            exception.copyWith(occurrenceKey: 'event-5/2026-08-24/b'),
          ],
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
        throwsArgumentError,
      );
    },
  );

  test('weekly materialization is inclusive, bounded, and stably keyed', () {
    final event = DaybookEvent(
      eventId: 'event_team',
      title: 'Team sync',
      startDate: CivilDate(2026, 8, 3),
      endDate: CivilDate(2026, 8, 3),
      timeZoneId: 'America/New_York',
      allDay: false,
      startMinute: 9 * 60,
      endMinute: 10 * 60,
      weeklyRule: WeeklyEventRule(weekdays: const {DateTime.monday}),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    expect(
      WeeklyEventMaterializer.between(
        event,
        CivilDate(2026, 8, 1),
        CivilDate(2026, 8, 31),
      ).map((item) => item.occurrenceKey),
      [
        'event_team@2026-08-03',
        'event_team@2026-08-10',
        'event_team@2026-08-17',
        'event_team@2026-08-24',
        'event_team@2026-08-31',
      ],
    );
  });

  test('interval weeks stay anchored to the event start week', () {
    final event = DaybookEvent(
      eventId: 'event_biweekly',
      title: 'Biweekly studio',
      startDate: CivilDate(2026, 8, 5),
      endDate: CivilDate(2026, 8, 5),
      timeZoneId: 'America/New_York',
      allDay: false,
      startMinute: 13 * 60,
      endMinute: 14 * 60,
      weeklyRule: WeeklyEventRule(
        weekdays: const {DateTime.monday, DateTime.wednesday},
        intervalWeeks: 2,
      ),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    expect(
      WeeklyEventMaterializer.between(
        event,
        CivilDate(2026, 8, 1),
        CivilDate(2026, 8, 31),
      ).map((item) => item.occurrenceKey),
      [
        'event_biweekly@2026-08-05',
        'event_biweekly@2026-08-17',
        'event_biweekly@2026-08-19',
        'event_biweekly@2026-08-31',
      ],
    );
  });

  test('weekly materialization applies exceptions and carries duration', () {
    final event = DaybookEvent(
      eventId: 'event_overnight',
      title: 'Overnight rotation',
      startDate: CivilDate(2026, 8, 3),
      endDate: CivilDate(2026, 8, 4),
      timeZoneId: 'America/New_York',
      allDay: false,
      startMinute: 23 * 60,
      endMinute: 60,
      weeklyRule: WeeklyEventRule(weekdays: const {DateTime.monday}),
      exceptions: [
        DaybookEventException(
          occurrenceKey: 'event_overnight@2026-08-10',
          originalDate: CivilDate(2026, 8, 10),
          state: DaybookEventOccurrenceState.moved,
          movedStartDate: CivilDate(2026, 8, 12),
          movedEndDate: CivilDate(2026, 8, 13),
          movedStartMinute: 22 * 60,
          movedEndMinute: 30,
          updatedAt: updatedAt,
        ),
        DaybookEventException(
          occurrenceKey: 'event_overnight@2026-08-17',
          originalDate: CivilDate(2026, 8, 17),
          state: DaybookEventOccurrenceState.cancelled,
          updatedAt: updatedAt,
        ),
      ],
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final occurrences = WeeklyEventMaterializer.between(
      event,
      CivilDate(2026, 8, 3),
      CivilDate(2026, 8, 17),
    );

    expect(occurrences.first.endDate, CivilDate(2026, 8, 4));
    expect(occurrences[1].state, DaybookEventOccurrenceState.moved);
    expect(occurrences[1].startDate, CivilDate(2026, 8, 12));
    expect(occurrences[1].endDate, CivilDate(2026, 8, 13));
    expect(occurrences[2].state, DaybookEventOccurrenceState.cancelled);
    expect(occurrences[2].occurrenceKey, 'event_overnight@2026-08-17');
  });

  test('weekly all-day occurrences carry their date span forward', () {
    final event = DaybookEvent(
      eventId: 'event_retreat',
      title: 'Retreat',
      startDate: CivilDate(2026, 8, 3),
      endDate: CivilDate(2026, 8, 5),
      timeZoneId: 'America/New_York',
      allDay: true,
      weeklyRule: WeeklyEventRule(weekdays: const {DateTime.monday}),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final occurrence = WeeklyEventMaterializer.between(
      event,
      CivilDate(2026, 8, 10),
      CivilDate(2026, 8, 10),
    ).single;

    expect(occurrence.startDate, CivilDate(2026, 8, 10));
    expect(occurrence.endDate, CivilDate(2026, 8, 12));
    expect(occurrence.startMinute, isNull);
    expect(occurrence.endMinute, isNull);
  });

  test(
    'weekly event occurrence mutations preserve siblings and restore overrides',
    () {
      final event = DaybookEvent(
        eventId: 'event_actions',
        title: 'Studio hour',
        startDate: CivilDate(2026, 8, 11),
        endDate: CivilDate(2026, 8, 11),
        timeZoneId: 'America/New_York',
        allDay: false,
        startMinute: 9 * 60,
        endMinute: 10 * 60,
        weeklyRule: WeeklyEventRule(
          weekdays: const {DateTime.tuesday},
          endsOn: CivilDate(2026, 8, 25),
        ),
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
      final moved = AcademicSchedule.empty()
          .putEvent(event)
          .moveEventOccurrence(
            eventId: event.eventId,
            occurrenceKey: 'event_actions@2026-08-11',
            startDate: CivilDate(2026, 8, 12),
            endDate: CivilDate(2026, 8, 12),
            startMinute: 13 * 60,
            endMinute: 14 * 60,
            updatedAt: updatedAt,
          );

      expect(moved.events.single.exceptions, hasLength(1));
      expect(
        moved
            .eventOccurrencesBetween(
              CivilDate(2026, 8, 11),
              CivilDate(2026, 8, 25),
            )
            .map((item) => item.originalDate),
        containsAll([
          CivilDate(2026, 8, 11),
          CivilDate(2026, 8, 18),
          CivilDate(2026, 8, 25),
        ]),
      );

      final restoredMove = moved.restoreEventOccurrence(
        eventId: event.eventId,
        occurrenceKey: 'event_actions@2026-08-11',
        updatedAt: updatedAt.add(const Duration(minutes: 30)),
      );
      expect(restoredMove.events.single.exceptions, isEmpty);
      final baseOccurrences = restoredMove.eventOccurrencesBetween(
        CivilDate(2026, 8, 11),
        CivilDate(2026, 8, 25),
      );
      expect(baseOccurrences.first.startDate, CivilDate(2026, 8, 11));
      expect(baseOccurrences.first.startMinute, 9 * 60);
      expect(baseOccurrences.first.endMinute, 10 * 60);

      final cancelled = moved.cancelEventOccurrence(
        eventId: event.eventId,
        occurrenceKey: 'event_actions@2026-08-11',
        updatedAt: updatedAt.add(const Duration(hours: 1)),
      );
      expect(
        cancelled.events.single.exceptions.single.state,
        DaybookEventOccurrenceState.cancelled,
      );

      final restored = cancelled.restoreEventOccurrence(
        eventId: event.eventId,
        occurrenceKey: 'event_actions@2026-08-11',
        updatedAt: updatedAt.add(const Duration(hours: 2)),
      );
      expect(restored.events.single.exceptions, isEmpty);
      expect(
        restored
            .eventOccurrencesBetween(
              CivilDate(2026, 8, 11),
              CivilDate(2026, 8, 25),
            )
            .map((item) => item.originalDate),
        [
          CivilDate(2026, 8, 11),
          CivilDate(2026, 8, 18),
          CivilDate(2026, 8, 25),
        ],
      );
    },
  );
}
