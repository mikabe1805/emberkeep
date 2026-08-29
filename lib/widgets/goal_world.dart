import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'goal_primary_button.dart';
import 'goal_steward.dart';

export 'goal_steward.dart'
    show goalsWorkshopTavernAsset, precacheGoalStewardAssets;

/// The Goals room is a portrait composition authored from the selected
/// "living commitment" target. Live goals, quests, and controls always remain
/// Flutter siblings above it.
const goalsLivingBackdropAsset = 'assets/pages/goals-living-backdrop-v2.webp';
const goalsLivingBackdropSoftAsset =
    'assets/pages/goals-living-backdrop-soft-v2.webp';

/// The owner-selected wide-threshold apartment, cleaned of every baked UI
/// mark. The resting Goals screen and the room route share this exact plate so
/// pressing the floor threshold cannot jump to a differently shaped arch.
const goalsRoomContinuousAsset = 'assets/pages/goals-threshold-room-v1.webp';
const goalsRoomRetreatAsset = 'assets/pages/goals-room-retreat-v1.webp';
const goalsRoomKitchenAsset = 'assets/pages/goals-room-kitchen-v1.webp';
const goalsRoomRestScale = 1.0;
const goalsRoomRestTranslation = Offset.zero;
const goalsRoomKitchenScale = 1.025;

const goalsWorldAlignment = Alignment(-0.42, 0);

/// The overview keeps the upper room legible, then lets the desk gradually
/// become the reading surface. There is no banner edge: atmosphere, type, and
/// action all occupy one continuous world.
const goalsOverviewScrim = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0x12000000),
    Color(0x00000000),
    Color(0x24120B07),
    Color(0x62120B07),
    Color(0xB4100D0B),
    Color(0xE8100D0B),
  ],
  stops: [0, 0.24, 0.43, 0.61, 0.82, 1],
);

/// Detail is the same room at a closer, more concentrated reading distance.
const goalsDetailScrim = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0x28080503),
    Color(0x00000000),
    Color(0x2E120B07),
    Color(0x8A120B07),
    Color(0xE4100D0B),
    Color(0xFA100D0B),
  ],
  stops: [0, 0.18, 0.38, 0.62, 0.82, 1],
);

/// The kitchen is the payoff of the room journey, so its light stays present
/// behind the first detail frame. The heavier reading veil still arrives near
/// the bottom where longer goal content needs it.
const goalsKitchenDetailScrim = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0x1C080503),
    Color(0x00000000),
    Color(0x20120B07),
    Color(0x64120B07),
    Color(0xC8100D0B),
    Color(0xF4100D0B),
  ],
  stops: [0, 0.2, 0.42, 0.68, 0.86, 1],
);

/// The workshop keeps the steward, card drawers, and amber lamp readable above
/// the bench, then settles into a quiet lower field for live route controls.
const goalsWorkshopDetailScrim = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0x08080503),
    Color(0x00000000),
    Color(0x12120B07),
    Color(0x46120B07),
    Color(0xC8100D0B),
    Color(0xF8100D0B),
  ],
  stops: [0, 0.18, 0.42, 0.66, 0.84, 1],
);

/// The travel frame keeps more of the desk, mug, and candle visible than the
/// reading state. It lets the camera move through a recognizable room before
/// the denser detail scrim settles behind live content.
const goalsThresholdScrim = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0x28080503),
    Color(0x05000000),
    Color(0x3D120B07),
    Color(0x77120B07),
    Color(0x98100D0B),
    Color(0xD2100D0B),
  ],
  stops: [0, 0.18, 0.34, 0.55, 0.78, 1],
);

/// At the wide threshold the room needs to be seen, not buried beneath the
/// reading scrim. The warmer lower edge still protects live type without
/// turning the environment into a banner over a dark page.
const goalsWideRoomScrim = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0x16000000),
    Color(0x00000000),
    Color(0x18120B07),
    Color(0x48120B07),
    Color(0x88100D0B),
  ],
  stops: [0, 0.28, 0.52, 0.76, 1],
);

class GoalRoomCameraPose {
  const GoalRoomCameraPose({required this.scale, required this.translation});

  final double scale;
  final Offset translation;

  static GoalRoomCameraPose lerp(
    GoalRoomCameraPose begin,
    GoalRoomCameraPose end,
    double t,
  ) => GoalRoomCameraPose(
    scale: begin.scale + (end.scale - begin.scale) * t,
    translation: Offset.lerp(begin.translation, end.translation, t)!,
  );
}

const _goalsWidePose = GoalRoomCameraPose(scale: 1, translation: Offset.zero);
const _goalsOpeningDeskPose = GoalRoomCameraPose(
  scale: 1.16,
  translation: Offset(0.08, -0.065),
);
const _goalsOpeningArchPose = GoalRoomCameraPose(
  scale: 1.56,
  translation: Offset(-0.12, 0.10),
);
// The final master pose is registered to the pendant and arch in the kitchen
// destination plate. Pushing all the way to this pose makes the last third a
// real doorway crossing; the previous 1.66x pose stopped in the living room
// and forced the destination image to do the travelling as a dissolve.
const _goalsKitchenHandoffPose = GoalRoomCameraPose(
  scale: 2.22,
  translation: Offset(-0.25, 0.19),
);
const _goalsKitchenStartPose = GoalRoomCameraPose(
  scale: 1,
  translation: Offset.zero,
);
const _goalsKitchenSettledPose = GoalRoomCameraPose(
  scale: goalsRoomKitchenScale,
  translation: Offset.zero,
);

double _roomSegment(double value, double begin, double end) {
  if (end <= begin) return value >= end ? 1 : 0;
  return ((value - begin) / (end - begin)).clamp(0.0, 1.0);
}

double _roomPulse(double value, double begin, double peak, double end) {
  if (value <= begin || value >= end) return 0;
  if (value <= peak) return _roomSegment(value, begin, peak);
  return 1 - _roomSegment(value, peak, end);
}

GoalRoomCameraPose _masterPoseFor(
  double progress, {
  required bool openingSequence,
}) {
  if (openingSequence) {
    if (progress <= 0.22) {
      return GoalRoomCameraPose.lerp(
        _goalsOpeningDeskPose,
        _goalsWidePose,
        Curves.easeOutCubic.transform(_roomSegment(progress, 0, 0.22)),
      );
    }
    if (progress <= 0.60) {
      return GoalRoomCameraPose.lerp(
        _goalsWidePose,
        _goalsOpeningArchPose,
        const Cubic(
          0.20,
          0.72,
          0.18,
          1,
        ).transform(_roomSegment(progress, 0.22, 0.60)),
      );
    }
    return GoalRoomCameraPose.lerp(
      _goalsOpeningArchPose,
      _goalsKitchenHandoffPose,
      const Cubic(
        0.42,
        0.02,
        0.18,
        1,
      ).transform(_roomSegment(progress, 0.60, 0.955)),
    );
  }
  if (progress < 0.12) return _goalsWidePose;
  final crossing = const Cubic(
    0.42,
    0.02,
    0.18,
    1,
  ).transform(_roomSegment(progress, 0.12, 0.955));
  return GoalRoomCameraPose.lerp(
    _goalsWidePose,
    _goalsKitchenHandoffPose,
    crossing,
  );
}

/// Live information that is visually registered to the lit arch during the
/// room journey. It remains Flutter-owned so real action names can reflow.
class GoalRoomInvitation {
  const GoalRoomInvitation({
    required this.cue,
    required this.actionTitle,
    this.fallbackAction,
    this.actionLabel,
    this.actionKey,
    this.onTap,
    this.semanticHint,
  });

  final String cue;
  final String actionTitle;
  final String? fallbackAction;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onTap;
  final String? semanticHint;
}

/// The quiet destination frame used when a returning goal carries straight on
/// to its exact Quest. It is intentionally not another card or confirmation:
/// the room has already accepted the tap, so this frame only lets the tavern
/// settle and names what is about to open.
class GoalQuestArrivalPlate extends StatelessWidget {
  const GoalQuestArrivalPlate({
    super.key,
    required this.actionTitle,
    required this.accent,
  });

  final String actionTitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2;
    const roomShadow = <Shadow>[
      Shadow(color: Color(0xE8100906), blurRadius: 18, offset: Offset(0, 4)),
      Shadow(color: Color(0x9A100906), blurRadius: 4, offset: Offset(0, 1)),
    ];
    return Semantics(
      key: const ValueKey('goal-quest-arrival'),
      container: true,
      liveRegion: true,
      label: 'Opening $actionTitle on your Quest board.',
      child: ColoredBox(
        color: const Color(0xFF100D0B),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ExcludeSemantics(
              child: GoalStewardArtwork(
                expression: GoalStewardExpression.acknowledging,
                reduceMotion: true,
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: goalsWorkshopDetailScrim),
            ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 20 : 28,
                  24,
                  compact ? 20 : 28,
                  compact ? 34 : 48,
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next Quest',
                          style: const TextStyle(
                            fontFamily: 'EBGaramond',
                            fontSize: 16.5,
                            height: 1.05,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.12,
                            decoration: TextDecoration.none,
                          ).copyWith(color: accent, shadows: roomShadow),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          actionTitle,
                          style: Type.display.copyWith(
                            fontSize: compact ? 25 : 29,
                            height: 1.06,
                            fontWeight: FontWeight.w500,
                            color: Palette.textHi,
                            shadows: roomShadow,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 11),
                        Row(
                          children: [
                            Container(
                              width: compact ? 36 : 48,
                              height: 1.5,
                              color: accent.withValues(alpha: 0.82),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Opening on your Quest board',
                                style: Type.body.copyWith(
                                  fontSize: 13,
                                  height: 1.25,
                                  color: Palette.textMid,
                                  shadows: roomShadow,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Goals-specific camera montage. It keeps one continuous room master
/// intact while withdrawing to the approved wide composition, then crosses
/// the painted arch before the steward's separated tavern planes settle. The
/// source apartment remains one plate; the destination room, steward, and
/// counter share exact registration and only carry a few pixels of depth.
class GoalRoomTravelBackdrop extends StatelessWidget {
  const GoalRoomTravelBackdrop({
    super.key,
    required this.progress,
    this.invitation,
    this.openingSequence = false,
    this.motionBlur,
    this.destinationExpression = GoalStewardExpression.ready,
    this.destinationParallax,
    this.destinationLight,
    this.reduceMotion = false,
    this.sourceAsset = goalsRoomContinuousAsset,
  });

  final double progress;
  final GoalRoomInvitation? invitation;
  final bool openingSequence;
  final GoalStewardExpression destinationExpression;
  final ValueListenable<Offset>? destinationParallax;
  final ValueListenable<Offset>? destinationLight;
  final bool reduceMotion;
  final String sourceAsset;

  /// An optional velocity-derived blur amount. The one-time opening supplies
  /// this so its wide-room hold resolves completely even though the same
  /// progress value can be crossed at several deliberately different speeds.
  final double? motionBlur;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    final masterPose = _masterPoseFor(value, openingSequence: openingSequence);
    final destinationMix = Curves.easeInOutCubic.transform(
      _roomSegment(value, 0.82, 0.97),
    );
    final destinationPose = GoalRoomCameraPose.lerp(
      _goalsKitchenStartPose,
      _goalsKitchenSettledPose,
      Curves.easeOutCubic.transform(destinationMix),
    );
    final arrival = _roomSegment(value, 0.70, 1);
    final scrim = value < 0.58
        ? goalsWideRoomScrim
        : Gradient.lerp(goalsWideRoomScrim, goalsWorkshopDetailScrim, arrival)!;
    final thresholdWarmth =
        Curves.easeOutCubic.transform(_roomPulse(value, 0.18, 0.55, 0.75)) *
        0.15;
    final crossingExposure =
        Curves.easeInOutCubic.transform(_roomPulse(value, 0.64, 0.86, 0.985)) *
        0.22;
    final crossingDepth =
        Curves.easeInOutCubic.transform(_roomPulse(value, 0.66, 0.83, 0.98)) *
        0.34;
    final handoffVeil = Curves.easeInOutCubic.transform(
      _roomPulse(destinationMix, 0.04, 0.50, 0.96),
    );
    // The room is the only blurred plane. Live type and controls stay crisp,
    // while the painted camera picks up a very small velocity softness at the
    // two fastest parts of the move and resolves completely at every rest.
    final retreatBlur =
        Curves.easeInOutCubic.transform(_roomPulse(value, 0.10, 0.32, 0.56)) *
        0.72;
    final crossingBlur =
        Curves.easeInOutCubic.transform(_roomPulse(value, 0.62, 0.82, 0.965)) *
        2.1;
    final sourceBlur = motionBlur ?? retreatBlur + crossingBlur;
    final destinationBlur = motionBlur == null
        ? crossingBlur * 0.46
        : motionBlur! * 0.46;
    final invitationIn = Curves.easeOutCubic.transform(
      openingSequence
          ? _roomSegment(value, 0.16, 0.22)
          : _roomSegment(value, 0.04, 0.12),
    );
    // Release the supporting copy first, then the action itself. The workshop
    // title does not enter until the latter has fully cleared, so the same
    // sentence never appears twice during the material handoff.
    final invitationSupportOut = Curves.easeOutCubic.transform(
      _roomSegment(value, 0.62, 0.73),
    );
    final invitationTitleOut = Curves.easeInCubic.transform(
      _roomSegment(value, 0.76, 0.82),
    );
    final invitationSupportOpacity = 1 - invitationSupportOut;
    final invitationTitleOpacity = 1 - invitationTitleOut;
    final invitationVisibility =
        invitationIn *
        math.max(invitationSupportOpacity, invitationTitleOpacity);
    final invitationScale =
        0.985 +
        Curves.easeOutCubic.transform(_roomSegment(value, 0.49, 0.60)) * 0.015;

    return KeyedSubtree(
      key: const ValueKey('goal-room-travel-backdrop'),
      child: ColoredBox(
        color: const Color(0xFF100D0B),
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              Widget plate({
                required Key key,
                required Widget child,
                required GoalRoomCameraPose pose,
                required double blur,
                required Key blurKey,
              }) {
                Widget paintedPlate = RepaintBoundary(
                  child: Transform.translate(
                    key: key,
                    offset: Offset(
                      constraints.maxWidth * pose.translation.dx,
                      constraints.maxHeight * pose.translation.dy,
                    ),
                    child: Transform.scale(scale: pose.scale, child: child),
                  ),
                );
                if (blur <= 0.01) return paintedPlate;
                paintedPlate = ImageFiltered(
                  key: blurKey,
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: blur * 0.72,
                    sigmaY: blur,
                  ),
                  child: paintedPlate,
                );
                return paintedPlate;
              }

              final sourceRelease = Curves.easeInCubic.transform(
                _roomSegment(destinationMix, 0.26, 0.98),
              );
              final destinationReveal = Curves.easeOutCubic.transform(
                _roomSegment(destinationMix, 0.08, 0.84),
              );

              return Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: 1 - sourceRelease,
                    child: plate(
                      key: const ValueKey('goal-room-travel-master'),
                      child: Image.asset(
                        sourceAsset,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        filterQuality: FilterQuality.medium,
                        excludeFromSemantics: true,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint(
                            'Goals room art failed to load: $sourceAsset ($error)',
                          );
                          return Image.asset(
                            goalsRoomRetreatAsset,
                            key: const Key('goal-room-source-fallback'),
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            filterQuality: FilterQuality.medium,
                            excludeFromSemantics: true,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              key: Key('goal-room-source-fallback-color'),
                              color: Color(0xFF160F0B),
                            ),
                          );
                        },
                      ),
                      pose: masterPose,
                      blur: sourceBlur,
                      blurKey: const ValueKey('goal-room-travel-motion-blur'),
                    ),
                  ),
                  if (destinationMix > 0)
                    Opacity(
                      opacity: destinationReveal,
                      child: plate(
                        key: const ValueKey('goal-room-travel-destination'),
                        child: ExcludeSemantics(
                          child: GoalStewardArtwork(
                            expression: destinationExpression,
                            reduceMotion: reduceMotion,
                            parallax: destinationParallax,
                            light: destinationLight,
                          ),
                        ),
                        pose: destinationPose,
                        blur: destinationBlur,
                        blurKey: const ValueKey(
                          'goal-room-travel-destination-blur',
                        ),
                      ),
                    ),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0.32, -0.08),
                          radius: 0.58,
                          colors: [
                            Color.fromRGBO(
                              255,
                              206,
                              127,
                              thresholdWarmth +
                                  crossingExposure +
                                  handoffVeil * 0.58,
                            ),
                            Color.fromRGBO(
                              223,
                              146,
                              61,
                              (thresholdWarmth +
                                      crossingExposure +
                                      handoffVeil * 0.58) *
                                  0.38,
                            ),
                            const Color(0x00170F0A),
                          ],
                          stops: const [0, 0.38, 1],
                        ),
                      ),
                    ),
                  ),
                  if (crossingDepth > 0)
                    IgnorePointer(
                      child: Opacity(
                        opacity: crossingDepth,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment(0.32, -0.08),
                              radius: 0.76,
                              colors: [
                                Color(0x000A0705),
                                Color(0x000A0705),
                                Color(0xA80A0705),
                              ],
                              stops: [0, 0.5, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (invitation case final invitationData?
                      when invitationVisibility > 0)
                    _GoalRoomArchInvitationAnchor(
                      key: const ValueKey('goal-room-arch-invitation'),
                      pose: masterPose,
                      opacity: invitationIn,
                      supportOpacity: invitationSupportOpacity,
                      titleOpacity: invitationTitleOpacity,
                      scale: invitationScale,
                      cue: invitationData.cue,
                      actionTitle: invitationData.actionTitle,
                      fallbackAction: invitationData.fallbackAction,
                      actionLabel: invitationData.actionLabel,
                      actionKey: invitationData.actionKey,
                      onTap: invitationData.onTap,
                      semanticHint: invitationData.semanticHint,
                    ),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: scrim),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GoalRoomArchInvitationAnchor extends StatelessWidget {
  const _GoalRoomArchInvitationAnchor({
    super.key,
    required this.pose,
    required this.opacity,
    required this.supportOpacity,
    required this.titleOpacity,
    required this.scale,
    required this.cue,
    required this.actionTitle,
    required this.fallbackAction,
    required this.actionLabel,
    required this.actionKey,
    required this.onTap,
    required this.semanticHint,
  });

  final GoalRoomCameraPose pose;
  final double opacity;
  final double supportOpacity;
  final double titleOpacity;
  final double scale;
  final String cue;
  final String actionTitle;
  final String? fallbackAction;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onTap;
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final center = Offset(
          constraints.maxWidth / 2,
          constraints.maxHeight / 2,
        );
        // This anchor is measured against the wide master plate's arch.
        // Applying the same camera pose keeps the invitation on the lit
        // doorway instead of inside the unrelated Hero rectangle.
        final baseAnchor = Offset(
          constraints.maxWidth * 0.65,
          constraints.maxHeight * 0.445,
        );
        final anchor = Offset(
          center.dx +
              (baseAnchor.dx - center.dx) * pose.scale +
              constraints.maxWidth * pose.translation.dx,
          center.dy +
              (baseAnchor.dy - center.dy) * pose.scale +
              constraints.maxHeight * pose.translation.dy,
        );
        final viewportScale = (constraints.maxWidth / 430).clamp(0.88, 1.0);
        final textScaler = MediaQuery.textScalerOf(context);
        final hasAction = actionLabel != null;
        final hasFallback = fallbackAction?.trim().isNotEmpty ?? false;
        final interactive = onTap != null && actionLabel != null;
        final panelWidth = (constraints.maxWidth * (hasAction ? 0.79 : 0.46))
            .clamp(176.0, hasAction ? 340.0 : 220.0)
            .toDouble();
        final copyWidth = panelWidth - 30;
        double measuredTextHeight(
          String text,
          TextStyle style, {
          required int maxLines,
        }) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: textScaler,
            maxLines: maxLines,
            ellipsis: '…',
          )..layout(maxWidth: copyWidth);
          return painter.height;
        }

        final cueHeight = measuredTextHeight(
          cue,
          Type.body.copyWith(
            fontSize: 12,
            height: 1.15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          maxLines: 2,
        );
        final actionHeight = measuredTextHeight(
          actionTitle,
          const TextStyle(
            fontFamily: 'EBGaramond',
            fontSize: 27,
            height: 0.98,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.08,
          ),
          maxLines: 3,
        );
        var contentHeight = cueHeight + 9 + actionHeight;
        if (hasFallback) {
          contentHeight +=
              9 +
              measuredTextHeight(
                'Lighter version',
                Type.body.copyWith(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
              ) +
              3 +
              measuredTextHeight(
                fallbackAction!.trim(),
                Type.body.copyWith(fontSize: 13, height: 1.26),
                maxLines: 3,
              );
        }
        contentHeight += hasAction ? 12 + 50 : 11 + 2;
        // TextPainter and RenderParagraph differ slightly once the custom
        // variable font and test text scaler are resolved. Keep one line of
        // honest breathing room rather than letting the arch crop live copy.
        final panelHeight = (contentHeight + (hasAction ? 57 : 61))
            .clamp(hasAction ? 218.0 : 166.0, constraints.maxHeight - 20)
            .ceilToDouble();
        final safePadding = MediaQuery.paddingOf(context);
        final panelLeft = (anchor.dx - panelWidth / 2)
            .clamp(10.0, constraints.maxWidth - panelWidth - 10)
            .toDouble();
        final panelTop = (anchor.dy - panelHeight / 2)
            .clamp(
              safePadding.top + 10,
              constraints.maxHeight - panelHeight - safePadding.bottom - 10,
            )
            .toDouble();

        Widget panel = Stack(
          children: [
            Positioned(
              left: panelLeft,
              top: panelTop,
              width: panelWidth,
              height: panelHeight,
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale * viewportScale,
                  child: Material(
                    type: MaterialType.transparency,
                    child: _GoalRoomArchInvitation(
                      cue: cue,
                      actionTitle: actionTitle,
                      supportOpacity: supportOpacity,
                      titleOpacity: titleOpacity,
                      fallbackAction: fallbackAction,
                      actionLabel: actionLabel,
                      actionKey: actionKey,
                      onTap: onTap,
                      semanticHint: semanticHint,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
        return IgnorePointer(
          ignoring: !interactive,
          child: ExcludeSemantics(excluding: !interactive, child: panel),
        );
      },
    );
  }
}

class _GoalRoomArchInvitation extends StatelessWidget {
  const _GoalRoomArchInvitation({
    required this.cue,
    required this.actionTitle,
    required this.supportOpacity,
    required this.titleOpacity,
    this.fallbackAction,
    this.actionLabel,
    this.actionKey,
    this.onTap,
    this.semanticHint,
  });

  final String cue;
  final String actionTitle;
  final double supportOpacity;
  final double titleOpacity;
  final String? fallbackAction;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onTap;
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    final fallback = fallbackAction?.trim();
    final hasAction = actionLabel != null;
    final interactive = onTap != null && hasAction;
    final semanticLabel =
        '$cue. $actionTitle${fallback == null || fallback.isEmpty ? '' : '. Lighter if needed: $fallback'}';
    const roomShadows = <Shadow>[
      Shadow(color: Color(0xE50B0705), blurRadius: 9, offset: Offset(0, 2)),
    ];
    final animationsDisabled =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      key: const ValueKey('goal-room-arch-plan'),
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Opacity(
              opacity: supportOpacity,
              child: Text(
                cue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'EBGaramond',
                  fontSize: 15.5,
                  height: 1.05,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.08,
                  color: Color(0xFFD5A257),
                  shadows: roomShadows,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Opacity(
              key: const ValueKey('goal-room-arch-title-opacity'),
              opacity: titleOpacity,
              child: Text(
                actionTitle,
                key: const ValueKey('goal-room-arch-action-title'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'EBGaramond',
                  fontSize: 27,
                  height: 0.98,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.08,
                  color: Color(0xFFF0E5D2),
                  shadows: roomShadows,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            if (fallback != null && fallback.isNotEmpty) ...[
              const SizedBox(height: 9),
              Opacity(
                opacity: supportOpacity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Lighter version',
                      textAlign: TextAlign.center,
                      style: Type.body.copyWith(
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: Palette.xpLight,
                        shadows: roomShadows,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      fallback,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Type.body.copyWith(
                        fontSize: 13,
                        height: 1.26,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFF0E5D2),
                        shadows: roomShadows,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 13),
            Opacity(
              opacity: supportOpacity,
              child: Row(
                children: [
                  const Expanded(
                    child: Divider(height: 1, color: Color(0xA6D49D45)),
                  ),
                  Transform.rotate(
                    angle: 0.785,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFD9A74E),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Divider(height: 1, color: Color(0xA6D49D45)),
                  ),
                ],
              ),
            ),
            if (hasAction) ...[
              const SizedBox(height: 12),
              ExcludeSemantics(
                excluding: !interactive,
                child: IgnorePointer(
                  ignoring: !interactive,
                  child: AnimatedOpacity(
                    key: const ValueKey('goal-room-arch-action-opacity'),
                    duration: animationsDisabled ? Duration.zero : Motion.quick,
                    curve: Motion.respond,
                    opacity: interactive ? 1 : 0,
                    child: Align(
                      child: SizedBox(
                        width: 176,
                        height: 50,
                        child: GoalPrimaryButton(
                          key:
                              actionKey ??
                              const ValueKey('goal-room-arch-step-in'),
                          label: actionLabel!,
                          icon: Icons.arrow_forward_rounded,
                          onTap: onTap ?? () {},
                          enabled: interactive,
                          glow: false,
                          reduceMotion: true,
                          treatment: GoalPrimaryButtonTreatment.openingClasp,
                          semanticHint:
                              semanticHint ?? 'Continue into this goal.',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String goalActionHeroTag(String title) =>
    'goal-world-action-${title.trim().toLowerCase()}';

/// The room-only threshold frame used while the overview becomes detail.
/// It deliberately contains no live copy: route Heroes carry the goal and
/// current action while the camera moves through the same authored place.
class GoalWorldBackdrop extends StatelessWidget {
  const GoalWorldBackdrop({
    super.key,
    this.scrim = goalsDetailScrim,
    this.scale = 1.025,
    this.softened = false,
  });

  final Gradient scrim;
  final double scale;
  final bool softened;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF100D0B),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: Image.asset(
                softened
                    ? goalsLivingBackdropSoftAsset
                    : goalsLivingBackdropAsset,
                fit: BoxFit.cover,
                alignment: goalsWorldAlignment,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              ),
            ),
            DecoratedBox(decoration: BoxDecoration(gradient: scrim)),
          ],
        ),
      ),
    );
  }
}
