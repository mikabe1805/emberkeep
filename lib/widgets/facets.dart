import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../tokens.dart';

/// Morrowloom's shared architectural silhouette: a pane with deliberate cut
/// corners, like the fireplace stone, window light, rugs, and framed art in the
/// keep. The asymmetry keeps it illustrated rather than feeling like a generic
/// octagonal UI kit.
Path facetedRectPath(Rect rect, {double cut = 12}) {
  final c = cut.clamp(0.0, rect.shortestSide / 3);
  return Path()
    ..moveTo(rect.left + c, rect.top)
    ..lineTo(rect.right - c * 0.62, rect.top)
    ..lineTo(rect.right, rect.top + c * 0.72)
    ..lineTo(rect.right, rect.bottom - c)
    ..lineTo(rect.right - c, rect.bottom)
    ..lineTo(rect.left + c * 0.55, rect.bottom)
    ..lineTo(rect.left, rect.bottom - c * 0.68)
    ..lineTo(rect.left, rect.top + c)
    ..close();
}

class FacetedBorder extends OutlinedBorder {
  const FacetedBorder({this.cut = 12, super.side = BorderSide.none});

  final double cut;

  @override
  OutlinedBorder copyWith({BorderSide? side}) =>
      FacetedBorder(cut: cut, side: side ?? this.side);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      facetedRectPath(rect, cut: cut);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    final inset = side.width;
    return facetedRectPath(
      rect.deflate(inset),
      cut: (cut - inset).clamp(0.0, cut),
    );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(
      facetedRectPath(rect.deflate(side.width / 2), cut: cut),
      side.toPaint(),
    );
  }

  @override
  ShapeBorder scale(double t) =>
      FacetedBorder(cut: cut * t, side: side.scale(t));

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is FacetedBorder) {
      return FacetedBorder(
        cut: lerpDouble(a.cut, cut, t)!,
        side: BorderSide.lerp(a.side, side, t),
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is FacetedBorder) {
      return FacetedBorder(
        cut: lerpDouble(cut, b.cut, t)!,
        side: BorderSide.lerp(side, b.side, t),
      );
    }
    return super.lerpTo(b, t);
  }
}

class FacetedClipper extends CustomClipper<Path> {
  const FacetedClipper({this.cut = 12});
  final double cut;

  @override
  Path getClip(Size size) => facetedRectPath(Offset.zero & size, cut: cut);

  @override
  bool shouldReclip(FacetedClipper oldClipper) => oldClipper.cut != cut;
}

ShapeDecoration facetedDecoration({
  Color? color,
  Gradient? gradient,
  double cut = 12,
  Color borderColor = Palette.glassEdge,
  double borderWidth = 1.2,
  List<BoxShadow> shadows = const [],
}) {
  return ShapeDecoration(
    color: color,
    gradient: gradient,
    shadows: shadows,
    shape: FacetedBorder(
      cut: cut,
      side: BorderSide(color: borderColor, width: borderWidth),
    ),
  );
}

/// A compact architectural emblem for domains, goals, and unlocks. Circular
/// icon bubbles read as generic mobile chrome; this mirrors the keep's cut
/// stone and framed-window geometry while retaining a generous hit silhouette.
class FacetMedallion extends StatelessWidget {
  const FacetMedallion({
    super.key,
    required this.accent,
    required this.child,
    this.size = 40,
    this.gradient,
    this.glow = false,
  });

  final Color accent;
  final Widget child;
  final double size;
  final Gradient? gradient;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final cut = size * 0.22;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: facetedDecoration(
              color: gradient == null ? accent.withValues(alpha: 0.16) : null,
              gradient: gradient,
              cut: cut,
              borderColor: accent.withValues(alpha: 0.55),
              shadows: glow
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.34),
                        blurRadius: size * 0.36,
                        offset: Offset(0, size * 0.1),
                      ),
                    ]
                  : const [],
            ),
            child: Center(child: child),
          ),
          FacetGleam(cut: cut, light: accent, strength: 0.75),
        ],
      ),
    );
  }
}

/// A crisp progress rail with angled ends, used wherever the keep records
/// growth. It makes data visualization feel engraved into the architecture.
///
/// A rail is a *groove*: a dark warm channel with a quiet brass rim and a lit
/// fill. The old recipe called `Palette.glassEdge.withValues(alpha: 0.55)`,
/// which replaced the token's own 0x2E alpha with 0.55 and drew a near-cream
/// hairline all the way round — at 6 px tall that rim was most of the rail, so
/// every empty track in the app read light and generic. Rim alpha is explicit
/// here for that reason.
class FacetedMeter extends StatelessWidget {
  const FacetedMeter({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
    this.glow = false,
    this.background = Palette.railTrack,
  });

  final double value;
  final Color color;
  final double height;
  final bool glow;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final cut = height * 0.42;
    return SizedBox(
      height: height,
      child: ClipPath(
        clipper: FacetedClipper(cut: cut),
        child: DecoratedBox(
          decoration: facetedDecoration(
            color: background,
            cut: cut,
            borderColor: Palette.railRim,
            borderWidth: 0.7,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // Lit along the top lip, settling into its own colour below —
                  // the same read as every other raised surface in the app.
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(color, const Color(0xFFFFF3D8), 0.34)!,
                      color,
                      Color.lerp(color, const Color(0xFF2A1A10), 0.30)!,
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                  boxShadow: glow
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ]
                      : const [],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One "this is chosen" mark for the whole app. Before this the product had a
/// Material square checkbox on the Shape-tomorrow sheet, a circular checkbox in
/// kit quests, a ring on the board and a diamond slab on capacity — four
/// shapes for one idea. This is the chamfered plate everything else already is.
class FacetCheck extends StatelessWidget {
  const FacetCheck({
    super.key,
    required this.selected,
    required this.accent,
    this.size = 22,
  });

  final bool selected;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: facetedDecoration(
        cut: size * 0.26,
        color: selected
            ? accent.withValues(alpha: 0.22)
            : const Color(0x3D0F0A07),
        borderColor: selected
            ? accent.withValues(alpha: 0.92)
            : Palette.brass.withValues(alpha: 0.55),
        borderWidth: selected ? 1.3 : 1,
      ),
      child: selected
          ? Center(
              child: Icon(
                Icons.check_rounded,
                size: size * 0.66,
                color: accent,
              ),
            )
          : null,
    ),
  );
}

/// A clipped highlight layer shared by panels and buttons. It draws the same
/// top-left light source as the keep: a crisp lit lip, a darker lower plane,
/// and one restrained triangular shard instead of a soft all-over gloss.
class FacetGleam extends StatelessWidget {
  const FacetGleam({
    super.key,
    this.cut = 12,
    this.light = Palette.specular,
    this.strength = 1,
  });

  final double cut;
  final Color light;
  final double strength;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ClipPath(
      clipper: FacetedClipper(cut: cut),
      child: CustomPaint(
        size: Size.infinite,
        painter: _FacetGleamPainter(light, strength),
      ),
    ),
  );
}

class _FacetGleamPainter extends CustomPainter {
  const _FacetGleamPainter(this.light, this.strength);
  final Color light;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final s = strength.clamp(0.0, 1.5);
    final top = Paint()
      ..color = light.withValues(alpha: 0.16 * s)
      ..strokeWidth = 1.1;
    canvas.drawLine(
      Offset(size.width * 0.055, 1),
      Offset(size.width * 0.68, 1),
      top,
    );

    // The catch-light where the pane meets the corner. It used to be a flat
    // triangle scaled to the panel, so on anything large — the Plans calendar,
    // the identity plate, the Shape-tomorrow sheet — it became a hard-edged
    // shaft that terminated in mid-air with no light source. It is now capped
    // at a real-world size and faded out along its length, so it reads as a
    // corner catching candlelight on every panel size.
    final w = size.width * 0.34 < 92 ? size.width * 0.34 : 92.0;
    final h = size.height * 0.42 < 108 ? size.height * 0.42 : 108.0;
    final shard = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w * 0.34, h)
      ..close();
    canvas.drawPath(
      shard,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            light.withValues(alpha: 0.055 * s),
            light.withValues(alpha: 0.016 * s),
            light.withValues(alpha: 0),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    final lowerH = size.height * 0.28 < 90 ? size.height * 0.28 : 90.0;
    final lower = Rect.fromLTWH(0, size.height - lowerH, size.width, lowerH);
    canvas.drawRect(
      lower,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Palette.warmShadow.withValues(alpha: 0),
            Palette.warmShadow.withValues(alpha: 0.20 * s),
          ],
        ).createShader(lower),
    );
  }

  @override
  bool shouldRepaint(_FacetGleamPainter old) =>
      old.light != light || old.strength != strength;
}
