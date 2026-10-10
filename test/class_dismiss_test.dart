// "Couldn't make it": a class he set aside pays nothing, counts for nothing
// and leaves the day's class set everywhere that set is read. Never a count
// of what was set aside, never a score against it.
//
// Clocks are frozen at INSTANTS (New York wall times converted from UTC), so
// these hold on a host in any zone.
import 'dart:convert';
import 'dart:math' as math;

import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/home_widgets/widget_snapshot.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/storage.dart';
import 'package:emberkeep/widgets/class_day/class_day_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/rutgers_fall_2026_ics_fixture.dart';

/// A New York wall time in October 2026 (EDT, UTC-4) as an instant.
DateTime _ny(int day, int hour, int minute, [int second = 0]) =>
    DateTime.utc(2026, 10, day, hour + 4, minute, second).toLocal();

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

/// The day as the live save reads it (dismissed classes are out of the set).
ClassDay _day(GameState state, DateTime at, {CivilDate? day}) =>
    projectClassDay(
      _fall2026,
      at,
      day: day,
      isDismissed: state.isClassDismissed,
    );

ProjectedClass _course(ClassDay day, String code, {int? start}) =>
    day.everyClass.firstWhere(
      (entry) =>
          entry.courseCode == code &&
          (start == null || entry.localStartMinute == start),
    );

/// Everything a keep would change, in one comparable line.
String _ledger(GameState s) =>
    'xp ${s.xp}/${s.totalXp}, embers ${s.embers}, stats '
    '${s.stats.entries.map((e) => '${e.key.name}:${e.value}').join(',')}, '
    'kept ${s.totalClassesKept} ${s.keptClassCounts}, streak ${s.streakDays}/'
    '${s.bestStreak} last ${s.lastStreakDay} freezes ${s.streakFreezes}, '
    'ledger ${s.ledger.length}, achievements ${s.unlockedAchievements.length}';

GameState _reload(GameState state) => GameState.fromJson(
  jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
)..soundEnabled = false;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    Clock.reset();
    GameState.restDayResolver = null;
  });

  group('the engine', () {
    test('setting a class aside pays nothing and moves no counter', () {
      final at = _ny(8, 13, 0);
      Clock.freeze(at);
      final state = _state();
      final day = _day(state, at);
      final before = _ledger(state);
      final serial = state.rewardSerial;
      final lab = _course(day, '14:332:363');

      expect(state.dismissClass(lab.facts), isTrue);

      expect(_ledger(state), before, reason: 'no XP, stat, streak or tally');
      expect(state.isClassDismissed(lab.facts), isTrue);
      expect(state.classesDismissedOn('2026-10-08'), hasLength(1));
      expect(state.classesKeptOn('2026-10-08'), isEmpty);
      expect(state.classXpForDay('2026-10-08'), 0);
      expect(
        state.rewardSerial,
        serial + 1,
        reason: 'a whole-save undo settles',
      );
    });

    test('only a class that can still be set aside can be', () {
      final at = _ny(8, 16, 0);
      Clock.freeze(at);
      final state = _state();
      final day = _day(state, at);
      final lecture = _course(day, '14:332:361');
      final lab = _course(day, '14:332:363');

      expect(state.dismissClass(lab.facts), isTrue);
      expect(state.dismissClass(lab.facts), isFalse, reason: 'already folded');
      expect(state.classesDismissedOn('2026-10-08'), hasLength(1));

      expect(state.keepClass(lecture.facts), isNotNull);
      expect(state.dismissClass(lecture.facts), isFalse, reason: 'it was kept');
      expect(state.isClassDismissed(lecture.facts), isFalse);

      // Another night, and a class that is not one.
      final yesterday = _course(
        _day(state, at, day: CivilDate(2026, 10, 7)),
        '14:332:333',
      );
      expect(state.dismissClass(yesterday.facts), isFalse);
      expect(
        state.dismissClass(
          ClassFacts(
            courseCode: '  ',
            title: 'x',
            kind: 'lecture',
            dayKey: '2026-10-08',
            startMinute: 600,
          ),
        ),
        isFalse,
      );
    });

    test('undo puts the save back exactly, record and all', () {
      final at = _ny(8, 13, 0);
      Clock.freeze(at);
      final state = _state();
      final lab = _course(_day(state, at), '14:332:363');

      // A day that held nothing else: the record goes away entirely.
      final empty = jsonEncode(state.toJson());
      final serial = state.rewardSerial;
      expect(state.dismissClass(lab.facts), isTrue);
      expect(state.dayRecords, hasLength(1));
      expect(state.undoDismiss(lab.facts), isTrue);
      expect(state.dayRecords, isEmpty);
      expect(jsonEncode(state.toJson()), empty);
      expect(state.rewardSerial, serial + 2);
      expect(state.undoDismiss(lab.facts), isFalse, reason: 'nothing to undo');

      // A day that held a kept class: only the dismissal leaves.
      Clock.freeze(_ny(8, 16, 0));
      final lecture = _course(_day(state, _ny(8, 16, 0)), '14:332:361');
      expect(state.keepClass(lecture.facts), isNotNull);
      final kept = jsonEncode(state.toJson());
      expect(state.dismissClass(lab.facts), isTrue);
      expect(jsonEncode(state.toJson()), isNot(kept));
      expect(state.undoDismiss(lab.facts), isTrue);
      expect(jsonEncode(state.toJson()), kept);
      expect(state.classesKeptOn('2026-10-08'), hasLength(1));
    });

    test('"I was there" on a set-aside class lifts the dismissal', () {
      final at = _ny(8, 13, 0);
      Clock.freeze(at);
      final state = _state();
      final lab = _course(_day(state, at), '14:332:363');
      expect(state.dismissClass(lab.facts), isTrue);

      Clock.freeze(_ny(8, 19, 5));
      final credit = state.keepClass(
        lab.facts,
        dayClassKeys: _day(state, at).dayClassKeys,
      );
      expect(credit, isNotNull);
      expect(credit!.xp, 30, reason: 'a lab pays what a lab pays');
      expect(state.isClassDismissed(lab.facts), isFalse);
      expect(state.classesKeptOn('2026-10-08'), hasLength(1));
      expect(state.dayRecordFor('2026-10-08')!.dismissed, isEmpty);
    });

    test('a set-aside optional meeting just disappears', () {
      final at = _ny(8, 13, 0);
      Clock.freeze(at);
      final state = _state();
      final hours = ClassFacts(
        occurrenceKey: 'oh-1',
        courseCode: '14:332:345',
        title: 'Office hours',
        kind: 'officeHours',
        dayKey: '2026-10-08',
        startMinute: 16 * 60,
        startsAt: _ny(8, 16, 0).toUtc(),
        endsAt: _ny(8, 17, 0).toUtc(),
      );
      expect(ClassPay.countsTowardDay('officeHours'), isFalse);
      expect(state.dismissClass(hours), isTrue);
      expect(state.isClassDismissed(hours), isTrue);
      expect(state.classXpForDay('2026-10-08'), 0);
    });
  });

  group('persistence', () {
    test('a dismissal survives a save and a load', () {
      final at = _ny(8, 13, 0);
      Clock.freeze(at);
      final state = _state();
      final lab = _course(_day(state, at), '14:332:363');
      state.dismissClass(lab.facts);

      final json = state.toJson();
      final day = (json['dayRecords'] as List).single as Map;
      expect(day['dismissedClasses'], isA<List>());
      expect(day.containsKey('classes'), isFalse);

      final back = _reload(state);
      expect(back.isClassDismissed(lab.facts), isTrue);
      expect(
        back.classesDismissedOn('2026-10-08').single.identity,
        lab.occurrenceKey,
      );
      expect(jsonEncode(back.toJson()), jsonEncode(state.toJson()));
    });

    test('a save from before the field loads with none, and writes none', () {
      final at = _ny(8, 16, 0);
      Clock.freeze(at);
      final state = _state();
      final lecture = _course(_day(state, at), '14:332:361');
      state.keepClass(lecture.facts);

      final old =
          jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>;
      final record = (old['dayRecords'] as List).single as Map;
      expect(record.containsKey('dismissedClasses'), isFalse);
      final loaded = GameState.fromJson(old);
      expect(loaded.classesDismissedOn('2026-10-08'), isEmpty);
      expect(loaded.classesKeptOn('2026-10-08'), hasLength(1));
      expect(jsonEncode(loaded.toJson()), jsonEncode(old));
    });

    test('a damaged dismissal is dropped alone; a keep outranks it', () {
      final at = _ny(8, 16, 0);
      Clock.freeze(at);
      final state = _state();
      final day = _day(state, at);
      final lecture = _course(day, '14:332:361');
      final lab = _course(day, '14:332:363');
      state.keepClass(lecture.facts);
      state.dismissClass(lab.facts);

      final json =
          jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>;
      final record =
          (json['dayRecords'] as List).single as Map<String, dynamic>;
      (record['dismissedClasses'] as List)
        ..add({'courseCode': '', 'startMinute': 10, 'dismissedAt': 1})
        ..add('nonsense')
        ..add({'courseCode': 'X', 'startMinute': 99999, 'dismissedAt': 1})
        // A dismissal of the class that was kept: the keep wins.
        ..add({
          'occurrenceKey': lecture.occurrenceKey,
          'courseCode': lecture.courseCode,
          'startMinute': lecture.localStartMinute,
          'dismissedAt': 5,
        });
      final loaded = GameState.fromJson(json);
      expect(loaded.classesDismissedOn('2026-10-08'), hasLength(1));
      expect(loaded.isClassDismissed(lab.facts), isTrue);
      expect(loaded.isClassDismissed(lecture.facts), isFalse);
      expect(loaded.classesKeptOn('2026-10-08'), hasLength(1));
    });

    test(
      'a day that only holds a dismissal is kept, then dropped when empty',
      () {
        final record = DayRecord(
          dayKey: '2026-10-08',
          dismissed: [
            DismissedClass(
              occurrenceKey: 'a',
              courseCode: 'C',
              startMinute: 600,
              dismissedAt: DateTime.utc(2026, 10, 8),
            ),
          ],
        );
        expect(record.isEmpty, isFalse);
        expect(record.xp, 0);
        expect(DayRecord.fromJson(record.toJson())!.dismissed, hasLength(1));
        expect(DayRecord.fromJson({'dayKey': '2026-10-08'}), isNull);
        expect(
          DayRecord.fromJson({'dayKey': '2026-10-08', 'dismissedClasses': []}),
          isNull,
        );
      },
    );

    test('two copies of a day fold into one without losing a dismissal', () {
      DismissedClass dismissed(String code, int minute) => DismissedClass(
        courseCode: code,
        startMinute: minute,
        dismissedAt: DateTime.utc(2026, 10, 8, 12, minute % 60),
      );
      final merged = DayRecord.merge(
        DayRecord(dayKey: '2026-10-08', dismissed: [dismissed('A', 600)]),
        DayRecord(
          dayKey: '2026-10-08',
          dismissed: [dismissed('A', 600), dismissed('B', 700)],
        ),
      );
      expect(merged.dismissed.map((d) => d.courseCode), ['A', 'B']);
    });

    test('Extra Credit and a dismissal share a day without touching', () {
      final at = _ny(8, 13, 0);
      Clock.freeze(at);
      final state = _state();
      final lab = _course(_day(state, at), '14:332:363');
      state.dismissClass(lab.facts);
      expect(
        state.addExtraCredit('Read ahead', dayKey: '2026-10-08'),
        isNotNull,
      );
      final record = state.dayRecordFor('2026-10-08')!;
      expect(record.dismissed, hasLength(1));
      expect(record.extraCredit, isNotNull);
      expect(record.xp, GameState.extraCreditXp);
      final back = _reload(state);
      expect(back.classesDismissedOn('2026-10-08'), hasLength(1));
      expect(back.extraCreditForDay('2026-10-08'), isNotNull);
    });

    test('it rides the cloud backup: save, export, restore', () async {
      final at = _ny(8, 13, 0);
      Clock.freeze(at);
      final state = _state();
      final lab = _course(_day(state, at), '14:332:363');
      state.dismissClass(lab.facts);

      expect(await Storage.save(state, const []), isTrue);
      final raw = (await Storage.exportRaw())!;
      expect(Storage.isValidSave(raw), isTrue);
      expect(raw, contains('dismissedClasses'));

      SharedPreferences.setMockInitialValues({});
      expect(await Storage.importRaw(raw), isTrue);
      final (restored, _) = (await Storage.load())!;
      expect(restored.isClassDismissed(lab.facts), isTrue);
      expect(restored.classesDismissedOn('2026-10-08'), hasLength(1));
    });
  });

  group('the day\'s class set', () {
    test('the projection moves it to dismissed, and says nothing else', () {
      final at = _ny(8, 13, 0);
      Clock.freeze(at);
      final state = _state();
      final plain = projectClassDay(_fall2026, at);
      expect(plain.classes, hasLength(3));
      state.dismissClass(_course(plain, '14:332:363').facts);

      final day = _day(state, at);
      expect(day.classes.map((c) => c.courseCode), [
        '14:332:361',
        '01:198:206',
      ]);
      expect(day.dismissed.map((c) => c.courseCode), ['14:332:363']);
      expect(day.everyClass, hasLength(3));
      expect(day.dayClassKeys, hasLength(2));
      expect(day.lastClassEnd, day.classes.last.endsAt);
      // Applying it again, or from the lookup side, changes nothing.
      expect(
        identical(day.withoutDismissed(state.isClassDismissed), day),
        isTrue,
      );
      final lateFiltered = plain.withoutDismissed(state.isClassDismissed);
      expect(lateFiltered.classes.length, 2);
      expect(lateFiltered.dismissed.length, 1);
      expect(lateFiltered.lastClassEnd, day.lastClassEnd);
    });

    test('a day with every class set aside is not a class day', () {
      final at = _ny(6, 9, 0);
      Clock.freeze(at);
      final state = _state();
      final plain = projectClassDay(_fall2026, at);
      expect(plain.isClassDay, isTrue);
      for (final entry in plain.classes) {
        expect(state.dismissClass(entry.facts), isTrue);
      }
      final day = _day(state, at);
      expect(day.isClassDay, isFalse);
      expect(day.classes, isEmpty);
      expect(day.dayClassKeys, isEmpty);
      expect(day.lastClassEnd, isNull);
      expect(day.dismissed, hasLength(plain.classes.length));
    });

    test('the next class skips a class that was set aside', () {
      final at = _ny(7, 20, 0);
      Clock.freeze(at);
      final state = _state();
      final thursday = projectClassDay(
        _fall2026,
        at,
        day: CivilDate(2026, 10, 8),
      );
      final electronics = _course(thursday, '14:332:361');
      expect(
        projectClassDay(_fall2026, at).nextClassAfter!.entry.occurrenceKey,
        electronics.occurrenceKey,
      );
      Clock.freeze(_ny(8, 7, 0));
      state.dismissClass(electronics.facts);
      final next = _day(state, _ny(7, 20, 0)).nextClassAfter!;
      expect(next.entry.courseCode, '01:198:206');
    });

    test('the boundaries the card waits on leave the set-aside class out', () {
      final at = _ny(5, 10, 0);
      Clock.freeze(at);
      final state = _state();
      final plain = projectClassDay(_fall2026, at);
      final evening = _course(plain, '14:332:345', start: 17 * 60 + 40);
      expect(nextClassBoundary(plain, _ny(5, 16, 0)), isNotNull);
      state.dismissClass(evening.facts);
      final day = _day(state, at);
      // Nothing is left to wait for after the afternoon lecture's end,
      // except the night's own end and the wind-down.
      DateTime? best = nextClassBoundary(day, _ny(5, 15, 30));
      expect(best, isNot(evening.startsAt));
      expect(best, isNot(evening.endsAt));
    });
  });

  group('the rest-day pause', () {
    ClassFacts monday() =>
        _course(_day(_state(), _ny(5, 12, 0)), '14:332:361').facts;

    test('a term day whose every class was set aside is a rest day', () {
      final at = _ny(6, 9, 0);
      Clock.freeze(at);
      final state = _state();
      final tuesday = projectClassDay(_fall2026, at);
      expect(restDayFor(_fall2026, '2026-10-06'), isFalse);
      expect(
        restDayFor(
          _fall2026,
          '2026-10-06',
          isDismissed: state.isClassDismissed,
        ),
        isFalse,
      );
      state.dismissClass(tuesday.classes.first.facts);
      expect(
        restDayFor(
          _fall2026,
          '2026-10-06',
          isDismissed: state.isClassDismissed,
        ),
        isFalse,
        reason: 'one class still holds the day',
      );
      state.dismissClass(tuesday.classes.last.facts);
      expect(
        restDayFor(
          _fall2026,
          '2026-10-06',
          isDismissed: state.isClassDismissed,
        ),
        isTrue,
      );
      state.undoDismiss(tuesday.classes.last.facts);
      expect(
        restDayFor(
          _fall2026,
          '2026-10-06',
          isDismissed: state.isClassDismissed,
        ),
        isFalse,
        reason: 'bringing one back ends the pause',
      );
    });

    test('the streak pauses over it and never breaks', () {
      GameState run({required bool dismissTuesday}) {
        final state = _state();
        GameState.restDayResolver = (key) =>
            restDayFor(_fall2026, key, isDismissed: state.isClassDismissed);
        Clock.freeze(_ny(5, 10, 30));
        expect(
          state.keepClass(monday(), dayClassKeys: const []),
          isNotNull,
          reason: 'Monday lights the streak',
        );
        expect(state.streakDays, 1);

        Clock.freeze(_ny(6, 9, 0));
        if (dismissTuesday) {
          for (final entry in projectClassDay(
            _fall2026,
            _ny(6, 9, 0),
          ).classes) {
            expect(state.dismissClass(entry.facts), isTrue);
          }
        }

        Clock.freeze(_ny(7, 10, 0));
        final wednesday = projectClassDay(_fall2026, _ny(7, 10, 0));
        final credit = state.keepClass(wednesday.classes.first.facts);
        expect(credit!.streak.lit, isTrue);
        expect(state.streakDays, 2);
        return state;
      }

      final paused = run(dismissTuesday: true);
      expect(
        paused.streakFreezes,
        GameState.starterStreakFreezes,
        reason: 'a rest day spends no freeze',
      );
      expect(paused.frozenStreakDays, isEmpty);

      final held = run(dismissTuesday: false);
      expect(
        held.streakFreezes,
        GameState.starterStreakFreezes - 1,
        reason: 'the same gap without the dismissal needed a freeze',
      );
      expect(held.frozenStreakDays, {'2026-10-06'});
    });

    test('setting a class aside is not a streak day by itself', () {
      GameState.restDayResolver = null;
      Clock.freeze(_ny(6, 9, 0));
      final state = _state();
      final before = _ledger(state);
      for (final entry in projectClassDay(_fall2026, _ny(6, 9, 0)).classes) {
        state.dismissClass(entry.facts);
      }
      expect(_ledger(state), before);
      expect(state.lastStreakDay, isNull);
    });
  });

  group('completion and the plans', () {
    test('the day completes without the class he could not make', () {
      final at = _ny(8, 16, 0);
      Clock.freeze(at);
      final state = _state();
      final plain = projectClassDay(_fall2026, at);
      state.dismissClass(_course(plain, '14:332:363').facts);
      final day = _day(state, at);
      final credits = [
        for (final entry in day.classes)
          state.keepClass(entry.facts, dayClassKeys: day.dayClassKeys)!,
      ];
      expect(credits.last.dayComplete, isTrue);
      expect(credits.last.fullDayBonus, ClassPay.fullDayBonusXp);
      expect(credits.last.dayClassCount, 2);
      expect(credits.first.fullDayBonus, 0);
      expect(state.classXpForDay('2026-10-08'), 25 + 25 + 10);
      expect(ClassCard.read(day, state, at).allKept, isTrue);
    });

    test('the same two keeps with all three scheduled do not complete it', () {
      final at = _ny(8, 16, 0);
      Clock.freeze(at);
      final state = _state();
      final day = projectClassDay(_fall2026, at);
      final credits = [
        for (final entry in day.classes.take(2))
          state.keepClass(entry.facts, dayClassKeys: day.dayClassKeys)!,
      ];
      expect(credits.last.dayComplete, isFalse);
      expect(credits.last.fullDayBonus, 0);
    });

    test('keeping a class after setting it aside is judged with its day', () {
      final at = _ny(8, 16, 0);
      Clock.freeze(at);
      final state = _state();
      final plain = projectClassDay(_fall2026, at);
      final lab = _course(plain, '14:332:363');
      state.dismissClass(lab.facts);
      final day = _day(state, at);
      for (final entry in day.classes) {
        state.keepClass(entry.facts, dayClassKeys: day.dayClassKeys);
      }
      expect(state.dayRecordFor('2026-10-08')!.fullDayBonusXp, 10);

      // Then the lab after all: the bonus is already paid and stays paid, the
      // class itself pays, and nothing doubles.
      Clock.freeze(_ny(8, 19, 0));
      final credit = state.keepClass(lab.facts, dayClassKeys: day.dayClassKeys);
      expect(credit!.fullDayBonus, 0);
      expect(state.classesKeptOn('2026-10-08'), hasLength(3));
      expect(state.dayRecordFor('2026-10-08')!.fullDayBonusXp, 10);
    });

    ClassCelebrationPlan plan(GameState state, DateTime at, ClassDay day) {
      final keptBefore = [...state.classesKeptOn(day.dayKey)];
      final marked = <ProjectedClass>[];
      final credits = <ClassCredit>[];
      for (final entry in day.classes) {
        if (state.keptClassFor(entry.facts) != null) continue;
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
        keptBefore: keptBefore,
        now: at,
        dayOf: (date) => _day(state, at, day: date),
      );
    }

    test('the day tier counts the day without it and never says how many', () {
      final at = _ny(8, 16, 0);
      Clock.freeze(at);
      final state = _state();
      state.dismissClass(
        _course(projectClassDay(_fall2026, at), '14:332:363').facts,
      );
      final day = _day(state, at);
      final p = plan(state, at, day);

      expect(p.tier, ClassCelebrationTier.dayDone);
      expect(p.headline, 'THURSDAY, DONE.');
      expect(p.closing.first, 'Two for two.');
      expect(p.bonusXp, 10);
      expect(p.bonusLine, "All of Thursday's classes");
      expect(p.rows, hasLength(2));
      expect(p.numeral, 2);
      final words = [
        p.headline,
        p.numeralLabel,
        p.caption ?? '',
        p.semanticsLabel,
        ...p.closing,
        for (final row in p.rows) row.title,
      ].join(' ').toLowerCase();
      expect(words, isNot(contains('three')));
      expect(words, isNot(contains(' of ')));
      expect(words, isNot(contains('couldn')));
      expect(words, isNot(contains('set aside')));
    });

    test('the week ends on the last class day that still has a class', () {
      // Friday's classes are both set aside, so Thursday is the week's last
      // class day and its day tier is the week tier.
      final at = _ny(8, 19, 5);
      Clock.freeze(_ny(8, 8, 0));
      final state = _state();
      for (final entry in projectClassDay(
        _fall2026,
        at,
        day: CivilDate(2026, 10, 9),
      ).classes) {
        Clock.freeze(_ny(9, 8, 0));
        expect(state.dismissClass(entry.facts), isTrue);
      }
      Clock.freeze(at);
      final day = _day(state, at);
      final p = plan(state, at, day);
      expect(p.tier, ClassCelebrationTier.weekDone);
      expect(p.headline, "THAT'S THE WEEK.");
    });

    test('with Friday standing, Thursday is only the day tier', () {
      final at = _ny(8, 19, 5);
      Clock.freeze(at);
      final state = _state();
      final p = plan(state, at, _day(state, at));
      expect(p.tier, ClassCelebrationTier.dayDone);
    });

    test('week closing lines count what he attended, not what was due', () {
      final at = _ny(9, 19, 0);
      final state = _state();
      Clock.freeze(_ny(5, 20, 0));
      for (final entry in projectClassDay(_fall2026, _ny(5, 20, 0)).classes) {
        state.keepClass(entry.facts);
      }
      Clock.freeze(at);
      // Friday: the 10:20 lecture is set aside, the evening one is kept.
      final friday = projectClassDay(_fall2026, at);
      state.dismissClass(friday.classes.first.facts);
      final day = _day(state, at);
      final p = plan(state, at, day);
      expect(p.tier, ClassCelebrationTier.weekDone);
      final line = p.closing.join(' ');
      expect(line, isNot(contains('Four for four')));
      expect(line.toLowerCase(), isNot(contains('of')));
    });
  });

  group('the evening, the wind-down and the board', () {
    test('a day whose remaining classes are kept is an evening once over', () {
      final at = _ny(6, 12, 0);
      Clock.freeze(at);
      final state = _state();
      final plain = projectClassDay(_fall2026, at);
      expect(classEveningAt(ClassCard.read(plain, state, at), at), isFalse);
      expect(classDayLetsBoardCloseDay(plain, state, at), isFalse);

      state.dismissClass(_course(plain, '01:198:206').facts);
      final day = _day(state, at);
      state.keepClass(day.classes.single.facts, dayClassKeys: day.dayClassKeys);
      final card = ClassCard.read(day, state, at);
      expect(card.allKept, isTrue);
      expect(classEveningAt(card, at), isTrue);
      expect(classDayLetsBoardCloseDay(day, state, at), isTrue);
    });

    test(
      'the board waits while a class is still to come, dismissed or not',
      () {
        final at = _ny(6, 12, 0);
        Clock.freeze(at);
        final state = _state();
        final day = _day(state, at);
        state.keepClass(
          day.classes.first.facts,
          dayClassKeys: day.dayClassKeys,
        );
        expect(classDayLetsBoardCloseDay(day, state, at), isFalse);
      },
    );

    test('the wind-down comes when the last class that remains is over', () {
      final at = _ny(5, 17, 10);
      Clock.freeze(at);
      final state = _state();
      final plain = projectClassDay(_fall2026, at);
      expect(
        classWindDown(plain, at),
        isFalse,
        reason: 'the 5:40 lecture is on',
      );
      state.dismissClass(
        _course(plain, '14:332:345', start: 17 * 60 + 40).facts,
      );
      final day = _day(state, at);
      expect(classWindDown(day, at), isTrue);
      expect(classWindDownStart(day), isNot(plain.lastClassEnd));
      expect(classDayLetsBoardCloseDay(day, state, at), isTrue);
    });

    test('a day of nothing but set-aside classes lets the board close it', () {
      final at = _ny(6, 12, 0);
      Clock.freeze(at);
      final state = _state();
      for (final entry in projectClassDay(_fall2026, at).classes) {
        state.dismissClass(entry.facts);
      }
      final day = _day(state, at);
      expect(classDayLetsBoardCloseDay(day, state, at), isTrue);
      expect(classEveningAt(ClassCard.read(day, state, at), at), isFalse);
    });
  });

  group('the night ledger and the journal', () {
    test('only kept classes are named', () {
      final at = _ny(8, 21, 0);
      Clock.freeze(_ny(8, 16, 0));
      final state = _state();
      final plain = projectClassDay(_fall2026, _ny(8, 16, 0));
      state.dismissClass(_course(plain, '14:332:363').facts);
      final day = _day(state, _ny(8, 16, 0));
      state.keepClass(day.classes.first.facts);
      Clock.freeze(at);
      final trace = state.journalTraceFor(const [], '2026-10-08');
      expect(trace.classTitles, ['Electronics Devices']);
      expect(state.classTitlesForDay('2026-10-08'), ['Electronics Devices']);
    });

    test('tomorrow\'s classes for the ledger tray leave it out', () {
      final at = _ny(7, 21, 0);
      Clock.freeze(at);
      final state = _state();
      final thursday = CivilDate(2026, 10, 8);
      final plain = projectClassDay(_fall2026, at, day: thursday);
      Clock.freeze(_ny(8, 7, 30));
      state.dismissClass(_course(plain, '14:332:361').facts);
      final tray = _day(state, at, day: thursday);
      expect(tray.classes.map((c) => c.courseCode), [
        '01:198:206',
        '14:332:363',
      ]);
    });
  });

  group('the Day Ledger widget', () {
    WidgetSnapshot snapshot(GameState state, DateTime at) =>
        WidgetSnapshotBuilder.build(
          quests: const [],
          schedule: _fall2026,
          now: at,
          state: state,
          classDayMarks: true,
        );

    test('a set-aside class is never shown as waiting, or as coming', () {
      final at = _ny(8, 16, 0);
      Clock.freeze(at);
      final state = _state();
      final plain = projectClassDay(_fall2026, at);
      final lab = _course(plain, '14:332:363');
      final before = snapshot(state, at);
      expect(before.classDays.first.classes, hasLength(3));
      expect(
        before.upcomingClasses.map((c) => c.occurrenceKey),
        contains(lab.occurrenceKey),
      );

      state.dismissClass(lab.facts);
      final after = snapshot(state, at);
      final today = after.classDays.first;
      expect(
        today.classes.map((c) => c.occurrenceKey),
        isNot(contains(lab.occurrenceKey)),
      );
      expect(today.classes, hasLength(2));
      expect(
        after.upcomingClasses.map((c) => c.occurrenceKey),
        isNot(contains(lab.occurrenceKey)),
      );
      expect(
        today.lastClassEndsAt,
        projectClassDay(_fall2026, at).classes[1].endsAt.toUtc(),
      );
      expect(jsonEncode(after.toJson()), isNot(contains(lab.occurrenceKey)));
    });

    test('the day is complete on the widget when the rest are kept', () {
      final at = _ny(8, 16, 0);
      Clock.freeze(at);
      final state = _state();
      state.dismissClass(
        _course(projectClassDay(_fall2026, at), '14:332:363').facts,
      );
      for (final entry in _day(state, at).classes) {
        state.keepClass(entry.facts);
      }
      final today = snapshot(state, at).classDays.first;
      expect(today.allKept, isTrue);
      expect(today.attendedShort, isNotNull);
    });

    test('a day of only set-aside classes is not on the widget at all', () {
      final at = _ny(6, 9, 0);
      Clock.freeze(at);
      final state = _state();
      for (final entry in projectClassDay(_fall2026, at).classes) {
        state.dismissClass(entry.facts);
      }
      final days = snapshot(state, at).classDays;
      expect(days.map((d) => d.dayKey), isNot(contains('2026-10-06')));
    });
  });
}
