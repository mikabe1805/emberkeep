# Goals return polish verification — 2026-09-27

## Final bound revision and render evidence

- Scoped revision: `commit:725346cdad1ba8a6b56a66cc94676a8e792fe475`.
- Opened same-state comparison:
  `design/comparisons/2026-09-27/evidence-goals-return-concept-to-build.png`
  (SHA-256 `940cfe0eba7a16a72196e0f8c9ce89cc7575fd6d43713c7069dc5274c3179647`).
- Opened final active-return golden:
  `test/goldens/goals_personal_index_active_430x932.png`
  (SHA-256 `0b0f1a97f2e9571bed4c959540f1100bc1504251bdbe9e4e90e41ff281b1d721`).

## Virtual Android emulator walkthrough

The installed Android **emulator** captures below are virtual-device evidence,
not owner or physical-phone acceptance:

- Active first frame: `android-emulator-goals-active-final.png`
  (SHA-256 `6bb693fe1eb039853bac6b2f4eb3221883d29dc7a6d193f0d688d73c2f0efcc9`)
  shows Today’s three and Review goal above the bottom navigation.
- Exact Quest arrival: `android-emulator-goals-open-quest-final.png`
  (SHA-256 `9e25a137516ef4e0baa140aa3b8ec57a163a48e6643beefd6acfde55e62b38f4`)
  shows the same Quest on Quests.
- Scrolled folio: `android-emulator-goals-scrolled-final.png`
  (SHA-256 `571b116f82b20df478a20a61b7d2c88300075e868c43cbedc5fc74b7ac742a0c`).
- Support-expanded folio: `android-emulator-goals-support-final.png`
  (SHA-256 `5425d84758480ba07e2c8168b8dc073b3edba45c5c4db0c2bcbd8c92395f0ee4`).

The active screenshot test now simulates a 120px shell bar and asserts that
Review goal remains above it; that test passed. These captures demonstrate the
post-fix layout using actual available page height and a tighter divider. They
cannot establish physical-phone thumb reach, scroll cadence, haptics, sound,
or OLED value separation.

## Independent visual critique

**Reviewer:** Codex workflow audit, not the implementation author.

**Result:** pass.

The final comparison retains the study's useful promise: the active commitment
rests in a warm, continuous room with the lit arch still visible, while one dark
book-cloth folio carries the current Goal and exact Quest. The Flutter version
does not claim the study's centered foreground desk exists in canonical runtime
art; its relationship is deliberately adapted rather than copied. `Open Quest`
is the only luminous action. The support-open and narrow enlarged-text goldens
keep support inside the same folio and preserve the reading order instead of
creating a second card stack. No material visual finding blocks this bounded
slice.

## Deterministic checks

Two full-suite failures found after the previous evidence update were repaired:
the active Goal title no longer sets a maximum scale factor, and the
room-travel test now expects the two shared room plates. Seven selected
Goals/room-travel fixtures were recaptured:

- `goals_personal_index_active_430x932.png` — SHA-256
  `0b0f1a97f2e9571bed4c959540f1100bc1504251bdbe9e4e90e41ff281b1d721`
- `goals_personal_index_support_open_430x932.png` — SHA-256
  `b728de702fb5eefd766f38b7b82ead9ac4eef23997a67097a6bdb27ea659acd4`
- `goal_room_travel_01_departure_430x932.png` — SHA-256
  `343486225474a1083ebef8ed8b395419d8cce80767180ffe5b0869dbf51ca64d`
- `goal_room_travel_02_bridge_430x932.png` — SHA-256
  `18a682a4c7753e0f62ffc97bdd8a9adda93a39c25bc5ac733d72cab51d86e336`
- `goal_room_travel_03_crossing_430x932.png` — SHA-256
  `94a9649ac94b1dd192eab9b94e568a4fa021d42213792c4a4a033fe734196906`
- `goal_room_travel_04_arrival_430x932.png` — SHA-256
  `791c06bc1a02326f40a477d76990155de395984360d24eb23810e355ac333319`
- `goal_room_travel_05_quest_arrival_430x932.png` — SHA-256
  `40180822bcf9c69cd7ef753bb560654c6045af8013bbefc944a9176afd625e0a`

The focused screenshot selection passed **6/6**, including the 120px
simulated shell-bar assertion. The selected route/management, choose-today,
shell, art-fallback, and workshop checks passed **49/49**. The complete suite
passed **1,201** with `flutter test --no-pub`. The feature-on discovery packet
passed **28**, with **1 expected skip**.

The following scoped analyzer command was run in this verification pass:

```powershell
flutter analyze --no-pub
```

Result: **No issues found**.

These checks cover the active and enlarged-text visual fixtures, exact Quest
handoff, room-travel sequence, today-field authority, recovery/return, still
Reduced Motion source, shell route, missing-art fallback, workshop boundaries,
and feature-on discovery. Release-build evidence is recorded separately below.
These checks do not replace owner or physical-device judgment.

## Release-build boundary

`flutter build web --release` passed for this revision.

`flutter build apk --release --no-pub` stopped in Gradle before compilation:
`android/key.properties` and the private upload keystore are absent, so
`Release signing is not configured`. This is a signing-input block, not an APK
compile pass or failure. No keystore was requested. iOS internal signing is a
separate Codemagic concern and is not established by either Android result.

As a local mitigation, `flutter build apk --debug --no-pub` passed and produced
`build/app/outputs/flutter-apk/app-debug.apk`. This confirms a local Android
debug package can be produced; it does not substitute for a signed release APK
or any upload, processing, owner, or physical-device gate.

## Remaining gates

The owner must still review the installed build on a physical phone. A physical
phone must still verify thumb hierarchy, scroll cadence, haptics, sound, and
OLED value separation in normal and Reduced Motion. The Android emulator
walkthrough is virtual evidence only; no owner or physical-device acceptance
is claimed here.
