# Class-day journey: UI surface code map

Written 2026-10-03, read-only, against **W** = `app/.worktrees/class-day-journey` at **c0a041a**
(Build 49 code plus one docs commit). Every `file:line` below was opened in W today. Paths are
relative to `W/lib/` unless they start with `test/`, `ios/`, `assets/` or `design/`.

Companion map (engine, model, storage, Extra Credit port, schema 29, undo, streak options):
`design/briefs/2026-10-03-class-day-code-map-engine.md`. This file covers the screens, flows,
widget, notifications and tests a class-day journey touches, and the seams to reach them.

Tags: **[v]** read in W today; **[i]** inferred (reasoning, or plugin/platform knowledge not
exercised here). Untagged statements are [v].

---

## 0. Bottom line

1. **The shell already holds the live schedule but nobody below it can see it.**
   `screens/shell.dart:202-203` keeps `_academicSchedule`; it is assigned without `setState`
   (:308, :322) and read only by the widget snapshot (:336) and class reminders (:1753-1755).
   Quests, routines and Journal get nothing. Cleanest seam: one pure `projectClassDay(schedule,
   now)` beside `academic_calendar/services/academic_reminder_projection.dart`, computed in the
   shell and passed down as an optional parameter (§1.5).
2. **Use the widget snapshot's filter for "a real class"** (`home_widgets/widget_snapshot.dart:142-152`):
   not cancelled, not tombstoned, course present and not archived. `occurrencesOn`
   (`academic_calendar/domain/academic_schedule.dart:1166`) also returns cancelled and tombstoned
   rows; `doorwayOccurrences` / `nextOccurrence` (:1486-1510) skip neither tombstones nor archived
   courses.
3. **Nothing on the board is clock-driven.** The only time-based rebuild is the shell's midnight
   timer (shell.dart:470-485) and resume (:498-506, rebuilds only if the day rolled). An "after the
   last class" state needs its own one-shot timer at the last class end.
4. **Board slot:** the `body:` switch at `screens/quests.dart:3503` (beside `dayResting` and Focus)
   is the one place an evening state can replace the list instead of stacking on it, modeled on
   `_restingBody` (:2679). Everything above the Quest list is already full (§2.2).
5. **Night ledger page is a fixed-height folio** with the tomorrow tray pinned to its bottom; a
   class section has to take the empty-day slot in `_FinishedThreadsLedger`
   (`widgets/routine_flows.dart:2365-2383`), which is also where GER's Extra Credit lives.
6. **Morning only arms by closing a night**, and `dayRestingNow` depends on `morningArmed`
   (`engine.dart:1401-1404`), so any change to arming changes the resting board too.
7. **`JournalTrace` has no class field and no `copyWith`**; `screens/quests.dart:832-844` rebuilds
   it field by field, so a new field is silently dropped there unless threaded through.
8. **The Quests room has no evening variant.** The only night room art
   (`assets/routine/room-night-v1.webp`, 853x1844 portrait) is a different camera from the 1635x962
   depth planes. Real hooks: `QuestDepthRoom.layers` / `farOverlay`, `HomeRoom.igniting`, and the
   unused `RewardBundle.revivesHearth`.
9. **Music:** QuestsPage already holds the shell's `BackgroundMusicController`
   (quests.dart:170; shell.dart:2010). There is no session-scoped switch for the main rotation and
   no way to ask for "Lamp left on" specifically.
10. **Notifications:** the iOS pending budget is already full by design (ids 1000, 1001,
    2000-2061 = 64; `platform/notifications_native.dart:24-30`). There are no categories, no actions
    and no tap handling at all (`initialize` at :56-58 registers no response callback).
11. **Widget:** both sides gate on snapshot version 2; after the last class the widget shows
    tomorrow's first class as a bare "8:30 AM" with no day word.
12. **No default-run golden covers these surfaces.** Their goldens are `CAPTURE_*`-gated render
    dumps; copy and layout are pinned by text and key finders (§11).

---

## 1. The academic schedule at runtime

### 1.1 His Fall 2026 grid (from `test/support/rutgers_fall_2026_ics_fixture.dart`)

Term "Fall 2026", 2026-09-01 to 2026-12-10 (:31-32), `America/New_York`, weekly until
2026-12-11 04:59Z (:23). Six courses, twelve series, 168 projected occurrences
(`test/academic_schedule_ics_import_test.dart:19-23`).

| Day | Classes (local) | Last class ends |
|---|---|---|
| Mon | 8:30-9:50 14:332:361 Electronics Devices (SEC 111); 2:00-3:20 14:332:345 Linear Systems & Signals (SEC 111); 5:40-7:00 PM 14:332:345 (SEC 204) | **7:00 PM** |
| Tue | 10:20-11:40 14:332:331 Computer Architecture & Assembly Language (HLL 114); 2:00-3:20 01:198:206 Discrete Structures II (PHY 001) | **3:20 PM** |
| Wed | 8:30-11:30 14:332:333 Computer Architecture Lab (EE 103); 2:00-3:20 14:332:345 (SEC 111) | **3:20 PM** |
| Thu | 8:30-9:50 14:332:361; 2:00-3:20 01:198:206; 3:50-6:50 PM 14:332:363 Electron Devices Lab (EE 209) | **6:50 PM** |
| Fri | 10:20-11:40 14:332:331; 5:55-6:50 PM 01:198:206 (BE 250, Livingston) | **6:50 PM** |

Designated days and recess (fixture EXDATEs :84-216 and `moved(...)` :233-267; asserted in the import test :24-50):
- **Tue 2026-09-08 runs Monday's three classes** (moved from Labor Day 09-07); Tuesday's own two are
  EXDATE-cancelled.
- **Wed 2026-11-25 runs Friday's two classes** (moved from 11-27); Wednesday's own two are cancelled.
- **Thu 2026-11-26** (Thanksgiving): all three cancelled.

Useful render dates: Mon 2026-10-05, Tue 10-06, Wed 10-07, Thu 10-08, Fri 10-09 (EDT, UTC-4).

### 1.2 Who loads and holds it

| Holder | Where | Notes |
|---|---|---|
| Store | `academic_calendar/data/academic_schedule_repository.dart:8-13` (interface), :19-74 `LocalAcademicScheduleRepository`, key `room_of_days_academic_schedule_v1` (:20), corrupt copy key (:21); `InMemoryAcademicScheduleRepository` :79-98 | Separate from the main save on purpose (:15-17). Not in `Storage.exportRaw` (`storage.dart:252-260` reads only `liferpg_save_v1`) and not in the cloud backup, so anything written into a Journal page or day record must copy titles, never point back to the schedule. |
| Shell | field and flag `screens/shell.dart:200-203`; repo :252-253; boot load :267 into `_loadAcademicScheduleForShell` :305-312; file inbox :264, :314-319 (jumps to Plans); `_onAcademicScheduleChanged` :321-326 | Both assignments skip `setState`. They only trigger `_rescheduleNotifications` and `_publishWidgetSnapshot`. |
| Plans | `screens/calendar.dart:127` own copy, loaded through the same repository (:141-142, state set ~:198-205); every mutation saves then calls `_reportScheduleChange` (:379-381) into the shell; NOW/NEXT doorway :944-949, rendered :980-988 with `AcademicDoorway` (`academic_calendar/widgets/academic_calendar_sections.dart:306-428`) | CalendarPage is built lazily on first visit to tab 3 (shell.dart:2039-2056). |
| Widget snapshot | `home_widgets/widget_snapshot.dart:87-134` build, :137-187 `_upcomingClasses` | Published from shell.dart:328-346 (§9). |
| Reminders | `academic_calendar/services/academic_reminder_projection.dart:19-60` | Called at shell.dart:1753-1755 (§10). |
| Importer | `academic_calendar/import/academic_schedule_ics_import.dart`; zone hard-coded `America/New_York` (:7, used :157, :305); moves applied :178-196; EXDATE and `STATUS:CANCELLED` cancellations :197-219; `RECURRENCE-ID` parse :254-275 | Accepts only files with the Room of Days fields (:395-418). |

### 1.3 Reading today's classes (the API that exists)

- `occurrencesOn(CivilDate)` academic_schedule.dart:1166-1172, sorted; **includes cancelled and
  tombstoned rows**. `occurrencesBetween` :1174-1180. `courseById` :1145; `termFor` :1130 (skips
  archived terms); `latestTerm` :1139.
- `doorwayOccurrences(now)` :1486-1499 (15 minutes before start to end; excludes cancelled only),
  `nextOccurrence(now)` :1501-1510.
- `ClassOccurrence` :373-472: `occurrenceKey`, `courseId`, `originalDate`, `date`, `startInstant` /
  `endInstant` (UTC), `localStartMinute` / `localEndMinute` (schedule zone), `kind` (`MeetingKind`
  :13-23), `place`, `timeZoneId`, `state` (`OccurrenceState { scheduled, moved, cancelled }` :25),
  `movedFrom`, `userAdjusted`, `tombstonedAt`; `triggersDoorway` :471.
- **Cancellations:** `cancelOccurrence` :1733-1755 sets `cancelled` + `userAdjusted`; the importer's
  EXDATE and `STATUS:CANCELLED` go through it. A series edit that drops a date leaves a
  `cancelled` row with `tombstonedAt` set (`OccurrenceMaterializer.rebuild` :928-942). Display rule:
  cancelled with `tombstonedAt == null` is a real "no class today" (show neutrally or not at all);
  tombstoned rows are history, ignore them.
- **Designated-day replacements:** `moveOccurrence` :1673-1730 sets `state = moved`, the new `date`,
  keeps `originalDate`, and sets `movedFrom`. On 2026-09-08 `occurrencesOn` returns three moved rows
  (original 09-07, a Monday) plus two cancelled Tuesday rows. A "runs Monday's classes" label can
  come from `originalDate.weekday` when every moved row agrees.
- **Last class end** = max `endInstant` over the real classes on that date.

### 1.4 CivilDate and time zones

- `CivilDate` (`daybook/domain/civil_date.dart:2-68`) is a plain Y-M-D; arithmetic runs on a UTC
  carrier (:31-36); `fromDateTime` (:12) copies the DateTime's own fields (local fields if local).
- `occurrence.date` is the civil date in `occurrence.timeZoneId`; instants are built with
  `TZDateTime` (`OccurrenceMaterializer._resolveInstants` academic_schedule.dart:947-967;
  `localTime` :976-985).
- The app's day is device-local: `Clock.now()` is `DateTime.now()` (`clock.dart:6-8`); `Days.key`
  `models.dart:15`; `Days.nightDate` :63-67 (before 04:00 belongs to the previous day);
  `Days.afterNight` :72-75.
- **Rule for the build:** today = `CivilDate.fromDateTime(Clock.now())` (matches `Days.key`);
  tonight's ledger = `CivilDate.fromDateTime(Days.nightDate(Clock.now()))`; "after the last class"
  = compare `endInstant` with `Clock.now().toUtc()`; show times from `localStart/EndMinute` or
  `localTime()`. The only mismatch is a phone in another zone than the schedule [i], acceptable for
  a first slice.
- **Test trap:** this Windows host runs Eastern time; the Codemagic host zone may not [i]. Existing
  schedule tests build instants with `DateTime.utc` (`test/home_widgets/widget_snapshot_test.dart:14`,
  :39; `test/academic_reminder_projection_test.dart:59-106`). Freeze `Clock` with an instant-correct
  value (for example `DateTime.utc(2026, 10, 6, 19, 35).toLocal()`) and derive dates through the
  schedule zone, or an after-class test passes here and fails in CI. Build 46 failed CI on a
  time-of-day test (HANDOFF §3.2).

### 1.5 Recommended seam

1. New pure file `academic_calendar/services/class_day_projection.dart` [i]:
   `ClassDayGlance projectClassDay({required AcademicSchedule schedule, required DateTime now, CivilDate? day})`
   returning: the date; today's real classes (code, title, kind, start/end UTC, local minutes, moved
   flag, original weekday); today's user cancellations; `lastEndUtc`; the next class (today or
   later, with its date); helpers `hasClasses`, `inClass(now)`, `afterLastClass(now)`. Filter =
   widget_snapshot.dart:142-152 plus archived-term exclusion. Unit-test it on the fixture days in
   §1.1, including 09-08, 11-25 and 11-26.
2. Shell: wrap the assignments at shell.dart:308-309 and :322-323 in `setState`; pass the schedule
   (or the glance) to `QuestsPage` (constructed :1983-2011) as an **optional** parameter defaulting
   to empty, so the twelve test files that build `QuestsPage` directly still compile
   (`grep -l "QuestsPage(" test`: academic_calendar_widget, capacity_journeys, goals_quest_management,
   journal_quest_entry, morrowloom_rebrand, night_routine_feedback, quests_daily_field,
   quests_feedback, quest_domain_history, quest_selection_flow, screenshots, working_experience_visual).
3. From QuestsPage into `NightFlow` (built at quests.dart:1692) and `MorningFlow` (quests.dart:1723);
   the shell's own auto-shown `MorningFlow` (shell.dart:1156); `InsightsPage` (shell.dart:2062-2068)
   into `JournalHubScreen` (insights.dart:168, :549).
4. A one-shot `Timer` to the next boundary (next class end) in QuestsPage, re-armed on rebuild and
   on resume; QuestsPage today has only the 520 ms commit timer and toast timers (quests.dart:200,
   :210, :1206, :1267-1268) and a pause-only lifecycle hook (:700-705).
5. The persisted class credit itself (`DayRecord` / `dayRecords`, schema 29, apply path outside
   `commit()`, undo rules): engine map §6, §3.5, §5.

---

## 2. Quests board first frame (`screens/quests.dart`)

### 2.1 Build path, top to bottom

| Piece | Lines | What it does |
|---|---|---|
| Visible list, sort | :2951-3001 | Scheduled Quests and due events; done ones sink; due events, then MAIN (Today's three), then the rest, all-day last |
| Today's three field | :3002-3036 | `selectedDailyFieldForDay` (chosen), commitments, optional (side) |
| Featured Quest | :3104-3115 | Selected card, else the first actionable visible Quest |
| Evening and resting flags | :3118-3123 | `nightOpen`; `showCloseDayRail = nightOpen && isWindDownTime(now) && (remaining > 0 \|\| visible.isEmpty)`; `dayResting = _state.dayRestingNow` |
| Room strip height | :3133-3152 | `shortFeatured`; `roomHeight` 24 / 48 / 126-156 pt; `sceneHeight` = room + 44 or 116 |
| Day strip | :3166-3199 | Pips from the chosen three; `modeLabel` = THE DAY IS KEPT / FOCUS MODE / GENTLE MODE (:3178-3187) replaces the Today's three tracker; tools disabled while resting (:3195-3198) |
| Side quests divider | :3201-3218 | Shown when the field is chosen and side Quests exist |
| Footer rail | :3220-3232 | MORNING door if armed and not already in the hearth panel; CLOSE DAY if the night is open and the 17:00 rail is not showing |
| Room backdrop and blur | :3246-3260 (classes :4033-4119, :4121+) | `HomeRoom` in a `FittedBox`, `igniting` / `hearthLit` from the shell |
| HUD | :3276-3421 | `_QuestHudPanel` (:4241-4302): desk-look button, LEVEL, rolling XP / next, `_QuestXpTrack` (:4304-4353), six `StatChips`, then `dayStrip` (:3417). :3429-3466 is an `Offstage(true)` legacy row |
| Offstage mantel | :3471-3490 | `InstallHint`, `_hearthPanel`, low-flame bar, all `offstage: true` (the live copies are in the list footer) |
| Header extras | :3494-3498 | Planning ember; `footerRail` in the header only when resting or in Focus |
| **Body switch** | **:3503-3506** | `dayResting ? _restingBody(now) : showFocus ? _focusBody(...) : ListView` |
| List footer | :3520-3539 | `_CloseDayRail` (:3523-3527), `footerRail`, `InstallHint`, `_hearthPanel()` (:3530), low-flame bar, deferred ember |
| Empty or cleared board | :3553-3628 | "The day is sheltered" / "A chosen quest is set aside" / "Enough for today" / "A clear board" |
| **Enough panel** | **:3629-3730** | `remaining == 0 && i == 0`: pop-in, "Enough for today" (:3657-3661), copy (:3672-3676), sub-line (:3685-3691), CLOSE THE DAY HoneyButton (:3697-3705), "take one more step" (:3709-3729) |
| Quest cards | :3739-3888 | `QuestCard` at :3748 (featured flag, Room Guide footer for the featured one), arrival wrapper, undo `Dismissible`, short-phone continuation of the HUD (:3841-3884) |

Resting: `_restingBody` :2679-2760 ("The day is kept." :2701; ledger count line :2707-2711; "The
board opens with the morning." :2720; "I'M NOT DONE YET" :2748; keys `day-resting-panel` :2686,
`day-resting-reopen` :2739); `_liftRest` :2762-2767; engine `dayRestingNow` / `liftRest`
`engine.dart:1401-1411`.

Hearth mantel (one banner at a time): `_hearthPanel` :2017-2027, priority first-ember, morning
(`_morningPanel` :2545-2585, "GOOD MORNING"), energy weather, re-anchor, week recap, today's bonus,
spark.

Today's three: chooser `_chooseToday` :440-462; tracker `_TodaysThreeTracker` :4624-4725 (status
"N open · choose" / "all kept" / "N of 3 kept" :4648-4652); pips :4726-4875. Featured card internals:
`widgets/quest_card.dart` (MARK COMPLETE :184, `_QuestTitleBlock` :632, MAIN chip :675, "Help,
plans & writing" :1217, "Manage" :1262, QUEST COMPLETE :1555).

### 2.2 What is already busy

At 393x852 on a normal weekday the first frame stacks: room strip; HUD with seven controls
(desk-look, six stat chips) plus the Today's three strip with FOCUS and ADD; the featured card with
MAIN chip, title block, XP, MARK COMPLETE and a two-action footer; then compact rows and the side
quests divider. Codex's Build 49 review counted "roughly six competing daily actions before the
normal Quest list" (HANDOFF §3.2), and Mika on 2026-09-28: "i absolutely hate how visually busy
the UI is around your main quest". The list footer is also crowded (rail, footer rail with two
doors, install hint, mantel banner, low-flame bar, ember). **Do not add a row to the HUD or above
the featured card.**

### 2.3 Where a class-day state can slot (ranked)

1. **Body switch, quests.dart:3503 (best fit for "after the last class, evening").** Add a third
   state beside `dayResting` and Focus, built like `_restingBody` (:2679): one panel naming the day
   and a small set of doors, with the board one tap away (the `_liftRest` pattern at :2762, as a
   session or per-night flag). It replaces the list instead of stacking above it, keeps the HUD and
   Today's three, and the header already shows `footerRail` for non-list bodies (:3497). Gate it on
   a non-empty class day so `test/night_routine_feedback_test.dart:302-361` (20:30, no schedule)
   still sees the list and its `close-day-rail`.
2. **Room strip height, :3144-3152.** An evening state can give the room more of the frame
   (`roomHeight`, `sceneHeight` and the header spacer at :3275 move together).
3. **Mantel `_hearthPanel`, :2017-2027.** One-banner slot already arbitrated by priority; cheap for
   a "classes are done" line, but it renders in the list footer (:3530), below the fold on a full
   board.
4. **Enough panel slot, :3629.** When Today's three are kept, the panel's copy (:3672-3691) is the
   natural place to name the class day too; do not create a second top-of-list card.
5. **Avoid:** `modeLabel` (:3178), which hides Today's three; any new HUD row.

Wind-down: `isWindDownTime` (`content/routines.dart:605`, hour >= 17 or < 4) has one caller,
quests.dart:3119-3120 (§12.5).

---

## 3. Night ledger (`widgets/routine_flows.dart`, `widgets/routine_ledger.dart`)

### 3.1 How it opens

| Door | Where | Gate |
|---|---|---|
| Footer rail CLOSE DAY | quests.dart:3229-3231 → `_BoardFooterRail` :4976-5034 (label :5001) | not resting, night open, 17:00 rail not shown |
| 17:00 rail "CLOSE THE DAY" | quests.dart:3523-3527 → `_CloseDayRail` :5036-5114 (key `close-day-rail` :5055, copy :5045-5047, :5078) | `isWindDownTime(now)` and work left or an empty board |
| Enough panel button | quests.dart:3697-3705 | all of Today's three kept and the night still open |
| 21:00 reminder | `platform/notifications_native.dart:237-259`; scheduled from shell.dart:1804-1815 with `skipNext` (`shouldSuppressNextNightReminder` shell.dart:67-76) | **Launches the app only.** No response handler exists anywhere in `lib`, so the tap lands on whatever tab was last open; it never opens the ledger |

All three in-app doors call `_openNight` (quests.dart:1684-1716), which inserts an `OverlayEntry`
with `NightFlow`; on close it may record a perfect day, toasts achievements, and calls
`onNightClosed` (shell.dart:1998-2000 reschedules notifications). GER replaces this overlay with an
owned dialog route plus a local Navigator (engine map §0); take that refactor with Extra Credit.

### 3.2 Structure

- `NightFlow(state, quests, onAdd, onPersist, onClose)` :29-47; title "Close the ledger" / "Mark
  tomorrow" (:133); `RoutineLedgerScaffold` (`routine_ledger.dart:63-394`, night room plate
  :205-208) with date label from `Days.nightDate` (:137), dismiss "NOT YET" (:138); primary CLOSE THE
  DAY / KEEP THESE THREE (:153); secondary "reflect · optional" or "edit tonight's page" (:159-160).
- `_finish` :82-96: `finalizeNightJournal(nightJournalTrace)`, `closeNight()` (arms morning),
  persist, close.
- **Recap page** `_ledgerRecap` :203-378, a `Stack` inside a fixed folio (`RoutineLedgerPage`
  routine_ledger.dart:583+, folio height = width x 1.034 on a normal phone, :623-640): WHAT MOVED
  (:239); rolling "+N XP" (:244-262, text :251); top three stat gains or "the quiet days still
  count" (:267-275); "N THREAD(S) FINISHED" (:306-309) over `_FinishedThreadsLedger` (:312-319,
  class :2340-2445, fixed 82-132 pt tall, collapsed to three titles plus "and N more!"); "N ready to
  rise" (:320-341); one all-day line (:345-355); the **tomorrow tray pinned at the bottom, 126 pt
  tall** (:364-373).
- Reads: `nightXp`, `nightStatGains`, `nightQuestTitles`, `nightCompletionCount`
  (`engine.dart:1118-1131`), all Quest-only.

### 3.3 Empty-day copy (what a class-only Monday shows today)

| Line | Text |
|---|---|
| routine_flows.dart:251 | "+0 XP" (the template `'+$value XP'` at 0) |
| :269 | "the quiet days still count" |
| :308 with `_ledgerCountWord(0)` :2210-2225 | "NO THREADS FINISHED" |
| :2374 | "Nothing had to be proven today." |
| routine_ledger tray | "MARK TOMORROW" with "Choose one" placeholders |

Replace the :2365-2383 empty branch with the class day (and Extra Credit) when classes exist; keep
the copy above for genuinely empty days.

### 3.4 Tomorrow tray and planner

- `_tomorrowQuests` :98-105 (`planningQuestsForDay` for `Days.afterNight`), `_orderedPriorities`
  :107-118; tray `_LedgerTomorrowTray` :2618-2811 (semantic label :2632-2634, "MARK TOMORROW"
  :2654 and :2744, tray art `top-three-tray-v2.webp`); planner page `_ledgerPlanner` :380-617
  ("KEEP THREE CLOSE · n/3" :392, tomorrow adder :485).
- Blind to tomorrow's classes. The natural addition is tomorrow's first class beside the three
  (`projectClassDay(day: afterNight)`), in the planner page rather than the 126 pt tray.

### 3.5 Dead code in this file

`_recap` (:704), `_tomorrowHook` (:618, called only from `_recap` :1176), `_planner` (:1199) and
`_LegacyMorningFlow` (:1654) sit behind `// ignore: unused_element` (:703, :1198, :1653). Their copy
(em dashes at :765, :867, :910, :1214; the "not failure" line at :765) never renders. Do not spend
copy work there; deleting them is a separate cleanup.

### 3.6 Extra Credit's slot (GER, from the snapshot diff)

GER passes `extraCredit` and `onExtraCredit` into `_FinishedThreadsLedger` and adds
`extraPageHeight: 96` to `RoutineLedgerPage` (`extra-credit-tracked-files.diff` hunks at
routine_flows :53-105, :194, :356-366, :2394-2603). A class section must share that slot and that
height budget with Extra Credit.

---

## 4. Morning flow arming and auto-show

| Piece | Where |
|---|---|
| Armed flag | `engine.dart:1357` `morningArmed`; set only in `closeNight` :1376-1386 (:1380); cleared in `closeMorning` :1390-1395 |
| Auto-show gate | `morningPending` :1476-1479 (armed and 4 h since `nightDoneAt`, `_morningGapMs` :1369); `morningAvailable` :1484 (armed) |
| Resting coupling | `dayRestingNow` :1401-1404 = armed and tonight closed and not lifted |
| Persisted | toJson :2387-2389; fromJson :2772, :2788-2792 |
| Shell auto-show | `_maybeMorning` shell.dart:1124-1177: after startup and What's New, onboarded, `morningDoneDay != today`, `morningPending`; inserts `MorningFlow` (:1156-1173). Called from load :573, resume :503, midnight :481, What's New dismiss :1119 and restore paths :767, :811, :1032 |
| In-app doors | footer MORNING (quests.dart:3226-3228, `_openMorning` :1718-1738); mantel "GOOD MORNING" (:2545-2585) |
| Page | `MorningFlow` routine_flows.dart:1412-1650: "Open the day" (:1524), "YOUR THREE" (:1550), tomorrow-self note (:1556), lead Quest plus two lines, "TODAY FEELS" capacity tabs (:1593), footnote (:3382-3445), primary OPEN THE DAY (:1541), dismiss LATER (:1526) |

A student who never closes the night never sees it. Arming on "first open of a class day before
noon" [i] would touch `morningPending` (engine :1476), the shell gate (:1150-1153), and
`dayRestingNow` (:1401). The page is already full; classes would replace a lead line, not add rows.
Tests: `test/morning_auto_open_test.dart:48`, :65-122, :274-298; `test/day_rest_test.dart:18-57`.

---

## 5. Journal

### 5.1 The trace

- `JournalTrace` `models.dart:593-668`: `day`, `level`, `totalXp`, `todayXp`, `streakDays`,
  `questTitles`, `goalTitles`, `statGains`, `energy`; `hasDayEvidence` :616-621; toJson :623-634;
  fromJson :636-668. Stored on `Note.trace` (:762; toJson :872; fromJson :887).
- Built only in the engine: `todayJournalTrace` `engine.dart:1109-1116`, `nightJournalTrace`
  :1133-1144, both through `_journalTrace` :1146-1176. No schedule input.
- Rebuilt by hand in `screens/quests.dart:821-845` (`_journalTraceFor`, Quest-scoped pages). **A new
  field must be threaded here or it is dropped.** Also passed through in `goal_adjustment.dart:447`
  and `Note.withNight(updatedTrace:)`.
- Written: quick reflection quests.dart:1049; Quest page :869; night page routine_flows.dart:73 and
  finalized :94; free page journal_hub.dart:211.

### 5.2 Where a trace is shown

| Surface | Where | Class-only day today |
|---|---|---|
| Hub "TODAY'S THREAD" | `screens/journal_hub.dart:833-890` (label :853, line :861-864, titles :867-879) | "The date, your build, and what you've completed so far today attach to this page." (:864) |
| Hub trace line | `_traceLine` :79-95 (fallback "LEVEL n" :94); feed cards :1047-1050 (only if `hasDayEvidence`) | "LEVEL n" |
| Entry page "ATTACHED TO THIS PAGE" | `screens/journal_entry.dart:1031-1032`, `_tracePanel` :1137-1200 (label :1166) | "Level n · X total XP" (:1176) |
| Journal tab list | `screens/insights.dart:424-425` (LV and QUESTS) | level only |
| Plans day view | `screens/calendar.dart:838`, :873 | by `trace.day` |

Adding `classTitles` (engine map §6.2 calls it `classesKept`) needs: the model field with optional
toJson; both engine builders; the quests.dart:832 copy; `_traceLine`, `_todayThread`,
`_tracePanel` and `hasDayEvidence`.

### 5.3 Hub layout facts for this pass

Journal tab (`InsightsPage`, insights.dart:91-150) → `JournalHubScreen` (journal_hub.dart:30+). Hub
list padding 16 pt (:560); composer `_composer` :736-831 with the prompt chip row :776-829
(§12.3); Keepsakes card `_cabinetCard` :608-660 (§12.2). The night page itself is written through
`showNightReflectionSheet` (`widgets/night_reflection_sheet.dart`).

---

## 6. Home room and the depth room

- **Quests room:** `_QuestRoomBackdrop` (quests.dart:4033-4119) renders `HomeRoom`
  (`widgets/home_room.dart:554-660`) with `plateId: activeQuestDeskLook(state).roomStyleId`,
  parallax, scroll light, `igniting`, `hearthLit`, `emberGlow`, `level`, room photo. It passes no
  `window` and no `memoryArtifacts`.
- **Writer's Hearth** (`plateId == 'wall_walnut'`) renders `QuestDepthRoom`
  (`widgets/quest_depth_room.dart:33-121`; planes and offsets :190-210) at home_room.dart:836-880.
  Hooks: `layers: QuestRoomLayers` (four plane assets; :65-76 show two sets), `farOverlay` (used
  for the room photo), `wallAssetOverride`, `flattenedAsset`, `igniting` / `hearthLit`. Other rooms
  are painted plates with live fire (:880-930) from `content/space_themes.dart`.
- **Time of day:** none on the board. Window scenes (`content/window_scenes.dart`, painter
  `paintWindowScene` home_room.dart:3690+) are bought cosmetics, used by the procedural room and
  visit/discover views (`discover_spaces.dart:759`, `hearth_circle.dart:1303`, `visit_room.dart:280`);
  plates bake their window. Fire ignores streak and level (home_room.dart:620-623).
- **Evening art that exists:** `assets/routine/room-night-v1.webp` and `room-morning-v1.webp`
  (853x1844 portrait, `assets/routine/GENERATED-ASSETS.md:20-21`), used only as the ledger backdrop
  (`routine_ledger.dart:205-208`, `_RoutineRoomPlate` :395-443, fire `_RoutineLivingFire` :503-580).
  Different camera from the 1635x962 depth planes, so not a drop-in for the Quests strip. A true
  evening Quests room means either a registered evening plane set through `layers` [i] or a grade
  plus window-glow overlay through `farOverlay` [i].
- **Reacting to the day:** the shell owns the once-per-session ignition (shell.dart:1183-1219,
  `fire_ignite`) and passes `roomIgniting` / `roomHearthLit` into QuestsPage (:2004-2005).
  `RewardBundle.revivesHearth` (`models.dart:1532-1537`) is unused in `lib` but pinned by
  `test/audit_regressions_test.dart:31-55`. A class-day or evening beat would drive the backdrop's
  `igniting` from QuestsPage state [i]. `memoryArtifacts` (home_room.dart:569, fed on Me at
  `screens/me.dart:2448`) is the existing hook for a shelf that fills.

---

## 7. Music

| Piece | Where |
|---|---|
| Preference | `GameState.musicEnabled = false` (`engine.dart:89`), `setMusic` :121-125, saved :2253, loaded :2408; Me toggle "Background music / jazzy room rotation · optional" (`screens/me.dart:3421-3432`) |
| Boot | `main.dart:60-72` starts `MainRoomMusic.instance` from the saved flag |
| Controller | `BackgroundMusicController` (`background_music.dart:81-300`), one per shell (shell.dart:251-259, :861-862); roles `main` / `focus` (:11); `_desiredRole` :133-140 (main only when the global flag is on; focus only inside a Focus session); `setEnabled` :146, `enterFocusSession` :154, `leaveFocusSession` :163, `setSessionEnabled` :171, `setSessionMuted` :177, `setForeground` :183, `retryAfterUserGesture` :189 |
| Lifecycle | `musicShouldRunForLifecycle` shell.dart:80-81, applied :488-493; gesture retry on any pointer down :1931-1933 |
| Main rotation | `MainRoomMusic` (`main_room_music.dart:244+`): 22 dry takes plus "Lamp left on" as take 23 in its own composition group (:256-271, asset `music/lamp-left-on.m4a`), shuffle bag `MusicRotation` :28+, 96 s takes, crossfades (:278-285), ducking `MusicDucker` :152+ |
| Focus | `widgets/timer_overlay.dart:93-106` enters a Focus session; in-overlay toggle `_MusicControl` (:422-427, class :708) |

**Can a screen offer "stay a while"?** Yes on the Quests board: it already receives the controller
(quests.dart:170, passed on to the timer at :1007). Two gaps: (a) no session-scoped main-role switch.
`setEnabled` mirrors the saved preference, so a screen either flips the Me setting
(`state.setMusic` plus `setEnabled` plus persist, exactly as Me does) or the build adds a
session flag to `_desiredRole` mirroring the Focus session API [i]. (b) No way to start on "Lamp
left on"; that needs a "prefer this take next" hook in `MainRoomMusic` / `MusicRotation` [i].
Respect the saved default (off); a tap is the gesture that unlocks playback. Tests:
`test/background_music_test.dart`, `test/timer_overlay_music_test.dart`,
`test/music_asset_roles_test.dart`. Read `SOUND-DESIGN.md` before any sound work.

---

## 8. Steward

- **Path today:** Goals tab → "Your goals / Review & reshape" door (`screens/goals.dart:1477-1478`)
  → `_openWorkshop` (:344-360) → `GoalWorkshopScreen` (`screens/goal_workshop.dart:28+`) →
  register footer "Talk with the Steward" / "Continue talking" (:526-552, keys `goal-workshop-talk`
  and, before discovery, `steward-hidden-card` at :409-431) → `_openEncounter` (:130-146) →
  `stewardRoomRoute` (`widgets/steward_room.dart:24-40`, route name `/goals/workshop/supper`) →
  `StewardEncounterScreen(state, onPersist)` (`screens/steward_encounter.dart:13-21`).
- **Content and memory:** one scene, `stewardEncounter` map (`content/steward_encounter.dart:41+`),
  first line `soup-hello` (:36), choice key `soup-note` (:37). `StewardMemory`
  (`steward_memory.dart:6-86`) holds a single `discovered`, `completed`, `nodeId`, `choices`;
  persisted at `engine.dart:53`, :2396, :2401. The screen marks discovery and progress at
  steward_encounter.dart:43-49, :81-82, :97-98.
- **What an evening door needs:** the route and screen are self-contained (state plus persist), so
  a door on the evening board can push `stewardRoomRoute` directly. More scenes need a scene
  registry and per-scene memory (today's single `nodeId` / `completed` cannot hold two scenes),
  migrated so the existing soup scene keeps its state. "Unlocks by days lived" needs a counter
  that does not exist: `history` counts only completion days, and the usage log
  (`storage.dart:349-367`) is a capped diagnostics buffer, not game state [i]. Tests:
  `test/goal_workshop_conversation_test.dart:49-105`, `test/steward_encounter_test.dart:104-330`,
  steward soup shots `test/screenshots_test.dart:2771-2833` (capture-gated).

---

## 9. Widget snapshot and the Swift widget

| Piece | Where |
|---|---|
| Snapshot model | `home_widgets/widget_snapshot.dart:16-17` (version 2, class limit 24); `WidgetSnapshot` :19-43 (`generatedAt`, `upcomingClasses`, `incompleteQuests`); `WidgetClassGlance` :45-73 (code, title, start/end local ISO, start/end epoch ms, zone); `WidgetQuestGlance` :75-84 (hashed id, title) |
| Builder | :86-134: up to three open Quests from `planningQuestsForDay`, non-all-day, ordered overdue event, event, Today's three, normal, bonus; classes :137-187 (filter :142-152) |
| Writer | `widget_snapshot_writer.dart:13-30`, channel `room_of_days/home_widget`, method `writeSnapshot` |
| Publish | shell.dart:328-346 (needs state, quests and a loaded schedule); called after storage load :872, schedule load :311, schedule change :325, and **every successful save** :1238 |
| Native bridge | `ios/Runner/AppDelegate.swift:102-128`: App Group `group.com.mikabe.emberkeep`, key `roomOfDaysWidgetSnapshotV2`, `reloadAllTimelines()` on each write |
| Swift | `ios/RoomOfDaysWidgets/RoomOfDaysWidgets.swift`: key :5; decoder :7-34; **`decoded.version == 2` gate :106**; timeline: now plus one entry per class end + 1 s, refresh 15 min after the last boundary (:79-99); `nextClass` = first class not yet ended (:40-45); small :161-188, medium :190-246; `StaticConfiguration`, `.systemSmall` / `.systemMedium` (:269-279); no `widgetURL`, no App Intents; widget target deploys to iOS 15.0 (`ios/Runner.xcodeproj/project.pbxproj:702`, :729, :756) |

Behavior on his days [v from code]:
- After the last class the snapshot drops ended classes, so `nextClass` becomes tomorrow's first
  class, shown as "NEXT CLASS / 14:332:361 / 8:30 AM" with **no day word** (`classTime` :260-266).
- With no class at all, the small widget prints the "NEXT CLASS" eyebrow over "Your day is open"
  (:163, :178).
- Nothing refreshes at midnight: yesterday's three linger until the app saves again.

An after-class state needs [i]: a snapshot v3 carrying today's day key, today's class count and
last end (or today's full list including ended ones), whether the class day was counted, and
Today's three kept/total; the Swift decoder and its version gate updated in the same build (the
snapshot key name is shared by AppDelegate :105 and Swift :5); a timeline entry at the last class
end and at midnight; a day word for a next class that is not today. Interactivity (iOS 17
`Button(intent:)`) needs an availability guard on the iOS 15 target and a queue the app applies on
next open (engine map §5 for undo; roll() is random, so XP cannot be applied in Swift).
`widgetURL` could deep-link with the existing `roomofdays` scheme (`ios/Runner/Info.plist:27-35`),
but the Dart side only parses room-share links (`social.dart:58-71`, `main.dart:150-175`), so a new
intent inbox would be needed. Tests: `test/home_widgets/widget_snapshot_test.dart:13-90`;
`test/release_native_privacy_test.dart:600` (runbook "small Day Ledger widget") and :785-820 (App
Group in both entitlements, widget Info.plist, three widget bundle ids).

---

## 10. Notifications

### 10.1 What exists

- `platform/notifications_native.dart`: ids daily 1000, night 1001, events 2000+ (:24-27), **62
  event slots so the total stays at iOS's 64 pending** (:28-30); `init` :41-75 (no categories, no
  `onDidReceiveNotificationResponse`, no background handler); permission request :87-114 and silent
  check :121-152; one shared `_details()` (:157-167, knock sound `knock_paced.wav`, Android channel
  `emberkeep_reminders_v2`); daily time :169-206; `scheduleDailyNudge` :208-226 (copy :214-215);
  `scheduleNightRoutine` :237-259 (copy :247-248); `scheduleEvents` :271-308 (absolute instants for
  classes :282-283); `EventReminder` :332-347. Web stub: `platform/notifications_stub.dart`.
- Shell: `_rescheduleNotifications` :1738-1743 (serialized), `_rescheduleNotificationsNow`
  :1745-1817: class notices :1753-1755; silent permission check that turns prefs off when denied
  (:1760-1768, `disableRemindersWithoutPermission` `engine.dart:818-823`); plan and class events
  (:1770-1793); daily nudge (:1794-1798); events (:1799-1803); night with `skipNext` (:1804-1816).
  Called on load :575, resume with zone refresh :504, schedule load/change :310/:324, Me toggles
  (:1967), night close (:1998-2000) and others.
- Prefs: `engine.dart:790-799` (`notifyEnabled` false, 9:00; `nightReminderEnabled` false, 21:00);
  Me rows "Quest & plan reminders" (`screens/me.dart:3737`) and "Night routine reminder" (:3764),
  header line :3726.
- Class reminders: `projectAcademicReminderNotices` (academic_reminder_projection.dart:19-60), title
  "Class in N minutes · CODE" (:49), per-series opt-in at import.
- iOS: `AppDelegate.swift:136-139` sets the `UNUserNotificationCenter` delegate (the plugin needs
  it); sound file `ios/Runner/knock_paced.wav`.

### 10.2 What a one-a-day after-last-class knock needs [i, plugin API not exercised here]

1. **A slot.** Give it a fixed id outside 2000-2063 and drop `_eventScheduleSlots` to 61, or
   schedule it as an event. Plan and class reminders already share the 62 event slots.
2. **A schedule.** The time differs by weekday, so project absolute one-shots (last class end plus
   a few minutes) for the next class days from `projectClassDay`, inside `_rescheduleNotificationsNow`
   next to :1753. Suppress today's once the class day is counted or the app was opened after the
   last class (like the night `skipNext`), and reschedule on that change.
3. **A preference**, default off: new `GameState` field, save/load, a Me row near :3737 / :3764,
   included in the permission condition at shell.dart:1758-1763 and in
   `disableRemindersWithoutPermission`.
4. **iOS action buttons** with `flutter_local_notifications` ^18.0.1 (`pubspec.yaml:55`): a
   `DarwinNotificationCategory` with two `DarwinNotificationAction`s in
   `DarwinInitializationSettings.notificationCategories`; `categoryIdentifier` on this
   notification's `DarwinNotificationDetails` (so `_details()` becomes a function, keeping the
   literal `sound: 'knock_paced.wav'` that `test/interaction_sound_quality_test.dart:1061` greps
   for); `onDidReceiveNotificationResponse` plus a top-level
   `@pragma('vm:entry-point')` background handler; `getNotificationAppLaunchDetails()` at launch for
   a cold-start tap; routing into the shell through an inbox like `RoomLinkInbox` (`social.dart:100`).
5. **No headless rewards.** A background action cannot run `roll()` / the engine safely; either use
   a foreground action option that opens the app and runs the normal receipt, or queue the action
   with the day it happened and apply it on next open (engine map §3.6 on the night-key check).
6. **Copy rules** (§12) and the room's knock. Draft wording for Mika's review only: title "That's
   the last class today", body "Count your classes, or come sit in the room for a bit.", actions
   "Count today's classes" and "Open the room".

---

## 11. Tests and goldens that pin these surfaces

Default run = text, key and logic asserts. Goldens marked "capture" only compare or write with the
named `--dart-define`; none of these surfaces has a default exact golden (default exact compares
are Windows-only and cover Quest cards, Room Guide, Plans, warm background and goal journal:
`test/quest_mastery_visual_test.dart`, `test/momentum_kits_test.dart:286-292`,
`test/academic_calendar_visual_test.dart`, `test/warm_background_visual_test.dart`,
`test/goal_journal_opening_visual_test.dart`).

| Surface | Test (lines) | Pins |
|---|---|---|
| Resting board | `test/day_rest_test.dart:18-57` (engine), :59-96 (widget) | `dayRestingNow`, `liftRest`, keys `day-resting-panel` :84 / `day-resting-reopen` :88, "The day is kept." :85, no "THE DAY IS KEPT" after reopen :95 |
| Wind-down and evening rail | `test/night_routine_feedback_test.dart:30-35` | `isWindDownTime` at 16:59, 17:00, 03:59, 04:00 |
| | same file :302-361 | At 20:30 with no schedule: `close-day-rail` :341, "CLOSE THE DAY" :344, then "Close the ledger" :357 |
| Night journal and trace | same file :40-153, :175-300, :363-530 | reminder default off, night page identity, 3 am ownership (`trace.day`, `todayXp`, `questTitles` :132-135), reflection chips ("TOMORROW" :222 is the night sheet's chip), CLOSE THE DAY :268-272 |
| Ledger layout | `test/routine_ledger_visual_test.dart:218-265` | "Close the ledger" :244, "+114 XP" :245, "MARK TOMORROW" :246, planner "KEEP THREE CLOSE · 3/3" :258 |
| | :267-300 | "Open the day" :284, "STEADY" :286, "YOUR GENTLE THREE" :298 |
| | :302-430 | narrow 320x568 at 2x text, no overflow; capture goldens :340, :379, :398, :425 |
| | :482-557 | "EIGHT THREADS FINISHED" :520, "and 5 more!" :521, "show fewer" :547-554 |
| | :559-620 | tomorrow bookmark order becomes the morning order |
| Shell flow | `test/widget_test.dart:1012-1031` | footer "CLOSE DAY" opens "Close the ledger" and "WHAT MOVED", then "CLOSE THE DAY"; `NightFlow` direct :1054; trace round trip :1412-1433 |
| Morning | `test/morning_auto_open_test.dart:48`, :65-122, :274-298 | armed save, cold start and resume auto-open "Open the day", once per day, What's New first |
| Today's three | `test/quests_daily_field_test.dart:88-105`, :132-137, :170-175; `test/quests_feedback_test.dart:147` | "Today's three", `daily-field-rail`, `side-quests-divider`, "all kept" |
| Board render dumps | `test/screenshots_test.dart:920-970` (capture) | `quest_board.png`, `quest_board_compact_rows.png`, `streak_freeze_sheet.png`; default asserts that the first Quest action clears the dock (:925-931) |
| | :1060-1230 (capture) | `quests_daily_field_*` goldens; default text asserts "Today's three", "all kept" |
| | :813-860 (capture), store :1722 (`store_01_quests`), :1885 (`store_07_journal`), :2355-2410 (night and morning store shots) | journal hub dumps and App Store frames (`tool/export_store_screenshots.dart:16`, :64) |
| | :2771-2833 (capture) | steward soup frames |
| Journal | `test/journal_read_mode_test.dart:150-472`; `test/journal_editor_material_test.dart:35-41`; `test/journal_quest_entry_test.dart` | "Write a new entry" :261, "Kept in Keepsakes" :235; const `JournalTrace` constructions (a new required field breaks them; keep it optional) |
| Steward | `test/goal_workshop_conversation_test.dart:49-105`; `test/steward_encounter_test.dart:104-330`; `test/goal_workshop_visual_test.dart` (capture) | keys `goal-workshop-talk`, `steward-hidden-card`, `steward-encounter`, "Talk with the Steward", "Continue talking" |
| Music | `test/background_music_test.dart`, `test/timer_overlay_music_test.dart`, `test/music_asset_roles_test.dart` | role transitions, Focus session, take list |
| Widget | `test/home_widgets/widget_snapshot_test.dart:13-90` | version, next class, advancing past an ended class, three-Quest order |
| Native | `test/release_native_privacy_test.dart:600`, :785-820 | runbook line, App Group, widget plist, bundle ids, `import UserNotifications` and the delegate line |
| Notifications | `test/notification_permission_test.dart:8-120`; `test/academic_reminder_projection_test.dart:6-110`; `test/interaction_sound_quality_test.dart:1043-1066` | permission clears prefs, night `skipNext` ownership, class reminder instants and title, knock file bytes and source strings |
| Schedule | `test/academic_schedule_ics_import_test.dart:8-60`; `test/academic_schedule_import_widget_test.dart`; `test/academic_schedule_test.dart` | 168 occurrences, designated days, recess |
| Rewards | `test/audit_regressions_test.dart:31-55` | `revivesHearth` |
| Release notes | `test/release_notes_test.dart:8-60`; `test/whats_new_screen_test.dart:64`, :149-159 | ordered ids, current release key; no test pins the 1.0.2+20 highlight text |

Also in W, **untracked and not from this task**: `test/design_renders/class_day_harness.dart` and
`class_day_current_test.dart` (created 2026-10-03 13:03, gated by `CLASS_DAY_RENDERS`) and
`design/comparisons/2026-10-03/`. They boot the real `LifeRpgApp` on his schedule; reuse them for
renders rather than writing a second harness. There is **no banned-word guard test** for user copy;
one cheap test over `lib/**.dart` string literals would hold the §12 rules [i].

---

## 12. Copy defects to fix in the same pass

Wording rules for anything new: no em dashes, no "not this, but this", never failed, missed, lost,
broke or skipped; plain, warm, specific. Drafts below are for Mika's review, not final copy.

1. **"missed" in What's New.** `content/release_notes.dart:872`, inside the 1.0.2+20 entry
   (:854-880), highlight "A SOFTER LANDING". Users reach it through the manual history (Me
   `screens/me.dart:3191` → `screens/whats_new.dart:42` shows every release when not automatic).
   Draft, in the app's own freeze wording (`widgets/streak_freeze_status.dart:81`): "Streak
   freezes can quietly hold a day away, then refill as you keep showing up." No test pins it.
2. **"1 artifacts".** `screens/journal_hub.dart:643`, Keepsakes card subtitle
   (`'$count artifacts · $chosen ...'`). Pluralize like the `moment` half of the same line.
3. **Journal prompt chips cut off.** `screens/journal_hub.dart:786-829`: four chips (QUEST THREAD
   or SMALL WIN :790-805, UNLOAD :806-812, GRATEFUL :813-819, TOMORROW :820-826) in a horizontal
   `SingleChildScrollView` inside the list's 16 pt padding (:560). The row is wider than the
   content box on 360-393 pt phones, so the last chip is sliced at the padding edge with no scroll
   cue (the label itself never ellipsizes). Fix with a `Wrap` (spacing 7, run spacing 7) or let the
   scroller bleed to the screen edge with trailing padding; render at 320, 360 and 393 pt. Same
   composer has em-dash copy at :758, :863 and :944 (plus :586, :723 on this screen).
4. **The 9:00 nudge leans on loss.** `platform/notifications_native.dart:214-215`, title "Your
   quests are waiting", body "One small win before the day gets away from you." Draft: title "The
   room is open", body "Pick one small quest whenever you're ready." For a class day, the
   after-class knock (§10.2) is the better default.
5. **Wind-down ignores late classes.** `content/routines.dart:605`
   (`now.hour >= 17 || now.hour < 4`), one caller quests.dart:3119-3120. On Monday (last class
   7:00 PM), Thursday and Friday (6:50 PM) the "CLOSE THE DAY · Close whenever you're ready." rail
   shows from 17:00 while he is still in class; on Tuesday and Wednesday (3:20 PM) nothing
   evening-shaped appears until 17:00. Shape: `isWindDownTime(now, {DateTime? lastClassEnd})`,
   true when the 17:00/04:00 window holds and `lastClassEnd` is null or past, and optionally true
   from `lastClassEnd` on class days [i]. The four asserts at
   `test/night_routine_feedback_test.dart:31-34` stay valid with `lastClassEnd: null`.
6. **Em dashes on the surfaces this pass touches** (fix while there; app-wide there are about 218):
   quests.dart:960, :1340, :1356, :1442, :1511, :1632, :1816, :2224, :2472-2475, :2506, :2828,
   :3583, :3689, :5157, :5781, :5811, :5935, :5944; journal_entry.dart:736-737, :1468;
   insights.dart:815, :1099, :1226, :1238; `content/weekly_chronicle.dart:39` (and the range
   separator at :35). Also the emojis in the "GOOD MORNING" mantel line (quests.dart:2570) and at quests.dart:960.
7. **Weekly chronicle reads a class week as quiet.** `content/weekly_chronicle.dart:37-41` counts
   Quests only; "a quieter week" plus an em-dash clause at :39.

---

## 13. Handoff corrections (checked against W)

1. HANDOFF §4.2 "Enough panel :3566-3731": the "Enough for today" celebration is quests.dart
   :3629-3730. :3553-3628 is a separate empty or cleared-board panel that can also title itself
   "Enough for today" (:3569).
2. HANDOFF §4.2 "HUD :3283-3405": the HUD panel is :3284-3421; its last child is the Today's three
   strip (:3417); :3429-3466 is an `Offstage(true)` legacy row.
3. HANDOFF §10 #17 and STUDENT-DAY §4.13 "Journal prompt chips clipped ("TOMO…")": there is no
   ellipsis. The chip row is a horizontal scroller cut at the hub's 16 pt padding
   (journal_hub.dart:560, :786-829). STUDENT-DAY §3 also lists the chips as SMALL WIN first; when a
   Quest was done today the first chip is QUEST THREAD (:790-797).
4. STUDENT-DAY §3, Day Ledger widget, "Quest list frozen at the last app open": the snapshot is
   republished after every successful save (shell.dart:1238) and on schedule load or change
   (:311, :325), so it is current as of the last save while the app ran. What stays true: no
   midnight refresh, and Swift timeline entries only at class ends (RoomOfDaysWidgets.swift:79-99).
5. STUDENT-DAY §3 Notifications ("No action buttons, nothing after class ends"): also no tap
   routing of any kind. The 21:00 reminder only launches the app; it does not open the ledger.
6. STUDENT-DAY Opportunity 6: `_rescheduleNotificationsNow` is shell.dart:1745-1817 (not
   :1746-1800). Adding any recurring notification collides with the 64-slot budget
   (notifications_native.dart:24-30).
7. HANDOFF §4.6 "Nothing in engine.dart or quests.dart reads AcademicSchedule" stands. Add: the
   shell holds it (shell.dart:202) but updates it without `setState` (:308, :322), so passing it
   down requires that change.
8. HANDOFF §6 and §10 #14 call `RewardBundle.revivesHearth` dead: it is unused in `lib` but pinned by
   `test/audit_regressions_test.dart:31-55`; deleting it fails that test.
9. STUDENT-DAY Opportunity 2 points at the night routine art for an evening room:
   `assets/routine/room-night-v1.webp` is an 853x1844 portrait plate on its own camera, not a
   drop-in for the 1635x962 Quests depth planes.
10. HANDOFF §3.4 item 6 cites "missed" at release_notes.dart:872 as current What's New: it is in the
    historical 1.0.2+20 entry (:854-880), visible through the manual history from Me
    (me.dart:3191; whats_new.dart:42). The fix still applies.
11. HANDOFF §4.3 / STUDENT-DAY Opportunity 4 treat routine_flows.dart as one live file:
    `_recap` (:704), `_tomorrowHook` (:618), `_planner` (:1199) and `_LegacyMorningFlow` (:1654) are
    dead code behind `ignore: unused_element`; their copy never renders.
12. Task context timetable: correct, with two details worth having. Friday's last class is a
    5:55-6:50 PM lecture on Livingston after a 10:20-11:40 AM class (a six-hour gap). Designated
    days: Tue 2026-09-08 runs Monday's three classes, Wed 2026-11-25 runs Friday's two, and Thu
    2026-11-26 has none.

---

## 14. Rendering a real class day (for evidence)

- Reuse the untracked harness in `test/design_renders/class_day_harness.dart` (boots `LifeRpgApp`,
  real fonts and art, his schedule, `CLASS_DAY_RENDERS` gate), or the technique in
  `C:/Users/mikus/Documents/Claude/room-of-days-handoff/sources/tmp/mika-folio/rod-ref-frames/_harness_rod_ref_frames_test.dart.txt`:
  `FontLoader` for MaterialIcons, Fraunces, Inter, JetBrainsMono, EBGaramond (:96-120); seeded
  `SharedPreferences.setMockInitialValues` (:267); `LifeRpgApp` (:276); precache room art in
  `runAsync` (:280-296); 393x852 at 3x with safe areas 59/34 (:307-312); PNG via
  `layer.toImage` (:41-50).
- `LifeRpgApp` builds `AppShell` without a repository (`main.dart:254-261`), so seed the schedule
  through prefs: key `room_of_days_academic_schedule_v1` =
  `jsonEncode(AcademicScheduleIcsImporter.parse(rutgersFall2026IcsFixture()).applyTo(AcademicSchedule.empty(), updatedAt: ...).toJson())`.
  Direct `AppShell` tests can pass `scheduleRepository: InMemoryAcademicScheduleRepository(...)`
  (shell.dart:162, :171).
- Freeze `Clock` per §1.4. Frames worth having before and after: Mon 10-05 at 19:15 (board, then
  ledger), Tue 10-06 at 15:35 (after last class), Thu 10-08 at 17:15 (in lab, 17:00 rail showing).

---

## 15. Status

- **Verified now:** every line reference above, read in W at c0a041a on 2026-10-03; the fixture
  grid; the absence of schedule reads below the shell; the absence of notification categories,
  actions and response handlers; the widget version gates and day-word gap; the capture gating of
  every golden on these surfaces; the dead code in routine_flows.dart; the iOS 64-slot arithmetic.
- **Inferred:** the CI host zone; the projection API shape; the music session flag and take hook;
  the plugin calls for actions and launch details; the evening room options; the widget v3 fields;
  the copy drafts.
- **Not done here:** no file under `W/lib` or `W/test` was edited, nothing was run except reads and
  greps, and no render was made. This is the only file written.
