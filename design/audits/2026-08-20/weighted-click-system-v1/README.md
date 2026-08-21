# Weighted click system v1

Status: **awaiting interaction-feel preference**. Nothing here is wired into
the app. This supersedes the literal stone-contact audition.

## Best way to listen

Open `index.html` through the local study server, press **Start sound lab** once,
and click A–D yourself. Tap slowly, then use each **play 10-tap run** control.
The explicit start gesture removes the browser's first-click unlock delay. The
interactive version cycles five close microvariants, never repeats one
immediately, and quietly reduces rapid-tap gain.

If the interactive page is unavailable, start with
`weighted-click-rapid-reel.wav`, then compare `dak-a.wav` through `dak-d.wav`.
Each candidate file contains a measured pass followed by a rapid pass.

The only question that matters on the first pass is:

> Which one feels most satisfying to press and still feels good rapidly?

Responses such as `B`, `B and C`, `A feels responsive but thin`, or `all bad`
are more useful than trying to identify what the sound resembles.

## What is controlled

- A–D form a controlled 2x2 study, not four unrelated materials: light versus
  weighted body, each with or without the same quiet closure.
- Every family has five related variants and the same non-repeating walk.
- Pitch variation stays inside the compact body; the contact identity is fixed.
- The primary pass preserves one identical contact gain across all four. The
  optional **equal-energy check** controls for simple loudness preference.
- Every single click is a 60 ms, 48 kHz, 24-bit PCM mono file and is effectively
  parked before the app's later outcome cue can begin.
- There is no recorded Foley, room tone, reverb, sample-library encoding, or
  background noise.
- The recipe is deterministic four-times-oversampled synthesis with band-limited
  export and 24-bit dither.
- Runtime assets and `lib/audio.dart` remain unchanged.

## Blind key — read after clicking

| Candidate | Character | Main risk |
| --- | --- | --- |
| A | light body, single contact | too thin |
| B | weighted body, single contact | mass may just read louder |
| C | light body, quiet 6 ms closure | closure may be unnecessary |
| D | weighted body, same quiet 6 ms closure | most mechanism, potentially busy |

`research.md` separates the published findings from the working “dak” model.
`metrics.json`, `qc.json`, and `session.json` contain the technical and blind-
comparison records. `tool/author_weighted_click_study.py` is the reproducible
authoring recipe.

`metrics.json` separately measures the first 4 ms transient, the 4–28 ms body,
the closure window, crest factor, spectral flatness, and the tail after 55 ms.
That avoids the old analysis bug that windowed away the onset. `qc.json`
contains the independent lossless-file checks. No model score decides which
click is satisfying.

## Approval gate

A winner is still only a mechanism direction. Before replacing app assets it
must be heard through the real `Pressable` pointer-down path with the existing
selection haptic, on a phone speaker, during an actual quest/navigation loop.
Then it can be expanded into interaction roles without losing the shared click
identity. Browser vibration is labeled as such and is not a substitute for the
app's actual haptic timing.
