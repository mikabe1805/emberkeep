import 'package:emberkeep/widgets/quest_depth_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _captureIgnition = bool.fromEnvironment('CAPTURE_IGNITION');
const _captureKey = ValueKey('quest-ignition-capture');

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_captureIgnition) return;
  await expectLater(
    find.byKey(_captureKey),
    matchesGoldenFile(
      '../design/audits/2026-08-19/next-level-polish/$name.png',
    ),
  );
}

void main() {
  testWidgets('the Quest hearth blooms once and reduce motion lands lit', (
    tester,
  ) async {
    final parallax = ValueNotifier(Offset.zero);
    final scroll = ValueNotifier(0.0);
    addTearDown(parallax.dispose);
    addTearDown(scroll.dispose);
    late void Function(void Function()) redraw;
    var igniting = false;
    var hearthLit = false;
    var reduceMotion = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            redraw = setState;
            return RepaintBoundary(
              key: _captureKey,
              child: SizedBox(
                width: 390,
                height: 300,
                child: QuestDepthRoom(
                  parallax: parallax,
                  scrollPosition: scroll,
                  flameHue: const Color(0xFFEC6007),
                  lively: !reduceMotion,
                  igniting: igniting,
                  hearthLit: hearthLit,
                  reduceMotion: reduceMotion,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    if (_captureIgnition) {
      final context = tester.element(find.byType(QuestDepthRoom));
      await tester.runAsync(() async {
        for (final asset in QuestDepthRoom.assets) {
          await precacheImage(AssetImage(asset), context);
        }
      });
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('quest-fire-ignition')))
          .opacity,
      0,
    );
    await _capture(tester, 'quest-fire-01-off');

    redraw(() {
      hearthLit = true;
      igniting = true;
    });
    await tester.pump();
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('quest-fire-ignition')))
          .opacity,
      lessThan(1),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('quest-fire-ignition')))
          .opacity,
      greaterThan(0),
    );
    await _capture(tester, 'quest-fire-02-igniting');
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('quest-fire-ignition')))
          .opacity,
      1,
    );
    await _capture(tester, 'quest-fire-03-settled');

    redraw(() => igniting = false);
    await tester.pump();
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('quest-fire-ignition')))
          .opacity,
      1,
      reason: 'the finished hearth does not go dark when the transient ends',
    );

    redraw(() {
      igniting = false;
      hearthLit = false;
      reduceMotion = true;
    });
    await tester.pump();
    redraw(() {
      hearthLit = true;
      igniting = true;
    });
    await tester.pump();
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('quest-fire-ignition')))
          .opacity,
      1,
      reason: 'reduced motion opens on the finished, lit room',
    );
  });
}
