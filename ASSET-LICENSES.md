# Asset licenses and provenance

## Hearth sounds

- Bundled files: `assets/sfx/fire_ignite.wav`, `assets/sfx/hearth.wav`,
  `assets/sfx/hearth_room.wav`
- Current ignition source: **Flare ignition** by qubodup
  - Page: <https://opengameart.org/content/flare-ignition>
  - Original FLAC: <https://opengameart.org/sites/default/files/ignition.flac>
- Current pressure-body source: **Flamethrower Weapon Short Medium Bursts**
  by AslakHostaker
  - Page: <https://freesound.org/s/395038/>
  - Source metadata: 48 kHz, 24-bit mono WAV, CC0
  - Working input: Freesound's official public high-quality preview; the
    original WAV download requires an authenticated Freesound account.
- Current fire-edge source: **Open-door Fireplace - XY at door level** by
  Sadiquecat
  - Page: <https://freesound.org/people/Sadiquecat/sounds/853081/>
  - Source metadata: 96 kHz, 32-bit stereo WAV, CC0
  - Working input: Freesound's official public high-quality preview; the
    original WAV download requires an authenticated Freesound account.
- Archived hearth-bed source: **Fireplace Sound loop** by PagDev
  - Page: <https://opengameart.org/content/fireplace-sound-loop>
  - Original WAV: <https://opengameart.org/sites/default/files/fire.wav>
- All listed recordings use
  [Creative Commons Zero (CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/).
- Changes to `fire_ignite.wav`: selected source passages were filtered into a
  warm 120-1000 Hz pressure body, given a patient asymmetric envelope and
  restrained natural width, faded, and peak-normalized without a hard limiter.
  The result is a 1.70-second stereo 48 kHz / 16-bit PCM one-shot. It contains
  no synthesized tone and no audio copied from the user's Krotos reference.
- The older `hearth.wav` and `hearth_room.wav` use the qubodup and PagDev
  recordings and remain archived for compatibility. None of these files is a
  looping app ambience track.

CC0 does not require attribution. This record is retained so the release team
can verify the origin and commercial-use status of the bundled sound.

## Production Room interaction sounds

- Bundled files: the 20 WAV masters under
  `assets/sfx/room/ordinary/<role>/`, the 60 bounded Paired Return masters under
  `assets/sfx/room/paired_return/<token>/<role>/`, plus the three locked
  completion files under `assets/sfx/room/completion/`.
- These are deterministic project-authored synthesis. No third-party sample,
  recorded Foley, generated-model output, or reference-video audio is used.
- Ordinary masters are mono 48 kHz / 24-bit PCM, 60 ms, and preserve the
  selected X contact/body/8.5 ms clasp at its approved `+1.5 dB` phone level.
- Paired Return masters are also mono 48 kHz / 24-bit PCM and 60 ms. Each is a
  deterministic precomposition of the unchanged X role/take plus one approved
  D5, A5, or E5 meaning stem. Only the bounded D5 → A5 → E5 → D5 runtime cell
  passed the iPhone 17 gate; unused v4 notes and audition reels are excluded.
- `completion-composite.wav` preserves accepted Select-2 followed by Answered
  Detent exactly 75 ms later in a 430 ms atomic cue with no study-timeline lead.
  Its two component masters are bundled solely for provenance and regression
  verification.
- The release repository retains the deterministic authoring recipes, the
  selected source masters used by byte-for-byte regression checks, and the
  physically approved phone-gate contract and listening result. Rejected
  candidates, long comparison reels, and browser audition copies remain
  outside the release package rather than being shipped with the app.

## Archived material tap sounds

- Archived compatibility files: the three `tap_wood`, `tap_parchment`, `tap_brass`,
  `tap_glass`, and `tap_stone` WAV variants under `assets/sfx/`.
- Physical contacts: [wood tap](https://freesound.org/people/mealwyrm/sounds/495814/)
  by mealwyrm, [small stones](https://freesound.org/people/FOSSarts/sounds/740544/)
  by FOSSarts, [paper slide](https://freesound.org/people/brokenmachinery/sounds/730078/)
  by brokenmachinery, [metal click](https://freesound.org/people/Sheyvan/sounds/475195/)
  by Sheyvan, and [glass tap](https://freesound.org/people/CJspellsfish/sounds/668383/)
  by CJspellsfish.
- Acoustic resonances: [Hokema Sansula F](https://freesound.org/people/cabled_mess/sounds/380739/)
  by cabled_mess, [small brass sound bowl](https://freesound.org/people/FOSSarts/sounds/762642/)
  by FOSSarts, and [glass bowl](https://freesound.org/people/Anthousai/sounds/448071/)
  by Anthousai.
- Every listed material recording is CC0. Room of Days used Freesound's
  official public high-quality preview encodes as its working copies.
- Runtime no longer routes ordinary interactions to this rejected study.
- Changes: bounded and trimmed into short contacts, converted to mono 44.1 kHz
  / 16-bit PCM, filtered and faded by material, layered with short acoustic
  dyads, conservatively peak-normalized, and given tiny baked tuning changes.
  The app cycles the three variants deterministically; it does not pitch-shift
  or randomize them at runtime.

The exact source filenames and per-family processing notes are retained in
`assets/sfx/SOURCES.md`.
