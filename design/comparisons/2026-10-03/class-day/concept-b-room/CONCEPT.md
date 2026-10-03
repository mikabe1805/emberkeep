# Concept B: In the room (revised)

Room-first, warmer execution of the class-day loop. Rendered 2026-10-03 in the real booted
`LifeRpgApp` (flutter_tester, 393 x 852 pt at 3x, 59/34 pt safe areas, iOS behavior, real dock,
real night ledger, real level-up) on Mika's Fall 2026 timetable imported through the app's own
importer. Sheet: `sheet.png`. Frame list: `frames.json`. 26 frames.

## The idea

On a class day Room of Days opens on the room, large. Today's classes lie in front of it on one
pane of restrained glass whose top edge sits on the floor line, so the lamp, the chair and the desk
stand on the boards behind it. The class that just ended is foremost with one gold "I was there".
The press plays a full-screen moment built the way the app's "YOU DID IT." is built: the camera
eases back until the whole lamp and desk are in frame, the bulb brightens and its light lands on
the desk, the Quest ring closes on that lit patch, a declarative headline slams in ("YOU WERE
THERE."), and a numeral in the level-up's diamond says how many of this course's meetings he has
been to. XP threads into the level rail, the stat lands, the run shows, and the line names what is
next. The day's last class gets "TUESDAY, DONE."; the week's last gets "THAT'S THE WEEK." with the
week filling and embers. After the last class the camera walks from the desk to the window and the
armchair: the hour is in the glass, the lamp's music is a brass plate on the lamp, the day's record
lies on the floor glass, and Today's three and the board stay one tap away. At night the ledger
names the classes and tomorrow's first one.

## Revision (2026-10-03, after the critique)

What changed, in the critic's order, and where I departed from a fix.

1. **Celebration rebuilt on the level-up's grammar, tiers structurally different**
   (`kept_celebration.dart`). Walnut radial dim (centred between the lamp and the desk, plus a
   vertical night under the desk line so the words never sit on the chair), a 420 pt halo centred
   on the lamp, Fraunces 44 w700 headline on `Motion.slam` (elasticOut) at 140 to 770 ms, the
   numeral in the 104 pt diamond on elasticOut at 260 to 900 ms. "CLASS ATTENDED" is gone.
   Headlines: "YOU WERE THERE." (class), "THAT ONE TOO." (quick), "TUESDAY, DONE." (day),
   "THAT'S THE WEEK." (week). Tiers now differ in structure: class = numeral, name, XP into the
   rail, one stat, run, what is next, auto-return at 3.2 s; day adds the day's rows, the +10, the
   day total, 34 honey motes from the desk and `Haptics.flourish`, held; week swaps the rows for
   the week strip filling one diamond every 45 ms and adds the 46-ember storm, held; quick plays the
   class timeline at 1.5x with a smaller numeral and is back at 1.4 s. "BACK TO THE ROOM" became the
   level-up's own "onward →".
   *Adjusted:* the label under the numeral reads "YOUR 9TH LECTURE THIS TERM" (and "YOUR FIRST
   LECTURE ON RECORD" for a first), with the course name in EB Garamond 30 right below it; the
   critic's "COMPUTER ARCHITECTURE · YOUR 9TH LECTURE" would print the name twice. The diamond is lit
   by the lamp (upper-left gradient) and has no glow of its own: one light field.
2. **The room answers and travels** (`room_stage.dart`). Shots are now real camera positions on the
   registered plates (`RoomShot`), with plane separation through the room's own parallax, so near
   planes move more than far ones. On a mark the camera eases back (0 to 420 ms) from the page's
   framing to one with the whole lamp and the whole desk top; the bulb opens to 0.9 at 380 ms and
   settles to 0.58, and a flat pool of its light lands on the desk where the ring settles (above the
   chair's back, not over it). After the last class the same camera walks (1.1 s, eased, near
   planes swinging wider mid-pan) to the window and the armchair (F3c, F4); music moves it closer
   in (F5). **The window shows the hour:** the base plate's night glass is keyed out at runtime and
   a painted sky sits behind it (morning, midday, afternoon, dusk); after dark it is the painting's
   own moon. No plate is cut: the same base raster is drawn again through a colour key inside the
   glass only, on the far plane. Class-day shots keep a strip of window at the left edge.
   Measured room-region mean RGB: F1 11:52 = 88/68/54, F4 15:36 = 101/76/55, F5 20:30 = 63/42/28;
   the window strip reads 153/147/147 at noon and 33/33/41 at 20:30.
   *Adjusted:* the mark's move is a pull back, not a push in, because "the whole lamp and the desk
   top in frame" needs a wider shot than the page's.
3. **The slip is registered to the room** (`class_slip.dart`, the page's layout delegate). Option
   two: restrained glass (backdrop blur sigma 18, walnut tint 0.70 at the top to 0.94 at the
   bottom), the lamp's falloff across it from its side, a lit top lip, faceted top corners only, and
   no drop shadow, ledge or bottom edge: the brass hairline fades out down the sides and the pane
   dissolves into the floor's shadow. Its top edge sits on the painting's floor line, and the
   camera is solved from the glass's height, so a short glass gives a larger room and the furniture
   always stands on the boards behind it. The after-class record uses the same glass.
   *Rejected:* option one (rotateX onto the desk plane). The desk top is about 10 px deep in the
   painting; a slip seated there is unreadable at phone size.
4. **Numbers.** Day and week tiers show the day's total as the hero (+64 XP, counting up from the
   +27 already earned) with "TUESDAY'S CLASSES · +37 THIS MARK" small. "LECTURE n OF m" is gone; the
   numeral is his own per-course count (attended only, so it only grows). F8 is played forward
   through the model itself (42 marks from Oct 6, Wednesday Oct 28 left neutral): MIND 116 → 332,
   CRAFT 94 → 136, run 30, level 19 at 887 / 915 before Friday's last class, which crosses into
   level 20 with no inferred XP added. The slip header says "1 ATTENDED". The course code left the
   meta line. The next class is named by day ("MONDAY 8:30", "TOMORROW 8:30"). The page's words go
   to opacity 0 while the real LevelUpOverlay is up (F8b).
5. **The evening is a place** (`in_the_room_page.dart`). The music control is a small brass plate
   with a MUSIC eyebrow fixed by a collar to the lamp's own pole, lit from the shade. Music on: the
   camera moves into the corner, the record folds to one line, it and the dock step back to 40%,
   and the room owns the frame (F5). The three icon doors became one text line, "Write a line ·
   The Steward", with the Steward only when an evening scene is waiting; "Stay a while" is gone.
   Today's three stays as a one-line ring row above BOARD in every state.
   *Adjusted:* the plate is on the pole, not the base: in the corner shot the lamp's base sits
   behind the armchair's front leg.
6. **No-class users** (F0). The card has "NOT NOW" (folds to one muted line, "Add your classes ›",
   under Today's three) and "I'M NOT IN CLASSES" (hides it for good and brings back today's
   board-first Quests tab). Only first sight is rendered; the other two states are the current
   board.
7. **Copy.** No room-as-narrator lines: F7b is "Discrete Structures II ended at 3:20 / Went? Mark it
   for +37 XP and +6 MIND." with "Open Room of Days"; F7a's counted state is "+37 XP COUNTED ·
   +6 MIND / OPEN ROOM OF DAYS FOR THE MOMENT" (the XP lands at the tap; nothing waits on opening).
   The closing line is generated from what is actually next and changes shape across his week:
   Mon "Tomorrow starts late: Computer Architecture at 10:20." Tue "Nothing else until Wednesday's
   8:30 lab." Wed "Thursday is the long one: three classes, lab until 6:50." Thu "Friday ends late:
   Discrete Structures II at 5:55." Fri "Free until Monday at 8:30."
8. **Missing states rendered:** M1 (Tue 8:05), Q1/Q2 (Thu 3:22 chain before the lab), U1 (undo),
   C1 (his real comeback), S1 (Saturday), L1 (large text), R1 (Reduce Motion), plus F3c (the camera
   walk). The full-screen departure is now in Departures.

Also new, not asked for:
- **Comeback x1.5.** His real first mark after a week away (C1) started a new run, which pays the
  day-one streak rate. Quests pay `GameState.comebackBonus` (x1.5) in exactly that case, so a class
  now does too: +26 XP instead of +17, captioned "COMEBACK ×1.5", with "A NEW RUN STARTS TODAY ·
  BEST 19". Coming back never pays less.
- **When a class can be marked:** from ten minutes before it ends until the day ends. Earlier in
  the meeting the row says "in session until 11:40" with no control, so the app never asks for the
  phone mid-lecture and "I was there" is never said in the present tense.
- **The six stats stay in the first frame,** as a quiet second HUD line.

## The journey, frame by frame

| Frame | When | What he sees | Why |
|---|---|---|---|
| M1 | Tue 8:05 | The room at the desk, morning in a strip of window. Glass: TUESDAY · 2 CLASSES, Computer Architecture 10:20 AM · HLL 114 · in 2 h 15 min, Discrete Structures II 2:00 PM. No control. Today's three · choose, BOARD. | Before class there is nothing to mark, so nothing gold; the day is laid out and the game is the action. |
| F1 | Tue 11:52 | Glass on the floor line. Computer Architecture, HLL 114 · ended 11:40, the ready ring, one gold I WAS THERE; under a rule, Discrete Structures II 2:00 PM · PHY 001 · in 2 h 8 min, dashed mark. HUD: LV 18, rail, 284 / 870 XP, TUE · OCT 6, six stats. | One owner, one luminous control. |
| F2a | press | Plate sinks 3 pt, top lip into shadow, the ring catches a warm halo. | Acknowledged on contact. |
| F2b | +300 ms | Camera most of the way back to the whole lamp and desk, bulb near full, the ring arriving on the lit desk, YOU WERE THERE. mid-slam, the numeral rising. | The room's own light answers; level-up grammar. |
| F2c | +1.2 s | 9 in the diamond, YOUR 9TH LECTURE THIS TERM, Computer Architecture & Assembly Language, 10:20 TO 11:40 · HLL 114, +27 XP threaded into the rail (311 / 870), +6 MIND 122, 13 DAYS RUNNING · TODAY COUNTS, "First one down. / Discrete Structures II is at 2:00 PM." | Praise, specificity, accumulation, the concrete game. |
| F2d | Tue 11:53 | 1 ATTENDED. Discrete Structures II foremost, no control. Computer Architecture +27 XP. WEEK ◆◆◆ ◆◇ … 4 ATTENDED. | The record is where the day is; the week fills the plate's space. |
| U1 | Tue 11:53 | The attended row swiped left past 42%: UNDO. | A mis-tap is one swipe, as on Quests. |
| F3a | Tue 15:35 | Discrete Structures II, PHY 001 · ended 3:20, ready. | Lands on exactly the thing to mark. |
| F3b | +2.2 s | TUESDAY, DONE. 14 · YOUR 14TH LECTURE THIS TERM · Discrete Structures II; both rows, +10; +64 XP, +6 MIND 128, rail 348 / 870, TUESDAY'S CLASSES · +37 THIS MARK; 13 DAYS RUNNING · BEST 19; "Nothing else until Wednesday's 8:30 lab."; motes rising from the desk; onward →. | The fullest version, no math at the payoff. |
| F3c | after the tap | The camera mid-walk from the desk toward the window, planes separating. | The room turns to the rest of the day. |
| F4 | Tue 15:36 | Window, afternoon sky, armchair, plant, lamp with MUSIC ▸ Lamp left on. Glass: TUESDAY · BOTH ATTENDED +64 XP, both classes, WEEK … 5 ATTENDED, TOMORROW 8:30 Computer Architecture Lab. Write a line. Today's three. | Something to come back to that is not a chore; tomorrow is on the page. |
| F5 | Tue 20:30 | Night in the window, the moon, the camera closer in. Plate: MUSIC (levels) ❚❚ Lamp left on. One line: Tuesday's classes, both attended +64 XP. Write a line · The Steward. Record, doors, Today's three and dock at 40%. | His "virtual cottage": music on, the room owns the screen. |
| F6 | Tue 22:30 | The real NightFlow: +64 XP, MIND +12, TWO CLASSES ATTENDED (both, with times), NEXT CLASS Computer Architecture Lab, WEDNESDAY · 8:30 AM · EE 103, then Mark tomorrow and CLOSE THE DAY. | The ledger names what he did and what is next. |
| F7a | MOCK | Day Ledger medium with an I WAS THERE App Intent; the counted state below. | Marks without opening the app; the moment plays once on the next open. |
| F7b | MOCK | One after-class notification with I was there and Open Room of Days. | Opt-in, one a day, goes away unanswered. |
| S1 | Sat 11:00 | The corner in daylight. SATURDAY · NO CLASSES / "Your run rests today. No freeze spent." / WEEK … 12 ATTENDED / MONDAY 8:30 Electronics Devices. | The rest rule, said plainly. |
| F0 | Tue 11:52 | YOUR CLASSES card, outlined ADD MY CLASSES, NOT NOW · I'M NOT IN CLASSES. | One calm way in, with exits. |
| X1 | Mon 19:15 | Three rows, each with the Quest's ready ring (48 pt target), and I WENT TO ALL THREE. | His Extra Credit idea as the shortcut. |
| X2 | +2.2 s | MONDAY, DONE. 3 · THREE FOR THREE, three rows and +10, +91 XP, +18 MIND 134, 13 DAYS RUNNING · WEEKEND RESTED, "Tomorrow starts late: Computer Architecture at 10:20." | One celebration for several marks. |
| Q1 | Thu 15:22 | Electronics Devices (ended 9:50) and Discrete Structures II (ended 3:20) with rings, the lab at 3:50 in 28 min, I WENT TO BOTH. | The real Thursday chain. |
| Q2 | +0.9 s | After Discrete's own moment, the morning lecture within 15 s: THAT ONE TOO. 11 · Electronics Devices, +27 XP, +6 MIND 128, "The lab is at 3:50, in EE 209." | The quick tier: still a real response, never a checkbox, never slow. |
| C1 | Tue 11:52 | His real state (away since Sep 28, nothing on record): YOU WERE THERE. 1 · YOUR FIRST LECTURE ON RECORD, +26 XP, COMEBACK ×1.5, A NEW RUN STARTS TODAY · BEST 19. | A comeback that reads as a start, never a loss. |
| F8a | Fri Oct 30 | THAT'S THE WEEK. 25 · Discrete Structures II, the week strip (Wednesday two hollow outlines), 10 ATTENDED, +80 XP, +6 MIND 332, LEVEL 20 READY, FRIDAY'S CLASSES · +45 THIS MARK, 30 DAYS RUNNING · BEST 30, "Free until Monday at 8:30.", embers. | Weeks of building, visible. |
| F8b | Fri Oct 30 | The real LevelUpOverlay: LEVEL UP / YOU DID IT. / 20 / NEXT · +12 BODY → Mighty. Nothing reads through behind it. | The real level-up chains after a mark. |
| L1 | text 130% | The glass grows, the camera eases in, the class name wraps, nothing clips. | Large text holds. |
| R1 | Reduce Motion, 300 ms | Everything already landed: no camera travel, no slam, no particles. | Reduce Motion honoured. |

## What counts and what it pays

- **A class can be marked from ten minutes before it ends,** until the day ends. Upcoming classes,
  and the first part of a class in session, have no control. Cancelled occurrences never appear.
  Each mark is its own record (proposed key `room_of_days_class_record_v1`), never a Quest: no
  `history`, `totalCompletions`, Quest titles, loot, crit or Glimmers. It is deterministic, which is
  what lets a widget or notification mark it safely.
- **XP per class = 15 x the streak multiplier x the MIND bend,** rounded, with the daily soft caps
  (`streakMultFor`, `intXpMult`, `dailyXpSoft/Hard`): the base, multiplier and bend a
  difficulty-4 Quest uses. Tue Oct 6 (run 13, x1.630; MIND 116, x1.087) = **27 XP**, next to his
  Quests' +22 to +26. At a 30-day run with MIND over 200 it is 35.
- **Comeback:** when the mark starts a new run after a gap no freeze covers, x1.5, as Quests get
  (`GameState.comebackBonus`). His real first mark: 26 XP.
- **Stat: +6 per class** (a difficulty-4 Quest's 4 x 1.5). Lectures feed MIND, labs CRAFT.
- **Day bonus: +10** when every class on that day's timetable is marked (Extra Credit's +10).
- **Scale:** Tuesday 2 x 27 + 10 = 64. Monday 91. A 12-class week at run 13 = 12 x 27 + 5 x 10 =
  **374 XP, 43% of a level** at L18. Simulated Oct 6 to Oct 30 (42 marks): about 1,470 XP, so
  classes alone take him from 284 / 870 at L18 to level 20 on Oct 30.
- **His count per course** is the number of that course's meetings (of that kind) he has marked.
  It never shows a total and never goes down.
- **Level-ups:** a mark calls `applyLevelUps()` and chains the real LevelUpOverlay after the class
  moment (F8b). This fixes the Extra Credit caveat where XP was added silently.

## The streak rule (proposal: please say yes or no)

> **A day counts for the streak when you mark at least one class or finish at least one Quest. A
> day with no classes on your timetable rests the streak and spends no freeze. A class day with
> nothing marked is treated like any day with nothing finished: a freeze holds it if you have one.**

The halves are separate choices: (1) marking a class keeps the run alive, (2) class-free days
(weekends, breaks) rest it for free. X2 shows (2) ("WEEKEND RESTED"), S1 says it on the day
("Your run rests today. No freeze spent."), C1 shows the honest restart. If the answer is no, the
run line leaves the celebration and the week strip carries continuity alone.

## What never punishes

- An unmarked class stays a plain row with a dashed mark, forever. No missed state, no red, and no
  count of unmarked classes anywhere: headers say "1 ATTENDED", the week counts "10 ATTENDED",
  hollow diamonds are only outlines.
- After 9 PM the evening never waits on a mark; unmarked classes sit in the record as quiet rows.
- The notification is opt-in, one a day, only while something is unmarked, and expires silently.
- Rest earns no XP; "Write a line" and the Steward pay nothing.
- A new run is said as a start ("A NEW RUN STARTS TODAY · BEST 19") and pays the comeback rate.
- Copy has no em dashes, no "not this, but this", and none of failed, missed, lost, broke, skipped.
- The fireplace never answers progress and is outside every shot. The lamp answers.

## Sound, haptics and timings (intended; renders are silent)

| Time | Visual | Sound / haptic |
|---|---|---|
| contact | Plate sinks 3 pt, ring halo | selectionClick (Pressable), inside 90 ms |
| 0 ms (release) | Celebration mounts over the room | `completion-composite.wav`; music ducks as for a Quest |
| 58 ms | | `Haptics.light` |
| 0 to 160 ms | The celebration's room fades over the page | |
| 0 to 420 ms | Camera eases back to the whole lamp and desk; near planes travel most | |
| 60 to 420 ms | Walnut dim falls outside the lamp's reach and under the desk line | |
| 0 to 380 ms, settle by 1.1 s | Bulb opens to 0.9, settles to 0.58; 420 pt halo; light pool on the desk | |
| 100 to 620 ms | Ring arrives on the desk (easeOutBack); closes at 140 ms (its own 460 ms) | |
| 140 to 770 ms | Headline slams (elasticOut, 0.58 to 1.0 scale) | |
| 260 to 900 ms | Numeral diamond slams (elasticOut, 0.4 to 1.0) | |
| 300 to 760 ms | Course name rises 16 pt | |
| 520 to 1170 ms | XP counts up, rail fills (easeInQuad, `Motion.barFill`); thread 520 to 900 ms, diamond at its head 3 to 8 pt | |
| 640 ms | Stat chip lands | `stat_2.wav` (MIND) or `stat_3.wav` (CRAFT) |
| 780 ms | Run line, when this mark counts the day | `streak.wav` |
| 900 to 1250 ms | What is next | |
| 1300 to 1500 ms | onward → | class tier returns at 3.2 s |
| Day: 700 ms on | Rows every 85 ms; +10 at 1000 ms; 34 motes from the desk from 1180 ms | `Haptics.flourish` at 1180 ms |
| Week: 1150 ms on | Week strip fills one diamond every 45 ms; 46 embers from the numeral | `Haptics.flourish` at 1180 ms |
| Day/week: 1500 to 2200 ms | Closing line, onward →; held until tapped | |
| Level crossed | After the tap, the real LevelUpOverlay | `levelup.wav`, `Haptics.big` |
| After the day's last class | Camera walks to the corner, 1.1 s eased; record and plate arrive in the last 45% | none (quiet on purpose) |
| Undo | Row swiped past 42% | `boing.wav`, light impact |

Quick tier: the class timeline at 1.5x, back in the room at 1.4 s. Reduce Motion: every value lands
at once, no camera travel, no slam, no particles; sound stays; haptics soften through
`Haptics.reduceMotion`.

## Reused vs new

**Reused, real code:** `LifeRpgApp` and its dock; the `QuestDepthRoom` planes and their parallax
(never re-cut; fire parked and out of frame), the base plate drawn a second time through a colour
key for the window; `GoldSurface`, `GoldLabel`, `Pressable`; the Quest ring `_CheckRing` (through
the 35-line public `QuestCheckRing`); `Palette`, `Type`, `Motion.slam`, `Stat`, `facetedDecoration`,
`LedgerType`; the level-up's dim, halo and diamond recipe; the Quest board's undo (`Dismissible`,
endToStart, 0.42); the real `NightFlow` ledger (class section and next class through a small hook);
the real `LevelUpOverlay`; `GameState` formulas (`streakMultFor`, `intXpMult`, `comebackBonus`,
`xpNeeded`, `applyLevelUps`, soft caps); `AcademicSchedule`, the .ics importer and his fixture;
`completion-composite.wav`, `stat_2/3.wav`, `streak.wav`, `boing.wav`, `levelup.wav`;
`Haptics.light`, `Haptics.flourish`.

**New:** the class record, rules, per-course count, comeback and undo (`class_day_model.dart`); the
camera shots, window sky key, lamp bloom and desk light (`room_stage.dart`); the glass and rows
(`class_slip.dart`); the four-tier celebration (`kept_celebration.dart`); the page with its
floor-line layout, camera walk, lamp plate, record and quiet line (`in_the_room_page.dart`); widget
and notification mocks (`reach_mocks.dart`); the ledger hook (`class_ledger_hook.dart`). Not built:
the Swift App Intent, the App Group queue, the notification, the save key and cloud backup.

## Build cost

Rough, one agent on this repo: class record, rules, save key, backup, about 1.5 days; the Quests
tab's class-day first frame (camera shots, window key, glass, floor-line layout, fold to the board
on scroll), 3 days; the celebration, 1.5 days; the corner, plate and music hand-off, 1 day; ledger
section and a `classTitles` trace line, half a day; widget App Intent with App Group queue and
replay, 2 to 3 days with Codemagic-only signing; the notification, 1 day. Extra Credit in
goals-everyday-review folds in (its +10 is the day bonus); port by hand, never merge that tree.

## Risks and open questions

1. **The lamp plate is code-drawn.** It is sized to the lamp, lit from the shade and collared to
   the pole, but it is still a drawn brass rectangle on a painting. A painted dimmer plate on the
   furniture plane (generated art on the same camera) would make it belong.
2. **Stat and level weight.** At +6 per class, MIND goes 116 → 332 in four weeks and the six-stat
   build tilts hard toward MIND; classes alone move him almost two levels a month. If that cheapens
   levels or the build, the first knob is +3 per class (MIND 116 → 224 by Oct 30), then base 12.
3. **Daylight is a key over a night painting.** The lamp and candle stay lit at noon; the strip of
   window, the light panel and the grade carry the hour. A day plate on the same camera would make
   it literal.
4. **The key's edges.** Softened by a 1 px blur in image space; at the closest shot the mullions
   are slightly soft and the jambs keep a moonlit blue.
5. **Motion feel.** He wrote today that page transitions with "the blur and rush effect" feel wrong
   ("it feels weird and inappropriate mood wise"). The camera walk is 1.1 s, eased, with no blur,
   and the celebration's move is 420 ms; both need his eye on a device.
6. **Glass cost.** A backdrop blur sits on the class-day first frame; measure on his phone.
7. **The streak rule needs his yes** before engine code (AGENTS.md promises "paused"; the engine
   resets).
8. **Self-report and two writers.** Attendance is never verified, by design. Widget and
   notification marks queue in the App Group and apply on open; the class record and the whole-save
   undo must not fight.
9. **Not rendered:** a class in session, a cancelled class, the folded "Add your classes ›" line,
   the music start and stop, sound and haptics on a device.

## Departures from the brief, the app or the conventions

- **Every mark is full-screen,** against AGENTS.md's "Full-screen celebrations rationed to
  milestones only", because his 2026-10-03 direction asks for a "well done!" screen on each mark.
  The tiers keep the tenth from feeling like the first.
- The room bleeds under the status bar on class days (the app keeps a plain band today).
- The HUD is two quiet lines over the room (level line and the six stats) instead of the card.
- Classes pay no Glimmers. A comeback mark pays the Quests' x1.5.
- Class copy says "attended"; "kept" stays the app's word for Quests and the day.
- The window's sky for the hour is a runtime colour key on the base plate (no new art, no re-cut).
- The lamp plate's title "Lamp left on" is the theme's real title.

## Files

Working copy `C:/tmp/cdj/b-room` (git archive of c0a041a):

- New: `lib/design_studies/class_day/b_room/class_day_model.dart`, `room_stage.dart`,
  `class_slip.dart`, `kept_celebration.dart`, `in_the_room_page.dart`, `reach_mocks.dart`,
  `class_ledger_hook.dart`
- New: `test/design_renders/class_day_b_room_test.dart`, `test/design_renders/b_room_sheet.py`
- Touched: `lib/widgets/quest_card.dart` (appended the public `QuestCheckRing` wrapper),
  `lib/widgets/routine_flows.dart` (hook import; CLASSES ATTENDED and NEXT CLASS in
  `_ledgerRecap`; `_LedgerClassLine`; the threads section hidden on a class-only day)
- Copied unchanged: the class-day harness files into `test/design_renders/`

Nothing under the class-day-journey worktree's `lib/` was edited. Its only change is this folder.

Reproduce:

```
cd C:/tmp/cdj/b-room
flutter test --dart-define=CLASS_DAY_RENDERS=true test/design_renders/class_day_b_room_test.dart
python test/design_renders/b_room_sheet.py
```

`--dart-define=B_ROOM_ONLY=tue,mon,thu,comeback,sat,empty,reduce,reach,week` renders a subset; a
full run clears this folder's PNGs first. Renders are deterministic.

## Verified, inferred, remaining

- **Verified (renders):** all 26 frames in the real app with the real dock, ledger and level-up;
  no layout overflow from the concept in the final run; numbers from the engine's own formulas;
  F8 played forward through the model.
- **Inferred:** the in-use story assumes he has marked classes since the term began, leaving three
  gaps neutral (Wed Sep 16; Fri Sep 25 Computer Architecture; Fri Oct 2 Discrete), which is what
  makes Oct 6 his 9th Computer Architecture lecture; the run of 12 on Oct 5 is his save's. C1 is his
  real state with an empty record. Whether the timetable is imported and the widget is on his home
  screen is his "yes and yes".
- **Remaining gate:** his yes or no on the streak rule; device feel (camera walk, celebration
  timing, sound, haptics, glass blur); whether he opens the app after class once this ships.
