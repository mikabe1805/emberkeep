import 'package:emberkeep/daybook/domain/civil_date.dart';
import 'package:emberkeep/daybook/domain/daybook_event.dart';
import 'package:emberkeep/daybook/domain/daybook_task.dart';
import 'package:emberkeep/daybook/domain/weekly_event_materializer.dart';
export 'package:emberkeep/daybook/domain/civil_date.dart';

import 'dart:convert';
import 'dart:math';

import 'package:timezone/data/latest.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

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

enum AcademicWorkKind {
  assignment('Assignment', 'DUE'),
  exam('Exam', 'EXAM');

  const AcademicWorkKind(this.label, this.shortLabel);
  final String label;
  final String shortLabel;
}

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
    this.transitionBufferMinutes = 10,
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
    if (transitionBufferMinutes < 0 || transitionBufferMinutes > 120) {
      throw ArgumentError.value(
        transitionBufferMinutes,
        'transitionBufferMinutes',
      );
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
    transitionBufferMinutes: json['transitionBufferMinutes'] as int? ?? 10,
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
  final int transitionBufferMinutes;
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
    'transitionBufferMinutes': transitionBufferMinutes,
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
    this.userAdjusted = false,
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

  factory ClassOccurrence.fromJson(Map<String, dynamic> json) {
    final state = OccurrenceState.values.byName(
      json['state'] as String? ?? OccurrenceState.scheduled.name,
    );
    final tombstonedAt = _dateTimeFromJson(json['tombstonedAt']);
    return ClassOccurrence(
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
      state: state,
      movedFrom: _optionalText(json['movedFrom']),
      userAdjusted:
          json['userAdjusted'] as bool? ??
          ((state == OccurrenceState.moved ||
                  state == OccurrenceState.cancelled) &&
              tombstonedAt == null),
      revision: json['revision'] as int? ?? 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        json['updatedAt'] as int,
        isUtc: true,
      ),
      tombstonedAt: tombstonedAt,
    );
  }

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
  final bool userAdjusted;
  final int revision;
  final DateTime updatedAt;
  final DateTime? tombstonedAt;

  bool get canOpenNotebook => true;
  bool get triggersDoorway => state != OccurrenceState.cancelled;
  bool get canAdjust => userAdjusted || tombstonedAt == null;

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
    bool clearMovedFrom = false,
    bool? userAdjusted,
    int? revision,
    DateTime? updatedAt,
    DateTime? tombstonedAt,
    bool clearTombstonedAt = false,
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
    movedFrom: clearMovedFrom ? null : movedFrom ?? this.movedFrom,
    userAdjusted: userAdjusted ?? this.userAdjusted,
    revision: revision ?? this.revision,
    updatedAt: updatedAt ?? this.updatedAt,
    tombstonedAt: clearTombstonedAt ? null : tombstonedAt ?? this.tombstonedAt,
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
    if (userAdjusted) 'userAdjusted': true,
    'revision': revision,
    'updatedAt': updatedAt.toUtc().millisecondsSinceEpoch,
    if (tombstonedAt != null)
      'tombstonedAt': tombstonedAt!.toUtc().millisecondsSinceEpoch,
  };
}

/// A pair of live classes occupying the same part of a day.
///
/// Conflicts are derived schedule truth rather than persisted state, so moving
/// or cancelling either occurrence immediately resolves the pressure point.
final class AcademicMeetingConflict {
  const AcademicMeetingConflict(this.first, this.second);

  final ClassOccurrence first;
  final ClassOccurrence second;

  CivilDate get date => first.date;
  int get overlapStartMinute =>
      max(first.localStartMinute, second.localStartMinute);
  int get overlapEndMinute => min(first.localEndMinute, second.localEndMinute);
  int get overlapMinutes => overlapEndMinute - overlapStartMinute;

  bool includes(String occurrenceKey) =>
      first.occurrenceKey == occurrenceKey ||
      second.occurrenceKey == occurrenceKey;

  ClassOccurrence otherThan(String occurrenceKey) =>
      first.occurrenceKey == occurrenceKey ? second : first;
}

/// Two non-overlapping classes that leave less transition time than requested.
///
/// A tight transition is deliberately separate from a conflict: both meetings
/// remain truthful fixed commitments, while the daybook can still warn that
/// travel or breathing room is thinner than the person asked for.
final class AcademicTransitionPressure {
  const AcademicTransitionPressure({
    required this.before,
    required this.after,
    required this.gapMinutes,
    required this.requestedMinutes,
  });

  final ClassOccurrence before;
  final ClassOccurrence after;
  final int gapMinutes;
  final int requestedMinutes;

  CivilDate get date => before.date;

  bool includes(String occurrenceKey) =>
      before.occurrenceKey == occurrenceKey ||
      after.occurrenceKey == occurrenceKey;
}

/// A course-linked obligation. Academic work stays separate from Quests so its
/// identity, due date, and completion state remain ordinary schedule truth.
final class AcademicWorkItem {
  AcademicWorkItem({
    required String workId,
    required String courseId,
    required this.kind,
    required String title,
    required this.dueDate,
    this.dueMinute,
    this.details,
    this.completedAt,
    this.revision = 1,
    required this.updatedAt,
    this.tombstonedAt,
  }) : workId = _requiredOpaqueId(workId, 'workId'),
       courseId = _requiredOpaqueId(courseId, 'courseId'),
       title = _requiredText(title, 'title') {
    if (dueMinute != null && (dueMinute! < 0 || dueMinute! >= 24 * 60)) {
      throw ArgumentError.value(dueMinute, 'dueMinute');
    }
    if (details != null && details!.trim().isEmpty) {
      throw ArgumentError.value(details, 'details');
    }
    if (revision < 1) throw ArgumentError.value(revision, 'revision');
  }

  factory AcademicWorkItem.fromJson(Map<String, dynamic> json) =>
      AcademicWorkItem(
        workId: json['workId'] as String,
        courseId: json['courseId'] as String,
        kind: AcademicWorkKind.values.byName(json['kind'] as String),
        title: json['title'] as String,
        dueDate: CivilDate.parse(json['dueDate'] as String),
        dueMinute: json['dueMinute'] as int?,
        details: _optionalText(json['details']),
        completedAt: _dateTimeFromJson(json['completedAt']),
        revision: json['revision'] as int? ?? 1,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          json['updatedAt'] as int,
          isUtc: true,
        ),
        tombstonedAt: _dateTimeFromJson(json['tombstonedAt']),
      );

  final String workId;
  final String courseId;
  final AcademicWorkKind kind;
  final String title;
  final CivilDate dueDate;
  final int? dueMinute;
  final String? details;
  final DateTime? completedAt;
  final int revision;
  final DateTime updatedAt;
  final DateTime? tombstonedAt;

  bool get completed => completedAt != null;

  AcademicWorkItem withCompletion({
    required bool completed,
    required DateTime updatedAt,
  }) => AcademicWorkItem(
    workId: workId,
    courseId: courseId,
    kind: kind,
    title: title,
    dueDate: dueDate,
    dueMinute: dueMinute,
    details: details,
    completedAt: completed ? updatedAt.toUtc() : null,
    revision: revision + 1,
    updatedAt: updatedAt.toUtc(),
    tombstonedAt: tombstonedAt,
  );

  Map<String, dynamic> toJson() => {
    'workId': workId,
    'courseId': courseId,
    'kind': kind.name,
    'title': title,
    'dueDate': dueDate.toString(),
    if (dueMinute != null) 'dueMinute': dueMinute,
    if (details != null) 'details': details,
    if (completedAt != null)
      'completedAt': completedAt!.toUtc().millisecondsSinceEpoch,
    'revision': revision,
    'updatedAt': updatedAt.toUtc().millisecondsSinceEpoch,
    if (tombstonedAt != null)
      'tombstonedAt': tombstonedAt!.toUtc().millisecondsSinceEpoch,
  };
}

/// The person's explicit study-planning preferences for one course item.
///
/// The plan is separate from the assignment or exam itself: changing or
/// clearing study time never changes the obligation's title or deadline.
final class AcademicStudyPlan {
  AcademicStudyPlan({
    required String workId,
    required this.totalMinutes,
    required this.sessionMinutes,
    required this.dailyStartMinute,
    required this.dailyEndMinute,
    this.revision = 1,
    required this.updatedAt,
  }) : workId = _requiredOpaqueId(workId, 'workId') {
    if (totalMinutes < 15 || totalMinutes > 7 * 24 * 60) {
      throw ArgumentError.value(totalMinutes, 'totalMinutes');
    }
    if (sessionMinutes < 15 || sessionMinutes > 4 * 60) {
      throw ArgumentError.value(sessionMinutes, 'sessionMinutes');
    }
    if (dailyStartMinute < 0 ||
        dailyStartMinute >= 24 * 60 ||
        dailyEndMinute <= dailyStartMinute ||
        dailyEndMinute > 24 * 60 ||
        dailyEndMinute - dailyStartMinute < 15) {
      throw ArgumentError('Study hours must leave at least fifteen minutes');
    }
    if (revision < 1) throw ArgumentError.value(revision, 'revision');
  }

  factory AcademicStudyPlan.fromJson(Map<String, dynamic> json) =>
      AcademicStudyPlan(
        workId: json['workId'] as String,
        totalMinutes: json['totalMinutes'] as int,
        sessionMinutes: json['sessionMinutes'] as int,
        dailyStartMinute: json['dailyStartMinute'] as int,
        dailyEndMinute: json['dailyEndMinute'] as int,
        revision: json['revision'] as int? ?? 1,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          json['updatedAt'] as int,
          isUtc: true,
        ),
      );

  final String workId;
  final int totalMinutes;
  final int sessionMinutes;
  final int dailyStartMinute;
  final int dailyEndMinute;
  final int revision;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'workId': workId,
    'totalMinutes': totalMinutes,
    'sessionMinutes': sessionMinutes,
    'dailyStartMinute': dailyStartMinute,
    'dailyEndMinute': dailyEndMinute,
    'revision': revision,
    'updatedAt': updatedAt.toUtc().millisecondsSinceEpoch,
  };
}

/// One concrete, user-approved study appointment.
final class AcademicStudyBlock {
  AcademicStudyBlock({
    required String studyBlockId,
    required String workId,
    required this.date,
    required this.startMinute,
    required this.endMinute,
    this.completedAt,
    this.revision = 1,
    required this.updatedAt,
  }) : studyBlockId = _requiredOpaqueId(studyBlockId, 'studyBlockId'),
       workId = _requiredOpaqueId(workId, 'workId') {
    if (startMinute < 0 ||
        startMinute >= 24 * 60 ||
        endMinute <= startMinute ||
        endMinute > 24 * 60) {
      throw ArgumentError('Study block times must stay within one day');
    }
    if (revision < 1) throw ArgumentError.value(revision, 'revision');
  }

  factory AcademicStudyBlock.fromJson(Map<String, dynamic> json) =>
      AcademicStudyBlock(
        studyBlockId: json['studyBlockId'] as String,
        workId: json['workId'] as String,
        date: CivilDate.parse(json['date'] as String),
        startMinute: json['startMinute'] as int,
        endMinute: json['endMinute'] as int,
        completedAt: _dateTimeFromJson(json['completedAt']),
        revision: json['revision'] as int? ?? 1,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          json['updatedAt'] as int,
          isUtc: true,
        ),
      );

  final String studyBlockId;
  final String workId;
  final CivilDate date;
  final int startMinute;
  final int endMinute;
  final DateTime? completedAt;
  final int revision;
  final DateTime updatedAt;

  int get durationMinutes => endMinute - startMinute;
  bool get completed => completedAt != null;

  AcademicStudyBlock withCompletion({
    required bool completed,
    required DateTime updatedAt,
  }) => AcademicStudyBlock(
    studyBlockId: studyBlockId,
    workId: workId,
    date: date,
    startMinute: startMinute,
    endMinute: endMinute,
    completedAt: completed ? updatedAt.toUtc() : null,
    revision: revision + 1,
    updatedAt: updatedAt.toUtc(),
  );

  Map<String, dynamic> toJson() => {
    'studyBlockId': studyBlockId,
    'workId': workId,
    'date': date.toString(),
    'startMinute': startMinute,
    'endMinute': endMinute,
    if (completedAt != null)
      'completedAt': completedAt!.toUtc().millisecondsSinceEpoch,
    'revision': revision,
    'updatedAt': updatedAt.toUtc().millisecondsSinceEpoch,
  };
}

final class AcademicStudySuggestion {
  const AcademicStudySuggestion({
    required this.targetMinutes,
    required this.completedMinutes,
    required this.blocks,
  });

  final int targetMinutes;
  final int completedMinutes;
  final List<AcademicStudyBlock> blocks;

  int get remainingTargetMinutes => max(0, targetMinutes - completedMinutes);
  int get scheduledMinutes =>
      blocks.fold(0, (total, block) => total + block.durationMinutes);
  int get unscheduledMinutes =>
      max(0, remainingTargetMinutes - scheduledMinutes);
  bool get fullyScheduled => unscheduledMinutes == 0;
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
          prior.userAdjusted &&
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
        prior.tombstonedAt != null && !prior.userAdjusted
            ? prior
            : prior.copyWith(
                state: OccurrenceState.cancelled,
                clearMovedFrom: true,
                userAdjusted: false,
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

  static (DateTime, DateTime) resolveInstants(
    CivilDate date,
    int startMinute,
    int endMinute,
    String timeZoneId,
  ) => _resolveInstants(date, startMinute, endMinute, timeZoneId);

  static time_zone.TZDateTime localTime(DateTime instant, String timeZoneId) {
    if (!_timeZonesReady) {
      time_zone_data.initializeTimeZones();
      _timeZonesReady = true;
    }
    return time_zone.TZDateTime.from(
      instant.toUtc(),
      time_zone.getLocation(timeZoneId),
    );
  }
}

final class AcademicScheduleDecodeResult {
  const AcademicScheduleDecodeResult(this.schedule, this.droppedNeutralRecords);

  final AcademicSchedule schedule;
  final int droppedNeutralRecords;
}

final class AcademicSchedule {
  AcademicSchedule({
    required this.terms,
    required this.courses,
    required this.meetingSeries,
    required this.occurrences,
    this.workItems = const [],
    this.studyPlans = const [],
    this.studyBlocks = const [],
    this.events = const [],
    this.tasks = const [],
  }) {
    _validateGraph();
  }

  factory AcademicSchedule.empty() => AcademicSchedule(
    terms: const [],
    courses: const [],
    meetingSeries: const [],
    occurrences: const [],
    workItems: const [],
    studyPlans: const [],
    studyBlocks: const [],
    events: const [],
    tasks: const [],
  );

  factory AcademicSchedule.fromJson(Map<String, dynamic> json) =>
      decode(json).schedule;

  static AcademicScheduleDecodeResult decode(Map<String, dynamic> json) {
    final schema = json['schema'] as int? ?? 1;
    if (schema < 1 || schema > currentSchema) {
      throw FormatException('Unsupported academic schedule schema $schema');
    }
    final academic = AcademicSchedule(
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
      workItems: schema < 2
          ? const []
          : [
              for (final item in json['workItems'] as List? ?? const [])
                AcademicWorkItem.fromJson(
                  (item as Map).cast<String, dynamic>(),
                ),
            ],
      studyPlans: schema < 4
          ? const []
          : [
              for (final plan in json['studyPlans'] as List? ?? const [])
                AcademicStudyPlan.fromJson(
                  (plan as Map).cast<String, dynamic>(),
                ),
            ],
      studyBlocks: schema < 4
          ? const []
          : [
              for (final block in json['studyBlocks'] as List? ?? const [])
                AcademicStudyBlock.fromJson(
                  (block as Map).cast<String, dynamic>(),
                ),
            ],
    );
    if (schema < 5) {
      return AcademicScheduleDecodeResult(academic, 0);
    }

    var droppedNeutralRecords = 0;
    final events = <DaybookEvent>[];
    final eventIds = <String>{};
    for (final rawEvent in json['events'] as List? ?? const []) {
      try {
        final event = DaybookEvent.fromJson(
          (rawEvent as Map).cast<String, dynamic>(),
        );
        if (!eventIds.add(event.eventId)) {
          droppedNeutralRecords += 1;
          continue;
        }
        events.add(event);
      } catch (_) {
        droppedNeutralRecords += 1;
      }
    }
    final tasks = <DaybookTask>[];
    final taskIds = <String>{};
    for (final rawTask in json['tasks'] as List? ?? const []) {
      try {
        final task = DaybookTask.fromJson(
          (rawTask as Map).cast<String, dynamic>(),
        );
        if (!taskIds.add(task.taskId)) {
          droppedNeutralRecords += 1;
          continue;
        }
        tasks.add(task);
      } catch (_) {
        droppedNeutralRecords += 1;
      }
    }
    return AcademicScheduleDecodeResult(
      academic._rebuild(
        events: List.unmodifiable(events),
        tasks: List.unmodifiable(tasks),
      ),
      droppedNeutralRecords,
    );
  }

  static const int currentSchema = 5;

  final List<AcademicTerm> terms;
  final List<AcademicCourse> courses;
  final List<MeetingSeries> meetingSeries;
  final List<ClassOccurrence> occurrences;
  final List<AcademicWorkItem> workItems;
  final List<AcademicStudyPlan> studyPlans;
  final List<AcademicStudyBlock> studyBlocks;
  final List<DaybookEvent> events;
  final List<DaybookTask> tasks;

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

  MeetingSeries? meetingSeriesById(String id) {
    for (final series in meetingSeries) {
      if (series.meetingSeriesId == id) return series;
    }
    return null;
  }

  ClassOccurrence? occurrenceByKey(String key) {
    for (final occurrence in occurrences) {
      if (occurrence.occurrenceKey == key) return occurrence;
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

  List<DaybookEventOccurrence> eventOccurrencesBetween(
    CivilDate first,
    CivilDate last,
  ) {
    if (first.compareTo(last) > 0) {
      throw ArgumentError('The event range must start before it ends');
    }
    final found = <DaybookEventOccurrence>[
      for (final event in events)
        ...WeeklyEventMaterializer.between(event, first, last),
    ]..sort(_compareDaybookOccurrences);
    return List.unmodifiable(found);
  }

  List<DaybookTask> tasksOn(CivilDate date) {
    final found = [
      for (final task in tasks)
        if (task.dueDate == date) task,
    ]..sort(_compareDaybookTasks);
    return List.unmodifiable(found);
  }

  List<AcademicMeetingConflict> meetingConflictsOn(CivilDate date) {
    final live = occurrencesOn(
      date,
    ).where((item) => item.state != OccurrenceState.cancelled).toList();
    final conflicts = <AcademicMeetingConflict>[];
    for (var first = 0; first < live.length; first++) {
      for (var second = first + 1; second < live.length; second++) {
        final left = live[first];
        final right = live[second];
        if (left.startInstant.isBefore(right.endInstant) &&
            right.startInstant.isBefore(left.endInstant)) {
          conflicts.add(AcademicMeetingConflict(left, right));
        }
      }
    }
    return List.unmodifiable(conflicts);
  }

  List<AcademicMeetingConflict> meetingConflictsBetween(
    CivilDate first,
    CivilDate last,
  ) {
    final conflicts = <AcademicMeetingConflict>[];
    for (var date = first; date.compareTo(last) <= 0; date = date.addDays(1)) {
      conflicts.addAll(meetingConflictsOn(date));
    }
    return List.unmodifiable(conflicts);
  }

  List<AcademicTransitionPressure> transitionPressuresOn(CivilDate date) {
    final live = occurrencesOn(
      date,
    ).where((item) => item.state != OccurrenceState.cancelled).toList();
    final conflictedKeys = <String>{
      for (final conflict in meetingConflictsOn(date)) ...[
        conflict.first.occurrenceKey,
        conflict.second.occurrenceKey,
      ],
    };
    final pressures = <AcademicTransitionPressure>[];

    for (var index = 0; index < live.length; index++) {
      final before = live[index];
      if (conflictedKeys.contains(before.occurrenceKey)) continue;

      ClassOccurrence? after;
      for (
        var candidateIndex = index + 1;
        candidateIndex < live.length;
        candidateIndex++
      ) {
        final candidate = live[candidateIndex];
        if (conflictedKeys.contains(candidate.occurrenceKey)) continue;
        if (!candidate.startInstant.isBefore(before.endInstant)) {
          after = candidate;
          break;
        }
      }
      if (after == null) continue;

      final beforeBuffer =
          meetingSeriesById(before.meetingSeriesId)?.transitionBufferMinutes ??
          10;
      final afterBuffer =
          meetingSeriesById(after.meetingSeriesId)?.transitionBufferMinutes ??
          10;
      final requested = max(beforeBuffer, afterBuffer);
      if (requested == 0) continue;
      final gap = after.startInstant.difference(before.endInstant).inMinutes;
      if (gap >= requested) continue;

      pressures.add(
        AcademicTransitionPressure(
          before: before,
          after: after,
          gapMinutes: gap,
          requestedMinutes: requested,
        ),
      );
    }

    return List.unmodifiable(pressures);
  }

  List<AcademicTransitionPressure> transitionPressuresBetween(
    CivilDate first,
    CivilDate last,
  ) {
    final pressures = <AcademicTransitionPressure>[];
    for (var date = first; date.compareTo(last) <= 0; date = date.addDays(1)) {
      pressures.addAll(transitionPressuresOn(date));
    }
    return List.unmodifiable(pressures);
  }

  List<AcademicWorkItem> workItemsOn(CivilDate date) {
    final found = [
      for (final item in workItems)
        if (item.tombstonedAt == null && item.dueDate == date) item,
    ]..sort(_compareWorkItems);
    return found;
  }

  List<AcademicWorkItem> workItemsBetween(CivilDate first, CivilDate last) {
    final found = [
      for (final item in workItems)
        if (item.tombstonedAt == null && item.dueDate.isWithin(first, last))
          item,
    ]..sort(_compareWorkItems);
    return found;
  }

  AcademicStudyPlan? studyPlanFor(String workId) {
    for (final plan in studyPlans) {
      if (plan.workId == workId) return plan;
    }
    return null;
  }

  List<AcademicStudyBlock> studyBlocksFor(String workId) {
    final found = [
      for (final block in studyBlocks)
        if (block.workId == workId) block,
    ]..sort(_compareStudyBlocks);
    return found;
  }

  List<AcademicStudyBlock> studyBlocksOn(CivilDate date) {
    final found = [
      for (final block in studyBlocks)
        if (block.date == date) block,
    ]..sort(_compareStudyBlocks);
    return found;
  }

  List<AcademicStudyBlock> studyBlocksBetween(CivilDate first, CivilDate last) {
    final found = [
      for (final block in studyBlocks)
        if (block.date.isWithin(first, last)) block,
    ]..sort(_compareStudyBlocks);
    return found;
  }

  int plannedStudyMinutesFor(String workId) => studyBlocksFor(
    workId,
  ).fold(0, (total, block) => total + block.durationMinutes);

  AcademicStudySuggestion suggestStudyBlocks({
    required String workId,
    required int totalMinutes,
    required int sessionMinutes,
    required int dailyStartMinute,
    required int dailyEndMinute,
    required DateTime now,
    CivilDate? planningStartDate,
    AcademicIdFactory idFactory = AcademicIds.create,
  }) {
    final plan = AcademicStudyPlan(
      workId: workId,
      totalMinutes: totalMinutes,
      sessionMinutes: sessionMinutes,
      dailyStartMinute: dailyStartMinute,
      dailyEndMinute: dailyEndMinute,
      updatedAt: now.toUtc(),
    );
    final work = workItems.where((item) => item.workId == workId).firstOrNull;
    if (work == null || work.tombstonedAt != null || work.completed) {
      throw ArgumentError.value(workId, 'workId');
    }
    final course = courseById(work.courseId);
    final term = course == null
        ? null
        : terms.where((item) => item.termId == course.termId).firstOrNull;
    if (term == null) throw ArgumentError.value(work.courseId, 'courseId');

    final completedMinutes = studyBlocksFor(workId)
        .where((block) => block.completed)
        .fold(0, (total, block) => total + block.durationMinutes);
    var remaining = max(0, totalMinutes - completedMinutes);
    if (remaining == 0) {
      return AcademicStudySuggestion(
        targetMinutes: totalMinutes,
        completedMinutes: completedMinutes,
        blocks: const [],
      );
    }

    final localNow = OccurrenceMaterializer.localTime(now, term.timeZoneId);
    final today = planningStartDate ?? CivilDate.fromDateTime(localNow);
    if (today.compareTo(work.dueDate) > 0) {
      return AcademicStudySuggestion(
        targetMinutes: totalMinutes,
        completedMinutes: completedMinutes,
        blocks: const [],
      );
    }
    final nowMinute = localNow.hour * 60 + localNow.minute;
    final candidates = <AcademicStudyBlock>[];
    final occupiedByOtherWork = [
      for (final block in studyBlocks)
        if (block.workId != workId || block.completed) block,
    ];
    final availableDays = <({CivilDate date, List<(int, int)> ranges})>[];

    for (
      var date = today;
      date.compareTo(work.dueDate) <= 0;
      date = date.addDays(1)
    ) {
      var windowStart = plan.dailyStartMinute;
      var windowEnd = plan.dailyEndMinute;
      if (planningStartDate == null && date == today) {
        windowStart = max(windowStart, _ceilToQuarterHour(nowMinute));
      }
      if (date == work.dueDate) {
        windowEnd = min(windowEnd, work.dueMinute ?? 24 * 60);
      }
      if (windowEnd - windowStart < 15) continue;

      final occupied = <(int, int)>[];
      for (final occurrence in occurrencesOn(date)) {
        if (occurrence.state == OccurrenceState.cancelled) continue;
        final buffer =
            meetingSeriesById(
              occurrence.meetingSeriesId,
            )?.transitionBufferMinutes ??
            10;
        occupied.add((
          max(0, occurrence.localStartMinute - buffer),
          min(24 * 60, occurrence.localEndMinute + buffer),
        ));
      }
      for (final block in occupiedByOtherWork) {
        if (block.date != date) continue;
        occupied.add((block.startMinute, block.endMinute));
      }
      final ranges = _availableMinuteRanges(windowStart, windowEnd, occupied);
      if (ranges.any((range) => range.$2 - range.$1 >= 15)) {
        availableDays.add((date: date, ranges: ranges));
      }
    }

    var preferredDay = 0;
    for (final duration in _studySessionDurations(remaining, sessionMinutes)) {
      if (availableDays.isEmpty) break;
      var placed = false;
      for (var offset = 0; offset < availableDays.length; offset++) {
        final dayIndex = (preferredDay + offset) % availableDays.length;
        final day = availableDays[dayIndex];
        final rangeIndex = day.ranges.indexWhere(
          (range) => range.$2 - range.$1 >= duration,
        );
        if (rangeIndex < 0) continue;
        final range = day.ranges.removeAt(rangeIndex);
        candidates.add(
          AcademicStudyBlock(
            studyBlockId: idFactory('study_block'),
            workId: workId,
            date: day.date,
            startMinute: range.$1,
            endMinute: range.$1 + duration,
            updatedAt: now.toUtc(),
          ),
        );
        if (range.$2 - (range.$1 + duration) >= 15) {
          day.ranges.insert(rangeIndex, (range.$1 + duration, range.$2));
        }
        preferredDay = (dayIndex + 1) % availableDays.length;
        placed = true;
        break;
      }
      if (!placed) break;
    }
    candidates.sort(_compareStudyBlocks);

    return AcademicStudySuggestion(
      targetMinutes: totalMinutes,
      completedMinutes: completedMinutes,
      blocks: List.unmodifiable(candidates),
    );
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

  AcademicSchedule putEvent(DaybookEvent event) {
    final nextEvents = _replaceById(
      events,
      event,
      (value) => value.eventId,
    ).toList()..sort(_compareDaybookEvents);
    return _rebuild(events: List.unmodifiable(nextEvents));
  }

  AcademicSchedule deleteEvent(String eventId) {
    final nextEvents = [
      for (final event in events)
        if (event.eventId != eventId) event,
    ];
    if (nextEvents.length == events.length) return this;
    return _rebuild(events: List.unmodifiable(nextEvents));
  }

  AcademicSchedule moveEventOccurrence({
    required String eventId,
    required String occurrenceKey,
    required CivilDate startDate,
    required CivilDate endDate,
    int? startMinute,
    int? endMinute,
    required DateTime updatedAt,
  }) {
    final event = _eventById(eventId);
    final originalDate = _eventOriginalDate(event, occurrenceKey);
    final exception = DaybookEventException(
      occurrenceKey: occurrenceKey,
      originalDate: originalDate,
      state: DaybookEventOccurrenceState.moved,
      movedStartDate: startDate,
      movedEndDate: endDate,
      movedStartMinute: startMinute,
      movedEndMinute: endMinute,
      updatedAt: updatedAt,
    );
    return putEvent(
      event.copyWith(
        exceptions: _replaceEventException(event, exception),
        updatedAt: updatedAt,
      ),
    );
  }

  AcademicSchedule cancelEventOccurrence({
    required String eventId,
    required String occurrenceKey,
    required DateTime updatedAt,
  }) {
    final event = _eventById(eventId);
    final originalDate = _eventOriginalDate(event, occurrenceKey);
    final exception = DaybookEventException(
      occurrenceKey: occurrenceKey,
      originalDate: originalDate,
      state: DaybookEventOccurrenceState.cancelled,
      updatedAt: updatedAt,
    );
    return putEvent(
      event.copyWith(
        exceptions: _replaceEventException(event, exception),
        updatedAt: updatedAt,
      ),
    );
  }

  AcademicSchedule restoreEventOccurrence({
    required String eventId,
    required String occurrenceKey,
    required DateTime updatedAt,
  }) {
    final event = _eventById(eventId);
    final originalDate = _eventOriginalDate(event, occurrenceKey);
    if (!event.exceptions.any((item) => item.originalDate == originalDate)) {
      throw ArgumentError.value(occurrenceKey, 'occurrenceKey');
    }
    return putEvent(
      event.copyWith(
        exceptions: List.unmodifiable([
          for (final exception in event.exceptions)
            if (exception.originalDate != originalDate) exception,
        ]),
        updatedAt: updatedAt,
      ),
    );
  }

  AcademicSchedule putTask(DaybookTask task) {
    final nextTasks = _replaceById(
      tasks,
      task,
      (value) => value.taskId,
    ).toList()..sort(_compareDaybookTasks);
    return _rebuild(tasks: List.unmodifiable(nextTasks));
  }

  AcademicSchedule deleteTask(String taskId) {
    final nextTasks = [
      for (final task in tasks)
        if (task.taskId != taskId) task,
    ];
    if (nextTasks.length == tasks.length) return this;
    return _rebuild(tasks: List.unmodifiable(nextTasks));
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
    return _rebuild(
      terms: nextTerms,
      courses: nextCourses,
      meetingSeries: nextSeries,
      occurrences: nextOccurrences,
    );
  }

  /// Moves one materialized class while keeping its recurring series intact.
  /// Any unfinished study blocks are then recalculated around the new shape of
  /// the schedule; completed study history is never moved.
  AcademicSchedule moveOccurrence({
    required String occurrenceKey,
    required CivilDate date,
    required int startMinute,
    required int endMinute,
    required DateTime updatedAt,
    AcademicIdFactory idFactory = AcademicIds.create,
  }) {
    final occurrence = _adjustableOccurrence(occurrenceKey);
    final series = meetingSeriesById(occurrence.meetingSeriesId)!;
    final term = _termForCourseId(occurrence.courseId);
    if (term == null || !date.isWithin(term.startDate, term.endDate)) {
      throw ArgumentError('A moved class must stay inside its term');
    }
    if (startMinute < 0 ||
        startMinute >= 24 * 60 ||
        endMinute <= startMinute ||
        endMinute > 24 * 60) {
      throw ArgumentError('Class times must be within one day, start to end');
    }
    if (date == occurrence.date &&
        startMinute == occurrence.localStartMinute &&
        endMinute == occurrence.localEndMinute) {
      return this;
    }
    if (date == occurrence.originalDate &&
        startMinute == series.localStartMinute &&
        endMinute == series.localEndMinute) {
      if (!occurrence.userAdjusted) return this;
      return restoreOccurrence(
        occurrenceKey: occurrenceKey,
        updatedAt: updatedAt,
        idFactory: idFactory,
      );
    }
    final (start, end) = OccurrenceMaterializer.resolveInstants(
      date,
      startMinute,
      endMinute,
      series.timeZoneId,
    );
    final moved = occurrence.copyWith(
      date: date,
      startInstant: start,
      endInstant: end,
      localStartMinute: startMinute,
      localEndMinute: endMinute,
      state: OccurrenceState.moved,
      movedFrom: occurrence.movedFrom ?? occurrence.originalDate.toString(),
      userAdjusted: true,
      revision: occurrence.revision + 1,
      updatedAt: updatedAt.toUtc(),
      clearTombstonedAt: true,
    );
    return _withOccurrence(
      moved,
    ).reflowOpenStudyPlans(now: updatedAt, idFactory: idFactory);
  }

  /// Cancels only this class occurrence, not the weekly series.
  AcademicSchedule cancelOccurrence({
    required String occurrenceKey,
    required DateTime updatedAt,
    AcademicIdFactory idFactory = AcademicIds.create,
  }) {
    final occurrence = _adjustableOccurrence(occurrenceKey);
    if (occurrence.state == OccurrenceState.cancelled &&
        occurrence.userAdjusted) {
      return this;
    }
    final cancelled = occurrence.copyWith(
      state: OccurrenceState.cancelled,
      userAdjusted: true,
      revision: occurrence.revision + 1,
      updatedAt: updatedAt.toUtc(),
      clearTombstonedAt: true,
    );
    return _withOccurrence(
      cancelled,
    ).reflowOpenStudyPlans(now: updatedAt, idFactory: idFactory);
  }

  /// Restores a user-moved or user-cancelled class to the current recurring
  /// series date and time.
  AcademicSchedule restoreOccurrence({
    required String occurrenceKey,
    required DateTime updatedAt,
    AcademicIdFactory idFactory = AcademicIds.create,
  }) {
    final occurrence = occurrenceByKey(occurrenceKey);
    if (occurrence == null || !occurrence.userAdjusted) {
      throw ArgumentError.value(occurrenceKey, 'occurrenceKey');
    }
    final series = meetingSeriesById(occurrence.meetingSeriesId);
    if (series == null) {
      throw ArgumentError('The recurring class no longer exists');
    }
    final (start, end) = OccurrenceMaterializer.resolveInstants(
      occurrence.originalDate,
      series.localStartMinute,
      series.localEndMinute,
      series.timeZoneId,
    );
    final restored = occurrence.copyWith(
      date: occurrence.originalDate,
      startInstant: start,
      endInstant: end,
      localStartMinute: series.localStartMinute,
      localEndMinute: series.localEndMinute,
      kind: series.kind,
      place: series.place,
      timeZoneId: series.timeZoneId,
      reminders: series.reminders,
      state: OccurrenceState.scheduled,
      clearMovedFrom: true,
      userAdjusted: false,
      revision: occurrence.revision + 1,
      updatedAt: updatedAt.toUtc(),
      clearTombstonedAt: true,
    );
    return _withOccurrence(
      restored,
    ).reflowOpenStudyPlans(now: updatedAt, idFactory: idFactory);
  }

  /// Rebuilds every active plan from its existing preferences after the class
  /// grid changes. All unfinished blocks are replaced together so stale blocks
  /// from one plan cannot crowd out another; completed blocks stay immutable.
  AcademicSchedule reflowOpenStudyPlans({
    required DateTime now,
    AcademicIdFactory idFactory = AcademicIds.create,
  }) {
    final openWorkIds = <String>{
      for (final item in workItems)
        if (!item.completed && item.tombstonedAt == null) item.workId,
    };
    final plans =
        [
          for (final plan in studyPlans)
            if (openWorkIds.contains(plan.workId)) plan,
        ]..sort((left, right) {
          final leftWork = workItems.firstWhere(
            (item) => item.workId == left.workId,
          );
          final rightWork = workItems.firstWhere(
            (item) => item.workId == right.workId,
          );
          final due = _compareWorkItems(leftWork, rightWork);
          return due != 0 ? due : left.workId.compareTo(right.workId);
        });
    if (plans.isEmpty) return this;

    final replannedWorkIds = plans.map((plan) => plan.workId).toSet();
    var working = _rebuild(
      studyBlocks: [
        for (final block in studyBlocks)
          if (!replannedWorkIds.contains(block.workId) || block.completed)
            block,
      ],
    );
    for (final plan in plans) {
      final suggestion = working.suggestStudyBlocks(
        workId: plan.workId,
        totalMinutes: plan.totalMinutes,
        sessionMinutes: plan.sessionMinutes,
        dailyStartMinute: plan.dailyStartMinute,
        dailyEndMinute: plan.dailyEndMinute,
        now: now,
        idFactory: idFactory,
      );
      working = working.putStudyPlan(plan: plan, blocks: suggestion.blocks);
    }
    return working;
  }

  ClassOccurrence _adjustableOccurrence(String occurrenceKey) {
    final occurrence = occurrenceByKey(occurrenceKey);
    if (occurrence == null || !occurrence.canAdjust) {
      throw ArgumentError.value(occurrenceKey, 'occurrenceKey');
    }
    if (meetingSeriesById(occurrence.meetingSeriesId) == null) {
      throw ArgumentError('The recurring class no longer exists');
    }
    return occurrence;
  }

  AcademicTerm? _termForCourseId(String courseId) {
    final course = courseById(courseId);
    if (course == null) return null;
    return terms.where((term) => term.termId == course.termId).firstOrNull;
  }

  DaybookEvent _eventById(String eventId) {
    final found = events.where((event) => event.eventId == eventId).firstOrNull;
    if (found == null) throw ArgumentError.value(eventId, 'eventId');
    return found;
  }

  CivilDate _eventOriginalDate(DaybookEvent event, String occurrenceKey) {
    final existing = event.exceptions
        .where((exception) => exception.occurrenceKey == occurrenceKey)
        .firstOrNull;
    if (existing != null) return existing.originalDate;
    final prefix = '${event.eventId}@';
    if (!occurrenceKey.startsWith(prefix)) {
      throw ArgumentError.value(occurrenceKey, 'occurrenceKey');
    }
    try {
      final originalDate = CivilDate.parse(
        occurrenceKey.substring(prefix.length),
      );
      event.occurrenceFor(originalDate);
      return originalDate;
    } catch (_) {
      throw ArgumentError.value(occurrenceKey, 'occurrenceKey');
    }
  }

  List<DaybookEventException> _replaceEventException(
    DaybookEvent event,
    DaybookEventException replacement,
  ) => List.unmodifiable([
    for (final exception in event.exceptions)
      if (exception.originalDate != replacement.originalDate) exception,
    replacement,
  ]);

  /// The single reconstruction path for mutations. Keeping all durable lists
  /// here prevents academic edits from accidentally dropping general entries.
  AcademicSchedule _rebuild({
    List<AcademicTerm>? terms,
    List<AcademicCourse>? courses,
    List<MeetingSeries>? meetingSeries,
    List<ClassOccurrence>? occurrences,
    List<AcademicWorkItem>? workItems,
    List<AcademicStudyPlan>? studyPlans,
    List<AcademicStudyBlock>? studyBlocks,
    List<DaybookEvent>? events,
    List<DaybookTask>? tasks,
  }) => AcademicSchedule(
    terms: terms ?? this.terms,
    courses: courses ?? this.courses,
    meetingSeries: meetingSeries ?? this.meetingSeries,
    occurrences: occurrences ?? this.occurrences,
    workItems: workItems ?? this.workItems,
    studyPlans: studyPlans ?? this.studyPlans,
    studyBlocks: studyBlocks ?? this.studyBlocks,
    events: events ?? this.events,
    tasks: tasks ?? this.tasks,
  );

  AcademicSchedule _withOccurrence(ClassOccurrence replacement) {
    final nextOccurrences = _replaceById(
      occurrences,
      replacement,
      (value) => value.occurrenceKey,
    ).toList()..sort(_compareOccurrences);
    return _rebuild(occurrences: nextOccurrences);
  }

  AcademicSchedule putWorkItem(AcademicWorkItem item) {
    final course = courseById(item.courseId);
    if (course == null) {
      throw ArgumentError('Academic work requires an existing course');
    }
    final term = terms
        .where((term) => term.termId == course.termId)
        .firstOrNull;
    if (term == null || !item.dueDate.isWithin(term.startDate, term.endDate)) {
      throw ArgumentError('Academic work must stay inside its course term');
    }
    final nextWorkItems = _replaceById(
      workItems,
      item,
      (value) => value.workId,
    ).toList()..sort(_compareWorkItems);
    return _rebuild(workItems: nextWorkItems);
  }

  AcademicSchedule putStudyPlan({
    required AcademicStudyPlan plan,
    required List<AcademicStudyBlock> blocks,
  }) {
    final work = workItems
        .where((item) => item.workId == plan.workId)
        .firstOrNull;
    if (work == null || work.tombstonedAt != null || work.completed) {
      throw ArgumentError('Study plans require an open course item');
    }
    if (blocks.any((block) => block.workId != plan.workId)) {
      throw ArgumentError('Study blocks must belong to their plan');
    }
    final completed = [
      for (final block in studyBlocksFor(plan.workId))
        if (block.completed) block,
    ];
    final replacementIds = blocks.map((block) => block.studyBlockId).toSet();
    if (replacementIds.length != blocks.length ||
        completed.any((block) => replacementIds.contains(block.studyBlockId))) {
      throw ArgumentError('Study block IDs must stay unique');
    }
    final nextPlans = _replaceById(studyPlans, plan, (value) => value.workId);
    final nextBlocks = <AcademicStudyBlock>[
      for (final block in studyBlocks)
        if (block.workId != plan.workId) block,
      ...completed,
      ...blocks,
    ]..sort(_compareStudyBlocks);
    return _rebuild(studyPlans: nextPlans, studyBlocks: nextBlocks);
  }

  AcademicSchedule setStudyBlockCompleted({
    required String studyBlockId,
    required bool completed,
    required DateTime updatedAt,
  }) {
    final block = studyBlocks
        .where((item) => item.studyBlockId == studyBlockId)
        .firstOrNull;
    if (block == null) throw ArgumentError.value(studyBlockId, 'studyBlockId');
    final nextBlocks = _replaceById(
      studyBlocks,
      block.withCompletion(completed: completed, updatedAt: updatedAt),
      (value) => value.studyBlockId,
    ).toList()..sort(_compareStudyBlocks);
    return _rebuild(studyBlocks: nextBlocks);
  }

  AcademicSchedule setWorkItemCompleted({
    required String workId,
    required bool completed,
    required DateTime updatedAt,
  }) {
    final item = workItems.where((item) => item.workId == workId).firstOrNull;
    if (item == null) throw ArgumentError.value(workId, 'workId');
    final next = putWorkItem(
      item.withCompletion(completed: completed, updatedAt: updatedAt),
    );
    if (!completed) return next;
    return next._rebuild(
      studyBlocks: [
        for (final block in next.studyBlocks)
          if (block.workId != workId || block.completed) block,
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'schema': currentSchema,
    'terms': [for (final term in terms) term.toJson()],
    'courses': [for (final course in courses) course.toJson()],
    'meetingSeries': [for (final series in meetingSeries) series.toJson()],
    'occurrences': [for (final occurrence in occurrences) occurrence.toJson()],
    'workItems': [for (final item in workItems) item.toJson()],
    'studyPlans': [for (final plan in studyPlans) plan.toJson()],
    'studyBlocks': [for (final block in studyBlocks) block.toJson()],
    'events': [for (final event in events) event.toJson()],
    'tasks': [for (final task in tasks) task.toJson()],
  };

  void _validateGraph() {
    final termIds = terms.map((term) => term.termId).toSet();
    final courseIds = courses.map((course) => course.courseId).toSet();
    final seriesIds = meetingSeries
        .map((series) => series.meetingSeriesId)
        .toSet();
    final workIds = workItems.map((item) => item.workId).toSet();
    final studyPlanWorkIds = studyPlans.map((item) => item.workId).toSet();
    final studyBlockIds = studyBlocks.map((item) => item.studyBlockId).toSet();
    final eventIds = events.map((item) => item.eventId).toSet();
    final taskIds = tasks.map((item) => item.taskId).toSet();
    if (termIds.length != terms.length ||
        courseIds.length != courses.length ||
        seriesIds.length != meetingSeries.length ||
        workIds.length != workItems.length ||
        studyPlanWorkIds.length != studyPlans.length ||
        studyBlockIds.length != studyBlocks.length ||
        occurrences.map((item) => item.occurrenceKey).toSet().length !=
            occurrences.length) {
      throw const FormatException('Academic schedule IDs must be unique');
    }
    if (eventIds.length != events.length || taskIds.length != tasks.length) {
      throw const FormatException('General schedule IDs must be unique');
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
    for (final item in workItems) {
      if (!courseIds.contains(item.courseId)) {
        throw const FormatException('Academic work has no course');
      }
    }
    for (final plan in studyPlans) {
      if (!workIds.contains(plan.workId)) {
        throw const FormatException('Study plan has no course item');
      }
    }
    for (final block in studyBlocks) {
      if (!workIds.contains(block.workId)) {
        throw const FormatException('Study block has no course item');
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

int _compareDaybookOccurrences(
  DaybookEventOccurrence left,
  DaybookEventOccurrence right,
) {
  final date = left.startDate.compareTo(right.startDate);
  if (date != 0) return date;
  final minute = (left.startMinute ?? -1).compareTo(right.startMinute ?? -1);
  if (minute != 0) return minute;
  return left.occurrenceKey.compareTo(right.occurrenceKey);
}

int _compareDaybookEvents(DaybookEvent left, DaybookEvent right) {
  final date = left.startDate.compareTo(right.startDate);
  if (date != 0) return date;
  final minute = (left.startMinute ?? -1).compareTo(right.startMinute ?? -1);
  if (minute != 0) return minute;
  return left.eventId.compareTo(right.eventId);
}

int _compareDaybookTasks(DaybookTask left, DaybookTask right) {
  final date = left.dueDate.compareTo(right.dueDate);
  if (date != 0) return date;
  final minute = (left.dueMinute ?? 24 * 60).compareTo(
    right.dueMinute ?? 24 * 60,
  );
  if (minute != 0) return minute;
  return left.taskId.compareTo(right.taskId);
}

int _compareWorkItems(AcademicWorkItem a, AcademicWorkItem b) {
  final date = a.dueDate.compareTo(b.dueDate);
  if (date != 0) return date;
  final completion = (a.completed ? 1 : 0).compareTo(b.completed ? 1 : 0);
  if (completion != 0) return completion;
  final minute = (a.dueMinute ?? 24 * 60).compareTo(b.dueMinute ?? 24 * 60);
  if (minute != 0) return minute;
  return a.workId.compareTo(b.workId);
}

int _compareStudyBlocks(AcademicStudyBlock a, AcademicStudyBlock b) {
  final date = a.date.compareTo(b.date);
  if (date != 0) return date;
  final time = a.startMinute.compareTo(b.startMinute);
  if (time != 0) return time;
  return a.studyBlockId.compareTo(b.studyBlockId);
}

int _ceilToQuarterHour(int minute) => ((minute + 14) ~/ 15) * 15;

List<(int, int)> _mergeMinuteRanges(Iterable<(int, int)> ranges) {
  final sorted = [
    for (final range in ranges)
      if (range.$2 > range.$1) range,
  ]..sort((left, right) => left.$1.compareTo(right.$1));
  final merged = <(int, int)>[];
  for (final range in sorted) {
    if (merged.isEmpty || range.$1 > merged.last.$2) {
      merged.add(range);
      continue;
    }
    final prior = merged.removeLast();
    merged.add((prior.$1, max(prior.$2, range.$2)));
  }
  return merged;
}

List<(int, int)> _availableMinuteRanges(
  int windowStart,
  int windowEnd,
  Iterable<(int, int)> occupied,
) {
  final available = <(int, int)>[];
  var cursor = windowStart;
  for (final busy in _mergeMinuteRanges(occupied)) {
    if (busy.$2 <= windowStart || busy.$1 >= windowEnd) continue;
    final busyStart = max(windowStart, busy.$1);
    if (busyStart > cursor) available.add((cursor, busyStart));
    cursor = max(cursor, min(windowEnd, busy.$2));
    if (cursor >= windowEnd) break;
  }
  if (cursor < windowEnd) available.add((cursor, windowEnd));
  return available;
}

List<int> _studySessionDurations(int totalMinutes, int sessionMinutes) {
  final durations = <int>[];
  var remaining = totalMinutes;
  while (remaining > 0) {
    final duration = min(sessionMinutes, remaining);
    if (duration < 15) {
      if (durations.isNotEmpty && durations.last + duration <= 4 * 60) {
        durations[durations.length - 1] += duration;
      }
      break;
    }
    durations.add(duration);
    remaining -= duration;
  }
  return durations;
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
