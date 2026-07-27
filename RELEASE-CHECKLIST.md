# Emberkeep Release Checklist

Updated July 26, 2026. “Repository-ready” means the source is prepared; it does
not replace a signed device build or store-console review.

## Repository-ready

- [x] Package/bundle ID is `com.mikabe.emberkeep` on Android and iOS.
- [x] Flutter stable targets Android API 36.
- [x] Android, iOS, and web Firebase apps are registered and configured.
- [x] Core experience works without account or network.
- [x] Cloud backup is explicit opt-in and account deletion exists in-app.
- [x] Privacy and deletion pages are live and linked from Me.
- [x] Shared keeps publish no free-form name, note, quest, or account data.
- [x] Firestore rules constrain shared data to known appearance/title values.
- [x] Android notification permission is declared and requested in context.
- [x] Exact-alarm permission is unnecessary; reminders use inexact scheduling.
- [x] Journal photos are local-only and erased by full reset.
- [x] Cold-start backgrounds match the dark Emberkeep canvas.
- [x] Native/PWA icons use the faceted, base-hot hearth mark.
- [x] Google Play 1024×500 feature graphic is ready in `store-assets/`.
- [x] Five opaque 1290×2796 production screenshots are ready in
  `store-assets/screenshots/`.
- [x] Release Gradle tasks cannot fall back to debug signing.
- [x] No ads, analytics, subscriptions, in-app purchases, or paywalls.
- [x] Store copy no longer mentions the retired character/avatar concept.

## Verify before every candidate

- [x] `dart format --output=none --set-exit-if-changed lib test`
- [x] `flutter analyze`
- [x] `flutter test`
- [x] `flutter build web --release`
- [ ] Render and inspect the screenshot-golden suite.
- [ ] Build a signed Android App Bundle and inspect its certificate.
- [ ] Build/upload iOS with Xcode 26+ and the iOS 26 SDK.
- [ ] Install release builds on physical Android and iPhone devices.
- [ ] Exercise fresh install, upgrade, offline, cloud, account deletion, media,
  notifications, export/restore, reset, sharing, large text, screen reader, and
  reduce-motion paths.
- [ ] Confirm the submitted version/build number exceeds every prior upload.

## Owner gates before submission

- [ ] Generate and safely back up the Android upload keystore.
- [ ] Create ignored `android/key.properties`; enroll in Play App Signing.
- [ ] Confirm Codemagic App Store Connect integration/signing secrets are valid.
- [ ] Publish a support URL with a real monitored email or contact method.
- [ ] Complete Apple App Privacy and Google Play Data safety questionnaires from
  `../STORE-LISTING.md`.
- [ ] Complete Apple’s current age-rating questionnaire.
- [x] Create the 1024×500 Google Play feature graphic.
- [x] Capture final production screenshots.
- [ ] Upload final production screenshots.
- [ ] Supply review-only credentials if a reviewer asks to test an existing
  cross-device account.
- [ ] Verify hosted privacy/deletion/support pages immediately before submit.
- [ ] Submit manually and monitor processing, pre-launch reports, and review
  messages.

## Release decision

Do not submit while any of these are true:

- A signed mobile artifact has not been installed and smoke-tested.
- The Play artifact is debug-signed or the signing certificate is unknown.
- Store privacy answers differ from optional-cloud behavior.
- The support URL lacks working public contact information.
- Firebase rules in production differ from the checked-in rules.
- Screenshots or copy depict a character/avatar or feature absent from the
  candidate binary.
