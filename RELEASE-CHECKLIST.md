# Room of Days Release Checklist

Updated August 23, 2026. “Repository-ready” means the source is prepared; it does
not replace a signed device build or store-console review.

## 1.0.4+31 iOS App Store candidate — supersedes Build 30

Build 30 reached TestFlight from `696c47f` through Codemagic Build #44 and was
approved for the internal Me group. Build 31 corrects the two interaction gaps
found on that physical build: a fresh private owner no longer has to infer that
generic code sharing hides the Discover opt-in, and the old Themes swatches no
longer change an obscured background. My Space and Discover now expose the
owner's private/listed state as a direct action. The renamed Ambient Light
control has a live preview and visibly relights the surrounding canvas while
Change Space remains the full-room chooser. `pubspec.yaml` is `1.0.4+31`.

- [x] Preserve Build 30 as the processed internal fallback and advance to the
  unused iOS build number 31.
- [x] Give a fresh owner with no room code a direct **Open to Discover** action
  beside My Space and another owner-listing action at the top of Discover.
- [x] Keep publication explicitly opt-in. The action may create the private
  share code as an implementation detail, but it opens with the Discover switch
  visible and never turns the switch on by itself.
- [x] Replace the decorative Discover `OPT-IN` pill with truthful `PRIVATE`,
  `LISTED`, or `CLOSING` state and keep the optional public-name control in the
  same management surface.
- [x] Rename Themes to Ambient Light, explain its boundary from Change Space,
  add an immediate live preview, visibly carry the selected light through Me's
  canvas and room-to-content fade, and reject invalid or locked selections.
- [x] Add fresh-owner route tests, empty-directory routing, discovery-first
  dialog visibility, ambient selection/persistence/validation, large-text
  reflow, and fresh rendered evidence for both owner-reported states.
- [x] Regenerate and inspect all seven opaque 1290×2796 App Store captures from
  the feature-on Build 31 source. My Space now shows **Open to Discover** and
  the Discover frame gives the private owner an explicit listing action.
- [x] Pass the 794-test regression suite, the 22-test feature-on discovery
  suite, `flutter analyze`, the feature-on release web build, and the iOS store
  packet verifier. Four stable one-channel Plans-hero golden baselines were
  reviewed together and refreshed; their layout, copy, and geometry are
  unchanged.
- [ ] Commit and push the reviewed Build 31 source, then start exactly one
  `ios-testflight` workflow from that immutable commit.
- [ ] Preserve the IPA, dSYMs, and `release-evidence.txt`; verify the receipt
  names Build 31, the exact commit, both discovery flags, and a successful
  TestFlight upload.
- [ ] Install Build 31 over Build 30 on a physical iPhone. Complete the revised
  Discover and Ambient Light checks in `DEVICE-ACCEPTANCE-RUNBOOK.md`, including
  a positive signed App Attest exchange and a second signed identity.
- [ ] Replace the App Store Version 1.0.4 draft's seven screenshots with the
  inspected Build 31 set, but do not select a build or submit the version until
  the physical-device gate passes.

## 1.0.4+30 iOS App Store candidate — supersedes Build 29

Build 29 reached TestFlight from `e2df153` through Codemagic Build #42. Build 30
turns the approved social direction into an actual release surface: keepers can
explicitly list a room with a separate optional public name, Discover offers a
finite shuffled handful without a code exchange, and Circle remains private and
uncapped. A stable opaque keeper key makes blocks survive room-code rotation;
private reports, server filters, rate limits, bans, community rules, and a daily
moderation queue form one safety boundary. My Space now distinguishes a listed
room from still-private cards. The iOS workflow explicitly compiles both
discovery flags. `pubspec.yaml` is `1.0.4+30`.

- [x] Keep Build 29 available as the processed TestFlight fallback and give the
  enabled candidate a new build identity.
- [x] Compile `SPACE_DISCOVERY=true` and `PUBLIC_DISCOVERY_NAMES=true` into the
  sole Codemagic IPA command and run focused feature-on tests before archive.
- [x] Make opt-in/listed/private states truthful in Me and the share dialog;
  keep the public name separate from the private Me name.
- [x] Add keeper-level block persistence, report/block copy, code-rotation
  verification, server-side filters/rate limits/bans, and app-accessible
  community rules with a monitored support and appeal route.
- [x] Update privacy, terms, reviewer notes, data-safety guidance, and age-rating
  guidance for the optional public name rather than describing the release as
  code-only.
- [x] Link the Firebase project to Blaze, add a low budget alert, enable the
  required APIs, register iOS App Attest, and keep public names unavailable if
  attestation or callable enforcement is not healthy. Billing, a $10 monthly
  alerts-only budget with 50/90/100 percent thresholds, APIs, Firebase App
  Check/App Attest registration, Apple Team/App Store identity, server
  enforcement, Apple’s production capability, and the regenerated distribution
  profile are proven. The budget warns rather than caps spending. A positive App
  Attest exchange from the signed app on a physical iPhone remains a separate
  gate below.
- [x] Deploy the exact checked-in Firestore rules and discovery Functions,
  configure TTL for `discoverableSpaces.expiresAt`, and publish the matching
  privacy, terms, community, and support pages. The rules and four public pages
  went live on August 23. Both Node 22 callables are active with App Check
  required, their negative tests return 401, TTL is active, and seven-day
  container-image cleanup is configured.
- [ ] Smoke the live directory with two signed identities: opt in, set/clear a
  name, browse, open, keep in Circle, report, block, rotate a code, unblock, opt
  out, and verify expired/removed listings are unreadable. A temporary
  two-identity live smoke proved public-name persistence, private report
  metadata, report creation, cleanup, and valid debug App Check; the complete
  signed-device interaction pass remains open.
- [x] Generate and inspect the appended seventh 1290×2796 Discover capture from
  the exact feature-on Build 30 source. Preserve frames 1–6 in their existing
  order. The August 23 seven-frame sheet and focused Discover/Me/share/report/
  Circle/workout sheet were both opened at full production geometry.
- [x] Confirm the App Store Version 1.0.4 draft remains unsent, save the Build
  30 listing changes, and replace the screenshot set with the seven-frame story.
  The refreshed seven-frame set is saved in the draft in the order Quests,
  Reward, Plans, My Space, Change Space, Journal, Discover. Apple’s questionnaire
  now records User-Generated Content Yes, fixed Messaging/Chat Yes, Social Media
  No, and a recalculated 9+ result.
- [x] Commit and push the reviewed release HEAD, then start exactly one
  `ios-testflight` workflow from commit `696c47f`.
- [x] Save the IPA, dSYMs, and `release-evidence.txt`; verify the evidence says
  Build 30 with both discovery flags enabled and confirms TestFlight upload.
  Codemagic Build #44 artifacts and receipt are preserved under
  `../release-artifacts/room-of-days/1.0.4+30/codemagic-build-44-696c47f/`.
  TestFlight finished beta review as `Approved` and is available to the existing
  internal `Me` group.
- [x] Save the Build 30 TestFlight description, review notes, and per-build What
  to Test instructions. Hide the invitation sheet’s approved-screenshot feed
  while it can only use the stale Ready-for-Distribution 1.0 set; turn it back
  on after 1.0.4 reaches Ready for Distribution and the seven new frames become
  eligible.
- [ ] Install over Build 29 on a physical iPhone and complete
  `DEVICE-ACCEPTANCE-RUNBOOK.md` before selecting Build 30 in the App Store draft
  or making a public submission change.

## 1.0.4+29 internal TestFlight record — superseded by Build 30

Build 28 reached TestFlight from `6d0781c` before this final interaction and
Circle pass. Build 29 makes sound belong to visible motion: every quest bob
answers once even when the press becomes a scroll, blank swipes stay quiet,
completion adds only its paired outcome, and opening Journal has its own page
turn. Guided workouts now offer seven sessions instead of claiming one is
already on the board. A Circle may hold as many trusted spaces as the user
wants and loads them progressively without ranks. The optional public directory
and public names remain default-off and are not deployed by the iOS workflow.
`pubspec.yaml` is `1.0.4+29`.

- [x] Confirm Build 28 is the live TestFlight high-water. Codemagic Build #41
  archived and uploaded it from `6d0781c`; Build 29 therefore has a new identity.
- [x] Keep Space Discovery and public names unavailable in the ordinary build.
  No discovery enablement define is passed and Codemagic does not deploy the
  accompanying Firestore rules or Functions.
- [ ] Confirm the existing App Store Version 1.0.4 draft remains unsent and
  public US distribution and agreements remain in effect.
- [x] Codemagic Build #42 archived and uploaded Build 29 from `e2df153` through
  the `ios-testflight` workflow.
- [x] Preserve its emitted IPA, dSYMs, and release evidence in Codemagic as the
  processed fallback for Build 30.
- [ ] After Apple finishes processing, add Build 29 to the intended internal
  tester group and install it over Build 28 on a physical iPhone.
- [ ] Complete `DEVICE-ACCEPTANCE-RUNBOOK.md` before selecting Build 29 in the
  App Store Version 1.0.4 draft or making any public submission change.
- [ ] Replace the prior App Store Connect screenshot set with the refreshed
  six-frame Build 29 story after final local capture inspection.
- [x] Regenerate all six Build 29 App Store frames on August 22, 2026. The
  exporter revalidated 1290×2796 opaque RGB output and the full sequence plus
  individual originals were opened and visually inspected. Plans and Change
  Space remained byte-equivalent; Quests, Reward, My Space, and Journal were
  refreshed.

## 1.0.4+28 internal TestFlight record — superseded by Build 29

Codemagic Build #41 archived and uploaded Build 28 from commit `6d0781c` on
August 22, 2026. The preserved IPA SHA-256 is
`97873F289265D64B6DC13CFEF7CE8EB4C4FB589926D6B6551FCDDBFA5F00202D`;
Apple processing identifier `bf87fd60-65d4-4d8e-a22a-7cf35bda4ed9` was last
recorded waiting for beta review. Its unfinished device and public-submission
gates move to Build 29.

## 1.0.4+27 iOS App Store candidate — supersedes Build 26

Build 26 shipped the sound system to TestFlight; Build 27 added two owner-noted
coverage fixes on top: a press that drifts into a drag (press depth and haptic
fired, then the finger moved past tap slop) now answers with a quiet select
detent instead of staying silent, and tapping an all-day quest (which bobs and
defers its completion to the night ledger) answers with the ordinary clasp.
Everything else is identical to Build 26. This is retained as release history;
the owner’s August 22 clarification supersedes the drag/coasting behavior in
Build 28 while preserving the bob. `pubspec.yaml` is `1.0.4+27`.

## 1.0.4+26 iOS App Store candidate — supersedes Build 25

Build 25 was prepared but is superseded before upload by Build 26, which adds
the phone-approved sound system: the material texture lanes (slate, page,
glass, brass over the wood clasp), the room-derived event voices replacing the
Gen-1 sine palette, dead-tap coverage (active-tab retap, board fling catch,
Daybook wiring), and its What's New record ("Every surface has a voice.").
Owner verdicts and byte-locks are recorded under
`design/audits/2026-08-21/`; the how-and-why lives in `SOUND-DESIGN.md`.
`pubspec.yaml` is `1.0.4+26`; everything in the Build 25 section below remains
included. Local verification: format, analyze, full test suite, release web
build with offline prep, dependency audit, and store-submission verifier —
run on August 21, 2026.

## 1.0.4+25 iOS App Store candidate (superseded by Build 26)

Builds 22, 23, and 24 were uploaded as internal candidates. Build 24 came from
the older `ade02ef` source before the final sound and quest-management work, so
it is superseded rather than releasable. Build 23 remains the known processed
fallback; Build 25 was the target of the historical preparation below.

The uncompleted Build 25 release actions were superseded before they ran; the
active release actions now live in the Build 31 section above.

- [x] Preserve Build 23 as an internal TestFlight fallback. A live Codemagic
  high-water check found the older Build 24 on Apple, so advance the final
  candidate without changing its marketing version to `1.0.4+25`.
- [x] Include the finished calendar-commitment work: Day Shape, fixed plans,
  deadlines, and chosen Quests now read as distinct parts of the same day.
- [x] Put the general Daybook, optional School lane, unified calendar views,
  manual locations, and Get Directions in the newest-first What's New record,
  while retaining the earlier Build 21 record in the archive.
- [x] Ship the owner-approved Day Ledger icon in the iOS asset catalog.
- [x] Give the room one crisp five-take interaction voice, a phone-approved
  bounded melodic return, a single-session hearth ignition, calmer rotating
  Quest companion copy, and a brighter earned mark in the Day Ledger icon
  without adding looping ambience.
- [x] Let Goals take back and reselect adopted quests, preserve their progress,
  and move weekly quests to another day without recreating them.
- [x] Keep protected Google place search off. The candidate is built without a
  `PLACE_SEARCH_ENABLED=true` define; manual location entry and map handoff
  remain available.
Android store work is intentionally deferred for this release. Its immutable
Build 20 evidence in `release-candidate.json` remains unchanged.

## 1.0.4+23 internal TestFlight fallback

- [x] Apple processed Version 1.0.4, Build 23 and made it available to the
  internal `Me` group on August 19, 2026.
- [x] Keep Build 23 available as the known processed fallback while Build 29 is
  built and auditioned; do not attach it to the App Store draft unless Build 29
  is abandoned for a documented release blocker.
- [ ] Preserve a completed physical-iPhone acceptance receipt if Build 23 was
  installed and tested; otherwise Build 29 supersedes this unchecked gate.

## 1.0.4+24 superseded App Store Connect artifact

- [x] Build 24 was produced from commit
  `ade02ef8b58c421ae25ba6f7ac3379d8279abcf3` and processed by Apple on
  August 19, 2026.
- [x] Do not attach or submit Build 24. It predates the approved five-take X and
  Paired Return system, Goals take-back/reselection, the reachable Planning
  Ember, and the final narrow-layout repair.
- [x] The attempted final-candidate run stopped before archive when its live
  high-water check found Build 24 already present; Build 25 replaces it.

## 1.0.3+21 internal TestFlight record

- [x] Give the post-1.0.2 Daybook work a new internal identity instead of
  reusing the frozen 1.0.2+20 Android/web record.
- [x] Apple processed Version 1.0.3, Build 21 and made it available in
  TestFlight on August 18, 2026.
- [ ] Preserve a completed physical-iPhone acceptance receipt if Build 21 was
  installed and tested; otherwise Build 29 supersedes this unchecked gate.

## 1.0.2+20 release record

- [x] Frozen source commit `b20649424053723855236f6951f16cf688bf6b5d`
  carries the 1.0.2+20 app and newest-first What's New record.
- [x] A clean checkout passes formatting, analysis, and all 433 tests on
  Windows. The clean-checkout run also normalizes source assertions across LF
  and CRLF clones.
- [x] The signed APK and AAB pass immutable hash, identity, signer, permissions,
  app-link, 16 KiB alignment, Bundletool, and native-library validation.
- [x] The public GitHub prerelease
  `v1.0.2-android-preview.20` serves the exact 79,306,323-byte APK with SHA-256
  `07DFA5EB180C1AF3C53773B7AC24AC4176503F67F5807DD9DDCBECA9DCBFF61F`.
- [x] Firebase Hosting serves web/PWA version 1.0.2+20, the Build 20 Android
  route, and always-fresh version, introduction, and Android release routes.
  A real 390 x 844 Chromium session loaded first-run onboarding and the Android
  page with no console warnings or errors.
- [ ] Install Build 20 over Build 13 on a physical Android phone and confirm the
  local save remains intact and What's New appears once.
- [ ] Start exactly one `ios-testflight` Codemagic build from the released main
  commit, then install and smoke the processed TestFlight build before any App
  Store submission change.

## Repository-ready

- [x] Package/bundle ID is `com.mikabe.emberkeep` on Android and iOS.
- [x] Flutter stable targets Android API 36.
- [x] Android, iOS, and web Firebase apps are registered and configured.
- [x] Core experience works without account or network.
- [x] Cloud backup is explicit opt-in and account deletion exists in-app.
- [x] Optional-account recovery has a least-access owner runbook. It uses
  Firebase's one-time reset email, never asks support to handle a password, and
  does not require widening the Build 12 mobile candidate.
- [x] Privacy and deletion pages are live and linked from Me. The deletion page
  also accepts a direct verified request without requiring the app, and the
  owner cleanup procedure is recorded in `ACCOUNT-DELETION-RUNBOOK.md`.
- [x] The v1 shared-room surface publishes generated appearance and broad
  presence fields only. Display names, goals, My Space and Journal writing, and
  photos stay out of the visitor payload.
- [x] The dormant visitor-profile capability defaults off, old consent is
  erased when a save loads, and visitor rendering ignores legacy profile data.
- [x] Firestore accepts only generated-only v5 room writes, serves only
  generated-only v5 rooms to code bearers, and denies collection listing.
- [ ] Space Discovery remains default-off. Before enabling it, deploy and prove
  the bounded v2 directory rules, exact-code isolation, opt-out/deletion, large
  Circle behavior, privacy/store disclosures, signed-device behavior, and fresh
  captures from that candidate.
- [ ] Public Discovery names remain separately default-off. Before enabling
  them, deploy both callables, keep and prove App Check enforcement, verify
  filtering/rate limits/reporting/blocking, staff the moderation runbook, and
  complete the UGC policy and store-review disclosures.
- [x] Android notification permission is declared and requested in context.
- [x] Exact-alarm permission is unnecessary; reminders use inexact scheduling.
- [x] Journal photos remain local and are excluded from cloud backup and shared
  rooms in v1.
- [x] Cold-start backgrounds match the dark Room of Days canvas.
- [x] Native/PWA icons use the owner-approved Day Ledger mark; the exact
  iOS, Android legacy/adaptive/themed, web maskable, and Windows outputs were
  rendered together and visually accepted on August 19, 2026.
- [x] The web release uses a first-party, versioned offline cache now that
  Flutter's generated service worker is intentionally a no-op. It keeps
  CanvasKit on the Room of Days origin, refuses stale/incomplete deploy output,
  and avoids permanently caching unhashed JavaScript in the browser.
- [x] The Apple association file is live at the apex domain with a JSON content
  type and exactly matches the checked-in file; verified August 9, 2026
  (SHA-256
  `9810E971FB67DB38FCFAD46669F7652C3727BDEE86C6C1E2EBC805B2F9183142`).
- [x] Android's association endpoint is live at the apex domain as a valid
  empty JSON placeholder with an explicit JSON content type. It returned HTTP
  200 and matched the built file byte-for-byte on August 9, 2026 (SHA-256
  `37517E5F3DC66819F61F5A7BB8ACE1921282415F10551D2DEFA5C3EB0985B570`).
  It intentionally remains empty until Play App Signing supplies the final
  certificate.
- [x] Google Play 1024×500 feature graphic is ready in `store-assets/`.
- [x] Seven opaque 24-bit RGB App Store screenshots at 1290×2796 and five
  independently rendered Google Play screenshots at 1080×1920 are ready in
  `store-assets/screenshots/`. The iOS set was regenerated and visually
  accepted on August 23, 2026; the deferred Android set remains unchanged.
- [x] Android 13+ themed icons use a dedicated monochrome Room of Days mark.
- [x] Release Gradle tasks cannot fall back to debug signing.
- [x] No keystore, App Store key/profile, service-account credential, password
  file, or private-key marker is tracked or named in Git history. Root ignore
  rules cover the common Android, Apple, environment, and Firebase Admin secret
  formats; Codemagic receives its certificate key only through a secret group.
- [x] Android API/NDK versions and Codemagic's Flutter, Xcode, and CocoaPods
  versions are pinned; CI verifies the signed IPA's identity, version, privacy
  manifest, signature, and associated-domain entitlement.
- [x] No ads, analytics, subscriptions, in-app purchases, or paywalls.
- [x] The exact Android candidate requests neither Advertising ID nor broad
  photo/video access. Journal media uses the scoped system picker; Build 12 has
  no `AD_ID`, `READ_MEDIA_IMAGES`, or `READ_MEDIA_VIDEO` permission.
- [x] Third-party font and sound rights are recorded. The Android candidate
  bundles all four font OFL files, the sound-source record, and Flutter's
  generated notices; the remaining hearth sources are CC0 and recorded in
  `ASSET-LICENSES.md`.
- [x] Store copy no longer mentions the retired character/avatar concept.
- [x] Privacy manifests, public policy, and console worksheets disclose both
  Fitness and Health data when optional cloud saves contain exercise, sleep,
  meal, medication, stress, or similar quest progress. The store description
  carries Google's required non-medical disclaimer and professional-advice
  reminder.
- [x] `DEVICE-ACCEPTANCE-RUNBOOK.md` turns the remaining physical-phone gate
  into an artifact-bound pass with stop conditions and a durable result record.

## Protected place search remains off

Checked and public builds remain `PLACE_SEARCH_ENABLED=false` until every item
below is complete, in this order. Repository tests, Functions builds, and fake
provider UI coverage do not make the public feature enabled.

- [ ] Attach billing to the owner-confirmed Firebase/Google Cloud project.
- [ ] Enable **Places API (New)** in that same project; do not enable a legacy
  substitute by mistake.
- [ ] Create a dedicated server key restricted to **Places API (New)**, apply a
  server application restriction where fixed egress makes it valid, store it as
  the `GOOGLE_PLACES_API_KEY` Functions secret, and verify the value is absent
  from source, Flutter defines, and web/native artifacts.
- [ ] Configure conservative provider quota caps first as the hard upstream
  stop; then configure budget alerts, which warn but do not cap spending; then
  activate Firestore TTL policies on timestamp field `expiresAt` for collection
  group `_placesCostGuards` and collection
  `serviceIdentityDeletionTombstones`. Cost counters are marked to expire 35
  days after their last update; deletion tombstones are marked to expire 35
  days after creation or refresh. Firestore deletes expired documents
  asynchronously afterward. Verify the server guards remain 30
  autocomplete calls/minute and 300/day per UID and install, 10 details/minute
  and 100/day, with global daily closures at 5,000 autocomplete and 1,000
  details calls. Complete all three cost/retention controls before deployment.
- [ ] Deploy and verify the owner-only room cleanup rules before any enabled
  client build. Prove an authenticated query for the caller's owner UID with a
  limit of 100 finds its public, private, and legacy rooms; prove unauthenticated,
  unfiltered, other-UID, missing-limit, and over-limit queries fail. Verify
  private `serviceIdentityDeletionTombstones/{uid}` documents can be read only
  by that UID and cannot be listed or mutated by clients. Prove a tombstone
  blocks same-UID save and room create/update across app instances and late
  Firebase tokens. Verify an owner-only `roomDeletionLocks/{code}` document
  blocks room updates and new Spark/Circle receipts, every private child cleanup
  read is server-only, room plus lock delete atomically, crash retry works,
  exact-code public/private reads remain unchanged, and every ambiguous remote
  result keeps the identity. Deploy and prove `storage.rules` also blocks
  shared-room media create/update for a tombstoned owner while allowing cleanup
  deletes; visitor-photo sharing remains false. Record both deployed rulesets
  and emulator/live allow/deny evidence; source-shape tests alone are not proof.
- [ ] Perform the first monitor-mode deploy of `placesAutocomplete`,
  `placesDetails`, and `beginServiceIdentityDeletion` with
  `PLACES_ENFORCE_APP_CHECK=false`. Confirm the deletion callable accepts only
  an authenticated anonymous Firebase provider, creates or refreshes the UID
  tombstone, and does not bind the Places secret. Do not opt any app build into
  search yet.
- [ ] Exercise all three callables only with controlled internal builds,
  including a cold-session deletion bootstrap that initializes Firebase Core
  and App Check without a prior search. Inspect App Check callable-request
  metrics separately for `placesAutocomplete`, `placesDetails`, and
  `beginServiceIdentityDeletion`. Record enough valid-token evidence to explain
  every legitimate platform before enforcement.
- [ ] Set `PLACES_ENFORCE_APP_CHECK=true` and redeploy all three callables.
  Verify invalid/missing attestation is rejected on each endpoint, legitimate
  Android, Apple, and web place requests still work, and the deletion endpoint
  continues to reject linked or missing-provider identities.
- [ ] Publish `web/privacy.html` and `web/terms.html`, then verify the live
  canonical `/privacy` and `/terms` pages, Google Maps terms link, Google
  privacy link, content, status, and cache behavior.
- [ ] Only after every earlier gate, produce an opt-in candidate with
  `--dart-define=PLACE_SEARCH_ENABLED=true`. Web additionally requires
  `--dart-define=PLACE_SEARCH_APP_CHECK_WEB_SITE_KEY=<public-site-key>`. Run the
  complete release verification again and perform the physical iPhone provider
  handoff before calling place search public. The private-service-identity
  removal control remains unavailable in web builds.

The detailed command-level owner runbook and primary documentation links are in
[`functions/README.md`](functions/README.md). No gate above is completed by the
Task 5 documentation commit itself.

## Verify before every candidate

- [x] Keep the iOS Build 31 record first in `lib/content/release_notes.dart` and
  match its `1.0.4+31` identity to `pubspec.yaml`. The frozen Android Build 20
  manifest remains separate in `release-candidate.json`. The current record and
  store copy truthfully include enabled, opt-in Discover and its privacy/safety
  controls alongside the already shipped sound, workout, and Circle changes.
- [ ] Install over the previous build and confirm What's New appears once,
  dismisses through both exits, and remains replayable from Me. Confirm a
  fresh install goes directly to onboarding, then inspect the normal,
  large-text, and Reduce Motion release screens on a phone-sized viewport.
- [x] The v1 store candidate defaults `VISITOR_PHOTO_SHARING` off. Local My
  Space photos remain available, but the candidate exposes no visitor-photo
  switch and makes no visitor-photo Storage upload or download. The completed
  future infrastructure remains dormant until a separately reviewed build.
- [x] The v1 store candidate defaults `VISITOR_PROFILE_SHARING` off. Enabling it
  requires terms, filtering, reporting, blocking, and a timely human moderation
  workflow before any store build can expose user-authored visitor content.

- [x] `dart format --output=none --set-exit-if-changed lib test tool`
- [x] `flutter analyze`
- [x] `flutter test` (401 tests on August 13, 2026)
- [x] `flutter build web --release --wasm`
- [x] `dart run tool/prepare_web_offline.dart` bound the Build 13 web output to
  its generated version metadata and an exact 129-file offline manifest: 25.7
  MiB core plus 8.2 MiB deferred, capped at 96 MiB.
- [x] A fresh real mobile Chromium session loaded the deployed Build 13 at
  `roomofdays.com` with zero console errors or warnings, completed onboarding,
  and exposed the Quest board in the accessibility tree. A new save started
  with 3 streak freezes; an isolated quiet-day completion moved a 5-day streak
  to 6, spent exactly one freeze, and recorded August 12 under Recently Held.
  The installed release also loaded from its first-party cache while the browser
  was fully offline on August 13, 2026. Root, policy, and shared-room HTML routes
  continue to revalidate instead of inheriting Firebase's one-hour default cache.
- [x] `dart run tool/verify_android_candidate.dart` verifies the immutable
  artifact hashes and handoff, source commit, package/version/SDK contract,
  permissions, app-link scope, APK/AAB signers, Bundletool configuration, ZIP
  alignment, and every native library's ELF LOAD alignment.
- [x] `dart run tool/verify_store_submission.dart` verifies store-field length
  limits, public URLs, privacy and health disclosures, candidate-version
  agreement, icons, feature graphic, and both exact five-image RGB screenshot
  sets.
- [x] `dart run tool/audit_pub_dependencies.dart` checked all 127 locked hosted
  Pub packages against OSV on August 8, 2026; no known affecting advisory was
  returned. This supports the proven native-plugin pins without pretending an
  advisory scan can prove that undiscovered vulnerabilities do not exist.
- [x] Render and inspect the screenshot-golden suite; all 23 captures pass a
  second run without updating baselines, confirming deterministic output.
- [x] Build signed Android App Bundle and APK candidates for `1.0.0+12` from
  source commit `ee091db079a54c982946aa6ab7e7b61546b3354f` on
  August 9, 2026. The AAB SHA-256 is
  `E2EA2FB86D95208F8CE0F29A61FD385AEFE227FF0F4C573EF6EDB5C59E36EA90`;
  the APK SHA-256 is
  `9C8C924E4C98CEC35175C03508EF5E757940CA8FD9C18627DCE6E4634B4A1B12`.
  Both match upload certificate SHA-256
  `4F:28:DB:3A:70:C6:03:6A:B4:03:E4:2B:D5:3A:96:D1:73:DD:FD:C6:B7:8F:14:55:CC:26:C5:6C:47:C6:14:14`.
  Stable copies and install guidance are in `../release-artifacts/`.
- [x] The Android app module's `:app:lintRelease` task completes successfully
  with 0 errors on the current Build 12 source as of August 9, 2026, after
  upgrading the core-library desugaring runtime to the API-36-safe 2.1.5
  release. Its nine remaining findings are four non-blocking app-link clarity
  suggestions and five launcher-silhouette advisories. The Gradle root aggregate
  also analyzes pinned plugin source and currently stops on dependency-internal
  AGP 9 findings in `firebase_storage` and `flutter_local_notifications`, not
  Room of Days source.
- [x] Bundletool 1.18.3 validates the AAB and reports
  `PAGE_ALIGNMENT_16K`; the APK passes `zipalign -c -P 16`, and all packaged
  native libraries have LOAD alignment of at least 16 KiB.
- [x] Generate a device-specific APK set from the exact immutable AAB with
  Bundletool 1.18.3. All four selected splits (`base-master`, `base-en`,
  `base-x86_64`, and `base-xxhdpi`) carry the expected upload certificate. A
  fresh Bundletool split install on Android 16 / API 36 completed onboarding,
  a quest, first-time production sharing, an exact generated-only v5 read, Stop
  Sharing, and Start Over on August 8, 2026.
- [x] Install the release APK on an Android 16 / API 36 emulator. Cold
  launch, onboarding, quest completion, all five destinations, offline
  relaunch, notification permission and alarm cancellation, exact and
  near-miss app links, largest in-app text, reset persistence, and repeated tab
  changes passed on August 8, 2026. The emulator required its supported host
  graphics backend; two unsupported software-renderer attempts crashed QEMU,
  not the app process.
- [x] Earlier migration evidence: install signed Build 10 over signed Build 9 on
  the API 36 emulator. The
  package upgraded from version code 9 to 10 without onboarding returning and
  preserved 10 XP. First-time sharing then produced a publicly readable v5
  room with every profile/photo field empty; Stop Sharing revoked the code.
- [x] Install the exact signed Build 11 APK over that installed Build 10 on the
  Android 16 / API 36 emulator. Android preserved the original install record
  and reported `1.0.0` / version code 11 / API 24-36. Build 10's native
  accessibility tree exposed Quest Desk and tab controls underneath first-run
  onboarding; after the upgrade, Build 11 exposed onboarding only, and its
  button advanced normally to step 2/4.
- [x] Package a Build 11 → Build 12 signed upgrade pair and a phone-friendly
  Android test guide in
  `../release-artifacts/room-of-days-android-tester-kit-build-12.zip`; its
  SHA-256 is
  `900B15567EFA6F0CE7AAF7EAC4257A9F321F82368565B5415115956B3913242D`.
- [x] Exercise the remaining release-mode data paths on API 36: a manual backup
  restored 23 XP back to its stashed 10-XP state across a cold relaunch; an
  Android scoped-picker photo and Journal text survived force-stop; optional
  backup, account create, sign-out, sign-in, and account deletion all completed;
  deletion invalidated the temporary credentials and returned an empty Journal.
- [x] Build/upload iOS with Xcode 26+ and the iOS 26 SDK. Codemagic Build #28
  built `1.0.0` (Build 19) from source commit `32e1f05` with Xcode 26.4.1 and
  `iphoneos26.4`. All 337 tests, signing setup, archive validation, and signed-IPA
  verification passed; App Store Connect accepted the upload with no errors.
  The exact IPA SHA-256 is
  `5773219E32E60EEB799CE191C895A4CB82826C17E8C7FE8DF02C82F060AA65BE`.
  App Store Connect completed processing and beta review; Build 19 is `Testing`
  in the Me and Friends and Family groups. Build 18 remains only as the prior
  approved baseline.
- [x] Confirm the exact Build 19 release candidate on a physical iPhone. On
  August 9, 2026, the owner installed it and reported that the build looks great
  and that things work nicely. The detailed performance, accessibility, and
  cross-device cases below remain explicit follow-up coverage rather than being
  inferred from that successful core smoke.
- [ ] Complete `DEVICE-ACCEPTANCE-RUNBOOK.md` on physical Android and iPhone
  devices using the exact recorded release artifacts.
- [ ] On a physical iPhone, continuously scroll the Quest board, tilt while
  scrolling, complete a Quest, open the one-line Journal sheet, and switch all
  five tabs twice. Confirm immediate press feedback, stable frame pacing, no
  audio crackle, no accidental taps, and no warm-device degradation.
- [ ] Repeat the phone performance pass with Low Power Mode and Reduce Motion.
- [ ] Profile in Xcode/Instruments if Quest scroll, room tilt, fire, or tab
  switching visibly misses frames; screenshots and Windows builds cannot close
  this gate.
- [ ] Exercise fresh install, upgrade, offline, cloud, account deletion, media,
  notifications, export/restore, reset, sharing, large text, screen reader, and
  reduce-motion paths.
- [x] Confirm the submitted version/build number exceeds every prior upload.
  Build 19 was accepted for upload after App Store Connect reported Build 18 as
  the previous high-water mark.
- [x] Repository candidate version is `1.0.0+12`; Codemagic keeps Build 12 as
  the iOS floor and increments only when App Store Connect already contains an
  equal or higher TestFlight build.
- [x] Deploy the checked-in Firestore rules before testing Share, Visit, or
  Circle; current rules compiled and were released to `emberkeep-5b33b` on
  August 8, 2026.
- [x] Run the repeatable authenticated production smoke: v5 publish, exact-code
  generated-only read, anti-enumeration, visitor-writing and photo-path
  rejection, anti-downgrade, Circle/Spark delivery and owner-only reads,
  duplicate support rejection, self-Spark/self-Circle rejection, and cleanup
  all passed again under the Build 11 source on August 8, 2026. Cleanup now
  attempts every temporary resource and identity even if an earlier deletion
  fails; this run reported `Cleanup complete`. Storage was intentionally
  excluded because it is not a v1 runtime dependency.
  Re-run with
  `dart run tool/production_social_smoke.dart --confirm-production --firestore-only`;
  a future visitor-photo candidate must create its bucket, deploy
  `storage.rules`, and add `--include-dormant-storage` before enabling the build
  flag.
- [x] Reject malformed room codes before Firestore access, safely detach stale
  missing/non-owned codes, serialize all Firebase identity changes with guest
  startup, and preserve an owner-aware cleanup queue across offline resets.

## Owner gates before submission

- [x] Generate the Android upload keystore and configure ignored
  `android/key.properties`.
- [ ] Back up the upload keystore and password file off this machine.
- [ ] Enroll in Play App Signing.
- [x] Confirm Codemagic App Store Connect integration/signing secrets are valid.
  Build #28 reused the persisted Apple Distribution private key and renewed
  App Store profile, uploaded Build 19, and completed its automatic TestFlight
  submission after Apple processed the binary.
- [x] In App Store Connect TestFlight Test Information, paste the exact Beta App
  Description and Build 19 What to Test copy from `STORE-LISTING.md`, use
  `support@roomofdays.com` as Feedback Email, add the marketing/privacy URLs and
  beta-review notes, and verify the existing beta-review contact fields. Build
  19's saved copy includes the redesigned About page, and the build is available
  to both Me and Friends and Family.
- [x] Rename the App Store Connect app record from `Emberkeep: Habit RPG` to
  `Room of Days`.
- [x] Prepare App Store version 1.0 with the checked-in promotional text,
  description, keywords, support/marketing URLs, updated review notes, Build 19,
  and automatic release after approval. Sign-in remains correctly marked as not
  required. The selected binary is validated, reports non-exempt encryption
  `No`, contains the
  intended associated-domain entitlement, and was submitted to App Review on
  August 9, 2026 at 3:25 PM EDT. Submission
  `3ce04859-9480-48e2-ad50-2a9f27e2bbb3` is `Waiting for Review`; Apple advises
  that review can take up to 48 hours. Automatic release is saved so approval
  can publish version 1.0 without a later manual click.
- [x] Configure the public app as Free in all 175 countries or regions on
  release. Disable the untested Apple silicon Mac and Apple Vision Pro listings;
  the candidate is intentionally iPhone-only.
- [x] Enable Associated Domains for the App ID and confirm the renewed iOS
  provisioning profile contains the Associated Domains entitlement and the
  signed app contains exactly `applinks:roomofdays.com`. Build #28 reused
  profile `Emberkeep ios_app_store 1786285471`, expiring June 17, 2027, and
  verified both layers before upload.
- [ ] After the first Play upload, publish the Play App Signing SHA-256 in
  `web/.well-known/assetlinks.json` (replacing the valid empty array), redeploy
  hosting, and verify Android App Links on-device.
- [x] Android and web builds link to the owner's tip-only Ko-fi page from
  About; the link grants no content, rewards, or progress. iOS excludes the
  external payment call-to-action under App Review Guideline 3.1.1 and
  Codemagic compiles that URL as empty; an empty `COFFEE_URL` remains the
  rollback switch for every platform.
- [x] Route `support@roomofdays.com` to a monitored inbox (owner confirmed).
- [x] Complete and publish Apple App Privacy from `STORE-LISTING.md`, including
  the privacy and deletion URLs and the seven linked, app-functionality data
  types used by optional account/cloud and user-authored features.
- [ ] Complete Google Play Data safety from `STORE-LISTING.md`.
- [ ] Complete Google Play's Health Apps declaration from `STORE-LISTING.md`;
  do not claim that the app has no health features. Confirm the declaration
  includes Activity and Fitness, Nutrition and Weight Management, Sleep
  Management, and Stress Management / Relaxation / Mental Acuity.
- [ ] Confirm the Play developer account satisfies Google's Organization-account
  requirement for health apps, including verifiable organization details and a
  D-U-N-S number. The live console currently identifies account
  `7343443055439981513` as a new Personal account. Do not submit the health and
  fitness candidate under an ineligible account or falsely declare that the app
  has no health features.
- [x] Verify ownership of the Play developer website. On August 9, 2026,
  `roomofdays.com` was registered as a domain property in Google Search Console
  through Cloudflare's one-time DNS authorization, and Play Console then
  auto-approved the same-account association and reported `Website verified`.
  Retain the Google site-verification TXT record so ownership stays verified.
- [ ] Finish the Play developer-account gates. Identity was approved on August
  6, 2026, and website ownership is now verified, but Google still requires the
  account owner to verify access through the Play Console app on a physical
  Android 10+ device; contact-phone verification remains locked until that
  device check is complete. Google has disabled `Create app` until both checks
  pass.
- [ ] If the final eligible account is a new Personal account, run a closed test
  with at least 12 opted-in testers for 14 continuous days and then apply for
  production access. The single current Android tester is enough for device
  smoke and an internal test, but not for Google's production-access gate.
- [x] Publish a temporary, direct Android tester route while Google Play remains
  delayed. `https://roomofdays.com/android` is a branded install page pointing
  to the public GitHub pre-release tag `v1.0.1-android-preview.13`; GitHub reports
  the exact 79,190,875-byte APK and SHA-256
  `42A827512A2E3F9F364FFBD4A050D3AB152D11964CEBDA830C436576F61A0A47`.
  The page explains Android's outside-Play install prompt, tells Build 12 users
  to install Build 13 over it, and keeps the backup guidance for the eventual
  Play Store edition.
- [ ] Confirm `com.mikabe.emberkeep` is registered or auto-registered in Play
  Console's Android developer verification page before the September 30, 2026
  enforcement date.
- [ ] Create a dedicated, reusable review-only account and store its credentials
  outside the repository. In Google Play, declare that some functionality is
  restricted and provide the account proactively because optional cloud backup
  is sign-in-gated. Keep it available for Apple if App Review asks to inspect
  the optional account path.
- [ ] Before giving that account to either store, complete
  `ACCOUNT-RECOVERY-RUNBOOK.md`: brand Firebase's password-reset template and
  sender as Room of Days, apply a verified `roomofdays.com` Auth email domain,
  confirm no Emberkeep/project identity appears in the received email or action
  page, and prove that a full reset preserves the review account's cloud save.
- [ ] Complete every Google Play App content card using
  `STORE-LISTING.md`: Ads No; sign-in details supplied; target audience and
  content rating; Data safety; Health apps; Financial features None;
  Government apps No; News and Magazine No; COVID-19 No; Advertising ID No;
  and any additional card Play Console marks `Needs attention`.
- [ ] Enter `https://roomofdays.com/delete-account` as Google Play's account
  deletion URL and verify the public request workflow from the console.
- [x] In App Store Connect, set Content Rights to Yes for the licensed fonts and
  audio and retain Apple's standard EULA. The uploaded build declares that it
  does not use non-exempt encryption, so no encryption document is required.
- [x] Enter the exact legal copyright owner and required App Review contact
  name/email/phone. App Store version 1.0 now carries `2026 Mika Be`, and the
  saved review contact matches the already verified TestFlight review contact.
- [x] Complete Apple's DSA trader/non-trader self-assessment. On August 9, 2026,
  the owner explicitly selected `I'm not a trader under the DSA or I don't plan
  to distribute in the EU`; App Store Connect now reports all current DSA
  regulatory requirements complete and the 27-country compliance record
  `Active` without public trader contact details.
- [x] Re-open Apple’s age-rating questionnaire for Build 30. Keep Health or
  Wellness Topics and fixed Messaging/Chat, answer User-Generated Content Yes
  for the optional public name, and accept Apple’s recalculated rating. Apple
  saved those answers on August 23, 2026 and recalculated the app at 9+.
- [ ] After the physical-iPhone accessibility pass, prepare App Store
  Accessibility Nutrition Labels. Publish only features whose every common task
  meets Apple's criteria; automated semantics and layout tests alone are not
  enough evidence.
- [x] Create the 1024×500 Google Play feature graphic.
- [x] Capture and inspect the refreshed seven-frame iOS production set; the old
  illustrated interface set stays removed. The prior Android production set
  remains intentionally frozen while publication is deferred.
- [x] Upload the refreshed seven 1290×2796 iPhone screenshots to App Store
  Connect and verify their persisted order is Quests, Reward, Plans, My Space,
  Change Space, Journal, then Discover. The saved 6.9-inch set contains seven
  screenshots and Apple reuses it for the 6.5-inch display.
- [ ] Upload the final Google Play screenshots.
- [ ] Supply review-only credentials if a reviewer asks to test an existing
  cross-device account.
- [x] Verify hosted privacy and deletion pages immediately before submit; both
  returned HTTP 200 on August 9, 2026. Their deployed SHA-256 values exactly
  match the checked-in files: privacy
  `45D3434D95D3F768EFE57238C90E968CEED052C92E1214B4CBAD72FC87B1396B`
  and deletion
  `250AA4DD60F627A200408A070854B8FF6BFE224678D9CFB148A6625A2628B29D`.
- [x] Verify `https://roomofdays.com/support` immediately before submit; it
  returned HTTP 200 over the public HTTPS domain on August 9, 2026 and exactly
  matched the checked-in SHA-256
  `E827432EC49E710F265CF4B30E9C84673C4A542D145120E61F7D651637076638`.
- [ ] Submit manually and monitor processing, pre-launch reports, and review
  messages.

## Release decision

Do not submit while any of these are true:

- A signed mobile artifact has not been installed and smoke-tested.
- The Play artifact is debug-signed or the signing certificate is unknown.
- Store privacy answers differ from optional-cloud behavior.
- The support URL lacks working public contact information.
- Firebase account email exposes the retired name/project identity, or the
  review account has not completed a real password-reset cycle.
- Firebase rules in production differ from the checked-in rules.
- `SPACE_DISCOVERY` is enabled before the directory rules, TTL policy, live
  opt-in/opt-out smoke, and hosted privacy/community pages are verified.
- `PUBLIC_DISCOVERY_NAMES` is enabled before App Check enforcement, the name and
  report callables, owner-level bans, the daily moderation queue, and the
  truthful User-Generated Content store answers are all live.
- `VISITOR_PHOTO_SHARING` is enabled without an inspected Storage bucket,
  deployed rules, full production smoke, and matching privacy declarations.
- `VISITOR_PROFILE_SHARING` is enabled without the complete reviewed UGC safety
  operation and matching store declarations.
- Screenshots or copy depict a character/avatar or feature absent from the
  candidate binary.
