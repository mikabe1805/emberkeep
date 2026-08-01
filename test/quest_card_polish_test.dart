import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/quest_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('only the featured quest ring follows live light', (
    tester,
  ) async {
    final light = ValueNotifier(Offset.zero);
    final scroll = ValueNotifier(0.0);
    addTearDown(light.dispose);
    addTearDown(scroll.dispose);

    Widget card({required bool featured}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 390,
            child: QuestCard(
              quest: Quest(
                title: 'A quiet piece of work',
                stat: Stat.foc,
                difficulty: 3,
              ),
              done: false,
              featured: featured,
              xpPreview: 26,
              lightDirection: light,
              scrollPosition: scroll,
              onComplete: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(card(featured: false));
    await tester.pump();
    final ring = find.byKey(const ValueKey('quest-check-draw'));
    final parked = tester.widget<CustomPaint>(ring).painter;
    light.value = const Offset(0.8, -0.4);
    scroll.value = 180;
    await tester.pump();
    expect(tester.widget<CustomPaint>(ring).painter, same(parked));

    await tester.pumpWidget(card(featured: true));
    await tester.pump();
    final live = tester.widget<CustomPaint>(ring).painter;
    light.value = const Offset(-0.7, 0.3);
    await tester.pump();
    expect(tester.widget<CustomPaint>(ring).painter, isNot(same(live)));
  });

  testWidgets('completion resolves in place before the card banks', (
    tester,
  ) async {
    final done = ValueNotifier(false);
    addTearDown(done.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              child: ValueListenableBuilder<bool>(
                valueListenable: done,
                builder: (context, isDone, _) => QuestCard(
                  key: const ValueKey('settling-quest'),
                  quest: Quest(
                    title: 'Read ten pages',
                    stat: Stat.intl,
                    difficulty: 3,
                    priority: true,
                  ),
                  done: isDone,
                  featured: !isDone,
                  xpPreview: 26,
                  onComplete: (_) => done.value = true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(QuestCard));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('QUEST COMPLETE'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('QUEST COMPLETE'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'long completed names remain readable on a narrow large-text phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      const title = 'Finish the unusually long and detailed visual polish pass';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: QuestCard(
                quest: Quest(title: title, stat: Stat.foc, difficulty: 5),
                done: true,
                featured: false,
                xpPreview: 41,
                onComplete: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(title), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
