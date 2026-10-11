// The Plans room (the daybook): the day with Mika's real classes, the week, the
// month, the page turns, the add flows, a class's own menu, large text.
//
// Everything runs through CalendarPage, the way the shell mounts it, on a
// phone-sized surface, with the Rutgers Fall 2026 timetable from the fixture.
import 'dart:ui' show Tristate;

import 'package:emberkeep/academic_calendar/data/academic_calendar_preferences.dart';
import 'package:emberkeep/academic_calendar/data/academic_schedule_repository.dart';
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/academic_calendar/services/notebook_handoff.dart';
import 'package:emberkeep/academic_calendar/widgets/academic_calendar_sections.dart';
import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/daybook/widgets/daybook_event_editor.dart';
import 'package:emberkeep/daybook/widgets/daybook_task_editor.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/screens/calendar.dart';
import 'package:emberkeep/widgets/house/house_backdrop.dart';
import 'package:emberkeep/widgets/house/house_light.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:emberkeep/widgets/house/plans/plans_cards.dart';
import 'package:emberkeep/widgets/house/plans/plans_geometry.dart';
import 'package:emberkeep/widgets/house/plans/plans_page_turn.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/rutgers_fall_2026_ics_fixture.dart';

/// A Tuesday: Computer Architecture at 10:20 and Discrete Structures at 2:00.
final _tuesday = DateTime(2026, 10, 6, 12, 30);

final _schedule = AcademicScheduleIcsImporter.parse(
  rutgersFall2026IcsFixture(),
).applyTo(AcademicSchedule.empty(), updatedAt: DateTime.utc(2026, 8, 27));

final class _Handoff implements NotebookHandoff {
  final List<NotebookHandoffIntent> intents = [];

  @override
  Future<NotebookHandoffResult> open(NotebookHandoffIntent intent) async {
    intents.add(intent);
    return NotebookHandoffResult.opened;
  }
}

Future<InMemoryAcademicCalendarPreferences> _pump(
  WidgetTester tester, {
  AcademicCalendarMode mode = AcademicCalendarMode.day,
  String date = '2026-10-06',
  Size size = const Size(393, 852),
  double textScale = 1,
  bool reduceMotion = false,
  InMemoryAcademicScheduleRepository? repository,
  NotebookHandoff? handoff,
  DateTime? now,
}) async {
  Clock.freeze(now ?? _tuesday);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.binding.setSurfaceSize(null);
  });
  final preferences = InMemoryAcademicCalendarPreferences(
    state: AcademicCalendarViewState(mode: mode, selectedDate: date),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CalendarPage(
          state: GameState()..reduceMotion = reduceMotion,
          quests: const [],
          onAdd: (_) => true,
          scheduleRepository:
              repository ?? InMemoryAcademicScheduleRepository(_schedule),
          calendarPreferences: preferences,
          notebookHandoff: handoff ?? _Handoff(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  return preferences;
}

Future<void> _turned(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 700));
}

/// How many lines a paragraph is set in.
int _lineCount(RenderParagraph paragraph) {
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(
      baseOffset: 0,
      extentOffset: paragraph.text.toPlainText().length,
    ),
  );
  return {for (final box in boxes) box.top.round()}.length;
}

Finder _curl() => find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is PlansCurlPainter,
);

void main() {
  setUp(() {
    Sfx.instance.soundEnabled = false;
  });

  tearDown(() {
    Clock.reset();
    Sfx.instance.soundEnabled = true;
  });

  group('where the pages are', () {
    test('the month grid is the plate\'s own, in order and on the page', () {
      final cols = PlansCanvas.monthColumns;
      final rows = PlansCanvas.monthRows;
      expect(cols, hasLength(8));
      expect(rows, hasLength(7));
      expect(cols, orderedEquals([...cols]..sort()));
      expect(rows, orderedEquals([...rows]..sort()));
      // The grid sits inside the right page's live field.
      expect(cols.first, greaterThan(PlansCanvas.field.left));
      expect(cols.last, lessThan(PlansCanvas.field.right));
      // The weekday row is the plate's first row; the date rows are five.
      expect(rows[0], lessThan(PlansCanvas.field.top + 50));
    });

    test('the layout scales with the screen width and hangs from the top', () {
      final layout = PlansLayout.forWidth(786);
      expect(layout.scale, 2);
      final field = layout.rect(PlansCanvas.field);
      expect(field.left, closeTo(PlansCanvas.field.left * 2, 1e-9));
      expect(field.top, closeTo(PlansCanvas.field.top * 2, 1e-9));
    });

    test('each view stands on its plate, the week on its own', () {
      expect(PlansPlates.forMode(AcademicCalendarMode.day), PlansPlates.day);
      expect(
        PlansPlates.forMode(AcademicCalendarMode.threeDay),
        PlansPlates.day,
      );
      expect(
        PlansPlates.forMode(AcademicCalendarMode.month),
        PlansPlates.month,
      );
      // The week has a plate of its own: the book with seven painted rows.
      expect(PlansPlates.week, HousePlateSets.plansWeek);
      expect(PlansPlates.weekHasOwnPlate, isTrue);
      expect(PlansPlates.forMode(AcademicCalendarMode.week), PlansPlates.week);

      // And the light does the rest.
      const week = HousePlates(
        midday: 'assets/rooms/house/plate-plans-week-midday.webp',
        evening: 'assets/rooms/house/plate-plans-week-evening.webp',
      );
      expect(
        housePlateLayersAt(week, DateTime(2026, 10, 6, 12)).single.asset,
        week.midday,
      );
      expect(
        housePlateLayersAt(week, DateTime(2026, 10, 6, 21)).single.asset,
        week.evening,
      );
    });

    test('the evening is the painted evening plate, never a tint', () {
      for (final plates in [PlansPlates.day, PlansPlates.month]) {
        final layers = housePlateLayersAt(plates, DateTime(2026, 10, 6, 21));
        expect(layers.single.asset, HousePlateSets.plansDay.evening);
      }
    });

    test('turning toward the month is forward, toward the day is back', () {
      expect(
        plansViewOrder(AcademicCalendarMode.month),
        greaterThan(plansViewOrder(AcademicCalendarMode.week)),
      );
      expect(
        plansViewOrder(AcademicCalendarMode.week),
        greaterThan(plansViewOrder(AcademicCalendarMode.threeDay)),
      );
      expect(
        plansViewOrder(AcademicCalendarMode.threeDay),
        greaterThan(plansViewOrder(AcademicCalendarMode.day)),
      );
    });
  });

  group('the day', () {
    testWidgets('a Tuesday holds his real classes with rings and menus', (
      tester,
    ) async {
      await _pump(tester);

      // The left page: MON to SUN with dates, today marked, Tuesday pointed at.
      for (final day in [5, 6, 7, 8, 9, 10, 11]) {
        expect(
          find.byKey(
            ValueKey('daybook-day-control-2026-10-${'$day'.padLeft(2, '0')}'),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('TODAY'), findsOneWidget);
      final tuesday = tester.getSemantics(
        find.byKey(const ValueKey('daybook-day-control-2026-10-06')),
      );
      expect(tuesday.label, 'Tuesday, October 6, today');
      expect(
        tuesday.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );

      // The right page: the date, ADD, two class cards, PLAN QUEST.
      expect(find.text('TUE · OCT 6'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.byKey(const ValueKey('academic-add-class')), findsOneWidget);
      expect(
        find.text('Computer Architecture & Assembly Language'),
        findsOneWidget,
      );
      expect(find.text('10:20 AM–11:40 AM'), findsOneWidget);
      expect(
        find.text('Introduction to Discrete Structures II'),
        findsOneWidget,
      );
      expect(find.text('2:00 PM–3:20 PM'), findsOneWidget);
      expect(find.text('PLAN QUEST'), findsOneWidget);
      // One "..." for each class.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey &&
              (w.key! as ValueKey).value.toString().startsWith(
                'academic-card-menu-',
              ),
        ),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a day tab turns the page to that day, with a curl', (
      tester,
    ) async {
      final preferences = await _pump(tester);

      await tester.tap(
        find.byKey(const ValueKey('daybook-day-control-2026-10-07')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Mid-turn: both pages are on the table and the curl sweeps between.
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Wednesday'), findsOneWidget);
      expect(_curl(), findsOneWidget);
      expect(preferences.state.selectedDate, '2026-10-07');

      await _turned(tester);
      expect(find.text('Today'), findsNothing);
      expect(find.text('Wednesday'), findsOneWidget);
      expect(_curl(), findsNothing);
      expect(find.text('Computer Architecture Lab'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with Reduce Motion the page turn is a cross-fade', (
      tester,
    ) async {
      await _pump(tester, reduceMotion: true);

      await tester.tap(
        find.byKey(const ValueKey('daybook-day-control-2026-10-07')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Wednesday'), findsOneWidget);
      expect(_curl(), findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(find.text('Today'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('swiping turns the page a day at a time', (tester) async {
      final preferences = await _pump(tester);
      final book = find.byKey(const ValueKey('academic-day-view'));

      await tester.fling(book, const Offset(-260, 0), 1200);
      await _turned(tester);
      expect(preferences.state.selectedDate, '2026-10-07');
      expect(find.text('Wednesday'), findsOneWidget);

      await tester.fling(book, const Offset(260, 0), 1200);
      await _turned(tester);
      expect(preferences.state.selectedDate, '2026-10-06');
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('a class card\'s menu opens notes and MOVE / CANCEL', (
      tester,
    ) async {
      final handoff = _Handoff();
      await _pump(tester, handoff: handoff);

      final menu = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            (w.key! as ValueKey).value.toString().startsWith(
              'academic-card-menu-',
            ),
      );
      await tester.tap(menu.first);
      await tester.pumpAndSettle();
      // NOTES is under the ring of the class that is next, and in the menu.
      expect(find.text('NOTES'), findsNWidgets(2));
      expect(find.text('MOVE / CANCEL THIS CLASS'), findsOneWidget);

      await tester.tap(find.text('NOTES').last);
      await tester.pumpAndSettle();
      expect(handoff.intents, hasLength(1));
      expect(handoff.intents.single.courseCode, '14:332:331');

      await tester.tap(menu.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('MOVE / CANCEL THIS CLASS'));
      await tester.pumpAndSettle();
      expect(find.byType(AcademicOccurrenceAdjustDialog), findsOneWidget);
      expect(find.text('ADJUST THIS CLASS'), findsOneWidget);
    });

    testWidgets('a class can be cancelled and restored from its card', (
      tester,
    ) async {
      final repository = InMemoryAcademicScheduleRepository(_schedule);
      await _pump(tester, repository: repository);
      final key = _schedule
          .occurrencesOn(CivilDate(2026, 10, 6))
          .firstWhere((o) => o.localStartMinute == 10 * 60 + 20)
          .occurrenceKey;

      await tester.tap(find.byKey(ValueKey('academic-card-menu-$key')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('academic-adjust-occurrence-$key')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('academic-occurrence-cancel')),
      );
      await tester.pumpAndSettle();
      expect(
        repository.schedule.occurrenceByKey(key)!.state,
        OccurrenceState.cancelled,
      );
      expect(find.text('CANCELLED'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('academic-card-menu-$key')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('academic-adjust-occurrence-$key')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('academic-occurrence-restore')),
      );
      await tester.pumpAndSettle();
      expect(
        repository.schedule.occurrenceByKey(key)!.state,
        OccurrenceState.scheduled,
      );
      expect(find.text('CANCELLED'), findsNothing);
    });

    testWidgets('ADD reaches every way into the daybook', (tester) async {
      await _pump(tester);

      Future<void> choose(String key) async {
        await tester.tap(find.byKey(const ValueKey('academic-add-class')));
        await tester.pumpAndSettle();
        expect(find.text('ADD TO YOUR DAYBOOK'), findsOneWidget);
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
      }

      await choose('daybook-add-choice-event');
      expect(find.byType(DaybookEventEditor), findsOneWidget);
      await tester.tap(find.byTooltip('Close').last);
      await tester.pumpAndSettle();

      await choose('daybook-add-choice-task');
      expect(find.byType(DaybookTaskEditor), findsOneWidget);
      await tester.tap(find.byTooltip('Close').last);
      await tester.pumpAndSettle();

      await choose('academic-add-choice-class');
      expect(find.byType(AddAcademicMeetingDialog), findsOneWidget);
      await tester.tap(find.byTooltip('Close').last);
      await tester.pumpAndSettle();

      await choose('academic-add-choice-assignment');
      expect(find.byType(AddAcademicWorkDialog), findsOneWidget);
      await tester.tap(find.byTooltip('Close').last);
      await tester.pumpAndSettle();

      await choose('academic-add-choice-exam');
      expect(find.byType(AddAcademicWorkDialog), findsOneWidget);
      await tester.tap(find.byTooltip('Close').last);
      await tester.pumpAndSettle();

      await choose('academic-add-choice-import');
      expect(find.byKey(const ValueKey('add-classes-sheet')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PLAN QUEST opens the presets', (tester) async {
      await _pump(tester);
      await tester.tap(
        find.byKey(const ValueKey('calendar-plan-selected-day')),
      );
      await tester.pumpAndSettle();
      for (final preset in const [
        'FOCUS BLOCK',
        'MOVE GENTLY',
        'RESET SPACE',
        'REACH OUT',
      ]) {
        expect(find.text(preset), findsOneWidget);
      }
      await tester.tap(find.text('FOCUS BLOCK'));
      await tester.pump();
      expect(find.text('One focused block'), findsOneWidget);
    });

    testWidgets('a past day has no PLAN QUEST', (tester) async {
      await _pump(tester, date: '2026-10-05');
      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('PLAN QUEST'), findsNothing);
      expect(
        find.byKey(const ValueKey('calendar-back-to-today')),
        findsOneWidget,
      );
    });
  });

  group('the week and the month', () {
    testWidgets('the week is seven rows; a row opens its day', (tester) async {
      final preferences = await _pump(tester, mode: AcademicCalendarMode.week);
      expect(find.byKey(const ValueKey('academic-week-view')), findsOneWidget);
      for (final day in ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']) {
        expect(find.text(day), findsOneWidget);
      }
      // Today is the only column marked as today, and he reads it aloud.
      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey('daybook-day-control-2026-10-06')),
            )
            .label,
        startsWith('Tuesday, October 6, today, 2 plans'),
      );

      await tester.tap(
        find.byKey(const ValueKey('daybook-day-control-2026-10-08')),
      );
      await _turned(tester);
      expect(preferences.state.mode, AcademicCalendarMode.day);
      expect(preferences.state.selectedDate, '2026-10-08');
      expect(find.text('Thursday'), findsOneWidget);
    });

    testWidgets('the month marks today and the days that are full', (
      tester,
    ) async {
      await _pump(tester, mode: AcademicCalendarMode.month);
      expect(find.byKey(const ValueKey('academic-month-view')), findsOneWidget);
      expect(find.text('OCTOBER'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('month-today-marker-2026-10-06')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('academic-month-weight-2026-10-06')),
        findsOneWidget,
      );
      // A weekend has no classes and no weight.
      expect(
        find.byKey(const ValueKey('academic-month-weight-2026-10-10')),
        findsNothing,
      );
      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey('academic-month-day-2026-10-06')),
            )
            .label,
        startsWith('October 6, 2026, today'),
      );
    });

    testWidgets(
      'the switch moves between the views; 3 DAYS is in its overflow',
      (tester) async {
        await _pump(tester, mode: AcademicCalendarMode.month);
        for (final mode in ['week', 'day', 'month']) {
          await tester.tap(find.byKey(ValueKey('academic-mode-$mode')));
          await _turned(tester);
          expect(
            find.byKey(ValueKey('academic-$mode-view')),
            findsOneWidget,
            reason: mode,
          );
        }
        expect(
          find.byKey(const ValueKey('academic-mode-threeDay')),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('academic-mode-overflow')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('academic-mode-threeDay')));
        await _turned(tester);
        expect(
          find.byKey(const ValueKey('academic-threeDay-view')),
          findsOneWidget,
        );
        expect(
          tester
              .getSemantics(
                find.byKey(const ValueKey('academic-mode-overflow')),
              )
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );
      },
    );

    testWidgets('the book names its page turns for a screen reader', (
      tester,
    ) async {
      await _pump(tester);
      final handle = tester.ensureSemantics();
      final book = tester.getSemantics(
        find.byKey(const ValueKey('academic-day-view')).first,
      );
      expect(book, isNotNull);
      expect(find.bySemanticsLabel('Previous day'), findsOneWidget);
      expect(find.bySemanticsLabel('Next day'), findsOneWidget);
      expect(find.bySemanticsLabel('Daybook, day view'), findsOneWidget);
      handle.dispose();
    });
  });

  group('other screens', () {
    testWidgets(
      'a phone is the whole screen; a tablet gets a phone-sized book',
      (tester) async {
        await _pump(tester);
        expect(tester.getSize(find.byType(HouseRoomBackdrop)).width, 393);

        await _pump(tester, size: const Size(768, 1024));
        // 1024 tall: the book is 1024 x 393 / 852 wide, in the middle, and the
        // day's cards are on the screen, not under its bottom edge.
        final book = tester.getRect(find.byType(HouseRoomBackdrop));
        expect(book.width, closeTo(1024 * 393 / 852, 0.5));
        expect(book.center.dx, closeTo(384, 0.5));
        expect(
          tester.getRect(find.text('PLAN QUEST')).bottom,
          lessThan(1024 * 0.88),
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('a card title that is set to fit', () {
    // Test text is one em wide a letter, so a 150-point column takes ten
    // letters of 14.5 and nine of 15.5 or 16.5.
    Future<TextStyle> pumpTitle(
      WidgetTester tester,
      String title, {
      double textScale = 1,
    }) async {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 150,
              child: PlansCardTitle(title: title, dim: false),
            ),
          ),
        ),
      );
      return tester.widget<Text>(find.text(title)).style!;
    }

    testWidgets('a name that fits two lines is never cut', (tester) async {
      final style = await pumpTitle(tester, 'abcdefghij klmnopqrs');
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('abcdefghij klmnopqrs'),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(style.fontSize, 14.5, reason: 'a point or two smaller to fit');
    });

    testWidgets('a name that fits at full size keeps it', (tester) async {
      final style = await pumpTitle(tester, 'abcdefgh ijklmnop');
      expect(style.fontSize, 16.5);
    });

    testWidgets('a longer one ends in an ellipsis, at the smallest size', (
      tester,
    ) async {
      final style = await pumpTitle(tester, 'abcdefghij klmnopqrs tuvwxyz');
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('abcdefghij klmnopqrs tuvwxyz'),
      );
      expect(paragraph.didExceedMaxLines, isTrue);
      expect(style.fontSize, 14.5);
      expect(_lineCount(paragraph), lessThanOrEqualTo(2));
    });

    testWidgets('at large text the size is the one the person chose', (
      tester,
    ) async {
      final style = await pumpTitle(
        tester,
        'abcdefghij klmnopqrs',
        textScale: 1.3,
      );
      expect(style.fontSize, 16.5);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('abcdefghij klmnopqrs'),
      );
      expect(_lineCount(paragraph), lessThanOrEqualTo(2));
    });
  });

  group('long names', () {
    const longName = 'Computer Architecture & Assembly Language';

    for (final scale in const [1.0, 1.3, 2.0]) {
      testWidgets(
        'a long class name is two lines at most at ${(scale * 100).round()}%',
        (tester) async {
          final semantics = tester.ensureSemantics();
          await _pump(tester, textScale: scale);

          final title = find.text(longName);
          expect(title, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(title);
          expect(_lineCount(paragraph), lessThanOrEqualTo(2));
          expect(paragraph.didExceedMaxLines, isTrue);
          expect(tester.widget<Text>(title).maxLines, 2);
          expect(tester.widget<Text>(title).overflow, TextOverflow.ellipsis);

          // The whole name is still said aloud, by the card's text node.
          expect(find.bySemanticsLabel(longName), findsWidgets);
          expect(tester.takeException(), isNull);
          semantics.dispose();
        },
      );
    }

    testWidgets('the "..." menu names the class in full', (tester) async {
      await _pump(tester);
      final menu = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            (w.key! as ValueKey).value.toString().startsWith(
              'academic-card-menu-',
            ),
      );
      await tester.tap(menu.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // The card's own words, and the menu's heading.
      expect(find.text(longName), findsNWidgets(2));
    });

    for (final scale in const [1.0, 1.3, 2.0]) {
      testWidgets(
        'the week keeps a long name to its strip at ${(scale * 100).round()}%',
        (tester) async {
          await _pump(
            tester,
            mode: AcademicCalendarMode.week,
            textScale: scale,
          );
          expect(tester.takeException(), isNull);
          for (final strip in find.textContaining('Assembly').evaluate()) {
            final box = strip.renderObject as RenderParagraph;
            expect(_lineCount(box), lessThanOrEqualTo(2));
          }
        },
      );
    }
  });

  group('large text', () {
    for (final size in const [Size(393, 852), Size(320, 568)]) {
      for (final scale in const [1.3, 2.0]) {
        for (final mode in const [
          AcademicCalendarMode.day,
          AcademicCalendarMode.threeDay,
          AcademicCalendarMode.week,
          AcademicCalendarMode.month,
        ]) {
          testWidgets(
            '${mode.label} at ${(scale * 100).round()}% on ${size.width.round()}x${size.height.round()} does not overflow',
            (tester) async {
              await _pump(tester, mode: mode, size: size, textScale: scale);
              expect(tester.takeException(), isNull);
              expect(
                find.byKey(const ValueKey('academic-add-class')),
                findsOneWidget,
              );
              // The cards and the days scroll inside the page; nothing is cut
              // off by the screen's edge.
              final add = tester.getRect(
                find.byKey(const ValueKey('academic-add-class')),
              );
              expect(add.right, lessThanOrEqualTo(size.width));
              expect(add.height, greaterThanOrEqualTo(44));
            },
          );
        }
      }
    }
  });
}
