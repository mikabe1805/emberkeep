import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/day_planning.dart';
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
  void Function(Quest quest)? onOpenQuest,
  VoidCallback? onOpenQuests,
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
          onOpenQuest: onOpenQuest ?? (_) {},
          onOpenQuests: onOpenQuests,
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

    final choose = find.byKey(const Key('goals-today-field-action'));
    expect(choose, findsOneWidget);
    await tester.tap(choose);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(persistCount, 0);
    expect(quests.every((quest) => quest.priorityDay == null), isTrue);

    await tester.tap(choose);
    await tester.pumpAndSettle();

    // Nothing to suggest: the chooser lists every available Quest directly.
    expect(find.text('ALL AVAILABLE QUESTS'), findsOneWidget);
    expect(find.textContaining('Browse all quests'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('top-three-Read ten pages')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('top-three-Clear the desk')));
    await tester.pump();
    final save = find.byKey(const Key('top-three-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(persistCount, 1);
    expect(quests[1].priorityDay, Days.key(today));
    expect(quests[1].priorityRank, 1);
    expect(quests[2].priorityDay, Days.key(today));
    expect(quests[2].priorityRank, 2);
    expect(quests[0].priorityDay, isNull);
    expect(find.text('Today’s three · 2'), findsOneWidget);
    expect(find.byKey(const Key('goals-today-field')), findsNothing);
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
    applyDailyField(quests, today, {'Name three good things'});

    await _pumpGoals(
      tester,
      state: state,
      quests: quests,
      onPersist: () {},
      size: const Size(320, 568),
      textScale: 1.5,
    );
    final choose = find.byKey(const Key('goals-today-field-header'));
    expect(choose, findsOneWidget);
    expect(tester.getCenter(choose).dy, lessThan(568));
    expect(tester.getSize(choose).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(choose).height, greaterThanOrEqualTo(44));
    final workshop = find.byKey(const Key('goals-open-workshop'));
    expect(tester.getSize(workshop).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(workshop).height, greaterThanOrEqualTo(44));
    expect(selectedDailyFieldForDay(quests, today), hasLength(1));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Review today’s three, 1 selected',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Today’s field opens only the exact available Quest', (
    tester,
  ) async {
    final today = DateTime(2026, 8, 30, 10);
    Clock.freeze(today);
    final state = GameState()..reduceMotion = true;
    final open = Quest(title: 'Read ten pages', stat: Stat.intl, difficulty: 2);
    final done = Quest(title: 'Clear the desk', stat: Stat.dis, difficulty: 1);
    final setAside = Quest(title: 'Take a walk', stat: Stat.str, difficulty: 2);
    final quests = <Quest>[open, done, setAside];
    applyDailyField(quests, today, {open.title, done.title, setAside.title});
    done.lastDoneDay = Days.key(today);
    setAside.snoozedDay = Days.key(today);
    final opened = <Quest>[];
    var boardOpens = 0;
    var persistCount = 0;

    await _pumpGoals(
      tester,
      state: state,
      quests: quests,
      onPersist: () => persistCount++,
      onOpenQuest: opened.add,
      onOpenQuests: () => boardOpens++,
    );

    final openRow = find.byKey(
      const ValueKey('goals-today-field-read ten pages'),
    );
    final doneRow = find.byKey(
      const ValueKey('goals-today-field-clear the desk'),
    );
    final setAsideRow = find.byKey(
      const ValueKey('goals-today-field-take a walk'),
    );
    expect(openRow, findsOneWidget);
    expect(doneRow, findsOneWidget);
    expect(setAsideRow, findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Open Read ten pages Quest',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(openRow);
    await tester.tap(openRow);
    await tester.pumpAndSettle();
    expect(opened, hasLength(1));
    expect(identical(opened.single, open), isTrue);
    expect(boardOpens, 0);
    expect(persistCount, 0);

    await tester.ensureVisible(doneRow);
    await tester.tap(doneRow);
    await tester.pumpAndSettle();
    expect(opened, hasLength(1));
    expect(boardOpens, 0);
    expect(persistCount, 0);
    await tester.ensureVisible(setAsideRow);
    await tester.tap(setAsideRow);
    await tester.pumpAndSettle();
    expect(opened, hasLength(1));
    expect(boardOpens, 0);
    expect(persistCount, 0);
    expect(find.text('Set aside today'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Take a walk, set aside today',
      ),
      findsOneWidget,
    );
    expect(find.text('See all quests'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
