# Room of Days music roles

Normal Room music and Focus music are different authored roles. Do not point
both controls at one file again.

## Normal Room music — dry rotation and Lamp left on

`take_01.m4a` through `take_16.m4a` are 96-second performances of the
owner-selected umbrella-brush grammar: jazzy/lofi B-minor harmony, 72 BPM,
swung eighths, and the dark brush replacing the rejected fake-rain droplets.
`take_17.m4a` through `take_22.m4a` add the approved dry-windowseat register:
the same quiet room role, but a second mood with no rain or droplet voice.
Runtime alternates the three normal-room composition families and crossfades
their seams, so the twenty-two dry takes and the new piece each keep their
own presence. Within a family, every take plays before one repeats.
`take_01` is byte-derived from the audition winner; the remaining umbrella
takes are deterministic performance variations of the same approved grammar.

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

### Lamp left on — approved September 6, 2026

> it sounds pretty good! you can add it to the app

`lamp-left-on.m4a` is the exact approved 96-second AAC from the umbrella
comparison. It uses the original umbrella-brush instruments and groove with
a written A–A′–B–A melody. The reviewed file was copied without re-encoding,
changing its level, or modifying any existing take.

- Source: `tool/author_room_music_new_theme.py`
- Score and deterministic render receipt: `design/audits/2026-09-06/sound-and-music/umbrella-new-theme/`
- AAC-LC, 96 kbps, 48 kHz mono, 96 seconds
- SHA-256: `a1b84c0b850e03131e5a22269cac7aa2532ad6a0fce5a31dea21e17d40078cc3`

All normal pieces use the existing 2.5-second transition beginning at 93.5
seconds and the same interaction ducking. Normal music remains optional;
Focus retains its distinct meditation track. All music is deferred from the
web first-frame cache and remains available for offline warming.

## Class-day score (`class_day/`)

On a class day the room's music is not the rotation but the class-day score:
`bed_between.m4a` and `bed_evening.m4a` (one 16-bar pass of the 72 BPM
umbrella-brush form each, with a 6.5 s tail, -36.0 dBFS phone-band RMS like
every take above) and `swell_00.m4a` to `swell_31.m4a` (two bars of bass and
night bells cut at each strong beat of the form, -38.2 dBFS over their held
bars). A class kept starts the swell cut at the next strong beat. Native only.
Source: `tool/author_class_day_score.py`; manifest, sizes and levels:
`design/audits/2026-10-11/class-day-score/manifest.json`; pinned in
`test/class_day_score_assets_test.dart`; how it plays: `SOUND-DESIGN.md` section
13. Owner evidence: "also changing the music after you marked a class was super
cool".

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

All bundled music is original deterministic project synthesis with no
imported recordings, external music-generation service, or paid sample source.

## License

This is an original project asset. No standalone redistribution license has
been declared; do not treat it as CC, stock, or public-domain audio. Reuse is
limited to this project unless its owner explicitly grants another license.
