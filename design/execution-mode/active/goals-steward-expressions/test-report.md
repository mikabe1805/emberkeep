# Layered steward v2 verification

Captured: 2026-08-29 EDT

- `flutter analyze`
  - Passed over the complete app with no issues.
- `flutter test test/goal_steward_test.dart test/goals_quest_management_test.dart`
  - Passed: 42
  - Failed: 0
- `flutter test test/luxe_motion_test.dart test/goal_steward_test.dart`
  - Passed: 9
  - Failed: 0
  - Includes the shared motion filter, immediate Reduced Motion parking, three
    steward plane distances, and the rapid-disposal startup guard.
- `flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/screenshots_test.dart --plain-name "goals personal index: active and quick create"`
  - Passed: 1
  - Failed: 0
  - Re-rendered the production Goals index, Workshop register, and exact owned
    Quest at 430 x 932.
- `flutter test tool/goals_opening_motion_capture_test.dart`
  - Passed: 1
  - Failed: 0
  - Captured 231 deterministic production frames through the desk retreat,
    threshold crossing, and ready-state Workshop arrival.
- `python tool/execution_gate.py check design/execution-mode/active/goals-steward-expressions --phase direction`
  - Passed after the direct owner corrections superseded the v1 expression
    evidence.

The focused tests cover all five situation-to-pose mappings, two shared room
planes plus five unique transparent sprites, register priority, note semantics,
the ready and acknowledging selected-bench states, three distinct parallax
travel distances, Reduced Motion holding every plane still, exactly one
state-aware semantic image description, and the unchanged exact-Quest, edit,
cancel, repair, and rapid-repeat behavior.

The live production evidence also caught and corrected one source-sheet miss:
the first ready pose's offered card fell behind the real folio. The final ready
sprite raises the same blank card into the visible chest-level band, keeps both
real pencils visible, and passes the rerun opening capture.

The running web preview at port 7357 was hot-restarted after the final asset and
code were in place. No pose path constructs or accepts a Quest, and no delay was
introduced merely to show a reaction.
