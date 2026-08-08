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
  Profile and This season each have a separate, off-by-default photo consent;
  every other photo/page, quest detail, streak, email, and account datum stays
  private.
- [x] Firestore rules bound every shared appearance, presence, and opt-in
  profile field; exact room-code reads work while collection listing is denied.
- [x] Android notification permission is declared and requested in context.
- [x] Exact-alarm permission is unnecessary; reminders use inexact scheduling.
- [x] Journal photos remain local by default; the two selected visitor copies
  are erased when withdrawn, unshared, reset, or account-deleted.
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

- [ ] Enable billing/Blaze, create the Firebase Storage bucket, and deploy
  `storage.rules` before testing visitor photos. On August 8, 2026, Google Cloud
  reported billing disabled and Firebase reported that Storage was not set up.

- [x] `dart format --output=none --set-exit-if-changed lib test tool`
- [x] `flutter analyze`
- [x] `flutter test`
- [x] `flutter build web --release`
- [x] Render and inspect the screenshot-golden suite; all 21 captures pass a
  second run without updating baselines, confirming deterministic output.
- [x] Build signed Android App Bundle and APK candidates for `1.0.0+2` on
  August 8, 2026. The AAB SHA-256 is
  `FA73AA98000F5F2F948ABD6D483BB55EE9387F252B21886EA276714058FB54E6`;
  the APK SHA-256 is
  `0183584AF16371A6A3149D3DA07328DA6A0C39C92FFB0B885C7DA2C7C12BB1C0`.
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
- [x] Repository candidate version is `1.0.0+2`; Codemagic still derives the
  next iOS build number from App Store Connect.
- [x] Deploy the checked-in Firestore rules before testing Share, Visit, or
  Circle; current rules compiled and were released to `emberkeep-5b33b` on
  August 8, 2026.
- [x] Run the repeatable authenticated production smoke: v5 publish, exact-code
  read, name hydration, anti-enumeration, versioned media-path validation,
  anti-downgrade, Circle/Spark delivery and owner-only reads, duplicate support
  rejection, self-Spark/self-Circle rejection, and cleanup all passed on
  August 8, 2026. Storage was intentionally excluded until its bucket exists.
  Re-run with
  `dart run tool/production_social_smoke.dart --confirm-production --firestore-only`;
  after Storage exists and its rules are deployed, omit `--firestore-only`.
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
  returned HTTP 200 on August 8, 2026.
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
- Firebase Storage is absent while visitor-photo controls remain enabled in the
  candidate.
- Screenshots or copy depict a character/avatar or feature absent from the
  candidate binary.
