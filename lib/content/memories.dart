import 'package:flutter/material.dart';

import '../engine.dart';
import '../models.dart';
import '../tokens.dart';
import 'achievements.dart';

enum MemoryKind { journal, trophy, goal, hearth }

class ProgressMilestone {
  const ProgressMilestone(this.level, this.name, this.description);

  final int level;
  final String name;
  final String description;
}

/// Long-arc room landmarks. Their names describe what the player accomplished,
/// leaving the tapestry itself to be seen rather than constantly explained.
const progressMilestones = <ProgressMilestone>[
  ProgressMilestone(5, 'First Five', 'Five levels in. The room has receipts.'),
  ProgressMilestone(
    10,
    'Double Digits',
    'This is officially a build, not a good week.',
  ),
  ProgressMilestone(
    16,
    'Taking Shape',
    'Your strongest domains are getting hard to miss.',
  ),
  ProgressMilestone(
    24,
    'Built Different',
    'Nobody else has made this exact stat shape.',
  ),
  ProgressMilestone(
    34,
    'All Yours',
    'Nothing here came from logging in. You did the quests.',
  ),
];

class MemoryArtifact {
  const MemoryArtifact({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.icon,
    required this.accent,
    this.note,
  });

  final String id;
  final MemoryKind kind;
  final String title;
  final String subtitle;
  final String detail;
  final IconData icon;
  final Color accent;
  final Note? note;
}

class MemoryCollection {
  const MemoryCollection({
    required this.kept,
    required this.trophies,
    required this.goals,
    required this.hearth,
  });

  final List<MemoryArtifact> kept;
  final List<MemoryArtifact> trophies;
  final List<MemoryArtifact> goals;
  final List<MemoryArtifact> hearth;

  int get length =>
      kept.length + trophies.length + goals.length + hearth.length;
}

MemoryCollection memoryCollection(GameState state, List<Quest> quests) {
  final notes = <(Note, String, Color)>[];
  for (final note in state.journal) {
    notes.add((note, 'JOURNAL', Palette.xp));
  }
  for (final stat in Stat.values) {
    for (final note in state.notesFor(stat)) {
      notes.add((note, stat.abbr, stat.color));
    }
  }
  for (final goal in state.goals) {
    for (final note in goal.notes) {
      notes.add((note, 'GOAL · ${goal.title}', goal.stat.color));
    }
  }
  for (final quest in quests) {
    for (final note in quest.log) {
      notes.add((note, 'QUEST · ${quest.displayTitle}', quest.stat.color));
    }
  }
  notes.sort((a, b) => b.$1.at.compareTo(a.$1.at));
  final kept = <MemoryArtifact>[
    for (final item in notes)
      if (state.memoryPins.contains(item.$1.id))
        MemoryArtifact(
          id: 'note:${item.$1.id}',
          kind: MemoryKind.journal,
          title: _noteTitle(item.$1),
          subtitle: item.$2,
          detail: item.$1.text.isEmpty
              ? 'A photograph you chose to keep.'
              : item.$1.text,
          icon: item.$1.images.isEmpty
              ? Icons.history_edu
              : Icons.photo_outlined,
          accent: item.$3,
          note: item.$1,
        ),
  ];

  final trophies = <MemoryArtifact>[
    for (final achievement in achievements)
      if (state.unlockedAchievements.contains(achievement.id))
        MemoryArtifact(
          id: 'trophy:${achievement.id}',
          kind: MemoryKind.trophy,
          title: achievement.title,
          subtitle: 'ACHIEVEMENT HEIRLOOM',
          detail: achievement.desc,
          icon: achievement.icon,
          accent: Palette.unlock,
        ),
  ];

  final goals = <MemoryArtifact>[
    for (final goal in state.goals)
      if (goal.complete || goal.progress >= 25)
        MemoryArtifact(
          id: 'goal:${goal.title}',
          kind: MemoryKind.goal,
          title: goal.title,
          subtitle: goal.complete ? 'FINISH LINE CROSSED' : 'FIRST MILESTONE',
          detail: goal.complete
              ? 'A promise you carried all the way through.'
              : '${goal.progress} points of real progress gathered here.',
          icon: goal.complete ? Icons.flag : Icons.alt_route,
          accent: goal.stat.color,
        ),
  ];

  final hearth = <MemoryArtifact>[
    for (final stage in progressMilestones)
      if (state.level >= stage.level)
        MemoryArtifact(
          id: 'hearth:${stage.level}',
          kind: MemoryKind.hearth,
          title: stage.name,
          subtitle: 'ROOM MILESTONE · LEVEL ${stage.level}',
          detail: stage.description,
          icon: Icons.auto_stories_outlined,
          accent: Palette.streak,
        ),
  ];

  return MemoryCollection(
    kept: kept,
    trophies: trophies,
    goals: goals,
    hearth: hearth,
  );
}

int memoryArtifactCount(GameState state, List<Quest> quests) =>
    memoryCollection(state, quests).length;

String _noteTitle(Note note) {
  final text = note.text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) return 'A moment in pictures';
  final first = text.split(RegExp(r'[.!?\n]')).first.trim();
  if (first.length <= 30) return first;
  return '${first.substring(0, 27).trim()}…';
}
