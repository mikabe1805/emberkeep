# Room of Days Release Candidate and App Icon Design

Status: the direction was approved in conversation on 2026-08-19. This written
specification is awaiting owner review before implementation begins.

## Purpose

This pass turns the current Room of Days source into the strongest honest
release candidate: stable, cohesive, visually finished, understandable on a
first visit, safe to update, and ready for a deliberate App Store decision.
It is a release-quality pass, not a feature sprint.

The approved App Store build remains an immutable reference point. The work in
this specification prepares a newer candidate and does not silently alter,
withdraw, submit, release, or message anyone through App Store Connect or
email. Those external actions require a final owner decision after the
candidate and its evidence are ready.

## Release truth on 2026-08-19

The release plan must begin from the evidence that exists now rather than the
older local checklist state:

- Apple's submission-complete email says App Store Version 1.0, Build 19 is
  eligible for distribution. The immediately following welcome email says the
  app was approved for distribution and may take up to 24 hours to appear
  after release.
- The local release checklist configured Version 1.0 for automatic release
  after approval. The approved build may therefore be processing for
  distribution even though the owner expected to hold it.
- An official US catalog lookup returned no result and the direct App Store
  product URL returned 404 when checked on 2026-08-19. This proves only that the
  listing was not publicly visible at that check; it does not prove that
  automatic distribution stopped.
- Apple Developer Support said the submission had not been forgotten, was
  proceeding through review, and required no action. The approval emails that
  followed contain no rejection, policy concern, or support-readiness defect
  to fix.
- Apple's TestFlight email confirms Version 1.0.3, Build 21 became available to
  test on 2026-08-18. Local documentation that describes Build 21 as pending is
  stale.
- The source version is `1.0.3+21`, while `release-candidate.json` still names
  `1.0.2+20`. The store-submission verifier correctly fails on that mismatch.
  Build 21 is therefore a test build, not a fully reconciled release candidate.
- The support mailbox contains no real inbound customer or tester message to
  incorporate. The only matching item is an empty unsent draft. The mailbox
  route may be configured, but successful delivery from an outside sender has
  not been evidenced.

Before any store action, the owner will check the live App Store Connect status
and agreements. The candidate uses the following interpretation:

| Observed store state | Release interpretation |
| --- | --- |
| Build 19 is public | It is the production baseline; the polished candidate ships as an update. |
| Build 19 is processing for distribution | Do not disrupt propagation during polish; treat the candidate as the next update unless the owner explicitly chooses otherwise. |
| Version 1.0 is still pending developer release | Keep it held while the candidate is prepared, then make an explicit keep-or-replace decision. |
| Contracts are blocking distribution | Resolve the agreement state in App Store Connect before claiming the app is released. |

## Product outcome

A successful candidate should feel like one authored product at every scale:

- the first few minutes explain the core rhythm without a manual;
- the daily loops respond immediately and never shame a missed day;
- the five main destinations, Daybook, settings, and account/support routes
  share one hierarchy and interaction language;
- typography, light, texture, spacing, motion, and controls remain readable and
  restrained on both a large phone and a small phone;
- existing saves, recurrence identities, quests, rooms, cloud data, and Room
  Notes handoffs survive an upgrade;
- public support and recovery routes are discoverable and actually reachable;
- release metadata names exactly one build and can be reproduced from source;
- the app icon represents the product at small size rather than merely looking
  attractive in isolation.

“Polished” means visible cohesion, calm interaction feel, complete edge states,
and verified reliability. A successful compile alone is not acceptance.

## Scope boundaries

This pass includes:

- a fresh visual and interaction audit of the shipping flows and important
  alternate states;
- focused corrections to hierarchy, spacing, readability, motion, response,
  copy, accessibility, and visible defects found in that audit;
- regression coverage for every behavior changed;
- a controlled app-icon decision using the current icon as a baseline and
  three grounded alternatives;
- support, privacy, deletion, and password-recovery discoverability and
  end-to-end readiness;
- release identity reconciliation, complete automated verification, fresh
  visual evidence, production builds, TestFlight validation, and a final
  owner-controlled App Store handoff.

This pass does not include:

- adding another major feature, destination, progression system, or content
  mechanic;
- turning on Google Places. Manual locations remain available and the checked
  Places release flag remains off until its separate billing, secret, quota,
  privacy, and App Check gates are complete;
- replacing the existing candlelit desk and folio direction with a new design
  system;
- changing durable IDs, persistence keys, account ownership, recurrence
  semantics, Room Notes handoff identifiers, or Firebase data shape merely to
  make code tidier;
- forcing a new icon when the current icon wins the small-size comparison;
- withdrawing, submitting, releasing, or changing store availability without
  explicit owner confirmation.

## Audit contract

Implementation begins with fresh captures from the current source. Historical
screenshots can provide context but cannot stand in as final evidence. The
audit covers the complete core journey:

1. launch, onboarding, and first-room comprehension;
2. Morning Flow and Night Flow, including dismissal and interruption;
3. Home/Quests, Goals, Plans/Daybook, Rooms, and Me;
4. creating, completing, undoing, editing, and deleting representative items;
5. the reset/help path, What's New, About + Feedback, privacy, recovery, and
   account deletion;
6. empty, populated, long-content, success, validation-error, unavailable, and
   offline states;
7. return visits and upgrades, not only fresh installs.

Each applicable screen is captured at a normal large-phone size and at
320 x 568. Text scaling is checked at the normal setting and 200 percent.
Reduced Motion is checked separately. Long names, long localized-looking copy,
keyboard/focus states, system insets, and destructive confirmations are
included where relevant.

The audit ranks findings by their effect on release trust:

1. blockers: data loss, dead ends, inaccessible essential actions, crashes,
   severe overflow, or misleading release/support state;
2. high priority: confusing hierarchy, broken primary flow, inconsistent
   response, unreadable content, or a repeated visual defect;
3. finish work: spacing, copy, motion, iconography, and surface consistency
   that materially improve the whole rather than decorate one screenshot.

Only observed findings are changed. Every visual change is compared against a
same-size before frame, and cross-cutting defects are fixed in their shared
source rather than masked one card at a time.

## Visual and interaction direction

The current authored visual language remains the source of truth: warm dark
room, book-cloth and folio structure, brass accents, soft motivated light,
Fraunces for expressive display type, Inter for readable interface text, and
JetBrains Mono for compact instrument metadata.

Polish follows these rules:

- One light field leads each frame. Added glow cannot flatten the hierarchy or
  turn every panel into a highlighted object.
- Readability wins over atmospheric translucency. Live text, inputs, state,
  and primary actions retain sufficient contrast in every captured state.
- Existing faceted geometry is refined consistently. New generic rounded-card
  styling, default platform blue, arbitrary gradients, and unrelated icon
  families are not introduced.
- The first meaningful response to a tap is immediate. Longer work exposes a
  calm pending state, ignores duplicate activation, and preserves the person's
  input if it fails.
- Primary targets remain at least 44 logical pixels and expose useful semantic
  labels. Important state is never communicated by color alone.
- Motion explains entry, completion, or spatial transition. Reduced Motion
  parks ambient movement and removes ornamental travel without hiding state.
- Copy remains direct, specific, and non-punitive. Missed or unfinished work
  is described as available to continue, not as failure.
- Short layouts scroll instead of shrinking readable copy. Large text may
  reflow and expand; compact metadata may be bounded only when the same
  information is available in readable semantics or adjacent detail.

No new artwork is generated for ordinary screen polish unless the fresh audit
finds a measured asset need. Existing approved art and tokens are reused.

## App icon decision

The current icon—a dark isometric room corner with brass structure and a warm
sun disc—is the baseline. It already has material depth and premium finish,
but the concern is valid: its emblem is not strongly repeated inside the app,
so recognition may come from style rather than product meaning.

After the audit establishes which motifs actually recur in the experience,
exactly three new icon directions will be produced:

1. **Inhabited room/world** — a simplified room or threshold shaped by the
   app's warm spatial light, emphasizing that the person is returning to a
   place rather than opening a utility.
2. **Completion latch/orbit** — a single compact form derived from the app's
   recurring completion and return interactions, emphasizing gentle forward
   motion without turning the icon into a streak badge.
3. **Daybook and light** — a restrained folio/page relationship with one warm
   light event, connecting held days and reflection without becoming a generic
   calendar glyph.

The tapestry is not the default direction. It was intentionally reduced to a
quiet room object and should not be promoted back into the product identity
without stronger evidence from the actual app.

All candidates use real generated artwork, no text, no tiny UI, and no
hand-drawn vector approximation. They are judged beside the current icon at
32, 60, and 180 pixels, in iOS masks and Android adaptive-icon safe areas, on
both light and dark surrounding fields. The chosen icon must:

- remain recognizable before its details are inspected;
- feel specifically connected to Room of Days;
- match the app's materials, warmth, and seriousness;
- avoid reading as a weather app, astrology app, generic journal, game token,
  or home-design tool;
- preserve a clear silhouette and focal point under platform masking;
- be strong enough to justify resetting existing recognition.

If none clearly beats the current icon, the current icon ships. Once selected,
the same master is propagated deliberately through iOS AppIcon assets,
Android legacy and adaptive assets, web/PWA icons, store artwork, and relevant
marketing surfaces. Automated checks verify dimensions and configuration;
small-size visual comparisons verify the artwork itself.

## Support and account readiness

Support should feel like a real path owned by the same person who made the app,
not a legal footer or a fictional company department.

- About + Feedback keeps `support@roomofdays.com` and a copyable fallback when
  the mail app cannot open.
- The prepared email includes concise prompts for expected behavior, actual
  behavior, and optional reproduction steps, plus non-sensitive app
  version/build and platform context. It never pre-fills journal content,
  account data, passwords, or private exports.
- About exposes direct, readable routes to the public support page, privacy
  policy, and account-deletion information. Me retains its existing account
  controls and About entry; the paths complement rather than duplicate one
  another.
- Public support copy is revised from an unsupported corporate “we” voice to
  the same honest Mika/Room of Days voice used in the app.
- The support page continues to warn people not to send passwords or
  unredacted journal exports and gives enough detail to report a bug usefully.
- An external sender completes a real delivery test to the support inbox. The
  test verifies receipt, sender, reply path, and spam placement without
  changing or deleting existing mail.
- A production-like password-reset cycle verifies the custom Firebase Auth
  email domain, link target, open-in-app/browser behavior, expired-link state,
  and successful sign-in after reset.
- Account deletion is checked both in-app and through the public request path,
  including its stated seven-day window and confirmation copy. No real account
  is deleted during verification unless the owner deliberately supplies a test
  account for that purpose.

Support-launch failure keeps the address and public support URL visible. Web
link failure never traps the person in a blank route. Recovery and deletion
errors preserve the account and explain the next safe action.

## Architecture and implementation boundaries

The fresh audit determines the smallest set of source changes. Expected areas
include shared visual primitives, the specific screens with evidenced issues,
About/Me support presentation, public support copy, icon asset catalogs, and
release metadata. Large files are split only when the correction needs a clear
boundary or test seam.

The following contracts remain stable:

- `GameState`, save migrations, recovery copies, cloud merge behavior, and
  existing preference keys preserve current data;
- academic and general Daybook stable IDs, occurrence exceptions, tombstones,
  and Room Notes handoff identifiers do not change;
- onboarding, room links, What's New, and Morning Flow retain a single
  non-stacking launch order;
- local-only Daybook data is not silently moved into analytics or cloud sync;
- Places remains disabled and manual location entry remains functional;
- support pages never expose secrets or require an account to read;
- the selected icon is an asset change, not permission for an unrelated visual
  redesign.

Every behavioral correction begins with a focused failing regression test.
Purely visual corrections receive a deterministic golden or comparison state
that demonstrates the old defect before the shared source is changed.

## Failure behavior

- Startup overlays cannot stack, reappear indefinitely, or block the main app
  after a preference read/write failure.
- A failed save, import, export, recovery, account, or support action keeps the
  person's input and provides a safe retry or fallback.
- Offline state never disables local rooms, quests, reflections, or manual
  Daybook editing merely because an optional network service is unavailable.
- Long work prevents duplicate activation and remains cancel-safe where
  cancellation is meaningful.
- Invalid release metadata fails verification before a store artifact is
  produced; it is never papered over by changing only the reported version.
- If a generated icon is attractive at 1024 pixels but muddy, misleading, or
  generic at small size, it is rejected.

## Verification contract

No completion claim is made from a partial suite. The final candidate requires
all of the following evidence:

### Automated and build verification

- focused regression tests for every behavior changed;
- the complete Flutter test suite finishing successfully, not merely a large
  passing prefix;
- `flutter analyze` with no unresolved issue;
- release web and Android builds from the candidate source;
- the repository's store-submission verifier passing with one matching version
  and build across `pubspec.yaml`, `release-candidate.json`, release notes, and
  store metadata;
- deterministic candidate artifact hashes recorded from the verified build;
- cloud iOS archive/signing validation followed by a new TestFlight build;
- tests for the feedback mail payload, launcher failure fallback, public-link
  discoverability, and support/privacy/deletion copy;
- asset-catalog and adaptive-icon checks for every required platform size.

### Visual verification

- fresh normal, narrow, 200-percent text, dark-surrounding-field, and Reduced
  Motion captures for changed screens;
- same-state before/after comparisons opened at full-frame and focused-detail
  scale;
- icon contact sheets showing current plus three candidates at 32, 60, 180,
  and master size with real platform masks;
- no high-priority audit finding left unresolved or silently reclassified;
- a final cohesion pass across the complete main journey, not only the screens
  touched most recently.

### Physical-device and service verification

- an upgrade on a physical iPhone from an existing TestFlight/App Store build,
  proving rooms, quests, Daybook data, preferences, account state, and What's
  New behavior remain correct;
- a fresh-install iPhone pass for onboarding, Morning/Night flows, keyboard,
  system insets, haptics, external links, Low Power Mode, text scaling,
  VoiceOver labels, and Reduced Motion;
- at least one physical Android install/upgrade pass for adaptive icon,
  navigation, back behavior, notifications, links, and saved data;
- a real inbound support email from an external sender and a reply-path check;
- a complete password-reset email/link/sign-in cycle;
- live checks of `/support`, `/privacy`, and `/delete-account` from outside the
  local development environment;
- App Store Connect confirmation of app status, territories, agreements/tax/
  banking state, support URL, privacy URL, age rating, export compliance,
  screenshots, icon, version, and selected build.

Device, mailbox, account, signing, and App Store Connect checks are manual
owner gates. Automated evidence cannot substitute for them.

## Release handoff

When every candidate gate is green, the owner receives one concise release
packet containing:

- the exact version/build and commit;
- automated test and build results;
- candidate artifact hashes;
- the selected icon comparison and fresh screen comparisons;
- completed physical-device, support, recovery, hosted-page, and store-status
  checks;
- known limitations, including Places remaining off;
- a recommendation to release or hold, with the reason.

Only then does the owner choose whether to submit the new build, leave the
currently approved build distributing, phase an update, or hold. The release
action and any email reply remain explicit external mutations and are not part
of the autonomous polish implementation.

## Official App Store references

- [Select an App Store version release option](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option/)
- [Choose a build to submit](https://developer.apple.com/help/app-store-connect/manage-builds/choose-a-build-to-submit/)
- [Create a new version](https://developer.apple.com/help/app-store-connect/update-your-app/create-a-new-version)
- [Add an app icon](https://developer.apple.com/help/app-store-connect/manage-app-information/add-an-app-icon/)
- [App and submission statuses](https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-submission-statuses)
