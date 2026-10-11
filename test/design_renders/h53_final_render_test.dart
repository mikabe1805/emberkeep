// The last fixes before the build, through the real app (the shell, the HUD and
// the dock), at 3x: Goals at rest on the three phone sizes (393 x 852,
// 375 x 667, 320 x 568), Goals at 200% text scrolled under the HUD, Goals at
// 21:00 at rest and mid-arrival on the lamp-lit plate, and the HUD's stat row
// at 130% text in two rooms. Skipped unless asked for:
//
//   flutter test --dart-define=H53_FINAL=true \
//     test/design_renders/h53_final_render_test.dart
//
// H53_FINAL_ONLY=rest,large,evening,hud picks groups; H53_FINAL_OUT=<folder>
// writes somewhere else. Output: design/comparisons/2026-10-11/h53-final/ in
// this checkout.
//
// The short phones are drawn with their real safe areas (an iPhone SE has a
// 20 pt status bar and no home indicator), the tall one with the 15 Pro's.
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/quests.dart' show QuestsPage;
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/class_day/doorway_art.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('H53_FINAL');
const _only = String.fromEnvironment('H53_FINAL_ONLY');
bool _wants(String name) =>
    _only.isEmpty || _only.split(',').map((s) => s.trim()).contains(name);

const _out = String.fromEnvironment(
  'H53_FINAL_OUT',
  defaultValue:
      'C:/Users/mikus/Downloads/experimentProject/app/.worktrees/class-day-journey/'
      'design/comparisons/2026-10-11/h53-final',
);

/// A phone: its size, and its safe area at the top and the bottom.
typedef _Device = ({
  String name,
  double w,
  double h,
  double top,
  double bottom,
});

const _tall = (name: '393x852', w: 393.0, h: 852.0, top: 59.0, bottom: 34.0);
const _se = (name: '375x667', w: 375.0, h: 667.0, top: 20.0, bottom: 0.0);
const _small = (name: '320x568', w: 320.0, h: 568.0, top: 20.0, bottom: 0.0);

void _device(WidgetTester tester, _Device d) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = Size(d.w * 3, d.h * 3);
  tester.view.padding = FakeViewPadding(top: d.top * 3, bottom: d.bottom * 3);
  tester.view.viewPadding = FakeViewPadding(
    top: d.top * 3,
    bottom: d.bottom * 3,
  );
}

final _midday = DateTime(2026, 10, 6, 12, 30);
final _evening = DateTime(2026, 10, 6, 21, 0);

List<String> get _plates => {
  for (final set in [HousePlateSets.goals, HousePlateSets.me]) ...set.all,
}.toList();

Future<void> _boot(WidgetTester tester, DateTime at) async {
  final account = mikaAccount(renderAt: at);
  Clock.freeze(at);
  await bootRoom(
    tester,
    account,
    schedule: mikaSchedule(),
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
}

/// The goals of the v4 prototype's wall, with real first steps; [count] of
/// them (five makes two that the wall has no sheet for).
void _theWall(WidgetTester tester, {int count = 3, bool long = false}) {
  final state = liveState(tester);
  final quests = liveQuests(tester);
  for (final goal in List<Goal>.of(state.goals)) {
    state.removeGoal(goal);
  }
  quests.removeWhere((q) => q.goalTitle != null);
  const goals = <(String, Stat, String)>[
    ('Room of Days', Stat.foc, 'Open Quest'),
    ('Computer Architecture', Stat.foc, 'Review one problem'),
    ('Summer 2027', Stat.soc, 'Open Quest'),
    ('Make the apartment feel calm', Stat.dis, 'Clear the kitchen counter'),
    ('Build a walking habit', Stat.vit, 'Walk after lunch'),
  ];
  // With [long], the middle sheet holds a name that would run under the sign.
  final wall = long
      ? [
          goals[0],
          (
            'Make the apartment feel calm and bright',
            Stat.dis,
            'Clear the kitchen counter',
          ),
          goals[2],
        ]
      : goals;
  for (final (title, stat, quest) in wall.take(count)) {
    state.addGoal(
      Goal(
        title: title,
        stat: stat,
        target: 25,
        progress: 6,
        openingSeen: true,
        startedDay: '2026-09-20',
      ),
    );
    quests.add(
      Quest(title: quest, stat: stat, difficulty: 1, goalTitle: title),
    );
  }
  // The prototype's current goal is the first.
  state.featuredGoalTitles
    ..clear()
    ..add(goals.first.$1);
}

Future<void> _openGoals(WidgetTester tester) async {
  await openTab(tester, RoomTab.goals);
  await settle(tester, total: const Duration(milliseconds: 900));
}

Future<void> _arrive(WidgetTester tester, RoomTab tab, int after) async {
  final label = find.text(tab.label).hitTestable();
  await tester.tap(label.last);
  await tester.pump();
  var t = 0;
  while (t < after) {
    final step = (after - t) < 17 ? (after - t) : 17;
    await tester.pump(Duration(milliseconds: step));
    t += step;
  }
}

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

  for (final d in [_tall, _se, _small]) {
    roomRenderTest('Goals at rest on ${d.name}', skip: !_renders, (
      tester,
    ) async {
      if (!_wants('rest')) return;
      _device(tester, d);
      await _boot(tester, _midday);
      _theWall(tester);
      await _openGoals(tester);
      await sheet.shot(
        tester,
        'G_rest_${d.name}',
        at: _midday,
        surface: 'GOALS',
        note: 'three goals at rest on ${d.name}',
      );
      _theWall(tester, count: 5);
      await settle(tester, total: const Duration(milliseconds: 600));
      await sheet.shot(
        tester,
        'G_rest5_${d.name}',
        at: _midday,
        surface: 'GOALS',
        note:
            'five goals at rest on ${d.name}: the +N counts what is not drawn',
      );
      _theWall(tester, long: true);
      await settle(tester, total: const Duration(milliseconds: 600));
      await sheet.shot(
        tester,
        'G_long_${d.name}',
        at: _midday,
        surface: 'GOALS',
        note: 'a long name beside the sign ends short of it on ${d.name}',
      );
    });
  }

  roomRenderTest('Goals at 200% text, scrolled', skip: !_renders, (
    tester,
  ) async {
    if (!_wants('large')) return;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _boot(tester, _midday);
    _theWall(tester, count: 5);
    await _openGoals(tester);
    await sheet.shot(
      tester,
      'L_goals_200_rest',
      at: _midday,
      surface: 'GOALS',
      note: '200% text at rest: the page starts under the HUD',
    );
    final scroll = find.byKey(const Key('goals-threshold-scroll'));
    await tester.drag(scroll, const Offset(0, -330), warnIfMissed: false);
    await settle(tester, total: const Duration(milliseconds: 900));
    await sheet.shot(
      tester,
      'L_goals_200_scrolled',
      at: _midday,
      surface: 'GOALS',
      note: '200% text scrolled: the card climbs under the HUD and dissolves',
    );
    await tester.drag(scroll, const Offset(0, -200), warnIfMissed: false);
    await settle(tester, total: const Duration(milliseconds: 900));
    await sheet.shot(
      tester,
      'L_goals_200_scrolled_more',
      at: _midday,
      surface: 'GOALS',
      note: '200% text scrolled further',
    );
  });

  roomRenderTest('Goals at 21:00', skip: !_renders, (tester) async {
    if (!_wants('evening')) return;
    await _boot(tester, _evening);
    _theWall(tester);
    await _openGoals(tester);
    await sheet.shot(
      tester,
      'E_goals_rest',
      at: _evening,
      surface: 'GOALS',
      note: '21:00 at rest on the lamp-lit plate',
    );
    _theWall(tester, count: 5);
    await settle(tester, total: const Duration(milliseconds: 600));
    await sheet.shot(
      tester,
      'E_goals_rest5',
      at: _evening,
      surface: 'GOALS',
      note: '21:00 with five goals: the +2 tag on the dark plate',
    );
    _theWall(tester);
    await openTab(tester, RoomTab.quests);
    await settle(tester, total: const Duration(milliseconds: 900));
    await _arrive(
      tester,
      RoomTab.goals,
      (HouseRoom.goals.arrivalMs * 0.5).round(),
    );
    await sheet.shot(
      tester,
      'E_goals_arrive_mid',
      at: _evening,
      surface: 'GOALS',
      note: '21:00 mid arrival, ${HouseRoom.goals.arrivalMs} ms',
    );
    await settle(tester, total: const Duration(milliseconds: 1200));
  });

  roomRenderTest('the HUD at 130% text', skip: !_renders, (tester) async {
    if (!_wants('hud')) return;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _boot(tester, _midday);
    for (final tab in [RoomTab.quests, RoomTab.goals]) {
      await openTab(tester, tab);
      await settle(tester, total: const Duration(milliseconds: 900));
      await sheet.shot(
        tester,
        'H_hud130_${tab.name}',
        at: _midday,
        surface: tab.label,
        note: '130% text: the stat row, icon to numeral',
      );
    }
    _device(tester, _small);
    await settle(tester, total: const Duration(milliseconds: 600));
    await sheet.shot(
      tester,
      'H_hud130_320',
      at: _midday,
      surface: 'GOALS',
      note: '130% text on 320 wide: three-digit stats',
    );
  });
}
