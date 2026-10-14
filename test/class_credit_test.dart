import 'dart:convert';
import 'dart:math';

import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/storage.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pure engine tests. The clock is frozen with local DateTimes and class
/// start instants are built the same way, so every comparison is between
/// values made on the same host: no test here depends on the host's zone.

const _tue = '2026-10-06';
const _wed = '2026-10-07';

ClassFacts _architecture({
  String day = _tue,
  String? key = 'occ-331-1006',
  DateTime? startsAt,
}) => ClassFacts(
  occurrenceKey: key,
  courseCode: '14:332:331',
  title: 'Computer Architecture & Assembly Language',
  kind: 'lecture',
  dayKey: day,
  startMinute: 620,
  startsAt: startsAt ?? DateTime(2026, 10, 6, 10, 20),
  endsAt: DateTime(2026, 10, 6, 11, 40),
);

ClassFacts _discrete({String? key = 'occ-206-1006'}) => ClassFacts(
  occurrenceKey: key,
  courseCode: '01:198:206',
  title: 'Discrete Structures II',
  kind: 'lecture',
  dayKey: _tue,
  startMinute: 840,
  startsAt: DateTime(2026, 10, 6, 14),
  endsAt: DateTime(2026, 10, 6, 15, 20),
);

ClassFacts _archLab() => ClassFacts(
  occurrenceKey: 'occ-333-1007',
  courseCode: '14:332:333',
  title: 'Computer Architecture Lab',
  kind: 'lab',
  dayKey: _wed,
  startMinute: 510,
  startsAt: DateTime(2026, 10, 7, 8, 30),
  endsAt: DateTime(2026, 10, 7, 11, 30),
);

final _tuesdayKeys = ['occ-331-1006', 'occ-206-1006'];

/// Quest-only keys a class keep must never touch.
const _questKeys = [
  'totalCompletions',
  'completionsAtLastLevel',
  'history',
  'todayXp',
  'todayStats',
  'todayQuestTitles',
  'todayTitleCounts',
  'todayLootDrops',
  'lastCompletionDay',
  'lastStreakDay',
  'streakDays',
  'bestStreak',
  'streakShields',
  'streakFreezeProgress',
  'frozenStreakDays',
  'goals',
  'perfectDays',
  'lastPerfectDay',
  'verifiedCompletions',
  'dreadCompletions',
  'epicCompletions',
  'eventCompletions',
  'customCompletions',
  'comebacks',
  'dawnCompletions',
  'duskCompletions',
  'level',
];

GameState _reload(GameState state) => GameState.fromJson(
  jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
);

class _NoLuck implements Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.999;
  @override
  int nextInt(int max) => 0;
}

void main() {
  tearDown(() {
    Clock.reset();
    ClassDayRules.debugOverride = null;
    GameState.restDayResolver = null;
  });

  group('pay', () {
    test('a lecture pays 25 XP, 3 Intellect and Glimmers like a Quest', () {
      Clock.freeze(DateTime(2026, 10, 6, 11, 52));
      final state = GameState()..embers = 4;

      final credit = state.keepClass(_architecture());

      expect(credit, isNotNull);
      expect(credit!.xp, 25);
      expect(credit.classXp, 25);
      expect(credit.fullDayBonus, 0);
      expect(credit.stat, Stat.intl);
      expect(credit.statGain, 3);
      expect(credit.glimmers, 8);
      expect(state.xp, 25);
      expect(state.totalXp, 25);
      expect(state.embers, 12);
      expect(state.stats[Stat.intl], 3);
      expect(
        state.ledger.first.title,
        'Computer Architecture & Assembly Language',
      );
      expect(state.ledger.first.stat, Stat.intl);
      expect(state.ledger.first.amount, 3);
      expect(credit.kept.kind, 'lecture');
      expect(credit.kept.keptAt.isUtc, isTrue);
      expect(
        credit.streak.lit,
        isTrue,
        reason: 'a class day lights the streak',
      );
    });

    test('a lab or studio pays 30 XP and 5 Focus; others pay as lectures', () {
      Clock.freeze(DateTime(2026, 10, 7, 12));
      final state = GameState();
      final lab = state.keepClass(_archLab())!;
      expect(lab.xp, 30);
      expect(lab.stat, Stat.foc);
      expect(lab.statGain, 5);
      expect(lab.glimmers, 10);
      expect(state.stats[Stat.foc], 5);

      for (final kind in ['studio']) {
        expect(ClassPay.forKind(kind).xp, 30);
        expect(ClassPay.forKind(kind).stat, Stat.foc);
      }
      for (final kind in [
        'lecture',
        'recitation',
        'seminar',
        'officeHours',
        '',
      ]) {
        expect(ClassPay.forKind(kind).xp, 25);
        expect(ClassPay.forKind(kind).stat, Stat.intl);
        expect(ClassPay.forKind(kind).statGain, 3);
      }
    });

    test('pay is deterministic on an unseeded state', () {
      for (var i = 0; i < 25; i++) {
        Clock.freeze(DateTime(2026, 10, 6, 12));
        expect(GameState().keepClass(_architecture())!.xp, 25);
      }
    });

    test('never touches Quest counters, history or the Quest-only buckets', () {
      // The streak keys are covered by class_day_streak_test now that a class
      // day lights the streak; here the rules are off so they stay pinned.
      ClassDayRules.debugOverride = const ClassDayRules(
        classDayLightsStreak: false,
        restDaysPause: false,
      );
      addTearDown(() => ClassDayRules.debugOverride = null);
      Clock.freeze(DateTime(2026, 10, 6, 15, 35));
      final state = GameState()
        ..lastActiveDay = _tue
        ..streakDays = 4
        ..bestStreak = 9
        ..lastCompletionDay = '2026-10-05'
        ..totalCompletions = 12
        ..history[_tue] = 1
        ..todayXp = 42
        ..todayStats[Stat.vit] = 3
        ..todayQuestTitles.add('Drink water')
        ..todayTitleCounts['Drink water'] = 1;
      final before = state.toJson();

      state.keepClass(_architecture(), dayClassKeys: _tuesdayKeys);
      state.keepClass(_discrete(), dayClassKeys: _tuesdayKeys);

      final after = state.toJson();
      for (final key in _questKeys) {
        expect(after[key], before[key], reason: key);
      }
      expect(state.todayXp, 42, reason: 'class XP stays out of the soft cap');
    });

    test('a long course title keeps a short label snapshot', () {
      Clock.freeze(DateTime(2026, 10, 6, 12));
      final state = GameState();
      final credit = state.keepClass(
        ClassFacts(
          courseCode: 'HIST 101',
          title:
              'An Unusually Long Course Title That Goes On Well Past Any Card Width',
          kind: 'lecture',
          dayKey: _tue,
          startMinute: 600,
        ),
      )!;
      expect(credit.label.characters.length, lessThanOrEqualTo(48));
      expect(credit.label, startsWith('An Unusually Long Course Title'));
      expect(
        GameState()
            .keepClass(
              ClassFacts(
                courseCode: 'HIST 101',
                title: '   ',
                kind: 'lecture',
                dayKey: _tue,
                startMinute: 600,
              ),
            )!
            .label,
        'HIST 101',
      );
    });
  });

  group('dedupe and window', () {
    test('one keep per occurrence, by key or by course and start', () {
      Clock.freeze(DateTime(2026, 10, 6, 12));
      final state = GameState();
      expect(state.keepClass(_architecture()), isNotNull);
      final xp = state.totalXp;

      expect(state.keepClass(_architecture()), isNull);
      expect(state.keepClass(_architecture(key: null)), isNull);
      expect(state.keepClass(_architecture(key: 'reimported-key')), isNull);
      expect(state.checkClassKeep(_architecture()), ClassKeepCheck.alreadyKept);
      expect(state.totalXp, xp);
      expect(state.classesKeptOn(_tue), hasLength(1));
      expect(state.keptClassFor(_architecture(key: null)), isNotNull);
    });

    test('the window is the class day while it is the current night', () {
      Clock.freeze(DateTime(2026, 10, 5, 22));
      final state = GameState();
      expect(
        state.checkClassKeep(_architecture()),
        ClassKeepCheck.outsideWindow,
        reason: 'tomorrow is not tonight',
      );

      Clock.freeze(DateTime(2026, 10, 7, 1, 30));
      expect(
        state.checkClassKeep(_architecture()),
        ClassKeepCheck.open,
        reason: 'before 4am the night still belongs to Tuesday',
      );

      Clock.freeze(DateTime(2026, 10, 7, 4, 1));
      expect(state.keepClass(_architecture()), isNull);
      expect(
        state.checkClassKeep(_architecture()),
        ClassKeepCheck.outsideWindow,
      );
    });

    test('the window follows the timetable zone, not the phone', () {
      // ECE 345 on Monday, 5:40 to 7:00 PM in New York (EDT, UTC-4). Its
      // night ends at 04:00 EDT Tuesday, 08:00 UTC. Every moment below is an
      // instant, so the answers are the same on a host in any zone.
      ClassFacts signals({DateTime? nightEndsAt}) => ClassFacts(
        occurrenceKey: 'occ-345-1005-1060',
        courseCode: '14:332:345',
        title: 'Linear Systems & Signals',
        kind: 'lecture',
        dayKey: '2026-10-05',
        startMinute: 1060,
        startsAt: DateTime.utc(2026, 10, 5, 21, 40),
        endsAt: DateTime.utc(2026, 10, 5, 23),
        nightEndsAt: nightEndsAt,
      );
      final nightEnd = DateTime.utc(2026, 10, 6, 8);
      expect(
        GameState.classNightEnd(signals()),
        nightEnd,
        reason: 'worked out from the start and its local minute',
      );
      expect(GameState.classNightEnd(signals(nightEndsAt: nightEnd)), nightEnd);

      for (final facts in [signals(), signals(nightEndsAt: nightEnd)]) {
        final state = GameState();
        // A phone on UTC (or UTC+8, where it is already Tuesday morning)
        // reads Tuesday's night; the class is still Monday's to keep.
        final phoneOnUtc = DateTime.utc(2026, 10, 6, 6, 30);
        expect(Days.nightKey(phoneOnUtc), '2026-10-06');
        Clock.freeze(phoneOnUtc);
        expect(state.checkClassKeep(facts), ClassKeepCheck.open);
        Clock.freeze(phoneOnUtc.toLocal());
        expect(state.checkClassKeep(facts), ClassKeepCheck.open);

        Clock.freeze(DateTime.utc(2026, 10, 5, 21, 24).toLocal());
        expect(state.checkClassKeep(facts), ClassKeepCheck.notStartedYet);
        Clock.freeze(DateTime.utc(2026, 10, 5, 7, 59).toLocal());
        expect(
          state.checkClassKeep(facts),
          ClassKeepCheck.outsideWindow,
          reason: 'before its own day began',
        );
        Clock.freeze(DateTime.utc(2026, 10, 6, 8));
        expect(
          state.checkClassKeep(facts),
          ClassKeepCheck.outsideWindow,
          reason: 'its night is over',
        );

        // A queued mark made in class counts for two more nights.
        final madeInClass = DateTime.utc(2026, 10, 5, 22);
        Clock.freeze(DateTime.utc(2026, 10, 8, 7, 59).toLocal());
        expect(
          state.checkClassKeep(facts, at: madeInClass),
          ClassKeepCheck.open,
        );
        Clock.freeze(DateTime.utc(2026, 10, 8, 8).toLocal());
        expect(
          state.checkClassKeep(facts, at: madeInClass),
          ClassKeepCheck.outsideWindow,
        );
        Clock.freeze(DateTime.utc(2026, 10, 7, 12).toLocal());
        expect(
          state.checkClassKeep(facts, at: DateTime.utc(2026, 10, 6, 8, 30)),
          ClassKeepCheck.outsideWindow,
          reason: 'made after its night ended',
        );

        Clock.freeze(phoneOnUtc);
        final credit = state.keepClass(facts)!;
        expect(credit.dayKey, '2026-10-05');
        expect(state.classesKeptOn('2026-10-05'), hasLength(1));
      }
    });

    test('facts without a usable start fall back to the phone night', () {
      Clock.freeze(DateTime(2026, 10, 6, 12));
      final state = GameState();
      // A start seven minutes off its local minute is no real zone offset.
      final skewed = ClassFacts(
        courseCode: 'X 1',
        title: 'Skewed',
        kind: 'lecture',
        dayKey: _tue,
        startMinute: 600,
        startsAt: DateTime(2026, 10, 6, 10, 7),
      );
      expect(GameState.classNightEnd(skewed), isNull);
      expect(state.checkClassKeep(skewed), ClassKeepCheck.open);
      Clock.freeze(DateTime(2026, 10, 7, 4, 1));
      expect(state.checkClassKeep(skewed), ClassKeepCheck.outsideWindow);
    });

    test('a class cannot be kept before it is about to start', () {
      Clock.freeze(DateTime(2026, 10, 6, 9, 50));
      final state = GameState();
      expect(
        state.checkClassKeep(_architecture()),
        ClassKeepCheck.notStartedYet,
      );
      expect(state.keepClass(_architecture()), isNull);

      Clock.freeze(DateTime(2026, 10, 6, 10, 6));
      expect(state.keepClass(_architecture()), isNotNull);
    });

    test(
      'a queued mark counts up to two nights back, made on its own night',
      () {
        Clock.freeze(DateTime(2026, 10, 8, 9));
        final state = GameState();

        expect(
          state.checkClassKeep(_architecture()),
          ClassKeepCheck.outsideWindow,
        );
        final markedTuesday = DateTime(2026, 10, 6, 15, 25);
        final credit = state.keepClass(_architecture(), at: markedTuesday);
        expect(credit, isNotNull);
        expect(credit!.kept.keptAt, markedTuesday.toUtc());
        expect(state.classesKeptOn(_tue), hasLength(1));

        // Made after Tuesday's night ended: not a Tuesday mark.
        expect(
          state.checkClassKeep(_discrete(), at: DateTime(2026, 10, 7, 9)),
          ClassKeepCheck.outsideWindow,
        );
        // A mark from the future is refused.
        expect(
          state.checkClassKeep(_discrete(), at: DateTime(2026, 10, 8, 18)),
          ClassKeepCheck.outsideWindow,
        );
        // Three nights back is past the bounded path.
        Clock.freeze(DateTime(2026, 10, 9, 9));
        expect(
          state.checkClassKeep(_discrete(), at: DateTime(2026, 10, 6, 15, 25)),
          ClassKeepCheck.outsideWindow,
        );
      },
    );

    test('a long course code is stored short and still keeps once', () {
      Clock.freeze(DateTime(2026, 10, 6, 12));
      final state = GameState();
      const typed = 'Introduction to Computer Architecture and Lab';
      expect(typed.length, greaterThan(KeptClass.maxCodeLength));
      const facts = ClassFacts(
        courseCode: '  $typed ',
        title: '',
        kind: 'lecture',
        dayKey: _tue,
        startMinute: 600,
      );
      expect(state.checkClassKeep(facts), ClassKeepCheck.open);
      final credit = state.keepClass(facts, dayClassKeys: [facts.identity])!;
      final stored = credit.kept.courseCode;
      expect(stored.length, lessThanOrEqualTo(KeptClass.maxCodeLength));
      expect(typed, startsWith(stored));
      expect(credit.courseCount, 1);
      expect(credit.dayComplete, isTrue, reason: 'one identity for both');
      expect(credit.fullDayBonus, ClassPay.fullDayBonusXp);
      expect(state.keptCountForCourse(typed), 1);
      expect(state.keepClass(facts), isNull);
      expect(state.checkClassKeep(facts), ClassKeepCheck.alreadyKept);

      final restored = _reload(state);
      expect(restored.classesKeptOn(_tue), hasLength(1));
      expect(restored.keptCountForCourse(typed), 1);
      expect(restored.checkClassKeep(facts), ClassKeepCheck.alreadyKept);

      // A cut never splits a letter from its accent.
      final accented = 'e\u0301' * 30;
      final cut = KeptClass.cleanCode(accented)!;
      expect(cut.length, lessThanOrEqualTo(KeptClass.maxCodeLength));
      expect(cut.characters.every((g) => g == 'e\u0301'), isTrue);
      expect(KeptClass.cleanCode('   '), isNull);
      expect(KeptClass.cleanCode(' ECE 345 '), 'ECE 345');
    });

    test('a day holds at most the classes a save can prove', () {
      Clock.freeze(DateTime(2026, 10, 6, 23));
      final state = GameState();
      ClassFacts nth(int i) => ClassFacts(
        occurrenceKey: 'occ-$i',
        courseCode: 'C$i',
        title: 'Class $i',
        kind: 'lecture',
        dayKey: _tue,
        startMinute: i * 10,
      );
      for (var i = 0; i < DayRecord.maxClassesPerDay; i++) {
        expect(state.keepClass(nth(i)), isNotNull, reason: 'class $i');
      }
      final xp = state.totalXp;
      final extra = nth(DayRecord.maxClassesPerDay);
      expect(state.checkClassKeep(extra), ClassKeepCheck.dayFull);
      expect(state.keepClass(extra), isNull);
      expect(state.totalXp, xp);

      final restored = _reload(state);
      expect(
        restored.classesKeptOn(_tue),
        hasLength(DayRecord.maxClassesPerDay),
      );
      for (var i = 0; i <= DayRecord.maxClassesPerDay; i++) {
        expect(restored.keepClass(nth(i)), isNull, reason: 'class $i');
      }
      expect(restored.totalXp, xp, reason: 'nothing is paid twice');
    });

    test('malformed facts are refused without throwing', () {
      Clock.freeze(DateTime(2026, 10, 6, 12));
      final state = GameState();
      for (final facts in [
        const ClassFacts(
          courseCode: ' ',
          title: 'x',
          kind: 'lecture',
          dayKey: _tue,
          startMinute: 600,
        ),
        const ClassFacts(
          courseCode: 'A',
          title: 'x',
          kind: 'lecture',
          dayKey: '2026-02-31',
          startMinute: 600,
        ),
        const ClassFacts(
          courseCode: 'A',
          title: 'x',
          kind: 'lecture',
          dayKey: _tue,
          startMinute: 1440,
        ),
      ]) {
        expect(state.checkClassKeep(facts), ClassKeepCheck.invalid);
        expect(state.keepClass(facts), isNull);
      }
      expect(state.totalXp, 0);
    });
  });

  group('full-day bonus and counters', () {
    test('the keep that completes the day pays +10 once', () {
      Clock.freeze(DateTime(2026, 10, 6, 15, 35));
      final state = GameState();

      final first = state.keepClass(
        _architecture(),
        dayClassKeys: _tuesdayKeys,
      )!;
      expect(first.dayComplete, isFalse);
      expect(first.fullDayBonus, 0);
      expect(first.keptToday, 1);
      expect(first.dayClassCount, 2);

      final second = state.keepClass(_discrete(), dayClassKeys: _tuesdayKeys)!;
      expect(second.dayComplete, isTrue);
      expect(second.fullDayBonus, ClassPay.fullDayBonusXp);
      expect(second.xp, 35);
      expect(second.classXp, 25);
      expect(second.glimmers, 11);
      expect(second.keptToday, 2);
      expect(state.dayRecordFor(_tue)!.fullDayBonusXp, 10);
      expect(state.classXpForDay(_tue), 60);
      expect(state.totalXp, 60);
    });

    test('a day already complete never pays the bonus again', () {
      Clock.freeze(DateTime(2026, 10, 6, 15, 35));
      final state = GameState();
      state.keepClass(_architecture(), dayClassKeys: ['occ-331-1006']);
      expect(state.dayRecordFor(_tue)!.fullDayBonusXp, 10);
      final later = state.keepClass(
        _discrete(),
        dayClassKeys: ['occ-331-1006'],
      );
      expect(later!.fullDayBonus, 0);
      expect(later.dayComplete, isTrue);
      expect(state.classXpForDay(_tue), 60);
      // No keys: no bonus and no claim about the day.
      Clock.freeze(DateTime(2026, 10, 7, 12));
      final unknownDay = state.keepClass(_archLab())!;
      expect(unknownDay.dayComplete, isFalse);
      expect(unknownDay.fullDayBonus, 0);
      expect(unknownDay.dayClassCount, 0);
    });

    test('fallback identities complete a day without occurrence keys', () {
      Clock.freeze(DateTime(2026, 10, 6, 15, 35));
      final state = GameState();
      final keys = ['14:332:331@620', '01:198:206@840'];
      state.keepClass(_architecture(key: null), dayClassKeys: keys);
      final last = state.keepClass(_discrete(key: null), dayClassKeys: keys)!;
      expect(last.fullDayBonus, 10);
    });

    test('two meetings of one course on one day keep apart', () {
      // His Monday: ECE 361 at 8:30, then ECE 345 at 2:00 and again at 5:40.
      for (final keyed in [true, false]) {
        Clock.freeze(DateTime(2026, 10, 5, 19, 15));
        final state = GameState();
        ClassFacts monday(String code, String title, int start) => ClassFacts(
          occurrenceKey: keyed ? 'occ-$code-$start' : null,
          courseCode: code,
          title: title,
          kind: 'lecture',
          dayKey: '2026-10-05',
          startMinute: start,
          startsAt: DateTime(2026, 10, 5, start ~/ 60, start % 60),
          endsAt: DateTime(2026, 10, 5, start ~/ 60 + 1, start % 60 + 20),
        );
        final devices = monday('14:332:361', 'Electronic Devices', 510);
        final early = monday('14:332:345', 'Linear Systems & Signals', 840);
        final late = monday('14:332:345', 'Linear Systems & Signals', 1060);
        final keys = [
          for (final f in [devices, early, late]) f.identity,
        ];
        expect(keys.toSet(), hasLength(3), reason: 'keyed: $keyed');

        final first = state.keepClass(early, dayClassKeys: keys)!;
        expect(first.courseCount, 1);
        final second = state.keepClass(late, dayClassKeys: keys)!;
        expect(second.courseCount, 2, reason: 'keyed: $keyed');
        expect(second.dayComplete, isFalse);
        expect(second.fullDayBonus, 0);
        final third = state.keepClass(devices, dayClassKeys: keys)!;
        expect(third.courseCount, 1);
        expect(third.dayComplete, isTrue);
        expect(third.fullDayBonus, ClassPay.fullDayBonusXp);
        expect(third.keptToday, 3);
        expect(state.totalXp, 85);
        expect(state.keptClassCounts, {'14:332:361': 1, '14:332:345': 2});
        for (final facts in [early, late, devices]) {
          expect(
            state.checkClassKeep(facts),
            ClassKeepCheck.alreadyKept,
            reason: 'keyed: $keyed',
          );
          expect(state.keepClass(facts, dayClassKeys: keys), isNull);
        }
        expect(state.totalXp, 85, reason: 'the bonus is paid once');

        final restored = _reload(state);
        expect(restored.classesKeptOn('2026-10-05'), hasLength(3));
        expect(restored.keptCountForCourse('14:332:345'), 2);
        expect(restored.checkClassKeep(late), ClassKeepCheck.alreadyKept);
      }
    });

    test('per-course counts and the total only grow, past the record trim', () {
      final state = GameState();
      var day = DateTime(2026, 1, 5, 12);
      for (var i = 0; i < GameState.dayRecordHorizon + 20; i++) {
        Clock.freeze(day);
        final credit = state.keepClass(
          ClassFacts(
            occurrenceKey: 'occ-$i',
            courseCode: '14:332:345',
            title: 'Linear Systems & Signals',
            kind: 'lecture',
            dayKey: Days.key(day),
            startMinute: 840,
          ),
        )!;
        expect(credit.courseCount, i + 1);
        expect(credit.totalClassesKept, i + 1);
        day = DateTime(day.year, day.month, day.day + 1, 12);
      }
      expect(state.dayRecords, hasLength(GameState.dayRecordHorizon));
      expect(state.keptCountForCourse('14:332:345'), 200);
      expect(state.totalClassesKept, 200);

      final restored = GameState.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
      );
      expect(restored.keptCountForCourse('14:332:345'), 200);
      expect(restored.totalClassesKept, 200);
      expect(restored.dayRecords, hasLength(GameState.dayRecordHorizon));
    });
  });

  group('level projection and level-ups', () {
    test('projects the level a keep makes ready without applying it', () {
      Clock.freeze(DateTime(2026, 10, 6, 12));
      final state = GameState()
        ..level = 3
        ..xp = 140;
      expect(state.xpNeeded(4), 195);

      final credit = state.keepClass(_architecture())!;
      expect(credit.level.level, 3);
      expect(credit.level.xpBefore, 140);
      expect(credit.level.xpAfter, 165);
      expect(credit.level.xpForNextLevel, 195);
      expect(credit.level.levelReady, isFalse);

      Clock.freeze(DateTime(2026, 10, 6, 15, 35));
      final ready = state.keepClass(_discrete())!;
      expect(ready.level.xpAfter, 190);
      expect(ready.level.levelReady, isFalse);
      state.xp = 180;
      Clock.freeze(DateTime(2026, 10, 7, 12));
      final crossing = state.keepClass(_archLab())!;
      expect(crossing.level.levelReady, isTrue);
      expect(crossing.level.projectedLevel, 4);
      expect(state.level, 3, reason: 'the UI chain applies levels');
    });

    test('a level-up names the classes since the last level, 0 otherwise', () {
      Clock.freeze(DateTime(2026, 10, 6, 15, 35));
      final state = GameState()..xp = 60;
      expect(state.xpNeeded(2), 105);
      state.keepClass(_architecture());
      state.keepClass(_discrete());
      final first = state.applyLevelUps();
      expect(first.leveledTo, 2);
      expect(first.classesSince, 2);
      expect(state.classesAtLastLevel, 2);

      state.xp = state.xpNeeded(3);
      final questOnly = state.applyLevelUps();
      expect(questOnly.leveledTo, 3);
      expect(questOnly.classesSince, 0);

      final restored = GameState.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
      );
      expect(restored.classesAtLastLevel, 2);
      expect(restored.totalClassesKept, 2);
    });

    test(
      'a stat tier crossing joins the rank-up beat; achievements unlock',
      () {
        Clock.freeze(DateTime(2026, 10, 6, 12));
        final state = GameState()..stats[Stat.intl] = 48;

        final credit = state.keepClass(_architecture())!;

        expect(credit.rankedUpTo, isNotNull);
        expect(credit.rankedUpTo!.tier, 3);
        final beat = state.takeJustRankedUp();
        expect(beat?.$1, Stat.intl);
        expect(credit.achievements.map((a) => a.id), contains('specialist'));
        expect(state.unlockedAchievements, contains('specialist'));
      },
    );
  });

  group('night and Journal totals', () {
    test('class XP and stats reach the night through day-keyed reads', () {
      Clock.freeze(DateTime(2026, 10, 6, 21));
      final state = GameState()
        ..lastActiveDay = _tue
        ..todayXp = 20
        ..todayStats[Stat.vit] = 2
        ..todayQuestTitles.add('Drink water');

      Clock.freeze(DateTime(2026, 10, 6, 21, 5));
      state.keepClass(_architecture(), dayClassKeys: _tuesdayKeys);
      state.keepClass(_discrete(), dayClassKeys: _tuesdayKeys);

      expect(state.todayXp, 20);
      expect(state.nightXp, 20 + 25 + 25 + 10);
      expect(state.nightStatGains, {Stat.vit: 2, Stat.intl: 6});
      expect(state.nightQuestTitles, ['Drink water']);
      expect(state.nightCompletionCount, 1);
      final trace = state.nightJournalTrace(const []);
      expect(trace.todayXp, 80);
      expect(trace.classTitles, [
        'Computer Architecture & Assembly Language',
        'Discrete Structures II',
      ]);
      expect(trace.questTitles, ['Drink water']);
      final roundTrip = JournalTrace.fromJson(trace.toJson())!;
      expect(roundTrip.classTitles, trace.classTitles);
      expect(roundTrip.hasDayEvidence, isTrue);
    });

    test('a 1am keep belongs to the night it happened in', () {
      Clock.freeze(DateTime(2026, 10, 6, 23, 50));
      final state = GameState()..lastActiveDay = _tue;
      Clock.freeze(DateTime(2026, 10, 7, 1, 10));
      state.rollover(<Quest>[]);
      state.keepClass(_discrete());
      expect(state.nightXp, 25);
      expect(state.todayJournalTrace(const []).todayXp, 0);
      expect(state.todayJournalTrace(const []).classTitles, isEmpty);
    });
  });

  group('persistence', () {
    test('round-trips and decodes tolerantly without re-awarding', () {
      Clock.freeze(DateTime(2026, 10, 6, 15, 35));
      final state = GameState();
      state.keepClass(_architecture(), dayClassKeys: _tuesdayKeys);
      state.keepClass(_discrete(), dayClassKeys: _tuesdayKeys);
      final json =
          jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>;

      final restored = GameState.fromJson(json);
      expect(restored.classesKeptOn(_tue), hasLength(2));
      expect(restored.dayRecordFor(_tue)!.fullDayBonusXp, 10);
      expect(restored.totalXp, state.totalXp);
      expect(restored.keepClass(_architecture()), isNull);

      final record =
          (json['dayRecords'] as List).single as Map<String, dynamic>;
      final good = (record['classes'] as List).first as Map<String, dynamic>;
      final damaged = Map<String, dynamic>.of(json)
        ..['dayRecords'] = [
          {
            'dayKey': _tue,
            'classes': [
              {...good, 'label': 'Older label', 'keptAt': 1},
              {...good, 'label': 'Newest label', 'keptAt': 9999999999999},
              {
                ...good,
                'statKey': 'no-such-stat',
                'occurrenceKey': 'other',
                'startMinute': 900,
              },
              {
                ...good,
                'xp': 999999,
                'occurrenceKey': 'greedy',
                'startMinute': 1000,
              },
              {...good, 'courseCode': '', 'occurrenceKey': 'blank'},
              {
                ...good,
                'keptAt': 1 << 62,
                'occurrenceKey': 'far',
                'startMinute': 1100,
              },
              'not a class',
            ],
            'fullDayBonusXp': 9999,
          },
          {
            'dayKey': _tue,
            'extraCredit': {
              'title': 'Went to everything',
              'xp': 10,
              'createdAt': 5,
            },
            'fullDayBonusXp': 10,
          },
          {'dayKey': 'tomorrow', 'classes': []},
          {'dayKey': _wed},
          42,
        ]
        ..['keptClassCounts'] = {'14:332:331': 'many', '': 3, 7: 1};
      final repaired = GameState.fromJson(damaged);
      final classes = repaired.classesKeptOn(_tue);
      expect(classes, hasLength(2));
      expect(classes.first.label, 'Newest label');
      expect(
        classes.last.stat,
        Stat.intl,
        reason: 'drifted stat falls back by kind',
      );
      expect(repaired.dayRecordFor(_tue)!.fullDayBonusXp, 10);
      expect(repaired.extraCreditForDay(_tue)!.title, 'Went to everything');
      expect(repaired.dayRecordFor(_wed), isNull);
      expect(repaired.totalXp, state.totalXp, reason: 'decode never re-awards');
      expect(
        repaired.keptCountForCourse('14:332:331'),
        2,
        reason: 'counters repair upward from the records',
      );

      final wrongType = Map<String, dynamic>.of(json)
        ..['dayRecords'] = 'nope'
        ..['keptClassCounts'] = []
        ..['totalClassesKept'] = 'x'
        ..['classesAtLastLevel'] = -4;
      final empty = GameState.fromJson(wrongType);
      expect(empty.dayRecords, isEmpty);
      expect(empty.totalClassesKept, 0);
      expect(empty.classesAtLastLevel, 0);
    });

    test('decoding an ordinary save does not read the live clock', () {
      Clock.freeze(DateTime(2026, 10, 6, 15, 35));
      final state = GameState()..keepClass(_architecture());
      final json =
          jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>;
      Clock.use(() => throw StateError('Decode must not depend on now'));
      expect(GameState.fromJson(json).classesKeptOn(_tue), hasLength(1));
    });

    test(
      'schema 28 migrates to 29 and the class keep survives a reload',
      () async {
        Clock.freeze(DateTime(2026, 10, 6, 12));
        final legacyState = GameState().toJson()
          ..remove('dayRecords')
          ..remove('totalClassesKept')
          ..remove('classesAtLastLevel')
          ..remove('keptClassCounts');
        SharedPreferences.setMockInitialValues({
          'liferpg_save_v1': jsonEncode({
            'app': 'emberkeep',
            'schema': 28,
            'state': legacyState,
            'quests': const <Object>[],
          }),
        });
        final (state, quests) = (await Storage.load())!;
        expect(state.dayRecords, isEmpty);
        expect(state.keepClass(_architecture()), isNotNull);
        expect(await Storage.save(state, quests), isTrue);

        final raw = (await Storage.exportRaw())!;
        expect(Storage.schemaOf(raw), 29);
        expect(Storage.isValidSave(raw), isTrue);
        final (reloaded, _) = (await Storage.load())!;
        expect(reloaded.classesKeptOn(_tue), hasLength(1));
        expect(reloaded.keptCountForCourse('14:332:331'), 1);
        expect(reloaded.keepClass(_architecture()), isNull);
      },
    );

    test('cloud merge holds an older-schema remote over kept classes', () {
      Clock.freeze(DateTime(2026, 10, 6, 12));
      final local = GameState()
        ..lastModified = 100
        ..keepClass(_architecture());
      String wrap(GameState s, int schema, {bool dropRecords = false}) {
        final encoded = s.toJson();
        if (dropRecords) encoded.remove('dayRecords');
        return jsonEncode({
          'app': 'emberkeep',
          'schema': schema,
          'state': encoded,
          'quests': const <Object>[],
        });
      }

      final localRaw = wrap(local, Storage.schema);
      final olderRemote = wrap(
        GameState()..lastModified = 200,
        28,
        dropRecords: true,
      );
      expect(
        Storage.decideCloudMerge(localRaw: localRaw, remoteRaw: olderRemote),
        CloudMergeDecision.hold,
        reason:
            'a newer schema-28 copy would drop the proof and allow a re-award',
      );
      final newerRemote = GameState.fromJson(local.toJson())
        ..lastModified = 300;
      expect(
        Storage.decideCloudMerge(
          localRaw: localRaw,
          remoteRaw: wrap(newerRemote, Storage.schema),
        ),
        CloudMergeDecision.adoptRemote,
      );
      expect(
        Storage.decideCloudMerge(localRaw: localRaw, remoteRaw: null),
        CloudMergeDecision.pushLocal,
      );
    });
  });

  group('undo', () {
    String snapshot(GameState state) =>
        jsonEncode({'state': state.toJson(), 'quests': const <Object>[]});

    GameState restore(String snap) => GameState.fromJson(
      ((jsonDecode(snap) as Map)['state'] as Map).cast<String, dynamic>(),
    );

    test('one whole-save slot reverts a keep exactly', () {
      Clock.freeze(DateTime(2026, 10, 6, 12));
      final state = GameState()..embers = 3;
      final slot = RewardUndoSlot.beforeClass(
        state,
        _architecture(),
        snapshot: snapshot(state),
      );
      state.keepClass(_architecture());
      expect(slot.canRestore(state), isTrue);
      expect(slot.kind, RewardUndoKind.keptClass);
      expect(slot.classIdentity, 'occ-331-1006');
      expect(slot.dayKey, _tue);

      final back = restore(slot.snapshot);
      expect(back.classesKeptOn(_tue), isEmpty);
      expect(back.totalXp, 0);
      expect(back.embers, 3);
      expect(back.stats[Stat.intl], 0);
      expect(back.totalClassesKept, 0);
      expect(back.keptCountForCourse('14:332:331'), 0);
      expect(
        back.keepClass(_architecture()),
        isNotNull,
        reason: 'it can be kept again',
      );
    });

    test('an Extra Credit wording edit settles an armed slot', () {
      Clock.freeze(DateTime(2026, 10, 6, 21));
      final state = GameState();
      state.addExtraCredit('Went to office hours', dayKey: _tue);
      final slot = RewardUndoSlot.beforeClass(
        state,
        _discrete(),
        snapshot: snapshot(state),
      );
      state.keepClass(_discrete());
      expect(slot.canRestore(state), isTrue);

      expect(state.updateExtraCredit(_tue, ' Went to  office hours '), isTrue);
      expect(
        slot.canRestore(state),
        isTrue,
        reason: 'the same words change nothing',
      );
      expect(
        state.updateExtraCredit(_tue, 'Stayed after for office hours'),
        isTrue,
      );
      expect(
        slot.canRestore(state),
        isFalse,
        reason: 'a restore would put the old words back',
      );
      expect(
        state.extraCreditForDay(_tue)!.title,
        'Stayed after for office hours',
      );
    });

    test('a later reward of any kind settles the slot', () {
      Clock.freeze(DateTime(2026, 10, 6, 15, 35));
      final state = GameState(rng: _NoLuck());
      final slot = RewardUndoSlot.beforeClass(
        state,
        _architecture(),
        snapshot: snapshot(state),
      );
      state.keepClass(_architecture());
      state.keepClass(_discrete());
      expect(slot.canRestore(state), isFalse, reason: 'a later class keep');

      final questSlot = RewardUndoSlot.before(
        state,
        kind: RewardUndoKind.quest,
        label: 'Drink water',
        snapshot: snapshot(state),
      );
      state.commit(
        state.roll(Quest(title: 'Drink water', stat: Stat.vit, difficulty: 2)),
      );
      expect(questSlot.canRestore(state), isTrue);
      state.addExtraCredit('Stayed after for office hours', dayKey: _tue);
      expect(
        questSlot.canRestore(state),
        isFalse,
        reason: 'later Extra Credit',
      );

      final other = GameState();
      final foreign = RewardUndoSlot.before(
        other,
        kind: RewardUndoKind.quest,
        label: 'x',
        snapshot: snapshot(other),
      );
      expect(foreign.canRestore(state), isFalse, reason: 'a swapped state');
    });

    test('one slot spans a gesture that keeps several classes', () {
      Clock.freeze(DateTime(2026, 10, 6, 15, 35));
      final state = GameState(rng: _NoLuck());
      final before = RewardUndoSlot.beforeClass(
        state,
        _architecture(),
        snapshot: snapshot(state),
      );
      state.keepClass(_architecture());
      state.keepClass(_discrete());
      expect(before.canRestore(state), isFalse, reason: 'one reward per slot');
      final slot = before.spanning(2, last: _discrete());
      expect(slot.canRestore(state), isTrue);
      expect(slot.rewards, 2);
      expect(slot.classIdentity, _discrete().identity);
      expect(slot.label, _discrete().label);
      final back = restore(slot.snapshot);
      expect(back.classesKeptOn(_tue), isEmpty, reason: 'both come back');
      expect(back.totalXp, 0);

      state.commit(
        state.roll(Quest(title: 'Drink water', stat: Stat.vit, difficulty: 2)),
      );
      expect(slot.canRestore(state), isFalse, reason: 'a later reward');
      expect(before.spanning(0).canRestore(state), isFalse);
    });
  });
}
