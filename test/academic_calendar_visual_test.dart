import 'dart:async';
import 'dart:io';

import 'package:emberkeep/academic_calendar/data/academic_calendar_preferences.dart';
import 'package:emberkeep/academic_calendar/data/academic_schedule_repository.dart';
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/services/notebook_handoff.dart';
import 'package:emberkeep/academic_calendar/widgets/academic_calendar_sections.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/daybook/data/daybook_preferences.dart';
import 'package:emberkeep/daybook/domain/daybook_event.dart';
import 'package:emberkeep/daybook/domain/daybook_place.dart';
import 'package:emberkeep/daybook/domain/daybook_task.dart';
import 'package:emberkeep/daybook/services/directions_launcher.dart';
import 'package:emberkeep/daybook/widgets/daybook_rows.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/calendar.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'support/golden_platform_policy.dart';

const _capture = bool.fromEnvironment('CAPTURE_ACADEMIC');
const _captureStore = bool.fromEnvironment('CAPTURE_STORE');
const _verifyExactGoldens = bool.fromEnvironment('VERIFY_EXACT_GOLDENS');
const _captureConflict = bool.fromEnvironment('CAPTURE_ACADEMIC_CONFLICT');
const _captureTransition = bool.fromEnvironment('CAPTURE_ACADEMIC_TRANSITION');
const _captureStudyPlanner = bool.fromEnvironment(
  'CAPTURE_ACADEMIC_STUDY_PLANNER',
);
const _captureOccurrenceAdjust = bool.fromEnvironment(
  'CAPTURE_ACADEMIC_OCCURRENCE_ADJUST',
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    final fraunces = FontLoader('Fraunces')
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-Bold.ttf'));
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Regular.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Medium.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Bold.ttf'));
    final mono = FontLoader('JetBrainsMono')
      ..addFont(
        rootBundle.load('assets/google_fonts/JetBrainsMono-SemiBold.ttf'),
      );
    await Future.wait([
      icons.load(),
      fraunces.load(),
      inter.load(),
      mono.load(),
    ]);
  });

  setUp(() {
    Clock.freeze(DateTime.utc(2026, 8, 11, 14, 15));
  });

  tearDown(Clock.reset);

  for (final mode in const [
    AcademicCalendarMode.month,
    AcademicCalendarMode.day,
  ]) {
    testWidgets('academic ${mode.name} visual', (tester) async {
      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
      });
      final state = GameState()
        ..reduceMotion = true
        ..history[Days.key(DateTime(2026, 8, 11))] = 2
        ..journal = [
          Note(
            at: DateTime(2026, 8, 11, 9),
            text: 'Questions to bring to office hours.',
          ),
        ];
      final plan = Quest(
        title: 'Finish the problem set',
        stat: Stat.foc,
        difficulty: 5,
        schedule: QuestSchedule.once,
        dueDate: DateTime(2026, 8, 11),
        custom: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Palette.parchment,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Palette.xp,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: Scaffold(
            body: CalendarPage(
              state: state,
              quests: [plan],
              onAdd: (_) => true,
              scheduleRepository: InMemoryAcademicScheduleRepository(
                _visualSchedule(),
              ),
              calendarPreferences: InMemoryAcademicCalendarPreferences(
                state: AcademicCalendarViewState(
                  mode: mode,
                  selectedDate: '2026-08-11',
                ),
              ),
              notebookHandoff: _NoopHandoff(),
            ),
          ),
        ),
      );
      await tester.pump();
      final context = tester.element(find.byType(MaterialApp));
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/pages/plans-desk-v2.webp'),
          context,
        ),
      );
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(tester.takeException(), isNull);
      if (_capture) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/academic_schedule_${mode.name}_430x932.png',
          ),
        );
      }
    });
  }

  testWidgets('App Store Daybook release visual', (tester) async {
    if (!_captureStore) return;

    await _pumpGeneralDaybookReleaseFixture(
      tester,
      mode: AcademicCalendarMode.month,
      size: const Size(430, 932),
      textScale: 1,
      devicePixelRatio: 3,
    );

    expect(find.text('PLANS'), findsOneWidget);
    expect(find.text('DAYBOOK'), findsOneWidget);
    expect(find.text('AUGUST 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/store_03_daybook_1290x2796.png'),
    );
  });

  for (final mode in const [
    AcademicCalendarMode.month,
    AcademicCalendarMode.day,
  ]) {
    testWidgets('general daybook ${mode.name} release visual', (tester) async {
      await _pumpGeneralDaybookReleaseFixture(
        tester,
        mode: mode,
        size: const Size(430, 932),
        textScale: 1,
      );

      expect(find.text('DAYBOOK'), findsOneWidget);
      expect(find.text('Summer 2026'), findsOneWidget);
      expect(
        find.text(
          mode == AcademicCalendarMode.month
              ? 'AUGUST 2026'
              : 'AUGUST 11, 2026',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      if (mode == AcademicCalendarMode.day) {
        await Scrollable.ensureVisible(
          tester.element(find.text('TUESDAY 11')),
          alignment: 0.02,
        );
        await tester.pump();
        expect(find.text('Return the field recorder'), findsOneWidget);
        expect(find.text('Museum tickets release'), findsOneWidget);
        expect(find.text('Portfolio review'), findsOneWidget);
        expect(find.text('Studio circle'), findsOneWidget);
        expect(find.text('DES 210 · STU'), findsOneWidget);
        expect(
          find.text(
            'Clear the kitchen table and put every borrowed thing back',
          ),
          findsOneWidget,
        );
        expect(find.text('Choose references for the cover'), findsOneWidget);
        expect(find.text('Clear the sink'), findsNothing);
        expect(
          tester.getTopLeft(find.text('Museum tickets release')).dy,
          greaterThanOrEqualTo(16),
        );
        expect(
          tester.getTopLeft(find.text('Return the field recorder')).dy,
          greaterThan(932 * 0.65),
        );
        expect(tester.takeException(), isNull);
      }

      await runExactGoldenCheck(
        operatingSystem: Platform.operatingSystem,
        explicitlyEnabled: _verifyExactGoldens,
        updatingGoldens: autoUpdateGoldenFiles,
        compare: () => expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/daybook_general_${mode.name}_430x932.png'),
        ),
      );
    });

    testWidgets(
      'general daybook ${mode.name} reflows at 320x568 and 200% text',
      (tester) async {
        await _pumpGeneralDaybookReleaseFixture(
          tester,
          mode: mode,
          size: const Size(320, 568),
          textScale: 2,
        );

        expect(find.text('DAYBOOK'), findsOneWidget);
        expect(find.text('Summer 2026'), findsOneWidget);
        expect(find.text('MON'), findsOneWidget);
        expect(find.text('WK'), findsOneWidget);
        expect(find.text('3D'), findsOneWidget);
        expect(find.text('DAY'), findsOneWidget);
        expect(
          tester
              .renderObject<RenderParagraph>(find.text('Summer 2026'))
              .didExceedMaxLines,
          isFalse,
        );
        expect(tester.takeException(), isNull);
        for (
          var drag = 0;
          drag < 20 &&
              find.text('Return the field recorder').evaluate().isEmpty;
          drag++
        ) {
          await tester.dragFrom(const Offset(160, 498), const Offset(0, -260));
          await tester.pump();
        }
        expect(find.text('Return the field recorder'), findsOneWidget);
        await tester.ensureVisible(find.text('Return the field recorder'));
        await tester.pump();
        expect(find.text('Museum tickets release'), findsOneWidget);
        expect(find.text('Portfolio review'), findsOneWidget);
        expect(find.text('Studio circle'), findsOneWidget);
        expect(find.text('DES 210 · STU'), findsOneWidget);
        expect(
          find.text(
            'Clear the kitchen table and put every borrowed thing back',
          ),
          findsOneWidget,
        );
        expect(
          tester
              .renderObject<RenderParagraph>(
                find.text(
                  'Clear the kitchen table and put every borrowed thing back',
                ),
              )
              .didExceedMaxLines,
          isFalse,
        );
        expect(
          tester
              .renderObject<RenderParagraph>(
                find.text('Return the field recorder'),
              )
              .didExceedMaxLines,
          isFalse,
        );
        final selectedDayLabel = mode == AcademicCalendarMode.month
            ? 'TUESDAY 11 · TODAY'
            : 'TUESDAY 11';
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(selectedDayLabel))
              .didExceedMaxLines,
          isFalse,
        );
        if (mode == AcademicCalendarMode.month) {
          expect(
            tester.getBottomLeft(find.text(selectedDayLabel)).dy,
            lessThan(tester.getTopLeft(find.text('+ PLAN')).dy),
          );
        } else {
          expect(find.text('TUESDAY 11 · TODAY'), findsNothing);
          expect(find.text('+ PLAN'), findsOneWidget);
          expect(
            tester.getBottomLeft(find.text(selectedDayLabel)).dy,
            lessThan(tester.getTopLeft(find.text('DAY SHAPE')).dy),
          );
          expect(
            tester.getBottomLeft(find.text('+ PLAN')).dy,
            lessThan(tester.getTopLeft(find.text('DAY SHAPE')).dy),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final configuration in const [
    (name: 'normal', size: Size(430, 932), textScale: 1.0),
    (name: 'narrow_200', size: Size(320, 568), textScale: 2.0),
  ]) {
    testWidgets('general daybook ${configuration.name} visual', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue =
          configuration.textScale;
      await tester.binding.setSurfaceSize(configuration.size);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.binding.setSurfaceSize(null);
      });
      final state = GameState()..reduceMotion = true;
      final quest = Quest(
        title: 'Quest board check-in',
        stat: Stat.foc,
        difficulty: 3,
        schedule: QuestSchedule.once,
        dueDate: DateTime(2026, 8, 11),
      );
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Palette.parchment,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Palette.xp,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: Scaffold(
            body: CalendarPage(
              state: state,
              quests: [quest],
              onAdd: (_) => true,
              scheduleRepository: InMemoryAcademicScheduleRepository(
                _visualDaybookSchedule(),
              ),
              calendarPreferences: InMemoryAcademicCalendarPreferences(
                state: const AcademicCalendarViewState(
                  mode: AcademicCalendarMode.day,
                  selectedDate: '2026-08-11',
                ),
              ),
              notebookHandoff: _NoopHandoff(),
            ),
          ),
        ),
      );
      await tester.pump();
      final context = tester.element(find.byType(MaterialApp));
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/pages/plans-desk-v2.webp'),
          context,
        ),
      );
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      if (configuration.textScale == 2) {
        expect(find.text('MON'), findsOneWidget);
        expect(find.text('WK'), findsOneWidget);
        expect(find.text('3D'), findsOneWidget);
        expect(find.text('DAY'), findsOneWidget);
      }
      await tester.scrollUntilVisible(
        find.text('DAY SHAPE'),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('DAY SHAPE'));
      await tester.pump();
      expect(find.text('DAY SHAPE'), findsOneWidget);
      expect(find.text('ALL DAY'), findsWidgets);
      expect(find.text('Library closed'), findsOneWidget);
      expect(find.text('Project meeting'), findsOneWidget);
      expect(find.text('Return library book'), findsOneWidget);
      expect(find.text('STILL OPEN'), findsOneWidget);
      if (configuration.textScale == 2) {
        expect(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('open-notebook-occurrence_visual_1')),
              )
              .dy,
          greaterThan(tester.getBottomLeft(find.text('ECE 345 · LEC')).dy),
        );
      }
      expect(tester.takeException(), isNull);
      await runExactGoldenCheck(
        operatingSystem: Platform.operatingSystem,
        explicitlyEnabled: _verifyExactGoldens,
        updatingGoldens: autoUpdateGoldenFiles,
        compare: () => expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/daybook_general_${configuration.name}.png',
          ),
        ),
      );
    });
  }

  testWidgets('integrated projected directions row visual', (tester) async {
    await _pumpGeneralDaybookReleaseFixture(
      tester,
      mode: AcademicCalendarMode.day,
      size: const Size(430, 932),
      textScale: 1,
      integratedDirections: true,
    );

    final eventTitle = find.text('Portfolio review');
    await Scrollable.ensureVisible(tester.element(eventTitle), alignment: 0.20);
    await tester.pump();

    final directions = find.bySemanticsLabel(
      'Get directions to Zimmerli Art Museum',
    );
    expect(eventTitle, findsOneWidget);
    expect(directions, findsOneWidget);
    expect(
      tester.getTopLeft(directions).dy,
      greaterThan(tester.getBottomLeft(eventTitle).dy),
    );
    expect(tester.takeException(), isNull);
    await runExactGoldenCheck(
      operatingSystem: Platform.operatingSystem,
      explicitlyEnabled: _verifyExactGoldens,
      updatingGoldens: autoUpdateGoldenFiles,
      compare: () => expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/daybook_directions_integrated_430x932.png'),
      ),
    );
  });

  for (final configuration in const [
    (name: 'normal', size: Size(430, 932), textScale: 1.0),
    (name: 'narrow_200', size: Size(320, 568), textScale: 2.0),
  ]) {
    testWidgets('directions surfaces ${configuration.name} visual', (
      tester,
    ) async {
      final isNarrow = configuration.name == 'narrow_200';
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue =
          configuration.textScale;
      await tester.binding.setSurfaceSize(configuration.size);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            platform: TargetPlatform.iOS,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Palette.parchment,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Palette.xp,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: Scaffold(
            body: Center(
              child: DaybookDirectionsAction(
                place: DaybookPlace(
                  savedName: isNarrow
                      ? 'Alexander Library Special Collections and University Archives Reading Room'
                      : 'Alexander Library',
                  routingText: '169 College Ave, New Brunswick, NJ',
                ),
                launcher: _UnavailableDirectionsLauncher(),
                preferences: InMemoryDaybookPreferences(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('GET DIRECTIONS'));
      await tester.pumpAndSettle();
      expect(find.text('APPLE MAPS'), findsOneWidget);
      expect(find.text('GOOGLE MAPS'), findsOneWidget);
      await tester.ensureVisible(find.text('GOOGLE MAPS'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await runExactGoldenCheck(
        operatingSystem: Platform.operatingSystem,
        explicitlyEnabled: _verifyExactGoldens,
        updatingGoldens: autoUpdateGoldenFiles,
        compare: () => expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/daybook_directions_provider_${configuration.name}.png',
          ),
        ),
      );

      await tester.tap(find.text('GOOGLE MAPS'));
      await tester.pumpAndSettle();
      expect(find.text('COPY LOCATION'), findsOneWidget);
      expect(find.text('GOOGLE MAPS'), findsOneWidget);
      await tester.ensureVisible(find.text('COPY LOCATION'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await runExactGoldenCheck(
        operatingSystem: Platform.operatingSystem,
        explicitlyEnabled: _verifyExactGoldens,
        updatingGoldens: autoUpdateGoldenFiles,
        compare: () => expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/daybook_directions_failure_${configuration.name}.png',
          ),
        ),
      );
    });
  }

  testWidgets('daybook today marker visual', (tester) async {
    Clock.freeze(DateTime.utc(2026, 8, 17, 12));
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    final state = GameState()..reduceMotion = true;
    final todayDeadline = Quest(
      title: 'Submit the project brief',
      stat: Stat.foc,
      difficulty: 5,
      schedule: QuestSchedule.once,
      dueDate: DateTime(2026, 8, 17),
      timerMinutes: 240,
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Palette.parchment,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Palette.xp,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: Scaffold(
          body: CalendarPage(
            state: state,
            quests: [todayDeadline],
            onAdd: (_) => true,
            scheduleRepository: InMemoryAcademicScheduleRepository(
              _visualSchedule(),
            ),
            calendarPreferences: InMemoryAcademicCalendarPreferences(
              state: const AcademicCalendarViewState(
                mode: AcademicCalendarMode.month,
                selectedDate: '2026-08-17',
              ),
            ),
            notebookHandoff: _NoopHandoff(),
          ),
        ),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(MaterialApp));
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/pages/plans-desk-v2.webp'),
        context,
      ),
    );
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(tester.takeException(), isNull);
    await runExactGoldenCheck(
      operatingSystem: Platform.operatingSystem,
      explicitlyEnabled: _verifyExactGoldens,
      updatingGoldens: autoUpdateGoldenFiles,
      compare: () => expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/daybook_today_marker_430x932.png'),
      ),
    );
  });

  testWidgets('academic conflict visual', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    final state = GameState()..reduceMotion = true;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Palette.parchment,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Palette.xp,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: Scaffold(
          body: CalendarPage(
            state: state,
            quests: const [],
            onAdd: (_) => true,
            scheduleRepository: InMemoryAcademicScheduleRepository(
              _visualSchedule(overlap: true),
            ),
            calendarPreferences: InMemoryAcademicCalendarPreferences(
              state: const AcademicCalendarViewState(
                mode: AcademicCalendarMode.day,
                selectedDate: '2026-08-11',
              ),
            ),
            notebookHandoff: _NoopHandoff(),
          ),
        ),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(MaterialApp));
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/pages/plans-desk-v2.webp'),
        context,
      ),
    );
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(tester.takeException(), isNull);
    if (_captureConflict) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/academic_schedule_conflict_430x932.png'),
      );
    }
  });

  testWidgets('academic transition visual', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    final state = GameState()..reduceMotion = true;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Palette.parchment,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Palette.xp,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: Scaffold(
          body: CalendarPage(
            state: state,
            quests: const [],
            onAdd: (_) => true,
            scheduleRepository: InMemoryAcademicScheduleRepository(
              _visualSchedule(tightTransition: true),
            ),
            calendarPreferences: InMemoryAcademicCalendarPreferences(
              state: const AcademicCalendarViewState(
                mode: AcademicCalendarMode.day,
                selectedDate: '2026-08-11',
              ),
            ),
            notebookHandoff: _NoopHandoff(),
          ),
        ),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(MaterialApp));
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/pages/plans-desk-v2.webp'),
        context,
      ),
    );
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(tester.takeException(), isNull);
    if (_captureTransition) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/academic_schedule_transition_430x932.png'),
      );
    }
  });

  testWidgets('academic study planner visual', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    final schedule = _visualSchedule(studyPlan: true);
    final item = schedule.workItems.singleWhere(
      (item) => item.workId == 'work_visual_problem_set',
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Palette.parchment,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Palette.xp,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: Scaffold(
          body: Stack(
            children: [
              CalendarPage(
                state: GameState()..reduceMotion = true,
                quests: const [],
                onAdd: (_) => true,
                scheduleRepository: InMemoryAcademicScheduleRepository(
                  schedule,
                ),
                calendarPreferences: InMemoryAcademicCalendarPreferences(),
                notebookHandoff: _NoopHandoff(),
              ),
              AcademicStudyPlannerDialog(
                schedule: schedule,
                item: item,
                planningStartDate: CivilDate(2026, 8, 11),
                onSave: (_, _) async => true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(MaterialApp));
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/pages/plans-desk-v2.webp'),
        context,
      ),
    );
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(tester.takeException(), isNull);
    if (_captureStudyPlanner) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/academic_study_planner_430x932.png'),
      );
    }
  });

  testWidgets('academic one-class adjustment visual', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    var schedule = _visualSchedule(studyPlan: true);
    schedule = schedule.putStudyPlan(
      plan: AcademicStudyPlan(
        workId: 'work_visual_problem_set',
        totalMinutes: 120,
        sessionMinutes: 45,
        dailyStartMinute: 9 * 60,
        dailyEndMinute: 20 * 60,
        updatedAt: DateTime.utc(2026, 8, 11),
      ),
      blocks: [
        AcademicStudyBlock(
          studyBlockId: 'study_visual_problem_set_1',
          workId: 'work_visual_problem_set',
          date: CivilDate(2026, 8, 11),
          startMinute: 17 * 60,
          endMinute: 17 * 60 + 45,
          updatedAt: DateTime.utc(2026, 8, 11),
        ),
      ],
    );
    final occurrence = schedule.occurrences.firstWhere(
      (item) =>
          item.courseId == 'course_ece_345' &&
          item.date == CivilDate(2026, 8, 11),
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Palette.parchment,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Palette.xp,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: Scaffold(
          body: CalendarPage(
            state: GameState()..reduceMotion = true,
            quests: const [],
            onAdd: (_) => true,
            scheduleRepository: InMemoryAcademicScheduleRepository(schedule),
            calendarPreferences: InMemoryAcademicCalendarPreferences(),
            notebookHandoff: _NoopHandoff(),
          ),
        ),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(MaterialApp));
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/pages/plans-desk-v2.webp'),
        context,
      ),
    );
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    final pageContext = tester.element(find.byType(CalendarPage));
    unawaited(
      showDialog<void>(
        context: pageContext,
        barrierColor: Palette.dialogBarrier,
        builder: (_) => AcademicOccurrenceAdjustDialog(
          schedule: schedule,
          occurrence: occurrence,
          onMove: (_, _, _, _) async => true,
          onCancel: (_) async => true,
          onRestore: (_) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (_captureOccurrenceAdjust) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/academic_occurrence_adjust_430x932.png'),
      );
    }
  });
}

Future<void> _pumpGeneralDaybookReleaseFixture(
  WidgetTester tester, {
  required AcademicCalendarMode mode,
  required Size size,
  required double textScale,
  double devicePixelRatio = 1,
  bool integratedDirections = false,
}) async {
  tester.view.devicePixelRatio = devicePixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.binding.setSurfaceSize(null);
  });

  final state = GameState()..reduceMotion = true;
  final dueQuest = Quest(
    title: 'Clear the kitchen table and put every borrowed thing back',
    stat: Stat.dis,
    difficulty: 2,
    schedule: QuestSchedule.once,
    dueDate: DateTime(2026, 8, 11),
  );
  final focusQuest = Quest(
    title: 'Choose references for the cover',
    stat: Stat.foc,
    difficulty: 3,
    priorityDay: Days.key(DateTime(2026, 8, 11)),
  );
  final routineQuest = Quest(
    title: 'Clear the sink',
    stat: Stat.dis,
    difficulty: 1,
    schedule: QuestSchedule.daily,
  );
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Palette.parchment,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Palette.xp,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: CalendarPage(
          state: state,
          quests: [dueQuest, focusQuest, routineQuest],
          onAdd: (_) => true,
          scheduleRepository: InMemoryAcademicScheduleRepository(
            _generalDaybookReleaseSchedule(
              integratedDirections: integratedDirections,
            ),
          ),
          calendarPreferences: InMemoryAcademicCalendarPreferences(
            state: AcademicCalendarViewState(
              mode: mode,
              selectedDate: '2026-08-11',
            ),
          ),
          notebookHandoff: _NoopHandoff(),
          directionsLauncher: integratedDirections
              ? _UnavailableDirectionsLauncher()
              : null,
          daybookPreferences: integratedDirections
              ? InMemoryDaybookPreferences()
              : null,
        ),
      ),
    ),
  );
  await tester.pump();
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/pages/plans-desk-v2.webp'),
      context,
    ),
  );
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

AcademicSchedule _generalDaybookReleaseSchedule({
  bool integratedDirections = false,
}) {
  final createdAt = DateTime.utc(2026, 8, 8);
  final term = AcademicTerm(
    termId: 'term_release_summer_2026',
    name: 'Summer 2026',
    startDate: CivilDate(2026, 8, 1),
    endDate: CivilDate(2026, 8, 31),
    timeZoneId: 'America/New_York',
  );
  final course = AcademicCourse(
    courseId: 'course_release_des_210',
    termId: term.termId,
    code: 'DES 210',
    title: 'Interaction Studio',
    colorValue: 0xFF8AAFC6,
    colorLabel: 'Dusk blue',
  );
  final series = MeetingSeries(
    meetingSeriesId: 'series_release_des_210',
    courseId: course.courseId,
    kind: MeetingKind.studio,
    weekdays: const {DateTime.tuesday},
    localStartMinute: 11 * 60 + 30,
    localEndMinute: 12 * 60 + 30,
    firstDate: term.startDate,
    lastDate: term.endDate,
    timeZoneId: term.timeZoneId,
    place: CampusPlace(
      label: 'Civic Hall 204',
      building: 'Civic Hall',
      room: '204',
    ),
    reminders: const [],
    updatedAt: createdAt,
  );
  var occurrenceIndex = 0;
  var schedule = AcademicSchedule.empty().putMeeting(
    term: term,
    course: course,
    series: series,
    updatedAt: createdAt,
    idFactory: (_) => 'occurrence_release_${++occurrenceIndex}',
  );

  schedule = schedule
      .putEvent(
        DaybookEvent(
          eventId: 'event_release_museum_tickets',
          title: 'Museum tickets release',
          startDate: CivilDate(2026, 8, 11),
          endDate: CivilDate(2026, 8, 12),
          timeZoneId: term.timeZoneId,
          allDay: true,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      )
      .putEvent(
        DaybookEvent(
          eventId: 'event_release_portfolio_review',
          title: 'Portfolio review',
          startDate: CivilDate(2026, 8, 11),
          endDate: CivilDate(2026, 8, 11),
          timeZoneId: term.timeZoneId,
          allDay: false,
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          place: integratedDirections
              ? DaybookPlace(
                  savedName: 'Zimmerli Art Museum',
                  routingText: '71 Hamilton Street, New Brunswick, NJ',
                )
              : null,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      )
      .putEvent(
        DaybookEvent(
          eventId: 'event_release_studio_circle',
          title: 'Studio circle',
          startDate: CivilDate(2026, 8, 11),
          endDate: CivilDate(2026, 8, 11),
          timeZoneId: term.timeZoneId,
          allDay: false,
          startMinute: 16 * 60,
          endMinute: 17 * 60,
          weeklyRule: WeeklyEventRule(
            weekdays: const {DateTime.tuesday},
            endsOn: CivilDate(2026, 8, 25),
          ),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      )
      .putTask(
        DaybookTask(
          taskId: 'task_release_field_recorder',
          title: 'Return the field recorder',
          dueDate: CivilDate(2026, 8, 11),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
  return schedule;
}

AcademicSchedule _visualSchedule({
  bool overlap = false,
  bool tightTransition = false,
  bool studyPlan = false,
}) {
  final term = AcademicTerm(
    termId: 'term_fall_2026',
    name: 'Fall 2026',
    startDate: CivilDate(2026, 8, 10),
    endDate: CivilDate(2026, 8, 21),
    timeZoneId: 'America/New_York',
  );
  var schedule = AcademicSchedule.empty();
  var occurrenceIndex = 0;
  String nextOccurrence(String _) => 'occurrence_visual_${++occurrenceIndex}';

  AcademicSchedule add({
    required String courseId,
    required String seriesId,
    required String code,
    required String title,
    required int color,
    required String colorLabel,
    required MeetingKind kind,
    required Set<int> weekdays,
    required int startMinute,
    required int endMinute,
    required String building,
    required String room,
  }) {
    final course = AcademicCourse(
      courseId: courseId,
      termId: term.termId,
      code: code,
      title: title,
      colorValue: color,
      colorLabel: colorLabel,
    );
    final series = MeetingSeries(
      meetingSeriesId: seriesId,
      courseId: courseId,
      kind: kind,
      weekdays: weekdays,
      localStartMinute: startMinute,
      localEndMinute: endMinute,
      firstDate: term.startDate,
      lastDate: term.endDate,
      timeZoneId: term.timeZoneId,
      place: CampusPlace(
        label: '$building $room',
        building: building,
        room: room,
      ),
      reminders: [
        AcademicReminder(reminderId: 'reminder_$seriesId', offsetMinutes: 10),
      ],
      updatedAt: DateTime.utc(2026, 8, 11),
    );
    return schedule.putMeeting(
      term: term,
      course: course,
      series: series,
      updatedAt: DateTime.utc(2026, 8, 11),
      idFactory: nextOccurrence,
    );
  }

  schedule = add(
    courseId: 'course_ece_345',
    seriesId: 'series_ece_345_lecture',
    code: 'ECE 345',
    title: 'Linear Systems',
    color: 0xFF8AAFC6,
    colorLabel: 'Dusk blue',
    kind: MeetingKind.lecture,
    weekdays: const {DateTime.tuesday, DateTime.friday},
    startMinute: 10 * 60 + 20,
    endMinute: 11 * 60 + 40,
    building: 'Hill Center',
    room: '114',
  );
  schedule = add(
    courseId: 'course_chem_161',
    seriesId: 'series_chem_161_lab',
    code: 'CHEM 161',
    title: 'General Chemistry',
    color: 0xFF9CBC88,
    colorLabel: 'Moss',
    kind: MeetingKind.lab,
    weekdays: const {DateTime.tuesday},
    startMinute: overlap
        ? 11 * 60
        : tightTransition
        ? 11 * 60 + 45
        : 14 * 60,
    endMinute: overlap
        ? 12 * 60 + 30
        : tightTransition
        ? 13 * 60 + 15
        : 16 * 60 + 50,
    building: 'Wright Labs',
    room: 'B12',
  );
  schedule = add(
    courseId: 'course_hist_210',
    seriesId: 'series_hist_210_recitation',
    code: 'HIST 210',
    title: 'Cities and Memory',
    color: 0xFFDD9A72,
    colorLabel: 'Terracotta',
    kind: MeetingKind.recitation,
    weekdays: const {DateTime.wednesday},
    startMinute: 9 * 60,
    endMinute: 9 * 60 + 55,
    building: 'Scott Hall',
    room: '205',
  );
  schedule = schedule.putWorkItem(
    AcademicWorkItem(
      workId: 'work_visual_problem_set',
      courseId: 'course_ece_345',
      kind: AcademicWorkKind.assignment,
      title: 'Problem set 3',
      dueDate: CivilDate(2026, 8, studyPlan ? 14 : 11),
      dueMinute: 23 * 60 + 59,
      details: 'Convolution problems 1–10',
      updatedAt: DateTime.utc(2026, 8, 11),
    ),
  );
  schedule = schedule.putWorkItem(
    AcademicWorkItem(
      workId: 'work_visual_chem_exam',
      courseId: 'course_chem_161',
      kind: AcademicWorkKind.exam,
      title: 'Stoichiometry quiz',
      dueDate: CivilDate(2026, 8, 12),
      dueMinute: 13 * 60,
      updatedAt: DateTime.utc(2026, 8, 11),
    ),
  );
  return schedule;
}

AcademicSchedule _visualDaybookSchedule() {
  final createdAt = DateTime.utc(2026, 8, 8);
  return _visualSchedule()
      .putEvent(
        DaybookEvent(
          eventId: 'event_visual_library_closed',
          title: 'Library closed',
          startDate: CivilDate(2026, 8, 11),
          endDate: CivilDate(2026, 8, 12),
          timeZoneId: 'America/New_York',
          allDay: true,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      )
      .putEvent(
        DaybookEvent(
          eventId: 'event_visual_project_meeting',
          title: 'Project meeting',
          startDate: CivilDate(2026, 8, 11),
          endDate: CivilDate(2026, 8, 11),
          timeZoneId: 'America/New_York',
          allDay: false,
          startMinute: 8 * 60 + 30,
          endMinute: 9 * 60 + 30,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      )
      .putTask(
        DaybookTask(
          taskId: 'task_visual_return_book',
          title: 'Return library book',
          dueDate: CivilDate(2026, 8, 10),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      )
      .putTask(
        DaybookTask(
          taskId: 'task_visual_send_form',
          title: 'Send the form',
          dueDate: CivilDate(2026, 8, 11),
          dueMinute: 16 * 60,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
}

final class _NoopHandoff implements NotebookHandoff {
  @override
  Future<NotebookHandoffResult> open(NotebookHandoffIntent intent) async =>
      NotebookHandoffResult.opened;
}

final class _UnavailableDirectionsLauncher implements DirectionsLauncher {
  @override
  Future<bool> open(DaybookPlace place, MapProvider provider) async => false;
}
