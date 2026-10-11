// The class-day evening: once the last class is over and every class is kept
// (or the schedule-aware wind-down has begun), the room turns to the window
// and the armchair and the glass holds the day on one line, the music, a page
// in the journal and closing the day.
//
// Clocks are frozen at INSTANTS (New York wall times converted from UTC), so
// these hold on a host in any zone: Codemagic's Mac is not on New York time.
// No test reads a wall time at or after 8 PM New York, where a UTC host's
// local date would already be the next day (the night's own key,
// nightDoneDay), except where a test says so and reads only the class day's
// own key.
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
import 'package:emberkeep/screens/journal_entry.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/class_day/class_kept_celebration.dart';
import 'package:emberkeep/widgets/class_day/class_room_stage.dart';
import 'package:emberkeep/widgets/class_day/doorway_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_renders/class_day_harness.dart' show loadRoomFonts;
import 'support/rutgers_fall_2026_ics_fixture.dart';

/// A New York wall time in October 2026 (EDT, UTC-4) as an instant.
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
    expect(
      state.keepClass(entry.facts, dayClassKeys: day.dayClassKeys),
      isNotNull,
      reason: '${entry.courseCode} at $at',
    );
  }
}

GameState _mika() => GameState()
  ..onboarded = true
  ..playerName = 'Mika'
  ..level = 18
  ..xp = 284
  ..totalXp = 4280
  ..soundEnabled = false;

/// Both of Tuesday's classes kept.
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

/// The main rotation, recorded instead of played.
class _MainMusic implements MainRoomMusicPlayback {
  final calls = <String>[];
  bool enabled = false;
  int? preferred;

  @override
  final ValueNotifier<String?> nowPlaying = ValueNotifier<String?>(null);

  @override
  bool get isPlaying => enabled;

  @override
  void preferNextTake(int take) {
    preferred = take;
    calls.add('prefer:$take');
  }

  @override
  Future<void> setEnabled(bool value) async {
    if (enabled == value) return;
    enabled = value;
    calls.add(value ? 'start' : 'pause');
    nowPlaying.value = value
        ? MainRoomMusic.assetForTake(preferred ?? 1)
        : null;
    preferred = null;
  }

  @override
  Future<void> setForeground(bool value) async {}

  @override
  Future<void> retryAfterUserGesture() async {}

  @override
  Future<void> dispose() async {}
}

/// The class-day score, recorded instead of played. On a class day it is the
/// room's music, so the evening door talks to it and not to the rotation.
class _Score implements ClassDayScorePlayback {
  final calls = <String>[];
  bool playing = false;

  @override
  final ValueNotifier<String?> nowPlaying = ValueNotifier<String?>(null);

  @override
  bool get isPlaying => playing;

  @override
  Future<void> start({required bool evening, bool opener = false}) async {
    calls.add(
      'start:${evening ? 'evening' : 'between'}${opener ? ':opener' : ''}',
    );
    playing = true;
    nowPlaying.value = opener
        ? MainRoomMusic.assetForTake(MainRoomMusic.lampLeftOnTake)
        : 'music/class_day/bed_${evening ? 'evening' : 'between'}.m4a';
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
    nowPlaying.value = null;
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

class _Page {
  _Page(this.state);
  final GameState state;
  int persisted = 0;
  final restored = <String>[];
}

Future<_Page> _mount(
  WidgetTester tester, {
  required DateTime at,
  GameState? state,
  bool reduceMotion = false,
  double textScale = 1,
  BackgroundMusicController? music,
  Size size = const Size(393, 852),
}) async {
  tester.view.devicePixelRatio = 1;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.binding.setSurfaceSize(null);
  });
  Clock.freeze(at);
  final s = (state ?? _mika())
    ..reduceMotion = reduceMotion
    ..lastActiveDay ??= Days.key(at);
  final page = _Page(s);
  final quests = [
    Quest(
      title: 'Read ten pages',
      stat: Stat.intl,
      difficulty: 4,
      schedule: QuestSchedule.daily,
    ),
  ];
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: QuestsPage(
            state: s,
            quests: quests,
            onRefresh: () => 0,
            onPersist: () => page.persisted++,
            onAdd: (_) => true,
            onRemove: (_) {},
            onSnapshot: () => jsonEncode(s.toJson()),
            onRestore: page.restored.add,
            classDays: _lookup,
            musicController: music,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  return page;
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

/// The Doorway plays before the day's card: the tickets unhook and drop into
/// the bowl (the mark, then about 1.9 s, then 0.9 s of flight), and the card
/// shows half a second after they land, then takes about a second and a half to
/// arrive. A shortcut that keeps several classes starts its marks 180 ms apart.
const _dayCardAfter = Duration(milliseconds: 4800);
const _shortcutCardAfter = Duration(milliseconds: 5400);

final _evening = find.byKey(const Key('class-evening'));
final _there = find.byKey(const Key('class-there-button'));
final _celebration = find.byType(ClassKeptCelebration);
final _closeDay = find.byKey(const Key('class-evening-close-day'));
final _musicRow = find.byKey(const Key('class-evening-music'));
final _playMark = find.byKey(const Key('class-evening-music-play'));
final _levels = find.byKey(const Key('class-evening-music-levels'));
final _write = find.byKey(const Key('class-evening-write'));

/// BOARD, then the board scrolled to its end, where the evening rail lives.
Future<void> _boardToEnd(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('class-day-toggle-board')));
  await tester.pump();
  await _pumpFor(tester, const Duration(milliseconds: 600));
  final board = find.byKey(const ValueKey('quest-board-scroll'));
  for (var i = 0; i < 8; i++) {
    await tester.drag(board, const Offset(0, -400), warnIfMissed: false);
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }
}

const _phone = Size(393, 852);
const _small = Size(375, 667);

/// How far the evening glass could scroll: zero when everything fits.
double _scrollExtent(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('class-evening-scroll')),
        matching: find.byType(Scrollable),
      ),
    )
    .position
    .maxScrollExtent;

/// The room's own stage: the Doorway (the celebration paints another one
/// while it is up).
final Finder _doorway = find.descendant(
  of: find.byKey(const Key('class-day-room')),
  matching: find.byType(DoorwayStage),
);

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // The real faces: the test font's wide glyphs would wrap doors that fit.
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

  group('the room turns to the evening', () {
    testWidgets('the last class kept: TUESDAY, DONE., then the glass turns '
        'to the evening over the same Doorway, no camera walk', (tester) async {
      final state = _mika();
      _keepAt(state, _ny(6, 11, 53), only: {'14:332:331'});
      await _mount(tester, at: _ny(6, 15, 35), state: state);
      expect(_doorway, findsOneWidget);
      await tester.tap(_there);
      await tester.pump();
      await _pumpFor(tester, _dayCardAfter);
      expect(find.text('TUESDAY, DONE.'), findsOneWidget);
      // Under the held moment the room keeps the day; nothing turns yet. The
      // Doorway stands behind the moment too, held still.
      expect(_evening, findsNothing);
      expect(
        find.descendant(of: _celebration, matching: find.byType(DoorwayStage)),
        findsOneWidget,
      );

      await tester.tapAt(const Offset(196, 300));
      await tester.pump();
      // The room is the same Doorway all the way: it never swaps for another
      // view, and nothing walks. Only the glass turns.
      final stage = tester.state<DoorwayStageState>(_doorway);
      for (var i = 0; i < 26; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(_doorway, findsOneWidget, reason: 'frame $i');
        expect(tester.state<DoorwayStageState>(_doorway), same(stage));
        expect(
          find.descendant(
            of: find.byKey(const Key('class-day-room')),
            matching: find.byType(BackdropFilter),
          ),
          findsOneWidget,
          reason: 'only the glass blurs what is behind it',
        );
      }
      expect(_celebration, findsNothing);
      expect(find.byType(ClassRoomStage), findsNothing);

      expect(_evening, findsOneWidget);
      expect(find.text('Tuesday’s classes, both attended'), findsOneWidget);
      expect(find.text('+60 XP'), findsOneWidget);
      expect(find.text('Write a line'), findsOneWidget);
      // 3:35 PM is before the wind-down: nothing asks to close the day.
      expect(_closeDay, findsNothing);
      // Today's three stays one line with BOARD.
      expect(find.byKey(const Key('class-day-todays-three')), findsOneWidget);
      expect(find.byKey(const Key('class-day-toggle-board')), findsOneWidget);
      // No Steward door: no scene is waiting.
      expect(find.textContaining('Steward'), findsNothing);
    });

    testWidgets('opened in the evening, the room is already there', (
      tester,
    ) async {
      await _mount(tester, at: _ny(6, 19, 30), state: _tuesdayKept());
      expect(_evening, findsOneWidget);
      expect(_doorway, findsOneWidget);
      // Dusk: the clock's light is the evening plate, not a tint of another.
      final stage = tester.state<DoorwayStageState>(_doorway);
      expect(stage.lights.evening, 1);
      expect(stage.lights.midday, 0);
      expect(find.text('Tuesday’s classes, both attended'), findsOneWidget);
      expect(_closeDay, findsOneWidget);
    });

    testWidgets('Reduce Motion: no walk, the Doorway stands still', (
      tester,
    ) async {
      final state = _mika();
      _keepAt(state, _ny(6, 11, 53), only: {'14:332:331'});
      await _mount(
        tester,
        at: _ny(6, 15, 35),
        state: state,
        reduceMotion: true,
      );
      expect(tester.state<DoorwayStageState>(_doorway).animating, isFalse);
      await tester.tap(_there);
      await tester.pump();
      // Every move is a fade: the tickets land in the bowl in under a second.
      await _pumpFor(tester, const Duration(milliseconds: 1800));
      await tester.tapAt(const Offset(196, 300));
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 700));
      expect(tester.state<DoorwayStageState>(_doorway).animating, isFalse);
      expect(_evening, findsOneWidget);
    });

    testWidgets('another room style: the same Doorway, the same evening', (
      tester,
    ) async {
      final state = _tuesdayKept()
        ..wallStyle = 'wall_archive'
        ..ownedStyles.add('wall_archive');
      await _mount(tester, at: _ny(6, 19, 30), state: state);
      expect(_evening, findsOneWidget);
      expect(find.byType(ClassRoomStage), findsNothing);
      expect(find.byKey(const Key('class-day-room-plate')), findsNothing);
      expect(_doorway, findsOneWidget);
    });

    // Visible, not merely present: the glass scrolls what does not fit, so
    // every door must be hit-testable and nothing may hide in the scroll.
    for (final (label, at, size, scale) in [
      ('Tuesday folded, 393 x 852 at 130%', _ny(6, 19, 30), _phone, 1.3),
      ('Monday three waiting, 393 x 852 at 130%', _ny(5, 19, 15), _phone, 1.3),
      ('Monday three waiting, 375 x 667', _ny(5, 19, 15), _small, 1.0),
      ('Monday three waiting, 375 x 667 at 130%', _ny(5, 19, 15), _small, 1.3),
    ]) {
      testWidgets('$label: every door is on screen and pressable', (
        tester,
      ) async {
        await _mount(
          tester,
          at: at,
          state: at.day == _ny(6, 19, 30).day ? _tuesdayKept() : null,
          textScale: scale,
          size: size,
        );
        expect(_evening, findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          _scrollExtent(tester),
          0,
          reason: 'nothing in the evening glass is out of view',
        );
        expect(_write.hitTestable(), findsOneWidget);
        expect(_closeDay.hitTestable(), findsOneWidget);
        if (at.day == 5) {
          expect(_there.hitTestable(), findsOneWidget);
          expect(
            find.byKey(const Key('class-all-of-today')).hitTestable(),
            findsOneWidget,
          );
        }
        // Close the day keeps the text size: it is set as large as Write a
        // line, never shrunk to fit beside it.
        final close = tester.getSize(
          find.descendant(of: _closeDay, matching: find.byType(Text)),
        );
        final write = tester.getSize(
          find.descendant(of: _write, matching: find.byType(Text)),
        );
        expect(close.height, closeTo(write.height, 0.5));
      });
    }
  });

  group('the wind-down follows his timetable', () {
    testWidgets('Monday 5:45 PM, in the late lecture: no evening and no '
        'CLOSE THE DAY rail on the board', (tester) async {
      final state = _mika();
      _keepAt(state, _ny(5, 14, 5), only: {'14:332:361'});
      await _mount(tester, at: _ny(5, 17, 45), state: state);
      expect(_evening, findsNothing);
      expect(find.text("I'M HERE"), findsOneWidget);
      await _boardToEnd(tester);
      // The board's end is on screen (its footer rail), and no evening rail.
      expect(find.byKey(const Key('close-day-rail')), findsNothing);
      expect(find.text('CLOSE DAY'), findsOneWidget);
    });

    testWidgets('Monday 7:15 PM, the lecture over: the board has its CLOSE '
        'THE DAY rail', (tester) async {
      await _mount(tester, at: _ny(5, 19, 15));
      await _boardToEnd(tester);
      expect(find.byKey(const Key('close-day-rail')), findsOneWidget);
    });

    testWidgets('Monday 7:15 PM: the evening leads with the classes still '
        'waiting, and closing the day is there', (tester) async {
      final music = BackgroundMusicController(
        mainMusic: _MainMusic(),
        classDayScore: _Score(),
        transport: _FocusTransport(),
      );
      final page = await _mount(tester, at: _ny(5, 19, 15), music: music);
      expect(_evening, findsOneWidget);
      // The card leads with the 5:40 lecture and the shortcut, exactly as
      // during the day; the two earlier classes are quiet dots.
      expect(find.text('SEC 204 · ended 7:00'), findsOneWidget);
      expect(find.byKey(const Key('class-quiet-dot')), findsNWidgets(2));
      expect(find.text('I went to all of today’s classes'), findsOneWidget);
      expect(_musicRow, findsNothing, reason: 'the glass stays about marking');
      expect(_closeDay, findsOneWidget);

      await tester.tap(find.byKey(const Key('class-all-of-today')));
      await tester.pump();
      expect(page.state.classesKeptOn('2026-10-05'), hasLength(3));
      await _pumpFor(tester, _shortcutCardAfter);
      expect(find.text('MONDAY, DONE.'), findsOneWidget);
      await tester.tapAt(const Offset(196, 300));
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 800));
      expect(_celebration, findsNothing);
      expect(find.text('Monday’s classes, all three attended'), findsOneWidget);
      expect(find.text('+85 XP'), findsOneWidget);
      expect(_musicRow, findsOneWidget, reason: 'the music joins now');
    });

    testWidgets('a mark made in the evening plays over the same Doorway', (
      tester,
    ) async {
      final state = _mika();
      _keepAt(state, _ny(8, 9, 55), only: {'14:332:361'});
      _keepAt(state, _ny(8, 15, 22), only: {'01:198:206'});
      await _mount(tester, at: _ny(8, 18, 55), state: state);
      expect(_evening, findsOneWidget);
      await tester.tap(_there);
      await tester.pump();
      // The scene first: the evening glass stays as it was while the tickets
      // drop into the bowl; nothing covers the room until they have landed.
      await _pumpFor(tester, const Duration(milliseconds: 900));
      expect(_celebration, findsNothing);
      await _pumpFor(tester, _dayCardAfter);
      expect(
        find.descendant(of: _celebration, matching: find.byType(DoorwayStage)),
        findsOneWidget,
      );
      expect(find.text('THURSDAY, DONE.'), findsOneWidget);
    });

    testWidgets('Close the day in the glass opens the night ledger', (
      tester,
    ) async {
      // The ledger's folio is sized for the test font at the existing night
      // test's phone (its own layout is not this slice's).
      await _mount(
        tester,
        at: _ny(6, 19, 30),
        state: _tuesdayKept(),
        size: const Size(430, 932),
      );
      await tester.tap(_closeDay);
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 400));
      expect(find.text('Close the ledger'), findsOneWidget);
    });

    testWidgets('once tonight is closed, closing the day leaves the glass', (
      tester,
    ) async {
      final state = _tuesdayKept()
        ..nightDoneDay = Days.nightKey(_ny(6, 19, 30));
      await _mount(tester, at: _ny(6, 19, 30), state: state);
      expect(_evening, findsOneWidget);
      expect(_closeDay, findsNothing);
      expect(find.text('Write a line'), findsOneWidget);
    });
  });

  group("the evening's doors", () {
    testWidgets('Write a line opens a fresh journal page for today', (
      tester,
    ) async {
      final page = await _mount(
        tester,
        at: _ny(6, 19, 30),
        state: _tuesdayKept(),
      );
      final before = page.state.journal.length;
      await tester.tap(find.byKey(const Key('class-evening-write')));
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(
        find.byKey(const ValueKey('class-evening-journal')),
        findsOneWidget,
      );
      expect(find.byType(JournalEntryScreen), findsOneWidget);
      expect(
        page.state.journal,
        hasLength(before),
        reason: 'opening writes nothing',
      );
    });

    testWidgets('a line written under an armed undo settles it, so the '
        'undo can never erase the page', (tester) async {
      final state = _mika();
      _keepAt(state, _ny(6, 11, 53), only: {'14:332:331'});
      final page = await _mount(tester, at: _ny(6, 15, 35), state: state);
      await tester.tap(_there);
      await tester.pump();
      await _pumpFor(tester, _dayCardAfter);
      await tester.tapAt(const Offset(196, 300));
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 2800));
      final undoRow = find.byWidgetPredicate(
        (w) => w is Dismissible && '${w.key}'.contains('class-undo-'),
      );
      expect(undoRow, findsOneWidget);
      await tester.tap(find.byKey(const Key('class-evening-write')));
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 600));
      await tester.enterText(
        find.byType(TextField).first,
        'Office hours ran long.',
      );
      await _pumpFor(tester, const Duration(milliseconds: 1500));
      expect(page.state.journal.last.text, contains('Office hours ran long.'));
      Navigator.of(tester.element(find.byType(JournalEntryScreen))).pop();
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 800));
      expect(undoRow, findsNothing);
    });

    testWidgets('the music never starts by itself; a press plays Lamp left '
        'on for tonight and leaves the saved setting alone', (tester) async {
      final main = _MainMusic();
      final score = _Score();
      final music = BackgroundMusicController(
        mainMusic: main,
        classDayScore: score,
        transport: _FocusTransport(),
      );
      unawaited(music.setEnabled(false));
      final page = await _mount(
        tester,
        at: _ny(6, 19, 30),
        state: _tuesdayKept(),
        music: music,
      );
      expect(_musicRow, findsOneWidget);
      expect(find.text('Lamp left on'), findsOneWidget);
      expect(_playMark, findsOneWidget);
      expect(_levels, findsNothing);
      expect(main.calls, isEmpty);
      expect(score.calls, isEmpty, reason: 'a class day alone plays nothing');

      await tester.tap(_musicRow);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // On a class day the score is the room's music: Lamp left on is its
      // opener, and the rotation is not told (it would open with Lamp left on
      // some other day).
      expect(score.calls, ['start:evening:opener']);
      expect(main.calls, isEmpty);
      expect(_playMark, findsNothing);
      expect(find.text('Lamp left on'), findsOneWidget);
      expect(_levels, findsOneWidget);
      expect(page.state.musicEnabled, isFalse);
      expect(music.enabled, isFalse);

      // The opener gives way to the evening bed: the room's music.
      score.nowPlaying.value = 'music/class_day/bed_evening.m4a';
      await tester.pump();
      expect(find.text('Room music'), findsOneWidget);

      await tester.tap(_musicRow);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(score.calls.last, 'stop');
      expect(_playMark, findsOneWidget);
    });

    testWidgets('with music on in Me, the evening shows it playing and a '
        'press quiets it for tonight', (tester) async {
      final main = _MainMusic();
      final score = _Score();
      final music = BackgroundMusicController(
        mainMusic: main,
        classDayScore: score,
        transport: _FocusTransport(),
      );
      final state = _tuesdayKept()..musicEnabled = true;
      unawaited(music.setEnabled(true));
      await _mount(tester, at: _ny(6, 19, 30), state: state, music: music);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_levels, findsOneWidget);
      // The page told the controller it is a class day, in its evening: the
      // Evening bed, with no opener (nothing was pressed), and not the rotation.
      expect(score.calls, ['start:evening']);
      expect(main.enabled, isFalse);
      await tester.tap(_musicRow);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(score.calls.last, 'stop');
      expect(state.musicEnabled, isTrue, reason: 'Me keeps his setting');
      expect(music.enabled, isTrue);
    });

    testWidgets("tonight's choice gives way to the saved setting once the "
        'evening is over', (tester) async {
      final main = _MainMusic();
      final score = _Score();
      final music = BackgroundMusicController(
        mainMusic: main,
        classDayScore: score,
        transport: _FocusTransport(),
      );
      unawaited(music.setEnabled(false));
      await _mount(
        tester,
        at: _ny(6, 19, 30),
        state: _tuesdayKept(),
        music: music,
      );
      await tester.tap(_musicRow);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(music.roomChoice, isTrue);
      expect(score.playing, isTrue);
      // Wednesday morning: a class day again, before any class.
      Clock.freeze(_ny(7, 7, 30));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_evening, findsNothing);
      expect(music.roomChoice, isNull);
      expect(score.calls.last, 'stop');
      expect(score.playing, isFalse);
    });

    testWidgets('undo: the day line swiped left past 42% restores the save '
        'from before the mark, as on the card', (tester) async {
      final state = _mika();
      _keepAt(state, _ny(6, 11, 53), only: {'14:332:331'});
      final page = await _mount(tester, at: _ny(6, 15, 35), state: state);
      final before = jsonEncode(page.state.toJson());
      await tester.tap(_there);
      await tester.pump();
      await _pumpFor(tester, _dayCardAfter);
      await tester.tapAt(const Offset(196, 300));
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 2800));
      final line = find.byKey(const Key('class-evening-record'));
      expect(line, findsOneWidget);
      expect(find.text('UNDO'), findsNothing);
      await tester.drag(line, const Offset(-260, 0));
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(page.restored, [before]);
      final restored = GameState.fromJson(
        (jsonDecode(page.restored.single) as Map).cast<String, dynamic>(),
      );
      expect(restored.classesKeptOn('2026-10-06'), hasLength(1));
    });
  });
}
