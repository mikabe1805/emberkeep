// How each room's light arrives, checked as data at the key points: a reveal
// grown from the room's own light over a dissolve, with a faint glow along its
// edge. Nothing here paints; the masks report their own alpha.
import 'dart:ui';

import 'package:emberkeep/widgets/class_day/doorway_light.dart';
import 'package:emberkeep/widgets/house/house_arrival.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:emberkeep/widgets/house/house_travel_model.dart';
import 'package:flutter_test/flutter_test.dart';

HouseArrivalFrame _at(HouseRoom room, double g, {DoorwayLights? lights}) =>
    houseArrivalFrame(room, g, timeMs: 400, lights: lights);

/// A grid of canvas points.
Iterable<Offset> _grid() sync* {
  for (var x = 8.0; x < houseCanvasWidth; x += 38) {
    for (var y = 8.0; y < houseCanvasHeight; y += 42) {
      yield Offset(x, y);
    }
  }
}

double _glowPeak(HouseArrivalFrame f) =>
    _grid().map(f.glowAt).fold(0.0, (a, b) => a > b ? a : b);

void main() {
  group('every arrival', () {
    for (final room in HouseRoom.values) {
      test('${room.name}: starts hidden, ends whole, never goes backward', () {
        // Nothing of the room shows before its light arrives, away from it.
        final start = _at(room, 0);
        final far = [const Offset(380, 30), const Offset(30, 60)];
        for (final p in far) {
          expect(start.maskAt(p), lessThan(0.03), reason: '${room.name} $p');
        }
        // Whole at the end, everywhere.
        final end = _at(room, 1);
        for (final p in _grid()) {
          expect(end.maskAt(p), closeTo(1, 1e-6), reason: '${room.name} $p');
        }
        // The reveal only grows (the dissolve under it and the light on it):
        // at each point the room is never less there than a moment before.
        for (final p in _grid()) {
          var before = 0.0;
          for (var g = 0.0; g <= 1.0001; g += 0.05) {
            final a = _at(room, g).maskAt(p);
            expect(
              a,
              greaterThanOrEqualTo(before - 0.02),
              reason: '${room.name} at $p, g=${g.toStringAsFixed(2)}',
            );
            before = a;
          }
        }
      });

      test('${room.name}: a faint glow along the edge, none at either end', () {
        expect(_glowPeak(_at(room, 0)), lessThan(0.05));
        expect(_glowPeak(_at(room, 1)), lessThan(0.05));
        final mid = _glowPeak(_at(room, 0.5));
        if (houseGlowGain == 0) {
          // Off to match the approved prototype v4, where the glow never showed.
          expect(mid, 0, reason: 'the glow is switched off');
          return;
        }
        expect(mid, greaterThan(0.05), reason: 'a glow shows mid-arrival');
        // Faint, never a wash: no single glow layer is above 0.9.
        for (var g = 0.0; g <= 1.0; g += 0.1) {
          expect(_glowPeak(_at(room, g)), lessThan(0.95));
        }
      });
    }
  });

  group('the five lights', () {
    test('ME: the hearth first, the room rises in firelight from the bottom '
        'up', () {
      final hearth = HouseRoom.me.anchor;
      final early = _at(HouseRoom.me, 0.12);
      expect(early.maskAt(hearth), greaterThan(0.95));
      // Embers: the room around the hearth is still dark high up.
      expect(early.maskAt(const Offset(200, 60)), lessThan(0.05));
      // The rise: the bottom of the screen is lit before the top of it.
      final half = _at(HouseRoom.me, 0.55);
      expect(
        half.maskAt(const Offset(60, 800)),
        greaterThan(half.maskAt(const Offset(60, 120))),
      );
      expect(half.maskAt(const Offset(60, 800)), greaterThan(0.9));
      // The tapestry above the mantel catches the light last: its glow
      // peaks late, after the embers have gone.
      final tapestry = const Offset(196, 222);
      expect(_at(HouseRoom.me, 0.2).glowAt(tapestry), lessThan(0.1));
      expect(
        _at(HouseRoom.me, 0.78).glowAt(tapestry),
        greaterThan(_at(HouseRoom.me, 0.2).glowAt(tapestry)),
      );
      // The embers' own glow, orange, at the hearth, early.
      expect(_at(HouseRoom.me, 0.3).glowAt(hearth), greaterThan(0.15));
    });

    test('QUESTS: day-glow blooms from the panes, outward and downward', () {
      final panes = HouseRoom.quests.anchor;
      final early = _at(HouseRoom.quests, 0.1);
      expect(early.maskAt(panes), greaterThan(0.95));
      expect(early.maskAt(const Offset(60, 700)), lessThan(0.05));
      // The hall resolves out of the brightness: taller than wide.
      final mid = _at(HouseRoom.quests, 0.25);
      expect(
        mid.maskAt(Offset(panes.dx, panes.dy + 200)),
        greaterThan(mid.maskAt(Offset(panes.dx + 200, panes.dy)) + 0.2),
      );
    });

    test('QUESTS: at evening the light is the lantern, and it is amber', () {
      final evening = doorwayLightsAtMinute(22 * 60);
      final day = _at(HouseRoom.quests, 0.5);
      final night = _at(HouseRoom.quests, 0.5, lights: evening);
      final lantern = HouseRoom.quests.eveningAnchor!;
      // The reveal is centred on the lantern at night, the door glass by day.
      expect(
        night.maskAt(Offset(lantern.dx, lantern.dy + 60)),
        greaterThan(day.maskAt(Offset(lantern.dx, lantern.dy + 60)) - 0.5),
      );
      expect(night.mask.first, isA<HouseRadial>());
      expect((night.mask.first as HouseRadial).center, lantern);
      expect((day.mask.first as HouseRadial).center, HouseRoom.quests.anchor);
      // The glow takes the amber of the lantern, the gold of day otherwise.
      final nightGlow = night.glow.first.stops.map((s) => s.color).toList();
      final dayGlow = day.glow.first.stops.map((s) => s.color).toList();
      expect(nightGlow[1].g, lessThan(dayGlow[1].g));
    });

    test('GOALS: a cone opens downward and outward from the lamp', () {
      final lamp = HouseRoom.goals.anchor;
      final early = _at(HouseRoom.goals, 0.08);
      expect(early.maskAt(lamp), greaterThan(0.95));
      // Straight down the cone is revealed before the sides and the top.
      final mid = _at(HouseRoom.goals, 0.4);
      final below = mid.maskAt(Offset(lamp.dx, lamp.dy + 250));
      final above = mid.maskAt(Offset(lamp.dx, lamp.dy - 200));
      final side = mid.maskAt(Offset(lamp.dx - 250, lamp.dy));
      expect(below, greaterThan(above));
      expect(below, greaterThan(side));
      // Its click: a bright point at the lamp itself, early.
      expect(_at(HouseRoom.goals, 0.05).glowAt(lamp), greaterThan(0.2));
      expect(_at(HouseRoom.goals, 0.95).glowAt(lamp), lessThan(0.05));
      // The cone widens.
      final narrow = _at(HouseRoom.goals, 0.15);
      final wide = _at(HouseRoom.goals, 0.6);
      final off = Offset(lamp.dx - 120, lamp.dy + 120);
      expect(wide.maskAt(off), greaterThan(narrow.maskAt(off)));
    });

    test(
      'PLANS: a vertical band of daylight sweeps in from the window side',
      () {
        final early = _at(HouseRoom.plans, 0.3);
        expect(early.maskAt(const Offset(14, 400)), greaterThan(0.95));
        expect(early.maskAt(const Offset(380, 400)), lessThan(0.15));
        // It is a band: the same at any height.
        expect(
          early.maskAt(const Offset(60, 100)),
          closeTo(early.maskAt(const Offset(60, 700)), 1e-9),
        );
        // It crosses the screen: the glow's centre moves right.
        double centreOf(HouseArrivalFrame f) {
          var best = 0.0;
          var at = 0.0;
          for (var x = 0.0; x <= houseCanvasWidth; x += 3) {
            final a = f.glowAt(Offset(x, 300));
            if (a > best) {
              best = a;
              at = x;
            }
          }
          return at;
        }

        expect(
          centreOf(_at(HouseRoom.plans, 0.7)),
          greaterThan(centreOf(_at(HouseRoom.plans, 0.35))),
        );
      },
    );

    test('PLANS: the band is amber at evening, pale daylight otherwise', () {
      final day = _at(HouseRoom.plans, 0.4);
      final night = _at(
        HouseRoom.plans,
        0.4,
        lights: doorwayLightsAtMinute(22 * 60),
      );
      expect(
        night.glow.first.stops[1].color.g,
        lessThan(day.glow.first.stops[1].color.g),
      );
    });

    test(
      'JOURNAL: the calmest arrival, a slow radial rise around the lamp',
      () {
        final lamp = HouseRoom.journal.anchor;
        final early = _at(HouseRoom.journal, 0.1);
        expect(early.maskAt(lamp), greaterThan(0.95));
        expect(early.maskAt(const Offset(40, 800)), lessThan(0.05));
        // Radial: the same distance from the lamp, the same reveal.
        final mid = _at(HouseRoom.journal, 0.5);
        expect(
          mid.maskAt(Offset(lamp.dx + 120, lamp.dy)),
          closeTo(mid.maskAt(Offset(lamp.dx, lamp.dy + 120)), 1e-6),
        );
        // Calm: its glow is the gentlest of the five.
        final peaks = {
          for (final room in HouseRoom.values)
            room: [
              for (var g = 0.1; g < 1; g += 0.1) _glowPeak(_at(room, g)),
            ].reduce((a, b) => a > b ? a : b),
        };
        final journalPeak = peaks[HouseRoom.journal]!;
        for (final room in HouseRoom.values) {
          expect(
            journalPeak,
            lessThanOrEqualTo(peaks[room]!),
            reason: room.name,
          );
        }
      },
    );
  });

  group('the progress a light is fed', () {
    test('is nearly linear in time, with a touch of the easing', () {
      expect(houseLightProgress(0), 0);
      expect(houseLightProgress(1), closeTo(1, 1e-9));
      expect(houseLightProgress(0.5), closeTo(0.5, 0.06));
      var before = 0.0;
      for (var p = 0.0; p <= 1.0; p += 0.02) {
        final g = houseLightProgress(p);
        expect(g, greaterThanOrEqualTo(before));
        before = g;
      }
    });
  });

  group('the gradients', () {
    test('a mask can be turned into shaders', () {
      for (final room in HouseRoom.values) {
        final frame = _at(room, 0.5);
        for (final g in [...frame.mask, ...frame.glow]) {
          expect(g.shader(1), isA<Shader>());
          expect(g.shader(2.5), isA<Shader>());
        }
      }
    });

    test('stops never go backwards (a later stop is clamped to the one '
        'before)', () {
      final conic = HouseConic(
        center: Offset.zero,
        stops: const [
          HouseStop(0, Color(0xFF000000)),
          HouseStop(200, Color(0x00000000)),
          HouseStop(100, Color(0xFF000000)),
        ],
      );
      expect(conic.stops.map((s) => s.at), [0, 200, 200]);
    });
  });
}
