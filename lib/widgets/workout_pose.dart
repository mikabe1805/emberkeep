import 'dart:math' show cos, pi, sin;

import 'package:flutter/material.dart';

import '../tokens.dart';

/// Simple, warm stick-figure illustrations of the guided-workout moves —
/// curated, offline, no assets, no AI (RESEARCH-workouts.md). A move's pose is
/// inferred from its name, so the runner can show "what it looks like" without
/// a single image file.
enum WorkoutPose {
  stand,
  squat,
  pushup,
  wallPress,
  plank,
  lunge,
  reach,
  march,
  sideLift,
  seated,
  breathe,
  bridge,
  twist,
}

/// Pick a pose for a move by keyword. Falls back to a neutral standing figure.
WorkoutPose poseForMove(String name) {
  final n = name.toLowerCase();
  if (n.contains('box breath') || n.contains('breathing')) {
    return WorkoutPose.breathe;
  }
  if (n.contains('wall') &&
      (n.contains('push') ||
          n.contains('press-up') ||
          n.contains('press up'))) {
    return WorkoutPose.wallPress;
  }
  if (n.contains('sideways leg') || n.contains('side leg')) {
    return WorkoutPose.sideLift;
  }
  if (n.contains('push') || n.contains('press-up') || n.contains('press up')) {
    return WorkoutPose.pushup;
  }
  if (n.contains('plank')) return WorkoutPose.plank;
  if (n.contains('lunge')) return WorkoutPose.lunge;
  if (n.contains('bridge')) return WorkoutPose.bridge;
  if (n.contains('squat') ||
      n.contains('sit-to-stand') ||
      n.contains('stand up')) {
    return WorkoutPose.squat;
  }
  if (n.contains('march') || n.contains('knee') || n.contains('hip march')) {
    return WorkoutPose.march;
  }
  if (n.contains('seated') ||
      n.contains('ankle') ||
      n.contains('cat') ||
      n.contains('hip circ')) {
    return WorkoutPose.seated;
  }
  if (n.contains('twist') ||
      n.contains('rotation') ||
      n.contains('roll') ||
      n.contains('neck')) {
    return WorkoutPose.twist;
  }
  if (n.contains('stretch') ||
      n.contains('opener') ||
      n.contains('reach') ||
      n.contains('hamstring') ||
      n.contains('calf') ||
      n.contains('breath') ||
      n.contains('box')) {
    return WorkoutPose.reach;
  }
  return WorkoutPose.stand;
}

/// A figure that breathes gently at rest and gives a little squash each time
/// [bump] changes (one per counted rep) — alive, not a static clip-art pose.
class WorkoutFigure extends StatefulWidget {
  const WorkoutFigure({
    super.key,
    required this.pose,
    required this.color,
    this.size = 150,
    this.bump = 0,
  });

  final WorkoutPose pose;
  final Color color;
  final double size;

  /// Increment to trigger a one-shot squash (e.g. on each rep tap).
  final int bump;

  @override
  State<WorkoutFigure> createState() => _WorkoutFigureState();
}

class _WorkoutFigureState extends State<WorkoutFigure>
    with TickerProviderStateMixin {
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);
  late final AnimationController _squash = AnimationController(
    vsync: this,
    duration: Motion.quick,
  );

  @override
  void didUpdateWidget(WorkoutFigure old) {
    super.didUpdateWidget(old);
    if (widget.bump != old.bump) {
      _squash.forward(from: 0).then((_) => _squash.reverse());
    }
  }

  @override
  void dispose() {
    _breathe.dispose();
    _squash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The breath was the one continuous loop in the app that never checked the
    // reduced-motion preference.
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still && _breathe.isAnimating) {
      _breathe.stop();
      _breathe.value = 0.5;
    } else if (!still && !_breathe.isAnimating) {
      _breathe.repeat(reverse: true);
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_breathe, _squash]),
        builder: (_, _) {
          final wave = Motion.ambient.transform(_breathe.value);
          final s = _squash.value;
          return Transform.scale(
            scaleY: 1 - 0.10 * s + 0.012 * wave,
            scaleX: 1 + 0.04 * s,
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _FigurePainter(
                pose: widget.pose,
                color: widget.color,
                breathe: wave,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Normalized joints (0..1 within the paint box).
class _Fig {
  const _Fig({
    required this.head,
    required this.shoulder,
    required this.hip,
    required this.elbowL,
    required this.handL,
    required this.elbowR,
    required this.handR,
    required this.kneeL,
    required this.footL,
    required this.kneeR,
    required this.footR,
    this.headR = 0.085,
  });
  final Offset head, shoulder, hip;
  final Offset elbowL, handL, elbowR, handR;
  final Offset kneeL, footL, kneeR, footR;
  final double headR;
}

const _poses = <WorkoutPose, _Fig>{
  WorkoutPose.stand: _Fig(
    head: Offset(0.50, 0.16),
    shoulder: Offset(0.50, 0.34),
    hip: Offset(0.50, 0.60),
    elbowL: Offset(0.41, 0.46),
    handL: Offset(0.39, 0.58),
    elbowR: Offset(0.59, 0.46),
    handR: Offset(0.61, 0.58),
    kneeL: Offset(0.45, 0.76),
    footL: Offset(0.44, 0.92),
    kneeR: Offset(0.55, 0.76),
    footR: Offset(0.56, 0.92),
  ),
  WorkoutPose.squat: _Fig(
    head: Offset(0.46, 0.22),
    shoulder: Offset(0.48, 0.38),
    hip: Offset(0.52, 0.58),
    elbowL: Offset(0.40, 0.42),
    handL: Offset(0.31, 0.45),
    elbowR: Offset(0.42, 0.46),
    handR: Offset(0.33, 0.49),
    kneeL: Offset(0.39, 0.66),
    footL: Offset(0.42, 0.90),
    kneeR: Offset(0.62, 0.66),
    footR: Offset(0.60, 0.90),
  ),
  WorkoutPose.pushup: _Fig(
    head: Offset(0.80, 0.42),
    shoulder: Offset(0.63, 0.48),
    hip: Offset(0.40, 0.58),
    elbowL: Offset(0.64, 0.62),
    handL: Offset(0.66, 0.74),
    elbowR: Offset(0.60, 0.62),
    handR: Offset(0.61, 0.74),
    kneeL: Offset(0.26, 0.66),
    footL: Offset(0.13, 0.74),
    kneeR: Offset(0.26, 0.68),
    footR: Offset(0.13, 0.76),
    headR: 0.075,
  ),
  WorkoutPose.wallPress: _Fig(
    head: Offset(0.38, 0.18),
    shoulder: Offset(0.42, 0.35),
    hip: Offset(0.40, 0.61),
    elbowL: Offset(0.55, 0.41),
    handL: Offset(0.72, 0.40),
    elbowR: Offset(0.57, 0.48),
    handR: Offset(0.73, 0.48),
    kneeL: Offset(0.34, 0.77),
    footL: Offset(0.28, 0.92),
    kneeR: Offset(0.48, 0.78),
    footR: Offset(0.52, 0.92),
  ),
  WorkoutPose.plank: _Fig(
    head: Offset(0.80, 0.46),
    shoulder: Offset(0.62, 0.52),
    hip: Offset(0.40, 0.60),
    elbowL: Offset(0.62, 0.66),
    handL: Offset(0.74, 0.70),
    elbowR: Offset(0.60, 0.66),
    handR: Offset(0.72, 0.70),
    kneeL: Offset(0.26, 0.68),
    footL: Offset(0.12, 0.74),
    kneeR: Offset(0.26, 0.70),
    footR: Offset(0.12, 0.76),
    headR: 0.075,
  ),
  WorkoutPose.lunge: _Fig(
    head: Offset(0.50, 0.18),
    shoulder: Offset(0.50, 0.34),
    hip: Offset(0.50, 0.55),
    elbowL: Offset(0.43, 0.46),
    handL: Offset(0.41, 0.55),
    elbowR: Offset(0.57, 0.46),
    handR: Offset(0.59, 0.55),
    kneeL: Offset(0.64, 0.72),
    footL: Offset(0.66, 0.90),
    kneeR: Offset(0.40, 0.76),
    footR: Offset(0.30, 0.92),
  ),
  WorkoutPose.reach: _Fig(
    head: Offset(0.50, 0.22),
    shoulder: Offset(0.50, 0.38),
    hip: Offset(0.50, 0.62),
    elbowL: Offset(0.43, 0.27),
    handL: Offset(0.40, 0.13),
    elbowR: Offset(0.57, 0.27),
    handR: Offset(0.60, 0.13),
    kneeL: Offset(0.46, 0.78),
    footL: Offset(0.45, 0.93),
    kneeR: Offset(0.54, 0.78),
    footR: Offset(0.55, 0.93),
  ),
  WorkoutPose.march: _Fig(
    head: Offset(0.50, 0.15),
    shoulder: Offset(0.50, 0.33),
    hip: Offset(0.50, 0.58),
    elbowL: Offset(0.41, 0.42),
    handL: Offset(0.40, 0.53),
    elbowR: Offset(0.60, 0.40),
    handR: Offset(0.62, 0.30),
    kneeL: Offset(0.58, 0.60),
    footL: Offset(0.60, 0.71),
    kneeR: Offset(0.46, 0.78),
    footR: Offset(0.45, 0.92),
  ),
  WorkoutPose.sideLift: _Fig(
    head: Offset(0.47, 0.16),
    shoulder: Offset(0.47, 0.34),
    hip: Offset(0.48, 0.60),
    elbowL: Offset(0.35, 0.43),
    handL: Offset(0.27, 0.52),
    elbowR: Offset(0.58, 0.44),
    handR: Offset(0.62, 0.57),
    kneeL: Offset(0.45, 0.77),
    footL: Offset(0.44, 0.92),
    kneeR: Offset(0.66, 0.67),
    footR: Offset(0.79, 0.73),
  ),
  WorkoutPose.seated: _Fig(
    head: Offset(0.42, 0.22),
    shoulder: Offset(0.44, 0.38),
    hip: Offset(0.46, 0.60),
    elbowL: Offset(0.40, 0.48),
    handL: Offset(0.42, 0.58),
    elbowR: Offset(0.50, 0.48),
    handR: Offset(0.52, 0.58),
    kneeL: Offset(0.66, 0.60),
    footL: Offset(0.66, 0.88),
    kneeR: Offset(0.70, 0.61),
    footR: Offset(0.70, 0.88),
  ),
  WorkoutPose.breathe: _Fig(
    head: Offset(0.48, 0.18),
    shoulder: Offset(0.48, 0.35),
    hip: Offset(0.48, 0.60),
    elbowL: Offset(0.40, 0.44),
    handL: Offset(0.48, 0.49),
    elbowR: Offset(0.56, 0.44),
    handR: Offset(0.48, 0.49),
    kneeL: Offset(0.40, 0.77),
    footL: Offset(0.39, 0.92),
    kneeR: Offset(0.56, 0.77),
    footR: Offset(0.57, 0.92),
  ),
  WorkoutPose.bridge: _Fig(
    head: Offset(0.18, 0.66),
    shoulder: Offset(0.30, 0.62),
    hip: Offset(0.56, 0.46),
    elbowL: Offset(0.24, 0.68),
    handL: Offset(0.16, 0.74),
    elbowR: Offset(0.24, 0.70),
    handR: Offset(0.16, 0.76),
    kneeL: Offset(0.74, 0.54),
    footL: Offset(0.80, 0.74),
    kneeR: Offset(0.74, 0.56),
    footR: Offset(0.82, 0.74),
    headR: 0.075,
  ),
  WorkoutPose.twist: _Fig(
    head: Offset(0.50, 0.18),
    shoulder: Offset(0.52, 0.36),
    hip: Offset(0.48, 0.60),
    elbowL: Offset(0.56, 0.42),
    handL: Offset(0.44, 0.44),
    elbowR: Offset(0.44, 0.42),
    handR: Offset(0.58, 0.45),
    kneeL: Offset(0.46, 0.78),
    footL: Offset(0.45, 0.92),
    kneeR: Offset(0.54, 0.78),
    footR: Offset(0.55, 0.92),
  ),
};

class _FigurePainter extends CustomPainter {
  _FigurePainter({
    required this.pose,
    required this.color,
    required this.breathe,
  });
  final WorkoutPose pose;
  final Color color;
  final double breathe;

  @override
  void paint(Canvas canvas, Size size) {
    final f = _poses[pose] ?? _poses[WorkoutPose.stand]!;
    final w = size.width, h = size.height;
    Offset p(Offset o) => Offset(o.dx * w, o.dy * h);

    final limb = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.034
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter
      ..color = color.withValues(alpha: 0.92);
    final spine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.036
      ..strokeCap = StrokeCap.square
      ..color = color;

    // Props are structural cues, not decoration. A beginner should never see
    // a floor push-up silhouette for a wall press, or a floating seated body.
    final prop = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.018
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter
      ..color = Palette.xpLight.withValues(alpha: 0.36);
    if (pose == WorkoutPose.wallPress) {
      canvas.drawLine(
        Offset(w * 0.79, h * 0.18),
        Offset(w * 0.79, h * 0.94),
        prop,
      );
      canvas.drawLine(
        Offset(w * 0.79, h * 0.18),
        Offset(w * 0.86, h * 0.13),
        prop,
      );
    }
    if (pose == WorkoutPose.seated) {
      final chair = Path()
        ..moveTo(w * 0.39, h * 0.57)
        ..lineTo(w * 0.76, h * 0.57)
        ..lineTo(w * 0.76, h * 0.63)
        ..lineTo(w * 0.43, h * 0.63)
        ..close();
      canvas.drawPath(chair, Paint()..color = color.withValues(alpha: 0.20));
      canvas.drawLine(
        Offset(w * 0.44, h * 0.62),
        Offset(w * 0.40, h * 0.91),
        prop,
      );
      canvas.drawLine(
        Offset(w * 0.72, h * 0.62),
        Offset(w * 0.74, h * 0.91),
        prop,
      );
    }
    if (pose == WorkoutPose.sideLift) {
      canvas.drawLine(
        Offset(w * 0.25, h * 0.48),
        Offset(w * 0.25, h * 0.94),
        prop,
      );
      canvas.drawLine(
        Offset(w * 0.18, h * 0.48),
        Offset(w * 0.32, h * 0.48),
        prop,
      );
    }
    if (pose == WorkoutPose.breathe) {
      final box = Path()
        ..moveTo(w * 0.48, h * 0.31)
        ..lineTo(w * 0.68, h * 0.49)
        ..lineTo(w * 0.48, h * 0.67)
        ..lineTo(w * 0.28, h * 0.49)
        ..close();
      canvas.drawPath(
        box,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.012
          ..color = color.withValues(alpha: 0.18 + breathe * 0.14),
      );
    }

    // a soft ground line for grounding (skipped for floor poses)
    if (pose != WorkoutPose.pushup &&
        pose != WorkoutPose.plank &&
        pose != WorkoutPose.bridge) {
      canvas.drawLine(
        Offset(w * 0.18, h * 0.95),
        Offset(w * 0.82, h * 0.95),
        Paint()
          ..color = color.withValues(alpha: 0.18)
          ..strokeWidth = w * 0.02
          ..strokeCap = StrokeCap.round,
      );
    }

    final path = Path()
      ..moveTo(p(f.shoulder).dx, p(f.shoulder).dy)
      ..lineTo(p(f.elbowL).dx, p(f.elbowL).dy)
      ..lineTo(p(f.handL).dx, p(f.handL).dy);
    final pathR = Path()
      ..moveTo(p(f.shoulder).dx, p(f.shoulder).dy)
      ..lineTo(p(f.elbowR).dx, p(f.elbowR).dy)
      ..lineTo(p(f.handR).dx, p(f.handR).dy);
    final legL = Path()
      ..moveTo(p(f.hip).dx, p(f.hip).dy)
      ..lineTo(p(f.kneeL).dx, p(f.kneeL).dy)
      ..lineTo(p(f.footL).dx, p(f.footL).dy);
    final legR = Path()
      ..moveTo(p(f.hip).dx, p(f.hip).dy)
      ..lineTo(p(f.kneeR).dx, p(f.kneeR).dy)
      ..lineTo(p(f.footR).dx, p(f.footR).dy);

    // Angular body planes preserve the existing, well-tested joint map while
    // lifting the art out of stick-figure territory. Every segment is a
    // tapered quadrilateral with one bright and one shadow facet.
    Path plane(Offset a, Offset b, double startWidth, double endWidth) {
      final delta = b - a;
      final length = delta.distance == 0 ? 1.0 : delta.distance;
      final normal = Offset(-delta.dy / length, delta.dx / length);
      return Path()
        ..moveTo((a + normal * startWidth).dx, (a + normal * startWidth).dy)
        ..lineTo((b + normal * endWidth).dx, (b + normal * endWidth).dy)
        ..lineTo((b - normal * endWidth).dx, (b - normal * endWidth).dy)
        ..lineTo((a - normal * startWidth).dx, (a - normal * startWidth).dy)
        ..close();
    }

    void drawPlane(Offset a, Offset b, double startWidth, double endWidth) {
      final shape = plane(a, b, startWidth, endWidth);
      canvas.drawPath(
        shape,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(color, Colors.white, 0.26)!.withValues(alpha: 0.82),
              color.withValues(alpha: 0.76),
              Color.lerp(color, Colors.black, 0.34)!.withValues(alpha: 0.86),
            ],
          ).createShader(shape.getBounds()),
      );
      canvas.drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.009
          ..strokeJoin = StrokeJoin.miter
          ..color = color.withValues(alpha: 0.66),
      );
    }

    drawPlane(p(f.shoulder), p(f.hip), w * 0.060, w * 0.076);
    drawPlane(p(f.shoulder), p(f.elbowL), w * 0.034, w * 0.029);
    drawPlane(p(f.elbowL), p(f.handL), w * 0.029, w * 0.021);
    drawPlane(p(f.shoulder), p(f.elbowR), w * 0.034, w * 0.029);
    drawPlane(p(f.elbowR), p(f.handR), w * 0.029, w * 0.021);
    drawPlane(p(f.hip), p(f.kneeL), w * 0.050, w * 0.038);
    drawPlane(p(f.kneeL), p(f.footL), w * 0.038, w * 0.024);
    drawPlane(p(f.hip), p(f.kneeR), w * 0.050, w * 0.038);
    drawPlane(p(f.kneeR), p(f.footR), w * 0.038, w * 0.024);

    canvas.drawPath(legL, limb);
    canvas.drawPath(legR, limb);
    canvas.drawLine(p(f.shoulder), p(f.hip), spine); // torso
    canvas.drawPath(path, limb);
    canvas.drawPath(pathR, limb);

    // neck + head (head bobs faintly with the breath)
    final headC = p(f.head) + Offset(0, -breathe * h * 0.006);
    canvas.drawLine(p(f.shoulder), headC, spine);
    final headR = w * f.headR;
    final head = Path();
    for (var i = 0; i < 6; i++) {
      final angle = -pi / 2 + i * pi / 3;
      final point = headC + Offset(cos(angle) * headR, sin(angle) * headR);
      if (i == 0) {
        head.moveTo(point.dx, point.dy);
      } else {
        head.lineTo(point.dx, point.dy);
      }
    }
    head.close();
    canvas.drawPath(
      head,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.28)!,
            color,
            Color.lerp(color, Colors.black, 0.30)!,
          ],
        ).createShader(head.getBounds()),
    );
    canvas.drawPath(
      head,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012
        ..strokeJoin = StrokeJoin.miter
        ..color = color.withValues(alpha: 0.72),
    );
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.pose != pose ||
      old.color != color ||
      (old.breathe - breathe).abs() > 0.03;
}
