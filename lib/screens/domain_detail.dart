import 'package:flutter/material.dart';

import '../clock.dart';
import '../content/evidence.dart';
import '../content/stat_ranks.dart';
import '../engine.dart';
import '../models.dart';
import '../tokens.dart';
import '../widgets/count_up.dart';
import '../widgets/detail_header.dart';
import '../widgets/ember_sheet.dart';
import '../widgets/glass.dart';
import '../widgets/notes_sheet.dart';

/// A life-domain's "base" (round-24, the keystone of notes-with-consequence):
/// tap a domain on the Me page to open its page — its growth (level + rank +
/// recent gains), a journal kept ON the domain, the quests serving it, and why
/// it matters. Every note here sits on something the game already levels up —
/// which is exactly what a blank Notion page can never offer.
class DomainDetailScreen extends StatefulWidget {
  const DomainDetailScreen({
    super.key,
    required this.stat,
    required this.state,
    required this.quests,
    required this.onPersist,
    required this.onAddQuest,
  });

  final Stat stat;
  final GameState state;
  final List<Quest> quests;
  final VoidCallback onPersist;
  final bool Function(Quest quest) onAddQuest;

  @override
  State<DomainDetailScreen> createState() => _DomainDetailScreenState();
}

class _DomainDetailScreenState extends State<DomainDetailScreen> {
  Stat get _stat => widget.stat;
  Color get _accent => _stat.color;

  @override
  Widget build(BuildContext context) {
    final now = Clock.now();
    final value = widget.state.stats[_stat] ?? 0;
    final rank = rankFor(_stat, value);
    final domainQuests = widget.quests
        .where((q) => q.stat == _stat)
        .toList(growable: false);
    final recent = widget.state.ledger
        .where((e) => e.stat == _stat)
        .take(4)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: Palette.parchment,
      body: WarmBackground(
        themeId: widget.state.canvasTheme,
        tint: _accent, // this domain's hue — its own "room"
        child: SafeArea(
          child: Column(
            children: [
              DetailHeader(
                title: _stat.label,
                accent: _accent,
                subtitle: _stat.blurb,
                heroTag: 'domainDot-${_stat.index}',
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  children: [
                    _growthPanel(value, rank, recent),
                    const SizedBox(height: 16),
                    JournalPanel(
                      title: _stat.label,
                      accent: _accent,
                      subtitle:
                          'your ${_stat.label.toLowerCase()}, in your words',
                      hint: 'What’s on your mind?',
                      emptyPreview:
                          'Keep notes on your '
                          '${_stat.label.toLowerCase()} — plans, wins, '
                          'what needs doing.',
                      emptyHint:
                          'No entries yet. This is your space for '
                          '${_stat.label} — plans, wins, what needs doing, '
                          'how it’s feeling.',
                      read: () => widget.state.notesFor(_stat),
                      onAdd: (text) {
                        // stamp the domain's rank now — proof of becoming
                        final rankLabel = rankFor(
                          _stat,
                          widget.state.stats[_stat] ?? 0,
                        ).label;
                        widget.state.setDomainNotes(
                          _stat,
                          widget.state
                              .notesFor(_stat)
                              .withNote(
                                text,
                                DateTime.now(),
                                context: rankLabel,
                              ),
                        );
                        widget.onPersist();
                      },
                      onDelete: (n) {
                        widget.state.setDomainNotes(
                          _stat,
                          widget.state.notesFor(_stat).without(n),
                        );
                        widget.onPersist();
                      },
                      onMakeQuest: (text) async {
                        // a reflection becomes board action — pre-fill the
                        // quest with the note, pre-lit to this domain
                        final q = await showEmberSheet(
                          context,
                          EmberSheetConfig(
                            defaultTitle: text,
                            defaultStat: _stat,
                            accent: _accent,
                          ),
                        );
                        if (q != null) widget.onAddQuest(q);
                      },
                    ),
                    const SizedBox(height: 16),
                    _questsPanel(domainQuests, now),
                    const SizedBox(height: 16),
                    _evidencePanel(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── growth: the number, the rank, the climb, recent gains ─────────
  Widget _growthPanel(int value, StatRank rank, List<LedgerEntry> recent) {
    final t = rankProgress(value);
    return GlassPanel(
      blur: true,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CountUpText(
                value,
                style: Type.numerals.copyWith(fontSize: 40, color: _accent),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _stat.abbr,
                  style: Type.label.copyWith(
                    fontSize: 12,
                    color: Palette.textLo,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: _accent.withValues(alpha: 0.16),
                  border: Border.all(color: _accent.withValues(alpha: 0.45)),
                ),
                child: Text(
                  rank.label.toUpperCase(),
                  style: Type.label.copyWith(fontSize: 12, color: _accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // climb toward the next rank
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: t),
              duration: const Duration(milliseconds: 800),
              curve: Motion.barCurve,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 7,
                backgroundColor: Palette.glassFill,
                valueColor: AlwaysStoppedAnimation(_accent),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rank.tier >= 5
                ? 'the highest rank — ${rank.label}'
                : 'climbing toward ${nextRank(_stat, value).label}',
            style: Type.label.copyWith(fontSize: 11, color: Palette.textLo),
          ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: Palette.glassEdge, height: 1),
            const SizedBox(height: 12),
            Text('RECENT GAINS', style: Type.label.copyWith(fontSize: 11)),
            const SizedBox(height: 8),
            for (final e in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(
                      '+${e.amount}',
                      style: Type.numerals.copyWith(
                        fontSize: 13,
                        color: _accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.title,
                        overflow: TextOverflow.ellipsis,
                        style: Type.body.copyWith(
                          fontSize: 13,
                          color: Palette.textMid,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ── quests serving this domain ────────────────────────────────────
  Widget _questsPanel(List<Quest> quests, DateTime now) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'QUESTS IN THIS DOMAIN',
                style: Type.label.copyWith(fontSize: 11),
              ),
              const Spacer(),
              Text(
                '${quests.length}',
                style: Type.numerals.copyWith(fontSize: 12, color: _accent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (quests.isEmpty)
            Text(
              'No quests training ${_stat.label} yet — adopt one on Goals.',
              style: Type.body.copyWith(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            )
          else
            for (final q in quests)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _accent,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        q.displayTitle,
                        overflow: TextOverflow.ellipsis,
                        style: Type.body.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Palette.textHi,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      q.doneFor(now)
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 18,
                      color: q.doneFor(now)
                          ? Palette.success
                          : _accent.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // ── why this domain matters (evidence) ────────────────────────────
  Widget _evidencePanel() {
    final card = evidenceForStat(_stat);
    if (card == null) return const SizedBox.shrink();
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                size: 15,
                color: Palette.info,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'WHY ${_stat.label.toUpperCase()} MATTERS',
                  style: Type.label.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            card.title,
            style: Type.body.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Palette.textHi,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            card.text,
            style: Type.body.copyWith(fontSize: 13, color: Palette.textMid),
          ),
          const SizedBox(height: 8),
          Text(
            card.source,
            style: Type.label.copyWith(
              fontSize: 11,
              color: Palette.info.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
