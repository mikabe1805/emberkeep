import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../clock.dart';
import '../content/memories.dart';
import '../content/stat_ranks.dart';
import '../engine.dart';
import '../journal_media.dart' as media;
import '../models.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/facets.dart';
import '../widgets/glass.dart';
import '../widgets/night_reflection_sheet.dart';
import '../widgets/notes_sheet.dart';
import 'journal_entry.dart';
import 'memory_cabinet.dart';

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
    this.compose = false,
  });

  final GameState state;
  final List<Quest> quests;
  final VoidCallback onPersist;
  final bool compose;

  @override
  State<JournalHubScreen> createState() => _JournalHubScreenState();
}

class _Entry {
  _Entry(
    this.note,
    this.source,
    this.color, {
    this.journal = false,
    this.currentContext,
  });
  final Note note;
  final String source;
  final Color color;
  final bool journal; // a free entry (deletable here)
  final String? currentContext;
}

class _JournalHubScreenState extends State<JournalHubScreen> {
  GameState get _s => widget.state;
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.compose) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openEditor();
      });
    }
  }

  JournalTrace _todayTrace() => _s.todayJournalTrace(widget.quests);

  String _traceLine(JournalTrace trace) {
    final parts = <String>[];
    if (trace.questTitles.isNotEmpty) {
      parts.add(
        '${trace.questTitles.length} ${trace.questTitles.length == 1 ? 'quest' : 'quests'}',
      );
    }
    if (trace.todayXp > 0) parts.add('+${trace.todayXp} XP');
    final strongest = trace.statGains.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (strongest.isNotEmpty) {
      parts.add(
        '${strongest.first.key.label.toUpperCase()} +${strongest.first.value}',
      );
    }
    if (parts.isEmpty) parts.add('LEVEL ${trace.level}');
    return parts.join('  ·  ');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_Entry> _all() {
    final out = <_Entry>[];
    for (final n in _s.journal) {
      out.add(
        _Entry(
          n,
          'JOURNAL',
          Palette.xp,
          journal: true,
          currentContext: _s.buildTitle,
        ),
      );
    }
    for (final st in Stat.values) {
      for (final n in _s.notesFor(st)) {
        out.add(
          _Entry(
            n,
            st.label.toUpperCase(),
            st.color,
            currentContext: rankFor(st, _s.stats[st] ?? 0).label,
          ),
        );
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

  String _contextLine(_Entry entry) {
    final then = entry.note.context?.trim();
    if (then == null || then.isEmpty) return '';
    final now = entry.currentContext?.trim();
    Stat? domain;
    for (final stat in Stat.values) {
      if (entry.source == stat.label.toUpperCase()) {
        domain = stat;
        break;
      }
    }
    if (domain != null) {
      final before = 'written when ${domain.label.toUpperCase()} was $then';
      if (now == null ||
          now.isEmpty ||
          now.toLowerCase() == then.toLowerCase()) {
        return before;
      }
      return '$before · now $now';
    }
    if (now == null || now.isEmpty || now.toLowerCase() == then.toLowerCase()) {
      return 'written as $then';
    }
    return 'written as $then · now $now';
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
  Future<void> _openEditor({
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
        reduceMotion: _s.reduceMotion,
      ).then((data) {
        if (!mounted || data == null) return;
        _s.updateNightJournalEntry(entry, data);
      });
    }
    final trace = entry == null ? _todayTrace() : entry.trace;
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => JournalEntryScreen(
          initial: entry,
          accent: Palette.xp,
          themeId: _s.canvasTheme,
          reduceMotion: _s.reduceMotion,
          heading: heading,
          hint: hint,
          starter: starter ?? _starterFor(entry),
          trace: trace,
          initiallyEditing: initiallyEditing,
          onEditRequested: entry != null && night != null
              ? (readerContext) async {
                  final data = await showNightReflectionSheet(
                    readerContext,
                    initial: night,
                    reduceMotion: _s.reduceMotion,
                  );
                  if (!readerContext.mounted || data == null) return;
                  _s.updateNightJournalEntry(entry, data);
                  if (readerContext.mounted) {
                    Navigator.of(readerContext).pop();
                  }
                }
              : null,
          commit: (payload, existing, markEdited) =>
              _commit(payload, existing, markEdited, trace),
          onDelete: _deleteJournal,
        ),
      ),
    );
  }

  String? _starterFor(Note? entry) {
    final source = entry?.sourceQuestKey;
    if (source == null || source.isEmpty) return null;
    for (final quest in widget.quests) {
      if (quest.title == source) return quest.journalPrompt?.starter;
    }
    return null;
  }

  /// Insert-or-replace and hand the saved Note back so the editor keeps
  /// autosaving into the same entry. setJournal notifies GameState, which the
  /// shell already persists on — so we do NOT also call widget.onPersist here
  /// (that double-encoded the whole save blob on every 650ms autosave tick).
  Note _commit(
    JournalPayload payload,
    Note? existing,
    bool markEdited,
    JournalTrace? trace,
  ) {
    if (existing == null) {
      // stamp who you were when you wrote it — proof of becoming
      final note = Note(
        at: Clock.now(),
        text: payload.text,
        context: _s.buildTitle,
        rich: payload.rich,
        images: payload.images,
        trace: trace,
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
    Sfx.instance.playMaterial(MaterialSound.parchment);
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
                        fontSize: Type.minLabel,
                        color: Palette.textLo,
                      ),
                    ),
                    if (e.note.editedAt != null)
                      Text(
                        '  ·  edited',
                        style: Type.label.copyWith(
                          fontSize: Type.minLabel,
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
                    _contextLine(e),
                    style: Type.label.copyWith(
                      fontSize: Type.minLabel,
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
                      // composer + cabinet + search, then the lazy feed/footer
                      itemCount: total == 0 ? 3 : items.length + 4,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _composer(),
                          );
                        }
                        if (i == 1) return _cabinetCard();
                        if (total == 0) return _emptyHint();
                        if (i == 2) return _searchField();
                        final idx = i - 3;
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

  Widget _cabinetCard() {
    final count = memoryArtifactCount(_s, widget.quests);
    final chosen = _s.memoryPins.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Sfx.instance.playMaterial(MaterialSound.wood);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  MemoryCabinetScreen(state: _s, quests: widget.quests),
            ),
          );
        },
        child: GlassPanel(
          glow: count > 0,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const FacetMedallion(
                size: 42,
                accent: Palette.unlock,
                glow: true,
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 21,
                  color: Palette.unlock,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keepsakes',
                      style: Type.display.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 0
                          ? 'turn moments and milestones into things your space can hold'
                          : '$count artifacts · $chosen ${chosen == 1 ? 'moment' : 'moments'} chosen by you',
                      style: Type.body.copyWith(
                        fontSize: 11.5,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 19, color: Palette.textLo),
            ],
          ),
        ),
      ),
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
  Widget _composer() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openEditor(),
        child: GlassPanel(
          glow: true,
          child: Row(
            children: [
              const FacetMedallion(
                size: 44,
                accent: Palette.xp,
                gradient: Palette.honeyGradient,
                glow: true,
                child: Icon(Icons.edit_note, size: 26, color: Palette.onHoney),
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
      ),
      const SizedBox(height: 10),
      _todayThread(),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'A WAY IN, IF YOU WANT ONE',
          style: Type.label.copyWith(
            fontSize: Type.minLabel,
            color: Palette.textLo,
          ),
        ),
      ),
      const SizedBox(height: 7),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (_s.todayQuestTitles.isNotEmpty)
              _promptChip(
                Icons.route_rounded,
                'QUEST THREAD',
                'After the quest',
                'What made it easier, harder, or worth repeating?',
                'After “${_s.todayQuestTitles.last}”:\n',
              )
            else
              _promptChip(
                Icons.auto_awesome,
                'SMALL WIN',
                'A small win',
                'Start with something that counted, even if nobody saw it.',
                'One small win today:\n',
              ),
            _promptChip(
              Icons.air,
              'UNLOAD',
              'Set it down',
              'Name what felt heavy. You do not need to solve it here.',
              'What felt heavy:\n',
            ),
            _promptChip(
              Icons.favorite_border,
              'GRATEFUL',
              'A warm detail',
              'Hold onto one person, place, or moment you are grateful for.',
              'Something I’m grateful for:\n',
            ),
            _promptChip(
              Icons.north_east,
              'TOMORROW',
              'The next step',
              'Make tomorrow smaller: what is the first gentle move?',
              'Tomorrow’s first step:\n',
            ),
          ],
        ),
      ),
    ],
  );

  Widget _todayThread() {
    final trace = _todayTrace();
    final hasQuests = trace.questTitles.isNotEmpty;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      tint: const Color(0xE8251C17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FacetMedallion(
            size: 34,
            accent: hasQuests ? Palette.success : Palette.xp,
            glow: hasQuests,
            child: Icon(
              hasQuests ? Icons.link_rounded : Icons.bookmark_add_outlined,
              size: 17,
              color: hasQuests ? Palette.success : Palette.xpLight,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TODAY’S THREAD',
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    color: Palette.xpLight,
                    letterSpacing: 1.35,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasQuests
                      ? '${_traceLine(trace)} — attached automatically when you write.'
                      : 'The date, your build, and what you’ve completed so far today attach to this page.',
                  style: Type.body.copyWith(
                    fontSize: 11.8,
                    height: 1.35,
                    color: Palette.textLo,
                  ),
                ),
                if (hasQuests) ...[
                  const SizedBox(height: 6),
                  Text(
                    trace.questTitles.take(2).join('  ·  '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Type.body.copyWith(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: Palette.textMid,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _promptChip(
    IconData icon,
    String label,
    String heading,
    String hint,
    String starter,
  ) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: Semantics(
      button: true,
      label: 'Start journal prompt: $label',
      child: GestureDetector(
        onTap: () =>
            _openEditor(heading: heading, hint: hint, starter: starter),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: facetedDecoration(
            cut: 7,
            color: Palette.xp.withValues(alpha: 0.08),
            borderColor: Palette.xp.withValues(alpha: 0.28),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: Palette.xpLight),
              const SizedBox(width: 6),
              Text(
                label,
                style: Type.label.copyWith(
                  fontSize: Type.minLabel,
                  color: Palette.xpLight,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _emptyHint() => GlassPanel(
    child: Column(
      children: [
        const Icon(Icons.edit_note_rounded, size: 26, color: Palette.xpLight),
        const SizedBox(height: 10),
        Text(
          'Your first page is ready',
          style: Type.display.copyWith(fontSize: 19),
        ),
        const SizedBox(height: 6),
        Text(
          'Write one line above. Your journal keeps the date, today’s quests, '
          'your goal threads, and the build you had when you wrote it — no '
          'manual tagging required.',
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

  /// One entry as its own glass card slice — journal rows open as a page to
  /// read first; the rest use a peek (they live on their quest/goal/domain).
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
                  fontSize: Type.minLabel,
                  color: Palette.textLo,
                ),
              ),
              if (e.note.editedAt != null)
                Text(
                  '  ·  edited',
                  style: Type.label.copyWith(
                    fontSize: Type.minLabel,
                    color: Palette.textLo,
                  ),
                ),
              const Spacer(),
              Semantics(
                button: true,
                toggled: _s.memoryPins.contains(e.note.id),
                label: _s.memoryPins.contains(e.note.id)
                    ? 'Remove from Keepsakes'
                    : 'Keep in Keepsakes',
                onTap: () {
                  final pinned = !_s.memoryPins.contains(e.note.id);
                  _s.setMemoryPinned(e.note.id, pinned);
                  Sfx.instance.play(pinned ? 'streak' : 'tick');
                  HapticFeedback.selectionClick();
                },
                child: GestureDetector(
                  excludeFromSemantics: true,
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    final pinned = !_s.memoryPins.contains(e.note.id);
                    _s.setMemoryPinned(e.note.id, pinned);
                    Sfx.instance.play(pinned ? 'streak' : 'tick');
                    HapticFeedback.selectionClick();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      _s.memoryPins.contains(e.note.id)
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      size: 17,
                      color: _s.memoryPins.contains(e.note.id)
                          ? Palette.unlock
                          : Palette.textLo,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
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
              _contextLine(e),
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                color: e.color.withValues(alpha: 0.8),
              ),
            ),
          ],
          if (e.journal && e.note.trace?.hasDayEvidence == true) ...[
            const SizedBox(height: 5),
            Text(
              _traceLine(e.note.trace!),
              style: Type.label.copyWith(
                fontSize: Type.minLabel,
                color: Palette.xpLight.withValues(alpha: 0.78),
              ),
            ),
          ],
        ],
      ),
    );
    return Semantics(
      button: true,
      label: e.journal ? 'Read journal entry' : 'Read ${e.source} note',
      child: GestureDetector(
        key: ValueKey('journal-card-${e.note.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => e.journal
            ? _openEditor(entry: e.note, initiallyEditing: false)
            : _peek(e),
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          child: body,
        ),
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
            ClipPath(
              clipper: const FacetedClipper(cut: 7),
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
              decoration: facetedDecoration(
                cut: 7,
                color: Colors.black.withValues(alpha: 0.18),
                borderColor: Palette.glassEdge,
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
    decoration: facetedDecoration(
      cut: 4,
      color: c.withValues(alpha: 0.14),
      borderColor: c.withValues(alpha: 0.2),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Type.label.copyWith(
        fontSize: Type.minLabel,
        color: c,
        letterSpacing: 0.8,
      ),
    ),
  );
}
