# Asset licenses and provenance

## Hearth sounds

- Bundled files: `assets/sfx/fire_ignite.wav`, `assets/sfx/hearth.wav`,
  `assets/sfx/hearth_room.wav`
- Ignition source: **Flare ignition** by qubodup
  - Page: <https://opengameart.org/content/flare-ignition>
  - Original FLAC: <https://opengameart.org/sites/default/files/ignition.flac>
- Fire-bed source: **Fireplace Sound loop** by PagDev
  - Page: <https://opengameart.org/content/fireplace-sound-loop>
  - Original WAV: <https://opengameart.org/sites/default/files/fire.wav>
- Both sources use [Creative Commons Zero (CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/).
- Changes: trimmed, mixed, converted to mono PCM, low-mid warmth increased,
  brittle highs softened, limited, faded, and normalized. The 2.18-second
  `fire_ignite.wav` adds a short reverse intake before the real flare, a quiet
  lower-pitched body, and a bounded fire tail for the app-session ignition.
  The older 3.3-second `hearth.wav` and quiet profile fire bed remain archived
  for compatibility; neither is a looping app ambience track.

CC0 does not require attribution. This record is retained so the release team
can verify the origin and commercial-use status of the bundled sound.

## Material tap sounds

- Bundled files: the three `tap_wood`, `tap_parchment`, `tap_brass`,
  `tap_glass`, and `tap_stone` WAV variants under `assets/sfx/`.
- Wood, parchment, brass, and glass sources: **100 CC0 SFX** by rubberduck
  - Page: <https://opengameart.org/content/100-cc0-sfx>
  - Original archive:
    <https://opengameart.org/sites/default/files/100-CC0-SFX_0.zip>
- Stone source: **Various Sound Effects** by Spring Spring
  - Page: <https://opengameart.org/content/various-sound-effects-0>
  - Original WAV:
    <https://opengameart.org/sites/default/files/tap_stone.wav>
- Both source collections use
  [Creative Commons Zero (CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/).
- Changes: bounded and trimmed into short contacts, converted to mono 44.1 kHz
  16-bit PCM, filtered and faded by material, conservatively peak-limited, and
  given small baked rate variations. The app cycles the three variants
  deterministically; it does not pitch-shift or randomize them at runtime.

The exact source filenames and per-family processing notes are retained in
`assets/sfx/SOURCES.md`.
