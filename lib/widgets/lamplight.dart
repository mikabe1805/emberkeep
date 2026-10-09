import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// The parchment of every lamp: a backlit-vellum transmittance map (1 = the
/// light passes, darker = denser paper), procedurally generated so it carries
/// the cloudy formation, soft veins and fibres of the room lamp's shade.
/// Provenance: design/comparisons/2026-10-04/primary-controls/lamplight/SPEC.md.
const lampVellumAsset = 'assets/quest/lamplight-vellum-v3.webp';

/// The paper is decoded once and shared by every lamp. Until it arrives (or
/// if it never does) the lamp paints its light without the paper: complete,
/// just smoother.
abstract final class LampVellum {
  static Future<void>? _loading;
  static final ValueNotifier<ui.Image?> image = ValueNotifier(null);

  static Future<void> load() => _loading ??= _decode();

  static Future<void> _decode() async {
    try {
      final data = await rootBundle.load(lampVellumAsset);
      final codec = await ui.instantiateImageCodec(
        Uint8List.view(data.buffer, data.offsetInBytes, data.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      image.value = frame.image;
    } catch (_) {
      // Paper is an enhancement; the light alone is a finished frame.
    }
  }

  static void ensure() {
    if (_loading == null) unawaited(load());
  }
}

/// The silhouette of a lamp shade seen from the front, a little above: the
/// sides lean in toward the top (the shade is a truncated cone), and the top
/// and bottom edges are the front arcs of its two rims, sagging gently. It
/// belongs to the lamp, not to the glass card's chamfered panes, so a lit
/// control never reads as the old plate in a new colour. [cut] sets the size
/// of the form (lean, sag and corner softness together).
class LampGeometry {
  const LampGeometry._(this.size, this.taper, this.sag, this.radius);

  factory LampGeometry.of(Size size, double cut) {
    final c = cut.clamp(0.0, 24.0).toDouble();
    // A long, low control needs more lean and sag than a squarer one to read
    // as a shade rather than a flat strip: the form scales with the width
    // (from 3.4 : 1 up, to at most 1.8 times), and only for lamps with a full
    // cut, so the near-square inset lamp stays near-square.
    final wide = size.width / math.max(size.height, 1) / 3.4;
    final fullCut = ((c - 4) / 6).clamp(0.0, 1.0);
    final k = 1 + (wide.clamp(1.0, 1.8) - 1) * fullCut;
    final taper = math.min(c * 0.85 * k, size.height * 0.2 * k);
    final sag = math.min(c * 0.28 * k, size.height * 0.07 * k);
    final radius = math.min(c * 0.55, size.height / 4);
    return LampGeometry._(size, taper, sag, radius);
  }

  final Size size;

  /// How far each side leans in at the top.
  final double taper;

  /// How far the rims' front arcs drop at their middle.
  final double sag;
  final double radius;

  double get _w => size.width;
  double get _h => size.height;

  /// y of the top rim at x (0 at the ends, [sag] at the middle).
  double topY(double x, {double inset = 0}) {
    final u = ((x - taper) / math.max(_w - 2 * taper, 1)).clamp(0.0, 1.0);
    return inset + sag * 4 * u * (1 - u);
  }

  /// y of the bottom rim at x ([_h] at the middle, [sag] higher at the ends).
  double bottomY(double x, {double inset = 0}) {
    final u = (x / math.max(_w, 1)).clamp(0.0, 1.0);
    return _h - inset - sag * (1 - 4 * u * (1 - u));
  }

  /// The left edge x at height y (the lean).
  double leftAt(double y) =>
      taper * (1 - (y / math.max(_h, 1)).clamp(0.0, 1.0));

  Path get path {
    final w = _w;
    final h = _h;
    final t = taper;
    final s = sag;
    final r = radius;
    // Corner points, then fillets that run into the curved rims.
    final tl = Offset(t, 0);
    final tr = Offset(w - t, 0);
    final br = Offset(w, h - s);
    final bl = Offset(0, h - s);
    Offset toward(Offset from, Offset to, double d) {
      final v = to - from;
      final len = v.distance;
      return len == 0 ? from : from + v / len * math.min(d, len / 2);
    }

    final topCtrl = Offset(w / 2, 2 * s);
    final botCtrl = Offset(w / 2, h + s);
    final p = Path();
    // top-left corner: from the left edge into the top rim
    final a0 = toward(tl, bl, r * 1.6);
    p.moveTo(a0.dx, a0.dy);
    final a1 = toward(tl, topCtrl, r * 1.1);
    p.quadraticBezierTo(tl.dx, tl.dy, a1.dx, a1.dy);
    // along the top rim (approximate the arc by a quadratic from a1 to b0)
    final b0 = toward(tr, topCtrl, r * 1.1);
    p.quadraticBezierTo(w / 2, 2 * s * 0.98 + 0.001, b0.dx, b0.dy);
    final b1 = toward(tr, br, r * 1.6);
    p.quadraticBezierTo(tr.dx, tr.dy, b1.dx, b1.dy);
    // right edge down to the bottom-right corner
    final c0 = toward(br, tr, r * 1.6);
    p.lineTo(c0.dx, c0.dy);
    final c1 = toward(br, botCtrl, r * 1.1);
    p.quadraticBezierTo(br.dx, br.dy, c1.dx, c1.dy);
    final d0 = toward(bl, botCtrl, r * 1.1);
    p.quadraticBezierTo(w / 2, h + s * 0.98, d0.dx, d0.dy);
    final d1 = toward(bl, tl, r * 1.6);
    p.quadraticBezierTo(bl.dx, bl.dy, d1.dx, d1.dy);
    p.lineTo(a0.dx, a0.dy);
    p.close();
    return p;
  }

  /// The top rim as a line [inset] below the edge, from end to end.
  Path rim({required bool top, double inset = 0, double pad = 0}) {
    final x0 = (top ? taper : 0.0) + pad;
    final x1 = _w - (top ? taper : 0.0) - pad;
    final p = Path();
    const n = 18;
    for (var i = 0; i <= n; i++) {
      final x = x0 + (x1 - x0) * i / n;
      final y = top ? topY(x, inset: inset) : bottomY(x, inset: inset);
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    return p;
  }
}

class LampShadeClipper extends CustomClipper<Path> {
  const LampShadeClipper({this.cut = 10});

  final double cut;

  @override
  Path getClip(Size size) => LampGeometry.of(size, cut).path;

  @override
  bool shouldReclip(LampShadeClipper old) => old.cut != cut;
}

/// The lamp's outline as a [ShapeBorder], for [Pressable]'s under-edge.
class LampShadeBorder extends OutlinedBorder {
  const LampShadeBorder({this.cut = 10, super.side = BorderSide.none});

  final double cut;

  @override
  OutlinedBorder copyWith({BorderSide? side}) =>
      LampShadeBorder(cut: cut, side: side ?? this.side);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      LampGeometry.of(rect.size, cut).path.shift(rect.topLeft);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(getOuterPath(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) =>
      LampShadeBorder(cut: cut * t, side: side.scale(t));
}

/// How much the lamp is lit.
///
/// [lit] is the one luminous primary control of a view. [low] is a lamp
/// turned down: a resolved action that is remembered, not offered. [off] is
/// an unlit shade: the action exists but is not ready.
enum LampLevel { lit, low, off }

/// The room's one light source is the lamp, so the primary control is lit
/// like the lamp's shade: warm parchment lit from within, its light falling
/// from a cream core through amber to a deep umber at the shoulders, the
/// shade's panel seams converging a little toward the top, light leaking
/// brightest along the bottom binding and spilling softly onto the surface
/// below. The hue is the room lamp's own (24-36 degrees), never a yellow slab.
///
/// The core moves only when the light input moves: phone tilt through [light]
/// and the page's scroll through [scroll]. Nothing animates on a clock. A
/// press turns the light up under the finger at once ([pressed]); release
/// eases back. Reduce Motion parks the core and keeps every state.
class LampShade extends StatefulWidget {
  const LampShade({
    super.key,
    required this.child,
    this.cut = 10,
    this.level = LampLevel.lit,
    this.pressed = false,
    this.light,
    this.scroll,
    this.reduceMotion = false,
    this.spill = true,
    this.dimFrom,
  });

  final Widget child;
  final double cut;
  final LampLevel level;
  final bool pressed;

  /// The shared tilt/pointer light field. Null parks the core at rest.
  final ValueListenable<Offset>? light;

  /// Scroll offset of the page the lamp sits on.
  final ValueListenable<double>? scroll;
  final bool reduceMotion;

  /// The soft pool of light the shade throws onto the surface below it.
  final bool spill;

  /// When set, the lamp mounts at this warmth and settles to [level]: a
  /// resolved action turning its lamp down instead of swapping to a new plate.
  final double? dimFrom;

  /// Test seam: forces every lamp to one level (the yellow check's "turn the
  /// warm accent off" pass). Never set in the app.
  static LampLevel? debugForceLevel;

  static double warmthFor(LampLevel level, {bool pressed = false}) =>
      switch (level) {
        LampLevel.lit => pressed ? 1.2 : 1.0,
        LampLevel.low => pressed ? 0.4 : 0.3,
        LampLevel.off => 0.0,
      };

  @override
  State<LampShade> createState() => _LampShadeState();
}

/// The width of the words on a lamp, reported by [LampLabel] during layout so
/// the light can sit behind them at any text size.
class _LampWords extends ChangeNotifier {
  double halfWidth = 0;

  void report(double value) {
    if ((value - halfWidth).abs() < 0.5) return;
    halfWidth = value;
    notifyListeners();
  }
}

class _LampScope extends InheritedWidget {
  const _LampScope({required this.words, required super.child});

  final _LampWords words;

  static _LampWords? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_LampScope>()?.words;

  @override
  bool updateShouldNotify(_LampScope old) => old.words != words;
}

class _LampShadeState extends State<LampShade> {
  final _words = _LampWords();

  @override
  void dispose() {
    _words.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    LampVellum.ensure();
    final still =
        widget.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final shownLevel = LampShade.debugForceLevel ?? widget.level;
    final target = LampShade.warmthFor(shownLevel, pressed: widget.pressed);
    final duration = still || widget.pressed
        ? Duration.zero
        : widget.dimFrom != null
        ? const Duration(milliseconds: 560)
        : const Duration(milliseconds: 200);
    final inputs = Listenable.merge([
      ?widget.light,
      ?widget.scroll,
      LampVellum.image,
    ]);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: widget.dimFrom ?? target, end: target),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: _LampScope(words: _words, child: widget.child),
      builder: (context, warmth, body) {
        return AnimatedBuilder(
          animation: inputs,
          child: body,
          builder: (context, body) {
            final tilt = still
                ? Offset.zero
                : widget.light?.value ?? Offset.zero;
            final offset = still ? 0.0 : widget.scroll?.value ?? 0.0;
            // The bulb sits low in the shade, a touch left of centre at rest
            // (the room's lamp stands to the left). Tilt slides it; scroll
            // rolls it slowly across as the page moves under the eye. The
            // travel is small enough that the words always stay in its light.
            final core = Offset(
              (0.485 + tilt.dx * 0.075 + 0.085 * math.sin(offset / 170))
                  .clamp(0.36, 0.64)
                  .toDouble(),
              (0.62 + tilt.dy * 0.10 + 0.07 * math.sin(offset / 240))
                  .clamp(0.45, 0.8)
                  .toDouble(),
            );
            final paper = LampVellum.image.value;
            return Stack(
              clipBehavior: Clip.none,
              fit: StackFit.passthrough,
              children: [
                if (widget.spill && warmth > 0.01)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _LampSpillPainter(warmth: warmth, core: core),
                      ),
                    ),
                  ),
                ClipPath(
                  clipper: LampShadeClipper(cut: widget.cut),
                  child: CustomPaint(
                    painter: _LampShadePainter(
                      warmth: warmth,
                      core: core,
                      cut: widget.cut,
                      paper: paper,
                      words: _words,
                    ),
                    child: body,
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _LampRimPainter(
                        warmth: warmth,
                        core: core,
                        cut: widget.cut,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Colours of the lit shade, sampled from the room lamp (h 24-36).
abstract final class LampTone {
  static const core = Color(0xFFFCE6C4);
  static const cream = Color(0xFFF2C892);
  static const amber = Color(0xFFCB874D);
  static const umber = Color(0xFF70452B);
  static const shoulder = Color(0xFF3B271D);
  static const pressedCore = Color(0xFFFFF8EC);
  static const pressedCream = Color(0xFFFBE2BA);

  /// Turned up under the finger, the whole shade fills with light: the
  /// shoulders lift from umber to amber, not just the core.
  static const pressedAmber = Color(0xFFE2A66C);
  static const pressedUmber = Color(0xFFA8693E);
  static const pressedShoulder = Color(0xFF6B4329);
  static const lowCore = Color(0xFFB9783F);
  static const lowCream = Color(0xFF93582B);
  static const lowAmber = Color(0xFF64391B);
  static const lowUmber = Color(0xFF3A2112);
  static const lowShoulder = Color(0xFF2C1A10);

  /// The unlit paper behind the light.
  static const paperTop = Color(0xFF2B1B11);
  static const paperBottom = Color(0xFF21150D);

  /// Ink printed on the lit shade.
  static const ink = Color(0xFF2B160A);

  /// The label of a lamp turned low: light coming through the paper.
  static const lowInk = Color(0xFFF0D3A2);
  static const offInk = Color(0xFFA8998A);
}

class _LampShadePainter extends CustomPainter {
  _LampShadePainter({
    required this.warmth,
    required this.core,
    required this.cut,
    required this.paper,
    required this.words,
  }) : super(repaint: words);

  final double warmth;
  final Offset core;
  final double cut;
  final ui.Image? paper;

  /// Reported during layout, read at paint: the light follows the words
  /// without rebuilding anything.
  final _LampWords words;

  @override
  void paint(Canvas canvas, Size size) {
    final wordsHalfWidth = words.halfWidth;
    final face = Offset.zero & size;
    final w = size.width;
    final h = size.height;
    final cx = core.dx * w;
    final cy = core.dy * h;

    // The unlit paper.
    canvas.drawRect(
      face,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [LampTone.paperTop, LampTone.paperBottom],
        ).createShader(face),
    );

    final lit = warmth.clamp(0.0, 1.0).toDouble();
    final hot = ((warmth - 1.0) / 0.2).clamp(0.0, 1.0).toDouble();
    final low = (warmth / 0.3).clamp(0.0, 1.0).toDouble();
    // 0..0.3 is the lamp turned low, 0.3..1 brings it up to full.
    final up = ((warmth - 0.3) / 0.7).clamp(0.0, 1.0).toDouble();

    Color tone(Color lowC, Color litC, Color? hotC) {
      final base = Color.lerp(lowC, litC, up)!;
      return hotC == null ? base : Color.lerp(base, hotC, hot)!;
    }

    canvas.saveLayer(face, Paint());
    if (warmth > 0.01) {
      // The light through the shade: an ellipse wider than tall, brightest
      // just below centre and sized to the words it sits behind, so the
      // shoulders of a wide lamp fall away into umber instead of the whole
      // face reading as one warm block.
      final ry = h * (0.98 + 0.22 * hot);
      final rx =
          math
              .max(math.max(w * 0.34, h * 1.9), wordsHalfWidth + h * 0.95)
              .clamp(0.0, w * 0.62)
              .toDouble() *
          (1 + 0.18 * hot);
      final glowPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, cy),
          ry,
          [
            tone(
              LampTone.lowCore,
              LampTone.core,
              LampTone.pressedCore,
            ).withValues(alpha: low),
            tone(
              LampTone.lowCream,
              LampTone.cream,
              LampTone.pressedCream,
            ).withValues(alpha: low),
            tone(
              LampTone.lowAmber,
              LampTone.amber,
              LampTone.pressedAmber,
            ).withValues(alpha: 0.97 * low),
            tone(
              LampTone.lowUmber,
              LampTone.umber,
              LampTone.pressedUmber,
            ).withValues(alpha: 0.94 * low),
            tone(
              LampTone.lowShoulder,
              LampTone.shoulder,
              LampTone.pressedShoulder,
            ).withValues(alpha: 0.9 * low),
          ],
          const [0.0, 0.26, 0.56, 0.82, 1.0],
          TileMode.clamp,
          _scaleAbout(Offset(cx, cy), rx / ry, 1).storage,
        );
      canvas.drawRect(face, glowPaint);

      // The shade's top is further from the bulb.
      canvas.drawRect(
        face,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A0D05).withValues(alpha: 0.34 * low),
              const Color(0x001A0D05),
            ],
            stops: const [0, 0.55],
          ).createShader(face),
      );

      // Light leaking under the bottom binding, brightest below the core.
      final leak = Paint()
        ..blendMode = BlendMode.screen
        ..shader = ui.Gradient.radial(
          Offset(cx, h + 1.5),
          h * 0.5,
          [
            const Color(0xFFFFF4E0).withValues(alpha: 0.78 * lit + 0.1 * hot),
            const Color(0xFFFFDDAA).withValues(alpha: 0.26 * lit),
            const Color(0x00FFDDAA),
          ],
          const [0.0, 0.42, 1.0],
          TileMode.clamp,
          _scaleAbout(
            Offset(cx, h + 1.5),
            math.max(w * 0.3, wordsHalfWidth + h) / (h * 0.5),
            1,
          ).storage,
        );
      canvas.drawRect(face, leak);
    } else {
      // An unlit shade: the paper only, catching the room's dim light from
      // above, so its formation still reads and it never looks like a slab.
      canvas.drawRect(
        face,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x787D6552), Color(0x4A574233)],
          ).createShader(face),
      );
    }

    // The paper: transmitted light is the light times the paper.
    final image = paper;
    if (image != null) {
      final iw = image.width.toDouble();
      final ih = image.height.toDouble();
      // About one paper texel per device pixel at 3x, so every lamp shows the
      // same fibre scale; larger lamps sample more of the sheet.
      var sw = math.min(iw, w * 3);
      var sh = math.min(ih, h * 3);
      final aspect = w / h;
      if (sw / sh > aspect) {
        sw = sh * aspect;
      } else {
        sh = sw / aspect;
      }
      // Each size of lamp reads a different part of the sheet.
      final seed = ((w * 7.3 + h * 13.1) % 97) / 97;
      final src = Rect.fromLTWH(
        (iw - sw) * seed,
        (ih - sh) * (0.5 - 0.3 * (seed - 0.5)),
        sw,
        sh,
      );
      final sheet = Paint()
        ..blendMode = BlendMode.modulate
        ..filterQuality = FilterQuality.medium;
      canvas.drawImageRect(image, src, face, sheet);
      // Unlit, the paper is seen by reflected light, where its cloudy
      // formation reads more strongly than when light shines through it.
      if (warmth <= 0.01) canvas.drawImageRect(image, src, face, sheet);
    }
    canvas.restore();

    if (warmth <= 0.01) return;

    // Panel seams: the front panel is wide and centred like the room lamp's,
    // its two seams leaning in toward the top, so the face reads as a
    // section of a shade rather than a flat plate. A seam is where two
    // sheets overlap: a soft band that passes a little less light.
    final front = math.max(w * 0.24, wordsHalfWidth + h * 0.45);
    if (front < w * 0.47) {
      for (final side in const [-1.0, 1.0]) {
        final bottomX = w / 2 + side * front;
        final lean = (w / 2 - LampGeometry.of(size, cut).taper) / (w / 2);
        final topX = w / 2 + side * front * lean;
        final reach = math.exp(-math.pow((bottomX - cx) / (0.36 * w), 2));
        final k = (reach * low).clamp(0.0, 1.0);
        canvas.drawLine(
          Offset(topX, 0),
          Offset(bottomX, h),
          Paint()
            ..strokeWidth = 1.8
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.7)
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF341706).withValues(alpha: 0.18 * k),
                const Color(0xFF341706).withValues(alpha: 0.42 * k),
              ],
            ).createShader(face),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LampShadePainter old) =>
      old.warmth != warmth ||
      old.core != core ||
      old.cut != cut ||
      old.paper != paper ||
      old.words != words;
}

/// The shade's bindings and edge. Not a stroke of one colour: every point of
/// the rim takes the light it is close to, so the bottom binding glows under
/// the core and the top corners stay in shadow.
class _LampRimPainter extends CustomPainter {
  const _LampRimPainter({
    required this.warmth,
    required this.core,
    required this.cut,
  });

  final double warmth;
  final Offset core;
  final double cut;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = core.dx * w;
    final lit = warmth.clamp(0.0, 1.2).toDouble();
    final shade = LampGeometry.of(size, cut);

    // The edge: lit by the core it surrounds.
    final edge = shade.path;
    canvas.drawPath(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = ui.Gradient.radial(
          Offset(cx, h * 0.9),
          h * 1.1,
          [
            Color.lerp(
              const Color(0xFF3A2416),
              const Color(0xFFE4AE73),
              (lit * 0.85).clamp(0.0, 1.0),
            )!.withValues(alpha: 0.85),
            Color.lerp(
              const Color(0xFF2E1D12),
              const Color(0xFF9A5E31),
              (lit * 0.8).clamp(0.0, 1.0),
            )!.withValues(alpha: 0.8),
            const Color(0xFF24160D).withValues(alpha: 0.85),
          ],
          const [0.0, 0.45, 1.0],
          TileMode.clamp,
          _scaleAbout(Offset(cx, h * 0.9), (w * 0.55) / (h * 1.1), 1).storage,
        ),
    );

    // Top binding: the wire rim of a shade, in shadow, following the rim's arc.
    canvas.drawPath(
      shade.rim(top: true, inset: 0.7, pad: shade.radius * 1.1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF2E1A0D).withValues(alpha: 0.9),
    );
    if (warmth > 0.01) {
      final topLeft = shade.taper + shade.radius * 1.1 + 2;
      final topRight = w - topLeft;
      canvas.drawPath(
        shade.rim(top: true, inset: 1.9, pad: shade.radius * 1.1 + 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..shader = ui.Gradient.linear(
            Offset(topLeft, 0),
            Offset(topRight, 0),
            [
              const Color(0x00FFE3B5),
              const Color(0xFFFFE3B5).withValues(alpha: 0.22 * lit),
              const Color(0x00FFE3B5),
            ],
            [0.0, core.dx.clamp(0.1, 0.9), 1.0],
          ),
      );

      // Bottom binding: where the light leaks out. Brightest under the core,
      // fading toward both ends, never one even line.
      final left = shade.radius * 1.3;
      final right = w - shade.radius * 1.3;
      final t = ((cx - left) / (right - left)).clamp(0.08, 0.92).toDouble();
      canvas.drawPath(
        shade.rim(top: false, inset: 0.9, pad: shade.radius * 1.3),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(
            Offset(left, 0),
            Offset(right, 0),
            [
              const Color(0xFF8A4F27).withValues(alpha: 0.35 * lit),
              const Color(0xFFE7A869).withValues(alpha: 0.7 * lit),
              const Color(0xFFFFF0D4).withValues(alpha: 0.95 * lit.clamp(0, 1)),
              const Color(0xFFE7A869).withValues(alpha: 0.7 * lit),
              const Color(0xFF8A4F27).withValues(alpha: 0.35 * lit),
            ],
            [
              0.0,
              (t - 0.26).clamp(0.02, 0.97).toDouble(),
              t,
              (t + 0.26).clamp(0.03, 0.98).toDouble(),
              1.0,
            ],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_LampRimPainter old) =>
      old.warmth != warmth || old.core != core || old.cut != cut;
}

/// The pool of light the lamp throws on the surface beneath it.
class _LampSpillPainter extends CustomPainter {
  const _LampSpillPainter({required this.warmth, required this.core});

  final double warmth;
  final Offset core;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strength = warmth <= 0.3
        ? warmth / 0.3 * 0.05
        : 0.05 + (warmth - 0.3) / 0.7 * 0.13;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(core.dx * w, h + 5),
        width: w * (0.66 + 0.08 * (warmth - 1).clamp(0, 1)),
        height: 18,
      ),
      Paint()
        ..color = const Color(
          0xFFE29A57,
        ).withValues(alpha: strength.clamp(0.0, 0.24).toDouble())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  @override
  bool shouldRepaint(_LampSpillPainter old) =>
      old.warmth != warmth || old.core != core;
}

Matrix4 _scaleAbout(Offset center, double sx, double sy) => Matrix4.identity()
  ..translateByDouble(center.dx, center.dy, 0, 1)
  ..scaleByDouble(sx, sy, 1, 1)
  ..translateByDouble(-center.dx, -center.dy, 0, 1);

/// The words on a lamp. Garamond capitals printed on the shade: dark ink on
/// the lit paper; on a lamp turned low the paper is dark and the letters are
/// where its remaining light comes through.
class LampLabel extends StatelessWidget {
  const LampLabel({
    super.key,
    required this.text,
    this.icon,
    this.level = LampLevel.lit,
    this.fontSize,
    this.maxLines = 2,
    this.ink,
  });

  final String text;
  final IconData? icon;
  final LampLevel level;
  final double? fontSize;
  final int maxLines;

  /// Set the same printed capitals in a plain colour with no halo or glow:
  /// the label of a quiet (unlit) control, so a secondary action shares the
  /// primary's type without sharing its light.
  final Color? ink;

  static TextStyle styleFor(
    String text, {
    LampLevel level = LampLevel.lit,
    double? fontSize,
  }) {
    final capitals = text == text.toUpperCase();
    final shown = LampShade.debugForceLevel ?? level;
    final ink = switch (shown) {
      LampLevel.lit => LampTone.ink,
      LampLevel.low => LampTone.lowInk,
      LampLevel.off => LampTone.offInk,
    };
    return TextStyle(
      fontFamily: 'EBGaramond',
      fontWeight: FontWeight.w600,
      fontSize: fontSize ?? (capitals ? 15.5 : 18.5),
      height: 1.08,
      letterSpacing: capitals ? 2.1 : 0.15,
      color: ink,
      decoration: TextDecoration.none,
      shadows: switch (shown) {
        // Light bleeding round the ink where the paper is thinnest.
        LampLevel.lit => const [
          Shadow(color: Color(0x59FFF6E4), blurRadius: 2.5),
        ],
        LampLevel.low => const [
          Shadow(color: Color(0x80D98C45), blurRadius: 7),
          Shadow(color: Color(0xA6140A04), offset: Offset(0, 1)),
        ],
        LampLevel.off => const [],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var style = styleFor(text, level: level, fontSize: fontSize);
    if (ink != null) style = style.copyWith(color: ink, shadows: const []);
    // Large text keeps its words whole: the printed capitals give up a little
    // of their tracking and size so a wide label still wraps at its spaces
    // inside the shade instead of breaking mid-word.
    if (MediaQuery.textScalerOf(context).scale(1) >= 1.5) {
      style = style.copyWith(
        fontSize: (style.fontSize ?? 15.5) * 0.86,
        letterSpacing: (style.letterSpacing ?? 0) * 0.35,
      );
    }
    final label = Text(
      text,
      maxLines: maxLines,
      textAlign: TextAlign.center,
      style: style,
    );
    Widget content = icon == null
        ? label
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: (style.fontSize ?? 15.5) + 3,
                color: style.color,
              ),
              SizedBox(width: (style.fontSize ?? 15.5) * 0.55),
              Flexible(child: label),
            ],
          );
    content = LampWords(child: content);
    return Center(child: content);
  }
}

/// Marks the words on a lamp: their laid-out width is reported to the
/// enclosing [LampShade] so its light sits behind them at any text size.
/// Outside a lamp it does nothing.
class LampWords extends SingleChildRenderObjectWidget {
  const LampWords({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLampWords(_LampScope.maybeOf(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderLampWords).words = _LampScope.maybeOf(context);
  }
}

class _RenderLampWords extends RenderProxyBox {
  _RenderLampWords(this.words);

  _LampWords? words;

  @override
  void performLayout() {
    super.performLayout();
    words?.report(size.width / 2);
  }
}
