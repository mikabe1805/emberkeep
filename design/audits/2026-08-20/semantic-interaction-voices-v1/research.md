# Why the sound system is semantic

The prior study treated C as a physical mechanism and varied its weight and
finish. The owner correction is more fundamental:

> i hardly hear a difference between the variations of C you made, and that's
> not what I meant. I meant if one thing sounds like dak when you click on it,
> like maybe the dak sound (ie C) is going to be used when switching pages, but
> a more "bloop!" sound like the current one should be for finishing quests,
> and then there should be another sound for button clicking (like clicking on
> a journal entry) that should have a lighter, shorter "tak!" feel, etc.

The corrected model is one sonic verb per state change. Variants live inside a
verb; they do not create the app's primary variety.

## Professional precedent

- Microsoft WinUI separates Invoke, Show, Hide, MoveNext, MovePrevious, and
  GoBack rather than assigning sound by visual surface. It also cycles related
  focus variants to avoid monotony:
  https://learn.microsoft.com/en-us/windows/apps/develop/ui/sound
- Apple recommends sparse, low-volume UI sound, precise sound-motion-haptic
  timing, clean edits, and testing on the actual device. It uses distinct
  directional cues where direction carries meaning:
  https://developer.apple.com/videos/play/wwdc2017/803/
- Apple's current haptic guidance emphasizes a consistent causal relationship
  and matching intensity/sharpness across sound, motion, and touch:
  https://developer.apple.com/design/human-interface-guidelines/playing-haptics

## Proposed runtime interpretation

The current `MaterialSound` API should eventually become an interaction-role
API, but only after audition approval:

`pressSound: navigateDak | openTak | selectTuk | silent`

Outcome cues stay separate:

`outcomeSound: completeBloop | placeSettle | discovery | rankAdvance | none`

For the first migration, `placeSettle` can reuse `selectTuk` after a confirmed
save. If that makes ordinary choices and durable saves feel too similar in the
real app, it earns a fifth voice later. It is not added speculatively now.

## Initial mapping

- Bottom dock, accepted page/section movement, and calendar period/view
  traversal: `navigateDak`. Choosing a date inside the current view is
  `selectTuk`.
- Journal entry, detail card, ordinary sheet, secondary button: `openTak`.
- Date, toggle, chip, filter, pin, picker: `selectTuk` after acceptance.
- Quest/routine completion: immediate small accepted-state touch, then
  `completeBloop` 65 ms later.
- Save/add/schedule: `selectTuk` or silence on press, then a compact settled
  confirmation only after persistence succeeds.
- Errors, cancel, loading, scrolling, typing, repeated selected tab: silent by
  default.

Rare `loot`, `levelup`, keepsake, and hearth cues retain their own identities.
They must not become louder versions of everyday clicks.
