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
    this.todayFieldCount = 0,
    this.onChooseToday,
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
  final int todayFieldCount;
  final VoidCallback? onChooseToday;
  final VoidCallback? onOpenWorkshop;
  final String workshopStatus;
  final VoidCallback onAction;
  final String? recoveryAction;
  final String? recoverySemanticHint;
  final VoidCallback? onRecovery;
  final ValueListenable<Offset> light;
  final bool reduceMotion;

  static const _ink = Color(0xFFE7DAC6);
  static const _warmInk = Color(0xFFE0B778);
  static const _supportInk = Palette.textMid;
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
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final compactType = sceneWidth < 360 || textScale > 1.2;
          final extremeType = textScale > 1.6;
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
                      left: compactType ? 292 : 324,
                      top: compactType ? 34 : 44,
                      width: compactType ? 126 : 94,
                      height: compactType ? 62 : 54,
                      child: _ThresholdNewGoal(onTap: onNewGoal),
                    ),
                    Positioned(
                      left: compactType ? 52 : 68,
                      top: compactType ? 92 : 122,
                      width: compactType ? 220 : 136,
                      height: compactType ? 106 : 84,
                      child: _GoalWallTitle(title: goalTitle, onTap: onReview),
                    ),
                    Positioned(
                      left: compactType ? 52 : 60,
                      top: compactType ? 204 : 198,
                      width: compactType ? 220 : 190,
                      height: compactType ? 82 : 70,
                      child: _ReturnEvidence(copy: evidenceCopy),
                    ),
                    Positioned(
                      left: 195,
                      top: 410,
                      width: 188,
                      height: 78,
                      child: _RouteInscription(
                        routePosition: routePosition,
                        reason: cue,
                      ),
                    ),
                    Positioned(
                      left: 208,
                      top: 490,
                      width: 160,
                      height: 88,
                      child: _ArchQuestTitle(title: actionTitle),
                    ),
                    const Positioned(
                      left: 252,
                      top: 578,
                      width: 72,
                      height: 12,
                      child: _ArchRule(),
                    ),
                    if (onOpenWorkshop case final openWorkshop?)
                      Positioned(
                        left: 219,
                        top: 320,
                        width: 156,
                        height: extremeType ? 76 : 64,
                        child: _TavernWorkshopSign(
                          status: workshopStatus,
                          onTap: openWorkshop,
                        ),
                      ),
                    Positioned(
                      left: 190,
                      top: 600,
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
                    if (onChooseToday case final chooseToday?)
                      Positioned(
                        left: 40,
                        top: 682,
                        width: 154,
                        height: extremeType ? 74 : 66,
                        child: _TodayFieldDoor(
                          count: todayFieldCount,
                          onTap: chooseToday,
                        ),
                      ),
                    if (recoveryAction case final recovery?)
                      Positioned(
                        left: 198,
                        top: 664,
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

/// The room-level door into the page's ordinary-day job. Keeping this on the
/// threshold makes the new utility discoverable before someone already knows
/// to scroll beneath the authored room; the fuller field folio still lives
/// below the room where its rows have enough space to breathe.
class _TodayFieldDoor extends StatelessWidget {
  const _TodayFieldDoor({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compactType = textScale > 1.2;
    final heading = textScale > 1.6 ? 'TODAY' : 'TODAY\'S FIELD';
    final status = count == 0
        ? (compactType ? 'Choose' : 'Choose up to 3')
        : '$count chosen';
    return Pressable(
      key: const Key('goals-field-door'),
      material: MaterialSound.wood,
      soundEnabled: false,
      pressDepth: 1.2,
      borderRadius: BorderRadius.circular(10),
      edgeColor: const Color(0xFF51331F),
      guardRapidReentry: true,
      semanticLabel: count == 0
          ? 'Choose today’s field'
          : 'Today’s field, $count chosen. Reshape today.',
      semanticHint:
          'Choose up to three Quests to carry. Everything else stays optional.',
      onTapUp: (_) => onTap(),
      stateBuilder: (context, child, pressed, focused, hovered) =>
          AnimatedOpacity(
            duration: pressed ? Duration.zero : Motion.ack,
            opacity: pressed
                ? 0.72
                : focused || hovered
                ? 1
                : 0.94,
            child: child,
          ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 8, 10, 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xE52A1B12), Color(0xE018100B)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x9CC99550), width: 0.8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x8A100805),
              blurRadius: 9,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.filter_list_rounded,
              size: 18,
              color: GoalThresholdScene._warmInk,
              shadows: GoalThresholdScene._roomShadow,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    heading,
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.34,
                      color: GoalThresholdScene._warmInk,
                      shadows: GoalThresholdScene._roomShadow,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'EBGaramond',
                      fontSize: 13.5,
                      height: 1,
                      fontWeight: FontWeight.w500,
                      color: GoalThresholdScene._ink,
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
          style: const TextStyle(
            fontFamily: 'EBGaramond',
            fontSize: 13.5,
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
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 9, 6),
      decoration: BoxDecoration(
        color: const Color(0xC9160F0B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x66C99550), width: 0.7),
        boxShadow: const [
          BoxShadow(
            color: Color(0x8A100805),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.local_florist_outlined,
              size: 16,
              color: GoalThresholdScene._warmInk,
              shadows: GoalThresholdScene._roomShadow,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              copy,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'EBGaramond',
                fontSize: 13.2,
                height: 1.14,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.02,
                color: GoalThresholdScene._supportInk,
                shadows: GoalThresholdScene._roomShadow,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
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
        colors: [Color(0xE61A100A), Color(0xC71A100A)],
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
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
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
          style: const TextStyle(
            fontFamily: 'EBGaramond',
            fontSize: 13,
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
            softWrap: true,
            textAlign: TextAlign.center,
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
          if (MediaQuery.textScalerOf(context).scale(1) <= 1.6) ...[
            const Icon(
              Icons.door_front_door_outlined,
              size: 17,
              color: Color(0xFFD0A36B),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Workshop',
                  key: Key('goals-workshop-entrance-label'),
                  maxLines: 1,
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
                  MediaQuery.textScalerOf(context).scale(1) > 1.6
                      ? 'Steward'
                      : 'Steward is here',
                  key: Key('goals-workshop-entrance-status'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'EBGaramond',
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.05,
                    color: Palette.textMid,
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
