// The class-day card and celebration words, read from his real Fall 2026
// timetable. Instants only (New York wall times converted from UTC), so this
// holds on a host in any zone.
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
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
      expect(plan.numeralLabel, 'YOUR FIRST LECTURE');
      expect(plan.autoReturn, const Duration(milliseconds: 2400));
      expect(plan.closing.first, 'First one down.');
      expect(plan.rows, isEmpty);
      expect(plan.streakLine, isNull);
    });

    test('the count only grows and names the kind', () {
      final state = GameState();
      keepAndPlan(state, _ny(5, 19, 0), [0]);
      final plan = keepAndPlan(state, _ny(8, 10, 0), [0]);
      expect(plan.numeral, 2);
      expect(plan.numeralLabel, 'YOUR 2ND LECTURE');
      final lab = keepAndPlan(state, _ny(7, 11, 40), [0]);
      expect(lab.numeralLabel, 'YOUR FIRST LAB');
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

    test('a later mark after the first one past the last class is not '
        'the day tier unless it completes the day', () {
      final state = GameState();
      keepAndPlan(state, _ny(5, 19, 15), [2]);
      final second = keepAndPlan(state, _ny(5, 19, 20), [0]);
      expect(second.tier, ClassCelebrationTier.classKept);
      final third = keepAndPlan(state, _ny(5, 19, 25), [1]);
      expect(third.tier, ClassCelebrationTier.dayDone);
      expect(third.closing.first, 'Three for three.');
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
    });

    test('the shortcut keeps several in one plan', () {
      final plan = keepAndPlan(GameState(), _ny(5, 19, 15), [0, 1, 2]);
      expect(plan.tier, ClassCelebrationTier.dayDone);
      expect(plan.numeral, 3);
      expect(plan.numeralLabel, 'CLASSES TODAY');
      expect(plan.rows, hasLength(3));
      expect(plan.title, isNull);
      expect(plan.xpGained, 85);
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
