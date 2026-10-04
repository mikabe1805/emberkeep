// Realistic calendar exports a student might bring to Room of Days. Written by
// hand for the class import (2026-10-03) to match the shapes these tools
// produce: Google Calendar's export (VTIMEZONE, RRULE with UTC
// UNTIL, COUNT, EXDATE, RECURRENCE-ID overrides, nested VALARM, folded lines,
// everyday events mixed in), a Canvas feed (deadlines, no class meetings), a
// school portal that writes every meeting as its own event in floating time,
// an Outlook export with Windows zone names, including the "busy only"
// published calendar Outlook makes by default, and a whole-calendar Google
// export that still holds last spring. Names and places are invented.

String _crlf(String text) =>
    text.replaceAll('\r\n', '\n').replaceAll('\n', '\r\n');

/// Google Calendar → Settings → Import & export → Export (one calendar).
/// A first-year at a Central-time school: four courses (five weekly meetings)
/// plus gym, a job, a book club, a standup, a dentist visit, a birthday and a
/// break.
String googleCalendarStudentExport() => _crlf('''
BEGIN:VCALENDAR
PRODID:-//Google Inc//Google Calendar 70.9054//EN
VERSION:2.0
CALSCALE:GREGORIAN
METHOD:PUBLISH
X-WR-CALNAME:jordan.lee.uiuc@gmail.com
X-WR-TIMEZONE:America/Chicago
BEGIN:VTIMEZONE
TZID:America/Chicago
X-LIC-LOCATION:America/Chicago
BEGIN:DAYLIGHT
TZOFFSETFROM:-0600
TZOFFSETTO:-0500
TZNAME:CDT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
END:DAYLIGHT
BEGIN:STANDARD
TZOFFSETFROM:-0500
TZOFFSETTO:-0600
TZNAME:CST
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
END:STANDARD
END:VTIMEZONE
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20260824T100000
DTEND;TZID=America/Chicago:20260824T105000
RRULE:FREQ=WEEKLY;WKST=SU;UNTIL=20261205T055959Z;BYDAY=FR,MO,WE
EXDATE;TZID=America/Chicago:20260907T100000
EXDATE;TZID=America/Chicago:20261123T100000,20261125T100000,20261127T100000
DTSTAMP:20260820T153012Z
UID:3k9v2c1qj8l0m7s5u4t6r2p1o0@google.com
CREATED:20260819T201544Z
DESCRIPTION:Prof. Alvarez\\nBring laptop on Fridays
LAST-MODIFIED:20260820T153001Z
LOCATION:Siebel Center 1404\\, 201 N Goodwin Ave\\, Urbana\\, IL 61801\\, USA
SEQUENCE:2
STATUS:CONFIRMED
SUMMARY:CS 225 - Data Structures (Lecture)
TRANSP:OPAQUE
BEGIN:VALARM
ACTION:DISPLAY
DESCRIPTION:This is an event reminder
TRIGGER:-P0DT0H10M0S
END:VALARM
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20260827T160000
DTEND;TZID=America/Chicago:20260827T175000
RRULE:FREQ=WEEKLY;COUNT=15;BYDAY=TH
DTSTAMP:20260820T153012Z
UID:7a1b0c9d8e7f6g5h4i3j2k1l0m@google.com
LOCATION:Siebel Center 0220
SUMMARY:CS 225 Lab
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20260825T110000
DTEND;TZID=America/Chicago:20260825T122000
RRULE:FREQ=WEEKLY;WKST=SU;UNTIL=20261205T055959Z;BYDAY=TU,TH
DTSTAMP:20260820T153012Z
UID:m241fall26q0w9e8r7t6y5u4i3@google.com
LOCATION:Altgeld Hall 314
SUMMARY:MATH 241: Calculus III
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20261015T130000
DTEND;TZID=America/Chicago:20261015T142000
DTSTAMP:20260820T153012Z
UID:m241fall26q0w9e8r7t6y5u4i3@google.com
RECURRENCE-ID;TZID=America/Chicago:20261015T110000
LOCATION:Altgeld Hall 145
SUMMARY:MATH 241: Calculus III (moved for midterm)
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20261126T110000
DTEND;TZID=America/Chicago:20261126T122000
DTSTAMP:20260820T153012Z
UID:m241fall26q0w9e8r7t6y5u4i3@google.com
RECURRENCE-ID;TZID=America/Chicago:20261126T110000
STATUS:CANCELLED
SUMMARY:MATH 241: Calculus III
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20260825T140000
DTEND;TZID=America/Chicago:20260825T152000
RRULE:FREQ=WEEKLY;UNTIL=20261204T000000Z;BYDAY=TU,TH
DTSTAMP:20260820T153012Z
UID:psyc100xx1@google.com
LOCATION:Psychology Building 23
SUMMARY:Intro to Psychology
DESCRIPTION:Long description that Google folds across several lines becau
 se it is longer than seventy-five octets\\, which the reader must unfol
 d before it reads anything else.
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20260824T130000
DTEND;TZID=America/Chicago:20260824T135000
RRULE:FREQ=DAILY;UNTIL=20261205T055959Z;BYDAY=MO,WE
DTSTAMP:20260820T153012Z
UID:rhet105zz2@google.com
LOCATION:English Building 160
SUMMARY:RHET 105 Writing and Research
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20260601T070000
DTEND;TZID=America/Chicago:20260601T080000
RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR
DTSTAMP:20260820T153012Z
UID:gym-forever@google.com
LOCATION:ARC
SUMMARY:Gym
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20260829T100000
DTEND;TZID=America/Chicago:20260829T160000
RRULE:FREQ=WEEKLY;UNTIL=20261213T055959Z;BYDAY=SA
DTSTAMP:20260820T153012Z
UID:shift-sat@google.com
LOCATION:Campus Bookstore
SUMMARY:Work shift
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20260902T190000
DTEND;TZID=America/Chicago:20260902T200000
RRULE:FREQ=WEEKLY;COUNT=10;BYDAY=WE
DTSTAMP:20260820T153012Z
UID:bookclub@google.com
SUMMARY:Book club
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20260901T090000
DTEND;TZID=America/Chicago:20260901T091500
RRULE:FREQ=WEEKLY;UNTIL=20261218T060000Z;BYDAY=MO,TU,WE,TH,FR
DTSTAMP:20260820T153012Z
UID:lab-standup@google.com
SUMMARY:Research lab standup
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20260918T153000
DTEND;TZID=America/Chicago:20260918T163000
DTSTAMP:20260820T153012Z
UID:dentist@google.com
SUMMARY:Dentist appointment
END:VEVENT
BEGIN:VEVENT
DTSTART;VALUE=DATE:20261012
DTEND;VALUE=DATE:20261013
RRULE:FREQ=YEARLY
DTSTAMP:20260820T153012Z
UID:mom-bday@google.com
SUMMARY:Mom's birthday
END:VEVENT
BEGIN:VEVENT
DTSTART;VALUE=DATE:20261121
DTEND;VALUE=DATE:20261130
DTSTAMP:20260820T153012Z
UID:fall-break@google.com
SUMMARY:Fall break
END:VEVENT
END:VCALENDAR
''');

/// Canvas → Calendar → Calendar Feed. Assignments are date-only or
/// zero-length; there are no class meetings in it.
String canvasFeedExport() => _crlf('''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Instructure//Canvas Calendar//EN
X-WR-CALNAME:Jordan Lee Calendar (Canvas)
X-WR-CALDESC:Calendar events for the user\\, Jordan Lee
METHOD:PUBLISH
BEGIN:VEVENT
DTEND;VALUE=DATE:20261009
DTSTART;VALUE=DATE:20261009
UID:event-assignment-1184211
CLASS:PUBLIC
DESCRIPTION:Read chapter 4 and answer the questions.
SUMMARY:Homework 5 [CS 225 FA26]
URL;VALUE=URI:https://canvas.illinois.edu/courses/55012/assignments/1184211
END:VEVENT
BEGIN:VEVENT
DTEND:20261010T045900Z
DTSTART:20261010T045900Z
UID:event-assignment-1184212
SUMMARY:MP3 Due [CS 225 FA26]
END:VEVENT
BEGIN:VEVENT
DTEND:20261014T045900Z
DTSTART:20261014T045900Z
UID:event-assignment-1184260
SUMMARY:Problem Set 6 [MATH 241 FA26]
END:VEVENT
BEGIN:VEVENT
DTEND;VALUE=DATE:20261016
DTSTART;VALUE=DATE:20261016
UID:event-assignment-1184299
SUMMARY:Reading response 4 [PSYC 100 FA26]
END:VEVENT
BEGIN:VEVENT
DTEND:20261013T010000Z
DTSTART:20261012T230000Z
UID:event-calendar-event-90213
LOCATION:Altgeld Hall 314
SUMMARY:Midterm review session [MATH 241 FA26]
END:VEVENT
END:VCALENDAR
''');

/// A school portal that exports every meeting as its own event, with
/// floating local times, a holiday hole, and a lab every other week.
String portalExpandedExport() {
  final out = StringBuffer(
    'BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//Example University//Student Schedule//EN\n',
  );
  var id = 0;
  void meeting(
    String date,
    String start,
    String end,
    String summary,
    String place,
  ) {
    id++;
    out.write(
      'BEGIN:VEVENT\nUID:sched-$id@example.edu\nDTSTAMP:20260820T120000Z\n'
      'DTSTART:${date}T$start\nDTEND:${date}T$end\n'
      'SUMMARY:$summary\nLOCATION:$place\nEND:VEVENT\n',
    );
  }

  // BIO 110 lecture, MWF 9:00-9:50, Sep 2 to Oct 9, no class Mon Sep 7.
  final lecture = [
    '20260902',
    '20260904',
    '20260909',
    '20260911',
    '20260914',
    '20260916',
    '20260918',
    '20260921',
    '20260923',
    '20260925',
    '20260928',
    '20260930',
    '20261002',
    '20261005',
    '20261007',
    '20261009',
  ];
  for (final date in lecture) {
    meeting(
      date,
      '090000',
      '095000',
      'BIO 110 LEC 001 - Principles of Biology',
      'Life Sciences Building 120',
    );
  }
  // BIO 110 lab every other Wednesday 2:00-4:50.
  for (final date in ['20260902', '20260916', '20260930', '20261014']) {
    meeting(
      date,
      '140000',
      '165000',
      'BIO 110 LAB 012 - Principles of Biology',
      'Life Sciences Building 214',
    );
  }
  // One-off: an advising appointment.
  meeting(
    '20260915',
    '110000',
    '113000',
    'Advising appointment',
    'Student Center',
  );
  out.write('END:VCALENDAR\n');
  return out.toString();
}

/// Outlook export (Windows zone names in TZID).
String outlookExport({bool busyOnly = false}) => _crlf('''
BEGIN:VCALENDAR
METHOD:PUBLISH
PRODID:Microsoft Exchange Server 2010
VERSION:2.0
X-WR-CALNAME:Calendar
BEGIN:VTIMEZONE
TZID:Eastern Standard Time
BEGIN:STANDARD
DTSTART:16010101T020000
TZOFFSETFROM:-0400
TZOFFSETTO:-0500
RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=1SU;BYMONTH=11
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:16010101T020000
TZOFFSETFROM:-0500
TZOFFSETTO:-0400
RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=2SU;BYMONTH=3
END:DAYLIGHT
END:VTIMEZONE
BEGIN:VEVENT
RRULE:FREQ=WEEKLY;UNTIL=20261211T150000Z;INTERVAL=1;BYDAY=TU,TH;WKST=SU
UID:040000008200E00074C5B7101A82E0080000000010D7A1C4F0CDDA01000000000000000010000000
SUMMARY:${busyOnly ? 'Busy' : 'ECON 102 Principles of Macroeconomics'}
DTSTART;TZID=Eastern Standard Time:20260901T093000
DTEND;TZID=Eastern Standard Time:20260901T104500
CLASS:PUBLIC
PRIORITY:5
DTSTAMP:20260828T190211Z
TRANSP:OPAQUE
STATUS:CONFIRMED
SEQUENCE:0
LOCATION:${busyOnly ? '' : 'Hayden Hall 100'}
END:VEVENT
BEGIN:VEVENT
RRULE:FREQ=WEEKLY;UNTIL=20261209T150000Z;INTERVAL=1;BYDAY=MO,WE;WKST=SU
UID:040000008200E00074C5B7101A82E0080000000020D7A1C4F0CDDA01000000000000000010000000
SUMMARY:${busyOnly ? 'Busy' : 'STAT 201 - Statistics (Lecture)'}
DTSTART;TZID=Eastern Standard Time:20260831T130000
DTEND;TZID=Eastern Standard Time:20260831T141500
DTSTAMP:20260828T190211Z
STATUS:CONFIRMED
END:VEVENT
END:VCALENDAR
''');

/// Google Calendar export of a whole calendar: this fall (the export above)
/// plus last spring's four courses, which ended in May.
String googleTwoTermExport() {
  final fall = googleCalendarStudentExport().replaceAll('\r\n', '\n');
  const spring = '''
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20260120T100000
DTEND;TZID=America/Chicago:20260120T105000
RRULE:FREQ=WEEKLY;UNTIL=20260507T045959Z;BYDAY=MO,WE,FR
DTSTAMP:20260110T153012Z
UID:cs173spring26@google.com
LOCATION:Siebel Center 1404
SUMMARY:CS 173 Discrete Structures
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20260120T093000
DTEND;TZID=America/Chicago:20260120T105000
RRULE:FREQ=WEEKLY;UNTIL=20260507T045959Z;BYDAY=TU,TH
DTSTAMP:20260110T153012Z
UID:math231spring26@google.com
LOCATION:Altgeld Hall 141
SUMMARY:MATH 231 Calculus II
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20260120T130000
DTEND;TZID=America/Chicago:20260120T142000
RRULE:FREQ=WEEKLY;UNTIL=20260507T045959Z;BYDAY=TU,TH
DTSTAMP:20260110T153012Z
UID:chem102spring26@google.com
LOCATION:Noyes Lab 100
SUMMARY:CHEM 102 General Chemistry I
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20260121T140000
DTEND;TZID=America/Chicago:20260121T165000
RRULE:FREQ=WEEKLY;UNTIL=20260507T045959Z;BYDAY=WE
DTSTAMP:20260110T153012Z
UID:chem103spring26@google.com
LOCATION:Chemistry Annex 1024
SUMMARY:CHEM 103 Lab
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=America/Chicago:20260203T180000
DTEND;TZID=America/Chicago:20260203T190000
RRULE:FREQ=WEEKLY;UNTIL=20260428T235959Z;BYDAY=TU
DTSTAMP:20260110T153012Z
UID:ultimate-spring@google.com
SUMMARY:Ultimate frisbee practice
END:VEVENT
''';
  return _crlf(fall.replaceFirst('END:VCALENDAR', '${spring}END:VCALENDAR'));
}
