# Morrowloom — Opus 5 luxury polish pass

You are taking over an existing, working Flutter app for one further visual
polish pass. This is not a redesign and not permission to replace the approved
direction. Your job is to make the current implementation feel more authored,
cohesive, tactile, and expensive while preserving all working behavior.

## Read first

Read these completely before changing anything:

1. `C:/Users/mikus/soul/MIKA.md`
2. `C:/Users/mikus/soul/TASTE.md`
3. `C:/Users/mikus/Downloads/experimentProject/app/AGENTS.md`
4. `C:/Users/mikus/Downloads/experimentProject/app/DESIGN-BIBLE.md`
5. `C:/Users/mikus/Downloads/experimentProject/app/design-qa.md`
6. `C:/Users/mikus/Downloads/experimentProject/VISUAL-AUDIT.md`
7. `C:/Users/mikus/Downloads/experimentProject/ROOM-PLATES.md`
8. `C:/Users/mikus/Downloads/experimentProject/app/design/visual-targets/2026-07-30/GENERATION-RECORD.md`

The approved visual targets are:

- `design/visual-targets/2026-07-30/quest-selected-journal.png`
- `design/visual-targets/2026-07-30/me.png`
- `design/visual-targets/2026-07-30/goals.png`
- `design/visual-targets/2026-07-30/plans.png`
- `design/visual-targets/2026-07-30/journal.png`

The latest real production captures are:

- `test/goldens/store_01_quests_1290x2796.png`
- `test/goldens/store_01a_quests_scrolled_1290x2796.png`
- `test/goldens/store_02_reward_1290x2796.png`
- `test/goldens/store_02_keep_1290x2796.png`
- `test/goldens/store_04_goals_1290x2796.png`
- `test/goldens/store_05_planner_1290x2796.png`
- `test/goldens/store_06_insights_1290x2796.png`

The normalized comparison sheet is:

- `design/comparisons/2026-07-30/system-target-vs-build.png`

Open the targets and current captures. Do not judge this pass from code or file
paths alone.

## Owner intent

The owner specifically likes the current direction and wants another senior
designer pass for polish, consistency, and places where the existing visual
language can feel more luxurious.

His operative rules are:

- “done” means it looks good, feels good, and is cohesive—not merely that it
  compiles.
- Luxury means material continuity and spatial response, not more decoration.
- Gold should glow, not flash.
- Shine moves because tilt, scroll, or touch changes the implied light. It must
  not sparkle on a loop.
- Painted scenes must remain intact. Visible cut planes, duplicate furniture,
  or moving seams are worse than less parallax.
- Fire may live and shed a few embers because fire is a real light source.
- Dark-but-warm, candlelit, textured, serious, and handcrafted. Never grey
  tech-dark, generic glassmorphism, or sparkly fairytale.
- Readability is a hard floor. No tiny low-contrast text or awkward overlap.
- Every visible element needs a reason to be there. Withhold decoration that
  does not strengthen hierarchy, material, navigation, accumulated history, or
  emotional payoff.

## Working method

1. Audit the current rendered five-screen system beside the approved targets.
2. Identify the smallest coherent set of high-impact P1/P2 fixes and
   high-confidence P3 refinements.
3. Implement them as one consistent system pass rather than unrelated local
   tweaks.
4. Regenerate real production screenshots at 430 × 932 logical pixels, DPR 3.
5. Put source and revised implementation into the same comparison images and
   inspect those combined images.
6. Iterate until no actionable P0/P1/P2 visual findings remain.
7. Run analysis, the full test suite, and a release web build.

Do not stop after writing an audit. Implement the justified fixes and verify
them. Do not change product scope, information architecture, or core behavior
unless a visible usability problem requires a narrow correction.

## Priority surfaces

### 1. Shared material consistency

Inspect the entire app—not only the five top-level resting screens—for older
surfaces that still look like flat brown blocks, generic cards, inconsistent
gold, mismatched borders, or another generation of Morrowloom. This includes
primary pushed flows and overlays such as:

- Quest manage/quick-add/focus/day controls
- Quest completion and undo
- Furnish/shop
- Goal wizard and goal detail
- Momentum kits and guided workouts
- Plan/add-event flow
- Journal hub, journal editor, Chronicle, and Patterns
- Me settings, trophies, share/visit, and room customization

Bring high-visibility states into the current optical-glass, book-cloth,
parchment, aged-brass, and honey hierarchy. Do not mechanically restyle every
minor control if it would create churn without visible gain.

### 2. Quest control and completion

The Main Quest is the quality bar.

- Preserve the open jeweler’s-orbit silhouette and dark center in the ready
  state.
- Make the small check-latch feel intentional, not like a completed token.
- Preserve the approved warm amber material initiative while checking whether
  its value range, edge heat, texture, and lower lip can feel closer to satin
  physical gold and less like an orange block.
- One broad user-driven reflection is enough.
- Completed controls must look resolved and expensive, never green plastic.
- The reward rail must remain readable long enough and must not obscure XP,
  title, or the action.

### 3. Depth and motion

Strengthen the feeling of a physical scene only where it remains seamless.

- Phone tilt/accelerometer and desktop pointer are equivalent inputs.
- Scroll and tilt should drive one coherent light field.
- Keep the room as one continuous overscanned painting.
- Allow room camera, independent light, authored foreground/desk art, embedded
  category art, and surface reflections to move at different restrained rates.
- Category illustrations should sit low enough, remain softly integrated, and
  never look like sharp pasted thumbnails.
- Maintain the fixed-scene/progressive-blur behavior as content scrolls over it.
- Fire and candlelight may animate softly; other shine must be input-driven.
- Respect both OS and in-app reduced-motion settings.
- Check for jank and avoid rebuilding quest data on every sensor frame.

### 4. Companion pages

- **Me:** verify identity, room, Glimmers/Furnish, milestones, build radar,
  share/visit, and lower sections feel like one intentional composition rather
  than stacked modules.
- **Goals:** verify each goal painting, medallion, progress rail, CTA, support
  section, and lower catalog share one material and image-quality standard.
- **Plans:** the calendar is currently the largest uninterrupted panel. Look
  for restrained ways to give it book-cloth/parchment depth, richer border
  logic, and category/history legibility without clutter. Keep the useful list
  of that day’s actual quests.
- **Journal:** preserve `ENTRIES · PATTERNS · CHRONICLE`, the personal Then &
  Now beat, and useful analytics. Check parchment texture, quote hierarchy,
  entry cards, and all deeper journal screens for continuity.

### 5. Navigation, typography, and state language

- Inspect selected dock geometry, icon optical weight, and label spacing across
  all destinations.
- Maintain the current Fraunces / JetBrains Mono / Inter role split.
- Check long goal names, quest names, player names, localized dates, text
  scaling, and small phone heights.
- One luminous primary action per screen. Secondary gold is aged and quiet.
- No awkward text overlap, hidden persistent controls, or accidental truncation.

### 6. Sound and sensory polish

- Preserve optional low hearth ambience.
- Check that navigation, completion, and reward sounds feel soft, physical, and
  theme-consistent rather than harsh or computer-generated.
- Do not add music or materially louder ambience without owner approval.

## Hard constraints

- This worktree is heavily dirty and contains user/Codex/Claude work. Preserve
  unrelated changes. Never reset, clean, discard, or rewrite history.
- Do not deploy, publish, push, or open a PR.
- Do not use destructive git commands.
- Do not replace the app architecture or protected runtime.
- Do not introduce placeholder art, emoji illustration, handcrafted SVG art,
  CSS/div art, or fake controls.
- Use existing authored assets when they fit. If a missing visible image asset
  is truly required and image generation is unavailable, leave a precise asset
  brief rather than faking it.
- Preserve all functioning interactions and persisted data.
- Use `apply_patch` or normal editor tools for deliberate edits.
- The user’s selected browser is the in-app browser. Do not switch to
  Playwright/Chrome without explicit permission. The deterministic Flutter
  production screenshot harness is already available.
- Keep `http://127.0.0.1:4173/` serving the latest verified release build when
  finished.

## Acceptance

The pass is complete only when:

- all five top-level destinations visibly belong to one art director;
- the important pushed flows no longer reveal an older flat UI generation;
- the room and embedded art respond to tilt/scroll without seams;
- shine is restrained and input-driven;
- fire reads as alive but does not become spectacle;
- active and completed Quest controls both look expensive;
- no important text overlaps, clips, or becomes too low-contrast;
- approved-source comparisons contain no actionable P0/P1/P2 findings;
- `flutter analyze`, full `flutter test`, and `flutter build web --release`
  pass;
- the local preview responds successfully.

Record the audit, changes, rejected ideas, comparison evidence, and verification
in `design/opus-5-luxury-polish-report.md`. End that report with either
`final result: passed` or `final result: blocked`.
