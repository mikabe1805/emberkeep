import 'package:emberkeep/widgets/house/plans/plans_page_turn.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(String key, double order, {bool? reduce = false}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: SizedBox(
          width: 300,
          height: 400,
          child: PlansPageTurn(
            turnKey: key,
            order: order,
            reduceMotion: reduce,
            curl: const Rect.fromLTWH(0, 0, 300, 400),
            child: SizedBox.expand(child: Text('page $key')),
          ),
        ),
      ),
    );

double _opacityOf(WidgetTester tester, String text) {
  final finder = find.ancestor(
    of: find.text(text),
    matching: find.byType(Opacity),
  );
  return tester.widget<Opacity>(finder.first).opacity;
}

void main() {
  test(
    'the old page lets go before the new one comes up: bare paper between',
    () {
      expect(plansTurnOut(0), 1);
      expect(plansTurnOut(1), 0);
      expect(plansTurnIn(0), 0);
      expect(plansTurnIn(1), 1);
      // Half way there is nothing on the paper, and at no moment are both
      // pages substantially there.
      expect(plansTurnOut(0.5), 0);
      expect(plansTurnIn(0.5), 0);
      for (var i = 0; i <= 100; i++) {
        final u = i / 100;
        expect(plansTurnOut(u) + plansTurnIn(u), lessThanOrEqualTo(1.0));
      }
    },
  );

  test('the curl is strongest mid-turn and absent at the ends', () {
    expect(plansCurlStrength(0), closeTo(0, 1e-9));
    expect(plansCurlStrength(1), closeTo(0, 1e-9));
    expect(plansCurlStrength(0.5), greaterThan(0.9));
  });

  test('the curl runs right to left going forward and back going back', () {
    expect(plansCurlLeft(0, forward: true), 240);
    expect(plansCurlLeft(1, forward: true), -92);
    expect(plansCurlLeft(0, forward: false), -92);
    expect(plansCurlLeft(1, forward: false), 240);
  });

  testWidgets(
    'a new key turns: the old page fades out, the new comes in, a curl sweeps',
    (tester) async {
      await tester.pumpWidget(_host('a', 0));
      expect(find.text('page a'), findsOneWidget);
      expect(find.byType(CustomPaint), findsNothing);

      await tester.pumpWidget(_host('b', 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Both pages are mounted during the turn, with the curl over them.
      expect(find.text('page a'), findsOneWidget);
      expect(find.text('page b'), findsOneWidget);
      expect(find.byType(PlansCurlPainter.new.runtimeType), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is PlansCurlPainter,
        ),
        findsOneWidget,
      );
      expect(_opacityOf(tester, 'page a'), greaterThan(0.5));
      expect(_opacityOf(tester, 'page b'), 0);

      await tester.pump(const Duration(milliseconds: 280));
      expect(_opacityOf(tester, 'page a'), lessThan(0.2));
      expect(_opacityOf(tester, 'page b'), lessThan(0.5));

      await tester.pump(plansTurnDuration);
      await tester.pump();
      expect(find.text('page a'), findsNothing);
      expect(find.text('page b'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is PlansCurlPainter,
        ),
        findsNothing,
      );
    },
  );

  testWidgets('Reduce Motion turns the page as a plain cross-fade', (
    tester,
  ) async {
    await tester.pumpWidget(_host('a', 0, reduce: true));
    await tester.pumpWidget(_host('b', 1, reduce: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PlansCurlPainter,
      ),
      findsNothing,
    );
    // Half way through the 200 ms the two are the two halves of one fade.
    expect(
      _opacityOf(tester, 'page a') + _opacityOf(tester, 'page b'),
      closeTo(1, 0.01),
    );
    await tester.pump(plansTurnReducedDuration);
    await tester.pump();
    expect(find.text('page a'), findsNothing);
  });
}
