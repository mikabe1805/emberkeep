import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../tokens.dart';

/// A warm glass toggle — a honey-glowing thumb sliding in a glass track — so the
/// one switch in the app (Reminders) matches the candlelit language instead of
/// reading as a cold stock-Material note in a warm room (round-34).
class GlassSwitch extends StatelessWidget {
  const GlassSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Sfx.instance.play('tick');
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: Motion.quick,
        curve: Motion.respond,
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: value ? Palette.xp.withValues(alpha: 0.26) : Palette.glassFill,
          border: Border.all(
            color: value
                ? Palette.xp.withValues(alpha: 0.7)
                : Palette.glassEdge,
          ),
        ),
        child: AnimatedAlign(
          duration: Motion.quick,
          curve: Motion.respond,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: value ? Palette.honeyGradient : null,
              color: value ? null : Palette.textLo.withValues(alpha: 0.55),
              boxShadow: value
                  ? const [BoxShadow(color: Palette.honeyGlow, blurRadius: 10)]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
