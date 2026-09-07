# Working experience browser validation

The release app is served locally on port 8393. Browser session
`rod-implementation` uses an isolated profile and the synthetic save in
`output/playwright/working-browser-fixture.json`. This is not the owner's save.
The sample includes real serialized timer configuration and a saved goal note;
the interface reads them through the normal storage and application paths.

## Verified journey

1. Open Goals from the real five-tab shell. Today's two and the longer goal
   appear together, with separate Change, Open today's quests and goal actions.
2. Change opens the chooser. The 10-minute filter retains existing choices and
   offers the current accepted sketch action and the saved five-minute timer.
   Adding Sketch changes only the draft. Persisted XP remains 0 and the saved
   field still has two entries before Save.
3. Attempt a fourth choice. The app says, "Your three are chosen. Remove one
   first to make room." Save retains Read ten pages / Take a walk / Sketch one
   object at ranks 1 / 2 / 3, with XP still 0.
4. Open the exact goal Quest, then its session. The clock remains 10:00 in Ready.
   The goal title, current-step guidance and latest saved note are displayed.
   The note and honor action remain reachable by ordinary vertical scrolling.
5. Choose Focus music On before Start. A single glass-selection sound plays;
   music and countdown do not start. Start plays a brass placement sound and
   starts `focus-meditation.m4a`; browser playback resolves successfully and
   the clock advances to 9:56. Leaving the session pauses that track, retains
   the saved global music preference (Off), and awards no XP.
6. Open Make this smaller, then inspect the before/after review. Keep original
   returns to Goals with the persisted save byte-for-byte identical.
7. Accept the five-minute outline attempt. The exact Quest is replaced at rank
   3, plan revision becomes 2, the other two choices and goal note remain, and
   XP is still 0. No second Workshop acceptance or duplicate Quest appears.
8. Open the five-minute session and choose I already did it. One completion
   grants 15 base XP, advances the goal once, and leaves the completed smaller
   Quest in today's three. The original ten-minute practice is restored in
   the plan. No timer-verification multiplier is awarded.
9. Reload the app. It retains 15 XP, one completion, all three field identities,
   the original ten-minute practice and the saved goal note.

## Defects found through the browser

The first timer overlay exposed underlying Quest and navigation controls to
accessibility traversal. It now uses a modal route and blocks the underlying
semantics, with closed-loop keyboard traversal. A regression test checks eight
Tab presses, cancellation and restoration of the Quest controls. Its running
header was also corrected, and its ticking time is no longer a live region.
Final rebuilt-browser confirmation is recorded in the root design QA.

That confirmation passed: the rebuilt Ready and running accessibility trees
contain only session controls; running copy reads "Your 10-minute session is
in progress." Cancellation restores the Quest controls. A 320 × 568 browser
capture after scrolling shows the music control, Start, honor action and full
saved note. A 1280 × 900 capture keeps the live work surface at a readable width.
After the final reload, cancelling a draft removal of the completed third
choice retains all three identities, 15 XP, one completion and the note.

## Evidence

`output/playwright/01-goals-live.png`, `02-chooser-live.png`,
`03-quests-live.png`, `04-session-ready-live.png`,
`05-session-context-live.png`, `06-smaller-review-live.png`,
`07-completion-live.png` record the working path. Final captures supersede the
initial simpler material where noted in the root QA.

The browser reported no product console errors or warnings during this path.
Successful playback and event timing do not establish physical-device sound
quality, haptic feel or owner acceptance.
