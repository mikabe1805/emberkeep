// Renders a MOCK of every Day Ledger widget state from real snapshots: his
// Fall 2026 timetable, the real WidgetSnapshotBuilder, the real engine keeps,
// encoded to JSON and read back the way the Swift decoder reads it
// (test/home_widgets/day_ledger_mirror.dart), at the widget's real iOS
// sizes.
//
// Run:
//   flutter test --dart-define=CLASS_DAY_RENDERS=true \
//     [--dart-define=WIDGET_RENDER_DIR=<absolute folder>] \
//     test/design_renders/class_day_widget_render_test.dart
library;

import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/home_widgets/widget_snapshot.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home_widgets/day_ledger_mirror.dart';
import 'class_day_harness.dart';
import 'day_ledger_widget_mock.dart';

const _renders = bool.fromEnvironment('CLASS_DAY_RENDERS');
const _dir = String.fromEnvironment('WIDGET_RENDER_DIR');

/// His New York wall clock as an instant (EDT through Oct 31).
DateTime ny(int month, int day, int hour, int minute) => DateTime.utc(
  2026,
  month,
  day,
  hour + (month < 11 ? 4 : 5),
  minute,
).toLocal();

/// The store account's Quests; "Read ten pages" was done on his Tuesday, so
/// Tuesday's list and Wednesday's list differ at midnight.
List<Quest> _quests() => [
  for (final (index, title) in mikaQuestTitles.indexed)
    Quest(
      title: title,
      stat: Stat.values[index % Stat.values.length],
      difficulty: 2 + index % 3,
      lastDoneDay: title == 'Read ten pages' ? '2026-10-06' : null,
    ),
];

/// Keeps the class with [code] on the day [Clock.now] belongs to.
void _keep(GameState state, AcademicSchedule schedule, String code) {
  final day = projectClassDay(schedule, Clock.now());
  final entry = day.classes.firstWhere((entry) => entry.courseCode == code);
  final credit = state.keepClass(entry.facts, dayClassKeys: day.dayClassKeys);
  if (credit == null) throw StateError('Could not keep $code');
}

/// What the widget reads at [at] when the app last published at
/// [publishedAt] after [keeps] (each a code kept at its time).
DayLedgerEntry _entry({
  required DateTime publishedAt,
  required DateTime at,
  List<(DateTime, String)> keeps = const [],
  bool timetable = true,
}) {
  final schedule = timetable ? mikaSchedule() : AcademicSchedule.empty();
  final state = GameState();
  for (final (keptAt, code) in keeps) {
    Clock.freeze(keptAt);
    _keep(state, schedule, code);
  }
  Clock.freeze(publishedAt);
  final snapshot = WidgetSnapshotBuilder.build(
    quests: _quests(),
    schedule: schedule,
    now: publishedAt,
    state: state,
  );
  Clock.freeze(at);
  return DayLedgerEntry(at, LedgerSnapshot.load(snapshot.encode()));
}

String _hm(DateTime local) {
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  return '$hour:${local.minute.toString().padLeft(2, '0')}';
}

void main() {
  setUpAll(setUpRoomRenders);
  tearDownAll(tearDownRoomRenders);
  final sheet = FrameSheet(
    _dir.isEmpty ? classDayDir('build/journey/widget') : _dir,
  );
  tearDownAll(() {
    if (_renders) sheet.writeManifest();
  });

  Future<void> frame(
    WidgetTester tester,
    String name, {
    required DayLedgerEntry entry,
    required String tag,
    required String caption,
    required String surface,
  }) async {
    await pumpPhoneStudy(
      tester,
      DayLedgerHomeScreenMock(
        entry: entry,
        clock: _hm(entry.date.toLocal()),
        tag: tag,
        caption: caption,
      ),
    );
    final small = entry.smallUrl ?? 'opens the app';
    final medium = entry.mediumUrl ?? 'opens the app';
    await sheet.shot(
      tester,
      name,
      at: entry.date.toLocal(),
      surface: surface,
      note: 'mode ${entry.mode.name}; small tap: $small; medium tap: $medium',
    );
  }

  roomRenderTest('Day Ledger widget states', skip: !_renders, (tester) async {
    final morning = ny(10, 6, 8, 5);
    final firstMark = ny(10, 6, 11, 53);

    await frame(
      tester,
      'W01_tue0805_before_class',
      entry: _entry(publishedAt: morning, at: morning),
      tag: 'MOCK · DAY LEDGER · BEFORE CLASS',
      surface: 'Widget, everyday',
      caption:
          'Tue 8:05 AM. Before the first class the widget keeps its everyday '
          'look: the next class and up to three quests.',
    );
    await frame(
      tester,
      'W02_tue1045_in_session',
      entry: _entry(publishedAt: morning, at: ny(10, 6, 10, 45)),
      tag: "MOCK · DAY LEDGER · IN CLASS",
      surface: 'Widget, in session',
      caption:
          "Tue 10:45 AM, app last opened at 8:05. The class in session can be "
          "marked: I'M HERE opens Room of Days and keeps it there, with the "
          'same celebration as the board.',
    );
    await frame(
      tester,
      'W03_tue1152_between_classes',
      entry: _entry(publishedAt: morning, at: ny(10, 6, 11, 52)),
      tag: 'MOCK · DAY LEDGER · BETWEEN CLASSES',
      surface: 'Widget, between classes',
      caption:
          'Tue 11:52 AM. The class that just ended, its one I WAS THERE, and '
          'the next one. The small widget is one tap: it opens the mark link.',
    );
    await frame(
      tester,
      'W04_tue1153_after_mark',
      entry: _entry(
        publishedAt: firstMark,
        at: firstMark,
        keeps: [(firstMark, '14:332:331')],
      ),
      tag: 'MOCK · DAY LEDGER · AFTER THE MARK',
      surface: 'Widget, kept',
      caption:
          'Tue 11:53 AM, right after the keep. The app republished: the class '
          'reads attended with its XP, and the next one is up.',
    );
    await frame(
      tester,
      'W05_tue1535_classes_done',
      entry: _entry(
        publishedAt: firstMark,
        at: ny(10, 6, 15, 35),
        keeps: [(firstMark, '14:332:331')],
      ),
      tag: 'MOCK · DAY LEDGER · AFTER THE LAST CLASS',
      surface: 'Widget, classes done',
      caption:
          'Tue 3:35 PM, app not opened since 11:53. The widget moved on by '
          'itself at 3:20: Classes done, the kept one with its XP, the '
          'waiting one with I WAS THERE, and tomorrow with its day.',
    );
    final secondMark = ny(10, 6, 15, 36);
    await frame(
      tester,
      'W06_tue1536_all_kept',
      entry: _entry(
        publishedAt: secondMark,
        at: secondMark,
        keeps: [(firstMark, '14:332:331'), (secondMark, '01:198:206')],
      ),
      tag: 'MOCK · DAY LEDGER · ALL KEPT',
      surface: 'Widget, all kept',
      caption:
          "Tue 3:36 PM. Both kept: one quiet line and the day's class XP "
          '(25 + 25 + the 10 full-day bonus).',
    );
    await frame(
      tester,
      'W07_tue2030_evening',
      entry: _entry(
        publishedAt: secondMark,
        at: ny(10, 6, 20, 30),
        keeps: [(firstMark, '14:332:331'), (secondMark, '01:198:206')],
      ),
      tag: 'MOCK · DAY LEDGER · EVENING',
      surface: 'Widget, evening',
      caption:
          'Tue 8:30 PM. The evening is the everyday look again, and the next '
          'class carries its day: WED 8:30 AM.',
    );
    final evening = ny(10, 6, 20, 30);
    await frame(
      tester,
      'W08_wed0005_midnight',
      entry: _entry(publishedAt: evening, at: ny(10, 7, 0, 5)),
      tag: 'MOCK · DAY LEDGER · AFTER MIDNIGHT',
      surface: 'Widget, midnight',
      caption:
          "Wed 12:05 AM, app last opened at 8:30 PM. At midnight Tuesday's "
          "list gives way to the new day's (Read ten pages, done Tuesday, is "
          "back). The lab is today's now, so it loses its day word.",
    );
    await frame(
      tester,
      'W09_mon1905_three_waiting',
      entry: _entry(publishedAt: ny(10, 5, 8, 0), at: ny(10, 5, 19, 5)),
      tag: 'MOCK · DAY LEDGER · MONDAY, CLASSES DONE',
      surface: 'Widget, classes done',
      caption:
          'Mon 7:05 PM, after his 5:40 to 7:00 class. Three rows; the newest '
          'carries the one bright I WAS THERE, the others are quiet links. '
          'It holds until 8:00 PM, then the evening look.',
    );
    final thuMorning = ny(10, 8, 9, 55);
    final thuAfternoon = ny(10, 8, 15, 25);
    await frame(
      tester,
      'W10_thu1855_lab_waiting',
      entry: _entry(
        publishedAt: thuAfternoon,
        at: ny(10, 8, 18, 55),
        keeps: [(thuMorning, '14:332:361'), (thuAfternoon, '01:198:206')],
      ),
      tag: 'MOCK · DAY LEDGER · THURSDAY AFTER THE LAB',
      surface: 'Widget, classes done',
      caption:
          'Thu 6:55 PM. Two kept with their XP, the lab that ended at 6:50 '
          'waiting with I WAS THERE.',
    );
    await frame(
      tester,
      'W13_wed1135_lab_ended',
      entry: _entry(publishedAt: ny(10, 7, 8, 0), at: ny(10, 7, 11, 35)),
      tag: 'MOCK · DAY LEDGER · WEDNESDAY AFTER THE LAB',
      surface: 'Widget, between classes',
      caption:
          'Wed 11:35 AM. The three-hour lab ended at 11:30; the longest title '
          'he has, on both sizes.',
    );
    await frame(
      tester,
      'W11_sat1100_no_classes',
      entry: _entry(publishedAt: ny(10, 10, 11, 0), at: ny(10, 10, 11, 0)),
      tag: 'MOCK · DAY LEDGER · NO CLASSES',
      surface: 'Widget, no classes',
      caption:
          'Sat 11:00 AM. A day without classes keeps the everyday look; '
          "Monday's class carries its day.",
    );
    await frame(
      tester,
      'W12_tue1152_no_timetable',
      entry: _entry(
        publishedAt: ny(10, 6, 11, 52),
        at: ny(10, 6, 11, 52),
        timetable: false,
      ),
      tag: 'MOCK · DAY LEDGER · NO TIMETABLE',
      surface: 'Widget, no timetable',
      caption: 'No timetable imported: exactly the widget as it is today.',
    );
  });
}
