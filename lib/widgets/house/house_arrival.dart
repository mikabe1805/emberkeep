// How each room's light arrives: five recipes, as data.
//
// Ported from the approved prototype (v4, the 'house' section of its main.js).
// An arrival is two stacks of gradients over the 393 x 852 pt canvas:
//
//   mask  a soft-edged reveal grown from the room's light, in black. Where it
//         is opaque the arriving room shows; its far field is the plain
//         cross-dissolve's own alpha, so the reveal rides on a dissolve.
//   glow  a faint glow in that light's own colour along the mask's edge,
//         screened over the picture. It is the light arriving, not a tint
//         over the room.
//
// Both are plain gradient descriptions (radial, linear, conic), never blur, and
// each can report its own alpha at a point, so an arrival can be checked at
// any moment without painting it. The widgets paint the same descriptions.
//
// `g` is the arrival's progress as the prototype feeds it to the recipes
// (almost linear in time: 88% of the progress plus 12% of its easing).
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../class_day/doorway_light.dart';
import 'house_room.dart';

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Smoothstep of [t] clamped to 0..1.
double houseSmoothstep(double t) {
  final c = _clamp01(t);
  return c * c * (3 - 2 * c);
}

/// A gradient stop: [at] is in the gradient's own unit (a fraction of the
/// radius for a radial, degrees for a conic, points along the line for a
/// linear) and [color] carries the stop's alpha.
final class HouseStop {
  const HouseStop(this.at, this.color);

  final double at;
  final ui.Color color;
}

/// Stop positions never go backwards (CSS clamps a stop up to the one before).
List<HouseStop> _monotone(List<HouseStop> stops) {
  final out = <HouseStop>[];
  var floor = double.negativeInfinity;
  for (final stop in stops) {
    final at = stop.at < floor ? floor : stop.at;
    floor = at;
    out.add(HouseStop(at, stop.color));
  }
  return List.unmodifiable(out);
}

/// One gradient of an arrival, in canvas points.
sealed class HouseGradient {
  HouseGradient({required List<HouseStop> stops}) : stops = _monotone(stops);

  final List<HouseStop> stops;

  /// The gradient's parameter at [p] (in the unit of the stops).
  double parameterAt(ui.Offset p);

  /// The gradient's alpha (0..1) at [p].
  double alphaAt(ui.Offset p) {
    final t = parameterAt(p);
    final first = stops.first;
    if (t <= first.at) return first.color.a;
    for (var i = 1; i < stops.length; i++) {
      final a = stops[i - 1];
      final b = stops[i];
      if (t < b.at) {
        final span = b.at - a.at;
        if (span <= 0) return b.color.a;
        return _lerp(a.color.a, b.color.a, (t - a.at) / span);
      }
    }
    return stops.last.color.a;
  }

  /// A shader for the gradient with every canvas point worth [scale] units
  /// (the pixels per canvas point of the surface it paints on).
  ui.Shader shader([double scale = 1]);

  /// Colours and unit positions (0..1) for a shader whose line is scaled by
  /// the returned `extent`: stops past the end stretch the line, stops before
  /// the start move its origin back.
  ({List<ui.Color> colors, List<double> positions, double lo, double hi})
  _unit({required double nativeLo, required double nativeHi}) {
    final lo = math.min(nativeLo, stops.first.at);
    final hi = math.max(nativeHi, stops.last.at);
    final span = hi - lo <= 0 ? 1.0 : hi - lo;
    final colors = <ui.Color>[];
    final positions = <double>[];
    for (final stop in stops) {
      colors.add(stop.color);
      positions.add(((stop.at - lo) / span).clamp(0.0, 1.0));
    }
    return (colors: colors, positions: positions, lo: lo, hi: hi);
  }
}

/// A radial (circle when [rx] equals [ry]) gradient: stops are fractions of
/// the radius; the last colour continues beyond it.
final class HouseRadial extends HouseGradient {
  HouseRadial({
    required this.center,
    required this.rx,
    required this.ry,
    required super.stops,
  });

  final ui.Offset center;
  final double rx;
  final double ry;

  @override
  double parameterAt(ui.Offset p) {
    final dx = (p.dx - center.dx) / math.max(rx, 0.0001);
    final dy = (p.dy - center.dy) / math.max(ry, 0.0001);
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  ui.Shader shader([double scale = 1]) {
    final u = _unit(nativeLo: 0, nativeHi: 1);
    final radius = math.max(rx, 0.0001) * u.hi * scale;
    final c = center * scale;
    // Scale about the centre so the circle becomes the ellipse.
    final k = ry / math.max(rx, 0.0001);
    final matrix = Float64List.fromList([
      1, 0, 0, 0, //
      0, k, 0, 0,
      0, 0, 1, 0,
      0, c.dy * (1 - k), 0, 1,
    ]);
    return ui.Gradient.radial(
      c,
      radius,
      u.colors,
      u.positions,
      ui.TileMode.clamp,
      matrix,
    );
  }
}

/// A linear gradient along [direction] (a unit vector) from [origin]: stops
/// are points along it.
final class HouseLinear extends HouseGradient {
  HouseLinear({
    required this.origin,
    required this.direction,
    required super.stops,
  });

  /// Upward from the bottom edge of a canvas [height] points tall (CSS 0deg).
  factory HouseLinear.up({
    required double height,
    required List<HouseStop> stops,
  }) => HouseLinear(
    origin: ui.Offset(0, height),
    direction: const ui.Offset(0, -1),
    stops: stops,
  );

  /// Rightward from the left edge (CSS 90deg).
  factory HouseLinear.right({required List<HouseStop> stops}) => HouseLinear(
    origin: ui.Offset.zero,
    direction: const ui.Offset(1, 0),
    stops: stops,
  );

  final ui.Offset origin;
  final ui.Offset direction;

  @override
  double parameterAt(ui.Offset p) {
    final d = p - origin;
    return d.dx * direction.dx + d.dy * direction.dy;
  }

  @override
  ui.Shader shader([double scale = 1]) {
    final u = _unit(nativeLo: 0, nativeHi: 0);
    final from = (origin + direction * u.lo) * scale;
    final to = (origin + direction * (u.hi <= u.lo ? u.lo + 1 : u.hi)) * scale;
    return ui.Gradient.linear(from, to, u.colors, u.positions);
  }
}

/// A conic gradient (CSS `conic-gradient(from 0deg at ...)`): stops are
/// degrees clockwise from straight up.
final class HouseConic extends HouseGradient {
  HouseConic({required this.center, required super.stops});

  final ui.Offset center;

  @override
  double parameterAt(ui.Offset p) {
    final d = p - center;
    var deg = math.atan2(d.dx, -d.dy) * 180 / math.pi;
    if (deg < 0) deg += 360;
    return deg;
  }

  @override
  ui.Shader shader([double scale = 1]) {
    final u = _unit(nativeLo: 0, nativeHi: 360);
    return ui.Gradient.sweep(
      center * scale,
      u.colors,
      u.positions,
      ui.TileMode.clamp,
      -math.pi / 2,
      3 * math.pi / 2,
    );
  }
}

/// One moment of an arrival: the reveal mask and the glow along its edge.
final class HouseArrivalFrame {
  const HouseArrivalFrame({required this.mask, required this.glow});

  /// Black gradients whose union is the reveal (alpha 1 where the arriving
  /// room shows fully).
  final List<HouseGradient> mask;

  /// The light's own colour along the edge, first on top, screened over the
  /// picture.
  final List<HouseGradient> glow;

  /// How much of the arriving room shows at [p]: the union of the mask layers.
  double maskAt(ui.Offset p) {
    var rest = 1.0;
    for (final layer in mask) {
      rest *= 1 - layer.alphaAt(p);
    }
    return 1 - rest;
  }

  /// The strongest glow alpha any glow layer has at [p].
  double glowAt(ui.Offset p) {
    var peak = 0.0;
    for (final layer in glow) {
      peak = math.max(peak, layer.alphaAt(p));
    }
    return peak;
  }
}

ui.Color _black(double alpha) =>
    ui.Color.fromRGBO(0, 0, 0, _clamp01(alpha).toDouble());

/// How much of each glow recipe's strength shows. The glow is the light
/// arriving along the reveal's edge, faint: the plates already paint their own
/// lamps, firelight and sun, and a strong glow over them reads as a wash.
const double houseGlowGain =
    0.0; // 0 matches the approved prototype v4, where the glow layer never showed; raise only with Mika's okay

ui.Color _rgba(List<int> c, double alpha) => ui.Color.fromRGBO(
  c[0],
  c[1],
  c[2],
  _clamp01(alpha * houseGlowGain).toDouble(),
);

const _opaque = ui.Color(0xFF000000);

/// The arrival of [room]'s light at progress [g] (0..1), at [timeMs] on the
/// travel clock (the hearth's flicker reads it).
///
/// [lights] is the real light of the day: Quests' light comes from the
/// lantern at evening and a warmer gold in the golden hour; Plans' band turns
/// amber at evening. [canvasHeight] is the screen's height in canvas points
/// (852 on the phone the plates were painted for).
HouseArrivalFrame houseArrivalFrame(
  HouseRoom room,
  double g, {
  double timeMs = 0,
  DoorwayLights? lights,
  double canvasHeight = houseCanvasHeight,
}) {
  final evening = (lights?.evening ?? 0) > 0.5;
  final golden = (lights?.golden ?? 0) > 0.5;
  return switch (room.arrival) {
    HouseArrival.hearth => _hearth(room, g, timeMs, canvasHeight),
    HouseArrival.doorGlass => _doorGlass(room, g, evening, golden),
    HouseArrival.lampCone => _lampCone(room, g),
    HouseArrival.daylightBand => _daylightBand(g, evening),
    HouseArrival.readingLamp => _readingLamp(room, g),
  };
}

/// ME: embers first, then the room rises in firelight from the bottom up, the
/// tapestry last.
HouseArrivalFrame _hearth(HouseRoom room, double e, double t, double height) {
  final hx = room.anchor.dx;
  final hy = room.anchor.dy;
  final emb = houseSmoothstep(e / 0.34);
  final rise = houseSmoothstep((e - 0.18) / 0.74);
  final d = houseSmoothstep((e - 0.4) / 0.6);
  final fl = 1 + 0.07 * math.sin(t / 83) + 0.05 * math.sin(t / 37 + 1.3);
  final rr = _lerp(4, 44, emb) + rise * 95;
  const soft = 90.0;
  final h = _lerp(-110, height + soft, rise);
  final mask = <HouseGradient>[
    HouseRadial(
      center: ui.Offset(hx, hy),
      rx: rr * 1.3,
      ry: rr,
      stops: [
        const HouseStop(0, _opaque),
        HouseStop(0.38, _black(0.55)),
        HouseStop(1, _black(0)),
      ],
    ),
    HouseLinear.up(
      height: height,
      stops: [
        const HouseStop(0, _opaque),
        HouseStop(h, _opaque),
        HouseStop(h + soft, _black(d)),
        HouseStop(math.max(height, h + soft), _black(d)),
      ],
    ),
  ];
  final tp =
      houseSmoothstep((e - 0.6) / 0.26) *
      (1 - houseSmoothstep((e - 0.92) / 0.08));
  final fade = 1 - houseSmoothstep((e - 0.82) / 0.18);
  const ember = [255, 150, 70];
  final glow = <HouseGradient>[
    // The tapestry above the mantel catches the light last.
    HouseRadial(
      center: const ui.Offset(196, 222),
      rx: 120,
      ry: 90,
      stops: [
        HouseStop(0, _rgba(const [255, 196, 116], 0.42 * tp)),
        HouseStop(1, _rgba(const [255, 170, 90], 0)),
      ],
    ),
    // The rising edge of firelight.
    HouseLinear.up(
      height: height,
      stops: [
        HouseStop(0, _rgba(ember, 0)),
        HouseStop(math.max(0, h - 80), _rgba(ember, 0)),
        HouseStop(
          h,
          _rgba(const [255, 158, 76], 0.24 * math.sin(math.pi * rise)),
        ),
        HouseStop(h + 54, _rgba(ember, 0)),
      ],
    ),
    // The embers themselves.
    HouseRadial(
      center: ui.Offset(hx, hy),
      rx: 70 + rr * 1.9,
      ry: 55 + rr * 1.4,
      stops: [
        HouseStop(
          0,
          _rgba(const [
            255,
            140,
            58,
          ], 0.5 * math.min(1, emb * 1.25) * fl * (1 - 0.45 * rise) * fade),
        ),
        HouseStop(0.52, _rgba(const [255, 120, 40], 0.24 * fl * fade * emb)),
        HouseStop(1, _rgba(const [255, 110, 30], 0)),
      ],
    ),
  ];
  return HouseArrivalFrame(mask: mask, glow: glow);
}

/// QUESTS: day-glow blooms from the panes; the hall resolves out of the
/// brightness, outward and downward.
HouseArrivalFrame _doorGlass(
  HouseRoom room,
  double e,
  bool evening,
  bool golden,
) {
  final at = room.anchorFor(evening: evening);
  final colour = evening
      ? const [255, 188, 104]
      : (golden ? const [255, 222, 160] : const [255, 242, 206]);
  final d = houseSmoothstep((e - 0.12) / 0.88);
  final r = _lerp(16, 720, math.pow(e.clamp(0.0, 1.0), 0.85).toDouble());
  final fe = 24 + r * 0.34;
  final s1 = math.max(0.0, (r - fe) / r);
  final rx = r * 0.82;
  final ry = r * 1.12;
  final mask = <HouseGradient>[
    HouseRadial(
      center: at,
      rx: rx,
      ry: ry,
      stops: [
        const HouseStop(0, _opaque),
        HouseStop(s1, _opaque),
        HouseStop(1, _black(d)),
      ],
    ),
  ];
  final env = math.sin(math.pi * _clamp01(e * 1.2));
  final ringI = math.max(0.0, (r - fe * 1.25) / r);
  final ringP = math.max(ringI, (r - fe * 0.4) / r);
  final ringO = 1 + fe * 0.45 / r;
  final glow = <HouseGradient>[
    HouseRadial(
      center: at,
      rx: rx,
      ry: ry,
      stops: [
        HouseStop(ringI, _rgba(colour, 0)),
        HouseStop(ringP, _rgba(colour, 0.42 * env)),
        HouseStop(ringO, _rgba(colour, 0)),
      ],
    ),
    HouseRadial(
      center: at,
      rx: 110,
      ry: 150,
      stops: [
        HouseStop(
          0,
          ui.Color.fromRGBO(
            255,
            255,
            255,
            _clamp01(0.72 * math.pow(env, 1.4).toDouble()).toDouble(),
          ),
        ),
        HouseStop(0.45, _rgba(colour, 0.22 * env)),
        HouseStop(1, _rgba(colour, 0)),
      ],
    ),
  ];
  return HouseArrivalFrame(mask: mask, glow: glow);
}

/// GOALS: the lamp clicks on and a cone opens downward and outward from it.
HouseArrivalFrame _lampCone(HouseRoom room, double e) {
  final a = room.anchor;
  final d = houseSmoothstep((e - 0.15) / 0.85);
  final h = _lerp(4, 196, houseSmoothstep(e * 1.04));
  final s = _lerp(7, 40, e);
  final st = [
    0.0,
    180 - h - s,
    180 - h,
    180 + h,
    180 + h + s,
    360.0,
  ].map((x) => x.clamp(0.0, 360.0)).toList();
  final mono = <double>[];
  var floor = 0.0;
  for (final x in st) {
    floor = math.max(floor, x);
    mono.add(floor);
  }
  final radius = _lerp(26, 780, math.pow(e.clamp(0.0, 1.0), 1.1).toDouble());
  final mask = <HouseGradient>[
    HouseRadial(
      center: a,
      rx: radius,
      ry: radius,
      stops: [
        const HouseStop(0, _opaque),
        const HouseStop(0.55, _opaque),
        HouseStop(1, _black(0)),
      ],
    ),
    HouseConic(
      center: a,
      stops: [
        HouseStop(0, _black(d)),
        HouseStop(mono[1], _black(d)),
        HouseStop(mono[2], _opaque),
        HouseStop(mono[3], _opaque),
        HouseStop(mono[4], _black(d)),
        HouseStop(360, _black(d)),
      ],
    ),
  ];
  final click =
      houseSmoothstep(e / 0.06) * (1 - houseSmoothstep((e - 0.2) / 0.8));
  const brass = [255, 208, 130];
  final edge = math.sin(math.pi * _clamp01(e * 1.15));
  final glow = <HouseGradient>[
    // The lamp's own click.
    HouseRadial(
      center: a,
      rx: 95,
      ry: 80,
      stops: [
        HouseStop(0, _rgba(const [255, 236, 190], 0.8 * click)),
        HouseStop(1, _rgba(const [255, 200, 120], 0)),
      ],
    ),
    // The cone's two edges.
    HouseConic(
      center: a,
      stops: [
        HouseStop(0, _rgba(brass, 0)),
        HouseStop(mono[1], _rgba(brass, 0)),
        HouseStop(mono[2], _rgba(brass, 0.34 * edge)),
        HouseStop(math.min(360, mono[2] + 14), _rgba(brass, 0)),
        HouseStop(math.max(0, mono[3] - 14), _rgba(brass, 0)),
        HouseStop(mono[3], _rgba(brass, 0.34 * edge)),
        HouseStop(mono[4], _rgba(brass, 0)),
        HouseStop(360, _rgba(brass, 0)),
      ],
    ),
  ];
  return HouseArrivalFrame(mask: mask, glow: glow);
}

/// PLANS: a soft vertical band of daylight sweeps across from the window
/// side, like curtains drawn on the day.
HouseArrivalFrame _daylightBand(double e, bool evening) {
  final colour = evening ? const [255, 196, 120] : const [255, 232, 176];
  final d = houseSmoothstep((e - 0.1) / 0.9);
  final w = _lerp(42, 96, e);
  final x = _lerp(-60, houseCanvasWidth + 110, e);
  final p0 = math.max(0.0, x - w);
  final p1 = math.max(p0, x + w * 0.7);
  final mask = <HouseGradient>[
    HouseLinear.right(
      stops: [
        const HouseStop(0, _opaque),
        HouseStop(p0, _opaque),
        HouseStop(p1, _black(d)),
        HouseStop(math.max(houseCanvasWidth, p1), _black(d)),
      ],
    ),
  ];
  final env = math.pow(math.sin(math.pi * _clamp01(e)), 0.6).toDouble();
  final glow = <HouseGradient>[
    HouseLinear.right(
      stops: [
        HouseStop(x - w * 1.7, _rgba(colour, 0)),
        HouseStop(x - w * 0.35, _rgba(colour, 0.36 * env)),
        HouseStop(x + w * 0.12, _rgba(const [255, 246, 220], 0.52 * env)),
        HouseStop(x + w * 1.2, _rgba(colour, 0)),
      ],
    ),
  ];
  return HouseArrivalFrame(mask: mask, glow: glow);
}

/// JOURNAL: the calmest arrival, a slow radial rise from a low glow around
/// the lamp.
HouseArrivalFrame _readingLamp(HouseRoom room, double e) {
  final a = room.anchor;
  final d = houseSmoothstep((e - 0.22) / 0.78);
  final r = _lerp(20, 760, math.pow(e.clamp(0.0, 1.0), 1.2).toDouble());
  final s1 = math.max(0.0, (r * 0.3 - 8) / r);
  final mask = <HouseGradient>[
    HouseRadial(
      center: a,
      rx: r,
      ry: r,
      stops: [
        const HouseStop(0, _opaque),
        HouseStop(s1, _opaque),
        HouseStop(1, _black(d)),
      ],
    ),
  ];
  final env = math.sin(math.pi * _clamp01(e * 1.1));
  const lamp = [255, 198, 118];
  const warm = [255, 170, 80];
  final glow = <HouseGradient>[
    HouseRadial(
      center: a,
      rx: 120,
      ry: 140,
      stops: [
        HouseStop(0, _rgba(lamp, 0.3 * math.pow(env, 1.2).toDouble())),
        HouseStop(1, _rgba(warm, 0)),
      ],
    ),
    HouseRadial(
      center: a,
      rx: r * 0.9,
      ry: r * 0.9,
      stops: [
        HouseStop(0.3, _rgba(warm, 0)),
        HouseStop(0.78, _rgba(lamp, 0.06 * env)),
        HouseStop(1, _rgba(warm, 0)),
      ],
    ),
  ];
  return HouseArrivalFrame(mask: mask, glow: glow);
}
