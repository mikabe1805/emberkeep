import 'dart:convert';

import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/home_widgets/widget_snapshot.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as time_zone_data;

void main() {
  setUpAll(time_zone_data.initializeTimeZones);

  test('builds a minimal versioned snapshot with the next class', () {
    final now = DateTime.utc(2026, 9, 1, 12);
    final snapshot = WidgetSnapshotBuilder.build(
      now: now,
      quests: const [],
      schedule: _schedule(),
    );

    expect(snapshot.nextClass?.courseCode, 'ECE 202');
    expect(snapshot.nextClass?.courseTitle, 'Signals and Systems');
    expect(snapshot.nextClass?.startLocal, contains('2026-09-02T10:00:00'));
    expect(
      snapshot.nextClass?.startEpochMillis,
      DateTime.utc(2026, 9, 2, 14).millisecondsSinceEpoch,
    );
    expect(snapshot.nextClass?.timeZoneId, 'America/New_York');
    expect(snapshot.upcomingClasses, hasLength(2));
    final json = jsonDecode(snapshot.encode()) as Map<String, dynamic>;
    expect(json['version'], roomOfDaysWidgetSnapshotVersion);
    expect(json['incompleteQuests'], isEmpty);
    expect(json['upcomingClasses'], hasLength(2));
    expect((json['upcomingClasses'] as List).first, isNot(contains('room')));
  });

  test('advances past an ended class without needing the full schedule', () {
    final snapshot = WidgetSnapshotBuilder.build(
      now: DateTime.utc(2026, 9, 2, 15, 16),
      quests: const [],
      schedule: _schedule(),
    );

    expect(snapshot.upcomingClasses, hasLength(1));
    expect(snapshot.nextClass?.courseCode, 'ECE 202');
    expect(
      snapshot.nextClass?.startEpochMillis,
      DateTime.utc(2026, 9, 3, 14).millisecondsSinceEpoch,
    );
  });

  test('selects at most three open quests in practical order', () {
    final now = DateTime(2026, 9, 1, 12);
    final quests = [
      Quest(title: 'All day', stat: Stat.dis, difficulty: 1, allDay: true),
      Quest(title: 'Dread', stat: Stat.dis, difficulty: 8, dread: true),
      Quest(title: 'Main', stat: Stat.str, difficulty: 5, priority: true),
      Quest(title: 'Light', stat: Stat.soc, difficulty: 1),
      Quest(
        title: 'Done',
        stat: Stat.intl,
        difficulty: 1,
        lastDoneDay: '2026-09-01',
      ),
    ];
    final snapshot = WidgetSnapshotBuilder.build(
      now: now,
      quests: quests,
      schedule: AcademicSchedule.empty(),
    );

    expect(snapshot.nextClass, isNull);
    expect(snapshot.incompleteQuests, hasLength(3));
    expect(snapshot.incompleteQuests.map((quest) => quest.title), [
      'Main',
      'Light',
      'Dread',
    ]);
    expect(
      snapshot.incompleteQuests.every((quest) => quest.id.length == 64),
      isTrue,
    );
    expect(
      snapshot.incompleteQuests.map((quest) => quest.toJson().keys),
      everyElement(containsAll(<String>['id', 'title'])),
    );
  });
}

AcademicSchedule _schedule() => AcademicSchedule.fromJson({
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
      'place': {'label': 'Room 101'},
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
      'endInstant': DateTime.utc(2026, 9, 2, 15, 15).millisecondsSinceEpoch,
      'localStartMinute': 600,
      'localEndMinute': 675,
      'kind': 'lecture',
      'place': {'label': 'Room 101'},
      'timeZoneId': 'America/New_York',
      'state': 'scheduled',
      'updatedAt': 0,
    },
    {
      'occurrenceKey': 'occurrence-2',
      'meetingSeriesId': 'series-1',
      'courseId': 'ece-202',
      'originalDate': '2026-09-03',
      'date': '2026-09-03',
      'startInstant': DateTime.utc(2026, 9, 3, 14).millisecondsSinceEpoch,
      'endInstant': DateTime.utc(2026, 9, 3, 15, 15).millisecondsSinceEpoch,
      'localStartMinute': 600,
      'localEndMinute': 675,
      'kind': 'lecture',
      'place': {'label': 'Room 101'},
      'timeZoneId': 'America/New_York',
      'state': 'scheduled',
      'updatedAt': 0,
    },
  ],
});
