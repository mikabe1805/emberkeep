import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:emberkeep/widgets/ember_flame_icon.dart';

void main() {
  test('visible UI cannot bypass the branded flame mark', () {
    final directStockFlame = RegExp(
      r'Icon\s*\(\s*Icons\.(?:local_fire_department(?:_outlined)?|whatshot)',
      multiLine: true,
    );
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      expect(
        directStockFlame.hasMatch(source),
        isFalse,
        reason: '${file.path} directly renders a stock fire glyph',
      );
      expect(
        source.contains('🔥'),
        isFalse,
        reason: '${file.path} renders a platform-dependent flame emoji',
      );
    }
  });

  testWidgets('all legacy fire glyphs render as the Room of Days flame mark', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            emberkeepIcon(
              Icons.local_fire_department,
              size: 24,
              color: Colors.orange,
            ),
            emberkeepIcon(
              Icons.local_fire_department_outlined,
              size: 24,
              color: Colors.orange,
            ),
            emberkeepIcon(Icons.whatshot, size: 24, color: Colors.orange),
            emberkeepIcon(Icons.lock_outline, size: 24, color: Colors.grey),
          ],
        ),
      ),
    );

    expect(find.byType(EmberFlameIcon), findsNWidgets(3));
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the branded mark paints cleanly at every shipped icon size', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            EmberFlameIcon(size: 13),
            EmberFlameIcon(size: 16),
            EmberFlameIcon(size: 20),
            EmberFlameIcon(size: 24),
            EmberFlameIcon(size: 34),
            EmberFlameIcon(size: 64),
          ],
        ),
      ),
    );

    expect(find.byType(EmberFlameIcon), findsNWidgets(6));
    expect(
      find.descendant(
        of: find.byType(EmberFlameIcon),
        matching: find.byType(CustomPaint),
      ),
      findsNWidgets(6),
    );
    expect(tester.takeException(), isNull);
  });
}
