// The Doorway's glass card: the class that is ready leads with its one
// control and a quiet "Couldn't make it" under it; the next two classes still
// to come follow as quiet rows; the rest wait behind "N more later today",
// which opens the whole list; a tap on a class still to come shows its own
// quiet word; a class he went to has gone to its hook and folds off the card;
// a class he set aside folds away, with a few seconds of Undo.
//
// Instants only (New York wall times converted from UTC).
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
import 'package:emberkeep/widgets/class_day/class_day_model.dart';
import 'package:emberkeep/widgets/class_day/doorway_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/crowded_friday_schedule.dart';
import 'support/rutgers_fall_2026_ics_fixture.dart';

DateTime _ny(int day, int hour, int minute) =>
    DateTime.utc(2026, 10, day, hour + 4, minute).toLocal();

final AcademicSchedule _fall2026 = AcademicScheduleIcsImporter.parse(
  rutgersFall2026IcsFixture(),
).applyTo(AcademicSchedule.empty(), updatedAt: DateTime.utc(2026, 8, 27));

class _NoLuck implements math.Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.999;
  @override
  int nextInt(int max) => 0;
}

GameState _mika() => GameState(rng: _NoLuck())
  ..onboarded = true
  ..playerName = 'Mika'
  ..level = 18
  ..xp = 284
  ..totalXp = 4280
  ..soundEnabled = false
  ..reduceMotion = true;

Future<GameState> _mount(
  WidgetTester tester, {
  required DateTime at,
  AcademicSchedule? schedule,
  GameState? state,
  bool reduceMotion = true,
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
  final timetable = schedule ?? _fall2026;
  ClassDay lookup(DateTime now, {CivilDate? day}) =>
      projectClassDay(timetable, now, day: day);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: const MediaQueryData(size: Size(393, 852)),
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
            classDays: lookup,
            classTerm: timetable.termFor,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  return s;
}

final _there = find.byKey(const Key('class-there-button'));
final _word = find.text(classSetAsideLabel);
final _more = find.byKey(const Key('class-more-later'));
final _reveals = find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('class-reveal-'),
);
final _rows = find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('class-row-'),
);

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  for (
    var t = Duration.zero;
    t < total;
    t += const Duration(milliseconds: 50)
  ) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    GameState.debugRandomFactory = _NoLuck.new;
    Sfx.instance.soundEnabled = false;
  });
  tearDown(() {
    Clock.reset();
    GameState.debugRandomFactory = null;
    Sfx.instance.debugResetForTesting();
    Sfx.instance.soundEnabled = true;
  });

  testWidgets('the ready class leads: I WAS THERE and a quiet word under it', (
    tester,
  ) async {
    await _mount(tester, at: _ny(6, 12, 51));
    expect(find.byType(DoorwayStage), findsOneWidget);
    expect(find.text('TUESDAY · 2 CLASSES'), findsOneWidget);
    expect(find.text('Computer Architecture'), findsWidgets);
    expect(_there, findsOneWidget);
    expect(find.text('I WAS THERE'), findsOneWidget);
    // The one quiet word, under the lamp and smaller than it.
    expect(_word, findsOneWidget);
    final lamp = tester.getRect(_there);
    final word = tester.getRect(_word);
    expect(word.top, greaterThanOrEqualTo(lamp.bottom - 1));
    expect(word.width, lessThan(lamp.width));
    // The next class is a quiet row (no word until it is tapped).
    expect(_rows, findsOneWidget);
    expect(find.text('Discrete Structures II'), findsOneWidget);
    expect(find.text('2:00 PM · PHY 001'), findsOneWidget);
    expect(_more, findsNothing);
  });

  group('five events', () {
    final schedule = crowdedFridaySchedule(List.filled(5, 'lecture'));
    DateTime fri(int h, int m) => _ny(9, h, m);

    testWidgets('the next two, then "N more later today"', (tester) async {
      await _mount(tester, at: fri(7, 0), schedule: schedule);
      // Nothing is over yet: the first class leads, two rows follow, and the
      // other two are one quiet line.
      expect(find.text('FRIDAY · 5 CLASSES'), findsOneWidget);
      expect(_rows, findsNWidgets(2));
      expect(_more, findsOneWidget);
      expect(find.text('2 more later today'), findsOneWidget);
      expect(find.text('Course E'), findsNothing);
    });

    testWidgets('the line opens the whole list, and closes it again', (
      tester,
    ) async {
      await _mount(tester, at: fri(7, 0), schedule: schedule);
      await tester.ensureVisible(_more);
      await tester.tap(_more);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_rows, findsNWidgets(4));
      expect(find.text('Course E'), findsOneWidget);
      expect(find.text('Show fewer'), findsOneWidget);
      expect(find.textContaining('more later today'), findsNothing);

      await tester.ensureVisible(_more);
      await tester.tap(_more);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_rows, findsNWidgets(2));
      expect(find.text('2 more later today'), findsOneWidget);
    });

    testWidgets('one more is still said as a line', (tester) async {
      await _mount(
        tester,
        at: fri(7, 0),
        schedule: crowdedFridaySchedule(List.filled(4, 'lecture')),
      );
      expect(_rows, findsNWidgets(2));
      expect(find.text('1 more later today'), findsOneWidget);
    });

    testWidgets('a tap on a class still to come shows its own quiet word', (
      tester,
    ) async {
      await _mount(tester, at: fri(7, 0), schedule: schedule);
      // The leading class has its word; the rows keep theirs out of sight.
      expect(_word, findsOneWidget);
      await tester.tap(_reveals.first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_word, findsNWidgets(2));
      // Another row: the first puts its word away, the second shows its own.
      await tester.tap(_reveals.last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_word, findsNWidgets(2));
      await tester.tap(_reveals.last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_word, findsOneWidget);
    });

    testWidgets('the word on a row sets that class aside, not the leader', (
      tester,
    ) async {
      final s = await _mount(tester, at: fri(7, 0), schedule: schedule);
      final day = projectClassDay(schedule, Clock.now());
      await tester.tap(_reveals.first);
      await tester.pump(const Duration(milliseconds: 300));
      // The row's word is the second in the tree (the leader's is first).
      await tester.tap(_word.last);
      await tester.pump(const Duration(milliseconds: 400));
      final aside = s.classesDismissedOn('2026-10-09');
      expect(aside, hasLength(1));
      expect(aside.single.answersTo(day.classes[1].occurrenceKey), isTrue);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  testWidgets('a class he went to has gone to its hook: no row for it', (
    tester,
  ) async {
    final state = _mika();
    Clock.freeze(_ny(6, 12, 40));
    final day = projectClassDay(_fall2026, Clock.now());
    final arch = day.classes.first;
    expect(
      state.keepClass(arch.facts, dayClassKeys: day.dayClassKeys),
      isNotNull,
    );
    await _mount(tester, at: _ny(6, 12, 51), state: state);
    final id = arch.facts.identity;
    expect(find.byKey(ValueKey('class-row-$id')), findsNothing);
    expect(find.byKey(ValueKey('class-foremost-$id')), findsNothing);
    // Today shows what he went to as a count up; the class still to come
    // leads. Nothing counts what is not here.
    expect(find.text('1 ATTENDED'), findsOneWidget);
    expect(find.text('Discrete Structures II'), findsOneWidget);
    expect(find.byType(DoorwayStage), findsOneWidget);
  });

  testWidgets(
    'Couldn’t make it folds the row away, with a few seconds to Undo',
    (tester) async {
      final s = await _mount(tester, at: _ny(6, 12, 51));
      await tester.tap(_word);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(s.classesDismissedOn('2026-10-06'), hasLength(1));
      expect(
        find.text('Computer Architecture is off today’s list.'),
        findsOneWidget,
      );
      expect(find.text('Undo'), findsOneWidget);
      // The other class leads now.
      expect(find.text('TUESDAY · 1 CLASS'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Undo'), findsNothing);
      expect(s.classesDismissedOn('2026-10-06'), hasLength(1));
    },
  );

  testWidgets('with motion on, a row folds over a few frames, not a pop', (
    tester,
  ) async {
    await _mount(tester, at: _ny(6, 12, 51), reduceMotion: false);
    expect(find.text('Discrete Structures II'), findsOneWidget);
    await tester.tap(_word);
    await tester.pump(const Duration(milliseconds: 60));
    // The set-aside class is mid-fold: still on the card, shrinking.
    expect(find.text('Computer Architecture'), findsWidgets);
    await _pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('Computer Architecture'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });
}
