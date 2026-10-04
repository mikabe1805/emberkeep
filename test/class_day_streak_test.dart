import 'dart:math';

import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two streak rules behind [ClassDayRules], in every combination.
/// Pure engine: the clock is frozen with local DateTimes and day keys are
/// strings, so nothing here depends on the host's time zone.

class _NoLuck implements Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.999;
  @override
  int nextInt(int max) => 0;
}

void _at(int month, int day, [int hour = 12]) =>
    Clock.freeze(DateTime(2026, month, day, hour));

String _key(int month, int day) => Days.key(DateTime(2026, month, day));

/// A lab pays CRAFT, which leaves the Quest XP multipliers untouched, so a
/// class and a Quest on the same day can be compared to the XP point.
ClassFacts _classOn(
  int month,
  int day, {
  int start = 600,
  String code = 'ECE 333',
  String kind = 'lab',
}) => ClassFacts(
  occurrenceKey: 'occ-$code-$month-$day-$start',
  courseCode: code,
  title: 'Course $code',
  kind: kind,
  dayKey: _key(month, day),
  startMinute: start,
);

RewardBundle _quest(GameState state, [String title = 'Drink water']) {
  final bundle = state.roll(Quest(title: title, stat: Stat.vit, difficulty: 2));
  state.commit(bundle);
  return bundle;
}

void _rules({bool lights = false, bool pause = false}) =>
    ClassDayRules.debugOverride = ClassDayRules(
      classDayLightsStreak: lights,
      restDaysPause: pause,
    );

bool _weekend(String dayKey) {
  final day = Days.parse(dayKey);
  return day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
}

void main() {
  tearDown(() {
    Clock.reset();
    ClassDayRules.debugOverride = null;
    GameState.restDayResolver = null;
  });

  group('shipped rules (both off)', () {
    test('both rules ship off until Mika answers', () {
      expect(ClassDayRules.shipped.classDayLightsStreak, isFalse);
      expect(ClassDayRules.shipped.restDaysPause, isFalse);
      expect(ClassDayRules.current, same(ClassDayRules.shipped));
    });

    test('a class-only day leaves the streak to Quests', () {
      final state = GameState(rng: _NoLuck());
      _at(10, 5);
      _quest(state);
      _at(10, 6);
      final credit = state.keepClass(_classOn(10, 6))!;
      expect(credit.streak.lit, isFalse);
      expect(state.streakDays, 1);
      expect(state.lastStreakDay, _key(10, 5));

      _at(10, 7);
      final bundle = _quest(state);
      expect(bundle.freezesUsed, 1, reason: 'Tuesday stays a quiet day');
      expect(state.frozenStreakDays, {_key(10, 6)});
      expect(state.streakDays, 2);
    });

    test('a resolver changes nothing while the pause rule is off', () {
      GameState.restDayResolver = (_) => true;
      final state = GameState(rng: _NoLuck());
      _at(10, 9);
      _quest(state);
      _at(10, 12);
      expect(_quest(state).freezesUsed, 2);
    });
  });

  group('A: a kept class lights its day', () {
    setUp(() => _rules(lights: true));

    test('a class day advances the streak; Quest markers stay Quest-only', () {
      final state = GameState(rng: _NoLuck());
      _at(10, 5);
      _quest(state);
      _at(10, 6);
      final credit = state.keepClass(_classOn(10, 6))!;

      expect(credit.streak.lit, isTrue);
      expect(credit.streak.streakDays, 2);
      expect(state.streakDays, 2);
      expect(state.lastStreakDay, _key(10, 6));
      expect(state.lastCompletionDay, _key(10, 5));
      expect(state.history.containsKey(_key(10, 6)), isFalse);
      expect(state.totalCompletions, 1);

      final bundle = _quest(state);
      expect(bundle.firstOfDay, isFalse, reason: 'the class lit today first');
      expect(state.streakDays, 2, reason: 'once per streak day');
      expect(state.lastCompletionDay, _key(10, 6));
      expect(state.history[_key(10, 6)], 1);
    });

    test('a class after a Quest the same day changes nothing', () {
      final state = GameState(rng: _NoLuck());
      _at(10, 6);
      _quest(state);
      final credit = state.keepClass(_classOn(10, 6))!;
      expect(credit.streak, same(ClassStreakEffect.none));
      expect(state.streakDays, 1);
    });

    test('freeze cadence follows streak days, whichever lit them', () {
      final state = GameState(rng: _NoLuck());
      expect(state.streakFreezes, 3);
      _at(10, 5);
      expect(state.keepClass(_classOn(10, 5))!.streak.freezeEarned, isFalse);
      _at(10, 6);
      expect(state.keepClass(_classOn(10, 6))!.streak.freezeEarned, isFalse);
      _at(10, 7);
      final third = state.keepClass(_classOn(10, 7))!;
      expect(third.streak.freezeEarned, isTrue);
      expect(state.streakFreezes, 4);
      expect(state.streakFreezeProgress, 0);
    });

    test('the 7-day chest is paid once, on the crossing streak day', () {
      final state = GameState(rng: _NoLuck())..streakFreezes = 5;
      var embers = 0;
      ClassCredit? seventh;
      for (var day = 5; day <= 11; day++) {
        _at(10, day);
        seventh = state.keepClass(_classOn(10, day))!;
        embers += seventh.glimmers;
      }
      expect(state.streakDays, 7);
      expect(seventh!.streak.milestone, 7);
      expect(seventh.streak.milestoneGlimmers, 50);
      expect(state.embers, embers + 50);
      expect(state.takeJustStreakMilestone(), 7);

      final before = state.embers;
      final bundle = _quest(state);
      expect(state.embers, before + bundle.embers, reason: 'no second chest');
      expect(state.takeJustStreakMilestone(), isNull);
    });

    test('quiet days between class days use freezes as before', () {
      final state = GameState(rng: _NoLuck());
      _at(10, 5);
      state.keepClass(_classOn(10, 5));
      _at(10, 8);
      final credit = state.keepClass(_classOn(10, 8))!;
      expect(credit.streak.freezesUsed, 2);
      expect(state.frozenStreakDays, {_key(10, 6), _key(10, 7)});
      expect(state.streakDays, 2);
    });

    test('a class comeback leaves the welcome-back for the next Quest', () {
      GameState lapsed() => GameState(rng: _NoLuck())
        ..streakDays = 9
        ..bestStreak = 9
        ..lastCompletionDay = '2026-08-01'
        ..streakFreezes = 0;

      // The twin does its Quest first: what that Quest pays is the bar.
      _at(8, 10);
      final twin = lapsed();
      final questFirst = _quest(twin);
      expect(questFirst.comebackMult, GameState.comebackBonus);

      final state = lapsed();
      final credit = state.keepClass(_classOn(8, 10))!;
      expect(credit.streak.restarted, isTrue);
      expect(state.streakDays, 1);
      expect(state.comebacks, 1);
      expect(state.bestStreak, 9);
      expect(state.comebackPendingDay, _key(8, 10));

      final classFirst = _quest(state);
      expect(classFirst.comebackMult, GameState.comebackBonus);
      expect(classFirst.xp, questFirst.xp, reason: 'order never changes pay');
      expect(state.comebacks, 1, reason: 'counted once');
      expect(state.comebackPendingDay, isNull);
      expect(_quest(state, 'Stretch').comebackMult, isNull);
    });

    test('the welcome-back waits for a Quest until another day lights', () {
      GameState lapsed() => GameState(rng: _NoLuck())
        ..streakDays = 4
        ..lastCompletionDay = '2026-08-01'
        ..streakFreezes = 0;

      _at(8, 10);
      final waiting = lapsed()..keepClass(_classOn(8, 10));
      _at(8, 11);
      final nextDay = _quest(waiting);
      expect(nextDay.comebackMult, GameState.comebackBonus);
      expect(waiting.streakDays, 2);

      _at(8, 10);
      final moved = lapsed()..keepClass(_classOn(8, 10));
      _at(8, 11);
      moved.keepClass(_classOn(8, 11));
      expect(_quest(moved).comebackMult, isNull, reason: 'day two of a streak');
      expect(moved.comebackPendingDay, isNull);
    });

    test('a pending welcome-back survives a save and reload', () {
      final state = GameState(rng: _NoLuck())
        ..streakDays = 4
        ..lastCompletionDay = '2026-08-01'
        ..streakFreezes = 0;
      _at(8, 10);
      state.keepClass(_classOn(8, 10));
      final restored = GameState.fromJson(state.toJson());
      expect(restored.comebackPendingDay, _key(8, 10));
      expect(restored.lastStreakDay, _key(8, 10));
      expect(restored.lastCompletionDay, '2026-08-01');
    });

    test('a late mark for a day a freeze held gives the freeze back', () {
      final state = GameState(rng: _NoLuck());
      _at(10, 5);
      _quest(state);
      _at(10, 7);
      _quest(state);
      expect(state.frozenStreakDays, {_key(10, 6)});
      expect(state.streakFreezes, 2);

      final credit = state.keepClass(
        _classOn(10, 6),
        at: DateTime(2026, 10, 6, 15),
      )!;
      expect(credit.streak.freezeReturned, isTrue);
      expect(credit.streak.lit, isFalse);
      expect(state.streakFreezes, 3);
      expect(state.frozenStreakDays, isEmpty);
      expect(state.streakDays, 2);
    });

    test('a late mark for an older lit day leaves the streak alone', () {
      final state = GameState(rng: _NoLuck());
      _at(10, 5);
      _quest(state);
      _at(10, 6);
      _quest(state);
      final credit = state.keepClass(
        _classOn(10, 5),
        at: DateTime(2026, 10, 5, 15),
      )!;
      expect(credit.streak, same(ClassStreakEffect.none));
      expect(state.streakDays, 2);
      expect(state.lastStreakDay, _key(10, 6));
    });
  });

  group('B: rest days pause', () {
    setUp(() {
      _rules(pause: true);
      GameState.restDayResolver = _weekend;
    });

    test('a weekend between Quests neither counts nor spends freezes', () {
      final state = GameState(rng: _NoLuck());
      _at(10, 9); // Friday
      _quest(state);
      _at(10, 12); // Monday
      expect(state.pendingStreakGap, (days: 0, covered: false));
      final bundle = _quest(state);
      expect(bundle.freezesUsed, 0);
      expect(bundle.comebackMult, isNull);
      expect(state.streakDays, 2);
      expect(state.streakFreezes, 3);
      expect(state.frozenStreakDays, isEmpty);
    });

    test('an ordinary quiet day inside the gap still needs a freeze', () {
      final state = GameState(rng: _NoLuck());
      _at(10, 9); // Friday
      _quest(state);
      _at(10, 13); // Tuesday; Monday was not a rest day
      expect(state.pendingStreakGap, (days: 1, covered: true));
      final bundle = _quest(state);
      expect(bundle.freezesUsed, 1);
      expect(state.frozenStreakDays, {_key(10, 12)});
    });

    test('rest days are left out of the gap the reserve has to hold', () {
      final state = GameState(rng: _NoLuck())..streakFreezes = 2;
      _at(10, 7); // Wednesday
      _quest(state);
      _at(10, 12); // Monday: Thu and Fri are quiet, the weekend rests
      expect(state.pendingStreakGap, (days: 2, covered: true));
      expect(_quest(state).freezesUsed, 2);
    });

    test('a resolver that throws counts the day as ordinary', () {
      GameState.restDayResolver = (_) => throw StateError('no timetable');
      final state = GameState(rng: _NoLuck());
      _at(10, 9);
      _quest(state);
      _at(10, 12);
      expect(_quest(state).freezesUsed, 2);
    });

    test('with no resolver nothing pauses', () {
      GameState.restDayResolver = null;
      final state = GameState(rng: _NoLuck());
      _at(10, 9);
      _quest(state);
      _at(10, 12);
      expect(_quest(state).freezesUsed, 2);
    });

    test('class days do not light the streak while rule A is off', () {
      final state = GameState(rng: _NoLuck());
      _at(10, 9);
      _quest(state);
      _at(10, 12);
      expect(state.keepClass(_classOn(10, 12))!.streak.lit, isFalse);
      expect(state.streakDays, 1);
    });
  });

  group('A and B together', () {
    setUp(() {
      _rules(lights: true, pause: true);
      GameState.restDayResolver = _weekend;
    });

    test(
      'a class fortnight with weekends keeps the streak without freezes',
      () {
        final state = GameState(rng: _NoLuck());
        int? milestone;
        for (var day = 5; day <= 16; day++) {
          final weekday = DateTime(2026, 10, day).weekday;
          if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
            continue;
          }
          _at(10, day);
          final credit = state.keepClass(_classOn(10, day))!;
          expect(credit.streak.lit, isTrue);
          expect(credit.streak.freezesUsed, 0);
          if (weekday == DateTime.monday && day > 5) {
            expect(credit.streak.restDaysPassed, 2);
          }
          milestone ??= credit.streak.milestone;
        }
        expect(state.streakDays, 10);
        expect(milestone, 7);
        expect(state.frozenStreakDays, isEmpty);
        expect(state.comebacks, 0);
      },
    );
  });

  group('never punish', () {
    for (final lights in [false, true]) {
      for (final pause in [false, true]) {
        test('no rule ever takes XP, stats, level or best streak '
            '(lights: $lights, pause: $pause)', () {
          _rules(lights: lights, pause: pause);
          final dice = Random(lights ? (pause ? 11 : 7) : (pause ? 5 : 3));
          GameState.restDayResolver = (key) => key.hashCode % 3 == 0;
          final state = GameState(rng: Random(42));
          var totalXp = 0;
          var level = 1;
          var best = 0;
          var embers = 0;
          final statFloor = {for (final stat in Stat.values) stat: 0};

          void check(String step) {
            expect(state.totalXp, greaterThanOrEqualTo(totalXp), reason: step);
            expect(state.level, greaterThanOrEqualTo(level), reason: step);
            expect(state.bestStreak, greaterThanOrEqualTo(best), reason: step);
            expect(state.embers, greaterThanOrEqualTo(embers), reason: step);
            for (final stat in Stat.values) {
              expect(
                state.stats[stat]!,
                greaterThanOrEqualTo(statFloor[stat]!),
                reason: '$step ${stat.name}',
              );
            }
            expect(state.streakFreezes, inInclusiveRange(0, 7), reason: step);
            totalXp = state.totalXp;
            level = state.level;
            best = state.bestStreak;
            embers = state.embers;
            for (final stat in Stat.values) {
              statFloor[stat] = state.stats[stat]!;
            }
          }

          var day = DateTime(2026, 9, 1, 9);
          for (var i = 0; i < 90; i++) {
            Clock.freeze(day);
            state.rollover(<Quest>[]);
            final roll = dice.nextInt(6);
            if (roll >= 2) {
              final classes = dice.nextInt(4);
              final keys = [
                for (var c = 0; c < classes; c++) 'occ-${Days.key(day)}-$c',
              ];
              for (var c = 0; c < classes; c++) {
                Clock.freeze(
                  DateTime(day.year, day.month, day.day, 10 + c * 2),
                );
                state.keepClass(
                  ClassFacts(
                    occurrenceKey: keys[c],
                    courseCode: 'C$c',
                    title: 'Class $c',
                    kind: c == 2 ? 'lab' : 'lecture',
                    dayKey: Days.key(day),
                    startMinute: 600 + c * 120,
                  ),
                  dayClassKeys: keys,
                );
                check('class $i/$c');
              }
            }
            if (roll.isOdd || roll == 4) {
              Clock.freeze(DateTime(day.year, day.month, day.day, 20));
              for (var q = 0; q <= dice.nextInt(2); q++) {
                _quest(state, 'Quest $q');
                check('quest $i/$q');
              }
            }
            if (dice.nextInt(5) == 0 && i > 2) {
              // A queued mark for a recent class arrives late.
              final earlier = DateTime(day.year, day.month, day.day - 1, 14);
              Clock.freeze(DateTime(day.year, day.month, day.day, 21));
              state.keepClass(
                ClassFacts(
                  occurrenceKey: 'late-${Days.key(earlier)}',
                  courseCode: 'LATE',
                  title: 'Late mark',
                  kind: 'lecture',
                  dayKey: Days.key(earlier),
                  startMinute: 840,
                ),
                at: earlier,
              );
              check('late $i');
            }
            state.applyLevelUps();
            check('level $i');
            day = DateTime(
              day.year,
              day.month,
              day.day + 1 + (dice.nextInt(7) == 0 ? dice.nextInt(4) : 0),
              9,
            );
          }
        });
      }
    }
  });
}
