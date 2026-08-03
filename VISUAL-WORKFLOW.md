# Room of Days — Visual Pass Workflow

Status: mandatory workflow for design, art, motion, and visual-polish work.

The purpose of this workflow is to keep future passes from rediscovering the
same lessons or declaring success from code alone. It applies to a single
control, a pushed flow, a whole screen, generated art, motion, and system-wide
polish.

## The outcome

A successful pass leaves behind:

- a clearly named visual source;
- a coherent implementation that belongs to the current system;
- fresh current-state screenshots;
- full-frame and focused source/build comparisons;
- tested interaction, reflow, and reduced-motion states;
- a concise record of what changed and what was deliberately rejected;
- directly attached images the owner can still see from a phone.

Compiling is necessary. It is not visual completion.

## 1. Load the canon

Read these before changing a visual surface:

1. `C:/Users/mikus/soul/MIKA.md`
2. `C:/Users/mikus/soul/TASTE.md`
3. `AGENTS.md`
4. `DESIGN-BIBLE.md`
5. `../ART-PIPELINE.md` for any art or image asset
6. the relevant current asset manifest under `assets/*/GENERATED-ASSETS.md`
7. the approved target and the latest real screenshot for the affected state

For historical context, use `design-qa.md` and `../VISUAL-AUDIT.md` after the
current canon. An old audit may explain why a defect existed without retaining
authority over the current solution.

Before editing, inspect the worktree and preserve unrelated work. This project
is routinely worked on by several models and the owner. Never reset or clean it
to make a pass easier.

## 2. Name the source and the state

Write down, at least in working notes:

- the product surface;
- the user’s goal in that moment;
- the exact state being judged;
- the approved visual source;
- the current production capture;
- the viewport and text scale;
- whether motion, scroll, completion, empty data, or long content matters.

Examples:

- `Quests / ready Main Quest / selected Quest target / 430 × 932 / rest +
  mid-scroll`
- `Night ledger / three priorities + eight completions / routine target /
  430 × 932 and 320 × 568`
- `Journal / Entries resting state / Journal target / default text + 1.3×`

Do not compare a generated ideal state with unrelated production data and call
the visible differences implementation defects. Normalize the state first.

## 3. Choose the correct kind of pass

### Existing approved direction

Use the current production surface plus `DESIGN-BIBLE.md` as the source of
truth. Preserve working hierarchy and behavior. Correct only the scoped defect
and any directly shared system primitive responsible for it.

### Source-fidelity correction

Open the source and implementation together. Identify the smallest physical or
system difference that explains the mismatch: camera, crop, material, value,
type, spacing, attachment, or state.

### New visual direction

Do not begin implementation from prose alone. Generate or compose three
meaningfully distinct visual targets, show them, and wait for a selection.
After selection, record the source and build from it.

### New art asset

Follow `../ART-PIPELINE.md`. Measure the destination first, generate for the
real crop and density, preserve provenance, and treat the output as a draft
until edge, material, perspective, and whole-frame QA pass.

For a genuinely additive furnishing feature, capture the empty, partial, and
completed states as separate product truths. Never infer an empty state by
labeling a completed painting `0`, and never leave concept HUD or live copy
baked into a runtime plate.

Room of Days’ current Me model is not additive furnishing. Each selectable room
identity owns one finished 3:2 painting and one lightweight chooser preview.
Do not manufacture empty or partial variants. Preview the whole room, preload
it before switching, move it as one overscanned camera, and keep experimental
object layers outside the runtime bundle. A future keepsake must be isolated
and optional; it may enrich a room but cannot be required to make it whole.

## 4. Capture a fresh baseline

The standard production screenshot story is:

```powershell
flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true --dart-define=CAPTURE_STORE=true test/screenshots_test.dart
```

The focused routine story is:

```powershell
flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/routine_ledger_visual_test.dart
```

Then build the current-state review sheet:

```powershell
python tool/visual_compare.py review
python tool/visual_compare.py review-phone
python tool/visual_compare.py rooms
python tool/visual_compare.py rooms-phone
python tool/visual_compare.py journal-performance-phone
```

Open the resulting images. A generated file is not evidence until someone has
looked at it.

The baseline must use the same values the live app supplies. A handsome test
fallback can hide a production defect, as the old hearth-color golden once did.

## 5. Audit the whole frame before the component

Judge the screenshot at three scales:

1. **Thumbnail distance** — silhouette, warmth, focal path, bright-value owner.
2. **Normal phone view** — hierarchy, readability, cadence, touch affordance.
3. **Focused crop / 100%** — edges, grain, registration, alpha, type, and
   texture continuity.

Ask:

- What is the brightest object, and should it be?
- Does every highlight point back to a light source?
- Does the screen read as one authored image?
- Does the changed element belong to the same material generation?
- Is any ornament floating without a physical or semantic attachment?
- Is the content optically centered inside the visible object?
- Does the fixed dock crop or crowd anything?
- Does the next pushed state reveal an older visual system?

Do not polish a button while its card, page, or room camera is wrong.

## 6. Map the material and semantic roles

Before implementation, classify each affected element:

| Question | Expected answer |
| --- | --- |
| What is the world? | room, desk, window, fireplace, or authored paper/leather object |
| What holds live information? | dark optical glass, book cloth, or registered parchment |
| What is structural? | aged brass, border, rule, medallion, groove |
| What is the one action? | satin honey-gold plate or physical clasp |
| What identifies domain/state? | small pigment, icon, rail, ribbon, or live type |
| What may move on its own? | a motivated living source such as fire |
| What moves only with the user? | camera, reflection, vignette, blur transition |

If an element cannot answer one of these questions, it may not belong.

## 7. Implement in the right order

Work from the largest relationship to the smallest:

1. **Composition and camera** — scene crop, occupied frame, object placement,
   dock relationship.
2. **Geometry and registration** — page bounds, inner rules, optical center,
   attachment points, responsive reflow.
3. **Material and value** — world, glass, parchment, leather, brass, action
   gold, domain pigment.
4. **Live content** — type roles, hierarchy, long names, counts, semantics,
   hit targets.
5. **Interaction** — press, selection, completion, disclosure, persistence.
6. **Motion and light** — user-driven depth, source-driven life, reduced
   motion, performance.
7. **Micro-polish** — grain scale, hairlines, edge heat, shadow weight,
   subtle sound and haptic timing.

Starting with sparkles, shadows, or animation usually hides the real problem
and creates rework.

## 8. Motion pass

For every moving layer, record:

- its physical cause;
- its owning input or event;
- its maximum travel;
- its response speed;
- its parked still;
- its reduced-motion behavior;
- whether it causes expensive rebuilds.

If registered layers depend only on persistent state such as owned furniture,
compose and cache them when that state changes. The animation loop should move
or relight one finished texture; it should not repeat image masking, blur, or
layer reconstruction on every tick.

Set a cadence budget before adding polish. Use the lowest rate that preserves
the intended illusion, and keep independent systems from all rebuilding on the
same display tick. The current reference budgets are approximately 30 fps for
phone light/camera publication, 12–20 fps for fire, and 12 fps for ambient
motes. A 120 Hz screen is not permission to decode, blur, or repaint authored
rasters 120 times per second.

For primary navigation, capture both a cold first frame and the first visit to
each destination. Illustrated tabs should decode lazily, remain alive after
their first visit, and mute all autonomous tickers while hidden.

Use the Room of Days motion classes:

- **autonomous:** fire, candle, occasional embers, quiet weather;
- **reactive:** camera, reflection, progressive blur, embedded vignette;
- **event:** press, check, receipt, milestone;
- **static:** ordinary ornament, borders, labels, and resting cards.

Tilt and scroll must feel like one light field. Continuous sparkle is not a
substitute for responsiveness.

For layered art:

- require registered independent planes with real under-painting;
- inspect extreme tilt for exposed edges and halos;
- use an intact overscanned plate when real layers do not exist;
- keep interactive content and hit targets on the same transform as the object
  they visibly inhabit.

## 9. Build same-input comparisons

For the five primary destinations:

```powershell
python tool/visual_compare.py system
python tool/visual_compare.py focus
```

For the daily bookends:

```powershell
python tool/visual_compare.py routine
python tool/visual_compare.py routine-detail
python tool/visual_compare.py routine-phone
```

For an ad-hoc source/build pair:

```powershell
python tool/visual_compare.py probe "SURFACE NAME" source.png build.png
```

The source and implementation must be in the same comparison image, at the
same viewport/state and a comparable crop. Looking at two images in separate
moments is not enough for fidelity work.

When a full-frame difference is hard to judge, add a focused crop for the
high-risk detail instead of zooming the whole sheet into unreadability.

## 10. Test the states that can disprove the design

Choose the relevant subset:

- rest before any scroll or tilt;
- mid-scroll with progressive blur;
- maximum reasonable tilt in both directions;
- completion and undo;
- active and completed controls;
- empty and single-item data;
- many items, collapsed and expanded;
- long quest, goal, player, and localized date strings;
- 430 × 932 and 320 × 568;
- at least 1.3× text;
- Reduce Motion and normal motion;
- sound off and sound on;
- transformed hit targets;
- first visit and persisted return state.
- immediate pointer-down feedback before release;
- first-frame image decode, rapid tab switching, and a long continuous scroll;
- a five-minute warm-device pass for dropped frames, heat, and audio crackle.

Test the awkward state, not only the art-directable one.

## 11. Run the quality gate

At minimum, run the focused tests for the changed surface. For a completed
visual-system pass, run:

```powershell
flutter analyze
flutter test
flutter build web --release
flutter build apk --release
```

Verification is proportional to risk, but visual work still requires direct
image inspection after the final code change. A passing test suite cannot
confirm crop, texture, hierarchy, or taste.

Do not claim there are no P0/P1/P2 findings until the final comparisons have
been opened at original resolution.

Desktop and golden checks cannot certify iPhone frame pacing, haptics, audio,
sensor cadence, thermal behavior, or TestFlight packaging. Before a mobile
candidate is called smooth, install a release/TestFlight build on a physical
iPhone, test normal and Low Power Mode, and profile the Quest scroll plus rapid
tab changes if either misses frames.

## 12. Record only what deserves to persist

### `DESIGN-BIBLE.md`

Add a rule only when it is approved, repeated, or clearly explains several
successful surfaces. Keep implementation trivia in code comments.

### `assets/*/GENERATED-ASSETS.md`

For every production raster, record:

- visual source;
- exact prompt or normalized production direction;
- generation/edit lineage;
- output dimensions;
- crop and registration assumptions;
- alpha/despill/post-processing;
- intended semantic role.

### `design-qa.md`

Record the scoped comparison, findings, fixes, rejected ideas, evidence, and
verification. State which earlier verdict the new pass supersedes.

### `C:/Users/mikus/soul/MIKA.md`

Update only for a durable cross-project truth about Mika’s taste or working
style. Preserve his quotes verbatim and update `SOURCES.md`. Project-specific
coordinates, widget names, and one-off fixes do not belong there.

## 13. Phone-first handoff

Tool-viewed images and local browser tabs may disappear when the work message
collapses. The final response must attach the current result again.

Always provide:

- one compact phone-friendly WebP contact sheet;
- the most important individual current screenshots;
- a full-resolution comparison when fidelity was part of the pass.

Use absolute paths in Markdown image syntax:

```markdown
![Current Room of Days review](C:/absolute/path/current-system-review-phone.webp)
```

Do not send only a file path or say the images were viewed during the work.
Confirm the attachment is the current capture, not an earlier iteration.

## Stop conditions

Pause and ask for direction when:

- no visual target exists for a new direction;
- two sources conflict in a way that changes the product;
- the requested fidelity requires a missing source asset that cannot be
  recreated without broad invention;
- a change would discard unrelated work or require a product-scope decision;
- the result is still visibly wrong after the safe in-scope alternatives are
  exhausted.

Do not pause merely because the pass is detailed. Continue through comparison
and correction while the intended direction is clear.

## Final visual checklist

- [ ] The room or desk still reads as one authored frame.
- [ ] One bright action owns the hierarchy.
- [ ] Materials retain their semantic jobs.
- [ ] Type belongs to the physical surface it inhabits.
- [ ] Content is optically inside the visible object.
- [ ] Ornament is attached and meaningful.
- [ ] Tilt and scroll preserve scene integrity.
- [ ] Autonomous motion belongs to a living source.
- [ ] Reduced Motion is a finished still.
- [ ] Long, narrow, dense, and completed states remain comfortable.
- [ ] Fresh source/build comparisons were opened and inspected.
- [ ] Current images are attached for phone review.
