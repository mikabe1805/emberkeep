# Room of Days semantic sound directions

Status: **rejected audition, retained as a negative reference**. These files do
not replace any runtime asset. On 2026-08-20 the user rejected the whole family
as unfresh, unsatisfying, and reminiscent of an old recording studio. Ledger,
Hearth, Relic, and the recommended gradient are not open finalists.

Do not polish these candidates into a second audition. Their down-pitched
literal mechanisms, heavily reduced high end, inherited recording spaces, and
long acoustic tails are the wrong foundation. The replacement direction and
calibration method live in
`design/audits/2026-08-20/sonic-taste-system/README.md`.

## North star

**The room answers the hand.** A sound begins as a believable touched object,
then the room may answer with a quiet acoustic resonance. Clear melody is rare
and earned.

The approved hearth ignition is the reference for discipline rather than a
template copied onto every interaction: it has a physical cause, a shaped
gesture, warm low-mid movement, and room to breathe. Ordinary interface sounds
should share that credibility while staying much shorter and quieter.

This candidate set contains no oscillators, synthesized bells, procedural
sparkle, or algorithmic reverb. It uses recorded wood, paper, a small latch, a
wax-seal press, a wooden drawer, Sansula, brass bowl, glass bowl, and—only in a
few Hearth-direction tails—a very quiet excerpt of the approved fire master.

## Why the existing system still feels one layer short

The material contacts now cover ordinary touch well. The remaining issue is
that a small group of old synthesized cues carries too many unrelated meanings:

- `boing` appears 33 times and currently means validation, duplicate, capacity,
  undo, cancel, deletion, and failure.
- `streak` appears across more than twenty call sites and currently means save,
  add, share, timer completion, social success, onboarding completion, planning
  success, and actual streak continuation.
- `loot` mixes achievement discovery with social receipts.
- `levelup` is used for true rank movement, goal commitment, routine progress,
  and several broad success states.

The old reward files are synthetic music-box, marimba, and bell constructions.
Adding more tap sounds cannot solve that semantic and timbral bottleneck.

## Start here: recommended gradient

`recommended-gradient-audition.wav` is the proposed hierarchy rather than one
uniform intensity. It takes the dry Ledger voices for routine actions, Hearth
voices for daily meaning, and Relic voices only for discovery and advancement.

| Time | Cue | Meaning |
| ---: | --- | --- |
| 0.450 | `boundary_soft` | a gentle local “not now” or reached limit |
| 1.210 | `plan_place` | a task, event, note, or plan settled into place |
| 2.080 | `goal_seal` | a consequential promise or goal sworn |
| 3.300 | `quest_latch` | one Quest genuinely completed |
| 4.400 | `streak_ward` | a streak protected, held, or extended |
| 5.740 | `keepsake_found` | a true achievement or keepsake revealed |
| 7.300 | `ledger_close` | Close the Day as its own remembered ritual |
| 8.640 | `rank_advance` | a real rung or rank advancement |

The gaps are intentionally long for judging. Runtime gaps would follow the
visual event and never play this sequence as a montage.

## Three complete directions

Each reel contains the same eight meanings in the order above.

### A — The Ledger

`a-ledger-audition.wav`

The driest and most tactile direction. Paper, wax, wood, and mechanisms lead;
resonance sits well underneath. This is the most serious and least “magical”
option. It is also the safest voice for high-frequency daily actions.

Timecodes: 0.450, 1.210, 2.080, 3.180, 4.180, 5.360, 6.600, 7.800.

### B — The Hearth

`b-hearth-audition.wav`

Rounder and warmer. It keeps the object-first construction but lets the D/A
resonance breathe. A nearly subliminal low fire texture appears only behind a
few earned cues; it is not ambience and never loops. This direction is the
closest continuation of the approved ignition.

Timecodes: 0.450, 1.240, 2.150, 3.370, 4.470, 5.810, 7.210, 8.550.

### C — The Relic

`c-relic-audition.wav`

The most harmonic and fantasy-forward direction. Real bowls and Sansula carry
longer open-fifth tails, but there is still no bright major-third jingle or
fairy-dust layer. It should be used sparingly even if selected; its strength is
that rare moments can finally feel rare.

Timecodes: 0.450, 1.270, 2.220, 3.560, 4.760, 6.240, 7.800, 9.280.

Every cue is also exported separately beneath its direction folder, so a final
system can mix choices without taking an entire direction wholesale.

## Proposed app-wide meaning map

### Keep the existing material-contact layer

- Wood: ordinary controls, tabs, drawers, room objects.
- Stone: calendar dates, anchored records, grounded counters.
- Parchment: planning, journals, page and writing-mode changes.
- Brass: durable commitments, clasps, rank/order movement.
- Glass: literal panes, lenses, previews, and delicate overlays only. It should
  no longer be the default voice for every sheet, toggle, and selection.

A touch receives one immediate material acknowledgement. A successful state
change may receive one semantic outcome roughly 65 ms later. It should never
receive two competing contact sounds.

### Replace the overloaded legacy cues

| New meaning | Use it for | Do not use it for |
| --- | --- | --- |
| `boundary_soft` | duplicate choice, local limit, unavailable action | server/network failure, optional “not now,” destructive confirmation |
| `plan_place` | saved calendar item, journal pin, plan/quest added | completion, streak, purchase |
| `goal_seal` | swearing a goal or similarly consequential commitment | ordinary profile save |
| `quest_latch` | completed Quest and equivalent held routine | every successful button |
| `streak_ward` | real streak continuation, freeze held/earned | onboarding, timer end, generic save |
| `keepsake_found` | achievement, meaningful owned-room/keepsake reveal | social send, ordinary purchase receipt |
| `ledger_close` | Close the Day only | modal dismissal or night navigation |
| `rank_advance` | real rung/rank increase and the rarest milestone | goal creation, purchase, routine progress |

### Add only the missing high-value beats

1. Quiet Company needs a restrained begin/end pair: a soft wick-like arrival
   and a felt-muted return tone. Timer end must not reuse `streak`.
2. “Keep in my Circle” needs a quiet token-placed confirmation after the save
   succeeds. It should be relational, not `loot`.
3. Morning can use a very understated ledger-open/page-lift counterpart. It is
   an invitation, never a reward.
4. Goal-wizard suggestion chips and quest removal need small parchment/soft
   lift-away contacts, not a reward sound.
5. Night-reflection prompt tabs can share an extremely quiet page gesture if
   real-device testing shows that the ritual benefits from it.

### Keep these silent

- typing, cursor movement, scrolling, passive loading, and background sync;
- repeated presses while an action is busy;
- most network/server failures, where copy already explains the problem;
- optional “not now” choices;
- passive previews and tiny visual-only expand/collapse changes;
- routine recap animation before the actual completion moment.

Silence is part of the hierarchy. If every visible change makes a sound, the
earned cues stop feeling earned.

## Playback and mixing contract

- First touch acknowledgement lands inside 100 ms; the baked candidates begin
  immediately.
- One ordinary cue per roughly 250 ms. Repeated taps must not accidentally
  compose a melody.
- Priority is ceremony > discovery > progress > confirmation > contact.
- A major local outcome may lower its own contact tail by 6–9 dB for 250–450
  ms; it must never duck external music or seize audio focus.
- Ordinary cues remain mono or narrowly centered. Natural stereo width belongs
  to environmental and rare ceremonial sounds.
- Delayed cues and haptics are cancelled when the app backgrounds or the event
  is superseded.
- Sound-off mode loses no information. Haptic and audio semantics remain
  aligned without requiring both.
- The core first-session set must be in the offline web cache; a fresh PWA
  session should not depend on a network fetch before its first meaningful cue.

## Production sequence after direction approval

1. Author final masters for the selected/hybrid direction and phone-speaker
   master them together, including the existing taps and hearth.
2. Introduce typed semantic events and a small sound director with cooldown,
   priority, cancellation, and overlap rules.
3. Migrate `boing`, `streak`, `loot`, and `levelup` call sites by meaning rather
   than by filename.
4. Add the Quiet Company and Circle-save gaps.
5. Test on a physical iPhone and Android phone at ordinary volume, with silent
   mode, external music, rapid tapping, backgrounding, and offline PWA startup.

## Audition-source provenance

All sources are CC0 and were verified on their source pages on 2026-08-19.
These candidates use official public high-quality preview encodes where an
original Freesound WAV requires login. Final source-encoding provenance must be
preserved if a candidate moves into the app.

- [Hokema Sansula F](https://freesound.org/people/cabled_mess/sounds/380739/)
  by cabled_mess.
- [Small brass sound bowl](https://freesound.org/people/FOSSarts/sounds/762642/)
  by FOSSarts.
- [Glass bowl, cloth mallet](https://freesound.org/people/Anthousai/sounds/448071/)
  by Anthousai.
- [Paper slide 2](https://freesound.org/people/brokenmachinery/sounds/730078/)
  by brokenmachinery.
- [Wood tap](https://freesound.org/people/mealwyrm/sounds/495814/) by mealwyrm.
- [Wax seal](https://freesound.org/people/Cerise_Virtuelle/sounds/759526/) by
  Cerise_Virtuelle.
- [Small door close latch](https://freesound.org/s/213397/) by chewiesmissus.
- [Opening and closing wooden drawer](https://freesound.org/people/FOSSarts/sounds/740297/)
  by FOSSarts.
- The already approved `fwoosh-c-hearth-bloom` master for the tiny Hearth-only
  ember layer.

The deterministic audition recipe is
`tool/author_semantic_sfx_candidates.py`.
