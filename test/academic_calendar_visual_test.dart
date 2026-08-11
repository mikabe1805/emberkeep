import 'package:emberkeep/academic_calendar/data/academic_calendar_preferences.dart';
import 'package:emberkeep/academic_calendar/data/academic_schedule_repository.dart';
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/services/notebook_handoff.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/calendar.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

const _capture = bool.fromEnvironment('CAPTURE_ACADEMIC');

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
}

AcademicSchedule _visualSchedule() {
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
    startMinute: 14 * 60,
    endMinute: 16 * 60 + 50,
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
      dueDate: CivilDate(2026, 8, 11),
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
