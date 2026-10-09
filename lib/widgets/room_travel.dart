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
/// the dock and ordinary pushed pages carry no decoration at all. The dock
/// changes rooms the way an iOS tab bar changes tabs, at once, softened by a
/// very short cross-dissolve so it is not a hard cut. Pushed pages use the
/// platform's own slide, with its parallax and interactive edge-swipe
/// untouched. The parchment contact at pointer-down stays the sound of
/// travel. The Goals walk (goal_room_route.dart, goal_world.dart, the Goals
/// opening) is its own authored movement and is not governed by anything here.
abstract final class RoomTravel {
  /// Mirrors GameState.reduceMotion OR the system's disableAnimations (the
  /// shell keeps it current, the same pattern as Haptics.reduceMotion) so
  /// route transitions, which cannot see app state, can park on a plain fade.
  static bool reduceMotion = false;

  /// One dock change. Long enough that it is not a hard cut, short enough to
  /// read as immediate.
  static const tabFade = Duration(milliseconds: 120);

  /// The new room's share of the picture over [tabFade]. A steep ease-out:
  /// about half the picture on the first frame after the tap, 80% on the
  /// next and 93% on the one after, so the two rooms truly overlap for about
  /// one frame and what follows is a short fading trace of the old room.
  ///
  /// The tap's own frame shows the dock's new selection and builds the new
  /// room at zero opacity. That frame is deliberate: a room visited for the
  /// first time is built lazily right then, and its first-build layout (the
  /// Plans daybook still "Opening your schedule...") settles unseen instead
  /// of jumping inside the dissolve.
  static const tabCurve = Curves.easeOutQuint;

  /// Reduced Motion pushes and pops: a plain fade in place, no travel.
  static const stillRouteIn = Duration(milliseconds: 180);
  static const stillRouteOut = Duration(milliseconds: 150);
}

bool _still(BuildContext context) =>
    RoomTravel.reduceMotion ||
    (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

/// The five rooms, switched by the dock.
///
/// Keeps IndexedStack's contract: every child stays mounted with its state
/// alive (scroll positions, boards, decoded art), and only the active one
/// hits or speaks to assistive tech. When [index] changes, the picture on
/// screen dissolves into the new room over [RoomTravel.tabFade]. Nothing
/// slides, scales or blurs.
///
/// Interruption is a designed state: a tap mid-dissolve redirects at once.
/// Whatever mix of rooms is on screen when the tap lands becomes the starting
/// picture of the next dissolve: the rooms already on screen keep their
/// proportions and fade out together (nothing snaps back or restarts), while
/// the newly chosen room arrives on the very next frame, exactly as it would
/// from rest.
///
/// Reduced Motion (in-app or system) switches in one frame.
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
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: RoomTravel.tabFade,
    value: 1,
  );

  /// The picture on screen when the current dissolve began, as each room's
  /// share of it (shares sum to 1). Empty when parked.
  Map<int, double> _from = const {};

  /// Below this share a room is invisible (under one 8-bit step), so it
  /// leaves the stage instead of painting a layer nobody can see.
  static const _invisible = 1 / 512;

  /// Each staged room's share of the picture while dissolving toward
  /// [target]: the target's share is the curved progress, and every room
  /// already on screen keeps its proportion of what is left.
  Map<int, double> _sharesToward(int target) {
    if (_from.isEmpty || _fade.value >= 1) return {target: 1};
    final a = RoomTravel.tabCurve.transform(_fade.value);
    final shares = <int, double>{
      for (final MapEntry(:key, :value) in _from.entries) key: value * (1 - a),
    };
    shares[target] = (shares[target] ?? 0) + a;
    shares.removeWhere((room, share) => room != target && share < _invisible);
    return shares;
  }

  @override
  void didUpdateWidget(covariant RoomTravelStack old) {
    super.didUpdateWidget(old);
    if (widget.index == old.index) return;
    if (_still(context)) {
      _from = const {};
      _fade.value = 1;
      return;
    }
    // Freeze the picture on screen now (a dissolve still in flight
    // included) and dissolve from it, so a redirect never snaps or restarts
    // the rooms already on screen.
    _from = _sharesToward(old.index);
    _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  /// Picture shares as opacities for the stack's fixed paint order (higher
  /// index paints on top). The lowest staged room is always fully opaque, so
  /// the canvas behind the rooms never shows through and the dissolve cannot
  /// dip or flash; each room above it takes exactly its share of what is
  /// left. The order never changes, so no room ever moves in the tree.
  static Map<int, double> _opacities(Map<int, double> shares) {
    final order = shares.keys.toList()..sort((a, b) => b.compareTo(a));
    final out = <int, double>{};
    var remaining = 1.0;
    for (final (n, room) in order.indexed) {
      final share = shares[room]!;
      out[room] = n == order.length - 1
          ? 1.0
          : remaining <= 1e-9
          ? 0.0
          : (share / remaining).clamp(0.0, 1.0);
      remaining -= share;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fade,
      builder: (context, _) {
        final active = widget.index;
        final opacities = _opacities(_sharesToward(active));
        return Stack(
          fit: StackFit.expand,
          children: [
            for (final (i, child) in widget.children.indexed)
              _pane(
                child: child,
                live: i == active,
                staged: opacities.containsKey(i),
                opacity: opacities[i] ?? 0,
              ),
          ],
        );
      },
    );
  }

  /// One pane per room, with a build-stable widget chain (only values ever
  /// change) so a dissolve can never remount a room. A hidden pane sits
  /// offstage, which is IndexedStack's contract: state alive, but unpainted,
  /// untouchable, unfindable, and silent to assistive tech. The room being
  /// left stops taking touches on the tap's own frame.
  Widget _pane({
    required Widget child,
    required bool live,
    required bool staged,
    required double opacity,
  }) {
    return Offstage(
      offstage: !staged,
      child: IgnorePointer(
        ignoring: !live,
        child: ExcludeSemantics(
          excluding: !live,
          child: Opacity(opacity: opacity, child: child),
        ),
      ),
    );
  }
}

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
