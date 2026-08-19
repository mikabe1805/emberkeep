# Room of Days design QA

## Quest completion, reactive light, and motion-cost pass - 2026-07-31

This section supersedes the earlier Quest-state verdict for the completion
control, completion hold, sensor permission path, and repaint cadence. It does
not redesign the approved Quest composition or the already-approved daily
bookends.

### Source truth and rendered evidence

- Approved Quest source:
  `design/visual-targets/2026-07-30/quest-selected-journal.png`.
- Current Quest implementation:
  `test/goldens/store_01_quests_1290x2796.png`.
- Current real mid-scroll state:
  `test/goldens/store_01a_quests_scrolled_1290x2796.png`.
- Current in-place resolve state:
  `test/goldens/store_02a_stitch_1290x2796.png`.
- Current banked completion and receipt state:
  `test/goldens/store_02_reward_1290x2796.png`.
- Full same-input Quest comparison:
  `design/comparisons/2026-07-31/quests-target-vs-build.png`.
- Focused same-input control and HUD comparison:
  `design/comparisons/2026-07-31/quests-detail-target-vs-build.png`.
- Daily-bookend comparison retained as a regression check:
  `design/comparisons/2026-07-31/routine-ledger-target-vs-build.png` and
  `design/comparisons/2026-07-31/routine-ledger-detail-target-vs-build.png`.
- Current phone handoff sheet:
  `design/comparisons/2026-07-31/quest-and-routines-current-pass-phone.webp`.

The Quest target is 852 x 1846 pixels. The implementation is rendered from the
production Flutter widgets at a 430 x 932 logical viewport and DPR 3, producing
1290 x 2796 pixels. Both unframed surfaces share the same phone aspect and were
normalized to a common comparison height without cropping. The routine source
is a 1700 x 922 two-panel board; each 850 x 922 panel was compared with its
430 x 932 DPR-1 production render. Captured states use the deterministic Level
18 board, Reduced Motion parked stills, the same quest order, and the same
persisted top-three routine order.

### Findings and comparison history

1. P2 - all visible Quest rings subscribed to live light and scroll even though
   only the featured jeweler's orbit is allowed to react. This multiplied
   custom-paint work during every sensor and scroll update.
   - Fixed by parking compact and completed rings and wiring the shared live
     field only to the featured control.
   - Post-fix evidence: the current full and focused comparisons preserve the
     approved ring hierarchy; `quest_card_polish_test.dart` verifies that only
     the featured ring repaints when light changes.
2. P2 - the fireplace rebuilt its full blended raster at controller cadence,
   and the broad Quest blur reached a heavier-than-needed sigma during scroll.
   This was a plausible contributor to the reported lag.
   - Fixed by sampling the living-fire raster at 24 frames per second while
     keeping autonomous flame life, and by reducing the maximum progressive
     backdrop blur from 12 to 8.5.
   - Post-fix evidence: resting and mid-scroll captures keep the authored room,
     crisp foreground type, warm separation, and visible fire. The room test
     verifies four registered planes, an autonomous fire layer, and a finished
     Reduced Motion still.
3. P2 - Safari's gated motion path attached its orientation listener before
   permission, then refused to attach it after permission was granted. This
   could make real-phone shine feel disconnected from movement.
   - Fixed by listening immediately only on ungated browsers and attaching the
     listener after the permission grant on gated Safari. Camera and reflected
     light remain separately damped so the room feels deep instead of loose.
   - Post-fix evidence: the motion tests verify the updated light response and
     parked Reduced Motion behavior. Physical iPhone frame timing remains a
     real-device test gap, not a claimed measurement from static QA.
4. P2 - completion changed the featured card into a compact completed row on
   the same frame as the tap, and the finished ring read too much like a filled
   reward coin.
   - Fixed with a 760 ms in-place resolve: the bright action cools into a dark
     aged-metal `QUEST COMPLETE` plate, the orbit closes in warm brass, and the
     card then banks into the ledger. The completed ring keeps the card visible
     through its center and uses a finer check and rim.
   - Post-fix evidence: `store_02a_stitch_1290x2796.png` shows the resolved hero
     before collapse; `store_02_reward_1290x2796.png` shows the quieter banked
     state. The focused widget test verifies that the resolved card exists
     before banking.
5. P2 - the added state transition needed explicit narrow, large-text, and
   Reduced Motion protection.
   - Fixed with content-driven animated sizing, a finished non-travelling still,
     and a two-line completed title allowance.
   - Post-fix evidence: the 320 x 568 at 1.3x text test passes without overflow;
     routine ledgers also pass narrow text, crowded completion, and opposing
     tilt hit-target tests unchanged.

### Required fidelity surfaces

- Fonts and typography: passed. Fraunces remains the warm editorial voice for
  quest names and reward numerals; compact mechanic labels keep their existing
  mono role. The new resolve plate uses restrained engraved small caps and no
  long-name collision was found.
- Spacing and layout rhythm: passed. The featured card, inner brass rules,
  painted vignette, action, following rows, protected receipt rail, and fixed
  dock retain the approved order. The temporary resolve uses the same action
  geometry, so completion has continuity rather than a new floating panel.
- Colors and visual tokens: passed. Honey action gold remains the one bright
  action; resolution cools to walnut and aged brass. No saturated success green,
  autonomous sparkle, or new flat state color was introduced.
- Image quality and asset fidelity: passed. The intact room and its four
  registered authored planes remain seam-free at rest; the category vignette
  stays softly integrated and safely cropped. No CSS drawing, handmade SVG,
  placeholder, or generated substitute replaced visible source artwork.
- Copy and content: passed. `MARK COMPLETE`, `QUEST COMPLETE`, reward values,
  undo copy, category labels, and the five navigation destinations remain
  coherent and readable.
- Icons and interaction states: passed. The open ready orbit, closed completed
  orbit, completion stitch, receipt, undo state, quick-add controls, and dock
  remain distinct and tappable. The Craft mark remains the more literal crossed
  maker-tools glyph.
- Accessibility and responsiveness: passed. Practical tap targets, system and
  in-app Reduced Motion, 320 x 568, 1.3x text, long completed names, transformed
  routine hit targets, and dense completion records are covered.

### Final verification

- Full Flutter suite: 117/117 passed.
- `flutter analyze`: no issues.
- `flutter build web --release`: passed; Wasm dry run passed.
- Local release preview: HTTP 200 at `http://127.0.0.1:4173/`.
- Full-view and focused source/build comparisons were opened together and
  inspected at original resolution after the final UI change.
- No actionable P0, P1, or P2 visual mismatch remains in this scoped pass.
  Real-device iPhone FPS and sensor feel should still be confirmed in the next
  TestFlight build because static/widget evidence cannot measure them.

final result: passed

## 2026-08-03 — Pre-TestFlight family-feedback freeze

- The featured Quest action now calibrates to the phone's resting hold, filters
  ordinary hand jitter with a radial dead zone, smooths deliberate tilt, and
  moves one broad satin reflection under a fixed implied room light. It has no
  autonomous shine loop. Controlled resting, left-tilt, and right-tilt evidence
  is archived at
  `design/comparisons/2026-08-03/button-light-controlled-phone.webp`.
- Reward receipts, achievement toasts, level-ups, streak milestones, and epic
  clears now combine the in-app and operating-system Reduce Motion settings.
  Reduced mode presents the complete readable state immediately without
  particles, travel, scale slams, chest motion, or heavy haptics, while keeping
  live announcements and teardown/dismissal behavior.
- Final Flutter verification passed 221/221 tests. `flutter analyze`, the
  formatting check across 141 Dart files, `git diff --check`, and
  `flutter build web --release` all passed; the WebAssembly dry run also passed.

current result: ready for a phone build; native sensor feel remains the next
validation step

## 2026-08-03 — Room of Days public rebrand

### Decision and compatibility

- The owner approved **Room of Days** as the public working name after family
  testing found Morrowloom unmemorable.
- Public Flutter copy, onboarding, sharing, exported captions, backup messages,
  Android/iOS/Windows labels, PWA metadata, legal pages, Codemagic workflow
  copy, store copy, and current documentation now use Room of Days.
- The Dart package, bundle/application IDs, Firebase project, storage marker,
  serialized fields, preference keys, notification channel, cloud identifiers,
  and historical asset filenames remain unchanged. Existing installs and saves
  therefore require no identity or data migration.
- The former public tapestry mark remains the same progression object in the
  room under the visible name **The Woven Dawn**. Internal widget and asset
  names remain historical compatibility details.

### Public mark and store art

- The selected launcher mark is an isometric little room holding one rising
  sun and one controlled path of daybreak. It removes the old brand's loom
  dependency, belongs specifically to Room of Days, and remains readable at
  32, 48, 192, and 1024 pixels. The earlier lit-window direction remains
  archived as provenance but is not the shipped mark.
- The selected image-generation source is archived at
  `design/source-assets/runtime-originals/assets/brand/room-of-days-icon-source-v2.png`.
  Prompt and lineage are recorded in `assets/brand/README.md`.
- `../tools/gen_icon_mascot.py` deterministically exports the current web,
  Android, iOS, Windows, favicon, and Apple touch assets. Android adaptive icons
  keep a 12% inset for mask safety.
- The Google Play feature graphic now uses **Room of Days**, **Real quests. Real
  progress.**, and the related arched-window sunrise scene. It remains exactly
  1024 × 500.

### Rendered evidence

- Old/new mark and feature graphic:
  `design/comparisons/2026-08-03/room-of-days-brand-review.webp`.
- Renamed first run:
  `test/goldens/store_audit_00_welcome_1290x2796.png`.
- Renamed Chronicle attribution:
  `test/goldens/store_06b_weekly_chronicle_1290x2796.png`.
- Updated full production review:
  `design/comparisons/2026-08-03/current-system-review-phone.webp`.

### Verification

- `flutter analyze`: passed with no issues.
- Full `flutter test`: 158/158 passed.
- Store-size screenshot regeneration: 17/17 passed.

## 2026-08-19 — Day Ledger launcher identity

This supersedes only the launcher-mark bullets in the 2026-08-03 historical
record above. The owner selected **The Day Ledger**, an open physical quest
ledger with one completed honey-gold medallion and two unfinished Room of Days
completion rings. The previous room-and-sun source remains archived provenance
and is no longer the shipping launcher identity.

- Selected source, exact prompt lineage, rejected transparency attempt, and
  owner checkpoint: `design/icon-exploration/2026-08-19/README.md`.
- Production source/export instructions:
  `assets/brand/README.md`.
- Exact source and derivative hashes:
  `assets/brand/room-of-days-icon-manifest-v1.json`.
- Exact platform-output review:
  `design/icon-exploration/2026-08-19/selected/shipping-platform-review.png`.
- Android adaptive icons now use a true transparent foreground and an 8%
  inset; the old opaque-master/12% treatment is superseded.
- `flutter build web --release`: passed, including the WebAssembly dry run.
- A clean rebuild removed a stale generated-only `figma-board` directory; the
  shipping web root now contains no former public-name copy.
- Android APK compilation remains environment-blocked because this workstation
  has no Android SDK configured.

final result: passed

## 2026-08-03 — Night routine, reminders, and tomorrow handoff

### Final production review

- The evening Quest board now carries one labeled `CLOSE THE DAY` rail from
  17:00 through the 04:00 day boundary. It states how many quests remain and
  becomes the primary action once the board is clear.
- Native settings now offer an independent night-routine reminder, including a
  configurable time and permission-aware scheduling. A denied notification
  permission disables the saved toggle without repeatedly prompting.
- The close-day flow offers four optional prompts: reflection, three grateful
  things, one discovery, and a message to tomorrow. They persist as one
  structured Journal page that can also be edited or removed from Journal and
  Calendar.
- A saved tomorrow message appears in the following morning ledger. `LATER`
  preserves it, and the compact card opens the complete message without
  crowding the three daily quests.
- The 04:00 ownership boundary, stale-draft isolation, idempotent close, and
  schema-17/18 cloud merge paths were exercised explicitly. A newer legacy
  cloud save is held rather than overwritten by an upgraded local save.

### Rendered evidence

- Evening entry point: `test/goldens/store_01d_evening_close_1290x2796.png`.
- Optional reflection sheet: `test/goldens/store_11b_night_reflection_1290x2796.png`.
- Morning handoff: `test/goldens/store_12_morning_open_1290x2796.png`.
- Current phone-system review:
  `design/comparisons/2026-08-03/current-system-review-phone.webp`.
- Routine target/build and detailed comparisons:
  `design/comparisons/2026-08-03/routine-ledger-target-vs-build.png` and
  `design/comparisons/2026-08-03/routine-ledger-detail-target-vs-build.png`.

### Verification

- `flutter analyze`: passed with no issues.
- Full `flutter test`: 158/158 passed.
- Store-size and routine golden regeneration: 24/24 passed.
- Compact 320 x 568 / 1.5x text tests cover the reflection sheet and morning
  handoff; the evening rail exposes a screen-reader tap action.
- `flutter build web --release`: passed, including the WebAssembly dry run.
- `flutter build apk --release`: not run to completion because this workstation
  has no Android SDK configured (`ANDROID_HOME` is unavailable).
- `git diff --check`: passed; only line-ending conversion warnings remain.

final result: passed

## 2026-08-03 — Family-feedback completion and social-space pass

### Completed product behavior

- My Space is now a personal page as well as a progress surface. A person can
  change their name, write a short introduction, feature up to three goals,
  and pin Journal moments or photos without disturbing the room scene.
- Visitor sharing is private by default. Opting in publishes only the chosen
  display name, introduction, and featured goals; Journal entries and photos,
  quests, streaks, account data, and the rest of the local profile never enter
  the shared-room payload. Public room codes allow an exact-code read but
  cannot be listed or searched as a collection.
- `Share my space` now opens the platform share sheet, so installed targets
  such as WhatsApp are available naturally, while copy-code remains an explicit
  fallback. The dialog keeps a stable Done action.
- `Visit a space` validates the six-character code in place, shows loading and
  retry states without dismissing itself, and can save the visited room to the
  Circle. Circle's add-code path uses the same validation and fetch contract.
- Circle now has a clearer empty-room invitation, trusted-space cards, quiet
  company, and accessible actions instead of acting like a decorative stub.
- Journal supports multiple photos in one entry, keeps location context,
  autosaves edits, and surfaces every entry for the selected day in Calendar.
- Every room choice now uses the same intact-camera depth treatment as the
  default room: parallax, moving light, hearth/reflection response, and authored
  full-room previews. Reduced Motion parks the camera and ambient movement.
- The night reflection remains an immersive full-screen close to the day.
  Optional reflection, three gratitudes, one discovery, and a message to
  tomorrow share one scrollable surface. The morning routine opens
  automatically on cold start or resume once due, without stacking overlays or
  covering onboarding.
- Night reminders remain independent from quest reminders. Only a confirmed
  permission denial clears a reminder; an unknown native result preserves the
  person's setting. Suppression compares the next actual wall-clock occurrence,
  including after-midnight ownership and daylight-saving boundaries.
- My Space, Personalize, Circle, Visit, Share, and Calendar Journal states now
  reflow at 320 x 568 with 2.0x text. Primary Circle actions are at least 44
  logical pixels and expose screen-reader tap actions.
- The guided workout received a final material and hierarchy pass: clearer
  session progress and countdown, an attached form/next-move ledger, larger
  controls, responsive small-phone behavior, and Reduced Motion support.

### Rendered evidence

- My Space, Circle, and the earlier visitor-profile exploration:
  `design/comparisons/2026-08-03/my-space-circle-visitor-pass.webp`.
- Complete-room chooser and both alternative-room previews:
  `design/comparisons/2026-08-03/complete-room-system-phone.webp`.
- Current whole-product phone review:
  `design/comparisons/2026-08-03/current-system-review-phone.webp`.
- Individual production captures include
  `test/goldens/store_02_keep_1290x2796.png`,
  `test/goldens/store_02c_visitor_room_1290x2796.png`,
  `test/goldens/store_03b_conservatory_preview_1290x2796.png`, and
  `test/goldens/store_10_workout_active_1290x2796.png`.
- Eight focused layout captures under `test/goldens/large_text_*.png` document
  the 320 x 568 / 2.0x My Space, Personalize, Circle, Visit, Share, and Calendar
  states. These use the deterministic test font and are layout evidence rather
  than store art.

### Final verification

- Combined family-feedback regression set: 77/77 passed.
- Full Flutter suite: 189/189 passed.
- `flutter analyze`: passed with no issues.
- `flutter build web --release`: passed; the WebAssembly dry run also passed.
- Three fresh 430 x 932 at DPR 3 screenshot stories passed and regenerated the
  social, room, Journal, workout, and identity evidence above.
- Fresh source/build comparison sheets were generated and opened at original
  resolution after the final implementation change. No actionable P0, P1, or
  P2 layout mismatch remains in this scoped pass.

final result: passed

## 2026-08-03 — Journal Quest handoff and release-candidate hygiene

### Product contract

- Authored Journal Quests open a dedicated autosaving Journal page rather than
  completing at the first tap.
- Opening the page and leaving it empty never counts. The first meaningful
  saved writing completes the linked Quest once when the person returns to
  Quests; reopening the same Quest on the same day resumes that page instead
  of creating a duplicate entry or reward.
- Ordinary check-off Quests keep their existing completion behavior.

### Release hygiene

- The local public privacy page, store disclosure worksheet, iOS privacy
  manifest, foreground-notification delegate, and Codemagic CocoaPods fallback
  now describe and provision the behavior in the candidate consistently.
- The updated Firestore rules compiled in a dry run. They have **not** been
  deployed, and the updated public privacy page has **not** been hosted. Share,
  Visit, and Circle should not be judged against production until those two
  release operations are complete.
- Final verification is fresh for this candidate: the full Flutter suite passed
  203/203, including the dedicated Journal Quest migration, immediate-back,
  bookplate, and 2x-text checks; `flutter analyze` found no issues; and
  `flutter build web --release` completed successfully.
- A fresh 430 x 932 at DPR 3 Quest-to-Journal capture was inspected at original
  resolution. Its first pass exposed a clipped long Quest title; the header now
  stacks above save status when needed, and the recapture shows the complete
  title, prompt, attached context, and photo action without overlap.
- The generic luminous `OPEN JOURNAL` slab was replaced after phone-sheet
  review with a restrained oxblood bookplate, aged-brass inset rim, book seal,
  and page-edge cue. The final recapture keeps it unmistakably actionable while
  preserving the Quest title and reward as the leading hierarchy.

current result: local candidate passed; external release operations remain

## 2026-08-03 — Arrangeable My Space card pass

### Product contract

- My Space is now an authored four-card page: About, Right now, Pinned moments,
  and This season. Each card keeps its own material language while the room
  remains the page's visual anchor.
- A full-screen arranger lets the owner drag the brass grips to reorder cards,
  hide or reveal individual cards, and edit their contents without committing
  a partial draft. Cancel discards the draft; Save applies the complete page in
  one persistence step.
- This season adds a short seasonal note and an optional photo chosen from the
  Journal. It stays out of legacy pages until it has content, so existing saves
  retain their established three-card rhythm.
- Visitor sharing still requires the existing explicit profile opt-in. The
  chosen name is eligible when opted in; About and Right now additionally
  respect their card visibility. Pinned-moment writing, Journal identifiers and
  photos, This season content, and the private deck arrangement never enter the
  public room document. They may remain in the person's private save or its
  optional private cloud backup.

### Rendered evidence

- Composed four-card page and full-screen arranger:
  `design/comparisons/2026-08-03/my-space-cards-phone.webp`.
- Individual 430 x 932 at DPR 3 production-widget captures:
  `test/goldens/store_14_my_space_cards_1290x2796.png`,
  `test/goldens/store_14b_my_space_season_1290x2796.png`, and
  `test/goldens/store_14c_my_space_arranger_1290x2796.png`.
- The arranger and composed page were also exercised at 320 x 568 with 2.0x
  text. The compact photo fallback was inspected in place so missing Journal
  media no longer forces full explanatory copy into a thumbnail.

### Verification

- Dedicated My Space state, UI, privacy-payload, large-text, visitor-profile,
  and cloud-merge set: 34/34 passed.
- Full Flutter suite: 215/215 passed.
- `flutter analyze`: passed with no issues.
- `flutter build web --release`: passed; the WebAssembly dry run also passed.
- Fresh phone captures were opened at original resolution after the final
  contrast, privacy-copy, and compact-photo corrections. No remaining P0 or P1
  issue is known in this scoped pass.

current result: passed

## Complete-room identity pivot — 2026-07-31

This section supersedes every earlier Me/furnishing verdict. The production
model is now three complete room identities; the archived empty-room and
piece-by-piece shop are no longer product truth.

### Source truth and rendered evidence

- Source visual truth:
  `design/visual-targets/2026-07-30/me.png` (853 × 1844 pixels).
- Canonical room source:
  `design/source-assets/rooms/wall_walnut-clean-v2.png` (1536 × 1024).
- Current Me implementation:
  `test/goldens/store_audit_10_fresh_me_1290x2796.png`.
- Current room-choice implementation:
  `test/goldens/store_audit_11a_conservatory_choice_1290x2796.png`.
- Current Conservatory preview:
  `test/goldens/store_audit_11b_conservatory_preview_1290x2796.png`.
- Current Archive preview:
  `test/goldens/store_audit_11c_archive_preview_1290x2796.png`.
- Full same-input source/build comparison:
  `design/comparisons/2026-08-01/complete-room-target-vs-build.png`.
- Focused same-input hero comparison:
  `design/comparisons/2026-08-01/probe-me-hero.png`.
- Current four-state phone review:
  `design/comparisons/2026-08-01/complete-room-system-phone.webp`.

The implementation was rendered from production Flutter widgets at a 430 ×
932 logical viewport and DPR 3, producing 1290 × 2796 pixels. The unframed
source target and implementation share the same portrait aspect and were
normalized to a common comparison height without cropping. The audited state
is a fresh Level 1 room with 0 Glimmers and Reduced Motion, followed by the
chooser and both unaffordable full-room previews. The room plates themselves
use the same 1536 × 1024, 3:2 camera and are displayed without upscaling in the
phone hero.

### Findings and comparison history

1. P1 — the first implementation capture showed the procedural legacy room in
   the Me hero and full-room preview, while chooser thumbnails could resolve as
   blank panels. This directly contradicted the complete-from-the-start model.
   - Fixed by bundling the preview directory, preloading the saved room while
     the Quest home appears, awaiting a selected room before opening its
     preview, and explicitly decoding deterministic screenshot assets.
   - Post-fix evidence: every room is present in the final full-view and
     four-state phone comparisons; no loading fallback or blank image remains.
2. P2 — the shared detail header overflowed by 515 pixels at 320 × 568 with
   1.3× text because the title, subtitle, and Glimmers chip competed for one
   row.
   - Fixed in `lib/widgets/detail_header.dart`: the title keeps the full first
     row and the pill stacks below at narrow widths or larger text scales.
   - Post-fix evidence: the real preview and purchase path passes at 320 × 568,
     1.3× text with no rendering exception, and completes the Glimmer purchase.
3. P2 — `ROOM CHANGES` implied an unfinished room and the first keepsake note
   read like implementation rationale rather than finished in-product copy.
   - Fixed by naming the profile seals `MILESTONES` and tightening the chooser
     copy to “Your room is whole from the beginning. Milestones may leave a
     quiet keepsake behind.”
   - Post-fix evidence: both changes are visible in the final phone review.

P0 remaining: none.

P1 remaining: none.

P2 remaining: none.

### Required fidelity surfaces

- Fonts and typography: passed. Fraunces preserves the warm editorial display
  voice; Inter carries explanation; JetBrains Mono carries compact mechanics.
  The selected target’s hierarchy and optical weights remain recognizable,
  titles wrap cleanly, and the narrow large-text header no longer collapses.
- Spacing and layout rhythm: passed. The 3:2 room is fully visible, the Me title
  and level rail sit inside its lower value field, 16-point page gutters remain
  consistent, room cards breathe, and both preview dialogs fit the viewport.
  The target’s upper-left `ME` placement versus the build’s lower in-scene
  identity rail is an intentional live-product composition retained from the
  approved current system, not an accidental drift.
- Colors and visual tokens: passed. Walnut, parchment, warm black, aged brass,
  and honey gold remain the base system. Moss and ink-blue accents identify the
  two new rooms without turning either into a flat category-color block.
- Image quality and asset fidelity: passed. Each identity is a real authored
  1536 × 1024 plate with a matched 720 × 480 preview. Camera, window, hearth,
  horizon, crop, and material density remain coherent; there are no alpha
  halos, sliced furniture, neighboring-object leaks, pasted thumbnails, live
  HUD text, or awkwardly cropped shop objects.
- Copy and content: passed. The flow now speaks in finished product language:
  `Change your space`, `STEP INSIDE`, permanent ownership, and free switching.
  It does not describe a chore catalogue or leak the design prompt into the UI.
- Icons and controls: passed. Back, room, visibility, key, close, and check
  controls use one supported Material family, retain practical hit targets,
  and align with the faceted brass system.
- States and interactions: passed. The Me rail opens the chooser; all three
  room cards scroll; Conservatory and Archive previews open; unaffordable,
  purchase, applied, and owned-switch states work; purchase deducts 280
  Glimmers, persists ownership, applies the room, and synchronizes its Quest
  Desk finish. Legacy wall purchases migrate to the nearest complete room.
- Accessibility and resilience: passed. Semantics label the room chooser and
  close control; Reduced Motion parks the room; 320 × 568 at 1.3× text passes;
  the preview remains scroll-reachable and no persistent controls are clipped.

### Verification

- `flutter analyze`: passed with no issues.
- Full `flutter test`: 124/124 passed.
- Focused 430 × 932 screenshot story: passed and inspected.
- 320 × 568 / 1.3× text purchase journey: passed.
- `flutter build web --release`: passed.
- Local release preview: HTTP 200 at `http://127.0.0.1:4173/`; both new room
  plates and chooser previews also return HTTP 200.
- Release sizes: app assets 13,788,921 bytes; room assets 2,100,431 bytes;
  `main.dart.js` 3,681,081 bytes.
- `git diff --check`: passed; output contains only the repository’s existing
  LF-to-CRLF conversion warnings.

### Open questions / residual test gap

- Real gyroscope feel, low-end-device decode timing, and autonomous fire audio
  remain physical TestFlight checks. The room rendering now moves one intact
  overscanned plate and preloads before switching, so this is not a visual-QA
  blocker, but a device remains the performance truth.

### Follow-up polish

- P3: if keepsakes return, introduce only a few isolated, milestone-specific
  objects. Test every object against all three complete rooms; never use them
  to complete the furniture, lighting, or basic warmth of a room.

final result: passed

---

## Current visual-system reflection and workflow codification — 2026-07-30

This pass did not redesign the approved app. It reconstructed why the current
result became cohesive, compared that explanation against fresh production
renders, and turned the successful mechanisms into durable project rules.

### Current-run evidence

- Fresh production screenshot story: 15/15 captures passed.
- Fresh focused routine visual suite: 7/7 states passed.
- Five-screen source/build comparison:
  `design/comparisons/2026-07-30/system-target-vs-build.png`.
- Focused source/build comparison:
  `design/comparisons/2026-07-30/focused-target-vs-build.png`.
- Full current-product review, including primary screens, Quest states, pushed
  flows, workouts, and bookends:
  `design/comparisons/2026-07-30/current-system-review.png`.
- Compressed phone handoff:
  `design/comparisons/2026-07-30/current-system-review-phone.webp`.
- Routine full and focused comparisons:
  `design/comparisons/2026-07-30/routine-ledger-target-vs-build.png` and
  `design/comparisons/2026-07-30/routine-ledger-detail-target-vs-build.png`.

All of these were regenerated from current production widgets during this
audit and opened at original or phone-review resolution.

### What made the look cohere

1. The app stopped treating scenery as wallpaper and began composing each
   screen from an environment outward.
2. Materials received stable semantic jobs: optical glass for live
   information, parchment for reflection, leather for ritual, aged brass for
   structure, and satin honey gold for one primary action.
3. Tilt, pointer, and scroll began feeding one light field. The room answers
   slowly, reflection answers quickly, and only motivated sources such as fire
   move autonomously.
4. The Quest room gained real registered layers instead of pieces cut from a
   finished painting. Other hero scenes remained intact and overscanned.
5. Authored raster detail was separated from live information and interaction.
   The art carries fibers, tarnish, perspective, and atmosphere; Flutter
   carries names, counts, accessibility, reflow, state, and hit targets.
6. The final routine corrections used optical registration: projected content
   follows the page's four inner corners, the clasp centers on the visible
   parchment rather than transparent bounds, and ribbons physically emerge
   from the slots whose order they mark.
7. Literal target matching yielded to material and semantic fidelity when a
   poster-like copy made real content awkward. This is why removing the
   morning bookmark improved fidelity to the intended experience.

### Documentation risks corrected

- `VISUAL-AUDIT.md` correctly diagnosed the old fragmented generations but
  prescribed an absolute removal of blur, gradient, glow, and shadow. The
  current canon now distinguishes sourceless effects from source-motivated
  optical depth and material response.
- `DESIGN.md` contained useful product history beside superseded light-theme,
  companion, particle, and generic-button directions. It now points visual
  work to the current bible.
- `ART-PIPELINE.md` still read as a code-painted-only rule despite the approved
  Quest planes, page hero plates, category vignettes, and routine materials.
  It now records the actual hybrid production lanes.
- Future passes had no single sequence for baseline capture, same-input
  comparison, optical/material audit, state testing, durable record, and phone
  handoff. `VISUAL-WORKFLOW.md` now owns that sequence.
- Tool-viewed images were easy to lose after a work message collapsed.
  `visual_compare.py` now creates full and compressed current-product review
  sheets intended for direct final attachment.

### Current conclusion

The fresh review supports the owner's positive verdict. The system now reads
as one art director across the five primary destinations, the important Quest
states, and the daily bookends. The pushed flows are intentionally quieter and
more utilitarian; their remaining differences are future P3 polish
opportunities, not a return to the old conflicting material generations.

No production UI or product behavior changed in this documentation pass.

final result: passed

---

## Routine camera, clasp, and bookmark correction — final 2026-07-30 pass

This section supersedes every earlier routine-ledger verdict below for the
morning camera, morning action alignment, and priority-marker treatment.

### Source visual truth and implementation evidence

- Approved material and interaction source:
  `design/visual-targets/2026-07-30/routine-ledger-selected.png`.
- Night implementation:
  `test/goldens/routine_ledger_night_430x932.png`.
- Morning implementation:
  `test/goldens/routine_ledger_morning_430x932.png`.
- Full same-input comparison:
  `design/comparisons/2026-07-30/routine-ledger-target-vs-build.png`.
- Focused same-input marker comparison:
  `design/comparisons/2026-07-30/routine-ledger-detail-target-vs-build.png`.
- Phone-only handoff:
  `design/comparisons/2026-07-30/routine-ledger-phone-after.webp`.

The implementation captures are 430 × 932 logical and physical pixels at DPR
1. The source is a 1700 × 922 two-panel artboard; each 850 × 922 bookend was
normalized independently beside its corresponding implementation. The compared
state has three persisted priorities, four completed quests, Steady selected,
and Reduced Motion parked on the composed still.

### Findings and comparison history

1. P1 — morning still used the steeper source-asset camera, so the parchment
   rules and all live copy ran visibly downhill while night sat almost square.
   The result felt like a different, sideways ledger rather than the same desk
   at dawn.
   - Fixed by registering the complete morning plate back by 3.5 degrees while
     preserving the measured four-corner page homography inside it. A small
     optical x-registration aligns the corrected page with the night folio.
   - Post-fix evidence: the full comparison shows matching near-horizontal
     page rules, comparable ledger tops, and one shared room-camera language.
2. P1 — the morning clasp was mathematically centered on the transparent asset
   bounds rather than optically centered on the corrected parchment.
   - Fixed by aligning the clasp to the corrected lower page center. The
     authored brass raster, live hit target, responsive sheen, and parked still
     remain one object.
   - Post-fix evidence: the morning phone capture shows equal visual weight on
     both sides of `OPEN THE DAY` and a centered relationship to the page.
3. P1 — night placed each numeral on top of a small cloth rectangle, turning
   the three priority markers into badges. They no longer read as bookmarks
   tied to tomorrow’s chosen slots.
   - Fixed by restoring the approved hierarchy: large page numerals and quest
     names remain inside the leather slots, while plum, blue, and umber cloth
     emerge from each slot’s lower seam. A one-pixel silhouette shadow gives
     the cloth physical separation without adding glow or sparkle.
   - Post-fix evidence: the focused comparison shows three readable slots and
     three materially attached ribbon tails.
4. P1 — morning’s reduced plum marker still floated beside the first quest.
   Shrinking the rejected gold plaque had changed its size, not the underlying
   compositional problem.
   - Fixed by removing the duplicate physical bookmark from morning. Persisted
     rank one is now one restrained live letterpress line, `1 BEGIN HERE`,
     directly above the lead quest.
   - Post-fix evidence: the focused comparison shows an uninterrupted parchment
     margin and no ornament competing with the first quest.

### Required fidelity surfaces

- Fonts and typography: passed. EB Garamond carries the ledger, ranks, quest
  names, and engraved actions. `1 BEGIN HERE` is legible, restrained, and
  aligned with the lead quest.
- Spacing and layout rhythm: passed. Both folios occupy the same general frame;
  morning no longer leans away from night, the clasp is optically centered,
  and ribbon tails clear both quest names and the action clasp.
- Colors and visual tokens: passed. Plum, blue, and umber remain quiet saved
  order cues; parchment, espresso leather, moss, and aged brass retain the
  approved material hierarchy.
- Image quality and asset fidelity: passed. Leather, parchment, clasp, tray,
  gilding, and cloth remain authored raster assets. No flat replacement,
  handcrafted vector, generic gradient, or placeholder was introduced.
- Copy and content: passed. Night’s exact 1–3 order still determines morning
  order; only persisted rank one receives `BEGIN HERE`.
- Interaction, motion, and accessibility: passed. Priority selection,
  persistence, morning handoff, capacity selection, clasp hit testing at tilt
  extremes, 320 × 568 at 1.3× type, completion expansion, and Reduced Motion
  remain covered.

### Verification

- Focused routine suite and refreshed captures: 7/7 passed.
- Full Flutter suite: 114/114 passed.
- `flutter analyze`: no issues.
- `flutter build web --release`: passed; Wasm dry run passed.
- Refreshed local release preview: HTTP 200 at
  `http://127.0.0.1:4173/`.
- The full-view and focused source/build comparisons were opened together and
  inspected at original resolution. No actionable P0, P1, or P2 difference
  remains in this scoped correction.

final result: passed

---

## Routine bookmark continuity and shared bookend frame — final 2026-07-30 pass

This section supersedes the earlier Desk Ledger verdicts below for bookmark
treatment and morning composition.

### Source visual truth and implementation evidence

- Approved material and interaction source:
  `design/visual-targets/2026-07-30/routine-ledger-selected.png`.
- Night implementation:
  `test/goldens/routine_ledger_night_430x932.png`.
- Functional ranked planner:
  `test/goldens/routine_ledger_planner_430x932.png`.
- Morning implementation:
  `test/goldens/routine_ledger_morning_430x932.png`.
- Full source/build comparison:
  `design/comparisons/2026-07-30/routine-ledger-target-vs-build.png`.
- Focused bookmark comparison:
  `design/comparisons/2026-07-30/routine-ledger-detail-target-vs-build.png`.

The implementation captures are 430 × 932 logical and physical pixels at DPR
1. The approved source is a two-panel 1700 × 922 artboard; each 850 × 922
bookend was normalized independently beside its corresponding phone render.
The compared state has three ranked tomorrow priorities, four completed
threads, the steady capacity selection, and Reduced Motion parked on a
finished still.

### Findings and comparison history

1. P1 — the night cloth markers hung beneath the tray as three detached scraps.
   Their colors were technically correct but the rank, quest, and ribbon read
   as separate decorations.
   - Fixed by moving the saved rank directly onto its authored plum, blue, or
     umber cloth tab inside the corresponding leather slot. The marker now
     explains selection order without crossing the quest name or competing
     with the brass `MARK TOMORROW` plate.
   - Post-fix evidence: the focused comparison shows one coherent
     cloth-plus-number object in each chosen slot.
2. P1 — morning used a second tall gold plaque for `1 / BEGIN HERE`. It
   repeated the primary-action material, displaced the first quest, and looked
   unrelated to the cloth chosen the night before.
   - Fixed by carrying the exact rank-one plum cloth into the parchment margin,
     stamping `1` onto it, and setting `BEGIN HERE` as restrained live
     letterpress beside the quest. The first row now shares the same icon and
     text alignment as the other two.
   - Post-fix evidence: the focused comparison shows the first quest as the
     focal content and the marker as supporting state.
3. P1 — the raw morning asset aspect made the open folio extend materially
   lower than the night ledger, so the bookends felt like different cameras
   and made the otherwise centered clasp appear displaced.
   - Fixed by giving both standard-size folios the same occupied frame while
     preserving the measured four-corner page projection. The symmetric clasp
     raster is centered on that shared frame; narrow large-text layouts retain
     their longer accessibility folio.
   - Post-fix evidence: the full comparison and phone renders show matching
     ledger tops and bottoms, with the morning action centered beneath the
     parchment.

### Required fidelity surfaces

- Fonts and typography: passed. EB Garamond remains the physical ledger voice;
  `BEGIN HERE` uses the same letterpress small-cap system, and quest titles,
  stat metadata, section titles, and clasp engraving keep their existing
  hierarchy without collision or truncation.
- Spacing and layout rhythm: passed. The night tray keeps three equal slots;
  the morning lead row no longer reserves a large empty marker column; both
  folios occupy the same vertical composition and the centered clasp remains
  fully on the cover.
- Colors and visual tokens: passed. The saved plum, blue, and umber cloth
  distinguish ranks without adding a new mechanic color. Parchment, espresso
  leather, moss, and responsive aged brass remain unchanged.
- Image quality and asset fidelity: passed. Every visible physical element uses
  the authored leather, parchment, brass, gilding, or cloth raster. The
  rejected oversized gold bookmark is no longer rendered; no CSS/vector
  approximation replaces it.
- Copy and content: passed. `BEGIN HERE` remains unmistakable and belongs only
  to persisted rank one. The exact night 1–3 order still becomes the morning
  quest order.
- Interaction and accessibility: passed. Priority selection, persistence,
  morning handoff, capacity choice, action clasps, extreme-tilt hit testing,
  320 × 568 at 1.3× type, completion expansion, and Reduced Motion remain
  covered.

### Verification

- Focused routine suite: 7/7 passed after the final asset-preload cleanup.
- Full Flutter suite: 114/114 passed.
- `flutter analyze`: no issues.
- `flutter build web --release`: passed; Wasm dry run passed.
- Refreshed local release preview: HTTP 200 at
  `http://127.0.0.1:4173/`.
- Both the full-view and focused same-input comparisons were opened and
  inspected at original resolution. No actionable P0, P1, or P2 difference
  remains; the smaller phone composition is an intentional responsive reflow,
  not an attempt to preserve the artboard as a rigid poster.

final result: passed

---

## Measured ledger perspective and safe-bound correction — final 2026-07-30 pass

This section supersedes the two earlier Desk Ledger verdicts below. The v2
folios, clasp, tray, ribbons, and bookmark remain the right authored assets;
the remaining mismatch was geometric assembly.

### Owner direction and reviewed context

> “please catch up with the convo i had with claude and the og prompt + follow ups, it improved some of the look of it but watch out for the tilts as they’re still not accurate and the elements are still not comfortably within the inner lines of the ledger”

The complete Claude follow-up, the original
`design/OPUS-5-LUXURY-POLISH-BRIEF.md`, the selected routine artboard, and the
later owner compromise were reviewed before changing the build. The durable
direction is to preserve the target’s purposeful, authored environment and
material quality without forcing live data into a rigid poster.

Claude’s own final implementation note identified the exact residual risk: the
night and morning angles were estimated by eye, the live layer received only a
center rotation, and the folios’ keystone was intentionally left unmodeled.
That explains both visible symptoms—the night ink leaned the wrong way near the
corners, and long planner rows could approach or cross the printed rule.

### Rendered implementation evidence

- Night recap:
  `test/goldens/routine_ledger_night_430x932.png`.
- Functional ranked planner:
  `test/goldens/routine_ledger_planner_430x932.png`.
- Morning handoff:
  `test/goldens/routine_ledger_morning_430x932.png`.
- Eight-completion collapsed and expanded states:
  `test/goldens/routine_ledger_night_many_collapsed_430x932.png` and
  `test/goldens/routine_ledger_night_many_expanded_430x932.png`.
- Approved art and current night/morning builds in one comparison input:
  `design/comparisons/2026-07-30/routine-ledger-target-vs-build.png`.
- Printed rules and measured live-content insets over the production captures:
  `design/comparisons/2026-07-30/routine-ledger-safe-bounds.png`.

### Findings and fixes

1. P1 — both live pages used a single center rotation. That can align one
   horizontal line, but it cannot follow four independently photographed
   corners.
   - Fixed with a true four-point projective mapping per folio. Night now
     follows its slight downward-right rule and widening lower frame; morning
     follows the parchment’s stronger downward-right tilt and asymmetric
     convergence.
2. P1 — the old axis-aligned content rectangle began outside the inner rule in
   source coordinates, so rotation merely moved the crossings around.
   - Fixed by registering a second quadrilateral comfortably inside each
     printed frame. Titles, rules, planner rows, completion records, the
     all-day check, capacity tabs, helper copy, and footnotes all lay out at
     that safe plane’s physical dimensions before projection.
3. P1 — the night tray previously relied on a negative bottom offset and ran
   beneath the clasp. Narrowing the content without reflow would have made that
   overlap worse.
   - Fixed by making the recap adapt to the measured page width, retaining
     three visible completion rows so eight resolves to `and 5 more!`, keeping
     the all-day actions inline, and seating the entire tray inside the safe
     lower cadence.
4. P2 — the compact all-day metadata truncated to an awkward partial XP value
   after the page received its truthful width.
   - Fixed by keeping `ALL-DAY LINE` intact in the compact ledger and leaving
     XP in the wider treatment where the full phrase can remain readable.
5. P2 — perspective can make a screen look right while silently breaking hit
   testing.
   - Fixed and guarded with a stressed interaction test: both an inner-page
     action and the physical clasp remain tappable at opposing near-maximum
     parallax and light values.

### Final visual QA

No actionable P0, P1, or P2 finding remains.

- Inner-bound comfort: passed. The annotated capture shows a clear optical
  inset between live content and the printed rule on all four sides. The only
  deliberate crossings are physical objects present in the approved logic:
  rank-one’s `BEGIN HERE` bookmark and the brass action clasp.
- Tilt and keystone: passed. Repeated horizontal rules now converge with the
  photographed folio instead of drifting against it. Night no longer uses the
  incorrect counter-clockwise content lean.
- Density: passed. Default, planner, eight-completion collapsed, expanded,
  morning, 320 × 568, and 1.3× text states remain composed without hiding a
  control or stretching copy across the gilding.
- Material continuity: passed. No raster asset was replaced or distorted into
  a new visual language; the correction changes how live ink inhabits the
  authored leather and parchment.
- Motion: passed. The page, live content, clasp, and hit targets stay on one
  near plane under device/pointer parallax. Reduced Motion still parks the
  complete composition.

### Verification

- `flutter analyze`: passed with no issues.
- Focused routine visual, capacity, narrow-text, completion expansion,
  rank-continuity, persistence, and tilt-hit tests: 7/7 passed.
- Full `flutter test`: 114/114 passed.
- Fresh production goldens and both combined comparison inputs: generated and
  inspected at original resolution.
- `flutter build web --release`: passed; Wasm dry run passed.
- Refreshed local release preview: HTTP 200 at
  `http://127.0.0.1:4173/`.
- Production was intentionally not redeployed.

final result: passed

---

## Adaptive Desk Ledger and material-fidelity correction — final 2026-07-30 pass

This section supersedes the earlier Desk Ledger pass below. That pass compiled
and matched the broad composition, but the owner correctly found that it still
treated the generated art too literally in some places and too generically in
its materials.

### Owner direction

> “i will say though part of the issue with the current very rigid build is that it’s not very kind to people who completed multiple quests. it can be collapsed into “and 5 more!” but i will admit from the work i’m seeing right now things are looking a bit awkward. maybe i was too harsh with you about matching the generated images exactly. i’m willing to compromise in order to make things flow better”

> “also, the bookmarks are meant to correspond with you choosing tomorrow’s top 3, and the “1 begin here” looks really out of place in the current build”

The visual source of truth remains
`design/visual-targets/2026-07-30/routine-ledger-selected.png`, now used as a
material and interaction rulebook rather than a fixed poster.

### Rendered implementation evidence

- Night recap:
  `test/goldens/routine_ledger_night_430x932.png`.
- Eight-completion collapsed state with `and 5 more!`:
  `test/goldens/routine_ledger_night_many_collapsed_430x932.png`.
- Expanded completion record:
  `test/goldens/routine_ledger_night_many_expanded_430x932.png`.
- Functional ranked tomorrow planner:
  `test/goldens/routine_ledger_planner_430x932.png`.
- Morning handoff:
  `test/goldens/routine_ledger_morning_430x932.png`.
- Approved art and final night/morning builds in one comparison input:
  `design/comparisons/2026-07-30/routine-ledger-target-vs-build.png`.
- Authored raster record:
  `assets/routine/GENERATED-ASSETS.md`.

### Findings and fixes

1. P1 — the four-row sample in the artboard had become a rigid data limit.
   More productive days either crowded the page or were dismissed by a tiny
   generic overflow count.
   - Fixed with a truthful total, three written thread rows on the normal
     folio, two on constrained or enlarged-text layouts, and an inline
     `and N more!` disclosure. Opening it reveals a bounded, scrollable record
     of every finished thread while the all-day line, priority tray, and clasp
     retain their hierarchy.
2. P1 — the priority marks were decorative and the morning `BEGIN HERE` plate
   had no durable relationship to the user’s nightly choices.
   - Fixed by persisting rank 1–3 on each selected quest. The nightly tray
     shows a plum, blue, or umber cloth marker only for a saved selection; the
     morning page sorts by those ranks and gives the physical `BEGIN HERE`
     marker only to rank one.
3. P1 — generic gold surfaces, tall front-facing shells, and app typography
   still lost the approved source’s material specificity.
   - Fixed with authored v2 leather/parchment shells, page stacks, gilded
     rules, brass clasp, leather tray, cloth ribbons, and an aged bookmark.
     EB Garamond now carries ledger writing and engraved labels; mono type is
     reserved for mechanics.
4. P2 — the tray, all-day row, ribbon tails, and action clasp competed for the
   same lower-page space.
   - Fixed by reserving a clear lower cadence, placing ribbons visibly through
     the tray slots, and lowering the clasp enough to keep every layer
     readable without detaching the action from the physical folio.
5. P2 — stricter typography could overflow a 320 × 568 phone at 1.3× text
   scale.
   - Fixed with accessibility-aware compact rows and a longer narrow folio
     content region. No title, total, disclosure, all-day action, tray, or
     clasp is lost.

### Final visual QA

No actionable P0, P1, or P2 findings remain.

- Fidelity: passed. The combined comparison preserves the source’s leather,
  parchment fiber, page depth, worn gilding, aged brass, cloth, serif
  hierarchy, room lighting, and physical control placement while allowing
  real records to reflow.
- Flow: passed. Four and eight-completion scenarios remain composed. The full
  record expands in place, scrolls independently, and collapses again without
  pushing the honest all-day check or tomorrow planning out of reach.
- Bookmark semantics: passed. Selection order is visible, persisted, and
  inherited by morning. Rank one and `BEGIN HERE` are the same state.
- Motion and restraint: passed. The clasp reflection responds to user tilt and
  scroll; no autonomous sparkle loop was added. Reduced Motion keeps the
  composed still behavior.
- Accessibility: passed. Normal, narrow, and 1.3× text layouts have no render
  overflow, and the controls retain button/selection semantics.

### Verification

- `flutter analyze`: passed with no issues.
- Full `flutter test`: 112/112 passed.
- Focused routine visual, expansion, rank-continuity, persistence, and narrow
  tests: 6/6 passed.
- Release web build: passed; Wasm dry run passed.
- Same-input source/build comparison: passed after inspection at original
  resolution.
- Refreshed local release preview and sampled v2 assets: HTTP 200 at
  `http://127.0.0.1:4173/`.
- Production was intentionally not redeployed in this pass.

final result: passed

---

## Desk Ledger source-fidelity correction — final 2026-07-30 pass

### Owner direction

This correction responds directly to:

> “the right images don’t look quite right. remember, the devil is in the details, you want to really make it look the same”

The visual source of truth is
`design/visual-targets/2026-07-30/routine-ledger-selected.png`.

### Rendered implementation evidence

- Night phone render:
  `test/goldens/routine_ledger_night_430x932.png`.
- Functional tomorrow-planning render:
  `test/goldens/routine_ledger_planner_430x932.png`.
- Morning phone render:
  `test/goldens/routine_ledger_morning_430x932.png`.
- Approved source and both final phone renders in one inspection image:
  `design/comparisons/2026-07-30/routine-ledger-target-vs-build.png`.
- Authored routine asset record:
  `assets/routine/GENERATED-ASSETS.md`.

### Findings and fixes

1. P1 — the phone night page had the right information but still read like an
   app laid over leather: bright domain colors, compact sans-serif rows, a
   filled all-day card, and a vertically stacked tomorrow chooser.
   - Fixed by restoring one engraved brass stat instrument, Fraunces ledger
     writing, muted moss completion rings, an open ruled all-day line, the
     source’s three-column horizontal tray, written-out thread count, and the
     narrow physical `MARK TOMORROW` plate.
2. P1 — the morning rows were evenly boxed rather than composed like the source
   parchment page. The first row was too tall, the bookmark sat inside it
   instead of hanging across the rule, and the lower controls did not land at
   the source’s cadence.
   - Fixed with source-measured `5 : 4 : 4` row proportions, inset hairline
     rules, a real alpha brass bookmark crossing the first divider, larger
     serif quest hierarchy, and measured placement for `TODAY FEELS`, the
     capacity tabs, helper copy, and side-quest line.
3. P1 — the room camera buried the moon and mountain horizon behind the folio,
   making the phone render feel like a different crop from the approved scene.
   - Fixed by registering both time-of-day plates to the same 1.12× overscanned
     camera and moving that camera upward. Moon, dawn mountains, window, shelves,
     and hearth now occupy the same compositional bands while retaining enough
     overscan for tilt and scroll depth.
4. P2 — small controls still looked like filled interface chips.
   - Fixed with a muted moss `HELD` engraving, open inactive actions, a
     responsive textured gold capacity selection, and removal of the duplicate
     bottom `later` action that did not exist in the approved morning source.
5. P2 — the stricter type and spacing initially overflowed a 320 × 568 phone at
   1.3× text scale.
   - Fixed by giving narrow accessibility layouts a longer physical folio and
     real scroll extent. The 430 × 932 source-matched composition remains
     unchanged while large text keeps every control reachable.

### Final visual QA

No actionable P0, P1, or P2 findings remain.

- Typography: passed. Display serif, mechanic mono, numerals, thread spacing,
  and line height now follow the source hierarchy without overlap or
  truncation.
- Materials: passed. Parchment, espresso leather, aged brass, moss, cloth
  ribbons, and one input-responsive gold surface retain authored grain and
  depth; no routine section reads as a generic color block.
- Composition: passed. The title/date, horizon, page header, recap instrument,
  thread list, all-day line, tomorrow tray, morning rows, energy selector,
  footnote, and clasp were inspected together with the approved artboard.
- Interaction: passed. Close/open actions, all-day confirmation, tomorrow
  planning, add-for-tomorrow, priority selection, energy choice, later/not-yet,
  reduced motion, scroll blur, tilt depth, responsive sheen, and autonomous
  fire remain functional.
- Accessibility: passed. The narrow large-text test checks both bookends
  independently and reports a named failure if either overflows.

### Verification

- `flutter analyze`: passed with no issues.
- Full `flutter test`: 109/109 passed.
- Focused golden and narrow large-text routine tests: 3/3 passed.
- Same-input source/build comparison: passed after visual inspection at
  original resolution.
- `flutter build web --release`: passed; Wasm dry run passed.
- Refreshed local release preview: HTTP 200 at
  `http://127.0.0.1:4173/`.
- Production alias and sampled routine assets: HTTP 200 at
  `https://morrowloom.vercel.app` (deployment
  `dpl_8XGdRCRBxQ3f7xKL8xohJKQf6K29`).

final result: passed

---

## Authored four-plane Quest room and living fire — final 2026-07-30 pass

### Source visual truth

- Owner-approved Quest direction:
  `design/visual-targets/2026-07-30/quest-selected.png`
  (850 x 1844).
- The approved behavior is a fixed painted room beneath the Quest stack,
  subtle phone-tilt and scroll depth, autonomous fire, and progressive
  backdrop blur as quests move over the room.

### Rendered implementation evidence

- Resting production Quest surface:
  `test/goldens/store_01_quests_1290x2796.png`.
- Real mid-scroll Quest surface:
  `test/goldens/store_01a_quests_scrolled_1290x2796.png`.
- Full normalized source/build comparison:
  `design/comparisons/2026-07-30/quests-target-vs-depth-build-full.png`.
- Focused room/HUD comparison:
  `design/comparisons/2026-07-30/quests-target-vs-depth-build-top.png`.
- Registered static room composite with selected fire frame:
  `design/comparisons/2026-07-30/quest-depth-composite-v5-fire.png`.
- Generated-asset and prompt record:
  `assets/rooms/GENERATED-ASSETS.md`.

### Viewport, density, and state normalization

- Flutter implementation viewport: 430 x 932 logical pixels at DPR 3,
  producing a 1290 x 2796 raster.
- Source raster: 850 x 1844. It was scaled with Lanczos filtering to
  1290 x 2796 without cropping, then placed beside the implementation.
- Compared state: Level 18, 284/870 XP, six populated domains, Quest tab
  selected, five open quests, and the first Quest featured.
- The full screen was used for hierarchy and rhythm. A 1290 x 1450 top-region
  comparison was also inspected because the layer edges, firebox registration,
  room crop, HUD type, and stat geometry are fidelity-sensitive at full size.

### Findings

No actionable P0, P1, or P2 visual findings remain.

- P3 — the production room is slightly more panoramic than the concept and its
  books carry a faint olive cast. This is acceptable for this pass: the shorter
  reveal preserves the existing task density, all authored objects remain
  legible, and the room stays within the same dark-warm walnut/amber system.
- P3 — the living fire is a little brighter than the source still. Its glow is
  deliberately restrained in code, and the brighter painted core remains
  localized inside the firebox rather than competing with the Quest action.

### Required fidelity surfaces

- Fonts and typography: passed. The implementation retains the approved
  display-serif hierarchy, compact mechanic labels, numerals, wrapping, and
  line spacing. No new room work altered text rendering or introduced overlap.
- Spacing and layout rhythm: passed. Room, level rail, six-domain panel, day
  controls, featured Quest, supporting rows, and fixed dock retain the approved
  order and mobile cadence. The static and scrolled captures have no clipped
  controls or hidden persistent navigation.
- Colors and visual tokens: passed. Midnight blue, walnut, espresso glass,
  aged brass, honey gold, parchment, and restrained domain accents remain
  coherent. The fire is the only autonomous warm light; Quest gold does not
  sparkle on its own.
- Image quality and asset fidelity: passed. The room uses four independently
  authored registered rasters with complete artwork behind each nearer plane,
  not cuts from a finished screenshot. The fire uses three painterly raster
  frames rather than a geometric code approximation. No visible magenta/black
  key halo, duplicate edge, exposed gap, stretched source, or cut-cardboard
  seam appears in the combined comparison.
- Copy and content: passed. All app-specific labels and quest content remain
  coherent and readable; this pass adds no prompt-like or implementation copy.
- Icons and controls: passed. The open completion orbit, XP plaque, stat
  glyphs, day controls, and dock remain aligned, consistent, and functional.
- Accessibility and resilience: passed. In-app and OS reduced-motion settings
  park parallax and the fire at composed still frames. The room ignores
  pointer input, existing Quest semantics remain intact, and short-height
  surfaces continue to collapse the cinematic reveal before the core task.

### Depth, motion, and scroll QA

- The architecture, wall decor, furniture, and foreground planes move at
  strictly increasing travel distances. A focused widget test verifies that
  ordering so the effect cannot silently collapse back into one flat plate.
- The fire owns a separate nine-second loop and crossfades three registered
  painterly states with sub-two-pixel sway and sub-one-percent breathing.
  Its surrounding glow, reflection, and three occasional embers stay inside a
  repaint boundary and do not rebuild Quest data.
- Final fire crops are 320 x 300. This reduces decoded animation memory from
  roughly 19 MB to roughly 1.1 MB while preserving source-camera registration.
- The mid-scroll production capture verifies that cards climb over the fixed
  room while the room softens and warms beneath them; foreground labels and
  actions remain crisp.

### Comparison history

1. Initial source decomposition found that moving slices from the completed
   room would repeat the earlier visible window/chair seams.
   - Fix: generated a complete far architecture plus three independently
     authored alpha planes sharing one camera.
   - Post-fix evidence: `quest-depth-composite-v4.png` and the resting
     production capture show continuous architecture behind every moving edge.
2. First implementation render exposed a P2 mismatch: the autonomous flame was
   made from angular painted paths and looked like a vector effect beside the
   raster room.
   - Fix: generated three coherent painted fire states, keyed and registered
     them inside the firebox, then retained code only for low-opacity ambient
     light, floor reflection, and occasional embers.
   - Post-fix evidence: `quest-depth-composite-v5-fire.png` and the focused
     source/build comparison show a painterly flame contained by the masonry.
3. Final normalized comparison found no actionable P0/P1/P2 mismatch. The two
   remaining P3 differences are documented above and do not block handoff.

### Verification

- `flutter analyze`: passed with no issues.
- Focused Quest depth, motion, reduced-motion, and capacity tests: 8/8 passed.
- Full regression suite: 106/106 passed.
- Resting and real mid-scroll production captures: passed.
- Same-input full and focused visual comparisons: passed.
- `flutter build web --release`: passed, including the Wasm dry run.
- Production deployment and the room/fire asset requests: HTTP 200 at
  `https://morrowloom.vercel.app`.

final result: passed

---

## Reactive, restrained Quest polish — final 2026-07-30 correction

### Owner direction

This correction responds directly to:

- “subtlty is key. i didnt mean it should sparkle all the time, only that its
  shine should naturally shift as you scroll through quests.”
- “after marking a quest complete, the checked button should look better. it
  looks cheap right now.”
- “right now it's cheap. it looks like you just cut into it, and the result is
  some weird movement with the window from the chair side.”
- “make sure it isn't cut off!”
- “make that type of painted image for each category ... so it replaces the
  ugly colors for easily knowing what category the quest belongs too.”

The approved source remains
`C:/Users/mikus/.codex/generated_images/019faf64-832e-7d63-8247-d71ac627fd36/exec-7c5a7ec1-284b-4be1-9ccb-f19ba075c8f0.png`.

### Implementation evidence

- Resting production Quest surface:
  `test/goldens/store_01_quests_1290x2796.png`.
- Real scrolled Quest surface:
  `test/goldens/store_01a_quests_scrolled_1290x2796.png`.
- Completed and next-active surface:
  `test/goldens/store_02_reward_1290x2796.png`.
- Same-viewport source comparison:
  `test/goldens/qa_source_vs_implementation.png`.
- Six production 2:1 category still-lifes:
  `assets/quest/category-{body,care,mind,craft,people,home}-v1.png`
  (each 1774 x 887).

### Findings and fixes

1. P1 — the featured card, ready ring, and action were driven by a repeating
   polish controller, so they sparkled even when the player was still.
   - Fixed by deleting the ambient loop. One restrained sheen phase now comes
     only from scroll and the existing tilt/pointer light direction. The card
     edge, open ring, and action have no travelling flare or sparkle emitters.
2. P1 — the finished check read as a flat, bright green plastic badge.
   - Fixed with a smoked-moss inset, aged moss-metal double rim, static
     parchment reflection, and a parchment check over a dark engraved underlay.
     Only the one-time resolve stroke animates when completion happens.
3. P1 — the room parallax duplicated broad polygon slices from the finished
   painting, visibly carrying window pixels with the chair.
   - Fixed by removing every cut-mask depth sample. The room now remains one
     continuous overscanned painting with sub-pixel camera travel; cool window
     reflection and warm hearth light respond independently to input. Two
     generated extraction experiments were rejected because they redesigned
     the source furniture instead of preserving it exactly.
4. P1 — only MIND/reading quests received motivating authored art.
   - Fixed with a complete category set. BODY uses leather training wraps and
     a plan; CARE uses tea, herbs, and a care note; MIND uses books and an open
     page; CRAFT uses hand tools and a project sketch; PEOPLE uses cups,
     correspondence, and ink; HOME uses a key, brush, jar, and room plan.
5. P1 — the original vignette used a cover crop and negative right offset.
   - Fixed with exact 2:1 slots, `BoxFit.contain`, positive inset, generated
     12% subject-safe margins, and a soft edge fade. Parchment and meaningful
     props remain visible in resting, scrolled, and next-active captures.
6. P2 — the amber action still carried a decorative sun glyph and too many
   competing hot points.
   - Fixed by removing the glyph, lowering texture/glow strength, reducing
     border heat, replacing two glints with one broad input-driven sheen, and
     using a legible engraved parchment-gold label.
7. P2 — category artwork could have become another independent animation.
   - Fixed by tying its maximum two-pixel drift to the shared user-input field.
     Reduced motion parks artwork, light, and room at deliberate still frames.

### Final QA

- Source fidelity: passed. The 852 x 1846 source and 1290 x 2796 production
  capture were normalized to the same viewport and judged in one side-by-side
  image. Room composition, active-card hierarchy, open gold check, illustrated
  right-side vignette, amber action, compact following rows, and warm material
  family remain aligned.
- Subtlety: passed. No routine Quest polish owns a time-based loop. A parked
  screen contains material variation but no performing sparkles; scroll and
  light input are the only causes of specular travel.
- Crop safety: passed. Every category source is a true 2:1 image with explicit
  internal safe margins, and the production widget contains rather than covers.
- Completed state: passed. The completed MIND row in the reward capture keeps
  a refined dark-moss center and clear parchment check without the previous
  saturated green coin effect.
- Room continuity: passed. The chair, window, desk, fireplace, and rug are
  sampled once from the authored plate. There are no polygon seams or duplicate
  object edges at any input value.
- Scroll hierarchy: passed. Quests continue to move over the fixed backdrop as
  warm blur develops behind them; foreground content remains crisp.
- Accessibility: passed. Existing full-card semantics and completion target are
  unchanged. OS and in-app reduced-motion settings park every new response.
- Regression: passed. Quest completion, undo, rewards, navigation, plans,
  persistence, room customization, and all existing capacity journeys remain
  functional.

### Verification

- `flutter analyze`: passed with no issues.
- Full `flutter test`: 103/103 passed.
- Resting, scrolled, completed, and same-input comparison captures: passed.
- `flutter build web`: passed, including the Wasm dry run.
- Local preview and all sampled new assets: HTTP 200 at
  `http://127.0.0.1:4173/`.

No actionable P0, P1, or P2 visual findings remain.

final result: passed

---

## Luxury light, depth, and active-Quest polish — final 2026-07-30 pass

### Owner direction

This pass responds directly to:

- “nothing feels like a block of color, it looks like shining gold with depth
  and special shine sparks.”
- “as you scroll around, the shine and sparkles on the main quest undone
  checkmark shift around and continue shining.”

The approved source remains:
`C:/Users/mikus/.codex/generated_images/019faf64-832e-7d63-8247-d71ac627fd36/exec-7c5a7ec1-284b-4be1-9ccb-f19ba075c8f0.png`.

### Implementation evidence

- Resting production Quest surface:
  `test/goldens/store_01_quests_1290x2796.png`.
- Real scrolled Quest surface:
  `test/goldens/store_01a_quests_scrolled_1290x2796.png`.
- Same-state approved-source comparison:
  `test/goldens/qa_approved_vs_current.png`.
- Ambient-motion checkpoint:
  `test/goldens/quest_board.png`.
- New authored UI material:
  `assets/quest/luminous-honey-gold-v1.png` (2048 x 683).

### Findings and fixes

1. P1 — the featured completion control still read as a filled amber gradient.
   - Fixed by generating a real luminous honey-gold material plate, clipping it
     into the action, warming it toward deep amber, and layering a moving
     specular band, hot inner edge, under-lip, and two restrained travelling
     glints over the authored texture.
2. P1 — the ready ring had one static highlight and did not share the action's
   light behavior.
   - Fixed with an open dark-glass center faithful to the source, a textured
     gold annulus, moving rim arc, travelling check highlight, and paired
     cream-gold flare. Ring, action, and featured-card edge now consume one
     shared light direction and scroll phase.
3. P1 — the painted room was one flat plate even though the artwork depicted
   foreground, middle, and background depth.
   - Fixed by re-sampling the authored plate into three tiny-displacement depth
     planes: room shell, desk/fireplace, and chair/plant/rug foreground.
     Maximum travel remains only a few pixels, with overscan preventing exposed
     edges.
4. P1 — the plated fireplace only changed brightness.
   - Fixed with a moving angular floor reflection and six deterministic embers;
     the earned gilded flame adds three additional flares. The painted flame is
     preserved rather than redrawn in a conflicting style.
5. P2 — motion inputs were isolated and would have made each effect feel like
   an unrelated animation.
   - Fixed with one normalized light field. Native Android/iOS uses a calibrated,
     low-pass accelerometer input; desktop/web uses pointer position; scroll
     advances the same sheen phase. Quest data does not rebuild while the light
     moves.
6. P2 — reduced motion could have removed the material finish with the motion.
   - Fixed by parking every effect at a deliberately composed still. Texture,
     open-ring hierarchy, fire glow, and specular placement remain visible while
     parallax and continuous travel stop.
7. P2 — the first generated-material pass made the ready ring read as a solid
   coin and pushed the action too close to yellow crystal.
   - Fixed after the mandatory same-input comparison: restored the source's
     dark center and modulated the material into candlelit honey-amber while
     retaining internal variation and moving shine.

### Final QA

- Source fidelity: passed. The reference and production capture were judged in
  one combined input at the same mobile aspect ratio. The active ring,
  featured-card edge, and completion action now preserve the source's open
  silhouette, honey hierarchy, and concentrated hot glints.
- Material depth: passed. No large active-Quest surface relies on a single
  block fill; base color, authored texture, caustic variation, inset edge,
  moving specular, and lower depth lip remain individually legible.
- Motion states: passed. Ambient and reduced-motion captures render finished
  compositions; the ambient checkpoint moves the ring/check flares and button
  sweep away from the reduced-motion checkpoint.
- Scroll state: passed. The fixed room remains beneath the existing 0 → 12
  sigma warm blur while the foreground Quest stack stays crisp. Scroll also
  changes active-gold phase when motion is enabled.
- Input fallback: passed. Missing native sensor hosts fail closed to
  pointer/scroll without an exception; native sampling is enhancement-only.
- Accessibility: passed. OS animation preference and the in-app reduced-motion
  setting both park continuous motion. Existing Quest semantics and functional
  full-card completion target remain unchanged.
- Regression: passed. Quest completion, undo, navigation, planning, rewards,
  persistence, and all existing capacity journeys remain functional.

### Verification

- `flutter analyze`: passed with no issues.
- Full `flutter test`: 103/103 passed.
- Resting + scrolled production screenshot regeneration: passed.
- Normal-motion and reduced-motion render checkpoints: passed.
- `flutter build web`: passed, including the Wasm dry run.
- Local release preview: HTTP 200 at `http://127.0.0.1:4173/`.

No actionable P0, P1, or P2 visual findings remain.

final result: passed

---

## Source-fidelity Quest board rebuild — final 2026-07-29 pass

### Why this pass exists

The previous implementation reproduced the concept's nouns but not its visual
system. It had the room, XP, cards, and navigation, yet the hierarchy, material
finish, spacing, illustration density, and completion moment belonged to
different generations of the product. The owner rejected that pass as
half-finished and asked for the implementation to preserve the generated
concept's small details and consistency.

### Source visual truth

- Owner-approved combined direction:
  `C:/Users/mikus/.codex/generated_images/019faf64-832e-7d63-8247-d71ac627fd36/exec-7c5a7ec1-284b-4be1-9ccb-f19ba075c8f0.png`
  (852 x 1846).
- The source combines the option-1 glossy `MARK COMPLETE` treatment with the
  option-2 candlelit room.
- Original owner behavior requirement: quests must scroll over the room while
  the room progressively blurs, so the transition feels expensive and polished.
- Claude audit and implementation notes reviewed before rebuilding:
  `../VISUAL-AUDIT.md` and `../ROOM-PLATES.md`.

### Implementation and comparison evidence

- Resting production screen:
  `test/goldens/store_01_quests_1290x2796.png`.
- Scrolled production screen:
  `test/goldens/store_01a_quests_scrolled_1290x2796.png`.
- Initial rejected implementation beside the source:
  `output/design-qa/quest-approved-vs-current-2026-07-29.png`.
- First cohesive-material pass:
  `output/design-qa/quest-approved-vs-pass1.png`.
- Final same-input comparison:
  `output/design-qa/quest-approved-vs-final.png`.
- Clean authored Quest-card still life:
  `assets/quest/reading-candle-books-v2.png`.
- Painted room plate used by the approved Walnut room state:
  `assets/rooms/wall_walnut.png`.

### Viewport and normalization

- Flutter surface: 430 x 932 logical pixels at DPR 3, producing a
  1290 x 2796 screenshot.
- The 852 x 1846 source has the same 0.462 mobile aspect ratio. Source and
  implementation were independently scaled to the same 1000 px comparison
  height without cropping, then placed side by side.
- Compared state: Level 18, 284/870 XP, six populated stats, five quests, first
  quest featured, Walnut room, Quest tab selected.

### Findings and fixes

1. P1 — the rejected screen had competing `NEXT`, desk-style, install, bonus,
   and low-flame panels between the room and the primary quest.
   - Fixed by preserving those real features below the quest list while making
     the first frame room → progression → stats → day → featured quest.
2. P1 — the completion action was a pale generic control rather than the
   source's physical, luminous centerpiece.
   - Fixed with a 48 pt faceted amber control, hot outer edge, inset second
     frame, top specular line, warm under-lip, controlled bloom, and a centered
     sun/check motif. The full Quest card remains the functional tap target.
3. P1 — cards, HUD, and navigation used unrelated glass recipes.
   - Fixed with one espresso faceted-surface system: restrained warm edge,
     top catch-light, deep lower falloff, serif display copy, mono mechanic
     labels, and honey reserved for XP and the primary action.
4. P1 — the room and Quest card lacked the source's authored illustration
   density.
   - Fixed by using the painted room plate and a purpose-made candle/books
     still life that fades directly into the featured card instead of reading
     as a rectangular thumbnail.
5. P2 — level and stat geometry was vertically inverted: the level strip was
   too tall and the six-stat panel too cramped.
   - Fixed with a protruding 54 pt Quest Desk medallion, compact XP strip,
     larger domain glyphs, longer separators, and a taller six-stat field.
6. P2 — featured-card height, art scale, title scale, and action placement did
   not match the source when normalized.
   - Fixed through three measured comparison passes. The final hero card,
     supporting-card rhythm, and dock intersection now land at the same major
     vertical anchors as the source.
7. P2 — the floating navigation pane introduced an extra diagonal facet and
   looked like another UI generation.
   - Fixed with one anchored 88 pt espresso rail and a contained selected tab.
     The product's real information architecture remains intact.
8. P2 — taller source-faithful content exposed old tests that tapped controls
   beneath the fixed dock.
   - Fixed by scrolling real interaction targets into view. Gentle Mode,
     full-board return, Quest Desk selection, planning, completion, and the
     five navigation destinations remain functional.

### Final full-view QA

- Composition: passed. Major normalized anchors align, including room crop,
  level/stat stack, `TODAY`, hero-card top/bottom, supporting cards, and dock.
- Typography: passed. Fraunces carries story/display text; JetBrains Mono
  carries mechanic labels and numerals. Sizes, wraps, truncation, and hierarchy
  are internally consistent.
- Materials: passed. Room, HUD, cards, XP chips, actions, and navigation now
  share one dark-warm faceted language. No generic white card, flat grey panel,
  emoji, placeholder box, or approximate inline illustration is visible.
- Primary action: passed. The glossy completion control is the single brightest
  product surface and remains mechanically connected to Quest completion.
- Illustration: passed. Both room and card art are sharp at production size,
  correctly cropped, warm-lit from the same palette, and integrated rather than
  pasted on.
- Scroll depth: passed. The fixed room sits below a dedicated 0 → 12 sigma
  backdrop-filter layer over the first 220 px of scroll. Foreground cards never
  enter the filter, so they remain crisp as the room becomes soft and warm.
- Navigation: passed. Five destinations remain reachable with practical hit
  targets, persistent labels, clear selection, and no content overflow.
- Responsive/accessibility: passed. Short surfaces collapse the cinematic room
  before sacrificing the board. Reduced motion is respected and Quest/card
  semantics remain intact.

### Comparison history

1. Rejected baseline: mixed generations, excessive first-frame product chrome,
   generic card materials, and a weak primary action.
2. Pass 1: coherent room/HUD/cards and authored still life; remaining issues
   were an oversized art crop, pale CTA, cramped stats, and floating dock.
3. Pass 2: corrected art/CTA/supporting cards and dock; normalized comparison
   exposed a hero card approximately 30 logical px too short.
4. Pass 3: restored the hero-card breathing room and corrected the
   level/stat height trade. Final focused pass aligned ring/title/XP placement
   and domain-glyph scale.

No actionable P0, P1, or P2 visual findings remain. Intentional product deltas
from the nonfunctional concept are limited to Morrowloom's real tab names,
working focus/add/day controls, and live quest metadata.

### Verification

- Production screenshot harness: 14/14 passed, including resting and scrolled
  Quest states.
- Focused capacity/scroll journeys: 5/5 passed.
- `flutter analyze`: passed with no issues.
- Full regression suite: 103/103 passed.
- `flutter build web --release --no-wasm-dry-run`: passed.

final result: passed

---

## Superseded room-backed Quest board — earlier 2026-07-29 pass

This section records the rejected implementation for history. Its verdict is
superseded by the source-fidelity rebuild above.

### Source visual truth

- Owner-selected combined direction:
  `C:/Users/mikus/.codex/generated_images/019faf64-832e-7d63-8247-d71ac627fd36/exec-7c5a7ec1-284b-4be1-9ccb-f19ba075c8f0.png`
  (852 x 1846).
- The selected direction combines the option-1 glossy completion system with
  the option-2 environmental room art. The owner's added behavior requirement
  is that quests scroll over the fixed room while that room progressively
  blurs, creating depth without softening foreground content.

### Implementation evidence

- Resting production Quest surface:
  `test/goldens/store_01_quests_1290x2796.png`.
- Scrolled production Quest surface:
  `test/goldens/store_01a_quests_scrolled_1290x2796.png`.
- Same-input source/implementation comparison:
  `output/design-qa/quest-room-board-comparison.png`.

### Viewport and normalization

- Flutter surface: 430 x 932 logical pixels at DPR 3, producing 1290 x 2796
  screenshots.
- The source and implementation share the same 0.462 mobile aspect ratio. For
  the comparison input, each was normalized to 430 x 932 without cropping and
  placed side by side.
- Production state: Level 18, 284/870 XP, six populated stats, furnished Plum
  room, five open quests, one completed quest, one live bonus panel.

### Full-view comparison

- Hierarchy: passed. The first frame is room -> XP/stats -> day context -> one
  featured quest. The implementation keeps its real bonus panel and Quest Desk
  finish control, adding live-product density without displacing the room or
  primary action.
- Completion control: passed. The leading actionable quest owns the only large
  honey control. Its cream top reflection, amber body, deep under-edge, faceted
  cut, circular check, and warm glow preserve the selected option's glossy,
  physical character. The full card remains the completion tap target.
- Environment: passed. The generated library/study is translated into the
  player's real procedural room: moon window, lamp, chair, shelves, furnished
  hearth, floor light, and a small central tapestry. The tapestry no longer
  reads as a doorway or repeats inside routine HUD chrome.
- Scroll depth: passed. The room remains fixed while one NestedScrollView
  carries HUD, day panels, and quests over it. A 0->12 sigma warm backdrop blur
  lives between room and content and ramps through the first 220 px. The
  scrolled capture keeps labels, icons, and buttons crisp while the environment
  becomes a warm, legible field behind them.

### Focused fidelity surfaces

- Fonts and typography: passed. Final captures explicitly warm the bundled
  Fraunces, Inter, JetBrains Mono, and Material Icon assets before the first
  screenshot; families, weights, numeral hierarchy, wrapping, and truncation
  match the shipping design system.
- Spacing and layout: passed. The room occupies ~30% of a normal phone first
  frame, the glass HUD overlaps its lower edge, the featured action remains
  above the fixed dock, and later cards keep a consistent 10 px rhythm.
- Colors and surfaces: passed. Honey is actionable, moss is resolved, the six
  domains retain their mechanic colors, and the new shine uses existing warm
  tokens rather than a disconnected gold treatment.
- Image quality and asset fidelity: passed. The approved tapestry raster is
  used only as literal room art at roughly 15% room width. No placeholder art,
  generated replacement asset, stretched thumbnail, handmade SVG, or emoji
  substitute was introduced.
- Icons and controls: passed. Material icons retain one weight family, board
  actions keep practical tap targets, and Quest Desk customization remains
  reachable with its material swatch and name.
- Responsiveness and accessibility: passed. Short landscape/split-screen
  surfaces collapse the cinematic room reveal before sacrificing quest access.
  Reduced motion parks room ambience, semantics remain on the card/button, and
  foreground content is never inside the blur layer.

### Comparison history

1. Initial pass: the existing tapestry occupied the full center third and read
   as a curtained doorway; the featured action was not guaranteed to land on
   the first visible quest.
   - Fix: reduced the tapestry bay to a small wall relic and keyed the glossy
     action to the first visible actionable quest.
2. Scroll pass: the first blur treatment reached sigma 15 with a 0.72 dark
   bottom veil, erasing the room instead of creating depth.
   - Fix: reduced the peak blur to 12, lowered the warm veil to 0.32, and delayed
     the backdrop fade so environmental color and geometry remain perceptible.
3. Resilience pass: the cinematic reveal pushed legacy 800 x 600 interaction
   tests beneath the dock.
   - Fix: compact-height layouts collapse the room reveal, and interaction
     tests now reveal real scroll targets before tapping instead of depending
     on obsolete fixed positions.
4. Capture pass: the first deterministic screenshot could record fallback
   glyph blocks before bundled fonts finished resolving.
   - Fix: the visual harness preloads the bundled families and gives their
     asynchronous registration one real-time warm-up before capture.

No actionable P0, P1, or P2 findings remain. The implementation deliberately
keeps the real procedural room and live bonus/desk controls rather than copying
the concept's nonfunctional bookshelf vignette or reducing product behavior.

### Verification

- `flutter analyze`: passed with no issues.
- Full `flutter test`: 103 tests passed.
- Focused scroll regression verifies the fixed room, blur layer, featured
  action, and sustained scroll offset.
- Production store render harness: passed for resting and scrolled Quest states.
- `flutter build web --release --no-wasm-dry-run`: passed.

final result: passed

---

## Game-first correction — 2026-07-29

### Source visual truth

- Baseline onboarding:
  `C:/Users/mikus/Downloads/experimentProject/output/playwright/morrowloom-metaphor-audit/01-onboarding.png`.
- Baseline resting Quest page:
  `C:/Users/mikus/Downloads/experimentProject/output/playwright/morrowloom-metaphor-audit/02-quest-screen.png`.
- Baseline 220 ms completion state:
  `C:/Users/mikus/Downloads/experimentProject/output/playwright/morrowloom-metaphor-audit/03-quest-completion.png`.
- The baseline is intentionally preserved for its dark-warm faceted art,
  typography, quest cards, dock, room, and completion check. The approved
  product correction is limited to removing metaphor saturation, restoring
  the live six-stat character sheet, and making XP the everyday destination.

### Implementation evidence

- Final onboarding:
  `C:/Users/mikus/Downloads/experimentProject/output/playwright/morrowloom-game-first-qa/final-01-onboarding.png`.
- Final resting Quest page:
  `C:/Users/mikus/Downloads/experimentProject/output/playwright/morrowloom-game-first-qa/final-02-quest-screen.png`.
- Final completion at 220 ms:
  `C:/Users/mikus/Downloads/experimentProject/output/playwright/morrowloom-game-first-qa/final-03-completion-220ms.png`.
- Final reward/build reaction at 620 ms:
  `C:/Users/mikus/Downloads/experimentProject/output/playwright/morrowloom-game-first-qa/final-04-completion-620ms.png`.
- Combined same-state comparisons (baseline left, implementation right):
  `compare-01-onboarding.png`, `compare-02-quest-screen.png`, and
  `compare-03-completion.png` in the same QA folder.

### Viewport and normalization

- Source and implementation PNGs are 430 x 932 pixels.
- Browser viewport is 430 x 932 CSS pixels; screenshots use Playwright
  `scale: css` at the default DPR 1, so no density conversion was required.
- State is a fresh Full Days onboarding, Level 1, default Walnut Desk, with the
  first Quest completion captured at the same 220 ms checkpoint.

### Full-view comparison

- Onboarding retains the exact room composition, brand name, tagline, CTA,
  palette, and vertical rhythm. Only the over-explained permanent-tapestry
  sentence changed to the direct quests/XP/build promise.
- The Quest page preserves the source frame, dock, card geometry, stat colors,
  XP material, and type system. Removing the 104 px tapestry thesis and adding
  the six live stat chips makes four complete quests visible at this viewport
  while keeping the header recognizably Morrowloom.
- Completion preserves the drawn check, ripple, +XP label, reward receipt,
  sound/haptic timing, and card state. The reward trace now terminates at the
  XP numeral; at commit, the matching BODY chip counts and blooms.

### Focused-region comparison

- Header: `compare-02-quest-screen.png` is readable at native size and shows
  the exact changed region, so no further crop was required. The implementation
  replaces redundant tapestry percentage/labeling with six mechanically useful
  stat values and retains a single textured XP rail.
- Completion: `compare-03-completion.png` shows the identical first-card state
  at 220 ms. `final-04-completion-620ms.png` separately verifies the destination,
  number roll, BODY pulse, and layered receipt after the state commits.

### Required fidelity surfaces

- Fonts and typography: passed. Fraunces numerals/display, Inter body, and
  JetBrains Mono labels retain the same sizes, weights, letter spacing, wraps,
  and truncation behavior as the baseline.
- Spacing and layout rhythm: passed. The header is materially shorter without
  collapsing touch targets; four quest cards are readable above/through the
  fixed dock and no viewport overflow hides navigation.
- Colors and visual tokens: passed. Honey remains XP, the six domain colors
  remain stable, success stays moss, and the walnut/plum glass treatment is
  unchanged. The active stat uses its own color rather than a generic glow.
- Image quality and asset fidelity: passed. The approved tapestry remains sharp
  in the onboarding room, Home, milestones, and app icon. No replacement art,
  placeholder, opacity-washed icon, handcrafted SVG, or approximate asset was
  introduced. The small XP rail reuses the woven material only as texture.
- Copy and content: passed. The first-session promise now names quests, XP, and
  the build. The tutorial says “Tap … and see what changes.” User-facing desk
  finishes and milestones no longer repeat loom/weave synonyms. Morrowloom,
  Glimmers, Gentle Mode, and compatibility identifiers remain unchanged.

### Interaction and runtime checks

- Primary path tested in a release browser: onboarding → Full Days starter board
  → first quest completion → XP numeral/bar and BODY stat reaction.
- Browser console: 0 errors and 0 warnings in the final release session.
- `flutter analyze`: passed with no issues.
- Full `flutter test`: 102 tests passed.
- `flutter build web --release`: passed; Wasm dry run also succeeded.
- Golden/store render dump: regenerated with `CAPTURE_GOLDENS` and
  `CAPTURE_STORE`; the five public store screenshots were refreshed and opened
  for inspection, including the new Quest and reward states.

### Comparison history

- Initial P2: targeting the early XP-bar fill put the first reward trace almost
  directly above the check, so it still read like a decorative thread.
- Fix: target the visible XP numeral instead and replace the destination X with
  a small faceted diamond arrival.
- Post-fix evidence: `compare-03-completion.png` shows a legible diagonal reward
  path; `final-04-completion-620ms.png` shows the number and stat reaction.
- No actionable P0, P1, or P2 findings remain. Residual P3: the transient web
  install hint still adds first-session density, and the low-contrast NEXT line
  could be revisited separately without blocking this correction.

final result: passed

---

## Historical tapestry-first rebrand QA

## Comparison target

- Selected Quest-page direction:
  `C:/Users/mikus/.codex/generated_images/019faac9-3a16-7d81-ab96-ad6fcab01bc7/exec-b7c76b82-7fb7-4d6d-b678-ff8e9e8a04b4.png`.
- Owner-approved canonical tapestry:
  `assets/brand/morrowloom-icon-source.png`.
- Production horizontal Quest-HUD derivative:
  `assets/brand/morrow-tapestry-wide.png` (2172 x 724, exact 3:1).
- Resting Quest page:
  `test/goldens/store_01_quests_1290x2796.png`.
- Completion stitch checkpoint:
  `test/goldens/store_02a_stitch_1290x2796.png`.
- Settled reward checkpoint:
  `test/goldens/store_02_reward_1290x2796.png`.
- Real release-browser checkpoints:
  `output/playwright/quest-completion-v2-100ms.png`,
  `output/playwright/quest-completion-v2-240ms.png`, and
  `output/playwright/quest-completion-v2-620ms.png`.

## Viewport and normalization

- Flutter golden surface: 430 x 932 logical pixels at DPR 3, producing
  1290 x 2796 captures.
- Browser verification: release web build at 430 x 932 CSS pixels.
- The selected concept and final production captures were opened together in
  one comparison input. The production screen deliberately keeps the existing
  fixed HUD and swipeable Quest-list architecture rather than copying the
  concept's oversized title or reducing real quest density.

## Required fidelity surfaces

- Artwork: passed. The Quest HUD uses a dedicated horizontal tapestry asset,
  not a thumbnail, translucent app icon, stretched square, arbitrary crop, or
  approximate code drawing. Rod, dawn, mountains, plum wool, and faceted brass
  read as one authored artifact at the real slot size.
- Permanent progression: passed. The complete future pattern remains visible
  but muted. Earned cloth reveals upward with level and never unweaves. A quest
  may relight the frontier, while only a level changes permanent reveal.
- Completion hierarchy: passed. The authored order is pointer-down
  acknowledgement, drawn check, XP label, one stat-colored-to-gold stitch,
  tapestry landing, atomic XP commit, then exceptional reward bubbles. Routine
  clears no longer stack generic particles over the stitch; flecks remain for
  combos, dread, crits, and loot.
- Resting card: passed. Completed cards retain the equipped Quest Desk
  material, use a warm seam rather than a flat moss wash, keep readable text
  without strike-through, and delay the encore affordance until the resolution
  beat has settled.
- Scroll behavior: passed. At 430 x 932 the fixed HUD remains coherent while
  the Quest list scrolls beneath it; three actionable cards remain readable in
  the starter state and the dock stays usable.
- Customization: passed. Quest Desk appearance changes the surrounding frame,
  textile rail, card finish, and material swatch without recoloring the brand
  artwork or mechanic colors. The style control retains a 44 px target.
- Typography and icons: passed. Existing Fraunces, Inter, JetBrains Mono, and
  Material icon roles remain intact. Unsupported circled-info/arrow glyphs in
  reward bubbles were replaced with readable product copy.
- Brand rules: passed. Morrowloom is public; XP remains XP; spendable currency
  is Glimmers; Gentle Mode remains non-punitive. Fire is absent from the brand,
  XP, completion, and progression surfaces and stays ambient in the room.
- Accessibility: passed. The tapestry exposes a concise permanent-woven
  semantics label. Reduced motion uses a simultaneous static stitch with one
  short fade instead of a travelling curve. System animation preference is
  honored by the panel and completion overlay.
- Console and layout: passed. Release-browser verification found no console
  errors or warnings. Golden and widget tests found no overflow after the final
  header/style adjustments.

## Findings and fixes

1. P0: the Quest page used a tiny/faded brand substitute and the square source
   could not compose cleanly inside a wide HUD slot.
   - Fixed with `morrow-tapestry-wide.png`, generated from the approved source
     and selected option-1 composition, then reviewed at its production size.
2. P0: the new stitch initially competed with a routine particle burst and the
   old reward stack.
   - Fixed by making check + XP + stitch the routine hero and reserving
     particles for exceptional events.
3. P1: the completed card immediately became moss-green, struck out its title,
   and swapped the XP chip for `MORE` during the tap beat.
   - Fixed by preserving the desk finish, using a warm seam, keeping readable
     text, and delaying the encore control.
4. P1: the low-level stitch destination landed inside the tapestry metadata
   band and the XP bar could restart from zero on each completion.
   - Fixed by targeting the cloth frontier above the 30 px seam and keeping the
     XP-bar animation keyed to level rather than completion generation.
5. P1: the first-session panel repeated the original tiny tapestry problem and
   speculative code-painted knots/snail did not meet the authored-art bar.
   - Fixed by using a standard touch affordance and removing unapproved micro
     art instead of shipping a low-quality gag.
6. P2: the Quest Desk control was undersized, read like a generic diamond, and
   truncated the material name.
   - Fixed with a 44 px material-swatch control and a wider name slot.
7. P2: reward copy emitted unsupported visible glyph boxes.
   - Fixed with `· WHY` and `· LEVEL` copy supported by the production fonts.

P0 remaining: none.

P1 remaining: none.

P2 remaining: none.

## Verification

- `dart format` on all touched Dart and test files.
- `flutter analyze`: no issues.
- `flutter test`: 102 tests passed.
- `flutter build web --release --no-wasm-dry-run`: passed.
- Full production screenshot regeneration with the store capture harness:
  passed, including the new stitch checkpoint.
- Release-browser QA at 430 x 932: onboarding, fixed HUD, list scroll, quest
  completion checkpoints, XP commit, resting card, and console inspected.
- Selected reference, resting screen, stitch checkpoint, and reward checkpoint
  inspected together in one final comparison input.
- Updated store screenshots copied to `store-assets/screenshots/`.
- No external deployment or publication performed.

historical result: passed

---

## Five-room luxury system and shared depth — final 2026-07-30 pass

### Source visual truth

- Quest direction:
  `design/visual-targets/2026-07-30/quest-selected-journal.png`
  (852 × 1846).
- Me direction: `design/visual-targets/2026-07-30/me.png`
  (853 × 1844).
- Goals direction: `design/visual-targets/2026-07-30/goals.png`
  (852 × 1846).
- Plans direction: `design/visual-targets/2026-07-30/plans.png`
  (853 × 1844).
- Journal direction: `design/visual-targets/2026-07-30/journal.png`
  (853 × 1844).
- Canonical implementation rules: `DESIGN-BIBLE.md`.

### Rendered implementation evidence

- Quest: `test/goldens/store_01_quests_1290x2796.png`.
- Quest, real mid-scroll:
  `test/goldens/store_01a_quests_scrolled_1290x2796.png`.
- Completed Quest and readable reward rail:
  `test/goldens/store_02_reward_1290x2796.png`.
- Me: `test/goldens/store_02_keep_1290x2796.png`.
- Goals: `test/goldens/store_04_goals_1290x2796.png`.
- Plans: `test/goldens/store_05_planner_1290x2796.png`.
- Journal: `test/goldens/store_06_insights_1290x2796.png`.
- Full five-screen source/build comparison:
  `design/comparisons/2026-07-30/system-target-vs-build.png`.
- Focused Quest-control comparison:
  `design/comparisons/2026-07-30/quest-control-focused.png`.

### Viewport, density, and state normalization

- Production Flutter viewport: 430 × 932 logical pixels at DPR 3, yielding
  1290 × 2796 implementation rasters.
- Each production raster and approved target was normalized to an unframed
  852 × 1846 content surface for comparison. The 853 × 1844 companion targets
  required only a one-pixel horizontal and two-pixel vertical fit; no browser
  chrome or phone frame was included.
- Shared state: Level 18, 284/870 XP before the captured completion, six
  populated domains, furnished Walnut room, five open quests, two active goals,
  July 2026 plan history, and two journal entries.
- The implementation captures are deterministic renders of the real production
  widgets, fonts, assets, navigation, and saved-state model—not static mock
  recreations.

### Findings

No actionable P0, P1, or P2 findings remain.

- The build deliberately uses the warmer amber material the owner approved for
  `MARK COMPLETE`, while preserving the source's authored texture, broad
  reflection, deep lower lip, hot inner edge, and single-action hierarchy.
- The selected dock plate is slightly stronger than the concept's selected
  state. This is an acceptable product delta: it gives the five compact mobile
  destinations a practical active target without introducing a second bright
  action in the content.
- Live product sections continue below the concept's first frame on Me, Goals,
  Plans, and Journal. They use the same optical-glass, typography, spacing, and
  material rules and do not alter the approved above-the-fold hierarchy.

### Required fidelity surfaces

- Fonts and typography: passed. Fraunces carries page, quest, goal, date, and
  meaningful-number hierarchy; JetBrains Mono carries compact mechanics; Inter
  carries explanation and controls. The final phone renders show no collision,
  accidental fallback, cramped line height, or unplanned title truncation.
- Spacing and layout rhythm: passed. All five screens keep the same cinematic
  hero proportion, 16 px content gutter, section cadence, card insets, faceted
  edge language, and fixed dock relationship. The Plans day panel and long Goal
  titles remain legible behind the dock with normal scrolling.
- Colors and visual tokens: passed. Near-black walnut, espresso glass, aged
  brass, honey action gold, parchment, and small domain-color notes map
  consistently across every destination. Completed controls use warm
  metal/parchment rather than inexpensive saturated green.
- Image quality and asset fidelity: passed. Quest categories and all three new
  companion desk scenes use authored raster art with safe crops, soft
  integration, and overscan. No placeholder, emoji illustration, handcrafted
  SVG substitute, stretched screenshot, visible crop seam, or duplicated room
  polygon remains.
- Copy and content: passed. Navigation is
  `ME · QUESTS · GOALS · PLANS · JOURNAL`; Journal contains functional
  `ENTRIES · PATTERNS · CHRONICLE`. Existing analytics survive under Patterns,
  and page subtitles support the room-at-night emotional model without leaking
  implementation instructions into the product.
- Icons and controls: passed. Material icons retain one weight family and all
  visible primary controls work: Quest completion/undo, furnishing/sharing,
  new-goal oath flow, day planning, journal writing, internal Journal lenses,
  and all five dock destinations.
- Accessibility and resilience: passed. Existing semantics and practical tap
  targets remain intact. In-app and operating-system reduced-motion preferences
  park parallax, fire, sheen, and category-art drift at composed still frames.
  Full widget coverage includes lazy mobile lists, longer content, overlays,
  and core navigation without overflow.

### Depth, motion, and material QA

- One calibrated motion field feeds every page. Native phone tilt uses
  low-pass accelerometer input; pointer position is the desktop/web equivalent.
- The room plate stays intact and overscanned while its camera position moves.
  Independent light, desk/foreground art, embedded category art, and glass/gold
  reflections respond at smaller rates, creating depth without visible cut
  planes.
- Scroll moves content over the fixed scene, progressively blurs and warms the
  scene beneath it, and shifts the gold sheen phase. The mid-scroll Quest
  capture verifies that foreground typography and controls remain crisp.
- Fire and candlelight own the only continuous ambient animation. Gold sheen
  and Quest sparkles do not perform autonomously; they respond to user tilt and
  scroll. Optional hearth audio loops at a deliberately low level and respects
  the existing sound toggle.

### Focused comparison

`design/comparisons/2026-07-30/quest-control-focused.png` compares the most
fidelity-sensitive region at the same normalized scale. The open jeweler's
orbit, small check-latch, right-side painted still life, XP plaque, framed
active card, broad gold reflection, and compact following rows remain readable
at full resolution. The individual companion comparisons were also opened at
their original 1730 × 1922 size; no additional crop was needed because their
hero, CTA, card, and navigation details were already legible.

### Comparison history

1. Earlier P1: the Quest screen was visually rebuilt while Me, Goals, Plans,
   and Insights still belonged to an older, flatter generation.
   - Fix: established one canonical bible, rebuilt all five destinations around
     shared scene, glass, type, spacing, navigation, and depth primitives, and
     changed top-level Insights to Journal while preserving its evidence tools.
   - Post-fix evidence: the five-screen comparison contact sheet.
2. Earlier P1: room depth used visibly sliced painted polygons; the result
   duplicated furniture/window edges and felt cheap.
   - Fix: restored one continuous overscanned room plate, increased its camera
     travel, and separated only light and authored foreground/art planes.
   - Post-fix evidence: resting and mid-scroll Quest captures plus the
     seam-free Me hero.
3. Earlier P1: Quest gold sparkled continuously, the completed check read as a
   green token, and the reward stack competed with XP and card content.
   - Fix: made sheen input-driven, rebuilt incomplete/completed controls in
     dark glass and aged brass, and consolidated rewards into one protected
     bottom rail that stays visible longer.
   - Post-fix evidence: focused Quest comparison and completed reward capture.
4. Earlier P2: Goals used one flat list treatment, Plans showed only due-date
   events, Me pushed identity/build context too low, and Journal lacked the
   personal Then & Now beat shown in the approved direction.
   - Fix: gave each Goal its own softened category painting, made Plans surface
     the day's actual recurring and planned quests, tightened Me identity and
     milestone structure, and added a live Then & Now card above existing
     journal/analytics tools.
   - Post-fix evidence: current Goals, Plans, Me, and Journal normalized
     comparisons.
5. Final comparison: no actionable P0/P1/P2 difference was found. Remaining
   deltas are the intentional amber action temperature, stronger selected dock
   affordance, and real functional content below the concept frame.

### Verification

- `flutter analyze`: passed with no issues.
- Full `flutter test`: 103/103 passed.
- Production screenshot story, including resting, scrolled, completion, and
  all five destinations: passed.
- `flutter build web --release`: passed; Wasm dry run passed.
- Local release preview: HTTP 200 at `http://127.0.0.1:4173/`.
- The user-selected in-app browser remains the preview target; no alternate
  browser automation was introduced.

final result: passed

---

## First-run, truthful furnishing, and contextual Journal - final 2026-07-31 pass

### Source visual truth

- User phone evidence:
  `C:/Users/mikus/.codex/codex-remote-attachments/019faf64-832e-7d63-8247-d71ac627fd36/12083B9C-96F6-43BA-B753-CB26C01EBB50/1-Photo-1.jpg`
  and `2-Photo-2.jpg` in the same folder.
- Approved Me and Journal directions:
  `design/visual-targets/2026-07-30/me.png` (853 x 1844) and
  `design/visual-targets/2026-07-30/journal.png` (853 x 1844).
- Canonical product rules: `DESIGN-BIBLE.md` and `VISUAL-WORKFLOW.md`.
- Registered room masters:
  `design/source-assets/rooms/wall_walnut-clean-v2.png`,
  `wall_walnut-empty-v3.png`, and `wall_walnut-rug-v1.png`, each
  1536 x 1024. The empty and rug plates were image edits, not unrelated
  generations: architecture, camera, moon, fireplace, light, and crop stay
  registered; the rug plate adds only the first owned furnishing.

### Implementation surfaces

- Me and furnishing state:
  `lib/screens/me.dart`, `lib/screens/shop.dart`,
  `lib/widgets/home_room.dart`, `lib/content/furniture.dart`, and the optimized
  runtime plates under `assets/rooms/`.
- Journal differentiation:
  `lib/models.dart`, `lib/screens/insights.dart`,
  `lib/screens/journal_hub.dart`, and `lib/screens/journal_entry.dart`.
- First run and compact resilience:
  `lib/widgets/onboarding_flow.dart` and `lib/screens/goal_wizard.dart`.
- Delivery and responsiveness:
  `lib/tokens.dart`, `lib/main.dart`, `web/index.html`, and `pubspec.yaml`.
- Regression evidence:
  `test/audit_regressions_test.dart` and the focused stories in
  `test/screenshots_test.dart`.

### Viewports, dimensions, and states

- Main screenshot audit: 430 x 932 logical pixels at DPR 3, producing
  1290 x 2796 rasters.
- Compact accessibility audit: 320 x 568 logical pixels with 1.3x text scale.
- Tested first-run states: opening, evening-aware naming, day-shape choice,
  and first-board explanation.
- Tested Me states: new account with zero Glimmers, open furnishing catalog,
  unaffordable preview, and rug-only try-on.
- Tested Journal states: fresh destination, empty Journal hub, context-aware
  prompt chips, and editor with an automatically attached daily trace.
- The furnished Level 18 approved reference is used for material and hierarchy
  comparison only. The fresh build intentionally shows a truthful empty Level 1
  room instead of borrowing advanced progress from the concept.

### Rendered comparison evidence

- Phone-friendly full pass:
  `design/comparisons/2026-07-31/first-run-me-journal-audit-phone.webp`.
- Approved/current Me comparison:
  `design/comparisons/2026-07-31/probe-approved-me.png`.
- Approved/current Journal comparison:
  `design/comparisons/2026-07-31/probe-approved-journal.png`.
- Focused empty/rug registration comparison:
  `design/comparisons/2026-07-31/probe-room-state.png`.
- Individual production captures:
  `test/goldens/store_audit_00_welcome_1290x2796.png` through
  `store_audit_14_journal_editor_1290x2796.png`, including
  `store_audit_11b_rug_try_on_1290x2796.png`.

### Comparison history and fixes

1. P0: the Walnut room source contained a baked `LEVEL 18` interface near the
   lower edge, so a new user's Me screen inherited progress they had not earned.
   - Fixed by restoring a clean source plate and adding a separate truly empty
     authored room state. Fresh Me now contains no baked text, furniture, or
     lit fire.
2. P0: `FURNISH` looked actionable but the useful hit target was narrow and the
   room preview could reveal objects not selected by the user.
   - Fixed by making the full furnishing rail actionable, retaining real
     preview/purchase logic, and using exact registered empty and rug plates for
     the first upgrade. The focused comparison verifies that the rug adds no
     chair, desk, decor, or fire.
3. P1: room masks and blur were recomposited inside the animation loop, making
   the Vercel build feel unnecessarily heavy.
   - Fixed by compositing once per inventory state, caching up to eight finished
     room textures, lowering web-only sensor/fire publication rates, compressing
     runtime art, preloading the opening plate, and removing runtime font fetches.
4. P1: Journal resembled a themed notes list and its icon did not match the
   approved open-book language.
   - Fixed with the correct book icon plus automatic daily evidence: completed
     quests, goal threads, XP, level, build movement, streak, energy, and stat
     gains. `TODAY'S THREAD`, context-aware prompts, Patterns, Chronicle, and
     Then & Now now turn entries into a memory layer grounded in app activity.
5. P1: the original first run asked for inputs before clearly explaining the
   value loop and became cramped on small, large-text phones.
   - Fixed with time-aware greeting, honest name usage, skippable naming,
     clearer day-density language, a four-step progress rail, back navigation,
     and a final Quest -> XP/Glimmers -> room/Journal explanation. The compact
     path and the following oath choices pass without covered content.
6. P2: furnishing prices used unsupported symbols and catalog labels no longer
   described their authored room objects.
   - Fixed with supported iconography, plain `Glimmers` price copy, and names
     aligned with the visible walnut furnishings while retaining stable IDs.

P0 remaining: none.

P1 remaining: none.

P2 remaining: none.

### Fidelity and usability checks

- Typography: passed. Fraunces, Inter, and JetBrains Mono are bundled locally;
  first launch no longer waits on Google Fonts. Type remains legible at both
  audited phone sizes and the name/oath flows do not collide with pinned CTAs.
- Spacing and hierarchy: passed. Me, furnishing, Journal, and first-run content
  remain inside their authored frames, with one primary gold action per state.
- Materials and color: passed. Parchment, walnut glass, aged brass, and restrained
  honey-gold sheen remain consistent with the approved system; no flat saturated
  completion or utility colors were introduced.
- Image fidelity: passed. The ghost HUD is absent, room states are registered,
  the rug is low-resolution enough to sit naturally in the painting, and no
  unrelated furnishing leaks into its try-on state.
- Copy: passed. The onboarding explains what is being asked and why. Journal
  accurately says it captures what has happened so far today; it does not claim
  future activity is already attached.
- Icons and controls: passed. Journal uses an open book. The full furnishing rail,
  catalog tabs, try-on, unaffordable state, and back controls are functional and
  use supported Material icons.
- Accessibility and resilience: passed. Compact 320 x 568 / 1.3x text testing,
  reduced-motion behavior, minimum practical tap targets, and scroll access were
  covered. The web build's floating Vercel toolbar is deployment chrome, not an
  application control.

### Performance and delivery verification

- `flutter analyze`: passed with no issues.
- Full `flutter test`: 123/123 passed.
- `flutter build web --release`: passed.
- Release asset audit: 13,247,560 bytes of app assets; room assets total
  1,559,837 bytes. `main.dart.js` is 3,698,008 bytes.
- Local release preview: HTTP 200 at `http://127.0.0.1:4173/`.
- Vercel preview deployment: ready and HTTP 200 with temporary authenticated
  access. Native/TestFlight is expected to avoid browser CanvasKit and Vercel
  toolbar overhead, but a physical TestFlight run remains the performance truth.
- `git diff --check`: passed; only pre-existing line-ending conversion warnings
  were reported.

final result: passed
