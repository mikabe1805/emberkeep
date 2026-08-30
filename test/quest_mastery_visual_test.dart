import 'dart:io';

import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/ladders.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/quest_card.dart';
import 'package:emberkeep/widgets/reward_receipt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/golden_platform_policy.dart';

const _verifyExactGoldens = bool.fromEnvironment('VERIFY_EXACT_GOLDENS');

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
      ..addFont(rootBundle.load('assets/google_fonts/Inter-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Bold.ttf'));
    final mono = FontLoader('JetBrainsMono')
      ..addFont(
        rootBundle.load('assets/google_fonts/JetBrainsMono-SemiBold.ttf'),
      )
      ..addFont(rootBundle.load('assets/google_fonts/JetBrainsMono-Bold.ttf'));
    await Future.wait([
      material.load(),
      fraunces.load(),
      inter.load(),
      mono.load(),
    ]);
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() => Clock.freeze(DateTime(2026, 8, 29, 14)));
  tearDown(Clock.reset);

  testWidgets('a legacy 16/5 save renders repaired and practiced', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Palette.parchment,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 92, 16, 16),
              child: Align(
                alignment: Alignment.topCenter,
                child: QuestCard(
                  quest: Quest.fromJson({
                    'title': 'Walk 10 minutes',
                    'stat': Stat.vit.index,
                    'difficulty': 3,
                    'rising': true,
                    'risingStreak': 16,
                    'ladder': Ladders.walking,
                    'ladderHint': 'CLIMBS AS YOU GROW',
                    'rung': 0,
                  }),
                  done: false,
                  featured: true,
                  reduceMotion: true,
                  xpPreview: 29,
                  onComplete: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('16/5'), findsNothing);
    expect(find.text('0/5'), findsOneWidget);
    expect(find.text('Walk 20 minutes'), findsOneWidget);
    expect(find.text('PRACTICED · 16×'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('16 completions, practiced mastery')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('rise progress 0 of 5')),
      findsOneWidget,
    );
    await runExactGoldenCheck(
      operatingSystem: Platform.operatingSystem,
      explicitlyEnabled: _verifyExactGoldens,
      updatingGoldens: autoUpdateGoldenFiles,
      compare: () => expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/quest_mastery_repaired_16_430x932.png'),
      ),
    );
  });

  testWidgets('mastery brasswork grows across goal domains', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });

    final quests = [
      Quest(
        title: 'Review lecture notes',
        stat: Stat.intl,
        difficulty: 2,
        masteryCompletions: 4,
      ),
      Quest(
        title: 'Clear the kitchen table',
        stat: Stat.dis,
        difficulty: 2,
        masteryCompletions: 5,
      ),
      Quest(
        title: 'Walk around the block',
        stat: Stat.vit,
        difficulty: 2,
        masteryCompletions: 15,
      ),
      Quest(
        title: 'Practice one song',
        stat: Stat.foc,
        difficulty: 2,
        masteryCompletions: 40,
      ),
      Quest(
        title: 'Call Mom',
        stat: Stat.soc,
        difficulty: 2,
        masteryCompletions: 100,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Palette.parchment,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 92, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'QUEST MASTERY',
                    style: Type.display.copyWith(
                      color: Palette.textHi,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'The same history, whatever you are tending.',
                    style: Type.body.copyWith(color: Palette.textMid),
                  ),
                  const SizedBox(height: 20),
                  for (final quest in quests) ...[
                    QuestCard(
                      quest: quest,
                      done: false,
                      reduceMotion: true,
                      xpPreview: 20,
                      onComplete: (_) {},
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await runExactGoldenCheck(
      operatingSystem: Platform.operatingSystem,
      explicitlyEnabled: _verifyExactGoldens,
      updatingGoldens: autoUpdateGoldenFiles,
      compare: () => expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/quest_mastery_cross_domain_430x932.png'),
      ),
    );
  });

  testWidgets('repaired mastery remains readable on a narrow phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    final walk = Quest.fromJson({
      'title': 'Walk 10 minutes',
      'stat': Stat.vit.index,
      'difficulty': 3,
      'rising': true,
      'risingStreak': 16,
      'ladder': Ladders.walking,
      'ladderHint': 'CLIMBS AS YOU GROW',
      'rung': 0,
    });

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(1.3),
            disableAnimations: true,
          ),
          child: Scaffold(
            backgroundColor: Palette.parchment,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 84, 12, 12),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: QuestCard(
                    quest: walk,
                    done: false,
                    featured: true,
                    reduceMotion: true,
                    xpPreview: 29,
                    onComplete: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('PRACTICED · 16×'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await runExactGoldenCheck(
      operatingSystem: Platform.operatingSystem,
      explicitlyEnabled: _verifyExactGoldens,
      updatingGoldens: autoUpdateGoldenFiles,
      compare: () => expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/quest_mastery_repaired_narrow_320x568.png'),
      ),
    );
  });

  testWidgets('threshold receipt names both the rise and earned mastery', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    final bundle = RewardBundle(
      xp: 29,
      stat: Stat.vit,
      statGain: 5,
      questTitle: 'Walk 10 minutes',
      message: 'You kept the promise.',
      difficulty: 3,
      risenToTitle: 'Walk 20 minutes',
      masteryCompletionsAfter: 5,
      masteryTierReached: QuestMasteryTier.kept,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              RewardReceipt(
                bundle: bundle,
                anchor: const Offset(160, 360),
                state: state,
                onDone: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('QUEST ROSE · Walk 20 minutes'), findsOneWidget);
    expect(find.text('KEPT · 5 COMPLETIONS'), findsOneWidget);
  });
}
