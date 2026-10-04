// The calendar-link read (Add your classes, 2026-10-03) against a local
// server: one GET straight to the host, HTTPS only (loopback http is the only
// test exemption), a 2 MB cap, a time limit, plain messages, and a request
// that carries nothing about the student or the phone.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:emberkeep/academic_calendar/import/calendar_link_fetch_io.dart';
import 'package:flutter_test/flutter_test.dart';

const _calendar =
    'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:u1\r\n'
    'DTSTART:20260908T130000Z\r\nDTEND:20260908T141500Z\r\n'
    'SUMMARY:PHYS 211 Lecture\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n';

Matcher _says(String words) => throwsA(
  isA<FormatException>().having(
    (error) => error.message,
    'message',
    contains(words),
  ),
);

void main() {
  late HttpServer server;
  late Future<void> Function(HttpRequest request) handler;
  final requests = <HttpRequest>[];

  setUp(() async {
    requests.clear();
    handler = (request) async {
      request.response
        ..headers.contentType = ContentType('text', 'calendar')
        ..write(_calendar);
      await request.response.close();
    };
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request);
      await handler(request);
    });
  });

  tearDown(() => server.close(force: true));

  Uri at(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

  Future<String> read(
    String path, {
    int maxBytes = 2 * 1024 * 1024,
    Duration timeLimit = const Duration(seconds: 20),
  }) async => utf8.decode(
    await fetchCalendarBytes(
      at(path),
      maxBytes: maxBytes,
      timeLimit: timeLimit,
      allowLoopbackHttpForTests: true,
    ),
  );

  test('reads the calendar and sends nothing about the student', () async {
    expect(await read('/private-abc/basic.ics'), _calendar);
    final request = requests.single;
    expect(request.method, 'GET');
    expect(request.cookies, isEmpty);
    expect(request.headers.value(HttpHeaders.cookieHeader), isNull);
    expect(request.headers.value(HttpHeaders.refererHeader), isNull);
    expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
    expect(
      request.headers.value(HttpHeaders.userAgentHeader),
      'RoomOfDays (calendar import)',
    );
    expect(
      request.headers.value(HttpHeaders.acceptHeader),
      contains('text/calendar'),
    );
  });

  test('plain http is refused before anything is sent', () async {
    await expectLater(
      fetchCalendarBytes(
        Uri.parse('http://calendar.example.edu/feed.ics'),
        maxBytes: 1024,
      ),
      _says('secure'),
    );
    // Loopback http is only open when a test asks for it.
    await expectLater(
      fetchCalendarBytes(at('/feed.ics'), maxBytes: 1024),
      _says('secure'),
    );
    expect(requests, isEmpty);
  });

  test('a redirect to plain http elsewhere is refused', () async {
    handler = (request) async {
      request.response
        ..statusCode = HttpStatus.found
        ..headers.set(
          HttpHeaders.locationHeader,
          'http://calendar.example.edu/x.ics',
        );
      await request.response.close();
    };
    await expectLater(read('/feed.ics'), _says('secure'));
    expect(requests, hasLength(1));
  });

  test(
    'a redirect on the same host is followed, a few times at most',
    () async {
      handler = (request) async {
        if (request.uri.path == '/final.ics') {
          request.response.write(_calendar);
        } else {
          request.response
            ..statusCode = HttpStatus.movedPermanently
            ..headers.set(HttpHeaders.locationHeader, '/final.ics');
        }
        await request.response.close();
      };
      expect(await read('/start.ics'), _calendar);

      handler = (request) async {
        request.response
          ..statusCode = HttpStatus.found
          ..headers.set(HttpHeaders.locationHeader, '/again.ics');
        await request.response.close();
      };
      requests.clear();
      await expectLater(read('/loop.ics'), _says('didn’t answer'));
      expect(requests.length, lessThanOrEqualTo(6));
    },
  );

  test('more than the cap is refused, announced or streamed', () async {
    handler = (request) async {
      request.response
        ..contentLength = 4096
        ..add(List<int>.filled(4096, 65));
      await request.response.close();
    };
    await expectLater(read('/big.ics', maxBytes: 1024), _says('very large'));

    handler = (request) async {
      request.response.headers.chunkedTransferEncoding = true;
      for (var i = 0; i < 8; i++) {
        request.response.add(List<int>.filled(512, 66));
        await request.response.flush();
      }
      await request.response.close();
    };
    await expectLater(
      read('/streamed.ics', maxBytes: 1024),
      _says('very large'),
    );
  });

  test('a calendar that does not answer in time gets a calm message', () async {
    final release = Completer<void>();
    handler = (request) async {
      await release.future;
      await request.response.close();
    };
    await expectLater(
      read('/slow.ics', timeLimit: const Duration(milliseconds: 300)),
      _says('took too long'),
    );
    release.complete();
  });

  test('a private or changed link says how to get a fresh one', () async {
    for (final status in const [401, 403, 404, 410]) {
      handler = (request) async {
        request.response.statusCode = status;
        await request.response.close();
      };
      await expectLater(read('/gone.ics'), _says('private'));
    }
    handler = (request) async {
      request.response.statusCode = 503;
      await request.response.close();
    };
    await expectLater(read('/busy.ics'), _says('Try again'));
  });

  test('a host that is not there gets a plain message', () async {
    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close();
    await expectLater(
      fetchCalendarBytes(
        Uri.parse('http://127.0.0.1:$port/feed.ics'),
        maxBytes: 1024,
        timeLimit: const Duration(seconds: 5),
        allowLoopbackHttpForTests: true,
      ),
      _says('couldn’t reach'),
    );
  });
}
