import 'package:emberkeep/audio.dart';
import 'package:emberkeep/content/evidence.dart';
import 'package:emberkeep/content/routines.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/workout_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Sfx.instance.soundEnabled = false;
  });

  tearDown(() {
    Sfx.instance.soundEnabled = true;
  });

  test('Morning Stretches is a gentle Vitality wake-up snack', () {
    final routine = routineById('morning-stretches');

    expect(routine, isNotNull);
    expect(routine!.title, 'Morning Stretches');
    expect(routine.stat, Stat.vit);
    expect(routine.restDay, isTrue);
    expect(routine.minutes, 4);
    expect(routine.moves.first.name, 'Easy march');
    expect(routine.moves.first.isWarmup, isTrue);
    expect(routine.moves.where((move) => move.isWork), hasLength(2));
    expect(evidenceByTitle(routine.evidenceTitle), isNotNull);
  });

  test('mobility rewards Vitality without claiming strength-goal progress', () {
    final routine = routineById('morning-stretches')!;
    final reward = workoutRewardQuest(routine, difficulty: routine.difficulty);
    final strengthReward = workoutRewardQuest(
      routineById('wake-up')!,
      difficulty: 2,
    );

    expect(reward.stat, Stat.vit);
    expect(reward.goalTitle, isNull);
    expect(strengthReward.goalTitle, 'The strength path');
  });

  testWidgets('Morning Stretches has stretch-specific safety guidance', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutFlow(
          state: GameState()..reduceMotion = true,
          recommended: routines.first,
          onFinish:
              ({
                required routine,
                required verified,
                required endedEarly,
                required workMovesDone,
              }) {},
          onClose: () {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Morning Stretches'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Morning Stretches'), findsWidgets);
    expect(
      find.textContaining('Move slowly, breathe normally'),
      findsOneWidget,
    );
    expect(find.textContaining('no bouncing'), findsOneWidget);
  });
}
