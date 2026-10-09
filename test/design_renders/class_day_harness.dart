// Class-day render harness: test-support library, not a test.
//
// Renders the REAL Room of Days app (LifeRpgApp, unmodified lib/) at iPhone
// size on Mika's real Fall 2026 class days, so design work can be judged in
// its medium instead of from code. Import it from a *_test.dart file:
//
//   import 'class_day_harness.dart';
//
//   const _renders = bool.fromEnvironment('CLASS_DAY_RENDERS');
//
//   void main() {
//     setUpAll(setUpRoomRenders);
//     tearDownAll(tearDownRoomRenders);
//     final sheet = FrameSheet(classDayDir('my-study'));
//     // Only a render run writes: a plain `flutter test` (CI) must leave the
//     // checkout untouched, and tearDownAll runs even when every test skips.
//     tearDownAll(() {
//       if (_renders) sheet.writeManifest();
//     });
//
//     roomRenderTest('Tuesday after class', skip: !_renders, (tester) async {
//       final at = DateTime(2026, 10, 6, 15, 35);
//       final account = mikaAccount(renderAt: at);
//       await bootRoom(tester, account, schedule: mikaSchedule());
//       await sheet.shot(tester, 'T01_board', at: at, surface: 'Quests');
//     });
//   }
//
// Run: flutter test --dart-define=CLASS_DAY_RENDERS=true <that file>
//
// What is real: the app widget tree, theme, fonts (bundled families), room
// art, the save format, the schedule importer and its prefs store, the widget
// snapshot builder, Clock-driven day logic. What is not: flutter_tester draws
// it (no Metal, no SF Pro, no sound, haptics, gyro or 120 Hz), and it runs on
// Windows, so dart:io Platform checks see Windows (notifications stay off).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:emberkeep/a11y.dart';
import 'package:emberkeep/academic_calendar/data/academic_schedule_repository.dart';
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/day_planning.dart';
import 'package:emberkeep/content/release_notes.dart';
import 'package:emberkeep/content/routines.dart';
import 'package:emberkeep/content/space_themes.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/haptics.dart';
import 'package:emberkeep/main.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/release_notes_preferences.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/storage.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/home_room.dart';
import 'package:emberkeep/widgets/quest_depth_room.dart';
import 'package:emberkeep/widgets/room_travel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/rutgers_fall_2026_ics_fixture.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Output locations
// ─────────────────────────────────────────────────────────────────────────────

/// `<worktree>/design/comparisons/2026-10-03/class-day/<sub>`. flutter test
/// runs with the package root as the working directory.
String classDayDir(String sub) {
  final root = Directory.current.path.replaceAll(r'\', '/');
  return '$root/design/comparisons/2026-10-03/class-day/$sub';
}

// ─────────────────────────────────────────────────────────────────────────────
// One-time setup: fonts, audio mocks, room art
// ─────────────────────────────────────────────────────────────────────────────

/// The audioplayers channels the room's music and sound touch at startup.
const roomAudioChannels = <MethodChannel>[
  MethodChannel('xyz.luan/audioplayers.global'),
  MethodChannel('xyz.luan/audioplayers.global/events'),
  MethodChannel('xyz.luan/audioplayers'),
  MethodChannel('xyz.luan/audioplayers/events/room-of-days-background-music'),
  MethodChannel('xyz.luan/audioplayers/events/room-of-days-focus-music'),
];

/// Families the platform typography asks for when a widget sets no family.
/// On a phone these resolve to SF Pro (iOS) or Roboto (Android); neither ships
/// with the app, so flutter_tester would draw boxes. We register Inter under
/// those names as a stand-in [approximation: SF Pro is not available here].
const _platformDefaultFamilies = <String>[
  'Roboto',
  'CupertinoSystemText',
  'CupertinoSystemDisplay',
  '.SF UI Text',
  '.SF UI Display',
  '.SF Pro Text',
  '.SF Pro Display',
];

/// Call from `setUpAll`. Loads the bundled type (Fraunces, Inter,
/// JetBrainsMono, EBGaramond, MaterialIcons), mocks the audio channels, seeds
/// the engine's random source, decodes every room plate in real async time,
/// and turns off Google Fonts network fetching. Safe to call once per file.
Future<void> setUpRoomRenders({int randomSeed = 20261003}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GameState.debugRandomFactory = () => Random(randomSeed);
  for (final channel in roomAudioChannels) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
  }
  // The decoded page, routine and room art is ~250 MB; the default 100 MB
  // cache would evict plates between precache and paint.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 900 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 4000;
  await loadRoomFonts();
  // Every complete room is decoded here, in the real-async setUpAll zone, as
  // the store screenshot harness does: a codec started on the fake clock and
  // awaited later can strand across zones.
  await preloadHomeRoomAssets();
  GoogleFonts.config.allowRuntimeFetching = false;
}

/// Call from `tearDownAll`.
void tearDownRoomRenders() {
  for (final channel in roomAudioChannels) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  }
  GameState.debugRandomFactory = null;
}

/// Loads the app's bundled faces under the family names the code uses.
Future<void> loadRoomFonts() async {
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  final fraunces = FontLoader('Fraunces')
    ..addFont(rootBundle.load('assets/google_fonts/Fraunces-Bold.ttf'))
    ..addFont(rootBundle.load('assets/google_fonts/Fraunces-SemiBold.ttf'))
    ..addFont(
      rootBundle.load('assets/google_fonts/Fraunces-SemiBoldItalic.ttf'),
    );
  final inter = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/google_fonts/Inter-Regular.ttf'))
    ..addFont(rootBundle.load('assets/google_fonts/Inter-Medium.ttf'))
    ..addFont(rootBundle.load('assets/google_fonts/Inter-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/google_fonts/Inter-Bold.ttf'))
    ..addFont(rootBundle.load('assets/google_fonts/Inter-Italic.ttf'));
  final mono = FontLoader('JetBrainsMono')
    ..addFont(rootBundle.load('assets/google_fonts/JetBrainsMono-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/google_fonts/JetBrainsMono-Bold.ttf'));
  final garamond = FontLoader('EBGaramond')
    ..addFont(rootBundle.load('assets/google_fonts/EBGaramond-Variable.ttf'))
    ..addFont(
      rootBundle.load('assets/google_fonts/EBGaramond-Italic-Variable.ttf'),
    );
  final standIns = [
    for (final family in _platformDefaultFamilies)
      FontLoader(family)
        ..addFont(rootBundle.load('assets/google_fonts/Inter-Regular.ttf'))
        ..addFont(rootBundle.load('assets/google_fonts/Inter-Medium.ttf'))
        ..addFont(rootBundle.load('assets/google_fonts/Inter-SemiBold.ttf'))
        ..addFont(rootBundle.load('assets/google_fonts/Inter-Bold.ttf')),
  ];
  await Future.wait([
    icons.load(),
    fraunces.load(),
    inter.load(),
    mono.load(),
    garamond.load(),
    for (final loader in standIns) loader.load(),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Phone
// ─────────────────────────────────────────────────────────────────────────────

/// iPhone 15 / 16 Pro: 393 x 852 pt at 3x, with its real safe areas (59 pt
/// status/Dynamic Island, 34 pt home indicator). PNGs come out 1179 x 2556.
void phone(WidgetTester tester, {double dpr = 3}) {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(393 * dpr, 852 * dpr);
  tester.view.padding = FakeViewPadding(top: 59 * dpr, bottom: 34 * dpr);
  tester.view.viewPadding = FakeViewPadding(top: 59 * dpr, bottom: 34 * dpr);
}

void unphone(WidgetTester tester) {
  tester.view.resetDevicePixelRatio();
  tester.view.resetPhysicalSize();
  tester.view.resetPadding();
  tester.view.resetViewPadding();
}

/// A testWidgets wrapper for render tests: phone size, iOS platform behavior
/// (Cupertino page transitions, bouncing scroll, iOS typography), sound off,
/// and a guaranteed reset of everything (Clock, view, platform, sound, the
/// widget snapshot tap) even when the body throws. The app is unmounted at
/// the end so the shell's midnight timer and listeners are disposed.
void roomRenderTest(
  String description,
  Future<void> Function(WidgetTester tester) body, {
  bool skip = false,
  bool ios = true,
  bool failOnOverflow = false,
  Duration timeout = const Duration(minutes: 10),
}) {
  testWidgets(
    description,
    (tester) async {
      phone(tester);
      if (ios) debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      Sfx.instance.soundEnabled = false;
      final previousOnError = FlutterError.onError;
      if (!failOnOverflow) {
        // A layout overflow is a finding about the app, not a harness
        // failure: record it and keep rendering. Debug builds paint the
        // yellow-black overflow stripe into the frame; release clips.
        FlutterError.onError = (details) {
          final text = details.exceptionAsString();
          if (text.contains('overflowed by')) {
            RenderIssues.record(description, details);
            return;
          }
          previousOnError?.call(details);
        };
      }
      try {
        await body(tester);
      } finally {
        FlutterError.onError = previousOnError;
        try {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        } catch (_) {}
        WidgetSnapshotTap.uninstall();
        debugDefaultTargetPlatformOverride = null;
        unphone(tester);
        Clock.reset();
        Sfx.instance.soundEnabled = true;
        Haptics.reduceMotion = false;
      }
    },
    skip: skip,
    timeout: Timeout(timeout),
  );
}

/// Layout overflows seen while rendering (see [roomRenderTest]).
abstract final class RenderIssues {
  static final List<String> lines = [];

  static void record(String test, FlutterErrorDetails details) {
    final what = details.exceptionAsString().split('\n').first;
    final where = details.informationCollector == null
        ? ''
        : details.informationCollector!()
              .map((node) => node.toString())
              .firstWhere((line) => line.contains('.dart:'), orElse: () => '')
              .trim();
    final line = '[$test] $what ${where.isEmpty ? '' : '($where)'}'.trim();
    if (!lines.contains(line)) {
      lines.add(line);
      // ignore: avoid_print
      print('RENDER ISSUE $line');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Time
// ─────────────────────────────────────────────────────────────────────────────

/// Freezes the app's injectable clock (lib/clock.dart) at a LOCAL time. The
/// test machine is on America/New_York, the same zone as the schedule, so a
/// local DateTime here is Mika's wall clock. Call again to jump.
void freezeAt(DateTime local) => Clock.freeze(local);

/// Advances fake (animation) time without moving [Clock].
Future<void> settle(
  WidgetTester tester, {
  Duration total = const Duration(milliseconds: 1600),
  Duration step = const Duration(milliseconds: 100),
}) async {
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

/// Sends the app to the background and back (what reopening the phone app
/// does). The shell re-runs rollover, What's New and the morning check.
Future<void> reopenApp(WidgetTester tester) async {
  // The only transitions AppLifecycleListener accepts, in order.
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump(const Duration(milliseconds: 200));
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
}

// ─────────────────────────────────────────────────────────────────────────────
// Mika's account
// ─────────────────────────────────────────────────────────────────────────────

class MikaAccount {
  MikaAccount(this.state, this.quests, {required this.lastActive});

  final GameState state;
  final List<Quest> quests;

  /// The last day he opened the app and completed anything.
  final DateTime lastActive;

  /// The save blob exactly as Storage writes it (key `liferpg_save_v1`).
  String encodeSave() => jsonEncode({
    'app': 'emberkeep',
    'schema': Storage.schema,
    'state': state.toJson(),
    'quests': [for (final q in quests) q.toJson()],
  });
}

/// The Quests the App Store screenshot account carries (reused on purpose,
/// they are ordinary, not student-specific).
const mikaQuestTitles = <String>[
  'Read ten pages',
  'Walk after lunch',
  'Clear the kitchen counter',
  'Message someone I miss',
  'Twenty-five focused minutes',
];

/// The three he chose on his last active day (inferred).
const mikaLastThree = <String>[
  'Read ten pages',
  'Clear the kitchen counter',
  'Message someone I miss',
];

/// A Mika-like account.
///
/// Verified numbers (the App Store account, HANDOFF.md 5.4): level 18,
/// 284 XP into the level, 4,280 total XP, MIND 116, HOME 103, a 12-day
/// streak, best 19, 3 freezes, 640 Glimmers, 138 completions, the free
/// walnut room, the store account's Quests and two goals.
///
/// Inferred (stated in every NOTES file that uses it):
/// - He now barely opens the app: the last active day is [lastActive]
///   (default Monday 2026-09-28, one week before the first render day).
///   The 12-day streak is the run that ended that day (Sep 17 to Sep 28,
///   mostly one or two Quests a day, i.e. light use while classes ran);
///   before that, the store account's activity pattern.
/// - On his last active day he chose Today's three ([mikaLastThree]) and
///   kept one of them ("Read ten pages"). Nothing is chosen for the render
///   day, so Today's three is unchosen.
/// - He swiped away the week recap on Sep 28, so the Monday "last week"
///   panel is due again in October (real engine behavior).
/// - Sound and music are off in renders (no audio device here); motion is on.
/// - [withJournal] adds the store account's two sample journal pages,
///   re-dated into September. They are store copy, not his writing.
///
/// Leaves [Clock] frozen at [renderAt].
MikaAccount mikaAccount({
  required DateTime renderAt,
  DateTime? lastActive,
  bool withJournal = true,
  bool reduceMotion = false,
  String playerName = 'Mika',
}) {
  final last = lastActive ?? DateTime(2026, 9, 28);
  final lastKey = Days.key(last);
  // Build "as of" his last evening so anything date-stamped lands there.
  Clock.freeze(DateTime(last.year, last.month, last.day, 21));

  final state = GameState()
    ..onboarded = true
    ..playerName = playerName
    ..level = 18
    ..xp = 284
    ..totalXp = 4280
    ..totalCompletions = 138
    ..embers = 640
    ..streakDays = 12
    ..bestStreak = 19
    ..streakFreezes = 3
    ..lastActiveDay = lastKey
    ..lastCompletionDay = lastKey
    ..weekRecapSeenWeek = Days.key(Days.weekStart(last))
    ..sparkSeenDay = lastKey
    ..emberSeenDay = lastKey
    ..soundEnabled = false
    ..reduceMotion = reduceMotion
    ..wallStyle = 'wall_walnut'
    ..floorStyle = 'floor_oak'
    ..questDeskStyle = 'wall_indigo'
    ..windowScene = 'moon'
    ..creatureSkin = 'sunstone'
    ..todayXp = 26;
  state.todayStats[Stat.intl] = 6;
  state.todayQuestTitles.add('Read ten pages');
  state.energyWeather = EnergyWeather.steady;
  state.energyWeatherDay = lastKey;
  state.energyHistory[lastKey] = EnergyWeather.steady;
  state.stats[Stat.str] = 88;
  state.stats[Stat.vit] = 72;
  state.stats[Stat.intl] = 116;
  state.stats[Stat.foc] = 94;
  state.stats[Stat.soc] = 61;
  state.stats[Stat.dis] = 103;
  state.ownedSkins.add('sunstone');
  state.ownedFurniture.addAll({
    'rug',
    'lamp',
    'plant',
    'shelf',
    'picture',
    'chair',
    'candles',
    'garland',
    'hearth',
    'pet',
  });
  state.unlockedAchievements.addAll({
    'well-rounded',
    'goal-getter',
    'perfect-day',
    'week-of-fire',
    'ascendant',
  });
  state.goals.addAll([
    Goal(
      title: 'Build a walking habit',
      stat: Stat.vit,
      target: 25,
      progress: 17,
      startedDay: '2026-07-08',
    ),
    Goal(
      title: 'Make the apartment feel calm',
      stat: Stat.dis,
      target: 25,
      progress: 11,
      startedDay: '2026-07-14',
    ),
  ]);
  // The 12-day run that ends on his last active day: light use, 1-2 a day.
  for (var i = 0; i < 12; i++) {
    final day = last.subtract(Duration(days: i));
    state.history[Days.key(day)] = i % 4 == 1 ? 2 : 1;
  }
  // Before it, the store account's rhythm (it skips some days).
  for (var i = 13; i < 84; i++) {
    if (i % 9 == 4 || i % 13 == 7) continue;
    final day = last.subtract(Duration(days: i));
    state.history[Days.key(day)] = 1 + (i * 5) % 4;
  }
  if (withJournal) {
    final first = last.subtract(const Duration(days: 12));
    final second = last.subtract(const Duration(days: 6));
    state.journal = [
      Note(
        at: DateTime(first.year, first.month, first.day, 20, 10),
        text: 'The first evening this room began to feel like mine.',
        context: 'Homey Homesteader',
        trace: JournalTrace(
          day: Days.key(first),
          level: 17,
          totalXp: 3990,
          todayXp: 52,
          streakDays: 1,
          questTitles: const ['Clear the kitchen counter'],
          goalTitles: const ['Make the apartment feel calm'],
          statGains: const {Stat.dis: 4},
          energy: EnergyWeather.steady,
        ),
      ),
      Note(
        at: DateTime(second.year, second.month, second.day, 21, 20),
        text: 'I showed up even though the day felt smaller than planned.',
        context: 'Homey Homesteader',
        trace: JournalTrace(
          day: Days.key(second),
          level: 18,
          totalXp: 4180,
          todayXp: 26,
          streakDays: 7,
          questTitles: const ['Walk after lunch'],
          goalTitles: const ['Build a walking habit'],
          statGains: const {Stat.vit: 3},
          energy: EnergyWeather.low,
        ),
      ),
    ];
  }

  final quests = [
    Quest(
      title: 'Read ten pages',
      stat: Stat.intl,
      difficulty: 4,
      lastDoneDay: lastKey,
    ),
    Quest(
      title: 'Walk after lunch',
      stat: Stat.vit,
      difficulty: 3,
      goalTitle: 'Build a walking habit',
      lastDoneDay: Days.key(last.subtract(const Duration(days: 1))),
    ),
    Quest(
      title: 'Clear the kitchen counter',
      stat: Stat.dis,
      difficulty: 5,
      dread: true,
      goalTitle: 'Make the apartment feel calm',
    ),
    Quest(title: 'Message someone I miss', stat: Stat.soc, difficulty: 4),
    Quest(
      title: 'Twenty-five focused minutes',
      stat: Stat.foc,
      difficulty: 6,
      verification: Verification.timer,
      timerMinutes: 25,
    ),
    workoutLauncherQuest(),
  ];
  // Today's three, chosen for HIS LAST ACTIVE DAY through the production path.
  applyDailyField(quests, last, mikaLastThree);

  Clock.freeze(renderAt);
  return MikaAccount(state, quests, lastActive: last);
}

// ─────────────────────────────────────────────────────────────────────────────
// Mika's schedule
// ─────────────────────────────────────────────────────────────────────────────

/// His real Fall 2026 timetable (test/support/rutgers_fall_2026_ics_fixture
/// .dart), parsed by the app's importer and applied to an empty schedule the
/// way Plans does on import (the Add your classes sheet applies a Room of
/// Days file through the same importer).
/// [importedAt] defaults to 2026-08-27, the day the .ics was made [inferred:
/// whether it is imported on his phone is unknown].
AcademicSchedule mikaSchedule({DateTime? importedAt}) {
  final draft = AcademicScheduleIcsImporter.parse(rutgersFall2026IcsFixture());
  return draft.applyTo(
    AcademicSchedule.empty(),
    updatedAt: (importedAt ?? DateTime(2026, 8, 27, 15)).toUtc(),
  );
}

/// The classes that meet on [day] (cancelled ones excluded), as readable
/// rows: `08:30-09:50  14:332:361  Electronics Devices  LEC  SEC · 111`.
List<String> classRowsOn(AcademicSchedule schedule, DateTime day) {
  String hm(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';
  return [
    for (final o in schedule.occurrencesOn(CivilDate.fromDateTime(day)))
      if (o.state != OccurrenceState.cancelled && o.tombstonedAt == null)
        '${hm(o.localStartMinute)}-${hm(o.localEndMinute)}  '
            '${schedule.courseById(o.courseId)?.code}  '
            '${schedule.courseById(o.courseId)?.title}  '
            '${o.kind.shortLabel}  ${o.place.shortLabel}'
            '${o.originalDate != o.date ? '  (moved from ${o.originalDate})' : ''}',
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget snapshot (the Day Ledger home-screen widget's input)
// ─────────────────────────────────────────────────────────────────────────────

/// Captures what the app publishes to the native widget through
/// `room_of_days/home_widget` → `writeSnapshot` (widget_snapshot_writer.dart).
/// [install] before [bootRoom]; [roomRenderTest] uninstalls it.
abstract final class WidgetSnapshotTap {
  static const channel = MethodChannel('room_of_days/home_widget');
  static final List<String> writes = [];

  static void install() {
    writes.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'writeSnapshot') {
            writes.add((call.arguments as Map)['json'] as String);
            return true;
          }
          return null;
        });
  }

  static void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  }

  static Map<String, dynamic>? get last => writes.isEmpty
      ? null
      : (jsonDecode(writes.last) as Map).cast<String, dynamic>();

  /// Writes the last published snapshot, pretty-printed, to [absolutePath].
  static File? writeLast(String absolutePath) {
    final json = last;
    if (json == null) return null;
    final file = File(absolutePath)..parent.createSync(recursive: true);
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
    return file;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Boot
// ─────────────────────────────────────────────────────────────────────────────

/// Seeds SharedPreferences the way a phone that has this account would hold
/// it: the main save, What's New already seen, and (when given) the academic
/// schedule written through the app's own [LocalAcademicScheduleRepository]
/// (key `room_of_days_academic_schedule_v1`).
Future<void> seedPreferences(
  MikaAccount account, {
  AcademicSchedule? schedule,
  Map<String, Object> extra = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    whatsNewSeenReleasePreferenceKey: currentRoomReleaseNotes.id,
    'liferpg_save_v1': account.encodeSave(),
    ...extra,
  });
  if (schedule != null) {
    final saved = await LocalAcademicScheduleRepository().save(schedule);
    if (!saved) throw StateError('The schedule did not persist');
  }
}

/// Mounts the real app ([LifeRpgApp]) on the seeded save, decodes the art the
/// first screens paint, and lets the session ignition and entrances settle.
/// Freeze the clock first (mikaAccount does). The app opens on QUESTS.
Future<void> bootRoom(
  WidgetTester tester,
  MikaAccount account, {
  AcademicSchedule? schedule,
  Map<String, Object> extraPrefs = const {},
  Iterable<String>? precache,
  Duration settleFor = const Duration(milliseconds: 2000),
}) async {
  await seedPreferences(account, schedule: schedule, extra: extraPrefs);
  await tester.pumpWidget(const LifeRpgApp());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
  await precacheArt(tester, precache ?? RoomArt.everyday);
  await settle(tester, total: settleFor);
}

/// Bundled art, grouped by surface. Widget tests run on a fake clock that
/// never completes image codecs, so anything not precached paints empty.
abstract final class RoomArt {
  static List<String> get board => [
    ...QuestDepthRoom.assets,
    'assets/quest/luminous-honey-gold-v2.webp',
    'assets/quest/category-body-v2.webp',
    'assets/quest/category-care-v2.webp',
    'assets/quest/category-mind-v2.webp',
    'assets/quest/category-craft-v2.webp',
    'assets/quest/category-people-v2.webp',
    'assets/quest/category-home-v2.webp',
    'assets/room/wall_grain.png',
    'assets/room/floor_grain.png',
  ];

  static const routine = <String>[
    'assets/routine/ledger-night-v2.webp',
    'assets/routine/ledger-morning-v2.webp',
    'assets/routine/ledger-clasp-v2.webp',
    'assets/routine/begin-here-bookmark-v2.webp',
    'assets/routine/room-night-v1.webp',
    'assets/routine/room-morning-v1.webp',
    'assets/routine/top-three-tray-v2.webp',
    'assets/routine/gilded-section-rule-v2.webp',
    'assets/routine/gilded-section-rule-left-v2.webp',
    'assets/routine/gilded-section-rule-right-v2.webp',
    'assets/routine/priority-ribbon-plum-v2.webp',
    'assets/routine/priority-ribbon-blue-v2.webp',
    'assets/routine/priority-ribbon-umber-v2.webp',
  ];

  static const plans = <String>['assets/pages/plans-conservatory-v2.webp'];

  static const journal = <String>[
    'assets/pages/journal-archive-v1.webp',
    'assets/pages/journal-desk-v3.webp',
    'assets/pages/journal-page-edge-v1.webp',
  ];

  static const goals = <String>[
    'assets/pages/goals-desk-v2.webp',
    'assets/pages/goals-living-backdrop-v2.webp',
    'assets/pages/goals-living-backdrop-soft-v2.webp',
    'assets/pages/goals-room-retreat-v1.webp',
    'assets/pages/goals-room-kitchen-v1.webp',
    'assets/pages/goals-threshold-room-v1.webp',
    'assets/pages/goals-threshold-plate-flat-v1.png',
    'assets/pages/goals-return-bookcloth-v1.png',
    'assets/pages/working-room-v1.webp',
  ];

  /// The tapestry glyph and marks (chronicle badge, quest desk, room).
  static const brand = <String>[
    'assets/brand/morrowloom-icon-runtime-v2.webp',
    'assets/brand/morrowloom-tapestry-room-v2.webp',
    'assets/brand/morrow-tapestry-wide-v2.webp',
  ];

  static List<String> get themePreviews => [
    for (final theme in spaceThemes) theme.previewAsset,
  ];

  /// Quests, routines, Plans, Journal, brand marks, the working room and
  /// the theme thumbnails (everything but Goals).
  static List<String> get everyday => [
    ...board,
    ...routine,
    ...plans,
    ...journal,
    ...brand,
    'assets/pages/working-room-v1.webp',
    ...themePreviews,
  ];
}

/// Decodes [assets] for real (runAsync) so the next frames paint them.
Future<void> precacheArt(WidgetTester tester, Iterable<String> assets) async {
  final context = tester.element(find.byType(MaterialApp).first);
  await tester.runAsync(() async {
    for (final asset in assets.toSet()) {
      await precacheImage(AssetImage(asset), context);
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  });
  await tester.pump(const Duration(milliseconds: 120));
}

// ─────────────────────────────────────────────────────────────────────────────
// Driving the real UI
// ─────────────────────────────────────────────────────────────────────────────

enum RoomTab {
  me('ME'),
  quests('QUESTS'),
  goals('GOALS'),
  plans('PLANS'),
  journal('JOURNAL');

  const RoomTab(this.label);
  final String label;
}

/// Taps a dock tab by its label, the way a thumb would.
Future<void> openTab(WidgetTester tester, RoomTab tab) async {
  final label = find.text(tab.label).hitTestable();
  await tester.tap(label.last);
  await tester.pump();
  await settle(tester, total: const Duration(milliseconds: 1400));
}

/// The Quests board's scroll view (a NestedScrollView).
final Finder questBoard = find.byKey(const ValueKey('quest-board-scroll'));

/// On a class day the Quests tab opens on the room; this taps BOARD so the
/// full board (its doors, rails and Quests) is the frame again. A no-op on
/// any other day.
Future<void> showQuestBoard(WidgetTester tester) async {
  final toggle = find.byKey(const Key('class-day-toggle-board')).hitTestable();
  if (toggle.evaluate().isEmpty) return;
  await tester.tap(toggle.first);
  await tester.pump();
  await settle(tester, total: const Duration(milliseconds: 800));
}

/// Every scroll position under [scope], for "did it move" checks.
List<double> scrollOffsets(WidgetTester tester, Finder scope) => [
  for (final s in tester.stateList<ScrollableState>(
    find.descendant(
      of: scope,
      matching: find.byType(Scrollable),
      matchRoot: true,
    ),
  ))
    if (s.position.hasPixels) s.position.pixels,
];

/// Drags [scope] upward until nothing under it scrolls any further. Returns
/// how many drags it took. Bouncing physics are allowed to settle each time.
Future<int> scrollToEnd(
  WidgetTester tester,
  Finder scope, {
  double step = 420,
  int maxDrags = 24,
}) async {
  for (var i = 0; i < maxDrags; i++) {
    final before = scrollOffsets(tester, scope);
    await tester.drag(scope.first, Offset(0, -step), warnIfMissed: false);
    await settle(tester, total: const Duration(milliseconds: 900));
    final after = scrollOffsets(tester, scope);
    if (listEquals(before, after)) return i;
  }
  return maxDrags;
}

/// Drags [scope] upward until [target] is hit-testable (or the end is
/// reached). Returns whether it is now reachable by a tap.
Future<bool> revealIn(
  WidgetTester tester,
  Finder target,
  Finder scope, {
  double step = 260,
  int maxDrags = 16,
}) async {
  for (var i = 0; i <= maxDrags; i++) {
    if (target.hitTestable().evaluate().isNotEmpty) return true;
    final before = scrollOffsets(tester, scope);
    await tester.drag(scope.first, Offset(0, -step), warnIfMissed: false);
    await settle(tester, total: const Duration(milliseconds: 800));
    if (listEquals(before, scrollOffsets(tester, scope))) break;
  }
  return target.hitTestable().evaluate().isNotEmpty;
}

/// Text (plain or rich) whose visible string equals [label] ignoring case,
/// for buttons whose code label is title case but paints in capitals.
Finder findLabel(String label) {
  final wanted = label.toLowerCase();
  return find.byWidgetPredicate((widget) {
    if (widget is Text) {
      final text = widget.data ?? widget.textSpan?.toPlainText();
      return text?.toLowerCase() == wanted;
    }
    if (widget is RichText) {
      return widget.text.toPlainText().toLowerCase() == wanted;
    }
    return false;
  }, description: 'label "$label" (any case)');
}

/// The app's live GameState and Quests (the ones the shell decoded from the
/// seeded save), read from the mounted QuestsPage. [MikaAccount.state] is
/// only the seed; after [bootRoom] the app owns its own copy.
GameState liveState(WidgetTester tester) => tester
    .widget<QuestsPage>(find.byType(QuestsPage, skipOffstage: false))
    .state;

List<Quest> liveQuests(WidgetTester tester) => tester
    .widget<QuestsPage>(find.byType(QuestsPage, skipOffstage: false))
    .quests;

Future<void> scrollToTop(WidgetTester tester, Finder scope) async {
  for (final s in tester.stateList<ScrollableState>(
    find.descendant(
      of: scope,
      matching: find.byType(Scrollable),
      matchRoot: true,
    ),
  )) {
    if (s.position.hasPixels && s.position.pixels != 0) s.position.jumpTo(0);
  }
  await settle(tester, total: const Duration(milliseconds: 500));
}

// ─────────────────────────────────────────────────────────────────────────────
// Concept studies inside the app's real theme
// ─────────────────────────────────────────────────────────────────────────────

/// The app's MaterialApp theme, mirrored from lib/main.dart
/// (`_LifeRpgAppState.build`). If main.dart's theme changes, update this copy;
/// [debugCheckRoomTheme] compares the two on a booted app. The page
/// transitions are the native-calm builders (room_travel.dart), so renders
/// that push a page show the same slide and fade the app does, with no blur.
ThemeData roomThemeData() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Palette.parchment,
  fontFamily: kIsWeb ? 'Inter' : null,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Palette.xp,
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: RoomPageTransitionsBuilder(),
      TargetPlatform.fuchsia: RoomPageTransitionsBuilder(),
      TargetPlatform.linux: RoomPageTransitionsBuilder(),
      TargetPlatform.windows: RoomPageTransitionsBuilder(),
      TargetPlatform.iOS: RoomCupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: RoomCupertinoPageTransitionsBuilder(),
    },
  ),
);

/// On a booted app: true when the live MaterialApp theme still matches
/// [roomThemeData] on the fields a study depends on.
bool debugCheckRoomTheme(WidgetTester tester) {
  final live = tester.widget<MaterialApp>(find.byType(MaterialApp).first).theme;
  final copy = roomThemeData();
  return live != null &&
      live.brightness == copy.brightness &&
      live.scaffoldBackgroundColor == copy.scaffoldBackgroundColor &&
      live.colorScheme == copy.colorScheme &&
      live.useMaterial3 == copy.useMaterial3 &&
      _sameBuilders(live.pageTransitionsTheme, copy.pageTransitionsTheme);
}

bool _sameBuilders(PageTransitionsTheme a, PageTransitionsTheme b) {
  for (final platform in TargetPlatform.values) {
    if (a.builders[platform]?.runtimeType !=
        b.builders[platform]?.runtimeType) {
      return false;
    }
  }
  return true;
}

/// Renders [child] as the home of a MaterialApp built with the app's real
/// theme and text-scale builder, at whatever view size is active (call
/// [phone] first, or use [roomRenderTest]). For concept studies that are not
/// wired into the app yet. Wrap [child] in a Scaffold yourself if it needs
/// one. [precache] decodes art the study paints.
Future<void> pumpPhoneStudy(
  WidgetTester tester,
  Widget child, {
  Iterable<String> precache = const [],
  Duration settleFor = const Duration(milliseconds: 800),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      title: 'Room of Days study',
      debugShowCheckedModeBanner: false,
      theme: roomThemeData(),
      builder: (context, inner) => ValueListenableBuilder<double>(
        valueListenable: appTextScale,
        builder: (context, inApp, _) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: roomTextScaler(MediaQuery.textScalerOf(context), inApp),
          ),
          child: inner ?? const SizedBox.shrink(),
        ),
      ),
      home: child,
    ),
  );
  await tester.pump();
  if (precache.isNotEmpty) await precacheArt(tester, precache);
  await settle(tester, total: settleFor);
}

// ─────────────────────────────────────────────────────────────────────────────
// Capture
// ─────────────────────────────────────────────────────────────────────────────

/// Writes a PNG of the whole screen (the root render view: every route,
/// overlay, dialog and sheet) at the view's physical size, 1179 x 2556 for
/// [phone]. Creates the folder. Returns the file.
Future<File> grab(WidgetTester tester, String absolutePath) async {
  RenderObject ro = tester.renderObject(find.byType(MaterialApp).first);
  while (ro.parent != null) {
    ro = ro.parent!;
  }
  final layer = ro.debugLayer! as OffsetLayer;
  final bounds = ro.paintBounds;
  final file = File(absolutePath);
  await tester.runAsync(() async {
    final image = await layer.toImage(bounds);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
  return file;
}

/// One captured frame, for the contact sheet and NOTES.
class FrameRecord {
  FrameRecord({
    required this.file,
    required this.at,
    required this.surface,
    this.note = '',
  });

  final String file;
  final DateTime at;
  final String surface;
  final String note;

  Map<String, String> toJson() => {
    'file': file,
    'when': _whenLabel(at),
    'at': at.toIso8601String(),
    'surface': surface,
    'note': note,
  };
}

String _whenLabel(DateTime at) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final h = at.hour.toString().padLeft(2, '0');
  final m = at.minute.toString().padLeft(2, '0');
  return '${days[at.weekday - 1]} ${months[at.month - 1]} ${at.day} $h:$m';
}

/// A folder of frames plus `frames.json` (file, when, surface, note), merged
/// across runs so a filtered run does not erase other tests' entries.
class FrameSheet {
  FrameSheet(this.directory);

  final String directory;
  final List<FrameRecord> frames = [];

  Future<File> shot(
    WidgetTester tester,
    String name, {
    required DateTime at,
    required String surface,
    String note = '',
  }) async {
    final file = await grab(tester, '$directory/$name.png');
    frames.add(
      FrameRecord(file: '$name.png', at: at, surface: surface, note: note),
    );
    // ignore: avoid_print
    print('FRAME $name.png  ${_whenLabel(at)}  $surface  $note');
    return file;
  }

  /// Writes frames.json beside the frames. Nothing is written when no frame
  /// was taken this run, so a skipped render file never adds a file to the
  /// checkout.
  void writeManifest() {
    if (frames.isEmpty) return;
    final manifest = File('$directory/frames.json');
    final merged = <String, Map<String, dynamic>>{};
    if (manifest.existsSync()) {
      for (final entry in jsonDecode(manifest.readAsStringSync()) as List) {
        final map = (entry as Map).cast<String, dynamic>();
        merged[map['file'] as String] = map;
      }
    }
    for (final frame in frames) {
      merged[frame.file] = frame.toJson();
    }
    final ordered = merged.values.toList()
      ..sort((a, b) => (a['file'] as String).compareTo(b['file'] as String));
    manifest
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(ordered));
  }
}
