import 'package:flutter/material.dart';

/// A compact view of the permanent in-room record, the Woven Dawn.
///
/// Compact placements keep the approved artwork crisp. The room-sized
/// tapestry carries the detailed woven-row treatment; shrinking that mask into
/// a HUD slot made the mark look washed out and introduced a false hard seam.
class MorrowTapestryGlyph extends StatelessWidget {
  const MorrowTapestryGlyph({
    super.key,
    required this.level,
    required this.lit,
    this.leap = 0,
    this.glow,
    this.reduceMotion = false,
    this.size = 48,
  });

  final int level;
  final bool lit;
  final int leap;
  final Color? glow;
  final bool reduceMotion;
  final double size;

  double get _woven => ((level + 2) / 36).clamp(0.12, 1.0);

  @override
  Widget build(BuildContext context) {
    final woven = _woven;
    final image = Image.asset(
      'assets/brand/morrowloom-icon-runtime-v2.webp',
      width: size,
      height: size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      excludeFromSemantics: true,
    );
    final accent = Color.lerp(
      const Color(0xFFF1AA3C),
      glow ?? const Color(0xFFF1AA3C),
      0.18,
    )!;

    return Semantics(
      image: true,
      label: 'The Woven Dawn, ${(woven * 100).round()} percent woven',
      child: TweenAnimationBuilder<double>(
        key: ValueKey(leap),
        tween: Tween(begin: leap == 0 ? 1 : 0.88, end: 1),
        duration: Duration(milliseconds: reduceMotion ? 1 : 520),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.22),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: lit ? 0.25 : 0.10),
                  blurRadius: size * (lit ? 0.22 : 0.12),
                  spreadRadius: size * 0.01,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image,
                  Positioned(
                    right: size * 0.10,
                    bottom: size * 0.20,
                    child: SizedBox(
                      key: const ValueKey('morrow-woven-progress'),
                      width: size * 0.055 + 0.6,
                      height: size * 0.60 * woven,
                      child: CustomPaint(painter: _WovenCordPainter(accent)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WovenCordPainter extends CustomPainter {
  const _WovenCordPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width * 1.35;
    final glow = Paint()
      ..color = color.withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
    final stitch = Paint()..color = const Color(0xFFFFD67F);
    for (var y = size.height - size.width * 0.25; y >= 0; y -= step) {
      final knot = Offset(size.width * 0.5, y);
      canvas.drawCircle(knot, size.width * 0.46, glow);
      canvas.drawCircle(knot, size.width * 0.22, stitch);
    }
  }

  @override
  bool shouldRepaint(_WovenCordPainter oldDelegate) =>
      oldDelegate.color != color;
}
