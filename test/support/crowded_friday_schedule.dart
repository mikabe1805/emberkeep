import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';

/// A Fall 2026 term whose only class day is Friday (2026-10-09 and every
/// Friday after), holding one meeting per entry of [kinds] (`lecture`, `lab`,
/// `recitation`, `office hours`), hourly from 8:00 and 50 minutes each, from
/// 8:00 to 19:50 and then doubling up. Each is its own course ("Course A",
/// "Course B"...), so labels and codes differ. [kinds] must not be empty (an
/// empty calendar does not import).
AcademicSchedule crowdedFridaySchedule(
  List<String> kinds, {
  String title = 'Course',
}) {
  final out = StringBuffer('BEGIN:VCALENDAR\nVERSION:2.0\n');
  for (var i = 0; i < kinds.length; i++) {
    final hour = (8 + i % 12).toString().padLeft(2, '0');
    final name = '$title ${String.fromCharCode(65 + i % 26)}';
    out
      ..write('BEGIN:VEVENT\nUID:crowd-$i@test\n')
      ..write('DTSTART;TZID=America/New_York:20261009T${hour}0000\n')
      ..write('DTEND;TZID=America/New_York:20261009T${hour}5000\n')
      ..write('RRULE:FREQ=WEEKLY;BYDAY=FR;UNTIL=20261211T045959Z\n')
      ..write('SUMMARY:$name\n')
      ..write('LOCATION:EE-${100 + i}\\, Busch Campus\n')
      ..write('X-ROOM-OF-DAYS-TERM:Fall 2026\n')
      ..write('X-ROOM-OF-DAYS-TERM-START:2026-09-01\n')
      ..write('X-ROOM-OF-DAYS-TERM-END:2026-12-10\n')
      ..write('X-ROOM-OF-DAYS-COURSE-CODE:14:332:${300 + i}\n')
      ..write('X-ROOM-OF-DAYS-COURSE-TITLE:$name\n')
      ..write('X-ROOM-OF-DAYS-SECTION:01\n')
      ..write('X-ROOM-OF-DAYS-MEETING-KIND:${kinds[i]}\n')
      ..write('X-ROOM-OF-DAYS-CAMPUS:Busch\n')
      ..write('X-ROOM-OF-DAYS-BUILDING:EE\n')
      ..write('X-ROOM-OF-DAYS-ROOM:${100 + i}\nEND:VEVENT\n');
  }
  out.write('END:VCALENDAR\n');
  return AcademicScheduleIcsImporter.parse(
    out.toString(),
  ).applyTo(AcademicSchedule.empty(), updatedAt: DateTime.utc(2026, 8, 27));
}
