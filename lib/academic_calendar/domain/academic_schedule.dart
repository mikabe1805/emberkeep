import 'dart:convert';
import 'dart:math';

import 'package:timezone/data/latest.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

/// A calendar date without an accidental device-time-zone interpretation.
final class CivilDate implements Comparable<CivilDate> {
  CivilDate(this.year, this.month, this.day) {
    final normalized = DateTime(year, month, day);
    if (normalized.year != year ||
        normalized.month != month ||
        normalized.day != day) {
      throw ArgumentError.value(toString(), 'date', 'Must be a valid date');
    }
  }

  factory CivilDate.fromDateTime(DateTime value) =>
      CivilDate(value.year, value.month, value.day);

  factory CivilDate.parse(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid civil date', value);
    }
    return CivilDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  final int year;
  final int month;
  final int day;

  /// UTC is intentional here: this value is only a Gregorian date-arithmetic
  /// carrier. A local midnight plus 24 hours can repeat or skip a civil date at
  /// a daylight-saving boundary.
  DateTime get dateArithmeticValue => DateTime.utc(year, month, day);
  int get weekday => dateArithmeticValue.weekday;

  CivilDate addDays(int days) =>
      CivilDate.fromDateTime(dateArithmeticValue.add(Duration(days: days)));

  CivilDate startOfWeek(int weekStartsOn) {
    if (weekStartsOn < DateTime.monday || weekStartsOn > DateTime.sunday) {
      throw ArgumentError.value(weekStartsOn, 'weekStartsOn');
    }
    final distance = (weekday - weekStartsOn + 7) % 7;
    return addDays(-distance);
  }

  bool isWithin(CivilDate first, CivilDate last) =>
      compareTo(first) >= 0 && compareTo(last) <= 0;

  @override
  int compareTo(CivilDate other) =>
      dateArithmeticValue.compareTo(other.dateArithmeticValue);

  @override
  bool operator ==(Object other) =>
      other is CivilDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

enum MeetingKind {
  lecture('Lecture', 'LEC'),
  lab('Lab', 'LAB'),
  recitation('Recitation', 'REC'),
  studio('Studio', 'STU'),
  officeHours('Office hours', 'OFFICE');

  const MeetingKind(this.label, this.shortLabel);
  final String label;
  final String shortLabel;
}

enum OccurrenceState { scheduled, moved, cancelled }

final class CampusPlace {
  CampusPlace({
    required String label,
    this.building,
    this.room,
    this.address,
    this.latitude,
    this.longitude,
    this.mapsProvider,
    this.placeId,
    this.campusCode,
  }) : label = _requiredText(label, 'label');

  factory CampusPlace.fromJson(Map<String, dynamic> json) => CampusPlace(
    label: json['label'] as String,
    building: _optionalText(json['building']),
    room: _optionalText(json['room']),
    address: _optionalText(json['address']),
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    mapsProvider: _optionalText(json['mapsProvider']),
    placeId: _optionalText(json['placeId']),
    campusCode: _optionalText(json['campusCode']),
  );

  final String label;
  final String? building;
  final String? room;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? mapsProvider;
  final String? placeId;
  final String? campusCode;

  String get shortLabel {
    final parts = <String>[?building, ?room];
    return parts.isEmpty ? label : parts.join(' · ');
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    if (building != null) 'building': building,
    if (room != null) 'room': room,
    if (address != null) 'address': address,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (mapsProvider != null) 'mapsProvider': mapsProvider,
    if (placeId != null) 'placeId': placeId,
    if (campusCode != null) 'campusCode': campusCode,
  };
}

final class AcademicReminder {
  AcademicReminder({
    required String reminderId,
    this.enabled = false,
    this.offsetMinutes = 10,
    this.customTitle,
    this.customBody,
  }) : reminderId = _requiredOpaqueId(reminderId, 'reminderId') {
    if (offsetMinutes < 0 || offsetMinutes > 7 * 24 * 60) {
      throw ArgumentError.value(offsetMinutes, 'offsetMinutes');
    }
  }

  factory AcademicReminder.fromJson(Map<String, dynamic> json) =>
      AcademicReminder(
        reminderId: json['reminderId'] as String,
        enabled: json['enabled'] as bool? ?? false,
        offsetMinutes: json['offsetMinutes'] as int? ?? 10,
        customTitle: _optionalText(json['customTitle']),
        customBody: _optionalText(json['customBody']),
      );

  final String reminderId;
  final bool enabled;
  final int offsetMinutes;
  final String? customTitle;
  final String? customBody;

  Map<String, dynamic> toJson() => {
    'reminderId': reminderId,
    'enabled': enabled,
    'offsetMinutes': offsetMinutes,
    if (customTitle != null) 'customTitle': customTitle,
    if (customBody != null) 'customBody': customBody,
  };
}

final class AcademicTerm {
  AcademicTerm({
    required String termId,
    required String name,
    required this.startDate,
    required this.endDate,
    required String timeZoneId,
    this.weekStartsOn = DateTime.monday,
    this.archived = false,
  }) : termId = _requiredOpaqueId(termId, 'termId'),
       name = _requiredText(name, 'name'),
       timeZoneId = _requiredText(timeZoneId, 'timeZoneId') {
    if (endDate.compareTo(startDate) < 0) {
      throw ArgumentError('A term must end on or after it starts');
    }
    if (weekStartsOn < DateTime.monday || weekStartsOn > DateTime.sunday) {
      throw ArgumentError.value(weekStartsOn, 'weekStartsOn');
    }
  }

  factory AcademicTerm.fromJson(Map<String, dynamic> json) => AcademicTerm(
    termId: json['termId'] as String,
    name: json['name'] as String,
    startDate: CivilDate.parse(json['startDate'] as String),
    endDate: CivilDate.parse(json['endDate'] as String),
    timeZoneId: json['timeZoneId'] as String,
    weekStartsOn: json['weekStartsOn'] as int? ?? DateTime.monday,
    archived: json['archived'] as bool? ?? false,
  );

  final String termId;
  final String name;
  final CivilDate startDate;
  final CivilDate endDate;
  final String timeZoneId;
  final int weekStartsOn;
  final bool archived;

  Map<String, dynamic> toJson() => {
    'termId': termId,
    'name': name,
    'startDate': startDate.toString(),
    'endDate': endDate.toString(),
    'timeZoneId': timeZoneId,
    'weekStartsOn': weekStartsOn,
    'archived': archived,
  };
}

final class AcademicCourse {
  AcademicCourse({
    required String courseId,
    required String termId,
    required String code,
    required String title,
    this.section,
    this.instructor,
    required this.colorValue,
    required String colorLabel,
    this.meetingSeriesIds = const <String>[],
    this.notebookId,
    this.archived = false,
  }) : courseId = _requiredOpaqueId(courseId, 'courseId'),
       termId = _requiredOpaqueId(termId, 'termId'),
       code = _requiredText(code, 'code'),
       title = _requiredText(title, 'title'),
       colorLabel = _requiredText(colorLabel, 'colorLabel') {
    for (final id in meetingSeriesIds) {
      _requiredOpaqueId(id, 'meetingSeriesId');
    }
    if (notebookId != null) _requiredOpaqueId(notebookId!, 'notebookId');
  }

  factory AcademicCourse.fromJson(Map<String, dynamic> json) => AcademicCourse(
    courseId: json['courseId'] as String,
    termId: json['termId'] as String,
    code: json['code'] as String,
    title: json['title'] as String,
    section: _optionalText(json['section']),
    instructor: _optionalText(json['instructor']),
    colorValue: json['colorValue'] as int,
    colorLabel: json['colorLabel'] as String,
    meetingSeriesIds: [
      for (final id in json['meetingSeriesIds'] as List? ?? const [])
        id as String,
    ],
    notebookId: _optionalText(json['notebookId']),
    archived: json['archived'] as bool? ?? false,
  );

  final String courseId;
  final String termId;
  final String code;
  final String title;
  final String? section;
  final String? instructor;
  final int colorValue;
  final String colorLabel;
  final List<String> meetingSeriesIds;
  final String? notebookId;
  final bool archived;

  AcademicCourse copyWith({List<String>? meetingSeriesIds}) => AcademicCourse(
    courseId: courseId,
    termId: termId,
    code: code,
    title: title,
    section: section,
    instructor: instructor,
    colorValue: colorValue,
    colorLabel: colorLabel,
    meetingSeriesIds: meetingSeriesIds ?? this.meetingSeriesIds,
    notebookId: notebookId,
    archived: archived,
  );

  Map<String, dynamic> toJson() => {
    'courseId': courseId,
    'termId': termId,
    'code': code,
    'title': title,
    if (section != null) 'section': section,
    if (instructor != null) 'instructor': instructor,
    'colorValue': colorValue,
    'colorLabel': colorLabel,
    'meetingSeriesIds': meetingSeriesIds,
    if (notebookId != null) 'notebookId': notebookId,
    'archived': archived,
  };
}

final class MeetingSeries {
  MeetingSeries({
    required String meetingSeriesId,
    required String courseId,
    required this.kind,
    required Set<int> weekdays,
    required this.localStartMinute,
    required this.localEndMinute,
    this.intervalWeeks = 1,
    required this.firstDate,
    required this.lastDate,
    required String timeZoneId,
    required this.place,
    this.reminders = const <AcademicReminder>[],
    this.revision = 1,
    required this.updatedAt,
    this.tombstonedAt,
  }) : meetingSeriesId = _requiredOpaqueId(meetingSeriesId, 'meetingSeriesId'),
       courseId = _requiredOpaqueId(courseId, 'courseId'),
       weekdays = Set.unmodifiable(weekdays),
       timeZoneId = _requiredText(timeZoneId, 'timeZoneId') {
    if (weekdays.isEmpty || weekdays.any((day) => day < 1 || day > 7)) {
      throw ArgumentError.value(weekdays, 'weekdays');
    }
    if (localStartMinute < 0 ||
        localStartMinute >= 24 * 60 ||
        localEndMinute <= localStartMinute ||
        localEndMinute > 24 * 60) {
      throw ArgumentError('Meeting times must be within one day, start to end');
    }
    if (intervalWeeks < 1) {
      throw ArgumentError.value(intervalWeeks, 'intervalWeeks');
    }
    if (lastDate.compareTo(firstDate) < 0) {
      throw ArgumentError('A meeting series must end on or after it starts');
    }
    if (revision < 1) throw ArgumentError.value(revision, 'revision');
    if (reminders.length > 8 ||
        reminders.map((rule) => rule.offsetMinutes).toSet().length !=
            reminders.length) {
      throw ArgumentError('Reminders must be unique and no more than eight');
    }
  }

  factory MeetingSeries.fromJson(Map<String, dynamic> json) => MeetingSeries(
    meetingSeriesId: json['meetingSeriesId'] as String,
    courseId: json['courseId'] as String,
    kind: MeetingKind.values.byName(json['kind'] as String),
    weekdays: {
      for (final day in json['weekdays'] as List? ?? const []) day as int,
    },
    localStartMinute: json['localStartMinute'] as int,
    localEndMinute: json['localEndMinute'] as int,
    intervalWeeks: json['intervalWeeks'] as int? ?? 1,
    firstDate: CivilDate.parse(json['firstDate'] as String),
    lastDate: CivilDate.parse(json['lastDate'] as String),
    timeZoneId: json['timeZoneId'] as String,
    place: CampusPlace.fromJson((json['place'] as Map).cast<String, dynamic>()),
    reminders: [
      for (final rule in json['reminders'] as List? ?? const [])
        AcademicReminder.fromJson((rule as Map).cast<String, dynamic>()),
    ],
    revision: json['revision'] as int? ?? 1,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      json['updatedAt'] as int,
      isUtc: true,
    ),
    tombstonedAt: _dateTimeFromJson(json['tombstonedAt']),
  );

  final String meetingSeriesId;
  final String courseId;
  final MeetingKind kind;
  final Set<int> weekdays;
  final int localStartMinute;
  final int localEndMinute;
  final int intervalWeeks;
  final CivilDate firstDate;
  final CivilDate lastDate;
  final String timeZoneId;
  final CampusPlace place;
  final List<AcademicReminder> reminders;
  final int revision;
  final DateTime updatedAt;
  final DateTime? tombstonedAt;

  Map<String, dynamic> toJson() => {
    'meetingSeriesId': meetingSeriesId,
    'courseId': courseId,
    'kind': kind.name,
    'weekdays': weekdays.toList()..sort(),
    'localStartMinute': localStartMinute,
    'localEndMinute': localEndMinute,
    'intervalWeeks': intervalWeeks,
    'firstDate': firstDate.toString(),
    'lastDate': lastDate.toString(),
    'timeZoneId': timeZoneId,
    'place': place.toJson(),
    'reminders': [for (final rule in reminders) rule.toJson()],
    'revision': revision,
    'updatedAt': updatedAt.toUtc().millisecondsSinceEpoch,
    if (tombstonedAt != null)
      'tombstonedAt': tombstonedAt!.toUtc().millisecondsSinceEpoch,
  };
}

final class ClassOccurrence {
  ClassOccurrence({
    required String occurrenceKey,
    required String meetingSeriesId,
    required String courseId,
    required this.originalDate,
    required this.date,
    required this.startInstant,
    required this.endInstant,
    required this.localStartMinute,
    required this.localEndMinute,
    required this.kind,
    required this.place,
    required String timeZoneId,
    this.reminders = const <AcademicReminder>[],
    this.state = OccurrenceState.scheduled,
    this.movedFrom,
    this.revision = 1,
    required this.updatedAt,
    this.tombstonedAt,
  }) : occurrenceKey = _requiredOpaqueId(occurrenceKey, 'occurrenceKey'),
       meetingSeriesId = _requiredOpaqueId(meetingSeriesId, 'meetingSeriesId'),
       courseId = _requiredOpaqueId(courseId, 'courseId'),
       timeZoneId = _requiredText(timeZoneId, 'timeZoneId') {
    if (!endInstant.isAfter(startInstant)) {
      throw ArgumentError('An occurrence must end after it starts');
    }
    if (revision < 1) throw ArgumentError.value(revision, 'revision');
  }

  factory ClassOccurrence.fromJson(Map<String, dynamic> json) =>
      ClassOccurrence(
        occurrenceKey: json['occurrenceKey'] as String,
        meetingSeriesId: json['meetingSeriesId'] as String,
        courseId: json['courseId'] as String,
        originalDate: CivilDate.parse(json['originalDate'] as String),
        date: CivilDate.parse(json['date'] as String),
        startInstant: DateTime.fromMillisecondsSinceEpoch(
          json['startInstant'] as int,
          isUtc: true,
        ),
        endInstant: DateTime.fromMillisecondsSinceEpoch(
          json['endInstant'] as int,
          isUtc: true,
        ),
        localStartMinute: json['localStartMinute'] as int,
        localEndMinute: json['localEndMinute'] as int,
        kind: MeetingKind.values.byName(json['kind'] as String),
        place: CampusPlace.fromJson(
          (json['place'] as Map).cast<String, dynamic>(),
        ),
        timeZoneId: json['timeZoneId'] as String,
        reminders: [
          for (final rule in json['reminders'] as List? ?? const [])
            AcademicReminder.fromJson((rule as Map).cast<String, dynamic>()),
        ],
        state: OccurrenceState.values.byName(
          json['state'] as String? ?? OccurrenceState.scheduled.name,
        ),
        movedFrom: _optionalText(json['movedFrom']),
        revision: json['revision'] as int? ?? 1,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          json['updatedAt'] as int,
          isUtc: true,
        ),
        tombstonedAt: _dateTimeFromJson(json['tombstonedAt']),
      );

  final String occurrenceKey;
  final String meetingSeriesId;
  final String courseId;
  final CivilDate originalDate;
  final CivilDate date;
  final DateTime startInstant;
  final DateTime endInstant;
  final int localStartMinute;
  final int localEndMinute;
  final MeetingKind kind;
  final CampusPlace place;
  final String timeZoneId;
  final List<AcademicReminder> reminders;
  final OccurrenceState state;
  final String? movedFrom;
  final int revision;
  final DateTime updatedAt;
  final DateTime? tombstonedAt;

  bool get canOpenNotebook => true;
  bool get triggersDoorway => state != OccurrenceState.cancelled;

  ClassOccurrence copyWith({
    CivilDate? date,
    DateTime? startInstant,
    DateTime? endInstant,
    int? localStartMinute,
    int? localEndMinute,
    MeetingKind? kind,
    CampusPlace? place,
    String? timeZoneId,
    List<AcademicReminder>? reminders,
    OccurrenceState? state,
    String? movedFrom,
    int? revision,
    DateTime? updatedAt,
    DateTime? tombstonedAt,
  }) => ClassOccurrence(
    occurrenceKey: occurrenceKey,
    meetingSeriesId: meetingSeriesId,
    courseId: courseId,
    originalDate: originalDate,
    date: date ?? this.date,
    startInstant: startInstant ?? this.startInstant,
    endInstant: endInstant ?? this.endInstant,
    localStartMinute: localStartMinute ?? this.localStartMinute,
    localEndMinute: localEndMinute ?? this.localEndMinute,
    kind: kind ?? this.kind,
    place: place ?? this.place,
    timeZoneId: timeZoneId ?? this.timeZoneId,
    reminders: reminders ?? this.reminders,
    state: state ?? this.state,
    movedFrom: movedFrom ?? this.movedFrom,
    revision: revision ?? this.revision,
    updatedAt: updatedAt ?? this.updatedAt,
    tombstonedAt: tombstonedAt ?? this.tombstonedAt,
  );

  Map<String, dynamic> toJson() => {
    'occurrenceKey': occurrenceKey,
    'meetingSeriesId': meetingSeriesId,
    'courseId': courseId,
    'originalDate': originalDate.toString(),
    'date': date.toString(),
    'startInstant': startInstant.toUtc().millisecondsSinceEpoch,
    'endInstant': endInstant.toUtc().millisecondsSinceEpoch,
    'localStartMinute': localStartMinute,
    'localEndMinute': localEndMinute,
    'kind': kind.name,
    'place': place.toJson(),
    'timeZoneId': timeZoneId,
    'reminders': [for (final rule in reminders) rule.toJson()],
    'state': state.name,
    if (movedFrom != null) 'movedFrom': movedFrom,
    'revision': revision,
    'updatedAt': updatedAt.toUtc().millisecondsSinceEpoch,
    if (tombstonedAt != null)
      'tombstonedAt': tombstonedAt!.toUtc().millisecondsSinceEpoch,
  };
}

typedef AcademicIdFactory = String Function(String kind);

abstract final class AcademicIds {
  static final Random _random = Random.secure();

  static String create(String kind) {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final token = base64Url.encode(bytes).replaceAll('=', '');
    return '${kind}_$token';
  }
}

abstract final class OccurrenceMaterializer {
  static bool _timeZonesReady = false;

  static List<ClassOccurrence> rebuild({
    required AcademicTerm term,
    required MeetingSeries series,
    required Iterable<ClassOccurrence> existing,
    required DateTime updatedAt,
    AcademicIdFactory idFactory = AcademicIds.create,
  }) {
    if (series.courseId.trim().isEmpty) {
      throw ArgumentError('A meeting series requires a course');
    }
    final first = _later(series.firstDate, term.startDate);
    final last = _earlier(series.lastDate, term.endDate);
    if (last.compareTo(first) < 0) {
      throw ArgumentError('Meeting dates must overlap their term');
    }

    final existingByDate = <CivilDate, ClassOccurrence>{
      for (final occurrence in existing)
        if (occurrence.meetingSeriesId == series.meetingSeriesId)
          occurrence.originalDate: occurrence,
    };
    final targetDates = <CivilDate>[];
    final anchorWeek = first.startOfWeek(term.weekStartsOn);
    for (var date = first; date.compareTo(last) <= 0; date = date.addDays(1)) {
      final weekIndex =
          date
              .startOfWeek(term.weekStartsOn)
              .dateArithmeticValue
              .difference(anchorWeek.dateArithmeticValue)
              .inDays ~/
          7;
      if (series.weekdays.contains(date.weekday) &&
          weekIndex % series.intervalWeeks == 0) {
        targetDates.add(date);
      }
    }

    final targetSet = targetDates.toSet();
    final rebuilt = <ClassOccurrence>[];
    for (final date in targetDates) {
      final prior = existingByDate[date];
      if (prior != null &&
          (prior.state == OccurrenceState.moved ||
              prior.state == OccurrenceState.cancelled)) {
        rebuilt.add(prior);
        continue;
      }
      final (start, end) = _resolveInstants(
        date,
        series.localStartMinute,
        series.localEndMinute,
        series.timeZoneId,
      );
      rebuilt.add(
        ClassOccurrence(
          occurrenceKey: prior?.occurrenceKey ?? idFactory('occurrence'),
          meetingSeriesId: series.meetingSeriesId,
          courseId: series.courseId,
          originalDate: date,
          date: date,
          startInstant: start,
          endInstant: end,
          localStartMinute: series.localStartMinute,
          localEndMinute: series.localEndMinute,
          kind: series.kind,
          place: series.place,
          timeZoneId: series.timeZoneId,
          reminders: series.reminders,
          revision: series.revision,
          updatedAt: updatedAt,
        ),
      );
    }

    for (final prior in existingByDate.values) {
      if (targetSet.contains(prior.originalDate)) continue;
      rebuilt.add(
        prior.state == OccurrenceState.cancelled
            ? prior
            : prior.copyWith(
                state: OccurrenceState.cancelled,
                revision: series.revision,
                updatedAt: updatedAt,
                tombstonedAt: updatedAt,
              ),
      );
    }
    rebuilt.sort(_compareOccurrences);
    return rebuilt;
  }

  static (DateTime, DateTime) _resolveInstants(
    CivilDate date,
    int startMinute,
    int endMinute,
    String timeZoneId,
  ) {
    if (!_timeZonesReady) {
      time_zone_data.initializeTimeZones();
      _timeZonesReady = true;
    }
    final location = time_zone.getLocation(timeZoneId);
    time_zone.TZDateTime atMinute(int minute) => time_zone.TZDateTime(
      location,
      date.year,
      date.month,
      date.day,
      minute ~/ 60,
      minute % 60,
    );
    return (atMinute(startMinute).toUtc(), atMinute(endMinute).toUtc());
  }
}

final class AcademicSchedule {
  AcademicSchedule({
    required this.terms,
    required this.courses,
    required this.meetingSeries,
    required this.occurrences,
  }) {
    _validateGraph();
  }

  factory AcademicSchedule.empty() => AcademicSchedule(
    terms: const [],
    courses: const [],
    meetingSeries: const [],
    occurrences: const [],
  );

  factory AcademicSchedule.fromJson(Map<String, dynamic> json) {
    final schema = json['schema'] as int? ?? 1;
    if (schema != currentSchema) {
      throw FormatException('Unsupported academic schedule schema $schema');
    }
    return AcademicSchedule(
      terms: [
        for (final term in json['terms'] as List? ?? const [])
          AcademicTerm.fromJson((term as Map).cast<String, dynamic>()),
      ],
      courses: [
        for (final course in json['courses'] as List? ?? const [])
          AcademicCourse.fromJson((course as Map).cast<String, dynamic>()),
      ],
      meetingSeries: [
        for (final series in json['meetingSeries'] as List? ?? const [])
          MeetingSeries.fromJson((series as Map).cast<String, dynamic>()),
      ],
      occurrences: [
        for (final occurrence in json['occurrences'] as List? ?? const [])
          ClassOccurrence.fromJson((occurrence as Map).cast<String, dynamic>()),
      ],
    );
  }

  static const int currentSchema = 1;

  final List<AcademicTerm> terms;
  final List<AcademicCourse> courses;
  final List<MeetingSeries> meetingSeries;
  final List<ClassOccurrence> occurrences;

  AcademicTerm? termFor(CivilDate date) {
    for (final term in terms.reversed) {
      if (!term.archived && date.isWithin(term.startDate, term.endDate)) {
        return term;
      }
    }
    return null;
  }

  AcademicTerm? get latestTerm {
    final active = terms.where((term) => !term.archived).toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate));
    return active.isEmpty ? null : active.last;
  }

  AcademicCourse? courseById(String id) {
    for (final course in courses) {
      if (course.courseId == id) return course;
    }
    return null;
  }

  List<ClassOccurrence> occurrencesOn(CivilDate date) {
    final found = [
      for (final occurrence in occurrences)
        if (occurrence.date == date) occurrence,
    ]..sort(_compareOccurrences);
    return found;
  }

  List<ClassOccurrence> occurrencesBetween(CivilDate first, CivilDate last) {
    final found = [
      for (final occurrence in occurrences)
        if (occurrence.date.isWithin(first, last)) occurrence,
    ]..sort(_compareOccurrences);
    return found;
  }

  List<ClassOccurrence> doorwayOccurrences(DateTime now) {
    final instant = now.toUtc();
    final found = [
      for (final occurrence in occurrences)
        if (occurrence.triggersDoorway &&
            !instant.isBefore(
              occurrence.startInstant.subtract(const Duration(minutes: 15)),
            ) &&
            !instant.isAfter(occurrence.endInstant))
          occurrence,
    ];
    found.sort((a, b) => b.startInstant.compareTo(a.startInstant));
    return found;
  }

  ClassOccurrence? nextOccurrence(DateTime now) {
    final instant = now.toUtc();
    final found = [
      for (final occurrence in occurrences)
        if (occurrence.triggersDoorway &&
            !occurrence.startInstant.isBefore(instant))
          occurrence,
    ]..sort(_compareOccurrences);
    return found.isEmpty ? null : found.first;
  }

  AcademicSchedule putMeeting({
    required AcademicTerm term,
    required AcademicCourse course,
    required MeetingSeries series,
    required DateTime updatedAt,
    AcademicIdFactory idFactory = AcademicIds.create,
  }) {
    if (course.termId != term.termId || series.courseId != course.courseId) {
      throw ArgumentError('Term, course, and meeting IDs do not agree');
    }
    if (!series.firstDate.isWithin(term.startDate, term.endDate) ||
        !series.lastDate.isWithin(term.startDate, term.endDate)) {
      throw ArgumentError('Meeting dates must stay within the term');
    }

    final nextTerms = _replaceById(terms, term, (value) => value.termId);
    final seriesIds = <String>{
      ...course.meetingSeriesIds,
      series.meetingSeriesId,
    }.toList();
    final nextCourse = course.copyWith(meetingSeriesIds: seriesIds);
    final nextCourses = _replaceById(
      courses,
      nextCourse,
      (value) => value.courseId,
    );
    final nextSeries = _replaceById(
      meetingSeries,
      series,
      (value) => value.meetingSeriesId,
    );
    final rebuilt = OccurrenceMaterializer.rebuild(
      term: term,
      series: series,
      existing: occurrences,
      updatedAt: updatedAt,
      idFactory: idFactory,
    );
    final nextOccurrences = [
      for (final occurrence in occurrences)
        if (occurrence.meetingSeriesId != series.meetingSeriesId) occurrence,
      ...rebuilt,
    ]..sort(_compareOccurrences);
    return AcademicSchedule(
      terms: nextTerms,
      courses: nextCourses,
      meetingSeries: nextSeries,
      occurrences: nextOccurrences,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema': currentSchema,
    'terms': [for (final term in terms) term.toJson()],
    'courses': [for (final course in courses) course.toJson()],
    'meetingSeries': [for (final series in meetingSeries) series.toJson()],
    'occurrences': [for (final occurrence in occurrences) occurrence.toJson()],
  };

  void _validateGraph() {
    final termIds = terms.map((term) => term.termId).toSet();
    final courseIds = courses.map((course) => course.courseId).toSet();
    final seriesIds = meetingSeries
        .map((series) => series.meetingSeriesId)
        .toSet();
    if (termIds.length != terms.length ||
        courseIds.length != courses.length ||
        seriesIds.length != meetingSeries.length ||
        occurrences.map((item) => item.occurrenceKey).toSet().length !=
            occurrences.length) {
      throw const FormatException('Academic schedule IDs must be unique');
    }
    for (final course in courses) {
      if (!termIds.contains(course.termId) ||
          course.meetingSeriesIds.any((id) => !seriesIds.contains(id))) {
        throw const FormatException('Course references are incomplete');
      }
    }
    for (final series in meetingSeries) {
      if (!courseIds.contains(series.courseId)) {
        throw const FormatException('Meeting series has no course');
      }
    }
    for (final occurrence in occurrences) {
      if (!courseIds.contains(occurrence.courseId) ||
          !seriesIds.contains(occurrence.meetingSeriesId)) {
        throw const FormatException('Occurrence references are incomplete');
      }
    }
  }
}

List<T> _replaceById<T>(List<T> source, T next, String Function(T) idOf) {
  final targetId = idOf(next);
  var replaced = false;
  final result = <T>[
    for (final value in source)
      if (idOf(value) == targetId) ...[next] else value,
  ];
  replaced = source.any((value) => idOf(value) == targetId);
  if (!replaced) result.add(next);
  return List.unmodifiable(result);
}

int _compareOccurrences(ClassOccurrence a, ClassOccurrence b) {
  final start = a.startInstant.compareTo(b.startInstant);
  if (start != 0) return start;
  return a.occurrenceKey.compareTo(b.occurrenceKey);
}

CivilDate _later(CivilDate a, CivilDate b) => a.compareTo(b) >= 0 ? a : b;
CivilDate _earlier(CivilDate a, CivilDate b) => a.compareTo(b) <= 0 ? a : b;

String _requiredText(String value, String name) {
  final clean = value.trim();
  if (clean.isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be blank');
  }
  return clean;
}

String _requiredOpaqueId(String value, String name) {
  final clean = _requiredText(value, name);
  if (clean.runes.any((rune) => rune < 0x20 || rune == 0x7f)) {
    throw ArgumentError.value(
      value,
      name,
      'Must not contain control characters',
    );
  }
  return clean;
}

String? _optionalText(Object? value) {
  if (value is! String) return null;
  final clean = value.trim();
  return clean.isEmpty ? null : clean;
}

DateTime? _dateTimeFromJson(Object? value) => value is int
    ? DateTime.fromMillisecondsSinceEpoch(value, isUtc: true)
    : null;
