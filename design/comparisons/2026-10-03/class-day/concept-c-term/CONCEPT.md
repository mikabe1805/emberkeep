# Concept C: Term (revision 2)

Class-day journey for Room of Days, accumulation first. Rendered 2026-10-03 from a `git archive`
copy of `class-day-journey` at c0a041a (Build 49 code), running the real `LifeRpgApp` at 393 x 852
pt @3x on Mika's real Fall 2026 timetable. Sheet: `sheet.png`. Frames: `F*.png`, listed in
`frames.json`. Source: `source/` (study code, render test, sheet script, and the study seams added
to the copy's `lib/` as `source/lib-seams.diff`). What changed since the critic's review is in
**Revision** at the end.

## The idea in three sentences

Every class Mika says he went to is struck as a honey medallion, full screen, the way a level-up
is: the Quest ring's orbit closes in gold, the medallion (stamped with the course number, "331")
lands in it with sparks and the completion haptic, and then it flies into its place in this week's
row of his term board. The board is a collected object, one unbroken run of medallions per week
since he started, and it is what the evening shows; days lived (marked or not) open room pieces,
and the room's own window shows the time of day and whatever opened tonight. At the end of the
term the finished board is framed for the room, so a degree becomes a wall of terms.

The request this answers, verbatim: "it doesnt have to continue to be just extra credit, it could
be a redesign for a more motivational angle where you can open the app at whatever point throughout
your day and mark if you attended your class and then it gives you like a "well done!" screen and
awards xp and maybe streak? not sure."

## The journey, frame by frame

His real week (from the imported fixture): Mon 8:30 Electronics Devices (SEC 111), 2:00 and 5:40-7:00
Linear Systems & Signals (SEC 111, SEC 204); Tue 10:20-11:40 Computer Architecture & Assembly
Language (HLL 114), 2:00-3:20 Discrete Structures II (PHY 001); Wed 8:30-11:30 Computer
Architecture Lab (EE 103), 2:00 Linear Systems; Thu 8:30 Electronics Devices, 2:00 Discrete
Structures II, 3:50-6:50 Electron Devices Lab (EE 209); Fri 10:20 Computer Architecture, 5:55-6:50
Discrete Structures II (BE 250, Livingston). Storyboard premise [inferred]: he starts the board on
Monday Oct 5 (week 6 of 15) and keeps all three Monday classes.

| Frame | When | What he sees | Why |
|---|---|---|---|
| F0a | Tue 8:05 | Morning light in the room's window. Under the HUD, one quiet strip: TUESDAY · TWO CLASSES, FIRST IN 2 HR 15 MIN, then "10:20 Computer Architecture HLL 114" and "2:00 Discrete Structures II PHY 001" with faint rings. No plate. The featured Quest (Read ten pages, MARK COMPLETE) stays the hero. | Nothing to mark yet, so the class day does not take the board. |
| F0b | Tue 10:45 | Mid-lecture: the class panel takes the featured slot. "in session until 11:40", +15 XP +1 MIND, the plate reads I'M HERE. | He can mark it from his seat; the word fits the moment. |
| F1 | Tue 11:50 | Daylight in the window. The panel: TUESDAY · WEEK 6 OF 15, Computer Architecture & Assembly Language with the Quest card's ready ring, "10:20–11:40 · HLL 114 · ended 10 min ago", one gold plate I WAS THERE; Discrete Structures II as a faint ring "in 2 hr 10 min"; this week's row M ●●● T ◌○ W ○○ T ○○○ F ○○, 3 THIS WEEK. | His classes in the first frame without Plans; one primary control. |
| F2a | press held | The plate sinks 3 pt into its brass under-plane, glow off, the ring warms (sheet shows a 2x detail). | 100 ms acknowledgment, the same plate as MARK COMPLETE. |
| F2b | 300 ms | The room blurs behind a warm takeover. ON THE BOARD; "Computer Architecture" slams in; "Lecture 10 of 28 · Tuesday 10:20 · HLL 114". At 40% height, on the level-up's rotated lozenge, the Quest ring's open orbit is closing in gold, a glint on its leading point. | The completion language he already knows, at full-screen size. |
| F2b+ | 700 ms | The strike: a 132 pt honey medallion with a 2 pt brass rim and "331" embossed has slammed into the closed ring (elastic), 18 sparks, the light spilling 420 pt around it. | The light source, the way the level numeral is in YOU DID IT. |
| F2c | 1.7 s, settled | The medallion flew into Tuesday and stays 1.25x with a thin bright ring; the lozenge now holds "+15 XP"; WEEK 6 · 4 THIS WEEK; "One down. / Discrete Structures II is at 2:00."; chips +1 MIND and STREAK · DAY 2 in one row; the rail at 353 / 870; onward and "Marked by mistake? Undo". | Earned and specific; it looks ahead instead of reporting a status. |
| F3 alt | Tue 15:35 | If he marked nothing during the day: both ready, one plate I WENT TO BOTH, "+40 XP FOR BOTH". | His Extra Credit idea as a shortcut. |
| F3 | Tue 15:35, settled | CLASSES DONE FOR TODAY. The headline names every class on the board today: "Computer Architecture / Discrete Structures II". 34 sparks at the strike; the numeral ticks +15 → +25 as BOTH +10 XP lands; "The rest of Tuesday is yours." | The day's fullest version, triggered by the clock. |
| F4 | Tue 15:36 | Afternoon light. Today's three steps back to 60% and reads "optional today"; the strip says "Both of Tuesday's classes are on the board." +40 XP, the week row, "Next class · Wed 8:30 AM · Computer Architecture Lab", and PUT A RECORD ON. The featured Quest has collapsed to an ordinary row. | The day handed back, with one thing for resting. |
| F5 | Tue 20:30 | The room's window now shows the Rainy Night view (term day 25 opened it), captioned "← Rainy Night window · term day 25". The panel: Fall 2026, "5 classes on the board · term day 25 of 70", the board (weeks 1–5 "before you started", week 6's run with today's medallions and the rest of the week as rings, "7–15 ahead"), NEXT FOR THE ROOM · 5 CLASS DAYS AWAY · Listening Room desk · "Opens on term day 30, marked or not.", PUT A RECORD ON. | Something that grows, an unlock he can see on this screen, and music. |
| F6 | Tue 22:30 | The real night ledger with its recap rewritten: WHAT MOVED +40 XP, "+2 MIND · BOTH CLASSES +10", TWO CLASSES ON THE BOARD (Computer Architecture 10:20, Discrete Structures II 2:00), the week row, "Week 6 · term day 25 of 70", TOMORROW 8:30 Computer Architecture Lab / 2:00 Linear Systems, over the real MARK TOMORROW tray. | Build 49 writes "+0 XP / NO THREADS FINISHED" for this day. |
| F10a | Mon Oct 12, 16:10 | His long Monday: "Two on the board so far." +30 XP, the week row, Linear Systems & Signals "5:40 PM · SEC 204 · in 1 hr 30 min". Nothing to mark, so the featured Quest leads. | The long gap is a good time for a Quest; the board does not compete. |
| F10b | Mon 19:05 | Dusk in the window. Electronics Devices and Linear Systems (2:00) on the board as quiet rows; Linear Systems (5:40–7:00) "ended 5 min ago", I WAS THERE. | Three of his five days end near 7 PM; marking this plays the day's beat. |
| F2d | Wed Oct 21, 15:30 | Marking Linear Systems after his lab: CLASSES DONE FOR TODAY, "Computer Architecture Lab / Linear Systems", +25, and the rail fills to LEVEL 19 READY (849 + 15 + 10 = 874 of 870). No onward link. | A class carrying him over a level, on screen. |
| F2d+ | +1.5 s | At 2.05 s the real LevelUpOverlay fades in over it: LEVEL UP, YOU DID IT., 19 on its lozenge, its own storm, and "30 classes since level 18". | The moment he loved, reached through classes. |
| F7a | MOCK, 11:52 | Day Ledger medium widget (338 x 158): the week row on its own line with day letters, the ended class with an interactive I WAS THERE (iOS 17 App Intent); below, after the tap: "On the board · +15 XP", "Open the room to watch it land". | Reach without opening; the celebration waits, it is never skipped. |
| F7b | MOCK, 15:21 | Lock screen, the opt-in after-last-class notification: "Tuesday's classes are over", actions "I went to both · +40 XP" and "Choose in the room". | Off unless he turns it on; one a day; not sent if all are marked. |
| F7c | MOCK, 15:36 and 20:30 | The same widget later: "Both of Tuesday's classes are on the board." +40 XP, TOMORROW 8:30 Computer Architecture Lab; in the evening "5 classes on the board this term", "Rainy Night window opened tonight". | The widget has a state for every part of the day. |
| F7d | Tue 15:40 | Opening the app after two widget marks: one combined takeover at the highest tier reached (CLASSES DONE FOR TODAY), "Marked from your home screen at 11:52 and 3:24.", two medallions struck side by side and landing 85 ms apart, +40, STREAK · DAY 2. | Deferred marks still get their moment, once. |
| F8a | Fri Nov 13, 18:52 | Six weeks in, the first mark after the week's last class: WEEK 11 COMPLETE, "Eleven classes this week.", +25, the term plate (11 THIS WEEK, 68 THIS TERM) with weeks 6–11 as unbroken runs, the brass rule under week 11, "The weekend is yours.", level 19 at 744 / 915. | The week's fullest version: the term, not a checkbox. |
| F8b | Fri 21:00 | The evening panel at week 11: 68 on the board, term day 53 of 70, six runs, "12–15 ahead", Painter's Loft desk "Opens on term day 55, marked or not." | Accumulation, side by side with F5. |
| F11 | Sat Oct 31, 10:30 | No mark came after Friday's last class that week, so the first weekend open rules week 9 off quietly on the board: WEEK 9 OF 15 · 45 THIS TERM, "Ten classes this week.", the run with a brass rule, "Next class · Mon 8:30 AM · Electronics Devices". No XP, no takeover. The featured Quest leads (the streak needs a Quest or a freeze on weekends). | The weekend, calm. |
| F9 | Tue 11:50, no timetable | "Going to class can count here." ADD CLASSES (outline), "not for me" hides it for good. The featured Quest stays the hero. | One calm way in for anyone without classes yet. |

## What counts, and what it pays (proposal, with reasons)

| Event | Pays | Why this size |
|---|---|---|
| Lecture or recitation | +15 XP, +1 to its course's stat | 15 is a difficulty-4 Quest's base before multipliers. Flat: no streak multiplier, no decay, no soft cap, so a class pays the same in week 15 as in week 6 (his "why should completion pay less over time??"). |
| Lab, or any block of 2.5 h or more | +20 XP, +2 CRAFT | Labs are hands-on; a 3-hour block pays a little more. |
| Every class of the day on the board | +10 XP, once | His Extra Credit number, earned by the day in any order. |
| A class not marked | nothing, ever | It stays neutral. |

A course's stat is chosen once per course when the timetable is imported (default MIND; a lab is
always CRAFT) and can be changed in Plans. In the storyboard Electronics Devices is set to CRAFT
[inferred: it is the lecture for his Electron Devices Lab]; Computer Architecture, Linear Systems
and Discrete Structures II are MIND.

Scale, his real week at full attendance: 10 lectures + 2 labs + 5 class days = 240 XP (about 28% of
level 18's 870, roughly two Quests per class day), +8 MIND and +6 CRAFT. Weeks 6 to 11 in the
storyboard move MIND 116 → 162 and CRAFT 94 → 126 (F8b), a steady trickle beside a Quest's +6, and
his other stats keep their own Quests. The rest of the term at full attendance is about 2,300 XP,
a little over two levels (18 → 20).

### The streak rule (proposal: yes or no)

**A day counts for the streak when he completes a Quest or marks a class.** The STREAK chip appears
only on the mark that makes the day count (the day's first counting action, "STREAK · DAY 2"), never
on later marks. Classes pay flat XP (the streak multiplier stays on Quests), never count as a Quest
completion, never fill Today's three, never move a goal. Unmarked classes do not hold the streak.
Freezes keep working as now (at CARE 72 one is earned every 2 active days), which covers a weekend
with no Quests. If he says no: the chip leaves and nothing else changes.

### What opens by days lived (never by streak, XP or marks)

A class day counts as lived once its last class has ended, marked or not. Every fifth class day
opens one piece the app already has: day 5 60 Glimmers, 10 City Lights window, 15 Pine Forest
window, 20 Far Mountains window, 25 Rainy Night window, 30 Listening Room desk, 35 brass corners for
the board, 40 Rain Room desk, 45 120 Glimmers, 50 Conservatory Ledger desk, 55 Painter's Loft desk,
60 Archive Ledger desk, 65 200 Glimmers, 70 the finished board framed for his room. A window view
appears in the Quests room's own window on the evening it opens (crossfaded on the first evening
open, with a caption); tapping the caption travels to the Me room through `room_travel.dart`
(described; the study caption is not wired).
Achievement-gated views keep their gates. Days lived before his first use open on his first evening.

## What never punishes

- An unmarked class draws nothing: no hole, no grey dot, no count of what is absent. A past week is
  one continuous run of medallions with hairline day ticks, so nothing has a column to be missing
  from (F8a, F8b). Open rings appear only for today and the rest of the current week.
- Weeks before he started fold into "before you started"; weeks ahead are one quiet line, "12–15
  ahead", never rows of empty sockets.
- Tiers follow the clock: the first mark after the day's last class plays the day beat, whichever
  class it is and in whatever order he marks; the +10 counts the whole day. Going to two of three
  still gets "The rest of Monday is yours."
- Days lived advance by the calendar, so the unlocks arrive whether or not he marked anything.
- Copy names what happened and never what did not. No red. A test scans every string literal in the
  study for failed, missed, lost, broke, skipped and em dashes.
- Marking stays open until the night rolls over (4 AM, the app's night key); then a class is neutral
  forever. In the evening a still-open class sits as one quiet row in the evening panel ("tap the
  ring if you went"), with no count. Long-press a class ring to set it aside for today (described, not rendered).
- The after-class notification is the only reminder, and it is off unless he turns it on.
- "Marked by mistake? Undo" on every takeover. Marks are self-report on purpose.

## Sound, haptics and timing (intended; renders have no audio)

| t (ms) | Ordinary (settles 1.6 s) | Day done (1.9 s) | Week done (2.4 s) |
|---|---|---|---|
| press | Haptics.tap on contact; no press sound, as MARK COMPLETE | same | same |
| 0-180 | Takeover fades in (walnut gradient at 82/88/93%), the room blurs (sigma 14), music ducks as on a Quest completion | same | same |
| 60-520 | Label, then the class name slams (elasticOut) | names every class on the board today | "Eleven classes this week." |
| 80-260 | Lozenge, spill and the open orbit fade in | same | same |
| 100 | `completion-composite` starts, so its detent lands on the strike | same | same |
| 140-560 | The gold sweep closes the orbit (easeInOut), glint on its leading point | same | same |
| 560 | Strike: medallion scale 0.4 → 1 on Motion.slam (to 900), Haptics.questComplete, ParticleBurst 18 | 34 | 52 |
| 900 / 1000 / 1150 | The medallion leaves: shrink-flight to its cell, 320 ms easeInCubic; +XP rises onto the lozenge | same | lands in week 11 of the term plate |
| landing | Haptics.tap; cell glow 120/500 ms; `stat_N` note (MIND F#, CRAFT A) | + BOTH chip: `streak.wav`, Haptics.flourish, numeral ticks +15 → +25 over 320 ms | brass rule under the week over 400 ms with the brass material sound, Haptics.big at its end |
| landing → +400 | Chips 85 ms apart; the rail fills (easeInQuad); the forward line | "The rest of Tuesday is yours." | "The weekend is yours." |
| end | onward, undo; a tap anywhere dismisses at any time | same | same |
| crossing | At end + 150 ms the real LevelUpOverlay is inserted (`levelup.wav`, Haptics.big, its storm); its dim fades in over the class takeover, which leaves 300 ms later | same | same |

`levelup.wav` stays reserved for level-ups. I WENT TO BOTH strikes two smaller medallions side by
side, 85 ms apart, in one takeover. Widget and notification marks queue with their own time in the
App Group; the next open plays one combined takeover at the highest tier reached (F7d). Reduce
Motion: no flight and no sparks; the medallion appears placed, one Haptics.light, one composite.

**Undo and levels:** Undo stays on the class takeover until the level-up fades in, and undoing there
takes the mark, its XP and the level back. After YOU DID IT. plays, the level stands (no level ever
goes down in Room of Days); undoing that class later (long-press its medallion, "Take it off the
board"; described, not rendered) removes its XP from level 19's progress, floored at zero.

## Reused vs new

**Reused, real code:** LifeRpgApp shell, Quests board, HUD (Today's three strip), dock, the writer
room's depth planes (untouched), `GoldSurface`, `facetedDecoration`/`FacetedClipper` and the
featured card's walnut and brass, the level-up's gradient, rotated lozenge, 420 pt spill and type
scale, the real `LevelUpOverlay`, `ParticleBurst`, `Motion.slam`, `RoutineLedgerScaffold`,
`RoutineLedgerPage`, `LedgerSectionTitle`, `LedgerType`, the real MARK TOMORROW tray,
`paintWindowScene`, `Sfx` cue names, `Haptics`, `AcademicSchedule` and its importer (his real .ics
fixture), the umbrella-brush music pool (`MainRoomMusic`, named, not played in renders).

**New:** the term record (`TermStudyModel`: marks, weeks, term days, days lived, unlocks, "lecture
10 of 28", clock-based tiers, the streak-first-mark rule, per-course stats), the struck medallion
(`TermHeroMedallionPainter`), the board marks and `TermWeekRun` / `TermWeekStrip` / `TermBoard`, the
class panel, the day strip (before / so far / done), the evening panel, the weekend panel, the
record control, the room caption, `TermRoomWindow` (the window by the clock), `TermCelebration`
(three tiers, flight, level handoff), the ledger recap, the mocks.

**Files touched in the copy's `lib/` (study seams, in `source/lib-seams.diff`):**
`lib/screens/quests.dart` (`ClassDaySlot` with `takesFeature`, `handsDayBack`, `threeStatus`,
`roomCaption`; Today's three status override at 60%); `lib/widgets/home_room.dart`
(`debugWriterRoomWindowOverlay` on the writer room's far plane); `lib/widgets/levelup_overlay.dart`
(`debugEvidenceLine`); `lib/widgets/routine_flows.dart` (`DebugLedgerTomorrowTray`). Study code:
`lib/design_studies/class_day/c_term/` (seven files).

## Build cost and risks

**Cost (rough):** attendance as its own save record (occurrenceKey, day, time marked) with schema,
cloud backup and undo, 1-2 days, merged with the Extra Credit port (schema 29) and coordinated with
the cloud-utf8-guard session; engine credit path (XP, per-course stat, level-ups, day bonus, streak
rule if yes) with tests, 1 day; per-course stat choice in the importer and Plans, half a day; board,
strips, evening and weekend panels in quests.dart, 2 days; the takeover and flight, 2 days; the
room window by daypart and unlock crossfade, 1 day (needs authored daylight plates eventually, see
risk 3); ledger recap and Journal trace class titles, 1 day; days-lived unlocks, half a day; widget
App Intent + App Group queue + replay on open (Swift, Codemagic, signing), 2-3 days; notification
category with actions, 1 day.

**Risks:**
1. Ten to twelve takeovers a week could still feel like a toll. The ordinary tier settles at 1.6 s,
   is skippable at any tap, and varies by course number, forward line and the week's count, but
   only his thumb on a phone can say. A "quick marks" setting may be needed.
2. Pay and stats are proposals; per-course stats need one question at import.
3. The daylight window is painted in code into the night base plate's panes. It reads as day at
   phone size, but the lamp stays lit and the room's warm light does not change; a build should
   author day and dusk variants of the base plane (never re-cut the planes).
4. The board at 11 pt medallions is a collected object at week 11; at week 15 with heavier
   schedules (4-5 classes a day) the runs get long and may need a second line per week.
5. The real LevelUpOverlay lets the board show through at about 5%, so the HUD and panel are
   faintly visible behind YOU DID IT. (F2d+). That is the shipped component.
6. Not observed: sound, haptics, 120 Hz motion, SF Pro (Inter stands in), the cost of a full-screen
   blur on older iPhones.

## Verified, inferred, gates, departures

- **Verified (renders, analyzer, tests):** all 24 frames render with zero layout overflows;
  `flutter analyze` is clean on the study, the seams and the test; the copy scan passes; a unit
  check confirms the day beat and the +10 follow the clock and ignore marking order, and the streak
  chip appears only on the first mark. Schedule facts (week 6 of 15, 70 class days, term day 25 on
  Oct 6 and 53 on Nov 13, lecture 10 of 28, 15 of 42, 22 of 42, 32 of 42) come from the imported
  fixture; the level crossing (849 → 874 of 870 on Wed Oct 21) comes from the pay rules applied to
  the seeded account.
- **Inferred:** he starts the board on Mon Oct 5 and keeps the Monday classes; the history after
  (four classes unmarked across weeks 7, 9 and 11) is invented to show neutral weeks; streak values
  assume the proposed rule; Electronics Devices set to CRAFT.
- **Remaining gates:** his yes or no on the streak rule, the pay sizes and the per-course stat; how
  the takeover feels ten times a week on his phone; sound and haptics heard on device.
- **Departures:** the repo convention "Full-screen celebrations rationed to milestones only" is
  knowingly overridden by his 2026-10-03 direction (a full-screen response to every mark), scaled
  by tier. F2c is captured at 1.7 s (the ordinary tier now settles at 1.6 s, longer than the brief's
  "about 1.2 s", because the medallion strikes before it flies). Extra frames F0a, F0b, F2b+, F2d,
  F2d+, F3 alt, F7c, F7d, F8a, F8b, F10a, F10b, F11, F9. The celebration uses short course names
  ("Computer Architecture", "Linear Systems") derived by rule; a build lets him rename courses. The
  study writes each mark's XP into the live save so the HUD under the takeover is current; history
  before the render moment is seeded with the same pay rules.

## Revision (after the critic, 2026-10-03)

What changed, by the critic's fixes:

1. **The ordinary tier now has a light-source hero.** A 132 pt struck medallion (honey radial
   0xFFF2CD93 → 0xFFB8742F, 2 pt brass rim, course number embossed in Fraunces 30) on the level-up's
   104 pt lozenge and 420 pt spill, at 40% height; the orbit closes 140-560 ms, it strikes at 560
   (Motion.slam, Haptics.questComplete, 18/34/52 sparks), then flies to its cell and stays 1.25x with
   a 1 px bright ring. The gradient dropped to 82/88/93% so the blurred room reads at the top; the
   layout centers near 45% with no empty bottom third; a Fraunces 20 line looks ahead ("One down. /
   Discrete Structures II is at 2:00."). Departure: the hold and flight are shorter than suggested
   (fly at 900 ms for 320 ms, settled at 1.6 s), because ten a week should stay quick.
2. **Tiers follow the clock.** The day beat plays on the first mark after the day's last class has
   ended (once per day), the week beat on the first mark after the week's last class (once per
   week); the +10 counts the whole day in any order; the day headline names every class on the
   board today; the BOTH/ALL chip appears only when all are on. With no mark after the week ends,
   the first weekend open rules the week off quietly on the board (F11, no XP, no takeover).
3. **No slot grid.** Past days pack their medallions; a past week is one run with hairline day
   ticks; sockets only for today and the rest of this week; weeks ahead are one line ("7–15
   ahead"). Board medallions are 11 pt with 3 pt gaps, a brass rim, a contact shadow and a drop of
   light that moves only with scroll offset. The widget's row has day letters and 9 pt medallions on
   its own line.
4. **The day is handed back.** After the day's classes, Today's three steps back to 60% ("optional
   today", or "optional tonight" after 5 PM), the featured Quest collapses to a row, and the strip
   offers PUT A RECORD ON (the umbrella-brush pool; while it plays, the small record turning is the
   only living effect). The Quests room's window follows `Clock.now()` (morning, day, afternoon,
   dusk, night), and on an unlock evening it shows the new view with a caption. Departure: shown
   with "optional today" before 5 PM, since "tonight" at 3:36 PM is not true.
5. **Chips are walnut** with a 0.6 px rim at 35% of the stat color and color only on icon and words;
   STREAK shows only on the mark that makes the day count ("STREAK · DAY 2"); the numeral ticks
   +15 → +25 when the bonus lands; chips sit in one centered row (F7d's three chips included).
6. **The level crossing is built and rendered** (F2d, F2d+): the rail reads LEVEL 19 READY and the
   real LevelUpOverlay fades in by itself, with "30 classes since level 18" through a small seam.
   Undo is answered above.
7. **The days the brief describes are storyboarded:** Tue 8:05 (F0a), Tue 10:45 (F0b), Mon 16:10
   and 19:05 on his long Monday (F10a, F10b), a Saturday (F11), the widget at 15:36 and 20:30
   (F7c), and the combined replay after widget marks (F7d). Departure: the mid-lecture plate reads
   I'M HERE, not I WAS THERE, because it is said from the seat.
8. **Copy and stats.** "Opens on term day 30, marked or not." (shorter than the suggested "whether
   or not you mark anything" so it fits one line); "Both of Tuesday's classes are on the board.";
   CLASS KEPT is now ON THE BOARD everywhere (the ledger reads TWO CLASSES ON THE BOARD); "before the
   board" is "before you started". Stats are per course (labs and Electronics Devices pay CRAFT,
   lectures MIND) at +1 per lecture and +2 per lab, so MIND reaches 162 by week 11, not 232.

Kept as the critic asked: the class panel in the featured slot with one gold plate, "Lecture 10 of
28 · Tuesday 10:20 · HLL 114", the three tiers and their closing lines, I WENT TO BOTH, the ledger
recap over the real tray, flat pay and the one-sentence streak rule, days-lived unlocks and the 4 AM
night key, the calm kept strip, the way-in card, the widget and opt-in notification, and the app's
own type and materials.

Also fixed while looking at the frames: the night ledger fits its page with no overflow (one fewer
section), the evening unlock row no longer wraps its label, short course names in the morning strip
and the widget footer, and the HUD under YOU DID IT. shows the new level.
