import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../content/achievements.dart';
import '../tokens.dart';
import 'glass.dart';

/// Achievement banner: slides down from the top, gold-lit, self-dismisses.
/// Smaller than a level-up, bigger than a receipt bubble.
class AchievementToast extends StatefulWidget {
  const AchievementToast({
    super.key,
    required this.achievement,
    required this.onDone,
  });

  final Achievement achievement;
  final VoidCallback onDone;

  @override
  State<AchievementToast> createState() => _AchievementToastState();
}

class _AchievementToastState extends State<AchievementToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  late final Animation<double> _in = CurvedAnimation(
      parent: _c, curve: const Interval(0, 0.12, curve: Curves.easeOutBack));
  late final Animation<double> _out = CurvedAnimation(
      parent: _c, curve: const Interval(0.88, 1.0, curve: Curves.easeIn));

  @override
  void initState() {
    super.initState();
    Sfx.instance.play('loot');
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 10,
      left: 0,
      right: 0,
      child: OverlaySurface(
        child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Opacity(
            opacity: ((_in.value) * (1 - _out.value)).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -30 * (1 - _in.value)),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Palette.card.withValues(alpha: 0.97),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: Palette.xpLight.withValues(alpha: 0.7)),
                    boxShadow: const [
                      BoxShadow(
                          color: Palette.honeyGlow,
                          blurRadius: 20,
                          offset: Offset(0, 6)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.achievement.icon,
                          size: 20, color: Palette.xpLight),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ACHIEVEMENT',
                              style: Type.label.copyWith(
                                  fontSize: 7.5, color: Palette.xp)),
                          Text(widget.achievement.title,
                              style: Type.display.copyWith(fontSize: 15)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
