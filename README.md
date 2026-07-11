# Emberkeep

Emberkeep is a local-first life RPG for Android, iOS, and the web. Completing
real-life quests grows six life domains, earns XP and embers, and gradually
furnishes a candlelit keep whose hearth reflects the player's momentum.

The product is deliberately non-punitive: progress never decays, lapses never
erase earned growth, and all core functionality works offline. The keep and
hearth are the visual heart of the app; there is no companion creature.

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
- `lib/cloud.dart` — optional Firebase auth, save mirror, and shared keeps
- `lib/screens/` — the five primary destinations and detail flows
- `lib/widgets/` — the keep, quest cards, glass primitives, and celebrations
- `lib/content/` — offline quest, evidence, cosmetic, and progression catalogs

## Platform setup still requiring owner credentials

- Android Firebase must be registered for package `com.mikabe.emberkeep` and
  regenerated with FlutterFire before cloud accounts/sharing work on Android.
- A Play release keystore must replace the development debug signing config.
- iOS signing/App Store setup is documented in [`../NATIVE-iOS.md`](../NATIVE-iOS.md).
