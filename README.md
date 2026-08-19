# Room of Days

Room of Days is a local-first life RPG for Android, iOS, and the web. Completing
real-life quests grows six life domains, earns XP and Glimmers, and changes
your build while you furnish a candlelit personal space.

The product is deliberately non-punitive: progress never decays, lapses never
erase earned growth, and all core functionality works offline. The build
and room are the visual heart of the app; the fireplace is ambient warmth, not
a health meter, and there is no companion creature.

## Design compass

- **Fast, physical feedback:** every tap acknowledges within 100 ms; reward
  receipts, sound, haptics, and motion scale with the size of the moment.
- **Candlelit glass:** dark espresso/plum canvases, warm honey glass, cream
  type, mechanic-specific accent colors, and code-painted room art.
- **Player-positive language:** no shame, health loss, stat decay, or broken
  streak copy. Comebacks are celebrated.
- **Local-first ownership:** the device save is authoritative. Firebase is an
  optional backup and appearance-only room sharing layer.
- **Accessible motion:** the in-app reduce-motion setting and OS animation
  preference park ambient effects and simplify celebrations.

The complete product specification lives in [`../DESIGN.md`](../DESIGN.md),
with the current art rules in [`../ART-PIPELINE.md`](../ART-PIPELINE.md).

## Run and verify

```sh
flutter pub get
flutter run
flutter analyze
flutter test
flutter build web --release --wasm
dart run tool/prepare_web_offline.dart
dart run tool/prepare_web_offline.dart --check
dart run tool/audit_pub_dependencies.dart
```

The web preparation step writes the versioned offline manifest consumed by the
Room of Days service worker. Firebase Hosting runs it again immediately before
deploy and refuses stale or incomplete web output.

Visual render dumps are generated with:

```sh
flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/screenshots_test.dart
```

Open the PNGs in `test/goldens/` after any visual change.

## Protected place search

Manual event, task, and class locations remain device-local and work without
Firebase or Google. In ordinary builds, the optional Google place-search UI and
callable construction path are disabled because `PLACE_SEARCH_ENABLED`
defaults to `false`; the platform plugin dependency may still be registered.
When explicitly enabled, its client sends requests only through authenticated
Firebase callables. The Google server key never belongs in Flutter, a Dart
define, web output, or repository text.

The owner-only activation sequence, cost guards, App Check rollout, and stop
conditions are in [`functions/README.md`](functions/README.md). Checked and
public builds must remain at the default `false` until every gate in that
runbook and [`RELEASE-CHECKLIST.md`](RELEASE-CHECKLIST.md) is complete. Source
readiness is not permission to deploy Functions, attach billing, create a
secret, or enable the flag.

## Structure

- `lib/engine.dart` — XP, stats, streaks, rewards, achievements, and rollover
- `lib/models.dart` — persisted goals, quests, notes, and reward models
- `lib/storage.dart` — validated local JSON persistence and user-held backups
- `lib/cloud.dart` — optional Firebase auth, save mirror, and shared spaces
- `lib/screens/` — the five primary destinations and detail flows
- `lib/widgets/` — the room, tapestry, quest cards, glass, and celebrations
- `lib/content/` — offline quest, evidence, cosmetic, and progression catalogs
- `functions/` — protected callable boundaries for optional Google place search
  and scoped anonymous service-identity removal

## Release setup still requiring owner credentials

- Android Firebase is registered for `com.mikabe.emberkeep`; cloud options are
  checked in for Android, iOS, and web.
- Android release builds intentionally fail until the ignored
  `android/key.properties` points to the owner’s private Play upload keystore.
- iOS signing/App Store setup is documented in
  [`../NATIVE-iOS.md`](../NATIVE-iOS.md).
- Owner procedures for off-app account deletion and password recovery are in
  [`ACCOUNT-DELETION-RUNBOOK.md`](ACCOUNT-DELETION-RUNBOOK.md) and
  [`ACCOUNT-RECOVERY-RUNBOOK.md`](ACCOUNT-RECOVERY-RUNBOOK.md).
- The exact physical Android/iPhone release pass is in
  [`DEVICE-ACCEPTANCE-RUNBOOK.md`](DEVICE-ACCEPTANCE-RUNBOOK.md).
- Store-console copy, privacy answers, screenshots, and remaining owner gates
  are tracked in [`RELEASE-CHECKLIST.md`](RELEASE-CHECKLIST.md) and
  [`STORE-LISTING.md`](STORE-LISTING.md).
