/// The class-reminder choice offered once classes are added (from a file, a
/// link, or typed in). Off until the student turns it on; turning it on is
/// the only thing that asks for notification permission.
library;

import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';

/// Minutes before a class that a reminder can come.
const classReminderOffsets = <int>[10, 15, 30];

/// One enabled reminder [offsetMinutes] before each meeting of
/// [meetingSeriesId], with the same stable ID the Room of Days importer gives
/// it, or no reminders when [offsetMinutes] is null.
List<AcademicReminder> classReminderRules(
  String meetingSeriesId,
  int? offsetMinutes,
) {
  if (offsetMinutes == null) return const <AcademicReminder>[];
  if (!classReminderOffsets.contains(offsetMinutes)) {
    throw ArgumentError.value(offsetMinutes, 'offsetMinutes');
  }
  return [
    AcademicReminder(
      reminderId: _stableId('reminder', '$meetingSeriesId|$offsetMinutes'),
      enabled: true,
      offsetMinutes: offsetMinutes,
    ),
  ];
}

/// Turns class reminders on ([offsetMinutes]) or off (null) for every
/// meeting of [meetingSeriesIds], moved meetings included.
AcademicSchedule withClassReminders(
  AcademicSchedule schedule,
  Iterable<String> meetingSeriesIds, {
  required int? offsetMinutes,
  required DateTime updatedAt,
}) => schedule.withMeetingReminders({
  for (final id in meetingSeriesIds) id: classReminderRules(id, offsetMinutes),
}, updatedAt: updatedAt);

/// The reminder offset every one of [meetingSeriesIds] already shares, or
/// null when any of them has no enabled reminder (or they disagree).
int? classReminderOffsetOf(
  AcademicSchedule schedule,
  Iterable<String> meetingSeriesIds,
) {
  int? shared;
  var any = false;
  for (final id in meetingSeriesIds) {
    final series = schedule.meetingSeriesById(id);
    if (series == null) continue;
    final enabled = series.reminders.where((rule) => rule.enabled).toList();
    if (enabled.isEmpty) return null;
    final offset = enabled.first.offsetMinutes;
    if (shared != null && shared != offset) return null;
    shared = offset;
    any = true;
  }
  return any ? shared : null;
}

/// The meeting series an import wrote into [after]: new ones and the ones it
/// refreshed. Untouched series keep their identity through every schedule
/// change, so identity is the honest test.
Set<String> meetingSeriesWrittenBetween(
  AcademicSchedule before,
  AcademicSchedule after,
) {
  final prior = {
    for (final series in before.meetingSeries) series.meetingSeriesId: series,
  };
  return {
    for (final series in after.meetingSeries)
      if (series.tombstonedAt == null &&
          !identical(prior[series.meetingSeriesId], series))
        series.meetingSeriesId,
  };
}

/// FNV-1a, the same scheme the Room of Days importer uses for stable IDs.
String _stableId(String kind, String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return '${kind}_${hash.toRadixString(16).padLeft(8, '0')}';
}
