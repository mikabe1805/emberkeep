# Stone contact texture study v1

Status: **awaiting texture preference**. Nothing in this folder is wired into
the app. This study follows the note-palette result: pitch is held neutral so
the listener can judge whether the touch itself feels physical and satisfying.

The user priority captured for this pass is:

> hmm i like all of them i guess, none of them stand out to me as clearly better than the rest. what i care more about is the texture sound so it actually feels like youre tapping like a satisfying stone tap when interacting with the right material

## Listen before reading the key

Start with `stone-texture-rapid-reel.wav`. It plays A through F in order using
the same ten-tap rhythm for every candidate.

| Candidate | Rapid-reel first contact |
| --- | ---: |
| A | 0.32 s |
| B | 2.29 s |
| C | 4.27 s |
| D | 6.24 s |
| E | 8.22 s |
| F | 10.19 s |

Then use `stone-a.wav` through `stone-f.wav`. Each file first plays six slower
contacts, then ten rapid contacts. The useful response can be as simple as
`D`, `A and D`, `E feels crisp but fake`, or `none of them feel like stone`.
“No preference” and “all bad” remain valid results.

Judge the texture rather than the tune:

1. Does it feel like a hard mineral surface made contact under your finger?
2. Is the first edge crisp without becoming sharp or cheap?
3. Is there enough body to feel satisfying without turning into a wooden knock?
4. Does rapid tapping stay tactile, or does the tail smear into a sound effect?

The phone speaker is the decision environment. Headphones are useful for
finding hiss, room sound, or harshness, but do not substitute for a phone pass.

## Controlled variables

Every candidate has:

- the same two real concrete-on-concrete contact events;
- the same order, velocity contour, six-contact measured rhythm, and ten-contact rapid rhythm;
- a 142 ms maximum envelope with no reverb or audible file tail;
- no oscillator, note sequence, global pitch shift, synthesized resonance, or ambience;
- only bands taken from the original physical contact, reshaped to test body, mineral detail, and edge;
- the same rapid-pass phone-band RMS, so a louder render does not win by default;
- 48 kHz, 24-bit PCM stereo output with effectively lossless mono fold-down.

This is deliberately a **dry mineral/concrete-contact** study. Concrete is a
credible first proxy for the app's stone material family, but the audition—not
the filename—must decide whether it actually reads as the desired stone touch.

## Blind key — read after listening

| Candidate | Treatment | What it tests |
| --- | --- | --- |
| A | dry real contact | whether the physical recording already supplies enough tactile credibility |
| B | body-forward | more low-mid mass without a longer room tail |
| C | mineral-forward | more hard-surface definition while staying below the harsh upper band |
| D | balanced body + mineral | whether a designed middle feels more complete than the raw contact |
| E | polished edge | the crispness ceiling; intentionally the main harshness-risk candidate |
| F | heavier body | the weight/decay ceiling; intentionally the main muddiness-risk candidate |

The treatment is parallel filtering of the real contact, not a tonal layer.
The actual note-changing system stays out of this audition until one material
texture is approved.

## Source and license record

The physical source is Adobe's uncompressed
`Foley Concrete Set On Concrete 01.wav`, downloaded in the official Foley ZIP
from [Adobe Audition Sound Effects](https://www.adobe.com/products/audition/offers/audition-dlc.html).
Adobe describes the library as royalty-free. Its current
[Content Files terms](https://www.adobe.com/legal/terms.html#content-files)
permit modification and distribution when embedded in an end use such as an
app, while prohibiting standalone redistribution.

The original WAV stays outside the repository in the source cache. Only short,
processed audition renders are present here. The verified original SHA-256 is:

`0376417edbf134682f5b654db6892b747a5261d41c55c6778ee1c00991bad853`

If a candidate ships, the source URL, hash, bundled Adobe license, and exact
edit recipe must move into the app's third-party asset record. The sound must
remain embedded feedback, not a user-downloadable sample.

## Technical and advisory checks

`qc.json` covers all eight WAV files. Every file parses correctly, contains no
clipped samples, has negligible DC, ends cleanly, and folds to mono without a
meaningful level loss. `metrics.json` records the matched timing, loudness, and
broad texture balance. The authoring recipe is
`tool/author_stone_texture_study.py`; its source hash check prevents silently
substituting a different recording.

Meta's Audiobox Aesthetics was used only to catch an accidental export-quality
outlier. Production-quality estimates occupy a narrow 7.39–7.54 range across
the six candidates. The model does not hear through the user's taste, certify
that a cue feels like stone, or select a winner.

Reference principles behind the controlled study:

- [Perceptual inference for impact sounds](https://mcdermottlab.mit.edu/papers/Traer_Cusimano_McDermott_2019_DAFx.pdf)
- [Frequency-dependent decay as a material cue](https://oamonitor.ireland.openaire.eu/rpo/rcsi/search/publication?pid=10.1162%2F105474600566907)
- [Apple audio and haptic feedback guidance](https://developer.apple.com/design/human-interface-guidelines/playing-haptics)

## After a texture is selected

The chosen treatment advances to an in-app pointer-down and haptic test. Only
then should it receive 3–5 related micro-variants and the quieter note-changing
layer. No audition candidate should replace `assets/sfx` before that contextual
phone-speaker pass.

