import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../content/memories.dart';
import '../engine.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';

class MemoryCabinetScreen extends StatelessWidget {
  const MemoryCabinetScreen({
    super.key,
    required this.state,
    required this.quests,
  });

  final GameState state;
  final List<Quest> quests;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final memories = memoryCollection(state, quests);
      return Scaffold(
        backgroundColor: Palette.parchment,
        body: WarmBackground(
          themeId: state.canvasTheme,
          tint: Palette.unlock,
          reduceMotion: state.reduceMotion,
          child: SafeArea(
            child: Column(
              children: [
                DetailHeader(
                  title: 'Keepsakes',
                  subtitle: 'proof that your space has a history',
                  accent: Palette.xp,
                  pill: '${memories.length}',
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
                    children: [
                      _CabinetHero(memories: memories),
                      const SizedBox(height: 20),
                      if (memories.kept.isEmpty)
                        _EmptyKeeps()
                      else ...[
                        const _SectionHeading(
                          title: 'MOMENTS YOU CHOSE',
                          subtitle: 'private words and photographs kept close',
                          accent: Palette.xp,
                        ),
                        const SizedBox(height: 9),
                        for (final memory in memories.kept) ...[
                          _MemoryCard(
                            memory: memory,
                            onRemove: () =>
                                state.setMemoryPinned(memory.note!.id, false),
                          ),
                          const SizedBox(height: 9),
                        ],
                      ],
                      if (memories.trophies.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const _SectionHeading(
                          title: 'ACHIEVEMENT HEIRLOOMS',
                          subtitle:
                              'earned objects — never bought, never random',
                          accent: Palette.unlock,
                        ),
                        const SizedBox(height: 9),
                        for (final memory in memories.trophies) ...[
                          _MemoryCard(memory: memory, ceremonial: true),
                          const SizedBox(height: 9),
                        ],
                      ],
                      if (memories.goals.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const _SectionHeading(
                          title: 'PATHS YOU WALKED',
                          subtitle:
                              'milestones from promises you made yourself',
                          accent: Palette.success,
                        ),
                        const SizedBox(height: 9),
                        for (final memory in memories.goals) ...[
                          _MemoryCard(memory: memory),
                          const SizedBox(height: 9),
                        ],
                      ],
                      if (memories.hearth.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const _SectionHeading(
                          title: 'ROOM MILESTONES',
                          subtitle: 'the level landmarks you actually reached',
                          accent: Palette.streak,
                        ),
                        const SizedBox(height: 9),
                        for (final memory in memories.hearth) ...[
                          _MemoryCard(memory: memory),
                          const SizedBox(height: 9),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _CabinetHero extends StatelessWidget {
  const _CabinetHero({required this.memories});
  final MemoryCollection memories;

  @override
  Widget build(BuildContext context) => GlassPanel(
    glow: memories.length > 0,
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        SizedBox(
          width: 96,
          height: 116,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 78,
                height: 108,
                decoration: facetedDecoration(
                  cut: 10,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6A4A37), Color(0xFF34241F)],
                  ),
                  borderColor: Palette.xpLight.withValues(alpha: 0.28),
                ),
              ),
              for (final spec in const [
                (Alignment(-0.42, -0.48), Palette.xp, Icons.history_edu),
                (
                  Alignment(0.42, -0.08),
                  Palette.unlock,
                  Icons.diamond_outlined,
                ),
                (
                  Alignment(-0.20, 0.48),
                  Palette.streak,
                  Icons.local_fire_department_outlined,
                ),
              ])
                Align(
                  alignment: spec.$1,
                  child: FacetMedallion(
                    size: 28,
                    accent: spec.$2,
                    glow: memories.length > 0,
                    child: Icon(spec.$3, size: 14, color: spec.$2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                memories.length == 0
                    ? 'The shelves are ready'
                    : '${memories.length} pieces of your story',
                style: Type.display.copyWith(fontSize: 21),
              ),
              const SizedBox(height: 5),
              Text(
                'Pin journal moments you want to remember. Goal milestones and achievements arrive here on their own.',
                style: Type.body.copyWith(
                  fontSize: 12.5,
                  height: 1.38,
                  color: Palette.textLo,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EmptyKeeps extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      'Use the bookmark beside any journal entry to place that moment here. Nothing is shared from this cabinet.',
      textAlign: TextAlign.center,
      style: Type.body.copyWith(
        fontSize: 12,
        fontStyle: FontStyle.italic,
        color: Palette.textLo,
      ),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
    required this.accent,
  });
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Transform.rotate(
        angle: 0.785,
        child: Container(width: 8, height: 8, color: accent),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Type.label.copyWith(
                fontSize: 10.5,
                letterSpacing: 1.45,
                color: Palette.textHi,
              ),
            ),
            Text(
              subtitle,
              style: Type.body.copyWith(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.memory,
    this.ceremonial = false,
    this.onRemove,
  });

  final MemoryArtifact memory;
  final bool ceremonial;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => GlassPanel(
    glow: ceremonial,
    padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FacetMedallion(
          size: ceremonial ? 52 : 46,
          accent: memory.accent,
          glow: ceremonial,
          gradient: ceremonial
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Palette.specular.withValues(alpha: 0.34),
                    memory.accent.withValues(alpha: 0.16),
                  ],
                )
              : null,
          child: Icon(
            memory.icon,
            size: ceremonial ? 25 : 21,
            color: memory.accent,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                memory.subtitle,
                style: Type.label.copyWith(fontSize: 9, color: memory.accent),
              ),
              const SizedBox(height: 3),
              Text(
                memory.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Type.display.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 3),
              Text(
                memory.detail,
                maxLines: memory.kind == MemoryKind.journal ? 4 : 2,
                overflow: TextOverflow.ellipsis,
                style: Type.body.copyWith(
                  fontSize: 12,
                  height: 1.35,
                  fontStyle: memory.kind == MemoryKind.journal
                      ? FontStyle.italic
                      : FontStyle.normal,
                  color: Palette.textLo,
                ),
              ),
            ],
          ),
        ),
        if (onRemove != null)
          Semantics(
            button: true,
            label: 'Remove ${memory.title} from Keepsakes',
            child: GestureDetector(
              excludeFromSemantics: true,
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Sfx.instance.play('tick');
                HapticFeedback.selectionClick();
                onRemove!();
              },
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.bookmark_remove_outlined,
                  size: 18,
                  color: Palette.textLo,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
