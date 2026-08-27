String rutgersFall2026IcsFixture({bool includeIgnoredEvent = false}) {
  final out = StringBuffer('BEGIN:VCALENDAR\nVERSION:2.0\n');

  void master({
    required String uid,
    required String code,
    required String title,
    required String section,
    required String day,
    required String start,
    required String end,
    required String first,
    required String kind,
    required String building,
    required String room,
    required String campus,
    String? exdate,
  }) {
    out
      ..write('BEGIN:VEVENT\nUID:$uid\n')
      ..write('DTSTART;TZID=America/New_York:${first}T$start\n')
      ..write('DTEND;TZID=America/New_York:${first}T$end\n')
      ..write('RRULE:FREQ=WEEKLY;BYDAY=$day;UNTIL=20261211T045959Z\n');
    if (exdate != null) {
      out.write('EXDATE;TZID=America/New_York:${exdate}T$start\n');
    }
    out
      ..write('SUMMARY:$title\n')
      ..write('LOCATION:$building-$room\\, $campus Campus\n')
      ..write('X-ROOM-OF-DAYS-TERM:Fall 2026\n')
      ..write('X-ROOM-OF-DAYS-TERM-START:2026-09-01\n')
      ..write('X-ROOM-OF-DAYS-TERM-END:2026-12-10\n')
      ..write('X-ROOM-OF-DAYS-COURSE-CODE:$code\n')
      ..write('X-ROOM-OF-DAYS-COURSE-TITLE:$title\n')
      ..write('X-ROOM-OF-DAYS-SECTION:$section\n')
      ..write('X-ROOM-OF-DAYS-MEETING-KIND:$kind\n')
      ..write('X-ROOM-OF-DAYS-CAMPUS:$campus\n')
      ..write('X-ROOM-OF-DAYS-BUILDING:$building\n')
      ..write('X-ROOM-OF-DAYS-ROOM:$room\nEND:VEVENT\n');
  }

  void moved(
    String uid,
    String original,
    String movedTo,
    String start,
    String end,
  ) {
    out.write(
      'BEGIN:VEVENT\nUID:$uid\n'
      'RECURRENCE-ID;TZID=America/New_York:${original}T$start\n'
      'DTSTART;TZID=America/New_York:${movedTo}T$start\n'
      'DTEND;TZID=America/New_York:${movedTo}T$end\nEND:VEVENT\n',
    );
  }

  master(
    uid: 'rutgers-f26-ece361-mo@roomofdays',
    code: '14:332:361',
    title: 'Electronics Devices',
    section: '01',
    day: 'MO',
    first: '20260907',
    start: '083000',
    end: '095000',
    kind: 'lecture',
    building: 'SEC',
    room: '111',
    campus: 'Busch',
  );
  master(
    uid: 'rutgers-f26-ece361-th@roomofdays',
    code: '14:332:361',
    title: 'Electronics Devices',
    section: '01',
    day: 'TH',
    first: '20260903',
    start: '083000',
    end: '095000',
    kind: 'lecture',
    building: 'SEC',
    room: '111',
    campus: 'Busch',
    exdate: '20261126',
  );
  master(
    uid: 'rutgers-f26-ece363-th@roomofdays',
    code: '14:332:363',
    title: 'Electron Devices Lab',
    section: '04',
    day: 'TH',
    first: '20260903',
    start: '155000',
    end: '185000',
    kind: 'lab',
    building: 'EE',
    room: '209',
    campus: 'Busch',
    exdate: '20261126',
  );
  master(
    uid: 'rutgers-f26-ece331-tu@roomofdays',
    code: '14:332:331',
    title: 'Computer Architecture & Assembly Language',
    section: '01',
    day: 'TU',
    first: '20260901',
    start: '102000',
    end: '114000',
    kind: 'lecture',
    building: 'HLL',
    room: '114',
    campus: 'Busch',
    exdate: '20260908',
  );
  master(
    uid: 'rutgers-f26-ece331-fr@roomofdays',
    code: '14:332:331',
    title: 'Computer Architecture & Assembly Language',
    section: '01',
    day: 'FR',
    first: '20260904',
    start: '102000',
    end: '114000',
    kind: 'lecture',
    building: 'HLL',
    room: '114',
    campus: 'Busch',
  );
  master(
    uid: 'rutgers-f26-ece333-we@roomofdays',
    code: '14:332:333',
    title: 'Computer Architecture Lab',
    section: '05',
    day: 'WE',
    first: '20260902',
    start: '083000',
    end: '113000',
    kind: 'lab',
    building: 'EE',
    room: '103',
    campus: 'Busch',
    exdate: '20261125',
  );
  master(
    uid: 'rutgers-f26-ece345-mo-afternoon@roomofdays',
    code: '14:332:345',
    title: 'Linear Systems & Signals',
    section: '03',
    day: 'MO',
    first: '20260907',
    start: '140000',
    end: '152000',
    kind: 'lecture',
    building: 'SEC',
    room: '111',
    campus: 'Busch',
  );
  master(
    uid: 'rutgers-f26-ece345-mo-evening@roomofdays',
    code: '14:332:345',
    title: 'Linear Systems & Signals',
    section: '03',
    day: 'MO',
    first: '20260907',
    start: '174000',
    end: '190000',
    kind: 'lecture',
    building: 'SEC',
    room: '204',
    campus: 'Busch',
  );
  master(
    uid: 'rutgers-f26-ece345-we@roomofdays',
    code: '14:332:345',
    title: 'Linear Systems & Signals',
    section: '03',
    day: 'WE',
    first: '20260902',
    start: '140000',
    end: '152000',
    kind: 'lecture',
    building: 'SEC',
    room: '111',
    campus: 'Busch',
    exdate: '20261125',
  );
  master(
    uid: 'rutgers-f26-cs206-tu@roomofdays',
    code: '01:198:206',
    title: 'Introduction to Discrete Structures II',
    section: '10',
    day: 'TU',
    first: '20260901',
    start: '140000',
    end: '152000',
    kind: 'lecture',
    building: 'PHY',
    room: '001',
    campus: 'Busch',
    exdate: '20260908',
  );
  master(
    uid: 'rutgers-f26-cs206-th@roomofdays',
    code: '01:198:206',
    title: 'Introduction to Discrete Structures II',
    section: '10',
    day: 'TH',
    first: '20260903',
    start: '140000',
    end: '152000',
    kind: 'lecture',
    building: 'PHY',
    room: '001',
    campus: 'Busch',
    exdate: '20261126',
  );
  master(
    uid: 'rutgers-f26-cs206-fr@roomofdays',
    code: '01:198:206',
    title: 'Introduction to Discrete Structures II',
    section: '10',
    day: 'FR',
    first: '20260904',
    start: '175500',
    end: '185000',
    kind: 'lecture',
    building: 'BE',
    room: '250',
    campus: 'Livingston',
  );

  moved(
    'rutgers-f26-ece361-mo@roomofdays',
    '20260907',
    '20260908',
    '083000',
    '095000',
  );
  moved(
    'rutgers-f26-ece345-mo-afternoon@roomofdays',
    '20260907',
    '20260908',
    '140000',
    '152000',
  );
  moved(
    'rutgers-f26-ece345-mo-evening@roomofdays',
    '20260907',
    '20260908',
    '174000',
    '190000',
  );
  moved(
    'rutgers-f26-ece331-fr@roomofdays',
    '20261127',
    '20261125',
    '102000',
    '114000',
  );
  moved(
    'rutgers-f26-cs206-fr@roomofdays',
    '20261127',
    '20261125',
    '175500',
    '185000',
  );

  if (includeIgnoredEvent) {
    out.write(
      'BEGIN:VEVENT\nUID:orientation@roomofdays\n'
      'DTSTART;TZID=America/New_York:20260831T120000\n'
      'DTEND;TZID=America/New_York:20260831T130000\n'
      'RRULE:FREQ=DAILY;UNTIL=20260831T170000Z\nEND:VEVENT\n',
    );
  }
  return '${out}END:VCALENDAR\n';
}
