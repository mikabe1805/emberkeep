import 'dart:async';

import 'package:emberkeep/background_music.dart';
import 'package:emberkeep/main_room_music.dart';
import 'package:flutter_test/flutter_test.dart';

class _MainMusic implements MainRoomMusicPlayback {
  final List<String> calls = [];
  Completer<void>? pauseGate;
  bool enabled = false;
  bool foreground = true;
  bool disposed = false;

  @override
  bool get isPlaying => enabled && foreground && !disposed;

  @override
  Future<void> dispose() async {
    calls.add('main:dispose');
    disposed = true;
    enabled = false;
  }

  @override
  Future<void> retryAfterUserGesture() async => calls.add('main:retry');

  @override
  Future<void> setEnabled(bool value) async {
    if (enabled == value) return;
    enabled = value;
    calls.add('main:${value ? 'start' : 'pause'}');
    if (!value) await pauseGate?.future;
  }

  @override
  Future<void> setForeground(bool value) async {
    if (foreground == value) return;
    foreground = value;
    calls.add('main:${value ? 'foreground' : 'background'}');
  }
}

class _FocusTransport implements BackgroundMusicTransport {
  final List<String> calls = [];
  Completer<void>? startGate;
  Completer<void>? pauseGate;
  bool sourceStarted = false;
  bool failStart = false;
  bool failPause = false;
  bool disposed = false;

  @override
  Future<void> dispose() async {
    calls.add('focus:dispose');
    disposed = true;
  }

  @override
  Future<void> pause() async {
    calls.add('focus:pause');
    if (failPause) throw StateError('focus pause failed');
    await pauseGate?.future;
  }

  @override
  Future<void> startOrResumeLoop(String asset, {required double volume}) async {
    if (failStart) throw StateError('focus start failed');
    calls.add(
      sourceStarted
          ? 'focus:resume:$asset:$volume'
          : 'focus:start:$asset:$volume',
    );
    await startGate?.future;
    sourceStarted = true;
  }

  @override
  Future<void> setVolume(double volume) async {
    calls.add('focus:volume:$volume');
  }
}

BackgroundMusicController _controller(_MainMusic main, _FocusTransport focus) =>
    BackgroundMusicController(mainMusic: main, transport: focus);

void main() {
  test('global preference starts only the approved main-room role', () async {
    final main = _MainMusic();
    final focus = _FocusTransport();
    final music = _controller(main, focus);

    await music.setEnabled(true);

    expect(music.currentRole, RoomMusicRole.main);
    expect(music.enabled, isTrue);
    expect(main.calls, ['main:start']);
    expect(focus.calls, isEmpty);
  });

  test('Focus replaces main music with meditation and restores main', () async {
    final main = _MainMusic();
    final focus = _FocusTransport();
    final music = _controller(main, focus);

    await music.setEnabled(true);
    await music.enterFocusSession();

    expect(music.sessionActive, isTrue);
    expect(music.currentRole, RoomMusicRole.focus);
    expect(main.calls, ['main:start', 'main:pause']);
    expect(focus.calls, ['focus:start:music/focus-meditation.m4a:0.0']);

    await music.leaveFocusSession();
    expect(music.sessionActive, isFalse);
    expect(music.currentRole, RoomMusicRole.main);
    expect(focus.calls.last, 'focus:pause');
    expect(main.calls.last, 'main:start');
  });

  test('Focus cannot start before the main-role fade is silent', () async {
    final main = _MainMusic()..pauseGate = Completer<void>();
    final focus = _FocusTransport();
    final music = _controller(main, focus);

    await music.setEnabled(true);
    final entering = music.enterFocusSession();
    await Future<void>.delayed(Duration.zero);

    expect(main.calls.last, 'main:pause');
    expect(focus.calls, isEmpty);

    main.pauseGate!.complete();
    await entering;
    expect(focus.calls.single, contains('focus-meditation.m4a'));
  });

  test('main cannot resume before the Focus role is paused', () async {
    final main = _MainMusic();
    final focus = _FocusTransport();
    final music = _controller(main, focus);

    await music.setEnabled(true);
    await music.enterFocusSession();
    focus.pauseGate = Completer<void>();
    final leaving = music.leaveFocusSession();
    await Future<void>.delayed(Duration.zero);

    expect(focus.calls.last, 'focus:pause');
    expect(main.calls.where((call) => call == 'main:start'), hasLength(1));

    focus.pauseGate!.complete();
    await leaving;
    expect(main.calls.where((call) => call == 'main:start'), hasLength(2));
  });

  test('disposing one shell does not poison the shared main player', () async {
    final shared = MainRoomMusic.instance
      ..debugResetForTesting()
      ..debugBypassPlayback = true;
    final starts = <String>[];
    shared.debugOnStartTake = starts.add;

    final first = BackgroundMusicController(transport: _FocusTransport());
    await first.setEnabled(true);
    final firstDisposing = first.dispose();
    final second = BackgroundMusicController(transport: _FocusTransport());
    await second.setEnabled(true);
    await firstDisposing;

    expect(starts, hasLength(1));
    expect(second.currentRole, RoomMusicRole.main);
    expect(second.isPlaying, isTrue);
    await second.dispose();
    shared.debugResetForTesting();
  });

  test(
    'Focus opt-in works while the saved main preference stays off',
    () async {
      final main = _MainMusic();
      final focus = _FocusTransport();
      final music = _controller(main, focus);

      await music.enterFocusSession();
      expect(music.shouldPlay, isFalse);

      await music.setSessionEnabled(true);
      expect(music.enabled, isFalse);
      expect(music.sessionEnabled, isTrue);
      expect(music.currentRole, RoomMusicRole.focus);
      expect(focus.calls.single, contains('focus-meditation.m4a'));

      await music.leaveFocusSession();
      expect(music.currentRole, isNull);
      expect(main.calls.where((call) => call == 'main:start'), isEmpty);
    },
  );

  test(
    'Focus quiet preserves a global choice and restores it on close',
    () async {
      final main = _MainMusic();
      final focus = _FocusTransport();
      final music = _controller(main, focus);

      await music.setEnabled(true);
      await music.enterFocusSession();
      await music.setSessionMuted(true);

      expect(music.enabled, isTrue);
      expect(music.sessionMuted, isTrue);
      expect(music.shouldPlay, isFalse);
      expect(music.currentRole, isNull);

      await music.leaveFocusSession();
      expect(music.enabled, isTrue);
      expect(music.sessionMuted, isFalse);
      expect(music.currentRole, RoomMusicRole.main);
    },
  );

  test(
    'background and resume restore the role wanted in that context',
    () async {
      final main = _MainMusic();
      final focus = _FocusTransport();
      final music = _controller(main, focus);

      await music.setEnabled(true);
      await music.enterFocusSession();
      await music.setForeground(false);
      expect(music.currentRole, isNull);
      expect(music.isPlaying, isFalse);

      await music.setForeground(true);
      expect(music.currentRole, RoomMusicRole.focus);
      expect(focus.calls.last, 'focus:resume:music/focus-meditation.m4a:0.0');

      await music.leaveFocusSession();
      expect(music.currentRole, RoomMusicRole.main);
    },
  );

  test(
    'leaving Focus behind an in-flight start restores the main role',
    () async {
      final main = _MainMusic();
      final focus = _FocusTransport()..startGate = Completer<void>();
      final music = _controller(main, focus);

      await music.setEnabled(true);
      final entering = music.enterFocusSession();
      await Future<void>.delayed(Duration.zero);
      expect(focus.calls, ['focus:start:music/focus-meditation.m4a:0.0']);

      final leaving = music.leaveFocusSession();
      focus.startGate!.complete();
      await Future.wait([entering, leaving]);

      expect(music.currentRole, RoomMusicRole.main);
      expect(focus.calls.where((call) => call == 'focus:pause'), isNotEmpty);
      expect(main.calls.last, 'main:start');
    },
  );

  test('a failed Focus start stays retryable on a later gesture', () async {
    final main = _MainMusic();
    final focus = _FocusTransport()..failStart = true;
    final music = _controller(main, focus);

    await music.enterFocusSession();
    await music.setSessionEnabled(true);
    expect(music.currentRole, isNull);

    focus.failStart = false;
    await music.retryAfterUserGesture();
    expect(music.currentRole, RoomMusicRole.focus);
    expect(focus.calls.single, contains('focus-meditation.m4a'));
  });

  test('a failed Focus pause never overlaps the normal-room role', () async {
    final main = _MainMusic();
    final focus = _FocusTransport();
    final music = _controller(main, focus);

    await music.setEnabled(true);
    await music.enterFocusSession();
    focus.failPause = true;
    await music.leaveFocusSession();

    expect(music.currentRole, RoomMusicRole.focus);
    expect(main.enabled, isFalse);
    expect(main.calls.where((call) => call == 'main:start'), hasLength(1));

    focus.failPause = false;
    await music.leaveFocusSession();
    expect(music.currentRole, RoomMusicRole.main);
    expect(main.calls.where((call) => call == 'main:start'), hasLength(2));
  });

  test('dispose is terminal for both music roles', () async {
    final main = _MainMusic();
    final focus = _FocusTransport();
    final music = _controller(main, focus);

    await music.setEnabled(true);
    await music.dispose();
    await music.setEnabled(false);
    await music.enterFocusSession();

    expect(main.disposed, isTrue);
    expect(focus.disposed, isTrue);
    expect(main.calls.last, 'main:dispose');
    expect(focus.calls.last, 'focus:dispose');
  });
}
