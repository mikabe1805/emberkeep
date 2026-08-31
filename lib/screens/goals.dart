import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../clock.dart';
import '../content/day_planning.dart';
import '../content/goal_catalog.dart';
import '../content/momentum_kits.dart';
import '../content/routines.dart';
import '../engine.dart';
import '../goal_planner.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/day_picker.dart';
import '../widgets/detail_route.dart';
import '../widgets/ember_sheet.dart';
import '../widgets/rung_picker.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/goal_primary_button.dart';
import '../widgets/goal_room_route.dart';
import '../widgets/goal_threshold_scene.dart';
import '../widgets/goal_world.dart';
import '../widgets/luxe_depth.dart';
import '../widgets/pressable.dart';
import '../widgets/top_three_wizard.dart';
import 'goal_detail.dart';
import 'goal_opening.dart';
import 'goal_plan_check_in.dart';
import 'goal_workshop.dart';
import 'goal_wizard.dart';
import 'momentum_kits.dart';
import 'quick_goal_composer.dart';

/// A catalog section (round-16) — light grouping so the longer "adopt a path"
/// list stays scannable. Order *and* membership live here in one declarative
/// table; the screen walks it and renders a [_CategoryHeader] before each
/// non-empty group. Not const (stat colors aren't const), but build-time fixed.
class _GoalCategory {
  const _GoalCategory({
    required this.label,
    required this.blurb,
    required this.icon,
    required this.accent,
    required this.goalTitles,
  });

  final String label;
  final String blurb;
  final IconData icon;
  final Color accent;
  final List<String> goalTitles;
}

final _goalCategories = <_GoalCategory>[
  _GoalCategory(
    label: 'HOME & HEARTH',
    blurb: 'the rooms and rhythms you live inside',
    icon: Icons.cottage_outlined,
    accent: Palette.xpLight,
    goalTitles: const ['Keep your space', 'Routine keeper', 'Tend your money'],
  ),
  _GoalCategory(
    label: 'LIVING THINGS',
    blurb: 'the ones who depend on you — green or breathing',
    icon: Icons.pets_outlined,
    accent: Stat.vit.color,
    goalTitles: const [
      'Tend your plants',
      'Tend your creatures',
      'Feed yourself well',
    ],
  ),
  _GoalCategory(
    label: 'BODY & REST',
    blurb: 'move it, fuel it, let it rest',
    icon: Icons.favorite_outline,
    accent: Stat.str.color,
    goalTitles: const [
      'Move through the world',
      'The strength path',
      'Wind down well',
    ],
  ),
  _GoalCategory(
    label: 'MIND & FOCUS',
    blurb: 'attention and the turning page',
    icon: Icons.auto_stories_outlined,
    accent: Stat.foc.color,
    goalTitles: const ['Become a reader', 'Deep focus', 'Keep a journal'],
  ),
  _GoalCategory(
    label: 'PEOPLE',
    blurb: 'the ones you reach for',
    icon: Icons.groups_outlined,
    accent: Stat.soc.color,
    goalTitles: const ['Reach out'],
  ),
];

String _questTitleKey(String title) => title.trim().toLowerCase();

const _goalsRoomTextShadows = <Shadow>[
  Shadow(color: Color(0xD8100906), blurRadius: 10, offset: Offset(0, 2)),
  Shadow(color: Color(0x86100906), blurRadius: 3, offset: Offset(0, 1)),
];

List<Quest> _questsForGoal(Goal goal, List<Quest> quests) => quests
    .where(
      (quest) =>
          quest.goalTitle != null &&
          _questTitleKey(quest.goalTitle!) == _questTitleKey(goal.title),
    )
    .toList(growable: false);

Quest? _nextQuestToday(Goal goal, List<Quest> quests) {
  final now = Clock.now();
  final todayKey = Days.key(now);
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
  final candidates =
      _questsForGoal(goal, quests)
          .where(
            (quest) =>
                quest.snoozedDay != todayKey &&
                !quest.doneFor(now) &&
                !quest.allDay &&
                (quest.isEvent
                    ? !quest.dueDate!.isAfter(endOfToday)
                    : quest.scheduledOn(now)),
          )
          .toList(growable: false)
        ..sort((a, b) {
          final priority = a
              .priorityRankOn(now)
              .compareTo(b.priorityRankOn(now));
          if (priority != 0) return priority;
          return a.difficulty.compareTo(b.difficulty);
        });
  return candidates.isEmpty ? null : candidates.first;
}

String _goalProgressCopy(Goal goal) {
  if (goal.complete) return 'Completed';
  if (goal.kind == GoalKind.achieve) {
    return '${goal.progress} of ${goal.target} actions';
  }
  final remaining = (goal.target - goal.progress).clamp(0, goal.target);
  if (goal.milestones == 0) {
    return '${goal.progress} actions kept · $remaining to the first milestone';
  }
  return '${goal.progress} actions kept · $remaining to the next milestone';
}

/// A conservative first move used only when a person deliberately leaves the
/// quick composer's action blank. Specific title cues win; the domain fallback
/// is intentionally small, editable, and revealed before it becomes a Quest.
String _preparedFirstAction(String title, Stat stat) {
  final value = title.trim().toLowerCase();
  bool mentions(Iterable<String> words) => words.any(value.contains);

  if (mentions(const ['apartment', 'room', 'home', 'tidy', 'clean'])) {
    return 'Clear one hand-sized surface';
  }
  if (mentions(const ['read', 'book', 'novel'])) return 'Read one page';
  if (mentions(const ['study', 'learn', 'class', 'exam'])) {
    return 'Open the material for ten minutes';
  }
  if (mentions(const ['journal', 'write', 'draft'])) {
    return 'Write one honest line';
  }
  if (mentions(const ['walk', 'run', 'move', 'exercise', 'workout'])) {
    return 'Put on your shoes and step outside';
  }
  if (mentions(const ['sleep', 'rest', 'wind down'])) {
    return 'Choose a time to begin winding down';
  }
  if (mentions(const ['friend', 'family', 'call', 'connect', 'reach out'])) {
    return 'Send one honest message';
  }
  if (mentions(const ['money', 'save', 'budget', 'spend'])) {
    return 'Look at the last seven days of spending';
  }
  if (mentions(const ['cook', 'meal', 'eat', 'food'])) {
    return 'Prepare one thing for your next meal';
  }

  return switch (stat) {
    Stat.str => 'Set out what you need for one easy start',
    Stat.vit => 'Prepare one thing that makes this easier',
    Stat.intl => 'Open it for ten focused minutes',
    Stat.foc => 'Put one tool where you can reach it',
    Stat.soc => 'Send one honest message',
    Stat.dis => 'Clear one hand-sized surface',
  };
}

String _preparedLighterAction(Stat stat, String firstAction) {
  final candidate = switch (stat) {
    Stat.str => 'set out what you need',
    Stat.vit => 'prepare one piece of it',
    Stat.intl => 'open it for two minutes',
    Stat.foc => 'touch one visible part of the work',
    Stat.soc => 'draft the first sentence',
    Stat.dis => 'clear one hand-sized surface',
  };
  if (_questTitleKey(candidate) != _questTitleKey(firstAction)) {
    return candidate;
  }
  return stat == Stat.dis
      ? 'put away one visible thing'
      : 'do the smallest visible part';
}

/// "Take on quests!" — goal discovery. Every routine quest belongs to a
/// goal (the why stays attached, round-7): begin your own via the Oath
/// Wizard, or adopt a curated goal whole. One-time plans live on the
/// calendar.
class GoalsPage extends StatefulWidget {
  const GoalsPage({
    super.key,
    required this.state,
    required this.onAdd,
    required this.onRemoveQuest,
    required this.onRemoveGoal,
    required this.onPersist,
    required this.quests,
    required this.onOpenQuest,
    this.onOpenQuests,
    this.onOpenGuidedWorkouts,
    this.onOpenWorkout,
    this.openingRequestTitle,
    this.onOpeningRequestHandled,
    this.parallax = const AlwaysStoppedAnimation(Offset.zero),
    this.lightDirection,
  });

  final GameState state;

  /// Returns false when a same-titled quest is already on the list.
  final bool Function(Quest quest) onAdd;

  /// Takes one live quest back off the board without removing its goal.
  final void Function(Quest quest) onRemoveQuest;

  /// Abandons a goal and clears its linked quests.
  final void Function(Goal goal) onRemoveGoal;

  /// Persists the save — used when a goal's journal changes in the detail view.
  final VoidCallback onPersist;

  /// The live board quests — threaded to the goal-detail view (quests serving it).
  final List<Quest> quests;

  /// Leaves this discovery tab and opens the shared board after a kit is lit.
  final VoidCallback? onOpenQuests;

  /// Opens the canonical seven-session picker owned by the Quests page.
  /// Optional only for independently rendered previews/tests; the app shell
  /// always supplies it.
  final VoidCallback? onOpenGuidedWorkouts;

  /// Leaves Goals and makes this exact action the first Quest on the board.
  final void Function(Quest quest) onOpenQuest;
  final void Function(Quest quest)? onOpenWorkout;
  final String? openingRequestTitle;
  final VoidCallback? onOpeningRequestHandled;
  final ValueListenable<Offset> parallax;
  final ValueListenable<Offset>? lightDirection;

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  String? _selectedGoalTitle;
  String? _arrivingGoalTitle;
  String? _handledOpeningRequestTitle;
  bool _roomAssetsPrepared = false;

  GameState get state => widget.state;
  bool Function(Quest quest) get onAdd => widget.onAdd;
  void Function(Quest quest) get onRemoveQuest => widget.onRemoveQuest;
  void Function(Goal goal) get onRemoveGoal => widget.onRemoveGoal;
  VoidCallback get onPersist => widget.onPersist;
  List<Quest> get quests => widget.quests;
  void Function(Quest quest) get onOpenQuest => widget.onOpenQuest;
  ValueListenable<Offset> get parallax => widget.parallax;
  ValueListenable<Offset>? get lightDirection => widget.lightDirection;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_roomAssetsPrepared) return;
    _roomAssetsPrepared = true;
    precacheImage(const AssetImage(goalsRoomContinuousAsset), context);
    precacheImage(const AssetImage(goalsRoomKitchenAsset), context);
    precacheGoalStewardAssets(context);
    precacheImage(const AssetImage(goalsThresholdPlateAsset), context);
    _scheduleRequestedOpening();
  }

  @override
  void didUpdateWidget(covariant GoalsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openingRequestTitle != widget.openingRequestTitle) {
      _scheduleRequestedOpening();
    }
  }

  void _scheduleRequestedOpening() {
    final title = widget.openingRequestTitle?.trim();
    if (title == null ||
        title.isEmpty ||
        title == _handledOpeningRequestTitle) {
      return;
    }
    _handledOpeningRequestTitle = title;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      Goal? goal;
      for (final candidate in state.goals) {
        if (_questTitleKey(candidate.title) == _questTitleKey(title)) {
          goal = candidate;
          break;
        }
      }
      if (goal == null || goal.openingSeen) {
        widget.onOpeningRequestHandled?.call();
        return;
      }
      final requestedGoal = goal;
      setState(() {
        _selectedGoalTitle = requestedGoal.title;
        _arrivingGoalTitle = requestedGoal.title;
      });
      await _openGoalOpening(context, requestedGoal);
      if (mounted) widget.onOpeningRequestHandled?.call();
    });
  }

  Future<void> _openWorkshop(BuildContext context, Goal initialGoal) async {
    _arrivingGoalTitle = null;
    await Navigator.of(context).push<void>(
      goalRoomRoute<void>(
        context: context,
        reduceMotion: state.reduceMotion,
        settings: const RouteSettings(name: '/goals/workshop'),
        builder: (workshopContext) => GoalWorkshopScreen(
          state: state,
          quests: quests,
          initialGoalTitle: initialGoal.title,
          onOpenGoal: (goal) => _openGoalOpening(
            this.context,
            goal,
            startInWorkshop: true,
            onBeforeQuestHandoff: () {
              if (Navigator.of(workshopContext).canPop()) {
                Navigator.of(workshopContext).pop();
              }
            },
          ),
          onBuildRoute: (goal) async {
            Navigator.of(workshopContext).pop();
            await Future<void>.delayed(
              Duration(milliseconds: state.reduceMotion ? 0 : 180),
            );
            if (!mounted) return;
            await _buildGoalPlan(this.context, goal);
          },
          onFocusGoal: (goal) {
            if (!mounted) return;
            setState(() => _selectedGoalTitle = goal.title);
          },
          onNewGoal: () async {
            Navigator.of(workshopContext).pop();
            await Future<void>.delayed(
              Duration(milliseconds: state.reduceMotion ? 0 : 180),
            );
            if (!mounted) return;
            await _openQuickCreate(this.context);
          },
          onPersist: widget.onPersist,
        ),
      ),
    );
  }

  /// Goals owns the decision to give an ordinary day a smaller, intentional
  /// field. Quests still owns the board and completion; this only saves the
  /// existing date-scoped priority markers that tell the board what leads.
  Future<void> _chooseToday(BuildContext context) async {
    final today = Clock.now();
    final candidates = planningQuestsForDay(
      quests,
      today,
    ).where((quest) => !quest.allDay && !quest.isEvent).toList(growable: false);
    if (candidates.isEmpty) return;

    final chosen = await showTopThreeWizard(
      context,
      title: 'Choose today',
      subtitle:
          'Pick up to three quests to carry. Everything else stays open if the day has more in it.',
      dayLabel: 'Today’s field',
      candidates: candidates,
      initialTitles: selectedDailyFieldForDay(
        quests,
        today,
      ).map((quest) => quest.title),
      accent: Palette.xpLight,
      confirmLabel: 'KEEP TODAY’S FIELD',
    );
    if (chosen == null || !mounted) return;

    applyDailyField(quests, today, chosen);
    onPersist();
    setState(() {});
  }

  Future<void> _openWizard(BuildContext context) async {
    final goal = await Navigator.of(context).push<Goal>(
      detailRoute<Goal>(
        context: context,
        reduceMotion: state.reduceMotion,
        builder: (_) => GoalWizardScreen(state: state),
      ),
    );
    if (!mounted || goal == null) return;
    onPersist();
    setState(() {
      _selectedGoalTitle = goal.title;
      _arrivingGoalTitle = goal.title;
    });
    await _openGoalOpening(this.context, goal);
  }

  Future<void> _openGoalOpening(
    BuildContext context,
    Goal goal, {
    Quest? preferredQuest,
    bool startInWorkshop = false,
    VoidCallback? onBeforeQuestHandoff,
  }) async {
    final routeDecision = GoalPlanner.decide(goal, quests, Clock.now());
    Quest? quest;
    var preparedByApp = false;
    var questOwned = false;
    if (routeDecision != null) {
      // A structured route owns its exact current marker. Do not let an
      // unrelated due or linked Quest become the workshop's offered cut.
      quest = routeDecision.quest;
      questOwned = quest != null;
      if (quest == null) {
        quest = GoalPlanner.questFor(goal, routeDecision, Clock.now());
        preparedByApp = true;
      }
    } else {
      quest = preferredQuest ?? _nextQuestToday(goal, quests);
      questOwned = quest != null && quests.contains(quest);
      preparedByApp = preferredQuest?.goalPlanStepId != null;
    }
    if (quest == null && goal.plan == null) {
      for (final linked in _questsForGoal(goal, quests)) {
        if (!linked.doneFor(Clock.now())) {
          quest = linked;
          questOwned = true;
          break;
        }
      }
    }

    if (quest == null) {
      preparedByApp = true;
      var title = _preparedFirstAction(goal.title, goal.stat);
      if (quests.any(
        (item) => _questTitleKey(item.title) == _questTitleKey(title),
      )) {
        title = 'Spend five minutes on ${goal.title}';
      }
      quest = Quest(
        title: title,
        stat: goal.stat,
        difficulty: 1,
        schedule: QuestSchedule.once,
        custom: true,
        goalTitle: goal.title,
      );
    }

    final hadFallbackCue = goal.fallbackCue != null;
    final hadFallbackAction = goal.fallbackAction != null;
    goal.fallbackCue ??= 'this feels like too much today';
    goal.fallbackAction ??= _preparedLighterAction(
      goal.stat,
      quest.displayTitle,
    );
    // The prepared support is part of the resumable opening, so keep it even
    // when the person leaves before accepting the first Quest.
    if (!hadFallbackCue || !hadFallbackAction) onPersist();

    final openingQuest = quest;
    var accepting = false;
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: '/goals/opening'),
        transitionDuration: Duration(
          milliseconds: state.reduceMotion ? 180 : 520,
        ),
        reverseTransitionDuration: Duration(
          milliseconds: state.reduceMotion ? 150 : 380,
        ),
        pageBuilder: (openingContext, animation, secondaryAnimation) =>
            GoalOpeningScreen(
              goal: goal,
              actionTitle: openingQuest.displayTitle,
              fallbackAction: goal.fallbackAction,
              preparedByApp: preparedByApp,
              questOwned: questOwned,
              reduceMotion: state.reduceMotion,
              onBegin: () {
                if (accepting) return;
                accepting = true;
                final currentDecision = GoalPlanner.decide(
                  goal,
                  quests,
                  Clock.now(),
                );
                final acceptedQuest = currentDecision == null
                    ? openingQuest
                    : currentDecision.quest ??
                          GoalPlanner.questFor(
                            goal,
                            currentDecision,
                            Clock.now(),
                          );
                if (!quests.contains(acceptedQuest) && !onAdd(acceptedQuest)) {
                  accepting = false;
                  ScaffoldMessenger.of(openingContext).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Palette.card,
                      content: Text(
                        'That first move is already on your Quest board',
                        style: Type.body.copyWith(color: Palette.textHi),
                      ),
                    ),
                  );
                  return;
                }
                state.completeGoalOpening(goal);
                onPersist();
                Navigator.of(openingContext).pop();
                onBeforeQuestHandoff?.call();
                onOpenQuest(acceptedQuest);
              },
              onEditAction: goal.plan == null
                  ? null
                  : (actionTitle) =>
                        _replaceOpeningRouteAction(goal, actionTitle),
              onMakeSmaller: goal.plan == null
                  ? null
                  : () => _makeOpeningRouteActionSmaller(goal),
              onReworkRoute: goal.plan == null
                  ? null
                  : () {
                      Navigator.of(openingContext).pop();
                      Future<void>.delayed(
                        Duration(milliseconds: state.reduceMotion ? 0 : 220),
                        () {
                          if (!mounted) return;
                          _adjustGoalPlan(
                            this.context,
                            goal,
                            onBeforeQuestHandoff: onBeforeQuestHandoff,
                          );
                        },
                      );
                    },
              onReturn: () => Navigator.of(openingContext).pop(),
              startInWorkshop: startInWorkshop,
              onChooseAnother: goal.plan == null && preparedByApp
                  ? () {
                      Navigator.of(openingContext).pop();
                      Future<void>.delayed(
                        Duration(milliseconds: state.reduceMotion ? 0 : 320),
                        () {
                          if (!mounted) return;
                          _addAction(
                            this.context,
                            goal,
                            defaultTitle: openingQuest.displayTitle,
                          );
                        },
                      );
                    }
                  : null,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (state.reduceMotion) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
              child: child,
            );
          }
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final raw = animation.value.clamp(0.0, 1.0);
              final fade = Curves.easeOutCubic.transform(
                ((raw - 0.02) / 0.86).clamp(0.0, 1.0),
              );
              final exposure = raw <= 0.44
                  ? (raw / 0.44)
                  : (1 - ((raw - 0.44) / 0.56));
              return Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(opacity: fade, child: child),
                  IgnorePointer(
                    child: Opacity(
                      opacity: exposure.clamp(0.0, 1.0) * 0.11,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(0.30, -0.20),
                            radius: 0.82,
                            colors: [
                              Color(0xFFFFDDA0),
                              Color(0x35D99645),
                              Color(0x00D99645),
                            ],
                            stops: [0, 0.42, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _discardUnfinishedOpeningRevision(Goal goal, int? revision) {
    if (revision == null) return;
    quests.removeWhere(
      (quest) =>
          _questTitleKey(quest.goalTitle ?? '') == _questTitleKey(goal.title) &&
          quest.goalPlanRevision == revision &&
          quest.goalPlanStepId != null &&
          !quest.doneFor(Clock.now()),
    );
  }

  Future<bool> _replaceOpeningRouteAction(Goal goal, String actionTitle) async {
    final clean = actionTitle.trim();
    if (clean.isEmpty || goal.plan?.currentStep == null) return false;
    final oldRevision = goal.plan?.revision;
    final revised = GoalPlanner.replaceCurrentAction(
      goal: goal,
      actionTitle: clean,
      now: Clock.now(),
    );
    _discardUnfinishedOpeningRevision(goal, oldRevision);
    state.updateGoalPlan(goal, revised);
    onPersist();
    return true;
  }

  Future<String?> _makeOpeningRouteActionSmaller(Goal goal) async {
    final plan = goal.plan;
    final current = plan?.currentStep;
    if (plan == null || current == null) return null;
    if (_questTitleKey(current.actionTitle) ==
        _questTitleKey(plan.fallbackAction)) {
      return current.actionTitle;
    }
    final revised = GoalPlanner.recalibrate(
      goal,
      GoalPlanSignal.tooBig,
      Clock.now(),
    );
    _discardUnfinishedOpeningRevision(goal, plan.revision);
    state.updateGoalPlan(goal, revised);
    onPersist();
    return revised.currentStep?.actionTitle;
  }

  Future<void> _openQuickCreate(BuildContext context) async {
    final result = await showQuickGoalComposer(
      context,
      existingGoalTitles: state.goals.map((goal) => goal.title),
      existingQuestTitles: quests.map((quest) => quest.title),
    );
    if (!context.mounted || result == null) return;
    switch (result.exit) {
      case QuickGoalComposerExit.advanced:
        await _openWizard(context);
        return;
      case QuickGoalComposerExit.browse:
        _openStartingPoints(context);
        return;
      case QuickGoalComposerExit.create:
        final title = result.title!;
        final stat = result.stat!;
        final plan = result.plan!;
        final goal = Goal(
          title: title,
          stat: stat,
          kind: plan.type == GoalRouteType.routine
              ? GoalKind.become
              : GoalKind.achieve,
          target: plan.type == GoalRouteType.routine
              ? 25
              : plan.steps.fold(
                  0,
                  (total, step) => total + step.requiredCompletions,
                ),
          openingSeen: false,
          plan: plan,
          fallbackCue: plan.obstacleCue,
          fallbackAction: plan.fallbackAction,
        );
        if (!state.addGoal(goal)) return;
        setState(() {
          _selectedGoalTitle = title;
          _arrivingGoalTitle = title;
        });
        // The route belongs to the Goal immediately. The first Quest does not
        // belong to the board until the person explicitly takes it in the
        // workshop at the end of the spatial opening.
        onPersist();
        Sfx.instance.playAfterContact('levelup');
        HapticFeedback.mediumImpact();
        if (!context.mounted) return;
        await _openGoalOpening(context, goal);
        return;
    }
  }

  void _openStartingPoints(BuildContext context) {
    Navigator.of(context).push(
      detailRoute<void>(
        context: context,
        reduceMotion: state.reduceMotion,
        builder: (_) =>
            _ReadyMadeGoalsScreen(state: state, buildCatalog: _catalogSections),
      ),
    );
  }

  Future<void> _addAction(
    BuildContext context,
    Goal goal, {
    String? defaultTitle,
  }) async {
    _arrivingGoalTitle = null;
    Sfx.instance.playMaterial(MaterialSound.glass);
    final quest = await showEmberSheet(
      context,
      EmberSheetConfig(
        surface: EmberSurface.goal,
        defaultTitle: defaultTitle,
        defaultStat: goal.stat,
        lockStat: true,
        goalTitle: goal.title,
        accent: goal.stat.color,
      ),
    );
    if (quest == null || !context.mounted) return;
    final added = onAdd(quest);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.card,
        content: Text(
          added
              ? '“${quest.displayTitle}” now moves “${goal.title}”'
              : 'That action is already on your Quest board',
          style: Type.body.copyWith(color: Palette.textHi),
        ),
      ),
    );
  }

  bool _canReuseFallback(Quest quest, DateTime now) {
    if (quest.doneFor(now) || quest.allDay) return false;
    if (quest.isEvent) {
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
      return !quest.dueDate!.isAfter(endOfToday);
    }
    return quest.scheduledOn(now);
  }

  Quest? _prepareGoalFallback(
    BuildContext context,
    Goal goal,
    String fallback,
  ) {
    _arrivingGoalTitle = null;
    final now = Clock.now();
    final todayKey = Days.key(now);
    final fallbackKey = _questTitleKey(fallback);

    Quest? reusable;
    for (final quest in _questsForGoal(goal, quests)) {
      if (_questTitleKey(quest.title) == fallbackKey &&
          _canReuseFallback(quest, now)) {
        reusable = quest;
        break;
      }
    }
    if (reusable != null) {
      if (reusable.snoozedDay == todayKey) {
        reusable.snoozedDay = null;
        onPersist();
      }
      return reusable;
    }

    var title = fallback;
    final usedTitles = quests
        .map((quest) => _questTitleKey(quest.title))
        .toSet();
    if (usedTitles.contains(_questTitleKey(title))) {
      final anchored = '$fallback · ${goal.title}';
      title = anchored;
      var copy = 2;
      while (usedTitles.contains(_questTitleKey(title))) {
        title = '$anchored · $copy';
        copy++;
      }
    }
    final day = DateTime(now.year, now.month, now.day);
    final created = Quest(
      title: title,
      stat: goal.stat,
      difficulty: 1,
      schedule: QuestSchedule.once,
      dueDate: day,
      custom: true,
      goalTitle: goal.title,
    );
    if (onAdd(created)) {
      Sfx.instance.playAfterContact('streak');
      HapticFeedback.mediumImpact();
      return created;
    }

    // A rapid second activation can lose the title race after the first add.
    // Reuse the accepted live object if it is now present; never forge a
    // duplicate or send the person back into a planning form.
    for (final quest in _questsForGoal(goal, quests)) {
      if (_questTitleKey(quest.title) == _questTitleKey(title) &&
          _canReuseFallback(quest, now)) {
        if (quest.snoozedDay == todayKey) {
          quest.snoozedDay = null;
          onPersist();
        }
        return quest;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.card,
        content: Text(
          'That lighter move is already on your Quest board',
          style: Type.body.copyWith(color: Palette.textHi),
        ),
      ),
    );
    return null;
  }

  Goal? _focusGoal(List<Goal> activeGoals) {
    if (activeGoals.isEmpty) return null;
    bool hasNextMove(Goal goal) =>
        GoalPlanner.decide(goal, quests, Clock.now()) != null ||
        _nextQuestToday(goal, quests) != null;
    final selected = _selectedGoalTitle;
    if (selected != null) {
      for (final goal in activeGoals) {
        if (_questTitleKey(goal.title) == _questTitleKey(selected)) return goal;
      }
    }
    for (final title in state.featuredGoalTitles) {
      for (final goal in activeGoals) {
        if (goal.title == title && hasNextMove(goal)) {
          return goal;
        }
      }
    }
    for (final goal in activeGoals) {
      if (hasNextMove(goal)) return goal;
    }
    for (final title in state.featuredGoalTitles) {
      for (final goal in activeGoals) {
        if (goal.title == title) return goal;
      }
    }
    return activeGoals.first;
  }

  void _selectGoal(Goal goal) {
    if (_questTitleKey(goal.title) ==
        _questTitleKey(_selectedGoalTitle ?? '')) {
      return;
    }
    Sfx.instance.playMaterial(MaterialSound.parchment);
    HapticFeedback.selectionClick();
    setState(() {
      _selectedGoalTitle = goal.title;
      _arrivingGoalTitle = null;
    });
  }

  void _openGuidedWorkout() {
    Quest? launcher;
    for (final quest in quests) {
      if (quest.workout) {
        launcher = quest;
        break;
      }
    }
    launcher ??= workoutLauncherQuest();
    if (!quests.contains(launcher) && !onAdd(launcher)) return;
    final openWorkout = widget.onOpenWorkout;
    if (openWorkout != null) {
      openWorkout(launcher);
    } else {
      onOpenQuest(launcher);
    }
  }

  void _openUnstick(BuildContext context, Goal? goal) {
    _arrivingGoalTitle = null;
    showMomentumKitLauncher(
      context,
      kind: MomentumKitKind.unstick,
      state: state,
      onAdd: onAdd,
      onPersist: onPersist,
      onOpenQuests: widget.onOpenQuests ?? () {},
      goalContext: goal,
      onOpenQuest: onOpenQuest,
    );
  }

  Future<void> _adjustGoalPlan(
    BuildContext context,
    Goal goal, {
    VoidCallback? onBeforeQuestHandoff,
  }) async {
    if (goal.plan == null) return;
    final signal = await showGoalPlanCheckIn(context, goal: goal);
    if (!mounted || signal == null) return;
    GoalPlan revised;
    if (signal == GoalPlanSignal.changed) {
      final changed = await showGoalOutcomeEditor(this.context, goal: goal);
      if (!mounted || changed == null) return;
      revised = GoalPlanner.replaceOutcome(
        goal: goal,
        outcome: changed.$1,
        successProof: changed.$2,
        now: Clock.now(),
      );
    } else {
      revised = GoalPlanner.recalibrate(goal, signal, Clock.now());
    }
    final oldRevision = goal.plan!.revision;
    quests.removeWhere(
      (quest) =>
          _questTitleKey(quest.goalTitle ?? '') == _questTitleKey(goal.title) &&
          quest.goalPlanStepId != null &&
          quest.goalPlanRevision == oldRevision &&
          !quest.doneFor(Clock.now()),
    );
    state.updateGoalPlan(goal, revised);
    onPersist();
    if (!mounted) return;
    setState(() {
      _selectedGoalTitle = goal.title;
      _arrivingGoalTitle = null;
    });
    await _openGoalOpening(
      this.context,
      goal,
      startInWorkshop: true,
      onBeforeQuestHandoff: onBeforeQuestHandoff,
    );
  }

  Future<void> _recoverGoalToday(BuildContext context, Goal goal) async {
    if (goal.plan == null) return;
    final choice = await showGoalTodayRecovery(context, goal: goal);
    if (!mounted || choice == null) return;

    switch (choice) {
      case GoalTodayRecoveryChoice.leaveTodayAlone:
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Palette.card,
            content: Text(
              'Nothing changed. Your route is here when you want it.',
              style: Type.body.copyWith(color: Palette.textHi),
            ),
          ),
        );
        return;
      case GoalTodayRecoveryChoice.smaller:
        await _applyGoalRecovery(goal, GoalPlanSignal.tooBig);
        return;
      case GoalTodayRecoveryChoice.prepareReturn:
        await _applyGoalRecovery(goal, GoalPlanSignal.lowEnergy);
        return;
    }
  }

  Future<void> _applyGoalRecovery(Goal goal, GoalPlanSignal signal) async {
    final plan = goal.plan;
    if (plan == null || plan.complete || plan.currentStep == null) return;
    final revised = GoalPlanner.recalibrate(goal, signal, Clock.now());
    _discardUnfinishedOpeningRevision(goal, plan.revision);
    state.updateGoalPlan(goal, revised);
    onPersist();
    if (!mounted) return;
    setState(() {
      _selectedGoalTitle = goal.title;
      _arrivingGoalTitle = null;
    });
    await _openGoalOpening(context, goal, startInWorkshop: true);
  }

  Future<void> _buildGoalPlan(BuildContext context, Goal goal) async {
    if (goal.plan != null) return;
    final plan = await showGoalPlanBuilder(context, goal: goal);
    if (!mounted || plan == null) return;
    state.updateGoalPlan(goal, plan);
    goal.openingSeen = false;
    onPersist();
    if (!mounted) return;
    setState(() {
      _selectedGoalTitle = goal.title;
      _arrivingGoalTitle = goal.title;
    });
    await _openGoalOpening(this.context, goal);
  }

  void _adoptGoal(BuildContext context, GoalIdea idea) {
    Goal? existingGoal;
    for (final existing in state.goals) {
      if (_questTitleKey(existing.title) == _questTitleKey(idea.title)) {
        existingGoal = existing;
        break;
      }
    }
    final routeType =
        idea.quests.any((quest) => quest.schedule != QuestSchedule.once)
        ? GoalRouteType.routine
        : GoalRouteType.finish;
    final today = Clock.now().weekday;
    final templates = [
      for (final template in idea.quests)
        template.schedule == QuestSchedule.weekly
            ? template.build(goalTitle: idea.title, weekdays: [today])
            : template.build(goalTitle: idea.title),
    ];
    final route =
        existingGoal?.plan ??
        GoalPlanner.fromActions(
          title: idea.title,
          stat: idea.stat,
          type: routeType,
          actions: templates.map((quest) => quest.displayTitle),
          questTemplates: templates,
          now: Clock.now(),
          outcome: idea.title,
          successProof: idea.finishLine,
          obstacleCue: idea.frictionCue,
          fallbackAction: idea.lighterMove,
        );
    final goal =
        existingGoal ??
        Goal(
          title: idea.title,
          stat: idea.stat,
          kind: routeType == GoalRouteType.routine
              ? GoalKind.become
              : GoalKind.achieve,
          target: routeType == GoalRouteType.routine
              ? 25
              : route.steps.fold(
                  0,
                  (total, step) => total + step.requiredCompletions,
                ),
          openingSeen: false,
          plan: route,
          fallbackCue: route.obstacleCue,
          fallbackAction: route.fallbackAction,
        );
    if (existingGoal == null) {
      if (!state.addGoal(goal)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Palette.card,
            content: Text(
              'That goal is already underway',
              style: Type.body.copyWith(color: Palette.textHi),
            ),
          ),
        );
        return;
      }
      onPersist();
      Sfx.instance.playMaterial(MaterialSound.brass);
      HapticFeedback.mediumImpact();
      setState(() {
        _selectedGoalTitle = goal.title;
        _arrivingGoalTitle = goal.title;
      });
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openGoalOpening(this.context, goal);
      });
      return;
    }

    // Leaving before accepting preserves the proposed route but does not put
    // its actions on the board. Re-enter the workshop instead of silently
    // turning a second catalog tap into acceptance.
    if (!existingGoal.openingSeen) {
      if (existingGoal.plan == null) {
        state.updateGoalPlan(existingGoal, route);
        onPersist();
      }
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openGoalOpening(this.context, existingGoal!);
      });
      return;
    }

    // Once the first cut has been accepted, catalog use is ordinary board
    // management and can add any authored actions that are still missing.
    if (existingGoal.plan == null) {
      state.updateGoalPlan(existingGoal, route);
    }
    var added = 0;
    for (var index = 0; index < templates.length; index++) {
      final quest = templates[index];
      quest.goalTitle = existingGoal.title;
      if (index < route.steps.length) {
        quest.goalPlanStepId = route.steps[index].id;
        quest.goalPlanRevision = route.revision;
        quest.goalPlanAttempt = 1;
      }
      if (onAdd(quest)) added++;
    }
    if (added > 0) {
      onPersist();
      Sfx.instance.play('levelup');
      HapticFeedback.mediumImpact();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.card,
        content: Text(
          added > 0
              ? '$added actions added to “${existingGoal.title}”'
              : 'Those actions are already on your board',
          style: Type.body.copyWith(color: Palette.textHi),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final activeGoals = state.goals
            .where((goal) => !goal.complete)
            .toList(growable: false);
        final arrivals = state.goals
            .where((goal) => goal.complete)
            .toList(growable: false);
        final focus = _focusGoal(activeGoals);
        final otherGoals = activeGoals
            .where((goal) => !identical(goal, focus))
            .toList(growable: false);
        final still =
            state.reduceMotion ||
            (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
        final surface = MediaQuery.sizeOf(context);
        final compactHero =
            MediaQuery.sizeOf(context).width < 360 ||
            MediaQuery.sizeOf(context).height < 700 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.2;
        final todayField = _TodayFieldFolio(
          quests: quests,
          day: Clock.now(),
          onChoose: () => _chooseToday(context),
        );
        if (focus != null) {
          final focusScene = _LivingGoalFocus(
            key: ValueKey<String>('goal-folio-${_questTitleKey(focus.title)}'),
            state: state,
            goal: focus,
            quests: quests,
            onRemoveGoal: onRemoveGoal,
            onPersist: onPersist,
            onAddQuest: onAdd,
            onOpenQuest: onOpenQuest,
            onOpenOpening: () => _openGoalOpening(context, focus),
            onOpenWorkshop: () => _openWorkshop(context, focus),
            onOpenWorkshopGoal: () =>
                _openGoalOpening(context, focus, startInWorkshop: true),
            light: lightDirection ?? parallax,
            arriving:
                _arrivingGoalTitle != null &&
                _questTitleKey(_arrivingGoalTitle!) ==
                    _questTitleKey(focus.title),
            onAddAction: (defaultTitle) =>
                _addAction(context, focus, defaultTitle: defaultTitle),
            onPrepareFallback: (fallback) =>
                _prepareGoalFallback(context, focus, fallback),
            onRecoverToday: () => _recoverGoalToday(context, focus),
            onAdjustPlan: () => _adjustGoalPlan(context, focus),
            onBuildPlan: () => _buildGoalPlan(context, focus),
            onNewGoal: () => _openQuickCreate(context),
            onChooseToday: () => _chooseToday(context),
          );
          return _GoalsThresholdPage(
            reduceMotion: state.reduceMotion,
            focus: focusScene,
            todayField: todayField,
            support: _GoalSupportTray(
              initiallyExpanded: false,
              reduceMotion: state.reduceMotion,
              hasGoalContext: true,
              onUnstick: () => _openUnstick(context, focus),
              onWorkout: _openGuidedWorkout,
            ),
            otherGoals: otherGoals.isEmpty
                ? null
                : _YourGoals(
                    state: state,
                    goals: otherGoals,
                    sectionLabel: 'OTHER GOALS',
                    onRemoveGoal: onRemoveGoal,
                    onPersist: onPersist,
                    onAddQuest: onAdd,
                    quests: quests,
                    onOpenQuest: onOpenQuest,
                    onSelectGoal: _selectGoal,
                    collapsed: true,
                  ),
            arrivals: arrivals.isEmpty
                ? null
                : _YourGoals(
                    state: state,
                    goals: arrivals,
                    sectionLabel: 'COMPLETED',
                    onRemoveGoal: onRemoveGoal,
                    onPersist: onPersist,
                    onAddQuest: onAdd,
                    quests: quests,
                    onOpenQuest: onOpenQuest,
                    collapsed: true,
                  ),
          );
        }
        final focusOrEmpty = KeyedSubtree(
          key: const ValueKey<String>('goals-empty-folio'),
          child: _GoalsEmptyBoard(
            hasArrivals: arrivals.isNotEmpty,
            onStart: () => _openQuickCreate(context),
            onBrowse: () => _openStartingPoints(context),
            light: lightDirection ?? parallax,
            reduceMotion: state.reduceMotion,
          ),
        );
        return LuxePageList(
          assetPath: goalsRoomContinuousAsset,
          title: 'Goals',
          subtitle: '',
          icon: Icons.explore_outlined,
          parallax: parallax,
          reduceMotion: state.reduceMotion,
          heroHeight: surface.height - 24,
          headingTop: compactHero
              ? 106
              : (surface.height * 0.28).clamp(220.0, 272.0).toDouble(),
          heroAlignment: Alignment.center,
          heroScale: goalsRoomRestScale,
          heroTranslation: goalsRoomRestTranslation,
          heroScrim: goalsOverviewScrim,
          bodyTextureAsset: 'assets/room/wall_grain.png',
          heading: _GoalsHeading(
            focus: focus,
            onNewGoal: state.goals.isEmpty
                ? null
                : () => _openQuickCreate(context),
          ),
          children: [
            AnimatedSwitcher(
              duration: still ? Motion.ack : Motion.settle,
              reverseDuration: still ? Motion.ack : Motion.quick,
              switchInCurve: Motion.respond,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                if (still) {
                  return FadeTransition(opacity: animation, child: child);
                }
                final response = CurvedAnimation(
                  parent: animation,
                  curve: Motion.respond,
                  reverseCurve: Curves.easeInCubic,
                );
                return FadeTransition(
                  opacity: response,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.035, 0.012),
                      end: Offset.zero,
                    ).animate(response),
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.985,
                        end: 1,
                      ).animate(response),
                      child: child,
                    ),
                  ),
                );
              },
              child: focusOrEmpty,
            ),
            const SizedBox(height: 18),
            todayField,
            const SizedBox(height: 18),
            _GoalSupportTray(
              initiallyExpanded: false,
              reduceMotion: state.reduceMotion,
              hasGoalContext: focus != null,
              onUnstick: () => _openUnstick(context, focus),
              onWorkout: _openGuidedWorkout,
            ),
            if (otherGoals.isNotEmpty) ...[
              // The first parked frame belongs to the focused commitment, but
              // the next section should arrive as a deliberate doorway at the
              // fold rather than a clipped row after an empty desk band.
              SizedBox(height: compactHero ? 38 : 48),
              _YourGoals(
                state: state,
                goals: otherGoals,
                sectionLabel: 'OTHER GOALS',
                onRemoveGoal: onRemoveGoal,
                onPersist: onPersist,
                onAddQuest: onAdd,
                quests: quests,
                onOpenQuest: onOpenQuest,
                onSelectGoal: _selectGoal,
                collapsed: true,
              ),
            ],
            if (arrivals.isNotEmpty) ...[
              const SizedBox(height: 18),
              _YourGoals(
                state: state,
                goals: arrivals,
                sectionLabel: 'COMPLETED',
                onRemoveGoal: onRemoveGoal,
                onPersist: onPersist,
                onAddQuest: onAdd,
                quests: quests,
                onOpenQuest: onOpenQuest,
                collapsed: true,
              ),
            ],
          ],
        );
      },
    );
  }

  /// The "adopt a path" catalog, grouped into scannable sections (round-16).
  /// Walks [_goalCategories] in order; each non-empty group gets a header then
  /// its cards. Unknown titles are skipped, so the table can't crash if a goal
  /// is renamed — it just won't appear until the table is updated.
  List<Widget> _catalogSections(BuildContext context) {
    // Dev-time guard: every catalog goal must be assigned to a category, or it
    // silently never renders here. A new GoalIdea added without a matching
    // _goalCategories entry fails loudly in debug instead of vanishing.
    assert(
      goalCatalog.every(
        (g) => _goalCategories.any((c) => c.goalTitles.contains(g.title)),
      ),
      'Every goalCatalog entry must be listed in a _GoalCategory (goals.dart). '
      'Unmapped goal(s): ${goalCatalog.where((g) => !_goalCategories.any((c) => c.goalTitles.contains(g.title))).map((g) => g.title).toList()}',
    );
    final activeQuests = <String, Quest>{
      for (final quest in quests) _questTitleKey(quest.title): quest,
    };
    final widgets = <Widget>[];
    for (final cat in _goalCategories) {
      final ideas = [
        for (final title in cat.goalTitles)
          ...goalCatalog.where((g) => g.title == title),
      ];
      if (ideas.isEmpty) continue;
      widgets.add(const SizedBox(height: 22));
      widgets.add(
        _CategoryHeader(
          label: cat.label,
          blurb: cat.blurb,
          icon: cat.icon,
          accent: cat.accent,
        ),
      );
      widgets.add(const SizedBox(height: 10));
      for (var i = 0; i < ideas.length; i++) {
        final idea = ideas[i];
        widgets.add(
          _GoalCard(
            key: ValueKey<String>('goal-catalog-${_questTitleKey(idea.title)}'),
            idea: idea,
            onAdd: onAdd,
            activeQuests: activeQuests,
            onRemoveQuest: onRemoveQuest,
            onPersist: onPersist,
            onAdopt: () => _adoptGoal(context, idea),
            reduceMotion: state.reduceMotion,
            adopted: state.goals.any(
              (g) => _questTitleKey(g.title) == _questTitleKey(idea.title),
            ),
          ),
        );
        if (i < ideas.length - 1) widgets.add(const SizedBox(height: 12));
      }
    }
    return widgets;
  }
}

class _GoalsHeading extends StatelessWidget {
  const _GoalsHeading({required this.focus, required this.onNewGoal});

  final Goal? focus;
  final VoidCallback? onNewGoal;

  @override
  Widget build(BuildContext context) {
    final goal = focus;
    final accent = goal?.stat.color ?? Palette.xpLight;
    return Row(
      children: [
        FacetMedallion(
          size: 32,
          accent: accent,
          child: Icon(
            goal?.stat.icon ?? Icons.route_outlined,
            size: 17,
            color: accent.withValues(alpha: 0.92),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            goal == null ? 'Goals' : 'Your focus',
            style:
                const TextStyle(
                  fontFamily: 'EBGaramond',
                  fontSize: 17,
                  height: 1.05,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.12,
                ).copyWith(
                  color: goal == null
                      ? Palette.textMid
                      : accent.withValues(alpha: 0.92),
                  shadows: _goalsRoomTextShadows,
                ),
          ),
        ),
        if (onNewGoal case final create?) ...[
          const SizedBox(width: 10),
          _NewGoalButton(onTap: create),
        ],
      ],
    );
  }
}

class _NewGoalButton extends StatelessWidget {
  const _NewGoalButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return Pressable(
      key: const Key('goals-new-goal'),
      material: MaterialSound.glass,
      soundEnabled: false,
      pressDepth: 1.5,
      borderRadius: BorderRadius.circular(6),
      edgeColor: Colors.transparent,
      guardRapidReentry: true,
      semanticLabel: 'Create a new goal',
      onTapUp: (_) => onTap(),
      stateBuilder: (context, child, pressed, focused, hovered) =>
          AnimatedContainer(
            duration: pressed ? Duration.zero : Motion.ack,
            decoration: BoxDecoration(
              color: pressed
                  ? Palette.xpLight.withValues(alpha: 0.065)
                  : focused || hovered
                  ? Palette.xpLight.withValues(alpha: 0.025)
                  : const Color(0x24140F0C),
              borderRadius: BorderRadius.circular(6),
              border: Border(
                bottom: BorderSide(
                  color: Palette.brass.withValues(
                    alpha: pressed || focused ? 0.54 : 0.30,
                  ),
                  width: 1,
                ),
              ),
            ),
            child: child,
          ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: compact ? 9 : 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_rounded,
              size: 17,
              color: Palette.brassLit.withValues(alpha: 0.68),
            ),
            if (!compact) ...[
              const SizedBox(width: 5),
              Text(
                'New goal',
                style: const TextStyle(
                  fontFamily: 'EBGaramond',
                  fontSize: 15.5,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: Palette.textMid,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single quiet support plane. The two established experiences remain one
/// obvious disclosure away without reading as promotions above the goal.
class _GoalSupportTray extends StatefulWidget {
  const _GoalSupportTray({
    required this.initiallyExpanded,
    required this.reduceMotion,
    required this.hasGoalContext,
    required this.onUnstick,
    required this.onWorkout,
  });

  final bool initiallyExpanded;
  final bool reduceMotion;
  final bool hasGoalContext;
  final VoidCallback onUnstick;
  final VoidCallback onWorkout;

  @override
  State<_GoalSupportTray> createState() => _GoalSupportTrayState();
}

class _GoalSupportTrayState extends State<_GoalSupportTray> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final still =
        widget.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    const cut = 12.0;
    return ClipPath(
      clipper: const FacetedClipper(cut: cut),
      child: DecoratedBox(
        decoration: facetedDecoration(
          color: const Color(0x9418120F),
          cut: cut,
          borderColor: const Color(0x349E7950),
          borderWidth: 1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Pressable(
              key: const Key('goals-support-toggle'),
              material: MaterialSound.glass,
              pressDepth: 1,
              shape: const FacetedBorder(cut: cut),
              edgeColor: Colors.transparent,
              semanticLabel:
                  'Need another way in. ${_expanded ? 'Expanded' : 'Collapsed'}.',
              semanticHint: _expanded
                  ? 'Collapse support choices.'
                  : 'Show a smaller start and Guided Workouts.',
              onTapUp: (_) => setState(() => _expanded = !_expanded),
              stateBuilder: (context, child, pressed, focused, hovered) =>
                  AnimatedContainer(
                    duration: pressed ? Duration.zero : Motion.ack,
                    color: pressed
                        ? Palette.xpLight.withValues(alpha: 0.055)
                        : focused || hovered
                        ? Palette.xpLight.withValues(alpha: 0.025)
                        : Colors.transparent,
                    child: child,
                  ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 13, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Need another way in',
                        style: const TextStyle(
                          fontFamily: 'EBGaramond',
                          fontSize: 17.5,
                          height: 1.05,
                          fontWeight: FontWeight.w600,
                          color: Palette.textMid,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: still ? Motion.ack : Motion.quick,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: still ? Motion.ack : Motion.quick,
              switchInCurve: Motion.respond,
              switchOutCurve: Curves.easeInCubic,
              child: _expanded
                  ? LayoutBuilder(
                      key: const ValueKey<String>('goals-support-open'),
                      builder: (context, constraints) {
                        final stacked =
                            constraints.maxWidth < 350 ||
                            MediaQuery.textScalerOf(context).scale(1) > 1.2;
                        final unstick = _SupportAction(
                          key: const Key('goals-unstick-me'),
                          icon: Icons.bolt_outlined,
                          title: widget.hasGoalContext
                              ? 'Find a start'
                              : 'Unstick Me',
                          detail: widget.hasGoalContext
                              ? 'A small next move, shaped around this goal.'
                              : 'Get moving with one small win.',
                          accent: Palette.streak,
                          onTap: widget.onUnstick,
                        );
                        final workout = _SupportAction(
                          key: const Key('goals-guided-workouts'),
                          icon: Icons.favorite_outline_rounded,
                          title: 'Guided Workouts',
                          detail: 'Work alongside a gentle guide.',
                          accent: Stat.str.color,
                          onTap: widget.onWorkout,
                        );
                        if (stacked) {
                          return Column(
                            children: [
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: Color(0x3A8A603C),
                              ),
                              unstick,
                              const Divider(
                                height: 1,
                                thickness: 1,
                                indent: 16,
                                endIndent: 16,
                                color: Color(0x2E8A603C),
                              ),
                              workout,
                            ],
                          );
                        }
                        return Column(
                          children: [
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0x3A8A603C),
                            ),
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: unstick),
                                  const VerticalDivider(
                                    width: 1,
                                    thickness: 1,
                                    color: Color(0x2E8A603C),
                                  ),
                                  Expanded(child: workout),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  : const SizedBox.shrink(
                      key: ValueKey<String>('goals-support-closed'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportAction extends StatelessWidget {
  const _SupportAction({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      material: MaterialSound.wood,
      pressDepth: 1.5,
      borderRadius: BorderRadius.zero,
      edgeColor: Colors.transparent,
      guardRapidReentry: true,
      semanticLabel: '$title. $detail',
      semanticHint: 'Open this guided experience.',
      onTapUp: (_) => onTap(),
      stateBuilder: (context, child, pressed, focused, hovered) =>
          AnimatedContainer(
            duration: pressed ? Duration.zero : Motion.ack,
            curve: Motion.respond,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  accent.withValues(
                    alpha: pressed
                        ? 0.12
                        : focused || hovered
                        ? 0.065
                        : 0.0,
                  ),
                  Colors.transparent,
                ],
              ),
            ),
            child: AnimatedSlide(
              offset: pressed ? const Offset(0.012, 0) : Offset.zero,
              duration: pressed ? Duration.zero : Motion.ack,
              curve: Motion.respond,
              child: child,
            ),
          ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 13, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 30,
              height: 38,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned(
                    left: 0,
                    top: 5,
                    bottom: 5,
                    child: Container(
                      width: 1.5,
                      color: accent.withValues(alpha: 0.64),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    child: Icon(icon, size: 18, color: accent),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    style: const TextStyle(
                      fontFamily: 'EBGaramond',
                      fontSize: 15.5,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                      color: Palette.textHi,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Type.body.copyWith(
                      fontSize: 12.25,
                      height: 1.25,
                      color: Palette.textLo,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
          ],
        ),
      ),
    );
  }
}

class _ReadyMadeGoalsScreen extends StatelessWidget {
  const _ReadyMadeGoalsScreen({
    required this.state,
    required this.buildCatalog,
  });

  final GameState state;
  final List<Widget> Function(BuildContext context) buildCatalog;

  @override
  Widget build(BuildContext context) {
    return WarmBackground(
      themeId: state.canvasTheme,
      reduceMotion: state.reduceMotion,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: state,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Back to Goals',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Palette.textMid,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'STARTING POINTS',
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    letterSpacing: 1.5,
                    color: Palette.xpLight,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Borrow a shape. Change anything.',
                  style: Type.display.copyWith(fontSize: 25, height: 1.08),
                ),
                const SizedBox(height: 7),
                Text(
                  'These are optional beginnings, kept away from your actual goals until you ask for them.',
                  style: Type.body.copyWith(
                    fontSize: 13.5,
                    height: 1.4,
                    color: Palette.textMid,
                  ),
                ),
                ...buildCatalog(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalsThresholdPage extends StatelessWidget {
  const _GoalsThresholdPage({
    required this.reduceMotion,
    required this.focus,
    required this.todayField,
    required this.support,
    this.otherGoals,
    this.arrivals,
  });

  final bool reduceMotion;
  final Widget focus;
  final Widget todayField;
  final Widget support;
  final Widget? otherGoals;
  final Widget? arrivals;

  @override
  Widget build(BuildContext context) {
    final still =
        reduceMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final belowRoom = <Widget>[
      todayField,
      const SizedBox(height: 18),
      support,
      if (otherGoals case final goals?) ...[const SizedBox(height: 30), goals],
      if (arrivals case final completed?) ...[
        const SizedBox(height: 18),
        completed,
      ],
    ];

    return ColoredBox(
      color: const Color(0xFF100D0B),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.055,
                child: Image.asset(
                  'assets/room/wall_grain.png',
                  fit: BoxFit.none,
                  repeat: ImageRepeat.repeat,
                  alignment: Alignment.topLeft,
                  color: const Color(0xFF6A3F26),
                  colorBlendMode: BlendMode.modulate,
                  filterQuality: FilterQuality.low,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
          CustomScrollView(
            key: const Key('goals-threshold-scroll'),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: still
                      ? Motion.ack
                      : const Duration(milliseconds: 440),
                  reverseDuration: still
                      ? Motion.ack
                      : const Duration(milliseconds: 360),
                  switchInCurve: Motion.respond,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    if (still) {
                      return FadeTransition(opacity: animation, child: child);
                    }
                    final response = CurvedAnimation(
                      parent: animation,
                      curve: Motion.respond,
                      reverseCurve: Curves.easeInCubic,
                    );
                    return FadeTransition(
                      opacity: response,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero,
                        ).animate(response),
                        child: child,
                      ),
                    );
                  },
                  child: focus,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 130),
                sliver: SliverList.list(children: belowRoom),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A useful, ordinary-day control that deliberately sits below the room. The
/// painted threshold remains the place for a goal and its exact Quest; this
/// folio gives a crowded board a shape without pretending every open Quest is
/// an obligation.
class _TodayFieldFolio extends StatelessWidget {
  const _TodayFieldFolio({
    required this.quests,
    required this.day,
    required this.onChoose,
  });

  final List<Quest> quests;
  final DateTime day;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final field = selectedDailyFieldForDay(quests, day);
    final candidates = planningQuestsForDay(
      quests,
      day,
    ).where((quest) => !quest.allDay && !quest.isEvent).toList(growable: false);
    final canChoose = candidates.isNotEmpty;
    final hasField = field.isNotEmpty;
    final label = hasField
        ? '${field.length} IN TODAY\'S FIELD'
        : 'TODAY\'S FIELD';
    final heading = hasField
        ? 'Today has a shape.'
        : 'Choose what leads today.';
    final supporting = hasField
        ? 'Everything else stays open for when you have the time or energy.'
        : canChoose
        ? 'Pick up to three quests to carry. The rest stays open if the day has more in it.'
        : 'Nothing ordinary is waiting. A clear day is allowed.';

    return Semantics(
      container: true,
      label: hasField
          ? 'Today’s field, ${field.length} quest${field.length == 1 ? '' : 's'} chosen'
          : 'Today’s field, not shaped yet',
      child: GlassPanel(
        key: const Key('goals-today-field'),
        radius: 16,
        tint: const Color(0xED211811),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.filter_list_rounded,
                  size: 17,
                  color: Palette.xpLight,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      color: Palette.xpLight,
                    ),
                  ),
                ),
                if (hasField)
                  Text(
                    'UP TO 3',
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      color: Palette.textLo,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              heading,
              style: Type.display.copyWith(fontSize: 23, height: 1.04),
            ),
            const SizedBox(height: 5),
            Text(
              supporting,
              style: Type.body.copyWith(
                fontSize: 13.5,
                height: 1.35,
                color: Palette.textMid,
              ),
            ),
            if (hasField) ...[
              const SizedBox(height: 13),
              for (var index = 0; index < field.length; index++) ...[
                _TodayFieldRow(index: index + 1, quest: field[index]),
                if (index != field.length - 1) const SizedBox(height: 7),
              ],
            ],
            if (canChoose) ...[
              const SizedBox(height: 14),
              _TodayFieldAction(
                key: Key(
                  hasField ? 'goals-reshape-today' : 'goals-choose-today',
                ),
                label: hasField ? 'RESHAPE TODAY' : 'CHOOSE TODAY',
                onTap: onChoose,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodayFieldRow extends StatelessWidget {
  const _TodayFieldRow({required this.index, required this.quest});

  final int index;
  final Quest quest;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey<String>('goals-today-field-${_questTitleKey(quest.title)}'),
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
      decoration: facetedDecoration(
        cut: 9,
        color: Palette.xpLight.withValues(alpha: 0.075),
        borderColor: Palette.xpLight.withValues(alpha: 0.34),
      ),
      child: Row(
        children: [
          Text(
            '$index',
            style: Type.numerals.copyWith(fontSize: 18, color: Palette.xpLight),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              quest.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Type.body.copyWith(
                fontSize: 13.5,
                height: 1.22,
                color: Palette.textHi,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Icon(Icons.arrow_forward_rounded, size: 17, color: Palette.textLo),
        ],
      ),
    );
  }
}

class _TodayFieldAction extends StatelessWidget {
  const _TodayFieldAction({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      material: MaterialSound.brass,
      semanticLabel: label,
      onTapUp: (_) => onTap(),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: facetedDecoration(
          cut: 10,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Palette.brass.withValues(alpha: 0.28),
              Palette.brassDeep.withValues(alpha: 0.34),
            ],
          ),
          borderColor: Palette.brassLit.withValues(alpha: 0.55),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  color: Palette.textHi,
                ),
              ),
            ),
            const SizedBox(width: 9),
            const Icon(Icons.tune_rounded, size: 18, color: Palette.textHi),
          ],
        ),
      ),
    );
  }
}

class _LivingGoalFocus extends StatelessWidget {
  const _LivingGoalFocus({
    super.key,
    required this.state,
    required this.goal,
    required this.quests,
    required this.onRemoveGoal,
    required this.onPersist,
    required this.onAddQuest,
    required this.onOpenQuest,
    required this.onOpenOpening,
    required this.onOpenWorkshop,
    required this.onOpenWorkshopGoal,
    required this.onAddAction,
    required this.onPrepareFallback,
    required this.onRecoverToday,
    required this.onAdjustPlan,
    required this.onBuildPlan,
    required this.onNewGoal,
    required this.onChooseToday,
    required this.light,
    required this.arriving,
  });

  final GameState state;
  final Goal goal;
  final List<Quest> quests;
  final void Function(Goal goal) onRemoveGoal;
  final VoidCallback onPersist;
  final bool Function(Quest quest) onAddQuest;
  final void Function(Quest quest) onOpenQuest;
  final VoidCallback onOpenOpening;
  final VoidCallback onOpenWorkshop;
  final VoidCallback onOpenWorkshopGoal;
  final ValueChanged<String?> onAddAction;
  final Quest? Function(String fallback) onPrepareFallback;
  final VoidCallback onRecoverToday;
  final VoidCallback onAdjustPlan;
  final VoidCallback onBuildPlan;
  final VoidCallback onNewGoal;
  final VoidCallback onChooseToday;
  final ValueListenable<Offset> light;
  final bool arriving;

  static String? _kept(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  void _openDetail(BuildContext context, {bool playSound = true}) {
    if (!goal.openingSeen) {
      onOpenOpening();
      return;
    }
    if (playSound) Sfx.instance.playMaterial(MaterialSound.parchment);
    final linked = _questsForGoal(goal, quests);
    final decision = GoalPlanner.decide(goal, quests, Clock.now());
    final next = decision?.quest ?? _nextQuestToday(goal, quests);
    final fallback = _kept(goal.fallbackAction);
    final fallbackCue = _kept(goal.fallbackCue);
    final actionTitle =
        decision?.actionTitle ??
        next?.displayTitle ??
        fallback ??
        (linked.isEmpty
            ? 'Choose one action small enough to begin'
            : 'Nothing is due. Make the next step smaller');
    Navigator.of(context).push(
      goalRoomRoute<void>(
        context: context,
        reduceMotion: state.reduceMotion,
        settings: const RouteSettings(name: '/goals/detail'),
        invitation: GoalRoomInvitation(
          cue: decision?.whyThisOne ?? _cueFor(next, fallbackCue),
          actionTitle: actionTitle,
          fallbackAction: fallback,
        ),
        builder: (_) => GoalDetailScreen(
          goal: goal,
          state: state,
          quests: quests,
          onRemoveGoal: onRemoveGoal,
          onPersist: onPersist,
          onAddQuest: onAddQuest,
          onOpenQuest: onOpenQuest,
          onOpenWorkshop: onOpenWorkshopGoal,
          onStartFallback: (fallback) {
            final quest = onPrepareFallback(fallback);
            if (quest != null) onOpenQuest(quest);
          },
          onAdjustPlan: goal.plan == null ? onBuildPlan : onAdjustPlan,
          light: light,
        ),
      ),
    );
  }

  void _openCurrentQuestThroughRoom(BuildContext context, Quest quest) {
    if (!goal.openingSeen) {
      onOpenOpening();
      return;
    }
    final navigator = Navigator.of(context);
    final still =
        state.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    late final PageRoute<void> route;
    route = goalRoomRoute<void>(
      context: context,
      reduceMotion: state.reduceMotion,
      settings: const RouteSettings(name: '/goals/quest-handoff'),
      invitation: GoalRoomInvitation(
        cue: _cueFor(quest, _kept(goal.fallbackCue)),
        actionTitle: quest.displayTitle,
        fallbackAction: _kept(goal.fallbackAction),
      ),
      arrivalHold: still ? Duration.zero : const Duration(milliseconds: 360),
      onArrival: () {
        if (!route.isActive || !route.isCurrent) return;
        navigator.removeRoute(route);
        onOpenQuest(quest);
      },
      builder: (_) => GoalQuestArrivalPlate(
        actionTitle: quest.displayTitle,
        accent: goal.stat.color,
      ),
    );
    navigator.push(route);
  }

  Quest? _preparePlanQuest(BuildContext context, GoalActionDecision decision) {
    final existing = decision.quest;
    if (existing != null) return existing;
    final created = GoalPlanner.questFor(goal, decision, Clock.now());
    if (onAddQuest(created)) return created;
    for (final quest in quests) {
      if (_questTitleKey(quest.goalTitle ?? '') == _questTitleKey(goal.title) &&
          quest.goalPlanStepId == decision.step.id &&
          quest.goalPlanRevision == decision.plan.revision &&
          (quest.goalPlanAttempt ?? 1) == decision.step.completions + 1 &&
          GoalPlanner.questActionableToday(quest, Clock.now()) &&
          !quest.doneFor(Clock.now())) {
        return quest;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.card,
        content: Text(
          'That route action is already on your Quest board',
          style: Type.body.copyWith(color: Palette.textHi),
        ),
      ),
    );
    return null;
  }

  String _cueFor(Quest? next, String? fallbackCue) {
    if (next != null) {
      if (next.isEvent) return 'Today, if you can';
      return switch (next.schedule) {
        QuestSchedule.daily => 'Today, if you can',
        QuestSchedule.weekly => 'On today’s path',
        QuestSchedule.monthly => 'Today, if you can',
        QuestSchedule.once => 'Today, if you can',
      };
    }
    if (fallbackCue case final cue?) return 'When $cue';
    return 'Whenever you are ready';
  }

  String get _evidenceCopy {
    if (goal.complete) return 'You kept this in your history.';
    if (goal.progress == 0) return 'Your first return can begin here.';
    final times = goal.progress == 1 ? 'time' : 'times';
    return 'You have found your way back ${goal.progress} $times.';
  }

  @override
  Widget build(BuildContext context) {
    final linked = _questsForGoal(goal, quests);
    final decision = GoalPlanner.decide(goal, quests, Clock.now());
    final next = decision?.quest ?? _nextQuestToday(goal, quests);
    final fallback = _kept(goal.fallbackAction);
    final fallbackCue = _kept(goal.fallbackCue);
    final today = Clock.now();
    final todayFieldCount = selectedDailyFieldForDay(quests, today).length;
    final canChooseToday = planningQuestsForDay(
      quests,
      today,
    ).any((quest) => !quest.allDay && !quest.isEvent);
    final still =
        state.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

    final actionTitle =
        decision?.actionTitle ??
        next?.displayTitle ??
        fallback ??
        (linked.isEmpty
            ? 'Choose one action small enough to begin'
            : 'Nothing is due. Make the next step smaller');
    final actionLabel = decision != null
        ? decision.quest == null
              ? 'Bring inside'
              : 'Open Quest'
        : (next != null || fallback != null ? 'Open Quest' : 'Add a Quest');
    final actionIcon = decision != null || next != null || fallback != null
        ? Icons.arrow_forward_rounded
        : Icons.add;
    final action = decision != null
        ? () {
            if (decision.quest == null) {
              onOpenWorkshopGoal();
              return;
            }
            final quest = _preparePlanQuest(context, decision);
            if (quest != null) _openCurrentQuestThroughRoom(context, quest);
          }
        : next != null
        ? () => _openCurrentQuestThroughRoom(context, next)
        : fallback != null
        ? () {
            final quest = onPrepareFallback(fallback);
            if (quest != null) _openCurrentQuestThroughRoom(context, quest);
          }
        : () => onAddAction(null);

    final content = GoalThresholdScene(
      goalTitle: goal.title,
      evidenceCopy: _evidenceCopy,
      routePosition: decision?.routePosition,
      cue: decision?.whyThisOne ?? _cueFor(next, fallbackCue),
      actionTitle: actionTitle,
      actionLabel: actionLabel,
      actionIcon: actionIcon,
      actionSemanticHint: decision != null && decision.quest == null
          ? 'Cross the room and inspect this cut before it reaches the Quest board.'
          : 'Cross the room and open this exact Quest.',
      onReview: () => _openDetail(context),
      onNewGoal: onNewGoal,
      todayFieldCount: todayFieldCount,
      onChooseToday: canChooseToday ? onChooseToday : null,
      onOpenWorkshop: onOpenWorkshop,
      workshopStatus: decision != null && decision.quest == null
          ? 'cut waiting'
          : decision?.quest != null || next != null
          ? 'Quest on board'
          : goal.plan == null
          ? 'route needed'
          : 'route kept',
      onAction: action,
      recoveryAction: decision?.quest == null ? null : 'this doesn’t fit today',
      recoverySemanticHint: decision?.quest == null
          ? null
          : 'Ask the steward to make, prepare, or leave today’s route alone.',
      onRecovery: decision?.quest == null ? null : onRecoverToday,
      light: light,
      reduceMotion: state.reduceMotion,
    );

    if (!arriving) return content;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: still ? Motion.ack : Motion.settle,
      curve: Motion.respond,
      child: content,
      builder: (context, t, child) => Opacity(
        opacity: 0.72 + (0.28 * t),
        child: Transform.scale(
          scale: still ? 1 : 0.985 + (0.015 * t),
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
    );
  }
}

class _GoalsEmptyBoard extends StatelessWidget {
  const _GoalsEmptyBoard({
    required this.hasArrivals,
    required this.onStart,
    required this.onBrowse,
    required this.light,
    required this.reduceMotion,
  });

  final bool hasArrivals;
  final VoidCallback onStart;
  final VoidCallback onBrowse;
  final ValueListenable<Offset> light;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(3, 4, 3, 2),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 2,
              margin: const EdgeInsets.only(right: 15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Palette.xpLight.withValues(alpha: 0.8),
                    Palette.brass.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    hasArrivals
                        ? 'A new direction'
                        : 'Make room for a direction',
                    style: Type.label.copyWith(
                      fontSize: 11,
                      letterSpacing: 0.45,
                      color: Palette.xpLight,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    hasArrivals
                        ? 'What would you like to make different now?'
                        : 'What would you like to make different?',
                    style: Type.display.copyWith(fontSize: 25, height: 1.06),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A name is enough to begin. You can add one small action now, or leave the space open until the next step is clear.',
                    style: Type.body.copyWith(
                      fontSize: 13.5,
                      height: 1.42,
                      color: Palette.textMid,
                    ),
                  ),
                  const SizedBox(height: 18),
                  GoalPrimaryButton(
                    key: const Key('goals-create-first'),
                    label: 'Create a goal',
                    icon: Icons.add_rounded,
                    onTap: onStart,
                    expand: true,
                    glow: false,
                    light: light,
                    reduceMotion: reduceMotion,
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Pressable(
                      key: const Key('goals-browse-starting-points'),
                      material: MaterialSound.parchment,
                      soundEnabled: false,
                      pressDepth: 1.5,
                      edgeColor: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      guardRapidReentry: true,
                      semanticLabel: 'Browse starting points',
                      semanticHint: 'Open ready-made goal ideas.',
                      onTapUp: (_) => onBrowse(),
                      stateBuilder:
                          (context, child, pressed, focused, hovered) =>
                              AnimatedContainer(
                                duration: pressed ? Duration.zero : Motion.ack,
                                decoration: BoxDecoration(
                                  color: pressed
                                      ? Palette.xpLight.withValues(alpha: 0.08)
                                      : focused || hovered
                                      ? Palette.xpLight.withValues(alpha: 0.04)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: child,
                              ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome_outlined,
                              size: 15,
                              color: Palette.textLo,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'Browse starting points',
                              style: Type.body.copyWith(
                                fontSize: 12.5,
                                color: Palette.textLo,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 15,
                              color: Palette.textLo,
                            ),
                          ],
                        ),
                      ),
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

/// A light, hand-made section rule for the catalog (round-16): a small
/// specular accent medallion (a quieter quote of the goal-card medallion) +
/// a bright ALL-CAPS title + an italic blurb + a honey-to-nothing hairline.
/// Reads as structure above its cards, never as glass chrome of its own.
class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.label,
    required this.blurb,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String blurb;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // A small specular accent medallion — a quieter quote of the goal-card
    // stat medallion so headers read as kin of the cards beneath them.
    final medallion = FacetMedallion(
      size: 26,
      accent: accent,
      child: Icon(icon, size: 15, color: accent),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title line: medallion · ALL-CAPS label · honey-to-nothing rule.
          // Both the label and rule can yield space so enlarged text wraps
          // cleanly instead of pushing past a narrow phone viewport.
          Row(
            children: [
              medallion,
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  style: Type.label.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.6,
                    color: Palette.textHi,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 1.2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        accent.withValues(alpha: 0.45),
                        Palette.glassEdge,
                        Palette.glassEdge.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Soft subtitle on its own full-width line — the warm voice, never
          // squeezed or ellipsized by the rule beside it.
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Text(
              blurb,
              style: Type.body.copyWith(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Goals read as one live direction board rather than a stack of unrelated
/// cards. The title, progress, and next honest action carry the hierarchy;
/// decoration never pretends to personalize a goal it cannot actually depict.
class _YourGoals extends StatelessWidget {
  const _YourGoals({
    required this.state,
    required this.goals,
    required this.sectionLabel,
    required this.onRemoveGoal,
    required this.onPersist,
    required this.onAddQuest,
    required this.quests,
    required this.onOpenQuest,
    this.onSelectGoal,
    this.collapsed = false,
  });

  final GameState state;
  final List<Goal> goals;
  final String sectionLabel;
  final void Function(Goal goal) onRemoveGoal;
  final VoidCallback onPersist;
  final bool Function(Quest quest) onAddQuest;
  final List<Quest> quests;
  final void Function(Quest quest) onOpenQuest;
  final ValueChanged<Goal>? onSelectGoal;
  final bool collapsed;

  void _openDetail(BuildContext context, Goal goal) {
    Sfx.instance.playMaterial(MaterialSound.parchment);
    Navigator.of(context).push(
      goalRoomRoute<void>(
        context: context,
        reduceMotion: state.reduceMotion,
        builder: (_) => GoalDetailScreen(
          goal: goal,
          state: state,
          quests: quests,
          onRemoveGoal: onRemoveGoal,
          onPersist: onPersist,
          onAddQuest: onAddQuest,
          onOpenQuest: onOpenQuest,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completed = goals.every((goal) => goal.complete);
    final accent = completed ? Palette.xpLight : Palette.xp;
    final rows = <Widget>[
      for (var index = 0; index < goals.length; index++) ...[
        Builder(
          builder: (context) {
            final goal = goals[index];
            final linked = _questsForGoal(goal, quests);
            return _GoalRouteCard(
              key: ValueKey<String>(
                'active-goal-${_questTitleKey(goal.title)}',
              ),
              goal: goal,
              linkedCount: linked.length,
              nextToday: goal.complete ? null : _nextQuestToday(goal, quests),
              opensInFolio: !goal.complete && onSelectGoal != null,
              onTap: () {
                final select = onSelectGoal;
                if (!goal.complete && select != null) {
                  select(goal);
                } else {
                  _openDetail(context, goal);
                }
              },
            );
          },
        ),
        if (index < goals.length - 1)
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Palette.brassDeep.withValues(alpha: 0.3),
          ),
      ],
    ];

    final heading = switch (sectionLabel) {
      'OTHER GOALS' => 'Other goals',
      'COMPLETED' => 'Completed goals',
      _ => sectionLabel,
    };
    final header = Row(
      children: [
        Icon(
          completed ? Icons.check_circle_outline : Icons.view_list_outlined,
          size: 16,
          color: accent,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            heading,
            style: Type.body.copyWith(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Palette.textMid,
            ),
          ),
        ),
      ],
    );

    if (collapsed) {
      final sectionKey = completed
          ? const Key('completed-goals-section')
          : const Key('other-goals-section');
      final disclosureKey = completed
          ? const Key('completed-goals-disclosure')
          : const Key('other-goals-disclosure');
      return KeyedSubtree(
        key: sectionKey,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: disclosureKey,
            initiallyExpanded: false,
            tilePadding: const EdgeInsets.symmetric(horizontal: 2),
            childrenPadding: const EdgeInsets.only(top: 5),
            collapsedIconColor: Palette.textLo,
            iconColor: Palette.xpLight,
            collapsedBackgroundColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            shape: const Border(),
            collapsedShape: const Border(),
            title: header,
            children: rows,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: header,
        ),
        const SizedBox(height: 5),
        Column(children: rows),
      ],
    );
  }
}

class _GoalRouteCard extends StatelessWidget {
  const _GoalRouteCard({
    super.key,
    required this.goal,
    required this.linkedCount,
    required this.nextToday,
    required this.opensInFolio,
    required this.onTap,
  });

  final Goal goal;
  final int linkedCount;
  final Quest? nextToday;
  final bool opensInFolio;
  final VoidCallback onTap;

  Color get _accent => goal.complete ? Palette.xpLight : goal.stat.color;

  String get _statusCopy {
    if (goal.complete) return 'Completed';
    if (nextToday case final quest?) return 'Today · ${quest.displayTitle}';
    if (linkedCount == 0) return 'No next action';
    return 'No action due today';
  }

  @override
  Widget build(BuildContext context) {
    final semantic = '${goal.title}. ${_goalProgressCopy(goal)}. $_statusCopy.';
    return Pressable(
      material: MaterialSound.parchment,
      soundEnabled: false,
      pressDepth: 1.5,
      borderRadius: BorderRadius.zero,
      edgeColor: Colors.transparent,
      guardRapidReentry: true,
      semanticLabel: semantic,
      semanticHint: opensInFolio
          ? 'Bring this goal into focus.'
          : 'Open goal details.',
      onTapUp: (_) => onTap(),
      stateBuilder: (context, child, pressed, focused, hovered) =>
          AnimatedContainer(
            duration: pressed ? Duration.zero : Motion.ack,
            curve: Motion.respond,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  _accent.withValues(
                    alpha: pressed
                        ? 0.10
                        : focused || hovered
                        ? 0.05
                        : 0.0,
                  ),
                  Colors.transparent,
                ],
              ),
            ),
            child: AnimatedSlide(
              offset: pressed ? const Offset(0.01, 0) : Offset.zero,
              duration: pressed ? Duration.zero : Motion.ack,
              curve: Motion.respond,
              child: child,
            ),
          ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 340;
          final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              narrow ? 11 : 13,
              narrow ? 11 : 12,
              narrow ? 10 : 12,
              narrow ? 11 : 12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    goal.stat.icon,
                    size: narrow ? 21 : 23,
                    color: _accent.withValues(alpha: 0.78),
                  ),
                ),
                SizedBox(width: narrow ? 11 : 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        maxLines: largeText ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Type.display.copyWith(
                          fontSize: narrow ? 17 : 18.5,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _statusCopy,
                        maxLines: largeText ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Type.body.copyWith(
                          fontSize: narrow ? 11.5 : 12.5,
                          height: 1.28,
                          color: nextToday != null
                              ? _accent.withValues(alpha: 0.88)
                              : Palette.textLo,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 9),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: Palette.textLo,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GoalCard extends StatefulWidget {
  const _GoalCard({
    super.key,
    required this.idea,
    required this.onAdd,
    required this.activeQuests,
    required this.onRemoveQuest,
    required this.onPersist,
    required this.onAdopt,
    required this.reduceMotion,
    required this.adopted,
  });

  final GoalIdea idea;
  final bool Function(Quest) onAdd;
  final Map<String, Quest> activeQuests;
  final void Function(Quest) onRemoveQuest;
  final VoidCallback onPersist;
  final VoidCallback onAdopt;
  final bool reduceMotion;
  final bool adopted;

  @override
  State<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<_GoalCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final idea = widget.idea;
    final still =
        widget.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final missingActions = idea.quests
        .where(
          (template) =>
              !widget.activeQuests.containsKey(_questTitleKey(template.title)),
        )
        .length;
    final fullyUnderway = widget.adopted && missingActions == 0;
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            label: '${_open ? 'Collapse' : 'Expand'} ${idea.title}',
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: ValueKey<String>(
                  'goal-catalog-toggle-${_questTitleKey(idea.title)}',
                ),
                onTap: () {
                  Sfx.instance.playMaterial(MaterialSound.glass);
                  setState(() => _open = !_open);
                },
                child: Row(
                  children: [
                    FacetMedallion(
                      size: 38,
                      accent: idea.stat.color,
                      child: Center(
                        // scaleDown so longer domain abbrs (CRAFT, PEOPLE) shrink
                        // to one line in the circle instead of wrapping to two.
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              idea.stat.abbr,
                              maxLines: 1,
                              style: Type.label.copyWith(
                                fontSize: 11,
                                color: idea.stat.color,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        idea.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Type.display.copyWith(fontSize: 18),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: still
                          ? const Duration(milliseconds: 1)
                          : Motion.quick,
                      child: const Icon(
                        Icons.expand_more,
                        size: 20,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: still ? const Duration(milliseconds: 1) : Motion.settle,
            curve: Motion.respond,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          idea.blurb,
                          style: Type.body.copyWith(
                            fontSize: 13.5,
                            height: 1.5,
                            color: Palette.textMid,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final t in idea.quests)
                          _TemplateRow(
                            template: t,
                            activeQuest:
                                widget.activeQuests[_questTitleKey(t.title)],
                            onAdd: widget.onAdd,
                            onRemove: widget.onRemoveQuest,
                            onPersist: widget.onPersist,
                          ),
                        const SizedBox(height: 4),
                        Center(
                          child: Pressable(
                            enabled: !fullyUnderway,
                            soundEnabled: false,
                            pressDepth: fullyUnderway ? 0 : 3,
                            borderRadius: BorderRadius.circular(8),
                            semanticLabel: fullyUnderway
                                ? '${idea.title} goal underway'
                                : widget.adopted
                                ? 'Add missing actions to ${idea.title}'
                                : 'Adopt the whole ${idea.title} goal',
                            onTapUp: fullyUnderway
                                ? null
                                : (_) => widget.onAdopt(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: facetedDecoration(
                                cut: 8,
                                gradient: fullyUnderway
                                    ? null
                                    : Palette.honeyGradient,
                                borderColor: fullyUnderway
                                    ? Palette.success.withValues(alpha: 0.5)
                                    : Colors.transparent,
                              ),
                              child: Text(
                                fullyUnderway
                                    ? 'GOAL UNDERWAY ✓'
                                    : widget.adopted
                                    ? 'ADD MISSING ACTIONS'
                                    : 'ADOPT WHOLE GOAL',
                                style: Type.label.copyWith(
                                  fontSize: 11,
                                  color: fullyUnderway
                                      ? Palette.success
                                      : Palette.onHoney,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// "WHY THIS HELPS" — the research behind a catalog quest, opened from the
/// info-dot on its row. Mirrors the per-stat evidence beat on Me; reads
/// [questWhy] (warm user-facing claim + a real source).
void _showQuestWhy(BuildContext context, QuestTemplate t) {
  final why = questWhy[t.title];
  if (why == null) return;
  Sfx.instance.playMaterial(MaterialSound.glass);
  HapticFeedback.selectionClick();
  showDialog(
    context: context,
    barrierColor: const Color(0xCC140C06),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(28),
      child: GlassPanel(
        tint: const Color(0xF22A211D),
        glow: true,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_stories, size: 14, color: t.stat.color),
                const SizedBox(width: 6),
                Text(
                  'WHY THIS HELPS',
                  style: Type.label.copyWith(fontSize: 11, color: t.stat.color),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(t.title, style: Type.display.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              why.claim,
              style: Type.body.copyWith(
                fontSize: 13,
                height: 1.5,
                color: Palette.textMid,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.menu_book_outlined,
                  size: 11,
                  color: Palette.info,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    why.source,
                    style: Type.label.copyWith(
                      fontSize: 11,
                      color: Palette.info,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

enum _TakenQuestAction { changeDay, takeBack }

class _TemplateRow extends StatefulWidget {
  const _TemplateRow({
    required this.template,
    required this.activeQuest,
    required this.onAdd,
    required this.onRemove,
    required this.onPersist,
  });

  final QuestTemplate template;
  final Quest? activeQuest;
  final bool Function(Quest) onAdd;
  final void Function(Quest) onRemove;
  final VoidCallback onPersist;

  @override
  State<_TemplateRow> createState() => _TemplateRowState();
}

class _TemplateRowState extends State<_TemplateRow> {
  Quest? _activeQuest;

  @override
  void initState() {
    super.initState();
    _activeQuest = widget.activeQuest;
  }

  @override
  void didUpdateWidget(covariant _TemplateRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.activeQuest, widget.activeQuest)) {
      _activeQuest = widget.activeQuest;
    }
  }

  Future<_TakenQuestAction?> _showTakenActions(Quest quest) {
    final t = widget.template;
    final weekly = quest.schedule == QuestSchedule.weekly;
    return showModalBottomSheet<_TakenQuestAction>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GlassPanel(
            tint: const Color(0xF22A211D),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ON YOUR QUEST BOARD',
                  style: Type.label.copyWith(fontSize: 11, color: t.stat.color),
                ),
                const SizedBox(height: 5),
                Text(t.title, style: Type.display.copyWith(fontSize: 19)),
                const SizedBox(height: 7),
                Text(
                  weekly
                      ? 'Move it to another day without losing its progress, or take it back from your board.'
                      : 'Take it back from your board now. You can take it on again here whenever you want.',
                  style: Type.body.copyWith(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Palette.textMid,
                  ),
                ),
                const SizedBox(height: 15),
                if (weekly) ...[
                  _QuestManageActionTile(
                    key: const Key('goal-quest-change-day'),
                    icon: Icons.calendar_today_outlined,
                    label: 'CHANGE WEEKLY DAY',
                    detail: weekdayLabel(quest.weekdays),
                    accent: t.stat.color,
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_TakenQuestAction.changeDay),
                  ),
                  const SizedBox(height: 9),
                ],
                _QuestManageActionTile(
                  key: const Key('goal-quest-take-back'),
                  icon: Icons.undo_rounded,
                  label: 'TAKE BACK',
                  detail:
                      'Taking it back removes this quest and its current progress. Undo restores it.',
                  accent: Palette.textLo,
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(_TakenQuestAction.takeBack),
                ),
                const SizedBox(height: 9),
                Semantics(
                  button: true,
                  label: 'Keep ${t.title} on the quest board',
                  onTap: () => Navigator.of(sheetContext).pop(),
                  child: GestureDetector(
                    key: const Key('goal-quest-keep'),
                    excludeFromSemantics: true,
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(sheetContext).pop(),
                    child: Container(
                      alignment: Alignment.center,
                      constraints: const BoxConstraints(minHeight: 46),
                      decoration: facetedDecoration(
                        cut: 8,
                        gradient: Palette.honeyGradient,
                      ),
                      child: Text(
                        'KEEP IT',
                        style: Type.label.copyWith(
                          fontSize: 11,
                          color: Palette.onHoney,
                        ),
                      ),
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

  Future<void> _manageTakenQuest(Quest quest) async {
    Sfx.instance.playMaterial(MaterialSound.glass);
    HapticFeedback.selectionClick();
    final action = await _showTakenActions(quest);
    if (!mounted || action == null) return;

    switch (action) {
      case _TakenQuestAction.changeDay:
        final day = await pickWeekday(
          context,
          accent: widget.template.stat.color,
          questTitle: widget.template.title,
          initial: quest.weekdays.isEmpty ? null : quest.weekdays.first,
        );
        if (!mounted || day == null) return;
        setState(() {
          quest.weekdays = day == 0 ? <int>[] : <int>[day];
        });
        widget.onPersist();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Palette.card,
            duration: const Duration(milliseconds: 1600),
            content: Text(
              '“${widget.template.title}” now lands ${weekdayLabel(quest.weekdays).toLowerCase()}',
              style: Type.body.copyWith(color: Palette.textHi),
            ),
          ),
        );
      case _TakenQuestAction.takeBack:
        final messenger = ScaffoldMessenger.of(context);
        final restoreQuest = widget.onAdd;
        widget.onRemove(quest);
        setState(() => _activeQuest = null);
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Palette.card,
            duration: const Duration(seconds: 4),
            content: Text(
              '“${widget.template.title}” taken back',
              style: Type.body.copyWith(color: Palette.textHi),
            ),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Palette.xpLight,
              onPressed: () {
                if (restoreQuest(quest) && mounted) {
                  setState(() => _activeQuest = quest);
                }
              },
            ),
          ),
        );
    }
  }

  Future<void> _takeOnQuest() async {
    final t = widget.template;
    // Weekly quests ask which day they should land on (the "weekly shot"
    // feedback) — default-selected to today.
    Quest quest;
    if (t.schedule == QuestSchedule.weekly) {
      final day = await pickWeekday(
        context,
        accent: t.stat.color,
        questTitle: t.title,
      );
      if (day == null) return; // dismissed → don't adopt
      quest = t.build(weekdays: day == 0 ? const [] : [day]);
    } else {
      quest = t.build();
    }
    // A laddered quest asks where you're starting, the same one-question
    // posture as the weekly day. Payout moves with the chosen rung (the
    // night-rise coupling), so a higher start earns like a risen quest.
    final ladder = quest.ladder;
    if (ladder != null && ladder.length > 1) {
      if (!mounted) return;
      final rung = await pickRung(
        context,
        accent: t.stat.color,
        questTitle: t.title,
        ladder: ladder,
        initial: quest.rung,
      );
      if (rung == null) return; // dismissed → don't adopt
      quest.difficulty = (quest.difficulty + (rung - quest.rung)).clamp(1, 10);
      quest.rung = rung;
    }
    if (!mounted) return;
    final ok = widget.onAdd(quest);
    if (ok) {
      setState(() => _activeQuest = quest);
      Sfx.instance.playInteraction(InteractionSound.place);
      HapticFeedback.selectionClick();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.card,
        duration: const Duration(milliseconds: 1400),
        content: Text(
          ok ? '“${t.title}” taken on ⚔️' : 'Already on your quest list',
          style: Type.body.copyWith(color: Palette.textHi),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    final activeQuest = _activeQuest;
    final taken = activeQuest != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        t.title,
                        style: Type.body.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Palette.textHi,
                        ),
                      ),
                    ),
                    // tap to learn the research behind this habit
                    if (questWhy.containsKey(t.title)) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _showQuestWhy(context, t),
                        behavior: HitTestBehavior.opaque,
                        child: Icon(
                          Icons.info_outline,
                          size: 13,
                          color: t.stat.color.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    _MiniChip(
                      label: activeQuest == null
                          ? t.schedule.label
                          : activeQuest.schedule == QuestSchedule.weekly
                          ? weekdayLabel(activeQuest.weekdays).toUpperCase()
                          : activeQuest.schedule.label,
                    ),
                    if (t.timerMinutes > 0)
                      _MiniChip(
                        label: '⏱ ${t.timerMinutes}M',
                        color: Palette.verify,
                      ),
                    if (t.allDay)
                      const _MiniChip(
                        label: 'CHECKS AT NIGHT',
                        color: Palette.unlock,
                      ),
                    if (t.dread)
                      const _MiniChip(
                        label: 'COUNTS EXTRA',
                        color: Palette.dread,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            enabled: true,
            label: taken
                ? 'Manage ${t.title}, currently taken'
                : 'Take on ${t.title}',
            onTap: taken ? () => _manageTakenQuest(activeQuest) : _takeOnQuest,
            child: GestureDetector(
              key: ValueKey<String>(
                'goal-quest-${taken ? 'manage' : 'take'}-${_questTitleKey(t.title)}',
              ),
              excludeFromSemantics: true,
              behavior: HitTestBehavior.opaque,
              onTap: taken
                  ? () => _manageTakenQuest(activeQuest)
                  : _takeOnQuest,
              child: AnimatedContainer(
                duration: Motion.quick,
                alignment: Alignment.center,
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: facetedDecoration(
                  cut: 7,
                  gradient: taken ? null : Palette.honeyGradient,
                  borderColor: taken
                      ? Palette.success.withValues(alpha: 0.5)
                      : Colors.transparent,
                ),
                child: Text(
                  taken ? 'TAKEN · EDIT' : 'TAKE ON',
                  style: Type.label.copyWith(
                    fontSize: 11,
                    color: taken ? Palette.success : Palette.onHoney,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestManageActionTile extends StatelessWidget {
  const _QuestManageActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.detail,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $detail',
      onTap: onTap,
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: facetedDecoration(
            cut: 9,
            color: Palette.glassFill,
            borderColor: accent.withValues(alpha: 0.45),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Type.label.copyWith(fontSize: 11, color: accent),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: Type.body.copyWith(
                        fontSize: 12.5,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Palette.textLo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Palette.textLo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: facetedDecoration(
        cut: 4,
        color: Colors.transparent,
        borderColor: c.withValues(alpha: 0.4),
      ),
      child: Text(label, style: Type.label.copyWith(fontSize: 11, color: c)),
    );
  }
}
