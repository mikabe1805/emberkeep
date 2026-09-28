import 'package:emberkeep/audio.dart';
import 'package:emberkeep/content/achievements.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/haptics.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/achievement_toast.dart';
import 'package:emberkeep/widgets/epic_overlay.dart';
import 'package:emberkeep/widgets/levelup_overlay.dart';
import 'package:emberkeep/widgets/particles.dart';
import 'package:emberkeep/widgets/reward_receipt.dart';
import 'package:emberkeep/widgets/streak_milestone_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    final display = FontLoader('Fraunces')
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-Bold.ttf'));
    final body = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Regular.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Medium.ttf'));
    final numerals = FontLoader('JetBrainsMono')
      ..addFont(rootBundle.load('assets/google_fonts/JetBrainsMono-Bold.ttf'));
    await Future.wait([
      icons.load(),
      display.load(),
      body.load(),
      numerals.load(),
    ]);
  });

  setUp(() {
    Sfx.instance.soundEnabled = false;
    Haptics.reduceMotion = false;
  });

  tearDown(() {
    Sfx.instance.soundEnabled = true;
    Haptics.reduceMotion = false;
  });

  testWidgets(
    'OS Reduce Motion softens native haptic sequences without an app toggle',
    (tester) async {
      final haptics = <MethodCall>[];
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
          return null;
        },
      );
      addTearDown(() {
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      Haptics.rise();
      await tester.pump(const Duration(milliseconds: 250));
      expect(haptics.map((call) => call.arguments), [
        'HapticFeedbackType.lightImpact',
      ]);
    },
  );

  testWidgets(
    'in-app Reduce Motion presents the complete reward receipt immediately',
    (tester) async {
      final state = GameState()..reduceMotion = true;
      var done = false;

      await tester.pumpWidget(
        _rewardHost(
          RewardReceipt(
            state: state,
            bundle: RewardBundle(
              xp: 24,
              embers: 3,
              stat: Stat.intl,
              statGain: 2,
              questTitle: 'Read ten pages',
              message: 'You made returning easier.',
              difficulty: 3,
              verifiedMult: 1.2,
              critMult: 2,
              firstOfDay: true,
            ),
            anchor: const Offset(180, 300),
            onDone: () => done = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('+24 XP'), findsOneWidget);
      expect(find.textContaining('FIRST WIN TODAY'), findsOneWidget);
      expect(find.textContaining('VERIFIED'), findsOneWidget);
      expect(find.textContaining('CRITICAL'), findsOneWidget);
      expect(find.text('You made returning easier.'), findsOneWidget);
      expect(
        done,
        isFalse,
        reason: 'the readable receipt must not vanish early',
      );

      final receiptTransform = find.ancestor(
        of: find.textContaining('+24 XP'),
        matching: find.byType(Transform),
      );
      expect(
        receiptTransform,
        findsNothing,
        reason: 'the reduced receipt must not translate into place',
      );
    },
  );

  testWidgets('a long Quest rise fits the receipt on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _rewardHost(
        RewardReceipt(
          state: GameState()..reduceMotion = true,
          bundle: RewardBundle(
            xp: 15,
            stat: Stat.vit,
            statGain: 1,
            questTitle: 'Reset the counter for 15 minutes',
            message: 'One visible change is proof.',
            difficulty: 2,
            risenToTitle: 'Reset the counter for 15 minutes until one usable patch is visible',
          ),
          anchor: const Offset(160, 280),
          onDone: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('QUEST ROSE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'OS Reduce Motion parks achievement toast and keeps its live announcement',
    (tester) async {
      var done = false;
      final achievement = Achievement(
        id: 'test-achievement',
        title: 'First Step',
        desc: 'Complete one quest',
        icon: Icons.flag_rounded,
        test: (_) => true,
      );

      await tester.pumpWidget(
        _rewardHost(
          AchievementToast(achievement: achievement, onDone: () => done = true),
          disableAnimations: true,
        ),
      );
      await tester.pump();

      expect(find.text('First Step'), findsOneWidget);
      final announcement = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
      );
      expect(announcement.properties.label, 'Achievement unlocked: First Step');
      expect(
        find.ancestor(
          of: find.text('First Step'),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
      expect(done, isFalse);

      await tester.pump(const Duration(milliseconds: 2600));
      expect(
        done,
        isTrue,
        reason: 'the toast must retain its teardown contract',
      );
    },
  );

  testWidgets(
    'OS Reduce Motion shows the encouraging level-up final state without particles or a slam',
    (tester) async {
      final haptics = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      var dismissed = false;

      await tester.pumpWidget(
        _rewardHost(
          LevelUpOverlay(
            level: 10,
            unlock: 'Sunlit Desk',
            nextUnlock: 'Brass Shelf',
            onDismiss: () => dismissed = true,
          ),
          disableAnimations: true,
        ),
      );
      await tester.pump();

      expect(find.text('LEVEL UP'), findsOneWidget);
      expect(find.text('YOU DID IT.'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('UNLOCKED'), findsOneWidget);
      expect(find.text('Sunlit Desk'), findsOneWidget);
      expect(find.byType(ParticleBurst), findsNothing);
      expect(_scaleOfText(tester, '10'), closeTo(1, 0.0001));
      expect(
        find.bySemanticsLabel('Level 10 reached. Sunlit Desk unlocked'),
        findsOneWidget,
      );
      expect(
        haptics.map((call) => call.arguments),
        contains('HapticFeedbackType.lightImpact'),
      );
      expect(
        haptics.map((call) => call.arguments),
        isNot(contains('HapticFeedbackType.heavyImpact')),
      );

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ParticleBurst), findsNothing);
      await tester.tapAt(const Offset(20, 20));
      expect(dismissed, isTrue);
    },
  );

  testWidgets(
    'level-up lands on an encouraging full-screen milestone before it can dismiss',
    (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        _rewardHost(
          LevelUpOverlay(
            level: 5,
            unlock: 'Window Seat',
            onDismiss: () => dismissed = true,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 720));

      expect(find.text('LEVEL UP'), findsOneWidget);
      expect(find.text('YOU DID IT.'), findsOneWidget);
      expect(find.text('LEVEL 5'), findsNothing);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Window Seat'), findsOneWidget);
      expect(find.byType(ParticleBurst), findsOneWidget);
      expect(dismissed, isFalse);

      await tester.tapAt(const Offset(20, 20));
      expect(dismissed, isTrue);
    },
  );

  testWidgets('level-up still frame fills a phone with the encouragement', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _rewardHost(
        LevelUpOverlay(
          level: 10,
          unlock: 'Sunlit Desk',
          nextUnlock: 'Brass Shelf',
          questsSince: 12,
          previousLevel: 9,
          onDismiss: () {},
          onShare: () {},
          reduceMotion: true,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('YOU DID IT.'), findsOneWidget);
    expect(find.text('12 quests since level 9'), findsOneWidget);
    // One numeral carries the level; the old small LEVEL 10 caption repeated it.
    expect(find.text('LEVEL 10'), findsNothing);
    if (const bool.fromEnvironment('CAPTURE_GOLDENS')) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/levelup_you_did_it_390x844.png'),
      );
    }
  });

  testWidgets(
    'level-up keeps its encouragement and exit doors on a narrow large-text phone',
    (tester) async {
      var shared = false;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await tester.pumpWidget(
        _rewardHost(
          LevelUpOverlay(
            level: 10,
            unlock: 'Sunlit Desk',
            nextUnlock: 'Brass Shelf',
            onDismiss: () {},
            onShare: () => shared = true,
            reduceMotion: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('YOU DID IT.'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('UNLOCKED'), findsOneWidget);
      expect(find.text('Sunlit Desk'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('SHARE THIS MOMENT'),
        180,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('SHARE THIS MOMENT'), findsOneWidget);
      expect(find.text('onward →'), findsOneWidget);
      await tester.tap(find.text('SHARE THIS MOMENT'));
      expect(shared, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'OS Reduce Motion opens streak chest at rest with payout and dismiss action',
    (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        _rewardHost(
          StreakMilestoneOverlay(
            days: 7,
            embers: 12,
            onDismiss: () => dismissed = true,
          ),
          disableAnimations: true,
        ),
      );
      await tester.pump();

      expect(find.text('7'), findsOneWidget);
      expect(find.text('A WEEK OF FIRE'), findsOneWidget);
      expect(find.text('+12 Glimmers'), findsOneWidget);
      expect(find.byType(ParticleBurst), findsNothing);
      expect(_scaleOfText(tester, '7'), closeTo(1, 0.0001));
      expect(
        find.bySemanticsLabel(
          '7 day streak. A WEEK OF FIRE. 12 Glimmers earned.',
        ),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byType(ParticleBurst), findsNothing);
      await tester.tapAt(const Offset(20, 20));
      expect(dismissed, isTrue);
    },
  );

  testWidgets(
    'OS Reduce Motion presents epic reward details without burst or travel',
    (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        _rewardHost(
          EpicOverlay(
            questTitle: 'Finish the hard draft',
            message: 'You stayed with it.',
            onDismiss: () => dismissed = true,
          ),
          disableAnimations: true,
        ),
      );
      await tester.pump();

      expect(find.text('EPIC QUEST CLEARED'), findsOneWidget);
      expect(find.text('YOU DID IT.'), findsOneWidget);
      expect(find.text('Finish the hard draft'), findsOneWidget);
      expect(find.text('You stayed with it.'), findsOneWidget);
      expect(find.byType(ParticleBurst), findsNothing);
      expect(_scaleOfText(tester, 'YOU DID IT.'), closeTo(1, 0.0001));
      expect(
        find.bySemanticsLabel(
          'EPIC QUEST CLEARED. YOU DID IT. Finish the hard draft',
        ),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ParticleBurst), findsNothing);
      await tester.tapAt(const Offset(20, 20));
      expect(dismissed, isTrue);
    },
  );
}

Widget _rewardHost(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (context, appChild) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: disableAnimations),
      child: appChild!,
    ),
    home: Scaffold(
      body: Stack(fit: StackFit.expand, children: [child]),
    ),
  );
}

double _scaleOfText(WidgetTester tester, String text) {
  final transform = tester.widget<Transform>(
    find.ancestor(of: find.text(text), matching: find.byType(Transform)).first,
  );
  return transform.transform.getMaxScaleOnAxis();
}
