import 'dart:async';

import 'package:flutter/material.dart';

import '../audio.dart';
import '../haptics.dart';
import '../tokens.dart';
import 'facets.dart';
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
    this.reduceMotion = false,
  });

  final int level;
  final String? unlock;
  final String? nextUnlock;
  final VoidCallback onDismiss;
  final bool reduceMotion;

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
    parent: _c,
    curve: const Interval(0, 0.15, curve: Curves.easeOut),
  );
  late final Animation<double> _slam = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.1, 0.55, curve: Motion.slam),
  );
  late final Animation<double> _unlockIn = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.55, 0.8, curve: Curves.easeOutCubic),
  );

  bool _burst = false;
  bool _started = false;
  bool _still = false;
  Timer? _burstTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still =
        widget.reduceMotion || MediaQuery.disableAnimationsOf(context);
    if (_still != still) {
      _still = still;
      if (still) {
        _burstTimer?.cancel();
        _burstTimer = null;
        if (_burst) setState(() => _burst = false);
      }
    }
    if (_started) return;
    _started = true;
    Sfx.instance.play('levelup');
    // the level-up slam — heavy settling into a medium, and softened to a
    // single medium under reduce-motion (Haptics.big honors the setting)
    if (still) {
      Haptics.light();
    } else {
      Haptics.big();
    }
    _c.forward();
    // particle storm fires as the numeral lands
    if (!still) {
      _burstTimer = Timer(const Duration(milliseconds: 380), () {
        if (mounted && !_still) setState(() => _burst = true);
      });
    }
  }

  @override
  void dispose() {
    _burstTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final center = Offset(size.width / 2, size.height * 0.40);
    final still =
        widget.reduceMotion || MediaQuery.disableAnimationsOf(context);
    // bigger milestone, bigger storm: every 5th level celebrates harder
    final milestone = widget.level % 5 == 0;

    return OverlaySurface(
      child: Semantics(
        button: true,
        label:
            'Level ${widget.level} reached'
            '${widget.unlock == null ? '' : '. ${widget.unlock} unlocked'}',
        hint: 'Tap to continue',
        onTap: widget.onDismiss,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onDismiss,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final dim = still ? 1.0 : _dim.value;
              final slam = still ? 1.0 : _slam.value;
              final unlockIn = still ? 1.0 : _unlockIn.value;
              return Container(
                // deep walnut night — warm dark, never grey-black
                color: const Color(0xFF2E1C0D).withValues(alpha: 0.92 * dim),
                child: Stack(
                  children: [
                    if (_burst && !still)
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
                        reduce: false,
                      ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: dim,
                            child: Text(
                              'LEVEL UP',
                              style: Type.label.copyWith(
                                fontSize: 16,
                                color: Palette.xpLight,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Transform.scale(
                            // elasticOut overshoots past 1.0 → the numeral slams in
                            scale: still ? 1 : 0.4 + 0.6 * slam,
                            child: Opacity(
                              opacity: slam.clamp(0.0, 1.0),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Transform.rotate(
                                    angle: 0.785,
                                    child: Container(
                                      width: 104,
                                      height: 104,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Palette.xpLight.withValues(
                                              alpha: 0.13,
                                            ),
                                            Palette.unlock.withValues(
                                              alpha: 0.025,
                                            ),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: Palette.xpLight.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Palette.honeyGlow.withValues(
                                              alpha: 0.35,
                                            ),
                                            blurRadius: 30,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${widget.level}',
                                    style: Type.numerals.copyWith(
                                      fontSize: 120,
                                      color: Palette.xpLight,
                                      shadows: [
                                        Shadow(
                                          color: Palette.xpLight.withValues(
                                            alpha: 0.7,
                                          ),
                                          blurRadius: still ? 24 : 44 * slam,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (widget.unlock != null)
                            Opacity(
                              opacity: unlockIn,
                              child: Transform.translate(
                                offset: Offset(
                                  0,
                                  still ? 0 : 20 * (1 - unlockIn),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 10,
                                  ),
                                  decoration: facetedDecoration(
                                    cut: 9,
                                    color: Palette.unlock.withValues(
                                      alpha: 0.05,
                                    ),
                                    borderColor: Palette.unlock,
                                    shadows: [
                                      BoxShadow(
                                        color: Palette.unlock.withValues(
                                          alpha: 0.3 * unlockIn,
                                        ),
                                        blurRadius: 18,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.lock_open,
                                        size: 18,
                                        color: Palette.unlock,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${widget.unlock} UNLOCKED',
                                        style: Type.label.copyWith(
                                          fontSize: 14,
                                          color: Palette.unlock,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (widget.nextUnlock != null) ...[
                            const SizedBox(height: 18),
                            Opacity(
                              opacity: unlockIn * 0.8,
                              child: Text(
                                'NEXT · ${widget.nextUnlock}',
                                style: Type.label.copyWith(fontSize: 11),
                              ),
                            ),
                          ],
                          const SizedBox(height: 40),
                          Opacity(
                            opacity: unlockIn * 0.6,
                            child: Text(
                              'onward →',
                              style: Type.label.copyWith(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
