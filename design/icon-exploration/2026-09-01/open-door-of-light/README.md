# Room of Days — Open Door of Light

Status: owner-selected production launcher direction, 2026-09-01.

## Decision

The previous Day Ledger launcher mark was professionally finished but led with
the planner category rather than the emotional reason to open Room of Days.
The owner reset the brief with:

> "not sure the book ledger thing is what would get people clicking on the app"

Three independent world-first directions were generated. After reviewing them,
the owner selected the first direction:

> "theyre great so well done! 1 and 2 are my favorites and i think 1 is the best for room of days"

The selected mark is **Open Door of Light**: one angular walnut threshold, a
door held ajar, and one contained honey path into the room. The visual job is
invitation and world-recognition before planner explanation.

## Production sources

- Opaque master:
  `design/source-assets/runtime-originals/assets/brand/room-of-days-open-door-source-v1.png`
  - 1254 x 1254, opaque RGB PNG
  - SHA-256:
    `2ABAC214582901D4456642D5D49CCA8E68DEA943C5B7E69C34F9AD13E1ED4524`
- Adaptive extraction source:
  `design/source-assets/runtime-originals/assets/brand/room-of-days-open-door-chroma-v1.png`
  - 1254 x 1254, opaque RGB PNG
  - SHA-256:
    `9CB20A12FC163EC1AEDD073C647A30CAE089CF57D0286C5EA2047310DD4A83CE`
  - technical green-screen derivative only; never use as public artwork

Both rasters were created with the built-in image-generation tool. The master
was generated from visual references; the chroma source is a precise-object
edit of the selected master for deterministic Android foreground extraction.

## Master prompt

```text
Create an original 1024×1024 App Store icon concept for the app Room of Days.

Internal direction name: Open Door of Light.

Core idea: one bold, angular doorway or room portal in near-black espresso walnut, opened just enough to cast a single warm honey-gold wedge of light into the dark. The light should feel like the emotional payoff of doing one difficult ordinary thing: a warm little world opening up. Let the light form a subtle forward or upward path through composition and angle, but it must not become a literal checkmark, arrow, letter, or task symbol.

First-read goal at tiny size: “a warm world is waiting for me,” not “planner,” “calendar,” “book,” or “productivity software.” Use one unmistakable silhouette, controlled asymmetry, generous breathing room, and strong value contrast that survives at 32 px. Make it professional and authored, with restrained tactile wood/brass material character and disciplined sourced light—not photorealistic 3D, glossy SaaS gradients, or a miniature room scene.

Reference roles:
- app_icon_master.png is the standard for Room Notes’ professional restraint, sparse silhouette, tactile seriousness, and small-size clarity. Do not copy its page/pen composition.
- Icon-1024.png is the current Room of Days icon being replaced. Preserve its dark-walnut/honey warmth but explicitly avoid its book, ledger, checklist, tiny UI, and busy miniature-object reading.
- 01-quests-1290x2796.png supplies the real Room of Days quest-room materials, palette, and angular architectural language.
- 02-reward-1290x2796.png supplies the emotional sense of earned warmth and visible reward, not literal text, coins, XP labels, or UI.
- 08-change-space-1290x2796.png supplies the inviting moonlit-room atmosphere, but simplify it to a single emblem.

Composition and export constraints: full-bleed square artwork, centered mask-safe emblem with generous margins for both iOS squircle and Android circle crops; no baked rounded-corner mask; no device mockup; no border; no title text; no letters or numbers; no book, ledger, pages, calendar, checklist, checkbox, phone UI, furniture collage, fake app screenshot, stars, sparkles, particles, fantasy filigree, watermark, or brand names. Palette: mostly deep espresso/black walnut, warm honey/amber and a small cream-hot core; at most a tiny earned accent of moonlit blue. Keep the mark bold, singular, emotionally magnetic, and credible beside a polished professional app icon.
```

## Adaptive-source edit prompt

```text
Use case: precise-object-edit
Asset type: production chroma-key source for an Android adaptive launcher icon
Input image: the supplied Open Door of Light icon is the sole edit target.
Primary request: replace only the surrounding near-black square background outside the freestanding doorway emblem with a perfectly uniform, flat chroma green (#00FF00). Preserve the approved icon subject exactly: the complete outer dark-walnut architectural frame, the partially open wooden door, the bright cream-and-honey interior opening, the cast honey light path on the ground, its grounded shadow edges, all existing proportions, perspective, texture, lighting, crop, centering, and generous margins.
Composition: same 1:1 square canvas and exact object placement as the source.
Constraints: this is a technical extraction source, not a redesign. Change only the outer background. Keep the entire door/frame/light-path subject opaque and fully visible. Use hard, clean subject boundaries with no green spill or green tint on the wood, light, or shadow. The green must be solid and textureless from edge to edge wherever the original background was removed.
Avoid: changing geometry, opening angle, light shape, palette, materials, contrast, scale, perspective, crop, or camera; no new objects; no text; no rounded-corner mask; no border; no transparency; no vignette; no gradient in the green background; no watermark.
```

## Visual evidence

The approved master was inspected beside the outgoing Room of Days icon and the
Room Notes icon at 1024, 180, 60, and 32 pixels, plus square, iOS-squircle,
Android-circle, safe-area, and grayscale/themed previews:

- `design/icon-review/2026-09-01/open-door-of-light/contact-sheet-32-60-180-1024.png`
- `design/icon-review/2026-09-01/open-door-of-light/contact-sheet-platform-masks.png`
- `design/icon-review/2026-09-01/open-door-of-light/REVIEW.md`
- `design/icon-exploration/2026-09-01/open-door-of-light/shipping/shipping-platform-review.png`
- `design/icon-exploration/2026-09-01/open-door-of-light/shipping/shipping-platform-review-phone.webp`

The singular threshold and contained light remain legible at 32 pixels. The
platform masks preserve the subject, and grayscale retains the structural
light/dark split. No refinement to the owner-selected opaque master was made.

The remaining visual gate after deterministic export is a real launcher check
on iPhone and Android hardware. That check may reject a derivative or inset; it
must not silently reinterpret the selected master.
