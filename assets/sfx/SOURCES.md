# Sound-effect sources

## `tick.wav`, `tick_warm.wav`, and `tick_lift.wav`

- Source: [Soft App Button Tap Sound #2](https://pixabay.com/sound-effects/technology-soft-app-button-tap-sound-2-547872/) by Vadim_Makes_Sound.
- License: [Pixabay Content License](https://pixabay.com/service/license-summary/).
- Retrieved: 2026-07-27.
- Room of Days processing: the neutral tap was trimmed to 110 ms, converted to mono 44.1 kHz PCM, stripped of leading silence, high-passed at 80 Hz, low-passed at 5.2 kHz, warmed gently around 480 Hz, faded quickly, and given a conservative peak level.
- `tick_warm.wav`: a 3% lower, slightly darker variation of the neutral tap.
- `tick_lift.wav`: a 3% higher variation with a restrained upper-mid lift.

The app cycles through a six-tap cadence—neutral, warm, neutral, warm, neutral, lift—so repeated exploration receives subtle variation without random or melodic noise.

The source is free for use under the linked license. Attribution is retained here for provenance even though Pixabay does not require it.

## Material contact families

The five material families are short, baked PCM contacts rather than runtime
pitch effects. Each family has three deterministic variants so repeated taps
retain a coherent material identity without sounding mechanically identical.

### Wood, parchment, brass, and glass

- Source: [100 CC0 SFX](https://opengameart.org/content/100-cc0-sfx) by rubberduck.
- Original archive: <https://opengameart.org/sites/default/files/100-CC0-SFX_0.zip>
- License: [Creative Commons Zero (CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/).
- Retrieved: 2026-08-19.
- Source recordings used:
  - wood: `wooden_01.ogg`, `wooden_02.ogg`, `wooden_03.ogg`
  - parchment: `paper_01.ogg`, `paper_02.ogg`, `paper_03.ogg`
  - brass: `metal_02.ogg`, `metal_03.ogg`, `metal_01.ogg`
  - glass: `glass_01.ogg`, `glass_02.ogg`, `glass_03.ogg`

### Stone

- Source: [Various Sound Effects](https://opengameart.org/content/various-sound-effects-0) by Spring Spring.
- Original recording: <https://opengameart.org/sites/default/files/tap_stone.wav>
- License: [Creative Commons Zero (CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/).
- Retrieved: 2026-08-19.
- Source recording used: `tap_stone.wav`.

### Room of Days processing

The recordings were silence-bounded, trimmed to 170-220 ms contacts, converted
to mono 44.1 kHz 16-bit PCM, high- and low-passed by material, gently faded,
and peak-limited conservatively. Selected variants have a baked approximately
2 percent rate change to create subtle pitch and length variation. Parchment
contacts retain the recorded paper movement and include a quiet `tick_warm`
transient so the touch acknowledgment remains immediate. No material sound is
randomized or synthesized at runtime.

## `fire_ignite.wav`

- Ignition source: [Flare ignition](https://opengameart.org/content/flare-ignition) by qubodup.
- Fire-tail source: [Fireplace Sound loop](https://opengameart.org/content/fireplace-sound-loop) by PagDev.
- License: [Creative Commons Zero (CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/) for both sources.
- Retrieved: 2026-08-19.
- Room of Days processing: a restrained reverse-ignition lead-in creates the
  intake of the fwoosh, followed by the original flare, a quiet lower-pitched
  body, and a short real-fire tail. The final mono 44.1 kHz PCM cue is 2.18
  seconds and is authored for the once-per-app-session room ignition, not as a
  looping ambience bed.
