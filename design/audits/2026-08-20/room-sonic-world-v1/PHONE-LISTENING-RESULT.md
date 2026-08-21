# Physical phone result · 2026-08-20

Source gate: `room-sonic-phone-gate-v1`

Candidate: `answered-detent`

Output route: physical iPhone built-in speaker, route explicitly attested

Device context: iOS 18.7, Safari 26.6, full device volume; exact iPhone model
was not captured.

## Result

Verdict: **Almost**

Verbatim reason:

> the main clicking sounds could be more crisp and fuller so it feels nice to click around, and also the volume is off it’s pretty quiet even though i’m on full volume

The event log proves one uninterrupted full-flow play and two uninterrupted
completion-only plays before the verdict. A second full-flow play began before
the verdict and reached its natural end immediately afterward. This is valid
physical-device evidence, not a browser-only or interrupted playback.

## Decision

- The physical-device gate did not pass. `Almost` is not approval.
- Keep Answered Detent and its 75 ms accepted-contact-to-answer timing locked;
  the listener specifically identified the main clicking sounds, not the
  selected reward, as the remaining texture problem.
- Reject the current everyday master levels for the iPhone speaker. The next
  study must raise ordinary interaction audibility without raising the locked
  reward or flattening the event hierarchy.
- Reject the current everyday contact/body balance for the iPhone speaker. The
  next study must test more useful contact definition and phone-readable body,
  not literal material Foley, a broad treble shelf, or extra bass.
- Keep runtime integration pending until a revised ordinary family passes a
  second physical-phone gate.

