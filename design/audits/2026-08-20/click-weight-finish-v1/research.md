# Turning approved C into a system

## Owner signal

> I think I like C best! you're definitely finally in the right direction so well done! If you can now do different varients with different "weights" or "materials" that would be awesome!

This is a specific and reaffirmed approval. C is therefore the control. New
sounds must earn replacing or tinting it; C does not disappear into a shuffled
set.

## Approved identity

Candidate C is a 60 ms virtual press mechanism:

- fixed clean contact, gain 0.620 and 2.05 ms decay;
- compact inharmonic body, gain 0.255 and 10.5 ms decay;
- quiet second closure, gain 0.076 at exactly 6 ms;
- body-only micro-pitch variation across five related variants;
- common 160 Hz high-pass, 10 kHz low-pass, and 22 ms tail-parking gate;
- practical silence before the later +65 ms outcome lane.

The new anchor files are copied byte-for-byte from the approved study and their
SHA-256 hashes are recorded in `manifest.json`.

## Two orthogonal controls

### Weight

Weight describes interaction physics, not visual material. Contact and closure
remain fixed while body energy and damping move:

| Weight | Body gain | Body decay |
| --- | ---: | ---: |
| Light | 0.205 | 9.0 ms |
| Settled · C | 0.255 | 10.5 ms |
| Weighty | 0.305 | 11.5 ms |

This lets a chip feel nimble and a save button feel seated without inventing a
different sonic language for each widget.

The weighty tier was deliberately kept close to C after quality review. A
longer 13 ms body began to read as a low, lingering boop; the final 11.5 ms
body keeps the extra seat while clearing the sound well before an outcome cue.

### Finish

Finish changes only a small part of the spectrum and texture. Each treatment
blends the same clean procedural contact/body/closure with short filtered
excitation and, for the brighter finishes, very quiet unequal-decay inharmonic
modes. No treatment introduces a sampled object, room, or long resonance.

- **Warm room** rounds the leading edge and concentrates the body lower.
- **Soft page** is drier and more brushed through the middle, without paper
  rustle or archive noise.
- **Clear lens** keeps a finer leading edge and a brief upper-mid definition,
  without a glass ping.
- **Quiet gilt** adds the densest controlled upper modes, without a bell tail.

The labels describe intended UI placement. They are not claims that the sound
literally resembles wood, paper, glass, or metal.

## Runtime interpretation if approved

The current material enum should eventually become a typed contact request:

`contact(weight: light|settled|weighty, finish: room|page|lens|gilt)`

The immediate contact stays on raw pointer-down with the existing selection
haptic. Completion, save, reward, error, and ceremony remain outcome roles and
must not be replaced by a heavier click. A quest card can therefore play a
weighty room/gilt contact immediately and a separate completion cue only after
the state actually commits.
