# Room of Days room generated-asset record

Updated: 2026-07-31

## Build 39 correction (2026-09-01)

The visible mantel-keepsake experiment was rejected and removed from the
product. The legacy `roomKeepsakes` IDs, state, and serialization fields remain
only as inert compatibility data; they do not render, affect room composition,
or define the current visual system.

The active room set is six complete, authored runtime plates, each with its
chooser preview and deterministic `-soft` derivative:

- `quest-depth-v1` (The Writer's Hearth)
- `conservatory-v3` (The Living Conservatory)
- `listening-v2`
- `archive-v3` (The Moonlit Archive)
- `rain-v1`
- `atelier-v1`

The approved optional room-photo path adds a registered Writer photo-ready
wall only when an explicit local room photo exists. The photo-ready wall is an
exact renamed copy of the registered runtime derivative formerly associated
with the rejected keepsake experiment:

| Candidate asset | SHA-256 | Registration / derivation |
| --- | --- | --- |
| `quest-depth-wall-photo-ready-v1.png` | `11d7c3362c1d5bc68082b326de45bcef61e9e6fdb1da310fcb8302bbccd781a6` | Exact registered wall derivative; source master `design/source-assets/rooms/quest-depth-wall-keepsakes-v1.png` (`6d5bab2ccf3546059d94f6233fdc8bf0f0a4ab488b306d6632d120cb6012bfe7`), scale `.95984`, translation `(56.41, 9.09)`, RMSE `1.22px`. |
| `quest-depth-photo-base-soft-v1.webp` | `fc614a985b2914c7709b7b3030d2dffec452948dcf28fca170f6e079a6d6c183` | Deterministic soft derivative, source blur `22px`, `1024 x 602`. |
| `quest-depth-photo-wall-soft-v1.webp` | `38f55e0fb8eb963cc994b0110f387f53a4b9573328a264a26e13f8d52369347b` | Deterministic soft derivative, source blur `22px`, `1024 x 602`. |
| `quest-depth-photo-furniture-soft-v1.webp` | `0b260e863f25d4b041f6b9dd8b51244b0caef33f78c4e1e2ba7be9e47542d943` | Deterministic soft derivative, source blur `22px`, `1024 x 602`. |
| `quest-depth-photo-foreground-soft-v1.webp` | `9743cba65b2d5cf917d8eddcc117c682ce7663861f976ecb18789ccdd1cae789` | Deterministic soft derivative, source blur `22px`, `1024 x 602`. |

The photo-ready wall's cleared shelf is not a return of keepsakes: it is a
precise registration repair that keeps an owner-selected photo legible. With
no photo, the original Writer quest-depth room and its original depth layers
remain unchanged. The soft photo layers are used only for the existing scroll
transition and never contain live text or UI.

Visual truth:

- `design/visual-targets/2026-07-30/quest-selected.png`
- Existing composition reference:
  `design/source-assets/runtime-originals/assets/rooms/wall_walnut.png`

All source generations used the built-in image generator. The originals remain
in the Codex generated-images folder; only the production-ready derivatives
listed below are bundled with the app.

## Registered room planes

All four planes share a 1635 x 962 camera and are composed in this order.

| Production asset | Generated original | Mode | Content |
| --- | --- | --- | --- |
| `quest-depth-base-v2.webp` | `call_DwaqLhMGVtX1SERkDx77tyvP.png` | generation | Slot-sized runtime derivative of the complete distant architecture: moonlit window, plaster wall, floor, rug, and empty masonry fireplace. |
| `quest-depth-wall-v4.png` | `call_boNQN5p6xBxHf8O70XGWGRnk.png` | generation | Registered wall shelves, books, plants, lamp, and woven hanging on a flat magenta key. |
| `quest-depth-furniture-v1.png` | `call_y0szMh5XFiwmEH7Yy0BKP63u.png` | generation | Registered desk, work objects, and stool on a flat magenta key. |
| `quest-depth-foreground-v1.png` | `call_LWaIyPHZgJUu4buMMrgFf1TI.png` | generation | Registered leather chair and foreground plant on a flat magenta key. |

Production prompt set, normalized from the generation calls:

1. Create a clean, complete distant architectural painting that matches the
   approved dark-warm moonlit study: deep-blue window and crescent moon at
   left, warm textured plaster, walnut floor and rug, and a masonry fireplace
   at right with an empty firebox. Preserve the registered 1635 x 962 camera.
   No furniture, wall decor, fire, people, text, UI, borders, or transparent
   gaps. Painterly, authored, low-detail luxury game illustration.
2. On a perfectly flat magenta background, paint only the registered middle
   wall-decor plane for that same camera: shelves, restrained books and plants,
   warm lamp, and woven hanging. Preserve the approved placement, dark walnut,
   aged brass, parchment, and candle-amber palette. No wall, floor, window,
   fireplace, furniture, shadows detached from the objects, text, or UI.
3. On a perfectly flat magenta background, paint only the registered furniture
   plane for the same camera: walnut writing desk, stool, open book and small
   authored work objects. Keep clean silhouettes and coherent warm lighting.
   No architecture, foreground chair, text, or UI.
4. On a perfectly flat magenta background, paint only the nearest plane for the
   same camera: the leather reading chair and potted plant at left, with clean
   silhouettes and the same painterly finish. No wall, window, desk, fireplace,
   text, or UI.

The keyed planes were converted to alpha with
`remove_chroma_key.py`. The selected wall pass uses no despill and a one-pixel
edge contraction to avoid a pale or magenta halo.

## Autonomous fire frames

| Production asset | Generated original | Mode |
| --- | --- | --- |
| `quest-fire-a-v3.png` | `call_XcVw0JQ7vFrhjOr3kdAA8Y2D.png` | generation |
| `quest-fire-b-v3.png` | `call_XcXsO4JipjcxepHSdlYyDG13.png` | edit |
| `quest-fire-c-v3.png` | `call_Qi7UQwVTlPP0pSbLLmyNq2M1.png` | edit |

Production prompt set:

1. On a pure black 1635 x 962 registered canvas, paint one compact hearth fire
   and fixed log pile at the approved fireplace location. Use simplified,
   hand-painted faceted strokes in deep ember red, amber, honey, and parchment
   cream. No photorealism, room, fireplace surround, smoke, text, or UI.
2. Edit the registered fire into the next modest animation state. Preserve the
   exact canvas, black background, log anchors, footprint, palette, and
   painterly style; alter only the flame silhouette and lean so it can
   crossfade seamlessly.
3. Create the third animation frame by editing the exact registered fire image.
   Preserve the 1635 x 962 canvas, pure solid black background, exact log pile
   position and scale, overall footprint, palette, lighting, and hand-painted
   low-detail faceted style. Make the central tongue a little shorter and split
   near its upper third, let a narrow right-hand tongue rise slightly higher,
   and lower the left tongue. No room, fireplace surround, smoke, text, extra
   objects, or transparent checkerboard; do not move or redraw the logs.

Post-processing:

- Black was converted to alpha with a soft matte, transparent threshold 1,
  opaque threshold 92, and one-pixel edge contraction.
- Each registered fire was scaled to 62% and positioned inside the source
  firebox.
- The final 320 x 300 transparent crops preserve that registration while
  reducing decoded animation memory from roughly 19 MB to roughly 1.1 MB for
  all three frames.

## Me room plate repair

The original walnut room included an accidental rendered `LEVEL 18` HUD at
its lower edge. A built-in image-edit pass removed only that HUD and continued
the existing floorboards. The clean full-resolution source is
`design/source-assets/rooms/wall_walnut-clean-v2.png`; the app bundles
`wall_walnut-clean-v2.webp`.

## Complete Me room identities

As of 2026-07-31, every player begins in a completed room. The room chooser
offers three whole, authored identities rather than a catalogue of necessities.
Glimmers unlock a transformation; they do not rescue an empty space.

| Identity | Runtime plate | Durable source | Generated original | Role |
| --- | --- | --- | --- | --- |
| The Writer’s Hearth | `wall_walnut-clean-v2.webp` | `design/source-assets/rooms/wall_walnut-clean-v2.png` | built-in image edit | Free default; the approved completed walnut room with the accidental Level-18 HUD removed. |
| The Living Conservatory | `wall_conservatory-v1.webp` | `design/source-assets/rooms/themes/wall_conservatory-full-v1.png` | `C:/Users/mikus/.codex/generated_images/019faf64-832e-7d63-8247-d71ac627fd36/exec-abaa3c3c-4de3-4848-b3b5-d8c348e6228b.png` | Complete plant-forward study: aged oak, restrained living greenery, terracotta, moonlight, and a working hearth. |
| The Moonlit Archive | `wall_archive-v1.webp` | `design/source-assets/rooms/themes/wall_archive-full-v1.png` | `C:/Users/mikus/.codex/generated_images/019faf64-832e-7d63-8247-d71ac627fd36/exec-30fa712d-1365-46c5-8250-8c5cfa42f3eb.png` | Complete scholarly study: smoked wood, books, maps, star chart, restrained brass instruments, and a working hearth. |

The canonical edit target for all three is
`design/source-assets/rooms/wall_walnut-clean-v2.png`. Each master is opaque
1536 × 1024 RGB with the same 3:2 camera, left window, right fireplace, floor
foreground, and hearth focal near `(0.83, 0.63)`. No plate contains UI, live
text, people, logos, or a watermark.

`tool/prepare_room_themes.py` creates the two new full-size WebPs and all three
720 × 480 chooser previews in `assets/rooms/previews/`. It preserves the
approved Writer’s Hearth runtime file byte-for-byte. The app preloads the room
selected for a full-screen preview, then moves the intact plate as one
overscanned camera; it never reconstructs these rooms from shop-item masks.

### Living Conservatory production prompt

Precise edit of the canonical walnut room into a complete plant-forward room
identity. Preserve the exact 1536 × 1024 camera, horizon, vanishing perspective,
room boundaries, left mullioned window, right stone fireplace footprint, floor
foreground, and hearth focal. Replace the interior coherently with lighter
aged-oak desk furniture, woven seating, layered shelves, carefully composed
ferns, trailing pothos, olive or laurel leaves, terracotta and dark-brass
planters, and restrained botanical specimens. Match the source’s painterly
faceted architectural illustration, crisp geometry, strong silhouettes,
selective handmade grain, and angular moon/fire light. Use espresso, warm oak,
deep moss, muted olive, oxidized brass, terracotta, parchment, amber, and
restrained blue-green moonlight. Keep it dark, warm, tactile, expensive, alive,
and fully furnished. Avoid bright greenhouse daylight, oversaturated emerald,
fairy lights, magical sparkles, excessive vines, random flowers, glossy tech,
incoherent perspective, equal detail everywhere, empty gaps, text, and UI.

### Moonlit Archive production prompt

Precise edit of the canonical walnut room into a complete celestial archive
for reading, planning, and looking outward. Preserve the same exact camera,
window, fireplace, floor foreground, and hearth focal. Replace the room
coherently with smoked-oak or ebony shelves, a substantial archival writing
desk, dark upholstered reading chair, practical desk chair, books, rolled maps,
one restrained brass armillary, and one framed hand-drawn star chart. Match the
source’s painterly faceted architectural illustration and two-source lighting:
silver-blue moonlight from the left, cream-hot amber firelight from the right,
and at most one explained task-light pool. Use ink blue, midnight indigo,
smoked walnut, charcoal plum, parchment, aged brass, muted silver-blue, amber,
and warm-brown shadows. Keep it serious, personal, calm, luxurious, and not
wizard-themed. Avoid runes, floating objects, magical sparkles, purple neon,
generic fantasy-library props, excessive celestial symbols, glossy tech,
incoherent perspective, empty gaps, readable text, and UI.

### Archived additive-furnishing exploration

The former empty-room, rug, and isolated furnishing WebPs are retained for
recoverability under
`design/source-assets/rooms/furnishing-layers/runtime-archive/`; they are not
bundled at runtime and no longer define product truth. Their source masters may
still be useful for a future optional keepsake system, but a keepsake must add
one isolated object and can never be required to make a room feel complete.

## Quest scroll softening plate

`quest-depth-scroll-soft-v1.webp` is a deterministic runtime derivative, not a
new visual source. `tool/prepare_quest_scroll_backdrop.py` composites the
approved 1635 × 962 Quest camera in the same order as `QuestDepthRoom`—base,
registered middle fire frame, wall, furniture, and foreground—then applies a
22-source-pixel Gaussian softening pass and downsamples to 1024 × 603 RGB WebP
at quality 80.

The plate appears only as quests scroll over the live room. It replaces a
full-room animated BackdropFilter while preserving the approved perceptual
depth transition. At rest the live registered layers remain untouched; the
soft plate never contains live text or UI.

## Runtime-colored fireplace pass

On 2026-08-03 the three complete Me room identities were precisely edited to
remove their baked orange blazes. The resulting fireboxes are intact, dark,
and unlit, allowing the registered `quest-fire-*-v3.png` animation to be the
single visible fire on both Me and Quests. The shared runtime hue rotation
preserves transparency, the cream-hot core, the dark logs, and the painted
frame texture while carrying the equipped wardrobe flame colour.

| Identity | Runtime plate | Durable source | Generated original |
| --- | --- | --- | --- |
| The Writer's Hearth | `wall_walnut-fireless-v3.webp` | `design/source-assets/rooms/wall_walnut-fireless-v3.png` | `C:/Users/mikus/.codex/generated_images/019fca4d-b45e-70e2-ba92-49fd9dbe74b8/exec-fedb6af5-6b7c-4be1-bd2b-5c26ee813518.png` |
| The Living Conservatory | `wall_conservatory-fireless-v2.webp` | `design/source-assets/rooms/themes/wall_conservatory-fireless-v2.png` | `C:/Users/mikus/.codex/generated_images/019fca4d-b45e-70e2-ba92-49fd9dbe74b8/exec-b0243aae-7408-4a32-b910-c7fc9f1dc479.png` |
| The Moonlit Archive | `wall_archive-fireless-v2.webp` | `design/source-assets/rooms/themes/wall_archive-fireless-v2.png` | `C:/Users/mikus/.codex/generated_images/019fca4d-b45e-70e2-ba92-49fd9dbe74b8/exec-a421db60-044a-4ab7-8572-e8309b87180a.png` |

All three masters are opaque 1536 x 1024 RGB precise-object edits. Production
prompt, applied separately to each matching source plate:

> Remove only the burning blaze and central burning logs from the fireplace.
> Reconstruct the now-unlit firebox as dark brick behind the existing iron
> andirons and grate, matching the exact masonry perspective, surface texture,
> shadows, and painterly faceted finish of the source. Remove only the direct
> orange fire glow caused by the blaze while preserving the room's authored
> lamps, moonlight, camera, crop, architecture, furniture, objects, materials,
> and composition exactly. No new objects, people, text, logos, UI, smoke, or
> fire. The result must look like the same complete room with its hearth
> momentarily unlit, not a redesigned room.

`tool/prepare_room_themes.py` produces all three full-size runtime WebPs and
their 720 x 480 chooser previews. At runtime Me quantizes the shared fire loop
to about 11 fps; Quests uses its existing lively/reduced-motion cadence.
