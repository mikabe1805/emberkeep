import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../audio.dart';
import 'facets.dart';
import 'lamplight.dart';
import 'pressable.dart';

/// The one primary CTA: a lamp (see [LampShade]) routed through [Pressable],
/// so contact turns its light up under the finger and drops the shade onto
/// its binding at once, with the shared haptic and sound lanes.
///
/// Disabled is an unlit shade, never a faded copy of the lit one: the
/// action exists and reads, it simply is not ready.
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
    this.soundEnabled = true,
    this.quiet = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  /// An unlit, unpressable shade when false (a "not ready yet" CTA).
  final bool enabled;
  final bool glow;

  /// Stretch to fill the available width (a pinned footer button).
  final bool expand;

  /// The old mono size; the lamp's Garamond capitals are sized from it.
  final double fontSize;

  /// The page's shared tilt/pointer light, when one is available. Without it
  /// the core simply parks: the still frame is the designed one.
  final ValueListenable<Offset>? light;

  /// Some composite controls already own a more specific semantic sound in
  /// their callback. They can keep the physical [Pressable] response without
  /// voicing a second, generic cue.
  final bool soundEnabled;

  /// A secondary action: the same printed capitals on a plain glass pane,
  /// with no light of its own. A view keeps one lamp (the primary); every
  /// other tappable that used to wear the gold becomes quiet.
  final bool quiet;

  Widget _quietButton(BuildContext context) {
    const cut = 9.0;
    final ink = enabled ? const Color(0xFFEAD7BA) : LampTone.offInk;
    Widget face(bool pressed) => Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.textScalerOf(context).scale(1) >= 1.5 ? 12 : 20,
        vertical: 12,
      ),
      alignment: Alignment.center,
      decoration: facetedDecoration(
        cut: cut,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: pressed
              ? const [Color(0xF2433326), Color(0xF62A1F17)]
              : const [Color(0xF02A211B), Color(0xF61A130F)],
        ),
        borderColor: pressed
            ? const Color(0x70E9B27A)
            : enabled
            ? const Color(0x3DF3DEC0)
            : const Color(0x1FF3DEC0),
        borderWidth: 1,
      ),
      child: LampLabel(
        text: label,
        icon: icon,
        fontSize: fontSize + 3.5,
        ink: ink,
      ),
    );
    return Pressable(
      enabled: enabled,
      material: MaterialSound.glass,
      soundEnabled: soundEnabled,
      semanticLabel: label,
      onTapUp: enabled ? (_) => onTap() : null,
      shape: const FacetedBorder(cut: cut),
      pressDepth: 1,
      edgeColor: Colors.transparent,
      stateBuilder: (context, child, pressed, focused, hovered) =>
          face(pressed),
      child: face(false),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (quiet) return _quietButton(context);
    const cut = 11.0;
    const shape = LampShadeBorder(cut: cut);
    final level = enabled ? LampLevel.lit : LampLevel.off;
    Widget face(bool pressed) => LampShade(
      cut: cut,
      spill: glow,
      light: light,
      pressed: pressed,
      level: level,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.textScalerOf(context).scale(1) >= 1.5
              ? 12
              : 22,
          vertical: 12,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: LampLabel(
                text: label,
                icon: icon,
                level: level,
                fontSize: fontSize + 3.5,
              ),
            ),
          ],
        ),
      ),
    );
    return Pressable(
      enabled: enabled,
      material: MaterialSound.brass,
      soundEnabled: soundEnabled,
      semanticLabel: label,
      onTapUp: enabled ? (_) => onTap() : null,
      shape: shape,
      pressDepth: 2,
      // The shade's dark binding, seen as its thickness.
      edgeColor: const Color(0xFF1E1109),
      stateBuilder: (context, child, pressed, focused, hovered) =>
          face(pressed),
      child: face(false),
    );
  }
}
