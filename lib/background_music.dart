import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'main_room_music.dart';
import 'platform/audio_support_stub.dart'
    if (dart.library.js_interop) 'platform/audio_support_web.dart';

/// The two intentionally different long-form music roles.
enum RoomMusicRole { main, focus }

/// Transport for the single peaceful Focus loop. The normal room uses
/// [MainRoomMusicPlayback], whose approved eight-take rotation has different
/// playback and crossfade needs.
abstract interface class BackgroundMusicTransport {
  Future<void> startOrResumeLoop(String asset, {required double volume});
  Future<void> setVolume(double volume);
  Future<void> pause();
  Future<void> dispose();
}

class AudioplayersBackgroundMusicTransport implements BackgroundMusicTransport {
  AudioplayersBackgroundMusicTransport({AudioPlayer? player})
    : _player = player ?? AudioPlayer(playerId: 'room-of-days-focus-music');

  final AudioPlayer _player;
  bool _configured = false;
  bool _sourceStarted = false;

  @override
  Future<void> startOrResumeLoop(String asset, {required double volume}) async {
    if (!_configured) {
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

/// Owns the semantic boundary between normal Room music and Focus music.
///
/// - The saved global preference controls the approved umbrella-brush main
///   rotation outside Focus.
/// - Entering Focus temporarily replaces that bed with the peaceful
///   meditation loop when music is wanted.
/// - Focus opt-in and quiet are ephemeral and never rewrite the saved global
///   preference.
/// - Leaving Focus restores the main rotation only when the global preference
///   is still on.
class BackgroundMusicController {
  static int _latestSharedMainLease = 0;

  static int _claimSharedMainLease() => ++_latestSharedMainLease;

  BackgroundMusicController({
    BackgroundMusicTransport? transport,
    MainRoomMusicPlayback? mainMusic,
    this.focusAsset = 'music/focus-meditation.m4a',
    // The meditation master is -24 LUFS. This gain keeps it below speech and
    // the approved interaction cues while remaining audible when chosen.
    this.focusVolume = 0.35,
  }) : _focusTransport = transport ?? AudioplayersBackgroundMusicTransport(),
       _mainMusic = mainMusic ?? MainRoomMusic.instance,
       _ownsMainMusic = mainMusic != null,
       _sharedMainLease = mainMusic == null ? _claimSharedMainLease() : null;

  final BackgroundMusicTransport _focusTransport;
  final MainRoomMusicPlayback _mainMusic;
  // The production instance is shared with Sfx for gesture retries and
  // ducking. An AppShell can be recreated in the same process, so disposing
  // that singleton here would make every later shell permanently silent.
  // Injected transports remain controller-owned for deterministic tests.
  final bool _ownsMainMusic;
  final int? _sharedMainLease;
  final String focusAsset;
  final double focusVolume;

  bool _enabled = false;
  bool _sessionActive = false;
  bool _sessionEnabled = false;
  bool _sessionMuted = false;
  bool _foreground = true;
  bool _focusPlaying = false;
  bool _disposed = false;
  int _fadeEpoch = 0;
  RoomMusicRole? _currentRole;
  Future<void> _tail = Future<void>.value();

  bool get enabled => _enabled;
  bool get sessionActive => _sessionActive;
  bool get sessionEnabled => _sessionEnabled;
  bool get sessionMuted => _sessionMuted;
  bool get foreground => _foreground;
  RoomMusicRole? get currentRole => _currentRole;
  bool get isPlaying => switch (_currentRole) {
    RoomMusicRole.main => _mainMusic.isPlaying,
    RoomMusicRole.focus => _focusPlaying,
    null => false,
  };

  RoomMusicRole? get _desiredRole {
    if (!_foreground) return null;
    if (_sessionActive) {
      final focusWanted = (_enabled || _sessionEnabled) && !_sessionMuted;
      return focusWanted ? RoomMusicRole.focus : null;
    }
    return _enabled ? RoomMusicRole.main : null;
  }

  /// Logical music intent. This can remain true while a browser is waiting
  /// for a user gesture or while a failed audio start remains retryable.
  bool get shouldPlay => _desiredRole != null;

  Future<void> setEnabled(bool enabled) {
    if (_disposed) return Future<void>.value();
    _enabled = enabled;
    return _schedule();
  }

  /// Marks the TimerOverlay boundary. A globally enabled room moves from the
  /// fun rotation to the meditation loop here, not when a setting changes.
  Future<void> enterFocusSession() {
    if (_disposed) return Future<void>.value();
    _sessionActive = true;
    _sessionEnabled = false;
    _sessionMuted = false;
    return _schedule();
  }

  /// Clears every ephemeral Focus choice and restores the global role.
  Future<void> leaveFocusSession() {
    if (_disposed) return Future<void>.value();
    _sessionActive = false;
    _sessionEnabled = false;
    _sessionMuted = false;
    return _schedule();
  }

  Future<void> setSessionEnabled(bool enabled) {
    if (_disposed) return Future<void>.value();
    _sessionEnabled = enabled;
    return _schedule();
  }

  Future<void> setSessionMuted(bool muted) {
    if (_disposed) return Future<void>.value();
    _sessionMuted = muted;
    return _schedule();
  }

  Future<void> setForeground(bool foreground) {
    if (_disposed) return Future<void>.value();
    _foreground = foreground;
    return _schedule();
  }

  Future<void> retryAfterUserGesture() {
    if (_disposed) return Future<void>.value();
    _tail = _tail.catchError((Object _) {}).then<void>((_) async {
      if (_disposed || _desiredRole == null) return;
      if (_desiredRole == RoomMusicRole.main) {
        await _mainMusic.retryAfterUserGesture();
      } else if (!_focusPlaying) {
        await _startFocus();
      }
    });
    return _tail;
  }

  Future<void> _schedule() {
    if (_disposed) return Future<void>.value();
    _tail = _tail.catchError((Object _) {}).then<void>((_) async {
      if (_disposed) return;
      await _mainMusic.setForeground(_foreground);
      final desired = _desiredRole;

      if (_currentRole == desired) {
        if (desired == RoomMusicRole.main && !_mainMusic.isPlaying) {
          await _mainMusic.setEnabled(true);
        } else if (desired == RoomMusicRole.focus && !_focusPlaying) {
          await _startFocus();
        }
        return;
      }

      _fadeEpoch++;
      if (_currentRole == RoomMusicRole.main || desired != RoomMusicRole.main) {
        await _mainMusic.setEnabled(false);
      }
      if (_currentRole == RoomMusicRole.focus) {
        try {
          await _focusTransport.pause();
          _focusPlaying = false;
        } catch (_) {
          // Keep the known playing state so the next reconciliation retries
          // the pause instead of starting another role over a loop that may
          // still be audible.
          return;
        }
      }

      _currentRole = null;
      if (desired == RoomMusicRole.main) {
        await _mainMusic.setEnabled(true);
        _currentRole = RoomMusicRole.main;
      } else if (desired == RoomMusicRole.focus) {
        await _startFocus();
      }
    });
    return _tail;
  }

  Future<void> _startFocus() async {
    try {
      await _mainMusic.setEnabled(false);
      if (kIsWeb && !browserAudioAvailable) {
        _focusPlaying = false;
        _currentRole = null;
        return;
      }
      await _focusTransport.startOrResumeLoop(focusAsset, volume: 0);
      if (_disposed || _desiredRole != RoomMusicRole.focus) {
        await _focusTransport.pause();
        _focusPlaying = false;
        _currentRole = null;
        return;
      }
      _focusPlaying = true;
      _currentRole = RoomMusicRole.focus;
      _fadeInFocus();
    } catch (_) {
      _focusPlaying = false;
      _currentRole = null;
    }
  }

  void _fadeInFocus() {
    final epoch = ++_fadeEpoch;
    unawaited(() async {
      const steps = 5;
      for (var step = 1; step <= steps; step++) {
        await Future<void>.delayed(const Duration(milliseconds: 45));
        if (_disposed ||
            !_focusPlaying ||
            _desiredRole != RoomMusicRole.focus ||
            epoch != _fadeEpoch) {
          return;
        }
        try {
          await _focusTransport.setVolume(focusVolume * step / steps);
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
    _tail = _tail.catchError((Object _) {}).then<void>((_) async {
      if (_ownsMainMusic) {
        await _mainMusic.setEnabled(false);
        await _mainMusic.setForeground(false);
        await _mainMusic.dispose();
      } else if (_sharedMainLease == _latestSharedMainLease) {
        // The shell owns the latest lease on the Sfx-shared singleton. Check
        // again after each await so a replacement shell can take authority
        // while this unawaited teardown is draining an old voice.
        await _mainMusic.setEnabled(false);
        if (_sharedMainLease == _latestSharedMainLease) {
          await _mainMusic.setForeground(false);
        }
      }
      await _focusTransport.dispose();
    });
    return _tail;
  }
}
