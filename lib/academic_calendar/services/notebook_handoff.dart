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
  }) : courseId = _opaqueId(courseId, 'courseId'),
       occurrenceKey = _opaqueId(occurrenceKey, 'occurrenceKey') {
    if (notebookId != null) _opaqueId(notebookId!, 'notebookId');
    if (pageId != null) _opaqueId(pageId!, 'pageId');
  }

  final String courseId;
  final String occurrenceKey;
  final String? notebookId;
  final String? pageId;
}

/// The sender-side half of the shared version-1 notebook contract.
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
      'v': '1',
      'courseId': intent.courseId,
      'occurrenceKey': intent.occurrenceKey,
      if (intent.notebookId != null) 'notebookId': intent.notebookId!,
      if (intent.pageId != null) 'pageId': intent.pageId!,
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
