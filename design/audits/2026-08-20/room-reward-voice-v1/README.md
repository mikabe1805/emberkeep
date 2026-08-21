# Room reward voice v1

Status: **Answered detent selected in a blind desktop/laptop-speaker pass and
retained after the first physical-phone gate; the whole system did not pass
because the everyday clicks were too quiet and insufficiently crisp/full.**
Runtime remains unchanged. See `LISTENING-RESULT.md` and
`../room-sonic-world-v1/PHONE-LISTENING-RESULT.md`.

## Why this study exists

The first unified Room-family proof produced a useful split decision:

- in the level-controlled blind pass, the unified candidate beat the previous
  mixed study;
- its open, select, navigate, place, and complete verbs remained distinct;
- at natural hierarchy, the previous mixed study still won;
- the owner's exact diagnosis was: “it sounds pretty good! The reward sounds
  could be better though and more crisp i guess or satisfying or full?”

That result accepts the new everyday acoustic world for this iteration but does
not approve its earned voice. This study therefore keeps every ordinary event
byte-identical and changes only the confirmed reward beginning 75 ms after the
accepted-state contact.

## The three challengers

These are different mechanisms, not small EQ variations:

1. **Receipt edge** — a clean derived release edge followed by a compact warm
   body;
2. **Seated catch** — a denser 300–600 Hz latch body with a longer weighted
   settle;
3. **Answered detent** — one physical catch followed by a restrained delayed
   fifth.

All three inherit `approved-c-contact-v1`, `room-modal-bank-v1`,
`room-close-reflection-v1`, and a fixed D-pentatonic pitch token. No new sample
library, video audio, or unrelated click is introduced.

## Listening design

The browser runs a progressive blind tournament:

1. current unified bloom versus Receipt edge;
2. the winner versus Seated catch;
3. the winner versus Answered detent;
4. the tournament winner at intended natural weight versus the previous reward
   re-composed on the same locked everyday family.

The first three rounds match integrated phone-band reward energy and use an
identical full-flow timeline. Mechanism names remain hidden until all verdicts
are recorded. A short ending replay is diagnostic only; the full flow is the
decision unit. The final pass introduces only the declared 0.65 dB earned-event
lift and the previous calibrated reward. The exact previous mixed full flow is
retained only as a post-verdict diagnostic because its ordinary cues differ.
The final benchmark is intentionally not loudness-neutral: the previous reward
has a longer natural energy arc and leaves the full control about 0.30 dB above
the challenger flows. That pass judges intended hierarchy; the first three
equal-energy rounds judge mechanism quality.

## Approval boundary

This study can establish a preferred completion mechanism. It cannot approve
discovery, rank, keepsake, or ceremony cues, and it does not authorize runtime
routing. The winning reward must still survive a phone speaker, headphones,
real animation/haptic timing, and the event-director overlap policy.

## Owner result

Answered detent beat the current unified bloom in the matched tournament, then
beat the previous reward on the locked Room family at intended natural weight.
The exact reason was: “I like the composed stuff”. Receipt edge and Seated
catch both lost to the baseline, so the useful signal is the authored
catch-and-answer gesture rather than brightness or mass alone.

## Physical speaker gate

`phone.html` skips the completed tournament and presents only the locked full
flow, the selected composed completion, and a short phone-speaker verdict. The
first attested iPhone run returned Almost. The listener heard the completion
twice and specifically identified the main clicking sounds and their low level
as the remaining issue, so the next study retains Answered detent and revises
the ordinary family only. This still does not replace the later in-app
animation and haptic synchronization check.

## Rebuild

```text
python tool/author_room_reward_voice_study.py \
  --output design/audits/2026-08-20/room-reward-voice-v1 \
  --room-study design/audits/2026-08-20/room-sonic-world-v1 \
  --previous-control design/audits/2026-08-20/room-sonic-world-v1/flows/control-current-natural.wav \
  --previous-reward design/audits/2026-08-20/semantic-interaction-voices-v1/roles/complete-bloop/current.wav
```

`manifest.json` records exact sources, hashes, mechanism derivations, timing,
and generated assets. `tool/tests/test_author_room_reward_voice_study.py`
checks determinism, locked-input preservation, 75 ms atomic timing, matched
energy, byte-identical flow prefixes, unclipped PCM output, and meaningful
mechanism contrast.
