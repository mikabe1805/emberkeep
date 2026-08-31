import 'dart:convert';

import 'package:emberkeep/content/steward_encounter.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/steward_encounter.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/goal_steward.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _SceneLauncher extends StatelessWidget {
  const _SceneLauncher({required this.state, this.onPersist});
  final GameState state;
  final VoidCallback? onPersist;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: const Key('open-steward-scene'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                StewardEncounterScreen(state: state, onPersist: onPersist),
          ),
        ),
        child: const Text('Open'),
      ),
    ),
  );
}

Future<void> _pumpScene(
  WidgetTester tester, {
  required GameState state,
  Size size = const Size(430, 932),
  double textScale = 1,
  bool disableAnimations = true,
  VoidCallback? onPersist,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: _SceneLauncher(state: state, onPersist: onPersist),
    ),
  );
  await tester.tap(find.byKey(const Key('open-steward-scene')));
  await tester.pumpAndSettle();
}

Future<void> _continue(WidgetTester tester) async {
  final action = find.byKey(const Key('steward-continue'));
  await tester.ensureVisible(action);
  await tester.tap(action);
  await tester.pump();
  await tester.pump();
}

Future<void> _reply(WidgetTester tester, String id) async {
  final action = find.byKey(ValueKey<String>('steward-reply-$id'));
  await tester.ensureVisible(action);
  await tester.tap(action);
  await tester.pump();
  await tester.pump();
}

Future<void> _toStance(WidgetTester tester, String openingReply) async {
  await _reply(tester, openingReply);
  await _continue(tester);
  await _continue(tester);
  expect(
    find.byKey(const ValueKey<String>('steward-text-soup-friends')),
    findsOneWidget,
  );
}

Future<void> _finishConversation(
  WidgetTester tester, {
  required String openingReply,
  required String stance,
}) async {
  await _toStance(tester, openingReply);
  await _reply(tester, stance);
  await _continue(tester);
  await _reply(tester, 'knows');
  await _continue(tester);
  await _continue(tester);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test(
    'the soup conversation graph is closed, reachable, and each stance returns',
    () {
      final reached = <String>{};
      void visit(String id) {
        if (!reached.add(id)) return;
        final line = stewardEncounter[id]!;
        if (line.next != null) {
          expect(stewardEncounter, contains(line.next));
          visit(line.next!);
        }
        for (final reply in line.choices) {
          if (reply.next != null) {
            expect(stewardEncounter, contains(reply.next));
            visit(reply.next!);
          }
        }
      }

      visit(stewardFirstLine);
      expect(reached, stewardEncounter.keys.toSet());
      for (final stance in const ['friends', 'agree', 'cook']) {
        expect(
          stewardReturnLine(
            GameState().stewardMemory..choices[stewardChoiceMemoryKey] = stance,
          ).text,
          isNotEmpty,
        );
      }
    },
  );

  testWidgets(
    'the opening explains the cook note and soup before the player chooses',
    (tester) async {
      await _pumpScene(tester, state: GameState());
      final line = tester.widget<Text>(
        find.byKey(const ValueKey<String>('steward-text-soup-hello')),
      );
      expect(line.data, contains('cook'));
      expect(line.data, contains('note'));
      expect(line.data, contains('soup'));
      expect(find.byKey(const Key('steward-continue')), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('steward-reply-ask')),
        findsOneWidget,
      );
      expect(find.textContaining('Unfiled'), findsNothing);
      expect(find.textContaining('file box', findRichText: true), findsNothing);
    },
  );

  for (final path in const [
    ('ask', 'friends', 'soup-friendship', 'You were right about the cook'),
    ('tease', 'agree', 'soup-agreement', 'Good to know someone else'),
    ('ask', 'cook', 'soup-cook-side', 'Still taking the cook’s side'),
  ]) {
    testWidgets('the ${path.$1} / ${path.$2} path saves its exact callback', (
      tester,
    ) async {
      final state = GameState();
      await _pumpScene(tester, state: state);
      await _toStance(tester, path.$1);
      await _reply(tester, path.$2);
      expect(state.stewardMemory.nodeId, path.$3);
      expect(state.stewardMemory.choices[stewardChoiceMemoryKey], path.$2);
      await _continue(tester);
      await _reply(tester, 'knows');
      await _continue(tester);
      await _continue(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-steward-scene')));
      await tester.pumpAndSettle();
      expect(find.textContaining(path.$4), findsOneWidget);
    });
  }

  testWidgets('leaving resumes a deserialized soup line', (tester) async {
    final state = GameState();
    var persisted = 0;
    await _pumpScene(tester, state: state, onPersist: () => persisted++);
    await _reply(tester, 'ask');
    expect(state.stewardMemory.nodeId, 'soup-problem');
    final restored = GameState.fromJson(
      jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpScene(tester, state: restored, onPersist: () => persisted++);
    expect(
      find.byKey(const ValueKey<String>('steward-text-soup-problem')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('steward-leave')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-steward-scene')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('steward-text-soup-problem')),
      findsOneWidget,
    );
    expect(persisted, greaterThanOrEqualTo(2));
  });

  testWidgets(
    'an unknown completed node with current soup memory opens the callback',
    (tester) async {
      final state = GameState()
        ..stewardMemory.completed = true
        ..stewardMemory.nodeId = 'removed-node'
        ..stewardMemory.choices[stewardChoiceMemoryKey] = 'agree';
      await _pumpScene(tester, state: state);
      expect(find.byKey(const Key('steward-replay')), findsOneWidget);
      expect(find.textContaining('Good to know someone else'), findsOneWidget);
    },
  );

  testWidgets('old unpublished fennel memory resets to the new opening', (
    tester,
  ) async {
    final state = GameState()
      ..stewardMemory.completed = true
      ..stewardMemory.nodeId = 'neutrality'
      ..stewardMemory.choices['fennel'] = 'neutral';
    await _pumpScene(tester, state: state);
    expect(state.stewardMemory.completed, isFalse);
    expect(state.stewardMemory.nodeId, stewardFirstLine);
    expect(
      find.byKey(const ValueKey<String>('steward-text-soup-hello')),
      findsOneWidget,
    );
  });

  testWidgets('the encounter changes only its memory', (tester) async {
    final state = GameState();
    final quests = <Quest>[
      Quest(title: 'Keep this untouched', stat: Stat.foc, difficulty: 1),
    ];
    final before = Map<String, dynamic>.from(state.toJson())
      ..remove('stewardMemory');
    final questsBefore = jsonEncode([
      for (final quest in quests) quest.toJson(),
    ]);
    await _pumpScene(tester, state: state);
    await _finishConversation(tester, openingReply: 'tease', stance: 'agree');
    expect(
      Map<String, dynamic>.from(state.toJson())..remove('stewardMemory'),
      before,
    );
    expect(
      jsonEncode([for (final quest in quests) quest.toJson()]),
      questsBefore,
    );
    expect(state.stewardMemory.completed, isTrue);
    expect(state.stewardMemory.choices[stewardChoiceMemoryKey], 'agree');
  });

  testWidgets(
    'same-frame advances cannot skip soup-note and replay keeps history',
    (tester) async {
      final state = GameState()
        ..stewardMemory.discovered = true
        ..stewardMemory.completed = true
        ..stewardMemory.choices[stewardChoiceMemoryKey] = 'cook';
      await _pumpScene(tester, state: state);
      await tester.tap(find.byKey(const Key('steward-replay')));
      await tester.pump();
      expect(state.stewardMemory.completed, isTrue);
      expect(state.stewardMemory.choices[stewardChoiceMemoryKey], 'cook');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      state.stewardMemory.nodeId = 'soup-problem';
      await _pumpScene(tester, state: state);
      final button = find.byKey(const Key('steward-continue'));
      await tester.tap(button);
      await tester.tap(button);
      await tester.pump();
      await tester.pump();
      expect(state.stewardMemory.nodeId, 'soup-note');
      expect(
        find.byKey(const ValueKey<String>('steward-text-soup-note')),
        findsOneWidget,
      );
    },
  );

  for (final scale in const [1.5, 2.0]) {
    testWidgets('compact $scale x scene scrolls every live action into reach', (
      tester,
    ) async {
      await _pumpScene(
        tester,
        state: GameState()..reduceMotion = true,
        size: const Size(320, 568),
        textScale: scale,
      );
      final scroll = find.descendant(
        of: find.byKey(const Key('steward-dialogue-scroll')),
        matching: find.byType(Scrollable),
      );
      expect(scroll, findsOneWidget);
      for (final id in const ['ask', 'tease', 'leave']) {
        final reply = find.byKey(ValueKey<String>('steward-reply-$id'));
        await tester.scrollUntilVisible(reply, 120, scrollable: scroll);
        expect(reply.hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reduced motion remains a labelled live dialogue region', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpScene(tester, state: GameState()..reduceMotion = true);
    final line = tester.getSemantics(find.byKey(const Key('steward-line')));
    expect(line.label, contains('STEWARD'));
    expect(line.label, contains('cook'));
    expect(line.flagsCollection.isLiveRegion, isTrue);
    expect(find.byKey(const Key('steward-leave')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('app and OS reduced motion each reach the steward artwork', (
    tester,
  ) async {
    await _pumpScene(
      tester,
      state: GameState()..reduceMotion = true,
      disableAnimations: false,
    );
    expect(
      tester
          .widget<GoalStewardArtwork>(find.byType(GoalStewardArtwork))
          .reduceMotion,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpScene(tester, state: GameState(), disableAnimations: true);
    expect(
      tester
          .widget<GoalStewardArtwork>(find.byType(GoalStewardArtwork))
          .reduceMotion,
      isTrue,
    );
  });
}
