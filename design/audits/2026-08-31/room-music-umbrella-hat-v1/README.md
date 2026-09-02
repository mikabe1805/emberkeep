# room-music-umbrella-hat-v1 — umbrella won; what carries its eighths now?

**Owner verdict (2026-08-31, verbatim, in order):**

> i really enjoy windowseat best, but best to leave out the rain sounds etc. they arent needed in the first place, and they dont even sound like rain they sound like bubble taps? i mean i kind of enjoy that sound effect so it can be used for a later app's tapping sound

> actually umbrella is the best one

**Question this study asks:** the droplet voice is rejected as it sounds
("bubble taps"), and umbrella — the winner — is the one candidate whose
percussion design leaned on it (the rain was the hi-hat). Removing it is not
a neutral subtraction; it changes the groove. So the fork is resolved by ear,
not by assumption: the SAME umbrella performance three ways — every chord,
bass note, thump, rim, and motif byte-identical — differing only in the hat.

| id | the hat | what to listen for |
| --- | --- | --- |
| `umbrella-rain` | the auditioned original (byte-identical to room-music-v2's `umbrella.wav` — the manifest hashes prove it) | the reference point |
| `umbrella-bare` | removed entirely — thump, rim, keys, bass, motif, nothing else | does the head-nod still breathe with no eighth-note air at all? |
| `umbrella-brush` | a dark swung shaker-brush on the eighths: the windowseat shaker's grain family, alternating strong/weak, dragging 8–20 ms with the kit, an occasional skipped grain | the lofi "dark closed hats" grammar — nothing droplet-like |

The bubble-tap idea is on file, not lost: the droplet grain synth
(`_rain` in `tool/author_room_music_v2_study.py`) is kind-of-liked as a
possible tapping sound for a LATER app — recorded in room-music-v2's
LISTENING-RESULT. Not for Room of Days.

Fairness: all three level-matched at −36.0 dBFS phone-band RMS under the
−6 dBFS ceiling; the underlying performance is byte-identical by
construction (the brush lives on its own seed stream, 13190). QC clean
(`qc.json`, 6/6 ok, no clipping); continuity law holds (the only quiet
window in bare/brush is the final fade-out itself); deterministic — a second
render is byte-identical. Flows place the untouched interaction masters on
v1's schedule, as always.

A winner here becomes the shipped umbrella voice: a GENERATIVE in-app
system (never a fixed loop) + Music toggle + iOS ambient session + duck
under earned sounds, with the answers-on-the-beat mechanic riding it — that
implementation is its own pass. Record the verdict verbatim in
`LISTENING-RESULT.md`.

Reproduce:

```
python tool/author_room_music_umbrella_hat_study.py \
    --output design/audits/2026-08-31/room-music-umbrella-hat-v1
python tool/sonic_taste_gate.py qc \
    --json-out design/audits/2026-08-31/room-music-umbrella-hat-v1/qc.json \
    design/audits/2026-08-31/room-music-umbrella-hat-v1/candidates \
    design/audits/2026-08-31/room-music-umbrella-hat-v1/flows
```
