import 'dart:math' show sin, pi;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../tokens.dart';

/// "Your Space" — a cozy, code-painted room the avatar lives in, that fills
/// with earned furniture as you grow (round-40, the home/world scaffold). The
/// painter switches on the unlocked piece-ids from content/furniture.dart.
/// Phase 1: a warm room + window + the pieces; later phases add placement,
/// nicer art, and visiting others' rooms.
const _defaultWall = [Color(0xFF2E2229), Color(0xFF3A2C2A)];
const _defaultFloor = [Color(0xFF3C2C20), Color(0xFF2A1D14)];

class HomeRoom extends StatelessWidget {
  const HomeRoom({
    super.key,
    required this.unlocked,
    required this.child,
    this.aspect = 1.7,
    this.wall = _defaultWall,
    this.floor = _defaultFloor,
    this.window = 'moon',
    this.petAwake = false,
  });

  /// Furniture piece-ids the player owns (GameState.ownedFurniture) — what
  /// the room draws. Bought in the shop with embers (content/furniture.dart).
  final Set<String> unlocked;

  /// The avatar, who stands on the floor in the middle of the room.
  final Widget child;
  final double aspect;

  /// The chosen wall / floor gradient colours (content/room_styles.dart) — two
  /// stops each. Default = the original Walnut/Oak look.
  final List<Color> wall;
  final List<Color> floor;

  /// The scene painted outside the window (content/window_scenes.dart).
  final String window;

  /// Whether the companion is awake + happy (on a streak) vs cozily asleep.
  final bool petAwake;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                  painter:
                      _RoomPainter(unlocked, wall, floor, window, petAwake)),
            ),
            // the avatar, standing on the floor in the middle of the room
            Align(
              alignment: const Alignment(0, 0.7),
              child: FractionallySizedBox(
                heightFactor: 0.52,
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
  _RoomPainter(this.unlocked, this.wall, this.floor, this.window, this.petAwake);
  final Set<String> unlocked;
  final List<Color> wall;
  final List<Color> floor;
  final String window;
  final bool petAwake;
  bool has(String id) => unlocked.contains(id);

  // furniture wood tone (independent of the chosen wall/floor)
  static const _wood = Color(0xFF4A3A2C);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final floorY = h * 0.66;

    // ── walls + floor (recoloured by the chosen room style) ─────────
    canvas.drawRect(
      Rect.fromLTRB(0, 0, w, floorY),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: wall,
        ).createShader(Rect.fromLTRB(0, 0, w, floorY)),
    );
    canvas.drawRect(
      Rect.fromLTRB(0, floorY, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: floor,
        ).createShader(Rect.fromLTRB(0, floorY, w, h)),
    );
    // baseboard shadow
    canvas.drawRect(
      Rect.fromLTWH(0, floorY - 1.5, w, 3),
      Paint()..color = const Color(0x44000000),
    );

    _window(canvas, w, h);
    // back-to-front so nearer pieces overlap farther ones
    if (has('garland')) _garland(canvas, w, h);
    if (has('hearth')) _hearth(canvas, w, h, floorY);
    if (has('shelf')) _shelf(canvas, w, h);
    if (has('picture')) _picture(canvas, w, h);
    if (has('rug')) _rug(canvas, w, h, floorY);
    if (has('cushion')) _cushion(canvas, w, h, floorY);
    if (has('lamp')) _lamp(canvas, w, h, floorY);
    if (has('chair')) _chair(canvas, w, h, floorY);
    if (has('candles')) _candles(canvas, w, h, floorY);
    if (has('plant')) _plant(canvas, w, h, floorY);
    if (has('pet')) _pet(canvas, w, h, floorY, petAwake);
  }

  void _window(Canvas canvas, double w, double h) {
    final fx = w * 0.07, fy = h * 0.13, fw = w * 0.26, fh = h * 0.3;
    final rect = Rect.fromLTWH(fx, fy, fw, fh);
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    // the view outside (clipped to the pane)
    paintWindowScene(canvas, window, rect);
    // frame + mullions on top
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

  // A little companion (round-50): curled cozily asleep, or — when you're on a
  // streak — awake and beaming up at you. Never-punish: sleeping is rest, not
  // a scold; the warmth is the reward for showing up.
  void _pet(Canvas canvas, double w, double h, double floorY, bool awake) {
    final u = h - floorY;
    final cx = w * 0.66;
    final baseY = floorY + u * 0.92;
    final tan = Paint()..color = const Color(0xFFCBA471);
    final tanLight = const Color(0xFFE0C091);
    const ink = Color(0xFF5A4030);

    // contact shadow
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, baseY), width: w * 0.17, height: u * 0.06),
      Paint()..color = const Color(0x33000000),
    );

    void ear(Offset c, double s, double size) {
      final p = Path()
        ..moveTo(c.dx + s * size * 0.4, c.dy + size * 0.3)
        ..lineTo(c.dx + s * size, c.dy - size)
        ..lineTo(c.dx + s * size * 1.5, c.dy + size * 0.1)
        ..close();
      canvas.drawPath(p, tan);
    }

    if (!awake) {
      // ── asleep: a curled, rounded loaf with a tail wrapped to the front ──
      final bodyC = Offset(cx, baseY - u * 0.1);
      canvas.drawOval(
        Rect.fromCenter(
            center: bodyC, width: w * 0.17, height: u * 0.24),
        tan,
      );
      // tail curling around the front
      final tail = Path()
        ..moveTo(cx + w * 0.08, baseY - u * 0.06)
        ..quadraticBezierTo(
            cx + w * 0.12, baseY - u * 0.2, cx + w * 0.02, baseY - u * 0.16);
      canvas.drawPath(
        tail,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.08
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFE0C091),
      );
      // head resting on the left
      final hc = Offset(cx - w * 0.06, baseY - u * 0.13);
      canvas.drawCircle(hc, w * 0.042, tan);
      ear(hc.translate(-w * 0.025, -w * 0.02), -1, w * 0.03);
      ear(hc.translate(w * 0.01, -w * 0.025), 1, w * 0.03);
      // a sleepy closed eye
      canvas.drawArc(
        Rect.fromCircle(center: hc.translate(w * 0.005, 0), radius: w * 0.014),
        0,
        pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = ink,
      );
      // Zzz drifting up
      final z = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = Palette.xpLight.withValues(alpha: 0.6);
      for (var i = 0; i < 3; i++) {
        final s = w * (0.018 - i * 0.004);
        final zx = hc.dx + w * 0.04 + i * w * 0.025;
        final zy = hc.dy - u * 0.12 - i * u * 0.07;
        canvas.drawLine(Offset(zx, zy), Offset(zx + s, zy), z);
        canvas.drawLine(Offset(zx + s, zy), Offset(zx, zy + s), z);
        canvas.drawLine(Offset(zx, zy + s), Offset(zx + s, zy + s), z);
      }
    } else {
      // ── awake: sitting up, beaming up at you ──
      // tail to the side
      final tail = Path()
        ..moveTo(cx + w * 0.05, baseY - u * 0.06)
        ..quadraticBezierTo(
            cx + w * 0.13, baseY - u * 0.04, cx + w * 0.11, baseY - u * 0.2);
      canvas.drawPath(
        tail,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.06
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFE0C091),
      );
      // body sitting
      final bodyC = Offset(cx, baseY - u * 0.16);
      canvas.drawOval(
        Rect.fromCenter(
            center: bodyC, width: w * 0.12, height: u * 0.3),
        tan,
      );
      // belly highlight
      canvas.drawOval(
        Rect.fromCenter(
            center: bodyC.translate(0, u * 0.04),
            width: w * 0.07,
            height: u * 0.16),
        Paint()..color = tanLight.withValues(alpha: 0.6),
      );
      // head up
      final hc = Offset(cx, baseY - u * 0.34);
      canvas.drawCircle(hc, w * 0.058, tan);
      ear(hc.translate(-w * 0.05, -w * 0.01), -1, w * 0.038);
      ear(hc.translate(w * 0.012, -w * 0.01), 1, w * 0.038);
      // big eyes with catchlights, looking up toward the ember
      for (final s in [-1.0, 1.0]) {
        final ec = hc.translate(s * w * 0.025, -w * 0.004);
        canvas.drawOval(
          Rect.fromCenter(
              center: ec, width: w * 0.018, height: w * 0.024),
          Paint()..color = ink,
        );
        canvas.drawCircle(ec.translate(-w * 0.004, -w * 0.006), w * 0.006,
            Paint()..color = Colors.white.withValues(alpha: 0.9));
      }
      // a happy little smile
      canvas.drawArc(
        Rect.fromCenter(
            center: hc.translate(0, w * 0.02),
            width: w * 0.03,
            height: w * 0.022),
        pi * 0.1,
        pi * 0.8,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round
          ..color = ink,
      );
      // rosy cheeks
      final blush = Paint()
        ..color = const Color(0x44D88A8A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(hc.translate(-w * 0.045, w * 0.012), w * 0.014, blush);
      canvas.drawCircle(hc.translate(w * 0.045, w * 0.012), w * 0.014, blush);
    }
  }

  // a string of warm bulbs draped across the upper wall (sags in the middle)
  void _garland(Canvas canvas, double w, double h) {
    final left = Offset(w * 0.36, h * 0.07);
    final right = Offset(w * 0.97, h * 0.09);
    final mid = Offset((left.dx + right.dx) / 2, h * 0.07 + h * 0.07); // sag
    final wire = Path()
      ..moveTo(left.dx, left.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, right.dx, right.dy);
    canvas.drawPath(
      wire,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF5A4536),
    );
    const bulbs = 7;
    for (var i = 1; i < bulbs; i++) {
      final t = i / bulbs, mt = 1 - (i / bulbs);
      final bx = mt * mt * left.dx + 2 * mt * t * mid.dx + t * t * right.dx;
      final by = mt * mt * left.dy + 2 * mt * t * mid.dy + t * t * right.dy;
      canvas.drawCircle(
        Offset(bx, by + 3),
        4.5,
        Paint()
          ..color = Palette.honeyGlow.withValues(alpha: 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
          Offset(bx, by + 3), 2.2, Paint()..color = Palette.xpLight);
    }
  }

  // a soft floor cushion to the left of the avatar
  void _cushion(Canvas canvas, double w, double h, double floorY) {
    final c = Offset(w * 0.3, floorY + (h - floorY) * 0.52);
    final cw = w * 0.1, ch = (h - floorY) * 0.26;
    canvas.drawOval(
      Rect.fromCenter(
          center: c.translate(0, ch * 0.5), width: cw * 1.2, height: ch * 0.3),
      Paint()..color = const Color(0x55000000), // contact shadow
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: cw, height: ch),
        Radius.circular(ch * 0.5),
      ),
      Paint()..color = const Color(0xFF8A6070),
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: c.translate(-cw * 0.12, -ch * 0.18),
          width: cw * 0.5,
          height: ch * 0.3),
      Paint()..color = Palette.specular.withValues(alpha: 0.12),
    );
  }

  // a little cluster of three candles glowing on the floor
  void _candles(Canvas canvas, double w, double h, double floorY) {
    final baseY = floorY + (h - floorY) * 0.42;
    for (final spec in [(-0.04, 0.9), (0.0, 1.15), (0.04, 0.8)]) {
      final cx = w * 0.4 + spec.$1 * w;
      final ch = (h - floorY) * 0.22 * spec.$2;
      canvas.drawCircle(
        Offset(cx, baseY - ch - 4),
        8,
        Paint()
          ..color = Palette.honeyGlow.withValues(alpha: 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 3, baseY - ch, 6, ch),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFFF0E2C8),
      );
      final flame = Path()
        ..moveTo(cx - 2, baseY - ch)
        ..quadraticBezierTo(cx - 3, baseY - ch - 6, cx, baseY - ch - 9)
        ..quadraticBezierTo(cx + 3, baseY - ch - 6, cx + 2, baseY - ch)
        ..close();
      canvas.drawPath(flame, Paint()..color = Palette.xpLight);
    }
  }

  @override
  bool shouldRepaint(_RoomPainter old) =>
      old.unlocked != unlocked ||
      old.window != window ||
      old.petAwake != petAwake ||
      !listEquals(old.wall, wall) ||
      !listEquals(old.floor, floor);
}

/// Paints the landscape inside a window pane [rect] for the chosen [scene]
/// (content/window_scenes.dart). Public so the shop's preview swatch can reuse
/// it. Clips to the pane; the caller draws the frame on top.
void paintWindowScene(Canvas canvas, String scene, Rect rect) {
  final fx = rect.left, fy = rect.top, fw = rect.width, fh = rect.height;
  final rr = RRect.fromRectAndRadius(rect, const Radius.circular(6));
  canvas.save();
  canvas.clipRRect(rr);

  Offset at(double x, double y) => Offset(fx + fw * x, fy + fh * y);
  final star = Paint()..color = Palette.xpLight.withValues(alpha: 0.85);
  void stars(List<Offset> pts) {
    for (var i = 0; i < pts.length; i++) {
      canvas.drawCircle(at(pts[i].dx, pts[i].dy), 1.3 - (i.isOdd ? 0.4 : 0), star);
    }
  }

  void sky(List<Color> colors) => canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ).createShader(rect),
      );
  void fullMoon(double x, double y, double rFrac) =>
      canvas.drawCircle(at(x, y), fw * rFrac, Paint()..color = Palette.xpLight);

  switch (scene) {
    case 'city':
      sky(const [Color(0xFF161A2E), Color(0xFF241A2A)]);
      stars(const [Offset(0.18, 0.18), Offset(0.42, 0.12), Offset(0.8, 0.2)]);
      fullMoon(0.2, 0.24, 0.08);
      // skyline silhouette with lit windows
      final sil = Paint()..color = const Color(0xFF0A0C16);
      final lit = Paint()..color = const Color(0xFFE8C77A);
      const bx = [0.08, 0.26, 0.42, 0.58, 0.74, 0.88];
      const bh = [0.34, 0.5, 0.28, 0.46, 0.36, 0.24];
      for (var i = 0; i < bx.length; i++) {
        final bw = fw * 0.13;
        final top = fy + fh * (1 - bh[i]);
        canvas.drawRect(
            Rect.fromLTWH(fx + fw * bx[i] - bw / 2, top, bw, fh), sil);
        for (var r = 0; r < 3; r++) {
          for (var c = 0; c < 2; c++) {
            if ((i + r + c).isEven) continue;
            canvas.drawRect(
              Rect.fromLTWH(fx + fw * bx[i] - bw * 0.28 + c * bw * 0.34,
                  top + fh * 0.06 + r * fh * 0.1, fw * 0.022, fh * 0.04),
              lit,
            );
          }
        }
      }
    case 'forest':
      sky(const [Color(0xFF101A14), Color(0xFF16140E)]);
      stars(const [Offset(0.2, 0.18), Offset(0.5, 0.14), Offset(0.34, 0.3)]);
      fullMoon(0.72, 0.26, 0.11);
      final tree = Paint()..color = const Color(0xFF0A140E);
      const tx = [0.1, 0.26, 0.44, 0.62, 0.8, 0.94];
      const th = [0.42, 0.56, 0.46, 0.6, 0.5, 0.4];
      for (var i = 0; i < tx.length; i++) {
        final baseY = fy + fh;
        final topY = fy + fh * (1 - th[i]);
        final cxp = fx + fw * tx[i], halfW = fw * 0.07;
        final p = Path()
          ..moveTo(cxp, topY)
          ..lineTo(cxp - halfW, baseY)
          ..lineTo(cxp + halfW, baseY)
          ..close();
        canvas.drawPath(p, tree);
      }
    case 'mountains':
      sky(const [Color(0xFF1A2236), Color(0xFF2A2438)]);
      stars(const [Offset(0.16, 0.16), Offset(0.6, 0.12), Offset(0.84, 0.22)]);
      fullMoon(0.78, 0.22, 0.09);
      final back = Paint()..color = const Color(0xFF2C3450);
      final front = Paint()..color = const Color(0xFF161C2C);
      Path ridge(double baseFrac, List<double> peaks) {
        final p = Path()..moveTo(fx, fy + fh);
        final n = peaks.length;
        for (var i = 0; i < n; i++) {
          p.lineTo(fx + fw * (i / (n - 1)), fy + fh * (1 - peaks[i]));
        }
        p..lineTo(fx + fw, fy + fh)..close();
        return p;
      }
      canvas.drawPath(ridge(0, const [0.3, 0.5, 0.36, 0.56, 0.34]), back);
      canvas.drawPath(ridge(0, const [0.18, 0.34, 0.22, 0.4, 0.2, 0.36]), front);
    case 'rain':
      sky(const [Color(0xFF14100C), Color(0xFF181820)]);
      // dim crescent behind the rain
      canvas.drawCircle(at(0.66, 0.3), fw * 0.12,
          Paint()..color = Palette.xpLight.withValues(alpha: 0.7));
      canvas.drawCircle(at(0.72, 0.27), fw * 0.12,
          Paint()..color = const Color(0xFF14100C));
      final drop = Paint()
        ..color = const Color(0xFFAEB8D0).withValues(alpha: 0.5)
        ..strokeWidth = 1;
      for (var i = 0; i < 22; i++) {
        final x = fx + fw * ((i * 0.137) % 1.0);
        final y = fy + fh * ((i * 0.231) % 1.0);
        canvas.drawLine(Offset(x, y), Offset(x - fw * 0.03, y + fh * 0.1), drop);
      }
    case 'dawn':
      sky(const [Color(0xFF3A2A4A), Color(0xFFB5683E), Color(0xFFE8B570)]);
      // a low sun with a soft glow
      canvas.drawCircle(at(0.3, 0.62), fw * 0.3,
          Paint()
            ..color = const Color(0xFFF6D79A).withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawCircle(
          at(0.3, 0.62), fw * 0.13, Paint()..color = const Color(0xFFFFE9B8));
      // hill silhouette
      final hill = Path()
        ..moveTo(fx, fy + fh)
        ..lineTo(fx, fy + fh * 0.78)
        ..quadraticBezierTo(
            fx + fw * 0.5, fy + fh * 0.66, fx + fw, fy + fh * 0.8)
        ..lineTo(fx + fw, fy + fh)
        ..close();
      canvas.drawPath(hill, Paint()..color = const Color(0xFF6E4A38));
    case 'aurora':
      sky(const [Color(0xFF0A1220), Color(0xFF101A26)]);
      stars(const [
        Offset(0.2, 0.2), Offset(0.5, 0.14), Offset(0.8, 0.24), Offset(0.66, 0.4)
      ]);
      // wavy aurora bands, blurred
      for (final band in [
        (0.28, const Color(0xFF6FE0A0)),
        (0.5, const Color(0xFF8FD0E0)),
        (0.72, const Color(0xFFB58AE0)),
      ]) {
        final p = Path()..moveTo(fx, fy + fh * 0.5);
        for (var i = 0; i <= 6; i++) {
          final x = fx + fw * (i / 6);
          final y = fy +
              fh * (0.34 + 0.12 * sin(i * 1.3 + band.$1 * 6) + band.$1 * 0.18);
          p.lineTo(x, y);
        }
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = fh * 0.08
            ..color = band.$2.withValues(alpha: 0.45)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, fh * 0.04),
        );
      }
    default: // 'moon' — the classic moonlit night
      canvas.drawRect(rect, Paint()..color = const Color(0xFF14100C));
      canvas.drawCircle(at(0.64, 0.34), fw * 0.14, Paint()..color = Palette.xpLight);
      canvas.drawCircle(at(0.64, 0.34).translate(fw * 0.07, -fw * 0.04),
          fw * 0.14, Paint()..color = const Color(0xFF14100C));
      stars(const [Offset(0.24, 0.28), Offset(0.36, 0.58), Offset(0.2, 0.62)]);
  }
  canvas.restore();
}
