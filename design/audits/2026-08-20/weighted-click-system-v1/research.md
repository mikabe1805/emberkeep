# Why a small click can feel satisfying

## Corrected target

This is not a stone, wood, glass, or brass Foley problem. The desired sensation
is an abstract control with enough mass to feel as if it moved and seated:

> i think youre taking stone too literally. im not looking for stone on stone sound system, more so the satisfying "dak" of clicking something with weight to it i guess? like it sounds like a satisfying interaction. maybe try to figure out why satisfying clicking sounds are satisfying to people and try to reverse engineer a sound system that sounds nice to click around on

The target is therefore a repeated **press → seat** gesture. Visual materials
may later tint this shared gesture, but a literal recording is not the identity.

## What the evidence supports

M. Ercan Altinsoy's controlled push-button experiments found that participants
described button sounds through pleasantness, confirmation, alerting,
irritation, and quality. Middle frequencies from 400–2,000 Hz were the most
suitable for confirmation; among the tested signals, a damped 1,200 Hz signal
was the strongest pleasant-confirmatory condition. Pleasantness fell above
2,000 Hz, and a 4,000 Hz condition was strongly irritating. A second impulse
5 ms after the first significantly increased confirmation for nearly every
condition, though its pleasantness benefit was only a trend. The same work
also showed that audio frequency changes perceived tactile strength.

Source: [Perceptual features of everyday push button sounds and audiotactile interaction](https://doi.org/10.1250/ast.41.173), Acoustical Science and Technology 41(1), 2020.

Touch-feedback timing also affects perceived quality. Kaaresoja, Brewster, and
Lantz found a subjective touch/audio simultaneity point around 19 ms in their
setup and a meaningful quality decline as delay entered roughly the 70–100 ms
region. This supports immediate pointer-down playback and rules out an awaited
action path for ordinary contact feedback.

Source: [Towards the Temporally Perfect Virtual Button](https://doi.org/10.1145/2611387), ACM Transactions on Applied Perception, 2014.

Apple's sound team supplies the strongest professional-system precedent:

- a quiet click precisely synchronized to haptics helped the solid iPhone Home
  button feel physical;
- changing only the synchronized sound changed how sharp and precise the same
  haptic tap felt;
- iOS keyboard clicks are deliberately non-identical, and their volume falls
  slightly during faster typing;
- Apple says even a 10 ms sound/haptic alignment change can affect the result;
- in a later UI example, Apple explicitly rejected literal window/projector
  recordings because they did not fit the system's aesthetic;
- frequently repeated sounds should remain subtle, slightly varied, and clean.

Sources: [Designing Sound, WWDC17](https://developer.apple.com/videos/play/wwdc2017/803/), [Explore immersive sound design, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10271/), and [Practice audio haptic design, WWDC21](https://developer.apple.com/videos/play/wwdc2021/10278/).

Microsoft independently cycles four versions of its frequently heard Focus
sound so the same one never plays twice in a row. The stated goal is to prevent
monotony while keeping this common cue subtle.

Source: [Sound for Windows apps](https://learn.microsoft.com/en-us/windows/apps/develop/ui/sound).

## Reverse-engineered working model

The following is a design hypothesis derived from the evidence, not a published
universal recipe:

| Phase | Starting target | Perceptual job |
| --- | --- | --- |
| contact | 0–4 ms; short controlled band-limited transient | immediate causality: “my finger did that” |
| weight | 4–38 ms; damped inharmonic 600–2,000 Hz body plus filtered excitation | gives a virtual control mass without sub-bass or a synthetic note |
| closure | 6 ms after onset; quiet 1–2 ms second impulse in two candidates | tests whether the mechanism feels seated rather than merely tapped |
| silence | 60 ms file, aggressively parked after 38 ms and below the tail gate by 55 ms | preserves clarity and leaves space for rapid interaction and outcomes |

The “dak” description is useful because its shape matches this model: a clean
leading consonant, a compact voiced body, and a dry stop. It is not being
implemented as speech or a sampled object.

## System contract

1. The shared contact gesture is more important than literal surface identity.
2. Every frequent-contact family contains five close microvariants and never
   repeats the exact variant immediately.
3. Pitch movement applies only to the damped inharmonic body, initially below
   one semitone; the contact remains stable and recognizable.
4. Rapid runs use one global contact-rate tracker and become about 0.6–1.1 dB
   quieter instead of accumulating energy. Very fast overlaps suppress the old
   tail and the active-voice count is capped.
5. The sound begins on pointer-down beside the visual press and selection
   haptic. It never waits for navigation or asynchronous completion.
6. A successful outcome may add a later cue; it does not replace the immediate
   contact. The contact file ends before the existing outcome separation around
   65 ms, preventing an accidental flam.
7. Navigation, commitment, completion, reward, and boundary feedback remain
   distinct roles. The click is not an error sound or a miniature reward.
8. Literal fire, paper, or mechanism sounds are reserved for interactions that
   visibly or semantically cause those events.
9. Phone speaker, rapid repetition, and the real haptic loop decide approval.
   Isolated headphones and model scores are diagnostics only.

## Four controlled mechanisms

All four use the same deterministic contact, inharmonic tuning, pitch walk,
rhythms, format, 60 ms file window, and common primary export gain. The study
is a strict 2x2 comparison. A second equal-energy pass is available only to
check whether a preference survives loudness matching.

| Blind ID | Hidden treatment | Boundary being tested |
| --- | --- | --- |
| A | light body, no closure | minimum weight versus thinness |
| B | weighted body, no closure | mass versus simple loudness |
| C | same light body, quiet 6 ms closure | closure benefit at low mass |
| D | same weighted body, same quiet 6 ms closure | closure benefit at higher mass |

No candidate is privileged and none represents a material. The body is an
inharmonic, noise-excited micro-mechanism rather than the previous dominant
gliding oscillator, specifically to avoid the tonal “boop” failure mode.

## What this study can and cannot prove

The published 5 ms second-impulse result supports stronger confirmation, not a
guarantee of pleasantness. The closure pair therefore remains a hypothesis for
Mika to accept or reject. Likewise, the primary weighted pair naturally carries
more energy; the equal-energy control shows whether “weight” survives when that
advantage is removed. Approval still requires the real app haptic, animation,
and phone speaker because audiovisual timing is part of the illusion.
