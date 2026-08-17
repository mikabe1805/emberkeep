# Room of Days Protected Places Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add explicitly consented Google Places autocomplete through protected callable functions, transient attributed selections, and production-safe feature gating without weakening manual location entry or directions.

**Architecture:** Flutter talks only to an injectable `PlaceSearchService`; the production adapter calls two authenticated Firebase callable functions. The new Functions package owns Google credentials, fixed upstream URLs, field masks, validation, per-user cost guards, and normalized transient responses. A compile-time feature flag defaults off until billing, server secret, quota, privacy, and App Check enforcement are configured by the owner.

**Tech Stack:** Flutter/Dart, `cloud_functions`, `firebase_app_check`, Firebase Auth, Firebase Functions v2/TypeScript, Google Places API (New), Jest/Vitest-style unit tests with mocked `fetch`.

## Global Constraints

- `PLACE_SEARCH_ENABLED` defaults to `false`; manual saved-name/routing/building/room fields and directions remain complete when search is disabled or unavailable.
- Never ship a Google Places server key in Flutter, Dart defines, `firebase_options.dart`, web assets, or repository plaintext.
- Search starts only after 3 non-whitespace characters and 300 ms quiet time, returns at most 5 predictions, creates a new UUID session token per search session, ignores stale results, and makes one details call on selection.
- Before first search, disclose typed-query transfer, no current location, and anonymous Firebase identity. Identity is created only after `USE PLACE SEARCH`; decline/close creates none.
- Persist only provider, place ID, exact person-typed query as saved name, and person-authored routing/building/room. Provider prediction/name/address/coordinates remain transient and attributed.
- Callable functions require Firebase Auth. Public enablement also requires App Check enforcement after monitor-mode validation.
- Fixed server requests use Places API (New), narrow field masks, no arbitrary upstream URL, payload limits, per-user/per-install rate limits, and a conservative global budget guard.
- No automated test calls a live billable Google API.
- Room of Days does not request or track device location.
- Terms/privacy disclosures and Google links must be live before the public flag is enabled.
- Do not edit or commit unrelated dirty design/audit files.
- Every behavior change begins with a focused failing test.

---

### Task 1: Bootstrap and test the protected Firebase Functions package

**Files:**
- Create: `functions/package.json`
- Create: `functions/tsconfig.json`
- Create: `functions/eslint.config.js`
- Create: `functions/src/index.ts`
- Create: `functions/src/places.ts`
- Create: `functions/src/places.test.ts`
- Modify: `firebase.json`
- Modify: `.gitignore`

**Interfaces:**
- Produces callable `placesAutocomplete` and `placesDetails`; pure `validateAutocompleteRequest`, `validateDetailsRequest`, `buildAutocompleteRequest`, `buildDetailsRequest`, `normalizeAutocomplete`, `normalizeDetails`, and `CostGuard` units.

- [ ] **Step 1: Write failing pure function tests**

Cover query trimming/3–160 length, UUID session token, locale validation, place-ID validation, exactly five normalized results, fixed `https://places.googleapis.com/v1/places:autocomplete` and `/v1/places/<encoded-id>` endpoints, exact field masks, discarded extra upstream fields, unauthorized rejection, rate-limit rejection, and global budget closure. Mock `fetch`; assert no test reaches the network.

- [ ] **Step 2: Run Functions tests before implementation**

Run: `npm --prefix functions test -- --runInBand`

Expected: FAIL because package/functions do not exist.

- [ ] **Step 3: Create package/config and fixed request builders**

Use Node 20, TypeScript, `firebase-functions` v2 callable APIs, `firebase-admin`, and a test runner. Define:

```ts
export type AutocompleteInput = { query: string; sessionToken: string; installId: string; locale: string };
export type DetailsInput = { placeId: string; sessionToken: string; installId: string; locale: string };
export type PlacePrediction = { placeId: string; primaryText: string; secondaryText?: string };
export type PlaceDetails = { placeId: string; primaryText: string; secondaryText?: string };
```

Use server secret `GOOGLE_PLACES_API_KEY`. Autocomplete sends only
`input`, `sessionToken`, and `languageCode`, with header field mask:

```text
suggestions.placePrediction.placeId,suggestions.placePrediction.structuredFormat.mainText.text,suggestions.placePrediction.structuredFormat.secondaryText.text
```

Details uses `GET https://places.googleapis.com/v1/places/<encoded-place-id>`
with field mask `id,displayName,formattedAddress` and the same session token.
Normalize details to `id`, `displayName.text`, and `formattedAddress`; do not
return coordinates or any extra upstream fields.

- [ ] **Step 4: Implement callable wrappers and guards**

```ts
const enforcePlacesAppCheck = defineBoolean('PLACES_ENFORCE_APP_CHECK', {
  default: false,
});

export const placesAutocomplete = onCall(
  {
    secrets: [googlePlacesApiKey],
    enforceAppCheck: enforcePlacesAppCheck,
  },
  async (request) => autocompleteHandler(request),
);
```

Implement the same boundary for details. Monitor-mode deployments leave the
boolean parameter false while the Flutter release flag remains false. Public
enablement requires redeployment with the parameter true. Rate/budget storage
is injected behind `CostGuard` so unit tests are deterministic; production uses
Firestore transactions keyed by authenticated UID and validated per-install
UUID with minute/day buckets and conservative limits documented beside
constants: 30 autocomplete calls/minute and 300/day per UID and install, 10
details calls/minute and 100/day per UID and install, plus global daily guards
of 5,000 autocomplete and 1,000 details calls. A closed/failed guard rejects the
request before the upstream fetch.

- [ ] **Step 5: Add Functions deployment target**

Add to `firebase.json`:

```json
"functions": [{"source": "functions", "codebase": "default", "runtime": "nodejs20"}]
```

Ignore `functions/lib`, `functions/node_modules`, and coverage output.

- [ ] **Step 6: Run backend gates**

Run: `npm --prefix functions install`

Run: `npm --prefix functions run lint && npm --prefix functions run build && npm --prefix functions test -- --runInBand`

Expected: all exit 0; tests confirm zero live upstream calls.

- [ ] **Step 7: Commit**

```powershell
git add functions firebase.json .gitignore
git commit -m "feat: add protected Places callables"
```

### Task 2: Add release flag, local consent, auth, and App Check boundaries

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `lib/release_features.dart`
- Modify: `lib/main.dart`
- Modify: `lib/daybook/data/daybook_preferences.dart`
- Create: `lib/daybook/services/place_search_access.dart`
- Create: `test/place_search_access_test.dart`

**Interfaces:**
- Produces `kPlaceSearchEnabled`, `PlaceSearchConsent`, `PlaceSearchIdentity`, `PlaceSearchAccess.ensureReady()`.
- Consumes existing Firebase Auth but provisions anonymous identity only after consent.

- [ ] **Step 1: Add dependencies through Flutter tooling**

Run: `flutter pub add cloud_functions firebase_app_check`

Expected: compatible current versions recorded in `pubspec.yaml`/lockfile.

- [ ] **Step 2: Write failing access-state tests**

Using fakes, assert disabled flag never prompts/authenticates; decline/close persists no consent and makes no auth call; accept writes consent then reuses signed-in account or calls anonymous sign-in exactly once; withdrawal clears only Places consent/preference, not the Firebase account; unavailable App Check/auth returns manual fallback state.

- [ ] **Step 3: Run access tests**

Run: `flutter test test/place_search_access_test.dart`

Expected: FAIL because access types do not exist.

- [ ] **Step 4: Implement flag/preferences/access**

```dart
const bool kPlaceSearchEnabled = bool.fromEnvironment(
  'PLACE_SEARCH_ENABLED',
  defaultValue: false,
);

abstract interface class PlaceSearchIdentity {
  bool get signedIn;
  Future<void> signInAnonymously();
}
```

Persist a local consent enum/version in `DaybookPreferences`. `ensureReady` checks flag, prompts via injected callback, and calls identity only on explicit acceptance.

- [ ] **Step 5: Configure App Check without breaking tests**

Initialize App Check after Firebase Core only on supported production platforms, with debug/test paths injectable. Document monitor mode in code/config; callable enforcement remains server-side. Do not add device location permissions.

- [ ] **Step 6: Run access and existing Firebase tests**

Run: `flutter test test/place_search_access_test.dart test/storage_cloud_merge_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit**

```powershell
git add pubspec.yaml pubspec.lock lib/release_features.dart lib/main.dart lib/daybook/data/daybook_preferences.dart lib/daybook/services/place_search_access.dart test/place_search_access_test.dart
git commit -m "feat: gate place search behind explicit consent"
```

### Task 3: Implement callable search, debouncing, sessions, and stale-response safety

**Files:**
- Create: `lib/daybook/services/place_search_service.dart`
- Create: `lib/daybook/services/firebase_place_search_service.dart`
- Create: `lib/daybook/services/place_search_controller.dart`
- Create: `test/place_search_service_test.dart`

**Interfaces:**
- Produces `PlaceSuggestion`, `PlaceSelection`, `PlaceSearchService.autocomplete/details`, `DisabledPlaceSearchService`, `PlaceSearchController`.
- Consumes callable names from Task 1 and access state from Task 2.

- [ ] **Step 1: Write failing contract/controller tests**

Assert under-three-character queries yield no call, 300 ms debounce, a UUID token per active session, max five results, second query invalidates first response, manual text change invalidates pending results, selection invokes details once with same token, selection saves exact original typed query, and an 8-second timeout/quota/App Check/unconfigured error exposes `Search unavailable — type the location instead.` without erasing manual fields.

- [ ] **Step 2: Run service tests**

Run: `flutter test test/place_search_service_test.dart`

Expected: FAIL because contracts/controller do not exist.

- [ ] **Step 3: Implement transient contracts**

```dart
final class PlaceSuggestion {
  const PlaceSuggestion({required this.provider, required this.placeId,
    required this.primaryText, this.secondaryText});
}

final class PlaceSelection {
  const PlaceSelection({required this.provider, required this.placeId,
    required this.originalQuery, required this.primaryText, this.secondaryText});
  DaybookPlace toPersistedPlace({String? routingText, String? building, String? room});
}

abstract interface class PlaceSearchService {
  Future<List<PlaceSuggestion>> autocomplete({required String query,
    required String sessionToken, required String installId,
    required String locale});
  Future<PlaceSelection> details({required PlaceSuggestion suggestion,
    required String originalQuery, required String sessionToken,
    required String installId, required String locale});
}
```

`toPersistedPlace` writes provider/placeId/originalQuery plus only person-authored optional fields. It never persists `primaryText`/`secondaryText`.

- [ ] **Step 4: Implement callable adapter and controller**

Map normalized callable payloads exactly and reject malformed data. Controller owns `Timer(const Duration(milliseconds: 300))`, generation counter, UUID session token, current query, max-five immutable state, selection closure, and disposal. Disabled service performs no callable access.

- [ ] **Step 5: Run service tests**

Run: `flutter test test/place_search_service_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add lib/daybook/services/place_search_service.dart lib/daybook/services/firebase_place_search_service.dart lib/daybook/services/place_search_controller.dart test/place_search_service_test.dart
git commit -m "feat: add safe place search sessions"
```

### Task 4: Add attributed search to the shared location editor

**Files:**
- Modify: `lib/daybook/widgets/daybook_place_fields.dart`
- Create: `lib/daybook/widgets/place_search_consent_dialog.dart`
- Modify: `lib/daybook/widgets/daybook_event_editor.dart`
- Modify: `lib/daybook/widgets/daybook_task_editor.dart`
- Modify: `lib/academic_calendar/widgets/academic_calendar_sections.dart`
- Modify: `lib/screens/calendar.dart`
- Modify: `test/academic_calendar_widget_test.dart`

**Interfaces:**
- Consumes Tasks 2–3 services/controller.
- Produces explicit `SEARCH PLACES WITH GOOGLE`, consent dialog, attributed prediction list/transient selection preview, manual fallback.

- [ ] **Step 1: Write failing widget tests**

Assert no typeahead before explicit affordance/consent; disclosure contains typed-query transfer/no current location/private anonymous ID and `USE PLACE SEARCH`; decline does not call auth/service; accepted search waits 300 ms and three characters; visible suggestions include `Google Maps` attribution; selection sets `SAVED NAME` to exact typed query and leaves routing text empty; stale responses cannot replace newer query; failure shows exact fallback copy and manual save remains enabled.

- [ ] **Step 2: Run widget tests**

Run: `flutter test test/academic_calendar_widget_test.dart --plain-name "place search"`

Expected: FAIL because shared location fields are manual-only.

- [ ] **Step 3: Implement consent and attributed suggestions**

Keep the existing manual fields first. The explicit affordance calls `PlaceSearchAccess.ensureReady`; accepted access creates a controller. Each suggestion has at least a 44 px target, primary/secondary transient text, and visible `Google Maps` attribution. Hide all provider content when the form closes or a manual choice replaces it.

- [ ] **Step 4: Inject service/access from CalendarPage**

Default production construction uses `DisabledPlaceSearchService` when the compile flag is false. Tests inject fakes. Event, task, and class editors reuse the same component and adapter.

- [ ] **Step 5: Run widget/service regressions**

Run: `flutter test test/place_search_access_test.dart test/place_search_service_test.dart test/academic_calendar_widget_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add lib/daybook/widgets/daybook_place_fields.dart lib/daybook/widgets/place_search_consent_dialog.dart lib/daybook/widgets/daybook_event_editor.dart lib/daybook/widgets/daybook_task_editor.dart lib/academic_calendar/widgets/academic_calendar_sections.dart lib/screens/calendar.dart test/academic_calendar_widget_test.dart
git commit -m "feat: add attributed Google place search"
```

### Task 5: Update privacy/configuration and prove disabled-release behavior

**Files:**
- Modify: `web/privacy.html`
- Modify: `web/terms.html`
- Modify: `README.md`
- Modify: `RELEASE-CHECKLIST.md`
- Modify: `test/release_native_privacy_test.dart`
- Create: `functions/README.md`

**Interfaces:**
- Consumes: completed backend/client slice.
- Produces truthful public copy, owner setup runbook, and a release flag that remains off by default.

- [ ] **Step 1: Write failing privacy/release assertions**

Assert public privacy copy says no current-location access; manual locations stay device-local/outside Firestore; active place searches send typed query to Google through protected endpoint; acceptance creates/reuses Firebase identity for service abuse controls; Room of Days does not use queries for ads/analytics. Assert Terms link Google Maps/Google privacy terms. Assert a default build renders manual location and never constructs a callable service.

- [ ] **Step 2: Run privacy tests**

Run: `flutter test test/release_native_privacy_test.dart test/place_search_access_test.dart`

Expected: FAIL against the old unconditional location wording.

- [ ] **Step 3: Update public disclosures and setup documentation**

Document exact owner-only enablement order: attach billing; enable Places API (New); restrict/store server secret; deploy functions; configure budget alerts and quota caps; inspect App Check monitor metrics; enable enforcement for both callables; verify privacy/terms live; build with `--dart-define=PLACE_SEARCH_ENABLED=true`. State that checked/public builds remain false until every gate is complete.

- [ ] **Step 4: Run all focused gates**

Run: `npm --prefix functions run lint && npm --prefix functions run build && npm --prefix functions test -- --runInBand`

Run: `flutter analyze`

Run: `flutter test test/place_search_access_test.dart test/place_search_service_test.dart test/academic_calendar_widget_test.dart test/release_native_privacy_test.dart`

Expected: all pass.

- [ ] **Step 5: Build the default disabled release**

Run: `flutter build web --release --wasm`

Run: `flutter build apk --release`

Expected: both exit 0; manual location/directions work and place search is absent/disabled.

- [ ] **Step 6: Commit**

```powershell
git add web/privacy.html web/terms.html README.md RELEASE-CHECKLIST.md test/release_native_privacy_test.dart functions/README.md
git commit -m "docs: disclose protected place search"
```

### Task 6: Whole-slice verification without production enablement

**Files:**
- Verify: all files in Tasks 1–5

**Interfaces:**
- Consumes: complete Places implementation with flag default false.
- Produces: test/build evidence and a list of owner-authenticated deployment gates still pending.

- [ ] **Step 1: Run all backend tests**

Run: `npm --prefix functions run lint && npm --prefix functions run build && npm --prefix functions test -- --runInBand`

Expected: all pass with mocked upstream calls.

- [ ] **Step 2: Run the full Flutter suite**

Run: `flutter analyze && flutter test`

Expected: analysis and tests pass.

- [ ] **Step 3: Exercise enabled UI against fakes/emulators only**

Run the widget tests with injected callable fakes and, if Firebase emulators are available, the callable integration tests. Do not use a live Google key or billable Places request.

- [ ] **Step 4: Verify platform manifests**

Confirm `ios/Runner/Info.plist` and `android/app/src/main/AndroidManifest.xml` contain no new location permission. Confirm no server credential string is present in Flutter/web build output.

- [ ] **Step 5: Record pending owner gates**

The final report must mark billing, secret creation, quota/budget alerts, function deployment, App Check monitor evidence/enforcement, public copy deployment, and physical iPhone provider handoff as pending until actually completed. Do not call the public Places feature enabled before those checks.

- [ ] **Step 6: Commit only if verification required a correction**

```powershell
git add functions lib test web README.md RELEASE-CHECKLIST.md firebase.json pubspec.yaml pubspec.lock
git commit -m "test: verify protected place search"
```
