# Goals return and review — current-branch evidence

Refreshed 2026-09-26 against scoped implementation revision
`commit:ba316fa36f809ee257204f522b6499f744681e7e` on
`codex/goals-return-harness`. The exploratory implementation preceded this
record; this file documents the current source and current branch rather than
claiming that it was built from an earlier accepted record.

## Deterministic checks

- Focused regression set — 61 tests passed: `readability_tokens_test`, `release_native_privacy_test`, `whats_new_screen_test`, `working_experience_visual_test`, `interaction_sound_quality_test`, and `goals_choose_today_test`. It covers the readable floor, sound lane, Build 44 metadata and What's New record, one-doorway return behavior, Cancel/no-mutation, count-aware semantics, 44 by 44 compact controls, and the Reduced Motion 320 by 568/1.5x fixture.
- `flutter test --no-pub --update-goldens --dart-define=CAPTURE_GOLDENS=true test/screenshots_test.dart --name "goals personal index: narrow large text"` — passed and refreshed the exact 320 by 568/1.5x selected return capture.
- `flutter test --no-pub --update-goldens --dart-define=CAPTURE_GOLDENS=true test/working_experience_visual_test.dart` — passed 9 working-route captures, including 2x text reachability.
- `flutter test --no-pub` — passed all 1,190 tests in 2:41. Captured terminal receipt: `C:\Users\mikus\Documents\Codex\2026-09-26\can-x20\work\days-full-after-goals-fix.log`.

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
change. The release repair also changes both compact contacts to the existing
`glass/select` lane and raises the chip text from 9 px to `Type.minLabel`; the
focused sound and readability tests pass against those exact changes.

## Known evidence boundary

The checked-in painted-room Goals golden from Build 43 was stale. A controlled
fresh capture of untouched `ea3b0ae` rendered the pre-existing stacked-card
Goals UI; the visual difference was not caused by this slice. Only Goals
goldens exercised by the changed route were refreshed.

## Owner checkpoint

The owner accepted the direction with `Yes, continue this direction`. Physical
phone review remains pending; the next action is to review the active and
narrow selected captures on the owner's phone before treating this as device
accepted or release-ready.
