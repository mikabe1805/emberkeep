import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/weekly_chronicle.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/goal_detail.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/share_moment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Counts read naturally at one: "1 day here", never "1 days here".
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('the share card counts a single quest as one quest', (
    tester,
  ) async {
    final state = GameState()
      ..setPlayerName('Mika')
      ..streakDays = 1
      ..totalCompletions = 1
      ..wallStyle = 'wall_walnut';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              child: MomentCard(state: state, level: 2),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Mika · day 1 · 1 quest kept'), findsOneWidget);
  });

  testWidgets('a goal on its first day reads "1 day here"', (tester) async {
    final today = DateTime(2026, 10, 3, 10);
    Clock.freeze(today);
    addTearDown(Clock.reset);
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final goal = Goal(
      title: 'Read before bed',
      stat: Stat.intl,
      target: 25,
      startedDay: Days.key(today),
    );
    final state = GameState()..goals.add(goal);
    final quests = [
      Quest(
        title: 'Read one page',
        stat: Stat.intl,
        difficulty: 1,
        goalTitle: goal.title,
      ),
    ];
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: GoalDetailScreen(
          goal: goal,
          state: state,
          quests: quests,
          onRemoveGoal: (_) {},
          onPersist: () {},
          onAddQuest: (_) => true,
          onOpenQuest: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('1 day here'), findsOneWidget);
    expect(find.text('1 linked quest'), findsOneWidget);
    expect(find.textContaining('days here'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(r'done today\. 1 linked quest\.')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  test('the weekly chronicle names one extra quest as one', () {
    WeeklyChronicleData chronicle(int delta) => WeeklyChronicleData(
      start: DateTime(2026, 9, 28),
      end: DateTime(2026, 10, 4),
      counts: const [1, 0, 0, 0, 0, 0, 0],
      litDays: 1,
      total: 1,
      delta: delta,
      strongestDomain: null,
    );
    expect(chronicle(1).deltaLine, '1 more quest than the week before');
    expect(chronicle(3).deltaLine, '3 more quests than the week before');
    expect(
      chronicle(1).shareText,
      'I showed up on 1 of 7 days and completed 1 quest this week.',
    );
  });
}
