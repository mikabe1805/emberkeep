import 'package:emberkeep/academic_calendar/data/academic_calendar_preferences.dart';
import 'package:emberkeep/academic_calendar/data/academic_schedule_repository.dart';
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_file_picker.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/academic_calendar/services/notebook_handoff.dart';
import 'package:emberkeep/academic_calendar/widgets/academic_schedule_import_dialog.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/screens/calendar.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/glass_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/rutgers_fall_2026_ics_fixture.dart';

const _capture = bool.fromEnvironment('CAPTURE_ACADEMIC_IMPORT');

void main() {
  setUpAll(() async {
    if (!_capture) return;
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

  setUp(() => Clock.freeze(DateTime.utc(2026, 8, 27, 14)));
  tearDown(Clock.reset);

  testWidgets(
    'picker cancellation leaves the review empty and writes nothing',
    (tester) async {
      var saveCount = 0;
      await _pumpDialog(
        tester,
        picker: _FakePicker(null),
        onImport: (_) async {
          saveCount += 1;
          return true;
        },
      );

      await tester.tap(find.byKey(const ValueKey('academic-import-choose')));
      await tester.pumpAndSettle();

      expect(saveCount, 0);
      expect(find.text('CHOOSE .ICS FILE'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('academic-import-courses')),
        findsNothing,
      );
    },
  );

  testWidgets('invalid input stays open and never reaches storage', (
    tester,
  ) async {
    var saveCount = 0;
    await _pumpDialog(
      tester,
      picker: const _FakePicker(
        AcademicScheduleImportSource(
          name: 'not-a-class-calendar.ics',
          contents: 'BEGIN:VCALENDAR\nEND:VCALENDAR',
        ),
      ),
      onImport: (_) async {
        saveCount += 1;
        return true;
      },
    );

    await tester.tap(find.byKey(const ValueKey('academic-import-choose')));
    await tester.pumpAndSettle();

    expect(saveCount, 0);
    expect(find.byKey(const ValueKey('academic-import-error')), findsOneWidget);
    expect(find.byType(AcademicScheduleImportDialog), findsOneWidget);
  });

  testWidgets(
    'Rutgers review is exact and storage failure remains recoverable',
    (tester) async {
      var saveCount = 0;
      await _pumpDialog(
        tester,
        picker: _rutgersPicker(includeIgnoredEvent: true),
        onImport: (_) async {
          saveCount += 1;
          return false;
        },
      );

      await tester.tap(find.byKey(const ValueKey('academic-import-choose')));
      await tester.pumpAndSettle();

      expect(find.text('Fall 2026'), findsOneWidget);
      expect(
        find.textContaining('6 COURSES · 12 WEEKLY MEETINGS'),
        findsOneWidget,
      );
      expect(find.textContaining('168 class meetings'), findsOneWidget);
      expect(find.text('Electronics Devices'), findsOneWidget);
      expect(find.text('Electron Devices Lab'), findsOneWidget);
      expect(
        find.text('Computer Architecture & Assembly Language'),
        findsOneWidget,
      );
      expect(find.text('Computer Architecture Lab'), findsOneWidget);
      expect(find.text('Linear Systems & Signals'), findsOneWidget);
      expect(
        find.text('Introduction to Discrete Structures II'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('academic-import-warning')),
        findsOneWidget,
      );
      expect(saveCount, 0);

      await tester.ensureVisible(
        find.byKey(const ValueKey('academic-import-confirm')),
      );
      await tester.tap(find.byKey(const ValueKey('academic-import-confirm')));
      await tester.pumpAndSettle();

      expect(saveCount, 1);
      expect(
        find.text('Couldn’t save this schedule locally. Try again.'),
        findsOneWidget,
      );
      expect(find.byType(AcademicScheduleImportDialog), findsOneWidget);
    },
  );

  testWidgets('class reminder is off until the review explicitly enables it', (
    tester,
  ) async {
    AcademicScheduleImportDraft? imported;
    await _pumpDialog(
      tester,
      picker: _rutgersPicker(),
      onImport: (draft) async {
        imported = draft;
        return true;
      },
    );

    await tester.tap(find.byKey(const ValueKey('academic-import-choose')));
    await tester.pumpAndSettle();

    final reminderSwitch = find.byKey(
      const ValueKey('academic-import-reminder-switch'),
    );
    expect(reminderSwitch, findsOneWidget);
    expect(tester.widget<GlassSwitch>(reminderSwitch).value, isFalse);
    expect(
      find.byKey(const ValueKey('academic-import-reminder-offset')),
      findsNothing,
    );

    await tester.ensureVisible(reminderSwitch);
    await tester.tap(reminderSwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<GlassSwitch>(reminderSwitch).value, isTrue);
    expect(
      find.byKey(const ValueKey('academic-import-reminder-offset')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('academic-import-confirm')),
    );
    await tester.tap(find.byKey(const ValueKey('academic-import-confirm')));
    await tester.pumpAndSettle();

    expect(imported?.reminderChoice, AcademicScheduleImportReminderChoice.on);
    expect(imported?.reminderOffsetMinutes, 10);
  });

  testWidgets('Daybook import writes the reviewed schedule once', (
    tester,
  ) async {
    final repository = InMemoryAcademicScheduleRepository();
    await _pumpCalendar(
      tester,
      repository: repository,
      picker: _rutgersPicker(),
    );

    await tester.tap(find.byKey(const ValueKey('academic-add-class')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('academic-add-choice-import')),
    );
    await tester.tap(find.byKey(const ValueKey('academic-add-choice-import')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('academic-import-choose')));
    await tester.pumpAndSettle();

    expect(repository.saveCount, 0);
    expect(find.textContaining('168 class meetings'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('academic-import-confirm')),
    );
    await tester.tap(find.byKey(const ValueKey('academic-import-confirm')));
    await tester.pumpAndSettle();

    expect(repository.saveCount, 1);
    expect(repository.schedule.terms, hasLength(1));
    expect(repository.schedule.courses, hasLength(6));
    expect(repository.schedule.meetingSeries, hasLength(12));
    expect(
      repository.schedule.occurrences.where(
        (item) => item.state != OccurrenceState.cancelled,
      ),
      hasLength(168),
    );
    expect(find.byType(AcademicScheduleImportDialog), findsNothing);
  });

  for (final visual in const [
    (
      name: '430x932',
      size: Size(430, 932),
      textScale: 1.0,
      showConfirmation: false,
    ),
    (
      name: '430x932_confirm',
      size: Size(430, 932),
      textScale: 1.0,
      showConfirmation: true,
    ),
    (
      name: '320x568_1_3x',
      size: Size(320, 568),
      textScale: 1.3,
      showConfirmation: false,
    ),
  ]) {
    testWidgets('review visual ${visual.name}', (tester) async {
      await _pumpDialog(
        tester,
        picker: _rutgersPicker(includeIgnoredEvent: true),
        onImport: (_) async => true,
        size: visual.size,
        textScale: visual.textScale,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('academic-import-choose')),
      );
      await tester.tap(find.byKey(const ValueKey('academic-import-choose')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('6 COURSES · 12 WEEKLY MEETINGS'),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('academic-import-cancel')))
            .shortestSide,
        greaterThanOrEqualTo(44),
      );
      if (visual.showConfirmation) {
        await tester.ensureVisible(
          find.byKey(const ValueKey('academic-import-confirm')),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .getSize(find.byKey(const ValueKey('academic-import-confirm')))
              .height,
          greaterThanOrEqualTo(44),
        );
      }
      if (_capture) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/academic_schedule_import_review_${visual.name}.png',
          ),
        );
      }
    });
  }

  for (final result in const [
    (
      name: 'sep8_designated_monday',
      selectedDate: '2026-09-08',
      expectedTitle: '14:332:361 · LEC',
    ),
    (
      name: 'nov25_designated_friday',
      selectedDate: '2026-11-25',
      expectedTitle: '14:332:331 · LEC',
    ),
  ]) {
    testWidgets('imported result ${result.name}', (tester) async {
      final schedule = AcademicScheduleIcsImporter.parse(
        rutgersFall2026IcsFixture(),
      ).applyTo(AcademicSchedule.empty(), updatedAt: DateTime.utc(2026, 8, 27));
      await _pumpImportedDay(
        tester,
        schedule: schedule,
        selectedDate: result.selectedDate,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(result.expectedTitle), findsWidgets);
      if (_capture) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/academic_schedule_import_result_${result.name}_430x932.png',
          ),
        );
      }
    });
  }
}

_FakePicker _rutgersPicker({bool includeIgnoredEvent = false}) => _FakePicker(
  AcademicScheduleImportSource(
    name: 'rutgers-fall-2026.ics',
    contents: rutgersFall2026IcsFixture(
      includeIgnoredEvent: includeIgnoredEvent,
    ),
  ),
);

Future<void> _pumpDialog(
  WidgetTester tester, {
  required AcademicScheduleFilePicker picker,
  required SaveAcademicScheduleImport onImport,
  Size size = const Size(430, 932),
  double textScale = 1,
}) async {
  await _configureView(tester, size: size, textScale: textScale);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _theme,
      home: Builder(
        builder: (context) => Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF17131A), Color(0xFF2A1E27)],
              ),
            ),
            child: Center(
              child: TextButton(
                key: const ValueKey('open-import-dialog'),
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierColor: Palette.dialogBarrier,
                  builder: (_) => AcademicScheduleImportDialog(
                    filePicker: picker,
                    onImport: onImport,
                  ),
                ),
                child: const Text('Open import'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-import-dialog')));
  await tester.pumpAndSettle();
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required InMemoryAcademicScheduleRepository repository,
  required AcademicScheduleFilePicker picker,
}) async {
  await _configureView(tester, size: const Size(430, 932), textScale: 1);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _theme,
      home: Scaffold(
        body: CalendarPage(
          state: GameState()..reduceMotion = true,
          quests: const [],
          onAdd: (_) => true,
          scheduleRepository: repository,
          calendarPreferences: InMemoryAcademicCalendarPreferences(
            state: const AcademicCalendarViewState(
              mode: AcademicCalendarMode.month,
              selectedDate: '2026-08-27',
            ),
          ),
          notebookHandoff: const _NoopHandoff(),
          academicScheduleFilePicker: picker,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pumpImportedDay(
  WidgetTester tester, {
  required AcademicSchedule schedule,
  required String selectedDate,
}) async {
  await _configureView(tester, size: const Size(430, 932), textScale: 1);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _theme,
      home: Scaffold(
        body: CalendarPage(
          state: GameState()..reduceMotion = true,
          quests: const [],
          onAdd: (_) => true,
          scheduleRepository: InMemoryAcademicScheduleRepository(schedule),
          calendarPreferences: InMemoryAcademicCalendarPreferences(
            state: AcademicCalendarViewState(
              mode: AcademicCalendarMode.day,
              selectedDate: selectedDate,
            ),
          ),
          notebookHandoff: const _NoopHandoff(),
          academicScheduleFilePicker: const _FakePicker(null),
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

Future<void> _configureView(
  WidgetTester tester, {
  required Size size,
  required double textScale,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.binding.setSurfaceSize(null);
  });
}

final _theme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Palette.parchment,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Palette.xp,
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
);

final class _FakePicker implements AcademicScheduleFilePicker {
  const _FakePicker(this.source);

  final AcademicScheduleImportSource? source;

  @override
  Future<AcademicScheduleImportSource?> pick() async => source;
}

final class _NoopHandoff implements NotebookHandoff {
  const _NoopHandoff();

  @override
  Future<NotebookHandoffResult> open(NotebookHandoffIntent intent) async =>
      NotebookHandoffResult.opened;
}
