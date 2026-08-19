# Room of Days Support Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make support, privacy, deletion, and feedback paths discoverable, testable, honest in voice, and useful when the device cannot open mail or a browser.

**Architecture:** A small pure content module owns the support address, platform label, and mail template. `AboutScreen` receives injectable launch/copy seams, keeps its existing authored visual system, and adds quiet links backed by `PublicLinks`. Static public pages share the same singular Mika/Room of Days voice, while source-level and widget tests lock the routes and failure behavior.

**Tech Stack:** Flutter/Dart, `url_launcher`, Flutter clipboard services, widget tests, source-level policy tests, static HTML.

**Spec:** `docs/superpowers/specs/2026-08-19-release-candidate-and-icon-design.md`

## Global Constraints

- Keep `support@roomofdays.com` as the only public support address.
- Do not add `package_info_plus`; `currentRoomReleaseNotes.id` is already checked against `pubspec.yaml`.
- Never prefill journal content, account email, device identifiers, passwords, authentication details, or private exports.
- Use `PublicLinks.support`, `PublicLinks.privacy`, and `PublicLinks.deleteAccount`; do not hardcode the public host in `about.dart`.
- Preserve the iOS Ko-fi exclusion and all existing contribution/IAP behavior.
- Keep copy direct, singular, non-corporate, and non-punitive.
- Keep every support/policy target at least 44 logical pixels and reachable at 320 x 568 with 200-percent text.
- Use test-first implementation and commit each independently reviewable deliverable.

---

### Task 1: Add one pure support-contact source of truth

**Files:**
- Create: `lib/content/support_contact.dart`
- Create: `test/support_contact_test.dart`
- Read: `lib/content/release_notes.dart`

**Interfaces:**
- Consumes: `currentRoomReleaseNotes.id`, `kIsWeb`, and `defaultTargetPlatform`.
- Produces: `supportEmail`, `supportPlatformLabel(...)`, and `feedbackMailUri(...)` for the About UI and tests.

- [ ] **Step 1: Write failing tests for address, platform, and safe body content**

Create `test/support_contact_test.dart`:

```dart
import 'package:emberkeep/content/support_contact.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('feedback mail carries useful non-sensitive release context', () {
    final uri = feedbackMailUri(
      releaseId: '1.0.3+21',
      platformLabel: 'iPhone / iPad',
    );

    expect(uri.scheme, 'mailto');
    expect(uri.path, supportEmail);
    expect(uri.queryParameters['subject'], 'Room of Days — feedback');
    final body = uri.queryParameters['body']!;
    expect(body, contains('What I expected:'));
    expect(body, contains('What happened:'));
    expect(body, contains('Steps to reproduce (optional):'));
    expect(body, contains('Platform: iPhone / iPad'));
    expect(body, contains('App version: 1.0.3+21'));
    expect(body, contains('Do not include your password or an unredacted journal export.'));
    expect(body, isNot(contains('account email')));
  });

  test('platform labels are explicit and stable', () {
    expect(
      supportPlatformLabel(isWebOverride: true),
      'Web',
    );
    expect(
      supportPlatformLabel(
        isWebOverride: false,
        platformOverride: TargetPlatform.iOS,
      ),
      'iPhone / iPad',
    );
    expect(
      supportPlatformLabel(
        isWebOverride: false,
        platformOverride: TargetPlatform.android,
      ),
      'Android',
    );
  });
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```powershell
flutter test test/support_contact_test.dart
```

Expected: FAIL because `lib/content/support_contact.dart` does not exist.

- [ ] **Step 3: Implement the pure support-contact module**

Create `lib/content/support_contact.dart`:

```dart
import 'package:flutter/foundation.dart';

import 'release_notes.dart';

const supportEmail = 'support@roomofdays.com';

String supportPlatformLabel({
  bool? isWebOverride,
  TargetPlatform? platformOverride,
}) {
  if (isWebOverride ?? kIsWeb) return 'Web';
  return switch (platformOverride ?? defaultTargetPlatform) {
    TargetPlatform.iOS => 'iPhone / iPad',
    TargetPlatform.android => 'Android',
    _ => 'Desktop',
  };
}

Uri feedbackMailUri({
  String? releaseId,
  String? platformLabel,
}) {
  final body = <String>[
    'What I’m reaching out about:',
    '',
    'What I expected:',
    '',
    'What happened:',
    '',
    'Steps to reproduce (optional):',
    '',
    'Platform: ${platformLabel ?? supportPlatformLabel()}',
    'App version: ${releaseId ?? currentRoomReleaseNotes.id}',
    '',
    'Do not include your password or an unredacted journal export.',
  ].join('\n');
  return Uri(
    scheme: 'mailto',
    path: supportEmail,
    queryParameters: <String, String>{
      'subject': 'Room of Days — feedback',
      'body': body,
    },
  );
}
```

- [ ] **Step 4: Run the focused test and verify it passes**

Run:

```powershell
dart format lib/content/support_contact.dart test/support_contact_test.dart
flutter test test/support_contact_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit the content boundary**

Run:

```powershell
git add -- lib/content/support_contact.dart test/support_contact_test.dart
git diff --cached --check
git commit -m "feat: define useful support contact details"
```

### Task 2: Make About links and failure fallbacks testable

**Files:**
- Modify: `lib/screens/about.dart`
- Modify: `test/about_screen_test.dart`
- Read: `lib/content/links.dart`

**Interfaces:**
- Consumes: `supportEmail`, `feedbackMailUri()`, and `PublicLinks.support/privacy/deleteAccount`.
- Produces: injected `ExternalUriLauncher` and `TextCopier` seams; keys `about-open-support`, `about-open-privacy`, and `about-open-delete-account`.

- [ ] **Step 1: Add failing launcher, fallback, link, and copy tests**

Extend `test/about_screen_test.dart` with fakes that capture calls:

```dart
final opened = <Uri>[];
final copied = <String>[];

Future<bool> captureOpen(Uri uri) async {
  opened.add(uri);
  return true;
}

Future<void> captureCopy(String value) async {
  copied.add(value);
}
```

Add tests that:

```dart
expect(find.byKey(const ValueKey('about-open-support')), findsOneWidget);
expect(find.byKey(const ValueKey('about-open-privacy')), findsOneWidget);
expect(find.byKey(const ValueKey('about-open-delete-account')), findsOneWidget);
```

Tap feedback with `captureOpen`, then assert the captured URI body contains `currentRoomReleaseNotes.id` and the active platform label. Pump with an opener that returns `false`, tap feedback, assert `COPY EMAIL` appears, tap it, and assert `copied.single == supportEmail` plus the confirmation `Support email copied.`. Add a throwing opener case and a failed public-link case; the latter must show the browser fallback and no copy action.

- [ ] **Step 2: Run the widget tests and verify they fail**

Run:

```powershell
flutter test test/about_screen_test.dart
```

Expected: FAIL because About has no injected seams or policy-link keys.

- [ ] **Step 3: Add injectable default wrappers without breaking const call sites**

At the top of `lib/screens/about.dart`, import Flutter services plus the content modules and define:

```dart
typedef ExternalUriLauncher = Future<bool> Function(Uri uri);
typedef TextCopier = Future<void> Function(String text);

Future<bool> _launchExternalUri(Uri uri) => launchUrl(uri);
Future<void> _copyText(String text) =>
    Clipboard.setData(ClipboardData(text: text));
```

Extend `AboutScreen`:

```dart
const AboutScreen({
  super.key,
  this.themeId,
  this.reduceMotion = false,
  this.coffeeUrlOverride,
  this.openExternalUri = _launchExternalUri,
  this.copyText = _copyText,
});

final ExternalUriLauncher openExternalUri;
final TextCopier copyText;
```

Delete the static `_feedbackMail`; call `feedbackMailUri()` at tap time.

- [ ] **Step 4: Implement mail failure with a copyable safe fallback**

Change `_open` to call `openExternalUri`, catch thrown errors, and return on success. For a failed `mailto:` request, show the existing human explanation with this action:

```dart
SnackBarAction(
  label: 'COPY EMAIL',
  textColor: Palette.xpLight,
  onPressed: () async {
    try {
      await copyText(supportEmail);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support email copied.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn’t copy it — support@roomofdays.com'),
        ),
      );
    }
  },
)
```

For `http`/`https` failure, keep `Couldn’t open that page. Try again when a browser is available.` and do not show a copy-email action.

- [ ] **Step 5: Add quiet direct support, privacy, and deletion actions**

Pass three callbacks into `_ContactCard` and render a wrapping secondary action group beneath `SEND FEEDBACK`. Reuse `Pressable`, `facetedDecoration`, `Type.label`, and the current glass edge/fill rather than default Material buttons. Each action has a minimum height of 44, may wrap to its own line at large text, and uses:

```dart
const ValueKey('about-open-support')
const ValueKey('about-open-privacy')
const ValueKey('about-open-delete-account')
```

The visible labels are `SUPPORT PAGE`, `PRIVACY`, and `DELETE ACCOUNT`. Their callbacks open `Uri.parse(PublicLinks.support)`, `Uri.parse(PublicLinks.privacy)`, and `Uri.parse(PublicLinks.deleteAccount)` through `_open`.

- [ ] **Step 6: Run focused behavior and narrow-layout tests**

Run:

```powershell
dart format lib/screens/about.dart test/about_screen_test.dart
flutter test test/support_contact_test.dart test/about_screen_test.dart
```

Expected: PASS, including the existing 320 x 568 / 200-percent-text case with no exception and all three policy actions reachable by scrolling.

- [ ] **Step 7: Commit the app support path**

Run:

```powershell
git add -- lib/screens/about.dart test/about_screen_test.dart
git diff --cached --check
git commit -m "feat: make support paths reliable and discoverable"
```

### Task 3: Align public support and deletion voice

**Files:**
- Modify: `web/support.html`
- Modify: `web/delete-account.html`
- Modify: `test/release_native_privacy_test.dart`

**Interfaces:**
- Consumes: canonical URLs and `support@roomofdays.com`.
- Produces: singular public support copy and source-level regression checks.

- [ ] **Step 1: Add failing singular-voice and prompt tests**

Extend the canonical policy/support test in `test/release_native_privacy_test.dart`:

```dart
expect(support, contains('tell me'));
expect(support, isNot(contains('tell us')));
expect(deletion, isNot(contains('email us')));
expect(deletion, isNot(contains('We will reply')));
expect(support, contains('What I expected'));
expect(support, contains('What happened'));
```

- [ ] **Step 2: Run the source test and verify it fails**

Run:

```powershell
flutter test test/release_native_privacy_test.dart
```

Expected: FAIL on the current plural support voice.

- [ ] **Step 3: Update only the public support voice and mail prompt**

In `web/support.html`, change `tell us` to `tell me`. Replace the bare mail link with a percent-encoded `mailto:` subject/body that prompts `What I expected`, `What happened`, and `Steps to reproduce (optional)` while retaining the visible address. In `web/delete-account.html`, change `email us` to `email me` and `We will reply` to `I’ll reply`. Do not alter the seven-day promise, retention language, privacy links, or deletion mechanics.

- [ ] **Step 4: Run the source test and verify it passes**

Run:

```powershell
flutter test test/release_native_privacy_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit the public copy separately**

Run:

```powershell
git add -- web/support.html web/delete-account.html test/release_native_privacy_test.dart
git diff --cached --check
git commit -m "fix: align public support voice"
```

### Task 4: Refresh About evidence and run the support gate

**Files:**
- Refresh: `test/goldens/about_screen_430x932.png`
- Refresh: `test/goldens/about_screen_ios_430x932.png`
- Modify: `design/audits/2026-08-19/release-candidate/README.md`

**Interfaces:**
- Consumes: Tasks 1-3 behavior and the visual-audit manifest.
- Produces: fresh support UI evidence and a complete local support-readiness receipt.

- [ ] **Step 1: Refresh the existing About captures**

Run:

```powershell
flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/screenshots_test.dart --plain-name "about"
```

Expected: PASS and both Android/default plus iOS About goldens refresh. If the test runner's name filter matches only one About case, run the exact second printed test name separately rather than broadening into unrelated screenshot updates.

- [ ] **Step 2: Open the About images at full and narrow scale**

Verify the primary `SEND FEEDBACK` action remains singular, the three quiet links are readable without competing with it, iOS still omits Ko-fi, and 200-percent text scrolls without clipping.

- [ ] **Step 3: Run the complete local support gate**

Run:

```powershell
flutter test test/support_contact_test.dart test/about_screen_test.dart test/release_native_privacy_test.dart
flutter analyze
```

Expected: both commands PASS.

- [ ] **Step 4: Record the remaining manual gates accurately**

Use `apply_patch` to add these unchecked owner actions to the dated audit report:

```text
- Send a real message from an external account to support@roomofdays.com; verify inbox/spam receipt and reply routing.
- Complete a production-like Firebase password-reset email/link/sign-in cycle.
- Open https://roomofdays.com/support, /privacy, and /delete-account outside the local environment after deployment.
```

Do not mark any of them complete from widget or source tests.

- [ ] **Step 5: Commit the refreshed evidence**

Run:

```powershell
git add -- test/goldens/about_screen_430x932.png test/goldens/about_screen_ios_430x932.png design/audits/2026-08-19/release-candidate/README.md
git diff --cached --check
git commit -m "test: capture final support experience"
```
