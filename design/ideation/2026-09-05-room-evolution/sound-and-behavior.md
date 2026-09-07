# Sound and behavior brief

This is a concept constraint, not a request to preserve the later Goals visual rewrite. Keep the recognizable Build 41 room, color relationships, and depth; let the new concepts substantially improve hierarchy, motion, and surface craft while retaining the sound language below.

## What already exists

There is an upgraded, authored tap-sound pack, and it is already in the Build 41 continuation. The later `goals-everyday-review` checkout and `build41-authored-continuation` each contain the same 110 `assets/sfx/room` files, with no SHA-256 differences, and their central `lib/audio.dart` routing is identical. No sound asset port is needed.

The pack includes:

- 20 ordinary contact masters: `open`, `select`, `navigate`, and `place`, five deterministic takes each.
- Material shading for shipped lanes only: slate, page, glass, and brass.
- The rare Paired Return phrase, D5 -> A5 -> E5 -> D5, across the four verbs.
- An accepted completion voice: Answered Detent by itself, plus a contact-to-outcome composite.

`ASSET-LICENSES.md` and `assets/sfx/SOURCES.md` record these as project-authored deterministic synthesis. The ordinary contacts, material lanes, and Paired Return phrase were physically approved on iPhone; the app still needs contextual listening when a redesigned surface changes density or timing.

## Event map for all three concepts

| Product event | Sound route | Motion relationship | Ownership / silence rule |
| --- | --- | --- | --- |
| An accepted press or choice | ordinary `select`; wood by default | Land at physical contact, alongside the shortest compression response | Disabled, rejected, dragged-away, or cancelled input stays silent. One control owns the contact. |
| Open or reveal a contained layer | `open`; page for a folio, glass only for a translucent chooser | Contact first, reveal follows immediately | Do not add a generic click beneath it. Do not invent an unshipped material lane. |
| Move between meaningful room planes | `navigate`; page or slate when the visible surface supports it | Start on the accepted destination change, not on speculative hover | Failed navigation stays silent. Repeated tab taps should not stack voices. |
| Save, place, or commit | `place`, after the mutation is accepted | The settling motion and sound should share the same outcome beat | Back, dismiss, and unchanged submissions stay silent. |
| Complete a Quest | `playCompletionAccepted` as one atomic contact-to-outcome plan | The exact Quest responds first; the reward follows as a distinct consequence | If the visible control already voiced contact, use Answered Detent only. Otherwise use the composite. Never layer a second tap sound. |

Material is semantic shading, not decoration. A visual restyle can change geometry and animation while the same event keeps the same verb. New concept controls should route through the central director rather than trigger assets directly.

## Cancellation and overlap contract

- Duplicate callbacks inside 18 ms collapse to one voice. Rapid accepted input inside 180 ms becomes slightly quieter (`1.0`, `0.93`, `0.93`, `0.885`) and aborts Paired Return eligibility; it must not become a loud stack.
- Paired Return is a rare melodic easter egg inside ordinary accepted actions, not an “after absence” cue. It requires four eligible actions no more than 700 ms apart, plays once per screen, and has a global 90-second cooldown. A screen change, rapid input, long gap, or higher-priority outcome interrupts it with no catch-up notes.
- Higher-priority events suppress ordinary contacts for 140 ms and duck the music. Completion suppresses ordinary contacts for 460 ms, interrupts any phrase even while muted, and deduplicates the same transition ID for two seconds.
- Normal assets have a four-player pool; Paired Return has one player. The event director's semantic gates remain the authority even when the audio backend could overlap files.
- Delayed rewards use the existing `playAfterContact` spacing (65 ms by default) so contact and consequence do not collapse into a harsh double hit.

## Best existing audition

Use [`discovery.wav`](C:/Users/mikus/Downloads/experimentProject/app/.worktrees/goals-everyday-review/design/audits/2026-08-20/room-paired-return-phone-gate-v1/reels/discovery.wav) (727,244 bytes; SHA-256 `70367FDE39C5D9935837E87763C70DEFE0464F245EB454E7C8401720989A3737`). It demonstrates varied ordinary contacts, the qualifying run, the approved D5 -> A5 -> E5 -> D5 phrase, and the return to plain contacts during cooldown. This is the most useful single file for hearing the upgraded tap language before judging it against any concept image.

## Behavior implications with calibrated evidence

- **Initiation:** stable-context repetition varies substantially across people and behaviors ([Lally et al.](https://doi.org/10.1002/ejsp.674); [Singh et al.](https://pmc.ncbi.nlm.nih.gov/articles/PMC11641623/)), while specific if-then plans can support initiation ([Gollwitzer & Sheeran](https://doi.org/10.1016/S0065-2601(06)38002-1)). Concepts should keep an optional cue and a small, concrete field of actions. The evidence does not establish three as optimal.
- **Immediate reward:** the safe design implication is exact competence feedback: name the completed action and its real consequence, keep undo available, and avoid controlling or moral language ([Deci et al.](https://pubmed.ncbi.nlm.nih.gov/10589297/); [Sheeran et al.](https://pubmed.ncbi.nlm.nih.gov/32437175/)). It does not establish the app's RPG economy as behaviorally effective.
- **Return:** preserve prior work and offer a smaller next move without catch-up language ([Breines & Chen](https://pubmed.ncbi.nlm.nih.gov/22645164/); [Biber & Ellis](https://pubmed.ncbi.nlm.nih.gov/28810473/)). Gamification evidence is mixed and bundled ([Johnson et al.](https://pmc.ncbi.nlm.nih.gov/articles/PMC6096297/)), so Paired Return, XP, streaks, and collectibles remain authored product choices to test in context rather than efficacy claims.

These implications should survive all three visual concepts. The research does not prescribe a palette, room metaphor, or animation style.
