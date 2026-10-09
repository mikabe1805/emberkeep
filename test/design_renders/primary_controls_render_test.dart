// Renders the primary-control RENDER SET through the real app (LifeRpgApp on
// Mika's Fall 2026 timetable) at iPhone size, so a primary-control direction
// can be judged on every screen that carries one. Skipped unless asked for:
//
//   flutter test --dart-define=CLASS_DAY_RENDERS=true \
//     --dart-define=PC_OUT=<absolute folder> \
//     test/design_renders/primary_controls_render_test.dart
//
// Frames (1179 x 2556):
//   F1 class day between classes, I WAS THERE (Tue 11:52)
//   F2 the press, about 60 ms after contact
//   F3 the ordinary Quest board on a non-class day, MARK COMPLETE (Sat)
//   F4 the same card just completed (the QUEST COMPLETE done state)
//   F5 the night ledger with CLOSE THE DAY
//   F6 Add your classes, the review and its primary (Plans)
//   F7 the Goals page primary (GoalPrimaryButton)
//   C  the control alone in every state (the 1:1 crop sheet's clean row)
//   T* light input pairs (tilt through the shell's own light notifier, and a
//      scroll of the board), A* text at 130%, R* Reduce Motion.
import 'dart:io';

import 'package:emberkeep/a11y.dart';
import 'package:emberkeep/academic_calendar/import/calendar_link.dart';
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/screens/calendar.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/widgets/class_day/class_day_room.dart';
import 'package:emberkeep/widgets/lamplight.dart';
import 'package:emberkeep/widgets/routine_flows.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/calendar_export_samples.dart';
import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('CLASS_DAY_RENDERS');
const _outOverride = String.fromEnvironment('PC_OUT');
const _only = String.fromEnvironment('PC_ONLY');
bool _wants(String group) =>
    _only.isEmpty || _only.split(',').map((s) => s.trim()).contains(group);

/// Extra art a direction may add (its own material texture).
const _extraArt = String.fromEnvironment('PC_EXTRA_ART');
List<String> get _art => [
  ...RoomArt.everyday,
  if (_extraArt.isNotEmpty) ..._extraArt.split(','),
];

DateTime _at(int day, int hour, int minute) =>
    DateTime(2026, 10, day, hour, minute);

final _log = <String>[];
void _note(String line) {
  _log.add(line);
  // ignore: avoid_print
  print('NOTE $line');
}

final _schedule = mikaSchedule();

void _keepAt(GameState state, DateTime at, {Set<String>? only}) {
  Clock.freeze(at);
  final day = projectClassDay(_schedule, Clock.now());
  for (final entry in day.classes) {
    if (only != null && !only.contains(entry.courseCode)) continue;
    state.keepClass(entry.facts, dayClassKeys: day.dayClassKeys);
  }
}

void _keepWeekBefore(GameState state, int day) {
  for (var d = 5; d < day; d++) {
    _keepAt(state, _at(d, 21, 0));
  }
}

final Finder _there = find.byKey(const Key('class-there-button'));
final Finder _questAction = find.byKey(const ValueKey('quest-primary-action'));

/// The shell's light notifier, as the Quests page receives it. Setting it is
/// exactly what the accelerometer path does after calibration.
ValueNotifier<Offset>? _shellLight(WidgetTester tester) {
  final page = find.byType(QuestsPage);
  if (page.evaluate().isEmpty) return null;
  final light = tester.widget<QuestsPage>(page.first).lightDirection;
  return light is ValueNotifier<Offset> ? light : null;
}

/// Boots the real app on a non-class Saturday.
Future<void> _bootSaturday(
  WidgetTester tester, {
  bool reduceMotion = false,
  double textScale = 1,
}) async {
  final at = _at(10, 10, 40);
  final account = mikaAccount(
    renderAt: _at(9, 21, 0),
    reduceMotion: reduceMotion,
  );
  _keepWeekBefore(account.state, 10);
  if (textScale != 1) {
    account.state.textScale = textScale;
    appTextScale.value = textScale;
    addTearDown(() => appTextScale.value = 1.0);
  }
  Clock.freeze(at);
  _note('Saturday classes: ${classRowsOn(_schedule, at)}');
  await bootRoom(tester, account, schedule: _schedule, precache: _art);
  await showQuestBoard(tester);
  await settle(tester, total: const Duration(milliseconds: 900));
}

Future<void> _bootTuesday(
  WidgetTester tester, {
  bool reduceMotion = false,
  double textScale = 1,
}) async {
  final at = _at(6, 11, 52);
  final account = mikaAccount(
    renderAt: _at(5, 21, 0),
    reduceMotion: reduceMotion,
  );
  _keepWeekBefore(account.state, 6);
  if (textScale != 1) {
    account.state.textScale = textScale;
    appTextScale.value = textScale;
    addTearDown(() => appTextScale.value = 1.0);
  }
  Clock.freeze(at);
  await bootRoom(tester, account, schedule: _schedule, precache: _art);
}

/// Writes the widget's global rect in logical pixels to the log, so crops can
/// be cut at 1:1 from the 3x frame.
void _rect(WidgetTester tester, String name, Finder finder) {
  final hit = finder.evaluate();
  if (hit.isEmpty) {
    _note('RECT $name missing');
    return;
  }
  final r = tester.getRect(finder.first);
  _note(
    'RECT $name ${r.left.toStringAsFixed(1)} ${r.top.toStringAsFixed(1)} '
    '${r.width.toStringAsFixed(1)} ${r.height.toStringAsFixed(1)}',
  );
}

final class _FakeFetcher implements CalendarLinkFetcher {
  _FakeFetcher(this.body);
  final String body;
  @override
  Future<String> fetch(CalendarLink link) async => checkCalendarText(body);
}

Finder _key(String value) => find.byKey(ValueKey(value));

Future<void> _tapKey(WidgetTester tester, Finder finder) async {
  if (finder.hitTestable().evaluate().isEmpty) {
    await Scrollable.ensureVisible(
      tester.element(finder.first),
      alignment: 0.5,
    );
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 500));
  }
  final target = finder.hitTestable().evaluate().isEmpty
      ? finder.first
      : finder.hitTestable().first;
  await tester.tap(target, warnIfMissed: false);
  await tester.pump();
  await settle(tester, total: const Duration(milliseconds: 900));
}

void main() {
  final out = _outOverride.isNotEmpty
      ? _outOverride
      : '${Directory.current.path.replaceAll(r'\', '/')}/design/comparisons/2026-10-04/primary-controls/out';
  final sheet = FrameSheet(out);

  setUpAll(() async {
    await setUpRoomRenders();
    // The lamp's paper, decoded in the real-async zone like the room art.
    await LampVellum.load();
  });
  const zoneChannel = MethodChannel('flutter_timezone');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(zoneChannel, (call) async {
          return call.method == 'getLocalTimezone' ? 'America/New_York' : null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(zoneChannel, null);
  });
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
    'F1/F2: Tuesday between classes and the press',
    skip: !_renders || !_wants('tue'),
    (tester) async {
      final at = _at(6, 11, 52);
      await _bootTuesday(tester);
      _rect(tester, 'F1 there', _there);
      await sheet.shot(
        tester,
        'F1_tue1152_i_was_there',
        at: at,
        surface: 'Quests, class day',
        note: 'between classes: Computer Architecture ended 11:40',
      );

      // Tilt pair, through the shell's light notifier.
      final light = _shellLight(tester);
      _note('shell light notifier: ${light != null}');
      if (light != null) {
        light.value = const Offset(-0.85, -0.2);
        await tester.pump(const Duration(milliseconds: 40));
        await sheet.shot(
          tester,
          'T1a_tue1152_tilt_left',
          at: at,
          surface: 'Quests, class day',
          note: 'phone tilted left (light -0.85, -0.2)',
        );
        light.value = const Offset(0.85, 0.2);
        await tester.pump(const Duration(milliseconds: 40));
        await sheet.shot(
          tester,
          'T1b_tue1152_tilt_right',
          at: at,
          surface: 'Quests, class day',
          note: 'phone tilted right (light 0.85, 0.2)',
        );
        light.value = Offset.zero;
        await tester.pump(const Duration(milliseconds: 40));
      }

      final gesture = await tester.startGesture(
        tester.getCenter(_there.hitTestable().first),
      );
      await tester.pump(const Duration(milliseconds: 60));
      _rect(tester, 'F2 there', _there);
      await sheet.shot(
        tester,
        'F2_tue1152_press_60ms',
        at: at,
        surface: 'Quests, class day',
        note: 'finger down, 60 ms',
      );
      await gesture.up();
      await tester.pump();
      await settle(tester, total: const Duration(milliseconds: 3600));
    },
  );

  roomRenderTest(
    'F3/F4: Saturday board, MARK COMPLETE and its done state',
    skip: !_renders || !_wants('sat'),
    (tester) async {
      final at = _at(10, 10, 40);
      await _bootSaturday(tester);
      await scrollToTop(tester, questBoard);
      await settle(tester, total: const Duration(milliseconds: 600));
      _rect(tester, 'F3 action', _questAction);
      await sheet.shot(
        tester,
        'F3_sat1040_mark_complete',
        at: at,
        surface: 'Quests, Saturday',
        note: 'no classes: the ordinary board, featured Quest',
      );

      // Scroll pair: the board moved a little, light follows the scroll.
      await tester.drag(questBoard, const Offset(0, -140));
      await settle(tester, total: const Duration(milliseconds: 900));
      _rect(tester, 'S1 action', _questAction);
      await sheet.shot(
        tester,
        'S1_sat1040_scrolled_140',
        at: at,
        surface: 'Quests, Saturday, scrolled',
        note: 'the board dragged up 140 pt',
      );
      await scrollToTop(tester, questBoard);
      await settle(tester, total: const Duration(milliseconds: 900));

      final light = _shellLight(tester);
      if (light != null) {
        light.value = const Offset(-0.85, -0.2);
        await tester.pump(const Duration(milliseconds: 40));
        await sheet.shot(
          tester,
          'T2a_sat1040_tilt_left',
          at: at,
          surface: 'Quests, Saturday',
          note: 'phone tilted left',
        );
        light.value = const Offset(0.85, 0.2);
        await tester.pump(const Duration(milliseconds: 40));
        await sheet.shot(
          tester,
          'T2b_sat1040_tilt_right',
          at: at,
          surface: 'Quests, Saturday',
          note: 'phone tilted right',
        );
        light.value = Offset.zero;
        await tester.pump(const Duration(milliseconds: 40));
      }

      final gesture = await tester.startGesture(
        tester.getCenter(_questAction.hitTestable().first),
      );
      await tester.pump(const Duration(milliseconds: 60));
      await sheet.shot(
        tester,
        'F3p_sat1040_press_60ms',
        at: at,
        surface: 'Quests, Saturday',
        note: 'MARK COMPLETE, finger down 60 ms',
      );
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      _rect(tester, 'F4a plate', _key('quest-resolved-plate'));
      await sheet.shot(
        tester,
        'F4a_sat1040_done_120ms',
        at: at,
        surface: 'Quests, Saturday',
        note: 'released, 120 ms: the lamp turning low',
      );
      await tester.pump(const Duration(milliseconds: 160));
      _rect(tester, 'F4 plate', _key('quest-resolved-plate'));
      await sheet.shot(
        tester,
        'F4_sat1040_quest_complete_280ms',
        at: at,
        surface: 'Quests, Saturday',
        note: 'released, 280 ms: QUEST COMPLETE',
      );
      await tester.pump(const Duration(milliseconds: 160));
      _rect(tester, 'F4c plate', _key('quest-resolved-plate'));
      await sheet.shot(
        tester,
        'F4c_sat1040_quest_complete_440ms',
        at: at,
        surface: 'Quests, Saturday',
        note: 'released, 440 ms: the lamp low, before the card banks',
      );
      await settle(tester, total: const Duration(milliseconds: 2400));
      await sheet.shot(
        tester,
        'F4b_sat1040_after',
        at: at,
        surface: 'Quests, Saturday',
        note: 'settled: the next Quest featured',
      );
    },
  );

  roomRenderTest(
    'F5: the night ledger, CLOSE THE DAY',
    skip: !_renders || !_wants('night'),
    (tester) async {
      final at = _at(5, 21, 30);
      final account = mikaAccount(renderAt: at);
      await bootRoom(tester, account, schedule: _schedule, precache: _art);
      final state = liveState(tester);
      final day = projectClassDay(_schedule, Clock.now());
      for (final entry in day.classes) {
        state.keepClass(entry.facts, dayClassKeys: day.dayClassKeys);
      }
      await settle(tester);
      await showQuestBoard(tester);
      final rail = find.byKey(const Key('close-day-rail'));
      await revealIn(tester, rail, questBoard);
      if (rail.hitTestable().evaluate().isEmpty) {
        _note('NOT REACHED: close-day rail');
        return;
      }
      await tester.tap(rail.hitTestable().first);
      await tester.pump();
      await precacheArt(tester, RoomArt.routine);
      await settle(tester, total: const Duration(milliseconds: 2400));
      _note('night flow: ${find.byType(NightFlow).evaluate().isNotEmpty}');
      final scroll = find.byKey(const ValueKey('recap'));
      if (scroll.evaluate().isNotEmpty) {
        await tester.drag(scroll, const Offset(0, -400));
        await settle(tester, total: const Duration(milliseconds: 900));
      }
      _rect(tester, 'F5 clasp', find.text('CLOSE THE DAY'));
      await sheet.shot(
        tester,
        'F5_mon2130_close_the_day',
        at: at,
        surface: 'Close the ledger, scrolled to the clasp',
        note: 'three classes kept',
      );
      final close = find.text('CLOSE THE DAY');
      if (close.hitTestable().evaluate().isNotEmpty) {
        final g = await tester.startGesture(
          tester.getCenter(close.hitTestable().first),
        );
        await tester.pump(const Duration(milliseconds: 60));
        await sheet.shot(
          tester,
          'F5p_mon2130_close_press_60ms',
          at: at,
          surface: 'Close the ledger',
          note: 'finger down 60 ms',
        );
        // Slide off so the day is not actually closed.
        await g.moveBy(const Offset(0, 120));
        await g.up();
        await settle(tester, total: const Duration(milliseconds: 600));
      }

      // A primary that is not ready yet: Extra Credit before any words.
      final entry = find.byKey(const Key('extra-credit-entry'));
      if (entry.hitTestable().evaluate().isEmpty) {
        _note('NOT REACHED: extra-credit entry');
        return;
      }
      await tester.tap(entry.hitTestable().first);
      await tester.pump();
      await settle(tester, total: const Duration(milliseconds: 1200));
      final save = find.byKey(const Key('extra-credit-save'));
      _rect(tester, 'X1 save', save);
      await sheet.shot(
        tester,
        'X1_mon2130_extra_credit_not_ready',
        at: at,
        surface: 'Extra Credit, empty: its primary unlit',
      );
      await tester.enterText(
        find.byKey(const Key('extra-credit-field')),
        'Stayed after for the recitation questions',
      );
      await tester.pump();
      await settle(tester, total: const Duration(milliseconds: 600));
      _rect(tester, 'X2 save', save);
      await sheet.shot(
        tester,
        'X2_mon2130_extra_credit_ready',
        at: at,
        surface: 'Extra Credit, written: its primary lit',
      );
    },
  );

  roomRenderTest(
    'F6: Add your classes, review and its primary',
    skip: !_renders || !_wants('import'),
    (tester) async {
      final at = DateTime(2026, 10, 4, 19, 30);
      final account = mikaAccount(renderAt: at);
      await bootRoom(tester, account, precache: _art);
      await openTab(tester, RoomTab.plans);
      await precacheArt(tester, RoomArt.plans);
      await settle(tester, total: const Duration(milliseconds: 1200));
      final plansScroll = find
          .descendant(
            of: find.byType(CalendarPage),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        _key('add-classes-doorway'),
        260,
        scrollable: plansScroll,
      );
      await settle(tester, total: const Duration(milliseconds: 600));
      await _tapKey(tester, _key('add-classes-doorway'));
      await _tapKey(tester, _key('add-classes-link'));
      await tester.enterText(
        _key('add-classes-link-field'),
        'https://calendar.google.com/calendar/ical/jordan.lee.uiuc%40gmail.com/private-8f2c41d9a7e0b3c5/basic.ics',
      );
      await tester.pump();
      await settle(tester, total: const Duration(milliseconds: 500));
      debugCalendarLinkFetcherOverride = _FakeFetcher(
        googleCalendarStudentExport(),
      );
      try {
        await _tapKey(tester, _key('add-classes-read-link'));
      } finally {
        debugCalendarLinkFetcherOverride = null;
      }
      _rect(tester, 'F6 primary', find.textContaining('COURSES'));
      await sheet.shot(
        tester,
        'F6_sun1930_add_classes_review',
        at: at,
        surface: 'Add your classes, Pick your classes',
        note: 'Google Calendar export, 4 courses checked',
      );
    },
  );

  roomRenderTest(
    'F7: the Goals page primary',
    skip: !_renders || !_wants('goals'),
    (tester) async {
      final at = _at(10, 10, 40);
      final account = mikaAccount(renderAt: at);
      await bootRoom(tester, account, precache: _art);
      await precacheArt(tester, RoomArt.goals);
      await openTab(tester, RoomTab.goals);
      await precacheArt(tester, RoomArt.goals);
      await settle(tester, total: const Duration(milliseconds: 1800));
      _rect(
        tester,
        'F7 primary',
        find.byKey(const Key('goals-return-primary-action')),
      );
      await sheet.shot(
        tester,
        'F7_sat1040_goals',
        at: at,
        surface: 'Goals',
        note: 'the Goals page as it opens',
      );
      final primary = find.byKey(const Key('goals-return-primary-action'));
      if (primary.evaluate().isNotEmpty &&
          primary.hitTestable().evaluate().isEmpty) {
        await tester.ensureVisible(primary.first);
        await settle(tester, total: const Duration(milliseconds: 900));
        _rect(tester, 'F7b primary', primary);
        await sheet.shot(
          tester,
          'F7b_sat1040_goals_primary',
          at: at,
          surface: 'Goals, scrolled to its primary',
        );
      }
    },
  );

  roomRenderTest(
    'C: the control in every state, alone on the class card ground',
    skip: !_renders || !_wants('states'),
    (tester) async {
      final tiltLeft = ValueNotifier<Offset>(const Offset(-0.85, -0.2));
      final tiltRight = ValueNotifier<Offset>(const Offset(0.85, 0.2));
      final forced = ValueNotifier<Offset>(const Offset(0.85, 0.2));
      addTearDown(() {
        tiltLeft.dispose();
        tiltRight.dispose();
        forced.dispose();
      });
      Widget lamp(
        String key, {
        bool enabled = true,
        bool kept = false,
        ValueNotifier<Offset>? light,
        bool reduceMotion = false,
      }) => KeyedSubtree(
        key: ValueKey('state-$key'),
        child: ClassThereButton(
          label: 'I WAS THERE',
          enabled: enabled,
          kept: kept,
          light: light,
          reduceMotion: reduceMotion,
          onTap: () {},
          semanticLabel: key,
        ),
      );
      Widget gap() => const SizedBox(height: 26);
      await pumpPhoneStudy(
        tester,
        Scaffold(
          backgroundColor: const Color(0xFF1F1611),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(34, 70, 34, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                lamp('parked'),
                gap(),
                lamp('pressed'),
                gap(),
                lamp('disabled', enabled: false),
                gap(),
                lamp('done', kept: true),
                gap(),
                Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(1.3)),
                    child: lamp('text130'),
                  ),
                ),
                gap(),
                Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(disableAnimations: true),
                    child: lamp('reduce', light: forced),
                  ),
                ),
                gap(),
                lamp('tiltLeft', light: tiltLeft),
                gap(),
                lamp('tiltRight', light: tiltRight),
              ],
            ),
          ),
        ),
        settleFor: const Duration(milliseconds: 1200),
      );
      for (final k in const [
        'parked',
        'pressed',
        'disabled',
        'done',
        'text130',
        'reduce',
        'tiltLeft',
        'tiltRight',
      ]) {
        _rect(tester, 'C $k', _key('state-$k'));
      }
      final g = await tester.startGesture(
        tester.getCenter(_key('state-pressed')),
      );
      await tester.pump(const Duration(milliseconds: 60));
      await sheet.shot(
        tester,
        'C1_states_alone',
        at: _at(6, 11, 52),
        surface: 'ClassThereButton alone, every state',
        note:
            'parked, pressed 60 ms, disabled, done (settled low), text 130%, '
            'Reduce Motion with light forced, tilt left, tilt right',
      );
      await g.up();
      await settle(tester, total: const Duration(milliseconds: 600));
    },
  );

  roomRenderTest(
    'K: the warm accent turned off (yellow check, step 4)',
    skip: !_renders || !_wants('off'),
    (tester) async {
      LampShade.debugForceLevel = LampLevel.off;
      addTearDown(() => LampShade.debugForceLevel = null);
      await _bootTuesday(tester);
      await sheet.shot(
        tester,
        'K1_tue1152_accent_off',
        at: _at(6, 11, 52),
        surface: 'Quests, class day, every lamp unlit',
        note: 'test seam: LampShade.debugForceLevel = off',
      );
    },
  );

  roomRenderTest(
    'K3: Saturday with the warm accent turned off',
    skip: !_renders || !_wants('off'),
    (tester) async {
      LampShade.debugForceLevel = LampLevel.off;
      addTearDown(() => LampShade.debugForceLevel = null);
      await _bootSaturday(tester);
      await scrollToTop(tester, questBoard);
      await settle(tester, total: const Duration(milliseconds: 600));
      await sheet.shot(
        tester,
        'K3_sat1040_accent_off',
        at: _at(10, 10, 40),
        surface: 'Quests, Saturday, every lamp unlit',
        note: 'test seam: LampShade.debugForceLevel = off',
      );
    },
  );

  roomRenderTest('A: text at 130%', skip: !_renders || !_wants('text'), (
    tester,
  ) async {
    await _bootTuesday(tester, textScale: 1.3);
    _rect(tester, 'A1 there', _there);
    await sheet.shot(
      tester,
      'A1_tue1152_text_130',
      at: _at(6, 11, 52),
      surface: 'Quests, class day, text 130%',
    );
  });

  roomRenderTest('A2: Saturday at 130%', skip: !_renders || !_wants('text'), (
    tester,
  ) async {
    await _bootSaturday(tester, textScale: 1.3);
    await scrollToTop(tester, questBoard);
    await settle(tester, total: const Duration(milliseconds: 600));
    _rect(tester, 'A2 action', _questAction);
    await sheet.shot(
      tester,
      'A2_sat1040_text_130',
      at: _at(10, 10, 40),
      surface: 'Quests, Saturday, text 130%',
    );
  });

  roomRenderTest('R: Reduce Motion', skip: !_renders || !_wants('reduce'), (
    tester,
  ) async {
    await _bootTuesday(tester, reduceMotion: true);
    final light = _shellLight(tester);
    // The shell's controller ignores sensor input under Reduce Motion; a
    // stray value here proves the control parks anyway.
    light?.value = const Offset(0.85, 0.2);
    await tester.pump(const Duration(milliseconds: 40));
    _rect(tester, 'R1 there', _there);
    await sheet.shot(
      tester,
      'R1_tue1152_reduce_motion',
      at: _at(6, 11, 52),
      surface: 'Quests, class day, Reduce Motion',
      note: 'light value forced to (0.85, 0.2): the control stays parked',
    );
    final gesture = await tester.startGesture(
      tester.getCenter(_there.hitTestable().first),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await sheet.shot(
      tester,
      'R2_tue1152_reduce_motion_press',
      at: _at(6, 11, 52),
      surface: 'Quests, class day, Reduce Motion',
      note: 'finger down 60 ms under Reduce Motion',
    );
    await gesture.up();
    await settle(tester, total: const Duration(milliseconds: 3600));
  });
}
