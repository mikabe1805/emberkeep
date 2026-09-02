# room-music-v2 — jazzy calm lofi beds (B minor inside the D-major field)

**Owner signal (2026-08-31, verbatim):** "the current music is super peaceful
and could be good for maybe a meditation timer mode thing, but i was imagining
more jazzy calm lofi type background music, specifically it's raining
somewhere else/the place where it rained from undertale/deltarune type thing
was what i imagined". Standing (2026-08-29): "i would love some music though
i loved the music direction you came up with and then how the buttons could
be on beat with the background music" — the answers-on-the-beat mechanic
carries forward, and taps are NEVER quantized. Older taste data on file:
"i was thinking more of that rainy feeling".

**Question this study asks:** what does "that register, in our room" actually
mean — the reference anatomy itself, a lofi head-nod under it, or just its
jazz color at furniture density?

## What the references actually are

Both titles are literal Toby Fox tracks — two renditions of one piece:
"It's Raining Somewhere Else" (UNDERTALE) and "The place where it rained"
(DELTARUNE, same fabric). Verified anatomy: C minor at 96 BPM, STRAIGHT
eighths; an 8-bar loop, two bars per chord, all minor-seventh quality
(i7–v7 planed down a whole step), zero dominant function except one short
bridge; vibraphone-like lead + piano + EP, upright bass in a ballad two-feel,
one constant soft shaker as the only percussion; a narrow stepwise melody
entering on beat 2; structure by layering, not rewriting. **The OST tracks
have no rain** — the titles are narrative. The rain here is OUR room's
window: the owner imagined it, and lofi wants a texture layer.

## The law: B minor inside the D-major field

House law says interaction taps play D-major pentatonic (D E F# A B) and must
land in tune. v1 obeyed it by keeping the music pentatonic-only — which is
why it read ambient, not jazzy (the deviation-from-v1 note: this study
deliberately leaves pentatonic-only music behind). v2's law: the music is
minor-key jazz centered on B minor, **every pitch diatonic to D major**
(D E F# G A B C#). The tap field is a subset of the harmony's scale, so
consonance is guaranteed by construction — the same guarantee, one level up.

The loop, two bars per chord (the reference's planed-down gesture, no
dominant anywhere, Am7's C-natural substituted with the fully diatonic A9sus):

    | Bm9 | Bm9 | F#m7(11) | F#m7(11) | A9sus | A9sus | Em9 | Em9 |

Tap consonance table (tap tone → role over each chord — every cell a chord
tone or a soft jazz tension):

| tap | Bm9 | F#m7(11) | A9sus | Em9 |
| --- | --- | --- | --- | --- |
| D | b3 | b13 (brief aeolian color) | 4 (chord tone) | b7 |
| E | 11 | b7 | 5 | root |
| F# | 5 | root | 13 | 9 |
| A | b7 | b3 | root | 11 |
| B | root | 11 | 9 | 5 |

Bridge, once per render where the candidate calls for it (one bar each):
**Gmaj9 → A13 → Dmaj9 → Em9** — the only major-quality chords and the only
functional dominant (A13's C# resolving to D, our counterpart of the
original's lone leading tone). C# and G stay mid-voice; every chord's top
voice is a pentatonic degree. Melody: narrow, stepwise, centered B4/D5,
entries off the downbeat, sustained tones resolving to pentatonic degrees;
bass: the reference's two-feel (root on 1, octave on and-of-2, fifth on 4,
eighth walk-up into the next chord every second bar), roots in the A2–A3
octave with the two-feel's octave pip ringing the octave above — kept there
on purpose, since lower roots would fight the room bus's 165 Hz high-pass.

## Candidates (`candidates/`, 96 s each — each asks ONE question)

| id | question | feel |
| --- | --- | --- |
| `windowseat` | is the reference register itself the answer? | 96 BPM straight — keys intro, lead + bass + shaker, an EP-ish darker handoff, one bridge pass, a 4-bar breakdown to rain and air, return, slowing tag. Rain gentle (−25.0 dB under the music). |
| `umbrella` | does the room want an actual lofi head-nod under it? | 72 BPM, swung eighths ~57% — dull thump + papery rim dragging behind the grid, chords rolled on it, a sparse behind-the-beat motif. NO hi-hats: **the rain is the hi-hat** (−21.0 dB, gusting, breathing with the swung grid). |
| `drizzle` | how much jazz density does a BACKGROUND want? | ~66 BPM feel, free placement, no percussion — the loop's suspended chords every 8–12 s (mostly Bm9 ↔ A9sus ↔ Em9, rare Gmaj9, no dominant or Dmaj9 arrival), 2–3-note lead fragments, rain sparse (−24.0 dB), and a whisper of the v1 drone air 12 dB under the music — the sparsest bed must never read as stopped (v1's furniture density always kept the drone breathing; the first render hit digital zero between phrases and the spectrogram review caught it). The jazz color at v1's furniture density. |

Rain everywhere is Poisson micro-droplet pings (1–3 ms grains in ~1.2–3.8 kHz
with the occasional larger low drip, density gusting on slow cycles) — many
tiny snaps, NO broadband wash (a swish is the §8 veto). Percussive bed events
are all darker and quieter than any UI contact, and the bed's 550–1400 Hz
content stays sustained — the transient-vs-sustained separation that keeps
taps legible 6 dB above the bed.

Fairness: all three candidates are level-matched at −36.0 dBFS phone-band
RMS — the deliberate floor under the interaction ladder (open −30.0 …
levelup −24.8) so an earned sound always owns the air — under the −6 dBFS
peak ceiling. The audition judges character, not loudness; the in-app level
is a later dial. Per-note excitation runs at 0.012 (keys) / 0.02 (lead) — a
bed's noise budget is per minute (§8). QC clean (`qc.json`, 7/7 ok, no
clipping, mono 48 kHz); `spectrograms.png` shows the phrase shapes, the
droplet field, and the clean floor. `*-score.json` records every pitched
note event (all pitch classes ⊆ {D, E, F#, G, A, B, C#}) plus the chord
timeline, and the Paired Return motif (D5 A5 E5 D5) is excluded by a FULL
sliding-window scan over every voice — v1's prefix/suffix check had an
interior-window gap; v2 closes it.

`flows/<id>-flow.wav` places the untouched interaction role masters over
each bed on v1's schedule — every tap in tune by construction.
`flows/umbrella-answers.wav` is the loved mechanic in the new register:
human-timed taps (instant, deliberately off-grid contacts), each answered by
a soft high pentatonic tone snapped to the next SWUNG eighth. Taps stay
instant; the room replies in time.

## The loop is the idiom; the performance is generative

The harmonic loop repeating is the register's own idiom (the reference does
exactly this). What must never repeat is the PERFORMANCE: every pass carries
seeded velocity/timing/voicing/ornament variation, no two renders of a bar
are identical, and a shipped bed stays a **generative in-app system, never a
fixed loop** — plus a Music switch, an iOS ambient session (the mute switch
and the person's own music always win), and a duck under earned sounds:
its own pass after a verdict. "None of these / a different direction" is a
legitimate verdict too — record it in `LISTENING-RESULT.md` either way.

Deviations from the house audition pattern, both deliberate (v1 precedent):
candidate wavs are PCM_16 (a −36 dBFS bed needs no 24-bit headroom, and the
audition page stays phone-light), and `index.html` references the wavs as
sibling files instead of inlining base64.

Deterministic seeds 13000–13499 (a second render is byte-identical);
`manifest.json` carries SHA-256 hashes, measured levels, and the measured
rain-under-music offset for every file.

Reproduce:

```
python tool/author_room_music_v2_study.py \
    --output design/audits/2026-08-31/room-music-v2
python tool/sonic_taste_gate.py qc \
    --json-out design/audits/2026-08-31/room-music-v2/qc.json \
    design/audits/2026-08-31/room-music-v2/candidates \
    design/audits/2026-08-31/room-music-v2/flows
```
