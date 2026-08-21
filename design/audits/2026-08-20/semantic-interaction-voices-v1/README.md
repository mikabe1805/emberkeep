# Semantic interaction voices v1

Status: **awaiting role-language feedback**. Nothing in this folder is wired
into the app.

This study answers a different question from the prior weight/finish matrix:

> Do these sound like distinct, satisfying interaction verbs when used in a
> normal app flow?

## The four voices

| Voice | Interaction meaning | Representative action |
| --- | --- | --- |
| `dak` | move somewhere | switch page or major section |
| `tak` | open or press something light | open a journal entry or sheet |
| `tuk` | a small state settles | choose a date, toggle, filter, or pin |
| `bloop` | earned completion | finish a quest or routine |

`dak` is the approved C family copied byte-for-byte. `bloop` is the current
runtime `complete.wav` copied byte-for-byte. Only `tak` and `tuk` are newly
authored in this pass.

## How to listen

1. Press **Start sound lab** once.
2. Press the four action cards as if they were real app controls.
3. Use **Play a normal flow** to hear the vocabulary as one short interaction
   sequence.
4. For the three everyday contacts, try the eight-tap runs. `tak` and `tuk`
   deliberately move farther in pitch than C while keeping one texture.

Useful feedback is role-specific: `tak is too sharp`, `tuk feels too much like
dak`, `the four verbs make sense`, or `the current bloop no longer fits`.

## Contract

- The role comes first; visual material is only an authoring ingredient.
- One action gets one immediate voice. Navigation is `dak`, not `tak + dak`.
- Quest completion is the deliberate exception: a small accepted-state touch
  can precede the earned `bloop` by 65 ms.
- Already-selected tabs, scrolling, typing, loading, passive previews, cancel,
  and background sync are silent.
- Rare reward, discovery, level-up, and hearth cues remain separate and sparse.
- Every new click is dry, mono, 48 kHz PCM24, and has no literal prop recording,
  reverb, room tone, or sparkle layer.

## Approval boundary

This lab establishes the vocabulary, not final runtime loudness. An approved
set still needs to be mixed with the real press animation and native haptics on
a physical phone. Runtime files and routing remain unchanged.
