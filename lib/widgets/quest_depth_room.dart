import 'dart:async';
import 'dart:math' show pi, sin;

import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/material.dart';

/// The Quest board's authored room, rebuilt as a true multi-plane painting.
///
/// Every raster was generated against one registered camera. Nothing here
/// samples or cuts pixels from the finished composition: the far architecture
/// contains the real wall behind the furniture, and each nearer plane has its
/// own transparent artwork. Tiny differential travel can therefore reveal
/// depth without exposing the window/chair seams that made the old effect feel
/// like sliced cardboard.
class QuestDepthRoom extends StatefulWidget {
  const QuestDepthRoom({
    super.key,
    required this.parallax,
    required this.scrollPosition,
    required this.flameHue,
    required this.lively,
  });

  static const baseAsset = 'assets/rooms/quest-depth-base-v2.webp';
  static const wallAsset = 'assets/rooms/quest-depth-wall-v4.png';
  static const furnitureAsset = 'assets/rooms/quest-depth-furniture-v1.png';
  static const foregroundAsset = 'assets/rooms/quest-depth-foreground-v1.png';
  static const scrollSoftAsset = 'assets/rooms/quest-depth-scroll-soft-v1.webp';
  static const fireAssets = <String>[
    'assets/rooms/quest-fire-a-v3.png',
    'assets/rooms/quest-fire-b-v3.png',
    'assets/rooms/quest-fire-c-v3.png',
  ];
  static const assets = <String>[
    baseAsset,
    wallAsset,
    furnitureAsset,
    foregroundAsset,
    scrollSoftAsset,
    ...fireAssets,
  ];

  final ValueListenable<Offset> parallax;
  final ValueListenable<double> scrollPosition;
  final Color flameHue;
  final bool lively;

  @override
  State<QuestDepthRoom> createState() => _QuestDepthRoomState();
}

class _QuestDepthRoomState extends State<QuestDepthRoom> {
  var _precacheStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precacheStarted) return;
    _precacheStarted = true;
    for (final asset in QuestDepthRoom.assets) {
      unawaited(precacheImage(AssetImage(asset), context));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([widget.parallax, widget.scrollPosition]),
          child: _QuestLivingFire(hue: widget.flameHue, lively: widget.lively),
          builder: (context, fire) {
            final tilt = widget.lively ? widget.parallax.value : Offset.zero;
            final scroll =
                widget.scrollPosition.value.clamp(0.0, 240.0).toDouble() /
                240.0;

            // The room never travels more than a handful of pixels. Near
            // silhouettes move most; architecture and the firebox barely move.
            // Scroll adds a quieter vertical counter-motion beneath the board.
            final far = Offset(-tilt.dx * 1.6, -tilt.dy * 1.1 - scroll * 1.0);
            final wall = Offset(-tilt.dx * 3.2, -tilt.dy * 2.1 - scroll * 2.0);
            final furniture = Offset(
              -tilt.dx * 5.7,
              -tilt.dy * 3.6 - scroll * 3.8,
            );
            final foreground = Offset(
              -tilt.dx * 8.6,
              -tilt.dy * 5.3 - scroll * 6.2,
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                _DepthPlane(
                  offset: far,
                  motionKey: const ValueKey('quest-depth-far-plane'),
                  child: const _RoomRaster(
                    QuestDepthRoom.baseAsset,
                    opaque: true,
                  ),
                ),
                // Fire belongs inside the architectural firebox, so its
                // independent life follows the far plane rather than drifting
                // with furniture.
                _DepthPlane(offset: far, child: fire!),
                _DepthPlane(
                  offset: wall,
                  motionKey: const ValueKey('quest-depth-wall-plane'),
                  child: const _RoomRaster(QuestDepthRoom.wallAsset),
                ),
                _DepthPlane(
                  offset: furniture,
                  motionKey: const ValueKey('quest-depth-furniture-plane'),
                  child: const _RoomRaster(QuestDepthRoom.furnitureAsset),
                ),
                _DepthPlane(
                  offset: foreground,
                  motionKey: const ValueKey('quest-depth-foreground-plane'),
                  child: const _RoomRaster(QuestDepthRoom.foregroundAsset),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DepthPlane extends StatelessWidget {
  const _DepthPlane({
    required this.offset,
    required this.child,
    this.motionKey,
  });

  final Offset offset;
  final Widget child;
  final Key? motionKey;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Transform.translate(
        key: motionKey,
        offset: offset,
        child: Transform.scale(scale: 1.055, child: child),
      ),
    );
  }
}

class _RoomRaster extends StatelessWidget {
  const _RoomRaster(this.asset, {this.opaque = false});

  final String asset;
  final bool opaque;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: AssetImage(asset),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      isAntiAlias: !opaque,
    );
  }
}

/// A separate low-frequency loop keeps the room alive even while the phone is
/// perfectly still. It is intentionally fire, not sparkle: a breathing glow,
/// moving tongues rooted to the fuel line, and a few natural embers.
class _QuestLivingFire extends StatefulWidget {
  const _QuestLivingFire({required this.hue, required this.lively});

  final Color hue;
  final bool lively;

  @override
  State<_QuestLivingFire> createState() => _QuestLivingFireState();
}

class _QuestLivingFireState extends State<_QuestLivingFire>
    with SingleTickerProviderStateMixin {
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );
  final ValueNotifier<double> _paintPhase = ValueNotifier(0);
  static final _paintFramesPerLoop = 9 * (kIsWeb ? 12 : 20);

  @override
  void initState() {
    super.initState();
    _life.addListener(_publishFireFrame);
    _syncLife();
  }

  void _publishFireFrame() {
    // The raster blend and full-room glow are the expensive part of the living
    // source. Native keeps twenty authored updates per second. Browser phones
    // use twelve: two blended transparent rasters at 24 fps consumed
    // the frame budget that scroll and tilt needed, while the flame's tiny
    // travel remains naturally fluid at this scale.
    final snapped =
        (_life.value * _paintFramesPerLoop).floor() / _paintFramesPerLoop;
    if (snapped != _paintPhase.value) _paintPhase.value = snapped;
  }

  @override
  void didUpdateWidget(_QuestLivingFire oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lively != oldWidget.lively) _syncLife();
  }

  void _syncLife() {
    if (widget.lively) {
      if (!_life.isAnimating) _life.repeat();
    } else {
      _life.stop();
      _life.value = 0;
      _paintPhase.value = 0;
    }
  }

  @override
  void dispose() {
    _life.removeListener(_publishFireFrame);
    _life.dispose();
    _paintPhase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _paintPhase,
          builder: (context, _) {
            final t = widget.lively ? _paintPhase.value : 0.0;
            final framePhase = t * 18;
            final currentFrame =
                framePhase.floor() % QuestDepthRoom.fireAssets.length;
            final nextFrame =
                (currentFrame + 1) % QuestDepthRoom.fireAssets.length;
            final blend = Curves.easeInOutSine.transform(framePhase % 1);
            final sway = sin(t * pi * 8) * 1.7 + sin(t * pi * 14 + 0.8) * 0.7;
            final lift = sin(t * pi * 12 + 0.35) * 0.9;
            final breathe = 0.994 + sin(t * pi * 6 + 0.2) * 0.006;

            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  key: const ValueKey('quest-depth-fire'),
                  painter: _QuestFirePainter(t: t, hue: widget.hue),
                ),
                FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: 1635,
                    height: 962,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 1290 + sway,
                          top: 470 + lift,
                          width: 320,
                          height: 300,
                          child: Transform.scale(
                            alignment: Alignment.bottomCenter,
                            scaleX: 1 / breathe,
                            scaleY: breathe,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _FireFrame(
                                  asset:
                                      QuestDepthRoom.fireAssets[currentFrame],
                                  opacity: 1 - blend,
                                ),
                                _FireFrame(
                                  asset: QuestDepthRoom.fireAssets[nextFrame],
                                  opacity: blend,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FireFrame extends StatelessWidget {
  const _FireFrame({required this.asset, required this.opacity});

  final String asset;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image(
        image: AssetImage(asset),
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        isAntiAlias: true,
      ),
    );
  }
}

class _QuestFirePainter extends CustomPainter {
  const _QuestFirePainter({required this.t, required this.hue});

  final double t;
  final Color hue;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fuel = Offset(w * 0.886, h * 0.758);
    final breath =
        0.86 + 0.08 * sin(t * pi * 6) + 0.04 * sin(t * pi * 10 + 0.9);
    final glowAt = fuel.translate(0, -h * 0.075);
    final glowRadius = w * 0.18;

    canvas.drawCircle(
      glowAt,
      glowRadius,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            hue.withValues(alpha: 0.070 * breath),
            hue.withValues(alpha: 0.026 * breath),
            hue.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: glowAt, radius: glowRadius)),
    );

    // One long, low reflection makes the fire belong to the floorboards.
    final reflection = Path()
      ..moveTo(fuel.dx - w * 0.035, fuel.dy)
      ..lineTo(fuel.dx + w * 0.035, fuel.dy)
      ..lineTo(w * 0.99, h)
      ..lineTo(w * 0.59, h)
      ..close();
    canvas.drawPath(
      reflection,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            hue.withValues(alpha: 0.040 * breath),
            hue.withValues(alpha: 0.011 * breath),
            hue.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(fuel.dx, fuel.dy, w - fuel.dx, h)),
    );

    for (var i = 0; i < 3; i++) {
      final cycle = (t * (0.64 + i * 0.06) + i * 0.31) % 1.0;
      final rise = Curves.easeOutCubic.transform(cycle);
      final alpha = sin(cycle * pi).abs() * (i.isEven ? 0.34 : 0.22);
      final point = Offset(
        fuel.dx + sin(cycle * pi * 2 + i * 1.6) * w * 0.008,
        fuel.dy - h * (0.08 + rise * (0.11 + i * 0.006)),
      );
      canvas.drawCircle(
        point,
        w * (i.isEven ? 0.0018 : 0.0013),
        Paint()
          ..blendMode = BlendMode.plus
          ..color = Color.lerp(
            hue,
            const Color(0xFFFFF0C0),
            0.76,
          )!.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_QuestFirePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.hue != hue;
}
