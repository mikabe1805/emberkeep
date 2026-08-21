# Repeated-tap note palette study v1

Status: **completed with no meaningful preference**. Nothing in this folder is
wired into the app. On 2026-08-20 the user reported that none of A–F stood out
as clearly better and that material texture mattered much more.

This is useful evidence, not a failed audition. Pitch can remain a subtle
secondary variation layer, but it should not lead the next design decision.
The next controlled study must isolate physical material texture, beginning
with a satisfying stone contact.

## Listen before reading the key

Start with `note-palette-rapid-reel.wav`. It plays A through F in order, using
the same rapid eight-tap rhythm for every candidate.

| Candidate | Rapid-reel first note |
| --- | ---: |
| A | 0.36 s |
| B | 2.40 s |
| C | 4.45 s |
| D | 6.49 s |
| E | 8.54 s |
| F | 10.58 s |

Then use `palette-a.wav` through `palette-f.wav` for closer listening. Each
individual file plays its phrase once at a measured pace and once at a pace
closer to someone tapping around the interface.

The useful response is not a theory critique. Record a first impression such
as `C`, `A then C`, `B is nice slowly but annoying fast`, or `all bad`. “Both
bad” and “no preference” are first-class preference data; choosing a least-bad
option is not required.

Do not judge whether the carrier resembles wood, parchment, or brass yet. Ask:

1. Do the note changes make tapping feel more fun?
2. Does the rapid version feel like a phrase rather than a scale exercise?
3. Would the pattern remain pleasant after many short sessions?
4. Is any jump distractingly large, childish, triumphant, or notification-like?

## Controlled variables

Every candidate has:

- the same D5 starting note;
- eight note events and the same two rhythms;
- the same 165 ms carrier and dynamic contour;
- identical peak level and file length;
- the same dry, close mastering with no room recording, reverb, or lossy source;
- 48 kHz, 24-bit PCM stereo output with near-perfect mono compatibility.

The carrier is a deterministic, four-times-oversampled soft-mallet hybrid. A
very short shaped-noise impulse supplies the touch; a centered band-limited
tonal body supplies pitch. It is deliberately neutral and is not proposed as
the final surface sound.

## Blind key — read after listening

| Candidate | Pitch collection from D | Phrase intervals | What it tests |
| --- | --- | --- | --- |
| A | major pentatonic | `0 2 4 7 9 7 4 2` | small-to-medium steps and easy melodic continuity |
| B | major with added sixth | `0 4 9 12 9 7 4 0` | a clearer arc and satisfying return |
| C | Lydian major | `0 2 6 7 11 12 7 2` | a brighter, spacious game-like color |
| D | open fifths | `0 7 12 7 14 12 7 0` | strong, simple intervals with little decorative color |
| E | major triad across octaves | `0 4 7 12 16 12 7 4` | familiar harmony and a more pronounced climb |
| F | stacked fourths | `0 5 10 12 17 12 10 5` | modern spaciousness and wider jumps |

No candidate was designed to be dark or deliberately unresolved. The broader
music reference only established that phrase development matters; it did not
select an emotional mode for Room of Days.

## Technical and advisory checks

`qc.json` covers every WAV. All eight rendered files pass format inspection,
contain no clipped samples, end cleanly, and fold to mono without meaningful
loss. `metrics.json` records the exact notes, timings, loudness, and broad
spectral balance.

Meta's Audiobox Aesthetics was run as an advisory export check. Its production-
quality estimates fell in the narrow 8.39–8.47 range for all six candidates,
which is useful evidence that one palette was not accidentally rendered much
better than another. The model does not select a winner.

## After a palette is selected

The winning interval grammar advances to a second controlled study with three
modern contact/timbre treatments. Only then should it be tried on an actual
press-and-haptic loop. The selected note lane remains quieter than the material
contact, opt-in for compatible repeated actions, and lower priority than earned
completion or discovery cues.

The deterministic authoring recipe is
`tool/author_note_palette_study.py`. The pairwise comparison manifest and
session are `manifest.json` and `session.json`.

Reference principles:

- [Apple Designing Sound](https://developer.apple.com/videos/play/wwdc2017/803/)
- [Apple Explore immersive sound design](https://developer.apple.com/videos/play/wwdc2023/10271/)
- [Mojang sound definitions](https://github.com/Mojang/bedrock-samples/blob/main/resource_pack/sounds/sound_definitions.json)
- [Web Audio API timing model](https://www.w3.org/TR/webaudio-1.0/)
