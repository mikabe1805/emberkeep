// One-off read-only visual capture for the September 27 discoverability review.
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/goals.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    final fraunces = FontLoader('Fraunces')
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-Bold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-SemiBold.ttf'));
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Regular.ttf'))
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
  });

  testWidgets('capture current Goals and featured Quest discoverability', (
    tester,
  ) async {
    // This design-capture test lives with its images instead of under test/.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    Clock.freeze(DateTime(2026, 9, 27, 10));
    addTearDown(Clock.reset);
    final state = GameState()
      ..onboarded = true
      ..reduceMotion = true
      ..soundEnabled = false;
    final goal = Goal(
      title: 'Make the apartment feel calm',
      stat: Stat.dis,
      target: 25,
      progress: 11,
      openingSeen: true,
    );
    state.goals.add(goal);
    final quests = <Quest>[
      Quest(
        title: 'Clear the kitchen counter',
        stat: Stat.dis,
        difficulty: 2,
        goalTitle: goal.title,
      ),
    ];

    Widget goals({required double scale}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Palette.parchment,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Palette.xp,
          brightness: Brightness.dark,
        ),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Inter'),
        useMaterial3: true,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: GoalsPage(
          state: state,
          quests: quests,
          onAdd: (quest) {
            quests.add(quest);
            return true;
          },
          onRemoveQuest: (_) {},
          onRemoveGoal: (_) {},
          onPersist: () {},
          onOpenQuest: (_) {},
        ),
      ),
    );

    Widget board({required double scale}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Palette.parchment,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Palette.xp,
          brightness: Brightness.dark,
        ),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Inter'),
        useMaterial3: true,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        backgroundColor: Palette.parchment,
        body: WarmBackground(
          themeId: state.canvasTheme,
          tint: Palette.streak,
          reduceMotion: true,
          child: QuestsPage(
            state: state,
            quests: quests,
            onRefresh: () => 0,
            onPersist: () {},
            onAdd: (quest) {
              quests.add(quest);
              return true;
            },
            onRemove: quests.remove,
            onSnapshot: () => '{}',
            onRestore: (_) {},
            onOpenRoomGuide: () {},
          ),
        ),
      ),
    );

    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(goals(scale: 1));
    final goalsContext = tester.element(find.byType(MaterialApp));
    await tester.runAsync(() async {
      for (final asset in <String>[
        'assets/pages/goals-living-backdrop-v2.webp',
        'assets/pages/goals-room-kitchen-v1.webp',
        'assets/pages/working-room-v1.webp',
        'assets/room/wall_grain.png',
      ]) {
        await precacheImage(AssetImage(asset), goalsContext);
      }
    });
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goals_normal_430x932.png'),
    );

    await tester.binding.setSurfaceSize(const Size(320, 568));
    await tester.pumpWidget(goals(scale: 1.5));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goals_large_text_320x568.png'),
    );

    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(board(scale: 1));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('quests_featured_normal_430x932.png'),
    );

    await tester.binding.setSurfaceSize(const Size(320, 568));
    await tester.pumpWidget(board(scale: 1.5));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('quests_featured_large_text_320x568.png'),
    );
  });
}
