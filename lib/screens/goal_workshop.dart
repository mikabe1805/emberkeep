import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../clock.dart';
import '../engine.dart';
import '../goal_planner.dart';
import '../models.dart';
import '../steward_memory.dart';
import '../tokens.dart';
import '../widgets/facets.dart';
import '../widgets/goal_steward.dart';
import '../widgets/goal_world.dart';
import '../widgets/luxe_depth.dart';
import '../widgets/pressable.dart';
import '../widgets/steward_room.dart';
import 'steward_encounter.dart';

typedef GoalWorkshopAction = Future<void> Function(Goal goal);

/// The returnable route register inside the steward's tavern workshop.
///
/// This screen owns no planning state. It reads each [GoalPlan] and its exact
/// current Quest identity, then sends the selected goal back through the same
/// workshop bench used by first acceptance and route repair.
class GoalWorkshopScreen extends StatefulWidget {
  const GoalWorkshopScreen({
    super.key,
    required this.state,
    required this.quests,
    required this.onOpenGoal,
    required this.onBuildRoute,
    required this.onFocusGoal,
    required this.onNewGoal,
    this.onPersist,
    this.initialGoalTitle,
  });

  final GameState state;
  final List<Quest> quests;
  final GoalWorkshopAction onOpenGoal;
  final GoalWorkshopAction onBuildRoute;
  final ValueChanged<Goal> onFocusGoal;
  final Future<void> Function() onNewGoal;
  final VoidCallback? onPersist;
  final String? initialGoalTitle;

  @override
  State<GoalWorkshopScreen> createState() => _GoalWorkshopScreenState();
}

class _GoalWorkshopScreenState extends State<GoalWorkshopScreen> {
  late final LuxeMotionController _motion;
  bool _opening = false;
  bool _stewardAssetsCached = false;

  @override
  void initState() {
    super.initState();
    _motion = LuxeMotionController(reduceMotion: widget.state.reduceMotion);
    unawaited(_motion.start());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion.setReduceMotion(
      widget.state.reduceMotion ||
          (MediaQuery.maybeDisableAnimationsOf(context) ?? false),
    );
    if (_stewardAssetsCached) return;
    _stewardAssetsCached = true;
    precacheGoalStewardAssets(context);
    unawaited(precacheStewardRoom(context));
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  String _key(String value) => value.trim().toLowerCase();

  List<Goal> get _activeGoals {
    final goals = widget.state.goals
        .where((goal) => !goal.complete)
        .toList(growable: false);
    final initial = _key(widget.initialGoalTitle ?? '');
    if (initial.isEmpty) return goals;
    return [...goals]..sort((a, b) {
      final aInitial = _key(a.title) == initial;
      final bInitial = _key(b.title) == initial;
      if (aInitial == bInitial) return 0;
      return aInitial ? -1 : 1;
    });
  }

  Future<void> _open(_WorkshopGoalEntry entry) async {
    if (_opening) return;
    if (entry.kind == _WorkshopGoalKind.routeComplete) {
      widget.onFocusGoal(entry.goal);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() => _opening = true);
    try {
      if (entry.kind == _WorkshopGoalKind.needsRoute) {
        await widget.onBuildRoute(entry.goal);
      } else {
        await widget.onOpenGoal(entry.goal);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _newGoal() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await widget.onNewGoal();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _openEncounter() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await Navigator.of(context).push<void>(
        stewardRoomRoute<void>(
          context: context,
          reduceMotion: widget.state.reduceMotion,
          builder: (_) => StewardEncounterScreen(
            state: widget.state,
            onPersist: widget.onPersist,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final still =
            widget.state.reduceMotion ||
            (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
        _motion.setReduceMotion(still);
        final now = Clock.now();
        final entries = [
          for (final goal in _activeGoals)
            _WorkshopGoalEntry.from(goal, widget.quests, now),
        ];
        final waiting = entries
            .where((entry) => entry.kind == _WorkshopGoalKind.cutWaiting)
            .length;
        final moving = entries
            .where((entry) => entry.kind == _WorkshopGoalKind.questOnBoard)
            .length;
        return LayoutBuilder(
          builder: (context, constraints) => MouseRegion(
            onHover: (event) =>
                _motion.handlePointer(event, constraints.biggest),
            onExit: _motion.clearPointer,
            child: Listener(
              onPointerDown: (_) =>
                  unawaited(_motion.requestBrowserMotionPermission()),
              child: _WorkshopRoom(
                entries: entries,
                waiting: waiting,
                moving: moving,
                stewardMemory: widget.state.stewardMemory,
                busy: _opening,
                reduceMotion: still,
                parallax: _motion.parallax,
                light: _motion.light,
                onBack: () => Navigator.of(context).pop(),
                onOpen: _open,
                onNewGoal: _newGoal,
                onOpenEncounter: _openEncounter,
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _WorkshopGoalKind { cutWaiting, questOnBoard, needsRoute, routeComplete }

class _WorkshopGoalEntry {
  const _WorkshopGoalEntry({
    required this.goal,
    required this.kind,
    required this.actionTitle,
    required this.status,
    required this.actionLabel,
    this.routePosition,
  });

  final Goal goal;
  final _WorkshopGoalKind kind;
  final String actionTitle;
  final String status;
  final String actionLabel;
  final String? routePosition;

  static String _key(String value) => value.trim().toLowerCase();

  static Quest? _legacyQuest(Goal goal, Iterable<Quest> quests, DateTime now) {
    for (final quest in quests) {
      if (_key(quest.goalTitle ?? '') == _key(goal.title) &&
          !quest.doneFor(now) &&
          GoalPlanner.questActionableToday(quest, now)) {
        return quest;
      }
    }
    return null;
  }

  factory _WorkshopGoalEntry.from(
    Goal goal,
    Iterable<Quest> quests,
    DateTime now,
  ) {
    final decision = GoalPlanner.decide(goal, quests, now);
    if (decision != null) {
      final owned = decision.quest != null;
      return _WorkshopGoalEntry(
        goal: goal,
        kind: owned
            ? _WorkshopGoalKind.questOnBoard
            : _WorkshopGoalKind.cutWaiting,
        actionTitle: decision.actionTitle,
        status: owned ? 'QUEST ON BOARD' : 'CUT WAITING',
        actionLabel: 'Open bench',
        routePosition: decision.routePosition,
      );
    }
    if (goal.plan == null) {
      final legacy = _legacyQuest(goal, quests, now);
      if (legacy != null) {
        return _WorkshopGoalEntry(
          goal: goal,
          kind: _WorkshopGoalKind.questOnBoard,
          actionTitle: legacy.displayTitle,
          status: 'QUEST ON BOARD',
          actionLabel: 'Open bench',
        );
      }
      return _WorkshopGoalEntry(
        goal: goal,
        kind: _WorkshopGoalKind.needsRoute,
        actionTitle: 'No route has been shaped for this goal yet.',
        status: 'NEEDS A ROUTE',
        actionLabel: 'Build route',
      );
    }
    return _WorkshopGoalEntry(
      goal: goal,
      kind: _WorkshopGoalKind.routeComplete,
      actionTitle: 'Every marker in this route is complete.',
      status: 'ROUTE COMPLETE',
      actionLabel: 'Return to goal',
    );
  }
}

class _WorkshopRoom extends StatelessWidget {
  const _WorkshopRoom({
    required this.entries,
    required this.waiting,
    required this.moving,
    required this.stewardMemory,
    required this.busy,
    required this.reduceMotion,
    required this.parallax,
    required this.light,
    required this.onBack,
    required this.onOpen,
    required this.onNewGoal,
    required this.onOpenEncounter,
  });

  final List<_WorkshopGoalEntry> entries;
  final int waiting;
  final int moving;
  final StewardMemory stewardMemory;
  final bool busy;
  final bool reduceMotion;
  final ValueListenable<Offset> parallax;
  final ValueListenable<Offset> light;
  final VoidCallback onBack;
  final ValueChanged<_WorkshopGoalEntry> onOpen;
  final VoidCallback onNewGoal;
  final VoidCallback onOpenEncounter;

  String get _summary {
    final parts = <String>[];
    if (waiting > 0) {
      parts.add('$waiting ${waiting == 1 ? 'cut' : 'cuts'} waiting');
    }
    if (moving > 0) {
      parts.add('$moving ${moving == 1 ? 'Quest' : 'Quests'} on board');
    }
    final unshaped = entries
        .where((entry) => entry.kind == _WorkshopGoalKind.needsRoute)
        .length;
    if (unshaped > 0) {
      parts.add('$unshaped ${unshaped == 1 ? 'route' : 'routes'} to shape');
    }
    final complete = entries
        .where((entry) => entry.kind == _WorkshopGoalKind.routeComplete)
        .length;
    if (complete > 0) {
      parts.add('$complete ${complete == 1 ? 'route' : 'routes'} complete');
    }
    if (parts.isEmpty) return 'Nothing is waiting on the bench';
    return parts.join('  ·  ');
  }

  GoalStewardExpression get _stewardExpression {
    return resolveGoalStewardRegisterExpression(
      hasCutWaiting: entries.any(
        (entry) => entry.kind == _WorkshopGoalKind.cutWaiting,
      ),
      hasRouteToShape: entries.any(
        (entry) => entry.kind == _WorkshopGoalKind.needsRoute,
      ),
      hasQuestOnBoard: entries.any(
        (entry) => entry.kind == _WorkshopGoalKind.questOnBoard,
      ),
      hasCompletedRoute: entries.any(
        (entry) => entry.kind == _WorkshopGoalKind.routeComplete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compact = surface.height < 700 || textScale > 1.2;
    final still =
        reduceMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return PopScope<Object?>(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: const Color(0xFF100D0B),
        body: Stack(
          fit: StackFit.expand,
          children: [
            GoalStewardArtwork(
              key: const Key('goal-workshop-tavern'),
              expression: _stewardExpression,
              reduceMotion: still,
              parallax: parallax,
              light: light,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: goalsWorkshopDetailScrim),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _WorkshopBackButton(enabled: !busy, onTap: onBack),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // The register belongs on the lower counter. Even on
                          // compact phones it must leave the steward's face and
                          // offered route card visible; the slips scroll inside
                          // the bench instead of growing over him.
                          final visibleRows = entries.length.clamp(1, 3);
                          final desiredHeight = 236.0 + (visibleRows * 62.0);
                          final compactFraction = textScale > 1.4 ? 0.92 : 0.62;
                          final maxPanelHeight =
                              constraints.maxHeight *
                              (compact ? compactFraction : 0.52);
                          final minPanelHeight = compact
                              ? maxPanelHeight * 0.88
                              : 390.0.clamp(0.0, maxPanelHeight);
                          final panelHeight = desiredHeight.clamp(
                            minPanelHeight,
                            maxPanelHeight,
                          );
                          return Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              if (!stewardMemory.discovered && !compact)
                                Positioned(
                                  right: 2,
                                  bottom: panelHeight + 12,
                                  child: _StewardHiddenCard(
                                    enabled: !busy,
                                    onTap: onOpenEncounter,
                                  ),
                                ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: AnimatedOpacity(
                                  duration: still ? Motion.ack : Motion.quick,
                                  opacity: busy ? 0.78 : 1,
                                  child: SizedBox(
                                    height: panelHeight,
                                    child: _WorkshopRegister(
                                      entries: entries,
                                      summary: _summary,
                                      stewardMemory: stewardMemory,
                                      showDiscoveryInFooter:
                                          !stewardMemory.discovered && compact,
                                      busy: busy,
                                      onOpen: onOpen,
                                      onNewGoal: onNewGoal,
                                      onOpenEncounter: onOpenEncounter,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkshopBackButton extends StatelessWidget {
  const _WorkshopBackButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    key: const Key('goal-workshop-home-back'),
    enabled: enabled,
    soundEnabled: false,
    pressDepth: 1.2,
    shape: const FacetedBorder(cut: 9),
    edgeColor: Colors.transparent,
    semanticLabel: 'Return to Goals',
    onTapUp: (_) => onTap(),
    child: Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: facetedDecoration(
        cut: 9,
        color: const Color(0xC2211812),
        borderColor: const Color(0x6FC69A64),
        shadows: const [
          BoxShadow(
            color: Color(0x6A080503),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.arrow_back_rounded, color: Palette.textHi),
    ),
  );
}

class _WorkshopRegister extends StatefulWidget {
  const _WorkshopRegister({
    required this.entries,
    required this.summary,
    required this.stewardMemory,
    required this.showDiscoveryInFooter,
    required this.busy,
    required this.onOpen,
    required this.onNewGoal,
    required this.onOpenEncounter,
  });

  final List<_WorkshopGoalEntry> entries;
  final String summary;
  final StewardMemory stewardMemory;
  final bool showDiscoveryInFooter;
  final bool busy;
  final ValueChanged<_WorkshopGoalEntry> onOpen;
  final VoidCallback onNewGoal;
  final VoidCallback onOpenEncounter;

  @override
  State<_WorkshopRegister> createState() => _WorkshopRegisterState();
}

class _WorkshopRegisterState extends State<_WorkshopRegister> {
  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compact = MediaQuery.sizeOf(context).height < 700 || textScale > 1.2;
    final largeText = textScale > 1.2;
    final hasFileBoxEntry =
        widget.stewardMemory.discovered || widget.showDiscoveryInFooter;
    Widget fileBoxAction(Alignment alignment) => TextButton.icon(
      key: widget.stewardMemory.discovered
          ? const Key('goal-workshop-talk')
          : const Key('steward-hidden-card'),
      onPressed: widget.busy ? null : widget.onOpenEncounter,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: alignment,
        textStyle: Type.body.copyWith(
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: const Icon(Icons.inventory_2_outlined, size: 17),
      label: Text(
        widget.stewardMemory.discovered
            ? widget.stewardMemory.nodeId != null &&
                      !widget.stewardMemory.completed
                  ? 'Continue talking'
                  : 'Talk with the Steward'
            : 'Talk with the Steward',
      ),
    );
    Widget newGoalAction(Alignment alignment) => TextButton.icon(
      key: const Key('goal-workshop-home-new-goal'),
      onPressed: widget.busy ? null : widget.onNewGoal,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: alignment,
        textStyle: Type.body.copyWith(
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: const Icon(Icons.add_rounded, size: 17),
      label: const Text('New goal'),
    );
    return KeyedSubtree(
      key: const Key('goal-workshop-home'),
      child: ClipPath(
        clipper: const FacetedClipper(cut: 13),
        child: DecoratedBox(
          decoration: facetedDecoration(
            cut: 13,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFA34261C), Color(0xFC160F0B)],
            ),
            borderColor: const Color(0xA8B47C43),
            borderWidth: 1.15,
            shadows: const [
              BoxShadow(
                color: Color(0xA1080503),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  key: const PageStorageKey<String>(
                    'goal-workshop-home-scroll',
                  ),
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        19,
                        compact ? 15 : 18,
                        19,
                        12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.home_repair_service_outlined,
                                size: 16,
                                color: Palette.brassLit,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "AT THE STEWARD'S BENCH",
                                  maxLines: compact ? 2 : 1,
                                  style: Type.label.copyWith(
                                    fontSize: 11,
                                    letterSpacing: 1.15,
                                    color: Palette.brassLit,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'What are we working on?',
                            style: Type.display.copyWith(
                              fontSize: compact ? 19 : 28,
                              height: 1.02,
                              color: Palette.textHi,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Choose a goal. We'll open the Quest you have, or shape the next move together.",
                            style: Type.body.copyWith(
                              fontSize: compact ? 13 : 13.5,
                              height: 1.3,
                              color: Palette.textMid,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            widget.summary.toUpperCase(),
                            key: const Key('goal-workshop-home-summary'),
                            style: Type.label.copyWith(
                              fontSize: 11,
                              letterSpacing: 0.72,
                              color: Palette.textMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0x48A97445),
                    ),
                    if (widget.entries.isEmpty)
                      _WorkshopEmpty(onNewGoal: widget.onNewGoal)
                    else
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          compact ? 8 : 10,
                          12,
                          10,
                        ),
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < widget.entries.length;
                              index++
                            ) ...[
                              _WorkshopGoalSlip(
                                entry: widget.entries[index],
                                enabled: !widget.busy,
                                onTap: () =>
                                    widget.onOpen(widget.entries[index]),
                              ),
                              if (index != widget.entries.length - 1)
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  indent: 12,
                                  endIndent: 12,
                                  color: Color(0x31986A3E),
                                ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 7, 18, 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0x3AAB7A49))),
                ),
                child: hasFileBoxEntry && largeText
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          fileBoxAction(Alignment.centerLeft),
                          const SizedBox(height: 4),
                          newGoalAction(Alignment.centerLeft),
                        ],
                      )
                    : Row(
                        children: [
                          if (hasFileBoxEntry)
                            Expanded(
                              child: fileBoxAction(Alignment.centerLeft),
                            ),
                          if (hasFileBoxEntry) const SizedBox(width: 4),
                          Expanded(
                            child: newGoalAction(
                              hasFileBoxEntry
                                  ? Alignment.centerRight
                                  : Alignment.center,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StewardHiddenCard extends StatelessWidget {
  const _StewardHiddenCard({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    key: const Key('steward-hidden-card'),
    enabled: enabled,
    soundEnabled: false,
    pressDepth: 1,
    shape: const FacetedBorder(cut: 9),
    edgeColor: Colors.transparent,
    semanticLabel: 'Talk with the Steward',
    semanticHint: 'Start a short optional conversation',
    onTapUp: (_) => onTap(),
    child: ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(minWidth: 160, minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: facetedDecoration(
          cut: 9,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE3CFA6), Color(0xFFB99766)],
          ),
          borderColor: const Color(0xFFCBAE78),
          borderWidth: 1.1,
          shadows: const [
            BoxShadow(
              color: Color(0x90080603),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          'Talk with the Steward',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'EBGaramond',
            fontSize: 16,
            height: 1.1,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF28180E),
          ),
        ),
      ),
    ),
  );
}

class _WorkshopGoalSlip extends StatelessWidget {
  const _WorkshopGoalSlip({
    required this.entry,
    required this.enabled,
    required this.onTap,
  });

  final _WorkshopGoalEntry entry;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = entry.goal.stat.color;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compact = MediaQuery.sizeOf(context).height < 700 || textScale > 1.2;
    final semantic =
        '${entry.goal.title}. ${entry.status}. ${entry.actionTitle}. ${entry.actionLabel}.';
    return Pressable(
      key: ValueKey<String>('goal-workshop-home-goal-${entry.goal.title}'),
      enabled: enabled,
      soundEnabled: false,
      pressDepth: 1,
      borderRadius: BorderRadius.circular(7),
      edgeColor: Colors.transparent,
      semanticLabel: semantic,
      semanticHint: entry.actionLabel,
      onTapUp: (_) => onTap(),
      stateBuilder: (context, child, pressed, focused, hovered) =>
          AnimatedContainer(
            duration: pressed ? Duration.zero : Motion.ack,
            decoration: BoxDecoration(
              color: pressed
                  ? accent.withValues(alpha: 0.10)
                  : focused || hovered
                  ? accent.withValues(alpha: 0.055)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: child,
          ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, compact ? 9 : 12, 8, compact ? 9 : 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: compact ? 62 : 48,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: compact
                  ? _CompactWorkshopGoalSlip(entry: entry, accent: accent)
                  : _RegularWorkshopGoalSlip(entry: entry, accent: accent),
            ),
            if (!compact) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: accent.withValues(alpha: 0.82),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RegularWorkshopGoalSlip extends StatelessWidget {
  const _RegularWorkshopGoalSlip({required this.entry, required this.accent});

  final _WorkshopGoalEntry entry;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              entry.goal.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Type.body.copyWith(
                fontSize: 14,
                height: 1.12,
                fontWeight: FontWeight.w600,
                color: Palette.textHi,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            entry.status,
            style: Type.label.copyWith(
              fontSize: Type.minLabel,
              letterSpacing: 0.62,
              color: Palette.textMid,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        entry.actionTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Type.body.copyWith(
          fontSize: 13,
          height: 1.22,
          color: Palette.textMid,
        ),
      ),
      if (entry.routePosition case final position?) ...[
        const SizedBox(height: 4),
        Text(
          position,
          style: Type.label.copyWith(
            fontSize: Type.minLabel,
            letterSpacing: 0.68,
            color: Palette.textMid,
          ),
        ),
      ],
    ],
  );
}

class _CompactWorkshopGoalSlip extends StatelessWidget {
  const _CompactWorkshopGoalSlip({required this.entry, required this.accent});

  final _WorkshopGoalEntry entry;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              entry.status,
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                letterSpacing: 0.58,
                color: Palette.textMid,
              ),
            ),
          ),
          Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: accent.withValues(alpha: 0.82),
          ),
        ],
      ),
      const SizedBox(height: 3),
      Text(
        entry.goal.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Type.body.copyWith(
          fontSize: 13.5,
          height: 1.12,
          fontWeight: FontWeight.w600,
          color: Palette.textHi,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        entry.actionTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Type.body.copyWith(
          fontSize: 13,
          height: 1.16,
          color: Palette.textMid,
        ),
      ),
    ],
  );
}

class _WorkshopEmpty extends StatelessWidget {
  const _WorkshopEmpty({required this.onNewGoal});

  final VoidCallback onNewGoal;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
      child: Column(
        children: [
          const Icon(Icons.handyman_outlined, size: 28, color: Palette.textLo),
          const SizedBox(height: 10),
          Text(
            'The bench is clear.',
            style: Type.display.copyWith(fontSize: 21, color: Palette.textHi),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a goal when there is something you want to make different.',
            textAlign: TextAlign.center,
            style: Type.body.copyWith(color: Palette.textMid),
          ),
        ],
      ),
    ),
  );
}
