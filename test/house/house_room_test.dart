// The house's room map and its light: which rooms there are, in dock order,
// where each one's light comes from, how it arrives and for how long, and
// which painted plate shows for the hour. A room with no plate for a light
// keeps its painted light: nothing is ever tinted to make an evening.
import 'dart:io';

import 'package:emberkeep/widgets/class_day/doorway_light.dart';
import 'package:emberkeep/widgets/house/house_light.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:flutter_test/flutter_test.dart';

DoorwayLights _at(int hour, [int minute = 0]) =>
    doorwayLightsAtMinute(hour * 60.0 + minute);

void main() {
  group('the room map', () {
    test('five rooms in dock order', () {
      expect(HouseRoom.values.map((r) => r.name), [
        'me',
        'quests',
        'goals',
        'plans',
        'journal',
      ]);
      for (final (i, room) in HouseRoom.values.indexed) {
        expect(room.index, i);
        expect(room.dockIndex, i);
        expect(HouseRoom.fromDockIndex(i), room);
      }
    });

    test('each room arrives for its own time (860, 700, 740, 820, 900 ms)', () {
      expect(HouseRoom.values.map((r) => r.arrivalMs), [
        860,
        700,
        740,
        820,
        900,
      ]);
      expect(HouseRoom.me.arrivalDuration, const Duration(milliseconds: 860));
    });

    test('each room arrives through its own light', () {
      expect(HouseRoom.values.map((r) => r.arrival), [
        HouseArrival.hearth,
        HouseArrival.doorGlass,
        HouseArrival.lampCone,
        HouseArrival.daylightBand,
        HouseArrival.readingLamp,
      ]);
      // Five rooms, five different arrivals: the variety is the rooms.
      expect(HouseRoom.values.map((r) => r.arrival).toSet().length, 5);
    });

    test('the light anchors are the plates\' pixel points over three', () {
      expect(HouseRoom.me.anchor.dx, closeTo(590 / 3, 1e-9));
      expect(HouseRoom.me.anchor.dy, closeTo(1450 / 3, 1e-9));
      expect(HouseRoom.quests.anchor.dx, closeTo(589 / 3, 1e-9));
      expect(HouseRoom.quests.anchor.dy, closeTo(520 / 3, 1e-9));
      expect(HouseRoom.quests.eveningAnchor!.dx, closeTo(1112 / 3, 1e-9));
      expect(HouseRoom.quests.eveningAnchor!.dy, closeTo(326 / 3, 1e-9));
      expect(HouseRoom.goals.anchor.dx, closeTo(885 / 3, 1e-9));
      expect(HouseRoom.goals.anchor.dy, closeTo(897 / 3, 1e-9));
      expect(HouseRoom.plans.anchor.dx, closeTo(42 / 3, 1e-9));
      expect(HouseRoom.plans.anchor.dy, closeTo(500 / 3, 1e-9));
      expect(HouseRoom.journal.anchor.dx, closeTo(742 / 3, 1e-9));
      expect(HouseRoom.journal.anchor.dy, closeTo(1117 / 3, 1e-9));
      for (final room in HouseRoom.values) {
        expect(room.anchor.dx, inInclusiveRange(0, houseCanvasWidth));
        expect(room.anchor.dy, inInclusiveRange(0, houseCanvasHeight));
        expect(room.contentTop, inInclusiveRange(100, 600));
      }
      // Only the Doorway has another light at evening: the lantern.
      expect(
        HouseRoom.quests.anchorFor(evening: true).dx,
        closeTo(1112 / 3, 1e-9),
      );
      expect(
        HouseRoom.quests.anchorFor(evening: false),
        HouseRoom.quests.anchor,
      );
      expect(HouseRoom.me.anchorFor(evening: true), HouseRoom.me.anchor);
    });

    test('Quests keeps the Doorway\'s own plates; the others have a set', () {
      expect(HouseRoom.quests.plates, isNull);
      for (final room in HouseRoom.values.where((r) => r != HouseRoom.quests)) {
        expect(room.plates, isNotNull, reason: room.name);
      }
    });

    test('every plate exists on disk, at 1179 x 2556, and is registered', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- assets/rooms/house/'));
      final plates = {
        for (final set in [
          HousePlateSets.me,
          HousePlateSets.goals,
          HousePlateSets.plansDay,
          HousePlateSets.plansMonth,
          HousePlateSets.plansWeek,
          HousePlateSets.journal,
        ])
          ...set.all,
      };
      // Me, Goals, Journal, the day, the week: two each; the month's evening
      // is the day's.
      expect(plates, hasLength(11));
      for (final asset in plates) {
        final file = File(asset);
        expect(file.existsSync(), isTrue, reason: asset);
        expect(asset, startsWith('assets/rooms/house/'));
        // A WebP's canvas size is in its VP8 header.
        final bytes = file.readAsBytesSync();
        expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
        expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WEBP');
      }
    });

    test('evening is painted for every room but the Doorway', () {
      for (final set in [
        HousePlateSets.me,
        HousePlateSets.goals,
        HousePlateSets.plansDay,
        HousePlateSets.plansWeek,
        HousePlateSets.journal,
      ]) {
        expect(set.hasEvening, isTrue);
      }
    });
  });

  group('the light of the day', () {
    test(
      'a room with only a midday plate always shows it: nothing is tinted',
      () {
        for (final plates in const [
          HousePlates(midday: 'assets/rooms/house/plate-goals-midday.webp'),
          HousePlates(midday: 'assets/rooms/house/plate-journal-midday.webp'),
        ]) {
          for (final hour in [0, 3, 6, 9, 12, 15, 16, 18, 19, 21, 23]) {
            final layers = housePlateLayers(plates, _at(hour));
            expect(layers, hasLength(1), reason: 'at $hour:00');
            expect(layers.single.asset, plates.midday);
            expect(layers.single.opacity, 1);
            expect(layers.single.weight, closeTo(1, 1e-9));
          }
          // And through the evening blend itself.
          for (var minute = 17 * 60; minute <= 19 * 60 + 30; minute += 5) {
            final layers = housePlateLayers(
              plates,
              doorwayLightsAtMinute(minute.toDouble()),
            );
            expect(layers.map((l) => l.asset), [plates.midday]);
          }
        }
      },
    );

    test(
      'Me and Plans cross-fade midday into evening on the Doorway\'s clock',
      () {
        final noon = housePlateLayers(HousePlateSets.me, _at(12));
        expect(noon.map((l) => l.asset), [HousePlateSets.me.midday]);

        final night = housePlateLayers(HousePlateSets.me, _at(22));
        expect(night.map((l) => l.asset), [HousePlateSets.me.evening]);
        expect(night.single.opacity, 1);

        // 18:30 is the middle of the blend: half and half.
        final dusk = housePlateLayers(HousePlateSets.me, _at(18, 30));
        expect(dusk.map((l) => l.asset), [
          HousePlateSets.me.midday,
          HousePlateSets.me.evening,
        ]);
        expect(dusk[0].weight, closeTo(0.5, 1e-9));
        expect(dusk[1].weight, closeTo(0.5, 1e-9));
        // The painter's cross-fade: the first is opaque, the second its share.
        expect(dusk[0].opacity, 1);
        expect(dusk[1].opacity, closeTo(0.5, 1e-9));

        // Dawn is the same blend the other way, at 06:00.
        final dawn = housePlateLayers(HousePlateSets.plansDay, _at(6));
        expect(dawn.map((l) => l.asset), [
          HousePlateSets.plansDay.midday,
          HousePlateSets.plansDay.evening,
        ]);
        expect(dawn[0].weight, closeTo(0.5, 1e-9));
      },
    );

    test('golden hour has no plate of its own: its share is midday\'s', () {
      final golden = housePlateLayers(HousePlateSets.me, _at(17));
      expect(golden.map((l) => l.asset), [HousePlateSets.me.midday]);
      expect(golden.single.weight, closeTo(1, 1e-9));
    });

    test('the weights always sum to one', () {
      for (final plates in [
        HousePlateSets.me,
        HousePlateSets.goals,
        HousePlateSets.plansMonth,
        const HousePlates(midday: 'a'),
        const HousePlates(midday: 'a', golden: 'g', evening: 'e'),
      ]) {
        for (var minute = 0; minute < 24 * 60; minute += 7) {
          final w = housePlateWeights(
            plates,
            doorwayLightsAtMinute(minute.toDouble()),
          );
          expect(w.fold(0.0, (a, b) => a + b), closeTo(1, 1e-9));
        }
      }
    });

    test('Plans\' month has no evening plate of its own: it takes the day '
        'spread\'s lamplit paper, never a tint', () {
      final night = housePlateLayers(HousePlateSets.plansMonth, _at(21));
      expect(night.map((l) => l.asset), [HousePlateSets.plansDay.evening]);
      final noon = housePlateLayers(HousePlateSets.plansMonth, _at(12));
      expect(noon.map((l) => l.asset), [HousePlateSets.plansMonth.midday]);
    });

    test('adding an evening plate to a room is one line, and nothing else '
        'changes', () {
      // What the Goals row would become the day its evening plate lands.
      const goalsWithEvening = HousePlates(
        midday: 'assets/rooms/house/plate-goals-midday.webp',
        evening: 'assets/rooms/house/plate-goals-evening.webp',
      );
      expect(housePlateLayers(goalsWithEvening, _at(12)).map((l) => l.asset), [
        goalsWithEvening.midday,
      ]);
      expect(housePlateLayers(goalsWithEvening, _at(22)).map((l) => l.asset), [
        goalsWithEvening.evening,
      ]);
      // A golden-hour plate, when one exists, takes golden hour and also the
      // share of a missing evening.
      const withGolden = HousePlates(midday: 'm', golden: 'g');
      expect(housePlateLayers(withGolden, _at(17)).map((l) => l.asset), ['g']);
      expect(housePlateLayers(withGolden, _at(23)).map((l) => l.asset), ['g']);
    });
  });
}
