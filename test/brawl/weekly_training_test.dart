// This week's training and the monster of the week: pure arithmetic on marks
// and dates. Every DateTime is a local one built from calendar fields, so no
// test depends on the host's time zone (the daylight-saving cases hold on a
// zone without one, where they are ordinary days).
import 'package:emberkeep/brawl/weekly_training.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

TrainingMark _mark(Stat stat, DateTime at, [double weight = 1]) =>
    TrainingMark(at: at, stat: stat, weight: weight);

void main() {
  group('the week runs from Monday at 04:00', () {
    test('a midweek moment belongs to that Monday', () {
      // Wed Oct 14 2026.
      expect(
        trainingWeekStart(DateTime(2026, 10, 14, 12, 30)),
        DateTime(2026, 10, 12, 4),
      );
      expect(
        trainingWeekStart(DateTime(2026, 10, 17, 9)),
        DateTime(2026, 10, 12, 4),
      );
    });

    test('Monday 03:59 is still last week, 04:00 is the new one', () {
      expect(
        trainingWeekStart(DateTime(2026, 10, 12, 3, 59, 59)),
        DateTime(2026, 10, 5, 4),
      );
      expect(
        trainingWeekStart(DateTime(2026, 10, 12, 4)),
        DateTime(2026, 10, 12, 4),
      );
      expect(
        trainingWeekStart(DateTime(2026, 10, 12, 0, 5)),
        DateTime(2026, 10, 5, 4),
      );
    });

    test('Sunday night runs on into the small hours of Monday', () {
      expect(
        trainingWeekStart(DateTime(2026, 10, 18, 23, 59)),
        DateTime(2026, 10, 12, 4),
      );
      expect(
        trainingWeekStart(DateTime(2026, 10, 19, 2)),
        DateTime(2026, 10, 12, 4),
      );
    });

    test('the next week starts seven calendar days on', () {
      expect(
        nextTrainingWeekStart(DateTime(2026, 10, 14, 12)),
        DateTime(2026, 10, 19, 4),
      );
    });

    test('it crosses a month and a year', () {
      expect(
        trainingWeekStart(DateTime(2026, 11, 1, 10)),
        DateTime(2026, 10, 26, 4),
      );
      // Fri Jan 1 2027.
      expect(
        trainingWeekStart(DateTime(2027, 1, 1, 10)),
        DateTime(2026, 12, 28, 4),
      );
    });

    test('a daylight-saving week still begins at 04:00 on the wall clock', () {
      // US clocks go back on Sun Nov 1 2026 and forward on Sun Mar 14 2027.
      expect(
        trainingWeekStart(DateTime(2026, 11, 2, 3, 30)),
        DateTime(2026, 10, 26, 4),
      );
      expect(
        trainingWeekStart(DateTime(2026, 11, 2, 4)),
        DateTime(2026, 11, 2, 4),
      );
      expect(
        trainingWeekStart(DateTime(2027, 3, 15, 3, 30)),
        DateTime(2027, 3, 8, 4),
      );
      expect(
        trainingWeekStart(DateTime(2027, 3, 15, 4)),
        DateTime(2027, 3, 15, 4),
      );
      // The week that holds the change begins where it always does.
      expect(
        trainingWeekStart(DateTime(2027, 3, 14, 12)),
        DateTime(2027, 3, 8, 4),
      );
    });
  });

  group('training points', () {
    final now = DateTime(2026, 10, 17, 11); // Sat

    test('a quiet week is six zeros', () {
      final points = trainingPoints(const [], now);
      expect(points.keys, Stat.values);
      expect(points.values.every((p) => p == 0), isTrue);
    });

    test('each quest finished this week is a point for its stat', () {
      final points = trainingPoints([
        _mark(Stat.str, DateTime(2026, 10, 13, 8)),
        _mark(Stat.str, DateTime(2026, 10, 14, 8)),
        _mark(Stat.str, DateTime(2026, 10, 16, 20)),
        _mark(Stat.intl, DateTime(2026, 10, 15, 9)),
      ], now);
      expect(points[Stat.str], 3);
      expect(points[Stat.intl], 1);
      expect(points[Stat.vit], 0);
    });

    test('one proven with the timer counts 1.5', () {
      final points = trainingPoints([
        _mark(Stat.foc, DateTime(2026, 10, 13, 9), timerProvenWeight),
        _mark(Stat.foc, DateTime(2026, 10, 14, 9), timerProvenWeight),
        _mark(Stat.foc, DateTime(2026, 10, 15, 9)),
      ], now);
      expect(points[Stat.foc], 4);
      expect(timerProvenWeight, 1.5);
    });

    test('the boundary: 03:59 Monday is last week, 04:00 counts', () {
      final points = trainingPoints([
        _mark(Stat.str, DateTime(2026, 10, 12, 3, 59)),
        _mark(Stat.vit, DateTime(2026, 10, 12, 4)),
      ], now);
      expect(points[Stat.str], 0);
      expect(points[Stat.vit], 1);
    });

    test('a mark just before the weekend still counts on Sunday night', () {
      final sunday = DateTime(2026, 10, 18, 23, 30);
      final points = trainingPoints([
        _mark(Stat.soc, DateTime(2026, 10, 18, 22)),
        _mark(Stat.soc, DateTime(2026, 10, 12, 4)),
      ], sunday);
      expect(points[Stat.soc], 2);
      // The same marks one night later, at 03:00 Monday, are still this week.
      final small = DateTime(2026, 10, 19, 3);
      expect(
        trainingPoints([
          _mark(Stat.soc, DateTime(2026, 10, 18, 22)),
        ], small)[Stat.soc],
        1,
      );
      // And at 04:00 Monday they are last week's.
      final fresh = DateTime(2026, 10, 19, 4);
      expect(
        trainingPoints([
          _mark(Stat.soc, DateTime(2026, 10, 18, 22)),
        ], fresh)[Stat.soc],
        0,
      );
    });

    test('a mark at this very moment counts, one after it waits', () {
      final points = trainingPoints([
        _mark(Stat.dis, now),
        _mark(Stat.dis, now.add(const Duration(minutes: 1))),
      ], now);
      expect(points[Stat.dis], 1);
    });

    test('a daylight-saving week counts by the clock on the wall', () {
      // The week of Nov 2 2026 starts the day after the clocks went back.
      final monday = DateTime(2026, 11, 2, 4);
      final points = trainingPoints([
        _mark(Stat.str, DateTime(2026, 11, 1, 23)), // last week's Sunday
        _mark(Stat.str, DateTime(2026, 11, 2, 3, 59)), // still last week
        _mark(Stat.str, monday), // this week
        _mark(Stat.str, DateTime(2026, 11, 3, 9)),
      ], DateTime(2026, 11, 4, 12));
      expect(points[Stat.str], 2);
    });

    test('a saved mark round trips and a damaged one is left out', () {
      final mark = _mark(Stat.intl, DateTime(2026, 10, 14, 9, 30), 1.5);
      final back = TrainingMark.tryFromJson(mark.toJson())!;
      expect(back.stat, Stat.intl);
      expect(back.weight, 1.5);
      expect(back.at, mark.at);
      expect(
        _mark(Stat.str, DateTime(2026, 10, 14)).toJson().containsKey('w'),
        isFalse,
      );
      for (final bad in <Object?>[
        null,
        'x',
        {'t': 1},
        {'s': 1},
        {'t': 'a', 's': 1},
        {'t': 1000, 's': 99},
        {'t': 1000, 's': -1},
      ]) {
        expect(TrainingMark.tryFromJson(bad), isNull, reason: '$bad');
      }
      // A strange weight reads as one.
      expect(TrainingMark.tryFromJson({'t': 1000, 's': 0, 'w': -4})!.weight, 1);
    });
  });

  group('the boost', () {
    test('1 for nothing, then 0.18 a point, up to 4', () {
      expect(boostOf(0), 1);
      expect(boostOf(-2), 1);
      expect(boostOf(1), closeTo(1.18, 1e-9));
      expect(boostOf(5), closeTo(1.9, 1e-9));
      expect(boostOf(10), closeTo(2.8, 1e-9));
      expect(boostOf(16), closeTo(3.88, 1e-9));
      expect(boostOf(17), 4);
      expect(boostOf(500), 4);
      expect(boostOf(7.5), closeTo(2.35, 1e-9));
    });

    test('a week reads its own boost and glow', () {
      final week = WeeklyTraining.from([
        _mark(Stat.str, DateTime(2026, 10, 13, 8)),
        _mark(Stat.str, DateTime(2026, 10, 14, 8), timerProvenWeight),
      ], DateTime(2026, 10, 17, 11));
      expect(week.pointsOf(Stat.str), 2.5);
      expect(week.boost(Stat.str), closeTo(1.45, 1e-9));
      expect(week.trained(Stat.str), isTrue);
      expect(week.trained(Stat.soc), isFalse);
      expect(week.boost(Stat.soc), 1);
      expect(week.any, isTrue);
      expect(week.lineFor(Stat.str), '+2.5 this week');
      expect(week.lineFor(Stat.soc), isNull);
      expect(WeeklyTraining.quiet().any, isFalse);
    });

    test('points read in plain numbers', () {
      expect(pointsLabel(0), '0');
      expect(pointsLabel(6), '6');
      expect(pointsLabel(7.5), '7.5');
      expect(pointsLabel(3.0), '3');
    });
  });

  group('the monster of the week', () {
    test('ISO week numbers, including the year turn', () {
      expect(isoWeekNumber(DateTime(2026, 10, 14)), 42);
      expect(isoWeekNumber(DateTime(2026, 10, 12)), 42);
      expect(isoWeekNumber(DateTime(2026, 10, 18)), 42);
      expect(isoWeekNumber(DateTime(2026, 10, 19)), 43);
      expect(isoWeekNumber(DateTime(2026, 1, 1)), 1);
      expect(isoWeekNumber(DateTime(2026, 12, 31)), 53);
      expect(isoWeekNumber(DateTime(2027, 1, 1)), 53);
      expect(isoWeekNumber(DateTime(2027, 1, 4)), 1);
      expect(isoWeekNumber(DateTime(2025, 12, 29)), 1);
      expect(isoWeekNumber(DateTime(2025, 12, 28)), 52);
    });

    test('even weeks the Couch Troll, odd weeks the Fog', () {
      final troll = monsterOfTheWeek(DateTime(2026, 10, 14)); // week 42
      expect(troll.name, 'Couch Troll');
      expect(troll.weakness, Stat.str);
      expect(troll.theName, 'the Couch Troll');
      expect(troll.weakLine, 'weak to Strength');
      final fog = monsterOfTheWeek(DateTime(2026, 10, 7)); // week 41
      expect(fog.name, 'Fog');
      expect(fog.weakness, Stat.intl);
      expect(fog.theName, 'the Fog');
      expect(fog.weakLine, 'weak to Intellect');
    });

    test('the same monster all week, changing on Monday at 04:00', () {
      expect(monsterOfTheWeek(DateTime(2026, 10, 12, 4)).id, 'couch_troll');
      expect(monsterOfTheWeek(DateTime(2026, 10, 17, 11)).id, 'couch_troll');
      expect(monsterOfTheWeek(DateTime(2026, 10, 19, 3, 59)).id, 'couch_troll');
      expect(monsterOfTheWeek(DateTime(2026, 10, 19, 4)).id, 'fog');
      expect(monsterOfTheWeek(DateTime(2026, 10, 12, 3, 59)).id, 'fog');
    });

    test('through the year turn, the weeks keep their number', () {
      // Week 53 of 2026 and week 1 of 2027 are both odd: the Fog twice.
      expect(monsterOfTheWeek(DateTime(2027, 1, 1)).id, 'fog');
      expect(monsterOfTheWeek(DateTime(2027, 1, 4, 12)).id, 'fog');
      expect(monsterOfTheWeek(DateTime(2027, 1, 11, 12)).id, 'couch_troll');
      expect(monsterOfTheWeek(DateTime(2025, 12, 28, 12)).id, 'couch_troll');
    });

    test('the preview line reads the way the Me page says it', () {
      expect(
        weekendPreviewLine(DateTime(2026, 10, 14)),
        'This weekend: the Couch Troll · weak to Strength',
      );
      expect(
        weekendPreviewLine(DateTime(2026, 10, 7)),
        'This weekend: the Fog · weak to Intellect',
      );
    });
  });
}
