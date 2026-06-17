import 'dart:math';

import 'package:flutter/material.dart';

/// One-shot particle burst. The single celebration system, parameterized:
/// [count] and [vibrancy] scale with achievement magnitude rather than each
/// event owning a bespoke animation (DESIGN.md §2).
class ParticleBurst extends StatefulWidget {
  const ParticleBurst({
    super.key,
    required this.origin,
    required this.colors,
    this.count = 18,
    this.vibrancy = 1.0,
    this.spread = 90,
    this.onDone,
  });

  /// Burst origin in the local space of the (full-screen) overlay.
  final Offset origin;
  final List<Color> colors;
  final int count;

  /// 0..1+ — scales particle size, speed and opacity.
  final double vibrancy;
  final double spread;
  final VoidCallback? onDone;

  @override
  State<ParticleBurst> createState() => _ParticleBurstState();
}

class _Particle {
  _Particle(this.velocity, this.color, this.size, this.drag, this.spin);
  final Offset velocity;
  final Color color;
  final double size;
  final double drag;
  final double spin;
}

class _ParticleBurstState extends State<ParticleBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _particles = List.generate(widget.count, (_) {
      final angle = rng.nextDouble() * 2 * pi;
      final speed =
          (0.4 + rng.nextDouble()) * widget.spread * (0.7 + widget.vibrancy);
      return _Particle(
        Offset(cos(angle), sin(angle) * 1.2) * speed,
        widget.colors[rng.nextInt(widget.colors.length)],
        (2.0 + rng.nextDouble() * 3.5) * (0.7 + 0.5 * widget.vibrancy),
        0.85 + rng.nextDouble() * 0.1,
        (rng.nextDouble() - 0.5) * 6,
      );
    });
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 750))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone?.call();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          size: Size.infinite,
          painter: _BurstPainter(
            t: _c.value,
            origin: widget.origin,
            particles: _particles,
            vibrancy: widget.vibrancy,
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.t,
    required this.origin,
    required this.particles,
    required this.vibrancy,
  });

  final double t;
  final Offset origin;
  final List<_Particle> particles;
  final double vibrancy;

  @override
  void paint(Canvas canvas, Size size) {
    const gravity = 110.0;
    final fade = (1 - t).clamp(0.0, 1.0);
    final paint = Paint();
    for (final p in particles) {
      // ease-out travel with drag, slight gravity pull
      final travel = 1 - pow(1 - t, 3).toDouble();
      final pos = origin +
          p.velocity * travel * p.drag +
          Offset(0, gravity * t * t);
      paint.color =
          p.color.withValues(alpha: fade * (0.6 + 0.4 * vibrancy).clamp(0, 1));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * t);
      // mix of sparks (rects) and dots
      if (p.size > 4) {
        canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.4),
            paint);
      } else {
        canvas.drawCircle(Offset.zero, p.size * fade, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
