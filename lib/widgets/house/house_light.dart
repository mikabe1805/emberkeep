// The house's light of day: which painted plate shows, by the real clock.
//
// The blend windows are the Doorway's (doorway_light.dart): evening from 18:30
// through 06:00, midday to 15:30, golden to 18:30, each change a forty-minute
// blend centred on its boundary. A plate set carries only the lights that
// have been painted. The weight of a light with no plate of its own goes to
// the nearest painted light: golden hour to midday, a missing evening to the
// golden plate if there is one and to midday if not. So a room with only a
// midday plate always shows its midday, and nothing is ever tinted to make it
// look like evening.
//
// Pure: a clock reading and a plate set in, the layers to paint out.
library;

import '../class_day/doorway_light.dart';
import 'house_room.dart';

/// One plate to paint, with how much of the room's picture it carries and the
/// opacity to draw it at (the painter's cross-fade, so there is no dark dip).
final class HousePlateLayer {
  const HousePlateLayer({
    required this.asset,
    required this.weight,
    required this.opacity,
  });

  final String asset;

  /// This plate's share of the picture; the live layers' weights sum to one.
  final double weight;

  /// The opacity to draw the plate at, laid over the layers before it.
  final double opacity;

  @override
  String toString() =>
      'HousePlateLayer($asset, weight: ${weight.toStringAsFixed(3)}, '
      'opacity: ${opacity.toStringAsFixed(3)})';
}

/// The weights of [plates]' lights for the Doorway's [lights], in the order
/// midday, golden, evening. A light the room has no plate for has weight zero;
/// its share has gone to the nearest painted light. The weights sum to one.
List<double> housePlateWeights(HousePlates plates, DoorwayLights lights) {
  var midday = lights.midday;
  var golden = lights.golden;
  var evening = lights.evening;
  if (plates.golden == null) {
    midday += golden;
    golden = 0;
  }
  if (plates.evening == null) {
    if (plates.golden != null) {
      golden += evening;
    } else {
      midday += evening;
    }
    evening = 0;
  }
  return [midday, golden, evening];
}

/// The plates to paint now, back to front: only the lights with any weight.
/// The first is opaque; each later one fades over what is under it.
List<HousePlateLayer> housePlateLayers(
  HousePlates plates,
  DoorwayLights lights,
) {
  final weights = housePlateWeights(plates, lights);
  final assets = [plates.midday, plates.golden, plates.evening];
  final fades = doorwayCrossfade(weights);
  return [
    for (var i = 0; i < 3; i++)
      if (assets[i] != null && weights[i] > 0.0005)
        HousePlateLayer(
          asset: assets[i]!,
          weight: weights[i],
          opacity: fades[i],
        ),
  ];
}

/// The plates to paint at the local wall-clock moment [local].
List<HousePlateLayer> housePlateLayersAt(HousePlates plates, DateTime local) =>
    housePlateLayers(plates, doorwayLightsAt(local));
