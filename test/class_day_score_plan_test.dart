// A scripted class day, run through the REAL music controller and the REAL
// class-day score on fake time and a recording transport, written out as
// build/class_day_plan/plan.json: every file the app would start, when, and
// every volume it would set. tool/mix_class_day_score.py then decodes the
// shipped files and mixes exactly that, so the proof WAV is made of the
// commands the app issues (it catches a wrong file or a wrong beat, not just
// an audio fault) rather than of a second implementation of them.
//
// The day (seconds from the music coming on, 14:00 on a Tuesday):
//    0  music on, a class day: the Between bed fades in over 4 s
//   20  first class kept: the chime hangs at 20.9, a swell on the next strong
//       beat after 20.95
//   24  a second class kept in the middle of that swell: the chime alone
//   36  a third, after it has settled: its own swell
//   44  the glass turns to the evening: the Evening bed at the next pass
//       boundary
//   66  a late class kept: the chime alone, the Evening bed has its own bass
//   75  music off: 600 ms fade
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:emberkeep/background_music.dart';
import 'package:emberkeep/class_day_score.dart';
import 'package:emberkeep/class_day_score_clock.dart';
import 'package:emberkeep/main_room_music.dart';
import 'package:emberkeep/widgets/class_day/doorway_cues.dart';
import 'package:emberkeep/widgets/class_day/doorway_motion.dart'
    show doorwayChimeDoneAfter, doorwayHangMs;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/class_day_score_harness.dart';

const _planOut = String.fromEnvironment(
  'CLASS_DAY_PLAN_OUT',
  defaultValue: 'build/class_day_plan/plan.json',
);

int _ms(Duration d) => d.inMicroseconds ~/ 1000;

void main() {
  test('a scripted class day, written out for the mixdown', () {
    late Map<String, dynamic> plan;
    late FakeScoreTransport transport;
    late ClassDayScore score;
    final log = <String>[];

    fakeAsync((async) {
      final epoch = DateTime.utc(2026, 10, 6, 18); // 14:00 in New York
      final ducker = MusicDucker();
      transport = FakeScoreTransport(
        () => async.elapsed,
        // A typical start: the platform sounds the first sample ~38 ms after
        // the play call, and a local file prepares in ~45 ms.
        startLag: const Duration(milliseconds: 38),
        prepareTime: const Duration(milliseconds: 45),
      );
      score = ClassDayScore(
        transport: transport,
        monotonic: () => async.elapsed,
        duckGain: () => ducker.gainAt(epoch.add(async.elapsed)),
        log: log.add,
      );
      final music = BackgroundMusicController(
        mainMusic: FakeMainMusic(),
        classDayScore: score,
        transport: FakeFocusTransport(),
      );
      final cues = <Map<String, Object>>[];
      final script = <Map<String, Object>>[];

      void run(Duration span) {
        async.elapse(span);
        async.flushMicrotasks();
      }

      void runTo(int seconds) {
        final wait = Duration(seconds: seconds) - async.elapsed;
        if (!wait.isNegative) run(wait);
      }

      void say(String what) =>
          script.add({'t': _ms(async.elapsed), 'what': what});

      // A class kept, as the Doorway and the page do it: the completion
      // sound at the tap (it ducks the music for 460 ms), the controller told
      // at once, and the chime when the ticket reaches its hook.
      void keepClass(int step) {
        final now = async.elapsed;
        say('class $step kept');
        ducker.duck(
          at: epoch.add(now),
          until: epoch.add(now + const Duration(milliseconds: 460)),
        );
        cues.add({
          't': _ms(now),
          'asset': 'sfx/room/completion/completion-composite.wav',
          'volume': 1.0,
          'what': 'completion',
        });
        music.classKept(after: doorwayChimeDoneAfter(reduceMotion: false));
        cues.add({
          't': _ms(now) + doorwayHangMs.round(),
          'asset': 'sfx/room/class_chime/${DoorwayCues.chimeStepFor(step)}.wav',
          'volume': DoorwayCues.chimeVolume,
          'what': 'chime $step',
        });
      }

      say('music on, a class day, between classes');
      unawaited(music.setClassDay(true));
      unawaited(music.setEnabled(true));
      run(const Duration(milliseconds: 100));

      runTo(20);
      keepClass(1);
      runTo(24);
      keepClass(2);
      runTo(36);
      keepClass(3);
      runTo(44);
      say('the glass turns to the evening');
      unawaited(music.setClassDay(true, evening: true));
      runTo(66);
      keepClass(4);
      runTo(75);
      say('music off');
      unawaited(music.setEnabled(false));
      run(const Duration(seconds: 2));

      final voices = <Map<String, Object?>>[];
      for (final v in transport.voices) {
        if (v.callAt == null) continue;
        voices.add({
          'id': v.id,
          'asset': v.asset,
          'kind': v.asset!.contains('swell_')
              ? 'swell'
              : v.asset!.contains('bed_')
              ? 'bed'
              : 'opener',
          'callAtMs': _ms(v.callAt!),
          // When the first sample sounded: what the phone would have done.
          'zeroAtMicros': v.zeroAt!.inMicroseconds,
          'releasedAtMs': v.releasedAt == null ? null : _ms(v.releasedAt!),
          'volumes': [
            for (final e in v.volumes) [e.at.inMicroseconds, e.volume],
          ],
        });
      }
      plan = {
        'study': 'class-day-score proof',
        'sampleRate': 48000,
        'durationMs': _ms(async.elapsed),
        'startLagMs': 38,
        'script': script,
        'cues': cues,
        'voices': voices,
        'log': log,
        'form': {
          'beatMicros': ScoreForm.beat.inMicroseconds,
          'passMicros': ScoreForm.pass.inMicroseconds,
          'swellPreRollMs': ScoreForm.swellPreRoll.inMilliseconds,
        },
      };
      unawaited(music.dispose());
      async.flushMicrotasks();
    });

    // What the day did.
    final voices = (plan['voices'] as List).cast<Map<String, Object?>>();
    final swells = voices.where((v) => v['kind'] == 'swell').toList();
    final beds = voices.where((v) => v['kind'] == 'bed').toList();
    expect(
      swells,
      hasLength(2),
      reason: 'marks 1 and 3; 2 and 4 get the chime',
    );
    expect(beds.map((v) => v['asset']).toSet(), {
      ScoreForm.bedBetween,
      ScoreForm.bedEvening,
    });
    // The evening came in at the first pass boundary after 44 s, and the late
    // mark at 66 s got no swell.
    final evening = beds.firstWhere((v) => v['asset'] == ScoreForm.bedEvening);
    expect(
      (evening['zeroAtMicros']! as int) / 1e6,
      closeTo(53.4, 0.3),
      reason: 'one pass after the first bed, ~53.3 s plus its 4 s head',
    );
    // Both swells sit on strong beats of the first bed's grid.
    final firstZero = (beds.first['zeroAtMicros']! as int);
    for (final swell in swells) {
      final beatAt =
          (swell['zeroAtMicros']! as int) +
          ScoreForm.swellPreRoll.inMicroseconds;
      final beats =
          (beatAt - firstZero) *
          ScoreForm.beatsPerPass /
          ScoreForm.pass.inMicroseconds;
      expect(
        (beats - beats.round()).abs() * ScoreForm.beat.inMilliseconds,
        lessThan(8),
        reason: 'within 8 ms of a beat',
      );
      expect(beats.round().isEven, isTrue, reason: 'a strong beat');
    }
    expect(log.any((l) => l.contains('already in flight')), isTrue);
    expect(log.any((l) => l.contains('evening bed')), isTrue);

    final out = File(_planOut);
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(plan));
    expect(out.existsSync(), isTrue);
  });
}
