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
