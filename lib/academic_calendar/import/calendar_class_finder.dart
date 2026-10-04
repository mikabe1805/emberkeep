/// Reads ordinary calendar exports (Google Calendar, Outlook, iCloud, a school
/// portal, Canvas, or a Room of Days file) and finds the weekly events that
/// look like classes. Nothing here changes a schedule until [applyTo] runs
/// after the student has reviewed the list.
///
/// It sits beside the Room of Days importer, which keeps handling files that
/// carry the X-ROOM-OF-DAYS-* fields exactly as before
/// ([ClassScheduleReader.read] routes them there).
library;

import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/clock.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

/// What a calendar file turned into.
sealed class ClassScheduleRead {
  const ClassScheduleRead();
}

/// A file made in the Room of Days format (the editable starter, or Mika's
/// own Rutgers file). It goes through the original importer unchanged, so
/// its stable IDs match anything already imported from it.
final class RoomOfDaysScheduleRead extends ClassScheduleRead {
  const RoomOfDaysScheduleRead(this.draft);
  final AcademicScheduleImportDraft draft;
}

/// Any other calendar: a list of possible classes to pick from.
final class CalendarClassesRead extends ClassScheduleRead {
  const CalendarClassesRead(this.draft);
  final CalendarClassImportDraft draft;
}

abstract final class ClassScheduleReader {
  /// Reads [text]. Throws [FormatException] only when it is not a calendar at
  /// all. A calendar with no weekly classes comes back as a draft with no
  /// candidates and the counts of what it did hold, so the review can say so.
  ///
  /// [fallbackTimeZoneId] is used for floating times and UTC-only feeds that
  /// name no zone (pass the device zone). [today] places open-ended weekly
  /// events inside a sensible term and picks the current term when an export
  /// spans more than one.
  static ClassScheduleRead read(
    String text, {
    String? sourceName,
    String fallbackTimeZoneId = 'America/New_York',
    CivilDate? today,
  }) {
    if (text.contains('X-ROOM-OF-DAYS-COURSE-CODE')) {
      try {
        return RoomOfDaysScheduleRead(
          AcademicScheduleIcsImporter.parse(text, sourceName: sourceName),
        );
      } on FormatException {
        // An edited starter in another zone, or with a missing field: the
        // general reader still honors every X-ROOM-OF-DAYS field it finds.
      }
    }
    return CalendarClassesRead(
      CalendarClassFinder.find(
        text,
        sourceName: sourceName,
        fallbackTimeZoneId: fallbackTimeZoneId,
        today: today,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Candidates and the review draft
// ─────────────────────────────────────────────────────────────────────────────

/// How a candidate was found.
enum ClassCandidateOrigin {
  /// A weekly repeating event (RRULE).
  repeating,

  /// Separate one-time events at the same time each week, gathered into a
  /// weekly series (some school portals export every meeting on its own, and
  /// a phone calendar hands over expanded meetings the same way).
  gathered,
}

/// One meeting that a class moved to (RECURRENCE-ID with a new time or day).
final class ClassMove {
  const ClassMove({
    required this.from,
    required this.to,
    required this.startMinute,
    required this.endMinute,
  });
  final CivilDate from;
  final CivilDate to;
  final int startMinute;
  final int endMinute;
}

/// One weekly meeting pattern that might be a class.
final class ClassCandidate {
  ClassCandidate({
    required this.key,
    required this.summary,
    required this.name,
    required this.location,
    required this.weekdays,
    required this.startMinute,
    required this.endMinute,
    required this.intervalWeeks,
    required this.firstDate,
    required this.lastDate,
    required this.endWasOpen,
    required this.skippedDates,
    required this.moves,
    required this.origin,
    required this.score,
    required this.signals,
    this.roomOfDays,
  });

  /// Stable across re-imports of the same calendar (UID, or the gathered
  /// pattern), so importing again refreshes instead of duplicating.
  final String key;
  final String summary;
  final ClassName name;
  final String? location;
  final Set<int> weekdays;
  final int startMinute;
  final int endMinute;
  final int intervalWeeks;
  final CivilDate firstDate;

  /// Null when the calendar gave no end (no UNTIL or COUNT); the draft's
  /// term end is used instead.
  final CivilDate? lastDate;
  final bool endWasOpen;
  final Set<CivilDate> skippedDates;
  final List<ClassMove> moves;
  final ClassCandidateOrigin origin;
  final int score;

  /// Why the score is what it is ("+3 course code"), for tests and support.
  final List<String> signals;

  /// Term and place fields from a Room of Days file, when present.
  final RoomOfDaysFields? roomOfDays;

  static const likelyScore = 4;
  bool get looksLikeClass => score >= likelyScore;
  int get lengthMinutes => endMinute - startMinute;

  /// The dates this pattern covers, with an open end closed at the end of
  /// its season (used to tell terms apart, never to place meetings).
  (CivilDate, CivilDate) get span =>
      (firstDate, lastDate ?? seasonAround(firstDate).end);
}

/// The Room of Days fields a file may carry on any event.
final class RoomOfDaysFields {
  const RoomOfDaysFields({
    this.termName,
    this.termStart,
    this.termEnd,
    this.campus,
    this.building,
    this.room,
  });
  final String? termName;
  final CivilDate? termStart;
  final CivilDate? termEnd;
  final String? campus;
  final String? building;
  final String? room;
}

/// A course as the review shows it: one or more weekly meetings.
final class ClassReviewCourse {
  const ClassReviewCourse({
    required this.key,
    required this.code,
    required this.codeFound,
    required this.title,
    required this.section,
    required this.candidates,
  });
  final String key;
  final String code;
  final bool codeFound;
  final String title;
  final String? section;
  final List<ClassCandidate> candidates;
  bool get looksLikeClass => candidates.any((item) => item.looksLikeClass);
}

/// One term an export covers. A full Google export can hold last spring and
/// this fall; the review shows one term at a time and starts on the current
/// (or next) one.
final class ClassTermChoice {
  const ClassTermChoice({
    required this.index,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.likelyCourseCount,
    required this.candidateKeys,
  });
  final int index;
  final String name;
  final CivilDate startDate;
  final CivilDate endDate;

  /// Courses in this term that look like classes.
  final int likelyCourseCount;
  final Set<String> candidateKeys;
}

/// A reviewable, non-mutating import from an ordinary calendar.
final class CalendarClassImportDraft {
  CalendarClassImportDraft._({
    required this.sourceName,
    required this.calendarName,
    required this.timeZoneId,
    required this.candidates,
    required this.selectedKeys,
    required this.today,
    required this.allDayCount,
    required this.oneTimeCount,
    required this.deadlineCount,
    required this.otherRepeatingCount,
    required this.termChoices,
    required this.activeTermIndex,
    this.termOverride,
  });

  final String sourceName;
  final String? calendarName;
  final String timeZoneId;

  /// Every weekly pattern in the calendar, across every term it covers.
  final List<ClassCandidate> candidates;
  final Set<String> selectedKeys;
  final CivilDate today;

  /// What the calendar held that is not a weekly class, for one calm line.
  final int allDayCount;
  final int oneTimeCount;
  final int deadlineCount;
  final int otherRepeatingCount;

  /// The terms this calendar covers (one when it covers one), and the one
  /// the review is showing.
  final List<ClassTermChoice> termChoices;
  final int activeTermIndex;
  final AcademicTerm? termOverride;

  bool get hasCandidates => candidates.isNotEmpty;

  ClassTermChoice get activeTerm => termChoices[activeTermIndex];

  /// The other terms the same calendar holds, for "also in this file".
  List<ClassTermChoice> get otherTerms => [
    for (final choice in termChoices)
      if (choice.index != activeTermIndex) choice,
  ];

  /// The weekly patterns in the term the review is showing.
  List<ClassCandidate> get activeCandidates => [
    for (final item in candidates)
      if (activeTerm.candidateKeys.contains(item.key)) item,
  ];

  /// Outlook publishes "busy only" by default: every event is titled Busy.
  bool get titlesHidden {
    if (candidates.isEmpty) return false;
    final hidden = candidates.where((item) => _titleHidden(item.summary));
    return hidden.length * 5 >= candidates.length * 4;
  }

  bool get foundLikelyClasses =>
      activeCandidates.any((item) => item.looksLikeClass);

  /// Picked patterns in the term the review is showing. A key from another
  /// term never counts, so one import always lands in one term.
  List<ClassCandidate> get selected => [
    for (final item in activeCandidates)
      if (selectedKeys.contains(item.key)) item,
  ];

  /// The shown term's patterns grouped into courses, likely ones first.
  List<ClassReviewCourse> get courses => _groupCourses(activeCandidates);

  List<ClassReviewCourse> get selectedCourses => _groupCourses(selected);

  CalendarClassImportDraft withSelected(String key, bool selected) => _copy(
    selectedKeys: {
      ...selectedKeys.where((item) => item != key),
      if (selected) key,
    },
  );

  CalendarClassImportDraft withCourseSelected(
    ClassReviewCourse course,
    bool selected,
  ) {
    final keys = {for (final item in course.candidates) item.key};
    return _copy(
      selectedKeys: {
        ...selectedKeys.where((item) => !keys.contains(item)),
        if (selected) ...keys,
      },
    );
  }

  /// Shows another term from the same calendar, with its likely classes
  /// checked and nothing from the term before.
  CalendarClassImportDraft withActiveTerm(int index) {
    if (index < 0 || index >= termChoices.length) {
      throw RangeError.index(index, termChoices, 'index');
    }
    final keys = termChoices[index].candidateKeys;
    return CalendarClassImportDraft._(
      sourceName: sourceName,
      calendarName: calendarName,
      timeZoneId: timeZoneId,
      candidates: candidates,
      selectedKeys: Set.unmodifiable({
        for (final item in candidates)
          if (keys.contains(item.key) && item.looksLikeClass) item.key,
      }),
      today: today,
      allDayCount: allDayCount,
      oneTimeCount: oneTimeCount,
      deadlineCount: deadlineCount,
      otherRepeatingCount: otherRepeatingCount,
      termChoices: termChoices,
      activeTermIndex: index,
    );
  }

  CalendarClassImportDraft withTermEnd(CivilDate end) {
    final current = term;
    return _copy(
      termOverride: AcademicTerm(
        termId: _stableId('term', '${current.name}|${current.startDate}|$end'),
        name: current.name,
        startDate: current.startDate.compareTo(end) <= 0
            ? current.startDate
            : end,
        endDate: end,
        timeZoneId: timeZoneId,
      ),
    );
  }

  CalendarClassImportDraft _copy({
    Set<String>? selectedKeys,
    AcademicTerm? termOverride,
  }) => CalendarClassImportDraft._(
    sourceName: sourceName,
    calendarName: calendarName,
    timeZoneId: timeZoneId,
    candidates: candidates,
    selectedKeys: Set.unmodifiable(selectedKeys ?? this.selectedKeys),
    today: today,
    allDayCount: allDayCount,
    oneTimeCount: oneTimeCount,
    deadlineCount: deadlineCount,
    otherRepeatingCount: otherRepeatingCount,
    termChoices: termChoices,
    activeTermIndex: activeTermIndex,
    termOverride: termOverride ?? this.termOverride,
  );

  /// The term the selected classes fall in: a Room of Days term when the file
  /// names one, otherwise the span of the selected classes, named by season.
  /// Open-ended classes run to the end of that season.
  AcademicTerm get term {
    if (termOverride != null) return termOverride!;
    final picked = selected.isEmpty ? activeCandidates : selected;
    final named = picked
        .map((item) => item.roomOfDays)
        .whereType<RoomOfDaysFields>()
        .where(
          (item) =>
              item.termName != null &&
              item.termStart != null &&
              item.termEnd != null,
        )
        .firstOrNull;
    if (named != null) {
      return AcademicTerm(
        termId: _stableId(
          'term',
          '${named.termName}|${named.termStart}|${named.termEnd}',
        ),
        name: named.termName!,
        startDate: named.termStart!,
        endDate: named.termEnd!,
        timeZoneId: timeZoneId,
      );
    }
    final span = _termSpan(picked, today);
    final name = '${seasonAround(span.$1).name} ${span.$1.year}';
    return AcademicTerm(
      termId: _stableId('term', '$name|${span.$1}|${span.$2}'),
      name: name,
      startDate: span.$1,
      endDate: span.$2,
      timeZoneId: timeZoneId,
    );
  }

  bool get usesSeasonEnd =>
      termOverride == null && selected.any((item) => item.endWasOpen);

  /// Class meetings the selected series will place on the calendar.
  int get projectedOccurrenceCount {
    final t = term;
    return selected.fold<int>(0, (sum, item) {
      final dates = _meetingDates(item, t);
      final moved = item.moves.where(
        (move) => move.to.isWithin(t.startDate, t.endDate),
      );
      return sum + dates.length + moved.length;
    });
  }

  /// Adds the selected classes to [existing]. Re-applying the same calendar
  /// refreshes the same courses and meetings (stable IDs) and never touches
  /// a meeting the student moved or cancelled by hand. A school portal that
  /// hands out new event IDs with every export still lands on the meetings
  /// already there: a course's meeting with the same days, times and kind is
  /// refreshed instead of added twice.
  AcademicSchedule applyTo(
    AcademicSchedule existing, {
    required DateTime updatedAt,
  }) {
    final t = term;
    final existingTerm = existing.terms
        .where((item) => item.termId == t.termId)
        .firstOrNull;
    final resolvedTerm = existingTerm ?? t;
    var next = existing;
    final groups = selectedCourses;
    for (var index = 0; index < groups.length; index++) {
      final group = groups[index];
      final courseId = _stableId(
        'course',
        '${resolvedTerm.termId}|${group.code}|${group.title}',
      );
      for (final candidate in group.candidates) {
        final first = _later(candidate.firstDate, resolvedTerm.startDate);
        final last = _earlier(
          candidate.lastDate ?? resolvedTerm.endDate,
          resolvedTerm.endDate,
        );
        if (last.compareTo(first) < 0) continue;
        final priorCourse = next.courseById(courseId);
        final palette = _courseColors[index % _courseColors.length];
        final course = AcademicCourse(
          courseId: courseId,
          termId: resolvedTerm.termId,
          code: group.code,
          title: group.title,
          section: group.section,
          colorValue: priorCourse?.colorValue ?? palette.$1,
          colorLabel: priorCourse?.colorLabel ?? palette.$2,
          meetingSeriesIds: priorCourse?.meetingSeriesIds ?? const [],
        );
        final seriesId = _seriesIdFor(next, candidate, courseId);
        final prior = next.meetingSeriesById(seriesId);
        final fields = candidate.roomOfDays;
        final series = MeetingSeries(
          meetingSeriesId: seriesId,
          courseId: courseId,
          kind: candidate.name.kind,
          weekdays: candidate.weekdays,
          localStartMinute: candidate.startMinute,
          localEndMinute: candidate.endMinute,
          intervalWeeks: candidate.intervalWeeks,
          firstDate: first,
          lastDate: last,
          timeZoneId: resolvedTerm.timeZoneId,
          place: CampusPlace(
            label: candidate.location ?? 'Location not set',
            building: fields?.building,
            room: fields?.room,
            campusCode: fields?.campus,
          ),
          reminders: prior?.reminders ?? const <AcademicReminder>[],
          updatedAt: updatedAt.toUtc(),
        );
        next = next.putMeeting(
          term: resolvedTerm,
          course: course,
          series: series,
          updatedAt: updatedAt,
        );
        final movedFrom = <CivilDate>{};
        for (final move in candidate.moves) {
          if (!move.to.isWithin(resolvedTerm.startDate, resolvedTerm.endDate)) {
            continue;
          }
          final original = next.occurrences
              .where(
                (item) =>
                    item.meetingSeriesId == seriesId &&
                    item.originalDate == move.from,
              )
              .firstOrNull;
          if (original == null || original.userAdjusted) continue;
          movedFrom.add(move.from);
          next = next.moveOccurrence(
            occurrenceKey: original.occurrenceKey,
            date: move.to,
            startMinute: move.startMinute,
            endMinute: move.endMinute,
            updatedAt: updatedAt,
          );
        }
        for (final date in candidate.skippedDates) {
          if (movedFrom.contains(date)) continue;
          final original = next.occurrences
              .where(
                (item) =>
                    item.meetingSeriesId == seriesId &&
                    item.originalDate == date,
              )
              .firstOrNull;
          if (original != null &&
              !original.userAdjusted &&
              original.state != OccurrenceState.cancelled) {
            next = next.cancelOccurrence(
              occurrenceKey: original.occurrenceKey,
              updatedAt: updatedAt,
            );
          }
        }
      }
    }
    return next;
  }
}

/// The stable series ID for [candidate], or the ID of the same weekly meeting
/// already in [schedule] under an older event ID.
String _seriesIdFor(
  AcademicSchedule schedule,
  ClassCandidate candidate,
  String courseId,
) {
  final stable = _stableId('meeting', candidate.key);
  if (schedule.meetingSeriesById(stable) != null) return stable;
  final twin = schedule.meetingSeries.where(
    (series) =>
        series.tombstonedAt == null &&
        series.courseId == courseId &&
        series.kind == candidate.name.kind &&
        series.localStartMinute == candidate.startMinute &&
        series.localEndMinute == candidate.endMinute &&
        series.intervalWeeks == candidate.intervalWeeks &&
        series.weekdays.length == candidate.weekdays.length &&
        series.weekdays.containsAll(candidate.weekdays),
  );
  return twin.firstOrNull?.meetingSeriesId ?? stable;
}

/// First and last day of a term made from [picked]. An open-ended series (a
/// gym slot from June) never drags the term back before this week.
(CivilDate, CivilDate) _termSpan(List<ClassCandidate> picked, CivilDate today) {
  CivilDate startOf(ClassCandidate item) => item.endWasOpen
      ? _later(item.firstDate, today.startOfWeek(DateTime.monday))
      : item.firstDate;
  final start = picked.isEmpty ? today : picked.map(startOf).reduce(_earlier);
  final season = seasonAround(start);
  final ends = [for (final item in picked) item.lastDate ?? season.end];
  var end = ends.isEmpty ? season.end : ends.reduce(_later);
  if (end.compareTo(start) < 0) end = start;
  return (start, end);
}

// ─────────────────────────────────────────────────────────────────────────────
// Telling terms apart
// ─────────────────────────────────────────────────────────────────────────────

int _days(CivilDate from, CivilDate to) =>
    to.dateArithmeticValue.difference(from.dateArithmeticValue).inDays;

/// Days two spans share (zero or less when they do not meet).
int _overlapDays((CivilDate, CivilDate) a, (CivilDate, CivilDate) b) =>
    _days(_later(a.$1, b.$1), _earlier(a.$2, b.$2)) + 1;

/// Splits [candidates] into terms. Classes in one term share most of their
/// dates; last spring and this fall share none. Only likely classes shape
/// the terms (a gym slot with no end would join every term together); every
/// other pattern joins the term it overlaps most. Returns the terms in date
/// order and the index of the current one: the term holding [today], else
/// the next to start, else the most recent.
(List<ClassTermChoice>, int) _termChoices(
  List<ClassCandidate> candidates,
  CivilDate today,
) {
  final likely = [
    for (final item in candidates)
      if (item.looksLikeClass) item,
  ];
  if (likely.isEmpty) {
    final span = _termSpan(candidates, today);
    return (
      [
        ClassTermChoice(
          index: 0,
          name: '${seasonAround(span.$1).name} ${span.$1.year}',
          startDate: span.$1,
          endDate: span.$2,
          likelyCourseCount: 0,
          candidateKeys: {for (final item in candidates) item.key},
        ),
      ],
      0,
    );
  }

  // Union-find over likely classes that share enough of their dates.
  final parent = List<int>.generate(likely.length, (index) => index);
  int root(int index) {
    var at = index;
    while (parent[at] != at) {
      parent[at] = parent[parent[at]];
      at = parent[at];
    }
    return at;
  }

  for (var i = 0; i < likely.length; i++) {
    for (var j = i + 1; j < likely.length; j++) {
      final a = likely[i].span;
      final b = likely[j].span;
      final shorter = [
        _days(a.$1, a.$2) + 1,
        _days(b.$1, b.$2) + 1,
      ].reduce((x, y) => x < y ? x : y);
      final needed = (shorter ~/ 2).clamp(1, 14);
      if (_overlapDays(a, b) >= needed) parent[root(i)] = root(j);
    }
  }
  final grouped = <int, List<ClassCandidate>>{};
  for (var i = 0; i < likely.length; i++) {
    (grouped[root(i)] ??= []).add(likely[i]);
  }
  final clusters = grouped.values.toList()
    ..sort((a, b) {
      final first = a.map((item) => item.span.$1).reduce(_earlier);
      final second = b.map((item) => item.span.$1).reduce(_earlier);
      return first.compareTo(second);
    });
  final spans = [
    for (final cluster in clusters)
      (
        cluster.map((item) => item.span.$1).reduce(_earlier),
        cluster.map((item) => item.span.$2).reduce(_later),
      ),
  ];

  final members = [
    for (final cluster in clusters) {for (final item in cluster) item.key},
  ];
  for (final item in candidates) {
    if (item.looksLikeClass) continue;
    // An open end reaches as far as the latest term, so a weekly habit with
    // no end joins whichever term it overlaps most.
    final reach = item.lastDate ?? spans.last.$2;
    final own = (item.firstDate, _later(reach, item.firstDate));
    var best = 0;
    var bestScore = -1 << 30;
    for (var i = 0; i < spans.length; i++) {
      final overlap = _overlapDays(own, spans[i]);
      // Prefer overlap; with none, the nearest term (a smaller gap wins).
      final score = overlap > 0 ? overlap : overlap - 1;
      if (score > bestScore) {
        bestScore = score;
        best = i;
      }
    }
    members[best].add(item.key);
  }

  var active = -1;
  for (var i = 0; i < spans.length; i++) {
    if (today.isWithin(spans[i].$1, spans[i].$2) &&
        (active < 0 || clusters[i].length > clusters[active].length)) {
      active = i;
    }
  }
  if (active < 0) {
    for (var i = 0; i < spans.length; i++) {
      if (spans[i].$1.compareTo(today) > 0) {
        active = i;
        break;
      }
    }
  }
  if (active < 0) active = spans.length - 1;

  final choices = <ClassTermChoice>[];
  for (var i = 0; i < clusters.length; i++) {
    final span = _termSpan(clusters[i], today);
    choices.add(
      ClassTermChoice(
        index: i,
        name: '${seasonAround(span.$1).name} ${span.$1.year}',
        startDate: span.$1,
        endDate: span.$2,
        likelyCourseCount: _groupCourses(clusters[i]).length,
        candidateKeys: Set.unmodifiable(members[i]),
      ),
    );
  }
  return (List.unmodifiable(choices), active);
}

// ─────────────────────────────────────────────────────────────────────────────
// Finder
// ─────────────────────────────────────────────────────────────────────────────

abstract final class CalendarClassFinder {
  static CalendarClassImportDraft find(
    String text, {
    String? sourceName,
    String fallbackTimeZoneId = 'America/New_York',
    CivilDate? today,
  }) {
    final calendar = _IcsCalendar.parse(text);
    final zone = _pickZone(calendar, fallbackTimeZoneId);
    final now = today ?? CivilDate.fromDateTime(Clock.now());

    var allDay = 0;
    var oneTime = 0;
    var deadlines = 0;
    var otherRepeating = 0;

    final overridesByUid = <String, List<_IcsComponent>>{};
    final masters = <_IcsComponent>[];
    final singles = <_Timed>[];
    for (final event in calendar.events) {
      final uid = event.text('UID');
      if (event.has('RECURRENCE-ID')) {
        if (uid != null) (overridesByUid[uid] ??= []).add(event);
        continue;
      }
      if (event.value('STATUS')?.toUpperCase() == 'CANCELLED') continue;
      if (uid != null && uid.startsWith('event-assignment')) {
        deadlines++;
        continue;
      }
      final start = event.time('DTSTART', zone);
      if (start == null) continue;
      if (start.minute == null) {
        allDay++;
        continue;
      }
      final end = _endOf(event, start, zone);
      if (end == null || end.minute == null) {
        deadlines++;
        continue;
      }
      final sameDay = end.date == start.date;
      final length = sameDay ? end.minute! - start.minute! : -1;
      if (length <= 0) {
        // Zero-length events are deadlines (Canvas, Brightspace); overnight
        // ones are not classes.
        if (length == 0) {
          deadlines++;
        } else {
          oneTime++;
        }
        continue;
      }
      final rule = event.value('RRULE');
      if (rule == null) {
        singles.add(
          _Timed(
            event: event,
            date: start.date,
            startMinute: start.minute!,
            endMinute: end.minute!,
          ),
        );
        continue;
      }
      final parsed = _Rule.parse(rule, start.date, zone);
      if (parsed == null) {
        otherRepeating++;
        continue;
      }
      masters.add(event);
    }

    final candidates = <ClassCandidate>[];
    final seenKeys = <String, int>{};
    String uniqueKey(String key) {
      final count = seenKeys.update(
        key,
        (value) => value + 1,
        ifAbsent: () => 0,
      );
      return count == 0 ? key : '$key#$count';
    }

    for (final event in masters) {
      final start = event.time('DTSTART', zone)!;
      final end = _endOf(event, start, zone)!;
      final rule = _Rule.parse(event.value('RRULE')!, start.date, zone)!;
      final uid = event.text('UID') ?? '${event.text('SUMMARY')}|$start';
      final skipped = <CivilDate>{
        for (final item in event.times('EXDATE', zone)) item.date,
      };
      final moves = <ClassMove>[];
      for (final override in overridesByUid[uid] ?? const <_IcsComponent>[]) {
        final from = override.time('RECURRENCE-ID', zone);
        if (from == null) continue;
        if (override.value('STATUS')?.toUpperCase() == 'CANCELLED') {
          skipped.add(from.date);
          continue;
        }
        final to = override.time('DTSTART', zone);
        final toEnd = to == null ? null : _endOf(override, to, zone);
        if (to?.minute == null ||
            toEnd?.minute == null ||
            toEnd!.date != to!.date ||
            toEnd.minute! <= to.minute!) {
          continue;
        }
        if (to.date == from.date &&
            to.minute == start.minute &&
            toEnd.minute == end.minute) {
          continue; // Same slot, different detail (a room note): keep as is.
        }
        moves.add(
          ClassMove(
            from: from.date,
            to: to.date,
            startMinute: to.minute!,
            endMinute: toEnd.minute!,
          ),
        );
      }
      final summary = event.text('SUMMARY')?.trim() ?? '';
      final fields = _roomOfDaysFields(event);
      final name = ClassNameReader.read(
        summary.isEmpty ? 'Untitled class' : summary,
        codeHint: event.text('X-ROOM-OF-DAYS-COURSE-CODE'),
        titleHint: event.text('X-ROOM-OF-DAYS-COURSE-TITLE'),
        sectionHint: event.text('X-ROOM-OF-DAYS-SECTION'),
        kindHint: event.text('X-ROOM-OF-DAYS-MEETING-KIND'),
      );
      final location = event.text('LOCATION')?.trim();
      final last = rule.lastDate;
      final score = _score(
        summary: summary,
        name: name,
        location: location,
        weekdays: rule.weekdays,
        startMinute: start.minute!,
        endMinute: end.minute!,
        firstDate: start.date,
        lastDate: last,
        roomOfDays: fields != null,
      );
      candidates.add(
        ClassCandidate(
          key: uniqueKey(uid),
          summary: summary,
          name: name,
          location: location == null || location.isEmpty ? null : location,
          weekdays: rule.weekdays,
          startMinute: start.minute!,
          endMinute: end.minute!,
          intervalWeeks: rule.intervalWeeks,
          firstDate: start.date,
          lastDate: last,
          endWasOpen: last == null,
          skippedDates: skipped,
          moves: moves,
          origin: ClassCandidateOrigin.repeating,
          score: score.$1,
          signals: score.$2,
          roomOfDays: fields,
        ),
      );
    }

    final gathered = _gather(singles);
    oneTime += gathered.leftOver;
    for (final group in gathered.groups) {
      final summary = group.summary;
      final name = ClassNameReader.read(
        summary.isEmpty ? 'Untitled class' : summary,
      );
      final score = _score(
        summary: summary,
        name: name,
        location: group.location,
        weekdays: group.weekdays,
        startMinute: group.startMinute,
        endMinute: group.endMinute,
        firstDate: group.first,
        lastDate: group.last,
        roomOfDays: false,
      );
      candidates.add(
        ClassCandidate(
          key: uniqueKey(
            'gathered|${_normal(summary)}|${group.startMinute}|${group.endMinute}',
          ),
          summary: summary,
          name: name,
          location: group.location,
          weekdays: group.weekdays,
          startMinute: group.startMinute,
          endMinute: group.endMinute,
          intervalWeeks: group.intervalWeeks,
          firstDate: group.first,
          lastDate: group.last,
          endWasOpen: false,
          skippedDates: group.holes,
          moves: const [],
          origin: ClassCandidateOrigin.gathered,
          score: score.$1,
          signals: score.$2,
        ),
      );
    }

    candidates.sort((a, b) {
      final likely = (b.looksLikeClass ? 1 : 0) - (a.looksLikeClass ? 1 : 0);
      if (likely != 0) return likely;
      final day = _firstWeekday(a).compareTo(_firstWeekday(b));
      if (day != 0) return day;
      return a.startMinute.compareTo(b.startMinute);
    });

    // Only the current (or next) term starts checked when an export holds
    // more than one; the others stay one tap away in the review.
    final (choices, active) = _termChoices(candidates, now);
    final activeKeys = choices[active].candidateKeys;
    return CalendarClassImportDraft._(
      sourceName: (sourceName == null || sourceName.trim().isEmpty)
          ? 'calendar.ics'
          : sourceName.trim(),
      calendarName: calendar.text('X-WR-CALNAME'),
      timeZoneId: zone.name,
      candidates: List.unmodifiable(candidates),
      selectedKeys: Set.unmodifiable({
        for (final item in candidates)
          if (item.looksLikeClass && activeKeys.contains(item.key)) item.key,
      }),
      today: now,
      allDayCount: allDay,
      oneTimeCount: oneTime,
      deadlineCount: deadlines,
      otherRepeatingCount: otherRepeating,
      termChoices: choices,
      activeTermIndex: active,
    );
  }
}

int _firstWeekday(ClassCandidate item) =>
    item.weekdays.reduce((a, b) => a < b ? a : b);

// ─────────────────────────────────────────────────────────────────────────────
// Reading course codes and titles out of a SUMMARY
// ─────────────────────────────────────────────────────────────────────────────

/// What a class is called, read from free text.
final class ClassName {
  const ClassName({
    required this.code,
    required this.codeFound,
    required this.title,
    required this.section,
    required this.kind,
  });

  /// A course code from the text ("CS 206", "14:332:345"), or short initials
  /// when the text has none ([codeFound] false). The schedule needs a code;
  /// the review shows initials only as a quiet label.
  final String code;
  final bool codeFound;
  final String title;
  final String? section;
  final MeetingKind kind;
}

abstract final class ClassNameReader {
  static final _rutgersCode = RegExp(
    r'\b(\d{2}:\d{3}:\d{3})(?::([A-Z0-9]{1,3}))?\b',
  );
  static final _letterCode = RegExp(
    r'\b([A-Z]{2,6}(?:\s?&\s?[A-Z]{1,4})?)[\s\-_.]?(\d{2,4}[A-Z]{0,2})\b',
  );
  static final _section = RegExp(
    r'(?:\bsec(?:tion)?\.?\s*|§\s*)([A-Z]?\d{1,3}[A-Z]?)\b',
    caseSensitive: false,
  );
  static final _kindSection = RegExp(
    r'\b(LEC|LAB|REC|DIS|SEM|STU|TUT|LECTURE|RECITATION|DISCUSSION)\s*[-.]?\s*(\d{1,3}[A-Z]?)\b',
    caseSensitive: false,
  );
  static const _notSubjects = {
    'LEC',
    'LAB',
    'REC',
    'DIS',
    'SEM',
    'SEC',
    'STU',
    'TUT',
    'ROOM',
    'RM',
    'AM',
    'PM',
    'FALL',
    'SPRING',
    'SUMMER',
    'WINTER',
    'TERM',
    'WEEK',
    'SECTION',
    'LECTURE',
    'CLASS',
    'UNIT',
    'HW',
    'QUIZ',
    'EXAM',
  };

  /// [summary] is the event title. The hints come from Room of Days fields
  /// and win when present.
  static ClassName read(
    String summary, {
    String? codeHint,
    String? titleHint,
    String? sectionHint,
    String? kindHint,
  }) {
    final kind = _kindFrom(kindHint) ?? _kindIn(summary) ?? MeetingKind.lecture;
    var code = codeHint?.trim();
    String? section = sectionHint?.trim();
    var rest = summary;

    if (code == null || code.isEmpty) {
      code = null;
      final rutgers = _rutgersCode.firstMatch(rest);
      if (rutgers != null) {
        code = rutgers.group(1);
        section ??= rutgers.group(2);
        rest = rest.replaceRange(rutgers.start, rutgers.end, ' ');
      } else {
        for (final match in _letterCode.allMatches(rest)) {
          final subject = match.group(1)!.replaceAll(' ', '');
          if (_notSubjects.contains(subject.toUpperCase())) continue;
          code =
              '${match.group(1)!.replaceAll(RegExp(r'\s+'), ' ')} ${match.group(2)}';
          rest = rest.replaceRange(match.start, match.end, ' ');
          break;
        }
      }
    }

    if (section == null || section.isEmpty) {
      section = null;
      final explicit = _section.firstMatch(rest);
      if (explicit != null) {
        section = explicit.group(1);
        rest = rest.replaceRange(explicit.start, explicit.end, ' ');
      } else {
        final kindSection = _kindSection.firstMatch(rest);
        if (kindSection != null) {
          section = kindSection.group(2);
          rest = rest.replaceRange(kindSection.start, kindSection.end, ' ');
        }
      }
    } else {
      final kindSection = _kindSection.firstMatch(rest);
      if (kindSection != null) {
        rest = rest.replaceRange(kindSection.start, kindSection.end, ' ');
      }
    }

    var title = titleHint?.trim();
    if (title == null || title.isEmpty) {
      title = _cleanTitle(rest);
    }
    final codeFound = code != null && code.isNotEmpty;
    if (title.isEmpty) title = codeFound ? code : summary.trim();
    if (title.isEmpty) title = 'Class';
    return ClassName(
      code: codeFound ? code.toUpperCase() : initialsFor(title),
      codeFound: codeFound,
      title: title,
      section: section,
      kind: kind,
    );
  }

  /// Strips separators and meeting-kind tags that are set off from the title
  /// ("- Lecture", "(Lab)", "Recitation:"). A bare trailing word stays, so
  /// "Computer Architecture Lab" keeps its name.
  static String _cleanTitle(String value) {
    var text = value;
    text = text.replaceAll(
      RegExp(
        r'[\(\[]\s*(lecture|lec|lab|laboratory|recitation|rec|discussion|dis|seminar|studio|tutorial|online|in[- ]person|hybrid)\s*[\)\]]',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'\s[-–—:|,]\s*(lecture|lec|lab|laboratory|recitation|rec|discussion|dis|seminar|studio|tutorial)\s*$',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'^\s*(lecture|lec|lab|recitation|rec|discussion|dis|seminar)\s*[-–—:|]\s*',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    text = text.replaceAll(RegExp(r'^[-–—:|,.\s]+|[-–—:|,\s]+$'), '').trim();
    return text;
  }

  static MeetingKind? _kindFrom(String? value) =>
      switch (value?.trim().toUpperCase()) {
        null || '' => null,
        'LAB' => MeetingKind.lab,
        'RECITATION' || 'REC' => MeetingKind.recitation,
        'STUDIO' || 'STU' => MeetingKind.studio,
        'OFFICE' || 'OFFICE HOURS' => MeetingKind.officeHours,
        _ => MeetingKind.lecture,
      };

  static MeetingKind? _kindIn(String summary) {
    final text = summary.toLowerCase();
    bool has(String pattern) => RegExp(pattern).hasMatch(text);
    if (has(r'\boffice hours?\b')) return MeetingKind.officeHours;
    if (has(r'\b(lab|laboratory)\b')) return MeetingKind.lab;
    if (has(r'\b(recitation|rec|discussion|dis|tutorial|tut|workshop)\b')) {
      return MeetingKind.recitation;
    }
    if (has(r'\b(studio|stu)\b')) return MeetingKind.studio;
    if (has(r'\b(lecture|lec|seminar|sem)\b')) return MeetingKind.lecture;
    return null;
  }

  static const _small = {
    'and',
    'of',
    'the',
    'to',
    'for',
    'in',
    'a',
    'an',
    'with',
    'on',
    'at',
    '&',
  };

  /// "Discrete Structures II" becomes "DS II"; "Electronics Devices" "ED".
  static String initialsFor(String title) {
    final words = title
        .split(RegExp(r'[\s/\-]+'))
        .where((word) => word.isNotEmpty)
        .toList();
    final numeral =
        words.isNotEmpty &&
            RegExp(
              r'^(I{1,3}|IV|V|VI{0,3}|\d{1,3}[A-Z]?)$',
            ).hasMatch(words.last)
        ? words.removeLast()
        : null;
    final letters = [
      for (final word in words)
        if (!_small.contains(word.toLowerCase()) &&
            RegExp(r'[A-Za-z]').hasMatch(word))
          word.replaceAll(RegExp(r'[^A-Za-z]'), '').characters0.toUpperCase(),
    ].take(4).join();
    final base = letters.isEmpty
        ? title.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase()
        : letters;
    final short = base.length > 6 ? base.substring(0, 6) : base;
    final code = numeral == null ? short : '$short $numeral';
    return code.isEmpty ? 'CLASS' : code;
  }
}

extension on String {
  String get characters0 => isEmpty ? '' : this[0];
}

// ─────────────────────────────────────────────────────────────────────────────
// Is it a class? A small, explainable score.
// ─────────────────────────────────────────────────────────────────────────────

/// An event title that says nothing about the event: what a calendar shared
/// as free/busy only writes instead of the real title.
bool _titleHidden(String summary) => RegExp(
  r'^(busy|free|tentative|away|out of office|untitled|no title)?$',
  caseSensitive: false,
).hasMatch(summary.trim());

(int, List<String>) _score({
  required String summary,
  required ClassName name,
  required String? location,
  required Set<int> weekdays,
  required int startMinute,
  required int endMinute,
  required CivilDate firstDate,
  required CivilDate? lastDate,
  required bool roomOfDays,
}) {
  var score = 2; // Weekly at a fixed time.
  final signals = <String>['weekly'];
  void add(int value, String why) {
    score += value;
    signals.add('${value > 0 ? '+' : ''}$value $why');
  }

  if (roomOfDays) add(10, 'room of days fields');
  // A busy-only calendar names nothing, so its times alone never make a
  // class; the review leaves them for the student to check.
  if (_titleHidden(summary)) add(-3, 'no title');
  final text = summary.toLowerCase();
  if (name.codeFound) add(3, 'course code');
  if (RegExp(
    r'\b(lecture|lec|lab|laboratory|recitation|rec|discussion|seminar|studio|tutorial|class|course|section|practicum)\b',
  ).hasMatch(text)) {
    add(2, 'class word');
  }
  if (RegExp(r'\boffice hours?\b').hasMatch(text)) add(1, 'office hours');
  final length = endMinute - startMinute;
  if (length >= 40 && length <= 200) add(1, 'class length');
  if (length > 240) add(-2, 'very long');
  if (length < 30) add(-1, 'very short');
  if (weekdays.every((day) => day <= DateTime.friday)) {
    add(1, 'weekdays');
  } else {
    add(-1, 'weekend');
  }
  if (lastDate != null) {
    final weeks =
        lastDate.dateArithmeticValue
            .difference(firstDate.dateArithmeticValue)
            .inDays ~/
        7;
    if (weeks >= 6 && weeks <= 26) add(1, 'term length');
    if (weeks < 3) add(-2, 'only a few weeks');
    if (weeks > 30) add(-1, 'longer than a term');
  } else {
    add(-1, 'no end date');
  }
  if (startMinute < 7 * 60 || startMinute >= 22 * 60) add(-2, 'off hours');
  if (location != null &&
      RegExp(
        r'\b(hall|room|rm|bldg|building|center|centre|lab|auditorium|campus|library|annex|lecture)\b|\b[A-Z]{2,5}[- ]?\d{2,4}[A-Z]?\b',
        caseSensitive: false,
      ).hasMatch(location)) {
    add(1, 'campus place');
  }
  if (RegExp(
    r'\b(gym|workout|lift|lifting|run|running|yoga|shift|work|job|practice|rehearsal|church|mass|therapy|appointment|dinner|lunch|breakfast|birthday|party|standup|stand-up|sync|1:1|call|club|volunteer|commute|game|match|date|meetup|hangout|bible|choir|band)\b',
  ).hasMatch(text)) {
    add(-3, 'everyday life word');
  }
  if (RegExp(r'\b(lesson|study|tutoring|meeting)\b').hasMatch(text)) {
    add(-2, 'maybe not a class');
  }
  return (score, signals);
}

// ─────────────────────────────────────────────────────────────────────────────
// Gathering one-time events into weekly series
// ─────────────────────────────────────────────────────────────────────────────

final class _Timed {
  const _Timed({
    required this.event,
    required this.date,
    required this.startMinute,
    required this.endMinute,
  });
  final _IcsComponent event;
  final CivilDate date;
  final int startMinute;
  final int endMinute;
}

final class _GatheredGroup {
  _GatheredGroup({
    required this.summary,
    required this.location,
    required this.weekdays,
    required this.startMinute,
    required this.endMinute,
    required this.intervalWeeks,
    required this.first,
    required this.last,
    required this.holes,
  });
  final String summary;
  final String? location;
  final Set<int> weekdays;
  final int startMinute;
  final int endMinute;
  final int intervalWeeks;
  final CivilDate first;
  final CivilDate last;
  final Set<CivilDate> holes;
}

({List<_GatheredGroup> groups, int leftOver}) _gather(List<_Timed> singles) {
  final byPattern = <String, List<_Timed>>{};
  for (final item in singles) {
    final summary = item.event.text('SUMMARY')?.trim() ?? '';
    (byPattern['${_normal(summary)}|${item.startMinute}|${item.endMinute}'] ??=
            [])
        .add(item);
  }
  final groups = <_GatheredGroup>[];
  var leftOver = 0;
  for (final items in byPattern.values) {
    final byWeekday = <int, Set<CivilDate>>{};
    for (final item in items) {
      (byWeekday[item.date.weekday] ??= {}).add(item.date);
    }
    final weekly = {
      for (final entry in byWeekday.entries)
        if (_distinctWeeks(entry.value) >= 3) entry.key: entry.value,
    };
    if (weekly.isEmpty) {
      leftOver += items.length;
      continue;
    }
    leftOver += items
        .where((item) => !weekly.containsKey(item.date.weekday))
        .length;
    final dates = weekly.values.expand((value) => value).toSet();
    final first = dates.reduce(_earlier);
    final last = dates.reduce(_later);
    // Fortnightly when every meeting falls on alternate weeks.
    final anchor = first.startOfWeek(DateTime.monday);
    final offsets = {
      for (final date in dates)
        date
                .startOfWeek(DateTime.monday)
                .dateArithmeticValue
                .difference(anchor.dateArithmeticValue)
                .inDays ~/
            7,
    };
    final interval = offsets.length >= 3 && offsets.every((week) => week.isEven)
        ? 2
        : 1;
    final holes = <CivilDate>{};
    for (var date = first; date.compareTo(last) <= 0; date = date.addDays(1)) {
      if (!weekly.containsKey(date.weekday)) continue;
      final week =
          date
              .startOfWeek(DateTime.monday)
              .dateArithmeticValue
              .difference(anchor.dateArithmeticValue)
              .inDays ~/
          7;
      if (week % interval != 0) continue;
      if (!dates.contains(date)) holes.add(date);
    }
    final sample = items.first;
    final location = items
        .map((item) => item.event.text('LOCATION')?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    groups.add(
      _GatheredGroup(
        summary: sample.event.text('SUMMARY')?.trim() ?? '',
        location: location,
        weekdays: weekly.keys.toSet(),
        startMinute: sample.startMinute,
        endMinute: sample.endMinute,
        intervalWeeks: interval,
        first: first,
        last: last,
        holes: holes,
      ),
    );
  }
  return (groups: groups, leftOver: leftOver);
}

int _distinctWeeks(Set<CivilDate> dates) =>
    {for (final date in dates) date.startOfWeek(DateTime.monday)}.length;

// ─────────────────────────────────────────────────────────────────────────────
// Weekly rules
// ─────────────────────────────────────────────────────────────────────────────

final class _Rule {
  const _Rule({
    required this.weekdays,
    required this.intervalWeeks,
    required this.lastDate,
  });
  final Set<int> weekdays;
  final int intervalWeeks;
  final CivilDate? lastDate;

  /// Weekly rules only (and DAILY limited to weekdays, which some tools
  /// write for MWF classes). Anything else is not a class pattern.
  static _Rule? parse(String raw, CivilDate firstDate, tz.Location zone) {
    final parts = <String, String>{
      for (final piece in raw.split(';'))
        if (piece.contains('='))
          piece.substring(0, piece.indexOf('=')).trim().toUpperCase(): piece
              .substring(piece.indexOf('=') + 1)
              .trim(),
    };
    final freq = parts['FREQ']?.toUpperCase();
    final byDay = parts['BYDAY'];
    if (freq != 'WEEKLY' && !(freq == 'DAILY' && byDay != null)) return null;
    final interval = int.tryParse(parts['INTERVAL'] ?? '1') ?? 1;
    if (interval < 1 || interval > 4) return null;
    if (freq == 'DAILY' && interval != 1) return null;
    final days = <int>{};
    if (byDay == null) {
      days.add(firstDate.weekday);
    } else {
      for (final token in byDay.split(',')) {
        final day = _weekdayFrom(token.trim().toUpperCase());
        if (day == null) return null;
        days.add(day);
      }
    }
    if (days.isEmpty) return null;
    CivilDate? last;
    final until = parts['UNTIL'];
    if (until != null) {
      final parsed = _IcsTime.parse(until, null);
      last = parsed?.inZone(zone, utcAware: true).date;
    } else if (parts['COUNT'] case final count?) {
      final total = int.tryParse(count);
      if (total == null || total < 1) return null;
      var seen = 0;
      final anchor = firstDate.startOfWeek(DateTime.monday);
      for (var date = firstDate; seen < total; date = date.addDays(1)) {
        final week =
            date
                .startOfWeek(DateTime.monday)
                .dateArithmeticValue
                .difference(anchor.dateArithmeticValue)
                .inDays ~/
            7;
        if (days.contains(date.weekday) && week % interval == 0) {
          seen++;
          last = date;
        }
        if (date.year > firstDate.year + 2) break;
      }
    }
    return _Rule(weekdays: days, intervalWeeks: interval, lastDate: last);
  }
}

int? _weekdayFrom(String token) {
  final code = token.replaceAll(RegExp(r'^[+-]?\d+'), '');
  return switch (code) {
    'MO' => DateTime.monday,
    'TU' => DateTime.tuesday,
    'WE' => DateTime.wednesday,
    'TH' => DateTime.thursday,
    'FR' => DateTime.friday,
    'SA' => DateTime.saturday,
    'SU' => DateTime.sunday,
    _ => null,
  };
}

List<CivilDate> _meetingDates(ClassCandidate item, AcademicTerm term) {
  final first = _later(item.firstDate, term.startDate);
  final last = _earlier(item.lastDate ?? term.endDate, term.endDate);
  final moved = {for (final move in item.moves) move.from};
  final anchor = first.startOfWeek(term.weekStartsOn);
  final dates = <CivilDate>[];
  for (var date = first; date.compareTo(last) <= 0; date = date.addDays(1)) {
    final week =
        date
            .startOfWeek(term.weekStartsOn)
            .dateArithmeticValue
            .difference(anchor.dateArithmeticValue)
            .inDays ~/
        7;
    if (!item.weekdays.contains(date.weekday)) continue;
    if (week % item.intervalWeeks != 0) continue;
    if (item.skippedDates.contains(date) || moved.contains(date)) continue;
    dates.add(date);
  }
  return dates;
}

// ─────────────────────────────────────────────────────────────────────────────
// Seasons
// ─────────────────────────────────────────────────────────────────────────────

/// A typical term around [date], used to name a term and to end classes that
/// a calendar left open-ended. The student can change the end in review.
({String name, CivilDate end}) seasonAround(CivilDate date) {
  final m = date.month;
  if (m >= 8) return (name: 'Fall', end: CivilDate(date.year, 12, 20));
  if (m <= 5) {
    return (
      name: m == 1 && date.day < 10 ? 'Winter' : 'Spring',
      end: m == 1 && date.day < 10
          ? CivilDate(date.year, 1, 24)
          : CivilDate(date.year, 5, 15),
    );
  }
  return (name: 'Summer', end: CivilDate(date.year, 8, 15));
}

// ─────────────────────────────────────────────────────────────────────────────
// Time zones
// ─────────────────────────────────────────────────────────────────────────────

bool _zonesReady = false;

tz.Location? zoneNamed(String? raw) {
  if (raw == null) return null;
  if (!_zonesReady) {
    tz_data.initializeTimeZones();
    _zonesReady = true;
  }
  var name = raw.trim().replaceAll('"', '');
  if (name.isEmpty) return null;
  tz.Location? attempt(String value) {
    try {
      return tz.getLocation(value);
    } catch (_) {
      return null;
    }
  }

  final direct = attempt(name);
  if (direct != null) return direct;
  if (name == 'UTC' || name == 'GMT' || name == 'Z') return tz.UTC;
  final windows = _windowsZones[name];
  if (windows != null) return attempt(windows);
  for (final entry in _outlookLabels.entries) {
    if (name.contains(entry.key)) return attempt(entry.value);
  }
  // "/mozilla.org/20050126_1/America/New_York", "/citadel.org/.../Europe/Rome"
  final pieces = name.split('/');
  for (var start = 1; start < pieces.length - 1; start++) {
    final found = attempt(pieces.sublist(start).join('/'));
    if (found != null) return found;
  }
  return null;
}

tz.Location _pickZone(_IcsCalendar calendar, String fallback) {
  final named = zoneNamed(calendar.text('X-WR-TIMEZONE'));
  if (named != null) return named;
  final counts = <String, int>{};
  for (final event in calendar.events) {
    final tzid = event.param('DTSTART', 'TZID');
    final zone = zoneNamed(tzid);
    if (zone != null) counts[zone.name] = (counts[zone.name] ?? 0) + 1;
  }
  if (counts.isNotEmpty) {
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return zoneNamed(best.key)!;
  }
  return zoneNamed(fallback) ?? zoneNamed('America/New_York')!;
}

const _windowsZones = <String, String>{
  'Eastern Standard Time': 'America/New_York',
  'US Eastern Standard Time': 'America/Indiana/Indianapolis',
  'Central Standard Time': 'America/Chicago',
  'Central Standard Time (Mexico)': 'America/Mexico_City',
  'Mountain Standard Time': 'America/Denver',
  'US Mountain Standard Time': 'America/Phoenix',
  'Pacific Standard Time': 'America/Los_Angeles',
  'Alaskan Standard Time': 'America/Anchorage',
  'Hawaiian Standard Time': 'Pacific/Honolulu',
  'Atlantic Standard Time': 'America/Halifax',
  'Newfoundland Standard Time': 'America/St_Johns',
  'SA Pacific Standard Time': 'America/Bogota',
  'E. South America Standard Time': 'America/Sao_Paulo',
  'GMT Standard Time': 'Europe/London',
  'Greenwich Standard Time': 'Atlantic/Reykjavik',
  'W. Europe Standard Time': 'Europe/Berlin',
  'Romance Standard Time': 'Europe/Paris',
  'Central Europe Standard Time': 'Europe/Budapest',
  'Central European Standard Time': 'Europe/Warsaw',
  'GTB Standard Time': 'Europe/Bucharest',
  'FLE Standard Time': 'Europe/Helsinki',
  'Russian Standard Time': 'Europe/Moscow',
  'Israel Standard Time': 'Asia/Jerusalem',
  'Arabian Standard Time': 'Asia/Dubai',
  'India Standard Time': 'Asia/Kolkata',
  'China Standard Time': 'Asia/Shanghai',
  'Singapore Standard Time': 'Asia/Singapore',
  'Tokyo Standard Time': 'Asia/Tokyo',
  'Korea Standard Time': 'Asia/Seoul',
  'AUS Eastern Standard Time': 'Australia/Sydney',
  'E. Australia Standard Time': 'Australia/Brisbane',
  'W. Australia Standard Time': 'Australia/Perth',
  'New Zealand Standard Time': 'Pacific/Auckland',
  'South Africa Standard Time': 'Africa/Johannesburg',
  'UTC': 'UTC',
  'Coordinated Universal Time': 'UTC',
};

const _outlookLabels = <String, String>{
  'Eastern Time (US & Canada)': 'America/New_York',
  'Central Time (US & Canada)': 'America/Chicago',
  'Mountain Time (US & Canada)': 'America/Denver',
  'Pacific Time (US & Canada)': 'America/Los_Angeles',
  'Arizona': 'America/Phoenix',
};

// ─────────────────────────────────────────────────────────────────────────────
// A small RFC 5545 reader (components, folding, parameters, times)
// ─────────────────────────────────────────────────────────────────────────────

final class _Property {
  const _Property(this.params, this.value);
  final Map<String, String> params;
  final String value;
}

final class _IcsComponent {
  _IcsComponent(this.name);
  final String name;
  final Map<String, List<_Property>> properties = {};

  bool has(String key) => properties.containsKey(key);
  String? value(String key) => properties[key]?.last.value;
  String? param(String key, String param) =>
      properties[key]?.last.params[param];
  String? text(String key) {
    final raw = value(key);
    return raw == null ? null : _unescape(raw);
  }

  _IcsTime? rawTime(String key) {
    final property = properties[key]?.last;
    if (property == null) return null;
    return _IcsTime.parse(
      property.value,
      property.params['TZID'],
      dateOnly: property.params['VALUE']?.toUpperCase() == 'DATE',
    );
  }

  _LocalTime? time(String key, tz.Location zone) => rawTime(key)?.inZone(zone);

  List<_LocalTime> times(String key, tz.Location zone) => [
    for (final property in properties[key] ?? const <_Property>[])
      for (final item in property.value.split(','))
        if (_IcsTime.parse(
              item.trim(),
              property.params['TZID'],
              dateOnly: property.params['VALUE']?.toUpperCase() == 'DATE',
            )
            case final parsed?)
          parsed.inZone(zone),
  ];
}

final class _IcsCalendar {
  _IcsCalendar(this.events, this._properties);
  final List<_IcsComponent> events;
  final Map<String, List<_Property>> _properties;

  String? text(String key) {
    final raw = _properties[key]?.last.value;
    return raw == null ? null : _unescape(raw).trim();
  }

  static _IcsCalendar parse(String input) {
    var text = input;
    if (text.startsWith('﻿')) text = text.substring(1);
    if (!text.contains('BEGIN:VCALENDAR') && !text.contains('BEGIN:VEVENT')) {
      throw const FormatException('Not an iCalendar file');
    }
    final lines = <String>[];
    for (final line
        in text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
      if ((line.startsWith(' ') || line.startsWith('\t')) && lines.isNotEmpty) {
        lines[lines.length - 1] += line.substring(1);
      } else {
        lines.add(line);
      }
    }
    final events = <_IcsComponent>[];
    final calendarProps = <String, List<_Property>>{};
    final stack = <_IcsComponent>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final colon = _valueColon(line);
      if (colon < 1) continue;
      final head = line.substring(0, colon);
      final value = line.substring(colon + 1);
      final fields = _splitParams(head);
      final key = fields.first.trim().toUpperCase();
      if (key == 'BEGIN') {
        stack.add(_IcsComponent(value.trim().toUpperCase()));
        continue;
      }
      if (key == 'END') {
        if (stack.isEmpty) continue;
        final done = stack.removeLast();
        if (done.name == 'VEVENT' &&
            (stack.isEmpty || stack.last.name == 'VCALENDAR')) {
          events.add(done);
        }
        continue;
      }
      final params = <String, String>{};
      for (final item in fields.skip(1)) {
        final split = item.indexOf('=');
        if (split > 0) {
          params[item.substring(0, split).trim().toUpperCase()] = item
              .substring(split + 1)
              .replaceAll('"', '')
              .trim();
        }
      }
      final property = _Property(params, value);
      if (stack.isEmpty) continue;
      final top = stack.last;
      if (top.name == 'VCALENDAR') {
        (calendarProps[key] ??= []).add(property);
      } else {
        (top.properties[key] ??= []).add(property);
      }
    }
    return _IcsCalendar(events, calendarProps);
  }
}

/// The first colon outside a quoted parameter value.
int _valueColon(String line) {
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') quoted = !quoted;
    if (char == ':' && !quoted) return i;
  }
  return -1;
}

List<String> _splitParams(String head) {
  final out = <String>[];
  final buffer = StringBuffer();
  var quoted = false;
  for (var i = 0; i < head.length; i++) {
    final char = head[i];
    if (char == '"') quoted = !quoted;
    if (char == ';' && !quoted) {
      out.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  out.add(buffer.toString());
  return out;
}

String _unescape(String value) => value
    .replaceAll(r'\\', '\u0000')
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\N', '\n')
    .replaceAll(r'\,', ',')
    .replaceAll(r'\;', ';')
    .replaceAll('\u0000', r'\');

final class _LocalTime {
  const _LocalTime(this.date, this.minute);
  final CivilDate date;

  /// Null for an all-day value.
  final int? minute;

  @override
  String toString() => '$date ${minute ?? 'all-day'}';
}

final class _IcsTime {
  const _IcsTime({
    required this.date,
    required this.minute,
    required this.utc,
    required this.tzid,
  });
  final CivilDate date;
  final int? minute;
  final bool utc;
  final String? tzid;

  static _IcsTime? parse(String raw, String? tzid, {bool dateOnly = false}) {
    final value = raw.trim().replaceAll('-', '').replaceAll(':', '');
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$',
    ).firstMatch(value);
    if (match == null) return null;
    final CivilDate date;
    try {
      date = CivilDate(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    } on ArgumentError {
      return null;
    }
    if (dateOnly || match.group(4) == null) {
      return _IcsTime(date: date, minute: null, utc: false, tzid: null);
    }
    return _IcsTime(
      date: date,
      minute: int.parse(match.group(4)!) * 60 + int.parse(match.group(5)!),
      utc: match.group(7) == 'Z',
      tzid: tzid,
    );
  }

  /// This time as a wall-clock time in [zone]. Floating times are already
  /// wall-clock times. With [utcAware] (UNTIL), a UTC instant converts.
  _LocalTime inZone(tz.Location zone, {bool utcAware = true}) {
    if (minute == null) return _LocalTime(date, null);
    tz.TZDateTime? instant;
    if (utc && utcAware) {
      instant = tz.TZDateTime.from(
        DateTime.utc(
          date.year,
          date.month,
          date.day,
          minute! ~/ 60,
          minute! % 60,
        ),
        zone,
      );
    } else if (tzid != null) {
      final from = zoneNamed(tzid);
      if (from != null && from.name != zone.name) {
        final source = tz.TZDateTime(
          from,
          date.year,
          date.month,
          date.day,
          minute! ~/ 60,
          minute! % 60,
        );
        instant = tz.TZDateTime.from(source.toUtc(), zone);
      }
    }
    if (instant == null) return _LocalTime(date, minute);
    return _LocalTime(
      CivilDate(instant.year, instant.month, instant.day),
      instant.hour * 60 + instant.minute,
    );
  }

  @override
  String toString() => '$date ${minute ?? 'all-day'}${utc ? 'Z' : ''}';
}

_LocalTime? _endOf(_IcsComponent event, _LocalTime start, tz.Location zone) {
  final end = event.time('DTEND', zone);
  if (end != null) return end;
  final duration = event.value('DURATION');
  if (duration != null && start.minute != null) {
    final match = RegExp(
      r'^P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:\d+S)?)?$',
    ).firstMatch(duration.trim().toUpperCase());
    if (match == null) return null;
    final minutes =
        (int.tryParse(match.group(1) ?? '') ?? 0) * 7 * 1440 +
        (int.tryParse(match.group(2) ?? '') ?? 0) * 1440 +
        (int.tryParse(match.group(3) ?? '') ?? 0) * 60 +
        (int.tryParse(match.group(4) ?? '') ?? 0);
    final total = start.minute! + minutes;
    return _LocalTime(start.date.addDays(total ~/ 1440), total % 1440);
  }
  // RFC 5545: a DATE-TIME start with no end is a zero-length moment.
  return start.minute == null ? null : _LocalTime(start.date, start.minute);
}

RoomOfDaysFields? _roomOfDaysFields(_IcsComponent event) {
  final keys = event.properties.keys.where(
    (key) => key.startsWith('X-ROOM-OF-DAYS-'),
  );
  if (keys.isEmpty) return null;
  CivilDate? date(String key) {
    final raw = event.value(key)?.replaceAll('-', '');
    if (raw == null) return null;
    final match = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(raw.trim());
    if (match == null) return null;
    return CivilDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  return RoomOfDaysFields(
    termName: event.text('X-ROOM-OF-DAYS-TERM'),
    termStart: date('X-ROOM-OF-DAYS-TERM-START'),
    termEnd: date('X-ROOM-OF-DAYS-TERM-END'),
    campus: event.text('X-ROOM-OF-DAYS-CAMPUS'),
    building: event.text('X-ROOM-OF-DAYS-BUILDING'),
    room: event.text('X-ROOM-OF-DAYS-ROOM'),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Grouping and helpers
// ─────────────────────────────────────────────────────────────────────────────

List<ClassReviewCourse> _groupCourses(List<ClassCandidate> items) {
  final groups = <String, List<ClassCandidate>>{};
  for (final item in items) {
    final key = item.name.codeFound
        ? 'code|${_normal(item.name.code)}'
        : 'title|${_normal(item.name.title)}';
    (groups[key] ??= []).add(item);
  }
  final courses = [
    for (final entry in groups.entries)
      ClassReviewCourse(
        key: entry.key,
        code: entry.value.first.name.code,
        codeFound: entry.value.first.name.codeFound,
        title: _mostCommon([for (final item in entry.value) item.name.title]),
        section: {for (final item in entry.value) item.name.section}.length == 1
            ? entry.value.first.name.section
            : null,
        candidates: List.unmodifiable(entry.value),
      ),
  ];
  courses.sort((a, b) {
    final likely = (b.looksLikeClass ? 1 : 0) - (a.looksLikeClass ? 1 : 0);
    if (likely != 0) return likely;
    final day = _firstWeekday(
      a.candidates.first,
    ).compareTo(_firstWeekday(b.candidates.first));
    if (day != 0) return day;
    return a.candidates.first.startMinute.compareTo(
      b.candidates.first.startMinute,
    );
  });
  return courses;
}

String _mostCommon(List<String> values) {
  final counts = <String, int>{};
  for (final value in values) {
    counts[value] = (counts[value] ?? 0) + 1;
  }
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

String _normal(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

CivilDate _earlier(CivilDate a, CivilDate b) => a.compareTo(b) <= 0 ? a : b;
CivilDate _later(CivilDate a, CivilDate b) => a.compareTo(b) >= 0 ? a : b;

/// FNV-1a, the same scheme the Room of Days importer uses for stable IDs.
String _stableId(String kind, String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return '${kind}_${hash.toRadixString(16).padLeft(8, '0')}';
}

const _courseColors = <(int, String)>[
  (0xFF8AAFC6, 'Dusk blue'),
  (0xFF9CBC88, 'Moss'),
  (0xFFDD9A72, 'Terracotta'),
  (0xFFAE9AC4, 'Lilac'),
  (0xFF93A7E0, 'Periwinkle'),
  (0xFFC79355, 'Aged bronze'),
];
