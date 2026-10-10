// The rules a set-aside class lives by (the design lead's three), and the
// serialized shape that carries them:
//
//   (a) the full-day bonus is withheld whenever any counting class that day
//       was set aside, whatever order the keeps and the dismissals came in;
//   (b) a class that was set aside has no reminder;
//   (c) the day tier's first closing line ("Two for two.") is said only when
//       nothing was set aside that day; otherwise only the next-class line.
//
// Instants only (New York wall times converted from UTC).
import 'dart:convert';
import 'dart:math' as math;

import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/academic_calendar/import/class_import_reminders.dart';
import 'package:emberkeep/academic_calendar/services/academic_reminder_projection.dart';
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/widgets/class_day/class_day_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/crowded_friday_schedule.dart';
import 'support/rutgers_fall_2026_ics_fixture.dart';

DateTime _ny(int day, int hour, int minute) =>
    DateTime.utc(2026, 10, day, hour + 4, minute).toLocal();

final AcademicSchedule _fall2026 = AcademicScheduleIcsImporter.parse(
  rutgersFall2026IcsFixture(),
).applyTo(AcademicSchedule.empty(), updatedAt: DateTime.utc(2026, 8, 27));

class _NoLuck implements math.Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.999;
  @override
  int nextInt(int max) => 0;
}

GameState _state() => GameState(rng: _NoLuck())..soundEnabled = false;

ClassDay _day(
  AcademicSchedule schedule,
  GameState state,
  DateTime at, {
  CivilDate? day,
}) => projectClassDay(
  schedule,
  at,
  day: day,
  isDismissed: state.isClassDismissed,
);

void main() {
  tearDown(Clock.reset);

  group('(a) the full-day bonus', () {
    // Thursday Oct 8: Electronics (8:30), Discrete (2:00), the lab (3:50).
    final at = _ny(8, 19, 0);

    ClassCredit? keep(GameState state, String code) {
      Clock.freeze(at);
      final plain = projectClassDay(_fall2026, at);
      final entry = plain.classes.firstWhere((c) => c.courseCode == code);
      final day = _day(_fall2026, state, at);
      return state.keepClass(entry.facts, dayClassKeys: day.dayClassKeys);
    }

    bool aside(GameState state, String code) {
      Clock.freeze(at);
      final plain = projectClassDay(_fall2026, at);
      return state.dismissClass(
        plain.classes.firstWhere((c) => c.courseCode == code).facts,
      );
    }

    test('set aside first, then the rest kept: no bonus', () {
      final state = _state();
      expect(aside(state, '14:332:363'), isTrue);
      final first = keep(state, '14:332:361');
      final last = keep(state, '01:198:206');
      expect(first!.fullDayBonus, 0);
      expect(last!.dayComplete, isTrue, reason: 'the day is still done');
      expect(last.fullDayBonus, 0);
      expect(state.dayRecordFor('2026-10-08')!.fullDayBonusXp, 0);
      expect(state.classXpForDay('2026-10-08'), 50);
    });

    test('kept first, then the last one set aside: no bonus either', () {
      final state = _state();
      expect(keep(state, '14:332:361')!.fullDayBonus, 0);
      expect(keep(state, '01:198:206')!.fullDayBonus, 0);
      expect(aside(state, '14:332:363'), isTrue);
      expect(state.dayRecordFor('2026-10-08')!.fullDayBonusXp, 0);
    });

    test('set aside between the keeps: no bonus', () {
      final state = _state();
      expect(keep(state, '14:332:361')!.fullDayBonus, 0);
      expect(aside(state, '01:198:206'), isTrue);
      final last = keep(state, '14:332:363');
      expect(last!.fullDayBonus, 0);
      expect(state.dayRecordFor('2026-10-08')!.fullDayBonusXp, 0);
    });

    test('all three kept: the bonus is paid, once', () {
      final state = _state();
      keep(state, '14:332:361');
      keep(state, '01:198:206');
      final last = keep(state, '14:332:363');
      expect(last!.fullDayBonus, ClassPay.fullDayBonusXp);
      expect(state.dayRecordFor('2026-10-08')!.fullDayBonusXp, 10);
    });

    test('a class set aside and then kept after all lifts the set-aside', () {
      final state = _state();
      aside(state, '14:332:363');
      keep(state, '14:332:361');
      keep(state, '01:198:206');
      expect(state.dayRecordFor('2026-10-08')!.fullDayBonusXp, 0);
      // He went after all: nothing is set aside any more and the full day is
      // paid, exactly once.
      final lab = keep(state, '14:332:363');
      expect(state.classesDismissedOn('2026-10-08'), isEmpty);
      expect(lab!.fullDayBonus, ClassPay.fullDayBonusXp);
      expect(state.dayRecordFor('2026-10-08')!.fullDayBonusXp, 10);
    });

    test('an optional meeting set aside never withholds it', () {
      // Two lectures and an office hour, one Friday.
      final schedule = crowdedFridaySchedule([
        'lecture',
        'office hours',
        'lecture',
      ]);
      final friday = _ny(9, 20, 0);
      Clock.freeze(friday);
      final state = _state();
      final plain = projectClassDay(schedule, friday);
      final office = plain.classes.firstWhere((c) => !c.countsTowardDay);
      expect(state.dismissClass(office.facts), isTrue);
      expect(state.classesDismissedOn('2026-10-09').single.optional, isTrue);
      final day = projectClassDay(
        schedule,
        friday,
        isDismissed: state.isClassDismissed,
      );
      ClassCredit? last;
      for (final entry in day.classes) {
        last = state.keepClass(entry.facts, dayClassKeys: day.dayClassKeys);
      }
      expect(last!.fullDayBonus, ClassPay.fullDayBonusXp);
    });

    test('a counting class is recorded as counting', () {
      final state = _state();
      aside(state, '14:332:363');
      expect(state.classesDismissedOn('2026-10-08').single.optional, isFalse);
    });
  });

  group('the saved shape stays compatible', () {
    test('a dismissal saved before the flag reads as a counting class', () {
      final old = {
        'occurrenceKey': 'occ-1',
        'courseCode': '14:332:363',
        'startMinute': 950,
        'dismissedAt': DateTime.utc(2026, 10, 8, 20).millisecondsSinceEpoch,
      };
      final read = DismissedClass.fromJson(old)!;
      expect(read.optional, isFalse);
      // And it writes back exactly as it was read: no new key for it.
      expect(read.toJson(), old);
    });

    test('the flag round-trips only when set', () {
      final item = DismissedClass(
        occurrenceKey: 'occ-2',
        courseCode: '14:332:999',
        startMinute: 750,
        dismissedAt: DateTime.utc(2026, 10, 8, 20),
        optional: true,
      );
      final json = jsonDecode(jsonEncode(item.toJson())) as Map;
      expect(json['optional'], isTrue);
      expect(DismissedClass.fromJson(json)!.optional, isTrue);
    });

    test('the save round-trips with its dismissals', () {
      final state = _state();
      Clock.freeze(_ny(8, 9, 0));
      final plain = projectClassDay(_fall2026, _ny(8, 9, 0));
      state.dismissClass(plain.classes.last.facts);
      final copy = GameState.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
      );
      expect(copy.classesDismissedOn('2026-10-08'), hasLength(1));
      expect(jsonEncode(copy.toJson()), jsonEncode(state.toJson()));
    });
  });

  group('(b) reminders', () {
    final reminded = withClassReminders(
      _fall2026,
      {for (final o in _fall2026.occurrences) o.meetingSeriesId},
      offsetMinutes: 15,
      updatedAt: DateTime.utc(2026, 9, 1),
    );

    test('every class has its reminder to begin with', () {
      Clock.freeze(_ny(8, 7, 0));
      final notices = projectAcademicReminderNotices(
        schedule: reminded,
        now: _ny(8, 7, 0),
      );
      final thursday = [
        for (final n in notices)
          if (n.whenUtc.isAfter(_ny(8, 7, 0).toUtc()) &&
              n.whenUtc.isBefore(_ny(9, 7, 0).toUtc()))
            n,
      ];
      expect(thursday, hasLength(3));
    });

    test('a class that was set aside has none', () {
      final state = _state();
      Clock.freeze(_ny(8, 7, 0));
      final plain = projectClassDay(_fall2026, _ny(8, 7, 0));
      final lab = plain.classes.firstWhere((c) => c.courseCode == '14:332:363');
      state.dismissClass(lab.facts);
      final notices = projectAcademicReminderNotices(
        schedule: reminded,
        now: _ny(8, 7, 0),
        isDismissed: state.isClassDismissed,
      );
      final thursday = [
        for (final n in notices)
          if (n.whenUtc.isAfter(_ny(8, 7, 0).toUtc()) &&
              n.whenUtc.isBefore(_ny(9, 7, 0).toUtc()))
            n,
      ];
      expect(thursday, hasLength(2));
      expect(
        thursday.map((n) => n.title).join(' '),
        isNot(contains('14:332:363')),
      );
      // Other days keep theirs, and the next lab is not touched.
      final all = notices.length;
      final without = projectAcademicReminderNotices(
        schedule: reminded,
        now: _ny(8, 7, 0),
      ).length;
      expect(all, without - 1);
    });

    test('bringing the class back brings its reminder back', () {
      final state = _state();
      Clock.freeze(_ny(8, 7, 0));
      final plain = projectClassDay(_fall2026, _ny(8, 7, 0));
      final lab = plain.classes.firstWhere((c) => c.courseCode == '14:332:363');
      state.dismissClass(lab.facts);
      state.undoDismiss(lab.facts);
      final notices = projectAcademicReminderNotices(
        schedule: reminded,
        now: _ny(8, 7, 0),
        isDismissed: state.isClassDismissed,
      );
      final plainCount = projectAcademicReminderNotices(
        schedule: reminded,
        now: _ny(8, 7, 0),
      ).length;
      expect(notices, hasLength(plainCount));
    });
  });

  group('(c) the day tier’s closing', () {
    final at = _ny(8, 19, 0);

    ClassCelebrationPlan plan(GameState state, {bool withAside = false}) {
      Clock.freeze(at);
      final plain = projectClassDay(_fall2026, at);
      if (withAside) {
        state.dismissClass(
          plain.classes.firstWhere((c) => c.courseCode == '14:332:363').facts,
        );
      }
      final day = _day(_fall2026, state, at);
      final before = [...state.classesKeptOn(day.dayKey)];
      final marked = <ProjectedClass>[];
      final credits = <ClassCredit>[];
      for (final entry in day.classes) {
        final credit = state.keepClass(
          entry.facts,
          dayClassKeys: day.dayClassKeys,
        );
        if (credit == null) continue;
        marked.add(entry);
        credits.add(credit);
      }
      return planClassCelebration(
        day: day,
        state: state,
        marked: marked,
        credits: credits,
        keptBefore: before,
        now: at,
        dayOf: (date) => _day(_fall2026, state, at, day: date),
      );
    }

    test('nothing set aside: "Three for three." leads, then what is next', () {
      final p = plan(_state());
      expect(p.tier, ClassCelebrationTier.dayDone);
      expect(p.closing.first, 'Three for three.');
      expect(p.closing, hasLength(2));
    });

    test('something set aside: only the next-class line', () {
      final p = plan(_state(), withAside: true);
      expect(p.tier, ClassCelebrationTier.dayDone);
      expect(p.closing, hasLength(1));
      expect(p.closing.single, isNot(contains(' for ')));
      expect(
        p.closing.single,
        'Friday ends late: Discrete Structures II at 5:55.',
      );
      // Nothing in the moment says what was set aside, or counts it.
      final words = [
        p.headline,
        ...p.closing,
        p.semanticsLabel,
      ].join(' ').toLowerCase();
      expect(words, isNot(contains('set aside')));
      expect(words, isNot(contains('couldn')));
    });

    test('the next-class line is the one the week already uses', () {
      Clock.freeze(at);
      final state = _state();
      final day = _day(_fall2026, state, at);
      final p = plan(state, withAside: true);
      expect(
        p.closing.single,
        nextClassDayLine(day, (date) => _day(_fall2026, state, at, day: date)),
      );
    });

    test('Friday, the week tier: "N for N" is held back too', () {
      final friday = _ny(9, 20, 0);
      Clock.freeze(friday);
      final state = _state();
      final plain = projectClassDay(_fall2026, friday);
      state.dismissClass(plain.classes.first.facts);
      final day = _day(_fall2026, state, friday);
      final before = [...state.classesKeptOn(day.dayKey)];
      final marked = <ProjectedClass>[];
      final credits = <ClassCredit>[];
      for (final entry in day.classes) {
        final credit = state.keepClass(
          entry.facts,
          dayClassKeys: day.dayClassKeys,
        );
        if (credit == null) continue;
        marked.add(entry);
        credits.add(credit);
      }
      final p = planClassCelebration(
        day: day,
        state: state,
        marked: marked,
        credits: credits,
        keptBefore: before,
        now: friday,
        dayOf: (date) => _day(_fall2026, state, friday, day: date),
      );
      expect(p.tier, ClassCelebrationTier.weekDone);
      expect(p.closing.join(' '), isNot(contains(' for ')));
    });
  });
}
