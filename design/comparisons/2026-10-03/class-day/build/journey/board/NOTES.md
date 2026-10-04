# Class-day board and celebration: build renders

The real app (`LifeRpgApp`, this branch's `lib/`) at 393 x 852 pt, 3x, iOS behavior, on Mika's
Fall 2026 timetable imported through the app's own importer, his Mika-like save (level 18,
284 / 870 XP). Rendered by `test/design_renders/class_day_board_build_test.dart`:

```
flutter test --dart-define=CLASS_DAY_RENDERS=true test/design_renders/class_day_board_build_test.dart
```

`--dart-define=BOARD_ONLY=tue,mon,thu,fri,level,none,reduce,text` renders a subset. Frame list
with times: `frames.json`. Engine output per seeded keep: `render-log.txt`. All frames on one
page: `sheet.png`. Concept (left) and build (right) at the same size, one pair per rubric state:
`compare-sheet-1.png`, `compare-sheet-2.png` (made by a small PIL script from the two folders).

## The story

The week of Oct 5 is played forward through the engine as if the class day shipped on Monday:
every count and XP figure is what the build pays (no seeded counts). That is why Tuesday's
Computer Architecture is "YOUR FIRST LECTURE" and Friday's Discrete Structures II is "YOUR 3RD
LECTURE". Inferred: which classes he marks and when (every class, at the times named per frame);
the level-crossing frames lift his XP to 850 / 870 and set 11 quests since level 18; W3 leaves
Tuesday's Discrete Structures II unmarked on purpose.

## Frames

| Frame | When | What it shows |
|---|---|---|
| B1 | Tue 11:52 | The room, Computer Architecture foremost (ended 11:40) with I WAS THERE, Discrete at 2:00 PM, the two-line HUD, Today's three and BOARD |
| B2a | press | Finger down: the plate sinks into the glass |
| B2b | +100 ms | Released: the card's own ring has closed, 1 ATTENDED |
| B2c | +300 ms | The takeover fades in on the room's own framing; the headline slams |
| B2d | settled | YOU WERE THERE., 1, YOUR FIRST LECTURE, the course, +25 XP threading into the rail, +3 MIND, First one down. Discrete Structures II is at 2:00 PM. |
| B3 | Tue 11:53 | Back on its own at 2.4 s: Discrete leads, Computer Architecture kept |
| U1, U2 | Tue 11:53 | The kept row swiped left past 42% (UNDO), then the whole save restored |
| C1 | Tue 13:48 | STARTS IN 12 MIN, the only countdown |
| C2 | Tue 14:40 | In session: I'M HERE |
| D1 | Tue 15:35 | The last class ready |
| D2a, D2b | +300 ms, settled | TUESDAY, DONE., the day's rows, All of Tuesday's classes +10, +60 XP for the day, Two for two. Nothing else until Wednesday's 8:30 lab. Held for a tap (still up at 5.7 s) |
| D3 | Tue 15:36 | Back home: the record (both attended, +60 XP, the +10, tomorrow's lab) |
| D4a, D4b | Tue 15:36 | BOARD: the board slides up over the room (no blur), then the full board with the ROOM line |
| X1 | Mon 19:15 | Three waiting: the 5:40 lecture foremost, two quiet dots, I went to all of today's classes |
| X2a, X2b | +300 ms, settled | One celebration for all three: MONDAY, DONE., 3, CLASSES TODAY, +85 XP, Three for three. Tomorrow starts late: Computer Architecture at 10:20. |
| X3 | Mon 19:16 | The record: all three attended |
| Q1, Q2, Q3 | Thu 15:22 | Two waiting before the lab; the quiet row brought forward; THAT ONE TOO. at 1.5x (captured mid-count at 700 ms), back at 1.4 s |
| W1, W2 | Fri 18:56 | The week's last class; THAT'S THE WEEK., Twelve for twelve., Free until Monday at 8:30. |
| W3 | Fri 18:56 | The same week with Tuesday's Discrete unmarked: Eleven classes this week. No denominator |
| L1, L2 | Tue 11:52 | LEVEL 19 READY on the rail; then the real LevelUpOverlay, 11 quests and 4 classes since level 18, the room's words stepped back behind it |
| N1 | Tue 11:52 | No timetable: the board as today, one Add your classes row under the hero |
| R1 | Reduce Motion, 300 ms | Everything landed; one short fade, no travel, no slam, no motes |
| T1, T2 | text 130% | The room and the celebration at 130% in-app text |

## Not shown here

The evening (the camera walk to the armchair, music, Close the day in the glass) is the next
slice. flutter_tester renders are silent: the completion composite, the stat note, haptics and
the press feel need his phone.
