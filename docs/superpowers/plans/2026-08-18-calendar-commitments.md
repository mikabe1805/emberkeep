# Calendar Commitments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Plans show only real deadlines, real timed commitments, and date-chosen Quest focus while adding a factual Day Shape summary.

**Architecture:** Keep Quest persistence unchanged and repair calendar intent inside `DaybookRangeProjection`. Extend the shared day summary so month cells and the selected-day folio consume the same fixed-time, deadline, and focus facts; render focus as a distinct agenda section and quiet month point.

**Tech Stack:** Flutter/Dart, existing Daybook projection, Flutter widget tests, platform-scoped golden policy.

**Spec:** `docs/superpowers/specs/2026-08-18-calendar-commitments-design.md`

## Global Constraints

- `DUE` is only an explicit dated one-off Quest or another existing due source.
- `TODAY’S FOCUS` is only `priorityDay == Days.key(date)` and never implies due.
- Daily, weekly, monthly, undated once, and standing undated MAIN Quests are absent from Plans.
- A matching explicit due date wins over focus and emits one row.
- Quest entries never add inferred minutes to `scheduledMinutes` or month tick height.
- Month tick = timed minutes; brass diamond = active deadline; one muted plum point = active focus.
- Empty time is never scored, filled, or described as wasted/available.
- No Quest schema migration, new persistence field, reward change, notification change, or external sync.
- Preserve existing 44 px targets and support 320 × 568 at 200% text without ellipsis or overflow.
- Every product change follows RED → GREEN; canonical goldens are updated only after an expected failing comparison and original-resolution inspection.

---

### Task 1: Repair Quest projection intent and shared day facts

**Files:**
- Modify: `lib/daybook/presentation/daybook_range_projection.dart:19-100, 180-200, 467-574, 607-673`
- Modify: `test/daybook_projection_test.dart`

**Interfaces:**
- Consumes: existing `Quest.isEvent`, `Quest.priorityDay`, `Days.key`, `Quest.doneFor`, and `DaybookEntry`.
- Produces: `DaybookSection.focus`; `DaybookDaySummary.fixedPlanCount`, `deadlineCount`, `focusCount`, and `firstTimedStartMinute`; explicit due/focus Quest projection.

- [ ] **Step 1: Write the failing projection matrix test**

Add a table-driven test with literal expected dates/sections for: unrestricted
daily, restricted daily, weekly, monthly, undated once, standing priority,
dated focus, dated due, and due plus matching focus. Include a snoozed focus and
snoozed due.

```dart
test('Quest calendar intent separates deadlines focus and routines', () {
  final date = CivilDate(2026, 8, 18);
  final range = DaybookRangeProjection.build(
    schedule: AcademicSchedule.empty(),
    quests: <Quest>[
      Quest(title: 'Daily care', stat: Stat.vit, difficulty: 1),
      Quest(
        title: 'Tuesday care',
        stat: Stat.vit,
        difficulty: 1,
        weekdays: const [DateTime.tuesday],
      ),
      Quest(
        title: 'Weekly care',
        stat: Stat.vit,
        difficulty: 1,
        schedule: QuestSchedule.weekly,
      ),
      Quest(
        title: 'Monthly care',
        stat: Stat.vit,
        difficulty: 1,
        schedule: QuestSchedule.monthly,
        monthDay: 18,
      ),
      Quest(
        title: 'Until done',
        stat: Stat.foc,
        difficulty: 2,
        schedule: QuestSchedule.once,
      ),
      Quest(
        title: 'Standing main',
        stat: Stat.foc,
        difficulty: 2,
        priority: true,
      ),
      Quest(
        title: 'Chosen today',
        stat: Stat.foc,
        difficulty: 2,
        priority: true,
        priorityDay: '2026-08-18',
      ),
      Quest(
        title: 'Real deadline',
        stat: Stat.foc,
        difficulty: 3,
        schedule: QuestSchedule.once,
        dueDate: DateTime(2026, 8, 18, 15),
      ),
      Quest(
        title: 'Due wins',
        stat: Stat.foc,
        difficulty: 3,
        schedule: QuestSchedule.once,
        dueDate: DateTime(2026, 8, 18),
        priority: true,
        priorityDay: '2026-08-18',
      ),
    ],
    first: date.addDays(-1),
    last: date.addDays(1),
    now: DateTime(2026, 8, 18, 12),
  );

  expect(
    [for (final entry in range.dayOn(date).entries) (entry.title, entry.section)],
    const [
      ('Real deadline', DaybookSection.due),
      ('Due wins', DaybookSection.due),
      ('Chosen today', DaybookSection.focus),
    ],
  );
  final titles = range.days.values
      .expand((day) => day.entries)
      .map((entry) => entry.title)
      .toSet();
  for (final hidden in const {
    'Daily care',
    'Tuesday care',
    'Weekly care',
    'Monthly care',
    'Until done',
    'Standing main',
  }) {
    expect(titles, isNot(contains(hidden)));
  }
});
```

Use separate literal assertions for snoozed focus (absent) and snoozed due
(present).

- [ ] **Step 2: Run the projection test and verify RED**

Run:

```powershell
flutter test --no-pub test/daybook_projection_test.dart --plain-name "Quest calendar intent"
```

Expected: compile failure because `DaybookSection.focus` does not exist, or
behavioral failure showing routine entries and due/focus misclassification.

- [ ] **Step 3: Write failing summary tests**

Add literal tests proving:

```dart
expect(day.summary.scheduledMinutes, 60); // one real 60-minute timed event
expect(day.summary.fixedPlanCount, 1);
expect(day.summary.deadlineCount, 1);
expect(day.summary.focusCount, 1);
expect(day.summary.firstTimedStartMinute, 9 * 60);
expect(day.summary.hasDeadline, isTrue);
```

Give the due and focus Quests large `timerMinutes` values so the test fails if
either is still added to timed load. Add completed focus/deadline fixtures and
assert their active counts are zero.

- [ ] **Step 4: Run the summary tests and verify RED**

Run:

```powershell
flutter test --no-pub test/daybook_projection_test.dart --plain-name "Quest calendar summary"
```

Expected: missing summary getters and/or inflated scheduled minutes.

- [ ] **Step 5: Implement the minimal projection distinction**

Use the enum and summary shape below:

```dart
enum DaybookSection { allDay, timed, due, focus, stillOpen }

final class DaybookDaySummary {
  const DaybookDaySummary({
    required this.scheduledMinutes,
    required this.weight,
    required this.fixedPlanCount,
    required this.deadlineCount,
    required this.focusCount,
    required this.firstTimedStartMinute,
    required this.hasDeadline,
    required this.conflicts,
    required this.semanticLabel,
  });

  final int fixedPlanCount;
  final int deadlineCount;
  final int focusCount;
  final int? firstTimedStartMinute;
  // Preserve the existing fields below.
}
```

Replace `_questAppearsOn` with explicit placement:

```dart
final due = quest.isEvent &&
    CivilDate.fromDateTime(quest.dueDate!) == date;
final focus = !due && quest.priorityDay == dateKey;
if (!due && (!focus || quest.snoozedDay == dateKey)) continue;

items.add(DaybookEntry(
  displayKey: 'quest:${quest.title}',
  sourceKind: DaybookSourceKind.questPlan,
  sourceId: quest.title,
  title: quest.displayTitle,
  section: due ? DaybookSection.due : DaybookSection.focus,
  startMinute: due ? dueMinute : null,
  completed: quest.doneFor(dateTime),
  sourceLabel: 'QUEST',
  action: QuestPlanAction(quest.title),
));
```

Do not apply `snoozedDay` to the `due` branch. Delete the Quest minutes lookup
and Quest-minute accumulation loop. Derive summary counts from non-cancelled or
incomplete entries exactly as the spec defines.

- [ ] **Step 6: Run focused projection tests and verify GREEN**

Run:

```powershell
flutter test --no-pub test/daybook_projection_test.dart
```

Expected: all projection tests pass with pristine output.

- [ ] **Step 7: Run scoped analysis**

Run:

```powershell
flutter analyze --no-pub lib/daybook/presentation/daybook_range_projection.dart test/daybook_projection_test.dart
```

Expected: `No issues found!`

- [ ] **Step 8: Commit Task 1**

```powershell
git add lib/daybook/presentation/daybook_range_projection.dart test/daybook_projection_test.dart
git commit -m "fix: separate quest focus from deadlines"
```

### Task 2: Render focus honestly in agenda and month marks

**Files:**
- Modify: `lib/academic_calendar/widgets/academic_calendar_sections.dart:764-835, 1358-1391, 4778-4799`
- Modify: `lib/screens/calendar.dart:849-1025, 1257-1331`
- Modify: `test/academic_calendar_widget_test.dart`

**Interfaces:**
- Consumes: Task 1 `DaybookSection.focus` and summary focus/deadline/time facts.
- Produces: `TODAY’S FOCUS` agenda section, `CHOSEN FOR TODAY` row timing, and `academic-month-focus-YYYY-MM-DD` month point.

- [ ] **Step 1: Write failing agenda and marker widget tests**

Create a CalendarPage fixture containing:

- one ordinary daily routine;
- one `priorityDay: '2026-08-18'` Quest;
- one explicit one-time due Quest on 2026-08-18;
- one real timed Daybook event.

Assert real rendered behavior:

```dart
expect(find.text('Daily routine'), findsNothing);
expect(find.text('TODAY’S FOCUS'), findsOneWidget);
expect(find.text('Chosen today'), findsOneWidget);
expect(find.text('CHOSEN FOR TODAY'), findsOneWidget);
expect(find.text('DUE'), findsWidgets);
expect(
  find.byKey(const ValueKey('academic-month-focus-2026-08-18')),
  findsOneWidget,
);
expect(
  find.byKey(const ValueKey('academic-month-deadline-2026-08-18')),
  findsOneWidget,
);
```

Add a routine-only fixture and assert both month keys and the weight key are
absent. Add a focus-only fixture and assert focus exists while deadline/weight
are absent.

- [ ] **Step 2: Run focused widget tests and verify RED**

Run:

```powershell
flutter test --no-pub test/academic_calendar_widget_test.dart --plain-name "Quest calendar intent"
```

Expected: missing focus section/copy/key and switch-exhaustiveness failures.

- [ ] **Step 3: Render the focus section and truthful row semantics**

Add this agenda section between due and still-open:

```dart
(DaybookSection.focus, 'TODAY’S FOCUS'),
```

Extend projected timing and semantics:

```dart
DaybookSection.focus => 'CHOSEN FOR TODAY',
// semantics switch
DaybookSection.focus => 'today’s focus',
```

Update `_dayCountLabel` so focus is separate:

```dart
if (focus > 0) parts.add('$focus FOCUS');
```

The row keeps the existing Quest completion control and source action.

- [ ] **Step 4: Add the quiet focus point to the month metadata slot**

Pass `summary.focusCount > 0` and a focus key into `_MonthDayWeightMark`. Keep
the outer slot at its existing fixed height. Render one 3 px circular
`Palette.unlock` point at the bottom; when a timed tick also exists, offset the
point to one side so both remain legible. Do not change tick height or deadline
diamond geometry.

The month-cell empty condition becomes:

```dart
summary.weight == DaybookDayWeight.none &&
    !summary.hasDeadline &&
    summary.focusCount == 0
```

- [ ] **Step 5: Run the focused widget tests and verify GREEN**

Run:

```powershell
flutter test --no-pub test/academic_calendar_widget_test.dart --plain-name "Quest calendar intent"
```

Expected: all matching tests pass with no overflow exceptions.

- [ ] **Step 6: Run the full calendar widget file and scoped analysis**

Run:

```powershell
flutter test --no-pub test/academic_calendar_widget_test.dart
flutter analyze --no-pub lib/academic_calendar/widgets/academic_calendar_sections.dart lib/screens/calendar.dart test/academic_calendar_widget_test.dart
```

Expected: all tests pass; analysis reports no issues.

- [ ] **Step 7: Commit Task 2**

```powershell
git add lib/academic_calendar/widgets/academic_calendar_sections.dart lib/screens/calendar.dart test/academic_calendar_widget_test.dart
git commit -m "feat: show chosen quests as today focus"
```

### Task 3: Add the factual Day Shape line and visual proof

**Files:**
- Modify: `lib/screens/calendar.dart:1532-1745`
- Modify: `test/academic_calendar_widget_test.dart`
- Modify: `test/academic_calendar_visual_test.dart:152-290, 877-951`
- Modify: affected files under `test/goldens/daybook_general_*.png`

**Interfaces:**
- Consumes: Task 1 summary counts and first timed start.
- Produces: selected-day `DAY SHAPE` eyebrow and factual wrapping body copy.

- [ ] **Step 1: Write failing normal and large-text Day Shape tests**

Add tests that pump the selected day with literal summary states through real
CalendarPage fixtures. Assert the body copy and geometry, not private helpers:

```dart
expect(find.text('DAY SHAPE'), findsOneWidget);
expect(
  find.text('2 fixed plans · first at 9:00 AM · 1 deadline · 1 focus'),
  findsOneWidget,
);
```

At `Size(320, 568)` and text scale 2, scroll the line into view and assert every
`RenderParagraph` for the Day Shape label/body has `didExceedMaxLines == false`,
the full body is in the scrollable viewport, and `tester.takeException()` is
null. Add empty-future and empty-past tests for `No fixed plans yet.` and
`A quiet day.`.

- [ ] **Step 2: Run focused Day Shape tests and verify RED**

Run:

```powershell
flutter test --no-pub test/academic_calendar_widget_test.dart --plain-name "Day Shape"
```

Expected: `DAY SHAPE` and body copy are absent.

- [ ] **Step 3: Implement the minimal Day Shape surface**

Add a private `_DayShapeSummary` widget in `calendar.dart` and insert it below
the date/action header. It receives `DaybookDaySummary` and `isPast`. Its copy
builder uses the literal contract from the spec; time formatting reuses the
existing academic time formatter rather than duplicating 12-hour conversion.

Render a thin brass rule, `DAY SHAPE` in the existing small label style, and a
wrapping body sentence in `Type.body` / `Palette.textMid`. Use no card,
progress bar, score, icon, or action. Remove the old empty-day sentence so the
truth is stated once.

- [ ] **Step 4: Run focused and full widget tests and verify GREEN**

Run:

```powershell
flutter test --no-pub test/academic_calendar_widget_test.dart --plain-name "Day Shape"
flutter test --no-pub test/academic_calendar_widget_test.dart
```

Expected: all tests pass with no Flutter overflow exception.

- [ ] **Step 5: Extend the visual fixture and capture expected RED**

Change `_pumpGeneralDaybookReleaseFixture` to pass three Quests:

```dart
quests: [
  realDueQuest,
  Quest(
    title: 'Choose references for the cover',
    stat: Stat.foc,
    difficulty: 2,
    priority: true,
    priorityDay: '2026-08-11',
  ),
  Quest(
    title: 'Clear the sink',
    stat: Stat.dis,
    difficulty: 1,
    schedule: QuestSchedule.daily,
  ),
],
```

Assert the focus is visible in day mode and the routine is absent. Run the
ordinary visual file before updating:

```powershell
flutter test --no-pub test/academic_calendar_visual_test.dart
```

Expected: only the affected general Daybook golden comparisons fail because
Day Shape/focus intentionally changed the frame.

- [ ] **Step 6: Refresh only affected canonical goldens**

On the canonical Windows environment:

```powershell
flutter test --no-pub --update-goldens test/academic_calendar_visual_test.dart --plain-name "general daybook"
```

Confirm the command does not update capture-only fixtures outside their gated
defines. Open every changed PNG at original resolution and inspect the month,
day, normal, and 320 × 568 / 200% states for the absence of routine-arrow
clutter, correct focus/deadline hierarchy, complete Day Shape copy, and no
crop/overlap.

- [ ] **Step 7: Run the complete focused gate**

Run:

```powershell
flutter test --no-pub test/daybook_projection_test.dart test/academic_calendar_widget_test.dart test/academic_calendar_visual_test.dart
flutter analyze --no-pub lib/daybook/presentation/daybook_range_projection.dart lib/academic_calendar/widgets/academic_calendar_sections.dart lib/screens/calendar.dart test/daybook_projection_test.dart test/academic_calendar_widget_test.dart test/academic_calendar_visual_test.dart
```

Expected: all focused tests pass and analysis reports `No issues found!`.

- [ ] **Step 8: Commit Task 3**

```powershell
git add lib/screens/calendar.dart test/academic_calendar_widget_test.dart test/academic_calendar_visual_test.dart test/goldens/daybook_general_*.png
git commit -m "feat: show the honest shape of a day"
```

### Task 4: Whole-branch verification

**Files:**
- Verify only; no planned product edits.

**Interfaces:**
- Consumes: all prior tasks.
- Produces: release evidence for the calendar slice.

- [ ] **Step 1: Run formatting and diff checks**

```powershell
dart format --output=none --set-exit-if-changed lib/daybook/presentation/daybook_range_projection.dart lib/academic_calendar/widgets/academic_calendar_sections.dart lib/screens/calendar.dart test/daybook_projection_test.dart test/academic_calendar_widget_test.dart test/academic_calendar_visual_test.dart
git diff --check
```

- [ ] **Step 2: Run full analysis and tests**

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

- [ ] **Step 3: Build release artifacts**

```powershell
flutter build web --release --wasm
flutter build apk --release
```

No deployment, TestFlight upload, feature-flag change, or store submission is
authorized by this plan.

- [ ] **Step 4: Record verification evidence**

Record command exit codes, test counts, build artifact paths, and any
non-blocking platform warnings in the plan ledger. Do not claim physical iPhone
behavior from desktop tests or release builds.
