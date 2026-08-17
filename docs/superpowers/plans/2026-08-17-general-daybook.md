# Room of Days General Daybook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn Plans into a useful device-local calendar for anyone by adding neutral events, one-off tasks, weekly event recurrence, manual locations, and one unified rendering projection while preserving all academic and Quest behavior.

**Architecture:** Extract the neutral civil-date value, add focused Daybook domain types, and keep `AcademicSchedule` as the backward-compatible schema-5 persistence envelope. Compose neutral, academic, study, and Quest sources only in `daybook/presentation/`, then make month, selected-day, and span views consume that projection. General forms and rows live under `lib/daybook/widgets/`; specialized School flows remain in `lib/academic_calendar/`.

**Tech Stack:** Flutter/Dart, SharedPreferences JSON, `url_launcher`, `flutter_test`, existing academic recurrence/time-zone helpers.

## Global Constraints

- The visible header is `DAYBOOK` with default subtitle `Events, tasks, classes, and places in one view`; an active selected term name replaces only the subtitle.
- The add sheet title is `ADD TO YOUR DAYBOOK`, ordered `EVENT`, `TASK`, a quiet `SCHOOL` rule, then `CLASS`, `ASSIGNMENT`, `EXAM`.
- General task completion never creates a Quest, awards XP, changes streaks/stats, or mutates Quest completion.
- Support one-off and weekly events only. Defer daily/monthly/yearly, recurring tasks, and `THIS AND FUTURE EVENTS`.
- All-day event end dates are exclusive. Timed events end on the same date or the next date only and must end after they start.
- Past incomplete tasks remain on their due date and also appear under `STILL OPEN` on the current date without red/failure language.
- `lib/daybook/domain/` must not import the academic domain. `lib/daybook/presentation/` may import both domains and Quest models.
- The schedule stays device-local under `room_of_days_academic_schedule_v1`; do not add it to `GameState`, exports, Firestore, or cloud merge.
- Schema 1–4 data must decode unchanged with empty general collections; one malformed schema-5 neutral record preserves a raw recovery copy and all other valid records.
- Existing class occurrence IDs/tombstones, School actions, study planning, Room Notes handoff identifiers, and academic reminders remain compatible.
- Manual locations work without Firebase, Google, a network, or permission. No device location permissions are added.
- Visible directions copy is `GET DIRECTIONS`; Google/Apple routing follows the predicates in Task 7.
- Do not edit or commit unrelated dirty design/audit files.
- Every behavior change starts with a focused failing test.

---

### Task 1: Extract neutral date and add place/event/task values

**Files:**
- Create: `lib/daybook/domain/civil_date.dart`
- Create: `lib/daybook/domain/daybook_place.dart`
- Create: `lib/daybook/adapters/campus_place_adapter.dart`
- Create: `lib/daybook/domain/daybook_event.dart`
- Create: `lib/daybook/domain/daybook_task.dart`
- Modify: `lib/academic_calendar/domain/academic_schedule.dart:1-72`
- Create: `test/daybook_domain_test.dart`

**Interfaces:**
- Produces: `CivilDate`; `DaybookPlace`; `CampusPlaceDaybookAdapter`; `DaybookEvent`; `WeeklyEventRule`; `DaybookEventException`; `DaybookEventOccurrence`; `DaybookTask`; JSON and immutable copy APIs.
- Compatibility: `academic_schedule.dart` exports `civil_date.dart`, so existing imports continue to resolve `CivilDate`.

- [ ] **Step 1: Write failing value/validation/adapter tests**

Cover these literal cases in `test/daybook_domain_test.dart`:

```dart
expect(CivilDate.parse('2026-08-17').addDays(1).toString(), '2026-08-18');
expect(event.toJson(), containsPair('endDate', '2026-08-18'));
expect(() => sameDayTimed.copyWith(endMinute: 540), throwsArgumentError);
expect(() => event.copyWith(endDate: CivilDate(2026, 8, 19)), throwsArgumentError);
expect(task.complete(at: completedAt).undoCompletion().dueDate, CivilDate(2026, 8, 17));
expect(CampusPlaceDaybookAdapter.toCampusPlace(
  CampusPlaceDaybookAdapter.fromCampusPlace(legacy),
  original: legacy,
).toJson(), legacy.toJson());
```

Use a legacy `CampusPlace` fixture containing label, building, room, address, latitude, longitude, mapsProvider, placeId, and campusCode.

- [ ] **Step 2: Run the new test**

Run: `flutter test test/daybook_domain_test.dart`

Expected: FAIL because the neutral files/types do not exist.

- [ ] **Step 3: Move `CivilDate` without breaking its old import surface**

Move the current implementation verbatim to `civil_date.dart`, then begin `academic_schedule.dart` with:

```dart
import 'package:emberkeep/daybook/domain/civil_date.dart';
export 'package:emberkeep/daybook/domain/civil_date.dart';
```

- [ ] **Step 4: Implement the neutral values**

Use these contracts exactly:

```dart
enum DaybookPlaceProvider { google }

final class DaybookPlace {
  DaybookPlace({
    required String savedName,
    String? routingText,
    String? building,
    String? room,
    this.provider,
    String? providerPlaceId,
  });
  final String savedName;
  final String? routingText, building, room, providerPlaceId;
  final DaybookPlaceProvider? provider;
  bool get hasGoogleDestination;
  bool get hasAppleDestination;
  Map<String, dynamic> toJson();
}

final class WeeklyEventRule {
  WeeklyEventRule({required Set<int> weekdays, this.intervalWeeks = 1, this.endsOn});
  final Set<int> weekdays;
  final int intervalWeeks;
  final CivilDate? endsOn;
}

enum DaybookEventOccurrenceState { scheduled, moved, cancelled }

final class DaybookEventException {
  DaybookEventException({
    required String occurrenceKey,
    required CivilDate originalDate,
    required DaybookEventOccurrenceState state,
    CivilDate? movedStartDate,
    CivilDate? movedEndDate,
    int? movedStartMinute,
    int? movedEndMinute,
    DateTime? tombstonedAt,
    required DateTime updatedAt,
  });
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
}

final class DaybookEvent {
  DaybookEvent({
    required String eventId,
    required String title,
    required CivilDate startDate,
    required CivilDate endDate,
    required String timeZoneId,
    required bool allDay,
    int? startMinute,
    int? endMinute,
    String? notes,
    DaybookPlace? place,
    WeeklyEventRule? weeklyRule,
    List<DaybookEventException> exceptions = const [],
    required DateTime createdAt,
    required DateTime updatedAt,
  });
  DaybookEventOccurrence occurrenceFor(CivilDate originalDate);
}

final class DaybookTask {
  DaybookTask({required String taskId, required String title, required CivilDate dueDate,
    int? dueMinute, String? notes, DaybookPlace? place, DateTime? completedAt,
    required DateTime createdAt, required DateTime updatedAt});
  bool get completed;
  DaybookTask complete({required DateTime at});
  DaybookTask undoCompletion({required DateTime at});
}
```

For an all-day event require `endDate > startDate` and null time fields. For timed events require both minutes in `0..1439`, `endDate` equal/start+1, and a positive instant ordering. Persist UTC timestamps as ISO-8601 strings.

Keep the academic adapter outside `lib/daybook/domain/`:

```dart
abstract final class CampusPlaceDaybookAdapter {
  static DaybookPlace fromCampusPlace(CampusPlace source);
  static CampusPlace toCampusPlace(
    DaybookPlace source, {
    required CampusPlace original,
  });
}
```

The adapter imports both domains and preserves `original.latitude`,
`original.longitude`, and `original.campusCode` when neutral fields are edited.

- [ ] **Step 5: Run domain and academic compatibility tests**

Run: `flutter test test/daybook_domain_test.dart test/academic_schedule_test.dart`

Expected: PASS; existing `CivilDate` users compile unchanged.

- [ ] **Step 6: Commit**

```powershell
git add lib/daybook/domain lib/daybook/adapters lib/academic_calendar/domain/academic_schedule.dart test/daybook_domain_test.dart
git commit -m "feat: add neutral daybook values"
```

### Task 2: Materialize weekly events and migrate the local envelope to schema 5

**Files:**
- Create: `lib/daybook/domain/weekly_event_materializer.dart`
- Modify: `lib/academic_calendar/domain/academic_schedule.dart:1053-1900`
- Modify: `lib/academic_calendar/data/academic_schedule_repository.dart`
- Modify: `test/daybook_domain_test.dart`
- Modify: `test/academic_schedule_test.dart`

**Interfaces:**
- Consumes: Task 1 neutral values.
- Produces: `WeeklyEventMaterializer.between`, `AcademicSchedule.events`, `AcademicSchedule.tasks`, neutral mutation methods, `AcademicScheduleDecodeResult`, `LocalAcademicScheduleRepository.lastRecoveredRecordCount`.

- [ ] **Step 1: Write failing recurrence, migration, and recovery tests**

Use literal expected occurrence keys:

```dart
expect(
  WeeklyEventMaterializer.between(event, CivilDate(2026, 8, 1), CivilDate(2026, 8, 31))
      .map((item) => item.occurrenceKey),
  ['event_team@2026-08-03', 'event_team@2026-08-10', 'event_team@2026-08-17', 'event_team@2026-08-24', 'event_team@2026-08-31'],
);
```

Assert a moved and cancelled exception survives rebuilding, editing the weekday tombstones removed generated dates, schemas 1–4 have empty `events/tasks`, schema 5 round-trips academic and general data, and every existing academic mutation preserves neutral lists.

Seed `SharedPreferences` with a valid schema-5 root containing one valid event, one malformed event, one valid task, and a class. Assert load returns the valid records/class, writes the original blob to the recovery key, and sets `lastRecoveredRecordCount == 1`.

- [ ] **Step 2: Run focused tests**

Run: `flutter test test/daybook_domain_test.dart test/academic_schedule_test.dart`

Expected: FAIL at missing materializer/schema-5 fields and tolerant recovery.

- [ ] **Step 3: Implement bounded weekly materialization**

```dart
abstract final class WeeklyEventMaterializer {
  static List<DaybookEventOccurrence> between(
    DaybookEvent event,
    CivilDate first,
    CivilDate last,
  );
}
```

Anchor interval weeks to `event.startDate.startOfWeek(DateTime.monday)`. Generate only the requested inclusive range, apply one exception by stable occurrence key, carry same-day/overnight or all-day duration forward, and sort by start date/time/key. Never materialize an unbounded series into persistent storage.

- [ ] **Step 4: Add schema-5 collections and mutations**

Set `AcademicSchedule.currentSchema = 5`; add `events` and `tasks` defaults to the constructor/empty/toJson/decode. Add:

```dart
List<DaybookEventOccurrence> eventOccurrencesBetween(CivilDate first, CivilDate last);
List<DaybookTask> tasksOn(CivilDate date);
AcademicSchedule putEvent(DaybookEvent event);
AcademicSchedule deleteEvent(String eventId);
AcademicSchedule moveEventOccurrence({
  required String eventId,
  required String occurrenceKey,
  required CivilDate startDate,
  required CivilDate endDate,
  int? startMinute,
  int? endMinute,
  required DateTime updatedAt,
});
AcademicSchedule cancelEventOccurrence({
  required String eventId,
  required String occurrenceKey,
  required DateTime updatedAt,
});
AcademicSchedule restoreEventOccurrence({
  required String eventId,
  required String occurrenceKey,
  required DateTime updatedAt,
});
AcademicSchedule putTask(DaybookTask task);
AcademicSchedule deleteTask(String taskId);
```

Use one private reconstruction helper that always carries `events` and `tasks`; replace every existing academic mutation reconstruction with it so neutral collections cannot disappear.

- [ ] **Step 5: Add per-record tolerant neutral decoding**

```dart
final class AcademicScheduleDecodeResult {
  const AcademicScheduleDecodeResult(this.schedule, this.droppedNeutralRecords);
  final AcademicSchedule schedule;
  final int droppedNeutralRecords;
}
```

Decode the academic graph as today. For schema 5, catch errors around each individual neutral record only. In the local repository, if `droppedNeutralRecords > 0`, copy the original raw string to the existing corrupt/recovery key once, set `lastRecoveredRecordCount`, emit a `debugPrint`, and return the partial schedule. Preserve existing empty+backup behavior for invalid JSON/root/academic graph.

- [ ] **Step 6: Run focused and repository tests**

Run: `flutter test test/daybook_domain_test.dart test/academic_schedule_test.dart`

Expected: PASS with stable recurrence keys, no lost academic/general data, and recovery count 1.

- [ ] **Step 7: Commit**

```powershell
git add lib/daybook/domain/weekly_event_materializer.dart lib/academic_calendar/domain/academic_schedule.dart lib/academic_calendar/data/academic_schedule_repository.dart test/daybook_domain_test.dart test/academic_schedule_test.dart
git commit -m "feat: persist general daybook entries"
```

### Task 3: Build the one-calendar range projection

**Files:**
- Create: `lib/daybook/presentation/daybook_range_projection.dart`
- Create: `test/daybook_projection_test.dart`

**Interfaces:**
- Consumes: `AcademicSchedule`, `List<Quest>`, inclusive `CivilDate first/last`, `DateTime now`.
- Produces: `DaybookRangeProjection.build`, `DaybookRange`, `DaybookDay`, `DaybookEntry`, `DaybookDaySummary`, typed source/action identifiers.

- [ ] **Step 1: Write failing projection tests**

Build one day containing an all-day event, timed event, class, study block, task, academic work, and Quest plan. Assert literal ordering: all-day event; timed entries by minute; due items by due minute; untimed tasks/plans by title. Assert clipped overnight minutes, month weight thresholds (none/light/moderate/full at 0/1–119/120–239/240+), deadline state, conflict names, and semantic counts. Assert an overdue task appears both on its due day and current day with `section == DaybookSection.stillOpen`, without changing `dueDate`.

- [ ] **Step 2: Run projection tests**

Run: `flutter test test/daybook_projection_test.dart`

Expected: FAIL because the projection types do not exist.

- [ ] **Step 3: Implement neutral projection records**

```dart
enum DaybookSourceKind { event, task, classOccurrence, academicWork, studyBlock, questPlan }
enum DaybookSection { allDay, timed, due, stillOpen }
enum DaybookDayWeight { none, light, moderate, full }

final class DaybookConflict {
  const DaybookConflict(this.leftDisplayKey, this.rightDisplayKey,
    this.message);
  final String leftDisplayKey;
  final String rightDisplayKey;
  final String message;
}

final class DaybookEntry {
  const DaybookEntry({required this.displayKey, required this.sourceKind,
    required this.sourceId, required this.title, required this.section,
    this.startMinute, this.endMinute, this.completed = false,
    this.cancelled = false, this.place, required this.action});
  final DaybookActionTarget action;
}

final class DaybookDaySummary {
  const DaybookDaySummary({required this.scheduledMinutes,
    required this.weight, required this.hasDeadline,
    required this.conflicts, required this.semanticLabel});
  final int scheduledMinutes;
  final DaybookDayWeight weight;
  final bool hasDeadline;
  final List<DaybookConflict> conflicts;
  final String semanticLabel;
}

final class DaybookDay {
  const DaybookDay({required this.date, required this.entries,
    required this.summary});
  final CivilDate date;
  final List<DaybookEntry> entries;
  final DaybookDaySummary summary;
}

final class DaybookRange {
  const DaybookRange({required this.first, required this.last,
    required this.days});
  final CivilDate first;
  final CivilDate last;
  final Map<CivilDate, DaybookDay> days;
  DaybookDay dayOn(CivilDate date);
}

sealed class DaybookActionTarget {
  const DaybookActionTarget();
}
final class DaybookEventAction extends DaybookActionTarget {
  const DaybookEventAction(this.eventId, this.occurrenceKey);
  final String eventId;
  final String occurrenceKey;
}
final class DaybookTaskAction extends DaybookActionTarget {
  const DaybookTaskAction(this.taskId);
  final String taskId;
}
final class AcademicOccurrenceAction extends DaybookActionTarget {
  const AcademicOccurrenceAction(this.occurrenceKey);
  final String occurrenceKey;
}
final class AcademicWorkAction extends DaybookActionTarget {
  const AcademicWorkAction(this.workId);
  final String workId;
}
final class AcademicStudyAction extends DaybookActionTarget {
  const AcademicStudyAction(this.studyBlockId);
  final String studyBlockId;
}
final class QuestPlanAction extends DaybookActionTarget {
  const QuestPlanAction(this.questId);
  final String questId;
}

final class DaybookRangeProjection {
  static DaybookRange build({required AcademicSchedule schedule,
    required List<Quest> quests, required CivilDate first,
    required CivilDate last, required DateTime now});
}
```

The projection owns source ordering, shared minute totals, deadline marks, timed overlap detection, and month semantics. It never mutates or reschedules sources.

- [ ] **Step 4: Run projection tests**

Run: `flutter test test/daybook_projection_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/daybook/presentation/daybook_range_projection.dart test/daybook_projection_test.dart
git commit -m "feat: unify daybook calendar projection"
```

### Task 4: Add neutral header, chooser, editors, location fields, and rows

**Files:**
- Create: `lib/daybook/widgets/daybook_add_choice_dialog.dart`
- Create: `lib/daybook/widgets/daybook_place_fields.dart`
- Create: `lib/daybook/widgets/daybook_event_editor.dart`
- Create: `lib/daybook/widgets/daybook_task_editor.dart`
- Create: `lib/daybook/widgets/daybook_rows.dart`
- Modify: `lib/academic_calendar/widgets/academic_calendar_sections.dart:49-220,1810-2040,2295-2328`
- Modify: `test/academic_calendar_widget_test.dart`

**Interfaces:**
- Consumes: Task 1 values, existing `AddAcademicMeetingDialog` and `AddAcademicWorkDialog`.
- Produces: `DaybookAddTarget`, `DaybookAddChoiceDialog`, `DaybookEventEditor`, `DaybookTaskEditor`, `DaybookPlaceFields`, `DaybookEventRow`, `DaybookTaskRow`.

- [ ] **Step 1: Write failing hierarchy/editor tests**

Assert the header contains `DAYBOOK` and default subtitle, semantic add label exactly `Add an event, task, class, assignment, or exam`, chooser order/general copy/`SCHOOL`, empty title validation, all-day/timed save payloads, weekly rule validation, task save payload, manual location persistence, and 44 px tappable choices. Retain existing class/assignment/exam tests unchanged.

- [ ] **Step 2: Run the chooser/editor tests**

Run: `flutter test test/academic_calendar_widget_test.dart --plain-name "Daybook"`

Expected: FAIL on the old academic header/chooser and missing editors.

- [ ] **Step 3: Implement chooser and header copy**

```dart
enum DaybookAddTarget { event, task, classMeeting, assignment, exam }
```

Use keys `daybook-add-choice-event`, `daybook-add-choice-task`, and preserve existing School choice keys. The header uses the existing calendar/daybook icon; selected active term name replaces only the default subtitle.

- [ ] **Step 4: Implement editor contracts**

Use these public constructor contracts:

```dart
DaybookEventEditor({
  required CivilDate selectedDay,
  DaybookEvent? initialEvent,
  DaybookEventOccurrence? initialOccurrence,
  required Future<bool> Function(DaybookEvent event) onSave,
});
DaybookTaskEditor({
  required CivilDate selectedDay,
  DaybookTask? initialTask,
  required Future<bool> Function(DaybookTask task) onSave,
});
```

Event fields are title, notes, all-day toggle, start/end dates, start/end time,
weekly toggle, weekdays, interval, and optional recurrence end. Task fields are
title, notes, due date, and optional due time. Both reuse `DaybookPlaceFields`
with `SAVED NAME`, `ADDRESS OR ROUTING TEXT`, `BUILDING`, `ROOM`; no network
affordance exists in this slice.

Use inline direct correction messages from the spec and keep dialogs open on invalid or failed saves.

- [ ] **Step 5: Reuse neutral location fields in class editor through the adapter**

Initialize from the class's existing `CampusPlace`; on save call `CampusPlaceDaybookAdapter.toCampusPlace(edited, original: existing)` so all legacy-only fields survive. New classes may retain `Location not set` only when all neutral fields are blank.

- [ ] **Step 6: Run widget regressions**

Run: `flutter test test/academic_calendar_widget_test.dart`

Expected: PASS for new general flows and unchanged School flows.

- [ ] **Step 7: Commit**

```powershell
git add lib/daybook/widgets lib/academic_calendar/widgets/academic_calendar_sections.dart test/academic_calendar_widget_test.dart
git commit -m "feat: add general daybook editors"
```

### Task 5: Make month, selected day, and span views consume the projection

**Files:**
- Modify: `lib/screens/calendar.dart:70-1040,1285-1579`
- Modify: `lib/academic_calendar/widgets/academic_calendar_sections.dart:415-730`
- Modify: `test/academic_calendar_widget_test.dart`
- Modify: `test/academic_calendar_visual_test.dart`

**Interfaces:**
- Consumes: Tasks 2–4 and `DaybookRangeProjection.build`.
- Produces: `_saveDaybookEvent`, `_saveDaybookTask`, `_toggleDaybookTask`, general rows in all views, projection-driven month summaries, `DaybookSpanPanel`.

- [ ] **Step 1: Write failing coexistence tests**

Seed one schedule with general items plus current academic fixtures and a Quest. Assert month semantics names every source, general entries appear in month/day/week/3-days, all-day rail precedes timed entries, task completion/undo persists without changing XP or Quest state, and `STILL OPEN` appears only on today for overdue incomplete tasks. Assert an empty non-school schedule never shows term/course requirements.

- [ ] **Step 2: Run focused coexistence tests**

Run: `flutter test test/academic_calendar_widget_test.dart --plain-name "general daybook"`

Expected: FAIL because `CalendarPage` still queries academic/general sources independently.

- [ ] **Step 3: Build one projection per visible range**

In `CalendarPage.build`, calculate first/last for the month or active span and call:

```dart
final daybook = DaybookRangeProjection.build(
  schedule: _academicSchedule,
  quests: widget.quests,
  first: first,
  last: last,
  now: Clock.now(),
);
```

Replace `_monthDayLoad`, `_dayCell` source queries, selected-day source queries, and `AcademicSpanPanel`'s direct schedule queries with `DaybookDay`/`DaybookDaySummary`. Source-specific rows resolve IDs back through the envelope only for specialized actions.

- [ ] **Step 4: Add persistence callbacks and chooser dispatch**

`_showAddDaybook` dispatches event/task editors or unchanged School dialogs. Each save mutates the envelope with `putEvent`/`putTask`, calls the existing repository, updates state only on successful save, and returns a boolean. Task toggle uses complete/undo with `Clock.now().toUtc()`.

- [ ] **Step 5: Generalize the span panel**

Rename `AcademicSpanPanel` to `DaybookSpanPanel`. It receives `DaybookRange` plus typed callbacks and renders all-day, timed, due, and still-open sections while retaining current academic row widgets/actions.

- [ ] **Step 6: Run focused widget and visual tests**

Run: `flutter test test/daybook_projection_test.dart test/academic_calendar_widget_test.dart test/academic_calendar_visual_test.dart`

Expected: PASS; every view reads identical projection data.

- [ ] **Step 7: Commit**

```powershell
git add lib/screens/calendar.dart lib/academic_calendar/widgets/academic_calendar_sections.dart test/academic_calendar_widget_test.dart test/academic_calendar_visual_test.dart
git commit -m "feat: render one general daybook across calendar views"
```

### Task 6: Add general edit/delete and weekly occurrence actions

**Files:**
- Create: `lib/daybook/widgets/daybook_event_actions.dart`
- Modify: `lib/daybook/widgets/daybook_rows.dart`
- Modify: `lib/screens/calendar.dart`
- Modify: `test/daybook_domain_test.dart`
- Modify: `test/academic_calendar_widget_test.dart`

**Interfaces:**
- Consumes: schema mutation methods from Task 2.
- Produces: `DaybookEventScope.thisEvent`, `DaybookEventScope.entireSeries`; move/cancel/restore/delete dialogs and callbacks.

- [ ] **Step 1: Write failing action tests**

Assert a one-off event edits and deletes without a scope chooser. Assert a task
edits, deletes, completes, and undoes completion while preserving its due date.
Assert tapping a weekly occurrence offers only `THIS EVENT` and `ENTIRE SERIES`;
moving/cancelling one writes an exception and leaves sibling occurrences;
restoring removes its override; entire-series edit replaces the source;
entire-series delete removes source and generated occurrences. Assert no
`THIS AND FUTURE EVENTS` copy exists.

- [ ] **Step 2: Run action tests**

Run: `flutter test test/daybook_domain_test.dart test/academic_calendar_widget_test.dart --plain-name "weekly event"`

Expected: FAIL because occurrence actions are absent.

- [ ] **Step 3: Implement scoped actions**

```dart
enum DaybookEventScope { thisEvent, entireSeries }
```

For one-off events, bypass the scope chooser and use `putEvent`/`deleteEvent`.
For tasks, reuse `DaybookTaskEditor`, `putTask`, and `deleteTask`; completion
remains a separate reversible control. For a weekly occurrence, scope is
mandatory. Reuse the event editor for a moved occurrence but persist an
exception; cancellation uses neutral `CANCEL EVENT` language and remains
restorable from the row. Deletion of `THIS EVENT` writes a cancelled/tombstoned
exception.

- [ ] **Step 4: Run domain and widget tests**

Run: `flutter test test/daybook_domain_test.dart test/academic_calendar_widget_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/daybook/widgets/daybook_event_actions.dart lib/daybook/widgets/daybook_rows.dart lib/screens/calendar.dart test/daybook_domain_test.dart test/academic_calendar_widget_test.dart
git commit -m "feat: adjust weekly daybook events"
```

### Task 7: Add manual-location directions and provider preference

**Files:**
- Create: `lib/daybook/data/daybook_preferences.dart`
- Create: `lib/daybook/services/directions_launcher.dart`
- Modify: `lib/daybook/widgets/daybook_rows.dart`
- Modify: `lib/academic_calendar/widgets/academic_calendar_sections.dart`
- Modify: `lib/screens/calendar.dart`
- Create: `test/daybook_directions_launcher_test.dart`
- Modify: `test/academic_calendar_widget_test.dart`

**Interfaces:**
- Consumes: `DaybookPlace.hasGoogleDestination/hasAppleDestination`, `url_launcher`.
- Produces: `MapProvider`, `DirectionsLauncher`, `ExternalDirectionsLauncher`, `DaybookPreferences`, `GET DIRECTIONS`, `CHANGE MAP APP`, copy fallback.

- [ ] **Step 1: Write failing URI and visibility tests**

Assert exact encoded URIs:

```dart
expect(DirectionsUris.google(place), Uri.parse(
  'https://www.google.com/maps/dir/?api=1&destination=100%20George%20St%2C%20New%20Brunswick%2C%20NJ'));
expect(DirectionsUris.apple(place), Uri.parse(
  'https://maps.apple.com/?daddr=100%20George%20St%2C%20New%20Brunswick%2C%20NJ'));
```

Assert Apple is available only with non-empty manual routing text; Google is available with routing text or Google place ID; `GET DIRECTIONS` is hidden otherwise; semantic label is `Get directions to <saved label>`; failed launch keeps the sheet and exposes `COPY LOCATION`.

- [ ] **Step 2: Run service/widget tests**

Run: `flutter test test/daybook_directions_launcher_test.dart test/academic_calendar_widget_test.dart --plain-name "directions"`

Expected: FAIL because the service/actions do not exist.

- [ ] **Step 3: Implement URI and launch boundaries**

```dart
enum MapProvider { apple, google }
abstract interface class DirectionsLauncher {
  Future<bool> open(DaybookPlace place, MapProvider provider);
}
```

Build query parameters with `Uri.https`; Google uses `/maps/dir/`, `api=1`, the person's routing text or saved name, plus `destination_place_id` when present. Apple uses `https://maps.apple.com/` and only manual routing text. Launch with `LaunchMode.externalApplication` on native and external platform behavior on web.

- [ ] **Step 4: Implement remembered chooser/fallback**

`DaybookPreferences` stores only the preferred provider and later Places consent. On iOS, show both choices only when both predicates are true; otherwise open the sole provider. `CHANGE MAP APP` clears the preference. On failure, keep details open and offer Clipboard copy of manual routing text or saved name.

- [ ] **Step 5: Wire actions to general and class locations**

Rows receive a `DaybookPlace` and injected launcher/preferences. Class locations adapt from `CampusPlace` without mutating it. Do not add location permissions.

- [ ] **Step 6: Run focused tests**

Run: `flutter test test/daybook_directions_launcher_test.dart test/academic_calendar_widget_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit**

```powershell
git add lib/daybook/data/daybook_preferences.dart lib/daybook/services/directions_launcher.dart lib/daybook/widgets/daybook_rows.dart lib/academic_calendar/widgets/academic_calendar_sections.dart lib/screens/calendar.dart test/daybook_directions_launcher_test.dart test/academic_calendar_widget_test.dart
git commit -m "feat: open directions from daybook places"
```

### Task 8: General Daybook regression and release gate

**Files:**
- Modify: `test/academic_calendar_visual_test.dart`
- Create: `test/goldens/daybook_general_month_430x932.png`
- Create: `test/goldens/daybook_general_day_430x932.png`
- Verify: all files changed by Tasks 1–7

**Interfaces:**
- Consumes: completed local Daybook slice.
- Produces: focused and full-suite evidence with Places search still absent/disabled.

- [ ] **Step 1: Add general month/day visual fixtures**

Use one all-day event, one timed event, one incomplete task, one weekly event, one class, and one Quest. Capture normal 430×932 and narrow 320×568 at 200% text. The header and selected-day detail must be readable with no overflow.

- [ ] **Step 2: Run focused suites**

Run: `flutter test test/daybook_domain_test.dart test/daybook_projection_test.dart test/daybook_directions_launcher_test.dart test/academic_schedule_test.dart test/academic_calendar_widget_test.dart test/academic_calendar_visual_test.dart`

Expected: all pass.

- [ ] **Step 3: Run static analysis and full Flutter tests**

Run: `flutter analyze`

Expected: `No issues found!`

Run: `flutter test`

Expected: all tests pass.

- [ ] **Step 4: Build web and Android release artifacts**

Run: `flutter build web --release --wasm`

Expected: exit 0.

Run: `flutter build apk --release`

Expected: exit 0.

- [ ] **Step 5: Commit verification assets only if changed**

```powershell
git add test/academic_calendar_visual_test.dart test/goldens/daybook_general_month_430x932.png test/goldens/daybook_general_day_430x932.png
git commit -m "test: lock general daybook visuals"
```
