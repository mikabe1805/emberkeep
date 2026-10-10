// Renders the BUILD's Doorway moves (part 2: the mark in the scene, the day's
// tickets into the bowl, the week's bundle onto the shelf, the restyled bar)
// on Mika's real Fall 2026 timetable at iPhone size, 393 x 852 at 3x, through
// the real app. Skipped unless asked for:
//
//   flutter test --dart-define=CLASS_DAY_RENDERS=true \
//     test/design_renders/class_day_doorway_motion_build_test.dart
//
// One filter for quick iteration: --dart-define=DOORWAY_ONLY=tue,day,week
//
// Output: design/comparisons/2026-10-10/doorway-build/part2/ in the
// class-day-journey checkout (PNGs at 1179 x 2556, frames.json). The frames
// are taken by pumping the real app: a frame at 420 ms is the app 420 ms after
// the tap on I WAS THERE, the stage's own clock. The sheet script puts them
// beside the prototype's own screenshots.
import 'dart:io';

import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/main_room_music.dart';
import 'package:emberkeep/widgets/class_day/doorway_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('CLASS_DAY_RENDERS');
const _only = String.fromEnvironment('DOORWAY_ONLY');
bool _wants(String name) =>
    _only.isEmpty || _only.split(',').map((s) => s.trim()).contains(name);

const _out =
    'C:/Users/mikus/Downloads/experimentProject/app/.worktrees/class-day-journey/'
    'design/comparisons/2026-10-10/doorway-build/part2';

DateTime _at(int day, int hour, int minute) =>
    DateTime(2026, 10, day, hour, minute);

final _schedule = mikaSchedule();

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
    state.keepClass(entry.facts, dayClassKeys: day.dayClassKeys);
  }
}

/// Four earlier weeks of the term (one class on a Tuesday and a Thursday), then
/// this week's finished days, so the shelf has its bundles and the bowl its
/// pairs.
void _keepWeekBefore(AcademicSchedule schedule, GameState state, int day) {
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
    _keep(schedule, state, at, {earlier.classes.first.courseCode});
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
  DateTime at,
) async {
  Clock.freeze(at);
  await bootRoom(tester, account, schedule: _schedule);
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
    if (_renders) sheet.writeManifest();
    tearDownRoomRenders();
  });
  setUp(() {
    MainRoomMusic.instance
      ..debugResetForTesting()
      ..debugBypassPlayback = true;
  });
  tearDown(() => MainRoomMusic.instance.debugResetForTesting());

  /// Pumps to [ms] after the tap (from [now]) in 20 ms frames and takes the
  /// frame, returning [ms].
  Future<int> frame(
    WidgetTester tester,
    int now,
    int ms,
    String name,
    DateTime at,
    String note,
  ) async {
    for (var t = now; t < ms; t += 20) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await sheet.shot(
      tester,
      name,
      at: at,
      surface: 'Quests, the Doorway',
      note: note,
    );
    return ms;
  }

  roomRenderTest(
    'the Tuesday mark, frame by frame',
    skip: !_renders || !_wants('tue'),
    (tester) async {
      final at = _at(6, 12, 51);
      final account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepWeekBefore(_schedule, account.state, 6);
      await _boot(tester, account, at);
      await sheet.shot(
        tester,
        'M00_tue_before',
        at: at,
        surface: 'Quests, the Doorway',
        note: 'before the tap: the waiting ticket in its holder',
      );
      await tester.tap(find.byKey(const Key('class-there-button')));
      await tester.pump();
      var now = 0;
      for (final ms in const [0, 120, 300, 420, 700, 1200, 2000]) {
        now = await frame(
          tester,
          now,
          ms,
          'M${ms.toString().padLeft(4, '0')}_tue_mark',
          at,
          '$ms ms after the tap',
        );
      }
      now = await frame(
        tester,
        now,
        3200,
        'M3200_tue_card_after',
        at,
        'the card after: attended, the next class leads',
      );
    },
  );

  roomRenderTest(
    'the day: both tickets into the bowl',
    skip: !_renders || !_wants('day'),
    (tester) async {
      final at = _at(6, 15, 35);
      final account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepWeekBefore(_schedule, account.state, 6);
      _keep(_schedule, account.state, _at(6, 11, 53), {'14:332:331'});
      await _boot(tester, account, at);
      await sheet.shot(
        tester,
        'D00_day_before',
        at: at,
        surface: 'Quests, the Doorway',
        note: 'the first class hangs; the last one waits',
      );
      await tester.tap(find.byKey(const Key('class-there-button')));
      await tester.pump();
      var now = 0;
      for (final (ms, name, note) in const [
        (1600, 'D1600_both_hung', 'both tickets hang'),
        (2150, 'D2150_unhooked', 'unhooking and clipping together'),
        (2450, 'D2450_arc', 'arcing down to the bowl, the beam warm'),
        (2900, 'D2900_landed', 'in the bowl'),
        (3300, 'D3300_beat', 'the beat before the day'),
        (4800, 'D4800_tier', 'the day card'),
      ]) {
        now = await frame(tester, now, ms, name, at, note);
      }
    },
  );

  roomRenderTest(
    'the week: the bundle onto the shelf',
    skip: !_renders || !_wants('week'),
    (tester) async {
      final at = _at(9, 18, 56);
      final account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepWeekBefore(_schedule, account.state, 9);
      _keep(_schedule, account.state, _at(9, 11, 45), {'14:332:331'});
      await _boot(tester, account, at);
      await tester.tap(find.byKey(const Key('class-there-button')));
      await tester.pump();
      var now = 0;
      for (final (ms, name, note) in const [
        (3000, 'W3000_bowl', "the day's pair in the bowl"),
        (3700, 'W3700_rising', 'the bundle rises from the bowl'),
        (4200, 'W4200_arriving', 'the bundle nears the shelf'),
        (4900, 'W4900_settled', 'the bundle stands on the shelf'),
        (7000, 'W7000_tier', "that's the week"),
      ]) {
        now = await frame(tester, now, ms, name, at, note);
      }
    },
  );

  roomRenderTest(
    'Reduce Motion: the Tuesday mark',
    skip: !_renders || !_wants('rm'),
    (tester) async {
      final at = _at(6, 12, 51);
      final account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepWeekBefore(_schedule, account.state, 6);
      account.state.reduceMotion = true;
      await _boot(tester, account, at);
      await tester.tap(find.byKey(const Key('class-there-button')));
      await tester.pump();
      var now = 0;
      for (final ms in const [120, 600]) {
        now = await frame(
          tester,
          now,
          ms,
          'R${ms.toString().padLeft(4, '0')}_tue_reduce_motion',
          at,
          'Reduce Motion, $ms ms after the tap',
        );
      }
    },
  );

  tearDownAll(() {
    if (_renders && Directory(_out).existsSync()) {
      // ignore: avoid_print
      print('FRAMES in $_out');
    }
  });
}
