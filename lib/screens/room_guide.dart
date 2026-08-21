import 'package:flutter/material.dart';

import '../audio.dart';
import '../engine.dart';
import '../haptics.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import 'momentum_kits.dart';

/// A re-openable map of Room of Days.
///
/// First-run onboarding stays focused on the first Quest. This screen carries
/// the broader product map for people who want it, and keeps situational help
/// such as Guided Home Reset from being discoverable only by accident.
class RoomGuideScreen extends StatelessWidget {
  const RoomGuideScreen({
    super.key,
    required this.state,
    required this.onAddQuest,
    required this.onPersist,
    required this.onSelectTab,
  });

  final GameState state;
  final bool Function(Quest quest) onAddQuest;
  final VoidCallback onPersist;
  final ValueChanged<int> onSelectTab;

  void _openTab(BuildContext context, int tab) {
    Sfx.instance.playMaterial(MaterialSound.wood);
    Haptics.tap();
    Navigator.of(context).pop();
    onSelectTab(tab);
  }

  void _openHelp(BuildContext context) {
    Sfx.instance.playMaterial(MaterialSound.wood);
    Haptics.tap();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MomentumKitsPage(
          state: state,
          onAdd: onAddQuest,
          onPersist: onPersist,
          onOpenQuests: () {
            // MomentumKitsPage has just begun popping its own route. Let that
            // transition finish before removing the guide as well; two route
            // pops in the same tick race on iOS and can leave the guide over a
            // Quests tab that already changed underneath it.
            Future<void>.delayed(const Duration(milliseconds: 320), () {
              if (!context.mounted) return;
              Navigator.of(context).pop();
              onSelectTab(1);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.parchment,
      body: WarmBackground(
        themeId: state.canvasTheme,
        tint: Palette.xp,
        reduceMotion: state.reduceMotion,
        child: SafeArea(
          child: Column(
            children: [
              const DetailHeader(
                title: 'Room Guide',
                subtitle: 'the useful things, and where they live',
                accent: Palette.xp,
                pill: 'OPEN ANYTIME',
              ),
              Expanded(
                child: ListView(
                  key: const ValueKey('room-guide-list'),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 42),
                  children: [
                    const _GuideIntro(),
                    const SizedBox(height: 22),
                    const _GuideSection(
                      title: 'YOUR DAY',
                      subtitle: 'begin here; learn the rest when it is useful',
                      accent: Palette.xp,
                    ),
                    const SizedBox(height: 10),
                    _GuideDoor(
                      eyebrow: 'THE DAILY BOARD',
                      title: 'Quests',
                      detail:
                          'Add what matters, finish it for XP, or use Focus Mode when you only want to see one thing.',
                      footnote: 'QUICK ADD · FOCUS MODE · MORNING + NIGHT',
                      icon: Icons.task_alt_rounded,
                      accent: Palette.xp,
                      actionLabel: 'OPEN QUESTS',
                      onTap: () => _openTab(context, 1),
                    ),
                    const SizedBox(height: 10),
                    _GuideDoor(
                      key: const ValueKey('room-guide-help-today'),
                      eyebrow: 'WHEN SOMETHING FEELS TOO BIG',
                      title: 'Help for Today',
                      detail:
                          'Turn one stuck task, a messy room, or a low-energy day into a few doable Quests.',
                      footnote:
                          'UNSTICK ME · GENTLE MODE DAY · GUIDED HOME RESET',
                      icon: Icons.support_outlined,
                      accent: Palette.streak,
                      actionLabel: 'FIND THE RIGHT HELP',
                      onTap: () => _openHelp(context),
                    ),
                    const SizedBox(height: 22),
                    const _GuideSection(
                      title: 'WHAT YOU ARE BUILDING',
                      subtitle: 'give the days direction without crowding them',
                      accent: Palette.unlock,
                    ),
                    const SizedBox(height: 10),
                    _GuideDoor(
                      eyebrow: 'PATHS + PRACTICE',
                      title: 'Goals',
                      detail:
                          'Make a goal, borrow a ready-made path, or open a guided workout when a little structure would help.',
                      footnote: 'READY-MADE PATHS · GUIDED WORKOUTS',
                      icon: Icons.explore_outlined,
                      accent: Palette.unlock,
                      actionLabel: 'OPEN GOALS',
                      onTap: () => _openTab(context, 2),
                    ),
                    const SizedBox(height: 10),
                    _GuideDoor(
                      eyebrow: 'DAYS + SCHOOL',
                      title: 'Plans',
                      detail:
                          'Keep appointments and planned Quests together. Academic mode can hold classes, work, exams, and study sessions.',
                      footnote: 'CALENDAR · CLASSES · STUDY PLANS',
                      icon: Icons.calendar_month_outlined,
                      accent: Stat.foc.color,
                      actionLabel: 'OPEN PLANS',
                      onTap: () => _openTab(context, 3),
                    ),
                    const SizedBox(height: 22),
                    const _GuideSection(
                      title: 'WHAT CHANGED',
                      subtitle: 'the evidence stays yours and gathers quietly',
                      accent: Palette.streak,
                    ),
                    const SizedBox(height: 10),
                    _GuideDoor(
                      eyebrow: 'PAGES + PATTERNS',
                      title: 'Journal',
                      detail:
                          'Write a page or keep one line. Quests, XP, and build movement can attach themselves so you do not have to reconstruct the day.',
                      footnote: 'ENTRIES · PATTERNS · THEN + NOW',
                      icon: Icons.menu_book_outlined,
                      accent: Stat.intl.color,
                      actionLabel: 'OPEN JOURNAL',
                      onTap: () => _openTab(context, 4),
                    ),
                    const SizedBox(height: 10),
                    _GuideDoor(
                      eyebrow: 'YOUR SPACE + BUILD',
                      title: 'Me',
                      detail:
                          'See the room and six-domain build your days have shaped. Change the space, keep memories, or manage settings and backup.',
                      footnote: 'ROOM · BUILD · MEMORIES · SETTINGS',
                      icon: Icons.emoji_emotions_outlined,
                      accent: Stat.vit.color,
                      actionLabel: 'OPEN ME',
                      onTap: () => _openTab(context, 0),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'You never need to use everything. This guide stays in Me → Settings whenever a different kind of day comes up.',
                      textAlign: TextAlign.center,
                      style: Type.body.copyWith(
                        fontSize: 12,
                        height: 1.45,
                        fontStyle: FontStyle.italic,
                        color: Palette.textMid,
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

class _GuideIntro extends StatelessWidget {
  const _GuideIntro();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      glow: true,
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FacetMedallion(
            size: 54,
            accent: Palette.xp,
            glow: true,
            child: Icon(Icons.map_outlined, size: 27, color: Palette.xpLight),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start with one Quest.',
                  style: Type.display.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 5),
                Text(
                  'The rest is not a syllabus. It is a set of doors you can open when a task, a day, or a longer plan needs a different kind of help.',
                  style: Type.body.copyWith(
                    fontSize: 13,
                    height: 1.42,
                    color: Palette.textMid,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Transform.rotate(
            angle: 0.785,
            child: Container(width: 9, height: 9, color: accent),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Type.label.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.7,
                  color: Palette.textHi,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Type.body.copyWith(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  color: Palette.textLo,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 72,
          height: 1,
          margin: const EdgeInsets.only(top: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent.withValues(alpha: 0.55), Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }
}

class _GuideDoor extends StatelessWidget {
  const _GuideDoor({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.detail,
    required this.footnote,
    required this.icon,
    required this.accent,
    required this.actionLabel,
    required this.onTap,
  });

  final String eyebrow;
  final String title;
  final String detail;
  final String footnote;
  final IconData icon;
  final Color accent;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $detail. $actionLabel',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: GlassPanel(
          padding: const EdgeInsets.fromLTRB(14, 14, 13, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FacetMedallion(
                size: 46,
                accent: accent,
                child: Icon(icon, size: 22, color: accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        letterSpacing: 1.15,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(title, style: Type.display.copyWith(fontSize: 21)),
                    const SizedBox(height: 5),
                    Text(
                      detail,
                      style: Type.body.copyWith(
                        fontSize: 12.5,
                        height: 1.38,
                        color: Palette.textMid,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      footnote,
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        height: 1.35,
                        letterSpacing: 0.8,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 21,
                  color: accent.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
