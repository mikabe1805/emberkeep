import 'dart:async';
import 'dart:math' show pi, sin;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../platform/motion_stub.dart'
    if (dart.library.js_interop) '../platform/motion_web.dart';
import '../tokens.dart';
import 'facets.dart';
import 'gold_surface.dart';
import 'home_room.dart' show paintEmberFlame;

/// One calibrated motion source for the whole five-tab shell.
///
/// Native phones use accelerometer tilt. Browser phones use DeviceOrientation
/// (including Safari's gesture-gated permission path), while desktop web uses
/// pointer position. Camera and reflected light have separate response curves:
/// the room carries weight, while shine acknowledges movement immediately.
///
/// Input is coalesced to display frames and the camera notifier is capped near
/// 30fps. A phone tilt therefore cannot trigger redundant paints between
/// frames, and the expensive room never repaints at 60–120Hz just because the
/// light reflection can.
class LuxeMotionController {
  LuxeMotionController({this.reduceMotion = false});

  final ValueNotifier<Offset> parallax = ValueNotifier(Offset.zero);
  final ValueNotifier<Offset> light = ValueNotifier(Offset.zero);
  final BrowserMotionSource _browserMotion = BrowserMotionSource();
  StreamSubscription<AccelerometerEvent>? _motionSubscription;
  StreamSubscription<Offset>? _browserMotionSubscription;
  Offset _sensorRest = Offset.zero;
  Offset _sensorTarget = Offset.zero;
  Offset _pointerValue = Offset.zero;
  final LuxeMotionResponse _response = LuxeMotionResponse();
  var _sensorSamples = 0;
  var _pointerActive = false;
  var _frameScheduled = false;
  var _disposed = false;
  Duration? _lastCameraPublish;
  Duration? _lastLightPublish;
  bool reduceMotion;

  void setReduceMotion(bool value) {
    if (reduceMotion == value) return;
    reduceMotion = value;
    if (value) {
      _response.reset();
      parallax.value = Offset.zero;
      light.value = Offset.zero;
    } else {
      _scheduleFrame();
    }
  }

  Future<void> start() async {
    if (kIsWeb) {
      _browserMotionSubscription = _browserMotion.events.listen(
        _onBrowserTilt,
        onError: (_, _) {},
      );
      return;
    }

    try {
      await const MethodChannel(
        'dev.fluttercommunity.plus/sensors/method',
      ).invokeMethod<void>('setAccelerationSamplingPeriod', 33000);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
    try {
      _motionSubscription = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 33),
      ).listen(_onAccelerometer, onError: (_, _) {});
    } catch (_) {
      // Motion is an enhancement. Pointer and the still frame remain complete.
    }
  }

  void _onAccelerometer(AccelerometerEvent event) {
    if (reduceMotion) return;
    final reading = Offset(event.x, event.y);
    if (_sensorSamples < 14) {
      _sensorSamples++;
      _sensorRest = Offset.lerp(_sensorRest, reading, 1 / _sensorSamples)!;
      return;
    }
    _sensorTarget = Offset(
      ((reading.dx - _sensorRest.dx) / 3.4).clamp(-1.0, 1.0),
      (-(reading.dy - _sensorRest.dy) / 3.4).clamp(-1.0, 1.0),
    );
    _scheduleFrame();
  }

  void _onBrowserTilt(Offset target) {
    if (reduceMotion) return;
    _sensorTarget = target;
    _scheduleFrame();
  }

  void handlePointer(PointerHoverEvent event, Size size) {
    if (reduceMotion || size.isEmpty) return;
    _pointerActive = true;
    _pointerValue = Offset(
      ((event.localPosition.dx / size.width) * 2 - 1).clamp(-1.0, 1.0),
      ((event.localPosition.dy / size.height) * 2 - 1).clamp(-1.0, 1.0),
    );
    _scheduleFrame();
  }

  void clearPointer(PointerExitEvent _) {
    _pointerActive = false;
    _scheduleFrame();
  }

  /// Safari requires this call to begin inside a user gesture. The shell calls
  /// it on the first pointer-down; other browsers simply return true.
  Future<bool> requestBrowserMotionPermission() {
    if (reduceMotion) return Future.value(false);
    return _browserMotion.requestPermission();
  }

  void _scheduleFrame() {
    if (reduceMotion || _disposed || _frameScheduled) return;
    _frameScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback(_publishFrame);
  }

  void _publishFrame(Duration timestamp) {
    _frameScheduled = false;
    if (reduceMotion || _disposed) return;

    final target = _pointerActive ? _pointerValue : _sensorTarget;
    final values = _response.step(target);

    // The sensor itself arrives near 30 Hz, so publishing the interpolated
    // light faster than that only rebuilds every reactive gold/card layer with
    // values the hand cannot distinguish. Thirty clean updates leave the
    // raster thread room for touch, scrolling, and fire on native and web.
    final lastLight = _lastLightPublish;
    final lightDue =
        lastLight == null ||
        timestamp - lastLight >= const Duration(milliseconds: 33);
    if (lightDue && (light.value - values.light).distanceSquared >= 0.000010) {
      _lastLightPublish = timestamp;
      light.value = values.light;
    }

    // The authored room is the expensive plane. Thirty paint updates a second
    // are visually continuous at its small travel distance and leave enough
    // headroom for scrolling, blur, fire, and the active gold surface.
    final lastCamera = _lastCameraPublish;
    final cameraPeriod = kIsWeb
        ? const Duration(milliseconds: 41)
        : const Duration(milliseconds: 32);
    if (lastCamera == null || timestamp - lastCamera >= cameraPeriod) {
      _lastCameraPublish = timestamp;
      if ((parallax.value - values.camera).distanceSquared >= 0.000012) {
        parallax.value = values.camera;
      }
    }

    if ((values.light - target).distanceSquared >= 0.00005 ||
        (values.camera - target).distanceSquared >= 0.00008) {
      _scheduleFrame();
    }
  }

  void dispose() {
    _disposed = true;
    unawaited(_motionSubscription?.cancel());
    unawaited(_browserMotionSubscription?.cancel());
    _browserMotion.dispose();
    parallax.dispose();
    light.dispose();
  }
}

/// Two-speed response model kept separate so its feel can be regression-tested
/// without a physical sensor. Light catches up quickly; camera mass settles
/// more slowly but follows the exact same target.
@visibleForTesting
class LuxeMotionResponse {
  Offset camera = Offset.zero;
  Offset light = Offset.zero;

  ({Offset camera, Offset light}) step(Offset target) {
    camera = Offset.lerp(camera, target, 0.18)!;
    light = Offset.lerp(light, target, 0.46)!;
    return (camera: camera, light: light);
  }

  void reset() {
    camera = Offset.zero;
    light = Offset.zero;
  }
}

/// Shared cinematic page construction for Goals, Plans, and Journal.
///
/// The illustration is fixed. Content scrolls over it while the plate gathers
/// blur and warmth. The title remains in document flow so it never collides
/// with the dock or controls.
class LuxePageList extends StatefulWidget {
  const LuxePageList({
    super.key,
    required this.assetPath,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.parallax,
    required this.reduceMotion,
    required this.children,
    this.trailing,
    this.heroHeight = 250,
    this.heroAlignment = Alignment.center,
    this.fireFocal,
  });

  final String assetPath;
  final String title;
  final String subtitle;
  final IconData icon;
  final ValueListenable<Offset> parallax;
  final bool reduceMotion;
  final List<Widget> children;
  final Widget? trailing;
  final double heroHeight;
  final Alignment heroAlignment;

  /// Optional live fire tied to a verified firebox in the authored plate.
  ///
  /// Most page plates already contain their own candle/fire treatment. A
  /// guessed screen-space focal becomes a detached flame as the overscanned
  /// plate tilts and crops, so pages opt in only when a registered focal has
  /// been checked against the actual runtime crop.
  final Offset? fireFocal;

  @override
  State<LuxePageList> createState() => _LuxePageListState();
}

/// The same fixed-scene/scrolling-glass construction as [LuxePageList], but
/// with a live authored widget (the player's actual room) as its hero.
class LuxeCustomPageList extends StatefulWidget {
  const LuxeCustomPageList({
    super.key,
    required this.hero,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.reduceMotion,
    required this.children,
    this.trailing,
    this.heroHeight = 275,
  });

  final Widget hero;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool reduceMotion;
  final List<Widget> children;
  final Widget? trailing;
  final double heroHeight;

  @override
  State<LuxeCustomPageList> createState() => _LuxeCustomPageListState();
}

class _LuxeCustomPageListState extends State<LuxeCustomPageList> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF100D0B)),
        Positioned(
          top: 0,
          left: -12,
          right: -12,
          height: widget.heroHeight + 18,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _scroll,
              child: widget.hero,
              builder: (context, hero) {
                final scroll = _scroll.hasClients
                    ? _scroll.offset.clamp(0.0, 240.0)
                    : 0.0;
                return Transform.translate(
                  offset: Offset(0, -scroll * 0.075),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(child: hero),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x10000000),
                              Color(0x00000000),
                              Color(0x3A100D0B),
                              Color(0xF8100D0B),
                            ],
                            stops: [0, 0.55, 0.80, 1],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        _LuxeScrollVeil(controller: _scroll, height: widget.heroHeight + 16),
        ListView(
          controller: _scroll,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
          children: [
            SizedBox(height: widget.heroHeight - 64),
            _LuxePageHeading(
              title: widget.title,
              subtitle: widget.subtitle,
              icon: widget.icon,
              trailing: widget.trailing,
            ),
            const SizedBox(height: 18),
            ...widget.children,
          ],
        ),
      ],
    );
  }
}

class _LuxePageListState extends State<LuxePageList> {
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _scrollPosition = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_trackScroll);
  }

  void _trackScroll() {
    if (!_scroll.hasClients) return;
    final next = _scroll.offset;
    if ((_scrollPosition.value - next).abs() >= 0.75) {
      _scrollPosition.value = next;
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_trackScroll);
    _scroll.dispose();
    _scrollPosition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still =
        widget.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF100D0B)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: widget.heroHeight + 24,
          child: _LuxeHeroPlate(
            assetPath: widget.assetPath,
            alignment: widget.heroAlignment,
            parallax: widget.parallax,
            scrollPosition: _scrollPosition,
            still: still,
            fireFocal: widget.fireFocal,
          ),
        ),
        _LuxeScrollVeil(controller: _scroll, height: widget.heroHeight + 20),
        ListView(
          controller: _scroll,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
          children: [
            SizedBox(height: widget.heroHeight - 66),
            _LuxePageHeading(
              title: widget.title,
              subtitle: widget.subtitle,
              icon: widget.icon,
              trailing: widget.trailing,
            ),
            const SizedBox(height: 18),
            ...widget.children,
          ],
        ),
      ],
    );
  }
}

class _LuxeHeroPlate extends StatelessWidget {
  const _LuxeHeroPlate({
    required this.assetPath,
    required this.alignment,
    required this.parallax,
    required this.scrollPosition,
    required this.still,
    required this.fireFocal,
  });

  final String assetPath;
  final Alignment alignment;
  final ValueListenable<Offset> parallax;
  final ValueListenable<double> scrollPosition;
  final bool still;
  final Offset? fireFocal;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: Listenable.merge([parallax, scrollPosition]),
        builder: (context, _) {
          final tilt = still ? Offset.zero : parallax.value;
          final scroll = scrollPosition.value.clamp(0.0, 260.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              Transform.translate(
                offset: Offset(-tilt.dx * 13.5, -tilt.dy * 8.5 - scroll * 0.09),
                child: Transform.scale(
                  scale: 1.115,
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.cover,
                    alignment: alignment,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              if (fireFocal case final focal?)
                _HeroFireLife(
                  key: const ValueKey('luxe-hero-fire'),
                  focal: focal,
                  still: still,
                ),
              // A source-aware light plane: tiny movement in the opposite
              // direction makes the glass feel above the painted environment.
              Transform.translate(
                offset: Offset(tilt.dx * 3.0, tilt.dy * 2.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(
                        0.52 + tilt.dx * 0.06,
                        -0.35 + tilt.dy * 0.04,
                      ),
                      radius: 0.9,
                      colors: const [Color(0x14FFD895), Color(0x00170F0A)],
                    ),
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x12000000),
                      Color(0x00000000),
                      Color(0x2A100D0B),
                      Color(0xF0100D0B),
                    ],
                    stops: [0, 0.55, 0.78, 1],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroFireLife extends StatefulWidget {
  const _HeroFireLife({super.key, required this.focal, required this.still});

  final Offset focal;
  final bool still;

  @override
  State<_HeroFireLife> createState() => _HeroFireLifeState();
}

class _HeroFireLifeState extends State<_HeroFireLife>
    with SingleTickerProviderStateMixin {
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.still) _life.repeat();
  }

  @override
  void didUpdateWidget(_HeroFireLife oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.still && !oldWidget.still) {
      _life.stop();
    } else if (!widget.still && oldWidget.still) {
      _life.repeat();
    }
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _life,
          builder: (context, _) => CustomPaint(
            painter: _HeroFirePainter(
              focal: widget.focal,
              t: widget.still ? 0.0 : (_life.value * 96).round() / 96,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroFirePainter extends CustomPainter {
  const _HeroFirePainter({required this.focal, required this.t});

  final Offset focal;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final at = Offset(size.width * focal.dx, size.height * focal.dy);
    final breath = 0.72 + 0.18 * sin(t * pi * 4) + 0.10 * sin(t * pi * 6 + 0.7);
    final glow = const Color(0xFFF29A43);
    final radius = size.width * 0.105;
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            glow.withValues(alpha: 0.075 * breath),
            glow.withValues(alpha: 0.020 * breath),
            glow.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: at, radius: radius)),
    );

    final flame = Rect.fromCenter(
      center: at.translate(0, size.height * 0.025),
      width: size.width * 0.052,
      height: size.height * (0.12 + 0.008 * breath),
    );
    canvas.saveLayer(
      flame.inflate(size.width * 0.018),
      Paint()..blendMode = BlendMode.screen,
    );
    paintEmberFlame(
      canvas,
      flame,
      glow,
      lean: sin(t * pi * 4.8) * size.width * 0.004,
      intensity: 0.12 * breath,
    );
    canvas.restore();

    for (var i = 0; i < 4; i++) {
      final cycle = (t * (0.62 + i * 0.08) + i * 0.23) % 1.0;
      final rise = Curves.easeOutCubic.transform(cycle);
      final point = Offset(
        at.dx + sin(cycle * pi * 2 + i) * size.width * 0.008,
        at.dy - size.height * (0.04 + rise * (0.12 + i * 0.01)),
      );
      final alpha = sin(cycle * pi).abs() * 0.58;
      canvas.drawCircle(
        point,
        size.width * 0.0016,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = const Color(0xFFFFE3A0).withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_HeroFirePainter old) => old.focal != focal || old.t != t;
}

/// Supporting pages use an authored soft-focus plate already. A progressive
/// warm veil creates the same foreground separation without asking the GPU to
/// resample a large BackdropFilter on every scroll frame. The Quest board,
/// where the blur transition is a signature interaction, uses its dedicated
/// pre-softened registered room instead.
class _LuxeScrollVeil extends StatelessWidget {
  const _LuxeScrollVeil({required this.controller, required this.height});

  final ScrollController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final offset = controller.hasClients
            ? controller.offset.clamp(0.0, 230.0)
            : 0.0;
        final strength = Curves.easeOutCubic.transform(offset / 230);
        if (strength <= 0.001) return const SizedBox.shrink();
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: height,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1D120C).withValues(alpha: 0.05 * strength),
                    const Color(0xFF1A100B).withValues(alpha: 0.22 * strength),
                    const Color(0xFF100D0B).withValues(alpha: 0.60 * strength),
                  ],
                  stops: const [0, 0.62, 1],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LuxePageHeading extends StatelessWidget {
  const _LuxePageHeading({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FacetMedallion(
          size: 46,
          accent: Palette.xp,
          glow: true,
          child: Icon(icon, size: 23, color: Palette.xpLight),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: Type.display.copyWith(
                  fontSize: 32,
                  height: 0.96,
                  letterSpacing: 1.2,
                  color: Palette.textHi,
                  shadows: const [
                    Shadow(
                      color: Color(0xB0000000),
                      blurRadius: 12,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Type.body.copyWith(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Palette.textLo,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

/// A page-level gold action using the same generated honey material as the
/// approved Quest CTA. The broad reflection follows tilt; it never twinkles.
class LuxeGoldButton extends StatelessWidget {
  const LuxeGoldButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.parallax,
    this.height = 58,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final ValueListenable<Offset> parallax;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: GoldSurface(
            cut: 12,
            light: parallax,
            child: GoldLabel(
              text: label.toUpperCase(),
              icon: icon,
              fontSize: 13,
              letterSpacing: 1.8,
            ),
          ),
        ),
      ),
    );
  }
}
