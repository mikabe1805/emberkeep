import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/day_planning.dart';
import 'package:emberkeep/content/embers.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/quest_card.dart';
import 'package:emberkeep/widgets/quest_depth_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _captureQuestScrollAudit = bool.fromEnvironment(
  'CAPTURE_QUEST_SCROLL_AUDIT',
);
const _captureBoundaryKey = ValueKey('capacity-board-capture');

Future<void> _captureBoard(WidgetTester tester, String name) async {
  if (!_captureQuestScrollAudit) return;
  await expectLater(
    find.byKey(_captureBoundaryKey),
    matchesGoldenFile(
      '../design/audits/2026-08-15/quest-scroll-quality/$name.png',
    ),
  );
}

Future<void> _precacheQuestBoardArt(WidgetTester tester) async {
  if (!_captureQuestScrollAudit) return;
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    for (final asset in [
      ...QuestDepthRoom.assets,
      'assets/quest/luminous-honey-gold-v2.webp',
      'assets/quest/category-mind-v2.webp',
    ]) {
      await precacheImage(AssetImage(asset), context);
    }
  });
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Quest _quest(String title, int difficulty, {bool dread = false}) => Quest(
  title: title,
  stat: Stat.foc,
  difficulty: difficulty,
  dread: dread,
  custom: true,
  schedule: QuestSchedule.daily,
);

Widget _board(GameState state, List<Quest> quests) => MaterialApp(
  home: RepaintBoundary(
    key: _captureBoundaryKey,
    child: Scaffold(
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
  setUpAll(() async {
    if (!_captureQuestScrollAudit) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    final fraunces = FontLoader('Fraunces')
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-Bold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-SemiBold.ttf'));
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Regular.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Medium.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-SemiBold.ttf'));
    final mono = FontLoader('JetBrainsMono')
      ..addFont(
        rootBundle.load('assets/google_fonts/JetBrainsMono-SemiBold.ttf'),
      )
      ..addFont(rootBundle.load('assets/google_fonts/JetBrainsMono-Bold.ttf'));
    await Future.wait([
      materialIcons.load(),
      fraunces.load(),
      inter.load(),
      mono.load(),
    ]);
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Sfx.instance.soundEnabled = false;
  });
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

  testWidgets('the room waits for the quest list to reach its top', (
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
      for (var i = 1; i <= 16; i++) _quest('Quest $i', i.clamp(1, 8)),
    ];

    await tester.pumpWidget(_board(state, quests));
    await tester.pump(const Duration(milliseconds: 500));
    await _precacheQuestBoardArt(tester);

    expect(find.text('MARK COMPLETE'), findsOneWidget);
    // At rest there is no blur to gather, so the filter layer is not mounted
    // at all — the room is simply the room. It appears as the board scrolls.
    expect(find.byKey(const ValueKey('quest-backdrop-blur')), findsNothing);
    final board = tester.widget<NestedScrollView>(
      find.byKey(const ValueKey('quest-board-scroll')),
    );
    expect(board.controller!.offset, 0);
    await _captureBoard(tester, '01-room-resting');

    await tester.drag(
      find.byKey(const ValueKey('quest-board-scroll')),
      const Offset(0, -1400),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('quest-board-scroll')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();

    final innerScrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    final innerPosition = tester
        .state<ScrollableState>(innerScrollable)
        .position;
    expect(board.controller!.offset, greaterThan(180));
    expect(innerPosition.pixels, greaterThan(0));
    expect(find.byKey(const ValueKey('quest-backdrop-blur')), findsOneWidget);
    expect(find.byType(QuestCard), findsWidgets);
    await _captureBoard(tester, '02-list-scrolled');

    final collapsedRoomOffset = board.controller!.offset;
    final listOffset = innerPosition.pixels;

    // Reversing direction while there are still quests above must move only
    // the list. The authored room stays parked until the first quest is back.
    await tester.drag(
      find.byKey(const ValueKey('quest-board-scroll')),
      const Offset(0, 120),
    );
    await tester.pumpAndSettle();

    expect(board.controller!.offset, closeTo(collapsedRoomOffset, 1));
    expect(innerPosition.pixels, lessThan(listOffset));
    expect(innerPosition.pixels, greaterThan(0));
    expect(find.byKey(const ValueKey('quest-backdrop-blur')), findsOneWidget);
    await _captureBoard(tester, '03-reverse-list-first');

    // Once the list reaches its true top, the remaining reverse motion may
    // reveal the room and clear the overlap treatment.
    await tester.drag(
      find.byKey(const ValueKey('quest-board-scroll')),
      const Offset(0, 1800),
    );
    await tester.pumpAndSettle();

    expect(innerPosition.pixels, 0);
    expect(board.controller!.offset, 0);
    expect(find.byKey(const ValueKey('quest-backdrop-blur')), findsNothing);
    await _captureBoard(tester, '04-room-returned-at-top');
  });

  testWidgets('focus mode protects its exit and names both ordering choices', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    final now = DateTime(2026, 7, 29, 10);
    Clock.freeze(now);
    final state = GameState()
      ..reduceMotion = true
      ..focusMode = true;
    _quietOtherMantelCards(state, now);
    final quests = [
      _quest('Small reset', 2),
      _quest('Write the difficult opening', 8, dread: true),
    ];

    await tester.pumpWidget(_board(state, quests));
    await tester.pump(const Duration(milliseconds: 500));
    await _precacheQuestBoardArt(tester);

    final focusList = tester.widget<ListView>(
      find.byKey(const ValueKey('focus-quest-list')),
    );
    expect(focusList.padding, const EdgeInsets.fromLTRB(16, 4, 16, 130));
    expect(find.bySemanticsLabel('Order quests: Ease in'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Order quests: Hardest first'),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('Order quests: Hardest first'));
    await tester.pumpAndSettle();
    expect(find.text('Write the difficult opening'), findsWidgets);

    await tester.drag(
      find.byKey(const ValueKey('quest-board-scroll')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await _captureBoard(tester, '05-focus-short-phone');

    await tester.drag(
      find.byKey(const ValueKey('focus-quest-list')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Show the full quest board'), findsOneWidget);
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
