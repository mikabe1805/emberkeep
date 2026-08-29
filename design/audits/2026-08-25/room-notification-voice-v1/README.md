# room-notification-voice-v1 — the room knocks

**Question this study asks:** should the reminder notification speak the
room's own language, and if so, with which gesture?

Today both platforms play the **stock OS notification sound**
(`lib/platform/notifications_native.dart` passes no `sound:` on either
platform). For a habit app, the reminder is plausibly the most-heard sound in
the product — and the only one nobody designed. This study renders four
candidates for it, every one derived from the shipped world: the approved
contact master (`room-sonic-world-v1/shared/contact-master.wav`), the modal
body bank, the D-major pentatonic field, and the close room fingerprint, with
render-polish discipline (0.09 excitation beds, modest sends).

**Concept:** a reminder is the room gently asking for its keeper. Not an
alarm, not a reward, and never a guilt trip — a knock, answered by the field.

## Candidates (`candidates/`, level-matched at −27.0 dBFS phone-band, −6 dBFS peak ceiling)

| id | gesture | read |
| --- | --- | --- |
| `knock-once` | one seated contact + warm D root, 0.44 s | the quietest ask |
| `knock-paced` | double knock, D answered by A above, 0.62 s | an invitation (rising) |
| `knock-settle` | double knock, D answered by A4 below, 0.62 s | the patient version (settling) |
| `field-call` | three small finds rising D→E→B, 0.70 s | a distant call, no knock metaphor |

`index.html` is a self-contained audition page (audio embedded as data URIs)
— open it on the phone. Recreate everything with:

```
python tool/author_room_notification_voice_study.py \
    --output design/audits/2026-08-25/room-notification-voice-v1
python tool/sonic_taste_gate.py qc --json-out .../qc.json .../candidates/*.wav
```

Deterministic seeds (7100–7440); `manifest.json` carries SHA-256 hashes and
measured levels; `qc.json` is the technical gate (all ok, no clipping).

## The audition is not the final gate

The phone-speaker listen picks a direction. Before anything ships, the chosen
candidate must be heard **as a real delivered notification on the lock
screen**, because the OS plays notification sounds on its own channel, at its
own volume, with the screen dark. `sonic_taste_gate.py make-session` can
structure the A/B if wanted.

## Shipping path (deferred until a verdict)

- **iOS:** the sound file must live in the Runner bundle (added via the Xcode
  project, not Flutter assets) and be referenced by
  `DarwinNotificationDetails(sound: '<name>.wav')`. WAV ≤ 30 s is accepted.
- **Android:** notification channels bake their sound **at channel creation**
  — shipping a custom sound requires a *new channel id* (e.g.
  `emberkeep_reminders_v2` with `RawResourceAndroidNotificationSound`), or
  existing installs keep the old default. Plan the migration deliberately.
- Either way, the master ships byte-identical to the approved audition file
  and gets a byte-lock in `test/interaction_sound_quality_test.dart`.

**Keeping the stock OS sound is also a legitimate verdict** — it just should
be a decision, not a default. Record it in `LISTENING-RESULT.md` either way.
