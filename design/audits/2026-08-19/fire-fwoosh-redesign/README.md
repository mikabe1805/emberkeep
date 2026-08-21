# Fire fwoosh redesign

These are the audition alternatives for the once-per-session hearth ignition.
The user selected C on 2026-08-19, and that exact render now owns
`assets/sfx/fire_ignite.wav`.

## What the reference is doing

The Krotos example behaves like one pressure gesture rather than a fire bed or
musical cue. Its softer fwooshes gather for roughly 0.9 seconds, crest in a few
uneven waves, and release within about 0.6 seconds. Their center of gravity
moves through 120-300 Hz, with useful 300-1000 Hz turbulence, restrained hiss,
and natural stereo width. The current app cue peaks around 0.55 seconds and is
dominated by a fixed sub-heavy mono body.

The candidates therefore contain no pitched afterglow, oscillator, copied
reference audio, or hard limiter. They are 1.70-second 48 kHz stereo gestures
made from recorded fire, with the crest near 0.9 seconds.

## Candidates

- `fwoosh-a-warm-pressure.wav` — darkest and softest; closest to the first two
  restrained fwooshes in the reference.
- `fwoosh-b-living-flame.wav` — more low-mid turbulence and air; closest to the
  fuller later fwooshes while remaining much softer than the rejected cue.
- `fwoosh-c-hearth-bloom.wav` — **selected master**; roundest and most
  fireplace-like, built from a real flare recording with the calmest high end.
- `fire-fwoosh-audition-reel.wav` — A, B, and C in that order, separated by
  950 ms of silence.

## Source and licensing

The user's [Krotos example](https://www.youtube.com/watch?v=BbyYOTNK1Ao) was
used for timing and spectral comparison only. No reference samples appear in
these files.

Recorded ingredients are CC0:

- [Flamethrower short and medium bursts](https://freesound.org/s/395038/) by
  AslakHostaker, 48 kHz / 24-bit WAV.
- [Flamethrower loop](https://freesound.org/s/563138/) by Nox_Sound, 48 kHz /
  24-bit stereo WAV.
- [Flare ignition](https://opengameart.org/content/flare-ignition) by qubodup.
- [Open-door fireplace](https://freesound.org/people/Sadiquecat/sounds/853081/)
  by Sadiquecat, uploaded at 96 kHz / 32-bit stereo.

The two new Freesound layers use their official public high-quality previews.
Their lossless WAV download endpoints require a Freesound login, and no
legitimate unauthenticated mirror was found. To preserve the exact sound the
user approved, C was promoted unchanged; do not call it an all-lossless source
chain. An authenticated rerender can be A/B tested later without silently
changing the selected master.

## Rebuild

`tool/author_fire_fwoosh_candidates.py` contains the deterministic fire-only
authoring recipe. It writes only to an explicit staging directory; promotion
to the runtime asset is an intentional copy after selection. The general
interaction authoring tool does not own or overwrite the fire master.
