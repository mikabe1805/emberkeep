import 'dart:async';

import 'package:emberkeep/background_music.dart';
import 'package:flutter_test/flutter_test.dart';

class _Transport implements BackgroundMusicTransport {
  final List<String> calls = [];
  Completer<void>? startGate;
  bool sourceStarted = false;
  bool failStart = false;
  bool failPause = false;
  bool disposed = false;

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    disposed = true;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    if (failPause) throw StateError('pause failed');
  }

  @override
  Future<void> startOrResumeLoop(String asset, {required double volume}) async {
    if (failStart) throw StateError('start failed');
    if (sourceStarted) {
      calls.add('resume:$volume');
      return;
    }
    calls.add('start:$asset:$volume');
    await startGate?.future;
    sourceStarted = true;
  }

  @override
  Future<void> setVolume(double volume) async {
    calls.add('volume:$volume');
  }
}

void main() {
  test(
    'music needs explicit opt-in and stays independent from SFX state',
    () async {
      final transport = _Transport();
      final music = BackgroundMusicController(transport: transport);

      await music.setForeground(true);
      expect(transport.calls, isEmpty);
      expect(music.enabled, isFalse);

      await music.setEnabled(true);
      expect(transport.calls, ['start:music/room-theme.m4a:0.0']);
      expect(music.isPlaying, isTrue);
    },
  );

  test(
    'backgrounding pauses and foregrounding resumes only a chosen track',
    () async {
      final transport = _Transport();
      final music = BackgroundMusicController(transport: transport);

      await music.setEnabled(true);
      await music.setForeground(false);
      await music.setForeground(true);

      expect(transport.calls, [
        'start:music/room-theme.m4a:0.0',
        'pause',
        'resume:0.0',
      ]);
    },
  );

  test(
    'a pending restore stays silent after lifecycle reports background',
    () async {
      final transport = _Transport();
      final music = BackgroundMusicController(transport: transport);

      // Model an inactive lifecycle notification arriving before storage has
      // restored an already-chosen music preference.
      await music.setForeground(false);
      await music.setEnabled(true);

      expect(transport.calls, isEmpty);
      expect(music.isPlaying, isFalse);
    },
  );

  test('an off request behind an in-flight start always wins', () async {
    final transport = _Transport()..startGate = Completer<void>();
    final music = BackgroundMusicController(transport: transport);

    final started = music.setEnabled(true);
    await Future<void>.delayed(Duration.zero);
    expect(transport.calls, ['start:music/room-theme.m4a:0.0']);
    final stopped = music.setEnabled(false);
    transport.startGate!.complete();
    await Future.wait([started, stopped]);

    expect(transport.calls, ['start:music/room-theme.m4a:0.0', 'pause']);
    expect(music.isPlaying, isFalse);
  });

  test('dispose is terminal and cannot leave a later loop behind', () async {
    final transport = _Transport();
    final music = BackgroundMusicController(transport: transport);

    await music.setEnabled(true);
    await music.dispose();
    await music.setForeground(true);
    await music.retryAfterUserGesture();

    expect(transport.calls, ['start:music/room-theme.m4a:0.0', 'dispose']);
    expect(transport.disposed, isTrue);
  });

  test(
    'a failed pause remains a pause retry and never starts another loop',
    () async {
      final transport = _Transport();
      final music = BackgroundMusicController(transport: transport);

      await music.setEnabled(true);
      transport.failPause = true;
      await music.setForeground(false);
      expect(music.isPlaying, isTrue);

      transport.failPause = false;
      await music.setForeground(false);
      expect(
        transport.calls.where((call) => call.startsWith('start:')),
        hasLength(1),
      );
      expect(transport.calls.where((call) => call == 'pause'), hasLength(2));
      expect(music.isPlaying, isFalse);
    },
  );

  test('a failed start stays retryable on a later user gesture', () async {
    final transport = _Transport()..failStart = true;
    final music = BackgroundMusicController(transport: transport);

    await music.setEnabled(true);
    expect(music.isPlaying, isFalse);

    transport.failStart = false;
    await music.retryAfterUserGesture();

    expect(transport.calls, ['start:music/room-theme.m4a:0.0']);
    expect(music.isPlaying, isTrue);
  });
}
