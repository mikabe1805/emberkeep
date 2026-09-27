import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/goal_catalog.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/quest_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    final fraunces = FontLoader('Fraunces')
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-Bold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-SemiBold.ttf'))
      ..addFont(
        rootBundle.load('assets/google_fonts/Fraunces-SemiBoldItalic.ttf'),
      );
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Regular.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Medium.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Italic.ttf'));
    final mono = FontLoader('JetBrainsMono')
      ..addFont(
        rootBundle.load('assets/google_fonts/JetBrainsMono-SemiBold.ttf'),
      )
      ..addFont(rootBundle.load('assets/google_fonts/JetBrainsMono-Bold.ttf'));
    await Future.wait([
      icons.load(),
      fraunces.load(),
      inter.load(),
      mono.load(),
    ]);
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    Clock.freeze(DateTime(2026, 9, 18, 14));
    Sfx.instance.soundEnabled = false;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    Clock.reset();
    Sfx.instance.soundEnabled = true;
  });

  testWidgets('an ordinary compact quest completes with one tap', (
    tester,
  ) async {
    var done = false;
    var completions = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              child: StatefulBuilder(
                builder: (context, setCardState) => QuestCard(
                  quest: Quest(
                    title: 'Send a thoughtful message',
                    stat: Stat.soc,
                    difficulty: 2,
                  ),
                  done: done,
                  featured: false,
                  xpPreview: 14,
                  onSelect: () {},
                  onComplete: (_) {
                    completions++;
                    setCardState(() => done = true);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    await tester.tap(find.text('Send a thoughtful message'));
    await tester.pump();

    expect(completions, 1);
    expect(done, isTrue);
  });

  testWidgets('the Quest board shows labelled tools on the live surface', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = GameState()
      ..onboarded = true
      ..reduceMotion = true
      ..streakDays = 6
      ..bestStreak = 11
      ..streakFreezes = 3
      ..lastActiveDay = '2026-09-18'
      ..lastCompletionDay = '2026-09-18';
    final main = Quest(
      title: 'Read ten pages',
      stat: Stat.intl,
      difficulty: 4,
      priority: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: QuestsPage(
            state: state,
            quests: [main],
            onRefresh: () => 0,
            onPersist: () {},
            onAdd: (_) => true,
            onRemove: (_) {},
            onSnapshot: () => 'snapshot',
            onRestore: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('FOCUS'), findsOneWidget);
    expect(find.text('ADD'), findsOneWidget);
    // Tools carry words, not mystery chevrons. The one chevron on the live
    // surface belongs to Today's three, which opens the chooser.
    final chevrons = find.byIcon(Icons.chevron_right_rounded);
    expect(chevrons, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('daily-field-rail')),
        matching: chevrons,
      ),
      findsOneWidget,
    );
  });

  testWidgets('the labelled rail fits a narrow large-text phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final state = GameState()
      ..onboarded = true
      ..reduceMotion = true
      ..streakFreezes = 2
      ..streakDays = 4
      ..lastActiveDay = '2026-09-18'
      ..lastCompletionDay = '2026-09-18';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestsPage(
            state: state,
            quests: [
              Quest(
                title: 'One clear thing',
                stat: Stat.foc,
                difficulty: 2,
                priority: true,
              ),
            ],
            onRefresh: () => 0,
            onPersist: () {},
            onAdd: (_) => true,
            onRemove: (_) {},
            onSnapshot: () => 'snapshot',
            onRestore: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('FOCUS'), findsOneWidget);
    expect(find.text('ADD'), findsOneWidget);
    // Continuity follows the work, in the board footer.
    final streak = find.text('2 READY · 4 DAY STREAK');
    for (
      var step = 0;
      step < 8 && streak.hitTestable().evaluate().isEmpty;
      step++
    ) {
      await tester.drag(
        find.byKey(const ValueKey('quest-board-scroll')),
        const Offset(0, -140),
      );
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(streak.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Reach out offers inclusive relationship starters', () {
    final reachOut = goalCatalog.singleWhere(
      (goal) => goal.title == 'Reach out',
    );

    expect(
      reachOut.quests.map((quest) => quest.title),
      containsAll(['Send a thoughtful message', 'Do one thoughtful thing']),
    );
    final thoughtful = reachOut.quests.singleWhere(
      (quest) => quest.title == 'Do one thoughtful thing',
    );
    expect(thoughtful.stat, Stat.soc);
    expect(thoughtful.schedule, QuestSchedule.weekly);
    expect(thoughtful.ladderHint, contains('DINNER'));
  });
}
