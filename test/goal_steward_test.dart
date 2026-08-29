import 'package:emberkeep/widgets/goal_steward.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every workshop situation resolves to its distinct asset', () {
    const expected = <GoalStewardSituation, GoalStewardExpression>{
      GoalStewardSituation.welcome: GoalStewardExpression.welcome,
      GoalStewardSituation.considering: GoalStewardExpression.considering,
      GoalStewardSituation.cutReady: GoalStewardExpression.ready,
      GoalStewardSituation.questAccepted: GoalStewardExpression.acknowledging,
      GoalStewardSituation.routeComplete: GoalStewardExpression.closing,
    };
    expect(expected.length, 5);
    for (final entry in expected.entries) {
      final expression = resolveGoalStewardExpression(entry.key);
      expect(expression, entry.value);
      expect(goalStewardAsset(expression), contains('steward'));
    }
  });

  test('steward registry contains two room planes and five unique poses', () {
    expect(goalStewardAssets, hasLength(7));
    expect(goalStewardAssets.toSet(), hasLength(7));
    for (final asset in goalStewardAssets) {
      expect(asset, isNotEmpty);
      expect(asset, startsWith('assets/'));
    }
    expect(
      goalStewardAssets,
      containsAll(<String>[
        goalsWorkshopTavernBackAsset,
        goalsWorkshopTavernCounterAsset,
        goalsWorkshopStewardWelcomeAsset,
        goalsWorkshopStewardConsideringAsset,
        goalsWorkshopStewardReadyAsset,
        goalsWorkshopStewardAcknowledgingAsset,
        goalsWorkshopStewardClosingAsset,
      ]),
    );
    expect(goalsWorkshopTavernAsset, goalsWorkshopTavernBackAsset);
    expect(
      goalStewardAssets,
      isNot(contains(goalsWorkshopStewardFallbackAsset)),
    );
  });

  testWidgets('every live steward plane and its fallback actually decodes', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.expand()));
    final context = tester.element(find.byType(SizedBox));
    final failures = <String>[];

    await tester.runAsync(() async {
      for (final asset in <String>[
        ...goalStewardAssets,
        goalsWorkshopStewardFallbackAsset,
      ]) {
        await precacheImage(
          AssetImage(asset),
          context,
          onError: (_, _) => failures.add(asset),
        );
      }
    });
    await tester.pump();

    expect(failures, isEmpty);
    expect(tester.takeException(), isNull);
  });

  test('register foregrounds the most immediate real workshop state', () {
    expect(
      resolveGoalStewardRegisterExpression(
        hasCutWaiting: false,
        hasRouteToShape: false,
        hasQuestOnBoard: false,
        hasCompletedRoute: false,
      ),
      GoalStewardExpression.welcome,
    );
    expect(
      resolveGoalStewardRegisterExpression(
        hasCutWaiting: false,
        hasRouteToShape: false,
        hasQuestOnBoard: false,
        hasCompletedRoute: true,
      ),
      GoalStewardExpression.closing,
    );
    expect(
      resolveGoalStewardRegisterExpression(
        hasCutWaiting: false,
        hasRouteToShape: false,
        hasQuestOnBoard: true,
        hasCompletedRoute: true,
      ),
      GoalStewardExpression.acknowledging,
    );
    expect(
      resolveGoalStewardRegisterExpression(
        hasCutWaiting: false,
        hasRouteToShape: true,
        hasQuestOnBoard: true,
        hasCompletedRoute: true,
      ),
      GoalStewardExpression.considering,
    );
    expect(
      resolveGoalStewardRegisterExpression(
        hasCutWaiting: true,
        hasRouteToShape: true,
        hasQuestOnBoard: true,
        hasCompletedRoute: true,
      ),
      GoalStewardExpression.ready,
    );
  });

  testWidgets(
    'artwork selects the keyed expression image and one semantics label',
    (tester) async {
      const expression = GoalStewardExpression.acknowledging;
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 300,
            height: 240,
            child: GoalStewardArtwork(
              expression: expression,
              reduceMotion: true,
            ),
          ),
        ),
      );
      await tester.pump();

      final image = tester.widget<Image>(
        find.byKey(const ValueKey('goal-steward-expression-acknowledging')),
      );
      expect(
        (image.image as AssetImage).assetName,
        goalsWorkshopStewardAcknowledgingAsset,
      );
      final background = tester.widget<Image>(
        find.byKey(const Key('goal-workshop-steward-background')),
      );
      expect(
        (background.image as AssetImage).assetName,
        goalsWorkshopTavernBackAsset,
      );
      final counter = tester.widget<Image>(
        find.byKey(const Key('goal-workshop-steward-counter')),
      );
      expect(
        (counter.image as AssetImage).assetName,
        goalsWorkshopTavernCounterAsset,
      );
      final label = goalStewardSemanticLabel(expression);
      expect(find.bySemanticsLabel(label), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('steward')), findsOneWidget);
      expect(find.byKey(const Key('goal-workshop-steward')), findsOneWidget);
    },
  );

  test('only relevant poses describe a route card', () {
    expect(
      goalStewardSemanticLabel(GoalStewardExpression.welcome),
      isNot(contains('card')),
    );
    expect(
      goalStewardSemanticLabel(GoalStewardExpression.acknowledging),
      isNot(contains('card')),
    );
    expect(
      goalStewardSemanticLabel(GoalStewardExpression.considering),
      contains('card'),
    );
    expect(
      goalStewardSemanticLabel(GoalStewardExpression.ready),
      contains('card'),
    );
    expect(
      goalStewardSemanticLabel(GoalStewardExpression.closing),
      contains('card'),
    );
  });

  testWidgets('separated planes carry restrained depth and Reduced Motion', (
    tester,
  ) async {
    final parallax = ValueNotifier<Offset>(Offset.zero);
    addTearDown(parallax.dispose);

    Widget artwork({required bool reduceMotion}) => MaterialApp(
      home: SizedBox(
        width: 430,
        height: 932,
        child: GoalStewardArtwork(
          expression: GoalStewardExpression.ready,
          reduceMotion: reduceMotion,
          parallax: parallax,
        ),
      ),
    );

    await tester.pumpWidget(artwork(reduceMotion: false));
    await tester.pump();
    final background = find.byKey(
      const Key('goal-workshop-steward-background'),
    );
    final counter = find.byKey(const Key('goal-workshop-steward-counter'));
    final backgroundRest = tester.getTopLeft(background);
    final counterRest = tester.getTopLeft(counter);

    parallax.value = const Offset(1, 1);
    await tester.pump();
    final backgroundMoved = tester.getTopLeft(background);
    final counterMoved = tester.getTopLeft(counter);
    expect(backgroundMoved.dx - backgroundRest.dx, closeTo(1.35, 0.02));
    expect(counterMoved.dx - counterRest.dx, closeTo(4, 0.02));
    expect(counterMoved.dy - counterRest.dy, closeTo(2.5, 0.02));

    await tester.pumpWidget(artwork(reduceMotion: true));
    await tester.pump();
    expect(tester.getTopLeft(background), backgroundRest);
    expect(tester.getTopLeft(counter), counterRest);
  });
}
