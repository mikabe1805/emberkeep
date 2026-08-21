# Room phone click v2

Status: **rejected on an attested iPhone 17 built-in speaker.** Double Seat and
the +2.0 dB level won their conditional passes, but the final verdict was No:
the isolated clicks sounded unfinished and only became fun in the rapid run.
Answered Detent remains locked. Runtime assets are unchanged. See
`LISTENING-RESULT.md`.

The first attested iPhone speaker gate returned `Almost`:

> the main clicking sounds could be more crisp and fuller so it feels nice to click around, and also the volume is off it’s pretty quiet even though i’m on full volume

This study separates those two causes instead of hiding a texture change inside
a gain change.

## Pass 1 · ordinary texture

Two full Room families play at the same +3 dB ordinary-role level. Both retain
the existing role timing, pitch walk, body family, and close Room fingerprint.

- `ledger-edge`: adds one short 1.6–4.2 kHz edge derived from the approved C
  contact; it tests clean articulation without a brittle treble shelf.
- `double-seat`: keeps that edge and adds one compact 650–1800 Hz derived seat;
  it tests phone-readable fullness without adding sub-bass or literal Foley.

The names stay hidden during listening. Each side must finish one complete Room
flow and one 125 ms alternating-control run before the verdict unlocks.

## Pass 2 · ordinary level

The selected texture is compared at +2.0 dB and +3.5 dB relative to the current
Room role targets used in the failed phone gate. Only open, select, navigate,
and place move. The accepted
completion contact and Answered Detent keep their exact source levels. If the
two levels are equal, the already-heard +3.0 dB middle render becomes the
confirmation candidate. If the texture pass is equal or neither, the study
stops instead of silently choosing a texture and contaminating the level result.

The +3.5 dB side is a deliberate upper bound, not a presumed shipping default:
it can make the short placement transient louder than the reward's sustained
phone-band RMS. The full-flow confirmation exists to reject that hierarchy if
it feels wrong. +2.0 dB is the safer end; +3.0 dB is the intended compromise.

## Locked completion

- accepted contact: exact `room-sonic-world-v1/roles/select/2.wav`
- Answered Detent: exact
  `room-reward-voice-v1/rewards/answered-detent/natural.wav`
- timing: 5.300 s contact, 5.375 s answer, exactly 75 ms

Every full-flow candidate is sample-identical from 5.300 s onward. This study
cannot reopen the reward selection.

## Rebuild

```text
python tool/author_room_phone_click_v2_study.py \
  --output design/audits/2026-08-20/room-phone-click-v2 \
  --room-study design/audits/2026-08-20/room-sonic-world-v1 \
  --reward-study design/audits/2026-08-20/room-reward-voice-v1
```

`manifest.json` records every input and generated hash. `qc.json` records
per-role phone-band level, peak, tail, contact-edge, seat-body, and low-body
measurements.
