// Renders the Goals room (the Steward's workshop) through the real app at
// iPhone size (393 x 852 at 3x, PNGs 1179 x 2556): the current goal with
// three goals on the wall, one goal, five goals, no goal, the card unrolled,
// the goal page pushed from the wall, large text, and the lamp's arrival.
// Skipped unless asked for:
//
//   flutter test --dart-define=GOALS_ROOM_RENDERS=true \
//     test/design_renders/house_goals_render_test.dart
//
// Output: design/comparisons/2026-10-10/house-rooms/goals/ in the
// class-day-journey checkout. `sheet.py` beside this file's output puts the
// prototype's v4 frames next to them.
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/class_day/doorway_art.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('GOALS_ROOM_RENDERS');
const _only = String.fromEnvironment('GOALS_ROOM_ONLY');
bool _wants(String name) =>
    _only.isEmpty || _only.split(',').map((s) => s.trim()).contains(name);

const _out =
    'C:/Users/mikus/Downloads/experimentProject/app/.worktrees/class-day-journey/'
    'design/comparisons/2026-10-10/house-rooms/goals';

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

/// The goals of the v4 prototype's wall, with real first steps.
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
    ('Summer 2027', Stat.soc, 'Send one application'),
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
}

Future<void> _openGoals(WidgetTester tester) async {
  await openTab(tester, RoomTab.goals);
  await settle(tester, total: const Duration(milliseconds: 800));
}

void main() {
  setUpAll(setUpRoomRenders);
  tearDownAll(tearDownRoomRenders);
  final sheet = FrameSheet(_out);
  tearDownAll(() {
    if (_renders) sheet.writeManifest();
  });

  roomRenderTest('the room at rest', skip: !_renders, (tester) async {
    if (!_wants('rest')) return;
    await _boot(tester);
    _theWall(tester);
    await _openGoals(tester);
    await sheet.shot(
      tester,
      'G_rest_focus',
      at: _at,
      surface: 'GOALS',
      note: 'three goals on the wall, the first is current',
    );

    // The card unrolled.
    await tester.tap(find.byKey(const Key('goals-room-more')));
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 700));
    await sheet.shot(
      tester,
      'G_more_open',
      at: _at,
      surface: 'GOALS',
      note: 'MORE unrolled: this goal, other goals, another way in',
    );
    await tester.tap(find.byKey(const Key('goals-room-more')));
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 500));

    // One goal.
    _theWall(tester, count: 1);
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 400));
    await sheet.shot(
      tester,
      'G_rest_one_goal',
      at: _at,
      surface: 'GOALS',
      note: 'one goal, one label',
    );

    // Five goals: three labels, the current goal always among them.
    _theWall(tester, count: 5);
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 400));
    await sheet.shot(
      tester,
      'G_rest_five_goals',
      at: _at,
      surface: 'GOALS',
      note: 'five goals: the wall holds three',
    );

    // No goal.
    _theWall(tester, count: 0);
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 600));
    await sheet.shot(
      tester,
      'G_no_focus',
      at: _at,
      surface: 'GOALS',
      note: 'no goal: Make room for a direction',
    );
  });

  roomRenderTest('a goal from the wall', skip: !_renders, (tester) async {
    if (!_wants('detail')) return;
    await _boot(tester);
    _theWall(tester);
    await _openGoals(tester);
    // A label makes its goal current; the card's name opens it.
    await tester.tap(find.byKey(const Key('goals-wall-computer-architecture')));
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('goals-card-open-goal')));
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 1400));
    await sheet.shot(
      tester,
      'G_detail',
      at: _at,
      surface: 'GOAL',
      note:
          'Computer Architecture, pushed from the name on the card: the same plate',
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -420));
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 700));
    await sheet.shot(
      tester,
      'G_detail_scrolled',
      at: _at,
      surface: 'GOAL',
      note: 'scrolled: the veil deepens over the room',
    );
  });

  for (final scale in [1.3, 2.0]) {
    final tag = (scale * 100).round();
    roomRenderTest('large text $tag%', skip: !_renders, (tester) async {
      if (!_wants('large')) return;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _boot(tester);
      _theWall(tester);
      await _openGoals(tester);
      await sheet.shot(
        tester,
        'G_large_$tag',
        at: _at,
        surface: 'GOALS',
        note: 'text at $tag%',
      );
      await tester.tap(find.byKey(const Key('goals-room-more')));
      await tester.pump();
      await settle(tester, total: const Duration(milliseconds: 500));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await tester.pump();
      await settle(tester, total: const Duration(milliseconds: 600));
      await sheet.shot(
        tester,
        'G_large_${tag}_more',
        at: _at,
        surface: 'GOALS',
        note: 'text at $tag%, unrolled and scrolled',
      );
    });
  }

  roomRenderTest('the lamp arrives', skip: !_renders, (tester) async {
    if (!_wants('arrive')) return;
    await _boot(tester);
    _theWall(tester);
    await openTab(tester, RoomTab.quests);
    final label = find.text(RoomTab.goals.label).hitTestable();
    await tester.tap(label.last);
    await tester.pump();
    var t = 0;
    for (final (name, mark) in const [('25', 185), ('mid', 370), ('75', 555)]) {
      while (t < mark) {
        await tester.pump(const Duration(milliseconds: 17));
        t += 17;
      }
      await sheet.shot(
        tester,
        'G_arrive_$name',
        at: _at,
        surface: 'GOALS',
        note: '${t}ms of ${HouseRoom.goals.arrivalMs} ms',
      );
    }
  });
}
