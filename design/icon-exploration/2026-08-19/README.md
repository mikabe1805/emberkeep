# Room of Days app-icon exploration

## Task 1 baseline record

This record locks the visual references and current icon baseline before any candidate generation. No artwork was generated or modified in Task 1, and no shipping icon asset was touched.

### Directly inspected references

- `web/icons/Icon-1024.png` — current 1024 px shipping icon; an isometric brass room/sun mark.
- `test/goldens/store_01_quests_1290x2796.png` — Quests capture with the warm inhabited room, books, brass controls, honey light, and espresso shadow language.
- `test/goldens/store_02_keep_1290x2796.png` — Me/space capture with the same room, folio-like panels, brass, and controlled warm light.
- `test/goldens/store_05_planner_1290x2796.png` — Planner capture with the same dark wood, folio, parchment, brass, and candlelight material system.
- `design/source-assets/runtime-originals/assets/brand/room-of-days-icon-source-v2.png` — archived source reference for the current icon craft and composition.

The references are visually coherent: the current icon reads as an isometric brass room/threshold with a central honey light, and the app captures establish the same warm room, folio, brass, and controlled-light product world.

### Current baseline copy

- Source: `web/icons/Icon-1024.png`
- Review copy: `design/icon-exploration/2026-08-19/current/master-1024.png`
- Source SHA-256: `ADC3B999C6730C7A592BA4E1AD2718E0172ED983A5AD15EB256366F4FCF8496B`
- Review-copy SHA-256: `ADC3B999C6730C7A592BA4E1AD2718E0172ED983A5AD15EB256366F4FCF8496B`
- Hash confirmation: exact match.

The review copy is a byte-for-byte copy of the source. It is a review baseline only; selection and later propagation remain separate decisions.

### Fixed review criteria

Every later candidate must be assessed for:

- product connection
- small-size recognition
- material coherence
- category confusion
- iOS mask
- Android circle/safe area
- themed-icon viability

## Task 2 prompts (exact text)

### Inhabited Room / World

```text
Use case: logo-brand
Asset type: 1024 x 1024 mobile app icon master
Primary request: Create a single iconic inhabited room or threshold shaped by warm spatial light, expressing that opening Room of Days means returning to a place that holds your days.
Input images: current icon as identity baseline; three app screenshots as material, lighting, and product-world references; archived source as craft reference. References are moodboard inputs, not edit targets.
Style/medium: production-quality restrained three-dimensional icon artwork, authored and tactile rather than glossy or cartoonish
Composition/framing: one centered silhouette, generous negative space, one unmistakable focal point, readable at 32 pixels, safe inside iOS squircle and Android circular/adaptive masks
Lighting/mood: one controlled honey-colored light source against espresso shadow; calm, intimate, quietly alive
Color palette: espresso brown, book-cloth charcoal, aged brass, honey light, muted parchment only
Materials/textures: subtle wood, cloth, and aged metal; simplify texture before it becomes noise
Constraints: square artwork only; no platform mask baked in; no text; no letters; no numbers; no tiny furniture; no UI; no people; no device frame; no watermark
Avoid: weather-app sun, home-design app, generic house icon, fantasy game crest, glossy 3D emoji, excessive glow, tapestry as the main symbol
```

### Completion Latch / Orbit

```text
Use case: logo-brand
Asset type: 1024 x 1024 mobile app icon master
Primary request: Create one compact latch-or-orbit form derived from gentle completion and returning, suggesting a day being kept and the path continuing without becoming a streak badge.
Input images: current icon as identity baseline; three app screenshots as material, lighting, and product-world references; archived source as craft reference. References are moodboard inputs, not edit targets.
Style/medium: production-quality restrained three-dimensional icon artwork with simple faceted geometry and tactile aged materials
Composition/framing: one bold centered mark, clear outer silhouette and one internal relationship, readable at 32 pixels, safe inside iOS squircle and Android circular/adaptive masks
Lighting/mood: a single honey-light event caught by aged brass over deep espresso; reassuring, grounded, forward-moving
Color palette: espresso brown, charcoal book cloth, aged brass, honey light; minimal parchment highlight
Materials/textures: aged brass edge, matte cloth or wood field, no visual grit at small size
Constraints: square artwork only; no platform mask baked in; no text; no checkmark; no flame; no trophy; no number; no streak counter; no UI; no device frame; no watermark
Avoid: fitness ring, astrology orbit, cryptocurrency token, game badge, generic productivity logo, glossy metallic coin, excessive glow
```

### Daybook and Light

```text
Use case: logo-brand
Asset type: 1024 x 1024 mobile app icon master
Primary request: Create a restrained folio or held-page relationship with one warm light event, expressing days being gathered and made visible without becoming a generic calendar or notes icon.
Input images: current icon as identity baseline; three app screenshots as material, lighting, and product-world references; archived source as craft reference. References are moodboard inputs, not edit targets.
Style/medium: production-quality restrained three-dimensional icon artwork, tactile editorial object, simplified for launcher scale
Composition/framing: one centered folio/page silhouette with one light interaction, no tiny page detail, readable at 32 pixels, safe inside iOS squircle and Android circular/adaptive masks
Lighting/mood: controlled honey light across deep espresso and charcoal; reflective, warm, serious but not somber
Color palette: espresso, book-cloth charcoal, aged brass, honey light, a restrained parchment plane
Materials/textures: clothbound folio, aged brass edge, soft paper only where legible
Constraints: square artwork only; no platform mask baked in; no text; no dates; no grid; no ruled lines; no pen; no UI; no device frame; no watermark
Avoid: generic journal app, notes app, calendar glyph, open-book education logo, religious book, fantasy spellbook, excessive glow, tapestry as the main symbol
```

The three prompts above are the generation contract. Every call used the five inspected references as moodboard inputs, and shipping-asset propagation remains blocked on owner selection.

## Task 2 generated-output provenance

The three independent built-in Image Gen calls were made in the prompt order recorded above. Every call attached the same five directly inspected reference images. The first Inhabited Room result violated the explicit no-miniature-furniture constraint, so the plan's single targeted retry was used for that direction. No shipping icon was changed.

1. **Inhabited Room / World**
   - Rejected initial output: `C:\Users\mikus\.codex\generated_images\01a019fc-1b77-7f32-8a90-d1af757cf379\exec-2d159c54-bfc3-4705-ba0e-4abb8495b5d9.png` — it visibly contained miniature shelves, books, plants, lamps, seating, a desk, and other decor.
   - Accepted targeted-retry output: `C:\Users\mikus\.codex\generated_images\01a019fc-1b77-7f32-8a90-d1af757cf379\exec-be6c430a-0b81-42bf-8ed3-d76b0fb31a04.png`
   - Workspace review copy: `design/icon-exploration/2026-08-19/candidates/inhabited-room-world.png`
   - Final prompt: the exact `Inhabited Room / World` prompt above with this single suffix appended verbatim:

```text
Targeted hard-constraint correction: replace the detailed miniature interior with a single simplified room-or-threshold silhouette and one spatial light event. Absolutely no shelves, books, plants, lamp, chair, table, cup, desk, candle, rug, wall hanging, or any other miniature furnishing or decor. Keep only bold architectural planes, the threshold, and controlled light so the mark survives at 32 pixels.
```
2. **Completion Latch / Orbit**
   - Built-in output: `C:\Users\mikus\.codex\generated_images\01a019fc-1b77-7f32-8a90-d1af757cf379\exec-6b08f09b-8526-485b-8eb3-86b2daf7a0a7.png`
   - Workspace review copy: `design/icon-exploration/2026-08-19/candidates/completion-latch-orbit.png`
   - Final prompt: the exact `Completion Latch / Orbit` prompt above; no retry or prompt change.
3. **Daybook and Light**
   - Built-in output: `C:\Users\mikus\.codex\generated_images\01a019fc-1b77-7f32-8a90-d1af757cf379\exec-be6a26ca-87c8-44e3-aeff-3aa1323e4293.png`
   - Workspace review copy: `design/icon-exploration/2026-08-19/candidates/daybook-light.png`
   - Final prompt: the exact `Daybook and Light` prompt above; no retry or prompt change.

The built-in generator returned each square output as 1254 x 1254 ARGB despite the requested 1024 x 1024 asset size. The workspace copies preserve those returned pixels exactly; no unapproved resize or format edit was applied. The review-only comparison tool will accept square inputs of at least 1024 px and deterministically downsample 1024, 180, 60, and 32 px previews.

These are review masters only. Their small-size silhouette, category reading, platform-mask behavior, and themed-icon viability remain unaccepted until the deterministic comparison sheets are built and opened.

For the three accepted review candidates and the comparison sheets, the stable option mapping is: Option 1 = accepted Inhabited Room targeted retry, Option 2 = Completion Latch / Orbit, Option 3 = Daybook and Light. The rejected first render remains in the built-in output history for provenance but is not an option.

## Task 3 deterministic comparison and visual evidence

The review-only tool was run against the current baseline followed by the three accepted masters in the fixed option order. It accepts exactly four square PNGs of at least 1024 px, preserving the 1254 px candidate masters as inputs and deriving cubic-downsampled 1024, 180, 60, and 32 px previews. Before creating a directory, it resolves the nearest existing output ancestor and rejects both lexical and resolved paths inside `ios`, `android`, `windows`, `store-assets`, `web/icons`, or `assets/brand`; a symlink or junction therefore cannot redirect review output into shipping art. It does not write candidate or shipping-icon pixels.

Generated opaque RGB review sheets:

- `contact-sheet-32-60-180-1024.png` — 1756 x 4502 px; current baseline, then Options 1-3 at 1024, 180, 60, and 32 px.
- `contact-sheet-platform-masks.png` — 2292 x 1782 px; square, iOS rounded-square proxy, Android circle proxy, Android safe-area overlay, and grayscale/themed preview.

Both sheets and all three candidate masters were opened directly. No selection was made in Task 3; the current icon remains the baseline and all three options remain available for the owner checkpoint.

### Current baseline

The centered brass room and warm disc retain the strongest immediately readable silhouette at 32 px. The form remains coherent in the iOS superellipse proxy and circular proxy, and is still legible as a monochrome/themed mark. The Android panel now draws the original unshrunk artwork with the circle and safe-area guide over it, so intersections would be visible rather than pre-contained. Its remaining tradeoff is the pre-existing broad category reading: it communicates a place/room more clearly than it communicates gathered days.

### Option 1 — Inhabited Room retry

The targeted retry is materially coherent with the app and carries the clearest candidate product connection: it reads as a threshold/room with a controlled light event rather than miniature decor. Its outer room silhouette and internal light hold at 32 px, survive both masks and show no problematic intersection with the honest Android guide, and remain credible in grayscale. It is close to the current room language, so it has low recognition risk but does not create a radically new emblem; its category risk is still a possible interior/home-design reading.

### Option 2 — Completion Latch / Orbit

The ring adds a distinct internal relationship and stays visible at 60 px, with the room outline, iOS proxy, circle proxy, safe-area guide, and grayscale preview all technically intact. At 32 px, however, the orbit compresses into a small Saturn-like form around the bright disc. That makes astronomy, game-token, or decorative-orbit category confusion a substantial concern, and the added geometry is less specifically connected to Room of Days than the threshold reading. This is evidence for the owner review, not a silent rejection or selection.

### Option 3 — Daybook / Light

The folio is the clearest candidate expression of held/gathered days and has strong cloth, brass, and honey-light material coherence. It stays inside the platform masks and guide; its grayscale preview retains the page-turn silhouette. At 32 px, its diagonal cover and page relationship become a compact book/journal reading more than a distinct Room of Days mark. The central light stays visible but is partially occluded, so generic notes, reading, or education-app category confusion remains the material concern.
