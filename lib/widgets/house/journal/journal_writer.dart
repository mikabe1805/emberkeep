// Opens the journal's writing view. One place, so the nook, the Journal hub
// and every row that opens a page do it the same way: the same editor, the
// same save, the same keepsake and delete behaviour. This file does not touch
// the writing view itself (journal_entry.dart).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../audio.dart';
import '../../../clock.dart';
import '../../../engine.dart';
import '../../../journal_media.dart' as media;
import '../../../models.dart';
import '../../../screens/journal_entry.dart';
import '../../../tokens.dart';
import '../../night_reflection_sheet.dart';

class JournalWriter {
  const JournalWriter({required this.state, required this.quests});

  final GameState state;

  /// The live board quests, so a quest thread can offer its own starter and
  /// today's trace can name what was done.
  final List<Quest> quests;

  /// What today carries onto a new page.
  JournalTrace todayTrace() => state.todayJournalTrace(quests);

  /// The starter line of the quest a thread entry came from, if any.
  String? starterFor(Note? entry) {
    final source = entry?.sourceQuestKey;
    if (source == null || source.isEmpty) return null;
    for (final quest in quests) {
      if (quest.title == source) return quest.journalPrompt?.starter;
    }
    return null;
  }

  bool toggleKeepsake(Note entry) {
    final pinned = !state.memoryPins.contains(entry.id);
    state.setMemoryPinned(entry.id, pinned);
    Sfx.instance.play(pinned ? 'streak' : 'tick');
    HapticFeedback.selectionClick();
    return pinned;
  }

  /// Insert-or-replace and hand the saved Note back so the editor keeps
  /// autosaving into the same entry. setJournal notifies GameState, which the
  /// shell already persists on, so nothing else saves here.
  Note commit(
    JournalPayload payload,
    Note? existing,
    bool markEdited,
    JournalTrace? trace,
  ) {
    if (existing == null) {
      // stamp who you were when you wrote it: proof of becoming
      final note = Note(
        at: Clock.now(),
        text: payload.text,
        context: state.buildTitle,
        rich: payload.rich,
        images: payload.images,
        trace: trace,
      );
      state.setJournal([...state.journal, note]);
      return note;
    }
    final updated = existing.copyWith(
      text: payload.text,
      rich: payload.rich,
      images: payload.images,
      editedAt: markEdited ? Clock.now() : null,
    );
    state.setJournal(state.journal.replacing(updated));
    return updated;
  }

  /// Removes an entry and its device-local photos (nothing else references
  /// the files, so they would be orphaned).
  void delete(Note note) {
    for (final filename in note.images) {
      media.delete(filename);
    }
    state.setJournal(state.journal.without(note));
  }

  /// The full-page editor: a brand-new entry (optionally with a prompt's
  /// [heading], [hint] and [starter]), or an existing one, read-first unless
  /// [initiallyEditing].
  Future<void> open(
    BuildContext context, {
    Note? entry,
    String heading = 'Journal',
    String hint = 'What’s on your mind today?',
    String? starter,
    bool initiallyEditing = true,
  }) {
    Sfx.instance.playMaterial(MaterialSound.parchment);
    final night = entry?.night;
    if (entry != null && night != null && initiallyEditing) {
      return showNightReflectionSheet(
        context,
        initial: night,
        reduceMotion: state.reduceMotion,
      ).then((data) {
        if (!context.mounted || data == null) return;
        state.updateNightJournalEntry(entry, data);
      });
    }
    final trace = entry == null ? todayTrace() : entry.trace;
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => JournalEntryScreen(
          initial: entry,
          accent: Palette.xp,
          themeId: state.canvasTheme,
          reduceMotion: state.reduceMotion,
          heading: heading,
          hint: hint,
          starter: starter ?? starterFor(entry),
          trace: trace,
          initiallyEditing: initiallyEditing,
          keepsakePinned: entry == null
              ? null
              : state.memoryPins.contains(entry.id),
          onToggleKeepsake: toggleKeepsake,
          onEditRequested: entry != null && night != null
              ? (readerContext) async {
                  final data = await showNightReflectionSheet(
                    readerContext,
                    initial: night,
                    reduceMotion: state.reduceMotion,
                  );
                  if (!readerContext.mounted || data == null) return;
                  state.updateNightJournalEntry(entry, data);
                  if (readerContext.mounted) {
                    Navigator.of(readerContext).pop();
                  }
                }
              : null,
          commit: (payload, existing, markEdited) =>
              commit(payload, existing, markEdited, trace),
          onDelete: delete,
        ),
      ),
    );
  }
}
