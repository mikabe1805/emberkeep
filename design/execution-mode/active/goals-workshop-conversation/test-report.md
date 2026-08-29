# Goals Workshop conversation verification

Captured: 2026-08-29T13:13:13-04:00

Revision: `worktree:0e666f2639fc:9639cd674f8c34bd0189b17b`

## Automated checks

- `flutter test --no-pub test/goal_workshop_conversation_test.dart` — 3 passed.
- Focused Goal/Workshop command across eight test files — 72 passed.
- `flutter analyze --no-pub` — no issues, 49.9 seconds.
- `flutter test --no-pub` — 857 passed, 90 seconds.
- Both targeted screenshot stories with `CAPTURE_GOLDENS=true` — passed.
- `dart run tool/verify_store_submission.dart --ios-only` — passed for the current `1.0.4+25` packet.
- `flutter build web --release --wasm --no-pub` — passed, 89.3 seconds.
- `flutter build apk --release --no-pub` — passed, 107.2 seconds; 85.6 MB APK.
- `git diff --check` on the slice — passed, with only the existing CRLF conversion warning.

## Contract observations

- Context priority is cut waiting, needs route, Quest on board, route complete, then empty bench.
- All three prompts are optional widget state.
- Goal and Quest JSON snapshots are unchanged after all dialogue interactions.
- Route, focus, and new-goal callbacks are not invoked by dialogue.
- The response is a screen-reader live region.
- At 320 x 568 and 1.5x text, all three prompts, the selected answer, `Routes`, and `New goal` are visible and hit-testable without overflow.

## Rendered artifacts

- `test/goldens/goals_workshop_home_430x932.png` — `bc35ab652df4569404e435fcc57a27a2b17f939b9c61a45305a477f94e923653`
- `test/goldens/goals_workshop_conversation_430x932.png` — `4ac4d64662fcfb830016ca01cf5a6e9b0f47fa2a7ff6e3828ac6d397711eece6`
- `test/goldens/goals_workshop_home_narrow_large_text_320x568.png` — `36c2d99e8cab4dc111e32c69b158e7b4904bc7514b1dc796ced0424403d6c636`
- `test/goldens/goals_workshop_conversation_narrow_large_text_320x568.png` — `d26e8c80e4906136cbeffc0a30a18b7253431b2f5c0cfdc19bb7d421510a8e1f`
- `design/comparisons/2026-08-29/goals-workshop-return-phone.webp` — `8f1dfd4c619186f79e66e0bc90cc97f678b72ba1115e3633a2cb9d219a736cc3`

## Independent critique

Terra reviewer `workshop_slice_critique` did not author the implementation. It inspected the production code, tests, four fresh captures, and contact sheet. Its first review identified one compact auto-scroll wayfinding risk. After the register height and compact bottom breathing room were corrected and evidence regenerated, it returned `PASS visual_evidence_ready`: the optional-routes context, all prompts, selected answer, and both exits are simultaneously visible.

## Remaining owner/device gate

Only the exact installed iPhone candidate can establish VoiceOver order, OLED separation, thumb reach, haptics, scroll feel, Reduced Motion feel, and whether the added character voice still feels like the Workshop rather than a chat system.
