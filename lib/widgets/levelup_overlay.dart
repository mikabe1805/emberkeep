import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../tokens.dart';
import 'glass.dart';
import 'particles.dart';

/// Full-screen level-up takeover (Habitica's level-up is just a modal — this
/// is the gap we out-execute, DESIGN.md §6): dim, numeral slam, particle
/// storm scaled by significance, unlock reveal, tap to dismiss. Always
/// skippable with a tap.
class LevelUpOverlay extends StatefulWidget {
  const LevelUpOverlay({
    super.key,
    required this.level,
    this.unlock,
    this.nextUnlock,
    required this.onDismiss,
  });

  final int level;
  final String? unlock;
  final String? nextUnlock;
  final VoidCallback onDismiss;

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<LevelUpOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  late final Animation<double> _dim = CurvedAnimation(
      parent: _c, curve: const Interval(0, 0.15, curve: Curves.easeOut));
  late final Animation<double> _slam = CurvedAnimation(
      parent: _c, curve: const Interval(0.1, 0.55, curve: Motion.slam));
  late final Animation<double> _unlockIn = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.55, 0.8, curve: Curves.easeOutCubic));

  bool _burst = false;

  @override
  void initState() {
    super.initState();
    Sfx.instance.play('levelup');
    // composed multi-tap celebration, reserved for level-ups (§8), synced
    // to the numeral slam
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 90), () {
      if (mounted) HapticFeedback.heavyImpact();
    });
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) HapticFeedback.mediumImpact();
    });
    _c.forward();
    // particle storm fires as the numeral lands
    Future.delayed(const Duration(milliseconds: 380), () {
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
    final center = Offset(size.width / 2, size.height * 0.40);
    // bigger milestone, bigger storm: every 5th level celebrates harder
    final milestone = widget.level % 5 == 0;

    return OverlaySurface(
      child: GestureDetector(
      onTap: widget.onDismiss,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          // deep walnut night — warm dark, never grey-black
          color: const Color(0xFF2E1C0D).withValues(alpha: 0.92 * _dim.value),
          child: Stack(
            children: [
              if (_burst)
                ParticleBurst(
                  origin: center,
                  colors: const [
                    Palette.xpLight,
                    Color(0xFFFFF4D9), // cream sparkle
                    Palette.unlock,
                  ],
                  count: milestone ? 90 : 46,
                  vibrancy: milestone ? 1.0 : 0.7,
                  spread: 160,
                ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: _dim.value,
                      child: Text('LEVEL UP',
                          style: Type.label.copyWith(
                              fontSize: 16, color: Palette.xpLight)),
                    ),
                    const SizedBox(height: 8),
                    Transform.scale(
                      // elasticOut overshoots past 1.0 → the numeral slams in
                      scale: 0.4 + 0.6 * _slam.value,
                      child: Opacity(
                        opacity: _slam.value.clamp(0.0, 1.0),
                        child: Text(
                          '${widget.level}',
                          style: Type.numerals.copyWith(
                            fontSize: 120,
                            color: Palette.xpLight,
                            shadows: [
                              Shadow(
                                color: Palette.xpLight.withValues(alpha: 0.7),
                                blurRadius: 44 * _slam.value,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (widget.unlock != null)
                      Opacity(
                        opacity: _unlockIn.value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - _unlockIn.value)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Palette.unlock),
                              boxShadow: [
                                BoxShadow(
                                  color: Palette.unlock.withValues(
                                      alpha: 0.3 * _unlockIn.value),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock_open,
                                    size: 18, color: Palette.unlock),
                                const SizedBox(width: 8),
                                Text('${widget.unlock} UNLOCKED',
                                    style: Type.label.copyWith(
                                        fontSize: 14,
                                        color: Palette.unlock)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (widget.nextUnlock != null) ...[
                      const SizedBox(height: 18),
                      Opacity(
                        opacity: _unlockIn.value * 0.8,
                        child: Text('NEXT · ${widget.nextUnlock}',
                            style: Type.label.copyWith(fontSize: 11)),
                      ),
                    ],
                    const SizedBox(height: 40),
                    Opacity(
                      opacity: _unlockIn.value * 0.6,
                      child: Text('onward →',
                          style: Type.label.copyWith(fontSize: 11)),
                    ),
                  ],
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
