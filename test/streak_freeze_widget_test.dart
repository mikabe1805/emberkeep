import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/reward_receipt.dart';
import 'package:emberkeep/widgets/routine_flows.dart';
import 'package:emberkeep/widgets/streak_freeze_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(Clock.reset);

  testWidgets(
    'Quest status opens a readable freeze explanation on a small phone',
    (tester) async {
      Clock.freeze(DateTime(2026, 8, 13, 10));
      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(const Size(320, 568));
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final state = GameState()
        ..streakDays = 6
        ..bestStreak = 11
        ..lastCompletionDay = '2026-08-13'
        ..streakFreezes = 3
        ..streakFreezeProgress = 2;
      state.frozenStreakDays.add('2026-08-11');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 180,
                child: StreakFreezeStatus(state: state),
              ),
            ),
          ),
        ),
      );

      expect(find.text('6 DAY STREAK · 3 FREEZES'), findsOneWidget);
      await tester.tap(find.byType(StreakFreezeStatus));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('STREAK FREEZES'), findsOneWidget);
      expect(find.text('Room for real life'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('AUG 11'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an uncovered return never presents the stale run as current', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 8, 13, 10));
    final state = GameState()
      ..streakDays = 9
      ..bestStreak = 11
      ..lastCompletionDay = '2026-08-07'
      ..streakFreezes = 3;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StreakFreezeStatus(state: state)),
      ),
    );

    expect(find.text('BEST 11 · 3 FREEZES READY'), findsOneWidget);
    expect(find.textContaining('9 DAY STREAK'), findsNothing);
  });

  testWidgets('freeze use and replenishment are explicit in the receipt', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              RewardReceipt(
                state: state,
                bundle: RewardBundle(
                  xp: 20,
                  stat: Stat.vit,
                  statGain: 2,
                  questTitle: 'Open the curtains',
                  message: 'The room is glad to have you back.',
                  difficulty: 2,
                  freezesUsed: 2,
                  freezeEarned: true,
                  freezeBalanceAfter: 2,
                ),
                anchor: const Offset(160, 300),
                onDone: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('STREAK FROZEN · 2 DAYS HELD'), findsOneWidget);
    expect(find.text('FREEZE BANKED · 2 READY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the weekly strip distinguishes a frozen day from an active day',
    (tester) async {
      Clock.freeze(DateTime(2026, 8, 13));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MomentumStrip(
              history: {'2026-08-12': 2},
              frozenDays: {'2026-08-11'},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.ac_unit_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
