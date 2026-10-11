// Renders Me, the mantel room, through the real app at iPhone size (393 x 852
// at 3x, PNGs 1179 x 2556): at rest at midday and at evening, each sheet open,
// and the large-text states. Skipped unless asked for:
//
//   flutter test --dart-define=HOUSE_ME_RENDERS=true \
//     test/design_renders/house_me_render_test.dart
//
// Output: design/comparisons/2026-10-10/house-rooms/me/ in the class-day-journey
// checkout (the sheet script puts them beside the prototype's v4 frames).
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/widgets/class_day/doorway_art.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('HOUSE_ME_RENDERS');

const _out =
    'C:/Users/mikus/Downloads/experimentProject/app/.worktrees/class-day-journey/'
    'design/comparisons/2026-10-10/house-rooms/me';

DateTime _at(int day, int hour, int minute) =>
    DateTime(2026, 10, day, hour, minute);

List<String> get _plates => {
  for (final set in [HousePlateSets.me]) ...set.all,
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

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await settle(tester, total: const Duration(milliseconds: 900));
}

void main() {
  setUpAll(setUpRoomRenders);
  tearDownAll(tearDownRoomRenders);
  final sheet = FrameSheet(_out);
  tearDownAll(() {
    if (_renders) sheet.writeManifest();
  });

  for (final (name, at, label) in [
    ('midday', _at(6, 12, 30), 'Tue Oct 6 12:30'),
    ('evening', _at(6, 21, 0), 'Tue Oct 6 21:00'),
  ]) {
    roomRenderTest('Me at $name', skip: !_renders, (tester) async {
      await _boot(tester, at);
      await openTab(tester, RoomTab.me);
      await sheet.shot(
        tester,
        'ME_rest_$name',
        at: at,
        surface: 'ME',
        note: 'the mantel at rest, $label',
      );
      for (final (key, shot) in [
        ('mantel-tab-settings', 'settings'),
        ('mantel-tab-save', 'save'),
        ('mantel-tag-trophy', 'trophy'),
        ('mantel-tab-space', 'space'),
        ('mantel-tab-more', 'more'),
      ]) {
        await _tap(tester, key);
        await sheet.shot(
          tester,
          'ME_sheet_${shot}_$name',
          at: at,
          surface: 'ME',
          note: '$shot sheet, $label',
        );
        await _tap(tester, 'mantel-sheet-close');
      }
    });
  }

  // The room arrives with its light: the glass waits for it (HouseRoomUi).
  roomRenderTest('Me arriving', skip: !_renders, (tester) async {
    final at = _at(6, 12, 30);
    await _boot(tester, at);
    for (final (name, ms) in const [('25', 215), ('mid', 430), ('75', 645)]) {
      await openTab(tester, RoomTab.quests);
      final label = find.text(RoomTab.me.label).hitTestable();
      await tester.tap(label.last);
      await tester.pump();
      var t = 0;
      while (t < ms) {
        final step = (ms - t) < 17 ? (ms - t) : 17;
        await tester.pump(Duration(milliseconds: step));
        t += step;
      }
      await sheet.shot(
        tester,
        'ME_arrive_$name',
        at: at,
        surface: 'ME',
        note: 'arriving, $ms ms',
      );
    }
  });

  for (final scale in [1.3, 2.0]) {
    roomRenderTest('Me at ${scale}x text', skip: !_renders, (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final at = _at(6, 12, 30);
      await _boot(tester, at);
      await openTab(tester, RoomTab.me);
      await sheet.shot(
        tester,
        'ME_rest_text${(scale * 100).round()}',
        at: at,
        surface: 'ME',
        note: 'the mantel at ${(scale * 100).round()}% text',
      );
      await _tap(tester, 'mantel-tab-settings');
      await sheet.shot(
        tester,
        'ME_sheet_settings_text${(scale * 100).round()}',
        at: at,
        surface: 'ME',
        note: 'settings sheet at ${(scale * 100).round()}% text',
      );
    });
  }
}
