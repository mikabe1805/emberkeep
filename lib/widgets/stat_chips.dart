import 'dart:math';

import 'package:flutter/material.dart';

import '../tokens.dart';

/// Header row of the six attribute chips. A chip pulses with its own color
/// and counts up when its stat gains — the header is a live mini character
/// sheet, reacting to every completion (DESIGN.md §7). Between events a
/// faint border shimmer drifts across the row (§2 ambient idle motion),
/// driven by one shared controller and quantized to ~20 repaints/s.
class StatChips extends StatefulWidget {
  const StatChips({super.key, required this.values});

  final Map<Stat, int> values;

  @override
  State<StatChips> createState() => _StatChipsState();
}

class _StatChipsState extends State<StatChips>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final s in Stat.values)
          Expanded(
            child: RepaintBoundary(
              child: _StatChip(
                stat: s,
                value: widget.values[s] ?? 0,
                ambient: _ambient,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatChip extends StatefulWidget {
  const _StatChip({
    required this.stat,
    required this.value,
    required this.ambient,
  });

  final Stat stat;
  final int value;
  final Animation<double> ambient;

  @override
  State<_StatChip> createState() => _StatChipState();
}

class _StatChipState extends State<_StatChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: Motion.settle,
  );
  int _shownFrom = 0;

  @override
  void didUpdateWidget(_StatChip old) {
    super.didUpdateWidget(old);
    if (widget.value > old.value) {
      _shownFrom = old.value;
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.stat.color;
    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, widget.ambient]),
      builder: (context, _) {
        // quick swell then settle: peak mid-animation
        final wave = Curves.easeOutBack.transform(
            1 - (_pulse.value - 0.5).abs() * 2);
        final active = _pulse.isAnimating;
        // ambient shimmer drifting across the row, staggered per chip;
        // quantized so repaints dedupe to ~20/s
        final phase = (widget.ambient.value * 84).round() / 84;
        final shimmer = 0.5 +
            0.5 * sin(2 * pi * (phase + widget.stat.index / Stat.values.length));
        return Transform.scale(
          scale: 1 + 0.10 * (active ? wave : 0),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Palette.glassFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? c.withValues(alpha: 0.4 + 0.6 * wave)
                    : Color.lerp(Palette.glassEdge,
                        c.withValues(alpha: 0.55), 0.16 * shimmer)!,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: c.withValues(alpha: 0.35 * wave),
                        blurRadius: 12,
                      )
                    ]
                  : const [],
            ),
            child: Column(
              children: [
                Text(widget.stat.abbr,
                    style: Type.label.copyWith(fontSize: 9, color: c)),
                const SizedBox(height: 2),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: _shownFrom, end: widget.value),
                  duration: Motion.settle,
                  builder: (_, v, _) => Text('$v',
                      style: Type.numerals.copyWith(fontSize: 14)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
