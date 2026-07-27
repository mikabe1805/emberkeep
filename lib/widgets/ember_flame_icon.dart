import 'package:flutter/material.dart';

import 'home_room.dart' show paintEmberFlame;

/// The default Emberkeep fire hue, shared by branded flame marks when no
/// player-selected hearth colour is available (for example the crash-safe
/// fallback shown before a save can be read).
const emberFlameDefaultHue = Color(0xFFEC6007);

/// A compact, static Emberkeep flame mark for semantic icon slots.
///
/// The room hearth, HUD, candles and shop previews use the same
/// [paintEmberFlame] primitive. This wrapper keeps small achievements, streak
/// chips, hints and fallback states in that same faceted visual language
/// instead of falling back to a rounded platform fire glyph.
class EmberFlameIcon extends StatelessWidget {
  const EmberFlameIcon({
    super.key,
    this.size = 24,
    this.color = emberFlameDefaultHue,
    this.semanticLabel,
  });

  final double size;
  final Color color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final mark = ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _EmberFlameIconPainter(color)),
      ),
    );
    final label = semanticLabel;
    return label == null
        ? mark
        : Semantics(label: label, image: true, child: mark);
  }
}

/// Routes legacy fire [IconData] through [EmberFlameIcon], while leaving every
/// unrelated Material icon untouched. This lets content models keep their
/// lightweight IconData fields without leaking stock flames into the UI.
Widget emberkeepIcon(
  IconData icon, {
  required double size,
  required Color color,
  Color? flameHue,
  String? semanticLabel,
}) {
  if (isEmberFlameIconData(icon)) {
    return EmberFlameIcon(
      size: size,
      color: flameHue ?? emberFlameDefaultHue,
      semanticLabel: semanticLabel,
    );
  }
  return Icon(icon, size: size, color: color, semanticLabel: semanticLabel);
}

bool isEmberFlameIconData(IconData icon) =>
    icon == Icons.local_fire_department ||
    icon == Icons.local_fire_department_outlined ||
    icon == Icons.whatshot;

class _EmberFlameIconPainter extends CustomPainter {
  const _EmberFlameIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final baseY = h * 0.91;

    // A tiny fuel line gives the mark the same heat logic as the hearth and
    // icon: every pale facet visibly originates from something it is burning.
    canvas.drawLine(
      Offset(w * 0.08, baseY),
      Offset(w * 0.92, baseY),
      Paint()
        ..color = Color.lerp(color, const Color(0xFF3A1812), 0.62)!
        ..strokeWidth = (w * 0.065).clamp(0.8, 2.0)
        ..strokeCap = StrokeCap.square,
    );

    // Side tongues first, broad spear last: the same overlap order used by the
    // room hearth and shop swatches. Normalized geometry keeps it legible from
    // a 13 px streak chip through a 64 px achievement medallion.
    paintEmberFlame(
      canvas,
      Rect.fromLTWH(w * 0.05, h * 0.47, w * 0.30, h * 0.44),
      color,
      lean: -w * 0.015,
    );
    paintEmberFlame(
      canvas,
      Rect.fromLTWH(w * 0.65, h * 0.43, w * 0.30, h * 0.48),
      color,
      lean: w * 0.012,
    );
    paintEmberFlame(
      canvas,
      Rect.fromLTWH(w * 0.25, h * 0.05, w * 0.50, h * 0.86),
      color,
    );
  }

  @override
  bool shouldRepaint(_EmberFlameIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
