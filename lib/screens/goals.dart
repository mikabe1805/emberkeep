import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../clock.dart';
import '../content/goal_catalog.dart';
import '../content/routines.dart';
import '../engine.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/day_picker.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/luxe_depth.dart';
import 'goal_detail.dart';
import 'goal_wizard.dart';
import 'momentum_kits.dart';

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

/// "Take on quests!" — goal discovery. Every routine quest belongs to a
/// goal (the why stays attached, round-7): begin your own via the Oath
/// Wizard, or adopt a curated goal whole. One-time plans live on the
/// calendar.
class GoalsPage extends StatelessWidget {
  const GoalsPage({
    super.key,
    required this.state,
    required this.onAdd,
    required this.activeTitles,
    required this.onRemoveGoal,
    required this.onPersist,
    required this.quests,
    required this.onOpenQuests,
    this.parallax = const AlwaysStoppedAnimation(Offset.zero),
    this.lightDirection,
  });

  final GameState state;

  /// Returns false when a same-titled quest is already on the list.
  final bool Function(Quest quest) onAdd;

  /// Titles already on the quest list (disables duplicate take-ons).
  final Set<String> activeTitles;

  /// Abandons a goal and clears its linked quests.
  final void Function(Goal goal) onRemoveGoal;

  /// Persists the save — used when a goal's journal changes in the detail view.
  final VoidCallback onPersist;

  /// The live board quests — threaded to the goal-detail view (quests serving it).
  final List<Quest> quests;

  /// Leaves this discovery tab and opens the shared board after a kit is lit.
  final VoidCallback onOpenQuests;
  final ValueListenable<Offset> parallax;
  final ValueListenable<Offset>? lightDirection;

  void _openWizard(BuildContext context) {
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GoalWizardScreen(state: state, onAdd: onAdd),
      ),
    );
  }

  void _adoptGoal(BuildContext context, GoalIdea idea) {
    final created = state.addGoal(
      Goal(title: idea.title, stat: idea.stat, target: 25),
    );
    var added = 0;
    // Whole-goal adopt: don't stack a modal per weekly quest — anchor each
    // weekly to today by default (editable later via the quest's tune sheet).
    final today = Clock.now().weekday;
    for (final t in idea.quests) {
      final q = t.schedule == QuestSchedule.weekly
          ? t.build(goalTitle: idea.title, weekdays: [today])
          : t.build(goalTitle: idea.title);
      if (onAdd(q)) added++;
    }
    Sfx.instance.play(created || added > 0 ? 'levelup' : 'boing');
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.card,
        content: Text(
          created
              ? 'Goal “${idea.title}” begun — $added quests taken on ⚔️'
              : 'Goal already underway',
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
        final catalog = _catalogSections(context);
        return LuxePageList(
          assetPath: 'assets/pages/goals-desk-v2.webp',
          title: 'Goals',
          subtitle: 'what you’re building toward',
          icon: Icons.explore_outlined,
          parallax: parallax,
          reduceMotion: state.reduceMotion,
          children: [
            LuxeGoldButton(
              label: 'Begin a new goal',
              icon: Icons.add_rounded,
              onTap: () => _openWizard(context),
              parallax: lightDirection ?? parallax,
            ),
            const SizedBox(height: 20),
            _CategoryHeader(
              label: 'YOUR GOALS',
              blurb: 'the goals you’re actively working on',
              icon: Icons.auto_awesome_outlined,
              accent: Palette.xp,
            ),
            const SizedBox(height: 10),
            if (state.goals.isNotEmpty) ...[
              _YourGoals(
                state: state,
                onRemoveGoal: onRemoveGoal,
                onPersist: onPersist,
                onAddQuest: onAdd,
                quests: quests,
                parallax: parallax,
              ),
              const SizedBox(height: 18),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'no oaths sworn yet — forge one above, or adopt a ready-made path below',
                  style: Type.body.copyWith(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Palette.textLo,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ReadyMadePathsDisclosure(catalog: catalog),
              const SizedBox(height: 18),
            ],
            _CategoryHeader(
              label: 'HELP FOR TODAY',
              blurb: 'choose the kind of support this day needs',
              icon: Icons.auto_awesome_outlined,
              accent: Palette.streak,
            ),
            const SizedBox(height: 10),
            _MomentumKitsCard(
              state: state,
              onAdd: onAdd,
              onPersist: onPersist,
              onOpenQuests: onOpenQuests,
            ),
            const SizedBox(height: 18),
            _CategoryHeader(
              label: 'GUIDED WORKOUTS',
              blurb: 'gentle sessions that meet you where you are',
              icon: Icons.fitness_center,
              accent: Stat.str.color,
            ),
            const SizedBox(height: 10),
            _GuidedWorkoutsCard(onAdd: onAdd),
            if (state.goals.isNotEmpty) ...catalog,
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
            idea: idea,
            onAdd: onAdd,
            activeTitles: activeTitles,
            onAdopt: () => _adoptGoal(context, idea),
            adopted: state.goals.any((g) => g.title == idea.title),
          ),
        );
        if (i < ideas.length - 1) widgets.add(const SizedBox(height: 12));
      }
    }
    return widgets;
  }
}

/// The catalog is useful, but on a first visit it should be a deliberate
/// alternate way in rather than a long obstacle between the empty state and
/// the next useful choice. Once opened, it stays open while the person browses.
class _ReadyMadePathsDisclosure extends StatefulWidget {
  const _ReadyMadePathsDisclosure({required this.catalog});

  final List<Widget> catalog;

  @override
  State<_ReadyMadePathsDisclosure> createState() =>
      _ReadyMadePathsDisclosureState();
}

class _ReadyMadePathsDisclosureState extends State<_ReadyMadePathsDisclosure> {
  var _expanded = false;

  void _toggle() {
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final semanticLabel = _expanded
        ? 'Hide ready-made paths'
        : 'Browse ready-made paths. Start with a path that already has its first quests.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _toggle();
                return null;
              },
            ),
          },
          child: Semantics(
            button: true,
            label: semanticLabel,
            onTap: _toggle,
            child: GestureDetector(
              excludeFromSemantics: true,
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: GlassPanel(
                padding: const EdgeInsets.fromLTRB(15, 13, 13, 13),
                child: Row(
                  children: [
                    FacetMedallion(
                      size: 38,
                      accent: Palette.xpLight,
                      child: const Icon(
                        Icons.auto_stories_outlined,
                        size: 19,
                        color: Palette.xpLight,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _expanded
                                ? 'Ready-made paths'
                                : 'Browse ready-made paths',
                            style: Type.display.copyWith(fontSize: 17),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _expanded
                                ? 'choose the shape that fits'
                                : 'start with a path that already has its first quests',
                            style: Type.body.copyWith(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Palette.textLo,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: Palette.textLo,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded) ...widget.catalog,
      ],
    );
  }
}

/// One coherent doorway for situation-shaped help: no new tab, checklist, or
/// currency. The six kits all resolve back into ordinary quests and the Keep.
class _MomentumKitsCard extends StatelessWidget {
  const _MomentumKitsCard({
    required this.state,
    required this.onAdd,
    required this.onPersist,
    required this.onOpenQuests,
  });

  final GameState state;
  final bool Function(Quest) onAdd;
  final VoidCallback onPersist;
  final VoidCallback onOpenQuests;

  @override
  Widget build(BuildContext context) {
    void open() {
      Sfx.instance.play('tick');
      HapticFeedback.selectionClick();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MomentumKitsPage(
            state: state,
            onAdd: onAdd,
            onPersist: onPersist,
            onOpenQuests: onOpenQuests,
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label:
          'Help for Today. A few useful quests for the kind of day you are having.',
      onTap: open,
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: GlassPanel(
          glow: true,
          padding: const EdgeInsets.fromLTRB(16, 15, 13, 15),
          child: Row(
            children: [
              const FacetMedallion(
                size: 48,
                accent: Palette.streak,
                glow: true,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x55FFF4D9), Color(0x33E8915A)],
                ),
                child: Icon(
                  Icons.auto_awesome_outlined,
                  size: 23,
                  color: Palette.xpLight,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The section rule directly above already says HELP FOR
                    // TODAY; repeating it as this card's eyebrow said the same
                    // words twice in 40 px and left the card without a subject.
                    Text(
                      'Help for this kind of day',
                      style: Type.display.copyWith(fontSize: 19),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'get unstuck · choose a gentle day · focus · make · reset',
                      style: Type.body.copyWith(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: Palette.textLo),
            ],
          ),
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
          // The hairline is the sole flexible child, so it always runs to the
          // edge (and the label, being inflexible, is never truncated).
          Row(
            children: [
              medallion,
              const SizedBox(width: 10),
              Text(
                label,
                style: Type.label.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.6,
                  color: Palette.textHi,
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

/// Guided-workout discovery: puts the hand-held session quest on the board
/// for the user who wants to move but isn't a gym rat (RESEARCH-workouts.md).
class _GuidedWorkoutsCard extends StatelessWidget {
  const _GuidedWorkoutsCard({required this.onAdd});
  final bool Function(Quest) onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Sfx.instance.play('tick');
        HapticFeedback.selectionClick();
        final added = onAdd(workoutLauncherQuest());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Palette.card,
            content: Text(
              added
                  ? 'Guided workouts added — find it on your Quests board 💪'
                  : 'It’s already on your Quests board — tap it to begin',
              style: Type.body.copyWith(color: Palette.textHi),
            ),
          ),
        );
      },
      child: GlassPanel(
        glow: true,
        child: Row(
          children: [
            FacetMedallion(
              size: 44,
              accent: Stat.str.color,
              child: Icon(
                Icons.fitness_center,
                size: 21,
                color: Stat.str.color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guided workouts',
                    style: Type.display.copyWith(fontSize: 19),
                  ),
                  Text(
                    'gentle, beginner sessions — we walk you through it',
                    style: Type.body.copyWith(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Palette.textLo,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Palette.textLo),
          ],
        ),
      ),
    );
  }
}

/// "YOUR GOALS" — each ambition with its bar inching toward full.
/// Long-press a goal to abandon it (clears its quests too).
class _YourGoals extends StatelessWidget {
  const _YourGoals({
    required this.state,
    required this.onRemoveGoal,
    required this.onPersist,
    required this.onAddQuest,
    required this.quests,
    required this.parallax,
  });
  final GameState state;
  final void Function(Goal goal) onRemoveGoal;
  final VoidCallback onPersist;
  final bool Function(Quest quest) onAddQuest;
  final List<Quest> quests;
  final ValueListenable<Offset> parallax;

  String _artFor(Stat stat) => switch (stat) {
    Stat.str => 'assets/quest/category-body-v2.webp',
    Stat.vit => 'assets/quest/category-care-v2.webp',
    Stat.intl => 'assets/quest/category-mind-v2.webp',
    Stat.foc => 'assets/quest/category-craft-v2.webp',
    Stat.soc => 'assets/quest/category-people-v2.webp',
    Stat.dis => 'assets/quest/category-home-v2.webp',
  };

  void _openDetail(BuildContext context, Goal g) {
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GoalDetailScreen(
          goal: g,
          state: state,
          quests: quests,
          onRemoveGoal: onRemoveGoal,
          onPersist: onPersist,
          onAddQuest: onAddQuest,
        ),
      ),
    );
  }

  void _confirmAbandon(BuildContext context, Goal g) {
    Sfx.instance.play('tick');
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
                  'Abandon “${g.title}”?',
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
                    Flexible(
                      child: GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 9,
                          ),
                          decoration: facetedDecoration(
                            cut: 8,
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFFF6D9A2),
                                Color(0xFFEFC074),
                                Color(0xFFC08B4F),
                              ],
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'KEEP IT',
                              maxLines: 1,
                              style: Type.label.copyWith(
                                fontSize: 11,
                                color: const Color(0xFF3A2510),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: GestureDetector(
                        onTap: () {
                          if (!armed) {
                            Sfx.instance.play('tick');
                            setDialog(() => armed = true);
                            return;
                          }
                          Sfx.instance.play('boing');
                          onRemoveGoal(g);
                          Navigator.of(ctx).pop();
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
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              armed ? 'TAP AGAIN' : 'ABANDON',
                              maxLines: 1,
                              style: Type.label.copyWith(
                                fontSize: 11,
                                color: const Color(0xFFE89090),
                              ),
                            ),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final g in state.goals)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openDetail(context, g),
              onLongPress: () => _confirmAbandon(context, g),
              child: GlassPanel(
                padding: EdgeInsets.zero,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 106),
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      Positioned(
                        top: 0,
                        right: -8,
                        bottom: 0,
                        width: 184,
                        child: IgnorePointer(
                          child: ShaderMask(
                            blendMode: BlendMode.dstIn,
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0x8A000000),
                                Color(0xF0000000),
                              ],
                              stops: [0, 0.55, 1],
                            ).createShader(bounds),
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: 0.65,
                                sigmaY: 0.65,
                              ),
                              child: AnimatedBuilder(
                                animation: parallax,
                                builder: (context, child) {
                                  final p = state.reduceMotion
                                      ? Offset.zero
                                      : parallax.value;
                                  return Transform.translate(
                                    offset: Offset(p.dx * 3.6, p.dy * 2.2),
                                    child: child,
                                  );
                                },
                                child: Opacity(
                                  opacity: 0.46,
                                  child: Image.asset(
                                    _artFor(g.stat),
                                    fit: BoxFit.cover,
                                    alignment: Alignment.centerRight,
                                    filterQuality: FilterQuality.medium,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
                        child: Row(
                          children: [
                            FacetMedallion(
                              size: 46,
                              accent: g.complete
                                  ? Palette.xpLight
                                  : g.stat.color,
                              glow: g.complete,
                              child: Icon(
                                g.complete
                                    ? Icons.emoji_events_outlined
                                    : g.stat.icon,
                                size: 22,
                                color: g.complete
                                    ? Palette.xpLight
                                    : g.stat.color,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    g.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Type.display.copyWith(
                                      fontSize: 17,
                                      height: 1.08,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    g.complete
                                        ? 'ACHIEVED'
                                        : '${g.progress} / ${g.target} QUESTS',
                                    style: Type.label.copyWith(
                                      fontSize: 10.5,
                                      color: g.complete
                                          ? Palette.xpLight
                                          : g.stat.color,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  FacetedMeter(
                                    value: g.complete ? 1 : g.fraction,
                                    height: 6,
                                    glow: g.complete,
                                    background: Palette.railTrack,
                                    color: g.complete
                                        ? Palette.xpLight
                                        : g.stat.color,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 7),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 21,
                              color: Palette.textLo,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GoalCard extends StatefulWidget {
  const _GoalCard({
    required this.idea,
    required this.onAdd,
    required this.activeTitles,
    required this.onAdopt,
    required this.adopted,
  });

  final GoalIdea idea;
  final bool Function(Quest) onAdd;
  final Set<String> activeTitles;
  final VoidCallback onAdopt;
  final bool adopted;

  @override
  State<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<_GoalCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final idea = widget.idea;
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Sfx.instance.play('tick');
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
                  duration: Motion.quick,
                  child: const Icon(
                    Icons.expand_more,
                    size: 20,
                    color: Palette.textLo,
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: Motion.settle,
            sizeCurve: Motion.respond,
            crossFadeState: _open
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
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
                      taken: widget.activeTitles.contains(t.title),
                      onAdd: widget.onAdd,
                    ),
                  const SizedBox(height: 4),
                  Center(
                    child: GestureDetector(
                      onTap: widget.adopted ? null : widget.onAdopt,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: facetedDecoration(
                          cut: 8,
                          gradient: widget.adopted
                              ? null
                              : const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFF6D9A2),
                                    Color(0xFFEFC074),
                                    Color(0xFFC08B4F),
                                  ],
                                ),
                          borderColor: widget.adopted
                              ? Palette.success.withValues(alpha: 0.5)
                              : Colors.transparent,
                        ),
                        child: Text(
                          widget.adopted
                              ? 'GOAL UNDERWAY ✓'
                              : 'ADOPT WHOLE GOAL',
                          style: Type.label.copyWith(
                            fontSize: 11,
                            color: widget.adopted
                                ? Palette.success
                                : const Color(0xFF3A2510),
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
    );
  }
}

/// "WHY THIS HELPS" — the research behind a catalog quest, opened from the
/// info-dot on its row. Mirrors the per-stat evidence beat on Me; reads
/// [questWhy] (warm user-facing claim + a real source).
void _showQuestWhy(BuildContext context, QuestTemplate t) {
  final why = questWhy[t.title];
  if (why == null) return;
  Sfx.instance.play('tick');
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

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.template,
    required this.taken,
    required this.onAdd,
  });

  final QuestTemplate template;
  final bool taken;
  final bool Function(Quest) onAdd;

  @override
  Widget build(BuildContext context) {
    final t = template;
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
                    _MiniChip(label: t.schedule.label),
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
          GestureDetector(
            onTap: taken
                ? null
                : () async {
                    // Weekly quests ask which day they should land on (the
                    // "weekly shot" feedback) — default-selected to today.
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
                    if (!context.mounted) return;
                    final ok = onAdd(quest);
                    if (ok) {
                      Sfx.instance.play('streak');
                      HapticFeedback.selectionClick();
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Palette.card,
                        duration: const Duration(milliseconds: 1400),
                        content: Text(
                          ok
                              ? '“${t.title}” taken on ⚔️'
                              : 'Already on your quest list',
                          style: Type.body.copyWith(color: Palette.textHi),
                        ),
                      ),
                    );
                  },
            child: AnimatedContainer(
              duration: Motion.quick,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: facetedDecoration(
                cut: 7,
                gradient: taken
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFF6D9A2),
                          Color(0xFFEFC074),
                          Color(0xFFC08B4F),
                        ],
                      ),
                borderColor: taken
                    ? Palette.success.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
              child: Text(
                taken ? 'TAKEN ✓' : 'TAKE ON',
                style: Type.label.copyWith(
                  fontSize: 11,
                  color: taken ? Palette.success : const Color(0xFF3A2510),
                ),
              ),
            ),
          ),
        ],
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
