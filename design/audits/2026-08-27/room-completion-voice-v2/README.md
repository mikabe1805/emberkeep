# room-completion-voice-v2 — a more satisfying completion

**Owner signal (2026-08-27):** "the completion isnt as satisfying."

**Hypothesis:** the shipped completion composite dates to
`room-reward-voice-v1` (2026-08-20) — rendered **before** the render-polish
discipline shipped on 08-21. Its three stacked modal bodies carry the legacy
0.18 excitation beds and the untrimmed reflection send: the same
"low quality recording vibe" mechanism the owner flagged and that was fixed
in every other master, but never re-applied to completion. Beyond that, the
gesture may simply want more physical weight.

## Candidates (`candidates/`, all level-matched to the shipped control's phone-band energy)

| id | change vs shipped |
| --- | --- |
| `control` | the shipped composite, byte-copied (the reference) |
| `polish` | identical gesture, 0.09 beds + trimmed send — isolates the polish question |
| `deeper-seat` | polish + heavier two-part accepted seat, denser root |
| `weighted-answer` | polish + the answer carries its own small catch |
| `longer-settle` | polish + 0.36 s ring, same voices |

`flows/` holds each candidate after two everyday clasps (the in-context
read). `index.html` is the phone audition page (embedded audio). Reproduce:

```
python tool/author_room_completion_voice_study.py \
    --output design/audits/2026-08-27/room-completion-voice-v2
```

Candidates peak ~0.20 vs the control's 0.29 at equal energy — denser body,
less spike, which is the intended "fuller through weight" direction.

## If a candidate wins

Ship path: re-render `answered-detent-natural.wav` and
`completion-composite.wav` from the winning params, byte-identical audition →
runtime, update the byte-locks (including the pinned SHA-256), and note that
`contactAlreadyPlayed` completions play the bare detent — both files change
together. The verdict may also be "keep as shipped."

Note: the owner's report was made against build 33, which predates the
2026-08-25/26 wiring fixes (the quest press was still a parchment page-flip
there). Judge this study alongside the next build, since the completing
press's contact changed from page-flip to the wood clasp.
