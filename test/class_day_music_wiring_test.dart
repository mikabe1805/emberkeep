// The Quests page and the room's music on a class day: the page tells the
// controller whether it is a class day and whether the glass is turned to the
// evening, and tells it when a class is kept. Nothing here plays a sound; the
// score and the rotation are recorded.
//
// Clocks are frozen at INSTANTS (New York wall times converted from UTC), so
// these hold on a host in any zone.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/audio.dart';
import 'package:emberkeep/background_music.dart';
import 'package:emberkeep/class_day_score.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/main_room_music.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/class_day/class_day_model.dart';
import 'package:emberkeep/widgets/class_day/doorway_motion.dart'
    show doorwayChimeDoneAfter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_renders/class_day_harness.dart' show loadRoomFonts;
import 'support/rutgers_fall_2026_ics_fixture.dart';

DateTime _ny(int day, int hour, int minute, [int second = 0]) =>
    DateTime.utc(2026, 10, day, hour + 4, minute, second).toLocal();

final AcademicSchedule _fall2026 = AcademicScheduleIcsImporter.parse(
  rutgersFall2026IcsFixture(),
).applyTo(AcademicSchedule.empty(), updatedAt: DateTime.utc(2026, 8, 27));

ClassDay _lookup(DateTime now, {CivilDate? day}) =>
    projectClassDay(_fall2026, now, day: day);

void _keepAt(GameState state, DateTime at, {Set<String>? only}) {
  Clock.freeze(at);
  final day = _lookup(at);
  for (final entry in day.classes) {
    if (only != null && !only.contains(entry.courseCode)) continue;
    state.keepClass(entry.facts, dayClassKeys: day.dayClassKeys);
  }
}

GameState _mika({bool reduceMotion = false}) => GameState()
  ..onboarded = true
  ..playerName = 'Mika'
  ..level = 18
  ..xp = 284
  ..totalXp = 4280
  ..soundEnabled = false
  ..reduceMotion = reduceMotion;

GameState _tuesdayKept() {
  final state = _mika();
  _keepAt(state, _ny(6, 11, 53), only: {'14:332:331'});
  _keepAt(state, _ny(6, 15, 35), only: {'01:198:206'});
  return state;
}

class _NoLuck implements math.Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.999;
  @override
  int nextInt(int max) => 0;
}

class _MainMusic implements MainRoomMusicPlayback {
  final calls = <String>[];
  bool enabled = false;

  @override
  final ValueNotifier<String?> nowPlaying = ValueNotifier<String?>(null);

  @override
  bool get isPlaying => enabled;

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

class _Score implements ClassDayScorePlayback {
  final calls = <String>[];
  bool playing = false;

  /// Every class kept, as the wait after the chime that was asked for.
  List<int> get kept => [
    for (final c in calls)
      if (c.startsWith('kept:')) int.parse(c.substring(5)),
  ];

  @override
  final ValueNotifier<String?> nowPlaying = ValueNotifier<String?>(null);

  @override
  bool get isPlaying => playing;

  @override
  Future<void> start({required bool evening, bool opener = false}) async {
    calls.add('start:${evening ? 'evening' : 'between'}');
    playing = true;
  }

  @override
  Future<void> setEvening(bool evening) async => calls.add('evening:$evening');

  @override
  void classKept({required Duration after}) =>
      calls.add('kept:${after.inMilliseconds}');

  @override
  Future<void> stop({Duration fade = MainRoomMusic.stopFadeOut}) async {
    if (!playing) return;
    calls.add('stop');
    playing = false;
  }

  @override
  Future<void> setForeground(bool foreground) async {}

  @override
  Future<void> dispose() async {}
}

class _FocusTransport implements BackgroundMusicTransport {
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

class _Rig {
  _Rig({bool musicOn = true}) {
    music = BackgroundMusicController(
      mainMusic: main,
      classDayScore: score,
      transport: _FocusTransport(),
    );
    unawaited(music.setEnabled(musicOn));
  }
  final main = _MainMusic();
  final score = _Score();
  late final BackgroundMusicController music;
}

Future<GameState> _mount(
  WidgetTester tester, {
  required DateTime at,
  required _Rig rig,
  GameState? state,
  Size size = const Size(393, 852),
}) async {
  tester.view.devicePixelRatio = 1;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.binding.setSurfaceSize(null);
  });
  Clock.freeze(at);
  final s = (state ?? _mika())..lastActiveDay ??= Days.key(at);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(
          body: QuestsPage(
            state: s,
            quests: [
              Quest(
                title: 'Read ten pages',
                stat: Stat.intl,
                difficulty: 4,
                schedule: QuestSchedule.daily,
              ),
            ],
            onRefresh: () => 0,
            onPersist: () {},
            onAdd: (_) => true,
            onRemove: (_) {},
            onSnapshot: () => jsonEncode(s.toJson()),
            onRestore: (_) {},
            classDays: _lookup,
            musicController: rig.music,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  return s;
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(const Duration(milliseconds: 100));
    elapsed += const Duration(milliseconds: 100);
  }
}

final _room = find.byKey(const Key('class-day-room'));
final _there = find.byKey(const Key('class-there-button'));
final _evening = find.byKey(const Key('class-evening'));
final _setAside = find.text(classSetAsideLabel);
final _undoSetAside = find.byKey(const Key('class-dismissed-undo'));

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadRoomFonts();
  });
  setUp(() {
    GameState.debugRandomFactory = _NoLuck.new;
    Sfx.instance.soundEnabled = false;
    for (final channel in const [
      MethodChannel('xyz.luan/audioplayers'),
      MethodChannel('xyz.luan/audioplayers.global'),
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => null);
    }
  });
  tearDown(() {
    Clock.reset();
    GameState.debugRandomFactory = null;
    Sfx.instance.soundEnabled = true;
  });

  group('the page tells the music what kind of day it is', () {
    testWidgets('a class day by day: the Between bed, not the rotation', (
      tester,
    ) async {
      final rig = _Rig();
      await _mount(tester, at: _ny(6, 8, 5), rig: rig);
      expect(_room, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(rig.score.calls, ['start:between']);
      expect(rig.main.calls.where((c) => c == 'start'), hasLength(1));
      expect(rig.main.enabled, isFalse, reason: 'handed over to the score');
      expect(rig.music.currentRole, RoomMusicRole.classDay);
    });

    testWidgets('a class day in the evening: the Evening bed', (tester) async {
      final rig = _Rig();
      await _mount(tester, at: _ny(6, 19, 30), rig: rig, state: _tuesdayKept());
      await tester.pump(const Duration(milliseconds: 100));
      expect(_evening, findsOneWidget);
      expect(rig.score.calls, ['start:evening']);
    });

    testWidgets('the glass turning to the evening is told to the score, which '
        'keeps playing', (tester) async {
      final rig = _Rig();
      final state = _mika();
      _keepAt(state, _ny(6, 11, 53), only: {'14:332:331'});
      await _mount(tester, at: _ny(6, 15, 35), rig: rig, state: state);
      await tester.pump(const Duration(milliseconds: 100));
      expect(rig.score.calls, ['start:between']);
      await tester.tap(_there);
      await tester.pump();
      // The Doorway's moment, the day card, and a tap to let it go.
      await _pumpFor(tester, const Duration(milliseconds: 4800));
      expect(
        rig.score.calls,
        isNot(contains('evening:true')),
        reason: 'under the held moment the room keeps the day',
      );
      await tester.tapAt(const Offset(196, 300));
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 2800));
      expect(_evening, findsOneWidget);
      expect(rig.score.calls.last, 'evening:true');
      expect(rig.score.calls.where((c) => c.startsWith('start')), hasLength(1));
    });

    testWidgets('with the board up the evening bed still follows the day', (
      tester,
    ) async {
      final rig = _Rig();
      await _mount(tester, at: _ny(6, 13, 0), rig: rig, state: _tuesdayKept());
      await tester.pump(const Duration(milliseconds: 100));
      expect(rig.score.calls, ['start:between']);
      await tester.tap(find.byKey(const Key('class-day-toggle-board')));
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 600));
      // The day moves on while the board is up (the room stays built under
      // it, so the music keeps following the day).
      Clock.freeze(_ny(6, 19, 30));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(rig.score.calls.last, 'evening:true');
    });

    testWidgets('a day without classes keeps the rotation', (tester) async {
      final rig = _Rig();
      await _mount(tester, at: _ny(10, 11, 0), rig: rig);
      expect(_room, findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(rig.score.calls, isEmpty);
      expect(rig.main.calls, ['start']);
      expect(rig.music.currentRole, RoomMusicRole.main);
    });

    testWidgets('the class day ending hands the room back to the rotation', (
      tester,
    ) async {
      final rig = _Rig();
      await _mount(tester, at: _ny(6, 19, 30), rig: rig, state: _tuesdayKept());
      await tester.pump(const Duration(milliseconds: 100));
      expect(rig.music.currentRole, RoomMusicRole.classDay);
      // Saturday: no classes.
      Clock.freeze(_ny(10, 9, 0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(rig.score.calls.last, 'stop');
      expect(rig.music.currentRole, RoomMusicRole.main);
      expect(rig.main.calls.last, 'start');
    });

    testWidgets('with the music off a class day plays nothing', (tester) async {
      final rig = _Rig(musicOn: false);
      await _mount(tester, at: _ny(6, 8, 5), rig: rig);
      await tester.pump(const Duration(milliseconds: 100));
      expect(rig.score.calls, isEmpty);
      expect(rig.main.calls, isEmpty);
      expect(rig.music.currentRole, isNull);
    });

    testWidgets('leaving the page ends the class day for the music', (
      tester,
    ) async {
      final rig = _Rig();
      await _mount(tester, at: _ny(6, 8, 5), rig: rig);
      await tester.pump(const Duration(milliseconds: 100));
      expect(rig.music.currentRole, RoomMusicRole.classDay);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      expect(rig.score.calls.last, 'stop');
      expect(rig.music.currentRole, RoomMusicRole.main);
    });
  });

  group('a class kept is told to the music, once', () {
    testWidgets('one mark: the chime hangs at 900 ms, the swell may begin '
        '950 ms after', (tester) async {
      final rig = _Rig();
      await _mount(tester, at: _ny(6, 11, 52), rig: rig);
      await tester.pump(const Duration(milliseconds: 100));
      expect(rig.score.kept, isEmpty);
      await tester.tap(_there);
      await tester.pump();
      expect(rig.score.kept, [950]);
      await _pumpFor(tester, const Duration(seconds: 6));
      expect(rig.score.kept, [950], reason: 'once, not again as it settles');
    });

    testWidgets('Reduce Motion: the chime is at 260 ms, so 310 ms', (
      tester,
    ) async {
      final rig = _Rig();
      await _mount(
        tester,
        at: _ny(6, 11, 52),
        rig: rig,
        state: _mika(reduceMotion: true),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(_there);
      await tester.pump();
      expect(rig.score.kept, [310]);
      await _pumpFor(tester, const Duration(seconds: 4));
    });

    testWidgets('the shortcut keeping three classes waits for the last '
        'ticket: 180 ms more for each', (tester) async {
      final rig = _Rig();
      await _mount(tester, at: _ny(5, 19, 15), rig: rig);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('class-all-of-today')));
      await tester.pump();
      expect(rig.score.kept, [950 + 360]);
      await _pumpFor(tester, const Duration(seconds: 6));
      expect(rig.score.kept, hasLength(1));
    });

    testWidgets('"Couldn\'t make it" and its undo say nothing to the music', (
      tester,
    ) async {
      final rig = _Rig();
      await _mount(tester, at: _ny(6, 8, 5), rig: rig);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(_setAside.first);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_undoSetAside, findsOneWidget);
      await tester.tap(_undoSetAside);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 6));
      expect(rig.score.kept, isEmpty);
    });

    testWidgets('undoing a kept class says nothing either', (tester) async {
      final rig = _Rig();
      final state = _mika();
      _keepAt(state, _ny(6, 11, 53), only: {'14:332:331'});
      await _mount(tester, at: _ny(6, 15, 35), rig: rig, state: state);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(_there);
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 4800));
      await tester.tapAt(const Offset(196, 300));
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 2800));
      expect(rig.score.kept, [950]);
      final line = find.byKey(const Key('class-evening-record'));
      expect(line, findsOneWidget);
      await tester.drag(line, const Offset(-260, 0));
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(rig.score.kept, [950], reason: 'the undo was not a mark');
    });

    testWidgets(
      'a mark with the music off is not told to anything that plays',
      (tester) async {
        final rig = _Rig(musicOn: false);
        await _mount(tester, at: _ny(6, 11, 52), rig: rig);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(_there);
        await tester.pump();
        await _pumpFor(tester, const Duration(seconds: 6));
        // The page tells the controller; the controller has no score playing,
        // so nothing reaches it.
        expect(rig.score.kept, isEmpty);
        expect(rig.score.calls, isEmpty);
      },
    );
  });

  test('the earliest beat is the chime\'s hang plus a clear 50 ms', () {
    expect(
      doorwayChimeDoneAfter(reduceMotion: false),
      const Duration(milliseconds: 950),
    );
    expect(
      doorwayChimeDoneAfter(reduceMotion: true),
      const Duration(milliseconds: 310),
    );
    expect(
      doorwayChimeDoneAfter(reduceMotion: false, tickets: 3),
      const Duration(milliseconds: 1310),
    );
    expect(
      doorwayChimeDoneAfter(reduceMotion: false, tickets: 0),
      const Duration(milliseconds: 950),
    );
  });
}
