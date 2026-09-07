import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/stat_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const values = <Stat, int>{
    Stat.str: 7,
    Stat.vit: 11,
    Stat.intl: 19,
    Stat.foc: 27,
    Stat.soc: 35,
    Stat.dis: 43,
  };

  Widget host({
    required ValueChanged<Stat> onSelect,
    required double textScale,
  }) => MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: StatChips(
              values: values,
              reduceMotion: true,
              onSelect: onSelect,
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> verifyTargets(
    WidgetTester tester, {
    required Size size,
    required double textScale,
  }) async {
    final selected = <Stat>[];
    final semantics = tester.ensureSemantics();
    try {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        host(onSelect: selected.add, textScale: textScale),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      for (final stat in Stat.values) {
        final finder = find.bySemanticsLabel(
          'Explore ${stat.label}, ${values[stat]} points',
        );
        expect(finder, findsOneWidget);
        final node = tester.getSemantics(finder);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        expect(node.rect.width, greaterThanOrEqualTo(44));
        expect(node.rect.height, greaterThanOrEqualTo(44));
        node.owner!.performAction(node.id, SemanticsAction.tap);
        await tester.pump();
      }
      expect(selected, Stat.values);
      selected.clear();
      for (final stat in Stat.values) {
        await tester.tap(find.text(stat.abbr));
        await tester.pump();
      }
      expect(selected, Stat.values);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  }

  testWidgets('393pt iPhone width keeps six labeled 44pt domain actions', (
    tester,
  ) async {
    await verifyTargets(tester, size: const Size(393, 852), textScale: 1);
  });

  testWidgets('320pt at 2x text reflows to accessible domain actions', (
    tester,
  ) async {
    await verifyTargets(tester, size: const Size(320, 568), textScale: 2);
  });
}
