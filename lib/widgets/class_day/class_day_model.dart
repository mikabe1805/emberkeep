// The class day on the Quests tab, as words and states: which class leads the
// glass, what every row shows, and what one mark's celebration says. Pure: it
// reads a ClassDay, the GameState's kept records and a moment, and writes
// nothing. The engine (GameState.keepClass) owns what a mark pays.
//
// Never punish: a class that ended unmarked has no state of its own. It is a
// quiet row (a dim dot, never a hollow socket), nothing counts it, and no line
// here ever names what was not marked. Every tally counts up.
library;

import '../../academic_calendar/domain/academic_schedule.dart';
import '../../academic_calendar/services/class_day_projection.dart';
import '../../content/routines.dart' show isWindDownTime;
import '../../engine.dart';
import '../../models.dart';
import '../../tokens.dart';

/// How one of today's classes reads on the glass.
enum ClassRowState {
  /// Marked: a closed ring and what it paid.
  kept,

  /// Over, unmarked, and still markable until the class's night ends.
  ready,

  /// Happening now: "I'm here".
  inSession,

  /// Starts within [classStartsSoonLead]: the only time a countdown shows.
  startsSoon,

  /// Later today: its start time.
  upcoming,

  /// Over and no longer markable (its night has ended on this phone's clock).
  /// A quiet row, nothing more.
  settled,
}

/// One class row.
final class ClassRow {
  const ClassRow({required this.entry, required this.state, this.kept});

  final ProjectedClass entry;
  final ClassRowState state;
  final KeptClass? kept;

  String get identity => entry.facts.identity;

  bool get isKept => state == ClassRowState.kept;

  /// "I was there" (or "I'm here") can be pressed for it now.
  bool get markable =>
      state == ClassRowState.ready || state == ClassRowState.inSession;

  /// Over, unmarked and markable: what the "all of today's classes" shortcut
  /// gathers.
  bool get waiting => state == ClassRowState.ready;
}

/// The glass card's reading of a class day at one moment.
final class ClassCard {
  const ClassCard._({
    required this.day,
    required this.rows,
    required this.foremost,
    required this.waiting,
    required this.held,
  });

  /// Reads [day] against [state]'s kept records at [now]. [preferred] is a
  /// row the person brought forward (tapping a quiet row); [held] keeps a
  /// just-marked row foremost while its ring closes under the celebration.
  factory ClassCard.read(
    ClassDay day,
    GameState state,
    DateTime now, {
    String? preferred,
    String? held,
  }) {
    final rows = [for (final entry in day.classes) _rowFor(entry, state, now)];
    ClassRow? find(String? identity) {
      if (identity == null) return null;
      for (final row in rows) {
        if (row.identity == identity) return row;
      }
      return null;
    }

    final heldRow = find(held);
    final preferredRow = find(preferred);
    ClassRow? foremost;
    if (heldRow != null && heldRow.isKept) {
      foremost = heldRow;
    } else if (preferredRow != null && preferredRow.markable) {
      foremost = preferredRow;
    } else {
      // The class that most recently began and can still be marked: the one
      // that just ended, or the one he is sitting in.
      for (final row in rows.reversed) {
        if (row.markable) {
          foremost = row;
          break;
        }
      }
      // Nothing to mark: the next class leads, with when and where.
      if (foremost == null) {
        for (final row in rows) {
          if (row.state == ClassRowState.startsSoon ||
              row.state == ClassRowState.upcoming) {
            foremost = row;
            break;
          }
        }
      }
    }
    return ClassCard._(
      day: day,
      rows: List.unmodifiable(rows),
      foremost: foremost,
      waiting: List.unmodifiable([
        for (final row in rows)
          if (row.waiting) row,
      ]),
      held: heldRow != null && heldRow.isKept,
    );
  }

  final ClassDay day;
  final List<ClassRow> rows;

  /// The one row that owns the card: markable, or next. Null once the day has
  /// nothing left to mark or wait for (the record).
  final ClassRow? foremost;

  /// Ended, unmarked, still markable.
  final List<ClassRow> waiting;

  /// The foremost row is a just-marked class held in place for its ring.
  final bool held;

  /// Two or more ended classes wait: one shortcut marks them together.
  bool get offersShortcut => waiting.length >= 2;

  /// Marking every waiting class would leave every class today kept.
  bool get shortcutCompletesDay {
    final keys = day.dayClassKeys;
    if (keys.isEmpty) return false;
    final after = {
      for (final row in rows)
        if (row.isKept || row.waiting) row.identity,
    };
    return keys.every(after.contains);
  }

  int get keptCount => rows.where((row) => row.isKept).length;

  /// Every class a full day is judged by is kept.
  bool get allKept {
    final keys = day.dayClassKeys;
    if (keys.isEmpty) return false;
    final kept = {
      for (final row in rows)
        if (row.isKept) row.identity,
    };
    return keys.every(kept.contains);
  }

  /// Nothing to mark and nothing still to come: the card is the day's record.
  bool get isRecord => foremost == null;

  static ClassRow _rowFor(ProjectedClass entry, GameState state, DateTime now) {
    final kept = state.keptClassFor(entry.facts);
    if (kept != null) {
      return ClassRow(entry: entry, state: ClassRowState.kept, kept: kept);
    }
    final moment = entry.momentAt(now);
    final open = state.checkClassKeep(entry.facts) == ClassKeepCheck.open;
    final rowState = switch (moment) {
      ClassMoment.upcoming => ClassRowState.upcoming,
      ClassMoment.startsSoon => ClassRowState.startsSoon,
      ClassMoment.inSession =>
        open ? ClassRowState.inSession : ClassRowState.settled,
      ClassMoment.ended => open ? ClassRowState.ready : ClassRowState.settled,
    };
    return ClassRow(entry: entry, state: rowState);
  }
}

/// The next moment the card can change by itself: a countdown starting, a
/// minute of it passing, a class starting or ending, or the class day's night
/// ending. Null when nothing is left to wait for.
DateTime? nextClassBoundary(ClassDay day, DateTime now) {
  final instant = now.toUtc();
  DateTime? best;
  void consider(DateTime? at) {
    if (at == null) return;
    final utc = at.toUtc();
    if (!utc.isAfter(instant)) return;
    if (best == null || utc.isBefore(best!)) best = utc;
  }

  for (final entry in day.classes) {
    final soon = entry.startsAt.subtract(classStartsSoonLead);
    consider(soon);
    consider(entry.startsAt);
    consider(entry.endsAt);
    // Inside the countdown, the next whole minute changes "STARTS IN 12 MIN".
    if (!instant.isBefore(soon) && instant.isBefore(entry.startsAt)) {
      final left = entry.startsAt.difference(instant);
      final step = left - Duration(minutes: left.inMinutes);
      consider(instant.add(step == Duration.zero ? _minute : step));
    }
  }
  if (day.classes.isNotEmpty) {
    consider(classNightEndFor(day.date, day.classes.first.timeZoneId));
  }
  // The wind-down turns the room to the evening even with a class unmarked.
  consider(classWindDownStart(day));
  return best;
}

const _minute = Duration(minutes: 1);

// ── The evening ───────────────────────────────────────────────────────────

/// [now] on the timetable's own wall clock, so a phone or a test host in
/// another zone still reads the class day's hour. Comparisons on the result
/// stay instant-correct.
DateTime classLocalTime(ClassDay day, DateTime now) {
  if (day.classes.isNotEmpty) {
    try {
      return OccurrenceMaterializer.localTime(
        now,
        day.classes.first.timeZoneId,
      );
    } catch (_) {}
  }
  return now.toLocal();
}

/// The wind-down on a class day: the usual 17:00 to 04:00 window on the
/// timetable's clock, and never before the day's last class is over (his
/// Monday lecture runs 5:40 to 7:00, his Thursday lab until 6:50).
bool classWindDown(ClassDay day, DateTime now) =>
    isWindDownTime(classLocalTime(day, now), lastClassEnd: day.lastClassEnd);

/// When [day]'s wind-down begins: 17:00 in the timetable's zone, or the end
/// of the last class when that is later. Null on a day without classes.
DateTime? classWindDownStart(ClassDay day) {
  final end = day.lastClassEnd;
  if (end == null) return null;
  try {
    final (five, _) = OccurrenceMaterializer.resolveInstants(
      day.date,
      17 * 60,
      17 * 60,
      day.classes.first.timeZoneId,
    );
    return five.isAfter(end) ? five : end;
  } catch (_) {
    return end;
  }
}

/// The evening owns the room once the day's last class is over and either
/// every class is kept or the wind-down has begun. A class still unmarked
/// then is neutral: it can be marked until its night ends, and nothing waits
/// on it.
bool classEveningAt(ClassCard card, DateTime now) {
  final day = card.day;
  if (!day.isClassDay || !day.afterLastClass(now)) return false;
  return card.allKept || classWindDown(day, now);
}

/// Whether the board's own "close the day" door may show on [day]. A class
/// day closes in the evening room and the night ledger, so the board waits:
/// not while a class is coming, in session or ready to be marked, only once
/// the last class is over and either every class is kept or the wind-down has
/// begun (a class still unmarked then is neutral, as in [classEveningAt]).
/// A day without classes always may.
bool classDayLetsBoardCloseDay(ClassDay day, GameState state, DateTime now) {
  if (!day.isClassDay) return true;
  if (!day.afterLastClass(now)) return false;
  final keys = day.dayClassKeys;
  final kept = state.classesKeptOn(day.dayKey);
  final allKept =
      keys.isNotEmpty &&
      keys.every((key) => kept.any((item) => item.answersTo(key)));
  return allKept || classWindDown(day, now);
}

/// The day's record folded to one line: "Tuesday’s classes, both
/// attended". It counts what he went to and never what he did not: no
/// total beside a partial count.
String classRecordLine(ClassCard card) {
  final name = weekdayOf(card.day.date);
  final total = card.day.classes.length;
  final kept = card.keptCount;
  final noun = total == 1 ? '$name’s class' : '$name’s classes';
  if (kept == 0) return noun;
  if (kept >= total) {
    return switch (total) {
      1 => '$noun, attended',
      2 => '$noun, both attended',
      _ => '$noun, all ${classCountWord(total)} attended',
    };
  }
  return '$noun, ${classCountWord(kept)} attended';
}

/// The next class start or end after [now]: the moment something becomes
/// markable. Reopening the app after it brings the room back from the board.
DateTime? nextClassStartOrEnd(ClassDay day, DateTime now) {
  final instant = now.toUtc();
  DateTime? best;
  for (final entry in day.classes) {
    for (final at in [entry.startsAt.toUtc(), entry.endsAt.toUtc()]) {
      if (!at.isAfter(instant)) continue;
      if (best == null || at.isBefore(best)) best = at;
    }
  }
  return best;
}

// ── Words ─────────────────────────────────────────────────────────────────

const classWeekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _weekdayShort = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const _monthShort = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

/// "TUE · OCT 6".
String classDayStamp(CivilDate date) =>
    '${_weekdayShort[date.weekday - 1]} · ${_monthShort[date.month - 1]} '
    '${date.day}';

String weekdayOf(CivilDate date) => classWeekdays[date.weekday - 1];

/// "2:00 PM" from minutes after midnight.
String classClock(int minute) {
  final h24 = (minute ~/ 60) % 24;
  final h = h24 % 12 == 0 ? 12 : h24 % 12;
  final m = (minute % 60).toString().padLeft(2, '0');
  return '$h:$m ${h24 < 12 ? 'AM' : 'PM'}';
}

/// "2:00" without the meridiem, for rows and closing lines.
String classClockShort(int minute) {
  final h24 = (minute ~/ 60) % 24;
  final h = h24 % 12 == 0 ? 12 : h24 % 12;
  return '$h:${(minute % 60).toString().padLeft(2, '0')}';
}

/// "HLL 114": the building and room as a student says them.
String classPlace(ProjectedClass entry) {
  final place = entry.place;
  final parts = <String>[?place.building, ?place.room];
  return parts.isEmpty ? place.label : parts.join(' ');
}

/// The course as said out loud: "Introduction to" dropped.
String classShortTitle(String title) {
  final t = title.trim();
  for (final intro in const ['Introduction to ', 'Intro to ']) {
    if (t.startsWith(intro) && t.length > intro.length) {
      return t.substring(intro.length);
    }
  }
  return t;
}

/// For rows: a long registrar title keeps the part before " & "
/// ("Computer Architecture").
String classBriefTitle(String title) {
  final t = classShortTitle(title);
  final amp = t.indexOf(' & ');
  if (t.length > 28 && amp > 8) return t.substring(0, amp);
  return t;
}

String classKindWord(MeetingKind kind) => switch (kind) {
  MeetingKind.lecture => 'lecture',
  MeetingKind.lab => 'lab',
  MeetingKind.recitation => 'recitation',
  MeetingKind.studio => 'studio',
  MeetingKind.officeHours => 'office hour',
};

const _units = [
  'zero',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
  'eleven',
  'twelve',
  'thirteen',
  'fourteen',
  'fifteen',
  'sixteen',
  'seventeen',
  'eighteen',
  'nineteen',
  'twenty',
];

/// "three", or digits from 21 on.
String classCountWord(int n) => n >= 0 && n < _units.length ? _units[n] : '$n';

/// "2:00 PM" never breaks between the time and the meridiem.
String _keepTogether(String time) => time.replaceAll(' ', '\u00A0');

String _capital(String word) =>
    word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}';

/// "9TH", "21ST", "FIRST".
String classOrdinal(int n) {
  if (n == 1) return 'FIRST';
  final teen = n % 100;
  final suffix = teen >= 11 && teen <= 13
      ? 'TH'
      : switch (n % 10) {
          1 => 'ST',
          2 => 'ND',
          3 => 'RD',
          _ => 'TH',
        };
  return '$n$suffix';
}

/// The line that says what is actually next in the timetable after [day],
/// in a shape that follows the week, so it never repeats itself:
/// "Free until Monday at 8:30." "Thursday is the long one: three classes,
/// lab until 6:50." "Friday ends late: Discrete Structures II at 5:55."
/// "Tomorrow starts late: Computer Architecture at 10:20." "Nothing else
/// until Wednesday's 8:30 lab."
String nextClassDayLine(ClassDay day, ClassDay? Function(CivilDate) dayOf) {
  final next = day.nextClassAfter;
  if (next == null) return 'Nothing else on your timetable.';
  final nextDay = dayOf(next.date);
  final classes = nextDay != null && nextDay.isClassDay
      ? nextDay.classes
      : [next.entry];
  final first = classes.first;
  final last = classes.reduce(
    (a, b) => a.localEndMinute >= b.localEndMinute ? a : b,
  );
  final name = weekdayOf(next.date);
  if (next.daysAhead > 1) {
    // Within the week a weekday says it; past that (a break), the date does.
    final when = next.daysAhead > 6 ? next.dayWord : name;
    return 'Free until $when at ${classClockShort(first.localStartMinute)}.';
  }
  if (classes.length >= 3 && last.localEndMinute >= 18 * 60) {
    final what = last.kind == MeetingKind.lab ? 'lab' : 'class';
    return '$name is the long one: ${classCountWord(classes.length)} '
        'classes, $what until ${classClockShort(last.localEndMinute)}.';
  }
  final lastStart = classes.reduce(
    (a, b) => a.localStartMinute >= b.localStartMinute ? a : b,
  );
  if (lastStart.localStartMinute >= 17 * 60) {
    return '$name ends late: ${classBriefTitle(lastStart.title)} at '
        '${classClockShort(lastStart.localStartMinute)}.';
  }
  if (first.localStartMinute >= 10 * 60) {
    return 'Tomorrow starts late: ${classBriefTitle(first.title)} at '
        '${classClockShort(first.localStartMinute)}.';
  }
  return "Nothing else until $name's "
      '${classClockShort(first.localStartMinute)} ${classKindWord(first.kind)}.';
}

// ── The celebration's plan ────────────────────────────────────────────────

enum ClassCelebrationTier {
  /// A second mark within [quickWindow] of the last: "THAT ONE TOO.", played
  /// at 1.5x and back in about 1.4 s.
  quick,

  /// "YOU WERE THERE.": back on its own at about 2.4 s.
  classKept,

  /// The first mark after the day's last class ended, or the mark that
  /// completes the day: "TUESDAY, DONE.", held for a tap.
  dayDone,

  /// The same on the week's last class day: "THAT'S THE WEEK.", held.
  weekDone,
}

/// One kept class as a celebration row.
final class ClassCelebrationRow {
  const ClassCelebrationRow({
    required this.title,
    required this.time,
    required this.xp,
    required this.stat,
    required this.marked,
  });

  final String title;
  final String time;
  final int xp;
  final Stat stat;

  /// Kept by this gesture (the rest were kept earlier today).
  final bool marked;
}

/// Everything the celebration says about one gesture (one class, or several
/// through the shortcut), decided before it plays.
final class ClassCelebrationPlan {
  const ClassCelebrationPlan({
    required this.tier,
    required this.headline,
    required this.numeral,
    required this.numeralLabel,
    required this.title,
    required this.detail,
    required this.rows,
    required this.bonusLine,
    required this.bonusXp,
    required this.xpShown,
    required this.xpFrom,
    required this.caption,
    required this.gains,
    required this.totals,
    required this.level,
    required this.xpBefore,
    required this.xpForNextLevel,
    required this.xpGained,
    required this.closing,
    required this.streakLine,
    required this.semanticsLabel,
  });

  static const quickWindow = Duration(seconds: 15);

  final ClassCelebrationTier tier;
  final String headline;

  /// The diamond: his own count for this course (only grows); the classes
  /// kept today when one gesture kept several or on the day tier; the classes
  /// kept this week on the week tier.
  final int numeral;

  /// "YOUR 9TH LECTURE ON RECORD", "FIRST ONE ON RECORD", "CLASSES TODAY",
  /// "ATTENDED TODAY" (day tier), "ATTENDED THIS WEEK" (week tier).
  final String numeralLabel;

  /// The course, for a single mark (none on the day and week tiers).
  final String? title;

  /// "10:20 TO 11:40 · HLL 114", for a single mark.
  final String? detail;

  /// Today's kept classes (day tier, or a shortcut). On the week tier, one
  /// row per class day attended: [ClassCelebrationRow.title] is the day name
  /// and [ClassCelebrationRow.time] the number attended.
  final List<ClassCelebrationRow> rows;

  /// "All of Tuesday's classes" with [bonusXp], only when this gesture paid
  /// the full-day bonus.
  final String? bonusLine;
  final int bonusXp;

  /// The big number counts from [xpFrom] up to [xpShown].
  final int xpShown;
  final int xpFrom;

  /// Small line under the rail ("TUESDAY'S CLASSES · +35 THIS MARK").
  final String? caption;

  final Map<Stat, int> gains;
  final Map<Stat, int> totals;

  /// Level rail: the level and unspent XP before, its cost, and what landed.
  final int level;
  final int xpBefore;
  final int xpForNextLevel;
  final int xpGained;

  /// "Two for two." / "First one down." then what is next.
  final List<String> closing;

  /// Only when [ClassDayRules] lights the streak from classes and this mark
  /// lit the day.
  final String? streakLine;

  final String semanticsLabel;

  bool get held =>
      tier == ClassCelebrationTier.dayDone ||
      tier == ClassCelebrationTier.weekDone;

  bool get levelReady => xpBefore + xpGained >= xpForNextLevel;

  /// When it goes back to the room by itself (null: held for a tap).
  Duration? get autoReturn => switch (tier) {
    ClassCelebrationTier.quick => const Duration(milliseconds: 1400),
    ClassCelebrationTier.classKept => const Duration(milliseconds: 2400),
    _ => null,
  };

  /// The quick tier plays the class timeline at 1.5x.
  double get speed => tier == ClassCelebrationTier.quick ? 1.5 : 1.0;
}

/// Plans the celebration for [credits] (in the order they were kept) on
/// [day]. [state] is read after the keeps; [keptBefore] is what that day held
/// before this gesture. [dayOf] projects other days of the timetable.
ClassCelebrationPlan planClassCelebration({
  required ClassDay day,
  required GameState state,
  required List<ProjectedClass> marked,
  required List<ClassCredit> credits,
  required List<KeptClass> keptBefore,
  required DateTime now,
  required ClassDay? Function(CivilDate) dayOf,
  DateTime? previousMarkAt,
}) {
  assert(credits.isNotEmpty && credits.length == marked.length);
  final instant = now.toUtc();
  final dayName = weekdayOf(day.date);
  final keys = day.dayClassKeys;
  bool covers(Iterable<KeptClass> kept) =>
      keys.isNotEmpty &&
      keys.every((key) => kept.any((item) => item.answersTo(key)));
  final keptAfter = state.classesKeptOn(day.dayKey);
  final completeBefore = covers(keptBefore);
  final completeAfter = covers(keptAfter);
  final completes = completeAfter && !completeBefore;
  final lastEnd = day.lastClassEnd;
  // The clock-based day tier already played for this day: a class was kept
  // after the last one ended (or the day was complete before).
  final dayTierPlayed =
      completeBefore ||
      (lastEnd != null &&
          keptBefore.any((kept) => !kept.keptAt.toUtc().isBefore(lastEnd)));
  final afterLast =
      lastEnd != null && !instant.isBefore(lastEnd) && !dayTierPlayed;
  // The day tier plays once a day: the first mark after the last class has
  // ended, or the mark that completes the day when that came first. A mark
  // that completes the day after it played is a class (or quick) moment that
  // carries the full-day line and "Three for three." instead of a second
  // "MONDAY, DONE.".
  final dayTier = afterLast || (completes && !dayTierPlayed);

  // The week (Monday to Sunday) the class day belongs to.
  final monday = day.date.addDays(-(day.date.weekday - 1));
  final week = <ClassDay>[];
  var laterClassDays = false;
  for (var i = 0; i < 7; i++) {
    final date = monday.addDays(i);
    final other = date == day.date ? day : dayOf(date);
    if (other == null || !other.isClassDay) continue;
    week.add(other);
    if (date.compareTo(day.date) > 0) laterClassDays = true;
  }
  final weekTier = dayTier && !laterClassDays;
  final quick =
      !dayTier &&
      previousMarkAt != null &&
      instant.difference(previousMarkAt.toUtc()).abs() <
          ClassCelebrationPlan.quickWindow;
  final tier = weekTier
      ? ClassCelebrationTier.weekDone
      : dayTier
      ? ClassCelebrationTier.dayDone
      : quick
      ? ClassCelebrationTier.quick
      : ClassCelebrationTier.classKept;

  final several = credits.length > 1;
  final held =
      tier == ClassCelebrationTier.dayDone ||
      tier == ClassCelebrationTier.weekDone;
  final hero = credits.last;
  final heroEntry = marked.last;
  final inSession =
      !several && heroEntry.momentAt(now) == ClassMoment.inSession;
  final headline = switch (tier) {
    ClassCelebrationTier.weekDone => "THAT'S THE WEEK.",
    ClassCelebrationTier.dayDone => '${dayName.toUpperCase()}, DONE.',
    ClassCelebrationTier.quick => 'THAT ONE TOO.',
    ClassCelebrationTier.classKept =>
      inSession ? "YOU'RE HERE." : 'YOU WERE THERE.',
  };
  final gained = credits.fold(0, (sum, credit) => sum + credit.xp);
  final bonus = credits.fold(0, (sum, credit) => sum + credit.fullDayBonus);

  // Rows: today's kept classes in timetable order.
  final markedKeys = {for (final entry in marked) entry.facts.identity};
  final rows = <ClassCelebrationRow>[];
  if (tier == ClassCelebrationTier.weekDone) {
    // The week speaks in days: one row per class day he went to, with how
    // many he attended and that day's class XP. A day he did not attend gets
    // no row (no zero, no denominator).
    for (final other in week) {
      final kept = state.classesKeptOn(other.dayKey);
      if (kept.isEmpty) continue;
      final counts = <Stat, int>{};
      for (final item in kept) {
        counts[item.stat] = (counts[item.stat] ?? 0) + 1;
      }
      var lead = kept.first.stat;
      for (final entry in counts.entries) {
        if (entry.value > counts[lead]!) lead = entry.key;
      }
      rows.add(
        ClassCelebrationRow(
          title: weekdayOf(other.date),
          time: '${kept.length}',
          xp: state.classXpForDay(other.dayKey),
          stat: lead,
          marked: other.date == day.date,
        ),
      );
    }
  } else if (tier == ClassCelebrationTier.dayDone || several) {
    for (final entry in day.classes) {
      final kept = state.keptClassFor(entry.facts);
      if (kept == null) continue;
      rows.add(
        ClassCelebrationRow(
          title: classBriefTitle(entry.title),
          time: classClockShort(entry.localStartMinute),
          xp: kept.xp,
          stat: kept.stat,
          marked: markedKeys.contains(entry.facts.identity),
        ),
      );
    }
  }

  // The big number: this mark's XP, or the day's (or week's) class XP.
  final dayXpAfter = state.classXpForDay(day.dayKey);
  var weekXpAfter = 0;
  var weekKept = 0;
  var weekTotal = 0;
  // Every class kept this week, optional kinds (an office hour) included.
  var weekKeptAny = 0;
  for (final other in week) {
    weekXpAfter += state.classXpForDay(other.dayKey);
    weekKeptAny += state.classesKeptOn(other.dayKey).length;
    for (final entry in other.classes) {
      if (!entry.countsTowardDay) continue;
      weekTotal++;
      if (state.keptClassFor(entry.facts) != null) weekKept++;
    }
  }

  // The diamond counts its own scope. The day and week tiers speak for the
  // whole day or week (never the one class just marked, whose count would
  // contradict "TUESDAY, DONE."), and never against a denominator.
  final numeral = switch (tier) {
    ClassCelebrationTier.weekDone => weekKeptAny,
    ClassCelebrationTier.dayDone => keptAfter.length,
    _ => several ? keptAfter.length : hero.courseCount,
  };
  final numeralLabel = switch (tier) {
    ClassCelebrationTier.weekDone => 'ATTENDED THIS WEEK',
    ClassCelebrationTier.dayDone => 'ATTENDED TODAY',
    _ =>
      several
          ? 'CLASSES TODAY'
          // Only the marks on record are counted, so the words say "on
          // record": he has been to more lectures than the app has been told
          // about.
          : hero.courseCount == 1
          ? 'FIRST ONE ON RECORD'
          : 'YOUR ${classOrdinal(hero.courseCount)} '
                '${classKindWord(heroEntry.kind).toUpperCase()} ON RECORD',
  };

  // The stat chip speaks for the same classes the big number does: this
  // gesture's, the day's, or the week's. The marked class's stat leads.
  final scope = switch (tier) {
    ClassCelebrationTier.weekDone => [
      for (final other in week) ...state.classesKeptOn(other.dayKey),
    ],
    ClassCelebrationTier.dayDone => state.classesKeptOn(day.dayKey),
    _ => [for (final credit in credits) credit.kept],
  };
  final gains = <Stat, int>{hero.stat: 0};
  for (final kept in scope) {
    gains[kept.stat] = (gains[kept.stat] ?? 0) + kept.statGain;
  }
  gains.removeWhere((_, gain) => gain <= 0);
  final totals = {for (final stat in gains.keys) stat: state.stats[stat] ?? 0};
  final (shown, from, caption) = switch (tier) {
    ClassCelebrationTier.weekDone => (
      weekXpAfter,
      weekXpAfter - gained,
      weekXpAfter == gained
          ? "THIS WEEK'S CLASSES"
          : "THIS WEEK'S CLASSES · +$gained THIS MARK",
    ),
    ClassCelebrationTier.dayDone => (
      dayXpAfter,
      dayXpAfter - gained,
      dayXpAfter == gained
          ? "${dayName.toUpperCase()}'S CLASSES"
          : "${dayName.toUpperCase()}'S CLASSES · +$gained THIS MARK",
    ),
    _ => (gained, 0, null),
  };

  // Closing lines, from what is actually next.
  final closing = <String>[];
  if (tier == ClassCelebrationTier.weekDone) {
    if (weekKept == weekTotal && weekTotal > 0) {
      closing.add(
        '${_capital(classCountWord(weekTotal))} for '
        '${classCountWord(weekTotal)}.',
      );
    } else if (weekKeptAny > 0) {
      // Counts what he went to, every kind. Never a count of nothing.
      closing.add(
        '${_capital(classCountWord(weekKeptAny))} '
        '${weekKeptAny == 1 ? 'class' : 'classes'} this week.',
      );
    }
    closing.add(nextClassDayLine(day, dayOf));
  } else if (tier == ClassCelebrationTier.dayDone) {
    if (completeAfter) {
      closing.add(
        '${_capital(classCountWord(keys.length))} for '
        '${classCountWord(keys.length)}.',
      );
    }
    closing.add(nextClassDayLine(day, dayOf));
  } else {
    // The day tier already played tonight; the mark that completes the day
    // still says so, once, and only because it is true.
    if (completes) {
      closing.add(
        '${_capital(classCountWord(keys.length))} for '
        '${classCountWord(keys.length)}.',
      );
    }
    ProjectedClass? next;
    ProjectedClass? running;
    for (final entry in day.classes) {
      if (markedKeys.contains(entry.facts.identity)) continue;
      final moment = entry.momentAt(now);
      if (moment == ClassMoment.inSession &&
          state.keptClassFor(entry.facts) == null) {
        running ??= entry;
      }
      if (moment == ClassMoment.upcoming || moment == ClassMoment.startsSoon) {
        next ??= entry;
      }
    }
    if (next != null) {
      final nextName =
          tier == ClassCelebrationTier.quick && next.kind == MeetingKind.lab
          ? 'The lab'
          : classBriefTitle(next.title);
      final at = tier == ClassCelebrationTier.quick
          ? '$nextName is at ${classClockShort(next.localStartMinute)}, '
                'in ${classPlace(next)}.'
          : '$nextName is at ${_keepTogether(classClock(next.localStartMinute))}.';
      if (keptBefore.isEmpty && tier == ClassCelebrationTier.classKept) {
        closing.add(
          several
              ? '${_capital(classCountWord(credits.length))} down.'
              : 'First one down.',
        );
      }
      closing.add(at);
    } else if (running != null) {
      closing.add(
        '${classBriefTitle(running.title)} runs until '
        '${_keepTogether(classClock(running.localEndMinute))}.',
      );
    } else {
      closing.add(nextClassDayLine(day, dayOf));
    }
  }

  // The keep that lit the day carries the count. A later keep of the same
  // day (the shortcut's last credit) lights nothing and reads 0, so the
  // streak is read from the credit that lit, never from the last one. A
  // count under one is never shown.
  final lit = credits.where((credit) => credit.streak.lit);
  final streakDays = lit.isEmpty ? 0 : lit.last.streak.streakDays;
  final streakLine =
      ClassDayRules.current.classDayLightsStreak && streakDays >= 1
      ? '$streakDays ${streakDays == 1 ? 'DAY' : 'DAYS'} '
            'RUNNING · TODAY COUNTS'
      : null;

  final first = credits.first.level;
  // The day and week tiers name no single course: their list does.
  final title = several || held ? null : classShortTitle(heroEntry.title);
  // The quick tier says less: the course and what is next, no time and room.
  final detail = several || held || tier == ClassCelebrationTier.quick
      ? null
      : '${classClockShort(heroEntry.localStartMinute)} TO '
            '${classClockShort(heroEntry.localEndMinute)} · '
            '${classPlace(heroEntry)}';
  final semantics = [
    headline,
    ?title,
    if (held) '$numeral $numeralLabel'.toLowerCase(),
    '$gained XP',
    for (final entry in gains.entries) '${entry.value} ${entry.key.label}',
    ...closing,
  ].join(' ');

  return ClassCelebrationPlan(
    tier: tier,
    headline: headline,
    numeral: numeral,
    numeralLabel: numeralLabel,
    title: title,
    detail: detail,
    rows: rows,
    // The week's day rows already carry each day's full-day bonus, so a
    // separate bonus row would count the closing day's bonus twice.
    bonusLine: bonus > 0 && tier != ClassCelebrationTier.weekDone
        ? "All of $dayName's classes"
        : null,
    bonusXp: tier == ClassCelebrationTier.weekDone ? 0 : bonus,
    xpShown: shown,
    xpFrom: from < 0 ? 0 : from,
    caption: caption,
    gains: gains,
    totals: totals,
    level: first.level,
    xpBefore: first.xpBefore,
    xpForNextLevel: first.xpForNextLevel,
    xpGained: gained,
    closing: closing,
    streakLine: streakLine,
    semanticsLabel: semantics,
  );
}
