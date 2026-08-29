# Workshop steward character lock

Status: owner-selected identity lock, corrected for separated v2 production
planes on 2026-08-29.

The ordinary Goal Study remains character-free, but the owner explicitly
requested that this steward appear inside his separate tavern workshop. The
earlier no-shipping restriction is superseded for that destination. Generated
runtime plates may ship only when they use the anchor, pass this consistency
gate, preserve the complete prompt/provenance record, and still receive
owner/device acceptance.

## Owner decisions

> "i dont think it's bad for the person to be attractive, i actually quite like the second one i just think whatever features you give him or his outfit need to be consistent with every regeneration of him"

> "make sure the pencils in his pocket look like actual pencils"

> "looks wonderful! i'd build out more functionality now i think, maybe make the npc aspect actually fleshed out and make the different expressions as initially promised"

> "you could honestly make him feel more alive by not making him have the same pose everytime, but rather different poses for different expressions/sprites, and then the offering note thing only for when its relevant to the user/the npc triggers something user facing"

> "it would also be really cool if you produce him separately from the background so we can apply the multilayer effect on the goals page too"

Direction B is selected. Attractiveness is not a defect. Identity and outfit
drift are the failure condition.

## Canonical references

- `steward-character-anchor-v1.png`
  - SHA-256: `f04a8dd0a338bd316e6707feaa8f38f8873de6f428e2365f4c46aa09fbccabd0`
  - Primary authority for face, hair, build, outfit, and drawing language.
- `steward-character-handoff-v1.png`
  - SHA-256: `7639ac37ee8b084cbe0f8ab6b269770badb5af07ba8608341e534aac48b4a120`
  - Approved consistency test for the exact-card handoff pose.
- `steward-character-drawers-v1.png`
  - SHA-256: `a8293c8eb88f581b0736602bbd8f9298a15edc102514ed1af9bd728de429adc4`
  - Approved consistency test for a turned full-body working pose.

The anchor image must be supplied as an image reference for every future
generation. Never recreate the steward from prose alone.

## Identity invariants

- Clearly adult man; do not age-shift him between scenes.
- Lean build, long proportions, and slightly relaxed shoulders.
- Long narrow soft-diamond face with a tapered jaw and chin.
- Heavy straight brows; slightly downturned almond eyes with weighted upper
  lids and quiet lower-eye shading.
- Long straight-to-softly-convex nose and a restrained closed mouth.
- Dark shoulder-length layered hair with a center part, two uneven
  face-framing locks, and a low loose ponytail.
- One small hoop earring in his left ear.
- Calm, watchful, slightly distant expression. Attractive is welcome; a broad
  smile, hostility, or generic replacement face is not.

## Outfit invariants

- Hooded work overshirt with a broad folded collar over one plain close shirt.
- Dark apron with two square aged-brass strap fasteners and a narrow waist tie.
- One stitched rectangular patch on his left upper sleeve.
- One small rectangular pencil pocket high on the left chest of the apron,
  directly below the left fastener. No hip tool pouch.
- Exactly two wooden drawing pencils in that pocket, at slightly different
  heights: hexagonal muted ochre-brown shafts, exposed sharpened wood, visible
  graphite points, and modest ferrule/eraser ends when perspective permits.
  They must not read as pens, styluses, brushes, screwdrivers, or metal tubes.
- Dark work trousers and ankle boots. Do not add fantasy or steampunk gear.

## Regeneration protocol

Use the built-in image generator in identity-preserve mode with
`steward-character-anchor-v1.png` as Image 1. The new prompt may change only
pose, action, expression within the established range, crop, or environment.
Repeat the identity and outfit invariants explicitly on every call.

Minimum prompt scaffold:

```text
Use case: identity-preserve
Input images: Image 1 is the canonical Workshop steward anchor and the sole
authority for identity, proportions, outfit construction, and drawing style.
Primary request: draw the exact same adult man in <new pose/scene>. This is not
a redesign and not a merely similar attractive man.
Constraints: preserve face ratios, eyes, nose, jaw, hairline, center part, low
ponytail, left hoop earring, build, hooded overshirt, apron, two brass
fasteners, left-sleeve patch, left-chest pocket, and exactly two recognizable
wooden pencils. No mirrored details, extra tools, costume changes, labels, UI,
logos, or watermark.
```

## Consistency gate

Compare every result with the anchor at full resolution before keeping it.
Reject and correct the result if any of these change: eye spacing or shape,
nose length/profile, jaw width, hair part or tie height, earring side, body
build, collar/hood construction, apron fasteners, patch side, pocket location,
or pencil construction/count.

The first independent handoff generation widened his jaw and changed his eyes;
it was corrected against the anchor. Recognizability alone is therefore not a
pass. The face and outfit must survive the new pose as the same designed
person.

## First runtime plate

- `assets/pages/goals-workshop-tavern-steward-v1.webp`
- Lossless source:
  `design/source-assets/runtime-originals/assets/pages/goals-workshop-tavern-steward-v1.png`
- Role: returnable tavern register and selected-goal bench background.
- Locked result: the steward is visibly waiting behind a walnut counter with a
  blank route card and exactly two sharpened wooden pencils in the high
  left-chest apron pocket. Live Flutter UI owns every word and interaction.
- Remaining gate: rendered phone comparison plus owner/device acceptance.

This full-scene v1 plate remains an identity, room, and composition reference.
It is superseded as the production runtime by the separated v2 planes below.

## Runtime expression set

The owner accepted the tavern slice and asked for the steward to feel more
fleshed out. Reactions are tied to real workshop state; they are not an idle
loop, dialogue tree, relationship meter, or praise system.

- `welcome` — empty hands, attentive open posture, one hand near the file box.
- `considering` — head and gaze lower while he reads one route card toward
  himself.
- `ready` — he squares toward the visitor and offers one route card. This is
  the only pose that presents a note to the person.
- `acknowledging` — empty hands, a relaxed lean, and the smallest earned warmth
  after that exact Quest is already on the board.
- `closing` — he turns toward the file box and physically files the completed
  route card.

Every v2 variant is a transparent 852 x 1847 steward sprite registered to the
same camera. Pose, gaze, head angle, shoulders, and motivated hand action may
change by state. Identity, face ratios, outfit construction, left-side details,
and exactly two sharpened wooden pencils remain locked.

## Separated production planes

The live Workshop and Goals arrival compose the same three registered planes:

1. `goals-workshop-tavern-back-v2` — the empty rear tavern room.
2. `goals-workshop-steward-<state>-v2` — one transparent state-specific
   steward sprite.
3. `goals-workshop-tavern-counter-v2` — the transparent foreground counter
   and file box.

The rear room, person, and foreground may carry only a few pixels of restrained
depth from the shared Goals motion source. Reduced Motion must hold every plane
still and swap poses immediately. The canvases, crop, `BoxFit`, and alignment
must remain identical so the character never shears away from the room.

## Surface treatment lock

- Clean graphite contours establish face, hair, hands, apron seams, card, and
  file-box edges.
- Warm broad watercolor or gouache masses carry the room and clothing values.
- Sparse directional hatching is allowed only in small deep-shadow zones such
  as under the fringe, jaw, collar, sleeve folds, and counter underside.
- Reject dense all-over crosshatching, scratched skin, patterned apron fields,
  or an engraved surface treatment. The face must remain the calmest and
  cleanest emotional read point.

## Remaining decisions

- No name is selected.
- A production color palette is not locked by these graphite references.
- Final owner-drawn linework, physical-phone depth feel, and owner/device
  acceptance remain open gates.
