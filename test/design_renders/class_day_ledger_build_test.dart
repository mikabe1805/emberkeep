// Renders the BUILD's night ledger on Mika's real Monday and Tuesday at
// iPhone size, with his classes kept. Skipped unless asked for:
//
//   flutter test --dart-define=CLASS_DAY_RENDERS=true \
//     test/design_renders/class_day_ledger_build_test.dart
//
// Output: design/comparisons/2026-10-03/class-day/build/ledger/ (PNGs at
// 1179 x 2556, frames.json, render-log.txt). The same account, timetable and
// clock times as current/ (C1, C2, C5, D2), so the two read side by side.
import 'dart:io';

import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/routine_flows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('CLASS_DAY_RENDERS');

final _monday = DateTime(2026, 10, 5);
final _tuesday = DateTime(2026, 10, 6);

DateTime _on(DateTime day, int hour, int minute) =>
    DateTime(day.year, day.month, day.day, hour, minute);

final _log = <String>[];
void _note(String line) {
  _log.add(line);
  // ignore: avoid_print
  print('NOTE $line');
}

/// Marks every class of the night-owned day as kept, the way the class-day
/// board will. The engine call is the real one; only the button is not built
/// yet in this phase.
void _keepToday(GameState state, {int? only}) {
  final day = projectClassDay(mikaSchedule(), Clock.now());
  final classes = only == null ? day.classes : day.classes.take(only);
  for (final entry in classes) {
    final credit = state.keepClass(entry.facts, dayClassKeys: day.dayClassKeys);
    _note(
      'kept ${entry.courseCode} ${entry.title}: '
      '${credit == null ? 'refused (${state.checkClassKeep(entry.facts)})' : '+${credit.xp} XP'}',
    );
  }
}

Future<bool> _tap(WidgetTester tester, Finder finder, String what) async {
  if (finder.hitTestable().evaluate().isEmpty && finder.evaluate().isNotEmpty) {
    await tester.ensureVisible(finder.first);
    await settle(tester, total: const Duration(milliseconds: 600));
  }
  final target = finder.hitTestable();
  if (target.evaluate().isEmpty) {
    _note('NOT REACHED: $what');
    return false;
  }
  await tester.tap(target.first);
  await tester.pump();
  await settle(tester, total: const Duration(milliseconds: 1200));
  return true;
}

Future<void> _openLedger(WidgetTester tester) async {
  final rail = find.byKey(const Key('close-day-rail'));
  await revealIn(tester, rail, questBoard);
  expect(await _tap(tester, rail, 'close-day rail'), isTrue);
  await precacheArt(tester, RoomArt.routine);
  await settle(tester, total: const Duration(milliseconds: 1800));
  expect(find.byType(NightFlow), findsOneWidget);
}

void main() {
  final sheet = FrameSheet(classDayDir('build/ledger'));

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
    'L: Monday 21:30, three classes kept, then Tuesday 08:05',
    skip: !_renders,
    failOnOverflow: true,
    (tester) async {
      final at = _on(_monday, 21, 30);
      final account = mikaAccount(renderAt: at);
      await bootRoom(tester, account, schedule: mikaSchedule());
      final state = liveState(tester);
      _keepToday(state);
      await settle(tester);

      await _openLedger(tester);
      _note(
        'Monday ledger: nightXp=${state.nightXp} '
        'kept=${state.classesKeptOn(state.activeNightDayKey).length} '
        'quests=${state.nightCompletionCount} gains=${state.nightStatGains}',
      );
      await sheet.shot(
        tester,
        'L1_mon2130_ledger_classes_kept',
        at: at,
        surface: 'Close the ledger',
        note: 'three classes kept, Tuesday\'s two head the tray',
      );

      final night = find.byType(NightFlow);
      if (await _tap(
        tester,
        find.descendant(of: night, matching: find.text('reflect · optional')),
        'reflect · optional',
      )) {
        final field = find.byKey(const Key('night-reflection-field'));
        _note(
          'reflection after tap: hit-testable='
          '${field.hitTestable().evaluate().isNotEmpty}',
        );
        await sheet.shot(
          tester,
          'L2_mon2130_reflect_above_ledger',
          at: at,
          surface: 'reflect · optional, above the folio',
          note: 'Build 49 opened this behind the ledger (current C2)',
        );
        await tester.binding.handlePopRoute();
        await settle(tester);
      }

      if (await _tap(
        tester,
        find.byKey(const Key('extra-credit-entry')),
        'Extra Credit line',
      )) {
        await sheet.shot(
          tester,
          'L3_mon2130_extra_credit_sheet',
          at: at,
          surface: 'Extra Credit, empty',
          note: 'his words as the example',
        );
        await tester.enterText(
          find.byKey(const Key('extra-credit-field')),
          'Stayed after for the recitation questions',
        );
        await tester.pump();
        await _tap(
          tester,
          find.byKey(const Key('extra-credit-save')),
          'ADD +10 XP',
        );
      }

      if (await _tap(
        tester,
        find.descendant(of: night, matching: find.text('MARK TOMORROW')),
        'MARK TOMORROW',
      )) {
        final planner = find.byKey(const ValueKey('ledger-planner'));
        for (final title in mikaLastThree) {
          await _tap(
            tester,
            find.descendant(of: planner, matching: find.text(title)),
            'planner row $title',
          );
        }
        await _tap(
          tester,
          find.descendant(of: night, matching: find.text('KEEP THESE THREE')),
          'KEEP THESE THREE',
        );
      }
      await sheet.shot(
        tester,
        'L4_mon2130_ledger_credit_and_three',
        at: at,
        surface: 'Close the ledger, Extra Credit and tomorrow\'s three',
        note: 'ribbons hang below the two-line titles (current C5)',
      );
      final scroll = find.byKey(const ValueKey('recap'));
      await tester.drag(scroll, const Offset(0, -400));
      await settle(tester);
      await sheet.shot(
        tester,
        'L4b_mon2130_ledger_scrolled',
        at: at,
        surface: 'Close the ledger, scrolled to the clasp',
      );

      if (!await _tap(
        tester,
        find.descendant(of: night, matching: find.text('CLOSE THE DAY')),
        'CLOSE THE DAY',
      )) {
        return;
      }
      await settle(tester, total: const Duration(milliseconds: 1600));
      _note('closed: nightDoneDay=${state.nightDoneDay}');

      final morning = _on(_tuesday, 8, 5);
      freezeAt(morning);
      await reopenApp(tester);
      await precacheArt(tester, RoomArt.routine);
      await settle(tester, total: const Duration(milliseconds: 1800));
      await sheet.shot(
        tester,
        'L5_tue0805_open_the_day',
        at: morning,
        surface: 'Open the day (auto-shown)',
        note: 'rows 2 and 3 keep their XP line (current D2 clipped them)',
      );
    },
  );

  roomRenderTest(
    'T: Tuesday 22:10, two classes kept and one Quest',
    skip: !_renders,
    failOnOverflow: true,
    (tester) async {
      final at = _on(_tuesday, 22, 10);
      final account = mikaAccount(renderAt: at);
      await bootRoom(tester, account, schedule: mikaSchedule());
      final state = liveState(tester);
      _keepToday(state);
      // One ordinary Quest finished in the evening, so classes and threads
      // share the page.
      state
        ..todayQuestTitles.add('Clear the kitchen counter')
        ..todayXp += 24
        ..todayStats[Stat.dis] = (state.todayStats[Stat.dis] ?? 0) + 2
        ..history[state.activeNightDayKey] =
            (state.history[state.activeNightDayKey] ?? 0) + 1;
      await settle(tester);

      await _openLedger(tester);
      _note(
        'Tuesday ledger: nightXp=${state.nightXp} '
        'kept=${state.classesKeptOn(state.activeNightDayKey).length} '
        'quests=${state.nightCompletionCount}',
      );
      await sheet.shot(
        tester,
        'T1_tue2210_ledger_classes_and_thread',
        at: at,
        surface: 'Close the ledger',
        note: 'two classes and one Quest; Wednesday\'s lab heads the tray',
      );
    },
  );

  roomRenderTest(
    'A: Monday 21:30 at 200% text',
    skip: !_renders,
    failOnOverflow: true,
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final at = _on(_monday, 21, 30);
      final account = mikaAccount(renderAt: at);
      await bootRoom(tester, account, schedule: mikaSchedule());
      final state = liveState(tester);
      _keepToday(state);
      state.addExtraCredit(
        'Stayed after for the recitation questions',
        dayKey: state.activeNightDayKey,
      );
      await settle(tester);
      await _openLedger(tester);
      await sheet.shot(
        tester,
        'A1_mon2130_ledger_text_200',
        at: at,
        surface: 'Close the ledger at 200% text',
        note: 'the book lengthens; nothing clips',
      );
      final scroll = find.byKey(const ValueKey('recap'));
      await tester.drag(scroll, const Offset(0, -520));
      await settle(tester);
      await sheet.shot(
        tester,
        'A2_mon2130_ledger_text_200_scrolled',
        at: at,
        surface: 'Close the ledger at 200% text, scrolled',
      );
    },
  );

  roomRenderTest(
    'Q: Monday 21:30, no class marked',
    skip: !_renders,
    failOnOverflow: true,
    (tester) async {
      final at = _on(_monday, 21, 30);
      final account = mikaAccount(renderAt: at);
      await bootRoom(tester, account, schedule: mikaSchedule());
      await _openLedger(tester);
      await sheet.shot(
        tester,
        'Q1_mon2130_ledger_nothing_marked',
        at: at,
        surface: 'Close the ledger',
        note: 'unmarked classes stay unmentioned; the gentle copy holds',
      );
    },
  );
}
