import 'package:emberkeep/audio.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/goal_planner.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/top_three_wizard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

final _day = DateTime(2026, 9, 6, 10);

Quest _quest(
  String title, {
  Verification verification = Verification.honor,
  int timerMinutes = 0,
  String? lastDoneDay,
  String? snoozedDay,
  String? goalTitle,
  String? stepId,
  int? revision,
  int? attempt,
}) => Quest(
  title: title,
  stat: Stat.foc,
  difficulty: 3,
  verification: verification,
  timerMinutes: timerMinutes,
  lastDoneDay: lastDoneDay,
  snoozedDay: snoozedDay,
  goalTitle: goalTitle,
  goalPlanStepId: stepId,
  goalPlanRevision: revision,
  goalPlanAttempt: attempt,
);

Future<void> _openChooser(
  WidgetTester tester, {
  required List<Quest> candidates,
  Iterable<String> initialTitles = const [],
  Iterable<Goal> goals = const [],
  void Function(Set<String>? value)? onResult,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            child: const Text('Open chooser'),
            onPressed: () {
              showTopThreeWizard(
                context,
                title: 'Choose today',
                subtitle: 'A calm field',
                dayLabel: 'Today',
                candidates: candidates,
                initialTitles: initialTitles,
                goals: goals,
                day: _day,
              ).then((value) => onResult?.call(value));
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open chooser'));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  final save = find.byKey(const Key('top-three-save'));
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => Sfx.instance.soundEnabled = false);

  testWidgets('cancel is pure: it returns no changed selection', (
    tester,
  ) async {
    final first = _quest(
      'First',
      verification: Verification.timer,
      timerMinutes: 10,
    );
    final second = _quest(
      'Second',
      verification: Verification.timer,
      timerMinutes: 20,
    );
    Set<String>? result = {'sentinel'};

    await _openChooser(
      tester,
      candidates: [first, second],
      initialTitles: const ['First'],
      onResult: (value) => result = value,
    );
    await _tapVisible(tester, find.byKey(const ValueKey('top-three-Second')));
    await _tapVisible(tester, find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(first.priorityDay, isNull);
    expect(second.priorityDay, isNull);
  });

  testWidgets('choosing only returns titles and awards no XP', (tester) async {
    final state = GameState();
    final quest = _quest(
      'Timed focus',
      verification: Verification.timer,
      timerMinutes: 10,
    );
    Set<String>? result;

    await _openChooser(
      tester,
      candidates: [quest],
      onResult: (value) => result = value,
    );
    await tester.tap(find.byKey(const ValueKey('top-three-Timed focus')));
    await tester.pump();
    expect(find.text('Keep this 1'), findsOneWidget);
    await _save(tester);

    expect(result, {'Timed focus'});
    expect(state.xp, 0);
    expect(quest.priorityDay, isNull);
    expect(quest.lastDoneDay, isNull);
  });

  testWidgets('keeps the saved rank instead of source order', (tester) async {
    Set<String>? result;
    await _openChooser(
      tester,
      candidates: [
        _quest(
          'Source first',
          verification: Verification.timer,
          timerMinutes: 5,
        ),
        _quest(
          'Saved first',
          verification: Verification.timer,
          timerMinutes: 10,
        ),
      ],
      initialTitles: const ['Saved first', 'Source first'],
      onResult: (value) => result = value,
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.byKey(const ValueKey('top-three-Saved first')), findsOneWidget);
    await _save(tester);
    expect(result!.toList(), ['Saved first', 'Source first']);
  });

  testWidgets('a session filter leaves chosen work visible', (tester) async {
    await _openChooser(
      tester,
      candidates: [
        _quest('Untimed commitment'),
        _quest(
          'Ten minute session',
          verification: Verification.timer,
          timerMinutes: 10,
        ),
      ],
      initialTitles: const ['Untimed commitment'],
    );

    await _tapVisible(tester, find.text('10 min').first);

    expect(
      find.byKey(const ValueKey('top-three-Untimed commitment')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('top-three-Ten minute session')),
      findsOneWidget,
    );
  });

  testWidgets('the active session-length pill stays silent when retapped', (
    tester,
  ) async {
    final cues = <String>[];
    final sfx = Sfx.instance;
    sfx.debugResetForTesting();
    sfx.debugBypassPlayback = true;
    sfx.debugOnPlay = cues.add;
    addTearDown(sfx.debugResetForTesting);

    await _openChooser(
      tester,
      candidates: [
        _quest('Five', verification: Verification.timer, timerMinutes: 5),
        _quest('Ten', verification: Verification.timer, timerMinutes: 10),
      ],
    );

    await _tapVisible(tester, find.text('Any').first);
    expect(cues, isEmpty);

    await _tapVisible(tester, find.text('10 min').first);
    expect(cues, ['select']);

    await _tapVisible(tester, find.text('10 min').first);
    expect(cues, ['select']);
  });

  testWidgets('a fourth choice does not evict the three already chosen', (
    tester,
  ) async {
    Set<String>? result;
    final quests = [
      _quest('One', verification: Verification.timer, timerMinutes: 5),
      _quest('Two', verification: Verification.timer, timerMinutes: 10),
      _quest('Three', verification: Verification.timer, timerMinutes: 20),
      _quest('Four', verification: Verification.timer, timerMinutes: 20),
    ];
    await _openChooser(
      tester,
      candidates: quests,
      onResult: (value) => result = value,
    );

    for (final title in ['One', 'Two', 'Three', 'Four']) {
      await _tapVisible(tester, find.byKey(ValueKey('top-three-$title')));
    }

    expect(
      find.text('Your three are chosen. Remove one first to make room.'),
      findsOneWidget,
    );
    await _save(tester);
    expect(result!.toList(), ['One', 'Two', 'Three']);
  });

  testWidgets('Browse all exposes an untimed ordinary quest', (tester) async {
    await _openChooser(
      tester,
      candidates: [
        _quest('Untimed ordinary quest'),
        _quest(
          'Known session',
          verification: Verification.timer,
          timerMinutes: 10,
        ),
      ],
    );

    expect(
      find.byKey(const ValueKey('top-three-Untimed ordinary quest')),
      findsNothing,
    );
    await tester.tap(find.text('Browse all quests (2)'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('top-three-Untimed ordinary quest')),
      findsOneWidget,
    );
  });

  testWidgets('suggestions require a configured saved session', (tester) async {
    await _openChooser(
      tester,
      candidates: [
        _quest('Title mentions 10 minutes'),
        _quest('Saved ten', verification: Verification.timer, timerMinutes: 10),
      ],
    );

    expect(
      find.byKey(const ValueKey('top-three-Title mentions 10 minutes')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('top-three-Saved ten')), findsOneWidget);
    expect(find.text('Your saved 10-minute session'), findsOneWidget);
  });

  testWidgets('retains initially chosen done and set-aside work', (
    tester,
  ) async {
    Set<String>? result;
    await _openChooser(
      tester,
      candidates: [
        _quest('Done earlier', lastDoneDay: Days.key(_day)),
        _quest('Set aside', snoozedDay: Days.key(_day)),
        _quest('Available', verification: Verification.timer, timerMinutes: 10),
      ],
      initialTitles: const ['Done earlier', 'Set aside'],
      onResult: (value) => result = value,
    );

    expect(find.text('Done today · kept in your three'), findsOneWidget);
    expect(find.text('Set aside · still chosen'), findsOneWidget);
    await _save(tester);
    expect(result!.toList(), ['Done earlier', 'Set aside']);
  });

  testWidgets('an exact current route action is a suggestion', (tester) async {
    final goal = Goal(
      title: 'Learn sketching',
      stat: Stat.foc,
      target: 6,
      plan: GoalPlanner.fromActions(
        title: 'Learn sketching',
        stat: Stat.foc,
        type: GoalRouteType.skill,
        actions: const ['Sketch a mug'],
        now: _day,
      ),
    );
    final step = goal.plan!.currentStep!;
    await _openChooser(
      tester,
      candidates: [
        _quest(
          'Sketch a mug',
          goalTitle: goal.title,
          stepId: step.id,
          revision: goal.plan!.revision,
          attempt: step.completions + 1,
        ),
      ],
      goals: [goal],
    );

    expect(
      find.byKey(const ValueKey('top-three-Sketch a mug')),
      findsOneWidget,
    );
    expect(find.text('Current action for Learn sketching'), findsOneWidget);
  });
}
