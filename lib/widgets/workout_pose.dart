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
  plank,
  lunge,
  reach,
  march,
  seated,
  bridge,
  twist,
}

/// Pick a pose for a move by keyword. Falls back to a neutral standing figure.
WorkoutPose poseForMove(String name) {
  final n = name.toLowerCase();
  if (n.contains('push') || n.contains('press-up') || n.contains('press up')) {
    return WorkoutPose.pushup;
  }
  if (n.contains('plank')) return WorkoutPose.plank;
  if (n.contains('lunge')) return WorkoutPose.lunge;
  if (n.contains('bridge')) return WorkoutPose.bridge;
  if (n.contains('squat') || n.contains('sit-to-stand') || n.contains('stand up')) {
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
    if (widget.bump != old.bump) _squash.forward(from: 0).then((_) => _squash.reverse());
  }

  @override
  void dispose() {
    _breathe.dispose();
    _squash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  pose: widget.pose, color: widget.color, breathe: wave),
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
    head: Offset(0.50, 0.16), shoulder: Offset(0.50, 0.34), hip: Offset(0.50, 0.60),
    elbowL: Offset(0.41, 0.46), handL: Offset(0.39, 0.58),
    elbowR: Offset(0.59, 0.46), handR: Offset(0.61, 0.58),
    kneeL: Offset(0.45, 0.76), footL: Offset(0.44, 0.92),
    kneeR: Offset(0.55, 0.76), footR: Offset(0.56, 0.92),
  ),
  WorkoutPose.squat: _Fig(
    head: Offset(0.46, 0.22), shoulder: Offset(0.48, 0.38), hip: Offset(0.52, 0.58),
    elbowL: Offset(0.40, 0.42), handL: Offset(0.31, 0.45),
    elbowR: Offset(0.42, 0.46), handR: Offset(0.33, 0.49),
    kneeL: Offset(0.39, 0.66), footL: Offset(0.42, 0.90),
    kneeR: Offset(0.62, 0.66), footR: Offset(0.60, 0.90),
  ),
  WorkoutPose.pushup: _Fig(
    head: Offset(0.80, 0.42), shoulder: Offset(0.63, 0.48), hip: Offset(0.40, 0.58),
    elbowL: Offset(0.64, 0.62), handL: Offset(0.66, 0.74),
    elbowR: Offset(0.60, 0.62), handR: Offset(0.61, 0.74),
    kneeL: Offset(0.26, 0.66), footL: Offset(0.13, 0.74),
    kneeR: Offset(0.26, 0.68), footR: Offset(0.13, 0.76),
    headR: 0.075,
  ),
  WorkoutPose.plank: _Fig(
    head: Offset(0.80, 0.46), shoulder: Offset(0.62, 0.52), hip: Offset(0.40, 0.60),
    elbowL: Offset(0.62, 0.66), handL: Offset(0.74, 0.70),
    elbowR: Offset(0.60, 0.66), handR: Offset(0.72, 0.70),
    kneeL: Offset(0.26, 0.68), footL: Offset(0.12, 0.74),
    kneeR: Offset(0.26, 0.70), footR: Offset(0.12, 0.76),
    headR: 0.075,
  ),
  WorkoutPose.lunge: _Fig(
    head: Offset(0.50, 0.18), shoulder: Offset(0.50, 0.34), hip: Offset(0.50, 0.55),
    elbowL: Offset(0.43, 0.46), handL: Offset(0.41, 0.55),
    elbowR: Offset(0.57, 0.46), handR: Offset(0.59, 0.55),
    kneeL: Offset(0.64, 0.72), footL: Offset(0.66, 0.90),
    kneeR: Offset(0.40, 0.76), footR: Offset(0.30, 0.92),
  ),
  WorkoutPose.reach: _Fig(
    head: Offset(0.50, 0.22), shoulder: Offset(0.50, 0.38), hip: Offset(0.50, 0.62),
    elbowL: Offset(0.43, 0.27), handL: Offset(0.40, 0.13),
    elbowR: Offset(0.57, 0.27), handR: Offset(0.60, 0.13),
    kneeL: Offset(0.46, 0.78), footL: Offset(0.45, 0.93),
    kneeR: Offset(0.54, 0.78), footR: Offset(0.55, 0.93),
  ),
  WorkoutPose.march: _Fig(
    head: Offset(0.50, 0.15), shoulder: Offset(0.50, 0.33), hip: Offset(0.50, 0.58),
    elbowL: Offset(0.41, 0.42), handL: Offset(0.40, 0.53),
    elbowR: Offset(0.60, 0.40), handR: Offset(0.62, 0.30),
    kneeL: Offset(0.58, 0.60), footL: Offset(0.60, 0.71),
    kneeR: Offset(0.46, 0.78), footR: Offset(0.45, 0.92),
  ),
  WorkoutPose.seated: _Fig(
    head: Offset(0.42, 0.22), shoulder: Offset(0.44, 0.38), hip: Offset(0.46, 0.60),
    elbowL: Offset(0.40, 0.48), handL: Offset(0.42, 0.58),
    elbowR: Offset(0.50, 0.48), handR: Offset(0.52, 0.58),
    kneeL: Offset(0.66, 0.60), footL: Offset(0.66, 0.88),
    kneeR: Offset(0.70, 0.61), footR: Offset(0.70, 0.88),
  ),
  WorkoutPose.bridge: _Fig(
    head: Offset(0.18, 0.66), shoulder: Offset(0.30, 0.62), hip: Offset(0.56, 0.46),
    elbowL: Offset(0.24, 0.68), handL: Offset(0.16, 0.74),
    elbowR: Offset(0.24, 0.70), handR: Offset(0.16, 0.76),
    kneeL: Offset(0.74, 0.54), footL: Offset(0.80, 0.74),
    kneeR: Offset(0.74, 0.56), footR: Offset(0.82, 0.74),
    headR: 0.075,
  ),
  WorkoutPose.twist: _Fig(
    head: Offset(0.50, 0.18), shoulder: Offset(0.52, 0.36), hip: Offset(0.48, 0.60),
    elbowL: Offset(0.56, 0.42), handL: Offset(0.44, 0.44),
    elbowR: Offset(0.44, 0.42), handR: Offset(0.58, 0.45),
    kneeL: Offset(0.46, 0.78), footL: Offset(0.45, 0.92),
    kneeR: Offset(0.54, 0.78), footR: Offset(0.55, 0.92),
  ),
};

class _FigurePainter extends CustomPainter {
  _FigurePainter(
      {required this.pose, required this.color, required this.breathe});
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
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: 0.92);
    final spine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.058
      ..strokeCap = StrokeCap.round
      ..color = color;

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

    canvas.drawPath(legL, limb);
    canvas.drawPath(legR, limb);
    canvas.drawLine(p(f.shoulder), p(f.hip), spine); // torso
    canvas.drawPath(path, limb);
    canvas.drawPath(pathR, limb);

    // neck + head (head bobs faintly with the breath)
    final headC = p(f.head) + Offset(0, -breathe * h * 0.006);
    canvas.drawLine(p(f.shoulder), headC, spine);
    canvas.drawCircle(
      headC,
      w * f.headR,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    // a soft glow halo around the head
    canvas.drawCircle(
      headC,
      w * f.headR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.pose != pose ||
      old.color != color ||
      (old.breathe - breathe).abs() > 0.03;
}
