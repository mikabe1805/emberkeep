// "Couldn't make it" on the class-day card: a quiet word on a class that can
// be set aside, the row folding away, a few seconds of "Undo", and nothing on
// the card that counts what was set aside. Also that the card scales from one
// class to a crowded day.
//
// Clocks are frozen at INSTANTS (New York wall times converted from UTC).
import 'dart:convert';

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
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/crowded_friday_schedule.dart';
import 'support/rutgers_fall_2026_ics_fixture.dart';

DateTime _ny(int day, int hour, int minute) =>
    DateTime.utc(2026, 10, day, hour + 4, minute).toLocal();

final AcademicSchedule _fall2026 = AcademicScheduleIcsImporter.parse(
  rutgersFall2026IcsFixture(),
).applyTo(AcademicSchedule.empty(), updatedAt: DateTime.utc(2026, 8, 27));

GameState _mika() => GameState()
  ..onboarded = true
  ..playerName = 'Mika'
  ..level = 18
  ..xp = 284
  ..totalXp = 4280
  ..soundEnabled = false
  ..reduceMotion = true;

class _Board {
  _Board(this.state);
  final GameState state;
  int persisted = 0;
}

/// The page with a PLAIN timetable lookup: it does not know about the save, so
/// the page itself must honor "Couldn't make it".
Future<_Board> _mount(
  WidgetTester tester, {
  required DateTime at,
  AcademicSchedule? schedule,
  GameState? state,
  double textScale = 1,
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
  final quests = [
    Quest(
      title: 'Read ten pages',
      stat: Stat.intl,
      difficulty: 4,
      schedule: QuestSchedule.daily,
    ),
  ];
  final timetable = schedule ?? _fall2026;
  ClassDay lookup(DateTime now, {CivilDate? day}) =>
      projectClassDay(timetable, now, day: day);
  final board = _Board(s);
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
            onPersist: () => board.persisted++,
            onAdd: (_) => true,
            onRemove: (_) {},
            onSnapshot: () => jsonEncode(s.toJson()),
            onRestore: (_) {},
            classDays: lookup,
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
final _setAside = find.text(classSetAsideLabel);
final _undoLine = find.byKey(const Key('class-dismissed-line'));
final _undo = find.byKey(const Key('class-dismissed-undo'));

String _occurrence(String code) => projectClassDay(
  _fall2026,
  Clock.now(),
).classes.firstWhere((c) => c.courseCode == code).occurrenceKey;

/// Every string drawn on the card.
List<String> _texts(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(find.byType(Text)))
    text.data ?? text.textSpan?.toPlainText() ?? '',
];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => Sfx.instance.soundEnabled = false);
  tearDown(() {
    Clock.reset();
    Sfx.instance.debugResetForTesting();
    Sfx.instance.soundEnabled = true;
  });

  group('before class: the next class leads', () {
    testWidgets('both rows offer it quietly; tapping folds the class away', (
      tester,
    ) async {
      final board = await _mount(tester, at: _ny(6, 8, 5));
      expect(_room, findsOneWidget);
      // Tuesday: the 10:20 lecture leads, the 2:00 lecture waits quietly.
      expect(_setAside, findsNWidgets(2));
      expect(_undoLine, findsNothing);
      final xp = board.state.totalXp;

      await tester.tap(_setAside.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(board.state.classesDismissedOn('2026-10-06'), hasLength(1));
      expect(board.state.totalXp, xp, reason: 'it pays nothing');
      expect(board.persisted, greaterThan(0));
      // The other class leads now, with its own quiet word; the first is gone
      // from the card and only the Undo line names it.
      expect(
        find.byKey(Key('class-foremost-${_occurrence('01:198:206')}')),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('class-foremost-${_occurrence('14:332:331')}')),
        findsNothing,
      );
      expect(_setAside, findsOneWidget);
      expect(_undoLine, findsOneWidget);
      expect(
        find.text('Computer Architecture is off today’s list.'),
        findsOneWidget,
      );
      expect(find.text('Undo'), findsOneWidget);

      // The line goes by itself after about five seconds; the class stays off.
      await tester.pump(const Duration(seconds: 4));
      expect(_undoLine, findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(_undoLine, findsNothing);
      expect(board.state.classesDismissedOn('2026-10-06'), hasLength(1));
    });

    testWidgets('Undo brings the class back exactly where it was', (
      tester,
    ) async {
      final board = await _mount(tester, at: _ny(6, 8, 5));
      final before = jsonEncode(board.state.toJson());
      final leader = find.byKey(
        Key('class-foremost-${_occurrence('14:332:331')}'),
      );
      expect(leader, findsOneWidget);

      await tester.tap(_setAside.first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(leader, findsNothing);

      await tester.tap(_undo);
      await tester.pump(const Duration(milliseconds: 300));
      expect(leader, findsOneWidget);
      expect(_undoLine, findsNothing);
      expect(board.state.classesDismissedOn('2026-10-06'), isEmpty);
      expect(jsonEncode(board.state.toJson()), before);
      expect(_setAside, findsNWidgets(2));
      // Nothing is left waiting to fire.
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a second one replaces the first Undo line', (tester) async {
      final board = await _mount(tester, at: _ny(8, 7, 0));
      expect(_setAside, findsNWidgets(3));
      await tester.tap(_setAside.first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Electronics Devices is off today’s list.'),
        findsOneWidget,
      );
      await tester.tap(_setAside.first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('is off today’s list.'), findsOneWidget);
      expect(
        find.text('Electronics Devices is off today’s list.'),
        findsNothing,
      );
      expect(board.state.classesDismissedOn('2026-10-08'), hasLength(2));
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('after class: next to I WAS THERE, never louder', () {
    testWidgets('the lamp leads; the quiet word sits beside it', (
      tester,
    ) async {
      final board = await _mount(tester, at: _ny(6, 11, 52));
      expect(_there, findsOneWidget);
      expect(_setAside, findsNWidgets(2));
      final lamp = tester.getRect(_there);
      final word = tester.getRect(_setAside.first);
      expect(word.left, greaterThan(lamp.right - 1), reason: 'beside the lamp');
      expect(word.width, lessThan(lamp.width / 2), reason: 'never as large');

      // Cream, quiet: the word carries no red and no warning color.
      final style = tester.widget<Text>(_setAside.first).style!;
      final color = style.color!;
      expect(color.a, lessThan(1));
      expect(color.r, greaterThanOrEqualTo(color.b));
      expect((color.r - color.g).abs(), lessThan(0.2));
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byIcon(Icons.cancel), findsNothing);

      await tester.tap(_setAside.first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(board.state.classesKeptOn('2026-10-06'), isEmpty);
      expect(board.state.classesDismissedOn('2026-10-06'), hasLength(1));
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('keeping one and setting the other aside completes the day', (
      tester,
    ) async {
      final board = await _mount(tester, at: _ny(6, 15, 40));
      // Both 10:20 and 2:00 are over. Set the 10:20 aside.
      expect(_there, findsOneWidget);
      await tester.tap(_setAside.first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(board.state.classesDismissedOn('2026-10-06'), hasLength(1));
      // The card now holds one class, which leads.
      expect(_there, findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a class in session is not offered it', (tester) async {
      await _mount(tester, at: _ny(6, 10, 50));
      expect(_there, findsOneWidget);
      // The 10:20 is running; only the 2:00 can be set aside.
      expect(_setAside, findsOneWidget);
    });
  });

  group('nothing counts what was set aside', () {
    testWidgets('no count, no "of", no word for it, anywhere on the card', (
      tester,
    ) async {
      await _mount(tester, at: _ny(8, 7, 0));
      await tester.tap(_setAside.first);
      await tester.pump(const Duration(milliseconds: 300));
      final words = _texts(tester).join(' | ').toLowerCase();
      expect(RegExp(r'\d+\s+of\s+\d+').hasMatch(words), isFalse, reason: words);
      expect(words, isNot(contains(' of 3')));
      for (final loss in [
        'missed',
        'skipped',
        'failed',
        'lost',
        'broke',
        'dismiss',
        'absent',
        'excused',
      ]) {
        expect(words, isNot(contains(loss)), reason: loss);
      }
      // The header counts what is on the day, in words it already used.
      expect(words, contains('thursday · 2 classes'));
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('every class set aside: the Undo has somewhere to be', (
      tester,
    ) async {
      final board = await _mount(tester, at: _ny(6, 8, 5));
      await tester.tap(_setAside.first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(_setAside.first);
      await tester.pump(const Duration(milliseconds: 300));

      expect(board.state.classesDismissedOn('2026-10-06'), hasLength(2));
      expect(_room, findsOneWidget, reason: 'the room holds while Undo waits');
      expect(_undoLine, findsOneWidget);
      expect(_setAside, findsNothing);
      expect(_there, findsNothing);
      final words = _texts(tester).join(' | ');
      expect(words, isNot(contains('0 CLASSES')));

      // Undo brings the last one back and the day is a class day again.
      await tester.tap(_undo);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_setAside, findsOneWidget);

      // Set it aside again and let the line go: the day is the plain board.
      await tester.tap(_setAside.first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 6));
      expect(_room, findsNothing);
      expect(_undoLine, findsNothing);
      expect(find.text('Read ten pages'), findsWidgets);
    });

    testWidgets('a later day is untouched by a dismissal today', (
      tester,
    ) async {
      final board = await _mount(tester, at: _ny(7, 7, 0));
      await tester.tap(_setAside.first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(board.state.classesDismissedOn('2026-10-07'), hasLength(1));
      expect(board.state.classesDismissedOn('2026-10-08'), isEmpty);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('accessibility', () {
    testWidgets(
      'a labelled button with a tap, and a named action on the lamp',
      (tester) async {
        final handle = tester.ensureSemantics();
        final board = await _mount(tester, at: _ny(6, 11, 52));

        final control = find.semantics.byLabel(
          'Couldn’t make it: Computer Architecture',
        );
        expect(control, findsOne);
        final data = control.evaluate().single.getSemanticsData();
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(data.flagsCollection.isButton, isTrue);

        final lamp = find.semantics
            .byLabel(RegExp('^I was there: Computer Architecture'))
            .evaluate()
            .single
            .getSemanticsData();
        expect(lamp.customSemanticsActionIds, isNotNull);
        final named = [
          for (final id in lamp.customSemanticsActionIds!)
            CustomSemanticsAction.getAction(id)!.label,
        ];
        expect(named, contains(classSetAsideLabel));

        // Performing it through the semantics tree sets the class aside.
        tester.semantics.tap(control);
        await tester.pump(const Duration(milliseconds: 300));
        expect(board.state.classesDismissedOn('2026-10-06'), hasLength(1));
        await tester.pump(const Duration(seconds: 6));
        handle.dispose();
      },
    );

    testWidgets('the Undo line is announced and its button is labelled', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _mount(tester, at: _ny(6, 8, 5));
      await tester.tap(_setAside.first);
      await tester.pump(const Duration(milliseconds: 300));
      final line = find.semantics.byLabel(
        'Computer Architecture is off today’s list.',
      );
      expect(line, findsOne);
      expect(
        line.evaluate().single.getSemanticsData().flagsCollection.isLiveRegion,
        isTrue,
      );
      expect(
        find.semantics.byLabel(
          'Undo: Computer Architecture back on today’s list',
        ),
        findsOne,
      );
      await tester.pump(const Duration(seconds: 6));
      handle.dispose();
    });
  });

  group('it scales with the day', () {
    final days = <(String, List<String>)>[
      ('one class', ['lecture']),
      ('three classes', ['lecture', 'lab', 'recitation']),
      ('five classes', List.filled(5, 'lecture')),
      ('eight classes', List.filled(8, 'lecture')),
      (
        'a crowded day with optional meetings',
        [
          'lecture',
          'lab',
          'recitation',
          'office hours',
          'lecture',
          'lecture',
          'office hours',
          'lab',
          'lecture',
        ],
      ),
    ];
    for (final (name, kinds) in days) {
      for (final scale in [1.0, 1.6]) {
        testWidgets('$name, text x$scale: no overflow, a word on each row', (
          tester,
        ) async {
          final schedule = crowdedFridaySchedule(kinds);
          // Before the first class: every row is later today.
          final board = await _mount(
            tester,
            at: _ny(9, 7, 0),
            schedule: schedule,
            textScale: scale,
            size: const Size(393, 852),
          );
          expect(tester.takeException(), isNull);
          expect(_room, findsOneWidget);
          expect(_setAside, findsNWidgets(kinds.length));

          // Set the first one aside; the card still lays out.
          await tester.tap(_setAside.first);
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          expect(board.state.classesDismissedOn('2026-10-09'), hasLength(1));
          expect(_setAside, findsNWidgets(kinds.length - 1));
          await tester.pump(const Duration(seconds: 6));
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('a small phone, large text, five classes: still no overflow', (
      tester,
    ) async {
      await _mount(
        tester,
        at: _ny(9, 7, 0),
        schedule: crowdedFridaySchedule(List.filled(5, 'lecture')),
        textScale: 2.0,
        size: const Size(320, 568),
      );
      expect(tester.takeException(), isNull);
      expect(_room, findsOneWidget);
    });
  });
}
