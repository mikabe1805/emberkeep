// Renders the house: each tab at rest in its room (midday), the arrival of
// each room at its midpoint and quarter points, and Me and Plans in the
// evening, through the real app at iPhone size (393 x 852 at 3x, PNGs
// 1179 x 2556). Skipped unless asked for:
//
//   flutter test --dart-define=HOUSE_RENDERS=true \
//     test/design_renders/house_build_render_test.dart
//
// Output: design/comparisons/2026-10-10/house-build/ in the class-day-journey
// checkout. A frame at 430 ms is the app 430 ms after the tap on the dock tab,
// the travel's own clock; the sheet script puts them beside the prototype's
// own v4 frames.
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/widgets/class_day/doorway_art.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('HOUSE_RENDERS');
const _only = String.fromEnvironment('HOUSE_ONLY');
bool _wants(String name) =>
    _only.isEmpty || _only.split(',').map((s) => s.trim()).contains(name);

const _out =
    'C:/Users/mikus/Downloads/experimentProject/app/.worktrees/class-day-journey/'
    'design/comparisons/2026-10-10/house-build';

DateTime _at(int day, int hour, int minute) =>
    DateTime(2026, 10, day, hour, minute);

final _schedule = mikaSchedule();

/// Every house plate, so the first frames paint them.
List<String> get _housePlates => {
  for (final set in [
    HousePlateSets.me,
    HousePlateSets.goals,
    HousePlateSets.plansDay,
    HousePlateSets.plansMonth,
    HousePlateSets.journal,
  ])
    ...set.all,
}.toList();

Future<void> _boot(WidgetTester tester, DateTime at) async {
  final account = mikaAccount(renderAt: at);
  Clock.freeze(at);
  await bootRoom(
    tester,
    account,
    schedule: _schedule,
    precache: [...RoomArt.everyday, ..._housePlates],
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

/// Taps the tab and pumps [after] of the arrival (frames of 1/60 s).
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
  final sheet = FrameSheet(_out);
  tearDownAll(() {
    if (_renders) sheet.writeManifest();
  });

  // Tuesday 6 October at 12:30: between his two classes, the light of midday.
  roomRenderTest('rest and arrivals at midday', skip: !_renders, (
    tester,
  ) async {
    if (!_wants('midday')) return;
    final at = _at(6, 12, 30);
    await _boot(tester, at);

    // Every tab at rest, in its room.
    for (final tab in [
      RoomTab.quests,
      RoomTab.me,
      RoomTab.goals,
      RoomTab.plans,
      RoomTab.journal,
    ]) {
      await openTab(tester, tab);
      await sheet.shot(
        tester,
        'H_rest_${tab.name}',
        at: at,
        surface: tab.label,
        note: 'at rest, midday',
      );
    }

    // The arrival of each room, at 25%, 50% and 75% of its time, from Quests
    // (Quests from Me).
    for (final tab in [
      RoomTab.me,
      RoomTab.goals,
      RoomTab.plans,
      RoomTab.journal,
      RoomTab.quests,
    ]) {
      final room = HouseRoom.values[tab.index];
      for (final (name, share) in const [
        ('25', 0.25),
        ('mid', 0.5),
        ('75', 0.75),
      ]) {
        await openTab(
          tester,
          tab == RoomTab.quests ? RoomTab.me : RoomTab.quests,
        );
        await _arrive(tester, tab, (room.arrivalMs * share).round());
        await sheet.shot(
          tester,
          'H_arrive_${tab.name}_$name',
          at: at,
          surface: tab.label,
          note: '${(share * 100).round()}% of ${room.arrivalMs} ms',
        );
        await settle(tester, total: const Duration(milliseconds: 1200));
      }
    }
  });

  // A day without classes: the Doorway behind the board, the rail empty.
  roomRenderTest('a day without classes', skip: !_renders, (tester) async {
    if (!_wants('saturday')) return;
    final at = _at(10, 11, 0);
    await _boot(tester, at);
    await sheet.shot(
      tester,
      'H_rest_quests_noclass',
      at: at,
      surface: 'QUESTS',
      note: 'Saturday: the Doorway behind the board, empty rail',
    );
    await _arrive(tester, RoomTab.me, 430);
    await sheet.shot(
      tester,
      'H_arrive_me_from_noclass_mid',
      at: at,
      surface: 'ME',
      note: 'leaving the board for the hearth',
    );
    await settle(tester, total: const Duration(milliseconds: 1200));
    await _arrive(tester, RoomTab.quests, 350);
    await sheet.shot(
      tester,
      'H_arrive_quests_noclass_mid',
      at: at,
      surface: 'QUESTS',
      note: 'the door glass blooms on the board',
    );
  });

  // Tuesday evening: Me and Plans have a painted evening; Goals and Journal
  // keep their painted light (no tint over a daylight plate).
  roomRenderTest('evening', skip: !_renders, (tester) async {
    if (!_wants('evening')) return;
    final at = _at(6, 21, 0);
    await _boot(tester, at);
    for (final tab in [
      RoomTab.me,
      RoomTab.plans,
      RoomTab.goals,
      RoomTab.journal,
    ]) {
      await openTab(tester, tab);
      await sheet.shot(
        tester,
        'H_evening_${tab.name}',
        at: at,
        surface: tab.label,
        note: 'at rest, 21:00',
      );
    }
    await openTab(tester, RoomTab.quests);
    await _arrive(tester, RoomTab.plans, 410);
    await sheet.shot(
      tester,
      'H_evening_arrive_plans_mid',
      at: at,
      surface: 'PLANS',
      note: 'amber band at evening',
    );
  });
}
