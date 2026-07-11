# Emberkeep — Project Context for AI Agents

## Overview
Emberkeep is a gamified habit-tracker / life-RPG mobile app. "Min-max your real life" — your character sheet IS you. Built with Flutter. Android-first, iOS second; also ships as an installable PWA.

**Round-63 art pivot (locked):** there is **no companion creature**. The product fantasy is **cozying up your keep** — a code-painted room whose hearth burns when you keep your streak. Read `ART-PIPELINE.md` (round-63 banner) before touching any art.

## Tech Stack
- **Flutter** (Dart) — UI framework
- **shared_preferences** — local-first JSON blob persistence (Drift/SQLite still planned when history outgrows the blob)
- **audioplayers** — event sounds (soft synth pops)
- **google_fonts** — Fraunces (display/numerals), Inter (body), JetBrains Mono (labels)
- **Firebase** — Auth (anonymous + email/password) + Firestore save mirror + optional room sharing. Local save stays source of truth; cloud is backup.
- **flutter_local_notifications** — native daily nudge (web stub)

## Design Philosophy
Read DESIGN.md (parent directory) for full spec. Key principles:
1. **Juice-first**: The completion moment is feature #1. 100ms acknowledgment rule.
2. **Never punish**: No HP, no decay, no guilt. Shields, rest days, comeback bonuses. Banned copy: "failed", "missed", "lost", "broke" (streaks say "paused").
3. **Cozy candlelit glass**: Dark espresso→plum canvas, warm honey-glass panels, hearth-centered keep. Light themes are off the table.
4. **One color per mechanic**: XP=honey, streak=ember, stats=6 warm hues, success=moss, quests=plum.
5. **Free forever**: Cosmetics earnable by play only.
6. **The keep is the star**: `widgets/home_room.dart` — hearth flame, furniture, walls, window view. No creature/portrait resurrection without an explicit owner ask.

## Project Structure
```
app/
  lib/
    main.dart          — entry point
    engine.dart        — XP/task/stats engine core
    models.dart        — data models
    storage.dart       — shared_preferences JSON persistence
    tokens.dart        — design tokens (colors, type, spacing)
    haptics.dart       — haptic feedback (honors reduceMotion)
    audio.dart         — sound system
    clock.dart         — testable "now" seam (use everywhere for day logic)
    cloud.dart         — Firebase auth + save mirror + rooms
    social.dart        — visit/share room helpers
    notifications.dart — local notifications
    journal_doc.dart   — journal entries
    journal_media*.dart — journal photo/media handling
    content/           — quest packs, evidence, cosmetics, achievements, …
    screens/           — Me, Quests, Goals, Plans, Insights, Shop, Journal, …
    widgets/           — home_room, glass, quest_card, receipts, overlays, …
    platform/          — web/native stubs (share, install, persist, notify)
  assets/              — sfx/, room/ grain, google_fonts/
  test/                — unit + widget + optional golden dumps
```

## Key Design Docs (in parent directory)
- `ART-PIPELINE.md` — **read first for any visual work.** Round-63: no creature; keep is the star; code-painted only.
- `DESIGN.md` — look/feel, game systems, stats, celebration, loot, collection
- `ROADMAP.md` — build phases
- `RESEARCH.md` — market/science evidence
- `STORE-LISTING.md` — app store / TestFlight copy

## Development Commands
```bash
flutter run                    # Run on connected device/emulator
flutter build apk              # Build Android APK
flutter build ios              # Build iOS
flutter build web --release    # PWA / Firebase Hosting
flutter test                   # Run tests
flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/screenshots_test.dart
flutter analyze                # Static analysis
dart format .                  # Format code
```

## Conventions
- Numbers always tick up visibly (animated count-ups), never just swap.
- Progress bars accelerate into the end, never stall near full.
- Celebration intensity is parameterized (scale particle count/vibrancy with magnitude).
- Full-screen celebrations rationed to milestones only.
- Honor reduce-motion (swap particles for fades; soften haptics via `Haptics.reduceMotion`).
- Stats never decay. No-punishment principle. Each stat bends a different feedback loop.
- Local-first, zero-cost infra. Everything works offline on-device.
- Day / streak / schedule logic must use `Clock.now()`, not raw `DateTime.now()`.
- Shop: try-on before buy for every not-owned item. Nothing renders blank.

## Current Phase
Core loop + goals + bookends + shop + journal + cloud accounts are shipped (past Phase 1 MVP depth). Open Phase 1/2 items: Drift migration, rest days, Trials, history constellation, richer evidence library, native push polish. Check ROADMAP.md for the full checklist.
