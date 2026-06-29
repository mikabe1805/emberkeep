import 'package:flutter/material.dart';

import '../tokens.dart';

/// One header for every "zoomed-in character sheet" (a goal's detail, a
/// domain's base) so they read as one family rather than three different apps
/// (round-27). Back chevron · optional Hero medallion · accent title (+ optional
/// subtitle) · optional right-side pill.
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.title,
    required this.accent,
    this.subtitle,
    this.pill,
    this.heroTag,
  });

  final String title;
  final Color accent;
  final String? subtitle;

  /// A short right-side chip (e.g. a goal's kind or a domain's rank).
  final String? pill;

  /// When set, a small colour medallion leads the title and shares this tag
  /// with its source (a Me stat dot) so it flies in on push.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final medallion = Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent,
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 8),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.chevron_left, size: 26, color: Palette.textMid),
            ),
          ),
          if (heroTag != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 9, right: 10),
              child: Hero(tag: heroTag!, child: medallion),
            ),
          ] else
            const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Type.display.copyWith(fontSize: 24, color: accent),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Type.body.copyWith(
                      fontSize: 12,
                      color: Palette.textLo,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (pill != null) ...[
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: accent.withValues(alpha: 0.16),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                ),
                child: Text(
                  pill!,
                  style: Type.label.copyWith(fontSize: 11, color: accent),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
