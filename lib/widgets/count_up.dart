import 'package:flutter/material.dart';

import '../tokens.dart';

/// A number that counts UP to [value] when it first appears — earned data
/// should feel earned, not just printed (round-25 juice pass). Best on screens
/// entered fresh (a pushed detail route), where the climb plays on open. Uses
/// tabular figures so the width doesn't jitter mid-count.
class CountUpText extends StatelessWidget {
  const CountUpText(
    this.value, {
    super.key,
    required this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = Motion.barFill,
    this.curve = Motion.barCurve,
  });

  final int value;
  final TextStyle style;
  final String prefix;
  final String suffix;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (_, v, _) => Text(
        '$prefix${v.round()}$suffix',
        style: style.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
