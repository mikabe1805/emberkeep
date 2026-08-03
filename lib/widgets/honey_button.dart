import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'facets.dart';
import 'gold_surface.dart';
import 'pressable.dart';

/// The one honey CTA — a plate of satin gold routed through [Pressable] so the
/// primary action depresses (faux-3D) with a haptic tick, exactly like a quest
/// card (round-30: the most important button should feel the MOST physical, not
/// flatter than a list row).
///
/// The face itself is [GoldSurface], which is also what the Quest control and
/// the page rails on Goals/Journal use — one material, one reflection, one ink.
class HoneyButton extends StatelessWidget {
  const HoneyButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.enabled = true,
    this.glow = true,
    this.expand = false,
    this.fontSize = 12,
    this.light,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  /// Dim + unpressable when false (a "not ready yet" CTA).
  final bool enabled;
  final bool glow;

  /// Stretch to fill the available width (a pinned footer button).
  final bool expand;
  final double fontSize;

  /// The page's shared tilt/pointer light, when one is available. Without it
  /// the reflection simply parks — the still frame is the designed one.
  final ValueListenable<Offset>? light;

  @override
  Widget build(BuildContext context) {
    const cut = 11.0;
    const shape = FacetedBorder(cut: cut);
    final button = GoldSurface(
      cut: cut,
      glow: glow,
      light: light,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: fontSize + 5, color: Palette.onHoney),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: Type.label.copyWith(
                  fontSize: fontSize,
                  letterSpacing: 1.3,
                  color: Palette.onHoney,
                  shadows: const [
                    Shadow(color: Color(0x59FFEBBE), offset: Offset(0, 1)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Pressable(
        enabled: enabled,
        semanticLabel: label,
        onTapUp: enabled ? (_) => onTap() : null,
        shape: shape,
        // a warm dark-amber under-edge, never grey
        edgeColor: Palette.brassDeep,
        child: button,
      ),
    );
  }
}
