// The victory chest and the pieces of loot that come out of it.
//
// A chest seen from the front: its lid lifts, light rises out of it and the
// loot floats up. The same loot drawings are the small marks in the Me trophy
// case. A port of the prototype's chest.
library;

import 'dart:math' as math;
import 'dart:ui' as ui show Gradient;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../core/brawl_monsters.dart' show BrawlChest;
import 'brawl_art.dart' show BrawlPen;
import 'brawl_fx.dart' show star4Path;

Color _hex(int rgb, [double a = 1]) =>
    Color.fromRGBO((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255, a);

double _clamp(double v, double a, double b) => v < a ? a : (v > b ? b : v);

/// Paints one piece of loot around ([x], [y]), about 36 units across at [s] 1.
void paintBrawlLoot(BrawlPen g, String name, double x, double y, double s) {
  final c = g.cv;
  c.save();
  c.translate(x, y);
  c.scale(s, s);
  switch (name) {
    case 'Doorstop Cushion':
      g.fillRR(-14, -9, 28, 18, 7, _hex(0xA85F5F));
      g.fillRR(-10, -7, 12, 4, 2, const Color.fromRGBO(255, 235, 200, 0.35));
      for (final p in const [
        [-14.0, -9.0],
        [14.0, -9.0],
        [-14.0, 9.0],
        [14.0, 9.0],
      ]) {
        g.fillCircle(p[0], p[1], 2.2, _hex(0xF3E6C8));
      }
    case 'Porch Lantern':
      g.arc(0, -10, 6, math.pi, 0, _hex(0xC9A56A), 2);
      g.fillRR(-9, -8, 18, 3, 1.5, _hex(0x4A2F1A));
      g.fillRR(-7, -5, 14, 15, 3, _hex(0xFFD28A));
      g.fillRR(-9, 9, 18, 3, 1.5, _hex(0x4A2F1A));
      g.fillCircle(0, 2, 3.4, const Color.fromRGBO(255, 240, 190, 0.9));
    case 'Golden Doormat':
      g.fillRR(-17, -7, 34, 14, 3, _hex(0xC9A56A));
      for (final y in const [-3.0, 1.0, 5.0]) {
        g.line(-13, y, 13, y, 1.4, _hex(0xFFE3A0));
      }
    case 'Dew Jar':
      g.fillRR(-9, -8, 18, 20, 6, const Color.fromRGBO(191, 224, 244, 0.5));
      g.fillRR(-6, -13, 12, 5, 2, _hex(0xC9A56A));
      g.fillCircle(0, 4, 4, _hex(0xBFE0F4));
      g.fillPath(
        Path()
          ..moveTo(-4, 4)
          ..lineTo(0, -5)
          ..lineTo(4, 4)
          ..close(),
        _hex(0xBFE0F4),
      );
    case 'Rain Chain':
      g.line(0, -14, 0, 14, 1.6, _hex(0xC9A56A), cap: StrokeCap.butt);
      for (final p in const [
        [-5.0, -6.0],
        [5.0, 3.0],
        [-5.0, 11.0],
      ]) {
        g.fillPath(
          Path()
            ..moveTo(p[0] - 6, p[1])
            ..lineTo(p[0] + 6, p[1])
            ..lineTo(p[0] + 4, p[1] + 7)
            ..lineTo(p[0] - 4, p[1] + 7)
            ..close(),
          _hex(0xE5C896),
        );
      }
    default: // Cloud Lamp
      g.fillCircle(0, 0, 18, const Color.fromRGBO(255, 230, 170, 0.35));
      for (final cc in const [
        [-8.0, 3.0, 8.0],
        [0.0, -2.0, 10.0],
        [8.0, 3.0, 8.0],
      ]) {
        g.fillCircle(cc[0], cc[1], cc[2], _hex(0xE6EEF5));
      }
      g.fillCircle(0, 6, 4, _hex(0xFFE3A0));
  }
  c.restore();
}

/// The chest, opening. [t] is seconds since it appeared.
class BrawlChestPainter extends CustomPainter {
  BrawlChestPainter({
    required this.time,
    required this.chest,
    required this.loot,
    this.still = false,
  }) : super(repaint: time);

  final ValueListenable<double> time;
  final BrawlChest chest;
  final String loot;

  /// Reduce Motion: the chest is already open, nothing floats.
  final bool still;

  final BrawlPen _pen = BrawlPen();

  @override
  void paint(Canvas canvas, Size size) {
    const w = 124.0, h = 112.0;
    final k = math.min(size.width / w, size.height / h);
    canvas.save();
    canvas.translate((size.width - w * k) / 2, (size.height - h * k) / 2);
    canvas.scale(k);
    final g = _pen..cv = canvas;
    final t = still ? 3.0 : time.value;
    double easeOut(double u) => 1 - math.pow(1 - u, 3).toDouble();
    double easeBack(double u) {
      const c1 = 1.8, c3 = c1 + 1;
      return 1 + c3 * math.pow(u - 1, 3) + c1 * math.pow(u - 1, 2);
    }

    final openK = _clamp((t - 0.25) / 0.7, 0, 1);
    final open = easeBack(openK);
    final wood = switch (chest) {
      BrawlChest.patient => [_hex(0x8a5a36), _hex(0x6a4226)],
      BrawlChest.steady => [_hex(0x7a4a2a), _hex(0x5a3820)],
      BrawlChest.swift => [_hex(0x6a3a28), _hex(0x4a2a1c)],
    };
    final band = switch (chest) {
      BrawlChest.patient => _hex(0x7c7468),
      BrawlChest.steady => _hex(0xC9A56A),
      BrawlChest.swift => _hex(0xF2B04A),
    };
    const cx = w / 2, by = 100.0;
    final p = Paint()..isAntiAlias = true;
    if (openK > 0) {
      p
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          const Offset(cx, by - 38),
          62 * openK + 10,
          [_hex(0xFFE6A0, 0.75 * openK), _hex(0xFFBE5A, 0)],
          const [0, 1],
        );
      canvas.drawCircle(const Offset(cx, by - 38), 72, p);
      p.shader = null;
      for (var i = 0; i < 7; i++) {
        final a = -math.pi / 2 + (i - 3) * 0.2 + math.sin(t * 0.7 + i) * 0.04;
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = _hex(0xFFECB4, 0.2 * openK);
        canvas.drawLine(
          const Offset(cx, by - 40),
          Offset(cx + math.cos(a) * 80, by - 40 + math.sin(a) * 80),
          p,
        );
      }
      p
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.srcOver;
    }
    // The body.
    g.fillEll(cx, by + 4, 46, 6, const Color.fromRGBO(0, 0, 0, 0.35));
    g.fillRR(cx - 38, by - 36, 76, 38, 5, wood[1]);
    g.fillRR(cx - 38, by - 36, 76, 34, 5, wood[0]);
    g.fillRR(
      cx - 34,
      by - 33,
      68,
      3,
      0,
      const Color.fromRGBO(255, 230, 190, 0.16),
    );
    g.fillRR(cx - 38, by - 12, 76, 5, 0, band);
    g.fillRR(cx - 30, by - 36, 6, 38, 0, band);
    g.fillRR(cx + 24, by - 36, 6, 38, 0, band);
    if (openK > 0.05) {
      g.fillRR(
        cx - 34,
        by - 38,
        68,
        8 * math.min(1.0, openK * 2),
        3,
        _hex(0xFFE296, 0.9 * math.min(1.0, openK * 1.5)),
      );
    }
    if (openK > 0.35) {
      final u = _clamp((t - 0.55) / 0.9, 0, 1), e = easeOut(u);
      paintBrawlLoot(
        g,
        loot,
        cx,
        (by - 36) +
            ((by - 66) - (by - 36)) * e +
            math.sin(t * 2.2) * (still ? 0 : 1.5),
        1.0 + 0.25 * e,
      );
    }
    // The lid lifts and tilts back.
    canvas.save();
    canvas.translate(cx, by - 36);
    canvas.translate(0, -open * 15);
    canvas.save();
    canvas.scale(1, 1 - open * 0.55);
    g.fillRR(-40, -24, 80, 26, 12, wood[1]);
    g.fillRR(-40, -26, 80, 24, 12, wood[0]);
    g.fillRR(-30, -26, 6, 26, 0, band);
    g.fillRR(24, -26, 6, 26, 0, band);
    g.fillRR(-34, -23, 40, 4, 2, const Color.fromRGBO(255, 240, 205, 0.22));
    canvas.restore();
    canvas.restore();
    if (openK < 0.2) {
      g.fillRR(cx - 6, by - 40, 12, 12, 3, band);
      g.fillCircle(cx, by - 35, 1.8, _hex(0x2a1608));
    }
    if (openK > 0.4 && !still) {
      for (var i = 0; i < 6; i++) {
        final ph = t * 1.6 + i * 1.3;
        final sx = cx + math.sin(ph * 1.1 + i) * 40;
        final sy = by - 40 - ((ph * 22) % 56);
        g.fillPath(
          star4Path(sx, sy, 2.6, ph),
          _hex(0xFFE8A8, 0.5 + 0.5 * math.sin(ph * 5)),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BrawlChestPainter old) =>
      old.chest != chest || old.loot != loot || old.still != still;
}

/// A piece of loot as a small mark (the trophy case).
class BrawlLootMark extends StatelessWidget {
  const BrawlLootMark({super.key, required this.loot, this.size = 44});

  final String loot;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _LootPainter(loot)),
    ),
  );
}

class _LootPainter extends CustomPainter {
  _LootPainter(this.loot);
  final String loot;
  final BrawlPen _pen = BrawlPen();

  @override
  void paint(Canvas canvas, Size size) {
    paintBrawlLoot(
      _pen..cv = canvas,
      loot,
      size.width / 2,
      size.height / 2,
      size.width / 44,
    );
  }

  @override
  bool shouldRepaint(_LootPainter old) => old.loot != loot;
}
