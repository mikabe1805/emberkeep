import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../clock.dart';
import '../engine.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/detail_header.dart';
import '../widgets/glass.dart';
import '../widgets/notes_sheet.dart' show relativeWhen;

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
  final _controller = TextEditingController();
  final _focus = FocusNode();

  GameState get _s => widget.state;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
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

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Sfx.instance.play('tick');
    HapticFeedback.selectionClick();
    // stamp who you were when you wrote it — proof of becoming
    _s.setJournal(
      _s.journal.withNote(text, Clock.now(), context: _s.buildTitle),
    );
    widget.onPersist();
    _controller.clear();
    _focus.requestFocus();
  }

  void _deleteJournal(Note n) {
    Sfx.instance.play('boing');
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

  Widget _composer() => GlassPanel(
        blur: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_stories_outlined,
                    size: 16, color: Palette.xp),
                const SizedBox(width: 8),
                Text('NEW ENTRY',
                    style: Type.label.copyWith(fontSize: 12, color: Palette.xp)),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              focusNode: _focus,
              maxLines: null,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              style: Type.body.copyWith(fontSize: 14, color: Palette.textHi),
              cursorColor: Palette.xp,
              decoration: InputDecoration(
                hintText: 'What’s on your mind today?',
                hintStyle:
                    Type.body.copyWith(fontSize: 14, color: Palette.textLo),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _add,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: Palette.honeyGradient,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 16, color: Palette.onHoney),
                      const SizedBox(width: 5),
                      Text('Keep it',
                          style: Type.label.copyWith(
                              fontSize: 12, color: Palette.onHoney)),
                    ],
                  ),
                ),
              ),
            ),
          ],
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

  Widget _row(_Entry e) => Padding(
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
                      fontSize: 10, color: Palette.textLo),
                ),
                const Spacer(),
                if (e.journal)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _deleteJournal(e.note),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close,
                          size: 15, color: Palette.textLo),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              e.note.text,
              style: Type.body.copyWith(
                  fontSize: 14, color: Palette.textHi, height: 1.3),
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
