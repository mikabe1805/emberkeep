import 'dart:math';

import 'package:flutter/material.dart';

import '../tokens.dart';

/// Hexagonal stats radar — your life as a build shape (DESIGN.md §4).
/// Honey-translucent fill, stat-colored vertex dots.
class StatRadar extends StatelessWidget {
  const StatRadar({super.key, required this.values, this.size = 230});

  final Map<Stat, int> values;
  final double size;

  @override
  Widget build(BuildContext context) {
    final maxValue =
        values.values.fold<int>(40, (m, v) => max(m, v)).toDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, t, _) => CustomPaint(
        size: Size.square(size),
        painter: _RadarPainter(
          values: {
            for (final e in values.entries)
              e.key: (e.value / maxValue).clamp(0.0, 1.0) * t,
          },
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.values});
  final Map<Stat, double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 30;
    final stats = Stat.values;

    Offset point(int i, double r) {
      final angle = -pi / 2 + 2 * pi * i / stats.length;
      return center + Offset(cos(angle), sin(angle)) * (radius * r);
    }

    // grid rings — faint candlelight lines
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x2EF2CD93);
    for (final ring in [0.33, 0.66, 1.0]) {
      final path = Path();
      for (var i = 0; i < stats.length; i++) {
        final p = point(i, ring);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, grid);
    }
    // axes
    for (var i = 0; i < stats.length; i++) {
      canvas.drawLine(center, point(i, 1.0), grid);
    }

    // value polygon — poured honey
    final poly = Path();
    for (var i = 0; i < stats.length; i++) {
      final v = max(0.06, values[stats[i]] ?? 0);
      final p = point(i, v);
      i == 0 ? poly.moveTo(p.dx, p.dy) : poly.lineTo(p.dx, p.dy);
    }
    poly.close();
    canvas.drawPath(
      poly,
      Paint()
        ..style = PaintingStyle.fill
        ..color = Palette.xpLight.withValues(alpha: 0.28),
    );
    canvas.drawPath(
      poly,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Palette.xp.withValues(alpha: 0.8),
    );

    // vertex dots + labels in each stat's color
    for (var i = 0; i < stats.length; i++) {
      final s = stats[i];
      final v = max(0.06, values[s] ?? 0);
      canvas.drawCircle(
        point(i, v),
        4,
        Paint()..color = s.color,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: s.abbr,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: s.color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelPos = point(i, 1.22);
      tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.values != values;
}
