// What Mika found on his iPhone in build 55, through the real app (the shell,
// the HUD and the dock) at 393 x 852 and 3x (PNGs 1179 x 2556): the Quest
// board under the HUD, the way to it from the Doorway's glass card, the
// evening card at rest, and the Doorway's light at 11:37 in the morning and at
// 11:37 at night. Skipped unless asked for:
//
//   flutter test --dart-define=H56_BOARD=true \
//     test/design_renders/h56_board_render_test.dart
//
// H56_ONLY=midday,morning,night,quiet,text,saturday picks groups; H56_OUT=
// <folder> writes somewhere else (the "before" frames go to _before/). Output:
// design/comparisons/2026-10-12/h56-board/ in this checkout.
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/day_planning.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/quests.dart' show QuestsPage;
import 'package:emberkeep/tokens.dart' show Stat;
import 'package:emberkeep/widgets/class_day/doorway_art.dart';
import 'package:emberkeep/widgets/class_day/doorway_stage.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('H56_BOARD');
const _only = String.fromEnvironment('H56_ONLY');
bool _wants(String name) =>
    _only.isEmpty || _only.split(',').map((s) => s.trim()).contains(name);

const _out = String.fromEnvironment(
  'H56_OUT',
  defaultValue:
      'C:/Users/mikus/Downloads/experimentProject/app/.worktrees/house-quests/'
      'design/comparisons/2026-10-12/h56-board',
);

DateTime _at(int day, int hour, int minute) =>
    DateTime(2026, 10, day, hour, minute);

final _schedule = mikaSchedule();

List<String> get _plates => {
  for (final set in [
    HousePlateSets.me,
    HousePlateSets.goals,
    HousePlateSets.plansDay,
    HousePlateSets.plansMonth,
    HousePlateSets.journal,
  ])
    ...set.all,
}.toList();

/// Keeps the classes of [at]'s day that [keep] names and sets the rest aside,
/// on the clock at [at] (a class can be kept until its night is over).
void _settleDay(
  GameState state,
  DateTime at, {
  required bool Function(ProjectedClass entry) keep,
}) {
  Clock.freeze(at);
  final day = projectClassDay(_schedule, at);
  for (final entry in day.classes) {
    if (keep(entry)) {
      state.keepClass(entry.facts, dayClassKeys: day.dayClassKeys);
    } else {
      state.dismissClass(entry.facts);
    }
  }
}

Future<void> _boot(
  WidgetTester tester,
  DateTime at, {
  bool Function(ProjectedClass entry)? keep,
  bool music = false,
  bool chosen = false,
  bool closed = false,
}) async {
  final account = mikaAccount(renderAt: at);
  account.state.musicEnabled = music;
  if (chosen) {
    account.quests
      ..add(Quest(title: 'Review one problem', stat: Stat.foc, difficulty: 3))
      ..add(Quest(title: 'Write for today', stat: Stat.dis, difficulty: 2));
    applyDailyField(account.quests, at, const [
      'Read ten pages',
      'Review one problem',
      'Write for today',
    ]);
  }
  if (keep != null) _settleDay(account.state, at, keep: keep);
  Clock.freeze(at);
  await bootRoom(
    tester,
    account,
    schedule: _schedule,
    precache: [...RoomArt.everyday, ..._plates],
  );
  final context = tester.element(find.byType(MaterialApp).first);
  await tester.runAsync(() async {
    for (final asset in DoorwayAssets.all) {
      await precacheImage(DoorwayAssets.providerFor(asset), context);
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
  await tester.pump(const Duration(milliseconds: 200));
  if (music) {
    // The saved setting is on and the app is in the foreground, as on his
    // phone: the evening's music door shows it playing and the room steps back.
    final controller = tester
        .widget<QuestsPage>(find.byType(QuestsPage, skipOffstage: false))
        .musicController!;
    await tester.runAsync(() async {
      await controller.setEnabled(true);
      await controller.setForeground(true);
    });
  }
  if (closed) {
    // Tonight's ledger is written: the day is kept and the board rests.
    liveState(tester).closeNight();
    // Out and back, as the night ledger's own route returns to the room.
    await openTab(tester, RoomTab.me);
    await openTab(tester, RoomTab.quests);
  }
  await settle(tester, total: const Duration(milliseconds: 2800));
}

/// BOARD from the Doorway's card, whichever card it is.
Future<void> _toBoard(WidgetTester tester) async {
  final toggle = find.byKey(const Key('class-day-toggle-board')).hitTestable();
  final quest = find.byKey(const Key('quest-day-board')).hitTestable();
  await tester.tap(toggle.evaluate().isNotEmpty ? toggle.first : quest.first);
  await tester.pump();
  await settle(tester, total: const Duration(milliseconds: 1400));
}

/// Quiets the music again before the app is taken down (its fade out would
/// leave a timer behind).
Future<void> _musicOff(WidgetTester tester) async {
  final controller = tester
      .widget<QuestsPage>(find.byType(QuestsPage, skipOffstage: false))
      .musicController!;
  await tester.runAsync(() async {
    await controller.setEnabled(false);
    await controller.setForeground(false);
    await Future<void>.delayed(const Duration(milliseconds: 900));
  });
  await settle(tester, total: const Duration(milliseconds: 1200));
}

String _lights(WidgetTester tester) {
  final stages = find.byType(DoorwayStage).evaluate();
  if (stages.isEmpty) return 'no stage';
  final stage = tester.state<DoorwayStageState>(
    find.byType(DoorwayStage).first,
  );
  return '${stage.lights}';
}

bool _all(ProjectedClass entry) => true;

void main() {
  setUpAll(setUpRoomRenders);
  tearDownAll(tearDownRoomRenders);
  // The test config keeps the old board for the old tests; the room is real.
  setUp(() => QuestsPage.debugLegacyBoard = false);
  tearDown(() => QuestsPage.debugLegacyBoard = true);
  final sheet = FrameSheet(_out);
  tearDownAll(() {
    if (_renders) sheet.writeManifest();
  });

  roomRenderTest('midday on a class day', skip: !_renders, (tester) async {
    if (!_wants('midday')) return;
    final at = _at(6, 12, 30);
    await _boot(tester, at);
    await sheet.shot(
      tester,
      'M_doorway',
      at: at,
      surface: 'QUESTS',
      note: 'Tuesday 12:30, the card with a class to mark',
    );
    await _toBoard(tester);
    await sheet.shot(
      tester,
      'M_board',
      at: at,
      surface: 'QUESTS',
      note: 'BOARD at rest',
    );
    await tester.drag(
      find.byKey(const ValueKey('quest-board-scroll')),
      const Offset(0, -200),
      warnIfMissed: false,
    );
    await settle(tester, total: const Duration(milliseconds: 900));
    await sheet.shot(
      tester,
      'M_board_scrolled',
      at: at,
      surface: 'QUESTS',
      note: 'BOARD scrolled 200 pt: the work climbing under the HUD',
    );
  });

  roomRenderTest('11:37 in the morning, the last class kept', skip: !_renders, (
    tester,
  ) async {
    if (!_wants('morning')) return;
    // Wednesday: the 8:30 lab ended at 11:30; the 2:00 lecture is set aside,
    // so the lab is the day's last class and the evening card is the room's.
    final at = _at(7, 11, 37);
    await _boot(tester, at, keep: (entry) => entry.courseCode == '14:332:333');
    // ignore: avoid_print
    print('LIGHT 11:37 AM ${_lights(tester)}');
    await sheet.shot(
      tester,
      'L_doorway_1137am',
      at: at,
      surface: 'QUESTS',
      note: 'Wednesday 11:37 AM, after the last class: the evening card',
    );
    await _toBoard(tester);
    await sheet.shot(
      tester,
      'L_board_1137am',
      at: at,
      surface: 'QUESTS',
      note: 'BOARD at 11:37 AM',
    );
  });

  roomRenderTest('11:37 at night, music on', skip: !_renders, (tester) async {
    if (!_wants('night')) return;
    // His Monday: the 2:00 lecture set aside, the other two attended.
    final at = _at(12, 23, 37);
    await _boot(
      tester,
      at,
      music: true,
      keep: (entry) => entry.localStartMinute != 14 * 60,
    );
    // ignore: avoid_print
    print('LIGHT 11:37 PM ${_lights(tester)}');
    await sheet.shot(
      tester,
      'N_doorway_1137pm',
      at: at,
      surface: 'QUESTS',
      note: 'Monday 11:37 PM, both attended, the music on',
    );
    await _toBoard(tester);
    await sheet.shot(
      tester,
      'N_board_1137pm',
      at: at,
      surface: 'QUESTS',
      note: 'BOARD at 11:37 PM',
    );
    await _musicOff(tester);
  });

  roomRenderTest('21:00, no music', skip: !_renders, (tester) async {
    if (!_wants('quiet')) return;
    final at = _at(6, 21, 0);
    await _boot(tester, at, keep: _all);
    await sheet.shot(
      tester,
      'E_doorway_2100',
      at: at,
      surface: 'QUESTS',
      note: 'Tuesday 21:00, both attended, no music',
    );
    await _toBoard(tester);
    await sheet.shot(
      tester,
      'E_board_2100',
      at: at,
      surface: 'QUESTS',
      note: 'BOARD at 21:00',
    );
  });

  roomRenderTest('130% text', skip: !_renders, (tester) async {
    if (!_wants('text')) return;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final at = _at(6, 12, 30);
    await _boot(tester, at);
    await sheet.shot(
      tester,
      'T_doorway_130',
      at: at,
      surface: 'QUESTS',
      note: 'Tuesday 12:30 at 130% text',
    );
    await _toBoard(tester);
    await sheet.shot(
      tester,
      'T_board_130',
      at: at,
      surface: 'QUESTS',
      note: 'BOARD at 130% text',
    );
  });

  roomRenderTest('evening at 130% text', skip: !_renders, (tester) async {
    if (!_wants('text')) return;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final at = _at(6, 21, 0);
    await _boot(tester, at, keep: _all, music: true);
    await sheet.shot(
      tester,
      'T_evening_130',
      at: at,
      surface: 'QUESTS',
      note: 'Tuesday 21:00 at 130% text, the music on',
    );
    await _musicOff(tester);
  });

  roomRenderTest('the day closed', skip: !_renders, (tester) async {
    if (!_wants('closed')) return;
    final at = _at(10, 21, 0);
    await _boot(tester, at, chosen: true, closed: true);
    await sheet.shot(
      tester,
      'R_doorway_closed',
      at: at,
      surface: 'QUESTS',
      note: 'Saturday 21:00, tonight closed: the day is kept',
    );
    await _toBoard(tester);
    await sheet.shot(
      tester,
      'R_board_closed',
      at: at,
      surface: 'QUESTS',
      note: 'BOARD with the day kept: the board rests',
    );
  });

  for (final (name, w, h, top, bottom, scale) in [
    ('375', 375.0, 667.0, 20.0, 0.0, 1.0),
    ('320', 320.0, 568.0, 20.0, 0.0, 1.3),
  ]) {
    roomRenderTest('a short phone, $name wide', skip: !_renders, (
      tester,
    ) async {
      if (!_wants('phones')) return;
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = Size(w * 3, h * 3);
      tester.view.padding = FakeViewPadding(top: top * 3, bottom: bottom * 3);
      tester.view.viewPadding = FakeViewPadding(
        top: top * 3,
        bottom: bottom * 3,
      );
      if (scale != 1) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      }
      final at = _at(6, 12, 30);
      await _boot(tester, at);
      await sheet.shot(
        tester,
        'P${name}_doorway',
        at: at,
        surface: 'QUESTS',
        note: '$name x ${h.round()} at ${(scale * 100).round()}% text',
      );
      await _toBoard(tester);
      await sheet.shot(
        tester,
        'P${name}_board',
        at: at,
        surface: 'QUESTS',
        note: 'BOARD, $name x ${h.round()} at ${(scale * 100).round()}% text',
      );
    });
  }

  roomRenderTest('a Saturday without classes', skip: !_renders, (tester) async {
    if (!_wants('saturday')) return;
    final at = _at(10, 11, 0);
    await _boot(tester, at, chosen: true);
    await sheet.shot(
      tester,
      'S_doorway',
      at: at,
      surface: 'QUESTS',
      note: 'Saturday, Today\'s three on the rail',
    );
    await _toBoard(tester);
    await sheet.shot(
      tester,
      'S_board',
      at: at,
      surface: 'QUESTS',
      note: 'Saturday, BOARD at rest',
    );
  });

  roomRenderTest('a Saturday, nothing chosen', skip: !_renders, (tester) async {
    if (!_wants('saturday')) return;
    final at = _at(10, 11, 0);
    await _boot(tester, at);
    await sheet.shot(
      tester,
      'S_doorway_choose',
      at: at,
      surface: 'QUESTS',
      note: 'Saturday, nothing chosen: the invitation',
    );
  });
}
