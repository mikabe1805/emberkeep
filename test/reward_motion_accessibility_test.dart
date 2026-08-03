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
  setUp(() {
    Sfx.instance.soundEnabled = false;
    Haptics.reduceMotion = false;
  });

  tearDown(() {
    Sfx.instance.soundEnabled = true;
    Haptics.reduceMotion = false;
  });

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
    'OS Reduce Motion shows level-up final state without particles or a slam',
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
      expect(find.text('10'), findsOneWidget);
      expect(find.text('Sunlit Desk UNLOCKED'), findsOneWidget);
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
