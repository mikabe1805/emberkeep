import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'facets.dart';
import 'goal_primary_button.dart';

double _goalFlightSegment(double value, double begin, double end) =>
    ((value - begin) / (end - begin)).clamp(0.0, 1.0);

/// During the room journey, the commitment card becomes a doorway invitation
/// instead of remaining a dashboard panel pasted across the apartment. The
/// source and destination cards return untouched at the route endpoints.
Widget goalActionFlightShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final fromHero = fromHeroContext.widget as Hero;
  final toHero = toHeroContext.widget as Hero;
  final lowEndpoint = flightDirection == HeroFlightDirection.push
      ? fromHero.child
      : toHero.child;
  final highEndpoint = flightDirection == HeroFlightDirection.push
      ? toHero.child
      : fromHero.child;

  return Material(
    type: MaterialType.transparency,
    child: AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final value = animation.value.clamp(0.0, 1.0);
        final lowOpacity =
            1 -
            Curves.easeInCubic.transform(_goalFlightSegment(value, 0.04, 0.16));
        final highOpacity = Curves.easeOutCubic.transform(
          _goalFlightSegment(value, 0.995, 1),
        );
        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            Opacity(opacity: lowOpacity, child: lowEndpoint),
            Opacity(opacity: highOpacity, child: highEndpoint),
          ],
        );
      },
    ),
  );
}

/// One physical commitment surface: identity, current action, and the single
/// luminous way through. Nothing inside becomes a second card.
class GoalActionCard extends StatelessWidget {
  const GoalActionCard({
    super.key,
    required this.identityIcon,
    required this.accent,
    required this.title,
    required this.actionLabel,
    required this.actionIcon,
    required this.onTap,
    this.buttonKey,
    this.eyebrow,
    this.fullWidthButton = false,
    this.light,
    this.reduceMotion = false,
    this.semanticHint,
    this.buttonTreatment = GoalPrimaryButtonTreatment.openingClasp,
  });

  final IconData identityIcon;
  final Color accent;
  final String title;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onTap;
  final Key? buttonKey;
  final String? eyebrow;
  final bool fullWidthButton;
  final ValueListenable<Offset>? light;
  final bool reduceMotion;
  final String? semanticHint;
  final GoalPrimaryButtonTreatment buttonTreatment;

  @override
  Widget build(BuildContext context) {
    if (buttonTreatment == GoalPrimaryButtonTreatment.questFolio) {
      return GoalPrimaryButton(
        key: buttonKey,
        label: actionLabel,
        icon: actionIcon,
        onTap: onTap,
        expand: true,
        light: light,
        reduceMotion: reduceMotion,
        semanticHint: semanticHint ?? 'Open this goal action.',
        treatment: buttonTreatment,
        folioTitle: title,
        folioEyebrow: eyebrow,
        folioIcon: identityIcon,
        folioAccent: accent,
      );
    }
    return DecoratedBox(
      decoration: facetedDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xC4261B13), Color(0xE3140F0C)],
        ),
        cut: 12,
        borderColor: const Color(0x568F6A45),
        borderWidth: 1,
        shadows: const [
          BoxShadow(
            color: Color(0x52100805),
            blurRadius: 20,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            right: 20,
            top: 0,
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0x00F4D7A2),
                    Color(0x62F4D7A2),
                    Color(0x1AF4D7A2),
                    Color(0x00F4D7A2),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 14, 15),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                final stacked =
                    fullWidthButton ||
                    constraints.maxWidth < 340 ||
                    textScale > 1.2 ||
                    actionLabel.length > 18;

                // Let the rule grow with the live title instead of fixing it
                // to a decorative height. At large type, the exact next Quest
                // remains whole and the action plate simply moves below it.
                final actionTitle = IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 40,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Icon(identityIcon, size: 25, color: accent),
                        ),
                      ),
                      Container(
                        width: 1,
                        margin: const EdgeInsets.only(left: 3, right: 15),
                        color: const Color(0x3DDFC493),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (eyebrow case final copy?) ...[
                              Text(
                                copy,
                                style: copy == copy.toUpperCase()
                                    ? Type.label.copyWith(
                                        fontSize: Type.minLabel,
                                        height: 1.15,
                                        color: accent.withValues(alpha: 0.92),
                                      )
                                    : Type.body.copyWith(
                                        fontSize: 12,
                                        height: 1.15,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.08,
                                        color: accent.withValues(alpha: 0.92),
                                      ),
                              ),
                              const SizedBox(height: 7),
                            ],
                            Text(
                              title,
                              textScaler: MediaQuery.textScalerOf(
                                context,
                              ).clamp(maxScaleFactor: 1.45),
                              style: Type.display.copyWith(
                                fontSize: stacked ? 21 : 20,
                                height: 1.1,
                                fontWeight: FontWeight.w500,
                                color: Palette.textHi,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
                final button = GoalPrimaryButton(
                  key: buttonKey,
                  label: actionLabel,
                  icon: actionIcon,
                  onTap: onTap,
                  expand: stacked,
                  light: light,
                  reduceMotion: reduceMotion,
                  semanticHint: semanticHint ?? 'Open this goal action.',
                  treatment: buttonTreatment,
                );
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [actionTitle, const SizedBox(height: 14), button],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: actionTitle),
                    const SizedBox(width: 15),
                    SizedBox(width: 130, child: button),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
