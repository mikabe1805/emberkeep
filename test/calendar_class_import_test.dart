// Add your classes (2026-10-03): ordinary calendar exports, the review
// picker, calendar links, quick typed classes, two-term exports and the
// class-reminder choice after an import. Mika's Room of Days file must keep
// importing exactly as before.
import 'dart:convert';

import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/academic_calendar/import/calendar_class_finder.dart';
import 'package:emberkeep/academic_calendar/import/calendar_link.dart';
import 'package:emberkeep/academic_calendar/import/class_import_reminders.dart';
import 'package:emberkeep/academic_calendar/import/quick_class_entry.dart';
import 'package:emberkeep/academic_calendar/services/academic_reminder_projection.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/calendar_export_samples.dart';
import 'support/rutgers_fall_2026_ics_fixture.dart';

List<ClassOccurrence> _live(AcademicSchedule schedule) => [
  for (final item in schedule.occurrences)
    if (item.state != OccurrenceState.cancelled && item.tombstonedAt == null)
      item,
];

String _hm(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

List<String> _rows(AcademicSchedule schedule) => [
  for (final item in _live(schedule))
    '${item.date} ${_hm(item.localStartMinute)}-${_hm(item.localEndMinute)} '
        '${schedule.courseById(item.courseId)!.code}',
]..sort();

CalendarClassImportDraft _google() => CalendarClassFinder.find(
  googleCalendarStudentExport(),
  sourceName: 'jordan.lee.uiuc@gmail.com.ics',
  fallbackTimeZoneId: 'America/New_York',
  today: CivilDate(2026, 10, 3),
);

void main() {
  group('Mika\'s Room of Days file', () {
    test('still routes to the original importer: 6 courses, 168 meetings', () {
      final read = ClassScheduleReader.read(
        rutgersFall2026IcsFixture(includeIgnoredEvent: true),
        sourceName: 'rutgers-fall-2026-room-of-days.ics',
      );
      expect(read, isA<RoomOfDaysScheduleRead>());
      final draft = (read as RoomOfDaysScheduleRead).draft;
      expect(draft.courses, hasLength(6));
      expect(draft.meetingSeriesCount, 12);
      expect(draft.projectedOccurrenceCount, 168);
      final schedule = draft.applyTo(
        AcademicSchedule.empty(),
        updatedAt: DateTime.utc(2026, 8, 27),
      );
      expect(_live(schedule), hasLength(168));
    });

    test('the general reader agrees with it meeting for meeting', () {
      final legacy = AcademicScheduleIcsImporter.parse(
        rutgersFall2026IcsFixture(),
      ).applyTo(AcademicSchedule.empty(), updatedAt: DateTime.utc(2026, 8, 27));
      final draft = CalendarClassFinder.find(
        rutgersFall2026IcsFixture(includeIgnoredEvent: true),
        today: CivilDate(2026, 10, 3),
      );
      expect(draft.candidates, hasLength(12));
      expect(draft.candidates.every((item) => item.looksLikeClass), isTrue);
      expect(draft.selectedCourses, hasLength(6));
      expect(draft.term.name, 'Fall 2026');
      expect(draft.term.startDate, CivilDate(2026, 9, 1));
      expect(draft.term.endDate, CivilDate(2026, 12, 10));
      expect(draft.otherRepeatingCount, 1); // the DAILY orientation event
      expect(draft.projectedOccurrenceCount, 168);
      final general = draft.applyTo(
        AcademicSchedule.empty(),
        updatedAt: DateTime.utc(2026, 8, 27),
      );
      expect(_live(general), hasLength(168));
      expect(_rows(general), _rows(legacy));
      // Designated days survive: Tuesday Sep 8 runs Monday's three classes.
      expect(
        _live(general).where((item) => item.date == CivilDate(2026, 9, 8)),
        hasLength(3),
      );
    });
  });

  group('Google Calendar export', () {
    test('finds the five class meetings and leaves everyday life out', () {
      final draft = _google();
      expect(draft.timeZoneId, 'America/Chicago');
      final likely = draft.candidates.where((item) => item.looksLikeClass);
      expect(likely.map((item) => item.summary).toSet(), {
        'CS 225 - Data Structures (Lecture)',
        'CS 225 Lab',
        'MATH 241: Calculus III',
        'Intro to Psychology',
        'RHET 105 Writing and Research',
      });
      final notLikely = draft.candidates
          .where((item) => !item.looksLikeClass)
          .map((item) => item.summary)
          .toSet();
      expect(notLikely, {
        'Gym',
        'Work shift',
        'Book club',
        'Research lab standup',
      });
      expect(draft.allDayCount, 2); // the birthday and fall break
      expect(draft.oneTimeCount, 1); // the dentist
      expect(draft.selectedKeys, hasLength(5));
    });

    test('reads codes, titles and kinds the way a student would say them', () {
      final courses = _google().selectedCourses;
      final byCode = {for (final course in courses) course.code: course};
      expect(byCode.keys.toSet(), {'CS 225', 'MATH 241', 'RHET 105', 'IP'});
      expect(byCode['CS 225']!.title, 'Data Structures');
      expect(byCode['CS 225']!.candidates, hasLength(2));
      expect(
        byCode['CS 225']!.candidates.map((item) => item.name.kind).toSet(),
        {MeetingKind.lecture, MeetingKind.lab},
      );
      expect(byCode['MATH 241']!.title, 'Calculus III');
      expect(byCode['RHET 105']!.title, 'Writing and Research');
      expect(byCode['IP']!.title, 'Intro to Psychology');
      expect(byCode['IP']!.codeFound, isFalse);
    });

    test('term, exceptions, moved and cancelled meetings, COUNT', () {
      final draft = _google();
      expect(draft.term.name, 'Fall 2026');
      expect(draft.term.startDate, CivilDate(2026, 8, 24));
      expect(draft.term.endDate, CivilDate(2026, 12, 4)); // UTC UNTIL, CST
      // 41 lecture + 15 lab + 29 calculus + 30 psychology + 30 rhetoric.
      expect(draft.projectedOccurrenceCount, 145);
      final schedule = draft.applyTo(
        AcademicSchedule.empty(),
        updatedAt: DateTime.utc(2026, 10, 3, 16),
      );
      expect(_live(schedule), hasLength(145));
      final labor = _live(
        schedule,
      ).where((item) => item.date == CivilDate(2026, 9, 7));
      expect(labor.map((item) => schedule.courseById(item.courseId)!.code), [
        'RHET 105',
      ]); // CS 225 has an EXDATE; RHET 105 does not.
      final midterm = _live(schedule).firstWhere(
        (item) =>
            item.date == CivilDate(2026, 10, 15) &&
            schedule.courseById(item.courseId)!.code == 'MATH 241',
      );
      expect(midterm.localStartMinute, 13 * 60);
      expect(
        _live(schedule).where(
          (item) =>
              item.date == CivilDate(2026, 11, 26) &&
              schedule.courseById(item.courseId)!.code == 'MATH 241',
        ),
        isEmpty,
      );
      final lab = _live(schedule)
          .where((item) => schedule.courseById(item.courseId)!.code == 'CS 225')
          .where((item) => item.kind == MeetingKind.lab);
      expect(lab, hasLength(15));
      expect(schedule.terms.single.timeZoneId, 'America/Chicago');
    });

    test('picking changes the count, and importing twice changes nothing', () {
      var draft = _google();
      final psych = draft.courses.firstWhere((item) => item.code == 'IP');
      draft = draft.withCourseSelected(psych, false);
      expect(draft.projectedOccurrenceCount, 115);
      final gym = draft.candidates.firstWhere((item) => item.summary == 'Gym');
      draft = draft.withSelected(gym.key, true);
      expect(draft.usesSeasonEnd, isTrue); // the gym series has no end
      draft = draft.withSelected(gym.key, false);
      final once = draft.applyTo(
        AcademicSchedule.empty(),
        updatedAt: DateTime.utc(2026, 10, 3, 16),
      );
      final twice = draft.applyTo(
        once,
        updatedAt: DateTime.utc(2026, 10, 4, 16),
      );
      expect(twice.courses, hasLength(once.courses.length));
      expect(twice.meetingSeries, hasLength(once.meetingSeries.length));
      expect(
        twice.occurrences.map((item) => item.occurrenceKey).toSet(),
        once.occurrences.map((item) => item.occurrenceKey).toSet(),
      );
      expect(_live(twice), hasLength(115));
    });

    test('the term end can be pulled in, and meetings stop there', () {
      final draft = _google().withTermEnd(CivilDate(2026, 10, 31));
      final schedule = draft.applyTo(
        AcademicSchedule.empty(),
        updatedAt: DateTime.utc(2026, 10, 3, 16),
      );
      expect(
        _live(
          schedule,
        ).every((item) => item.date.compareTo(CivilDate(2026, 10, 31)) <= 0),
        isTrue,
      );
    });
  });

  group('Other sources', () {
    test('a Canvas feed holds due dates and no classes', () {
      final draft = CalendarClassFinder.find(
        canvasFeedExport(),
        fallbackTimeZoneId: 'America/Chicago',
        today: CivilDate(2026, 10, 3),
      );
      expect(draft.hasCandidates, isFalse);
      expect(draft.deadlineCount, 4);
      expect(draft.oneTimeCount, 1);
      expect(draft.calendarName, 'Jordan Lee Calendar (Canvas)');
    });

    test('a portal that writes every meeting separately is gathered', () {
      final draft = CalendarClassFinder.find(
        portalExpandedExport(),
        fallbackTimeZoneId: 'America/Los_Angeles',
        today: CivilDate(2026, 10, 3),
      );
      expect(draft.timeZoneId, 'America/Los_Angeles');
      expect(draft.candidates, hasLength(2));
      expect(draft.oneTimeCount, 1); // the advising appointment
      final course = draft.selectedCourses.single;
      expect(course.code, 'BIO 110');
      expect(course.title, 'Principles of Biology');
      final lecture = course.candidates.firstWhere(
        (item) => item.name.kind == MeetingKind.lecture,
      );
      expect(lecture.origin, ClassCandidateOrigin.gathered);
      expect(lecture.weekdays, {
        DateTime.monday,
        DateTime.wednesday,
        DateTime.friday,
      });
      expect(lecture.name.section, '001');
      expect(lecture.skippedDates, {CivilDate(2026, 9, 7)});
      final lab = course.candidates.firstWhere(
        (item) => item.name.kind == MeetingKind.lab,
      );
      expect(lab.intervalWeeks, 2);
      expect(draft.projectedOccurrenceCount, 16 + 4);
      final schedule = draft.applyTo(
        AcademicSchedule.empty(),
        updatedAt: DateTime.utc(2026, 10, 3),
      );
      expect(_live(schedule), hasLength(20));
    });

    test('Outlook zone names resolve; a busy-only calendar says so', () {
      final draft = CalendarClassFinder.find(
        outlookExport(),
        fallbackTimeZoneId: 'America/Chicago',
        today: CivilDate(2026, 10, 3),
      );
      expect(draft.timeZoneId, 'America/New_York');
      expect(draft.selectedCourses.map((item) => item.code).toSet(), {
        'ECON 102',
        'STAT 201',
      });
      expect(draft.titlesHidden, isFalse);
      final econ = draft.candidates.firstWhere(
        (item) => item.name.code == 'ECON 102',
      );
      expect(econ.startMinute, 9 * 60 + 30);
      expect(econ.lastDate, CivilDate(2026, 12, 11));
      final busy = CalendarClassFinder.find(
        outlookExport(busyOnly: true),
        today: CivilDate(2026, 10, 3),
      );
      expect(busy.titlesHidden, isTrue);
      // Times without names never pass for classes on their own.
      expect(busy.foundLikelyClasses, isFalse);
      expect(busy.selectedKeys, isEmpty);
      expect(
        busy.candidates.every((item) => item.signals.contains('-3 no title')),
        isTrue,
      );
    });

    test('a UTC-only feed lands in the fallback zone', () {
      const feed =
          'BEGIN:VCALENDAR\nVERSION:2.0\nBEGIN:VEVENT\nUID:u1\n'
          'DTSTART:20260908T130000Z\nDTEND:20260908T141500Z\n'
          'RRULE:FREQ=WEEKLY;BYDAY=TU;UNTIL=20261208T235959Z\n'
          'SUMMARY:PHYS 211 Lecture\nEND:VEVENT\nEND:VCALENDAR\n';
      final draft = CalendarClassFinder.find(
        feed,
        fallbackTimeZoneId: 'America/Denver',
        today: CivilDate(2026, 10, 3),
      );
      final item = draft.candidates.single;
      expect(item.startMinute, 7 * 60); // 13:00Z is 07:00 MDT
      expect(item.looksLikeClass, isTrue);
    });

    test('not a calendar at all is a FormatException', () {
      expect(
        () => ClassScheduleReader.read('<html><body>Sign in</body></html>'),
        throwsFormatException,
      );
    });
  });

  group('Course names', () {
    final cases = <String, (String, String, bool, MeetingKind)>{
      'CS 206 - Discrete Structures II (Lecture)': (
        'CS 206',
        'Discrete Structures II',
        true,
        MeetingKind.lecture,
      ),
      '14:332:345 Linear Systems & Signals': (
        '14:332:345',
        'Linear Systems & Signals',
        true,
        MeetingKind.lecture,
      ),
      'ECE345: Linear Systems': (
        'ECE 345',
        'Linear Systems',
        true,
        MeetingKind.lecture,
      ),
      'MATH-151 REC 04': ('MATH 151', 'MATH 151', true, MeetingKind.recitation),
      'Linear Systems & Signals - Lecture': (
        'LSS',
        'Linear Systems & Signals',
        false,
        MeetingKind.lecture,
      ),
      'Computer Architecture Lab': (
        'CAL',
        'Computer Architecture Lab',
        false,
        MeetingKind.lab,
      ),
      'Discrete Structures II': (
        'DS II',
        'Discrete Structures II',
        false,
        MeetingKind.lecture,
      ),
      'CHEM 161H Honors Chemistry Discussion': (
        'CHEM 161H',
        'Honors Chemistry Discussion',
        true,
        MeetingKind.recitation,
      ),
    };
    for (final entry in cases.entries) {
      test(entry.key, () {
        final name = ClassNameReader.read(entry.key);
        expect(name.code, entry.value.$1);
        expect(name.title, entry.value.$2);
        expect(name.codeFound, entry.value.$3);
        expect(name.kind, entry.value.$4);
      });
    }
  });

  group('Calendar links', () {
    test('webcal and bare links become https; sources are recognized', () {
      final icloud = CalendarLink.parse(
        ' webcal://p52-caldav.icloud.com/published/2/MTIzNDU2Nzg5 ',
      );
      expect(icloud.uri.scheme, 'https');
      expect(icloud.source, CalendarLinkSource.icloud);
      final google = CalendarLink.parse(
        'https://calendar.google.com/calendar/ical/jordan.lee.uiuc%40gmail.com/private-0123abcd/basic.ics',
      );
      expect(google.source, CalendarLinkSource.google);
      final canvas = CalendarLink.parse(
        'canvas.illinois.edu/feeds/calendars/user_AbC123.ics',
      );
      expect(canvas.uri.toString(), startsWith('https://canvas.illinois.edu'));
      expect(canvas.source, CalendarLinkSource.canvas);
      final outlook = CalendarLink.parse(
        'https://outlook.office365.com/owa/calendar/abc@school.edu/def/calendar.ics',
      );
      expect(outlook.source, CalendarLinkSource.outlook);
    });

    test('page links and junk get a plain reason', () {
      expect(
        () => CalendarLink.parse(
          'https://calendar.google.com/calendar/embed?src=jordan%40gmail.com',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Secret address in iCal format'),
          ),
        ),
      );
      expect(() => CalendarLink.parse('   '), throwsFormatException);
      expect(
        () => CalendarLink.parse('ftp://x.edu/a.ics'),
        throwsFormatException,
      );
      expect(
        () => checkCalendarText('<!doctype html><title>Sign in</title>'),
        throwsFormatException,
      );
      expect(
        checkCalendarText('﻿BEGIN:VCALENDAR\nEND:VCALENDAR'),
        startsWith('BEGIN:VCALENDAR'),
      );
    });
  });

  group('Typing classes in', () {
    test(
      'a class starts this week, in an inferred term, and joins its course',
      () {
        final today = CivilDate(2026, 10, 7); // a Wednesday
        var schedule = AcademicSchedule.empty();
        final term = QuickClassPlanner.termFor(
          schedule,
          today,
          timeZoneId: 'America/New_York',
        );
        expect(term.name, 'Fall 2026');
        expect(term.startDate, CivilDate(2026, 10, 5));
        expect(term.endDate, CivilDate(2026, 12, 20));
        schedule = QuickClassPlanner.add(
          schedule,
          QuickClassEntry(
            name: 'CS 206 Discrete Structures II',
            weekdays: {DateTime.tuesday, DateTime.thursday},
            startMinute: 14 * 60,
            lengthMinutes: 80,
          ),
          term: term,
          today: today,
          updatedAt: DateTime.utc(2026, 10, 7, 18),
        );
        schedule = QuickClassPlanner.add(
          schedule,
          QuickClassEntry(
            name: 'CS 206 Recitation',
            weekdays: {DateTime.friday},
            startMinute: 17 * 60 + 55,
            lengthMinutes: 55,
          ),
          term: QuickClassPlanner.termFor(
            schedule,
            today,
            timeZoneId: 'America/New_York',
          ),
          today: today,
          updatedAt: DateTime.utc(2026, 10, 7, 18, 1),
        );
        expect(schedule.terms, hasLength(1));
        expect(schedule.courses, hasLength(1));
        expect(schedule.courses.single.code, 'CS 206');
        expect(schedule.courses.single.title, 'Discrete Structures II');
        expect(schedule.meetingSeries, hasLength(2));
        final first = _live(schedule).first;
        expect(first.date, CivilDate(2026, 10, 6)); // this week's Tuesday
        expect(first.localEndMinute, 15 * 60 + 20);
        expect(
          _live(schedule).where((item) => item.kind == MeetingKind.recitation),
          isNotEmpty,
        );
      },
    );

    test('an entry says what is missing in plain words', () {
      expect(
        QuickClassEntry(
          name: '',
          weekdays: {1},
          startMinute: 600,
          lengthMinutes: 50,
        ).problem,
        'Give the class a name.',
      );
      expect(
        QuickClassEntry(
          name: 'Bio',
          weekdays: const {},
          startMinute: 600,
          lengthMinutes: 50,
        ).problem,
        'Pick the days it meets.',
      );
    });
  });

  group('Two terms in one export', () {
    CalendarClassImportDraft twoTerms(CivilDate today) =>
        CalendarClassFinder.find(
          googleTwoTermExport(),
          sourceName: 'jordan.lee.uiuc@gmail.com.ics',
          fallbackTimeZoneId: 'America/New_York',
          today: today,
        );

    test('only the current term starts checked; last spring waits', () {
      final draft = twoTerms(CivilDate(2026, 10, 3));
      expect(draft.termChoices.map((item) => item.name), [
        'Spring 2026',
        'Fall 2026',
      ]);
      expect(draft.activeTerm.name, 'Fall 2026');
      expect(draft.otherTerms.single.name, 'Spring 2026');
      expect(draft.otherTerms.single.likelyCourseCount, 4);
      // Exactly the five fall meetings, as in the fall-only export.
      expect(
        draft.selected.map((item) => item.summary).toSet(),
        _google().selected.map((item) => item.summary).toSet(),
      );
      expect(
        draft.selectedKeys.every(
          (key) => draft.activeTerm.candidateKeys.contains(key),
        ),
        isTrue,
      );
      // Everyday life sorts into the term it overlaps, and stays unchecked.
      expect(
        draft.courses
            .where((course) => !course.looksLikeClass)
            .map((course) => course.title)
            .toSet(),
        containsAll(<String>['Gym', 'Work shift']),
      );
      expect(
        draft.courses.map((course) => course.title),
        isNot(contains('Ultimate frisbee practice')),
      );
      expect(draft.term.name, 'Fall 2026');
      expect(draft.term.startDate, CivilDate(2026, 8, 24));
      expect(draft.projectedOccurrenceCount, 145);
      final schedule = draft.applyTo(
        AcademicSchedule.empty(),
        updatedAt: DateTime.utc(2026, 10, 3, 16),
      );
      expect(schedule.terms.single.name, 'Fall 2026');
      final single = _google().applyTo(
        AcademicSchedule.empty(),
        updatedAt: DateTime.utc(2026, 10, 3, 16),
      );
      expect(_rows(schedule), _rows(single));
    });

    test('the other term is one tap away and never mixes in', () {
      final fall = twoTerms(CivilDate(2026, 10, 3));
      final spring = fall.withActiveTerm(fall.otherTerms.single.index);
      expect(spring.activeTerm.name, 'Spring 2026');
      expect(spring.selectedCourses.map((course) => course.code).toSet(), {
        'CS 173',
        'MATH 231',
        'CHEM 102',
        'CHEM 103',
      });
      expect(
        spring.courses
            .where((course) => !course.looksLikeClass)
            .map((course) => course.title),
        contains('Ultimate frisbee practice'),
      );
      expect(spring.term.name, 'Spring 2026');
      expect(spring.term.startDate, CivilDate(2026, 1, 20));
      expect(spring.term.endDate.month, 5);
      final schedule = spring.applyTo(
        AcademicSchedule.empty(),
        updatedAt: DateTime.utc(2026, 10, 3, 16),
      );
      expect(schedule.terms.single.name, 'Spring 2026');
      expect(
        _live(
          schedule,
        ).every((item) => item.date.compareTo(CivilDate(2026, 6, 1)) < 0),
        isTrue,
      );
      // Back again: the fall picks come back as they started.
      final back = spring.withActiveTerm(spring.otherTerms.single.index);
      expect(back.selectedKeys, fall.selectedKeys);
    });

    test('between terms the next one leads; after both, the latest', () {
      expect(twoTerms(CivilDate(2026, 7, 1)).activeTerm.name, 'Fall 2026');
      expect(twoTerms(CivilDate(2026, 3, 2)).activeTerm.name, 'Spring 2026');
      expect(twoTerms(CivilDate(2027, 2, 1)).activeTerm.name, 'Fall 2026');
    });

    test('a one-term export has one choice and nothing else to show', () {
      final draft = _google();
      expect(draft.termChoices, hasLength(1));
      expect(draft.otherTerms, isEmpty);
    });
  });

  group('Importing again', () {
    test('a portal export with new event IDs refreshes instead of adding', () {
      final first = CalendarClassFinder.find(
        googleCalendarStudentExport(),
        fallbackTimeZoneId: 'America/New_York',
        today: CivilDate(2026, 10, 3),
      ).applyTo(AcademicSchedule.empty(), updatedAt: DateTime.utc(2026, 10, 3));
      final renamed = googleCalendarStudentExport().replaceAllMapped(
        RegExp(r'^UID:(.*)$', multiLine: true),
        (match) => 'UID:fresh-${match.group(1)}',
      );
      final again = CalendarClassFinder.find(
        renamed,
        fallbackTimeZoneId: 'America/New_York',
        today: CivilDate(2026, 10, 3),
      ).applyTo(first, updatedAt: DateTime.utc(2026, 10, 4));
      expect(again.courses, hasLength(first.courses.length));
      expect(again.meetingSeries, hasLength(first.meetingSeries.length));
      expect(_rows(again), _rows(first));
    });
  });

  group('Class reminders after an import', () {
    AcademicScheduleImportDraft legacy() =>
        AcademicScheduleIcsImporter.parse(rutgersFall2026IcsFixture());
    final at = DateTime.utc(2026, 8, 27, 15);

    test('a Room of Days file imports with reminders off, as before', () {
      final schedule = legacy().applyTo(
        AcademicSchedule.empty(),
        updatedAt: at,
      );
      final written = meetingSeriesWrittenBetween(
        AcademicSchedule.empty(),
        schedule,
      );
      expect(written, hasLength(12));
      expect(classReminderOffsetOf(schedule, written), isNull);
      expect(
        projectAcademicReminderNotices(schedule: schedule, now: at),
        isEmpty,
      );
    });

    test('turning them on after the import matches the old review exactly', () {
      final before = AcademicSchedule.empty();
      final imported = legacy().applyTo(before, updatedAt: at);
      final written = meetingSeriesWrittenBetween(before, imported);
      for (final offset in classReminderOffsets) {
        final viaResult = withClassReminders(
          imported,
          written,
          offsetMinutes: offset,
          updatedAt: at.add(const Duration(minutes: 1)),
        );
        final viaOldReview = legacy()
            .withReminderChoice(
              AcademicScheduleImportReminderChoice.on,
              offsetMinutes: offset,
            )
            .applyTo(before, updatedAt: at);
        List<String> rules(AcademicSchedule schedule) => [
          for (final series in schedule.meetingSeries)
            for (final rule in series.reminders)
              '${series.meetingSeriesId} ${rule.reminderId} '
                  '${rule.enabled} ${rule.offsetMinutes}',
        ]..sort();
        expect(rules(viaResult), rules(viaOldReview));
        String notices(AcademicSchedule schedule) => [
          for (final notice in projectAcademicReminderNotices(
            schedule: schedule,
            now: at,
          ))
            '${notice.whenUtc.toIso8601String()} ${notice.title} ${notice.body}',
        ].join('\n');
        expect(notices(viaResult), notices(viaOldReview));
        expect(
          projectAcademicReminderNotices(schedule: viaResult, now: at),
          hasLength(168),
        );
        expect(classReminderOffsetOf(viaResult, written), offset);
        // Times, places and states are untouched.
        expect(_rows(viaResult), _rows(imported));
      }
    });

    test('turning them off clears them, moved classes included', () {
      final imported = legacy().applyTo(
        AcademicSchedule.empty(),
        updatedAt: at,
      );
      final written = meetingSeriesWrittenBetween(
        AcademicSchedule.empty(),
        imported,
      );
      final on = withClassReminders(
        imported,
        written,
        offsetMinutes: 15,
        updatedAt: at,
      );
      final moved = on.occurrences.where(
        (item) => item.state == OccurrenceState.moved,
      );
      expect(moved, isNotEmpty);
      expect(
        moved.every((item) => item.reminders.single.offsetMinutes == 15),
        isTrue,
      );
      final off = withClassReminders(
        on,
        written,
        offsetMinutes: null,
        updatedAt: at,
      );
      expect(classReminderOffsetOf(off, written), isNull);
      expect(projectAcademicReminderNotices(schedule: off, now: at), isEmpty);
    });

    test('a later re-import keeps the reminders the student chose', () {
      final imported = legacy().applyTo(
        AcademicSchedule.empty(),
        updatedAt: at,
      );
      final written = meetingSeriesWrittenBetween(
        AcademicSchedule.empty(),
        imported,
      );
      final on = withClassReminders(
        imported,
        written,
        offsetMinutes: 30,
        updatedAt: at,
      );
      final again = legacy().applyTo(
        on,
        updatedAt: at.add(const Duration(days: 1)),
      );
      expect(classReminderOffsetOf(again, written), 30);
      final general = CalendarClassFinder.find(
        googleCalendarStudentExport(),
        fallbackTimeZoneId: 'America/New_York',
        today: CivilDate(2026, 10, 3),
      );
      final first = general.applyTo(AcademicSchedule.empty(), updatedAt: at);
      final ids = meetingSeriesWrittenBetween(AcademicSchedule.empty(), first);
      final chosen = withClassReminders(
        first,
        ids,
        offsetMinutes: 10,
        updatedAt: at,
      );
      final refreshed = general.applyTo(chosen, updatedAt: at);
      expect(classReminderOffsetOf(refreshed, ids), 10);
    });

    test('only what the import wrote counts as written', () {
      final imported = legacy().applyTo(
        AcademicSchedule.empty(),
        updatedAt: at,
      );
      final today = CivilDate(2026, 10, 7);
      final term = QuickClassPlanner.termFor(
        imported,
        today,
        timeZoneId: 'America/New_York',
      );
      final typed = QuickClassPlanner.add(
        imported,
        QuickClassEntry(
          name: 'Bio lab',
          weekdays: {DateTime.wednesday},
          startMinute: 17 * 60,
          lengthMinutes: 110,
        ),
        term: term,
        today: today,
        updatedAt: at,
      );
      final written = meetingSeriesWrittenBetween(imported, typed);
      expect(written, hasLength(1));
      final on = withClassReminders(
        typed,
        written,
        offsetMinutes: 10,
        updatedAt: at,
      );
      expect(
        on.meetingSeries.where((series) => series.reminders.isNotEmpty),
        hasLength(1),
      );
    });

    test('the choice is saved in fields old builds already read', () {
      final imported = legacy().applyTo(
        AcademicSchedule.empty(),
        updatedAt: at,
      );
      final written = meetingSeriesWrittenBetween(
        AcademicSchedule.empty(),
        imported,
      );
      final on = withClassReminders(
        imported,
        written,
        offsetMinutes: 10,
        updatedAt: at,
      );
      final decoded = AcademicSchedule.fromJson(
        (jsonDecode(jsonEncode(on.toJson())) as Map).cast<String, dynamic>(),
      );
      expect(classReminderOffsetOf(decoded, written), 10);
      expect(
        projectAcademicReminderNotices(schedule: decoded, now: at),
        hasLength(168),
      );
    });

    test('offsets outside the offered three are refused', () {
      expect(() => classReminderRules('meeting_1', 45), throwsArgumentError);
      expect(classReminderRules('meeting_1', null), isEmpty);
    });
  });

  group('Calendar links keep their secret', () {
    test('the review names the kind of calendar, never the link', () {
      const secret = 'private-8f2c41d9a7e0b3c5';
      final google = CalendarLink.parse(
        'https://calendar.google.com/calendar/ical/jordan%40gmail.com/$secret/basic.ics',
      );
      expect(google.displayName, 'Google Calendar link');
      expect(google.displayName, isNot(contains(secret)));
      final school = CalendarLink.parse(
        'https://my.school.edu/schedule/feed/$secret.ics',
      );
      expect(school.displayName, 'my.school.edu');
      expect(
        PlatformCalendarLinkFetcher.timeLimit,
        const Duration(seconds: 20),
      );
      expect(PlatformCalendarLinkFetcher.maxBytes, 2 * 1024 * 1024);
    });

    test('a web page and a busy-only calendar each get a plain reason', () {
      expect(
        () => checkCalendarText('<!doctype html><title>Sign in</title>'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('web page'),
          ),
        ),
      );
      final busy = ClassScheduleReader.read(
        outlookExport(busyOnly: true),
        today: CivilDate(2026, 10, 3),
      );
      expect((busy as CalendarClassesRead).draft.titlesHidden, isTrue);
    });
  });
}
