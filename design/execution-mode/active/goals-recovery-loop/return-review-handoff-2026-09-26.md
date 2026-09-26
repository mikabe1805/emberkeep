# Goals return and review slice — 2026-09-26

## Source and scope

- Branch: `codex/goals-return-harness`
- Base: `ea3b0ae7a45b134f9fb6b2e7be494ad818573cf5`
- Job: on returning to Goals, see that today's field is available, see the
  exact current Quest, then review or set up to three carried Quests. If the
  exact Quest does not fit, the existing quiet recovery control stays beside
  it.

The existing recovery loop remains the state authority. This slice changes
the entry hierarchy only: a compact `TODAY'S FIELD` doorway sits above the
focused Goal, and the complete field remains below it. The doorway intentionally
does not repeat the field's individual Quests, completion count, or action;
those live in the one detailed field surface.

## Fresh rendered evidence

Generated from this branch with
`flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/screenshots_test.dart --name "goals personal index"`.

| State | Viewport | Artifact | SHA-256 |
| --- | --- | --- | --- |
| Active Goal and carried field | 430x932 | `test/goldens/goals_personal_index_active_430x932.png` | `17fd7e09cb4061de40c7acdf2177b454bc13bd0e5f0b436803772e433805d9b6` |
| No carried field, 1.5x text | 320x568 | `test/goldens/goals_personal_index_narrow_large_text_320x568.png` | `611e41aec0acf52547bae4cd339e153e0848659796c2193d7b6a226527741b30` |

The first frame keeps the detailed Goal and its one honey action ahead of the
full field. The doorway has no luminous treatment and opens the existing
choose/review flow.

## Checks run

- `flutter analyze lib/screens/goals.dart test/goals_choose_today_test.dart`
- `flutter test test/goals_choose_today_test.dart`
- `flutter test test/goals_quest_management_test.dart --name "focused recovery"`
- focused visual capture suite above (six Goals states)

## Remaining gate

These renders and widget tests cannot establish whether the first-frame
ordering feels more useful on a physical phone. Owner review of the 430x932
and 320x568 captures is still required before this is treated as an accepted
direction or a release candidate.
