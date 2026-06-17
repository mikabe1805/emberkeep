import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

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
      title: 'Emberkeep',
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
