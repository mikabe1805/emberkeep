import 'package:emberkeep/academic_calendar/data/academic_calendar_preferences.dart';
import 'package:emberkeep/academic_calendar/data/academic_schedule_repository.dart';
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/services/notebook_handoff.dart';
import 'package:emberkeep/academic_calendar/widgets/academic_calendar_sections.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/screens/calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Clock.freeze(DateTime.utc(2026, 8, 11, 14, 15));
  });

  tearDown(Clock.reset);

  testWidgets('Plans shows Now, room, time, and the stable notebook doorway', (
    tester,
  ) async {
    final schedule = _scheduleFixture();
    final repository = InMemoryAcademicScheduleRepository(schedule);
    final handoff = _RecordingHandoff();
    await _pumpCalendar(tester, repository: repository, handoff: handoff);

    expect(find.text('ACADEMIC DAYBOOK'), findsOneWidget);
    expect(find.text('Fall 2026'), findsOneWidget);
    expect(find.text('READY IN 5 MIN'), findsOneWidget);
    expect(find.text('ECE 345 · Lecture'), findsOneWidget);
    expect(find.textContaining('Hill Center · 114'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('academic-doorway-open-notebook')),
    );
    await tester.pump();

    expect(handoff.intents, hasLength(1));
    expect(handoff.intents.single.courseId, 'course_ece_345');
    expect(
      handoff.intents.single.occurrenceKey,
      schedule.occurrences.single.occurrenceKey,
    );
    expect(handoff.intents.single.notebookId, isNull);
  });

  testWidgets('Month, Week, 3-day, and Day read the same occurrence record', (
    tester,
  ) async {
    final schedule = _scheduleFixture();
    final key = schedule.occurrences.single.occurrenceKey;
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(schedule),
      handoff: _RecordingHandoff(),
    );

    expect(
      find.byKey(ValueKey('academic-month-occurrence-$key')),
      findsOneWidget,
    );

    for (final mode in const [
      AcademicCalendarMode.week,
      AcademicCalendarMode.threeDay,
      AcademicCalendarMode.day,
    ]) {
      await tester.tap(find.byKey(ValueKey('academic-mode-${mode.name}')));
      await tester.pump();
      expect(
        find.byKey(ValueKey('academic-${mode.name}-view')),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey('academic-occurrence-$key')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Add class saves a real recurring course into the local store', (
    tester,
  ) async {
    final repository = InMemoryAcademicScheduleRepository();
    await _pumpCalendar(
      tester,
      repository: repository,
      handoff: _RecordingHandoff(),
    );

    await tester.tap(find.byKey(const ValueKey('academic-add-class')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.enterText(
      find.byKey(const ValueKey('academic-course-code')),
      'BIO 101',
    );
    await tester.enterText(
      find.byKey(const ValueKey('academic-course-title')),
      'Foundations of Biology',
    );
    await tester.enterText(
      find.byKey(const ValueKey('academic-building')),
      'Life Sciences',
    );
    await tester.enterText(find.byKey(const ValueKey('academic-room')), '204');
    final save = find.text('KEEP THIS CLASS');
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(repository.saveCount, 1);
    expect(repository.schedule.courses.single.code, 'BIO 101');
    expect(repository.schedule.meetingSeries.single.weekdays, {
      DateTime.tuesday,
    });
    expect(
      repository.schedule.meetingSeries.single.place.shortLabel,
      'Life Sciences · 204',
    );
    expect(repository.schedule.occurrences, isNotEmpty);
    expect(
      repository.schedule.occurrences.every(
        (occurrence) =>
            occurrence.occurrenceKey.trim().isNotEmpty &&
            occurrence.courseId == repository.schedule.courses.single.courseId,
      ),
      isTrue,
    );
    expect(find.byType(AddAcademicMeetingDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected date and view remain device-local preferences', (
    tester,
  ) async {
    final preferences = InMemoryAcademicCalendarPreferences(
      state: const AcademicCalendarViewState(
        mode: AcademicCalendarMode.threeDay,
        selectedDate: '2026-08-11',
      ),
    );
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(_scheduleFixture()),
      handoff: _RecordingHandoff(),
      preferences: preferences,
    );

    expect(
      find.byKey(const ValueKey('academic-threeDay-view')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('academic-mode-day')));
    await tester.pump();

    expect(preferences.state.mode, AcademicCalendarMode.day);
    expect(preferences.state.selectedDate, '2026-08-11');
  });

  testWidgets('academic controls reflow on a narrow phone at 200% text', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(_scheduleFixture()),
      handoff: _RecordingHandoff(),
      size: const Size(320, 568),
      textScale: 2,
    );

    expect(find.byKey(const ValueKey('academic-add-class')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('academic-now-next')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('academic-now-next')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required InMemoryAcademicScheduleRepository repository,
  required NotebookHandoff handoff,
  AcademicCalendarPreferences? preferences,
  Size size = const Size(430, 932),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.binding.setSurfaceSize(null);
  });
  final state = GameState()..reduceMotion = true;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: CalendarPage(
          state: state,
          quests: const [],
          onAdd: (_) => true,
          scheduleRepository: repository,
          calendarPreferences:
              preferences ?? InMemoryAcademicCalendarPreferences(),
          notebookHandoff: handoff,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

AcademicSchedule _scheduleFixture() {
  final term = AcademicTerm(
    termId: 'term_fall_2026',
    name: 'Fall 2026',
    startDate: CivilDate(2026, 8, 10),
    endDate: CivilDate(2026, 8, 14),
    timeZoneId: 'America/New_York',
  );
  final course = AcademicCourse(
    courseId: 'course_ece_345',
    termId: term.termId,
    code: 'ECE 345',
    title: 'Linear Systems',
    colorValue: 0xFF8AAFC6,
    colorLabel: 'Dusk blue',
  );
  final series = MeetingSeries(
    meetingSeriesId: 'series_ece_345_lecture',
    courseId: course.courseId,
    kind: MeetingKind.lecture,
    weekdays: const {DateTime.tuesday},
    localStartMinute: 10 * 60 + 20,
    localEndMinute: 11 * 60 + 40,
    firstDate: term.startDate,
    lastDate: term.endDate,
    timeZoneId: term.timeZoneId,
    place: CampusPlace(
      label: 'Hill Center 114',
      building: 'Hill Center',
      room: '114',
    ),
    reminders: [
      AcademicReminder(reminderId: 'reminder_ece_345_10m', offsetMinutes: 10),
    ],
    updatedAt: DateTime.utc(2026, 8, 11),
  );
  return AcademicSchedule.empty().putMeeting(
    term: term,
    course: course,
    series: series,
    updatedAt: DateTime.utc(2026, 8, 11),
    idFactory: (_) => 'occurrence_ece_345_aug_11',
  );
}

final class _RecordingHandoff implements NotebookHandoff {
  final List<NotebookHandoffIntent> intents = [];

  @override
  Future<NotebookHandoffResult> open(NotebookHandoffIntent intent) async {
    intents.add(intent);
    return NotebookHandoffResult.opened;
  }
}
