// Frame cost of the dock's travel through the real app, in flutter_tester:
// the time each pumped frame takes to build, lay out and paint (compositing
// is built; there is no GPU here) while every room arrives. A 60 Hz frame is
// 16.7 ms. Skipped unless asked for:
//
//   flutter test --dart-define=HOUSE_RENDERS=true \
//     test/design_renders/house_travel_perf_test.dart
//
// It prints the median, 95th percentile and worst frame per arrival, and at
// rest, and asserts the arrival is not heavier than a frame budget.
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/widgets/class_day/doorway_art.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('HOUSE_RENDERS');

({double median, double p95, double worst}) _stats(List<double> ms) {
  final sorted = [...ms]..sort();
  double at(double q) => sorted[((sorted.length - 1) * q).round()];
  return (median: at(0.5), p95: at(0.95), worst: sorted.last);
}

void main() {
  setUpAll(setUpRoomRenders);
  tearDownAll(tearDownRoomRenders);

  roomRenderTest('arrivals stay inside a 60 Hz frame', skip: !_renders, (
    tester,
  ) async {
    final at = DateTime(2026, 10, 6, 12, 30);
    final account = mikaAccount(renderAt: at);
    Clock.freeze(at);
    await bootRoom(
      tester,
      account,
      schedule: mikaSchedule(),
      precache: [
        ...RoomArt.everyday,
        for (final set in [
          HousePlateSets.me,
          HousePlateSets.goals,
          HousePlateSets.plansDay,
          HousePlateSets.journal,
        ])
          ...set.all,
      ],
    );
    final context = tester.element(find.byType(MaterialApp).first);
    await tester.runAsync(() async {
      for (final asset in DoorwayAssets.all) {
        await precacheImage(DoorwayAssets.providerFor(asset), context);
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    // Visit every room once so each is built and its art is decoded.
    for (final tab in RoomTab.values) {
      await openTab(tester, tab);
    }
    await openTab(tester, RoomTab.quests);

    final results = <String, ({double median, double p95, double worst})>{};
    for (final tab in [
      RoomTab.me,
      RoomTab.goals,
      RoomTab.plans,
      RoomTab.journal,
      RoomTab.quests,
    ]) {
      final room = HouseRoom.values[tab.index];
      final origin = tab == RoomTab.quests ? RoomTab.me : RoomTab.quests;
      await openTab(tester, origin);
      await tester.tap(find.text(tab.label).hitTestable().last);
      final watch = Stopwatch();
      final frames = <double>[];
      var t = 0;
      while (t < room.arrivalMs + 100) {
        watch
          ..reset()
          ..start();
        await tester.pump(const Duration(microseconds: 16667));
        watch.stop();
        frames.add(watch.elapsedMicroseconds / 1000);
        t += 17;
      }
      results[tab.label] = _stats(frames);
      await settle(tester, total: const Duration(milliseconds: 600));
    }
    // At rest: a frame with nothing arriving.
    final rest = <double>[];
    final watch = Stopwatch();
    for (var i = 0; i < 60; i++) {
      watch
        ..reset()
        ..start();
      await tester.pump(const Duration(microseconds: 16667));
      watch.stop();
      rest.add(watch.elapsedMicroseconds / 1000);
    }
    results['rest'] = _stats(rest);
    for (final entry in results.entries) {
      final s = entry.value;
      // ignore: avoid_print
      print(
        'PERF ${entry.key.padRight(8)} median ${s.median.toStringAsFixed(2)} ms'
        '  p95 ${s.p95.toStringAsFixed(2)} ms  worst ${s.worst.toStringAsFixed(2)} ms',
      );
      expect(entry.value.median, lessThan(16.7), reason: entry.key);
      expect(entry.value.p95, lessThan(33.4), reason: entry.key);
    }
  });
}
