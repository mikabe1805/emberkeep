// The class-day board: on a day with classes the Quests tab opens on the
// room with today's classes on one glass card, and "I was there" plays the
// class celebration through the engine's own keepClass.
//
// Clocks are frozen at INSTANTS (New York wall times converted from UTC), so
// these hold on a host in any zone: Codemagic's Mac is not on New York time.
// No test reads a wall time after 8 PM New York, where a UTC host's local
// date would already be the next day.
import 'dart:convert';
import 'dart:math' as math;

import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/class_day/class_kept_celebration.dart';
import 'package:emberkeep/widgets/levelup_overlay.dart';
import 'package:emberkeep/widgets/stat_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/rutgers_fall_2026_ics_fixture.dart';

/// A New York wall time in October 2026 (EDT, UTC-4) as an instant.
DateTime _ny(int day, int hour, int minute, [int second = 0]) =>
    DateTime.utc(2026, 10, day, hour + 4, minute, second).toLocal();

final AcademicSchedule _fall2026 = AcademicScheduleIcsImporter.parse(
  rutgersFall2026IcsFixture(),
).applyTo(AcademicSchedule.empty(), updatedAt: DateTime.utc(2026, 8, 27));

ClassDay _lookup(DateTime now, {CivilDate? day}) =>
    projectClassDay(_fall2026, now, day: day);

/// Keeps classes of the class day at [at] through the engine (as the board
/// does). [only] picks by course code. Leaves the clock at [at].
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

class _NoLuck implements math.Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.999;
  @override
  int nextInt(int max) => 0;
}

class _Board {
  _Board(this.state, this.quests);
  final GameState state;
  final List<Quest> quests;
  final restored = <String>[];
  int persisted = 0;
  int addClassesTaps = 0;

  /// What the shell would hand the page next: a focus request (a Goals
  /// hand-off, or the dock's plain clear-focus bump) and whether the Quests
  /// tab is the one on screen (the shell's TickerMode).
  final props = ValueNotifier(const _Props());
}

class _Props {
  const _Props({
    this.focusRequestId = 0,
    this.focusQuestTitle,
    this.tabShown = true,
  });

  final int focusRequestId;
  final String? focusQuestTitle;
  final bool tabShown;
}

/// Keeps [count] earlier classes of [code] on the save (as weeks of the term
/// would have), so the next keep of that course is the count after it.
GameState _withCourseCount(GameState state, String code, int count) {
  final json = jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>;
  json['keptClassCounts'] = {code: count};
  return GameState.fromJson(json)
    ..soundEnabled = false
    ..reduceMotion = state.reduceMotion;
}

Future<_Board> _mount(
  WidgetTester tester, {
  required DateTime at,
  GameState? state,
  bool reduceMotion = false,
  double textScale = 1,
  bool timetable = true,
  bool offerAddClasses = false,
  bool tabShown = true,
  bool secondQuest = false,
}) async {
  tester.view.devicePixelRatio = 1;
  await tester.binding.setSurfaceSize(const Size(393, 852));
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.binding.setSurfaceSize(null);
  });
  Clock.freeze(at);
  final s = (state ?? _mika())
    ..reduceMotion = reduceMotion
    ..lastActiveDay ??= Days.key(at);
  final quests = [
    Quest(
      title: 'Read ten pages',
      stat: Stat.intl,
      difficulty: 4,
      schedule: QuestSchedule.daily,
    ),
    if (secondQuest)
      Quest(
        title: 'Walk to campus',
        stat: Stat.vit,
        difficulty: 2,
        schedule: QuestSchedule.daily,
      ),
  ];
  final board = _Board(s, quests)..props.value = _Props(tabShown: tabShown);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(393, 852),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: ValueListenableBuilder<_Props>(
            valueListenable: board.props,
            builder: (context, props, _) => TickerMode(
              enabled: props.tabShown,
              child: QuestsPage(
                state: s,
                quests: quests,
                onRefresh: () => 0,
                onPersist: () => board.persisted++,
                onAdd: (_) => true,
                onRemove: (_) {},
                onSnapshot: () => jsonEncode(s.toJson()),
                onRestore: board.restored.add,
                classDays: timetable ? _lookup : null,
                onAddClasses: offerAddClasses
                    ? () => board.addClassesTaps++
                    : null,
                focusRequestId: props.focusRequestId,
                focusQuestTitle: props.focusQuestTitle,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  return board;
}

final _room = find.byKey(const Key('class-day-room'));
final _there = find.byKey(const Key('class-there-button'));
final _celebration = find.byType(ClassKeptCelebration);
final _headline = find.byKey(const Key('class-celebration-headline'));

String _closing(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const Key('class-celebration-closing')))
    .data!;

String _textOf(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

Future<void> _tapThere(WidgetTester tester) async {
  await tester.tap(_there);
  await tester.pump();
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

/// Taps the celebration away (the day and week tiers wait for this).
Future<void> _dismiss(WidgetTester tester) async {
  await tester.tapAt(const Offset(196, 300));
  await tester.pump();
  await _pumpFor(tester, const Duration(milliseconds: 600));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    // No luck in any reward: a Quest completion never rolls a crit or a loot
    // drop whose overlay would cover the board on one run and not the next.
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

  group('the room owns a class day', () {
    testWidgets('Tuesday 11:52: one owner, one luminous control', (
      tester,
    ) async {
      await _mount(tester, at: _ny(6, 11, 52));
      expect(_room, findsOneWidget);
      expect(find.text('MARK COMPLETE'), findsNothing);
      expect(find.text('TUESDAY · 2 CLASSES'), findsOneWidget);
      expect(find.text('Computer Architecture'), findsOneWidget);
      expect(find.text('HLL 114 · ended 11:40'), findsOneWidget);
      expect(find.text('I WAS THERE'), findsOneWidget);
      expect(find.text('Discrete Structures II'), findsOneWidget);
      expect(find.text('2:00 PM · PHY 001'), findsOneWidget);
      // The HUD keeps the life RPG: level, XP and the six stats.
      expect(find.byKey(const Key('class-day-hud')), findsOneWidget);
      expect(find.text('LV'), findsOneWidget);
      expect(find.text('TUE · OCT 6'), findsOneWidget);
      for (final stat in Stat.values) {
        expect(find.byKey(Key('class-day-stat-${stat.name}')), findsOneWidget);
      }
      // Today's three is one line with BOARD.
      expect(find.byKey(const Key('class-day-todays-three')), findsOneWidget);
      expect(find.byKey(const Key('class-day-toggle-board')), findsOneWidget);
      // Nothing is counted against him and nothing reads as N of M.
      expect(find.textContaining(' OF '), findsNothing);
      expect(find.textContaining('ATTENDED'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a countdown only inside the last 15 minutes', (tester) async {
      final state = _mika();
      _keepAt(state, _ny(6, 11, 53), only: {'14:332:331'});
      await _mount(tester, at: _ny(6, 13, 30), state: state);
      expect(find.textContaining('STARTS IN'), findsNothing);
      expect(find.text('2:00 PM · PHY 001'), findsOneWidget);
      expect(_there, findsNothing, reason: 'nothing to mark before it starts');

      Clock.freeze(_ny(6, 13, 48));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('STARTS IN 12 MIN'), findsOneWidget);
      expect(_there, findsNothing);
      // What was kept, beside the day's name: never beside its total.
      expect(find.text('TUESDAY'), findsOneWidget);
      expect(find.text('1 ATTENDED'), findsOneWidget);
      expect(find.textContaining('CLASSES'), findsNothing);
    });

    testWidgets("in session: I'M HERE, and the press keeps it", (tester) async {
      final board = await _mount(tester, at: _ny(6, 10, 50));
      expect(find.text("I'M HERE"), findsOneWidget);
      expect(find.text('HLL 114 · until 11:40'), findsOneWidget);
      await _tapThere(tester);
      expect(board.state.classesKeptOn('2026-10-06'), hasLength(1));
      await _pumpFor(tester, const Duration(milliseconds: 900));
      expect(find.text("YOU'RE HERE."), findsOneWidget);
    });

    testWidgets('the next class boundary re-reads the card by itself', (
      tester,
    ) async {
      await _mount(tester, at: _ny(6, 11, 39, 59));
      expect(find.text("I'M HERE"), findsOneWidget);
      Clock.freeze(_ny(6, 11, 40, 2));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('I WAS THERE'), findsOneWidget);
      expect(find.text("I'M HERE"), findsNothing);
    });

    testWidgets('a day without classes keeps the board', (tester) async {
      // Saturday Oct 10: a timetable, no classes.
      await _mount(tester, at: _ny(10, 11, 0));
      expect(_room, findsNothing);
      expect(find.text('MARK COMPLETE'), findsOneWidget);
      expect(find.byKey(const Key('add-classes-row')), findsNothing);
    });
  });

  group('marking and the celebration', () {
    testWidgets('I WAS THERE keeps the class through the engine and plays '
        'YOU WERE THERE., back on its own at about 2.4 s', (tester) async {
      final board = await _mount(tester, at: _ny(6, 11, 52));
      final s = board.state;
      await _tapThere(tester);
      // On contact the class is kept: XP, MIND, never a Quest completion.
      expect(s.xp, 284 + 25);
      expect(s.stats[Stat.intl], 3);
      expect(s.totalCompletions, 0);
      expect(s.history, isEmpty);
      expect(s.classesKeptOn('2026-10-06'), hasLength(1));
      expect(board.persisted, greaterThan(0));
      // The card's own ring closes under the press, held in place.
      expect(find.text('I WAS THERE'), findsOneWidget);
      expect(find.text('1 ATTENDED'), findsOneWidget);
      // No total beside the kept count (it would read as 1 of 2).
      expect(find.text('TUESDAY'), findsOneWidget);
      expect(find.textContaining('2 CLASSES'), findsNothing);

      await _pumpFor(tester, const Duration(milliseconds: 1600));
      expect(_celebration, findsOneWidget);
      expect(find.text('YOU WERE THERE.'), findsOneWidget);
      expect(_textOf(tester, const Key('class-celebration-numeral')), '1');
      expect(find.text('YOUR FIRST LECTURE'), findsOneWidget);
      expect(
        find.text('Computer Architecture & Assembly Language'),
        findsOneWidget,
      );
      expect(find.text('10:20 TO 11:40 · HLL 114'), findsOneWidget);
      expect(_textOf(tester, const Key('class-celebration-xp')), '+25 XP');
      expect(
        find.byKey(const Key('class-celebration-stat-intl')),
        findsOneWidget,
      );
      expect(
        _closing(tester),
        'First one down.\nDiscrete Structures II is at 2:00\u00A0PM.',
      );
      // No streak line while ClassDayRules keeps it off.
      expect(find.textContaining('DAYS RUNNING'), findsNothing);
      expect(find.textContaining('Marked by mistake'), findsNothing);

      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(_celebration, findsOneWidget, reason: 'still up at 2.2 s');
      await _pumpFor(tester, const Duration(milliseconds: 400));
      expect(_celebration, findsNothing, reason: 'back on its own');
      // Back in the room: Discrete leads, Computer Architecture is kept.
      expect(find.text('+25 XP'), findsOneWidget);
      expect(find.text('I WAS THERE'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a finger on the glass holds the class tier', (tester) async {
      await _mount(tester, at: _ny(6, 11, 52));
      await _tapThere(tester);
      await _pumpFor(tester, const Duration(milliseconds: 500));
      final finger = await tester.startGesture(const Offset(196, 300));
      await _pumpFor(tester, const Duration(seconds: 3));
      expect(_celebration, findsOneWidget);
      await finger.up();
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 500));
      expect(_celebration, findsNothing, reason: 'the fade back, then gone');
    });

    testWidgets('the last class: TUESDAY, DONE., two for two, +10, held', (
      tester,
    ) async {
      final state = _mika();
      _keepAt(state, _ny(6, 11, 53), only: {'14:332:331'});
      final board = await _mount(tester, at: _ny(6, 15, 35), state: state);
      expect(find.text('Discrete Structures II'), findsOneWidget);
      expect(find.text('PHY 001 · ended 3:20'), findsOneWidget);
      await _tapThere(tester);
      expect(board.state.xp, 284 + 25 + 25 + 10);
      await _pumpFor(tester, const Duration(milliseconds: 2600));
      expect(find.text('TUESDAY, DONE.'), findsOneWidget);
      expect(find.byKey(const Key('class-celebration-bonus')), findsOneWidget);
      expect(find.text("All of Tuesday's classes"), findsOneWidget);
      expect(_textOf(tester, const Key('class-celebration-xp')), '+60 XP');
      expect(
        _closing(tester),
        "Two for two.\nNothing else until Wednesday's 8:30 lab.",
      );
      await _pumpFor(tester, const Duration(seconds: 6));
      expect(_celebration, findsOneWidget, reason: 'the day waits for a tap');
      await _dismiss(tester);
      expect(_celebration, findsNothing);
      // Every class kept and the last one over: the evening. The day folds
      // to one line with its XP (the +10 included).
      await _pumpFor(tester, const Duration(milliseconds: 2600));
      expect(find.byKey(const Key('class-evening')), findsOneWidget);
      expect(find.text('Tuesday’s classes, both attended'), findsOneWidget);
      expect(find.text('+60 XP'), findsOneWidget);
      expect(find.text('Write a line'), findsOneWidget);
      // 3:35 PM is not the wind-down yet: nothing asks to close the day.
      expect(find.byKey(const Key('class-evening-close-day')), findsNothing);
    });

    testWidgets('the first mark after the last class ended is the day tier '
        'without two for two or the +10', (tester) async {
      await _mount(tester, at: _ny(6, 15, 35));
      await _tapThere(tester);
      await _pumpFor(tester, const Duration(milliseconds: 2600));
      expect(find.text('TUESDAY, DONE.'), findsOneWidget);
      expect(find.byKey(const Key('class-celebration-bonus')), findsNothing);
      expect(find.textContaining('for two'), findsNothing);
      expect(_closing(tester), "Nothing else until Wednesday's 8:30 lab.");
    });

    testWidgets('Monday 19:15: one shortcut marks all three, one celebration', (
      tester,
    ) async {
      final board = await _mount(tester, at: _ny(5, 19, 15));
      // The 5:40 lecture leads; the two earlier ones are quiet dots.
      expect(find.text('SEC 204 · ended 7:00'), findsOneWidget);
      expect(find.byKey(const Key('class-quiet-dot')), findsNWidgets(2));
      final shortcut = find.byKey(const Key('class-all-of-today'));
      expect(shortcut, findsOneWidget);
      expect(find.text('I went to all of today’s classes'), findsOneWidget);
      await tester.tap(shortcut);
      await tester.pump();
      expect(board.state.classesKeptOn('2026-10-05'), hasLength(3));
      expect(board.state.xp, 284 + 25 * 3 + 10);
      await _pumpFor(tester, const Duration(milliseconds: 2600));
      expect(_celebration, findsOneWidget);
      expect(find.text('MONDAY, DONE.'), findsOneWidget);
      expect(_textOf(tester, const Key('class-celebration-numeral')), '3');
      expect(find.text('CLASSES TODAY'), findsOneWidget);
      expect(_textOf(tester, const Key('class-celebration-xp')), '+85 XP');
      expect(
        _closing(tester),
        'Three for three.\nTomorrow starts late: Computer Architecture at '
        '10:20.',
      );
      await _dismiss(tester);
      expect(find.text('Monday’s classes, all three attended'), findsOneWidget);
      expect(find.byKey(const Key('class-all-of-today')), findsNothing);
    });

    testWidgets('Thursday: a second mark within 15 s is THAT ONE TOO. and '
        'back in about 1.4 s', (tester) async {
      await _mount(tester, at: _ny(8, 15, 22));
      expect(find.text('Discrete Structures II'), findsOneWidget);
      expect(find.text('I went to both'), findsOneWidget);
      await _tapThere(tester);
      await _pumpFor(tester, const Duration(milliseconds: 1400));
      expect(find.text('YOU WERE THERE.'), findsOneWidget);
      expect(
        _closing(tester),
        'First one down.\nElectron Devices Lab is at 3:50\u00A0PM.',
      );
      await _dismiss(tester);

      Clock.freeze(_ny(8, 15, 22, 9));
      await tester.tap(find.text('Electronics Devices'));
      await tester.pump();
      expect(find.text('SEC 111 · ended 9:50'), findsOneWidget);
      await _tapThere(tester);
      await _pumpFor(tester, const Duration(milliseconds: 900));
      expect(find.text('THAT ONE TOO.'), findsOneWidget);
      expect(_closing(tester), 'The lab is at 3:50, in EE 209.');
      await _pumpFor(tester, const Duration(milliseconds: 700));
      expect(_celebration, findsNothing, reason: 'back at about 1.4 s');
    });

    testWidgets("Friday: the week's last class is THAT'S THE WEEK., twelve "
        'for twelve', (tester) async {
      final state = _mika();
      for (final day in [5, 6, 7, 8]) {
        _keepAt(state, _ny(day, 19, 45));
      }
      _keepAt(state, _ny(9, 11, 45), only: {'14:332:331'});
      await _mount(tester, at: _ny(9, 18, 56), state: state);
      await _tapThere(tester);
      await _pumpFor(tester, const Duration(milliseconds: 2600));
      expect(find.text("THAT'S THE WEEK."), findsOneWidget);
      expect(
        _closing(tester),
        'Twelve for twelve.\nFree until Monday at 8:30.',
      );
      expect(_celebration, findsOneWidget);
      await _pumpFor(tester, const Duration(seconds: 4));
      expect(_celebration, findsOneWidget, reason: 'the week waits for a tap');
    });

    testWidgets('a week with a class left unmarked never shows a denominator', (
      tester,
    ) async {
      final state = _mika();
      _keepAt(state, _ny(5, 19, 45));
      _keepAt(state, _ny(6, 19, 45), only: {'14:332:331'});
      _keepAt(state, _ny(7, 19, 45));
      _keepAt(state, _ny(8, 19, 45));
      _keepAt(state, _ny(9, 11, 45), only: {'14:332:331'});
      await _mount(tester, at: _ny(9, 18, 56), state: state);
      await _tapThere(tester);
      await _pumpFor(tester, const Duration(milliseconds: 2600));
      expect(find.text("THAT'S THE WEEK."), findsOneWidget);
      expect(
        _closing(tester),
        'Eleven classes this week.\nFree until Monday at 8:30.',
      );
      expect(find.textContaining('for twelve'), findsNothing);
      expect(find.textContaining(' OF '), findsNothing);
    });

    testWidgets('a level crossed by a mark chains into the real level-up with '
        'the classes since the last level', (tester) async {
      final state = _mika()
        ..xp = 850
        ..totalCompletions = 30
        ..completionsAtLastLevel = 19;
      await _mount(tester, at: _ny(6, 11, 52), state: state);
      await _tapThere(tester);
      await _pumpFor(tester, const Duration(milliseconds: 1600));
      expect(
        _textOf(tester, const Key('class-celebration-rail')),
        'LEVEL 19 READY',
      );
      expect(find.byType(LevelUpOverlay), findsNothing);
      await _pumpFor(tester, const Duration(milliseconds: 1000));
      expect(_celebration, findsNothing);
      expect(find.byType(LevelUpOverlay), findsOneWidget);
      expect(state.level, 19);
      expect(find.text('YOU DID IT.'), findsOneWidget);
      expect(
        find.text('11 quests and one class since level 18'),
        findsOneWidget,
      );
    });

    testWidgets('undo: the kept row past 42% restores the whole save through '
        'the reward slot', (tester) async {
      final board = await _mount(tester, at: _ny(6, 11, 52));
      final before = jsonEncode(board.state.toJson());
      await _tapThere(tester);
      await _pumpFor(tester, const Duration(milliseconds: 2600));
      expect(_celebration, findsNothing);
      final identity = _lookup(_ny(6, 11, 52)).classes.first.facts.identity;
      final row = find.byKey(ValueKey('class-undo-$identity'));
      expect(row, findsOneWidget);
      await tester.drag(row, const Offset(-260, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(board.restored, [before]);
      final restored = GameState.fromJson(
        (jsonDecode(board.restored.single) as Map).cast<String, dynamic>(),
      );
      expect(restored.xp, 284);
      expect(restored.classesKeptOn('2026-10-06'), isEmpty);
    });

    testWidgets('a short swipe keeps the class', (tester) async {
      final board = await _mount(tester, at: _ny(6, 11, 52));
      await _tapThere(tester);
      await _pumpFor(tester, const Duration(milliseconds: 2600));
      final identity = _lookup(_ny(6, 11, 52)).classes.first.facts.identity;
      await tester.drag(
        find.byKey(ValueKey('class-undo-$identity')),
        const Offset(-80, 0),
      );
      await tester.pumpAndSettle();
      expect(board.restored, isEmpty);
    });

    testWidgets('a staged Quest reward lands before a class write, and the '
        'Quest undo is settled', (tester) async {
      final board = await _mount(tester, at: _ny(6, 11, 52));
      final s = board.state;
      await tester.tap(find.byKey(const Key('class-day-toggle-board')));
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text('MARK COMPLETE'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(s.totalCompletions, 0, reason: 'the reward is still staged');
      await tester.tap(find.byKey(const Key('class-day-toggle-room')));
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 300));
      expect(_there, findsOneWidget);
      await _tapThere(tester);
      expect(s.totalCompletions, 1, reason: 'flushed before the class write');
      expect(s.classesKeptOn('2026-10-06'), hasLength(1));
      await _pumpFor(tester, const Duration(seconds: 4));
      // The Quest card on the board no longer offers its undo.
      await tester.tap(find.byKey(const Key('class-day-toggle-board')));
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('undo-Read ten pages')), findsNothing);
    });

    testWidgets('Reduce Motion: the celebration lands at once', (tester) async {
      await _mount(tester, at: _ny(6, 11, 52), reduceMotion: true);
      await _tapThere(tester);
      await tester.pump(const Duration(milliseconds: 50));
      // Everything has landed; only one short fade brings it in.
      expect(_textOf(tester, const Key('class-celebration-xp')), '+25 XP');
      await tester.pump(const Duration(milliseconds: 250));
      final opacity = tester
          .widgetList<Opacity>(
            find.ancestor(of: _headline, matching: find.byType(Opacity)),
          )
          .map((o) => o.opacity);
      expect(opacity.every((o) => o == 1), isTrue);
      await _pumpFor(tester, const Duration(milliseconds: 2600));
      expect(_celebration, findsNothing);
    });

    testWidgets('text at 130% lays out the room and the celebration', (
      tester,
    ) async {
      await _mount(tester, at: _ny(6, 11, 52), textScale: 1.3);
      expect(tester.takeException(), isNull);
      expect(_there.hitTestable(), findsOneWidget);
      await _tapThere(tester);
      await _pumpFor(tester, const Duration(milliseconds: 1800));
      expect(find.text('YOU WERE THERE.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the board', () {
    testWidgets('BOARD brings back the full board and ROOM returns', (
      tester,
    ) async {
      await _mount(tester, at: _ny(6, 11, 52));
      await tester.tap(find.byKey(const Key('class-day-toggle-board')));
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(_room, findsNothing);
      expect(find.text('MARK COMPLETE'), findsOneWidget);
      expect(
        find.byKey(const Key('class-day-board-room-line')),
        findsOneWidget,
      );
      expect(find.text('Tuesday’s classes'), findsOneWidget);
      await tester.tap(find.byKey(const Key('class-day-toggle-room')));
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(_room, findsOneWidget);
      expect(find.text('MARK COMPLETE'), findsNothing);
    });

    testWidgets('reopening after a class boundary brings the room back', (
      tester,
    ) async {
      await _mount(tester, at: _ny(6, 11, 52));
      await tester.tap(find.byKey(const Key('class-day-toggle-board')));
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 600));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(_room, findsNothing, reason: 'no class started or ended');
      Clock.freeze(_ny(6, 14, 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(_room, findsOneWidget);
      expect(find.text("I'M HERE"), findsOneWidget);
    });

    testWidgets('no timetable: the board is unchanged', (tester) async {
      await _mount(tester, at: _ny(6, 11, 52), timetable: false);
      expect(_room, findsNothing);
      expect(find.text('MARK COMPLETE'), findsOneWidget);
      expect(find.byKey(const Key('add-classes-row')), findsNothing);
      expect(find.text('I WAS THERE'), findsNothing);
    });

    testWidgets('Add your classes on a weekday, gone for good with Not in '
        'school', (tester) async {
      final board = await _mount(
        tester,
        at: _ny(6, 11, 52),
        timetable: false,
        offerAddClasses: true,
      );
      expect(find.text('MARK COMPLETE'), findsOneWidget);
      expect(find.byKey(const Key('add-classes-row')), findsOneWidget);
      expect(find.text('Add your classes'), findsOneWidget);
      expect(find.text('Each class you go to earns XP.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('add-classes')));
      await tester.pump();
      expect(board.addClassesTaps, 1);
      await tester.tap(find.byKey(const Key('not-in-school')));
      await tester.pump();
      expect(board.state.addClassesHidden, isTrue);
      expect(find.byKey(const Key('add-classes-row')), findsNothing);
      final restored = GameState.fromJson(
        (jsonDecode(jsonEncode(board.state.toJson())) as Map)
            .cast<String, dynamic>(),
      );
      expect(restored.addClassesHidden, isTrue);
    });

    testWidgets('Add your classes stays off the weekend', (tester) async {
      await _mount(
        tester,
        at: _ny(10, 11, 0),
        timetable: false,
        offerAddClasses: true,
      );
      expect(find.text('MARK COMPLETE'), findsOneWidget);
      expect(find.byKey(const Key('add-classes-row')), findsNothing);
    });
  });

  group('undo, hand-offs and later edits', () {
    testWidgets("the shortcut's three marks undo together from the newest "
        'kept row', (tester) async {
      final board = await _mount(tester, at: _ny(5, 19, 15));
      final before = jsonEncode(board.state.toJson());
      await tester.tap(find.byKey(const Key('class-all-of-today')));
      await tester.pump();
      expect(board.state.classesKeptOn('2026-10-05'), hasLength(3));
      await _pumpFor(tester, const Duration(milliseconds: 2600));
      await _dismiss(tester);
      // The newest kept row (the 5:40 lecture) carries the gesture's undo.
      final last = _lookup(_ny(5, 19, 15)).classes.last.facts.identity;
      final row = find.byKey(ValueKey('class-undo-$last'));
      expect(row, findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Dismissible && '${w.key}'.contains('class-undo-'),
        ),
        findsOneWidget,
        reason: 'one undo for one gesture',
      );
      await tester.drag(row, const Offset(-260, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(board.restored, [before]);
      final restored = GameState.fromJson(
        (jsonDecode(board.restored.single) as Map).cast<String, dynamic>(),
      );
      expect(restored.classesKeptOn('2026-10-05'), isEmpty);
      expect(restored.xp, 284);
    });

    testWidgets('a Goals hand-off on a class day opens the board', (
      tester,
    ) async {
      final board = await _mount(tester, at: _ny(6, 11, 52));
      expect(_room, findsOneWidget);
      board.props.value = const _Props(
        focusRequestId: 1,
        focusQuestTitle: 'Read ten pages',
      );
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(_room, findsNothing);
      expect(find.text('MARK COMPLETE'), findsOneWidget);
    });

    testWidgets("the dock's clear-focus bump leaves the room where it is", (
      tester,
    ) async {
      final board = await _mount(tester, at: _ny(6, 11, 52));
      board.props.value = const _Props(focusRequestId: 1);
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(_room, findsOneWidget, reason: 'no Quest was named');
      // After a real hand-off and ROOM, the plain bump keeps the room.
      board.props.value = const _Props(
        focusRequestId: 2,
        focusQuestTitle: 'Read ten pages',
      );
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(_room, findsNothing);
      await tester.tap(find.byKey(const Key('class-day-toggle-room')));
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(_room, findsOneWidget);
      board.props.value = const _Props(focusRequestId: 3);
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(_room, findsOneWidget);
    });

    testWidgets('a hand-off on a day without classes never carries over to '
        "Monday's room", (tester) async {
      final board = await _mount(tester, at: _ny(10, 11, 0));
      board.props.value = const _Props(
        focusRequestId: 1,
        focusQuestTitle: 'Read ten pages',
      );
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 300));
      expect(_room, findsNothing, reason: 'Saturday is the board');
      Clock.freeze(_ny(12, 8, 0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(_room, findsOneWidget);
    });

    testWidgets('Not in school settles an armed Quest undo', (tester) async {
      final board = await _mount(
        tester,
        at: _ny(6, 11, 52),
        timetable: false,
        offerAddClasses: true,
        secondQuest: true,
      );
      await tester.tap(find.text('MARK COMPLETE').first);
      await tester.pump();
      await _pumpFor(tester, const Duration(seconds: 3));
      expect(board.state.totalCompletions, 1);
      expect(find.byKey(const ValueKey('undo-Read ten pages')), findsOneWidget);
      await tester.tap(find.byKey(const Key('not-in-school')));
      await tester.pump();
      expect(board.state.addClassesHidden, isTrue);
      expect(
        find.byKey(const ValueKey('undo-Read ten pages')),
        findsNothing,
        reason: 'a restore would bring the row back',
      );
    });

    testWidgets("choosing today's three under a kept class settles its undo", (
      tester,
    ) async {
      await _mount(tester, at: _ny(6, 11, 52));
      await _tapThere(tester);
      await _pumpFor(tester, const Duration(milliseconds: 2600));
      final identity = _lookup(_ny(6, 11, 52)).classes.first.facts.identity;
      expect(find.byKey(ValueKey('class-undo-$identity')), findsOneWidget);
      await tester.tap(find.byKey(const Key('class-day-todays-three')));
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 800));
      await tester.tap(find.byKey(const ValueKey('top-three-Read ten pages')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('top-three-save')));
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 800));
      expect(
        find.byKey(ValueKey('class-undo-$identity')),
        findsNothing,
        reason: 'a restore would quietly drop the choice',
      );
    });
  });

  group('the board on a day without classes', () {
    testWidgets('a Quest level-up keeps the header behind the takeover until '
        'it is dismissed', (tester) async {
      final state = _mika()..xp = 869;
      await _mount(tester, at: _ny(10, 11, 0), state: state);
      await tester.tap(find.text('MARK COMPLETE'));
      await tester.pump();
      for (var i = 0; i < 80; i++) {
        if (find.byType(LevelUpOverlay).evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(LevelUpOverlay), findsOneWidget);
      expect(state.level, 19);
      expect(
        find.text('LEVEL 18', findRichText: true),
        findsOneWidget,
        reason:
            'the full bar stays behind the dim; the pour plays on dismissal',
      );
      await _pumpFor(tester, const Duration(seconds: 1));
    });
  });

  group('the board out of view', () {
    testWidgets("BOARD after a mark shows the board's numbers already landed", (
      tester,
    ) async {
      final state = _mika()..stats[Stat.intl] = 25;
      await _mount(tester, at: _ny(6, 11, 52), state: state);
      await _tapThere(tester);
      await _pumpFor(tester, const Duration(milliseconds: 2600));
      await tester.tap(find.byKey(const Key('class-day-toggle-board')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final chips = find.byType(StatChips);
      expect(
        find.descendant(of: chips, matching: find.text('28')),
        findsOneWidget,
        reason: 'MIND landed offstage, never rolling from 25 in view',
      );
      expect(find.textContaining('284 / 870'), findsNothing);
      expect(find.textContaining('309'), findsWidgets);
    });

    testWidgets('mounted while the Quests tab is hidden, the board still '
        'shows its real numbers on the first BOARD', (tester) async {
      final state = _mika()
        ..stats[Stat.intl] = 25
        ..stats[Stat.str] = 88;
      // The shell's TickerMode is off while another tab is on screen (the
      // timetable arriving from Plans mounts the class day there).
      final board = await _mount(
        tester,
        at: _ny(6, 11, 52),
        state: state,
        tabShown: false,
      );
      await _pumpFor(tester, const Duration(seconds: 3));
      board.props.value = const _Props();
      await tester.pump();
      await tester.tap(find.byKey(const Key('class-day-toggle-board')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final chips = find.byType(StatChips);
      expect(
        find.descendant(of: chips, matching: find.text('25')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: chips, matching: find.text('88')),
        findsOneWidget,
      );
    });
  });

  group('sound and touch', () {
    testWidgets('I WAS THERE: one completion composite and a light tap; the '
        'stat note in the celebration; boing on undo; no levelup', (
      tester,
    ) async {
      final played = <String>[];
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add('${call.arguments}');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _mount(tester, at: _ny(6, 11, 52));
      Sfx.instance
        ..soundEnabled = true
        ..debugBypassPlayback = true
        ..debugOnPlay = played.add;
      addTearDown(Sfx.instance.debugResetForTesting);
      await _tapThere(tester);
      expect(played.where((e) => e == 'complete'), hasLength(1));
      expect(haptics, contains('HapticFeedbackType.lightImpact'));
      await _pumpFor(tester, const Duration(milliseconds: 900));
      expect(played, contains('stat_${Stat.intl.index}'));
      await _pumpFor(tester, const Duration(milliseconds: 1700));
      expect(_celebration, findsNothing);
      final identity = _lookup(_ny(6, 11, 52)).classes.first.facts.identity;
      await tester.drag(
        find.byKey(ValueKey('class-undo-$identity')),
        const Offset(-260, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(played, contains('boing'));
      expect(played, isNot(contains('levelup')));
      expect(played.where((e) => e == 'complete'), hasLength(1));
    });

    testWidgets('a level crossed by a mark plays levelup once, after the '
        'celebration', (tester) async {
      final played = <String>[];
      final state = _mika()..xp = 850;
      await _mount(tester, at: _ny(6, 11, 52), state: state);
      Sfx.instance
        ..soundEnabled = true
        ..debugBypassPlayback = true
        ..debugOnPlay = played.add;
      addTearDown(Sfx.instance.debugResetForTesting);
      await _tapThere(tester);
      await _pumpFor(tester, const Duration(milliseconds: 2000));
      expect(played, isNot(contains('levelup')));
      await _pumpFor(tester, const Duration(milliseconds: 1600));
      expect(find.byType(LevelUpOverlay), findsOneWidget);
      expect(played.where((e) => e == 'levelup'), hasLength(1));
    });
  });

  group('after midnight, until the night ends', () {
    testWidgets("01:30 Wednesday still marks Tuesday's classes; after 04:00 "
        'the card is Wednesday', (tester) async {
      final board = await _mount(tester, at: _ny(7, 1, 30));
      expect(find.text('TUESDAY · 2 CLASSES'), findsOneWidget);
      expect(find.text('Discrete Structures II'), findsOneWidget);
      expect(find.text('PHY 001 · ended 3:20'), findsOneWidget);
      expect(find.text('I WAS THERE'), findsOneWidget);
      await _tapThere(tester);
      expect(board.state.classesKeptOn('2026-10-06'), hasLength(1));
      await _pumpFor(tester, const Duration(milliseconds: 3000));
      await _dismiss(tester);

      Clock.freeze(_ny(7, 4, 0, 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.textContaining('WEDNESDAY'), findsOneWidget);
      expect(find.text('I WAS THERE'), findsNothing);
      expect(find.text('Computer Architecture Lab'), findsOneWidget);
    });

    testWidgets('the night-end timer turns the card over by itself', (
      tester,
    ) async {
      await _mount(tester, at: _ny(7, 3, 59, 50));
      expect(find.text('TUESDAY · 2 CLASSES'), findsOneWidget);
      Clock.freeze(_ny(7, 4, 0, 1));
      await tester.pump(const Duration(seconds: 11));
      expect(find.textContaining('WEDNESDAY'), findsOneWidget);
    });
  });

  group('the celebration, refined', () {
    testWidgets('going back on its own fades out, and the room is home at '
        '2.4 s', (tester) async {
      await _mount(tester, at: _ny(6, 11, 52));
      await _tapThere(tester);
      await _pumpFor(tester, const Duration(milliseconds: 2000));
      double headlineOpacity() => tester
          .widgetList<Opacity>(
            find.ancestor(of: _headline, matching: find.byType(Opacity)),
          )
          .map((o) => o.opacity)
          .reduce((a, b) => a * b);
      expect(headlineOpacity(), 1);
      await _pumpFor(tester, const Duration(milliseconds: 300));
      expect(_celebration, findsOneWidget);
      expect(headlineOpacity(), lessThan(1), reason: 'the words leave first');
      await _pumpFor(tester, const Duration(milliseconds: 200));
      expect(_celebration, findsNothing);
    });

    testWidgets('the quick tier holds still: its count has landed by about '
        '500 ms and there is no time and room line', (tester) async {
      await _mount(tester, at: _ny(8, 15, 22));
      await _tapThere(tester);
      await _pumpFor(tester, const Duration(milliseconds: 1400));
      await _dismiss(tester);
      Clock.freeze(_ny(8, 15, 22, 9));
      await tester.tap(find.text('Electronics Devices'));
      await tester.pump();
      await _tapThere(tester);
      await _pumpFor(tester, const Duration(milliseconds: 500));
      expect(find.text('THAT ONE TOO.'), findsOneWidget);
      expect(_textOf(tester, const Key('class-celebration-xp')), '+25 XP');
      expect(find.text('8:30 TO 9:50 · SEC 111'), findsNothing);
      final closing = find.byKey(const Key('class-celebration-closing'));
      final opacity = tester
          .widgetList<Opacity>(
            find.ancestor(of: closing, matching: find.byType(Opacity)),
          )
          .map((o) => o.opacity)
          .reduce((a, b) => a * b);
      expect(opacity, 1, reason: 'the closing line came in with the headline');
    });

    for (final (label, at, side) in [
      ('YOU WERE THERE.', _ny(6, 11, 52), 100.0),
      ('TUESDAY, DONE.', _ny(6, 15, 35), 84.0),
    ]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('a two-digit count sits inside the diamond: $label at '
            '${(scale * 100).round()}%', (tester) async {
          final course = label == 'YOU WERE THERE.'
              ? '14:332:331'
              : '01:198:206';
          final state = _withCourseCount(_mika(), course, 23);
          await _mount(tester, at: at, state: state, textScale: scale);
          await _tapThere(tester);
          await _pumpFor(tester, const Duration(milliseconds: 1900));
          expect(find.text(label), findsOneWidget);
          final numeral = find.byKey(const Key('class-celebration-numeral'));
          expect(tester.widget<Text>(numeral).data, '24');
          expect(find.text('YOUR 24TH LECTURE'), findsOneWidget);
          final text = tester.getRect(numeral);
          final centre = text.center;
          final half = side * math.sqrt1_2;
          final style = tester.widget<Text>(numeral).style!;
          // The numeral's box keeps inside the diamond's edges.
          expect(
            text.width / 2 + 0.36 * style.fontSize!,
            lessThanOrEqualTo(half),
          );
          expect(tester.widget<Text>(numeral).textScaler, TextScaler.noScaling);
          // The points never reach the headline or the label.
          final headline = tester.getRect(_headline);
          final under = tester.getRect(
            find.byKey(const Key('class-celebration-numeral-label')),
          );
          expect(headline.bottom, lessThanOrEqualTo(centre.dy - half - 4));
          expect(under.top, greaterThanOrEqualTo(centre.dy + half + 4));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
