import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// One GET for a calendar link, from this device straight to the calendar's
/// host. Every hop must be HTTPS (a redirect to plain http is refused), the
/// whole read must finish inside [timeLimit], and a body over [maxBytes] is
/// refused before it is all downloaded. The request sends no cookies,
/// referrer, account or device details, and nothing is cached or written.
///
/// [allowLoopbackHttpForTests] lets tests serve a calendar from a local
/// `http://127.0.0.1` server; only loopback addresses are ever exempt.
Future<Uint8List> fetchCalendarBytes(
  Uri uri, {
  required int maxBytes,
  Duration timeLimit = const Duration(seconds: 20),
  int maxRedirects = 5,
  bool allowLoopbackHttpForTests = false,
}) async {
  final client = HttpClient()
    ..connectionTimeout = timeLimit
    ..idleTimeout = const Duration(seconds: 1)
    ..autoUncompress = true
    ..userAgent = 'RoomOfDays (calendar import)';
  // Straight to the host: never through a configured proxy.
  client.findProxy = (_) => 'DIRECT';
  try {
    return await _read(
      client,
      uri,
      maxBytes: maxBytes,
      maxRedirects: maxRedirects,
      allowLoopbackHttp: allowLoopbackHttpForTests,
    ).timeout(timeLimit);
  } on TimeoutException {
    throw const FormatException(
      'The calendar took too long to answer. Try again in a moment.',
    );
  } on HandshakeException {
    throw const FormatException(
      'That calendar link isn’t secure enough to open.',
    );
  } on TlsException {
    throw const FormatException(
      'That calendar link isn’t secure enough to open.',
    );
  } on SocketException {
    throw const FormatException(
      'Room of Days couldn’t reach that calendar. Check the connection and '
      'try again.',
    );
  } on HttpException {
    throw const FormatException(
      'The calendar didn’t answer just now. Try again in a moment.',
    );
  } finally {
    client.close(force: true);
  }
}

bool _allowed(Uri uri, {required bool allowLoopbackHttp}) {
  if (uri.scheme == 'https') return true;
  if (!allowLoopbackHttp || uri.scheme != 'http') return false;
  final host = uri.host;
  return host == '127.0.0.1' || host == 'localhost' || host == '::1';
}

Future<Uint8List> _read(
  HttpClient client,
  Uri start, {
  required int maxBytes,
  required int maxRedirects,
  required bool allowLoopbackHttp,
}) async {
  var uri = start;
  for (var hop = 0; ; hop++) {
    if (!_allowed(uri, allowLoopbackHttp: allowLoopbackHttp)) {
      throw const FormatException(
        'That calendar link isn’t secure enough to open.',
      );
    }
    final request = await client.getUrl(uri);
    request
      ..followRedirects = false
      ..persistentConnection = false;
    request.headers.set(HttpHeaders.acceptHeader, 'text/calendar, */*;q=0.5');
    final response = await request.close();
    if (response.isRedirect) {
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();
      if (location == null || hop >= maxRedirects) {
        throw const FormatException(
          'The calendar didn’t answer just now. Try again in a moment.',
        );
      }
      uri = uri.resolve(location);
      continue;
    }
    final status = response.statusCode;
    if (status == 401 || status == 403 || status == 404 || status == 410) {
      await response.drain<void>();
      throw const FormatException(
        'That calendar is private or the link has changed. Copy a fresh '
        'private (secret) link and try again.',
      );
    }
    if (status != 200) {
      await response.drain<void>();
      throw const FormatException(
        'The calendar didn’t answer just now. Try again in a moment.',
      );
    }
    if (response.contentLength > maxBytes) {
      throw const FormatException(
        'That calendar is very large. Export just your class calendar and '
        'try again.',
      );
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
      if (builder.length > maxBytes) {
        throw const FormatException(
          'That calendar is very large. Export just your class calendar and '
          'try again.',
        );
      }
    }
    return builder.takeBytes();
  }
}
