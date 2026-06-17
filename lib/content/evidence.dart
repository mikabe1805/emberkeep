import '../tokens.dart';

/// Evidence cards (DESIGN.md §5) — bite-sized, sourced "why this works"
/// content. Phase 0 ships a small curated set drawn from RESEARCH.md §4;
/// grows to ~100 offline JSON cards in later phases.
class EvidenceCard {
  const EvidenceCard({
    required this.stat,
    required this.title,
    required this.text,
    required this.source,
  });

  final Stat stat;
  final String title;
  final String text;
  final String source;
}

const evidenceCards = <EvidenceCard>[
  EvidenceCard(
    stat: Stat.vit,
    title: '7,000 steps is the real target',
    text:
        'You don’t need 10,000 steps. About 7,000 a day is linked to a 47% '
        'lower risk of early death, 38% lower dementia risk, and 22% fewer '
        'depressive symptoms — and the gains level off after that.',
    source: 'Lancet Public Health 2025 · 57 studies, device-measured',
  ),
  EvidenceCard(
    stat: Stat.str,
    title: 'Exercise snacks count',
    text:
        '1–2 minute bursts of movement measurably improve cardio fitness — '
        'and short bouts beat long workouts on the habit that matters most: '
        'actually showing up again tomorrow.',
    source: 'Meta-analysis of 12 randomized trials',
  ),
  EvidenceCard(
    stat: Stat.vit,
    title: 'Caffeine has a 6-hour shadow',
    text:
        'That afternoon coffee can still be in your system at bedtime — '
        'caffeine six hours before bed measurably steals sleep. Cut it off '
        'early and you’re protecting tonight’s recovery.',
    source: 'Journal of Clinical Sleep Medicine',
  ),
  EvidenceCard(
    stat: Stat.intl,
    title: 'Start absurdly small',
    text:
        'Behaviors stick when they’re too small to refuse — read one '
        'page, do two push-ups. The emotion you feel on finishing is what '
        'wires the habit, not the size of the session.',
    source: 'BJ Fogg, Stanford Behavior Design Lab',
  ),
  EvidenceCard(
    stat: Stat.foc,
    title: 'Enjoyment literally builds habits faster',
    text:
        'Pleasure during a behavior increases the automaticity gained from '
        'each repetition — fun isn’t decoration, it’s mechanism. '
        'That’s why this app celebrates you.',
    source: 'Psychology of habit formation, PMC6302524',
  ),
  EvidenceCard(
    stat: Stat.dis,
    title: 'Anchor habits to moments, not clocks',
    text:
        'Behaviors repeated in a stable context — after coffee, before the '
        'shower — form habits faster than ones tied to arbitrary times.',
    source: 'Habit formation research, PMC6302524',
  ),
  EvidenceCard(
    stat: Stat.soc,
    title: 'Connection is a health behavior',
    text:
        'One message counts. Reaching out to people you care about protects '
        'your mood and your long-term health — social ties rank right '
        'alongside exercise in the longevity studies.',
    source: 'Holt-Lunstad meta-analyses',
  ),
  EvidenceCard(
    stat: Stat.foc,
    title: 'Evening workouts are fine',
    text:
        'Late workouts don’t wreck your sleep — that’s a myth. Train when '
        'life actually allows; showing up beats perfect timing every time.',
    source: 'Sleep hygiene evidence review',
  ),
  EvidenceCard(
    stat: Stat.str,
    title: 'Soreness means you’re adapting',
    text:
        'A little next-day ache is your muscles rebuilding stronger, not '
        'damage. It fades fast — and the “repeated-bout effect” means the '
        'same session hurts far less next time. Sharp or joint pain is '
        'different: that one’s a stop sign.',
    source: 'DOMS & repeated-bout effect, exercise physiology',
  ),
  EvidenceCard(
    stat: Stat.vit,
    title: 'Rest is when you build',
    text:
        'Muscles don’t grow during the workout — they grow in the recovery '
        'after it. A gentle or skipped day isn’t lost progress; it’s the '
        'other half of getting stronger.',
    source: 'Recovery & adaptation, ACSM',
  ),
];

/// First evidence card that speaks to [stat] — powers the "why this works"
/// info-dot on each stat row (RESEARCH-momentum.md §7).
EvidenceCard? evidenceForStat(Stat stat) {
  for (final c in evidenceCards) {
    if (c.stat == stat) return c;
  }
  return null;
}

/// Lookup by exact title — used by guided routines to show a specific
/// "why this works" card on their intro screen.
EvidenceCard? evidenceByTitle(String title) {
  for (final c in evidenceCards) {
    if (c.title == title) return c;
  }
  return null;
}
