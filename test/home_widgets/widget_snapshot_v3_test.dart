import 'dart:convert';

import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/class_day_links.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/home_widgets/widget_snapshot.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as time_zone_data;

import '../support/rutgers_fall_2026_ics_fixture.dart';
import 'day_ledger_mirror.dart';

/// His wall clock in New York, as an instant. Codemagic's Mac is not on New
/// York time, so every moment is built from UTC and read back in local.
DateTime ny(int month, int day, int hour, int minute) {
  // Fall 2026 before Nov 1 is EDT (UTC-4); after, EST (UTC-5).
  final offset = month < 11 ? 4 : 5;
  return DateTime.utc(2026, month, day, hour + offset, minute).toLocal();
}

AcademicSchedule mikaSchedule() => AcademicScheduleIcsImporter.parse(
  rutgersFall2026IcsFixture(),
).applyTo(AcademicSchedule.empty(), updatedAt: DateTime.utc(2026, 8, 27, 19));

List<Quest> mikaQuests() => [
  Quest(title: 'Review lecture notes', stat: Stat.intl, difficulty: 3),
  Quest(title: 'Walk outside', stat: Stat.str, difficulty: 2),
  Quest(title: 'Call home', stat: Stat.soc, difficulty: 2),
  Quest(title: 'Tidy the desk', stat: Stat.dis, difficulty: 1),
];

/// Keeps every class on the day [at] belongs to whose start is before [at],
/// the way a tap on the board would (engine keepClass).
ClassCredit? keep(GameState state, AcademicSchedule schedule, String code) {
  final day = projectClassDay(schedule, Clock.now());
  final entry = day.classes.firstWhere((entry) => entry.courseCode == code);
  return state.keepClass(entry.facts, dayClassKeys: day.dayClassKeys);
}

Map<String, dynamic> decode(WidgetSnapshot snapshot) =>
    (jsonDecode(snapshot.encode()) as Map).cast<String, dynamic>();

/// What the widget reads at [at] from the snapshot the app published at
/// [publishedAt]. [marks] is whether the board keeps from links.
DayLedgerEntry entryAt(
  AcademicSchedule schedule,
  GameState state, {
  required DateTime publishedAt,
  DateTime? at,
  bool marks = true,
}) {
  final snapshot = WidgetSnapshotBuilder.build(
    quests: mikaQuests(),
    schedule: schedule,
    now: publishedAt,
    state: state,
    classDayMarks: marks,
  );
  return DayLedgerEntry(
    at ?? publishedAt,
    LedgerSnapshot.load(snapshot.encode()),
  );
}

void main() {
  setUpAll(time_zone_data.initializeTimeZones);
  tearDown(Clock.reset);

  group('snapshot v3 on his Tuesday', () {
    late AcademicSchedule schedule;
    late GameState state;

    setUp(() {
      schedule = mikaSchedule();
      state = GameState();
    });

    test('11:52, between classes: the ended class waits, the next is up', () {
      final now = ny(10, 6, 11, 52);
      Clock.freeze(now);
      final snapshot = WidgetSnapshotBuilder.build(
        quests: mikaQuests(),
        schedule: schedule,
        now: now,
        state: state,
        classDayMarks: true,
      );
      final json = decode(snapshot);

      expect(json['version'], 3);
      expect(roomOfDaysWidgetSnapshotVersion, 3);
      // Every version 2 key keeps its name and shape.
      expect(
        json.keys,
        containsAll(<String>[
          'version',
          'generatedAt',
          'upcomingClasses',
          'incompleteQuests',
        ]),
      );
      final firstUpcoming = (json['upcomingClasses'] as List).first as Map;
      expect(
        firstUpcoming.keys,
        containsAll(<String>[
          'courseCode',
          'courseTitle',
          'startLocal',
          'endLocal',
          'startEpochMillis',
          'endEpochMillis',
          'timeZoneId',
        ]),
      );
      expect(
        firstUpcoming['courseTitle'],
        'Introduction to Discrete Structures II',
      );
      expect(firstUpcoming['shortTitle'], 'Discrete Structures II');
      expect(firstUpcoming['dayKey'], '2026-10-06');
      expect(firstUpcoming['dayLabel'], 'TUE');

      final days = json['classDays'] as List;
      expect(days, isNotEmpty);
      final tuesday = (days.first as Map).cast<String, dynamic>();
      expect(tuesday['dayKey'], '2026-10-06');
      expect(tuesday['weekday'], 'Tuesday');
      expect(
        tuesday['startsEpochMillis'],
        DateTime.utc(2026, 10, 6, 8).millisecondsSinceEpoch,
      );
      expect(
        tuesday['nightEndsEpochMillis'],
        DateTime.utc(2026, 10, 7, 8).millisecondsSinceEpoch,
      );
      expect(
        tuesday['lastClassEndEpochMillis'],
        DateTime.utc(2026, 10, 6, 19, 20).millisecondsSinceEpoch,
      );
      // 5:00 PM: later than an hour after his 3:20 PM class.
      expect(
        tuesday['eveningStartsEpochMillis'],
        DateTime.utc(2026, 10, 6, 21).millisecondsSinceEpoch,
      );
      expect(tuesday['allKept'], isFalse);
      expect(tuesday.containsKey('attendedShort'), isFalse);
      expect(tuesday.containsKey('recordLine'), isFalse);
      expect(tuesday['classXp'], 0);
      expect(
        tuesday['markAllUrl'],
        'roomofdays://class-day/mark-all?day=2026-10-06',
      );

      final classes = [
        for (final entry in tuesday['classes'] as List)
          (entry as Map).cast<String, dynamic>(),
      ];
      expect(classes.map((entry) => entry['shortTitle']), [
        'Computer Architecture',
        'Discrete Structures II',
      ]);
      expect(classes.map((entry) => entry['state']), ['waiting', 'upcoming']);
      expect(classes.map((entry) => entry['place']), ['HLL 114', 'PHY 001']);
      expect(classes.first['startLabel'], '10:20 AM');
      expect(classes.first['endLabel'], '11:40 AM');
      expect(classes.first['kept'], isFalse);
      final key = classes.first['occurrenceKey'] as String;
      expect(key, isNotEmpty);
      expect(
        classes.first['markUrl'],
        'roomofdays://class-day/mark?occurrence=${Uri.encodeQueryComponent(key)}'
        '&day=2026-10-06',
      );
      expect(
        ClassDayLink.fromUri(Uri.parse(classes.first['markUrl'] as String)),
        ClassDayLink.mark(occurrenceKey: key, dayKey: '2026-10-06'),
      );

      // The timeline turns at the next class start, its end, the evening,
      // local midnight and the night's end.
      final boundaries = [
        for (final value in json['boundaries'] as List)
          DateTime.fromMillisecondsSinceEpoch(value as int, isUtc: true),
      ];
      expect(boundaries.first, DateTime.utc(2026, 10, 6, 18));
      expect(
        boundaries,
        containsAll([
          DateTime.utc(2026, 10, 6, 19, 20),
          DateTime.utc(2026, 10, 6, 21),
          DateTime.utc(2026, 10, 7, 8),
          DateTime(2026, 10, 7).toUtc(),
        ]),
      );
      expect(boundaries, orderedEquals([...boundaries]..sort()));
      expect(json['questsDayEndsEpochMillis'], isA<int>());
      expect(
        json['questsDayEndsEpochMillis'],
        DateTime(
          now.year,
          now.month,
          now.day + 1,
        ).toUtc().millisecondsSinceEpoch,
      );

      final entry = DayLedgerEntry(now, LedgerSnapshot.load(snapshot.encode()));
      expect(entry.mode, LedgerMode.classes);
      expect(entry.classesDone, isFalse);
      expect(entry.focusClass?.shortTitle, 'Computer Architecture');
      expect(entry.isInSession(entry.focusClass!), isFalse);
      expect(entry.nextAfter?.title, 'Discrete Structures II');
      expect(entry.nextAfter?.time, '2:00 PM');
      expect(entry.markAllUrl, isNull);
      expect(entry.smallUrl, classes.first['markUrl']);
      expect(entry.mediumUrl, classDayOpenUrl);
      // The medium widget has one control, and it marks the class that
      // ended, never the one that has not started.
      expect(entry.mediumLinks, [classDayOpenUrl, classes.first['markUrl']]);
    });

    test('15:35, after the last class: Classes done with the waiting one', () {
      Clock.freeze(ny(10, 6, 11, 52));
      final first = keep(state, schedule, '14:332:331');
      expect(first?.xp, 25);

      final now = ny(10, 6, 15, 35);
      Clock.freeze(now);
      final snapshot = WidgetSnapshotBuilder.build(
        quests: mikaQuests(),
        schedule: schedule,
        now: now,
        state: state,
        classDayMarks: true,
      );
      final tuesday = snapshot.classDays.first;
      expect(tuesday.dayKey, '2026-10-06');
      expect(tuesday.classes.map((entry) => entry.state), [
        WidgetClassState.kept,
        WidgetClassState.waiting,
      ]);
      expect(tuesday.classes.first.keptXp, 25);
      expect(tuesday.classXp, 25);
      expect(tuesday.allKept, isFalse);
      expect(tuesday.recordLine, 'Tuesday’s classes, one attended');
      // Version 2 readers still see the next class, now tomorrow's lab.
      expect(snapshot.nextClass?.courseTitle, 'Computer Architecture Lab');
      expect(snapshot.nextClass?.dayLabel, 'WED');
      expect(snapshot.nextClass?.dayKey, '2026-10-07');

      final entry = DayLedgerEntry(now, LedgerSnapshot.load(snapshot.encode()));
      expect(entry.mode, LedgerMode.classes);
      expect(entry.classesDone, isTrue);
      expect(entry.doneRows.map((row) => row.shortTitle), [
        'Computer Architecture',
        'Discrete Structures II',
      ]);
      expect(entry.focusClass?.shortTitle, 'Discrete Structures II');
      // One waiting: its own I WAS THERE, no mark-all.
      expect(entry.waitingClasses, hasLength(1));
      expect(entry.markAllUrl, isNull);
      expect(entry.smallUrl, entry.focusClass!.markUrl);
      expect(entry.showsNextAfterRows, isTrue);
      expect(entry.nextAfter?.title, 'Computer Architecture Lab');
      expect(entry.nextAfter?.time, 'WED 8:30 AM');

      // Keeping the second one completes the day: the quiet line.
      final second = keep(state, schedule, '01:198:206');
      expect(second?.fullDayBonus, ClassPay.fullDayBonusXp);
      final kept = WidgetSnapshotBuilder.build(
        quests: mikaQuests(),
        schedule: schedule,
        now: now,
        state: state,
        classDayMarks: true,
      );
      final day = kept.classDays.first;
      expect(day.allKept, isTrue);
      expect(day.classXp, 60);
      expect(day.attendedShort, 'Both attended');
      expect(day.recordLine, 'Tuesday’s classes, both attended');
      final after = DayLedgerEntry(now, LedgerSnapshot.load(kept.encode()));
      expect(after.mode, LedgerMode.allKept);
      expect(after.focusClass, isNull);
      expect(after.smallUrl, classDayOpenUrl);
      expect(after.mediumLinks, [classDayOpenUrl]);
    });

    test('two ended and unmarked: one I WENT TO BOTH for both', () {
      final entry = entryAt(
        schedule,
        state,
        publishedAt: ny(10, 6, 11, 52),
        at: ny(10, 6, 15, 35),
      );
      expect(entry.classesDone, isTrue);
      expect(entry.waitingClasses, hasLength(2));
      expect(
        entry.markAllUrl,
        'roomofdays://class-day/mark-all?day=2026-10-06',
      );
      expect(entry.markAllLabel, 'I WENT TO BOTH');
      expect(entry.smallUrl, entry.markAllUrl);
      expect(entry.mediumLinks, [classDayOpenUrl, entry.markAllUrl]);
    });

    test('20:30, the evening: the everyday look and one quiet line', () {
      final now = ny(10, 6, 20, 30);
      Clock.freeze(now);
      final snapshot = WidgetSnapshotBuilder.build(
        quests: mikaQuests(),
        schedule: schedule,
        now: now,
        state: state,
        classDayMarks: true,
      );
      final json = decode(snapshot);
      final tuesday = ((json['classDays'] as List).first as Map)
          .cast<String, dynamic>();
      // Still Tuesday's night until 4:00 AM, both classes still markable.
      expect(tuesday['dayKey'], '2026-10-06');
      expect(
        [for (final entry in tuesday['classes'] as List) entry['state']],
        ['waiting', 'waiting'],
      );
      expect(json['incompleteQuests'], hasLength(3));
      expect(json['nextDayQuests'], hasLength(3));

      final entry = DayLedgerEntry(now, LedgerSnapshot.load(snapshot.encode()));
      expect(entry.mode, LedgerMode.today);
      expect(entry.nextClass?.courseTitle, 'Computer Architecture Lab');
      expect(entry.classTime(entry.nextClass!), 'WED 8:30 AM');
      expect(entry.quests, hasLength(3));
      // Both still markable from the home screen: a quiet mark-all line,
      // and a tap anywhere else lands on the class day.
      expect(entry.eveningLine, LedgerEveningLine.markAll);
      expect(entry.eveningMarkAllLabel, 'I WENT TO BOTH');
      expect(entry.smallUrl, classDayOpenUrl);
      expect(entry.mediumUrl, classDayOpenUrl);
      expect(entry.mediumLinks.last, tuesday['markAllUrl']);

      // 3:59 AM is still Tuesday's night; at 4:00 the line is gone.
      final lastMinute = DayLedgerEntry(
        ny(10, 7, 3, 59),
        LedgerSnapshot.load(snapshot.encode()),
      );
      expect(lastMinute.eveningLine, LedgerEveningLine.markAll);
      final over = DayLedgerEntry(
        ny(10, 7, 4, 1),
        LedgerSnapshot.load(snapshot.encode()),
      );
      expect(over.eveningLine, isNull);
      expect(over.smallUrl, isNull);
      expect(over.mediumLinks, isEmpty);

      // The midnight entry (the device's own midnight, where the app's
      // quest day turns): tomorrow's list replaces today's.
      final loaded = LedgerSnapshot.load(snapshot.encode());
      final midnightAt = DateTime.fromMillisecondsSinceEpoch(
        loaded.questsDayEndsEpochMillis!,
        isUtc: true,
      );
      expect(midnightAt, DateTime(now.year, now.month, now.day + 1).toUtc());
      expect(
        ledgerTimeline(loaded, now),
        contains(midnightAt.add(const Duration(seconds: 1))),
      );
      final midnight = DayLedgerEntry(
        midnightAt.add(const Duration(minutes: 5)),
        loaded,
      );
      expect(identical(midnight.quests, loaded.nextDayQuests), isTrue);
      expect(
        DayLedgerEntry(
          midnightAt.subtract(const Duration(minutes: 5)),
          loaded,
        ).quests,
        same(loaded.incompleteQuests),
      );
      // Two midnights later neither list is current: no quests at all.
      final stale = DayLedgerEntry(
        DateTime.fromMillisecondsSinceEpoch(
          loaded.nextDayEndsEpochMillis! + 5 * 60 * 1000,
          isUtc: true,
        ),
        loaded,
      );
      expect(stale.quests, isNull);
      // After his midnight the lab is today's, so it loses its day word.
      final wednesdayNight = DayLedgerEntry(ny(10, 7, 0, 5), loaded);
      expect(wednesdayNight.classTime(wednesdayNight.nextClass!), '8:30 AM');
      // And Wednesday's own class day comes from the same snapshot.
      final wednesday = DayLedgerEntry(
        ny(10, 7, 11, 40),
        LedgerSnapshot.load(snapshot.encode()),
      );
      expect(wednesday.mode, LedgerMode.classes);
      expect(wednesday.classDay?.dayKey, '2026-10-07');
      expect(wednesday.focusClass?.shortTitle, 'Computer Architecture Lab');
      expect(wednesday.nextAfter?.time, '2:00 PM');
    });

    test('20:30 with one kept: the other is offered on the quiet line', () {
      Clock.freeze(ny(10, 6, 11, 52));
      keep(state, schedule, '14:332:331');
      final entry = entryAt(
        schedule,
        state,
        publishedAt: ny(10, 6, 11, 53),
        at: ny(10, 6, 20, 30),
      );
      expect(entry.mode, LedgerMode.today);
      expect(entry.eveningLine, LedgerEveningLine.waiting);
      expect(entry.eveningWaiting.single.shortTitle, 'Discrete Structures II');
      expect(entry.mediumLinks, [
        classDayOpenUrl,
        entry.eveningWaiting.single.markUrl,
      ]);
      // The small widget's evening look has no control: its tap only opens.
      expect(entry.smallUrl, classDayOpenUrl);
    });

    test("20:30 with both kept: the day's record as one quiet line", () {
      Clock.freeze(ny(10, 6, 11, 52));
      keep(state, schedule, '14:332:331');
      Clock.freeze(ny(10, 6, 15, 36));
      keep(state, schedule, '01:198:206');
      final entry = entryAt(
        schedule,
        state,
        publishedAt: ny(10, 6, 15, 36),
        at: ny(10, 6, 20, 30),
      );
      expect(entry.eveningLine, LedgerEveningLine.record);
      expect(entry.eveningDay?.recordLine, 'Tuesday’s classes, both attended');
      expect(entry.eveningDay?.classXp, 60);
      expect(entry.mediumLinks, [classDayOpenUrl], reason: 'no control');
    });
  });

  test('his Monday: Classes done for an hour after 7:00 PM, one control', () {
    final schedule = mikaSchedule();
    final now = ny(10, 5, 19, 5);
    Clock.freeze(now);
    final snapshot = WidgetSnapshotBuilder.build(
      quests: mikaQuests(),
      schedule: schedule,
      now: now,
      state: GameState(),
      classDayMarks: true,
    );
    final monday = snapshot.classDays.first;
    expect(monday.classes, hasLength(3));
    expect(monday.eveningStartsAt, DateTime.utc(2026, 10, 6));
    final entry = DayLedgerEntry(now, LedgerSnapshot.load(snapshot.encode()));
    expect(entry.mode, LedgerMode.classes);
    expect(entry.classesDone, isTrue);
    expect(entry.doneRows, hasLength(3));
    expect(entry.focusClass?.startLabel, '5:40 PM');
    // Three waiting: one I WENT TO ALL, never a count of them.
    expect(entry.markAllUrl, monday.markAllUrl);
    expect(entry.markAllLabel, 'I WENT TO ALL');
    expect(entry.smallUrl, monday.markAllUrl);
    expect(entry.mediumLinks, [classDayOpenUrl, monday.markAllUrl]);
    expect(entry.showsNextAfterRows, isFalse);
    final later = DayLedgerEntry(
      ny(10, 5, 20, 1),
      LedgerSnapshot.load(snapshot.encode()),
    );
    expect(later.mode, LedgerMode.today);
    expect(later.eveningLine, LedgerEveningLine.markAll);
    expect(later.eveningMarkAllLabel, 'I WENT TO ALL');
  });

  test('a lecture in session offers I AM HERE through its own mark link', () {
    final schedule = mikaSchedule();
    final now = ny(10, 6, 10, 45);
    Clock.freeze(now);
    final snapshot = WidgetSnapshotBuilder.build(
      quests: const [],
      schedule: schedule,
      now: now,
      state: GameState(),
      classDayMarks: true,
    );
    expect(
      snapshot.classDays.first.classes.first.state,
      WidgetClassState.inSession,
    );
    final entry = DayLedgerEntry(now, LedgerSnapshot.load(snapshot.encode()));
    expect(entry.mode, LedgerMode.classes);
    expect(entry.isInSession(entry.focusClass!), isTrue);
    expect(entry.smallUrl, entry.focusClass!.markUrl);
    // Before the first class the widget keeps its everyday look.
    final early = DayLedgerEntry(
      ny(10, 6, 8, 5),
      LedgerSnapshot.load(snapshot.encode()),
    );
    expect(early.mode, LedgerMode.today);
    expect(early.eveningLine, isNull);
    expect(early.smallUrl, isNull);
  });

  test('until the board keeps from links, no tap can mark', () {
    final schedule = mikaSchedule();
    for (final at in [
      ny(10, 6, 10, 45),
      ny(10, 6, 11, 52),
      ny(10, 5, 19, 5),
      ny(10, 6, 20, 30),
    ]) {
      Clock.freeze(at);
      final snapshot = WidgetSnapshotBuilder.build(
        quests: mikaQuests(),
        schedule: schedule,
        now: at,
        state: GameState(),
      );
      expect(snapshot.encode(), isNot(contains('/mark')), reason: '$at');
      final entry = DayLedgerEntry(at, LedgerSnapshot.load(snapshot.encode()));
      expect(entry.smallUrl, classDayOpenUrl, reason: '$at');
      expect(entry.mediumLinks, [classDayOpenUrl], reason: '$at');
      expect(entry.markAllUrl, isNull);
    }
    // The class itself still shows, quietly, with its ring.
    Clock.freeze(ny(10, 6, 11, 52));
    final entry = entryAt(
      schedule,
      GameState(),
      publishedAt: ny(10, 6, 11, 52),
      marks: false,
    );
    expect(entry.mode, LedgerMode.classes);
    expect(entry.focusClass?.shortTitle, 'Computer Architecture');
    expect(entry.focusClass?.markUrl, isNull);
  });

  test('a started office hour stays offered after the counted classes', () {
    // Lecture kept, office hours (not counted toward the day) started and
    // not kept: the day is complete for the engine, but the widget still
    // offers the office hour, and never says "Both attended" for three.
    final start = ny(10, 6, 9, 0).toUtc().millisecondsSinceEpoch;
    const hour = 60 * 60 * 1000;
    Map<String, dynamic> dayClass(String key, int offset, bool kept) => {
      'occurrenceKey': key,
      'title': key,
      'shortTitle': key,
      'place': '',
      'startLabel': '',
      'endLabel': '',
      'startEpochMillis': start + offset * hour,
      'endEpochMillis': start + offset * hour + hour,
      'kept': kept,
      'keptXp': kept ? 25 : 0,
      'markUrl': classDayMarkUrl(key, '2026-10-06'),
    };
    final json = jsonEncode({
      'version': 3,
      'generatedAt': '',
      'upcomingClasses': <Object>[],
      'incompleteQuests': <Object>[],
      'classDays': [
        {
          'dayKey': '2026-10-06',
          'weekday': 'Tuesday',
          'startsEpochMillis': start - 5 * hour,
          'eveningStartsEpochMillis': start + 8 * hour,
          'nightEndsEpochMillis': start + 19 * hour,
          'lastClassEndEpochMillis': start + 3 * hour,
          'classXp': 35,
          'allKept': true,
          'attendedShort': 'Attended',
          'markAllUrl': classDayMarkAllUrl('2026-10-06'),
          'classes': [
            dayClass('Lecture', 0, true),
            dayClass('Office hours', 2, false),
          ],
        },
      ],
    });
    final before = DayLedgerEntry(
      DateTime.fromMillisecondsSinceEpoch(start + 90 * 60 * 1000, isUtc: true),
      LedgerSnapshot.load(json),
    );
    expect(before.mode, LedgerMode.allKept);
    final during = DayLedgerEntry(
      DateTime.fromMillisecondsSinceEpoch(start + 150 * 60 * 1000, isUtc: true),
      LedgerSnapshot.load(json),
    );
    expect(during.mode, LedgerMode.classes);
    expect(during.focusClass?.shortTitle, 'Office hours');
    expect(during.smallUrl, during.focusClass?.markUrl);
  });

  test('a Saturday without classes keeps the everyday look', () {
    final schedule = mikaSchedule();
    final now = ny(10, 10, 11, 0);
    Clock.freeze(now);
    final snapshot = WidgetSnapshotBuilder.build(
      quests: mikaQuests(),
      schedule: schedule,
      now: now,
      state: GameState(),
      classDayMarks: true,
    );
    expect(snapshot.classDays.first.dayKey, '2026-10-12');
    final entry = DayLedgerEntry(now, LedgerSnapshot.load(snapshot.encode()));
    expect(entry.mode, LedgerMode.today);
    expect(entry.eveningLine, isNull);
    expect(entry.smallUrl, isNull);
    expect(entry.classTime(entry.nextClass!), 'MON 8:30 AM');
    expect(entry.quests, hasLength(3));
  });

  test('a snapshot without a timetable has no class days', () {
    final now = ny(10, 6, 11, 52);
    Clock.freeze(now);
    final snapshot = WidgetSnapshotBuilder.build(
      quests: mikaQuests(),
      schedule: AcademicSchedule.empty(),
      now: now,
      classDayMarks: true,
    );
    expect(snapshot.classDays, isEmpty);
    expect(snapshot.upcomingClasses, isEmpty);
    expect(snapshot.incompleteQuests, hasLength(3));
  });

  test('the attended and record lines only ever say true, whole things', () {
    expect(WidgetSnapshotBuilder.attendedShort(1), 'Attended');
    expect(WidgetSnapshotBuilder.attendedShort(2), 'Both attended');
    expect(WidgetSnapshotBuilder.attendedShort(3), 'All three attended');
    expect(WidgetSnapshotBuilder.attendedShort(5), 'All attended');
    expect(
      WidgetSnapshotBuilder.recordLine(
        'Wednesday',
        classCount: 1,
        kept: 1,
        allKept: true,
      ),
      'Wednesday’s class, attended',
    );
    expect(
      WidgetSnapshotBuilder.recordLine(
        'Monday',
        classCount: 3,
        kept: 2,
        allKept: false,
      ),
      'Monday’s classes, two attended',
    );
    final lines = [
      for (var kept = 1; kept <= 5; kept++) ...[
        WidgetSnapshotBuilder.attendedShort(kept),
        for (final allKept in [true, false])
          WidgetSnapshotBuilder.recordLine(
            'Tuesday',
            classCount: 5,
            kept: kept,
            allKept: allKept,
          ),
      ],
    ];
    for (final line in lines) {
      expect(line, isNot(contains('—')));
      expect(line, isNot(matches(RegExp(r'\d+ of \d+'))));
      expect(line, isNot(matches(RegExp(r'\bof (two|three|four|five)\b'))));
      expect(
        line.toLowerCase(),
        isNot(matches(RegExp(r'missed|failed|lost|broke|skipped'))),
      );
    }
  });

  group('version 2 readers', () {
    test('a version 2 snapshot reads as before', () {
      const v2 =
          '{"version":2,"generatedAt":"2026-09-01T12:00:00.000Z",'
          '"upcomingClasses":[{"courseCode":"ECE 202","courseTitle":'
          '"Signals and Systems","startLocal":"2026-09-02T10:00:00.000-0400",'
          '"endLocal":"2026-09-02T11:15:00.000-0400","startEpochMillis":'
          '1788357600000,"endEpochMillis":1788362100000,"timeZoneId":'
          '"America/New_York"}],"incompleteQuests":[{"id":"a","title":"One"}]}';
      final snapshot = LedgerSnapshot.load(v2);
      expect(snapshot.version, 2);
      final entry = DayLedgerEntry(DateTime.utc(2026, 9, 2, 12), snapshot);
      expect(entry.mode, LedgerMode.today);
      expect(entry.classTime(entry.nextClass!), '10:00 AM');
      expect(entry.quests?.single.title, 'One');
      expect(entry.eveningLine, isNull);
      expect(
        ledgerTimeline(snapshot, DateTime.utc(2026, 9, 2, 12)).last,
        DateTime.utc(2026, 9, 2, 15, 15, 1),
      );
    });

    test('an unknown future version reads as empty', () {
      final snapshot = LedgerSnapshot.load(
        '{"version":4,"generatedAt":"","upcomingClasses":[],'
        '"incompleteQuests":[{"id":"a","title":"One"}]}',
      );
      expect(snapshot.incompleteQuests, isEmpty);
    });

    test('the shipped version 2 widget shows its empty look for version 3 '
        '(the downgrade gap the doc comment names)', () {
      final now = ny(10, 6, 11, 52);
      Clock.freeze(now);
      final json = decode(
        WidgetSnapshotBuilder.build(
          quests: mikaQuests(),
          schedule: mikaSchedule(),
          now: now,
        ),
      );
      // Build 49's loadSnapshot() accepts `decoded.version == 2` only.
      expect(json['version'] == 2, isFalse);
      // Its keys are all still there for when a version 2 app republishes.
      expect(json['incompleteQuests'], hasLength(3));
      expect(json['upcomingClasses'], isNotEmpty);
    });
  });
}
