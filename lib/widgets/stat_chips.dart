import 'package:flutter/material.dart';

import '../tokens.dart';

/// Header row of the six domain readouts. A column pulses with its own color
/// and counts up when its stat gains — the header is a live mini character
/// sheet, reacting to every completion (DESIGN.md §7).
///
/// It used to also run a 4.2 s brightness loop across all six glyphs, forever,
/// on the two most-visited screens. That is exactly the autonomous sparkle the
/// direction rules out: shine moves because the user did something. The pulse
/// on an actual gain stays; the idle loop is gone.
///
/// Deliberately borderless. This row sits *inside* an already-bordered glass
/// panel, and boxing each domain again produced the nested-frame look the
/// approved board art doesn't have — six lit chips competing with the hearth
/// for the top of the value range. Hairline rules separate the columns instead,
/// so the only things carrying light here are the six glyphs and their numbers.
class StatChips extends StatefulWidget {
  const StatChips({super.key, required this.values, this.reduceMotion = false});

  final Map<Stat, int> values;
  final bool reduceMotion;

  @override
  State<StatChips> createState() => _StatChipsState();
}

class _StatChipsState extends State<StatChips> {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final s in Stat.values) ...[
          if (s.index != 0) const _DomainRule(),
          Expanded(
            child: RepaintBoundary(
              child: _StatChip(stat: s, value: widget.values[s] ?? 0),
            ),
          ),
        ],
      ],
    );
  }
}

/// The hairline between two domains: a short vertical rule that fades out at
/// both ends, so it reads as light catching an edge rather than a drawn border.
class _DomainRule extends StatelessWidget {
  const _DomainRule();

  // A fixed height rather than CrossAxisAlignment.stretch: with every child
  // stretching there is nothing left to size the row from.
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 62,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Palette.glassEdge.withValues(alpha: 0),
          Palette.glassEdge.withValues(alpha: 0.5),
          Palette.glassEdge.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ),
    ),
  );
}

class _StatChip extends StatefulWidget {
  const _StatChip({required this.stat, required this.value});

  final Stat stat;
  final int value;

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
      animation: _pulse,
      builder: (context, _) {
        // quick swell then settle: peak mid-animation
        final wave = Curves.easeOutBack.transform(
          1 - (_pulse.value - 0.5).abs() * 2,
        );
        final active = _pulse.isAnimating;
        final glyphAlpha = (0.86 + 0.14 * (active ? wave : 0)).clamp(0.0, 1.0);
        return Transform.scale(
          scale: 1 + 0.08 * (active ? wave : 0),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.stat.icon,
                  size: 24,
                  color: c.withValues(alpha: glyphAlpha),
                  // the only place a domain is allowed to throw light, and
                  // only while it is actually gaining
                  shadows: active
                      ? [
                          Shadow(
                            color: c.withValues(alpha: 0.55 * wave),
                            blurRadius: 11,
                          ),
                        ]
                      : const [],
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.stat.abbr,
                    maxLines: 1,
                    style: Type.label.copyWith(
                      fontSize: 10,
                      letterSpacing: 0.7,
                      color: c.withValues(alpha: 0.82),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: _shownFrom, end: widget.value),
                  duration: Motion.settle,
                  builder: (_, v, _) => FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$v',
                      maxLines: 1,
                      style: Type.numerals.copyWith(
                        fontSize: 20,
                        color: Palette.textMid,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
