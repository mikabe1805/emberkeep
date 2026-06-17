import 'dart:math';

import 'package:flutter/material.dart';

import '../tokens.dart';

enum PortraitMood { idle, happy }

/// A portrait frame earned at a level — the cosmetic-unlock promise made
/// real (RESEARCH-momentum.md §7). Reaching the level visibly changes the
/// character; the Me page's appearance slots read from this same list.
class PortraitFrame {
  const PortraitFrame(this.level, this.name);
  final int level;
  final String name;
}

const portraitFrames = <PortraitFrame>[
  PortraitFrame(5, 'Ember Ring'),
  PortraitFrame(10, 'Bright Frame'),
  PortraitFrame(16, 'Gilt Crown'),
  PortraitFrame(24, 'Solar Halo'),
  PortraitFrame(34, 'Eternal Crown'),
];

/// How many frames a level has earned (0 = bare bead).
int frameTierForLevel(int level) {
  var t = 0;
  for (final f in portraitFrames) {
    if (level >= f.level) t++;
  }
  return t;
}

/// The character — an amber glass bead with a face that lives. Blinks on its
/// own rhythm, beams when you complete a quest, wears an aura in your
/// dominant stat's color, and grows a frame as you level — the portrait
/// reacts to how you build yourself (DESIGN.md §11 / round-2 feedback).
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

  /// Character level — drives the earned frame tier.
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
  // one slow loop drives blinking; quantized + repaint-bounded
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
          final core = AnimatedContainer(
            duration: Motion.settle,
            curve: Motion.respond,
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.45, -0.55),
                colors: [
                  Color(0xFFFFF4D9), // cream specular
                  Color(0xFFF2CD93),
                  Color(0xFFB97F46),
                  Color(0xFF53351A), // walnut rim
                ],
                stops: [0.0, 0.32, 0.78, 1.0],
              ),
              boxShadow: [
                // the aura — your build, glowing around you; richer with tier
                BoxShadow(
                  color: aura.withValues(
                      alpha: (happy ? 0.65 : 0.38) + 0.06 * tier),
                  blurRadius: (happy ? 26 : 16) + 4.0 * tier,
                  spreadRadius: (happy ? 2 : 0) + tier.toDouble(),
                ),
                const BoxShadow(
                    color: Color(0x66140C06),
                    blurRadius: 6,
                    offset: Offset(0, 3)),
              ],
            ),
            child: CustomPaint(
              painter: _FacePainter(
                  happy: happy, blinking: blinking, trait: widget.trait),
              foregroundPainter: tier > 0
                  ? _FramePainter(tier: tier, aura: aura)
                  : null,
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
                  right: -widget.size * 0.04,
                  bottom: -widget.size * 0.04,
                  child: Container(
                    width: widget.size * 0.34,
                    height: widget.size * 0.34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFFFF4D9), Color(0xFFC08B4F)],
                      ),
                      border: Border.all(
                          color: const Color(0xFF3A2510), width: 1),
                      boxShadow: const [
                        BoxShadow(color: Palette.honeyGlow, blurRadius: 8),
                      ],
                    ),
                    child: Icon(Icons.star,
                        size: widget.size * 0.2,
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

/// The earned frame: concentric rim rings that accrue with level — a visible,
/// honest cosmetic that grows as you do.
class _FramePainter extends CustomPainter {
  _FramePainter({required this.tier, required this.aura});
  final int tier;
  final Color aura;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    const honey = Color(0xFFF2CD93);
    const cream = Color(0xFFFFF4D9);
    // base rim — warm at low tiers, aura-tinted from tier 3
    final ringColor = tier >= 3 ? aura : honey;
    canvas.drawCircle(
      c,
      r - size.width * 0.03,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * (0.018 + 0.005 * tier)
        ..color = ringColor.withValues(alpha: 0.85)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.01),
    );
    // tier 2+: an inner cream ring
    if (tier >= 2) {
      canvas.drawCircle(
        c,
        r - size.width * 0.075,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.012
          ..color = cream.withValues(alpha: 0.55),
      );
    }
    // tier 4+: a laurel of small dots around the rim (12 at the top tier)
    if (tier >= 4) {
      final n = tier >= 5 ? 12 : 8;
      final dotR = size.width * (tier >= 5 ? 0.022 : 0.018);
      final ringR = r - size.width * 0.03;
      final dotPaint = Paint()
        ..color = (tier >= 5 ? cream : honey).withValues(alpha: 0.9)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.006);
      for (var i = 0; i < n; i++) {
        final a = (i / n) * 2 * pi - pi / 2;
        canvas.drawCircle(
            c + Offset(cos(a) * ringR, sin(a) * ringR), dotR, dotPaint);
      }
    }
    // tier 5: a second, outer gilded ring
    if (tier >= 5) {
      canvas.drawCircle(
        c,
        r - size.width * 0.005,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.01
          ..color = honey.withValues(alpha: 0.75)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.012),
      );
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.tier != tier || old.aura != aura;
}

class _FacePainter extends CustomPainter {
  _FacePainter({required this.happy, required this.blinking, this.trait});
  final bool happy;
  final bool blinking;
  final Stat? trait;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final s = size.width;
    final ink = Paint()
      ..color = const Color(0xFF35230F)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF35230F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round;

    final eyeY = -s * 0.04;
    final eyeDx = s * 0.15;
    if (happy || blinking) {
      // happy arcs (^ ^) — also doubles as the blink shape
      for (final dx in [-eyeDx, eyeDx]) {
        canvas.drawArc(
          Rect.fromCenter(
              center: c + Offset(dx, eyeY),
              width: s * 0.13,
              height: s * 0.10),
          pi,
          pi,
          false,
          stroke,
        );
      }
    } else {
      canvas.drawCircle(c + Offset(-eyeDx, eyeY), s * 0.038, ink);
      canvas.drawCircle(c + Offset(eyeDx, eyeY), s * 0.038, ink);
    }

    // smile — wider when happy
    canvas.drawArc(
      Rect.fromCenter(
          center: c + Offset(0, s * (happy ? 0.09 : 0.10)),
          width: s * (happy ? 0.34 : 0.24),
          height: s * (happy ? 0.22 : 0.14)),
      pi * 0.12,
      pi * 0.76,
      false,
      stroke,
    );

    // blush when happy
    if (happy) {
      final blush = Paint()
        ..color = const Color(0x55D88A8A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(
          c + Offset(-s * 0.24, s * 0.07), s * 0.05, blush);
      canvas.drawCircle(c + Offset(s * 0.24, s * 0.07), s * 0.05, blush);
    }

    // build-trait flourish — only at larger sizes so the tiny HUD stays clean
    final tr = trait;
    if (tr != null && s >= 70) {
      final tc = tr.color;
      final acc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.03
        ..strokeCap = StrokeCap.round
        ..color = tc;
      switch (tr) {
        case Stat.intl: // round glasses
          final r = s * 0.072;
          canvas.drawCircle(c + Offset(-eyeDx, eyeY), r, acc);
          canvas.drawCircle(c + Offset(eyeDx, eyeY), r, acc);
          canvas.drawLine(
              c + Offset(-eyeDx + r, eyeY), c + Offset(eyeDx - r, eyeY), acc);
          canvas.drawLine(c + Offset(-eyeDx - r, eyeY),
              c + Offset(-eyeDx - r - s * 0.06, eyeY - s * 0.02), acc);
          canvas.drawLine(c + Offset(eyeDx + r, eyeY),
              c + Offset(eyeDx + r + s * 0.06, eyeY - s * 0.02), acc);
        case Stat.str: // a headband across the brow + knot tails
          final band = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.055
            ..strokeCap = StrokeCap.round
            ..color = tc;
          final by = -s * 0.20;
          canvas.drawLine(c + Offset(-s * 0.22, by), c + Offset(s * 0.22, by), band);
          canvas.drawLine(c + Offset(s * 0.20, by),
              c + Offset(s * 0.30, by + s * 0.05), acc);
          canvas.drawLine(c + Offset(s * 0.20, by),
              c + Offset(s * 0.30, by - s * 0.03), acc);
        case Stat.foc: // a calm focus dot above the brows
          canvas.drawCircle(
              c + Offset(0, -s * 0.17), s * 0.028, Paint()..color = tc);
        case Stat.soc: // brighter, always-on bloom cheeks
          final b = Paint()
            ..color = tc.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
          canvas.drawCircle(c + Offset(-s * 0.24, s * 0.07), s * 0.055, b);
          canvas.drawCircle(c + Offset(s * 0.24, s * 0.07), s * 0.055, b);
        case Stat.vit: // a tiny sprout above the head
          canvas.drawLine(
              c + Offset(0, -s * 0.30), c + Offset(-s * 0.05, -s * 0.37), acc);
          canvas.drawLine(
              c + Offset(0, -s * 0.30), c + Offset(s * 0.05, -s * 0.37), acc);
          canvas.drawLine(
              c + Offset(0, -s * 0.27), c + Offset(0, -s * 0.33), acc);
        case Stat.dis: // determined brows
          canvas.drawLine(c + Offset(-eyeDx - s * 0.05, eyeY - s * 0.10),
              c + Offset(-eyeDx + s * 0.04, eyeY - s * 0.06), acc);
          canvas.drawLine(c + Offset(eyeDx + s * 0.05, eyeY - s * 0.10),
              c + Offset(eyeDx - s * 0.04, eyeY - s * 0.06), acc);
      }
    }
  }

  @override
  bool shouldRepaint(_FacePainter old) =>
      old.happy != happy ||
      old.blinking != blinking ||
      old.trait != trait;
}
