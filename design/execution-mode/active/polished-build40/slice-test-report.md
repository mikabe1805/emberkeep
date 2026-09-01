# Room of Days Build 40 slice report

Prepared September 1, 2026 from
`feature/build40-classes-widgets-focus` at base revision
`9defeba68894f1817ad0efd56f2b8f3cc973c368`.

## What is locally complete

- A valid, shareable class-schedule starter documents editable fields and
  comma-separated `BYDAY=MO,WE,FR` meeting days.
- Compatible `.ics` files received through the picker or native Open In/share
  handoff enter the same review-first flow. Nothing is saved automatically.
- Class reminders are off unless deliberately enabled during review. Ten,
  fifteen, and thirty-minute choices are available, permission follows intent,
  and an untouched re-import preserves the existing reminder decision.
- The versioned widget projection holds a bounded upcoming-class list and at
  most three actionable unfinished Quest titles. It excludes rooms, class
  locations, schedule notes, Journal content, and account details.
- The iOS small widget shows the next class. The medium widget adds up to three
  unfinished Quests. Its timeline advances at included class-end boundaries
  without requiring the app to be reopened, and both families are marked
  privacy-sensitive.
- Focus uses the existing Fable room theme as an optional session atmosphere.
  It can be made quiet in one tap and restores the app-wide music preference
  when the timer closes.
- Build 40 has matching in-app release notes, TestFlight instructions, reviewer
  notes, public description, privacy disclosure, and a device-gated ten-frame
  App Store story.

Android Open In/share support is included and the Android app builds. An
Android home-screen widget is not part of this App Store-first slice.

## Visual inspection

The import review, Focus timer, and What's New surfaces were freshly rendered
at 430x932 and on compact large-text phones. The first pass exposed two real
layout problems: the starter action row could overflow and the Focus clock
could wrap at 320x568. Both were corrected before the final captures. The
reminder decision now appears before the course list, the timer stays on one
line, normal-height Focus content is centered, and compact content remains
scrollable.

The owner rejected the book-ledger direction as the storefront hook and chose
Open Door of Light from three new world-first options. The approved opaque
master was preserved unchanged. Review sheets compare it with the outgoing
Room of Days icon and Room Notes at 1024, 180, 60, and 32 pixels plus square,
iOS, Android, safe-area, and grayscale/themed masks. The singular threshold and
contained honey path remain clear at 32 pixels. The production exporter then
propagated it across iOS, Android legacy/adaptive/themed, web, Windows, and
maskable outputs; the final shipping sheet was opened at original resolution.
The fresh Android debug APK was then installed on an emulator. In the labeled
app drawer, Open Door of Light remains centered and unclipped, separates cleanly
from Room Notes, and reads as a warm threshold at real adaptive-launcher size.

## Deterministic validation

- Full `flutter test --no-pub`: **1,093 passed**. The one Journal assertion that
  had been tapping an off-screen card now brings the card into view first; its
  focused replay passes without the hit-test warning.
- `flutter analyze --no-pub`: **pass**, no issues.
- `flutter build apk --debug --no-pub`: **pass**. Local artifact:
  `build/app/outputs/flutter-apk/app-debug.apk`, 190,960,901 bytes, SHA-256
  `0206B4C1BDC08505EB555DBE2F706A7DC4C9C1F2F1141857079F10F17CB2A272`.
- `flutter build web --release --no-pub`: **pass**; the Wasm dry run also
  passed.
- Store verification: names, character limits, URLs, privacy claims, version
  `1.0.4+40`, and current in-app notes pass. It then stops exactly where it
  should: the checked-in App Store screenshot manifest still names Build 39.
- Icon verification: **14 focused tests passed** across deterministic export,
  committed hashes, RGB/alpha contracts, review guards, and shipping output.
- Repository whitespace verification has no errors; Flutter only reports the
  repository's normal Windows line-ending notices.

## Remaining release gates

This Windows host cannot compile or sign the new WidgetKit extension. The exact
candidate still needs a macOS archive with the App Group enabled for Runner and
the widget extension, followed by cold and warm `.ics` handoff, notification
permission, widget empty/populated/redacted states, class-boundary refresh,
background/resume, upgrade, VoiceOver, Largest Text, and Reduced Motion checks
on a physical iPhone.

The Fable mix also needs owner listening on the phone speaker and headphones.
The selected icon has passed Android emulator launcher inspection but still
needs physical-iPhone and physical-Android inspection. Only after those gates
should the real Home Screen widget be photographed, the ten App Store frames be
recaptured and inspected, and the Build 40 screenshot manifest be bound. No
TestFlight upload or public App Store submission has been performed or
authorized.

The local Android release command also stops deliberately because the private
upload keystore is not present in this worktree. The unsigned debug APK and web
release both package successfully; signed Android distribution remains an
account/credential gate rather than a source failure.

## Verdicts

- `code_complete`: **pass for the locally provable source scope**. Dart,
  Android, web, and reviewed iOS source are complete; a signed iOS compile is
  still open.
- `visual_evidence_ready`: **pass for import, Focus, What's New, and the selected
  shipping icon**. The final App Store screenshot set is intentionally not ready.
- `owner_device_accepted`: **pending**.
