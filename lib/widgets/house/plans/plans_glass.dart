// The daybook's two materials: ink on paper, and smoky glass on paper.
//
// Paper ink is warm charcoal, not black, and gold appears only as a ring, a
// selected edge or the mark of today. The glass is the light kind: the paper
// and the sun come through a little, the cream type on it stays crisp (the
// approved prototype's `.pc`). A soft backdrop blur and a darkening under the
// fill do that; there is no tint over the page.
library;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Ink on the paper.
abstract final class PlansInk {
  static const Color ink = Color(0xFF45392F);
  static const Color muted = Color(0xFF65574A);
  static const Color rule = Color(0x40503D2E);
  static const Color brass = Color(0xFFA66C2D);

  /// Cream type on the glass.
  static const Color cream = Color(0xFFFAF1E2);
  static const Color creamSoft = Color(0xFFEADCCB);
  static const Color creamDim = Color(0xFFC9B9A4);
  static const Color ring = Color(0xFFEFBF78);
  static const Color ringDone = Color(0xFFF4CF8A);

  static const String serif = 'EBGaramond';
  static const String mono = 'JetBrainsMono';
}

/// How large the system's text is, as a multiple of one.
double plansTextScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(11) / 11;

/// A slab of smoky glass on the page.
class PlansGlass extends StatelessWidget {
  const PlansGlass({
    super.key,
    required this.child,
    this.radius = 9,
    this.padding = EdgeInsets.zero,
    this.bright = false,
    this.soft = false,
    this.shadow = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// The first card of a day has a brighter edge.
  final bool bright;

  /// A quieter slab: less fill, for notes that are not plans.
  final bool soft;

  /// The contact shadow under the slab (off for the small tickets of the week).
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    // A soft contact shadow under the slab (a gradient, not a box shadow: a
    // box shadow under translucent glass darkens the card itself).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (shadow)
          Positioned(
            left: 5,
            right: 5,
            bottom: -9,
            height: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x38120A05), Color(0x00120A05)],
                ),
              ),
            ),
          ),
        ClipRRect(
          borderRadius: shape,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: shape,
                // The paper under the glass is darkened first (the
                // prototype's brightness(.72)), then the smoke over it.
                color: Color.fromRGBO(30, 21, 15, soft ? 0.22 : 0.34),
                border: Border.all(
                  color: bright
                      ? const Color(0x8CFBDBA9)
                      : const Color(0x57FFEED0),
                  width: 0.75,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: shape,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.fromRGBO(94, 76, 62, soft ? 0.24 : 0.34),
                      Color.fromRGBO(34, 25, 20, soft ? 0.30 : 0.44),
                    ],
                    stops: const [0, 0.78],
                  ),
                ),
                child: Stack(
                  children: [
                    // The lit top lip.
                    Positioned(
                      left: 6,
                      right: 6,
                      top: 0,
                      height: 0.75,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0x00FFFFFF),
                              Color(bright ? 0x4DFFFFFF : 0x2EFFFFFF),
                              const Color(0x00FFFFFF),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // The warm catch low on the right.
                    const Positioned(
                      right: 10,
                      bottom: 0,
                      width: 90,
                      height: 0.9,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0x00FFCE8B),
                              Color(0x8CFFCE8B),
                              Color(0x00FFCE8B),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(padding: padding, child: child),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
