# Class-day evening: build renders

The real app (`LifeRpgApp`, this branch's `lib/`) at 393 x 852 pt, 3x, iOS behavior, on Mika's
Fall 2026 timetable imported through the app's own importer, his Mika-like save (level 18,
284 / 870 XP). Rendered by `test/design_renders/class_day_evening_build_test.dart`:

```
flutter test --dart-define=CLASS_DAY_RENDERS=true test/design_renders/class_day_evening_build_test.dart
```

`--dart-define=EVENING_ONLY=tue,mon,thu,plate,reduce,text` renders a subset. Frame list with
times: `frames.json`. Engine output per seeded keep and the checks the run made: `render-log.txt`.
All frames on one page: `sheet.png`. Concept B (left) and build (right) at the same size, one pair
per evening state: `compare-sheet.png`.

## What the evening is

On a class day, once the last class is over and either every class is kept or the wind-down has
begun, the room owns the frame. The camera walks from the desk to the window and the armchair by
moving the walnut depth room's own planes (the near planes swing wider than the far ones while it
pans), 2.4 s, eased, no blur. The glass at the floor line holds the day on one line ("Tuesday's
classes, both attended  +60 XP"), the music ("Lamp left on", then the room's rotation, through
the shell's `BackgroundMusicController`), "Write a line" and, from the wind-down, CLOSE THE DAY.
Today's three stays one line with BOARD.

The wind-down is schedule-aware: 5 PM to 4 AM on the timetable's clock, and never before the
day's last class is over. Monday's starts at 7:00 (his 5:40 to 7:00 lecture), Thursday's at 6:50
(the lab), Tuesday's at 5:00 (classes end at 3:20). The board's CLOSE THE DAY rail follows the
same rule on class days.

The room is the night painting it was made as at every hour: the runtime daylight (a sky keyed into
the window, a daylight grade) was removed, so an afternoon walk still ends at the painted moon.

## The story

The week of Oct 5 is played forward through the engine as if the class day shipped on Monday:
every XP figure is what the build pays. Inferred: which classes he marks and when (named per
frame); E7 gives him the archive room style. Music in renders is the real rotation with playback
bypassed (no audio device): the log shows Lamp left on starting from the press, with his saved
music setting still off.

## Frames

| Frame | When | What it shows |
|---|---|---|
| E1a | Tue 15:35 | TUESDAY, DONE. held for a tap (the board slice's day tier) |
| E1b | +180 ms after the tap | Going back: the words gone, the dim lifting on the kept framing |
| E1c to E1e | +0.8, 1.4, 1.9 s | The walk: from the celebration's framing past the desk to the window; the glass arrives in the last 45% |
| E1f | Tue 15:36 | Settled: the window's painted night and moon, the armchair, the lamp; the day on one line, MUSIC Lamp left on, Write a line; no CLOSE THE DAY before 5 PM |
| E2a | Tue 20:30 | The evening, music off (his saved setting): the painting's own night and moon, CLOSE THE DAY in the glass |
| E2b | Tue 20:30 | After one press: Lamp left on playing for tonight (pause, still levels); his setting untouched |
| E2c | Tue 20:30 | CLOSE THE DAY from the glass opens the real night ledger |
| E3 | Tue 20:31 | Write a line: a fresh journal page stamped with today |
| E4a | Mon 19:15 | The wind-down began at 7:00 with his lecture, three classes unmarked: the card leads with the 5:40 lecture, I WAS THERE and the shortcut exactly as during the day; the music waits; CLOSE THE DAY is there |
| E4b | Mon 19:15 | MONDAY, DONE. played where the camera already stands (no swing back to the desk) |
| E4c | Mon 19:16 | Monday's classes, all three attended +85 XP; the music joins |
| E4d | Mon 19:16 | BOARD: the board's CLOSE THE DAY rail is there after the class |
| E5a | Mon 17:45 | In the 5:40 lecture: the class day (I'M HERE), no evening, nothing asks to close the day |
| E5b | Mon 17:45 | BOARD scrolled to its end: no CLOSE THE DAY rail mid-class (the footer's manual CLOSE DAY door is the board's all-day path) |
| E6a | Thu 18:55 | The lab ended 6:50 and the wind-down began with it: the lab leads the glass |
| E6b | Thu 18:56 | After THURSDAY, DONE., the existing rank-up beat (the lab's CRAFT crossed a rank) |
| E6c | Thu 18:56 | Thursday's classes, all three attended +90 XP, the window's painted night |
| E7 | Tue 20:30 | The archive room: the plate held still behind the same evening glass |
| E8a, E8b | Tue 15:35, 15:36 | Reduce Motion: no walk; the desk still fades into the evening still |
| E9a | Tue 20:30 | 130% text: the day line may wrap rather than shrink; nothing clips |
| E9b | Mon 19:15 | 130% text with three unmarked: the tallest evening glass |

## Not shown here

flutter_tester renders are silent: the music fade-in, the glass and parchment contacts and the
haptics need his phone. The walk's feel (2.4 s, eased) needs his eye on a device.
