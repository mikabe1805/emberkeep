import 'package:flutter/material.dart';

import '../tokens.dart';

/// "Your Space" — a cozy, code-painted room the avatar lives in, that fills
/// with earned furniture as you grow (round-40, the home/world scaffold). The
/// painter switches on the unlocked piece-ids from content/furniture.dart.
/// Phase 1: a warm room + window + the pieces; later phases add placement,
/// nicer art, and visiting others' rooms.
class HomeRoom extends StatelessWidget {
  const HomeRoom({
    super.key,
    required this.unlocked,
    required this.child,
    this.aspect = 1.7,
  });

  /// Furniture piece-ids currently earned (see unlockedFurniture()).
  final Set<String> unlocked;

  /// The avatar, who stands on the floor in the middle of the room.
  final Widget child;
  final double aspect;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _RoomPainter(unlocked)),
            ),
            // the avatar, standing on the rug
            Align(
              alignment: const Alignment(0, 0.5),
              child: FractionallySizedBox(
                heightFactor: 0.58,
                child: FittedBox(child: child),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomPainter extends CustomPainter {
  _RoomPainter(this.unlocked);
  final Set<String> unlocked;
  bool has(String id) => unlocked.contains(id);

  // warm room palette
  static const _wall = Color(0xFF2E2229);
  static const _wallLow = Color(0xFF3A2C2A);
  static const _floor = Color(0xFF3C2C20);
  static const _wood = Color(0xFF4A3A2C);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final floorY = h * 0.66;

    // ── walls + floor ──────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTRB(0, 0, w, floorY),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_wall, _wallLow],
        ).createShader(Rect.fromLTRB(0, 0, w, floorY)),
    );
    canvas.drawRect(
      Rect.fromLTRB(0, floorY, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_floor, Color(0xFF2A1D14)],
        ).createShader(Rect.fromLTRB(0, floorY, w, h)),
    );
    // baseboard shadow
    canvas.drawRect(
      Rect.fromLTWH(0, floorY - 1.5, w, 3),
      Paint()..color = const Color(0x44000000),
    );

    _window(canvas, w, h);
    // back-to-front so nearer pieces overlap farther ones
    if (has('hearth')) _hearth(canvas, w, h, floorY);
    if (has('shelf')) _shelf(canvas, w, h);
    if (has('picture')) _picture(canvas, w, h);
    if (has('rug')) _rug(canvas, w, h, floorY);
    if (has('lamp')) _lamp(canvas, w, h, floorY);
    if (has('chair')) _chair(canvas, w, h, floorY);
    if (has('plant')) _plant(canvas, w, h, floorY);
    if (has('pet')) _pet(canvas, w, h, floorY);
  }

  void _window(Canvas canvas, double w, double h) {
    final fx = w * 0.07, fy = h * 0.13, fw = w * 0.26, fh = h * 0.3;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(fx, fy, fw, fh),
      const Radius.circular(6),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0xFF14100C)); // night sky
    // crescent moon
    final mc = Offset(fx + fw * 0.64, fy + fh * 0.34);
    canvas.drawCircle(mc, fw * 0.14, Paint()..color = Palette.xpLight);
    canvas.drawCircle(
      mc.translate(fw * 0.07, -fw * 0.04),
      fw * 0.14,
      Paint()..color = const Color(0xFF14100C),
    );
    // stars
    final star = Paint()..color = Palette.xpLight.withValues(alpha: 0.8);
    canvas.drawCircle(Offset(fx + fw * 0.24, fy + fh * 0.28), 1.4, star);
    canvas.drawCircle(Offset(fx + fw * 0.36, fy + fh * 0.58), 1.1, star);
    canvas.drawCircle(Offset(fx + fw * 0.2, fy + fh * 0.62), 1.0, star);
    // frame + mullions
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF5A4536);
    canvas.drawRRect(r, edge);
    final bar = Paint()
      ..color = const Color(0xFF5A4536)
      ..strokeWidth = 2;
    canvas.drawLine(
        Offset(fx, fy + fh / 2), Offset(fx + fw, fy + fh / 2), bar);
    canvas.drawLine(
        Offset(fx + fw / 2, fy), Offset(fx + fw / 2, fy + fh), bar);
  }

  void _rug(Canvas canvas, double w, double h, double floorY) {
    final c = Offset(w * 0.5, floorY + (h - floorY) * 0.62);
    final rx = w * 0.35, ry = (h - floorY) * 0.42;
    final rect = Rect.fromCenter(center: c, width: rx * 2, height: ry * 2);
    canvas.drawOval(
      rect,
      Paint()..color = const Color(0xFF6E4A55).withValues(alpha: 0.9),
    );
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Palette.xpLight.withValues(alpha: 0.25),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: rx * 1.4, height: ry * 1.4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF8A6070).withValues(alpha: 0.55),
    );
  }

  void _lamp(Canvas canvas, double w, double h, double floorY) {
    final x = w * 0.115;
    final baseY = floorY + (h - floorY) * 0.46;
    final topY = h * 0.22;
    // warm glow
    canvas.drawCircle(
      Offset(x, topY + 4),
      w * 0.1,
      Paint()
        ..color = Palette.honeyGlow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    // pole + base
    canvas.drawLine(
      Offset(x, topY + 8),
      Offset(x, baseY),
      Paint()
        ..color = _wood
        ..strokeWidth = 3,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(x, baseY), width: w * 0.08, height: (h - floorY) * 0.12),
      Paint()..color = _wood,
    );
    // shade
    final shade = Path()
      ..moveTo(x - w * 0.05, topY + 10)
      ..lineTo(x + w * 0.05, topY + 10)
      ..lineTo(x + w * 0.034, topY - 8)
      ..lineTo(x - w * 0.034, topY - 8)
      ..close();
    canvas.drawPath(shade, Paint()..color = Palette.xpLight);
  }

  void _shelf(Canvas canvas, double w, double h) {
    final x = w * 0.6, y = h * 0.26, sw = w * 0.3;
    canvas.drawRect(Rect.fromLTWH(x, y, sw, 4), Paint()..color = _wood);
    // book spines
    const cols = [Palette.success, Palette.verify, Palette.unlock, Palette.dread];
    for (var i = 0; i < 4; i++) {
      final bw = sw * 0.12;
      final bx = x + sw * 0.08 + i * (bw + sw * 0.06);
      final bh = h * (0.05 + (i.isEven ? 0.02 : 0.0));
      canvas.drawRect(
        Rect.fromLTWH(bx, y - bh, bw, bh),
        Paint()..color = cols[i].withValues(alpha: 0.85),
      );
    }
  }

  void _picture(Canvas canvas, double w, double h) {
    final x = w * 0.46, y = h * 0.14, pw = w * 0.16, ph = h * 0.16;
    final frame = Rect.fromLTWH(x, y, pw, ph);
    canvas.drawRect(frame, Paint()..color = const Color(0xFF1A1410));
    canvas.drawRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Palette.xp.withValues(alpha: 0.7),
    );
    // a tiny scene: a sun + a hill
    canvas.drawCircle(
      Offset(x + pw * 0.7, y + ph * 0.35),
      pw * 0.1,
      Paint()..color = Palette.xpLight.withValues(alpha: 0.8),
    );
    final hill = Path()
      ..moveTo(x, y + ph)
      ..lineTo(x + pw * 0.5, y + ph * 0.5)
      ..lineTo(x + pw, y + ph)
      ..close();
    canvas.drawPath(hill, Paint()..color = Palette.success.withValues(alpha: 0.7));
  }

  void _chair(Canvas canvas, double w, double h, double floorY) {
    final x = w * 0.76, seatY = floorY + (h - floorY) * 0.2;
    final cw = w * 0.16, seatH = (h - floorY) * 0.3;
    final col = Paint()..color = const Color(0xFF7A4F44);
    // back
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, seatY - seatH * 0.9, cw, seatH * 1.1),
        const Radius.circular(8),
      ),
      col,
    );
    // seat
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - cw * 0.1, seatY, cw * 1.2, seatH * 0.6),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF8A5C50),
    );
  }

  void _plant(Canvas canvas, double w, double h, double floorY) {
    final x = w * 0.88, baseY = floorY + (h - floorY) * 0.55;
    // pot
    final pot = Path()
      ..moveTo(x - w * 0.04, baseY)
      ..lineTo(x + w * 0.04, baseY)
      ..lineTo(x + w * 0.03, baseY + (h - floorY) * 0.3)
      ..lineTo(x - w * 0.03, baseY + (h - floorY) * 0.3)
      ..close();
    canvas.drawPath(pot, Paint()..color = const Color(0xFF8A5A3C));
    // leaves
    final leaf = Paint()..color = Palette.success.withValues(alpha: 0.9);
    for (final a in [-0.5, 0.0, 0.5]) {
      final tip = Offset(x + a * w * 0.05, baseY - (h * 0.13) * (1 - a.abs() * 0.4));
      final path = Path()
        ..moveTo(x, baseY)
        ..quadraticBezierTo(
            x + a * w * 0.06 - 6, baseY - h * 0.06, tip.dx, tip.dy)
        ..quadraticBezierTo(
            x + a * w * 0.06 + 6, baseY - h * 0.06, x, baseY);
      canvas.drawPath(path, leaf);
    }
  }

  void _hearth(Canvas canvas, double w, double h, double floorY) {
    final x = w * 0.2, y = floorY - (h - floorY) * 0.05;
    final hw = w * 0.2, hh = (h - floorY) * 0.95;
    // mantel
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - hw / 2 - 4, y - hh, hw + 8, hh),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF463A33),
    );
    // opening
    final open = RRect.fromRectAndCorners(
      Rect.fromLTWH(x - hw / 2 + 6, y - hh * 0.78, hw - 12, hh * 0.74),
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
    );
    canvas.drawRRect(open, Paint()..color = const Color(0xFF120C08));
    // fire glow + flames
    canvas.drawCircle(
      Offset(x, y - hh * 0.12),
      hw * 0.4,
      Paint()
        ..color = Palette.streak.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    for (final dx in [-0.18, 0.0, 0.18]) {
      final fx = x + dx * hw;
      final flame = Path()
        ..moveTo(fx - 5, y - hh * 0.06)
        ..quadraticBezierTo(fx - 7, y - hh * 0.3, fx, y - hh * 0.4)
        ..quadraticBezierTo(fx + 7, y - hh * 0.3, fx + 5, y - hh * 0.06)
        ..close();
      canvas.drawPath(
        flame,
        Paint()..color = Palette.xpLight.withValues(alpha: 0.9),
      );
    }
  }

  void _pet(Canvas canvas, double w, double h, double floorY) {
    final x = w * 0.66, y = floorY + (h - floorY) * 0.74;
    final col = Paint()..color = const Color(0xFFC9A06E);
    // curled body
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: w * 0.13, height: (h - floorY) * 0.34),
      col,
    );
    // head
    final hx = x - w * 0.05;
    canvas.drawCircle(Offset(hx, y - 2), w * 0.035, col);
    // ears
    for (final s in [-1.0, 1.0]) {
      final ear = Path()
        ..moveTo(hx + s * w * 0.02, y - w * 0.04)
        ..lineTo(hx + s * w * 0.04, y - w * 0.075)
        ..lineTo(hx + s * w * 0.045, y - w * 0.03)
        ..close();
      canvas.drawPath(ear, col);
    }
    // a sleepy closed eye
    canvas.drawArc(
      Rect.fromCircle(center: Offset(hx, y - 3), radius: w * 0.012),
      0,
      3.14,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF5A4030),
    );
  }

  @override
  bool shouldRepaint(_RoomPainter old) => old.unlocked != unlocked;
}
