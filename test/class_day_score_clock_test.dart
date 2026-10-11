// The pure part of the class-day score: the form's constants, the beat clock,
// and which swell goes where. No audio and no timers here.
import 'package:emberkeep/class_day_score_clock.dart';
import 'package:flutter_test/flutter_test.dart';

Duration _s(double seconds) => Duration(microseconds: (seconds * 1e6).round());

void main() {
  group('the form', () {
    test('is one 72 BPM pass of 64 beats, 53.333 s', () {
      expect(ScoreForm.bpm, 72);
      expect(ScoreForm.beatsPerPass, 64);
      expect(
        (ScoreForm.beat.inMicroseconds * 64 - ScoreForm.pass.inMicroseconds)
            .abs(),
        lessThan(64),
        reason: 'a beat is a 64th of the pass, to the microsecond',
      );
      // 16 bars of 4 beats at 72 BPM = 2,560,000 frames at 48 kHz.
      expect(ScoreForm.pass.inMicroseconds, closeTo(2560000 / 48000 * 1e6, 1));
    });

    test('names six performances of each bed and thirty-two swells', () {
      expect(ScoreForm.performanceCount, 6);
      expect(
        ScoreForm.bedAsset(evening: false, performance: 0),
        'music/class_day/bed_between_0.m4a',
      );
      expect(
        ScoreForm.bedAsset(evening: true, performance: 5),
        'music/class_day/bed_evening_5.m4a',
      );
      expect(ScoreForm.swellCount, 32);
      expect(ScoreForm.swellAsset(0), 'music/class_day/swell_00.m4a');
      expect(ScoreForm.swellAsset(31), 'music/class_day/swell_31.m4a');
      // Twelve beds and thirty-two swells.
      expect(ScoreForm.allAssets, hasLength(44));
      expect(ScoreForm.allAssets.toSet(), hasLength(44));
      expect(() => ScoreForm.swellAsset(32), throwsRangeError);
      expect(() => ScoreForm.swellAsset(-1), throwsRangeError);
      expect(
        () => ScoreForm.bedAsset(evening: false, performance: 6),
        throwsRangeError,
      );
      expect(
        () => ScoreForm.bedAsset(evening: true, performance: -1),
        throwsRangeError,
      );
    });

    test('a bed names its phase and its performance, nothing else does', () {
      for (var p = 0; p < ScoreForm.performanceCount; p++) {
        final between = ScoreForm.bedAsset(evening: false, performance: p);
        final evening = ScoreForm.bedAsset(evening: true, performance: p);
        expect(ScoreForm.isBed(between), isTrue);
        expect(ScoreForm.isBed(evening), isTrue);
        expect(ScoreForm.isEveningBed(between), isFalse);
        expect(ScoreForm.isEveningBed(evening), isTrue);
        expect(ScoreForm.performanceOf(between), p);
        expect(ScoreForm.performanceOf(evening), p);
      }
      for (final other in [
        null,
        'music/lamp-left-on.m4a',
        ScoreForm.swellAsset(3),
        'music/take_01.m4a',
      ]) {
        expect(ScoreForm.isBed(other), isFalse, reason: '$other');
        expect(ScoreForm.isEveningBed(other), isFalse, reason: '$other');
        expect(ScoreForm.performanceOf(other), isNull, reason: '$other');
      }
    });

    test('the swell starts 150 ms before its beat', () {
      expect(ScoreForm.swellPreRoll, const Duration(milliseconds: 150));
    });

    test('beats sit on a grid of 64 per pass, from the anchor', () {
      const anchor = Duration(seconds: 10);
      expect(ScoreForm.beatAt(anchor, 0), anchor);
      expect(ScoreForm.beatAt(anchor, 64), anchor + ScoreForm.pass);
      expect(
        (ScoreForm.beatAt(anchor, 1) - anchor - ScoreForm.beat).abs(),
        lessThan(const Duration(microseconds: 2)),
      );
    });
  });

  group('the lag', () {
    test('is assumed until one is measured, then the median of five', () {
      final clock = ScoreClock();
      expect(clock.lag, clock.defaultLag);
      clock.noteLag(const Duration(milliseconds: 20));
      expect(clock.lag, const Duration(milliseconds: 20));
      for (final ms in [30, 80, 25, 28]) {
        clock.noteLag(Duration(milliseconds: ms));
      }
      // 20, 30, 80, 25, 28 -> sorted 20 25 28 30 80 -> 28
      expect(clock.lag, const Duration(milliseconds: 28));
      // The oldest leaves the window: 30 80 25 28 90 -> 25 28 30 80 90.
      clock.noteLag(const Duration(milliseconds: 90));
      expect(clock.lag, const Duration(milliseconds: 30));
    });

    test('one wild lag does not move the median', () {
      final clock = ScoreClock();
      for (final ms in [30, 32, 28, 31]) {
        clock.noteLag(Duration(milliseconds: ms));
      }
      clock.noteLag(const Duration(milliseconds: 380));
      expect(clock.lag, const Duration(milliseconds: 31));
    });

    test('a negative or absurd lag is not a lag', () {
      final clock = ScoreClock();
      clock.noteLag(const Duration(milliseconds: -5));
      clock.noteLag(const Duration(seconds: 2));
      expect(clock.lag, clock.defaultLag);
    });
  });

  group('trust', () {
    test('there is none before an anchor, and none after distrust', () {
      final clock = ScoreClock();
      expect(clock.trusted, isFalse);
      expect(clock.planSwell(earliest: const Duration(seconds: 5)), isNull);
      clock.anchorAt(Duration.zero);
      expect(clock.trusted, isTrue);
      expect(clock.planSwell(earliest: const Duration(seconds: 5)), isNotNull);
      clock.distrust();
      expect(clock.trusted, isFalse);
      expect(clock.planSwell(earliest: const Duration(seconds: 5)), isNull);
      // The next pass anchors it again.
      clock.anchorAt(const Duration(seconds: 53));
      expect(clock.trusted, isTrue);
    });

    test('an unmeasured start is only a nominal anchor: no swell', () {
      final clock = ScoreClock()..anchorUnmeasured(const Duration(seconds: 1));
      expect(clock.anchor, const Duration(seconds: 1));
      expect(clock.trusted, isFalse);
      expect(clock.planSwell(earliest: const Duration(seconds: 9)), isNull);
    });

    test('a re-measured zero within 40 ms of the anchor agrees', () {
      final clock = ScoreClock()..anchorAt(const Duration(seconds: 20));
      expect(clock.agrees(const Duration(seconds: 20)), isTrue);
      expect(clock.agrees(const Duration(milliseconds: 20040)), isTrue);
      expect(clock.agrees(const Duration(milliseconds: 19960)), isTrue);
      expect(clock.agrees(const Duration(milliseconds: 20041)), isFalse);
      expect(clock.agrees(const Duration(milliseconds: 19900)), isFalse);
      expect(ScoreClock().agrees(Duration.zero), isFalse, reason: 'no anchor');
    });

    test('reset forgets the anchor but keeps what it learned of the lag', () {
      final clock = ScoreClock()
        ..noteLag(const Duration(milliseconds: 44))
        ..anchorAt(Duration.zero)
        ..reset();
      expect(clock.anchor, isNull);
      expect(clock.trusted, isFalse);
      expect(clock.lag, const Duration(milliseconds: 44));
    });
  });

  group('which swell, and when', () {
    ScoreClock clockAt(Duration anchor, {int lagMs = 30}) => ScoreClock()
      ..noteLag(Duration(milliseconds: lagMs))
      ..anchorAt(anchor);

    test('the first strong beat at or after the earliest moment', () {
      final clock = clockAt(Duration.zero);
      // 0.95 s: beats are at 0, 0.833, 1.667 ... the next beat is #2, and
      // #2 is a strong one.
      final a = clock.planSwell(earliest: _s(0.95))!;
      expect(a.beat, 2);
      expect(a.file, 1);
      expect(a.beatAt, ScoreForm.beatAt(Duration.zero, 2));
      // 1.7 s is past beat #2 (1.667 s): beat #3 is weak, so #4.
      final b = clock.planSwell(earliest: _s(1.7))!;
      expect(b.beat, 4);
      expect(b.file, 2);
    });

    test('a beat exactly at the earliest moment is that beat', () {
      final clock = clockAt(Duration.zero);
      final at = ScoreForm.beatAt(Duration.zero, 4);
      expect(clock.planSwell(earliest: at)!.beat, 4);
      // A rounded microsecond past it is still that beat; a real moment is not.
      expect(
        clock.planSwell(earliest: at + const Duration(microseconds: 1))!.beat,
        4,
      );
      expect(
        clock.planSwell(earliest: at + const Duration(milliseconds: 1))!.beat,
        6,
      );
    });

    test('the file follows the form, so the bass follows the chords', () {
      final clock = clockAt(Duration.zero);
      for (var strong = 0; strong < 64; strong += 2) {
        final earliest = ScoreForm.beatAt(Duration.zero, strong);
        final plan = clock.planSwell(earliest: earliest)!;
        expect(plan.beat, strong);
        expect(plan.file, strong ~/ 2, reason: 'strong beat $strong');
      }
    });

    test('the pass wraps: the 64th beat is the next pass\'s first', () {
      final clock = clockAt(Duration.zero);
      final nearEnd = clock.planSwell(earliest: _s(52.6))!;
      expect(nearEnd.beat, 64, reason: '63 is weak, 64 is the next pass');
      expect(nearEnd.file, 0);
      expect(nearEnd.inNextPass, isTrue);
      expect(nearEnd.beatAt, ScoreForm.pass);
      final late = clock.planSwell(earliest: _s(53.5))!;
      expect(late.beat, 66);
      expect(late.file, 1);
    });

    test('the play call is the beat less the pre-roll less the lag', () {
      final clock = clockAt(const Duration(seconds: 100), lagMs: 42);
      final plan = clock.planSwell(earliest: const Duration(seconds: 104))!;
      expect(
        plan.startAt,
        plan.beatAt -
            const Duration(milliseconds: 150) -
            const Duration(milliseconds: 42),
      );
    });

    test('works on any anchor, not just zero', () {
      final anchor = _s(731.4182);
      final clock = clockAt(anchor);
      final plan = clock.planSwell(earliest: anchor + _s(10))!;
      // 10 s / 0.8333 = 12.0 -> beat 12 is at 10.0 s exactly.
      expect(plan.beat, 12);
      expect(plan.beatAt, anchor + _s(10));
    });

    test('an earliest moment before the anchor takes the first beat', () {
      final clock = clockAt(const Duration(seconds: 5));
      expect(clock.planSwell(earliest: const Duration(seconds: 1))!.beat, 0);
    });

    test('the wait after the chime is never more than two beats', () {
      final clock = clockAt(Duration.zero);
      var longest = Duration.zero;
      for (var i = 0; i < 4000; i++) {
        final earliest = Duration(milliseconds: 1000 + i * 13);
        final plan = clock.planSwell(earliest: earliest)!;
        final wait = plan.beatAt - earliest;
        expect(wait, greaterThanOrEqualTo(Duration.zero));
        if (wait > longest) longest = wait;
        expect(plan.beat.isEven, isTrue);
      }
      expect(
        longest,
        lessThan(ScoreForm.beat * 2 + const Duration(microseconds: 2)),
      );
      expect(
        longest,
        greaterThan(_s(1.6)),
        reason: 'it does reach the worst case',
      );
    });
  });

  group('the walk over the performances', () {
    List<int> walk(int seed, int takes, {int count = 6}) {
      final w = PerformanceWalk(seed: seed, count: count);
      return [for (var i = 0; i < takes; i++) w.take()];
    }

    test('never plays the same performance twice in a row', () {
      for (var seed = 0; seed < 300; seed++) {
        final order = walk(seed, 240);
        for (var i = 1; i < order.length; i++) {
          expect(order[i], isNot(order[i - 1]), reason: 'seed $seed, take $i');
        }
      }
    });

    test('plays all of them before any comes round again', () {
      for (var seed = 0; seed < 300; seed++) {
        final order = walk(seed, 240);
        for (var bag = 0; bag < order.length; bag += 6) {
          expect(
            order.sublist(bag, bag + 6).toSet(),
            {0, 1, 2, 3, 4, 5},
            reason: 'seed $seed, take $bag to ${bag + 5}',
          );
        }
      }
    });

    test(
      'is the same walk for the same seed, and not the same for another',
      () {
        expect(walk(41, 60), walk(41, 60));
        final orders = {
          for (var seed = 0; seed < 40; seed++) walk(seed, 12).join(),
        };
        expect(
          orders.length,
          greaterThan(30),
          reason: 'seeds make different days',
        );
        // And every performance can open a day.
        final firsts = {
          for (var seed = 0; seed < 200; seed++) walk(seed, 1).first,
        };
        expect(firsts, {0, 1, 2, 3, 4, 5});
      },
    );

    test('peek says what take will, without using it up', () {
      final w = PerformanceWalk(seed: 5);
      expect(w.last, isNull);
      final next = w.peek;
      expect(w.peek, next);
      expect(w.peek, next);
      expect(w.take(), next);
      expect(w.last, next);
      expect(w.peek, isNot(next), reason: 'not the one that just played');
      // Peeking across a bag boundary does not repeat the last either.
      for (var i = 0; i < 5; i++) {
        final peeked = w.peek;
        expect(w.take(), peeked);
        final after = w.peek;
        expect(after, isNot(peeked));
      }
    });

    test('with two performances it alternates, never repeating', () {
      final order = walk(3, 30, count: 2);
      for (var i = 1; i < order.length; i++) {
        expect(order[i], isNot(order[i - 1]));
      }
      expect(order.toSet(), {0, 1});
    });

    test('a walk of one cannot avoid a repeat, so it is refused', () {
      expect(() => PerformanceWalk(seed: 1, count: 1), throwsAssertionError);
    });
  });
}
