# room-event-voice-v1

Status: **candidates rendered, awaiting the owner's listening pass.** Runtime
assets are unchanged.

## What this study is

The last remaining Gen-1 palette — `streak`, `crit`, `loot`, `levelup`,
`boing`, and `stat_0..5` — still ships as bare sine blips from a different
acoustic world than the approved everyday X clasp. Owner feedback (2026-08-21,
verbatim in `manifest.json`) named the result: tapping around "all just sounds
like the same popping sound that feels like a popping bubbles stim toy".

Every candidate here is derived from the locked Room chain — the approved C
contact master, the modal body bank, the close reflection fingerprint, and the
D-major pentatonic field — so outcomes finally live in the same Room as the
clasps while each keeps a distinct gesture:

| Event | Gesture |
| --- | --- |
| streak | one catch, root, fifth above — the permitted two-note answer |
| crit | weighted double catch, denser body — heavier, never brighter |
| loot | three finds rising; the last opens into the room (discovery) |
| levelup | sparse ceremony phrase ending in a blooming crown dyad |
| boing | two soft catches stepping down — friendly through softness |
| stat_0..5 | one light find per stat, ascending D E F# A B D |

## How to listen

- Browser A/B desk (level-matched controls, context flows, playable stat run):
  https://claude.ai/code/artifact/85e4e3ef-d4b8-4242-81e9-bca0dac5f861
- Or play the files directly: `events/` vs `controls/current-*.wav`, and
  `flows/*/candidate.wav` vs `flows/*/current.wav` for in-context listens.
- Phone speaker first, headphones second, per the established gates.

## If a candidate ships

Copy it over its name in `assets/sfx/` and move its `Sfx._volume` entry to
1.0 — like the other Room masters, candidates carry their intended phone level
in the file. Regenerate or re-render with
`tool/author_room_event_voice_study.py`.
