import '../domain/academic_schedule.dart';

final class AcademicReminderNotice {
  const AcademicReminderNotice({
    required this.whenUtc,
    required this.title,
    required this.body,
  });

  final DateTime whenUtc;
  final String title;
  final String body;
}

/// Projects enabled class reminders into absolute instants without asking for
/// permission or scheduling anything. Keeping this pure makes DST, cancelled
/// classes, and privacy boundaries independently testable.
List<AcademicReminderNotice> projectAcademicReminderNotices({
  required AcademicSchedule schedule,
  required DateTime now,
}) {
  final nowUtc = now.toUtc();
  final notices = <AcademicReminderNotice>[];
  final seen = <String>{};
  for (final occurrence in schedule.occurrences) {
    if (occurrence.state == OccurrenceState.cancelled ||
        occurrence.tombstonedAt != null) {
      continue;
    }
    final course = schedule.courseById(occurrence.courseId);
    if (course == null || course.archived) continue;
    final series = schedule.meetingSeriesById(occurrence.meetingSeriesId);
    final reminders = occurrence.reminders.isNotEmpty
        ? occurrence.reminders
        : series?.reminders ?? const <AcademicReminder>[];
    for (final reminder in reminders) {
      if (!reminder.enabled) continue;
      final when = occurrence.startInstant.toUtc().subtract(
        Duration(minutes: reminder.offsetMinutes),
      );
      if (!when.isAfter(nowUtc)) continue;
      final identity =
          '${occurrence.occurrenceKey}|${reminder.reminderId}|${when.toIso8601String()}';
      if (!seen.add(identity)) continue;
      notices.add(
        AcademicReminderNotice(
          whenUtc: when,
          title: reminder.customTitle?.trim().isNotEmpty == true
              ? reminder.customTitle!.trim()
              : 'Class in ${reminder.offsetMinutes} minutes · ${course.code}',
          body: reminder.customBody?.trim().isNotEmpty == true
              ? reminder.customBody!.trim()
              : course.title,
        ),
      );
    }
  }
  notices.sort((a, b) => a.whenUtc.compareTo(b.whenUtc));
  return List.unmodifiable(notices);
}
