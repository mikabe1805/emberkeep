// How a goal's own page arrives from the Steward's workshop.
//
// The goal page stands in the same painted room as the workshop (the Goals
// plate), so nothing needs to be walked through: the plate stays where it is
// and only the glass changes. A short cross-fade is the whole transition; under
// Reduce Motion it is shorter still.
library;

import 'package:flutter/material.dart';

import '../../../tokens.dart';

/// The route to a goal's page. [builder] is the page, which paints the Goals
/// plate itself.
PageRoute<T> houseGoalDetailRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool reduceMotion = false,
  RouteSettings? settings,
}) {
  final still =
      reduceMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: Duration(milliseconds: still ? 120 : 300),
    reverseTransitionDuration: Duration(milliseconds: still ? 100 : 240),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          key: const ValueKey('goal-detail-house-fade'),
          opacity: CurvedAnimation(
            parent: animation,
            curve: Motion.respond,
            reverseCurve: Curves.easeInCubic,
          ),
          child: child,
        ),
  );
}
