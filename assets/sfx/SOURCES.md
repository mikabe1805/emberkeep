# Sound-effect sources

> **Current status (2026-08-25):** the production everyday family is the
> phone-approved X clasp under `room/ordinary/`. The older `tap_*`, `tick*`,
> `complete.wav`, and `hearth_room.wav` files were archived compatibility
> assets: the user rejected their sound quality and near-static note
> variation, and runtime no longer routed to them. On 2026-08-25 their bytes
> were removed from the bundle entirely (~0.6 MB); this provenance record and
> the approved-study archives under `design/audits/` remain the reference.
> Do not extend the archived recipe. `hearth.wav` stays bundled pending the
> owner's decision on optional hearth ambience (see DESIGN-BIBLE.md).

## Production Room interaction family

`room/ordinary/<open|select|navigate|place>/1..5.wav` contains the selected X
mechanism from `room-c-gesture-v3`: one complete 60 ms contact, compact body,
and explicit 8.5 ms clasp. All 20 masters are mono 48 kHz / 24-bit PCM and
carry the common `+1.5 dB` level that was approved through an iPhone built-in
speaker. Runtime selects from one global non-repeating variant walk and only
softens legitimate rapid taps; it never pitch-shifts the masters.

The X family is deterministic project-authored synthesis. It uses no recorded
Foley, sample library, room tone, reverb, or reference-video audio. The release
repository retains the exact selected X masters under
`design/audits/2026-08-20/room-c-gesture-v3/roles/c-clasp-family/`, their
manifest, and the authoring recipe in `tool/author_room_c_gesture_v3_study.py`.
Rejected weighted-click candidates and long audition reels are deliberately
not part of the release package.

`room/completion/completion-composite.wav` is the immutable accepted Select-2
contact followed by the selected Answered Detent exactly 75 ms later. The two
source masters are retained beside it for hash/provenance checks. Runtime plays
the precomposed file for delayed or non-Pressable completions; when a visible
bob already voiced contact, it plays the locked `answered-detent-natural.wav`
outcome instead of layering another generic tap over the same touch.
This completion is also deterministic project-authored synthesis and contains
no third-party or reference-video audio. The 460 ms atomic master is copied
byte-for-byte from `room-completion-voice-v2/candidates/longer-settle.wav`
(owner-approved 2026-08-27: "the longer settle sounds good!") — the same
gesture re-rendered under render-polish discipline with a 0.36 s settle; the
bare detent ships as its `locked/answered-detent-longer-settle.wav` twin.
The similarly named v3 `locked/completion-composite.wav` is a 6.1-second study
flow with its completion parked at 5.3 seconds; it is audit evidence, never a
runtime cue.

`room/materials/<slate|page|glass|brass>/<verb>/1..3.wav` contains the nine
phone-approved material texture lanes (gestures approved in
`room-material-shading-v1`, shipped as the `room-material-shading-v2-polish`
render on the owner's 2026-08-21 final verdict). Each lane is a body/grain
shading of the same X contact master, reflection fingerprint, and pentatonic
tokens — deterministic project-authored synthesis, no recorded Foley —
copied byte-for-byte from the v2-polish audition masters and regenerable via
`tool/author_room_material_shading_study.py --polish`. Runtime routes a
surface's declared `MaterialSound` onto these lanes and falls back to the
plain clasp for anything undeclared.

`streak/crit/loot/levelup/boing/stat_0..5.wav` are the phone-approved event
voices (gestures approved in `room-event-voice-v1`, shipped as the
`room-event-voice-v2-polish` render on the owner's 2026-08-21 final
verdict), derived from the same Room chain and calibrated in-file to their
natural phone-band targets — runtime plays them at volume 1.0. They replaced
the last Gen-1 synthesized sine palette. Regenerable via
`tool/author_room_event_voice_study.py --polish`; the shipped copies live
under `design/audits/2026-08-21/room-event-voice-v2-polish/events/`.

`room/paired_return/<d5|a5|e5>/<open|select|navigate|place>/1..5.wav`
contains the 60 physically approved Paired Return masters. Each is copied
byte-for-byte from the corresponding v4 cue and contains one complete X take
plus its dry 60 ms meaning resonance in a single file, preventing runtime
scheduling jitter. The owner passed the corrected gate on an iPhone 17.

Plain X with slight physical variation remains the everyday voice. Only after
four accepted actions spaced 180–700 ms apart may the next four eligible
actions carry D5 → A5 → E5 → D5. The return is limited to once per stable
screen and a global 90-second cooldown; rapid input or completion clears it
without catch-up. A4, F#5, the longer v4 phrases, and all audition reels remain
study evidence and are not production assets.

## Archived material-study language

The retired material study used real recorded objects and acoustic instruments.
It shared a D-centered suspended pentatonic vocabulary—C, D, E, G, and A—to
test harmonic continuity without an accidental tune. This describes archived
provenance only; none of these contacts are part of the production everyday
voice.

That archived palette deliberately avoided synthetic sparkle layers. A real
contact owned the first 5-12 ms, followed by a short, damped acoustic
resonance. The result aimed to feel closer to touching a small enchanted
object than triggering a notification.

`tick.wav`, `tick_warm.wav`, and `tick_lift.wav` use the same CC0 wood contact
and Sansula sources documented below. They retain the retired study's six-beat
cadence for provenance and compatibility, not as the current Room interaction
direction.

## Archived material contact families

The five material families are short, baked PCM contacts rather than runtime
pitch effects. Each family has three deterministic variants so repeated taps
retain a coherent material identity without sounding mechanically identical.

### Physical-contact sources

All five source recordings are released under
[Creative Commons Zero (CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/).
The linked license and source metadata were verified on 2026-08-19. Room of
Days used Freesound's high-quality public preview encodes as its working copies.

- Wood: [wood tap.wav](https://freesound.org/people/mealwyrm/sounds/495814/)
  by mealwyrm. A drumstick on a small wooden box, recorded on a TASCAM field
  recorder. Three separate contacts from the recording are used.
- Stone: [small stones dropped on wooden table 1](https://freesound.org/people/FOSSarts/sounds/740544/)
  by FOSSarts. Rough garnet crystals recorded on a Zoom H1 Essential. Three
  separate, isolated contacts are used.
- Parchment: [Paper slide 2](https://freesound.org/people/brokenmachinery/sounds/730078/)
  by brokenmachinery. Three gentle paper-slide gestures.
- Brass: [Metal Click.wav](https://freesound.org/people/Sheyvan/sounds/475195/)
  by Sheyvan. Three separate contacts from the recording are used.
- Glass: [Glass Tap 2](https://freesound.org/people/CJspellsfish/sounds/668383/)
  by CJspellsfish. Finger taps on glass.

### Acoustic-resonance sources

All three acoustic recordings are also released under CC0 1.0.

- [Hokema Sansula F](https://freesound.org/people/cabled_mess/sounds/380739/)
  by cabled_mess. A Rode NT5 recording of an acoustic thumb-piano note. It
  supplies the warm wooden body for wood and legacy tick contacts.
- [Small brass sound bowl, medium ring](https://freesound.org/people/FOSSarts/sounds/762642/)
  by FOSSarts. A 96 kHz recording of a small brass bowl struck with a wooden
  mallet. It supplies the restrained brass fifth.
- [Glass bowl, cloth mallet](https://freesound.org/people/Anthousai/sounds/448071/)
  by Anthousai. A TASCAM DR-40 recording of a glass bowl struck with a cloth
  mallet. Its resonance is retuned and differently damped for stone,
  parchment, and glass.

### Room of Days processing

The recordings were converted to mono 44.1 kHz 16-bit PCM. Every voice starts
with a softened physical contact, then blooms 7-12 ms later into a short real-
instrument dyad. Total lengths range from 133-190 ms; natural resonance is
damped by family and exits through a 13-16 ms fade. Final asset peaks sit
between -8.5 and -10 dBFS before the app's per-family playback volume.

The five identities are D/A for wood, G/D for stone, E/A for parchment, C/G
for brass, and A/E for glass. Variants retain the same interval while changing
the contact, balance, length, and tuning by only three cents. Nothing is
randomized or pitch-shifted at runtime. The offline authoring recipe lives in
`tool/author_fantasy_sfx.py`.

## `fire_ignite.wav`

All production sources are CC0 and were retrieved on 2026-08-19:

- [Flare ignition](https://opengameart.org/content/flare-ignition) by qubodup.
  The original FLAC supplies the round hearth catch.
- [Flamethrower short and medium bursts](https://freesound.org/s/395038/) by
  AslakHostaker. A performed burst supplies the moving 120-1000 Hz pressure
  body. The source page identifies the original as 48 kHz / 24-bit mono WAV;
  the final approved render uses Freesound's public high-quality preview.
- [Open-door fireplace](https://freesound.org/people/Sadiquecat/sounds/853081/)
  by Sadiquecat. A very quiet filtered excerpt supplies the living fire edge.
  The source page identifies the upload as 96 kHz / 32-bit stereo WAV; the
  final approved render uses Freesound's public high-quality preview.

The user's [Krotos fire-whoosh example](https://www.youtube.com/watch?v=BbyYOTNK1Ao)
was used only as a structural reference. No audio from the video is shipped.
The useful qualities were a patient pressure gather, warm low-mid movement,
an irregular crest, natural width, restrained hiss, and a clean release.

Room of Days processing shapes the recordings into the user-selected
`fwoosh-c-hearth-bloom` master: a 1.70-second stereo 48 kHz / 16-bit PCM
gesture with a near-silent intake, a crest around 0.9 seconds, quiet natural
stereo movement, and a fast ember-like release. It contains no oscillator,
pitched afterglow, copied reference audio, or hard limiter. It remains the
once-per-app-session room ignition; it is not a looping ambience bed.

The deterministic audition recipe and approved render are retained under
`tool/author_fire_fwoosh_candidates.py` and
`design/audits/2026-08-19/fire-fwoosh-redesign/fwoosh-c-hearth-bloom.wav`.
Rejected candidates and the comparison reel remain outside the release
package. The original Freesound WAV downloads require an authenticated
account; that encoding boundary is recorded here rather than describing the
shipped master as all-lossless.
