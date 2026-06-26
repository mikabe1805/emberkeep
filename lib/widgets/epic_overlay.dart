import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../tokens.dart';
import 'glass.dart';
import 'particles.dart';

/// Full-screen celebration for EPIC (d≥7) completions — "you tackled the
/// hard thing" deserves an event (DESIGN.md §11.3). Sunlit cream wash, the
/// inverse of the level-up's walnut night. Always skippable with a tap.
class EpicOverlay extends StatefulWidget {
  const EpicOverlay({
    super.key,
    required this.questTitle,
    required this.message,
    required this.onDismiss,
    this.kicker = 'EPIC QUEST CLEARED',
    this.headline = 'YOU DID IT.',
  });

  final String questTitle;
  final String message;
  final VoidCallback onDismiss;

  /// Re-used for goal completions ("GOAL ACHIEVED" / "YOU MADE IT.").
  final String kicker;
  final String headline;

  @override
  State<EpicOverlay> createState() => _EpicOverlayState();
}

class _EpicOverlayState extends State<EpicOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  late final Animation<double> _wash = CurvedAnimation(
      parent: _c, curve: const Interval(0, 0.18, curve: Curves.easeOut));
  late final Animation<double> _slam = CurvedAnimation(
      parent: _c, curve: const Interval(0.08, 0.5, curve: Motion.slam));
  late final Animation<double> _detail = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.45, 0.75, curve: Curves.easeOutCubic));

  bool _burst = false;

  @override
  void initState() {
    super.initState();
    Sfx.instance.play('levelup');
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 110), () {
      if (mounted) HapticFeedback.heavyImpact();
    });
    _c.forward();
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) setState(() => _burst = true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final center = Offset(size.width / 2, size.height * 0.38);

    // overlay entries need a Material ancestor (yellow-underline fix)
    return OverlaySurface(
      child: GestureDetector(
      onTap: widget.onDismiss,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          // amber dusk — glowing warm, distinct from level-up's deep walnut
          color: const Color(0xFF2B1D0E).withValues(alpha: 0.94 * _wash.value),
          child: Stack(
            children: [
              if (_burst)
                ParticleBurst(
                  origin: center,
                  colors: const [
                    Palette.xp,
                    Palette.streak,
                    Color(0xFFD88A8A), // bloom
                    Color(0xFFC9A56A), // sandy gold
                  ],
                  count: 110,
                  vibrancy: 1.0,
                  spread: 180,
                ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: _wash.value,
                        child: Text(widget.kicker,
                            style: Type.label.copyWith(
                                fontSize: 12, color: Palette.streak)),
                      ),
                      const SizedBox(height: 12),
                      Transform.scale(
                        scale: 0.5 + 0.5 * _slam.value,
                        child: Opacity(
                          opacity: _slam.value.clamp(0.0, 1.0),
                          child: Text(
                            widget.headline,
                            textAlign: TextAlign.center,
                            style: Type.display.copyWith(
                              fontSize: 52,
                              fontWeight: FontWeight.w700,
                              color: Palette.textHi,
                              shadows: [
                                Shadow(
                                  color: Palette.xpLight
                                      .withValues(alpha: 0.8),
                                  blurRadius: 30 * _slam.value,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Opacity(
                        opacity: _detail.value,
                        child: Transform.translate(
                          offset: Offset(0, 16 * (1 - _detail.value)),
                          child: Column(
                            children: [
                              Text(widget.questTitle,
                                  textAlign: TextAlign.center,
                                  style: Type.body.copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Palette.textMid)),
                              const SizedBox(height: 10),
                              Text(widget.message,
                                  textAlign: TextAlign.center,
                                  style: Type.body.copyWith(
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                      color: Palette.textLo)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 44),
                      Opacity(
                        opacity: _detail.value * 0.6,
                        child: Text('tap to keep going →',
                            style: Type.label.copyWith(fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
