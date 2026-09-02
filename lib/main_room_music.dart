import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'platform/audio_support_stub.dart'
    if (dart.library.js_interop) 'platform/audio_support_web.dart';

/// The normal-room music role. Focus music is deliberately owned by
/// [BackgroundMusicController] instead so the approved jazzy room rotation can
/// never silently collapse back into the meditation loop.
abstract interface class MainRoomMusicPlayback {
  bool get isPlaying;
  Future<void> setEnabled(bool enabled);
  Future<void> setForeground(bool foreground);
  Future<void> retryAfterUserGesture();
  Future<void> dispose();
}

/// Shuffle-bag over the eight approved umbrella-brush takes. Every bag plays
/// all eight before repeating, and the bag boundary cannot repeat a take.
class MusicRotation {
  MusicRotation({math.Random? random, this.takeCount = MainRoomMusic.takeCount})
    : _random = random ?? math.Random();

  final int takeCount;
  final math.Random _random;
  final List<int> _bag = <int>[];
  int? _last;

  int next() {
    if (_bag.isEmpty) _refill();
    final take = _bag.removeLast();
    _last = take;
    return take;
  }

  void _refill() {
    _bag.addAll([for (var take = 1; take <= takeCount; take++) take]);
    _bag.shuffle(_random);
    if (_bag.length > 1 && _bag.last == _last) {
      final swap = _random.nextInt(_bag.length - 1);
      final displaced = _bag[swap];
      _bag[swap] = _bag.last;
      _bag[_bag.length - 1] = displaced;
    }
  }
}

enum MusicDuckKind { ordinary, completion }

/// Pure gain math for keeping earned interaction sounds above the music bed.
class MusicDucker {
  static const double restGain = 1;
  static const double duckFloor = 0.40;
  static const Duration downRamp = Duration(milliseconds: 80);
  static const Duration recoveryRamp = Duration(milliseconds: 400);

  DateTime? _rampStart;
  DateTime? _holdUntil;
  double _rampFrom = restGain;

  void duck({required DateTime at, required DateTime until}) {
    final holdUntil = _holdUntil;
    if (holdUntil != null && !at.isAfter(holdUntil)) {
      if (until.isAfter(holdUntil)) _holdUntil = until;
      return;
    }
    _rampFrom = gainAt(at);
    _rampStart = at;
    _holdUntil = until;
  }

  double gainAt(DateTime now) {
    final rampStart = _rampStart;
    final holdUntil = _holdUntil;
    if (rampStart == null || holdUntil == null) return restGain;
    var sinceRamp = now.difference(rampStart);
    if (sinceRamp < Duration.zero) sinceRamp = Duration.zero;
    if (sinceRamp < downRamp) {
      final t = sinceRamp.inMicroseconds / downRamp.inMicroseconds;
      return _rampFrom + (duckFloor - _rampFrom) * t;
    }
    if (!now.isAfter(holdUntil)) return duckFloor;
    final sinceHold = now.difference(holdUntil);
    if (sinceHold >= recoveryRamp) return restGain;
    final t = sinceHold.inMicroseconds / recoveryRamp.inMicroseconds;
    return duckFloor + (restGain - duckFloor) * t;
  }

  @visibleForTesting
  void reset() {
    _rampStart = null;
    _holdUntil = null;
    _rampFrom = restGain;
  }
}

class _MusicVoice {
  _MusicVoice(this.player, {required this.startedAt}) : _fadeStart = startedAt;

  final AudioPlayer player;
  DateTime startedAt;
  StreamSubscription<void>? completeSub;
  DateTime _fadeStart;
  Duration _fadeLength = Duration.zero;
  double _fadeFrom = 0;
  double _fadeTo = 1;
  bool retired = false;

  void beginFade({
    required double from,
    required double to,
    required DateTime at,
    required Duration length,
  }) {
    _fadeFrom = from;
    _fadeTo = to;
    _fadeStart = at;
    _fadeLength = length;
  }

  double envelopeAt(DateTime now) {
    if (_fadeLength <= Duration.zero) return _fadeTo;
    var since = now.difference(_fadeStart);
    if (since < Duration.zero) {
      _fadeStart = now;
      since = Duration.zero;
    }
    if (since <= Duration.zero) return _fadeFrom;
    if (since >= _fadeLength) return _fadeTo;
    final t = since.inMicroseconds / _fadeLength.inMicroseconds;
    return _fadeFrom + (_fadeTo - _fadeFrom) * t;
  }

  bool fadedOut(DateTime now) =>
      _fadeTo == 0 && now.difference(_fadeStart) >= _fadeLength;
}

/// The owner-approved normal-room score: eight 96-second umbrella-brush takes
/// at 72 BPM, rotated without immediate repetition and crossfaded at the seam.
/// The masters carry their auditioned level in-file, so playback stays at
/// unity apart from fades and interaction ducking.
class MainRoomMusic implements MainRoomMusicPlayback {
  MainRoomMusic._({MusicRotation? rotation, MusicDucker? ducker})
    : _rotation = rotation ?? MusicRotation(),
      ducker = ducker ?? MusicDucker();

  @visibleForTesting
  MainRoomMusic.testing({MusicRotation? rotation, MusicDucker? ducker})
    : this._(rotation: rotation, ducker: ducker);

  static final MainRoomMusic instance = MainRoomMusic._();

  static const takeCount = 8;
  static String assetForTake(int take) =>
      'music/take_${take.toString().padLeft(2, '0')}.m4a';
  static final List<String> takeAssets = List<String>.unmodifiable([
    for (var take = 1; take <= takeCount; take++) assetForTake(take),
  ]);

  static const takeDuration = Duration(seconds: 96);
  static const crossfadeAt = Duration(milliseconds: 93500);
  static const crossfadeLength = Duration(milliseconds: 2500);
  static const startFadeIn = Duration(seconds: 4);
  static const resumeFadeIn = Duration(milliseconds: 1500);
  static const stopFadeOut = Duration(milliseconds: 600);
  static const lifecycleFadeOut = Duration(milliseconds: 200);
  static const volumeStep = Duration(milliseconds: 40);

  final MusicRotation _rotation;
  final MusicDucker ducker;

  bool _enabled = false;
  bool _initialized = false;
  bool _foreground = true;
  bool _disposed = false;
  bool _debugPlaying = false;
  int _transitionEpoch = 0;
  _MusicVoice? _current;
  _MusicVoice? _outgoing;
  _MusicVoice? _draining;
  Timer? _ticker;

  @visibleForTesting
  bool debugBypassPlayback = false;

  @visibleForTesting
  ValueChanged<String>? debugOnStartTake;

  bool get enabled => _enabled;

  bool get _hasActiveVoice => _debugPlaying || _current != null;

  @override
  bool get isPlaying =>
      _debugPlaying ||
      _current != null ||
      _outgoing != null ||
      _draining != null;

  @override
  Future<void> setEnabled(bool enabled) async {
    if (_disposed) return;
    final changed = _enabled != enabled;
    _enabled = enabled;
    if (!_initialized) {
      _initialized = true;
    }
    if (!changed &&
        (enabled == _hasActiveVoice || (kIsWeb && enabled && !isPlaying))) {
      return;
    }
    if (enabled) {
      if (_foreground && !_hasActiveVoice) {
        // A quick off -> on may arrive while the old voice is still draining.
        // Retire that fade before starting a fresh take; otherwise `isPlaying`
        // would stay true until the drain ends and strand the enabled intent.
        _stopNow();
        if (kIsWeb) {
        } else {
          _startTake(fadeIn: startFadeIn);
        }
      }
    } else {
      await _fadeOutAndWait();
    }
  }

  @override
  Future<void> setForeground(bool foreground) async {
    if (_disposed || _foreground == foreground) return;
    _foreground = foreground;
    if (!foreground) {
      await _fadeOutAndWait(fade: lifecycleFadeOut);
    } else if (_enabled && !_hasActiveVoice) {
      _stopNow();
      if (kIsWeb) {
      } else {
        _startTake(fadeIn: resumeFadeIn);
      }
    }
  }

  @override
  Future<void> retryAfterUserGesture() async {
    if (_disposed ||
        !_initialized ||
        !_enabled ||
        !_foreground ||
        _hasActiveVoice) {
      return;
    }
    if (kIsWeb && !browserAudioAvailable) return;
    _stopNow();
    _startTake(fadeIn: startFadeIn);
  }

  void duck({required DateTime until, MusicDuckKind? kind, DateTime? at}) {
    ducker.duck(at: at ?? DateTime.now(), until: until);
  }

  void _startTake({required Duration fadeIn}) {
    if (_disposed || !_enabled || !_foreground) return;
    final take = _rotation.next();
    final asset = takeAssets[take - 1];
    debugOnStartTake?.call(asset);
    if (debugBypassPlayback) {
      _debugPlaying = true;
      return;
    }
    if (kIsWeb && !browserAudioAvailable) return;
    final now = DateTime.now();
    final voice = _MusicVoice(AudioPlayer(), startedAt: now)
      ..beginFade(from: 0, to: 1, at: now, length: fadeIn);
    _current = voice;
    voice.completeSub = voice.player.onPlayerComplete.listen(
      (_) => _onVoiceComplete(voice),
    );
    unawaited(_startVoice(voice, asset));
    _ticker ??= Timer.periodic(volumeStep, (_) => _onTick());
  }

  Future<void> _startVoice(_MusicVoice voice, String asset) async {
    try {
      await voice.player.setAudioContext(
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
      if (!_voiceMayStart(voice)) {
        _retire(voice);
        return;
      }
      await voice.player.play(AssetSource(asset), volume: 0);
      // setAudioContext/play are asynchronous. A toggle or lifecycle change
      // may have retired this voice while either call was in flight.
      if (!_voiceMayStart(voice)) _retire(voice);
    } catch (error) {
      debugPrint('Main room music "$asset" failed (continuing silent): $error');
      _onVoiceStartFailed(voice);
    }
  }

  bool _voiceMayStart(_MusicVoice voice) =>
      !_disposed &&
      _enabled &&
      _foreground &&
      !voice.retired &&
      (identical(_current, voice) ||
          identical(_outgoing, voice) ||
          identical(_draining, voice));

  void _onVoiceStartFailed(_MusicVoice voice) {
    if (identical(_current, voice)) _current = null;
    if (identical(_outgoing, voice)) _outgoing = null;
    _retire(voice);
  }

  void _onVoiceComplete(_MusicVoice voice) {
    if (identical(_outgoing, voice)) {
      _outgoing = null;
      _retire(voice);
      return;
    }
    if (!identical(_current, voice)) return;
    _current = null;
    _retire(voice);
    if (_enabled && _foreground) _startTake(fadeIn: Duration.zero);
  }

  void _onTick() {
    final now = DateTime.now();
    final duckGain = ducker.gainAt(now);
    final current = _current;
    if (current != null) {
      if (now.isBefore(current.startedAt)) current.startedAt = now;
      _applyVolume(current, now, duckGain);
      if (_outgoing == null &&
          now.difference(current.startedAt) >= crossfadeAt) {
        _beginCrossfade(now);
      }
    }
    final outgoing = _outgoing;
    if (outgoing != null) {
      _applyVolume(outgoing, now, duckGain);
      if (outgoing.fadedOut(now)) {
        _outgoing = null;
        _retire(outgoing);
      }
    }
    final draining = _draining;
    if (draining != null) {
      _applyVolume(draining, now, duckGain);
      if (draining.fadedOut(now)) {
        _draining = null;
        _retire(draining);
      }
    }
    if (_current == null && _outgoing == null && _draining == null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _beginCrossfade(DateTime now) {
    final fading = _current;
    if (fading == null) return;
    fading.beginFade(
      from: fading.envelopeAt(now),
      to: 0,
      at: now,
      length: crossfadeLength,
    );
    _outgoing = fading;
    _current = null;
    _startTake(fadeIn: crossfadeLength);
  }

  void _fadeOutAndStop({Duration fade = stopFadeOut}) {
    if (debugBypassPlayback) {
      _debugPlaying = false;
      return;
    }
    final now = DateTime.now();
    final retiring = _outgoing;
    if (retiring != null) {
      _outgoing = null;
      final older = _draining;
      if (older != null) _retire(older);
      retiring.beginFade(
        from: retiring.envelopeAt(now),
        to: 0,
        at: now,
        length: fade,
      );
      _draining = retiring;
    }
    final current = _current;
    if (current == null) return;
    current.beginFade(
      from: current.envelopeAt(now),
      to: 0,
      at: now,
      length: fade,
    );
    _outgoing = current;
    _current = null;
  }

  Future<void> _fadeOutAndWait({Duration fade = stopFadeOut}) async {
    final epoch = ++_transitionEpoch;
    final needsDrain = !debugBypassPlayback && isPlaying;
    _fadeOutAndStop(fade: fade);
    if (!needsDrain || fade <= Duration.zero) return;
    await Future<void>.delayed(fade);
    if (epoch != _transitionEpoch || (_enabled && _foreground)) return;
    // The timer normally retires the voice on the same boundary. Finish it
    // synchronously here so callers may safely start a different music role
    // only after the old role is actually silent.
    _stopNow();
  }

  void _applyVolume(_MusicVoice voice, DateTime now, double duckGain) {
    final volume = (voice.envelopeAt(now) * duckGain).clamp(0.0, 1.0);
    voice.player.setVolume(volume).catchError((Object error) {
      debugPrint('Main room music volume failed (continuing): $error');
    });
  }

  void _retire(_MusicVoice? voice) {
    if (voice == null || voice.retired) return;
    voice.retired = true;
    unawaited(voice.completeSub?.cancel());
    voice.completeSub = null;
    final player = voice.player;
    unawaited(() async {
      try {
        await player.stop();
      } catch (error) {
        debugPrint('Main room music stop failed (continuing): $error');
      }
      try {
        await player.dispose();
      } catch (error) {
        debugPrint('Main room music dispose failed (continuing): $error');
      }
    }());
  }

  void _stopNow() {
    final current = _current;
    final outgoing = _outgoing;
    final draining = _draining;
    _current = null;
    _outgoing = null;
    _draining = null;
    _debugPlaying = false;
    _retire(current);
    _retire(outgoing);
    _retire(draining);
    _ticker?.cancel();
    _ticker = null;
  }

  @visibleForTesting
  void debugResetForTesting() {
    _stopNow();
    debugOnStartTake = null;
    debugBypassPlayback = false;
    _enabled = false;
    _initialized = false;
    _foreground = true;
    _disposed = false;
    _transitionEpoch++;
    ducker.reset();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _enabled = false;
    _transitionEpoch++;
    _stopNow();
  }
}
