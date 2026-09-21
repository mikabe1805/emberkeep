import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Felt travel between the keep's spaces.
///
/// Movement used to be invisible: the dock swapped IndexedStack indices in a
/// single frame and pushed surfaces arrived with the stock platform zoom.
/// These widgets give every space movement one authored gesture — a short
/// lateral camera pan between the five rooms, and a settle deeper into the
/// room for pushed surfaces — carried by a motion blur that rises with the
/// movement's speed and resolves into a sharp parked still. The parchment
/// contact at pointer-down remains the *sound* of travel; this is its body.
abstract final class RoomTravel {
  /// Mirrors GameState.reduceMotion (the shell keeps it current — the same
  /// pattern as Haptics.reduceMotion) so route transitions, which cannot see
  /// app state, can park on a plain cross-fade instead of moving.
  static bool reduceMotion = false;

  /// One movement everywhere: rooms pan for this long, pushes settle within
  /// the route's own 300ms.
  static const panDuration = Duration(milliseconds: 380);
}

/// The five rooms, with a camera pan between them.
///
/// Keeps IndexedStack's contract — every child stays mounted with its state
/// alive, and only the active one paints, hits, or speaks to assistive tech —
/// but when [index] changes the old and new rooms share the frame for one
/// short pan: both slide in the direction of travel while a horizontal motion
/// blur rises with the pan's speed and settles to a sharp still.
class RoomTravelStack extends StatefulWidget {
  const RoomTravelStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<RoomTravelStack> createState() => _RoomTravelStackState();
}

class _RoomTravelStackState extends State<RoomTravelStack>
    with SingleTickerProviderStateMixin {
  /// Restrained travel: enough for the eye to read a direction, never a
  /// carousel fling. The blur carries the sense of speed, not the distance.
  static const _travel = 26.0;
  static const _maxBlur = 4.5;

  late final AnimationController _pan = AnimationController(
    vsync: this,
    duration: RoomTravel.panDuration,
  );

  /// The room being left, while a pan is in flight. Null when parked.
  int? _from;

  /// Lets the blur wrapper come and go around the live stack without
  /// remounting the five rooms (their scroll positions, boards, and images).
  final GlobalKey _sceneKey = GlobalKey(debugLabel: 'room-travel-scene');

  @override
  void didUpdateWidget(covariant RoomTravelStack old) {
    super.didUpdateWidget(old);
    if (widget.index == old.index) return;
    final still =
        RoomTravel.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (still) {
      _from = null;
      _pan.value = 1;
      return;
    }
    // A tap mid-pan redirects the camera from wherever it is; the pan
    // restarts from the interrupted room rather than queueing behind it.
    _from = old.index;
    _pan.forward(from: 0);
  }

  @override
  void dispose() {
    _pan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pan,
      builder: (context, _) {
        final from = _from;
        final active = widget.index;
        // Derived from the animation's value, not a completion callback, so
        // the outgoing room leaves the stage in the very frame the pan lands.
        final panning = from != null && from != active && _pan.value < 1;
        final t = panning ? _pan.value : 1.0;
        final p = Curves.easeOutCubic.transform(t);
        final direction = panning && active < from ? -1.0 : 1.0;
        // Whichever room paints on top does the fading, so the pair reads as
        // one continuous cross-dissolve in both travel directions.
        final topIsIncoming = !panning || active > from;
        final fade = (p / 0.38).clamp(0.0, 1.0);

        Widget scene = KeyedSubtree(
          key: _sceneKey,
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (final (i, child) in widget.children.indexed)
                _pane(
                  child: child,
                  live: i == active,
                  staged: i == active || (panning && i == from),
                  offset: !panning || (i != active && i != from)
                      ? Offset.zero
                      : i == active
                      ? Offset(direction * _travel * (1 - p), 0)
                      : Offset(-direction * _travel * p, 0),
                  opacity: i == active
                      ? (topIsIncoming ? fade : 1.0)
                      : i == from
                      ? (topIsIncoming ? 1.0 : 1.0 - fade)
                      : 0.0,
                ),
            ],
          ),
        );

        // Motion blur follows the pan's speed: a fast ramp in (no popped
        // first frame), then the ease-out's own decay into a sharp settle.
        // Applied only while meaningful — the parked frame pays nothing.
        final sigma = panning
            ? _maxBlur * (t / 0.12).clamp(0.0, 1.0) * (1 - t) * (1 - t)
            : 0.0;
        if (sigma > 0.08) {
          scene = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: sigma,
              sigmaY: sigma * 0.22,
              tileMode: TileMode.decal,
            ),
            child: scene,
          );
        }
        return scene;
      },
    );
  }

  /// One pane per room, with a build-stable widget chain (only values ever
  /// change) so pans can never remount a room mid-flight. A hidden pane sits
  /// offstage — exactly IndexedStack's contract: state alive, but unpainted,
  /// untouchable, unfindable, and silent to assistive tech.
  Widget _pane({
    required Widget child,
    required bool live,
    required bool staged,
    required Offset offset,
    required double opacity,
  }) {
    return Offstage(
      offstage: !staged,
      child: IgnorePointer(
        ignoring: !live,
        child: ExcludeSemantics(
          excluding: !live,
          child: Transform.translate(
            offset: offset,
            child: Opacity(opacity: opacity, child: child),
          ),
        ),
      ),
    );
  }
}

/// Shared by both route builders: wraps the page with a transition-time
/// blur that can appear and disappear without remounting the page.
class _RouteBlur extends StatefulWidget {
  const _RouteBlur({
    required this.listenable,
    required this.sigma,
    required this.compose,
    required this.child,
    this.sigmaYFactor = 1.0,
  });

  final Listenable listenable;
  final double Function() sigma;

  /// 1.0 for an even focus pull; small for a directional lateral streak.
  final double sigmaYFactor;

  /// Applies the builder's own opacity/translate around the (possibly
  /// blurred) page each tick. Values must be no-ops at rest.
  final Widget Function(Widget page) compose;
  final Widget child;

  @override
  State<_RouteBlur> createState() => _RouteBlurState();
}

class _RouteBlurState extends State<_RouteBlur> {
  final GlobalKey _pageKey = GlobalKey(debugLabel: 'room-route-page');

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.listenable,
      builder: (context, _) {
        Widget page = KeyedSubtree(key: _pageKey, child: widget.child);
        final sigma = widget.sigma();
        if (sigma > 0.08) {
          page = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: sigma,
              sigmaY: sigma * widget.sigmaYFactor,
              tileMode: TileMode.decal,
            ),
            child: page,
          );
        }
        return widget.compose(page);
      },
    );
  }
}

bool _still(BuildContext context) =>
    RoomTravel.reduceMotion ||
    (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

/// Pushed surfaces settle up out of the room's depth: a short rise, a fade,
/// and a focus pull that lands sharp. The room beneath eases back a step.
/// Used everywhere except iOS/macOS, whose native edge-swipe lives in the
/// Cupertino builder (see [RoomCupertinoPageTransitionsBuilder]).
class RoomPageTransitionsBuilder extends PageTransitionsBuilder {
  const RoomPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_still(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    final arrive = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final covered = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeInOut,
    );
    return _RouteBlur(
      listenable: Listenable.merge([arrive, covered]),
      sigma: () => (1 - arrive.value) * 3.2,
      compose: (page) {
        final t = arrive.value;
        final u = covered.value;
        Widget scene = page;
        if (t < 1) {
          scene = Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 20),
              child: scene,
            ),
          );
        }
        if (u > 0) {
          // The covered room recedes a step instead of freezing — depth,
          // not a lightbox.
          scene = Opacity(
            opacity: 1 - u * 0.22,
            child: Transform.translate(
              offset: Offset(0, u * -12),
              child: scene,
            ),
          );
        }
        return scene;
      },
      child: child,
    );
  }
}

/// iOS/macOS: keep the native slide and its interactive edge-swipe exactly as
/// they are, and add the lateral motion blur underneath — real motion blur on
/// real motion. The blur stands down entirely while a finger owns the
/// gesture, so tracking stays crisp and coupled to the hand.
class RoomCupertinoPageTransitionsBuilder extends PageTransitionsBuilder {
  const RoomCupertinoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    Widget page = child;
    if (!_still(context)) {
      page = _RouteBlur(
        listenable: animation,
        sigmaYFactor: 0.2,
        sigma: () {
          if (route.navigator?.userGestureInProgress ?? false) return 0.0;
          final t = animation.value;
          // A bell over the slide: quiet at both ends, streaking mid-flight.
          return 3.6 * 4 * t * (1 - t);
        },
        compose: (blurred) => blurred,
        child: child,
      );
    }
    return const CupertinoPageTransitionsBuilder().buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      page,
    );
  }
}
