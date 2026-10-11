// A fake audio transport and a fake-time harness for the class-day score.
//
// The score only ever asks a voice to prepare, set a volume, start, report its
// position and release. This fake records those calls with the (fake)
// stopwatch time they happened at, and answers `position()` the way a player
// that starts [startLag] after its play call would, in whole milliseconds. So
// a test can play a whole class day in zero wall time and read back exactly
// what the app would have asked of the phone.
import 'dart:async';

import 'package:emberkeep/background_music.dart';
import 'package:emberkeep/class_day_score.dart';
import 'package:emberkeep/class_day_score_clock.dart';
import 'package:emberkeep/main_room_music.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';

class FakeScoreVoice implements ScoreVoice {
  FakeScoreVoice(this.transport, this.id);

  final FakeScoreTransport transport;
  final int id;
  String? asset;

  /// When the play call went out and when the first sample sounded.
  Duration? callAt;
  Duration? zeroAt;
  Duration? releasedAt;
  Duration? preparedAt;
  bool released = false;

  /// Every setVolume call, with when it was made.
  final List<({Duration at, double volume})> volumes = [];

  double get lastVolume => volumes.isEmpty ? 0 : volumes.last.volume;

  /// The volume that was in force at [at] (the last call before it).
  double volumeAt(Duration at) {
    var v = 0.0;
    for (final entry in volumes) {
      if (entry.at > at) break;
      v = entry.volume;
    }
    return v;
  }

  @override
  Future<void> prepare(String asset) async {
    transport.calls.add('prepare:$asset');
    final failure = transport.prepareFailure?.call(asset);
    if (failure != null) throw failure;
    await Future<void>.delayed(transport.prepareTime);
    this.asset = asset;
    preparedAt = transport.now();
  }

  @override
  Future<void> setVolume(double volume) async {
    volumes.add((at: transport.now(), volume: volume));
  }

  @override
  Future<void> start() async {
    callAt = transport.now();
    zeroAt = callAt! + transport.startLagFor(this);
    transport.calls.add('start:$asset');
  }

  @override
  Future<Duration?> position() async {
    if (transport.positionErrors > 0) {
      transport.positionErrors--;
      throw StateError('the player is not ready to say');
    }
    final zero = zeroAt;
    if (zero == null) return null;
    final since = transport.now() - zero + transport.positionSkew;
    if (since.isNegative) return Duration.zero;
    // Whole milliseconds, as the platforms report.
    return Duration(milliseconds: since.inMilliseconds);
  }

  @override
  Future<void> release() async {
    if (released) return;
    released = true;
    releasedAt = transport.now();
    transport.calls.add('release:$asset');
  }
}

class FakeScoreTransport implements ScoreTransport {
  FakeScoreTransport(
    this.now, {
    this.startLag = const Duration(milliseconds: 35),
    this.prepareTime = const Duration(milliseconds: 40),
  });

  final Duration Function() now;
  Duration startLag;
  Duration prepareTime;

  /// Added to every position read: a playhead that no longer agrees with the
  /// stopwatch (an interruption, a stall).
  Duration positionSkew = Duration.zero;

  /// The next this many position reads throw.
  int positionErrors = 0;

  /// Per-voice override of [startLag].
  Duration Function(FakeScoreVoice voice)? lagOverride;

  /// Throws for an asset to fail its prepare.
  Object? Function(String asset)? prepareFailure;

  final List<FakeScoreVoice> voices = [];
  final List<String> calls = [];

  Duration startLagFor(FakeScoreVoice voice) =>
      lagOverride?.call(voice) ?? startLag;

  @override
  ScoreVoice createVoice() {
    final voice = FakeScoreVoice(this, voices.length);
    voices.add(voice);
    return voice;
  }

  Iterable<FakeScoreVoice> where(bool Function(String asset) test) =>
      voices.where((v) => v.asset != null && test(v.asset!));

  Iterable<FakeScoreVoice> get beds =>
      where((a) => a.contains('bed_')).where((v) => v.callAt != null);

  Iterable<FakeScoreVoice> get swells =>
      where((a) => a.contains('swell_')).where((v) => v.callAt != null);

  /// Voices not yet released.
  Iterable<FakeScoreVoice> get live => voices.where((v) => !v.released);
}

/// A score on fake time. Build it inside a `fakeAsync` callback.
class ScoreHarness {
  ScoreHarness(
    this.async, {
    Duration startLag = const Duration(milliseconds: 35),
    Duration prepareTime = const Duration(milliseconds: 40),
    double Function()? duck,
  }) {
    transport = FakeScoreTransport(
      () => async.elapsed,
      startLag: startLag,
      prepareTime: prepareTime,
    );
    score = ClassDayScore(
      transport: transport,
      monotonic: () => async.elapsed,
      duckGain: duck,
      log: log.add,
    );
  }

  final FakeAsync async;
  late final FakeScoreTransport transport;
  late final ClassDayScore score;
  final List<String> log = [];

  Duration get now => async.elapsed;

  /// Lets everything due, and every continuation of it, run.
  void run(Duration span) {
    async.elapse(span);
    async.flushMicrotasks();
  }

  /// Starts the score and runs until the first pass is anchored.
  void startAndSettle({bool evening = false, bool opener = false}) {
    unawaited(score.start(evening: evening, opener: opener));
    run(const Duration(milliseconds: 600));
  }

  /// Runs until the current pass is [seconds] old (by its anchor).
  void runToPass(double seconds) {
    final target = anchor + Duration(microseconds: (seconds * 1e6).round());
    final wait = target - now;
    if (!wait.isNegative) run(wait);
  }

  /// Runs until the bed has been audible long enough for a swell (4 s).
  void startPastTheFadeIn({bool evening = false}) {
    startAndSettle(evening: evening);
    run(const Duration(seconds: 4));
  }

  /// The anchor of the pass sounding now.
  Duration get anchor => score.clock.anchor!;

  /// Seconds into the current pass.
  double get passSeconds => (now - anchor).inMicroseconds / 1e6;

  /// The index of the beat nearest to [at] on the current anchor's grid, and
  /// how far from the grid [at] is.
  ({int beat, Duration off}) beatOf(Duration at, {Duration? from}) {
    final grid = from ?? anchor;
    final n =
        ((at - grid).inMicroseconds *
                ScoreForm.beatsPerPass /
                ScoreForm.pass.inMicroseconds)
            .round();
    return (beat: n, off: at - ScoreForm.beatAt(grid, n));
  }
}

/// The rotation, recorded instead of played.
class FakeMainMusic implements MainRoomMusicPlayback {
  bool enabled = false;
  final List<String> calls = [];

  @override
  bool get isPlaying => enabled;

  @override
  final ValueNotifier<String?> nowPlaying = ValueNotifier<String?>(null);

  @override
  void preferNextTake(int take) => calls.add('prefer:$take');

  @override
  Future<void> setEnabled(bool value) async {
    if (enabled == value) return;
    enabled = value;
    calls.add(value ? 'start' : 'pause');
  }

  @override
  Future<void> setForeground(bool value) async {}

  @override
  Future<void> retryAfterUserGesture() async {}

  @override
  Future<void> dispose() async {}
}

/// The Focus loop's transport, doing nothing.
class FakeFocusTransport implements BackgroundMusicTransport {
  @override
  Future<void> dispose() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> startOrResumeLoop(
    String asset, {
    required double volume,
  }) async {}
}
