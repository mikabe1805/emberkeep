import 'dart:typed_data';

/// The web build cannot read most calendar hosts (they send no CORS headers),
/// so the sheet hides the link path there and offers the file path instead.
Future<Uint8List> fetchCalendarBytes(
  Uri uri, {
  required int maxBytes,
  Duration timeLimit = const Duration(seconds: 20),
  int maxRedirects = 5,
  bool allowLoopbackHttpForTests = false,
}) async {
  throw const FormatException(
    'Calendar links open in the iPhone app. Here, download the .ics file and '
    'choose it instead.',
  );
}
