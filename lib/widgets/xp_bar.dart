import 'package:flutter/material.dart';

import '../tokens.dart';

/// The XP bar. Fill accelerates INTO the end and never stalls near full
/// (perceived-duration research), with animated ribbing inside the fill and
/// a glow at the leading edge. Keyed by [generation] so a level-up restarts
/// the fill from empty (overflow pour) instead of draining backwards.
class XpBar extends StatelessWidget {
  const XpBar({
    super.key,
    required this.progress,
    required this.generation,
    this.height = 14,
  });

  /// 0..1 toward next level.
  final double progress;

  /// Bump when the bar must restart from 0 (i.e. the level changed).
  final int generation;
  final double height;

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary: the ribbing animates continuously — confine its
    // invalidations to the 14px bar instead of the whole header layer.
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Container(
          height: height,
          color: const Color(0x1FF2CD93), // faint honey track in the dark
          child: TweenAnimationBuilder<double>(
            key: ValueKey(generation),
            tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
            duration: Motion.barFill,
            curve: Motion.barCurve,
            builder: (_, value, _) => _RibbedFill(value: value, height: height),
          ),
        ),
      ),
    );
  }
}

class _RibbedFill extends StatefulWidget {
  const _RibbedFill({required this.value, required this.height});
  final double value;
  final double height;

  @override
  State<_RibbedFill> createState() => _RibbedFillState();
}

class _RibbedFillState extends State<_RibbedFill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scroll = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scroll,
      builder: (_, _) => CustomPaint(
        size: Size.infinite,
        painter: _FillPainter(
          value: widget.value,
          // quantized so shouldRepaint dedupes: ~20 repaints/s reads
          // identically for an 18px stripe scroll, at a sixth of the work
          phase: (_scroll.value * 24).round() / 24,
          height: widget.height,
        ),
      ),
    );
  }
}

class _FillPainter extends CustomPainter {
  _FillPainter({required this.value, required this.phase, required this.height});
  final double value;
  final double phase;
  final double height;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * value;
    if (w <= 0) return;
    final fillRect = Rect.fromLTWH(0, 0, w, size.height);

    // honey gradient fill — light pours in from the left
    canvas.drawRect(
      fillRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Palette.xpLight, Palette.xp],
        ).createShader(fillRect),
    );

    // animated ribbing: scrolling diagonal stripes inside the fill
    canvas.save();
    canvas.clipRect(fillRect);
    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.28);
    const gap = 18.0;
    final offset = phase * gap;
    for (double x = -size.height + offset - gap; x < w + size.height; x += gap) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + size.height, 0)
        ..lineTo(x + size.height + 6, 0)
        ..lineTo(x + 6, size.height)
        ..close();
      canvas.drawPath(path, stripe);
    }
    canvas.restore();

    // leading-edge glow
    canvas.drawCircle(
      Offset(w, size.height / 2),
      height * 0.9,
      Paint()
        ..color = Palette.xp.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(_FillPainter old) =>
      old.value != value || old.phase != phase;
}
