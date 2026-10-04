import '../../class_credit.dart';
import '../../models.dart' show Days;
import '../domain/academic_schedule.dart';

/// Where a class sits relative to a moment.
enum ClassMoment {
  /// More than [classStartsSoonLead] away.
  upcoming,

  /// Starts within [classStartsSoonLead].
  startsSoon,

  /// Between its start and its end.
  inSession,

  /// Over.
  ended,
}

/// How early a class reads as starting soon (and can be kept).
const classStartsSoonLead = Duration(minutes: 15);

/// One real class on a projected day.
final class ProjectedClass {
  const ProjectedClass({
    required this.occurrenceKey,
    required this.courseCode,
    required this.title,
    required this.kind,
    required this.place,
    required this.date,
    required this.originalDate,
    required this.startsAt,
    required this.endsAt,
    required this.localStartMinute,
    required this.localEndMinute,
    required this.timeZoneId,
    required this.moment,
  });

  final String occurrenceKey;
  final String courseCode;
  final String title;
  final MeetingKind kind;
  final CampusPlace place;

  /// The civil day it meets, and the day the timetable first put it on. They
  /// differ on a designated day that runs another weekday's classes.
  final CivilDate date;
  final CivilDate originalDate;

  /// Absolute instants (UTC). Compare these with now, never wall clocks.
  final DateTime startsAt;
  final DateTime endsAt;

  /// Minutes after midnight in [timeZoneId], for display.
  final int localStartMinute;
  final int localEndMinute;
  final String timeZoneId;

  /// Relative to the `now` the day was projected for.
  final ClassMoment moment;

  bool get moved => originalDate != date;

  String get placeLabel => place.shortLabel;

  /// Recomputes [moment] for another instant without projecting again.
  ClassMoment momentAt(DateTime now) => classMomentFor(startsAt, endsAt, now);

  /// The plain facts the engine keeps.
  ClassFacts get facts => ClassFacts(
    occurrenceKey: occurrenceKey,
    courseCode: courseCode,
    title: title,
    kind: kind.name,
    dayKey: date.toString(),
    startMinute: localStartMinute,
    startsAt: startsAt,
    endsAt: endsAt,
    nightEndsAt: classNightEndFor(date, timeZoneId),
  );

  /// Whether a full day waits on this class (office hours do not).
  bool get countsTowardDay => ClassPay.countsTowardDay(kind.name);
}

/// The next real class after a projected day, with the word for its day.
final class NextClass {
  const NextClass({
    required this.entry,
    required this.daysAhead,
    required this.dayWord,
  });

  final ProjectedClass entry;

  /// Civil days after the projected day (1 = tomorrow).
  final int daysAhead;

  /// `tomorrow`, a weekday name within the week (`Monday`), else a short
  /// date (`Oct 12`). Reads naturally after "Next class".
  final String dayWord;

  CivilDate get date => entry.date;
}

/// One day of classes, projected for a moment.
final class ClassDay {
  const ClassDay({
    required this.date,
    required this.classes,
    required this.lastClassEnd,
    required this.nextClassAfter,
    required this.runsWeekdayOf,
  });

  /// The night-owned civil day in the schedule's zone (before 04:00 belongs
  /// to the day before), unless a day was asked for.
  final CivilDate date;

  /// Real classes only, by start: not cancelled, not tombstoned, course
  /// present and not archived (the widget snapshot's filter), term not
  /// archived.
  final List<ProjectedClass> classes;

  /// The latest end among [classes] (UTC), or null on a day without classes.
  final DateTime? lastClassEnd;

  /// The first real class after [date] (tomorrow or later).
  final NextClass? nextClassAfter;

  /// On a designated day that runs another weekday's classes, that weekday
  /// (`DateTime.monday` ... `DateTime.sunday`), when every moved class agrees.
  final int? runsWeekdayOf;

  bool get isClassDay => classes.isNotEmpty;

  String get dayKey => date.toString();

  /// The identity of every class a full day is judged by, for the engine's
  /// full-day bonus. Optional kinds (office hours, [ClassPay.optionalKinds])
  /// stay on the board and can still be kept, but the bonus never waits on
  /// them.
  List<String> get dayClassKeys => [
    for (final entry in classes)
      if (entry.countsTowardDay) entry.facts.identity,
  ];

  bool afterLastClass(DateTime now) {
    final end = lastClassEnd;
    return end != null && !now.toUtc().isBefore(end);
  }
}

/// Where a class sits relative to [now], by instants only.
ClassMoment classMomentFor(DateTime startsAt, DateTime endsAt, DateTime now) {
  final instant = now.toUtc();
  if (!instant.isBefore(endsAt.toUtc())) return ClassMoment.ended;
  if (!instant.isBefore(startsAt.toUtc())) return ClassMoment.inSession;
  if (!instant.isBefore(startsAt.toUtc().subtract(classStartsSoonLead))) {
    return ClassMoment.startsSoon;
  }
  return ClassMoment.upcoming;
}

/// Projects the classes of the day that [now] belongs to. Pure: no clock, no
/// device time zone. The day is read in the schedule's own zone so a test
/// host (or a phone) in another zone still lands on the right date.
ClassDay projectClassDay(
  AcademicSchedule schedule,
  DateTime now, {
  CivilDate? day,
}) {
  final date = day ?? classDayDateFor(schedule, now);
  final real = [
    for (final occurrence in schedule.occurrencesOn(date))
      if (_isReal(schedule, occurrence)) occurrence,
  ]..sort(_byStart);
  final classes = [
    for (final occurrence in real) ?_project(schedule, occurrence, now),
  ];
  DateTime? lastEnd;
  for (final entry in classes) {
    if (lastEnd == null || entry.endsAt.isAfter(lastEnd)) {
      lastEnd = entry.endsAt;
    }
  }
  int? runs;
  if (classes.isNotEmpty && classes.every((entry) => entry.moved)) {
    final weekdays = {for (final entry in classes) entry.originalDate.weekday};
    if (weekdays.length == 1) runs = weekdays.single;
  }
  return ClassDay(
    date: date,
    classes: List.unmodifiable(classes),
    lastClassEnd: lastEnd,
    nextClassAfter: _nextAfter(schedule, date, now),
    runsWeekdayOf: runs,
  );
}

/// The night-owned civil date for [now] in the schedule's zone. Falls back to
/// the device's own day for a schedule without any zone yet.
CivilDate classDayDateFor(AcademicSchedule schedule, DateTime now) {
  final zone = _zoneOf(schedule);
  if (zone == null) {
    return CivilDate.fromDateTime(Days.nightDate(now.toLocal()));
  }
  final local = OccurrenceMaterializer.localTime(now, zone);
  final civil = CivilDate(local.year, local.month, local.day);
  return local.hour < 4 ? civil.addDays(-1) : civil;
}

/// The engine's facts for one occurrence, or null when its course is gone.
ClassFacts? classFactsFor(
  AcademicSchedule schedule,
  ClassOccurrence occurrence,
) {
  final course = schedule.courseById(occurrence.courseId);
  if (course == null) return null;
  return ClassFacts(
    occurrenceKey: occurrence.occurrenceKey,
    courseCode: course.code,
    title: course.title,
    kind: occurrence.kind.name,
    dayKey: occurrence.date.toString(),
    startMinute: occurrence.localStartMinute,
    startsAt: occurrence.startInstant.toUtc(),
    endsAt: occurrence.endInstant.toUtc(),
    nightEndsAt: classNightEndFor(occurrence.date, occurrence.timeZoneId),
  );
}

/// When a class day's night ends: 04:00 the next morning in [timeZoneId], as
/// a UTC instant (exact across a daylight-saving change). Null for a zone
/// the time zone database does not know; the engine then works the end out
/// from the class's start.
DateTime? classNightEndFor(CivilDate date, String timeZoneId) {
  try {
    final (end, _) = OccurrenceMaterializer.resolveInstants(
      date.addDays(1),
      4 * 60,
      4 * 60,
      timeZoneId,
    );
    return end.toUtc();
  } catch (_) {
    return null;
  }
}

/// A rest day for the streak's pause rule: a day inside a (not archived)
/// term with no real classes a full day waits on, such as a weekend, a
/// recess day, a day whose classes moved elsewhere, or a day holding only
/// office hours. Days outside every term are ordinary days.
bool restDayFor(AcademicSchedule schedule, String dayKey) {
  final parsed = Days.tryParse(dayKey);
  if (parsed == null) return false;
  final date = CivilDate(parsed.year, parsed.month, parsed.day);
  if (schedule.termFor(date) == null) return false;
  return !schedule
      .occurrencesOn(date)
      .any(
        (occurrence) =>
            _isReal(schedule, occurrence) &&
            ClassPay.countsTowardDay(occurrence.kind.name),
      );
}

bool _isReal(AcademicSchedule schedule, ClassOccurrence occurrence) {
  if (occurrence.state == OccurrenceState.cancelled ||
      occurrence.tombstonedAt != null) {
    return false;
  }
  final course = schedule.courseById(occurrence.courseId);
  if (course == null || course.archived) return false;
  for (final term in schedule.terms) {
    if (term.termId == course.termId) return !term.archived;
  }
  return true;
}

int _byStart(ClassOccurrence a, ClassOccurrence b) {
  final byStart = a.startInstant.toUtc().compareTo(b.startInstant.toUtc());
  return byStart != 0 ? byStart : a.occurrenceKey.compareTo(b.occurrenceKey);
}

ProjectedClass? _project(
  AcademicSchedule schedule,
  ClassOccurrence occurrence,
  DateTime now,
) {
  final course = schedule.courseById(occurrence.courseId);
  if (course == null) return null;
  final startsAt = occurrence.startInstant.toUtc();
  final endsAt = occurrence.endInstant.toUtc();
  return ProjectedClass(
    occurrenceKey: occurrence.occurrenceKey,
    courseCode: course.code,
    title: course.title,
    kind: occurrence.kind,
    place: occurrence.place,
    date: occurrence.date,
    originalDate: occurrence.originalDate,
    startsAt: startsAt,
    endsAt: endsAt,
    localStartMinute: occurrence.localStartMinute,
    localEndMinute: occurrence.localEndMinute,
    timeZoneId: occurrence.timeZoneId,
    moment: classMomentFor(startsAt, endsAt, now),
  );
}

NextClass? _nextAfter(AcademicSchedule schedule, CivilDate day, DateTime now) {
  ClassOccurrence? next;
  for (final occurrence in schedule.occurrences) {
    if (occurrence.date.compareTo(day) <= 0) continue;
    if (!_isReal(schedule, occurrence)) continue;
    if (next == null || _byStart(occurrence, next) < 0) next = occurrence;
  }
  if (next == null) return null;
  final entry = _project(schedule, next, now);
  if (entry == null) return null;
  final daysAhead = next.date.dateArithmeticValue
      .difference(day.dateArithmeticValue)
      .inDays;
  return NextClass(
    entry: entry,
    daysAhead: daysAhead,
    dayWord: _dayWord(next.date, daysAhead),
  );
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _dayWord(CivilDate date, int daysAhead) {
  if (daysAhead == 1) return 'tomorrow';
  if (daysAhead >= 2 && daysAhead <= 6) return _weekdays[date.weekday - 1];
  return '${_months[date.month - 1]} ${date.day}';
}

String? _zoneOf(AcademicSchedule schedule) {
  final term = schedule.latestTerm;
  if (term != null) return term.timeZoneId;
  if (schedule.terms.isNotEmpty) return schedule.terms.last.timeZoneId;
  if (schedule.occurrences.isNotEmpty) {
    return schedule.occurrences.first.timeZoneId;
  }
  return null;
}
