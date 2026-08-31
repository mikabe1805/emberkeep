import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// The one optional long-lived music voice. It is deliberately separate from
/// [Sfx]: interaction sound remains available whether music is on or off.
abstract interface class BackgroundMusicTransport {
  /// Starts [asset] once, then resumes that same looping source after pauses.
  Future<void> startOrResumeLoop(String asset, {required double volume});
  Future<void> setVolume(double volume);
  Future<void> pause();
  Future<void> dispose();
}

class AudioplayersBackgroundMusicTransport implements BackgroundMusicTransport {
  AudioplayersBackgroundMusicTransport({AudioPlayer? player})
    : _player =
          player ?? AudioPlayer(playerId: 'room-of-days-background-music');

  final AudioPlayer _player;
  bool _configured = false;
  bool _sourceStarted = false;

  @override
  Future<void> startOrResumeLoop(String asset, {required double volume}) async {
    if (!_configured) {
      // Match the event-sound contract explicitly. Music remains optional and
      // must mix with a person's own audio rather than taking focus from it.
      await _player.setAudioContext(
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
      await _player.setReleaseMode(ReleaseMode.loop);
      _configured = true;
    }
    if (_sourceStarted) {
      await _player.setVolume(volume);
      await _player.resume();
      return;
    }
    await _player.play(AssetSource(asset), volume: volume);
    _sourceStarted = true;
  }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> dispose() => _player.dispose();
}

/// Serializes background-music intent across settings, lifecycle, and browser
/// gesture retries. A stale asynchronous start can therefore only be followed
/// by the newer requested pause; it cannot resurrect music after it was off.
class BackgroundMusicController {
  BackgroundMusicController({
    BackgroundMusicTransport? transport,
    this.asset = 'music/room-theme.m4a',
    // Fable master: -24 LUFS / -26.7 dBFS phone-band RMS. This 0.35 gain
    // lands near -35.8 dBFS phone-band RMS: a quiet bed below conversation
    // and the approved event sounds, while still audible when chosen.
    this.volume = 0.35,
  }) : _transport = transport ?? AudioplayersBackgroundMusicTransport();

  final BackgroundMusicTransport _transport;
  final String asset;
  final double volume;

  bool _enabled = false;
  bool _foreground = true;
  bool _playing = false;
  bool _disposed = false;
  int _fadeEpoch = 0;
  Future<void> _tail = Future<void>.value();

  bool get enabled => _enabled;
  bool get isPlaying => _playing;

  Future<void> setEnabled(bool enabled) {
    if (_disposed) return Future<void>.value();
    _enabled = enabled;
    return _schedule();
  }

  Future<void> setForeground(bool foreground) {
    if (_disposed) return Future<void>.value();
    _foreground = foreground;
    return _schedule();
  }

  /// Browsers may reject a restored opt-in before a user gesture. A pointer
  /// can call this safely: it only starts when enabled, foregrounded, and not
  /// already playing.
  Future<void> retryAfterUserGesture() => _schedule();

  Future<void> _schedule() {
    if (_disposed) return Future<void>.value();
    _tail = _tail.catchError((Object _) {}).then<void>((_) async {
      if (_disposed) return;
      final shouldPlay = _enabled && _foreground;
      if (shouldPlay == _playing) return;
      if (shouldPlay) {
        try {
          // Start/resume at silence, then fade the optional bed in without
          // holding the lifecycle queue behind a cosmetic delay.
          await _transport.startOrResumeLoop(asset, volume: 0);
          if (_disposed) return;
          if (_enabled && _foreground) {
            _playing = true;
            _fadeIn();
          } else {
            await _transport.pause();
            _playing = false;
          }
        } catch (_) {
          // A WebAudio unlock or asset-load failure stays retryable on a real
          // gesture or later foreground event.
          _playing = false;
        }
      } else {
        _fadeEpoch++;
        try {
          await _transport.pause();
          _playing = false;
        } catch (_) {
          // Keep the last known playing state. A later lifecycle/settings
          // reconciliation will make another pause attempt instead of starting
          // a duplicate loop.
        }
      }
    });
    return _tail;
  }

  void _fadeIn() {
    final epoch = ++_fadeEpoch;
    unawaited(() async {
      const steps = 5;
      for (var step = 1; step <= steps; step++) {
        await Future<void>.delayed(const Duration(milliseconds: 45));
        if (_disposed ||
            !_playing ||
            !_enabled ||
            !_foreground ||
            epoch != _fadeEpoch) {
          return;
        }
        try {
          await _transport.setVolume(volume * step / steps);
        } catch (_) {
          return;
        }
      }
    }());
  }

  Future<void> dispose() {
    if (_disposed) return _tail;
    _disposed = true;
    _fadeEpoch++;
    _tail = _tail
        .catchError((Object _) {})
        .then<void>((_) => _transport.dispose());
    return _tail;
  }
}
