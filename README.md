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
flutter build web --release
```

Visual render dumps are generated with:

```sh
flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/screenshots_test.dart
```

Open the PNGs in `test/goldens/` after any visual change.

## Structure

- `lib/engine.dart` — XP, stats, streaks, rewards, achievements, and rollover
- `lib/models.dart` — persisted goals, quests, notes, and reward models
- `lib/storage.dart` — validated local JSON persistence and user-held backups
- `lib/cloud.dart` — optional Firebase auth, save mirror, and shared spaces
- `lib/screens/` — the five primary destinations and detail flows
- `lib/widgets/` — the room, tapestry, quest cards, glass, and celebrations
- `lib/content/` — offline quest, evidence, cosmetic, and progression catalogs

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
- Store-console copy, privacy answers, screenshots, and remaining owner gates
  are tracked in [`RELEASE-CHECKLIST.md`](RELEASE-CHECKLIST.md) and
  [`../STORE-LISTING.md`](../STORE-LISTING.md).
