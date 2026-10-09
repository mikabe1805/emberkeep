import 'package:flutter/foundation.dart';

import 'content/achievements.dart';
import 'content/stat_ranks.dart';
import 'models.dart';
import 'tokens.dart';

/// The two questions about classes and the streak, answered in this one
/// place. Mika answered yes to both on 2026-10-08:
///
/// * [classDayLightsStreak]: a day with at least one kept class is a streak
///   day, exactly like a day with a Quest.
/// * [restDaysPause]: gap days that [GameState.restDayResolver] marks as rest
///   days (a term day with no classes) are passed over when judging a gap, so
///   they neither count nor spend freezes.
final class ClassDayRules {
  const ClassDayRules({
    this.classDayLightsStreak = true,
    this.restDaysPause = true,
  });

  final bool classDayLightsStreak;
  final bool restDaysPause;

  /// What the app ships with. Change the answer here and nowhere else.
  static const shipped = ClassDayRules();

  /// Tests flip the rules without touching [shipped]. Reset in tearDown.
  @visibleForTesting
  static ClassDayRules? debugOverride;

  static ClassDayRules get current => debugOverride ?? shipped;
}

/// What one kept class pays. Flat and deterministic: no crit, luck, streak or
/// comeback multiplier, so a class always pays what it says and tests can
/// assert exact numbers on any GameState.
final class ClassPay {
  const ClassPay._({
    required this.xp,
    required this.stat,
    required this.statGain,
  });

  final int xp;
  final Stat stat;
  final int statGain;

  /// Lectures, recitations, seminars and anything that is not a lab: MIND.
  static const lecture = ClassPay._(xp: 25, stat: Stat.intl, statGain: 3);

  /// Labs and studios: CRAFT, and a little more for the longer block.
  static const lab = ClassPay._(xp: 30, stat: Stat.foc, statGain: 5);

  /// Paid once per day, on the keep that completes every class that day.
  static const fullDayBonusXp = 10;

  static bool isLabKind(String kind) => kind == 'lab' || kind == 'studio';

  static ClassPay forKind(String kind) => isLabKind(kind) ? lab : lecture;

  /// Meeting kinds that are optional drop-in time. They are kept and paid
  /// like any class, but a day is complete without them (the full-day bonus
  /// never waits on one) and a term day holding only these is a rest day.
  /// Whether they should pay at all is still open for Mika; decide it here.
  static const optionalKinds = {'officeHours'};

  /// Whether a class of [kind] belongs to the set a full day is judged by.
  static bool countsTowardDay(String kind) => !optionalKinds.contains(kind);

  /// Glimmers track XP the way Quest receipts do.
  static int glimmersFor(int xp) => xp ~/ 3;
}

/// Plain facts about one class occurrence. The engine stays schedule-blind:
/// the timetable (device-local, not backed up) is read by the UI and passed
/// in as these values, which a kept record then copies.
final class ClassFacts {
  const ClassFacts({
    this.occurrenceKey,
    required this.courseCode,
    required this.title,
    required this.kind,
    required this.dayKey,
    required this.startMinute,
    this.startsAt,
    this.endsAt,
    this.nightEndsAt,
  });

  /// The timetable occurrence, when there is one.
  final String? occurrenceKey;
  final String courseCode;

  /// The course title; the kept record stores a short label from it.
  final String title;

  /// The meeting kind's name (`lecture`, `lab`, `recitation`, ...).
  final String kind;

  /// The class's own civil day, in `Days.key` form.
  final String dayKey;

  /// Local start, minutes after midnight in the schedule's zone.
  final int startMinute;

  /// Absolute start and end, when known. A class cannot be kept more than a
  /// few minutes before it starts.
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// When this class's own night ends: 04:00 the next morning in the
  /// timetable's zone, as an instant. With it (or, failing that, with
  /// [startsAt]) the keep window is judged by instants, so a phone in another
  /// zone keeps exactly the classes its timetable shows.
  final DateTime? nightEndsAt;

  /// The course code as a kept record stores it (trimmed, at most
  /// [KeptClass.maxCodeLength] UTF-16 units), or null when nothing is left.
  String? get keptCode => KeptClass.cleanCode(courseCode);

  /// The key a day's class list uses for this class.
  String get identity =>
      occurrenceKey ?? '${keptCode ?? courseCode.trim()}@$startMinute';

  String get label => KeptClass.cleanLabel(title, courseCode);
}

/// Why a class can or cannot be kept right now.
enum ClassKeepCheck {
  /// It can be kept.
  open,

  /// It is already kept; a second mark pays nothing.
  alreadyKept,

  /// It has not started yet (more than [GameState.classKeepLead] away).
  notStartedYet,

  /// It is not the class's own night (04:00 to 04:00 in the timetable's
  /// zone), or a queued mark was made outside that night or arrived more
  /// than [GameState.classKeepRecentNights] nights after it ended.
  outsideWindow,

  /// Its day already holds [DayRecord.maxClassesPerDay] kept classes, the
  /// most a save keeps for one day, so one more could not be proven later.
  dayFull,

  /// The facts do not describe a class (bad day key, empty code, bad start).
  invalid,
}

/// What a class keep did to the streak. Always [none] unless
/// [ClassDayRules.classDayLightsStreak] is on.
final class ClassStreakEffect {
  const ClassStreakEffect({
    this.lit = false,
    this.streakDays = 0,
    this.freezesUsed = 0,
    this.restDaysPassed = 0,
    this.restarted = false,
    this.freezeEarned = false,
    this.freezeReturned = false,
    this.relit = false,
    this.milestone,
    this.milestoneGlimmers = 0,
  });

  static const none = ClassStreakEffect();

  /// This keep made its day a streak day.
  final bool lit;

  /// The streak after the keep (0 when unchanged).
  final int streakDays;

  /// Freezes spent to hold the quiet days before this one.
  final int freezesUsed;

  /// Rest days passed over without spending anything.
  final int restDaysPassed;

  /// The streak began again at 1 after a gap the reserve could not hold.
  /// The next Quest still gets its welcome-back bonus.
  final bool restarted;

  /// This streak day filled the freeze reserve by one.
  final bool freezeEarned;

  /// A late mark landed on a day a freeze had held, so the freeze came back.
  final bool freezeReturned;

  /// A late mark lit a day older than the last streak day, and the streak
  /// days after it were counted again in day order, as if the mark had come
  /// on time. [streakDays] is the streak after that recount and
  /// [freezesUsed] the freezes it spent on balance.
  final bool relit;

  /// A 7, 30 or 100 day crossing, with its chest of Glimmers.
  final int? milestone;
  final int milestoneGlimmers;
}

/// Where a keep leaves the level bar. Level-ups are not applied by the keep;
/// the UI runs its usual chain (`applyLevelUps`) after its celebration.
final class ClassLevelProjection {
  const ClassLevelProjection({
    required this.level,
    required this.xpBefore,
    required this.xpAfter,
    required this.xpForNextLevel,
    required this.projectedLevel,
  });

  /// The level before and after the keep (levels apply later).
  final int level;

  /// Unspent XP toward the next level, before and after the keep.
  final int xpBefore;
  final int xpAfter;

  /// The cost of `level + 1`.
  final int xpForNextLevel;

  /// The level the chain will reach once it applies this XP.
  final int projectedLevel;

  bool get levelReady => projectedLevel > level;
}

/// Everything a class celebration needs, computed once by the engine.
final class ClassCredit {
  const ClassCredit({
    required this.kept,
    required this.dayKey,
    required this.xp,
    required this.classXp,
    required this.fullDayBonus,
    required this.stat,
    required this.statGain,
    required this.rankedUpTo,
    required this.glimmers,
    required this.courseCount,
    required this.totalClassesKept,
    required this.dayComplete,
    required this.keptToday,
    required this.dayClassCount,
    required this.level,
    required this.streak,
    required this.achievements,
  });

  /// The stored record (label, kind, start, keptAt).
  final KeptClass kept;
  final String dayKey;

  /// All XP this keep added: the class pay plus any full-day bonus.
  final int xp;

  /// The class's own pay.
  final int classXp;

  /// The full-day bonus paid by this keep (0 or [ClassPay.fullDayBonusXp]).
  final int fullDayBonus;

  final Stat stat;
  final int statGain;

  /// The new rank when the stat crossed a tier (also queued for the
  /// existing rank-up beat), else null.
  final StatRank? rankedUpTo;

  /// Glimmers from this keep (milestone chests are in [streak]).
  final int glimmers;

  /// This course's kept count after the keep ("your Nth lecture").
  final int courseCount;

  /// Every class kept, ever, after this keep.
  final int totalClassesKept;

  /// Every class that day is now kept (needs the day's class keys).
  final bool dayComplete;

  /// Classes kept on [dayKey] after this keep.
  final int keptToday;

  /// How many real classes the day has, as passed in (0 when unknown).
  final int dayClassCount;

  final ClassLevelProjection level;
  final ClassStreakEffect streak;

  /// Achievements this keep unlocked, already recorded.
  final List<Achievement> achievements;

  String get label => kept.label;
}
