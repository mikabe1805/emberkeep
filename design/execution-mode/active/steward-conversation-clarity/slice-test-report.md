# Steward conversation clarity — current local evidence

Implementation: `worktree:61bacca43134:d2d94cbd3fbd87cd60dbe2a1`.
Revision frozen at `2026-08-30T20:23:04.4950815-04:00`; checks below completed after that freeze.

## Correction

The previous draft looked appealing but failed the owner's first-read comprehension check. The new entrance explicitly says **Talk with the Steward**. The opening identifies the cook, his note, and the disagreement about soup before asking for a response. The unfamiliar ingredient and legal/filing conceit are gone. This remains an optional personal conversation, not app help or a planning action.

The complete [ordered preview](conversation-preview.md) is generated from production nodes visited by the screenshot test. It includes all eight beats of the selected path and each chosen player reply. The corresponding [JSON trace](ordered-preview.json) preserves node identities and screenshot names. This replaces the misleading nonconsecutive preview as the owner-review artifact.

## Current verified results

- Whole-app `flutter analyze --no-pub`: no issues, exit 0.
- `flutter test --no-pub test/steward_encounter_test.dart test/goal_workshop_conversation_test.dart test/steward_memory_test.dart test/goals_quest_management_test.dart`: **65 passed**, exit 0.
- `flutter test --no-pub --update-goldens --dart-define=CAPTURE_GOLDENS=true test/screenshots_test.dart --name 'steward hidden encounter|goals personal index:'`: **7 passed**, exit 0. Regenerated all eight sequential beats, return callback, compact 1.5x/2x top/action pairs, and surrounding Goals/workshop states.

The focused tests cover both opening branches, all three saved stance callbacks, serialized mid-conversation reload, obsolete unpublished draft saves restarting at the new opening, unknown completed current nodes returning to the callback, leaving without consuming a line, replay, same-frame advance protection, unchanged non-Steward state, exact practical goal callback, compact controls and reduced motion.

Normal 430x932 and compact 320x568 renders retain the artwork, opaque dialogue surface and live text. At large text sizes the panel deliberately scrolls; paired top/action renders and widget interaction checks establish that the complete text and all choices are reachable, not simultaneously visible. Desktop screenshots do not establish physical-phone reading comfort, VoiceOver behavior or touch pacing.

## Evidence limits and verdicts

The prior draft's 983-test suite and web build are historical results, **not rerun or claimed current for this correction**. This report covers the changed conversation, entry, save recovery and neighboring goal actions. No upload, store submission or release occurred.

- `code_complete`: pass for this bounded correction.
- `visual_evidence_ready`: pass for current local renders and continuous preview.
- `owner_device_accepted`: pending. First-read comprehension review is not owner taste approval or a physical-device receipt.

Release stays paused. Owner review of the wording and encounter comes before expansion. Signed-device checks, friend/account release checks and new App Store assets remain separate unfinished release work.
