# Room of Days tap refinement — owner audition brief

Status: **Refined selected for integration**. The 47 base masters and 60 Paired Return masters were copied byte-for-byte into production from the frozen Refined snapshot. Routing, gesture handling, global variant walks, gain logic, settings, completion, and unrelated assets remain unchanged.

Interactive comparison: `http://127.0.0.1:8393/sound-review-20260906/taps/`. Source: `tool/preview/tap-review.html`, copied to the served directory as `index.html`.

## Interactive verification

On 2026-09-06, Chromium/Playwright verified all five live material/ordinary lane paths for each of the three families, plus all five contextual reels per family (15 live paths and 15 reel starts). Each recorded reel advanced its playback clock without a media error and only one reel played at a time. Four blind comparisons covered both candidates and switching back to Current; each pair contained Current and the selected candidate, with explicit label reveal. The live music checkbox started the exact approved 96-second Lamp asset and stopped it when unchecked. Browser console: zero errors or warnings. Evidence: `browser-review.log`, `browser-blind-review.log`.

Screenshots at 320, 430, and 1280 pixels were visually inspected; no horizontal overflow. Images are in `output/playwright/tap-study-{width}.png`. The offline manifest check still passes; this local audition remains excluded from the shipped offline asset manifest. These checks establish playback and layout, not a sensory preference or phone-speaker acceptance.

## Decision

Compare the exact current Room tap masters with two strictly bounded treatments:

- **CURRENT** — byte-identical approved masters.
- **REFINED** — complementary time-varying EQ moves a modest amount of existing energy into the compact body, retains the first-contact edge and source duration, reduces high grain after contact, and subtly shortens only the glass ring.
- **WEIGHTIER** — the same treatment with twice REFINED's modest lane body boost.

The treatment adds no notes, pitch walk, randomness, noise, reverb, Foley, compression, or melody. CURRENT, REFINED, and WEIGHTIER each contain the same 47 source tap masters: four ordinary roles with five takes each (20), and nine material lanes with three takes each (27), for 141 audition entries total.

Integration preparation now also contains all 60 Paired Return combinations per family. They use the exact plain-base substitution already present in the auditioned paired-return reel; the original meaning layer is retained within one 24-bit quantization step. `paired-manifest.json` records every derivative. `source-manifest.json` locks the archived original sources, so rerunning the authoring recipe after a future integration cannot process already-refined runtime files a second time.

After the comparison, the owner explicitly selected Refined: "go for refined!" The selection authorizes this exact frozen family, not a new render or a broader sound-system change. It is an owner audition choice; the output route for that final choice was not recorded, so physical-device acceptance is not asserted here.

Each derivative is normalized against its direct source to 260–8000 Hz energy within 0.01 dB. The renderer requires at least 5 dB of headroom; measured worst cue peak is -5.325 dBFS, belonging to the unchanged current anchor. Independent PCM checks and deterministic rendering pass in `independent-qc.json`. Those checks do not establish a preference or prove perceived loudness equality.

## Behavior that stays locked

- Production gesture routing is untouched by this study. In the listening sandbox, visible contact can sound when pressed, while a canceled drag never commits an action or plays its outcome. Bare scrolling, typing, loading, busy controls, and selected-again focus/completion remain silent.
- The original **Answered Detent** is byte-locked. The recorded completion has one accepted contact and its original outcome exactly 75 ms later; no generic second click is added. Live interaction waits for a committed action before its outcome.
- The paired-return reel changes only its plain base. Its existing rare meaning layer remains original.
- `rapid.wav` retains the existing global walk and gain behavior. Ordinary roles have five existing variants; material roles have three.
- `with-music.wav` uses approved **Lamp left on** and `with-umbrella.wav` uses the umbrella alternate. Both preserve the existing music mix behavior.

## Listen in this order

1. `current/flow.wav` versus `refined/flow.wav`, then `refined/flow.wav` versus `weightier/flow.wav`.
2. `current/single.wav` and `refined/single.wav` for ordinary repeated presses.
3. `current/rapid.wav` versus `refined/rapid.wav` for fatigue and accumulation.
4. The same flow under `with-music.wav`, then `with-umbrella.wav`.
5. `paired-return.wav` to ensure the rare meaning layer still owns the moment.
6. `locked/silence.wav` as a reminder that deliberate silence is part of the system.

The flow has the same ten tap timings in every family: 300, 1100, 1800, 2500, 3200, 4100, 5200, 6250, 7900, and 8900 ms. The completion outcome starts at 6325 ms. Use the normal app mix first, on a phone speaker and headphones; `matched.wav` is a diagnostic equal-energy check, never a substitute for the natural pass.

Ask: **does it stay like the same Room gesture, but feel crisper and fuller without becoming poppy, louder, or a new musical layer?** Record `CURRENT`, `REFINED`, `WEIGHTIER`, `both bad`, or `no preference`, plus the device, output route, reel, and cadence. A verdict on an isolated file does not approve the system.

Historical owner evidence is preserved verbatim in the adjacent system contract: “the tap sounds just don't sound good”; “the sound changes notes as you keep clicking around”; and “a tap sound should only be triggered when you directly tap a quest but don't trigger its completion, not when you just swipe around not intending to tap anything.”
