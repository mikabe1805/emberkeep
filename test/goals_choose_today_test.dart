import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/goals.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> _pumpGoals(
  WidgetTester tester, {
  required GameState state,
  required List<Quest> quests,
  required VoidCallback onPersist,
  Size size = const Size(430, 932),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
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
          onPersist: onPersist,
          onOpenQuest: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => Sfx.instance.soundEnabled = false);
  tearDown(Clock.reset);

  testWidgets('Goals gives a crowded ordinary day a saved field', (
    tester,
  ) async {
    final today = DateTime(2026, 8, 30, 10);
    Clock.freeze(today);
    final state = GameState()..reduceMotion = true;
    state.goals.add(
      Goal(
        title: 'Keep a journal',
        stat: Stat.intl,
        target: 12,
        openingSeen: true,
      ),
    );
    final quests = <Quest>[
      Quest(title: 'Name three good things', stat: Stat.intl, difficulty: 1),
      Quest(title: 'Read ten pages', stat: Stat.intl, difficulty: 2),
      Quest(title: 'Clear the desk', stat: Stat.dis, difficulty: 3),
      Quest(title: 'Take a walk', stat: Stat.str, difficulty: 3),
    ];
    var persistCount = 0;

    await _pumpGoals(
      tester,
      state: state,
      quests: quests,
      onPersist: () => persistCount++,
    );

    final choose = find.byKey(const Key('goals-field-door'));
    expect(choose, findsOneWidget);
    expect(find.text('Choose up to 3'), findsOneWidget);
    await tester.tap(choose);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('top-three-Read ten pages')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('top-three-Clear the desk')));
    await tester.pump();
    await tester.tap(find.text('REVIEW 2 CHOICES'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('KEEP TODAY’S FIELD'));
    await tester.pumpAndSettle();

    expect(persistCount, 1);
    expect(quests[1].priorityDay, Days.key(today));
    expect(quests[1].priorityRank, 1);
    expect(quests[2].priorityDay, Days.key(today));
    expect(quests[2].priorityRank, 2);
    expect(quests[0].priorityDay, isNull);
    expect(find.text('2 chosen'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('goals-today-field')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('goals-reshape-today')), findsOneWidget);
    expect(find.text('Today has a shape.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('goals-today-field-read ten pages')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('goals-today-field-clear the desk')),
      findsOneWidget,
    );
  });

  testWidgets('Today’s field reflows on a narrow large-text phone', (
    tester,
  ) async {
    final today = DateTime(2026, 8, 30, 10);
    Clock.freeze(today);
    final state = GameState()..reduceMotion = true;
    state.goals.add(
      Goal(
        title: 'Keep a journal',
        stat: Stat.intl,
        target: 12,
        openingSeen: true,
      ),
    );
    final quests = <Quest>[
      Quest(title: 'Name three good things', stat: Stat.intl, difficulty: 1),
    ];

    await _pumpGoals(
      tester,
      state: state,
      quests: quests,
      onPersist: () {},
      size: const Size(320, 568),
      textScale: 1.5,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('goals-today-field')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('Choose what leads today.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
