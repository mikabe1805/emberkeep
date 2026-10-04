# Class-day board and celebration: test report

Run on Windows, Flutter 3.44.2, 2026-10-04, branch `claude/class-day-journey`.

## Full suite

`flutter test --no-pub`: **1,490 passed, 40 skipped (capture-gated renders), 0 failed**
(`02:14 +1490 ~40: All tests passed!`, on the tree of 7533556). The suite was 1,444 before this slice; the 46
new tests are below. The first full run on this slice failed only the three
`class_day_plumbing_test.dart` cases that tap board doors on a class day; they now tap BOARD
first, as a person would (the Quests tab opens on the room).

`flutter analyze --no-pub lib test`: no issues.

After the last implementation commit (7533556) the class-day files, the copy guard and the
sound-lane guard were run again: `flutter test --no-pub test/class_day_board_test.dart
test/class_day_model_test.dart test/class_day_plumbing_test.dart test/copy_style_guard_test.dart
test/interaction_sound_quality_test.dart`: **77 passed**. The full-suite run above is the same
code as that commit.

## New tests

`test/class_day_board_test.dart` (24, the real `QuestsPage` on his Fall 2026 timetable at 393 x 852,
clocks frozen at New York instants so they hold on Codemagic's Mac):

- the room owns a class day: Tuesday 11:52 one owner and one luminous control, HUD with the six
  stats, Today's three and BOARD, nothing counted against him; a countdown only inside 15 minutes;
  I'M HERE in session; the next class boundary re-reads the card by itself; a day without classes
  keeps the board.
- marking and the celebration: I WAS THERE keeps the class through the engine (+25 XP, +3 MIND,
  no Quest counters) and plays YOU WERE THERE. with YOUR FIRST LECTURE, the course, +25 XP, the
  MIND chip and First one down. Discrete Structures II is at 2:00 PM., back at about 2.4 s; a
  finger on the glass holds it; TUESDAY, DONE. with Two for two., the +10 and the held tap; the
  first mark after the last class without Two for two or the +10; Monday's shortcut marks all
  three with one celebration (Three for three., +85 XP); Thursday's THAT ONE TOO. within 15 s,
  back at about 1.4 s; Friday's THAT'S THE WEEK. Twelve for twelve.; a week with a class left
  unmarked says Eleven classes this week.; a level crossed chains into the real LevelUpOverlay
  (11 quests and one class since level 18); undo past 42% restores the whole save through the
  reward slot; a short swipe keeps the class; a staged Quest reward lands before the class write
  and its undo is settled; Reduce Motion lands at once behind one short fade; 130% text lays out
  the room and the celebration without an exception.
- the board: BOARD and ROOM; reopening after a class boundary brings the room back; no
  timetable keeps the board unchanged; Add your classes on a weekday, gone for good with Not in
  school (persisted); never on the weekend.

`test/class_day_model_test.dart` (22): the next-class line for each of his weekdays (Mon
"Tomorrow starts late: Computer Architecture at 10:20.", Tue "Nothing else until Wednesday's
8:30 lab.", Wed "Thursday is the long one: three classes, lab until 6:50.", Thu "Friday ends
late: Discrete Structures II at 5:55.", Fri "Free until Monday at 8:30."); row states and the
foremost class; the boundary timer's instants; titles, ordinals and clocks; every tier's plan
(class, count that grows, lab, quick within 15 s and not after it, day with and without N for N,
the later mark after the last class, the week with no denominator, the shortcut); the level-up's
classes line with quests, alone, and absent.

## Renders

`flutter test --dart-define=CLASS_DAY_RENDERS=true test/design_renders/class_day_board_build_test.dart`:
11 passed, 32 frames, no layout issue logged (regenerated after the commit; frames.json and
render-log.txt came out byte-identical). Frames and notes:
`design/comparisons/2026-10-03/class-day/build/journey/board/`.
