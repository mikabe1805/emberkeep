import 'package:flutter/material.dart';

import '../tokens.dart';

/// Builds a focused-detail route that preserves the source page's presence.
///
/// The incoming detail is a restrained scale/fade with a very small upward
/// shared-axis travel: a card becoming a closer view, not a new unrelated
/// screen. Callers supply their persisted in-app setting through
/// [reduceMotion]; the OS accessibility preference is read here as well.
///
/// Under Reduce Motion the same route remains a short fade. This keeps
/// navigational causality without retaining spatial movement or scale.
PageRoute<T> detailRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool reduceMotion = false,
  RouteSettings? settings,
  Widget? transitionBackdrop,
}) {
  final still =
      reduceMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
  final hasThreshold = transitionBackdrop != null;
  final duration = still
      ? Duration(milliseconds: hasThreshold ? 180 : 90)
      : Duration(milliseconds: hasThreshold ? 420 : 320);
  final reverseDuration = still
      ? Duration(milliseconds: hasThreshold ? 150 : 80)
      : Duration(milliseconds: hasThreshold ? 360 : 260);

  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: duration,
    reverseTransitionDuration: reverseDuration,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final response = CurvedAnimation(
        parent: animation,
        curve: Motion.respond,
        reverseCurve: Curves.easeInCubic,
      );
      if (transitionBackdrop case final backdrop?) {
        if (still) {
          return Stack(
            fit: StackFit.expand,
            children: [
              KeyedSubtree(
                key: const ValueKey('detail-route-threshold-backdrop'),
                child: backdrop,
              ),
              FadeTransition(
                key: const ValueKey('detail-route-fade'),
                opacity: response,
                child: child,
              ),
            ],
          );
        }
        final foreground = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.48, 1, curve: Curves.easeOutCubic),
          reverseCurve: const Interval(0, 0.72, curve: Curves.easeInCubic),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            SlideTransition(
              key: const ValueKey('detail-route-threshold-travel'),
              position: Tween<Offset>(
                begin: const Offset(0, 0.006),
                end: const Offset(0, -0.008),
              ).animate(response),
              child: ScaleTransition(
                key: const ValueKey('detail-route-threshold-backdrop'),
                scale: Tween<double>(begin: 1, end: 1.035).animate(response),
                alignment: Alignment.topCenter,
                child: backdrop,
              ),
            ),
            FadeTransition(
              key: const ValueKey('detail-route-fade'),
              opacity: foreground,
              child: SlideTransition(
                key: const ValueKey('detail-route-shared-axis'),
                position: Tween<Offset>(
                  begin: const Offset(0, 0.022),
                  end: Offset.zero,
                ).animate(foreground),
                child: ScaleTransition(
                  key: const ValueKey('detail-route-scale'),
                  scale: Tween<double>(
                    begin: 0.992,
                    end: 1,
                  ).animate(foreground),
                  child: child,
                ),
              ),
            ),
          ],
        );
      }
      if (still) {
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF100D0B)),
            FadeTransition(
              key: const ValueKey('detail-route-fade'),
              opacity: Tween<double>(begin: 0.86, end: 1).animate(response),
              child: child,
            ),
          ],
        );
      }

      // Cover the outgoing page before the incoming foreground settles. A
      // conventional whole-page crossfade doubles every line of type midway
      // through the route and makes a same-room transition look like two
      // unrelated dashboards ghosting through each other. The espresso field
      // keeps the route opaque while the shared room gently brightens, rises,
      // and resolves into its closer view.
      return Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF100D0B)),
          FadeTransition(
            key: const ValueKey('detail-route-fade'),
            opacity: Tween<double>(begin: 0.86, end: 1).animate(response),
            child: SlideTransition(
              key: const ValueKey('detail-route-shared-axis'),
              position: Tween<Offset>(
                begin: const Offset(0, 0.016),
                end: Offset.zero,
              ).animate(response),
              child: ScaleTransition(
                key: const ValueKey('detail-route-scale'),
                scale: Tween<double>(begin: 0.985, end: 1).animate(response),
                child: child,
              ),
            ),
          ),
        ],
      );
    },
  );
}
