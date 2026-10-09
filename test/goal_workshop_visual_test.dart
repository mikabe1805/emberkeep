import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/goal_planner.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/goal_workshop.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/goal_steward.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const _capture = bool.fromEnvironment('CAPTURE_GOLDENS');

Goal _plannedGoal(String title, Stat stat, String action) {
  final plan = GoalPlanner.fromActions(
    title: title,
    stat: stat,
    type: GoalRouteType.finish,
    actions: [action],
    now: Clock.now(),
    outcome: '$title has visible proof',
    successProof: 'One useful result exists',
    obstacleCue: 'the whole thing feels too large',
    fallbackAction: 'Set out the materials',
  );
  return Goal(title: title, stat: stat, target: 3, plan: plan);
}

Future<void> _mount(
  WidgetTester tester, {
  required GameState state,
  required List<Quest> quests,
  required Size size,
  double textScale = 1,
  String? initialGoalTitle,
}) async {
  tester.view.devicePixelRatio = 1;
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Palette.xp,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: size,
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: GoalWorkshopScreen(
        state: state,
        quests: quests,
        initialGoalTitle: initialGoalTitle,
        onOpenGoal: (_) async {},
        onShapePlan: (_, _) async {},
        onCreateGoal: (_) async {},
        onFocusGoal: (_) {},
      ),
    ),
  );
  final workshopContext = tester.element(find.byType(GoalWorkshopScreen));
  await tester.runAsync(() async {
    for (final asset in [
      ...goalStewardAssets,
      goalsWorkshopStewardFallbackAsset,
    ]) {
      await precacheImage(AssetImage(asset), workshopContext);
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    final fraunces = FontLoader('Fraunces')
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-Bold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-SemiBold.ttf'));
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Regular.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Medium.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-SemiBold.ttf'));
    final mono = FontLoader('JetBrainsMono')
      ..addFont(
        rootBundle.load('assets/google_fonts/JetBrainsMono-SemiBold.ttf'),
      );
    final garamond = FontLoader('EBGaramond')
      ..addFont(rootBundle.load('assets/google_fonts/EBGaramond-Variable.ttf'));
    await Future.wait([
      material.load(),
      fraunces.load(),
      inter.load(),
      mono.load(),
      garamond.load(),
    ]);
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Workshop register visual states remain readable', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 9, 6, 10));
    addTearDown(() {
      Clock.reset();
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    final state = GameState()..reduceMotion = true;
    final selected = _plannedGoal(
      'Read books that stay with me',
      Stat.intl,
      'Read ten pages and keep one line',
    );
    final owned = _plannedGoal(
      'Make the apartment feel calm',
      Stat.dis,
      'Clear one useful stretch of the counter',
    );
    state.goals.addAll([
      selected,
      owned,
      Goal(title: 'Build a walking habit', stat: Stat.vit, target: 3),
    ]);
    final decision = GoalPlanner.decide(owned, const <Quest>[], Clock.now())!;
    final quests = [GoalPlanner.questFor(owned, decision, Clock.now())];

    await _mount(
      tester,
      state: state,
      quests: quests,
      size: const Size(430, 932),
      initialGoalTitle: selected.title,
    );
    // The goal that most needs the Steward (no plan yet) leads, with the one
    // thing to do about it; the other two are listed below it.
    expect(
      find.descendant(
        of: find.byKey(const Key('goal-workshop-lead')),
        matching: find.text('Build a walking habit'),
      ),
      findsOneWidget,
    );
    expect(find.text('NEEDS A PLAN'), findsOneWidget);
    expect(find.text('Shape a plan'), findsOneWidget);
    expect(find.text('NEXT STEP READY'), findsOneWidget);
    expect(find.text('ON YOUR BOARD'), findsOneWidget);
    expect(find.text('STEP 1 OF 1'), findsNWidgets(2));
    expect(find.textContaining('route'), findsNothing);
    expect(find.textContaining('marker'), findsNothing);
    expect(find.textContaining('bench'), findsNothing);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goal_workshop_mixed_430x932.png'),
      );
    }

    await _mount(
      tester,
      state: state,
      quests: quests,
      size: const Size(320, 568),
      textScale: 1.5,
      initialGoalTitle: selected.title,
    );
    // Nothing is capped: the whole screen scrolls, so the last goal and the
    // footer are both reachable even at large text on a small phone.
    await tester.scrollUntilVisible(
      find.byKey(
        const ValueKey<String>(
          'goal-workshop-home-goal-Make the apartment feel calm',
        ),
      ),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goal_workshop_mixed_320x568_1_5x.png'),
      );
    }
    await tester.scrollUntilVisible(
      find.byKey(const Key('steward-hidden-card')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('steward-hidden-card')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('goal-workshop-home-new-goal')).hitTestable(),
      findsOneWidget,
    );

    await _mount(
      tester,
      state: GameState()..reduceMotion = true,
      quests: const [],
      size: const Size(320, 568),
      textScale: 1.5,
    );
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goal_workshop_empty_top_320x568_1_5x.png'),
      );
    }
    await tester.scrollUntilVisible(
      find.text('Start your first goal'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Start your first goal'), findsOneWidget);
    expect(find.text('Start a goal'), findsOneWidget);
    expect(
      find.byKey(const Key('steward-hidden-card')).hitTestable(),
      findsOneWidget,
    );
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goal_workshop_empty_320x568_1_5x.png'),
      );
    }
    expect(tester.takeException(), isNull);
  });
}
