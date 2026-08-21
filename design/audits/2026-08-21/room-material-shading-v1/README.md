# room-material-shading-v1

Status: **candidates rendered, awaiting the owner's listening pass.** Runtime
assets are unchanged.

## What this study is

Owner direction (2026-08-21): interactable surfaces should feel like different
**textures** — buttons like stone slates with a satisfying "dak", page flips
their own sound, ordinary tapping keeping the current clasp. This is the
material axis the sonic-world sheet reserved ("visual material may shade an
authoring layer later"), now owner-directed.

The history it honors: the two literal-Foley material families were vetoed
("recorded in a really old recording studio… not fresh and satisfying"); what
finally passed the phone gate was synthesized. So every lane here is a
**shading of the approved mechanism** — same C contact master, same close
reflection fingerprint, same D-major pentatonic tokens and take walk — with
only the body/grain changing per material. Minecraft's material-walk system is
the model for the mapping (material follows the surface you touch), not for
sourcing.

| Lane | Identity | Where it will be wired |
| --- | --- | --- |
| slate select/navigate/place | heavier double contact, stiff dense plate, mineral grain — the "dak" | faceted stone-cut buttons, commits, primary CTAs |
| page navigate/open | parchment flick that lands on a soft contact carrying the field note | dock tab changes, journal pages, calendar modes, wizard steps |
| glass select/place | one small damped bright-side pair, never piercing | glass switches, cosmetic/preview surfaces |
| brass select/place | felt-muted dyad with a slow warm beat | precious commits: purchase, keepsake, share |
| wood (anchor) | the shipped clasp, untouched | everything else — "tapping around is the current sound" |

Three takes per lane on the d/e/a pitch tokens — the same global variant axis
as the clasps, so material never breaks the no-repeat walk or Paired Return.

## How to listen

- Browser desk (playable mock surfaces, the with/without browse A/B, per-lane
  takes, and the still-open event-voice candidates):
  https://claude.ai/code/artifact/85e4e3ef-d4b8-4242-81e9-bca0dac5f861
- `flows/click-around-current.wav` vs `flows/click-around-shaded.wav` — the
  same natural browse with and without textures. This is the decisive A/B.
- `reels/<material>.wav` — each material's takes; `reels/wood-anchor.wav` for
  the baseline clasp family.
- `qc.json` — sonic_taste_gate QC (onsets, tails, brightness, peaks).
- Phone speaker first, headphones second, per the established gates.

## Runtime status (already wired, dormant)

`Sfx.playInteraction` now takes the surface's `MaterialSound` and routes
(material × verb) to `room/materials/<material>/<verb>/<take>` — but only for
lanes named in `Sfx._shippedMaterialLanes`, which is EMPTY until a family
passes its phone gate. Call sites already declare their true materials (the
census regrouping moved faceted chips/commits to stone, tab/wizard travel to
parchment, and kept brass gold-only), so approving a lane means: copy its
takes into `assets/sfx/room/materials/`, add the lane string to
`_shippedMaterialLanes`, and extend the byte-lock test. Nothing else moves.
Regenerate candidates with `tool/author_room_material_shading_study.py`.
