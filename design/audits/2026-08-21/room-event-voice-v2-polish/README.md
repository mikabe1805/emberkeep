# room-event-voice-v2-polish

Status: **shipped 2026-08-21** — owner final verdict: "it sounds wonderful!
very well done". All eleven events replaced v1 in `assets/sfx/` and the
byte-locks in `test/interaction_sound_quality_test.dart` pin these masters.

The v1 approval (see `../room-event-voice-v1/LISTENING-RESULT.md`) noted one
polish item verbatim: "that sort of low quality recording vibe". This render
changes ONLY that: per-body excitation-noise beds cut (0.18 to 0.09) and the
reflection send trimmed 20% so the room fingerprint stays subliminal on the
long gestures. Notes, weights, and timings are identical — regenerate with
`tool/author_room_event_voice_study.py --polish` (its `controls/` are the v1
masters, level-matched).

Measured inter-partial noise floor (500–3000 Hz, sustain window) vs v1:
crit −5.7 dB, levelup −2.6 dB, stat −0.9 dB, loot/streak marginal (their
beds are contact-dominated).

The v1 study remains the approved-gesture record; its masters stay archived
there for lineage.
