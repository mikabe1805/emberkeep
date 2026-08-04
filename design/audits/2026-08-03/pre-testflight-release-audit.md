# Room of Days pre-TestFlight release audit

Date: 2026-08-03
Scope: the current family-feedback candidate, including the Journal Quest
handoff, read-first journal history, visitor-card privacy, sharing, arrangeable
My Space cards, and release configuration.
Decision state: ready to make a phone build. The final local verification gate
passed, and the repaired Firestore rules, web invite route, and public privacy
copy are deployed.

## Evidence used

- Whole-product phone review:
  `design/comparisons/2026-08-03/current-system-review-phone.webp`.
- My Space, Circle, and visitor profile:
  `design/comparisons/2026-08-03/my-space-circle-visitor-pass.webp`.
- Arrangeable My Space cards and editor:
  `design/comparisons/2026-08-03/my-space-cards-phone.webp`.
- Complete room identities:
  `design/comparisons/2026-08-03/complete-room-system-phone.webp`.
- First run and Journal:
  `design/comparisons/2026-08-03/first-run-me-journal-audit-phone.webp`.
- Night and morning ledger:
  `design/comparisons/2026-08-03/routine-ledger-phone-after.webp`.
- Controlled Quest-button light states:
  `design/comparisons/2026-08-03/button-light-controlled-phone.webp`.
- Sharing, journal read mode, card privacy, and reactive metal:
  `design/comparisons/2026-08-03/sharing-journal-privacy-pass.webp`.

These are deterministic production-widget captures at the audited phone
viewport, not mockups. They establish current composition, copy, hierarchy,
room continuity, and responsive layout. They do not establish native sensor
feel, notification delivery, resume timing, or the platform share sheet.

## Numbered end-to-end health review

1. **First launch, name, and re-entry — healthy in current evidence.** Room of
   Days is now the public identity, the new mark reads clearly at phone size,
   naming remains optional, and the morning ledger is designed to greet a due
   user on cold start or resume. The first-run and whole-product sheets show a
   coherent entry into the same warm room system.
2. **Quest board and ordinary completion — healthy.** The current system sheet
   preserves one obvious honey-gold action, legible Quest hierarchy, readable
   rewards, and a calm completed state. Ordinary Quests retain their established
   check-off behavior. The featured action now treats the room light as fixed:
   resting-hand jitter is filtered out, while an intentional tilt rolls one
   broad satin reflection across the metal without an autonomous shimmer.
3. **Authored Journal Quest handoff — locally verified.** Selecting one opens
   its dedicated autosaving Journal page. An
   empty visit never counts, meaningful saved writing completes once on return,
   and the same Quest on the same day resumes its linked page. The fresh focused
   phone capture shows the dedicated doorway and page without clipping or
   overlap after the long-heading correction.
4. **Night close and morning return — healthy in current visual evidence.** The
   routine sheet preserves the full-screen night ritual, optional reflection,
   gratitude, discovery, and tomorrow-message paths, followed by the matching
   morning ledger. Native scheduling and resume behavior remain phone checks.
5. **Journal and Calendar — healthy for the verified feedback scope.** The
   current Journal evidence shows the personal writing hierarchy, contextual
   daily trace, photo-led memory treatment, and entry resurfacing. Historical
   entries now open as pages to read with an explicit Edit action, and guided
   prompt text uses a distinct accent, italic face without changing stored
   text. Multi-photo, location, autosave, and day-linked Calendar behavior are
   covered by the regression pass; the Quest-to-page route is gated separately
   in item 3.
6. **My Space and room personalization — healthy.** The dedicated sheets show
   an authored four-card page that keeps the room as its hero, plus a
   full-screen arranger for reordering, hiding, revealing, and editing cards.
   About, Right now, Pinned moments, and This season use distinct materials;
   the seasonal card can draw an optional photo from the Journal. Cancel and
   Save have explicit draft semantics. Visitor sharing remains opt-in, and each
   of the four cards now has its own audience choice. Shared pinned/seasonal
   cards publish bounded writing only. Profile and This season each offer a
   separate, off-by-default visitor-photo consent; every other journal photo and
   private arrangement state stay local. All three room choices read as complete authored interiors
   and use the same depth model.
7. **Share, Visit, and Circle — repaired and deployed.** Share now distinguishes
   backend permission, connectivity, timeout, and exhausted-code failures;
   stale codes rotate safely. The dialog leads with the code, offers the native
   share surface, and includes a browser/PWA invite URL that preloads the room.
   Visitor rooms include the chosen display name and selected profile cards.
   Invite copy keeps that name anonymous while the visitor page is closed. A
   best-effort owner-only Circle receipt appears after another account saves the
   room, and the owner now receives a one-time in-app notice at startup/resume
   without having to open Circle first. Unsharing/reset/account deletion clear
   receipt subcollections before removing the room, and production rules reject
   older-client schema downgrades. Every social call now rejects malformed room
   codes before constructing a Firestore document path, stale missing/non-owned
   codes detach locally during cleanup. Anonymous social sign-in and every
   account identity change share one mutex, so simultaneous startup, backup,
   sharing, and account work cannot race. Failed reset cleanup keeps an
   owner-tagged retry queue and will not discard the only credential capable of
   removing a room. The matching web build and privacy copy are live.
8. **Accessibility and resilience — healthy in automated/layout evidence.**
   The family-feedback pass covers the affected My Space, its card arranger,
   Personalize, Circle, Visit, Share, and Calendar surfaces at 320 x 568 with
   2.0x text, plus Reduced Motion and practical touch targets. Reward receipts,
   achievement toasts, level-ups, streak milestones, and epic clears now honor
   both the in-app preference and the operating-system setting by showing a
   readable final state without particles, travel, scale slams, or chest motion.
   A real iPhone remains the truth for dynamic type comfort, frame pacing,
   haptics, and native overlays.
9. **Native release configuration — corrected locally; signing remains
   external.** The candidate includes foreground notification delegation, a
   CocoaPods fallback for plugins without Swift Package Manager support, and a
   privacy-manifest entry for the optional visitor text. App Store signing,
   Codemagic's selected Xcode image, and distribution credentials cannot be
   proven from this workspace.

## Severity and release gates

### P0 — stop-ship

No P0 defect is identified in the current static, widget, and visual evidence.

### P1 — closed in this pass

1. Keep the frozen candidate green. Its final focused tests, full Flutter suite,
   analysis, and release web build all passed on August 3, 2026.
2. Firestore rules compiled and were deployed to `emberkeep-5b33b` before the
   updated hosting release.
3. The updated app and privacy page were deployed to
   `https://emberkeep-5b33b.web.app`; both the invite route and privacy page
   returned HTTP 200.

### P2 — validate in the next phone build

1. Judge whether tilt-driven shine follows an implied light source naturally
   without reacting to every small hand tremor, and watch native frame pacing
   while scrolling each room.
2. Confirm night-reminder permission, foreground presentation, chosen-time
   delivery, after-midnight ownership, and daylight-saving behavior.
3. Confirm morning auto-open on cold launch and resume without duplicate or
   stacked routines.
4. Exercise the native share sheet, WhatsApp when installed, code copying, the
   dialog's Done action, a valid visit, an invalid visit, retry, and Circle save.
5. Check the Journal Quest path by opening and abandoning it empty, resuming it,
   saving meaningful writing, returning to Quests, and verifying exactly one
   completion and reward.
6. Reorder and hide My Space cards, cancel one draft, save another, choose a
   seasonal Journal photo, relaunch, and confirm the arrangement persists.
   Share the room and verify that only visitor-selected cards appear, selected
   pinned/seasonal writing appears in the chosen order, and all journal photos
   remain absent from the visitor page.

These P2 checks are the reason to produce the TestFlight build; they are not
known defects and do not justify adding more features before device feedback.

## Verification

- Dedicated Journal Quest and bookplate checks: passed, including legacy-save
  enrichment, immediate-back autosave, 2x text, and accessibility semantics.
- Dedicated My Space state, UI, privacy-payload, large-text, visitor-profile,
  journal read-mode, and cloud-merge suites: passed.
- Dedicated reward Reduce Motion checks: 5/5 passed.
- Full Flutter suite: 237/237 tests passed.
- `flutter analyze`: passed with no issues.
- `flutter build web --release`: passed; the WebAssembly dry run also passed.
- Controlled button-light capture: passed and inspected at original detail;
  ordinary hold jitter is parked and deliberate left/right tilt moves the same
  broad reflection monotonically.
- Fresh Journal Quest route capture: passed and inspected at original detail;
  compact evidence is
  `../../comparisons/2026-08-03/journal-quest-doorway-phone.webp`.
- Firestore rules: compiled and deployed to production successfully.
- Authenticated production smoke: two temporary anonymous identities created a
  v4 room, loaded it by exact code with its display name, could not enumerate
  rooms, could not downgrade v4 to v3, delivered an owner-only Circle receipt,
  and read that receipt as the owner. Temporary room, receipt, and identities
  were removed afterward.
- Bad-request hardening: malformed room codes are rejected locally across all
  social operations, missing/non-owned stale codes no longer abort cleanup,
  every Firebase identity mutation is serialized with anonymous-session
  initialization, and failed reset cleanup retains an owner-aware retry queue.
- Hosting: release deployed successfully; invite, privacy, and deletion routes
  returned HTTP 200, and the hosted privacy page includes the receipt disclosure.

Current recommendation: freeze the Room of Days feature scope and produce the
phone build. The next round should be driven by real-device feel rather than
another speculative feature pass.
