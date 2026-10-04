/// Typing a class in by hand, fast: one name line, day chips, a start time and
/// a length. The term is inferred (the one already in Plans, or this season),
/// and the class starts this week so nothing earlier fills up with old
/// meetings.
library;

import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';

import 'calendar_class_finder.dart';

final class QuickClassEntry {
  QuickClassEntry({
    required this.name,
    required Set<int> weekdays,
    required this.startMinute,
    required this.lengthMinutes,
    this.place,
  }) : weekdays = Set.unmodifiable(weekdays);

  final String name;
  final Set<int> weekdays;
  final int startMinute;
  final int lengthMinutes;
  final String? place;

  int get endMinute => startMinute + lengthMinutes;
  ClassName get reading => ClassNameReader.read(name.trim());

  /// A showable reason this entry cannot be added yet, or null.
  String? get problem {
    if (name.trim().isEmpty) return 'Give the class a name.';
    if (weekdays.isEmpty) return 'Pick the days it meets.';
    if (lengthMinutes < 10 || endMinute > 24 * 60) {
      return 'That length runs past midnight.';
    }
    return null;
  }
}

/// Common class lengths, in minutes, offered as chips.
const quickClassLengths = <int>[50, 75, 80, 110, 180];

abstract final class QuickClassPlanner {
  /// The term a typed class joins: the active term for [today] if Plans has
  /// one, otherwise this season, starting the Monday of this week.
  static AcademicTerm termFor(
    AcademicSchedule schedule,
    CivilDate today, {
    required String timeZoneId,
  }) {
    final existing = schedule.termFor(today);
    if (existing != null) return existing;
    final start = today.startOfWeek(DateTime.monday);
    final season = seasonAround(today);
    return AcademicTerm(
      termId: AcademicIds.create('term'),
      name: '${season.name} ${today.year}',
      startDate: start,
      endDate: season.end,
      timeZoneId: timeZoneId,
    );
  }

  /// Adds [entry] to [schedule] in [term]. A class whose code (or name)
  /// matches an existing course in the term joins it instead of duplicating.
  static AcademicSchedule add(
    AcademicSchedule schedule,
    QuickClassEntry entry, {
    required AcademicTerm term,
    required CivilDate today,
    required DateTime updatedAt,
    int colorIndex = 0,
  }) {
    final problem = entry.problem;
    if (problem != null) throw ArgumentError(problem);
    final reading = entry.reading;
    String norm(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final match = schedule.courses.where(
      (course) =>
          course.termId == term.termId &&
          !course.archived &&
          (reading.codeFound
              ? norm(course.code) == norm(reading.code)
              : norm(course.title) == norm(reading.title)),
    );
    final palette = _quickColors[colorIndex % _quickColors.length];
    final course =
        match.firstOrNull ??
        AcademicCourse(
          courseId: AcademicIds.create('course'),
          termId: term.termId,
          code: reading.code,
          title: reading.title,
          section: reading.section,
          colorValue: palette.$1,
          colorLabel: palette.$2,
        );
    final weekStart = today.startOfWeek(DateTime.monday);
    var first = weekStart.compareTo(term.startDate) < 0
        ? term.startDate
        : weekStart;
    if (first.compareTo(term.endDate) > 0) first = term.endDate;
    final place = entry.place?.trim();
    final series = MeetingSeries(
      meetingSeriesId: AcademicIds.create('series'),
      courseId: course.courseId,
      kind: reading.kind,
      weekdays: entry.weekdays,
      localStartMinute: entry.startMinute,
      localEndMinute: entry.endMinute,
      firstDate: first,
      lastDate: term.endDate,
      timeZoneId: term.timeZoneId,
      place: CampusPlace(
        label: place == null || place.isEmpty ? 'Location not set' : place,
      ),
      updatedAt: updatedAt.toUtc(),
    );
    return schedule.putMeeting(
      term: term,
      course: course,
      series: series,
      updatedAt: updatedAt,
    );
  }
}

const _quickColors = <(int, String)>[
  (0xFF8AAFC6, 'Dusk blue'),
  (0xFF9CBC88, 'Moss'),
  (0xFFDD9A72, 'Terracotta'),
  (0xFFAE9AC4, 'Lilac'),
  (0xFF93A7E0, 'Periwinkle'),
  (0xFFC79355, 'Aged bronze'),
];
