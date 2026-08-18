import 'package:emberkeep/academic_calendar/data/academic_calendar_preferences.dart';
import 'package:emberkeep/academic_calendar/data/academic_schedule_repository.dart';
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/services/notebook_handoff.dart';
import 'package:emberkeep/academic_calendar/widgets/academic_calendar_sections.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/daybook/domain/daybook_event.dart';
import 'package:emberkeep/daybook/domain/daybook_task.dart';
import 'package:emberkeep/daybook/widgets/daybook_add_choice_dialog.dart';
import 'package:emberkeep/daybook/widgets/daybook_event_editor.dart';
import 'package:emberkeep/daybook/widgets/daybook_rows.dart';
import 'package:emberkeep/daybook/widgets/daybook_task_editor.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/calendar.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Clock.freeze(DateTime.utc(2026, 8, 11, 14, 15));
  });

  tearDown(Clock.reset);

  testWidgets('Daybook header is neutral and keeps the active term secondary', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(),
      handoff: _RecordingHandoff(),
    );

    expect(find.text('DAYBOOK'), findsOneWidget);
    expect(
      find.text('Events, tasks, classes, and places in one view'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Add an event, task, class, assignment, or exam'),
      findsOneWidget,
    );

    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(_scheduleFixture()),
      handoff: _RecordingHandoff(),
      calendarKey: const ValueKey('daybook-term-header'),
    );

    expect(find.text('DAYBOOK'), findsOneWidget);
    expect(find.text('Fall 2026'), findsOneWidget);
    expect(
      find.text('Events, tasks, classes, and places in one view'),
      findsNothing,
    );
  });

  testWidgets('Daybook add chooser keeps general choices before School', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DaybookAddChoiceDialog())),
    );

    expect(find.text('ADD TO YOUR DAYBOOK'), findsOneWidget);
    expect(
      find.text('Keep events, tasks, and school together.'),
      findsOneWidget,
    );
    expect(find.text('SCHOOL'), findsOneWidget);

    final labels = ['EVENT', 'TASK', 'SCHOOL', 'CLASS', 'ASSIGNMENT', 'EXAM'];
    final tops = [
      for (final label in labels) tester.getTopLeft(find.text(label)).dy,
    ];
    expect(tops, orderedEquals(tops.toList()..sort()));

    for (final key in const [
      'daybook-add-choice-event',
      'daybook-add-choice-task',
      'academic-add-choice-class',
      'academic-add-choice-assignment',
      'academic-add-choice-exam',
    ]) {
      expect(
        tester.getSize(find.byKey(ValueKey(key))).height,
        greaterThanOrEqualTo(44),
      );
    }
  });

  testWidgets(
    'Daybook event editor validates title and keeps failed saves open',
    (tester) async {
      var saveCalls = 0;
      await _pumpDaybookWidget(
        tester,
        DaybookEventEditor(
          selectedDay: CivilDate(2026, 8, 11),
          onSave: (_) async {
            saveCalls += 1;
            return false;
          },
        ),
      );

      await tester.tap(find.byKey(const ValueKey('daybook-event-save')));
      await tester.pump();
      expect(
        find.text('Add a title before keeping this event.'),
        findsOneWidget,
      );
      expect(saveCalls, 0);
      expect(find.byType(DaybookEventEditor), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('daybook-event-title')),
        'Library hours',
      );
      await tester.tap(find.byKey(const ValueKey('daybook-event-save')));
      await tester.pump();
      expect(saveCalls, 1);
      expect(
        find.text('Couldn’t save this event locally. Try again.'),
        findsOneWidget,
      );
      expect(find.byType(DaybookEventEditor), findsOneWidget);
    },
  );

  testWidgets('Daybook event editor saves an all-day event and manual place', (
    tester,
  ) async {
    DaybookEvent? saved;
    await _pumpDaybookWidget(
      tester,
      DaybookEventEditor(
        selectedDay: CivilDate(2026, 8, 11),
        onSave: (event) async {
          saved = event;
          return true;
        },
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('daybook-event-title')),
      'Library hours',
    );
    await tester.enterText(
      find.byKey(const ValueKey('daybook-event-notes')),
      'Bring the borrowed book',
    );
    await tester.enterText(
      find.byKey(const ValueKey('daybook-event-place-saved-name')),
      'Alexander Library',
    );
    await tester.enterText(
      find.byKey(const ValueKey('daybook-event-place-routing-text')),
      '169 College Ave, New Brunswick, NJ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('daybook-event-place-building')),
      'Alexander',
    );
    await tester.enterText(
      find.byKey(const ValueKey('daybook-event-place-room')),
      'East Wing',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('daybook-event-save')),
    );
    await tester.tap(find.byKey(const ValueKey('daybook-event-save')));
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.title, 'Library hours');
    expect(saved!.notes, 'Bring the borrowed book');
    expect(saved!.startDate, CivilDate(2026, 8, 11));
    expect(saved!.endDate, CivilDate(2026, 8, 12));
    expect(saved!.allDay, isTrue);
    expect(saved!.startMinute, isNull);
    expect(saved!.endMinute, isNull);
    expect(saved!.weeklyRule, isNull);
    expect(saved!.place!.savedName, 'Alexander Library');
    expect(saved!.place!.routingText, '169 College Ave, New Brunswick, NJ');
    expect(saved!.place!.building, 'Alexander');
    expect(saved!.place!.room, 'East Wing');
  });

  testWidgets('Daybook event editor saves timed and valid weekly payloads', (
    tester,
  ) async {
    DaybookEvent? saved;
    await _pumpDaybookWidget(
      tester,
      DaybookEventEditor(
        selectedDay: CivilDate(2026, 8, 11),
        onSave: (event) async {
          saved = event;
          return true;
        },
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('daybook-event-title')),
      'Team check-in',
    );
    await tester.tap(find.byKey(const ValueKey('daybook-event-all-day')));
    await tester.tap(find.byKey(const ValueKey('daybook-event-weekly')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('daybook-event-weekday-2')));
    await tester.ensureVisible(
      find.byKey(const ValueKey('daybook-event-save')),
    );
    await tester.tap(find.byKey(const ValueKey('daybook-event-save')));
    await tester.pump();

    expect(
      find.text('Choose at least one weekday for a weekly event.'),
      findsOneWidget,
    );
    expect(saved, isNull);
    expect(find.byType(DaybookEventEditor), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('daybook-event-weekday-3')));
    await tester.ensureVisible(
      find.byKey(const ValueKey('daybook-event-save')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('daybook-event-save')));
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.allDay, isFalse);
    expect(saved!.startDate, CivilDate(2026, 8, 11));
    expect(saved!.endDate, CivilDate(2026, 8, 11));
    expect(saved!.startMinute, 9 * 60);
    expect(saved!.endMinute, 10 * 60);
    expect(saved!.weeklyRule!.weekdays, {DateTime.wednesday});
    expect(saved!.weeklyRule!.intervalWeeks, 1);
  });

  testWidgets(
    'Daybook task editor saves one-off due details without Quest state',
    (tester) async {
      DaybookTask? saved;
      await _pumpDaybookWidget(
        tester,
        DaybookTaskEditor(
          selectedDay: CivilDate(2026, 8, 11),
          onSave: (task) async {
            saved = task;
            return true;
          },
        ),
      );

      await tester.tap(find.byKey(const ValueKey('daybook-task-save')));
      await tester.pump();
      expect(
        find.text('Add a title before keeping this task.'),
        findsOneWidget,
      );
      expect(saved, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('daybook-task-title')),
        'Return library book',
      );
      await tester.enterText(
        find.byKey(const ValueKey('daybook-task-notes')),
        'Use the College Avenue drop box',
      );
      await tester.tap(find.byKey(const ValueKey('daybook-task-has-time')));
      await tester.enterText(
        find.byKey(const ValueKey('daybook-task-place-saved-name')),
        'Alexander Library',
      );
      await tester.enterText(
        find.byKey(const ValueKey('daybook-task-place-routing-text')),
        '169 College Ave, New Brunswick, NJ',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('daybook-task-save')),
      );
      await tester.tap(find.byKey(const ValueKey('daybook-task-save')));
      await tester.pump();

      expect(saved, isNotNull);
      expect(saved!.title, 'Return library book');
      expect(saved!.notes, 'Use the College Avenue drop box');
      expect(saved!.dueDate, CivilDate(2026, 8, 11));
      expect(saved!.dueMinute, 17 * 60);
      expect(saved!.completed, isFalse);
      expect(saved!.place!.savedName, 'Alexander Library');
      expect(saved!.place!.routingText, '169 College Ave, New Brunswick, NJ');
    },
  );

  testWidgets(
    'Daybook rows keep time, place, and completion actions readable',
    (tester) async {
      final event = DaybookEvent(
        eventId: 'event_meeting',
        title: 'Project meeting',
        startDate: CivilDate(2026, 8, 11),
        endDate: CivilDate(2026, 8, 11),
        timeZoneId: 'America/New_York',
        allDay: false,
        startMinute: 9 * 60,
        endMinute: 10 * 60,
        createdAt: DateTime.utc(2026, 8, 11),
        updatedAt: DateTime.utc(2026, 8, 11),
      );
      final task = DaybookTask(
        taskId: 'task_book',
        title: 'Return library book',
        dueDate: CivilDate(2026, 8, 11),
        createdAt: DateTime.utc(2026, 8, 11),
        updatedAt: DateTime.utc(2026, 8, 11),
      );
      bool? completed;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                DaybookEventRow(event: event),
                DaybookTaskRow(
                  task: task,
                  onCompletedChanged: (value) => completed = value,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Project meeting'), findsOneWidget);
      expect(find.text('9:00 AM–10:00 AM'), findsOneWidget);
      expect(find.text('Return library book'), findsOneWidget);
      final toggle = find.byKey(
        const ValueKey('daybook-task-toggle-task_book'),
      );
      expect(tester.getSize(toggle).height, greaterThanOrEqualTo(44));
      await tester.tap(toggle);
      expect(completed, isTrue);
    },
  );

  testWidgets('Daybook class place edits preserve legacy-only campus fields', (
    tester,
  ) async {
    final original = CampusPlace(
      label: 'Hill Center 114',
      building: 'Hill Center',
      room: '114',
      address: '110 Frelinghuysen Rd, Piscataway, NJ',
      latitude: 40.5211,
      longitude: -74.4622,
      mapsProvider: 'google',
      placeId: 'google-hill-center',
      campusCode: 'BUSCH',
    );
    CampusPlace? savedPlace;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AddAcademicMeetingDialog(
                  schedule: AcademicSchedule.empty(),
                  selectedDay: DateTime(2026, 8, 11),
                  initialPlace: original,
                  onSave: (_, _, series) async {
                    savedPlace = series.place;
                    return true;
                  },
                ),
              ),
              child: const Text('OPEN CLASS EDITOR'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN CLASS EDITOR'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('academic-course-code')),
      'BIO 101',
    );
    await tester.enterText(
      find.byKey(const ValueKey('academic-course-title')),
      'Foundations of Biology',
    );
    await tester.enterText(
      find.byKey(const ValueKey('academic-saved-name')),
      'Life Sciences 204',
    );
    await tester.enterText(
      find.byKey(const ValueKey('academic-routing-text')),
      '123 Bevier Rd, Piscataway, NJ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('academic-building')),
      'Life Sciences',
    );
    await tester.enterText(find.byKey(const ValueKey('academic-room')), '204');
    await tester.ensureVisible(find.text('KEEP THIS CLASS'));
    await tester.pump();
    await tester.tap(find.text('KEEP THIS CLASS'));
    await tester.pump();

    expect(savedPlace, isNotNull);
    expect(savedPlace!.label, 'Life Sciences 204');
    expect(savedPlace!.address, '123 Bevier Rd, Piscataway, NJ');
    expect(savedPlace!.building, 'Life Sciences');
    expect(savedPlace!.room, '204');
    expect(savedPlace!.latitude, original.latitude);
    expect(savedPlace!.longitude, original.longitude);
    expect(savedPlace!.mapsProvider, original.mapsProvider);
    expect(savedPlace!.placeId, original.placeId);
    expect(savedPlace!.campusCode, original.campusCode);
  });

  testWidgets('Plans shows Now, room, time, and the stable notebook doorway', (
    tester,
  ) async {
    final schedule = _scheduleFixture();
    final repository = InMemoryAcademicScheduleRepository(schedule);
    final handoff = _RecordingHandoff();
    await _pumpCalendar(tester, repository: repository, handoff: handoff);

    expect(find.text('DAYBOOK'), findsOneWidget);
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
    expect(handoff.intents.single.courseCode, 'ECE 345');
    expect(handoff.intents.single.courseTitle, 'Linear Systems');
    expect(handoff.intents.single.occurrenceDate, '2026-08-11');
    expect(handoff.intents.single.startMinute, 10 * 60 + 20);
    expect(handoff.intents.single.endMinute, 11 * 60 + 40);
    expect(handoff.intents.single.meetingKind, 'lecture');
    expect(handoff.intents.single.place, contains('Hill Center'));
    expect(handoff.intents.single.courseColorValue, 0xFF8AAFC6);
  });

  testWidgets('Month summary, Week, 3-day, and Day read the same schedule', (
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
      find.byKey(const ValueKey('academic-month-weight-2026-08-11')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('lightly scheduled day')),
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

  testWidgets('six-week month keeps an even readable folio rhythm', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(_scheduleFixture()),
      handoff: _RecordingHandoff(),
    );

    final folio = find.byKey(const ValueKey('academic-month-folio'));
    expect(folio, findsOneWidget);
    final folioBox = tester.renderObject<RenderBox>(folio);
    expect(folioBox.size.height, greaterThanOrEqualTo(450));
    expect(tester.getTopLeft(find.text('31').last).dy, greaterThan(850));
    expect(tester.takeException(), isNull);
  });

  testWidgets('today marker stays compact', (tester) async {
    final today = DateTime.utc(2026, 8, 17, 12);
    Clock.freeze(today);
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(_scheduleFixture()),
      handoff: _RecordingHandoff(),
      size: const Size(320, 568),
      textScale: 2,
      preferences: InMemoryAcademicCalendarPreferences(
        state: const AcademicCalendarViewState(
          mode: AcademicCalendarMode.month,
          selectedDate: '2026-08-17',
        ),
      ),
    );

    final marker = find.byKey(const ValueKey('month-today-marker-2026-08-17'));
    await tester.dragFrom(const Offset(160, 500), const Offset(0, -480));
    await tester.pump();
    expect(marker, findsOneWidget);
    expect(tester.getSize(marker), const Size(30, 30));
    expect(
      find.byKey(const ValueKey('month-today-label-2026-08-17')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('month-selected-wash-2026-08-17')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSemantics(find.text('17').first).label,
      contains('August 17, 2026, today'),
    );

    // August 2026 displays six rows; September displays five. Together these
    // cases place Today in each weekday column while exercising both layouts.
    for (final day in [
      DateTime.utc(2026, 8, 17, 12),
      DateTime.utc(2026, 8, 18, 12),
      DateTime.utc(2026, 8, 19, 12),
      DateTime.utc(2026, 9, 17, 12),
      DateTime.utc(2026, 9, 18, 12),
      DateTime.utc(2026, 9, 19, 12),
      DateTime.utc(2026, 9, 20, 12),
    ]) {
      Clock.freeze(day);
      final keyDate =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      await _pumpCalendar(
        tester,
        repository: InMemoryAcademicScheduleRepository(_scheduleFixture()),
        handoff: _RecordingHandoff(),
        calendarKey: ValueKey(keyDate),
        size: const Size(320, 568),
        textScale: 2,
        preferences: InMemoryAcademicCalendarPreferences(
          state: AcademicCalendarViewState(
            mode: AcademicCalendarMode.month,
            selectedDate: keyDate,
          ),
        ),
      );
      await tester.dragFrom(const Offset(160, 500), const Offset(0, -480));
      await tester.pump();
      expect(
        find.byKey(ValueKey('month-today-marker-$keyDate')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('today deadline stays below the compact marker', (tester) async {
    Clock.freeze(DateTime.utc(2026, 8, 17, 12));
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(_scheduleFixture()),
      handoff: _RecordingHandoff(),
      quests: [
        Quest(
          title: 'Submit the project brief',
          stat: Stat.foc,
          difficulty: 5,
          schedule: QuestSchedule.once,
          dueDate: DateTime(2026, 8, 17),
          timerMinutes: 240,
        ),
      ],
      size: const Size(320, 568),
      textScale: 2,
      preferences: InMemoryAcademicCalendarPreferences(
        state: const AcademicCalendarViewState(
          mode: AcademicCalendarMode.month,
          selectedDate: '2026-08-17',
        ),
      ),
    );

    await tester.dragFrom(const Offset(160, 500), const Offset(0, -480));
    await tester.pump();
    final marker = find.byKey(const ValueKey('month-today-marker-2026-08-17'));
    final wash = find.byKey(const ValueKey('month-selected-wash-2026-08-17'));
    final weight = find.byKey(
      const ValueKey('academic-month-weight-2026-08-17'),
    );
    final deadline = find.byKey(
      const ValueKey('academic-month-deadline-2026-08-17'),
    );

    expect(marker, findsOneWidget);
    expect(weight, findsOneWidget);
    expect(deadline, findsOneWidget);
    expect(tester.getSize(weight), const Size(9, 13));
    final markerRect = tester.getRect(marker);
    final washRect = tester.getRect(wash);
    final weightRect = tester.getRect(weight);
    final deadlineRect = tester.getRect(deadline);
    expect(weightRect.top, greaterThanOrEqualTo(markerRect.bottom));
    expect(weightRect.bottom, lessThanOrEqualTo(washRect.bottom));
    expect(deadlineRect.top, greaterThanOrEqualTo(markerRect.bottom));
    expect(deadlineRect.bottom, lessThanOrEqualTo(washRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('month day weight compresses scheduled time into three heights', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(
        _scheduleFixtureWithDayWeights(),
      ),
      handoff: _RecordingHandoff(),
    );

    final light = tester.getSize(
      find.byKey(const ValueKey('academic-month-weight-2026-08-11')),
    );
    final moderate = tester.getSize(
      find.byKey(const ValueKey('academic-month-weight-2026-08-12')),
    );
    final full = tester.getSize(
      find.byKey(const ValueKey('academic-month-weight-2026-08-13')),
    );

    // The outer mark keeps a stable 13px hit-free slot; the visible brass tick is
    // the only nested Container with one of the encoded workload heights.
    double visibleTickHeight(Finder mark) {
      final heights = <double>[];
      for (final element
          in find
              .descendant(of: mark, matching: find.byType(Container))
              .evaluate()) {
        final box = element.renderObject! as RenderBox;
        if (box.hasSize && box.size.width == 3) heights.add(box.size.height);
      }
      return heights.single;
    }

    expect(light, const Size(9, 13));
    expect(moderate, const Size(9, 13));
    expect(full, const Size(9, 13));
    expect(
      visibleTickHeight(
        find.byKey(const ValueKey('academic-month-weight-2026-08-11')),
      ),
      6,
    );
    expect(
      visibleTickHeight(
        find.byKey(const ValueKey('academic-month-weight-2026-08-12')),
      ),
      8,
    );
    expect(
      visibleTickHeight(
        find.byKey(const ValueKey('academic-month-weight-2026-08-13')),
      ),
      10,
    );
  });

  testWidgets('completed plan keeps day weight but clears its deadline', (
    tester,
  ) async {
    final cancelled = _scheduleFixture().cancelOccurrence(
      occurrenceKey: 'occurrence_ece_345_aug_11',
      updatedAt: DateTime.utc(2026, 8, 11, 14),
    );
    final completedPlan = Quest(
      title: 'Finished plan',
      stat: Stat.foc,
      difficulty: 4,
      schedule: QuestSchedule.once,
      dueDate: DateTime(2026, 8, 11),
      lastDoneDay: '2026-08-11',
    );
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(cancelled),
      handoff: _RecordingHandoff(),
      quests: [completedPlan],
    );

    expect(
      find.byKey(const ValueKey('academic-month-weight-2026-08-11')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('academic-month-deadline-2026-08-11')),
      findsNothing,
    );
  });

  testWidgets('cancelled class does not make its day look busy', (
    tester,
  ) async {
    final cancelled = _scheduleFixture().cancelOccurrence(
      occurrenceKey: 'occurrence_ece_345_aug_11',
      updatedAt: DateTime.utc(2026, 8, 11, 14),
    );
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(cancelled),
      handoff: _RecordingHandoff(),
    );

    expect(
      find.byKey(const ValueKey('academic-month-weight-2026-08-11')),
      findsNothing,
    );
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
    await tester.tap(find.byKey(const ValueKey('academic-add-choice-class')));
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

  testWidgets('Add assignment keeps course work in the academic daybook', (
    tester,
  ) async {
    final repository = InMemoryAcademicScheduleRepository(_scheduleFixture());
    await _pumpCalendar(
      tester,
      repository: repository,
      handoff: _RecordingHandoff(),
    );

    await tester.tap(find.byKey(const ValueKey('academic-add-class')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(
      find.byKey(const ValueKey('academic-add-choice-assignment')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull, reason: 'work dialog layout');

    expect(find.byType(AddAcademicWorkDialog), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('academic-work-title')),
      'Problem set 3',
    );
    await tester.enterText(
      find.byKey(const ValueKey('academic-work-details')),
      'Problems 1–10',
    );
    final save = find.byKey(const ValueKey('academic-work-save'));
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull, reason: 'month layout after save');

    expect(repository.schedule.workItems, hasLength(1));
    final item = repository.schedule.workItems.single;
    expect(item.kind, AcademicWorkKind.assignment);
    expect(item.title, 'Problem set 3');
    expect(item.courseId, repository.schedule.courses.single.courseId);
    expect(item.dueDate, CivilDate(2026, 8, 11));
    expect(item.dueMinute, 23 * 60 + 59);
    expect(
      find.byKey(const ValueKey('academic-month-weight-2026-08-11')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('academic-month-deadline-2026-08-11')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('academic-mode-day')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull, reason: 'day layout');
    expect(
      find.byKey(ValueKey('academic-work-${item.workId}')),
      findsOneWidget,
    );

    final toggle = find.byKey(ValueKey('academic-work-toggle-${item.workId}'));
    await tester.ensureVisible(toggle);
    await tester.pump();
    await tester.tap(toggle);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'completed layout');

    expect(repository.schedule.workItems.single.completed, isTrue);
    expect(repository.saveCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('study planner previews and keeps open blocks around class', (
    tester,
  ) async {
    final repository = InMemoryAcademicScheduleRepository(
      _scheduleFixtureWithFutureWork(),
    );
    await _pumpCalendar(
      tester,
      repository: repository,
      handoff: _RecordingHandoff(),
      preferences: InMemoryAcademicCalendarPreferences(
        state: const AcademicCalendarViewState(
          mode: AcademicCalendarMode.day,
          selectedDate: '2026-08-14',
        ),
      ),
    );

    final plan = find.byKey(
      const ValueKey('academic-plan-study-work_problem_set'),
    );
    await tester.ensureVisible(plan);
    await tester.pump();
    await tester.tap(plan);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(AcademicStudyPlannerDialog), findsOneWidget);
    expect(
      find.byKey(const ValueKey('academic-study-suggestion-preview')),
      findsOneWidget,
    );
    expect(find.textContaining('OPEN BLOCKS FOUND'), findsOneWidget);
    expect(
      find.text('Nothing is added until you keep this plan.'),
      findsOneWidget,
    );

    final save = find.byKey(const ValueKey('academic-study-plan-save'));
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 350));

    expect(repository.schedule.studyPlans, hasLength(1));
    expect(repository.schedule.studyBlocks, isNotEmpty);
    expect(
      repository.schedule.studyBlocks.any(
        (block) =>
            block.date == CivilDate(2026, 8, 11) &&
            block.startMinute < 11 * 60 + 50 &&
            block.endMinute > 10 * 60 + 10,
      ),
      isFalse,
      reason: 'class plus ten-minute transition buffer stays reserved',
    );
    expect(find.byType(AcademicStudyPlannerDialog), findsNothing);
    expect(repository.saveCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'one class cancels and restores while open study blocks automatically refit',
    (tester) async {
      final repository = InMemoryAcademicScheduleRepository(
        _scheduleFixtureWithStudyBlock(),
      );
      await _pumpCalendar(
        tester,
        repository: repository,
        handoff: _RecordingHandoff(),
        preferences: InMemoryAcademicCalendarPreferences(
          state: const AcademicCalendarViewState(
            mode: AcademicCalendarMode.day,
            selectedDate: '2026-08-11',
          ),
        ),
      );

      const occurrenceKey = 'occurrence_ece_345_aug_11';
      final adjust = find.byKey(
        const ValueKey('academic-adjust-occurrence-$occurrenceKey'),
      );
      await tester.ensureVisible(adjust);
      await tester.pump();
      await tester.tap(adjust);
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(AcademicOccurrenceAdjustDialog), findsOneWidget);
      expect(find.text('ADJUST THIS CLASS'), findsOneWidget);
      expect(
        find.text(
          'Only this class changes; the weekly class stays intact. Open study blocks will refit, while completed study stays put.',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('academic-occurrence-cancel')),
      );
      await tester.pump(const Duration(milliseconds: 350));

      final cancelled = repository.schedule.occurrenceByKey(occurrenceKey)!;
      expect(cancelled.state, OccurrenceState.cancelled);
      expect(cancelled.userAdjusted, isTrue);
      expect(
        repository.schedule.studyBlocks.any(
          (block) => block.studyBlockId == 'study_problem_set_1',
        ),
        isFalse,
        reason: 'the former open block is regenerated instead of left stale',
      );
      expect(repository.saveCount, 1);

      final adjustCancelled = find.byKey(
        const ValueKey('academic-adjust-occurrence-$occurrenceKey'),
      );
      await tester.ensureVisible(adjustCancelled);
      await tester.tap(adjustCancelled);
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.byKey(const ValueKey('academic-occurrence-restore')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('academic-occurrence-restore')),
      );
      await tester.pump(const Duration(milliseconds: 350));

      final restored = repository.schedule.occurrenceByKey(occurrenceKey)!;
      expect(restored.state, OccurrenceState.scheduled);
      expect(restored.userAdjusted, isFalse);
      expect(restored.date, CivilDate(2026, 8, 11));
      expect(repository.saveCount, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('move form edits only one class and keeps the series time', (
    tester,
  ) async {
    final repository = InMemoryAcademicScheduleRepository(_scheduleFixture());
    await _pumpCalendar(
      tester,
      repository: repository,
      handoff: _RecordingHandoff(),
      preferences: InMemoryAcademicCalendarPreferences(
        state: const AcademicCalendarViewState(
          mode: AcademicCalendarMode.day,
          selectedDate: '2026-08-11',
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey('academic-adjust-occurrence-occurrence_ece_345_aug_11'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('academic-occurrence-move')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('academic-occurrence-move')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('academic-occurrence-move-save')),
      findsOneWidget,
    );
    await tester.tap(find.text('August 11, 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('academic-occurrence-move-save')),
    );
    await tester.pump(const Duration(milliseconds: 350));

    final occurrence = repository.schedule.occurrenceByKey(
      'occurrence_ece_345_aug_11',
    )!;
    expect(occurrence.state, OccurrenceState.moved);
    expect(occurrence.userAdjusted, isTrue);
    expect(occurrence.originalDate, CivilDate(2026, 8, 11));
    expect(occurrence.date, CivilDate(2026, 8, 12));
    expect(
      repository.schedule.meetingSeries.single.localStartMinute,
      10 * 60 + 20,
    );
    expect(repository.saveCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'kept study block appears on its day and completes independently',
    (tester) async {
      final repository = InMemoryAcademicScheduleRepository(
        _scheduleFixtureWithStudyBlock(),
      );
      await _pumpCalendar(
        tester,
        repository: repository,
        handoff: _RecordingHandoff(),
        preferences: InMemoryAcademicCalendarPreferences(
          state: const AcademicCalendarViewState(
            mode: AcademicCalendarMode.day,
            selectedDate: '2026-08-11',
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('academic-study-block-study_problem_set_1')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('ECE 345 · STUDY'), findsOneWidget);
      expect(find.text('Problem set 4'), findsWidgets);
      expect(find.text('3:00 PM–3:45 PM · 45 min'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('academic-study-toggle-study_problem_set_1')),
      );
      await tester.pump(const Duration(milliseconds: 250));

      expect(repository.schedule.studyBlocks.single.completed, isTrue);
      expect(
        repository.schedule.workItems
            .singleWhere((item) => item.workId == 'work_problem_set')
            .completed,
        isFalse,
      );
      expect(repository.saveCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('overlapping classes are gently surfaced and previewed', (
    tester,
  ) async {
    final schedule = _scheduleFixtureWithOverlap();
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(schedule),
      handoff: _RecordingHandoff(),
    );

    await tester.tap(find.byKey(const ValueKey('academic-mode-day')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('academic-conflicts-2026-08-11')),
      findsOneWidget,
    );
    expect(find.text('TWO CLASSES SHARE THIS TIME'), findsOneWidget);
    expect(find.text('OVERLAP'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('academic-add-class')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('academic-add-choice-class')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.byKey(const ValueKey('academic-class-overlap-preview')),
      findsOneWidget,
    );
    expect(find.textContaining('It can still be kept'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tight class transition can be resolved without moving class', (
    tester,
  ) async {
    final repository = InMemoryAcademicScheduleRepository(
      _scheduleFixtureWithTightTransition(),
    );
    await _pumpCalendar(
      tester,
      repository: repository,
      handoff: _RecordingHandoff(),
    );

    await tester.tap(find.byKey(const ValueKey('academic-mode-day')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('academic-transitions-2026-08-11')),
      findsOneWidget,
    );
    expect(find.text('A TIGHT TURNAROUND'), findsOneWidget);
    expect(find.text('TIGHT TURNAROUND'), findsNWidgets(2));
    expect(find.text('OVERLAP'), findsNothing);

    const chemOccurrenceKey = 'occurrence_chem_161_aug_11';
    final bufferMenu = find.byKey(
      const ValueKey('academic-buffer-menu-$chemOccurrenceKey'),
    );
    await tester.ensureVisible(bufferMenu);
    await tester.pump();
    await tester.tap(bufferMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 min buffer'));
    await tester.pumpAndSettle();

    final chemSeries = repository.schedule.meetingSeriesById(
      'series_chem_161_lab',
    );
    expect(chemSeries?.transitionBufferMinutes, 5);
    expect(chemSeries?.localStartMinute, 11 * 60 + 45);
    expect(
      repository.schedule.transitionPressuresOn(CivilDate(2026, 8, 11)),
      isEmpty,
    );
    expect(
      find.byKey(const ValueKey('academic-transitions-2026-08-11')),
      findsNothing,
    );
    expect(repository.saveCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add class previews a tight transition and exposes buffers', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(
        _scheduleFixtureBeforeDefaultClass(),
      ),
      handoff: _RecordingHandoff(),
    );

    await tester.tap(find.byKey(const ValueKey('academic-add-class')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('academic-add-choice-class')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('academic-class-transition-preview')),
      findsOneWidget,
    );
    expect(find.text('TIME AROUND CLASS'), findsOneWidget);
    expect(find.textContaining('Class times stay unchanged'), findsOneWidget);
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

  testWidgets('tight-transition actions reflow at 200% text', (tester) async {
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(
        _scheduleFixtureWithTightTransition(),
      ),
      handoff: _RecordingHandoff(),
      size: const Size(320, 568),
      textScale: 2,
    );

    await tester.tap(find.byKey(const ValueKey('academic-mode-day')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.scrollUntilVisible(
      find.byKey(
        const ValueKey('academic-buffer-menu-occurrence_chem_161_aug_11'),
      ),
      120,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.byKey(
        const ValueKey('academic-buffer-menu-occurrence_chem_161_aug_11'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('study planner reflows on a narrow phone at 200% text', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(
        _scheduleFixtureWithFutureWork(),
      ),
      handoff: _RecordingHandoff(),
      size: const Size(320, 568),
      textScale: 2,
      preferences: InMemoryAcademicCalendarPreferences(
        state: const AcademicCalendarViewState(
          mode: AcademicCalendarMode.day,
          selectedDate: '2026-08-14',
        ),
      ),
    );

    final plan = find.byKey(
      const ValueKey('academic-plan-study-work_problem_set'),
    );
    await tester.scrollUntilVisible(
      plan,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(plan);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('academic-study-plan-save')),
      120,
      scrollable: find.byType(Scrollable).last,
    );

    expect(
      find.byKey(const ValueKey('academic-study-plan-save')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('class adjustment reflows on a narrow phone at 200% text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.binding.setSurfaceSize(null);
    });
    final schedule = _scheduleFixtureWithStudyBlock();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AcademicOccurrenceAdjustDialog(
            schedule: schedule,
            occurrence: schedule.occurrences.single,
            onMove: (_, _, _, _) async => true,
            onCancel: (_) async => true,
            onRestore: (_) async => true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('academic-occurrence-move')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('academic-occurrence-move')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('academic-occurrence-move-save')),
      120,
      scrollable: find.byType(Scrollable).last,
    );

    expect(
      find.byKey(const ValueKey('academic-occurrence-move-save')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpDaybookWidget(
  WidgetTester tester,
  Widget child, {
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
  await tester.pumpWidget(
    MaterialApp(debugShowCheckedModeBanner: false, home: Scaffold(body: child)),
  );
  await tester.pump();
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required InMemoryAcademicScheduleRepository repository,
  required NotebookHandoff handoff,
  AcademicCalendarPreferences? preferences,
  Key? calendarKey,
  List<Quest> quests = const [],
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
          key: calendarKey,
          state: state,
          quests: quests,
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

AcademicSchedule _scheduleFixture({
  int startMinute = 10 * 60 + 20,
  int endMinute = 11 * 60 + 40,
  int transitionBufferMinutes = 10,
}) {
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
    localStartMinute: startMinute,
    localEndMinute: endMinute,
    transitionBufferMinutes: transitionBufferMinutes,
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

AcademicSchedule _scheduleFixtureWithDayWeights() {
  var schedule = _scheduleFixture(startMinute: 10 * 60, endMinute: 11 * 60);
  final term = schedule.terms.single;

  AcademicSchedule addDay({
    required String id,
    required int weekday,
    required int startMinute,
    required int endMinute,
  }) {
    final course = AcademicCourse(
      courseId: 'course_$id',
      termId: term.termId,
      code: id.toUpperCase(),
      title: '$id workload fixture',
      colorValue: 0xFF8AAFC6,
      colorLabel: 'Dusk blue',
    );
    return schedule.putMeeting(
      term: term,
      course: course,
      series: MeetingSeries(
        meetingSeriesId: 'series_$id',
        courseId: course.courseId,
        kind: MeetingKind.lecture,
        weekdays: {weekday},
        localStartMinute: startMinute,
        localEndMinute: endMinute,
        firstDate: term.startDate,
        lastDate: term.endDate,
        timeZoneId: term.timeZoneId,
        place: CampusPlace(label: 'Library'),
        updatedAt: DateTime.utc(2026, 8, 11),
      ),
      updatedAt: DateTime.utc(2026, 8, 11),
      idFactory: (_) => 'occurrence_$id',
    );
  }

  schedule = addDay(
    id: 'moderate',
    weekday: DateTime.wednesday,
    startMinute: 10 * 60,
    endMinute: 13 * 60,
  );
  schedule = addDay(
    id: 'full',
    weekday: DateTime.thursday,
    startMinute: 9 * 60,
    endMinute: 13 * 60,
  );
  return schedule;
}

AcademicSchedule _scheduleFixtureWithOverlap() {
  final schedule = _scheduleFixture();
  final term = schedule.terms.single;
  const courseId = 'course_chem_161';
  final course = AcademicCourse(
    courseId: courseId,
    termId: term.termId,
    code: 'CHEM 161',
    title: 'General Chemistry',
    colorValue: 0xFF9CBC88,
    colorLabel: 'Moss',
  );
  return schedule.putMeeting(
    term: term,
    course: course,
    series: MeetingSeries(
      meetingSeriesId: 'series_chem_161_lab',
      courseId: courseId,
      kind: MeetingKind.lab,
      weekdays: const {DateTime.tuesday},
      localStartMinute: 11 * 60,
      localEndMinute: 12 * 60 + 30,
      firstDate: term.startDate,
      lastDate: term.endDate,
      timeZoneId: term.timeZoneId,
      place: CampusPlace(label: 'Wright Labs B12'),
      updatedAt: DateTime.utc(2026, 8, 11),
    ),
    updatedAt: DateTime.utc(2026, 8, 11),
    idFactory: (_) => 'occurrence_chem_161_aug_11',
  );
}

AcademicSchedule _scheduleFixtureWithTightTransition() {
  final schedule = _scheduleFixture(transitionBufferMinutes: 5);
  final term = schedule.terms.single;
  const courseId = 'course_chem_161';
  final course = AcademicCourse(
    courseId: courseId,
    termId: term.termId,
    code: 'CHEM 161',
    title: 'General Chemistry',
    colorValue: 0xFF9CBC88,
    colorLabel: 'Moss',
  );
  return schedule.putMeeting(
    term: term,
    course: course,
    series: MeetingSeries(
      meetingSeriesId: 'series_chem_161_lab',
      courseId: courseId,
      kind: MeetingKind.lab,
      weekdays: const {DateTime.tuesday},
      localStartMinute: 11 * 60 + 45,
      localEndMinute: 13 * 60,
      transitionBufferMinutes: 10,
      firstDate: term.startDate,
      lastDate: term.endDate,
      timeZoneId: term.timeZoneId,
      place: CampusPlace(label: 'Wright Labs B12'),
      updatedAt: DateTime.utc(2026, 8, 11),
    ),
    updatedAt: DateTime.utc(2026, 8, 11),
    idFactory: (_) => 'occurrence_chem_161_aug_11',
  );
}

AcademicSchedule _scheduleFixtureBeforeDefaultClass() => _scheduleFixture(
  startMinute: 8 * 60 + 35,
  endMinute: 9 * 60 + 55,
  transitionBufferMinutes: 10,
);

AcademicSchedule _scheduleFixtureWithFutureWork() =>
    _scheduleFixture().putWorkItem(
      AcademicWorkItem(
        workId: 'work_problem_set',
        courseId: 'course_ece_345',
        kind: AcademicWorkKind.assignment,
        title: 'Problem set 4',
        dueDate: CivilDate(2026, 8, 14),
        dueMinute: 17 * 60,
        details: 'Convolution problems 1–10',
        updatedAt: DateTime.utc(2026, 8, 11),
      ),
    );

AcademicSchedule _scheduleFixtureWithStudyBlock() {
  final schedule = _scheduleFixtureWithFutureWork();
  return schedule.putStudyPlan(
    plan: AcademicStudyPlan(
      workId: 'work_problem_set',
      totalMinutes: 120,
      sessionMinutes: 45,
      dailyStartMinute: 9 * 60,
      dailyEndMinute: 20 * 60,
      updatedAt: DateTime.utc(2026, 8, 11),
    ),
    blocks: [
      AcademicStudyBlock(
        studyBlockId: 'study_problem_set_1',
        workId: 'work_problem_set',
        date: CivilDate(2026, 8, 11),
        startMinute: 15 * 60,
        endMinute: 15 * 60 + 45,
        updatedAt: DateTime.utc(2026, 8, 11),
      ),
    ],
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
