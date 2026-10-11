// The class-day score: the room's music on a class day, and its answer when a
// class is kept.
//
// What it plays (assets/music/class_day, tool/author_class_day_score.py):
//   * two pre-mixed beds, Between classes and Evening: one 16-bar pass each
//     with its 6.5 s tail. The next pass is a second, already prepared source
//     started one pass (53.333 s) after the last began, while the first rings
//     out, so the chained passes are the circular loop with no gap and no
//     crossfade of coherent copies.
//   * thirty-two two-bar swells of bass and night bells, one per strong beat
//     of the form. When a class is kept, one is started on the next strong
//     beat after the chime has sounded, so the bass follows the chords, the
//     bells come in on the beat, and two bars later it has settled.
//
// What it cannot rely on: audioplayers has no loop point, no start-at-time
// and no shared clock. So nothing loops here, no stems run in parallel, and
// the beat clock is MEASURED: each pass is anchored by polling the source's
// position right after it starts, on a monotonic stopwatch (never the wall
// clock). If the clock cannot be believed, or a swell would start more than
// 60 ms from its beat, the swell is simply not played and the class chime
// alone answers. A mark never gets a wrong swell.
//
// It plays on the iOS ambient session with no Android audio focus, exactly
// like the room's other music, so the phone's mute switch silences it and it
// never interrupts, or pauses, the person's own audio. It is native only.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'class_day_score_clock.dart';
import 'main_room_music.dart' show MainRoomMusic;

// ── The platform seam ─────────────────────────────────────────────────────

/// One source the score can prepare, start on a beat, and read the position
/// of. A voice is used once and released.
abstract interface class ScoreVoice {
  /// Loads [asset] (a path under assets/) and returns once it is ready to
  /// start, at volume zero.
  Future<void> prepare(String asset);
  Future<void> setVolume(double volume);

  /// Starts the prepared source from its first sample.
  Future<void> start();

  /// The playhead, whole milliseconds on the platforms in use. Zero (or
  /// null) until the first sample has sounded.
  Future<Duration?> position();

  /// Stops and frees the source. Never throws.
  Future<void> release();
}

abstract interface class ScoreTransport {
  ScoreVoice createVoice();
}

/// The production transport: one audioplayers player per voice, on the same
/// ambient session and no-focus settings as the room's other music.
class AudioplayersScoreTransport implements ScoreTransport {
  const AudioplayersScoreTransport();

  @override
  ScoreVoice createVoice() => _AudioplayersScoreVoice();
}

class _AudioplayersScoreVoice implements ScoreVoice {
  AudioPlayer? _player;
  bool _released = false;

  @override
  Future<void> prepare(String asset) async {
    final player = AudioPlayer();
    _player = player;
    // No frame-by-frame position stream: the score reads the position itself,
    // on demand.
    player.positionUpdater = null;
    await player.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: const {},
        ),
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.none,
        ),
      ),
    );
    // Never ReleaseMode.loop: the iOS loop is a seek to zero on the main
    // thread, which gaps. A pass plays once and the next pass is a new source.
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(0);
    await player.setSource(AssetSource(asset));
  }

  @override
  Future<void> setVolume(double volume) => _player!.setVolume(volume);

  @override
  Future<void> start() => _player!.resume();

  @override
  Future<Duration?> position() => _player!.getCurrentPosition();

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    final player = _player;
    if (player == null) return;
    try {
      await player.stop();
    } catch (error) {
      debugPrint('Class-day score stop failed (continuing): $error');
    }
    try {
      await player.dispose();
    } catch (error) {
      debugPrint('Class-day score dispose failed (continuing): $error');
    }
  }
}

// ── What the controller sees ──────────────────────────────────────────────

/// The room's music on a class day, as BackgroundMusicController uses it.
abstract interface class ClassDayScorePlayback {
  /// Whether any voice is sounding (a fading one counts).
  bool get isPlaying;

  /// The file sounding now (an asset path under assets/), or null. The
  /// evening's music door names Lamp left on from this.
  ValueListenable<String?> get nowPlaying;

  /// Starts the score on the bed for the day's phase. [opener] plays Lamp
  /// left on first and crossfades into the Evening bed at its end.
  Future<void> start({required bool evening, bool opener = false});

  /// The phase the day is in. Applied at the next pass boundary.
  Future<void> setEvening(bool evening);

  /// A class was kept. [after] is how long from now the chime takes to
  /// finish sounding; a swell, if one is owed, starts on the first strong
  /// beat after that. Never plays over a swell, or in the Evening.
  void classKept({required Duration after});

  /// Fades everything out and awaits silence.
  Future<void> stop({Duration fade = MainRoomMusic.stopFadeOut});
  Future<void> setForeground(bool foreground);
  Future<void> dispose();
}

// ── The score ─────────────────────────────────────────────────────────────

enum _Kind { bed, swell, opener }

class _Voice {
  _Voice(this.handle, this.asset, this.kind, {this.evening = false});

  final ScoreVoice handle;
  final String asset;
  final _Kind kind;
  final bool evening;

  bool started = false;
  bool retired = false;

  /// When the play call went out, and when the first sample sounded (both on
  /// the stopwatch).
  Duration? callAt;
  Duration? zeroAt;

  double? sent;
  double _fadeFrom = 1;
  double _fadeTo = 1;
  Duration _fadeStart = Duration.zero;
  Duration _fadeLength = Duration.zero;

  void beginFade({
    required double from,
    required double to,
    required Duration at,
    required Duration length,
  }) {
    _fadeFrom = from;
    _fadeTo = to;
    _fadeStart = at;
    _fadeLength = length;
  }

  double envelopeAt(Duration now) {
    if (_fadeLength <= Duration.zero) return _fadeTo;
    final since = now - _fadeStart;
    if (since <= Duration.zero) return _fadeFrom;
    if (since >= _fadeLength) return _fadeTo;
    final t = since.inMicroseconds / _fadeLength.inMicroseconds;
    return _fadeFrom + (_fadeTo - _fadeFrom) * t;
  }

  bool fadedOut(Duration now) =>
      _fadeTo == 0 && now - _fadeStart >= _fadeLength;
}

class _Swell {
  _Swell(this.plan);

  final SwellPlan plan;
  _Voice? voice;
  bool cancelled = false;
}

class ClassDayScore implements ClassDayScorePlayback {
  ClassDayScore({
    required this.transport,
    Duration Function()? monotonic,
    double Function()? duckGain,
    ScoreClock? clock,
    this.openerAsset = 'music/lamp-left-on.m4a',
    this.log,
  }) : _now = monotonic ?? _stopwatch(),
       _duck = duckGain ?? (() => 1.0),
       _clock = clock ?? ScoreClock();

  static Duration Function() _stopwatch() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  /// The 40 ms volume tick the room's other music uses.
  static const volumeStep = MainRoomMusic.volumeStep;

  /// How long before a pass ends the next one is prepared. A local file takes
  /// a small fraction of this, and a phase change inside it still applies.
  static const prepareLead = Duration(seconds: 4);

  /// The least time a swell needs between the class being kept and its play
  /// call: enough to prepare a local file.
  static const minPrepare = Duration(milliseconds: 200);

  /// Right after a start, the position is read this often to find the
  /// moment of the first sample, for at most [anchorPollCap].
  static const anchorPoll = Duration(milliseconds: 12);
  static const anchorPollCap = Duration(milliseconds: 400);

  /// How often the anchor is checked against the playhead.
  static const recheckEvery = Duration(seconds: 8);

  /// A start further than this from its beat is dropped, not played.
  static const lateDrop = Duration(milliseconds: 60);

  /// A bed must have been sounding this long before a swell joins it, so a
  /// mark made as the music fades in is answered by the chime alone.
  static const bedAudibleBeforeSwell = Duration(seconds: 4);

  /// A swell still sounding when the Evening bed arrives is let go.
  static const swellLetGo = Duration(milliseconds: 500);

  /// A dropped swell leaves this quickly (it is still in its silent run-up).
  static const dropFade = Duration(milliseconds: 30);

  /// Where the voices come from.
  final ScoreTransport transport;
  final Duration Function() _now;
  final double Function() _duck;
  final ScoreClock _clock;

  /// The asset that plays first when the evening door is pressed.
  final String openerAsset;

  /// One line per decision worth reading on a device: a pass's start lag and
  /// anchor, a swell played or why it was not. Null prints in debug builds.
  final void Function(String line)? log;

  final ValueNotifier<String?> _nowPlaying = ValueNotifier<String?>(null);

  bool _foreground = true;
  bool _disposed = false;
  bool _running = false;
  bool _evening = false;
  bool _resumeFade = false;
  int _epoch = 0;
  int _passes = 0;
  int _recoveries = 0;
  Duration? _bedStartedAt;

  final List<_Voice> _voices = <_Voice>[];
  _Voice? _current;
  _Voice? _next;
  _Voice? _opener;
  _Swell? _swell;

  final Set<Timer> _timers = <Timer>{};
  Timer? _ticker;
  Timer? _checkTimer;

  /// The clock the beats are placed on. Exposed for tests and device logs.
  ScoreClock get clock => _clock;

  /// The swell in flight (planned, preparing or sounding), or null.
  SwellPlan? get swellPlan => _swell?.plan;

  @override
  ValueListenable<String?> get nowPlaying => _nowPlaying;

  @override
  bool get isPlaying => _voices.isNotEmpty;

  /// Whether the score is running (not fading out, not stopped).
  bool get running => _running;

  /// The phase being played, or about to be at the next pass boundary.
  bool get evening => _evening;

  // ── Starting and stopping ───────────────────────────────────────────────

  @override
  Future<void> start({required bool evening, bool opener = false}) async {
    if (_disposed || !_foreground) return;
    _stopNow();
    final epoch = ++_epoch;
    _running = true;
    _evening = evening;
    _passes = 0;
    _recoveries = 0;
    _bedStartedAt = null;
    final fade = _resumeFade
        ? MainRoomMusic.resumeFadeIn
        : MainRoomMusic.startFadeIn;
    _resumeFade = false;
    try {
      if (opener) {
        await _startOpener(epoch, fade);
      } else {
        await _startPass(epoch, fadeIn: fade);
      }
    } catch (error) {
      _note('start failed (continuing silent): $error');
      if (epoch == _epoch) _stopNow();
      rethrow;
    }
  }

  @override
  Future<void> stop({Duration fade = MainRoomMusic.stopFadeOut}) async {
    if (!_running && _voices.isEmpty) return;
    final epoch = ++_epoch;
    _running = false;
    // Said at once; the fade is only the sound leaving.
    _nowPlaying.value = null;
    _cancelTimers();
    _checkTimer?.cancel();
    _checkTimer = null;
    _swell = null;
    _next = null;
    _opener = null;
    _current = null;
    _clock.reset();
    final now = _now();
    for (final voice in [..._voices]) {
      if (!voice.started) {
        _retire(voice);
        continue;
      }
      voice.beginFade(
        from: voice.envelopeAt(now),
        to: 0,
        at: now,
        length: fade,
      );
    }
    if (fade <= Duration.zero || _voices.isEmpty) {
      _stopNow();
      return;
    }
    _ensureTicker();
    await Future<void>.delayed(fade);
    // A start() that arrived during the fade has already cleaned up.
    if (epoch != _epoch) return;
    _stopNow();
  }

  @override
  Future<void> setForeground(bool foreground) async {
    if (_disposed || _foreground == foreground) return;
    _foreground = foreground;
    if (!foreground) {
      // Back in the foreground the bed begins again from bar 1 on a short
      // fade-in; no swell is resumed.
      _resumeFade = _running || _voices.isNotEmpty;
      await stop(fade: MainRoomMusic.lifecycleFadeOut);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _stopNow();
    _nowPlaying.dispose();
  }

  // ── The phase ───────────────────────────────────────────────────────────

  @override
  Future<void> setEvening(bool evening) async {
    if (_evening == evening) return;
    _evening = evening;
    if (!_running) return;
    if (evening) {
      // A swell that has not sounded yet belongs to the Between bed.
      final swell = _swell;
      if (swell != null && !(swell.voice?.started ?? false)) {
        _cancelSwell('the evening came first');
      }
    }
    final next = _next;
    if (next != null && next.evening != evening) {
      final end = _current?.zeroAt;
      final room = end == null ? Duration.zero : end + ScoreForm.pass - _now();
      // Far enough from the boundary: prepare the right bed instead. Too
      // close, and the change waits one more pass.
      if (room > const Duration(milliseconds: 800)) {
        _next = null;
        _retire(next);
        unawaited(_prepareNext(_epoch));
      }
    }
  }

  // ── A class was kept ────────────────────────────────────────────────────

  @override
  void classKept({required Duration after}) {
    if (_disposed || !_running || !_foreground) return;
    final now = _now();
    final bed = _current;
    String? skip;
    if (bed == null || bed.retired) {
      skip = 'no bed is sounding yet';
    } else if (bed.evening) {
      skip = 'the evening bed has its own soft bass';
    } else if (_swell != null) {
      skip = 'a swell is already in flight';
    } else if (_bedStartedAt == null ||
        now - _bedStartedAt! < bedAudibleBeforeSwell) {
      skip = 'the bed has not been audible for 4 s';
    } else if (!_clock.trusted) {
      skip = 'the beat clock is not believed';
    }
    if (skip != null) {
      _note('swell skipped: $skip');
      return;
    }
    final needsAtLeast = now + minPrepare + ScoreForm.swellPreRoll + _clock.lag;
    final asked = now + after;
    final plan = _clock.planSwell(
      earliest: asked > needsAtLeast ? asked : needsAtLeast,
    );
    if (plan == null) {
      _note('swell skipped: the beat clock is not believed');
      return;
    }
    // Once the evening is wanted, the next pass is the Evening bed, which has
    // its own soft bass: a swell that would still be held when it arrives is
    // not started.
    final passEnd = _clock.anchor! + ScoreForm.pass;
    if (_evening && plan.beatAt + ScoreForm.beat * 8 > passEnd) {
      _note('swell skipped: it would run into the evening bed');
      return;
    }
    final swell = _Swell(plan);
    _swell = swell;
    _note(
      'swell planned: file ${plan.file} on beat ${plan.beat}, play call at '
      '${plan.startAt.inMilliseconds} ms (lag ${_clock.lag.inMilliseconds} ms)',
    );
    unawaited(_runSwell(swell, _epoch));
  }

  Future<void> _runSwell(_Swell swell, int epoch) async {
    try {
      final voice = await _prepare(
        ScoreForm.swellAsset(swell.plan.file),
        _Kind.swell,
        epoch,
        initial: _duck(),
      );
      if (voice == null) {
        if (identical(_swell, swell)) _swell = null;
        return;
      }
      swell.voice = voice;
      if (swell.cancelled) {
        _retire(voice);
        return;
      }
    } catch (error) {
      _note('swell dropped: could not prepare ($error)');
      if (identical(_swell, swell)) _swell = null;
      return;
    }
    _after(
      swell.plan.startAt - _now(),
      () => unawaited(_fireSwell(swell, epoch)),
    );
  }

  Future<void> _fireSwell(_Swell swell, int epoch) async {
    final voice = swell.voice;
    if (epoch != _epoch || swell.cancelled || voice == null) return;
    final late = _now() - swell.plan.startAt;
    if (late > lateDrop) {
      _dropSwell(
        swell,
        'its play call would be ${late.inMilliseconds} ms late',
      );
      return;
    }
    if (!_clock.trusted) {
      _dropSwell(swell, 'the beat clock is no longer believed');
      return;
    }
    try {
      await _begin(voice, epoch, fadeIn: Duration.zero);
    } catch (error) {
      _dropSwell(swell, 'could not start ($error)');
      return;
    }
    if (epoch != _epoch || swell.cancelled) return;
    // It is audible from here; whatever happens next, it ends with its file.
    _after(ScoreForm.swellLength + const Duration(milliseconds: 500), () {
      _retire(voice);
      if (identical(_swell, swell)) _swell = null;
    });
    final zero = await _measureStart(voice, epoch);
    if (epoch != _epoch || swell.cancelled || zero == null) return;
    voice.zeroAt = zero;
    _clock.noteLag(zero - voice.callAt!);
    final off = zero - (swell.plan.beatAt - ScoreForm.swellPreRoll);
    if (off.abs() > lateDrop) {
      // Still in its silent run-up and rise: leave quickly.
      voice.beginFade(
        from: voice.envelopeAt(_now()),
        to: 0,
        at: _now(),
        length: dropFade,
      );
      _note('swell dropped: it started ${off.inMilliseconds} ms from its beat');
      return;
    }
    _note('swell played: ${off.inMilliseconds} ms from its beat');
  }

  void _dropSwell(_Swell swell, String why) {
    swell.cancelled = true;
    final voice = swell.voice;
    if (voice != null) _retire(voice);
    if (identical(_swell, swell)) _swell = null;
    _note('swell dropped: $why');
  }

  void _cancelSwell(String why) {
    final swell = _swell;
    if (swell == null) return;
    _dropSwell(swell, why);
  }

  // ── Beds ────────────────────────────────────────────────────────────────

  Future<void> _startPass(int epoch, {required Duration fadeIn}) async {
    final evening = _evening;
    final voice = await _prepare(
      evening ? ScoreForm.bedEvening : ScoreForm.bedBetween,
      _Kind.bed,
      epoch,
      evening: evening,
      initial: fadeIn > Duration.zero ? 0 : _duck(),
    );
    if (voice == null) return;
    _current = voice;
    await _begin(voice, epoch, fadeIn: fadeIn);
    if (epoch != _epoch) return;
    _bedStartedAt ??= voice.callAt;
    _nowPlaying.value = voice.asset;
    unawaited(_anchorBed(voice, epoch));
  }

  /// Finds when [voice]'s first sample sounded and chains the next pass from
  /// it.
  Future<void> _anchorBed(_Voice voice, int epoch) async {
    final zero = await _measureStart(voice, epoch);
    if (epoch != _epoch || voice.retired) return;
    final callAt = voice.callAt!;
    final before = _clock.anchor;
    if (zero == null) {
      final nominal = callAt + _clock.lag;
      voice.zeroAt = nominal;
      _clock.anchorUnmeasured(nominal);
      _note(
        'pass ${_passes + 1}: start not measured, no swells until the next',
      );
    } else {
      voice.zeroAt = zero;
      _clock.noteLag(zero - callAt);
      _clock.anchorAt(zero);
      final drift = before == null
          ? ''
          : ', ${(zero - (before + ScoreForm.pass)).inMilliseconds} ms from '
                'the last pass plus a form';
      _note(
        'pass ${_passes + 1}: start lag ${(zero - callAt).inMilliseconds} ms$drift',
      );
    }
    _passes++;
    _scheduleChain(voice, epoch);
  }

  void _scheduleChain(_Voice voice, int epoch) {
    final end = voice.zeroAt! + ScoreForm.pass;
    final now = _now();
    _after(end - prepareLead - now, () => unawaited(_prepareNext(epoch)));
    _after(end - _clock.lag - now, () => unawaited(_startNext(epoch)));
    _checkTimer ??= Timer.periodic(
      recheckEvery,
      (_) => unawaited(_recheck(_epoch)),
    );
  }

  /// The next pass being prepared now, so the boundary can wait for it
  /// instead of preparing a second.
  Future<void>? _preparingNext;

  Future<void> _prepareNext(int epoch) {
    final running = _preparingNext;
    if (running != null) return running;
    final job = _prepareNextNow(epoch);
    _preparingNext = job;
    return job.whenComplete(() {
      if (identical(_preparingNext, job)) _preparingNext = null;
    });
  }

  Future<void> _prepareNextNow(int epoch) async {
    if (epoch != _epoch || !_running || _next != null) return;
    final evening = _evening;
    try {
      final voice = await _prepare(
        evening ? ScoreForm.bedEvening : ScoreForm.bedBetween,
        _Kind.bed,
        epoch,
        evening: evening,
        initial: _duck(),
      );
      if (voice == null) return;
      if (epoch != _epoch || !_running) {
        _retire(voice);
        return;
      }
      _next = voice;
    } catch (error) {
      _note('next pass could not be prepared (will try at its time): $error');
    }
  }

  Future<void> _startNext(int epoch) async {
    if (epoch != _epoch || !_running) return;
    final preparing = _preparingNext;
    if (preparing != null) await preparing;
    if (epoch != _epoch || !_running) return;
    var next = _next;
    _next = null;
    try {
      next ??= await _prepare(
        _evening ? ScoreForm.bedEvening : ScoreForm.bedBetween,
        _Kind.bed,
        epoch,
        evening: _evening,
        initial: _duck(),
      );
    } catch (error) {
      _note('next pass failed to prepare: $error');
      await _recover(epoch);
      return;
    }
    if (next == null) return;
    if (epoch != _epoch || !_running) {
      _retire(next);
      return;
    }
    final previous = _current;
    // The Evening bed has its own soft bass: a swell still sounding would
    // sit a few ms off it. Let the swell go, softly.
    if (next.evening) _letSwellGo();
    try {
      _current = next;
      await _begin(next, epoch, fadeIn: Duration.zero);
    } catch (error) {
      _note('next pass failed to start: $error');
      await _recover(epoch);
      return;
    }
    if (epoch != _epoch) return;
    _recoveries = 0;
    _nowPlaying.value = next.asset;
    if (previous != null) {
      // It rings out under the new pass; it is retired once its tail is over.
      _after(
        ScoreForm.bedTail + const Duration(seconds: 1),
        () => _retire(previous),
      );
    }
    unawaited(_anchorBed(next, epoch));
  }

  void _letSwellGo() {
    final swell = _swell;
    if (swell == null) return;
    final voice = swell.voice;
    if (voice == null || !voice.started) {
      _cancelSwell('the evening bed arrived first');
      return;
    }
    final now = _now();
    voice.beginFade(
      from: voice.envelopeAt(now),
      to: 0,
      at: now,
      length: swellLetGo,
    );
  }

  /// The chain broke (a pass could not be prepared or started). Begin again
  /// from bar 1 on a short fade; give up after three tries in a row.
  Future<void> _recover(int epoch) async {
    if (epoch != _epoch || !_running) return;
    if (++_recoveries > 3) {
      _note('giving up after three failed passes (continuing silent)');
      _stopNow();
      return;
    }
    _clock.reset();
    try {
      await _startPass(epoch, fadeIn: MainRoomMusic.resumeFadeIn);
    } catch (error) {
      _note('restart failed: $error');
      _after(const Duration(seconds: 2), () => unawaited(_recover(epoch)));
    }
  }

  Future<void> _recheck(int epoch) async {
    final voice = _current;
    if (epoch != _epoch ||
        voice == null ||
        voice.retired ||
        !_clock.trusted ||
        voice.zeroAt == null) {
      return;
    }
    final t0 = _now();
    // Not at either end of a pass: the next one is being handed over.
    if (t0 - voice.zeroAt! < const Duration(seconds: 1) ||
        voice.zeroAt! + ScoreForm.pass - t0 < const Duration(seconds: 2)) {
      return;
    }
    Duration? position;
    try {
      position = await voice.handle.position();
    } catch (_) {
      position = null;
    }
    final t1 = _now();
    if (epoch != _epoch || voice.retired) return;
    if (position == null) {
      _clock.distrust();
      _note('beat clock no longer believed: no playhead');
      return;
    }
    final measured = t0 + (t1 - t0) ~/ 2 - position;
    if (!_clock.agrees(measured)) {
      _clock.distrust();
      _note(
        'beat clock no longer believed: ${(measured - _clock.anchor!).inMilliseconds} '
        'ms off, no swells until the next pass',
      );
    }
  }

  // ── Lamp left on, the opener ────────────────────────────────────────────

  Future<void> _startOpener(int epoch, Duration fadeIn) async {
    final voice = await _prepare(openerAsset, _Kind.opener, epoch, initial: 0);
    if (voice == null) return;
    _opener = voice;
    await _begin(voice, epoch, fadeIn: fadeIn);
    if (epoch != _epoch) return;
    _nowPlaying.value = openerAsset;
    // Where the rotation would crossfade to its next take, the Evening bed
    // takes over.
    _after(MainRoomMusic.crossfadeAt, () => unawaited(_openerCrossfade(epoch)));
  }

  Future<void> _openerCrossfade(int epoch) async {
    final opener = _opener;
    if (epoch != _epoch || opener == null || !_running) return;
    final now = _now();
    opener.beginFade(
      from: opener.envelopeAt(now),
      to: 0,
      at: now,
      length: MainRoomMusic.crossfadeLength,
    );
    _opener = null;
    // The opener only plays in the evening; the bed follows the phase.
    try {
      await _startPass(epoch, fadeIn: MainRoomMusic.crossfadeLength);
    } catch (error) {
      _note('the evening bed could not follow the opener: $error');
      await _recover(epoch);
    }
  }

  // ── Voices, volumes and the clock ───────────────────────────────────────

  Future<_Voice?> _prepare(
    String asset,
    _Kind kind,
    int epoch, {
    bool evening = false,
    required double initial,
  }) async {
    final voice = _Voice(
      transport.createVoice(),
      asset,
      kind,
      evening: evening,
    );
    _voices.add(voice);
    try {
      await voice.handle.prepare(asset);
      voice.sent = initial;
      await voice.handle.setVolume(initial);
    } catch (_) {
      _retire(voice);
      rethrow;
    }
    if (epoch != _epoch || _disposed) {
      _retire(voice);
      return null;
    }
    return voice;
  }

  /// Sends the play call for a prepared [voice], noting when.
  Future<void> _begin(
    _Voice voice,
    int epoch, {
    required Duration fadeIn,
  }) async {
    final at = _now();
    voice.callAt = at;
    voice.beginFade(
      from: fadeIn > Duration.zero ? 0 : 1,
      to: 1,
      at: at,
      length: fadeIn,
    );
    await voice.handle.start();
    if (epoch != _epoch || voice.retired) {
      _retire(voice);
      return;
    }
    voice.started = true;
    _ensureTicker();
  }

  /// When [voice]'s first sample sounded, on the stopwatch: the position is
  /// read until it is above zero; the sample sounded that long before the
  /// middle of the read. Null if it never moved within [anchorPollCap], or if
  /// the answer cannot be true (a source cannot sound before its play call).
  Future<Duration?> _measureStart(_Voice voice, int epoch) async {
    final callAt = voice.callAt!;
    while (_now() - callAt <= anchorPollCap) {
      await Future<void>.delayed(anchorPoll);
      if (epoch != _epoch || voice.retired) return null;
      final t0 = _now();
      Duration? position;
      try {
        position = await voice.handle.position();
      } catch (_) {
        // A read can fail in the first moments of a start; try again.
        position = null;
      }
      final t1 = _now();
      if (epoch != _epoch || voice.retired) return null;
      if (position != null && position > Duration.zero) {
        final zero = t0 + (t1 - t0) ~/ 2 - position;
        // A playhead that reports a coarse or stale position (a second ahead)
        // would put the first sample before the call that started it.
        if (zero < callAt - const Duration(milliseconds: 20)) return null;
        return zero;
      }
    }
    return null;
  }

  void _ensureTicker() {
    _ticker ??= Timer.periodic(volumeStep, (_) => _onTick());
  }

  void _onTick() {
    final now = _now();
    final duck = _duck();
    for (final voice in [..._voices]) {
      if (voice.retired || !voice.started) continue;
      if (voice.fadedOut(now)) {
        _retire(voice);
        continue;
      }
      final volume = (voice.envelopeAt(now) * duck).clamp(0.0, 1.0);
      if (volume == voice.sent) continue;
      voice.sent = volume;
      unawaited(
        voice.handle.setVolume(volume).catchError((Object error) {
          debugPrint('Class-day score volume failed (continuing): $error');
        }),
      );
    }
    if (_voices.isEmpty) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _retire(_Voice voice) {
    if (voice.retired) return;
    voice.retired = true;
    _voices.remove(voice);
    if (identical(_current, voice)) _current = null;
    if (identical(_next, voice)) _next = null;
    if (identical(_opener, voice)) _opener = null;
    if (identical(_swell?.voice, voice)) _swell = null;
    unawaited(voice.handle.release());
  }

  void _cancelTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  Timer _after(Duration wait, void Function() callback) {
    late final Timer timer;
    timer = Timer(wait.isNegative ? Duration.zero : wait, () {
      _timers.remove(timer);
      callback();
    });
    _timers.add(timer);
    return timer;
  }

  /// Everything, at once, and every pending continuation made stale.
  void _stopNow() {
    _epoch++;
    _running = false;
    _cancelTimers();
    _checkTimer?.cancel();
    _checkTimer = null;
    _ticker?.cancel();
    _ticker = null;
    _swell = null;
    _next = null;
    _opener = null;
    _current = null;
    _preparingNext = null;
    for (final voice in [..._voices]) {
      _retire(voice);
    }
    _voices.clear();
    _clock.reset();
    if (!_disposed) _nowPlaying.value = null;
  }

  void _note(String line) {
    final sink = log;
    if (sink != null) {
      sink(line);
    } else if (kDebugMode) {
      debugPrint('Class-day score: $line');
    }
  }
}
