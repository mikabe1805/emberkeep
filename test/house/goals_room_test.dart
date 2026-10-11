// The Goals tab as the Steward's workshop: the card (with a goal and without),
// the sign on the pillar, the wall's labels, everything Goals has ever offered
// still being reachable, large text, Reduce Motion and the goal page standing
// in the same room.
import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/goal_planner.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/goal_detail.dart';
import 'package:emberkeep/screens/goals.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/goal_world.dart';
import 'package:emberkeep/widgets/house/goals/goals_room.dart';
import 'package:emberkeep/widgets/house/house_backdrop.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:emberkeep/widgets/house/house_travel_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../support/goals_room_support.dart';

Goal _goal(String title, Stat stat, {bool complete = false}) => Goal(
  title: title,
  stat: stat,
  target: 25,
  progress: complete ? 25 : 6,
  openingSeen: true,
  startedDay: '2026-09-20',
  achievedDay: complete ? '2026-10-01' : null,
);

Quest _quest(String title, Stat stat, String goal) =>
    Quest(title: title, stat: stat, difficulty: 1, goalTitle: goal);

Future<void> _pump(
  WidgetTester tester, {
  required GameState state,
  required List<Quest> quests,
  Size size = const Size(393, 852),
  double textScale = 1,
  bool disableAnimations = false,
  void Function(Quest)? onOpenQuest,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: GoalsPage(
          state: state,
          quests: quests,
          onAdd: (quest) {
            quests.add(quest);
            return true;
          },
          onRemoveQuest: quests.remove,
          onRemoveGoal: state.removeGoal,
          onPersist: () {},
          onOpenQuest: onOpenQuest ?? (_) {},
          onOpenQuests: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Mika's three goals of the prototype's wall, each with a first step.
({GameState state, List<Quest> quests}) _wall({int count = 3}) {
  final state = GameState()..reduceMotion = true;
  final quests = <Quest>[];
  const goals = <(String, Stat, String)>[
    ('Room of Days', Stat.foc, 'Open the app'),
    ('Computer Architecture', Stat.foc, 'Review one problem'),
    ('Summer 2027', Stat.soc, 'Send one application'),
    ('Make the apartment feel calm', Stat.dis, 'Clear the kitchen counter'),
    ('Build a walking habit', Stat.vit, 'Walk after lunch'),
  ];
  for (final (title, stat, quest) in goals.take(count)) {
    state.goals.add(_goal(title, stat));
    quests.add(_quest(quest, stat, title));
  }
  state.featuredGoalTitles.add(goals.first.$1);
  return (state: state, quests: quests);
}

Finder _label(String title) => find.byKey(
  Key('goals-wall-${title.trim().toLowerCase().replaceAll(' ', '-')}'),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => Sfx.instance.soundEnabled = false);
  tearDown(() {
    Sfx.instance.soundEnabled = true;
    Clock.reset();
  });

  group('the card with a current goal', () {
    testWidgets('names the goal, its next thing, and its two buttons', (
      tester,
    ) async {
      Clock.freeze(DateTime(2026, 10, 6, 12, 30));
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);

      expect(find.text('CURRENT GOAL'), findsOneWidget);
      expect(find.byKey(const Key('goals-card-name')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('goals-card-name'))).data,
        'Room of Days',
      );
      expect(find.text('THE NEXT THING · CURRENT QUEST'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('goals-card-next'))).data,
        'Open the app',
      );
      expect(find.text('OPEN QUEST'), findsOneWidget);
      expect(find.text('CHOOSE TODAY’S THREE'), findsOneWidget);
      // The card carries the room: nothing else of Goals is on its face.
      expect(find.byKey(const Key('goals-review-goal')), findsNothing);
      expect(find.byKey(const Key('other-goals-disclosure')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Open Quest hands over the goal\'s exact Quest', (
      tester,
    ) async {
      Clock.freeze(DateTime(2026, 10, 6, 12, 30));
      final w = _wall();
      final opened = <Quest>[];
      await _pump(
        tester,
        state: w.state,
        quests: w.quests,
        onOpenQuest: opened.add,
      );
      await tester.tap(find.byKey(const Key('goals-return-primary-action')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pumpAndSettle();
      expect(opened, hasLength(1));
      expect(opened.single.title, 'Open the app');
    });

    testWidgets('the next thing is a button too', (tester) async {
      Clock.freeze(DateTime(2026, 10, 6, 12, 30));
      final w = _wall();
      final opened = <Quest>[];
      await _pump(
        tester,
        state: w.state,
        quests: w.quests,
        onOpenQuest: opened.add,
      );
      await tester.tap(find.byKey(const Key('goals-card-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pumpAndSettle();
      expect(opened.single.title, 'Open the app');
    });

    testWidgets('Choose today\'s three counts what is chosen', (tester) async {
      Clock.freeze(DateTime(2026, 10, 6, 12, 30));
      final w = _wall();
      w.quests.first
        ..priorityDay = Days.key(Clock.now())
        ..priorityRank = 1;
      await _pump(tester, state: w.state, quests: w.quests);
      expect(find.text('TODAY’S THREE · 1'), findsOneWidget);
    });
  });

  group('the card with no goal', () {
    testWidgets('invites the Steward: Make room for a direction', (
      tester,
    ) async {
      await _pump(tester, state: GameState()..reduceMotion = true, quests: []);
      expect(find.text('MAKE ROOM FOR A DIRECTION'), findsOneWidget);
      expect(find.text('CREATE A GOAL'), findsOneWidget);
      expect(find.text('BROWSE STARTING POINTS'), findsOneWidget);
      expect(find.byKey(const Key('goals-card-name')), findsNothing);
      // No wall labels: there is nothing to pin.
      expect(find.byKey(const Key('goals-wall-room-of-days')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Create a goal goes to the Steward\'s first question', (
      tester,
    ) async {
      await _pump(tester, state: GameState()..reduceMotion = true, quests: []);
      await tester.tap(find.byKey(const Key('goals-create-first')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steward-intake')), findsOneWidget);
      expect(find.byKey(const Key('steward-ask-name')), findsOneWidget);
    });

    testWidgets('Browse starting points opens the ready-made goals', (
      tester,
    ) async {
      await _pump(tester, state: GameState()..reduceMotion = true, quests: []);
      await tester.tap(find.byKey(const Key('goals-browse-starting-points')));
      await tester.pumpAndSettle();
      expect(find.text('STARTING POINTS'), findsOneWidget);
    });

    testWidgets('after finished goals it says a new direction', (tester) async {
      final state = GameState()..reduceMotion = true;
      state.goals.add(_goal('Finish the portfolio', Stat.foc, complete: true));
      await _pump(tester, state: state, quests: []);
      expect(find.text('A NEW DIRECTION'), findsOneWidget);
      expect(find.text('CREATE A GOAL'), findsOneWidget);
      // The finished goal is still there, behind MORE.
      await revealOnGoalsPage(
        tester,
        find.byKey(const Key('completed-goals-disclosure')),
      );
    });
  });

  group('the sign on the pillar', () {
    testWidgets('reads the Steward\'s workshop and opens it', (tester) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      final sign = find.byKey(const Key('goals-open-workshop'));
      expect(
        find.descendant(
          of: sign,
          matching: find.text('The Steward’s workshop'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sign,
          matching: find.text('Turn a goal into a first step'),
        ),
        findsOneWidget,
      );
      await tester.tap(sign);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('goal-workshop-home')), findsOneWidget);
    });

    testWidgets('hangs on the pillar where the plate was painted for it', (
      tester,
    ) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      final rect = tester.getRect(find.byKey(const Key('goals-open-workshop')));
      expect(rect.left, closeTo(goalsSignLeft, 0.5));
      expect(rect.top, closeTo(goalsSignTop, 0.5));
      expect(rect.width, closeTo(goalsSignWidth, 0.5));
      // On the pillar, not over the shelves.
      expect(rect.right, lessThan(150));
    });

    testWidgets('is the one thing the lamp\'s glint crosses', (tester) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      expect(
        find.ancestor(
          of: find.byKey(const Key('goals-open-workshop')),
          matching: find.byType(HouseGlintSweep),
        ),
        findsOneWidget,
      );
    });

    testWidgets('with no goal it offers help to start one', (tester) async {
      await _pump(tester, state: GameState()..reduceMotion = true, quests: []);
      expect(find.text('Start a goal with help'), findsOneWidget);
    });
  });

  group('the wall', () {
    testWidgets('pins each goal as a label on its painted sheet', (
      tester,
    ) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      for (var i = 0; i < 3; i++) {
        final title = w.state.goals[i].title;
        final box = tester.getRect(_label(title));
        final slot = goalsWallSlots[i];
        // The label's glass sits at the slot's top (the tap target reaches a
        // little above and below it) and ends at the slot's right edge.
        expect(
          box.center.dy,
          closeTo(slot.top + 12 + 0, 14),
          reason: '$title top',
        );
        expect(box.right, closeTo(393 - slot.right, 1), reason: title);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the current goal\'s label is lit and the others are not', (
      tester,
    ) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      final semantics = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel('Room of Days, your current goal'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Computer Architecture, a goal'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('tapping another goal\'s label opens that goal', (
      tester,
    ) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      await tester.tap(_label('Computer Architecture'));
      await tester.pumpAndSettle();
      final detail = tester.widget<GoalDetailScreen>(
        find.byType(GoalDetailScreen),
      );
      expect(detail.goal.title, 'Computer Architecture');
    });

    testWidgets('tapping the current goal\'s label opens it too', (
      tester,
    ) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      await tester.tap(_label('Room of Days'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<GoalDetailScreen>(find.byType(GoalDetailScreen)).goal,
        w.state.goals.first,
      );
    });

    testWidgets('holds three goals; the current one is always among them', (
      tester,
    ) async {
      final w = _wall(count: 5);
      // The current goal is the fifth: it takes the last sheet.
      w.state.featuredGoalTitles
        ..clear()
        ..add('Build a walking habit');
      await _pump(tester, state: w.state, quests: w.quests);
      expect(_label('Room of Days'), findsOneWidget);
      expect(_label('Computer Architecture'), findsOneWidget);
      expect(_label('Build a walking habit'), findsOneWidget);
      expect(_label('Summer 2027'), findsNothing);
      expect(_label('Make the apartment feel calm'), findsNothing);
      // The goals the wall has no sheet for are still in the card's MORE.
      await revealOnGoalsPage(
        tester,
        find.byKey(const Key('other-goals-disclosure')),
      );
    });

    test(
      'goalsOnTheWall keeps order, caps at the sheets, keeps the current',
      () {
        expect(goalsOnTheWall<int>([1, 2], current: 2), [1, 2]);
        expect(goalsOnTheWall<int>([1, 2, 3, 4, 5], current: 1), [1, 2, 3]);
        expect(goalsOnTheWall<int>([1, 2, 3, 4, 5], current: 5), [1, 2, 5]);
        expect(goalsOnTheWall<int>([1, 2, 3, 4, 5], current: null), [1, 2, 3]);
        expect(goalsOnTheWall<int>(const [], current: null), isEmpty);
      },
    );

    testWidgets('a long name stays on its label and does not overflow', (
      tester,
    ) async {
      final state = GameState()..reduceMotion = true;
      const long =
          'Learn to sketch buildings from memory before the spring semester';
      state.goals.add(_goal(long, Stat.foc));
      await _pump(tester, state: state, quests: []);
      final box = tester.getRect(_label(long));
      expect(box.left, greaterThan(393 * 0.2));
      expect(box.width, lessThanOrEqualTo(393 * 0.72 + 1));
      expect(tester.takeException(), isNull);
    });
  });

  group('everything Goals has is still reachable', () {
    testWidgets('MORE holds this goal, other goals, finished goals, support, '
        'starting points and a new goal', (tester) async {
      Clock.freeze(DateTime(2026, 10, 6, 12, 30));
      final w = _wall();
      w.state.goals.add(
        _goal('Finish the portfolio', Stat.foc, complete: true),
      );
      // A route, so there is a current Quest to ease.
      final goal = w.state.goals.first;
      final plan = GoalPlanner.fromActions(
        title: goal.title,
        stat: goal.stat,
        type: GoalRouteType.skill,
        actions: const ['Open the app'],
        now: Clock.now(),
      );
      goal.plan = plan;
      w.quests.first
        ..goalPlanStepId = plan.currentStep!.id
        ..goalPlanRevision = plan.revision
        ..goalPlanAttempt = 1
        ..priorityDay = Days.key(Clock.now())
        ..priorityRank = 1;
      await _pump(tester, state: w.state, quests: w.quests);

      // Rolled up: only the card's face.
      expect(goalsRoomUnrolled, findsNothing);
      await openGoalsMore(tester);
      expect(goalsRoomUnrolled, findsOneWidget);

      for (final key in const [
        'goals-review-goal',
        'goals-recover-today',
        'other-goals-disclosure',
        'completed-goals-disclosure',
        'goals-support-toggle',
        'goals-new-goal',
        'goals-browse-starting-points',
      ]) {
        await revealOnGoalsPage(tester, find.byKey(Key(key)));
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Unstick Me and Guided Workouts open from the support tray', (
      tester,
    ) async {
      final w = _wall();
      final opened = <Quest>[];
      await _pump(
        tester,
        state: w.state,
        quests: w.quests,
        onOpenQuest: opened.add,
      );
      final toggle = find.byKey(const Key('goals-support-toggle'));
      await revealOnGoalsPage(tester, toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await revealOnGoalsPage(
        tester,
        find.byKey(const Key('goals-unstick-me')),
      );
      await tester.tap(find.byKey(const Key('goals-unstick-me')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('momentum-kit-text')), findsOneWidget);
    });

    testWidgets('a goal from the Other goals list becomes the current goal', (
      tester,
    ) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      final disclosure = find.byKey(const Key('other-goals-disclosure'));
      await revealOnGoalsPage(tester, disclosure);
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      final row = find.byKey(const Key('active-goal-summer 2027'));
      await revealOnGoalsPage(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('goals-card-name'))).data,
        'Summer 2027',
      );
    });

    testWidgets('Review this goal opens the goal and leaves the card rolled', (
      tester,
    ) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      final review = find.byKey(const Key('goals-review-goal'));
      await revealOnGoalsPage(tester, review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(find.byType(GoalDetailScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(GoalDetailScreen))).pop();
      await tester.pumpAndSettle();
      expect(goalsRoomUnrolled, findsNothing);
    });

    testWidgets('Starting points open from MORE when a goal is current', (
      tester,
    ) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      final door = find.byKey(const Key('goals-browse-starting-points'));
      await revealOnGoalsPage(tester, door);
      await tester.tap(door);
      await tester.pumpAndSettle();
      expect(find.text('STARTING POINTS'), findsOneWidget);
    });

    testWidgets('New goal in MORE goes through the Steward', (tester) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      final door = find.byKey(const Key('goals-new-goal'));
      await revealOnGoalsPage(tester, door);
      await tester.tap(door);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steward-intake')), findsOneWidget);
    });

    testWidgets('MORE rolls up again', (tester) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      await openGoalsMore(tester);
      expect(goalsRoomUnrolled, findsOneWidget);
      await tester.tap(goalsRoomMore);
      await tester.pumpAndSettle();
      expect(goalsRoomUnrolled, findsNothing);
    });
  });

  group('large text', () {
    for (final scale in [1.3, 2.0]) {
      for (final size in const [Size(393, 852), Size(320, 568)]) {
        testWidgets(
          'at ${(scale * 100).round()}% on ${size.width.round()} wide, with '
          'a goal: no overflow, every control reachable',
          (tester) async {
            Clock.freeze(DateTime(2026, 10, 6, 12, 30));
            final w = _wall();
            await _pump(
              tester,
              state: w.state,
              quests: w.quests,
              size: size,
              textScale: scale,
            );
            expect(tester.takeException(), isNull);
            for (final key in const [
              'goals-open-workshop',
              'goals-return-primary-action',
              'goals-today-field-action',
              'goals-room-more',
            ]) {
              final finder = find.byKey(Key(key));
              await revealOnGoalsPage(tester, finder);
              final box = tester.getRect(finder);
              expect(box.height, greaterThanOrEqualTo(44), reason: key);
              expect(box.width, greaterThanOrEqualTo(44), reason: key);
              expect(box.left, greaterThanOrEqualTo(0), reason: key);
              expect(box.right, lessThanOrEqualTo(size.width), reason: key);
            }
            for (final goal in w.state.goals) {
              final finder = _label(goal.title);
              await revealOnGoalsPage(tester, finder);
              final box = tester.getRect(finder);
              expect(box.right, lessThanOrEqualTo(size.width + 0.5));
              expect(box.left, greaterThanOrEqualTo(0));
            }
            await openGoalsMore(tester);
            await revealOnGoalsPage(
              tester,
              find.byKey(const Key('goals-browse-starting-points')),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }

      testWidgets('at ${(scale * 100).round()}% with no goal', (tester) async {
        await _pump(
          tester,
          state: GameState()..reduceMotion = true,
          quests: [],
          size: const Size(320, 568),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        for (final key in const [
          'goals-create-first',
          'goals-browse-starting-points',
          'goals-open-workshop',
        ]) {
          final finder = find.byKey(Key(key));
          await revealOnGoalsPage(tester, finder);
          expect(
            tester.getRect(finder).height,
            greaterThanOrEqualTo(44),
            reason: key,
          );
        }
      });
    }
  });

  group('Reduce Motion', () {
    testWidgets('MORE opens at once and the card swaps without a fade', (
      tester,
    ) async {
      final w = _wall();
      await _pump(
        tester,
        state: w.state,
        quests: w.quests,
        disableAnimations: true,
      );
      await tester.tap(goalsRoomMore);
      await tester.pump();
      expect(goalsRoomUnrolled, findsOneWidget);
      final fade = tester.widget<Opacity>(
        find.descendant(of: goalsRoomUnrolled, matching: find.byType(Opacity)),
      );
      expect(fade.opacity, 1);
    });

    testWidgets('the goal page arrives with a short fade', (tester) async {
      final w = _wall();
      await _pump(
        tester,
        state: w.state,
        quests: w.quests,
        disableAnimations: true,
      );
      await tester.tap(_label('Computer Architecture'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(GoalDetailScreen), findsOneWidget);
    });
  });

  group('semantics', () {
    testWidgets('the sign, the card\'s buttons and MORE speak plainly', (
      tester,
    ) async {
      final w = _wall();
      final handle = tester.ensureSemantics();
      await _pump(tester, state: w.state, quests: w.quests);
      expect(
        find.bySemanticsLabel(
          'The Steward’s workshop. Turn a goal into a first step',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Open Quest. Open the app'), findsOneWidget);
      expect(find.bySemanticsLabel('MORE. Collapsed.'), findsOneWidget);
      await tester.tap(goalsRoomMore);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('MORE. Open. Collapse.'), findsOneWidget);
      handle.dispose();
    });
  });

  group('the goal page stands in the same house plate', () {
    testWidgets('the push from a label keeps the workshop\'s plate', (
      tester,
    ) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      await tester.tap(_label('Computer Architecture'));
      await tester.pumpAndSettle();
      final backdrop = find.descendant(
        of: find.byType(GoalDetailScreen),
        matching: find.byType(HouseRoomBackdrop),
      );
      expect(backdrop, findsOneWidget);
      expect(tester.widget<HouseRoomBackdrop>(backdrop).room, HouseRoom.goals);
      // The old backdrop (the kitchen beyond the arch) is gone from the page.
      expect(
        find.descendant(
          of: find.byType(GoalDetailScreen),
          matching: find.byType(GoalRoomTravelBackdrop),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('and the push from Review this goal does too', (tester) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      final review = find.byKey(const Key('goals-review-goal'));
      await revealOnGoalsPage(tester, review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(GoalDetailScreen),
          matching: find.byType(HouseRoomBackdrop),
        ),
        findsOneWidget,
      );
    });
  });
}
