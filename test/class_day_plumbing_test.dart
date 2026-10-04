// The shell owns the timetable and hands the class-day projection down: the
// Quests board (and from it the night ledger and the morning) receive it as an
// optional parameter, and the streak's rest-day hook reads the same schedule.
import 'dart:convert';

import 'package:emberkeep/academic_calendar/data/academic_schedule_repository.dart';
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
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
