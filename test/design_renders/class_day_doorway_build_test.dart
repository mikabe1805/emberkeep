// Renders the BUILD's Doorway (part 1: the stage, the rail, the glass card) on
// Mika's real Fall 2026 timetable at iPhone size, 393 x 852 at 3x, through the
// real app (LifeRpgApp, his timetable through the app's own importer, the real
// engine). Skipped unless asked for:
//
//   flutter test --dart-define=CLASS_DAY_RENDERS=true \
//     test/design_renders/class_day_doorway_build_test.dart
//
// One filter for quick iteration: --dart-define=DOORWAY_ONLY=tue,busy
//
// Output: design/comparisons/2026-10-10/doorway-build/ in the class-day-journey
// checkout (PNGs at 1179 x 2556, frames.json, render-log.txt). The renders sit
// beside the prototype's own screenshots in the sheet the render run writes.
//
// What is inferred, per frame: the hour (chosen so the light and the card's
// states match the prototype scenario), and which classes are marked. The
// "busy" day adds Computer Architecture and an office hour to his Thursday
// (his real week has no five-event day).
import 'dart:io';

import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/main_room_music.dart';
import 'package:emberkeep/widgets/class_day/class_day_model.dart';
import 'package:emberkeep/widgets/class_day/doorway_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/rutgers_fall_2026_ics_fixture.dart';
import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('CLASS_DAY_RENDERS');
const _only = String.fromEnvironment('DOORWAY_ONLY');
bool _wants(String name) =>
    _only.isEmpty || _only.split(',').map((s) => s.trim()).contains(name);

const _out =
    'C:/Users/mikus/Downloads/experimentProject/app/.worktrees/class-day-journey/'
    'design/comparisons/2026-10-10/doorway-build';

DateTime _at(int day, int hour, int minute) =>
    DateTime(2026, 10, day, hour, minute);

final _log = <String>[];
void _note(String line) {
  _log.add(line);
  // ignore: avoid_print
  print('NOTE $line');
}

final _schedule = mikaSchedule();

/// His Thursday with Computer Architecture and an office hour added: five
/// meetings, one of them optional.
AcademicSchedule _busyThursday() {
  var ics = rutgersFall2026IcsFixture();
  String event(
    String uid,
    String code,
    String title,
    String start,
    String end,
    String kind,
    String building,
    String room,
  ) =>
      'BEGIN:VEVENT\nUID:$uid\n'
      'DTSTART;TZID=America/New_York:20261001T$start\n'
      'DTEND;TZID=America/New_York:20261001T$end\n'
      'RRULE:FREQ=WEEKLY;BYDAY=TH;UNTIL=20261211T045959Z\n'
      'SUMMARY:$title\n'
      'LOCATION:$building-$room\\, Busch Campus\n'
      'X-ROOM-OF-DAYS-TERM:Fall 2026\n'
      'X-ROOM-OF-DAYS-TERM-START:2026-09-01\n'
      'X-ROOM-OF-DAYS-TERM-END:2026-12-10\n'
      'X-ROOM-OF-DAYS-COURSE-CODE:$code\n'
      'X-ROOM-OF-DAYS-COURSE-TITLE:$title\n'
      'X-ROOM-OF-DAYS-SECTION:01\n'
      'X-ROOM-OF-DAYS-MEETING-KIND:$kind\n'
      'X-ROOM-OF-DAYS-CAMPUS:Busch\n'
      'X-ROOM-OF-DAYS-BUILDING:$building\n'
      'X-ROOM-OF-DAYS-ROOM:$room\nEND:VEVENT\n';
  final extra =
      event(
        'busy-arch@roomofdays',
        '14:332:331',
        'Computer Architecture',
        '102000',
        '114000',
        'lecture',
        'HLL',
        '114',
      ) +
      event(
        'busy-oh@roomofdays',
        '14:332:999',
        'Office Hours',
        '123000',
        '132000',
        'office hours',
        'SEC',
        '316',
      );
  ics = ics.replaceFirst('END:VCALENDAR', '${extra}END:VCALENDAR');
  return AcademicScheduleIcsImporter.parse(
    ics,
  ).applyTo(AcademicSchedule.empty(), updatedAt: DateTime.utc(2026, 8, 27));
}

/// Keeps [codes] on the class day at [at] through the engine, the way the
/// room's button does.
void _keep(
  AcademicSchedule schedule,
  GameState state,
  DateTime at,
  Set<String> codes,
) {
  Clock.freeze(at);
  final day = projectClassDay(schedule, Clock.now());
  for (final entry in day.classes) {
    if (!codes.contains(entry.courseCode)) continue;
    final credit = state.keepClass(entry.facts, dayClassKeys: day.dayClassKeys);
    _note(
      '${at.month}/${at.day} kept ${entry.courseCode}: '
      '${credit == null ? 'refused' : '+${credit.xp} XP'}',
    );
  }
}

/// The week before [day]: every class of Mon..day-1 kept at 21:00.
void _keepWeekBefore(AcademicSchedule schedule, GameState state, int day) {
  // Four earlier weeks of the term (one class a day, Tuesdays and Thursdays)
  // so the shelf has its tied weeks, then this week's finished days.
  for (final (month, d) in const [
    (9, 15),
    (9, 17),
    (9, 22),
    (9, 24),
    (9, 29),
    (10, 1),
  ]) {
    final at = DateTime(2026, month, d, 21, 0);
    Clock.freeze(at);
    final earlier = projectClassDay(schedule, Clock.now());
    if (earlier.classes.isEmpty) continue;
    final one = earlier.classes.first.courseCode;
    _keep(schedule, state, at, {one});
  }
  for (var d = 5; d < day; d++) {
    final at = _at(d, 21, 0);
    Clock.freeze(at);
    final today = projectClassDay(schedule, Clock.now());
    _keep(schedule, state, at, {for (final c in today.classes) c.courseCode});
  }
}

Future<void> _boot(
  WidgetTester tester,
  MikaAccount account,
  AcademicSchedule schedule,
  DateTime at,
) async {
  Clock.freeze(at);
  await bootRoom(tester, account, schedule: schedule);
  // The stage asks for its own art; decode exactly what it asks for, in real
  // time, then let the frames catch up.
  final context = tester.element(find.byType(MaterialApp).first);
  await tester.runAsync(() async {
    for (final asset in DoorwayAssets.all) {
      await precacheImage(DoorwayAssets.providerFor(asset), context);
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
  await settle(tester, total: const Duration(milliseconds: 1500));
}

void main() {
  final sheet = FrameSheet(_out);

  setUpAll(setUpRoomRenders);
  tearDownAll(() {
    if (_renders) {
      sheet.writeManifest();
      File('$_out/render-log.txt')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          '${[..._log, for (final l in RenderIssues.lines) 'LAYOUT $l'].join('\n')}\n',
        );
    }
    tearDownRoomRenders();
  });
  setUp(() {
    MainRoomMusic.instance
      ..debugResetForTesting()
      ..debugBypassPlayback = true;
  });
  tearDown(() => MainRoomMusic.instance.debugResetForTesting());

  // At rest: the first class has ended and waits, the rest are to come.
  final rests = <(String, String, DateTime)>[
    ('mon', 'D01_mon_rest', _at(5, 10, 0)),
    ('tue', 'D02_tue_rest', _at(6, 12, 51)),
    ('wed', 'D03_wed_rest', _at(7, 12, 0)),
    ('thu', 'D04_thu_rest', _at(8, 10, 30)),
    ('fri', 'D05_fri_rest', _at(9, 12, 0)),
  ];
  for (final (name, file, at) in rests) {
    roomRenderTest(
      'at rest: $name ${at.hour}:${at.minute.toString().padLeft(2, '0')}',
      skip: !_renders || !_wants(name),
      (tester) async {
        final account = mikaAccount(renderAt: _at(5, 21, 0));
        _keepWeekBefore(_schedule, account.state, at.day);
        await _boot(tester, account, _schedule, at);
        await sheet.shot(
          tester,
          file,
          at: at,
          surface: 'Quests, the Doorway',
          note: 'at rest',
        );
      },
    );
  }

  roomRenderTest(
    'busy: five events, the first ready',
    skip: !_renders || !_wants('busy'),
    (tester) async {
      final schedule = _busyThursday();
      final at = _at(8, 12, 0);
      final account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepWeekBefore(schedule, account.state, 8);
      _keep(schedule, account.state, _at(8, 10, 0), {'14:332:361'});
      await _boot(tester, account, schedule, at);
      await sheet.shot(
        tester,
        'D06_busy_rest',
        at: at,
        surface: 'Quests, the Doorway',
        note: 'five events: one hung, one ready, three to come (one optional)',
      );
      final more = find.byKey(const Key('class-more-later'));
      if (more.evaluate().isNotEmpty) {
        await tester.tap(more.hitTestable().first);
        await tester.pump();
        await settle(tester, total: const Duration(milliseconds: 600));
        await sheet.shot(
          tester,
          'D06b_busy_all',
          at: at,
          surface: 'Quests, the Doorway',
          note: 'the full list open',
        );
      }
    },
  );

  roomRenderTest(
    'one mark: Tuesday after Computer Architecture',
    skip: !_renders || !_wants('mark'),
    (tester) async {
      final at = _at(6, 12, 51);
      final account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepWeekBefore(_schedule, account.state, 6);
      _keep(_schedule, account.state, _at(6, 12, 40), {'14:332:331'});
      await _boot(tester, account, _schedule, at);
      await sheet.shot(
        tester,
        'D07_tue_one_mark',
        at: at,
        surface: 'Quests, the Doorway',
        note: 'one ticket hangs (static); the next class leads the card',
      );
    },
  );

  roomRenderTest(
    'set aside: Tuesday, Couldn\'t make it on the waiting class',
    skip: !_renders || !_wants('aside'),
    (tester) async {
      final at = _at(6, 12, 51);
      final account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepWeekBefore(_schedule, account.state, 6);
      await _boot(tester, account, _schedule, at);
      final aside = find.text(classSetAsideLabel);
      await tester.tap(aside.hitTestable().first);
      await tester.pump();
      await settle(tester, total: const Duration(milliseconds: 900));
      await sheet.shot(
        tester,
        'D08_tue_set_aside',
        at: at,
        surface: 'Quests, the Doorway',
        note: 'Computer Architecture set aside; Undo waits on the card',
      );
    },
  );

  roomRenderTest(
    'the evening: Tuesday 20:15, both classes kept',
    skip: !_renders || !_wants('evening'),
    (tester) async {
      final at = _at(6, 20, 15);
      final account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepWeekBefore(_schedule, account.state, 6);
      _keep(_schedule, account.state, _at(6, 11, 53), {'14:332:331'});
      _keep(_schedule, account.state, _at(6, 15, 35), {'01:198:206'});
      await _boot(tester, account, _schedule, at);
      await sheet.shot(
        tester,
        'D09_tue_evening',
        at: at,
        surface: 'Quests, the Doorway, evening',
        note: 'the glass keeps its evening doors over the evening light',
      );
    },
  );
}
