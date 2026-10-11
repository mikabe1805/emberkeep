// Renders the Goals wall's tap-to-swap through the real app (the shell, the
// HUD and the dock) at iPhone size (393 x 852 at 3x, PNGs 1179 x 2556): the
// wall at rest with three goals, a label tapped (two moments of the swap and
// the settled card), five goals with the "+N" tag, the tag pressed, and the
// room at 130% and 200% text. Skipped unless asked for:
//
//   flutter test --dart-define=GOALS_WALL_RENDERS=true \
//     test/design_renders/house_goals_wall_render_test.dart
//
// Output: design/comparisons/2026-10-11/h53-goals-wall/ in this checkout.
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/quests.dart' show QuestsPage;
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/class_day/doorway_art.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('GOALS_WALL_RENDERS');
const _only = String.fromEnvironment('GOALS_WALL_ONLY');
bool _wants(String name) =>
    _only.isEmpty || _only.split(',').map((s) => s.trim()).contains(name);

const _out =
    'C:/Users/mikus/Downloads/experimentProject/app/.worktrees/house-goals/'
    'design/comparisons/2026-10-11/h53-goals-wall';

final _at = DateTime(2026, 10, 6, 12, 30);

List<String> get _plates => {
  for (final set in [HousePlateSets.goals]) ...set.all,
}.toList();

Future<void> _boot(WidgetTester tester) async {
  final account = mikaAccount(renderAt: _at);
  Clock.freeze(_at);
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
void _theWall(WidgetTester tester, {int count = 3}) {
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
  for (final (title, stat, quest) in goals.take(count)) {
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

Future<void> _pumpFor(WidgetTester tester, int ms) async {
  var t = 0;
  while (t < ms) {
    final step = (ms - t) < 10 ? (ms - t) : 10;
    await tester.pump(Duration(milliseconds: step));
    t += step;
  }
}

Finder _label(String id) => find.byKey(Key('goals-wall-$id'));

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

  roomRenderTest('rest, a swap, and the swapped card', skip: !_renders, (
    tester,
  ) async {
    if (!_wants('swap')) return;
    await _boot(tester);
    _theWall(tester);
    await _openGoals(tester);
    await sheet.shot(
      tester,
      'W_rest_3',
      at: _at,
      surface: 'GOALS',
      note: 'three goals, the first is current: its edge is lit',
    );

    await tester.tap(_label('computer-architecture'));
    await tester.pump();
    await _pumpFor(tester, 70);
    await sheet.shot(
      tester,
      'W_swap_070',
      at: _at,
      surface: 'GOALS',
      note: '70 ms into the swap: the old goal is leaving',
    );
    await _pumpFor(tester, 80);
    await sheet.shot(
      tester,
      'W_swap_150',
      at: _at,
      surface: 'GOALS',
      note: '150 ms: the new goal is coming up',
    );
    await settle(tester, total: const Duration(milliseconds: 600));
    await sheet.shot(
      tester,
      'W_after_swap',
      at: _at,
      surface: 'GOALS',
      note: 'Computer Architecture is current: the lit edge has moved',
    );

    await tester.tap(_label('summer-2027'));
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 700));
    await sheet.shot(
      tester,
      'W_after_swap_3',
      at: _at,
      surface: 'GOALS',
      note: 'Summer 2027 is current (a card with a different first step)',
    );
  });

  roomRenderTest('five goals and the "+N" tag', skip: !_renders, (
    tester,
  ) async {
    if (!_wants('tag')) return;
    await _boot(tester);
    _theWall(tester, count: 5);
    await _openGoals(tester);
    await sheet.shot(
      tester,
      'W_five_tag',
      at: _at,
      surface: 'GOALS',
      note: 'five goals: three labels and "+2" under the lowest',
    );
    await tester.tap(find.byKey(const Key('goals-wall-more')));
    await tester.pump();
    await _pumpFor(tester, 160);
    await sheet.shot(
      tester,
      'W_five_tag_pressed_160',
      at: _at,
      surface: 'GOALS',
      note: '"+2" pressed, 160 ms in: MORE unrolling to Other goals',
    );
    await settle(tester, total: const Duration(milliseconds: 900));
    await sheet.shot(
      tester,
      'W_five_tag_open',
      at: _at,
      surface: 'GOALS',
      note: '"+2" pressed: MORE unrolled and scrolled to Other goals',
    );
  });

  for (final scale in [1.3, 2.0]) {
    final tag = (scale * 100).round();
    roomRenderTest('large text $tag%', skip: !_renders, (tester) async {
      if (!_wants('large')) return;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _boot(tester);
      _theWall(tester, count: 5);
      await _openGoals(tester);
      await sheet.shot(
        tester,
        'W_large_$tag',
        at: _at,
        surface: 'GOALS',
        note: 'five goals at $tag% text: the wall is a list, "+2" after it',
      );
      await tester.tap(find.byKey(const Key('goals-wall-more')));
      await tester.pump();
      await settle(tester, total: const Duration(milliseconds: 1000));
      await sheet.shot(
        tester,
        'W_large_${tag}_open',
        at: _at,
        surface: 'GOALS',
        note: '"+2" pressed at $tag% text: Other goals under the HUD',
      );
    });
  }

  roomRenderTest('a narrow phone', skip: !_renders, (tester) async {
    if (!_wants('narrow')) return;
    // 320 wide, the same shape as the phone (320 x 693 pt).
    tester.view.physicalSize = const Size(320 * 3, 693 * 3);
    await _boot(tester);
    _theWall(tester, count: 5);
    await _openGoals(tester);
    await sheet.shot(
      tester,
      'W_narrow_320',
      at: _at,
      surface: 'GOALS',
      note: '320 wide, five goals',
    );
  });
}
