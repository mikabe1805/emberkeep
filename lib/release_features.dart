import 'package:flutter/foundation.dart';

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

/// Audience-specific My Space profiles. Store builds opt in only when the
/// protected profile publisher, public/mutual Firestore projections, Circle
/// relationship checks, posting filter, report/block path, and moderation
/// operation with timely human moderation are deployed together. The
/// local/default build remains off so it cannot imply that a backend
/// environment is ready when it is not.
const bool kVisitorProfileSharingEnabled = bool.fromEnvironment(
  'VISITOR_PROFILE_SHARING',
  defaultValue: false,
);

/// Opt-in browsing of a tiny room directory. Release workflows must choose
/// this explicitly so a local/debug build never implies that the production
/// rules, moderation, and policy operation are already live.
const bool kSpaceDiscoveryEnabled = bool.fromEnvironment(
  'SPACE_DISCOVERY',
  defaultValue: false,
);

/// Optional names in Discover are the only user-authored text on the public
/// directory. They stay independently gated because generated-only discovery
/// remains a safe fallback if the protected name service is unavailable.
const bool kPublicDiscoveryNamesEnabled =
    kSpaceDiscoveryEnabled &&
    bool.fromEnvironment('PUBLIC_DISCOVERY_NAMES', defaultValue: false);

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
const bool kAnonymousServiceIdentityRemovalEnabled =
    kPlaceSearchEnabled && !kIsWeb;

/// Public reCAPTCHA v3 site key used by App Check in web builds, including
/// protected social writes and visitor-profile reads. This is not a Google
/// Places credential. An enabled web build remains unavailable when the key is
/// absent rather than making unattested requests.
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
