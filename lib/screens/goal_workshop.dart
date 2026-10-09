import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../audio.dart';
import '../clock.dart';
import '../engine.dart';
import '../goal_planner.dart';
import '../models.dart';
import '../steward_memory.dart';
import '../tokens.dart';
import '../widgets/facets.dart';
import '../widgets/goal_steward.dart';
import '../widgets/goal_world.dart';
import '../widgets/honey_button.dart';
import '../widgets/luxe_depth.dart';
import '../widgets/pressable.dart';
import '../widgets/steward_room.dart';
import 'quick_goal_composer.dart';
import 'steward_encounter.dart';
import 'steward_intake.dart';

typedef GoalWorkshopAction = Future<void> Function(Goal goal);

/// Receives a finished new-goal intake (or a request to start another way).
typedef GoalWorkshopCreate =
    Future<void> Function(QuickGoalComposerResult result);

/// Receives the plan the Steward drafted for a goal that already existed.
typedef GoalWorkshopShape = Future<void> Function(Goal goal, GoalPlan plan);

/// The Steward's workshop: where a goal becomes a plan and one first step.
///
/// The home lists every goal by what it needs from the Steward, leading with
/// the one that needs him most. The same room also hosts his questions (a new
/// goal, or a plan for a goal that has none) so the whole journey from a vague
/// goal to a first Quest happens with him. This screen owns no planning state:
/// it reads each [GoalPlan] and its exact current Quest, and hands every
/// decision back to Goals.
class GoalWorkshopScreen extends StatefulWidget {
  const GoalWorkshopScreen({
    super.key,
    required this.state,
    required this.quests,
    required this.onOpenGoal,
    required this.onShapePlan,
    required this.onCreateGoal,
    required this.onFocusGoal,
    this.onPersist,
    this.initialGoalTitle,
    this.startNewGoal = false,
    this.shapeGoal,
  });

  final GameState state;
  final List<Quest> quests;
  final GoalWorkshopAction onOpenGoal;
  final GoalWorkshopShape onShapePlan;
  final GoalWorkshopCreate onCreateGoal;
  final ValueChanged<Goal> onFocusGoal;
  final VoidCallback? onPersist;
  final String? initialGoalTitle;

  /// Opens straight into the Steward's questions for a new goal.
  final bool startNewGoal;

  /// Opens straight into the Steward's questions for this goal's plan.
  final Goal? shapeGoal;

  @override
  State<GoalWorkshopScreen> createState() => _GoalWorkshopScreenState();
}

class _IntakeTarget {
  const _IntakeTarget({this.goal, this.nextChapter = false});

  /// Null for a new goal.
  final Goal? goal;
  final bool nextChapter;
}

class _GoalWorkshopScreenState extends State<GoalWorkshopScreen> {
  late final LuxeMotionController _motion;
  final _intakeKey = GlobalKey<StewardIntakeState>();
  final _intakeExpression = ValueNotifier<GoalStewardExpression>(
    GoalStewardExpression.welcome,
  );
  _IntakeTarget? _intake;

  /// True while the questions are the first thing the screen showed, so back
  /// from the first question leaves the workshop instead of showing its home.
  late bool _intakeIsEntry;
  bool _opening = false;
  bool _stewardAssetsCached = false;

  @override
  void initState() {
    super.initState();
    _motion = LuxeMotionController(reduceMotion: widget.state.reduceMotion);
    unawaited(_motion.start());
    final shape = widget.shapeGoal;
    if (shape != null) {
      _intake = _IntakeTarget(
        goal: shape,
        nextChapter: shape.plan?.complete == true,
      );
    } else if (widget.startNewGoal) {
      _intake = const _IntakeTarget();
    }
    _intakeIsEntry = _intake != null;
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
    _intakeExpression.dispose();
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

  void _beginIntake(_IntakeTarget target) {
    if (_opening) return;
    _intakeExpression.value = GoalStewardExpression.welcome;
    setState(() => _intake = target);
  }

  Future<void> _open(_WorkshopGoalEntry entry) async {
    if (_opening) return;
    switch (entry.kind) {
      case _WorkshopGoalKind.needsPlan:
        _beginIntake(_IntakeTarget(goal: entry.goal));
        return;
      case _WorkshopGoalKind.planDone:
        _beginIntake(_IntakeTarget(goal: entry.goal, nextChapter: true));
        return;
      case _WorkshopGoalKind.stepReady:
      case _WorkshopGoalKind.onBoard:
        setState(() => _opening = true);
        try {
          await widget.onOpenGoal(entry.goal);
        } finally {
          if (mounted) setState(() => _opening = false);
        }
    }
  }

  void _newGoal() => _beginIntake(const _IntakeTarget());

  Future<void> _finishIntake(QuickGoalComposerResult result) async {
    if (_opening) return;
    final target = _intake;
    setState(() => _opening = true);
    try {
      final goal = target?.goal;
      if (result.exit == QuickGoalComposerExit.create && goal != null) {
        await widget.onShapePlan(goal, result.plan!);
      } else {
        await widget.onCreateGoal(result);
      }
    } finally {
      if (mounted) {
        setState(() {
          _opening = false;
          // Back from the first Quest lands on the home, where the goal now
          // shows what it needs next.
          if (result.exit == QuickGoalComposerExit.create) {
            _intake = null;
            _intakeIsEntry = false;
          }
        });
      }
    }
  }

  /// Back from the room: one question back, then out of the questions, then
  /// out of the workshop.
  void _back() {
    if (_opening) return;
    if (_intake != null) {
      if (_intakeKey.currentState?.stepBack() ?? false) return;
      if (!_intakeIsEntry) {
        setState(() => _intake = null);
        return;
      }
    }
    Navigator.of(context).pop();
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
                stewardMemory: widget.state.stewardMemory,
                busy: _opening,
                reduceMotion: still,
                parallax: _motion.parallax,
                light: _motion.light,
                onBack: _back,
                onOpen: _open,
                onNewGoal: _newGoal,
                onOpenEncounter: _openEncounter,
                intake: _intake == null
                    ? null
                    : StewardIntake(
                        // Each target gets its own questions and answers.
                        key: _intakeKey,
                        existingGoalTitles: [
                          for (final goal in widget.state.goals) goal.title,
                        ],
                        existingGoal: _intake!.goal,
                        nextChapter: _intake!.nextChapter,
                        expression: _intakeExpression,
                        busy: _opening,
                        onResult: _finishIntake,
                      ),
                intakeExpression: _intakeExpression,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// What a goal needs from the Steward, most in need first.
enum _WorkshopGoalKind { needsPlan, stepReady, onBoard, planDone }

class _WorkshopGoalEntry {
  const _WorkshopGoalEntry({
    required this.goal,
    required this.kind,
    required this.actionTitle,
    required this.status,
    required this.actionLabel,
    this.stepPosition,
  });

  final Goal goal;
  final _WorkshopGoalKind kind;
  final String actionTitle;
  final String status;
  final String actionLabel;
  final String? stepPosition;

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
        kind: owned ? _WorkshopGoalKind.onBoard : _WorkshopGoalKind.stepReady,
        actionTitle: decision.actionTitle,
        status: owned ? 'ON YOUR BOARD' : 'NEXT STEP READY',
        actionLabel: owned ? 'Open the Quest' : 'Take the next step',
        stepPosition: decision.routePosition,
      );
    }
    if (goal.plan == null) {
      final legacy = _legacyQuest(goal, quests, now);
      if (legacy != null) {
        return _WorkshopGoalEntry(
          goal: goal,
          kind: _WorkshopGoalKind.onBoard,
          actionTitle: legacy.displayTitle,
          status: 'ON YOUR BOARD',
          actionLabel: 'Open the Quest',
        );
      }
      return _WorkshopGoalEntry(
        goal: goal,
        kind: _WorkshopGoalKind.needsPlan,
        actionTitle:
            'No plan yet. A few questions and I will draft one, with a small first step.',
        status: 'NEEDS A PLAN',
        actionLabel: 'Shape a plan',
      );
    }
    return _WorkshopGoalEntry(
      goal: goal,
      kind: _WorkshopGoalKind.planDone,
      actionTitle: 'Every step in this plan is done.',
      status: 'PLAN COMPLETE',
      actionLabel: 'Shape what comes next',
    );
  }
}

class _WorkshopRoom extends StatelessWidget {
  const _WorkshopRoom({
    required this.entries,
    required this.stewardMemory,
    required this.busy,
    required this.reduceMotion,
    required this.parallax,
    required this.light,
    required this.onBack,
    required this.onOpen,
    required this.onNewGoal,
    required this.onOpenEncounter,
    required this.intake,
    required this.intakeExpression,
  });

  final List<_WorkshopGoalEntry> entries;
  final StewardMemory stewardMemory;
  final bool busy;
  final bool reduceMotion;
  final ValueListenable<Offset> parallax;
  final ValueListenable<Offset> light;
  final VoidCallback onBack;
  final ValueChanged<_WorkshopGoalEntry> onOpen;
  final VoidCallback onNewGoal;
  final VoidCallback onOpenEncounter;
  final Widget? intake;
  final ValueListenable<GoalStewardExpression> intakeExpression;

  GoalStewardExpression get _homeExpression {
    return resolveGoalStewardRegisterExpression(
      hasCutWaiting: entries.any(
        (entry) => entry.kind == _WorkshopGoalKind.stepReady,
      ),
      hasRouteToShape: entries.any(
        (entry) => entry.kind == _WorkshopGoalKind.needsPlan,
      ),
      hasQuestOnBoard: entries.any(
        (entry) => entry.kind == _WorkshopGoalKind.onBoard,
      ),
      hasCompletedRoute: entries.any(
        (entry) => entry.kind == _WorkshopGoalKind.planDone,
      ),
    );
  }

  /// The goal that most needs the Steward: no plan, then a next step that is
  /// ready but not on the board, then one already on the board.
  _WorkshopGoalEntry? get _lead {
    _WorkshopGoalEntry? best;
    for (final entry in entries) {
      if (best == null || entry.kind.index < best.kind.index) best = entry;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final inIntake = intake != null;
    final still =
        reduceMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final artwork = inIntake
        ? ValueListenableBuilder<GoalStewardExpression>(
            valueListenable: intakeExpression,
            builder: (context, expression, _) => GoalStewardArtwork(
              key: const Key('goal-workshop-tavern'),
              expression: expression,
              reduceMotion: still,
              parallax: parallax,
              light: light,
            ),
          )
        : GoalStewardArtwork(
            key: const Key('goal-workshop-tavern'),
            expression: _homeExpression,
            reduceMotion: still,
            parallax: parallax,
            light: light,
          );
    return PopScope<Object?>(
      // Back from a question steps back through the questions; the screen
      // decides what a back from the first one means.
      canPop: !busy && !inIntake,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) onBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF100D0B),
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            artwork,
            const DecoratedBox(
              decoration: BoxDecoration(gradient: goalsWorkshopDetailScrim),
            ),
            if (inIntake)
              _IntakeLayer(busy: busy, child: intake!)
            else
              _HomeScroll(
                entries: entries,
                lead: _lead,
                stewardMemory: stewardMemory,
                busy: busy,
                onOpen: onOpen,
                onNewGoal: onNewGoal,
                onOpenEncounter: onOpenEncounter,
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 0, 0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: _WorkshopBackButton(enabled: !busy, onTap: onBack),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Steward's questions sit on the lower counter and rise with the
/// keyboard; the room behind them stays where it is.
class _IntakeLayer extends StatelessWidget {
  const _IntakeLayer({required this.busy, required this.child});

  final bool busy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom = math.max(media.padding.bottom, media.viewInsets.bottom);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, media.padding.top + 66, 16, bottom + 12),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedOpacity(
          duration: Motion.quick,
          opacity: busy ? 0.78 : 1,
          child: child,
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
    semanticLabel: 'Back',
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

/// The whole home scrolls over the Steward: at rest his face and shoulders
/// are visible above the panel, and the panel rises over him as it scrolls.
class _HomeScroll extends StatelessWidget {
  const _HomeScroll({
    required this.entries,
    required this.lead,
    required this.stewardMemory,
    required this.busy,
    required this.onOpen,
    required this.onNewGoal,
    required this.onOpenEncounter,
  });

  final List<_WorkshopGoalEntry> entries;
  final _WorkshopGoalEntry? lead;
  final StewardMemory stewardMemory;
  final bool busy;
  final ValueChanged<_WorkshopGoalEntry> onOpen;
  final VoidCallback onNewGoal;
  final VoidCallback onOpenEncounter;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compact = media.size.height < 700 || textScale > 1.2;
    final gap = (media.size.height * (compact ? 0.28 : 0.40)).clamp(
      150.0,
      420.0,
    );
    // The back button stays put at the top left, so the panel dissolves into
    // the room as it scrolls up to meet it rather than running under it.
    final fadeFrom = media.padding.top + 2;
    final fadeTo = media.padding.top + 62;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0x00000000), Color(0xFF000000)],
        stops: [
          (fadeFrom / rect.height).clamp(0.0, 1.0),
          (fadeTo / rect.height).clamp(0.0, 1.0),
        ],
      ).createShader(rect),
      child: ListView(
        key: const PageStorageKey<String>('goal-workshop-home-scroll'),
        padding: EdgeInsets.fromLTRB(16, 0, 16, media.padding.bottom + 28),
        children: [
          SizedBox(height: gap),
          AnimatedOpacity(
            duration: Motion.quick,
            opacity: busy ? 0.78 : 1,
            child: _WorkshopHome(
              entries: entries,
              lead: lead,
              stewardMemory: stewardMemory,
              busy: busy,
              onOpen: onOpen,
              onNewGoal: onNewGoal,
              onOpenEncounter: onOpenEncounter,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkshopHome extends StatelessWidget {
  const _WorkshopHome({
    required this.entries,
    required this.lead,
    required this.stewardMemory,
    required this.busy,
    required this.onOpen,
    required this.onNewGoal,
    required this.onOpenEncounter,
  });

  final List<_WorkshopGoalEntry> entries;
  final _WorkshopGoalEntry? lead;
  final StewardMemory stewardMemory;
  final bool busy;
  final ValueChanged<_WorkshopGoalEntry> onOpen;
  final VoidCallback onNewGoal;
  final VoidCallback onOpenEncounter;

  @override
  Widget build(BuildContext context) {
    final others = [
      for (final entry in entries)
        if (!identical(entry, lead)) entry,
    ];
    final talkLabel = stewardMemory.discovered
        ? stewardMemory.nodeId != null && !stewardMemory.completed
              ? 'Continue talking'
              : 'Talk with the Steward'
        : 'Talk with the Steward';
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
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
                              'THE STEWARD\u2019S WORKSHOP',
                              style: Type.label.copyWith(
                                fontSize: 11,
                                letterSpacing: 1.15,
                                color: Palette.brassLit,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Let\u2019s work on a goal',
                        key: const Key('goal-workshop-home-title'),
                        style: Type.display.copyWith(
                          fontSize: 27,
                          height: 1.04,
                          color: Palette.textHi,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'I turn a goal into a short plan and one small first step. Nothing goes on your Quest board until you take it.',
                        key: const Key('goal-workshop-home-intro'),
                        style: Type.body.copyWith(
                          fontSize: 14,
                          height: 1.35,
                          color: Palette.textMid,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (lead case final entry?)
                  _WorkshopLeadCard(
                    entry: entry,
                    enabled: !busy,
                    onTap: () => onOpen(entry),
                  )
                else
                  _WorkshopFirstGoalCard(enabled: !busy, onTap: onNewGoal),
                if (others.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Text(
                      'YOUR OTHER GOALS',
                      key: const Key('goal-workshop-home-others'),
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        letterSpacing: 1.0,
                        color: Palette.textMid,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (var index = 0; index < others.length; index++) ...[
                    _WorkshopGoalRow(
                      entry: others[index],
                      enabled: !busy,
                      onTap: () => onOpen(others[index]),
                    ),
                    if (index != others.length - 1)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        indent: 10,
                        endIndent: 10,
                        color: Color(0x31986A3E),
                      ),
                  ],
                ],
                const SizedBox(height: 16),
                if (entries.isNotEmpty) ...[
                  HoneyButton(
                    key: const Key('goal-workshop-home-new-goal'),
                    label: 'New goal',
                    icon: Icons.add_rounded,
                    quiet: true,
                    expand: true,
                    enabled: !busy,
                    onTap: onNewGoal,
                  ),
                  const SizedBox(height: 6),
                ],
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: HoneyButton(
                      key: stewardMemory.discovered
                          ? const Key('goal-workshop-talk')
                          : const Key('steward-hidden-card'),
                      label: talkLabel,
                      icon: Icons.forum_outlined,
                      quiet: true,
                      tint: Palette.textMid,
                      enabled: !busy,
                      onTap: onOpenEncounter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A short, tinted word for what a goal needs next.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.entry});

  final _WorkshopGoalEntry entry;

  @override
  Widget build(BuildContext context) {
    final attention =
        entry.kind == _WorkshopGoalKind.needsPlan ||
        entry.kind == _WorkshopGoalKind.stepReady;
    final color = attention ? Palette.xpLight : Palette.textMid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: facetedDecoration(
        cut: 4,
        color: color.withValues(alpha: attention ? 0.10 : 0.05),
        borderColor: color.withValues(alpha: attention ? 0.55 : 0.28),
      ),
      child: Text(
        entry.status,
        style: Type.label.copyWith(
          fontSize: Type.minLabel,
          letterSpacing: 0.7,
          color: color,
        ),
      ),
    );
  }
}

/// The one goal that most needs the Steward, with the one thing to do about it.
class _WorkshopLeadCard extends StatelessWidget {
  const _WorkshopLeadCard({
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
    return Container(
      key: const Key('goal-workshop-lead'),
      decoration: facetedDecoration(
        cut: 10,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.10),
            const Color(0x1CF3DEC0),
            const Color(0x0DF3DEC0),
          ],
          stops: const [0, 0.35, 1],
        ),
        borderColor: accent.withValues(alpha: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StatusChip(entry: entry),
                if (entry.stepPosition case final position?)
                  Text(
                    position,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      letterSpacing: 0.8,
                      color: Palette.textMid,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              entry.goal.title,
              key: const Key('goal-workshop-lead-title'),
              style: Type.display.copyWith(
                fontSize: 25,
                height: 1.06,
                color: Palette.textHi,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              entry.actionTitle,
              style: Type.body.copyWith(
                fontSize: 14.5,
                height: 1.35,
                color: Palette.textMid,
              ),
            ),
            const SizedBox(height: 15),
            HoneyButton(
              key: ValueKey<String>(
                'goal-workshop-home-goal-${entry.goal.title}',
              ),
              label: entry.actionLabel,
              icon: Icons.arrow_forward_rounded,
              expand: true,
              glow: false,
              enabled: enabled,
              semanticLabel: '${entry.actionLabel}: ${entry.goal.title}',
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// No goals yet: the Steward offers to start the first one.
class _WorkshopFirstGoalCard extends StatelessWidget {
  const _WorkshopFirstGoalCard({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('goal-workshop-lead'),
    decoration: facetedDecoration(
      cut: 10,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x1CF3DEC0), Color(0x0DF3DEC0)],
      ),
      borderColor: Palette.brass.withValues(alpha: 0.5),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Start your first goal',
            style: Type.display.copyWith(
              fontSize: 25,
              height: 1.06,
              color: Palette.textHi,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Tell me what you want to change. I will ask a few questions, one at a time, and hand you one small first step.',
            style: Type.body.copyWith(
              fontSize: 14.5,
              height: 1.35,
              color: Palette.textMid,
            ),
          ),
          const SizedBox(height: 15),
          HoneyButton(
            key: const Key('goal-workshop-home-new-goal'),
            label: 'Start a goal',
            icon: Icons.arrow_forward_rounded,
            expand: true,
            glow: false,
            enabled: enabled,
            onTap: onTap,
          ),
        ],
      ),
    ),
  );
}

class _WorkshopGoalRow extends StatelessWidget {
  const _WorkshopGoalRow({
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
    final semantic =
        '${entry.goal.title}. ${entry.status}. ${entry.actionTitle}. ${entry.actionLabel}.';
    return Pressable(
      key: ValueKey<String>('goal-workshop-home-goal-${entry.goal.title}'),
      enabled: enabled,
      pressDepth: 1,
      material: MaterialSound.parchment,
      interactionSound: InteractionSound.open,
      guardRapidReentry: true,
      borderRadius: BorderRadius.circular(7),
      edgeColor: Colors.transparent,
      semanticLabel: semantic,
      semanticHint: entry.actionLabel,
      onTapUp: (_) => onTap(),
      stateBuilder: (context, child, pressed, focused, hovered) =>
          AnimatedContainer(
            duration: pressed ? Duration.zero : Motion.ack,
            constraints: const BoxConstraints(minHeight: 56),
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
        padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.goal.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Type.body.copyWith(
                        fontSize: 15,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        color: Palette.textHi,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatusChip(entry: entry),
                        if (entry.stepPosition case final position?)
                          Text(
                            position,
                            style: Type.label.copyWith(
                              fontSize: Type.minLabel,
                              letterSpacing: 0.7,
                              color: Palette.textLo,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      entry.actionTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Type.body.copyWith(
                        fontSize: 13,
                        height: 1.25,
                        color: Palette.textMid,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: accent.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
