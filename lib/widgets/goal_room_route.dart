import 'package:flutter/material.dart';

import '../tokens.dart';
import 'goal_threshold_walk.dart';
import 'goal_world.dart';

double _segment(double value, double begin, double end) =>
    ((value - begin) / (end - begin)).clamp(0.0, 1.0);

/// Walking in: the Goals folio lifts with your first step, about 0.83 s of
/// walking through the arch, then the room's own page settles in once you are
/// standing in it.
const goalRoomWalkDuration = Duration(milliseconds: 970);

/// Walking back out: the page lifts, you step back through the arch, and the
/// Goals folio returns once you are back at the desk.
const goalRoomWalkReverseDuration = Duration(milliseconds: 900);

/// Reduced Motion: a plain fade between two stills.
const goalRoomStillDuration = Duration(milliseconds: 220);
const goalRoomStillReverseDuration = Duration(milliseconds: 180);

const _gait = GoalWalkGait();

/// One direction of travel through the arch, as functions of the route's
/// linear animation value.
@immutable
class _WalkTimeline {
  const _WalkTimeline.outbound()
    : returning = false,
      walkFrom = 0,
      walkTo = 0.856,
      sourceTo = 0.10,
      pageFrom = 0.835;

  const _WalkTimeline.returning()
    : returning = true,
      walkFrom = 0.16,
      walkTo = 0.93,
      sourceTo = 0.16,
      pageFrom = 0.88;

  /// Walking back out is the walk in, mirrored in time: its first step comes
  /// as the page lifts and its soft stop lands on the desk.
  final bool returning;
  final double walkFrom;
  final double walkTo;

  /// The route's room fades over the Goals tab between 0 and this value.
  final double sourceTo;

  /// The destination page is present between this value and 1.
  final double pageFrom;

  double walk(double raw) {
    final u = _segment(raw, walkFrom, walkTo);
    return returning ? 1 - _gait.transform(1 - u) : _gait.transform(u);
  }

  /// d(walk)/d(raw).
  double walkSlope(double raw) {
    if (raw <= walkFrom || raw >= walkTo) return 0;
    final u = _segment(raw, walkFrom, walkTo);
    final dudr = 1 / (walkTo - walkFrom);
    return (returning ? _gait.velocity(1 - u) : _gait.velocity(u)) * dudr;
  }

  double source(double raw) =>
      Curves.easeInOutCubic.transform(_segment(raw, 0, sourceTo));

  double page(double raw) {
    final t = _segment(raw, pageFrom, 1);
    // Arriving, the page settles in; leaving, it lifts quickly then eases.
    return returning
        ? 1 - Curves.easeOutCubic.transform(1 - t)
        : Curves.easeOutCubic.transform(t);
  }
}

/// Turning back mid-walk: the walk's forward momentum eases out, you turn,
/// and walk back to the desk with a soft stop. A cubic Hermite from the
/// current position and speed to rest at 0, so neither jumps.
class _TurnBackSimulation extends Simulation {
  _TurnBackSimulation({required this.from, required this.velocity})
    : seconds = (0.40 + from * 0.80).clamp(0.50, 1.0);

  final double from;
  final double velocity;
  final double seconds;

  /// A restarted ticker's first frame reads time zero, which would repeat the
  /// last walking frame; the turn starts one frame in so motion never stalls.
  static const _lead = 1 / 60;

  double _s(double time) => ((time + _lead) / seconds).clamp(0.0, 1.0);

  @override
  double x(double time) {
    final s = _s(time);
    final h00 = 2 * s * s * s - 3 * s * s + 1;
    final h10 = s * s * s - 2 * s * s + s;
    return (h00 * from + h10 * seconds * velocity).clamp(0.0, 1.0);
  }

  @override
  double dx(double time) {
    final s = _s(time);
    if (s >= 1) return 0;
    return (6 * s * s - 6 * s) * from / seconds +
        (3 * s * s - 4 * s + 1) * velocity;
  }

  @override
  bool isDone(double time) => time + _lead >= seconds;
}

/// The Goals walk into a goal's own room: the kitchen beyond the lit arch.
///
/// The arch you pass grows and slides out past both edges of the screen while
/// the kitchen beyond comes toward you, and only once you are standing in it
/// does the goal's page settle in. Leaving walks back out; leaving mid-walk
/// turns around (it reads as changing your mind, not a rewind).
///
/// Only the kitchen is walked. The workshop, the quest handoff and the
/// one-time opening keep [goalRoomRoute], a calm dolly with no motion blur.
GoalKitchenWalkRoute<T> goalKitchenWalkRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool reduceMotion = false,
  RouteSettings? settings,
}) {
  final still =
      reduceMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
  return GoalKitchenWalkRoute<T>._(
    settings: settings,
    still: still,
    builder: builder,
  );
}

/// The route returned by [goalKitchenWalkRoute].
class GoalKitchenWalkRoute<T> extends PageRouteBuilder<T> {
  GoalKitchenWalkRoute._({
    super.settings,
    required this.still,
    required WidgetBuilder builder,
  }) : super(
         transitionDuration: still
             ? goalRoomStillDuration
             : goalRoomWalkDuration,
         reverseTransitionDuration: still
             ? goalRoomStillReverseDuration
             : goalRoomWalkReverseDuration,
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
       );

  final bool still;
  _WalkTimeline _timeline = const _WalkTimeline.outbound();

  @override
  Simulation? createSimulation({required bool forward}) {
    final c = controller;
    if (forward || still || c == null) {
      if (!forward && !still) _timeline = const _WalkTimeline.returning();
      return null;
    }
    if (c.status == AnimationStatus.forward && c.value < 1) {
      // Back while still walking in: turn around from where you are. The walk
      // keeps its outbound shape, so position and speed stay continuous.
      return _TurnBackSimulation(from: c.value, velocity: c.velocity);
    }
    _timeline = const _WalkTimeline.returning();
    return null;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (still) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Motion.respond,
        reverseCurve: Curves.easeInCubic,
      );
      // A transparent still-to-still fade keeps the actual source page
      // visible underneath on reverse.
      return FadeTransition(
        key: const ValueKey('goal-room-reduced-motion-fade'),
        opacity: fade,
        child: child,
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final raw = animation.value.clamp(0.0, 1.0);
        final settled = animation.status == AnimationStatus.completed;
        final timeline = _timeline;
        final walkVelocity =
            timeline.walkSlope(raw) * (controller?.velocity ?? 0);
        return Stack(
          fit: StackFit.expand,
          children: [
            // Once you are standing in the kitchen its own (opaque) page
            // paints it; the walk's planes stay mounted for the walk back out
            // but cost nothing at rest.
            Offstage(
              offstage: settled,
              child: Opacity(
                opacity: timeline.source(raw),
                child: GoalKitchenWalkBackdrop(
                  progress: timeline.walk(raw),
                  walkVelocity: walkVelocity,
                ),
              ),
            ),
            IgnorePointer(
              ignoring: !settled,
              child: ExcludeSemantics(
                excluding: !settled,
                child: Opacity(
                  key: const ValueKey('goal-room-travel-foreground'),
                  opacity: timeline.page(raw),
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The calm Goals dolly: the apartment itself moving toward the arch, with no
/// motion blur. The workshop and the quest handoff go this way (the kitchen
/// has the walk, see [goalKitchenWalkRoute]).
///
/// Generic details use [detailRoute]; this route accepts the floor threshold,
/// lets the wide room hold for a breath, passes the lit arch, and only then
/// settles the exact Quest.
PageRoute<T> goalRoomRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool reduceMotion = false,
  RouteSettings? settings,
  GoalRoomInvitation? invitation,
  VoidCallback? onArrival,
  Duration arrivalHold = Duration.zero,
}) {
  final still =
      reduceMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
  var arrivalScheduled = false;
  var routeDeparted = false;
  var statusListenerAttached = false;
  late final PageRouteBuilder<T> route;

  void handleRouteStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward) {
      routeDeparted = true;
    }
    if (onArrival == null ||
        !routeDeparted ||
        arrivalScheduled ||
        status != AnimationStatus.completed) {
      return;
    }
    arrivalScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void deliver() {
        // A back gesture can dismiss the room while it is still travelling or
        // during the brief arrival hold. In either case, leaving is the user's
        // latest instruction and must cancel the automatic handoff.
        if (route.isActive && route.isCurrent) onArrival();
      }

      if (arrivalHold == Duration.zero) {
        deliver();
      } else {
        Future<void>.delayed(arrivalHold, deliver);
      }
    });
  }

  void observeArrival(Animation<double> animation) {
    if (!statusListenerAttached) {
      statusListenerAttached = true;
      animation.addStatusListener(handleRouteStatus);
    }
    // A freshly installed PageRoute can briefly expose a completed animation
    // before Navigator drives it forward from zero. `routeDeparted` prevents
    // that bootstrap frame from masquerading as the real destination.
    handleRouteStatus(animation.status);
  }

  route = PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: Duration(milliseconds: still ? 220 : 1640),
    reverseTransitionDuration: Duration(milliseconds: still ? 180 : 1160),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      observeArrival(animation);
      if (still) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Motion.respond,
          reverseCurve: Curves.easeInCubic,
        );
        // A transparent still-to-still fade keeps the actual source page
        // visible underneath on reverse. Holding a kitchen plate here made
        // Reduced Motion pop from kitchen to overview on the final frame.
        return FadeTransition(
          key: const ValueKey('goal-room-reduced-motion-fade'),
          opacity: fade,
          child: child,
        );
      }

      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final raw = animation.value.clamp(0.0, 1.0);
          // Leave the live wall, arch, and floor layers visible for the first
          // truthful frames. The route uses the same clean room master beneath
          // them, so acceptance becomes a continuous doorway crossing rather
          // than a cut to a second composition.
          final backdrop = Curves.easeInOutCubic.transform(
            _segment(raw, 0.0, 0.055),
          );
          // The kitchen page resolves over several frames. A three-frame
          // arrival reads as a flash; this slower exposure lets the doorway,
          // destination plate, and live document settle as one arrival.
          final foreground = Curves.easeOutCubic.transform(
            _segment(raw, 0.87, 1),
          );
          final settled = animation.status == AnimationStatus.completed;
          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: backdrop,
                child: GoalRoomTravelBackdrop(
                  progress: raw,
                  invitation: invitation,
                ),
              ),
              IgnorePointer(
                ignoring: !settled,
                child: ExcludeSemantics(
                  excluding: !settled,
                  child: Opacity(
                    key: const ValueKey('goal-room-travel-foreground'),
                    opacity: foreground,
                    child: child,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
  return route;
}
