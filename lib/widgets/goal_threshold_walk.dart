import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'goal_world.dart'
    show
        goalsKitchenDetailScrim,
        goalsRoomContinuousAsset,
        goalsRoomRetreatAsset,
        goalsWideRoomScrim;

// ─────────────────────────────────────────────────────────────────────────────
// The Goals walk: passing through the lit arch into the kitchen.
//
// Why this exists (Mika, 2026-10-03, verbatim): "when i was talking about the
// motion blur back then, i meant SPECIFCIALLY on the transitions for the goals
// page, so that it really feels like you’re walking through a room, which never
// ended up landing".
//
// The old travel zoomed one flat plate. Walking is read from parallax: the
// doorway you pass grows and slides out of frame much faster than the room
// beyond it, which comes toward you slowly and resolves. This file models the
// walk with two depths and no new art:
//
// * NEAR: the apartment master (`goals-threshold-room-v1`) with the arch
//   opening cut away along its painted inner edge. The cut follows a real
//   occlusion edge (plaster jamb and soffit against the lit room beyond), and
//   the chair's armrest that overlaps the opening stays on the near plane.
//   The floor seam at the threshold is a 70 px feather, so the lit floorboards
//   hand over to the room beyond without a line.
// * FAR: the kitchen itself, registered inside the doorway at the first frame
//   (the kitchen plate is fitted to the master's painted kitchen by a measured
//   similarity). Anything the far plane cannot cover at its edges is
//   mirror-extended in bands of a few points; the passage never shows an empty
//   edge.
// * BRIDGE: for the first steps the master's own painted kitchen sits in the
//   doorway at the far depth, so the first frame is pixel-identical to the
//   resting Goals tab, then gives way to the kitchen plate.
//
// Both planes expand about one focus of expansion (the point the walk heads
// toward). Near magnification is 1 / (1 - D w), far is rho / (rho - D w): the
// arch accelerates out of frame as you near it while the room beyond keeps a
// steady approach. The camera turns gently toward the room's centre over the
// walk (pan), which is uniform across depths, like a head turn.
//
// Only the kitchen is walked. The workshop, the quest handoff and the one-time
// opening keep the calm Goals dolly (`GoalRoomTravelBackdrop`); the first
// walk-threshold build also walked them (design/comparisons/2026-10-03/
// transitions/walk-threshold), and the steward's tavern needs a plate painted
// for this camera before that is worth shipping.
// ─────────────────────────────────────────────────────────────────────────────

/// Master plate geometry, in its own pixels (853 x 1844).
const goalsThresholdMasterSize = Size(853, 1844);

/// The master's lit arch opening, measured on the plate: vertical jambs at
/// x 362.5 and 722.5, a semi-elliptic head (centre 542.5/510, radii 180/184),
/// the floor threshold at y 1245, and the armchair's armrest (which stands in
/// front of the opening) excluded on the lower right.
final Path goalsThresholdOpening = () {
  const cx = 542.5, cy = 510.0, rx = 180.0, ry = 184.0;
  final path = Path()
    ..moveTo(362.5, cy)
    ..lineTo(362.5, 1207)
    ..lineTo(369, 1207)
    ..lineTo(369, 1245)
    ..lineTo(661, 1245)
    ..lineTo(664.5, 1201)
    ..lineTo(668, 1193)
    ..lineTo(724, 1176)
    ..lineTo(722.5, 1176)
    ..lineTo(722.5, cy);
  const steps = 72;
  for (var i = 1; i < steps; i++) {
    final a = math.pi * i / steps;
    path.lineTo(cx + rx * math.cos(a), cy - ry * math.sin(a));
  }
  path.close();
  return path;
}();

/// The floor band just in front of the threshold where the near floor fades
/// into the floor beyond (between the left jamb base and the armrest).
const goalsThresholdFloorBand = Rect.fromLTRB(369, 1245, 661, 1315);

/// The near plane's arch edges, for the motion streak and the stop text.
const _archLeftEdge = 362.5;
const _archTopY = 326.0;
const _thresholdY = 1245.0;
const _archCentreX = 542.5;

/// Kitchen plate geometry (851 x 1847) and its registration to the master's
/// painted kitchen (SIFT matches, RANSAC similarity on 51 inliers, mean
/// residual 3.4 master px, rotation 0.37 deg ignored).
const goalsKitchenPlateSize = Size(851, 1847);
const _kitchenToMasterScale = 0.6762;
const _kitchenToMasterOffset = Offset(209.54, 268.68);

/// The kitchen plate is painted from inside the arch, so its own jambs show at
/// the edges, and just inside the left jamb a sliver of moonlit blue (plate x
/// 31-79) that reads as a stripe, not a window, once the arch slides past it.
/// Only this rectangle is the room beyond; the walk and the detail page never
/// show the painted jambs or that sliver.
const goalsKitchenContentRect = Rect.fromLTRB(84, 0, 775, 1847);

/// The kitchen detail's framing (scale over cover and the shift that keeps the
/// painted right jamb just outside the frame). The detail page and the walk's
/// arrival use the same numbers, so the arrival is the page itself.
@immutable
class GoalsKitchenFrame {
  const GoalsKitchenFrame({required this.scale, required this.translation});

  /// Scale applied over BoxFit.cover, about the box centre.
  final double scale;

  /// FractionalTranslation of the scaled plate (fraction of the box size).
  final Offset translation;

  static const minimumScale = 1.12;

  /// Heroes are drawn in a box of [box] size whose top is the screen top.
  factory GoalsKitchenFrame.forBox(Size box) {
    final cover = math.max(
      box.width / goalsKitchenPlateSize.width,
      box.height / goalsKitchenPlateSize.height,
    );
    final content = goalsKitchenContentRect;
    final needed = (box.width + 6) / (content.width * cover);
    final scale = math.max(minimumScale, needed);
    final s = cover * scale;
    final centredLeft = box.width / 2 - s * goalsKitchenPlateSize.width / 2;
    // Right-align to the content edge (2 px inside it); the left side then
    // keeps the painted left jamb out of frame as well.
    var left = box.width + 2 - s * (content.right - 1);
    final leftLimit = -s * (content.left + 1);
    if (left > leftLimit) left = leftLimit;
    return GoalsKitchenFrame(
      scale: scale,
      translation: Offset((left - centredLeft) / box.width, 0),
    );
  }

  /// The hero box the detail page uses for [screen] (it adds 52 pt below).
  static Size heroBox(Size screen, {required bool compact}) =>
      Size(screen.width, screen.height + (compact ? 24 : 52));

  /// Kitchen pixels to screen for a hero box anchored at the screen top.
  GoalWalkAffine affineIn(Size box) {
    final cover = math.max(
      box.width / goalsKitchenPlateSize.width,
      box.height / goalsKitchenPlateSize.height,
    );
    final s = cover * scale;
    return GoalWalkAffine(
      s,
      Offset(
        box.width / 2 -
            s * goalsKitchenPlateSize.width / 2 +
            translation.dx * box.width,
        box.height / 2 -
            s * goalsKitchenPlateSize.height / 2 +
            translation.dy * box.height,
      ),
    );
  }
}

/// Whether the detail page uses its compact framing (narrow, short, or large
/// text). Shared so the walk lands on exactly what the page will draw.
bool goalsKitchenCompact(BuildContext context) {
  final surface = MediaQuery.sizeOf(context);
  return surface.width < 360 ||
      surface.height < 700 ||
      MediaQuery.textScalerOf(context).scale(1) > 1.2;
}

/// A scale-and-offset map: screen = s * p + o.
@immutable
class GoalWalkAffine {
  const GoalWalkAffine(this.s, this.o);
  final double s;
  final Offset o;

  Offset map(Offset p) => Offset(p.dx * s + o.dx, p.dy * s + o.dy);

  Float64List get storage => Float64List.fromList(<double>[
    s, 0, 0, 0, //
    0, s, 0, 0, //
    0, 0, 1, 0, //
    o.dx, o.dy, 0, 1,
  ]);

  GoalWalkAffine then(GoalWalkAffine outer) =>
      GoalWalkAffine(s * outer.s, outer.map(o));
}

/// The Goals tab's resting framing of the master (the desk), which is where
/// every walk starts: scale over cover about the centre, translation as a
/// fraction of the viewport.
@immutable
class GoalRoomFraming {
  const GoalRoomFraming(this.scale, this.translation);
  final double scale;
  final Offset translation;

  static const desk = GoalRoomFraming(1.16, Offset(0.08, -0.065));

  GoalWalkAffine masterAffine(Size size) {
    final cover = math.max(
      size.width / goalsThresholdMasterSize.width,
      size.height / goalsThresholdMasterSize.height,
    );
    final s = cover * scale;
    return GoalWalkAffine(
      s,
      Offset(
        size.width / 2 -
            s * goalsThresholdMasterSize.width / 2 +
            translation.dx * size.width,
        size.height / 2 -
            s * goalsThresholdMasterSize.height / 2 +
            translation.dy * size.height,
      ),
    );
  }
}

/// A walk's gait: a soft first step, a steady middle, a soft arrival.
///
/// The velocity profile is a raised-cosine ramp from a quarter of walking
/// speed (weight already moving when the finger lifts) to full speed over
/// [firstStep], a steady stretch, then a raised-cosine slowdown to rest from
/// [arriveFrom]. Being closed-form, its velocity is exact, so the motion streak
/// never strobes.
class GoalWalkGait extends Curve {
  const GoalWalkGait({this.firstStep = 0.2, this.arriveFrom = 0.72});

  final double firstStep;
  final double arriveFrom;

  static const _startSpeed = 0.25;

  double get _area =>
      _startSpeed * firstStep +
      (1 - _startSpeed) * firstStep / 2 +
      (arriveFrom - firstStep) +
      (1 - arriveFrom) / 2;

  double _integral(double t) {
    final a = firstStep, b = arriveFrom;
    if (t <= a) {
      return _startSpeed * t +
          (1 - _startSpeed) *
              (t / 2 - a / (2 * math.pi) * math.sin(math.pi * t / a));
    }
    final first = _startSpeed * a + (1 - _startSpeed) * a / 2;
    if (t <= b) return first + (t - a);
    final d = 1 - b;
    final u = t - b;
    return first +
        (b - a) +
        u / 2 +
        d / (2 * math.pi) * math.sin(math.pi * u / d);
  }

  @override
  double transformInternal(double t) => _integral(t) / _area;

  /// d(transform)/dt.
  double velocity(double t) {
    final clamped = t.clamp(0.0, 1.0);
    final a = firstStep, b = arriveFrom;
    double v;
    if (clamped <= a) {
      v =
          _startSpeed +
          (1 - _startSpeed) * (1 - math.cos(math.pi * clamped / a)) / 2;
    } else if (clamped <= b) {
      v = 1;
    } else {
      v = (1 + math.cos(math.pi * (clamped - b) / (1 - b))) / 2;
    }
    return v / _area;
  }
}

double _smoothstep(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _smoothstepSlope(double x) {
  if (x <= 0 || x >= 1) return 0;
  return 6 * x * (1 - x);
}

double _segment(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0);

/// The geometry of one walk at one viewport size. Pure math; no widgets.
@immutable
class GoalThresholdWalk {
  const GoalThresholdWalk._({
    required this.size,
    required this.masterStart,
    required this.focusStart,
    required this.focusEnd,
    required this.travel,
    required this.farDepth,
    required this.farEnd,
    required this.kitchenStart,
    required this.kitchenBox,
  });

  /// [kitchenBox] is the detail page's hero box (see [GoalsKitchenFrame]).
  factory GoalThresholdWalk({required Size size, required Size kitchenBox}) {
    // The geometry is defined by the kitchen registration: the focus of
    // expansion is the kitchen point that ends at (0.5, 0.46) of the screen.
    final desk = GoalRoomFraming.desk.masterAffine(size);
    final kitchenStartDesk = const GoalWalkAffine(
      _kitchenToMasterScale,
      _kitchenToMasterOffset,
    ).then(desk);
    final kitchenEnd = GoalsKitchenFrame.forBox(
      kitchenBox,
    ).affineIn(kitchenBox);
    final focusEnd = Offset(size.width * 0.5, size.height * 0.46);
    final kitchenGrowth = kitchenEnd.s / kitchenStartDesk.s;
    // F0 = o0 - (o1 - Fend) / m1, so every kitchen pixel lands on its framing.
    final routeFocus =
        kitchenStartDesk.o - (kitchenEnd.o - focusEnd) / kitchenGrowth;
    // The arch grows 4.5x: its left jamb leaves the frame at ~w 0.85.
    const nearEnd = 4.5;
    const travel = 1 - 1 / nearEnd;
    return GoalThresholdWalk._(
      size: size,
      masterStart: desk,
      focusStart: routeFocus,
      focusEnd: focusEnd,
      travel: travel,
      farDepth: kitchenGrowth * travel / (kitchenGrowth - 1),
      farEnd: kitchenGrowth,
      kitchenStart: kitchenStartDesk,
      kitchenBox: kitchenBox,
    );
  }

  final Size size;
  final GoalWalkAffine masterStart;
  final Offset focusStart;
  final Offset focusEnd;

  /// D: the share of the distance to the arch walked by w = 1.
  final double travel;

  /// rho: the far room's depth in arch distances.
  final double farDepth;

  /// The far room's total growth over the walk.
  final double farEnd;
  final GoalWalkAffine kitchenStart;
  final Size kitchenBox;

  double nearMag(double w) => 1 / (1 - travel * w);
  double farMag(double w) => farDepth / (farDepth - travel * w);
  double _nearMagSlope(double w) {
    final d = 1 - travel * w;
    return travel / (d * d);
  }

  Offset focus(double w) => Offset.lerp(focusStart, focusEnd, _smoothstep(w))!;

  GoalWalkAffine _expand(GoalWalkAffine start, double m, double w) {
    final f = focus(w);
    return GoalWalkAffine(start.s * m, f + (start.o - focusStart) * m);
  }

  /// Master pixels to screen for the arch (near plane).
  GoalWalkAffine near(double w) => _expand(masterStart, nearMag(w), w);

  /// Master pixels to screen for the master's own painted room beyond (the
  /// first-steps bridge), which travels at the far depth.
  GoalWalkAffine bridge(double w) => _expand(masterStart, farMag(w), w);

  /// Kitchen pixels to screen.
  GoalWalkAffine kitchen(double w) => _expand(kitchenStart, farMag(w), w);

  /// How much of the master's own painted room still bridges the doorway.
  /// The kitchen beyond is the same room re-painted closer, so it hands over
  /// gently as you set off.
  double bridgeOpacity(double w) =>
      1 - Curves.easeInOutCubic.transform(_segment(w, 0.0, 0.12));

  /// The screen speed (points per second) of the arch's edges while they are
  /// in frame, for a walk advancing at [walkVelocity] (w per second). x is the
  /// left jamb, y the arch head or the threshold.
  Offset edgeSpeed(double w, double walkVelocity) {
    if (walkVelocity == 0) return Offset.zero;
    final aff = near(w);
    final m = nearMag(w);
    final slope = _nearMagSlope(w);
    final panSlope = _smoothstepSlope(w);
    final f0 = focusStart;
    final df = focusEnd - focusStart;
    final left0 = masterStart.map(const Offset(_archLeftEdge, 0)).dx;
    final top0 = masterStart.map(const Offset(_archCentreX, _archTopY)).dy;
    final floor0 = masterStart.map(const Offset(_archCentreX, _thresholdY)).dy;
    final leftX = aff.map(const Offset(_archLeftEdge, 0)).dx;
    final topY = aff.map(const Offset(_archCentreX, _archTopY)).dy;
    final floorY = aff.map(const Offset(_archCentreX, _thresholdY)).dy;
    var vx = 0.0;
    if (leftX > -4 && leftX < size.width) {
      vx = (df.dx * panSlope + (left0 - f0.dx) * slope) * walkVelocity;
    }
    var vy = 0.0;
    if (topY > -4 && topY < size.height) {
      vy = (df.dy * panSlope + (top0 - f0.dy) * slope) * walkVelocity;
    }
    if (floorY > 0 && floorY < size.height + 4) {
      final v = (df.dy * panSlope + (floor0 - f0.dy) * slope) * walkVelocity;
      if (v.abs() > vy.abs()) vy = v;
    }
    // Speeds are only meaningful where the edge is near the frame: once an
    // edge has left, its plane is out of view.
    if (m > 40) return Offset.zero;
    return Offset(vx, vy);
  }
}

/// The motion streak for the near plane: a 180-degree shutter at 60 Hz spreads
/// an edge over half a frame of travel; as a Gaussian that is about 0.2 of the
/// per-frame displacement. Capped so a fast edge stays a soft edge.
Offset goalWalkStreakSigma(Offset edgeSpeed) {
  double sigma(double speed) {
    final perFrame = speed.abs() / 60;
    return (perFrame * 0.2).clamp(0.0, 5.0);
  }

  return Offset(sigma(edgeSpeed.dx), sigma(edgeSpeed.dy));
}

// ─────────────────────────────────────────────────────────────────────────────
// Images
// ─────────────────────────────────────────────────────────────────────────────

/// Resolves the walk's plates as `ui.Image`s from the shared image cache. The
/// resting Goals tab precaches them, so on device they arrive synchronously.
class GoalWalkImages {
  GoalWalkImages(this._onChanged);

  final VoidCallback _onChanged;
  final Map<String, _ResolvedImage> _images = {};
  ui.Image? _kitchenContent;
  bool _disposed = false;

  ui.Image? operator [](String asset) => _images[asset]?.info?.image;
  bool failed(String asset) => _images[asset]?.failed ?? false;

  /// The kitchen plate cropped to [goalsKitchenContentRect], so mirror tiling
  /// never reaches the painted jambs.
  ui.Image? get kitchenContent {
    if (_kitchenContent != null) return _kitchenContent;
    final source = this[goalsWalkKitchenAsset];
    if (source == null) return null;
    final rect = goalsKitchenContentRect;
    final sx = source.width / goalsKitchenPlateSize.width;
    final sy = source.height / goalsKitchenPlateSize.height;
    final src = Rect.fromLTRB(
      rect.left * sx,
      rect.top * sy,
      rect.right * sx,
      rect.bottom * sy,
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      source,
      src,
      Rect.fromLTWH(0, 0, src.width, src.height),
      Paint()..filterQuality = FilterQuality.none,
    );
    final picture = recorder.endRecording();
    _kitchenContent = picture.toImageSync(
      src.width.round(),
      src.height.round(),
    );
    picture.dispose();
    return _kitchenContent;
  }

  void want(BuildContext context, Iterable<String> assets) {
    final configuration = createLocalImageConfiguration(context);
    for (final asset in assets) {
      if (_images.containsKey(asset)) continue;
      final resolved = _ResolvedImage();
      _images[asset] = resolved;
      final stream = AssetImage(asset).resolve(configuration);
      resolved.stream = stream;
      resolved.listener = ImageStreamListener(
        (info, synchronousCall) {
          if (_disposed) {
            info.dispose();
            return;
          }
          resolved.info?.dispose();
          resolved.info = info;
          if (!synchronousCall) _onChanged();
        },
        onError: (error, stackTrace) {
          if (_disposed) return;
          resolved.failed = true;
          debugPrint('Goals walk art failed to load: $asset ($error)');
          _onChanged();
        },
      );
      stream.addListener(resolved.listener!);
    }
  }

  void dispose() {
    _disposed = true;
    for (final resolved in _images.values) {
      if (resolved.listener != null) {
        resolved.stream?.removeListener(resolved.listener!);
      }
      resolved.info?.dispose();
    }
    _images.clear();
    _kitchenContent?.dispose();
    _kitchenContent = null;
  }
}

class _ResolvedImage {
  ImageStream? stream;
  ImageStreamListener? listener;
  ImageInfo? info;
  bool failed = false;
}

const goalsWalkKitchenAsset = 'assets/pages/goals-room-kitchen-v1.webp';

// ─────────────────────────────────────────────────────────────────────────────
// Painters
// ─────────────────────────────────────────────────────────────────────────────

Paint _imagePaint() => Paint()
  ..filterQuality = FilterQuality.medium
  ..isAntiAlias = true;

/// Fills [screen] with [image] mirror-tiled beyond its edges. [aff] maps the
/// image's own pixels to the screen.
void _fillMirrored(
  Canvas canvas,
  Rect screen,
  ui.Image image,
  GoalWalkAffine aff,
) {
  final paint = Paint()
    ..shader = ImageShader(
      image,
      TileMode.mirror,
      TileMode.mirror,
      aff.storage,
      filterQuality: FilterQuality.medium,
    );
  canvas.drawRect(screen, paint);
}

/// Everything beyond the doorway: the kitchen and, for the first steps, the
/// master's own painted room.
class GoalWalkFarPainter extends CustomPainter {
  GoalWalkFarPainter({
    required this.walk,
    required this.w,
    required this.images,
    required this.sourceAsset,
  });

  final GoalThresholdWalk walk;
  final double w;
  final GoalWalkImages images;
  final String sourceAsset;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    canvas.drawRect(screen, Paint()..color = const Color(0xFF100D0B));
    final content = images.kitchenContent;
    if (content != null) {
      final aff = walk.kitchen(w);
      final rect = goalsKitchenContentRect;
      // Cropped pixel (u, v) is plate pixel rect.topLeft + (u, v) * px.
      final px = rect.width / content.width;
      _fillMirrored(
        canvas,
        screen,
        content,
        GoalWalkAffine(aff.s * px, aff.map(rect.topLeft)),
      );
    }
    final bridge = walk.bridgeOpacity(w);
    final master = images[sourceAsset];
    if (bridge > 0 && master != null) {
      final aff = walk.bridge(w);
      canvas.save();
      canvas.transform(aff.storage);
      canvas.clipPath(
        Path()
          ..addPath(goalsThresholdOpening, Offset.zero)
          ..addRect(goalsThresholdFloorBand),
      );
      canvas.drawImageRect(
        master,
        Rect.fromLTWH(0, 0, master.width.toDouble(), master.height.toDouble()),
        Offset.zero & goalsThresholdMasterSize,
        _imagePaint()..color = Color.fromRGBO(0, 0, 0, bridge),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(GoalWalkFarPainter old) =>
      old.w != w ||
      old.walk != walk ||
      old.images != images ||
      old.sourceAsset != sourceAsset;
}

/// The doorway and the room you are standing in: the master with the arch
/// opening cut away and the threshold floor feathered.
class GoalWalkNearPainter extends CustomPainter {
  GoalWalkNearPainter({
    required this.aff,
    required this.image,
    this.opacity = 1,
  });

  final GoalWalkAffine aff;
  final ui.Image image;
  final double opacity;

  static final Path _outside = Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(const Rect.fromLTRB(-6000, -6000, 7000, 8000))
    ..addPath(goalsThresholdOpening, Offset.zero)
    ..addRect(goalsThresholdFloorBand);

  static final ui.Gradient _feather = ui.Gradient.linear(
    goalsThresholdFloorBand.topCenter,
    goalsThresholdFloorBand.bottomCenter,
    const [
      Color(0x00000000),
      Color(0x5A000000),
      Color(0xA6000000),
      Color(0xDF000000),
      Color(0xFF000000),
    ],
    const [0, 0.25, 0.5, 0.75, 1],
  );

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Offset.zero & goalsThresholdMasterSize;
    final paint = _imagePaint()..color = Color.fromRGBO(0, 0, 0, opacity);
    canvas.save();
    canvas.transform(aff.storage);
    canvas.save();
    canvas.clipPath(_outside);
    canvas.drawImageRect(image, src, dst, paint);
    canvas.restore();
    canvas.saveLayer(goalsThresholdFloorBand, Paint());
    canvas.clipRect(goalsThresholdFloorBand);
    canvas.drawImageRect(image, src, dst, paint);
    canvas.drawRect(
      goalsThresholdFloorBand,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = _feather,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(GoalWalkNearPainter old) =>
      old.aff.s != aff.s ||
      old.aff.o != aff.o ||
      old.image != image ||
      old.opacity != opacity;
}

// ─────────────────────────────────────────────────────────────────────────────
// The backdrop
// ─────────────────────────────────────────────────────────────────────────────

/// The kitchen walk: passing through the lit arch.
///
/// [progress] is the walk position, 0 (the resting Goals tab's desk framing)
/// to 1 (standing in the kitchen). The arch is the near plane, cut along its
/// painted inner edge; the kitchen is the far plane. They separate by depth as
/// you walk, so the doorway grows and slides out of frame while the room
/// beyond comes toward you and resolves. Only the near plane is ever blurred,
/// and only by its own screen speed ([walkVelocity]); every stop is crisp.
class GoalKitchenWalkBackdrop extends StatefulWidget {
  const GoalKitchenWalkBackdrop({
    super.key,
    required this.progress,
    this.walkVelocity = 0,
    this.sourceAsset = goalsRoomContinuousAsset,
  });

  final double progress;

  /// The walk's speed in [progress] units per second (signed). Drives the
  /// near plane's motion streak; zero at every stop.
  final double walkVelocity;
  final String sourceAsset;

  @override
  State<GoalKitchenWalkBackdrop> createState() =>
      _GoalKitchenWalkBackdropState();
}

class _GoalKitchenWalkBackdropState extends State<GoalKitchenWalkBackdrop> {
  late final GoalWalkImages _images = GoalWalkImages(() {
    if (mounted) setState(() {});
  });

  Iterable<String> get _wanted => [widget.sourceAsset, goalsWalkKitchenAsset];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _images.want(context, _wanted);
  }

  @override
  void didUpdateWidget(covariant GoalKitchenWalkBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _images.want(context, _wanted);
  }

  @override
  void dispose() {
    _images.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final failed = _images.failed(widget.sourceAsset);
    return KeyedSubtree(
      key: const ValueKey('goal-kitchen-walk-backdrop'),
      child: ColoredBox(
        color: const Color(0xFF100D0B),
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (failed) return _fallback();
              return _scene(context, constraints.biggest);
            },
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          goalsRoomRetreatAsset,
          key: const Key('goal-room-source-fallback'),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => const ColoredBox(
            key: Key('goal-room-source-fallback-color'),
            color: Color(0xFF160F0B),
          ),
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: goalsWideRoomScrim),
          ),
        ),
      ],
    );
  }

  Widget _scene(BuildContext context, Size size) {
    final w = widget.progress.clamp(0.0, 1.0);
    final master = _images[widget.sourceAsset];
    final walk = GoalThresholdWalk(
      size: size,
      kitchenBox: GoalsKitchenFrame.heroBox(
        size,
        compact: goalsKitchenCompact(context),
      ),
    );
    final children = <Widget>[
      CustomPaint(
        key: const ValueKey('goal-room-travel-destination'),
        size: size,
        painter: GoalWalkFarPainter(
          walk: walk,
          w: w,
          images: _images,
          sourceAsset: widget.sourceAsset,
        ),
      ),
    ];
    // Once the arch has passed the frame there is nothing near to draw.
    if (walk.nearMag(w) < 60) {
      Widget near = CustomPaint(
        key: const ValueKey('goal-room-travel-master'),
        size: size,
        painter: master == null
            ? null
            : GoalWalkNearPainter(aff: walk.near(w), image: master),
      );
      final sigma = goalWalkStreakSigma(walk.edgeSpeed(w, widget.walkVelocity));
      if (math.max(sigma.dx, sigma.dy) > 0.2) {
        near = ImageFiltered(
          key: const ValueKey('goal-room-travel-motion-blur'),
          imageFilter: ui.ImageFilter.blur(
            sigmaX: sigma.dx,
            sigmaY: sigma.dy,
            tileMode: TileMode.decal,
          ),
          child: near,
        );
      }
      children.add(near);
    }

    // The scrim settles from the room you stand in to the kitchen's own.
    final arrival = Curves.easeInOutCubic.transform(
      ((w - 0.3) / 0.7).clamp(0.0, 1.0),
    );
    children.add(
      IgnorePointer(
        child: Opacity(
          opacity: 1 - arrival,
          child: const DecoratedBox(
            decoration: BoxDecoration(gradient: goalsWideRoomScrim),
          ),
        ),
      ),
    );
    if (arrival > 0) {
      final box = walk.kitchenBox;
      children.add(
        Positioned(
          left: 0,
          top: 0,
          width: box.width,
          height: box.height,
          child: IgnorePointer(
            child: Opacity(
              opacity: arrival,
              child: const Stack(
                fit: StackFit.expand,
                children: [
                  // The detail page's own warm light on its kitchen plate.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0.52, -0.35),
                        radius: 0.9,
                        colors: [Color(0x14FFD895), Color(0x00170F0A)],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: goalsKitchenDetailScrim,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Stack(fit: StackFit.expand, children: children);
  }
}
