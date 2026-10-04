// The shell owns the timetable and hands the class-day projection down: the
// Quests board (and from it the night ledger and the morning) receive it as an
// optional parameter, and the streak's rest-day hook reads the same schedule.
import 'dart:convert';

import 'package:emberkeep/academic_calendar/data/academic_schedule_repository.dart';
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/release_notes.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/main.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/release_notes_preferences.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/storage.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/routine_flows.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/rutgers_fall_2026_ics_fixture.dart';

AcademicSchedule _fall2026() => AcademicScheduleIcsImporter.parse(
  rutgersFall2026IcsFixture(),
).applyTo(AcademicSchedule.empty(), updatedAt: DateTime.utc(2026, 8, 27));

Future<void> _seed({AcademicSchedule? schedule}) async {
  final state = GameState()
    ..onboarded = true
    ..playerName = 'Mika'
    ..reduceMotion = true
    ..lastActiveDay = Days.key(Clock.now());
  SharedPreferences.setMockInitialValues({
    whatsNewSeenReleasePreferenceKey: currentRoomReleaseNotes.id,
    'liferpg_save_v1': jsonEncode({
      'app': 'emberkeep',
      'schema': Storage.schema,
      'state': state.toJson(),
      'quests': [
        Quest(
          title: 'Read ten pages',
          stat: Stat.intl,
          difficulty: 2,
          schedule: QuestSchedule.daily,
        ).toJson(),
      ],
    }),
  });
  if (schedule != null) {
    expect(await LocalAcademicScheduleRepository().save(schedule), isTrue);
  }
}

Future<void> _boot(WidgetTester tester) async {
  await tester.pumpWidget(const LifeRpgApp());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pump(const Duration(milliseconds: 800));
}

/// A timetable holder that records what the board asks for. It answers from
/// the Rutgers fixture for the day asked, or for the local night-owned day
/// when none is, so its answers never depend on the host's zone.
class _RecordingLookup {
  _RecordingLookup(this.schedule);

  final AcademicSchedule schedule;
  final List<CivilDate?> asked = [];

  ClassDay call(DateTime now, {CivilDate? day}) {
    asked.add(day);
    return projectClassDay(
      schedule,
      now,
      day: day ?? CivilDate.fromDateTime(Days.nightDate(now)),
    );
  }
}

Future<GameState> _mountBoard(
  WidgetTester tester,
  _RecordingLookup lookup, {
  bool morning = false,
}) async {
  tester.view.devicePixelRatio = 1;
  await tester.binding.setSurfaceSize(const Size(393, 852));
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.binding.setSurfaceSize(null);
  });
  final state = GameState()
    ..onboarded = true
    ..playerName = 'Mika'
    ..reduceMotion = true
    ..morningArmed = morning
    ..lastActiveDay = Days.key(Clock.now());
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: QuestsPage(
          state: state,
          // A short title: under the square test font a longer one wraps
          // the morning's lead row (the bundled fonts fit it; see
          // class_day_ledger_test for the morning at 393 x 852).
          quests: [
            Quest(
              title: 'Stretch',
              stat: Stat.vit,
              difficulty: 2,
              schedule: QuestSchedule.daily,
            ),
          ],
          onRefresh: () => 0,
          onPersist: () {},
          onAdd: (_) => true,
          onRemove: (_) {},
          onSnapshot: () => jsonEncode(state.toJson()),
          onRestore: (_) {},
          classDays: lookup.call,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  return state;
}

/// On a class day the Quests tab opens on the room; BOARD brings the full
/// board (and its doors) back.
Future<void> _openBoard(WidgetTester tester) async {
  final toggle = find.byKey(const Key('class-day-toggle-board'));
  if (toggle.evaluate().isEmpty) return;
  await tester.tap(toggle);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Scrolls the board to [door] and taps it.
Future<void> _tapDoor(WidgetTester tester, Finder door) async {
  await _openBoard(tester);
  if (door.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      door,
      240,
      scrollable: find
          .descendant(
            of: find.byType(QuestsPage),
            matching: find.byType(Scrollable),
          )
          .last,
    );
  }
  await tester.ensureVisible(door.first);
  await tester.pump(const Duration(milliseconds: 150));
  await tester.tap(door.first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    Sfx.instance.soundEnabled = false;
    for (final channel in const [
      MethodChannel('xyz.luan/audioplayers'),
      MethodChannel('xyz.luan/audioplayers.global'),
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => null);
    }
  });
  tearDown(() {
    Clock.reset();
    Sfx.instance.soundEnabled = true;
    GameState.restDayResolver = null;
  });

  testWidgets('the board receives the class day the shell projects', (
    tester,
  ) async {
    // Tuesday Oct 6 at 3:35 PM local. The lookup asks for explicit days, so
    // what it returns never depends on the host's zone.
    Clock.freeze(DateTime(2026, 10, 6, 15, 35));
    await _seed(schedule: _fall2026());
    await _boot(tester);

    final page = tester.widget<QuestsPage>(find.byType(QuestsPage));
    final lookup = page.classDays;
    expect(lookup, isNotNull);
    final tuesday = lookup!(Clock.now(), day: CivilDate(2026, 10, 6));
    expect(tuesday.classes.map((entry) => entry.courseCode), [
      '14:332:331',
      '01:198:206',
    ]);
    final wednesday = lookup(Clock.now(), day: CivilDate(2026, 10, 7));
    expect(wednesday.classes.first.title, 'Computer Architecture Lab');

    // The streak's rest-day pause reads the same timetable (it acts only
    // while ClassDayRules.restDaysPause is on).
    expect(GameState.restDayResolver, isNotNull);
    expect(GameState.restDayResolver!('2026-10-10'), isTrue, reason: 'Sat');
    expect(GameState.restDayResolver!('2026-10-06'), isFalse, reason: 'Tue');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(
      GameState.restDayResolver,
      isNull,
      reason: 'a disposed shell leaves no hook behind',
    );
  });

  group('the board hands the timetable to its routine flows', () {
    // Monday night, and the same night after midnight: both close Monday,
    // so the MARK TOMORROW tray asks for Tuesday Oct 6.
    for (final at in [
      DateTime(2026, 10, 5, 21, 30),
      DateTime(2026, 10, 6, 0, 30),
    ]) {
      final label = at.hour == 0 ? 'after midnight' : 'at 9:30 PM';
      testWidgets('the ledger asks for the day after the night $label', (
        tester,
      ) async {
        Clock.freeze(at);
        final lookup = _RecordingLookup(_fall2026());
        await _mountBoard(tester, lookup);
        expect(find.byType(NightFlow), findsNothing);
        await _tapDoor(tester, find.byKey(const Key('close-day-rail')));
        expect(find.byType(NightFlow), findsOneWidget);

        expect(lookup.asked.whereType<CivilDate>().toSet(), {
          CivilDate(2026, 10, 6),
        });
        final flow = tester.widget<NightFlow>(find.byType(NightFlow));
        expect(flow.tomorrowClasses?.date, CivilDate(2026, 10, 6));
        final lines = find.byKey(const Key('ledger-tomorrow-classes'));
        await tester.ensureVisible(lines);
        await tester.pump(const Duration(milliseconds: 150));
        for (final line in [
          'TUESDAY · 10:20 AM · HLL 114',
          'TUESDAY · 2:00 PM · PHY 001',
        ]) {
          expect(
            find.descendant(of: lines, matching: find.textContaining(line)),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the morning receives the classes of its day', (tester) async {
      Clock.freeze(DateTime(2026, 10, 6, 8, 5));
      final lookup = _RecordingLookup(_fall2026());
      await _mountBoard(tester, lookup, morning: true);
      expect(find.byType(MorningFlow), findsNothing);
      // A first-day board keeps its morning door in the footer.
      await _tapDoor(tester, find.text('MORNING'));
      expect(find.byType(MorningFlow), findsOneWidget);

      // The morning asks for the day it belongs to, not a named one.
      expect(lookup.asked, isNotEmpty);
      expect(lookup.asked.last, isNull);
      final classDay = tester
          .widget<MorningFlow>(find.byType(MorningFlow))
          .classDay;
      expect(classDay?.date, CivilDate(2026, 10, 6));
      expect(classDay?.classes.map((entry) => entry.courseCode), [
        '14:332:331',
        '01:198:206',
      ]);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('without a timetable the board gets no class day', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 10, 6, 15, 35));
    await _seed();
    await _boot(tester);
    final page = tester.widget<QuestsPage>(find.byType(QuestsPage));
    expect(page.classDays, isNull);
    expect(GameState.restDayResolver!('2026-10-10'), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
