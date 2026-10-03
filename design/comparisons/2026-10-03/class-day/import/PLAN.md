# Add your classes: the import track (2026-10-03)

The ask, verbatim (2026-10-03; check_quotes: OK-NEW in session c9150ef1):

> "make sure there's an easy way for other people to import/input their classes, the easier/more widely available the better"

His earlier ask that the current importer was built for, verbatim (2026-08-31; check_quotes: OK):

> "ability to edit in your own ics file for programmers who want to set their stuff up easily"

Both stay true in this plan. The programmer path keeps working exactly as it does now; every
other student gets a way in that does not need a programmer.

**Recommended slice for the next internal build:** one "Add your classes" sheet, reached from a
calm doorway in Plans (and later from the class-day first frame), with three ways in that share
one review: **a calendar file** (any standard .ics, picked in the app or opened from Mail, Files
or Safari), **a calendar link** (Google secret iCal address, Outlook ICS link, iCloud public
link, school feeds), and **typing them in** (one name line, day chips, a start time, a length).
The review is "Pick your classes": repeating events grouped into courses, the class-like ones
already checked, everyday life folded away unchecked. Room of Days files still apply through the
original importer. Next slice after that: **From this iPhone's Calendar** (EventKit), feeding
the same review.

Everything below was built and rendered in a private copy (`C:/tmp/cdj/import`, from c0a041a).
Nothing under the worktree's `lib/` changed.

---

## 1. Map: how a student gets classes in today (c0a041a)

### The paths

| Path | Where | What it accepts |
|---|---|---|
| Import from inside the app | Plans → ADD → `DaybookAddChoiceDialog` → IMPORT CLASSES (`lib/daybook/widgets/daybook_add_choice_dialog.dart:117-123`) → `_showAcademicScheduleImport` (`lib/screens/calendar.dart:1307`, routed at `:1371`) → `AcademicScheduleImportDialog` (`lib/academic_calendar/widgets/academic_schedule_import_dialog.dart`): CHOOSE .ICS FILE `:362`, review, IMPORT SCHEDULE `:596` | Only Room of Days files (see "Why ordinary exports fail") |
| Open a file from Mail, Files or Safari | iOS document type for `public.calendar-event` / `com.apple.ical.ics` (`ios/Runner/Info.plist:11-25`), `AcademicScheduleFileBridge` (`ios/Runner/AppDelegate.swift:8-100`), `AcademicScheduleFileInbox` (`lib/academic_calendar/import/academic_schedule_file_inbox.dart`), shell jumps to Plans (`lib/screens/shell.dart:314-318`), same review dialog | Same restriction |
| Editable starter file | GET EDITABLE STARTER FILE (`academic_schedule_import_dialog.dart:392`), template `lib/academic_calendar/import/academic_schedule_ics_import.dart:14-40` | His programmer path |
| Type one class | Plans → ADD → CLASS (`daybook_add_choice_dialog.dart:107-115`) → `AddAcademicMeetingDialog` (`lib/academic_calendar/widgets/academic_calendar_sections.dart:2720`) | Everyone, slowly |
| Onboarding | Never mentions school: the only question is "How full are your days, usually?" (`lib/widgets/onboarding_flow.dart:394`) | Nothing |
| Quests board, Goals, widget | No way in. The Day Ledger widget only shows a next class once classes exist | Nothing |

`AcademicAddChoiceDialog` (`academic_calendar_sections.dart:167`) has no callers; Plans uses the
Daybook version.

### Why ordinary exports fail (`academic_schedule_ics_import.dart`)

- `X-ROOM-OF-DAYS-TERM-START` and `-TERM-END` are parsed unconditionally (`:403-410`); an empty
  value throws in `_parseCivilDate` (`:594`). No ordinary export has them.
- `X-ROOM-OF-DAYS-COURSE-CODE` and `-COURSE-TITLE` are required (`:411-418`); SUMMARY is never read.
- Any `TZID` other than America/New_York throws (`:564-567`): every student outside Eastern time,
  and every Outlook export ("Eastern Standard Time" is a Windows name), fails.
- `RRULE` must be WEEKLY with BYDAY and UNTIL (`:391-394`); COUNT, open-ended series and
  one-event-per-meeting exports are dropped.
- Nested `VALARM` blocks are read into the event (the reader is flat).
- The student sees only "That file isn’t a Room of Days class schedule yet." (`academic_schedule_import_dialog.dart:61`, `:105`).

The manual dialog also assumes the East Coast: a new term is created in America/New_York
(`academic_calendar_sections.dart:4859`), and a class starts on the term's first day
(`:2958`), so a class added in October back-fills August and September.

### Taps today versus the prototype

| Job | Today | Prototype |
|---|---|---|
| Ordinary Google, Outlook or portal export | Not possible | File: doorway, FROM A CALENDAR FILE, pick, ADD N COURSES, SEE MY WEEK (5 taps plus finding the file). Opened from Mail or Files: about 3 taps |
| Calendar link | Not possible | Doorway, FROM A CALENDAR LINK, PASTE, READ THIS CALENDAR, ADD N COURSES, SEE MY WEEK: 6 taps |
| Room of Days file | PLANS, ADD, IMPORT CLASSES, CHOOSE .ICS FILE, pick, IMPORT SCHEDULE: 6 taps | Same file, same importer: doorway, FROM A CALENDAR FILE, pick, ADD 6 COURSES: 4 taps (or Open In) |
| Type one weekly meeting | PLANS, ADD, CLASS, then term fields, code field, title field, extra day chips, START (dial: hour, minute, OK), END (dial: hour, minute, OK), SAVE: about 14 to 16 taps and 2 typed fields | One name field, 1 to 3 day chips, a length chip, ADD THIS CLASS: about 5 taps and 1 typed field (plus 3 if the start is not the default). No end-time dial, no term setup |
| Mika's 12 weekly meetings by hand | About 180 taps | About 70 to 100 taps; his file is the 4-tap path anyway |

---

## 2. What students actually have (research)

Reach is my judgment from the sources, not measured; no survey data was found.

| Source | How a student gets it | Reach | Effort for us | iOS requirements | Privacy | Failure modes |
|---|---|---|---|---|---|---|
| **School portal .ics** | Some portals export: Purdue Timetabling "Export iCalendar"; Michigan Schedule Builder export; Penn State LionPATH emails an .ics; some Workday setups have "Download ICS". Many do not: Rutgers WebReg has no export (students use the "Calendarize WebReg" extension), Banner usually needs an extension | Medium, uneven by school | Dart only (parser plus review) | None new: .ics is already a registered document type | File stays on device | One-event-per-meeting exports, floating times, missing holidays (Michigan says breaks are not reflected), UIDs that change between exports |
| **Google Calendar export** | Export works on a computer only ("You can't export from the Google Calendar app"); gives an .ics (zip for all calendars) | Medium (students who keep classes in Google) | Same parser | None | File stays on device | Mixes life events with classes; often several calendars |
| **Google secret iCal address** | Computer: Settings, the calendar, Integrate calendar, "Secret address in iCal format" | Same people, no file to move | Small: one HTTPS GET | HTTPS only (ATS); webcal is upgraded | The link is a secret: read once, never stored | Hard to find on a phone; public address errors on private calendars |
| **Outlook publish** | Settings, Shared calendars, Publish a calendar: HTML and ICS links | Medium at Microsoft 365 schools | Same | Same | Link is public to anyone who has it | Default detail is "Can view when I'm busy": every event is "Busy" (detected; the review says so). Windows zone names (mapped) |
| **iCloud public calendar** | Calendar app: share as Public Calendar, copy the webcal link | Low to medium | Same | Same | Makes that calendar public | Students rarely do this; iPhone Calendar has no export |
| **Canvas calendar feed** | Calendar, Calendar Feed (a URL) | Very high (LMS) | Same parser; handled as "no classes" | Same | Feed URL is private | It holds assignments and events, not class meeting times. Up to 366 days ahead, 1,000 items. Useful later for due dates |
| **iPhone Calendar (EventKit)** | Anything already on the phone: iCloud, Google or Exchange accounts added in Settings, subscribed feeds | Highest among students with any calendar; zero hunting | Native: a small Swift channel (like the existing file bridge) or `device_calendar_plus` 0.10.1 (iOS 13+, "maintained replacement for the abandoned device_calendar"); built and tested only through Codemagic and a device | iOS 17+: `requestFullAccessToEvents` and `NSCalendarsFullAccessUsageDescription`; older API fails when linked against iOS 17. Write-only access cannot read | Full read of every calendar is a big ask for a local-first app; nothing leaves the phone, so the App Store label can stay "Data Not Collected" | Google Calendar app users who never added the account to iOS have nothing there; prompt denied once means Settings |
| **Screenshot or PDF of a schedule** | Everyone has one | Very high in theory | High: Apple Vision `VNRecognizeTextRequest` is free and on-device (100 to 300 ms) or ML Kit; then grid geometry to days and times | Native code | On-device | Weekly grid layouts lose their structure in OCR; times and room numbers mix. Not worth it before the above. Cheap experiment instead: iOS Live Text (iPhone XS and later, iOS 15+) already lets a student copy text from a screenshot; a "paste schedule text" box could reuse the name reader |
| **Typing them in** | Everyone | 100% | Small | None | On-device | Takes about a minute; needs a fast form |

---

## 3. Ranking (ease times reach)

1. **Type them in, fast.** The floor for every student, including Rutgers students whose portal
   has no export. Must exist in the first frame of the sheet.
2. **Any calendar file**, picked or opened from Mail, Files or Safari. Covers portal exports and
   computer-side Google and Outlook exports. Dart only, fully testable here.
3. **iPhone Calendar (EventKit).** Easiest for anyone whose classes already sit in a phone
   calendar, but it needs native code we can only test through Codemagic and a device, plus a
   full-access prompt. It reuses the review built in 2: EventKit returns expanded occurrences,
   which is exactly what the prototype's "gathered" path already groups into weekly series.
4. **Calendar link.** Same sources as 2 with no file to move; small (one GET). Ships with 2.
5. **Screenshot or PDF.** Highest theoretical reach, lowest reliability. Later, if at all.
6. **Canvas feed.** Recognized and answered calmly now; later it can bring due dates in as
   assignments.

---

## 4. The recommended slice

**What ships in the next internal build**

- `AddClassesDoorway` in Plans when there are no classes yet: "YOUR CLASSES / Add them once and
  each one shows up on its day." Brass and glass, no honey fill, no nag. The class-day first
  frame (the sibling concepts) opens the same sheet from its own empty state.
- `AddClassesSheet` with three ways in: FROM A CALENDAR FILE, FROM A CALENDAR LINK, TYPE THEM
  IN, and a folded "WHERE DO I FIND MINE?" with one plain line each for a school portal, Google,
  Outlook and Canvas, plus the Room of Days .ics starter for programmers.
- "Pick your classes": term card (name, dates, meeting count, CHANGE END), one row per course
  with every weekly meeting listed, the app's open ring as the check, "PROBABLY NOT CLASSES · N"
  folded, one quiet line for what stays out ("1 one-time event and 2 all-day events"), one honey
  button "ADD N COURSES".
- Result: "4 courses in Plans", "Fall 2026, through Dec 4. Your next class is CS 225, tomorrow at
  10:00 AM.", a five-day strip with the week's class counts, SEE MY WEEK.
- Every file opened from outside goes through this sheet; Room of Days files show "Your Room of
  Days file" and apply through `AcademicScheduleIcsImporter` unchanged (same stable IDs, so his
  already-imported schedule is refreshed, never duplicated).
- Gentle edges: a Canvas feed gets "No weekly classes in this one. It holds 4 due dates and 1
  one-time event. Canvas feeds carry assignments, not the times your classes meet." with TYPE
  THEM IN; a busy-only Outlook calendar gets a note to publish with titles; a web page instead of
  a calendar gets "That link opened a web page, not a calendar."

**How the reader decides what is a class** (`calendar_class_finder.dart`, `_score`): weekly at
a fixed time (+2), a course code in the title (+3), a class word such as lecture, lab or
recitation (+2), 40 to 200 minutes (+1), weekdays (+1), six to 26 weeks long (+1), a campus
place (+1); everyday words such as gym, shift, club, standup (-3) and lesson, study, meeting
(-2), weekends, off hours and very long events count down. Four or more is checked. The review
is the safety net: every repeating event is listed and one tap changes it.

**What it reads**: real RFC 5545 (folded lines, quoted parameters, nested VALARM and VTIMEZONE),
TZID in IANA, Mozilla-prefixed or Windows form, X-WR-TIMEZONE, UTC and floating times (device
zone), DATE and DATE-TIME UNTIL, COUNT, INTERVAL (every other week), DAILY with BYDAY, EXDATE
lists, moved and cancelled RECURRENCE-ID overrides, DURATION, and exports that write every
meeting as its own event (gathered into weekly series, with holes kept as skipped dates). Course
codes from "CS 206", "ECE345", "MATH-151", "CHEM 161H", "14:332:345"; sections from "LEC 001",
"Sec. 2"; titles stripped of "(Lecture)", "- Lab" tags; short initials ("LSS", "DS II") only when
the title has no code.

**Copy rules held**: no em dashes, no "not this, but this", none of the banned words. Mika's
chat wording was not used as copy.

---

## 5. Prototype, tests and frames

### Files (private copy `C:/tmp/cdj/import`; snapshot in `prototype/` next to this file)

New:
- `lib/academic_calendar/import/calendar_class_finder.dart`: `ClassScheduleReader` (routes Room of Days files to the original importer), `CalendarClassFinder`, `CalendarClassImportDraft` (selection, term, `withTermEnd`, `projectedOccurrenceCount`, idempotent `applyTo`), `ClassNameReader`, the RFC 5545 reader and zone mapping.
- `lib/academic_calendar/import/calendar_link.dart`, `calendar_link_fetch_io.dart`, `calendar_link_fetch_stub.dart`: link parsing (webcal and http to https, source detection, Google page-link guard), one HTTPS GET with a 20 s limit and 2 MB cap, web stub.
- `lib/academic_calendar/import/quick_class_entry.dart`: `QuickClassEntry`, `QuickClassPlanner` (term inferred, class starts this week, joins an existing course by code or name).
- `lib/academic_calendar/widgets/add_classes_sheet.dart`: the sheet, its stages, `AddClassesDoorway`.
- `test/calendar_class_import_test.dart`, `test/support/calendar_export_samples.dart` (a Google export with exceptions, overrides, COUNT, DAILY+BYDAY, VALARM, folded lines and everyday events; a Canvas feed; a portal export with one event per meeting and a fortnightly lab; an Outlook export with Windows zones, plus its busy-only form).
- `test/design_renders/import_journey_test.dart`, `test/design_renders/import_sheet.py`.

Changed (`prototype/modified-files.diff`, 134 lines):
- `lib/screens/calendar.dart`: the doorway under the Daybook header; IMPORT CLASSES and every incoming file open the sheet; `_saveAddedClasses`. The old dialog and `_saveAcademicScheduleImport` are left in place, unreferenced.
- `lib/daybook/widgets/daybook_add_choice_dialog.dart`: the row reads "ADD YOUR CLASSES / From a calendar file, a link, or typed in".

### Test result

`flutter test test/calendar_class_import_test.dart` in the copy: **24 passed, 0 failed**.
Highlights: Mika's Rutgers fixture still routes to the original importer and gives 6 courses, 12
weekly meetings, **168** meetings; the general reader, run on the same file, agrees meeting for
meeting (same sorted list of date, start, end and code, designated days included). The Google
export finds exactly the five class meetings (CS 225 lecture and lab, MATH 241, Intro to
Psychology, RHET 105) and leaves gym, work shift, book club and a lab standup unchecked; 145
meetings with Labor Day and Thanksgiving skipped, the Oct 15 midterm moved to 1:00 PM, Nov 26
cancelled, COUNT=15 honored; importing twice changes nothing. The Canvas feed has no candidates
and 4 due dates; the portal export gathers BIO 110 into MWF lectures with one hole and a lab
every other week; Outlook resolves to America/New_York and the busy-only form is flagged.
Only this file and the render file were run, never the full suite. `flutter analyze` on every
touched path: no issues.

### Frames (`I01` to `I14`, `sheet.png`)

Rendered by `flutter test --dart-define=CLASS_DAY_RENDERS=true test/design_renders/import_journey_test.dart`
in the copy, with the shared class-day harness (real `LifeRpgApp`, bundled fonts, 393 x 852 pt
@3x, safe areas), Sunday Oct 4 2026 19:30. 4 render tests passed.

1. The way in: I01 Plans with the doorway, I02 the three ways, I03 help open.
2. A calendar link: I04 pasted, I05 Pick your classes, I06 probably not classes opened, I07 the
   result, I08 Plans WEEK after import (NEXT CLASS · TOMORROW · CS 225, in Chicago campus time).
3. Typing: I09 empty form, I10 one added and the next half typed, I11 result.
4. Edges: I12 a Canvas feed, I13 Mika's own Room of Days file opened from Files, I14 its result
   ("6 courses in Plans … Your next class is 14:332:361, tomorrow at 8:30 AM.").

---

## 6. Files to touch for the build

The prototype files above, moved into the build branch as they are, plus:
- `lib/screens/calendar.dart`: the doorway and routing (diff above); then delete or keep the old dialog on purpose.
- Result screen: add the class-reminder choice the old review had (see departures).
- The class-day first frame (sibling concept) and onboarding: one "I have classes" doorway that opens the same sheet. Small.
- `ios/Runner/Info.plist`: nothing for this slice. The EventKit slice adds `NSCalendarsFullAccessUsageDescription` and a Swift channel.
- Tests: the unit file above joins the suite; a widget test for selection toggles and the busy-only note.

---

## 7. Risks and open questions

- **Wrong guesses in the review.** "Piano lesson" style events can look like classes. The review lists every repeating event and one tap fixes it; the score is explainable and tested.
- **Two terms in one export.** A full Google export can hold last spring and this fall. The draft makes one term from what is checked; the build should split by date clusters and pre-check only the current or next term. Not built yet.
- **UIDs that change between portal exports** would duplicate classes on re-import. The build should match by course code, weekday and start time before creating a meeting.
- **Floating times** use the phone's zone; a student importing while travelling gets the travel zone. Shown in Plans as campus time when zones differ (I08).
- **Links**: Google's secret address is only visible on a computer; Outlook defaults to busy-only; iCloud links make a calendar public; school feeds on plain http are upgraded to https and may fail. Each has a plain message. The link is never stored; keep it that way unless a "keep in sync" feature is chosen on purpose.
- **Web build**: calendar hosts send no CORS headers, so the PWA offers the file path instead (stub).
- **Clock**: the reader takes "today" from `Clock.now()`.

---

## 8. Handoff

**Verified now**
- 24 unit tests pass in the copy, including Mika's fixture at 168 meetings on both paths.
- 14 frames rendered in the real app at phone size; each looked at full size. Fixed during the pass: a doubled title and label, length chips stretching to full width, a weekday list wrapping, a false line about reminders in the result, a tap that never reached the sheet because flutter_tester answers the time-zone channel on real time (the render mocks it).
- The worktree's `lib/` and git state are untouched (`git status`: only the untracked design and render folders).

**Inferred**
- Reach and effort estimates in section 2 come from the sources below, not measurement.
- Tap counts are counted from the code paths, not from a device.

**Remaining gate**
- Device: the file picker, Open In and a live link fetch on an iPhone (Codemagic build); the feel of the sheet, sound and haptics. flutter_tester has no sound, haptics, SF Pro or 120 Hz.
- Mika's yes on the slice, and on whether EventKit's full-calendar prompt is acceptable for slice two.

**Departures**
- The old review's class-reminder switch is not in the new review (kept calmer); it belongs on the result screen before this ships. Inferred.
- The quick add starts a class this week instead of on the term's first day, so nothing earlier fills with meetings nobody marked. Inferred, matches the never-punish rule.
- Course codes are invented as initials when a title has none, because the schedule requires a code; the review hides them and Plans shows them small. Default.
- The doorway lives in Plans only in this prototype; the first-frame entry belongs to the class-day concepts.

---

## Sources

- Google Calendar Help, Export events: https://support.google.com/calendar/answer/37111?hl=en
- Google Calendar Help, Sync with computer programs (secret iCal address): https://support.google.com/calendar/answer/37648?hl=en
- Microsoft Support, Share your calendar in Outlook on the web (publish, ICS link, detail levels): https://support.microsoft.com/en-us/office/share-your-calendar-in-outlook-on-the-web-7ecef8ae-139c-40d9-bae2-a23977ee58d5
- Instructure Community, Canvas calendar feed: https://community.canvaslms.com/t5/Student-Guide/How-do-I-subscribe-to-the-Calendar-feed-using-Outlook-com/ta-p/285 and limits (366 days, 1,000 items) via https://lifeload.io/blog/how-to-add-canvas-calendar-to-google-calendar/
- Canvas feed format (date-only and zero-length assignment events, `event-assignment-` UIDs): https://github.com/Ddundee/look/pull/7
- Expo changelog, iOS 17 calendar permissions (full access, write-only, new request APIs): https://expo.dev/changelog/2023-09-28-new-xcode-ios
- Apple Developer Forums, requestFullAccessToEvents on iOS 17: https://developer.apple.com/forums/thread/742371
- device_calendar_plus on pub.dev: https://pub.dev/packages/device_calendar_plus ; device_calendar changelog (4.3.3 iOS 17 fix): https://pub.dev/packages/device_calendar/changelog
- iPhone Calendar cannot export: https://news.ycombinator.com/item?id=36116650 and https://discussions.apple.com/thread/252561755
- Michigan Schedule Builder calendar export: https://atlas.ai.umich.edu/whats-new/note/schedule-builder-calendar-export-available/
- Penn State LionPATH schedule download (search result summary; page returned 403): https://hazleton.psu.edu/node/4748
- Purdue calendar feed: https://purdue.edu/science/scienceit/web/student-schedule.html
- Rutgers WebReg has no native export; Calendarize WebReg extension: https://adoryvo.github.io/calendarize-webreg/ and its source https://github.com/AdoryVo/calendarize-webreg/blob/main/calendarize.js
- Banner exports through extensions: https://abelweldaregay.github.io/Banner-GCal-Schedule-Importer/help.html
- Workday Schedule Exporter (WPI "Download ICS"): https://chromewebstore.google.com/detail/workday-schedule-exporter/elloafhmffcedcmbdepancjijjccmail?hl=en
- Apple Vision text recognition, on-device speed: https://blakecrosley.com/blog/vision-framework-built-in and https://atomicrobot.com/blog/optical-text-recognition-in-ios/
- Live Text requirements: https://support.apple.com/guide/iphone/interact-photos-live-text-visual-iph37fdd714b/15.0/ios/15.0
- ML Kit text recognition for Flutter: https://pub.dev/packages/google_ml_kit
