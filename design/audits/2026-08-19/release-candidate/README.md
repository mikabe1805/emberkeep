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
| `flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true --dart-define=CAPTURE_STORE=true --dart-define=CAPTURE_PLAY=true test/screenshots_test.dart` | Not captured: console detached before Flutter's final footer | 14 scenarios printed before the console detached; no failures printed | Deterministic widget, Apple store, and Google Play golden families. The runner process then exited; required Apple frames were present and decoded. |
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
