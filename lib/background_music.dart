import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'class_day_score.dart';
import 'clock.dart';
import 'main_room_music.dart';
import 'platform/audio_support_stub.dart'
    if (dart.library.js_interop) 'platform/audio_support_web.dart';

/// The long-form music roles. [main] and [focus] are intentionally different
/// pieces of music; [classDay] is the class-day score, which stands in for
/// [main] on a class day only (see [BackgroundMusicController.setClassDay]).
enum RoomMusicRole { main, focus, classDay }

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
/// - On a class day the class-day score is the room's music instead of the
///   rotation, for as long as music is wanted (the saved setting or tonight's
///   choice): the Between bed by day, the Evening bed once the glass has
///   turned to the evening, and a two-bar swell when a class is kept. Focus
///   still wins over it, and every other day keeps the rotation. It is native
///   only; the web build keeps the rotation.
class BackgroundMusicController {
  static int _latestSharedMainLease = 0;

  static int _claimSharedMainLease() => ++_latestSharedMainLease;

  BackgroundMusicController({
    BackgroundMusicTransport? transport,
    MainRoomMusicPlayback? mainMusic,
    ClassDayScorePlayback? classDayScore,
    this.focusAsset = 'music/focus-meditation.m4a',
    // The meditation master is -24 LUFS. This gain keeps it below speech and
    // the approved interaction cues while remaining audible when chosen.
    this.focusVolume = 0.35,
  }) : _focusTransport = transport ?? AudioplayersBackgroundMusicTransport(),
       _mainMusic = mainMusic ?? MainRoomMusic.instance,
       _score =
           classDayScore ??
           ClassDayScore(
             transport: const AudioplayersScoreTransport(),
             // The same duck the rotation sits under when sounds play.
             duckGain: mainMusic == null
                 ? () => MainRoomMusic.instance.ducker.gainAt(DateTime.now())
                 : null,
           ),
       _ownsMainMusic = mainMusic != null,
       _sharedMainLease = mainMusic == null ? _claimSharedMainLease() : null {
    _mainMusic.nowPlaying.addListener(_syncNowPlaying);
    _score.nowPlaying.addListener(_syncNowPlaying);
    _syncNowPlaying();
  }

  final BackgroundMusicTransport _focusTransport;
  final MainRoomMusicPlayback _mainMusic;
  final ClassDayScorePlayback _score;
  final ValueNotifier<String?> _nowPlaying = ValueNotifier<String?>(null);

  /// The class-day score is native only: the web build keeps the rotation.
  static bool get _scoreAvailable => !kIsWeb;
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

  /// Today is a class day (the Quests page says so) and whether the glass has
  /// turned to the evening. Both are the page's reading, relayed; this class
  /// holds no day logic of its own.
  bool _classDay = false;
  bool _classDayEvening = false;

  /// The evening door's press asked for Lamp left on while the score is the
  /// room's music: the score plays it first, as an opener.
  bool _openerPending = false;

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

  /// The file sounding now (an asset path) in the room's music, the
  /// rotation's take or the class-day score's, or null.
  ValueListenable<String?> get nowPlaying => _nowPlaying;

  void _syncNowPlaying() {
    final next = _score.nowPlaying.value ?? _mainMusic.nowPlaying.value;
    if (_nowPlaying.value != next) _nowPlaying.value = next;
  }

  bool get sessionActive => _sessionActive;
  bool get sessionEnabled => _sessionEnabled;
  bool get sessionMuted => _sessionMuted;
  bool get foreground => _foreground;
  RoomMusicRole? get currentRole => _currentRole;
  bool get isPlaying => switch (_currentRole) {
    RoomMusicRole.main => _mainMusic.isPlaying,
    RoomMusicRole.focus => _focusPlaying,
    RoomMusicRole.classDay => _score.isPlaying,
    null => false,
  };

  RoomMusicRole? get _desiredRole {
    if (!_foreground) return null;
    if (_sessionActive) {
      final focusWanted = (_enabled || _sessionEnabled) && !_sessionMuted;
      return focusWanted ? RoomMusicRole.focus : null;
    }
    if (!(_activeChoice ?? _enabled)) return null;
    return _classDay && _scoreAvailable
        ? RoomMusicRole.classDay
        : RoomMusicRole.main;
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
    if (listening != true) _openerPending = false;
    if (listening == true &&
        startWithTake != null &&
        _currentRole != RoomMusicRole.main &&
        _currentRole != RoomMusicRole.classDay) {
      if (_classDay && _scoreAvailable) {
        // The score is the room's music today: Lamp left on opens it, and the
        // rotation is not told, or it would open with Lamp left on some other
        // day.
        if (startWithTake == MainRoomMusic.lampLeftOnTake) {
          _openerPending = true;
        }
      } else {
        _mainMusic.preferNextTake(startWithTake);
      }
    }
    return _schedule();
  }

  /// The Quests page's reading of today: a class day or not, and whether the
  /// glass has turned to the evening. On a class day the score replaces the
  /// rotation while music is wanted; the change of phase is applied at the
  /// score's next pass boundary. Says nothing about whether music is wanted,
  /// and never starts music by itself.
  Future<void> setClassDay(bool active, {bool evening = false}) {
    if (_disposed) return Future<void>.value();
    final phase = active && evening;
    if (_classDay == active && _classDayEvening == phase) {
      return Future<void>.value();
    }
    _classDay = active;
    _classDayEvening = phase;
    if (!active) _openerPending = false;
    return _schedule();
  }

  /// A class was kept. The score answers with a two-bar swell on the next
  /// strong beat after [after] (how long the chime takes to sound), when it is
  /// the room's music and the Between bed is sounding; otherwise nothing.
  void classKept({required Duration after}) {
    if (_disposed || _currentRole != RoomMusicRole.classDay) return;
    _score.classKept(after: after);
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
      } else if (_desiredRole == RoomMusicRole.classDay) {
        // Native only, so no browser gesture is waited for; but a score that
        // failed to start is retried on the next press.
        if (_currentRole != RoomMusicRole.classDay || !_score.isPlaying) {
          await _startScore();
        }
      } else if (!_focusPlaying || _focusFadeNeedsRetry) {
        await _startFocus();
      }
    });
    return _tail;
  }

  Future<void> _schedule() {
    if (_disposed) return Future<void>.value();
    _mainWanted.value =
        _desiredRole == RoomMusicRole.main ||
        _desiredRole == RoomMusicRole.classDay;
    _tail = _tail.catchError((Object _) {}).then<void>((_) async {
      if (_disposed) return;
      await _mainMusic.setForeground(_foreground);
      await _score.setForeground(_foreground);
      final desired = _desiredRole;

      if (_currentRole == desired) {
        if (desired == RoomMusicRole.main && !_mainMusic.isPlaying) {
          await _mainMusic.setEnabled(true);
        } else if (desired == RoomMusicRole.focus && !_focusPlaying) {
          await _startFocus();
        } else if (desired == RoomMusicRole.classDay) {
          if (_score.isPlaying) {
            await _score.setEvening(_classDayEvening);
          } else {
            await _startScore();
          }
        }
        return;
      }

      _fadeEpoch++;
      if (_currentRole == RoomMusicRole.main || desired != RoomMusicRole.main) {
        await _mainMusic.setEnabled(false);
      }
      if (_currentRole == RoomMusicRole.classDay) {
        await _score.stop();
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
      } else if (desired == RoomMusicRole.classDay) {
        await _startScore();
      }
    });
    return _tail;
  }

  Future<void> _startScore() async {
    final opener = _openerPending && _classDayEvening;
    _openerPending = false;
    try {
      await _mainMusic.setEnabled(false);
      await _score.start(evening: _classDayEvening, opener: opener);
      if (_disposed || _desiredRole != RoomMusicRole.classDay) {
        await _score.stop();
        _currentRole = null;
        return;
      }
      _currentRole = RoomMusicRole.classDay;
    } catch (_) {
      // Continuing silent, like the rotation: the next change of state tries
      // again.
      _currentRole = null;
    }
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
    _mainMusic.nowPlaying.removeListener(_syncNowPlaying);
    _score.nowPlaying.removeListener(_syncNowPlaying);
    _tail = _tail.catchError((Object _) {}).then<void>((_) async {
      await _score.dispose();
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
