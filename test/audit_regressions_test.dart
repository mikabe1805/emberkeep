import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/visit_room.dart';
import 'package:emberkeep/screens/goal_wizard.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/notes_sheet.dart';
import 'package:emberkeep/widgets/onboarding_flow.dart';
import 'package:emberkeep/widgets/routine_flows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(Clock.reset);

  test('calendar gaps stay correct across daylight-saving boundaries', () {
    final state = GameState()..streakFreezes = 0;
    final quest = Quest(title: 'Walk', stat: Stat.vit, difficulty: 2);

    Clock.freeze(DateTime(2026, 3, 7, 12));
    state.commit(state.roll(quest));
    expect(state.streakDays, 1);

    // In New York this interval contains a 23-hour day. It is still two
    // calendar dates apart, with one genuinely open day between them.
    Clock.freeze(DateTime(2026, 3, 9, 12));
    final comeback = state.roll(quest);
    expect(comeback.comebackMult, isNotNull);
    expect(comeback.revivesHearth, isTrue);
    state.commit(comeback);
    expect(state.streakDays, 1);
    expect(state.comebacks, 1);
    expect(Days.between(DateTime(2026, 3, 7), DateTime(2026, 3, 9)), 2);
  });

  test('hearth ignition is reserved for first spark and real comeback', () {
    final state = GameState()..streakFreezes = 0;
    final quest = Quest(title: 'Tend the fire', stat: Stat.dis, difficulty: 2);

    Clock.freeze(DateTime(2026, 7, 20, 9));
    final firstSpark = state.roll(quest);
    expect(firstSpark.revivesHearth, isTrue);
    state.commit(firstSpark);

    Clock.freeze(DateTime(2026, 7, 21, 9));
    final continued = state.roll(quest);
    expect(continued.firstOfDay, isTrue);
    expect(continued.revivesHearth, isFalse);
    state.commit(continued);

    Clock.freeze(DateTime(2026, 7, 23, 9));
    final comeback = state.roll(quest);
    expect(comeback.revivesHearth, isTrue);
  });

  test('damaged persisted day keys are dropped instead of crashing play', () {
    final quest = Quest.fromJson({
      'title': 'Read',
      'stat': Stat.intl.index,
      'difficulty': 2,
      'lastDoneDay': '2026-02-31',
      'snoozedDay': 'not-a-day',
    });
    expect(quest.lastDoneDay, isNull);
    expect(quest.snoozedDay, isNull);
    expect(() => quest.doneFor(DateTime(2026, 3, 1)), returnsNormally);

    final state = GameState.fromJson({
      'stats': List<int>.filled(Stat.values.length, 0),
      'lastCompletionDay': 'broken',
      'history': {'also-broken': 99, '2026-03-01': 2},
    });
    expect(state.lastCompletionDay, isNull);
    expect(state.history, {'2026-03-01': 2});
  });

  test('loading self-heals achievements earned by older builds', () {
    final before = GameState()
      ..level = 3
      ..totalCompletions = 1;
    final json = before.toJson()..['unlockedAchievements'] = <String>[];

    final restored = GameState.fromJson(json);

    expect(restored.unlockedAchievements, contains('first-step'));
    expect(restored.ownedFurniture, containsAll(['rug', 'plant']));
  });

  test('the first level-up visibly furnishes the starter keep', () {
    final state = GameState();
    state.xp = state.xpNeeded(2);

    final result = state.applyLevelUps();

    expect(result.leveledTo, 2);
    expect(state.ownedFurniture, contains('rug'));
    expect(state.ownedFurniture, isNot(contains('plant')));
  });

  test('routine and goal achievements unlock where they are earned', () {
    Clock.freeze(DateTime(2026, 7, 27, 22));
    final state = GameState();

    state.closeNight();
    expect(state.unlockedAchievements, contains('night-owl'));

    for (var i = 1; i <= 3; i++) {
      expect(
        state.addGoal(Goal(title: 'Path $i', stat: Stat.dis, target: 25)),
        isTrue,
      );
    }
    expect(state.unlockedAchievements, contains('pathmaker'));
  });

  testWidgets('bookend routines hide quests that are not scheduled today', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 7, 7, 9)); // Tuesday
    final state = GameState();
    final offDay = Quest(
      title: 'Wednesday only',
      stat: Stat.dis,
      difficulty: 2,
      weekdays: const [DateTime.wednesday],
    );
    final today = Quest(
      title: 'Tuesday quest',
      stat: Stat.str,
      difficulty: 2,
      weekdays: const [DateTime.tuesday],
      priority: true,
    );
    final offDayAllDay = Quest(
      title: 'Wednesday line',
      stat: Stat.vit,
      difficulty: 2,
      allDay: true,
      weekdays: const [DateTime.wednesday],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MorningFlow(
          state: state,
          quests: [offDay, today, offDayAllDay],
          onClose: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Tuesday quest'), findsOneWidget);
    expect(find.text('Wednesday only'), findsNothing);
    expect(find.text('Wednesday line'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: NightFlow(
          state: state,
          quests: [offDayAllDay],
          onClose: () {},
          onPersist: () {},
          onAdd: (_) => true,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Wednesday line'), findsNothing);
  });

  testWidgets('a malformed public room payload renders a safe fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VisitRoomScreen(
          room: {
            'name': 42,
            'title': ['not', 'text'],
            'level': 'high',
            'furniture': ['rug', 7, null],
            'wall': false,
          },
          code: 'ABC234',
          lively: false,
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('a space'), findsOneWidget);
    expect(find.text('The Writer’s Hearth'), findsOneWidget);
  });

  test('relative note labels use calendar days across DST', () {
    expect(
      relativeWhen(
        DateTime(2026, 3, 8, 0, 30),
        now: DateTime(2026, 3, 9, 0, 15),
      ),
      'yesterday',
    );
  });

  testWidgets('onboarding and oath choices fit a narrow large-text phone', (
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

    final state = GameState();
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          state: state,
          onFinish:
              ({
                required forgeFirstGoal,
                required openGuide,
                required timeShape,
              }) {},
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    expect(
      tester.getBottomLeft(find.text('ENTER ROOM OF DAYS')).dy,
      lessThanOrEqualTo(568),
      reason: 'the first action should be visible without discovering a scroll',
    );
    await tester.tap(find.text('ENTER ROOM OF DAYS'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(
      tester.getBottomLeft(find.text('skip for now')).dy,
      lessThanOrEqualTo(568),
      reason: 'name and skip actions should remain visible on a small phone',
    );
    await tester.tap(find.text('skip for now'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(MaterialApp(home: GoalWizardScreen(state: state)));
    await tester.pump();
    await tester.tap(find.text('Reach a finish line'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('50'), findsOneWidget);
  });

  testWidgets('onboarding greets the actual time of day', (tester) async {
    Clock.freeze(DateTime(2026, 7, 31, 20, 15));
    final state = GameState();
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          state: state,
          onFinish:
              ({
                required forgeFirstGoal,
                required openGuide,
                required timeShape,
              }) {},
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('ENTER ROOM OF DAYS'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Good evening.'), findsOneWidget);
  });
}
