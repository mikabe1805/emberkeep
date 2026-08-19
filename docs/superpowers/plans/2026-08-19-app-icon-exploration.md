# Room of Days App Icon Exploration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce exactly three product-grounded app-icon candidates, compare them against the current icon at launcher sizes and platform masks, and stop for an explicit visual selection before changing shipping assets.

**Architecture:** The current 1024 px icon and fresh in-app captures act as moodboard references, not edit targets. Built-in Image Gen produces three independent 1024 px candidates in the approved directions. A review-only Dart tool uses the existing `image` package to make deterministic small-size and platform-mask sheets without touching launcher assets; the selected candidate receives a separate propagation plan after the owner chooses it.

**Tech Stack:** Product Design ideation workflow, built-in Image Gen, Dart `package:image`, local image inspection, Markdown provenance.

**Spec:** `docs/superpowers/specs/2026-08-19-release-candidate-and-icon-design.md`

## Global Constraints

- Generate exactly three independent images with separate built-in Image Gen calls; do not batch or use the CLI fallback.
- Use the current icon and actual app captures as attached image references in every call.
- Keep the app's espresso, book-cloth, aged brass, honey-light, restrained three-dimensional material language.
- No text, letters, numbers, streak counters, tiny UI, device frame, watermark, or generic rounded-square mockup.
- The tapestry is not a default identity direction.
- A candidate must work at 32, 60, and 180 pixels and inside real platform safe areas, not only at 1024 pixels.
- Do not overwrite any current iOS, Android, web, Windows, store, or marketing icon before selection.
- Number options only by the order their generated-image results appear in the task.
- After the three options and comparison sheet are visible, stop for selection before asset propagation.

---

### Task 1: Lock the visual references and current baseline

**Files:**
- Read: `web/icons/Icon-1024.png`
- Read: `test/goldens/store_01_quests_1290x2796.png`
- Read: `test/goldens/store_02_keep_1290x2796.png`
- Read: `test/goldens/store_05_planner_1290x2796.png`
- Read: `design/source-assets/runtime-originals/assets/brand/room-of-days-icon-source-v2.png`
- Create: `design/icon-exploration/2026-08-19/README.md`
- Create: `design/icon-exploration/2026-08-19/current/master-1024.png`

**Interfaces:**
- Consumes: fresh visual-audit captures and the exact current icon.
- Produces: inspected reference set, copied current baseline, and provenance record for generation.

- [ ] **Step 1: Open every named reference directly**

Use the local image viewer on all five images. Confirm the current icon is the isometric brass room/sun mark and the app captures share the same warm room, folio, brass, and controlled-light language. Stop if a file is missing or visually unrelated; do not infer from filenames.

- [ ] **Step 2: Copy the current master without changing it**

Run:

```powershell
New-Item -ItemType Directory -Force 'design/icon-exploration/2026-08-19/current' | Out-Null
Copy-Item -LiteralPath 'web/icons/Icon-1024.png' -Destination 'design/icon-exploration/2026-08-19/current/master-1024.png'
Get-FileHash -Algorithm SHA256 'web/icons/Icon-1024.png'
Get-FileHash -Algorithm SHA256 'design/icon-exploration/2026-08-19/current/master-1024.png'
```

Expected: the hashes match exactly.

- [ ] **Step 3: Create the provenance record**

Use `apply_patch` to create `design/icon-exploration/2026-08-19/README.md` with the baseline hash, the five reference paths, the three prompts from Task 2, and these fixed criteria: product connection, small-size recognition, material coherence, category confusion, iOS mask, Android circle/safe area, and themed-icon viability.

### Task 2: Generate three independent icon directions

**Files:**
- Create from built-in Image Gen output: `design/icon-exploration/2026-08-19/candidates/inhabited-room-world.png`
- Create from built-in Image Gen output: `design/icon-exploration/2026-08-19/candidates/completion-latch-orbit.png`
- Create from built-in Image Gen output: `design/icon-exploration/2026-08-19/candidates/daybook-light.png`
- Modify: `design/icon-exploration/2026-08-19/README.md`

**Interfaces:**
- Consumes: Task 1's five inspected visual references.
- Produces: three 1024 x 1024 independent RGB review masters in displayed-result order.

- [ ] **Step 1: Generate the direction named Inhabited Room / World**

Attach the five Task 1 images as reference images and make one built-in Image Gen call with:

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

Inspect the returned image. If it violates a hard constraint, make one targeted retry for that same direction before moving on. Copy the accepted preview from its generated-images path into the exact candidate path without overwriting another result.

- [ ] **Step 2: Generate the direction named Completion Latch / Orbit**

Make a separate built-in Image Gen call with the same five attachments:

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

Inspect, retry only for a hard-constraint violation, and copy the accepted result to its exact candidate path.

- [ ] **Step 3: Generate the direction named Daybook and Light**

Make a third independent built-in Image Gen call with the same attachments:

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

Inspect, retry only for a hard-constraint violation, and copy the accepted result to its exact candidate path.

- [ ] **Step 4: Record the actual generated output provenance**

Add the three built-in output locations, workspace copies, exact final prompts, and any single-change retry to the exploration README. Do not claim an attachment that was not actually passed to Image Gen.

### Task 3: Build small-size and platform-mask comparisons

**Files:**
- Create: `tool/build_icon_review.dart`
- Create: `test/icon_review_tool_test.dart`
- Create: `design/icon-exploration/2026-08-19/contact-sheet-32-60-180-1024.png`
- Create: `design/icon-exploration/2026-08-19/contact-sheet-platform-masks.png`

**Interfaces:**
- Consumes: current master followed by the three candidate masters in displayed-result order.
- Produces: two RGB PNG review sheets; does not write any shipping icon path.

- [ ] **Step 1: Write a failing deterministic review-tool test**

Create `test/icon_review_tool_test.dart` to invoke the tool in a temporary directory with four generated solid-color 1024 x 1024 fixtures, then assert both output files decode as RGB, contain the expected four labeled rows, and have non-zero dimensions. Import reusable functions from `tool/build_icon_review.dart` with a relative import so no runtime app dependency is created.

- [ ] **Step 2: Run the tool test and verify it fails**

Run:

```powershell
flutter test test/icon_review_tool_test.dart
```

Expected: FAIL because `tool/build_icon_review.dart` does not exist.

- [ ] **Step 3: Implement the review-only tool**

Use `package:image` to:

- decode exactly four 1024 x 1024 inputs;
- downsample each with Lanczos-style interpolation to 32, 60, 180, and 1024 review tiles without upscaling;
- place the current baseline first and candidates in displayed-result order;
- render square, rounded-square proxy, circular proxy, Android safe-area overlay, and grayscale/themed previews;
- write opaque RGB PNG outputs only beneath the provided `--output-dir`;
- reject a path inside `ios/`, `android/`, `web/icons/`, `windows/`, `assets/brand/`, or `store-assets/` so review cannot overwrite shipping art.

The command interface is:

```text
dart run tool/build_icon_review.dart --current design/icon-exploration/2026-08-19/current/master-1024.png --candidate design/icon-exploration/2026-08-19/candidates/inhabited-room-world.png --candidate design/icon-exploration/2026-08-19/candidates/completion-latch-orbit.png --candidate design/icon-exploration/2026-08-19/candidates/daybook-light.png --output-dir design/icon-exploration/2026-08-19
```

- [ ] **Step 4: Run the tool test and real comparison build**

Run:

```powershell
dart format tool/build_icon_review.dart test/icon_review_tool_test.dart
flutter test test/icon_review_tool_test.dart
dart run tool/build_icon_review.dart --current design/icon-exploration/2026-08-19/current/master-1024.png --candidate design/icon-exploration/2026-08-19/candidates/inhabited-room-world.png --candidate design/icon-exploration/2026-08-19/candidates/completion-latch-orbit.png --candidate design/icon-exploration/2026-08-19/candidates/daybook-light.png --output-dir design/icon-exploration/2026-08-19
```

Expected: PASS, then both comparison images are created without changes under any shipping asset path.

- [ ] **Step 5: Inspect the two sheets directly**

Reject any candidate that loses its silhouette at 32 pixels, hides its focal point under a circle, reads as another app category, depends on noisy texture, or cannot yield a credible themed mark. Record the evidence without silently choosing for the owner.

### Task 4: Present the three displayed options and stop for selection

**Files:**
- Modify: `design/icon-exploration/2026-08-19/README.md`
- Do not modify: all shipping icon assets.

**Interfaces:**
- Consumes: the three visible generated-image results and Task 3 comparison sheets.
- Produces: an explicit owner selection or refinement request for the later propagation plan.

- [ ] **Step 1: Verify all three generated images are visible exactly once**

If any generated result is missing from the task, retry only the missing direction. The authoritative numbering is the order in which the generated-image results appear, even if it differs from planned prompt order.

- [ ] **Step 2: Show the current baseline and comparison sheets without renumbering the generated results**

Render the current icon and both local comparison images in the task. Keep the generated-result order as the only option-number mapping.

- [ ] **Step 3: Ask for the required selection and stop**

Send only:

```text
Which option should I build: 1, 2, or 3? Or tell me what you'd like to refine or personalize first.
```

Do not propagate, regenerate platform assets, bump a build, or alter store art before the owner selects or explicitly keeps the current icon.

- [ ] **Step 4: Commit the exploration after the selection checkpoint**

After the owner selects or asks to retain the current icon, record that exact decision in the README and run:

```powershell
git add -- design/icon-exploration/2026-08-19 tool/build_icon_review.dart test/icon_review_tool_test.dart
git diff --cached --check
git commit -m "design: explore final Room of Days app icon"
```

The later selected-icon propagation plan must cover the true transparent Android foreground, matching monochrome derivative, iOS/Web/legacy outputs, source hash manifest, physical launcher inspection, and a new unused iOS build number. It must not edit `release-candidate.json` until real signed Android artifacts exist.
