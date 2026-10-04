// Add your classes (2026-10-03): the one sheet every way in opens. The Plans
// doorway, the Plans ADD menu and every .ics opened from outside all land
// here; Room of Days files still apply through the original importer.
import 'dart:convert';

import 'package:emberkeep/academic_calendar/data/academic_calendar_preferences.dart';
import 'package:emberkeep/academic_calendar/data/academic_schedule_repository.dart';
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_file_inbox.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_file_picker.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/academic_calendar/import/calendar_link.dart';
import 'package:emberkeep/academic_calendar/services/notebook_handoff.dart';
import 'package:emberkeep/academic_calendar/widgets/add_classes_sheet.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/screens/calendar.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/glass_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/calendar_export_samples.dart';
import 'support/rutgers_fall_2026_ics_fixture.dart';

const _capture = bool.fromEnvironment('CAPTURE_ACADEMIC_IMPORT');

Finder _key(String value) => find.byKey(ValueKey(value));

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

  // Sunday Oct 4 2026, 19:30 in New York. Built from an instant so the day is
  // the same on a host in another zone (Codemagic's Mac is not on New York
  // time); assertions below avoid zone-dependent day words.
  setUp(() => Clock.freeze(DateTime.utc(2026, 10, 4, 23, 30).toLocal()));
  tearDown(Clock.reset);

  group('the sheet', () {
    testWidgets('picker cancellation stays on the ways in and writes nothing', (
      tester,
    ) async {
      final saves = _Saves();
      await _pumpSheet(tester, picker: const _FakePicker(null), saves: saves);

      await tester.tap(_key('add-classes-file'));
      await tester.pumpAndSettle();

      expect(saves.count, 0);
      expect(find.text('FROM A CALENDAR FILE'), findsOneWidget);
      expect(_key('add-classes-confirm'), findsNothing);
      expect(_key('add-classes-error'), findsNothing);
    });

    testWidgets('a file that is not a calendar stays open and saves nothing', (
      tester,
    ) async {
      final saves = _Saves();
      await _pumpSheet(
        tester,
        picker: const _FakePicker(
          AcademicScheduleImportSource(
            name: 'notes.ics',
            contents: 'Meet Sam after lab',
          ),
        ),
        saves: saves,
      );

      await tester.tap(_key('add-classes-file'));
      await tester.pumpAndSettle();

      expect(saves.count, 0);
      expect(_key('add-classes-error'), findsOneWidget);
      expect(_key('add-classes-sheet'), findsOneWidget);
      expect(find.text('FROM A CALENDAR FILE'), findsOneWidget);
    });

    testWidgets('an empty calendar points to typing them in', (tester) async {
      final saves = _Saves();
      await _pumpSheet(
        tester,
        picker: const _FakePicker(
          AcademicScheduleImportSource(
            name: 'empty.ics',
            contents: 'BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n',
          ),
        ),
        saves: saves,
      );

      await tester.tap(_key('add-classes-file'));
      await tester.pumpAndSettle();

      expect(find.text('No weekly classes here'), findsOneWidget);
      await tester.tap(_key('add-classes-type-instead'));
      await tester.pumpAndSettle();
      expect(_key('add-classes-quick-name'), findsOneWidget);
      expect(saves.count, 0);
    });

    testWidgets(
      'his Room of Days file reviews exactly; a failed save stays open',
      (tester) async {
        final saves = _Saves(succeed: false);
        await _pumpSheet(
          tester,
          picker: _rutgersPicker(includeIgnoredEvent: true),
          saves: saves,
        );

        await tester.tap(_key('add-classes-file'));
        await tester.pumpAndSettle();

        expect(find.text('Your Room of Days file'), findsOneWidget);
        expect(find.text('Fall 2026'), findsOneWidget);
        expect(find.text('168 MEETINGS'), findsOneWidget);
        for (final title in const [
          'Electronics Devices',
          'Electron Devices Lab',
          'Computer Architecture & Assembly Language',
          'Computer Architecture Lab',
          'Linear Systems & Signals',
          'Introduction to Discrete Structures II',
        ]) {
          expect(find.text(title), findsOneWidget);
        }
        expect(find.text('ADD 6 COURSES'), findsOneWidget);
        expect(saves.count, 0);

        await _tapVisible(tester, _key('add-classes-confirm'));

        expect(saves.count, 1);
        expect(_key('add-classes-error'), findsOneWidget);
        expect(
          find.text('Couldn’t save on this phone just now. Try again.'),
          findsOneWidget,
        );
        expect(find.text('Your Room of Days file'), findsOneWidget);
      },
    );

    testWidgets('class reminders stay off until the result turns them on', (
      tester,
    ) async {
      final saves = _Saves();
      var asked = 0;
      await _pumpSheet(
        tester,
        picker: _rutgersPicker(),
        saves: saves,
        requestReminderPermission: () async {
          asked += 1;
          return true;
        },
      );

      await tester.tap(_key('add-classes-file'));
      await tester.pumpAndSettle();
      await _tapVisible(tester, _key('add-classes-confirm'));

      expect(saves.count, 1);
      expect(asked, 0);
      expect(_reminders(saves.last!), isEmpty);
      expect(find.text('6 courses in Plans'), findsOneWidget);
      expect(
        tester.widget<Text>(_key('add-classes-result-line')).data,
        allOf(contains('Fall 2026'), contains('8:30 AM')),
      );
      final reminderSwitch = _key('add-classes-reminder-switch');
      expect(tester.widget<GlassSwitch>(reminderSwitch).value, isFalse);
      expect(_key('add-classes-reminder-10'), findsNothing);

      await _tapVisible(tester, reminderSwitch);

      expect(asked, 1);
      expect(tester.widget<GlassSwitch>(reminderSwitch).value, isTrue);
      expect(saves.count, 2);
      expect(_reminders(saves.last!), {10});
      expect(
        saves.last!.meetingSeries.where((item) => item.reminders.isNotEmpty),
        hasLength(12),
      );

      await _tapVisible(tester, _key('add-classes-reminder-15'));
      expect(saves.count, 3);
      expect(_reminders(saves.last!), {15});

      await _tapVisible(tester, reminderSwitch);
      expect(asked, 1); // turning off never asks
      expect(_reminders(saves.last!), isEmpty);
      expect(tester.widget<GlassSwitch>(reminderSwitch).value, isFalse);
    });

    testWidgets('declined notifications leave reminders off, kindly', (
      tester,
    ) async {
      final saves = _Saves();
      await _pumpSheet(
        tester,
        picker: _rutgersPicker(),
        saves: saves,
        requestReminderPermission: () async => false,
      );
      await tester.tap(_key('add-classes-file'));
      await tester.pumpAndSettle();
      await _tapVisible(tester, _key('add-classes-confirm'));
      await _tapVisible(tester, _key('add-classes-reminder-switch'));

      expect(saves.count, 1);
      expect(
        tester.widget<GlassSwitch>(_key('add-classes-reminder-switch')).value,
        isFalse,
      );
      expect(
        tester.widget<Text>(_key('add-classes-reminder-line')).data,
        contains('Settings'),
      );
      expect(_key('add-classes-error'), findsNothing);
    });

    testWidgets('a pasted link is read once and not kept anywhere', (
      tester,
    ) async {
      const link =
          'https://calendar.google.com/calendar/ical/jordan.lee%40gmail.com/'
          'private-8f2c41d9a7e0b3c5/basic.ics';
      final saves = _Saves();
      final fetcher = _FakeFetcher(googleCalendarStudentExport());
      await _pumpSheet(
        tester,
        picker: const _FakePicker(null),
        saves: saves,
        linkFetcher: fetcher,
      );

      await tester.tap(_key('add-classes-link'));
      await tester.pumpAndSettle();
      expect(_key('add-classes-link-privacy'), findsOneWidget);
      await tester.enterText(_key('add-classes-link-field'), link);
      await tester.pump();
      await _tapVisible(tester, _key('add-classes-read-link'));

      expect(fetcher.reads, hasLength(1));
      expect(fetcher.reads.single.uri.toString(), link);
      expect(find.text('Pick your classes'), findsOneWidget);
      expect(find.text('FROM GOOGLE CALENDAR LINK'), findsOneWidget);
      expect(find.text('ADD 4 COURSES'), findsOneWidget);
      expect(find.textContaining('PROBABLY NOT CLASSES'), findsOneWidget);
      expect(find.text('Gym'), findsNothing); // folded away, unchecked

      // Once read, the link is gone from the field too.
      await _tapVisible(tester, _key('add-classes-back'));
      await _tapVisible(tester, _key('add-classes-link'));
      expect(
        tester
            .widget<TextField>(_key('add-classes-link-field'))
            .controller!
            .text,
        isEmpty,
      );

      await tester.enterText(_key('add-classes-link-field'), link);
      await tester.pump();
      await _tapVisible(tester, _key('add-classes-read-link'));
      await _tapVisible(tester, _key('add-classes-confirm'));
      expect(saves.count, 1);
      final saved = jsonEncode(saves.last!.toJson());
      expect(saved, isNot(contains('private-8f2c41d9a7e0b3c5')));
      expect(saved, isNot(contains('calendar.google.com')));
    });

    testWidgets('a web page and a busy-only calendar each explain themselves', (
      tester,
    ) async {
      final fetcher = _FakeFetcher('<!doctype html><title>Sign in</title>');
      await _pumpSheet(
        tester,
        picker: const _FakePicker(null),
        saves: _Saves(),
        linkFetcher: fetcher,
      );
      await tester.tap(_key('add-classes-link'));
      await tester.pumpAndSettle();
      await tester.enterText(
        _key('add-classes-link-field'),
        'https://outlook.office365.com/owa/calendar/abc/def/calendar.html',
      );
      await tester.pump();
      await _tapVisible(tester, _key('add-classes-read-link'));
      expect(
        tester.widget<Text>(_key('add-classes-error')).data,
        contains('web page'),
      );
      expect(_key('add-classes-link-field'), findsOneWidget);

      fetcher.body = outlookExport(busyOnly: true);
      await _tapVisible(tester, _key('add-classes-read-link'));
      expect(_key('add-classes-busy-only'), findsOneWidget);
      // Times without names are never guessed into classes.
      expect(find.text('PICK AT LEAST ONE'), findsOneWidget);
      expect(find.text('Busy'), findsOneWidget); // listed, unchecked
      await _tapVisible(tester, _key('add-classes-new-link'));
      expect(_key('add-classes-link-field'), findsOneWidget);
    });

    testWidgets(
      'two terms in one file: this term is checked, the other waits',
      (tester) async {
        final saves = _Saves();
        await _pumpSheet(
          tester,
          picker: _FakePicker(
            AcademicScheduleImportSource(
              name: 'jordan.lee.uiuc@gmail.com.ics',
              contents: googleTwoTermExport(),
            ),
          ),
          saves: saves,
        );
        await tester.tap(_key('add-classes-file'));
        await tester.pumpAndSettle();

        expect(find.text('Fall 2026'), findsOneWidget);
        expect(find.text('ADD 4 COURSES'), findsOneWidget);
        expect(find.text('Also here: Spring 2026, 4 courses.'), findsOneWidget);
        expect(find.text('Discrete Structures'), findsNothing); // CS 173

        await _tapVisible(tester, _key('add-classes-term-0'));
        expect(find.text('Spring 2026'), findsOneWidget);
        expect(find.text('Discrete Structures'), findsOneWidget);
        expect(find.text('Also here: Fall 2026, 4 courses.'), findsOneWidget);

        await _tapVisible(tester, _key('add-classes-term-1'));
        await _tapVisible(tester, _key('add-classes-confirm'));
        expect(saves.last!.terms.single.name, 'Fall 2026');
      },
    );

    testWidgets('typing classes in adds each one and offers reminders', (
      tester,
    ) async {
      final saves = _Saves();
      await _pumpSheet(tester, picker: const _FakePicker(null), saves: saves);
      await tester.tap(_key('add-classes-type'));
      await tester.pumpAndSettle();

      await _tapVisible(tester, _key('add-classes-quick-add'));
      expect(
        tester.widget<Text>(_key('add-classes-error')).data,
        'Give the class a name.',
      );
      expect(saves.count, 0);

      await tester.enterText(
        _key('add-classes-quick-name'),
        'MATH 152 Calculus II',
      );
      await _tapVisible(tester, _key('add-classes-day-2'));
      await _tapVisible(tester, _key('add-classes-day-4'));
      await _tapVisible(tester, _key('add-classes-quick-add'));
      expect(saves.count, 1);
      expect(find.text('ADDED · 1'), findsOneWidget);

      await _tapVisible(tester, _key('add-classes-quick-done'));
      expect(find.text('1 class in Plans'), findsOneWidget);
      expect(_key('add-classes-reminders'), findsOneWidget);
      final course = saves.last!.courses.single;
      expect(course.code, 'MATH 152');
      expect(course.title, 'Calculus II');
    });
  });

  group('in Plans', () {
    testWidgets('the doorway shows only while there are no classes', (
      tester,
    ) async {
      final repository = InMemoryAcademicScheduleRepository();
      await _pumpCalendar(
        tester,
        repository: repository,
        picker: _rutgersPicker(),
      );
      // Plans ends on the doorway: after the day, never above it.
      await tester.scrollUntilVisible(
        _key('add-classes-doorway'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(CalendarPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(_key('add-classes-doorway'), findsOneWidget);

      await tester.tap(_key('add-classes-doorway'));
      await tester.pumpAndSettle();
      expect(_key('add-classes-sheet'), findsOneWidget);
      await tester.tap(_key('add-classes-file'));
      await tester.pumpAndSettle();
      await _tapVisible(tester, _key('add-classes-confirm'));
      await tester.tap(_key('add-classes-see-week'));
      await tester.pumpAndSettle();

      expect(_key('add-classes-sheet'), findsNothing);
      // With classes in, the end of Plans no longer offers the doorway.
      await tester.fling(
        find
            .descendant(
              of: find.byType(CalendarPage),
              matching: find.byType(Scrollable),
            )
            .first,
        const Offset(0, -4000),
        4000,
      );
      await tester.pumpAndSettle();
      expect(_key('add-classes-doorway'), findsNothing);
    });

    testWidgets('the ADD menu imports the reviewed schedule once', (
      tester,
    ) async {
      final repository = InMemoryAcademicScheduleRepository();
      await _pumpCalendar(
        tester,
        repository: repository,
        picker: _rutgersPicker(),
      );

      await tester.tap(_key('academic-add-class'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_key('academic-add-choice-import'));
      expect(find.text('ADD YOUR CLASSES'), findsOneWidget);
      await tester.tap(_key('academic-add-choice-import'));
      await tester.pumpAndSettle();
      await tester.tap(_key('add-classes-file'));
      await tester.pumpAndSettle();

      expect(repository.saveCount, 0);
      expect(find.text('168 MEETINGS'), findsOneWidget);
      await _tapVisible(tester, _key('add-classes-confirm'));

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
      await tester.tap(_key('add-classes-see-week'));
      await tester.pumpAndSettle();
      expect(_key('add-classes-sheet'), findsNothing);
      expect(repository.saveCount, 1);
    });

    testWidgets('a file opened from outside opens the same sheet', (
      tester,
    ) async {
      const channel = MethodChannel('room_of_days/test_add_classes_inbox');
      var delivered = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (delivered) return null;
            delivered = true;
            return {
              'name': 'jordan.lee.uiuc@gmail.com.ics',
              'contents': googleCalendarStudentExport(),
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final inbox = AcademicScheduleFileInbox(channel: channel);
      addTearDown(inbox.dispose);
      await inbox.initialize();
      final repository = InMemoryAcademicScheduleRepository();
      await _pumpCalendar(
        tester,
        repository: repository,
        picker: const _FakePicker(null),
        inbox: inbox,
      );
      await tester.pumpAndSettle();

      expect(_key('add-classes-sheet'), findsOneWidget);
      expect(find.text('Pick your classes'), findsOneWidget);
      expect(find.text('ADD 4 COURSES'), findsOneWidget);
      expect(repository.saveCount, 0);
    });
  });

  for (final visual in const [
    (name: '430x932', size: Size(430, 932), textScale: 1.0),
    (name: '320x568_1_3x', size: Size(320, 568), textScale: 1.3),
  ]) {
    testWidgets('fits at ${visual.name}', (tester) async {
      await _pumpSheet(
        tester,
        picker: _FakePicker(
          AcademicScheduleImportSource(
            name: 'jordan.lee.uiuc@gmail.com.ics',
            contents: googleTwoTermExport(),
          ),
        ),
        saves: _Saves(),
        size: visual.size,
        textScale: visual.textScale,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(_key('add-classes-close')).shortestSide,
        greaterThanOrEqualTo(44),
      );
      await _tapVisible(tester, _key('add-classes-help'));
      expect(tester.takeException(), isNull);

      await _tapVisible(tester, _key('add-classes-file'));
      expect(tester.takeException(), isNull);
      await _tapVisible(tester, _key('add-classes-others'));
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(_key('add-classes-confirm')).height,
        greaterThanOrEqualTo(44),
      );
      if (_capture) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/add_classes_review_${visual.name}.png'),
        );
      }

      await _tapVisible(tester, _key('add-classes-confirm'));
      expect(tester.takeException(), isNull);
      expect(_key('add-classes-reminders'), findsOneWidget);
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
      expect(_key('add-classes-doorway'), findsNothing);
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

Set<int> _reminders(AcademicSchedule schedule) => {
  for (final series in schedule.meetingSeries)
    for (final rule in series.reminders)
      if (rule.enabled) rule.offsetMinutes,
};

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

_FakePicker _rutgersPicker({bool includeIgnoredEvent = false}) => _FakePicker(
  AcademicScheduleImportSource(
    name: 'rutgers-fall-2026.ics',
    contents: rutgersFall2026IcsFixture(
      includeIgnoredEvent: includeIgnoredEvent,
    ),
  ),
);

final class _Saves {
  _Saves({this.succeed = true});
  final bool succeed;
  int count = 0;
  AcademicSchedule? last;

  Future<bool> save(AcademicSchedule next, AcademicTerm term) async {
    count += 1;
    if (succeed) last = next;
    return succeed;
  }
}

late _SheetLauncher _launcher;

final class _SheetLauncher {
  _SheetLauncher({
    required this.picker,
    required this.saves,
    this.requestReminderPermission,
    this.linkFetcher,
  });
  final AcademicScheduleFilePicker picker;
  final _Saves saves;
  final Future<bool> Function()? requestReminderPermission;
  final CalendarLinkFetcher? linkFetcher;
  AcademicSchedule schedule = AcademicSchedule.empty();

  Future<void> open(BuildContext context) async {
    await showAddClassesSheet(
      context,
      schedule: schedule,
      filePicker: picker,
      timeZoneIdProvider: () async => 'America/New_York',
      requestReminderPermission: requestReminderPermission,
      linkFetcher: linkFetcher,
      onShareStarter: () async => true,
      onSave: (next, term) async {
        final saved = await saves.save(next, term);
        if (saved) schedule = next;
        return saved;
      },
    );
  }
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required AcademicScheduleFilePicker picker,
  required _Saves saves,
  Future<bool> Function()? requestReminderPermission,
  CalendarLinkFetcher? linkFetcher,
  Size size = const Size(430, 932),
  double textScale = 1,
}) async {
  _launcher = _SheetLauncher(
    picker: picker,
    saves: saves,
    requestReminderPermission: requestReminderPermission,
    linkFetcher: linkFetcher,
  );
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
                key: const ValueKey('open-add-classes'),
                onPressed: () => _launcher.open(context),
                child: const Text('Add classes'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await _openSheet(tester);
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(_key('open-add-classes'));
  await tester.pumpAndSettle();
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required InMemoryAcademicScheduleRepository repository,
  required AcademicScheduleFilePicker picker,
  AcademicScheduleFileInbox? inbox,
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
              selectedDate: '2026-10-04',
            ),
          ),
          notebookHandoff: const _NoopHandoff(),
          academicScheduleFilePicker: picker,
          academicScheduleFileInbox: inbox,
          timeZoneIdProvider: () async => 'America/New_York',
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

final class _FakeFetcher implements CalendarLinkFetcher {
  _FakeFetcher(this.body);
  String body;
  final List<CalendarLink> reads = [];

  @override
  Future<String> fetch(CalendarLink link) async {
    reads.add(link);
    return checkCalendarText(body);
  }
}

final class _NoopHandoff implements NotebookHandoff {
  const _NoopHandoff();

  @override
  Future<NotebookHandoffResult> open(NotebookHandoffIntent intent) async =>
      NotebookHandoffResult.opened;
}
