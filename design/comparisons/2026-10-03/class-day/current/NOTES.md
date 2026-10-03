# A class day in Room of Days today (Build 49 code)

Rendered 2026-10-03 from worktree `class-day-journey` at c0a041a, with `lib/` unmodified. The
renders run the real `LifeRpgApp` in flutter_tester at iPhone 15/16 Pro size (393 x 852 pt at 3x,
59 pt top and 34 pt bottom safe areas), with iOS platform behavior and his real Fall 2026
timetable imported through the app's own importer.

The request this answers (Mika, 2026-10-03): "i feel like it's not in the best state it could be
right now, plus i barely use it as a student who just goes to class then relaxes afterwards. maybe
we need to consider that sort of case more and make it still useful for me?"

Contact sheet: `current-sheet.png`. Frame list with times: `frames.json`. Run log: `render-log.txt`.
Schedule rows: `schedule.txt`. Widget snapshot: `H_tue1535_widget_snapshot.json`.

## His two days (verified from the fixture, as imported)

| Day | Classes |
|---|---|
| Mon Oct 5 | 08:30-09:50 14:332:361 Electronics Devices (SEC 111) · 14:00-15:20 14:332:345 Linear Systems & Signals (SEC 111) · 17:40-19:00 14:332:345 Linear Systems & Signals (SEC 204) |
| Tue Oct 6 | 10:20-11:40 14:332:331 Computer Architecture & Assembly Language (HLL 114) · 14:00-15:20 01:198:206 Discrete Structures II (PHY 001) |

No cancellation or designated-day swap touches either day (the fixture's swaps are Sep 8 and
Nov 25; the recess is Nov 25-27). The test asserts this.

## The account

- **Verified numbers** (the App Store screenshot account, HANDOFF.md 5.4): level 18, 284/870 XP,
  4,280 total XP, MIND 116, HOME 103 (BODY 88, CARE 72, CRAFT 94, PEOPLE 61), 12-day streak, best
  19, 3 freezes, the walnut room, its five ordinary Quests plus the guided workout, two goals.
- **Inferred:** he now barely opens the app, so his last active day is Mon Sep 28, a week before
  the first render day. The 12-day streak is the run that ended that day, mostly one Quest a day.
  On Sep 28 he chose Today's three (Read ten pages, Clear the kitchen counter, Message someone I
  miss) and kept one. Nothing is chosen for the render days. Sound off, motion on. The two
  journal entries are the store account's sample pages re-dated into September, not his writing.
  Whether his classes are imported on his real phone is unknown.

## Frames

| Frame | When | Surface | What it shows | How his day reads |
|---|---|---|---|---|
| B1 | Mon 19:15 | Quests, first frame | Room strip, level 18 HUD, six stats, "Today's three · 6 open · choose", featured "Read ten pages +24 XP" with MARK COMPLETE, then "Walk after lunch" | He just left a 7 PM lecture after a 5 h class day. The board asks him to choose the day's three and do chores. Nothing says he was in class |
| B2 p1, p2 | Mon 19:15 | Quests, scrolled | The other Quests, the CLOSE THE DAY rail ("Close whenever you're ready."), "3 READY · BEST 19 KEPT", the Energy weather panel ("What is the weather inside today?") | The only state shown is freezes and a weather check-in. No streak, no class, no evening |
| C0 | Mon 21:30 | Quests, first frame | Byte-identical to B1 (same MD5) | 19:15 and 21:30 are the same picture |
| C0b | Mon 21:30 | Quests, scrolled to the rail | The rail he taps to close the day | |
| C1 | Mon 21:30 | Close the ledger | Night room, leather ledger: WHAT MOVED "+0 XP", "the quiet days still count", "NO THREADS FINISHED", "Nothing had to be proven today.", an empty MARK TOMORROW tray (1 2 3 "Choose one"), CLOSE THE DAY | A day with three lectures is written into the book as zero. Kind words, but the page is empty |
| C2 | Mon 21:30 | Ledger after tapping "reflect · optional" | Visibly the same as C1. The reflection sheet opened underneath the ledger (see Defects 1) | The one place to write about the day does not appear |
| C3 | Mon 21:30 | Mark tomorrow | KEEP THREE CLOSE · 0/3, his daily Quests as rows | Tomorrow is planned as chores. His Tuesday classes are not on the page |
| C4 | Mon 21:30 | Mark tomorrow, 3/3 | Read ten pages 1, Clear the kitchen counter 2, Message someone I miss 3 | |
| C5 | Mon 21:30 | Ledger, tomorrow marked | Tray filled; the ribbons cover the second line of two titles (Defects 3) | |
| C6 | Mon 21:30 | CLOSE THE DAY at 220 ms | The book settling as it closes | |
| C7 | Mon 21:30 | Right after closing | The reflection sheet from C2 surfaces now, full screen: "Keep what matters", REFLECT / 3 GRATEFUL / DISCOVERED / TOMORROW | The writing prompt arrives after the day is already closed |
| C7b, C8 | Mon 21:30 | Quests, closed | "The day is kept." / "Tonight is closed and written. The rest can wait." / "The board opens with the morning." / I'M NOT DONE YET; the HUD reads THE DAY IS KEPT | The warmest frame of the day, and the first that feels like an evening. It still names nothing he did |
| D1 | Tue 08:05, Monday not closed | Quests, first frame | Byte-identical to A1 (Tue 15:35) | Before his 10:20 class and after his last class he sees the same pixels |
| D2 | Tue 08:05, Monday closed | Open the day (auto-shown) | Sunrise room, parchment ledger: YOUR THREE with "1 BEGIN HERE Read ten pages", TODAY FEELS LOW / STEADY / BRIGHT, "3 side quests waiting", OPEN THE DAY. Rows 2 and 3 overflow by 6.9 pt (debug stripes; Defects 2) | Reachable only because the night was closed. No classes on the morning page, so it cannot say his first class is at 10:20 |
| D3 | Tue 08:05 | Quests after Open the day | "Today's three · 0 of 3 kept", MAIN badges on the chosen Quests | |
| A1 | Tue 15:35 | Quests, first frame | Same as D1: night window, lamp lit, "6 open · choose", Read ten pages +25 XP | 15 minutes after two lectures. The room is in night, the board is a morning to-do list |
| A2 p1, p2 | Tue 15:35 | Quests, scrolled | Quests, a small CLOSE DAY link (before 17:00), freezes, Energy weather | |
| E1 | Tue 15:35 | Plans, as it opens | PLANS / "your days, held in one place", DAYBOOK Fall 2026, MONTH/WEEK/3 DAYS/DAY, doorway NEXT CLASS · TOMORROW, 14:332:333 · Lab, 8:30 to 11:30 AM, EE · 103, October month | The only surface that knows his schedule. It has already moved on to tomorrow |
| E2, E3 p1 | Tue 15:35 | Plans, DAY view | "OCTOBER 6, 2026 · NEW YORK · CAMPUS TIME", "DAY SHAPE 2 fixed plans · first at 10:20 AM", the two classes as cards with NOTES, ADJUST, "reminders off", a PLAN QUEST button | Classes he already sat through look exactly like future ones. There is no way to say they happened |
| F1 | Tue 21:10 | Journal tab | WRITE FOR TODAY, ENTRIES / PATTERNS / CHRONICLE, "Your Week · 7 days active · 9 quests", "138 quests logged across 70 active days." | Stats about Quests, none about days of class |
| F2 | Tue 21:10 | Journal, new page | "New entry", ADD PHOTOS, ATTACHED TO THIS PAGE "Level 18 · 4280 total XP", "What's on your mind today?" | The day trace for a two-lecture day is his level and lifetime XP |
| F3 | Tue 21:10 | Same, keyboard up | Page shrinks to the space above a 336 pt keyboard (keyboard not drawn) | The trace and the first lines stay visible while typing |
| G1, G2 p1 | Sun Oct 4 21:10 | Weekly chronicle | YOUR WEEK SEP 21-27, "9 quests became progress", "7 OF 7 DAYS ACTIVE · 1 MORE QUESTS THAN THE WEEK BEFORE", seven equal diamonds, MIND BURNED BRIGHTEST "Feeding your head.", SAGE QUIET MASTER, SHARE CHRONICLE | A week with 12 classes is told as 9 Quests. Every lit day looks the same size |
| H | Tue 15:35 | Widget snapshot (JSON) | Next class Wed 08:30 Computer Architecture Lab, then 23 more classes through Oct 20; UP NEXT "Guided workout · Wake-Up Snack", "Walk after lunch", "Message someone I miss" | At 15:35 the widget has nothing to say about today: next class is tomorrow, and it leads with a workout |

## How a class-then-relax day reads today

- **Verified (renders):** the Quests tab is the same picture before class, after class and late at
  night (A1 = D1 and B1 = C0, byte for byte). The board has no idea a day happened, and after his
  last class it still opens on "choose" and MARK COMPLETE.
- **Verified:** the game layer reads his Monday as empty. Three lectures produce "+0 XP", "NO
  THREADS FINISHED" and "Nothing had to be proven today." The copy never scolds, but it gives him
  nothing.
- **Verified:** classes live only in Plans, which treats them as a calendar. At 15:35 the doorway
  already points to tomorrow, and today's two classes look the same as future ones.
- **Verified:** the Journal page's trace, the weekly chronicle and the widget never mention a
  class.
- **Verified:** the evening only exists after he closes the night ("The day is kept."). Before
  that, 19:15 and 21:30 are a chore board with a rail at the bottom.
- **Inferred:** so a student who went to class and wants to rest gets no reason to open the app:
  it cannot see the part of the day he did, and the part he wants (resting) has no place until he
  performs the closing ritual.

## First thing that feels artificial

Opening A1 cold: the room above the HUD is in deep night (starry window, lamp lit, fire going) at
3:35 in the afternoon, and directly under it the board asks him to "choose" today's three as if
the day were starting. The room does not know what time it is, and the board does not know he has
just spent the day in class.

## Defects found in passing (not fixed; lib/ was out of scope)

1. **Reflection sheet opens behind the ledger.** "reflect · optional" in the board-launched night
   flow pushes `showNightReflectionSheet` on the root navigator (`useRootNavigator: true`,
   night_reflection_sheet.dart:27), but the ledger is an OverlayEntry that QuestsPage inserted
   directly into that same overlay (quests.dart:1684-1716), and Flutter keeps non-route entries
   above routes. The sheet is in the tree but not hit-testable (render-log.txt), so the tap seems
   to do nothing, and the sheet surfaces after CLOSE THE DAY (C7). Confidence high from code and
   render; confirm on a device. night_routine_feedback_test.dart pumps NightFlow as a route, so it
   does not cover this.
2. **Morning rows overflow at 393 x 852.** `_MorningQuestLine` (routine_flows.dart:3226) gets
   29.1 pt of height and needs 6.9 pt more, so the "HOME · +28 XP" sub-lines of rows 2 and 3 are
   clipped in release (debug stripes in D2). Fonts here are the bundled EB Garamond and JetBrains
   Mono, so this is not a font stand-in effect.
3. **Tomorrow tray ribbons cover text.** In C5 and C6 the slot titles wrap to two lines and the
   ribbons sit over the second line ("Clear the kitchen c... r", "Message someone I").
4. **Chronicle grammar:** "1 MORE QUESTS THAN THE WEEK BEFORE" (G1).
5. **Chronicle reads the wall clock.** `weeklyChronicleFor` defaults to `DateTime.now()`
   (content/weekly_chronicle.dart:48-53) and `WeeklyChronicleScreen` and the Journal "Your Week"
   card call it without `now`. Same result on a phone; it only matters for tests (AGENTS.md asks
   for Clock).
6. **Widget order:** the snapshot's first Quest is the guided-workout launcher, ahead of the
   chores (widget_snapshot.dart sorts by difficulty after priority). Minor.

## How the renders differ from his phone

- flutter_tester, not a device: no iOS status bar or Dynamic Island (the top 59 pt is a plain dark
  band), no sound, haptics, gyro parallax or 120 Hz. Text without a family would use SF Pro on a
  phone; Inter stands in (most app text names its family, so this barely shows).
- Clock frozen at each time; animations settled with fake time. Scenarios boot fresh from the
  seeded save, except C to D2/D3, which is one session sent to the background at 21:30 and reopened
  at 08:05 the next morning.
- G is rendered on Sunday Oct 4, because the chronicle screen reads the real date (Defect 5). On
  Tuesday Oct 6 his phone would show the week of Sep 28-Oct 4 instead (1 Quest on 1 day).
- F3's keyboard is a simulated 336 pt inset; the keyboard itself is not drawn.
- D2's red and white stripes are Flutter's debug overflow marker; a release build clips instead.

## Reproduce

```
cd C:/Users/mikus/Downloads/experimentProject/app/.worktrees/class-day-journey
flutter test --dart-define=CLASS_DAY_RENDERS=true test/design_renders/class_day_current_test.dart
python test/design_renders/contact_sheet.py design/comparisons/2026-10-03/class-day/current design/comparisons/2026-10-03/class-day/current/current-sheet.png --order B,C,D,A,F,G
```

The renders are deterministic: two runs gave identical PNGs except where the harness changed.
