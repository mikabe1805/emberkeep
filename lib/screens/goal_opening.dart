import 'dart:async';

import 'package:flutter/material.dart';

import '../audio.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/facets.dart';
import '../widgets/goal_primary_button.dart';
import '../widgets/goal_steward.dart';
import '../widgets/goal_world.dart';
import '../widgets/luxe_depth.dart';
import '../widgets/pressable.dart';

enum _GoalOpeningStage { desk, wideRoom, threshold, arrival }

enum _GoalOpeningMotionLeg { idle, deskRetreat, archApproach, doorwayCrossing }

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

  @override
  State<GoalOpeningScreen> createState() => _GoalOpeningScreenState();
}

class _GoalOpeningScreenState extends State<GoalOpeningScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _room;
  late final LuxeMotionController _motion;
  late String _actionTitle;
  late _GoalOpeningStage _stage;
  _GoalOpeningMotionLeg _motionLeg = _GoalOpeningMotionLeg.idle;
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

  double get _travelBlur {
    if (_still || !_moving) return 0;
    final legWeight = switch (_motionLeg) {
      _GoalOpeningMotionLeg.idle => 0.0,
      _GoalOpeningMotionLeg.deskRetreat =>
        _room.value < _goalOpeningWideRoomProgress ? 1.8 : 0.95,
      _GoalOpeningMotionLeg.archApproach => 0.95,
      _GoalOpeningMotionLeg.doorwayCrossing => 2.15,
    };
    return (_room.velocity.abs() * legWeight).clamp(0.0, 2.2);
  }

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
    required _GoalOpeningMotionLeg motionLeg,
    Curve curve = Curves.easeInOutCubic,
  }) async {
    if (_moving || target == _stage) return;
    if (_still) {
      setState(() {
        _stage = target;
        _motionLeg = _GoalOpeningMotionLeg.idle;
      });
      return;
    }
    setState(() {
      _moving = true;
      _motionLeg = motionLeg;
    });
    await _room.animateTo(progress, duration: duration, curve: curve);
    if (!mounted) return;
    setState(() {
      _stage = target;
      _moving = false;
      _motionLeg = _GoalOpeningMotionLeg.idle;
    });
  }

  // Each camera destination belongs to the person. Reaching the wide room is
  // a real stop: the route remains parked until they choose to cross it.
  Future<void> _showPlan() => _moveTo(
    _GoalOpeningStage.wideRoom,
    progress: _goalOpeningWideRoomProgress,
    duration: const Duration(milliseconds: 760),
    motionLeg: _GoalOpeningMotionLeg.deskRetreat,
    curve: Curves.easeOutCubic,
  );

  Future<void> _approachArch() => _moveTo(
    _GoalOpeningStage.threshold,
    progress: _goalOpeningThresholdProgress,
    duration: const Duration(milliseconds: 1040),
    motionLeg: _GoalOpeningMotionLeg.archApproach,
    curve: const Cubic(0.20, 0.72, 0.18, 1),
  );

  Future<void> _stepIn() => _moveTo(
    _GoalOpeningStage.arrival,
    progress: 1,
    duration: const Duration(milliseconds: 1120),
    motionLeg: _GoalOpeningMotionLeg.doorwayCrossing,
    curve: const Cubic(0.42, 0.02, 0.18, 1),
  );

  Future<void> _returnToDesk() => _moveTo(
    _GoalOpeningStage.desk,
    progress: 0,
    duration: const Duration(milliseconds: 720),
    motionLeg: _GoalOpeningMotionLeg.deskRetreat,
    curve: Curves.easeInOutCubic,
  );

  Future<void> _returnToWideRoom() => _moveTo(
    _GoalOpeningStage.wideRoom,
    progress: _goalOpeningWideRoomProgress,
    duration: const Duration(milliseconds: 840),
    motionLeg: _GoalOpeningMotionLeg.archApproach,
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
          'Change the cut',
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
            child: const Text('USE THIS CUT'),
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
          motionLeg: _GoalOpeningMotionLeg.doorwayCrossing,
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
            builder: (context, _) =>
                _buildScene(_room.value, travelBlur: _travelBlur),
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

  Widget _buildScene(double progress, {double travelBlur = 0}) {
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
                motionBlur: travelBlur,
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
                                : 'Marker 1 of ${goal.plan!.steps.length}',
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
                            : 'Open route',
                        icon: Icons.arrow_forward_rounded,
                        onTap: onContinue,
                        glow: false,
                        reduceMotion: reduceMotion,
                        pendingLabel: 'Opening',
                        treatment: GoalPrimaryButtonTreatment.openingClasp,
                        semanticHint: goal.plan == null
                            ? 'Reveal the prepared first move.'
                            : 'Reveal the complete route and its first Quest.',
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
                          'A lighter route is ready if you need it.',
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
                            : 'Marker 1 of ${goal.plan!.steps.length}',
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
                      'A lighter route is ready if you need it.',
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
                label: goal.plan == null ? 'See the move' : 'Open route',
                icon: Icons.arrow_forward_rounded,
                onTap: onContinue,
                expand: true,
                glow: false,
                reduceMotion: reduceMotion,
                pendingLabel: 'Opening',
                treatment: GoalPrimaryButtonTreatment.openingClasp,
                semanticHint: goal.plan == null
                    ? 'Reveal the prepared first move.'
                    : 'Reveal the complete route and its first Quest.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpeningRoutePreview extends StatelessWidget {
  const _OpeningRoutePreview({required this.plan, required this.accent});

  final GoalPlan plan;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
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
              'ROUTE KEPT',
              style: Type.label.copyWith(
                fontSize: 9,
                letterSpacing: 1.1,
                color: accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${plan.steps.length - plan.currentStepIndex} marker${plan.steps.length - plan.currentStepIndex == 1 ? '' : 's'} remain',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Type.body.copyWith(
                  fontSize: 10.5,
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
                width: 19,
                height: 19,
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
                    fontSize: 7.8,
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
                    fontSize: 12,
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

class _OpeningArrivalFolio extends StatelessWidget {
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
  final bool questOwned;
  final bool updating;
  final bool reduceMotion;
  final bool compact;
  final double reveal;

  @override
  Widget build(BuildContext context) {
    final still =
        reduceMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final primaryReveal = still
        ? 1.0
        : Curves.easeOutCubic.transform(_openingSegment(reveal, 0.80, 0.90));
    final detailsReveal = still
        ? 1.0
        : Curves.easeOutCubic.transform(_openingSegment(reveal, 0.90, 0.975));
    final supportReveal = still
        ? 1.0
        : Curves.easeOutCubic.transform(_openingSegment(reveal, 0.94, 0.99));
    final controlsReveal = still
        ? 1.0
        : Curves.easeOutCubic.transform(_openingSegment(reveal, 0.965, 1));
    final cutSurfaceReveal = still
        ? 1.0
        : Curves.easeOutCubic.transform(_openingSegment(reveal, 0.78, 0.88));
    final cutTitleReveal = still
        ? 1.0
        : Curves.easeOutCubic.transform(_openingSegment(reveal, 0.82, 0.88));
    final cutInkReveal = still
        ? 1.0
        : Curves.easeOutCubic.transform(_openingSegment(reveal, 0.87, 0.97));
    final cutLabelReveal = still
        ? 1.0
        : Curves.easeOutCubic.transform(_openingSegment(reveal, 0.92, 0.985));
    final textScaler = MediaQuery.textScalerOf(context);
    final largeText = textScaler.scale(1) > 1.2;
    final compactWorkshop = compact;
    final plan = goal.plan;
    final step = plan?.currentStep;
    final marker = plan == null
        ? 'FIRST QUEST'
        : 'MARKER ${plan.currentStepIndex + 1} OF ${plan.steps.length}';
    final cutTitleStyle = TextStyle.lerp(
      TextStyle(
        fontFamily: 'EBGaramond',
        fontSize: compactWorkshop ? 23.5 : 27,
        height: 0.98,
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
        fontSize: compactWorkshop ? 19 : 25,
        height: 1.0,
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

    return KeyedSubtree(
      key: const Key('goal-workshop-screen'),
      child: _OpeningFolioShell(
        child: Column(
          children: [
            Flexible(
              child: SingleChildScrollView(
                key: const PageStorageKey<String>('goal-workshop-scroll'),
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
                            'The steward\'s workshop',
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
                                fontSize: 8.5,
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
                                    fontSize: 8.5,
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
                                              questOwned
                                                  ? 'CURRENT QUEST'
                                                  : 'THE CUT',
                                              textAlign: TextAlign.center,
                                              style: Type.label.copyWith(
                                                fontSize: 8.5,
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
                                      actionTitle,
                                      key: const Key(
                                        'goal-opening-action-title',
                                      ),
                                      maxLines: compactWorkshop ? null : 3,
                                      overflow: compactWorkshop
                                          ? TextOverflow.visible
                                          : TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      textScaler: compactWorkshop
                                          ? textScaler
                                          : textScaler.clamp(
                                              maxScaleFactor: 1.45,
                                            ),
                                      style: cutTitleStyle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (step != null || plan != null)
                            _OpeningReveal(
                              reveal: detailsReveal,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (step != null) ...[
                                    const SizedBox(height: 12),
                                    _WorkshopFact(
                                      label: 'WHY THIS ONE',
                                      value: step.whyNow,
                                      valueKey: const Key('goal-workshop-why'),
                                      accent: goal.stat.color,
                                    ),
                                    const SizedBox(height: 9),
                                    _WorkshopFact(
                                      label: 'PROOF TO LEAVE BEHIND',
                                      value: step.proof,
                                      valueKey: const Key(
                                        'goal-workshop-proof',
                                      ),
                                      accent: goal.stat.color,
                                    ),
                                  ],
                                  if (plan != null) ...[
                                    const SizedBox(height: 12),
                                    _OpeningRoutePreview(
                                      plan: plan,
                                      accent: goal.stat.color,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (fallbackAction != null && fallbackAction!.isNotEmpty)
                      _OpeningReveal(
                        reveal: supportReveal,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 11),
                          child: _WorkshopFact(
                            label: 'SMALLER CUT KEPT READY',
                            value: fallbackAction!,
                            accent: goal.stat.color,
                          ),
                        ),
                      ),
                    if (onEditAction != null ||
                        onMakeSmaller != null ||
                        onReworkRoute != null ||
                        (preparedByApp && onChooseAnother != null) ||
                        onReturn != null)
                      _OpeningReveal(
                        reveal: controlsReveal,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (onEditAction != null || onMakeSmaller != null)
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 4,
                                  runSpacing: 0,
                                  children: [
                                    if (onEditAction != null)
                                      TextButton.icon(
                                        key: const Key(
                                          'goal-workshop-edit-action',
                                        ),
                                        onPressed: updating
                                            ? null
                                            : onEditAction,
                                        icon: const Icon(
                                          Icons.cut_rounded,
                                          size: 17,
                                        ),
                                        label: const Text('Change the cut'),
                                      ),
                                    if (onMakeSmaller != null)
                                      TextButton.icon(
                                        key: const Key(
                                          'goal-workshop-smaller-action',
                                        ),
                                        onPressed: updating
                                            ? null
                                            : onMakeSmaller,
                                        icon: const Icon(
                                          Icons.compress_rounded,
                                          size: 17,
                                        ),
                                        label: const Text('Make it smaller'),
                                      ),
                                  ],
                                )
                              else if (preparedByApp && onChooseAnother != null)
                                TextButton(
                                  key: const Key('goal-opening-choose-another'),
                                  onPressed: onChooseAnother,
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size.fromHeight(44),
                                    foregroundColor: Palette.textMid,
                                  ),
                                  child: Text(
                                    'Choose another first move',
                                    style: Type.body.copyWith(
                                      fontSize: 13.5,
                                      height: 1.2,
                                      fontWeight: FontWeight.w500,
                                      color: Palette.textMid,
                                    ),
                                  ),
                                ),
                              if (onReworkRoute != null)
                                TextButton.icon(
                                  key: const Key('goal-workshop-rework-route'),
                                  onPressed: updating ? null : onReworkRoute,
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size.fromHeight(44),
                                    foregroundColor: Palette.textMid,
                                  ),
                                  icon: const Icon(
                                    Icons.alt_route_rounded,
                                    size: 17,
                                  ),
                                  label: const Text('Rework the route'),
                                ),
                              if (onReturn != null)
                                TextButton.icon(
                                  key: const Key('goal-workshop-cancel'),
                                  onPressed: updating ? null : onReturn,
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size.fromHeight(44),
                                    foregroundColor: Palette.textLo,
                                  ),
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Return to my room'),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _OpeningReveal(
              reveal: controlsReveal,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 9, 20, 18),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0x3AAB7A49), width: 1),
                  ),
                ),
                child: SizedBox(
                  key: const Key('goal-opening-begin'),
                  height: largeText ? 58 : 54,
                  child: GoalPrimaryButton(
                    key: const Key('goal-workshop-accept'),
                    label: questOwned ? 'Open this Quest' : 'Take this Quest',
                    icon: Icons.arrow_forward_rounded,
                    onTap: onBegin,
                    expand: true,
                    glow: false,
                    reduceMotion: reduceMotion,
                    pendingLabel: questOwned
                        ? 'Opening the Quest'
                        : 'Taking the Quest',
                    treatment: GoalPrimaryButtonTreatment.openingClasp,
                    semanticHint: questOwned
                        ? 'Open the exact Quest already on the board.'
                        : 'Add this exact Quest to the board and open it.',
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
                fontSize: 8.2,
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
                'Lighter version',
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
          child: Text(
            label,
            style: Type.body.copyWith(
              fontSize: 12.5,
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
