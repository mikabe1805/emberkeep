import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy goal deserialization leaves habit-support fields absent', () {
    final goal = Goal.fromJson({
      'title': 'Read more',
      'stat': Stat.foc.index,
      'target': 25,
    });

    expect(goal.why, isNull);
    expect(goal.fallbackCue, isNull);
    expect(goal.fallbackAction, isNull);
    expect(goal.firstProofTitle, isNull);
    expect(goal.firstProofDay, isNull);
    expect(goal.openingSeen, isTrue);
  });

  test('goal round-trips optional habit-support fields', () {
    final goal = Goal(
      title: 'Read more',
      stat: Stat.foc,
      target: 25,
      why: 'I want stories back in my evenings.',
      fallbackCue: 'When I am too tired for a chapter',
      fallbackAction: 'I will read one page.',
      firstProofTitle: 'Read one page',
      firstProofDay: '2026-08-26',
      openingSeen: false,
    );

    final restored = Goal.fromJson(goal.toJson());

    expect(restored.why, goal.why);
    expect(restored.fallbackCue, goal.fallbackCue);
    expect(restored.fallbackAction, goal.fallbackAction);
    expect(restored.firstProofTitle, goal.firstProofTitle);
    expect(restored.firstProofDay, goal.firstProofDay);
    expect(restored.openingSeen, isFalse);
  });

  test('first proof is stamped once by a real linked quest commit', () {
    Clock.freeze(DateTime(2026, 8, 26, 10));
    addTearDown(Clock.reset);
    final state = GameState();
    final goal = Goal(title: 'Read more', stat: Stat.foc, target: 25);
    state.addGoal(goal);
    final linked = Quest(
      title: 'Read one page',
      stat: Stat.foc,
      difficulty: 1,
      goalTitle: goal.title,
    );
    final unlinked = Quest(
      title: 'Water plants',
      stat: Stat.vit,
      difficulty: 1,
    );

    state.commit(state.roll(unlinked));
    expect(goal.firstProofTitle, isNull);
    expect(goal.firstProofDay, isNull);

    state.commit(state.roll(linked));
    expect(goal.firstProofTitle, 'Read one page');
    expect(goal.firstProofDay, '2026-08-26');

    Clock.freeze(DateTime(2026, 8, 27, 10));
    state.commit(state.roll(linked));
    expect(goal.firstProofTitle, 'Read one page');
    expect(goal.firstProofDay, '2026-08-26');
  });

  test(
    'user-authored support can change or clear without resetting progress',
    () {
      final state = GameState();
      final goal = Goal(
        title: 'Read more',
        stat: Stat.foc,
        target: 25,
        progress: 8,
      );
      state.addGoal(goal);
      var changes = 0;
      state.addListener(() => changes++);

      state.updateGoalSupport(
        goal,
        why: 'I miss getting absorbed in a story.',
        fallbackCue: 'I am too tired for a chapter',
        fallbackAction: 'read one page',
      );
      expect(changes, 1);
      expect(goal.progress, 8);
      expect(goal.why, isNotNull);

      state.updateGoalSupport(
        goal,
        why: null,
        fallbackCue: null,
        fallbackAction: null,
      );
      expect(changes, 2);
      expect(goal.progress, 8);
      expect(goal.why, isNull);
      expect(goal.fallbackCue, isNull);
      expect(goal.fallbackAction, isNull);
    },
  );
}
