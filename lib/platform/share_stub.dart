import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Native share (iOS/Android/desktop): hands the PNG to the OS share sheet
/// via share_plus. The web build uses share_web.dart instead. Returns true on
/// success; false (e.g. user dismissed) lets the caller fall back to text.
Future<bool> sharePng(Uint8List bytes, String filename, String text) async {
  try {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'image/png', name: filename)],
        text: text,
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  } catch (_) {
    return false;
  }
}
