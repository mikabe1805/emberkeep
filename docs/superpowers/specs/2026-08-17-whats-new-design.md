# Room of Days What's New Design

## Scope

Room of Days will show a calm, full-screen What's New card once after every
build that is actually released to users. Internal build attempts that never
ship do not count. The content model should be reusable when Room Notes gains
the same feature later, but this implementation changes only Room of Days.

## Approved behavior

- Show the current release once on the first ordinary launch after an update.
- Onboarding and an opened room link take priority. What's New then takes
  priority over Morning Flow so full-screen experiences never stack.
- A fresh install skips What's New because onboarding owns that moment.
- The automatic screen has both a quiet close control and one luminous
  `KEEP GOING` action. Neither requires scrolling, trying a feature, or moving
  through a tour.
- Claim the release as seen before showing it. If the app closes or crashes
  while the screen is open, it must not trap the person in a repeat.
- Keep seen state on the device, outside the game save and cloud mirror.
- Add `WHAT'S NEW` under Me settings so current and older notes can always be
  reopened.

## Release policy and content

Each release is a checked-in immutable record with:

- a stable ID matching the shipped `version+build` value;
- a display version and date;
- a short outcome-led title and introduction;
- two to four factual user-visible highlights with an icon, title, and body.

The newest record is the current release. Records remain newest-first so the
manual screen becomes a small release archive without another service or
network request. The release checklist and automated tests must catch a
current release ID that drifts from `pubspec.yaml` or
`release-candidate.json`.

The inaugural record is `1.0.1+13` and describes the academic daybook already
present in this source:

- Plans now keeps classes, assignments, and exams together.
- Course work can carry due dates, details, and completion state.
- Month, week, three-day, and day views are available, and the chosen view is
  remembered.

Copy stays direct and factual. It does not demand that a feature be tried,
overstate the app's role in someone's life, or use guilt language.

## Visual and interaction design

This is an extension of the approved pushed-screen system, not a new visual
direction. Reuse the current `WarmBackground`, faceted `GlassPanel`, brass
medallions, Fraunces/Inter/JetBrains Mono type roles, and one `GoldSurface`
action. No new raster art is required.

The automatic first frame contains:

1. a quiet close control in the upper-right;
2. `WHAT'S NEW` and the release version as compact metadata;
3. one Fraunces outcome-led title;
4. one glass release card containing two to four readable highlights;
5. one full-width `KEEP GOING` gold action.

The screen scrolls on short or large-text devices instead of shrinking live
copy. At 430 x 932 it should read as a composed single frame; at 320 x 568 and
large text it may scroll comfortably. There is no autonomous flourish beyond
the existing motivated background ambience. Reduce Motion and the operating
system animation preference park that ambience on its completed still.

The automatic overlay is modal for pointer, keyboard focus, and semantics.
The Quest board beneath it is not reachable by screen readers or hardware
keyboard focus. The manual archive uses normal Navigator back behavior and the
same release-card component.

## Architecture

- `lib/content/release_notes.dart` owns immutable release records and the
  current release ID.
- `lib/release_notes_preferences.dart` owns the single device-local seen-ID
  preference. It exposes a claim operation that returns true only when an
  existing install has an unseen release and the seen write succeeded.
- `lib/screens/whats_new.dart` owns the reusable automatic/manual screen and
  release-card presentation.
- `lib/screens/shell.dart` determines whether local storage was fresh, claims
  the current release during load, and coordinates launch order:
  room link -> onboarding -> What's New -> Morning Flow.
- `lib/screens/me.dart` adds the permanent manual entry immediately before
  About + Feedback.

The release preference never changes `GameState`, the save schema, exports,
cloud merge decisions, or account behavior.

## Failure behavior

- If preferences cannot be read or written, skip the automatic screen for
  that launch. The app remains usable and the manual archive remains present.
- If an unknown or empty catalog reaches the UI, show no automatic overlay;
  the manual screen presents a quiet empty state rather than crashing.
- A duplicate resume or post-frame callback cannot insert a second overlay.
- Dismissing What's New immediately re-runs the Morning Flow eligibility check.

## Verification

Automated coverage will prove:

- current release metadata matches both release files;
- a fresh install is marked seen without showing the screen;
- an existing unseen install shows it once;
- the seen write happens before display and suppresses later launches;
- onboarding and room links precede it, while it precedes Morning Flow;
- repeated resume cannot stack overlays;
- close and `KEEP GOING` both dismiss, and dismissal allows Morning Flow;
- Me can reopen the archive;
- underlying shell semantics are hidden while the automatic overlay is open;
- 320 x 568, large text, and Reduce Motion render without exceptions or
  overflow.

Final verification includes focused tests, `flutter analyze`, a release web
build, a fresh screenshot of the automatic screen, and direct visual
inspection at normal and narrow/large-text sizes.
