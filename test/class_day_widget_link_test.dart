import 'package:emberkeep/academic_calendar/data/academic_schedule_repository.dart';
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/audio.dart';
import 'package:emberkeep/class_day_links.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/release_notes.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/home_widgets/widget_snapshot.dart';
import 'package:emberkeep/home_widgets/widget_snapshot_writer.dart';
import 'package:emberkeep/main.dart';
import 'package:emberkeep/release_notes_preferences.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/screens/shell.dart';
import 'package:emberkeep/storage.dart';
import 'package:emberkeep/widgets/room_travel.dart';
import 'package:emberkeep/widgets/routine_flows.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as time_zone_data;

import 'support/rutgers_fall_2026_ics_fixture.dart';

/// His Tuesday in New York, as an instant (EDT, UTC-4), read in local time.
DateTime tuesday(int hour, int minute) =>
    DateTime.utc(2026, 10, 6, hour + 4, minute).toLocal();

AcademicSchedule mikaSchedule() => AcademicScheduleIcsImporter.parse(
  rutgersFall2026IcsFixture(),
).applyTo(AcademicSchedule.empty(), updatedAt: DateTime.utc(2026, 8, 27, 19));

class _Writer implements WidgetSnapshotWriter {
  final List<WidgetSnapshot> written = [];

  @override
  Future<bool> write(WidgetSnapshot snapshot) async {
    written.add(snapshot);
    return true;
  }
}

/// Stands in for the Quests board's side of the seam: it keeps the class
/// through the engine the way the board will, and records what it was asked.
class _Board with ClassDayLinkTarget {
  _Board(this.schedule);

  final AcademicSchedule schedule;
  GameState? state;
  final List<String> calls = [];

  @override
  void showClassDay() => calls.add('show');

  @override
  Future<bool> markClassFromLink(String occurrenceKey, String dayKey) async {
    calls.add('mark $dayKey');
    final live = state;
    if (live == null) return false;
    final occurrence = schedule.occurrenceByKey(occurrenceKey)!;
    final facts = classFactsFor(schedule, occurrence)!;
    final day = projectClassDay(schedule, Clock.now());
    return live.keepClass(facts, dayClassKeys: day.dayClassKeys) != null;
  }
}

Future<void> _saveState({bool morningDue = false}) async {
  final state = GameState()
    ..onboarded = true
    ..reduceMotion = true
    ..soundEnabled = false;
  if (morningDue) {
    Clock.freeze(tuesday(0, 0).subtract(const Duration(hours: 2)));
    state.closeNight();
  }
  await Storage.save(state, const []);
}

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 16; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

String _keyFor(AcademicSchedule schedule, String code) {
  final day = projectClassDay(schedule, Clock.now());
  return day.classes
      .firstWhere((entry) => entry.courseCode == code)
      .occurrenceKey;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    time_zone_data.initializeTimeZones();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      whatsNewSeenReleasePreferenceKey: currentRoomReleaseNotes.id,
    });
    Sfx.instance.soundEnabled = false;
    ClassDayBoardSeam.instance.debugReset();
  });

  tearDown(() {
    Clock.reset();
    Sfx.instance.soundEnabled = true;
    ClassDayBoardSeam.instance.debugReset();
  });

  testWidgets('the root app claims a warm class-day link before Navigator', (
    tester,
  ) async {
    await tester.pumpWidget(const LifeRpgApp());
    await tester.pump();

    final message = const JSONMethodCodec().encodeMethodCall(
      const MethodCall('pushRouteInformation', <String, dynamic>{
        'location': 'roomofdays://class-day/mark?occurrence=abc&day=2026-10-06',
        'state': null,
      }),
    );
    final result = (await tester.binding.defaultBinaryMessenger
        .handlePlatformMessage('flutter/navigation', message, (_) {}))!;
    expect(const JSONMethodCodec().decodeEnvelope(result), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'a mark link opens Quests, hands the board an open keep once, and '
    'the widget snapshot republishes with the class kept',
    (tester) async {
      await _saveState();
      final now = tuesday(11, 52);
      Clock.freeze(now);
      final schedule = mikaSchedule();
      final key = _keyFor(schedule, '14:332:331');
      final board = _Board(schedule);
      final writer = _Writer();
      final inbox = ClassDayLinkInbox()
        ..enqueueUri(Uri.parse(classDayMarkUrl(key, '2026-10-06')));

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            initialPage: AppShellInitialPage.goals,
            classDayLinks: inbox,
            scheduleRepository: InMemoryAcademicScheduleRepository(schedule),
            widgetSnapshotWriter: writer,
          ),
        ),
      );
      await _settle(tester);

      expect(inbox.isNotEmpty, isFalse);
      expect(
        tester.widget<RoomTravelStack>(find.byType(RoomTravelStack)).index,
        1,
      );
      expect(find.byType(QuestsPage, skipOffstage: false), findsOneWidget);
      // No board has attached yet (the Quests page does not implement the
      // seam in this branch): the keep waits, checked and ready.
      final pending = ClassDayBoardSeam.instance.pending;
      expect(pending, hasLength(1));
      expect(pending.single.isMark, isTrue);
      expect(pending.single.occurrenceKey, key);
      expect(pending.single.dayKey, '2026-10-06');

      // The board mounts: it gets the request once and keeps the class.
      board.state = tester
          .widget<QuestsPage>(find.byType(QuestsPage, skipOffstage: false))
          .state;
      final before = writer.written.length;
      ClassDayBoardSeam.instance.attach(board);
      await _settle(tester);
      expect(board.calls, ['show', 'mark 2026-10-06']);
      expect(ClassDayBoardSeam.instance.pending, isEmpty);
      expect(board.state!.classesKeptOn('2026-10-06'), hasLength(1));

      // Kept → saved → republished: the widget's class reads kept.
      expect(writer.written.length, greaterThan(before));
      final day = writer.written.last.classDays.first;
      expect(day.dayKey, '2026-10-06');
      expect(day.classes.first.kept, isTrue);
      expect(day.classes.first.state, WidgetClassState.kept);
      expect(day.classXp, 25);

      ClassDayBoardSeam.instance.detach(board);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      inbox.dispose();
    },
  );

  testWidgets(
    'a mark link for a class that has not started only opens the class day',
    (tester) async {
      await _saveState();
      Clock.freeze(tuesday(11, 52));
      final schedule = mikaSchedule();
      final later = _keyFor(schedule, '01:198:206');
      final inbox = ClassDayLinkInbox()
        ..enqueueUri(Uri.parse(classDayMarkUrl(later, '2026-10-06')))
        ..enqueueUri(Uri.parse(classDayMarkUrl('not-a-class', '2026-10-06')))
        ..enqueueUri(
          Uri.parse(
            classDayMarkUrl(_keyFor(schedule, '14:332:331'), '2026-10-07'),
          ),
        );

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            classDayLinks: inbox,
            scheduleRepository: InMemoryAcademicScheduleRepository(schedule),
            widgetSnapshotWriter: _Writer(),
          ),
        ),
      );
      await _settle(tester);

      final pending = ClassDayBoardSeam.instance.pending;
      expect(pending, hasLength(3));
      expect(pending.every((request) => !request.isMark), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      inbox.dispose();
    },
  );

  testWidgets('a class-day link opens before the morning briefing', (
    tester,
  ) async {
    await _saveState(morningDue: true);
    Clock.freeze(tuesday(11, 52));
    final schedule = mikaSchedule();
    final inbox = ClassDayLinkInbox()
      ..enqueueUri(
        Uri.parse(
          classDayMarkUrl(_keyFor(schedule, '14:332:331'), '2026-10-06'),
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          classDayLinks: inbox,
          scheduleRepository: InMemoryAcademicScheduleRepository(schedule),
          widgetSnapshotWriter: _Writer(),
        ),
      ),
    );
    await _settle(tester);

    expect(ClassDayBoardSeam.instance.pending.single.isMark, isTrue);
    expect(find.byType(MorningFlow), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    inbox.dispose();
  });

  testWidgets('without a link the same morning still opens the briefing', (
    tester,
  ) async {
    await _saveState(morningDue: true);
    Clock.freeze(tuesday(11, 52));

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          classDayLinks: ClassDayLinkInbox(),
          scheduleRepository: InMemoryAcademicScheduleRepository(
            mikaSchedule(),
          ),
          widgetSnapshotWriter: _Writer(),
        ),
      ),
    );
    await _settle(tester);

    expect(find.byType(MorningFlow), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('the snapshot republishes at the next class boundary', (
    tester,
  ) async {
    await _saveState();
    Clock.freeze(tuesday(11, 52));
    final writer = _Writer();

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          scheduleRepository: InMemoryAcademicScheduleRepository(
            mikaSchedule(),
          ),
          widgetSnapshotWriter: writer,
        ),
      ),
    );
    await _settle(tester);
    final published = writer.written.length;
    expect(published, greaterThan(0));
    expect(
      writer.written.last.nextBoundaryAfter(Clock.now()),
      DateTime.utc(2026, 10, 6, 18),
    );

    // 2:00 PM: Discrete Structures II starts.
    Clock.freeze(tuesday(14, 0).add(const Duration(seconds: 1)));
    await tester.pump(const Duration(hours: 2, minutes: 8, seconds: 2));
    await tester.pump();
    expect(writer.written.length, greaterThan(published));
    expect(
      writer.written.last.classDays.first.classes.last.state,
      WidgetClassState.inSession,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
