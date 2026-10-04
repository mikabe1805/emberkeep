// Renders the BUILD's class-day board and celebration on Mika's real week of
// Oct 5, 2026 at iPhone size, through the real app (LifeRpgApp, his Fall 2026
// timetable through the app's own importer, the real engine's keepClass).
// Skipped unless asked for:
//
//   flutter test --dart-define=CLASS_DAY_RENDERS=true \
//     test/design_renders/class_day_board_build_test.dart
//
// Output: design/comparisons/2026-10-03/class-day/build/journey/board/
// (PNGs at 1179 x 2556, frames.json, render-log.txt).
//
// The week is played forward through the engine as if the class day shipped
// on Monday Oct 5: every number is what the build pays (no seeded counts).
// Inferred, stated per frame: which classes he marks and when; the level
// crossing frame lifts his XP to 850 / 870 and sets 11 quests since level 18.
import 'dart:convert';
import 'dart:io';

import 'package:emberkeep/a11y.dart';
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/widgets/class_day/class_kept_celebration.dart';
import 'package:emberkeep/widgets/levelup_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('CLASS_DAY_RENDERS');

/// One filter for quick iteration: `--dart-define=BOARD_ONLY=tue,mon`.
const _only = String.fromEnvironment('BOARD_ONLY');
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
/// board's button does (same facts, same day keys). [only] picks classes by
/// course code. Leaves the clock at [at].
void _keepAt(GameState state, DateTime at, {Set<String>? only}) {
  Clock.freeze(at);
  final day = projectClassDay(_schedule, Clock.now());
  for (final entry in day.classes) {
    if (only != null && !only.contains(entry.courseCode)) continue;
    final credit = state.keepClass(entry.facts, dayClassKeys: day.dayClassKeys);
    _note(
      '${Days.key(at)} kept ${entry.courseCode}: '
      '${credit == null ? 'refused (${state.checkClassKeep(entry.facts)})' : '+${credit.xp} XP'}',
    );
  }
}

/// The week before [day] at 21:00 each night, as the board would have kept
/// it (every class marked).
void _keepWeekBefore(GameState state, int day) {
  for (var d = 5; d < day; d++) {
    _keepAt(state, _at(d, 21, 0));
  }
}

/// The same account with [counts] earlier keeps per course (as later weeks
/// of the term would have them). Inferred, stated per frame.
MikaAccount _withCourseCounts(MikaAccount account, Map<String, int> counts) {
  final json =
      jsonDecode(jsonEncode(account.state.toJson())) as Map<String, dynamic>;
  json['keptClassCounts'] = {
    ...(json['keptClassCounts'] as Map? ?? const {}),
    ...counts,
  };
  return MikaAccount(
    GameState.fromJson(json),
    account.quests,
    lastActive: account.lastActive,
  );
}

final Finder _there = find.byKey(const Key('class-there-button'));
final Finder _celebration = find.byType(ClassKeptCelebration);

Future<void> _press(WidgetTester tester, Finder target) async {
  await tester.tap(target.hitTestable().first);
  await tester.pump();
}

Future<void> _dismissCelebration(WidgetTester tester) async {
  if (_celebration.evaluate().isEmpty) return;
  await tester.tapAt(const Offset(196, 420));
  await tester.pump();
  // A held tier that ends the day hands the room to the evening: let the
  // camera's walk to the armchair (2.4 s) settle.
  await settle(tester, total: const Duration(milliseconds: 3000));
}

void main() {
  final sheet = FrameSheet(classDayDir('build/journey/board'));

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

  roomRenderTest(
    'B: Tuesday between classes, the mark and its celebration',
    skip: !_renders || !_wants('tue'),
    (tester) async {
      final at = _at(6, 11, 52);
      final account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepWeekBefore(account.state, 6);
      Clock.freeze(at);
      await bootRoom(tester, account, schedule: _schedule);
      await sheet.shot(
        tester,
        'B1_tue1152_between_classes',
        at: at,
        surface: 'Quests, class day',
        note: 'Computer Architecture ended 11:40, Discrete at 2:00',
      );

      final gesture = await tester.startGesture(
        tester.getCenter(_there.hitTestable().first),
      );
      await tester.pump(const Duration(milliseconds: 60));
      await sheet.shot(
        tester,
        'B2a_tue1152_press',
        at: at,
        surface: 'Quests, class day',
        note: 'finger down: the plate sinks into the glass',
      );
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await sheet.shot(
        tester,
        'B2b_tue1152_contact_100ms',
        at: at,
        surface: 'Quests, class day',
        note: 'released: the card ring closing, completion composite',
      );
      await tester.pump(const Duration(milliseconds: 200));
      await sheet.shot(
        tester,
        'B2c_tue1152_celebration_300ms',
        at: at,
        surface: 'Class celebration',
        note: 'camera easing back, headline mid-slam',
      );
      await settle(tester, total: const Duration(milliseconds: 1600));
      await sheet.shot(
        tester,
        'B2d_tue1152_celebration_settled',
        at: at,
        surface: 'Class celebration',
        note: 'settled at 1.9 s, returns on its own at 2.4 s',
      );
      await settle(tester, total: const Duration(milliseconds: 400));
      await sheet.shot(
        tester,
        'B2e_tue1152_going_back_2300ms',
        at: at,
        surface: 'Class celebration',
        note:
            'going back on its own: the takeover fading, the camera easing '
            'back to the desk framing',
      );
      await settle(tester, total: const Duration(milliseconds: 1000));
      _note('celebration gone on its own: ${_celebration.evaluate().isEmpty}');
      await sheet.shot(
        tester,
        'B3_tue1153_after_first_mark',
        at: at,
        surface: 'Quests, class day',
        note: 'back in the room: Discrete leads, Computer Architecture kept',
      );

      // Undo: the latest kept row swiped left past 42%.
      final row = find.byWidgetPredicate(
        (w) => w is Dismissible && '${w.key}'.contains('class-undo-'),
      );
      _note('undo row present: ${row.evaluate().isNotEmpty}');
      if (row.evaluate().isNotEmpty) {
        final drag = await tester.startGesture(tester.getCenter(row));
        await drag.moveBy(const Offset(-90, 0));
        await tester.pump(const Duration(milliseconds: 120));
        await drag.moveBy(const Offset(-80, 0));
        await tester.pump(const Duration(milliseconds: 120));
        await sheet.shot(
          tester,
          'U1_tue1153_undo_swipe',
          at: at,
          surface: 'Quests, class day',
          note: 'the kept row dragged left: UNDO behind it',
        );
        await drag.moveBy(const Offset(-60, 0));
        await drag.up();
        await tester.pump();
        await settle(tester, total: const Duration(milliseconds: 1200));
        _note('after undo: xp=${liveState(tester).xp}');
        await sheet.shot(
          tester,
          'U2_tue1153_after_undo',
          at: at,
          surface: 'Quests, class day',
          note: 'restored: Computer Architecture ready again',
        );
      }
    },
  );

  roomRenderTest(
    'C: Tuesday countdown and in session',
    skip: !_renders || !_wants('tue'),
    (tester) async {
      final account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepWeekBefore(account.state, 6);
      _keepAt(account.state, _at(6, 11, 53), only: {'14:332:331'});
      final soon = _at(6, 13, 48);
      Clock.freeze(soon);
      await bootRoom(tester, account, schedule: _schedule);
      await sheet.shot(
        tester,
        'C1_tue1348_starts_in_12',
        at: soon,
        surface: 'Quests, class day',
        note: 'a countdown only inside the last 15 minutes',
      );
      final during = _at(6, 14, 40);
      Clock.freeze(during);
      await reopenApp(tester);
      await settle(tester, total: const Duration(milliseconds: 800));
      await sheet.shot(
        tester,
        'C2_tue1440_in_session',
        at: during,
        surface: 'Quests, class day',
        note: "in session: I'M HERE",
      );
    },
  );

  roomRenderTest(
    'D: Tuesday 15:35, the last class, TUESDAY, DONE.',
    skip: !_renders || !_wants('tue'),
    (tester) async {
      final account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepWeekBefore(account.state, 6);
      _keepAt(account.state, _at(6, 11, 53), only: {'14:332:331'});
      final at = _at(6, 15, 35);
      Clock.freeze(at);
      await bootRoom(tester, account, schedule: _schedule);
      await sheet.shot(
        tester,
        'D1_tue1535_last_class_ready',
        at: at,
        surface: 'Quests, class day',
        note: 'Discrete ended 3:20',
      );
      await _press(tester, _there);
      await tester.pump(const Duration(milliseconds: 300));
      await sheet.shot(
        tester,
        'D2a_tue1535_day_300ms',
        at: at,
        surface: 'Class celebration, day tier',
        note: '',
      );
      await settle(tester, total: const Duration(milliseconds: 2400));
      await sheet.shot(
        tester,
        'D2b_tue1535_day_settled',
        at: at,
        surface: 'Class celebration, day tier',
        note: 'held for a tap',
      );
      await settle(tester, total: const Duration(milliseconds: 3000));
      _note(
        'day tier still up after 5.7 s: ${_celebration.evaluate().isNotEmpty}',
      );
      await _dismissCelebration(tester);
      final home = _at(6, 15, 36);
      await sheet.shot(
        tester,
        'D3_tue1536_back_home',
        at: home,
        surface: 'Quests, class day evening',
        note: 'the evening: both attended on one line (the evening slice)',
      );
      await tester.tap(find.byKey(const Key('class-day-toggle-board')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 230));
      await sheet.shot(
        tester,
        'D4a_tue1536_board_rising',
        at: home,
        surface: 'Quests',
        note: 'BOARD: the board slides up over the room, no blur',
      );
      await settle(tester, total: const Duration(milliseconds: 800));
      await sheet.shot(
        tester,
        'D4b_tue1536_board',
        at: home,
        surface: 'Quests',
        note: 'the full board, ROOM line above the dock',
      );
    },
  );

  roomRenderTest(
    'X: Monday 19:15, three waiting, one shortcut',
    skip: !_renders || !_wants('mon'),
    (tester) async {
      final at = _at(5, 19, 15);
      final account = mikaAccount(renderAt: at);
      await bootRoom(tester, account, schedule: _schedule);
      await sheet.shot(
        tester,
        'X1_mon1915_three_waiting',
        at: at,
        surface: 'Quests, class day',
        note: 'the 5:40 lecture foremost; the shortcut under it',
      );
      await _press(tester, find.byKey(const Key('class-all-of-today')));
      await tester.pump(const Duration(milliseconds: 300));
      await sheet.shot(
        tester,
        'X2a_mon1915_monday_300ms',
        at: at,
        surface: 'Class celebration, day tier',
        note: '',
      );
      await settle(tester, total: const Duration(milliseconds: 2400));
      await sheet.shot(
        tester,
        'X2b_mon1915_monday_done',
        at: at,
        surface: 'Class celebration, day tier',
        note: 'one celebration for all three',
      );
      await _dismissCelebration(tester);
      await sheet.shot(
        tester,
        'X3_mon1916_monday_record',
        at: at,
        surface: 'Quests, class day',
        note: '',
      );
    },
  );

  roomRenderTest(
    'Q: Thursday 15:22, two waiting before the lab, the quick chain',
    skip: !_renders || !_wants('thu'),
    (tester) async {
      final account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepWeekBefore(account.state, 8);
      final at = _at(8, 15, 22);
      Clock.freeze(at);
      await bootRoom(tester, account, schedule: _schedule);
      await sheet.shot(
        tester,
        'Q1_thu1522_two_waiting',
        at: at,
        surface: 'Quests, class day',
        note: 'Discrete foremost, Electronics a quiet dot, the lab at 3:50',
      );
      await _press(tester, _there);
      await settle(tester, total: const Duration(milliseconds: 1200));
      await _dismissCelebration(tester);
      final second = at.add(const Duration(seconds: 6));
      Clock.freeze(second);
      final quiet = find.textContaining('Electronics Devices');
      await tester.tap(quiet.hitTestable().first);
      await tester.pump();
      await settle(tester, total: const Duration(milliseconds: 500));
      await sheet.shot(
        tester,
        'Q2_thu1522_brought_forward',
        at: second,
        surface: 'Quests, class day',
        note: 'the quiet row tapped: it leads',
      );
      await _press(tester, _there);
      await tester.pump(const Duration(milliseconds: 700));
      await sheet.shot(
        tester,
        'Q3_thu1522_that_one_too',
        at: second,
        surface: 'Class celebration, quick tier',
        note: '1.5x, back at 1.4 s',
      );
      await settle(tester, total: const Duration(milliseconds: 1000));
      _note('quick tier gone at 1.7 s: ${_celebration.evaluate().isEmpty}');
    },
  );

  roomRenderTest(
    'W: Friday 18:56, the week',
    skip: !_renders || !_wants('fri'),
    (tester) async {
      final account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepWeekBefore(account.state, 9);
      _keepAt(account.state, _at(9, 11, 45), only: {'14:332:331'});
      final at = _at(9, 18, 56);
      Clock.freeze(at);
      await bootRoom(tester, account, schedule: _schedule);
      await sheet.shot(
        tester,
        'W1_fri1856_last_of_the_week',
        at: at,
        surface: 'Quests, class day',
        note: '',
      );
      await _press(tester, _there);
      await settle(tester, total: const Duration(milliseconds: 2600));
      await sheet.shot(
        tester,
        'W2_fri1856_thats_the_week',
        at: at,
        surface: 'Class celebration, week tier',
        note: 'twelve for twelve',
      );
    },
  );

  roomRenderTest(
    'W2: Friday 18:56, a week with Tuesday Discrete unmarked',
    skip: !_renders || !_wants('fri'),
    (tester) async {
      final account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepAt(account.state, _at(5, 21, 0));
      _keepAt(account.state, _at(6, 21, 0), only: {'14:332:331'});
      for (final d in [7, 8]) {
        _keepAt(account.state, _at(d, 21, 0));
      }
      _keepAt(account.state, _at(9, 11, 45), only: {'14:332:331'});
      final at = _at(9, 18, 56);
      Clock.freeze(at);
      await bootRoom(tester, account, schedule: _schedule);
      await _press(tester, _there);
      await settle(tester, total: const Duration(milliseconds: 2600));
      await sheet.shot(
        tester,
        'W3_fri1856_eleven_this_week',
        at: at,
        surface: 'Class celebration, week tier',
        note: 'Tuesday Discrete left neutral: no denominator',
      );
    },
  );

  roomRenderTest(
    'L: a level crossed by a mark',
    skip: !_renders || !_wants('level'),
    (tester) async {
      final at = _at(6, 11, 52);
      final account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepWeekBefore(account.state, 6);
      account.state
        ..xp = 850
        ..completionsAtLastLevel = account.state.totalCompletions - 11
        ..classesAtLastLevel = 0;
      _note('inferred: xp 850 / 870 and 11 quests since level 18');
      Clock.freeze(at);
      await bootRoom(tester, account, schedule: _schedule);
      await _press(tester, _there);
      await settle(tester, total: const Duration(milliseconds: 1900));
      await sheet.shot(
        tester,
        'L1_tue1152_level_ready',
        at: at,
        surface: 'Class celebration',
        note: 'LEVEL 19 READY on the rail',
      );
      await settle(tester, total: const Duration(milliseconds: 800));
      await settle(tester, total: const Duration(milliseconds: 1600));
      _note(
        'level-up up: ${find.byType(LevelUpOverlay).evaluate().isNotEmpty}',
      );
      await sheet.shot(
        tester,
        'L2_tue1153_you_did_it',
        at: at,
        surface: 'LevelUpOverlay',
        note: 'the real level-up, with the classes line',
      );
    },
  );

  roomRenderTest(
    'N: no timetable, a weekday',
    skip: !_renders || !_wants('none'),
    (tester) async {
      final at = _at(6, 11, 52);
      final account = mikaAccount(renderAt: at);
      await bootRoom(tester, account);
      await sheet.shot(
        tester,
        'N1_tue1152_no_timetable',
        at: at,
        surface: 'Quests',
        note: 'the board as today, one Add your classes row under the hero',
      );
    },
  );

  roomRenderTest('R: Reduce Motion', skip: !_renders || !_wants('reduce'), (
    tester,
  ) async {
    final at = _at(6, 11, 52);
    final account = mikaAccount(renderAt: _at(5, 21, 0), reduceMotion: true);
    _keepWeekBefore(account.state, 6);
    Clock.freeze(at);
    await bootRoom(tester, account, schedule: _schedule);
    await _press(tester, _there);
    await tester.pump(const Duration(milliseconds: 300));
    await sheet.shot(
      tester,
      'R1_tue1152_reduce_motion_300ms',
      at: at,
      surface: 'Class celebration',
      note: 'everything already landed: no travel, no slam',
    );
  });

  roomRenderTest('T: text at 130%', skip: !_renders || !_wants('text'), (
    tester,
  ) async {
    final at = _at(6, 11, 52);
    final account = mikaAccount(renderAt: _at(5, 21, 0));
    _keepWeekBefore(account.state, 6);
    account.state.textScale = 1.3;
    // The app applies the saved size at launch (main.dart); the harness
    // mounts LifeRpgApp directly, so set the same notifier here.
    appTextScale.value = 1.3;
    addTearDown(() => appTextScale.value = 1.0);
    Clock.freeze(at);
    await bootRoom(tester, account, schedule: _schedule);
    await sheet.shot(
      tester,
      'T1_tue1152_text_130',
      at: at,
      surface: 'Quests, class day',
      note: 'in-app text size 130%',
    );
    await _press(tester, _there);
    await settle(tester, total: const Duration(milliseconds: 1900));
    await sheet.shot(
      tester,
      'T2_tue1152_text_130_celebration',
      at: at,
      surface: 'Class celebration',
      note: '',
    );
  });

  roomRenderTest(
    'K: a two-digit count in the diamond',
    skip: !_renders || !_wants('count'),
    (tester) async {
      final at = _at(6, 11, 52);
      var account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepWeekBefore(account.state, 6);
      account = _withCourseCounts(account, {'14:332:331': 23});
      _note('inferred: 23 earlier Computer Architecture lectures (late term)');
      Clock.freeze(at);
      await bootRoom(tester, account, schedule: _schedule);
      await _press(tester, _there);
      await settle(tester, total: const Duration(milliseconds: 1900));
      await sheet.shot(
        tester,
        'K1_tue1152_your_24th_lecture',
        at: at,
        surface: 'Class celebration',
        note: 'YOUR 24TH LECTURE: the numeral inside the diamond',
      );
    },
  );

  roomRenderTest(
    'K2: a two-digit count on the day tier',
    skip: !_renders || !_wants('count'),
    (tester) async {
      var account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepWeekBefore(account.state, 6);
      _keepAt(account.state, _at(6, 11, 53), only: {'14:332:331'});
      account = _withCourseCounts(account, {'01:198:206': 23});
      _note('inferred: 23 earlier Discrete Structures II lectures');
      final at = _at(6, 15, 35);
      Clock.freeze(at);
      await bootRoom(tester, account, schedule: _schedule);
      await _press(tester, _there);
      await settle(tester, total: const Duration(milliseconds: 2400));
      await sheet.shot(
        tester,
        'K2_tue1535_day_tier_24th',
        at: at,
        surface: 'Class celebration, day tier',
        note: 'TUESDAY, DONE. with a two-digit count',
      );
    },
  );

  roomRenderTest(
    'K3: a two-digit count at 130% text',
    skip: !_renders || !_wants('count'),
    (tester) async {
      final at = _at(6, 11, 52);
      var account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepWeekBefore(account.state, 6);
      account = _withCourseCounts(account, {'14:332:331': 23});
      account.state.textScale = 1.3;
      appTextScale.value = 1.3;
      addTearDown(() => appTextScale.value = 1.0);
      Clock.freeze(at);
      await bootRoom(tester, account, schedule: _schedule);
      await _press(tester, _there);
      await settle(tester, total: const Duration(milliseconds: 1900));
      await sheet.shot(
        tester,
        'K3_tue1152_text_130_24th',
        at: at,
        surface: 'Class celebration',
        note: 'the numeral keeps its size inside the diamond at 130%',
      );
    },
  );

  roomRenderTest(
    'P: another room style (the archive plate)',
    skip: !_renders || !_wants('plate'),
    (tester) async {
      final at = _at(6, 11, 52);
      final account = mikaAccount(renderAt: _at(5, 21, 0));
      _keepWeekBefore(account.state, 6);
      account.state
        ..wallStyle = 'wall_archive'
        ..ownedStyles.add('wall_archive');
      _note('inferred: the archive room style, owned');
      Clock.freeze(at);
      await bootRoom(tester, account, schedule: _schedule);
      await sheet.shot(
        tester,
        'P1_tue1152_archive_between',
        at: at,
        surface: 'Quests, class day',
        note: 'a painted plate held still behind the same layout',
      );
      await _press(tester, _there);
      await tester.pump(const Duration(milliseconds: 300));
      await sheet.shot(
        tester,
        'P2_tue1152_archive_300ms',
        at: at,
        surface: 'Class celebration',
        note: 'the plate at the same scale and place as in the room',
      );
      await settle(tester, total: const Duration(milliseconds: 1600));
      await sheet.shot(
        tester,
        'P3_tue1152_archive_settled',
        at: at,
        surface: 'Class celebration',
        note: '',
      );
      await settle(tester, total: const Duration(milliseconds: 1400));
      await sheet.shot(
        tester,
        'P4_tue1153_archive_after',
        at: at,
        surface: 'Quests, class day',
        note: 'back in the room',
      );
    },
  );
}
