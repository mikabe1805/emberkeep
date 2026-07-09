import 'dart:math';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../tokens.dart';

enum PortraitMood { idle, happy }

/// A painted costume the ember can wear (round-62, replacing the AI outfit
/// sprites). Each is drawn in code over the base flame-spirit so it stays in
/// the same clean style as every other creature.
enum Outfit { wayfarer, herbalist, knight, wizard }

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

/// The character — the chibi flame-spirit of the LOCKED canon
/// (ART-PIPELINE.md): a teardrop-flame body, two swept-back ear-wisps, big
/// dark glossy eyes, rosy cheeks, tiny dark feet, and a glowing coal belly.
/// It blinks and glances on its own rhythm, its flame sways and flickers, the
/// coal in its belly breathes light, and the flame rises taller as you level.
/// This painter is the guaranteed fallback for every sprite everywhere, so it
/// must always read as the same creature as the pre-rendered frames.
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
    this.outfit,
  });

  final double size;
  final PortraitMood mood;

  /// A painted costume (null = a plain ember). When worn, the flame crest
  /// tucks down to make room for the hat/hood/helm.
  final Outfit? outfit;

  /// Dominant-stat color (or an equipped skin's color); defaults to honey.
  final Color? aura;

  /// The four body-gradient colours (light→dark) of the worn creature skin
  /// (content/creature_skins.dart). Null = the default warm Ember amber.
  final List<Color>? skin;

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

  // a stable per-instance phase so a row of embers (the shop skin list, the
  // evolution ladder) don't blink and sway in lockstep like animatronics
  double get _phase {
    final s = widget.skin;
    final h = (s == null ? 0 : s.fold<int>(0, (a, c) => a ^ c.toARGB32())) ^
        (widget.level * 37);
    return (h % 997) / 997.0;
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aura = widget.aura ?? Palette.xp;
    final tier = frameTierForLevel(widget.level);
    // reduce-motion (OS switch): park the loop and hold the calm resting pose
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still && _life.isAnimating) {
      _life.stop();
    } else if (!still && !_life.isAnimating) {
      _life.repeat();
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _life,
        builder: (context, _) {
          // phase-shift the loop per instance, then quantize (~20 steps)
          final t = still ? 0.0 : (((_life.value + _phase) % 1.0) * 84).round() / 84;
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
                skin: widget.skin ?? _emberAmber,
                outfit: widget.outfit,
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

/// Draws the whole flame-spirit: aura, swept ear-wisps, the teardrop-flame
/// body (belly + rising flame in ONE silhouette), the glowing coal belly,
/// tiny dark feet, the face, and any build-trait flourish.
class _EmberPainter extends CustomPainter {
  _EmberPainter({
    required this.happy,
    required this.blinking,
    required this.aura,
    required this.tier,
    required this.t,
    required this.skin,
    this.trait,
    this.outfit,
  });

  final bool happy;
  final bool blinking;
  final Color aura;
  final int tier;
  final double t;
  final Stat? trait;
  final Outfit? outfit;

  /// Four body-gradient stops, light→dark (the worn creature skin).
  final List<Color> skin;

  // the glass palette derives from the skin so the whole creature recolours
  // together; only the ink (eyes/mouth/feet) stays a universal warm dark.
  Color get _cream => skin[0];
  Color get _honey => skin[1];
  Color get _amber => skin[2];
  Color get _rim => skin[3];
  static const _ink = Color(0xFF31200E);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s * 0.5;
    final detail = s >= 56; // fine detail only when it won't muddy

    // ── the life signals, all phases of one quantized loop ──
    final breathe = sin(t * 2 * pi);
    // two-harmonic sway so the flame wanders instead of metronoming
    final sway =
        (sin(t * 2 * pi) * 0.7 + sin(t * 4 * pi + 0.9) * 0.3) * s * 0.02;
    final flick = 1 +
        0.05 * sin(t * 2 * pi * 1.7) +
        0.025 * sin(t * 2 * pi * 3.3 + 1.1);
    final excite = happy ? 1.04 : 1.0;
    final bob = sin(t * 2 * pi + 1.2) * s * (happy ? 0.028 : 0.014);
    final lift = (-bob / (s * 0.028)).clamp(0.0, 1.0);

    // ── body geometry: a plump teardrop — round belly low, narrowing into
    // the flame. Belly breathes wider on the inhale, flame rides the sway. ──
    final restY = s * 0.615; // belly centre at rest
    final bodyC = Offset(cx, restY + bob);
    final bellyW = s * 0.58 * excite * (1 + 0.024 * breathe); // belly width
    final bellyH = s * 0.56 * excite * (1 - 0.018 * breathe);
    final bellyR = Rect.fromCenter(center: bodyC, width: bellyW, height: bellyH);
    final headY = bodyC.dy - bellyH * 0.40; // where the flame starts narrowing
    // the flame: taller + livelier with each earned tier. Under a costume it
    // tucks down to a short crest so the hat/hood/helm has room to sit.
    final flameH =
        s * ((outfit != null ? 0.09 : 0.22) + tier * 0.042) * flick;
    final tipY = headY - flameH;
    final tipX = cx + sway * (1.6 + tier * 0.12);
    final baseY = bodyC.dy + bellyH * 0.5; // the floor contact line

    // ── aura: candlelight pooling around you (brighter happy/higher tier) ──
    canvas.drawCircle(
      bodyC.translate(0, -s * 0.04),
      s * 0.52,
      Paint()
        ..color = aura.withValues(alpha: (happy ? 0.32 : 0.19) + 0.03 * tier)
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, s * (happy ? 0.16 : 0.13)),
    );
    canvas.drawCircle(
      bodyC,
      s * 0.34,
      Paint()
        ..color = aura.withValues(alpha: (happy ? 0.18 : 0.10) + 0.02 * tier)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.09),
    );

    // grounding shadow — beneath the body, shrinking + fading as it hops
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, s * 0.885),
        width: bellyW * 0.82 * (1 - 0.14 * lift),
        height: s * 0.055,
      ),
      Paint()
        ..color = Color.fromRGBO(0, 0, 0, 0.24 * (1 - 0.35 * lift))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.018),
    );

    // ── tiny dark feet (canon), peeking out under the belly ──
    for (final dx in [-0.135, 0.135]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + dx * s, baseY + s * 0.012),
          width: s * 0.115,
          height: s * 0.065,
        ),
        Paint()..color = Color.lerp(_ink, _rim, 0.25)!,
      );
    }

    // ── the swept-back ear-wisps (canon) — little flame horns reaching
    // outward, waving on their own beat, growing with tier. Painted behind
    // the body. ──
    _earWisps(canvas, s, cx, bodyC, bellyW);

    // ── the body: belly oval + flame teardrop, ONE silhouette. Both fills
    // share one shader positioned on the union's bounds, so they read as a
    // single seamless shape (no Path.combine cost). ──
    final union = Rect.fromLTRB(
        bellyR.left, min(tipY, bellyR.top) - s * 0.02, bellyR.right, bellyR.bottom);
    // warm and lit-from-within: honey up top, amber through the middle, the
    // deep rim only at the far edges — the cream stays for the coal + flame
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.30),
        radius: 1.05,
        colors: [
          Color.lerp(_honey, _cream, 0.35)!,
          _honey,
          _amber,
          _rim,
        ],
        stops: const [0.0, 0.26, 0.64, 1.0],
      ).createShader(union);
    final flame = _flamePath(cx, headY, tipX, tipY, bellyW, s);
    canvas.drawOval(bellyR, bodyPaint);
    canvas.drawPath(flame, bodyPaint);

    // the flame's upper reach glows lighter than the body — a soft cream
    // bloom hugging the tip so the lick reads hot without bleaching the body
    canvas.save();
    canvas.clipPath(flame);
    final flameR = Rect.fromLTRB(cx - bellyW * 0.5, tipY, cx + bellyW * 0.5, headY + s * 0.10);
    canvas.drawRect(
      flameR,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            _honey.withValues(alpha: 0.0),
            _honey.withValues(alpha: 0.35),
            _cream.withValues(alpha: 0.85),
          ],
          stops: const [0.35, 0.72, 1.0],
        ).createShader(flameR),
    );
    // inner flame swirls — soft licks of light inside the crest (blurred so
    // they glow rather than crack; only once the flame is tall enough)
    if (detail && tier >= 1) {
      final lick = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.02
        ..strokeCap = StrokeCap.round
        ..color = _cream.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.012);
      final lp = Path()
        ..moveTo(cx - s * 0.035, headY - flameH * 0.12)
        ..quadraticBezierTo(
            cx - s * 0.01, headY - flameH * 0.45,
            tipX - s * 0.012, headY - flameH * 0.70);
      canvas.drawPath(lp, lick);
      if (tier >= 3) {
        final lp2 = Path()
          ..moveTo(cx + s * 0.05, headY - flameH * 0.08)
          ..quadraticBezierTo(
              cx + s * 0.065, headY - flameH * 0.32,
              tipX + s * 0.028, headY - flameH * 0.52);
        canvas.drawPath(lp2, lick..color = _cream.withValues(alpha: 0.28));
      }
    }
    canvas.restore();

    // ── inside-the-glass light, clipped to the whole silhouette ──
    final clip = Path()
      ..addOval(bellyR)
      ..addPath(flame, Offset.zero);
    canvas.save();
    canvas.clipPath(clip);
    // the glowing coal belly (canon) — a warm hearth LOW in the tummy, well
    // below the mouth, breathing light on the same loop as the body
    final coalGlow = 0.5 + 0.12 * sin(t * 2 * pi * 2 + 0.4) + (happy ? 0.14 : 0);
    final coalC = Offset(cx, bodyC.dy + bellyH * 0.30);
    canvas.drawCircle(
      coalC,
      bellyW * 0.28,
      Paint()
        ..color = Color.lerp(_cream, Colors.white, 0.3)!
            .withValues(alpha: 0.30 + 0.22 * coalGlow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05),
    );
    canvas.drawCircle(
      coalC,
      bellyW * 0.15,
      Paint()
        ..color = Color.lerp(_cream, Colors.white, 0.55)!
            .withValues(alpha: 0.55 + 0.3 * coalGlow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.02),
    );
    if (detail) {
      // faint little coals ringing the glow — tone-on-tone, not a necklace
      final pebble = Paint()
        ..color = Color.lerp(_cream, _honey, 0.4)!.withValues(alpha: 0.55);
      for (final p in const [
        Offset(-0.115, 0.010), Offset(-0.065, 0.052), Offset(0.005, 0.066),
        Offset(0.072, 0.048), Offset(0.118, 0.004),
      ]) {
        canvas.drawCircle(
          coalC.translate(p.dx * s, p.dy * s),
          s * 0.012,
          pebble,
        );
      }
    }
    // a warm back-light rim along the lower-right edge (candlelight wrapping
    // the form) — the touch that sells "lit", not "flat"
    canvas.drawArc(
      bellyR.deflate(s * 0.010),
      pi * 0.1,
      pi * 0.6,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.028
        ..color = Color.lerp(_honey, _cream, 0.5)!.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.012),
    );
    canvas.restore();

    // crisp top-left specular on the flame shoulder + a tiny near-white
    // hotspot — the single sharp glint that makes glass read as glass
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - bellyW * 0.185, headY - s * 0.015),
        width: bellyW * 0.20,
        height: bellyH * 0.13,
      ),
      Paint()
        ..color = _cream.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.014),
    );
    canvas.drawCircle(
      Offset(cx - bellyW * 0.22, headY - s * 0.035),
      s * 0.018,
      Paint()
        ..color =
            Color.lerp(_cream, Colors.white, 0.65)!.withValues(alpha: 0.9),
    );

    // ── tiny nub arms (canon) — little rounded paws resting against the
    // belly either side of the coal glow, warming themselves ──
    if (detail) {
      for (final side in const [-1.0, 1.0]) {
        final ac = Offset(
            cx + side * bellyW * 0.335, bodyC.dy + bellyH * 0.16);
        final ar = Rect.fromCenter(
            center: ac, width: s * 0.085, height: s * 0.13);
        canvas.save();
        canvas.translate(ac.dx, ac.dy);
        canvas.rotate(side * -0.5);
        canvas.translate(-ac.dx, -ac.dy);
        canvas.drawOval(
          ar,
          Paint()
            ..shader = RadialGradient(
              center: Alignment(-side * 0.4, -0.5),
              colors: [
                Color.lerp(_honey, _cream, 0.2)!,
                Color.lerp(_amber, _rim, 0.25)!,
              ],
            ).createShader(ar),
        );
        canvas.restore();
      }
    }

    _face(canvas, s, cx, bodyC, bellyW, bellyH, detail);

    // ── the painted costume (round-62), sitting on the tucked crest ──
    if (outfit != null) {
      _outfit(canvas, s, cx, bodyC, bellyW, bellyH, headY);
    }

    // ── high-tier sparkle motes drifting around the blaze ──
    if (tier >= 4) {
      final sp = Paint()
        ..color = _cream.withValues(alpha: 0.85)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.006);
      for (final p in const [
        Offset(0.18, 0.30),
        Offset(0.84, 0.36),
        Offset(0.76, 0.62),
      ]) {
        canvas.drawCircle(Offset(p.dx * s, p.dy * s), s * 0.014, sp);
      }
    }
  }

  /// Paint the worn costume over the base creature (round-62, replacing the AI
  /// outfit sprites). Each is a few flat, softly-shaded shapes in the same
  /// style as the rest of the ember, sitting on the tucked-down crest.
  void _outfit(Canvas canvas, double s, double cx, Offset bodyC, double bellyW,
      double bellyH, double headY) {
    final crownY = headY + s * 0.045; // where a hat rests on the crown
    final eyeY = bodyC.dy - bellyH * 0.22;
    final headW = bellyW * 0.62;
    switch (outfit!) {
      case Outfit.wayfarer:
        _hatWayfarer(canvas, s, cx, crownY, headW);
      case Outfit.herbalist:
        _hoodHerbalist(canvas, s, cx, crownY, headW, eyeY);
      case Outfit.knight:
        _helmKnight(canvas, s, cx, crownY, headW, eyeY);
      case Outfit.wizard:
        _hatWizard(canvas, s, cx, crownY, headW);
    }
  }

  // a soft top-left highlight blob, shared by the costumes so they catch the
  // same candlelight as the body
  void _sheen(Canvas canvas, Offset c, double w, double h, Color col) {
    canvas.drawOval(
      Rect.fromCenter(center: c, width: w, height: h),
      Paint()
        ..color = col.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.4),
    );
  }

  void _hatWayfarer(
      Canvas canvas, double s, double cx, double crownY, double headW) {
    const dark = Color(0xFF4E3320), mid = Color(0xFF8A5A34), band = Color(0xFFC89A5C);
    // wide soft brim
    final brim = Rect.fromCenter(
        center: Offset(cx, crownY + s * 0.01), width: headW * 2.0, height: s * 0.12);
    canvas.drawOval(brim, Paint()..color = dark);
    canvas.drawOval(brim.deflate(s * 0.009),
        Paint()..color = mid.withValues(alpha: 0.9));
    // rounded crown cap
    final cap = RRect.fromRectAndCorners(
      Rect.fromCenter(
          center: Offset(cx, crownY - s * 0.06), width: headW * 0.92, height: s * 0.17),
      topLeft: Radius.circular(s * 0.07),
      topRight: Radius.circular(s * 0.07),
      bottomLeft: Radius.circular(s * 0.02),
      bottomRight: Radius.circular(s * 0.02),
    );
    canvas.drawRRect(cap, Paint()..color = mid);
    // band + a little buckle
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(cx, crownY - s * 0.008), width: headW * 0.92, height: s * 0.028),
        Paint()..color = band);
    canvas.drawRect(
        Rect.fromCenter(center: Offset(cx + headW * 0.2, crownY - s * 0.008),
            width: s * 0.04, height: s * 0.04),
        Paint()..color = dark);
    _sheen(canvas, Offset(cx - headW * 0.22, crownY - s * 0.10),
        headW * 0.4, s * 0.09, const Color(0xFFE8C494));
  }

  void _hoodHerbalist(Canvas canvas, double s, double cx, double crownY,
      double headW, double eyeY) {
    const dark = Color(0xFF3C5836), mid = Color(0xFF5E844F), edge = Color(0xFF8FB07E);
    // a cowl framing the face: over the crown, down the sides, arched open
    // above the eyes so the face shows
    final hood = Path()
      ..moveTo(cx - headW * 0.82, eyeY + s * 0.02)
      ..quadraticBezierTo(cx - headW * 1.0, crownY - s * 0.06,
          cx, crownY - s * 0.14)
      ..quadraticBezierTo(cx + headW * 1.0, crownY - s * 0.06,
          cx + headW * 0.82, eyeY + s * 0.02)
      ..quadraticBezierTo(
          cx + headW * 0.5, eyeY - s * 0.04, cx, eyeY - s * 0.05)
      ..quadraticBezierTo(
          cx - headW * 0.5, eyeY - s * 0.04, cx - headW * 0.82, eyeY + s * 0.02)
      ..close();
    canvas.drawPath(hood, Paint()..color = dark);
    // a lighter inner rim around the face opening
    canvas.drawPath(
      hood,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.02
        ..color = mid,
    );
    // fill the upper hood with the mid tone (leaving the rim darker)
    final capFill = Path()
      ..moveTo(cx - headW * 0.7, crownY + s * 0.02)
      ..quadraticBezierTo(
          cx - headW * 0.82, crownY - s * 0.05, cx, crownY - s * 0.11)
      ..quadraticBezierTo(
          cx + headW * 0.82, crownY - s * 0.05, cx + headW * 0.7, crownY + s * 0.02)
      ..quadraticBezierTo(cx, crownY - s * 0.02, cx - headW * 0.7, crownY + s * 0.02)
      ..close();
    canvas.drawPath(capFill, Paint()..color = mid);
    // a little leaf sprig on top
    final lx = cx + headW * 0.05, ly = crownY - s * 0.15;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(lx, ly), width: s * 0.07, height: s * 0.04),
        Paint()..color = edge);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(lx + s * 0.05, ly - s * 0.02),
            width: s * 0.055, height: s * 0.03),
        Paint()..color = edge.withValues(alpha: 0.85));
    _sheen(canvas, Offset(cx - headW * 0.3, crownY - s * 0.06),
        headW * 0.4, s * 0.08, edge);
  }

  void _helmKnight(Canvas canvas, double s, double cx, double crownY,
      double headW, double eyeY) {
    const dark = Color(0xFF454E56), steel = Color(0xFF8C99A2), lite = Color(0xFFC3CDD3);
    const gold = Color(0xFFE8CC82), plume = Color(0xFFC65746);
    // plume first (behind the dome)
    final pl = Path()
      ..moveTo(cx, crownY - s * 0.10)
      ..quadraticBezierTo(cx + s * 0.02, crownY - s * 0.24, cx + s * 0.10, crownY - s * 0.30)
      ..quadraticBezierTo(cx + s * 0.02, crownY - s * 0.20, cx - s * 0.005, crownY - s * 0.10)
      ..close();
    canvas.drawPath(pl, Paint()..color = plume);
    // dome helm over the crown down to the forehead (above the eyes)
    final dome = Path()
      ..moveTo(cx - headW * 0.62, eyeY - s * 0.02)
      ..quadraticBezierTo(cx - headW * 0.72, crownY - s * 0.10, cx, crownY - s * 0.12)
      ..quadraticBezierTo(cx + headW * 0.72, crownY - s * 0.10, cx + headW * 0.62, eyeY - s * 0.02)
      ..quadraticBezierTo(cx, eyeY + s * 0.01, cx - headW * 0.62, eyeY - s * 0.02)
      ..close();
    canvas.drawPath(
      dome,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [lite, steel, dark],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTRB(
            cx - headW * 0.7, crownY - s * 0.12, cx + headW * 0.7, eyeY)),
    );
    // gold brow band
    canvas.drawPath(
      Path()
        ..moveTo(cx - headW * 0.62, eyeY - s * 0.02)
        ..quadraticBezierTo(cx, eyeY + s * 0.01, cx + headW * 0.62, eyeY - s * 0.02),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.03
        ..color = gold,
    );
    // nose guard between the eyes
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx, eyeY + s * 0.04), width: s * 0.05, height: s * 0.12),
          Radius.circular(s * 0.02)),
      Paint()..color = steel,
    );
    _sheen(canvas, Offset(cx - headW * 0.22, crownY - s * 0.06),
        headW * 0.4, s * 0.10, lite);
  }

  void _hatWizard(
      Canvas canvas, double s, double cx, double crownY, double headW) {
    const dark = Color(0xFF423A70), mid = Color(0xFF6A62A8), lite = Color(0xFF9A92D8);
    const star = Color(0xFFFFF1C4);
    // soft brim
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, crownY), width: headW * 1.7, height: s * 0.10),
        Paint()..color = dark);
    // tall cone leaning + drooping tip
    final tipX = cx + s * 0.10, tipY = crownY - s * 0.42;
    final cone = Path()
      ..moveTo(cx - headW * 0.62, crownY - s * 0.01)
      ..quadraticBezierTo(
          cx - headW * 0.20, crownY - s * 0.24, tipX - s * 0.02, tipY + s * 0.02)
      ..quadraticBezierTo(tipX + s * 0.06, tipY - s * 0.01, tipX + s * 0.04, tipY + s * 0.05)
      ..quadraticBezierTo(cx + headW * 0.35, crownY - s * 0.14, cx + headW * 0.62, crownY - s * 0.01)
      ..quadraticBezierTo(cx, crownY - s * 0.06, cx - headW * 0.62, crownY - s * 0.01)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [dark, mid, lite],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromLTRB(
            cx - headW * 0.62, tipY, cx + headW * 0.62, crownY)),
    );
    // a couple of little stars
    void starAt(double x, double y, double r) {
      final p = Paint()..color = star;
      for (var i = 0; i < 4; i++) {
        final a = i * pi / 2;
        canvas.drawCircle(Offset(x + cos(a) * r, y + sin(a) * r), r * 0.5, p);
      }
      canvas.drawCircle(Offset(x, y), r * 0.7, p);
    }
    starAt(cx + s * 0.01, crownY - s * 0.14, s * 0.022);
    starAt(cx + s * 0.05, crownY - s * 0.26, s * 0.016);
    _sheen(canvas, Offset(cx - headW * 0.18, crownY - s * 0.16),
        headW * 0.3, s * 0.12, lite);
  }

  /// The rising flame that IS the top of the head — a lick that narrows fast
  /// off the head and S-curves into a fine tip leaning with the sway.
  Path _flamePath(
      double cx, double headY, double tipX, double tipY, double bellyW, double s) {
    final h = headY - tipY;
    final wl = cx - bellyW * 0.365; // left shoulder of the neck
    final wr = cx + bellyW * 0.365; // right shoulder
    final anchor = headY + s * 0.07; // tucked into the belly so no seam shows
    final p = Path()..moveTo(wl, anchor);
    // left side hugs the head then whips up into the tip (slight S)
    p.cubicTo(
      wl + s * 0.005, headY - h * 0.52,
      tipX - s * 0.155, tipY + h * 0.52,
      tipX, tipY,
    );
    // right side billows out a touch further before falling away
    p.cubicTo(
      tipX + s * 0.175, tipY + h * 0.50,
      wr + s * 0.012, headY - h * 0.42,
      wr, anchor,
    );
    p.close();
    return p;
  }

  /// The two swept-back ear-wisps — curved flame crescents reaching outward
  /// and dipping like little wings, tips flicking up, each waving on its own
  /// phase. They grow with tier.
  void _earWisps(
      Canvas canvas, double s, double cx, Offset bodyC, double bellyW) {
    final grow = 0.72 + tier * 0.10; // tier 0 nubs → tier 5 wings
    final rootY = bodyC.dy - s * 0.055;
    for (final side in const [-1.0, 1.0]) {
      final wag = sin(t * 2 * pi + (side < 0 ? 0.6 : 2.2)) * s * 0.014;
      final rootX = cx + side * bellyW * 0.40;
      final reach = s * 0.24 * grow;
      // the tip: swept outward and DOWN like a wing, the very end flicking up
      final tip = Offset(
        rootX + side * reach,
        rootY + s * 0.015 * grow + wag,
      );
      // a drooping crescent: thick at the root, the lower edge sagging like a
      // wing's belly, the upper edge arching over it — a banana, not a spike
      final wisp = Path()
        ..moveTo(rootX, rootY + s * 0.075 * grow)
        ..quadraticBezierTo(
          rootX + side * reach * 0.45, rootY + s * 0.175 * grow, // sag down
          tip.dx, tip.dy,
        )
        ..quadraticBezierTo(
          rootX + side * reach * 0.60, rootY + s * 0.02 * grow, // arch back
          rootX, rootY - s * 0.045 * grow,
        )
        ..close();
      final r = Rect.fromPoints(
          Offset(rootX, rootY - s * 0.1), Offset(tip.dx, tip.dy + s * 0.12));
      canvas.drawPath(
        wisp,
        Paint()
          ..shader = LinearGradient(
            begin: side < 0 ? Alignment.centerRight : Alignment.centerLeft,
            end: side < 0 ? Alignment.centerLeft : Alignment.centerRight,
            colors: [_amber, _honey, Color.lerp(_honey, _cream, 0.65)!],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(r),
      );
      // a soft glow off each wisp tip so they read as burning, not solid
      canvas.drawCircle(
        tip,
        s * 0.028 * grow,
        Paint()
          ..color = _honey.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.028),
      );
    }
  }

  void _face(Canvas canvas, double s, double cx, Offset bodyC, double bellyW,
      double bellyH, bool detail) {
    final eyeY = bodyC.dy - bellyH * 0.22;
    final eyeDx = s * 0.125;
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.032
      ..strokeCap = StrokeCap.round;

    // cheeks — a soft always-on warmth, blooming when happy
    final blush = Paint()
      ..color = Color(happy ? 0x77E08A7A : 0x55D88A8A)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.016);
    for (final dx in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + dx * s * 0.205, eyeY + s * 0.095),
            width: s * 0.115,
            height: s * 0.075),
        blush,
      );
    }

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
      // big dark glossy eyes (canon): a deep-warm iris ring around near-black,
      // one big catchlight + one small sparkle. A slow saccade shifts the
      // catchlights so it glances around the room between blinks.
      final eyeR = s * (happy ? 0.088 : 0.082);
      final gaze = _saccade(s);
      for (final dx in [-eyeDx, eyeDx]) {
        final ec = Offset(cx + dx, eyeY);
        final er =
            Rect.fromCenter(center: ec, width: eyeR * 1.75, height: eyeR * 2.05);
        canvas.drawOval(
          er,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(0, 0.35),
              colors: [
                Color.lerp(_ink, _amber, 0.55)!,
                Color.lerp(_ink, _amber, 0.18)!,
                _ink,
              ],
              stops: const [0.0, 0.45, 1.0],
            ).createShader(er),
        );
        // big upper catchlight, riding the glance
        canvas.drawCircle(
          ec.translate(-eyeR * 0.30 + gaze.dx, -eyeR * 0.48 + gaze.dy),
          eyeR * 0.40,
          Paint()..color = Colors.white.withValues(alpha: 0.95),
        );
        // small lower sparkle
        canvas.drawCircle(
          ec.translate(eyeR * 0.36 + gaze.dx, eyeR * 0.52 + gaze.dy),
          eyeR * 0.18,
          Paint()..color = Colors.white.withValues(alpha: 0.65),
        );
      }
    }

    // mouth — a tiny contented :3 when idle, a proper open smile when happy
    final mouthY = eyeY + s * (happy ? 0.135 : 0.12);
    if (happy) {
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(cx, mouthY),
            width: s * 0.23,
            height: s * 0.16),
        pi * 0.1,
        pi * 0.8,
        false,
        stroke,
      );
    } else {
      // two little arcs meeting in the middle — the canon's cat-smile
      for (final dx in [-1.0, 1.0]) {
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(cx + dx * s * 0.042, mouthY),
              width: s * 0.085,
              height: s * 0.055),
          pi * 0.15,
          pi * 0.7,
          false,
          stroke..strokeWidth = s * 0.026,
        );
      }
    }

    _trait(canvas, s, cx, eyeY, eyeDx, detail);
  }

  /// Where the eyes are glancing right now: a small offset that hops between
  /// rest and a couple of side-glances a few times per loop, quantized so it
  /// reads as intent (look, hold, look back) rather than wander.
  Offset _saccade(double s) {
    final step = (t * 5).floor(); // five holds per loop
    final r = sin(step * 12.9898) * 43758.5453;
    final h = r - r.floorToDouble(); // stable pseudo-random per hold
    if (h < 0.45) return Offset.zero; // mostly looking at you
    final a = h * 2 * pi;
    return Offset(cos(a) * s * 0.012, sin(a) * s * 0.008);
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
      old.outfit != outfit ||
      old.t != t ||
      !listEquals(old.skin, skin);
}
