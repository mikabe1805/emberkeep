// The class-day card and celebration words, read from his real Fall 2026
// timetable. Instants only (New York wall times converted from UTC), so this
// holds on a host in any zone.
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/routines.dart' show isWindDownTime;
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/class_day/class_day_model.dart';
import 'package:emberkeep/widgets/levelup_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/rutgers_fall_2026_ics_fixture.dart';

DateTime _ny(int day, int hour, int minute, [int second = 0]) =>
    DateTime.utc(2026, 10, day, hour + 4, minute, second).toLocal();

final AcademicSchedule _fall2026 = AcademicScheduleIcsImporter.parse(
  rutgersFall2026IcsFixture(),
).applyTo(AcademicSchedule.empty(), updatedAt: DateTime.utc(2026, 8, 27));

ClassDay _day(DateTime at) => projectClassDay(_fall2026, at);

/// A term whose only classes are on Fridays: a lecture in the morning and an
/// office hour in the afternoon (optional: a day is complete without it).
String _fridayWithOfficeHourIcs() {
  final out = StringBuffer('BEGIN:VCALENDAR\nVERSION:2.0\n');
  void meeting(String uid, String start, String end, String kind) => out
    ..write('BEGIN:VEVENT\nUID:$uid\n')
    ..write('DTSTART;TZID=America/New_York:20260904T$start\n')
    ..write('DTEND;TZID=America/New_York:20260904T$end\n')
    ..write('RRULE:FREQ=WEEKLY;BYDAY=FR;UNTIL=20261211T045959Z\n')
    ..write('SUMMARY:Signals and Systems\n')
    ..write('LOCATION:EE-105\\, Busch Campus\n')
    ..write('X-ROOM-OF-DAYS-TERM:Fall 2026\n')
    ..write('X-ROOM-OF-DAYS-TERM-START:2026-09-01\n')
    ..write('X-ROOM-OF-DAYS-TERM-END:2026-12-10\n')
    ..write('X-ROOM-OF-DAYS-COURSE-CODE:14:332:345\n')
    ..write('X-ROOM-OF-DAYS-COURSE-TITLE:Signals and Systems\n')
    ..write('X-ROOM-OF-DAYS-SECTION:01\n')
    ..write('X-ROOM-OF-DAYS-MEETING-KIND:$kind\n')
    ..write('X-ROOM-OF-DAYS-CAMPUS:Busch\n')
    ..write('X-ROOM-OF-DAYS-BUILDING:EE\n')
    ..write('X-ROOM-OF-DAYS-ROOM:105\nEND:VEVENT\n');
  meeting('signals-fr@test', '100000', '112000', 'lecture');
  meeting('signals-oh-fr@test', '140000', '150000', 'office hours');
  out.write('END:VCALENDAR\n');
  return out.toString();
}

ClassDay? _dayOf(CivilDate date) =>
    projectClassDay(_fall2026, _ny(5, 12, 0), day: date);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(Clock.reset);

  group('what is next, in the shape of his week', () {
    final lines = {
      5: 'Tomorrow starts late: Computer Architecture at 10:20.',
      6: "Nothing else until Wednesday's 8:30 lab.",
      7: 'Thursday is the long one: three classes, lab until 6:50.',
      8: 'Friday ends late: Discrete Structures II at 5:55.',
      9: 'Free until Monday at 8:30.',
    };
    for (final MapEntry(key: day, value: line) in lines.entries) {
      test('Oct $day', () {
        expect(nextClassDayLine(_day(_ny(day, 19, 30)), _dayOf), line);
      });
    }
  });

  group('the card', () {
    test('before class: the next class leads, nothing to mark', () {
      Clock.freeze(_ny(6, 8, 5));
      final card = ClassCard.read(
        _day(_ny(6, 8, 5)),
        GameState(),
        _ny(6, 8, 5),
      );
      expect(card.foremost?.entry.courseCode, '14:332:331');
      expect(card.foremost?.state, ClassRowState.upcoming);
      expect(card.rows.map((row) => row.markable), [false, false]);
      expect(card.offersShortcut, isFalse);
      expect(card.isRecord, isFalse);
    });

    test('a countdown, then in session, then ready', () {
      for (final (at, state) in [
        (_ny(6, 10, 8), ClassRowState.startsSoon),
        (_ny(6, 10, 50), ClassRowState.inSession),
        (_ny(6, 11, 52), ClassRowState.ready),
      ]) {
        Clock.freeze(at);
        final card = ClassCard.read(_day(at), GameState(), at);
        expect(card.foremost?.state, state, reason: '$at');
      }
    });

    test('the latest markable class leads; earlier ones wait quietly', () {
      final at = _ny(5, 19, 15);
      Clock.freeze(at);
      final card = ClassCard.read(_day(at), GameState(), at);
      expect(card.foremost?.entry.localStartMinute, 17 * 60 + 40);
      expect(card.waiting, hasLength(3));
      expect(card.offersShortcut, isTrue);
      expect(card.shortcutCompletesDay, isTrue);
      final preferred = card.rows.first.identity;
      final again = ClassCard.read(
        _day(at),
        GameState(),
        at,
        preferred: preferred,
      );
      expect(again.foremost?.identity, preferred);
    });

    test('kept classes count up; every kept day becomes the record', () {
      final at = _ny(6, 15, 35);
      Clock.freeze(at);
      final state = GameState();
      final day = _day(at);
      expect(
        state.keepClass(
          day.classes.first.facts,
          dayClassKeys: day.dayClassKeys,
        ),
        isNotNull,
      );
      var card = ClassCard.read(day, state, at);
      expect(card.keptCount, 1);
      expect(card.allKept, isFalse);
      expect(card.offersShortcut, isFalse, reason: 'one class waits');
      expect(
        state.keepClass(day.classes.last.facts, dayClassKeys: day.dayClassKeys),
        isNotNull,
      );
      card = ClassCard.read(day, state, at);
      expect(card.allKept, isTrue);
      expect(card.isRecord, isTrue);
    });

    test('the next boundary: the countdown, its minutes, the start', () {
      final day = _day(_ny(6, 11, 52));
      expect(
        nextClassBoundary(day, _ny(6, 11, 52)),
        _ny(6, 13, 45).toUtc(),
        reason: 'fifteen minutes before 2:00',
      );
      expect(
        nextClassBoundary(day, _ny(6, 13, 48, 30)),
        _ny(6, 13, 49).toUtc(),
        reason: 'the countdown ticks each minute',
      );
      expect(nextClassStartOrEnd(day, _ny(6, 11, 52)), _ny(6, 14, 0).toUtc());
    });
  });

  group('words', () {
    test('titles as said out loud', () {
      expect(
        classShortTitle('Introduction to Discrete Structures II'),
        'Discrete Structures II',
      );
      expect(
        classBriefTitle('Computer Architecture & Assembly Language'),
        'Computer Architecture',
      );
      expect(
        classBriefTitle('Linear Systems & Signals'),
        'Linear Systems & Signals',
      );
    });

    test('ordinals and clocks', () {
      expect(classOrdinal(1), 'FIRST');
      expect(classOrdinal(9), '9TH');
      expect(classOrdinal(12), '12TH');
      expect(classOrdinal(21), '21ST');
      expect(classClock(14 * 60), '2:00 PM');
      expect(classClock(8 * 60 + 30), '8:30 AM');
      expect(classClockShort(17 * 60 + 55), '5:55');
    });
  });

  group('the celebration plan', () {
    ClassCelebrationPlan keepAndPlan(
      GameState state,
      DateTime at,
      List<int> indexes, {
      DateTime? previous,
    }) {
      Clock.freeze(at);
      final day = _day(at);
      final keptBefore = [...state.classesKeptOn(day.dayKey)];
      final marked = [for (final i in indexes) day.classes[i]];
      final credits = [
        for (final entry in marked)
          state.keepClass(entry.facts, dayClassKeys: day.dayClassKeys)!,
      ];
      return planClassCelebration(
        day: day,
        state: state,
        marked: marked,
        credits: credits,
        keptBefore: keptBefore,
        now: at,
        dayOf: _dayOf,
        previousMarkAt: previous,
      );
    }

    test('a class mid-day: YOU WERE THERE., his count, what is next', () {
      final plan = keepAndPlan(GameState(), _ny(6, 11, 52), [0]);
      expect(plan.tier, ClassCelebrationTier.classKept);
      expect(plan.headline, 'YOU WERE THERE.');
      expect(plan.numeral, 1);
      expect(plan.numeralLabel, 'FIRST ONE ON RECORD');
      expect(plan.autoReturn, const Duration(milliseconds: 2400));
      expect(plan.closing.first, 'First one down.');
      expect(plan.rows, isEmpty);
      expect(plan.streakLine, '1 DAY RUNNING · TODAY COUNTS');
    });

    test('the count only grows and names the kind', () {
      final state = GameState();
      keepAndPlan(state, _ny(5, 19, 0), [0]);
      final plan = keepAndPlan(state, _ny(8, 10, 0), [0]);
      expect(plan.numeral, 2);
      expect(plan.numeralLabel, 'YOUR 2ND LECTURE ON RECORD');
      expect(plan.numeralLabel, isNot(contains(' OF ')));
      final lab = keepAndPlan(state, _ny(7, 11, 40), [0]);
      expect(lab.numeralLabel, 'FIRST ONE ON RECORD');
      expect(lab.gains.keys.single.name, 'foc');
    });

    test('a second mark within 15 s is the quick tier', () {
      final state = GameState();
      final first = keepAndPlan(state, _ny(8, 15, 22), [1]);
      expect(first.tier, ClassCelebrationTier.classKept);
      final quick = keepAndPlan(state, _ny(8, 15, 22, 10), [
        0,
      ], previous: _ny(8, 15, 22));
      expect(quick.tier, ClassCelebrationTier.quick);
      expect(quick.headline, 'THAT ONE TOO.');
      expect(quick.autoReturn, const Duration(milliseconds: 1400));
      expect(quick.speed, 1.5);
      final later = keepAndPlan(GameState(), _ny(8, 15, 40), [
        0,
      ], previous: _ny(8, 15, 22));
      expect(later.tier, ClassCelebrationTier.classKept);
    });

    test('the day tier holds, and says N for N only when true', () {
      final partial = keepAndPlan(GameState(), _ny(6, 15, 35), [1]);
      expect(partial.tier, ClassCelebrationTier.dayDone);
      expect(partial.headline, 'TUESDAY, DONE.');
      expect(partial.autoReturn, isNull);
      expect(partial.bonusLine, isNull);
      expect(partial.closing.join(' '), isNot(contains('for')));

      final state = GameState();
      keepAndPlan(state, _ny(6, 11, 53), [0]);
      final full = keepAndPlan(state, _ny(6, 15, 35), [1]);
      expect(full.tier, ClassCelebrationTier.dayDone);
      expect(full.closing.first, 'Two for two.');
      expect(full.bonusLine, "All of Tuesday's classes");
      expect(full.bonusXp, 10);
      expect(full.xpShown, 60);
      expect(full.xpFrom, 25);
      expect(full.caption, "TUESDAY'S CLASSES · +35 THIS MARK");
    });

    test('the day tier counts the day: classes attended today, no course '
        'title, no denominator', () {
      final state = GameState();
      keepAndPlan(state, _ny(6, 11, 53), [0]);
      final day = keepAndPlan(state, _ny(6, 15, 35), [1]);
      expect(day.tier, ClassCelebrationTier.dayDone);
      expect(day.numeral, 2, reason: 'both classes, not the course count');
      expect(day.numeralLabel, 'ATTENDED TODAY');
      expect(day.title, isNull);
      expect(day.detail, isNull);
      expect(day.rows, hasLength(2));
      expect(day.closing.first, 'Two for two.');
      expect(day.semanticsLabel, contains('2 attended today'));

      // A partial day counts what he went to, and a lone class says 1.
      final partial = keepAndPlan(GameState(), _ny(6, 15, 35), [1]);
      expect(partial.tier, ClassCelebrationTier.dayDone);
      expect(partial.numeral, 1);
      expect(partial.numeralLabel, 'ATTENDED TODAY');
      expect(partial.title, isNull);
      for (final plan in [day, partial]) {
        expect(plan.numeralLabel, isNot(contains(' OF ')));
        expect(plan.numeralLabel, isNot(contains('RECORD')));
      }
    });

    test(
      'the single-class and quick tiers keep the course count and title',
      () {
        final state = GameState();
        keepAndPlan(state, _ny(5, 19, 0), [0]);
        final lecture = keepAndPlan(state, _ny(8, 10, 0), [0]);
        expect(lecture.tier, ClassCelebrationTier.classKept);
        expect(lecture.title, isNotNull);
        expect(lecture.detail, isNotNull);
        expect(lecture.numeralLabel, endsWith('ON RECORD'));
      },
    );

    test('the day tier plays once a day: a later mark that completes the '
        'day says so without a second DONE.', () {
      final state = GameState();
      final first = keepAndPlan(state, _ny(5, 19, 15), [2]);
      expect(first.tier, ClassCelebrationTier.dayDone);
      expect(first.headline, 'MONDAY, DONE.');
      final second = keepAndPlan(state, _ny(5, 19, 20), [0]);
      expect(second.tier, ClassCelebrationTier.classKept);
      expect(second.closing.join(' '), isNot(contains('for')));
      final third = keepAndPlan(state, _ny(5, 19, 25), [1]);
      expect(third.tier, ClassCelebrationTier.classKept);
      expect(third.headline, 'YOU WERE THERE.');
      expect(third.closing.first, 'Three for three.');
      expect(third.bonusLine, "All of Monday's classes");
      expect(third.bonusXp, 10);
    });

    test('marked one at a time in the evening: DONE., THAT ONE TOO., then '
        'THAT ONE TOO. with the full day, never DONE. twice', () {
      final state = GameState();
      final first = keepAndPlan(state, _ny(5, 19, 15, 5), [2]);
      final second = keepAndPlan(state, _ny(5, 19, 15, 11), [
        0,
      ], previous: _ny(5, 19, 15, 5));
      final third = keepAndPlan(state, _ny(5, 19, 15, 17), [
        1,
      ], previous: _ny(5, 19, 15, 11));
      expect(
        [first.headline, second.headline, third.headline],
        ['MONDAY, DONE.', 'THAT ONE TOO.', 'THAT ONE TOO.'],
      );
      expect(third.closing.first, 'Three for three.');
      expect(third.bonusXp, 10);
    });

    test('the week tier counts the week without a denominator', () {
      final state = GameState();
      for (final day in [5, 7, 8]) {
        keepAndPlan(state, _ny(day, 19, 45), [
          for (var i = 0; i < _day(_ny(day, 19, 45)).classes.length; i++) i,
        ]);
      }
      keepAndPlan(state, _ny(6, 19, 45), [0]);
      keepAndPlan(state, _ny(9, 11, 45), [0]);
      final week = keepAndPlan(state, _ny(9, 18, 56), [1]);
      expect(week.tier, ClassCelebrationTier.weekDone);
      expect(week.headline, "THAT'S THE WEEK.");
      expect(week.closing, [
        'Eleven classes this week.',
        'Free until Monday at 8:30.',
      ]);
      expect(week.numeral, 11, reason: 'the diamond matches the closing line');
      expect(week.numeralLabel, 'ATTENDED THIS WEEK');
      expect(week.title, isNull);
      expect(week.detail, isNull);
      expect(week.numeralLabel, isNot(contains(' OF ')));
      // The list matches the diamond: one row per class day attended, with
      // how many, and no row for a count of nothing.
      expect(
        [for (final row in week.rows) (row.title, row.time)],
        [
          ('Monday', '3'),
          ('Tuesday', '1'),
          ('Wednesday', '2'),
          ('Thursday', '3'),
          ('Friday', '2'),
        ],
      );
      expect(
        week.rows.fold(0, (sum, row) => sum + int.parse(row.time)),
        week.numeral,
      );
      expect(week.rows.where((row) => row.marked).single.title, 'Friday');
      expect(week.rows.every((row) => row.xp > 0), isTrue);
      // The day rows already carry each day's full-day bonus, so the list
      // sums exactly to the big number, with no separate bonus row.
      expect(week.bonusLine, isNull);
      expect(week.bonusXp, 0);
      expect(
        week.rows.fold(0, (sum, row) => sum + row.xp),
        week.xpShown,
        reason: 'the week rows add up to the big XP number',
      );
    });

    test('the shortcut keeps several in one plan', () {
      final plan = keepAndPlan(GameState(), _ny(5, 19, 15), [0, 1, 2]);
      expect(plan.tier, ClassCelebrationTier.dayDone);
      expect(plan.numeral, 3);
      expect(plan.numeralLabel, 'ATTENDED TODAY');
      expect(plan.rows, hasLength(3));
      expect(plan.title, isNull);
      expect(plan.xpGained, 85);
    });

    test('the stat chip speaks for the same classes as the big number', () {
      final state = GameState();
      final first = keepAndPlan(state, _ny(6, 11, 53), [0]);
      expect(first.xpShown, 25);
      expect(first.gains, {Stat.intl: 3}, reason: 'this mark');
      final day = keepAndPlan(state, _ny(6, 15, 35), [1]);
      expect(day.tier, ClassCelebrationTier.dayDone);
      expect(day.xpShown, 60, reason: "the day's XP");
      expect(day.gains, {Stat.intl: 6}, reason: "the day's MIND, both kept");
      expect(day.totals, {Stat.intl: 6});

      // Thursday: two lectures and the lab; the day's chips carry both.
      final thursday = keepAndPlan(GameState(), _ny(8, 19, 0), [0, 1, 2]);
      expect(thursday.gains, {Stat.intl: 6, Stat.foc: 5});
    });

    test('the week tier counts the week on its chips too', () {
      final state = GameState();
      for (final day in [5, 6, 7, 8]) {
        keepAndPlan(state, _ny(day, 19, 45), [
          for (var i = 0; i < _day(_ny(day, 19, 45)).classes.length; i++) i,
        ]);
      }
      keepAndPlan(state, _ny(9, 11, 45), [0]);
      final week = keepAndPlan(state, _ny(9, 18, 56), [1]);
      expect(week.tier, ClassCelebrationTier.weekDone);
      final kept = [
        for (final d in [5, 6, 7, 8, 9])
          ...state.classesKeptOn(_day(_ny(d, 12, 0)).dayKey),
      ];
      final mind = kept
          .where((k) => k.stat == Stat.intl)
          .fold(0, (sum, k) => sum + k.statGain);
      expect(week.gains[Stat.intl], mind);
      expect(week.gains.keys.first, Stat.intl, reason: 'the mark leads');
    });

    test('the quick tier drops the time and room line', () {
      final state = GameState();
      keepAndPlan(state, _ny(8, 15, 22), [1]);
      final quick = keepAndPlan(state, _ny(8, 15, 22, 10), [
        0,
      ], previous: _ny(8, 15, 22));
      expect(quick.tier, ClassCelebrationTier.quick);
      expect(quick.detail, isNull);
      expect(quick.title, 'Electronics Devices');
    });

    group('the streak line, with ClassDayRules lighting it', () {
      tearDown(() => ClassDayRules.debugOverride = null);

      test('on the first class of a day, never on the second', () {
        ClassDayRules.debugOverride = const ClassDayRules(
          classDayLightsStreak: true,
        );
        final state = GameState();
        final first = keepAndPlan(state, _ny(6, 11, 53), [0]);
        expect(first.streakLine, '1 DAY RUNNING · TODAY COUNTS');
        final second = keepAndPlan(state, _ny(6, 15, 35), [1]);
        expect(second.streakLine, isNull, reason: 'the day was already lit');
        final wednesday = keepAndPlan(state, _ny(7, 11, 40), [0]);
        expect(wednesday.streakLine, '2 DAYS RUNNING · TODAY COUNTS');
      });

      test('the shortcut keeps three at once and still reads one day', () {
        ClassDayRules.debugOverride = const ClassDayRules(
          classDayLightsStreak: true,
        );
        final plan = keepAndPlan(GameState(), _ny(5, 19, 15), [0, 1, 2]);
        expect(plan.tier, ClassCelebrationTier.dayDone);
        expect(plan.streakLine, '1 DAY RUNNING · TODAY COUNTS');
        expect(plan.streakLine, isNot(contains('0 DAYS')));
      });

      test('absent when the rule is off', () {
        ClassDayRules.debugOverride = const ClassDayRules(
          classDayLightsStreak: false,
        );
        final plan = keepAndPlan(GameState(), _ny(6, 11, 53), [0]);
        expect(plan.streakLine, isNull);
      });
    });
  });

  group('the board may close the day', () {
    GameState keptAll(DateTime at) {
      Clock.freeze(at);
      final day = _day(at);
      final state = GameState();
      for (final entry in day.classes) {
        state.keepClass(entry.facts, dayClassKeys: day.dayClassKeys);
      }
      return state;
    }

    bool lets(GameState state, DateTime at) {
      Clock.freeze(at);
      return classDayLetsBoardCloseDay(_day(at), state, at);
    }

    test('not while a class is coming, in session or ready to be marked', () {
      expect(lets(GameState(), _ny(6, 9, 0)), isFalse, reason: 'coming');
      expect(lets(GameState(), _ny(6, 11, 52)), isFalse, reason: 'markable');
      expect(lets(GameState(), _ny(6, 14, 40)), isFalse, reason: 'in session');
      expect(lets(GameState(), _ny(6, 15, 35)), isFalse, reason: 'waiting');
    });

    test('once the last class is over and every class is kept', () {
      expect(lets(keptAll(_ny(6, 15, 45)), _ny(6, 15, 50)), isTrue);
    });

    test('in the wind-down a class left unmarked is neutral', () {
      expect(lets(GameState(), _ny(6, 18, 0)), isTrue);
      expect(lets(GameState(), _ny(5, 17, 45)), isFalse, reason: 'in lecture');
    });

    test('a day without classes always may', () {
      final saturday = _ny(10, 12, 0);
      Clock.freeze(saturday);
      expect(
        classDayLetsBoardCloseDay(_day(saturday), GameState(), saturday),
        isTrue,
      );
    });
  });

  group('past the week and past midnight', () {
    test('a break longer than a week names the date, not a weekday', () {
      final tuesday = _day(_ny(6, 19, 30));
      final after = _dayOf(CivilDate(2026, 10, 19));
      expect(after!.classes, isNotEmpty);
      final broken = ClassDay(
        date: tuesday.date,
        classes: tuesday.classes,
        lastClassEnd: tuesday.lastClassEnd,
        nextClassAfter: NextClass(
          entry: after.classes.first,
          daysAhead: 13,
          dayWord: 'Oct 19',
        ),
        runsWeekdayOf: null,
      );
      expect(nextClassDayLine(broken, _dayOf), 'Free until Oct 19 at 8:30.');
    });

    test('at 11 PM the next boundary is the night ending at 4 AM', () {
      final day = _day(_ny(6, 23, 0));
      expect(day.date, CivilDate(2026, 10, 6));
      final end = nextClassBoundary(day, _ny(6, 23, 0));
      expect(end, _ny(7, 4, 0).toUtc());
      expect(end, classNightEndFor(day.date, 'America/New_York'));
    });

    test('an office hour alone never makes the week say zero', () {
      final schedule = AcademicScheduleIcsImporter.parse(
        _fridayWithOfficeHourIcs(),
      ).applyTo(AcademicSchedule.empty(), updatedAt: DateTime.utc(2026, 8, 27));
      ClassDay? dayOf(CivilDate date) =>
          projectClassDay(schedule, _ny(9, 12, 0), day: date);
      final at = _ny(9, 15, 30);
      Clock.freeze(at);
      final day = projectClassDay(schedule, at);
      expect(day.classes, hasLength(2));
      final office = day.classes.last;
      expect(office.kind, MeetingKind.officeHours);
      final state = GameState();
      final credit = state.keepClass(
        office.facts,
        dayClassKeys: day.dayClassKeys,
      );
      expect(credit, isNotNull);
      final plan = planClassCelebration(
        day: day,
        state: state,
        marked: [office],
        credits: [credit!],
        keptBefore: const [],
        now: at,
        dayOf: dayOf,
      );
      expect(plan.tier, ClassCelebrationTier.weekDone);
      expect(plan.numeral, 1);
      expect(plan.closing.first, 'One class this week.');
      expect(plan.closing.join(' '), isNot(contains('Zero')));
    });
  });

  group('the evening and the wind-down', () {
    GameState kept(DateTime at, Set<String> codes) {
      Clock.freeze(at);
      final day = _day(at);
      final state = GameState();
      for (final entry in day.classes) {
        if (!codes.contains(entry.courseCode)) continue;
        expect(
          state.keepClass(entry.facts, dayClassKeys: day.dayClassKeys),
          isNotNull,
        );
      }
      return state;
    }

    test('the wind-down window waits for the last class to end', () {
      final end = DateTime(2026, 10, 5, 19);
      expect(isWindDownTime(DateTime(2026, 10, 5, 17, 45)), isTrue);
      expect(
        isWindDownTime(DateTime(2026, 10, 5, 17, 45), lastClassEnd: end),
        isFalse,
      );
      expect(
        isWindDownTime(DateTime(2026, 10, 5, 18, 59), lastClassEnd: end),
        isFalse,
      );
      expect(
        isWindDownTime(DateTime(2026, 10, 5, 19), lastClassEnd: end),
        isTrue,
      );
      // An afternoon that ended early is still not the wind-down.
      expect(
        isWindDownTime(
          DateTime(2026, 10, 6, 15, 35),
          lastClassEnd: DateTime(2026, 10, 6, 15, 20),
        ),
        isFalse,
      );
      expect(
        isWindDownTime(
          DateTime(2026, 10, 7, 1, 30),
          lastClassEnd: DateTime(2026, 10, 6, 15, 20),
        ),
        isTrue,
      );
    });

    test('never during his Monday 5:40 lecture or his Thursday lab', () {
      expect(classWindDown(_day(_ny(5, 17, 45)), _ny(5, 17, 45)), isFalse);
      expect(classWindDown(_day(_ny(5, 18, 59)), _ny(5, 18, 59)), isFalse);
      expect(classWindDown(_day(_ny(5, 19, 0)), _ny(5, 19, 0)), isTrue);
      expect(classWindDown(_day(_ny(8, 18, 45)), _ny(8, 18, 45)), isFalse);
      expect(classWindDown(_day(_ny(8, 18, 55)), _ny(8, 18, 55)), isTrue);
      // Tuesday ends at 3:20; the wind-down is still 5 PM.
      expect(classWindDown(_day(_ny(6, 15, 35)), _ny(6, 15, 35)), isFalse);
      expect(classWindDown(_day(_ny(6, 17, 0)), _ny(6, 17, 0)), isTrue);
      // Past midnight it is still Tuesday's night.
      expect(classWindDown(_day(_ny(7, 1, 30)), _ny(7, 1, 30)), isTrue);
    });

    test('the wind-down starts at 5 PM or at the last class end', () {
      expect(classWindDownStart(_day(_ny(6, 9, 0))), _ny(6, 17, 0).toUtc());
      expect(classWindDownStart(_day(_ny(5, 9, 0))), _ny(5, 19, 0).toUtc());
      expect(classWindDownStart(_day(_ny(8, 9, 0))), _ny(8, 18, 50).toUtc());
      // After Tuesday's last class, the next thing that changes the room by
      // itself is the wind-down at 5.
      expect(
        nextClassBoundary(_day(_ny(6, 15, 35)), _ny(6, 15, 35)),
        _ny(6, 17, 0).toUtc(),
      );
    });

    test('the evening: every class kept after the last one, or the '
        'wind-down', () {
      ClassCard card(DateTime at, GameState state) =>
          ClassCard.read(_day(at), state, at);
      const tuesday = {'14:332:331', '01:198:206'};
      // Both kept, the last over: the evening, at 3:35 PM.
      var at = _ny(6, 15, 35);
      expect(classEveningAt(card(at, kept(at, tuesday)), at), isTrue);
      // One unmarked: the day still leads with it until 5 PM.
      expect(classEveningAt(card(at, kept(at, {'14:332:331'})), at), isFalse);
      at = _ny(6, 17, 0);
      expect(classEveningAt(card(at, kept(at, {'14:332:331'})), at), isTrue);
      // Kept during the last class (I'M HERE): the evening waits for its end.
      at = _ny(6, 14, 40);
      expect(classEveningAt(card(at, kept(at, tuesday)), at), isFalse);
      // Monday: never during the late lecture; from 7 PM, marks or not.
      at = _ny(5, 17, 45);
      expect(classEveningAt(card(at, GameState()), at), isFalse);
      at = _ny(5, 19, 15);
      expect(classEveningAt(card(at, GameState()), at), isTrue);
    });

    test('the record folds to one line that only counts what he went to', () {
      Clock.freeze(_ny(6, 20, 30));
      var at = _ny(6, 20, 30);
      String line(Set<String> codes) =>
          classRecordLine(ClassCard.read(_day(at), kept(at, codes), at));
      expect(
        line({'14:332:331', '01:198:206'}),
        'Tuesday’s classes, both attended',
      );
      expect(line({'14:332:331'}), 'Tuesday’s classes, one attended');
      expect(line({}), 'Tuesday’s classes');
      at = _ny(5, 20, 30);
      expect(
        line({'14:332:361', '14:332:345'}),
        'Monday’s classes, all three attended',
      );
      for (final words in [
        line({}),
        line({'14:332:361'}),
      ]) {
        expect(words, isNot(contains(' of ')));
        expect(words, isNot(matches(RegExp(r'\d'))));
      }
    });

    test('the 9 PM night reminder never lands in one of his classes', () {
      // The default reminder (GameState.nightReminderHour) against the end
      // of every class day of his week.
      final reminder = GameState().nightReminderHour;
      expect(reminder, 21);
      for (var d = 5; d <= 9; d++) {
        final day = _day(_ny(d, 12, 0));
        final last = OccurrenceMaterializer.localTime(
          day.lastClassEnd!,
          'America/New_York',
        );
        expect(
          last.hour * 60 + last.minute,
          lessThanOrEqualTo(reminder * 60),
          reason: 'Oct $d ends at $last',
        );
      }
    });
  });

  group('the level-up names classes beside quests', () {
    Future<void> pump(WidgetTester tester, {int? quests, int classes = 0}) =>
        tester.pumpWidget(
          MaterialApp(
            home: LevelUpOverlay(
              level: 22,
              previousLevel: 21,
              questsSince: quests,
              classesSince: classes,
              reduceMotion: true,
              onDismiss: () {},
            ),
          ),
        );

    testWidgets('quests and classes', (tester) async {
      await pump(tester, quests: 11, classes: 24);
      expect(
        find.text('11 quests and 24 classes since level 21'),
        findsOneWidget,
      );
    });

    testWidgets('classes alone', (tester) async {
      await pump(tester, quests: 0, classes: 1);
      expect(find.text('one class since level 21'), findsOneWidget);
    });

    testWidgets('nothing counted, no line', (tester) async {
      await pump(tester);
      expect(find.textContaining('since level'), findsNothing);
    });
  });
}
