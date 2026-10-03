# Concept A · On the board (revised)

Class-day journey study for Room of Days, 2026-10-03. Board-first, game-forward.
Storyboard: `sheet.png`. Frames: the PNGs here, listed with times in `frames.json`. Run notes and
reward math per frame: `render-log.txt`. Source: `source/` (study code, the render test, the sheet
script, and `lib-changes.diff` for the three real files it touches). The first version's frames and
notes are kept outside the worktree at `C:/tmp/cdj/a-board-v1-frames/` for comparison.

## The idea in three sentences

On a class day the Quests board changes its mind about the day: the HUD drops to level and stats,
today's classes become the first card, each with its time and state, and Today's three steps down
under them as one quiet line. Marking a class plays a full-screen moment in the level-up's own
dialect (the same walnut dim with the room faintly behind, no blur): CLASS KEPT, the course as the
hero, its ring closing, the XP counting, and one true line that only counts up ("Your fourth class
this week.", weeks later "Your twelfth Computer Architecture lecture this term."); the day's last
class becomes "Two for two." and the week's last "Twelve for twelve.". After the last class the
thread closes into a finished hero that offers the rest of the day (music, a line in the Journal),
the evening folds the chores away, and the night ledger names the classes kept and tomorrow's.

What it answers, in his words: "make it still useful for me" as "a student who just goes to class
then relaxes afterwards", and the newest direction, "open the app at whatever point throughout
your day and mark if you attended your class and then it gives you like a "well done!" screen and
awards xp and maybe streak?". The full screen is the one he asked to keep: "i really liked it in
the early builds of the app when level ups filled the entire screen with the "you did it!" screen.
it felt very rewarding/encouraging".

## The journey, frame by frame

All frames are the real app (this concept wired into a copy of Build 49's `lib/`) at 393 x 852 pt,
3x, on his real Fall 2026 timetable as the app's own importer reads it. Tuesday Oct 6: 14:332:331
Computer Architecture & Assembly Language 10:20-11:40 HLL 114, 01:198:206 Introduction to Discrete
Structures II 2:00-3:20 PHY 001. Wednesday: Computer Architecture Lab 8:30-11:30, Linear Systems &
Signals 2:00-3:20. Scenario: he started marking classes on Monday Oct 5 (all three kept), so
Tuesday's first mark is his fourth of the week and day 13 of the streak.

| Frame | When | What he sees | Why it is built this way |
|---|---|---|---|
| F1 | Tue 11:52 | Room, then the HUD as level and six stats only (no Today's three rings, no "6 open · choose"). Then TODAY'S CLASSES: Computer Architecture & Assembly Language, open ring, "Ended at 11:40 · HLL 114", "+26 XP · +3 MIND", the gold plate I WAS THERE; a thread down to Discrete Structures II, dashed ring, "2:00 to 3:20 · PHY 001", UPCOMING. Under the card, one line: "Today's three · choose ›" with FOCUS and ADD. Quests follow as compact rows | One owner (the class card), one luminous control (the plate), no second "today" tally above it. The Quest hero gives up MARK COMPLETE while classes lead |
| F2a | +0 ms | The plate drops 3 pt and loses its under-shadow; selection haptic | The press is acknowledged in the first frame (the app's 100 ms rule) |
| F2b | 300 ms | Full screen in the level-up's dim (0.93 / 0.95 / 0.97, no blur, the board faint behind). CLASS KEPT; "Computer Architecture" slamming in, "& Assembly Language" under it; the ring at 104 pt mostly closed, no check yet | The course is the hero in the slot "YOU DID IT." holds. The check now lands after the arc, so no half-drawn chevron |
| F2b2 | 850 ms | Beat 1 landing: the check in, the XP thread dropping from the ring into "+21 XP" as it counts, "Your fourth class this week." | The board's real reward language (ring, thread, number) at celebration scale |
| F2c | 1.5 s, settled | Beat 2: the thread has faded (no pendant). +3 MIND chip · 13-DAY STREAK · today counts; the week's rings with Tuesday's first just closed. No level bar (36% into the level), no NEXT, no onward | Spare like the level-up: label, hero, medallion, number, one line, then one compact row. It goes back to the board on its own at 2.4 s |
| F2d | Tue 11:53 | Back on the board (the overlay left by itself, verified in the run): "1 KEPT"; Computer Architecture as a small kept row (+26 XP); "NEXT · 2:00 PM" in quiet text, Discrete Structures II, "Until 3:20 · PHY 001". No plate | The class reads as kept and the next one leads. No two-hour timer |
| F2d2 | Tue 13:48 | The same card, but the label is "STARTS IN 12 MIN" in honey | A countdown only inside the last fifteen minutes |
| F2e | Tue 14:40 | In Discrete: "On now · 40 min left · PHY 001", a 2.5 pt honey arc on the ring's inner track at half, plate I'M HERE | Present tense while he is in the room; the elapsed arc is legible at phone size |
| F3a | Tue 15:35 | Fifteen minutes after Discrete: "Ended at 3:20 · PHY 001", plate I WAS THERE | |
| F3 | 15:35, 1.9 s | CLASSES DONE FOR TODAY · "Two for two." · both rings joined, names and times · "+37 XP" (the +27 counted, then +10 FULL DAY rolled into it) · "+63 XP from class today" · FULL DAY and MIND chips · the week strip, 5 KEPT THIS WEEK · "That was every class on Tuesday. / The rest of the day is yours." · onward | The headline and the number agree. Honey motes rose from the rings at the close and are gone before the settle |
| F4 | Tue 15:36 | The finished hero: "2 KEPT", "Two for two.", "The rest of the day is yours.", both classes with times, "+63 XP · +6 MIND · FROM CLASS TODAY", two doors (Put on music · ♪ Lamp left on, lit; Write a line · JOURNAL), "NEXT Wed 8:30 AM · Computer Architecture Lab". Under it the one-line Today's three. No Quest plate | The celebration's promise is true a minute later: the rest of the day is offered, not a chore |
| F5 | Tue 20:30 | The room gets 64 pt more. One card: TUE EVENING · 2 KEPT, "The rest of tonight is yours.", "You kept Computer Architecture and Discrete Structures II today.", three doors (music lit, Journal, Close the day), the week's rings, 5 KEPT THIS WEEK, NEXT · WED 8:30 AM. Then one row: "Quests · 6 open ⌄". No Energy Weather, no chore list | Something to come back to that is not a chore: the room, his music, a line, the week filling |
| F5b | Tue 20:30 | The Quests row tapped open and scrolled: the side quests as calm rows, then the freeze line ("5 READY · 13 DAY STREAK") | The chores are one tap away, never gone |
| F6 | Tue 22:30 | The real night ledger: WHAT MOVED +63 XP, MIND +6, TWO CLASSES KEPT with each class and time, then TOMORROW · WED with Computer Architecture Lab 8:30 AM and Linear Systems 2:00 PM on dashed rings, directly heading the MARK TOMORROW tray (1 2 3, Choose one). No "+0 XP / NO THREADS FINISHED" | The book names what he did, and tomorrow's fixed lines fill the old empty middle |
| F9a | Tue 20:30, partial | He kept Computer Architecture and never marked Discrete. TUE EVENING · 1 KEPT, "You kept Computer Architecture today.", one quiet line "Discrete Structures II · 2:00 to 3:20" whose ring still marks it, the doors, the strip with Tuesday as one closed ring and one 4 pt dim dot, 4 KEPT THIS WEEK | Never "1 OF 2". Nothing red, no label, no count of what was not marked |
| F9b | Tue 22:30, partial | ONE CLASS KEPT: Computer Architecture 10:20 AM. Tomorrow's classes as above | The ledger lists only what he kept |
| F9c | Fri Oct 9 18:56, partial week | Friday's last class (Discrete 5:55) in a week with Tuesday's Discrete unmarked: "Two for two.", +37 XP, "+61 XP from class today", the strip with Tuesday's dot, 11 KEPT THIS WEEK | A partial week still gets its full days; no hole between medals |
| F9d | Fri 20:30, partial week | FRI EVENING · 2 KEPT, the strip, 11 KEPT THIS WEEK | |
| F7a | MOCK, Tue 11:52 | Home-screen Day Ledger widget (systemMedium, 338 x 158 pt): TUE · CLASSES, the open ring, "Computer Architecture / Ended at 11:40 · HLL 114", NEXT 2:00 PM Discrete Structures II, an interactive I WAS THERE button | He marks without opening the app |
| F7b | MOCK, after the tap | "1 KEPT", "Kept at 11:53 · +26 XP", a quiet OPEN button | OPEN launches the app into the waiting celebration. No "to collect" |
| F7c | MOCK, Tue 3:25 PM | Nothing marked all day: "Two classes over", "Computer Architecture and Discrete Structures II", NEXT WED 8:30 AM Computer Architecture Lab, one button I WENT TO BOTH | The after-class state, with his Extra Credit shortcut on the home screen |
| F0 | Tue 11:52, no timetable | The board exactly as today (HUD with Today's three, Read ten pages with MARK COMPLETE), then under the Quest hero one row: dashed ring, "Add your classes ›", "Each class you go to can count here, with XP.", and a visible "Not in school" | One calm way in that never takes the prime slot; weekdays only; "Not in school" puts it away for good. It hands off to the separate import track |
| F8a | Mon 19:05 | Right after the 5:40 lecture, nothing marked: three rows (Electronics Devices, Linear Systems & Signals at 3:20 in SEC 111 and at 7:00 in SEC 204), each with an open ring that marks that class alone and its +26 XP; "+80 XP +10 FULL DAY"; one plate I WENT TO ALL THREE | His Extra Credit idea as the main action; a partial day is one ring tap, with no extra text buttons |
| F8b | Mon 19:05, 1.9 s | "Three for three." Three rings close 150 ms apart; +80 rolls to +90 with FULL DAY; +9 MIND; 13-DAY STREAK · today counts; 3 KEPT THIS WEEK; "That was every class on Monday. / The evening is yours." | One celebration for the whole day |
| F8c | Fri Nov 13 11:52 (projection) | Weeks in, an ordinary mark: CLASS KEPT · Computer Architecture · +35 XP · "Your twelfth Computer Architecture lecture this term." · +3 MIND · 39-DAY STREAK · today counts · ten of twelve rings closed and this one closing · LEVEL 21, 10 XP TO LEVEL 22 | The single tier does not repeat itself: the count line grows every week, and the bar appears only when a level is near |
| F8d | Fri 18:56, 1.9 s | EVERY CLASS THIS WEEK · "Twelve for twelve." · the medal board (one column per weekday) · LAST OF THE WEEK · FRI 5:55 PM, Discrete Structures II · +35 rolls to +65 with FULL WEEK · "+534 XP from class this week" · LEVEL 22 READY · "Monday to Friday, every one." No "today counts" (the morning lecture lit the day) | The rarest, biggest version |
| F8e | after onward | The real level-up overlay: LEVEL UP, "YOU DID IT.", 22, "11 quests and 24 classes since level 21" | A class that crosses a level gets the real takeover, and the level names what earned it |

## What counts and what it pays

**A kept class** is one tap on a class that has started (on now, or over), any time before that
night's ledger closes (before 4 AM still counts as the day before, `Days.nightKey`). Cancelled
occurrences and office hours never appear. It is its own record (`ClassMark`: occurrence, course,
meeting kind, the class's day, time marked, what it paid), never a Quest completion: it does not
touch Quest history, `totalCompletions`, Today's three or goal progress.

**XP.** A class pays like a Quest of its length: up to 90 minutes, base 15 (a difficulty-4 Quest);
up to 150 minutes, base 20 (difficulty 6); longer, base 25 (difficulty 8, his 3-hour labs). Then
the same multipliers a Quest uses for steadiness: the streak multiplier (x1.0 to x2.0), MIND's XP
bend (x1.0 to x1.15), the comeback x1.5 when the class is his first activity after an uncovered
gap, and the daily soft cap. No crit, loot, dread, custom damp, neglect or same-day decay: a class
is not a dice roll.

**Bonuses, flat:** +10 FULL DAY when every class that met today is kept (his Extra Credit amount,
kept as is), or +30 FULL WEEK on the mark that completes every class of the week (it replaces that
day's +10).

**Stat:** lectures, recitations and seminars feed MIND; labs and studios feed CRAFT. +3 for up to
90 minutes, +4 up to 150, +6 longer. That is half of what the same-XP Quest adds, so MIND keeps
mostly reflecting what he chose to do beyond showing up. Glimmers are XP / 3, as for Quests.

**The count line** (new in this revision) is one sentence chosen from facts that can only grow:
his first class ever on the board; then, once a course has three or more marks this term, "Your
twelfth Computer Architecture lecture this term." (marks grouped by course and meeting kind);
otherwise his place in the week ("Your fourth class this week."). The day tier's closing line says
"Every Tuesday class, three weeks running." only when that is true (every Tuesday class kept for
two or more consecutive weeks); otherwise "That was every class on Tuesday.". None of these ever
names a class he did not mark or compares him with another week.

**His real numbers** (verified in the render log):

| Mark | Math | Pays |
|---|---|---|
| Tue, Computer Architecture (80 min, 12-day streak, MIND 116) | 15 x 1.609 x 1.087 | +26 XP, +3 MIND, +8 Glimmers, lights day 13; 284 to 310 / 870 |
| Tue, Discrete Structures II (80 min, day 13, MIND 119) | 15 x 1.630 x 1.089, + 10 | +27 XP + 10 FULL DAY = +37, +3 MIND; 310 to 347 |
| Tuesday | | +63 XP, +6 MIND |
| Mon, all three at once | 15 x 1.609 x 1.087, then x 1.630 at day 13 (twice), + 10 | +80 + 10 = +90, +9 MIND; 284 to 374 |
| Projection, six weeks in (38-day streak, MIND 212) | 15 x 2.0 x 1.15 | +35 per lecture (+58 per lab); Friday's lecture 960 to 995 / 1005 |
| Projection, the week's last class | 35 + 30 FULL WEEK | +65; 995 to 1060, level 22; +534 XP from class that week |

A full week of his 12 classes (10 lectures, 2 labs) at today's streak pays about 26 x 10 + 43 x 2
+ 4 x 10 + 30 = about 420 XP, roughly half of level 18's 870. Weeks in, at x2.0 and MIND's cap, it
is about 530 a week (534 in the F8 projection), a level every two weeks from classes alone; Quests
stay the faster road on top. If that feels too generous, the one dial is the base (15 to 12 cuts
it by a fifth).

**Level-up:** the class celebration shows the level bar only when the mark crosses a level (LEVEL
22 READY) or lands within 15% of one (10 XP TO LEVEL 22); tapping onward after a crossing hands off
to the real full-screen level-up, whose line now counts classes beside Quests.

## The streak rule (a proposal for a yes or a no)

> A day with at least one kept class counts as a lit streak day, exactly like a day with one
> finished Quest. The first class he marks for a day lights it, and the celebration says "today
> counts"; more marks that day add nothing more to the streak. The day a mark lights is the
> class's own day (the night ledger's day: a mark at 1 AM lights the day he went). An unmarked
> class never subtracts anything: a day with no marks and no Quests is handled exactly as today (a
> freeze holds it, or the streak pauses). A mark only counts for its own day; it cannot be added
> after that night's ledger closes.

Why: on his real weekdays, going to class is the thing he does; with this rule the streak follows
his life and the x1.6 to x2.0 multiplier stops being something only a chore-doer keeps. Weekends
still need a Quest or a freeze. The cost: the Extra Credit evidence card warns against changing
streak state as a disguised completion. This rule is open about it (the class is its own record
and the streak line names it). If the answer is no, classes still pay XP and a stat; the streak
line leaves the celebration and only Quests light a day.

## What never punishes

- Every tally counts up. Headers read "1 KEPT", "2 KEPT", or nothing before the first mark; never
  "0 OF 2" or "1 OF 2". The week reads "5 KEPT THIS WEEK", never "5 OF 12".
- A class that is over and unmarked has no state. In the week strip it is a 4 pt dim dot (it keeps
  its place in the day, nothing more), never a medal-sized empty ring between filled ones; a class
  still to come is the dashed orbit. In the evening card it is one quiet line whose ring still
  marks it, with no label. The ledger lists only classes kept (F9a to F9d show a partial day and
  week).
- No reminders about unmarked classes. The after-class reach (widget, or one notification) is
  opt-in, at most once a day, and only ever offers the mark.
- Marking is self-report, never gated or verified. Proposed, not built in the study: a wrong mark
  can be taken back from the kept row (long-press, "Not this one"), restoring the XP the way Quest
  undo does.
- Copy check on every user-facing string in `source/lib`: no em dashes, none of failed, missed,
  lost, broke or skipped, no "not this, but this".

## Sound, haptics, timing (intended; flutter_tester renders are silent)

Single tier (1.5 s of motion, then it returns on its own at 2.4 s):

| Time | Visual | Sound | Haptic |
|---|---|---|---|
| Press | Plate drops 3 pt, under-shadow gone | none (as MARK COMPLETE) | selectionClick |
| Release, 0 ms | The board's ring starts closing under the takeover | completion-composite.wav (accepted contact, then the detent, 460 ms); music ducks | lightImpact |
| 0-190 ms | The level-up's walnut dim fades in (0.93 / 0.95 / 0.97), no blur | | |
| 20-260 ms | CLASS KEPT | | |
| 80-540 ms | Hero ring closes from 12 o'clock (easeOutCubic); the check lands over the last 38% of the close (easeOutBack) | | |
| 100-680 ms | Course name slams in (elasticOut, 0.58 to 1, the level-up's curve) | | |
| 420-640 ms | XP thread drops from the ring to the number; diamond lands | | |
| 480-900 ms | Number fades in and counts to 26 (easeInQuad from 520) | | |
| 640-900 ms | The count line ("Your fourth class this week.") | | |
| 900 ms | Beat 2: stat chip and streak line rise in (to 1150) | stat_2.wav (MIND, F#) | |
| 900-1100 ms | The thread fades out | | |
| 1000 ms | Week strip in; this ring closes 1080-1400 | streak.wav, only when this mark lit the day | |
| 2400 ms | Back to the board, unless a finger is on the glass (lifting it continues). Any tap before that continues at once | | |

Day and week tiers (1.9 s, wait for a tap): the day's rings close in sequence 150 ms apart;
Haptics.flourish (heavy, medium +80, light +170) as the last one closes; 26 round honey motes (36
for the week) spawn in a band 120 pt above and below the rings 140 ms before that close, rise 30 to
70 pt and are gone 400 to 520 ms later, so the settled frame is clean. 560-1000 ms the class XP
counts; stat note at 1000; 1100-1350 the FULL DAY (or FULL WEEK) chip pulses once while the bonus
rolls into the number, tick_warm and a light haptic as it lands; 1350-1600 "+63 XP from class
today"; streak.wav at 1500 only if this mark lit the day; closing lines and then onward (textMid,
full opacity). These two tiers sit a shade deeper (0.96 / 0.97 / 0.98) because they carry more
lines. levelup.wav stays reserved for levels; no confetti, no new audio files.

Reduced Motion: everything lands at its final value, one light haptic, no motes, no slam; the
single tier still returns at 2.4 s.

## Reached without opening the app (F7, MOCK)

The Day Ledger widget gains an iOS 17 interactive button. Tapping I WAS THERE (or I WENT TO BOTH
after the last class) runs an AppIntent that appends `{occurrenceKey, dayKey, markedAt}` to a
queue in the App Group (`group.com.mikabe.emberkeep`) and reloads the widget into "Kept at 11:53 ·
+26 XP" with an OPEN button. The XP is applied in Dart on the next open through the same mark path,
which then plays the celebration (several queued marks play as one "Two for two." moment); OPEN is
a deep link straight into it. After the night closes the widget moves to tomorrow. Alternative or
companion: one opt-in notification at the end of the day's last class with an "I was there" action
feeding the same queue.

## Reused and new

**Reused, real code:** QuestsPage with its room backdrop and depth planes, HUD, stat chips, day
strip, side-quest disclosure pattern and dock; GoldSurface and GoldLabel (the one plate); Pressable;
the faceted hero-card recipe from QuestCard; WorkingType titles; Sfx (completion composite, stat
notes, streak, tick_warm); Haptics (light, flourish); NightFlow, LedgerSectionTitle and the MARK
TOMORROW tray; LevelUpOverlay; AcademicSchedule (importer, occurrences, courses); Clock and Days;
GameState fields and multipliers.

**Ported:** the class ring is the Quest ring's painter (quest_card.dart `_CheckRingPainter`) with
two class states added (upcoming as a dashed orbit, on now with the elapsed arc on its inner track).

**New:** `ClassBoard` (the class record, the pay rules, the streak lighting by the class's day, the
count line, the weeks-running check), the thread card, the finished hero with the rest-of-day doors,
the evening card, the "Add your classes" row, `ClassKeptOverlay` in three sizes with its own round
motes, the week strip and medal board, the ledger's class lines and tomorrow's lines, the widget
mock in three states.

**Files touched (all in the copy at `C:/tmp/cdj/a-board`, nothing under the worktree's `lib/`):**

- new `lib/design_studies/class_day/a_board/class_board.dart`, `class_ring.dart`,
  `class_thread.dart`, `class_kept_overlay.dart`, `widget_mock.dart`
- `lib/screens/quests.dart`: mounts the class slot under the HUD; while classes lead (active,
  finished or evening) the HUD drops its Today's three row and a compact one-line Today's three
  (with FOCUS and ADD) sits under the class card; the Quest hero gives up its plate; in the class
  evening the room gets 64 pt more, the Quests fold under one "Quests · N open" row and the hearth
  banners (Energy Weather and the rest) step aside; the close-day rail and footer link step aside
  for the evening card; "Add your classes" sits under the Quest hero on weekdays when there is no
  timetable; rebuilds on a mark and on resume; passes the class count to the level-up
- `lib/widgets/routine_flows.dart`: the night ledger's CLASSES KEPT section, tomorrow's classes as
  fixed lines heading the MARK TOMORROW tray, the NO THREADS line hidden on a class day without
  Quests
- `lib/widgets/levelup_overlay.dart`: optional `classesSince` in the evidence line
- new `test/design_renders/class_day_a_board_test.dart`, `test/design_renders/concept_a_sheet.py`

## Build cost and risks

**To build it for real (estimate):** save schema 28 to 29 with a `classMarks` list (with meeting
kind, for the per-course count) and the per-level class count, plus cloud backup and validation; a
`commitClass` in engine.dart that shares commit()'s streak block keyed to `Days.nightKey(now)` (the
study applies it from outside); undo for a mark; a timer for the next class boundary so the board
turns over on its own (and the fifteen-minute countdown appears); JournalTrace and the weekly
chronicle learn classes; port the Extra Credit snapshot into this (its `ExtraCreditEntry` becomes
the "all of today's" shortcut, its +10 becomes FULL DAY). About two to three days of agent work
with tests for board, overlay, model and ledger. The interactive widget is another one to two days
plus signing churn on Codemagic.

**Risks and open questions:**

1. The streak rule needs his yes or no.
2. XP inflation: classes roughly double his weekly XP at today's light use. One dial (the base).
3. Checkbox fatigue: the single tier is now spare, returns on its own at 2.4 s and says a growing
   count each time, but whether the seventh ordinary mark of a week still feels good is a phone
   question for his week-long feel test.
4. First thing that still feels artificial, F1: the starry moon window above a board that knows it
   is 11:52 AM. The Quest room is one authored night painting; a day window would need new
   registered room art (the depth planes are not re-cut here). In the celebrations: the faint board
   ghosting through the dim, the same trade the level-up makes.
5. The morning is not storyboarded: the Open the day ledger still lists only YOUR THREE, so it
   cannot yet say "first class 10:20". The same tomorrow lines from F6 would fit there.
6. Monday's two Linear Systems & Signals lectures are the same course twice; rows tell them apart
   by time and room, the day medallion by time only.
7. The finished hero (F4) and the evening card (F5) are two cards on purpose: Close the day and the
   larger room wait for the wind-down hour (5 PM), so the ledger is not offered at 3:36 PM.
8. Study limits: the class record lives in memory (not saved), sound and haptics are unheard,
   flutter_tester stands Inter in for SF Pro, F7 is a Flutter mock of SwiftUI, and F8c to F8e use a
   projected account (level 21, 38-day streak, MIND 212, every class marked since Oct 5 except
   Thu Oct 22's lab and Wed Oct 28's lecture, 22 classes since level 21 before Friday).

## Verified, inferred, gates, departures

- **Verified (renders, this run):** every frame above; no layout overflows (render-log.txt); the
  single tier left by itself after 2.4 s in all three runs that use it; the reward numbers come
  from the running app's GameState; F8d no longer claims "today counts"; W's `lib/` is untouched.
- **Inferred:** he started marking on Monday Oct 5 (all three kept); the partial day and the F8
  account are scenarios; sound and haptic choices are from code, not heard.
- **Remaining gate:** his yes or no on the streak rule, and a phone test of the takeover's feel.
- **Departures:** "well done!" became CLASS KEPT with the course as the hero and a count line, and
  "Two for two." / "Three for three." / "Twelve for twelve." for the bigger tiers (his wording is
  intent, not copy). The plate stays first person (I WAS THERE, I'M HERE), like his "i also went to
  all my classes"; every state label says KEPT. Stat gains are half a Quest's (default, so MIND
  keeps meaning chosen work). The level-up line now counts classes (a small change to a real
  overlay he liked; inferred safe).

## Revision (after the critic's review, same day)

What changed, by the critic's fixes:

1. **The board changes its mind.** While classes lead (active, after class, evening) the HUD is
   level and stats only; Today's three moves under the class card as one line ("Today's three ·
   choose ›" with FOCUS and ADD), and in the evening becomes "Quests · 6 open ⌄" with the chores
   folded. A new after-class mode starts the moment every class is kept (Tue/Wed 3:20 PM, not
   5 PM): the finished hero offers music and a line, the Quest hero keeps its plate down, so "The
   rest of the day is yours." is true at 3:36 PM. Departure: the evening card itself (Close the day,
   the larger room) still waits for 5 PM, so the ledger is not offered mid-afternoon.
2. **The single tier speaks the level-up's dialect.** Two beats, centered; the 14 sigma blur is gone
   and the dim is the level-up's 0.93 / 0.95 / 0.97; the thread fades once the number lands; the
   level bar only near or across a level; NEXT and onward gone; it returns on its own at 2.4 s
   unless touched. Day and week tiers still wait for a tap.
3. **Warm, counting copy.** CLASS ATTENDED became CLASS KEPT; the timetable readback became a count
   line fed by a per-course, per-kind count for the term. Departure: the line sits under the number
   (where the level-up's "11 quests since level 21" sits), not directly under the course name.
4. **Unmarked stays neutral, and is shown.** Count-up tallies everywhere; past unmarked classes are
   4 pt dots; "N KEPT THIS WEEK"; new frames F9a to F9d render a partial Tuesday and week.
5. **Numbers and motes.** Day and week tiers count the class XP, roll the bonus in, then show the
   day or week total; ParticleBurst's dashes replaced by round honey motes that are gone before the
   settle; seeded marks light their streak day, and marks light the class's own day
   (`Days.nightKey`), so F8d no longer says "today counts".
6. **Plate and ring states.** I'M HERE during class, I WAS THERE after; "40 min left"; a 2.5 pt
   honey elapsed arc; "NEXT · 2:00 PM" in quiet text with a countdown only inside fifteen minutes
   (new F2d2); in the several-waiting card each ring marks its class and the text buttons are gone.
   The hero check now lands after the arc (no chevron at 300 ms).
7. **A calm evening and a fuller night.** Energy Weather and the other hearth banners step aside in
   the class evening; the chores fold; the music door reads "Put on music / ♪ Lamp left on"
   (departure: no "· mix", because Lamp left on is the name of one piece in the app's music, not a
   mix). The night ledger shows tomorrow's classes as fixed dashed-ring lines heading the MARK
   TOMORROW tray (placed directly above the tray's three wells rather than inside its raster frame).
8. **Widget and first run.** "Kept at 11:53 · +26 XP" with OPEN; a new after-last-class mock (F7c,
   I WENT TO BOTH); "Add your classes" under the Quest hero, weekdays only, with a visible "Not in
   school".

Also: "onward" is textMid at full opacity; the board's kept rows use the short course name so they
no longer truncate; the day and week tiers sit a shade deeper (0.96 / 0.97 / 0.98) because their
denser lines were colliding with the board's own text behind them; a ledger overflow found during
this pass was fixed. Nothing the critic asked to keep was removed. No fix was rejected outright;
the three partial departures are named above.

## Reproduce

```
cd C:/tmp/cdj/a-board
flutter test --dart-define=CLASS_DAY_RENDERS=true test/design_renders/class_day_a_board_test.dart
python test/design_renders/concept_a_sheet.py <this folder>
```
