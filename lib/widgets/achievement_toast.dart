import 'dart:async';

import 'package:flutter/material.dart';

import '../audio.dart';
import '../content/achievements.dart';
import '../haptics.dart';
import '../tokens.dart';
import 'ember_flame_icon.dart';
import 'facets.dart';
import 'glass.dart';

/// Achievement banner: slides down from the top, gold-lit, self-dismisses.
/// Smaller than a level-up, bigger than a receipt bubble.
class AchievementToast extends StatefulWidget {
  const AchievementToast({
    super.key,
    required this.achievement,
    required this.onDone,
    this.flameHue = emberFlameDefaultHue,
    this.reduceMotion = false,
  });

  final Achievement achievement;
  final VoidCallback onDone;
  final Color flameHue;
  final bool reduceMotion;

  @override
  State<AchievementToast> createState() => _AchievementToastState();
}

class _AchievementToastState extends State<AchievementToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2600),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) _finish();
      });

  late final Animation<double> _in = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.12, curve: Curves.easeOutBack),
  );
  late final Animation<double> _out = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.88, 1.0, curve: Curves.easeIn),
  );
  bool _started = false;
  bool _done = false;
  Timer? _doneTimer;

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    widget.onDone();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final still =
        widget.reduceMotion || MediaQuery.disableAnimationsOf(context);
    Sfx.instance.play('loot');
    if (still) {
      Haptics.light();
    } else {
      Haptics.success();
    }
    if (still) {
      // Accessibility mode parks the banner in its final readable state. A
      // wall-clock timer owns teardown so OS animation scaling cannot shorten
      // or indefinitely extend its reading window.
      _doneTimer = Timer(const Duration(milliseconds: 2600), _finish);
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _doneTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still =
        widget.reduceMotion || MediaQuery.disableAnimationsOf(context);
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 10,
      left: 0,
      right: 0,
      child: OverlaySurface(
        child: Semantics(
          liveRegion: true,
          label: 'Achievement unlocked: ${widget.achievement.title}',
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final opacity = still
                    ? 1.0
                    : ((_in.value) * (1 - _out.value)).clamp(0.0, 1.0);
                final banner = Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: facetedDecoration(
                      color: Palette.card.withValues(alpha: 0.97),
                      cut: 11,
                      borderColor: Palette.xpLight.withValues(alpha: 0.7),
                      shadows: const [
                        BoxShadow(
                          color: Palette.honeyGlow,
                          blurRadius: 20,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        emberkeepIcon(
                          widget.achievement.icon,
                          size: 20,
                          color: Palette.xpLight,
                          flameHue: widget.flameHue,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ACHIEVEMENT',
                              style: Type.label.copyWith(
                                fontSize: 11,
                                color: Palette.xp,
                              ),
                            ),
                            Text(
                              widget.achievement.title,
                              style: Type.display.copyWith(fontSize: 15),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
                return Opacity(
                  opacity: opacity,
                  child: still
                      ? banner
                      : Transform.translate(
                          offset: Offset(0, -30 * (1 - _in.value)),
                          child: banner,
                        ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
