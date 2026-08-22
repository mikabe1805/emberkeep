# SOUND-DESIGN — how Room of Days sounds the way it does

Written 2026-08-21, the day the texture system shipped. This is the thorough
record of what makes the app's sound feel good: the failures that taught the
rules, the acoustic world every sound is built from, the recipes, the phone
reality, and the process that keeps taste in charge. `DESIGN-BIBLE.md` holds
the binding rules; this file explains *why* they work. Owner quotes are
verbatim throughout, lowercase and all — they are the actual steering data.

---

## 1. The one-paragraph answer

Every sound in the app is a different gesture performed by **one imagined
physical cause** — a close, handmade mechanism in a warm room, touched by the
same hand. One finger-contact recording-of-a-synthesis starts every sound;
one three-tap room reflection ends every sound; every pitched body lands on
one pentatonic scale; and loudness, duration, and weight follow what the
touch *meant*, not what looked cool in a DAW. Variety comes from changing the
**struck body** (wood clasp, slate plate, parchment, glass, brass) and the
**gesture** (tap, flip, set-down, ceremony), never from importing unrelated
sounds. That is the whole trick: the ear believes it is one world because,
acoustically, it is.

---

## 2. The failures that taught the rules

The system was not designed in one pass. It was carved by vetoes, and each
veto became a permanent rule.

**Real recordings failed — twice.** A five-material CC0 foley family
(wood/stone/parchment/brass/glass) and then a recorded-object semantic set
were both rejected: "they sound kind of like they were recorded in a really
old recording studio or something, the sound doesn't sound fresh and
satisfying". The autopsy found removed treble, inherited room tone, pitched-
down sources, and long acoustic tails. **Rule: recordings carry their room
with them. Synthesize, so the only room present is the one we author.**

**Clean-but-unrelated failed.** A four-sound family (dak/tak/tuk/bloop) where
every file measured clean was rejected: "the sounds on their own sound crisp
i guess but they don't sound good together or feel like room of days. they
sound like random tap sounds." **Rule: per-file quality cannot substitute for
shared acoustic physics. Cohesion is constructed, not mixed in later.**

**Loudness failed.** When the clicks felt unsatisfying, +3.5 dB lost to
+2.0 dB, and the louder candidate family still failed. **Rule: importance is
expressed through body, duration, and weight — never volume alone.**

**Incompleteness failed.** A family derived from only the first 14 ms of the
approved click felt "unfinished" one tap at a time, even though rapid tapping
felt fun — the next tap's onset was secretly supplying the missing ending.
**Rule: every single sound is a complete contact → body → seat/release
gesture on its own.**

**Literalism failed.** A study of real stone-on-stone recordings was
superseded by the owner's correction: "i think youre taking stone too
literally. im not looking for stone on stone sound system, more so the
satisfying 'dak' of clicking something with weight to it i guess?" **Rule:
materials are the satisfying weight of the press, tinted — never Foley
realism.**

**And synthesis noise failed, quietly.** The first shipped texture render
drew "they do have that sort of low quality recording vibe to them" — caused
not by recordings but by *synthesis behaving like one*: stacked per-note
excitation-noise beds summing into a hiss floor, and reflection sends
peeking out on long sounds. **Rule: noise is a spice measured per-sound, not
per-note; the room fingerprint stays subliminal.** (Section 8.)

---

## 3. The shared world — four things every sound inherits

These four constants are why twenty different sounds read as one place.

**The contact master.** A single 14 ms excerpt shaped from the first
phone-approved click ("C"), high-passed at 180 Hz, low-passed at 6.2 kHz,
faded by 5.5 ms so it carries attack but no tail. It is the "hand" — placed
at the head of nearly every sound at some gain. Two sounds with the same
onset transient are half-believed to be the same object before their bodies
even differ.

**The modal body bank.** Pitched bodies come from one damped modal recipe:
partials at ratios 1.0 / 1.498 / 2.17 (detuned 0 / −4 / +7 cents so nothing
is synthetically perfect), a 0.55 ms attack, per-partial exponential decays,
a whisper of correlated band-passed excitation noise so the modes read as a
struck object instead of a clean oscillator, and a 170 Hz–4.2 kHz band. Body
energy concentrates in the phone-readable 550–1400 Hz range with quiet
250–450 Hz support.

**The space fingerprint.** Three feed-forward reflections at 22 / 29 / 34 ms,
−24 / −29 / −34 dB, low-passed at 3 kHz, no feedback tail. That is the whole
"reverb" — an almost subliminal close warm room. Everything passes through
it; nothing gets its own space. The single cheapest cohesion device there is.

**The pitch field.** D-major pentatonic only (D, E, F#, A, B), voiced through
three tokens (d/e/a) that double as the take-variation axis. Any two sounds
that collide in a fast run are consonant *by construction* — which is what
makes rapid tapping feel accidentally musical instead of like clatter. This
is also the owner's oldest standing request: "i do like it when the sound
changes notes as you keep clicking around for diversity and making tapping
around more fun".

---

## 4. The grammar — verbs, materials, events

Sound is keyed to three stacked questions: what did the touch DO (verb), what
did it TOUCH (material), and what did it EARN (event).

### Verbs (weights of one mechanism)

`open` (52 ms, lightest) → `select` (65 ms, a small two-part detent) →
`navigate` (82 ms, the weighted dak) → `place` (118 ms, the confirmed seat).
Same contact, same body bank — only gain, duration, and a second micro-
contact change. Five close takes per verb walk through one global no-repeat
pattern shared across every widget, so no two consecutive taps anywhere in
the app are identical files.

### Materials (bodies of one mechanism) — shipped 2026-08-21

The owner's direction: "when im clicking around i want the interactable
surfaces to feel like different 'textures' of sound and interaction". This is
Minecraft's material-follows-surface logic, built on the perception research
finding that material identity lives almost entirely in **frequency-dependent
damping and spectral density** (Aramaki 2011; Klatzky/Pai 2000; Giordano &
McAdams 2006) — which is exactly the axis a body-swap changes and a sample
swap ruins.

| Lane | Body recipe | Reads as |
| --- | --- | --- |
| **wood** (baseline) | the shipped clasp, untouched | the everyday room |
| **slate** | free-plate ratio set 1 : 1.52 : 1.94 : 2.71, fast upper decay, a heavier double contact 5 ms apart, and a short narrow mineral grain (500–1900 Hz, 7 ms) | the satisfying weighted dak |
| **page** | no pitch of its own: two traveling noise grains plus ~14 fiber micro-crackles (1.5 ms pings, 900–2600 Hz) densifying toward a soft landing contact that carries the field note | a page flipped, landing on the walk |
| **glass** | one sparse clean pair rooted an OCTAVE above the token (1.0–2.6 kHz is where glass reads; the octave keeps the pitch class in-field), tightly damped | a small glass tick, never piercing |
| **brass** | a felt-muted dyad with a slow beat (root × 1.007 — roughness inside the critical band is the metal tell) plus 1.5 and 2.0 partials | precious, warm, gold-only |

Mapping principle: the material follows what the surface **looks like and
commits**. Faceted opaque chips and commit slabs = slate. Travel between
pages/tabs/modes = parchment. Translucent switches and dialogs = glass. Gold
only = brass — if brass played on non-gold it would stop meaning precious.
Everything else = wood. Runtime routes a declared `MaterialSound` onto
`room/materials/<lane>/<verb>/<take>` and falls back to the plain clasp for
any undeclared surface, so the axis can grow lane by lane.

### Events (gestures of one mechanism)

The reward tier was the last part still voiced by bare sine blips — the
"popping bubbles stim toy" — and was rebuilt from the same chain:

- **streak** — one catch, the root, its fifth arriving above: the two-note
  answer outcomes are allowed.
- **crit** — streak's heavier cousin: weighted double catch, denser body.
  Livelier through weight and speed, never through brightness.
- **loot** — discovery: three finds rising through the field, the last body
  opening into the room (the one place breath is allowed).
- **levelup** — ceremony: low root, octave, fifth, then one blooming crown
  dyad. Composed, no fanfare sparkle — "I like the composed stuff".
- **boing** — the friendly settle: two soft catches stepping down. A mistake
  sits back down; nothing scolds.
- **stat_0..5** — one light find per stat, ascending D E F# A B D, so a full
  stat sweep literally plays the field.
- **completion** (pre-existing, untouched) — permanence, not reward: the
  accepted contact, then the Answered Detent exactly 75 ms later, baked into
  one 430 ms file so frame timing can never flam it.

---

## 5. The phone reality

Every decision is made on a physical phone speaker because that is where the
app lives, and phone speakers are brutal:

- They roll off below roughly **800 Hz** — authored low-end "weight" simply
  disappears. Weight must be *implied* by body density and contact strength
  in the 550–1400 Hz band, not by bass.
- **4–5 kHz is hyped and fatiguing** on handsets — nothing in the palette
  stacks energy there; global low-passing shaves everything bright.
- Happy accident: the material fingerprints (damping law, spectral density,
  roughness) all live *above* the roll-off — you lose weight on a phone, not
  identity. That is why material differentiation works at all.

Levels are a designed ladder, not mixing-by-feel: every master is calibrated
to a phone-band (260 Hz–8 kHz) RMS target — open −30.0 dBFS up through place
−27.6, slate place −27.0, events up to levelup −24.8 — under a hard −6 dBFS
peak ceiling, with the level baked into the file so runtime plays Room
masters at 1.0 and can never drift them apart.

---

## 6. The runtime behavior that makes it feel alive

Files are half the system; the router is the other half.

- **One global take walk** across all widgets and roles, with a no-immediate-
  repeat guarantee — repetition is the loudest machine tell there is.
- **18 ms duplicate gate** — two callbacks in one transient produce one sound.
- **Rapid attenuation** — fast tapping softens on the measured ladder
  1 / 0.93 / 0.93 / 0.885 instead of building an accidental drum roll.
- **Reward suppression** — an earned sound mutes ordinary taps for 140 ms
  (430 ms for completion) so the moment that matters owns the air.
- **Paired Return** — after four well-paced accepted actions, the next four
  taps may carry D5→A5→E5→D5 over the unchanged mechanism; once per screen,
  90-second global cooldown. The melodic play the owner loves, kept rare
  enough to stay a gift.
- **The contact sound begins with the bob** — press depth, haptic, and sound are
  one pointer-down event. If that press becomes a scroll, the bob releases and
  the control does not activate, but its already-visible contact is not made
  mysteriously silent. Bare scrolling and a caught fling with no pressed
  control remain silent.
- **A touch that does something is never left unanswered** (owner correction,
  2026-08-21): retapping the active tab acknowledges with a quieter select
  detent; new surfaces wire their verb before they ship.

---

## 7. Why it doesn't sound "AI" or "stock"

Deliberate humanization is baked into the synthesis, not sprinkled on:
partials are detuned by a few cents; every take sits on a different pitch
token; the contact is an irregular real-shaped transient, not a click;
excitation noise makes modes read as struck objects; the crown of levelup
blooms rather than snaps; nothing loops, sparkles idly, or plays a
notification melody. And the deeper reason: every sound exists because a
specific touch *means* something — the mapping is learnable, so the ear
starts trusting the app the way a hand trusts a real mechanism.

---

## 8. The polish pass — what "low quality recording vibe" turned out to be

The first shipped texture render was approved with one note: "they do have
that sort of low quality recording vibe to them although it's not a huge
deal". Diagnosis, in synthesis terms:

1. **Stacked excitation beds.** Each modal body carried its own noise bed at
   gain 0.18. A five-note ceremony therefore carried five uncorrelated beds —
   summed, they read exactly like a recording-room noise floor. Fix: bed gain
   halved to 0.09 per body (the *sound's* total noise is what matters, not
   the note's).
2. **Audible room slap.** The reflection send on long events let the 22 ms
   tap peek above subliminal. Fix: sends trimmed 20 % on events.
3. **Swish.** The page flick was pure filtered noise — which is what a cheap
   recording of paper also is. Fix: rebuilt as fiber micro-crackle over a
   reduced wash; a flip is many tiny snaps, not a swish.
4. **Wide grain.** Slate's mineral grain (420–2600 Hz, 9.5 ms) carried hiss
   along with grit. Fix: 500–1900 Hz, 7 ms, slightly lower.

Measured on the inter-partial noise floor (the level *between* the musical
peaks, 500–3000 Hz): crit −5.7 dB, page −3.4 dB, levelup −2.6 dB, slate
−2.4 dB, glass −1.9 dB — with gestures, notes, and weights byte-identical in
intent. Final verdict: "it sounds wonderful! very well done."

---

## 9. The process that protects all of this

- **Studies, not vibes.** Every change is authored as a reproducible study
  under `design/audits/<date>/<study>/` — deterministic seeds, manifest,
  SHA-256 of every file, provenance, and the exact question being asked.
- **Fair auditions.** A/Bs are level-matched so loudness can't win; sounds
  are judged inside realistic interaction flows, not as solo WAVs; the
  decision environment is the physical phone speaker.
- **The owner's ear is the only taste authority.** A respected audio-quality
  model once scored a rejected sound as the best-produced of the set and the
  explicitly approved fire near the bottom. Measurements gate exports
  (`tool/sonic_taste_gate.py qc`); they never pick winners.
- **Verdicts are recorded verbatim** in `LISTENING-RESULT.md`, and `almost`
  is not approval.
- **Ship exactly what was approved.** Masters go to runtime byte-identical to
  the audition (the fire_ignite precedent) and are byte-locked by tests that
  also grep the source for architectural invariants (every pointer-down bob
  owns one contact sound, pointer-up does not replay it, and completion owns a
  distinct accepted outcome).

## 10. Extending the palette — the short checklist

1. Name the touch's verb, material, and (if earned) event. If none fits, the
   sound probably shouldn't exist.
2. Build from the chain: contact master + modal bank + space fingerprint +
   pitch field. Never import a sample.
3. Respect the ladder: duration and phone-band target by meaning; −6 dBFS
   ceiling; total noise budgeted per sound.
4. Render as a study with seeds and hashes; QC it; audition it level-matched
   in context on the phone.
5. Record the verdict verbatim; ship byte-identical; extend the byte-locks.
6. Silence remains part of the system: scrolling, typing, passive previews,
   and decline/not-now stay quiet — a touch that does something never does.
