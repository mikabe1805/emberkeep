/// Calendar links a student can paste: a Google Calendar secret iCal address,
/// an Outlook published ICS link, an iCloud public calendar, a Canvas feed, or
/// a school portal feed.
///
/// Privacy: the phone reads the link once, straight from the calendar's own
/// host, over HTTPS. No Room of Days server or other service sits between,
/// the request carries no cookies, account or device details, and neither
/// the link nor the downloaded calendar is written anywhere. Only the classes
/// the student then picks are saved, in the on-device schedule.
library;

import 'dart:async';
import 'dart:convert';

import 'calendar_link_fetch_stub.dart'
    if (dart.library.io) 'calendar_link_fetch_io.dart';

/// Where a link comes from, so the review can say something specific.
enum CalendarLinkSource { google, outlook, icloud, canvas, other }

final class CalendarLink {
  const CalendarLink(this.uri, this.source);
  final Uri uri;
  final CalendarLinkSource source;

  /// A name for the review header that never repeats the secret part of the
  /// link (only the kind of calendar, or the host).
  String get displayName => switch (source) {
    CalendarLinkSource.google => 'Google Calendar link',
    CalendarLinkSource.outlook => 'Outlook link',
    CalendarLinkSource.icloud => 'iCloud link',
    CalendarLinkSource.canvas => 'Canvas feed',
    CalendarLinkSource.other => uri.host,
  };

  /// Accepts what people actually paste: webcal://, http(s)://, a link with
  /// spaces or angle brackets around it. Throws [FormatException] with a
  /// message that can be shown as is.
  static CalendarLink parse(String raw) {
    var text = raw.trim();
    text = text.replaceAll(RegExp(r'^[<"]+|[>"]+$'), '').trim();
    if (text.isEmpty) {
      throw const FormatException('Paste a calendar link first.');
    }
    if (!text.contains('://')) text = 'https://$text';
    var uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) {
      throw const FormatException(
        'That doesn’t look like a link. Copy the whole address and paste it again.',
      );
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'webcal' || scheme == 'webcals' || scheme == 'http') {
      uri = uri.replace(scheme: 'https');
    } else if (scheme != 'https') {
      throw const FormatException(
        'Room of Days can read web calendar links (https or webcal).',
      );
    }
    final host = uri.host.toLowerCase();
    final source = host.endsWith('google.com')
        ? CalendarLinkSource.google
        : host.contains('outlook') || host.contains('office365')
        ? CalendarLinkSource.outlook
        : host.endsWith('icloud.com')
        ? CalendarLinkSource.icloud
        : host.contains('instructure.com') ||
              uri.path.contains('/feeds/calendars/')
        ? CalendarLinkSource.canvas
        : CalendarLinkSource.other;
    if (source == CalendarLinkSource.google &&
        (uri.path.contains('/embed') || uri.path.endsWith('/r'))) {
      throw const FormatException(
        'That is the Google Calendar page link. In Google Calendar settings, '
        'copy “Secret address in iCal format” instead.',
      );
    }
    return CalendarLink(uri, source);
  }
}

/// Reads a calendar link. Swap in a fake for tests and renders.
abstract interface class CalendarLinkFetcher {
  Future<String> fetch(CalendarLink link);
}

/// The device fetch: one HTTPS GET straight to the calendar host, 20 seconds
/// for the whole read, 2 MB at most, no cookies, nothing stored. Errors are
/// [FormatException]s with showable messages.
final class PlatformCalendarLinkFetcher implements CalendarLinkFetcher {
  const PlatformCalendarLinkFetcher();

  static const maxBytes = 2 * 1024 * 1024;
  static const timeLimit = Duration(seconds: 20);

  @override
  Future<String> fetch(CalendarLink link) async {
    final bytes = await fetchCalendarBytes(
      link.uri,
      maxBytes: maxBytes,
      timeLimit: timeLimit,
    );
    return checkCalendarText(utf8.decode(bytes, allowMalformed: true));
  }
}

/// Shared by the device fetch and tests: a calendar, or a showable reason.
String checkCalendarText(String text) {
  var body = text;
  if (body.startsWith('﻿')) body = body.substring(1);
  if (!body.contains('BEGIN:VCALENDAR')) {
    throw const FormatException(
      'That link opens a web page. Look for the link that ends in .ics, or '
      'the one labeled iCal.',
    );
  }
  return body;
}

/// Lets render tests of the whole app serve a calendar without a network.
/// Production leaves it null; the sheet's own `linkFetcher` wins over it.
CalendarLinkFetcher? debugCalendarLinkFetcherOverride;
