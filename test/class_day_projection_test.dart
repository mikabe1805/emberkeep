import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart' show Days;
import 'package:flutter_test/flutter_test.dart';

import 'support/rutgers_fall_2026_ics_fixture.dart';

/// Mika's real Fall 2026 timetable. Every moment is an instant built with
/// DateTime.utc (EDT = UTC-4 until Nov 1, EST = UTC-5 after), so these pass
/// on a host in any zone: the projection reads the day in the schedule's own
/// zone, never the test machine's wall clock.

AcademicSchedule _fall2026() => AcademicScheduleIcsImporter.parse(
  rutgersFall2026IcsFixture(),
).applyTo(AcademicSchedule.empty(), updatedAt: DateTime.utc(2026, 8, 27));

DateTime _edt(int month, int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, month, day, hour + 4, minute);

DateTime _est(int month, int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, month, day, hour + 5, minute);

final _tuesdayMidday = _edt(10, 6, 11, 52);
final _tuesdayAfterClasses = _edt(10, 6, 15, 35);

List<String> _codes(ClassDay day) => [
  for (final entry in day.classes) entry.courseCode,
];

void main() {
  late AcademicSchedule schedule;

  setUpAll(() => schedule = _fall2026());
  tearDown(() {
    Clock.reset();
    GameState.restDayResolver = null;
  });

  test('his Monday: three classes, the last ending at 7:00 PM', () {
    final day = projectClassDay(schedule, _edt(10, 5, 19, 15));

    expect(day.date, CivilDate(2026, 10, 5));
    expect(day.dayKey, '2026-10-05');
    expect(day.isClassDay, isTrue);
    expect(_codes(day), ['14:332:361', '14:332:345', '14:332:345']);
    expect(day.classes.map((entry) => entry.localStartMinute), [
      510,
      840,
      1060,
    ]);
    expect(day.classes.first.title, 'Electronics Devices');
    expect(day.classes.first.kind, MeetingKind.lecture);
    expect(day.classes.first.startsAt, DateTime.utc(2026, 10, 5, 12, 30));
    expect(day.classes.first.endsAt, DateTime.utc(2026, 10, 5, 13, 50));
    expect(day.classes.first.placeLabel, isNotEmpty);
    expect(
      day.classes.every((entry) => entry.moment == ClassMoment.ended),
      isTrue,
    );
    expect(day.lastClassEnd, DateTime.utc(2026, 10, 5, 23));
    expect(day.afterLastClass(_edt(10, 5, 19, 15)), isTrue);
    expect(day.afterLastClass(_edt(10, 5, 18, 59)), isFalse);
    expect(day.runsWeekdayOf, isNull);
    expect(day.nextClassAfter!.entry.courseCode, '14:332:331');
    expect(day.nextClassAfter!.daysAhead, 1);
    expect(day.nextClassAfter!.dayWord, 'tomorrow');
    expect(day.nextClassAfter!.date, CivilDate(2026, 10, 6));
  });

  test('moments run upcoming, starts soon, in session, ended by instants', () {
    final evening = projectClassDay(schedule, _edt(10, 5, 17, 30));
    expect(evening.classes.map((entry) => entry.moment), [
      ClassMoment.ended,
      ClassMoment.ended,
      ClassMoment.startsSoon,
    ]);
    final third = evening.classes.last;
    expect(third.momentAt(_edt(10, 5, 17, 24)), ClassMoment.upcoming);
    expect(third.momentAt(_edt(10, 5, 17, 25)), ClassMoment.startsSoon);
    expect(third.momentAt(_edt(10, 5, 17, 40)), ClassMoment.inSession);
    expect(third.momentAt(_edt(10, 5, 18, 59)), ClassMoment.inSession);
    expect(third.momentAt(_edt(10, 5, 19)), ClassMoment.ended);

    final morning = projectClassDay(schedule, _edt(10, 5, 8));
    expect(morning.classes.first.moment, ClassMoment.upcoming);
    expect(morning.afterLastClass(_edt(10, 5, 8)), isFalse);
  });

  test('his Tuesday between classes', () {
    final day = projectClassDay(schedule, _tuesdayMidday);

    expect(_codes(day), ['14:332:331', '01:198:206']);
    expect(day.classes.map((entry) => entry.moment), [
      ClassMoment.ended,
      ClassMoment.upcoming,
    ]);
    expect(day.lastClassEnd, DateTime.utc(2026, 10, 6, 19, 20));
    expect(day.nextClassAfter!.entry.courseCode, '14:332:333');
    expect(day.nextClassAfter!.entry.kind, MeetingKind.lab);
    expect(day.nextClassAfter!.dayWord, 'tomorrow');
    expect(day.dayClassKeys, hasLength(2));
  });

  // The facts carry the class's own day, its instants and the end of its
  // night in the timetable's zone, so the engine judges the window exactly
  // as the projection does, on a host in any zone.
  test('his Tuesday through the engine, with the full-day bonus', () {
    final now = _tuesdayMidday;
    final day = projectClassDay(schedule, now);

    Clock.freeze(now.toLocal());
    final state = GameState();
    final architecture = day.classes.first.facts;
    expect(architecture.dayKey, '2026-10-06');
    expect(architecture.kind, 'lecture');
    expect(architecture.startMinute, 620);
    expect(architecture.identity, day.classes.first.occurrenceKey);
    expect(architecture.nightEndsAt, DateTime.utc(2026, 10, 7, 8));
    final first = state.keepClass(
      architecture,
      dayClassKeys: day.dayClassKeys,
    )!;
    expect(first.dayComplete, isFalse);
    expect(
      state.checkClassKeep(day.classes.last.facts),
      ClassKeepCheck.notStartedYet,
      reason: 'Discrete starts at 2:00 PM',
    );

    Clock.freeze(_tuesdayAfterClasses.toLocal());
    final last = state.keepClass(
      day.classes.last.facts,
      dayClassKeys: day.dayClassKeys,
    )!;
    expect(last.dayComplete, isTrue);
    expect(last.fullDayBonus, 10);
    expect(state.totalXp, 60);
  });

  test('a phone in another zone keeps what the board shows', () {
    // 2:30 AM Tuesday in New York: still Monday's night on the board. A
    // phone on UTC (6:30 AM Tuesday, its own night already Tuesday) keeps
    // Monday's evening class; at 4:00 AM New York the board and the engine
    // both move on together.
    final lateNight = _edt(10, 6, 2, 30);
    final board = projectClassDay(schedule, lateNight);
    expect(board.dayKey, '2026-10-05');
    final signals = board.classes.last.facts;
    expect(signals.nightEndsAt, DateTime.utc(2026, 10, 6, 8));
    expect(Days.nightKey(lateNight), '2026-10-06');

    final state = GameState();
    Clock.freeze(lateNight);
    expect(state.checkClassKeep(signals), ClassKeepCheck.open);
    Clock.freeze(_edt(10, 6, 4));
    expect(projectClassDay(schedule, _edt(10, 6, 4)).dayKey, '2026-10-06');
    expect(state.checkClassKeep(signals), ClassKeepCheck.outsideWindow);
    Clock.freeze(lateNight.toLocal());
    expect(
      state.keepClass(signals, dayClassKeys: board.dayClassKeys),
      isNotNull,
    );
  });

  test('office hours stay keepable but a full day never waits on them', () {
    final json = schedule.toJson();
    for (final occurrence in (json['occurrences'] as List).cast<Map>()) {
      final date = occurrence['date'];
      // Monday's 5:40 PM meeting, and all of Friday, become office hours.
      if ((date == '2026-10-05' && occurrence['localStartMinute'] == 1060) ||
          date == '2026-10-09') {
        occurrence['kind'] = MeetingKind.officeHours.name;
      }
    }
    final edited = AcademicSchedule.fromJson(json);
    final monday = projectClassDay(edited, _edt(10, 5, 19, 15));
    expect(monday.classes, hasLength(3), reason: 'still on the board');
    final officeHours = monday.classes.last;
    expect(officeHours.kind, MeetingKind.officeHours);
    expect(officeHours.countsTowardDay, isFalse);
    expect(monday.dayClassKeys, hasLength(2));
    expect(monday.dayClassKeys, isNot(contains(officeHours.occurrenceKey)));

    Clock.freeze(_edt(10, 5, 19, 15).toLocal());
    final state = GameState();
    state.keepClass(monday.classes[0].facts, dayClassKeys: monday.dayClassKeys);
    final second = state.keepClass(
      monday.classes[1].facts,
      dayClassKeys: monday.dayClassKeys,
    )!;
    expect(second.dayComplete, isTrue);
    expect(second.fullDayBonus, 10);
    final drop = state.keepClass(
      officeHours.facts,
      dayClassKeys: monday.dayClassKeys,
    )!;
    expect(drop.fullDayBonus, 0, reason: 'the bonus is paid once');
    expect(drop.xp, ClassPay.lecture.xp);

    expect(
      restDayFor(edited, '2026-10-09'),
      isTrue,
      reason: 'only office hours',
    );
    expect(restDayFor(edited, '2026-10-05'), isFalse);
    final friday = projectClassDay(edited, _edt(10, 9, 12));
    expect(friday.isClassDay, isTrue);
    expect(friday.dayClassKeys, isEmpty);
  });

  test('his Thursday lab is a lab, in session at 5:15 PM', () {
    final day = projectClassDay(schedule, _edt(10, 8, 17, 15));
    expect(_codes(day), ['14:332:361', '01:198:206', '14:332:363']);
    final lab = day.classes.last;
    expect(lab.kind, MeetingKind.lab);
    expect(lab.title, 'Electron Devices Lab');
    expect(lab.moment, ClassMoment.inSession);
    expect(lab.facts.kind, 'lab');
    expect(ClassPay.forKind(lab.facts.kind).xp, 30);
    expect(day.lastClassEnd, DateTime.utc(2026, 10, 8, 22, 50));
    expect(day.afterLastClass(_edt(10, 8, 17, 15)), isFalse);
  });

  test('Sep 8 runs Monday\'s classes; Tuesday\'s own are left out', () {
    final day = projectClassDay(schedule, _edt(9, 8, 12));
    expect(day.date, CivilDate(2026, 9, 8));
    expect(_codes(day), ['14:332:361', '14:332:345', '14:332:345']);
    expect(day.classes.every((entry) => entry.moved), isTrue);
    expect(
      day.classes.every((entry) => entry.originalDate == CivilDate(2026, 9, 7)),
      isTrue,
    );
    expect(day.runsWeekdayOf, DateTime.monday);
    expect(day.classes.first.startsAt, DateTime.utc(2026, 9, 8, 12, 30));
    expect(day.classes.first.facts.dayKey, '2026-09-08');
    expect(restDayFor(schedule, '2026-09-08'), isFalse);
    expect(
      restDayFor(schedule, '2026-09-07'),
      isTrue,
      reason: 'Labor Day has nothing left on it',
    );
  });

  test('Nov 25 runs Friday\'s two; Nov 26 is a day off', () {
    final wednesday = projectClassDay(schedule, _est(11, 25, 12));
    expect(_codes(wednesday), ['14:332:331', '01:198:206']);
    expect(wednesday.runsWeekdayOf, DateTime.friday);
    expect(wednesday.lastClassEnd, DateTime.utc(2026, 11, 25, 23, 50));

    final thanksgiving = projectClassDay(schedule, _est(11, 26, 12));
    expect(thanksgiving.date, CivilDate(2026, 11, 26));
    expect(thanksgiving.isClassDay, isFalse);
    expect(thanksgiving.classes, isEmpty);
    expect(thanksgiving.lastClassEnd, isNull);
    expect(thanksgiving.afterLastClass(_est(11, 26, 12)), isFalse);
    expect(thanksgiving.dayClassKeys, isEmpty);
    expect(restDayFor(schedule, '2026-11-26'), isTrue);
    expect(
      restDayFor(schedule, '2026-11-27'),
      isTrue,
      reason: 'its classes moved',
    );
    final next = thanksgiving.nextClassAfter!;
    expect(next.date, CivilDate(2026, 11, 30));
    expect(next.daysAhead, 4);
    expect(next.dayWord, 'Monday');
    expect(next.entry.startsAt, DateTime.utc(2026, 11, 30, 13, 30));
  });

  test('before 4am the day still belongs to the night before', () {
    final lateNight = projectClassDay(schedule, _edt(10, 6, 1, 30));
    expect(lateNight.date, CivilDate(2026, 10, 5));
    expect(_codes(lateNight), ['14:332:361', '14:332:345', '14:332:345']);
    expect(lateNight.nextClassAfter!.dayWord, 'tomorrow');

    final morning = projectClassDay(schedule, _edt(10, 6, 4));
    expect(morning.date, CivilDate(2026, 10, 6));
  });

  test('a Friday points to Monday; far days use a short date', () {
    final friday = projectClassDay(schedule, _edt(10, 9, 19));
    expect(_codes(friday), ['14:332:331', '01:198:206']);
    expect(friday.afterLastClass(_edt(10, 9, 19)), isTrue);
    expect(friday.nextClassAfter!.daysAhead, 3);
    expect(friday.nextClassAfter!.dayWord, 'Monday');

    final beforeTerm = projectClassDay(
      schedule,
      _edt(8, 25, 12),
      day: CivilDate(2026, 8, 25),
    );
    expect(beforeTerm.isClassDay, isFalse);
    expect(beforeTerm.nextClassAfter!.date, CivilDate(2026, 9, 1));
    expect(beforeTerm.nextClassAfter!.dayWord, 'Sep 1');

    final afterTerm = projectClassDay(schedule, _est(12, 14, 12));
    expect(afterTerm.isClassDay, isFalse);
    expect(afterTerm.nextClassAfter, isNull);
  });

  test('rest days are term days without classes', () {
    expect(restDayFor(schedule, '2026-10-10'), isTrue); // Saturday
    expect(restDayFor(schedule, '2026-10-11'), isTrue); // Sunday
    expect(restDayFor(schedule, '2026-10-05'), isFalse);
    expect(restDayFor(schedule, '2026-12-19'), isFalse, reason: 'after term');
    expect(restDayFor(schedule, '2026-08-20'), isFalse, reason: 'before term');
    expect(restDayFor(schedule, 'not-a-day'), isFalse);
    expect(restDayFor(AcademicSchedule.empty(), '2026-10-10'), isFalse);
  });

  test('only real classes count: cancelled, tombstoned and archived drop', () {
    final json = schedule.toJson();
    Map mondayAt(int startMinute) =>
        (json['occurrences'] as List).cast<Map>().singleWhere(
          (occurrence) =>
              occurrence['date'] == '2026-10-05' &&
              occurrence['localStartMinute'] == startMinute,
        );
    mondayAt(840)
      ..['state'] = 'cancelled'
      ..['userAdjusted'] = true;
    mondayAt(1060)
      ..['state'] = 'cancelled'
      ..['tombstonedAt'] = DateTime.utc(2026, 9, 1).millisecondsSinceEpoch;
    final edited = AcademicSchedule.fromJson(json);
    final day = projectClassDay(edited, _edt(10, 5, 12));
    expect(_codes(day), ['14:332:361']);
    expect(day.lastClassEnd, DateTime.utc(2026, 10, 5, 13, 50));

    final archived = schedule.toJson();
    for (final course in archived['courses'] as List) {
      if ((course as Map)['code'] == '14:332:361') course['archived'] = true;
    }
    final withoutDevices = projectClassDay(
      AcademicSchedule.fromJson(archived),
      _edt(10, 5, 12),
    );
    expect(_codes(withoutDevices), ['14:332:345', '14:332:345']);
  });

  test('facts from an occurrence match the projected class', () {
    final day = projectClassDay(schedule, _edt(10, 7, 12));
    final lab = day.classes.first;
    final occurrence = schedule.occurrenceByKey(lab.occurrenceKey)!;
    final facts = classFactsFor(schedule, occurrence)!;
    expect(facts.occurrenceKey, lab.facts.occurrenceKey);
    expect(facts.courseCode, '14:332:333');
    expect(facts.title, 'Computer Architecture Lab');
    expect(facts.kind, 'lab');
    expect(facts.dayKey, '2026-10-07');
    expect(facts.startMinute, 510);
    expect(facts.startsAt, DateTime.utc(2026, 10, 7, 12, 30));
    expect(facts.endsAt, DateTime.utc(2026, 10, 7, 15, 30));
  });

  test('the resolver hook reads the timetable for the pause rule', () {
    GameState.restDayResolver = (key) => restDayFor(schedule, key);
    expect(GameState.restDayResolver!('2026-10-10'), isTrue);
    expect(GameState.restDayResolver!('2026-10-12'), isFalse);
  });
}
