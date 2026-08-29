import 'dart:convert';

import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/goal_catalog.dart';
import 'package:emberkeep/content/ladders.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/goal_planner.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(Clock.reset);

  test('mastery thresholds are permanent and category-neutral', () {
    final cases = <int, QuestMasteryTier>{
      0: QuestMasteryTier.unmarked,
      4: QuestMasteryTier.unmarked,
      5: QuestMasteryTier.kept,
      14: QuestMasteryTier.kept,
      15: QuestMasteryTier.practiced,
      39: QuestMasteryTier.practiced,
      40: QuestMasteryTier.gilded,
      99: QuestMasteryTier.gilded,
      100: QuestMasteryTier.masterwork,
      500: QuestMasteryTier.masterwork,
    };
    for (final entry in cases.entries) {
      expect(
        questMasteryTierFor(entry.key),
        entry.value,
        reason: '${entry.key} completions',
      );
    }
  });

  test('every curated rising Quest owns a concrete safe ladder', () {
    final risingTemplates = [
      for (final idea in goalCatalog)
        for (final quest in idea.quests)
          if (quest.rising) quest,
    ];
    expect(risingTemplates, isNotEmpty);
    for (final template in risingTemplates) {
      expect(
        template.ladder,
        isNotNull,
        reason: '${template.title} cannot rise an invisible prescription',
      );
      expect(template.ladder!.length, greaterThan(1), reason: template.title);
    }
  });

  test(
    'Walk 10 minutes rises on its fifth completion and never shows 16/5',
    () {
      final state = GameState();
      final walk = Quest(
        title: 'Walk 10 minutes',
        stat: Stat.vit,
        difficulty: 3,
        rising: true,
        ladder: Ladders.walking,
        ladderHint: 'CLIMBS AS YOU GROW',
      );

      RewardBundle? fifth;
      for (var day = 0; day < 5; day++) {
        Clock.freeze(DateTime(2026, 8, 1 + day, 12));
        final bundle = state.roll(walk);
        state.commit(bundle);
        if (day == 4) fifth = bundle;
      }

      expect(fifth, isNotNull);
      final fifthBundle = fifth;
      if (fifthBundle == null) fail('the fifth completion was not captured');
      expect(fifthBundle.questTitle, 'Walk 10 minutes');
      expect(fifthBundle.difficulty, 3);
      expect(fifthBundle.risenToTitle, 'Walk 20 minutes');
      expect(fifthBundle.masteryTierReached, QuestMasteryTier.kept);
      expect(walk.displayTitle, 'Walk 20 minutes');
      expect(walk.difficulty, 4);
      expect(walk.rung, 1);
      expect(walk.risingStreak, 0);
      expect(walk.riseProgress, 0);
      expect(walk.masteryCompletions, 5);
      expect(walk.masteryTier, QuestMasteryTier.kept);
      expect(walk.readyToRise, isFalse);

      Clock.freeze(DateTime(2026, 8, 6, 12));
      state.commit(state.roll(walk));
      expect(walk.risingStreak, 1);
      expect(walk.riseProgress, 1);
      expect(walk.masteryCompletions, 6);
    },
  );

  test('a legacy 16/5 save gets one safe catch-up and keeps all history', () {
    final walk = Quest.fromJson({
      'title': 'Walk 10 minutes',
      'stat': Stat.vit.index,
      'difficulty': 3,
      'rising': true,
      'risingStreak': 16,
      'ladder': Ladders.walking,
      'rung': 0,
    });

    expect(walk.autoRise, isTrue);
    expect(walk.displayTitle, 'Walk 20 minutes');
    expect(walk.rung, 1);
    expect(walk.difficulty, 4);
    expect(walk.risingStreak, 0);
    expect(walk.riseProgress, 0);
    expect(walk.masteryCompletions, 16);
    expect(walk.masteryTier, QuestMasteryTier.practiced);

    final restored = Quest.fromJson(
      (jsonDecode(jsonEncode(walk.toJson())) as Map).cast<String, dynamic>(),
    );
    expect(restored.rung, 1, reason: 'a modern save must not catch up twice');
    expect(restored.risingStreak, 0);
    expect(restored.masteryCompletions, 16);
    expect(restored.autoRise, isTrue);
  });

  test('final authored rung builds mastery without a hidden rise meter', () {
    final walk = Quest(
      title: 'Walk 10 minutes',
      stat: Stat.vit,
      difficulty: 7,
      rising: true,
      risingStreak: 4,
      masteryCompletions: 99,
      ladder: Ladders.walking,
      rung: Ladders.walking.length - 1,
    );

    final change = walk.recordCompletionProgress();
    expect(change.tierReached, QuestMasteryTier.masterwork);
    expect(change.risenToTitle, isNull);
    expect(walk.masteryCompletions, 100);
    expect(walk.risingStreak, 0);
    expect(walk.readyToRise, isFalse);
    expect(walk.displayTitle, Ladders.walking.last);
    expect(walk.difficulty, 7);
  });

  test('school, home, movement, creative, and care earn equal mastery', () {
    final quests = [
      Quest(title: 'Review lecture notes', stat: Stat.intl, difficulty: 2),
      Quest(title: 'Clear the kitchen table', stat: Stat.dis, difficulty: 2),
      Quest(title: 'Walk around the block', stat: Stat.vit, difficulty: 2),
      Quest(title: 'Practice one song', stat: Stat.foc, difficulty: 2),
      Quest(title: 'Call Mom', stat: Stat.soc, difficulty: 2),
    ];

    for (final quest in quests) {
      for (var i = 0; i < 15; i++) {
        quest.recordCompletionProgress();
      }
    }

    for (final quest in quests) {
      expect(quest.masteryCompletions, 15, reason: quest.title);
      expect(
        quest.masteryTier,
        QuestMasteryTier.practiced,
        reason: quest.title,
      );
      expect(quest.difficulty, 2, reason: quest.title);
      expect(quest.risingStreak, 0, reason: quest.title);
    }
  });

  test('Workshop routine mastery survives each generated Quest attempt', () {
    final state = GameState();
    final goal = Goal(
      title: 'Keep up with class',
      stat: Stat.intl,
      target: 25,
      plan: GoalPlan(
        type: GoalRouteType.routine,
        outcome: 'Keep up with class',
        startingPoint: 'One lecture behind',
        successProof: 'The current lecture notes are reviewed',
        timeBudgetMinutes: 15,
        obstacleCue: 'the whole lecture feels too large',
        fallbackAction: 'Review one paragraph of notes',
        steps: const [
          GoalPlanStep(
            id: 'anchor',
            title: 'Choose the anchor',
            actionTitle: 'Open the lecture notes after class',
            proof: 'The notes are open',
            whyNow: 'The anchor already exists.',
            ctaLabel: 'OPEN THE NOTES',
            minutes: 1,
            kind: GoalPlanStepKind.prepare,
            completions: 1,
            masteryCompletions: 1,
            completedDay: '2026-08-01',
          ),
          GoalPlanStep(
            id: 'practice',
            title: 'Return to the notes',
            actionTitle: 'Review lecture notes for 15 minutes',
            proof: 'One review block is complete',
            whyNow: 'This is the repeatable version.',
            ctaLabel: 'REVIEW THE NOTES',
            minutes: 15,
            kind: GoalPlanStepKind.practice,
          ),
        ],
        createdDay: '2026-08-01',
      ),
    );
    state.goals.add(goal);
    final attempts = <Quest>[];
    RewardBundle? fifth;

    for (var day = 0; day < 5; day++) {
      final now = DateTime(2026, 8, 10 + day, 12);
      Clock.freeze(now);
      final decision = GoalPlanner.decide(goal, attempts, now);
      expect(decision, isNotNull);
      final quest = GoalPlanner.questFor(goal, decision!, now);
      attempts.add(quest);
      final bundle = state.roll(quest);
      state.commit(bundle);
      if (day == 4) fifth = bundle;

      expect(
        goal.plan!.steps[1].masteryCompletions,
        day + 1,
        reason: 'the stable Workshop marker must retain attempt ${day + 1}',
      );
    }

    expect(attempts.map((quest) => quest.goalPlanRevision).toSet().length, 5);
    expect(attempts.last.masteryCompletions, 5);
    expect(fifth!.masteryTierReached, QuestMasteryTier.kept);

    final restored = Goal.fromJson(
      (jsonDecode(jsonEncode(goal.toJson())) as Map).cast<String, dynamic>(),
    );
    expect(restored.plan!.steps[1].masteryCompletions, 5);
  });

  test('custom ladders ask before rising and arbitrary tasks never harden', () {
    final state = GameState();
    final custom = Quest(
      title: 'Read 5 pages',
      stat: Stat.intl,
      difficulty: 2,
      custom: true,
      rising: true,
      ladder: const ['Read 5 pages', 'Read 10 pages'],
    );
    final maintenance = Quest(
      title: 'Reset the apartment',
      stat: Stat.dis,
      difficulty: 2,
      custom: true,
      rising: true,
    );

    for (var day = 0; day < 5; day++) {
      Clock.freeze(DateTime(2026, 8, 10 + day, 12));
      state.commit(state.roll(custom));
      state.commit(state.roll(maintenance));
    }

    expect(custom.autoRise, isFalse);
    expect(custom.rung, 0);
    expect(custom.risingStreak, 5);
    expect(custom.riseProgress, 5);
    expect(custom.readyToRise, isTrue);
    expect(custom.masteryTier, QuestMasteryTier.kept);

    expect(maintenance.autoRise, isFalse);
    expect(maintenance.difficulty, 2);
    expect(maintenance.risingStreak, 0);
    expect(maintenance.readyToRise, isFalse);
    expect(maintenance.masteryTier, QuestMasteryTier.kept);
  });

  test('guided reward builds mastery on its persistent launcher', () {
    Clock.freeze(DateTime(2026, 8, 20, 12));
    final state = GameState();
    final reward = Quest(
      title: 'Gentle strength session',
      stat: Stat.str,
      difficulty: 3,
    );
    final launcher = Quest(
      title: 'Strength workout',
      stat: Stat.str,
      difficulty: 3,
      workout: true,
    );

    final bundle = state.roll(reward, progressionQuest: launcher);
    expect(reward.masteryCompletions, 0);
    expect(launcher.masteryCompletions, 1);
    expect(bundle.masteryCompletionsAfter, 1);
  });
}
