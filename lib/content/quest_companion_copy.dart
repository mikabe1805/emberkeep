import '../models.dart';
import '../tokens.dart';

/// A single quiet line for a featured Quest that has no keeper-written note or
/// curated instruction. The copy is stable for the local day: it should make
/// the board feel inhabited, not shuffle every time Flutter rebuilds it.
///
/// This deliberately returns a completed English message today, but each pool
/// is a semantic state rather than a widget fragment. Moving it to localized
/// templates later therefore means translating a whole line per state, not
/// trying to reconstruct grammar around an interpolated word.
String? questCompanionCopy({required Quest quest, required DateTime day}) {
  // Keeper words and a curated prescription are already more specific than a
  // generated companion. Never talk over either one.
  if (quest.latestNote != null || quest.ladderHint != null) return null;

  final state = _stateFor(quest, day);
  final pool = switch (state) {
    _QuestCompanionState.overdue => _overdue,
    _QuestCompanionState.dueToday => _dueToday,
    _QuestCompanionState.main => _main,
    _QuestCompanionState.domain => _byStat[quest.stat]!,
  };

  final identity = quest.origin ?? quest.title;
  final identitySeed = _stableSeed(
    '$identity|${quest.stat.name}|${state.name}',
  );
  // Advance exactly one place per civil day. Hashing the date together with
  // identity can coincidentally return the same modulo bucket on consecutive
  // days; this explicit rotation makes the anti-fatigue promise real while
  // keeping different Quests out of lockstep.
  final dayOrdinal =
      DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  return pool[(identitySeed + dayOrdinal) % pool.length];
}

enum _QuestCompanionState { overdue, dueToday, main, domain }

_QuestCompanionState _stateFor(Quest quest, DateTime day) {
  final start = DateTime(day.year, day.month, day.day);
  final due = quest.dueDate;
  if (due != null) {
    final dueDay = DateTime(due.year, due.month, due.day);
    if (dueDay.isBefore(start)) return _QuestCompanionState.overdue;
    if (dueDay == start) return _QuestCompanionState.dueToday;
  }
  if (quest.priorityOn(day)) return _QuestCompanionState.main;
  return _QuestCompanionState.domain;
}

/// Explicit and stable across Dart runtimes; [String.hashCode] is not used as
/// a content contract because this choice must stay reproducible in tests and
/// on every supported device.
int _stableSeed(String value) => value.codeUnits.fold<int>(17, (seed, unit) {
  return (seed * 31 + unit) & 0x7fffffff;
});

const _overdue = [
  'Still yours when you have room.',
  'Pick it back up when the day allows.',
  'This can wait for a clearer moment.',
];

const _dueToday = [
  'This is the day it belongs to.',
  'A place to land today.',
  'Keep this one in view.',
];

const _main = [
  'Keep this one within reach.',
  'A good place to begin.',
  'Let this be the clear thing.',
];

const _byStat = <Stat, List<String>>{
  Stat.str: [
    'A little movement changes the room.',
    'Give your body a real moment.',
    'One honest effort is enough to begin.',
  ],
  Stat.vit: [
    'A quiet kindness to future-you.',
    'Care counts even when it is small.',
    'Make a little room to feel better.',
  ],
  Stat.intl: [
    'Give your attention somewhere real.',
    'A thought worth keeping starts here.',
    'Stay with one curious thing.',
  ],
  Stat.foc: [
    'Make one honest pass.',
    'One clear stretch of attention.',
    'The rest can wait for a minute.',
  ],
  Stat.soc: [
    'A small reach still reaches someone.',
    'Leave a little warmth with someone.',
    'Connection can begin quietly.',
  ],
  Stat.dis: [
    'One corner is enough to begin.',
    'Make the room a little easier to return to.',
    'A small tending changes the feeling of home.',
  ],
};
