# Room of Days music roles

Normal Room music and Focus music are different authored roles. Do not point
both controls at one file again.

## Normal Room music — approved umbrella-brush rotation

`take_01.m4a` through `take_08.m4a` are 96-second performances of the
owner-selected umbrella-brush grammar: jazzy/lofi B-minor harmony, 72 BPM,
swung eighths, and the dark brush replacing the rejected fake-rain droplets.
Runtime shuffles all eight without an adjacent repeat and crossfades their
seams. `take_01` is byte-derived from the audition winner; the remaining seven
are deterministic performance variations of the same approved grammar.

Owner evidence, preserved verbatim in the audit records:

> actually umbrella is the best one

> i think umbrella-brush is my favorite!

Source recipes, exact note-event scores, manifests, and verdict records live
under:

- `design/audits/2026-08-31/room-music-v2/`
- `design/audits/2026-08-31/room-music-umbrella-hat-v1/`
- `design/audits/2026-08-31/room-music-rotation-v1/`
- `tool/author_room_music_study.py`
- `tool/author_room_music_v2_study.py`
- `tool/author_room_music_umbrella_hat_study.py`
- `tool/author_room_music_rotation_study.py`

The shipped AAC digests are pinned in `test/music_asset_roles_test.dart`.

## Focus music — peaceful meditation loop

`focus-meditation.m4a` is the 112-second Steward-supper master that Build 40
incorrectly used as the normal Room track. It now appears only while a Focus
session is active.

Owner role evidence:

> the current music is super peaceful and could be good for maybe a meditation timer mode thing

- Source master: `design/audits/2026-08-31/steward-supper/audio/steward-supper-music-v1/master/steward-supper-theme-master.wav`
- Recipe: `design/audits/2026-08-31/steward-supper/audio/author_steward_supper_music.py`
- Bundle: AAC-LC, 96 kbps, 48 kHz mono, 112.000 s, 1,381,265 bytes
- SHA-256: `e4162909e9a5063e5d087b267346a9bf4383fcdb47a38e91fae1843271534d9e`

Both music families are original deterministic project synthesis with no
imported recordings, external music-generation service, or paid sample source.

## License

This is an original project asset. No standalone redistribution license has
been declared; do not treat it as CC, stock, or public-domain audio. Reuse is
limited to this project unless its owner explicitly grants another license.
