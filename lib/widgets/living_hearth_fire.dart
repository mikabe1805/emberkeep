import 'dart:math' show cos, pi, sin;

import 'package:flutter/material.dart';

/// The three registered, painted hearth frames shared by Me and Quests.
///
/// Keeping one frame set means a wardrobe flame is the same physical fire in
/// every room. The hue is applied at paint time, so adding a new earned colour
/// never requires another trio of near-identical raster assets.
const hearthFireAssets = <String>[
  'assets/rooms/quest-fire-a-v3.png',
  'assets/rooms/quest-fire-b-v3.png',
  'assets/rooms/quest-fire-c-v3.png',
];

/// Recolors the painted flame while preserving its luminance and saturation.
///
/// A hue-rotation matrix is deliberate: unlike a blend-mode color filter, it
/// preserves transparent pixels as transparent. It also preserves luminance,
/// so the cream-hot core stays cream and the dark logs stay dark instead of
/// turning the frame crop into a flat neon rectangle.
ColorFilter hearthFireColorFilter(Color hue) {
  const sourceFireHue = 28.0;
  final radians = (HSVColor.fromColor(hue).hue - sourceFireHue) * pi / 180;
  final c = cos(radians);
  final s = sin(radians);

  // SVG/CSS hueRotate matrix, using the same luminance coefficients. White,
  // black, and alpha remain fixed while chromatic pixels rotate around them.
  return ColorFilter.matrix(<double>[
    0.213 + c * 0.787 - s * 0.213,
    0.715 - c * 0.715 - s * 0.715,
    0.072 - c * 0.072 + s * 0.928,
    0,
    0,
    0.213 - c * 0.213 + s * 0.143,
    0.715 + c * 0.285 + s * 0.140,
    0.072 - c * 0.072 - s * 0.283,
    0,
    0,
    0.213 - c * 0.213 - s * 0.787,
    0.715 - c * 0.715 + s * 0.715,
    0.072 + c * 0.928 + s * 0.072,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);
}

({int current, int next, double blend}) hearthFireFrameAt(double phase) {
  final framePhase = (phase % 1.0) * 18;
  final current = framePhase.floor() % hearthFireAssets.length;
  return (
    current: current,
    next: (current + 1) % hearthFireAssets.length,
    blend: Curves.easeInOutSine.transform(framePhase % 1),
  );
}

/// One recolored painted frame. Public so room surfaces can share the exact
/// same raster/color treatment without sharing their different positioning.
class RecoloredHearthFireFrame extends StatelessWidget {
  const RecoloredHearthFireFrame({
    super.key,
    required this.asset,
    required this.hue,
    required this.opacity,
  });

  final String asset;
  final Color hue;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: ColorFiltered(
        key: const ValueKey('recolored-hearth-fire'),
        colorFilter: hearthFireColorFilter(hue),
        child: Image(
          image: AssetImage(asset),
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          isAntiAlias: true,
        ),
      ),
    );
  }
}
