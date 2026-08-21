# Room of Days Calendar Commitments Design

Status: approved by the owner on 2026-08-18.

## Problem

Plans currently treats every recurring Quest occurrence as a deadline. A daily,
weekly, or monthly routine is projected into every matching date, placed under
`DUE`, assigned an inferred duration, and used to draw both the month weight tick
and deadline mark. An undated one-time Quest (`Until it’s done`) is also placed on
the current day as `DUE` even though the Quest flow deliberately gave it no due
date.

This makes routine care look urgent and fills the month with identical marks. It
breaks the no-punishment contract and makes actual commitments harder to see.

This spec supersedes the older Design Bible sentence that the selected day shows
all recurring Quests. Plans is a calendar of commitments and deliberate focus;
the Quest board remains the home of routines.

## Product thesis

Google Calendar tells a person when things are. Room of Days should help them
understand what their day can honestly hold.

The calendar therefore distinguishes four kinds of intent:

1. `SCHEDULE` — something given real start and end times.
2. `DUE` — something with a real due date.
3. `TODAY’S FOCUS` — a Quest deliberately chosen for one civil date.
4. Routine — recurring Quest-board work with no calendar claim.

Empty time is not a problem to solve. The app does not fill it, score it, call it
available, or imply that the person should use it more efficiently.

## Quest visibility contract

| Quest state | Plans behavior |
| --- | --- |
| `schedule == once` and `dueDate != null` | Appears once on its due date under `DUE`; creates an active deadline mark while incomplete. |
| `priorityDay == Days.key(date)` | Appears once on that date under `TODAY’S FOCUS`; creates one quiet focus mark while incomplete. |
| Both explicit due date and matching `priorityDay` | Appears once under `DUE`; the deadline wins. |
| Daily, weekly, or monthly recurrence without a dated focus | Does not appear in Plans. |
| `schedule == once` and `dueDate == null` | Does not appear in Plans. |
| Standing legacy `priority == true` with `priorityDay == null` | Does not appear in Plans. |
| Completed dated/focus Quest | The row may remain as completed history on its true date, but it creates no active deadline, focus, or time-weight mark. |

`snoozedDay` continues to hide a dated focus on that date. It does not erase an
explicit due date from the calendar; a Quest-board snooze must not rewrite the
existence of a deadline.

This uses existing persisted fields. It does not add a Quest schema field or
migration.

## Projection contract

`DaybookRangeProjection` remains the sole composition point for academic,
general Daybook, and Quest sources.

`DaybookSection` gains `focus` with this stable presentation order:

`allDay → timed → due → focus → stillOpen`

Quest projection is explicit:

- a true Quest event (`quest.isEvent`) is emitted as `due` on the civil date of
  `dueDate`;
- a non-due Quest whose `priorityDay` equals the civil-date key is emitted as
  `focus`;
- no other Quest is emitted.

Quest entries never contribute inferred minutes. `scheduledMinutes` and
`DaybookDayWeight` are derived only from non-cancelled timed entries, preserving
the existing class transition-buffer calculation. Due items, all-day items, and
focus choices do not claim time that was never assigned.

`DaybookDaySummary` additionally exposes:

- `fixedPlanCount`: non-cancelled all-day and timed entries;
- `deadlineCount`: incomplete `due` and `stillOpen` entries;
- `focusCount`: incomplete `focus` entries;
- `firstTimedStartMinute`: the first non-cancelled timed start, if any.

`hasDeadline` remains the compatibility boolean `deadlineCount > 0`.

The accessibility summary names fixed scheduled minutes, true deadlines, and
focus choices separately. It never calls a routine due or describes an empty day
as failed, wasted, or underused.

## Month marks

The month keeps one quiet metadata slot beneath each numeral:

- tick height represents only actual timed minutes;
- the brass diamond represents at least one active deadline;
- one small muted plum point represents at least one active dated focus;
- ordinary routines create no mark;
- multiple focus Quests still create one point, preventing visual escalation.

The focus point has a stable test key
`academic-month-focus-YYYY-MM-DD`. It is visually subordinate to the deadline
diamond and does not change the tick height.

## Selected-day agenda

Agenda sections render in this order:

`ALL DAY → SCHEDULE → DUE → TODAY’S FOCUS → STILL OPEN`

A Quest deadline row uses source label `QUEST` and timing copy `DUE` (or
`DUE 3:00 PM`). A dated focus row uses source label `QUEST` and timing copy
`CHOSEN FOR TODAY`. Its accessibility label is
`<title>, today’s focus[, completed]`; it never includes `due`.

The existing Quest completion action remains the only action on these rows.
Completing a focus Quest uses the existing Quest reward path; this pass does not
create a second Quest model or reward system.

## Day Shape

The selected-day folio gains one compact factual summary immediately below the
date / `+ PLAN` header and above the agenda. It is not a new card, chart, or
score.

Visible eyebrow: `DAY SHAPE`

The body is composed from summary facts:

- timed/all-day plans: `1 fixed plan · 10:00 AM`,
  `2 fixed plans · first at 10:00 AM`, or `1 all-day plan`;
- active deadlines: `1 deadline` / `2 deadlines`;
- active focus: `1 focus` / `2 focus choices`;
- multiple facts join with ` · `;
- if no fact exists: `No fixed plans.` — this states only what the Daybook
  projection knows and never implies that the person had no routines or that
  the day was available.
  for the past.

The line wraps naturally. At large text, the existing date/action reflow remains
intact and the Day Shape text may take multiple lines. No content is ellipsized.
The old empty-day sentence is removed because Day Shape now owns that truth.

## Accessibility

- The month cell semantic label names the date, timed weight, true deadline,
  and dated focus without relying on the visual glyph.
- The focus row says `today’s focus`, not `due`.
- Section headings and Day Shape text remain visible at 320 × 568 and 200%
  text without horizontal or vertical overflow.
- Existing 44 px completion and action targets remain unchanged.

## Compatibility and scope

No persistence migration is required. Existing Quest JSON, completion behavior,
XP, streaks, bookends, general Daybook events/tasks, academic scheduling,
directions, and Places behavior remain unchanged.

Explicitly deferred:

- automatic scheduling or rescheduling;
- `MAKE TODAY LIGHTER` actions;
- inferred Quest duration or free-time calculations;
- external calendar import/sync;
- a new per-Quest calendar-presence field;
- a standing priority / undated MAIN interpretation in Plans;
- availability, productivity, or energy scores.

These later features must build on the commitment/focus distinction established
here rather than reintroducing routine clutter.

## Verification contract

Tests must prove the entire bug strain, not only the screenshot examples:

- daily, weekday-restricted daily, weekly, and monthly routines project nowhere;
- undated once and standing MAIN project nowhere;
- explicit due and dated focus project to distinct sections and dates;
- due plus focus de-duplicates to due;
- snoozed focus hides while snoozed due remains;
- routine/focus/due Quests do not inflate timed minutes or tick height;
- completed entries create no active deadline/focus mark;
- month markers distinguish time, deadline, and focus;
- selected-day and span agendas use the approved section order/copy;
- Day Shape renders factual states at normal and 320 × 568 / 200% text;
- refreshed canonical calendar goldens are inspected at original resolution;
- focused tests, full analysis, full Flutter tests, and release builds pass in
  proportion to the change before release.
