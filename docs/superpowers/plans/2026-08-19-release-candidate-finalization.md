# Room of Days Release Candidate Finalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the approved visual, support, and icon work into one reproducible `1.0.4+22` candidate, verify every local gate, and prepare an evidence packet for the owner-controlled TestFlight and App Store release.

**Architecture:** Product changes land before the version bump. One release-prep commit then aligns `pubspec.yaml`, immutable What's New identity, store assets, and the eventual signed Android candidate record. Local automation proves source/build consistency; Codemagic produces the signed iOS artifact and physical devices prove native behavior. Store submission and availability remain an explicit final external action.

**Tech Stack:** Flutter/Dart, Flutter golden and widget tests, Android Gradle release builds, Codemagic iOS/TestFlight workflow, Firebase Hosting release preparation, repository verification tools, SHA-256 artifact records.

**Spec:** `docs/superpowers/specs/2026-08-19-release-candidate-and-icon-design.md`

## Global Constraints

- Execute this plan only after the visual audit, accepted polish fixes, support work, and icon selection/propagation are complete.
- The next planned identity is `1.0.4+22` because `1.0.3+21` already exists in TestFlight. If App Store Connect reports Build 22 is also used, stop before editing release identity and revise the plan to the next unused build.
- Preserve package/bundle ID `com.mikabe.emberkeep` and Firebase project `emberkeep-5b33b`.
- Keep protected Google Places disabled; manual locations and directions remain available.
- Do not edit `release-candidate.json` to look current before real signed Android artifacts and hashes exist.
- Never claim TestFlight, physical-device acceptance, public catalog visibility, hosted support delivery, or App Store publication from local tests.
- Do not submit, release, deploy, or send mail until the named owner gate authorizes that external mutation.
- Preserve all existing saves, stable Daybook occurrence IDs, cloud data, preferences, and Room Notes handoff identifiers during upgrade testing.

---

### Task 1: Advance one coherent release identity

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/content/release_notes.dart`
- Modify: `test/release_notes_test.dart`
- Modify: `RELEASE-CHECKLIST.md`
- Modify: `DEVICE-ACCEPTANCE-RUNBOOK.md`

**Interfaces:**
- Consumes: completed product commits and the verified fact that Build 21 exists in TestFlight.
- Produces: `1.0.4+22` as the single source release identity and current What's New record.

- [ ] **Step 1: Write the failing release-identity test**

Change the current assertions in `test/release_notes_test.dart` to:

```dart
expect(currentRoomReleaseNotes.id, '1.0.4+22');
expect(currentRoomReleaseNotes.title, 'Plans are for your whole life.');
expect(pubspec, contains('version: ${currentRoomReleaseNotes.id}'));
```

Keep the current Daybook introduction and three factual highlights because Version 1.0 / Build 19 is the approved production baseline and those features are new to that audience.

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```powershell
flutter test test/release_notes_test.dart
```

Expected: FAIL because source identity remains `1.0.3+21`.

- [ ] **Step 3: Update the source version and immutable release record**

Change:

```yaml
version: 1.0.4+22
```

Change only the newest `RoomReleaseNotes` record identity/label:

```dart
id: '1.0.4+22',
versionLabel: 'VERSION 1.0.4 · BUILD 22',
```

Keep the older `1.0.3+21`, `1.0.2+20`, and `1.0.1+13` records in newest-first archive order. Update the checklist and device runbook headers/current-candidate references to `1.0.4+22`; historical evidence sections retain their original build numbers.

- [ ] **Step 4: Run the release-note tests and verify they pass**

Run:

```powershell
dart format lib/content/release_notes.dart test/release_notes_test.dart
flutter test test/release_notes_test.dart test/whats_new_screen_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit the atomic identity bump**

Run:

```powershell
git add -- pubspec.yaml lib/content/release_notes.dart test/release_notes_test.dart RELEASE-CHECKLIST.md DEVICE-ACCEPTANCE-RUNBOOK.md
git diff --cached --check
git commit -m "chore: prepare Room of Days 1.0.4 build 22"
```

### Task 2: Produce the complete local verification receipt

**Files:**
- Create: `release-evidence/1.0.4+22/local-verification.md`
- Do not modify: product source during the receipt run.

**Interfaces:**
- Consumes: the committed `1.0.4+22` source tree.
- Produces: complete analyzer/test/build receipts tied to one commit.

- [ ] **Step 1: Record source and toolchain identity**

Run and record the exact output:

```powershell
git rev-parse HEAD
git status --short
flutter --version
dart --version
java -version
```

Expected: product source is committed; pre-existing unrelated working-tree paths are listed and excluded from release staging.

- [ ] **Step 2: Run static analysis and the complete Flutter suite**

Run each command to completion:

```powershell
flutter analyze
flutter test
```

Expected: `flutter analyze` reports no issues and `flutter test` prints its final all-tests-passed receipt. A truncated prefix of passing tests is not acceptance.

- [ ] **Step 3: Run release-specific verifiers that do not require new artifacts**

Run:

```powershell
flutter test test/release_notes_test.dart test/release_native_privacy_test.dart test/production_smoke_cleanup_test.dart test/golden_platform_policy_test.dart
dart run tool/audit_pub_dependencies.dart
```

Expected: PASS. `verify_store_submission.dart` is intentionally deferred until Task 4 creates the signed Android artifact record.

- [ ] **Step 4: Build and prepare the release web bundle**

Run:

```powershell
flutter build web --release --wasm
dart run tool/prepare_web_offline.dart
```

Expected: both commands exit 0 and `build/web/version.json` reports Version `1.0.4`, Build `22`.

- [ ] **Step 5: Write the local verification receipt**

Use `apply_patch` to create `release-evidence/1.0.4+22/local-verification.md` with the commit, toolchain versions, every command, exit code, final test count, build output path, and known manual gates. Do not include secrets, signing material, or optimistic completion for later tasks.

### Task 3: Refresh and export store screenshots from the accepted UI

**Files:**
- Refresh: `test/goldens/store_*.png`
- Refresh: `test/goldens/play_*.png`
- Refresh through exporter: `store-assets/screenshots/app-store/*.png`
- Refresh through exporter: `store-assets/screenshots/google-play/*.png`
- Modify: `release-evidence/1.0.4+22/local-verification.md`

**Interfaces:**
- Consumes: accepted visual-audit source and selected icon-independent store story.
- Produces: five RGB App Store screenshots and five RGB Google Play screenshots that match the candidate UI.

- [ ] **Step 1: Regenerate the deterministic store story**

Run:

```powershell
flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true --dart-define=CAPTURE_STORE=true --dart-define=CAPTURE_PLAY=true test/screenshots_test.dart
```

Expected: PASS.

- [ ] **Step 2: Export only the approved five-image sequences**

Run:

```powershell
dart run tool/export_store_screenshots.dart
```

Expected: exactly five 1290 x 2796 RGB PNGs under `store-assets/screenshots/app-store/` and exactly five 1080 x 1920 RGB PNGs under `store-assets/screenshots/google-play/`.

- [ ] **Step 3: Open and inspect all ten exported images**

Verify ordering, legibility, no clipped UI, no private content, no stale icon/brand, and factual correspondence with `STORE-LISTING.md`. Record the exact files inspected in the verification receipt.

- [ ] **Step 4: Commit final screenshot assets separately**

Run:

```powershell
git add -- test/goldens store-assets/screenshots release-evidence/1.0.4+22/local-verification.md
git diff --cached --check
git commit -m "assets: refresh Room of Days store screenshots"
```

Review `git diff --cached --name-only` before committing and remove diagnostic `test/failures/` images if they appear.

### Task 4: Build signed Android artifacts and create immutable candidate evidence

**Files:**
- Create outside the repo history: `../release-artifacts/room-of-days-1.0.4+22-android.aab`
- Create outside the repo history: `../release-artifacts/room-of-days-1.0.4+22-android.apk`
- Modify only after artifacts exist: `release-candidate.json`
- Modify: `../release-artifacts/README.md`
- Modify: `test/release_native_privacy_test.dart`
- Modify: `release-evidence/1.0.4+22/local-verification.md`

**Interfaces:**
- Consumes: committed source and configured Android release signing.
- Produces: signed APK/AAB, exact SHA-256/size/permission evidence, and a verifier-readable immutable manifest.

- [ ] **Step 1: Build the Android release artifacts**

Run:

```powershell
flutter build appbundle --release
flutter build apk --release
```

Expected: both commands exit 0. Confirm the signing certificate matches the established release certificate before copying artifacts.

- [ ] **Step 2: Copy artifacts to versioned evidence paths and hash them**

Run:

```powershell
Copy-Item -LiteralPath 'build/app/outputs/bundle/release/app-release.aab' -Destination '../release-artifacts/room-of-days-1.0.4+22-android.aab'
Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-release.apk' -Destination '../release-artifacts/room-of-days-1.0.4+22-android.apk'
Get-Item '../release-artifacts/room-of-days-1.0.4+22-android.aab','../release-artifacts/room-of-days-1.0.4+22-android.apk' | Select-Object FullName,Length
Get-FileHash -Algorithm SHA256 '../release-artifacts/room-of-days-1.0.4+22-android.aab','../release-artifacts/room-of-days-1.0.4+22-android.apk'
```

Expected: two non-empty versioned files and two exact hashes.

- [ ] **Step 3: Write the candidate manifest from actual evidence**

Update `release-candidate.json` to Version `1.0.4`, Code `22`, the exact release-prep source commit, actual artifact paths/sizes/hashes, actual signing certificate, SDK/NDK/native alignment inventory, permissions, ABIs, and app-link paths. Do not copy a size, hash, or permission from Build 20.

Update the corresponding source-level assertions in `test/release_native_privacy_test.dart` and add the artifact receipt to `../release-artifacts/README.md`.

- [ ] **Step 4: Run the immutable candidate verifiers**

Run:

```powershell
flutter test test/release_native_privacy_test.dart
dart run tool/verify_android_candidate.dart --manifest release-candidate.json
dart run tool/verify_store_submission.dart
```

Expected: all commands PASS. The store verifier reports one internally consistent `1.0.4+22` packet.

- [ ] **Step 5: Commit candidate metadata, not binary artifacts**

Run:

```powershell
git add -- release-candidate.json test/release_native_privacy_test.dart release-evidence/1.0.4+22/local-verification.md
git diff --cached --check
git commit -m "release: record Room of Days 1.0.4 build 22"
```

The versioned APK/AAB remain in the established external `release-artifacts` evidence directory.

### Task 5: Run the owner-controlled hosted, TestFlight, and physical gates

**Files:**
- Modify after real checks: `RELEASE-CHECKLIST.md`
- Modify after real checks: `DEVICE-ACCEPTANCE-RUNBOOK.md`
- Modify after real checks: `ACCOUNT-RECOVERY-RUNBOOK.md`
- Modify: `release-evidence/1.0.4+22/local-verification.md`

**Interfaces:**
- Consumes: the locally verified candidate, signed Android evidence, selected icon, and support paths.
- Produces: externally verified hosted pages, processed TestFlight build, physical-device acceptance, and support/recovery receipts.

- [ ] **Step 1: Ask the owner before external mutations**

Present the local verification packet and request one explicit approval covering Firebase Hosting deployment, the manual Codemagic `ios-testflight` build, and the real external support-mail test. Do not infer those permissions from passing local tests.

- [ ] **Step 2: After approval, deploy and verify hosted pages**

Build from the real project layout, deploy the accepted web bundle to Firebase Hosting project `emberkeep-5b33b`, then open the live `/support`, `/privacy`, `/delete-account`, and `/version.json` routes from outside the local environment. Record timestamps and responses without storing credentials.

- [ ] **Step 3: After approval, run exactly one Codemagic iOS workflow**

Trigger the manual `ios-testflight` workflow from the verified release commit. It must accept unused Build 22, complete analysis/tests/signing/privacy checks, preserve IPA/dSYM evidence, and process in TestFlight. If the workflow reports Build 22 already exists, stop and revise the identity rather than bypassing the guard.

- [ ] **Step 4: Complete physical upgrade and fresh-install matrices**

Install the exact processed TestFlight build over Build 19 or the latest available baseline and complete every applicable row in `DEVICE-ACCEPTANCE-RUNBOOK.md`. Separately perform a fresh install. Cover saved rooms/quests/Daybook/account state, What's New ordering, all five tabs, Morning/Night flows, completion/undo, offline relaunch, keyboard/insets, links, notifications, Low Power Mode, text scaling, VoiceOver, Reduced Motion, audio/haptics, warm-phone scroll stress, icon/splash, and map handoff.

Install the exact Android APK/AAB-derived build on a physical Android 10+ device and complete its upgrade, adaptive/themed icon, navigation/back, notification, link, and persistence checks.

- [ ] **Step 5: Complete support and recovery service tests**

From an external sender, email `support@roomofdays.com`, verify inbox/spam receipt and reply routing, then record the result without deleting mail. Use a deliberate test account to complete the custom-domain password reset and successful sign-in cycle. Do not delete a real account merely to satisfy the runbook.

- [ ] **Step 6: Commit only truthful completed checkboxes and receipts**

Run:

```powershell
git add -- RELEASE-CHECKLIST.md DEVICE-ACCEPTANCE-RUNBOOK.md ACCOUNT-RECOVERY-RUNBOOK.md release-evidence/1.0.4+22/local-verification.md
git diff --cached --check
git commit -m "docs: verify Room of Days 1.0.4 release gates"
```

Unchecked or failed gates stay explicit.

### Task 6: Prepare the final App Store release decision

**Files:**
- Create: `release-evidence/1.0.4+22/release-packet.md`
- Modify only after observed state changes: `RELEASE-CHECKLIST.md`

**Interfaces:**
- Consumes: Tasks 1-5 complete receipts and current App Store Connect/public-catalog state.
- Produces: one exact release/hold recommendation and an owner-controlled submission decision.

- [ ] **Step 1: Recheck current Apple state**

Verify App Store Connect status, selected territories, agreements/tax/banking, support and privacy URLs, age rating, export compliance, screenshots, icon, version, and selected Build 22. Recheck the official public catalog for Build 19/Version 1.0 rather than relying on the August 19 propagation check.

- [ ] **Step 2: Write the release packet**

Use `apply_patch` to create `release-evidence/1.0.4+22/release-packet.md` containing the exact commit, version/build, artifact hashes, complete test/build receipts, visual comparison paths, selected icon evidence, physical-device results, support/recovery/hosted checks, store status, Places-off limitation, and a one-sentence release-or-hold recommendation with its reason.

- [ ] **Step 3: Obtain the final owner decision**

Present the packet and ask the owner to release or hold. Do not submit, phase, replace, withdraw, or change availability until that answer is explicit.

- [ ] **Step 4: If released, verify publication rather than submission**

After the authorized App Store action, monitor until Apple reports the version ready for sale and the public catalog/product page returns the released version. Record the observed public state and timestamp. A successful upload, processing state, TestFlight install, or review submission is not publication.

- [ ] **Step 5: Commit the final truthful release record**

Run:

```powershell
git add -- release-evidence/1.0.4+22/release-packet.md RELEASE-CHECKLIST.md
git diff --cached --check
git commit -m "docs: record Room of Days 1.0.4 release"
```

If the owner holds, record the hold reason and leave publication boxes unchecked.
