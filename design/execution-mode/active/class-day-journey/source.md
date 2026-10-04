# Class-day journey: board and celebration (source)

The direction this slice builds, as handed to the build on 2026-10-04. Mika's words are quoted
verbatim (lowercase, apostrophes and typos kept). Nothing here is his verdict on the build: he has
not seen it yet.

## His direction

2026-10-03, verbatim:

> "it doesnt have to continue to be just extra credit, it could be a redesign for a more
> motivational angle where you can open the app at whatever point throughout your day and mark if
> you attended your class and then it gives you like a "well done!" screen and awards xp and maybe
> streak? not sure."

Earlier, about what he loved:

> "i really liked it in the early builds of the app when level ups filled the entire screen with
> the "you did it!" screen. it felt very rewarding/encouraging"

What to avoid, in his words: "i absolutely hate how visually busy the UI is around your main
quest" (2026-09-28, as quoted in the UI code map), "i dont like verything being colored", "i cant stand colored blocks like the peach and
green stuff". What he likes: "i like the 3d feeling like youre layering art and get to travel
throughout it". About transitions: "i don’t like the blur and rush effect it feels weird and
inappropriate mood wise". "well done!" is his intent, never final copy.

## The chosen direction

Concept B, "In the room" (`design/comparisons/2026-10-03/class-day/concept-b-room/CONCEPT.md`),
with grafts from A, "On the board" (real-board seams, the HUD swap, the mode machine, the
no-timetable row) and C, "Term" (clock tiers). Three independent judges recommended it; Mika has
not given a verdict. This build is what he will judge on his phone.

## Rubric for this slice (the judges' reasons, standing in for his until he gives his own)

A lost item means not done.

1. The class day changes the frame: on a day with classes the Quests tab opens on the room (large,
   the layered depth room, not a strip) with today's classes on one calm glass card at the floor
   line; the class that just ended foremost with one luminous I WAS THERE; the next one upcoming.
   One primary owner, one luminous control. A compact two-line HUD keeps level, XP and the six
   stats. Today's three is one line with a BOARD toggle that brings the full board back. Non-class
   days and people without a timetable keep today's board unchanged, except one calm "Add your
   classes" row under the Quest hero on weekdays with a visible "Not in school" that hides it for
   good (it opens the Plans import sheet).
2. Marking: any class that has started can be marked (I'M HERE while in session, I WAS THERE
   after); a countdown only inside the last 15 minutes before start ("STARTS IN 12 MIN"), otherwise
   the start time; marking stays open until the class's night ends at 04:00. The press
   acknowledges on contact (the card's own ring closes; completion-composite sound; light haptic).
   Past unmarked classes are quiet dim dots, never hollow outlines. When two or more ended classes
   are unmarked, one "I went to all of today's classes" shortcut marks them together with one
   celebration.
3. The celebration speaks the level-up's own grammar (walnut dim with no blur, Fraunces display
   headline slammed on elasticOut, the numeral diamond). Class tier "YOU WERE THERE." with the
   per-course count that only grows, the course title, time and room, +XP threading into the level
   rail, the stat chip, one closing line from what is actually next in his timetable; back on its
   own at about 2.4 s unless a finger is on the glass. Quick tier "THAT ONE TOO." at 1.5x, back in
   about 1.4 s. Day tier "<WEEKDAY>, DONE." held for a tap, "Two for two." only when true, the +10
   line only when every class is kept. Week tier "THAT'S THE WEEK." with "Twelve for twelve." only
   when true, else "Eleven classes this week.". No denominators, no confetti, motes gone before the
   settle. The streak line only when ClassDayRules turns it on (off now). A level crossed by a mark
   chains into the real LevelUpOverlay with the classes since the last level.
4. Not B's two artificial things: no check ring floating over the desk, no code-drawn brass plate
   or caption on the painting.
5. Undo is a swipe on the kept row past 42% with boing.wav, through RewardUndoSlot, exactly as
   Quests undo; no "Marked by mistake?" text.
7. Reduce Motion: fades and stills. Large text (130%) and 393 x 852 legible. The board never fights
   the Quest board's existing tests on non-class days.
8. Copy plain, specific and game-concrete; no room-as-narrator lines, no storybook, no
   over-metaphor.

Item 6 (the evening and the camera walk to the armchair) belongs to the next slice.
