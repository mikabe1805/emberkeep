import 'package:flutter/material.dart';

import '../tokens.dart';
import 'goal_world.dart';

double _routeSegment(double value, double begin, double end) =>
    ((value - begin) / (end - begin)).clamp(0.0, 1.0);

/// A Goals-only route whose primary transition is the apartment itself.
///
/// Generic details use [detailRoute]; a living goal has a stronger contract:
/// accept the floor threshold, let the selected wide room hold for a breath,
/// pass the lit arch at walking speed, and only then settle the exact Quest.
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
            _routeSegment(raw, 0.0, 0.055),
          );
          // The kitchen page resolves over several frames. A three-frame
          // arrival reads as a flash; this slower exposure lets the doorway,
          // destination plate, and live document settle as one arrival.
          final foreground = Curves.easeOutCubic.transform(
            _routeSegment(raw, 0.87, 1),
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
