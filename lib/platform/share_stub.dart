import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

enum ShareTextResult { shared, dismissed, unavailable }

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

/// Hand plain invitation copy to the system share sheet. WhatsApp and any
/// other installed messaging apps appear naturally without hard-coding one.
Future<ShareTextResult> shareText(String text, {Rect? origin}) async {
  try {
    final result = await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: origin),
    );
    return switch (result.status) {
      ShareResultStatus.success => ShareTextResult.shared,
      ShareResultStatus.dismissed => ShareTextResult.dismissed,
      ShareResultStatus.unavailable => ShareTextResult.unavailable,
    };
  } catch (_) {
    return ShareTextResult.unavailable;
  }
}
