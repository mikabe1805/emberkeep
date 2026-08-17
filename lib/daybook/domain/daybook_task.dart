import 'civil_date.dart';
import 'daybook_place.dart';

final class DaybookTask {
  DaybookTask({
    required String taskId,
    required String title,
    required this.dueDate,
    int? dueMinute,
    String? notes,
    this.place,
    DateTime? completedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : taskId = _requiredText(taskId, 'taskId'),
       title = _requiredText(title, 'title'),
       dueMinute = dueMinute,
       notes = _optionalText(notes),
       completedAt = completedAt?.toUtc(),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc() {
    if (dueMinute != null && (dueMinute < 0 || dueMinute >= 24 * 60)) {
      throw ArgumentError.value(dueMinute, 'dueMinute');
    }
  }

  factory DaybookTask.fromJson(Map<String, dynamic> json) => DaybookTask(
    taskId: json['taskId'] as String,
    title: json['title'] as String,
    dueDate: CivilDate.parse(json['dueDate'] as String),
    dueMinute: json['dueMinute'] as int?,
    notes: json['notes'] as String?,
    place: json['place'] == null
        ? null
        : DaybookPlace.fromJson((json['place'] as Map).cast<String, dynamic>()),
    completedAt: _dateTimeFromJson(json['completedAt']),
    createdAt: _dateTimeFromJson(json['createdAt'])!,
    updatedAt: _dateTimeFromJson(json['updatedAt'])!,
  );

  final String taskId;
  final String title;
  final CivilDate dueDate;
  final int? dueMinute;
  final String? notes;
  final DaybookPlace? place;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get completed => completedAt != null;

  DaybookTask complete({required DateTime at}) =>
      copyWith(completedAt: at, updatedAt: at);

  DaybookTask undoCompletion({DateTime? at}) =>
      copyWith(completedAt: null, updatedAt: at ?? updatedAt);

  DaybookTask copyWith({
    String? taskId,
    String? title,
    CivilDate? dueDate,
    Object? dueMinute = _unset,
    Object? notes = _unset,
    Object? place = _unset,
    Object? completedAt = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DaybookTask(
    taskId: taskId ?? this.taskId,
    title: title ?? this.title,
    dueDate: dueDate ?? this.dueDate,
    dueMinute: identical(dueMinute, _unset)
        ? this.dueMinute
        : dueMinute as int?,
    notes: identical(notes, _unset) ? this.notes : notes as String?,
    place: identical(place, _unset) ? this.place : place as DaybookPlace?,
    completedAt: identical(completedAt, _unset)
        ? this.completedAt
        : completedAt as DateTime?,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'title': title,
    'dueDate': dueDate.toString(),
    if (dueMinute != null) 'dueMinute': dueMinute,
    if (notes != null) 'notes': notes,
    if (place != null) 'place': place!.toJson(),
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
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
