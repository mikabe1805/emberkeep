# Room of Days pre-TestFlight release audit

Date: 2026-08-03
Scope: the current family-feedback candidate, including the Journal Quest
handoff, arrangeable My Space cards, and release configuration.
Decision state: ready to make a phone build; the final local verification gate
passed. Production social testing additionally requires the two explicit
release operations listed below.

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
   daily trace, photo-led memory treatment, and entry resurfacing. Multi-photo,
   location, autosave, and day-linked Calendar behavior are covered by the
   existing regression pass; the new Quest-to-page route is gated separately
   in item 3.
6. **My Space and room personalization — healthy.** The dedicated sheets show
   an authored four-card page that keeps the room as its hero, plus a
   full-screen arranger for reordering, hiding, revealing, and editing cards.
   About, Right now, Pinned moments, and This season use distinct materials;
   the seasonal card can draw an optional photo from the Journal. Cancel and
   Save have explicit draft semantics. Visitor sharing still requires opt-in,
   respects hidden About and Right now cards, and excludes pinned/seasonal
   content and private arrangement state. All three room choices read as
   complete authored interiors and use the same depth model.
7. **Share, Visit, and Circle — locally coherent; production backend update
   required.** The social sheet shows clear sharing, code entry, visitor
   boundaries, and trusted-space states. The checked-in rules accept the new
   bounded visitor payload and compiled in a dry run, but production rules have
   not been deployed. The current public privacy update has also not been
   hosted.
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

### P1 — complete before production behavior is judged

1. Keep the frozen candidate green. Its final focused tests, full Flutter suite,
   analysis, and release web build all passed on August 3, 2026.
2. Deploy the checked-in Firestore rules before testing Share, Visit, or Circle
   against production. The dry run proved compilation only; no deployment was
   performed.
3. Publish the updated privacy page before wider external distribution of the
   visitor-profile feature. The local copy is corrected; hosting was not
   changed by this pass.

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
   Share the room and verify that hidden About/Right now values and all
   pinned/seasonal content remain absent from the visitor page.

These P2 checks are the reason to produce the TestFlight build; they are not
known defects and do not justify adding more features before device feedback.

## Verification

- Dedicated Journal Quest and bookplate checks: passed, including legacy-save
  enrichment, immediate-back autosave, 2x text, and accessibility semantics.
- Dedicated My Space state, UI, privacy-payload, large-text, visitor-profile,
  and cloud-merge checks: 34/34 passed.
- Dedicated reward Reduce Motion checks: 5/5 passed.
- Full Flutter suite: 221/221 tests passed.
- `flutter analyze`: passed with no issues.
- `flutter build web --release`: passed; the WebAssembly dry run also passed.
- Controlled button-light capture: passed and inspected at original detail;
  ordinary hold jitter is parked and deliberate left/right tilt moves the same
  broad reflection monotonically.
- Fresh Journal Quest route capture: passed and inspected at original detail;
  compact evidence is
  `../../comparisons/2026-08-03/journal-quest-doorway-phone.webp`.
- Firestore rules dry run: passed; production deployment not performed.
- Public privacy page: corrected locally; hosting deployment not performed.

Current recommendation: freeze the Room of Days feature scope and produce the
phone build. The next round should be driven by real-device feel rather than
another speculative feature pass.
