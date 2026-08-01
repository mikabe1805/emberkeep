import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/day_planning.dart';
import 'package:emberkeep/content/embers.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/quest_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Quest _quest(String title, int difficulty, {bool dread = false}) => Quest(
  title: title,
  stat: Stat.foc,
  difficulty: difficulty,
  dread: dread,
  custom: true,
  schedule: QuestSchedule.daily,
);

Widget _board(GameState state, List<Quest> quests) => MaterialApp(
  home: Scaffold(
    body: QuestsPage(
      state: state,
      quests: quests,
      onRefresh: () => 0,
      onPersist: () {},
      onAdd: (q) {
        quests.add(q);
        return true;
      },
      onRemove: quests.remove,
      onSnapshot: () => '{}',
      onRestore: (_) {},
    ),
  ),
);

void _quietOtherMantelCards(GameState state, DateTime now) {
  final today = Days.key(now);
  state
    ..onboarded = true
    ..totalCompletions = 12
    ..morningDoneDay = today
    ..weekRecapSeenWeek = Days.key(Days.weekStart(now))
    ..emberSeenDay = today
    ..sparkSeenDay = today;
}

void main() {
  setUp(() => Sfx.instance.soundEnabled = false);
  tearDown(() {
    Sfx.instance.soundEnabled = true;
    Clock.reset();
  });

  test('dated MAIN choices lead only the intended morning and round-trip', () {
    final quest = _quest('Draft the opening', 4)..priorityDay = '2026-07-29';

    expect(quest.priorityOn(DateTime(2026, 7, 28)), isFalse);
    expect(quest.priorityOn(DateTime(2026, 7, 29)), isTrue);
    expect(Quest.fromJson(quest.toJson()).priorityDay, equals('2026-07-29'));
  });

  test('Gentle Mode suggestion caps a crowded custom board at three', () {
    final now = DateTime(2026, 7, 28, 10);
    final quests = [
      _quest('Tiny first step', 1),
      _quest('Easy reply', 2),
      _quest('Small reset', 2),
      _quest('Hard draft', 8),
      _quest('Dreaded call', 3, dread: true),
      _quest('Another project', 6),
    ];

    final planned = planningQuestsForDay(quests, now);
    final chosen = suggestedLowFlameQuests(planned, now);

    expect(chosen, hasLength(3));
    expect(chosen.map((q) => q.title), [
      'Tiny first step',
      'Easy reply',
      'Small reset',
    ]);
  });

  testWidgets('choosing Gentle Mode visibly shelters a veteran board', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    final now = DateTime(2026, 7, 28, 10);
    Clock.freeze(now);
    final state = GameState()..reduceMotion = true;
    _quietOtherMantelCards(state, now);
    state.energyWeatherDay = null;
    final quests = [
      for (var i = 1; i <= 10; i++) _quest('Custom quest $i', i.clamp(1, 8)),
    ];

    await tester.pumpWidget(_board(state, quests));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.text('ENERGY WEATHER'),
      360,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('ENERGY WEATHER'), findsOneWidget);

    await tester.tap(find.text('GENTLE MODE'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(state.lowFlameQuestTitles, hasLength(3));
    expect(find.text('GENTLE MODE SHELTER'), findsOneWidget);
    expect(find.byType(QuestCard), findsNWidgets(3));
    expect(find.textContaining('7 resting'), findsOneWidget);

    await tester.ensureVisible(find.text('SHOW ALL'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('SHOW ALL'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, -1800),
      2400,
    );
    await tester.pumpAndSettle();
    expect(find.text('GENTLE MODE · FULL BOARD'), findsOneWidget);
    expect(state.lowFlameQuestTitles, hasLength(3));

    await tester.tap(find.text('RETURN TO 3'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(QuestCard), findsNWidgets(3));
  });

  testWidgets('quests climb over the fixed room through the blur layer', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    final now = DateTime(2026, 7, 29, 10);
    Clock.freeze(now);
    final state = GameState()..reduceMotion = true;
    _quietOtherMantelCards(state, now);
    state.energyWeatherDay = Days.key(now);
    final quests = [
      for (var i = 1; i <= 8; i++) _quest('Quest $i', i.clamp(1, 8)),
    ];

    await tester.pumpWidget(_board(state, quests));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('MARK COMPLETE'), findsOneWidget);
    // At rest there is no blur to gather, so the filter layer is not mounted
    // at all — the room is simply the room. It appears as the board scrolls.
    expect(find.byKey(const ValueKey('quest-backdrop-blur')), findsNothing);
    final board = tester.widget<NestedScrollView>(
      find.byKey(const ValueKey('quest-board-scroll')),
    );
    expect(board.controller!.offset, 0);

    await tester.drag(
      find.byKey(const ValueKey('quest-board-scroll')),
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();

    expect(board.controller!.offset, greaterThan(180));
    expect(find.byKey(const ValueKey('quest-backdrop-blur')), findsOneWidget);
    expect(find.text('Quest 1'), findsWidgets);

    // A downward pull from the list must hand the gesture back to the outer
    // room header. On mobile web this used to strand the board in its
    // collapsed position, leaving only a thin strip of the authored room even
    // after the user had reached the first quest.
    await tester.drag(
      find.byKey(const ValueKey('quest-board-scroll')),
      const Offset(0, 900),
    );
    await tester.pumpAndSettle();

    expect(board.controller!.offset, 0);
    expect(find.byKey(const ValueKey('quest-backdrop-blur')), findsNothing);
  });

  testWidgets('planning Ember opens a real two-step tomorrow chooser', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    var day = DateTime(2026, 1, 1, 10);
    while (emberOfDay(day).title != planTomorrowEmber) {
      day = day.add(const Duration(days: 1));
    }
    Clock.freeze(day);
    final state = GameState()..reduceMotion = true;
    _quietOtherMantelCards(state, day);
    state
      ..energyWeather = EnergyWeather.steady
      ..energyWeatherDay = Days.key(day)
      ..emberSeenDay = null;
    final quests = [
      _quest('Lead with this', 3),
      _quest('Then this', 2),
      _quest('And this', 4),
      _quest('Can wait', 7),
    ];

    await tester.pumpWidget(_board(state, quests));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(planTomorrowEmber), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('PLAN'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.text('PLAN'));
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('Shape tomorrow'), findsOneWidget);

    for (final title in ['Lead with this', 'Then this', 'And this']) {
      final choice = find.byKey(ValueKey('top-three-$title'));
      await tester.ensureVisible(choice);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(choice);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('REVIEW 3 CHOICES'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Your day has a shape'), findsOneWidget);

    await tester.tap(find.text('SET TOMORROW’S THREE'));
    await tester.pump(const Duration(milliseconds: 450));

    final tomorrowKey = Days.key(day.add(const Duration(days: 1)));
    expect(
      quests.where((q) => q.priorityDay == tomorrowKey).map((q) => q.title),
      ['Lead with this', 'Then this', 'And this'],
    );
    expect(state.emberSeenDay, Days.key(day));
  });
}
