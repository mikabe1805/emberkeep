import 'dart:async';
import 'dart:math' show max, pi, sin;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../audio.dart';
import '../tokens.dart';
import 'facets.dart';
import 'glass.dart';
import 'lamplight.dart';
import 'luxe_depth.dart';
import 'pressable.dart';

enum RoutineTime { night, morning }

/// The live page and its scroll stage must agree on this geometry. The night
/// receipt grows with Extra Credit and with tomorrow's classes (more at
/// accessibility text sizes), so a fixed stage would strand the reflection
/// action below the scroll extent.
class _RoutineLedgerPageGeometry {
  const _RoutineLedgerPageGeometry({
    required this.width,
    required this.folioHeight,
    required this.claspHeight,
    required this.claspTop,
    required this.secondaryTop,
    required this.totalHeight,
  });

  final double width;
  final double folioHeight;
  final double claspHeight;
  final double claspTop;
  final double secondaryTop;
  final double totalHeight;
}

_RoutineLedgerPageGeometry _routineLedgerPageGeometry({
  required double viewportWidth,
  required double textScale,
  required RoutineTime time,
  required double extraPageHeight,
  required bool hasSecondaryAction,
}) {
  final narrow = viewportWidth < 360;
  final accessibilityPhone = narrow && textScale >= 1.75;
  final width = (viewportWidth * 1.22).clamp(410.0, 560.0);
  // The two bookends are visits to the same desk, so their occupied frame is
  // deliberately shared even though the morning source plate contains a
  // taller transparent/page-stack crop. Drawing that crop at its raw aspect
  // made dawn feel like a different, lower camera and pushed its clasp well
  // below the night composition.
  //
  // The places that give way are accessibility text sizes (and a narrow
  // phone), where the page genuinely cannot hold the day at a legible size.
  // There the book stretches rather than the type shrinking: the trade the
  // routine_ledger_visual_test guards, and the right one, since a slightly
  // long book beats a day you cannot read. A full-width phone lengthens its
  // book the same way as the text grows past 115% (the narrow phone's long
  // book by 175%); at a fixed 1.034 its receipt ran past the folio. A page
  // with more live content asks for [extraPageHeight] of paper the same
  // way, scaled with the text.
  final aspect = narrow
      ? (accessibilityPhone ? 2.45 : 1.84)
      : 1.034 + (1.84 - 1.034) * ((textScale - 1.15) / 0.6).clamp(0.0, 1.0);
  final folioHeight =
      width * aspect + extraPageHeight * textScale.clamp(1.0, 2.0);
  // The clasp plate is its own photograph too (1983x498, h/w 0.251), so its
  // height follows its width rather than a hand-set clamp. It sits ON the
  // cover: before this it began at 0.915 of the folio and ran past the
  // book's own bottom edge (0.93), so a solid brass plate was half mounted on
  // leather and half floating in the room.
  const claspAspect = 498 / 1983;
  final claspWidth = width * (1 - _claspInset * 2);
  final claspHeight = claspWidth * claspAspect;
  // Where the plate's lower edge lands, as a fraction of the folio: just
  // inside the leather in both books (night's cover ends at ~0.93, the
  // morning folio's page block at ~0.955).
  final morning = time == RoutineTime.morning;
  final claspTop = folioHeight * (morning ? 0.945 : 0.905) - claspHeight;
  final objectBottom = max(folioHeight, claspTop + claspHeight);
  final secondaryTop = objectBottom + 14;
  return _RoutineLedgerPageGeometry(
    width: width,
    folioHeight: folioHeight,
    claspHeight: claspHeight,
    claspTop: claspTop,
    secondaryTop: secondaryTop,
    totalHeight: hasSecondaryAction ? secondaryTop + 42 : objectBottom,
  );
}

const _claspInset = 0.24;

/// The ledger has its own printed voice. EB Garamond keeps live quest text
/// feeling letterpressed into the folio instead of laid over it by a modern
/// interface, while the app's compact mono remains available for dates and
/// mechanical metadata.
abstract final class LedgerType {
  static const display = TextStyle(
    fontFamily: 'EBGaramond',
    fontWeight: FontWeight.w600,
    height: 0.98,
    letterSpacing: 0.1,
  );

  static const body = TextStyle(
    fontFamily: 'EBGaramond',
    fontWeight: FontWeight.w500,
    height: 1.16,
  );

  static const smallCaps = TextStyle(
    fontFamily: 'EBGaramond',
    fontWeight: FontWeight.w600,
    height: 1,
    letterSpacing: 1.7,
  );

  static const button = TextStyle(
    fontFamily: 'EBGaramond',
    fontWeight: FontWeight.w600,
    height: 1,
    letterSpacing: 2.0,
  );
}

typedef RoutineLedgerBuilder =
    Widget Function(
      BuildContext context,
      ValueListenable<Offset> parallax,
      ValueListenable<Offset> light,
      ValueListenable<double> scroll,
      Animation<double> entrance,
    );

/// The shared room for the two daily bookends.
///
/// The night and morning plates are the exact same camera at two times of day.
/// The room carries slow, weighty tilt; the ledger rides a nearer plane; and
/// the existing three-frame painted fire stays alive while the phone is still.
class RoutineLedgerScaffold extends StatefulWidget {
  const RoutineLedgerScaffold({
    super.key,
    required this.time,
    required this.title,
    required this.dateLabel,
    required this.dismissLabel,
    required this.onDismiss,
    required this.reduceMotion,
    required this.builder,
    required this.scrollKey,
    this.pageExtraHeight = 0,
  });

  final RoutineTime time;
  final String title;
  final String dateLabel;
  final String dismissLabel;
  final VoidCallback onDismiss;
  final bool reduceMotion;
  final RoutineLedgerBuilder builder;
  final Key scrollKey;

  /// The [RoutineLedgerPage.extraPageHeight] the builder's page asks for, so
  /// the scroll stage always reaches the page's real end.
  final double pageExtraHeight;

  @override
  State<RoutineLedgerScaffold> createState() => _RoutineLedgerScaffoldState();
}

class _RoutineLedgerScaffoldState extends State<RoutineLedgerScaffold>
    with TickerProviderStateMixin {
  late final LuxeMotionController _motion = LuxeMotionController(
    reduceMotion: widget.reduceMotion,
  );
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _entranceCurve = CurvedAnimation(
    parent: _entrance,
    curve: const Cubic(0.18, 0.82, 0.20, 1),
  );
  late final AnimationController _fire = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5400),
  );
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _scrollPosition = ValueNotifier(0);
  final ValueNotifier<double> _firePhase = ValueNotifier(0.18);
  Timer? _webFireTimer;
  var _webFireFrame = (0.18 * 54).round();
  var _tickerModeEnabled = true;
  static const _fireFramesPerLoop = 96;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_publishScroll);
    if (!kIsWeb) _fire.addListener(_publishFireFrame);
    unawaited(_motion.start());
    if (widget.reduceMotion) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
    _syncFire();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerModeEnabled = TickerMode.valuesOf(context).enabled;
    _syncFire();
  }

  void _publishFireFrame() {
    // The controller can tick at 60/120 Hz, but the painted three-frame flame
    // gains no visual detail from rebuilding two alpha rasters that often.
    // Eighteen authored updates per second keeps the candle alive and leaves
    // the remaining frame budget to the ledger's drag and phone tilt.
    final snapped =
        (_fire.value * _fireFramesPerLoop).floor() / _fireFramesPerLoop;
    if (snapped != _firePhase.value) _firePhase.value = snapped;
  }

  void _syncFire() {
    final shouldLive = !widget.reduceMotion && _tickerModeEnabled;
    if (kIsWeb) {
      if (shouldLive) {
        _webFireTimer ??= Timer.periodic(const Duration(milliseconds: 100), (
          _,
        ) {
          const steps = 54;
          _webFireFrame = (_webFireFrame + 1) % steps;
          _firePhase.value = _webFireFrame / steps;
        });
      } else {
        _webFireTimer?.cancel();
        _webFireTimer = null;
        _webFireFrame = (0.18 * 54).round();
        if (_firePhase.value != 0.18) _firePhase.value = 0.18;
      }
    } else if (shouldLive) {
      if (!_fire.isAnimating) _fire.repeat();
    } else {
      _fire.stop();
      if (_firePhase.value != 0.18) _firePhase.value = 0.18;
    }
  }

  @override
  void didUpdateWidget(RoutineLedgerScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reduceMotion != widget.reduceMotion) {
      _motion.setReduceMotion(widget.reduceMotion);
      if (widget.reduceMotion) {
        _entrance.value = 1;
      }
      _syncFire();
    }
  }

  void _publishScroll() {
    final next = _scroll.hasClients ? _scroll.offset : 0.0;
    if ((_scrollPosition.value - next).abs() > (kIsWeb ? 2.0 : 0.25)) {
      _scrollPosition.value = next;
    }
  }

  @override
  void dispose() {
    _webFireTimer?.cancel();
    _scroll.removeListener(_publishScroll);
    if (!kIsWeb) _fire.removeListener(_publishFireFrame);
    _scroll.dispose();
    _scrollPosition.dispose();
    _firePhase.dispose();
    _fire.dispose();
    _entrance.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final morning = widget.time == RoutineTime.morning;
    final roomAsset = morning
        ? 'assets/routine/room-morning-v1.webp'
        : 'assets/routine/room-night-v1.webp';

    return OverlaySurface(
      child: ColoredBox(
        color: const Color(0xFF0E0907),
        child: Listener(
          onPointerDown: (_) =>
              unawaited(_motion.requestBrowserMotionPermission()),
          child: LayoutBuilder(
            builder: (context, bounds) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final narrowPhone = bounds.maxWidth < 360;
              // Accessibility text gets the two-line title and the lower
              // folio on any phone; only the narrow one also needs the
              // taller stage.
              final largeText = textScale >= 1.75;
              final accessibilityPhone = narrowPhone && largeText;
              // Reserve the page's real extent (its extra paper and the
              // optional action below it), so the stage always reaches the
              // same endpoint as the page builder.
              final pageGeometry = _routineLedgerPageGeometry(
                viewportWidth: bounds.maxWidth,
                textScale: textScale,
                time: widget.time,
                extraPageHeight: widget.pageExtraHeight,
                hasSecondaryAction: true,
              );
              final contentTop = largeText ? 245.0 : 154.0;
              final ledgerExtent = contentTop + pageGeometry.totalHeight + 16;
              final minimumStage = max(
                narrowPhone ? (accessibilityPhone ? 1450.0 : 1080.0) : 900.0,
                ledgerExtent,
              );
              final stageHeight = max(minimumStage, bounds.maxHeight);
              return MouseRegion(
                onHover: (event) =>
                    _motion.handlePointer(event, bounds.biggest),
                onExit: _motion.clearPointer,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _RoutineRoomPlate(
                      asset: roomAsset,
                      parallax: _motion.parallax,
                      scrollPosition: _scrollPosition,
                      morning: morning,
                    ),
                    Positioned(
                      right: -8,
                      top: bounds.maxHeight * (morning ? 0.270 : 0.275),
                      width: bounds.maxWidth * 0.29,
                      height: bounds.maxWidth * 0.31,
                      child: _RoutineLivingFire(
                        animation: _firePhase,
                        morning: morning,
                        lively: !widget.reduceMotion,
                      ),
                    ),
                    _RoutineScrollVeil(
                      scrollPosition: _scrollPosition,
                      morning: morning,
                    ),
                    SafeArea(
                      child: SingleChildScrollView(
                        key: widget.scrollKey,
                        controller: _scroll,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        child: SizedBox(
                          // Accessibility-sized type needs a physically longer
                          // folio on the narrowest phones. Give the scroll view
                          // real extent for that extra paper instead of letting
                          // the live ledger overflow inside a clipped stage.
                          height: stageHeight,
                          width: bounds.maxWidth,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                top: 12,
                                left: morning ? null : 10,
                                right: morning ? 10 : null,
                                child: Semantics(
                                  button: true,
                                  label: widget.dismissLabel,
                                  child: TextButton(
                                    onPressed: widget.onDismiss,
                                    style: TextButton.styleFrom(
                                      foregroundColor: Palette.textLo,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                    child: Text(
                                      widget.dismissLabel,
                                      style: Type.label.copyWith(
                                        fontSize: 11,
                                        color: Palette.textMid,
                                        shadows: const [
                                          Shadow(
                                            color: Color(0xB3000000),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: largeText ? 52 : 62,
                                left: largeText ? 20 : 24,
                                right: largeText ? 20 : 24,
                                child: FadeTransition(
                                  opacity: _entranceCurve,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.12),
                                      end: Offset.zero,
                                    ).animate(_entranceCurve),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          widget.title,
                                          maxLines: largeText ? 2 : 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: LedgerType.display.copyWith(
                                            fontSize: largeText ? 32 : 39,
                                            height: largeText ? 0.92 : 1,
                                            color: Palette.textHi,
                                            shadows: const [
                                              Shadow(
                                                color: Color(0xE0000000),
                                                blurRadius: 18,
                                                offset: Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        Text(
                                          widget.dateLabel,
                                          maxLines: largeText ? 2 : 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: Type.label.copyWith(
                                            fontSize: 11,
                                            letterSpacing: 1.75,
                                            color: morning
                                                ? const Color(0xFFE9C9A0)
                                                : Palette.textMid,
                                            shadows: const [
                                              Shadow(
                                                color: Color(0xCC000000),
                                                blurRadius: 9,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: largeText ? 245 : 154,
                                left: 0,
                                right: 0,
                                child: widget.builder(
                                  context,
                                  _motion.parallax,
                                  _motion.light,
                                  _scrollPosition,
                                  _entranceCurve,
                                ),
                              ),
                            ],
                          ),
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
    );
  }
}

class _RoutineRoomPlate extends StatelessWidget {
  const _RoutineRoomPlate({
    required this.asset,
    required this.parallax,
    required this.scrollPosition,
    required this.morning,
  });

  final String asset;
  final ValueListenable<Offset> parallax;
  final ValueListenable<double> scrollPosition;
  final bool morning;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([parallax, scrollPosition]),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
        builder: (context, room) {
          final tilt = parallax.value;
          final scroll = scrollPosition.value.clamp(0.0, 160.0) / 160.0;
          return Transform.translate(
            offset: Offset(-tilt.dx * 3.2, -52 - tilt.dy * 2.0 - scroll * 3.5),
            child: Transform.scale(
              // The approved artboard sees the mountain horizon and moon
              // above the folio. A little more overscan and an upward camera
              // registration preserves that composition on a tall phone.
              scale: 1.12,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  morning ? const Color(0x24FFF1D0) : const Color(0x16100604),
                  morning ? BlendMode.screen : BlendMode.multiply,
                ),
                child: room,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RoutineScrollVeil extends StatelessWidget {
  const _RoutineScrollVeil({
    required this.scrollPosition,
    required this.morning,
  });

  final ValueListenable<double> scrollPosition;
  final bool morning;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scrollPosition,
      builder: (context, _) {
        final strength = Curves.easeOutCubic.transform(
          (scrollPosition.value / 130).clamp(0.0, 1.0),
        );
        if (strength < 0.002) return const SizedBox.shrink();
        return Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: morning
                      ? [
                          const Color(
                            0xFF2B1A10,
                          ).withValues(alpha: 0.03 * strength),
                          const Color(
                            0xFF2B1A10,
                          ).withValues(alpha: 0.14 * strength),
                          const Color(
                            0xFF170D08,
                          ).withValues(alpha: 0.24 * strength),
                        ]
                      : [
                          const Color(
                            0xFF0D0806,
                          ).withValues(alpha: 0.03 * strength),
                          const Color(
                            0xFF0D0806,
                          ).withValues(alpha: 0.15 * strength),
                          const Color(
                            0xFF090504,
                          ).withValues(alpha: 0.29 * strength),
                        ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoutineLivingFire extends StatelessWidget {
  const _RoutineLivingFire({
    required this.animation,
    required this.morning,
    required this.lively,
  });

  final ValueListenable<double> animation;
  final bool morning;
  final bool lively;

  static const _frames = <String>[
    'assets/rooms/quest-fire-a-v3.png',
    'assets/rooms/quest-fire-b-v3.png',
    'assets/rooms/quest-fire-c-v3.png',
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = lively ? animation.value : 0.18;
            final phase = t * 15;
            final current = phase.floor() % _frames.length;
            final next = (current + 1) % _frames.length;
            final blend = Curves.easeInOutSine.transform(phase % 1);
            final sway = lively
                ? sin(t * pi * 8) * 1.7 + sin(t * pi * 13 + 0.6) * 0.8
                : 0.0;
            final breathe = lively ? 0.97 + sin(t * pi * 6) * 0.025 : 0.97;
            final opacity = morning ? 0.58 : 0.72;
            return Transform.translate(
              offset: Offset(sway, 0),
              child: Transform.scale(
                alignment: Alignment.bottomCenter,
                scaleX: 1 / breathe,
                scaleY: breathe,
                child: Opacity(
                  opacity: opacity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Opacity(
                        opacity: 1 - blend,
                        child: Image.asset(
                          _frames[current],
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          filterQuality: FilterQuality.medium,
                          excludeFromSemantics: true,
                        ),
                      ),
                      Opacity(
                        opacity: blend,
                        child: Image.asset(
                          _frames[next],
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          filterQuality: FilterQuality.medium,
                          excludeFromSemantics: true,
                        ),
                      ),
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

/// A real generated leather folio with live, accessible content placed on its
/// clean page. The artwork owns material detail; Flutter owns information and
/// interaction, so names, quests and rewards never become baked-in pixels.
class RoutineLedgerPage extends StatelessWidget {
  const RoutineLedgerPage({
    super.key,
    required this.time,
    required this.parallax,
    required this.light,
    required this.scroll,
    required this.entrance,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.closing = false,
    this.extraPageHeight = 0,
  });

  final RoutineTime time;
  final ValueListenable<Offset> parallax;
  final ValueListenable<Offset> light;
  final ValueListenable<double> scroll;
  final Animation<double> entrance;
  final Widget child;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool closing;

  /// Additional writing space for a bookend with more live content. The folio
  /// extends instead of shrinking type or stealing another control's room.
  /// Morning keeps its original frame; the night receipt uses this allowance.
  final double extraPageHeight;

  @override
  Widget build(BuildContext context) {
    final morning = time == RoutineTime.morning;
    final asset = morning
        ? 'assets/routine/ledger-morning-v2.webp'
        : 'assets/routine/ledger-night-v2.webp';
    final registration = morning
        ? _LedgerPageRegistration.morning
        : _LedgerPageRegistration.night;

    return LayoutBuilder(
      builder: (context, bounds) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final geometry = _routineLedgerPageGeometry(
          viewportWidth: bounds.maxWidth,
          textScale: textScale,
          time: time,
          extraPageHeight: extraPageHeight,
          hasSecondaryAction: secondaryLabel != null,
        );
        final width = geometry.width;
        final folioHeight = geometry.folioHeight;
        final claspHeight = geometry.claspHeight;
        // Register the dawn plate back to the same quiet camera as the night
        // cover while preserving its measured internal page homography.
        final plateAngle = morning ? -3.5 * pi / 180 : 0.0;
        final plateOffsetX = morning ? width * 0.026 : 0.0;
        final claspTop = geometry.claspTop;
        // Align the action with the corrected parchment rather than the
        // asymmetric transparent bounds of the dawn asset.
        final claspOffsetX = morning ? width * 0.017 : 0.0;
        final secondaryTop = geometry.secondaryTop;
        final totalHeight = geometry.totalHeight;
        return SizedBox(
          width: bounds.maxWidth,
          height: totalHeight,
          child: OverflowBox(
            minWidth: width,
            maxWidth: width,
            minHeight: totalHeight,
            maxHeight: totalHeight,
            child: SizedBox(
              width: width,
              height: totalHeight,
              child: AnimatedOpacity(
                opacity: closing ? 0.72 : 1,
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeInCubic,
                child: AnimatedRotation(
                  turns: closing ? -0.004 : 0,
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeInOutCubic,
                  child: AnimatedScale(
                    scale: closing ? 0.955 : 1,
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeInOutCubic,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([entrance, parallax]),
                      builder: (context, _) {
                        final intro = entrance.value;
                        final tilt = parallax.value;
                        final matrix = Matrix4.identity()
                          ..setEntry(3, 2, 0.0007)
                          ..translateByDouble(
                            tilt.dx * 5.2,
                            (1 - intro) * 24 + tilt.dy * 3.2,
                            0,
                            1,
                          )
                          ..rotateY(tilt.dx * 0.008)
                          ..rotateX(-tilt.dy * 0.004)
                          ..scaleByDouble(
                            0.965 + intro * 0.035,
                            0.965 + intro * 0.035,
                            0.965 + intro * 0.035,
                            1,
                          );
                        return Transform(
                          alignment: Alignment.center,
                          transform: matrix,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: 0,
                                top: 0,
                                width: width,
                                height: folioHeight,
                                child: Transform.translate(
                                  offset: Offset(plateOffsetX, 0),
                                  transformHitTests: true,
                                  child: Transform.rotate(
                                    angle: plateAngle,
                                    alignment: Alignment.center,
                                    transformHitTests: true,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.asset(
                                          asset,
                                          fit: BoxFit.fill,
                                          filterQuality: FilterQuality.high,
                                          excludeFromSemantics: true,
                                        ),
                                        _LedgerPerspectiveContent(
                                          registration: registration,
                                          child: child,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: width * _claspInset,
                                right: width * _claspInset,
                                top: claspTop,
                                height: claspHeight,
                                child: Transform.translate(
                                  offset: Offset(
                                    claspOffsetX + parallax.value.dx * 1.4,
                                    parallax.value.dy * 0.7,
                                  ),
                                  child: LedgerClaspButton(
                                    label: primaryLabel,
                                    onTap: onPrimary,
                                    light: light,
                                    scroll: scroll,
                                  ),
                                ),
                              ),
                              if (secondaryLabel != null && onSecondary != null)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: secondaryTop,
                                  child: Center(
                                    child: TextButton(
                                      onPressed: onSecondary,
                                      style: TextButton.styleFrom(
                                        foregroundColor: Palette.textLo,
                                        minimumSize: const Size(44, 38),
                                      ),
                                      child: Text(
                                        secondaryLabel!,
                                        style: Type.label.copyWith(
                                          fontSize: 11,
                                          color: Palette.textMid,
                                          shadows: const [
                                            Shadow(
                                              color: Color(0xD9000000),
                                              blurRadius: 8,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
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
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The usable page is not an axis-aligned rectangle inside either source
/// photograph. Its four corners are registered against the real inner rules
/// in the native folio assets, then moved inward far enough that live copy,
/// controls, and ink never crowd the gilding.
///
/// Normalized source coordinates keep that registration intact when
/// accessibility needs a taller folio: the artwork and its safe quadrilateral
/// stretch together.
class _LedgerPageRegistration {
  const _LedgerPageRegistration({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  // ledger-night-v2.webp — 1056 × 1092.
  static const night = _LedgerPageRegistration(
    topLeft: Offset(282 / 1056, 112 / 1092),
    topRight: Offset(783 / 1056, 118 / 1092),
    bottomRight: Offset(827 / 1056, 845 / 1092),
    bottomLeft: Offset(250 / 1056, 835 / 1092),
  );

  // ledger-morning-v2.webp — 1022 × 1184.
  static const morning = _LedgerPageRegistration(
    topLeft: Offset(280 / 1022, 126 / 1184),
    topRight: Offset(747 / 1022, 166 / 1184),
    bottomRight: Offset(752 / 1022, 942 / 1184),
    bottomLeft: Offset(215 / 1022, 900 / 1184),
  );

  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;
}

class _LedgerPerspectiveContent extends StatelessWidget {
  const _LedgerPerspectiveContent({
    required this.registration,
    required this.child,
  });

  final _LedgerPageRegistration registration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bounds) {
        final size = bounds.biggest;
        final topLeft = _resolve(registration.topLeft, size);
        final topRight = _resolve(registration.topRight, size);
        final bottomRight = _resolve(registration.bottomRight, size);
        final bottomLeft = _resolve(registration.bottomLeft, size);

        // Lay the child out at the quad's average physical dimensions first.
        // The matrix then contributes only the photographed convergence and
        // tilt instead of shrinking an oversized flat layout after the fact.
        final contentWidth =
            ((topRight - topLeft).distance +
                (bottomRight - bottomLeft).distance) /
            2;
        final contentHeight =
            ((bottomLeft - topLeft).distance +
                (bottomRight - topRight).distance) /
            2;
        final transform = _quadTransform(
          width: contentWidth,
          height: contentHeight,
          topLeft: topLeft,
          topRight: topRight,
          bottomRight: bottomRight,
          bottomLeft: bottomLeft,
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: contentWidth,
              height: contentHeight,
              child: Transform(
                alignment: Alignment.topLeft,
                transform: transform,
                transformHitTests: true,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }

  static Offset _resolve(Offset point, Size size) =>
      Offset(point.dx * size.width, point.dy * size.height);

  /// Projects an ordinary child rectangle into a convex four-corner page.
  ///
  /// Flutter's Matrix4 uses its final row for the perspective divisor, so the
  /// homography maps horizontal rules and interactive hit targets into the
  /// same photographed plane as the printed border.
  static Matrix4 _quadTransform({
    required double width,
    required double height,
    required Offset topLeft,
    required Offset topRight,
    required Offset bottomRight,
    required Offset bottomLeft,
  }) {
    final dx1 = topRight.dx - bottomRight.dx;
    final dx2 = bottomLeft.dx - bottomRight.dx;
    final dx3 = topLeft.dx - topRight.dx + bottomRight.dx - bottomLeft.dx;
    final dy1 = topRight.dy - bottomRight.dy;
    final dy2 = bottomLeft.dy - bottomRight.dy;
    final dy3 = topLeft.dy - topRight.dy + bottomRight.dy - bottomLeft.dy;

    var perspectiveX = 0.0;
    var perspectiveY = 0.0;
    if (dx3.abs() > 0.000001 || dy3.abs() > 0.000001) {
      final denominator = dx1 * dy2 - dx2 * dy1;
      perspectiveX = (dx3 * dy2 - dx2 * dy3) / denominator;
      perspectiveY = (dx1 * dy3 - dx3 * dy1) / denominator;
    }

    final scaleX = topRight.dx - topLeft.dx + perspectiveX * topRight.dx;
    final shearX = bottomLeft.dx - topLeft.dx + perspectiveY * bottomLeft.dx;
    final scaleY = topRight.dy - topLeft.dy + perspectiveX * topRight.dy;
    final shearY = bottomLeft.dy - topLeft.dy + perspectiveY * bottomLeft.dy;

    return Matrix4.identity()
      ..setEntry(0, 0, scaleX / width)
      ..setEntry(0, 1, shearX / height)
      ..setEntry(0, 3, topLeft.dx)
      ..setEntry(1, 0, scaleY / width)
      ..setEntry(1, 1, shearY / height)
      ..setEntry(1, 3, topLeft.dy)
      ..setEntry(3, 0, perspectiveX / width)
      ..setEntry(3, 1, perspectiveY / height);
  }
}

/// The ledger's primary: the book's brass clasp, now a label holder, with a
/// card of the lamp's vellum set into it. The brass is the book's hardware
/// and stays in shadow; the card carries the one lamp of the view, lit like
/// the room's lamp shade, and its core shifts with the tilt and scroll the
/// ledger already listens to. Contact turns the card's light up at once.
class LedgerClaspButton extends StatelessWidget {
  const LedgerClaspButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.light,
    required this.scroll,
  });

  final String label;
  final VoidCallback onTap;
  final ValueListenable<Offset> light;
  final ValueListenable<double> scroll;

  // The holder's opening inside ledger-clasp-v2.webp (1983 x 498): between
  // the two rivet tabs and inside the engraved rule.
  static const _opening = Rect.fromLTRB(
    268 / 1983,
    60 / 498,
    1715 / 1983,
    368 / 498,
  );

  @override
  Widget build(BuildContext context) {
    const shape = FacetedBorder(cut: 7);
    final accessibilityText = MediaQuery.textScalerOf(context).scale(1) >= 1.75;
    Widget face(bool pressed) => LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final card = Rect.fromLTRB(
          _opening.left * w,
          _opening.top * h,
          _opening.right * w,
          _opening.bottom * h,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            // Aged brass in the dark: a little deeper and less saturated
            // than the photograph, so the card is the light, not the metal.
            ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.70, 0.07, 0.02, 0, 0, //
                0.05, 0.66, 0.02, 0, 0, //
                0.04, 0.06, 0.55, 0, 0, //
                0, 0, 0, 1, 0,
              ]),
              child: Image.asset(
                'assets/routine/ledger-clasp-v2.webp',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
              ),
            ),
            Positioned.fromRect(
              rect: card,
              child: LampShade(
                cut: 3,
                spill: false,
                pressed: pressed,
                light: light,
                scroll: scroll,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: accessibilityText ? 2 : 10,
                    ),
                    child: LampWords(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            LampLabel.styleFor(
                              label,
                              fontSize: accessibilityText ? 9.5 : 14.5,
                            ).copyWith(
                              letterSpacing: accessibilityText ? 0.2 : 2.2,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // The holder's lip shades the top and left of the card.
            Positioned.fromRect(
              rect: card,
              child: const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x8C120A05), Color(0x00120A05)],
                      stops: [0, 0.16],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    return Pressable(
      semanticLabel: label,
      material: MaterialSound.brass,
      shape: shape,
      // The plate is a photograph with its own cast shadow and rounded ends;
      // an under-edge would staple a synthetic slab behind it.
      edgeColor: Colors.transparent,
      pressDepth: 2,
      onTapUp: (_) => onTap(),
      stateBuilder: (context, child, pressed, focused, hovered) =>
          RepaintBoundary(child: face(pressed)),
      child: RepaintBoundary(child: face(false)),
    );
  }
}

abstract final class LedgerInk {
  static const dark = Color(0xFF3D2C20);
  static const mid = Color(0xFF6F5742);
  static const quiet = Color(0xFF92785F);
  static const rule = Color(0x4D7A5A36);
  static const pageGold = Color(0xFF8D5B27);
}

/// A small section title with rules cut into the page on both sides.
class LedgerSectionTitle extends StatelessWidget {
  const LedgerSectionTitle({
    super.key,
    required this.label,
    required this.morning,
    this.color,
  });

  final String label;
  final bool morning;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? (morning ? LedgerInk.mid : Palette.textLo);
    return SizedBox(
      height: 18,
      child: Row(
        children: [
          Expanded(
            child: Opacity(
              opacity: morning ? 0.56 : 0.72,
              child: Image.asset(
                'assets/routine/gilded-section-rule-left-v2.webp',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: LedgerType.smallCaps.copyWith(
                    fontSize: 11,
                    color: ink,
                    shadows: [
                      Shadow(
                        color: morning
                            ? const Color(0x66FFF7DF)
                            : const Color(0x6B000000),
                        blurRadius: 1,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Opacity(
              opacity: morning ? 0.56 : 0.72,
              child: Image.asset(
                'assets/routine/gilded-section-rule-right-v2.webp',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
