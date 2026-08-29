import 'package:emberkeep/content/goal_catalog.dart';
import 'package:emberkeep/goal_planner.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 29, 10);

  test('every catalog starting point owns a concrete distinct finish line', () {
    final finishLines = goalCatalog
        .map((idea) => idea.finishLine.trim())
        .toList(growable: false);
    expect(finishLines, hasLength(goalCatalog.length));
    expect(finishLines.toSet(), hasLength(goalCatalog.length));
    expect(finishLines.every((line) => line.length >= 48), isTrue);
    expect(finishLines, isNot(contains(contains('fits an ordinary week'))));
    expect(finishLines, isNot(contains(contains('finished and checked'))));

    final frictionCues = goalCatalog
        .map((idea) => idea.frictionCue.trim())
        .toList(growable: false);
    expect(frictionCues.toSet(), hasLength(goalCatalog.length));
    expect(frictionCues.every((cue) => cue.length >= 35), isTrue);
    expect(
      frictionCues,
      isNot(contains(contains('the full version does not fit today'))),
    );

    final lighterMoves = goalCatalog
        .map((idea) => idea.lighterMove.trim())
        .toList(growable: false);
    expect(lighterMoves.toSet(), hasLength(goalCatalog.length));
    expect(lighterMoves.every((move) => move.length >= 13), isTrue);
  });

  test(
    'catalog routes preserve their authored friction and lighter response',
    () {
      for (final idea in goalCatalog) {
        final route = GoalPlanner.fromActions(
          title: idea.title,
          stat: idea.stat,
          type: GoalRouteType.routine,
          actions: idea.quests.map((quest) => quest.title),
          now: now,
          successProof: idea.finishLine,
          obstacleCue: idea.frictionCue,
          fallbackAction: idea.lighterMove,
        );
        expect(route.obstacleCue, idea.frictionCue);
        expect(route.fallbackAction, idea.lighterMove);
      }
    },
  );

  GoalPlanInput input({
    required String title,
    required String outcome,
    required String startingPoint,
    required String successProof,
    Stat stat = Stat.dis,
  }) => GoalPlanInput(
    title: title,
    stat: stat,
    type: GoalRouteType.reset,
    outcome: outcome,
    startingPoint: startingPoint,
    successProof: successProof,
    timeBudgetMinutes: 15,
    obstacleCue: 'the full version does not fit today',
    now: now,
  );

  test('reset routes give each domain an equally concrete first move', () {
    final cases = <String, GoalPlanInput>{
      'home': input(
        title: 'Make the apartment calmer',
        outcome: 'the kitchen is usable',
        startingPoint: 'the counter is crowded',
        successProof: 'the kitchen stays usable',
      ),
      'study': input(
        title: 'Do better in school',
        outcome: 'my grades improve this semester',
        startingPoint: 'homework is scattered',
        successProof: 'the next assignment is complete',
      ),
      'movement': input(
        title: 'Get back into working out',
        outcome: 'movement feels workable again',
        startingPoint: 'i have not exercised recently',
        successProof: 'i move three times this week',
      ),
      'creative': input(
        title: 'Return to making music',
        outcome: 'i finish a song draft',
        startingPoint: 'the project file is waiting',
        successProof: 'one song draft exists',
      ),
      'general': input(
        title: 'Make life feel more manageable',
        outcome: 'one part of the situation changes',
        startingPoint: 'i am not sure where to begin',
        successProof: 'one part of the situation is workable',
      ),
    };

    final plans = {
      for (final entry in cases.entries)
        entry.key: GoalPlanner.draft(entry.value),
    };

    expect(plans['home']!.steps[1].title, 'Clear one working zone');
    expect(plans['home']!.steps[1].actionTitle, contains('zone'));
    expect(plans['study']!.steps[1].title, 'Open one working block');
    expect(plans['study']!.steps[1].actionTitle, contains('study'));
    expect(plans['movement']!.steps[1].title, contains('movement'));
    expect(plans['creative']!.steps[1].title, 'Reopen one working piece');
    expect(plans['creative']!.steps[1].actionTitle, contains('working piece'));
    expect(plans['general']!.steps[1].title, 'Change one workable piece');

    for (final entry in plans.entries.where((entry) => entry.key != 'home')) {
      final steps = entry.value.steps;
      expect(
        steps.map((step) => '${step.title} ${step.actionTitle}').join(' '),
        isNot(contains('zone')),
        reason: '${entry.key} should not inherit home-only zone language',
      );
      expect(steps[1].proof, isNotEmpty);
      expect(steps[1].whyNow, contains('proof'));
      expect(steps[1].minutes, 15);
    }
  });

  test(
    'school and creative signals win over reset fallback and stat defaults',
    () {
      final school = GoalPlanner.draft(
        input(
          title: 'Catch up before my next exam',
          outcome: 'understand the lecture material',
          startingPoint: 'the textbook and assignment are open',
          successProof: 'i can answer the next question',
          stat: Stat.dis,
        ),
      );
      final creative = GoalPlanner.draft(
        input(
          title: 'Practice guitar again',
          outcome: 'play one song cleanly',
          startingPoint: 'my instrument is ready',
          successProof: 'i can play one song cleanly',
          stat: Stat.dis,
        ),
      );

      expect(school.steps[1].actionTitle, contains('study block'));
      expect(creative.steps[1].actionTitle, contains('working piece'));
      expect(school.fallbackAction, contains('material'));
      expect(creative.fallbackAction, contains('rough mark'));
    },
  );
}
