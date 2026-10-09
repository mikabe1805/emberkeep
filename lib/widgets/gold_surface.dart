import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'facets.dart';
import 'lamplight.dart';

export 'lamplight.dart' show LampLevel;

/// The app's one primary-control material, kept under its old name so every
/// screen that asked for "the gold" now receives the lamp.
///
/// The honey plate (satin gold ramp, a broad reflection, a hot lip) was
/// retired on 2026-10-04: "the old gold buttons don’t look so good in the
/// new UI". The control is now a [LampShade]: parchment lit from within, in
/// the room lamp's own hue. Nothing animates on its own; the core moves only
/// with tilt and scroll.
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
    this.pressed = false,
    this.level = LampLevel.lit,
  });

  final Widget child;
  final double cut;

  /// The shared tilt/pointer light field. Null parks the core at rest.
  final ValueListenable<Offset>? light;

  /// Scroll offset of the surface's page; rolls the same core.
  final ValueListenable<double>? scroll;
  final bool reduceMotion;

  /// The pool of light under the shade. Off for secondary/inline lamps.
  final bool glow;

  /// Kept for callers; the paper is always present where it can resolve.
  final bool textured;
  final bool pressed;
  final LampLevel level;

  @override
  Widget build(BuildContext context) {
    return LampShade(
      cut: cut,
      light: light,
      scroll: scroll,
      reduceMotion: reduceMotion,
      spill: glow,
      pressed: pressed,
      level: level,
      child: child,
    );
  }
}

/// The label that belongs on [GoldSurface]: the lamp's printed capitals.
class GoldLabel extends StatelessWidget {
  const GoldLabel({
    super.key,
    required this.text,
    this.icon,
    this.fontSize,
    this.letterSpacing,
    this.level = LampLevel.lit,
  });

  final String text;
  final IconData? icon;

  /// Old mono sizes (12-12.5) map onto the Garamond capitals' 15.5.
  final double? fontSize;
  final double? letterSpacing;
  final LampLevel level;

  @override
  Widget build(BuildContext context) {
    return LampLabel(
      text: text,
      icon: icon,
      level: level,
      fontSize: fontSize == null ? null : fontSize! + 3,
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
