# C-derived click families

Status: **awaiting weight and finish preference**. Nothing in this folder is
wired into the app.

## Listen in this order

1. Press **Start sound lab** once.
2. Replay **C anchor**. It is copied byte-for-byte from the approved study.
3. Compare **Light**, **Settled · C**, and **Weighty**. Each keeps the same
   contact and 6 ms closure; only the compact body changes.
4. Choose a weight, then compare **Warm room**, **Soft page**, **Clear lens**,
   and **Quiet gilt** at that weight.
5. Use the ten-tap runs after the single taps. A finish that is pleasant once
   but annoying in rhythm is not a production candidate.
6. If one option wins easily, enable **equal-energy check** and verify it still
   wins when simple loudness advantage is removed.

Useful feedback is as short as `settled + page`, `light + lens`, `C is still
better`, or `the weights work but all finishes are worse`.

## What is fixed

- C's 60 ms contact → body → 6 ms closure gesture remains the identity.
- The anchor WAVs are byte-identical copies of the approved candidate.
- Contact and closure timing never change across weights.
- Five related microvariants use one no-repeat walk.
- Rapid runs soften globally instead of accumulating loudness.
- Every family is dry, mono, lossless PCM24, and effectively silent by 55 ms.
- There is no recorded Foley, room sound, reverb, or sample-library residue.

## What changes

Weight changes only body gain and damping:

| Weight | Intended role |
| --- | --- |
| Light | selectors, chips, toggles, tabs, and browsing |
| Settled · C | ordinary cards, dates, and room controls |
| Weighty | place, save, commit, and primary actions |

Finish is a restrained spectral tint, not an object recording:

| Finish | Intended role |
| --- | --- |
| Warm room | general room objects and routine controls |
| Soft page | calendar, journal, notes, planning, and insights |
| Clear lens | switches, pickers, sheets, previews, and utility controls |
| Quiet gilt | honey buttons and durable choices |

The old literal `stone` idea is intentionally absent. A grounded control is a
weight decision; the visual surface does not need rock-on-rock Foley.

## Approval gate

A favorite here is a family direction, not automatic runtime approval. It must
still be heard through Flutter's raw pointer-down path with the real selection
haptic and press animation on a phone speaker. Outcomes such as completion,
save, and rewards remain separate later events.

