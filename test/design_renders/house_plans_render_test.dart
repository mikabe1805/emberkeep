// Renders the Plans room through the real app at iPhone size (393 x 852 at 3x,
// PNGs 1179 x 2556): a Tuesday with Mika's real classes in the day, the week
// and the month, the evening, a page turn caught in the middle, the large text
// and Reduce Motion states. Skipped unless asked for:
//
//   flutter test --dart-define=PLANS_RENDERS=true \
//     test/design_renders/house_plans_render_test.dart
//
// Output: design/comparisons/2026-10-10/house-rooms/plans/ in the
// class-day-journey checkout. `PLANS_ONLY=name,name` limits the frames.
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/widgets/class_day/doorway_art.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('PLANS_RENDERS');
const _only = String.fromEnvironment('PLANS_ONLY');
bool _wants(String name) =>
    _only.isEmpty || _only.split(',').map((s) => s.trim()).contains(name);

const _out =
    'C:/Users/mikus/Downloads/experimentProject/app/.worktrees/class-day-journey/'
    'design/comparisons/2026-10-10/house-rooms/plans';

DateTime _at(int day, int hour, int minute) =>
    DateTime(2026, 10, day, hour, minute);

final _schedule = mikaSchedule();

List<String> get _plates => {
  for (final set in [HousePlateSets.plansDay, HousePlateSets.plansMonth])
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

Future<void> _tab(WidgetTester tester, String date) async {
  await tester.tap(find.byKey(ValueKey('daybook-day-control-$date')));
  await tester.pump();
}

void main() {
  setUpAll(setUpRoomRenders);
  tearDownAll(tearDownRoomRenders);
  final sheet = FrameSheet(_out);
  tearDownAll(() {
    if (_renders) sheet.writeManifest();
  });

  // Tuesday 6 October 2026 at 12:30: between his two classes, midday light.
  roomRenderTest('the daybook at midday', skip: !_renders, (tester) async {
    final at = _at(6, 12, 30);
    await _boot(tester, at);
    await openTab(tester, RoomTab.plans);

    if (_wants('day')) {
      await _mode(tester, 'day');
      await sheet.shot(
        tester,
        'P_day_tue',
        at: at,
        surface: 'Plans',
        note: 'DAY, Tuesday with his real classes',
      );
    }
    if (_wants('turn')) {
      await _mode(tester, 'day');
      await _tab(tester, '2026-10-07');
      await tester.pump(const Duration(milliseconds: 300));
      // ignore: avoid_print
      for (final t in ['Today', 'Wednesday']) {
        for (final o
            in find
                .ancestor(of: find.text(t), matching: find.byType(Opacity))
                .evaluate()) {
          // ignore: avoid_print
          print('OPACITY $t ${(o.widget as Opacity).opacity}');
        }
      }
      // ignore: avoid_print
      print(
        'CURLS ${find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == 'PlansCurlPainter').evaluate().length}',
      );
      await sheet.shot(
        tester,
        'P_turn_mid',
        at: at,
        surface: 'Plans',
        note: 'DAY, page turning from Tuesday to Wednesday, 300 ms',
      );
      await settle(tester, total: const Duration(milliseconds: 900));
      await sheet.shot(
        tester,
        'P_day_wed',
        at: at,
        surface: 'Plans',
        note: 'DAY, Wednesday',
      );
    }
    if (_wants('week')) {
      await _mode(tester, 'week');
      await sheet.shot(
        tester,
        'P_week',
        at: at,
        surface: 'Plans',
        note: 'WEEK, seven columns on the day plate',
      );
    }
    if (_wants('month')) {
      await _mode(tester, 'month');
      await sheet.shot(
        tester,
        'P_month',
        at: at,
        surface: 'Plans',
        note: 'MONTH',
      );
    }
    if (_wants('view-turn')) {
      await _mode(tester, 'day');
      await tester.tap(find.byKey(const ValueKey('academic-mode-month')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 310));
      await sheet.shot(
        tester,
        'P_view_turn_mid',
        at: at,
        surface: 'Plans',
        note: 'DAY to MONTH, 310 ms into the turn',
      );
    }
  });

  roomRenderTest('the daybook in the evening', skip: !_renders, (tester) async {
    final at = _at(6, 20, 30);
    await _boot(tester, at);
    await openTab(tester, RoomTab.plans);
    if (_wants('evening')) {
      await _mode(tester, 'day');
      await _tab(tester, '2026-10-07');
      await settle(tester, total: const Duration(milliseconds: 900));
      await sheet.shot(
        tester,
        'P_evening_day',
        at: at,
        surface: 'Plans',
        note: 'DAY at evening, Wednesday, the painted evening plate',
      );
    }
    if (_wants('evening-month')) {
      await _mode(tester, 'month');
      await sheet.shot(
        tester,
        'P_evening_month',
        at: at,
        surface: 'Plans',
        note: 'MONTH at evening',
      );
    }
  });

  roomRenderTest('large text', skip: !_renders, (tester) async {
    final at = _at(6, 12, 30);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _boot(tester, at);
    await openTab(tester, RoomTab.plans);
    if (_wants('large')) {
      await _mode(tester, 'day');
      await sheet.shot(
        tester,
        'P_large_day',
        at: at,
        surface: 'Plans',
        note: 'DAY at 200% text',
      );
      await _mode(tester, 'month');
      await sheet.shot(
        tester,
        'P_large_month',
        at: at,
        surface: 'Plans',
        note: 'MONTH at 200% text',
      );
      await _mode(tester, 'week');
      await sheet.shot(
        tester,
        'P_large_week',
        at: at,
        surface: 'Plans',
        note: 'WEEK at 200% text',
      );
    }
  });
}
