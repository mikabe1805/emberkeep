import 'package:flutter/material.dart';

import '../models.dart';
import '../tokens.dart';
import 'pressable.dart';

/// One quest row as a warm glass card: stat-colored check ring, title,
/// ladder hint, dread storm, and the XP payout preview — the reward IS the
/// difficulty signal (the abstract pips failed playtesting, DESIGN.md §11.4).
class QuestCard extends StatefulWidget {
  const QuestCard({
    super.key,
    required this.quest,
    required this.done,
    required this.xpPreview,
    required this.onComplete,
    this.onManage,
    this.onEncore,
  });

  final Quest quest;

  /// Done for the current period (computed by the page against today).
  final bool done;
  final int xpPreview;
  final void Function(Offset globalTapPosition) onComplete;

  /// Long-press: star / remove (round-9 management affordance).
  final VoidCallback? onManage;

  /// Shown as a ⚡ on a finished, still-climbable card — the peak-end encore
  /// (RESEARCH-momentum.md §1), right where the win just landed.
  final VoidCallback? onEncore;

  @override
  State<QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends State<QuestCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _squash = AnimationController(
    vsync: this,
    duration: Motion.quick,
  );

  void _handleTap(Offset globalPos) {
    if (widget.done) return;
    _squash.forward(from: 0).then((_) => _squash.reverse());
    widget.onComplete(globalPos);
  }

  @override
  void dispose() {
    _squash.dispose();
    super.dispose();
  }

  static String _difficultyWord(int d) {
    if (d <= 2) return 'EASY';
    if (d <= 4) return 'SOLID';
    if (d <= 6) return 'TOUGH';
    return 'EPIC';
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quest;
    final done = widget.done;
    return AnimatedBuilder(
      animation: _squash,
      builder: (context, child) => Transform.scale(
        scaleY: 1 - 0.08 * _squash.value,
        scaleX: 1 + 0.02 * _squash.value,
        child: child,
      ),
      child: Pressable(
        enabled: !done,
        onTapUp: _handleTap,
        onLongPress: widget.onManage,
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            AnimatedContainer(
              duration: Motion.settle,
              curve: Motion.respond,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: done
                    ? Palette.glassFill.withValues(alpha: 0.38)
                    : Palette.glassFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: done
                      ? Palette.success.withValues(alpha: 0.3)
                      : q.priority
                          ? Palette.xpLight.withValues(alpha: 0.55)
                          : Palette.glassEdge,
                  width: 1.2,
                ),
                boxShadow: done
                    ? const []
                    : const [
                        BoxShadow(
                          color: Palette.warmShadow,
                          blurRadius: 14,
                          offset: Offset(0, 5),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  _CheckRing(stat: q.stat, done: done),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: Motion.settle,
                          style: Type.body.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: done ? Palette.textLo : Palette.textHi,
                            decoration:
                                done ? TextDecoration.lineThrough : null,
                            decorationColor: Palette.textLo,
                          ),
                          child: Text(q.displayTitle),
                        ),
                        Builder(builder: (_) {
                          // Each meta tag is a self-contained chip; a Wrap lets
                          // them flow to a second line instead of overflowing a
                          // Row on a narrow phone now that the type is larger.
                          final chips = <Widget>[
                            if (q.workout)
                              _MetaChip(Icons.fitness_center, 'GUIDED',
                                  q.stat.color),
                            if (q.priority)
                              _MetaChip(
                                  Icons.star, 'MAIN', Palette.xpLight),
                            if (q.allDay)
                              _MetaChip(Icons.nightlight_round,
                                  'ALL DAY · CHECKS AT NIGHT', Palette.unlock),
                            if (q.rising)
                              _MetaChip(
                                  Icons.trending_up,
                                  '${q.risingStreak}/${Quest.risesAt}',
                                  Palette.streak),
                            if (q.bonus)
                              _MetaChip(Icons.bolt, 'BONUS · TODAY',
                                  Palette.streak)
                            else if (q.isEvent)
                              Builder(builder: (_) {
                                final now = DateTime.now();
                                final overdue = q.dueDate!.isBefore(DateTime(
                                    now.year, now.month, now.day));
                                return _MetaChip(
                                    null,
                                    overdue ? 'STILL WAITING' : 'DUE TODAY',
                                    overdue
                                        ? Palette.streak
                                        : Palette.xpLight);
                              })
                            else if (q.schedule != QuestSchedule.daily)
                              _MetaChip(null, q.schedule.label,
                                  Palette.xpLight.withValues(alpha: 0.8)),
                            if (q.verification == Verification.timer)
                              _MetaChip(Icons.timer_outlined,
                                  '${q.timerMinutes}M PROOF ×1.2',
                                  Palette.verify),
                            if (q.ladderHint != null)
                              _MetaChip(null, q.ladderHint!, Palette.textLo),
                          ];
                          if (chips.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: chips,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  if (q.dread)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      // storm-in-steel, NOT the ember flame — that pair
                      // belongs exclusively to the streak mechanic
                      child: Icon(Icons.thunderstorm,
                          size: 20,
                          color: done
                              ? Palette.dread.withValues(alpha: 0.4)
                              : Palette.dread),
                    ),
                  if (done && widget.onEncore != null)
                    GestureDetector(
                      onTap: widget.onEncore,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        margin: const EdgeInsets.only(left: 4),
                        constraints:
                            const BoxConstraints(minHeight: 44, minWidth: 44),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: Palette.streak.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt,
                                size: 15, color: Palette.streak),
                            const SizedBox(width: 4),
                            Text('MORE',
                                style: Type.label.copyWith(
                                    fontSize: 11, color: Palette.streak)),
                          ],
                        ),
                      ),
                    )
                  else
                    _XpChip(
                      xp: widget.xpPreview,
                      word: _difficultyWord(q.difficulty),
                      dim: done,
                    ),
                ],
              ),
            ),
            // specular drop of light
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: RadialGradient(
                      center: const Alignment(-0.8, -0.9),
                      radius: 1.0,
                      colors: [
                        Palette.specular.withValues(alpha: done ? 0.12 : 0.30),
                        Palette.specular.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.5],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckRing extends StatelessWidget {
  const _CheckRing({required this.stat, required this.done});
  final Stat stat;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.quick,
      curve: Curves.easeOutBack,
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? Palette.success : Colors.transparent,
        border: Border.all(
          color: done ? Palette.success : stat.color,
          width: 2.4,
        ),
        // Keep a constant-blur shadow in BOTH states (alpha→0 when done)
        // rather than toggling to an empty list — the easeOutBack overshoot
        // would otherwise lerp the blur radius negative and assert.
        boxShadow: [
          BoxShadow(
            color: stat.color.withValues(alpha: done ? 0.0 : 0.25),
            blurRadius: 8,
          ),
        ],
      ),
      child: done
          ? const Icon(Icons.check, size: 20, color: Palette.parchment)
          : null,
    );
  }
}

/// One meta tag under a quest title (GUIDED / MAIN / ALL DAY / proof / …).
/// A self-contained pill so the parent can lay these out in a Wrap that
/// reflows instead of overflowing once the type is at a readable size.
class _MetaChip extends StatelessWidget {
  const _MetaChip(this.icon, this.text, this.color);
  final IconData? icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
        ],
        Text(text, style: Type.label.copyWith(fontSize: 11, color: color)),
      ],
    );
  }
}

/// The payout preview: "+34 XP" in honey with a plain difficulty word.
class _XpChip extends StatelessWidget {
  const _XpChip({required this.xp, required this.word, required this.dim});
  final int xp;
  final String word;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final alpha = dim ? 0.4 : 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Palette.xpLight.withValues(alpha: 0.35 * alpha),
            border: Border.all(
                color: Palette.xp.withValues(alpha: 0.35 * alpha)),
          ),
          child: Text(
            '+$xp XP',
            style: Type.numerals.copyWith(
                fontSize: 15, color: Palette.xp.withValues(alpha: alpha)),
          ),
        ),
        const SizedBox(height: 4),
        Text(word,
            style: Type.label.copyWith(
                fontSize: 11,
                color: Palette.textLo.withValues(alpha: alpha))),
      ],
    );
  }
}
