import 'dart:math';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../tokens.dart';

enum PortraitMood { idle, happy }

/// The default warm Ember body palette (light→dark) when no skin is worn.
const _emberAmber = [
  Color(0xFFFFF4D9),
  Color(0xFFF2CD93),
  Color(0xFFC58A4E),
  Color(0xFF6E451F),
];

/// A growth stage the character reaches at a level — the cosmetic-unlock
/// promise made real (RESEARCH-momentum.md §7). Reaching the level visibly
/// changes the creature (its flame crest grows); the Me page's appearance
/// slots read from this same list.
class PortraitFrame {
  const PortraitFrame(this.level, this.name);
  final int level;
  final String name;
}

const portraitFrames = <PortraitFrame>[
  PortraitFrame(5, 'First Spark'),
  PortraitFrame(10, 'Steady Flame'),
  PortraitFrame(16, 'Bright Crest'),
  PortraitFrame(24, 'Twin Fire'),
  PortraitFrame(34, 'Everflame'),
];

/// How many stages a level has earned (0 = a tiny new ember).
int frameTierForLevel(int level) {
  var t = 0;
  for (final f in portraitFrames) {
    if (level >= f.level) t++;
  }
  return t;
}

/// The character — a little ember creature you grow: a soft round body with
/// big bright eyes, rosy cheeks, little nub ears, tiny round arms, and a
/// flame crest that rises taller as you level. It blinks on its own rhythm,
/// beams when you complete a quest, glows in your dominant stat's colour,
/// and visibly evolves as you build yourself.
class Portrait extends StatefulWidget {
  const Portrait({
    super.key,
    required this.size,
    this.mood = PortraitMood.idle,
    this.aura,
    this.level = 1,
    this.badge = false,
    this.trait,
    this.skin,
  });

  final double size;
  final PortraitMood mood;

  /// Dominant-stat color (or an equipped skin's color); defaults to honey.
  final Color? aura;

  /// The four body-gradient colours (light→dark) of the worn creature skin.
  final List<Color>? skin;

  /// Character level — drives the earned growth stage (flame crest).
  final int level;

  /// Pin the founder badge (an equipped cosmetic).
  final bool badge;

  /// Your dominant stat once it's ranked up — adds a build-keyed flourish.
  final Stat? trait;

  @override
  State<Portrait> createState() => _PortraitState();
}

class _PortraitState extends State<Portrait>
    with SingleTickerProviderStateMixin {
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
    _life.stop();
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aura = widget.aura ?? Palette.xp;
    final tier = frameTierForLevel(widget.level);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _life,
        builder: (context, _) {
          final t = (_life.value * 84).round() / 84;
          final blinking = t > 0.92 && t < 0.965;
          final happy = widget.mood == PortraitMood.happy;
          final core = SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _EmberPainter(
                happy: happy,
                blinking: blinking,
                aura: aura,
                tier: tier,
                trait: widget.trait,
                t: t,
                skin: widget.skin ?? _emberAmber,
              ),
            ),
          );
          if (!widget.badge) return core;
          // badge pinned to lower-right
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                core,
                Positioned(
                  right: -widget.size * 0.02,
                  bottom: widget.size * 0.04,
                  child: Container(
                    width: widget.size * 0.3,
                    height: widget.size * 0.3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFFFF4D9), Color(0xFFC08B4F)],
                      ),
                      border: Border.all(color: const Color(0xFF3A2510), width: 1),
                      boxShadow: const [
                        BoxShadow(color: Palette.honeyGlow, blurRadius: 8),
                      ],
                    ),
                    child: Icon(Icons.star, size: widget.size * 0.18, color: const Color(0xFF3A2510)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Redesigned _EmberPainter — the "transparent condom" is gone.
/// The body is a warm, rounded pear-shape with distinct ears, tiny
/// arm nubs, and a flame that uses bright fire colours (yellow/orange/white)
/// independent of the skin hue so it always reads as FIRE, not tinted goo.
class _EmberPainter extends CustomPainter {
  _EmberPainter({
    required this.happy,
    required this.blinking,
    required this.aura,
    required this.tier,
    required this.t,
    required this.skin,
    this.trait,
  });

  final bool happy;
  final bool blinking;
  final Color aura;
  final int tier;
  final double t;
  final Stat? trait;

  /// Four body-gradient stops, light→dark (the worn creature skin).
  final List<Color> skin;

  Color get _cream => skin[0];
  Color get _honey => skin[1];
  Color get _amber => skin[2];
  Color get _rim => skin[3];
  static const _ink = Color(0xFF3A2410);

  // Flame colours — ALWAYS fire-toned regardless of skin, so it reads as
  // an actual flame on top of whatever body colour the skin chose.
  static const _flameTip = Color(0xFFFFF4D9);   // pale white-yellow tip
  static const _flameMid = Color(0xFFFFB347);     // bright orange-gold
  static const _flameBase = Color(0xFFE07020);    // deep orange base
  static const _flameCore = Color(0xFFFFF8E7);    // hot white heart

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s * 0.5;
    final detail = s >= 56;

    // ── animation state ──
    final breathe = sin(t * 2 * pi);
    final excite = happy ? 1.03 : 1.0;
    final bob = sin(t * 2 * pi + 1.2) * s * (happy ? 0.03 : 0.016);
    final restY = s * 0.54;
    final baseY = restY + s * 0.64 * excite * 0.5;
    final lift = (-bob / (s * 0.03)).clamp(0.0, 1.0);

    // ── body geometry: round pear-shape (wider bottom, slight shoulders) ──
    final bodyC = Offset(cx, restY + bob);
    final bodyW = s * 0.66 * excite * (1 + 0.025 * breathe);
    final bodyH = s * 0.60 * excite * (1 - 0.02 * breathe);
    final bodyTop = bodyC.dy - bodyH / 2;

    // ── aura ──
    canvas.drawCircle(
      bodyC, s * 0.52,
      Paint()
        ..color = aura.withValues(alpha: (happy ? 0.34 : 0.20) + 0.03 * tier)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * (happy ? 0.16 : 0.13)),
    );
    canvas.drawCircle(
      bodyC, s * 0.34,
      Paint()
        ..color = aura.withValues(alpha: (happy ? 0.20 : 0.11) + 0.02 * tier)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.09),
    );

    // ── flame crest ──
    _crest(canvas, s, cx, bodyTop);

    // ── grounding shadow ──
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, baseY + s * 0.01),
        width: bodyW * 0.78 * (1 - 0.16 * lift),
        height: s * 0.06,
      ),
      Paint()
        ..color = Color.fromRGBO(0, 0, 0, 0.24 * (1 - 0.35 * lift))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.018),
    );

    // ── ears — two little tufts on the sides, breaking the egg silhouette ──
    if (detail) {
      for (final side in [-1.0, 1.0]) {
        final earC = Offset(cx + side * bodyW * 0.55, bodyC.dy - bodyH * 0.25);
        final earR = Rect.fromCenter(center: earC, width: s * 0.18, height: s * 0.15);
        canvas.drawOval(
          earR,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.3, -0.4),
              colors: [Color.lerp(_honey, _cream, 0.4)!, _amber],
            ).createShader(earR),
        );
        // ear inner highlight
        canvas.drawOval(
          Rect.fromCenter(center: earC.translate(-side * s * 0.01, -s * 0.01), width: s * 0.07, height: s * 0.05),
          Paint()
            ..color = _cream.withValues(alpha: 0.35)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.006),
        );
      }
    }

    // ── feet ──
    if (detail) {
      for (final dx in [-0.16, 0.16]) {
        final fc = Offset(cx + dx * s, bodyC.dy + bodyH * 0.46);
        final fr = Rect.fromCenter(center: fc, width: s * 0.2, height: s * 0.12);
        canvas.drawOval(
          fr,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.2, -0.6),
              colors: [Color.lerp(_amber, _cream, 0.35)!, Color.lerp(_amber, _rim, 0.55)!],
            ).createShader(fr),
        );
      }
    }

    // ── body: round pear-shaped blob (no longer a pure egg) ──
    final bodyPath = Path()
      // start at top
      ..moveTo(cx, bodyTop)
      // right curve
      ..quadraticBezierTo(cx + bodyW * 0.6, bodyTop + bodyH * 0.2, cx + bodyW * 0.55, bodyTop + bodyH * 0.5)
      // bottom curve
      ..quadraticBezierTo(cx + bodyW * 0.5, bodyTop + bodyH * 0.85, cx + bodyW * 0.15, bodyTop + bodyH * 0.95)
      ..quadraticBezierTo(cx, bodyTop + bodyH * 1.0, cx - bodyW * 0.15, bodyTop + bodyH * 0.95)
      // left curve
      ..quadraticBezierTo(cx - bodyW * 0.5, bodyTop + bodyH * 0.85, cx - bodyW * 0.55, bodyTop + bodyH * 0.5)
      ..quadraticBezierTo(cx - bodyW * 0.6, bodyTop + bodyH * 0.2, cx, bodyTop)
      ..close();

    // Fill body with radial gradient
    final bodyRect = Rect.fromCenter(center: bodyC, width: bodyW, height: bodyH);
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.5),
          radius: 1.05,
          colors: [_cream, _honey, _amber, _rim],
          stops: const [0.0, 0.34, 0.76, 1.0],
        ).createShader(bodyRect),
    );

    // ── inner warm glow (visible through the body) ──
    canvas.save();
    canvas.clipPath(bodyPath);
    // warm glow pool in the lower belly
    canvas.drawCircle(
      Offset(cx, bodyC.dy + bodyH * 0.2),
      bodyW * 0.38,
      Paint()
        ..color = Color.lerp(_honey, _cream, 0.3)!.withValues(alpha: happy ? 0.50 : 0.38)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05),
    );
    // warm rim-light on the lower-right edge
    canvas.drawArc(
      bodyRect.deflate(s * 0.012),
      pi * 0.1, pi * 0.62, false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.03
        ..color = Color.lerp(_honey, _cream, 0.5)!.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.012),
    );
    canvas.restore();

    // ── specular highlight (top-left) ──
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - bodyW * 0.2, bodyTop + bodyH * 0.22),
        width: bodyW * 0.2, height: bodyH * 0.14,
      ),
      Paint()
        ..color = _cream.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.014),
    );
    canvas.drawCircle(
      Offset(cx - bodyW * 0.24, bodyTop + bodyH * 0.17),
      s * 0.018,
      Paint()..color = Color.lerp(_cream, Colors.white, 0.65)!.withValues(alpha: 0.85),
    );

    // ── tiny arm nubs on each side (huggable) ──
    if (detail) {
      for (final side in [-1.0, 1.0]) {
        final armC = Offset(cx + side * bodyW * 0.52, bodyC.dy + bodyH * 0.12);
        final armR = Rect.fromCenter(center: armC, width: s * 0.16, height: s * 0.2);
        canvas.drawOval(
          armR,
          Paint()
            ..shader = RadialGradient(
              center: Alignment(side * -0.3, -0.5),
              colors: [_cream, Color.lerp(_honey, _amber, 0.5)!],
            ).createShader(armR),
        );
      }
    }

    // ── face ──
    _face(canvas, s, cx, bodyC, bodyW, detail);

    // ── tier 4+ sparkles ──
    if (tier >= 4) {
      final sp = Paint()
        ..color = _cream.withValues(alpha: 0.85)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.006);
      for (final p in const [Offset(0.2, 0.28), Offset(0.82, 0.34), Offset(0.74, 0.6)]) {
        canvas.drawCircle(Offset(p.dx * s, p.dy * s), s * 0.014, sp);
      }
    }
  }

  void _crest(Canvas canvas, double s, double cx, double bodyTop) {
    final h = s * (0.15 + tier * 0.05);
    final baseY = bodyTop + s * 0.08;
    final flick = 1 + 0.06 * sin(t * 2 * pi * 1.7);
    final sway = sin(t * 2 * pi) * s * 0.012;

    Path teardrop(double fx, double fw, double fh, double tipX) => Path()
      ..moveTo(fx - fw / 2, baseY)
      ..quadraticBezierTo(fx - fw * 0.62, baseY - fh * 0.5, tipX - fw * 0.14, baseY - fh * 0.82)
      ..quadraticBezierTo(tipX, baseY - fh, tipX + fw * 0.14, baseY - fh * 0.82)
      ..quadraticBezierTo(fx + fw * 0.62, baseY - fh * 0.5, fx + fw / 2, baseY)
      ..quadraticBezierTo(fx, baseY + fh * 0.14, fx - fw / 2, baseY)
      ..close();

    void flame(double dx, double scale, double lean) {
      final fx = cx + dx + sway * scale;
      final fh = h * scale * flick;
      final fw = s * 0.145 * scale;
      final tipX = fx + lean;
      final body = teardrop(fx, fw, fh, tipX);

      // always uses fire colours (yellow/orange/white), NOT skin tones
      final fr = Rect.fromLTWH(fx - fw, baseY - fh, fw * 2, fh * 1.16);

      // outer glow
      canvas.drawCircle(
        Offset(fx, baseY - fh * 0.3), fw * 1.05,
        Paint()
          ..color = _flameMid.withValues(alpha: 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05),
      );
      // flame body gradient (always fire colours)
      canvas.drawPath(
        body,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter, end: Alignment.topCenter,
            colors: [_flameBase, _flameMid, _flameTip],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(fr),
      );
      // hot white core
      final coreW = fw * 0.42, coreH = fh * 0.5;
      canvas.drawPath(
        teardrop(fx, coreW, coreH, fx),
        Paint()
          ..color = _flameCore.withValues(alpha: 0.7)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.006),
      );
    }

    if (tier >= 3) flame(-s * 0.12, 0.6, -s * 0.02);
    if (tier >= 2) flame(s * 0.12, 0.68, s * 0.02);
    flame(0, 1.0, sway * 0.6);
  }

  void _face(Canvas canvas, double s, double cx, Offset bodyC, double bodyW, bool detail) {
    final eyeY = bodyC.dy - s * 0.02;
    final eyeDx = s * 0.135;
    final ink = Paint()..color = _ink;
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round;

    // cheeks
    final blush = Paint()
      ..color = Color(happy ? 0x66E08A7A : 0x44D88A8A)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.018);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - s * 0.2, eyeY + s * 0.1), width: s * 0.13, height: s * 0.085), blush);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + s * 0.2, eyeY + s * 0.1), width: s * 0.13, height: s * 0.085), blush);

    // tiny eyebrows — add expression without being human
    if (detail && !happy) {
      final brow = Paint()
        ..color = _ink.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.024
        ..strokeCap = StrokeCap.round;
      for (final dx in [-eyeDx, eyeDx]) {
        canvas.drawLine(
          Offset(cx + dx - s * 0.05, eyeY - s * 0.12),
          Offset(cx + dx + s * 0.05, eyeY - s * 0.09),
          brow,
        );
      }
    }

    if (blinking) {
      for (final dx in [-eyeDx, eyeDx]) {
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx + dx, eyeY), width: s * 0.13, height: s * 0.1),
          pi, pi, false, stroke);
      }
    } else {
      final eyeR = s * (happy ? 0.085 : 0.078);
      for (final dx in [-eyeDx, eyeDx]) {
        final ec = Offset(cx + dx, eyeY);
        canvas.drawOval(
          Rect.fromCenter(center: ec, width: eyeR * 1.7, height: eyeR * 2.0), ink);
        canvas.drawCircle(ec.translate(-eyeR * 0.32, -eyeR * 0.5), eyeR * 0.42,
            Paint()..color = _cream.withValues(alpha: 0.95));
        canvas.drawCircle(ec.translate(eyeR * 0.34, eyeR * 0.55), eyeR * 0.2,
            Paint()..color = _cream.withValues(alpha: 0.7));
      }
    }

    // mouth
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, eyeY + s * (happy ? 0.135 : 0.125)),
        width: s * (happy ? 0.24 : 0.17),
        height: s * (happy ? 0.17 : 0.1)),
      pi * 0.1, pi * 0.8, false, stroke,
    );

    _trait(canvas, s, cx, eyeY, eyeDx, detail);
  }

  void _trait(Canvas canvas, double s, double cx, double eyeY, double eyeDx, bool detail) {
    final tr = trait;
    if (tr == null || !detail) return;
    final c = Offset(cx, eyeY);
    final tc = tr.color;
    final acc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.028
      ..strokeCap = StrokeCap.round
      ..color = tc;
    switch (tr) {
      case Stat.intl:
        final r = s * 0.085;
        canvas.drawCircle(c + Offset(-eyeDx, 0), r, acc);
        canvas.drawCircle(c + Offset(eyeDx, 0), r, acc);
        canvas.drawLine(c + Offset(-eyeDx + r, 0), c + Offset(eyeDx - r, 0), acc);
      case Stat.str:
        final band = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.05
          ..strokeCap = StrokeCap.round
          ..color = tc;
        final by = eyeY - s * 0.14;
        canvas.drawLine(Offset(cx - s * 0.2, by), Offset(cx + s * 0.2, by), band);
        canvas.drawLine(Offset(cx + s * 0.18, by), Offset(cx + s * 0.28, by + s * 0.05), acc);
        canvas.drawLine(Offset(cx + s * 0.18, by), Offset(cx + s * 0.28, by - s * 0.03), acc);
      case Stat.foc:
        canvas.drawCircle(Offset(cx, eyeY - s * 0.12), s * 0.026, Paint()..color = tc);
      case Stat.soc:
        final b = Paint()
          ..color = tc.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.02);
        canvas.drawCircle(Offset(cx - s * 0.2, eyeY + s * 0.1), s * 0.05, b);
        canvas.drawCircle(Offset(cx + s * 0.2, eyeY + s * 0.1), s * 0.05, b);
      case Stat.vit:
        final lx = cx + s * 0.26, ly = eyeY + s * 0.02;
        canvas.drawLine(Offset(lx, ly + s * 0.05), Offset(lx, ly - s * 0.06), acc..strokeWidth = s * 0.02);
        canvas.drawOval(Rect.fromCenter(center: Offset(lx + s * 0.03, ly - s * 0.02), width: s * 0.06, height: s * 0.035), Paint()..color = tc);
      case Stat.dis:
        canvas.drawLine(Offset(cx - eyeDx - s * 0.05, eyeY - s * 0.11), Offset(cx - eyeDx + s * 0.04, eyeY - s * 0.07), acc);
        canvas.drawLine(Offset(cx + eyeDx + s * 0.05, eyeY - s * 0.11), Offset(cx + eyeDx - s * 0.04, eyeY - s * 0.07), acc);
    }
  }

  @override
  bool shouldRepaint(_EmberPainter old) =>
      old.happy != happy ||
      old.blinking != blinking ||
      old.tier != tier ||
      old.aura != aura ||
      old.trait != trait ||
      old.t != t ||
      !listEquals(old.skin, skin);
}
