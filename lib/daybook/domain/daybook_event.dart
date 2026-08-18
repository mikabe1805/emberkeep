import 'civil_date.dart';
import 'daybook_place.dart';

final class WeeklyEventRule {
  WeeklyEventRule({
    required Set<int> weekdays,
    this.intervalWeeks = 1,
    this.endsOn,
  }) : weekdays = Set.unmodifiable(weekdays) {
    if (this.weekdays.isEmpty ||
        this.weekdays.any(
          (weekday) => weekday < DateTime.monday || weekday > DateTime.sunday,
        )) {
      throw ArgumentError.value(weekdays, 'weekdays');
    }
    if (intervalWeeks < 1) {
      throw ArgumentError.value(intervalWeeks, 'intervalWeeks');
    }
  }

  factory WeeklyEventRule.fromJson(Map<String, dynamic> json) =>
      WeeklyEventRule(
        weekdays: {
          for (final weekday in json['weekdays'] as List) weekday as int,
        },
        intervalWeeks: json['intervalWeeks'] as int? ?? 1,
        endsOn: json['endsOn'] == null
            ? null
            : CivilDate.parse(json['endsOn'] as String),
      );

  final Set<int> weekdays;
  final int intervalWeeks;
  final CivilDate? endsOn;

  WeeklyEventRule copyWith({
    Set<int>? weekdays,
    int? intervalWeeks,
    Object? endsOn = _unset,
  }) => WeeklyEventRule(
    weekdays: weekdays ?? this.weekdays,
    intervalWeeks: intervalWeeks ?? this.intervalWeeks,
    endsOn: identical(endsOn, _unset) ? this.endsOn : endsOn as CivilDate?,
  );

  Map<String, dynamic> toJson() => {
    'weekdays': weekdays.toList()..sort(),
    'intervalWeeks': intervalWeeks,
    if (endsOn != null) 'endsOn': endsOn.toString(),
  };
}

enum DaybookEventOccurrenceState { scheduled, moved, cancelled }

final class DaybookEventException {
  DaybookEventException({
    required String occurrenceKey,
    required this.originalDate,
    required this.state,
    this.movedStartDate,
    this.movedEndDate,
    this.movedStartMinute,
    this.movedEndMinute,
    DateTime? tombstonedAt,
    required DateTime updatedAt,
  }) : occurrenceKey = _requiredText(occurrenceKey, 'occurrenceKey'),
       tombstonedAt = tombstonedAt?.toUtc(),
       updatedAt = updatedAt.toUtc() {
    final hasAnyMovedValue =
        movedStartDate != null ||
        movedEndDate != null ||
        movedStartMinute != null ||
        movedEndMinute != null;
    if (state == DaybookEventOccurrenceState.moved) {
      if (movedStartDate == null || movedEndDate == null) {
        throw ArgumentError(
          'A moved occurrence requires moved start and end dates',
        );
      }
      if (movedEndDate!.compareTo(movedStartDate!) < 0) {
        throw ArgumentError('A moved occurrence must not end before it starts');
      }
      if ((movedStartMinute == null) != (movedEndMinute == null)) {
        throw ArgumentError('Moved times must be supplied together');
      }
      if (movedStartMinute != null) {
        _validateMinute(movedStartMinute!, 'movedStartMinute');
        _validateMinute(movedEndMinute!, 'movedEndMinute');
        if (movedStartDate == movedEndDate &&
            movedEndMinute! <= movedStartMinute!) {
          throw ArgumentError(
            'A moved occurrence must have a positive duration',
          );
        }
      }
    } else if (hasAnyMovedValue) {
      throw ArgumentError('Only moved occurrences may have moved values');
    }
  }

  factory DaybookEventException.fromJson(Map<String, dynamic> json) =>
      DaybookEventException(
        occurrenceKey: json['occurrenceKey'] as String,
        originalDate: CivilDate.parse(json['originalDate'] as String),
        state: DaybookEventOccurrenceState.values.byName(
          json['state'] as String,
        ),
        movedStartDate: json['movedStartDate'] == null
            ? null
            : CivilDate.parse(json['movedStartDate'] as String),
        movedEndDate: json['movedEndDate'] == null
            ? null
            : CivilDate.parse(json['movedEndDate'] as String),
        movedStartMinute: json['movedStartMinute'] as int?,
        movedEndMinute: json['movedEndMinute'] as int?,
        tombstonedAt: _dateTimeFromJson(json['tombstonedAt']),
        updatedAt: _dateTimeFromJson(json['updatedAt'])!,
      );

  final String occurrenceKey;
  final CivilDate originalDate;
  final DaybookEventOccurrenceState state;
  final CivilDate? movedStartDate;
  final CivilDate? movedEndDate;
  final int? movedStartMinute;
  final int? movedEndMinute;
  final DateTime? tombstonedAt;
  final DateTime updatedAt;

  DaybookEventException copyWith({
    String? occurrenceKey,
    CivilDate? originalDate,
    DaybookEventOccurrenceState? state,
    Object? movedStartDate = _unset,
    Object? movedEndDate = _unset,
    Object? movedStartMinute = _unset,
    Object? movedEndMinute = _unset,
    Object? tombstonedAt = _unset,
    DateTime? updatedAt,
  }) => DaybookEventException(
    occurrenceKey: occurrenceKey ?? this.occurrenceKey,
    originalDate: originalDate ?? this.originalDate,
    state: state ?? this.state,
    movedStartDate: identical(movedStartDate, _unset)
        ? this.movedStartDate
        : movedStartDate as CivilDate?,
    movedEndDate: identical(movedEndDate, _unset)
        ? this.movedEndDate
        : movedEndDate as CivilDate?,
    movedStartMinute: identical(movedStartMinute, _unset)
        ? this.movedStartMinute
        : movedStartMinute as int?,
    movedEndMinute: identical(movedEndMinute, _unset)
        ? this.movedEndMinute
        : movedEndMinute as int?,
    tombstonedAt: identical(tombstonedAt, _unset)
        ? this.tombstonedAt
        : tombstonedAt as DateTime?,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'occurrenceKey': occurrenceKey,
    'originalDate': originalDate.toString(),
    'state': state.name,
    if (movedStartDate != null) 'movedStartDate': movedStartDate.toString(),
    if (movedEndDate != null) 'movedEndDate': movedEndDate.toString(),
    if (movedStartMinute != null) 'movedStartMinute': movedStartMinute,
    if (movedEndMinute != null) 'movedEndMinute': movedEndMinute,
    if (tombstonedAt != null) 'tombstonedAt': tombstonedAt!.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

final class DaybookEventOccurrence {
  const DaybookEventOccurrence({
    required this.eventId,
    required this.occurrenceKey,
    required this.originalDate,
    required this.startDate,
    required this.endDate,
    required this.allDay,
    this.startMinute,
    this.endMinute,
    required this.state,
  });

  factory DaybookEventOccurrence.fromJson(Map<String, dynamic> json) =>
      DaybookEventOccurrence(
        eventId: json['eventId'] as String,
        occurrenceKey: json['occurrenceKey'] as String,
        originalDate: CivilDate.parse(json['originalDate'] as String),
        startDate: CivilDate.parse(json['startDate'] as String),
        endDate: CivilDate.parse(json['endDate'] as String),
        allDay: json['allDay'] as bool,
        startMinute: json['startMinute'] as int?,
        endMinute: json['endMinute'] as int?,
        state: DaybookEventOccurrenceState.values.byName(
          json['state'] as String,
        ),
      );

  final String eventId;
  final String occurrenceKey;
  final CivilDate originalDate;
  final CivilDate startDate;
  final CivilDate endDate;
  final bool allDay;
  final int? startMinute;
  final int? endMinute;
  final DaybookEventOccurrenceState state;

  DaybookEventOccurrence copyWith({
    String? eventId,
    String? occurrenceKey,
    CivilDate? originalDate,
    CivilDate? startDate,
    CivilDate? endDate,
    bool? allDay,
    Object? startMinute = _unset,
    Object? endMinute = _unset,
    DaybookEventOccurrenceState? state,
  }) => DaybookEventOccurrence(
    eventId: eventId ?? this.eventId,
    occurrenceKey: occurrenceKey ?? this.occurrenceKey,
    originalDate: originalDate ?? this.originalDate,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    allDay: allDay ?? this.allDay,
    startMinute: identical(startMinute, _unset)
        ? this.startMinute
        : startMinute as int?,
    endMinute: identical(endMinute, _unset)
        ? this.endMinute
        : endMinute as int?,
    state: state ?? this.state,
  );

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'occurrenceKey': occurrenceKey,
    'originalDate': originalDate.toString(),
    'startDate': startDate.toString(),
    'endDate': endDate.toString(),
    'allDay': allDay,
    if (startMinute != null) 'startMinute': startMinute,
    if (endMinute != null) 'endMinute': endMinute,
    'state': state.name,
  };
}

final class DaybookEvent {
  DaybookEvent({
    required String eventId,
    required String title,
    required this.startDate,
    required this.endDate,
    required String timeZoneId,
    required this.allDay,
    this.startMinute,
    this.endMinute,
    String? notes,
    this.place,
    this.weeklyRule,
    List<DaybookEventException> exceptions = const [],
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : eventId = _requiredText(eventId, 'eventId'),
       title = _requiredText(title, 'title'),
       timeZoneId = _requiredText(timeZoneId, 'timeZoneId'),
       notes = _optionalText(notes),
       exceptions = List.unmodifiable(exceptions),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc() {
    _validateRange(
      startDate: startDate,
      endDate: endDate,
      allDay: allDay,
      startMinute: startMinute,
      endMinute: endMinute,
    );
    if (weeklyRule?.endsOn != null &&
        weeklyRule!.endsOn!.compareTo(startDate) < 0) {
      throw ArgumentError('A weekly event cannot end before it begins');
    }
    final keys = <String>{};
    final originalDates = <CivilDate>{};
    for (final exception in this.exceptions) {
      if (!keys.add(exception.occurrenceKey)) {
        throw ArgumentError('Event exception keys must be unique');
      }
      if (!originalDates.add(exception.originalDate)) {
        throw ArgumentError('Event exceptions must have unique original dates');
      }
      _validateException(exception);
    }
  }

  factory DaybookEvent.fromJson(Map<String, dynamic> json) => DaybookEvent(
    eventId: json['eventId'] as String,
    title: json['title'] as String,
    startDate: CivilDate.parse(json['startDate'] as String),
    endDate: CivilDate.parse(json['endDate'] as String),
    timeZoneId: json['timeZoneId'] as String,
    allDay: json['allDay'] as bool,
    startMinute: json['startMinute'] as int?,
    endMinute: json['endMinute'] as int?,
    notes: json['notes'] as String?,
    place: json['place'] == null
        ? null
        : DaybookPlace.fromJson((json['place'] as Map).cast<String, dynamic>()),
    weeklyRule: json['weeklyRule'] == null
        ? null
        : WeeklyEventRule.fromJson(
            (json['weeklyRule'] as Map).cast<String, dynamic>(),
          ),
    exceptions: [
      for (final exception in json['exceptions'] as List? ?? const [])
        DaybookEventException.fromJson(
          (exception as Map).cast<String, dynamic>(),
        ),
    ],
    createdAt: _dateTimeFromJson(json['createdAt'])!,
    updatedAt: _dateTimeFromJson(json['updatedAt'])!,
  );

  final String eventId;
  final String title;
  final CivilDate startDate;
  final CivilDate endDate;
  final String timeZoneId;
  final bool allDay;
  final int? startMinute;
  final int? endMinute;
  final String? notes;
  final DaybookPlace? place;
  final WeeklyEventRule? weeklyRule;
  final List<DaybookEventException> exceptions;
  final DateTime createdAt;
  final DateTime updatedAt;

  DaybookEvent copyWith({
    String? eventId,
    String? title,
    CivilDate? startDate,
    CivilDate? endDate,
    String? timeZoneId,
    bool? allDay,
    Object? startMinute = _unset,
    Object? endMinute = _unset,
    Object? notes = _unset,
    Object? place = _unset,
    Object? weeklyRule = _unset,
    List<DaybookEventException>? exceptions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DaybookEvent(
    eventId: eventId ?? this.eventId,
    title: title ?? this.title,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    timeZoneId: timeZoneId ?? this.timeZoneId,
    allDay: allDay ?? this.allDay,
    startMinute: identical(startMinute, _unset)
        ? this.startMinute
        : startMinute as int?,
    endMinute: identical(endMinute, _unset)
        ? this.endMinute
        : endMinute as int?,
    notes: identical(notes, _unset) ? this.notes : notes as String?,
    place: identical(place, _unset) ? this.place : place as DaybookPlace?,
    weeklyRule: identical(weeklyRule, _unset)
        ? this.weeklyRule
        : weeklyRule as WeeklyEventRule?,
    exceptions: exceptions ?? this.exceptions,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  DaybookEventOccurrence occurrenceFor(CivilDate originalDate) {
    if (!_includes(originalDate)) {
      throw ArgumentError.value(originalDate, 'originalDate');
    }
    final exception = exceptions
        .where((item) => item.originalDate == originalDate)
        .firstOrNull;
    if (exception == null ||
        exception.state == DaybookEventOccurrenceState.scheduled) {
      return _scheduledOccurrence(originalDate);
    }
    if (exception.state == DaybookEventOccurrenceState.cancelled) {
      return _scheduledOccurrence(
        originalDate,
        state: DaybookEventOccurrenceState.cancelled,
      );
    }
    return DaybookEventOccurrence(
      eventId: eventId,
      occurrenceKey: exception.occurrenceKey,
      originalDate: originalDate,
      startDate: exception.movedStartDate!,
      endDate: exception.movedEndDate!,
      allDay: allDay,
      startMinute: exception.movedStartMinute,
      endMinute: exception.movedEndMinute,
      state: DaybookEventOccurrenceState.moved,
    );
  }

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'title': title,
    'startDate': startDate.toString(),
    'endDate': endDate.toString(),
    'timeZoneId': timeZoneId,
    'allDay': allDay,
    if (startMinute != null) 'startMinute': startMinute,
    if (endMinute != null) 'endMinute': endMinute,
    if (notes != null) 'notes': notes,
    if (place != null) 'place': place!.toJson(),
    if (weeklyRule != null) 'weeklyRule': weeklyRule!.toJson(),
    'exceptions': [for (final exception in exceptions) exception.toJson()],
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  DaybookEventOccurrence _scheduledOccurrence(
    CivilDate originalDate, {
    DaybookEventOccurrenceState state = DaybookEventOccurrenceState.scheduled,
  }) {
    final dayOffset = _daysBetween(startDate, endDate);
    return DaybookEventOccurrence(
      eventId: eventId,
      occurrenceKey: _occurrenceKey(originalDate),
      originalDate: originalDate,
      startDate: originalDate,
      endDate: originalDate.addDays(dayOffset),
      allDay: allDay,
      startMinute: startMinute,
      endMinute: endMinute,
      state: state,
    );
  }

  bool _includes(CivilDate date) {
    if (weeklyRule == null) return date == startDate;
    if (date.compareTo(startDate) < 0 ||
        (weeklyRule!.endsOn != null &&
            date.compareTo(weeklyRule!.endsOn!) > 0) ||
        !weeklyRule!.weekdays.contains(date.weekday)) {
      return false;
    }
    final weekDelta = _daysBetween(
      startDate.startOfWeek(DateTime.monday),
      date.startOfWeek(DateTime.monday),
    );
    return weekDelta % (7 * weeklyRule!.intervalWeeks) == 0;
  }

  void _validateException(DaybookEventException exception) {
    if (weeklyRule == null && exception.originalDate != startDate) {
      throw ArgumentError(
        'A one-time event can only change its own occurrence',
      );
    }
    if (weeklyRule != null && !_includes(exception.originalDate)) {
      throw ArgumentError('An exception must belong to the weekly event');
    }
    if (exception.state != DaybookEventOccurrenceState.moved) return;
    _validateRange(
      startDate: exception.movedStartDate!,
      endDate: exception.movedEndDate!,
      allDay: allDay,
      startMinute: exception.movedStartMinute,
      endMinute: exception.movedEndMinute,
    );
  }

  String _occurrenceKey(CivilDate originalDate) =>
      '$eventId/${originalDate.toString()}';
}

void _validateRange({
  required CivilDate startDate,
  required CivilDate endDate,
  required bool allDay,
  required int? startMinute,
  required int? endMinute,
}) {
  if (allDay) {
    if (endDate.compareTo(startDate) <= 0 ||
        startMinute != null ||
        endMinute != null) {
      throw ArgumentError(
        'An all-day event needs a positive date range and no times',
      );
    }
    return;
  }
  if (startMinute == null || endMinute == null) {
    throw ArgumentError('A timed event requires both times');
  }
  _validateMinute(startMinute, 'startMinute');
  _validateMinute(endMinute, 'endMinute');
  final daySpan = _daysBetween(startDate, endDate);
  if (daySpan < 0 || daySpan > 1) {
    throw ArgumentError(
      'A timed event may only end on its start date or the next day',
    );
  }
  if (daySpan == 0 && endMinute <= startMinute) {
    throw ArgumentError('A timed event must have a positive duration');
  }
}

int _daysBetween(CivilDate start, CivilDate end) =>
    end.dateArithmeticValue.difference(start.dateArithmeticValue).inDays;

void _validateMinute(int value, String name) {
  if (value < 0 || value >= 24 * 60) {
    throw ArgumentError.value(value, name, 'Must be within a civil day');
  }
}

DateTime? _dateTimeFromJson(Object? value) =>
    value is String ? DateTime.parse(value).toUtc() : null;

String _requiredText(String value, String name) {
  final clean = value.trim();
  if (clean.isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be blank');
  }
  return clean;
}

String? _optionalText(String? value) {
  final clean = value?.trim();
  return clean == null || clean.isEmpty ? null : clean;
}

const _Unset _unset = _Unset();

final class _Unset {
  const _Unset();
}
