import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../tokens.dart';
import 'facets.dart';
import 'glass.dart';

/// The fixed, text-free support-note vocabulary and its picker sheet, shared
/// by the Circle screen (sparking a kept space) and the visit screen (leaving
/// a note after touring a room). One vocabulary, one sheet — the note reads
/// the same wherever it is sent from.

const List<String> sparkSupportKinds = ['kindle', 'steady', 'cheer'];

typedef SparkSender = Future<bool> Function(String code, String kind);
typedef SocialInboxFetcher =
    Future<
      ({
        List<Map<String, dynamic>> sparks,
        List<Map<String, dynamic>> circleAdds,
      })
    >
    Function(String code);

String normalizedSparkKind(Object? raw) =>
    raw is String && sparkSupportKinds.contains(raw)
    ? raw
    : sparkSupportKinds.first;

String sparkSupportTitle(String kind) => switch (normalizedSparkKind(kind)) {
  'steady' => 'Keep steady',
  'cheer' => 'Cheering you on',
  _ => 'A little warmth',
};

String sparkSupportDetail(String kind) => switch (normalizedSparkKind(kind)) {
  'steady' => 'Quiet support for whatever today is holding.',
  'cheer' => 'A small celebration from someone in your Circle.',
  _ => 'A warm note with no message or profile attached.',
};

String sparkSupportReceiptLabel(String kind) =>
    switch (normalizedSparkKind(kind)) {
      'steady' => 'A steady note',
      'cheer' => 'A cheer',
      _ => 'A little warmth',
    };

String sparkSupportReceiptPlural(String kind) =>
    switch (normalizedSparkKind(kind)) {
      'steady' => 'steady notes',
      'cheer' => 'cheers',
      _ => 'warm notes',
    };

IconData sparkSupportIcon(String kind) => switch (normalizedSparkKind(kind)) {
  'steady' => Icons.anchor_outlined,
  'cheer' => Icons.campaign_outlined,
  _ => Icons.local_fire_department_outlined,
};

Color sparkSupportColor(String kind) => switch (normalizedSparkKind(kind)) {
  'steady' => Palette.unlock,
  'cheer' => Palette.streak,
  _ => Palette.xpLight,
};

String sparkSupportNoticeText(Iterable<String> kinds) {
  final counts = <String, int>{};
  for (final raw in kinds) {
    final kind = normalizedSparkKind(raw);
    counts[kind] = (counts[kind] ?? 0) + 1;
  }
  final phrases = <String>[
    for (final kind in sparkSupportKinds)
      if ((counts[kind] ?? 0) > 0)
        switch ((kind, counts[kind]!)) {
          ('kindle', 1) => 'a little warmth',
          ('kindle', final count) => '$count warm notes',
          ('steady', 1) => 'a steady note',
          ('steady', final count) => '$count steady notes',
          ('cheer', 1) => 'a cheer',
          ('cheer', final count) => '$count cheers',
          _ => 'a little warmth',
        },
  ];
  if (phrases.isEmpty) return '';
  final joined = switch (phrases) {
    [final only] => only,
    [final first, final second] => '$first and $second',
    _ => '${phrases.take(phrases.length - 1).join(', ')}, and ${phrases.last}',
  };
  return 'Circle has $joined waiting for you.';
}

class SparkPickerSheet extends StatelessWidget {
  const SparkPickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: GlassPanel(
            tint: Palette.dialogSurface,
            radius: 24,
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 46,
                      height: 3,
                      color: Palette.textLo.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Send support',
                    style: Type.display.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Choose one fixed note. No custom text, profile details, or task information is attached.',
                    style: Type.body.copyWith(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Palette.textLo,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (
                    var index = 0;
                    index < sparkSupportKinds.length;
                    index++
                  ) ...[
                    _SparkChoice(kind: sparkSupportKinds[index]),
                    if (index != sparkSupportKinds.length - 1)
                      const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'ONE NOTE PER PERSON UNTIL IT IS COLLECTED',
                      textAlign: TextAlign.center,
                      style: Type.label.copyWith(
                        fontSize: Type.minLabel,
                        color: Palette.textLo,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SparkChoice extends StatelessWidget {
  const _SparkChoice({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    final title = sparkSupportTitle(kind);
    final detail = sparkSupportDetail(kind);
    final color = sparkSupportColor(kind);
    return Semantics(
      button: true,
      label: '$title. $detail',
      onTap: () => Navigator.of(context).pop(kind),
      child: GestureDetector(
        key: ValueKey('spark-kind-$kind'),
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Sfx.instance.playMaterial(MaterialSound.glass);
          HapticFeedback.selectionClick();
          Navigator.of(context).pop(kind);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: facetedDecoration(
            cut: 8,
            color: color.withValues(alpha: 0.1),
            borderColor: color.withValues(alpha: 0.42),
          ),
          child: Row(
            children: [
              FacetMedallion(
                size: 42,
                accent: color,
                child: Icon(sparkSupportIcon(kind), size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Type.body.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Palette.textHi,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: Type.body.copyWith(
                        fontSize: 11.5,
                        height: 1.35,
                        color: Palette.textLo,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.send_outlined, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
