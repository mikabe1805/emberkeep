// The class-day score on a fake transport and fake time: what it asks of the
// phone, and when, over a whole class day. Nothing here plays a sound.
import 'dart:async';
import 'dart:io';

import 'package:emberkeep/class_day_score.dart';
import 'package:emberkeep/class_day_score_clock.dart';
import 'package:emberkeep/main_room_music.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/class_day_score_harness.dart';

const _chime = Duration(milliseconds: 950);
const _chimeReduced = Duration(milliseconds: 310);
const _ms35 = Duration(milliseconds: 35);

/// Runs [body] on fake time.
void _day(void Function(FakeAsync async) body) {
  fakeAsync((async) {
    body(async);
  });
}

void main() {
  group('starting a bed', () {
    test('Between: prepared at zero volume, started, faded in over 4 s', () {
      _day((async) {
        final h = ScoreHarness(async);
        unawaited(h.score.start(evening: false));
        h.run(const Duration(milliseconds: 100));

        final bed = h.transport.voices.single;
        expect(isBetweenBed(bed.asset), isTrue);
        expect(bed.volumes.first.volume, 0, reason: 'prepared silent');
        expect(bed.callAt, isNotNull);
        expect(h.score.isPlaying, isTrue);
        expect(isBetweenBed(h.score.nowPlaying.value), isTrue);

        h.run(const Duration(seconds: 2));
        expect(bed.lastVolume, closeTo(0.5, 0.05), reason: 'half way in 2 s');
        h.run(const Duration(seconds: 2, milliseconds: 100));
        expect(bed.lastVolume, 1.0);
        // The shared fade is the room's own: 4 s in, 600 ms out.
        expect(MainRoomMusic.startFadeIn, const Duration(seconds: 4));
        expect(MainRoomMusic.stopFadeOut, const Duration(milliseconds: 600));
      });
    });

    test('Evening starts on the Evening bed', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startAndSettle(evening: true);
        expect(isEveningBed(h.transport.voices.single.asset), isTrue);
        expect(isEveningBed(h.score.nowPlaying.value), isTrue);
      });
    });

    test('the beat clock is anchored on the first sample, within a few ms', () {
      _day((async) {
        final h = ScoreHarness(
          async,
          startLag: const Duration(milliseconds: 41),
        );
        h.startAndSettle();
        final bed = h.transport.voices.single;
        expect(h.score.clock.trusted, isTrue);
        final err = (h.anchor - bed.zeroAt!).abs();
        expect(
          err,
          lessThanOrEqualTo(const Duration(milliseconds: 3)),
          reason: 'polled every 12 ms, whole-millisecond positions',
        );
        expect(
          (h.score.clock.lag - const Duration(milliseconds: 41)).abs(),
          lessThanOrEqualTo(const Duration(milliseconds: 4)),
        );
      });
    });

    test('never starts while the app is in the background', () {
      _day((async) {
        final h = ScoreHarness(async);
        unawaited(h.score.setForeground(false));
        h.run(const Duration(seconds: 1));
        unawaited(h.score.start(evening: false));
        h.run(const Duration(seconds: 1));
        expect(h.transport.voices, isEmpty);
        expect(h.score.isPlaying, isFalse);
      });
    });

    test('a failed prepare leaves nothing playing and says so', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.transport.prepareFailure = (_) => StateError('no such asset');
        Object? error;
        unawaited(
          h.score.start(evening: false).catchError((Object e) {
            error = e;
          }),
        );
        h.run(const Duration(seconds: 1));
        expect(error, isA<StateError>());
        expect(h.score.isPlaying, isFalse);
        expect(h.transport.live, isEmpty);
        expect(h.score.nowPlaying.value, isNull);
      });
    });

    test('nothing in the score loops: one play per pass, no loop mode', () {
      final code = File('lib/class_day_score.dart')
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      expect(code, isNot(contains('ReleaseMode.loop')));
      expect(code, contains('setReleaseMode(ReleaseMode.stop)'));
    });
  });

  group('chaining passes', () {
    test('the next pass starts one form after the last, ringing over it', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startAndSettle();
        final first = h.transport.voices.single;
        // Four seconds before the pass ends, the next is prepared, not played.
        h.run(ScoreForm.pass - const Duration(seconds: 6));
        expect(h.transport.voices, hasLength(1));
        h.run(const Duration(seconds: 3));
        expect(h.transport.voices, hasLength(2));
        final second = h.transport.voices[1];
        expect(isBetweenBed(second.asset), isTrue);
        expect(second.callAt, isNull, reason: 'prepared, waiting for its beat');
        // It starts one pass after the first sample, less the platform's lag.
        h.run(const Duration(seconds: 3));
        expect(second.callAt, isNotNull);
        final gap = second.zeroAt! - first.zeroAt!;
        expect(
          (gap - ScoreForm.pass).abs(),
          lessThanOrEqualTo(const Duration(milliseconds: 8)),
          reason: 'one form between first samples',
        );
        // The first pass is still ringing out; it is let go after its tail.
        expect(first.released, isFalse);
        expect(
          second.volumes.first.volume,
          1.0,
          reason: 'no fade between passes',
        );
        h.run(const Duration(seconds: 8));
        expect(first.released, isTrue);
        expect(second.released, isFalse);
        // And a third follows.
        h.run(ScoreForm.pass);
        expect(h.transport.beds.length, greaterThanOrEqualTo(3));
      });
    });

    test('a next pass still being prepared at its boundary is waited for, '
        'not prepared twice', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        // Slower than the four seconds it is given.
        h.transport.prepareTime = const Duration(seconds: 5);
        h.runToPass(54);
        h.run(const Duration(seconds: 6));
        expect(h.transport.beds, hasLength(2));
        expect(
          h.transport.voices.where((v) => isBetweenBed(v.asset)),
          hasLength(2),
        );
        expect(h.score.isPlaying, isTrue);
      });
    });

    test('a long afternoon: ten passes, no drift between them', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startAndSettle();
        h.run(ScoreForm.pass * 10);
        final beds = h.transport.beds.toList();
        expect(beds.length, greaterThanOrEqualTo(10));
        for (var i = 1; i < beds.length; i++) {
          final gap = beds[i].zeroAt! - beds[i - 1].zeroAt!;
          expect(
            (gap - ScoreForm.pass).abs(),
            lessThanOrEqualTo(const Duration(milliseconds: 10)),
            reason: 'pass $i',
          );
        }
        // Only the passing pass and its predecessor's tail are live.
        expect(h.transport.live.length, lessThanOrEqualTo(3));
      });
    });

    test('the phase changes at the next pass boundary, not before', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        h.run(const Duration(seconds: 10));
        unawaited(h.score.setEvening(true));
        h.run(const Duration(seconds: 20));
        expect(
          h.transport.beds.every((v) => isBetweenBed(v.asset)),
          isTrue,
          reason: 'still the Between bed, mid-pass',
        );
        expect(isBetweenBed(h.score.nowPlaying.value), isTrue);
        h.run(const Duration(seconds: 30));
        final last = h.transport.beds.last;
        expect(isEveningBed(last.asset), isTrue);
        expect(isEveningBed(h.score.nowPlaying.value), isTrue);
        expect(h.score.evening, isTrue);
      });
    });

    test('a change after the next pass was prepared still makes it', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        // The next pass is prepared four seconds early, as the Between bed.
        h.runToPass(50.5);
        expect(isBetweenBed(h.transport.voices.last.asset), isTrue);
        final prepared = h.transport.voices.last;
        unawaited(h.score.setEvening(true));
        h.run(const Duration(milliseconds: 100));
        expect(prepared.released, isTrue, reason: 'the wrong bed is let go');
        h.run(const Duration(seconds: 6));
        expect(isEveningBed(h.transport.beds.last.asset), isTrue);
      });
    });

    test('a change inside the last 800 ms waits one more pass', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        // Prepared as Between; the boundary is about 0.4 s away.
        h.runToPass(52.9);
        unawaited(h.score.setEvening(true));
        h.run(const Duration(seconds: 1));
        expect(isBetweenBed(h.transport.beds.last.asset), isTrue);
        h.run(ScoreForm.pass);
        expect(isEveningBed(h.transport.beds.last.asset), isTrue);
      });
    });
  });

  group('a class kept', () {
    test('one swell, on the next strong beat after the chime', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        h.run(const Duration(seconds: 7, milliseconds: 123));
        final tap = h.now;
        h.score.classKept(after: _chime);
        h.run(const Duration(seconds: 4));

        final swell = h.transport.swells.single;
        expect(h.score.swellPlan, isNotNull, reason: 'in flight until it ends');
        // Where did it land? Its beat is its first sample plus the pre-roll.
        final beatAt = swell.zeroAt! + ScoreForm.swellPreRoll;
        final grid = h.beatOf(beatAt);
        expect(grid.beat.isEven, isTrue, reason: 'a strong beat');
        expect(
          grid.off.abs(),
          lessThanOrEqualTo(const Duration(milliseconds: 6)),
        );
        expect(beatAt, greaterThanOrEqualTo(tap + _chime));
        expect(
          beatAt - (tap + _chime),
          lessThan(ScoreForm.beat * 2),
          reason: 'the first strong beat, not a later one',
        );
        // The file is the one cut at that beat of the form.
        expect(swell.asset, ScoreForm.swellAsset((grid.beat ~/ 2) % 32));
        // The play call went out one pre-roll and one lag ahead.
        expect(swell.callAt, lessThan(beatAt - ScoreForm.swellPreRoll));
        // The bed was not touched.
        expect(h.transport.beds.single.lastVolume, 1.0);
      });
    });

    test('over a day of different taps, every swell is on a strong beat', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        var played = 0;
        for (var i = 0; i < 6; i++) {
          // Land each tap somewhere else in the beat and in the form.
          h.run(Duration(milliseconds: 11000 + i * 1733));
          if (h.now - h.anchor > ScoreForm.pass - const Duration(seconds: 14)) {
            h.run(const Duration(seconds: 16));
          }
          final tap = h.now;
          h.score.classKept(after: _chime);
          h.run(const Duration(seconds: 12));
          final swells = h.transport.swells.toList();
          if (swells.length > played) {
            final swell = swells.last;
            final beatAt = swell.zeroAt! + ScoreForm.swellPreRoll;
            final grid = h.beatOf(beatAt, from: h.score.clock.anchor);
            expect(grid.beat.isEven, isTrue, reason: 'tap $i');
            expect(
              grid.off.abs(),
              lessThanOrEqualTo(const Duration(milliseconds: 8)),
            );
            expect(beatAt, greaterThanOrEqualTo(tap + _chime));
            expect(beatAt - (tap + _chime), lessThan(ScoreForm.beat * 2));
            played = swells.length;
          }
        }
        expect(played, greaterThanOrEqualTo(4));
      });
    });

    test(
      'the swell holds its level for two bars and is gone with its file',
      () {
        _day((async) {
          final h = ScoreHarness(async);
          h.startPastTheFadeIn();
          h.score.classKept(after: _chime);
          h.run(const Duration(seconds: 3));
          final swell = h.transport.swells.single;
          // The envelope is in the file; the score only ever sends its duck.
          expect(swell.volumes.every((v) => v.volume == 1.0), isTrue);
          expect(swell.released, isFalse);
          expect(h.score.swellPlan, isNotNull);
          // Its file is 9.3 s from its play call: the release is still
          // ringing at the end of it, and it is let go half a second later.
          h.run(swell.callAt! + ScoreForm.swellLength - h.now);
          expect(
            swell.released,
            isFalse,
            reason: 'its release is still ringing',
          );
          h.run(const Duration(seconds: 1));
          expect(swell.released, isTrue);
          expect(h.score.swellPlan, isNull);
          // The bed is untouched throughout.
          expect(h.transport.beds.first.released, isFalse);
        });
      },
    );

    test(
      'Reduce Motion: the earliest beat is 310 ms, the wait stays short',
      () {
        _day((async) {
          final h = ScoreHarness(async);
          h.startPastTheFadeIn();
          h.run(const Duration(seconds: 5, milliseconds: 321));
          final tap = h.now;
          h.score.classKept(after: _chimeReduced);
          h.run(const Duration(seconds: 4));
          final swell = h.transport.swells.single;
          final beatAt = swell.zeroAt! + ScoreForm.swellPreRoll;
          // Never sooner than a swell can be prepared and started.
          expect(
            beatAt - tap,
            greaterThanOrEqualTo(const Duration(milliseconds: 310)),
          );
          expect(
            beatAt - tap,
            lessThan(
              const Duration(milliseconds: 310) +
                  ScoreForm.beat * 2 +
                  const Duration(milliseconds: 400),
            ),
          );
          expect(
            h.score.clock.lag,
            lessThan(const Duration(milliseconds: 100)),
          );
        });
      },
    );

    test('two classes kept close together make ONE swell: the second is the '
        'chime alone (no restart, no extension)', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        h.score.classKept(after: _chime);
        h.run(const Duration(seconds: 4));
        expect(h.transport.swells, hasLength(1));
        final first = h.transport.swells.single;
        // A second mark in the middle of the swell.
        h.score.classKept(after: _chime);
        h.run(const Duration(seconds: 6));
        expect(h.transport.swells, hasLength(1));
        expect(
          first.volumes.every((v) => v.volume == 1.0),
          isTrue,
          reason: 'the first swell is not cut short',
        );
        expect(
          h.log.where((l) => l.contains('already in flight')),
          hasLength(1),
        );
        // And a mark while the first is still only planned.
        h.run(const Duration(seconds: 12));
        h.score.classKept(after: _chime);
        h.score.classKept(after: _chime);
        h.run(const Duration(seconds: 6));
        expect(h.transport.swells, hasLength(2));
      });
    });

    test('after a swell has finished, the next mark gets its own', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        h.score.classKept(after: _chime);
        h.run(const Duration(seconds: 14));
        expect(h.transport.swells, hasLength(1));
        h.score.classKept(after: _chime);
        h.run(const Duration(seconds: 6));
        expect(h.transport.swells, hasLength(2));
      });
    });

    test('three tickets marked together are one gesture, one swell', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        // The shortcut marks three: its last chime hangs 2 x 180 ms later.
        h.score.classKept(after: _chime + const Duration(milliseconds: 360));
        h.run(const Duration(seconds: 6));
        expect(h.transport.swells, hasLength(1));
      });
    });

    test(
      'a mark in the first 4 s of the bed is answered by the chime alone',
      () {
        _day((async) {
          final h = ScoreHarness(async);
          h.startAndSettle();
          h.run(const Duration(seconds: 1));
          h.score.classKept(after: _chime);
          h.run(const Duration(seconds: 5));
          expect(h.transport.swells, isEmpty);
          expect(h.log.any((l) => l.contains('not been audible')), isTrue);
        });
      },
    );

    test('in the Evening a mark gets the chime alone: no swell', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn(evening: true);
        h.score.classKept(after: _chime);
        h.run(const Duration(seconds: 6));
        expect(h.transport.swells, isEmpty);
        expect(h.log.any((l) => l.contains('evening')), isTrue);
      });
    });

    test('after the evening bed has taken over, still no swell', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        unawaited(h.score.setEvening(true));
        h.run(ScoreForm.pass + const Duration(seconds: 10));
        expect(isEveningBed(h.transport.beds.last.asset), isTrue);
        h.score.classKept(after: _chime);
        h.run(const Duration(seconds: 6));
        expect(h.transport.swells, isEmpty);
      });
    });

    test(
      'a swell planned for the next pass is not played into the Evening',
      () {
        _day((async) {
          final h = ScoreHarness(async);
          h.startPastTheFadeIn();
          unawaited(h.score.setEvening(true));
          // Tap just before the pass ends: its strong beat is the next
          // pass's first, which will be the Evening bed.
          h.runToPass(52.2);
          h.score.classKept(after: _chime);
          h.run(const Duration(seconds: 12));
          expect(h.transport.swells, isEmpty);
          expect(h.log.any((l) => l.contains('evening bed')), isTrue);
        });
      },
    );

    test('nor one that would still be held when the Evening bed arrives', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        unawaited(h.score.setEvening(true));
        // Its beat is inside this pass, but its two bars are not.
        h.runToPass(47.0);
        h.score.classKept(after: _chime);
        h.run(const Duration(seconds: 12));
        expect(h.transport.swells, isEmpty);
        expect(
          h.log.any((l) => l.contains('run into the evening bed')),
          isTrue,
        );
      });
    });

    test(
      'a swell still sounding when the Evening arrives is let go softly',
      () {
        _day((async) {
          final h = ScoreHarness(async);
          h.startPastTheFadeIn();
          // Mark so its swell is still held across the pass boundary; the
          // evening is only asked for once the swell is sounding.
          h.runToPass(47.0);
          h.score.classKept(after: _chime);
          h.run(const Duration(seconds: 3));
          final swell = h.transport.swells.single;
          unawaited(h.score.setEvening(true));
          h.run(const Duration(seconds: 12));
          expect(isEveningBed(h.transport.beds.last.asset), isTrue);
          expect(swell.released, isTrue);
          // It fell to nothing, over about half a second, not all at once.
          final fade = swell.volumes.where((v) => v.volume < 1.0).toList();
          expect(fade.length, greaterThan(5));
          expect(fade.last.volume, lessThan(0.15));
        });
      },
    );
  });

  group('when the beat cannot be trusted', () {
    test('a playhead that has moved off the clock stops the swells', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        expect(h.score.clock.trusted, isTrue);
        // Something stalls the player (a call, a route change).
        h.transport.positionSkew = const Duration(milliseconds: -90);
        h.run(const Duration(seconds: 9));
        expect(h.score.clock.trusted, isFalse);
        h.score.classKept(after: _chime);
        h.run(const Duration(seconds: 4));
        expect(h.transport.swells, isEmpty);
        expect(h.log.any((l) => l.contains('not believed')), isTrue);
      });
    });

    test('within 40 ms is still believed', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        h.transport.positionSkew = const Duration(milliseconds: 25);
        h.run(const Duration(seconds: 17));
        expect(h.score.clock.trusted, isTrue);
      });
    });

    test('the next pass anchors the clock again', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        h.transport.positionSkew = const Duration(milliseconds: -90);
        h.run(const Duration(seconds: 9));
        expect(h.score.clock.trusted, isFalse);
        // A fresh source starts clean.
        h.transport.positionSkew = Duration.zero;
        h.run(ScoreForm.pass);
        expect(h.score.clock.trusted, isTrue);
        h.run(const Duration(seconds: 2));
        h.score.classKept(after: _chime);
        h.run(const Duration(seconds: 4));
        expect(h.transport.swells, hasLength(1));
      });
    });

    test('a start that cannot be measured is a bed with no swells', () {
      _day((async) {
        final h = ScoreHarness(async);
        // A playhead that never moves.
        h.transport.positionSkew = const Duration(hours: -1);
        h.startAndSettle();
        h.run(const Duration(seconds: 5));
        expect(h.score.isPlaying, isTrue, reason: 'the bed still plays');
        expect(h.score.clock.trusted, isFalse);
        h.score.classKept(after: _chime);
        h.run(const Duration(seconds: 4));
        expect(h.transport.swells, isEmpty);
        // And the passes still chain.
        h.run(ScoreForm.pass);
        expect(h.transport.beds.length, greaterThanOrEqualTo(2));
      });
    });

    test('a position read that fails at first is tried again', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.transport.positionErrors = 3;
        h.startAndSettle();
        expect(h.score.clock.trusted, isTrue);
      });
    });

    test('a playhead that reads a second ahead is not believed', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.transport.positionSkew = const Duration(seconds: 1);
        h.startAndSettle();
        h.run(const Duration(seconds: 5));
        expect(h.score.isPlaying, isTrue);
        expect(h.score.clock.trusted, isFalse);
        expect(h.log.any((l) => l.contains('not measured')), isTrue);
      });
    });

    test('a swell whose play call would be over 60 ms late is dropped', () {
      _day((async) {
        // Preparing takes a second: the beat is gone before the file is ready.
        final h = ScoreHarness(
          async,
          prepareTime: const Duration(milliseconds: 40),
        );
        h.startPastTheFadeIn();
        h.transport.prepareTime = const Duration(milliseconds: 1500);
        h.score.classKept(after: const Duration(milliseconds: 310));
        h.run(const Duration(seconds: 6));
        expect(h.transport.swells, isEmpty);
        expect(h.log.any((l) => l.contains('late')), isTrue);
        // The mark did no harm: the next one is answered.
        h.transport.prepareTime = const Duration(milliseconds: 40);
        h.run(const Duration(seconds: 2));
        h.score.classKept(after: _chime);
        h.run(const Duration(seconds: 4));
        expect(h.transport.swells, hasLength(1));
      });
    });

    test(
      'a start that lands 90 ms off its beat is stopped; 40 ms is played',
      () {
        _day((async) {
          final h = ScoreHarness(async);
          h.startPastTheFadeIn();
          h.transport.lagOverride = (voice) => voice.asset!.contains('swell')
              ? const Duration(milliseconds: 35 + 90)
              : const Duration(milliseconds: 35);
          h.score.classKept(after: _chime);
          h.run(const Duration(seconds: 4));
          final dropped = h.transport.where((a) => a.contains('swell_')).single;
          expect(dropped.released, isTrue, reason: 'let go within moments');
          expect(
            dropped.releasedAt! - dropped.zeroAt!,
            lessThan(const Duration(milliseconds: 250)),
            reason: 'still in its silent run-up',
          );
          expect(h.log.any((l) => l.contains('swell dropped')), isTrue);
          // 40 ms off is inside the budget.
          h.run(const Duration(seconds: 14));
          h.transport.lagOverride = (voice) => voice.asset!.contains('swell')
              ? const Duration(milliseconds: 35 + 40)
              : const Duration(milliseconds: 35);
          h.score.classKept(after: _chime);
          h.run(const Duration(seconds: 6));
          final kept = h.transport.swells.last;
          expect(kept.released, isFalse);
          expect(h.log.any((l) => l.contains('swell played')), isTrue);
        });
      },
    );

    test('a measured swell lag sharpens the next one', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        h.transport.lagOverride = (voice) => voice.asset!.contains('swell')
            ? const Duration(milliseconds: 55)
            : const Duration(milliseconds: 35);
        for (var i = 0; i < 3; i++) {
          h.score.classKept(after: _chime);
          h.run(const Duration(seconds: 14));
        }
        // The median has moved from the bed's 35 ms towards the swell's 55.
        expect(
          h.score.clock.lag,
          greaterThan(const Duration(milliseconds: 40)),
        );
      });
    });
  });

  group('performances of the form', () {
    // What the walk would play for [seed], pass by pass.
    List<int> reference(int seed, int takes) {
      final walk = PerformanceWalk(seed: seed);
      return [for (var i = 0; i < takes; i++) walk.take()];
    }

    List<int> dayOf(int seed, int passes) {
      late List<int> played;
      _day((async) {
        final h = ScoreHarness(async, walkSeed: seed);
        h.startAndSettle();
        h.run(ScoreForm.pass * (passes - 1));
        played = h.transport.performances;
      });
      return played;
    }

    test('each pass plays the walk\'s next performance, in order', () {
      final played = dayOf(11, 14);
      expect(played.length, greaterThanOrEqualTo(14));
      expect(played, reference(11, played.length));
    });

    test('never the same one twice in a row, all six before any repeats', () {
      for (final seed in [1, 2, 3, 99]) {
        final played = dayOf(seed, 18);
        expect(played.length, greaterThanOrEqualTo(18), reason: 'seed $seed');
        for (var i = 1; i < played.length; i++) {
          expect(
            played[i],
            isNot(played[i - 1]),
            reason: 'seed $seed, pass ${i + 1}',
          );
        }
        for (var bag = 0; bag + 6 <= played.length; bag += 6) {
          expect(
            played.sublist(bag, bag + 6).toSet(),
            {0, 1, 2, 3, 4, 5},
            reason: 'seed $seed, passes ${bag + 1} to ${bag + 6}',
          );
        }
      }
    });

    test('the same seed is the same day, another seed another day', () {
      expect(dayOf(8, 6), dayOf(8, 6));
      final days = {
        for (var seed = 20; seed < 28; seed++) dayOf(seed, 3).join(),
      };
      expect(days.length, greaterThan(4));
    });

    test('a pass is named in the log with its phase and performance', () {
      _day((async) {
        final h = ScoreHarness(async, walkSeed: 4);
        h.startAndSettle();
        final first = reference(4, 1).single;
        expect(
          h.log.any((l) => l.contains('between performance $first')),
          isTrue,
          reason: h.log.join(' | '),
        );
      });
    });

    test('a change of phase keeps the performance already chosen', () {
      _day((async) {
        final h = ScoreHarness(async, walkSeed: 5);
        h.startPastTheFadeIn();
        final ref = reference(5, 4);
        // The next pass is prepared four seconds early, as a Between bed.
        h.runToPass(50.5);
        final prepared = h.transport.voices.last;
        expect(ScoreForm.performanceOf(prepared.asset), ref[1]);
        unawaited(h.score.setEvening(true));
        h.run(const Duration(seconds: 6));
        final evening = h.transport.beds.last;
        expect(isEveningBed(evening.asset), isTrue);
        expect(
          ScoreForm.performanceOf(evening.asset),
          ref[1],
          reason: 'the same performance, now of the Evening bed',
        );
        // The walk goes on from there with nothing skipped or played twice.
        h.run(ScoreForm.pass);
        expect(h.transport.performances, ref.sublist(0, 3));
      });
    });

    test('a change inside the last 800 ms waits a pass and skips nothing', () {
      _day((async) {
        final h = ScoreHarness(async, walkSeed: 6);
        h.startPastTheFadeIn();
        final ref = reference(6, 4);
        h.runToPass(52.9);
        unawaited(h.score.setEvening(true));
        h.run(const Duration(seconds: 1));
        expect(isBetweenBed(h.transport.beds.last.asset), isTrue);
        expect(ScoreForm.performanceOf(h.transport.beds.last.asset), ref[1]);
        h.run(ScoreForm.pass);
        expect(isEveningBed(h.transport.beds.last.asset), isTrue);
        expect(ScoreForm.performanceOf(h.transport.beds.last.asset), ref[2]);
        expect(h.transport.performances, ref.sublist(0, 3));
      });
    });

    test('stopping and starting again carries the walk on, not back', () {
      _day((async) {
        final h = ScoreHarness(async, walkSeed: 9);
        final ref = reference(9, 4);
        h.startPastTheFadeIn();
        unawaited(h.score.stop(fade: Duration.zero));
        h.run(const Duration(milliseconds: 100));
        unawaited(h.score.start(evening: false));
        h.run(const Duration(seconds: 1));
        unawaited(h.score.stop(fade: Duration.zero));
        h.run(const Duration(milliseconds: 100));
        unawaited(h.score.start(evening: true));
        h.run(const Duration(seconds: 1));
        expect(h.transport.performances, ref.sublist(0, 3));
        expect(isEveningBed(h.transport.beds.last.asset), isTrue);
      });
    });

    test('the opener hands over to the walk\'s first performance', () {
      _day((async) {
        final h = ScoreHarness(async, walkSeed: 12);
        h.startAndSettle(evening: true, opener: true);
        h.run(const Duration(seconds: 94));
        final bed = h.transport.beds.single;
        expect(isEveningBed(bed.asset), isTrue);
        expect(ScoreForm.performanceOf(bed.asset), reference(12, 1).single);
      });
    });

    test('a swell is the same file whatever performance is under it', () {
      _day((async) {
        final h = ScoreHarness(async, walkSeed: 3);
        h.startPastTheFadeIn();
        final ref = reference(3, 2);
        void markAndCheck(int pass) {
          h.score.classKept(after: _chime);
          h.run(const Duration(seconds: 4));
          final swell = h.transport.swells.last;
          final beatAt = swell.zeroAt! + ScoreForm.swellPreRoll;
          final grid = h.beatOf(beatAt, from: h.score.clock.anchor);
          expect(grid.beat.isEven, isTrue, reason: 'pass $pass');
          expect(swell.asset, ScoreForm.swellAsset((grid.beat ~/ 2) % 32));
        }

        h.run(const Duration(seconds: 6));
        markAndCheck(1);
        // Into the second pass, whose bed is another performance.
        h.runToPass(48);
        h.run(const Duration(seconds: 22));
        expect(h.transport.performances, ref);
        markAndCheck(2);
        expect(h.transport.swells, hasLength(2));
      });
    });
  });

  group('stopping', () {
    test('Music off: 600 ms out, then every voice released', () async {
      fakeAsync((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        var done = false;
        unawaited(h.score.stop().then((_) => done = true));
        h.run(const Duration(milliseconds: 300));
        final bed = h.transport.beds.single;
        expect(bed.lastVolume, closeTo(0.5, 0.1));
        expect(done, isFalse);
        expect(h.score.nowPlaying.value, isNull, reason: 'said at once');
        h.run(const Duration(milliseconds: 400));
        expect(done, isTrue);
        expect(h.score.isPlaying, isFalse);
        expect(h.transport.live, isEmpty);
        // Nothing comes back by itself.
        h.run(ScoreForm.pass * 2);
        expect(h.transport.voices, hasLength(1));
      });
    });

    test('a swell in flight is retired with the bed', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        h.score.classKept(after: _chime);
        h.run(const Duration(seconds: 3));
        expect(h.transport.swells, hasLength(1));
        unawaited(h.score.stop());
        h.run(const Duration(seconds: 1));
        expect(h.transport.live, isEmpty);
        h.run(const Duration(seconds: 12));
        expect(h.transport.swells, hasLength(1));
      });
    });

    test('a swell still being prepared is retired with the bed', () {
      _day((async) {
        final h = ScoreHarness(
          async,
          prepareTime: const Duration(milliseconds: 300),
        );
        h.startPastTheFadeIn();
        h.score.classKept(after: _chime);
        h.run(const Duration(milliseconds: 100));
        unawaited(h.score.stop());
        h.run(const Duration(seconds: 12));
        expect(h.transport.live, isEmpty);
        expect(h.transport.swells, isEmpty, reason: 'it never sounded');
      });
    });

    test('a mark after the music is off does nothing', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        unawaited(h.score.stop());
        h.run(const Duration(seconds: 2));
        final voices = h.transport.voices.length;
        h.score.classKept(after: _chime);
        h.run(const Duration(seconds: 6));
        expect(h.transport.voices, hasLength(voices));
      });
    });

    test('starting during the fade-out cleans up and starts clean', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        unawaited(h.score.stop());
        h.run(const Duration(milliseconds: 200));
        unawaited(h.score.start(evening: false));
        h.run(const Duration(seconds: 2));
        expect(h.transport.live, hasLength(1));
        expect(isBetweenBed(h.transport.live.single.asset), isTrue);
        h.run(const Duration(seconds: 2, milliseconds: 500));
        expect(h.transport.live.single.lastVolume, 1.0);
      });
    });

    test('backgrounding: 200 ms out, released; back again, bar 1 on a 1.5 s '
        'fade, and no swell is owed', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        h.score.classKept(after: _chime);
        h.run(const Duration(seconds: 3));
        unawaited(h.score.setForeground(false));
        h.run(const Duration(milliseconds: 100));
        expect(h.transport.beds.first.lastVolume, lessThan(0.7));
        h.run(const Duration(milliseconds: 200));
        expect(h.transport.live, isEmpty);
        expect(h.score.isPlaying, isFalse);
        // Nothing starts while backgrounded.
        h.run(const Duration(seconds: 30));
        expect(h.transport.live, isEmpty);
        // Back: the controller restarts it.
        final before = h.transport.voices.length;
        unawaited(h.score.setForeground(true));
        unawaited(h.score.start(evening: false));
        h.run(const Duration(milliseconds: 200));
        final bed = h.transport.voices[before];
        expect(isBetweenBed(bed.asset), isTrue);
        h.run(const Duration(milliseconds: 650));
        expect(bed.lastVolume, closeTo(0.5, 0.15));
        h.run(const Duration(milliseconds: 900));
        expect(bed.lastVolume, 1.0, reason: '1.5 s, not 4 s');
        // A fresh start is a fresh 4 s fade again.
        unawaited(h.score.stop(fade: Duration.zero));
        h.run(const Duration(milliseconds: 10));
        unawaited(h.score.start(evening: false));
        h.run(const Duration(seconds: 1));
        expect(h.transport.voices.last.lastVolume, lessThan(0.4));
      });
    });

    test('dispose releases everything and ends it', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        unawaited(h.score.dispose());
        h.run(const Duration(seconds: 1));
        expect(h.transport.live, isEmpty);
        unawaited(h.score.start(evening: false));
        h.run(const Duration(seconds: 1));
        expect(h.transport.live, isEmpty);
      });
    });
  });

  group('sounds ducking the music', () {
    test('the shared duck scales the bed and the swell alike', () {
      _day((async) {
        var duck = 1.0;
        final h = ScoreHarness(async, duck: () => duck);
        h.startPastTheFadeIn();
        duck = 0.4;
        h.run(const Duration(milliseconds: 100));
        final bed = h.transport.beds.single;
        expect(bed.lastVolume, closeTo(0.4, 0.001));
        duck = 1.0;
        h.run(const Duration(milliseconds: 100));
        expect(bed.lastVolume, 1.0);
        h.score.classKept(after: _chime);
        h.run(const Duration(seconds: 3));
        duck = 0.4;
        h.run(const Duration(milliseconds: 100));
        expect(h.transport.swells.single.lastVolume, closeTo(0.4, 0.001));
      });
    });

    test('a steady level sends no volume calls', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        final bed = h.transport.beds.single;
        final calls = bed.volumes.length;
        h.run(const Duration(seconds: 20));
        expect(bed.volumes.length, calls);
      });
    });
  });

  group('Lamp left on, the opener', () {
    test('plays first on a 4 s fade and crossfades into the Evening bed', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startAndSettle(evening: true, opener: true);
        final opener = h.transport.voices.single;
        expect(opener.asset, 'music/lamp-left-on.m4a');
        expect(
          h.score.nowPlaying.value,
          MainRoomMusic.assetForTake(MainRoomMusic.lampLeftOnTake),
          reason: 'the evening door names Lamp left on from this',
        );
        h.run(const Duration(seconds: 4));
        expect(opener.lastVolume, 1.0);
        expect(h.transport.voices, hasLength(1));
        // At 93.5 s the Evening bed fades in over 2.5 s as the opener leaves.
        h.run(const Duration(seconds: 89, milliseconds: 150));
        expect(h.transport.voices, hasLength(2));
        final bed = h.transport.voices[1];
        expect(isEveningBed(bed.asset), isTrue);
        h.run(bed.callAt! + const Duration(milliseconds: 1250) - h.now);
        expect(bed.lastVolume, closeTo(0.5, 0.1));
        expect(opener.lastVolume, closeTo(0.5, 0.1));
        h.run(const Duration(milliseconds: 1500));
        expect(bed.lastVolume, 1.0);
        expect(opener.released, isTrue);
        expect(isEveningBed(h.score.nowPlaying.value), isTrue);
        // And the form carries on from there.
        h.run(ScoreForm.pass);
        expect(h.transport.beds.length, greaterThanOrEqualTo(2));
      });
    });

    test('no swell over the opener, or the Evening bed after it', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startAndSettle(evening: true, opener: true);
        h.run(const Duration(seconds: 10));
        h.score.classKept(after: _chime);
        h.run(const Duration(seconds: 6));
        expect(h.transport.swells, isEmpty);
      });
    });

    test('backgrounding during the opener does not resume it', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startAndSettle(evening: true, opener: true);
        h.run(const Duration(seconds: 20));
        unawaited(h.score.setForeground(false));
        h.run(const Duration(seconds: 1));
        expect(h.transport.live, isEmpty);
        unawaited(h.score.setForeground(true));
        unawaited(h.score.start(evening: true));
        h.run(const Duration(seconds: 2));
        expect(isEveningBed(h.transport.live.single.asset), isTrue);
      });
    });
  });

  group('when the chain breaks', () {
    test('a next pass that cannot be prepared restarts the bed from bar 1', () {
      _day((async) {
        final h = ScoreHarness(async);
        h.startPastTheFadeIn();
        var failing = true;
        h.transport.prepareFailure = (asset) =>
            failing ? StateError('disk') : null;
        h.run(ScoreForm.pass - const Duration(seconds: 3));
        failing = false;
        h.run(const Duration(seconds: 6));
        expect(h.transport.beds.length, greaterThanOrEqualTo(2));
        expect(h.score.isPlaying, isTrue);
        expect(h.log.any((l) => l.contains('could not be prepared')), isTrue);
      });
    });

    test(
      'three failures in a row end it, silent, without a loop of retries',
      () {
        _day((async) {
          final h = ScoreHarness(async);
          h.startPastTheFadeIn();
          h.transport.prepareFailure = (_) => StateError('disk');
          h.run(ScoreForm.pass * 2);
          expect(h.score.isPlaying, isFalse);
          expect(h.log.any((l) => l.contains('giving up')), isTrue);
        });
      },
    );
  });

  test('the stopwatch default measures real time and is monotonic', () {
    final score = ClassDayScore(
      transport: FakeScoreTransport(() => Duration.zero),
    );
    expect(score.isPlaying, isFalse);
    expect(score.clock.trusted, isFalse);
  });

  test('constants the design rests on', () {
    expect(ClassDayScore.lateDrop, const Duration(milliseconds: 60));
    expect(ClassDayScore.anchorPoll, const Duration(milliseconds: 12));
    expect(ClassDayScore.anchorPollCap, const Duration(milliseconds: 400));
    expect(ClassDayScore.recheckEvery, const Duration(seconds: 8));
    expect(ClassDayScore.bedAudibleBeforeSwell, const Duration(seconds: 4));
    expect(ClassDayScore.volumeStep, const Duration(milliseconds: 40));
    expect(_ms35, isNotNull);
  });
}
