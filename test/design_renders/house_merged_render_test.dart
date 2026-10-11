// Renders the merged house through the real app at iPhone size (393 x 852 at
// 3x, PNGs 1179 x 2556): every room at rest (midday and evening), one
// mid-arrival per room, Quests on a class day and on a Saturday, Plans day,
// week and month, the Me sheets, the Journal, and each room at 130% text.
// Skipped unless asked for:
//
//   flutter test --dart-define=HOUSE_MERGED=true \
//     test/design_renders/house_merged_render_test.dart
//
// Output: design/comparisons/2026-10-11/house-merged/ in the class-day-journey
// checkout, next to the prototype's v4 frames (the sheets are made from both).
// MERGED_OUT=<folder> writes somewhere else (the h53 merge used h53-merged).
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/screens/quests.dart' show QuestsPage;
import 'package:emberkeep/widgets/class_day/doorway_art.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('HOUSE_MERGED');
const _only = String.fromEnvironment('MERGED_ONLY');
bool _wants(String name) =>
    _only.isEmpty || _only.split(',').map((s) => s.trim()).contains(name);

const _out = String.fromEnvironment(
  'MERGED_OUT',
  defaultValue:
      'C:/Users/mikus/Downloads/experimentProject/app/.worktrees/class-day-journey/'
      'design/comparisons/2026-10-11/house-merged',
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
    HousePlateSets.plansWeek,
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

Future<void> _mode(WidgetTester tester, String mode) async {
  await tester.tap(find.byKey(ValueKey('academic-mode-$mode')));
  await tester.pump();
  await settle(tester, total: const Duration(milliseconds: 900));
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await settle(tester, total: const Duration(milliseconds: 900));
}

Future<void> _rest(
  WidgetTester tester,
  FrameSheet sheet,
  String name,
  DateTime at,
  RoomTab tab,
  String note,
) async {
  await openTab(tester, tab);
  await settle(tester, total: const Duration(milliseconds: 900));
  await sheet.shot(tester, name, at: at, surface: tab.label, note: note);
}

const _tabs = [
  RoomTab.quests,
  RoomTab.me,
  RoomTab.goals,
  RoomTab.plans,
  RoomTab.journal,
];

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

  roomRenderTest(
    'midday rests, Plans views, Me sheets, arrivals',
    skip: !_renders,
    (tester) async {
      if (!_wants('midday')) return;
      final at = _at(6, 12, 30);
      await _boot(tester, at);
      for (final tab in _tabs) {
        await _rest(
          tester,
          sheet,
          'M_rest_${tab.name}',
          at,
          tab,
          'at rest, midday',
        );
      }
      await openTab(tester, RoomTab.plans);
      await _mode(tester, 'day');
      await sheet.shot(
        tester,
        'M_plans_day',
        at: at,
        surface: 'PLANS',
        note: 'DAY',
      );
      await _mode(tester, 'week');
      await sheet.shot(
        tester,
        'M_plans_week',
        at: at,
        surface: 'PLANS',
        note: 'WEEK on its own plate',
      );
      await _mode(tester, 'month');
      await sheet.shot(
        tester,
        'M_plans_month',
        at: at,
        surface: 'PLANS',
        note: 'MONTH',
      );
      await _mode(tester, 'day');
      await openTab(tester, RoomTab.me);
      for (final (key, shot) in [
        ('mantel-tab-settings', 'settings'),
        ('mantel-tag-trophy', 'trophy'),
        ('mantel-tab-space', 'space'),
        ('mantel-tab-more', 'more'),
      ]) {
        await _tap(tester, key);
        await sheet.shot(
          tester,
          'M_me_sheet_$shot',
          at: at,
          surface: 'ME',
          note: '$shot sheet',
        );
        // "Your space" is a page now, with its own BACK; the rest are sheets.
        await _tap(
          tester,
          find.byKey(const Key('your-space-back')).evaluate().isNotEmpty
              ? 'your-space-back'
              : 'mantel-sheet-close',
        );
      }
      await openTab(tester, RoomTab.journal);
      await tester.drag(
        find.byKey(const ValueKey('journal-nook-scroll')),
        const Offset(0, -420),
      );
      await settle(tester, total: const Duration(milliseconds: 600));
      await sheet.shot(
        tester,
        'M_journal_scrolled',
        at: at,
        surface: 'JOURNAL',
        note: 'scrolled: the HUD over the cards',
      );
      for (final tab in [
        RoomTab.me,
        RoomTab.goals,
        RoomTab.plans,
        RoomTab.journal,
        RoomTab.quests,
      ]) {
        final room = HouseRoom.values[tab.index];
        await openTab(
          tester,
          tab == RoomTab.quests ? RoomTab.me : RoomTab.quests,
        );
        await settle(tester, total: const Duration(milliseconds: 1200));
        await _arrive(tester, tab, (room.arrivalMs * 0.5).round());
        await sheet.shot(
          tester,
          'M_arrive_${tab.name}_mid',
          at: at,
          surface: tab.label,
          note: 'mid arrival, ${room.arrivalMs} ms',
        );
        await settle(tester, total: const Duration(milliseconds: 1200));
      }
    },
  );

  roomRenderTest('evening rests', skip: !_renders, (tester) async {
    if (!_wants('evening')) return;
    final at = _at(6, 21, 0);
    await _boot(tester, at);
    for (final tab in _tabs) {
      await _rest(
        tester,
        sheet,
        'E_rest_${tab.name}',
        at,
        tab,
        'at rest, 21:00',
      );
    }
    await openTab(tester, RoomTab.plans);
    await _mode(tester, 'week');
    await sheet.shot(
      tester,
      'E_plans_week',
      at: at,
      surface: 'PLANS',
      note: 'WEEK at evening',
    );
    await _mode(tester, 'month');
    await sheet.shot(
      tester,
      'E_plans_month',
      at: at,
      surface: 'PLANS',
      note: 'MONTH at evening',
    );
    await _mode(tester, 'day');
    await openTab(tester, RoomTab.quests);
    await settle(tester, total: const Duration(milliseconds: 900));
    await _arrive(tester, RoomTab.goals, 370);
    await sheet.shot(
      tester,
      'E_arrive_goals_mid',
      at: at,
      surface: 'GOALS',
      note: 'mid arrival at evening',
    );
  });

  roomRenderTest('a Saturday without classes', skip: !_renders, (tester) async {
    if (!_wants('saturday')) return;
    final at = _at(10, 11, 0);
    await _boot(tester, at);
    await settle(tester, total: const Duration(milliseconds: 900));
    await sheet.shot(
      tester,
      'S_rest_quests',
      at: at,
      surface: 'QUESTS',
      note: 'Saturday, the three on the rail',
    );
    await _arrive(tester, RoomTab.me, 430);
    await settle(tester, total: const Duration(milliseconds: 1200));
    await _arrive(tester, RoomTab.quests, 350);
    await sheet.shot(
      tester,
      'S_arrive_quests_mid',
      at: at,
      surface: 'QUESTS',
      note: 'mid arrival on Saturday',
    );
  });

  roomRenderTest('130% text, every room', skip: !_renders, (tester) async {
    if (!_wants('text')) return;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final at = _at(6, 12, 30);
    await _boot(tester, at);
    for (final tab in _tabs) {
      await _rest(tester, sheet, 'T_rest_${tab.name}', at, tab, '130% text');
    }
    await openTab(tester, RoomTab.plans);
    await _mode(tester, 'week');
    await sheet.shot(
      tester,
      'T_plans_week',
      at: at,
      surface: 'PLANS',
      note: 'WEEK 130% text',
    );
    await _mode(tester, 'month');
    await sheet.shot(
      tester,
      'T_plans_month',
      at: at,
      surface: 'PLANS',
      note: 'MONTH 130% text',
    );
  });
}
