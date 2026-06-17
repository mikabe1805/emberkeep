import '../models.dart';
import '../tokens.dart';

/// The momentum layer (RESEARCH-momentum.md §2–3): concrete progression
/// ladders for trainable quests, and per-stat *variant pools* (siblings that
/// credit the same stat). The Quests-page "keep the fire going" encore reads
/// from both — STOKE climbs a quest's [Quest.ladder]; SWITCH pulls a sibling
/// from [kinByStat] (or a quest's own [Quest.kin]).
abstract final class Ladders {
  /// Ready-made ladders keyed by a quest's rung-0 prescription. Rungs follow
  /// the one-variable-at-a-time, small-step rule so each next rung sits just
  /// above current skill (the flow channel / ZPD).
  static const byBaseTitle = <String, List<String>>{
    'Do 2 push-ups': [
      'Do 2 push-ups',
      'Do 5 push-ups',
      'Do 8 push-ups',
      'Do 12 push-ups',
      'Do 20 push-ups',
    ],
    'Read one page': [
      'Read one page',
      'Read 3 pages',
      'Read 10 minutes',
      'Read 20 minutes',
      'Finish a chapter',
    ],
    'Walk 10 minutes': [
      'Walk 10 minutes',
      'Walk 20 minutes',
      'Walk 30 minutes',
      'Walk 45 minutes',
      'Walk an hour',
    ],
    'Workout — full session': [
      'Workout — 20 minutes',
      'Workout — 30 minutes',
      'Workout — 45 minutes',
      'Workout — full hour',
    ],
    // the guided-workout launcher climbs through its recommended routines
    // (RESEARCH-workouts.md); the rung maps to recommendedForRung().
    'Guided workout session': [
      'Guided workout · Wake-Up Snack',
      'Guided workout · Beginner Full Body',
      'Guided workout · Level Two',
    ],
  };

  /// Per-stat variant pools — what "Switch it up" offers when a quest has no
  /// hand-authored [Quest.kin]. Each is a small, real, low-friction sibling.
  static const kinByStat = <Stat, List<String>>{
    Stat.str: [
      'Do 10 squats',
      'Hold a 30-second plank',
      'Do 8 lunges each leg',
      'Carry something heavy upstairs',
    ],
    Stat.vit: [
      'Take the stairs',
      'A 5-minute stretch flow',
      'Cook a real meal',
      'Step outside for fresh air',
    ],
    Stat.intl: [
      'Watch a how-to and take one note',
      'Learn one new word',
      'Teach someone a small thing',
      'Read 3 pages of anything',
    ],
    Stat.foc: [
      'A 1-minute breathing reset',
      'Put the phone in another room for 20 min',
      'Single-task one thing, start to finish',
      'A 10-minute one-tab-only stretch',
    ],
    Stat.soc: [
      'Send one message to someone you miss',
      'Call someone for 5 minutes',
      'Do one small kindness',
      'Make a plan with a friend',
    ],
    Stat.dis: [
      'Do the dreaded thing first',
      'Make the bed',
      'Cold-start the task you keep dodging',
      'Keep one tiny promise to yourself',
    ],
  };

  /// Variants available for [q]: its own [Quest.kin] if set, else the stat
  /// pool — minus anything already on the board (by display title) and the
  /// quest's own current rung, so SWITCH always offers something genuinely new.
  static List<String> variantsFor(Quest q, Iterable<String> onBoard) {
    final pool = q.kin ?? kinByStat[q.stat] ?? const [];
    final taken = onBoard.map((t) => t.toLowerCase()).toSet()
      ..add(q.displayTitle.toLowerCase());
    return [for (final v in pool) if (!taken.contains(v.toLowerCase())) v];
  }
}
