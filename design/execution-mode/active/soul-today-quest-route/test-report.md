# Today's three route · local verification · 2026-09-26

Implementation candidate: `codex/soul-today-quest-route`, scoped revision
`commit:a35a41b6c9859e692f5c5ea694938b0e800b76c0`.

## Passed on this machine

- `flutter test --no-pub test/goals_choose_today_test.dart test/goals_today_field_visual_test.dart test/goals_quest_management_test.dart test/quests_daily_field_test.dart test/quest_selection_flow_test.dart`: 59 tests passed. The focused cases exercise an available, completed, and set-aside selected Quest; assert no unintended persistence or general-board callback; and inspect exact-object handoff, duplicate-title arrival, later manual selection, and consumed focus.
- `flutter analyze --no-pub lib/screens/goals.dart lib/screens/quests.dart lib/screens/shell.dart test/goals_choose_today_test.dart test/goals_quest_management_test.dart test/goals_today_field_visual_test.dart`: no issues.
- `flutter test test/goals_shell_route_test.dart`: 1 test passed. It restores local state into the real AppShell, taps the Goals selected row, checks that the same rehydrated Quest instance becomes the first featured Quests card, then returns by the dock and checks that the ordinary commitment-first board is restored.
- `flutter analyze --no-pub test/goals_shell_route_test.dart`: no issues.
- The three selected-field Flutter captures were regenerated from the current implementation at 430 × 932, 320 × 568/1.5× text, and 430 × 932 with a set-aside row. The set-aside semantics node has no tap action, and the available row measures at least 44 px high in the large-text fixture. Fresh same-state before/after pairs were inspected for the first two sizes.
- `flutter build apk --debug --no-pub`: built `app-debug.apk` successfully.

## Device check

The Android emulator accepted an APK install, but a complete app journey was not observed. A direct launch stayed on the splash screen; `flutter run` later reached the VM-service stage, then lost the device. Windows Application Error event 1000 recorded `qemu-system-x86_64-headless.exe` failing with `0xc0000005` on 2026-09-26 at 19:39:31 Eastern. A second headless emulator process also disappeared during the run. This is an emulator-host failure, not evidence that the app route passed or that the app itself crashed.

Physical-phone touch feel, sound, and release acceptance remain unobserved.
