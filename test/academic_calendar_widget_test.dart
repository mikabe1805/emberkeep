import 'dart:async';
import 'dart:ui' as ui show ImageByteFormat;
import 'dart:ui' show SemanticsAction, Tristate;

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
import 'package:emberkeep/daybook/services/place_search_access.dart'
    hide PlaceSearchUnavailable;
import 'package:emberkeep/daybook/services/place_search_authorization.dart';
import 'package:emberkeep/daybook/services/place_search_controller.dart';
import 'package:emberkeep/daybook/services/place_search_service.dart';
import 'package:emberkeep/daybook/widgets/daybook_add_choice_dialog.dart';
import 'package:emberkeep/daybook/widgets/daybook_event_actions.dart';
import 'package:emberkeep/daybook/widgets/daybook_event_editor.dart';
import 'package:emberkeep/daybook/widgets/daybook_place_fields.dart';
import 'package:emberkeep/daybook/widgets/daybook_rows.dart';
import 'package:emberkeep/daybook/widgets/daybook_task_editor.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/calendar.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderParagraph, RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _capturePlaceSearch = bool.fromEnvironment('CAPTURE_PLACE_SEARCH');
const _daybookWidgetCaptureKey = ValueKey('daybook-widget-capture');

void main() {
  setUpAll(() async {
    if (!_capturePlaceSearch) return;
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
    for (final description in const [
      'Something happening at a time or across a day',
      'Something to finish by a date or time',
      'A lecture, lab, meeting, or recurring class',
      'Course work with a due date and time',
      'A test, midterm, or final on your calendar',
    ]) {
      expect(find.text(description), findsOneWidget);
    }

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
    'place search factory is threaded through CalendarPage event task and class paths',
    (tester) async {
      final factory = _TestPlaceSearchFactory(
        service: _RecordingPlaceSearchService(),
      );
      await _pumpCalendar(
        tester,
        repository: InMemoryAcademicScheduleRepository(),
        handoff: _RecordingHandoff(),
        placeSearchFactory: factory,
      );

      Future<void> expectEditorUsesSearch(String targetKey) async {
        await tester.tap(
          find.bySemanticsLabel(
            'Add an event, task, class, assignment, or exam',
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(targetKey)));
        await tester.pumpAndSettle();
        expect(find.text('SEARCH PLACES WITH GOOGLE'), findsOneWidget);
        await tester.tap(find.byTooltip('Close').last);
        await tester.pumpAndSettle();
      }

      await expectEditorUsesSearch('daybook-add-choice-event');
      await expectEditorUsesSearch('daybook-add-choice-task');
      await expectEditorUsesSearch('academic-add-choice-class');
    },
  );

  testWidgets(
    'Daybook event editor validates title and keeps failed saves open',
    (tester) async {
      var saveCalls = 0;
      await _pumpDaybookWidget(
        tester,
        DaybookEventEditor(
          selectedDay: CivilDate(2026, 8, 11),
          timeZoneIdProvider: () async => 'Etc/UTC',
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
        timeZoneIdProvider: () async => 'Etc/UTC',
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

  testWidgets(
    'place search stays dormant while manual SAVED NAME is being typed',
    (tester) async {
      final service = _RecordingPlaceSearchService();
      final factory = _TestPlaceSearchFactory(service: service);
      await _pumpDaybookWidget(
        tester,
        DaybookEventEditor(
          selectedDay: CivilDate(2026, 8, 11),
          placeSearchFactory: factory,
          timeZoneIdProvider: () async => 'Etc/UTC',
          onSave: (_) async => true,
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('daybook-event-place-saved-name')),
        'Alexander Library',
      );
      await tester.pump(const Duration(seconds: 1));

      expect(service.autocompleteQueries, isEmpty);
      expect(factory.controllerCreateCalls, 0);
      expect(
        find.byKey(const ValueKey('daybook-event-place-search-query')),
        findsNothing,
      );
      expect(find.text('SEARCH PLACES WITH GOOGLE'), findsOneWidget);
    },
  );

  testWidgets(
    'place search disclosure decline performs no auth and manual event save stays available',
    (tester) async {
      DaybookEvent? saved;
      final service = _RecordingPlaceSearchService();
      final identity = _TestPlaceSearchIdentity();
      final factory = _TestPlaceSearchFactory(
        service: service,
        identity: identity,
      );
      await _pumpDaybookWidget(
        tester,
        DaybookEventEditor(
          selectedDay: CivilDate(2026, 8, 11),
          placeSearchFactory: factory,
          timeZoneIdProvider: () async => 'Etc/UTC',
          onSave: (event) async {
            saved = event;
            return true;
          },
        ),
      );

      await tester.tap(find.text('SEARCH PLACES WITH GOOGLE'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Through Room of Days, Google receives the query you type, a temporary search session token, and the app display language.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'If you choose a result, Room of Days sends Google its place ID once for confirmation.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('sends only the query'), findsNothing);
      expect(
        find.text('Your current device location is not requested or used.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Room of Days creates or reuses a private Firebase identity for authenticated service access and abuse controls.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Room of Days retains a private random install identifier for abuse and cost limits; it is not a hardware or device identifier.',
        ),
        findsOneWidget,
      );
      expect(find.text('USE PLACE SEARCH'), findsOneWidget);

      await tester.tap(find.text('KEEP TYPING MANUALLY'));
      await tester.pumpAndSettle();
      expect(identity.ensureCoreCalls, 0);
      expect(identity.signInCalls, 0);
      expect(factory.appCheck.activateCalls, 0);
      expect(factory.controllerCreateCalls, 0);
      expect(service.autocompleteQueries, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('daybook-event-title')),
        'Library hours',
      );
      await tester.tap(find.byKey(const ValueKey('daybook-event-save')));
      await tester.pump();
      expect(saved?.title, 'Library hours');
    },
  );

  testWidgets(
    'place search waits for three characters and 300 ms then shows attributed 44px suggestions',
    (tester) async {
      final service = _RecordingPlaceSearchService();
      final factory = _TestPlaceSearchFactory(service: service);
      await _pumpDaybookWidget(
        tester,
        DaybookEventEditor(
          selectedDay: CivilDate(2026, 8, 11),
          placeSearchFactory: factory,
          timeZoneIdProvider: () async => 'Etc/UTC',
          onSave: (_) async => true,
        ),
        locale: const Locale('en', 'GB'),
      );
      await _acceptPlaceSearch(tester);

      final search = find.byKey(
        const ValueKey('daybook-event-place-search-query'),
      );
      await tester.enterText(search, 'ab');
      await tester.pump(const Duration(seconds: 1));
      expect(service.autocompleteQueries, isEmpty);

      await tester.enterText(search, 'abc');
      await tester.pump(const Duration(milliseconds: 299));
      expect(service.autocompleteQueries, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(service.autocompleteQueries, ['abc']);
      expect(factory.locales, ['en-GB']);
      expect(find.text('Provider abc'), findsOneWidget);
      expect(find.text('Google Maps'), findsOneWidget);
      expect(
        tester
            .getSize(
              find.byKey(
                const ValueKey('daybook-event-place-search-suggestion-0'),
              ),
            )
            .height,
        greaterThanOrEqualTo(44),
      );
    },
  );

  testWidgets('place search editor requires three non-whitespace characters', (
    tester,
  ) async {
    final service = _RecordingPlaceSearchService();
    final factory = _TestPlaceSearchFactory(service: service);
    await _pumpDaybookWidget(
      tester,
      DaybookTaskEditor(
        selectedDay: CivilDate(2026, 8, 11),
        placeSearchFactory: factory,
        onSave: (_) async => true,
      ),
    );
    await _acceptPlaceSearch(tester);

    final search = find.byKey(
      const ValueKey('daybook-task-place-search-query'),
    );
    await tester.enterText(search, 'a b');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(service.autocompleteQueries, isEmpty);
    expect(find.text('Provider a b'), findsNothing);

    await tester.enterText(search, 'a b c');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(service.autocompleteQueries, ['a b c']);
    expect(find.text('Provider a b c'), findsOneWidget);
  });

  testWidgets(
    'place search selection saves the exact typed query and label edits retain its provider ID',
    (tester) async {
      DaybookEvent? saved;
      final service = _RecordingPlaceSearchService();
      final factory = _TestPlaceSearchFactory(service: service);
      await _pumpDaybookWidget(
        tester,
        DaybookEventEditor(
          selectedDay: CivilDate(2026, 8, 11),
          placeSearchFactory: factory,
          timeZoneIdProvider: () async => 'Etc/UTC',
          onSave: (event) async {
            saved = event;
            return true;
          },
        ),
      );
      await _acceptPlaceSearch(tester);

      await tester.enterText(
        find.byKey(const ValueKey('daybook-event-place-search-query')),
        '  Alex Library  ',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('daybook-event-place-search-suggestion-0')),
      );
      await tester.pumpAndSettle();

      final savedName = tester.widget<TextField>(
        find.byKey(const ValueKey('daybook-event-place-saved-name')),
      );
      final routing = tester.widget<TextField>(
        find.byKey(const ValueKey('daybook-event-place-routing-text')),
      );
      expect(savedName.controller!.text, '  Alex Library  ');
      expect(routing.controller!.text, isEmpty);
      expect(find.text('Confirmed Provider Alex Library'), findsOneWidget);
      expect(find.text('Google Maps'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('daybook-event-place-saved-name')),
        'My study library',
      );
      await tester.enterText(
        find.byKey(const ValueKey('daybook-event-title')),
        'Study block',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('daybook-event-save')),
      );
      await tester.tap(find.byKey(const ValueKey('daybook-event-save')));
      await tester.pump();

      expect(saved?.place?.savedName, 'My study library');
      expect(saved?.place?.routingText, isNull);
      expect(saved?.place?.provider, DaybookPlaceProvider.google);
      expect(saved?.place?.providerPlaceId, 'place-Alex-Library');
    },
  );

  testWidgets(
    'place search provider secondary copy meets 4.5 to 1 contrast in suggestions and selections',
    (tester) async {
      final factory = _TestPlaceSearchFactory(
        service: _RecordingPlaceSearchService(),
      );
      await _pumpDaybookWidget(
        tester,
        DaybookEventEditor(
          selectedDay: CivilDate(2026, 8, 11),
          placeSearchFactory: factory,
          timeZoneIdProvider: () async => 'Etc/UTC',
          onSave: (_) async => true,
        ),
      );
      await _acceptPlaceSearch(tester);
      await tester.enterText(
        find.byKey(const ValueKey('daybook-event-place-search-query')),
        'Alexander Library',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      final suggestion = find.byKey(
        const ValueKey('daybook-event-place-search-suggestion-0'),
      );
      expect(
        await _renderedPlaceSearchSecondaryContrast(
          tester,
          card: suggestion,
          secondaryText: 'Provider address for Alexander Library',
        ),
        greaterThanOrEqualTo(4.5),
      );

      await tester.tap(suggestion);
      await tester.pumpAndSettle();
      expect(
        await _renderedPlaceSearchSecondaryContrast(
          tester,
          card: find.byKey(
            const ValueKey('daybook-event-place-search-selection'),
          ),
          secondaryText: 'Provider address for Alexander Library',
        ),
        greaterThanOrEqualTo(4.5),
      );
    },
  );

  testWidgets(
    'place search explicit manual replacement clears task provider content and ID',
    (tester) async {
      DaybookTask? saved;
      final service = _RecordingPlaceSearchService();
      final factory = _TestPlaceSearchFactory(service: service);
      await _pumpDaybookWidget(
        tester,
        DaybookTaskEditor(
          selectedDay: CivilDate(2026, 8, 11),
          placeSearchFactory: factory,
          onSave: (task) async {
            saved = task;
            return true;
          },
        ),
      );
      await _acceptPlaceSearch(tester);
      await tester.enterText(
        find.byKey(const ValueKey('daybook-task-place-search-query')),
        'Student Center',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('daybook-task-place-search-suggestion-0')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Confirmed Provider Student Center'), findsOneWidget);

      await tester.tap(find.text('USE MANUAL LOCATION INSTEAD'));
      await tester.pump();
      expect(find.text('Confirmed Provider Student Center'), findsNothing);
      expect(find.text('Google Maps'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('daybook-task-title')),
        'Pick up forms',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('daybook-task-save')),
      );
      await tester.tap(find.byKey(const ValueKey('daybook-task-save')));
      await tester.pump();

      expect(saved?.place?.savedName, 'Student Center');
      expect(saved?.place?.provider, isNull);
      expect(saved?.place?.providerPlaceId, isNull);
    },
  );

  testWidgets(
    'place search ignores stale editor results and keeps the newer provider list',
    (tester) async {
      final service = _RecordingPlaceSearchService(blockAutocomplete: true);
      final factory = _TestPlaceSearchFactory(service: service);
      await _pumpDaybookWidget(
        tester,
        DaybookEventEditor(
          selectedDay: CivilDate(2026, 8, 11),
          placeSearchFactory: factory,
          timeZoneIdProvider: () async => 'Etc/UTC',
          onSave: (_) async => true,
        ),
      );
      await _acceptPlaceSearch(tester);
      final search = find.byKey(
        const ValueKey('daybook-event-place-search-query'),
      );

      await tester.enterText(search, 'first');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(search, 'second');
      await tester.pump(const Duration(milliseconds: 300));
      service.completeAutocomplete('second');
      await tester.pump();
      expect(find.text('Provider second'), findsOneWidget);

      service.completeAutocomplete('first');
      await tester.pump();
      expect(find.text('Provider second'), findsOneWidget);
      expect(find.text('Provider first'), findsNothing);
    },
  );

  testWidgets(
    'place search failure shows the exact fallback while manual task save remains enabled',
    (tester) async {
      DaybookTask? saved;
      final service = _RecordingPlaceSearchService(failAutocomplete: true);
      final factory = _TestPlaceSearchFactory(service: service);
      await _pumpDaybookWidget(
        tester,
        DaybookTaskEditor(
          selectedDay: CivilDate(2026, 8, 11),
          placeSearchFactory: factory,
          onSave: (task) async {
            saved = task;
            return true;
          },
        ),
      );
      await _acceptPlaceSearch(tester);
      await tester.enterText(
        find.byKey(const ValueKey('daybook-task-place-search-query')),
        'Library',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(
        find.text('Search unavailable — type the location instead.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('daybook-task-title')),
        'Return book',
      );
      await tester.enterText(
        find.byKey(const ValueKey('daybook-task-place-saved-name')),
        'Alexander Library',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('daybook-task-save')),
      );
      await tester.tap(find.byKey(const ValueKey('daybook-task-save')));
      await tester.pump();
      expect(saved?.place?.savedName, 'Alexander Library');
    },
  );

  testWidgets(
    'place search access unavailability shows fallback and keeps manual event save enabled',
    (tester) async {
      DaybookEvent? saved;
      final factory = _TestPlaceSearchFactory(
        service: _RecordingPlaceSearchService(),
        appCheck: _TestPlaceSearchAppCheck(succeeds: false),
      );
      await _pumpDaybookWidget(
        tester,
        DaybookEventEditor(
          selectedDay: CivilDate(2026, 8, 11),
          placeSearchFactory: factory,
          timeZoneIdProvider: () async => 'Etc/UTC',
          onSave: (event) async {
            saved = event;
            return true;
          },
        ),
      );

      await _acceptPlaceSearch(tester);
      expect(
        find.text('Search unavailable — type the location instead.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('daybook-event-title')),
        'Study block',
      );
      await tester.enterText(
        find.byKey(const ValueKey('daybook-event-place-saved-name')),
        'My library',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('daybook-event-save')),
      );
      await tester.tap(find.byKey(const ValueKey('daybook-event-save')));
      await tester.pump();

      expect(saved?.place?.savedName, 'My library');
      expect(factory.controllerCreateCalls, 0);
    },
  );

  testWidgets(
    'place search controller replacement clears transient provider content',
    (tester) async {
      final factory = _TestPlaceSearchFactory(
        service: _RecordingPlaceSearchService(),
      );
      var controller = DaybookPlaceFieldsController();
      late StateSetter rebuild;
      await _pumpDaybookWidget(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return DaybookPlaceFields(
              controller: controller,
              keyPrefix: 'review-place',
              placeSearchFactory: factory,
            );
          },
        ),
      );
      await _acceptPlaceSearch(tester);
      await tester.enterText(
        find.byKey(const ValueKey('review-place-search-query')),
        'Alexander Library',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('review-place-search-suggestion-0')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Confirmed Provider Alexander Library'), findsOneWidget);

      rebuild(() {
        controller = DaybookPlaceFieldsController(
          initialPlace: DaybookPlace(savedName: 'Manual replacement'),
        );
      });
      await tester.pump();

      expect(find.text('Confirmed Provider Alexander Library'), findsNothing);
      expect(find.text('Google Maps'), findsNothing);
      final savedName = tester.widget<TextField>(
        find.byKey(const ValueKey('review-place-saved-name')),
      );
      expect(savedName.controller!.text, 'Manual replacement');
    },
  );

  testWidgets(
    'place search deferred access cannot activate after controller replacement',
    (tester) => _expectDeferredAccessCannotActivateReplacement(
      tester,
      replaceController: true,
    ),
  );

  testWidgets(
    'place search deferred access cannot activate after factory replacement',
    (tester) => _expectDeferredAccessCannotActivateReplacement(
      tester,
      replaceController: false,
    ),
  );

  testWidgets('place search visual consent remains complete at 430x932 and 200% text', (
    tester,
  ) async {
    final factory = _TestPlaceSearchFactory(
      service: _RecordingPlaceSearchService(),
    );
    await _pumpDaybookWidget(
      tester,
      DaybookEventEditor(
        selectedDay: CivilDate(2026, 8, 11),
        placeSearchFactory: factory,
        timeZoneIdProvider: () async => 'Etc/UTC',
        onSave: (_) async => true,
      ),
      textScale: 2,
    );
    await tester.ensureVisible(find.text('SEARCH PLACES WITH GOOGLE'));
    await tester.tap(find.text('SEARCH PLACES WITH GOOGLE'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Through Room of Days, Google receives the query you type, a temporary search session token, and the app display language.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'If you choose a result, Room of Days sends Google its place ID once for confirmation.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Your current device location is not requested or used.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Room of Days creates or reuses a private Firebase identity for authenticated service access and abuse controls.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Room of Days retains a private random install identifier for abuse and cost limits; it is not a hardware or device identifier.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.text('USE PLACE SEARCH'),
                  matching: find.byType(InkWell),
                )
                .first,
          )
          .height,
      greaterThanOrEqualTo(44),
    );
    expect(tester.takeException(), isNull);
    await _capturePlaceSearchFrame(tester, 'consent_430x932_2x');

    await tester.ensureVisible(find.text('USE PLACE SEARCH'));
    await tester.pump();
    await tester.tap(find.text('USE PLACE SEARCH'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('daybook-event-place-search-query')),
      'Alexander Library',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    final suggestion = find.byKey(
      const ValueKey('daybook-event-place-search-suggestion-0'),
    );
    await tester.ensureVisible(suggestion);
    await tester.pump();
    expect(find.text('Google Maps'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capturePlaceSearchFrame(tester, 'search_430x932_2x');
  });

  testWidgets(
    'place search visual remains scroll and keyboard reachable at 320x568 and 200% text',
    (tester) async {
      final factory = _TestPlaceSearchFactory(
        service: _RecordingPlaceSearchService(),
      );
      await _pumpDaybookWidget(
        tester,
        DaybookTaskEditor(
          selectedDay: CivilDate(2026, 8, 11),
          placeSearchFactory: factory,
          onSave: (_) async => true,
        ),
        size: const Size(320, 568),
        textScale: 2,
      );
      await tester.ensureVisible(find.text('SEARCH PLACES WITH GOOGLE'));
      await tester.tap(find.text('SEARCH PLACES WITH GOOGLE'));
      await tester.pumpAndSettle();
      expect(
        find.text('Your current device location is not requested or used.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Room of Days retains a private random install identifier for abuse and cost limits; it is not a hardware or device identifier.',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('USE PLACE SEARCH'));
      await tester.pump();
      expect(find.text('USE PLACE SEARCH').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capturePlaceSearchFrame(tester, 'consent_320x568_2x');
      await tester.tap(find.text('USE PLACE SEARCH'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('daybook-task-place-search-query')),
        'Alexander Library',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      final suggestion = find.byKey(
        const ValueKey('daybook-task-place-search-suggestion-0'),
      );
      await tester.ensureVisible(suggestion);
      await tester.pump();
      expect(suggestion.hitTestable(), findsOneWidget);
      expect(tester.getSize(suggestion).height, greaterThanOrEqualTo(44));
      expect(find.text('Google Maps'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capturePlaceSearchFrame(tester, 'search_320x568_2x_keyboard');

      final save = find.byKey(const ValueKey('daybook-task-save'));
      await tester.ensureVisible(save);
      await tester.pump();
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.getSize(save).height, greaterThanOrEqualTo(44));
      expect(tester.getRect(save).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(save).bottom, lessThanOrEqualTo(328));
      expect(tester.takeException(), isNull);
      await _capturePlaceSearchFrame(
        tester,
        'save_reachable_320x568_2x_keyboard',
      );
    },
  );

  testWidgets(
    'place search visual hardware keyboard reaches search and traps consent focus in visual order',
    (tester) async {
      final factory = _TestPlaceSearchFactory(
        service: _RecordingPlaceSearchService(),
      );
      await _pumpDaybookWidget(
        tester,
        DaybookPlaceFields(
          controller: DaybookPlaceFieldsController(),
          keyPrefix: 'focus-place',
          placeSearchFactory: factory,
        ),
        size: const Size(320, 568),
        textScale: 2,
      );

      final visualOrder = [
        find.byKey(const ValueKey('focus-place-saved-name')),
        find.byKey(const ValueKey('focus-place-routing-text')),
        find.byKey(const ValueKey('focus-place-building')),
        find.byKey(const ValueKey('focus-place-room')),
        find.byKey(const ValueKey('focus-place-search-affordance')),
      ];
      for (final target in visualOrder) {
        await _pressTab(tester);
        expect(_focusIsWithin(target), isTrue);
      }
      final searchAffordance = visualOrder.last;
      expect(searchAffordance.hitTestable(), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final useSearch = find
          .ancestor(
            of: find.text('USE PLACE SEARCH'),
            matching: find.byType(InkWell),
          )
          .first;
      final keepManual = find.widgetWithText(
        TextButton,
        'KEEP TYPING MANUALLY',
      );
      if (!_focusIsWithin(useSearch)) await _pressTab(tester);
      expect(_focusIsWithin(useSearch), isTrue);
      expect(useSearch.hitTestable(), findsOneWidget);

      await _pressTab(tester);
      expect(_focusIsWithin(keepManual), isTrue);
      expect(keepManual.hitTestable(), findsOneWidget);
      await _pressTab(tester);
      expect(_focusIsWithin(useSearch), isTrue);
      await _pressShiftTab(tester);
      expect(_focusIsWithin(keepManual), isTrue);
      expect(_focusIsWithin(searchAffordance), isFalse);
      await _capturePlaceSearchFrame(tester, 'keyboard_focus_trap_320x568_2x');
    },
  );

  testWidgets(
    'place search keyboard Enter accepts consent and activates search',
    (tester) async {
      final service = _RecordingPlaceSearchService();
      final identity = _TestPlaceSearchIdentity();
      final factory = _TestPlaceSearchFactory(
        service: service,
        identity: identity,
      );
      await _pumpDaybookWidget(
        tester,
        DaybookPlaceFields(
          controller: DaybookPlaceFieldsController(),
          keyPrefix: 'keyboard-accept-place',
          placeSearchFactory: factory,
        ),
      );
      await _openPlaceSearchConsentWithKeyboard(tester);

      final useSearch = find
          .ancestor(
            of: find.text('USE PLACE SEARCH'),
            matching: find.byType(InkWell),
          )
          .first;
      if (!_focusIsWithin(useSearch)) await _pressTab(tester);
      expect(_focusIsWithin(useSearch), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('USE PLACE SEARCH'), findsNothing);
      expect(
        find.byKey(const ValueKey('keyboard-accept-place-search-query')),
        findsOneWidget,
      );
      expect(identity.ensureCoreCalls, 1);
      expect(identity.signInCalls, 1);
      expect(factory.appCheck.activateCalls, 1);
      expect(factory.controllerCreateCalls, 1);
      expect(service.autocompleteQueries, isEmpty);
    },
  );

  testWidgets(
    'place search keyboard Enter declines consent with manual mode untouched',
    (tester) async {
      final service = _RecordingPlaceSearchService();
      final identity = _TestPlaceSearchIdentity();
      final controller = DaybookPlaceFieldsController(
        initialPlace: DaybookPlace(savedName: 'Manual library'),
      );
      final factory = _TestPlaceSearchFactory(
        service: service,
        identity: identity,
      );
      await _pumpDaybookWidget(
        tester,
        DaybookPlaceFields(
          controller: controller,
          keyPrefix: 'keyboard-decline-place',
          placeSearchFactory: factory,
        ),
      );
      await _openPlaceSearchConsentWithKeyboard(tester);

      final keepManual = find.widgetWithText(
        TextButton,
        'KEEP TYPING MANUALLY',
      );
      for (var tabs = 0; tabs < 2 && !_focusIsWithin(keepManual); tabs++) {
        await _pressTab(tester);
      }
      expect(_focusIsWithin(keepManual), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('KEEP TYPING MANUALLY'), findsNothing);
      expect(
        find.byKey(const ValueKey('keyboard-decline-place-search-query')),
        findsNothing,
      );
      expect(identity.ensureCoreCalls, 0);
      expect(identity.signInCalls, 0);
      expect(factory.appCheck.activateCalls, 0);
      expect(factory.controllerCreateCalls, 0);
      expect(service.autocompleteQueries, isEmpty);

      final savedName = find.byKey(
        const ValueKey('keyboard-decline-place-saved-name'),
      );
      expect(
        tester.widget<TextField>(savedName).controller!.text,
        'Manual library',
      );
      await tester.enterText(savedName, 'Busch Student Center');
      expect(controller.savedName, 'Busch Student Center');
    },
  );

  testWidgets('Daybook event editor saves timed and valid weekly payloads', (
    tester,
  ) async {
    DaybookEvent? saved;
    await _pumpDaybookWidget(
      tester,
      DaybookEventEditor(
        selectedDay: CivilDate(2026, 8, 11),
        timeZoneIdProvider: () async => 'Etc/UTC',
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
    'Daybook series edit reconciles exceptions inside save failure and retry handling',
    (tester) async {
      final source = DaybookEvent(
        eventId: 'event_series_retry',
        title: 'Studio hour',
        startDate: CivilDate(2026, 8, 11),
        endDate: CivilDate(2026, 8, 11),
        timeZoneId: 'America/New_York',
        allDay: false,
        startMinute: 9 * 60,
        endMinute: 10 * 60,
        weeklyRule: WeeklyEventRule(weekdays: const {DateTime.tuesday}),
        exceptions: [
          DaybookEventException(
            occurrenceKey: 'event_series_retry@2026-08-18',
            originalDate: CivilDate(2026, 8, 18),
            state: DaybookEventOccurrenceState.moved,
            movedStartDate: CivilDate(2026, 8, 19),
            movedEndDate: CivilDate(2026, 8, 19),
            movedStartMinute: 11 * 60,
            movedEndMinute: 12 * 60,
            updatedAt: DateTime.utc(2026, 8, 10),
          ),
          DaybookEventException(
            occurrenceKey: 'event_series_retry@2026-08-25',
            originalDate: CivilDate(2026, 8, 25),
            state: DaybookEventOccurrenceState.cancelled,
            updatedAt: DateTime.utc(2026, 8, 10),
          ),
        ],
        createdAt: DateTime.utc(2026, 8, 8),
        updatedAt: DateTime.utc(2026, 8, 8),
      );
      final attempts = <DaybookEvent>[];
      await _pumpDaybookWidget(
        tester,
        DaybookEventEditor(
          selectedDay: source.startDate,
          initialEvent: source,
          onSave: (event) async {
            attempts.add(event);
            return attempts.length > 1;
          },
        ),
      );

      await tester.tap(find.byKey(const ValueKey('daybook-event-all-day')));
      await tester.ensureVisible(
        find.byKey(const ValueKey('daybook-event-save')),
      );
      await tester.tap(find.byKey(const ValueKey('daybook-event-save')));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(attempts, hasLength(1));
      expect(attempts.single.allDay, isTrue);
      expect(attempts.single.exceptions, hasLength(1));
      expect(
        attempts.single.exceptions.single.state,
        DaybookEventOccurrenceState.cancelled,
      );
      expect(
        find.text('Couldn’t save this event locally. Try again.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('daybook-event-save')));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(attempts, hasLength(2));
      expect(attempts.last.exceptions, attempts.first.exceptions);
    },
  );

  for (final platformZone in const [
    (platform: 'native', zone: 'Asia/Tokyo'),
    (platform: 'web', zone: 'Europe/London'),
  ]) {
    testWidgets(
      'Daybook new event uses the injected ${platformZone.platform} IANA zone',
      (tester) async {
        DaybookEvent? saved;
        await _pumpDaybookWidget(
          tester,
          DaybookEventEditor(
            selectedDay: CivilDate(2026, 8, 11),
            timeZoneIdProvider: () async => platformZone.zone,
            onSave: (event) async {
              saved = event;
              return true;
            },
          ),
        );

        await tester.enterText(
          find.byKey(const ValueKey('daybook-event-title')),
          'Cross-zone call',
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('daybook-event-save')),
        );
        await tester.tap(find.byKey(const ValueKey('daybook-event-save')));
        await tester.pump();

        expect(saved?.timeZoneId, platformZone.zone);
      },
    );
  }

  testWidgets('Daybook event edit preserves its stored time zone', (
    tester,
  ) async {
    var discoveryCalls = 0;
    DaybookEvent? saved;
    final source = DaybookEvent(
      eventId: 'event_zone_preserved',
      title: 'Remote review',
      startDate: CivilDate(2026, 8, 11),
      endDate: CivilDate(2026, 8, 11),
      timeZoneId: 'Australia/Perth',
      allDay: false,
      startMinute: 9 * 60,
      endMinute: 10 * 60,
      createdAt: DateTime.utc(2026, 8, 8),
      updatedAt: DateTime.utc(2026, 8, 8),
    );
    await _pumpDaybookWidget(
      tester,
      DaybookEventEditor(
        selectedDay: source.startDate,
        initialEvent: source,
        timeZoneIdProvider: () async {
          discoveryCalls += 1;
          return 'Pacific/Auckland';
        },
        onSave: (event) async {
          saved = event;
          return true;
        },
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('daybook-event-save')),
    );
    await tester.tap(find.byKey(const ValueKey('daybook-event-save')));
    await tester.pump();

    expect(discoveryCalls, 0);
    expect(saved?.timeZoneId, 'Australia/Perth');
  });

  testWidgets('Daybook new event falls back to neutral Etc/UTC', (
    tester,
  ) async {
    DaybookEvent? saved;
    await _pumpDaybookWidget(
      tester,
      DaybookEventEditor(
        selectedDay: CivilDate(2026, 8, 11),
        timeZoneIdProvider: () async => throw StateError('zone unavailable'),
        onSave: (event) async {
          saved = event;
          return true;
        },
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('daybook-event-title')),
      'Fallback-zone call',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('daybook-event-save')),
    );
    await tester.tap(find.byKey(const ValueKey('daybook-event-save')));
    await tester.pump();

    expect(saved?.timeZoneId, 'Etc/UTC');
  });

  testWidgets(
    'address or routing label remains fully visible at 320x568 and 200% text',
    (tester) async {
      await _pumpDaybookWidget(
        tester,
        DaybookEventEditor(
          selectedDay: CivilDate(2026, 8, 11),
          timeZoneIdProvider: () async => 'Etc/UTC',
          onSave: (_) async => true,
        ),
        size: const Size(320, 568),
        textScale: 2,
      );

      final label = find.text('ADDRESS OR ROUTING TEXT');
      expect(label, findsOneWidget);
      await tester.ensureVisible(label);
      await tester.pump();

      expect(
        tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
        isFalse,
      );
      final bounds = tester.getRect(label);
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'occurrence cancellation explanation remains fully readable at 200% text',
    (tester) async {
      await _pumpDaybookWidget(
        tester,
        const DaybookEventActionsDialog(
          title: 'A weekly event with a descriptive title',
          scope: DaybookEventScope.thisEvent,
        ),
        size: const Size(320, 568),
        textScale: 2,
      );

      final explanation = find.text(
        'Keep the series and mark only this occurrence cancelled.',
      );
      expect(explanation, findsOneWidget);
      await tester.ensureVisible(explanation);
      await tester.pump();

      expect(
        tester.renderObject<RenderParagraph>(explanation).didExceedMaxLines,
        isFalse,
      );
      expect(tester.getBottomLeft(explanation).dy, lessThanOrEqualTo(568));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Daybook weekday controls stay 44 px and expose unambiguous semantics',
    (tester) async {
      await _pumpDaybookWidget(
        tester,
        DaybookEventEditor(
          selectedDay: CivilDate(2026, 8, 11),
          onSave: (_) async => true,
        ),
        size: const Size(320, 568),
        textScale: 2,
      );

      final weeklyToggle = find.byKey(const ValueKey('daybook-event-weekly'));
      await tester.ensureVisible(weeklyToggle);
      await tester.tap(weeklyToggle);
      await tester.pump();

      for (var weekday = 1; weekday <= 7; weekday++) {
        final target = find.byKey(ValueKey('daybook-event-weekday-$weekday'));
        final size = tester.getSize(target);
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
      }
      expect(find.bySemanticsLabel('Tuesday'), findsOneWidget);
      expect(find.bySemanticsLabel('Thursday'), findsOneWidget);
      expect(find.bySemanticsLabel('Saturday'), findsOneWidget);
      expect(find.bySemanticsLabel('Sunday'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Tuesday'))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Daybook timed event correction names the next-day limit', (
    tester,
  ) async {
    final event = DaybookEvent(
      eventId: 'event_overnight',
      title: 'Overnight vigil',
      startDate: CivilDate(2026, 8, 11),
      endDate: CivilDate(2026, 8, 11),
      timeZoneId: 'America/New_York',
      allDay: false,
      startMinute: 21 * 60,
      endMinute: 23 * 60,
      createdAt: DateTime.utc(2026, 8, 11),
      updatedAt: DateTime.utc(2026, 8, 11),
    );
    final occurrence = DaybookEventOccurrence(
      eventId: event.eventId,
      occurrenceKey: '${event.eventId}/2026-08-11',
      originalDate: CivilDate(2026, 8, 11),
      startDate: CivilDate(2026, 8, 11),
      endDate: CivilDate(2026, 8, 13),
      allDay: false,
      startMinute: 21 * 60,
      endMinute: 1 * 60,
      state: DaybookEventOccurrenceState.scheduled,
    );
    DaybookEvent? saved;
    await _pumpDaybookWidget(
      tester,
      DaybookEventEditor(
        selectedDay: CivilDate(2026, 8, 11),
        initialEvent: event,
        initialOccurrence: occurrence,
        onSave: (value) async {
          saved = value;
          return true;
        },
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('daybook-event-save')),
    );
    await tester.tap(find.byKey(const ValueKey('daybook-event-save')));
    await tester.pump();

    expect(
      find.text(
        'Choose the same day or the following day for a timed event’s end.',
      ),
      findsOneWidget,
    );
    expect(saved, isNull);
    expect(find.byType(DaybookEventEditor), findsOneWidget);
  });

  testWidgets('Daybook timed event correction names an invalid end time', (
    tester,
  ) async {
    final event = DaybookEvent(
      eventId: 'event_same_day',
      title: 'Evening meeting',
      startDate: CivilDate(2026, 8, 11),
      endDate: CivilDate(2026, 8, 11),
      timeZoneId: 'America/New_York',
      allDay: false,
      startMinute: 18 * 60,
      endMinute: 19 * 60,
      createdAt: DateTime.utc(2026, 8, 11),
      updatedAt: DateTime.utc(2026, 8, 11),
    );
    final occurrence = DaybookEventOccurrence(
      eventId: event.eventId,
      occurrenceKey: '${event.eventId}/2026-08-11',
      originalDate: CivilDate(2026, 8, 11),
      startDate: CivilDate(2026, 8, 11),
      endDate: CivilDate(2026, 8, 11),
      allDay: false,
      startMinute: 18 * 60,
      endMinute: 17 * 60,
      state: DaybookEventOccurrenceState.scheduled,
    );
    await _pumpDaybookWidget(
      tester,
      DaybookEventEditor(
        selectedDay: CivilDate(2026, 8, 11),
        initialEvent: event,
        initialOccurrence: occurrence,
        onSave: (_) async => true,
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('daybook-event-save')),
    );
    await tester.tap(find.byKey(const ValueKey('daybook-event-save')));
    await tester.pump();

    expect(
      find.text('Choose an end time after the start time.'),
      findsOneWidget,
    );
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

  testWidgets(
    'Daybook read-only task row does not announce a completion button',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final task = DaybookTask(
        taskId: 'task_read_only',
        title: 'Read-only task',
        dueDate: CivilDate(2026, 8, 11),
        createdAt: DateTime.utc(2026, 8, 11),
        updatedAt: DateTime.utc(2026, 8, 11),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DaybookTaskRow(task: task)),
        ),
      );

      final toggle = find.byKey(
        const ValueKey('daybook-task-toggle-task_read_only'),
      );
      final toggleSemantics = tester.getSemantics(toggle);
      expect(toggleSemantics.flagsCollection.isButton, isFalse);
      expect(
        toggleSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
      semantics.dispose();
    },
  );

  testWidgets('directions stay hidden without a durable destination', (
    tester,
  ) async {
    await _pumpDaybookWidget(
      tester,
      DaybookDirectionsAction(
        place: DaybookPlace(savedName: 'Meet by the old oak'),
        launcher: _RecordingDirectionsLauncher(),
        preferences: InMemoryDaybookPreferences(),
      ),
    );

    expect(find.text('GET DIRECTIONS'), findsNothing);
  });

  testWidgets('directions expose the saved label as their semantic name', (
    tester,
  ) async {
    await _pumpDaybookWidget(
      tester,
      DaybookDirectionsAction(
        place: DaybookPlace(
          savedName: 'Alexander Library',
          routingText: '169 College Ave, New Brunswick, NJ',
        ),
        launcher: _RecordingDirectionsLauncher(),
        preferences: InMemoryDaybookPreferences(),
      ),
    );

    expect(find.text('GET DIRECTIONS'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Get directions to Alexander Library'),
      findsOneWidget,
    );
  });

  testWidgets(
    'directions launch synchronously on non-iOS without reading preferences',
    (tester) async {
      final launcher = _RecordingDirectionsLauncher();
      final preferences = _BlockingDaybookPreferences();
      await _pumpDaybookWidget(
        tester,
        Theme(
          data: ThemeData(platform: TargetPlatform.android),
          child: DaybookDirectionsAction(
            place: DaybookPlace(
              savedName: 'Alexander Library',
              routingText: '169 College Ave, New Brunswick, NJ',
            ),
            launcher: launcher,
            preferences: preferences,
          ),
        ),
      );

      await tester.tap(find.text('GET DIRECTIONS'));

      expect(preferences.loadCalls, 0);
      expect(launcher.calls, [(MapProvider.google, 'Alexander Library')]);
    },
  );

  testWidgets('directions launch failure keeps the action and offers copy', (
    tester,
  ) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
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
    final launcher = _RecordingDirectionsLauncher(succeeds: false);
    await _pumpDaybookWidget(
      tester,
      DaybookDirectionsAction(
        place: DaybookPlace(
          savedName: 'Alexander Library',
          routingText: '169 College Ave, New Brunswick, NJ',
        ),
        launcher: launcher,
        preferences: InMemoryDaybookPreferences(),
      ),
    );

    await tester.tap(
      find.bySemanticsLabel('Get directions to Alexander Library'),
    );
    await tester.pumpAndSettle();

    expect(launcher.calls, [(MapProvider.google, 'Alexander Library')]);
    expect(find.text('GET DIRECTIONS'), findsOneWidget);
    expect(find.text('COPY LOCATION'), findsOneWidget);
    await tester.tap(find.text('COPY LOCATION'));
    await tester.pump();
    expect(copiedText, '169 College Ave, New Brunswick, NJ');
  });

  testWidgets(
    'directions failure keeps copy reachable with a long label at 320x568 and 200%',
    (tester) async {
      const savedName =
          'Alexander Library Special Collections and University Archives Reading Room';
      await _pumpDaybookWidget(
        tester,
        Theme(
          data: ThemeData(platform: TargetPlatform.iOS),
          child: DaybookDirectionsAction(
            place: DaybookPlace(
              savedName: savedName,
              routingText: '169 College Ave, New Brunswick, NJ',
            ),
            launcher: _RecordingDirectionsLauncher(succeeds: false),
            preferences: InMemoryDaybookPreferences(),
          ),
        ),
        size: const Size(320, 568),
        textScale: 2,
      );

      await tester.tap(find.text('GET DIRECTIONS'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('GOOGLE MAPS'));
      await tester.pump();
      await tester.tap(find.text('GOOGLE MAPS'));
      await tester.pumpAndSettle();

      final copy = find.text('COPY LOCATION');
      expect(copy, findsOneWidget);
      await tester.ensureVisible(copy);
      await tester.pump();
      expect(tester.getCenter(copy).dy, inInclusiveRange(0, 568));
      await tester.tap(copy);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('directions remember and clear an iOS map provider', (
    tester,
  ) async {
    final launcher = _RecordingDirectionsLauncher();
    final preferences = InMemoryDaybookPreferences();
    await _pumpDaybookWidget(
      tester,
      Theme(
        data: ThemeData(platform: TargetPlatform.iOS),
        child: DaybookDirectionsAction(
          place: DaybookPlace(
            savedName: 'Alexander Library',
            routingText: '169 College Ave, New Brunswick, NJ',
          ),
          launcher: launcher,
          preferences: preferences,
        ),
      ),
    );

    await tester.tap(find.text('GET DIRECTIONS'));
    await tester.pumpAndSettle();
    expect(find.text('APPLE MAPS'), findsOneWidget);
    expect(find.text('GOOGLE MAPS'), findsOneWidget);
    expect(launcher.calls, isEmpty);

    await tester.tap(find.text('GOOGLE MAPS'));
    await tester.pumpAndSettle();
    expect(launcher.calls, [(MapProvider.google, 'Alexander Library')]);
    expect(preferences.preferredMapProvider, MapProvider.google);
    expect(find.text('CHANGE MAP APP'), findsOneWidget);

    await tester.tap(find.text('CHANGE MAP APP'));
    await tester.pumpAndSettle();
    expect(preferences.preferredMapProvider, isNull);

    await tester.tap(find.text('GET DIRECTIONS'));
    await tester.pumpAndSettle();
    expect(find.text('APPLE MAPS'), findsOneWidget);
    expect(find.text('GOOGLE MAPS'), findsOneWidget);
  });

  testWidgets('directions ignore a remembered provider unavailable here', (
    tester,
  ) async {
    final launcher = _RecordingDirectionsLauncher();
    await _pumpDaybookWidget(
      tester,
      Theme(
        data: ThemeData(platform: TargetPlatform.iOS),
        child: DaybookDirectionsAction(
          place: DaybookPlace(
            savedName: 'Busch Student Center',
            provider: DaybookPlaceProvider.google,
            providerPlaceId: 'ChIJBUSCH',
          ),
          launcher: launcher,
          preferences: InMemoryDaybookPreferences(
            preferredMapProvider: MapProvider.apple,
          ),
        ),
      ),
    );

    await tester.tap(find.text('GET DIRECTIONS'));
    await tester.pumpAndSettle();

    expect(launcher.calls, [(MapProvider.google, 'Busch Student Center')]);
    expect(find.text('APPLE MAPS'), findsNothing);
  });

  testWidgets('directions actions use projected general and class places', (
    tester,
  ) async {
    final createdAt = DateTime.utc(2026, 8, 8);
    final event = DaybookEvent(
      eventId: 'event_library',
      title: 'Library pickup',
      startDate: CivilDate(2026, 8, 11),
      endDate: CivilDate(2026, 8, 11),
      timeZoneId: 'America/New_York',
      allDay: false,
      startMinute: 9 * 60,
      endMinute: 10 * 60,
      place: DaybookPlace(
        savedName: 'Alexander Library',
        routingText: '169 College Ave, New Brunswick, NJ',
      ),
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    final schedule = _scheduleFixture(
      place: CampusPlace(
        label: 'Hill Center 114',
        building: 'Hill Center',
        room: '114',
        address: '110 Frelinghuysen Rd, Piscataway, NJ',
      ),
    ).putEvent(event);
    final launcher = _RecordingDirectionsLauncher();

    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(schedule),
      handoff: _RecordingHandoff(),
      preferences: InMemoryAcademicCalendarPreferences(
        state: const AcademicCalendarViewState(
          mode: AcademicCalendarMode.day,
          selectedDate: '2026-08-11',
        ),
      ),
      directionsLauncher: launcher,
      daybookPreferences: InMemoryDaybookPreferences(),
    );

    expect(
      find.bySemanticsLabel('Get directions to Alexander Library'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Get directions to Hill Center 114'),
      findsOneWidget,
    );

    final libraryDirections = find.bySemanticsLabel(
      'Get directions to Alexander Library',
    );
    final classDirections = find.bySemanticsLabel(
      'Get directions to Hill Center 114',
    );
    await tester.ensureVisible(libraryDirections);
    await tester.tap(libraryDirections);
    await tester.pumpAndSettle();
    await tester.ensureVisible(classDirections);
    await tester.tap(classDirections);
    await tester.pumpAndSettle();
    expect(launcher.calls, [
      (MapProvider.google, 'Alexander Library'),
      (MapProvider.google, 'Hill Center 114'),
    ]);
  });

  testWidgets('directions class action reflows at 320x568 and 200% text', (
    tester,
  ) async {
    final schedule = _scheduleFixture(
      place: CampusPlace(
        label: 'Hill Center 114',
        building: 'Hill Center',
        room: '114',
        address: '110 Frelinghuysen Rd, Piscataway, NJ',
      ),
    );
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(schedule),
      handoff: _RecordingHandoff(),
      preferences: InMemoryAcademicCalendarPreferences(
        state: const AcademicCalendarViewState(
          mode: AcademicCalendarMode.day,
          selectedDate: '2026-08-11',
        ),
      ),
      directionsLauncher: _RecordingDirectionsLauncher(),
      daybookPreferences: InMemoryDaybookPreferences(),
      size: const Size(320, 568),
      textScale: 2,
    );

    final directions = find.bySemanticsLabel(
      'Get directions to Hill Center 114',
    );
    for (var drag = 0; drag < 8 && directions.evaluate().isEmpty; drag++) {
      await tester.dragFrom(const Offset(160, 500), const Offset(0, -220));
      await tester.pump();
    }
    expect(directions, findsOneWidget);
    expect(
      tester.getSize(find.text('GET DIRECTIONS')).height,
      greaterThanOrEqualTo(20),
    );
    expect(tester.takeException(), isNull);
  });

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

  testWidgets(
    'Daybook class place clearing removes neutral fields but keeps legacy data',
    (tester) async {
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
                child: const Text('OPEN CLEARING EDITOR'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN CLEARING EDITOR'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('academic-course-code')),
        'BIO 101',
      );
      await tester.enterText(
        find.byKey(const ValueKey('academic-course-title')),
        'Foundations of Biology',
      );
      for (final key in const [
        'academic-saved-name',
        'academic-routing-text',
        'academic-building',
        'academic-room',
      ]) {
        await tester.enterText(find.byKey(ValueKey(key)), '');
      }
      await tester.ensureVisible(find.text('KEEP THIS CLASS'));
      await tester.tap(find.text('KEEP THIS CLASS'));
      await tester.pump();

      expect(savedPlace, isNotNull);
      expect(savedPlace!.label, 'Location not set');
      expect(savedPlace!.address, isNull);
      expect(savedPlace!.building, isNull);
      expect(savedPlace!.room, isNull);
      expect(savedPlace!.latitude, original.latitude);
      expect(savedPlace!.longitude, original.longitude);
      expect(savedPlace!.mapsProvider, original.mapsProvider);
      expect(savedPlace!.placeId, original.placeId);
      expect(savedPlace!.campusCode, original.campusCode);
    },
  );

  testWidgets(
    'place search class selection reuses the shared editor without persisting Google address or coordinates',
    (tester) async {
      CampusPlace? savedPlace;
      final factory = _TestPlaceSearchFactory(
        service: _RecordingPlaceSearchService(),
      );
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
                    placeSearchFactory: factory,
                    onSave: (_, _, series) async {
                      savedPlace = series.place;
                      return true;
                    },
                  ),
                ),
                child: const Text('OPEN SEARCH CLASS EDITOR'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN SEARCH CLASS EDITOR'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('academic-course-code')),
        'ECE 345',
      );
      await tester.enterText(
        find.byKey(const ValueKey('academic-course-title')),
        'Linear Systems',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('academic-place-search-affordance')),
      );
      await tester.tap(
        find.byKey(const ValueKey('academic-place-search-affordance')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('USE PLACE SEARCH'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('academic-place-search-query')),
        'Hill Center',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('academic-place-search-suggestion-0')),
      );
      await tester.tap(
        find.byKey(const ValueKey('academic-place-search-suggestion-0')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('KEEP THIS CLASS'));
      await tester.tap(find.text('KEEP THIS CLASS'));
      await tester.pump();

      expect(savedPlace?.label, 'Hill Center');
      expect(savedPlace?.address, isNull);
      expect(savedPlace?.latitude, isNull);
      expect(savedPlace?.longitude, isNull);
      expect(savedPlace?.mapsProvider, 'google');
      expect(savedPlace?.placeId, 'place-Hill-Center');
      expect(savedPlace?.campusCode, isNull);
    },
  );

  testWidgets('Day Shape states the fixed plans, deadline, and focus facts', (
    tester,
  ) async {
    final createdAt = DateTime.utc(2026, 8, 8);
    final schedule = AcademicSchedule.empty()
        .putEvent(
          DaybookEvent(
            eventId: 'day_shape_all_day',
            title: 'Museum visit',
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
            eventId: 'day_shape_timed',
            title: 'Portfolio review',
            startDate: CivilDate(2026, 8, 11),
            endDate: CivilDate(2026, 8, 11),
            timeZoneId: 'America/New_York',
            allDay: false,
            startMinute: 9 * 60,
            endMinute: 10 * 60,
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        )
        .putTask(
          DaybookTask(
            taskId: 'day_shape_deadline',
            title: 'Send references',
            dueDate: CivilDate(2026, 8, 11),
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        );
    final focus = Quest(
      title: 'Choose cover references',
      stat: Stat.foc,
      difficulty: 2,
      priorityDay: Days.key(DateTime(2026, 8, 11)),
    );

    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(schedule),
      handoff: _RecordingHandoff(),
      preferences: InMemoryAcademicCalendarPreferences(
        state: const AcademicCalendarViewState(
          mode: AcademicCalendarMode.day,
          selectedDate: '2026-08-11',
        ),
      ),
      quests: [focus],
    );

    await tester.scrollUntilVisible(
      find.text('DAY SHAPE'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('DAY SHAPE'), findsOneWidget);
    expect(
      find.text('2 fixed plans · first at 9:00 AM · 1 deadline · 1 focus'),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('DAY SHAPE')).dy,
      lessThan(tester.getTopLeft(find.text('ALL DAY').first).dy),
    );
  });

  for (final mode in const [
    AcademicCalendarMode.day,
    AcademicCalendarMode.threeDay,
    AcademicCalendarMode.week,
  ]) {
    testWidgets(
      '${mode.label} keeps one selected-day control and one Day Shape',
      (tester) async {
        final createdAt = DateTime.utc(2026, 8, 8);
        final schedule = AcademicSchedule.empty().putEvent(
          DaybookEvent(
            eventId: 'selected_folio_${mode.name}',
            title: 'Museum visit',
            startDate: CivilDate(2026, 8, 11),
            endDate: CivilDate(2026, 8, 12),
            timeZoneId: 'America/New_York',
            allDay: true,
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        );
        final state = GameState()
          ..history['2026-08-11'] = 1
          ..journal = [
            Note(
              id: 'selected-folio-note-${mode.name}',
              at: DateTime(2026, 8, 11, 8),
              text: 'A kept note',
            ),
          ];

        await _pumpCalendar(
          tester,
          repository: InMemoryAcademicScheduleRepository(schedule),
          handoff: _RecordingHandoff(),
          preferences: InMemoryAcademicCalendarPreferences(
            state: AcademicCalendarViewState(
              mode: mode,
              selectedDate: '2026-08-11',
            ),
          ),
          state: state,
          calendarKey: ValueKey('selected-folio-${mode.name}'),
        );

        await tester.scrollUntilVisible(
          find.text('DAY SHAPE'),
          260,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();

        expect(find.text('TUESDAY 11 · TODAY'), findsNothing);
        expect(find.text('+ PLAN'), findsOneWidget);
        final planSemantics = tester.getSemantics(
          find.bySemanticsLabel(RegExp(r'Add a plan for TUESDAY 11, today')),
        );
        expect(
          planSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );
        expect(find.text('DAY SHAPE'), findsOneWidget);
        final selectedControl = find.byKey(
          const ValueKey('daybook-day-control-2026-08-11'),
        );
        final selectedSemantics = tester.getSemantics(selectedControl);
        expect(
          selectedSemantics.getSemanticsData().flagsCollection.isSelected,
          Tristate.isTrue,
        );
        expect(
          selectedSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );
        final selectedTop = tester.getTopLeft(selectedControl).dy;
        final shapeTop = tester.getTopLeft(find.text('DAY SHAPE')).dy;
        final planTop = tester.getTopLeft(find.text('+ PLAN')).dy;
        if (mode == AcademicCalendarMode.day) {
          expect(selectedTop, lessThan(shapeTop));
          expect(planTop, lessThan(shapeTop));
        } else {
          expect(shapeTop, lessThan(selectedTop));
          expect(shapeTop, lessThan(planTop));
        }
        expect(
          tester.getTopLeft(find.text('DAY SHAPE')).dy,
          lessThan(tester.getTopLeft(find.text('ALL DAY').first).dy),
        );

        await tester.scrollUntilVisible(
          find.text('JOURNAL'),
          260,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('1 quest completed'), findsOneWidget);
        expect(find.text('JOURNAL'), findsOneWidget);
        expect(find.text('A kept note'), findsOneWidget);
        expect(find.text('TUESDAY 11 · TODAY'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Day Shape uses factual singular, plural, and empty copy', (
    tester,
  ) async {
    final createdAt = DateTime.utc(2026, 8, 8);
    final preferences = InMemoryAcademicCalendarPreferences(
      state: const AcademicCalendarViewState(
        mode: AcademicCalendarMode.day,
        selectedDate: '2026-08-11',
      ),
    );

    Future<void> expectShape({
      required AcademicSchedule schedule,
      List<Quest> quests = const [],
      required String copy,
      DateTime? now,
    }) async {
      Clock.freeze(now ?? DateTime(2026, 8, 11));
      await _pumpCalendar(
        tester,
        repository: InMemoryAcademicScheduleRepository(schedule),
        handoff: _RecordingHandoff(),
        preferences: preferences,
        quests: quests,
        calendarKey: ValueKey('day-shape-$copy'),
      );
      await tester.scrollUntilVisible(
        find.text('DAY SHAPE'),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('DAY SHAPE'), findsOneWidget);
      expect(find.text(copy), findsOneWidget);
    }

    await expectShape(
      schedule: AcademicSchedule.empty().putEvent(
        DaybookEvent(
          eventId: 'day_shape_one_timed',
          title: 'Call advisor',
          startDate: CivilDate(2026, 8, 11),
          endDate: CivilDate(2026, 8, 11),
          timeZoneId: 'America/New_York',
          allDay: false,
          startMinute: 10 * 60,
          endMinute: 11 * 60,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      ),
      copy: '1 fixed plan · 10:00 AM',
    );
    await expectShape(
      schedule: AcademicSchedule.empty()
          .putEvent(
            DaybookEvent(
              eventId: 'day_shape_first_timed',
              title: 'Call advisor',
              startDate: CivilDate(2026, 8, 11),
              endDate: CivilDate(2026, 8, 11),
              timeZoneId: 'America/New_York',
              allDay: false,
              startMinute: 10 * 60,
              endMinute: 11 * 60,
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          )
          .putEvent(
            DaybookEvent(
              eventId: 'day_shape_second_timed',
              title: 'Studio circle',
              startDate: CivilDate(2026, 8, 11),
              endDate: CivilDate(2026, 8, 11),
              timeZoneId: 'America/New_York',
              allDay: false,
              startMinute: 16 * 60,
              endMinute: 17 * 60,
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          ),
      copy: '2 fixed plans · first at 10:00 AM',
    );
    await expectShape(
      schedule: AcademicSchedule.empty().putEvent(
        DaybookEvent(
          eventId: 'day_shape_all_day_only',
          title: 'Museum visit',
          startDate: CivilDate(2026, 8, 11),
          endDate: CivilDate(2026, 8, 12),
          timeZoneId: 'America/New_York',
          allDay: true,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      ),
      copy: '1 all-day plan',
    );
    await expectShape(
      schedule: AcademicSchedule.empty().putTask(
        DaybookTask(
          taskId: 'day_shape_deadline_only',
          title: 'Send references',
          dueDate: CivilDate(2026, 8, 11),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      ),
      copy: '1 deadline',
    );
    await expectShape(
      schedule: AcademicSchedule.empty(),
      quests: [
        Quest(
          title: 'Choose cover references',
          stat: Stat.foc,
          difficulty: 2,
          priorityDay: Days.key(DateTime(2026, 8, 11)),
        ),
      ],
      copy: '1 focus',
    );
    await expectShape(
      schedule: AcademicSchedule.empty(),
      quests: [
        Quest(
          title: 'Choose cover references',
          stat: Stat.foc,
          difficulty: 2,
          priorityDay: Days.key(DateTime(2026, 8, 11)),
        ),
        Quest(
          title: 'Outline the presentation',
          stat: Stat.foc,
          difficulty: 2,
          priorityDay: Days.key(DateTime(2026, 8, 11)),
        ),
      ],
      copy: '2 focus choices',
    );
    await expectShape(
      schedule: AcademicSchedule.empty(),
      copy: 'No fixed plans.',
    );
    await expectShape(
      schedule: AcademicSchedule.empty(),
      copy: 'No fixed plans.',
      now: DateTime(2026, 8, 12),
    );
  });

  for (final mode in const [
    AcademicCalendarMode.day,
    AcademicCalendarMode.threeDay,
    AcademicCalendarMode.week,
  ]) {
    testWidgets('${mode.label} Day Shape wraps at 320 by 568 and 200% text', (
      tester,
    ) async {
      final createdAt = DateTime.utc(2026, 8, 8);
      final schedule = AcademicSchedule.empty()
          .putEvent(
            DaybookEvent(
              eventId: 'day_shape_large_all_day',
              title: 'Museum visit',
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
              eventId: 'day_shape_large_timed',
              title: 'Portfolio review',
              startDate: CivilDate(2026, 8, 11),
              endDate: CivilDate(2026, 8, 11),
              timeZoneId: 'America/New_York',
              allDay: false,
              startMinute: 9 * 60,
              endMinute: 10 * 60,
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          )
          .putTask(
            DaybookTask(
              taskId: 'day_shape_large_deadline',
              title: 'Send references',
              dueDate: CivilDate(2026, 8, 11),
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          );
      const body = '2 fixed plans · first at 9:00 AM · 1 deadline · 1 focus';
      await _pumpCalendar(
        tester,
        repository: InMemoryAcademicScheduleRepository(schedule),
        handoff: _RecordingHandoff(),
        preferences: InMemoryAcademicCalendarPreferences(
          state: AcademicCalendarViewState(
            mode: mode,
            selectedDate: '2026-08-11',
          ),
        ),
        quests: [
          Quest(
            title: 'Choose cover references',
            stat: Stat.foc,
            difficulty: 2,
            priorityDay: Days.key(DateTime(2026, 8, 11)),
          ),
        ],
        size: const Size(320, 568),
        textScale: 2,
      );

      await tester.scrollUntilVisible(
        find.text('DAY SHAPE'),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      final label = tester.renderObject<RenderParagraph>(
        find.text('DAY SHAPE'),
      );
      final paragraph = tester.renderObject<RenderParagraph>(find.text(body));
      expect(label.didExceedMaxLines, isFalse);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(find.text('TUESDAY 11 · TODAY'), findsNothing);
      expect(find.text('+ PLAN'), findsOneWidget);
      final selectedBottom = tester
          .getBottomLeft(
            find.byKey(const ValueKey('daybook-day-control-2026-08-11')),
          )
          .dy;
      final planBottom = tester.getBottomLeft(find.text('+ PLAN')).dy;
      final shapeTop = tester.getTopLeft(find.text('DAY SHAPE')).dy;
      if (mode == AcademicCalendarMode.day) {
        expect(selectedBottom, lessThan(shapeTop));
        expect(planBottom, lessThan(shapeTop));
      } else {
        expect(shapeTop, lessThan(selectedBottom));
        expect(shapeTop, lessThan(planBottom));
      }
      expect(
        tester.getTopLeft(find.text('DAY SHAPE')).dy,
        lessThan(tester.getTopLeft(find.text('ALL DAY').first).dy),
      );
      expect(tester.getTopLeft(find.text(body)).dy, greaterThanOrEqualTo(0));
      expect(tester.getBottomLeft(find.text(body)).dy, lessThanOrEqualTo(568));
      expect(tester.takeException(), isNull);
    });
  }

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
      find.bySemanticsLabel(
        'August 11, 2026, today, 90 scheduled minutes, 1 fixed plan, no active deadlines, no active focus choices',
      ),
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

  testWidgets(
    'general daybook coexistence uses one source order in month and span views',
    (tester) async {
      final schedule = _generalDaybookSchedule();
      final quest = Quest(
        title: 'Quest board check-in',
        stat: Stat.foc,
        difficulty: 3,
        schedule: QuestSchedule.once,
        dueDate: DateTime(2026, 8, 11),
      );
      await _pumpCalendar(
        tester,
        repository: InMemoryAcademicScheduleRepository(schedule),
        handoff: _RecordingHandoff(),
        quests: [quest],
      );

      expect(
        find.bySemanticsLabel(
          'August 11, 2026, today, 195 scheduled minutes, 4 fixed plans, 4 active deadlines, no active focus choices',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Library closed'),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Library closed'), findsOneWidget);
      expect(find.text('Project meeting'), findsOneWidget);
      expect(find.text('Return library book'), findsOneWidget);
      expect(find.text('Quest board check-in'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('ALL DAY').first).dy,
        lessThan(tester.getTopLeft(find.text('SCHEDULE')).dy),
      );

      for (final mode in const [
        AcademicCalendarMode.week,
        AcademicCalendarMode.threeDay,
        AcademicCalendarMode.day,
      ]) {
        final modeButton = find.byKey(ValueKey('academic-mode-${mode.name}'));
        await tester.scrollUntilVisible(
          modeButton,
          -260,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(modeButton);
        await tester.pump(const Duration(milliseconds: 250));
        expect(
          find.byKey(ValueKey('academic-${mode.name}-view')),
          findsOneWidget,
        );
        expect(find.text('Library closed'), findsWidgets);
        expect(find.text('Project meeting'), findsWidgets);
        expect(find.text('Return library book'), findsWidgets);
        expect(find.text('Quest board check-in'), findsWidgets);
        expect(find.text('STILL OPEN'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('ALL DAY').first).dy,
          lessThan(tester.getTopLeft(find.text('SCHEDULE').first).dy),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'general daybook task completion and undo persist without game rewards',
    (tester) async {
      final task = DaybookTask(
        taskId: 'task_return_book',
        title: 'Return library book',
        dueDate: CivilDate(2026, 8, 11),
        dueMinute: 17 * 60,
        createdAt: DateTime.utc(2026, 8, 9),
        updatedAt: DateTime.utc(2026, 8, 9),
      );
      final repository = InMemoryAcademicScheduleRepository(
        AcademicSchedule.empty().putTask(task),
      );
      final state = GameState()
        ..xp = 17
        ..totalXp = 41
        ..streakDays = 3;
      final quest = Quest(
        title: 'Keep the Quest untouched',
        stat: Stat.foc,
        difficulty: 2,
        schedule: QuestSchedule.once,
        dueDate: DateTime(2026, 8, 11),
      );
      final historyBefore = Map<String, int>.of(state.history);

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
        quests: [quest],
        state: state,
      );

      final toggle = find.byKey(
        const ValueKey('daybook-task-toggle-task_return_book'),
      );
      await tester.tap(toggle.first);
      await tester.pump(const Duration(milliseconds: 250));
      expect(repository.schedule.tasks.single.completed, isTrue);
      expect(repository.schedule.tasks.single.dueDate, CivilDate(2026, 8, 11));
      expect(repository.schedule.tasks.single.dueMinute, 17 * 60);
      expect(state.xp, 17);
      expect(state.totalXp, 41);
      expect(state.streakDays, 3);
      expect(state.history, historyBefore);
      expect(quest.doneFor(DateTime(2026, 8, 11)), isFalse);

      await tester.tap(toggle.first);
      await tester.pump(const Duration(milliseconds: 250));
      expect(repository.schedule.tasks.single.completed, isFalse);
      expect(repository.schedule.tasks.single.dueDate, CivilDate(2026, 8, 11));
      expect(repository.schedule.tasks.single.dueMinute, 17 * 60);
      expect(repository.saveCount, 2);
      expect(state.xp, 17);
      expect(state.totalXp, 41);
      expect(state.streakDays, 3);
      expect(state.history, historyBefore);
      expect(quest.doneFor(DateTime(2026, 8, 11)), isFalse);
    },
  );

  testWidgets('dated Quest focus renders in its own accessible section', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(),
      handoff: _RecordingHandoff(),
      preferences: InMemoryAcademicCalendarPreferences(
        state: const AcademicCalendarViewState(
          mode: AcademicCalendarMode.day,
          selectedDate: '2026-08-11',
        ),
      ),
      quests: [
        Quest(
          title: 'Choose my anchor',
          stat: Stat.foc,
          difficulty: 2,
          priorityDay: '2026-08-11',
        ),
      ],
    );

    expect(find.text('TODAY’S FOCUS'), findsOneWidget);
    expect(find.text('Choose my anchor'), findsOneWidget);
    expect(find.text('CHOSEN FOR TODAY'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Choose my anchor, today’s focus'),
      findsOneWidget,
    );
  });

  testWidgets('Quest calendar intent renders focus separately from due work', (
    tester,
  ) async {
    final date = CivilDate(2026, 8, 18);
    final createdAt = DateTime.utc(2026, 8, 17);
    final timedEvent = DaybookEvent(
      eventId: 'event_focus_day',
      title: 'Real timed Daybook event',
      startDate: date,
      endDate: date,
      timeZoneId: 'America/New_York',
      allDay: false,
      startMinute: 9 * 60,
      endMinute: 10 * 60,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(
        AcademicSchedule.empty().putEvent(timedEvent),
      ),
      handoff: _RecordingHandoff(),
      preferences: InMemoryAcademicCalendarPreferences(
        state: const AcademicCalendarViewState(
          mode: AcademicCalendarMode.day,
          selectedDate: '2026-08-18',
        ),
      ),
      quests: [
        Quest(
          title: 'Daily routine',
          stat: Stat.foc,
          difficulty: 1,
          schedule: QuestSchedule.daily,
        ),
        Quest(
          title: 'Chosen today',
          stat: Stat.foc,
          difficulty: 2,
          priorityDay: '2026-08-18',
        ),
        Quest(
          title: 'Explicit one-time due Quest',
          stat: Stat.foc,
          difficulty: 3,
          schedule: QuestSchedule.once,
          dueDate: DateTime(2026, 8, 18),
        ),
      ],
      size: const Size(320, 568),
      textScale: 2,
    );

    expect(find.text('Daily routine'), findsNothing);
    expect(find.text('TODAY’S FOCUS'), findsOneWidget);
    expect(find.text('Chosen today'), findsOneWidget);
    expect(find.text('CHOSEN FOR TODAY'), findsOneWidget);
    expect(find.text('DUE'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('academic-mode-month')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.byKey(const ValueKey('academic-month-focus-2026-08-18')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('academic-month-deadline-2026-08-18')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quest calendar intent leaves routine-only month days unmarked', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(),
      handoff: _RecordingHandoff(),
      preferences: InMemoryAcademicCalendarPreferences(
        state: const AcademicCalendarViewState(
          mode: AcademicCalendarMode.month,
          selectedDate: '2026-08-18',
        ),
      ),
      quests: [
        Quest(
          title: 'Daily routine',
          stat: Stat.foc,
          difficulty: 1,
          schedule: QuestSchedule.daily,
        ),
      ],
    );

    expect(
      find.byKey(const ValueKey('academic-month-weight-2026-08-18')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('academic-month-deadline-2026-08-18')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('academic-month-focus-2026-08-18')),
      findsNothing,
    );
  });

  testWidgets('Quest calendar intent gives focus its own quiet month mark', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(),
      handoff: _RecordingHandoff(),
      preferences: InMemoryAcademicCalendarPreferences(
        state: const AcademicCalendarViewState(
          mode: AcademicCalendarMode.month,
          selectedDate: '2026-08-18',
        ),
      ),
      quests: [
        Quest(
          title: 'Chosen today',
          stat: Stat.foc,
          difficulty: 2,
          priorityDay: '2026-08-18',
        ),
      ],
    );

    expect(
      find.byKey(const ValueKey('academic-month-focus-2026-08-18')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('academic-month-deadline-2026-08-18')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('academic-month-weight-2026-08-18')),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^August 18, 2026, no timed plans, no fixed plans, no active deadlines, 1 active focus choice$',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'today due and focus Quest rows delegate their canonical completion action',
    (tester) async {
      Clock.freeze(DateTime(2026, 8, 18, 12));
      final due = Quest(
        title: 'Explicit due Quest',
        stat: Stat.foc,
        difficulty: 3,
        schedule: QuestSchedule.once,
        dueDate: DateTime(2026, 8, 18),
      );
      final focus = Quest(
        title: 'Chosen today',
        stat: Stat.foc,
        difficulty: 2,
        priorityDay: '2026-08-18',
      );
      final delegated = <Quest>[];
      final anchors = <Offset>[];
      await _pumpCalendar(
        tester,
        repository: InMemoryAcademicScheduleRepository(),
        handoff: _RecordingHandoff(),
        preferences: InMemoryAcademicCalendarPreferences(
          state: const AcademicCalendarViewState(
            mode: AcademicCalendarMode.day,
            selectedDate: '2026-08-18',
          ),
        ),
        quests: [due, focus],
        onCompleteQuest: (quest, anchor) {
          delegated.add(quest);
          anchors.add(anchor);
        },
      );

      final dueToggle = find.byKey(
        const ValueKey('quest-plan-toggle-Explicit due Quest'),
      );
      final focusToggle = find.byKey(
        const ValueKey('quest-plan-toggle-Chosen today'),
      );
      await tester.scrollUntilVisible(
        dueToggle,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.getSize(dueToggle), const Size(44, 44));
      await tester.tap(dueToggle);
      await tester.pump();
      await tester.scrollUntilVisible(
        focusToggle,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.getSize(focusToggle), const Size(44, 44));
      await tester.tap(focusToggle);
      await tester.pump();

      expect(delegated, [same(due), same(focus)]);
      expect(anchors, hasLength(2));
      for (final anchor in anchors) {
        expect(anchor.dx, greaterThan(0));
        expect(anchor.dy, greaterThan(0));
      }
    },
  );

  testWidgets(
    'calendar Quest completion uses the normal reward and persistence pipeline',
    (tester) async {
      Clock.freeze(DateTime(2026, 8, 18, 12));
      final state = GameState()
        ..onboarded = true
        ..reduceMotion = true;
      final focus = Quest(
        title: 'Calendar focus',
        stat: Stat.foc,
        difficulty: 2,
        priorityDay: '2026-08-18',
      );
      final quests = [focus];
      var persisted = 0;
      void Function(Quest quest, Offset anchor)? canonicalComplete;
      final repository = InMemoryAcademicScheduleRepository();

      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Offstage(
                  offstage: true,
                  child: QuestsPage(
                    state: state,
                    quests: quests,
                    onRefresh: () => 0,
                    onPersist: () => persisted++,
                    onAdd: (_) => true,
                    onRemove: (_) {},
                    onSnapshot: () => 'calendar-completion-snapshot',
                    onRestore: (_) {},
                    onBindComplete: (complete) => canonicalComplete = complete,
                  ),
                ),
                CalendarPage(
                  state: state,
                  quests: quests,
                  onAdd: (_) => true,
                  onCompleteQuest: (quest, anchor) =>
                      canonicalComplete!(quest, anchor),
                  scheduleRepository: repository,
                  calendarPreferences: InMemoryAcademicCalendarPreferences(
                    state: const AcademicCalendarViewState(
                      mode: AcademicCalendarMode.day,
                      selectedDate: '2026-08-18',
                    ),
                  ),
                  notebookHandoff: _RecordingHandoff(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final toggle = find.byKey(
        const ValueKey('quest-plan-toggle-Calendar focus'),
      );
      await tester.scrollUntilVisible(
        toggle,
        220,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('1 focus'), findsOneWidget);
      await tester.tap(toggle);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('quest-completion-stitch')),
        findsOneWidget,
      );
      expect(focus.doneFor(Clock.now()), isTrue);
      expect(find.text('1 focus'), findsNothing);
      expect(find.text('No fixed plans.'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 600));
      expect(state.totalXp, greaterThan(0));
      expect(state.history['2026-08-18'], 1);
      expect(persisted, 1);

      await tester.pump(const Duration(seconds: 6));
    },
  );

  testWidgets('completed focus remains history, not an active month choice', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(),
      handoff: _RecordingHandoff(),
      preferences: InMemoryAcademicCalendarPreferences(
        state: const AcademicCalendarViewState(
          mode: AcademicCalendarMode.month,
          selectedDate: '2026-08-18',
        ),
      ),
      quests: [
        Quest(
          title: 'Chosen today',
          stat: Stat.foc,
          difficulty: 2,
          priorityDay: '2026-08-18',
          lastDoneDay: '2026-08-18',
        ),
      ],
    );

    expect(
      find.byKey(const ValueKey('academic-month-focus-2026-08-18')),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^August 18, 2026, no timed plans, no fixed plans, no active deadlines, no active focus choices$',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'month semantics state exact timed all-day deadline and focus facts once',
    (tester) async {
      Clock.freeze(DateTime(2026, 8, 18, 12));
      final createdAt = DateTime.utc(2026, 8, 8);
      final schedule = AcademicSchedule.empty()
          .putEvent(
            DaybookEvent(
              eventId: 'semantic_all_day',
              title: 'Museum visit',
              startDate: CivilDate(2026, 8, 18),
              endDate: CivilDate(2026, 8, 19),
              timeZoneId: 'America/New_York',
              allDay: true,
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          )
          .putEvent(
            DaybookEvent(
              eventId: 'semantic_timed',
              title: 'Portfolio review',
              startDate: CivilDate(2026, 8, 18),
              endDate: CivilDate(2026, 8, 18),
              timeZoneId: 'America/New_York',
              allDay: false,
              startMinute: 9 * 60,
              endMinute: 10 * 60,
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          )
          .putTask(
            DaybookTask(
              taskId: 'semantic_deadline',
              title: 'Send references',
              dueDate: CivilDate(2026, 8, 18),
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          );
      await _pumpCalendar(
        tester,
        repository: InMemoryAcademicScheduleRepository(schedule),
        handoff: _RecordingHandoff(),
        preferences: InMemoryAcademicCalendarPreferences(
          state: const AcademicCalendarViewState(
            mode: AcademicCalendarMode.month,
            selectedDate: '2026-08-18',
          ),
        ),
        quests: [
          Quest(
            title: 'Chosen today',
            stat: Stat.foc,
            difficulty: 2,
            priorityDay: '2026-08-18',
          ),
        ],
      );

      const expected =
          'August 18, 2026, today, 60 scheduled minutes, 2 fixed plans, 1 active deadline, 1 active focus choice';
      expect(find.bySemanticsLabel(expected), findsOneWidget);
      final semantics = tester.getSemantics(find.bySemanticsLabel(expected));
      expect(
        RegExp('August 18, 2026').allMatches(semantics.label),
        hasLength(1),
      );
      expect(semantics.label, isNot(contains('open day')));
      expect(semantics.label, isNot(contains('2026-08-18')));
    },
  );

  testWidgets(
    'month semantics treats all-day as fixed and completed or cancelled as inactive',
    (tester) async {
      Clock.freeze(DateTime(2026, 8, 18, 12));
      final createdAt = DateTime.utc(2026, 8, 8);
      final cancelled = DaybookEvent(
        eventId: 'semantic_cancelled',
        title: 'Cancelled call',
        startDate: CivilDate(2026, 8, 18),
        endDate: CivilDate(2026, 8, 18),
        timeZoneId: 'America/New_York',
        allDay: false,
        startMinute: 14 * 60,
        endMinute: 15 * 60,
        weeklyRule: WeeklyEventRule(
          weekdays: const {DateTime.tuesday},
          endsOn: CivilDate(2026, 8, 18),
        ),
        exceptions: [
          DaybookEventException(
            occurrenceKey: 'semantic_cancelled/2026-08-18',
            originalDate: CivilDate(2026, 8, 18),
            state: DaybookEventOccurrenceState.cancelled,
            updatedAt: createdAt,
          ),
        ],
        createdAt: createdAt,
        updatedAt: createdAt,
      );
      final schedule = AcademicSchedule.empty()
          .putEvent(
            DaybookEvent(
              eventId: 'semantic_only_all_day',
              title: 'Museum visit',
              startDate: CivilDate(2026, 8, 18),
              endDate: CivilDate(2026, 8, 19),
              timeZoneId: 'America/New_York',
              allDay: true,
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          )
          .putEvent(cancelled)
          .putTask(
            DaybookTask(
              taskId: 'semantic_completed_deadline',
              title: 'Sent references',
              dueDate: CivilDate(2026, 8, 18),
              completedAt: createdAt,
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          );
      await _pumpCalendar(
        tester,
        repository: InMemoryAcademicScheduleRepository(schedule),
        handoff: _RecordingHandoff(),
        preferences: InMemoryAcademicCalendarPreferences(
          state: const AcademicCalendarViewState(
            mode: AcademicCalendarMode.month,
            selectedDate: '2026-08-18',
          ),
        ),
        quests: [
          Quest(
            title: 'Finished focus',
            stat: Stat.foc,
            difficulty: 2,
            priorityDay: '2026-08-18',
            lastDoneDay: '2026-08-18',
          ),
        ],
      );

      expect(
        find.bySemanticsLabel(
          'August 18, 2026, today, no timed plans, 1 all-day plan, no active deadlines, no active focus choices',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('academic-month-weight-2026-08-18')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('academic-month-deadline-2026-08-18')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('academic-month-focus-2026-08-18')),
        findsNothing,
      );
    },
  );

  testWidgets('projected occurrence renders moved state and moved local time', (
    tester,
  ) async {
    final event = DaybookEvent(
      eventId: 'event_moved_clinic',
      title: 'Planning clinic',
      startDate: CivilDate(2026, 8, 11),
      endDate: CivilDate(2026, 8, 11),
      timeZoneId: 'America/New_York',
      allDay: false,
      startMinute: 9 * 60,
      endMinute: 10 * 60,
      weeklyRule: WeeklyEventRule(
        weekdays: const {DateTime.tuesday},
        endsOn: CivilDate(2026, 8, 18),
      ),
      exceptions: [
        DaybookEventException(
          occurrenceKey: 'event_moved_clinic/2026-08-11',
          originalDate: CivilDate(2026, 8, 11),
          state: DaybookEventOccurrenceState.moved,
          movedStartDate: CivilDate(2026, 8, 12),
          movedEndDate: CivilDate(2026, 8, 12),
          movedStartMinute: 13 * 60 + 15,
          movedEndMinute: 14 * 60 + 45,
          updatedAt: DateTime.utc(2026, 8, 10),
        ),
      ],
      createdAt: DateTime.utc(2026, 8, 8),
      updatedAt: DateTime.utc(2026, 8, 10),
    );
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(
        AcademicSchedule.empty().putEvent(event),
      ),
      handoff: _RecordingHandoff(),
      preferences: InMemoryAcademicCalendarPreferences(
        state: const AcademicCalendarViewState(
          mode: AcademicCalendarMode.day,
          selectedDate: '2026-08-12',
        ),
      ),
    );

    expect(find.text('MOVED'), findsOneWidget);
    expect(find.text('1:15 PM–2:45 PM'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Planning clinic, schedule, 1:15 PM to 2:45 PM, moved',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'projected occurrence renders cancelled state from the projection',
    (tester) async {
      final event = DaybookEvent(
        eventId: 'event_cancelled_hour',
        title: 'Cancelled office hour',
        startDate: CivilDate(2026, 8, 11),
        endDate: CivilDate(2026, 8, 11),
        timeZoneId: 'America/New_York',
        allDay: false,
        startMinute: 9 * 60,
        endMinute: 10 * 60,
        exceptions: [
          DaybookEventException(
            occurrenceKey: 'event_cancelled_hour/2026-08-11',
            originalDate: CivilDate(2026, 8, 11),
            state: DaybookEventOccurrenceState.cancelled,
            updatedAt: DateTime.utc(2026, 8, 10),
          ),
        ],
        createdAt: DateTime.utc(2026, 8, 8),
        updatedAt: DateTime.utc(2026, 8, 10),
      );
      await _pumpCalendar(
        tester,
        repository: InMemoryAcademicScheduleRepository(
          AcademicSchedule.empty().putEvent(event),
        ),
        handoff: _RecordingHandoff(),
        preferences: InMemoryAcademicCalendarPreferences(
          state: const AcademicCalendarViewState(
            mode: AcademicCalendarMode.day,
            selectedDate: '2026-08-11',
          ),
        ),
      );

      expect(find.text('CANCELLED'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Cancelled office hour, schedule, 9:00 AM to 10:00 AM, cancelled',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'projected occurrence renders an overnight event clipped to this day',
    (tester) async {
      final event = DaybookEvent(
        eventId: 'event_night_train',
        title: 'Night train',
        startDate: CivilDate(2026, 8, 11),
        endDate: CivilDate(2026, 8, 12),
        timeZoneId: 'America/New_York',
        allDay: false,
        startMinute: 23 * 60 + 30,
        endMinute: 75,
        createdAt: DateTime.utc(2026, 8, 8),
        updatedAt: DateTime.utc(2026, 8, 8),
      );
      await _pumpCalendar(
        tester,
        repository: InMemoryAcademicScheduleRepository(
          AcademicSchedule.empty().putEvent(event),
        ),
        handoff: _RecordingHandoff(),
        preferences: InMemoryAcademicCalendarPreferences(
          state: const AcademicCalendarViewState(
            mode: AcademicCalendarMode.day,
            selectedDate: '2026-08-12',
          ),
        ),
      );

      expect(find.text('12:00 AM–1:15 AM'), findsOneWidget);
      expect(find.text('11:30 PM–1:15 AM'), findsNothing);
      expect(
        find.bySemanticsLabel('Night train, schedule, 12:00 AM to 1:15 AM'),
        findsOneWidget,
      );
    },
  );

  testWidgets('general daybook keeps overdue tasks open only on today', (
    tester,
  ) async {
    final schedule = AcademicSchedule.empty().putTask(
      DaybookTask(
        taskId: 'task_open',
        title: 'Return library book',
        dueDate: CivilDate(2026, 8, 10),
        createdAt: DateTime.utc(2026, 8, 8),
        updatedAt: DateTime.utc(2026, 8, 8),
      ),
    );
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(schedule),
      handoff: _RecordingHandoff(),
      preferences: InMemoryAcademicCalendarPreferences(
        state: const AcademicCalendarViewState(
          mode: AcademicCalendarMode.day,
          selectedDate: '2026-08-11',
        ),
      ),
    );
    expect(find.text('STILL OPEN'), findsOneWidget);
    expect(find.text('Return library book'), findsWidgets);

    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(schedule),
      handoff: _RecordingHandoff(),
      calendarKey: const ValueKey('general-daybook-past'),
      preferences: InMemoryAcademicCalendarPreferences(
        state: const AcademicCalendarViewState(
          mode: AcademicCalendarMode.day,
          selectedDate: '2026-08-10',
        ),
      ),
    );
    expect(find.text('STILL OPEN'), findsNothing);
    expect(find.text('Return library book'), findsWidgets);
  });

  testWidgets(
    'general daybook empty schedule adds a task without School setup',
    (tester) async {
      final repository = InMemoryAcademicScheduleRepository();
      await _pumpCalendar(
        tester,
        repository: repository,
        handoff: _RecordingHandoff(),
      );

      await tester.tap(find.byKey(const ValueKey('academic-add-class')));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byKey(const ValueKey('daybook-add-choice-task')));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(DaybookTaskEditor), findsOneWidget);
      expect(find.byKey(const ValueKey('academic-term-name')), findsNothing);
      expect(find.byKey(const ValueKey('academic-course-code')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('daybook-task-title')),
        'Renew library card',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('daybook-task-save')),
      );
      repository.allowWrites = false;
      await tester.tap(find.byKey(const ValueKey('daybook-task-save')));
      await tester.pump(const Duration(milliseconds: 250));

      expect(repository.schedule.tasks, isEmpty);
      expect(find.byType(DaybookTaskEditor), findsOneWidget);
      expect(
        find.text('Couldn’t save this task locally. Try again.'),
        findsOneWidget,
      );

      repository.allowWrites = true;
      await tester.tap(find.byKey(const ValueKey('daybook-task-save')));
      await tester.pumpAndSettle();
      expect(repository.schedule.terms, isEmpty);
      expect(repository.schedule.courses, isEmpty);
      expect(repository.schedule.tasks.single.title, 'Renew library card');
      expect(repository.saveCount, 2);
      expect(find.byType(DaybookTaskEditor), findsNothing);

      await tester.tap(find.byKey(const ValueKey('academic-mode-week')));
      await tester.pumpAndSettle();
      expect(find.text('LOCAL TIME'), findsOneWidget);
      expect(find.text('CAMPUS TIME'), findsNothing);
    },
  );

  testWidgets(
    'general daybook empty schedule saves and renders an event after retry',
    (tester) async {
      final repository = InMemoryAcademicScheduleRepository();
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
        timeZoneIdProvider: () async => 'Etc/UTC',
      );

      await tester.tap(find.byKey(const ValueKey('academic-add-class')));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byKey(const ValueKey('daybook-add-choice-event')));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(DaybookEventEditor), findsOneWidget);
      expect(find.byKey(const ValueKey('academic-term-name')), findsNothing);
      expect(find.byKey(const ValueKey('academic-course-code')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('daybook-event-title')),
        'Call the repair shop',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('daybook-event-save')),
      );
      repository.allowWrites = false;
      await tester.tap(find.byKey(const ValueKey('daybook-event-save')));
      await tester.pumpAndSettle();

      expect(repository.schedule.events, isEmpty);
      expect(find.byType(DaybookEventEditor), findsOneWidget);
      expect(
        find.text('Couldn’t save this event locally. Try again.'),
        findsOneWidget,
      );

      repository.allowWrites = true;
      await tester.tap(find.byKey(const ValueKey('daybook-event-save')));
      await tester.pumpAndSettle();

      expect(repository.schedule.terms, isEmpty);
      expect(repository.schedule.courses, isEmpty);
      expect(repository.schedule.events.single.title, 'Call the repair shop');
      expect(repository.schedule.events.single.timeZoneId, 'Etc/UTC');
      expect(repository.saveCount, 2);
      expect(find.byType(DaybookEventEditor), findsNothing);
      expect(find.text('Call the repair shop'), findsOneWidget);
    },
  );

  testWidgets('event ending at midnight does not render on its end date', (
    tester,
  ) async {
    final event = DaybookEvent(
      eventId: 'event_midnight_end',
      title: 'Ends at midnight',
      startDate: CivilDate(2026, 8, 11),
      endDate: CivilDate(2026, 8, 12),
      timeZoneId: 'America/New_York',
      allDay: false,
      startMinute: 23 * 60,
      endMinute: 0,
      createdAt: DateTime.utc(2026, 8, 8),
      updatedAt: DateTime.utc(2026, 8, 8),
    );
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(
        AcademicSchedule.empty().putEvent(event),
      ),
      handoff: _RecordingHandoff(),
      preferences: InMemoryAcademicCalendarPreferences(
        state: const AcademicCalendarViewState(
          mode: AcademicCalendarMode.day,
          selectedDate: '2026-08-12',
        ),
      ),
    );

    expect(find.text('Ends at midnight'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.bySemanticsLabel('Previous day'));
    await tester.pumpAndSettle();
    expect(find.text('Ends at midnight'), findsOneWidget);
    expect(find.text('11:00 PM–12:00 AM'), findsOneWidget);
  });

  testWidgets(
    'one-off event actions edit and delete without a weekly event scope chooser',
    (tester) async {
      final event = DaybookEvent(
        eventId: 'event_dentist',
        title: 'Dentist appointment',
        startDate: CivilDate(2026, 8, 11),
        endDate: CivilDate(2026, 8, 11),
        timeZoneId: 'America/New_York',
        allDay: false,
        startMinute: 9 * 60,
        endMinute: 10 * 60,
        createdAt: DateTime.utc(2026, 8, 8),
        updatedAt: DateTime.utc(2026, 8, 8),
      );
      final repository = InMemoryAcademicScheduleRepository(
        AcademicSchedule.empty().putEvent(event),
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

      await tester.tap(
        find.byKey(const ValueKey('daybook-event-actions-event_dentist')),
      );
      await tester.pumpAndSettle();
      expect(find.text('EDIT EVENT'), findsOneWidget);
      expect(find.text('DELETE EVENT'), findsOneWidget);
      expect(find.text('THIS EVENT'), findsNothing);
      expect(find.text('ENTIRE SERIES'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('daybook-event-edit')));
      await tester.pumpAndSettle();
      expect(find.byType(DaybookEventEditor), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('daybook-event-title')),
        'Dentist and pharmacy',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('daybook-event-save')),
      );
      await tester.tap(find.byKey(const ValueKey('daybook-event-save')));
      await tester.pumpAndSettle();
      expect(repository.schedule.events.single.title, 'Dentist and pharmacy');

      await tester.tap(
        find.byKey(const ValueKey('daybook-event-actions-event_dentist')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('daybook-event-delete')));
      await tester.pumpAndSettle();
      repository.allowWrites = false;
      await tester.tap(
        find.byKey(const ValueKey('daybook-confirm-delete-event')),
      );
      await tester.pumpAndSettle();
      expect(repository.schedule.events, hasLength(1));
      expect(
        find.text("Couldn’t delete this event locally. Try again."),
        findsOneWidget,
      );

      repository.allowWrites = true;
      await tester.tap(
        find.byKey(const ValueKey('daybook-confirm-delete-event')),
      );
      await tester.pumpAndSettle();
      expect(repository.schedule.events, isEmpty);
    },
  );

  testWidgets(
    'task actions edit and delete while weekly event scope stays absent',
    (tester) async {
      final task = DaybookTask(
        taskId: 'task_print_form',
        title: 'Print the form',
        dueDate: CivilDate(2026, 8, 11),
        dueMinute: 16 * 60,
        createdAt: DateTime.utc(2026, 8, 8),
        updatedAt: DateTime.utc(2026, 8, 8),
      );
      final repository = InMemoryAcademicScheduleRepository(
        AcademicSchedule.empty().putTask(task),
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

      await tester.tap(
        find.byKey(const ValueKey('daybook-task-actions-task_print_form')),
      );
      await tester.pumpAndSettle();
      expect(find.text('EDIT TASK'), findsOneWidget);
      expect(find.text('DELETE TASK'), findsOneWidget);
      expect(find.text('THIS EVENT'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('daybook-task-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('daybook-task-title')),
        'Print and sign the form',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('daybook-task-save')),
      );
      await tester.tap(find.byKey(const ValueKey('daybook-task-save')));
      await tester.pumpAndSettle();
      expect(repository.schedule.tasks.single.title, 'Print and sign the form');
      expect(repository.schedule.tasks.single.dueDate, CivilDate(2026, 8, 11));
      expect(repository.schedule.tasks.single.dueMinute, 16 * 60);

      await tester.tap(
        find.byKey(const ValueKey('daybook-task-actions-task_print_form')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('daybook-task-delete')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('daybook-confirm-delete-task')),
      );
      await tester.pumpAndSettle();
      expect(repository.schedule.tasks, isEmpty);
    },
  );

  testWidgets(
    'weekly event move reopens as restorable and retries without changing siblings',
    (tester) async {
      final event = _weeklyDaybookEvent();
      final repository = InMemoryAcademicScheduleRepository(
        AcademicSchedule.empty().putEvent(event),
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

      await tester.tap(
        find.byKey(const ValueKey('daybook-event-actions-event_studio')),
      );
      await tester.pumpAndSettle();
      expect(find.text('THIS EVENT'), findsOneWidget);
      expect(find.text('ENTIRE SERIES'), findsOneWidget);
      expect(find.text('THIS AND FUTURE EVENTS'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('daybook-scope-this-event')));
      await tester.pumpAndSettle();
      expect(find.text('MOVE EVENT'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('daybook-event-move')));
      await tester.pumpAndSettle();
      expect(find.byType(DaybookEventEditor), findsOneWidget);
      expect(find.byKey(const ValueKey('daybook-event-title')), findsNothing);
      expect(find.byKey(const ValueKey('daybook-event-weekly')), findsNothing);
      expect(
        find.text(
          'Only this occurrence moves. The weekly details stay with the series.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('daybook-event-start-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.descendant(
          of: find.byType(DaybookEventEditor),
          matching: find.byType(SingleChildScrollView),
        ),
        const Offset(0, -350),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('daybook-event-save')));
      await tester.pumpAndSettle();

      final saved = repository.schedule.events.single;
      expect(saved.exceptions, hasLength(1));
      expect(saved.exceptions.single.state, DaybookEventOccurrenceState.moved);
      expect(saved.exceptions.single.originalDate, CivilDate(2026, 8, 11));
      expect(saved.exceptions.single.movedStartDate, CivilDate(2026, 8, 12));
      final siblings = repository.schedule.eventOccurrencesBetween(
        CivilDate(2026, 8, 11),
        CivilDate(2026, 8, 25),
      );
      expect(
        siblings.map((item) => item.originalDate),
        containsAll([CivilDate(2026, 8, 18), CivilDate(2026, 8, 25)]),
      );

      await tester.tap(find.bySemanticsLabel('Next day'));
      await tester.pumpAndSettle();
      expect(find.text('MOVED'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('daybook-event-actions-event_studio')),
      );
      await tester.pumpAndSettle();
      expect(find.text('THIS EVENT'), findsOneWidget);
      expect(find.text('ENTIRE SERIES'), findsOneWidget);
      expect(find.text('THIS AND FUTURE EVENTS'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('daybook-scope-this-event')));
      await tester.pumpAndSettle();
      expect(find.text('RESTORE EVENT'), findsOneWidget);
      expect(find.text('CANCEL EVENT'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('daybook-event-restore')));
      await tester.pumpAndSettle();

      repository.allowWrites = false;
      await tester.tap(
        find.byKey(const ValueKey('daybook-confirm-restore-event')),
      );
      await tester.pumpAndSettle();
      expect(repository.schedule.events.single.exceptions, hasLength(1));
      expect(find.text('MOVED'), findsOneWidget);
      expect(
        find.text("Couldn’t restore this event locally. Try again."),
        findsOneWidget,
      );

      repository.allowWrites = true;
      await tester.tap(
        find.byKey(const ValueKey('daybook-confirm-restore-event')),
      );
      await tester.pumpAndSettle();
      expect(repository.schedule.events.single.exceptions, isEmpty);
      expect(find.text('MOVED'), findsNothing);
      final restored = repository.schedule.eventOccurrencesBetween(
        CivilDate(2026, 8, 11),
        CivilDate(2026, 8, 25),
      );
      expect(restored.map((item) => item.originalDate), [
        CivilDate(2026, 8, 11),
        CivilDate(2026, 8, 18),
        CivilDate(2026, 8, 25),
      ]);
      expect(restored.first.startDate, CivilDate(2026, 8, 11));
      expect(restored.first.startMinute, 9 * 60);
      expect(restored.first.endMinute, 10 * 60);
      expect(repository.saveCount, 3);
    },
  );

  testWidgets(
    'weekly event this-event cancellation remains visible and restorable',
    (tester) async {
      final repository = InMemoryAcademicScheduleRepository(
        AcademicSchedule.empty().putEvent(_weeklyDaybookEvent()),
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

      await tester.tap(
        find.byKey(const ValueKey('daybook-event-actions-event_studio')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('daybook-scope-this-event')));
      await tester.pumpAndSettle();
      expect(find.text('CANCEL EVENT'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('daybook-event-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('daybook-confirm-cancel-event')),
      );
      await tester.pumpAndSettle();
      expect(find.text('CANCELLED'), findsOneWidget);
      expect(
        repository.schedule.events.single.exceptions.single.state,
        DaybookEventOccurrenceState.cancelled,
      );

      await tester.tap(
        find.byKey(const ValueKey('daybook-event-actions-event_studio')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('daybook-scope-this-event')));
      await tester.pumpAndSettle();
      expect(find.text('RESTORE EVENT'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('daybook-event-restore')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('daybook-confirm-restore-event')),
      );
      await tester.pumpAndSettle();
      expect(repository.schedule.events.single.exceptions, isEmpty);
      expect(find.text('CANCELLED'), findsNothing);
    },
  );

  testWidgets(
    'weekly event entire-series edit replaces source and delete removes occurrences',
    (tester) async {
      final repository = InMemoryAcademicScheduleRepository(
        AcademicSchedule.empty().putEvent(_weeklyDaybookEvent()),
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

      await tester.tap(
        find.byKey(const ValueKey('daybook-event-actions-event_studio')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('daybook-scope-entire-series')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('daybook-event-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('daybook-event-title')),
        'Open studio',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('daybook-event-save')),
      );
      await tester.tap(find.byKey(const ValueKey('daybook-event-save')));
      await tester.pumpAndSettle();
      expect(repository.schedule.events.single.title, 'Open studio');

      await tester.tap(
        find.byKey(const ValueKey('daybook-event-actions-event_studio')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('daybook-scope-entire-series')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('daybook-event-delete')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('daybook-confirm-delete-event')),
      );
      await tester.pumpAndSettle();
      expect(repository.schedule.events, isEmpty);
      expect(
        repository.schedule.eventOccurrencesBetween(
          CivilDate(2026, 8, 11),
          CivilDate(2026, 8, 31),
        ),
        isEmpty,
      );
    },
  );

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

  testWidgets('completed plan clears projected weight and its deadline', (
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
      findsNothing,
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

  testWidgets(
    '3-day selection stays in its spread and chevrons advance the next spread',
    (tester) async {
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

      expect(find.text('AUGUST 11–13, 2026'), findsOneWidget);
      await tester.ensureVisible(find.text('WEDNESDAY 12'));
      await tester.pump();
      final thursdayControl = find.byKey(
        const ValueKey('daybook-day-control-2026-08-13'),
      );
      final thursdayTopBeforeSelection = tester.getTopLeft(thursdayControl).dy;
      await tester.tap(find.text('WEDNESDAY 12'));
      await tester.pump();
      expect(find.text('AUGUST 11–13, 2026'), findsOneWidget);
      expect(preferences.state.selectedDate, '2026-08-12');
      expect(preferences.state.threeDayStartDate, '2026-08-11');
      expect(
        tester.getTopLeft(thursdayControl).dy,
        closeTo(thursdayTopBeforeSelection, 0.01),
      );
      final selectedWednesday = tester.getSemantics(
        find.byKey(const ValueKey('daybook-day-control-2026-08-12')),
      );
      expect(
        selectedWednesday.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(
        selectedWednesday.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );

      // Recreating Plans restores both the selected day and the spread it was
      // selected inside instead of quietly shifting the viewport by a day.
      await _pumpCalendar(
        tester,
        repository: InMemoryAcademicScheduleRepository(_scheduleFixture()),
        handoff: _RecordingHandoff(),
        preferences: preferences,
        calendarKey: const ValueKey('restored-three-day-spread'),
      );
      expect(find.text('AUGUST 11–13, 2026'), findsOneWidget);

      await tester.ensureVisible(find.text('THURSDAY 13'));
      await tester.pump();
      await tester.tap(find.text('THURSDAY 13'));
      await tester.pump();

      // Choosing a visible day changes selection, not the three-day window
      // underneath the finger.
      expect(find.text('AUGUST 11–13, 2026'), findsOneWidget);
      await tester.ensureVisible(find.bySemanticsLabel('Next 3 days'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Next 3 days'));
      await tester.pump();

      expect(find.text('AUGUST 14–16, 2026'), findsOneWidget);
      expect(preferences.state.selectedDate, '2026-08-14');
      expect(preferences.state.threeDayStartDate, '2026-08-14');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'month day controls state their destination without moving scroll',
    (tester) async {
      await _pumpCalendar(
        tester,
        repository: InMemoryAcademicScheduleRepository(_scheduleFixture()),
        handoff: _RecordingHandoff(),
      );

      final day = find.byKey(const ValueKey('academic-month-day-2026-08-12'));
      await tester.tap(day);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('month-selected-wash-2026-08-12')),
        findsOneWidget,
      );
      expect(find.text('WED 12 · BACK TO TODAY'), findsOneWidget);
      final monthContext = find.byKey(
        const ValueKey('month-selected-context-control'),
      );
      expect(tester.getRect(monthContext).height, greaterThanOrEqualTo(44));
      final semantics = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'August 12, 2026')),
      );
      expect(
        semantics.getSemanticsData().hint,
        'Showing this day below the calendar',
      );
      expect(tester.getTopLeft(day).dy, greaterThan(0));

      await tester.tap(monthContext);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('month-selected-wash-2026-08-11')),
        findsOneWidget,
      );
      expect(find.text('TUE 11 · TODAY'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected span row keeps Today reachable without shifting range',
    (tester) async {
      await _pumpCalendar(
        tester,
        repository: InMemoryAcademicScheduleRepository(_scheduleFixture()),
        handoff: _RecordingHandoff(),
        preferences: InMemoryAcademicCalendarPreferences(
          state: const AcademicCalendarViewState(
            mode: AcademicCalendarMode.threeDay,
            selectedDate: '2026-08-12',
            threeDayStartDate: '2026-08-11',
          ),
        ),
      );

      expect(find.text('AUGUST 11–13, 2026'), findsOneWidget);
      final today = find.byKey(const ValueKey('calendar-back-to-today'));
      expect(today, findsOneWidget);
      await tester.tap(today);
      await tester.pump();

      expect(find.text('AUGUST 11–13, 2026'), findsOneWidget);
      expect(today, findsNothing);
      final selectedToday = tester.getSemantics(
        find.byKey(const ValueKey('daybook-day-control-2026-08-11')),
      );
      expect(
        selectedToday.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selected span Today and Plan actions reflow at 200% text', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(_scheduleFixture()),
      handoff: _RecordingHandoff(),
      preferences: InMemoryAcademicCalendarPreferences(
        state: const AcademicCalendarViewState(
          mode: AcademicCalendarMode.threeDay,
          selectedDate: '2026-08-12',
          threeDayStartDate: '2026-08-11',
        ),
      ),
      size: const Size(320, 568),
      textScale: 2,
    );

    final today = find.byKey(const ValueKey('calendar-back-to-today'));
    final plan = find.byKey(const ValueKey('calendar-plan-selected-day'));
    await tester.scrollUntilVisible(
      today,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(today, findsOneWidget);
    expect(plan, findsOneWidget);
    expect(tester.getRect(today).width, greaterThanOrEqualTo(44));
    expect(tester.getRect(today).height, greaterThanOrEqualTo(44));
    expect(tester.getRect(plan).width, greaterThanOrEqualTo(44));
    expect(tester.getRect(plan).height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back to today appears when today leaves the visible span', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(_scheduleFixture()),
      handoff: _RecordingHandoff(),
      preferences: InMemoryAcademicCalendarPreferences(
        state: const AcademicCalendarViewState(
          mode: AcademicCalendarMode.week,
          selectedDate: '2026-08-19',
        ),
      ),
    );

    expect(find.text('BACK TO TODAY'), findsOneWidget);
    await tester.tap(find.text('BACK TO TODAY'));
    await tester.pump();
    expect(find.text('BACK TO TODAY'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an early day choice wins over delayed restored preferences', (
    tester,
  ) async {
    final preferences = _DelayedAcademicCalendarPreferences(
      const AcademicCalendarViewState(
        mode: AcademicCalendarMode.day,
        selectedDate: '2026-08-10',
      ),
    );
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(_scheduleFixture()),
      handoff: _RecordingHandoff(),
      preferences: preferences,
    );

    await tester.tap(
      find.byKey(const ValueKey('academic-month-day-2026-08-12')),
    );
    await tester.pump();
    preferences.completeLoad();
    await tester.pump();

    expect(find.byKey(const ValueKey('academic-month-folio')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('month-selected-wash-2026-08-12')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an explicit early Month tap wins over delayed view restore', (
    tester,
  ) async {
    final preferences = _DelayedAcademicCalendarPreferences(
      const AcademicCalendarViewState(
        mode: AcademicCalendarMode.day,
        selectedDate: '2026-08-10',
      ),
    );
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(_scheduleFixture()),
      handoff: _RecordingHandoff(),
      preferences: preferences,
    );

    await tester.tap(find.byKey(const ValueKey('academic-mode-month')));
    await tester.pump();
    preferences.completeLoad();
    await tester.pump();

    expect(find.byKey(const ValueKey('academic-month-folio')), findsOneWidget);
    expect(find.byKey(const ValueKey('academic-day-view')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid view saves are serialized in the order they were chosen', (
    tester,
  ) async {
    final preferences = _DelayedSaveAcademicCalendarPreferences();
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(_scheduleFixture()),
      handoff: _RecordingHandoff(),
      preferences: preferences,
    );

    await tester.tap(
      find.byKey(const ValueKey('academic-month-day-2026-08-12')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('academic-month-day-2026-08-13')),
    );
    await tester.pump();

    expect(preferences.saves, hasLength(1));
    expect(preferences.saves.single.selectedDate, '2026-08-12');
    preferences.completeSave(0);
    await tester.pump();

    expect(preferences.saves, hasLength(2));
    expect(preferences.saves.last.selectedDate, '2026-08-13');
    preferences.completeSave(1);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing calendar view returns its new view to the top', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      repository: InMemoryAcademicScheduleRepository(_scheduleFixture()),
      handoff: _RecordingHandoff(),
    );

    final scrollable = find.byType(Scrollable).first;
    await tester.dragFrom(const Offset(215, 700), const Offset(0, -100));
    await tester.pump();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );

    await tester.tap(find.byKey(const ValueKey('academic-mode-week')));
    await tester.pump();
    expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);
    expect(tester.takeException(), isNull);
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

Future<void> _acceptPlaceSearch(WidgetTester tester) async {
  await tester.tap(find.text('SEARCH PLACES WITH GOOGLE'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('USE PLACE SEARCH'));
  await tester.pumpAndSettle();
}

Future<void> _expectDeferredAccessCannotActivateReplacement(
  WidgetTester tester, {
  required bool replaceController,
}) async {
  final coreGate = Completer<bool>();
  final identity = _TestPlaceSearchIdentity(coreGate: coreGate);
  final oldFactory = _TestPlaceSearchFactory(
    service: _RecordingPlaceSearchService(),
    identity: identity,
  );
  final newFactory = _TestPlaceSearchFactory(
    service: _RecordingPlaceSearchService(),
  );
  var controller = DaybookPlaceFieldsController();
  DaybookPlaceSearchFactory factory = oldFactory;
  late StateSetter rebuild;
  await _pumpDaybookWidget(
    tester,
    StatefulBuilder(
      builder: (context, setState) {
        rebuild = setState;
        return DaybookPlaceFields(
          controller: controller,
          keyPrefix: 'deferred-place',
          placeSearchFactory: factory,
        );
      },
    ),
  );

  await tester.tap(find.text('SEARCH PLACES WITH GOOGLE'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('USE PLACE SEARCH'));
  await tester.pump();
  expect(identity.ensureCoreCalls, 1);

  rebuild(() {
    if (replaceController) {
      controller = DaybookPlaceFieldsController(
        initialPlace: DaybookPlace(savedName: 'Replacement form'),
      );
    } else {
      factory = newFactory;
    }
  });
  await tester.pump();
  coreGate.complete(true);
  await tester.pumpAndSettle();

  expect(
    find.byKey(const ValueKey('deferred-place-search-query')),
    findsNothing,
  );
  expect(oldFactory.controllerCreateCalls, 0);
  expect(newFactory.controllerCreateCalls, 0);
  if (replaceController) {
    final savedName = tester.widget<TextField>(
      find.byKey(const ValueKey('deferred-place-saved-name')),
    );
    expect(savedName.controller!.text, 'Replacement form');
  }
}

Future<double> _renderedPlaceSearchSecondaryContrast(
  WidgetTester tester, {
  required Finder card,
  required String secondaryText,
}) async {
  const pixelRatio = 3.0;
  final boundaryFinder = find.byKey(_daybookWidgetCaptureKey);
  final boundary = tester.renderObject<RenderRepaintBoundary>(boundaryFinder);
  final capture = (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (rgba: rgba!, width: image.width);
    } finally {
      image.dispose();
    }
  }))!;
  final paragraph = tester.renderObject<RenderParagraph>(
    find.text(secondaryText),
  );
  final boundaryOrigin = tester.getTopLeft(boundaryFinder);
  final cardRect = tester.getRect(card);
  var lowestGlyphContrast = double.infinity;

  for (var index = 0; index < secondaryText.length; index++) {
    if (secondaryText[index].trim().isEmpty) continue;
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: index, extentOffset: index + 1),
    );
    for (final box in boxes) {
      final globalRect = Rect.fromPoints(
        paragraph.localToGlobal(Offset(box.left, box.top)),
        paragraph.localToGlobal(Offset(box.right, box.bottom)),
      );
      final backgroundPoint = Offset(
        globalRect.center.dx,
        (globalRect.bottom + 2).clamp(cardRect.top + 1, cardRect.bottom - 1),
      );
      final background = _renderedPixel(
        capture.rgba,
        imageWidth: capture.width,
        pixelRatio: pixelRatio,
        logicalPoint: backgroundPoint - boundaryOrigin,
      );
      var glyphContrast = 0.0;
      final localRect = globalRect.shift(-boundaryOrigin);
      final left = (localRect.left * pixelRatio).floor();
      final top = (localRect.top * pixelRatio).floor();
      final right = (localRect.right * pixelRatio).ceil();
      final bottom = (localRect.bottom * pixelRatio).ceil();
      for (var y = top; y < bottom; y++) {
        for (var x = left; x < right; x++) {
          final pixel = _renderedPixelAt(capture.rgba, capture.width, x, y);
          final contrast = _contrastRatio(pixel, background);
          if (contrast > glyphContrast) glyphContrast = contrast;
        }
      }
      if (glyphContrast < lowestGlyphContrast) {
        lowestGlyphContrast = glyphContrast;
      }
    }
  }
  return lowestGlyphContrast;
}

Color _renderedPixel(
  ByteData rgba, {
  required int imageWidth,
  required double pixelRatio,
  required Offset logicalPoint,
}) => _renderedPixelAt(
  rgba,
  imageWidth,
  (logicalPoint.dx * pixelRatio).round(),
  (logicalPoint.dy * pixelRatio).round(),
);

Color _renderedPixelAt(ByteData rgba, int imageWidth, int x, int y) {
  final offset = (y * imageWidth + x) * 4;
  return Color.fromARGB(
    rgba.getUint8(offset + 3),
    rgba.getUint8(offset),
    rgba.getUint8(offset + 1),
    rgba.getUint8(offset + 2),
  );
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

Future<void> _openPlaceSearchConsentWithKeyboard(WidgetTester tester) async {
  for (var index = 0; index < 5; index++) {
    await _pressTab(tester);
  }
  expect(_focusIsWithin(find.text('SEARCH PLACES WITH GOOGLE')), isTrue);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
  expect(find.text('USE PLACE SEARCH'), findsOneWidget);
}

Future<void> _pressTab(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
}

Future<void> _pressShiftTab(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
  await tester.pumpAndSettle();
}

bool _focusIsWithin(Finder finder) {
  final focusedContext = FocusManager.instance.primaryFocus?.context;
  if (focusedContext is! Element) return false;
  final targets = finder.evaluate().toSet();
  if (targets.contains(focusedContext)) return true;
  var within = false;
  focusedContext.visitAncestorElements((ancestor) {
    within = targets.contains(ancestor);
    return !within;
  });
  if (within) return true;
  for (final target in targets) {
    target.visitAncestorElements((ancestor) {
      within = identical(ancestor, focusedContext);
      return !within;
    });
    if (within) return true;
  }
  return false;
}

Future<void> _capturePlaceSearchFrame(WidgetTester tester, String name) async {
  if (!_capturePlaceSearch) return;
  await expectLater(
    find.byKey(_daybookWidgetCaptureKey),
    matchesGoldenFile('goldens/task_4_place_search_$name.png'),
  );
}

Future<void> _pumpDaybookWidget(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(430, 932),
  double textScale = 1,
  Locale? locale,
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
    RepaintBoundary(
      key: _daybookWidgetCaptureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: locale == null
            ? const [Locale('en', 'US')]
            : [locale],
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required InMemoryAcademicScheduleRepository repository,
  required NotebookHandoff handoff,
  AcademicCalendarPreferences? preferences,
  DirectionsLauncher? directionsLauncher,
  DaybookPreferences? daybookPreferences,
  DaybookPlaceSearchFactory? placeSearchFactory,
  Future<String> Function()? timeZoneIdProvider,
  Key? calendarKey,
  List<Quest> quests = const [],
  Size size = const Size(430, 932),
  double textScale = 1,
  GameState? state,
  void Function(Quest quest, Offset anchor)? onCompleteQuest,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.binding.setSurfaceSize(null);
  });
  final calendarState = state ?? GameState();
  calendarState.reduceMotion = true;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: CalendarPage(
          key: calendarKey,
          state: calendarState,
          quests: quests,
          onAdd: (_) => true,
          onCompleteQuest: onCompleteQuest,
          scheduleRepository: repository,
          calendarPreferences:
              preferences ?? InMemoryAcademicCalendarPreferences(),
          notebookHandoff: handoff,
          directionsLauncher: directionsLauncher,
          daybookPreferences: daybookPreferences,
          placeSearchFactory:
              placeSearchFactory ?? const ProductionDaybookPlaceSearchFactory(),
          timeZoneIdProvider: timeZoneIdProvider,
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
  CampusPlace? place,
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
    place:
        place ??
        CampusPlace(
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

AcademicSchedule _generalDaybookSchedule() {
  final createdAt = DateTime.utc(2026, 8, 8);
  final schedule = _scheduleFixture()
      .putEvent(
        DaybookEvent(
          eventId: 'event_library_closed',
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
          eventId: 'event_project_meeting',
          title: 'Project meeting',
          startDate: CivilDate(2026, 8, 11),
          endDate: CivilDate(2026, 8, 11),
          timeZoneId: 'America/New_York',
          allDay: false,
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      )
      .putTask(
        DaybookTask(
          taskId: 'task_send_form',
          title: 'Send the form',
          dueDate: CivilDate(2026, 8, 11),
          dueMinute: 16 * 60,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      )
      .putTask(
        DaybookTask(
          taskId: 'task_return_book',
          title: 'Return library book',
          dueDate: CivilDate(2026, 8, 10),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      )
      .putWorkItem(
        AcademicWorkItem(
          workId: 'work_daybook_problem_set',
          courseId: 'course_ece_345',
          kind: AcademicWorkKind.assignment,
          title: 'Problem set 4',
          dueDate: CivilDate(2026, 8, 11),
          dueMinute: 18 * 60,
          updatedAt: createdAt,
        ),
      );
  return schedule.putStudyPlan(
    plan: AcademicStudyPlan(
      workId: 'work_daybook_problem_set',
      totalMinutes: 45,
      sessionMinutes: 45,
      dailyStartMinute: 8 * 60,
      dailyEndMinute: 20 * 60,
      updatedAt: createdAt,
    ),
    blocks: [
      AcademicStudyBlock(
        studyBlockId: 'study_daybook_problem_set',
        workId: 'work_daybook_problem_set',
        date: CivilDate(2026, 8, 11),
        startMinute: 15 * 60,
        endMinute: 15 * 60 + 45,
        updatedAt: createdAt,
      ),
    ],
  );
}

DaybookEvent _weeklyDaybookEvent() => DaybookEvent(
  eventId: 'event_studio',
  title: 'Studio hour',
  startDate: CivilDate(2026, 8, 11),
  endDate: CivilDate(2026, 8, 11),
  timeZoneId: 'America/New_York',
  allDay: false,
  startMinute: 9 * 60,
  endMinute: 10 * 60,
  weeklyRule: WeeklyEventRule(
    weekdays: const {DateTime.tuesday},
    endsOn: CivilDate(2026, 8, 25),
  ),
  createdAt: DateTime.utc(2026, 8, 8),
  updatedAt: DateTime.utc(2026, 8, 8),
);

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

final class _RecordingDirectionsLauncher implements DirectionsLauncher {
  _RecordingDirectionsLauncher({this.succeeds = true});

  final bool succeeds;
  final List<(MapProvider, String)> calls = [];

  @override
  Future<bool> open(DaybookPlace place, MapProvider provider) async {
    calls.add((provider, place.savedName));
    return succeeds;
  }
}

final class _TestPlaceSearchFactory implements DaybookPlaceSearchFactory {
  _TestPlaceSearchFactory({
    required this.service,
    _TestPlaceSearchIdentity? identity,
    _TestPlaceSearchAppCheck? appCheck,
    InMemoryDaybookPreferences? preferences,
  }) : identity = identity ?? _TestPlaceSearchIdentity(),
       appCheck = appCheck ?? _TestPlaceSearchAppCheck(),
       preferences = preferences ?? InMemoryDaybookPreferences();

  final _RecordingPlaceSearchService service;
  final _TestPlaceSearchIdentity identity;
  final _TestPlaceSearchAppCheck appCheck;
  final InMemoryDaybookPreferences preferences;
  int controllerCreateCalls = 0;
  final List<String> locales = [];

  @override
  bool get enabled => true;

  @override
  PlaceSearchAccess createAccess({
    required PlaceSearchConsentRequest requestConsent,
  }) => PlaceSearchAccess(
    enabled: true,
    preferences: preferences,
    identity: identity,
    appCheck: appCheck,
    requestConsent: requestConsent,
    createInstallId: () => '00000000-0000-4000-8000-000000000001',
  );

  @override
  PlaceSearchController createController({
    required String installId,
    required String locale,
    required PlaceSearchAuthorizationLease authorization,
  }) {
    controllerCreateCalls += 1;
    locales.add(locale);
    return PlaceSearchController(
      service: service,
      installId: installId,
      locale: locale,
      authorization: authorization,
      createSessionToken: () =>
          '00000000-0000-4000-8000-${controllerCreateCalls.toString().padLeft(12, '0')}',
    );
  }
}

final class _TestPlaceSearchIdentity implements PlaceSearchIdentity {
  _TestPlaceSearchIdentity({this.coreGate});

  final Completer<bool>? coreGate;
  bool _signedIn = false;
  int ensureCoreCalls = 0;
  int signInCalls = 0;

  @override
  bool get signedIn => _signedIn;

  @override
  Future<bool> ensureCoreAvailable() async {
    ensureCoreCalls += 1;
    return coreGate?.future ?? true;
  }

  @override
  Future<bool> signInAnonymously() async {
    signInCalls += 1;
    _signedIn = true;
    return true;
  }
}

final class _TestPlaceSearchAppCheck implements PlaceSearchAppCheck {
  _TestPlaceSearchAppCheck({this.succeeds = true});

  final bool succeeds;
  int activateCalls = 0;

  @override
  Future<bool> activate() async {
    activateCalls += 1;
    return succeeds;
  }
}

final class _RecordingPlaceSearchService implements PlaceSearchService {
  _RecordingPlaceSearchService({
    this.failAutocomplete = false,
    this.blockAutocomplete = false,
  });

  final bool failAutocomplete;
  final bool blockAutocomplete;
  final List<String> autocompleteQueries = [];
  final List<String> detailPlaceIds = [];
  final Map<String, Completer<List<PlaceSuggestion>>> _pending = {};

  @override
  Future<List<PlaceSuggestion>> autocomplete({
    required String query,
    required String sessionToken,
    required String installId,
    required String locale,
  }) {
    autocompleteQueries.add(query);
    if (failAutocomplete) {
      return Future<List<PlaceSuggestion>>.error(
        const PlaceSearchUnavailable(),
      );
    }
    if (blockAutocomplete) {
      return (_pending[query] ??= Completer<List<PlaceSuggestion>>()).future;
    }
    return Future.value([_suggestion(query)]);
  }

  void completeAutocomplete(String query) {
    _pending[query]!.complete([_suggestion(query)]);
  }

  @override
  Future<PlaceSelection> details({
    required PlaceSuggestion suggestion,
    required String originalQuery,
    required String sessionToken,
    required String installId,
    required String locale,
  }) async {
    detailPlaceIds.add(suggestion.placeId);
    return PlaceSelection(
      provider: suggestion.provider,
      placeId: suggestion.placeId,
      originalQuery: originalQuery,
      primaryText: 'Confirmed ${suggestion.primaryText}',
      secondaryText: suggestion.secondaryText,
    );
  }

  PlaceSuggestion _suggestion(String query) {
    final clean = query.trim();
    return PlaceSuggestion(
      provider: 'google',
      placeId: 'place-${clean.replaceAll(' ', '-')}',
      primaryText: 'Provider $clean',
      secondaryText: 'Provider address for $clean',
    );
  }
}

final class _BlockingDaybookPreferences implements DaybookPreferences {
  final Completer<MapProvider?> _load = Completer<MapProvider?>();
  int loadCalls = 0;

  @override
  Future<MapProvider?> loadPreferredMapProvider() {
    loadCalls += 1;
    return _load.future;
  }

  @override
  Future<void> savePreferredMapProvider(MapProvider? provider) async {}
}

final class _DelayedAcademicCalendarPreferences
    implements AcademicCalendarPreferences {
  _DelayedAcademicCalendarPreferences(this.state);

  final AcademicCalendarViewState state;
  final Completer<AcademicCalendarViewState> _load = Completer();

  void completeLoad() => _load.complete(state);

  @override
  Future<AcademicCalendarViewState> load() => _load.future;

  @override
  Future<void> save(AcademicCalendarViewState state) async {}
}

final class _DelayedSaveAcademicCalendarPreferences
    implements AcademicCalendarPreferences {
  final List<AcademicCalendarViewState> saves = [];
  final List<Completer<void>> _saveGates = [];

  void completeSave(int index) => _saveGates[index].complete();

  @override
  Future<AcademicCalendarViewState> load() async =>
      const AcademicCalendarViewState(mode: AcademicCalendarMode.month);

  @override
  Future<void> save(AcademicCalendarViewState state) {
    saves.add(state);
    final gate = Completer<void>();
    _saveGates.add(gate);
    return gate.future;
  }
}
