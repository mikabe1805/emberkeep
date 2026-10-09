import 'dart:async';

import 'package:flutter/material.dart';

import '../audio.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/facets.dart';
import '../widgets/goal_primary_button.dart';
import '../widgets/honey_button.dart';
import '../widgets/goal_steward.dart';
import '../widgets/goal_world.dart';
import '../widgets/luxe_depth.dart';
import '../widgets/pressable.dart';

enum _GoalOpeningStage { desk, wideRoom, threshold, arrival }

const _goalOpeningWideRoomProgress = 0.22;
const _goalOpeningThresholdProgress = 0.60;

double _openingSegment(double value, double begin, double end) {
  if (end <= begin) return value >= end ? 1 : 0;
  return ((value - begin) / (end - begin)).clamp(0.0, 1.0);
}

/// The one-time opening for a newly created goal.
///
/// This is deliberately not an onboarding carousel. The person supplied one
/// intention; Room of Days pays that setup back by showing the exact first
/// Quest it preserved or prepared, holding long enough to read, and ending on
/// the real Quest handoff. Returning goals skip this screen entirely.
class GoalOpeningScreen extends StatefulWidget {
  const GoalOpeningScreen({
    super.key,
    required this.goal,
    required this.actionTitle,
    required this.onBegin,
    this.fallbackAction,
    this.preparedByApp = false,
    this.onChooseAnother,
    this.onEditAction,
    this.onMakeSmaller,
    this.onReworkRoute,
    this.onReturn,
    this.reduceMotion = false,
    this.startInWorkshop = false,
    this.questOwned = false,
    this.actionXp,
  });

  final Goal goal;
  final String actionTitle;
  final String? fallbackAction;
  final bool preparedByApp;
  final VoidCallback onBegin;
  final VoidCallback? onChooseAnother;
  final Future<bool> Function(String actionTitle)? onEditAction;
  final Future<String?> Function()? onMakeSmaller;
  final VoidCallback? onReworkRoute;
  final VoidCallback? onReturn;
  final bool reduceMotion;
  final bool startInWorkshop;
  final bool questOwned;

  /// The XP of the Quest the primary action would take, read when it is drawn
  /// so a changed step never shows the old number.
  final int Function()? actionXp;

  @override
  State<GoalOpeningScreen> createState() => _GoalOpeningScreenState();
}

class _GoalOpeningScreenState extends State<GoalOpeningScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _room;
  late final LuxeMotionController _motion;
  late String _actionTitle;
  late _GoalOpeningStage _stage;
  bool _moving = false;
  bool _workshopUpdating = false;
  late bool _questOwned;
  bool _stewardAssetsCached = false;

  GoalStewardExpression get _stewardExpression {
    if (_workshopUpdating) {
      return resolveGoalStewardExpression(GoalStewardSituation.considering);
    }
    if (_questOwned) {
      return resolveGoalStewardExpression(GoalStewardSituation.questAccepted);
    }
    return resolveGoalStewardExpression(GoalStewardSituation.cutReady);
  }

  bool get _still =>
      widget.reduceMotion ||
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  double get _stageProgress => switch (_stage) {
    _GoalOpeningStage.desk => 0,
    _GoalOpeningStage.wideRoom => _goalOpeningWideRoomProgress,
    _GoalOpeningStage.threshold => _goalOpeningThresholdProgress,
    _GoalOpeningStage.arrival => 1,
  };

  bool get _isWideRoomStop => !_moving && _stage == _GoalOpeningStage.wideRoom;

  @override
  void initState() {
    super.initState();
    _room = AnimationController(vsync: this, lowerBound: 0, upperBound: 1);
    _motion = LuxeMotionController(reduceMotion: widget.reduceMotion);
    unawaited(_motion.start());
    _stage = widget.startInWorkshop
        ? _GoalOpeningStage.arrival
        : _GoalOpeningStage.desk;
    _room.value = widget.startInWorkshop ? 1 : 0;
    _actionTitle = widget.actionTitle;
    _questOwned = widget.questOwned;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion.setReduceMotion(_still);
    if (_stewardAssetsCached) return;
    _stewardAssetsCached = true;
    precacheGoalStewardAssets(context);
  }

  @override
  void dispose() {
    _room.dispose();
    _motion.dispose();
    super.dispose();
  }

  Future<void> _moveTo(
    _GoalOpeningStage target, {
    required double progress,
    required Duration duration,
    Curve curve = Curves.easeInOutCubic,
  }) async {
    if (_moving || target == _stage) return;
    if (_still) {
      setState(() => _stage = target);
      return;
    }
    setState(() => _moving = true);
    await _room.animateTo(progress, duration: duration, curve: curve);
    if (!mounted) return;
    setState(() {
      _stage = target;
      _moving = false;
    });
  }

  // Each camera destination belongs to the person. Reaching the wide room is
  // a real stop: the route remains parked until they choose to cross it.
  Future<void> _showPlan() => _moveTo(
    _GoalOpeningStage.wideRoom,
    progress: _goalOpeningWideRoomProgress,
    duration: const Duration(milliseconds: 760),
    curve: Curves.easeOutCubic,
  );

  Future<void> _approachArch() => _moveTo(
    _GoalOpeningStage.threshold,
    progress: _goalOpeningThresholdProgress,
    duration: const Duration(milliseconds: 1040),
    curve: const Cubic(0.20, 0.72, 0.18, 1),
  );

  Future<void> _stepIn() => _moveTo(
    _GoalOpeningStage.arrival,
    progress: 1,
    duration: const Duration(milliseconds: 1120),
    curve: const Cubic(0.42, 0.02, 0.18, 1),
  );

  Future<void> _returnToDesk() => _moveTo(
    _GoalOpeningStage.desk,
    progress: 0,
    duration: const Duration(milliseconds: 720),
    curve: Curves.easeInOutCubic,
  );

  Future<void> _returnToWideRoom() => _moveTo(
    _GoalOpeningStage.wideRoom,
    progress: _goalOpeningWideRoomProgress,
    duration: const Duration(milliseconds: 840),
    curve: const Cubic(0.32, 0, 0.42, 1),
  );

  Future<void> _editWorkshopAction() async {
    final apply = widget.onEditAction;
    if (apply == null || _workshopUpdating || _moving) return;
    var draft = _actionTitle;
    final changed = await showDialog<String>(
      context: context,
      barrierColor: const Color(0xD9130B07),
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF211812),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Change this step',
          style: Type.display.copyWith(fontSize: 21),
        ),
        content: TextFormField(
          key: const Key('goal-workshop-edit-field'),
          initialValue: draft,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (value) => draft = value,
          style: Type.body.copyWith(color: Palette.textHi),
          decoration: const InputDecoration(
            hintText: 'One visible action you can actually do',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('KEEP IT'),
          ),
          TextButton(
            key: const Key('goal-workshop-edit-save'),
            onPressed: () => Navigator.of(dialogContext).pop(draft.trim()),
            child: const Text('USE THIS STEP'),
          ),
        ],
      ),
    );
    if (!mounted || changed == null || changed.trim().isEmpty) return;
    setState(() => _workshopUpdating = true);
    final accepted = await apply(changed.trim());
    if (!mounted) return;
    setState(() {
      if (accepted) {
        _actionTitle = changed.trim();
        _questOwned = false;
      }
      _workshopUpdating = false;
    });
  }

  Future<void> _makeWorkshopActionSmaller() async {
    final makeSmaller = widget.onMakeSmaller;
    if (makeSmaller == null || _workshopUpdating || _moving) return;
    setState(() => _workshopUpdating = true);
    final previous = _actionTitle;
    final changed = await makeSmaller();
    if (!mounted) return;
    setState(() {
      if (changed != null && changed.trim().isNotEmpty) {
        _actionTitle = changed.trim();
        if (_actionTitle != previous) _questOwned = false;
      }
      _workshopUpdating = false;
    });
  }

  Future<void> _back() async {
    if (_moving) return;
    switch (_stage) {
      case _GoalOpeningStage.desk:
        // The opening owns back navigation so an in-flight camera move can
        // never inherit a stale route-level pop permission. A direct pop here
        // is safe because this is the only stage that actually exits.
        Navigator.of(context).pop();
        return;
      case _GoalOpeningStage.wideRoom:
        await _returnToDesk();
        return;
      case _GoalOpeningStage.threshold:
        await _returnToWideRoom();
        return;
      case _GoalOpeningStage.arrival:
        if (widget.startInWorkshop) {
          Navigator.of(context).pop();
          return;
        }
        await _moveTo(
          _GoalOpeningStage.threshold,
          progress: _goalOpeningThresholdProgress,
          duration: const Duration(milliseconds: 900),
          curve: const Cubic(0.34, 0, 0.24, 1),
        );
        return;
    }
  }

  Future<void> _handleSystemBack(bool didPop, Object? result) async {
    if (didPop || _moving) return;
    await _back();
  }

  @override
  Widget build(BuildContext context) {
    _motion.setReduceMotion(_still);
    final scene = _still
        ? _buildScene(_stageProgress)
        : AnimatedBuilder(
            animation: _room,
            builder: (context, _) => _buildScene(_room.value),
          );

    return PopScope<Object?>(
      // Keep the route vetoed and resolve every system-back request through
      // [_back]. This closes the one-frame gap between a CTA's accepted frame
      // and the first camera tick, when a stale `canPop: true` could otherwise
      // discard the just-created goal opening.
      canPop: false,
      onPopInvokedWithResult: _handleSystemBack,
      child: Scaffold(
        backgroundColor: const Color(0xFF100D0B),
        body: LayoutBuilder(
          builder: (context, constraints) => MouseRegion(
            onHover: (event) =>
                _motion.handlePointer(event, constraints.biggest),
            onExit: _motion.clearPointer,
            child: Listener(
              onPointerDown: (_) =>
                  unawaited(_motion.requestBrowserMotionPermission()),
              child: scene,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScene(double progress) {
    final deskOut = Curves.easeInCubic.transform(
      _openingSegment(progress, 0.03, 0.18),
    );
    final arrivalIn = Curves.easeOutCubic.transform(
      _openingSegment(progress, 0.79, 0.91),
    );
    final wideRoomReady = !_moving && _stage == _GoalOpeningStage.wideRoom;
    final thresholdReady = !_moving && _stage == _GoalOpeningStage.threshold;
    final routeStopReady = wideRoomReady || thresholdReady;
    final atOrBeforeWideRoom =
        _stage == _GoalOpeningStage.desk ||
        _stage == _GoalOpeningStage.wideRoom;
    final plan = widget.goal.plan;
    final routeStopCue = atOrBeforeWideRoom
        ? 'You’ll know this is complete when'
        : 'What this plan should survive';
    final routeStopTitle = atOrBeforeWideRoom
        ? plan?.successProof.trim().isNotEmpty == true
              ? plan!.successProof.trim()
              : '$_actionTitle is visibly done'
        : plan?.obstacleCue.trim().isNotEmpty == true
        ? plan!.obstacleCue.trim()
        : widget.goal.fallbackCue?.trim().isNotEmpty == true
        ? widget.goal.fallbackCue!.trim()
        : 'The full version may ask for more than today has.';
    final routeActionLabel = atOrBeforeWideRoom
        ? 'Cross the room'
        : 'Step inside';
    final routeActionKey = atOrBeforeWideRoom
        ? const ValueKey('goal-room-wide-continue')
        : const ValueKey('goal-room-arch-step-in');
    final routeAction = wideRoomReady
        ? _approachArch
        : thresholdReady
        ? _stepIn
        : null;
    final fallback = widget.fallbackAction?.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final compact = constraints.maxHeight < 700 || textScale > 1.2;
        final bottom = MediaQuery.paddingOf(context).bottom + 22;
        final panelMaxHeight =
            constraints.maxHeight *
            (textScale > 1.6
                ? 0.76
                : compact
                ? 0.68
                : 0.58);
        final routeStopIn = Curves.easeOutCubic.transform(
          _openingSegment(progress, 0.16, 0.22),
        );
        final routeStopOut = Curves.easeInCubic.transform(
          _openingSegment(progress, 0.62, 0.76),
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            KeyedSubtree(
              key: _isWideRoomStop
                  ? const ValueKey('goal-opening-wide-room-stop')
                  : null,
              child: GoalRoomTravelBackdrop(
                progress: progress,
                openingSequence: true,
                destinationExpression: _stewardExpression,
                destinationParallax: _motion.parallax,
                destinationLight: _motion.light,
                reduceMotion: _still,
                invitation: compact
                    ? null
                    : GoalRoomInvitation(
                        cue: routeStopCue,
                        actionTitle: routeStopTitle,
                        fallbackAction: atOrBeforeWideRoom ? null : fallback,
                        actionLabel: routeActionLabel,
                        actionKey: routeActionKey,
                        onTap: routeAction,
                        semanticHint: wideRoomReady
                            ? 'Cross the room toward the support this plan may need.'
                            : 'Step through the arch to review and accept the prepared Quest.',
                      ),
              ),
            ),
            if (_stage == _GoalOpeningStage.arrival)
              IgnorePointer(
                child: Semantics(
                  key: const Key('goal-workshop-steward'),
                  image: true,
                  label: goalStewardSemanticLabel(_stewardExpression),
                  child: const SizedBox.expand(),
                ),
              ),
            Positioned(
              left: 16,
              top: MediaQuery.paddingOf(context).top + 10,
              child: _OpeningBackButton(enabled: !_moving, onTap: _back),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: bottom,
              child: ExcludeSemantics(
                excluding: _moving || _stage != _GoalOpeningStage.desk,
                child: IgnorePointer(
                  ignoring: _moving || deskOut > 0.04,
                  child: Opacity(
                    key: const ValueKey('goal-opening-desk-opacity'),
                    opacity: 1 - deskOut,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: panelMaxHeight),
                      child: compact
                          ? _OpeningDeskFolio(
                              goal: widget.goal,
                              actionTitle: _actionTitle,
                              hasLighterPlan:
                                  fallback != null && fallback.isNotEmpty,
                              preparedByApp: widget.preparedByApp,
                              onContinue: _showPlan,
                              reduceMotion: widget.reduceMotion,
                            )
                          : _OpeningDeskCinematicFolio(
                              goal: widget.goal,
                              actionTitle: _actionTitle,
                              hasLighterPlan:
                                  fallback != null && fallback.isNotEmpty,
                              preparedByApp: widget.preparedByApp,
                              onContinue: _showPlan,
                              reduceMotion: widget.reduceMotion,
                            ),
                    ),
                  ),
                ),
              ),
            ),
            if (compact)
              Positioned(
                left: 16,
                right: 16,
                bottom: bottom,
                child: ExcludeSemantics(
                  excluding: !routeStopReady,
                  child: IgnorePointer(
                    ignoring: !routeStopReady,
                    child: Opacity(
                      key: const ValueKey(
                        'goal-opening-compact-route-stop-opacity',
                      ),
                      opacity: routeStopIn * (1 - routeStopOut),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: panelMaxHeight),
                        child: _OpeningThresholdFolio(
                          contextLabel: routeStopCue,
                          actionTitle: routeStopTitle,
                          fallbackAction: atOrBeforeWideRoom ? null : fallback,
                          actionLabel: routeActionLabel,
                          actionKey: routeActionKey,
                          semanticHint: wideRoomReady
                              ? 'Cross the room toward the support this plan may need.'
                              : 'Step through the arch to review and accept the prepared Quest.',
                          onContinue: routeAction ?? () {},
                          reduceMotion: widget.reduceMotion,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: bottom,
              child: ExcludeSemantics(
                excluding: _moving || _stage != _GoalOpeningStage.arrival,
                child: IgnorePointer(
                  ignoring: _moving || _stage != _GoalOpeningStage.arrival,
                  child: Opacity(
                    key: const ValueKey('goal-workshop-shell-opacity'),
                    opacity: arrivalIn,
                    child: Transform.translate(
                      offset: Offset(0, -(1 - arrivalIn) * 18),
                      child: Transform.scale(
                        alignment: Alignment.bottomCenter,
                        scale: 0.985 + arrivalIn * 0.015,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: panelMaxHeight,
                          ),
                          child: _OpeningArrivalFolio(
                            goal: widget.goal,
                            actionTitle: _actionTitle,
                            fallbackAction: fallback,
                            preparedByApp: widget.preparedByApp,
                            onBegin: widget.onBegin,
                            onChooseAnother: widget.onChooseAnother,
                            onEditAction: widget.onEditAction == null
                                ? null
                                : _editWorkshopAction,
                            onMakeSmaller: widget.onMakeSmaller == null
                                ? null
                                : _makeWorkshopActionSmaller,
                            onReworkRoute: widget.onReworkRoute,
                            onReturn: widget.onReturn,
                            showReturn: !widget.startInWorkshop,
                            xp: widget.actionXp?.call(),
                            questOwned: _questOwned,
                            updating: _workshopUpdating,
                            reduceMotion: widget.reduceMotion,
                            compact: compact,
                            reveal: progress,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OpeningBackButton extends StatelessWidget {
  const _OpeningBackButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      excluding: !enabled,
      child: AnimatedOpacity(
        duration: Motion.ack,
        opacity: enabled ? 1 : 0.42,
        child: Pressable(
          key: const Key('goal-opening-back'),
          material: MaterialSound.glass,
          enabled: enabled,
          pressDepth: 1.2,
          shape: const FacetedBorder(cut: 10),
          edgeColor: Colors.transparent,
          semanticLabel: 'Back',
          semanticHint: 'Return to the previous opening beat.',
          onTapUp: (_) => onTap(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: DecoratedBox(
              decoration: facetedDecoration(
                cut: 10,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xD52A1D15), Color(0xE718100C)],
                ),
                borderColor: const Color(0x78B98A56),
                borderWidth: 0.9,
                shadows: const [
                  BoxShadow(
                    color: Color(0x66100805),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: const Stack(
                fit: StackFit.expand,
                children: [
                  FacetGleam(cut: 10, strength: 0.62),
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Palette.textHi,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OpeningDeskCinematicFolio extends StatelessWidget {
  const _OpeningDeskCinematicFolio({
    required this.goal,
    required this.actionTitle,
    required this.hasLighterPlan,
    required this.preparedByApp,
    required this.onContinue,
    required this.reduceMotion,
  });

  final Goal goal;
  final String actionTitle;
  final bool hasLighterPlan;
  final bool preparedByApp;
  final VoidCallback onContinue;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final reason = goal.why?.trim();
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final claspWidth = 148 + ((textScale - 1).clamp(0.0, 0.2) * 108).toDouble();
    const roomShadows = <Shadow>[
      Shadow(color: Color(0xDC120B07), blurRadius: 18, offset: Offset(0, 5)),
      Shadow(color: Color(0x59F1C782), blurRadius: 1, offset: Offset(0, -1)),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OpeningContextLine(
                'Your focus',
                key: const Key('goal-opening-desk-label'),
                accent: goal.stat.color,
                icon: goal.stat.icon,
                shadows: roomShadows,
              ),
              const SizedBox(height: 10),
              Text(
                goal.title,
                key: const Key('goal-opening-title'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Type.display.copyWith(
                  fontSize: 31,
                  height: 1.08,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFF3E5CE),
                  shadows: roomShadows,
                ),
              ),
              if (reason != null && reason.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        width: 24,
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              goal.stat.color.withValues(alpha: 0.9),
                              goal.stat.color.withValues(alpha: 0.08),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Type.body.copyWith(
                          fontSize: 14.5,
                          height: 1.36,
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFFE7D5B9),
                          shadows: roomShadows,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _OpeningFolioShell(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    FacetMedallion(
                      size: 26,
                      accent: goal.stat.color,
                      child: Icon(
                        goal.stat.icon,
                        size: 15,
                        color: goal.stat.color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.plan == null
                                ? (preparedByApp
                                      ? 'First move'
                                      : 'Your first move')
                                : 'Step 1 of ${goal.plan!.steps.length}',
                            style: Type.body.copyWith(
                              fontSize: 12.5,
                              height: 1.1,
                              fontWeight: FontWeight.w500,
                              color: Palette.textMid,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            actionTitle,
                            style: Type.display.copyWith(
                              fontSize: 16.5,
                              height: 1.1,
                              fontWeight: FontWeight.w500,
                              color: Palette.textHi,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: claspWidth,
                      height: 52,
                      child: GoalPrimaryButton(
                        key: const Key('goal-opening-show-plan'),
                        label: goal.plan == null
                            ? 'See the move'
                            : 'Open the plan',
                        icon: Icons.arrow_forward_rounded,
                        onTap: onContinue,
                        glow: false,
                        reduceMotion: reduceMotion,
                        pendingLabel: 'Opening',
                        treatment: GoalPrimaryButtonTreatment.openingClasp,
                        semanticHint: goal.plan == null
                            ? 'Reveal the prepared first move.'
                            : 'Reveal the whole plan and its first Quest.',
                      ),
                    ),
                  ],
                ),
                if (hasLighterPlan) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.south_east_rounded,
                        size: 15,
                        color: goal.stat.color.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'A smaller version is ready if you need it.',
                          style: Type.body.copyWith(
                            fontSize: 13.5,
                            height: 1.25,
                            color: Palette.textMid,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OpeningDeskFolio extends StatelessWidget {
  const _OpeningDeskFolio({
    required this.goal,
    required this.actionTitle,
    required this.hasLighterPlan,
    required this.preparedByApp,
    required this.onContinue,
    required this.reduceMotion,
  });

  final Goal goal;
  final String actionTitle;
  final bool hasLighterPlan;
  final bool preparedByApp;
  final VoidCallback onContinue;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final reason = goal.why?.trim();
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return _OpeningFolioShell(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 19, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OpeningContextLine(
              'Your focus',
              key: const Key('goal-opening-desk-label'),
              accent: goal.stat.color,
              icon: goal.stat.icon,
            ),
            const SizedBox(height: 10),
            Text(
              goal.title,
              key: const Key('goal-opening-title'),
              style: Type.display.copyWith(
                fontSize: 27,
                height: 1.1,
                fontWeight: FontWeight.w500,
                color: Palette.textHi,
              ),
            ),
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 11),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 1,
                    margin: const EdgeInsets.only(top: 10, right: 9),
                    color: goal.stat.color.withValues(alpha: 0.7),
                  ),
                  Expanded(
                    child: Text(
                      reason,
                      style: Type.body.copyWith(
                        fontSize: 14.5,
                        height: 1.36,
                        fontStyle: FontStyle.italic,
                        color: Palette.textMid,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FacetMedallion(
                  size: 24,
                  accent: goal.stat.color,
                  child: Icon(goal.stat.icon, size: 14, color: goal.stat.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.plan == null
                            ? (preparedByApp ? 'First move' : 'Your first move')
                            : 'Step 1 of ${goal.plan!.steps.length}',
                        style: Type.body.copyWith(
                          fontSize: 12.5,
                          height: 1.1,
                          fontWeight: FontWeight.w500,
                          color: Palette.textMid,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        actionTitle,
                        style: Type.display.copyWith(
                          fontSize: 16.5,
                          height: 1.12,
                          fontWeight: FontWeight.w500,
                          color: Palette.textHi,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasLighterPlan) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.south_east_rounded,
                    size: 15,
                    color: goal.stat.color.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'A smaller version is ready if you need it.',
                      style: Type.body.copyWith(
                        fontSize: 13.5,
                        height: 1.25,
                        color: Palette.textMid,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: largeText ? 56 : 52,
              child: GoalPrimaryButton(
                key: const Key('goal-opening-show-plan'),
                label: goal.plan == null ? 'See the move' : 'Open the plan',
                icon: Icons.arrow_forward_rounded,
                onTap: onContinue,
                expand: true,
                glow: false,
                reduceMotion: reduceMotion,
                pendingLabel: 'Opening',
                treatment: GoalPrimaryButtonTreatment.openingClasp,
                semanticHint: goal.plan == null
                    ? 'Reveal the prepared first move.'
                    : 'Reveal the whole plan and its first Quest.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quiet actions in pairs where there is room, one per line where there is
/// not. A quiet [HoneyButton] fills the width it is given, so the row sets it.
class _OpeningActions extends StatelessWidget {
  const _OpeningActions({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked =
          constraints.maxWidth < 290 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.2;
      final width = stacked
          ? constraints.maxWidth
          : (constraints.maxWidth - 8) / 2;
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _OpeningPlanPreview extends StatelessWidget {
  const _OpeningPlanPreview({required this.plan, required this.accent});

  final GoalPlan plan;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final remaining = plan.steps.length - plan.currentStepIndex;
    return Container(
      key: const Key('goal-workshop-route'),
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 9),
      decoration: facetedDecoration(
        cut: 8,
        color: const Color(0xFF15100D),
        borderColor: Palette.brassDeep.withValues(alpha: 0.62),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'THE WHOLE PLAN',
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  letterSpacing: 1.1,
                  color: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$remaining ${remaining == 1 ? 'step' : 'steps'} to go',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: Type.body.copyWith(
                    fontSize: 13,
                    color: Palette.textLo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (
            var index = plan.currentStepIndex;
            index < plan.steps.length;
            index++
          ) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 23,
                  height: 23,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: index == plan.currentStepIndex
                          ? accent
                          : Palette.brassDeep,
                    ),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      color: index == plan.currentStepIndex
                          ? accent
                          : Palette.textLo,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan.steps[index].title,
                    style: Type.body.copyWith(
                      fontSize: 13,
                      height: 1.2,
                      color: index == plan.currentStepIndex
                          ? Palette.textHi
                          : Palette.textMid,
                      fontWeight: index == plan.currentStepIndex
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
            if (index != plan.steps.length - 1) const SizedBox(height: 5),
          ],
        ],
      ),
    );
  }
}

/// The arrival: the step on offer (its title and XP) and the one action that
/// takes it. Everything else (why this step, what it should leave behind, the
/// whole plan, ways to change it) sits behind "See the whole plan" so the
/// first read is one decision.
class _OpeningArrivalFolio extends StatefulWidget {
  const _OpeningArrivalFolio({
    required this.goal,
    required this.actionTitle,
    required this.fallbackAction,
    required this.preparedByApp,
    required this.onBegin,
    required this.onChooseAnother,
    required this.onEditAction,
    required this.onMakeSmaller,
    required this.onReworkRoute,
    required this.onReturn,
    required this.showReturn,
    required this.xp,
    required this.questOwned,
    required this.updating,
    required this.reduceMotion,
    required this.compact,
    required this.reveal,
  });

  final Goal goal;
  final String actionTitle;
  final String? fallbackAction;
  final bool preparedByApp;
  final VoidCallback onBegin;
  final VoidCallback? onChooseAnother;
  final VoidCallback? onEditAction;
  final VoidCallback? onMakeSmaller;
  final VoidCallback? onReworkRoute;
  final VoidCallback? onReturn;
  final bool showReturn;
  final int? xp;
  final bool questOwned;
  final bool updating;
  final bool reduceMotion;
  final bool compact;
  final double reveal;

  @override
  State<_OpeningArrivalFolio> createState() => _OpeningArrivalFolioState();
}

class _OpeningArrivalFolioState extends State<_OpeningArrivalFolio> {
  final _scroll = ScrollController();
  final _toggleKey = GlobalKey();
  bool _planOpen = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _togglePlan() {
    setState(() => _planOpen = !_planOpen);
    if (!_planOpen) return;
    // Bring the toggle to the top of the panel so what it reveals is in view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _toggleKey.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.22,
        duration: widget.reduceMotion ? Duration.zero : Motion.quick,
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Long step titles shrink a little instead of being cut: the whole title
  /// is the thing being offered.
  double _titleSize(int length, bool compact) {
    final base = compact ? 23.5 : 27.0;
    if (length <= 38) return base;
    if (length <= 80) return base - 3.5;
    return base - 6.5;
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final reveal = widget.reveal;
    final still =
        widget.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    double stage(double begin, double end) => still
        ? 1.0
        : Curves.easeOutCubic.transform(_openingSegment(reveal, begin, end));
    final primaryReveal = stage(0.80, 0.90);
    final supportReveal = stage(0.94, 0.99);
    final controlsReveal = stage(0.965, 1);
    final cutSurfaceReveal = stage(0.78, 0.88);
    final cutTitleReveal = stage(0.82, 0.88);
    final cutInkReveal = stage(0.87, 0.97);
    final cutLabelReveal = stage(0.92, 0.985);
    final textScaler = MediaQuery.textScalerOf(context);
    final compactWorkshop = widget.compact;
    final plan = goal.plan;
    final step = plan?.currentStep;
    final fallback = widget.fallbackAction;
    final hasFallback = fallback != null && fallback.isNotEmpty;
    final marker = plan == null
        ? 'FIRST QUEST'
        : 'STEP ${plan.currentStepIndex + 1} OF ${plan.steps.length}';
    final eyebrow = widget.questOwned
        ? 'ON YOUR BOARD'
        : plan == null || plan.currentStepIndex == 0
        ? 'YOUR FIRST STEP'
        : 'YOUR NEXT STEP';
    final size = _titleSize(widget.actionTitle.length, compactWorkshop);
    final cutTitleStyle = TextStyle.lerp(
      TextStyle(
        fontFamily: 'EBGaramond',
        fontSize: size,
        height: 1.0,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.08,
        color: const Color(0xFFF0E5D2),
        shadows: const [
          Shadow(color: Color(0xE50B0705), blurRadius: 9, offset: Offset(0, 2)),
          Shadow(color: Color(0x00100906), blurRadius: 0),
        ],
        decoration: TextDecoration.none,
      ),
      TextStyle(
        fontFamily: 'EBGaramond',
        fontSize: size - 2,
        height: 1.02,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.05,
        color: const Color(0xFF2B1B10),
        shadows: const [
          Shadow(color: Color(0x00100906), blurRadius: 0),
          Shadow(color: Color(0x00100906), blurRadius: 0),
        ],
        decoration: TextDecoration.none,
      ),
      cutInkReveal,
    )!;
    final hasChanges =
        widget.onEditAction != null || widget.onReworkRoute != null;
    final canDisclose =
        step != null || plan != null || hasFallback || hasChanges;
    final hasSecondary =
        widget.onMakeSmaller != null ||
        (widget.preparedByApp && widget.onChooseAnother != null);

    Widget details() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        if (step != null) ...[
          _WorkshopFact(
            label: 'WHY THIS STEP',
            value: step.whyNow,
            valueKey: const Key('goal-workshop-why'),
            accent: goal.stat.color,
          ),
          const SizedBox(height: 9),
          _WorkshopFact(
            label: 'WHAT SHOWS IT IS DONE',
            value: step.proof,
            valueKey: const Key('goal-workshop-proof'),
            accent: goal.stat.color,
          ),
          const SizedBox(height: 12),
        ],
        if (plan != null) ...[
          _OpeningPlanPreview(plan: plan, accent: goal.stat.color),
          const SizedBox(height: 11),
        ],
        if (hasFallback)
          _WorkshopFact(
            label: 'SMALLER VERSION, READY',
            value: fallback,
            accent: goal.stat.color,
          ),
        if (hasChanges)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _OpeningActions(
              children: [
                if (widget.onEditAction != null)
                  HoneyButton(
                    key: const Key('goal-workshop-edit-action'),
                    label: 'Change this step',
                    icon: Icons.edit_outlined,
                    quiet: true,
                    compact: true,
                    enabled: !widget.updating,
                    onTap: widget.onEditAction!,
                  ),
                if (widget.onReworkRoute != null)
                  HoneyButton(
                    key: const Key('goal-workshop-rework-route'),
                    label: 'Change the plan',
                    icon: Icons.alt_route_rounded,
                    quiet: true,
                    compact: true,
                    enabled: !widget.updating,
                    onTap: widget.onReworkRoute!,
                  ),
              ],
            ),
          ),
      ],
    );

    return KeyedSubtree(
      key: const Key('goal-workshop-screen'),
      child: _OpeningFolioShell(
        child: Column(
          children: [
            Flexible(
              child: SingleChildScrollView(
                key: const PageStorageKey<String>('goal-workshop-scroll'),
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OpeningReveal(
                      reveal: primaryReveal,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _OpeningContextLine(
                            'The Steward’s workshop',
                            key: const Key('goal-opening-arrival-label'),
                            accent: goal.stat.color,
                            icon: goal.stat.icon,
                          ),
                          const SizedBox(height: 9),
                          if (compactWorkshop) ...[
                            Text(
                              marker,
                              key: const Key('goal-workshop-marker'),
                              textAlign: TextAlign.right,
                              style: Type.label.copyWith(
                                fontSize: Type.minLabel,
                                letterSpacing: 0.9,
                                color: goal.stat.color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              goal.title,
                              style: Type.body.copyWith(
                                fontSize: 13,
                                height: 1.18,
                                fontWeight: FontWeight.w600,
                                color: Palette.textMid,
                              ),
                            ),
                          ] else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Text(
                                    goal.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Type.body.copyWith(
                                      fontSize: 14,
                                      height: 1.18,
                                      fontWeight: FontWeight.w600,
                                      color: Palette.textMid,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  marker,
                                  key: const Key('goal-workshop-marker'),
                                  style: Type.label.copyWith(
                                    fontSize: Type.minLabel,
                                    letterSpacing: 0.9,
                                    color: goal.stat.color,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 11),
                          Transform.scale(
                            alignment: Alignment.center,
                            scale: 0.94 + cutSurfaceReveal * 0.06,
                            child: Container(
                              key: const Key('goal-workshop-current-quest'),
                              padding: EdgeInsets.fromLTRB(
                                15,
                                compactWorkshop ? 10 : 13,
                                15,
                                compactWorkshop ? 11 : 14,
                              ),
                              decoration: facetedDecoration(
                                cut: 9,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color.lerp(
                                      Colors.transparent,
                                      const Color(0xFFF0D7AE),
                                      cutSurfaceReveal,
                                    )!,
                                    Color.lerp(
                                      Colors.transparent,
                                      const Color(0xFFC69A64),
                                      cutSurfaceReveal,
                                    )!,
                                  ],
                                ),
                                borderColor: Color.lerp(
                                  Colors.transparent,
                                  const Color(0xFFC99B58),
                                  cutSurfaceReveal,
                                )!,
                                borderWidth: 1.15,
                                shadows: [
                                  BoxShadow(
                                    color: const Color(0x8A090604).withValues(
                                      alpha: 0.54 * cutSurfaceReveal,
                                    ),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: const Color(0x33FFD995).withValues(
                                      alpha: 0.20 * cutSurfaceReveal,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, -2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ClipRect(
                                    child: Align(
                                      heightFactor: cutLabelReveal,
                                      child: Opacity(
                                        opacity: cutLabelReveal,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                              eyebrow,
                                              textAlign: TextAlign.center,
                                              style: Type.label.copyWith(
                                                fontSize: Type.minLabel,
                                                letterSpacing: 1.2,
                                                color: const Color(0xFF6C4726),
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Opacity(
                                    key: const ValueKey(
                                      'goal-workshop-cut-title-opacity',
                                    ),
                                    opacity: cutTitleReveal,
                                    child: Text(
                                      widget.actionTitle,
                                      key: const Key(
                                        'goal-opening-action-title',
                                      ),
                                      textAlign: TextAlign.center,
                                      textScaler: textScaler,
                                      style: cutTitleStyle,
                                    ),
                                  ),
                                  if (widget.xp case final xp?)
                                    ClipRect(
                                      child: Align(
                                        heightFactor: cutLabelReveal,
                                        child: Opacity(
                                          opacity: cutLabelReveal,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Text(
                                              '+$xp XP',
                                              key: const Key(
                                                'goal-workshop-xp',
                                              ),
                                              textAlign: TextAlign.center,
                                              style: Type.label.copyWith(
                                                fontSize: 12,
                                                letterSpacing: 1.1,
                                                color: const Color(0xFF6C4726),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasSecondary || canDisclose || widget.showReturn)
                      _OpeningReveal(
                        reveal: supportReveal,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _OpeningActions(
                            children: [
                              if (widget.onMakeSmaller != null)
                                HoneyButton(
                                  key: const Key(
                                    'goal-workshop-smaller-action',
                                  ),
                                  label: 'Make it smaller',
                                  icon: Icons.compress_rounded,
                                  quiet: true,
                                  compact: true,
                                  enabled: !widget.updating,
                                  onTap: widget.onMakeSmaller!,
                                )
                              else if (widget.preparedByApp &&
                                  widget.onChooseAnother != null)
                                HoneyButton(
                                  key: const Key('goal-opening-choose-another'),
                                  label: 'Choose another first move',
                                  quiet: true,
                                  compact: true,
                                  onTap: widget.onChooseAnother!,
                                ),
                              if (canDisclose)
                                KeyedSubtree(
                                  key: _toggleKey,
                                  child: HoneyButton(
                                    key: const Key('goal-workshop-see-plan'),
                                    label: _planOpen
                                        ? 'Hide the plan'
                                        : plan != null
                                        ? 'See the whole plan'
                                        : 'See the details',
                                    icon: _planOpen
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    quiet: true,
                                    compact: true,
                                    onTap: _togglePlan,
                                  ),
                                ),
                              if (widget.showReturn && widget.onReturn != null)
                                HoneyButton(
                                  key: const Key('goal-workshop-cancel'),
                                  label: 'Return to my room',
                                  icon: Icons.arrow_back_rounded,
                                  quiet: true,
                                  compact: true,
                                  enabled: !widget.updating,
                                  onTap: widget.onReturn!,
                                ),
                            ],
                          ),
                        ),
                      ),
                    // A zero-length AnimatedSize re-dirties its own layout, so a
                    // still screen swaps the plan in without it.
                    if (still) ...[
                      if (_planOpen && canDisclose) details(),
                    ] else
                      AnimatedSize(
                        duration: Motion.quick,
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: _planOpen && canDisclose
                            ? details()
                            : const SizedBox(width: double.infinity),
                      ),
                  ],
                ),
              ),
            ),
            _OpeningReveal(
              reveal: controlsReveal,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 11, 20, 18),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0x3AAB7A49), width: 1),
                  ),
                ),
                child: SizedBox(
                  key: const Key('goal-opening-begin'),
                  child: HoneyButton(
                    key: const Key('goal-workshop-accept'),
                    label: widget.questOwned
                        ? 'Open this Quest'
                        : 'Take this Quest',
                    icon: Icons.arrow_forward_rounded,
                    onTap: widget.onBegin,
                    expand: true,
                    glow: false,
                    semanticLabel: widget.questOwned
                        ? 'Open this Quest, already on the board'
                        : 'Take this Quest, adds it to the board',
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

class _WorkshopFact extends StatelessWidget {
  const _WorkshopFact({
    required this.label,
    required this.value,
    required this.accent,
    this.valueKey,
  });

  final String label;
  final String value;
  final Color accent;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 3,
        height: 32,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                letterSpacing: 0.9,
                color: accent,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              key: valueKey,
              style: Type.body.copyWith(
                fontSize: 13.2,
                height: 1.28,
                color: Palette.textMid,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _OpeningThresholdFolio extends StatelessWidget {
  const _OpeningThresholdFolio({
    required this.contextLabel,
    required this.actionTitle,
    required this.fallbackAction,
    required this.actionLabel,
    required this.actionKey,
    required this.semanticHint,
    required this.onContinue,
    required this.reduceMotion,
  });

  final String contextLabel;
  final String actionTitle;
  final String? fallbackAction;
  final String actionLabel;
  final Key actionKey;
  final String semanticHint;
  final VoidCallback onContinue;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final veryLargeText = MediaQuery.textScalerOf(context).scale(1) > 1.6;
    return _OpeningFolioShell(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OpeningContextLine(contextLabel, accent: Palette.xpLight),
            const SizedBox(height: 10),
            Text(
              actionTitle,
              style: Type.display.copyWith(
                fontSize: 20,
                height: 1.1,
                fontWeight: FontWeight.w500,
                color: Palette.textHi,
              ),
            ),
            if (fallbackAction != null && fallbackAction!.isNotEmpty) ...[
              const SizedBox(height: 11),
              Text(
                'Smaller version',
                style: Type.body.copyWith(
                  fontSize: 13.5,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: Palette.xpLight,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                fallbackAction!,
                style: Type.body.copyWith(
                  fontSize: 14.5,
                  height: 1.34,
                  fontWeight: FontWeight.w500,
                  color: Palette.textHi,
                ),
              ),
            ],
            const SizedBox(height: 13),
            SizedBox(
              height: veryLargeText ? 56 : 52,
              child: GoalPrimaryButton(
                key: actionKey,
                label: actionLabel,
                icon: Icons.arrow_forward_rounded,
                onTap: onContinue,
                expand: true,
                glow: false,
                reduceMotion: reduceMotion,
                treatment: GoalPrimaryButtonTreatment.openingClasp,
                semanticHint: semanticHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpeningFolioShell extends StatelessWidget {
  const _OpeningFolioShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: facetedDecoration(
        cut: 14,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF437281D), Color(0xFA1A120E)],
        ),
        borderColor: const Color(0x99B78754),
        borderWidth: 1.15,
        shadows: const [
          BoxShadow(
            color: Color(0xA80B0705),
            blurRadius: 30,
            offset: Offset(0, 15),
          ),
          BoxShadow(
            color: Color(0x1FF1C782),
            blurRadius: 16,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: ClipPath(
        clipper: const FacetedClipper(cut: 14),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(2.2),
                child: DecoratedBox(
                  decoration: facetedDecoration(
                    cut: 12.4,
                    color: Colors.transparent,
                    borderColor: const Color(0x8A0B0705),
                    borderWidth: 0.9,
                  ),
                ),
              ),
            ),
            const Positioned.fill(child: FacetGleam(cut: 14, strength: 0.72)),
            Positioned(
              left: 24,
              right: 34,
              bottom: 1,
              child: Container(
                height: 1,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0x00100A07),
                      Color(0xB6100A07),
                      Color(0x24100A07),
                      Color(0x00100A07),
                    ],
                  ),
                ),
              ),
            ),
            child,
            const Positioned(
              left: 2,
              right: 2,
              top: 2,
              height: 12,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xC437281D), Color(0x0037281D)],
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

class _OpeningContextLine extends StatelessWidget {
  const _OpeningContextLine(
    this.label, {
    super.key,
    required this.accent,
    this.icon,
    this.shadows = const [],
  });

  final String label;
  final Color accent;
  final IconData? icon;
  final List<Shadow> shadows;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return Row(
      children: [
        if (icon case final glyph?) ...[
          Icon(glyph, size: 14, color: accent.withValues(alpha: 0.92)),
          const SizedBox(width: 7),
        ] else ...[
          Container(
            width: 18,
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.92),
                  accent.withValues(alpha: 0.12),
                ],
              ),
            ),
          ),
          const SizedBox(width: 7),
        ],
        Flexible(
          flex: 6,
          child: Text(
            label,
            style: Type.body.copyWith(
              fontSize: 13.5,
              height: 1.15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              color: Palette.textMid,
              shadows: shadows,
            ),
          ),
        ),
        if (!largeText) ...[
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Palette.brass.withValues(alpha: 0.22),
                    Palette.brass.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _OpeningReveal extends StatelessWidget {
  const _OpeningReveal({required this.reveal, required this.child});

  final double reveal;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final value = reveal.clamp(0.0, 1.0);
    return Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, (1 - value) * 3),
        child: child,
      ),
    );
  }
}
