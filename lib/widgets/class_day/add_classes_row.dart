// "Add your classes": one calm row under the Quest hero, on weekdays, for a
// person with no timetable yet (ported from concept A, "On the board"). It
// never takes the prime slot, it opens the Plans import sheet, and "Not in
// school" puts it away for good.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../audio.dart' show InteractionSound, MaterialSound;
import '../../tokens.dart';
import '../facets.dart';
import '../pressable.dart';
import '../working_surface.dart' show WorkingType;

class AddClassesRow extends StatelessWidget {
  const AddClassesRow({super.key, required this.onTap, required this.onHide});

  /// Opens the Add your classes sheet in Plans.
  final VoidCallback onTap;

  /// "Not in school": puts the row away for good.
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('add-classes-row'),
    decoration: facetedDecoration(
      cut: 10,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xE8241A15), Color(0xE8171210)],
      ),
      borderColor: const Color(0xFF41372F),
      borderWidth: 0.8,
    ),
    padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
    child: Row(
      children: [
        Expanded(
          child: Pressable(
            key: const Key('add-classes'),
            onTapUp: (_) => onTap(),
            pressDepth: 2,
            material: MaterialSound.parchment,
            interactionSound: InteractionSound.navigate,
            shape: const FacetedBorder(cut: 8),
            edgeColor: Colors.transparent,
            semanticLabel: 'Add your classes',
            semanticHint: 'Opens Plans to bring in your timetable',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
              child: Row(
                children: [
                  const SizedBox.square(
                    dimension: 34,
                    child: CustomPaint(painter: _OpenOrbit()),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Add your classes',
                                style: WorkingType.title.copyWith(fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Palette.textLo.withValues(alpha: 0.85),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Each class you go to earns XP.',
                          style: Type.body.copyWith(
                            fontSize: 13,
                            height: 1.3,
                            color: Palette.textLo,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Not in school. Hide this for good',
          excludeSemantics: true,
          child: TextButton(
            key: const Key('not-in-school'),
            onPressed: onHide,
            style: TextButton.styleFrom(
              foregroundColor: Palette.textLo,
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              'Not in\nschool',
              textAlign: TextAlign.center,
              style: Type.body.copyWith(
                fontSize: 12.5,
                height: 1.15,
                fontStyle: FontStyle.italic,
                color: Palette.textLo,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _OpenOrbit extends CustomPainter {
  const _OpenOrbit();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 1.5;
    const dashes = 18;
    const sweep = 2 * math.pi / dashes;
    final paint = Paint()
      ..color = Palette.brass.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        i * sweep,
        sweep * 0.45,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_OpenOrbit oldDelegate) => false;
}
