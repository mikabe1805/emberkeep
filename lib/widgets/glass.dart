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
          // the wet lip — a bright line of candlelight catching the glass's
          // top inner edge; what reads as "a pane" rather than a tinted box
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Palette.specular.withValues(alpha: 0.10),
                      Palette.specular.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.12],
                  ),
                ),
              ),
            ),
          ),
          // the lower rim — the pane's own soft shadow, grounding it in depth
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Palette.glassRim, Color(0x00140C06)],
                    stops: [0.0, 0.16],
                  ),
                ),
              ),
            ),
          ),
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
                      Palette.specular.withValues(alpha: 0.16),
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
  const WarmBackground(
      {super.key, required this.child, this.themeId, this.tint});
  final Widget child;

  /// The active canvas theme id (null → default Walnut Night). Resolved here
  /// so callers only pass a string.
  final String? themeId;

  /// Optional colour to lean the glow pools toward — a domain's "base" page
  /// uses its own hue so each of the six feels like a different room of a life
  /// (round-25), not the same template recoloured by one accent.
  final Color? tint;

  Color _glow(Color base) =>
      tint == null ? base : Color.lerp(base, tint, 0.42)!;

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
          // pools of warm light — recolored by the theme — glowing in the dark.
          // Each breathes on its own slow rhythm (out of phase) so the room is
          // lit by candlelight that wavers, not a printed gradient.
          Positioned(
            top: -70, left: -60,
            child: _Glow(color: _glow(theme.glows[0]), size: 320, phase: 0.0),
          ),
          Positioned(
            top: 200, right: -90,
            child: _Glow(color: _glow(theme.glows[1]), size: 280, phase: 0.35),
          ),
          Positioned(
            bottom: 40, left: -50,
            child: _Glow(color: _glow(theme.glows[2]), size: 260, phase: 0.6),
          ),
          Positioned(
            bottom: 240, right: 30,
            child: _Glow(color: _glow(theme.glows[3]), size: 180, phase: 0.85),
          ),
          const Positioned.fill(child: _Fireflies()),
          // a soft vignette: the center where content lives feels lit, the
          // corners recede — editorial depth, not a flat fill.
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.15,
                    colors: [Color(0x00140C06), Color(0x3A140C06)],
                    stops: [0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatefulWidget {
  const _Glow({required this.color, required this.size, this.phase = 0});
  final Color color;
  final double size;

  /// 0..1 offset into the breath cycle, so the pools waver out of sync.
  final double phase;

  @override
  State<_Glow> createState() => _GlowState();
}

class _GlowState extends State<_Glow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 11),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.color;
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            // quantize to ~15 steps so the swell is smooth but cheap
            final t = sin(2 * pi *
                ((_c.value * 15).round() / 15 + widget.phase));
            final scale = 1 + 0.07 * t; // gentle swell
            // brighten/dim by modulating the gradient's own alpha — no Opacity
            // save-layer over a 320px area each frame.
            final a = (base.a * (0.8 + 0.2 * (0.5 + 0.5 * t))).clamp(0.0, 1.0);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      base.withValues(alpha: a),
                      base.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            );
          },
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
