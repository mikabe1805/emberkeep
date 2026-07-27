import 'package:flutter/material.dart';

import '../audio.dart';
import '../haptics.dart';
import '../tokens.dart';
import 'facets.dart';
import 'glass.dart';
import 'particles.dart';

/// Full-screen streak milestone celebration (DESIGN.md §7): a warm chest
/// opens to reveal an ember payout, scaled by the milestone's significance.
/// 7 days = a warm glow, 30 days = a proper blaze, 100 days = legendary.
///
/// Always skippable with a tap. Rationed to milestones only — never fires
/// for ordinary completions or level-ups (those have their own overlays).
class StreakMilestoneOverlay extends StatefulWidget {
  const StreakMilestoneOverlay({
    super.key,
    required this.days,
    required this.embers,
    required this.onDismiss,
    this.reduceMotion = false,
  });

  final int days;
  final int embers;
  final VoidCallback onDismiss;
  final bool reduceMotion;

  @override
  State<StreakMilestoneOverlay> createState() => _StreakMilestoneOverlayState();
}

class _StreakMilestoneOverlayState extends State<StreakMilestoneOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  late final Animation<double> _dim = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.12, curve: Curves.easeOut),
  );
  late final Animation<double> _slam = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.08, 0.45, curve: Motion.slam),
  );
  late final Animation<double> _chestOpen = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.4, 0.65, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _emberRise = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
  );

  bool _burst = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
    Sfx.instance.play('streak');
    Haptics.big();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() => _burst = true);
        Sfx.instance.play('loot');
        Haptics.flourish();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String get _label {
    if (widget.days >= 100) return 'A SEASON OF FIRE';
    if (widget.days >= 30) return 'A MONTH OF FIRE';
    return 'A WEEK OF FIRE';
  }

  @override
  Widget build(BuildContext context) {
    final intensity = widget.days >= 100
        ? 1.0
        : widget.days >= 30
        ? 0.7
        : 0.4;
    return GestureDetector(
      onTap: widget.onDismiss,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Stack(
            children: [
              // dim
              Positioned.fill(
                child: Opacity(
                  opacity: _dim.value * 0.88,
                  child: const ColoredBox(color: Color(0xF2191210)),
                ),
              ),
              // particle burst (scaled by significance)
              if (_burst)
                Positioned.fill(
                  child: ParticleBurst(
                    origin: Offset(
                      MediaQuery.sizeOf(context).width / 2,
                      MediaQuery.sizeOf(context).height / 2,
                    ),
                    colors: [Palette.streak, Palette.xp, Palette.xpLight],
                    count: widget.days >= 100
                        ? 40
                        : widget.days >= 30
                        ? 28
                        : 18,
                    vibrancy: intensity * 1.3,
                    spread: widget.days >= 100 ? 140 : 100,
                    reduce: widget.reduceMotion,
                  ),
                ),
              // content
              Center(
                child: GlassPanel(
                  blur: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 28,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // the streak number slams in
                      Transform.scale(
                        scale: _slam.value,
                        child: Text(
                          '${widget.days}',
                          style: Type.numerals.copyWith(
                            fontSize: 72,
                            color: Palette.streak,
                            shadows: [
                              Shadow(
                                color: Palette.streak.withValues(alpha: 0.5),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'DAY STREAK',
                        style: Type.label.copyWith(
                          fontSize: 12,
                          color: Palette.textLo,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _label,
                        style: Type.display.copyWith(
                          fontSize: 22,
                          color: Palette.streak,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // the chest opening
                      SizedBox(
                        width: 120,
                        height: 80,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            // chest body
                            Transform.scale(
                              scale: _slam.value,
                              child: Container(
                                width: 90,
                                height: 56,
                                decoration: facetedDecoration(
                                  cut: 8,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF6E451F),
                                      Color(0xFF3A2410),
                                    ],
                                  ),
                                  borderColor: Palette.streak.withValues(
                                    alpha: 0.4,
                                  ),
                                  borderWidth: 2,
                                  shadows: [
                                    BoxShadow(
                                      color: Palette.streak.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // lid opens
                            Transform.translate(
                              offset: Offset(0, -_chestOpen.value * 30),
                              child: Transform.rotate(
                                angle: -_chestOpen.value * 0.3,
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  width: 90,
                                  height: 28,
                                  decoration: facetedDecoration(
                                    cut: 7,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFF8A6A1E),
                                        Color(0xFF4A3210),
                                      ],
                                    ),
                                    borderColor: Palette.streak.withValues(
                                      alpha: 0.4,
                                    ),
                                    borderWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                            // embers rising from the open chest
                            if (_chestOpen.value > 0.3)
                              ...List.generate(8, (i) {
                                final t = _emberRise.value;
                                final dx = (i - 3.5) * 12.0;
                                final dy = -t * (60 + i * 8);
                                final alpha = (1 - t) * 0.9;
                                return Transform.translate(
                                  offset: Offset(dx, dy),
                                  child: Opacity(
                                    opacity: alpha,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Palette.xp,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Palette.xp.withValues(
                                              alpha: 0.6,
                                            ),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // the payout
                      Opacity(
                        opacity: _emberRise.value,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '✦',
                              style: Type.display.copyWith(
                                fontSize: 28,
                                color: Palette.xp,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '+${widget.embers} embers',
                              style: Type.display.copyWith(
                                fontSize: 22,
                                color: Palette.xpLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'tap to continue',
                        style: Type.body.copyWith(
                          fontSize: 11,
                          color: Palette.textLo,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
