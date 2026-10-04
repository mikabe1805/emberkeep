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
