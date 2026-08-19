# Room of Days Release Candidate Visual Audit

- Capture date: 2026-08-19
- Source commit: ca483b8fe0a5496b8105399fc8593c624e0b6a3e
- Source version: 1.0.3+21
- Main viewport: 430 x 932 logical pixels at DPR 3
- Narrow viewport: 320 x 568 logical pixels at DPR 1 and 200% text
- Motion evidence: deterministic Reduced Motion captures plus focused normal/reduced behavior tests
- Places state: protected provider search disabled; manual locations available

## Commands and receipts

| Command | Exit code | Test count when printed | Output family |
| --- | --- | --- | --- |
| `git rev-parse HEAD` | 0 | n/a | `ca483b8fe0a5496b8105399fc8593c624e0b6a3e` |
| `git status --short` | 0 | n/a | Empty before capture; retained as the ownership baseline. |
| `rg -n "^version:" pubspec.yaml` | 0 | n/a | `19:version: 1.0.3+21` |
| `flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true --dart-define=CAPTURE_STORE=true --dart-define=CAPTURE_PLAY=true test/screenshots_test.dart` | 0 | 23 | `01:01 +23: All tests passed!` Deterministic widget, Apple store, and Google Play golden families refreshed. |
| Required-frame `Test-Path` check | 0 | n/a | All seven required Apple store frames exist. |
| Required-frame `System.Drawing.Image.FromFile` check | 0 | n/a | All seven required Apple store frames decode at 1290 x 2796. |
| `git status --short` | 0 | n/a | Empty after capture. |
| `git diff --stat -- test/goldens` | 0 | n/a | Empty: regenerated output matches the committed golden baseline byte-for-byte. |

## Findings

| ID | Severity | State | Evidence path | Shared source | Release decision |
| --- | --- | --- | --- | --- | --- |
| None recorded | n/a | Four representative core frames opened: quests, reward, goals, and insights. No issue is recorded without opened evidence. | `test/goldens/store_01_quests_1290x2796.png`; `test/goldens/store_02_reward_1290x2796.png`; `test/goldens/store_04_goals_1290x2796.png`; `test/goldens/store_06_insights_1290x2796.png` | n/a | Defer release judgment until the remaining audit tasks complete. |

## Physical-device gates

- Notification permission, timezone handling, scheduling, and delivery on iOS and Android.
- Native share-sheet invocation and completion behavior.
- Image-picker permission and camera/photo-library behavior.
- External directions and support links through the device URL handler.

## Task 2: Accessibility, state, and motion refresh (2026-08-19)

Task 2 was run from the release-final worktree at `d1d6a4ffea1237c6b208c2f7a002155dce0358af`. These are fresh deterministic captures and behavior receipts from the current source; no browser driver or live Places request was used.

| Command | Exit code | Test count when printed | Receipt |
| --- | --- | --- | --- |
| `flutter test --update-goldens --dart-define=CAPTURE_LARGE_TEXT=true test/large_text_accessibility_test.dart` | 0 | 5 | `00:03 +5: All tests passed!` Refreshed `test/goldens/large_text_{calendar_journal,circle_empty,circle_populated,my_space,personalize_dialog,share_dialog,visit_error,visit_loading}_320x568_2x.png`. |
| `flutter test --update-goldens --dart-define=CAPTURE_ACADEMIC=true --dart-define=CAPTURE_ACADEMIC_CONFLICT=true --dart-define=CAPTURE_ACADEMIC_TRANSITION=true --dart-define=CAPTURE_ACADEMIC_STUDY_PLANNER=true --dart-define=CAPTURE_ACADEMIC_OCCURRENCE_ADJUST=true test/academic_calendar_visual_test.dart` | 0 | 16 | `00:04 +16: All tests passed!` Refreshed `test/goldens/academic_*.png` and `test/goldens/daybook_*.png`, including normal and narrow/200% Daybook, directions, failure, conflict, transition, study-planner, and occurrence-adjustment states. |
| `flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/routine_ledger_visual_test.dart` | 0 | 7 | `00:02 +7: All tests passed!` Refreshed `test/goldens/routine_ledger_{morning,night,night_many_collapsed,night_many_expanded,planner}_430x932.png`. |
| `flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/room_guide_test.dart` | 0 | 6 | `00:01 +6: All tests passed!` Refreshed `test/goldens/room_guide_{430x932,scrolled_430x932}.png`. |
| `flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/whats_new_screen_test.dart` | 0 | 7 | `00:01 +7: All tests passed!` Refreshed `design/audits/2026-08-19/release-candidate/whats-new/{whats_new_430x932,whats_new_320x568_text_2x,whats_new_320x568_text_2x_scrolled}.png`. |
| `flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/streak_freeze_visual_test.dart` | 0 | 1 | `00:00 +1: All tests passed!` Refreshed `test/goldens/streak_freeze_{details,sheet}.png`. |
| `flutter test test/reward_motion_accessibility_test.dart test/feedback_motion_accessibility_test.dart test/luxe_motion_test.dart` | 0 | 13 | `00:01 +13: All tests passed!` Behavior receipt: reduced motion keeps the complete reward receipt immediate and parks supporting rooms while lists scroll; deterministic goldens intentionally show parked motion. |
| `flutter test test/text_scaler_accessibility_test.dart test/semantic_action_regression_test.dart test/about_screen_test.dart` | 0 | 11 | `00:01 +11: All tests passed!` Focused text-scaling and semantic-action receipt; no uncaught layout exception was printed. |

The `test/goldens` refresh produced no tracked golden diff, which means those current-source runs matched the committed golden baseline byte-for-byte. The current-date What’s New evidence above is intentionally audit-local rather than part of `test/goldens`; the separate motion and semantic behavior receipts remain evidence for states not represented by a capture.

### Task 2 manual limits

- Normal-motion feel and frame pacing remain physical-device checks; a parked deterministic golden is not evidence of normal-motion quality.
- Software keyboard inset behavior and physical keyboard navigation remain manual device checks.
- VoiceOver/TalkBack traversal order remains a manual assistive-technology check.
- Native external handoff (directions, share sheet, support links) remains a manual device check.
