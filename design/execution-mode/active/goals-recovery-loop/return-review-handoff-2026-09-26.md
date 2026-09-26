# Goals return and review slice — 2026-09-26

## Source and scope

- Branch: `codex/goals-return-harness`
- Base: `ea3b0ae7a45b134f9fb6b2e7be494ad818573cf5`
- Job: on returning to Goals, see that today's field is available, see the
  exact current Quest, then review or set up to three carried Quests. If the
  exact Quest does not fit, the existing quiet recovery control stays beside
  it.

The existing recovery loop remains the state authority. This slice makes the
focused Goal the single return surface: `Today's three · count` opens the
existing picker from beside Review and recovery, so the page does not repeat a
second field card and its Quest rows. At compact large text, the same picker is
available from the calendar icon in the header; a selected field receives its
count badge. The Goal and current-Quest text retain the user's chosen text
scale and may grow or scroll rather than being truncated.

## Fresh rendered evidence

Generated from this branch with
`flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/screenshots_test.dart --name "goals personal index"`.

| State | Viewport | Artifact | SHA-256 |
| --- | --- | --- | --- |
| Active Goal and carried field | 430x932 | `test/goldens/goals_personal_index_active_430x932.png` | `46c02a8c97267a50fe92f7aeca2b9964a16530a8af6bd969e91056ea15c36e1d` |
| No carried field, 1.5x text | 320x568 | `test/goldens/goals_personal_index_narrow_large_text_320x568.png` | `190bf57d21f352a0f7ee954eee765f87f024a151af9ac89479f60fd7913079a5` |

The first frame keeps the exact Quest as the one honey action. Today's three
is a quiet contextual status and opens the existing choose/review flow. The
compact header reduces navigation to icons and preserves the full text scale in
the Goal surface.

## Baseline note

The tracked Build 43 painted-room golden was stale. A detached worktree at the
same `ea3b0ae` revision ran the identical capture command and rendered the
existing stacked-card Goals UI instead. The baseline capture lives at
`app/.worktrees/goals-render-baseline/test/goldens/goals_personal_index_active_430x932.png`.
Only the Goals screenshot states exercised by this changed route were rebased.

## Checks run

- `flutter analyze lib/screens/goals.dart test/goals_choose_today_test.dart`
- `flutter test test/goals_choose_today_test.dart`
- `flutter test test/goals_quest_management_test.dart --name "focused recovery"`
- focused visual capture suite above (six Goals states)

The day-field test covers header/card entry, Cancel returning without priority
or persistence mutation, selection, and the compact Reduced Motion fixture.

## Remaining gate

These renders and widget tests cannot establish whether the first-frame
ordering feels more useful on a physical phone. Owner review of the 430x932
and 320x568 captures is still required before this is treated as an accepted
direction or a release candidate.
