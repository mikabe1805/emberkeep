import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'clock.dart';
import 'main_room_music.dart';
import 'platform/audio_support_stub.dart'
    if (dart.library.js_interop) 'platform/audio_support_web.dart';

/// The two intentionally different long-form music roles.
enum RoomMusicRole { main, focus }

/// Transport for the single peaceful Focus loop. The normal room uses
/// [MainRoomMusicPlayback], whose approved dry rotation has different
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

  /// Tonight's choice from the evening room, over the saved preference: null
  /// follows the saved setting, true plays the main rotation, false keeps it
  /// quiet. Ephemeral like the Focus choices: it never rewrites the saved
  /// preference, and changing that preference clears it.
  bool? _roomChoice;

  /// When tonight's choice lapses by itself (the class day's night end). It
  /// is read through [Clock], so the choice never waits for a page to
  /// rebuild before it gives way to the saved setting.
  DateTime? _roomChoiceUntil;

  /// Tonight's choice while it holds; null once its night is over.
  bool? get _activeChoice {
    final until = _roomChoiceUntil;
    if (_roomChoice != null &&
        until != null &&
        !Clock.now().toUtc().isBefore(until.toUtc())) {
      _roomChoice = null;
      _roomChoiceUntil = null;
    }
    return _roomChoice;
  }

  final ValueNotifier<bool> _mainWanted = ValueNotifier<bool>(false);
  bool _sessionActive = false;
  bool _sessionEnabled = false;
  bool _sessionMuted = false;
  bool _foreground = true;
  bool _focusPlaying = false;
  bool _focusFadeNeedsRetry = false;
  bool _disposed = false;
  int _fadeEpoch = 0;
  RoomMusicRole? _currentRole;
  Future<void> _tail = Future<void>.value();

  bool get enabled => _enabled;
  bool? get roomChoice => _activeChoice;

  /// Whether the main rotation is wanted now (the saved setting, or tonight's
  /// choice over it), outside Focus and in the foreground. Said at once, before
  /// any fade.
  ValueListenable<bool> get mainWanted => _mainWanted;

  /// The main rotation's take sounding now (an asset path), or null.
  ValueListenable<String?> get nowPlaying => _mainMusic.nowPlaying;
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
    return (_activeChoice ?? _enabled) ? RoomMusicRole.main : null;
  }

  /// Whether the main rotation would play outside Focus: the saved setting,
  /// or tonight's choice over it. Unlike [mainWanted] it ignores the
  /// foreground, so a control reads the same while the app is backgrounded.
  bool get roomMusicOn => _activeChoice ?? _enabled;

  /// Logical music intent. This can remain true while a browser is waiting
  /// for a user gesture or while a failed audio start remains retryable.
  bool get shouldPlay => _desiredRole != null;

  Future<void> setEnabled(bool enabled) {
    if (_disposed) return Future<void>.value();
    // The saved setting changing (Me's switch) is the newer word: tonight's
    // evening choice gives way to it.
    if (enabled != _enabled) {
      _roomChoice = null;
      _roomChoiceUntil = null;
    }
    _enabled = enabled;
    return _schedule();
  }

  /// The evening room's music control: [listening] true plays the main
  /// rotation for now, starting on [startWithTake] when nothing is playing
  /// yet; false keeps the room quiet for now; null goes back to the saved
  /// setting. [until] is when the choice lapses by itself (tonight's end),
  /// so the app coming back the next morning never starts the rotation
  /// against the saved setting. Never written to the saved preference, and
  /// nothing calls it except a person's tap, so the room never starts music
  /// on its own.
  Future<void> setRoomChoice(
    bool? listening, {
    int? startWithTake,
    DateTime? until,
  }) {
    if (_disposed) return Future<void>.value();
    _roomChoice = listening;
    _roomChoiceUntil = listening == null ? null : until;
    if (listening == true &&
        startWithTake != null &&
        _currentRole != RoomMusicRole.main) {
      _mainMusic.preferNextTake(startWithTake);
    }
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
      } else if (!_focusPlaying || _focusFadeNeedsRetry) {
        await _startFocus();
      }
    });
    return _tail;
  }

  Future<void> _schedule() {
    if (_disposed) return Future<void>.value();
    _mainWanted.value = _desiredRole == RoomMusicRole.main;
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
          _focusFadeNeedsRetry = false;
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
      _focusFadeNeedsRetry = false;
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
          // A fade can fail after an earlier step already made this source
          // audible. Keep ownership so lifecycle changes still pause it, and
          // let the next real user gesture resume this one source at zero and
          // retry the fade rather than starting another Focus player.
          if (epoch == _fadeEpoch &&
              _desiredRole == RoomMusicRole.focus &&
              _focusPlaying) {
            _focusFadeNeedsRetry = true;
          }
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
