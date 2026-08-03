import 'dart:async';

import 'package:flutter/material.dart';

import '../audio.dart';
import '../haptics.dart';
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
    this.reduceMotion = false,
  });

  final String questTitle;
  final String message;
  final VoidCallback onDismiss;

  /// Re-used for goal completions ("GOAL ACHIEVED" / "YOU MADE IT.").
  final String kicker;
  final String headline;
  final bool reduceMotion;

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
    parent: _c,
    curve: const Interval(0, 0.18, curve: Curves.easeOut),
  );
  late final Animation<double> _slam = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.08, 0.5, curve: Motion.slam),
  );
  late final Animation<double> _detail = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.45, 0.75, curve: Curves.easeOutCubic),
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
    // softens to a single medium under reduce-motion (Haptics.big honors it)
    if (still) {
      Haptics.light();
    } else {
      Haptics.big();
    }
    _c.forward();
    if (!still) {
      _burstTimer = Timer(const Duration(milliseconds: 320), () {
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
    final center = Offset(size.width / 2, size.height * 0.38);
    final still =
        widget.reduceMotion || MediaQuery.disableAnimationsOf(context);

    // overlay entries need a Material ancestor (yellow-underline fix)
    return OverlaySurface(
      child: Semantics(
        button: true,
        label: '${widget.kicker}. ${widget.headline} ${widget.questTitle}',
        hint: 'Tap to continue',
        onTap: widget.onDismiss,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onDismiss,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final wash = still ? 1.0 : _wash.value;
              final slam = still ? 1.0 : _slam.value;
              final detail = still ? 1.0 : _detail.value;
              return Container(
                // amber dusk — glowing warm, distinct from level-up's deep walnut
                color: const Color(0xFF2B1D0E).withValues(alpha: 0.94 * wash),
                child: Stack(
                  children: [
                    if (_burst && !still)
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
                        reduce: false,
                      ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Opacity(
                              opacity: wash,
                              child: Text(
                                widget.kicker,
                                style: Type.label.copyWith(
                                  fontSize: 12,
                                  color: Palette.streak,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Transform.scale(
                              scale: still ? 1 : 0.5 + 0.5 * slam,
                              child: Opacity(
                                opacity: slam.clamp(0.0, 1.0),
                                child: Text(
                                  widget.headline,
                                  textAlign: TextAlign.center,
                                  style: Type.display.copyWith(
                                    fontSize: 52,
                                    fontWeight: FontWeight.w700,
                                    color: Palette.textHi,
                                    shadows: [
                                      Shadow(
                                        color: Palette.xpLight.withValues(
                                          alpha: 0.8,
                                        ),
                                        blurRadius: still ? 20 : 30 * slam,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Opacity(
                              opacity: detail,
                              child: Transform.translate(
                                offset: Offset(
                                  0,
                                  still ? 0 : 16 * (1 - detail),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      widget.questTitle,
                                      textAlign: TextAlign.center,
                                      style: Type.body.copyWith(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Palette.textMid,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      widget.message,
                                      textAlign: TextAlign.center,
                                      style: Type.body.copyWith(
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                        color: Palette.textLo,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 44),
                            Opacity(
                              opacity: detail * 0.6,
                              child: Text(
                                'tap to keep going →',
                                style: Type.label.copyWith(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
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
