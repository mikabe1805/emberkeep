// Scripted class days, run through the REAL music controller and the REAL
// class-day score on fake time and a recording transport, written out as
// build/class_day_plan/*.json: every file the app would start, when, and every
// volume it would set. tool/mix_class_day_score.py then decodes the shipped
// files and mixes exactly that, so the proof WAV is made of the commands the
// app issues (it catches a wrong file or a wrong beat, not just an audio
// fault) rather than of a second implementation of them.
//
// The short day (plan.json, seconds from the music coming on, 14:00 on a
// Tuesday):
//    0  music on, a class day: the Between bed fades in over 4 s
//   20  first class kept: the chime hangs at 20.9, a swell on the next strong
//       beat after 20.95
//   24  a second class kept in the middle of that swell: the chime alone
//   36  a third, after it has settled: its own swell
//   44  the glass turns to the evening: the Evening bed at the next pass
//       boundary
//   66  a late class kept: the chime alone, the Evening bed has its own bass
//   75  music off: 600 ms fade
//
// The varied day (plan-varied.json) is long enough to cross three pass
// boundaries, and every pass is a different performance of the form:
//    0  music on: Between, pass 1
//   18  class kept: a swell        40  class kept: a swell
//   53  pass 2, another performance of the Between bed
//   66  class kept: a swell        88  class kept: a swell
//   96  the glass turns to the evening
//  107  pass 3, the Evening bed (the evening arrives at the boundary)
//  124  a late class kept: the chime alone
//  160  pass 4, another performance of the Evening bed
//  182  music off
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
const _variedOut = String.fromEnvironment(
  'CLASS_DAY_PLAN_VARIED_OUT',
  defaultValue: 'build/class_day_plan/plan-varied.json',
);

int _ms(Duration d) => d.inMicroseconds ~/ 1000;

/// One scripted day on fake time. Build it inside a fakeAsync callback.
class _Day {
  _Day(this.async, {required int walkSeed, required this.study}) {
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
      walk: PerformanceWalk(seed: walkSeed),
      log: log.add,
    );
    music = BackgroundMusicController(
      mainMusic: FakeMainMusic(),
      classDayScore: score,
      transport: FakeFocusTransport(),
    );
  }

  final FakeAsync async;
  final String study;
  final epoch = DateTime.utc(2026, 10, 6, 18); // 14:00 in New York
  final ducker = MusicDucker();
  final log = <String>[];
  final cues = <Map<String, Object>>[];
  final script = <Map<String, Object>>[];
  late final FakeScoreTransport transport;
  late final ClassDayScore score;
  late final BackgroundMusicController music;

  void run(Duration span) {
    async.elapse(span);
    async.flushMicrotasks();
  }

  void runTo(int seconds) {
    final wait = Duration(seconds: seconds) - async.elapsed;
    if (!wait.isNegative) run(wait);
  }

  void say(String what) => script.add({'t': _ms(async.elapsed), 'what': what});

  /// A class kept, as the Doorway and the page do it: the completion sound at
  /// the tap (it ducks the music for 460 ms), the controller told at once, and
  /// the chime when the ticket reaches its hook.
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

  /// Everything the day asked of the phone, as the mixdown reads it.
  Map<String, dynamic> finish() {
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
        'performance': ScoreForm.performanceOf(v.asset),
        'callAtMs': _ms(v.callAt!),
        // When the first sample sounded: what the phone would have done.
        'zeroAtMicros': v.zeroAt!.inMicroseconds,
        'releasedAtMs': v.releasedAt == null ? null : _ms(v.releasedAt!),
        'volumes': [
          for (final e in v.volumes) [e.at.inMicroseconds, e.volume],
        ],
      });
    }
    return {
      'study': study,
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
  }
}

void _write(String path, Map<String, dynamic> plan) {
  final out = File(path);
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(plan));
  expect(out.existsSync(), isTrue);
}

/// Both swells and beds of [plan], by kind.
List<Map<String, Object?>> _voices(Map<String, dynamic> plan, String kind) =>
    (plan['voices'] as List)
        .cast<Map<String, Object?>>()
        .where((v) => v['kind'] == kind)
        .toList();

/// Every swell sits on a strong beat of the grid of the bed it plays over.
void _expectSwellsOnStrongBeats(
  List<Map<String, Object?>> swells,
  List<Map<String, Object?>> beds,
) {
  for (final swell in swells) {
    final beatAt =
        (swell['zeroAtMicros']! as int) + ScoreForm.swellPreRoll.inMicroseconds;
    // The bed whose pass the beat falls in: the last one that began before it.
    final bed = beds.lastWhere(
      (b) => (b['zeroAtMicros']! as int) <= beatAt,
      orElse: () => beds.first,
    );
    final beats =
        (beatAt - (bed['zeroAtMicros']! as int)) *
        ScoreForm.beatsPerPass /
        ScoreForm.pass.inMicroseconds;
    expect(
      (beats - beats.round()).abs() * ScoreForm.beat.inMilliseconds,
      lessThan(8),
      reason: 'within 8 ms of a beat',
    );
    expect(beats.round().isEven, isTrue, reason: 'a strong beat');
  }
}

void main() {
  test('a scripted class day, written out for the mixdown', () {
    late Map<String, dynamic> plan;
    late _Day day;

    fakeAsync((async) {
      day = _Day(async, walkSeed: 2, study: 'class-day-score proof');
      day.say('music on, a class day, between classes');
      unawaited(day.music.setClassDay(true));
      unawaited(day.music.setEnabled(true));
      day.run(const Duration(milliseconds: 100));

      day.runTo(20);
      day.keepClass(1);
      day.runTo(24);
      day.keepClass(2);
      day.runTo(36);
      day.keepClass(3);
      day.runTo(44);
      day.say('the glass turns to the evening');
      unawaited(day.music.setClassDay(true, evening: true));
      day.runTo(66);
      day.keepClass(4);
      day.runTo(75);
      day.say('music off');
      unawaited(day.music.setEnabled(false));
      day.run(const Duration(seconds: 2));
      plan = day.finish();
      unawaited(day.music.dispose());
      async.flushMicrotasks();
    });

    // What the day did.
    final swells = _voices(plan, 'swell');
    final beds = _voices(plan, 'bed');
    expect(
      swells,
      hasLength(2),
      reason: 'marks 1 and 3; 2 and 4 get the chime',
    );
    expect(beds, hasLength(2));
    expect(isBetweenBed(beds[0]['asset']! as String), isTrue);
    expect(isEveningBed(beds[1]['asset']! as String), isTrue);
    expect(
      beds[0]['performance'],
      isNot(beds[1]['performance']),
      reason: 'the second pass is another performance',
    );
    // The evening came in at the first pass boundary after 44 s, and the late
    // mark at 66 s got no swell.
    expect(
      (beds[1]['zeroAtMicros']! as int) / 1e6,
      closeTo(53.4, 0.3),
      reason: 'one pass after the first bed, ~53.3 s plus its 4 s head',
    );
    // Both swells sit on strong beats of the first bed's grid.
    _expectSwellsOnStrongBeats(swells, beds);
    expect(day.log.any((l) => l.contains('already in flight')), isTrue);
    expect(day.log.any((l) => l.contains('evening bed')), isTrue);
    _write(_planOut, plan);
  });

  test('a longer day: three pass boundaries, a different performance each '
      'pass, written out for the mixdown', () {
    late Map<String, dynamic> plan;
    late _Day day;

    fakeAsync((async) {
      // A seed whose first four are all performances after the sketch's.
      day = _Day(async, walkSeed: 1, study: 'class-day-score varied proof');
      day.say('music on, a class day, between classes');
      unawaited(day.music.setClassDay(true));
      unawaited(day.music.setEnabled(true));
      day.run(const Duration(milliseconds: 100));

      day.runTo(18);
      day.keepClass(1);
      day.runTo(40);
      day.keepClass(2);
      day.runTo(66);
      day.keepClass(3);
      day.runTo(88);
      day.keepClass(4);
      day.runTo(96);
      day.say('the glass turns to the evening');
      unawaited(day.music.setClassDay(true, evening: true));
      day.runTo(124);
      day.keepClass(5);
      day.runTo(182);
      day.say('music off');
      unawaited(day.music.setEnabled(false));
      day.run(const Duration(seconds: 2));
      plan = day.finish();
      unawaited(day.music.dispose());
      async.flushMicrotasks();
    });

    final swells = _voices(plan, 'swell');
    final beds = _voices(plan, 'bed');
    // Four passes: three boundaries crossed.
    expect(beds, hasLength(4));
    final performances = [for (final b in beds) b['performance']! as int];
    expect(performances.toSet(), hasLength(4), reason: 'four different ones');
    expect(performances, [for (var i = 0; i < 4; i++) isNot(0)]);
    expect(
      performances,
      (() {
        final walk = PerformanceWalk(seed: 1);
        return [for (var i = 0; i < 4; i++) walk.take()];
      })(),
      reason: 'the walk the seed names, one step a pass',
    );
    // Between, Between, then the Evening twice.
    expect(
      [for (final b in beds) isEveningBed(b['asset']! as String)],
      [false, false, true, true],
    );
    for (var i = 1; i < beds.length; i++) {
      final gap =
          (beds[i]['zeroAtMicros']! as int) -
          (beds[i - 1]['zeroAtMicros']! as int);
      expect(
        (gap - ScoreForm.pass.inMicroseconds).abs(),
        lessThan(15000),
        reason: 'one form between first samples, boundary $i',
      );
    }
    // Marks 1 to 4 are answered with swells (all in Between passes, each
    // after the last has settled); the mark in the Evening gets the chime.
    expect(swells, hasLength(4));
    for (final swell in swells) {
      expect(isEveningBed(swell['asset']! as String), isFalse);
    }
    _expectSwellsOnStrongBeats(swells, beds);
    expect(day.log.any((l) => l.contains('evening bed')), isTrue);
    _write(_variedOut, plan);
  });
}
