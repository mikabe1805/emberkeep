import 'dart:async';

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
import 'package:emberkeep/screens/whats_new.dart';
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

// These tests hand the shell its own ClassDayBoardSeam and read what the
// shell handed over from it (`debugReceived`). The Quests page attaches to
// ClassDayBoardSeam.instance, so the board piece merging in does not change
// what they see.

/// His wall clock in New York as an instant (EDT, UTC-4), read in local
/// time. Codemagic's Mac is not on New York time.
DateTime ny(int month, int day, int hour, int minute) =>
    DateTime.utc(2026, month, day, hour + 4, minute).toLocal();

/// His Tuesday.
DateTime tuesday(int hour, int minute) => ny(10, 6, hour, minute);

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

/// Stands in for the Quests board's side of the seam: it keeps through the
/// engine the way the board does (keepClass with the tap's `at`), and
/// records what it was asked.
class _Board with ClassDayLinkTarget {
  _Board(this.schedule, {this.marks = true});

  final AcademicSchedule schedule;
  final bool marks;
  GameState? state;
  final List<String> calls = [];

  @override
  bool get marksClassesFromLinks => marks;

  @override
  void showClassDay() => calls.add('show');

  bool _keep(String occurrenceKey, String dayKey, DateTime? at) {
    final live = state;
    if (live == null) return false;
    final occurrence = schedule.occurrenceByKey(occurrenceKey)!;
    final facts = classFactsFor(schedule, occurrence)!;
    final day = projectClassDay(
      schedule,
      at ?? Clock.now(),
      day: occurrence.date,
    );
    return live.keepClass(facts, dayClassKeys: day.dayClassKeys, at: at) !=
        null;
  }

  @override
  Future<bool> markClassFromLink(
    String occurrenceKey,
    String dayKey, {
    DateTime? at,
  }) async {
    calls.add('mark $dayKey');
    return _keep(occurrenceKey, dayKey, at);
  }

  @override
  Future<bool> markClassesFromLink(
    List<String> occurrenceKeys,
    String dayKey, {
    DateTime? at,
  }) async {
    calls.add('mark ${occurrenceKeys.length} $dayKey');
    var kept = false;
    for (final key in occurrenceKeys) {
      kept = _keep(key, dayKey, at) || kept;
    }
    return kept;
  }
}

Future<void> _saveState({bool morningDue = false, bool sound = false}) async {
  final state = GameState()
    ..onboarded = true
    ..reduceMotion = true
    ..soundEnabled = sound;
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

GameState _shellState(WidgetTester tester) => tester
    .widget<QuestsPage>(find.byType(QuestsPage, skipOffstage: false))
    .state;

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  late ClassDayBoardSeam seam;

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
    seam = ClassDayBoardSeam();
  });

  tearDown(() {
    Clock.reset();
    Sfx.instance.debugResetForTesting();
    Sfx.instance.soundEnabled = true;
    ClassDayBoardSeam.instance.debugReset();
  });

  AppShell shell({
    required ClassDayLinkInbox? inbox,
    required AcademicSchedule schedule,
    WidgetSnapshotWriter? writer,
    AppShellInitialPage initialPage = AppShellInitialPage.quests,
  }) => AppShell(
    initialPage: initialPage,
    classDayLinks: inbox,
    classDayBoardSeam: seam,
    scheduleRepository: InMemoryAcademicScheduleRepository(schedule),
    widgetSnapshotWriter: writer ?? _Writer(),
  );

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

    await _unmount(tester);
  });

  testWidgets(
    'a mark link opens Quests and hands over one checked keep for the tap',
    (tester) async {
      await _saveState();
      final now = tuesday(11, 52);
      Clock.freeze(now);
      final schedule = mikaSchedule();
      final key = _keyFor(schedule, '14:332:331');
      final inbox = ClassDayLinkInbox()
        ..enqueueUri(Uri.parse(classDayMarkUrl(key, '2026-10-06')));

      await tester.pumpWidget(
        MaterialApp(
          home: shell(
            inbox: inbox,
            schedule: schedule,
            initialPage: AppShellInitialPage.goals,
          ),
        ),
      );
      await _settle(tester);

      expect(inbox.isNotEmpty, isFalse);
      expect(
        tester.widget<RoomTravelStack>(find.byType(RoomTravelStack)).index,
        1,
      );
      final request = seam.debugReceived.single;
      expect(request.isMark, isTrue);
      expect(request.occurrenceKey, key);
      expect(request.dayKey, '2026-10-06');
      expect(request.requestedAt, now);

      await _unmount(tester);
      inbox.dispose();
    },
  );

  testWidgets(
    'the board keeps the handed-over class once and the widget republishes',
    (tester) async {
      await _saveState();
      Clock.freeze(tuesday(11, 52));
      final schedule = mikaSchedule();
      final key = _keyFor(schedule, '14:332:331');
      final writer = _Writer();
      final inbox = ClassDayLinkInbox()
        ..enqueueUri(Uri.parse(classDayMarkUrl(key, '2026-10-06')))
        // The same tap delivered twice keeps nothing twice.
        ..enqueueUri(Uri.parse(classDayMarkUrl(key, '2026-10-06')));

      await tester.pumpWidget(
        MaterialApp(
          home: shell(inbox: inbox, schedule: schedule, writer: writer),
        ),
      );
      await _settle(tester);

      final board = _Board(schedule)..state = _shellState(tester);
      final before = writer.written.length;
      seam.attach(board);
      await _settle(tester);
      expect(board.calls, [
        'show',
        'mark 2026-10-06',
        'show',
        'mark 2026-10-06',
      ]);
      expect(seam.pending, isEmpty);
      expect(board.state!.classesKeptOn('2026-10-06'), hasLength(1));

      // Kept → saved → republished: the class reads kept, and with a board
      // that keeps from links attached the next class carries its link.
      expect(writer.written.length, greaterThan(before));
      final day = writer.written.last.classDays.first;
      expect(day.dayKey, '2026-10-06');
      expect(day.classes.first.kept, isTrue);
      expect(day.classes.first.state, WidgetClassState.kept);
      expect(day.classXp, 25);
      expect(day.classes.last.markUrl, isNotNull);

      seam.detach(board);
      await _unmount(tester);
      inbox.dispose();
    },
  );

  testWidgets(
    'the widget offers no mark control until a board that keeps attaches',
    (tester) async {
      await _saveState();
      Clock.freeze(tuesday(11, 52));
      final schedule = mikaSchedule();
      final writer = _Writer();

      await tester.pumpWidget(
        MaterialApp(
          home: shell(
            inbox: ClassDayLinkInbox(),
            schedule: schedule,
            writer: writer,
          ),
        ),
      );
      await _settle(tester);
      final unwired = writer.written.last.classDays.first;
      expect(unwired.classes.every((entry) => entry.markUrl == null), isTrue);
      expect(unwired.markAllUrl, isNull);
      expect(unwired.toJson().toString(), isNot(contains('mark')));

      // A board that has not wired the keep yet changes nothing.
      final quiet = _Board(schedule, marks: false);
      seam.attach(quiet);
      await _settle(tester);
      expect(writer.written.last.classDays.first.classes.first.markUrl, isNull);

      // The board that keeps attaches: the shell republishes with links.
      final published = writer.written.length;
      final board = _Board(schedule);
      seam.attach(board);
      await _settle(tester);
      expect(writer.written.length, greaterThan(published));
      final wired = writer.written.last.classDays.first;
      expect(wired.classes.first.markUrl, startsWith('roomofdays://'));
      expect(wired.markAllUrl, isNotNull);

      seam.detach(board);
      await _unmount(tester);
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
          home: shell(inbox: inbox, schedule: schedule),
        ),
      );
      await _settle(tester);

      final received = seam.debugReceived;
      expect(received, hasLength(3));
      expect(received.every((request) => !request.isMark), isTrue);
      expect(received.every((request) => !request.isMarkAll), isTrue);

      await _unmount(tester);
      inbox.dispose();
    },
  );

  testWidgets(
    'a mark tapped at 3:58 AM still keeps after a cold start past 4:00 AM',
    (tester) async {
      await _saveState();
      final schedule = mikaSchedule();
      // Wednesday 3:58 AM is still Tuesday's night: Discrete Structures II
      // (ended 3:20 PM) can be kept until 4:00.
      final tapped = ny(10, 7, 3, 58);
      Clock.freeze(tapped);
      final key = _keyFor(schedule, '01:198:206');
      final inbox = ClassDayLinkInbox()
        ..enqueueUri(Uri.parse(classDayMarkUrl(key, '2026-10-06')));
      // The launch, the save and the cloud take the clock past 4:00.
      Clock.freeze(ny(10, 7, 4, 1));

      await tester.pumpWidget(
        MaterialApp(
          home: shell(inbox: inbox, schedule: schedule),
        ),
      );
      await _settle(tester);

      final request = seam.debugReceived.single;
      expect(request.isMark, isTrue, reason: 'judged by the tap, not 4:01');
      expect(request.requestedAt, tapped);

      final board = _Board(schedule)..state = _shellState(tester);
      seam.attach(board);
      await _settle(tester);
      final kept = board.state!.classesKeptOn('2026-10-06');
      expect(kept, hasLength(1));
      expect(kept.single.keptAt, tapped.toUtc());

      seam.detach(board);
      await _unmount(tester);
      inbox.dispose();
    },
  );

  testWidgets('a mark-all link hands over every waiting class as one keep', (
    tester,
  ) async {
    await _saveState();
    final now = ny(10, 5, 19, 5);
    Clock.freeze(now);
    final schedule = mikaSchedule();
    final inbox = ClassDayLinkInbox()
      ..enqueueUri(Uri.parse(classDayMarkAllUrl('2026-10-05')));

    await tester.pumpWidget(
      MaterialApp(
        home: shell(inbox: inbox, schedule: schedule),
      ),
    );
    await _settle(tester);

    final request = seam.debugReceived.single;
    expect(request.isMarkAll, isTrue);
    expect(request.dayKey, '2026-10-05');
    final monday = projectClassDay(schedule, now);
    expect(request.occurrenceKeys, [
      for (final entry in monday.classes) entry.occurrenceKey,
    ]);

    final board = _Board(schedule)..state = _shellState(tester);
    seam.attach(board);
    await _settle(tester);
    expect(board.calls, ['show', 'mark 3 2026-10-05']);
    expect(board.state!.classesKeptOn('2026-10-05'), hasLength(3));

    seam.detach(board);
    await _unmount(tester);
    inbox.dispose();
  });

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
        home: shell(inbox: inbox, schedule: schedule),
      ),
    );
    await _settle(tester);

    expect(seam.debugReceived.single.isMark, isTrue);
    expect(find.byType(MorningFlow), findsNothing);

    await _unmount(tester);
    inbox.dispose();
  });

  testWidgets('without a link the same morning still opens the briefing', (
    tester,
  ) async {
    await _saveState(morningDue: true);
    Clock.freeze(tuesday(11, 52));

    await tester.pumpWidget(
      MaterialApp(
        home: shell(inbox: ClassDayLinkInbox(), schedule: mikaSchedule()),
      ),
    );
    await _settle(tester);

    expect(find.byType(MorningFlow), findsOneWidget);

    await _unmount(tester);
  });

  group("What's New", () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('a class-day link holds the release card', (tester) async {
      await _saveState();
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
          home: shell(inbox: inbox, schedule: schedule),
        ),
      );
      await _settle(tester);

      expect(seam.debugReceived.single.isMark, isTrue);
      expect(find.byType(WhatsNewScreen), findsNothing);

      await _unmount(tester);
      inbox.dispose();
    });

    testWidgets('without a link the release card shows', (tester) async {
      await _saveState();
      Clock.freeze(tuesday(11, 52));

      await tester.pumpWidget(
        MaterialApp(
          home: shell(inbox: ClassDayLinkInbox(), schedule: mikaSchedule()),
        ),
      );
      await _settle(tester);

      expect(find.byType(WhatsNewScreen), findsOneWidget);

      await _unmount(tester);
    });
  });

  group('the session hearth', () {
    late List<String> played;

    setUp(() {
      played = [];
      Sfx.instance
        ..debugBypassPlayback = true
        ..debugOnPlay = played.add;
    });

    testWidgets('a link-opened session lights the hearth quietly: no flare, no '
        'fire_ignite', (tester) async {
      await _saveState(sound: true);
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
          home: shell(inbox: inbox, schedule: schedule),
        ),
      );
      await _settle(tester);

      expect(seam.debugReceived.single.isMark, isTrue);
      expect(played, isNot(contains('fire_ignite')));
      final page = tester.widget<QuestsPage>(
        find.byType(QuestsPage, skipOffstage: false),
      );
      expect(page.roomHearthLit, isTrue);
      expect(page.roomIgniting, isFalse);

      await _unmount(tester);
      inbox.dispose();
    });

    testWidgets('an ordinary open still plays the welcome flare', (
      tester,
    ) async {
      await _saveState(sound: true);
      Clock.freeze(tuesday(11, 52));

      await tester.pumpWidget(
        MaterialApp(
          home: shell(inbox: ClassDayLinkInbox(), schedule: mikaSchedule()),
        ),
      );
      await tester.pump();
      await tester.pump();
      for (
        var frame = 0;
        frame < 6 && !played.contains('fire_ignite');
        frame++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(played, contains('fire_ignite'));

      await _settle(tester);
      await _unmount(tester);
    });
  });

  testWidgets(
    'a link that arrives under a pushed route waits for the Quest room',
    (tester) async {
      await _saveState();
      Clock.freeze(tuesday(11, 52));
      final schedule = mikaSchedule();
      final inbox = ClassDayLinkInbox();
      final navigator = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: shell(inbox: inbox, schedule: schedule),
        ),
      );
      await _settle(tester);

      // Something (a Journal page, Settings) is open over the shell.
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('a page on top')),
          ),
        ),
      );
      await _settle(tester);

      inbox.enqueueUri(
        Uri.parse(
          classDayMarkUrl(_keyFor(schedule, '14:332:331'), '2026-10-06'),
        ),
      );
      await _settle(tester);
      expect(inbox.isNotEmpty, isFalse);
      expect(seam.debugReceived, isEmpty, reason: 'nothing kept behind it');
      expect(find.text('a page on top'), findsOneWidget);

      navigator.currentState!.pop();
      await _settle(tester);
      expect(seam.debugReceived.single.isMark, isTrue);

      await _unmount(tester);
      inbox.dispose();
    },
  );

  testWidgets('a link that arrives under a dialog waits for it to close', (
    tester,
  ) async {
    await _saveState();
    Clock.freeze(tuesday(11, 52));
    final schedule = mikaSchedule();
    final inbox = ClassDayLinkInbox();
    final navigator = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: shell(inbox: inbox, schedule: schedule),
      ),
    );
    await _settle(tester);

    unawaited(
      showDialog<void>(
        context: navigator.currentContext!,
        builder: (_) => const AlertDialog(content: Text('a dialog on top')),
      ),
    );
    await _settle(tester);
    inbox.enqueueUri(
      Uri.parse(classDayMarkUrl(_keyFor(schedule, '14:332:331'), '2026-10-06')),
    );
    await _settle(tester);
    expect(seam.debugReceived, isEmpty);

    navigator.currentState!.pop();
    await _settle(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(seam.debugReceived.single.isMark, isTrue);

    await _unmount(tester);
    inbox.dispose();
  });

  testWidgets('the snapshot republishes at the next class boundary', (
    tester,
  ) async {
    await _saveState();
    Clock.freeze(tuesday(11, 52));
    final writer = _Writer();

    await tester.pumpWidget(
      MaterialApp(
        home: shell(inbox: null, schedule: mikaSchedule(), writer: writer),
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

    await _unmount(tester);
  });
}
