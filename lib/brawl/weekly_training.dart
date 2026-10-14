// This week's training, and the monster of the week.
//
// Quests raise stats during the week. The stats you trained THIS week boost
// their abilities in the weekend brawl, so the week you just lived is what the
// fight shows. A stat's training points are the number of quests finished for
// it since Monday 04:00 (not the raw stat gain, which varies with difficulty);
// a quest proven with the timer counts 1.5.
//
// Pure Dart: the engine remembers a small [TrainingMark] for every finished
// quest (and every class kept), and everything here is arithmetic on those
// marks and on a date. The caller passes `Clock.now()`; nothing in this file
// reads the wall clock, so a test can put any moment against any week.
library;

import 'dart:math' as math;

import '../tokens.dart';

/// A week runs from Monday at this hour. The small hours after midnight still
/// belong to the day before, as everywhere else in the app (a night owl's
/// Sunday does not end at 00:00).
const int trainingWeekStartHour = 4;

/// What a quest proven with the timer counts for, against 1 for any other.
const double timerProvenWeight = 1.5;

/// One point of training adds this much to the ability's boost...
const double boostPerPoint = 0.18;

/// ...up to this much in all, so a big week is about 4 times a quiet one.
const double boostCap = 3.0;

/// One finished quest (or kept class), as far as training goes.
class TrainingMark {
  const TrainingMark({required this.at, required this.stat, this.weight = 1.0});

  /// When it was finished.
  final DateTime at;

  /// The stat it trained.
  final Stat stat;

  /// 1, or [timerProvenWeight] for a quest proven with the timer.
  final double weight;

  Map<String, Object> toJson() => {
    't': at.millisecondsSinceEpoch,
    's': stat.index,
    if (weight != 1.0) 'w': weight,
  };

  /// A damaged entry reads as null and is left out, so one bad record never
  /// costs the rest of the week.
  static TrainingMark? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final t = raw['t'];
    final s = raw['s'];
    final w = raw['w'];
    if (t is! num || s is! num) return null;
    final index = s.toInt();
    if (index < 0 || index >= Stat.values.length) return null;
    final weight = w is num && w > 0 && w <= 10 ? w.toDouble() : 1.0;
    return TrainingMark(
      at: DateTime.fromMillisecondsSinceEpoch(t.toInt()),
      stat: Stat.values[index],
      weight: weight,
    );
  }
}

/// When the training week holding [now] began: the Monday at
/// [trainingWeekStartHour], local time. Built from calendar fields, so a
/// daylight-saving change inside the week never moves it by an hour.
DateTime trainingWeekStart(DateTime now) {
  final dayOffset = now.hour < trainingWeekStartHour ? -1 : 0;
  final day = DateTime(now.year, now.month, now.day + dayOffset);
  final monday = DateTime(day.year, day.month, day.day - (day.weekday - 1));
  return DateTime(monday.year, monday.month, monday.day, trainingWeekStartHour);
}

/// When the next training week begins.
DateTime nextTrainingWeekStart(DateTime now) {
  final start = trainingWeekStart(now);
  return DateTime(
    start.year,
    start.month,
    start.day + 7,
    trainingWeekStartHour,
  );
}

/// The training points per stat this week, up to [now]: every mark from
/// [trainingWeekStart] through [now], summed by weight. A mark in the future
/// (a clock set back) waits until its time; a mark before the week belongs to
/// the week it was in.
Map<Stat, double> trainingPoints(Iterable<TrainingMark> marks, DateTime now) {
  final start = trainingWeekStart(now);
  final points = {for (final stat in Stat.values) stat: 0.0};
  for (final mark in marks) {
    if (mark.at.isBefore(start) || mark.at.isAfter(now)) continue;
    points[mark.stat] = points[mark.stat]! + mark.weight;
  }
  return points;
}

/// How much a stat's ability is boosted by [points] of training: 1 for none,
/// then 0.18 more for each point, up to 4.
double boostOf(num points) {
  if (points <= 0) return 1;
  return 1 + math.min(boostCap, boostPerPoint * points);
}

/// A training count in plain words: "6", or "7.5" when a timer-proven quest
/// made it a half.
String pointsLabel(double points) {
  final rounded = (points * 2).round() / 2;
  return rounded == rounded.roundToDouble()
      ? '${rounded.round()}'
      : rounded.toStringAsFixed(1);
}

/// The week's training for all six stats, with the boost each one earns.
class WeeklyTraining {
  const WeeklyTraining(this.points);

  /// A week with nothing trained yet.
  WeeklyTraining.quiet() : points = {for (final s in Stat.values) s: 0.0};

  /// Read from the marks the engine remembers, at [now].
  factory WeeklyTraining.from(Iterable<TrainingMark> marks, DateTime now) =>
      WeeklyTraining(trainingPoints(marks, now));

  final Map<Stat, double> points;

  double pointsOf(Stat stat) => points[stat] ?? 0;

  /// The boost [stat]'s ability earns this week (1 to 4).
  double boost(Stat stat) => boostOf(pointsOf(stat));

  /// Whether [stat] was trained this week at all.
  bool trained(Stat stat) => pointsOf(stat) > 0;

  /// Whether anything at all was trained this week.
  bool get any => points.values.any((p) => p > 0);

  /// "+6 this week", or null when [stat] was not trained.
  String? lineFor(Stat stat) =>
      trained(stat) ? '+${pointsLabel(pointsOf(stat))} this week' : null;
}

/// A monster of the week.
class WeeklyMonster {
  const WeeklyMonster({
    required this.id,
    required this.name,
    required this.weakness,
  });

  /// A stable key for art and saves: "couch_troll".
  final String id;

  /// "Couch Troll".
  final String name;

  /// The stat whose ability lands the hardest on it.
  final Stat weakness;

  /// "the Couch Troll", for a sentence.
  String get theName => 'the $name';

  /// "weak to Strength".
  String get weakLine => 'weak to ${weakness.label}';
}

/// Even weeks the Couch Troll naps on the sofa and gives way to Strength.
const couchTroll = WeeklyMonster(
  id: 'couch_troll',
  name: 'Couch Troll',
  weakness: Stat.str,
);

/// Odd weeks the Fog rolls in and thins out to Intellect.
const theFog = WeeklyMonster(id: 'fog', name: 'Fog', weakness: Stat.intl);

/// The ISO 8601 week number (1 to 53) of the calendar day [d] falls in.
int isoWeekNumber(DateTime d) {
  final day = DateTime.utc(d.year, d.month, d.day);
  // The Thursday of the week names its year and so its number.
  final thursday = day.add(Duration(days: 4 - day.weekday));
  final jan1 = DateTime.utc(thursday.year, 1, 1);
  return 1 + thursday.difference(jan1).inDays ~/ 7;
}

/// The monster of the week for [date]: even ISO weeks the Couch Troll, odd
/// weeks the Fog. The week is the training week, so it changes on Monday at
/// 04:00 as the training does, and Sunday night's fight is still the weekend's.
WeeklyMonster monsterOfTheWeek(DateTime date) =>
    isoWeekNumber(trainingWeekStart(date)).isEven ? couchTroll : theFog;

/// "This weekend: the Couch Troll · weak to Strength".
String weekendPreviewLine(DateTime date) {
  final monster = monsterOfTheWeek(date);
  return 'This weekend: ${monster.theName} · ${monster.weakLine}';
}
