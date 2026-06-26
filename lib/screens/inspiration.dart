import 'package:flutter/material.dart';

import '../content/evidence.dart';
import '../engine.dart';
import '../tokens.dart';
import '../widgets/glass.dart';

/// The Sparks page: a cozy feed of evidence cards — the "why this works"
/// voice (DESIGN.md §5). Now personalized — the stats you actually train
/// float to the top — and the deeper archive is the level-4 unlock it was
/// always advertised to be (RESEARCH-momentum.md §7).
class InspirationPage extends StatefulWidget {
  const InspirationPage({super.key, required this.state});

  final GameState state;

  /// The level at which the "EVIDENCE ARCHIVE" unlock (engine.unlocks[4])
  /// opens the last few cards.
  static const archiveGate = 4;

  @override
  State<InspirationPage> createState() => _InspirationPageState();
}

class _InspirationPageState extends State<InspirationPage> {
  /// Cards relevant-but-unseen when the page opened — flagged NEW this visit,
  /// then marked seen so they don't shout next time.
  late final Set<String> _newTitles;

  @override
  void initState() {
    super.initState();
    final s = widget.state;
    _newTitles = {
      for (final c in evidenceCards)
        if ((s.stats[c.stat] ?? 0) > 0 && !s.seenEvidence.contains(c.title))
          c.title,
    };
    if (_newTitles.isNotEmpty) {
      // persist the "seen" set after this frame (notify → shell save)
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => s.markEvidenceSeen(_newTitles));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final dominant = state.dominantStat;
    // your trained stats float up; within that, source order holds
    final sorted = [...evidenceCards];
    if (dominant != null) {
      sorted.sort((a, b) {
        final av = (state.stats[a.stat] ?? 0);
        final bv = (state.stats[b.stat] ?? 0);
        return bv.compareTo(av);
      });
    }
    // the deeper half is the archive — gated until level 4
    final unlocked = state.level >= InspirationPage.archiveGate;
    final gateAt =
        unlocked ? sorted.length : (sorted.length - 3).clamp(0, sorted.length);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
      children: [
        Text('Sparks', style: Type.display.copyWith(fontSize: 30)),
        const SizedBox(height: 4),
        Text(
            dominant == null
                ? 'why the little things work'
                : 'why the little things work — starting with your ${dominant.abbr}',
            style: Type.body.copyWith(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Palette.textLo)),
        const SizedBox(height: 16),
        for (var i = 0; i < sorted.length; i++) ...[
          if (i < gateAt)
            _EvidenceTile(
              card: sorted[i],
              forYou: dominant != null && sorted[i].stat == dominant,
              isNew: _newTitles.contains(sorted[i].title),
            )
          else
            _LockedCard(card: sorted[i]),
          const SizedBox(height: 12),
        ],
        if (!unlocked) ...[
          const SizedBox(height: 2),
          Center(
            child: Text(
                'the rest of the archive opens at level ${InspirationPage.archiveGate}',
                style: Type.label.copyWith(fontSize: 11, color: Palette.textLo)),
          ),
        ],
      ],
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile(
      {required this.card, this.forYou = false, this.isNew = false});
  final EvidenceCard card;
  final bool forYou;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      glow: forYou,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: card.stat.color.withValues(alpha: 0.14),
                  border: Border.all(
                      color: card.stat.color.withValues(alpha: 0.4)),
                ),
                child: Text(card.stat.abbr,
                    style: Type.label
                        .copyWith(fontSize: 11, color: card.stat.color)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(card.title,
                    style: Type.display.copyWith(fontSize: 16)),
              ),
              if (isNew) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Palette.streak.withValues(alpha: 0.2),
                  ),
                  child: Text('NEW',
                      style: Type.label
                          .copyWith(fontSize: 11, color: Palette.streak)),
                ),
                const SizedBox(width: 6),
              ],
              if (forYou)
                Text('FOR YOU',
                    style: Type.label
                        .copyWith(fontSize: 11, color: Palette.xpLight)),
            ],
          ),
          const SizedBox(height: 8),
          Text(card.text,
              style: Type.body.copyWith(
                  fontSize: 13, height: 1.5, color: Palette.textMid)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.menu_book_outlined,
                  size: 13, color: Palette.info),
              const SizedBox(width: 5),
              Expanded(
                child: Text(card.source,
                    overflow: TextOverflow.ellipsis,
                    style:
                        Type.label.copyWith(fontSize: 11, color: Palette.info)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A gated archive card — its stat and a locked title, a teaser until Lv 4.
class _LockedCard extends StatelessWidget {
  const _LockedCard({required this.card});
  final EvidenceCard card;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Row(
        children: [
          Icon(Icons.lock_outline,
              size: 16, color: Palette.textLo.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(card.title,
                style: Type.body.copyWith(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Palette.textLo.withValues(alpha: 0.7))),
          ),
          Text('LV 4',
              style: Type.label.copyWith(fontSize: 11, color: Palette.textLo)),
        ],
      ),
    );
  }
}
