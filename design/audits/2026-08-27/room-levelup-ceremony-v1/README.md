# room-levelup-ceremony-v1 — the crown

**Owner direction (2026-08-27):** "make sure there's also an actually longer
celebratory sound for actual achievements like level ups" — given in the same
message that approved the longer-settle completion.

With completion now a 0.46 s settle, the level-up must clearly outrank it.
Three candidates against the shipped 0.95 s control, all grown from the
shipped phrase's own recipe (same contacts, modal bank, D-major field) under
render-polish discipline; celebration through weight and duration, never
brightness — "composed, no fanfare sparkle" stands.

| id | length | shape |
| --- | --- | --- |
| `control` | 0.95 s | the shipped levelup, byte-copied |
| `procession` | 1.9 s | shipped phrase + a resolving F#5→D5 arrival |
| `peal` | 2.15 s | rising walk D5-F#5-A5-B5 over a long root, crowned late |
| `crown-echo` | 2.4 s | shipped phrase, a breath, the crown echoed an octave down |

Fairness: whole-file RMS penalizes long settles, so candidates are matched on
the **first 0.95 s phone-band RMS** (control −26.60; procession −26.60,
crown-echo −26.62, peal −27.19 — its energy sits in the rising walk). All
peak-capped at −6 dBFS, QC clean. `flows/` plays two clasps → the new
completion → the ceremony.

**Ships with the winner (not before):** the levelup master byte-identical, a
byte-lock, and an extended owns-the-air window (levelup currently suppresses
ordinary taps for only 140 ms; a ~2 s ceremony should own roughly its
celebration body, ~700–900 ms — the tail may coexist with taps).

Reproduce:

```
python tool/author_room_levelup_ceremony_study.py \
    --output design/audits/2026-08-27/room-levelup-ceremony-v1
```
