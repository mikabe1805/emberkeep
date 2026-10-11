import 'package:flutter/cupertino.dart'
    show
        CupertinoPageTransition,
        CupertinoPageTransitionsBuilder,
        CupertinoRouteTransitionMixin;
import 'package:flutter/material.dart';

/// Everyday movement between the keep's spaces: native and calm.
///
/// Owner direction (2026-10-03): the motion blur was only ever meant for the
/// Goals walk, and the everyday "blur and rush" felt wrong for the mood. So
/// ordinary pushed pages carry no decoration at all: they use the platform's
/// own slide, with its parallax and interactive edge-swipe untouched. The
/// parchment contact at pointer-down stays the sound of travel. The Goals walk
/// (goal_room_route.dart, goal_world.dart, the Goals opening) is its own
/// authored movement and is not governed by anything here.
///
/// The dock is not here any more: switching tabs is the house's travel (each
/// room arrives through its own light, house/house_travel.dart), the
/// owner's 2026-10-10 direction after "the same pillar transition through every
/// page is a bit lazy". Only this file's route transitions and the
/// [reduceMotion] flag remain for pushes.
abstract final class RoomTravel {
  /// Mirrors GameState.reduceMotion OR the system's disableAnimations (the
  /// shell keeps it current, the same pattern as Haptics.reduceMotion) so
  /// route transitions, which cannot see app state, can park on a plain fade.
  static bool reduceMotion = false;

  /// Reduced Motion pushes and pops: a plain fade in place, no travel.
  static const stillRouteIn = Duration(milliseconds: 180);
  static const stillRouteOut = Duration(milliseconds: 150);
}

bool _still(BuildContext context) =>
    RoomTravel.reduceMotion ||
    (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

/// Pushed pages on Android, Fuchsia, Linux and Windows: the page fades in
/// with a short rise over 300 ms and the room beneath stays exactly where it
/// is. No blur and no receding background. Reduced Motion is a plain fade.
class RoomPageTransitionsBuilder extends PageTransitionsBuilder {
  const RoomPageTransitionsBuilder();

  /// Logical pixels the arriving page rises while it fades in.
  static const rise = 20.0;

  static const _duration = Duration(milliseconds: 300);

  @override
  Duration get transitionDuration =>
      RoomTravel.reduceMotion ? RoomTravel.stillRouteIn : _duration;

  @override
  Duration get reverseTransitionDuration =>
      RoomTravel.reduceMotion ? RoomTravel.stillRouteOut : _duration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _RiseIn(animation: animation, child: child);
  }
}

/// Owns its curved animation (built once, disposed with the route) because
/// route transitions are rebuilt on every animation tick. One widget chain in
/// both modes, so toggling Reduced Motion never remounts anything.
class _RiseIn extends StatefulWidget {
  const _RiseIn({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<_RiseIn> {
  late CurvedAnimation _arrive = _curve(widget.animation);

  static CurvedAnimation _curve(Animation<double> parent) => CurvedAnimation(
    parent: parent,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void didUpdateWidget(covariant _RiseIn old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation) {
      _arrive.dispose();
      _arrive = _curve(widget.animation);
    }
  }

  @override
  void dispose() {
    _arrive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = _still(context);
    return FadeTransition(
      opacity: still ? widget.animation : _arrive,
      child: AnimatedBuilder(
        animation: _arrive,
        builder: (context, page) => Transform.translate(
          offset: Offset(
            0,
            still ? 0 : (1 - _arrive.value) * RoomPageTransitionsBuilder.rise,
          ),
          child: page,
        ),
        child: widget.child,
      ),
    );
  }
}

/// iOS and macOS: the native Cupertino page transition, exactly as the
/// platform plays it: the 500 ms slide, the covered page's parallax (also
/// for a page underneath that is not itself a Cupertino-style route), the
/// edge shadow and the interactive edge-swipe back. Nothing is layered on.
///
/// Reduced Motion, like iOS's "Prefer Cross-Fade Transitions": a push or pop
/// from a button is a plain fade in place, and neither page moves. The
/// edge-swipe still works; while a finger drives it the page follows the
/// finger with the native slide (direct manipulation follows the hand), and
/// at rest it returns to the still mode without a jump.
class RoomCupertinoPageTransitionsBuilder
    extends CupertinoPageTransitionsBuilder {
  const RoomCupertinoPageTransitionsBuilder();

  @override
  Duration get transitionDuration => RoomTravel.reduceMotion
      ? RoomTravel.stillRouteIn
      : CupertinoRouteTransitionMixin.kTransitionDuration;

  @override
  Duration get reverseTransitionDuration => RoomTravel.reduceMotion
      ? RoomTravel.stillRouteOut
      : CupertinoRouteTransitionMixin.kTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => _delegated;

  static Widget? _delegated(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    if (_still(context) &&
        !(Navigator.maybeOf(context)?.userGestureInProgress ?? false)) {
      return child;
    }
    return CupertinoPageTransition.delegatedTransition(
      context,
      animation,
      secondaryAnimation,
      allowSnapshotting,
      child,
    );
  }

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _NativeOrStill<T>(
      route: route,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// The native slide, or under Reduced Motion the same slide parked at rest
/// inside a fade. One widget chain in both modes, so a swipe can start at any
/// time and toggling Reduced Motion never remounts the page or its swipe
/// detector.
class _NativeOrStill<T> extends StatefulWidget {
  const _NativeOrStill({
    required this.route,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final PageRoute<T> route;
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  State<_NativeOrStill<T>> createState() => _NativeOrStillState<T>();
}

class _NativeOrStillState<T> extends State<_NativeOrStill<T>> {
  late CurvedAnimation _fade = _curve(widget.animation);

  static CurvedAnimation _curve(Animation<double> parent) => CurvedAnimation(
    parent: parent,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );

  @override
  void didUpdateWidget(covariant _NativeOrStill<T> old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation) {
      _fade.dispose();
      _fade = _curve(widget.animation);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilt on every tick of the route's animations, so this is re-read
    // at the swipe's boundaries.
    final parked = _still(context) && !widget.route.popGestureInProgress;
    return FadeTransition(
      opacity: parked ? _fade : kAlwaysCompleteAnimation,
      child: CupertinoRouteTransitionMixin.buildPageTransitions<T>(
        widget.route,
        context,
        parked ? kAlwaysCompleteAnimation : widget.animation,
        parked ? kAlwaysDismissedAnimation : widget.secondaryAnimation,
        widget.child,
      ),
    );
  }
}
