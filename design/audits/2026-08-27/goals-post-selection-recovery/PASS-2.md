# Goals post-selection recovery — pass 2

Captured 2026-08-27 after the returning-goal journey, exact Quest handoff,
goal-linked lighter path, contextual Unstick path, and UI-text polish were
rebuilt together.

## Product result

- A returning goal presents one exact due Quest and one honest lighter version.
- Either action uses the same 1.64-second room crossing and 360ms arrival hold,
  then opens that exact Quest on the shared Quest board.
- The lighter action reuses an eligible linked Quest or creates a difficulty-1,
  due-today Quest attached to the selected goal. Rapid creation collisions are
  resolved without opening a generic composer.
- Contextual Unstick keeps its generated Quest attached to the selected goal
  and hands off that exact Quest.
- The collapsed support door expands to `Find a start` and `Guided Workouts`
  without competing with the primary action.

## Visual result

- Primary motion evidence is authored at 402 x 874 logical points, matching the
  regular modern-iPhone target used for this pass.
- Sentence-case cue and support copy reduce the density of all-caps labels while
  keeping `THE ONE TO RETURN TO`, `THE NEXT TRUE THING`, and the return-plan
  identity as deliberate roles.
- Goal Detail now gives the add-Quest action and long-press goal-release action
  their own dark, room-matched surfaces over the bright kitchen backsplash.
- The approval comparison, still-state review, and motion capture use the same
  goal, reason, exact Quest, and lighter action fixture.

Fresh artifacts:

- `design/comparisons/2026-08-27/evidence-goals-returning-commitment.png`
- `design/comparisons/2026-08-27/goals-living-commitment-phone.webp`
- `design/comparisons/2026-08-27/goals-return-motion-contact-sheet-402x874.png`
- `design/comparisons/2026-08-27/goals-return-journey-402x874.mp4`
- `test/goldens/goals_personal_index_support_open_430x932.png`
- `test/goldens/goal_detail_habit_support_430x932.png`

## Independent critique

Claude Fable 5 judged the core journey ship-worthy and verified that the route
lands on the exact Quest, the lighter path follows the same contract, and the
room landmarks preserve spatial continuity. Its concrete findings were applied
and recaptured: detail-bottom contrast, fixture divergence, label density, and
the final low-contrast goal-release affordance. The final release-control pill
was directly inspected after the follow-up review.

## Verification

- `flutter analyze`: pass, no issues.
- `flutter test`: pass, 801 tests.
- Focused Goals and momentum-kit suites: pass, 38 tests.
- Fresh normal, pressed, accepted, hard-day, support-open, detail, 2x text, and
  exact-arrival captures: pass.
- Deterministic returning journey at 60 fps: pass, 110 frames.
- `flutter build web --wasm --release`: pass.
- LAN preview, bootstrap, and Wasm responses on port 4174: HTTP 200; server is
  bound to `0.0.0.0`.

## Remaining owner gate

Physical-iPhone feel is still pending. Renders and automated checks do not prove
thumb response, OLED value separation, haptic weight, or whether the authored
travel feels right after repeated daily use.
