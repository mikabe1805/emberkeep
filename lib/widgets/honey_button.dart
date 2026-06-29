import 'package:flutter/material.dart';

import '../tokens.dart';
import 'pressable.dart';

/// The one honey CTA — a lozenge of warm glass routed through [Pressable] so
/// the primary action depresses (faux-3D) with a haptic tick, exactly like a
/// quest card (round-30: the most important button should feel the MOST
/// physical, not flatter than a list row). One gradient/ink token everywhere.
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

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: Palette.honeyGradient,
        boxShadow: glow
            ? const [
                BoxShadow(
                  color: Palette.honeyGlow,
                  blurRadius: 18,
                  offset: Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: Palette.onHoney),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Type.label.copyWith(
                fontSize: fontSize,
                color: Palette.onHoney,
              ),
            ),
          ),
        ],
      ),
    );
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Pressable(
        enabled: enabled,
        onTapUp: enabled ? (_) => onTap() : null,
        borderRadius: BorderRadius.circular(999),
        // a warm dark-amber under-edge, never grey
        edgeColor: const Color(0xFF7A4E22),
        child: pill,
      ),
    );
  }
}
