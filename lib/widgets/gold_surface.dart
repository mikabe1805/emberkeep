import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'facets.dart';

/// The app's single piece of gold.
///
/// Before this existed the product shipped six primary-button materials — a
/// near-white plaque, a bevelled-plastic price chip, a burnt-orange Quest
/// control, a lava-textured page rail, a flat mustard slab and an extruded
/// 12 px block. They were the loudest evidence that the screens came from
/// different generations.
///
/// One recipe now: the [Palette.honeyGradient] satin ramp, the authored honey
/// plate as grain, ONE broad reflection whose position comes from tilt/scroll
/// (never from a clock), a hot top lip, and a deep under-lip. Nothing here
/// animates on its own — park the light input and the still frame is finished.
class GoldSurface extends StatelessWidget {
  const GoldSurface({
    super.key,
    required this.child,
    this.cut = 11,
    this.light,
    this.scroll,
    this.reduceMotion = false,
    this.glow = true,
    this.textured = true,
  });

  final Widget child;
  final double cut;

  /// The shared tilt/pointer light field. Null parks the reflection at rest.
  final ValueListenable<Offset>? light;

  /// Scroll offset of the surface's page; advances the same reflection.
  final ValueListenable<double>? scroll;
  final bool reduceMotion;

  /// A warm halo under the plate. Off for secondary/inline golds.
  final bool glow;

  /// The authored honey-gold plate as grain. Off for very small chips, where
  /// the texture would only turn to noise.
  final bool textured;

  @override
  Widget build(BuildContext context) {
    final still =
        reduceMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return AnimatedBuilder(
      animation: Listenable.merge([?light, ?scroll]),
      child: child,
      builder: (context, body) {
        final tilt = still ? Offset.zero : light?.value ?? Offset.zero;
        final offset = still ? 0.0 : scroll?.value ?? 0.0;
        // One broad reflection. Rest is a little left of centre, which is where
        // the approved target parks it; tilt and scroll slide it across.
        final sweep =
            (0.32 + tilt.dx * 0.10 - tilt.dy * 0.035 + offset * 0.00032) % 1.0;
        return DecoratedBox(
          decoration: facetedDecoration(
            cut: cut,
            gradient: Palette.honeyGradient,
            borderColor: Palette.brass,
            borderWidth: 1.1,
            shadows: [
              const BoxShadow(
                color: Palette.brassDeep,
                blurRadius: 0,
                offset: Offset(0, 2),
              ),
              if (glow)
                const BoxShadow(
                  color: Color(0x2EC98F44),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
            ],
          ),
          child: ClipPath(
            clipper: FacetedClipper(cut: cut),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                if (textured)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.18,
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Color(0xFFD8AE73),
                            BlendMode.modulate,
                          ),
                          child: Image.asset(
                            'assets/quest/luminous-honey-gold-v2.webp',
                            fit: BoxFit.cover,
                            alignment: Alignment(
                              tilt.dx * 0.055,
                              tilt.dy * 0.028,
                            ),
                            filterQuality: FilterQuality.medium,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _GoldFacePainter(sweep: sweep, tilt: tilt),
                    ),
                  ),
                ),
                body!,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GoldFacePainter extends CustomPainter {
  const _GoldFacePainter({required this.sweep, required this.tilt});

  final double sweep;
  final Offset tilt;

  @override
  void paint(Canvas canvas, Size size) {
    // One broad, soft reflection — the width of a real highlight rolling over
    // a satin surface, not a travelling glint.
    canvas.save();
    canvas.translate(-size.width * 0.24 + sweep * size.width * 1.48, 0);
    canvas.rotate(-0.20 + tilt.dy * 0.02);
    final band = Rect.fromLTWH(
      -size.width * 0.13,
      -size.height,
      size.width * 0.26,
      size.height * 3,
    );
    canvas.drawRect(
      band,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = const LinearGradient(
          colors: [
            Color(0x00FFF3D6),
            Color(0x0CFFF3D6),
            Color(0x3AFFF7E2),
            Color(0x0CFFF3D6),
            Color(0x00FFF3D6),
          ],
          stops: [0, 0.30, 0.5, 0.70, 1],
        ).createShader(band),
    );
    canvas.restore();

    // The lit top lip and the plate's own shaded lower plane. Together these
    // are what makes it read as a raised piece of metal rather than a fill.
    final lip = Rect.fromLTWH(size.width * 0.05, 0.8, size.width * 0.90, 1.4);
    canvas.drawRect(
      lip,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0x00FFF0C4),
            Color(0xA8FFF0C4),
            Color(0x66FFF0C4),
            Color(0x00FFF0C4),
          ],
          stops: [0, 0.3, 0.72, 1],
        ).createShader(lip),
    );
    final under = Rect.fromLTWH(
      0,
      size.height - size.height * 0.26,
      size.width,
      size.height * 0.26,
    );
    canvas.drawRect(
      under,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00512F12), Color(0x36512F12)],
        ).createShader(under),
    );

    // A hairline of warm shadow inside the rim keeps the border from reading
    // as painted-on line art.
    canvas.drawPath(
      facetedRectPath(
        Rect.fromLTWH(0, 0, size.width, size.height).deflate(1.6),
        cut: 8,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0x3A6B441C),
    );
  }

  @override
  bool shouldRepaint(_GoldFacePainter old) =>
      old.sweep != sweep || old.tilt != tilt;
}

/// The engraved label that belongs on [GoldSurface]. Dark espresso ink with a
/// one-pixel warm relief under it, exactly as the approved target renders
/// `MARK COMPLETE` — never pale amber text on an amber plate.
class GoldLabel extends StatelessWidget {
  const GoldLabel({
    super.key,
    required this.text,
    this.icon,
    this.fontSize = 12.5,
    this.letterSpacing = 1.65,
  });

  final String text;
  final IconData? icon;
  final double fontSize;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      maxLines: 2,
      textAlign: TextAlign.center,
      style: Type.label.copyWith(
        fontSize: fontSize,
        letterSpacing: letterSpacing,
        color: Palette.onHoney,
        shadows: const [Shadow(color: Color(0x59FFEBBE), offset: Offset(0, 1))],
      ),
    );
    if (icon == null) return Center(child: label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: fontSize + 5.5, color: Palette.onHoney),
        SizedBox(width: fontSize * 0.7),
        Flexible(child: label),
      ],
    );
  }
}

/// Aged brass for everything that is gold but is *not* the one primary action:
/// section rules, medallion rims, day marks, seals. Quiet, never luminous —
/// this is what stops a screen from growing a second bright control.
ShapeDecoration agedBrassPlate({double cut = 9, double strength = 1}) =>
    facetedDecoration(
      cut: cut,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFFD79A).withValues(alpha: 0.14 * strength),
          const Color(0xFF8A5A28).withValues(alpha: 0.05 * strength),
        ],
      ),
      borderColor: Palette.brass.withValues(alpha: 0.78 * strength),
      borderWidth: 1,
    );
