# Class-day board and celebration: test report

Run on Windows, Flutter 3.44.2, 2026-10-04, branch `claude/class-day-journey`, on the tree of
68ee337 (the review fixes are ee857f5 and 68ee337 on top of the slice's 750d122 and 7533556).

## Full suite

`flutter test --no-pub`: **1,521 passed, 44 skipped (capture-gated renders), 0 failed**
(`02:06 +1521 ~44: All tests passed!`). The suite was 1,490 after the slice; the 31 new tests are
below. `flutter analyze --no-pub lib test`: no issues. Every changed Dart file passes
`dart format --set-exit-if-changed`.

During the review round, `goal_journal_opening_visual_test.dart` failed once inside a full run and
passed in the next full run and three times on its own. It does not touch the class day; it is
noted, not fixed here.

## What the review found, and the tests that now hold it

`test/class_day_board_test.dart` (43, the real `QuestsPage` on his Fall 2026 timetable at 393 x 852,
clocks frozen at New York instants, every reward without luck):

- The card header never puts a total beside a kept count: TUESDAY with 1 ATTENDED after a mark
  and at the countdown, no "2 CLASSES" beside it (findings 5, 12, 19).
- The shortcut's three marks undo together from the newest kept row through one RewardUndoSlot
  that spans the gesture; one undo row; the restore is the save from before the gesture (finding 4).
- A Goals hand-off on a class day opens the board; the dock's clear-focus bump leaves the room, also
  after a hand-off and ROOM; a hand-off on a day without classes never carries to Monday's room
  (findings 11, 18).
- Not in school settles an armed Quest undo; choosing Today's three under a kept class settles the
  class undo (findings 15, 16).
- On a day without classes a Quest level-up keeps the header at LEVEL 18 behind the takeover
  (finding 17; this test fails on the old always-setState path).
- BOARD after a mark shows the board's MIND and XP already landed; a board mounted while the Quests
  tab is hidden shows its real stats on the first BOARD (findings 2, 20).
- Sound and touch, through `Sfx.debugOnPlay` with playback bypassed: I WAS THERE plays one
  completion composite and a light haptic, the celebration plays `stat_2` (MIND), the undo swipe
  plays `boing`, and `levelup` never plays unless a level is crossed, where it plays once after the
  celebration (finding 23).
- After midnight: at 01:30 on Wednesday the card is still Tuesday with I WAS THERE on Discrete
  Structures II and the mark lands on Tuesday; after 04:00 it is Wednesday; the night-end timer turns
  the card over by itself (finding 24).
- Going back on its own: the words leave first and the room is home by about 2.4 s; a finger on
  the glass holds it and its release starts the fade back (finding 10).
- The quick tier has landed its count and closing line by 500 ms and has no time and room line
  (finding 9).
- A two-digit count (YOUR 24TH LECTURE) sits inside the diamond on the class and day tiers at 100%
  and 130% text: the numeral keeps its size, its box stays inside the diamond's edges, and the
  diamond's points stay clear of the headline and the label (finding 3).

`test/class_day_model_test.dart` (30): the day and week tiers' chips cover the same classes as the
big number (Tuesday +60 XP with +6 MIND; Thursday +6 MIND and +5 CRAFT; the week's MIND) (finding
8); the quick tier has no detail line (9); the streak line, once ClassDayRules lights it, reads
"1 DAY RUNNING · TODAY COUNTS" on the first class of a day, nothing on the second, "2 DAYS RUNNING"
the next day, and nothing by default (25); a break longer than a week says "Free until Oct 19 at
8:30." (13); at 11 PM the next boundary is the night's end at 4 AM (24); an office hour kept alone
on the week's last day says "One class this week.", never zero (14).

`test/class_day_plumbing_test.dart` (8), through the real shell: an empty timetable on a weekday
offers the row; tapping it opens the Plans sheet; the same request does not reopen it; a new tap
does; a timetable still loading and a timetable with classes offer no row (finding 22).

`test/class_credit_test.dart`: one slot spans a gesture that keeps several classes and refuses once
a later reward lands.

## Renders

`flutter test --dart-define=CLASS_DAY_RENDERS=true test/design_renders/class_day_board_build_test.dart`:
15 passed, 45 frames, no layout issue logged, rendered after 68ee337. New: B2e (the fade back at
2.3 s), K1 to K3 (YOUR 24TH LECTURE on the class tier, the day tier and at 130%), P1 to P4 (the
archive room). The render test file is formatted (finding 21). Frames, notes and sheets:
`design/comparisons/2026-10-03/class-day/build/journey/board/`; before and after crops for the
visual findings: `review/after_fixes_1.png`, `review/after_fixes_2.png`.

## The evening slice (rubric 6, with 7 and 8), 86f9989

Run on Windows, Flutter 3.44.2, 2026-10-04, on the tree of 86f9989.

`flutter test --no-pub`: **1,551 passed, 54 skipped (capture-gated renders), 0 failed**. One run
before the final fix failed `interaction_sound_quality_test.dart` (Close the day declared the
unshipped glass/open lane); it now uses glass/select, a shipped lane. `flutter analyze --no-pub
lib test`: no issues. Every changed Dart file passes `dart format --set-exit-if-changed`.

`test/class_day_evening_test.dart` (17, the real `QuestsPage` on his Fall 2026 timetable at
393 x 852, New York instants, no reward luck):

- Tue 15:35, the last class kept: under TUESDAY, DONE. the room holds the desk; after the tap the
  camera walks from the celebration's framing to the window, the shot moving every frame in one
  direction, still on its way at 1.5 s, the near planes swinging wider mid-pan (tilt below -0.5)
  and settling at zero; the only blur on the room is the glass's own. Then the day on one line
  (Tuesday’s classes, both attended, +60 XP), Write a line, Today's three with BOARD, no Close the
  day before 5 PM and no Steward door.
- Opened in the evening, the room is already there (no walk). Reduce Motion: no walk, the shot
  never travels. The archive room: the same evening glass on a still plate. 130% text: no
  overflow.
- Mon 17:45 in the late lecture: no evening, I'M HERE, and the board scrolled to its end has no
  CLOSE THE DAY rail (its all-day CLOSE DAY door is there). Mon 19:15: the board has the rail; the
  room is the evening with the 5:40 lecture still leading (I WAS THERE, the shortcut, two quiet
  dots, no music row yet, Close the day); the shortcut's MONDAY, DONE., then all three attended
  +85 XP and the music row.
- A mark made in the evening (Thu 18:55, the lab) plays its celebration on the room's own
  framing. Close the day from the glass opens the ledger; once tonight is closed it leaves the
  glass.
- Write a line opens a fresh journal page and writes nothing until he does; a line written under
  an armed undo settles it first (this test fails without the fix).
- Music: nothing starts on its own; a press asks the rotation for Lamp left on then starts it,
  the saved setting stays off; a later take reads Room music; a second press pauses. With music on
  in Me the evening shows it playing and a press quiets it for tonight without touching Me.
  Tonight's choice gives way to the saved setting on Wednesday morning.
- Undo: the day line swiped left past 42% restores the save from before the mark.

`test/class_day_model_test.dart` (+6): the wind-down window with a last class end; never during his
Monday lecture (17:45, 18:59) or Thursday lab (18:45), from 19:00 and 18:55; Tuesday's at 17:00,
and past midnight still Tuesday's night; the wind-down start instants (17:00, 19:00, 18:50) and the
boundary at Tue 15:35 being 17:00; the evening rule; the record words, which never carry a digit
or "of"; and the 9 PM night reminder after every class day's last class (his latest ends at 7:00).

`test/background_music_test.dart` (+5) and `test/main_room_music_test.dart` (+2): tonight's choice
plays Lamp left on first and never writes the saved setting; quiet for tonight over a saved
setting that is on; a playing rotation is never restarted; Me's switch gives the choice up; Focus
keeps its own session; the rotation's preferred take plays once and its composition never twice in
a row; `nowPlaying` names the take and clears on stop.

`test/class_day_board_test.dart`: the day tier and Monday shortcut tests now expect the evening
line after the tap (the board slice expected the record card there).

### Renders

`flutter test --dart-define=CLASS_DAY_RENDERS=true test/design_renders/class_day_evening_build_test.dart`:
10 passed, 24 frames, no layout issue logged, rendered after 22e698b (which lets the board renders'
back-home frames wait out the walk; the board renders were re-run then too, 15 passed, and their
sheets and review crops regenerated). Frames, notes and sheets:
`design/comparisons/2026-10-03/class-day/build/journey/evening/` (`sheet.png`; concept B beside the
build in `compare-sheet.png`).

## The board review round, checked again on 3eb9e0e

2026-10-04, after a usage-limit cut-off: the workflow ran the board's review-fix step a second
time. Every one of the 25 board findings was already fixed by ee857f5 and 68ee337, and each still
holds on 3eb9e0e, so this pass changed no code. Checked on a clean, detached checkout of 3eb9e0e
(a temporary worktree, since removed), so the evening review's unfinished edits in this worktree
played no part:

- `flutter test --no-pub`: **1,551 passed, 54 skipped, 0 failed**.
- `flutter analyze --no-pub lib test`: no issues.
- `dart format --set-exit-if-changed` over the 29 Dart files changed since 076ef04: 0 changed
  (finding 21).
- Each finding was traced to its fix in the code and to the test that holds it (listed above).
- The board frames (rendered after 22e698b, whose app code is the same as 3eb9e0e's) were looked
  at again: the room runs to the top of the screen with the shelf, plant and lamp behind the HUD and
  no step at 59 pt (B1, C1, Q1). The window top is soft at 300 ms (B2c, D2a). The archive plate
  stays in place from P1 to P3. 24 sits inside the diamond at 100% and 130% (K1 to K3). Q3 has
  its count landed with no time and room line. The header never puts a total beside a kept count
  (B3, D1). BOARD fades the room back over a board already showing the same numbers (D4a).

The uncommitted edits in this worktree (the evening review's fixes: window panes, the evening
shot, the dock stepping back, tonight's music choice ending at the night's end, the day tier
playing once a day, the ledger naming the next class) are not part of this check and are not
committed here. Run on that tree, the board, model, plumbing and credit tests pass, and three
tests from that unfinished work still fail: two evening layout tests at 375 x 667 and the
ledger's "tomorrow's classes head the tray".

## The evening review round, finished on c659a58

2026-10-09, after the 2026-10-04 usage-limit cut-off. The evening review's three reports (fidelity,
correctness, CI) came back with 9, 3 and 4 findings; the cut-off tree carried most of the fixes
uncommitted. This round finished them, removed the runtime daylight and changed the count's words.
Commits: 1f72401 (review fixes), 6cc193a (the room stays the night painting), aff9fb6 (the count
says "on record"), 779467d (doors), c659a58 (renders and notes).

### Findings, each one

- Glass hidden and unpressable for 2.4 s when the evening starts on a room already up: fixed. Only
  the walk under the celebration stages the glass's arrival; reopening, the wind-down timer and an
  undo crossfade with the glass on screen.
- Room shrunk to a band while classes wait: fixed in `RoomShot.evening` (lamp held under the HUD, the
  floor runs on behind the glass). Seen in E4a, E6a, E9b: lamp and moon in frame.
- Settled glass not letting the room own the frame, hierarchy inverted, still level bars: partly
  fixed. The doors are one quiet row under the record (record textHi, doors textMid), the music
  steps the glass, HUD, line and dock back and eases the camera closer, and the levels move. Not
  changed: with the music on the glass is still the record plus two rows of doors; I looked at
  E2b but did not measure how much of the frame it takes against concept F5.
- Mark made in the evening plays the day tier in an unlit room: fixed (the framing is held only
  when the lamp is clear of the scrim; otherwise the camera eases back to the whole lamp).
- Day tier twice (DONE., THAT ONE TOO., DONE.): fixed in `planClassCelebration`
  (`dayTier = afterLast || (completes && !dayTierPlayed)`); model tests for the one-at-a-time case.
- Window sky pasted onto the painting: resolved by removing the daylight (below), not by
  patching it.
- CLOSE THE DAY did not follow large text: fixed (no FittedBox; the doors wrap whole).
- Mixed apostrophes: fixed. Ledger header said KEPT and dropped the next class's name: fixed
  (ATTENDED, and the next class by name over its tag).
- After midnight Write a line took the calendar day's trace: fixed (`journalTraceFor` the class day).
- Tonight's music choice outliving its night: fixed (`setRoomChoice(until:)`, read through Clock).
- CI blocker (plumbing test read host-local wall time): fixed, the case now uses a Sunday night.
- 130% test could not see a scrolled-away door: the evening test now asserts hit-testable doors
  and a zero scroll extent. The no-blur check now asserts no ImageFiltered at all in the room.
  The three 8 PM mounts: header corrected.
- Rejected: none. Left open: a night reminder hour chosen in Me can still fire mid-class, and the
  board's footer CLOSE DAY door still shows mid-class (both were open before).

### The three tests that failed on the dirty tree

- `class_day_evening_test` Monday three waiting, 375 x 667, at 100% and 130%: the test file never
  loaded the real faces, so every label ran in the test font's square glyphs and the doors wrapped
  onto a second row that real text does not need. That was the test's fault: it now loads the
  faces (`loadRoomFonts`). With real text only 130% was left, 1 pt over; the compact glass's gap
  under its header went from 12 to 10 pt. The assertion (nothing scrolled out of view) is unchanged.
- `class_day_ledger_test` "tomorrow's classes head the tray": the new next-class line is a plain
  Text, and the test read `textSpan!` on every line. The test reads `data ?? textSpan` now; the
  expected lines were already right.

### Runtime daylight removed

`ClassWindowSky`, the daylight colour grade, the window-light panel, the blurred window edge, the
lower-pane range and head shade (all of the uncommitted window edits only served daylight) and the
board's `windowLayer` plumbing in `HomeRoom` are gone, along with `RoomHour`. The lamp keeps one
resting glow. Kept: the evening camera framing (`RoomShot.evening`, `coverLeft`).

### Count copy

The celebration's per-course label reads `FIRST ONE ON RECORD` and `YOUR 9TH LECTURE ON RECORD`
(it counts the marks the app has, not the lectures he has been to). Tests: model (first, 2nd,
a lab, no ` OF `), board (24 at 100% and 130%: label inside the screen, no exception).

### Verified

- `flutter analyze --no-pub lib test`: no issues. `dart format` over the Dart files changed since
  278a73f: 0 changed.
- Class-day tests, background music and main-room-music tests: green; the full suite
  (`flutter test --no-pub`), run after 779467d: **1,555 passed, 54 skipped, 0 failed**. The only
  later changes are render tests' captions and notes (those tests ran green, gated on).
- Renders (`CLASS_DAY_RENDERS=true`, board 15 passed, evening 10 passed, no layout issue logged).
  Looked at full size: B1, B2c, D2a (the left edge is the painted night window, no pale strip),
  E1f, E4a, E2b (the window is the painted moon and stars, the lamp and the moon in frame, the
  glass leads with the class waiting, the doors on their own rows).
- Contact sheets regenerated (`sheet.png` in both folders). `compare-sheet.png` and
  `compare-sheet-1/2.png` were rebuilt as plain concept B beside build pairs (the old ones were hand
  cut against the daylight frames); the reviewers' before/after crops `review/after_fixes_*.png`
  show the old frames, so they are no longer cited as evidence.

### Inferred, not verified

Anything about how the walk, the music step-back and the glass feel on his phone; whether the
glass's three rows still read as "a list" to him (E2a/E2b), which is the first thing in the
evening that still feels a little built, not painted.
