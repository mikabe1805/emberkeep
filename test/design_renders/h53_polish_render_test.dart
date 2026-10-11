// Renders for the small follow-ups of the house merge (2026-10-11), through the
// real app at iPhone size (393 x 852 at 3x, PNGs 1179 x 2556):
//
//   * Plans day and week with a long class name, at 100%, 130% and 200% text
//     (a card's title is two lines at most);
//   * the Journal at rest and scrolled, and all five rooms at rest, to show the
//     dock's fade no longer dims a room at rest and still rises under scrolled
//     content.
//
// Skipped unless asked for:
//
//   flutter test --dart-define=H53_POLISH=true \
//     test/design_renders/h53_polish_render_test.dart
//
// Output: design/comparisons/2026-10-11/h53-polish/ in this checkout.
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/screens/quests.dart' show QuestsPage;
import 'package:emberkeep/widgets/class_day/doorway_art.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('H53_POLISH');
const _only = String.fromEnvironment('H53_ONLY');
bool _wants(String name) =>
    _only.isEmpty || _only.split(',').map((s) => s.trim()).contains(name);

const _out =
    'C:/Users/mikus/Downloads/experimentProject/app/.worktrees/house-plans/'
    'design/comparisons/2026-10-11/h53-polish';

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

Future<void> _mode(WidgetTester tester, String mode) async {
  await tester.tap(find.byKey(ValueKey('academic-mode-$mode')));
  await tester.pump();
  await settle(tester, total: const Duration(milliseconds: 900));
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
  setUp(() => QuestsPage.debugLegacyBoard = false);
  tearDown(() => QuestsPage.debugLegacyBoard = true);
  final sheet = FrameSheet(_out);
  tearDownAll(() {
    if (_renders) sheet.writeManifest();
  });

  roomRenderTest('rests and the Journal scrolled', skip: !_renders, (
    tester,
  ) async {
    if (!_wants('rests')) return;
    final at = _at(6, 12, 30);
    await _boot(tester, at);
    for (final tab in _tabs) {
      await openTab(tester, tab);
      await settle(tester, total: const Duration(milliseconds: 900));
      await sheet.shot(
        tester,
        'M_rest_${tab.name}',
        at: at,
        surface: tab.label,
        note: 'at rest, midday',
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
      note: 'scrolled: the fade is up under the cards',
    );
    await tester.drag(
      find.byKey(const ValueKey('journal-nook-scroll')),
      const Offset(0, -60),
    );
    await settle(tester, total: const Duration(milliseconds: 600));
    await sheet.shot(
      tester,
      'M_journal_scrolled_more',
      at: at,
      surface: 'JOURNAL',
      note: 'scrolled further',
    );
    await tester.drag(
      find.byKey(const ValueKey('journal-nook-scroll')),
      const Offset(0, 900),
    );
    await settle(tester, total: const Duration(milliseconds: 900));
    await sheet.shot(
      tester,
      'M_journal_back',
      at: at,
      surface: 'JOURNAL',
      note: 'back at rest: the fade has let go',
    );
  });

  roomRenderTest('Plans day and week, long names', skip: !_renders, (
    tester,
  ) async {
    if (!_wants('plans')) return;
    final at = _at(6, 12, 30);
    await _boot(tester, at);
    await openTab(tester, RoomTab.plans);
    await _mode(tester, 'day');
    await sheet.shot(
      tester,
      'P_day_100',
      at: at,
      surface: 'PLANS',
      note: 'DAY, 100% text',
    );
    await _mode(tester, 'week');
    await sheet.shot(
      tester,
      'P_week_100',
      at: at,
      surface: 'PLANS',
      note: 'WEEK, 100% text',
    );
  });

  for (final scale in const [1.3, 2.0]) {
    final label = (scale * 100).round();
    roomRenderTest('Plans at $label% text', skip: !_renders, (tester) async {
      if (!_wants('plans$label')) return;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final at = _at(6, 12, 30);
      await _boot(tester, at);
      await openTab(tester, RoomTab.plans);
      await _mode(tester, 'day');
      await sheet.shot(
        tester,
        'P_day_$label',
        at: at,
        surface: 'PLANS',
        note: 'DAY, $label% text',
      );
      await _mode(tester, 'week');
      await sheet.shot(
        tester,
        'P_week_$label',
        at: at,
        surface: 'PLANS',
        note: 'WEEK, $label% text',
      );
      if (label == 130) {
        for (final tab in _tabs) {
          await openTab(tester, tab);
          await settle(tester, total: const Duration(milliseconds: 900));
          await sheet.shot(
            tester,
            'T_rest_${tab.name}',
            at: at,
            surface: tab.label,
            note: '${tab.label} at rest, 130% text',
          );
        }
      }
    });
  }
}
