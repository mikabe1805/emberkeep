import 'dart:math' as math;
import 'dart:io';

import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('semantic secondary ink clears the warm-surface contrast floor', () {
    const workshopSurface = Color(0xFF3B281B);

    expect(
      _contrastRatio(Palette.textLo, workshopSurface),
      greaterThanOrEqualTo(5.5),
    );
    expect(
      _contrastRatio(Palette.textLo, Palette.card),
      greaterThanOrEqualTo(5.5),
    );
  });

  test('secondary ink stays distinct from body ink and quiet ink', () {
    expect(Palette.textLo, isNot(Palette.textMid));
    expect(Palette.textLo, isNot(Palette.textQuiet));
    expect(
      _relativeLuminance(Palette.textLo),
      lessThan(_relativeLuminance(Palette.textMid)),
    );
    expect(
      _relativeLuminance(Palette.textQuiet),
      lessThan(_relativeLuminance(Palette.textLo)),
    );
  });

  test('meaningful caps labels retain the mobile readability floor', () {
    expect(Type.minLabel, greaterThanOrEqualTo(11));
    expect(Type.label.fontSize, greaterThanOrEqualTo(Type.minLabel));
    expect(Type.label.color, Palette.textLo);
  });

  test('owner-flagged Goals and Workshop surfaces keep the readable floor', () {
    const paths = [
      'lib/screens/goals.dart',
      'lib/screens/quests.dart',
      'lib/screens/goal_opening.dart',
      'lib/screens/goal_workshop.dart',
      'lib/widgets/goal_route_panel.dart',
      'lib/widgets/goal_threshold_scene.dart',
    ];
    final numericSize = RegExp(r'fontSize:\s*(\d+(?:\.\d+)?)');

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      for (final match in numericSize.allMatches(source)) {
        final size = double.parse(match.group(1)!);
        expect(
          size,
          greaterThanOrEqualTo(Type.minLabel),
          reason: '$path contains a live numeric font size below 11sp',
        );
      }
      expect(
        source,
        isNot(contains('maxScaleFactor')),
        reason: '$path must let meaningful phone copy follow text scaling',
      );
      expect(
        source,
        isNot(contains('Palette.textQuiet')),
        reason: '$path carries state and actions, not decorative-only copy',
      );
    }
  });
}

double _contrastRatio(Color first, Color second) {
  final lighter = _relativeLuminance(first);
  final darker = _relativeLuminance(second);
  final high = lighter > darker ? lighter : darker;
  final low = lighter > darker ? darker : lighter;
  return (high + 0.05) / (low + 0.05);
}

double _relativeLuminance(Color color) {
  double linearize(int channel) {
    final normalized = channel / 255;
    return normalized <= 0.04045
        ? normalized / 12.92
        : math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
  }

  final argb = color.toARGB32();
  return (0.2126 * linearize((argb >> 16) & 0xff)) +
      (0.7152 * linearize((argb >> 8) & 0xff)) +
      (0.0722 * linearize(argb & 0xff));
}
