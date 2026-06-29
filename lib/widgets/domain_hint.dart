import 'package:flutter/material.dart';

import '../tokens.dart';
import 'glass.dart';

/// A quiet one-line answer to "which domain is this?" — the selected domain's
/// meaning, plus a few concrete examples in its own colour. Dropped beneath any
/// domain picker so categorization explains itself at the moment of choosing
/// (round-21: the six domains overlap enough — CARE vs HOME vs BODY — that a
/// living example line beats a static legend).
class DomainHint extends StatelessWidget {
  const DomainHint(this.stat, {super.key});
  final Stat stat;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.quick,
      switchInCurve: Motion.respond,
      // cross-fade so tapping between domains reads as one calm line updating,
      // not a jumpy reflow.
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: Padding(
        // key on the domain so the switcher animates each change
        key: ValueKey(stat),
        padding: const EdgeInsets.only(top: 8),
        child: RichText(
          text: TextSpan(
            style: Type.body.copyWith(fontSize: 12, color: Palette.textLo),
            children: [
              TextSpan(
                text: '${stat.label} — ',
                style: Type.body.copyWith(
                    fontSize: 12,
                    color: stat.color,
                    fontWeight: FontWeight.w600),
              ),
              TextSpan(text: stat.examples),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small tappable "?" that opens the full domains legend — for reference
/// spots (the Me page build) where no single domain is selected.
class DomainLegendButton extends StatelessWidget {
  const DomainLegendButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showDomainLegend(context),
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Palette.glassFill,
          border: Border.all(color: Palette.glassEdge),
        ),
        child: Text('?',
            style: Type.label.copyWith(fontSize: 12, color: Palette.textLo)),
      ),
    );
  }
}

/// The reference card: all six domains, each with its meaning and examples.
/// What "?" opens — a place to settle "is this CARE or HOME?" once and for all.
Future<void> showDomainLegend(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GlassPanel(
          tint: const Color(0xF22A211D),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('THE SIX DOMAINS',
                  style: Type.label.copyWith(fontSize: 12, color: Palette.xp)),
              const SizedBox(height: 4),
              Text('What each one is for',
                  style: Type.body
                      .copyWith(fontSize: 13, color: Palette.textLo)),
              const SizedBox(height: 16),
              for (final s in Stat.values) _LegendRow(s),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LegendRow extends StatelessWidget {
  const _LegendRow(this.stat);
  final Stat stat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // colour dot — the same hue this domain wears everywhere
          Container(
            margin: const EdgeInsets.only(top: 3, right: 12),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: stat.color.withValues(alpha: 0.85),
              boxShadow: [
                BoxShadow(
                    color: stat.color.withValues(alpha: 0.4), blurRadius: 8),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stat.abbr,
                    style: Type.label.copyWith(
                        fontSize: 12, color: stat.color)),
                const SizedBox(height: 2),
                Text(stat.blurb,
                    style: Type.body
                        .copyWith(fontSize: 13, color: Palette.textMid)),
                const SizedBox(height: 2),
                Text(stat.examples,
                    style: Type.body.copyWith(
                        fontSize: 12,
                        color: Palette.textLo,
                        fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
