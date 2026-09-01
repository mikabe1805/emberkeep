# Build 39 integrated release audit

Recorded against `worktree:479ac46ec8c1:a0a0c3da5f321618061d2972` on
2026-09-01 after the final Writer photo-wall and compact-accessibility
corrections. This is current local
evidence for the internal candidate, not a signed iPhone or public-release
receipt.

## Product and visual journey

The current production surfaces were rendered and inspected as one journey,
not as isolated cards:

1. **Quests** opens with an actual ordinary job, visible XP, a concrete Complete
   action, and the room as the reward context. The selected field and `OPEN IF
   IT FITS` keep a crowded board useful without turning every possibility into
   debt.
2. **Reward** proves the loop with the completed job, XP, Glimmers, stat and
   streak effects, and the optional Journal handoff. The state is information
   dense, but hierarchy remains coherent and the reward is traceable to the
   action.
3. **Goals** makes the promise operational: it names a specific goal, next
   action, and Workshop route. The very quiet `this doesn't fit today` action is
   the weakest affordance in the first three frames, but it remains a secondary
   recovery route rather than the primary job.
4. **Workshop and Steward** retain the authored walnut, brass, paper, and
   honey-light language. Talk is optional and ephemeral; it cannot create a
   Quest, accept a plan, or mutate progression.
5. **Recovery** gives smaller work, preparation, and leaving the day alone equal
   legitimacy. It is the clearest proof that Room of Days is not a punitive
   streak tracker.
6. **Plans** keeps calendar and class context on the same warm desk. Its sparse
   month grid is slower to parse than the Quest board, but event detail and the
   next commitment remain readable.
7. **My Space** now says `PRIVATE PAGE` and labels private cards `ONLY YOU`.
   Writing, Journal photos, and the local room photo are not implied to be
   public.
8. **Change Space** shows a complete authored room rather than a thumbnail grid.
   The rejected visible mantel-keepsake sentence and editor are absent.
9. **Journal** remains a private record. Its Cabinet `Keepsakes` label refers to
   saved memories, not the removed mantel experiment.
10. **Discover** names its private default and optional listing boundary. It is
    secondary to the first three store frames, so the download reason is not
    forced through a social feature.

The optional room-photo slice was separately rendered at normal width,
320x568 with 2x text, all six authored rooms, both parallax extremes, scroll,
half-soft and fully softened transitions, compact preview, removal, private
share state, confirmation, ready-to-publish state, and local public preview.
The Writer-specific wall defect found during the first fresh pass is resolved:
an explicit photo uses a registered clear wall plane above the fireplace, while
removing the photo restores the original bookshelf and no-photo room. The photo
remains source-local until the separate sharing confirmation is saved.

An independent review then found one material compact-state issue: at 320x568
with 2x text, the editor's full title consumed too much height and the adjacent
Replace/Remove actions crowded each other. The final correction gives that
state a direct `Photo` / `Private on device.` header and stacks the actions at
full width. A real remove-and-save interaction test and two fresh renders cover
the corrected top and action states. The same independent reviewer re-inspected
the result and found no remaining material UI issue in the reviewed scope.

## Current rendered artifacts

- `visual-evidence/photo-writer-room.png` — explicit local photo in the corrected
  Writer room.
- `visual-evidence/photo-editor-private.png` — normal private editor state.
- `visual-evidence/photo-editor-large-text-top.png` — corrected 320x568,
  2x-text top state with the compact privacy header.
- `visual-evidence/photo-editor-large-text-actions.png` — 320x568, 2x-text
  scrolled action state with full-width Replace/Remove controls.
- `visual-evidence/photo-share-confirmation.png` — separate public sharing
  confirmation and copy boundary.
- `visual-evidence/photo-share-ready.png` — acknowledged but not-yet-saved
  public state.
- `store-assets/screenshots/app-store/01-quests-1290x2796.png` — search-result
  opener and concrete job.
- `store-assets/screenshots/app-store/02-reward-1290x2796.png` — visible reward
  proof.
- `store-assets/screenshots/app-store/03-goals-1290x2796.png` — goal-to-next-step
  bridge.

The App Store first-three order is deliberately Quests, Reward, Goals. It says
what a person does, why completion feels different, and how larger intentions
become a next action before introducing rooms, Journal, or social discovery.

## Deterministic validation

- `flutter analyze --no-pub`: pass, no issues.
- Full `flutter test --no-pub`: pass, **1,074 tests**. One existing non-fatal
  widget-test tap warning remains diagnostic noise; the affected test and the
  suite passed.
- Compact room-photo editor regression: **7/7 pass**, including a 320x568,
  2x-text remove-and-save path that exercises the real controls.
- Final Writer/photo regression: pass. It asserts that a decoded explicit photo
  selects only the registered photo-ready wall or matching soft layers, and that
  the original no-photo room returns immediately.
- Fresh screenshot capture after the final source correction: **43/43 pass** in
  both required capture modes; ten 1290x2796 opaque RGB App Store PNGs exported,
  hashed, and directly inspected.
- Functions Jest suite: **134 pass**, 20 emulator-only cases skipped in the
  ordinary run.
- Functions lint and TypeScript build: pass. The package correctly requests Node
  22; the current local shell is Node 20, so CI/runtime version alignment remains
  a maintenance check.
- Firestore emulator authorization: **16/16 pass**, including expected denied
  writes.
- Firestore plus Storage emulator privacy: **4/4 pass**, covering owner
  create/read/replace/delete, exact live-revision public reads, revocation and
  stale-copy behavior, unauthenticated/cross-owner rejection, content type, and
  the 800 KiB limit.
- Final `flutter build web --release --no-pub`: pass; Wasm dry run also passed. No
  hosting deployment was performed.
- Final `flutter build apk --debug --no-pub`: pass. The Android release build stopped
  at its intended private-keystore gate, so no unsigned artifact is presented as
  a release APK.
- Store metadata verifier: all character limits and Build 39 identity checks
  pass. It intentionally stops at the stale pre-receipt manifest until the
  source and screenshots are bound by the second candidate commit.

## Privacy and compatibility boundaries

- Legacy `roomKeepsakes` data still round-trips but is inert in rendering, copy,
  semantics, and visitor pages.
- A picked room photo is canonical local PNG data, never a gallery path or
  ordinary cloud-backup field.
- Public photo bytes require a separate explicit owner action and exact current
  public-room revision. Discover cards do not show the photo.
- Removing or superseding public state prevents a new anonymous read; owner
  cleanup remains possible.
- The public-room schema and old-save compatibility remain intact; this visual
  correction does not strand older clients or erase legacy saves.

## Accessibility and remaining risk

Automated and rendered evidence covers 320x568, 1.3x and 2x text, scrolling,
semantics, Reduced Motion, no-photo fallback, malformed/cross-owner media, and
private/public copy. It does not establish iPhone VoiceOver order, thumb feel,
haptic weight, lower-brightness OLED separation, real photo-picker behavior,
speaker/headphone balance, warm-device frame pacing, background/resume, or
offline/reconnect behavior. Those remain required on the exact processed
TestFlight build. Deployed two-account behavior, App Check, Apple processing,
and owner taste acceptance also remain separate gates.

## Verdicts

- `code_complete`: **pass** for the frozen local Build 39 source and packaging
  slice.
- `visual_evidence_ready`: **pass** for owner and device review.
- `owner_device_accepted`: **pending** until the exact signed candidate is used
  on the owner's physical iPhone and the two-account/deployed-backend journey is
  complete.

## Independent review

The read-only reviewer was not an implementation author. The first review
reported the compact editor crowding above; the second review verified the
direct compact header, vertically stacked actions, current 320x568 2x renders,
and the real remove/save regression. Its final disposition was
`visual_evidence_ready=pass` for the reviewed rendering and UI scope, while
candidate binding, Apple processing, physical-device feel, backend deployment,
and two-account behavior remain deliberately outside that verdict.
