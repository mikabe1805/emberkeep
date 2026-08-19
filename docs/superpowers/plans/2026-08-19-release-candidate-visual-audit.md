# Room of Days Release Candidate Visual Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture and inspect a fresh, deterministic release-candidate baseline, then publish an evidence-backed audit whose blocker and high-priority findings can be turned into an exact correction plan.

**Architecture:** Existing Flutter golden stories remain the capture source because they already preload production art and deterministic state. The audit combines the main 430 x 932 story, focused 320 x 568 / 200-percent-text states, Daybook states, and Reduced Motion behavior tests, then builds same-input comparison sheets with the repository's visual comparison tool. This plan produces evidence and findings only; it does not guess at visual fixes before those findings exist.

**Tech Stack:** Flutter widget/golden tests, repository visual comparison tooling, Markdown audit evidence, local image inspection.

**Spec:** `docs/superpowers/specs/2026-08-19-release-candidate-and-icon-design.md`

## Global Constraints

- Work from `C:\Users\mikus\Downloads\experimentProject\app`.
- Preserve the candlelit desk and folio system in `DESIGN-BIBLE.md`; this audit does not introduce a new style.
- Use fresh captures from the current source. Historical images are context, not final evidence.
- Do not use Playwright or another browser driver without separate owner permission.
- Do not treat screenshots as QA by themselves; inspect same-state comparisons and run the corresponding behavior tests.
- Keep Google Places disabled and do not call live billable APIs.
- Do not modify unrelated existing dirty files or untracked design evidence.
- Physical keyboard, inset, haptic, audio, external-app handoff, and frame-pacing checks remain manual device gates.

---

### Task 1: Freeze the baseline identity and refresh the main production story

**Files:**
- Create: `design/audits/2026-08-19/release-candidate/README.md`
- Refresh through the existing harness: `test/goldens/store_*.png`
- Refresh through the existing harness: `test/goldens/play_*.png`
- Source: `test/screenshots_test.dart`

**Interfaces:**
- Consumes: current Git commit, `pubspec.yaml`, the deterministic fixtures in `test/screenshots_test.dart`.
- Produces: a dated capture manifest and fresh 430 x 932 / DPR 3 Apple images plus 432 x 768 / DPR 2.5 Google Play images.

- [ ] **Step 1: Record the exact baseline before regenerating images**

Run:

```powershell
git rev-parse HEAD
git status --short
rg -n "^version:" pubspec.yaml
```

Expected: the commit includes the approved release-candidate spec, the version is `1.0.3+21`, and the status output is saved for ownership comparison rather than cleaned or reset.

- [ ] **Step 2: Run the complete deterministic production screenshot story**

Run:

```powershell
flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true --dart-define=CAPTURE_STORE=true --dart-define=CAPTURE_PLAY=true test/screenshots_test.dart
```

Expected: PASS. The run refreshes the main journey, onboarding, room states, completion/reward states, Goals, Plans, Journal, Me, daily bookends, Room Guide entry, and store-sized output images in `test/goldens/`.

- [ ] **Step 3: Confirm the seven core release frames exist and decode**

Run:

```powershell
$required = @(
  'test/goldens/store_01_quests_1290x2796.png',
  'test/goldens/store_01a_quests_scrolled_1290x2796.png',
  'test/goldens/store_02_reward_1290x2796.png',
  'test/goldens/store_02_keep_1290x2796.png',
  'test/goldens/store_04_goals_1290x2796.png',
  'test/goldens/store_05_planner_1290x2796.png',
  'test/goldens/store_06_insights_1290x2796.png'
)
$required | ForEach-Object { if (-not (Test-Path -LiteralPath $_)) { throw "Missing $_" } }
```

Expected: no missing-file error.

- [ ] **Step 4: Create the baseline manifest with observed facts**

Use `apply_patch` to create `design/audits/2026-08-19/release-candidate/README.md`. It must record:

```markdown
# Room of Days Release Candidate Visual Audit

- Capture date: 2026-08-19
- Source commit: write the exact 40-character output from `git rev-parse HEAD`
- Source version: 1.0.3+21
- Main viewport: 430 x 932 logical pixels at DPR 3
- Narrow viewport: 320 x 568 logical pixels at DPR 1 and 200% text
- Motion evidence: deterministic Reduced Motion captures plus focused normal/reduced behavior tests
- Places state: protected provider search disabled; manual locations available

## Commands and receipts

Record each command, its exit code, test count when printed, and output family.

## Findings

Use one row per observed issue: ID, severity, state, evidence path, shared source, and release decision. Do not record an issue without opening its evidence.

## Physical-device gates

List only the native behaviors that the desktop evidence cannot certify.
```

Do not write a clean bill of health before the images are opened.

- [ ] **Step 5: Inspect the baseline diff without staging unrelated files**

Run:

```powershell
git status --short
git diff --stat -- test/goldens
```

Expected: any changed golden is attributable to the fresh capture. Existing unrelated dirty paths remain untouched.

### Task 2: Refresh narrow, large-text, Daybook, and Reduced Motion evidence

**Files:**
- Refresh: `test/goldens/large_text_*_320x568_2x.png`
- Refresh: `test/goldens/daybook_*.png`
- Refresh: `test/goldens/academic_*.png`
- Refresh: `test/goldens/routine_ledger_*.png`
- Refresh: `test/goldens/room_guide_*.png`
- Refresh: `test/goldens/whats_new_*.png` when the test exposes capture output
- Modify: `design/audits/2026-08-19/release-candidate/README.md`

**Interfaces:**
- Consumes: Task 1 baseline manifest and the existing deterministic fixtures.
- Produces: the release-spec accessibility/state matrix and motion receipts used by Task 3.

- [ ] **Step 1: Refresh the 320 x 568 / 200-percent-text matrix**

Run:

```powershell
flutter test --update-goldens --dart-define=CAPTURE_LARGE_TEXT=true test/large_text_accessibility_test.dart
```

Expected: PASS with current My Space, dialog, Circle, loading/error, sharing, and calendar/journal captures under `test/goldens/large_text_*_320x568_2x.png`.

- [ ] **Step 2: Refresh general and academic Daybook matrices**

Run:

```powershell
flutter test --update-goldens --dart-define=CAPTURE_ACADEMIC=true --dart-define=CAPTURE_ACADEMIC_CONFLICT=true --dart-define=CAPTURE_ACADEMIC_TRANSITION=true --dart-define=CAPTURE_ACADEMIC_STUDY_PLANNER=true --dart-define=CAPTURE_ACADEMIC_OCCURRENCE_ADJUST=true test/academic_calendar_visual_test.dart
```

Expected: PASS with 430 x 932 normal and 320 x 568 / 200-percent-text general Daybook, directions, failure, month/day, conflict, study, transition, and occurrence-adjustment evidence.

- [ ] **Step 3: Refresh supporting daily-loop evidence**

Run:

```powershell
flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/routine_ledger_visual_test.dart
flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/room_guide_test.dart
flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/whats_new_screen_test.dart
flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/streak_freeze_visual_test.dart
```

Expected: all four commands PASS. If a test has behavior coverage but no capture flag, record that as a behavior receipt rather than inventing an image.

- [ ] **Step 4: Verify Reduced Motion behavior separately**

Run:

```powershell
flutter test test/reward_motion_accessibility_test.dart test/feedback_motion_accessibility_test.dart test/luxe_motion_test.dart
```

Expected: PASS. Record that deterministic goldens park motion, while these tests prove state changes do not disappear when ornamental motion is removed.

- [ ] **Step 5: Run the focused no-overflow accessibility checks**

Run:

```powershell
flutter test test/text_scaler_accessibility_test.dart test/semantic_action_regression_test.dart test/about_screen_test.dart
```

Expected: PASS with no uncaught layout exception.

- [ ] **Step 6: Add exact receipts to the audit manifest**

Use `apply_patch` to add each command's exit result and the paths it refreshed. Explicitly note that normal-motion feel, software keyboard insets, VoiceOver traversal order, and native external handoff are not certified by these tests.

### Task 3: Build comparisons, inspect every release surface, and issue the audit

**Files:**
- Create through existing tooling: `design/comparisons/2026-08-19/*`
- Modify: `design/audits/2026-08-19/release-candidate/README.md`
- Create only if findings require product changes: `docs/superpowers/plans/2026-08-19-release-candidate-polish.md`

**Interfaces:**
- Consumes: Tasks 1-2 captures and `design/visual-targets/2026-07-30/` approved sources.
- Produces: combined comparison inputs, a severity-ranked audit, and an exact correction plan when release-relevant findings exist.

- [ ] **Step 1: Generate the existing comparison families**

Run:

```powershell
python tool/visual_compare.py review
python tool/visual_compare.py review-phone
python tool/visual_compare.py audit-phone
python tool/visual_compare.py system
python tool/visual_compare.py focus
python tool/visual_compare.py routine
python tool/visual_compare.py routine-detail
python tool/visual_compare.py routine-phone
python tool/visual_compare.py rooms
python tool/visual_compare.py rooms-phone
python tool/visual_compare.py journal-performance-phone
python tool/visual_compare.py sharing-journal-phone
```

Expected: each supported mode exits 0 and writes its dated output beneath `design/comparisons/2026-08-19/`. If a mode rejects a missing historical input, record the exact missing input and continue with the modes whose sources exist; do not fabricate a substitute.

- [ ] **Step 2: Open same-input comparisons at full-frame scale**

Inspect the generated review/system sheets and the individual current captures for:

- onboarding and first-board comprehension;
- Quests resting, scrolled, completion, undo, and reward;
- Goals hierarchy and empty/long content;
- Plans/Daybook month, day, conflict, general item, failure, and directions;
- Rooms/Me/Journal, including empty and populated states;
- Morning Flow, Night Flow, Room Guide, What's New, About, and support/account entry points.

Every finding must cite a concrete image path and the likely shared source. Do not infer a defect from a filename or a masked diff alone.

- [ ] **Step 3: Inspect narrow and 200-percent-text captures individually**

Open the `large_text_*`, `daybook_*_narrow_200`, and narrow About/Room Guide/What's New evidence. Check clipping, reading order, target reachability, system inset clearance, duplicated emphasis, and content that only survives because text was shrunk.

- [ ] **Step 4: Classify findings using the release rubric**

Use exactly these severities in the audit:

```text
BLOCKER — data loss, crash, dead end, inaccessible essential action, severe overflow, or misleading release/support state
HIGH — confusing hierarchy, broken primary flow, inconsistent response, unreadable content, or repeated shared-system defect
FINISH — spacing, copy, motion, iconography, or surface consistency that materially improves the whole
MANUAL — a native/device/service condition desktop evidence cannot certify
```

For each non-manual finding, name the smallest shared source likely to own it. If no release-relevant finding exists, say so directly and retain the evidence.

- [ ] **Step 5: Write the correction plan only from observed findings**

If the audit contains BLOCKER, HIGH, or accepted FINISH work, create `docs/superpowers/plans/2026-08-19-release-candidate-polish.md` with the writing-plans skill. Each task must name exact files, tests, before/after evidence, and a focused commit. Do not add speculative cleanup.

- [ ] **Step 6: Commit the audit evidence separately**

Run:

```powershell
git add -- design/audits/2026-08-19/release-candidate design/comparisons/2026-08-19 docs/superpowers/plans/2026-08-19-release-candidate-polish.md
git diff --cached --check
git diff --cached --name-only
git commit -m "docs: audit final Room of Days release candidate"
```

If no correction plan was needed, omit that absent path from `git add`. Expected: the commit contains only the new dated audit/comparison evidence and, when present, its finding-derived plan.
