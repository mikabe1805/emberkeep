# Room of Days Paired Return phone gate v1

This is the short, single-condition iPhone regression audition for the rare
Paired Return easter egg. It is not another A/B. The resulting physical-device
approval is recorded in `LISTENING-RESULT.md`.

Run this from the app root:

```text
python tool/author_room_paired_return_phone_gate.py
python -m unittest tool.tests.test_author_room_paired_return_phone_gate
python C:\Users\mikus\.codex\skills\sound-design-director\scripts\validate_sonic_system.py design/audits/2026-08-20/room-paired-return-phone-gate-v1/sonic-system.json
```

The generator has `--v3-root`, `--v4-root`, and `--reward-root` parameters.
It byte-copies every approved v3 X take, the bounded v4 D5/A5/E5 stems, and
the canonical atomic completion source:
`room-reward-voice-v1/composites/answered-detent/natural.wav` (430 ms).
It never uses the 6.1-second v3 full-flow `completion-composite.wav`.

The three required natural-completion reels are:

- `discovery.wav`: varied plain X, four 350 ms eligible actions, D5→A5→E5→D5,
  plain X, then an immediate second qualifying run held plain by the 90-second
  and once-per-screen rarity limits.
- `rapid-stays-plain.wav`: four eligible X actions then D5, followed by a
  120 ms abort. The five-event armed burst uses `1/.93/.93/.885/.885` from D5
  through the rapid run; later eligible actions stay plain and do not catch up.
- `completion-interrupts.wav`: four eligible X actions then D5, the canonical
  atomic completion 80 ms later, and a later plain eligible interaction that
  proves the phrase was cleared.

The HTML lets any browser preview, but `physical_gate_eligible` is true only
for an iPhone-like user agent plus the speaker-route checkbox. Android, iPad,
touch-Mac, and desktop routes export truthful preview evidence and cannot make
`physical_gate_passed` true. A physical pass additionally requires full volume,
a model, room condition, natural completion of every reel, and `Ready`.
Verdicts lock after one selection to prevent conflicting attestation events.

## Result

The owner naturally completed all three reels on an iPhone 17 built-in speaker
at full volume in a quiet room and selected `ready`. Paired Return is approved
only under the bounded policy above. Plain five-take X remains the everyday
voice; this result does not promote the longer v4 phrase or its unused notes.
