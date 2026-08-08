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
