# Room of Days Release Checklist

Updated August 8, 2026. “Repository-ready” means the source is prepared; it does
not replace a signed device build or store-console review.

## Repository-ready

- [x] Package/bundle ID is `com.mikabe.emberkeep` on Android and iOS.
- [x] Flutter stable targets Android API 36.
- [x] Android, iOS, and web Firebase apps are registered and configured.
- [x] Core experience works without account or network.
- [x] Cloud backup is explicit opt-in and account deletion exists in-app.
- [x] Privacy and deletion pages are live and linked from Me.
- [x] Visitor profiles are private by default and publish only the display name
  and profile cards independently marked for visitors.
- [x] Shared Pinned moments publish only bounded, deliberately selected writing.
  Journal photos and unselected pages never enter the v1 visitor payload;
  quest detail, streak, email, and account data stay private.
- [x] Firestore rules bound every shared appearance, presence, and opt-in
  profile field; exact room-code reads work while collection listing is denied.
- [x] Android notification permission is declared and requested in context.
- [x] Exact-alarm permission is unnecessary; reminders use inexact scheduling.
- [x] Journal photos remain local and are excluded from cloud backup and the v1
  visitor page.
- [x] Cold-start backgrounds match the dark Room of Days canvas.
- [x] Native/PWA icons use the approved lit-window Room of Days mark.
- [x] The Apple association file is live at the apex domain with a JSON content
  type; verified August 8, 2026.
- [x] Google Play 1024×500 feature graphic is ready in `store-assets/`.
- [x] Five opaque 1290×2796 production screenshots are ready in
  `store-assets/screenshots/`.
- [x] Release Gradle tasks cannot fall back to debug signing.
- [x] No ads, analytics, subscriptions, in-app purchases, or paywalls.
- [x] Store copy no longer mentions the retired character/avatar concept.

## Verify before every candidate

- [x] The v1 store candidate defaults `VISITOR_PHOTO_SHARING` off. Local My
  Space photos remain available, but the candidate exposes no visitor-photo
  switch and makes no visitor-photo Storage upload or download. The completed
  future infrastructure remains dormant until a separately reviewed build.

- [x] `dart format --output=none --set-exit-if-changed lib test tool`
- [x] `flutter analyze`
- [x] `flutter test`
- [x] `flutter build web --release`
- [x] Render and inspect the screenshot-golden suite; all 21 captures pass a
  second run without updating baselines, confirming deterministic output.
- [x] Build signed Android App Bundle and APK candidates for `1.0.0+4` on
  August 8, 2026. The AAB SHA-256 is
  `F3D7EF0A51D7B8108D5BDFC8B755E7EE28E8C8E0C907710C7CD1DAEBF88320B0`;
  the APK SHA-256 is
  `EC073C127FC16BED306B089FE20C60DEA51139D1AC9315F08843571477834DAD`.
  Both match upload certificate SHA-256
  `4F:28:DB:3A:70:C6:03:6A:B4:03:E4:2B:D5:3A:96:D1:73:DD:FD:C6:B7:8F:14:55:CC:26:C5:6C:47:C6:14:14`.
  Stable copies and install guidance are in `../release-artifacts/`.
- [ ] Build/upload iOS with Xcode 26+ and the iOS 26 SDK.
- [ ] Install release builds on physical Android and iPhone devices.
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
- [x] Repository candidate version is `1.0.0+4`; Codemagic still derives the
  next iOS build number from App Store Connect.
- [x] Deploy the checked-in Firestore rules before testing Share, Visit, or
  Circle; current rules compiled and were released to `emberkeep-5b33b` on
  August 8, 2026.
- [x] Run the repeatable authenticated production smoke: v5 publish, exact-code
  read, name hydration, anti-enumeration, versioned media-path validation,
  anti-downgrade, Circle/Spark delivery and owner-only reads, duplicate support
  rejection, self-Spark/self-Circle rejection, and cleanup all passed on
  August 8, 2026. Storage was intentionally excluded because it is not a v1
  runtime dependency.
  Re-run with
  `dart run tool/production_social_smoke.dart --confirm-production --firestore-only`;
  a future visitor-photo candidate must create its bucket, deploy
  `storage.rules`, and omit `--firestore-only` before enabling the build flag.
- [x] Reject malformed room codes before Firestore access, safely detach stale
  missing/non-owned codes, serialize all Firebase identity changes with guest
  startup, and preserve an owner-aware cleanup queue across offline resets.

## Owner gates before submission

- [x] Generate the Android upload keystore and configure ignored
  `android/key.properties`.
- [ ] Back up the upload keystore and password file off this machine.
- [ ] Enroll in Play App Signing.
- [ ] Confirm Codemagic App Store Connect integration/signing secrets are valid.
- [ ] Enable Associated Domains for the App ID and confirm the renewed iOS
  provisioning profile includes `applinks:roomofdays.com`.
- [ ] After the first Play upload, publish the Play App Signing SHA-256 in
  `assetlinks.json`, redeploy hosting, and verify Android App Links on-device.
- [x] Store builds default to no external coffee/payment link. A separately
  reviewed web or desktop build may opt in through `COFFEE_URL`.
- [x] Route `support@roomofdays.com` to a monitored inbox (owner confirmed).
- [ ] Complete Apple App Privacy and Google Play Data safety questionnaires from
  `../STORE-LISTING.md`.
- [ ] Complete Apple’s current age-rating questionnaire.
- [x] Create the 1024×500 Google Play feature graphic.
- [x] Capture final production screenshots.
- [ ] Upload final production screenshots.
- [ ] Supply review-only credentials if a reviewer asks to test an existing
  cross-device account.
- [x] Verify hosted privacy and deletion pages immediately before submit; both
  returned HTTP 200 on August 8, 2026. The deployed privacy page exactly matches
  the local v1 local-photo policy by SHA-256.
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
- Firebase rules in production differ from the checked-in rules.
- `VISITOR_PHOTO_SHARING` is enabled without an inspected Storage bucket,
  deployed rules, full production smoke, and matching privacy declarations.
- Screenshots or copy depict a character/avatar or feature absent from the
  candidate binary.
