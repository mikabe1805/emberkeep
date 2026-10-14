// Renders the BUILD's class-day evening on Mika's real week of Oct 5, 2026 at
// iPhone size, through the real app (LifeRpgApp, his Fall 2026 timetable
// through the app's own importer, the real engine's keepClass). Skipped
// unless asked for:
//
//   flutter test --dart-define=CLASS_DAY_RENDERS=true \
//     test/design_renders/class_day_evening_build_test.dart
//
// Output: design/comparisons/2026-10-03/class-day/build/journey/evening/
// (PNGs at 1179 x 2556, frames.json, render-log.txt).
//
// As in the board renders, the week is played forward through the engine as
// if the class day shipped on Monday Oct 5. Inferred, stated per frame: which
// classes he marks and when; E9 gives him the archive room style.
import 'dart:io';

import 'package:emberkeep/a11y.dart';
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/main_room_music.dart';
import 'package:emberkeep/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('CLASS_DAY_RENDERS');

/// One filter for quick iteration: `--dart-define=EVENING_ONLY=tue,mon`.
const _only = String.fromEnvironment('EVENING_ONLY');
bool _wants(String group) =>
    _only.isEmpty || _only.split(',').map((s) => s.trim()).contains(group);

DateTime _at(int day, int hour, int minute) =>
    DateTime(2026, 10, day, hour, minute);

final _log = <String>[];
void _note(String line) {
  _log.add(line);
  // ignore: avoid_print
  print('NOTE $line');
}

/// His timetable, parsed once per run: occurrence keys are minted at import,
/// so the marks seeded here and the app's own projection must share it.
final _schedule = mikaSchedule();

/// Keeps classes of the class day at [at] through the engine, the way the
/// room's button does. [only] picks classes by course code.
void _keepAt(GameState state, DateTime at, {Set<String>? only}) {
  Clock.freeze(at);
  final day = projectClassDay(_schedule, Clock.now());
  for (final entry in day.classes) {
    if (only != null && !only.contains(entry.courseCode)) continue;
    final credit = state.keepClass(entry.facts, dayClassKeys: day.dayClassKeys);
    _note(
      '${Days.key(at)} kept ${entry.courseCode} ${entry.kind.name}: '
      '${credit == null ? 'refused (${state.checkClassKeep(entry.facts)})' : '+${credit.xp} XP'}',
    );
  }
}

/// The week before [day] at 21:00 each night, every class marked.
void _keepWeekBefore(GameState state, int day) {
  for (var d = 5; d < day; d++) {
    _keepAt(state, _at(d, 21, 0));
  }
}

final Finder _there = find.byKey(const Key('class-there-button'));

Future<void> _press(WidgetTester tester, Finder target) async {
  await tester.tap(target.hitTestable().first);
  await tester.pump();
}

/// The held tiers wait for a tap; it starts their way back.
Future<void> _tapAway(WidgetTester tester) async {
  await tester.tapAt(const Offset(196, 420));
  await tester.pump();
}

/// Tuesday with Computer Architecture kept at 11:53 and Discrete Structures
/// II kept at 15:35: both of Tuesday's classes.
MikaAccount _tuesdayKept({bool reduceMotion = false}) {
  final account = mikaAccount(
    renderAt: _at(5, 21, 0),
    reduceMotion: reduceMotion,
  );
  _keepWeekBefore(account.state, 6);
  _keepAt(account.state, _at(6, 11, 53), only: {'14:332:331'});
  _keepAt(account.state, _at(6, 15, 35), only: {'01:198:206'});
  return account;
}

void main() {
  final sheet = FrameSheet(classDayDir('build/journey/evening'));

  setUpAll(setUpRoomRenders);
  tearDownAll(() {
    if (_renders) {
      sheet.writeManifest();
      File('${sheet.directory}/render-log.txt')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          '${[..._log, for (final l in RenderIssues.lines) 'LAYOUT $l'].join('\n')}\n',
        );
    }
    tearDownRoomRenders();
  });
  setUp(() {
    // No audio device here: the rotation reports its take without a player.
    MainRoomMusic.instance
      ..debugResetForTesting()
      ..debugBypassPlayback = true;
  });
  tearDown(() => MainRoomMusic.instance.debugResetForTesting());

  roomRenderTest(
    'E1: Tuesday 15:35, TUESDAY, DONE., then the walk to the armchair',
    skip: !_renders || !_wants('tue'),
    (tester) async {
      final account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepWeekBefore(account.state, 6);
      _keepAt(account.state, _at(6, 11, 53), only: {'14:332:331'});
      final at = _at(6, 15, 35);
      Clock.freeze(at);
      await bootRoom(tester, account, schedule: _schedule);
      await _press(tester, _there);
      await settle(tester, total: const Duration(milliseconds: 2600));
      await sheet.shot(
        tester,
        'E1a_tue1535_day_done',
        at: at,
        surface: 'Class celebration, day tier',
        note: 'held for a tap',
      );
      await _tapAway(tester);
      await tester.pump(const Duration(milliseconds: 180));
      await sheet.shot(
        tester,
        'E1b_tue1535_leaving_180ms',
        at: at,
        surface: 'Class celebration, going back',
        note: 'the words gone, the dim lifting on the kept framing',
      );
      await tester.pump(const Duration(milliseconds: 620));
      await sheet.shot(
        tester,
        'E1c_tue1535_walk_800ms',
        at: at,
        surface: 'Quests, class day evening',
        note: 'the camera walking from the desk toward the window',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await sheet.shot(
        tester,
        'E1d_tue1535_walk_1400ms',
        at: at,
        surface: 'Quests, class day evening',
        note: 'mid-walk: the near planes swing wider than the far ones',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await sheet.shot(
        tester,
        'E1e_tue1535_walk_1900ms',
        at: at,
        surface: 'Quests, class day evening',
        note: 'settling: the glass arriving',
      );
      await settle(tester, total: const Duration(milliseconds: 1600));
      final home = _at(6, 15, 36);
      await sheet.shot(
        tester,
        'E1f_tue1536_evening_afternoon',
        at: home,
        surface: 'Quests, class day evening',
        note:
            'the window and the armchair, the painted night glass; the day on one '
            'line; music, Write a line; no Close the day before 5 PM',
      );
    },
  );

  roomRenderTest(
    'E2: Tuesday 20:30, the evening, music off and on',
    skip: !_renders || !_wants('tue'),
    (tester) async {
      final account = _tuesdayKept();
      final at = _at(6, 20, 30);
      Clock.freeze(at);
      await bootRoom(tester, account, schedule: _schedule);
      // The phone's app in the foreground: music may only run then.
      await reopenApp(tester);
      await settle(tester, total: const Duration(milliseconds: 600));
      await sheet.shot(
        tester,
        'E2a_tue2030_evening_music_off',
        at: at,
        surface: 'Quests, class day evening',
        note: 'night in the window; music off (his saved setting is off)',
      );
      await _press(tester, find.byKey(const Key('class-evening-music')));
      await settle(tester, total: const Duration(milliseconds: 600));
      _note(
        'music after the press: saved setting=${liveState(tester).musicEnabled}, '
        'playing=${MainRoomMusic.instance.nowPlaying.value}',
      );
      await sheet.shot(
        tester,
        'E2b_tue2030_evening_music_on',
        at: at,
        surface: 'Quests, class day evening',
        note: 'Lamp left on playing, for tonight; the saved setting untouched',
      );
      await _press(tester, find.byKey(const Key('class-evening-close-day')));
      await settle(tester, total: const Duration(milliseconds: 1400));
      await sheet.shot(
        tester,
        'E2c_tue2030_close_the_day',
        at: at,
        surface: 'Night ledger',
        note: 'Close the day from the glass opens the real ledger',
      );
    },
  );

  roomRenderTest(
    'E3: Tuesday 20:30, Write a line',
    skip: !_renders || !_wants('tue'),
    (tester) async {
      final account = _tuesdayKept();
      final at = _at(6, 20, 31);
      Clock.freeze(at);
      await bootRoom(tester, account, schedule: _schedule);
      await _press(tester, find.byKey(const Key('class-evening-write')));
      await settle(tester, total: const Duration(milliseconds: 1200));
      await sheet.shot(
        tester,
        'E3_tue2031_write_a_line',
        at: at,
        surface: 'Journal page',
        note: 'a fresh journal page stamped with today',
      );
    },
  );

  roomRenderTest(
    'E4: Monday 19:15, right after the 7 PM class',
    skip: !_renders || !_wants('mon'),
    (tester) async {
      final at = _at(5, 19, 15);
      final account = mikaAccount(renderAt: at);
      await bootRoom(tester, account, schedule: _schedule);
      await sheet.shot(
        tester,
        'E4a_mon1915_evening_three_waiting',
        at: at,
        surface: 'Quests, class day evening',
        note:
            'the wind-down began at 7:00 with the class; the card still leads '
            'with the 5:40 lecture and the shortcut; Close the day in the glass',
      );
      await _press(tester, find.byKey(const Key('class-all-of-today')));
      await settle(tester, total: const Duration(milliseconds: 2400));
      await sheet.shot(
        tester,
        'E4b_mon1915_monday_done_in_the_evening',
        at: at,
        surface: 'Class celebration, day tier',
        note: 'the camera holds the evening framing; the lamp answers there',
      );
      await _tapAway(tester);
      await settle(tester, total: const Duration(milliseconds: 1200));
      await sheet.shot(
        tester,
        'E4c_mon1916_monday_evening',
        at: _at(5, 19, 16),
        surface: 'Quests, class day evening',
        note: 'all three attended, one line; the painted night window',
      );
      await showQuestBoard(tester);
      final reached = await revealIn(
        tester,
        find.byKey(const Key('close-day-rail')),
        questBoard,
      );
      _note('Mon 19:16 board: CLOSE THE DAY rail reachable: $reached');
      await sheet.shot(
        tester,
        'E4d_mon1916_board_rail',
        at: _at(5, 19, 16),
        surface: 'Quests board',
        note: 'BOARD in the evening: the CLOSE THE DAY rail is there',
      );
    },
  );

  roomRenderTest(
    'E5: Monday 17:45, during the late class',
    skip: !_renders || !_wants('mon'),
    (tester) async {
      final account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepAt(account.state, _at(5, 14, 5), only: {'14:332:361'});
      final at = _at(5, 17, 45);
      Clock.freeze(at);
      await bootRoom(tester, account, schedule: _schedule);
      await sheet.shot(
        tester,
        'E5a_mon1745_in_the_late_class',
        at: at,
        surface: 'Quests, class day',
        note: "in session until 7:00: I'M HERE; no evening, no Close the day",
      );
      await showQuestBoard(tester);
      await scrollToEnd(tester, questBoard);
      final rail = find.byKey(const Key('close-day-rail'));
      _note(
        'Mon 17:45 board: CLOSE THE DAY rail present: '
        '${rail.evaluate().isNotEmpty}',
      );
      await sheet.shot(
        tester,
        'E5b_mon1745_board_no_rail',
        at: at,
        surface: 'Quests board',
        note: 'the board scrolled to its end: no CLOSE THE DAY rail mid-class',
      );
    },
  );

  roomRenderTest(
    'E6: Thursday 18:55, after the lab',
    skip: !_renders || !_wants('thu'),
    (tester) async {
      final account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepWeekBefore(account.state, 8);
      _keepAt(account.state, _at(8, 9, 55), only: {'14:332:361'});
      _keepAt(account.state, _at(8, 15, 22), only: {'01:198:206'});
      final at = _at(8, 18, 55);
      Clock.freeze(at);
      await bootRoom(tester, account, schedule: _schedule);
      await sheet.shot(
        tester,
        'E6a_thu1855_lab_waiting',
        at: at,
        surface: 'Quests, class day evening',
        note: 'the lab ended 6:50 and the wind-down began with it',
      );
      await _press(tester, _there);
      await settle(tester, total: const Duration(milliseconds: 2600));
      await _tapAway(tester);
      await settle(tester, total: const Duration(milliseconds: 1200));
      // The lab's Focus crossed a rank: the real rank-up beat follows the
      // celebration. Tap it away as he would.
      final rank = find.text('tap to keep going →');
      _note('Thu: rank-up beat after the lab: ${rank.evaluate().isNotEmpty}');
      if (rank.evaluate().isNotEmpty) {
        await sheet.shot(
          tester,
          'E6b_thu1856_rank_up_beat',
          at: _at(8, 18, 56),
          surface: 'Rank-up beat',
          note: 'Focus ranked up by the lab: the existing chain',
        );
        await tester.tap(rank.first);
        await tester.pump();
        await settle(tester, total: const Duration(milliseconds: 1200));
      }
      await sheet.shot(
        tester,
        'E6c_thu1856_thursday_evening',
        at: _at(8, 18, 56),
        surface: 'Quests, class day evening',
        note: 'all three attended; the painted night window',
      );
    },
  );

  roomRenderTest(
    'E7: another room style (the archive plate), Tuesday 20:30',
    skip: !_renders || !_wants('plate'),
    (tester) async {
      final account = _tuesdayKept();
      account.state
        ..wallStyle = 'wall_archive'
        ..ownedStyles.add('wall_archive');
      _note('inferred: the archive room style, owned');
      final at = _at(6, 20, 30);
      Clock.freeze(at);
      await bootRoom(tester, account, schedule: _schedule);
      await sheet.shot(
        tester,
        'E7_tue2030_archive_evening',
        at: at,
        surface: 'Quests, class day evening',
        note: 'the plate held still behind the same evening glass',
      );
    },
  );

  roomRenderTest(
    'E8: Reduce Motion, Tuesday 15:35',
    skip: !_renders || !_wants('reduce'),
    (tester) async {
      final account = mikaAccount(renderAt: _at(5, 21, 0), reduceMotion: true);
      _keepWeekBefore(account.state, 6);
      _keepAt(account.state, _at(6, 11, 53), only: {'14:332:331'});
      final at = _at(6, 15, 35);
      Clock.freeze(at);
      await bootRoom(tester, account, schedule: _schedule);
      await _press(tester, _there);
      await settle(tester, total: const Duration(milliseconds: 600));
      await _tapAway(tester);
      await tester.pump(const Duration(milliseconds: 140));
      await sheet.shot(
        tester,
        'E8a_tue1535_reduce_motion_fade',
        at: at,
        surface: 'Quests, class day evening',
        note: 'no walk: the desk still fading into the evening still',
      );
      await settle(tester, total: const Duration(milliseconds: 800));
      await sheet.shot(
        tester,
        'E8b_tue1536_reduce_motion_evening',
        at: _at(6, 15, 36),
        surface: 'Quests, class day evening',
        note: 'the evening, still',
      );
    },
  );

  roomRenderTest(
    'E9: text at 130%, Tuesday 20:30 and Monday 19:15',
    skip: !_renders || !_wants('text'),
    (tester) async {
      final account = _tuesdayKept();
      account.state.textScale = 1.3;
      appTextScale.value = 1.3;
      addTearDown(() => appTextScale.value = 1.0);
      final at = _at(6, 20, 30);
      Clock.freeze(at);
      await bootRoom(tester, account, schedule: _schedule);
      await sheet.shot(
        tester,
        'E9a_tue2030_text_130',
        at: at,
        surface: 'Quests, class day evening',
        note: 'in-app text size 130%',
      );
    },
  );

  roomRenderTest(
    'E9b: text at 130%, Monday 19:15 with three waiting',
    skip: !_renders || !_wants('text'),
    (tester) async {
      final at = _at(5, 19, 15);
      final account = mikaAccount(renderAt: at);
      account.state.textScale = 1.3;
      appTextScale.value = 1.3;
      addTearDown(() => appTextScale.value = 1.0);
      await bootRoom(tester, account, schedule: _schedule);
      await sheet.shot(
        tester,
        'E9b_mon1915_text_130_waiting',
        at: at,
        surface: 'Quests, class day evening',
        note: 'the tallest evening glass at 130%',
      );
    },
  );
}
