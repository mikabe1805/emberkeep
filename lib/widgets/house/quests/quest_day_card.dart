// The day's card on a day with no classes: "SATURDAY, DONE.", held for a tap,
// once the last of Today's three is kept and the tickets have landed in the
// bowl.
//
// It is the class day's own tier card (ClassKeptCelebration, the one that
// says "TUESDAY, DONE."), planned from the quests instead of the timetable:
// the weekday, the number of quests kept today in the diamond, "QUESTS DONE
// TODAY", and one closing line. There is no XP row. Each quest paid when it
// was kept (its XP flew to the HUD then), so the card has nothing of its own
// to count up, and it never invents any: a pill appears only for a real
// full-three bonus, and the engine has none today (GameState grants XP for a
// quest, for a class, for a full class day and for Extra Credit, and nothing
// for keeping Today's three), so [planQuestDay] is called without one.
//
// Never punish: no count of what was not done, no "of three".
library;

import '../../../academic_calendar/domain/academic_schedule.dart'
    show CivilDate;
import '../../../engine.dart';
import '../../class_day/class_day_model.dart';

/// "The rest of today is yours." The one line the card closes on.
const questDayClosing = 'The rest of today is yours.';

/// What the card says for [kept] quests kept on [date], a day with no
/// classes. [bonusXp] is a full-three bonus the engine really paid on the
/// keep that cleared the day (0: none, no pill).
ClassCelebrationPlan planQuestDay({
  required CivilDate date,
  required int kept,
  required GameState state,
  int bonusXp = 0,
}) {
  final day = weekdayOf(date);
  final headline = '${day.toUpperCase()}, DONE.';
  final label = kept == 1 ? 'QUEST DONE TODAY' : 'QUESTS DONE TODAY';
  final pill = bonusXp > 0 ? bonusXp : 0;
  return ClassCelebrationPlan(
    tier: ClassCelebrationTier.dayDone,
    headline: headline,
    numeral: kept,
    numeralLabel: label,
    title: null,
    detail: null,
    rows: const [],
    bonusLine: null,
    bonusXp: 0,
    xpShown: 0,
    xpFrom: 0,
    caption: null,
    gains: const {},
    totals: const {},
    level: state.level,
    xpBefore: state.xp,
    xpForNextLevel: state.xpNeeded(state.level + 1),
    xpGained: 0,
    closing: const [questDayClosing],
    streakLine: null,
    xpRail: false,
    pillXp: pill,
    semanticsLabel: [
      '$day, done.',
      '$kept ${kept == 1 ? 'quest' : 'quests'} done today.',
      if (pill > 0) 'Plus $pill XP.',
      questDayClosing,
    ].join(' '),
  );
}
