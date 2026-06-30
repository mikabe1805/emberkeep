import 'dart:math';

import 'package:flutter/material.dart';

import '../tokens.dart';

enum PortraitMood { idle, happy }

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

/// The character — a little ember creature you grow: a soft amber-glass body
/// with big bright eyes, rosy cheeks, and a flame crest that rises taller as
/// you level. It blinks on its own rhythm, beams when you complete a quest,
/// glows in your dominant stat's colour, and visibly evolves as you build
/// yourself (the owner's #1 ask: a lovable character that grows with you).
class Portrait extends StatefulWidget {
  const Portrait({
    super.key,
    required this.size,
    this.mood = PortraitMood.idle,
    this.aura,
    this.level = 1,
    this.badge = false,
    this.trait,
  });

  final double size;
  final PortraitMood mood;

  /// Dominant-stat color (or an equipped skin's color); defaults to honey.
  final Color? aura;

  /// Character level — drives the earned growth stage (flame crest).
  final int level;

  /// Pin the founder badge (an equipped cosmetic).
  final bool badge;

  /// Your dominant stat once it's ranked up — adds a build-keyed flourish to
  /// the face (glasses for INT, a headband for STR, …). Null = neutral face.
  final Stat? trait;

  @override
  State<Portrait> createState() => _PortraitState();
}

class _PortraitState extends State<Portrait>
    with SingleTickerProviderStateMixin {
  // one slow loop drives blinking + the flame's gentle sway; quantized +
  // repaint-bounded so it costs almost nothing
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
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
          // blink: eyes shut briefly near the end of each loop
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
              ),
            ),
          );
          if (!widget.badge) return core;
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
                      border:
                          Border.all(color: const Color(0xFF3A2510), width: 1),
                      boxShadow: const [
                        BoxShadow(color: Palette.honeyGlow, blurRadius: 8),
                      ],
                    ),
                    child: Icon(Icons.star,
                        size: widget.size * 0.18,
                        color: const Color(0xFF3A2510)),
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

/// Draws the whole creature: aura, flame crest, soft body with a glassy
/// sheen, little feet, the face, and any build-trait flourish.
class _EmberPainter extends CustomPainter {
  _EmberPainter({
    required this.happy,
    required this.blinking,
    required this.aura,
    required this.tier,
    required this.t,
    this.trait,
  });

  final bool happy;
  final bool blinking;
  final Color aura;
  final int tier;
  final double t;
  final Stat? trait;

  // warm glass palette
  static const _cream = Color(0xFFFFF4D9);
  static const _honey = Color(0xFFF2CD93);
  static const _amber = Color(0xFFC58A4E);
  static const _rim = Color(0xFF6E451F);
  static const _ink = Color(0xFF3A2410);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s * 0.5;
    final detail = s >= 56; // feet/fine detail only when it won't muddy
    // a soft flame sway so the creature feels alive
    final sway = sin(t * 2 * pi) * s * 0.012;

    // body geometry — a soft, slightly egg-shaped blob (head+body in one)
    final bodyC = Offset(cx, s * 0.54);
    final bodyW = s * 0.62, bodyH = s * 0.64;
    final bodyTop = bodyC.dy - bodyH / 2;

    // ── aura: your build, glowing around you (brighter happy / higher tier) ──
    canvas.drawCircle(
      bodyC,
      s * 0.5,
      Paint()
        ..color = aura.withValues(
            alpha: (happy ? 0.42 : 0.24) + 0.035 * tier)
        ..maskFilter = MaskFilter.blur(
            BlurStyle.normal, s * (happy ? 0.13 : 0.10)),
    );

    // ── flame crest (the growth stage) — rises above the head, taller with
    // each tier; tier 0 is a single shy spark, the top tiers a real blaze ──
    _crest(canvas, s, cx, bodyTop, sway);

    // ── feet: two little nubs so it stands ──
    if (detail) {
      final footPaint = Paint()..color = const Color(0xFFA9743E);
      for (final dx in [-0.16, 0.16]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx + dx * s, bodyC.dy + bodyH * 0.46),
            width: s * 0.2,
            height: s * 0.12,
          ),
          footPaint,
        );
      }
    }

    // ── body: glassy radial-shaded blob ──
    final bodyRect = Rect.fromCenter(
        center: bodyC, width: bodyW, height: bodyH);
    canvas.drawOval(
      bodyRect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.55),
          radius: 1.05,
          colors: [_cream, _honey, _amber, _rim],
          stops: [0.0, 0.34, 0.76, 1.0],
        ).createShader(bodyRect),
    );
    // grounding shadow under the body
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, bodyC.dy + bodyH * 0.5),
        width: bodyW * 0.78,
        height: s * 0.06,
      ),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.012),
    );
    // soft belly — a lighter tummy that reads as "soft creature"
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, bodyC.dy + bodyH * 0.12),
        width: bodyW * 0.5,
        height: bodyH * 0.42,
      ),
      Paint()
        ..color = _cream.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.03),
    );
    // a crisp top-left specular highlight (the glass "drop of light")
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - bodyW * 0.22, bodyTop + bodyH * 0.2),
        width: bodyW * 0.26,
        height: bodyH * 0.18,
      ),
      Paint()
        ..color = _cream.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.02),
    );

    _face(canvas, s, cx, bodyC, bodyW, detail);

    // ── high-tier sparkle motes drifting around the blaze ──
    if (tier >= 4) {
      final sp = Paint()
        ..color = _cream.withValues(alpha: 0.85)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.006);
      for (final p in const [
        Offset(0.2, 0.28),
        Offset(0.82, 0.34),
        Offset(0.74, 0.6),
      ]) {
        canvas.drawCircle(
            Offset(p.dx * s, p.dy * s), s * 0.014, sp);
      }
    }
  }

  void _crest(Canvas canvas, double s, double cx, double bodyTop, double sway) {
    // how tall the flame stands, by stage
    final h = s * (0.1 + tier * 0.05);
    final baseY = bodyTop + s * 0.06;

    void flame(double dx, double scale, double lean) {
      final fx = cx + dx + sway * scale;
      final fh = h * scale;
      final fw = s * 0.12 * scale;
      final tipX = fx + lean;
      final path = Path()
        ..moveTo(fx - fw / 2, baseY)
        ..quadraticBezierTo(
            fx - fw * 0.55, baseY - fh * 0.55, tipX, baseY - fh)
        ..quadraticBezierTo(
            fx + fw * 0.55, baseY - fh * 0.55, fx + fw / 2, baseY)
        ..quadraticBezierTo(fx, baseY + fh * 0.12, fx - fw / 2, baseY)
        ..close();
      // glow
      canvas.drawPath(
        path,
        Paint()
          ..color = Palette.honeyGlow.withValues(alpha: 0.7)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.03),
      );
      // body of the flame
      final fr = Rect.fromLTWH(fx - fw, baseY - fh, fw * 2, fh);
      canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xFFE9A24B), _honey, _cream],
            stops: [0.0, 0.5, 1.0],
          ).createShader(fr),
      );
    }

    // side flames first (so the central one sits in front), added by tier
    if (tier >= 3) flame(-s * 0.11, 0.62, -s * 0.02);
    if (tier >= 2) flame(s * 0.11, 0.7, s * 0.02);
    flame(0, 1.0, sway * 0.6); // the main flame, always present
  }

  void _face(Canvas canvas, double s, double cx, Offset bodyC, double bodyW,
      bool detail) {
    final eyeY = bodyC.dy - s * 0.02;
    final eyeDx = s * 0.135;
    final ink = Paint()..color = _ink;
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round;

    // cheeks — a soft always-on warmth, blooming when happy
    final blush = Paint()
      ..color = Color(happy ? 0x66E08A7A : 0x44D88A8A)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.018);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx - s * 0.2, eyeY + s * 0.1),
          width: s * 0.13,
          height: s * 0.085),
      blush,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx + s * 0.2, eyeY + s * 0.1),
          width: s * 0.13,
          height: s * 0.085),
      blush,
    );

    if (blinking) {
      // gentle closed arcs
      for (final dx in [-eyeDx, eyeDx]) {
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(cx + dx, eyeY),
              width: s * 0.13,
              height: s * 0.1),
          pi,
          pi,
          false,
          stroke,
        );
      }
    } else {
      // big round eyes with catchlights — the heart of the cuteness
      final eyeR = s * (happy ? 0.085 : 0.078);
      for (final dx in [-eyeDx, eyeDx]) {
        final ec = Offset(cx + dx, eyeY);
        canvas.drawOval(
          Rect.fromCenter(center: ec, width: eyeR * 1.7, height: eyeR * 2.0),
          ink,
        );
        // big upper catchlight
        canvas.drawCircle(
          ec.translate(-eyeR * 0.32, -eyeR * 0.5),
          eyeR * 0.42,
          Paint()..color = _cream.withValues(alpha: 0.95),
        );
        // small lower sparkle
        canvas.drawCircle(
          ec.translate(eyeR * 0.34, eyeR * 0.55),
          eyeR * 0.2,
          Paint()..color = _cream.withValues(alpha: 0.7),
        );
      }
    }

    // mouth — a soft smile, wider and rounder when happy
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(cx, eyeY + s * (happy ? 0.135 : 0.125)),
          width: s * (happy ? 0.24 : 0.17),
          height: s * (happy ? 0.17 : 0.1)),
      pi * 0.1,
      pi * 0.8,
      false,
      stroke,
    );

    _trait(canvas, s, cx, eyeY, eyeDx, detail);
  }

  void _trait(Canvas canvas, double s, double cx, double eyeY, double eyeDx,
      bool detail) {
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
      case Stat.intl: // round glasses
        final r = s * 0.085;
        canvas.drawCircle(c + Offset(-eyeDx, 0), r, acc);
        canvas.drawCircle(c + Offset(eyeDx, 0), r, acc);
        canvas.drawLine(
            c + Offset(-eyeDx + r, 0), c + Offset(eyeDx - r, 0), acc);
      case Stat.str: // headband across the brow + knot tails
        final band = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.05
          ..strokeCap = StrokeCap.round
          ..color = tc;
        final by = eyeY - s * 0.14;
        canvas.drawLine(
            Offset(cx - s * 0.2, by), Offset(cx + s * 0.2, by), band);
        canvas.drawLine(Offset(cx + s * 0.18, by),
            Offset(cx + s * 0.28, by + s * 0.05), acc);
        canvas.drawLine(Offset(cx + s * 0.18, by),
            Offset(cx + s * 0.28, by - s * 0.03), acc);
      case Stat.foc: // a calm focus dot on the brow
        canvas.drawCircle(
            Offset(cx, eyeY - s * 0.12), s * 0.026, Paint()..color = tc);
      case Stat.soc: // brighter, larger bloom cheeks
        final b = Paint()
          ..color = tc.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.02);
        canvas.drawCircle(Offset(cx - s * 0.2, eyeY + s * 0.1), s * 0.05, b);
        canvas.drawCircle(Offset(cx + s * 0.2, eyeY + s * 0.1), s * 0.05, b);
      case Stat.vit: // a tiny leaf sprig on one cheek (clear of the flame)
        final lx = cx + s * 0.26, ly = eyeY + s * 0.02;
        canvas.drawLine(Offset(lx, ly + s * 0.05), Offset(lx, ly - s * 0.06),
            acc..strokeWidth = s * 0.02);
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(lx + s * 0.03, ly - s * 0.02),
              width: s * 0.06,
              height: s * 0.035),
          Paint()..color = tc,
        );
      case Stat.dis: // determined brows
        canvas.drawLine(Offset(cx - eyeDx - s * 0.05, eyeY - s * 0.11),
            Offset(cx - eyeDx + s * 0.04, eyeY - s * 0.07), acc);
        canvas.drawLine(Offset(cx + eyeDx + s * 0.05, eyeY - s * 0.11),
            Offset(cx + eyeDx - s * 0.04, eyeY - s * 0.07), acc);
    }
  }

  @override
  bool shouldRepaint(_EmberPainter old) =>
      old.happy != happy ||
      old.blinking != blinking ||
      old.tier != tier ||
      old.aura != aura ||
      old.trait != trait ||
      old.t != t;
}
