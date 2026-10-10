// The Doorway's light of day: three painted lights, cross-faded by the clock.
//
// The three plates are real paintings of the same doorway at midday, in the
// golden hour and at dusk. They never tint: one fades into the next while the
// hour turns, each blend forty minutes wide and centered on its boundary
// (06:00 and 15:30 and 18:30), so there is no moment of one wash laid over
// another. Pure: a clock reading in, three weights out.
library;

/// How much of each painted light shows. The weights sum to one.
final class DoorwayLights {
  const DoorwayLights({
    required this.midday,
    required this.golden,
    required this.evening,
  });

  final double midday;
  final double golden;
  final double evening;

  /// The weights in plate order: midday, golden, evening.
  List<double> get weights => [midday, golden, evening];

  /// The sun is up (a beam falls through the glass).
  double get sun => midday + golden;

  @override
  bool operator ==(Object other) =>
      other is DoorwayLights &&
      other.midday == midday &&
      other.golden == golden &&
      other.evening == evening;

  @override
  int get hashCode => Object.hash(midday, golden, evening);

  @override
  String toString() =>
      'DoorwayLights(midday: ${midday.toStringAsFixed(3)}, '
      'golden: ${golden.toStringAsFixed(3)}, '
      'evening: ${evening.toStringAsFixed(3)})';
}

/// The width of every blend between two lights, in minutes.
const doorwayBlendMinutes = 40.0;

/// Where the lights change, in minutes after midnight: dawn into midday,
/// midday into golden, golden into evening.
const doorwayDawn = 6 * 60.0;
const doorwayGoldenStart = 15 * 60 + 30.0;
const doorwayEveningStart = 18 * 60 + 30.0;

double _smooth(double t) {
  final c = t.clamp(0.0, 1.0);
  return c * c * (3 - 2 * c);
}

/// The lights at [minutes] after local midnight (fractions allowed): evening
/// from 18:30 through 06:00, midday to 15:30, golden to 18:30, with a
/// [doorwayBlendMinutes] blend centered on each boundary.
DoorwayLights doorwayLightsAtMinute(double minutes) {
  const half = doorwayBlendMinutes / 2;
  final day = _smooth((minutes - (doorwayDawn - half)) / doorwayBlendMinutes);
  final toGold = _smooth(
    (minutes - (doorwayGoldenStart - half)) / doorwayBlendMinutes,
  );
  final toEvening = _smooth(
    (minutes - (doorwayEveningStart - half)) / doorwayBlendMinutes,
  );
  return DoorwayLights(
    midday: day * (1 - toGold),
    golden: toGold * (1 - toEvening),
    evening: (1 - day) + toEvening,
  );
}

/// The lights at the local wall-clock moment [local] (the app's own clock,
/// [Clock.now], read in the device's zone).
DoorwayLights doorwayLightsAt(DateTime local) {
  final at = local.toLocal();
  return doorwayLightsAtMinute(
    at.hour * 60 +
        at.minute +
        at.second / 60 +
        at.millisecond / 60000 +
        at.microsecond / 60000000,
  );
}

/// Painter's cross-fade: the opacity each layer is drawn with, so that laying
/// them in order reproduces the weights without a dark dip in the middle. The
/// first live layer is opaque; each later one fades over what is under it by
/// its share of the weight so far.
List<double> doorwayCrossfade(List<double> weights) {
  final out = List<double>.filled(weights.length, 0);
  var cumulative = 0.0;
  for (var i = 0; i < weights.length; i++) {
    final w = weights[i];
    if (w <= 0.0005) continue;
    final before = cumulative;
    cumulative += w;
    out[i] = before <= 0.0005 ? 1 : (w / cumulative).clamp(0.0, 1.0);
  }
  return out;
}
