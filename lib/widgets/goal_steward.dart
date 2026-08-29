import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

const goalsWorkshopTavernBackAsset =
    'assets/pages/goals-workshop-tavern-back-v2.webp';
const goalsWorkshopTavernCounterAsset =
    'assets/pages/goals-workshop-tavern-counter-v2.webp';
const goalsWorkshopStewardWelcomeAsset =
    'assets/pages/goals-workshop-steward-welcome-v2.webp';
const goalsWorkshopStewardConsideringAsset =
    'assets/pages/goals-workshop-steward-considering-v2.webp';
const goalsWorkshopStewardReadyAsset =
    'assets/pages/goals-workshop-steward-ready-v2.webp';
const goalsWorkshopStewardAcknowledgingAsset =
    'assets/pages/goals-workshop-steward-acknowledging-v2.webp';
const goalsWorkshopStewardClosingAsset =
    'assets/pages/goals-workshop-steward-closing-v2.webp';
const goalsWorkshopStewardFallbackAsset =
    'assets/pages/goals-workshop-tavern-steward-v1.webp';

/// Compatibility name for code that only needs the workshop's resting room.
/// The live workshop itself always composes all three planes below.
const goalsWorkshopTavernAsset = goalsWorkshopTavernBackAsset;

const goalStewardAssets = <String>[
  goalsWorkshopTavernBackAsset,
  goalsWorkshopTavernCounterAsset,
  goalsWorkshopStewardWelcomeAsset,
  goalsWorkshopStewardConsideringAsset,
  goalsWorkshopStewardReadyAsset,
  goalsWorkshopStewardAcknowledgingAsset,
  goalsWorkshopStewardClosingAsset,
];

/// The steward only changes expression when the workshop's real state changes.
/// These are not moods, idle loops, or a relationship score.
enum GoalStewardSituation {
  welcome,
  considering,
  cutReady,
  questAccepted,
  routeComplete,
}

enum GoalStewardExpression {
  welcome,
  considering,
  ready,
  acknowledging,
  closing,
}

GoalStewardExpression resolveGoalStewardExpression(
  GoalStewardSituation situation,
) => switch (situation) {
  GoalStewardSituation.welcome => GoalStewardExpression.welcome,
  GoalStewardSituation.considering => GoalStewardExpression.considering,
  GoalStewardSituation.cutReady => GoalStewardExpression.ready,
  GoalStewardSituation.questAccepted => GoalStewardExpression.acknowledging,
  GoalStewardSituation.routeComplete => GoalStewardExpression.closing,
};

/// Chooses the one expression the register should foreground when several
/// goals are present. A cut waiting for an explicit decision is most immediate;
/// unfinished shaping comes next, then already-owned work, then quiet closure.
GoalStewardExpression resolveGoalStewardRegisterExpression({
  required bool hasCutWaiting,
  required bool hasRouteToShape,
  required bool hasQuestOnBoard,
  required bool hasCompletedRoute,
}) {
  if (hasCutWaiting) {
    return resolveGoalStewardExpression(GoalStewardSituation.cutReady);
  }
  if (hasRouteToShape) {
    return resolveGoalStewardExpression(GoalStewardSituation.considering);
  }
  if (hasQuestOnBoard) {
    return resolveGoalStewardExpression(GoalStewardSituation.questAccepted);
  }
  if (hasCompletedRoute) {
    return resolveGoalStewardExpression(GoalStewardSituation.routeComplete);
  }
  return resolveGoalStewardExpression(GoalStewardSituation.welcome);
}

String goalStewardAsset(GoalStewardExpression expression) =>
    switch (expression) {
      GoalStewardExpression.welcome => goalsWorkshopStewardWelcomeAsset,
      GoalStewardExpression.considering => goalsWorkshopStewardConsideringAsset,
      GoalStewardExpression.ready => goalsWorkshopStewardReadyAsset,
      GoalStewardExpression.acknowledging =>
        goalsWorkshopStewardAcknowledgingAsset,
      GoalStewardExpression.closing => goalsWorkshopStewardClosingAsset,
    };

String goalStewardSemanticLabel(
  GoalStewardExpression expression,
) => switch (expression) {
  GoalStewardExpression.welcome =>
    'The workshop steward looks up attentively from behind the tavern counter.',
  GoalStewardExpression.considering =>
    'The workshop steward studies one route card, weighing the next cut.',
  GoalStewardExpression.ready =>
    'The workshop steward offers a prepared route card for you to accept or revise.',
  GoalStewardExpression.acknowledging =>
    'The workshop steward leans in with quiet warmth at the Quest now on the board.',
  GoalStewardExpression.closing =>
    'The workshop steward files the completed route card into the wooden box.',
};

void precacheGoalStewardAssets(BuildContext context) {
  for (final asset in goalStewardAssets) {
    precacheImage(AssetImage(asset), context);
  }
  precacheImage(const AssetImage(goalsWorkshopStewardFallbackAsset), context);
}

/// A fixed tavern room, a state-specific transparent steward, and a foreground
/// counter. The separated planes keep the character reusable and let the room
/// carry a few pixels of restrained depth without changing his authored pose.
class GoalStewardArtwork extends StatefulWidget {
  const GoalStewardArtwork({
    super.key,
    required this.expression,
    required this.reduceMotion,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.topCenter,
    this.parallax,
    this.light,
  });

  final GoalStewardExpression expression;
  final bool reduceMotion;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final ValueListenable<Offset>? parallax;

  /// Reserved for the shared room-light response. Keeping this notifier in the
  /// contract lets the Goals arrival and returnable Workshop share one motion
  /// source even though this illustration currently needs only camera depth.
  final ValueListenable<Offset>? light;

  @override
  State<GoalStewardArtwork> createState() => _GoalStewardArtworkState();
}

class _GoalStewardArtworkState extends State<GoalStewardArtwork> {
  bool _useFallback = false;

  Widget _fallbackArtwork({Key? key}) => Image.asset(
    goalsWorkshopStewardFallbackAsset,
    key: key,
    fit: widget.fit,
    alignment: widget.alignment,
    filterQuality: FilterQuality.medium,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF160F0B)),
  );

  void _handlePlaneError(Object error, StackTrace? stackTrace) {
    if (_useFallback) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_useFallback) setState(() => _useFallback = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final asset = goalStewardAsset(widget.expression);
    return Semantics(
      key: const Key('goal-workshop-steward'),
      image: true,
      label: _useFallback
          ? 'The workshop steward waits behind the tavern counter.'
          : goalStewardSemanticLabel(widget.expression),
      child: ClipRect(
        child: _useFallback
            ? _StewardDepthPlane(
                key: const ValueKey('goal-steward-fallback'),
                parallax: widget.parallax,
                reduceMotion: widget.reduceMotion,
                travel: const Offset(2.4, 1.5),
                child: _fallbackArtwork(
                  key: const Key('goal-workshop-steward-fallback-image'),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  _StewardDepthPlane(
                    parallax: widget.parallax,
                    reduceMotion: widget.reduceMotion,
                    travel: const Offset(1.35, 0.9),
                    child: Image.asset(
                      goalsWorkshopTavernBackAsset,
                      key: const Key('goal-workshop-steward-background'),
                      fit: widget.fit,
                      alignment: widget.alignment,
                      filterQuality: FilterQuality.medium,
                      excludeFromSemantics: true,
                      errorBuilder: (_, error, stackTrace) {
                        _handlePlaneError(error, stackTrace);
                        return _fallbackArtwork();
                      },
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: widget.reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      fit: StackFit.expand,
                      children: [...previousChildren, ?currentChild],
                    ),
                    child: _StewardDepthPlane(
                      key: ValueKey(
                        'goal-steward-pose-${widget.expression.name}',
                      ),
                      parallax: widget.parallax,
                      reduceMotion: widget.reduceMotion,
                      travel: const Offset(2.8, 1.8),
                      child: Image.asset(
                        asset,
                        key: ValueKey(
                          'goal-steward-expression-${widget.expression.name}',
                        ),
                        fit: widget.fit,
                        alignment: widget.alignment,
                        filterQuality: FilterQuality.medium,
                        excludeFromSemantics: true,
                        errorBuilder: (_, error, stackTrace) {
                          _handlePlaneError(error, stackTrace);
                          return _fallbackArtwork();
                        },
                      ),
                    ),
                  ),
                  _StewardDepthPlane(
                    parallax: widget.parallax,
                    reduceMotion: widget.reduceMotion,
                    travel: const Offset(4.0, 2.5),
                    child: Image.asset(
                      goalsWorkshopTavernCounterAsset,
                      key: const Key('goal-workshop-steward-counter'),
                      fit: widget.fit,
                      alignment: widget.alignment,
                      filterQuality: FilterQuality.medium,
                      excludeFromSemantics: true,
                      errorBuilder: (_, error, stackTrace) {
                        _handlePlaneError(error, stackTrace);
                        return _fallbackArtwork();
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _StewardDepthPlane extends StatelessWidget {
  const _StewardDepthPlane({
    super.key,
    required this.parallax,
    required this.reduceMotion,
    required this.travel,
    required this.child,
  });

  final ValueListenable<Offset>? parallax;
  final bool reduceMotion;
  final Offset travel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final source = parallax;
    if (source == null || reduceMotion) return _position(Offset.zero);
    return ValueListenableBuilder<Offset>(
      valueListenable: source,
      builder: (context, value, _) => _position(value),
    );
  }

  Widget _position(Offset value) => RepaintBoundary(
    child: Transform.translate(
      offset: Offset(value.dx * travel.dx, value.dy * travel.dy),
      child: Transform.scale(scale: 1.018, child: child),
    ),
  );
}
