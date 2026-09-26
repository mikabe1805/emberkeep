# Goals return and review — current-branch evidence

Recorded 2026-09-26 against implementation commit
`29e1993d3cf21ea44e2449baebb5e8326672ed24` on
`codex/goals-return-harness`. The exploratory implementation preceded this
record; this file documents the current source and current branch rather than
claiming that it was built from an earlier accepted record.

## Deterministic checks

- `flutter analyze lib/screens/goals.dart test/goals_choose_today_test.dart test/screenshots_test.dart` — passed with no issues.
- `flutter test test/goals_choose_today_test.dart` — passed. It covers card and compact-header entry, Cancel returning without priority or persistence mutation, selected field state, a count-aware semantic label, 44 by 44 compact Today and Workshop targets, and a Reduced Motion 320 by 568/1.5x fixture.
- `flutter test test/goals_quest_management_test.dart --name "focused recovery"` — passed. It preserves the existing exact recovery behavior, including leave-today-unchanged and reviewed smaller-cut paths.
- `flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/screenshots_test.dart --name "goals personal index"` — passed six Goals states, including the active return surface and selected narrow large-text state.

## Visual inspection

- `test/goldens/goals_personal_index_active_430x932.png` was inspected as the ordinary active return surface. It places one `Today’s three · 2` review action beside Review goal and Make this smaller; it does not place a second field card above the current Quest.
- `test/goldens/goals_personal_index_narrow_large_text_320x568.png` was inspected at 320 by 568 and 1.5x text with one selected field. It keeps full readable Goal and current-Quest text, shows the compact Today entry in the header, and uses a dark walnut/brass count chip.

## Independent QA finding and resolution

An independent review of the compact header found that the former 20 px icon
inside 8 px padding could render below the 44 px touch-target expectation. It
also rejected the default `Badge.count` appearance and asked for selected-count
semantics. Commit `29e1993` resolves the finding with explicit 44 by 44 Today
and Workshop children, a dark walnut/brass count chip, and the semantic label
`Review today’s three, 1 selected`. The focused widget test asserts the target
geometry and label; the fresh narrow selected render was inspected after that
change.

## Known evidence boundary

The checked-in painted-room Goals golden from Build 43 was stale. A controlled
fresh capture of untouched `ea3b0ae` rendered the pre-existing stacked-card
Goals UI; the visual difference was not caused by this slice. Only Goals
goldens exercised by the changed route were refreshed.

## Owner checkpoint

No owner acceptance or physical-device review is recorded. The next action is
to review the active and narrow selected captures on the owner's phone before
expanding this exploratory direction or treating it as release-ready.
