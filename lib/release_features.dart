/// Capabilities that are complete in source but deliberately absent from the
/// first store candidate.
///
/// Visitor-photo sharing needs a reviewed Firebase Storage bucket and deployed
/// rules. Keeping the default false makes the ordinary release build local-only
/// for journal photos. A later, separately verified candidate can opt in with
/// `--dart-define=VISITOR_PHOTO_SHARING=true`.
const bool kVisitorPhotoSharingEnabled = bool.fromEnvironment(
  'VISITOR_PHOTO_SHARING',
  defaultValue: false,
);

/// User-authored visitor profiles require a complete UGC safety operation:
/// posting filters, terms, reporting, blocking, and timely human moderation.
/// The first store release keeps My Space writing private and shares only the
/// app-generated room/presence payload. Do not enable this flag in a store build
/// until those controls and the moderation workflow have been reviewed.
const bool kVisitorProfileSharingEnabled = bool.fromEnvironment(
  'VISITOR_PROFILE_SHARING',
  defaultValue: false,
);

/// Protected Google place search stays absent unless every external release
/// gate (billing, server secret, quotas, policy pages, and App Check
/// enforcement) has been completed and the build opts in explicitly.
const bool kPlaceSearchEnabled = bool.fromEnvironment(
  'PLACE_SEARCH_ENABLED',
  defaultValue: false,
);

/// The scoped anonymous-service deletion control relies on the deployed
/// owner-only Firestore room query and deletion-tombstone rules. Coupling it to
/// the explicit place-search opt-in keeps default/off builds' existing Share
/// path unchanged and prevents the control from appearing before that server
/// capability is verified.
const bool kAnonymousServiceIdentityRemovalEnabled = kPlaceSearchEnabled;

/// Public reCAPTCHA v3 site key used only by App Check in web builds. This is
/// not a Google Places credential. An enabled web build remains unavailable
/// when the key is absent rather than making unattested callable requests.
const String kPlaceSearchAppCheckWebSiteKey = String.fromEnvironment(
  'PLACE_SEARCH_APP_CHECK_WEB_SITE_KEY',
  defaultValue: '',
);

/// Debug attestation must be an explicit build choice. Store candidates use
/// real Play Integrity/App Attest providers even when compiled in debug mode.
const bool kPlaceSearchAppCheckDebug = bool.fromEnvironment(
  'PLACE_SEARCH_APP_CHECK_DEBUG',
  defaultValue: false,
);
