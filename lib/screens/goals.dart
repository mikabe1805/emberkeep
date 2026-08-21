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
import '../widgets/rung_picker.dart';
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

String _questTitleKey(String title) => title.trim().toLowerCase();

/// "Take on quests!" — goal discovery. Every routine quest belongs to a
/// goal (the why stays attached, round-7): begin your own via the Oath
/// Wizard, or adopt a curated goal whole. One-time plans live on the
/// calendar.
class GoalsPage extends StatelessWidget {
  const GoalsPage({
    super.key,
    required this.state,
    required this.onAdd,
    required this.onRemoveQuest,
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

  /// Takes one live quest back off the board without removing its goal.
  final void Function(Quest quest) onRemoveQuest;

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
    Sfx.instance.playMaterial(MaterialSound.brass);
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
    Sfx.instance.playMaterial(MaterialSound.glass);
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
      Sfx.instance.playMaterial(MaterialSound.parchment);
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

/// Guided-workout discovery: puts the hand-held session quest on the board
/// for the user who wants to move but isn't a gym rat (RESEARCH-workouts.md).
class _GuidedWorkoutsCard extends StatelessWidget {
  const _GuidedWorkoutsCard({required this.onAdd});
  final bool Function(Quest) onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Sfx.instance.playMaterial(MaterialSound.brass);
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
    Sfx.instance.playMaterial(MaterialSound.parchment);
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
                            gradient: Palette.honeyGradient,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'KEEP IT',
                              maxLines: 1,
                              style: Type.label.copyWith(
                                fontSize: 11,
                                color: Palette.onHoney,
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
                            Sfx.instance.playMaterial(MaterialSound.brass);
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
                                      fontSize: Type.minLabel,
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
    super.key,
    required this.idea,
    required this.onAdd,
    required this.activeQuests,
    required this.onRemoveQuest,
    required this.onPersist,
    required this.onAdopt,
    required this.adopted,
  });

  final GoalIdea idea;
  final bool Function(Quest) onAdd;
  final Map<String, Quest> activeQuests;
  final void Function(Quest) onRemoveQuest;
  final VoidCallback onPersist;
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
            key: ValueKey<String>(
              'goal-catalog-toggle-${_questTitleKey(idea.title)}',
            ),
            behavior: HitTestBehavior.opaque,
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
          AnimatedSize(
            duration: Motion.settle,
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
                                    : Palette.honeyGradient,
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
              onPressed: () => restoreQuest(quest),
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
      Sfx.instance.play('streak');
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
    final activeQuest = widget.activeQuest;
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
