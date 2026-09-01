import 'dart:js_interop';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:web/web.dart' as web;

enum ShareTextResult { shared, dismissed, unavailable }

/// Share a PNG via the browser. Tries the Web Share API with files first
/// (the native share sheet on iOS/Android — exactly what an installed PWA
/// wants), and falls back to a plain download when that isn't available.
/// Returns true if something happened (shared or downloaded).
Future<bool> sharePng(Uint8List bytes, String filename, String text) async {
  // 1) native share sheet with the image as a file
  try {
    final file = web.File(
      <JSAny>[bytes.toJS].toJS,
      filename,
      web.FilePropertyBag(type: 'image/png'),
    );
    final data = web.ShareData(
      files: <web.File>[file].toJS,
      title: 'Room of Days',
      text: text,
    );
    if (web.window.navigator.canShare(data)) {
      try {
        await web.window.navigator.share(data).toDart;
        return true;
      } catch (_) {
        // user dismissed the sheet — don't also trigger a download
        return false;
      }
    }
  } catch (_) {
    // share API / file-share unsupported → fall through to download
  }

  // 2) download the PNG
  try {
    final blob = web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'image/png'),
    );
    final url = web.URL.createObjectURL(blob);
    final a = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = filename;
    web.document.body?.appendChild(a);
    a.click();
    a.remove();
    web.URL.revokeObjectURL(url);
    return true;
  } catch (_) {
    return false;
  }
}

/// Shares the editable iCalendar starter when file sharing is available, then
/// falls back to a normal .ics download on desktop browsers.
Future<bool> shareCalendarFile(String contents, String filename) async {
  final bytes = Uint8List.fromList(utf8.encode(contents));
  try {
    final file = web.File(
      <JSAny>[bytes.toJS].toJS,
      filename,
      web.FilePropertyBag(type: 'text/calendar;charset=utf-8'),
    );
    final data = web.ShareData(
      files: <web.File>[file].toJS,
      title: 'Room of Days class schedule starter',
      text:
          'Edit the class details, keep the iCalendar formatting, then open the file in Room of Days to review it.',
    );
    if (web.window.navigator.canShare(data)) {
      try {
        await web.window.navigator.share(data).toDart;
        return true;
      } catch (_) {
        return false;
      }
    }
  } catch (_) {
    // File sharing is optional; fall through to a local download.
  }
  try {
    final blob = web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'text/calendar;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = filename;
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
    return true;
  } catch (_) {
    return false;
  }
}

Future<ShareTextResult> shareText(String text, {Rect? origin}) async {
  try {
    await web.window.navigator
        .share(web.ShareData(title: 'Visit my space', text: text))
        .toDart;
    return ShareTextResult.shared;
  } catch (error) {
    if (error.toString().contains('AbortError')) {
      return ShareTextResult.dismissed;
    }
    return ShareTextResult.unavailable;
  }
}
