import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../audio.dart';
import '../tokens.dart';
import 'goal_primary_button.dart';
import 'goal_world.dart';
import 'pressable.dart';

/// The owner-selected returning Goals composition.
///
/// It is deliberately authored as one 430 x 932 room plate. Goal identity is
/// registered to the wall, the current Quest belongs inside the lit arch, and
/// the tavern workshop is mounted to that threshold instead of being written
/// across the floor. The complete scene scales with phone width so those
/// relationships do not collapse back into a vertical card layout.
class GoalThresholdScene extends StatelessWidget {
  const GoalThresholdScene({
    super.key,
    required this.goalTitle,
    required this.evidenceCopy,
    this.routePosition,
    required this.cue,
    required this.actionTitle,
    required this.actionLabel,
    required this.actionIcon,
    this.actionSemanticHint,
    required this.onReview,
    required this.onNewGoal,
    this.onOpenWorkshop,
    this.workshopStatus = 'routes inside',
    required this.onAction,
    required this.light,
    required this.reduceMotion,
    this.recoveryAction,
    this.recoverySemanticHint,
    this.onRecovery,
  });

  final String goalTitle;
  final String evidenceCopy;
  final String? routePosition;
  final String cue;
  final String actionTitle;
  final String actionLabel;
  final IconData actionIcon;
  final String? actionSemanticHint;
  final VoidCallback onReview;
  final VoidCallback onNewGoal;
  final VoidCallback? onOpenWorkshop;
  final String workshopStatus;
  final VoidCallback onAction;
  final String? recoveryAction;
  final String? recoverySemanticHint;
  final VoidCallback? onRecovery;
  final ValueListenable<Offset> light;
  final bool reduceMotion;

  static const _ink = Color(0xFFE7DAC6);
  static const _warmInk = Color(0xFFC99550);
  static const _quietInk = Color(0xFFAD7E50);
  static const _roomShadow = <Shadow>[
    Shadow(color: Color(0xA8100906), blurRadius: 9, offset: Offset(0, 2)),
    Shadow(color: Color(0x56100906), blurRadius: 2, offset: Offset(0, 1)),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label:
          '$goalTitle. ${routePosition == null ? '' : '$routePosition. '}$evidenceCopy Current action: $actionTitle',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sceneWidth = constraints.maxWidth;
          final sceneHeight = sceneWidth * (932 / 430);
          return SizedBox(
            width: sceneWidth,
            height: sceneHeight,
            child: FittedBox(
              fit: BoxFit.fill,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 430,
                height: 932,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _RoomPlate(light: light, reduceMotion: reduceMotion),
                    const _RegisteredLightVeil(),
                    Positioned(
                      left: 324,
                      top: 44,
                      width: 94,
                      height: 54,
                      child: _ThresholdNewGoal(onTap: onNewGoal),
                    ),
                    Positioned(
                      left: 68,
                      top: 122,
                      width: 136,
                      height: 84,
                      child: _GoalWallTitle(title: goalTitle, onTap: onReview),
                    ),
                    Positioned(
                      left: 68,
                      top: 204,
                      width: 166,
                      height: 54,
                      child: _ReturnEvidence(copy: evidenceCopy),
                    ),
                    Positioned(
                      left: 203,
                      top: 420,
                      width: 172,
                      height: 58,
                      child: _RouteInscription(
                        routePosition: routePosition,
                        reason: cue,
                      ),
                    ),
                    Positioned(
                      left: 208,
                      top: 476,
                      width: 160,
                      height: 82,
                      child: _ArchQuestTitle(title: actionTitle),
                    ),
                    const Positioned(
                      left: 252,
                      top: 550,
                      width: 72,
                      height: 12,
                      child: _ArchRule(),
                    ),
                    if (onOpenWorkshop case final openWorkshop?)
                      Positioned(
                        left: 219,
                        top: 320,
                        width: 156,
                        height: 64,
                        child: _TavernWorkshopSign(
                          status: workshopStatus,
                          onTap: openWorkshop,
                        ),
                      ),
                    Positioned(
                      left: 190,
                      top: 574,
                      width: 185,
                      height: 58,
                      child: GoalPrimaryButton(
                        key: const Key('focus-goal-action'),
                        label: actionLabel,
                        pendingLabel: 'Opening',
                        icon: actionIcon,
                        onTap: onAction,
                        expand: true,
                        glow: false,
                        light: light,
                        reduceMotion: reduceMotion,
                        treatment: GoalPrimaryButtonTreatment.openingClasp,
                        semanticHint:
                            actionSemanticHint ??
                            'Cross the room and open this exact Quest.',
                      ),
                    ),
                    if (recoveryAction case final recovery?)
                      Positioned(
                        left: 198,
                        top: 638,
                        width: 170,
                        height: 42,
                        child: _ArchRecoveryAction(
                          label: recovery,
                          semanticHint: recoverySemanticHint,
                          onTap: onRecovery,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RoomPlate extends StatelessWidget {
  const _RoomPlate({required this.light, required this.reduceMotion});

  final ValueListenable<Offset> light;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final still =
        reduceMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return AnimatedBuilder(
      animation: light,
      builder: (context, _) {
        final tilt = still ? Offset.zero : light.value;
        return ClipRect(
          child: Transform.translate(
            offset: Offset(-tilt.dx * 2.4, -tilt.dy * 1.7),
            child: Transform.scale(
              scale: still ? 1 : 1.008,
              child: Image.asset(
                goalsRoomContinuousAsset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RegisteredLightVeil extends StatelessWidget {
  const _RegisteredLightVeil();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: 26,
            top: 82,
            width: 260,
            height: 210,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.35, -0.1),
                  radius: 0.95,
                  colors: [Color(0x3A080604), Color(0x00080604)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 185,
            top: 409,
            width: 206,
            height: 190,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.2),
                  radius: 0.92,
                  colors: [Color(0x00000000), Color(0x4A080604)],
                  stops: [0.45, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThresholdNewGoal extends StatelessWidget {
  const _ThresholdNewGoal({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      key: const Key('goals-new-goal'),
      material: MaterialSound.brass,
      soundEnabled: false,
      pressDepth: 1,
      borderRadius: BorderRadius.circular(8),
      edgeColor: Colors.transparent,
      guardRapidReentry: true,
      semanticLabel: 'Create a new goal',
      onTapUp: (_) => onTap(),
      stateBuilder: (context, child, pressed, focused, hovered) =>
          AnimatedOpacity(
            duration: pressed ? Duration.zero : Motion.ack,
            opacity: pressed
                ? 0.64
                : focused || hovered
                ? 1
                : 0.86,
            child: child,
          ),
      child: Align(
        alignment: Alignment.center,
        child: Text(
          '+  New goal',
          maxLines: 1,
          textScaler: MediaQuery.textScalerOf(
            context,
          ).clamp(maxScaleFactor: 1.18),
          style: const TextStyle(
            fontFamily: 'EBGaramond',
            fontSize: 12,
            height: 1,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.04,
            color: GoalThresholdScene._warmInk,
            shadows: GoalThresholdScene._roomShadow,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _GoalWallTitle extends StatelessWidget {
  const _GoalWallTitle({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      key: const Key('focus-goal-review'),
      material: MaterialSound.parchment,
      soundEnabled: false,
      pressDepth: 1,
      borderRadius: BorderRadius.circular(8),
      edgeColor: Colors.transparent,
      guardRapidReentry: true,
      semanticLabel: '$title. Open goal details.',
      semanticHint: 'Move deeper into this goal.',
      onTapUp: (_) => onTap(),
      stateBuilder: (context, child, pressed, focused, hovered) =>
          AnimatedOpacity(
            duration: pressed ? Duration.zero : Motion.ack,
            opacity: pressed ? 0.72 : 1,
            child: child,
          ),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textScaler: MediaQuery.textScalerOf(
            context,
          ).clamp(maxScaleFactor: 1.18),
          style: const TextStyle(
            fontFamily: 'EBGaramond',
            fontSize: 19.5,
            height: 1,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.04,
            color: GoalThresholdScene._ink,
            shadows: GoalThresholdScene._roomShadow,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _ReturnEvidence extends StatelessWidget {
  const _ReturnEvidence({required this.copy});

  final String copy;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.local_florist_outlined,
            size: 15,
            color: GoalThresholdScene._quietInk,
            shadows: GoalThresholdScene._roomShadow,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                copy,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textScaler: MediaQuery.textScalerOf(
                  context,
                ).clamp(maxScaleFactor: 1.15),
                style: const TextStyle(
                  fontFamily: 'EBGaramond',
                  fontSize: 11.8,
                  height: 1.12,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.02,
                  color: GoalThresholdScene._quietInk,
                  shadows: GoalThresholdScene._roomShadow,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteInscription extends StatelessWidget {
  const _RouteInscription({required this.routePosition, required this.reason});

  final String? routePosition;
  final String reason;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x5C1A100A), Color(0x261A100A)],
      ),
      border: Border(
        top: BorderSide(color: Color(0x72C99550), width: 0.7),
        bottom: BorderSide(color: Color(0x443C2415), width: 0.7),
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (routePosition case final route?) ...[
          Text(
            route.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            textScaler: MediaQuery.textScalerOf(
              context,
            ).clamp(maxScaleFactor: 1.15),
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 8.2,
              height: 1,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.42,
              color: GoalThresholdScene._warmInk,
              shadows: GoalThresholdScene._roomShadow,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 3),
        ],
        Text(
          reason,
          maxLines: routePosition == null ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          textScaler: MediaQuery.textScalerOf(
            context,
          ).clamp(maxScaleFactor: 1.15),
          style: const TextStyle(
            fontFamily: 'EBGaramond',
            fontSize: 10.8,
            height: 1.08,
            fontWeight: FontWeight.w500,
            color: GoalThresholdScene._ink,
            shadows: GoalThresholdScene._roomShadow,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    ),
  );
}

class _ArchQuestTitle extends StatelessWidget {
  const _ArchQuestTitle({required this.title});

  final String title;

  String get _balancedTitle {
    final words = title.trim().split(RegExp(r'\s+'));
    if (words.length < 3 || title.length > 32) return title;
    var bestSplit = 1;
    var bestDifference = 1 << 30;
    for (var split = 1; split < words.length; split++) {
      final first = words.take(split).join(' ').length;
      final second = words.skip(split).join(' ').length;
      final difference = (first - second).abs();
      if (difference < bestDifference) {
        bestDifference = difference;
        bestSplit = split;
      }
    }
    return '${words.take(bestSplit).join(' ')}\n${words.skip(bestSplit).join(' ')}';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 160,
          child: Text(
            _balancedTitle,
            maxLines: 4,
            softWrap: !(_balancedTitle.contains('\n')),
            textAlign: TextAlign.center,
            textScaler: MediaQuery.textScalerOf(
              context,
            ).clamp(maxScaleFactor: 1.12),
            style: const TextStyle(
              fontFamily: 'EBGaramond',
              fontSize: 21.5,
              height: 1,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.03,
              color: GoalThresholdScene._ink,
              shadows: GoalThresholdScene._roomShadow,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArchRule extends StatelessWidget {
  const _ArchRule();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(height: 1, color: Color(0xA6D49D45))),
        Transform.rotate(
          angle: 0.785,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD9A74E), width: 1.2),
            ),
          ),
        ),
        const Expanded(child: Divider(height: 1, color: Color(0xA6D49D45))),
      ],
    );
  }
}

class _ArchRecoveryAction extends StatelessWidget {
  const _ArchRecoveryAction({
    required this.label,
    required this.semanticHint,
    required this.onTap,
  });

  final String label;
  final String? semanticHint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final callback = onTap;
    return Pressable(
      key: const Key('focus-goal-fallback'),
      material: MaterialSound.parchment,
      soundEnabled: false,
      enabled: callback != null,
      pressDepth: 0,
      borderRadius: BorderRadius.circular(10),
      edgeColor: Colors.transparent,
      guardRapidReentry: true,
      semanticLabel: label,
      semanticHint:
          semanticHint ?? 'Ask the steward to help this route meet today.',
      onTapUp: (_) => callback?.call(),
      stateBuilder: (context, child, pressed, focused, hovered) =>
          AnimatedOpacity(
            duration: pressed ? Duration.zero : Motion.ack,
            opacity: pressed
                ? 0.68
                : focused || hovered
                ? 1
                : 0.92,
            child: child,
          ),
      child: Center(
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          textScaler: MediaQuery.textScalerOf(
            context,
          ).clamp(maxScaleFactor: 1.15),
          style: const TextStyle(
            fontFamily: 'EBGaramond',
            fontSize: 13.2,
            height: 1.05,
            fontWeight: FontWeight.w500,
            color: Color(0xFFD3AF7F),
            shadows: GoalThresholdScene._roomShadow,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _TavernWorkshopSign extends StatelessWidget {
  const _TavernWorkshopSign({required this.status, required this.onTap});
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    key: const Key('goals-open-workshop'),
    material: MaterialSound.wood,
    soundEnabled: false,
    pressDepth: 1.5,
    borderRadius: BorderRadius.circular(10),
    edgeColor: const Color(0xFF3A2416),
    guardRapidReentry: true,
    semanticLabel: 'Enter the workshop. The steward is in. $status.',
    semanticHint: 'Cross into the steward\'s tavern workshop.',
    onTapUp: (_) => onTap(),
    stateBuilder: (context, child, pressed, focused, hovered) =>
        AnimatedOpacity(
          duration: pressed ? Duration.zero : Motion.ack,
          opacity: pressed ? 0.76 : 1,
          child: child,
        ),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xED3B281B), Color(0xF21A110C)],
        ),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xC6C08A50), width: 0.9),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99100805),
            blurRadius: 11,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.door_front_door_outlined,
            size: 17,
            color: Color(0xFFD0A36B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Workshop',
                  key: Key('goals-workshop-entrance-label'),
                  maxLines: 1,
                  textScaler: MediaQuery.textScalerOf(
                    context,
                  ).clamp(maxScaleFactor: 1.18),
                  style: const TextStyle(
                    fontFamily: 'EBGaramond',
                    fontSize: 14.2,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF0D2A3),
                    shadows: GoalThresholdScene._roomShadow,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Steward is here',
                  key: Key('goals-workshop-entrance-status'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: MediaQuery.textScalerOf(
                    context,
                  ).clamp(maxScaleFactor: 1.18),
                  style: const TextStyle(
                    fontFamily: 'EBGaramond',
                    fontSize: 10.6,
                    height: 1,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.05,
                    color: Color(0xD9C69A64),
                    shadows: GoalThresholdScene._roomShadow,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
