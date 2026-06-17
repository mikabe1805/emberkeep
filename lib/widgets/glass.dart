import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../content/themes.dart';
import '../tokens.dart';

/// Overlay entries render outside the Scaffold's Material — without a
/// Material ancestor every Text falls back to the yellow-underline error
/// style. Wrap any OverlayEntry-rooted widget in this.
class OverlaySurface extends StatelessWidget {
  const OverlaySurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Material(type: MaterialType.transparency, child: child);
}

/// Warm glass panel with the signature specular "drop of light" at top-left
/// (the owner's liquid-glass technique). [blur] enables a real BackdropFilter
/// — reserve it for the header and nav dock; cards use the cheap variant.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 20,
    this.blur = false,
    this.tint,
    this.glow = false,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final double radius;
  final bool blur;
  final Color? tint;
  final bool glow;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    Widget panel = Container(
      padding: padding,
      decoration: Glass.panel(radius: radius, tint: tint, glow: glow),
      child: child,
    );
    panel = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          if (blur)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: const SizedBox.expand(),
              ),
            ),
          panel,
          // specular drop of light, top-left — every glass element has one
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: RadialGradient(
                    center: const Alignment(-0.75, -0.85),
                    radius: 1.1,
                    colors: [
                      Palette.specular.withValues(alpha: 0.14),
                      Palette.specular.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.55],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return panel;
  }
}

/// The candlelit desk: deep espresso→plum-dusk gradient, soft glowing color
/// pools, and drifting firefly motes — the night is alive but never busy.
class WarmBackground extends StatelessWidget {
  const WarmBackground({super.key, required this.child, this.themeId});
  final Widget child;

  /// The active canvas theme id (null → default Walnut Night). Resolved here
  /// so callers only pass a string.
  final String? themeId;

  @override
  Widget build(BuildContext context) {
    final theme = canvasThemeById(themeId);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.top, theme.bottom],
        ),
      ),
      child: Stack(
        children: [
          // pools of warm light — recolored by the theme — glowing in the dark
          Positioned(
            top: -70, left: -60,
            child: _Glow(color: theme.glows[0], size: 320),
          ),
          Positioned(
            top: 200, right: -90,
            child: _Glow(color: theme.glows[1], size: 280),
          ),
          Positioned(
            bottom: 40, left: -50,
            child: _Glow(color: theme.glows[2], size: 260),
          ),
          Positioned(
            bottom: 240, right: 30,
            child: _Glow(color: theme.glows[3], size: 180),
          ),
          const Positioned.fill(child: _Fireflies()),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// Drifting, twinkling motes of warm light. One repaint-bounded layer,
/// quantized to ~20 fps — ambience, not a particle storm.
class _Fireflies extends StatefulWidget {
  const _Fireflies();

  @override
  State<_Fireflies> createState() => _FirefliesState();
}

class _Mote {
  _Mote(Random rng)
      : x = rng.nextDouble(),
        y = rng.nextDouble(),
        size = 1.4 + rng.nextDouble() * 2.2,
        driftX = (rng.nextDouble() - 0.5) * 0.018,
        driftY = -0.006 - rng.nextDouble() * 0.014,
        phase = rng.nextDouble(),
        twinkle = 0.5 + rng.nextDouble() * 1.5,
        warm = rng.nextDouble() < 0.75;

  final double x, y, size, driftX, driftY, phase, twinkle;
  final bool warm;
}

class _FirefliesState extends State<_Fireflies>
    with SingleTickerProviderStateMixin {
  static const _count = 16;
  late final List<_Mote> _motes;
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    final rng = Random(7);
    _motes = List.generate(_count, (_) => _Mote(rng));
    _c = AnimationController(
        vsync: this, duration: const Duration(seconds: 60))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(
            size: Size.infinite,
            // quantize: ~20 repaints/s is invisible for slow motes
            painter: _MotePainter(
                motes: _motes, t: (_c.value * 1200).round() / 1200),
          ),
        ),
      ),
    );
  }
}

class _MotePainter extends CustomPainter {
  _MotePainter({required this.motes, required this.t});
  final List<_Mote> motes;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final m in motes) {
      // wrap-around drift across the whole 60s loop
      final x = ((m.x + m.driftX * t * 60) % 1.0) * size.width;
      final y = ((m.y + m.driftY * t * 60) % 1.0 + 1.0) % 1.0 * size.height;
      // twinkle: each mote breathes on its own rhythm
      final glow =
          0.25 + 0.75 * (0.5 + 0.5 * sin(2 * pi * (t * 60 * m.twinkle / 8 + m.phase)));
      final color = m.warm
          ? Palette.xpLight.withValues(alpha: 0.5 * glow)
          : Palette.unlock.withValues(alpha: 0.35 * glow);
      paint
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(x, y), m.size * (0.8 + 0.3 * glow), paint);
    }
  }

  @override
  bool shouldRepaint(_MotePainter old) => old.t != t;
}
