import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../clock.dart';
import '../engine.dart';
import '../goal_planner.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/ember_sheet.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/goal_action_card.dart';
import '../widgets/goal_route_panel.dart';
import '../widgets/goal_world.dart';
import '../widgets/honey_button.dart';
import '../widgets/luxe_depth.dart';
import '../widgets/notes_sheet.dart';
import '../widgets/pressable.dart';

String _goalTitleKey(String title) => title.trim().toLowerCase();

const _goalRoomTextShadows = <Shadow>[
  Shadow(color: Color(0xD8100906), blurRadius: 10, offset: Offset(0, 2)),
  Shadow(color: Color(0x86100906), blurRadius: 3, offset: Offset(0, 1)),
];

String? _keptGoalText(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

class _GoalDetailHeading extends StatelessWidget {
  const _GoalDetailHeading({
    required this.goal,
    required this.accent,
    required this.onBack,
  });

  final Goal goal;
  final Color accent;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      goal.title,
      textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.45),
      style: Type.display.copyWith(
        fontSize: 25,
        height: 1.04,
        fontWeight: FontWeight.w500,
        color: Palette.textHi,
        shadows: const [
          Shadow(
            color: Color(0xD9000000),
            blurRadius: 15,
            offset: Offset(0, 3),
          ),
        ],
      ),
    );
    final livingTitle = title;
    final kind = goal.complete
        ? 'Kept in your history'
        : goal.kind == GoalKind.become
        ? 'A practice you return to'
        : 'A finish line you are moving toward';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Pressable(
          key: const Key('goal-detail-back'),
          material: MaterialSound.glass,
          pressDepth: 1.5,
          edgeColor: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          guardRapidReentry: true,
          semanticLabel: 'Back to Goals',
          semanticHint: 'Return to the Goals room.',
          onTapUp: (_) => onBack(),
          stateBuilder: (context, child, pressed, focused, hovered) =>
              AnimatedContainer(
                duration: pressed ? Duration.zero : Motion.ack,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: pressed
                      ? const Color(0xC2261912)
                      : focused || hovered
                      ? const Color(0xA51F1611)
                      : const Color(0x7818110D),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: focused
                        ? Palette.xpLight.withValues(alpha: 0.78)
                        : const Color(0x4AAB8257),
                  ),
                  boxShadow: pressed
                      ? const []
                      : const [
                          BoxShadow(
                            color: Color(0x42100805),
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          ),
                        ],
                ),
                child: AnimatedSlide(
                  offset: pressed ? const Offset(-0.06, 0) : Offset.zero,
                  duration: pressed ? Duration.zero : Motion.ack,
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Palette.textHi,
                  ),
                ),
              ),
          child: const SizedBox(width: 44, height: 44),
        ),
        const SizedBox(width: 3),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                livingTitle,
                const SizedBox(height: 7),
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 1,
                      color: accent.withValues(alpha: 0.78),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        kind,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Type.body.copyWith(
                          fontSize: 11.5,
                          height: 1.2,
                          letterSpacing: 0.15,
                          color: Palette.textMid,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A goal's "character sheet" (round-20): tap an adopted goal to open this —
/// a progress ring, the cool stats being kept track of, the quests serving the
/// goal, and a quiet way to abandon it. Read-only; completion lives on the
/// Quests board. The page accent is the goal's stat colour (honey once achieved).
class GoalDetailScreen extends StatelessWidget {
  const GoalDetailScreen({
    super.key,
    required this.goal,
    required this.state,
    required this.quests,
    required this.onRemoveGoal,
    required this.onPersist,
    required this.onAddQuest,
    required this.onOpenQuest,
    this.onStartFallback,
    this.onAdjustPlan,
    this.onOpenWorkshop,
    this.light,
  });

  final Goal goal;
  final GameState state;

  /// The live board quests — the ones serving this goal are filtered by title.
  final List<Quest> quests;
  final void Function(Goal goal) onRemoveGoal;

  /// Persists the save after a journal edit.
  final VoidCallback onPersist;

  /// Adds a quest — used by the journal's "make this a quest".
  final bool Function(Quest quest) onAddQuest;

  /// Returns to the shared Quest board with this exact action in focus.
  final void Function(Quest quest) onOpenQuest;
  final ValueChanged<String>? onStartFallback;
  final VoidCallback? onAdjustPlan;
  final VoidCallback? onOpenWorkshop;
  final ValueListenable<Offset>? light;

  Color get _accent => goal.complete ? Palette.xpLight : goal.stat.color;

  /// The ring fill: a true 0→1 finish-line for ACHIEVE; for BECOME, the fill
  /// within the current tier (toward the next milestone) so it ascends rather
  /// than sitting near-full forever.
  /// Start-of-current-tier progress (0 before the first milestone). The ring
  /// and the centre number share this so the arc and the digits always agree.
  int get _tierBase => goal.milestones == 0 ? 0 : goal.target ~/ 2;

  double get _ringValue {
    if (goal.complete) return 1;
    if (goal.kind == GoalKind.achieve) return goal.fraction;
    final span = goal.target - _tierBase;
    if (span <= 0) return 0;
    return ((goal.progress - _tierBase) / span).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) => _buildBody(context),
  );

  Widget _buildBody(BuildContext context) {
    final related = quests
        .where(
          (q) =>
              q.goalTitle != null &&
              _goalTitleKey(q.goalTitle!) == _goalTitleKey(goal.title),
        )
        .toList(growable: false);
    final now = Clock.now();
    final todayKey = Days.key(now);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    // Only quests actually actionable today belong in the DONE-TODAY
    // denominator: a quest snoozed for today, or a habit not scheduled today
    // (e.g. a M/W/F habit on a Tuesday), can't be cleared today — counting it
    // would leave the ring stuck short and quietly scold. They still show in
    // the list below as goal members.
    final activeToday = related
        .where(
          (q) =>
              q.snoozedDay != todayKey &&
              (q.isEvent
                  ? !q.dueDate!.isAfter(endOfToday)
                  : q.scheduledOn(now)),
        )
        .toList(growable: false);
    final doneToday = activeToday.where((q) => q.doneFor(now)).length;
    final days = goal.startedDay == null
        ? null
        : math.max(1, Days.between(Days.parse(goal.startedDay!), now) + 1);
    final actionable =
        activeToday
            .where((quest) => !quest.doneFor(now))
            .toList(growable: false)
          ..sort((a, b) {
            final priority = a
                .priorityRankOn(now)
                .compareTo(b.priorityRankOn(now));
            if (priority != 0) return priority;
            return a.difficulty.compareTo(b.difficulty);
          });
    final decision = GoalPlanner.decide(goal, related, now);
    final next =
        decision?.quest ?? (actionable.isEmpty ? null : actionable.first);
    final surface = MediaQuery.sizeOf(context);
    final compactWorld =
        surface.width < 360 ||
        surface.height < 700 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final lightField =
        light ?? const AlwaysStoppedAnimation<Offset>(Offset.zero);

    return Scaffold(
      backgroundColor: const Color(0xFF100D0B),
      body: LuxePageList(
        assetPath: goalsRoomKitchenAsset,
        title: '',
        subtitle: '',
        icon: Icons.explore_outlined,
        parallax: lightField,
        reduceMotion: state.reduceMotion,
        heroHeight: surface.height + (compactWorld ? 0 : 28),
        headingTop: compactWorld ? 10 : 16,
        heroAlignment: Alignment.center,
        heroScale: compactWorld ? 1.015 : goalsRoomKitchenScale,
        heroScrim: goalsKitchenDetailScrim,
        contentSafeArea: true,
        bodyTextureAsset: 'assets/room/wall_grain.png',
        heading: _GoalDetailHeading(
          goal: goal,
          accent: _accent,
          onBack: () => Navigator.of(context).pop(),
        ),
        children: [
          SizedBox(height: largeText ? 150 : (compactWorld ? 72 : 224)),
          _currentAction(context, next, related, decision),
          if (goal.plan != null && onAdjustPlan != null) ...[
            const SizedBox(height: 22),
            GoalRoutePanel(goal: goal, onAdjust: onAdjustPlan!),
          ] else if (onAdjustPlan != null) ...[
            const SizedBox(height: 22),
            GoalRouteBuilderPrompt(
              accent: goal.stat.color,
              onBuild: onAdjustPlan!,
            ),
          ],
          const SizedBox(height: 26),
          _livingEvidence(
            context,
            related.length,
            doneToday,
            activeToday.length,
            days,
          ),
          const SizedBox(height: 24),
          _GoalSupportPanel(
            goal: goal,
            state: state,
            accent: _accent,
            onPersist: onPersist,
          ),
          const SizedBox(height: 22),
          JournalPanel(
            title: goal.title,
            accent: _accent,
            subtitle: 'proof and moments you want to keep',
            emptyPreview:
                'Keep one concrete moment, change, or thing you learned here.',
            emptyHint:
                'No proof notes yet. Keep one concrete moment, change, or thing you learned here.',
            read: () => goal.notes,
            onAdd: (text) {
              final mark = goal.complete
                  ? 'done'
                  : goal.kind == GoalKind.achieve
                  ? '${goal.progress}/${goal.target}'
                  : goal.milestones == 0
                  ? 'starting out'
                  : 'milestone ${goal.milestones}';
              goal.notes = goal.notes.withNote(
                text,
                Clock.now(),
                context: mark,
              );
              onPersist();
            },
            onDelete: (n) {
              goal.notes = goal.notes.without(n);
              onPersist();
            },
            onEdit: (orig, text) {
              goal.notes = goal.notes.replacing(
                orig.copyWith(text: text, editedAt: Clock.now()),
              );
              onPersist();
            },
            onMakeQuest: (text) async {
              final q = await showEmberSheet(
                context,
                EmberSheetConfig(
                  surface: EmberSurface.goal,
                  defaultTitle: text,
                  defaultStat: goal.stat,
                  lockStat: true,
                  goalTitle: goal.title,
                  accent: _accent,
                ),
              );
              if (q != null) onAddQuest(q);
            },
          ),
          const SizedBox(height: 18),
          _relatedPanel(context, related, now, doneToday, activeToday.length),
          const SizedBox(height: 24),
          _abandonLink(context),
        ],
      ),
    );
  }

  Widget _currentAction(
    BuildContext context,
    Quest? next,
    List<Quest> related,
    GoalActionDecision? decision,
  ) {
    if (goal.complete) {
      return Semantics(
        container: true,
        label: '${goal.title} is kept in your history.',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 22,
                color: Palette.xpLight,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Kept in your history',
                  style: Type.display.copyWith(
                    fontSize: 21,
                    color: Palette.textHi,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final fallback = _keptGoalText(goal.fallbackAction);
    final cue = _keptGoalText(goal.fallbackCue);
    final title =
        decision?.actionTitle ??
        next?.displayTitle ??
        fallback ??
        (related.isEmpty
            ? 'Choose one action small enough to begin'
            : 'Make the next step easier to return to');
    final label = decision != null
        ? decision.quest == null && onOpenWorkshop != null
              ? 'Fit this cut'
              : decision.ctaLabel
        : next != null
        ? 'Open this Quest'
        : fallback != null
        ? 'Do the lighter version'
        : 'Add one small action';
    final cueCopy = decision != null
        ? decision.whyThisOne
        : next != null
        ? 'Today, if you can'
        : cue == null
        ? 'Whenever you are ready'
        : 'When $cue';
    void open() {
      if (decision != null) {
        if (decision.quest == null && onOpenWorkshop != null) {
          onOpenWorkshop!();
          return;
        }
        final quest =
            decision.quest ?? GoalPlanner.questFor(goal, decision, Clock.now());
        if (decision.quest == null && !onAddQuest(quest)) {
          final existing = related.where(
            (candidate) =>
                candidate.goalPlanStepId == decision.step.id &&
                candidate.goalPlanRevision == decision.plan.revision &&
                (candidate.goalPlanAttempt ?? 1) ==
                    decision.step.completions + 1 &&
                GoalPlanner.questActionableToday(candidate, Clock.now()) &&
                !candidate.doneFor(Clock.now()),
          );
          if (existing.isEmpty) return;
          Navigator.of(context).pop();
          onOpenQuest(existing.first);
          return;
        }
        Navigator.of(context).pop();
        onOpenQuest(quest);
      } else if (next != null) {
        Navigator.of(context).pop();
        onOpenQuest(next);
      } else if (fallback != null && onStartFallback != null) {
        Navigator.of(context).pop();
        onStartFallback!(fallback);
      } else {
        _addQuest(context, defaultTitle: fallback);
      }
    }

    final card = GoalActionCard(
      identityIcon: goal.stat.icon,
      accent: _accent,
      eyebrow: decision != null
          ? 'WHY THIS ONE  ·  ${decision.routePosition}'
          : next != null
          ? 'THE NEXT TRUE THING'
          : fallback != null
          ? 'Counts toward this goal'
          : 'ONE SMALL START',
      title: title,
      actionLabel: label,
      actionIcon: next == null && fallback == null
          ? Icons.add_rounded
          : Icons.arrow_forward_rounded,
      buttonKey: const Key('goal-detail-current-action'),
      onTap: open,
      fullWidthButton: true,
      light: light,
      reduceMotion: state.reduceMotion,
    );
    final still =
        state.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final livingCard = still
        ? card
        : Hero(
            tag: goalActionHeroTag(goal.title),
            transitionOnUserGestures: true,
            flightShuttleBuilder: goalActionFlightShuttleBuilder,
            child: Material(type: MaterialType.transparency, child: card),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.schedule_outlined,
              size: 18,
              color: Palette.xpLight.withValues(alpha: 0.86),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                cueCopy,
                style: Type.body.copyWith(
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.12,
                  color: Palette.xpLight,
                  shadows: _goalRoomTextShadows,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        livingCard,
      ],
    );
  }

  Widget _livingEvidence(
    BuildContext context,
    int active,
    int doneToday,
    int doneDenom,
    int? days,
  ) {
    final remaining = (goal.target - goal.progress).clamp(0, goal.target);
    final milestone = goal.complete
        ? 'Reached ${relativeWhen(Days.parse(goal.achievedDay!))}'
        : goal.kind == GoalKind.achieve
        ? '$remaining more ${remaining == 1 ? 'action' : 'actions'} until the finish'
        : '$remaining more ${remaining == 1 ? 'action' : 'actions'} until the next marker';
    final evidence = goal.complete
        ? 'You kept this in your history.'
        : goal.progress == 0
        ? 'Your first return will live here.'
        : 'You have found your way back ${goal.progress} ${goal.progress == 1 ? 'time' : 'times'}.';
    return Semantics(
      container: true,
      label:
          '$evidence $milestone. $doneToday of $doneDenom done today. $active linked quests.',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Proof you’ve been here',
              style: Type.body.copyWith(
                fontSize: 13,
                height: 1.2,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.12,
                color: _accent,
                shadows: _goalRoomTextShadows,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              evidence,
              style: Type.display.copyWith(
                fontSize: 25,
                height: 1.1,
                fontWeight: FontWeight.w400,
                color: Palette.textHi,
                shadows: _goalRoomTextShadows,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              milestone,
              style: Type.body.copyWith(
                fontSize: 13,
                height: 1.35,
                color: Palette.textLo,
                shadows: _goalRoomTextShadows,
              ),
            ),
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Container(
                height: 5,
                color: Palette.brassDeep.withValues(alpha: 0.38),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: _ringValue,
                  child: SizedBox.expand(
                    child: ColoredBox(color: _accent.withValues(alpha: 0.78)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 11),
            Wrap(
              spacing: 8,
              runSpacing: 5,
              children: [
                Text(
                  '$doneToday of $doneDenom today',
                  style: Type.body.copyWith(
                    fontSize: 12,
                    color: Palette.textMid,
                  ),
                ),
                Text('·', style: Type.body.copyWith(color: Palette.textLo)),
                Text(
                  '$active linked ${active == 1 ? 'quest' : 'quests'}',
                  style: Type.body.copyWith(
                    fontSize: 12,
                    color: Palette.textMid,
                  ),
                ),
                if (days != null) ...[
                  Text('·', style: Type.body.copyWith(color: Palette.textLo)),
                  Text(
                    '$days days here',
                    style: Type.body.copyWith(
                      fontSize: 12,
                      color: Palette.textMid,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── quests serving this goal ──────────────────────────────────────
  Future<void> _addQuest(BuildContext context, {String? defaultTitle}) async {
    Sfx.instance.playMaterial(MaterialSound.glass);
    final quest = await showEmberSheet(
      context,
      EmberSheetConfig(
        surface: EmberSurface.goal,
        defaultTitle: defaultTitle,
        defaultStat: goal.stat,
        lockStat: true,
        goalTitle: goal.title,
        accent: _accent,
      ),
    );
    if (quest == null || !context.mounted) return;
    final added = onAddQuest(quest);
    if (added) Sfx.instance.play('streak');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.card,
        content: Text(
          added
              ? '“${quest.displayTitle}” now moves this goal'
              : 'That quest is already on your board',
          style: Type.body.copyWith(color: Palette.textHi),
        ),
      ),
    );
  }

  Widget _relatedPanel(
    BuildContext context,
    List<Quest> related,
    DateTime now,
    int doneToday,
    int denom,
  ) {
    final sorted = [...related]
      ..sort((a, b) {
        final ad = a.doneFor(now) ? 1 : 0;
        final bd = b.doneFor(now) ? 1 : 0;
        return ad.compareTo(bd); // undone first, handled-today sink lower
      });
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Quests serving this goal',
                  overflow: TextOverflow.ellipsis,
                  style: Type.display.copyWith(
                    fontSize: 19,
                    color: Palette.textMid,
                  ),
                ),
              ),
              if (related.isNotEmpty)
                Text(
                  '$doneToday of $denom today',
                  style: Type.body.copyWith(
                    fontSize: 12,
                    color: Palette.textLo,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: Palette.brassDeep.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 4),
          if (sorted.isEmpty)
            Text(
              'No quests feed this goal yet. Add one small action to give it somewhere to move.',
              style: Type.body.copyWith(
                fontSize: 13.5,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            )
          else
            for (var index = 0; index < sorted.length; index++) ...[
              _questRow(context, sorted[index], sorted[index].doneFor(now)),
              if (index < sorted.length - 1)
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(left: 20),
                  color: Palette.brassDeep.withValues(alpha: 0.34),
                ),
            ],
          if (!goal.complete) ...[
            const SizedBox(height: 12),
            Pressable(
              key: const Key('goal-detail-add-quest'),
              material: MaterialSound.glass,
              soundEnabled: false,
              pressDepth: 1.5,
              borderRadius: BorderRadius.circular(10),
              edgeColor: Colors.transparent,
              guardRapidReentry: true,
              semanticLabel: sorted.isEmpty
                  ? 'Add the first quest to this goal'
                  : 'Add another quest to this goal',
              onTapUp: (_) => _addQuest(context),
              stateBuilder: (context, child, pressed, focused, hovered) =>
                  AnimatedContainer(
                    duration: pressed ? Duration.zero : Motion.ack,
                    curve: Motion.respond,
                    decoration: BoxDecoration(
                      color: pressed
                          ? _accent.withValues(alpha: 0.10)
                          : focused || hovered
                          ? const Color(0xAA241A13)
                          : const Color(0x9219130F),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _accent.withValues(
                          alpha: pressed || focused ? 0.52 : 0.38,
                        ),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x5C0E0906),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: child,
                  ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: _accent),
                    const SizedBox(width: 7),
                    Text(
                      sorted.isEmpty
                          ? 'Add the first Quest'
                          : 'Add another Quest',
                      style: Type.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Palette.textHi,
                        shadows: _goalRoomTextShadows,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _questRow(BuildContext context, Quest q, bool done) {
    return Opacity(
      opacity: done ? 0.6 : 1,
      child: Pressable(
        key: ValueKey('goal-detail-quest-${q.title}'),
        material: MaterialSound.parchment,
        soundEnabled: false,
        pressDepth: 1.5,
        borderRadius: BorderRadius.circular(8),
        edgeColor: Colors.transparent,
        guardRapidReentry: true,
        semanticLabel:
            '${q.displayTitle}. ${done ? 'Completed for this period' : 'Open on Quests'}',
        semanticHint: 'Returns to the Quest board.',
        onTapUp: (_) {
          Navigator.of(context).pop();
          onOpenQuest(q);
        },
        stateBuilder: (context, child, pressed, focused, hovered) =>
            AnimatedContainer(
              duration: pressed ? Duration.zero : Motion.ack,
              curve: Motion.respond,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    q.stat.color.withValues(
                      alpha: pressed
                          ? 0.10
                          : focused || hovered
                          ? 0.05
                          : 0.0,
                    ),
                    Colors.transparent,
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: AnimatedSlide(
                offset: pressed ? const Offset(0.009, 0) : Offset.zero,
                duration: pressed ? Duration.zero : Motion.ack,
                child: child,
              ),
            ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Transform.rotate(
                angle: 0.785,
                child: Container(width: 7, height: 7, color: q.stat.color),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.displayTitle,
                      overflow: TextOverflow.ellipsis,
                      style: Type.body.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Palette.textHi,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        _chip(q.schedule.label),
                        if (q.effectiveTimerMinutes > 0)
                          _chip(
                            '⏱ ${q.effectiveTimerMinutes}M',
                            Palette.verify,
                          ),
                        if (q.allDay) _chip('CHECKS AT NIGHT', Palette.unlock),
                        if (q.dread) _chip('COUNTS EXTRA', Palette.dread),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                done ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: done
                    ? Palette.success
                    : q.stat.color.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: Palette.textLo,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, [Color? color]) {
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

  // ── abandon (the existing two-step warm confirm) ──────────────────
  Widget _abandonLink(BuildContext context) {
    // Deliberately understated and gated behind a long-press — quitting a goal
    // shouldn't feel like a casual one-tap button (owner feedback).
    final label = goal.complete
        ? 'Hold to retire this goal'
        : 'Hold to let this goal go';
    return Semantics(
      button: true,
      label: label,
      hint: 'Long press to review this choice.',
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () => _confirmAbandon(context),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xA618110D),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0x4A9E7950)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x5C0E0906),
                    blurRadius: 9,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Text(
                  label,
                  style: Type.label.copyWith(
                    fontSize: 11,
                    letterSpacing: 0.55,
                    color: Palette.textMid,
                    shadows: _goalRoomTextShadows,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmAbandon(BuildContext context) {
    Sfx.instance.playMaterial(MaterialSound.glass);
    HapticFeedback.selectionClick();
    var armed = false;
    showDialog(
      context: context,
      barrierColor: const Color(0xCC140C06),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => Dialog(
          backgroundColor: Colors.transparent,
          child: GlassPanel(
            tint: const Color(0xF22A211D),
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Abandon “${goal.title}”?',
                  textAlign: TextAlign.center,
                  style: Type.display.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 6),
                Text(
                  'The goal and every quest serving it leave the board.',
                  textAlign: TextAlign.center,
                  style: Type.body.copyWith(
                    fontSize: 13.5,
                    color: Palette.textMid,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
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
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        if (!armed) {
                          Sfx.instance.playMaterial(MaterialSound.glass);
                          setDialog(() => armed = true);
                          return;
                        }
                        Sfx.instance.play('boing');
                        Navigator.of(ctx).pop(); // close confirm
                        onRemoveGoal(goal);
                        Navigator.of(context).maybePop(); // leave the detail
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
                        decoration: facetedDecoration(
                          cut: 8,
                          color: Colors.transparent,
                          borderColor: const Color(
                            0xFFE89090,
                          ).withValues(alpha: armed ? 1 : 0.5),
                        ),
                        child: Text(
                          armed ? 'TAP AGAIN' : 'ABANDON',
                          style: Type.label.copyWith(
                            fontSize: 11,
                            color: const Color(0xFFE89090),
                          ),
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
    );
  }
}

class _GoalSupportPanel extends StatefulWidget {
  const _GoalSupportPanel({
    required this.goal,
    required this.state,
    required this.accent,
    required this.onPersist,
  });

  final Goal goal;
  final GameState state;
  final Color accent;
  final VoidCallback onPersist;

  @override
  State<_GoalSupportPanel> createState() => _GoalSupportPanelState();
}

class _GoalSupportPanelState extends State<_GoalSupportPanel> {
  static String? _clean(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? get _why {
    final value = widget.goal.why?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? get _fallbackCue {
    final cue = widget.goal.fallbackCue?.trim();
    return cue == null || cue.isEmpty ? null : cue;
  }

  String? get _fallbackAction {
    final action = widget.goal.fallbackAction?.trim();
    return action == null || action.isEmpty ? null : action;
  }

  String get _cueCopy => _fallbackCue == null
      ? 'When the usual plan feels too large'
      : 'When ${_fallbackCue!}';

  String get _actionCopy =>
      _fallbackAction ?? 'Choose a smaller version that still counts.';

  String get _hardDayCopy => '$_cueCopy. $_actionCopy';

  Future<void> _edit() async {
    Sfx.instance.playMaterial(MaterialSound.glass);
    HapticFeedback.selectionClick();
    final saved = await showModalBottomSheet<_GoalSupportResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Palette.dialogBarrier,
      builder: (_) => _GoalSupportSheet(
        accent: widget.accent,
        initialWhy: widget.goal.why ?? '',
        initialCue: widget.goal.fallbackCue ?? '',
        initialAction: widget.goal.fallbackAction ?? '',
      ),
    );
    if (saved != null && mounted) {
      widget.state.updateGoalSupport(
        widget.goal,
        why: _clean(saved.why),
        fallbackCue: _clean(saved.cue),
        fallbackAction: _clean(saved.action),
      );
      widget.onPersist();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      key: const Key('goal-support-plan'),
      material: MaterialSound.parchment,
      soundEnabled: false,
      pressDepth: 1,
      borderRadius: BorderRadius.circular(8),
      edgeColor: Colors.transparent,
      guardRapidReentry: true,
      semanticLabel:
          'Your return plan. Why this matters: ${_why ?? 'Not added yet'}. When the day shrinks: $_hardDayCopy',
      semanticHint: 'Edit your reason and a smaller fallback plan.',
      onTapUp: (_) => _edit(),
      stateBuilder: (context, child, pressed, focused, hovered) =>
          AnimatedContainer(
            duration: pressed ? Duration.zero : Motion.ack,
            decoration: BoxDecoration(
              color: pressed
                  ? widget.accent.withValues(alpha: 0.07)
                  : focused || hovered
                  ? widget.accent.withValues(alpha: 0.035)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: child,
          ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 8, 5, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'YOUR RETURN PLAN',
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
                      letterSpacing: 1.25,
                      color: widget.accent,
                      shadows: _goalRoomTextShadows,
                    ),
                  ),
                ),
                Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: widget.accent.withValues(alpha: 0.78),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _why ?? 'Add the reason that makes this yours. It can change.',
              style: Type.display.copyWith(
                fontSize: 18,
                height: 1.18,
                fontWeight: FontWeight.w400,
                color: _why == null ? Palette.textMid : Palette.textHi,
                fontStyle: _why == null ? FontStyle.italic : FontStyle.normal,
                shadows: _goalRoomTextShadows,
              ),
            ),
            const SizedBox(height: 13),
            Container(
              height: 1,
              color: Palette.brassDeep.withValues(alpha: 0.34),
            ),
            const SizedBox(height: 10),
            Text(
              'When the day shrinks',
              style: Type.body.copyWith(
                fontSize: 13,
                height: 1.2,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.12,
                color: widget.accent.withValues(alpha: 0.9),
                shadows: _goalRoomTextShadows,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _cueCopy,
              style: Type.body.copyWith(
                fontSize: 13.5,
                height: 1.32,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
                shadows: _goalRoomTextShadows,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _actionCopy,
              style: Type.body.copyWith(
                fontSize: 14.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: Palette.textHi,
                shadows: _goalRoomTextShadows,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalSupportResult {
  const _GoalSupportResult({
    required this.why,
    required this.cue,
    required this.action,
  });

  final String why;
  final String cue;
  final String action;
}

class _GoalSupportSheet extends StatefulWidget {
  const _GoalSupportSheet({
    required this.accent,
    required this.initialWhy,
    required this.initialCue,
    required this.initialAction,
  });

  final Color accent;
  final String initialWhy;
  final String initialCue;
  final String initialAction;

  @override
  State<_GoalSupportSheet> createState() => _GoalSupportSheetState();
}

class _GoalSupportSheetState extends State<_GoalSupportSheet> {
  late String _why;
  late String _cue;
  late String _action;

  @override
  void initState() {
    super.initState();
    _why = widget.initialWhy;
    _cue = widget.initialCue;
    _action = widget.initialAction;
  }

  void _save() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(
      context,
    ).pop(_GoalSupportResult(why: _why, cue: _cue, action: _action));
  }

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: Type.body.copyWith(color: Palette.textLo, fontSize: 14),
    filled: true,
    fillColor: const Color(0xFF130E0B),
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: BorderSide(color: Palette.brassDeep.withValues(alpha: 0.7)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: BorderSide(color: widget.accent.withValues(alpha: 0.9)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 10, 12, keyboard + 12),
      child: SingleChildScrollView(
        child: GlassPanel(
          tint: const Color(0xFC211812),
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 17),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Palette.brass.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 13),
              Text(
                'MAKE THIS EASIER TO RETURN TO',
                style: Type.label.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 1.25,
                  color: widget.accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your reason. Your smaller version.',
                style: Type.display.copyWith(fontSize: 21, height: 1.08),
              ),
              const SizedBox(height: 6),
              Text(
                'All of this is optional. Change it whenever the goal changes.',
                style: Type.body.copyWith(
                  fontSize: 13,
                  height: 1.35,
                  color: Palette.textMid,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'WHY DOES THIS MATTER TO YOU?  ·  OPTIONAL',
                style: Type.label.copyWith(fontSize: 10, color: Palette.textLo),
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('goal-support-why'),
                initialValue: _why,
                onChanged: (value) => _why = value,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                maxLines: 2,
                style: Type.body.copyWith(fontSize: 15, color: Palette.textHi),
                decoration: _decoration('What would this make easier?'),
              ),
              const SizedBox(height: 13),
              Text(
                'WHEN THE USUAL PLAN GETS HARD…  ·  OPTIONAL',
                style: Type.label.copyWith(fontSize: 10, color: Palette.textLo),
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('goal-support-cue'),
                initialValue: _cue,
                onChanged: (value) => _cue = value,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                style: Type.body.copyWith(fontSize: 15, color: Palette.textHi),
                decoration: _decoration('e.g. I get home exhausted'),
              ),
              const SizedBox(height: 9),
              TextFormField(
                key: const Key('goal-support-action'),
                initialValue: _action,
                onChanged: (value) => _action = value,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                style: Type.body.copyWith(fontSize: 15, color: Palette.textHi),
                decoration: _decoration(
                  'I can still… e.g. clear one small surface',
                ),
              ),
              const SizedBox(height: 17),
              HoneyButton(
                key: const Key('goal-support-save'),
                label: 'KEEP THIS PLAN',
                icon: Icons.check_rounded,
                expand: true,
                glow: false,
                onTap: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
