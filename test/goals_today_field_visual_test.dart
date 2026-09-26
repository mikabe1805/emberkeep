import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/day_planning.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/goals.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const _capture = bool.fromEnvironment('CAPTURE_GOLDENS');

Future<void> _showSelectedField(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  bool withSetAside = false,
}) async {
  tester.view.devicePixelRatio = 1;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.binding.setSurfaceSize(null);
    Clock.reset();
  });
  final today = DateTime(2026, 8, 30, 10);
  Clock.freeze(today);
  final first = Quest(
    title: 'Read ten pages before bed',
    stat: Stat.intl,
    difficulty: 2,
  );
  final second = Quest(
    title: 'Clear the desk for tomorrow',
    stat: Stat.dis,
    difficulty: 1,
  );
  final setAside = Quest(
    title: 'Take a walk after lunch',
    stat: Stat.str,
    difficulty: 2,
  );
  final quests = <Quest>[first, second, if (withSetAside) setAside];
  applyDailyField(quests, today, {
    first.title,
    second.title,
    if (withSetAside) setAside.title,
  });
  second.lastDoneDay = Days.key(today);
  if (withSetAside) setAside.snoozedDay = Days.key(today);
  final state = GameState()
    ..reduceMotion = true
    ..soundEnabled = false;

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Palette.parchment,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Palette.xp,
          brightness: Brightness.dark,
        ),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Inter'),
        useMaterial3: true,
      ),
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
          onAdd: (_) => false,
          onRemoveQuest: (_) {},
          onRemoveGoal: (_) {},
          onPersist: () {},
          onOpenQuest: (_) {},
          onOpenQuests: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/pages/working-room-v1.webp'),
      context,
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.scrollUntilVisible(
    find.text('Today’s three'),
    180,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('goals-threshold-scroll')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await Scrollable.ensureVisible(
    tester.element(find.text('Today’s three')),
    alignment: 0.08,
    duration: Duration.zero,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
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
      );
    final garamond = FontLoader('EBGaramond')
      ..addFont(rootBundle.load('assets/google_fonts/EBGaramond-Variable.ttf'));
    await Future.wait([
      icons.load(),
      fraunces.load(),
      inter.load(),
      mono.load(),
      garamond.load(),
    ]);
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  setUp(() => Sfx.instance.soundEnabled = false);
  tearDown(() => Sfx.instance.soundEnabled = true);

  testWidgets('selected field stays legible on an ordinary phone', (
    tester,
  ) async {
    await _showSelectedField(tester, size: const Size(430, 932), textScale: 1);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goals_selected_field_430x932.png'),
      );
    }
    expect(find.text('Read ten pages before bed'), findsOneWidget);
    expect(find.text('Clear the desk for tomorrow'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected field remains reachable at large text', (tester) async {
    await _showSelectedField(
      tester,
      size: const Size(320, 568),
      textScale: 1.5,
    );
    final first = find.byKey(
      const ValueKey('goals-today-field-read ten pages before bed'),
    );
    await Scrollable.ensureVisible(
      tester.element(first),
      alignment: 0.2,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goals_selected_field_320x568_large.png'),
      );
    }
    expect(tester.getSize(first).height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('set-aside choice stays readable without an open action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _showSelectedField(
      tester,
      size: const Size(430, 932),
      textScale: 1,
      withSetAside: true,
    );
    final setAside = find.byKey(
      const ValueKey('goals-today-field-take a walk after lunch'),
    );
    await Scrollable.ensureVisible(
      tester.element(setAside),
      alignment: 0.65,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goals_selected_field_set_aside_430x932.png'),
      );
    }
    expect(find.text('Set aside today'), findsOneWidget);
    expect(
      tester
          .getSemantics(setAside)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isFalse,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
