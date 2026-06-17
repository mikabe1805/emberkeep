import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../content/goal_catalog.dart';
import '../content/routines.dart';
import '../engine.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/glass.dart';
import 'goal_wizard.dart';

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
    goalTitles: const ['Become a reader', 'Deep focus'],
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
  });

  final GameState state;

  /// Returns false when a same-titled quest is already on the list.
  final bool Function(Quest quest) onAdd;

  /// Titles already on the quest list (disables duplicate take-ons).
  final Set<String> activeTitles;

  /// Abandons a goal and clears its linked quests.
  final void Function(Goal goal) onRemoveGoal;

  void _adoptGoal(BuildContext context, GoalIdea idea) {
    final created = state.addGoal(
        Goal(title: idea.title, stat: idea.stat, target: 25));
    var added = 0;
    for (final t in idea.quests) {
      if (onAdd(t.build(goalTitle: idea.title))) added++;
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
            style: Type.body.copyWith(color: Palette.textHi)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
        children: [
          Text('Take on quests!', style: Type.display.copyWith(fontSize: 30)),
          const SizedBox(height: 4),
          Text('every quest serves a goal — that’s the point',
              style: Type.body.copyWith(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Palette.textLo)),
          const SizedBox(height: 16),
          _WizardHero(state: state, onAdd: onAdd),
          const SizedBox(height: 12),
          if (state.goals.isNotEmpty) ...[
            _YourGoals(state: state, onRemoveGoal: onRemoveGoal),
            const SizedBox(height: 12),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                  'no oaths sworn yet — forge one above, or adopt a ready-made path below',
                  style: Type.body.copyWith(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Palette.textLo)),
            ),
            const SizedBox(height: 12),
          ],
          _GuidedWorkoutsCard(onAdd: onAdd),
          ..._catalogSections(context),
        ],
      ),
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
      goalCatalog.every((g) =>
          _goalCategories.any((c) => c.goalTitles.contains(g.title))),
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
      widgets.add(_CategoryHeader(
        label: cat.label,
        blurb: cat.blurb,
        icon: cat.icon,
        accent: cat.accent,
      ));
      widgets.add(const SizedBox(height: 10));
      for (var i = 0; i < ideas.length; i++) {
        final idea = ideas[i];
        widgets.add(_GoalCard(
          idea: idea,
          onAdd: onAdd,
          activeTitles: activeTitles,
          onAdopt: () => _adoptGoal(context, idea),
          adopted: state.goals.any((g) => g.title == idea.title),
        ));
        if (i < ideas.length - 1) widgets.add(const SizedBox(height: 12));
      }
    }
    return widgets;
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
    final medallion = SizedBox(
      width: 26,
      height: 26,
      child: Stack(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.16),
              border: Border.all(
                  color: accent.withValues(alpha: 0.5), width: 1.2),
            ),
            child: Center(child: Icon(icon, size: 15, color: accent)),
          ),
          // the signature specular drop-of-light, at small scale
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.7, -0.8),
                    radius: 1.1,
                    colors: [
                      Palette.specular.withValues(alpha: 0.18),
                      Palette.specular.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.6],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
              Text(label,
                  style: Type.label.copyWith(
                      fontSize: 11,
                      letterSpacing: 1.6,
                      color: Palette.textHi)),
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
            child: Text(blurb,
                style: Type.body.copyWith(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Palette.textLo)),
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
                style: Type.body.copyWith(color: Palette.textHi)),
          ),
        );
      },
      child: GlassPanel(
        glow: true,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Stat.str.color.withValues(alpha: 0.16),
                border:
                    Border.all(color: Stat.str.color.withValues(alpha: 0.5)),
              ),
              child:
                  Icon(Icons.fitness_center, size: 21, color: Stat.str.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Guided workouts',
                      style: Type.display.copyWith(fontSize: 19)),
                  Text('gentle, beginner sessions — we walk you through it',
                      style: Type.body.copyWith(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Palette.textLo)),
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

/// The doorway to the Oath Wizard — creation as ceremony.
class _WizardHero extends StatelessWidget {
  const _WizardHero({required this.state, required this.onAdd});
  final GameState state;
  final bool Function(Quest) onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Sfx.instance.play('tick');
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GoalWizardScreen(state: state, onAdd: onAdd),
          ),
        );
      },
      child: GlassPanel(
        blur: true,
        glow: true,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.4, -0.5),
                  colors: [Color(0xFFFFF4D9), Color(0xFFC08B4F)],
                ),
                boxShadow: const [
                  BoxShadow(color: Palette.honeyGlow, blurRadius: 16),
                ],
              ),
              child: const Icon(Icons.flag, size: 22, color: Color(0xFF3A2510)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Begin a new goal',
                      style: Type.display.copyWith(fontSize: 19)),
                  Text('name it · forge its path · swear the oath',
                      style: Type.body.copyWith(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Palette.textLo)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Palette.textLo),
          ],
        ),
      ),
    );
  }
}

/// "YOUR GOALS" — each ambition with its bar inching toward full.
/// Long-press a goal to abandon it (clears its quests too).
class _YourGoals extends StatelessWidget {
  const _YourGoals({required this.state, required this.onRemoveGoal});
  final GameState state;
  final void Function(Goal goal) onRemoveGoal;

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
                Text('Abandon “${g.title}”?',
                    textAlign: TextAlign.center,
                    style: Type.display.copyWith(fontSize: 17)),
                const SizedBox(height: 6),
                Text('The goal and every quest serving it leave the board.',
                    textAlign: TextAlign.center,
                    style: Type.body.copyWith(
                        fontSize: 12.5, color: Palette.textMid)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFF2CD93), Color(0xFFC08B4F)],
                          ),
                        ),
                        child: Text('KEEP IT',
                            style: Type.label.copyWith(
                                fontSize: 10,
                                color: const Color(0xFF3A2510))),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
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
                            horizontal: 18, vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: const Color(0xFFE89090)
                                  .withValues(alpha: armed ? 1 : 0.5)),
                        ),
                        child: Text(armed ? 'TAP AGAIN' : 'ABANDON',
                            style: Type.label.copyWith(
                                fontSize: 10,
                                color: const Color(0xFFE89090))),
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
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('YOUR GOALS', style: Type.label.copyWith(fontSize: 10)),
              const Spacer(),
              Text('hold to edit', style: Type.label.copyWith(fontSize: 7.5)),
            ],
          ),
          const SizedBox(height: 10),
          for (final g in state.goals) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: () => _confirmAbandon(context, g),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        g.complete
                            ? Icons.emoji_events
                            : g.kind == GoalKind.become
                                ? Icons.all_inclusive
                                : Icons.flag,
                        size: 13,
                        color: g.complete ? Palette.xpLight : g.stat.color,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(g.title,
                            overflow: TextOverflow.ellipsis,
                            style: Type.body.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Palette.textHi)),
                      ),
                      Text(
                          g.complete
                              ? 'ACHIEVED'
                              : '${g.progress}/${g.target}'
                                  '${g.kind == GoalKind.become ? " · MILESTONE" : ""}',
                          style: Type.label.copyWith(
                              fontSize: 8,
                              color: g.complete
                                  ? Palette.xpLight
                                  : g.stat.color)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: g.complete ? 1 : g.fraction,
                      minHeight: 7,
                      backgroundColor: const Color(0x1FF2CD93),
                      color: g.complete ? Palette.xpLight : g.stat.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
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
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: idea.stat.color.withValues(alpha: 0.16),
                    border: Border.all(
                        color: idea.stat.color.withValues(alpha: 0.5)),
                  ),
                  child: Center(
                    child: Text(idea.stat.abbr,
                        style: Type.label.copyWith(
                            fontSize: 9, color: idea.stat.color)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(idea.title,
                      style: Type.display.copyWith(fontSize: 18)),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: Motion.quick,
                  child: const Icon(Icons.expand_more,
                      size: 20, color: Palette.textLo),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: Motion.settle,
            sizeCurve: Motion.respond,
            crossFadeState:
                _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(idea.blurb,
                      style: Type.body.copyWith(
                          fontSize: 12.5,
                          height: 1.5,
                          color: Palette.textMid)),
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
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: widget.adopted
                              ? null
                              : const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFF2CD93),
                                    Color(0xFFC08B4F)
                                  ],
                                ),
                          border: widget.adopted
                              ? Border.all(
                                  color: Palette.success
                                      .withValues(alpha: 0.5))
                              : null,
                        ),
                        child: Text(
                          widget.adopted
                              ? 'GOAL UNDERWAY ✓'
                              : 'ADOPT WHOLE GOAL',
                          style: Type.label.copyWith(
                              fontSize: 9,
                              color: widget.adopted
                                  ? Palette.success
                                  : const Color(0xFF3A2510)),
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
                Text('WHY THIS HELPS',
                    style:
                        Type.label.copyWith(fontSize: 10, color: t.stat.color)),
              ],
            ),
            const SizedBox(height: 10),
            Text(t.title, style: Type.display.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text(why.claim,
                style: Type.body.copyWith(
                    fontSize: 13, height: 1.5, color: Palette.textMid)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.menu_book_outlined,
                    size: 11, color: Palette.info),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(why.source,
                      style: Type.label
                          .copyWith(fontSize: 8, color: Palette.info)),
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
                      child: Text(t.title,
                          style: Type.body.copyWith(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Palette.textHi)),
                    ),
                    // tap to learn the research behind this habit
                    if (questWhy.containsKey(t.title)) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _showQuestWhy(context, t),
                        behavior: HitTestBehavior.opaque,
                        child: Icon(Icons.info_outline,
                            size: 13,
                            color: t.stat.color.withValues(alpha: 0.8)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _MiniChip(label: t.schedule.label),
                    if (t.timerMinutes > 0) ...[
                      const SizedBox(width: 5),
                      _MiniChip(
                          label: '⏱ ${t.timerMinutes}M',
                          color: Palette.verify),
                    ],
                    if (t.allDay) ...[
                      const SizedBox(width: 5),
                      const _MiniChip(
                          label: 'CHECKS AT NIGHT', color: Palette.unlock),
                    ],
                    if (t.dread) ...[
                      const SizedBox(width: 5),
                      const _MiniChip(
                          label: 'COUNTS EXTRA', color: Palette.dread),
                    ],
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: taken
                ? null
                : () {
                    final ok = onAdd(t.build());
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
                            style:
                                Type.body.copyWith(color: Palette.textHi)),
                      ),
                    );
                  },
            child: AnimatedContainer(
              duration: Motion.quick,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: taken
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFF2CD93), Color(0xFFC08B4F)],
                      ),
                border: taken
                    ? Border.all(
                        color: Palette.success.withValues(alpha: 0.5))
                    : null,
              ),
              child: Text(
                taken ? 'TAKEN ✓' : 'TAKE ON',
                style: Type.label.copyWith(
                    fontSize: 9,
                    color: taken
                        ? Palette.success
                        : const Color(0xFF3A2510)),
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: Type.label.copyWith(fontSize: 7.5, color: c)),
    );
  }
}
