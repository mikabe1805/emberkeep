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
| `flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true --dart-define=CAPTURE_STORE=true --dart-define=CAPTURE_PLAY=true test/screenshots_test.dart` | 0 | 24 | `01:00 +24: All tests passed!` Deterministic widget, Apple store, and Google Play golden families refreshed; capture-story hit-test warnings were fatal. |
| Required-frame `Test-Path` check | 0 | n/a | All seven required Apple store frames exist. |
| Required-frame `System.Drawing.Image.FromFile` check | 0 | n/a | All seven required Apple store frames decode at 1290 x 2796. |
| `python -m unittest tool.tests.test_audit_capture_manifest` | 0 | 3 | Manifest coverage, changed-byte detection, and newly cited-image detection passed. |
| `python tool/audit_capture_manifest.py check --readme design/audits/2026-08-19/release-candidate/README.md --manifest design/audits/2026-08-19/release-candidate/capture-manifest.sha256` | 0 | 76 hashes | Every exact PNG/WebP path cited in this audit exists locally and matches the committed SHA-256 receipt. |
| `flutter analyze` | 0 | n/a | `No issues found!` |
| `flutter test` | 0 | 652 | `01:02 +652: All tests passed!` |

The capture directories contain ignored render output, so an empty Git diff is not evidence of equality with a committed golden corpus. The exact comparison recorded here is narrower: after the documented capture commands ran, every image cited as opened evidence received a SHA-256 digest in `design/audits/2026-08-19/release-candidate/capture-manifest.sha256`. `tool/audit_capture_manifest.py check` verifies those current local bytes and exact README coverage; `write` deterministically regenerates the sorted receipt. A clean checkout must first run the documented capture commands to recreate ignored images before checking the receipt. The audit does not claim that uncited or ignored render output is byte-identical to a Git baseline.

## Findings

| ID | Severity | Finding | Opened evidence | Smallest shared source | Release decision |
| --- | --- | --- | --- | --- | --- |
| A-01 | FINISH | About breaks the system's one-luminous-action hierarchy. Android gives the Contact section's `SEND FEEDBACK` and the later Support section's `VISIT KO-FI` the honey-gold primary treatment. On iOS, Ko-fi is absent, but the same scrollable page still has two gold actions: Contact's `SEND FEEDBACK` and the later Support section's `SHARE ROOM OF DAYS`. The actions are legible and reachable, so this is a material consistency finish rather than a broken flow. | Preserved baselines: `design/audits/2026-08-19/release-candidate/about-before/about_screen_android_430x932.png`; `design/audits/2026-08-19/release-candidate/about-before/about_screen_ios_430x932.png` | `lib/screens/about.dart`, specifically `_ContactCard`, `_SupportCard`, and the existing `gold` variant in `_AboutAction` | Accepted FINISH. It does not block release-candidate validation, but should be completed before the release tag using `docs/superpowers/plans/2026-08-19-release-candidate-polish.md`. |
| M-01 | MANUAL | Physical keyboard traversal, software-keyboard/inset behavior, and VoiceOver/TalkBack reading order cannot be certified from deterministic desktop captures. | Task 2 focused accessibility receipts plus the current narrow captures listed below | Native device and assistive-technology environment | Keep as a required device gate. |
| M-02 | MANUAL | Haptics, audio, native share/directions/support handoffs, and normal-motion feel/frame pacing cannot be certified from deterministic desktop captures. | Task 2 motion/semantic receipts plus current share, directions, support, and ritual captures listed below | Native OS services and physical device | Keep as a required device gate. |

The Task 1 provisional `None recorded` row is superseded by this final Task 3 finding set.

## Physical-device gates

- Notification permission, timezone handling, scheduling, and delivery on iOS and Android.
- Native share-sheet invocation and completion behavior.
- Image-picker permission and camera/photo-library behavior.
- External directions and support links through the device URL handler.

## Unverified release gates outside this visual matrix

The visual verdict below is intentionally bounded to the journeys and states named in the opened-evidence lists. These release gates were not exercised by this audit and must not be treated as passed:

- Privacy routes, policy content, and external privacy handoff.
- Password/account recovery, including failure and expired-link behavior.
- In-app and public account deletion, including the seven-day confirmation state.
- Destructive-action confirmation and cancellation states.
- Offline launch, offline local editing, reconnection, and conflict behavior.
- Return visits and shipped-version upgrades, including state preservation and What's New sequencing.
- Representative create, edit, and delete journeys for Quests, Goals, Plans/Daybook, and Journal records.

The file `design/comparisons/2026-08-19/sharing-journal-privacy-pass.webp` has a historical comparison-sheet name. In this audit it supports only the visible sharing and Journal presentation captured on that sheet; it is not evidence that the privacy routes above passed.

## Task 2: Accessibility, state, and motion refresh (2026-08-19)

Task 2 was run from the release-final worktree at `d1d6a4ffea1237c6b208c2f7a002155dce0358af`. These are fresh deterministic captures and behavior receipts from the current source; no browser driver or live Places request was used.

| Command | Exit code | Test count when printed | Receipt |
| --- | --- | --- | --- |
| `flutter test --update-goldens --dart-define=CAPTURE_LARGE_TEXT=true test/large_text_accessibility_test.dart` | 0 | 5 | `00:02 +5: All tests passed!` Refreshed `test/goldens/large_text_{calendar_journal,circle_empty,circle_populated,my_space,personalize_dialog,share_dialog,visit_error,visit_loading}_320x568_2x.png`. |
| `flutter test --update-goldens --dart-define=CAPTURE_ACADEMIC=true --dart-define=CAPTURE_ACADEMIC_CONFLICT=true --dart-define=CAPTURE_ACADEMIC_TRANSITION=true --dart-define=CAPTURE_ACADEMIC_STUDY_PLANNER=true --dart-define=CAPTURE_ACADEMIC_OCCURRENCE_ADJUST=true test/academic_calendar_visual_test.dart` | 0 | 16 | `00:04 +16: All tests passed!` Refreshed `test/goldens/academic_*.png` and `test/goldens/daybook_*.png`, including normal and narrow/200% Daybook, directions, failure, conflict, transition, study-planner, and occurrence-adjustment states. |
| `flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/routine_ledger_visual_test.dart` | 0 | 8 | `00:02 +8: All tests passed!` Registered the asset under the production family `JetBrainsMono`, rejected Ahem-like block coverage, and refreshed the normal and true 320 x 568 / 200% top-and-scrolled routine captures. |
| `flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/room_guide_test.dart` | 0 | 6 | `00:02 +6: All tests passed!` Refreshed normal Room Guide plus true 320 x 568 / 200% top-and-scrolled evidence; the behavior path proves the `Me` door and closing guidance are reachable. |
| `flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/whats_new_screen_test.dart` | 0 | 7 | `00:01 +7: All tests passed!` Refreshed `design/audits/2026-08-19/release-candidate/whats-new/{whats_new_430x932,whats_new_320x568_text_2x,whats_new_320x568_text_2x_scrolled}.png`. |
| `flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/streak_freeze_visual_test.dart` | 0 | 1 | `00:00 +1: All tests passed!` Refreshed `test/goldens/streak_freeze_{details,sheet}.png`. |
| `flutter test test/reward_motion_accessibility_test.dart test/feedback_motion_accessibility_test.dart test/luxe_motion_test.dart` | 0 | 13 | `00:01 +13: All tests passed!` Behavior receipt: reduced motion keeps the complete reward receipt immediate and parks supporting rooms while lists scroll; deterministic goldens intentionally show parked motion. |
| `flutter test test/text_scaler_accessibility_test.dart test/semantic_action_regression_test.dart test/about_screen_test.dart` | 0 | 11 | `00:01 +11: All tests passed!` Focused text-scaling and semantic-action receipt; no uncaught layout exception was printed. |

The ignored `test/goldens` refresh is not compared through Git. Exact current local bytes for every cited image are instead bound by the committed SHA-256 receipt described above. The current-date What's New evidence is intentionally audit-local rather than part of `test/goldens`; the separate motion and semantic behavior receipts remain evidence for states not represented by a capture.

### Task 2 manual limits

- Normal-motion feel and frame pacing remain physical-device checks; a parked deterministic golden is not evidence of normal-motion quality.
- Software keyboard inset behavior and physical keyboard navigation remain manual device checks.
- VoiceOver/TalkBack traversal order remains a manual assistive-technology check.
- Native external handoff (directions, share sheet, support links) remains a manual device check.

## Task 3: Same-input comparison and senior visual audit (2026-08-19)

All twelve supported comparison modes exited 0 from current source and wrote the dated outputs below. No historical input was missing, no substitute was fabricated, and no browser driver or live Places request was used.

| Command | Exit code | Dated output |
| --- | --- | --- |
| `python tool/visual_compare.py review` | 0 | `design/comparisons/2026-08-19/current-system-review.png` |
| `python tool/visual_compare.py review-phone` | 0 | `design/comparisons/2026-08-19/current-system-review-phone.webp` |
| `python tool/visual_compare.py audit-phone` | 0 | `design/comparisons/2026-08-19/first-run-me-journal-audit-phone.webp` |
| `python tool/visual_compare.py system` | 0 | `design/comparisons/2026-08-19/system-target-vs-build.png` |
| `python tool/visual_compare.py focus` | 0 | `design/comparisons/2026-08-19/focused-target-vs-build.png` |
| `python tool/visual_compare.py routine` | 0 | `design/comparisons/2026-08-19/routine-ledger-target-vs-build.png` |
| `python tool/visual_compare.py routine-detail` | 0 | `design/comparisons/2026-08-19/routine-ledger-detail-target-vs-build.png` |
| `python tool/visual_compare.py routine-phone` | 0 | `design/comparisons/2026-08-19/routine-ledger-phone-after.webp` |
| `python tool/visual_compare.py rooms` | 0 | `design/comparisons/2026-08-19/complete-room-target-vs-build.png` |
| `python tool/visual_compare.py rooms-phone` | 0 | `design/comparisons/2026-08-19/complete-room-system-phone.webp` |
| `python tool/visual_compare.py journal-performance-phone` | 0 | `design/comparisons/2026-08-19/journal-and-phone-performance-pass.webp` |
| `python tool/visual_compare.py sharing-journal-phone` | 0 | `design/comparisons/2026-08-19/sharing-journal-privacy-pass.webp` |

Four deterministic evidence pairs were also generated with the explicitly labeled `evidence-pair` mode. They pair two current captures and do not present either side as an approved historical target:

- `design/comparisons/2026-08-19/evidence-routine-night-200.png`
- `design/comparisons/2026-08-19/evidence-routine-morning-200.png`
- `design/comparisons/2026-08-19/evidence-room-guide-200.png`
- `design/comparisons/2026-08-19/evidence-planner-plan-creation.png`

### Opened comparison sheets

Every generated comparison sheet was opened at full-frame scale:

- `design/comparisons/2026-08-19/current-system-review.png`
- `design/comparisons/2026-08-19/current-system-review-phone.webp`
- `design/comparisons/2026-08-19/first-run-me-journal-audit-phone.webp`
- `design/comparisons/2026-08-19/system-target-vs-build.png`
- `design/comparisons/2026-08-19/focused-target-vs-build.png`
- `design/comparisons/2026-08-19/routine-ledger-target-vs-build.png`
- `design/comparisons/2026-08-19/routine-ledger-detail-target-vs-build.png`
- `design/comparisons/2026-08-19/routine-ledger-phone-after.webp`
- `design/comparisons/2026-08-19/complete-room-target-vs-build.png`
- `design/comparisons/2026-08-19/complete-room-system-phone.webp`
- `design/comparisons/2026-08-19/journal-and-phone-performance-pass.webp`
- `design/comparisons/2026-08-19/sharing-journal-privacy-pass.webp`
- `design/comparisons/2026-08-19/evidence-routine-night-200.png`
- `design/comparisons/2026-08-19/evidence-routine-morning-200.png`
- `design/comparisons/2026-08-19/evidence-room-guide-200.png`
- `design/comparisons/2026-08-19/evidence-planner-plan-creation.png`

### Opened individual current captures

The audit also opened the required current and narrow captures individually rather than inferring from filenames or masked sheets:

- Onboarding: `test/goldens/store_audit_00_welcome_1290x2796.png`, `test/goldens/store_audit_01_evening_name_1290x2796.png`, `test/goldens/store_audit_02_day_shape_1290x2796.png`, `test/goldens/store_audit_03_first_board_1290x2796.png`.
- Quests: `test/goldens/store_01_quests_1290x2796.png`, `test/goldens/store_01a_quests_scrolled_1290x2796.png`, `test/goldens/store_02a_stitch_1290x2796.png`, `test/goldens/store_02_reward_1290x2796.png`.
- Goals and Plans/Daybook: `test/goldens/store_04_goals_1290x2796.png`, `test/goldens/store_05_planner_1290x2796.png`, `test/goldens/store_05b_planner_shapes_1290x2796.png`, `test/goldens/academic_schedule_month_430x932.png`, `test/goldens/academic_schedule_day_430x932.png`, `test/goldens/academic_schedule_conflict_430x932.png`, `test/goldens/daybook_general_normal.png`, `test/goldens/daybook_directions_integrated_430x932.png`, `test/goldens/daybook_directions_failure_normal.png`, `test/goldens/academic_occurrence_adjust_430x932.png`.
- Narrow Plans/Daybook: `test/goldens/daybook_general_narrow_200.png`, `test/goldens/daybook_directions_provider_narrow_200.png`, `test/goldens/daybook_directions_failure_narrow_200.png`.
- Narrow 200-percent system: `test/goldens/large_text_calendar_journal_320x568_2x.png`, `test/goldens/large_text_circle_empty_320x568_2x.png`, `test/goldens/large_text_circle_populated_320x568_2x.png`, `test/goldens/large_text_my_space_320x568_2x.png`, `test/goldens/large_text_personalize_dialog_320x568_2x.png`, `test/goldens/large_text_share_dialog_320x568_2x.png`, `test/goldens/large_text_visit_error_320x568_2x.png`, `test/goldens/large_text_visit_loading_320x568_2x.png`.
- What's New: `design/audits/2026-08-19/release-candidate/whats-new/whats_new_430x932.png`, `design/audits/2026-08-19/release-candidate/whats-new/whats_new_320x568_text_2x.png`, `design/audits/2026-08-19/release-candidate/whats-new/whats_new_320x568_text_2x_scrolled.png`.
- About and Room Guide: `test/goldens/about_screen_430x932.png`, `test/goldens/about_screen_ios_430x932.png`, `test/goldens/about_screen_narrow_320x568_2x.png`, `test/goldens/about_screen_narrow_scrolled_320x568_2x.png`, `test/goldens/room_guide_430x932.png`, `test/goldens/room_guide_scrolled_430x932.png`, `test/goldens/room_guide_narrow_320x568_text_2x.png`, `test/goldens/room_guide_narrow_scrolled_320x568_text_2x.png`.
- Rooms/Me/Journal: `test/goldens/store_audit_10_fresh_me_1290x2796.png`, `test/goldens/store_02_keep_1290x2796.png`, `test/goldens/store_audit_12_fresh_journal_1290x2796.png`, `test/goldens/store_07_journal_1290x2796.png`, `test/goldens/store_14c_my_space_arranger_1290x2796.png`.
- Rituals: `test/goldens/routine_ledger_night_430x932.png`, `test/goldens/routine_ledger_night_many_collapsed_430x932.png`, `test/goldens/routine_ledger_night_many_expanded_430x932.png`, `test/goldens/routine_ledger_planner_430x932.png`, `test/goldens/routine_ledger_morning_430x932.png`, `test/goldens/routine_ledger_night_narrow_320x568_text_2x.png`, `test/goldens/routine_ledger_night_narrow_scrolled_320x568_text_2x.png`, `test/goldens/routine_ledger_morning_narrow_320x568_text_2x.png`, `test/goldens/routine_ledger_morning_narrow_scrolled_320x568_text_2x.png`.
- Support/account/streak: `test/goldens/store_02e_share_dialog_1290x2796.png`, `test/goldens/store_02f_support_picker_1290x2796.png`, `test/goldens/store_14d_room_guide_entry_1290x2796.png`, `test/goldens/streak_freeze_sheet.png`.

### Final-review evidence repair

| Command | Exit code | Definitive footer | Output |
| --- | --- | --- | --- |
| `flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/screenshots_test.dart --plain-name "about screen narrow large text"` | 0 | `00:00 +1: All tests passed!` | `test/goldens/about_screen_narrow_320x568_2x.png`; `test/goldens/about_screen_narrow_scrolled_320x568_2x.png` |
| `flutter test test/screenshots_test.dart --plain-name "about screen narrow large text"` | 0 | `00:00 +1: All tests passed!` | With capture disabled, the test still scrolls to and requires both lower About actions to be hit-testable. |
| `flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/room_guide_test.dart --plain-name "guide remains usable on a narrow large-text phone"` | 0 | `00:00 +1: All tests passed!` | `test/goldens/room_guide_narrow_320x568_text_2x.png`; `test/goldens/room_guide_narrow_scrolled_320x568_text_2x.png` |
| `flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/routine_ledger_visual_test.dart` | 0 | `00:02 +8: All tests passed!` | Normal routine captures plus four true 320 x 568 / 200% top-and-scrolled captures. |
| `flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true --dart-define=CAPTURE_STORE=true --dart-define=CAPTURE_PLAY=true test/screenshots_test.dart` | 0 | `01:00 +24: All tests passed!` | Corrected `test/goldens/store_05b_planner_shapes_1290x2796.png`; the story asserts the Plan creation heading before capture and treats all hit-test warnings as fatal. |
| `flutter test test/screenshots_test.dart --plain-name "store screenshot story: real production surfaces"` | 0 | `00:04 +1: All tests passed!` | With capture disabled, keyed `+ PLAN` navigation and the Plan-surface assertion still execute under fatal hit-test warnings. |
| Ten-file `System.Drawing.Image.FromFile` decode/dimension check | 0 | n/a | About, Room Guide, and routine narrow files decode at exactly 320 x 568; planner overview and creation files decode at exactly 1290 x 2796. |

All files above and their four evidence-pair sheets were opened directly. About's reachability assertions now execute even when capture flags are false; at 200% its title wraps intentionally and both lower support actions remain hit-testable. Room Guide's true 200% top state keeps its introduction readable, while the scrolled state reaches the `Me` door and complete closing guidance. Both routine bookends use the registered `JetBrainsMono` family rather than Ahem placeholder blocks; their true 200% states reflow into a longer scroll stage, the compact priority tray inherits the full 200% scaler, and `CLOSE THE DAY` / `OPEN THE DAY` remain readable and hit-testable. The corrected planner evidence visibly contains `START WITH A DAY SHAPE — OR NAME YOUR OWN`; it is no longer a Journal capture mislabeled as planner shapes. The masked `large_text_*` frames were used only to judge geometry and reflow, never to infer copy or type defects.

### Final release decision

Within the exact opened journey matrix listed above, no BLOCKER or HIGH visual defect remains. This verdict covers presentation and tested reachability only for those named onboarding, Quests, Goals, Daybook, rooms, Journal, ritual, overlay, About, Room Guide, and accessibility captures. It does not certify the unverified release gates listed above, native/device behavior, external service handoffs, or uncaptured lifecycle journeys. Historical targets with mature room state were treated as state context rather than current-build defects. `A-01` remains an accepted FINISH with an executable one-task plan and should be completed before the release tag. Release-candidate validation may continue only with every unverified and physical-device gate held open until separately evidenced.
