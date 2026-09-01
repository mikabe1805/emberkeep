/// A deliberately small, predictable importer for Room of Days academic .ics
/// files. This is not a general-purpose iCalendar implementation.
library;

import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';

const _rutgersTimeZone = 'America/New_York';

/// A small, editable starting point for a Room of Days class import.
///
/// Keep the commas in `BYDAY` when a class meets on more than one day. The
/// template deliberately uses CRLF line endings: that is the iCalendar line
/// ending required by RFC 5545, whether it is shared as a file or pasted into
/// another calendar tool.
const roomOfDaysAcademicScheduleTemplate =
    'BEGIN:VCALENDAR\r\n'
    'VERSION:2.0\r\n'
    'PRODID:-//Room of Days//Academic Schedule Template//EN\r\n'
    'CALSCALE:GREGORIAN\r\n'
    'BEGIN:VEVENT\r\n'
    'UID:replace-with-a-stable-class-meeting-id@roomofdays\r\n'
    'DTSTAMP:20260901T000000Z\r\n'
    'DTSTART;TZID=America/New_York:20260908T083000\r\n'
    'DTEND;TZID=America/New_York:20260908T092000\r\n'
    'RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR;UNTIL=20261214T235900\r\n'
    'SUMMARY:ECE 345 — Replace with your class title\r\n'
    'LOCATION:Engineering Building 101\r\n'
    'X-ROOM-OF-DAYS-NOTE:Replace the example values before importing.\r\n'
    'X-ROOM-OF-DAYS-NOTE:Keep commas in BYDAY for classes meeting multiple days.\r\n'
    'X-ROOM-OF-DAYS-TERM:Fall 2026\r\n'
    'X-ROOM-OF-DAYS-TERM-START:20260901\r\n'
    'X-ROOM-OF-DAYS-TERM-END:20261223\r\n'
    'X-ROOM-OF-DAYS-COURSE-CODE:ECE 345\r\n'
    'X-ROOM-OF-DAYS-COURSE-TITLE:Replace with your class title\r\n'
    'X-ROOM-OF-DAYS-SECTION:01\r\n'
    'X-ROOM-OF-DAYS-MEETING-KIND:LECTURE\r\n'
    'X-ROOM-OF-DAYS-CAMPUS:BUSCH\r\n'
    'X-ROOM-OF-DAYS-BUILDING:Engineering Building\r\n'
    'X-ROOM-OF-DAYS-ROOM:101\r\n'
    'END:VEVENT\r\n'
    'END:VCALENDAR\r\n';

/// Produces the shareable UTF-8 contents for the editable class-file starter.
String buildRoomOfDaysAcademicScheduleTemplate() =>
    roomOfDaysAcademicScheduleTemplate;

/// What an accepted import should do with its recurring class reminders.
///
/// The review intentionally starts [unchanged]. This means a first import has
/// no reminders, while a later re-import cannot silently erase a class
/// reminder the owner already chose.
enum AcademicScheduleImportReminderChoice { unchanged, off, on }

/// The review-level information a UI needs before committing an import.
final class AcademicScheduleImportCourse {
  const AcademicScheduleImportCourse({
    required this.code,
    required this.title,
    this.section,
    required this.meetingSeriesCount,
  });

  final String code;
  final String title;
  final String? section;
  final int meetingSeriesCount;
}

/// A parsed, non-mutating academic-calendar import.  Call [applyTo] only after
/// the review step has been accepted.
final class AcademicScheduleImportDraft {
  AcademicScheduleImportDraft._({
    required this.term,
    required this.courses,
    required this.meetingSeriesCount,
    required this.projectedOccurrenceCount,
    required this.warnings,
    required List<_IcsMaster> masters,
    required Map<String, List<_IcsOverride>> overridesByUid,
    this.reminderChoice = AcademicScheduleImportReminderChoice.unchanged,
    this.reminderOffsetMinutes = 10,
  }) : _masters = List.unmodifiable(masters),
       _overridesByUid = overridesByUid.map(
         (key, value) => MapEntry(key, List.unmodifiable(value)),
       );

  final AcademicTerm term;
  final List<AcademicScheduleImportCourse> courses;
  final int meetingSeriesCount;
  final int projectedOccurrenceCount;
  final List<String> warnings;
  final AcademicScheduleImportReminderChoice reminderChoice;
  final int reminderOffsetMinutes;
  final List<_IcsMaster> _masters;
  final Map<String, List<_IcsOverride>> _overridesByUid;

  /// Returns another still-uncommitted review draft. It never changes the
  /// schedule by itself.
  AcademicScheduleImportDraft withReminderChoice(
    AcademicScheduleImportReminderChoice choice, {
    int offsetMinutes = 10,
  }) {
    if (offsetMinutes != 10 && offsetMinutes != 15 && offsetMinutes != 30) {
      throw ArgumentError.value(offsetMinutes, 'offsetMinutes');
    }
    return AcademicScheduleImportDraft._(
      term: term,
      courses: courses,
      meetingSeriesCount: meetingSeriesCount,
      projectedOccurrenceCount: projectedOccurrenceCount,
      warnings: warnings,
      masters: _masters,
      overridesByUid: _overridesByUid,
      reminderChoice: choice,
      reminderOffsetMinutes: offsetMinutes,
    );
  }

  /// Adds the deterministic records in this import and refreshes their recurring
  /// meeting details. Existing user-adjusted occurrences and other schedule
  /// material remain untouched.
  AcademicSchedule applyTo(
    AcademicSchedule existing, {
    required DateTime updatedAt,
  }) {
    var next = existing;
    final importTerm = existing.terms
        .where((item) => item.termId == term.termId)
        .firstOrNull;
    final resolvedTerm = importTerm ?? term;

    for (final master in _masters) {
      final courseId = _stableId(
        'course',
        '${term.termId}|${master.courseCode}|${master.courseTitle}|${master.section ?? ''}',
      );
      final priorCourse = next.courseById(courseId);
      final course = AcademicCourse(
        courseId: courseId,
        termId: term.termId,
        code: master.courseCode,
        title: master.courseTitle,
        section: master.section,
        colorValue: _courseColors[_colorIndex(courseId)].$1,
        colorLabel: _courseColors[_colorIndex(courseId)].$2,
        meetingSeriesIds: priorCourse?.meetingSeriesIds ?? const [],
      );
      final series = MeetingSeries(
        meetingSeriesId: _stableId('meeting', master.uid),
        courseId: courseId,
        kind: master.kind,
        weekdays: master.weekdays,
        localStartMinute: master.start.minuteOfDay,
        localEndMinute: master.end.minuteOfDay,
        firstDate: master.start.date,
        lastDate: master.until,
        timeZoneId: _rutgersTimeZone,
        place: CampusPlace(
          label: master.location,
          building: master.building,
          room: master.room,
          campusCode: master.campus,
        ),
        reminders: _remindersFor(
          prior: next.meetingSeriesById(_stableId('meeting', master.uid)),
          meetingSeriesId: _stableId('meeting', master.uid),
        ),
        updatedAt: updatedAt.toUtc(),
      );
      next = next.putMeeting(
        term: resolvedTerm,
        course: course,
        series: series,
        updatedAt: updatedAt,
      );

      final overrides = _overridesByUid[master.uid] ?? const [];
      final movedDates = <CivilDate>{
        for (final override in overrides)
          if (!override.cancelled) override.recurrence.date,
      };
      for (final override in overrides.where((item) => !item.cancelled)) {
        final original = next.occurrences
            .where(
              (item) =>
                  item.meetingSeriesId == series.meetingSeriesId &&
                  item.originalDate == override.recurrence.date,
            )
            .firstOrNull;
        if (original == null || original.userAdjusted) continue;
        next = next.moveOccurrence(
          occurrenceKey: original.occurrenceKey,
          date: override.start!.date,
          startMinute: override.start!.minuteOfDay,
          endMinute: override.end!.minuteOfDay,
          updatedAt: updatedAt,
        );
      }
      for (final date in {
        ...master.exdates,
        ...overrides
            .where((item) => item.cancelled)
            .map((item) => item.recurrence.date),
      }) {
        if (movedDates.contains(date)) continue;
        final original = next.occurrences
            .where(
              (item) =>
                  item.meetingSeriesId == series.meetingSeriesId &&
                  item.originalDate == date,
            )
            .firstOrNull;
        if (original != null && !original.userAdjusted) {
          next = next.cancelOccurrence(
            occurrenceKey: original.occurrenceKey,
            updatedAt: updatedAt,
          );
        }
      }
    }
    return next;
  }

  List<AcademicReminder> _remindersFor({
    required MeetingSeries? prior,
    required String meetingSeriesId,
  }) {
    return switch (reminderChoice) {
      AcademicScheduleImportReminderChoice.unchanged =>
        prior?.reminders ?? const <AcademicReminder>[],
      AcademicScheduleImportReminderChoice.off => const <AcademicReminder>[],
      AcademicScheduleImportReminderChoice.on => [
        AcademicReminder(
          reminderId: _stableId(
            'reminder',
            '$meetingSeriesId|$reminderOffsetMinutes',
          ),
          enabled: true,
          offsetMinutes: reminderOffsetMinutes,
        ),
      ],
    };
  }
}

abstract final class AcademicScheduleIcsImporter {
  static AcademicScheduleImportDraft parse(String text, {String? sourceName}) {
    final events = _readEvents(text);
    if (events.isEmpty) throw const FormatException('No VEVENT records found');
    final masters = <_IcsMaster>[];
    final overrides = <String, List<_IcsOverride>>{};
    final warnings = <String>[];
    for (final event in events) {
      final recurrence = event.dateTime('RECURRENCE-ID');
      if (recurrence != null) {
        final uid = event.value('UID');
        if (uid == null) {
          warnings.add('Ignored an override without a UID.');
          continue;
        }
        final status = event.value('STATUS')?.toUpperCase();
        final start = event.dateTime('DTSTART');
        final end = event.dateTime('DTEND');
        if (status != 'CANCELLED' && (start == null || end == null)) {
          throw const FormatException(
            'A moved occurrence needs DTSTART and DTEND',
          );
        }
        (overrides[uid] ??= []).add(
          _IcsOverride(
            recurrence: recurrence,
            start: start,
            end: end,
            cancelled: status == 'CANCELLED',
          ),
        );
        continue;
      }
      try {
        masters.add(_IcsMaster.fromEvent(event, sourceName: sourceName));
      } on _IgnorableEvent catch (error) {
        warnings.add(error.message);
      }
    }
    if (masters.isEmpty) {
      throw const FormatException('No supported weekly class meetings found');
    }
    final first = masters.first;
    if (masters.any(
      (item) =>
          item.termName != first.termName ||
          item.termStart != first.termStart ||
          item.termEnd != first.termEnd,
    )) {
      throw const FormatException('The import must contain one academic term');
    }
    final term = AcademicTerm(
      termId: _stableId(
        'term',
        '${first.termName}|${first.termStart}|${first.termEnd}',
      ),
      name: first.termName,
      startDate: first.termStart,
      endDate: first.termEnd,
      timeZoneId: _rutgersTimeZone,
    );
    final grouped = <String, List<_IcsMaster>>{};
    for (final master in masters) {
      (grouped['${master.courseCode}|${master.courseTitle}|${master.section ?? ''}'] ??=
              [])
          .add(master);
    }
    final courses =
        grouped.values
            .map(
              (items) => AcademicScheduleImportCourse(
                code: items.first.courseCode,
                title: items.first.courseTitle,
                section: items.first.section,
                meetingSeriesCount: items.length,
              ),
            )
            .toList()
          ..sort((a, b) => a.code.compareTo(b.code));
    final projected = masters.fold<int>(0, (sum, master) {
      final override = overrides[master.uid] ?? const [];
      final movedDates = override
          .where((item) => !item.cancelled)
          .map((item) => item.recurrence.date);
      final excluded = {
        ...master.exdates,
        ...override
            .where((item) => item.cancelled)
            .map((item) => item.recurrence.date),
        ...movedDates,
      };
      final moved = override.where((item) => !item.cancelled).length;
      return sum +
          _weeklyDates(
            master,
          ).where((date) => !excluded.contains(date)).length +
          moved;
    });
    return AcademicScheduleImportDraft._(
      term: term,
      courses: List.unmodifiable(courses),
      meetingSeriesCount: masters.length,
      projectedOccurrenceCount: projected,
      warnings: List.unmodifiable(warnings),
      masters: masters,
      overridesByUid: overrides,
    );
  }
}

final class _IcsMaster {
  _IcsMaster({
    required this.uid,
    required this.start,
    required this.end,
    required this.weekdays,
    required this.until,
    required this.exdates,
    required this.termName,
    required this.termStart,
    required this.termEnd,
    required this.courseCode,
    required this.courseTitle,
    required this.section,
    required this.kind,
    required this.location,
    required this.campus,
    required this.building,
    required this.room,
  });
  factory _IcsMaster.fromEvent(_Event event, {String? sourceName}) {
    final uid = event.value('UID');
    final start = event.dateTime('DTSTART');
    final end = event.dateTime('DTEND');
    if (uid == null || start == null || end == null) {
      throw const FormatException(
        'A class VEVENT needs UID, DTSTART, and DTEND',
      );
    }
    if (end.date != start.date || end.minuteOfDay <= start.minuteOfDay) {
      throw const FormatException(
        'All-day or overnight VEVENTs are not supported',
      );
    }
    final rule = _parts(event.value('RRULE'), 'RRULE');
    if (rule['FREQ'] != 'WEEKLY' ||
        rule['BYDAY'] == null ||
        rule['UNTIL'] == null) {
      throw _IgnorableEvent('Ignored a non-weekly calendar event.');
    }
    final weekdays = rule['BYDAY']!.split(',').map(_weekday).toSet();
    final until = _parseDate(rule['UNTIL']!).date;
    final termName =
        event.text('X-ROOM-OF-DAYS-TERM') ??
        event.text('TERM') ??
        sourceName ??
        'Imported term';
    final termStart = _parseCivilDate(
      event.value('X-ROOM-OF-DAYS-TERM-START') ??
          event.value('TERM-START') ??
          '',
    );
    final termEnd = _parseCivilDate(
      event.value('X-ROOM-OF-DAYS-TERM-END') ?? event.value('TERM-END') ?? '',
    );
    final code =
        event.text('X-ROOM-OF-DAYS-COURSE-CODE') ?? event.text('COURSE-CODE');
    final title =
        event.text('X-ROOM-OF-DAYS-COURSE-TITLE') ?? event.text('COURSE-TITLE');
    if (code == null || title == null) {
      throw const FormatException(
        'A class VEVENT needs COURSE-CODE and COURSE-TITLE',
      );
    }
    return _IcsMaster(
      uid: uid,
      start: start,
      end: end,
      weekdays: weekdays,
      until: until,
      exdates: event.dateTimes('EXDATE').map((item) => item.date).toSet(),
      termName: termName,
      termStart: termStart,
      termEnd: termEnd,
      courseCode: code,
      courseTitle: title,
      section: event.text('X-ROOM-OF-DAYS-SECTION') ?? event.text('SECTION'),
      kind: _kind(
        event.text('X-ROOM-OF-DAYS-MEETING-KIND') ?? event.text('MEETING-KIND'),
      ),
      location: event.text('LOCATION') ?? 'Location not set',
      campus: event.text('X-ROOM-OF-DAYS-CAMPUS') ?? event.text('CAMPUS'),
      building: event.text('X-ROOM-OF-DAYS-BUILDING') ?? event.text('BUILDING'),
      room: event.text('X-ROOM-OF-DAYS-ROOM') ?? event.text('ROOM'),
    );
  }
  final String uid;
  final _LocalTime start;
  final _LocalTime end;
  final Set<int> weekdays;
  final CivilDate until;
  final Set<CivilDate> exdates;
  final String termName;
  final CivilDate termStart;
  final CivilDate termEnd;
  final String courseCode;
  final String courseTitle;
  final String? section;
  final MeetingKind kind;
  final String location;
  final String? campus;
  final String? building;
  final String? room;
}

final class _IcsOverride {
  const _IcsOverride({
    required this.recurrence,
    this.start,
    this.end,
    required this.cancelled,
  });
  final _LocalTime recurrence;
  final _LocalTime? start;
  final _LocalTime? end;
  final bool cancelled;
}

final class _LocalTime {
  const _LocalTime(this.date, this.minuteOfDay);
  final CivilDate date;
  final int minuteOfDay;
}

final class _IgnorableEvent implements Exception {
  const _IgnorableEvent(this.message);
  final String message;
}

final class _Event {
  _Event(this._properties);
  final Map<String, List<_Property>> _properties;
  String? value(String key) => _properties[key]?.last.value;
  String? text(String key) {
    final raw = value(key);
    return raw == null ? null : _unescape(raw);
  }

  _LocalTime? dateTime(String key) {
    final value = _properties[key]?.last;
    return value == null
        ? null
        : _parseDate(value.value, tzid: value.params['TZID']);
  }

  List<_LocalTime> dateTimes(String key) => [
    for (final property in _properties[key] ?? const [])
      for (final item in property.value.split(','))
        _parseDate(item, tzid: property.params['TZID']),
  ];
}

final class _Property {
  const _Property(this.params, this.value);
  final Map<String, String> params;
  final String value;
}

List<_Event> _readEvents(String text) {
  final unfolded = <String>[];
  for (final line
      in text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
    if ((line.startsWith(' ') || line.startsWith('\t')) &&
        unfolded.isNotEmpty) {
      unfolded[unfolded.length - 1] += line.substring(1);
    } else {
      unfolded.add(line);
    }
  }
  final events = <_Event>[];
  Map<String, List<_Property>>? active;
  for (final line in unfolded) {
    if (line == 'BEGIN:VEVENT') {
      active = {};
      continue;
    }
    if (line == 'END:VEVENT') {
      if (active != null) events.add(_Event(active));
      active = null;
      continue;
    }
    if (active == null || line.isEmpty) continue;
    final colon = line.indexOf(':');
    if (colon < 1) continue;
    final fields = line.substring(0, colon).split(';');
    final key = fields.first.toUpperCase();
    final params = <String, String>{};
    for (final item in fields.skip(1)) {
      final split = item.indexOf('=');
      if (split > 0) {
        params[item.substring(0, split).toUpperCase()] = item.substring(
          split + 1,
        );
      }
    }
    (active[key] ??= []).add(_Property(params, line.substring(colon + 1)));
  }
  return events;
}

_LocalTime _parseDate(String value, {String? tzid}) {
  value = value.replaceAll('-', '');
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(?:\d{2})?(Z)?)?$',
  ).firstMatch(value);
  if (match == null || match.group(4) == null) {
    throw const FormatException('All-day or malformed dates are not supported');
  }
  if (tzid != null && tzid != _rutgersTimeZone) {
    throw const FormatException(
      'Only America/New_York calendar times are supported',
    );
  }
  final date = CivilDate(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
  final minutes = int.parse(match.group(4)!) * 60 + int.parse(match.group(5)!);
  if (match.group(6) == 'Z') {
    final local = OccurrenceMaterializer.localTime(
      DateTime.utc(
        date.year,
        date.month,
        date.day,
        minutes ~/ 60,
        minutes % 60,
      ),
      _rutgersTimeZone,
    );
    return _LocalTime(
      CivilDate.fromDateTime(local),
      local.hour * 60 + local.minute,
    );
  }
  return _LocalTime(date, minutes);
}

CivilDate _parseCivilDate(String value) {
  final compact = value.replaceAll('-', '');
  final match = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(compact);
  if (match == null) {
    throw const FormatException('Malformed academic term date');
  }
  return CivilDate(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

Map<String, String> _parts(String? value, String label) {
  if (value == null) throw FormatException('Missing $label');
  return {
    for (final piece in value.split(';'))
      if (piece.contains('='))
        piece.substring(0, piece.indexOf('=')).toUpperCase(): piece
            .substring(piece.indexOf('=') + 1)
            .toUpperCase(),
  };
}

int _weekday(String value) => switch (value) {
  'MO' => DateTime.monday,
  'TU' => DateTime.tuesday,
  'WE' => DateTime.wednesday,
  'TH' => DateTime.thursday,
  'FR' => DateTime.friday,
  'SA' => DateTime.saturday,
  'SU' => DateTime.sunday,
  _ => throw const FormatException('Unsupported BYDAY value'),
};
MeetingKind _kind(String? value) => switch (value?.toUpperCase()) {
  'LAB' => MeetingKind.lab,
  'RECITATION' || 'REC' => MeetingKind.recitation,
  'STUDIO' || 'STU' => MeetingKind.studio,
  'OFFICE' || 'OFFICE HOURS' => MeetingKind.officeHours,
  _ => MeetingKind.lecture,
};
String _unescape(String value) => value
    .replaceAll(r'\\', '\\')
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\N', '\n')
    .replaceAll(r'\,', ',')
    .replaceAll(r'\;', ';');
List<CivilDate> _weeklyDates(_IcsMaster master) {
  final dates = <CivilDate>[];
  for (
    var date = master.start.date;
    date.compareTo(master.until) <= 0;
    date = date.addDays(1)
  ) {
    if (master.weekdays.contains(date.weekday)) dates.add(date);
  }
  return dates;
}

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
int _colorIndex(String value) {
  var total = 0;
  for (final unit in value.codeUnits) {
    total = (total * 31 + unit) & 0x7fffffff;
  }
  return total % _courseColors.length;
}
