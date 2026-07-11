import 'package:flutter/material.dart';

import '../audio.dart';
import '../clock.dart';
import '../engine.dart';
import '../journal_media.dart' as media;
import '../models.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/glass.dart';
import '../widgets/notes_sheet.dart';
import 'journal_entry.dart';

/// The Journal hub (round-45) — the discoverable home for notes. The feature
/// always existed but lived buried (long-press a quest, a goal's panel, a
/// domain's base), so the owner "didn't see it anywhere." This gathers EVERY
/// note you've kept — free journal entries, domain notes, goal notes, quest
/// logs — into one reverse-chronological feed, and gives the free journal a
/// real place to write. Notes still live on their thing (notes-with-
/// consequence); this is the window onto all of them. (round-61: a search
/// field, month headers, photo thumbnails, and a lazy feed so a year of daily
/// journaling scrolls smoothly.)
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
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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

  /// The feed after the search box — matches on the note text, its source
  /// label, and the "written as" title, case-insensitive.
  List<_Entry> _visible() {
    final all = _all();
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where(
          (e) =>
              e.note.text.toLowerCase().contains(q) ||
              e.source.toLowerCase().contains(q) ||
              (e.note.context?.toLowerCase().contains(q) ?? false),
        )
        .toList();
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
          reduceMotion: _s.reduceMotion,
          heading: 'Journal',
          hint: 'What’s on your mind today?',
          commit: _commit,
          onDelete: _deleteJournal,
        ),
      ),
    );
  }

  /// Insert-or-replace and hand the saved Note back so the editor keeps
  /// autosaving into the same entry. setJournal notifies GameState, which the
  /// shell already persists on — so we do NOT also call widget.onPersist here
  /// (that double-encoded the whole save blob on every 650ms autosave tick).
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
    return updated;
  }

  /// Remove an entry AND its device-local photos (they'd be orphaned forever
  /// otherwise — nothing else references the files). setJournal's notify
  /// persists via the shell listener, so no explicit onPersist here either.
  void _deleteJournal(Note n) {
    for (final f in n.images) {
      media.delete(f);
    }
    _s.setJournal(_s.journal.without(n));
  }

  /// Peek a note that lives on a quest / goal / domain — with a deep-link
  /// into the editable notes sheet so the hub isn't a dead end.
  void _peek(_Entry e) {
    Sfx.instance.play('tick');
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GlassPanel(
            tint: const Color(0xF22A211D),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _chip(e.source, e.color),
                    const SizedBox(width: 8),
                    Text(
                      relativeWhen(e.note.at),
                      style: Type.label.copyWith(
                        fontSize: 10.5,
                        color: Palette.textLo,
                      ),
                    ),
                    if (e.note.editedAt != null)
                      Text(
                        '  ·  edited',
                        style: Type.label.copyWith(
                          fontSize: 10.5,
                          color: Palette.textLo,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      e.note.text.isEmpty ? 'Photo entry' : e.note.text,
                      style: Type.body.copyWith(
                        fontSize: 15,
                        height: 1.4,
                        color: Palette.textHi,
                      ),
                    ),
                  ),
                ),
                if (e.note.context != null && e.note.context!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'written as ${e.note.context}',
                    style: Type.label.copyWith(
                      fontSize: 10,
                      color: e.color.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(sheetCtx).pop();
                      _openEditable(e);
                    },
                    child: Text(
                      'OPEN TO EDIT',
                      style: Type.label.copyWith(color: Palette.xp),
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

  void _openEditable(_Entry e) {
    if (e.source.startsWith('QUEST · ')) {
      final title = e.source.substring('QUEST · '.length);
      final q = widget.quests.cast<Quest?>().firstWhere(
        (x) => x!.title == title || x.displayTitle == title,
        orElse: () => null,
      );
      if (q == null) return;
      showNotesSheet(
        context,
        kicker: 'LOG',
        title: q.displayTitle,
        accent: q.stat.color,
        icon: Icons.edit_note,
        read: () => q.log,
        onAdd: (text) {
          q.addNote(text, Clock.now());
          widget.onPersist();
          setState(() {});
        },
        onDelete: (n) {
          q.log = q.log.without(n);
          widget.onPersist();
          setState(() {});
        },
        onEdit: (orig, text) {
          q.log = q.log.replacing(
            orig.copyWith(text: text, editedAt: Clock.now()),
          );
          widget.onPersist();
          setState(() {});
        },
      );
      return;
    }
    if (e.source.startsWith('GOAL · ')) {
      final title = e.source.substring('GOAL · '.length);
      final g = _s.goals.cast<Goal?>().firstWhere(
        (x) => x!.title == title,
        orElse: () => null,
      );
      if (g == null) return;
      showNotesSheet(
        context,
        kicker: 'JOURNAL',
        title: g.title,
        accent: g.stat.color,
        icon: Icons.menu_book_outlined,
        read: () => g.notes,
        onAdd: (text) {
          g.notes = g.notes.withNote(text, Clock.now());
          widget.onPersist();
          setState(() {});
        },
        onDelete: (n) {
          g.notes = g.notes.without(n);
          widget.onPersist();
          setState(() {});
        },
        onEdit: (orig, text) {
          g.notes = g.notes.replacing(
            orig.copyWith(text: text, editedAt: Clock.now()),
          );
          widget.onPersist();
          setState(() {});
        },
      );
      return;
    }
    // domain note
    final stat = Stat.values.cast<Stat?>().firstWhere(
      (s) => s!.label.toUpperCase() == e.source,
      orElse: () => null,
    );
    if (stat == null) return;
    showNotesSheet(
      context,
      kicker: 'NOTES',
      title: stat.label,
      accent: stat.color,
      icon: Icons.auto_stories_outlined,
      read: () => _s.notesFor(stat),
      onAdd: (text) {
        _s.setDomainNotes(stat, _s.notesFor(stat).withNote(text, Clock.now()));
        widget.onPersist();
        setState(() {});
      },
      onDelete: (n) {
        _s.setDomainNotes(stat, _s.notesFor(stat).without(n));
        widget.onPersist();
        setState(() {});
      },
      onEdit: (orig, text) {
        _s.setDomainNotes(
          stat,
          _s
              .notesFor(stat)
              .replacing(orig.copyWith(text: text, editedAt: Clock.now())),
        );
        widget.onPersist();
        setState(() {});
      },
    );
  }

  static String _monthLabel(DateTime d) {
    const months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _s,
      builder: (context, _) {
        final total =
            _s.journal.length +
            Stat.values.fold<int>(0, (a, s) => a + _s.notesFor(s).length) +
            _s.goals.fold<int>(0, (a, g) => a + g.notes.length) +
            widget.quests.fold<int>(0, (a, q) => a + q.log.length);
        final visible = _visible();

        // flatten into a lazy item stream: a month-header string wherever the
        // month changes, then the entry rows under it
        final items = <Object>[];
        String? lastMonth;
        for (final e in visible) {
          final m = _monthLabel(e.note.at);
          if (m != lastMonth) {
            items.add(m);
            lastMonth = m;
          }
          items.add(e);
        }

        return Scaffold(
          backgroundColor: Palette.parchment,
          body: WarmBackground(
            themeId: _s.canvasTheme,
            reduceMotion: _s.reduceMotion,
            tint: Palette.xp,
            child: SafeArea(
              child: Column(
                children: [
                  DetailHeader(
                    title: 'Journal',
                    accent: Palette.xp,
                    subtitle: 'everything you’ve kept, in one place',
                    pill: '$total',
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
                      // +2 header slots (composer, search); +1 footer note
                      itemCount: total == 0 ? 2 : items.length + 3,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _composer(),
                          );
                        }
                        if (total == 0) return _emptyHint();
                        if (i == 1) return _searchField();
                        final idx = i - 2;
                        if (idx < items.length) {
                          final it = items[idx];
                          if (it is String) return _monthHeader(it);
                          return _card(it as _Entry);
                        }
                        // footer
                        if (visible.isEmpty) {
                          return _noMatch();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Notes live on your quests, goals and domains too — '
                            'open any of them to add more.',
                            textAlign: TextAlign.center,
                            style: Type.body.copyWith(
                              fontSize: 11.5,
                              fontStyle: FontStyle.italic,
                              color: Palette.textLo,
                            ),
                          ),
                        );
                      },
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

  Widget _searchField() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: Palette.textLo),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim()),
              cursorColor: Palette.xp,
              style: Type.body.copyWith(fontSize: 14, color: Palette.textHi),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: InputBorder.none,
                hintText: 'Search your notes',
                hintStyle: Type.body.copyWith(
                  fontSize: 14,
                  color: Palette.textLo,
                ),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _search.clear();
                setState(() => _query = '');
                FocusScope.of(context).unfocus();
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: Palette.textLo),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _monthHeader(String label) => Padding(
    padding: const EdgeInsets.only(left: 4, top: 10, bottom: 8),
    child: Text(
      label,
      style: Type.label.copyWith(
        fontSize: 11,
        color: Palette.textLo,
        letterSpacing: 1.5,
      ),
    ),
  );

  Widget _noMatch() => Padding(
    padding: const EdgeInsets.only(top: 30),
    child: Column(
      children: [
        Icon(Icons.search_off, size: 24, color: Palette.textLo),
        const SizedBox(height: 10),
        Text(
          'nothing matches — yet',
          style: Type.body.copyWith(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: Palette.textLo,
          ),
        ),
      ],
    ),
  );

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
            child: const Icon(
              Icons.edit_note,
              size: 26,
              color: Palette.onHoney,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Write a new entry',
                  style: Type.display.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 2),
                Text(
                  'a whole page to think out loud — saved as you go',
                  style: Type.body.copyWith(
                    fontSize: 12.5,
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

  Widget _emptyHint() => GlassPanel(
    child: Column(
      children: [
        const Icon(
          Icons.auto_stories_outlined,
          size: 26,
          color: Palette.xpLight,
        ),
        const SizedBox(height: 10),
        Text(
          'Your journal is open',
          style: Type.display.copyWith(fontSize: 19),
        ),
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

  /// One entry as its own glass card slice — journal rows reopen the editor,
  /// the rest open a read-only peek (they live on their quest/goal/domain).
  Widget _card(_Entry e) {
    final photoOnly = e.note.text.isEmpty && e.note.images.isNotEmpty;
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
                style: Type.label.copyWith(
                  fontSize: 10.5,
                  color: Palette.textLo,
                ),
              ),
              if (e.note.editedAt != null)
                Text(
                  '  ·  edited',
                  style: Type.label.copyWith(
                    fontSize: 10.5,
                    color: Palette.textLo,
                  ),
                ),
              const Spacer(),
              // no one-tap delete here — a whole page of writing dies too
              // easily to a 15px X. The row opens the editor, whose delete
              // asks first (and cleans up the entry's photos).
              Icon(
                e.journal ? Icons.chevron_right : Icons.visibility_outlined,
                size: 15,
                color: Palette.textLo,
              ),
            ],
          ),
          if (e.note.text.isNotEmpty || photoOnly) ...[
            const SizedBox(height: 6),
            Text(
              photoOnly ? 'Photo entry' : e.note.text,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: Type.body.copyWith(
                fontSize: 14,
                color: photoOnly ? Palette.textLo : Palette.textHi,
                height: 1.3,
                fontStyle: photoOnly ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ],
          if (e.note.images.isNotEmpty) _thumbs(e.note.images),
          if (e.note.context != null && e.note.context!.isNotEmpty) ...[
            const SizedBox(height: 4),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => e.journal ? _openEditor(entry: e.note) : _peek(e),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        child: body,
      ),
    );
  }

  /// A little strip of rounded photo thumbnails for entries that carry images
  /// (native only — media.image is a no-op on web). Caps at 3 with a "+N".
  Widget _thumbs(List<String> images) {
    const max = 3;
    final shown = images.take(max).toList();
    final extra = images.length - shown.length;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          for (final name in shown) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 52,
                height: 52,
                child: media.image(name, maxHeight: 52),
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (extra > 0)
            Container(
              width: 40,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.black.withValues(alpha: 0.18),
              ),
              child: Text(
                '+$extra',
                style: Type.label.copyWith(fontSize: 12, color: Palette.textLo),
              ),
            ),
        ],
      ),
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
      style: Type.label.copyWith(fontSize: 9.5, color: c, letterSpacing: 0.8),
    ),
  );
}
