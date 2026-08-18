# General Daybook — Task 4 report

Date: 2026-08-17
Implementation commit: `f1d2268` (`feat: add general daybook editors`)

## Implementation

- Reframed the visible academic-calendar header as the neutral `DAYBOOK` surface. The default subtitle is `Events, tasks, classes, and places in one view`; an active term replaces only that subtitle. The existing add key remains stable and its semantic label is exactly `Add an event, task, class, assignment, or exam`.
- Added the neutral add chooser with `EVENT`, `TASK`, a quiet `SCHOOL` rule, then `CLASS`, `ASSIGNMENT`, and `EXAM`. General targets use the new keys and enum; all existing School choice keys and callback contracts remain unchanged.
- Added one-off/all-day/timed/weekly event editing, including weekdays, interval, optional recurrence end, occurrence prefilling, direct inline corrections, and failed-save handling that leaves the dialog open.
- Added one-off task editing with title, notes, due date, optional due time, manual place, completion identity preservation, and no Quest, XP, or streak model semantics.
- Added shared offline-only manual place fields: `SAVED NAME`, `ADDRESS OR ROUTING TEXT`, `BUILDING`, and `ROOM`. There is no search, network, location-permission, or provider affordance.
- Reused the shared place fields in the class editor. Existing `CampusPlace` values are converted with `CampusPlaceDaybookAdapter`, and saves call the adapter with the original place so latitude, longitude, campus code, provider, and provider place ID survive neutral-field edits.
- Added event/task rows with readable time/place metadata and a 44 px task completion control.
- Added responsive reflow: paired event date/time controls and paired building/room fields stack on narrow or large-text layouts instead of shrinking their content.

Task 4 intentionally does not wire the neutral chooser or general editors into calendar persistence; that is Task 5. The existing School-only chooser remains the current CalendarPage dispatch contract and was left intact.

## Files

- `lib/daybook/widgets/daybook_add_choice_dialog.dart` — neutral add-target enum and chooser.
- `lib/daybook/widgets/daybook_place_fields.dart` — shared manual-place controller and fields.
- `lib/daybook/widgets/daybook_event_editor.dart` — event create/edit dialog.
- `lib/daybook/widgets/daybook_task_editor.dart` — task create/edit dialog.
- `lib/daybook/widgets/daybook_rows.dart` — event and task display rows.
- `lib/academic_calendar/widgets/academic_calendar_sections.dart` — neutral header and adapter-backed class place fields.
- `test/academic_calendar_widget_test.dart` — focused Daybook coverage while retaining School regressions.
- `.superpowers/sdd/2026-08-17-general-daybook/task-4-report.md` — this report.

No unrelated pre-existing working-tree changes were staged or committed.

## RED

Command run before implementation, verbatim:

```powershell
flutter test test/academic_calendar_widget_test.dart --plain-name "Daybook"
```

Result: **FAIL** (exit 1). The focused test target failed during compile/load because the newly referenced Task 4 public files and types did not yet exist, including `daybook_add_choice_dialog.dart`, `daybook_event_editor.dart`, `daybook_rows.dart`, and `daybook_task_editor.dart`. This was a genuine requirements-driven RED, not a synthetic failure.

## GREEN

Final commands were run on the exact implementation tree immediately before the implementation commit.

```powershell
flutter test test/academic_calendar_widget_test.dart --plain-name "Daybook"
```

Result: **PASS**, 8/8 focused Daybook widget tests.

```powershell
flutter test test/academic_calendar_widget_test.dart
```

Result: **PASS**, 30/30 academic-calendar widget tests, including the existing class, assignment, exam, planner, conflict, preference, narrow-phone, and 200%-text regressions.

The focused coverage verifies:

- neutral header/default and active-term subtitle behavior;
- exact add semantics, chooser copy/order/keys, quiet School grouping, and 44 px choices;
- event title, date/time, weekly-rule, manual-place, and failed-save behavior;
- task due date/time/manual-place payloads without Quest state;
- event/task row readability and completion semantics;
- preservation of legacy-only class place fields through the lossless adapter.

## Scoped analysis

```powershell
flutter analyze lib/daybook/widgets lib/academic_calendar/widgets/academic_calendar_sections.dart test/academic_calendar_widget_test.dart
```

Result: **PASS** — `No issues found!`.

`git diff --check` and the staged equivalent also completed without whitespace errors.

## Visual and accessibility self-review

Temporary visual probes were rendered and inspected at 430 × 932 and at 320 × 568 with 200% text. The probe test was removed before the final verification and commit; screenshots were kept outside the repository at:

`C:\Users\mikus\.codex\visualizations\2026\08\17\01a0115a-ce70-7471-bd36-a1db785d6456`

Review findings:

- The `DAYBOOK` header remains compact, warm, and subordinate to the calendar content, with one honey/brass `ADD` action and no duplicated visual primary.
- The add chooser has a clear general-first hierarchy; `SCHOOL` reads as a quiet organizational rule rather than another action.
- Editor hierarchy remains literary and cohesive with the existing smoked-glass, faceted-brass, mono-label language. Inputs remain full-size rather than becoming tiny.
- At 320 px and 200% text, dialogs scroll naturally. Manual-place fields stack; event date/time pairs were changed to stack after inspection exposed truncation. The final probe shows full `9:00 AM` and `10:00 AM` values.
- Save, chooser, close, toggle, weekday, and task-completion actions preserve at least 44 px hit regions and retain button/selected/enabled semantics.
- Corrections stay inline and dialogs remain open after validation or local save failure.
- No network/search/location-permission affordance appears in the manual-location slice.

An existing academic-calendar visual-golden command was also sampled without accepting new baselines:

```powershell
flutter test --dart-define=CAPTURE_ACADEMIC=true test/academic_calendar_visual_test.dart
```

It failed against the intentionally stale header goldens (month: 1.75%, 6,995 pixels; day: 0.25%, 1,006 pixels; today marker: 0.25%, 1,006 pixels). Inspection confirmed the differences are the deliberate `ACADEMIC DAYBOOK` → `DAYBOOK` header/icon/subtitle change. Golden recapture is deferred to Task 8 as specified by the broader plan; no baselines were updated in Task 4.

## Commit

- `f1d2268` — `feat: add general daybook editors`
- This report is committed separately so it can truthfully name the immutable implementation commit.

Only the seven Task 4 implementation/test paths were included in the implementation commit. Repository-authored dirty design files, audit/comparison directories, `diff_selected.txt`, and the unrelated What's New plan remain untouched and uncommitted.

## Concerns and handoff notes

- The neutral chooser and general editors are intentionally public but not yet connected to CalendarPage dispatch or local repository writes. Task 5 owns that wiring; changing it here would violate the Task 4 boundary.
- The existing header visual goldens now describe the old academic header. Task 8 should recapture and judge those baselines after the later calendar composition work lands.
- New events use the app's existing Rutgers-oriented `America/New_York` default when no initial event supplies a timezone. The required constructor has no timezone input; editing preserves an existing event's IANA timezone.
- No network-dependent location discovery is present. That is intentional for this offline-only slice.

## Influence from `MIKA.md`

`C:\Users\mikus\soul\MIKA.md` was read completely before design or copy work. It materially reinforced four choices:

- Treat visual cohesion and interaction feel as part of “done,” which prompted actual narrow/large-text rendering and a responsive date/time reflow rather than stopping at compile/test success.
- Preserve authored warmth and hierarchy instead of introducing generic Material styling: smoked glass, restrained brass, one honey primary action, and the established type roles remain intact.
- Keep copy direct and humane: corrections say what to fix, do not blame the user, and failed local saves keep their work in the open dialog.
- Avoid pretending an offline manual field set can search or locate places; no false affordance or unsupported promise was added.
