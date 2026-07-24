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

/// A number that rolls from its PREVIOUS value to the new one whenever [value]
/// changes — for persistent surfaces (a header that updates in place) where
/// [CountUpText]'s always-from-zero climb would misfire. Tracks the last value
/// and tweens prev→new so the most-watched number on screen visibly ticks up
/// at the moment of a gain instead of snapping like inert data (round-65).
class RollingNumber extends StatefulWidget {
  const RollingNumber(
    this.value, {
    super.key,
    required this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = Motion.barFill,
    this.curve = Motion.barCurve,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final int value;
  final TextStyle style;
  final String prefix;
  final String suffix;
  final Duration duration;
  final Curve curve;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  State<RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<RollingNumber> {
  late double _from = widget.value.toDouble();
  late double _to = widget.value.toDouble();

  @override
  void didUpdateWidget(RollingNumber old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      // start the next roll from wherever the last one settled
      _from = _to;
      _to = widget.value.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from, end: _to),
      duration: widget.duration,
      curve: widget.curve,
      builder: (_, v, _) => Text(
        '${widget.prefix}${v.round()}${widget.suffix}',
        maxLines: widget.maxLines,
        overflow: widget.overflow ?? TextOverflow.clip,
        textAlign: widget.textAlign,
        style: widget.style.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
