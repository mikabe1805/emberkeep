import 'dart:math' show pi, sin;

import 'package:flutter/material.dart';

/// Code-painted stage scenes (round-62) — the cozy places the ember stands in
/// at its hero moments (skin try-on, share card, onboarding). These replace the
/// round-60 SDXL/FLUX backdrops (the owner found the generated art "obviously
/// AI"); every scene here is drawn in the same clean, warm, flat-painterly
/// style as the room. Each composition keeps its lower-centre OPEN so the
/// creature has somewhere to stand. [t] (0..1, optional) drives gentle ambient
/// — fireflies, flicker, falling snow, twinkling stars — and defaults to a
/// finished still frame (the shop thumbnails + goldens rely on that).
void paintStageScene(Canvas canvas, String id, Rect rect, {double t = 0}) {
  final w = rect.width, h = rect.height;
  Offset at(double x, double y) => rect.topLeft + Offset(w * x, h * y);

  void sky(List<Color> colors, [List<double>? stops]) => canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
            stops: stops,
          ).createShader(rect),
      );

  void glow(Offset c, double r, Color col, double alpha) => canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = col.withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.55),
      );

  void floor(double y, List<Color> colors) => canvas.drawRect(
        Rect.fromLTRB(rect.left, rect.top + h * y, rect.right, rect.bottom),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ).createShader(
              Rect.fromLTRB(rect.left, rect.top + h * y, rect.right, rect.bottom)),
      );

  void stars(List<Offset> pts, [double base = 0.8]) {
    for (var i = 0; i < pts.length; i++) {
      final tw = 0.7 + 0.3 * sin(t * 2 * pi + i * 1.7);
      canvas.drawCircle(at(pts[i].dx, pts[i].dy), w * 0.006 * (0.8 + 0.3 * tw),
          Paint()..color = const Color(0xFFFFF3D6).withValues(alpha: base * tw));
    }
  }

  // a soft round bush/tree-crown blob
  void blob(Offset c, double rw, double rh, Color col) => canvas.drawOval(
      Rect.fromCenter(center: c, width: rw, height: rh), Paint()..color = col);

  void plantPot(double x, double baseY, double scale, Color pot, Color leaf) {
    final bx = at(x, baseY);
    canvas.drawPath(
      Path()
        ..moveTo(bx.dx - w * 0.03 * scale, bx.dy)
        ..lineTo(bx.dx + w * 0.03 * scale, bx.dy)
        ..lineTo(bx.dx + w * 0.022 * scale, bx.dy + h * 0.12 * scale)
        ..lineTo(bx.dx - w * 0.022 * scale, bx.dy + h * 0.12 * scale)
        ..close(),
      Paint()..color = pot,
    );
    for (final a in [-0.55, 0.0, 0.55]) {
      final tip = Offset(bx.dx + a * w * 0.035 * scale,
          bx.dy - h * 0.13 * scale * (1 - a.abs() * 0.35));
      canvas.drawPath(
        Path()
          ..moveTo(bx.dx, bx.dy)
          ..quadraticBezierTo(bx.dx + a * w * 0.05 * scale - 4,
              bx.dy - h * 0.06 * scale, tip.dx, tip.dy)
          ..quadraticBezierTo(bx.dx + a * w * 0.05 * scale + 4,
              bx.dy - h * 0.06 * scale, bx.dx, bx.dy),
        Paint()..color = leaf,
      );
    }
  }

  // a small warm hanging lantern with a glow
  void lantern(double x, double y, double scale) {
    final c = at(x, y);
    glow(c, w * 0.06 * scale, const Color(0xFFF6C878), 0.7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: w * 0.03 * scale, height: h * 0.06 * scale),
          Radius.circular(w * 0.006)),
      Paint()..color = const Color(0xFFFBE6B0),
    );
    canvas.drawLine(Offset(c.dx, rect.top),
        Offset(c.dx, c.dy - h * 0.03 * scale), Paint()..color = const Color(0x55000000)..strokeWidth = 1);
  }

  switch (id) {
    case 'candleglow':
      sky(const [Color(0xFF3A2A24), Color(0xFF241713)]);
      floor(0.66, const [Color(0xFF2E211A), Color(0xFF1C130E)]);
      // a big soft pool of warm candlelight fills the whole scene
      glow(at(0.5, 0.5), w * 0.5, const Color(0xFFF3B45A), 0.4);
      glow(at(0.5, 0.46), w * 0.26, const Color(0xFFFFD98A), 0.35);
      // candles clustered off to the sides so they peek past the ember
      for (final spec in const [(0.24, 1.1), (0.32, 0.85), (0.72, 1.0), (0.8, 0.8)]) {
        final base = at(spec.$1, 0.68);
        final ch = h * 0.14 * spec.$2;
        final fl = 1 + 0.12 * sin(t * 2 * pi * 2 + spec.$1 * 30);
        glow(base.translate(0, -ch - h * 0.02), w * 0.04, const Color(0xFFFFDE9A), 0.85);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(base.dx - 3, base.dy - ch, 6, ch), Radius.circular(2)),
            Paint()..color = const Color(0xFFF0E2C8));
        canvas.drawPath(
          Path()
            ..moveTo(base.dx - 3, base.dy - ch)
            ..quadraticBezierTo(base.dx - 4, base.dy - ch - h * 0.045 * fl, base.dx, base.dy - ch - h * 0.07 * fl)
            ..quadraticBezierTo(base.dx + 4, base.dy - ch - h * 0.045 * fl, base.dx + 3, base.dy - ch)
            ..close(),
          Paint()..color = const Color(0xFFFFF0C4),
        );
      }
    case 'lamplight':
      sky(const [Color(0xFF3B2E2A), Color(0xFF261C18)]);
      floor(0.64, const [Color(0xFF3A2A20), Color(0xFF241610)]);
      // a tall reading lamp casting a gold pool
      final lx = 0.2;
      glow(at(lx, 0.24), w * 0.16, const Color(0xFFF6CE86), 0.7);
      canvas.drawPath(
        Path()
          ..moveTo(at(lx - 0.05, 0.3).dx, at(lx, 0.3).dy)
          ..lineTo(at(lx + 0.05, 0.3).dx, at(lx, 0.3).dy)
          ..lineTo(at(lx + 0.032, 0.18).dx, at(lx, 0.18).dy)
          ..lineTo(at(lx - 0.032, 0.18).dx, at(lx, 0.18).dy)
          ..close(),
        Paint()..color = const Color(0xFFEAD3A0),
      );
      canvas.drawLine(at(lx, 0.3), at(lx, 0.7), Paint()..color = const Color(0xFF4A3A2C)..strokeWidth = 3);
      glow(at(0.5, 0.75), w * 0.3, const Color(0xFFE0A860), 0.28);
      // an armchair silhouette to the right
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: at(0.8, 0.66), width: w * 0.26, height: h * 0.34), Radius.circular(w * 0.03)),
        Paint()..color = const Color(0xFF6E4A44),
      );
    case 'garden':
      sky(const [Color(0xFF3A2E52), Color(0xFF6A4A5E), Color(0xFFB57A66)], const [0.0, 0.55, 1.0]);
      floor(0.7, const [Color(0xFF37414A), Color(0xFF232A2E)]);
      // a soft dusk moon
      glow(at(0.78, 0.22), w * 0.1, const Color(0xFFFDE9C0), 0.5);
      canvas.drawCircle(at(0.78, 0.22), w * 0.045, Paint()..color = const Color(0xFFFDECC8));
      // lavender rows
      for (final x in const [0.1, 0.2, 0.82, 0.92]) {
        blob(at(x, 0.72), w * 0.11, h * 0.16, const Color(0xFF6E5A9A));
        blob(at(x, 0.68), w * 0.08, h * 0.1, const Color(0xFF8A76C0));
      }
      lantern(0.32, 0.4, 1.1);
      lantern(0.68, 0.34, 0.9);
      // fireflies
      for (var i = 0; i < 6; i++) {
        final fx = 0.2 + 0.6 * ((i * 0.37) % 1.0);
        final fy = 0.4 + 0.25 * sin(t * 2 * pi + i);
        glow(at(fx, fy), w * 0.012, const Color(0xFFDFF0A0), 0.7);
      }
    case 'autumn':
      sky(const [Color(0xFF4A3520), Color(0xFF8A5A2E), Color(0xFFC98A46)], const [0.0, 0.5, 1.0]);
      floor(0.68, const [Color(0xFF5A3A22), Color(0xFF3A2414)]);
      glow(at(0.7, 0.3), w * 0.22, const Color(0xFFF6C060), 0.4);
      // autumn tree crowns
      blob(at(0.2, 0.28), w * 0.34, h * 0.4, const Color(0xFFB5702E));
      blob(at(0.16, 0.22), w * 0.22, h * 0.26, const Color(0xFFD08A3A));
      blob(at(0.86, 0.3), w * 0.3, h * 0.36, const Color(0xFFA0662C));
      canvas.drawRect(Rect.fromCenter(center: at(0.2, 0.55), width: w * 0.05, height: h * 0.3),
          Paint()..color = const Color(0xFF4A3018));
      // a mossy stump (the open spot)
      canvas.drawOval(Rect.fromCenter(center: at(0.5, 0.74), width: w * 0.34, height: h * 0.14),
          Paint()..color = const Color(0xFF6B4A2A));
      canvas.drawOval(Rect.fromCenter(center: at(0.5, 0.72), width: w * 0.3, height: h * 0.1),
          Paint()..color = const Color(0xFF7E5A34));
      // drifting leaves
      for (var i = 0; i < 5; i++) {
        final lx = (i * 0.23 + t * 0.4) % 1.0;
        final ly = 0.2 + 0.5 * ((i * 0.31 + t) % 1.0);
        canvas.drawCircle(at(lx, ly), w * 0.01, Paint()..color = const Color(0xFFD0873C).withValues(alpha: 0.8));
      }
    case 'greenhouse':
      sky(const [Color(0xFF17242A), Color(0xFF22333A)]);
      floor(0.7, const [Color(0xFF2C3830), Color(0xFF1A241E)]);
      // glass roof lines
      final glass = Paint()..color = const Color(0x3387C0B0)..strokeWidth = 1.5;
      for (var i = 0; i <= 6; i++) {
        canvas.drawLine(at(i / 6, 0.0), at(0.5, 0.32), glass);
      }
      stars(const [Offset(0.3, 0.12), Offset(0.6, 0.08), Offset(0.8, 0.16)]);
      // leafy plants along the sides
      blob(at(0.12, 0.5), w * 0.2, h * 0.5, const Color(0xFF2E5A3E));
      blob(at(0.9, 0.52), w * 0.22, h * 0.5, const Color(0xFF356A46));
      plantPot(0.24, 0.78, 1.0, const Color(0xFF8A5A3C), const Color(0xFF6FB07E));
      plantPot(0.78, 0.8, 1.1, const Color(0xFF8A5A3C), const Color(0xFF5FA070));
      lantern(0.5, 0.3, 1.0);
    case 'bakery':
      sky(const [Color(0xFF4A3626), Color(0xFF33241A)]);
      floor(0.66, const [Color(0xFF6A4A30), Color(0xFF43301E)]);
      glow(at(0.5, 0.5), w * 0.4, const Color(0xFFF3B860), 0.28);
      // warm oven at the back-left with a firebox glow
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: at(0.2, 0.5), width: w * 0.24, height: h * 0.3), Radius.circular(w * 0.02)),
        Paint()..color = const Color(0xFF5A3A24));
      glow(at(0.2, 0.52), w * 0.09, const Color(0xFFFFC868), 0.8);
      // wooden shelves with little loaves on the right
      for (final sy in const [0.24, 0.42]) {
        canvas.drawRect(Rect.fromLTWH(at(0.55, sy).dx, at(0.55, sy).dy, w * 0.4, h * 0.02),
            Paint()..color = const Color(0xFF5A3E26));
        for (var i = 0; i < 4; i++) {
          canvas.drawOval(Rect.fromCenter(center: at(0.6 + i * 0.09, sy - 0.02), width: w * 0.06, height: h * 0.04),
              Paint()..color = const Color(0xFFC98A50));
        }
      }
    case 'library':
      sky(const [Color(0xFF232838), Color(0xFF2E2A38)]);
      floor(0.72, const [Color(0xFF3A2C34), Color(0xFF241A20)]);
      // tall bookshelves
      for (final sx in const [0.08, 0.86]) {
        canvas.drawRect(Rect.fromLTWH(at(sx, 0.0).dx, rect.top, w * 0.14, h * 0.72),
            Paint()..color = const Color(0xFF3A2A24));
        for (var r = 0; r < 5; r++) {
          for (var b = 0; b < 4; b++) {
            const cols = [Color(0xFF9BC08F), Color(0xFF93A7E0), Color(0xFFC9A3DC), Color(0xFFE0A865)];
            canvas.drawRect(
              Rect.fromLTWH(at(sx + 0.005 + b * 0.032, 0.05 + r * 0.13).dx,
                  at(sx, 0.05 + r * 0.13).dy, w * 0.026, h * 0.1),
              Paint()..color = cols[(r + b) % 4].withValues(alpha: 0.8),
            );
          }
        }
      }
      // a moon window between them
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: at(0.5, 0.26), width: w * 0.28, height: h * 0.3), Radius.circular(w * 0.02)),
          Paint()..color = const Color(0xFF141018));
      glow(at(0.55, 0.22), w * 0.06, const Color(0xFFF3ECD0), 0.6);
      canvas.drawCircle(at(0.55, 0.22), w * 0.05, Paint()..color = const Color(0xFFF3ECD0));
      stars(const [Offset(0.44, 0.2), Offset(0.6, 0.3)], 0.7);
    case 'rooftop':
      sky(const [Color(0xFF0E1428), Color(0xFF1E1E38), Color(0xFF3A2A40)], const [0.0, 0.6, 1.0]);
      stars(const [Offset(0.2, 0.15), Offset(0.4, 0.1), Offset(0.65, 0.14), Offset(0.85, 0.2), Offset(0.5, 0.24)]);
      glow(at(0.8, 0.2), w * 0.06, const Color(0xFFEFE6C0), 0.4);
      canvas.drawCircle(at(0.8, 0.2), w * 0.035, Paint()..color = const Color(0xFFEFE6C0));
      // city skyline silhouette with lit windows
      final sil = Paint()..color = const Color(0xFF10121F);
      const bx = [0.05, 0.2, 0.35, 0.6, 0.75, 0.92];
      const bh = [0.22, 0.32, 0.18, 0.3, 0.24, 0.16];
      for (var i = 0; i < bx.length; i++) {
        final top = 0.62 - bh[i];
        canvas.drawRect(Rect.fromLTWH(at(bx[i] - 0.06, top).dx, at(0, top).dy, w * 0.12, h), sil);
      }
      floor(0.62, const [Color(0xFF2E2630), Color(0xFF1C1720)]);
      // string lights across the top
      for (var i = 1; i < 8; i++) {
        glow(at(i / 8, 0.08 + 0.03 * sin(i.toDouble())), w * 0.012, const Color(0xFFF6C878), 0.7);
      }
    case 'seaside':
      sky(const [Color(0xFF3A3A5E), Color(0xFFB5763E), Color(0xFFF0C070)], const [0.0, 0.6, 1.0]);
      // low sun over the sea
      glow(at(0.7, 0.5), w * 0.2, const Color(0xFFFAD98A), 0.5);
      canvas.drawCircle(at(0.7, 0.5), w * 0.08, Paint()..color = const Color(0xFFFFE9B0));
      // sea band
      canvas.drawRect(Rect.fromLTRB(rect.left, rect.top + h * 0.55, rect.right, rect.top + h * 0.66),
          Paint()..color = const Color(0xFF6E6E8E));
      // shimmer line under the sun
      canvas.drawRect(Rect.fromLTWH(at(0.6, 0.56).dx, at(0, 0.56).dy, w * 0.2, h * 0.08),
          Paint()..color = const Color(0xFFFAD98A).withValues(alpha: 0.4));
      // porch deck
      floor(0.66, const [Color(0xFF7A5A3E), Color(0xFF4E3826)]);
      // a railing
      canvas.drawRect(Rect.fromLTWH(rect.left, at(0, 0.64).dy, w, h * 0.015), Paint()..color = const Color(0xFF8A6A48));
      for (var i = 0; i <= 8; i++) {
        canvas.drawRect(Rect.fromLTWH(at(i / 8, 0.64).dx - 2, at(0, 0.64).dy, 3, h * 0.06),
            Paint()..color = const Color(0xFF6E4E32));
      }
    case 'snownook':
      sky(const [Color(0xFF2A3040), Color(0xFF3A3A4E)]);
      floor(0.68, const [Color(0xFF4A3E44), Color(0xFF2E262C)]);
      // a window to the snowy night
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: at(0.5, 0.32), width: w * 0.5, height: h * 0.44), Radius.circular(w * 0.02)),
          Paint()..color = const Color(0xFF1A2230));
      // snowy hills through the glass
      canvas.drawPath(
        Path()
          ..moveTo(at(0.26, 0.5).dx, at(0, 0.5).dy)
          ..quadraticBezierTo(
              at(0.5, 0.42).dx, at(0, 0.42).dy, at(0.74, 0.5).dx, at(0, 0.5).dy)
          ..lineTo(at(0.74, 0.54).dx, at(0, 0.54).dy)
          ..lineTo(at(0.26, 0.54).dx, at(0, 0.54).dy)
          ..close(),
        Paint()..color = const Color(0xFFB8C4D8),
      );
      // falling snow
      for (var i = 0; i < 14; i++) {
        final sx = 0.27 + 0.46 * ((i * 0.137) % 1.0);
        final sy = 0.12 + 0.4 * ((i * 0.19 + t) % 1.0);
        canvas.drawCircle(at(sx, sy), w * 0.006, Paint()..color = Colors.white.withValues(alpha: 0.85));
      }
      // window frame cross
      final fr = Paint()..color = const Color(0xFF5A4536)..strokeWidth = 3;
      canvas.drawLine(at(0.5, 0.1), at(0.5, 0.54), fr);
      canvas.drawLine(at(0.25, 0.32), at(0.75, 0.32), fr);
      glow(at(0.16, 0.6), w * 0.1, const Color(0xFFF3B860), 0.4); // a warm candle inside
    default: // 'hearthside' — a warm fireside room (fire raised so it haloes
      // above the ember rather than hiding behind it)
      sky(const [Color(0xFF3A2A28), Color(0xFF281B18)]);
      floor(0.66, const [Color(0xFF4A3324), Color(0xFF2C1E14)]);
      // a broad stone fireplace + chimney across the back
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: at(0.5, 0.3), width: w * 0.5, height: h * 0.44),
              Radius.circular(w * 0.02)),
          Paint()..color = const Color(0xFF4A3A34));
      canvas.drawRRect(
          RRect.fromRectAndCorners(
              Rect.fromCenter(center: at(0.5, 0.36), width: w * 0.3, height: h * 0.3),
              topLeft: Radius.circular(w * 0.05), topRight: Radius.circular(w * 0.05)),
          Paint()..color = const Color(0xFF140C08));
      // firelight glowing out of the hearth, high enough to wrap the ember
      glow(at(0.5, 0.36), w * 0.26, const Color(0xFFF39A38), 0.75);
      glow(at(0.5, 0.34), w * 0.14, const Color(0xFFFFD98A), 0.6);
      for (final dx in const [-0.07, 0.0, 0.07]) {
        final base = at(0.5 + dx, 0.44);
        final fl = 1 + 0.14 * sin(t * 2 * pi * 2 + dx * 40);
        canvas.drawPath(
          Path()
            ..moveTo(base.dx - 6, base.dy)
            ..quadraticBezierTo(base.dx - 7, base.dy - h * 0.09 * fl, base.dx, base.dy - h * 0.16 * fl)
            ..quadraticBezierTo(base.dx + 7, base.dy - h * 0.09 * fl, base.dx + 6, base.dy)
            ..close(),
          Paint()
            ..shader = const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xFFE8915A), Color(0xFFF2CD93), Color(0xFFFFF4D9)])
                .createShader(Rect.fromLTWH(base.dx - 7, base.dy - h * 0.16, 14, h * 0.16)),
        );
      }
      plantPot(0.86, 0.8, 1.0, const Color(0xFF8A5A3C), const Color(0xFF6FA070));
  }

  // a soft warm vignette so the lit centre where the creature stands reads as
  // the heart of the scene
  canvas.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.1),
        radius: 1.0,
        colors: const [Color(0x00140C06), Color(0x59140C06)],
        stops: const [0.6, 1.0],
      ).createShader(rect),
  );
}
