# Class-day journey: engine, model and storage code map

Read-only code map and port plan, 2026-10-03. Base **W** =
`app/.worktrees/class-day-journey` on `claude/class-day-journey` at **c0a041a** (Build 49 source
9bf441c plus one docs commit). Every `file:line` without a prefix is relative to `W/lib/` and was
read in W for this document. **GER** = the Extra Credit work in `.worktrees/goals-everyday-review`,
read only through the snapshot at
`C:\Users\mikus\Documents\Claude\room-of-days-handoff\extra-credit-snapshot\`. GER line numbers come
from a reconstruction made outside the repo: `git archive fd58456` into the session scratchpad, then
`git apply extra-credit-tracked-files.diff` (applied cleanly) plus the untracked files.
332a90d was read only with `git -C W show 332a90d`.

Nothing under `W/lib` was edited. This file is the only file written. No user-facing copy is
proposed here; where a surface needs words, it says so and leaves them to the copy pass.

Mika's ask that this serves (2026-10-03, verbatim): "i feel like it's not in the best state it
could be right now, plus i barely use it as a student who just goes to class then relaxes
afterwards. maybe we need to consider that sort of case more and make it still useful for me?"

His Extra Credit idea (2026-09-03, verbatim, from the GER brief): "i attended all of my classes
successfully on a given day and didnt make a quest for going to class so maybe i wanna be able to
tell the app "i also went to all my classes" and it gives me a little extra xp that day"

## Contents

0. [Bottom line](#0-bottom-line)
1. [Extra Credit port plan](#1-extra-credit-port-plan)
2. [Save schema](#2-save-schema)
3. [Rewards: roll, commit, level-ups, receipt chain](#3-rewards)
4. [Streak and active days](#4-streak-and-active-days)
5. [Undo](#5-undo)
6. [A unified model for the day's own records](#6-a-unified-model-for-the-days-own-records)
7. [Version bump list for internal 1.0.5](#7-version-bump-list-for-internal-105)
8. [CI traps a build touching these files would hit](#8-ci-traps)
9. [Handoff corrections](#9-handoff-corrections)
10. [Verified, inferred, gates, departures](#10-verified-inferred-gates-departures)

---

## 0. Bottom line

- **The port is smaller than the GER diff looks.** Four of the ten files in
  `extra-credit-tracked-files.diff` (`storage.dart`, `widgets/routine_flows.dart`,
  `widgets/routine_ledger.dart`, `test/routine_ledger_visual_test.dart`), plus `cloud.dart`, are
  byte-identical between fd58456 and c0a041a, so their Extra Credit hunks land at the same offsets
  in W. `engine.dart` and `models.dart` differ only by Build 45's `completionsAtLastLevel` and
  `LevelResult` fields, far from the Extra Credit hunks. The real merge work is in `screens/quests.dart`
  (+1,211/-486 since fd58456), `screens/journal_entry.dart`, `screens/journal_hub.dart` and
  `screens/room_guide.dart`.
- **The Extra Credit hunks are tangled with GER's "expedition" restyle.** Several of them reference
  `expedition_scene.dart`, `expedition_surface.dart`, `ExpeditionAssets` and `Palette.action /
  onAction / actionGradient`, none of which exist in W. Those lines must be dropped or rewritten with
  W's own surfaces.
- **The snapshot's Extra Credit diff is missing two coupled files** that exist only in the
  full-tree diff: `lib/widgets/night_reflection_sheet.dart` (root navigator to local navigator) and
  `test/storage_cloud_merge_test.dart` (the schema-29 safety tests).
- **Extra Credit needs the GER night-route refactor.** GER replaced the night ledger's
  `OverlayEntry` with an owned `RawDialogRoute` plus a local `Navigator`, so the writing sheet can sit
  above the folio. The same refactor flushes any pending Quest commit on open, settles the older Quest
  undo on every ledger write, and resolves level-ups when the ledger closes.
- **The STUDENT-DAY "no level-up" caveat is only half true.** `addExtraCredit` itself never levels,
  but GER's ledger exit calls `_resolveLevelUps(s)` (GER quests.dart:1509), and a GER widget test
  checks the full-screen level-up after leaving the recap. Any other entry point (a board row, a
  widget replay) must call the level-up chain itself.
- **Schema 28 to 29 is safe and mechanical**, and it does not conflict with 332a90d (the UTF-8 guard
  touches only `cloud.dart` and builds its test saves through `Storage.save`). The one schema pin in
  tests is `test/storage_cloud_merge_test.dart:261`.
- **Class credit must not go through `commit()`.** `commit()` (engine.dart:1849-2034) is
  Quest-shaped: it bumps `totalCompletions`, `history`, `todayQuestTitles`, the streak, freezes, goal
  progress and mastery. An honest class award needs its own apply path that still feeds XP, one stat,
  the rank-up queue, achievements and the level-up overlay.
- **Streak:** the clean option to offer Mika is (a), class days hold the streak like a free freeze
  without counting as active days. (b), counting class days as active, ripples into multipliers,
  milestone Glimmers, achievements and the comeback bonus, which is the disguised completion P11
  warns about. (c) keeps today's behavior. Recommended default for the first slice: (c), with (a)
  ready behind Mika's answer to the streak question.
- **Size:** a unified day-record list costs about 115 bytes per kept class and about 255 bytes per
  day averaged over his full week. Capped at 180 days it tops out near 46 KB (about 5% of the
  921,600-byte backup guard); uncapped it would pull the guard crossing from about day 1,351 to about
  day 1,110 on HANDOFF §9's 3-year model.

---

## 1. Extra Credit port plan

### 1.1 What changed in W since the GER base

W is 46 commits past fd58456 (45 to 9bf441c, plus the c0a041a docs commit). For the files
Extra Credit touches:

| File | fd58456 → c0a041a | Port consequence |
|---|---|---|
| `lib/storage.dart` | unchanged | GER hunks apply at the same lines (:24, :241-249) |
| `lib/cloud.dart` | unchanged | No Extra Credit change here; skip GER's cloud flag (see 1.2) |
| `lib/widgets/routine_flows.dart` | unchanged | Extra Credit hunks apply at the same offsets |
| `lib/widgets/routine_ledger.dart` | unchanged | Same, but the geometry hunk is tangled with the expedition swap (1.2) |
| `test/routine_ledger_visual_test.dart` | unchanged | Same, minus the `ExpeditionAssets` precache lines |
| `lib/engine.dart` | +20/-1 (Build 45: `completionsAtLastLevel` :1221-1223, `applyLevelUps` :2058, :2078-2090, toJson :2355, fromJson :2690) | No overlap with GER hunks; offsets shift by about +4 to +20 |
| `lib/models.dart` | +11/-1 (Build 45: `LevelResult.previousLevel / questsSince`, :1590-1607) | No overlap |
| `lib/screens/quests.dart` | +1,211/-486 (Builds 43-49) | Hand merge; GER's night-route hunks map onto W's `_openNight` :1684-1716 |
| `lib/screens/journal_entry.dart` | +89/-1 (Build 48 Keepsake toggle, fdd4b19) | Hand merge, textual only |
| `lib/screens/journal_hub.dart` | +74/-55 (Build 48) | Hand merge; GER's `_archiveToolbar` is not Extra Credit |
| `lib/screens/room_guide.dart` | +169/-53 (Build 48 rewrote the guide) | Re-apply two copy edits by hand at W :149-153 and :131-135 |

### 1.2 Hunk classification (extra-credit-tracked-files.diff)

"EC" = Extra Credit proper. "Coupled" = needed for Extra Credit to work as tested. "Not EC" = other
GER work riding in the same file; do not port.

**lib/engine.dart**

| GER hunk | Class | What it does | W target |
|---|---|---|---|
| @@ -1,6 (import `StringCharacters`) | EC | Grapheme-length title check | top of file |
| @@ -1109 `todayJournalTrace` | EC | Reads `_dayXp/_dayStats/_dayQuestTitles` for today, adds `extraCreditTitles` | :1109-1116 |
| @@ -1119 night getters | Coupled | `nightXp/nightStatGains/nightQuestTitles` become day-keyed reads | :1122-1128 |
| @@ -1136, -1149, -1168 `_journalTrace` | EC | Threads `extraCreditTitles` into the trace | :1133-1178 |
| @@ -1177 `_dayXp`, `_dayStats`, `_dayQuestTitles` | Coupled | Day-keyed read helpers; `_dayXp` = Quest bucket + Extra Credit for that day; also stops a fresh before-4am state from leaking today's bucket into last night | insert after :1178 |
| @@ -1330 `extraCreditXp`, entries list, `extraCreditForDay`, `extraCreditTitlesForDay`, `extraCreditXpForDay`, `addExtraCredit`, `updateExtraCredit`, `_cleanExtraCreditTitle`, `_trimExtraCreditEntries` | EC | The feature's engine | after :1339 (today's haul) |
| @@ -2357 toJson `'extraCredit'` | EC | Persist | after :2377 `todayQuestTitles` |
| @@ -2723 fromJson decode | EC | Tolerant decode, newest-wins dedupe per day, 180 trim | after W's `todayQuestTitles` decode (:2742-2744) |

**lib/models.dart**: all four hunks EC (`StringCharacters` import; `JournalTrace.extraCreditTitles`
field, `hasDayEvidence`, toJson, fromJson at W :593-669; new `ExtraCreditEntry` class inserted after
`JournalTrace`, GER models.dart:686-746).

**lib/storage.dart**: both hunks EC (schema 28 → 29 at :24; `_hasRequiredStateFields` at
:241-249 requires `state['extraCredit'] is List` for schema ≥ 29 while keeping the schema-28
`roomKeepsakes` rule).

**lib/widgets/routine_flows.dart**

| GER hunk | Class | Note |
|---|---|---|
| imports: `extra_credit_sheet.dart`, `pressable.dart` | EC | |
| import `expedition_surface.dart` | Not EC | Drop |
| `_editingExtraCredit` field; `_keepExtraCredit()` (GER :56, :69-107) | EC | Uses W's existing `_reduceMotion` (:59), `widget.onPersist`, `saveNightJournal` |
| `extraPageHeight: 96` on `RoutineLedgerPage` (GER :197) | EC | Needs the routine_ledger.dart geometry hunk |
| `_FinishedThreadsLedger(... extraCredit, onExtraCredit, reduceMotion)` (GER :357) | EC | W call site :312-318 |
| `_showRisers` `useRootNavigator: false` | Coupled | Required once the ledger owns a local Navigator |
| RISE button `ExpeditionSurface` / `Palette.action*` (two hunks) | Not EC | Drop |
| `_FinishedThreadsLedger` restructure + new `_LedgerExtraCreditLine` (GER :2395-2600) | EC | W class at :2340; the empty-day line "Nothing had to be proven today." (:2374) moves inside the switcher |
| `_CapacityLedgerLabel` colors | Not EC | Drop |

**lib/widgets/routine_ledger.dart**: the `_RoutineLedgerPageGeometry` /
`_routineLedgerPageGeometry` helper, `extraPageHeight` on `RoutineLedgerPage` (W :583-596), and the
stage-height math that reserves 96 px are EC (the night receipt grows with Extra Credit at large
text). The `ExpeditionScene` swap and removal of `_RoutineRoomPlate` in the same hunks are Not EC:
keep W's `_RoutineRoomPlate` and `ColoredBox`, port only the geometry.

**lib/screens/quests.dart** (EC and Coupled hunks only; everything else in this file's GER diff is
Goals or expedition work, including the import changes, `_selectedQuestTitle`, the `_exploreStat`
variant, dialog `ExpeditionSurface`s, `_QuestArrival` removal, `_DailyFieldRail`, `_MomentumSheet`
and `_EditQuestDialog` restyles)

| GER hunk | Class | W target |
|---|---|---|
| `_nightOverlay` → `Route<void>? _nightRoute` | Coupled | :259-262 |
| `didUpdateWidget`: `_removeNightRoute()` on state swap | Coupled | :669-671 |
| `dispose`: `_removeNightRoute()` | Coupled | :772-774 |
| `_journalTraceFor`: `extraCreditTitles: base.extraCreditTitles` | EC | :832-842 |
| `_openNight` rewritten as `RawDialogRoute` + local `Navigator`; `_flushCommit()` on open; `onPersist` clears `_undoTitle/_undoSnapshot` first (GER :1480-1487); `.then` records perfect day, `_resolveLevelUps(s)`, `onNightClosed`; new `_removeNightRoute()` | Coupled (the undo settle and level-up resolve are EC behavior) | :1684-1716 |
| `_resolveLevelUps`: `if (_nightRoute != null) return;` | Coupled | :1845-1847 |

**lib/screens/journal_entry.dart**: one EC hunk, the "EXTRA CREDIT · ..." label under the page's
trace lines (GER @@ -1176). W anchor: the trace block around :1185-1190. All other hunks in this
file are GER Journal restyle; drop.

**lib/screens/journal_hub.dart**: EC parts are `_extraCreditLine()` (insert after `_traceLine`,
W :79), the `hasExtraCredit / hasActivity` logic and line in `_todayThread()` (W :833-871), and
the line on saved entry cards (W ~:1050). GER's `_archiveToolbar` replaces W's `_composer` (:736)
and is Not EC; if the composer should show Extra Credit, add the line to W's `_composer` instead.

**lib/screens/room_guide.dart**: EC is two copy edits only (the Quests door mentions Extra Credit,
the Journal door says Quests and Extra Credit attach). W's guide was rewritten in Build 48: Quests
door detail at :151-152, Journal door detail at :133-134. Everything else in the GER hunk
(`ExpeditionScene`, `ExpeditionSurface`, Goals door copy) is Not EC. The copy pass owns the final
words; GER's sentences are a draft.

**test/routine_ledger_visual_test.dart**: the added "reflect · optional reachable after the
receipt" assertions are EC (they guard the 96 px growth). The `ExpeditionAssets` precache swap is
Not EC; keep W's `room-night-v1` / `room-morning-v1` precache.

**Untracked files** (snapshot `untracked/`): `lib/widgets/extra_credit_sheet.dart` (259 lines;
imports only `engine`, `models`, `tokens`, `glass`, `honey_button`, all present in W, so it compiles
once the engine API exists); the three tests (1.5); `tool/verify_extra_credit.py` (uses only
`execution_gate.load_json / current_revision / brief_digest`, all present in W's
`tool/execution_gate.py`); the brief and the execution record (`brief.json`, `evidence.json`; the
evidence is bound to GER revisions and must be regenerated, not copied as proof).

**Not in the Extra Credit diff but coupled to it** (only in `goals-everyday-review-all-tracked.diff`):

- `lib/widgets/night_reflection_sheet.dart` (full diff :22689+): `useRootNavigator: true → false`
  so the reflection opens inside the ledger's own Navigator. Port that one line and its comment;
  drop the `ExpeditionScene` wrapper. W currently says the opposite at
  `widgets/night_reflection_sheet.dart:23-29`.
- `test/storage_cloud_merge_test.dart` (full diff :29361+): adds `omitExtraCredit`, rewrites three
  schema tests to 29, adds "schema-28 keepsake protection remains after schema-29 migration", and
  changes `expect(Storage.schema, 28)` to 29.
- `lib/cloud.dart` (+21/-1, compile-time `emberkeep_cloud_enabled` flag): Not EC. Skip it.

### 1.3 Conflicts with Build 48 Keepsakes and other later work

- **No schema conflict with Keepsakes.** Build 48's Journal Keepsakes reuse the existing
  `memoryPins` set (`engine.dart:761` `setMemoryPinned`); no new persisted field. The "keepsakes"
  in GER's schema comment means `roomKeepsakes`, the schema-28 field already in W (engine.dart:846,
  toJson :2267, fromJson :2427, storage.dart:246-248). GER keeps that rule and adds its own.
- **Textual conflicts only:** `journal_entry.dart` (fdd4b19 added the Keepsake toggle,
  `keepsakePinned` / `onToggleKeepsake`) and `journal_hub.dart` (`_toggleKeepsake` at :259, its
  callers :224-227, :992-996). Merge the Extra Credit lines beside them.
- **Build 45 `completionsAtLastLevel`** sits in `applyLevelUps`; GER's level-up resolution on ledger
  exit will now report `questsSince` too. Extra Credit does not touch `totalCompletions`, so a
  level-up caused only by Extra Credit reports 0 and the overlay hides the line
  (`widgets/levelup_overlay.dart:340-341`).
- **Build 45-47 Close Day placement:** CLOSE DAY moved to the board footer and an evening rail
  (`close-day-rail` key at quests.dart:5055; footer label `'CLOSE DAY'` with semantic label
  `'Close the day'` at :5001-5002). The GER widget test's `_openLedger` helper looks for the rail key,
  then `find.byTooltip('Close the day')`, then the text `'CLOSE THE DAY'`. In W the second fallback is a
  semantics label, not a tooltip, so if the rail is absent the helper falls to the text finder; check
  that path at 15:30 ("afternoon access" test).
- **Builds 43-49 quest-board work** (featured Quest, Today's three rings, `_selectedQuest`,
  `_settleUndoBeforeLaterEdit` :707-714, `_exploreStat` :716-739) does not overlap the night-route
  code, but `_openNight` is reached from three W call sites (:3230, :3526, :3702), all of which keep
  working if the method signature stays the same.

### 1.4 Port order (smallest safe steps)

1. Models and engine (models.dart, engine.dart hunks), then storage.dart schema 29.
2. Port `test/extra_credit_test.dart` and `test/extra_credit_journal_test.dart` unchanged; port the
   storage_cloud_merge_test.dart schema changes. Run only those files.
3. routine_ledger.dart geometry, routine_flows.dart ledger line, extra_credit_sheet.dart.
4. quests.dart night route + `night_reflection_sheet.dart` root-navigator flip.
5. journal_entry / journal_hub / room_guide lines.
6. `test/extra_credit_widget_test.dart`, `test/routine_ledger_visual_test.dart` additions; then
   re-run the night tests already in W (`night_routine_feedback_test.dart`, `day_rest_test.dart`,
   `widget_test.dart` "night routine opens, recaps and closes", `audit_regressions_test.dart`).

### 1.5 The GER tests and what they assert

`test/extra_credit_test.dart` (11 tests, pure engine, frozen `Clock`):

| Test | Asserts |
|---|---|
| awards fixed XP once without inventing Quest progress | +10 to `xp` and `totalXp`; trimmed title; a second add the same day returns null; every other `toJson` key is unchanged (no stats, Glimmers, streak, history, completions) |
| allows wording edits without a second award | `updateExtraCredit` changes the title only; after 04:00 the old day's edit is refused |
| rejects blank, overlong, stale, and arbitrary past-day claims | blank, > 180 graphemes, a past `dayKey`, and a stale editor after 04:00 all return null |
| counts visible emoji graphemes like the text field | 180 multi-codepoint emoji pass, 181 fail |
| serializes, deduplicates malformed records, and preserves its trace | round-trip; malformed list keeps one entry per day (newest wording), drops bad keys, overlong titles, `xp != 10`, out-of-range timestamps; a non-list decodes empty; no re-award on decode |
| ordinary and legacy save decode do not read the live clock | decode with a throwing `Clock` succeeds |
| bounds restored history while retaining the active day on a backward clock | 181 entries trim to 180 and keep the active night |
| attributes a 1am credit to the prior night before rollover | `nightXp` 37 + 10, night trace lists it, today's trace does not, `todayStats` untouched |
| a fresh before-4am state never leaks current-day buckets backward | with no `lastActiveDay`, night XP is only the credit |
| attributes a post-rollover 1am credit and cold restore correctly | after rollover at 1am, the credit joins the snapshot day and survives a cold decode |
| a new night can claim after rollover while yesterday remains frozen | one per night-owned day; yesterday's entry kept |

`test/extra_credit_journal_test.dart` (3): an old trace shape keeps `extraCreditTitles` without
`questTitles` and still `hasDayEvidence`; a saved page shows the "EXTRA CREDIT · ..." label and no
Quest count or "QUEST THREAD"; the live Journal hub shows the label on a day with no Quests.

`test/extra_credit_widget_test.dart` (13, mounts the real `QuestsPage` at 21:30 on 2026-09-03):
claim, edit and restore once (XP 42 → 52, `nightCompletionCount` stays 2, no Journal page created,
saved JSON restores and refuses a second award); an empty day stays optional and cancel or blank
input changes nothing and never persists; an existing night reflection receives the credit in its
trace without a second Journal page; afternoon access (15:30) works without closing the day; a stale
editor keeps the words and refuses to credit the new day; **the level threshold resolves on leaving
the recap** (level 1 while the ledger is open, level 2 plus `LevelUpOverlay` after "NOT YET", with
`totalCompletions`, `history`, `streakDays` and `nightDoneDay` untouched); back closes the writing
first, then the ledger; a save replacement closes the whole private stack; the reflection stays
reachable above the board-owned ledger; **an earlier full-save Quest undo cannot erase new Extra
Credit** (undo affordance gone, `totalXp` kept); rapid double taps keep one ledger, one editor, one
award; at 320x568 with 1.5x and 2.0x text the keyboard leaves the save button reachable.

`test/routine_ledger_visual_test.dart` additions: after the receipt grows, "reflect · optional" is
still hit-testable and opens the real reflection field.

`test/storage_cloud_merge_test.dart` changes (full diff only): a newer schema-28 remote is held
against schema-29 local; schema 28 and 29 saves without `roomKeepsakes` are both invalid while a
schema-27 save without either field is valid; schema 29 requires `extraCredit` while schema 28
migrates it; import rejects a truncated schema-29 state and accepts schema 28; load quarantines a
truncated schema-29 state; `Storage.schema == 29`.

---

## 2. Save schema

### 2.1 Where it stands in W

- `storage.dart:19` blob key `liferpg_save_v1`; `:24` `static const schema = 28; // retains the
  bounded legacy room field`.
- Every save writes the current schema (`Storage.save`, :36-57, `'schema': schema` at :46), so the
  first save after an update migrates the local blob automatically.
- The academic schedule is **not** in this blob and **not** cloud-backed: it has its own prefs key
  (`academic_calendar/data/academic_schedule_repository.dart:15-20`,
  `room_of_days_academic_schedule_v1`) and `CloudSync` only mirrors `liferpg_save_v1`. A restored or
  second device can have class records with no schedule behind them (6.2).

### 2.2 Validation path

1. `_hasRequiredStateFields` (:241-249): `state` must be a map with a `stats` list; schema ≥ 28
   must carry `roomKeepsakes` as a list ("distinguishes an explicit legacy field from a truncated
   state map").
2. `load()` (:62-97): required fields → `GameState.fromJson` → `Quest.fromJson` for each; any throw
   quarantines the raw blob to `liferpg_save_corrupt` (first quarantine kept, :88-90) and starts
   fresh. **A throwing decoder anywhere in `GameState.fromJson` therefore costs the user a fresh
   start**, so every new decoder must be total (return null or empty, never throw).
3. `isValidSave()` (:121-140): marker `emberkeep`, schema int ≥ 0, required fields, full decode.
   It does not reject a future schema; merge and import do.
4. `decideCloudMerge()` (:149-174): hold if local is invalid or newer than this build; push if no
   remote; hold if remote is invalid or newer than this build; on a newer remote adopt only when
   `remoteSchema >= localSchema`, else hold; otherwise push only when `localSchema >= remoteSchema`.
5. `decideInitialCloudMerge()` (:180-192): a fresh-bootstrap local may adopt an older-schema remote;
   the shell then re-saves at the current schema and checks it before pushing
   (`screens/shell.dart:949-966`).
6. `importRaw()` (:265-309): rejects a future schema (:282), then the same gates.
7. Cloud push: `cloud.dart:1016-1048` `_pushNowQueued` reads `Storage.exportRaw()`, refuses an
   invalid save (:1023), applies the size guard (:1031), writes `{data, updatedAt}`. Sign-out flush
   at :775-776 also gates on `isValidSave`. A held merge shows `'paused · cloud copy kept safe'`
   (:398-405).

### 2.3 Adding a reward-bearing field with a bump (checklist)

1. **Model** (`models.dart`): value class with `toJson` and a static, total `fromJson(Object?)` that
   returns null on any bad record (GER `ExtraCreditEntry.fromJson` is the pattern).
2. **Engine** (`engine.dart`): field on `GameState`; one new top-level key in `toJson` (:2246-2397;
   choose the name once, AGENTS.md locks serialized names); decode in `fromJson` (:2399-2801)
   tolerant of a missing key (legacy), a wrong type (treat as empty), duplicates (dedupe without
   re-awarding), and oversize (trim). Decode must not depend on `Clock.now()` except to protect the
   active day while trimming (GER test "decode does not read the live clock").
3. **Storage**: bump `schema` (:24) with a comment; extend `_hasRequiredStateFields` (:241-249) so
   `schema >= 29` requires the new key to be a list. Keep the schema-28 `roomKeepsakes` rule.
4. **Cloud merge**: no code change. `decideCloudMerge` is schema-generic; once a device writes 29, an
   older build holds (never adopts, never overwrites), and a newer schema-28 remote is held against a
   schema-29 local until both devices update.
5. **cloud.dart backup**: no code change. The new key rides in the blob; it counts toward the size
   guard (2.5, 6.4).
6. **Undo snapshot** (`shell.dart:1436-1439`): automatic, since it serializes `state.toJson()`. Decide
   the restore rule (section 5).
7. **Tests**: update `test/storage_cloud_merge_test.dart:261` (`expect(Storage.schema, 28)`), add the
   four schema-29 tests from GER. Other tests that seed saves (`day_rest_test.dart:73`,
   `screenshots_test.dart:916, :1295, :1707`, `widget_test.dart:1139`,
   `working_experience_visual_test.dart:137`) use `Storage.schema` with `state.toJson()`, so they pick
   up the new key automatically. No checked-in JSON save fixtures exist.

**Why a bump here, when Build 45 added `completionsAtLastLevel` without one**
(engine.dart:1221-1223, :2355, :2690): that field is nullable and cosmetic. A credit record is
paired with XP already added. If an older build overwrote the blob and dropped the record, the XP
would stay while the day's "already kept" proof vanished, so the new build would let the same day be
claimed again. The bump makes the older build hold instead.

### 2.4 How old saves migrate

Legacy saves (schema < 29) decode the missing key as empty and are written back at 29 on the next
save. No transform. A schema-28 cloud copy adopted by a fresh install is re-saved at 29 and verified
before the first push (`shell.dart:949-966`). No schema-29 save exists in the wild (inferred: GER was
never uploaded, and its cloud flag was for local previews).

### 2.5 The UTF-8 guard fix (332a90d) and a schema change

332a90d is a direct child of c0a041a (merge-base is c0a041a), so it cherry-picks onto W cleanly. It
changes only `lib/cloud.dart` (+`import 'dart:convert'`, new top-level
`cloudSaveByteLimit = 900 * 1024` and `cloudSaveBytes(raw) => utf8.encode(raw).length` before the
`CloudSync` class, and the guard at :1031 now compares bytes) and adds
`test/cloud_save_size_guard_test.dart`, which builds Hebrew saves through `Storage.save` and never
names a schema number. **No textual or semantic conflict with a schema bump.** The only interaction
is size: new records add bytes that the guard now measures correctly. Course codes and class labels
are ASCII; Extra Credit wording can be any language and is capped at 180 graphemes per day. Order
does not matter; cherry-pick 332a90d once Mika says yes. Do not port GER's `cloud.dart` flag in the
same pass; it is unrelated and touches nearby lines.

---

## 3. Rewards

### 3.1 roll() (engine.dart:1686-1822)

Pure with respect to XP and stats; it does mark the Quest done (`q.lastDoneDay = nowKey`, :1709) and
records mastery progress (:1775). Order: streak situation (:1697-1703; comeback = gap the freezes
cannot fully cover); same-title count, neglect and day-one damp (:1705-1707); base
`10 × (0.5 + d × 0.25)` × streak multiplier (post-reset ×1.07 on a comeback, :1714-1717), dread ×1.35,
custom ×0.85, verified ×1.2, comeback ×1.5, neglect, day-one, same-day decay, MIND ×1-1.15, daily
soft cap from `todayXp` (:1718-1726); BODY crit from `_rng` (:1729-1733); CRAFT loot (:1737-1749);
stat gain `max(1, round(d × 1.5 × damps × decay × softcap)) + 3 if dreaded` (:1753-1757, :1783);
freeze projection for the commit (:1758-1772); Glimmers `max(1, xp ~/ 3)` (:1781). Returns a
`RewardBundle` (models.dart:1435-1568).

### 3.2 commit() (engine.dart:1849-2034)

XP, `totalXp`, Glimmers (:1850-1854); stat plus rank-tier crossing into `_rankedUpQ` (:1856-1861);
Me ledger entry, capped at 8 (:1862-1866); the streak block, once per day (:1873-1906, section 4);
dawn/dusk counters; loot kept; `totalCompletions`, verified, dread, epic, event, custom counters;
`history[today]++`; same-title count (:1920-1928); today's haul `todayXp`, `todayStats`,
`todayQuestTitles` (:1931-1933); goal and route progress (:1936-2018); history trim to 180
(:2023-2031); `notifyListeners()`.

### 3.3 Level-ups

`xpNeeded(L) = 60 + (L-1) × 45` (:1530). `applyLevelUps()` (:2056-2091) loops while
`xp >= xpNeeded(level + 1)`, applies furniture flags, the level-6 freeze bonus (+2, :2070-2073) and
the level-15 gilded skin, and returns `LevelResult(leveledTo, unlock, previousLevel, questsSince)`
with `questsSince = totalCompletions - completionsAtLastLevel`. It deliberately does not notify.

**Callers in W:** only `QuestsPage._resolveLevelUps` (screens/quests.dart:1845-1897), which is called
only from `_afterEpic` (:1360, :1366). So in W a level threshold crossed by anything other than a
Quest waits for the next Quest. GER adds the night-ledger exit as a second caller.

### 3.4 The receipt and celebration chain (screens/quests.dart)

| Step | Where |
|---|---|
| Flush any pending commit, take the whole-save undo snapshot, `roll()` | `_runCompletion` :1066-1082 |
| Done state, combo, re-anchor offer, day-cleared wash, completion voice and haptics, combo flourish, particle burst (combo, crit, loot or dread only), XP stitch | :1083-1166 |
| Receipt at 240 ms (`RewardReceipt`, onDone → `_afterReceipt`) | :1171-1196 |
| Staged commit at 520 ms → `_flushCommit` (commit, perfect day, achievements queued, persist, offer undo) | :1202-1206, :743-768 |
| Epic overlay if difficulty ≥ 7 | `_afterReceipt` :1307-1326 |
| Goal milestone toast; goal achieved overlay | `_afterEpic` :1330-1368 |
| `applyLevelUps` → `LevelUpOverlay` | `_resolveLevelUps` :1845-1897 |
| Streak milestone chest (7/30/100) | `_resolveStreakMilestone` :1902-1928 |
| Rank-up "WHY THIS WORKS" beat from `_rankedUpQ` | `_afterRankThenToasts` :1933-1961 |
| Achievement toasts | `_releaseAchievementToasts` :1293-1304 |

`RewardReceipt` (widgets/reward_receipt.dart) is Quest-shaped: header text "QUEST COMPLETE" (:489),
"SWIPE TO UNDO" / "QUEST SETTLED" (:512), semantics "Quest complete." (:392), the optional line
attaches to `bundle.questTitle` (:346), the WHY card reads `bundle.stat` (:256). Its level chip
projects `state.xp + b.xp` (:90-97) because the receipt appears **before** the 520 ms commit.

### 3.5 What an honest class award needs

The goal: the real completion feel (receipt, stat chip, level-up overlay) without pretending to be a
Quest. Engine side:

- **A separate apply path, never `commit()`.** Sketch:
  `ClassCredit? keepClass({required String dayKey, required ClassFacts facts})` that adds XP and one
  stat gain, enqueues a rank-up if the stat crosses a tier (same `_rankedUpQ`), inserts a Me ledger
  entry with the class label, writes the day record (section 6), and notifies. It must **not** touch
  `totalCompletions`, `history`, `todayXp`, `todayStats`, `todayQuestTitles`, `todayTitleCounts`,
  `lastCompletionDay`, streak, freezes, goals, mastery, loot or perfect days.
- **Keep class XP out of `todayXp`.** `_dailyXpMult()` (:1660-1664) reads `todayXp`; mixing class XP
  in would push the evening's Quests into the soft cap. Fold class XP into night totals through the
  read helpers instead (GER's `_dayXp` pattern: Quest bucket + records for that day).
- **Deterministic amounts.** No crit, loot, streak or comeback multiplier, so tests can assert exact
  numbers without injecting a `Random`. Stat by meeting kind is a natural default (lecture,
  recitation, seminar → MIND `intl`; lab, studio → CRAFT `foc`; `MeetingKind` at
  `academic_calendar/domain/academic_schedule.dart:13-23`) [default]. Size of the award and whether
  it pays Glimmers are Mika's call (HANDOFF §13 Q5); GER pays no Glimmers.
- **Engine stays schedule-blind.** `GameState` should receive plain facts (occurrence key, course
  code, label, start minute, kind, the occurrence's civil date) from the UI. The shell already holds
  the loaded schedule (`screens/shell.dart:202`, loaded at :306); `QuestsPage` does not receive it
  today, so a board slot needs it passed down. `CivilDate.toString()`
  (`daybook/domain/civil_date.dart:66-69`) has the same `YYYY-MM-DD` shape as `Days.key`.
- **Receipt.** Either give `RewardReceipt` a kind (header, semantics, undo label, no Quest-only
  chips) or a small sibling widget that reuses `_Bubble`. Apply XP after the receipt computes its
  level chip, or pass the pre-apply XP, to avoid double counting in the projection.
- **Level-up.** After the receipt, enter the chain at `_resolveLevelUps(s)`; it then runs streak
  milestone (nothing queued), rank-up beat, achievements. `questsSince` keeps counting Quests only and
  hides itself at 0. If Mika wants classes named on the level-up, add a `classesSince` counter beside
  `completionsAtLastLevel` [optional].
- **Achievements.** Call `checkAchievements()` after applying; level and stat thresholds can then
  unlock honestly (content/achievements.dart :122, :130, :153, :198-215).
- **Sound lanes.** Any new `Pressable` that declares both `material:` and `interactionSound:` must
  use a shipped lane (test/interaction_sound_quality_test.dart:923-975: slate select/navigate/place,
  page navigate/open, glass select/place, brass select/place). GER's ledger line declares only
  `material: MaterialSound.parchment` and is exempt.

### 3.6 addExtraCredit's caveats (STUDENT-DAY §5) and two more

1. **No level-up check in the engine method** (GER engine.dart:1409-1427: `xp += entry.xp;
   totalXp += entry.xp; notifyListeners();`). True. But GER's UI resolves it when the ledger closes
   (GER quests.dart:1509) and blocks `_resolveLevelUps` while the ledger is open (GER :1660). Any new
   entry point must do the same.
2. **nightKey-only `dayKey`** (GER engine.dart:1411 and `updateExtraCredit` :1432 refuse anything
   but `Days.nightKey(Clock.now())`, models.dart:64-69 sets the 04:00 boundary). A widget or
   notification action replayed at the next app open must carry the day it happened, and the engine
   needs a bounded "recent day" path, or the credit is dropped after the night rolls over.
3. **New: the decoder rejects any `xp != awardXp`** (GER `ExtraCreditEntry.fromJson`, the
   `xp != awardXp` check). If the +10 ever changes, every stored record silently disappears on the next
   load (the XP stays). Validate a sane range instead, and keep the amount actually awarded.
4. **New: trimming is by entry count (180).** With one entry per day this equals 180 days; with one
   record per class it would not. Trim by day key.

---

## 4. Streak and active days

### 4.1 Mechanics in W

- Fields: `streakDays`, `bestStreak`, `lastCompletionDay` (:1184-1186); freezes start at 3, capacity
  5, 7 from level 6 (:1192-1205); cadence 2 active days at CARE ≥ 40, else 3 (:1209);
  `frozenStreakDays` (:1200); preview `pendingStreakGap` (:1213-1216).
- `_streakSituation()` (:1575-1591): no gap if there is no `lastCompletionDay` or it is today;
  otherwise list every day strictly between the last completion and today; `covered` only when
  `streakFreezes >= days.length` (partial cover refused).
- `roll()` reads it for messaging and pay (:1697-1703, :1714, :1721); `xpPreview` mirrors it
  (:1827-1845).
- `commit()` streak block (:1873-1906), once per calendar day: no gap → `streakDays += 1`; covered gap
  → spend freezes, record the held dates, `streakDays += 1`; uncovered gap → `comebacks++`,
  **`streakDays = 1` (:1883)**; then `lastCompletionDay = today`, freeze balance and progress from the
  bundle, and the 7/30/100 milestone chest (+50/200/800 Glimmers) inside the same block.
- No other code mutates `streakDays` (grep of lib); decode at :2667.

**What counts as an active day:** a Quest commit, nothing else. `lastCompletionDay` is written only
at :1885. `history` (written only at :1926) is the "lit day" signal for the weekly chronicle
(content/weekly_chronicle.dart:61-67), Plans dots (screens/calendar.dart:956, :1107), the hearth
circle (screens/hearth_circle.dart:614), Insights (:963, :1088), the constellation
(widgets/constellation.dart:141-164), the resting panel (quests.dart:2681), the social `todayLit`
flag (social.dart:343), the night ledger (routine_flows.dart:3505) and `recordPerfectDay` (:2237-2243).
Achievements read `streakDays` (≥ 7, ≥ 30: content/achievements.dart:89, :239), `comebacks` (:161)
and `perfectDays` (:168, :175).

### 4.2 The three options

| | (a) Class credit holds the day like a freeze | (b) Class credit counts as an active day | (c) Neither (today) |
|---|---|---|---|
| Change | In `_streakSituation`, drop gap days that have a kept class before testing `covered`; spend freezes only for the rest | Factor the streak block into a shared `_advanceStreakDay(today)` callable from class credit; split `lastCompletionDay` (Quest) from a new `lastStreakDay` | None |
| `streakDays` | Grows on Quest days only; class days bridge | Grows on class days too | Grows on Quest days; class-only days are a gap |
| Reset to 1 | Only if the non-class gap days exceed the reserve | Rarely on a school week | Whenever a class week has no Quests and the gap beats the reserve |
| Freezes | Saved for weekends and true rest; no freeze earned on class days | Earned on class days (`firstOfDay` staging in `roll()` :1701, :1762-1772 breaks unless split) | As now |
| Multiplier (×1.0-×2.0) | Kept through a school week, climbs only with Quest days | Can reach ×2.0 from classes alone, inflating Quest XP | Drops to ×1.07 after an uncovered gap |
| Milestone Glimmers 7/30/100 | Quest days only | Paid for class days | Quest days only |
| Comeback ×1.5 | Unchanged | Consumed by a class day with nothing to multiply; the next Quest gets no WELCOME BACK | Unchanged |
| Achievements (streak 7/30) | Reached through Quest days | Reachable through classes | Unchanged |
| Receipt | A held-by-classes fact on the next Quest's bundle (new field beside `freezesUsed`); copy TBD | New streak chips on a class receipt | Unchanged |
| Also touches | `roll()` `freezesUsed` (:1702), `xpPreview` (:1833-1834), `pendingStreakGap`, the freeze sheet (widgets/streak_freeze_status.dart:72-87), commit :1877-1880 | Everything in column (a) plus `history` must stay Quest-only, or chronicle, calendar, constellation and social all count classes | Nothing |
| P11 risk | Low to medium: continuity, not completion; still needs Mika's yes | High: the disguised completion P11 warns about | None |

Notes for (a): the hold is decided lazily at the next Quest commit, so late-arriving credit (widget
replay) still counts if it lands before that commit. Only schedule-backed class records should hold a
day; free-text Extra Credit should never hold one, or typing anything becomes a universal streak
saver [inferred]. Keep held class days out of `frozenStreakDays` (that list reads as "freeze used" in
the details sheet) or mark them separately.

### 4.3 Never-punish implications

Nothing in any option removes XP, stats, level or rooms; `bestStreak` is kept. The real cost of (c)
is a rate drop: an uncovered gap takes the multiplier from up to ×2.0 back to ×1.07, softened by
the ×1.5 comeback on the return Quest. AGENTS.md promises streaks that read "paused"; the engine
resets. The public lines HANDOFF §12 lists ("A missed day never costs you progress...",
index.html:162; `projects/room-of-days.html:143-144`; the résumé's "no penalty for missed days") stay
overstated under (c), become truer for class days under (a) and (b), and stay overstated for
weekends and rest days in every option until rest days (ROADMAP.md:81) exist.

---

## 5. Undo

### 5.1 How it works in W

- Snapshot: before each Quest roll, `_runCompletion` calls `widget.onSnapshot()` (:1077), which is
  `shell._captureSnapshot` (screens/shell.dart:1436-1439): `jsonEncode` of the whole `state.toJson()`
  and every Quest.
- Arm: after the staged commit, `_flushCommit` → `_offerUndo(title, snapshot)` (:760, :1213-1219);
  the just-completed card swipes left past 42% to undo (:3796-3797).
- Restore: `_undoLast` (:523-536) → `shell._restoreSnapshot` (:1443-1495) rebuilds state and Quests
  from the snapshot, then merges back Quests added after it (by title, :1455-1460) and Journal notes
  added after it (by id, plus the night draft and pending morning pointers, :1462-1483). Everything
  else reverts.
- Settled (undo cleared) by: a new completion (replaces the slot), a quick reflection
  (`_keepQuestReflection` :1053-1059), Domain detail edits (`_settleUndoBeforeLaterEdit` :707-714,
  used at :727-734).

### 5.2 The GER guard

In GER the night ledger's `onPersist` clears `_undoTitle` and `_undoSnapshot` before persisting
(GER quests.dart:1480-1487, comment: "A completion's full-save undo predates any writing, plans, or
extra credit kept here. It must not erase this new work."), and `_openNight` flushes any pending
commit first. Test: "earlier full-save Quest undo cannot erase new extra credit".

**Latent W issue the guard also fixes:** W passes `onPersist: widget.onPersist` straight through
(:1696). After a Quest completion, choosing tomorrow's three on existing Quests or closing the night
leaves the Quest undo armed; an undo would revert those choices and `nightDoneDay` / `morningArmed`
(only notes and new Quests are merged back). Also, W's `_openNight` does not flush a commit staged in
the last 520 ms, so the ledger can open with that Quest's XP not yet in `nightXp`.

### 5.3 Rules for class credit

1. **Before any class credit write:** `_flushCommit()` (land a pending Quest reward), then settle an
   armed Quest undo (same as `_settleUndoBeforeLaterEdit`). Applies to every surface: board row, night
   ledger, a replayed widget or notification action.
2. **Its own undo, if offered, uses the same whole-save slot:** snapshot before the keep, arm undo on
   the class row. A later Quest completion replaces the slot; a later class keep settles the Quest
   slot. One slot, one most-recent reward, so a restore never crosses a later reward.
3. **Never merge reward-bearing records in `_restoreSnapshot`.** Merging a class record back without
   its XP (or with it) breaks the pairing; rule 1 makes a merge unnecessary. Keep merging Journal
   notes and new Quests as now.
4. **Wording edits** (Extra Credit) never award and need no undo; they still settle any armed slot
   because they persist.
5. **Level-up while an undo is armed:** W keeps the swipe undo armed across a Quest level-up (only
   snackbars are cleared, :1856), and an undo reverts the level too. Class credit should behave the
   same, or both should settle on level-up; decide once for both [open].

---

## 6. A unified model for the day's own records

### 6.1 Shape

One list, keyed by the night-owned day, separate from Quests, streak and goals:

```dart
/// What a lived day held apart from Quests. Never a Quest.
class DayRecord {
  final String dayKey;                 // Days.key format; the night-owned day
  final List<KeptClass> classes;       // one per class occurrence, sorted by start
  final ExtraCreditEntry? extraCredit; // GER's one free-text line per day (dayKey dropped)
}

class KeptClass {
  final String? occurrenceKey;  // link to AcademicSchedule when present
  final String courseCode;      // "14:332:345", self-describing on a device without the schedule
  final int startMinute;        // local start; with courseCode, the identity if the key is absent
  final int xp;                 // amount actually awarded
  final DateTime keptAt;        // UTC
  // optional: a short label snapshot (<= 48 chars) if titles must show without the schedule
}
```

JSON key, one name forever: `dayRecords` (list). Schema 29 requires it as a list. Keep GER's public
API (`addExtraCredit`, `updateExtraCredit`, `extraCreditForDay`, `extraCreditEntries`,
`extraCreditXpForDay`, `extraCreditTitlesForDay`) as thin readers over `dayRecords`, so the GER
engine tests port with only the three raw-JSON decode tests rewritten. Fallback if the port should
stay closer to GER: keep GER's `extraCredit` key exactly and add a sibling `keptClasses` key in the
same schema bump.

### 6.2 Invariants

- At most one `KeptClass` per occurrence (`occurrenceKey`, else `courseCode` + `startMinute`) and one
  `extraCredit` per day. Decode dedupes without re-awarding (newest wins), drops bad records, never
  throws.
- Occurrence keys are stable across re-imports of the same .ics (series ids come from the UID,
  `academic_calendar/import/academic_schedule_ics_import.dart:149, :165-166`; occurrences keep their
  key by original date, `academic_schedule.dart:909`), so the link survives a re-import. The schedule
  is device-local and not backed up (2.1), so records must read correctly without it.
- Cancelled occurrences cannot be kept (`OccurrenceState.cancelled`, `academic_schedule.dart:25`).
  An unkept class is simply absent: no negative state exists in the model.
- The day comes from the occurrence's civil date, compared with `Days.nightKey(now)` for the
  "current night" check; time comparisons use instants (`doorwayOccurrences` :1486-1499 compares
  `now.toUtc()` with `startInstant / endInstant`), never local wall-clock on a test host.
- XP from records never enters `todayXp`; night and Journal totals add it through day-keyed reads.
- Trim by day: keep the last 180 day records plus the active night (same horizon as `history`,
  :2023-2031). If a semester total is wanted after trimming, keep a tiny per-course counter map
  (about 25 bytes per course) instead of the full list [optional].
- An evening note stays in the Journal as a `Note` linked by `trace.day`. Do not copy evening text
  into the record: night journal text is already stored twice (models.dart:867 and :873, HANDOFF §9).
  If Mika wants rest to accumulate without XP (STUDENT-DAY Opportunity 2), add an optional
  `restLine` (≤ 120 chars) to `DayRecord` later [optional].
- Journal trace: add a compact `classesKept` list (course codes, or short labels) beside GER's
  `extraCreditTitles` in `JournalTrace` (models.dart:593-669); both optional in toJson, so no schema
  need.

### 6.3 Size estimate against the save budget (HANDOFF §9)

Measured with compact JSON (`json.dumps(separators=(',', ':'))`, which matches `jsonEncode`), using
his real timetable from `test/support/rutgers_fall_2026_ics_fixture.dart`: Mon 8:30-9:50 ECE 361,
2:00-3:20 and 5:40-7:00 ECE 345; Tue 10:20-11:40 ECE 331, 2:00-3:20 CS 206; Wed 8:30-11:30 ECE 333 lab,
2:00-3:20 ECE 345; Thu 8:30-9:50 ECE 361, 2:00-3:20 CS 206, 3:50-6:50 ECE 363 lab; Fri 10:20-11:40
ECE 331, 5:55-6:50 CS 206 (Livingston). Twelve meetings a week.

| Item | Bytes |
|---|---|
| One kept class (occurrence key, code, start, keptAt, xp) | about 115 |
| Day shell | about 30 |
| Extra Credit line ("I went to all my classes") | about 95 (GER's own entry with `dayKey`: 92) |
| His Monday, 3 classes plus Extra Credit | about 457 |
| A Tuesday, 2 classes | about 263 |
| Full class week (12 classes, 5 day shells, Extra Credit on 3 nights) | about 1,784, so about 255 per day averaged over 7 |
| One term (14.5 weeks) | about 26 KB |
| 180-day cap, steady state | about 46 KB (5.0% of the 921,600-byte guard) |
| Journal trace addition per class-day note | about 57 (codes) or 127 (codes plus titles) |

Against HANDOFF §9's model (747,170 UTF-8 bytes at 3 years, about 679 B/day growth, guard crossed at
about day 1,351):

- **Capped at 180 days:** the guard crossing moves about 67 days earlier (to about day 1,284).
- **Uncapped:** about 54 KB a year for two terms, so about 160 KB at 3 years; the crossing moves to
  about day 1,110.
- **Trace additions** on top (night page on 60% of about 150 class days a year): about 5 KB a year
  with codes, about 11 KB with titles; another 20 to 50 days earlier at 3 years.
- For scale, dropping the duplicated night journal text (HANDOFF §9) would save about 274 KB at 3
  years, roughly six times the capped record cost. That is a separate change, not part of this slice.

### 6.4 What it stays separate from

Not a `Quest`, never in `widget.quests`; no `history`, `totalCompletions`, `todayQuestTitles`,
mastery or goal progress; streak only through option (a), if Mika chooses it; no Today's three slot
(that stays Quests, HANDOFF §2.2).

---

## 7. Version bump list for internal 1.0.5

Apple normally closes a released version train, and 1.0.4 is live (HANDOFF §3.1, inferred). Next
internal candidate: **1.0.5+50**. Every location below was read in W at c0a041a.

| Location | Now | Change | Enforced by |
|---|---|---|---|
| `pubspec.yaml:19` | `version: 1.0.4+49` | `1.0.5+50` | release_native_privacy_test.dart:879; the build step |
| `codemagic.yaml:56` | tag pattern `room-of-days-1.0.4-build-49-internal-candidate` | new tag | CI trigger; release_native_privacy_test.dart:661 |
| `codemagic.yaml:86` | `MANIFEST=release-evidence/internal-testflight/1.0.4+49/CANDIDATE-MANIFEST.json` | `1.0.5+50` | receipt step; test :685 |
| `codemagic.yaml:88` | `test "$CM_TAG" = "room-of-days-1.0.4-build-49-internal-candidate"` | new tag | receipt step |
| `codemagic.yaml:90` | `.candidate.version` = `1.0.4+49` | `1.0.5+50` | receipt step |
| `codemagic.yaml:451` | manifest path in the IPA hash step | `1.0.5+50` | publishing |
| `ios/Runner.xcodeproj/project.pbxproj:699, :726, :753` | `CURRENT_PROJECT_VERSION = 49;` (widget target, three configs) | `50` | `tool/verify_internal_testflight_candidate.dart` `_verifyNativeWidgetContract` (contains-check only, so a partial bump passes it); the IPA check below catches a Release mismatch |
| `ios/Runner.xcodeproj/project.pbxproj:708, :735, :762` | `MARKETING_VERSION = 1.0.4;` (widget target) | `1.0.5` | same |
| Runner target `:475, :655, :678` | `$(FLUTTER_BUILD_NUMBER)` | none (follows `--build-number`) | |
| `lib/content/release_notes.dart:54-57` | first entry `id: '1.0.4+49'`, `versionLabel: 'VERSION 1.0.4 · BUILD 49'` | new first entry `'1.0.5+50'`, `'VERSION 1.0.5 · BUILD 50'` | `verify_store_submission.dart` `_verifyCurrentInAppReleaseNotes` :420-455 (run in CI through the internal verifier); release_notes_test.dart |
| `test/release_notes_test.dart:11` and the ordered list from :25 | `'1.0.4+49'` first | add `'1.0.5+50'` | itself |
| `test/release_notes_test.dart:12-20` | current title "The next step reads clearly." and three highlight titles | the new entry's title and highlights | **missed by the handoff** |
| `test/whats_new_screen_test.dart:64, :156` | key `whats-new-release-1.0.4+49` | new id | itself |
| `test/whats_new_screen_test.dart:57-62` | current title and highlight texts | new entry's texts | **missed by the handoff** |
| `test/release_native_privacy_test.dart:661, :685, :879` | tag, manifest path, pubspec | new values | itself |
| `STORE-LISTING.md:111` (TestFlight description) | "Build 49 is an internal candidate..." | must name "Build 50" | `verify_store_submission.dart --ios-testflight` `_verifyTestFlightCandidateIdentity` :483-503, called from the internal verifier in CI. **Missed by the handoff** |
| `STORE-LISTING.md:21` (App Store What's New heading) | "Version 1.0.4 (Build 45)" | only before an App Store submission | `verify_store_submission.dart` full / `--ios-only` mode only (`_verifyListingWhatsNewIdentity` :458-478; not run for `--ios-testflight`, :126-130). No flutter test checks it |
| `release-evidence/internal-testflight/1.0.5+50/CANDIDATE-MANIFEST.json` | absent | added alone in the receipt child commit | internal verifier :33-90 and codemagic.yaml:86-96 |
| `RELEASE-CHECKLIST.md` | Build 49 section | new section | not enforced |

No edit needed: `tool/verify_internal_testflight_candidate.dart` derives tag and manifest path from
pubspec (:20-31); `test/my_space_ui_test.dart:1081` pins the historical "VERSION 1.0.4 · BUILD 28"
label and stays valid because `WhatsNewScreen` builds every release in a `SingleChildScrollView`
(`screens/whats_new.dart:68`); `test/release_native_privacy_test.dart:592` and :728 pin older tags on
purpose; `release-candidate.json` is the Android 1.0.2+20 record and is read only in full mode.

Also enforced at build time: `codemagic.yaml:273-286` refuses to build when TestFlight's latest
build number is already ≥ the pubspec build, and the IPA check (:310-322) requires the app and the
widget's `CFBundleShortVersionString` and `CFBundleVersion` to equal the pubspec values.

---

## 8. CI traps

From HANDOFF §3.5, checked against W, for a build that touches engine, models, storage, quests,
routine flows and the receipt:

1. **Exact-XP tests on an unseeded `GameState`.** `GameState({Random? rng})` (engine.dart:41-42,
   also `debugRandomFactory`) rolls a 3-10% crit. Any test that drives a Quest through `roll()` and
   asserts XP must inject a no-luck `Random`. Class credit avoids this if it stays deterministic.
2. **Tracked goldens not re-captured after a restyle.** The night-ledger goldens
   (`test/goldens/routine_ledger_night_narrow_320x568_text_2x.png` and `..._scrolled_...`) are
   compared only under `CAPTURE_GOLDENS` (routine_ledger_visual_test.dart:16, :247+), so CI will not
   catch them, but GER re-captured both and those binaries are not in the snapshot: re-capture on
   Windows after the port. The files that compare exactly by default on **Windows only**
   (`runExactGoldenCheck`, test/support/golden_platform_policy.dart; Codemagic macOS skips them unless
   `VERIFY_EXACT_GOLDENS`) include `quest_mastery_visual_test.dart` (Quest cards) and
   `academic_calendar_visual_test.dart` (Plans, NOW/NEXT doorway): a local Windows run fails if a
   class row changes those surfaces even though CI stays green.
3. **Sound lanes outside the shipped list** (interaction_sound_quality_test.dart:923-975): a new
   `Pressable` declaring an unshipped pair (for example glass/navigate) fails the suite.
4. **`dart format` on unrelated files.** Format only the files you changed (637fc58 reverted
   formatter churn once).
5. **Time-of-day tests.** Build 46 failed because a night-routine test depended on the machine's
   clock; 9303781 froze it (`widget_test.dart` "night routine opens, recaps and closes",
   `Clock.freeze(DateTime(2026, 9, 27, 14))`). Everything class-day is time-of-day by nature
   (wind-down at 17:00, `content/routines.dart:605`; the 04:00 night boundary; "after the last
   class"). Freeze `Clock` in every widget test and build test clocks from the occurrence's instants;
   Codemagic's macOS host is not on America/New_York.
6. **Schema pin.** `test/storage_cloud_merge_test.dart:261` `expect(Storage.schema, 28)` fails on
   the bump until updated.
7. **Clean tree for the verifier.** `tool/verify_internal_testflight_candidate.dart` runs
   `git status --porcelain` and refuses any dirty or untracked path. W currently has modified
   `windows/flutter/generated_plugin*` files (from `flutter pub get`) and untracked
   `design/comparisons/2026-10-03/`, `test/design_renders/` and this brief; revert, commit or move
   them before running it.
8. **Night-route refactor ripple.** Moving the ledger from an `OverlayEntry` to a route changes how
   the existing night tests find and dismiss it (`night_routine_feedback_test.dart`,
   `day_rest_test.dart`, `widget_test.dart`, `audit_regressions_test.dart`). GER adjusted its own
   copies; W's versions differ (Builds 45-47 moved CLOSE DAY), so expect fixes there.
9. **Full suite is CI-only for this phase.** CI runs the whole `flutter test --no-pub`
   (codemagic.yaml:118-121) plus the discovery packet; locally run only the files you touched.

---

## 9. Handoff corrections

1. **Level-up caveat (STUDENT-DAY §5, Opportunity 1):** "If the +10 crosses a level, the level-up
   waits for the next Quest completion... in the shipped screens only the Quest completion chain calls
   it." That describes W and the engine method. GER's own UI resolves the level-up when the night
   ledger closes (GER quests.dart:1509) and defers it while the ledger is open (GER :1660); the GER
   widget test "extra-credit level threshold resolves on leaving the recap" checks it.
2. **Snapshot completeness (extra-credit-snapshot README):** `extra-credit-tracked-files.diff`
   leaves out two coupled files that exist only in the full diff:
   `lib/widgets/night_reflection_sheet.dart` (root to local navigator) and
   `test/storage_cloud_merge_test.dart` (the schema-29 tests). It also includes non-EC expedition code
   inside EC hunks (`ExpeditionScene`, `ExpeditionSurface`, `ExpeditionAssets`,
   `Palette.action/onAction/actionGradient`), none of which exist in W.
3. **STORE-LISTING enforcement (HANDOFF §3.1):** "a test enforces it" for the What's New heading. No
   flutter test checks it; `tool/verify_store_submission.dart` checks it in App Store mode only. For an
   internal build the CI check is the TestFlight description naming "Build N" (STORE-LISTING.md:111),
   which the handoff's list does not mention. Also missing from the list: the release-notes title and
   highlight pins in `release_notes_test.dart:12-20` and `whats_new_screen_test.dart:57-62`.
4. **Commit count:** W (c0a041a) is 46 commits past fd58456; 9bf441c is the 45th.
5. **Keepsakes "reconcile" (STUDENT-DAY §5):** nothing to reconcile at the schema level. Build 48
   Journal Keepsakes use the existing `memoryPins`; GER's "keepsakes" comment refers to the schema-28
   `roomKeepsakes` field already in W.
6. **Line drift (minor):** `roll()` runs to :1822 (HANDOFF §5 says :1686-1800); `decideCloudMerge`
   is :149-174 (handoff :149-165); GER's undo guard assignments are at GER quests.dart:1484-1485 with
   the comment at :1482-1483 (handoff :1483).
7. **Unchanged files lower the risk:** storage.dart, cloud.dart, routine_flows.dart,
   routine_ledger.dart and routine_ledger_visual_test.dart are identical at fd58456 and c0a041a, so
   the "45 commits behind" warning applies mainly to quests.dart and the three Journal/guide screens.

---

## 10. Verified, inferred, gates, departures

**Verified now** (read in W at c0a041a, or in the reconstructed GER copy, 2026-10-03): every W
`file:line` above; the fd58456 → c0a041a change matrix (`git diff --quiet` per file); the GER
reconstruction applies cleanly; GER line numbers for `addExtraCredit` (:1409), `applyLevelUps`
(:2183), the schema (:24, :250), the night-route exit (:1509) and guard (:1660); 332a90d's parent and
its two changed files; the fixture's twelve weekly meetings; the version pins; the verifier's
TestFlight-mode checks; the size numbers (computed in the session scratchpad from compact JSON).

**Inferred:** no schema-29 save exists in the wild; 1.0.5 is needed; the class-award defaults
(MIND for lectures, CRAFT for labs, no Glimmers); free-text Extra Credit should never hold a streak
day; the evening note belongs in the Journal.

**Remaining gates:** Mika's answers on the streak (option a or c), the award size, and Glimmers;
Mika's yes before cherry-picking 332a90d; device feel for any receipt or level-up path.

**Departures:** the task asked for "the exact hunks"; GER hunks are cited by diff header and GER
line, not reproduced. The unified model departs from GER's separate `extraCredit` key (fallback
given in 6.1). No copy was written; where a surface needs words, the copy pass owns them.
