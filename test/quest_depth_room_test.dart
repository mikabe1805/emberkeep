import 'package:emberkeep/widgets/quest_depth_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Quest room uses four registered planes and living fire', (
    tester,
  ) async {
    final parallax = ValueNotifier(Offset.zero);
    final scroll = ValueNotifier(0.0);
    addTearDown(parallax.dispose);
    addTearDown(scroll.dispose);

    Widget room({required bool lively}) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: 430,
          height: 253,
          child: QuestDepthRoom(
            parallax: parallax,
            scrollPosition: scroll,
            flameHue: const Color(0xFFE8915A),
            lively: lively,
          ),
        ),
      ),
    );

    await tester.pumpWidget(room(lively: true));
    await tester.pump(const Duration(milliseconds: 300));

    final visibleImages = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(visibleImages, hasLength(6));
    final visibleAssets = visibleImages
        .map((image) => (image.image as AssetImage).assetName)
        .toSet();
    expect(
      visibleAssets,
      containsAll(<String>[
        QuestDepthRoom.baseAsset,
        QuestDepthRoom.wallAsset,
        QuestDepthRoom.furnitureAsset,
        QuestDepthRoom.foregroundAsset,
      ]),
    );
    expect(
      visibleAssets.intersection(QuestDepthRoom.fireAssets.toSet()),
      hasLength(2),
    );

    parallax.value = const Offset(0.6, -0.4);
    await tester.pump();
    double xTravel(String key) {
      final transform = tester.widget<Transform>(find.byKey(ValueKey(key)));
      return transform.transform.getTranslation().x.abs();
    }

    expect(
      xTravel('quest-depth-far-plane'),
      lessThan(xTravel('quest-depth-wall-plane')),
    );
    expect(
      xTravel('quest-depth-wall-plane'),
      lessThan(xTravel('quest-depth-furniture-plane')),
    );
    expect(
      xTravel('quest-depth-furniture-plane'),
      lessThan(xTravel('quest-depth-foreground-plane')),
    );

    final fire = find.byKey(const ValueKey('quest-depth-fire'));
    final firstPainter = tester.widget<CustomPaint>(fire).painter;

    await tester.pump(const Duration(milliseconds: 700));

    final movingPainter = tester.widget<CustomPaint>(fire).painter;
    expect(identical(firstPainter, movingPainter), isFalse);

    await tester.pumpWidget(room(lively: false));
    await tester.pump();
    final parkedPainter = tester.widget<CustomPaint>(fire).painter;

    await tester.pump(const Duration(milliseconds: 700));

    expect(tester.widget<CustomPaint>(fire).painter, same(parkedPainter));
  });
}
