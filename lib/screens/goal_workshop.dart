import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../clock.dart';
import '../engine.dart';
import '../goal_planner.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/facets.dart';
import '../widgets/goal_steward.dart';
import '../widgets/goal_world.dart';
import '../widgets/luxe_depth.dart';
import '../widgets/pressable.dart';

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
    this.initialGoalTitle,
  });

  final GameState state;
  final List<Quest> quests;
  final GoalWorkshopAction onOpenGoal;
  final GoalWorkshopAction onBuildRoute;
  final ValueChanged<Goal> onFocusGoal;
  final Future<void> Function() onNewGoal;
  final String? initialGoalTitle;

  @override
  State<GoalWorkshopScreen> createState() => _GoalWorkshopScreenState();
}

class _GoalWorkshopScreenState extends State<GoalWorkshopScreen> {
  late final LuxeMotionController _motion;
  bool _opening = false;
  bool _conversationOpen = false;
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
                conversationOpen: _conversationOpen,
                busy: _opening,
                reduceMotion: still,
                parallax: _motion.parallax,
                light: _motion.light,
                onBack: () => Navigator.of(context).pop(),
                onOpen: _open,
                onNewGoal: _newGoal,
                onConversationChanged: (open) {
                  if (_conversationOpen == open) return;
                  setState(() => _conversationOpen = open);
                },
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

class _WorkshopDialogueOption {
  const _WorkshopDialogueOption({
    required this.id,
    required this.prompt,
    required this.response,
  });

  final String id;
  final String prompt;
  final String response;
}

class _WorkshopConversation {
  const _WorkshopConversation({required this.contextual});

  final _WorkshopDialogueOption contextual;

  static const goodCut = _WorkshopDialogueOption(
    id: 'good-cut',
    prompt: 'What makes a good cut?',
    response:
        'Small enough to begin, clear enough to finish, and worth leaving proof behind.',
  );

  static const changingDay = _WorkshopDialogueOption(
    id: 'changing-day',
    prompt: 'What if today changes?',
    response:
        'Then the cut changes. Finished marks stay; unfinished work can be shaped again.',
  );

  List<_WorkshopDialogueOption> get options => [
    contextual,
    goodCut,
    changingDay,
  ];

  factory _WorkshopConversation.fromEntries(List<_WorkshopGoalEntry> entries) {
    _WorkshopGoalEntry? firstOf(_WorkshopGoalKind kind) {
      for (final entry in entries) {
        if (entry.kind == kind) return entry;
      }
      return null;
    }

    if (firstOf(_WorkshopGoalKind.cutWaiting) case final entry?) {
      return _WorkshopConversation(
        contextual: _WorkshopDialogueOption(
          id: 'waiting-cut',
          prompt: 'What is waiting for me?',
          response:
              '${entry.actionTitle} is the cut waiting for ${entry.goal.title}. '
              'It is only an offer. Change it, make it smaller, or take it when it fits.',
        ),
      );
    }
    if (firstOf(_WorkshopGoalKind.needsRoute) case final entry?) {
      return _WorkshopConversation(
        contextual: _WorkshopDialogueOption(
          id: 'needs-route',
          prompt: 'Where do we start?',
          response:
              '${entry.goal.title} has no route yet. Start with what is true today; '
              'the next move can be shaped from there.',
        ),
      );
    }
    if (firstOf(_WorkshopGoalKind.questOnBoard) case final entry?) {
      return _WorkshopConversation(
        contextual: _WorkshopDialogueOption(
          id: 'quest-on-board',
          prompt: 'What is already moving?',
          response:
              '${entry.actionTitle} is already on the board for ${entry.goal.title}. '
              'The route can change without erasing what you have done.',
        ),
      );
    }
    if (firstOf(_WorkshopGoalKind.routeComplete) case final entry?) {
      return _WorkshopConversation(
        contextual: _WorkshopDialogueOption(
          id: 'route-complete',
          prompt: 'What happens when a route ends?',
          response:
              '${entry.goal.title} has enough proof for this route. '
              'Nothing new is being assigned here.',
        ),
      );
    }
    return const _WorkshopConversation(
      contextual: _WorkshopDialogueOption(
        id: 'empty-bench',
        prompt: 'What belongs on the bench?',
        response:
            'Only something you actually want to make different belongs here. '
            'An empty bench is allowed.',
      ),
    );
  }
}

class _WorkshopRoom extends StatelessWidget {
  const _WorkshopRoom({
    required this.entries,
    required this.waiting,
    required this.moving,
    required this.conversationOpen,
    required this.busy,
    required this.reduceMotion,
    required this.parallax,
    required this.light,
    required this.onBack,
    required this.onOpen,
    required this.onNewGoal,
    required this.onConversationChanged,
  });

  final List<_WorkshopGoalEntry> entries;
  final int waiting;
  final int moving;
  final bool conversationOpen;
  final bool busy;
  final bool reduceMotion;
  final ValueListenable<Offset> parallax;
  final ValueListenable<Offset> light;
  final VoidCallback onBack;
  final ValueChanged<_WorkshopGoalEntry> onOpen;
  final VoidCallback onNewGoal;
  final ValueChanged<bool> onConversationChanged;

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
                          final desiredHeight =
                              236.0 +
                              (visibleRows * 62.0) +
                              (conversationOpen && !compact ? 54.0 : 0.0);
                          final compactFraction = textScale > 1.4
                              ? conversationOpen
                                    ? 0.98
                                    : 0.92
                              : 0.62;
                          final maxPanelHeight =
                              constraints.maxHeight *
                              (compact
                                  ? compactFraction
                                  : conversationOpen
                                  ? 0.60
                                  : 0.52);
                          final minPanelHeight = compact
                              ? maxPanelHeight * 0.88
                              : 390.0.clamp(0.0, maxPanelHeight);
                          final panelHeight = desiredHeight.clamp(
                            minPanelHeight,
                            maxPanelHeight,
                          );
                          return Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedOpacity(
                              duration: still ? Motion.ack : Motion.quick,
                              opacity: busy ? 0.78 : 1,
                              child: SizedBox(
                                height: panelHeight,
                                child: _WorkshopRegister(
                                  entries: entries,
                                  conversation:
                                      _WorkshopConversation.fromEntries(
                                        entries,
                                      ),
                                  summary: _summary,
                                  busy: busy,
                                  onOpen: onOpen,
                                  onNewGoal: onNewGoal,
                                  onConversationChanged: onConversationChanged,
                                ),
                              ),
                            ),
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
    required this.conversation,
    required this.summary,
    required this.busy,
    required this.onOpen,
    required this.onNewGoal,
    required this.onConversationChanged,
  });

  final List<_WorkshopGoalEntry> entries;
  final _WorkshopConversation conversation;
  final String summary;
  final bool busy;
  final ValueChanged<_WorkshopGoalEntry> onOpen;
  final VoidCallback onNewGoal;
  final ValueChanged<bool> onConversationChanged;

  @override
  State<_WorkshopRegister> createState() => _WorkshopRegisterState();
}

class _WorkshopRegisterState extends State<_WorkshopRegister> {
  final ScrollController _conversationScroll = ScrollController();
  bool _talking = false;
  String? _selectedOptionId;

  void _toggleConversation() {
    if (widget.busy) return;
    final openingConversation = !_talking;
    setState(() {
      _talking = openingConversation;
      _selectedOptionId = null;
    });
    widget.onConversationChanged(openingConversation);
    if (openingConversation) _revealConversation(showResponse: false);
  }

  void _selectOption(String id) {
    if (widget.busy || _selectedOptionId == id) return;
    setState(() => _selectedOptionId = id);
    _revealConversation(showResponse: true);
  }

  void _revealConversation({required bool showResponse}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_talking || !_conversationScroll.hasClients) return;
      final position = _conversationScroll.position;
      final compact =
          MediaQuery.sizeOf(context).height < 700 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.2;
      if (!showResponse && !compact) return;
      final target = showResponse
          ? position.maxScrollExtent
          : 140.0.clamp(0.0, position.maxScrollExtent).toDouble();
      if ((position.pixels - target).abs() < 0.5) return;
      final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (still) {
        _conversationScroll.jumpTo(target);
      } else {
        unawaited(
          _conversationScroll.animateTo(
            target,
            duration: Motion.quick,
            curve: Motion.respond,
          ),
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant _WorkshopRegister oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedOptionId == oldWidget.conversation.contextual.id &&
        oldWidget.conversation.contextual.id !=
            widget.conversation.contextual.id) {
      _selectedOptionId = null;
    }
  }

  @override
  void dispose() {
    _conversationScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compact = MediaQuery.sizeOf(context).height < 700 || textScale > 1.2;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
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
                child: AnimatedSwitcher(
                  duration: still ? Duration.zero : Motion.ack,
                  switchInCurve: Motion.respond,
                  switchOutCurve: Motion.respond,
                  child: ListView(
                    controller: _talking ? _conversationScroll : null,
                    key: PageStorageKey<String>(
                      _talking
                          ? 'goal-workshop-conversation-scroll'
                          : 'goal-workshop-home-scroll',
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
                                      fontSize: 9.5,
                                      letterSpacing: 1.15,
                                      color: Palette.brassLit,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Text(
                              _talking
                                  ? 'A word at the bench.'
                                  : 'What are we working on?',
                              style: Type.display.copyWith(
                                fontSize: compact ? 19 : 28,
                                height: 1.02,
                                color: Palette.textHi,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _talking
                                  ? 'Ask what helps. Nothing here changes the route.'
                                  : "Choose a goal. We'll open the Quest you have, or shape the next move together.",
                              style: Type.body.copyWith(
                                fontSize: compact ? 10.5 : 13.5,
                                height: 1.3,
                                color: Palette.textMid,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              (_talking
                                      ? 'OPTIONAL · THE ROUTES STAY PUT'
                                      : widget.summary)
                                  .toUpperCase(),
                              key: const Key('goal-workshop-home-summary'),
                              style: Type.label.copyWith(
                                fontSize: compact ? 8 : 8.5,
                                letterSpacing: 0.72,
                                color: Palette.textLo,
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
                      if (_talking)
                        _WorkshopConversationPage(
                          key: const Key('goal-workshop-conversation'),
                          conversation: widget.conversation,
                          selectedOptionId: _selectedOptionId,
                          enabled: !widget.busy,
                          compact: compact,
                          onSelect: _selectOption,
                        )
                      else if (widget.entries.isEmpty)
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
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 7, 18, 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0x3AAB7A49))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        key: const Key('goal-workshop-talk'),
                        onPressed: widget.busy ? null : _toggleConversation,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 4 : 10,
                          ),
                          alignment: Alignment.centerLeft,
                          visualDensity: VisualDensity.compact,
                          textStyle: Type.body.copyWith(
                            fontSize: compact ? 10.5 : 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: Icon(
                          _talking
                              ? Icons.arrow_back_rounded
                              : Icons.chat_bubble_outline_rounded,
                          size: compact ? 14 : 16,
                        ),
                        label: Text(
                          _talking
                              ? compact
                                    ? 'Routes'
                                    : 'Back to routes'
                              : 'Talk shop',
                          maxLines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextButton.icon(
                        key: const Key('goal-workshop-home-new-goal'),
                        onPressed: widget.busy ? null : widget.onNewGoal,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 4 : 10,
                          ),
                          alignment: Alignment.centerRight,
                          visualDensity: VisualDensity.compact,
                          textStyle: Type.body.copyWith(
                            fontSize: compact ? 10.5 : 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: Icon(Icons.add_rounded, size: compact ? 15 : 17),
                        label: const Text('New goal', maxLines: 1),
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

class _WorkshopConversationPage extends StatelessWidget {
  const _WorkshopConversationPage({
    super.key,
    required this.conversation,
    required this.selectedOptionId,
    required this.enabled,
    required this.compact,
    required this.onSelect,
  });

  final _WorkshopConversation conversation;
  final String? selectedOptionId;
  final bool enabled;
  final bool compact;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final options = conversation.options;
    _WorkshopDialogueOption? selected;
    for (final option in options) {
      if (option.id == selectedOptionId) selected = option;
    }
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        14,
        compact ? 10 : 14,
        14,
        compact ? 26 : 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ASK ONE THING',
            style: Type.label.copyWith(
              fontSize: 8.5,
              letterSpacing: 1.05,
              color: Palette.textLo,
            ),
          ),
          SizedBox(height: compact ? 7 : 9),
          for (var index = 0; index < options.length; index++) ...[
            _WorkshopQuestion(
              option: options[index],
              selected: options[index].id == selectedOptionId,
              enabled: enabled,
              compact: compact,
              onTap: () => onSelect(options[index].id),
            ),
            if (index != options.length - 1) SizedBox(height: compact ? 6 : 8),
          ],
          SizedBox(height: compact ? 10 : 12),
          AnimatedSwitcher(
            duration: still ? Duration.zero : Motion.ack,
            switchInCurve: Motion.respond,
            switchOutCurve: Motion.respond,
            child: selected == null
                ? Text(
                    'Choose a question when you want his read. The routes are still waiting underneath.',
                    key: const Key('goal-workshop-conversation-idle'),
                    style: Type.body.copyWith(
                      fontSize: compact ? 10.5 : 12.5,
                      height: 1.28,
                      color: Palette.textLo,
                    ),
                  )
                : Semantics(
                    key: const Key('goal-workshop-conversation-response'),
                    liveRegion: true,
                    label: 'The steward says: ${selected.response}',
                    child: Container(
                      key: ValueKey<String>(
                        'goal-workshop-conversation-response-${selected.id}',
                      ),
                      padding: EdgeInsets.fromLTRB(
                        compact ? 12 : 14,
                        compact ? 10 : 12,
                        compact ? 12 : 14,
                        compact ? 11 : 13,
                      ),
                      decoration: facetedDecoration(
                        cut: 8,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xF0281D16), Color(0xF018100C)],
                        ),
                        borderColor: const Color(0x6FAE7B48),
                        borderWidth: 1,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'THE STEWARD',
                            style: Type.label.copyWith(
                              fontSize: 8,
                              letterSpacing: 1,
                              color: Palette.brassLit,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            selected.response,
                            style: TextStyle(
                              fontFamily: 'EBGaramond',
                              fontSize: compact ? 13.2 : 15.2,
                              height: 1.24,
                              fontWeight: FontWeight.w500,
                              color: Palette.textHi,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _WorkshopQuestion extends StatelessWidget {
  const _WorkshopQuestion({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.compact,
    required this.onTap,
  });

  final _WorkshopDialogueOption option;
  final bool selected;
  final bool enabled;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    key: ValueKey<String>('goal-workshop-conversation-option-${option.id}'),
    enabled: enabled,
    soundEnabled: false,
    pressDepth: 0.8,
    borderRadius: BorderRadius.circular(7),
    edgeColor: Colors.transparent,
    semanticLabel: selected
        ? 'Selected question, ${option.prompt}'
        : 'Ask the steward, ${option.prompt}',
    onTapUp: (_) => onTap(),
    child: Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 11 : 13,
        vertical: compact ? 8 : 10,
      ),
      decoration: facetedDecoration(
        cut: 7,
        color: selected ? const Color(0xD832241A) : const Color(0xA91B130F),
        borderColor: selected
            ? const Color(0xAFC58E52)
            : const Color(0x47986A3E),
        borderWidth: selected ? 1.1 : 0.8,
      ),
      child: Row(
        children: [
          Icon(
            selected ? Icons.arrow_right_rounded : Icons.add_rounded,
            size: 17,
            color: selected ? Palette.brassLit : Palette.textLo,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              option.prompt,
              style: Type.body.copyWith(
                fontSize: compact ? 11.5 : 13.2,
                height: 1.18,
                fontWeight: FontWeight.w600,
                color: selected ? Palette.textHi : Palette.textMid,
              ),
            ),
          ),
        ],
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
              fontSize: 8.5,
              letterSpacing: 0.62,
              color: accent,
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
          fontSize: 12.4,
          height: 1.22,
          color: Palette.textMid,
        ),
      ),
      if (entry.routePosition case final position?) ...[
        const SizedBox(height: 4),
        Text(
          position,
          style: Type.label.copyWith(
            fontSize: 7.8,
            letterSpacing: 0.68,
            color: Palette.textLo,
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
                fontSize: 8.2,
                letterSpacing: 0.58,
                color: accent,
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
          fontSize: 12.2,
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
          fontSize: 10.4,
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
