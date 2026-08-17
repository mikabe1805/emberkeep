import 'dart:async';
import 'dart:math' show pi, sin;

import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/material.dart';

import 'living_hearth_fire.dart';

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
  static const fireAssets = hearthFireAssets;
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
    final roomMotion = kIsWeb
        ? widget.parallax
        : Listenable.merge([widget.parallax, widget.scrollPosition]);
    return ClipRect(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: roomMotion,
          child: _QuestLivingFire(
            hue: widget.flameHue,
            lively: widget.lively,
            scrollPosition: widget.scrollPosition,
          ),
          builder: (context, fire) {
            final tilt = widget.lively ? widget.parallax.value : Offset.zero;
            // Reduce Motion means the room is a parked illustration. Scrolling
            // content remains usable, but it must not counter-slide the room
            // behind it: that is still motion from the person's point of view.
            // On the browser, scrolling keeps ownership of the frame. The
            // authored room stays parked while the soft plate and card sheen
            // provide the depth response; native retains the tiny plane travel.
            final scroll = widget.lively && !kIsWeb
                ? widget.scrollPosition.value.clamp(0.0, 240.0).toDouble() /
                      240.0
                : 0.0;

            // The planes separate enough that an ordinary one-handed tilt
            // reads immediately as depth. Architecture and the registered
            // fire stay weighty; furniture and the near chair travel farther.
            // Scroll keeps its quieter counter-motion beneath the board.
            final far = Offset(-tilt.dx * 3.0, -tilt.dy * 2.0 - scroll * 1.0);
            final wall = Offset(-tilt.dx * 7.2, -tilt.dy * 4.6 - scroll * 2.0);
            final furniture = Offset(
              -tilt.dx * 14.0,
              -tilt.dy * 8.3 - scroll * 3.8,
            );
            final foreground = Offset(
              -tilt.dx * 24.0,
              -tilt.dy * 13.5 - scroll * 6.2,
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
        child: Transform.scale(scale: 1.08, child: child),
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
  const _QuestLivingFire({
    required this.hue,
    required this.lively,
    required this.scrollPosition,
  });

  final Color hue;
  final bool lively;
  final ValueListenable<double> scrollPosition;

  @override
  State<_QuestLivingFire> createState() => _QuestLivingFireState();
}

class _QuestLivingFireState extends State<_QuestLivingFire>
    with SingleTickerProviderStateMixin {
  AnimationController? _life;
  Timer? _webTimer;
  var _webFrame = 0;
  var _tickerModeEnabled = true;
  final ValueNotifier<double> _paintPhase = ValueNotifier(0);
  static const _nativePaintFramesPerLoop = 9 * 20;
  static const _webPaintFramesPerLoop = 9 * 8;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _life = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 9),
      )..addListener(_publishFireFrame);
    }
    widget.scrollPosition.addListener(_syncLife);
    _syncLife();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerModeEnabled = TickerMode.valuesOf(context).enabled;
    _syncLife();
  }

  void _publishFireFrame() {
    // The raster blend and full-room glow are the expensive part of the living
    // source. Native keeps twenty authored updates per second. Browser phones
    // use eight: two blended transparent rasters at 24 fps consumed
    // the frame budget that scroll and tilt needed, while the flame's tiny
    // travel remains naturally fluid at this scale.
    final life = _life;
    if (life == null) return;
    final snapped =
        (life.value * _nativePaintFramesPerLoop).floor() /
        _nativePaintFramesPerLoop;
    if (snapped != _paintPhase.value) _paintPhase.value = snapped;
  }

  void _publishWebFrame(Timer _) {
    _webFrame = (_webFrame + 1) % _webPaintFramesPerLoop;
    _paintPhase.value = _webFrame / _webPaintFramesPerLoop;
  }

  @override
  void didUpdateWidget(_QuestLivingFire oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollPosition != widget.scrollPosition) {
      oldWidget.scrollPosition.removeListener(_syncLife);
      widget.scrollPosition.addListener(_syncLife);
    }
    if (widget.lively != oldWidget.lively) _syncLife();
  }

  void _syncLife() {
    // Once the browser board leaves its resting top, the softened environment
    // already obscures the flame. Parking it there prevents an off-focus fire
    // repaint from stealing the same frames as touch/scroll.
    final shouldLive =
        widget.lively &&
        _tickerModeEnabled &&
        (!kIsWeb || widget.scrollPosition.value <= 1.0);
    if (kIsWeb) {
      if (shouldLive) {
        _webTimer ??= Timer.periodic(
          const Duration(milliseconds: 125),
          _publishWebFrame,
        );
      } else {
        _webTimer?.cancel();
        _webTimer = null;
        _webFrame = 0;
        if (_paintPhase.value != 0) _paintPhase.value = 0;
      }
      return;
    }
    final life = _life!;
    if (shouldLive) {
      if (!life.isAnimating) life.repeat();
    } else {
      if (life.isAnimating || life.value != 0) {
        life.stop();
        life.value = 0;
      }
      if (_paintPhase.value != 0) _paintPhase.value = 0;
    }
  }

  @override
  void dispose() {
    widget.scrollPosition.removeListener(_syncLife);
    _webTimer?.cancel();
    _life?.removeListener(_publishFireFrame);
    _life?.dispose();
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
            final frame = hearthFireFrameAt(t);
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
                                RecoloredHearthFireFrame(
                                  asset:
                                      QuestDepthRoom.fireAssets[frame.current],
                                  hue: widget.hue,
                                  opacity: 1 - frame.blend,
                                ),
                                RecoloredHearthFireFrame(
                                  asset: QuestDepthRoom.fireAssets[frame.next],
                                  hue: widget.hue,
                                  opacity: frame.blend,
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
