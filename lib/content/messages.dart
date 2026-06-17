import 'dart:math';

import '../tokens.dart';

/// The personal reward voice (DESIGN.md §11.2): completions speak to *you*,
/// mixing warm encouragement with a little friendly competitiveness.
abstract final class RewardMessages {
  static final _byStat = <Stat, List<String>>{
    Stat.str: [
      'That’s how strength gets built — one rep at a time.',
      'Most people skipped their workout today. Not you.',
      'Your muscles got the memo: we’re leveling up.',
      'Future-you, mid-hike, says thanks.',
      'Strong isn’t a look. It’s a stack of days like this.',
      'The body keeps the receipts. This one’s a deposit.',
    ],
    Stat.vit: [
      'Your future self is already breathing easier :)',
      'That’s a deposit in the long-game health bank.',
      'Small healthy choices compound — this one counts.',
      'Boring, repeatable, powerful. That’s the good stuff.',
      'Energy tomorrow is built quietly today. Nice.',
      'The unglamorous wins are the ones that last.',
    ],
    Stat.intl: [
      'That keeps you sharp :)',
      'Pages add up. Readers are dangerous people.',
      'Your brain just got a little harder to argue with.',
      'A little smarter than yesterday. That’s the whole trick.',
      'Curiosity, fed. It’ll pay you back at odd hours.',
      'Knowledge compounds quieter than money, and longer.',
    ],
    Stat.foc: [
      'Real focus is rare. You just did it.',
      'That session puts you ahead of everyone still scrolling.',
      'Deep work logged — that’s where the good stuff happens.',
      'You out-sat the urge to check your phone. Respect.',
      'Attention is the rarest currency. You just spent it well.',
      'That’s the muscle the modern world tries to steal. Trained.',
    ],
    Stat.soc: [
      'You just made someone’s day a little warmer :)',
      'Connection logged. Hearts level up too.',
      'People remember this stuff. Nicely done.',
      'Reaching out is brave more often than it looks.',
      'Someone out there is glad you exist today.',
      'Relationships are a stat too — and you just trained it.',
    ],
    Stat.dis: [
      'You did the thing you didn’t want to do. That’s the whole game.',
      'The dread never stood a chance.',
      'Discipline is a stat most people never train. Look at you.',
      'Did it anyway. That’s the only sentence that matters.',
      'You kept a promise to yourself. Those are the loudest kind.',
      'Motivation’s nice. You used discipline. Sturdier stuff.',
    ],
  };

  // Context lines — a dungeon master who's actually watching the moment
  // (scout pick #4). Surfaced ~60% of the time when they apply, so they stay
  // a surprise and the warm per-stat lines remain the default.
  static const _dawnLines = [
    'Before 8am. Most of the world’s still asleep — you’re already moving.',
    'A dawn quest. The day owes you nothing now; everything else is a bonus.',
  ];
  static const _duskLines = [
    'Late, and you still showed up. The day didn’t get away from you.',
    'Burning the late candle — quietly, on purpose. Respect.',
  ];
  static const _dreadLines = [
    'The dreaded one. Done. That’s the whole game, right there.',
    'You did the thing you were avoiding. Everything’s easier now.',
  ];
  static const _comebackLines = [
    'Back at it after a gap — no guilt, just go. This is the move that counts.',
    'You returned. That’s rarer and braver than never stopping.',
  ];

  static String pick(
    Stat stat,
    Random rng, {
    int hour = 12,
    bool dread = false,
    int countToday = 1,
    bool comeback = false,
  }) {
    final specials = <String>[];
    if (hour < 8) specials.addAll(_dawnLines);
    if (hour >= 21) specials.addAll(_duskLines);
    if (dread) specials.addAll(_dreadLines);
    if (comeback) specials.addAll(_comebackLines);
    if (countToday >= 4) {
      specials.add('That makes $countToday today. You’re on a tear.');
    }
    if (specials.isNotEmpty && rng.nextDouble() < 0.6) {
      return specials[rng.nextInt(specials.length)];
    }
    final list = _byStat[stat]!;
    return list[rng.nextInt(list.length)];
  }

  static const nightLines = [
    'Whatever today was — you showed up. That’s the part that compounds.',
    'Rest is part of the build. Tanks need repairs; so do heroes.',
    'Tomorrow’s you is already grateful for what you did today.',
    'The day is logged. Nothing left to carry to bed.',
    'You don’t have to have won today. You only had to not quit.',
    'Set it down. The fire will be here in the morning.',
    'Progress isn’t loud. It’s a hundred quiet nights like this.',
    'Be proud of the small ones. They were the hard ones.',
  ];

  static const morningLines = [
    'New day, fresh XP on the table. Small first quest, then momentum.',
    'You don’t need to feel ready. You need one small win before noon.',
    'Yesterday is banked. Today is uncharted map.',
    'Head clear, list short, first quest tiny. Let’s go.',
    'Start absurdly small. Momentum does the rest.',
    'You woke up. You opened this. The hard part’s already behind you.',
    'One tiny quest before coffee and the day tilts your way.',
    'No need to conquer the day. Just light the first ember.',
  ];

  static String night(Random rng) =>
      nightLines[rng.nextInt(nightLines.length)];
  static String morning(Random rng) =>
      morningLines[rng.nextInt(morningLines.length)];
}
