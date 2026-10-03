// Renders the CURRENT app (Build 49 code, unmodified lib/) on Mika's real
// Fall 2026 class days at iPhone size. Skipped unless asked for:
//
//   flutter test --dart-define=CLASS_DAY_RENDERS=true \
//     test/design_renders/class_day_current_test.dart
//
// Output: design/comparisons/2026-10-03/class-day/current/ (PNGs at
// 1179 x 2556, frames.json, schedule.txt, render-log.txt and the widget
// snapshot JSON the app publishes at Tuesday 15:35).
import 'dart:io';

import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/routines.dart';
import 'package:emberkeep/content/weekly_chronicle.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/journal_entry.dart';
import 'package:emberkeep/screens/weekly_chronicle.dart';
import 'package:emberkeep/widgets/routine_flows.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('CLASS_DAY_RENDERS');

// Monday 2026-10-05 and Tuesday 2026-10-06: ordinary class days. The
// fixture's designated-day swaps are Sep 8 and Nov 25, its recess Nov 25-27,
// and no EXDATE touches these two days ('schedule check' asserts the rows).
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

/// Taps the first hit-testable match, or records that the route was not
/// reachable (so the NOTES can say so instead of silently faking it).
Future<bool> _tap(
  WidgetTester tester,
  Finder finder,
  String what, {
  Duration settleFor = const Duration(milliseconds: 1400),
}) async {
  final target = finder.hitTestable();
  if (target.evaluate().isEmpty) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder.first);
      await settle(tester, total: const Duration(milliseconds: 600));
    }
  }
  final again = finder.hitTestable();
  if (again.evaluate().isEmpty) {
    _note(
      'NOT REACHED: $what (no hit-testable ${finder.describeMatch(Plurality.zero)})',
    );
    return false;
  }
  await tester.tap(again.first);
  await tester.pump();
  await settle(tester, total: settleFor);
  return true;
}

/// Captures one frame per scroll page of [scope] until it stops moving.
Future<int> _pages(
  WidgetTester tester,
  FrameSheet sheet,
  String prefix, {
  required Finder scope,
  required DateTime at,
  required String surface,
  double step = 470,
  int maxPages = 10,
}) async {
  var page = 1;
  for (; page <= maxPages; page++) {
    final before = scrollOffsets(tester, scope);
    await tester.drag(scope.first, Offset(0, -step), warnIfMissed: false);
    await settle(tester, total: const Duration(milliseconds: 1000));
    final after = scrollOffsets(tester, scope);
    if (listEquals(before, after)) break;
    await sheet.shot(
      tester,
      '${prefix}_p$page',
      at: at,
      surface: surface,
      note: 'scrolled page $page (${after.map((v) => v.round()).join('/')} pt)',
    );
  }
  _note('$prefix: ${page - 1} scroll page(s) until the end');
  return page - 1;
}

void main() {
  final sheet = FrameSheet(classDayDir('current'));

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

  test('schedule check: Monday and Tuesday rows', () {
    final schedule = mikaSchedule();
    final monday = classRowsOn(schedule, _monday);
    final tuesday = classRowsOn(schedule, _tuesday);
    expect(monday, hasLength(3));
    expect(tuesday, hasLength(2));
    expect(monday.first, startsWith('08:30-09:50  14:332:361'));
    expect(monday.last, startsWith('17:40-19:00  14:332:345'));
    expect(tuesday.last, startsWith('14:00-15:20  01:198:206'));
    final cancelled = [
      for (final day in [_monday, _tuesday])
        ...schedule
            .occurrencesOn(CivilDate.fromDateTime(day))
            .where((o) => o.state == OccurrenceState.cancelled),
    ];
    expect(cancelled, isEmpty);
    final out = StringBuffer()
      ..writeln('Mika, Fall 2026, as imported by the app from')
      ..writeln('test/support/rutgers_fall_2026_ics_fixture.dart')
      ..writeln()
      ..writeln('Monday 2026-10-05')
      ..writeAll(monday.map((r) => '  $r\n'))
      ..writeln()
      ..writeln('Tuesday 2026-10-06')
      ..writeAll(tuesday.map((r) => '  $r\n'))
      ..writeln()
      ..writeln('Wednesday 2026-10-07')
      ..writeAll(
        classRowsOn(schedule, DateTime(2026, 10, 7)).map((r) => '  $r\n'),
      );
    File('${sheet.directory}/schedule.txt')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(out.toString());
  }, skip: !_renders);

  roomRenderTest(
    'a, e, h: Tuesday 15:35, just after the last class',
    skip: !_renders,
    (tester) async {
      final at = _on(_tuesday, 15, 35);
      final account = mikaAccount(renderAt: at);
      WidgetSnapshotTap.install();
      await bootRoom(tester, account, schedule: mikaSchedule());
      expect(Clock.now(), at);

      await sheet.shot(
        tester,
        'A1_tue1535_quests_top',
        at: at,
        surface: 'Quests, first frame',
        note: 'app opened 15 min after CS 206 ended (15:20)',
      );
      await _pages(
        tester,
        sheet,
        'A2_tue1535_quests',
        scope: questBoard,
        at: at,
        surface: 'Quests, scrolled',
      );

      final snapshot = WidgetSnapshotTap.writeLast(
        '${sheet.directory}/H_tue1535_widget_snapshot.json',
      );
      _note(
        'widget snapshot: ${WidgetSnapshotTap.writes.length} write(s); '
        'saved=${snapshot != null}',
      );

      await scrollToTop(tester, questBoard);
      await openTab(tester, RoomTab.plans);
      await precacheArt(tester, RoomArt.plans);
      await settle(tester, total: const Duration(milliseconds: 1200));
      await sheet.shot(
        tester,
        'E1_tue1535_plans_open',
        at: at,
        surface: 'Plans, as it opens (month)',
      );
      if (await _tap(tester, find.text('DAY'), 'Plans DAY mode')) {
        await sheet.shot(
          tester,
          'E2_tue1535_plans_day',
          at: at,
          surface: 'Plans, DAY view',
        );
        await _pages(
          tester,
          sheet,
          'E3_tue1535_plans_day',
          scope: find.byType(Scrollable).hitTestable(),
          at: at,
          surface: 'Plans, DAY view scrolled',
        );
      }
    },
  );

  roomRenderTest(
    'b: Monday 19:15, just after the 7 PM class',
    skip: !_renders,
    (tester) async {
      final at = _on(_monday, 19, 15);
      final account = mikaAccount(renderAt: at);
      await bootRoom(tester, account, schedule: mikaSchedule());
      await sheet.shot(
        tester,
        'B1_mon1915_quests_top',
        at: at,
        surface: 'Quests, first frame',
        note: 'three classes today, the last ended 19:00',
      );
      await _pages(
        tester,
        sheet,
        'B2_mon1915_quests',
        scope: questBoard,
        at: at,
        surface: 'Quests, scrolled',
      );
    },
  );

  roomRenderTest(
    'c, d: Monday 21:30 close the ledger, then Tuesday 08:05',
    skip: !_renders,
    (tester) async {
      final at = _on(_monday, 21, 30);
      final account = mikaAccount(renderAt: at);
      await bootRoom(tester, account, schedule: mikaSchedule());
      await sheet.shot(
        tester,
        'C0_mon2130_quests_top',
        at: at,
        surface: 'Quests, first frame',
        note: 'three classes, zero Quests',
      );

      final rail = find.byKey(const Key('close-day-rail'));
      await revealIn(tester, rail, questBoard);
      await sheet.shot(
        tester,
        'C0b_mon2130_quests_close_rail',
        at: at,
        surface: 'Quests, scrolled to CLOSE THE DAY',
      );
      if (!await _tap(tester, rail, 'close-day rail on the board')) return;
      await settle(tester, total: const Duration(milliseconds: 1800));
      await sheet.shot(
        tester,
        'C1_mon2130_ledger_recap',
        at: at,
        surface: 'Close the ledger (recap)',
        note: 'opened from the board rail CLOSE THE DAY',
      );
      final s = liveState(tester);
      _note(
        'ledger recap data: nightXp=${s.nightXp} '
        'done=${s.nightCompletionCount} gains=${s.nightStatGains}',
      );

      final night = find.byType(NightFlow);
      final reflection = find.byKey(
        const Key('night-reflection-sheet'),
        skipOffstage: false,
      );
      if (await _tap(
        tester,
        find.descendant(of: night, matching: find.text('reflect · optional')),
        'reflect · optional',
      )) {
        // The sheet is a root-navigator route; the ledger is an OverlayEntry
        // the board inserted above every route. Record what that does.
        _note(
          'after tapping reflect · optional: sheet in tree='
          '${reflection.evaluate().isNotEmpty} hit-testable='
          '${reflection.hitTestable().evaluate().isNotEmpty} '
          '(Not now hit-testable='
          '${find.byTooltip('Not now').hitTestable().evaluate().isNotEmpty})',
        );
        await sheet.shot(
          tester,
          'C2_mon2130_ledger_after_reflect_tap',
          at: at,
          surface: 'Ledger, 1.4 s after tapping reflect · optional',
          note: 'the reflection sheet opened underneath the ledger',
        );
      }

      if (await _tap(
        tester,
        find.descendant(of: night, matching: find.text('MARK TOMORROW')),
        'MARK TOMORROW tray',
      )) {
        await sheet.shot(
          tester,
          'C3_mon2130_mark_tomorrow_empty',
          at: at,
          surface: 'Mark tomorrow (planner)',
          note: 'nothing chosen yet',
        );
        final planner = find.byKey(const ValueKey('ledger-planner'));
        for (final title in mikaLastThree) {
          await _tap(
            tester,
            find.descendant(of: planner, matching: find.text(title)),
            'planner row $title',
            settleFor: const Duration(milliseconds: 500),
          );
        }
        await settle(tester);
        await sheet.shot(
          tester,
          'C4_mon2130_mark_tomorrow_three',
          at: at,
          surface: 'Mark tomorrow, three chosen',
          note: 'chose the same three as his last active day [inferred]',
        );
        await _tap(
          tester,
          find.descendant(of: night, matching: find.text('KEEP THESE THREE')),
          'KEEP THESE THREE',
        );
        await sheet.shot(
          tester,
          'C5_mon2130_ledger_recap_with_three',
          at: at,
          surface: 'Close the ledger, tomorrow marked',
        );
      }

      final close = find.descendant(
        of: night,
        matching: find.text('CLOSE THE DAY'),
      );
      if (close.hitTestable().evaluate().isNotEmpty) {
        await tester.tap(close.hitTestable().first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));
        await sheet.shot(
          tester,
          'C6_mon2130_closing_220ms',
          at: at,
          surface: 'CLOSE THE DAY pressed, 220 ms',
        );
        await settle(tester, total: const Duration(milliseconds: 2600));
        final surfaced = reflection.hitTestable().evaluate().isNotEmpty;
        await sheet.shot(
          tester,
          'C7_mon2130_after_close',
          at: at,
          surface: 'Right after CLOSE THE DAY',
          note: surfaced
              ? 'the reflection sheet from earlier surfaces now'
              : '',
        );
        if (surfaced) {
          await _tap(tester, find.byTooltip('Not now'), 'reflection Not now');
          await sheet.shot(
            tester,
            'C7b_mon2130_closed_board',
            at: at,
            surface: 'Quests after closing (day kept)',
            note: 'after dismissing the late reflection sheet',
          );
        }
        await scrollToTop(tester, questBoard);
        await sheet.shot(
          tester,
          'C8_mon2130_closed_board_top',
          at: at,
          surface: 'Quests after closing, scrolled to the top',
        );
        _note(
          'after close: nightDoneDay=${s.nightDoneDay} '
          'morningArmed=${s.morningArmed} dayRestingNow=${s.dayRestingNow}',
        );
      } else {
        _note('NOT REACHED: CLOSE THE DAY in the ledger');
        return;
      }

      // ---- d (closed): Tuesday 08:05, the same phone, app reopened ----
      final morning = _on(_tuesday, 8, 5);
      freezeAt(morning);
      await scrollToTop(tester, questBoard);
      await reopenApp(tester);
      await settle(tester, total: const Duration(milliseconds: 2400));
      final flow = find.byType(MorningFlow);
      _note(
        'Tue 08:05 after a closed night: MorningFlow shown=${flow.evaluate().isNotEmpty}',
      );
      await sheet.shot(
        tester,
        'D2_tue0805_morning_after_closed_night',
        at: morning,
        surface: 'Open the day (auto-shown)',
        note: 'Monday night was closed at 21:30',
      );
      if (flow.evaluate().isNotEmpty) {
        await _tap(
          tester,
          find.descendant(of: flow, matching: find.text('OPEN THE DAY')),
          'OPEN THE DAY',
          settleFor: const Duration(milliseconds: 2600),
        );
        await sheet.shot(
          tester,
          'D3_tue0805_board_after_morning',
          at: morning,
          surface: 'Quests after Open the day',
        );
      }
    },
  );

  roomRenderTest('d: Tuesday 08:05, Monday night not closed', skip: !_renders, (
    tester,
  ) async {
    final at = _on(_tuesday, 8, 5);
    final account = mikaAccount(renderAt: at);
    await bootRoom(tester, account, schedule: mikaSchedule());
    _note(
      'Tue 08:05 unclosed: MorningFlow shown='
      '${find.byType(MorningFlow).evaluate().isNotEmpty} '
      'morningAvailable=${liveState(tester).morningAvailable}',
    );
    await sheet.shot(
      tester,
      'D1_tue0805_open_unclosed_night',
      at: at,
      surface: 'Quests, first frame',
      note: 'first class 10:20; Monday not closed',
    );
  });

  roomRenderTest(
    'f: Tuesday 21:10, the Journal on a class day',
    skip: !_renders,
    (tester) async {
      final at = _on(_tuesday, 21, 10);
      final account = mikaAccount(renderAt: at);
      await bootRoom(tester, account, schedule: mikaSchedule());
      final live = liveState(tester);
      final trace = live.todayJournalTrace(liveQuests(tester));
      _note(
        'Tue journal trace: day=${trace.day} level=${trace.level} '
        'totalXp=${trace.totalXp} todayXp=${trace.todayXp} '
        'quests=${trace.questTitles} hasDayEvidence=${trace.hasDayEvidence}',
      );
      await openTab(tester, RoomTab.journal);
      await precacheArt(tester, RoomArt.journal);
      await settle(tester, total: const Duration(milliseconds: 1000));
      await sheet.shot(
        tester,
        'F1_tue2110_journal_tab',
        at: at,
        surface: 'Journal tab',
      );

      if (await _tap(
        tester,
        findLabel('Write for today'),
        'Write for today',
        settleFor: const Duration(milliseconds: 2400),
      )) {
        final editor = find.byType(JournalEntryScreen);
        _note('JournalEntryScreen open=${editor.evaluate().isNotEmpty}');
        await sheet.shot(
          tester,
          'F2_tue2110_journal_new_page',
          at: at,
          surface: 'Journal, new page for today',
          note: 'nothing typed; day trace attached',
        );
        // The iPhone keyboard (about 336 pt with the suggestion bar) would
        // be up while writing [approximation: the inset is simulated and the
        // keyboard itself is not drawn].
        tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
        await settle(tester, total: const Duration(milliseconds: 900));
        await sheet.shot(
          tester,
          'F3_tue2110_journal_new_page_keyboard',
          at: at,
          surface: 'Journal, new page, keyboard space',
          note: 'bottom 336 pt is where the keyboard sits (not drawn)',
        );
        tester.view.resetViewInsets();
        await settle(tester, total: const Duration(milliseconds: 600));
        final navigator = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        navigator.popUntil((route) => route.isFirst);
        await settle(tester, total: const Duration(milliseconds: 1400));
      }

      expect(isWindDownTime(at), isTrue);
      expect(live.lastActiveDay, Days.key(at));
    },
  );

  roomRenderTest(
    'g: Sunday Oct 4 21:10, the weekly chronicle of a class week',
    skip: !_renders,
    (tester) async {
      // WeeklyChronicleScreen reads DateTime.now(), not Clock (content/
      // weekly_chronicle.dart weeklyChronicleFor without `now`). Render on a
      // Clock day in the same real week as the run so both name the same
      // "last week": Sep 21-27, five class days and a weekend.
      final at = DateTime(2026, 10, 4, 21, 10);
      final account = mikaAccount(renderAt: at);
      await bootRoom(tester, account, schedule: mikaSchedule());
      final live = liveState(tester);
      final shown = weeklyChronicleFor(live);
      final byClock = weeklyChronicleFor(live, now: Clock.now());
      final agree = shown.rangeLabel == byClock.rangeLabel;
      _note(
        'chronicle week on screen (wall clock): '
        '${Days.key(shown.start)} to ${Days.key(shown.end)} '
        'counts=${shown.counts} total=${shown.total} delta=${shown.delta}; '
        'by Clock: ${Days.key(byClock.start)}; '
        '${agree ? 'they agree' : 'MISMATCH, the render shows the wall-clock week'}',
      );
      final classDays = [
        for (var i = 0; i < 7; i++)
          classRowsOn(
            mikaSchedule(),
            shown.start.add(Duration(days: i)),
          ).length,
      ];
      _note('classes per day that week (Mon..Sun): $classDays');
      await openTab(tester, RoomTab.journal);
      await precacheArt(tester, RoomArt.journal);
      if (await _tap(
        tester,
        find.text('CHRONICLE'),
        'CHRONICLE lens',
        settleFor: const Duration(milliseconds: 2000),
      )) {
        _note(
          'WeeklyChronicleScreen open='
          '${find.byType(WeeklyChronicleScreen).evaluate().isNotEmpty}',
        );
        await sheet.shot(
          tester,
          'G1_sun2110_weekly_chronicle',
          at: at,
          surface: 'Weekly chronicle (Journal, CHRONICLE)',
          note:
              'week ${Days.key(shown.start)} to ${Days.key(shown.end)}: '
              'classes $classDays, Quests ${shown.counts}',
        );
        await _pages(
          tester,
          sheet,
          'G2_sun2110_weekly_chronicle',
          scope: find.byType(Scrollable).hitTestable(),
          at: at,
          surface: 'Weekly chronicle, scrolled',
          maxPages: 3,
        );
      }
    },
  );
}
