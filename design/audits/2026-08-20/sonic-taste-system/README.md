# Room of Days sonic taste system

Status: **calibration direction, not a runtime sound migration**.

Current calibration artifact:
`design/audits/2026-08-20/note-palette-study-v1/README.md`.

The 2026-08-19 semantic audition is rejected. It was coherent, but it was not
fresh or satisfying. Its down-pitched literal mechanisms, aggressive high-end
filtering, audible recording spaces, and long acoustic tails made the set feel
like old studio Foley. Do not promote or iterate those files as if the choice
were merely between Ledger, Hearth, and Relic.

The approved `fwoosh-c-hearth-bloom` remains the hearth reference. Approval of
that one gesture does not approve the source or processing recipe used by the
rejected interaction set.

## What Mika is actually asking for

These are product requirements, not loose mood-board words:

- “the sound changes notes as you keep clicking around”;
- “crisp and satisfying and high quality”;
- “there's a rhythm and it feels melodic”;
- material-dependent variation like Minecraft footsteps;
- polished, authored impact and hierarchy like remembered Warcraft and
  Overwatch interactions;
- none of the “recorded in a really old recording studio” character of the
  rejected audition.

The “Blue Lips” example is context about how closely Mika listens to musical
shape, tension, and emotional nuance. It is **not** a request to give the app a
darker or deliberately unresolved edge.

The working identity is **modern enchanted tactility**: a clean, close,
immediate physical action with a restrained harmonic layer. It should feel
like the app and the person's hand are briefly playing the same instrument,
not like a notification pack, music box, antique prop library, or miniature
cinematic trailer.

## What the professional systems teach us

### Apple: exact, clean, repeatable, synchronized

Apple's sound-design guidance calls for interaction sounds that are distinct,
appropriate to the app, unobtrusive under repetition, and clean enough to cut
through without becoming abrasive. It explicitly recommends subtle pitch and
level changes for repetitive keys, trimming leading silence and background
noise, preserving a natural fade, testing on both phone speakers and
headphones, and synchronizing sound, haptic, and animation precisely. Apple
also shows that literal physical recordings can be wrong for a modern visual
language even when the recorded object is semantically correct.

- [Designing Sound, WWDC17](https://developer.apple.com/videos/play/wwdc2017/803/)
- [Explore immersive sound design, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10271/)
- [Playing audio](https://developer.apple.com/design/human-interface-guidelines/playing-audio)
- [Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics)

### Minecraft: semantic materials and controlled variation

Minecraft does not make a surface interesting by endlessly pitching one file.
Its sound definitions assign different events to material actions, choose among
multiple recordings, use narrow pitch and volume ranges, and give uncommon
details low probability. Music and ambience also leave intentional gaps. The
result is diversity with a stable material identity.

- [Mojang Bedrock sound definitions](https://github.com/Mojang/bedrock-samples/blob/main/resource_pack/sounds/sound_definitions.json)
- [Mojang block sound assignments](https://github.com/Mojang/bedrock-samples/blob/main/resource_pack/sounds.json)
- [Microsoft custom-sound documentation](https://learn.microsoft.com/en-us/minecraft/creator/documents/addcustomsounds)
- [Minecraft composer interview](https://www.minecraft.net/en-us/article/cherry-groves-composer-interview)

### Blizzard: authored identity and mix priority

Blizzard's published breakdowns describe source recordings as ingredients:
performances and physical recordings are layered, shaped, and mastered into a
world-specific result. Overwatch's “Play by Sound” system deliberately limits
variation on important gameplay cues so people learn a stable sonic identity,
then dynamically gives the most important event space in the mix. That creates
clarity and polish more reliably than making every cue louder or more complex.

- [World of Warcraft sound-design anatomy](https://worldofwarcraft.blizzard.com/en-us/news/9135372)
- [Overwatch: The Elusive Goal — Play by Sound](https://www.gdcvault.com/play/1023010/Overwatch-The-Elusive-Goal-Play)
- [Overwatch 2 environment acoustics](https://overwatch.blizzard.com/en-us/news/23629160/)

## Why the last set failed

The files confirm Mika's description:

- almost all useful air above 5 kHz was removed;
- several sources were pitched downward and inherited room/noise character;
- literal latch, drawer, wax, wood, bowl, and Sansula recordings were allowed
  to carry the identity instead of becoming invisible ingredients;
- long decays made short UI events sound archived rather than immediate;
- material variants changed by only a few cents, so they did not deliver the
  clearly changing notes Mika asked for;
- semantic sounds were designed in isolation rather than heard as a rhythmic
  series under real tapping.

This was a direction error, not a mastering tweak. More EQ on the same sources
will not fix it.

## Sonic grammar v1

### 1. A contact lane preserves the material

Each repeated material family gets four to six genuinely different, clean,
close-miked source gestures. A shuffle bag prevents immediate repetition.
Pitch drift on the physical contact stays small enough that wood remains wood,
paper remains paper, and brass remains brass.

Working material families:

| Family | Product meaning | Contact character |
| --- | --- | --- |
| wood / leather | ordinary room controls and held tasks | close, dry, rounded, decisive |
| paper / ink | plans, journals, order, placement | compact fiber/ink motion, not page noise |
| stone / brass | dates, commitments, ranks, durable states | precise mass with a short clean body |
| glass / air | lenses, reveal, preview, delicate overlays | clear but never icy or sparkly |
| flame / breath | hearth and rare living-room gestures | warm pressure and irregular movement |

Ordinary contacts target an audible response inside 100 ms, nearly no leading
silence, an 8–30 ms designed transient, and a controlled 80–220 ms body. Those
are audition constraints, not automatic approval thresholds.

### 2. A quieter note lane creates play

The clearly changing note belongs to a separate, quieter tonal layer. This
lets a material stay believable while quick taps form a short phrase.

The palette, contour, and cadence are intentionally unchosen. A sequence after
a pause may begin from a stable home note, quick continuation may move by
clearly audible scale steps, and 700–900 ms of rest may reset the phrase. The
first study must compare different emotional colors instead of silently
selecting a dark, suspended, cheerful, or fantasy-coded mode in advance.

The useful clue from “Blue Lips” is simply that broad labels like “pleasant”
will not be enough for the preference model. Mika hears how a phrase develops.
It is not a brief for the app's harmony.

### 3. Meaning controls how much variation is safe

- Repeated, low-stakes contact may vary recording, note, and micro-dynamics.
- Navigation should be recognizably related while still supporting a phrase.
- Save, boundary, completion, streak protection, discovery, and ceremony each
  keep one learnable fingerprint.
- Critical semantic cues vary only subtly. They never become a random melody.
- Sound priority is ceremony > discovery > progress > confirmation > contact.
  An earned cue gets space instead of fighting the tap that caused it.
- Silence remains a designed response for scrolling, typing, busy presses,
  passive updates, and insignificant visual changes.

## Modern-production contract

A shipping master must:

1. start from a lossless, licensed original or an owned recording;
2. expose no audible room tone, codec swish, electrical hum, or inherited
   background bed in the final UI-sized tail;
3. retain enough upper detail to feel immediate without a painful 2–6 kHz
   spike or brittle 8 kHz hiss;
4. have a deliberately authored transient, body, and exit rather than one
   blanket low-pass filter and fade;
5. be compared at normal phone-speaker loudness, on headphones, and under fast
   repeated taps inside the actual interface;
6. align its audible cause with press motion and haptic closely enough to read
   as one event;
7. carry source, license, edit recipe, approval, and replacement history.

Preview MP3s may support exploration but may not become new shipping masters.
The already approved fire is recorded as a provenance exception rather than a
precedent.

## The reliable model: Sonic Taste Gate

The tool is a selection and quality-control system, not a sound generator and
not an automated taste authority.

### Layer A — deterministic release checks

Measure format, onset, duration, peak, clipping, DC offset, crest factor,
background/tail energy, frequency balance, and mono compatibility. These checks
can find damaged or poorly prepared files. They cannot decide whether a sound
is delightful.

### Layer B — advisory machine listening

Audio/text embeddings such as [Microsoft CLAP](https://github.com/microsoft/CLAP)
may flag a candidate that is semantically far from its contract—for example, a
“warm wooden contact” clustering with glass bells. Aesthetic models may provide
another warning signal, never a ranking authority.

That distinction is empirical. In a first local test, Meta's
[Audiobox Aesthetics](https://github.com/facebookresearch/audiobox-aesthetics)
gave the rejected `boundary_soft` candidate the highest production-quality
score in the comparison, while giving the user-approved fire a low enjoyment
score. The model was behaving as designed: estimating broad rater judgments,
not learning Mika's taste or judging a cue in Room of Days.

| Local sample | Content enjoyment | Production quality | Human evidence |
| --- | ---: | ---: | --- |
| approved fire C | 2.538 | 5.275 | explicitly selected |
| current wood tap | 5.201 | 5.531 | tap family rejected |
| rejected `boundary_soft` | 4.130 | 7.944 | rejected with its batch |
| rejected `rank_advance` | 3.371 | 6.818 | rejected with its batch |

### Layer C — Mika's role-specific preference model

The authority is a short in-context comparison: `A`, `B`, `both bad`, or `no
preference`, with optional words. Comparisons remain within one interaction
role. A regularized pairwise model learns a ranking only after enough labels;
it does not collapse fire, taps, boundaries, and ceremonies into one universal
“good sound” score.

The model may rank unseen candidates only after reaching at least 80% held-out
agreement with Mika within that role. It can never auto-promote a master.

## Calibration plan

The first useful session is 36 purposefully different candidates: six each for
repeated contact, navigation/selection, plan/save, gentle boundary, earned
completion, and rare discovery. The set must vary real production dimensions—
transient shape, material density, note grammar, brightness, body, and contour—
instead of offering six EQ versions of one recording.

Approximately 30–50 comparisons should be enough to discover whether a role is
converging. Every session includes current and rejected anchors so “less bad”
cannot masquerade as approved. The user listens in the real UI first; isolated
WAVs are a diagnostic view.

Only after this calibration should the code gain a stateful sonic director and
only after the director proves useful should the lab be packaged as a reusable
Codex plugin. No currently available plugin supplies this combination of
personal preference learning, interaction context, provenance, and release QC.

## Local tool

`tool/sonic_taste_gate.py` is the dependency-free first layer. It currently:

- inspects PCM WAV exports and reports objective release measurements;
- creates deterministic, role-local comparison sessions from a manifest;
- records `A`, `B`, `both bad`, and `no preference` as different evidence;
- fits provisional role-local pairwise rankings and says when the comparison
  graph is too thin to support a ranking.

It deliberately has no `approve` command. Later advisory listening models can
add warnings without changing that authority boundary.

Example:

```powershell
python tool/sonic_taste_gate.py qc assets/sfx --json-out sound-qc.json
python tool/sonic_taste_gate.py make-session --manifest candidates.json --out session.json
python tool/sonic_taste_gate.py fit --session session.json --ratings choices.jsonl --out fit.json
```

## Next production pass

1. Build the comparison harness and objective checks.
2. Create one deliberately broad six-candidate repeated-tap study from clean,
   lossless sources and modern hybrid synthesis.
3. Audition it through a real press/haptic loop, including rapid sequences.
4. Learn the first role model; keep `both bad` as a first-class outcome.
5. Only then expand to confirmation and completion roles.
6. Preserve the approved fire and do not remaster it silently.
