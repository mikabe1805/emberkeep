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
import 'package:emberkeep/widgets/pressable.dart';
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
({GameState state, List<Quest> quests}) _wall({
  int count = 3,
  bool reduceMotion = true,
}) {
  final state = GameState()..reduceMotion = reduceMotion;
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

final Finder _card = find.byKey(const Key('goals-room-card'));
final Finder _moreTag = find.byKey(const Key('goals-wall-more'));
Key _face(String id) => ValueKey<String>('goals-card-face-$id');

String? _nameOf(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('goals-card-name'))).data;

/// The edge of a label's glass.
const Color _litEdge = Color(0xE6EEC076);
const Color _quietEdge = Color(0x42F6E2BF);

/// The glass of a label or tag: the box under its blur.
Finder _glassOf(Finder control) => find
    .descendant(
      of: find.descendant(of: control, matching: find.byType(BackdropFilter)),
      matching: find.byType(DecoratedBox),
    )
    .first;

Color _edge(WidgetTester tester, String title) {
  final deco = tester.widget<DecoratedBox>(_glassOf(_label(title))).decoration;
  return ((deco as BoxDecoration).border! as Border).top.color;
}

/// How visible a goal's card face is (its fade).
double _opacity(WidgetTester tester, String id) {
  final fade = find
      .ancestor(
        of: find.byKey(_face(id)),
        matching: find.byType(FadeTransition),
      )
      .first;
  return tester.widget<FadeTransition>(fade).opacity.value;
}

bool _overlap(Rect a, Rect b) => a.deflate(0.6).overlaps(b.deflate(0.6));

/// The "+N" tag touches no label, the sign or the card, and is on screen.
void _expectTagClear(
  WidgetTester tester,
  GameState state, {
  double width = 393,
  bool card = true,
}) {
  final tag = tester.getRect(_moreTag);
  final tagGlass = tester.getRect(_glassOf(_moreTag));
  expect(tag.left, greaterThanOrEqualTo(0));
  expect(tag.right, lessThanOrEqualTo(width + 0.5));
  // The tag's glass is clear of every label's glass. (Its 44 pt area may share
  // a few points with the lowest label's, below that label's glass: the tag is
  // drawn after the label and is the one pressed there.)
  for (final goal in state.goals) {
    final label = _label(goal.title);
    if (label.evaluate().isEmpty) continue;
    expect(
      _overlap(tagGlass, tester.getRect(_glassOf(label))),
      isFalse,
      reason: 'the tag and ${goal.title}',
    );
  }
  final sign = find.byKey(const Key('goals-open-workshop'));
  if (sign.evaluate().isNotEmpty) {
    expect(_overlap(tag, tester.getRect(sign)), isFalse, reason: 'the sign');
  }
  // The tag's glass (its tap area reaches 20 pt below it) is clear of the card.
  if (!card) return;
  expect(
    _overlap(tagGlass, tester.getRect(_card)),
    isFalse,
    reason: 'the card',
  );
}

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

    testWidgets('tapping another goal\'s label makes it the current goal', (
      tester,
    ) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      await tester.tap(_label('Computer Architecture'));
      await tester.pumpAndSettle();
      // The goal's page does not open: the card changes to that goal.
      expect(find.byType(GoalDetailScreen), findsNothing);
      expect(_nameOf(tester), 'Computer Architecture');
      expect(
        tester.widget<Text>(find.byKey(const Key('goals-card-next'))).data,
        'Review one problem',
      );
      expect(find.byKey(_face('computer architecture')), findsOneWidget);
      expect(find.byKey(_face('room of days')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the lit edge moves to the label that was tapped', (
      tester,
    ) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      expect(_edge(tester, 'Room of Days'), _litEdge);
      expect(_edge(tester, 'Computer Architecture'), _quietEdge);
      await tester.tap(_label('Computer Architecture'));
      await tester.pumpAndSettle();
      expect(_edge(tester, 'Computer Architecture'), _litEdge);
      expect(_edge(tester, 'Room of Days'), _quietEdge);
      final semantics = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel('Computer Architecture, your current goal'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Room of Days, a goal'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('the light crosses between the two edges, it does not jump', (
      tester,
    ) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      await tester.tap(_label('Computer Architecture'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      expect(_edge(tester, 'Computer Architecture'), isNot(_litEdge));
      expect(_edge(tester, 'Computer Architecture'), isNot(_quietEdge));
      expect(_edge(tester, 'Room of Days'), isNot(_litEdge));
      expect(_edge(tester, 'Room of Days'), isNot(_quietEdge));
      await tester.pumpAndSettle();
      expect(_edge(tester, 'Computer Architecture'), _litEdge);
    });

    testWidgets('it is the choosing Other goals in MORE does: the same goal '
        'is current, the others are the list', (tester) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      await tester.tap(_label('Summer 2027'));
      await tester.pumpAndSettle();
      expect(_nameOf(tester), 'Summer 2027');
      final disclosure = find.byKey(const Key('other-goals-disclosure'));
      await revealOnGoalsPage(tester, disclosure);
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('active-goal-room of days')), findsOneWidget);
      expect(
        find.byKey(const Key('active-goal-computer architecture')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('active-goal-summer 2027')), findsNothing);
    });

    testWidgets('a label is voiced once, by the choosing or the opening', (
      tester,
    ) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      final label = tester.widget<Pressable>(_label('Summer 2027'));
      // The page plays the parchment flick (page/open) for both taps; the
      // label itself stays quiet so one tap is one sound.
      expect(label.material, MaterialSound.parchment);
      expect(label.soundEnabled, isFalse);
    });

    testWidgets('the card fades through to the new goal and eases its height', (
      tester,
    ) async {
      final w = _wall(reduceMotion: false);
      await _pump(tester, state: w.state, quests: w.quests);
      expect(
        find.descendant(of: _card, matching: find.byType(AnimatedSize)),
        findsOneWidget,
      );
      await tester.tap(_label('Computer Architecture'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 45));
      // Both goals' faces are on the card, the old one on its way out.
      final out = _opacity(tester, 'room of days');
      final inn = _opacity(tester, 'computer architecture');
      expect(out, inExclusiveRange(0.0, 1.0));
      expect(inn, lessThan(0.05));
      // The leaving face cannot be touched and is not read out.
      expect(
        find.ancestor(
          of: find.byKey(_face('room of days')),
          matching: find.byWidgetPredicate(
            (w) => w is IgnorePointer && w.ignoring,
          ),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 80));
      expect(_opacity(tester, 'room of days'), lessThan(0.01));
      expect(
        _opacity(tester, 'computer architecture'),
        inExclusiveRange(0.0, 1.0),
      );
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();
      expect(find.byKey(_face('room of days')), findsNothing);
      expect(_opacity(tester, 'computer architecture'), 1);
    });

    testWidgets('the swap takes about 220 ms', (tester) async {
      expect(goalsSwapDuration, const Duration(milliseconds: 220));
      final w = _wall(reduceMotion: false);
      await _pump(tester, state: w.state, quests: w.quests);
      await tester.tap(_label('Computer Architecture'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(_face('room of days')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byKey(_face('room of days')), findsNothing);
    });

    testWidgets('the same goal\'s card is not remade when it rebuilds', (
      tester,
    ) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      final before = tester.element(find.byKey(_face('room of days')));
      await tester.tap(goalsRoomMore);
      await tester.pumpAndSettle();
      expect(tester.element(find.byKey(_face('room of days'))), same(before));
    });

    testWidgets('the current goal\'s label opens its page', (tester) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      await tester.tap(_label('Room of Days'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<GoalDetailScreen>(find.byType(GoalDetailScreen)).goal,
        w.state.goals.first,
      );
    });

    testWidgets('after a swap the new current goal\'s label opens its page', (
      tester,
    ) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      await tester.tap(_label('Summer 2027'));
      await tester.pumpAndSettle();
      expect(find.byType(GoalDetailScreen), findsNothing);
      await tester.tap(_label('Summer 2027'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<GoalDetailScreen>(find.byType(GoalDetailScreen)).goal,
        w.state.goals[2],
      );
    });

    testWidgets('a label says what a tap does', (tester) async {
      final w = _wall();
      final semantics = tester.ensureSemantics();
      await _pump(tester, state: w.state, quests: w.quests);
      final current = find.bySemanticsLabel('Room of Days, your current goal');
      expect(tester.getSemantics(current).hint, 'Open this goal.');
      final other = find.bySemanticsLabel('Computer Architecture, a goal');
      expect(tester.getSemantics(other).hint, 'Make this your current goal.');
      semantics.dispose();
    });

    testWidgets('every label is a 44 pt target', (tester) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      for (final goal in w.state.goals) {
        expect(
          tester.getSize(_label(goal.title)).height,
          greaterThanOrEqualTo(44),
          reason: goal.title,
        );
      }
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

  group('the card\'s name opens the goal', () {
    testWidgets('a small chevron follows the name and it is a 44 pt target', (
      tester,
    ) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      final name = find.byKey(const Key('goals-card-open-goal'));
      expect(
        find.descendant(
          of: name,
          matching: find.byIcon(Icons.chevron_right_rounded),
        ),
        findsOneWidget,
      );
      final box = tester.getRect(name);
      expect(box.height, greaterThanOrEqualTo(44));
      expect(box.width, greaterThanOrEqualTo(44));
      // The chevron comes after the name, on its line.
      final text = tester.getRect(find.byKey(const Key('goals-card-name')));
      final chevron = tester.getRect(
        find.descendant(
          of: name,
          matching: find.byIcon(Icons.chevron_right_rounded),
        ),
      );
      expect(chevron.left, greaterThanOrEqualTo(text.right));
      expect(chevron.left - text.right, lessThan(12));
      expect(chevron.width, lessThanOrEqualTo(20));
    });

    testWidgets('pressing the name opens that goal\'s page', (tester) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      await tester.tap(find.byKey(const Key('goals-card-open-goal')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<GoalDetailScreen>(find.byType(GoalDetailScreen)).goal,
        w.state.goals.first,
      );
    });

    testWidgets('after a swap it opens the new goal', (tester) async {
      final w = _wall();
      await _pump(tester, state: w.state, quests: w.quests);
      await tester.tap(_label('Computer Architecture'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('goals-card-open-goal')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<GoalDetailScreen>(find.byType(GoalDetailScreen)).goal,
        w.state.goals[1],
      );
    });

    testWidgets('VoiceOver hears "Open goal, <name>"', (tester) async {
      final w = _wall();
      final semantics = tester.ensureSemantics();
      await _pump(tester, state: w.state, quests: w.quests);
      expect(find.bySemanticsLabel('Open goal, Room of Days'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('the card is the height it was before the name opened the '
        'goal', (tester) async {
      final state = GameState()..reduceMotion = true;
      state.goals.add(_goal('Cooking', Stat.dis));
      final quests = [_quest('Open the app', Stat.dis, 'Cooking')];
      state.featuredGoalTitles.add('Cooking');
      await _pump(tester, state: state, quests: quests);
      final card = tester.getRect(_card);
      // The card, the next row and the buttons are where they were: the name's
      // 44 pt area shares the caps line's row and the gap below the name.
      expect(card.height, 236);
      expect(tester.getRect(find.byKey(const Key('goals-card-next'))).top, 637);
      expect(
        tester
            .getRect(find.byKey(const Key('goals-return-primary-action')))
            .top,
        681,
      );
      expect(
        tester.getRect(find.byKey(const Key('goals-card-name'))).top,
        card.top + 46,
      );
    });

    testWidgets('MORE keeps its corner under a long name', (tester) async {
      final state = GameState()..reduceMotion = true;
      const long = 'Learn to sketch buildings from memory before the spring';
      state.goals.add(_goal(long, Stat.foc));
      await _pump(tester, state: state, quests: []);
      final more = tester.getRect(goalsRoomMore);
      // The name's area runs under MORE's lower edge; MORE wins there.
      await tester.tapAt(Offset(more.center.dx, more.bottom - 2));
      await tester.pumpAndSettle();
      expect(find.byType(GoalDetailScreen), findsNothing);
      expect(goalsRoomUnrolled, findsOneWidget);
    });

    testWidgets('at large text it is still a 44 pt target and nothing '
        'overflows', (tester) async {
      for (final scale in [1.3, 2.0]) {
        final w = _wall();
        await _pump(
          tester,
          state: w.state,
          quests: w.quests,
          size: const Size(320, 568),
          textScale: scale,
        );
        final name = find.byKey(const Key('goals-card-open-goal'));
        await revealOnGoalsPage(tester, name);
        final box = tester.getRect(name);
        expect(box.height, greaterThanOrEqualTo(44), reason: '$scale');
        expect(box.right, lessThanOrEqualTo(320), reason: '$scale');
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('more goals than the wall has sheets', () {
    testWidgets('a "+N" shows only with four goals or more', (tester) async {
      for (final count in [0, 1, 2, 3]) {
        final w = _wall(count: count);
        await _pump(tester, state: w.state, quests: w.quests);
        expect(_moreTag, findsNothing, reason: '$count goals');
      }
      final four = _wall(count: 4);
      await _pump(tester, state: four.state, quests: four.quests);
      expect(_moreTag, findsOneWidget);
      expect(
        find.descendant(of: _moreTag, matching: find.text('+1')),
        findsOne,
      );
      final five = _wall(count: 5);
      await _pump(tester, state: five.state, quests: five.quests);
      expect(
        find.descendant(of: _moreTag, matching: find.text('+2')),
        findsOne,
      );
    });

    testWidgets('finished goals are not counted', (tester) async {
      final w = _wall(count: 3);
      w.state.goals.add(
        _goal('Finish the portfolio', Stat.foc, complete: true),
      );
      await _pump(tester, state: w.state, quests: w.quests);
      expect(_moreTag, findsNothing);
    });

    testWidgets('it hangs just below the lowest label, at its right edge, and '
        'touches nothing', (tester) async {
      final w = _wall(count: 5);
      await _pump(tester, state: w.state, quests: w.quests);
      _expectTagClear(tester, w.state);
      final label = tester.getRect(_glassOf(_label('Summer 2027')));
      final glass = tester.getRect(_glassOf(_moreTag));
      expect(glass.top - label.bottom, closeTo(3, 0.5));
      expect(glass.right, closeTo(label.right, 0.5));
      // Small and quiet: smaller than a label's glass.
      expect(glass.height, lessThan(label.height));
      expect(glass.width, lessThan(40));
      // Its 44 pt area starts at its glass and reaches down and to the left.
      final area = tester.getRect(_moreTag);
      expect(area.top, closeTo(glass.top, 0.5));
      expect(area.right, closeTo(glass.right + 6, 0.5));
      expect(area.height, greaterThanOrEqualTo(44));
    });

    testWidgets('it is a 44 pt target and speaks plainly', (tester) async {
      final w = _wall(count: 5);
      final semantics = tester.ensureSemantics();
      await _pump(tester, state: w.state, quests: w.quests);
      final box = tester.getRect(_moreTag);
      expect(box.height, greaterThanOrEqualTo(44));
      expect(box.width, greaterThanOrEqualTo(44));
      expect(find.bySemanticsLabel('2 more goals'), findsOneWidget);
      final four = _wall(count: 4);
      await _pump(tester, state: four.state, quests: four.quests);
      expect(find.bySemanticsLabel('1 more goal'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('it stays clear of the labels, the sign and the card at 100% '
        'on 393 and 320 wide', (tester) async {
      for (final size in const [Size(393, 852), Size(320, 693)]) {
        final w = _wall(count: 5);
        await _pump(tester, state: w.state, quests: w.quests, size: size);
        // At 320 wide the card is taller (its words wrap), so only the wall
        // is checked there; the card's own reach is a separate limit.
        _expectTagClear(
          tester,
          w.state,
          width: size.width,
          card: size.width > 350,
        );
        expect(tester.takeException(), isNull);
      }
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('it stays clear of every label at ${(scale * 100).round()}% '
          'text', (tester) async {
        for (final size in const [Size(393, 852), Size(320, 568)]) {
          final w = _wall(count: 5);
          await _pump(
            tester,
            state: w.state,
            quests: w.quests,
            size: size,
            textScale: scale,
          );
          await revealOnGoalsPage(tester, _moreTag);
          _expectTagClear(tester, w.state, width: size.width);
          final tag = tester.getRect(_moreTag);
          expect(tag.height, greaterThanOrEqualTo(44));
          // It follows the last label in the page's flow, before the card.
          final card = tester.getRect(_card);
          expect(tag.bottom, lessThanOrEqualTo(card.top + 0.5));
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets('pressing it unrolls MORE at Other goals', (tester) async {
      final w = _wall(count: 5);
      await _pump(tester, state: w.state, quests: w.quests);
      expect(goalsRoomUnrolled, findsNothing);
      await tester.tap(_moreTag);
      await tester.pumpAndSettle();
      expect(goalsRoomUnrolled, findsOneWidget);
      // Other goals is open and is where the card has scrolled to.
      final card = tester.getRect(find.byKey(const Key('goals-card-scroll')));
      final section = tester.getRect(
        find.byKey(const Key('other-goals-section')),
      );
      expect(section.top, greaterThanOrEqualTo(card.top));
      expect(section.top, lessThan(card.top + 120));
      // Its rows are there; the first is in view (the card scrolls for the
      // rest).
      for (final title in const [
        'computer architecture',
        'summer 2027',
        'make the apartment feel calm',
        'build a walking habit',
      ]) {
        expect(find.byKey(Key('active-goal-$title')), findsOneWidget);
      }
      final first = tester.getRect(
        find.byKey(const Key('active-goal-computer architecture')),
      );
      expect(first.top, greaterThanOrEqualTo(card.top));
      expect(first.bottom, lessThanOrEqualTo(card.bottom + 0.5));
      expect(
        tester
            .state<ScrollableState>(
              find.descendant(
                of: find.byKey(const Key('goals-card-scroll')),
                matching: find.byType(Scrollable),
              ),
            )
            .position
            .pixels,
        greaterThan(0),
      );
    });

    testWidgets('it fades away while MORE is open and returns when MORE '
        'rolls up', (tester) async {
      final w = _wall(count: 5);
      final semantics = tester.ensureSemantics();
      await _pump(tester, state: w.state, quests: w.quests);
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find
                .ancestor(of: _moreTag, matching: find.byType(AnimatedOpacity))
                .first,
          )
          .opacity;
      expect(opacity(), 1);
      expect(find.semantics.byLabel('2 more goals'), findsOneWidget);
      await openGoalsMore(tester);
      // The unrolled card would cover half of it: it has done its work.
      expect(opacity(), 0);
      expect(find.semantics.byLabel('2 more goals'), findsNothing);
      expect(
        tester.widget<Pressable>(_moreTag).enabled,
        isFalse,
        reason: 'not reachable by touch or keyboard while hidden',
      );
      await tester.tap(goalsRoomMore);
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      expect(find.semantics.byLabel('2 more goals'), findsOneWidget);
      expect(tester.widget<Pressable>(_moreTag).enabled, isTrue);
      semantics.dispose();
    });

    testWidgets('a goal chosen from that list becomes the current goal', (
      tester,
    ) async {
      final w = _wall(count: 5);
      await _pump(tester, state: w.state, quests: w.quests);
      await tester.tap(_moreTag);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('active-goal-build a walking habit')),
      );
      await tester.pumpAndSettle();
      expect(_nameOf(tester), 'Build a walking habit');
      // It has taken the last sheet, and the count still says two more.
      expect(_label('Build a walking habit'), findsOneWidget);
      expect(_label('Summer 2027'), findsNothing);
      expect(
        find.descendant(of: _moreTag, matching: find.text('+2')),
        findsOne,
      );
    });

    testWidgets('rolling MORE up and unrolling it again starts with Other '
        'goals closed', (tester) async {
      final w = _wall(count: 5);
      await _pump(tester, state: w.state, quests: w.quests);
      await tester.tap(_moreTag);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('active-goal-summer 2027')), findsOneWidget);
      // The card has scrolled down to Other goals; MORE is at its top.
      await tester.ensureVisible(goalsRoomMore);
      await tester.pumpAndSettle();
      await tester.tap(goalsRoomMore);
      await tester.pumpAndSettle();
      expect(goalsRoomUnrolled, findsNothing);
      await tester.tap(goalsRoomMore);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('active-goal-summer 2027')), findsNothing);
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('at ${(scale * 100).round()}% it brings Other goals into '
          'view', (tester) async {
        final w = _wall(count: 5);
        await _pump(
          tester,
          state: w.state,
          quests: w.quests,
          size: const Size(320, 568),
          textScale: scale,
        );
        await revealOnGoalsPage(tester, _moreTag);
        await tester.tap(_moreTag);
        await tester.pumpAndSettle();
        final section = tester.getRect(
          find.byKey(const Key('other-goals-section')),
        );
        expect(section.top, greaterThanOrEqualTo(0));
        expect(section.top, lessThan(568 * 0.6));
        expect(
          find.byKey(const Key('active-goal-summer 2027')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('under Reduce Motion it goes straight there', (tester) async {
      final w = _wall(count: 5);
      await _pump(
        tester,
        state: w.state,
        quests: w.quests,
        disableAnimations: true,
      );
      await tester.tap(_moreTag);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('active-goal-summer 2027')), findsOneWidget);
      final card = tester.getRect(find.byKey(const Key('goals-card-scroll')));
      expect(
        tester.getRect(find.byKey(const Key('other-goals-section'))).top,
        lessThan(card.top + 120),
      );
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
    testWidgets('MORE opens at once', (tester) async {
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

    testWidgets('the swap is a fade only: the card does not ease its height', (
      tester,
    ) async {
      final w = _wall();
      await _pump(
        tester,
        state: w.state,
        quests: w.quests,
        disableAnimations: true,
      );
      expect(
        find.descendant(of: _card, matching: find.byType(AnimatedSize)),
        findsNothing,
      );
      await tester.tap(_label('Computer Architecture'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 45));
      expect(_opacity(tester, 'room of days'), inExclusiveRange(0.0, 1.0));
      expect(_opacity(tester, 'computer architecture'), lessThan(0.05));
      await tester.pumpAndSettle();
      expect(find.byKey(_face('room of days')), findsNothing);
      expect(_nameOf(tester), 'Computer Architecture');
    });

    testWidgets('the goal page arrives with a short fade', (tester) async {
      final w = _wall();
      await _pump(
        tester,
        state: w.state,
        quests: w.quests,
        disableAnimations: true,
      );
      await tester.tap(_label('Room of Days'));
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
      expect(find.bySemanticsLabel('Open goal, Room of Days'), findsOneWidget);
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
      await tester.tap(_label('Room of Days'));
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
