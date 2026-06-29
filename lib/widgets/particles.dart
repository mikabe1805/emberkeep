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
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 850))
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
    // embers RISE and waver (candlelit), not confetti that falls — the
    // celebration shares a visual family with the firefly motes on the canvas.
    const lift = 72.0;
    final fade = (1 - t).clamp(0.0, 1.0);
    final paint = Paint();
    for (final p in particles) {
      // ease-out outward travel with drag, then a gentle decelerating rise
      final travel = 1 - pow(1 - t, 3).toDouble();
      final flick = sin(t * 7 + p.spin) * 4 * t; // sideways ember flicker
      final pos = origin +
          p.velocity * travel * p.drag +
          Offset(flick, -lift * travel);
      final a = fade * (0.6 + 0.4 * vibrancy).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: a);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * t);
      if (p.size > 4) {
        // a crisp spark fleck
        paint.maskFilter = null;
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset.zero, width: p.size, height: p.size * 0.4),
            paint);
      } else {
        // a glowing ember mote — soft bloom, like the ambient fireflies
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
        canvas.drawCircle(Offset.zero, p.size * (0.6 + 0.6 * fade), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
