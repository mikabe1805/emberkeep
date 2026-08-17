import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'facets.dart';

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
    this.reduceMotion = false,
  });

  /// 0..1 toward next level.
  final double progress;

  /// Bump when the bar must restart from 0 (i.e. the level changed).
  final int generation;
  final double height;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion || MediaQuery.disableAnimationsOf(context);
    // RepaintBoundary: the ribbing animates continuously — confine its
    // invalidations to the 14px bar instead of the whole header layer.
    return RepaintBoundary(
      child: ClipPath(
        clipper: FacetedClipper(cut: height * 0.42),
        child: Container(
          height: height,
          color: const Color(0x1FF2CD93), // faint honey track in the dark
          child: TweenAnimationBuilder<double>(
            key: ValueKey(generation),
            tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
            duration: still ? Duration.zero : Motion.barFill,
            curve: Motion.barCurve,
            builder: (_, value, _) => _RibbedFill(
              value: value,
              height: height,
              // The fill itself still pours on web. Only the endless
              // decorative stripe crawl parks after it settles.
              lively: !still && !kIsWeb,
            ),
          ),
        ),
      ),
    );
  }
}

class _RibbedFill extends StatefulWidget {
  const _RibbedFill({
    required this.value,
    required this.height,
    required this.lively,
  });
  final double value;
  final double height;
  final bool lively;

  @override
  State<_RibbedFill> createState() => _RibbedFillState();
}

class _RibbedFillState extends State<_RibbedFill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scroll;

  @override
  void initState() {
    super.initState();
    // Initialize while the element is active. A lazy field initializer first
    // touched by dispose() would try to create a ticker from a deactivated
    // context when reduced motion kept the controller otherwise unused.
    _scroll = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.lively) _scroll.repeat();
  }

  @override
  void didUpdateWidget(covariant _RibbedFill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lively == widget.lively) return;
    if (widget.lively) {
      _scroll.repeat();
    } else {
      _scroll
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.lively) {
      return CustomPaint(
        size: Size.infinite,
        painter: _FillPainter(
          value: widget.value,
          phase: 0,
          height: widget.height,
        ),
      );
    }
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
  _FillPainter({
    required this.value,
    required this.phase,
    required this.height,
  });
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
    for (
      double x = -size.height + offset - gap;
      x < w + size.height;
      x += gap
    ) {
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
