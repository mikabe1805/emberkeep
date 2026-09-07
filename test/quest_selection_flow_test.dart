import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/quest_card.dart';
import 'package:emberkeep/widgets/timer_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpBoard(
  WidgetTester tester, {
  required GameState state,
  required List<Quest> quests,
}) async {
  state.reduceMotion = true;
  state.rollover(quests);
  state.setEnergyWeather(EnergyWeather.steady);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: QuestsPage(
          state: state,
          quests: quests,
          onRefresh: () => 0,
          onPersist: () {},
          onAdd: (_) => false,
          onRemove: (_) {},
          onSnapshot: () => 'pre-completion-snapshot',
          onRestore: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
}

Finder _card(Quest quest) => find.byKey(ValueKey('card-${quest.title}'));

Finder _actionIn(Quest quest) => find.descendant(
  of: _card(quest),
  matching: find.byKey(const ValueKey('quest-primary-action')),
);

bool _accessibilityTraversalContains(WidgetTester tester, String label) =>
    tester.semantics.simulatedAccessibilityTraversal().any(
      (node) => node.getSemanticsData().label.contains(label),
    );

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    260,
    scrollable: find
        .descendant(
          of: find.byType(QuestsPage),
          matching: find.byType(Scrollable),
        )
        .last,
  );
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Clock.freeze(DateTime(2026, 9, 5, 13));
    Sfx.instance.soundEnabled = false;
  });

  tearDown(() {
    Clock.reset();
    Sfx.instance.soundEnabled = true;
  });

  testWidgets(
    'a compact row selects its exact Quest and only its named action completes',
    (tester) async {
      final state = GameState();
      final first = Quest(
        title: 'Clear one surface',
        stat: Stat.dis,
        difficulty: 2,
      );
      final second = Quest(
        title: 'Read ten pages',
        stat: Stat.intl,
        difficulty: 3,
      );
      await _pumpBoard(tester, state: state, quests: [first, second]);

      expect(_actionIn(first), findsOneWidget);
      expect(_actionIn(second), findsNothing);
      await _show(tester, _card(second));
      await tester.tap(_card(second));
      await tester.pump(const Duration(milliseconds: 350));

      expect(first.doneFor(Clock.now()), isFalse);
      expect(second.doneFor(Clock.now()), isFalse);
      expect(state.totalXp, 0);
      expect(_actionIn(first), findsNothing);
      expect(_actionIn(second), findsOneWidget);
      await tester.tap(_actionIn(second));
      await tester.pump();
      expect(first.doneFor(Clock.now()), isFalse);
      expect(second.doneFor(Clock.now()), isTrue);
      expect(
        find.descendant(
          of: _card(second),
          matching: find.text('QUEST COMPLETE'),
        ),
        findsOneWidget,
      );
      expect(_actionIn(first), findsNothing);

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('dragging a compact row neither selects nor completes it', (
    tester,
  ) async {
    final state = GameState();
    final first = Quest(title: 'First', stat: Stat.foc, difficulty: 2);
    final second = Quest(title: 'Second', stat: Stat.soc, difficulty: 2);
    await _pumpBoard(tester, state: state, quests: [first, second]);
    await _show(tester, _card(second));

    final gesture = await tester.startGesture(tester.getCenter(_card(second)));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -48));
    await tester.pump(const Duration(milliseconds: 180));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 350));

    expect(first.doneFor(Clock.now()), isFalse);
    expect(second.doneFor(Clock.now()), isFalse);
    expect(_actionIn(first), findsOneWidget);
    expect(_actionIn(second), findsNothing);
    expect(state.totalXp, 0);
  });

  testWidgets('the explicit action guards a repeated activation', (
    tester,
  ) async {
    final state = GameState();
    final quest = Quest(title: 'One real clear', stat: Stat.foc, difficulty: 3);
    await _pumpBoard(tester, state: state, quests: [quest]);
    final expectedXp = state.xpPreview(quest);

    final action = _actionIn(quest);
    await tester.tap(action, warnIfMissed: false);
    await tester.tap(action, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(quest.doneFor(Clock.now()), isTrue);
    expect(state.totalXp, expectedXp);

    await tester.pump(const Duration(seconds: 8));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('featured actions name the path they actually open', (
    tester,
  ) async {
    Future<void> expectLabel(Quest quest, String label) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 390,
                child: QuestCardForTest(quest: quest),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(label), findsOneWidget);
    }

    await expectLabel(
      Quest(
        title: 'Write one line',
        stat: Stat.intl,
        difficulty: 1,
        journalPrompt: const JournalQuestPrompt(starter: '', hint: ''),
      ),
      'OPEN JOURNAL',
    );
    await expectLabel(
      Quest(
        title: 'Guided strength',
        stat: Stat.str,
        difficulty: 3,
        workout: true,
      ),
      'BEGIN SESSION',
    );
    await expectLabel(
      Quest(
        title: 'Focus proof',
        stat: Stat.foc,
        difficulty: 3,
        verification: Verification.timer,
        timerMinutes: 12,
      ),
      'Open 12-minute session',
    );
    await expectLabel(
      Quest(
        title: 'No sugar today',
        stat: Stat.vit,
        difficulty: 3,
        allDay: true,
      ),
      'CHECK TONIGHT',
    );
  });

  testWidgets('timer action opens Ready and honor follows the base path', (
    tester,
  ) async {
    final state = GameState();
    final quest = Quest(
      title: 'Focus proof',
      stat: Stat.foc,
      difficulty: 3,
      verification: Verification.timer,
      timerMinutes: 12,
    );
    await _pumpBoard(tester, state: state, quests: [quest]);
    final baseXp = state.xpPreview(quest);

    await tester.tap(_actionIn(quest));
    await tester.pump();

    expect(find.byKey(const Key('timer-status')), findsOneWidget);
    expect(find.text('READY'), findsOneWidget);
    expect(find.text('Start 12 minutes'), findsOneWidget);
    expect(find.byKey(const Key('timer-honor')), findsOneWidget);
    expect(quest.doneFor(Clock.now()), isFalse);

    final honor = find.byKey(const Key('timer-honor'));
    await tester.ensureVisible(honor);
    await tester.pump();
    await tester.tap(honor);
    await tester.pump();
    expect(quest.doneFor(Clock.now()), isTrue);
    await tester.pump(const Duration(milliseconds: 600));
    expect(state.totalXp, baseXp);
    expect(state.verifiedCompletions, 0);

    await tester.pump(const Duration(seconds: 8));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'timer is a semantic and keyboard modal until cancel returns to Quests',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final state = GameState();
      final quest = Quest(
        title: 'Focus proof',
        stat: Stat.foc,
        difficulty: 3,
        verification: Verification.timer,
        timerMinutes: 12,
      );
      await _pumpBoard(tester, state: state, quests: [quest]);

      expect(
        _accessibilityTraversalContains(tester, 'Open 12-minute session'),
        isTrue,
      );
      await tester.tap(_actionIn(quest));
      await tester.pump();

      expect(find.byType(TimerOverlay), findsOneWidget);
      expect(
        _accessibilityTraversalContains(tester, 'Open 12-minute session'),
        isFalse,
      );
      expect(_accessibilityTraversalContains(tester, 'Back to Quests'), isTrue);

      for (var i = 0; i < 8; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focusedContext = FocusManager.instance.primaryFocus?.context;
        expect(focusedContext, isNotNull);
        expect(
          focusedContext!.findAncestorWidgetOfExactType<TimerOverlay>(),
          isNotNull,
        );
      }

      await tester.ensureVisible(find.byKey(const Key('timer-back')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('timer-back')));
      await tester.pump();

      expect(find.byType(TimerOverlay), findsNothing);
      expect(
        _accessibilityTraversalContains(tester, 'Open 12-minute session'),
        isTrue,
      );
      expect(quest.doneFor(Clock.now()), isFalse);
      semantics.dispose();
    },
  );

  testWidgets('linked Goal identity advances only after the reward commit', (
    tester,
  ) async {
    final state = GameState();
    final goal = Goal(title: 'Read more', stat: Stat.intl, target: 3);
    state.goals.add(goal);
    final quest = Quest(
      title: 'Read ten pages',
      stat: Stat.intl,
      difficulty: 2,
      goalTitle: 'read MORE',
    );
    await _pumpBoard(tester, state: state, quests: [quest]);

    expect(find.text('GOAL · Read more · 0/3'), findsOneWidget);
    await tester.tap(_actionIn(quest));
    await tester.pump();
    expect(goal.progress, 0);
    await tester.pump(const Duration(milliseconds: 600));
    expect(goal.progress, 1);
    expect(find.text('GOAL · Read more · 1/3'), findsOneWidget);

    await tester.pump(const Duration(seconds: 8));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('quick reflection keeps its Quest source and settles full undo', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    final state = GameState();
    final quest = Quest(
      title: 'Read ten pages',
      stat: Stat.intl,
      difficulty: 2,
    );
    await _pumpBoard(tester, state: state, quests: [quest]);
    await _show(tester, _actionIn(quest));
    await tester.tap(_actionIn(quest));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byKey(ValueKey('undo-${quest.title}')), findsOneWidget);
    await tester.tap(find.textContaining('KEEP ONE LINE'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byType(TextField),
      'Leaving the book open made returning easy.',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 600));

    expect(state.journal, hasLength(1));
    expect(
      state.journal.single.text,
      'Leaving the book open made returning easy.',
    );
    expect(state.journal.single.sourceQuestKey, quest.title);
    expect(find.byKey(ValueKey('undo-${quest.title}')), findsNothing);
    expect(find.text('ONE LINE KEPT IN JOURNAL'), findsOneWidget);
    expect(find.text('QUEST SETTLED'), findsOneWidget);

    await tester.pump(const Duration(seconds: 8));
    expect(state.journal, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class QuestCardForTest extends StatelessWidget {
  const QuestCardForTest({required this.quest, super.key});

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    return QuestCard(
      quest: quest,
      done: false,
      featured: true,
      xpPreview: 10,
      reduceMotion: true,
      onComplete: (_) {},
      onManage: () {},
    );
  }
}
