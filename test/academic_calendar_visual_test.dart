import 'dart:async';

import 'package:emberkeep/academic_calendar/data/academic_calendar_preferences.dart';
import 'package:emberkeep/academic_calendar/data/academic_schedule_repository.dart';
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/services/notebook_handoff.dart';
import 'package:emberkeep/academic_calendar/widgets/academic_calendar_sections.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/calendar.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

const _capture = bool.fromEnvironment('CAPTURE_ACADEMIC');
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
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/daybook_today_marker_430x932.png'),
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

final class _NoopHandoff implements NotebookHandoff {
  @override
  Future<NotebookHandoffResult> open(NotebookHandoffIntent intent) async =>
      NotebookHandoffResult.opened;
}
