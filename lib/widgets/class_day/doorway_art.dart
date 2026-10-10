// The Doorway's painted art and its geometry, measured from the plates.
//
// Everything here is in points on a 393 x 852 canvas (the plates are 1179 x
// 2556 px, three per point). The art loads lazily and never throws: a plate
// that has not decoded yet simply is not drawn, so the stage is always
// complete in whatever it has.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The canvas the plates are drawn on.
const double doorwayCanvasWidth = 393;
const double doorwayCanvasHeight = 852;

/// The three painted lights, in the order the stage keeps them.
enum DoorwayLight { midday, golden, evening }

abstract final class DoorwayAssets {
  static const _dir = 'assets/rooms/doorway/';

  /// The foreground plate per light: the interior, with six transparent
  /// pane cuts.
  static const view = [
    '${_dir}door-view-midday.webp',
    '${_dir}door-view-golden.webp',
    '${_dir}door-view-evening.webp',
  ];

  /// The oversized exterior behind the panes, per light.
  static const outdoor = [
    '${_dir}outdoor-midday.webp',
    '${_dir}outdoor-golden.webp',
    '${_dir}outdoor-dusk.webp',
  ];

  /// Each light's rail pieces (see doorway_rail.dart).
  static const rail = [
    '${_dir}rail-midday.webp',
    '${_dir}rail-golden.webp',
    '${_dir}rail-evening.webp',
  ];

  /// The live sunbeams (additive), for the two lights that have sun.
  static const beam = ['${_dir}beam-midday.webp', '${_dir}beam-golden.webp'];

  static const ticketBlank = '${_dir}ticket-blank.webp';
  static const ticketAttended = '${_dir}ticket-attended.webp';

  static const bundle = [
    '${_dir}week-bundle-A.webp',
    '${_dir}week-bundle-B.webp',
    '${_dir}week-bundle-C.webp',
  ];

  /// Everything the stage paints, for a precache.
  static List<String> get all => [
    ...view,
    ...outdoor,
    ...rail,
    ...beam,
    ticketBlank,
    ticketAttended,
    ...bundle,
  ];

  /// The provider the stage uses for [asset], so a caller that precaches it
  /// warms exactly the entry the stage will ask for.
  static ImageProvider providerFor(String asset) {
    if (outdoor.contains(asset)) {
      // Only a 182 pt window of it ever shows, three pixels per point.
      return ResizeImage(AssetImage(asset), width: 640, allowUpscaling: false);
    }
    return AssetImage(asset);
  }
}

/// Decodes the art on demand and tells its painters when something arrives.
class DoorwayArt extends ChangeNotifier {
  final Map<String, ui.Image> _images = {};
  final Set<String> _pending = {};
  final List<ImageStream> _streams = [];
  final List<ImageStreamListener> _listeners = [];
  bool _disposed = false;

  /// The decoded [asset], or null while it is not ready.
  ui.Image? operator [](String asset) => _images[asset];

  /// Starts decoding [asset] if nothing has yet.
  void ensure(String asset) {
    if (_disposed || _images.containsKey(asset) || !_pending.add(asset)) return;
    final stream = DoorwayAssets.providerFor(
      asset,
    ).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (_disposed) return;
        _images[asset]?.dispose();
        _images[asset] = info.image.clone();
        stream.removeListener(listener);
        _streams.remove(stream);
        _listeners.remove(listener);
        notifyListeners();
      },
      onError: (_, _) {
        // Missing or undecodable art is simply not drawn.
        stream.removeListener(listener);
        _streams.remove(stream);
        _listeners.remove(listener);
      },
    );
    _streams.add(stream);
    _listeners.add(listener);
    stream.addListener(listener);
  }

  @override
  void dispose() {
    _disposed = true;
    for (var i = 0; i < _streams.length; i++) {
      _streams[i].removeListener(_listeners[i]);
    }
    _streams.clear();
    _listeners.clear();
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    super.dispose();
  }
}

// ── Geometry ──────────────────────────────────────────────────────────────

/// Where the oversized exterior sits behind the panes (points). The pane
/// union is x 114.7 to 216.3, y 138.7 to 328.3; the plate overscans it by the
/// parallax travel, framed so the left column is golden foliage and the
/// mountain peak lands in the upper-right panes, as in the concept.
const doorwayOutdoorRect = Rect.fromLTWH(68, 107, 182, 227.5);

/// The five hooks' x (points) and the y their strings start from.
const doorwayHookX = [290.0, 308.7, 327.3, 346.0, 364.7];
const double doorwayHookY = 211;

/// The brass key bowl's rim center (points) on the cabinet.
const doorwayBowl = Offset(349.3, 347.5);

/// The wall lantern (evening), where its motes drift.
const doorwayLantern = Offset(371, 109);

/// The high shelf's top surface (points) and the clear stretch's bundles:
/// each sprite's size and center x. The shelf's own label sits below.
const double doorwayShelfTop = 164.5;
const doorwayBundleSizes = [Size(15.6, 28), Size(12.8, 28), Size(16.5, 28)];
const doorwayBundleX = [353.8, 366.4, 360.0];
const doorwayShelfLabelRect = Rect.fromLTWH(276, 171.5, 70, 8);

/// A hung ticket's two hooks, the string below the hooks' middle, and the
/// angle it comes to rest at, for each place on the hooks.
final class DoorwayHang {
  const DoorwayHang(this.hooks, this.drop, this.rest);

  final (int, int) hooks;

  /// From the hooks' hold to the ticket's top edge (points).
  final double drop;

  /// Resting tilt (degrees).
  final double rest;
}

const _hangs = [
  DoorwayHang((1, 4), 11, -4.5),
  DoorwayHang((0, 3), 12.5, 3.5),
  DoorwayHang((0, 2), 11.5, -2.5),
  DoorwayHang((1, 3), 10, 2.2),
  DoorwayHang((0, 4), 11, -1.4),
  DoorwayHang((1, 2), 10.5, 3),
];

/// The hang for the [place]th spot on the hooks ([layer] counts earlier
/// tickets sharing it, from the sixth ticket of a long day: each hangs a
/// little lower and leans the other way).
DoorwayHang doorwayHangFor(int place, {int layer = 0}) {
  final base = _hangs[place % _hangs.length];
  if (layer == 0) return base;
  return DoorwayHang(
    base.hooks,
    base.drop + 1.6 * layer,
    layer.isOdd ? -base.rest * 0.6 : base.rest,
  );
}

/// A hung ticket's center for the tilt [degrees] it is at.
Offset doorwayHangCenter(DoorwayHang hang, double degrees, double height) {
  final anchor =
      (doorwayHookX[hang.hooks.$1] + doorwayHookX[hang.hooks.$2]) / 2;
  final reach = hang.drop + height / 2;
  final r = degrees * math.pi / 180;
  return Offset(
    anchor - reach * math.sin(r),
    doorwayHookY + reach * math.cos(r),
  );
}

/// The day's pairs lie in the bowl leaning on its rim: each pair's offset
/// from the rim center (points) and its tilt (degrees).
const doorwayBowlPairs = [
  (Offset(-6, -3), -18.0),
  (Offset(5, -2.5), 14.0),
  (Offset(-1, -4), -8.0),
  (Offset(3.5, -3), 22.0),
  (Offset(-3, -2), 6.0),
];

/// A mini ticket in the bowl is this fraction of a full one.
const double doorwayBowlScale = 0.4;

// ── Dust ──────────────────────────────────────────────────────────────────

/// The lit volume of a beam, as a low-resolution mask (196 x 426, half a
/// point per cell... two points per cell), and the places a mote can be born.
/// Built from the beam's own alpha, smeared back toward the door along the
/// light's direction, so the motes live in the shaft and never outside it.
final class DoorwayBeamMask {
  DoorwayBeamMask._(this.air, this.births);

  static const int width = 196;
  static const int height = 426;

  /// 0..255 per cell: how much of the shaft's air is lit there.
  final Uint8List air;

  /// Candidate birth places (points).
  final List<Offset> births;

  /// How lit the air is at a point (0..1).
  double at(double x, double y) {
    final ix = x ~/ 2;
    final iy = y ~/ 2;
    if (ix < 0 || iy < 0 || ix >= width || iy >= height) return 0;
    return air[iy * width + ix] / 255;
  }

  /// Builds the mask from [alpha], the beam image's alpha channel sampled at
  /// [width] x [height] (row major).
  static DoorwayBeamMask fromAlpha(Uint8List alpha, math.Random random) {
    final air = Uint8List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var best = 0.0;
        for (var t = 0; t <= 42; t += 3) {
          final sx = x + (0.94 * t).round();
          final sy = y + (0.34 * t).round();
          if (sx >= width || sy >= height) break;
          final v = alpha[sy * width + sx] * (1 - t / 52);
          if (v > best) best = v;
        }
        air[y * width + x] = best.round();
      }
    }
    final births = <Offset>[];
    for (var i = 0; i < air.length; i++) {
      final y = i ~/ width;
      if (air[i] > 120 && y > 40 && (y < 236 || random.nextDouble() < 0.12)) {
        births.add(Offset((i % width) * 2.0, y * 2.0));
      }
    }
    return DoorwayBeamMask._(air, births);
  }

  /// Samples [image] (decoded at 196 px wide) into a mask, or null when it
  /// cannot be read.
  static Future<DoorwayBeamMask?> fromImage(
    ui.Image image,
    math.Random random,
  ) async {
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;
      final bytes = data.buffer.asUint8List();
      final alpha = Uint8List(width * height);
      for (var y = 0; y < height; y++) {
        final sy = math.min(image.height - 1, y * image.height ~/ height);
        for (var x = 0; x < width; x++) {
          final sx = math.min(image.width - 1, x * image.width ~/ width);
          alpha[y * width + x] = bytes[(sy * image.width + sx) * 4 + 3];
        }
      }
      return fromAlpha(alpha, random);
    } catch (_) {
      return null;
    }
  }
}
