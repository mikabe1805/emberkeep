import 'package:flutter/material.dart';

import '../audio.dart';
import '../clock.dart';
import '../engine.dart';
import '../journal_media.dart' as media;
import '../models.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/glass.dart';
import '../widgets/notes_sheet.dart' show relativeWhen;
import 'journal_entry.dart';

/// The Journal hub (round-45) — the discoverable home for notes. The feature
/// always existed but lived buried (long-press a quest, a goal's panel, a
/// domain's base), so the owner "didn't see it anywhere." This gathers EVERY
/// note you've kept — free journal entries, domain notes, goal notes, quest
/// logs — into one reverse-chronological feed, and gives the free journal a
/// real place to write. Notes still live on their thing (notes-with-
/// consequence); this is the window onto all of them.
class JournalHubScreen extends StatefulWidget {
  const JournalHubScreen({
    super.key,
    required this.state,
    required this.quests,
    required this.onPersist,
  });

  final GameState state;
  final List<Quest> quests;
  final VoidCallback onPersist;

  @override
  State<JournalHubScreen> createState() => _JournalHubScreenState();
}

class _Entry {
  _Entry(this.note, this.source, this.color, {this.journal = false});
  final Note note;
  final String source;
  final Color color;
  final bool journal; // a free entry (deletable here)
}

class _JournalHubScreenState extends State<JournalHubScreen> {
  GameState get _s => widget.state;

  List<_Entry> _all() {
    final out = <_Entry>[];
    for (final n in _s.journal) {
      out.add(_Entry(n, 'JOURNAL', Palette.xp, journal: true));
    }
    for (final st in Stat.values) {
      for (final n in _s.notesFor(st)) {
        out.add(_Entry(n, st.label.toUpperCase(), st.color));
      }
    }
    for (final g in _s.goals) {
      for (final n in g.notes) {
        out.add(_Entry(n, 'GOAL · ${g.title}', g.stat.color));
      }
    }
    for (final q in widget.quests) {
      for (final n in q.log) {
        out.add(_Entry(n, 'QUEST · ${q.title}', q.stat.color));
      }
    }
    out.sort((a, b) => b.note.at.compareTo(a.note.at));
    return out;
  }

  /// Open the full-page editor — for a brand-new entry, or to keep writing an
  /// existing one (notes are editable now, not write-once).
  void _openEditor({Note? entry}) {
    Sfx.instance.play('tick');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JournalEntryScreen(
          initial: entry,
          accent: Palette.xp,
          themeId: _s.canvasTheme,
          heading: 'Journal',
          hint: 'What’s on your mind today?',
          commit: _commit,
          onDelete: _deleteJournal,
        ),
      ),
    );
  }

  /// Insert-or-replace, persist, and hand the saved Note back so the editor
  /// keeps autosaving into the same entry. Silent (autosave fires often).
  Note _commit(JournalPayload payload, Note? existing, bool markEdited) {
    if (existing == null) {
      // stamp who you were when you wrote it — proof of becoming
      final note = Note(
        at: Clock.now(),
        text: payload.text,
        context: _s.buildTitle,
        rich: payload.rich,
        images: payload.images,
      );
      _s.setJournal([..._s.journal, note]);
      widget.onPersist();
      return note;
    }
    // markEdited only when this entry pre-existed the editor session; passing
    // null to copyWith leaves the original editedAt untouched.
    final updated = existing.copyWith(
      text: payload.text,
      rich: payload.rich,
      images: payload.images,
      editedAt: markEdited ? Clock.now() : null,
    );
    _s.setJournal(_s.journal.replacing(updated));
    widget.onPersist();
    return updated;
  }

  /// Remove an entry AND its device-local photos (they'd be orphaned forever
  /// otherwise — nothing else references the files). Silent: the editor's
  /// confirmed delete plays its own sound, and the autosave path is quiet.
  void _deleteJournal(Note n) {
    for (final f in n.images) {
      media.delete(f);
    }
    _s.setJournal(_s.journal.without(n));
    widget.onPersist();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _s,
      builder: (context, _) {
        final all = _all();
        return Scaffold(
          backgroundColor: Palette.parchment,
          body: WarmBackground(
            themeId: _s.canvasTheme,
            tint: Palette.xp,
            child: SafeArea(
              child: Column(
                children: [
                  DetailHeader(
                    title: 'Journal',
                    accent: Palette.xp,
                    subtitle: 'everything you’ve kept, in one place',
                    pill: '${all.length}',
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
                      children: [
                        _composer(),
                        const SizedBox(height: 16),
                        if (all.isEmpty)
                          _emptyHint()
                        else ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'EVERYTHING YOU’VE KEPT',
                              style: Type.label.copyWith(
                                fontSize: 11,
                                color: Palette.textLo,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          GlassPanel(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: Column(
                              children: [
                                for (var i = 0; i < all.length; i++) ...[
                                  if (i > 0)
                                    Divider(
                                      height: 1,
                                      color:
                                          Palette.textLo.withValues(alpha: 0.12),
                                    ),
                                  _row(all[i]),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Notes live on your quests, goals and domains too — '
                            'open any of them to add more.',
                            textAlign: TextAlign.center,
                            style: Type.body.copyWith(
                              fontSize: 11.5,
                              fontStyle: FontStyle.italic,
                              color: Palette.textLo,
                            ),
                          ),
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

  /// A prominent invitation into the full-page editor — a whole page to write
  /// on, not a cramped two-line box. (round-53)
  Widget _composer() => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openEditor(),
        child: GlassPanel(
          glow: true,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: Palette.honeyGradient,
                  boxShadow: const [
                    BoxShadow(color: Palette.honeyGlow, blurRadius: 14),
                  ],
                ),
                child: const Icon(Icons.edit_note,
                    size: 26, color: Palette.onHoney),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Write a new entry',
                        style: Type.display.copyWith(fontSize: 17)),
                    const SizedBox(height: 2),
                    Text(
                      'a whole page to think out loud — saved as you go',
                      style: Type.body.copyWith(
                          fontSize: 12.5, color: Palette.textLo),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: Palette.textLo),
            ],
          ),
        ),
      );

  Widget _emptyHint() => GlassPanel(
        child: Column(
          children: [
            const Icon(Icons.auto_stories_outlined,
                size: 26, color: Palette.xpLight),
            const SizedBox(height: 10),
            Text('Your journal is open',
                style: Type.display.copyWith(fontSize: 19)),
            const SizedBox(height: 6),
            Text(
              'Jot a thought above — how today went, what you’re tracking, '
              'what you’re grateful for. Anything you note on a quest, goal '
              'or domain shows up here too.',
              textAlign: TextAlign.center,
              style: Type.body.copyWith(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            ),
          ],
        ),
      );

  Widget _row(_Entry e) {
    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: _chip(e.source, e.color)),
              const SizedBox(width: 8),
              Text(
                relativeWhen(e.note.at),
                style: Type.label.copyWith(fontSize: 10, color: Palette.textLo),
              ),
              if (e.note.editedAt != null)
                Text(
                  '  ·  edited',
                  style:
                      Type.label.copyWith(fontSize: 10, color: Palette.textLo),
                ),
              if (e.note.images.isNotEmpty) ...[
                const SizedBox(width: 6),
                Icon(Icons.photo_outlined, size: 12, color: e.color),
                const SizedBox(width: 2),
                Text('${e.note.images.length}',
                    style: Type.label.copyWith(fontSize: 10, color: e.color)),
              ],
              const Spacer(),
              // no one-tap delete here — a whole page of writing dies too
              // easily to a 15px X. The row opens the editor, whose delete
              // asks first (and cleans up the entry's photos).
              if (e.journal)
                const Icon(Icons.chevron_right,
                    size: 15, color: Palette.textLo),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            // a photo-only entry still reads nicely in the feed
            e.note.text.isEmpty && e.note.images.isNotEmpty
                ? 'Photo entry'
                : e.note.text,
            // entries can be whole pages now — show a tidy preview in the feed.
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: Type.body.copyWith(
              fontSize: 14,
              color: e.note.text.isEmpty && e.note.images.isNotEmpty
                  ? Palette.textLo
                  : Palette.textHi,
              height: 1.3,
              fontStyle: e.note.text.isEmpty && e.note.images.isNotEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
          if (e.note.context != null && e.note.context!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              'written as ${e.note.context}',
              style: Type.label.copyWith(
                fontSize: 9.5,
                color: e.color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
    if (!e.journal) return body;
    // a free journal entry opens back up to keep writing — tap to continue.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openEditor(entry: e.note),
      child: body,
    );
  }

  Widget _chip(String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: c.withValues(alpha: 0.14),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Type.label.copyWith(
              fontSize: 9, color: c, letterSpacing: 0.8),
        ),
      );
}
