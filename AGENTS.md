# Emberkeep — Project Context for AI Agents

## Overview
Emberkeep is a gamified habit-tracker / life-RPG mobile app. "Min-max your real life" — your character sheet IS you. Built with Flutter + Rive + local SQLite (Drift). Android-first, iOS second.

## Tech Stack
- **Flutter** (Dart) — UI framework
- **Rive** — vector companion animation (ember.riv)
- **Drift** (SQLite) — local-first persistence, offline-first
- **audioplayers** — event sounds
- **google_fonts** — Fraunces (display/numerals), Inter (body), JetBrains Mono (labels)
- **Firebase** — optional, later (auth, social, FCM notifications)

## Design Philosophy
Read DESIGN.md (parent directory) for full spec. Key principles:
1. **Juice-first**: The completion moment is feature #1. 100ms acknowledgment rule.
2. **Never punish**: No HP, no decay, no guilt. Shields, rest days, comeback bonuses.
3. **Cozy liquid glass aesthetic**: Warm honey-glass panels, parchment canvas, specular highlights.
4. **One color per mechanic**: XP=honey, streak=ember, stats=6 warm hues, success=moss, quests=plum.
5. **Free forever**: Cosmetics earnable by play only.

## Project Structure
```
app/
  lib/
    main.dart          — entry point
    engine.dart        — XP/task/stats engine core
    models.dart        — data models
    storage.dart       — Drift/SQLite persistence
    tokens.dart        — design tokens (colors, type, spacing)
    haptics.dart       — haptic feedback
    audio.dart         — sound system
    clock.dart         — streak/day tracking
    cloud.dart         — Firebase (optional)
    social.dart        — social features
    notifications.dart — local notifications
    journal_doc.dart   — journal entries
    journal_media*.dart — journal photo/media handling
    content/           — quest packs, evidence cards, skins
    screens/           — app screens/pages
    widgets/           — reusable UI widgets (portrait, cards, etc.)
    platform/          — platform-specific code
  assets/              — rive, audio, images
  test/                — unit + golden tests
```

## Key Design Docs (in parent directory)
- `DESIGN.md` — look/feel, game systems, stats, celebration, loot, collection
- `ROADMAP.md` — build phases (Phase 0: feel prototype → Phase 5: ML verification)
- `RESEARCH.md` — market/science evidence backing design decisions
- `RIVE-EMBER-SPEC.md` — Rive companion creature authoring spec
- `STORE-LISTING.md` — app store copy

## Development Commands
```bash
flutter run                    # Run on connected device/emulator
flutter build apk              # Build Android APK
flutter build ios              # Build iOS
flutter test                   # Run tests
flutter test --golden           # Run golden tests
flutter analyze                 # Static analysis
dart format .                   # Format code
```

## Conventions
- Numbers always tick up visibly (animated count-ups), never just swap.
- Progress bars accelerate into the end, never stall near full.
- Celebration intensity is parameterized (scale particle count/vibrancy with magnitude).
- Full-screen celebrations rationed to milestones only.
- Honor reduce-motion (swap particles for fades).
- Stats never decay. No-punishment principle.
- Each stat bends a different feedback loop (STR=crit chance, INT=XP rate, etc.).
- Local-first, zero-cost infra. Everything works offline on-device.

## Current Phase
Check ROADMAP.md for current phase. The feel prototype (Phase 0) and core loop MVP (Phase 1) are the immediate priorities.