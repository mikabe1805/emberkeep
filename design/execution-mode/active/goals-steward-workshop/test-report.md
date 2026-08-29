# Goals spatial workshop slice test report

Captured: 2026-08-28

Correction note: the earlier copy-free, automatic wide-room breath was rejected
after owner video review. Evidence for that behavior is superseded. This report
now records the interactive wide-room waypoint that replaced it.

## Product and interaction checks

- `flutter test test/goals_quest_management_test.dart`
  - Passed: 34
  - Failed: 0
  - Covers the representative quick-create journey, a two-second no-auto-advance assertion at the wide waypoint, visible `Cross the room`, Back at every rest, four-stage reverse travel, Reduced Motion with the same waypoint, zero Quest before workshop acceptance, cancel and reopen, exact goal/step/revision identity, edited and smaller actions, rapid-repeat rejection, persistent arch typography, blur only during painted-room travel, and crisp parked states.
- `flutter analyze lib/screens/goal_opening.dart lib/widgets/goal_world.dart`
  - Passed with no issues.
- `flutter test test/screenshots_test.dart --name "goal opening:"`
  - Passed: 4
  - Failed: 0
  - Exercises normal, compact large-text, 1.15 text, and 200-percent long-copy opening states with the added waypoint action.
- `flutter test tool/goals_opening_motion_capture_test.dart`
  - Passed at 430 x 932 and again at 320 x 568 with 1.5 text.

## Rendered-state checks

- `goal opening: desk, threshold, and arrival`
  - The 430 x 932 journey now renders desk, interactive wide waypoint, threshold, workshop, and workshop controls as separate states.
- `goal workshop: 1.3 text keeps acceptance reachable`
  - Passed at 430 x 932 with a true 1.3 text scaler; the primary acceptance and all workshop controls remain reachable.
- `goal opening: narrow large text remains reachable`
  - Passed at 320 x 568 with a 1.5 text scaler; the natural top begins with the complete Goal heading, a visible scroll reaches `Open the route`, and wide waypoint, threshold, workshop top, acceptance, edit, smaller-action, and return states remain reachable.
- `goal opening: desk clasp at 1.15 text scale`
  - Passed at 430 x 932 after the affected desk golden was refreshed.

The capture-enabled golden suite was not regenerated for this correction, so
this report does not claim that every repository golden comparison passes. The
affected opening state tests above were run directly and passed.

## Motion checks

- `goals-opening-interactive-wide-stop.mp4`: deterministic 30 fps phone capture passed with 231 frames at 430 x 932.
- `goals-opening-interactive-wide-stop-compact.mp4`: deterministic 30 fps compact capture passed with 249 frames at 320 x 568 and 1.5 text; the extra frames show the real scroll from the complete Goal heading to the first action before travel.
- The wide apartment is now a semantic state rather than a timed plateau. It shows the same exact first move and lighter option, exposes `Cross the room`, enables Back, has no blur at rest, and remains parked indefinitely. The capture holds it for 42 frames before the recorded press; the behavior test additionally pumps two seconds and verifies that neither camera nor plan moves.
- The travel legs are deliberately unequal: a 760 ms desk withdrawal, a 1040 ms arch approach, a 1120 ms doorway crossing with velocity-derived painted-room softness, then a quieter workshop settle. Blur resolves completely whenever the camera parks.
- The frame contacts were inspected across desk, wide waypoint, explicit press, arch approach, threshold hold, doorway crossing, and workshop reveal. The same live first move is readable at the wide waypoint and arch. Supporting copy releases first; the action remains readable while the workshop material gathers around it, then inks into the workshop cut before facts and controls arrive.
- Reduced Motion retains all four explicit-action states as finished stills, including the wide waypoint; it removes camera travel and velocity blur without removing information or ownership.

## Known boundary

This report covers the representative quick-create slice. Advanced wizard and ready-made adoption are intentionally deferred until the owner checkpoint recorded in the direction brief. Physical iPhone feel, haptics, OLED separation, natural frame pacing, and owner acceptance of the complete journey remain unverified.

The owner-reported text-to-box discontinuity, missing spatial stop, and dead-air auto-advance were followed by a fresh 34-test focused run, four targeted rendered-state tests, targeted analysis with no issues, regenerated phone and compact motion captures, and an independent review of the current artifacts.

## Expansion verification: one ownership boundary everywhere

Captured: 2026-08-28 18:49 EDT

- `flutter test test/goal_route_engine_test.dart test/goals_quest_management_test.dart`
  - Passed: 48
  - Failed: 0
  - Covers quick creation, cancellation, edit, smaller action, rapid acceptance, advanced wizard, new ready-made adoption, schedule preservation, meaningful repair, stale-revision cleanup, completed-proof retention, direct workshop entry, and exact current-revision Quest acceptance.
- `flutter test test/audit_regressions_test.dart test/semantic_action_regression_test.dart`
  - Passed: 15
  - Failed: 0
- `flutter test test/widget_test.dart --plain-name "goal wizard: name, add a quest via the sheet, begin"`
  - Passed: 1
  - Failed: 0
- `flutter test test/screenshots_test.dart --plain-name "goals personal index: active and quick create"`
  - Passed: 1
  - Failed: 0
- `flutter analyze` over the 13 edited implementation and regression-test targets
  - No issues found.
- Final deterministic opening capture passed at 430 x 932 and again at 320 x 568 with 1.5 text.
- `git diff --check` over the edited implementation and test targets reported no whitespace errors.

The quick composer now ends after Aim and Reality. `Draft my route` persists a
GoalPlan with zero board Quests and hands directly to the room; the workshop is
the first complete route review. The full wizard and new ready-made adoption
share that boundary. Their configured recurrence, weekdays, difficulty, dread,
and verification live as dormant Quest templates until acceptance. Existing-goal
`Add missing actions` remains ordinary board management rather than pretending
to be a new-goal ceremony.

Meaningful repair preserves completed proof, removes only unfinished Quests
from the superseded route revision, and opens directly in the workshop with no
current-revision Quest. Cancellation keeps the revised plan resumable; one
acceptance creates one exact current Quest.

Rendered evidence:

- `design/comparisons/2026-08-28/goals-workshop-route-handoff-before-after.webp`
  compares the removed `3 OF 3 · ROUTE` approval against the direct room handoff.
- `design/comparisons/2026-08-28/goals-workshop-expansion-contact.webp`
  places Aim, Reality, desk, wide room, normal workshop, and compact workshop
  together. The compact state retains Cut, Why, Proof, and explicit acceptance.

The final render check caught a long clasp label wrapping inside a fixed-height
desk control. A width-expansion trial caused a 24 px short-viewport overflow and
was rejected by the focused suite. The final fix keeps the proven folio geometry
and shortens the action to `Open route`; the complete 48-test journey then
passed. No generated or placeholder steward pixels were introduced.

## Returnable Workshop slice: Goals foyer, register, and selected bench

Captured: 2026-08-28 20:35 EDT

- `flutter analyze lib/screens/goal_workshop.dart lib/screens/goal_opening.dart lib/screens/goals.dart lib/screens/goal_detail.dart lib/widgets/goal_threshold_scene.dart test/goals_quest_management_test.dart test/screenshots_test.dart`
  - Passed with no issues.
- `flutter test test/goals_quest_management_test.dart test/goal_route_engine_test.dart test/audit_regressions_test.dart test/semantic_action_regression_test.dart`
  - Passed: 64
  - Failed: 0
- `flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/screenshots_test.dart --name "goals personal index: (narrow large text|active and quick create)"`
  - Passed: 2
  - Failed: 0
- `dart format --output=none --set-exit-if-changed` over the seven changed Dart implementation and regression targets
  - Passed with zero formatting changes.

The Goals room now exposes one quiet attached `Workshop` affordance while the
exact current Quest remains the luminous owner. Workshop opens into the same
kitchen and places one faceted route register on the lower bench. The register
derives `CUT WAITING`, `QUEST ON BOARD`, `NEEDS A ROUTE`, and `ROUTE COMPLETE`
from the existing `GoalPlan` and exact linked Quest identity; it owns no second
planning model.

Selecting a row reuses the existing workshop folio. An owned current object
shows `CURRENT QUEST` and `Open this Quest`; an unowned current cut shows `THE
CUT` and `Take this Quest`. Cancellation does not materialize work, rapid repeat
cannot duplicate it, an owned row opens the identical Quest object, and route
repair keeps the accepted first-opening history while invalidating only
unfinished stale revisions.

Rendered evidence:

- `design/comparisons/2026-08-28/goals-workshop-return-phone.webp` places the
  Goals entrance, route register, owned bench, waiting bench, and both 320 x 568
  at 1.5 text states together.
- `design/comparisons/2026-08-28/evidence-workshop-selected-bench.png` places
  the approved material and hierarchy reference beside the current selected
  bench. The production build deliberately retains the room, folio, cut, route,
  and clasp hierarchy without copying the reference-only generated person.

Independent review initially found two accessibility defects: the compact
owned state capped and ellipsized live goal or Quest content, and ownership
labels fell below a comfortable type floor. The compact folio now reflows the
complete goal and Quest at the active text scaler, and the operational labels
were raised. The same reviewer re-inspected the fresh 320 x 568 renders and
returned PASS with no remaining P1 or P2 finding.

The bounded implementation and rendered evidence are complete. A physical
iPhone still has to establish OLED separation, font rasterization, manual scroll
feel, edge and back gestures, and owner feel. The steward layer also remains
empty until Mika supplies or approves the consistent owner-authored character;
any pencils in that final pocket asset must read as actual pencils.

## Owner correction: mounted tavern entrance and visible steward

Captured: 2026-08-28 23:06 EDT

This section supersedes the kitchen destination, floor-written Workshop note,
and empty steward layer described above. The owner explicitly rejected those
three results and asked for a genuinely separate tavern with the already-made
helper visible inside it.

- `flutter test test/goals_quest_management_test.dart`
  - Passed: 36
  - Failed: 0
  - Covers waiting and owned routes, non-mutating cancel/reopen, exact Quest
    identity, route repair, rapid-repeat idempotence, the mounted entrance,
    canonical tavern asset, and steward semantic presence.
- Focused authored render stories, run without updating their expected images:
  - `goals personal index: active and quick create`
  - `goals personal index: narrow large text`
  - `goal opening: desk, threshold, and arrival`
  - `goal opening: narrow large text remains reachable`
  - Passed: 4
  - Failed: 0
- Targeted `flutter analyze` over the six changed Goals implementation files
  and two affected tests passed with no issues.

Fresh source/build evidence:

- `design/audits/2026-08-28/goals-tavern-workshop-pass/comparison-foyer-430x932.png`
  compares the source room with the current mounted, level Workshop entrance.
- `comparison-tavern-home-430x932.png` and
  `comparison-tavern-home-320x568.png` compare the tavern source with the live
  register at normal and 1.5x compact text.
- `comparison-steward-identity.png` places the locked steward handoff and the
  runtime tavern together. Face, tied hair, hooded overshirt, dark apron, brass
  fasteners, left sleeve patch, and exactly two sharpened wooden pencils remain
  consistent in the authored phone frame.

The mounted entrance now activates the spatial room route and resolves into a
separate walnut-and-amber tavern. The steward remains visible above the lower
register and selected-goal folio; the normal frame also preserves his hands and
pencil pocket. The raster contains no generated UI or text. The compact frame
keeps his face, full goal and Quest identities, scrolling, back, and the primary
action reachable without overflow.

Deterministic code and rendered evidence are current. Physical iPhone OLED
contrast, haptic/audio weight, transition feel, edge gestures, and Mika's owner
acceptance of this corrected slice remain pending.
