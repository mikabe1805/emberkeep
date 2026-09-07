# Build 41 behavior reliability port

Implemented on the Build 41 foundation without replacing its Focus timer layout.

- OS Reduce Motion now softens composed haptic sequences even when the in-app toggle is off.
- A failed Focus fade retains ownership of the live source, retries that same source after a user gesture, pauses it on background, and prevents normal Room music from overlapping it.
- Gestures inside the timer overlay reach the Focus retry path without adding an interaction sound.
- The Focus music control exposes one actionable accessibility toggle and one accepted selection cue.

Validation:

- `flutter test --no-pub --reporter expanded test/background_music_test.dart test/timer_overlay_music_test.dart test/reward_motion_accessibility_test.dart` — 25 passed.
- `dart analyze lib` — no issues found.
- `git diff --check` — passed before validation.

Deferred intact: Extra Credit remains a future atomic port with its model, engine mutations, schema migration, cloud-save boundary, Journal trace, and owned closing-ledger navigation. None of it was partially copied here.
