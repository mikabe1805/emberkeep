import 'package:emberkeep/audio.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/screens/momentum_kits.dart';
import 'package:emberkeep/screens/room_guide.dart';
import 'package:emberkeep/widgets/onboarding_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const _capture = bool.fromEnvironment('CAPTURE_GOLDENS');

Future<void> _loadFonts() async {
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
    ..addFont(rootBundle.load('assets/google_fonts/JetBrainsMono-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/google_fonts/JetBrainsMono-Bold.ttf'));
  await Future.wait([icons.load(), fraunces.load(), inter.load(), mono.load()]);
  GoogleFonts.config.allowRuntimeFetching = false;
}

Widget _guide({ValueChanged<int>? onSelectTab}) {
  final state = GameState()
    ..onboarded = true
    ..reduceMotion = true
    ..soundEnabled = false;
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RoomGuideScreen(
      state: state,
      onAddQuest: (_) => true,
      onPersist: () {},
      onSelectTab: onSelectTab ?? (_) {},
    ),
  );
}

Widget _guideOverShell({required ValueChanged<int> onSelectTab}) {
  final state = GameState()
    ..onboarded = true
    ..reduceMotion = true
    ..soundEnabled = false;
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    initialRoute: '/guide',
    routes: {
      '/': (_) => const Scaffold(body: Center(child: Text('SHELL'))),
      '/guide': (_) => RoomGuideScreen(
        state: state,
        onAddQuest: (_) => true,
        onPersist: () {},
        onSelectTab: onSelectTab,
      ),
    },
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  setUp(() => Sfx.instance.soundEnabled = false);
  tearDown(() => Sfx.instance.soundEnabled = true);

  testWidgets('onboarding names situational help and can open the guide', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = GameState()..reduceMotion = true;
    bool? openedGuide;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: OnboardingFlow(
          state: state,
          onFinish:
              ({
                required forgeFirstGoal,
                required openGuide,
                required timeShape,
              }) {
                openedGuide = openGuide;
              },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('ENTER ROOM OF DAYS'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('skip for now'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('CONTINUE').last);
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('HELP FOR TODAY'), findsOneWidget);
    expect(find.textContaining('messy room'), findsOneWidget);
    expect(find.text('open the room guide'), findsOneWidget);

    await tester.tap(find.text('open the room guide'));
    expect(openedGuide, isTrue);
    expect(state.onboarded, isTrue);
  });

  testWidgets('guide opens the exact hidden help surface', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_guide());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Help for Today'), findsOneWidget);
    expect(find.textContaining('messy room'), findsOneWidget);
    expect(find.textContaining('GUIDED HOME RESET'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('room-guide-help-today')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MomentumKitsPage), findsOneWidget);
    expect(find.text('Guided Home Reset'), findsOneWidget);
    expect(find.text('OVERWHELMED SPACES'), findsOneWidget);
  });

  testWidgets('kit completion unwinds help and guide before opening Quests', (
    tester,
  ) async {
    var selected = -1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _guideOverShell(onSelectTab: (tab) => selected = tab),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('room-guide-help-today')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.tap(find.text('Guided Home Reset'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('PIN THE RESET PATH'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('OPEN QUESTS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(selected, 1);
    expect(find.byType(MomentumKitsPage), findsNothing);
    expect(find.byType(RoomGuideScreen), findsNothing);
    expect(find.text('SHELL'), findsOneWidget);
  });

  testWidgets('guide doors move to the requested primary room', (tester) async {
    var selected = -1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_guide(onSelectTab: (tab) => selected = tab));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('Quests'));
    await tester.pump();
    expect(selected, 1);
  });

  testWidgets('guide remains usable on a narrow large-text phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(_guide());
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Start with one Quest.'), findsOneWidget);

    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/room_guide_narrow_320x568_text_2x.png'),
      );
    }

    await tester.scrollUntilVisible(
      find.text('Me'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.takeException(), isNull);
    final meDoor = find.ancestor(
      of: find.text('Me'),
      matching: find.byType(GestureDetector),
    );
    expect(meDoor.hitTestable(), findsOneWidget);
    final closingGuidance = find.textContaining(
      'You never need to use everything.',
    );
    await tester.scrollUntilVisible(
      closingGuidance,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 180));
    expect(closingGuidance, findsOneWidget);
    expect(tester.takeException(), isNull);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/room_guide_narrow_scrolled_320x568_text_2x.png',
        ),
      );
    }
  });

  testWidgets('room guide visual target', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(_guide());
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(tester.takeException(), isNull);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/room_guide_430x932.png'),
      );
      await tester.scrollUntilVisible(
        find.text('Me'),
        420,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 180));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/room_guide_scrolled_430x932.png'),
      );
    }
  });
}
