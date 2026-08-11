import 'package:url_launcher/url_launcher.dart';

const String configuredNotebookIntentBase = String.fromEnvironment(
  'ROOM_NOTES_INTENT_BASE',
  defaultValue: 'notebook-preview://calendar/open',
);

final class NotebookHandoffIntent {
  NotebookHandoffIntent({
    required String courseId,
    required String occurrenceKey,
    this.notebookId,
    this.pageId,
    this.courseCode,
    this.courseTitle,
    this.occurrenceDate,
    this.startMinute,
    this.endMinute,
    this.meetingKind,
    this.place,
    this.courseColorValue,
  }) : courseId = _opaqueId(courseId, 'courseId'),
       occurrenceKey = _opaqueId(occurrenceKey, 'occurrenceKey') {
    if (notebookId != null) _opaqueId(notebookId!, 'notebookId');
    if (pageId != null) _opaqueId(pageId!, 'pageId');
    _hint(courseCode, 'courseCode', 40);
    _hint(courseTitle, 'courseTitle', 160);
    _civilDate(occurrenceDate);
    _minute(startMinute, 'startMinute', allowEndOfDay: false);
    _minute(endMinute, 'endMinute', allowEndOfDay: true);
    if (startMinute != null &&
        endMinute != null &&
        endMinute! <= startMinute!) {
      throw ArgumentError('endMinute must be after startMinute');
    }
    if (meetingKind != null && !_meetingKinds.contains(meetingKind)) {
      throw ArgumentError.value(meetingKind, 'meetingKind');
    }
    _hint(place, 'place', 160);
    if (courseColorValue != null &&
        (courseColorValue! < 0 || courseColorValue! > 0xFFFFFFFF)) {
      throw ArgumentError.value(courseColorValue, 'courseColorValue');
    }
  }

  final String courseId;
  final String occurrenceKey;
  final String? notebookId;
  final String? pageId;
  final String? courseCode;
  final String? courseTitle;
  final String? occurrenceDate;
  final int? startMinute;
  final int? endMinute;
  final String? meetingKind;
  final String? place;
  final int? courseColorValue;
}

/// The sender-side half of the shared version-2 notebook contract.
final class NotebookHandoffCodec {
  NotebookHandoffCodec({required Uri baseUri})
    : baseUri = _validatedBase(baseUri);

  factory NotebookHandoffCodec.fromBase(String rawBase) {
    final parsed = Uri.tryParse(rawBase);
    if (parsed == null) {
      throw ArgumentError.value(rawBase, 'rawBase', 'Must be a valid URI');
    }
    return NotebookHandoffCodec(baseUri: parsed);
  }

  final Uri baseUri;

  Uri encode(NotebookHandoffIntent intent) => baseUri.replace(
    queryParameters: {
      'v': '2',
      'courseId': intent.courseId,
      'occurrenceKey': intent.occurrenceKey,
      if (intent.notebookId != null) 'notebookId': intent.notebookId!,
      if (intent.pageId != null) 'pageId': intent.pageId!,
      if (intent.courseCode != null) 'courseCode': intent.courseCode!,
      if (intent.courseTitle != null) 'courseTitle': intent.courseTitle!,
      if (intent.occurrenceDate != null)
        'occurrenceDate': intent.occurrenceDate!,
      if (intent.startMinute != null)
        'startMinute': intent.startMinute!.toString(),
      if (intent.endMinute != null) 'endMinute': intent.endMinute!.toString(),
      if (intent.meetingKind != null) 'meetingKind': intent.meetingKind!,
      if (intent.place != null) 'place': intent.place!,
      if (intent.courseColorValue != null)
        'courseColor': intent.courseColorValue!
            .toRadixString(16)
            .padLeft(8, '0')
            .toUpperCase(),
    },
  );
}

enum NotebookHandoffResult { opened, unavailable, failed }

abstract interface class NotebookHandoff {
  Future<NotebookHandoffResult> open(NotebookHandoffIntent intent);
}

final class UrlLauncherNotebookHandoff implements NotebookHandoff {
  UrlLauncherNotebookHandoff(this._codec);

  factory UrlLauncherNotebookHandoff.configured() => UrlLauncherNotebookHandoff(
    NotebookHandoffCodec.fromBase(configuredNotebookIntentBase),
  );

  final NotebookHandoffCodec _codec;

  @override
  Future<NotebookHandoffResult> open(NotebookHandoffIntent intent) async {
    try {
      final opened = await launchUrl(
        _codec.encode(intent),
        mode: LaunchMode.externalApplication,
      );
      return opened
          ? NotebookHandoffResult.opened
          : NotebookHandoffResult.unavailable;
    } catch (_) {
      return NotebookHandoffResult.failed;
    }
  }
}

Uri _validatedBase(Uri uri) {
  const networkSchemes = {'http', 'https', 'ws', 'wss', 'ftp'};
  if (!uri.hasScheme ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      networkSchemes.contains(uri.scheme.toLowerCase()) ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw ArgumentError.value(
      uri,
      'baseUri',
      'Must be an absolute custom-scheme URI without query or fragment',
    );
  }
  return uri;
}

String _opaqueId(String value, String name) {
  final clean = value.trim();
  if (clean.isEmpty || clean.runes.any((rune) => rune < 0x20 || rune == 0x7f)) {
    throw ArgumentError.value(
      value,
      name,
      'Must be a non-blank opaque ID without control characters',
    );
  }
  return clean;
}

const _meetingKinds = {'lecture', 'lab', 'recitation', 'studio', 'officeHours'};

void _hint(String? value, String name, int maxLength) {
  if (value == null) return;
  if (value.trim().isEmpty ||
      value.runes.length > maxLength ||
      value.runes.any((rune) => rune < 0x20 || rune == 0x7f)) {
    throw ArgumentError.value(value, name);
  }
}

void _civilDate(String? value) {
  if (value == null) return;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) throw ArgumentError.value(value, 'occurrenceDate');
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    throw ArgumentError.value(value, 'occurrenceDate');
  }
}

void _minute(int? value, String name, {required bool allowEndOfDay}) {
  if (value == null) return;
  final maximum = allowEndOfDay ? 24 * 60 : 24 * 60 - 1;
  if (value < 0 || value > maximum) throw ArgumentError.value(value, name);
}
