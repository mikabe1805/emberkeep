import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('warm background has no hard ambient planes', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: RepaintBoundary(
          child: WarmBackground(
            themeId: 'walnut',
            tint: Palette.streak,
            reduceMotion: true,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(WarmBackground),
      matchesGoldenFile('goldens/warm_background_no_planes_430x932.png'),
    );
  });
}
