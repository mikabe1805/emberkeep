import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../content/themes.dart';
import '../tokens.dart';
import 'facets.dart';

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
    final cut = radius >= 100 ? 14.0 : (radius * 0.58).clamp(7.0, 15.0);
    final panel = DecoratedBox(
      decoration: facetedDecoration(
        color: tint,
        gradient: tint == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(Palette.glassTop, const Color(0xEF181210)),
                  Color.alphaBlend(
                    Palette.glassBottom,
                    const Color(0xF617110E),
                  ),
                ],
              )
            : null,
        cut: cut,
        shadows: [
          const BoxShadow(
            color: Palette.warmShadow,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
          if (glow)
            const BoxShadow(
              color: Palette.honeyGlow,
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
    return ClipPath(
      clipper: FacetedClipper(cut: cut),
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
          Positioned.fill(child: FacetGleam(cut: cut, strength: 0.52)),
        ],
      ),
    );
  }
}

/// The candlelit desk: deep espresso→plum-dusk gradient, soft glowing color
/// pools, and drifting firefly motes — the night is alive but never busy.
class WarmBackground extends StatelessWidget {
  const WarmBackground({
    super.key,
    required this.child,
    this.themeId,
    this.tint,
    this.reduceMotion = false,
  });
  final Widget child;

  /// The active canvas theme id (null → default Walnut Night). Resolved here
  /// so callers only pass a string.
  final String? themeId;

  /// Optional colour to lean the glow pools toward — a domain's "base" page
  /// uses its own hue so each of the six feels like a different room of a life
  /// (round-25), not the same template recoloured by one accent.
  final Color? tint;

  /// When true (or OS reduce-motion is on), fireflies freeze — ambience
  /// without continuous animation (DESIGN.md accessibility).
  final bool reduceMotion;

  Color _glow(Color base) =>
      tint == null ? base : Color.lerp(base, tint, 0.42)!;

  @override
  Widget build(BuildContext context) {
    final theme = canvasThemeById(themeId);
    final still =
        reduceMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return AnimatedContainer(
      duration: still ? Duration.zero : const Duration(milliseconds: 600),
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
          // (static; the drifting fireflies carry the motion, cheaply).
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _AmbientPlanesPainter(
                  top: theme.top,
                  bottom: theme.bottom,
                  accent: tint ?? theme.glows.first,
                ),
              ),
            ),
          ),
          Positioned(
            top: -70,
            left: -60,
            child: _Glow(color: _glow(theme.glows[0]), size: 320, phase: 0.0),
          ),
          Positioned(
            top: 200,
            right: -90,
            child: _Glow(color: _glow(theme.glows[1]), size: 280, phase: 0.35),
          ),
          Positioned(
            bottom: 40,
            left: -50,
            child: _Glow(color: _glow(theme.glows[2]), size: 260, phase: 0.6),
          ),
          Positioned(
            bottom: 240,
            right: 30,
            child: _Glow(color: _glow(theme.glows[3]), size: 180, phase: 0.85),
          ),
          Positioned.fill(child: _Fireflies(still: still)),
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

/// A static warm light-pool. Deliberately NOT animated: the drifting fireflies
/// carry the ambient motion, and four per-frame breathing controllers per
/// WarmBackground (× every pushed route) made navigation feel laggy on real
/// devices (round-39 perf pass — owner feedback). The [phase] is now unused but
/// kept so call sites don't churn.
class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size, this.phase = 0});
  final Color color;
  final double size;
  final double phase;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipPath(
        clipper: FacetedClipper(cut: size * 0.16),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.25, -0.2),
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmbientPlanesPainter extends CustomPainter {
  const _AmbientPlanesPainter({
    required this.top,
    required this.bottom,
    required this.accent,
  });

  final Color top;
  final Color bottom;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    // Three light planes, each fading along its own length. They used to be
    // flat-filled polygons at 8–14% alpha across the whole viewport, which read
    // as hard-edged shafts terminating in mid-air — the same seam three
    // separate screen audits reported at roughly x = 0.5 of the canvas. A plane
    // with a falloff still gives the canvas construction, but it has somewhere
    // for the light to go.
    void plane(Path path, Rect bounds, Color tone, double alpha) {
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tone.withValues(alpha: alpha),
              tone.withValues(alpha: alpha * 0.35),
              tone.withValues(alpha: 0),
            ],
            stops: const [0, 0.55, 1],
          ).createShader(bounds),
      );
    }

    plane(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width * 0.62, 0)
        ..lineTo(size.width * 0.28, size.height * 0.46)
        ..lineTo(0, size.height * 0.34)
        ..close(),
      Rect.fromLTWH(0, 0, size.width * 0.62, size.height * 0.46),
      Color.lerp(top, accent, 0.35)!,
      0.11,
    );

    plane(
      Path()
        ..moveTo(size.width, size.height * 0.12)
        ..lineTo(size.width, size.height * 0.72)
        ..lineTo(size.width * 0.58, size.height * 0.45)
        ..lineTo(size.width * 0.78, size.height * 0.08)
        ..close(),
      Rect.fromLTWH(
        size.width,
        size.height * 0.08,
        -size.width * 0.42,
        size.height * 0.64,
      ),
      Color.lerp(bottom, accent, 0.24)!,
      0.09,
    );

    final floorRect = Rect.fromLTWH(
      0,
      size.height * 0.78,
      size.width,
      size.height * 0.22,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width * 0.64, size.height * 0.78)
        ..lineTo(size.width * 0.22, size.height * 0.86)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Palette.warmShadow.withValues(alpha: 0.16),
            Palette.warmShadow.withValues(alpha: 0),
          ],
        ).createShader(floorRect),
    );
  }

  @override
  bool shouldRepaint(_AmbientPlanesPainter old) =>
      old.top != top || old.bottom != bottom || old.accent != accent;
}

/// Drifting, twinkling motes of warm light. One repaint-bounded layer,
/// quantized to ~12 fps — ambience, not a particle storm.
class _Fireflies extends StatefulWidget {
  const _Fireflies({this.still = false});
  final bool still;

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
  static const _count = 8;
  late final List<_Mote> _motes;
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    final rng = Random(7);
    _motes = List.generate(_count, (_) => _Mote(rng));
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    );
    if (!widget.still) _c.repeat();
  }

  @override
  void didUpdateWidget(_Fireflies old) {
    super.didUpdateWidget(old);
    if (widget.still && !old.still) {
      _c.stop();
    } else if (!widget.still && old.still) {
      _c.repeat();
    }
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
            // Twelve paints a second is ample for minute-long drift. The old
            // 20 fps field spent battery under every scroll for motion almost
            // nobody could consciously see.
            painter: _MotePainter(
              motes: _motes,
              t: widget.still ? 0.15 : (_c.value * 720).round() / 720,
            ),
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
          0.25 +
          0.75 * (0.5 + 0.5 * sin(2 * pi * (t * 60 * m.twinkle / 8 + m.phase)));
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
