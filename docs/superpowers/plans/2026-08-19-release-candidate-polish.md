# Release Candidate About Hierarchy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restore the About screen to one honey-gold primary action on both Android and iOS while preserving every existing support and sharing path.

**Architecture:** Keep the current About screen structure, copy, GlassPanel material, faceted action component, and platform policy. `SEND FEEDBACK` remains the single honey-gold primary action; Ko-fi and share stay fully reachable as the existing quiet-glass secondary action variant. No new component or visual language is introduced.

**Tech Stack:** Flutter, Dart, `flutter_test`, deterministic widget goldens

**Spec:** `design/audits/2026-08-19/release-candidate/README.md` finding `A-01`

## Global Constraints

- Preserve the candlelit desk and folio system in `DESIGN-BIBLE.md`.
- Keep Ko-fi hidden on iOS and retain all current external-action behavior.
- Do not call live support, share, or billing services from tests.
- Preserve the audit-local About files as immutable BEFORE evidence. Refresh the tracked test goldens only as AFTER evidence, then create and inspect combined before/after comparison sheets before accepting the correction.

---

### Task 1: Give About one luminous action across platform variants

**Files:**

- Modify: `lib/screens/about.dart:319-355`
- Modify: `test/about_screen_test.dart:1-104`
- Verify/refresh: `test/goldens/about_screen_430x932.png`
- Verify/refresh: `test/goldens/about_screen_ios_430x932.png`
- Create: `design/comparisons/2026-08-19/probe-about-android-before-after.png`
- Create: `design/comparisons/2026-08-19/probe-about-ios-before-after.png`

**Before evidence:**

- `design/audits/2026-08-19/release-candidate/about-before/about_screen_android_430x932.png` shows Android's Contact action (`SEND FEEDBACK`) and later Support action (`VISIT KO-FI`) both in honey gold on the same scrollable page.
- `design/audits/2026-08-19/release-candidate/about-before/about_screen_ios_430x932.png` shows iOS's two gold actions across the same scrollable page: Contact's `SEND FEEDBACK` and the later Support section's `SHARE ROOM OF DAYS`. Ko-fi is absent on iOS as intended.

Do not overwrite or regenerate either audit-local BEFORE file.

**Step 1: Add a failing hierarchy regression test**

Import the design tokens and add a helper that checks whether the `Container` below a keyed action owns the honey gradient:

```dart
import 'package:emberkeep/tokens.dart';

bool usesHoneyGradient(WidgetTester tester, Key key) {
  final containers = tester.widgetList<Container>(
    find.descendant(of: find.byKey(key), matching: find.byType(Container)),
  );
  return containers.any(
    (container) =>
        container.decoration is ShapeDecoration &&
        (container.decoration! as ShapeDecoration).gradient ==
            Palette.honeyGradient,
  );
}
```

Extend the existing Android and iOS tests so they express the one-primary-action invariant:

```dart
expect(
  usesHoneyGradient(tester, const ValueKey('about-send-feedback')),
  isTrue,
);
expect(
  usesHoneyGradient(tester, const ValueKey('about-send-coffee')),
  isFalse,
);
expect(
  usesHoneyGradient(tester, const ValueKey('about-share-app')),
  isFalse,
);
```

For iOS, omit the absent Ko-fi assertion and assert feedback is gold while share is not.

**Step 2: Run the focused test and verify the new invariant fails**

Run: `flutter test test/about_screen_test.dart`

Expected: the Android test reports Ko-fi still uses `Palette.honeyGradient`, and the iOS test reports share still uses it.

**Step 3: Make the smallest visual correction**

In `_SupportCard`, use the existing secondary `_AboutAction` variant for both support actions:

```dart
_AboutAction(
  key: const ValueKey('about-send-coffee'),
  label: 'VISIT KO-FI',
  icon: Icons.local_cafe_outlined,
  onTap: onCoffee,
),

_AboutAction(
  key: const ValueKey('about-share-app'),
  label: 'SHARE ROOM OF DAYS',
  icon: Icons.ios_share_rounded,
  onTap: onShare,
),
```

Do not change `_ContactCard`; `SEND FEEDBACK` remains `gold: true`.

**Step 4: Verify behavior and large-text safety**

Run: `flutter test test/about_screen_test.dart test/text_scaler_accessibility_test.dart test/semantic_action_regression_test.dart`

Expected: all tests pass with no uncaught exception; Android still exposes Ko-fi, iOS still omits it, and feedback/share targets remain present.

**Step 5: Refresh and inspect the affected visual evidence**

Run: `flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/screenshots_test.dart --plain-name "about screen"`

The refreshed tracked files are the AFTER evidence:

- Android AFTER: `test/goldens/about_screen_430x932.png`
- iOS AFTER: `test/goldens/about_screen_ios_430x932.png`

Create same-input combined comparison sheets:

```powershell
python tool/visual_compare.py probe "About Android before after" design/audits/2026-08-19/release-candidate/about-before/about_screen_android_430x932.png test/goldens/about_screen_430x932.png
python tool/visual_compare.py probe "About iOS before after" design/audits/2026-08-19/release-candidate/about-before/about_screen_ios_430x932.png test/goldens/about_screen_ios_430x932.png
```

Open and inspect both outputs before judging:

- `design/comparisons/2026-08-19/probe-about-android-before-after.png`
- `design/comparisons/2026-08-19/probe-about-ios-before-after.png`

Expected: each platform shows exactly one honey-gold action (`SEND FEEDBACK`); Ko-fi/share remain legible, full-width, and reachable as quiet-glass actions with unchanged spacing and content.

**Step 6: Commit the focused correction**

```powershell
git add -- lib/screens/about.dart test/about_screen_test.dart test/goldens/about_screen_430x932.png test/goldens/about_screen_ios_430x932.png design/comparisons/2026-08-19/probe-about-android-before-after.png design/comparisons/2026-08-19/probe-about-ios-before-after.png
git diff --cached --check
git commit -m "fix: restore About action hierarchy"
```
