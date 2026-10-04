// Reading a calendar and placing class meetings load the zone database the
// first time they need it. Loading it again resets tz.local to UTC, which
// would move the daily nudge and night routine to UTC wall-clock time after
// an import (Plans reschedules notifications on save). This file stays
// separate so each lazy load is the first one in its isolate.
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/calendar_class_finder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'support/calendar_export_samples.dart';

void main() {
  // What the notification scheduler does at launch.
  setUpAll(tz_data.initializeTimeZones);
  setUp(() => tz.setLocalLocation(tz.getLocation('America/New_York')));

  test('placing class meetings keeps the device zone', () {
    final (start, _) = OccurrenceMaterializer.resolveInstants(
      CivilDate(2026, 10, 6),
      10 * 60,
      11 * 60 + 20,
      'America/Chicago',
    );
    expect(start, DateTime.utc(2026, 10, 6, 15));
    expect(tz.local.name, 'America/New_York');
  });

  test('reading a calendar keeps the device zone', () {
    final draft = CalendarClassFinder.find(
      googleCalendarStudentExport(),
      fallbackTimeZoneId: 'America/New_York',
      today: CivilDate(2026, 10, 3),
    );
    expect(draft.timeZoneId, 'America/Chicago');
    expect(tz.local.name, 'America/New_York');
  });
}
