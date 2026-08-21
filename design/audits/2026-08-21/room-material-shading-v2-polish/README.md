# room-material-shading-v2-polish

Status: **shipped 2026-08-21** — owner final verdict: "it sounds wonderful!
very well done". All nine lanes replaced v1 in `assets/sfx/room/materials/`
and the byte-locks in `test/interaction_sound_quality_test.dart` pin these
masters.

The v1 approval (see `../room-material-shading-v1/LISTENING-RESULT.md`) noted
one polish item verbatim: "that sort of low quality recording vibe". This
render changes ONLY that: per-body excitation-noise beds cut (0.18 to 0.09),
mineral grain narrowed and shortened, and the page flick rebuilt from fiber
micro-crackle over a reduced wash. Gestures, notes, weights, durations, and
targets are identical — regenerate with
`tool/author_room_material_shading_study.py --polish`.

Measured inter-partial noise floor (500–3000 Hz, sustain window) vs v1:
page −3.4 dB, slate −2.4 dB, glass −1.9 dB.

The v1 study remains the approved-gesture record; its masters stay archived
there for lineage.
