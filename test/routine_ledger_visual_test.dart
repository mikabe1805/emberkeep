import 'dart:ui' as ui;

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/routine_flows.dart';
import 'package:emberkeep/widgets/routine_ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const _capture = bool.fromEnvironment('CAPTURE_GOLDENS');
final _night = DateTime(2026, 7, 30, 21, 30);
final _morning = DateTime(2026, 7, 31, 7, 45);

Quest _quest(
  String title,
  Stat stat, {
  bool tomorrowMain = false,
  bool allDay = false,
}) => Quest(
  title: title,
  stat: stat,
  difficulty: 3,
  custom: true,
  schedule: QuestSchedule.daily,
  allDay: allDay,
  priorityDay: tomorrowMain ? Days.key(_morning) : null,
);

List<Quest> _quests() => [
  _quest('Draft the chapter', Stat.foc, tomorrowMain: true),
  _quest('Read 20 pages', Stat.intl, tomorrowMain: true),
  _quest('Clear the desk', Stat.dis, tomorrowMain: true),
  _quest('Take a slow walk', Stat.str),
  _quest('Water the plants', Stat.vit),
  _quest('No caffeine after 2pm', Stat.vit, allDay: true),
];

GameState _state() {
  final state = GameState()
    ..playerName = 'Mika'
    ..reduceMotion = true
    ..todayXp = 114
    ..streakDays = 7
    ..bestStreak = 12;
  state.todayStats.addAll({Stat.foc: 7, Stat.intl: 4, Stat.dis: 3});
  state.todayQuestTitles.addAll([
    'Draft the chapter',
    'Read 20 pages',
    'Clear the desk',
    'Take a slow walk',
  ]);
  state.history[Days.key(_night)] = 4;
  return state;
}

Widget _app(Widget child) =>
    MaterialApp(debugShowCheckedModeBanner: false, home: child);

Future<void> _settleArtwork(WidgetTester tester) async {
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(
    () => Future.wait([
      precacheImage(
        const AssetImage('assets/routine/room-night-v1.webp'),
        context,
      ),
      precacheImage(
        const AssetImage('assets/routine/room-morning-v1.webp'),
        context,
      ),
      precacheImage(
        const AssetImage('assets/routine/ledger-night-v2.webp'),
        context,
      ),
      precacheImage(
        const AssetImage('assets/routine/ledger-morning-v2.webp'),
        context,
      ),
      precacheImage(
        const AssetImage('assets/routine/ledger-clasp-v2.webp'),
        context,
      ),
      precacheImage(
        const AssetImage('assets/routine/top-three-tray-v2.webp'),
        context,
      ),
      precacheImage(
        const AssetImage('assets/routine/gilded-section-rule-left-v2.webp'),
        context,
      ),
      precacheImage(
        const AssetImage('assets/routine/gilded-section-rule-right-v2.webp'),
        context,
      ),
      precacheImage(
        const AssetImage('assets/routine/priority-ribbon-plum-v2.webp'),
        context,
      ),
      precacheImage(
        const AssetImage('assets/rooms/quest-fire-a-v3.png'),
        context,
      ),
    ]),
  );
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    final fraunces = FontLoader('Fraunces')
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-Bold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-SemiBold.ttf'));
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Regular.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Medium.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Bold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Italic.ttf'));
    final mono = FontLoader('JetBrainsMono')
      ..addFont(
        rootBundle.load('assets/google_fonts/JetBrainsMono-SemiBold.ttf'),
      );
    final ledger = FontLoader('EBGaramond')
      ..addFont(rootBundle.load('assets/google_fonts/EBGaramond-Variable.ttf'))
      ..addFont(
        rootBundle.load('assets/google_fonts/EBGaramond-Italic-Variable.ttf'),
      );
    await Future.wait([
      icons.load(),
      fraunces.load(),
      inter.load(),
      mono.load(),
      ledger.load(),
    ]);
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    Sfx.instance.soundEnabled = false;
  });

  tearDown(() {
    Clock.reset();
    Sfx.instance.soundEnabled = true;
  });

  testWidgets('routine labels render detailed JetBrains Mono glyphs', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(160, 64));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: boundaryKey,
          child: const ColoredBox(
            color: Colors.white,
            child: Center(
              child: Text(
                'I.I',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 32,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final coverage = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(bytes, isNotNull);
      var darkPixels = 0;
      final data = bytes!.buffer.asUint8List();
      for (var offset = 0; offset < data.length; offset += 4) {
        if (data[offset] < 96 &&
            data[offset + 1] < 96 &&
            data[offset + 2] < 96 &&
            data[offset + 3] > 192) {
          darkPixels++;
        }
      }
      return darkPixels / (image.width * image.height);
    });
    expect(
      coverage,
      lessThan(0.20),
      reason: 'Ahem fallback renders each missing glyph as a solid block.',
    );
    expect(coverage, greaterThan(0.005));
  });

  testWidgets('night ledger visual target', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    Clock.freeze(_night);
    final quests = _quests();

    await tester.pumpWidget(
      _app(
        NightFlow(
          state: _state(),
          quests: quests,
          onAdd: (quest) {
            quests.add(quest);
            return true;
          },
          onPersist: () {},
          onClose: () {},
        ),
      ),
    );
    await _settleArtwork(tester);

    expect(find.text('Close the ledger'), findsOneWidget);
    expect(find.text('+114 XP'), findsOneWidget);
    expect(find.text('MARK TOMORROW'), findsOneWidget);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/routine_ledger_night_430x932.png'),
      );
    }

    await tester.tap(find.text('Draft the chapter').last);
    await tester.pump(const Duration(milliseconds: 520));
    await _settleArtwork(tester);
    expect(find.text('Mark tomorrow'), findsOneWidget);
    expect(find.text('KEEP THREE CLOSE · 3/3'), findsOneWidget);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/routine_ledger_planner_430x932.png'),
      );
    }
  });

  testWidgets('morning ledger visual target and capacity choice', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    Clock.freeze(_morning);
    final state = _state();

    await tester.pumpWidget(
      _app(MorningFlow(state: state, quests: _quests(), onClose: () {})),
    );
    await _settleArtwork(tester);

    expect(find.text('Open the day'), findsOneWidget);
    expect(find.text('Draft the chapter'), findsOneWidget);
    expect(find.text('STEADY'), findsOneWidget);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/routine_ledger_morning_430x932.png'),
      );
    }

    await tester.tap(find.text('LOW'));
    await tester.pump(const Duration(milliseconds: 260));
    expect(state.energyWeather, EnergyWeather.low);
    expect(state.lowFlameQuestTitles, hasLength(3));
    expect(find.text('YOUR GENTLE THREE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('both ledgers survive a narrow large-text phone', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final quests = _quests();
    quests.first = _quest(
      'Finish the unusually long and detailed visual polish pass',
      Stat.foc,
      tomorrowMain: true,
    );

    Clock.freeze(_night);
    await tester.pumpWidget(
      _app(
        NightFlow(
          state: _state(),
          quests: quests,
          onAdd: (_) => true,
          onPersist: () {},
          onClose: () {},
        ),
      ),
    );
    await _settleArtwork(tester);
    expect(
      tester.takeException(),
      isNull,
      reason: 'Night ledger overflowed on a narrow large-text phone.',
    );
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/routine_ledger_night_narrow_320x568_text_2x.png',
        ),
      );
    }
    final nightScroll = find.byKey(const ValueKey('recap'));
    final closeDay = find.text('CLOSE THE DAY');
    await tester.scrollUntilVisible(
      closeDay,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.takeException(), isNull);
    expect(closeDay.hitTestable(), findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(closeDay).didExceedMaxLines,
      isFalse,
      reason: 'The 200% primary action must remain visually readable.',
    );
    expect(
      tester.widget<SingleChildScrollView>(nightScroll).controller!.offset,
      greaterThan(0),
    );
    expect(
      tester
          .renderObject<RenderParagraph>(
            find.text(
              'Finish the unusually long and detailed visual polish pass',
            ),
          )
          .textScaler
          .scale(1),
      2,
      reason: 'The 200% evidence must not cap its compact priority tray.',
    );
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/routine_ledger_night_narrow_scrolled_320x568_text_2x.png',
        ),
      );
    }

    Clock.freeze(_morning);
    await tester.pumpWidget(
      _app(MorningFlow(state: _state(), quests: quests, onClose: () {})),
    );
    await _settleArtwork(tester);
    expect(
      tester.takeException(),
      isNull,
      reason: 'Morning ledger overflowed on a narrow large-text phone.',
    );
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/routine_ledger_morning_narrow_320x568_text_2x.png',
        ),
      );
    }
    final morningScroll = find.byKey(const ValueKey('morning-ledger'));
    final openDay = find.text('OPEN THE DAY');
    await tester.scrollUntilVisible(
      openDay,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.takeException(), isNull);
    expect(openDay.hitTestable(), findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(openDay).didExceedMaxLines,
      isFalse,
      reason: 'The 200% primary action must remain visually readable.',
    );
    expect(
      tester.widget<SingleChildScrollView>(morningScroll).controller!.offset,
      greaterThan(0),
    );
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/routine_ledger_morning_narrow_scrolled_320x568_text_2x.png',
        ),
      );
    }
  });

  testWidgets('projected ledger controls remain tappable at tilt extremes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    final parallax = ValueNotifier(const Offset(0.85, -0.75));
    final light = ValueNotifier(const Offset(-0.8, 0.7));
    final scroll = ValueNotifier(124.0);
    var innerTapped = false;
    var claspTapped = false;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      parallax.dispose();
      light.dispose();
      scroll.dispose();
    });

    await tester.pumpWidget(
      _app(
        Center(
          child: RoutineLedgerPage(
            time: RoutineTime.night,
            parallax: parallax,
            light: light,
            scroll: scroll,
            entrance: const AlwaysStoppedAnimation(1),
            primaryLabel: 'LOCK THE LEDGER',
            onPrimary: () => claspTapped = true,
            child: Center(
              child: TextButton(
                onPressed: () => innerTapped = true,
                child: const Text('INNER ACTION'),
              ),
            ),
          ),
        ),
      ),
    );
    await _settleArtwork(tester);

    await tester.tap(find.text('INNER ACTION'));
    await tester.pump();
    expect(innerTapped, isTrue);

    await tester.tap(find.text('LOCK THE LEDGER'));
    await tester.pump();
    expect(claspTapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a full completion record expands without breaking the folio', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    Clock.freeze(_night);
    final state = _state();
    state.todayQuestTitles
      ..clear()
      ..addAll([
        'Draft the chapter',
        'Read 20 pages',
        'Clear the desk',
        'Take a slow walk',
        'Water the plants',
        'Write tomorrow’s opening line',
        'Stretch for ten minutes',
        'Put the room back in order',
      ]);
    state.history[Days.key(_night)] = state.todayQuestTitles.length;

    await tester.pumpWidget(
      _app(
        NightFlow(
          state: state,
          quests: _quests(),
          onAdd: (_) => true,
          onPersist: () {},
          onClose: () {},
        ),
      ),
    );
    await _settleArtwork(tester);

    expect(find.text('EIGHT THREADS FINISHED'), findsOneWidget);
    expect(find.text('and 5 more!'), findsOneWidget);
    expect(find.text('Take a slow walk'), findsNothing);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/routine_ledger_night_many_collapsed_430x932.png',
        ),
      );
    }

    await tester.tap(find.text('and 5 more!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('all-finished-threads')), findsOneWidget);
    expect(find.text('Take a slow walk'), findsOneWidget);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/routine_ledger_night_many_expanded_430x932.png',
        ),
      );
    }
    await tester.scrollUntilVisible(
      find.text('show fewer'),
      90,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('all-finished-threads')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('show fewer'), findsOneWidget);
    expect(find.text('Put the room back in order'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('night bookmark order becomes the morning begin-here order', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    Clock.freeze(_night);
    final quests = [
      _quest('Draft the chapter', Stat.foc),
      _quest('Read 20 pages', Stat.intl),
      _quest('Clear the desk', Stat.dis),
      _quest('Take a slow walk', Stat.str),
    ];
    var persistCount = 0;

    await tester.pumpWidget(
      _app(
        NightFlow(
          state: _state(),
          quests: quests,
          onAdd: (_) => true,
          onPersist: () => persistCount++,
          onClose: () {},
        ),
      ),
    );
    await _settleArtwork(tester);
    await tester.tap(find.text('MARK TOMORROW'));
    await tester.pump();

    await tester.tap(find.text('Clear the desk'));
    await tester.pump();
    await tester.tap(find.text('Draft the chapter'));
    await tester.pump();
    await tester.tap(find.text('Read 20 pages'));
    await tester.pump();

    expect(quests[2].priorityRank, 1);
    expect(quests[0].priorityRank, 2);
    expect(quests[1].priorityRank, 3);
    expect(persistCount, 3);

    Clock.freeze(_morning);
    await tester.pumpWidget(
      _app(MorningFlow(state: _state(), quests: quests, onClose: () {})),
    );
    await _settleArtwork(tester);

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Begin here, Clear the desk',
      ),
      findsOneWidget,
    );
    final firstTop = tester.getTopLeft(find.text('Clear the desk')).dy;
    final secondTop = tester.getTopLeft(find.text('Draft the chapter')).dy;
    final thirdTop = tester.getTopLeft(find.text('Read 20 pages')).dy;
    expect(firstTop, lessThan(secondTop));
    expect(secondTop, lessThan(thirdTop));
    expect(tester.takeException(), isNull);
  });

  test('priority bookmark rank survives persistence', () {
    final quest = _quest('Draft the chapter', Stat.foc)
      ..priorityDay = Days.key(_morning)
      ..priorityRank = 2;

    final restored = Quest.fromJson(quest.toJson());

    expect(restored.priorityDay, Days.key(_morning));
    expect(restored.priorityRank, 2);
  });
}
