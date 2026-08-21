# Listening result · 2026-08-21

Source study: `room-event-voice-v1` (heard together with
`room-material-shading-v1` on one audition desk)

Output route: physical phone built-in speaker (the locally hosted Listening
Desk page; every event A/B'd against its level-matched legacy control, plus
in-context stat runs)

## Verdict

Approved for release, with one noted polish item. Verbatim:

> i like all the candidate stuff best on the phone sound system, they sound fun (although they do have that sort of low quality recording vibe to them although it's not a huge deal)

## Decision

- `streak`, `crit`, `loot`, `levelup`, `boing`, and `stat_0..5` ship
  byte-identical to the auditioned candidates, replacing the last Gen-1 sine
  palette.
- Their `Sfx._volume` entries move to 1.0 — the phone level is calibrated
  in-file, extending the Room-master convention to the event tier.
- Byte-locks added in `test/interaction_sound_quality_test.dart`.
- The completion composite, fire ignition, clasps, and Paired Return were not
  part of this study and are unchanged.

## Polish follow-up — resolved

Shared with `room-material-shading-v1`: the "low quality recording vibe" was
a render artifact (stacked excitation-noise beds, reflection send on long
gestures), treated in `room-event-voice-v2-polish` with identical gestures.
Owner's final verdict beside the live v1 masters (2026-08-21):

> it sounds wonderful! very well done. you can get it ready for the next build

**Shipped:** the v2-polish events replaced v1 in `assets/sfx/` for the next
build; byte-locks now pin the v2-polish audition copies.
