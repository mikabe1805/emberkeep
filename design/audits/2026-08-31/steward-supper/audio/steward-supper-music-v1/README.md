# steward-supper-music-v1 — one loopable room theme, awaiting your ears

**Status: sonic study for explicit owner audition. Nothing here is approved.**

## Where this comes from

The music you remembered was found: two full studies rendered 2026-08-29
(`room-music-v1`, `room-music-pulse-v1`) were sitting **uncommitted** in the
`release-final` worktree's working directory — never committed to any branch,
which is why the read-only audit found no music in Build 37. They are
preserved byte-for-byte with verified hashes in `../recovered/`, along with
their deterministic recipes and a full approval-state record
(`../recovered/RECOVERY.md`).

What was approved on 2026-08-29 was the **direction**, verbatim: sparse
D-pentatonic music grown from the room's own sound modules, taps consonant
with the bed, and "how the buttons could be on beat with the background
music". No candidate file was ever auditioned; both LISTENING-RESULT files
are still blank.

## What this study is

One 112-second piece, **composed as a seamless loop** because runtime
(`lib/background_music.dart`) plays `music/room-theme.m4a` with
`ReleaseMode.loop` at the final measured volume **0.35**. The 2026-08-29 beds answered the
fire-loop complaint by never repeating; a bundled asset must loop, so this
piece answers it differently — it is long enough and shaped enough that the
repeat is a returning chapter, not a jingle. 28 bars of 4/4 at 60 bpm:

- bars 0–3 — air and the softest tread: the room, inhabited
- bars 4–11 — three low phrases under candlelight
- bars 12–18 — supper by the window: low statements, falling high answers
  (the rain is not literal noise — it is the shape of the answers, stepping
  only downward, settling on D or A)
- bars 19–24 — a gentle wander, the quiet high point, still readable-over
- bars 25–27 — one closing phrase settles on D and decays into the loop's
  opening air; the seam lands in the sparsest bars

Human-feeling restraint is deliberate: eighth-note grid humanized ±15 ms,
phrase velocities arched toward the middle with a quieter last word, the
final phrase's last spacing broadened 1.8× like a sentence ending, per-note
pitch drift of a hand-played instrument. No harsh pings, no fairy dust, no
synthetic beat — the only pulse is a shallow bar-tide in the air and a
near-subliminal tread that skips bars so it never becomes a metronome.

**Honesty about the instrument:** this is the room's own modal voice (the
same physics as every approved tap) given a soft bloom attack — a lamplit,
thumb-piano-adjacent tone. It is not a piano and is not pretended to be one;
credible piano/strings are beyond honest local synthesis, and the room
already speaks this voice, so music and interactions share one world by
construction. Every pitch sits on the D-major pentatonic field; the Paired
Return motif (D5 A5 E5 D5) is excluded by assertion.

## Files

| file | what it is |
| --- | --- |
| `master/steward-supper-theme-master.wav` | 112.000 s, 48 kHz mono PCM_24 — the master |
| `../../../../../assets/music/room-theme.m4a` | AAC-LC 96 kbps bundle of the master (1.38 MB) |
| `evidence/loop-seam-audition.wav` | the last 10 s followed by the first 10 s — exactly what looping playback crosses |
| `evidence/audition-reel-player-gain.wav` | 32 s of ordinary product use: approved SFX at shipped levels over the music at runtime volume 0.35, including completion, a reading silence, and a rapid-tap burst |
| `evidence/audition-reel-master-level.wav` | same reel with music at master level, for reference |
| `evidence/music-only-player-gain.wav` | first 40 s of the piece at volume 0.35 — is it audible-but-ignorable? |
| `evidence/decoded-room-theme.wav` | the bundled m4a decoded back to PCM — proof the shipped file plays |
| `evidence/master-spectrogram.png` | the piece's shape; seam at 0/112 s |
| `measurements.json`, `manifest.json`, `qc.json`, `test-results.json` | numbers, hashes, provenance, 18/18 limit+decode checks, house QC 6/6 |

## Measured (verified this run, 2026-08-31)

- integrated loudness **−24.00 LUFS** (BS.1770-4, own implementation), true
  peak −10.74 dBTP, sample peak −10.74 dBFS, DC ≈ 0
- at final runtime volume **0.35** (−9.1 dB linear), the effective level is
  **−33.12 LUFS** / **−35.82 dBFS phone-band**. That is the final local mix
  setting after the master was measured at −24.00 LUFS / −26.70 dBFS
  phone-band; owner phone/headphone approval remains pending
- loop seam: the sample step across end→start is **0.46×** the piece's own
  99.9th-percentile sample step (no click; the drone is generated with an
  8 s wrap-crossfade and phrase tails wrap modulo the loop), seam-window
  levels −21.0 → −21.8 dBFS
- bundled AAC decodes to **exactly 5,376,000 frames (112.000 s, 0.0 ms
  drift)** at −24.01 LUFS, correlation 0.9998 against the master

Reproduce: `python ../author_steward_supper_music.py` (deterministic, seeds
13000–13400, offline, no external services, no samples).

## Remaining gates — what the numbers cannot decide

1. **Nobody has listened to this yet.** I have no listening facility; every
   claim above is measurement, not taste. Phone-speaker and headphone
   audition by the owner is the gate that matters, per
   `LISTENING-RESULT.md`.
2. **Loop gaplessness on device.** The m4a decodes sample-exactly under an
   edit-list-honoring decoder (ffmpeg verified; Apple honors edit lists).
   Whether `audioplayers`' `ReleaseMode.loop` restarts without an audible
   gap on the real iPhone is a runtime property only a device test can
   observe. If it gaps, the master WAV is the source for any re-encode or a
   player-side gapless path.
3. **The in-app volume dial** is now 0.35 after the measured local mix
   review. It is still subject to the owner's phone/headphone verdict; the
   master deliberately leaves headroom for a later adjustment.
4. Whether the room wants this much music at all — "keep the room quiet" is
   still a legitimate verdict, as the recovered study said.
