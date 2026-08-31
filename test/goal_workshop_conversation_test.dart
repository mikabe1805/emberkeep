import 'package:emberkeep/audio.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/goal_workshop.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> _pumpWorkshop(
  WidgetTester tester, {
  required GameState state,
  required List<Quest> quests,
  VoidCallback? onPersist,
  ValueChanged<Goal>? onBuildRoute,
  Size size = const Size(430, 932),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: GoalWorkshopScreen(
        state: state,
        quests: quests,
        onPersist: onPersist,
        onOpenGoal: (_) async {},
        onBuildRoute: (goal) async => onBuildRoute?.call(goal),
        onFocusGoal: (_) {},
        onNewGoal: () async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => Sfx.instance.soundEnabled = false);
  tearDown(() => Sfx.instance.soundEnabled = true);

  testWidgets(
    'Talk with the Steward starts the optional scene; partial scenes resume clearly',
    (tester) async {
      final state = GameState()..reduceMotion = true;
      var persisted = 0;
      await _pumpWorkshop(
        tester,
        state: state,
        quests: const [],
        onPersist: () => persisted++,
      );

      expect(find.byKey(const Key('steward-hidden-card')), findsOneWidget);
      expect(find.byKey(const Key('goal-workshop-talk')), findsNothing);
      expect(find.bySemanticsLabel('Talk with the Steward'), findsOneWidget);
      expect(find.textContaining('Unfiled'), findsNothing);
      expect(
        find.textContaining('By file box', findRichText: true),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('steward-hidden-card')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steward-encounter')), findsOneWidget);
      expect(state.stewardMemory.discovered, isTrue);

      await tester.tap(find.byKey(const Key('steward-leave')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('goal-workshop-talk')), findsOneWidget);
      expect(find.byKey(const Key('steward-hidden-card')), findsNothing);
      expect(find.text('Continue talking'), findsOneWidget);
      expect(persisted, greaterThanOrEqualTo(1));

      await tester.tap(find.byKey(const Key('goal-workshop-talk')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('steward-encounter')), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('steward-text-soup-hello')),
        findsOneWidget,
      );
    },
  );

  testWidgets('a completed soup note revisits from Talk with the Steward', (
    tester,
  ) async {
    final state = GameState()
      ..stewardMemory.discovered = true
      ..stewardMemory.completed = true
      ..stewardMemory.choices['soup-note'] = 'friends';
    await _pumpWorkshop(tester, state: state, quests: const []);
    expect(find.byKey(const Key('goal-workshop-talk')), findsOneWidget);
    expect(find.text('Talk with the Steward'), findsOneWidget);
    expect(find.textContaining('Unfiled'), findsNothing);
    expect(
      find.textContaining('By file box', findRichText: true),
      findsNothing,
    );
  });

  testWidgets(
    'a populated workshop preserves routes and opens its exact goal once',
    (tester) async {
      final state = GameState()..reduceMotion = true;
      final goal = Goal(title: 'Build the cabinet', stat: Stat.foc, target: 3);
      state.goals.add(goal);
      final quests = <Quest>[
        Quest(title: 'Keep this Quest', stat: Stat.dis, difficulty: 1),
      ];
      final before = Map<String, dynamic>.from(state.toJson())
        ..remove('stewardMemory');
      final questsBefore = [for (final quest in quests) quest.toJson()];
      var opened = 0;
      await _pumpWorkshop(
        tester,
        state: state,
        quests: quests,
        onBuildRoute: (openedGoal) {
          expect(openedGoal, same(goal));
          opened++;
        },
      );
      await tester.tap(find.byKey(const Key('steward-hidden-card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('steward-leave')));
      await tester.pumpAndSettle();
      expect(
        Map<String, dynamic>.from(state.toJson())..remove('stewardMemory'),
        before,
      );
      expect([for (final quest in quests) quest.toJson()], questsBefore);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('goal-workshop-home-goal-Build the cabinet'),
        ),
      );
      await tester.pumpAndSettle();
      expect(opened, 1);
    },
  );

  for (final scale in const [1.5, 2.0]) {
    testWidgets(
      'compact $scale x discovery and workshop footer remain reachable',
      (tester) async {
        final state = GameState()..reduceMotion = true;
        await _pumpWorkshop(
          tester,
          state: state,
          quests: const [],
          size: const Size(320, 568),
          textScale: scale,
        );
        final card = find.byKey(const Key('steward-hidden-card'));
        expect(card.hitTestable(), findsOneWidget);
        expect(tester.getSize(card).height, greaterThanOrEqualTo(48));
        await tester.tap(card);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('steward-leave')));
        await tester.pumpAndSettle();
        final talk = find.byKey(const Key('goal-workshop-talk'));
        expect(talk.hitTestable(), findsOneWidget);
        expect(tester.getSize(talk).height, greaterThanOrEqualTo(44));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
