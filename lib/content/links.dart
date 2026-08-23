/// Every URL a person can see, in one place.
///
/// The base is deliberately a single constant: changing [_base] — or passing
/// `--dart-define=SHARE_BASE_URL=https://…` at build time — moves the invite
/// links, the privacy page, and account deletion together. Nothing else in
/// lib/ may hardcode a public host. Firebase-infrastructure hosts
/// (firebase_options.dart) are not public links and stay as they are.
abstract final class PublicLinks {
  static const _base = String.fromEnvironment(
    'SHARE_BASE_URL',
    defaultValue: 'https://roomofdays.com',
  );

  /// The invite/landing origin — room links hang query codes off this.
  static const String home = _base;

  static const String privacy = '$_base/privacy';
  static const String community = '$_base/community';
  static const String terms = '$_base/terms';
  static const String deleteAccount = '$_base/delete-account';
  static const String support = '$_base/support';
}
