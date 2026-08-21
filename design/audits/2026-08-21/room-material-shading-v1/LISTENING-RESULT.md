# Listening result · 2026-08-21

Source study: `room-material-shading-v1` (heard together with
`room-event-voice-v1` on one audition desk)

Output route: physical phone built-in speaker (the locally hosted Listening
Desk page, level-matched A/Bs, playable mock surfaces, and the
with/without-textures browse flows)

## Verdict

Approved for release, with one noted polish item. Verbatim:

> i like all the candidate stuff best on the phone sound system, they sound fun (although they do have that sort of low quality recording vibe to them although it's not a huge deal)

"All the candidate stuff" covers both open studies: the nine material lanes
(slate select/navigate/place, page navigate/open, glass select/place, brass
select/place) and the eleven event voices. The comparison set included the
shipped wood clasp anchor and the legacy event palette as level-matched
controls, so the preference is against the live system, not in isolation.

## Decision

- Ship every lane byte-identical to the auditioned masters (no rerender
  between approval and release — the fire_ignite precedent).
- Runtime: the nine lanes enter `Sfx._shippedMaterialLanes`; event volumes
  move to 1.0 (levels are calibrated in-file like the other Room masters).
- Byte-locks added in `test/interaction_sound_quality_test.dart` against the
  study copies.

## Polish follow-up — resolved

The noted "low quality recording vibe" was diagnosed as a render artifact,
not a gesture problem: stacked per-body excitation-noise beds, the page
flick's steady filtered noise, and the reflection send on the longest
gestures. The `room-material-shading-v2-polish` render treated exactly these
with identical gestures. Heard beside the live v1 masters on the desk, the
owner's final verdict (2026-08-21):

> it sounds wonderful! very well done. you can get it ready for the next build

**Shipped:** the v2-polish masters replaced v1 in
`assets/sfx/room/materials/` for the next build; byte-locks now pin the
v2-polish audition copies. The v1 masters remain in this study as the
approved-gesture record.
