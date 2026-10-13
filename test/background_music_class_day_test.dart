// The class-day role of the music controller: when the score is the room's
// music instead of the rotation, what takes precedence over it, and that it
// never starts music nobody asked for.
import 'dart:async';

import 'package:emberkeep/background_music.dart';
import 'package:emberkeep/class_day_score.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/main_room_music.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// One shared log, so a test can say what happened before what.
class _Log {
  final List<String> events = [];
  void add(String e) => events.add(e);
  List<String> get score => [
    for (final e in events)
      if (e.startsWith('score:')) e,
  ];
  List<String> get main => [
    for (final e in events)
      if (e.startsWith('main:')) e,
  ];
}

class _MainMusic implements MainRoomMusicPlayback {
  _MainMusic(this.log);
  final _Log log;
  bool enabled = false;
  bool foreground = true;
  Completer<void>? pauseGate;

  @override
  bool get isPlaying => enabled && foreground;

  @override
  final ValueNotifier<String?> nowPlaying = ValueNotifier<String?>(null);

  @override
  void preferNextTake(int take) => log.add('main:prefer:$take');

  @override
  Future<void> dispose() async => log.add('main:dispose');

  @override
  Future<void> retryAfterUserGesture() async => log.add('main:retry');

  @override
  Future<void> setEnabled(bool value) async {
    if (enabled == value) return;
    enabled = value;
    log.add('main:${value ? 'start' : 'pause'}');
    nowPlaying.value = value ? MainRoomMusic.assetForTake(4) : null;
    if (!value) await pauseGate?.future;
  }

  @override
  Future<void> setForeground(bool value) async {
    if (foreground == value) return;
    foreground = value;
    log.add('main:${value ? 'foreground' : 'background'}');
  }
}

class _Score implements ClassDayScorePlayback {
  _Score(this.log);
  final _Log log;
  bool playing = false;
  bool failStart = false;
  Completer<void>? stopGate;
  final List<Duration> kept = [];

  @override
  final ValueNotifier<String?> nowPlaying = ValueNotifier<String?>(null);

  @override
  bool get isPlaying => playing;

  @override
  Future<void> start({required bool evening, bool opener = false}) async {
    if (failStart) throw StateError('no audio');
    log.add(
      'score:start:${evening ? 'evening' : 'between'}${opener ? ':opener' : ''}',
    );
    playing = true;
    nowPlaying.value = opener
        ? MainRoomMusic.assetForTake(MainRoomMusic.lampLeftOnTake)
        : evening
        ? 'music/class_day/bed_evening_0.m4a'
        : 'music/class_day/bed_between_0.m4a';
  }

  @override
  Future<void> setEvening(bool evening) async =>
      log.add('score:evening:$evening');

  @override
  void classKept({required Duration after}) {
    kept.add(after);
    log.add('score:kept:${after.inMilliseconds}');
  }

  @override
  Future<void> stop({Duration fade = MainRoomMusic.stopFadeOut}) async {
    if (!playing) return;
    log.add('score:stop');
    await stopGate?.future;
    playing = false;
    nowPlaying.value = null;
  }

  @override
  Future<void> setForeground(bool foreground) async {
    if (!foreground && playing) {
      log.add('score:background');
      playing = false;
      nowPlaying.value = null;
    }
  }

  @override
  Future<void> dispose() async => log.add('score:dispose');
}

class _FocusTransport implements BackgroundMusicTransport {
  _FocusTransport(this.log);
  final _Log log;
  @override
  Future<void> dispose() async {}
  @override
  Future<void> pause() async => log.add('focus:pause');
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> startOrResumeLoop(
    String asset, {
    required double volume,
  }) async => log.add('focus:start');
}

class _Rig {
  _Rig() {
    main = _MainMusic(log);
    score = _Score(log);
    music = BackgroundMusicController(
      mainMusic: main,
      classDayScore: score,
      transport: _FocusTransport(log),
    );
  }
  final log = _Log();
  late final _MainMusic main;
  late final _Score score;
  late final BackgroundMusicController music;
}

void main() {
  tearDown(Clock.reset);

  group('on a class day the score is the room\'s music', () {
    test('the saved setting plays the Between bed, not the rotation', () async {
      final r = _Rig();
      await r.music.setClassDay(true);
      expect(
        r.log.events,
        isEmpty,
        reason: 'saying it is a class day is silent',
      );
      await r.music.setEnabled(true);
      expect(r.music.currentRole, RoomMusicRole.classDay);
      expect(r.log.score, ['score:start:between']);
      expect(r.log.main, isNot(contains('main:start')));
      expect(r.music.isPlaying, isTrue);
      expect(r.music.mainWanted.value, isTrue, reason: 'the door reads it');
    });

    test('the Evening bed once the glass has turned', () async {
      final r = _Rig();
      await r.music.setEnabled(true);
      await r.music.setClassDay(true, evening: true);
      expect(r.log.score.last, 'score:start:evening');
      expect(r.music.currentRole, RoomMusicRole.classDay);
    });

    test(
      'the page learning it is a class day after the music started '
      'hands the rotation over: it is silenced before the score starts',
      () async {
        final r = _Rig();
        await r.music.setEnabled(true);
        expect(r.music.currentRole, RoomMusicRole.main);
        r.main.pauseGate = Completer<void>();
        final handover = r.music.setClassDay(true);
        await Future<void>.delayed(Duration.zero);
        expect(r.log.events, contains('main:pause'));
        expect(
          r.log.score,
          isEmpty,
          reason: 'the rotation is still fading out',
        );
        r.main.pauseGate!.complete();
        await handover;
        expect(r.music.currentRole, RoomMusicRole.classDay);
        expect(
          r.log.events.indexOf('main:pause'),
          lessThan(r.log.events.indexOf('score:start:between')),
        );
      },
    );

    test(
      'music not wanted: nothing starts, and a class day never starts it',
      () async {
        final r = _Rig();
        await r.music.setClassDay(true, evening: true);
        await r.music.setClassDay(true);
        expect(r.log.events, isEmpty);
        expect(r.music.currentRole, isNull);
        expect(r.music.mainWanted.value, isFalse);
        expect(r.music.shouldPlay, isFalse);
      },
    );

    test('another day keeps the rotation, untouched', () async {
      final r = _Rig();
      await r.music.setClassDay(false);
      await r.music.setEnabled(true);
      expect(r.music.currentRole, RoomMusicRole.main);
      expect(r.log.main, ['main:start']);
      expect(r.log.score, isEmpty);
    });

    test('the class day ending hands back to the rotation, score faded out '
        'first', () async {
      final r = _Rig();
      await r.music.setClassDay(true);
      await r.music.setEnabled(true);
      r.score.stopGate = Completer<void>();
      final back = r.music.setClassDay(false);
      await Future<void>.delayed(Duration.zero);
      expect(r.log.score, contains('score:stop'));
      expect(r.log.main, isNot(contains('main:start')), reason: 'not over it');
      r.score.stopGate!.complete();
      await back;
      expect(r.music.currentRole, RoomMusicRole.main);
      expect(
        r.log.events.indexOf('score:stop'),
        lessThan(r.log.events.indexOf('main:start')),
      );
    });

    test(
      'a change of phase is told to the score, which keeps playing',
      () async {
        final r = _Rig();
        await r.music.setClassDay(true);
        await r.music.setEnabled(true);
        await r.music.setClassDay(true, evening: true);
        expect(r.log.score, ['score:start:between', 'score:evening:true']);
        await r.music.setClassDay(true);
        expect(r.log.score.last, 'score:evening:false');
        // The same reading again is not news.
        final count = r.log.events.length;
        await r.music.setClassDay(true);
        expect(r.log.events, hasLength(count));
      },
    );

    test('Music off fades the score out, and nothing else starts', () async {
      final r = _Rig();
      await r.music.setClassDay(true);
      await r.music.setEnabled(true);
      await r.music.setEnabled(false);
      expect(r.log.score.last, 'score:stop');
      expect(r.music.currentRole, isNull);
      expect(r.log.main, isNot(contains('main:start')));
      expect(r.music.mainWanted.value, isFalse);
    });

    test(
      'a score that cannot start leaves the room quiet, then tries again',
      () async {
        final r = _Rig();
        r.score.failStart = true;
        await r.music.setClassDay(true);
        await r.music.setEnabled(true);
        expect(r.music.currentRole, isNull);
        expect(r.music.isPlaying, isFalse);
        r.score.failStart = false;
        await r.music.setClassDay(true, evening: true);
        expect(r.music.currentRole, RoomMusicRole.classDay);
      },
    );
  });

  group('a press (the gesture a browser waits for)', () {
    test('never starts the Focus loop on a class day', () async {
      final r = _Rig();
      await r.music.setClassDay(true);
      await r.music.setEnabled(true);
      await r.music.retryAfterUserGesture();
      expect(r.log.events.where((e) => e.startsWith('focus:')), isEmpty);
      expect(r.music.currentRole, RoomMusicRole.classDay);
      expect(r.log.score, ['score:start:between'], reason: 'already playing');
    });

    test('retries a score that failed to start', () async {
      final r = _Rig();
      r.score.failStart = true;
      await r.music.setClassDay(true);
      await r.music.setEnabled(true);
      expect(r.music.currentRole, isNull);
      r.score.failStart = false;
      await r.music.retryAfterUserGesture();
      expect(r.music.currentRole, RoomMusicRole.classDay);
    });
  });

  group('Focus and the lifecycle', () {
    test('Focus takes the room from the score and gives it back', () async {
      final r = _Rig();
      await r.music.setClassDay(true);
      await r.music.setEnabled(true);
      await r.music.enterFocusSession();
      expect(r.music.currentRole, RoomMusicRole.focus);
      expect(r.log.events, containsAllInOrder(['score:stop', 'focus:start']));
      await r.music.leaveFocusSession();
      expect(r.music.currentRole, RoomMusicRole.classDay);
      expect(r.log.events.last, 'score:start:between');
    });

    test('Focus wins even where the day is a class day', () async {
      final r = _Rig();
      await r.music.enterFocusSession();
      await r.music.setClassDay(true);
      await r.music.setEnabled(true);
      expect(r.music.currentRole, RoomMusicRole.focus);
      expect(r.log.score, isEmpty);
    });

    test(
      'backgrounding fades the score; coming back starts it again',
      () async {
        final r = _Rig();
        await r.music.setClassDay(true);
        await r.music.setEnabled(true);
        await r.music.setForeground(false);
        expect(r.log.score, contains('score:background'));
        expect(r.music.currentRole, isNull);
        expect(r.music.isPlaying, isFalse);
        await r.music.setForeground(true);
        expect(r.music.currentRole, RoomMusicRole.classDay);
        expect(
          r.log.score.where((e) => e.startsWith('score:start')),
          hasLength(2),
        );
      },
    );

    test('a swell is owed to nobody who was away: it is not resumed', () async {
      final r = _Rig();
      await r.music.setClassDay(true);
      await r.music.setEnabled(true);
      r.music.classKept(after: const Duration(milliseconds: 950));
      await r.music.setForeground(false);
      await r.music.setForeground(true);
      expect(r.score.kept, hasLength(1), reason: 'only the one asked for');
    });
  });

  group('a class kept', () {
    test(
      'reaches the score only while the score is the room\'s music',
      () async {
        final r = _Rig();
        const after = Duration(milliseconds: 950);
        // Not a class day: the rotation has nothing to swell.
        await r.music.setEnabled(true);
        r.music.classKept(after: after);
        expect(r.score.kept, isEmpty);
        // A class day, music playing.
        await r.music.setClassDay(true);
        r.music.classKept(after: after);
        expect(r.score.kept, [after]);
        // Music off.
        await r.music.setEnabled(false);
        r.music.classKept(after: after);
        expect(r.score.kept, hasLength(1));
      },
    );

    test('is not sent during Focus', () async {
      final r = _Rig();
      await r.music.setClassDay(true);
      await r.music.setEnabled(true);
      await r.music.enterFocusSession();
      r.music.classKept(after: const Duration(milliseconds: 950));
      expect(r.score.kept, isEmpty);
    });

    test('is not sent once the controller is disposed', () async {
      final r = _Rig();
      await r.music.setClassDay(true);
      await r.music.setEnabled(true);
      await r.music.dispose();
      r.music.classKept(after: const Duration(milliseconds: 950));
      expect(r.score.kept, isEmpty);
    });
  });

  group('tonight\'s choice at the evening door', () {
    test('a press with the music off plays Lamp left on, as the score\'s '
        'opener, and does not arm the rotation', () async {
      final r = _Rig();
      await r.music.setClassDay(true, evening: true);
      await r.music.setRoomChoice(
        true,
        startWithTake: MainRoomMusic.lampLeftOnTake,
        until: DateTime.now().add(const Duration(hours: 5)),
      );
      expect(r.music.currentRole, RoomMusicRole.classDay);
      expect(r.log.score, ['score:start:evening:opener']);
      expect(
        r.log.main,
        isNot(contains('main:prefer:${MainRoomMusic.lampLeftOnTake}')),
        reason: 'it would open some other day with Lamp left on',
      );
      expect(
        r.music.nowPlaying.value,
        MainRoomMusic.assetForTake(MainRoomMusic.lampLeftOnTake),
      );
      expect(r.music.roomChoice, isTrue);
      expect(
        r.music.enabled,
        isFalse,
        reason: 'the saved setting is untouched',
      );
      // The opener moves on to the bed: the door says "Room music".
      r.score.nowPlaying.value = 'music/class_day/bed_evening_0.m4a';
      expect(r.music.nowPlaying.value, 'music/class_day/bed_evening_0.m4a');
    });

    test('with music already on in Me there is no opener: straight to the '
        'Evening bed', () async {
      final r = _Rig();
      await r.music.setEnabled(true);
      await r.music.setClassDay(true, evening: true);
      expect(r.log.score.last, 'score:start:evening');
      expect(r.log.score.any((e) => e.contains('opener')), isFalse);
    });

    test('a press that is taken back before the music starts leaves no opener '
        'owing', () async {
      final r = _Rig();
      await r.music.setClassDay(true, evening: true);
      r.score.failStart = true;
      await r.music.setRoomChoice(
        true,
        startWithTake: MainRoomMusic.lampLeftOnTake,
      );
      r.score.failStart = false;
      await r.music.setRoomChoice(false);
      await r.music.setRoomChoice(null);
      await r.music.setEnabled(true);
      expect(r.log.score.last, 'score:start:evening');
    });

    test(
      'a press on a day without classes is the rotation, as before',
      () async {
        final r = _Rig();
        await r.music.setClassDay(false);
        await r.music.setRoomChoice(
          true,
          startWithTake: MainRoomMusic.lampLeftOnTake,
        );
        expect(r.log.main, [
          'main:prefer:${MainRoomMusic.lampLeftOnTake}',
          'main:start',
        ]);
        expect(r.log.score, isEmpty);
      },
    );

    test('the choice lapsing at the night\'s end quiets the score', () async {
      final r = _Rig();
      final night = DateTime.utc(2026, 10, 7, 8);
      Clock.freeze(DateTime.utc(2026, 10, 7, 1));
      await r.music.setClassDay(true, evening: true);
      await r.music.setRoomChoice(
        true,
        startWithTake: MainRoomMusic.lampLeftOnTake,
        until: night,
      );
      expect(r.music.currentRole, RoomMusicRole.classDay);
      Clock.freeze(DateTime.utc(2026, 10, 7, 9));
      expect(r.music.roomChoice, isNull);
      await r.music.setForeground(true); // any reconcile
      expect(r.music.currentRole, isNull);
      expect(r.log.score.last, 'score:stop');
    });

    test(
      'turning it off at the door fades the score and leaves Me alone',
      () async {
        final r = _Rig();
        await r.music.setEnabled(true);
        await r.music.setClassDay(true, evening: true);
        await r.music.setRoomChoice(false);
        expect(r.music.currentRole, isNull);
        expect(r.music.enabled, isTrue);
        expect(r.log.score.last, 'score:stop');
        await r.music.setRoomChoice(null);
        expect(r.music.currentRole, RoomMusicRole.classDay);
      },
    );
  });

  group('what the door reads', () {
    test('nowPlaying follows the score, then the rotation', () async {
      final r = _Rig();
      expect(r.music.nowPlaying.value, isNull);
      r.score.nowPlaying.value = 'music/class_day/bed_between_0.m4a';
      expect(r.music.nowPlaying.value, 'music/class_day/bed_between_0.m4a');
      r.score.nowPlaying.value = null;
      r.main.nowPlaying.value = MainRoomMusic.assetForTake(9);
      expect(r.music.nowPlaying.value, MainRoomMusic.assetForTake(9));
    });

    test('a disposed controller stops listening', () async {
      final r = _Rig();
      await r.music.dispose();
      r.score.nowPlaying.value = 'music/class_day/bed_between_0.m4a';
      expect(r.music.nowPlaying.value, isNull);
      expect(r.log.events, contains('score:dispose'));
    });
  });

  test('the role is only chosen where the platform can play it', () {
    // The web build has no beat clock to stand on, so it keeps the rotation.
    expect(kIsWeb, isFalse, reason: 'these tests run on the VM');
    expect(RoomMusicRole.values, contains(RoomMusicRole.classDay));
  });
}
