// Renders Me, the mantel, with the six stats drawn out (H57), through the real
// app at iPhone size (393 x 852 at 3x, PNGs 1179 x 2556). Skipped unless asked
// for:
//
//   flutter test --dart-define=H57_RENDERS=true \
//     test/design_renders/h57_stats_render_test.dart
//
// Output: design/comparisons/2026-10-14/h57-stats/ in this checkout. Pass
// --dart-define=H57_OUT=before to write to .../h57-stats/before instead.
import 'dart:io';

import 'package:emberkeep/clock.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/class_day/doorway_art.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('H57_RENDERS');
const _sub = String.fromEnvironment('H57_OUT');

String get _out {
  final root = Directory.current.path.replaceAll(r'\', '/');
  return '$root/design/comparisons/2026-10-14/h57-stats'
      '${_sub.isEmpty ? '' : '/$_sub'}';
}

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

void _train(WidgetTester tester, {Map<Stat, int>? stats}) {
  final state = liveState(tester);
  if (stats != null) state.stats.addAll(stats);
  for (final (stat, count) in const [
    (Stat.str, 6),
    (Stat.intl, 3),
    (Stat.dis, 1),
  ]) {
    for (var i = 0; i < count; i++) {
      state.markTraining(stat, at: _at(12 + i % 2, 9 + i, 0));
    }
  }
}

// Mika's numbers from the fight spec: LV 6, STR 54, VIT 90, INT 30, FOC 23,
// SOC 5 (Call a Friend is still locked), DIS 110.
const _specStats = {
  Stat.str: 54,
  Stat.vit: 90,
  Stat.intl: 30,
  Stat.foc: 23,
  Stat.soc: 5,
  Stat.dis: 110,
};

void main() {
  setUpAll(setUpRoomRenders);
  tearDownAll(tearDownRoomRenders);
  final sheet = FrameSheet(_out);
  tearDownAll(() {
    if (_renders) sheet.writeManifest();
  });

  // Wed Oct 14 is ISO week 42 (even): the Couch Troll, weak to Strength.
  for (final (name, at, label) in [
    ('midday', _at(14, 12, 30), 'Wed Oct 14 12:30'),
    ('evening', _at(14, 21, 0), 'Wed Oct 14 21:00'),
  ]) {
    roomRenderTest('Me at $name', skip: !_renders, (tester) async {
      await _boot(tester, at);
      _train(tester);
      await openTab(tester, RoomTab.me);
      await sheet.shot(
        tester,
        'ME_stats_$name',
        at: at,
        surface: 'ME',
        note: 'the mantel with the six stats, $label',
      );
    });
  }

  roomRenderTest('Me, a quiet week', skip: !_renders, (tester) async {
    final at = _at(14, 12, 30);
    await _boot(tester, at);
    await openTab(tester, RoomTab.me);
    await sheet.shot(
      tester,
      'ME_stats_quiet',
      at: at,
      surface: 'ME',
      note: 'nothing trained yet this week, Wed Oct 14 12:30',
    );
  });

  for (final scale in [1.3, 2.0]) {
    roomRenderTest('Me at ${scale}x text', skip: !_renders, (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final at = _at(14, 12, 30);
      await _boot(tester, at);
      _train(tester);
      await openTab(tester, RoomTab.me);
      await sheet.shot(
        tester,
        'ME_stats_text${(scale * 100).round()}',
        at: at,
        surface: 'ME',
        note: 'the mantel at ${(scale * 100).round()}% text',
      );
    });
  }

  // The stat pages the rows open: the ability, the tiers, the week's boost.
  for (final (stat, name) in [
    (Stat.str, 'strength_trained'),
    (Stat.soc, 'social_locked'),
  ]) {
    roomRenderTest('Stat page $name', skip: !_renders, (tester) async {
      final at = _at(17, 11, 0);
      await _boot(tester, at);
      _train(tester, stats: _specStats);
      await openTab(tester, RoomTab.me);
      await tester.tap(find.byKey(Key('mantel-stat-${stat.name}')));
      await tester.pump();
      await settle(tester, total: const Duration(milliseconds: 1400));
      await sheet.shot(
        tester,
        'STAT_$name',
        at: at,
        surface: 'STAT',
        note: '${stat.label} page, Sat Oct 17 11:00',
      );
    });
  }

  // Mika's numbers: Social 5 is locked, the rest sit at different tiers.
  roomRenderTest('Me with the spec numbers', skip: !_renders, (tester) async {
    final at = _at(17, 11, 0); // Saturday, week 42
    await _boot(tester, at);
    _train(tester, stats: _specStats);
    await openTab(tester, RoomTab.me);
    await sheet.shot(
      tester,
      'ME_stats_spec_numbers',
      at: at,
      surface: 'ME',
      note: 'LV 6 numbers (Social locked) on Saturday Oct 17 11:00',
    );
  });
}
