# Room of Days — Project Context for AI Agents

## Overview
Room of Days is a gamified habit-tracker / life-RPG mobile app. "Min-max your real life" — your character sheet IS you. Built with Flutter. Android-first, iOS second; also ships as an installable PWA.

**Room of Days direction (locked):** there is **no companion creature**. The public mark is **The Day Ledger**: an open quest ledger with one completed honey-gold medallion and two unfinished Room of Days completion rings. The former isometric room-and-sun mark remains archived provenance only. **The Woven Dawn** remains a permanent room object: it grows with level and never unweaves. It is a quiet long-term record, not the narrator, everyday Quest HUD, or the app's claim about a user's future. Ordinary completions visibly feed XP and the six-stat build; the code-painted room carries long-term change. The fireplace stays ambient furniture, never health or progression. Read `../ART-PIPELINE.md` before touching any art.

**Compatibility identifiers (locked):** keep the existing package name, bundle ID `com.mikabe.emberkeep`, Firebase project `emberkeep-5b33b`, serialized field names, Firestore fields, and preference keys unless a deliberate migration is designed and tested. These internal legacy identifiers are not public brand copy.

**Visual work (locked):** read `C:/Users/mikus/soul/MIKA.md`,
`DESIGN-BIBLE.md`, `VISUAL-WORKFLOW.md`, and the relevant approved target and
current screenshot before changing UI, art, motion, type, or sound. The design
bible overrides older visual prescriptions in `DESIGN.md`, `VISUAL-AUDIT.md`,
and historical QA sections. Never judge a visual pass from code, tests, or file
paths alone.

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
3. **Cozy candlelit glass**: Dark espresso→plum canvas, warm honey-glass panels, room-centered long-term progression. Light themes are off the table.
4. **One color per mechanic**: XP=honey, continuity=amber, stats=6 warm hues, success=moss, quests=plum.
5. **Free forever**: Cosmetics earnable by play only.
6. **The room is the long game**: `widgets/home_room.dart` — quiet tapestry, ambient hearth, furniture, walls, window view. No creature/portrait resurrection without an explicit owner ask.
7. **Game-first language**: quests feed XP and the six-stat build. The tapestry appears where it is literally visible or where a level changes it; do not narrate ordinary actions as weaving a future. Spendable currency is Glimmers and Gentle Mode keeps its plain name.

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

## Key Design Docs
- `DESIGN-BIBLE.md` — **canonical current visual and interaction system**, including materials, light, motion, geometry, screen contracts, and definition of visual done.
- `VISUAL-WORKFLOW.md` — mandatory baseline, implementation, comparison, QA, record, and phone-handoff procedure.
- `../ART-PIPELINE.md` — production-art roles, source provenance, room construction, and historical pivots. Read for any art or image work.
- `../DESIGN.md` — product systems, stats, celebration, loot, and collection. Its historical visual sections do not override the design bible.
- `design/visual-targets/2026-07-30/` — selected five-screen and routine visual sources.
- `design-qa.md` — comparison history and superseded implementation findings.
- `../ROADMAP.md` — build phases
- `../RESEARCH.md` — market/science evidence
- `STORE-LISTING.md` — versioned app store / TestFlight copy

## Development Commands
```bash
flutter run                    # Run on connected device/emulator
flutter build apk              # Build Android APK
flutter build ios              # Build iOS
flutter build web --release --wasm # PWA / Firebase Hosting (JS fallback included)
flutter test                   # Run tests
flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/screenshots_test.dart
python tool/visual_compare.py review
python tool/visual_compare.py review-phone
python tool/visual_compare.py system
python tool/visual_compare.py focus
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
- Visual changes start and end with fresh rendered evidence. Put the approved
  source and current build in the same comparison image and inspect both the
  full frame and focused high-risk details.
- A generated concept is a material, composition, and interaction source—not
  a rigid poster. Keep live content live and let it reflow without losing the
  source's physical logic.
- Optical alignment beats coordinate alignment. Register live content and
  controls to the visible page, cover, frame, and inner rule rather than raw
  transparent bounds.
- Final visual handoffs must attach current images again with absolute paths;
  tool-viewed images and local tabs are not assumed to remain visible on the
  owner's phone.

## Visual Definition of Done

A visual pass is not done until the relevant resting, scrolled, completed,
long-content, narrow, large-text, and Reduced Motion states have been rendered
and inspected. There must be no visible crop seam, alpha halo, overlap, tiny
text, detached ornament, cheap solid fill, conflicting material generation,
or second competing bright action. Working interactions, focused tests,
analysis, and a release build still need to pass in proportion to the change.
Use `VISUAL-WORKFLOW.md` for the exact procedure.

## Current Phase
Core loop + goals + bookends + shop + journal + cloud accounts are shipped (past Phase 1 MVP depth). Open Phase 1/2 items: Drift migration, rest days, Trials, history constellation, richer evidence library, native push polish. Check ROADMAP.md for the full checklist.
