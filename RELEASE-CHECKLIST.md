# Room of Days Release Checklist

Updated August 8, 2026. “Repository-ready” means the source is prepared; it does
not replace a signed device build or store-console review.

## Repository-ready

- [x] Package/bundle ID is `com.mikabe.emberkeep` on Android and iOS.
- [x] Flutter stable targets Android API 36.
- [x] Android, iOS, and web Firebase apps are registered and configured.
- [x] Core experience works without account or network.
- [x] Cloud backup is explicit opt-in and account deletion exists in-app.
- [x] Optional-account recovery has a least-access owner runbook. It uses
  Firebase's one-time reset email, never asks support to handle a password, and
  does not require changing the frozen Build 10 mobile candidate.
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
- [x] Android notification permission is declared and requested in context.
- [x] Exact-alarm permission is unnecessary; reminders use inexact scheduling.
- [x] Journal photos remain local and are excluded from cloud backup and shared
  rooms in v1.
- [x] Cold-start backgrounds match the dark Room of Days canvas.
- [x] Native/PWA icons use the approved lit-window Room of Days mark.
- [x] The Apple association file is live at the apex domain with a JSON content
  type; verified August 8, 2026.
- [x] Android's association endpoint is live at the apex domain as a valid
  empty JSON placeholder with an explicit JSON content type. It returned HTTP
  200 and matched the built file byte-for-byte on August 8, 2026 (SHA-256
  `37517E5F3DC66819F61F5A7BB8ACE1921282415F10551D2DEFA5C3EB0985B570`).
  It intentionally remains empty until Play App Signing supplies the final
  certificate.
- [x] Google Play 1024×500 feature graphic is ready in `store-assets/`.
- [x] Five opaque 24-bit RGB App Store screenshots at 1290×2796 and five
  independently rendered Google Play screenshots at 1080×1920 are ready in
  `store-assets/screenshots/`; every frame was opened and visually accepted.
- [x] Android 13+ themed icons use a dedicated monochrome Room of Days mark.
- [x] Release Gradle tasks cannot fall back to debug signing.
- [x] Android API/NDK versions and Codemagic's Flutter, Xcode, and CocoaPods
  versions are pinned; CI verifies the signed IPA's identity, version, privacy
  manifest, signature, and associated-domain entitlement.
- [x] No ads, analytics, subscriptions, in-app purchases, or paywalls.
- [x] The exact Android candidate requests neither Advertising ID nor broad
  photo/video access. Journal media uses the scoped system picker; Build 10 has
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

## Verify before every candidate

- [x] The v1 store candidate defaults `VISITOR_PHOTO_SHARING` off. Local My
  Space photos remain available, but the candidate exposes no visitor-photo
  switch and makes no visitor-photo Storage upload or download. The completed
  future infrastructure remains dormant until a separately reviewed build.
- [x] The v1 store candidate defaults `VISITOR_PROFILE_SHARING` off. Enabling it
  requires terms, filtering, reporting, blocking, and a timely human moderation
  workflow before any store build can expose user-authored visitor content.

- [x] `dart format --output=none --set-exit-if-changed lib test tool`
- [x] `flutter analyze`
- [x] `flutter test` (332 tests)
- [x] `flutter build web --release`
- [x] `dart run tool/verify_android_candidate.dart` verifies the immutable
  artifact hashes and handoff, source commit, package/version/SDK contract,
  permissions, app-link scope, APK/AAB signers, Bundletool configuration, ZIP
  alignment, and every native library's ELF LOAD alignment.
- [x] `dart run tool/verify_store_submission.dart` verifies store-field length
  limits, public URLs, privacy and health disclosures, candidate-version
  agreement, icons, feature graphic, and both exact five-image RGB screenshot
  sets.
- [x] Render and inspect the screenshot-golden suite; all 21 captures pass a
  second run without updating baselines, confirming deterministic output.
- [x] Build signed Android App Bundle and APK candidates for `1.0.0+10` from
  source commit `68f45ac2b67bc41dc79e492cd556751577107a24` on
  August 8, 2026. The AAB SHA-256 is
  `0D46FBFC6EAAC2AFDDDD0BE1EFFAB9FF8576FBA251B2B43EC8DED46CFE19A654`;
  the APK SHA-256 is
  `8EA8CC79BF289B440A5FD1B384DD6AAD8B1F03FC2FA5FD36A2B39AF6B7960D16`.
  Both match upload certificate SHA-256
  `4F:28:DB:3A:70:C6:03:6A:B4:03:E4:2B:D5:3A:96:D1:73:DD:FD:C6:B7:8F:14:55:CC:26:C5:6C:47:C6:14:14`.
  Stable copies and install guidance are in `../release-artifacts/`.
- [x] The Android app module's `:app:lintRelease` task completes successfully
  with 0 errors after upgrading the core-library desugaring runtime to the
  API-36-safe 2.1.5 release. Its remaining findings are non-blocking
  manifest/icon guidance. The Gradle root aggregate also analyzes pinned plugin
  source and currently stops on dependency-internal AGP 9 findings in
  `firebase_storage` and `flutter_local_notifications`, not Room of Days source.
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
- [x] Install signed Build 10 over signed Build 9 on the API 36 emulator. The
  package upgraded from version code 9 to 10 without onboarding returning and
  preserved 10 XP. First-time sharing then produced a publicly readable v5
  room with every profile/photo field empty; Stop Sharing revoked the code.
- [x] Exercise the remaining release-mode data paths on API 36: a manual backup
  restored 23 XP back to its stashed 10-XP state across a cold relaunch; an
  Android scoped-picker photo and Journal text survived force-stop; optional
  backup, account create, sign-out, sign-in, and account deletion all completed;
  deletion invalidated the temporary credentials and returned an empty Journal.
- [ ] Build/upload iOS with Xcode 26+ and the iOS 26 SDK.
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
- [ ] Confirm the submitted version/build number exceeds every prior upload.
- [x] Repository candidate version is `1.0.0+10`; Codemagic keeps Build 10 as
  the iOS floor and increments only when App Store Connect already contains an
  equal or higher TestFlight build.
- [x] Deploy the checked-in Firestore rules before testing Share, Visit, or
  Circle; current rules compiled and were released to `emberkeep-5b33b` on
  August 8, 2026.
- [x] Run the repeatable authenticated production smoke: v5 publish, exact-code
  generated-only read, anti-enumeration, visitor-writing and photo-path
  rejection, anti-downgrade, Circle/Spark delivery and owner-only reads,
  duplicate support rejection, self-Spark/self-Circle rejection, and cleanup
  all passed again under the Build 10 source on August 8, 2026. Cleanup now
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
- [ ] Confirm Codemagic App Store Connect integration/signing secrets are valid.
- [ ] In App Store Connect TestFlight Test Information, paste the Beta App
  Description and What to Test copy from `../STORE-LISTING.md`, use the
  monitored support inbox as Feedback Email, and complete the review contact
  fields before Codemagic's `submit_to_testflight` post-processing runs.
- [ ] Enable Associated Domains for the App ID and confirm the renewed iOS
  provisioning profile includes `applinks:roomofdays.com`.
- [ ] After the first Play upload, publish the Play App Signing SHA-256 in
  `web/.well-known/assetlinks.json` (replacing the valid empty array), redeploy
  hosting, and verify Android App Links on-device.
- [x] Store builds default to no external coffee/payment link. A separately
  reviewed web or desktop build may opt in through `COFFEE_URL`.
- [x] Route `support@roomofdays.com` to a monitored inbox (owner confirmed).
- [ ] Complete Apple App Privacy and Google Play Data safety questionnaires from
  `../STORE-LISTING.md`.
- [ ] Complete Google Play's Health Apps declaration from `../STORE-LISTING.md`;
  do not claim that the app has no health features. Confirm the declaration
  includes Activity and Fitness, Nutrition and Weight Management, Sleep
  Management, and Stress Management / Relaxation / Mental Acuity.
- [ ] Confirm the Play developer account satisfies Google's Organization-account
  requirement for health apps, including verifiable organization details and a
  D-U-N-S number. Do not submit under an ineligible Personal account.
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
  `../STORE-LISTING.md`: Ads No; sign-in details supplied; target audience and
  content rating; Data safety; Health apps; Financial features None;
  Government apps No; News and Magazine No; COVID-19 No; Advertising ID No;
  and any additional card Play Console marks `Needs attention`.
- [ ] Enter `https://roomofdays.com/delete-account` as Google Play's account
  deletion URL and verify the public request workflow from the console.
- [ ] In App Store Connect, set Content Rights to Yes for the licensed fonts and
  audio; use Apple's standard EULA; enter the exact legal copyright owner and
  required App Review contact name/email/phone; and confirm the uploaded build
  reports no non-exempt encryption.
- [ ] Complete Apple's DSA trader/non-trader self-assessment. If trader applies,
  finish verification of the contact details Apple will publish in EU product
  pages; do not select non-trader merely to avoid publishing them.
- [ ] Complete Apple’s current age-rating questionnaire.
- [ ] After the physical-iPhone accessibility pass, prepare App Store
  Accessibility Nutrition Labels. Publish only features whose every common task
  meets Apple's criteria; automated semantics and layout tests alone are not
  enough evidence.
- [x] Create the 1024×500 Google Play feature graphic.
- [x] Capture and inspect final production screenshots for both store-specific
  aspect ratios; the old illustrated interface set has been removed.
- [ ] Upload final production screenshots.
- [ ] Supply review-only credentials if a reviewer asks to test an existing
  cross-device account.
- [x] Verify hosted privacy and deletion pages immediately before submit; both
  returned HTTP 200 on August 8, 2026. The deployed privacy and deletion pages
  exactly match the checked-in files by SHA-256.
- [x] Verify `https://roomofdays.com/support` immediately before submit; it
  returned HTTP 200 over the public HTTPS domain on August 8, 2026.
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
- `VISITOR_PHOTO_SHARING` is enabled without an inspected Storage bucket,
  deployed rules, full production smoke, and matching privacy declarations.
- `VISITOR_PROFILE_SHARING` is enabled without the complete reviewed UGC safety
  operation and matching store declarations.
- Screenshots or copy depict a character/avatar or feature absent from the
  candidate binary.
