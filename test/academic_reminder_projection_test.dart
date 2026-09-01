import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/services/academic_reminder_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'projects enabled class reminders at absolute instants without place',
    () {
      final schedule = AcademicSchedule.fromJson({
        'schema': 1,
        'terms': [
          {
            'termId': 'fall-2026',
            'name': 'Fall 2026',
            'startDate': '2026-09-01',
            'endDate': '2026-12-20',
            'timeZoneId': 'America/New_York',
          },
        ],
        'courses': [
          {
            'courseId': 'ece-202',
            'termId': 'fall-2026',
            'code': 'ECE 202',
            'title': 'Signals and Systems',
            'colorValue': 0xffc78d45,
            'colorLabel': 'gold',
          },
        ],
        'meetingSeries': [
          {
            'meetingSeriesId': 'series-1',
            'courseId': 'ece-202',
            'kind': 'lecture',
            'weekdays': [2],
            'localStartMinute': 600,
            'localEndMinute': 675,
            'firstDate': '2026-09-01',
            'lastDate': '2026-12-20',
            'timeZoneId': 'America/New_York',
            'place': {'label': 'Private Room 101'},
            'reminders': [
              {
                'reminderId': 'reminder-1',
                'enabled': true,
                'offsetMinutes': 15,
              },
            ],
            'updatedAt': 0,
          },
        ],
        'occurrences': [
          {
            'occurrenceKey': 'occurrence-1',
            'meetingSeriesId': 'series-1',
            'courseId': 'ece-202',
            'originalDate': '2026-09-02',
            'date': '2026-09-02',
            'startInstant': DateTime.utc(2026, 9, 2, 14).millisecondsSinceEpoch,
            'endInstant': DateTime.utc(
              2026,
              9,
              2,
              15,
              15,
            ).millisecondsSinceEpoch,
            'localStartMinute': 600,
            'localEndMinute': 675,
            'kind': 'lecture',
            'place': {'label': 'Private Room 101'},
            'timeZoneId': 'America/New_York',
            'state': 'scheduled',
            'updatedAt': 0,
          },
          {
            'occurrenceKey': 'occurrence-cancelled',
            'meetingSeriesId': 'series-1',
            'courseId': 'ece-202',
            'originalDate': '2026-09-09',
            'date': '2026-09-09',
            'startInstant': DateTime.utc(2026, 9, 9, 14).millisecondsSinceEpoch,
            'endInstant': DateTime.utc(
              2026,
              9,
              9,
              15,
              15,
            ).millisecondsSinceEpoch,
            'localStartMinute': 600,
            'localEndMinute': 675,
            'kind': 'lecture',
            'place': {'label': 'Private Room 101'},
            'timeZoneId': 'America/New_York',
            'state': 'cancelled',
            'updatedAt': 0,
          },
        ],
      });

      final notices = projectAcademicReminderNotices(
        schedule: schedule,
        now: DateTime.utc(2026, 9, 2, 13),
      );

      expect(notices, hasLength(1));
      expect(notices.single.whenUtc, DateTime.utc(2026, 9, 2, 13, 45));
      expect(notices.single.title, 'Class in 15 minutes · ECE 202');
      expect(notices.single.body, 'Signals and Systems');
      expect(
        '${notices.single.title} ${notices.single.body}',
        isNot(contains('Room 101')),
      );
    },
  );
}
