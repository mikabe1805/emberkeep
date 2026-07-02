import 'dart:convert';

/// One block of a journal entry — either a paragraph of [text] or an inline
/// [image] (a relative filename under the app's journal-images dir). A free
/// journal entry is an ordered list of these, so photos sit between paragraphs
/// the way they do in a notes app. Serialized as compact JSON into Note.rich.
class JournalBlock {
  const JournalBlock.text(this.text) : image = null;
  const JournalBlock.image(this.image) : text = null;

  final String? text;
  final String? image;

  bool get isImage => image != null;

  Map<String, dynamic> toJson() =>
      isImage ? {'t': 'img', 'v': image} : {'t': 'p', 'v': text ?? ''};

  static JournalBlock fromJson(Map<String, dynamic> j) => j['t'] == 'img'
      ? JournalBlock.image((j['v'] as String?) ?? '')
      : JournalBlock.text((j['v'] as String?) ?? '');
}

/// Pure (no platform deps) encode/decode + flatteners for a journal document —
/// so it's web-safe and unit-testable. The blocks live in Note.rich; the
/// plain-text flattening lives in Note.text (previews/feed/search).
abstract final class JournalDoc {
  static String encode(List<JournalBlock> blocks) =>
      jsonEncode([for (final b in blocks) b.toJson()]);

  /// Decode Note.rich → blocks. Never throws (garbage → empty list), matching
  /// the restore-resilience of the rest of the model.
  static List<JournalBlock> decode(String? rich) {
    if (rich == null || rich.isEmpty) return [];
    try {
      final list = jsonDecode(rich);
      if (list is! List) return [];
      return [
        for (final e in list)
          if (e is Map) JournalBlock.fromJson(e.cast<String, dynamic>()),
      ];
    } catch (_) {
      return [];
    }
  }

  /// The plain-text flattening — what Note.text carries (paragraphs joined by
  /// blank lines; images skipped).
  static String plainText(List<JournalBlock> blocks) => blocks
      .where((b) => !b.isImage)
      .map((b) => b.text ?? '')
      .join('\n\n')
      .trim();

  /// The image filenames referenced, in order.
  static List<String> images(List<JournalBlock> blocks) =>
      [for (final b in blocks) if (b.isImage) b.image!];
}
