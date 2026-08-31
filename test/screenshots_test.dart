// A visual harness: renders the code-painted widgets and primary shell
// window scenes, the journal hub) to PNGs via golden files, so I can actually
// SEE what the CustomPainters produce instead of shipping blind. Regenerate:
//   flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true \
//     --dart-define=CAPTURE_STORE=true test/screenshots_test.dart
// then open test/goldens/*.png. Not a pass/fail guard — purely a render dump.
// BOTH flags are needed: CAPTURE_GOLDENS gates the widget dumps, CAPTURE_STORE
// gates the full-screen store_* shots. With only the first, the tests still
// report "All tests passed" while every store_*.png silently stays stale.
// Add CAPTURE_PLAY=true to render the five submission frames again at a native
// 1080×1920 Play Store viewport. Google Play rejects the taller 1290×2796
// iPhone class because its long edge is more than twice its short edge.
// (round-62 pivot: the creature is gone; the keep + its hearth are the star.)
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/cloud.dart';
import 'package:emberkeep/content/creature_skins.dart';
import 'package:emberkeep/content/day_planning.dart';
import 'package:emberkeep/content/furniture.dart';
import 'package:emberkeep/content/release_notes.dart';
import 'package:emberkeep/content/routines.dart';
import 'package:emberkeep/content/space_themes.dart';
import 'package:emberkeep/content/steward_encounter.dart';
import 'package:emberkeep/discovery.dart';
import 'package:emberkeep/widgets/routine_flows.dart';
import 'package:emberkeep/widgets/share_moment_card.dart';
import 'package:emberkeep/widgets/streak_freeze_status.dart';
import 'package:emberkeep/content/room_styles.dart';
import 'package:emberkeep/content/window_scenes.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/goal_planner.dart';
import 'package:emberkeep/main.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/release_notes_preferences.dart';
import 'package:emberkeep/screens/about.dart';
import 'package:emberkeep/screens/discover_spaces.dart';
import 'package:emberkeep/screens/journal_entry.dart';
import 'package:emberkeep/screens/journal_hub.dart';
import 'package:emberkeep/screens/hearth_circle.dart';
import 'package:emberkeep/screens/goals.dart';
import 'package:emberkeep/screens/goal_detail.dart';
import 'package:emberkeep/screens/goal_opening.dart';
import 'package:emberkeep/screens/memory_cabinet.dart';
import 'package:emberkeep/screens/me.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/screens/steward_encounter.dart';
import 'package:emberkeep/screens/visit_room.dart';
import 'package:emberkeep/screens/weekly_chronicle.dart';
import 'package:emberkeep/social.dart';
import 'package:emberkeep/storage.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/constellation.dart';
import 'package:emberkeep/widgets/glass.dart';
import 'package:emberkeep/widgets/home_room.dart';
import 'package:emberkeep/widgets/gold_surface.dart';
import 'package:emberkeep/widgets/luxe_depth.dart';
import 'package:emberkeep/widgets/onboarding_flow.dart';
import 'package:emberkeep/widgets/pressable.dart';
import 'package:emberkeep/widgets/quest_depth_room.dart';
import 'package:emberkeep/widgets/quest_desk.dart';
import 'package:emberkeep/widgets/top_three_wizard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _stage(
  Widget child, {
  Color bg = const Color(0xFF241A20),
  double pad = 28,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Padding(padding: EdgeInsets.all(pad), child: child),
      ),
    ),
  );
}

/// Paints a window scene + frame, for the scene-grid screenshot.
class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scene);
  final String scene;
  @override
  void paint(Canvas canvas, Size size) {
    paintWindowScene(canvas, scene, Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(1),
        const Radius.circular(6),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF5A4536),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _FlamePalettePainter extends CustomPainter {
  const _FlamePalettePainter(this.hue);
  final Color hue;

  @override
  void paint(Canvas canvas, Size size) =>
      paintEmberFlameSwatch(canvas, size, hue);

  @override
  bool shouldRepaint(_FlamePalettePainter old) => old.hue != hue;
}

const _capture = bool.fromEnvironment('CAPTURE_GOLDENS');
const _captureStore = bool.fromEnvironment('CAPTURE_STORE');
const _capturePlay = bool.fromEnvironment('CAPTURE_PLAY');

Future<void> _shoot(WidgetTester tester, Widget w, String name) async {
  await tester.pumpWidget(w);
  // Give asynchronously decoded room textures and the tapestry more than one
  // frame to arrive. A single long pump advances fake time only once and can
  // capture the painter before its image-decoding future schedules a repaint.
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
  if (_capture) {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }
}

/// Decode every routine asset for real before capturing. `Image.asset` resolves
/// through an async codec, and the fake-async test clock never lets that finish
/// — so without this the folio, the clasp and the room all capture as empty
/// black boxes while the layout around them looks perfectly fine.
Future<void> _precacheRoutineArt(WidgetTester tester) async {
  const assets = <String>[
    'assets/routine/ledger-night-v2.webp',
    'assets/routine/ledger-morning-v2.webp',
    'assets/routine/ledger-clasp-v2.webp',
    'assets/routine/begin-here-bookmark-v2.webp',
    'assets/routine/room-night-v1.webp',
    'assets/routine/room-morning-v1.webp',
    'assets/routine/top-three-tray-v2.webp',
    'assets/routine/gilded-section-rule-v2.webp',
    'assets/routine/gilded-section-rule-left-v2.webp',
    'assets/routine/gilded-section-rule-right-v2.webp',
    'assets/routine/priority-ribbon-plum-v2.webp',
    'assets/routine/priority-ribbon-blue-v2.webp',
    'assets/routine/priority-ribbon-umber-v2.webp',
  ];
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    for (final a in assets) {
      await precacheImage(AssetImage(a), context);
    }
  });
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Decode the page and personalized room plates before comparing destinations.
/// Widget-test fake time does not complete image codecs reliably, which made
/// Goals, Plans, and a fresh Journal look like featureless black screens even
/// though production resolves the same bundled assets normally.
Future<void> _precachePageArt(WidgetTester tester) async {
  const assets = <String>[
    'assets/pages/goals-desk-v2.webp',
    'assets/rooms/wall_walnut-fireless-v3.webp',
    'assets/pages/plans-conservatory-v2.webp',
    'assets/pages/journal-archive-v1.webp',
    'assets/pages/journal-desk-v3.webp',
    'assets/pages/journal-page-edge-v1.webp',
    'assets/pages/goals-living-backdrop-v2.webp',
    'assets/pages/goals-room-retreat-v1.webp',
    'assets/pages/goals-threshold-room-v1.webp',
    'assets/pages/goals-room-kitchen-v1.webp',
    'assets/pages/goals-workshop-tavern-back-v2.webp',
    'assets/pages/goals-workshop-tavern-counter-v2.webp',
    'assets/pages/goals-workshop-steward-welcome-v2.webp',
    'assets/pages/goals-workshop-steward-considering-v2.webp',
    'assets/pages/goals-workshop-steward-ready-v2.webp',
    'assets/pages/goals-workshop-steward-acknowledging-v2.webp',
    'assets/pages/goals-workshop-steward-closing-v2.webp',
    'assets/pages/goals-workshop-tavern-steward-v1.webp',
    'assets/pages/steward-supper-room-v2.webp',
    'assets/pages/steward-supper-offering-v2.webp',
    'assets/room/wall_grain.png',
  ];
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    for (final asset in assets) {
      await precacheImage(AssetImage(asset), context);
    }
  });
  await tester.pump(const Duration(milliseconds: 300));
}

/// Decode the lighter chooser thumbnails before a deterministic capture. The
/// full room plates are awaited before the app mounts, because AppShell starts
/// its own production preload and a fake-async test must not inherit that
/// in-flight Future into `runAsync`.
Future<void> _precacheSpaceThemeArt(WidgetTester tester) async {
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    for (final theme in spaceThemes) {
      await precacheImage(AssetImage(theme.previewAsset), context);
    }
  });
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _precacheGoldSurface(WidgetTester tester) async {
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/quest/luminous-honey-gold-v2.webp'),
      context,
    ),
  );
  await tester.pump(const Duration(milliseconds: 120));
}

Future<void> _precacheQuestBoardArt(WidgetTester tester) async {
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    for (final asset in [
      ...QuestDepthRoom.assets,
      'assets/quest/luminous-honey-gold-v2.webp',
      'assets/quest/category-body-v2.webp',
      'assets/quest/category-care-v2.webp',
      'assets/quest/category-mind-v2.webp',
      'assets/quest/category-craft-v2.webp',
      'assets/quest/category-people-v2.webp',
      'assets/quest/category-home-v2.webp',
    ]) {
      await precacheImage(AssetImage(asset), context);
    }
  });
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _storeShot(WidgetTester tester, String name) async {
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
  if (_captureStore) {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/store_$name.png'),
    );
  }
}

Future<void> _storeShotNow(WidgetTester tester, String name) async {
  if (_captureStore) {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/store_$name.png'),
    );
  }
}

/// Reflows the same production state into Google's recommended 9:16 phone
/// class instead of cropping or stretching the accepted Apple capture.
Future<void> _playStoreShot(WidgetTester tester, String name) async {
  if (!_capturePlay) return;
  tester.view.devicePixelRatio = 2.5;
  await tester.binding.setSurfaceSize(const Size(432, 768));
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/play_$name.png'),
  );
  tester.view.devicePixelRatio = 3;
  await tester.binding.setSurfaceSize(const Size(430, 932));
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void _activateDock(WidgetTester tester, IconData icon) {
  final tapTarget = find
      .ancestor(of: find.byIcon(icon), matching: find.byType(Pressable))
      .first;
  tester.widget<Pressable>(tapTarget).onTapUp!.call(Offset.zero);
}

void main() {
  // Load the icon font. Without this the test binding has no MaterialIcons
  // glyphs, so EVERY `Icon` in a screenshot renders as a tofu box — and a
  // dump full of unreadable squares covering the UI is worse than no dump,
  // because it reports a problem the app doesn't have while hiding the real
  // composition underneath. `uses-material-design: true` puts the font in the
  // asset bundle at this path, so the test can load it the same way the app
  // does. (Same lesson as the emberGlow fallback: a golden has to render what
  // ships, not an artefact of the harness.)
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    GameState.debugRandomFactory = () => Random(20260808);
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await loader.load();
    final fraunces = FontLoader('Fraunces')
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-Bold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-SemiBold.ttf'))
      ..addFont(
        rootBundle.load('assets/google_fonts/Fraunces-SemiBoldItalic.ttf'),
      );
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Regular.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Medium.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Bold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Italic.ttf'));
    final mono = FontLoader('JetBrainsMono')
      ..addFont(
        rootBundle.load('assets/google_fonts/JetBrainsMono-SemiBold.ttf'),
      )
      ..addFont(rootBundle.load('assets/google_fonts/JetBrainsMono-Bold.ttf'));
    // The ledger's printed voice (widgets/routine_ledger.dart). It is declared
    // in pubspec fonts: rather than through google_fonts, so it needs loading
    // here like the rest — without it every EB Garamond string in the two daily
    // bookends captured as a solid Ahem block, which makes those goldens look
    // like a layout catastrophe that the shipping app does not have.
    final garamond = FontLoader('EBGaramond')
      ..addFont(rootBundle.load('assets/google_fonts/EBGaramond-Variable.ttf'))
      ..addFont(
        rootBundle.load('assets/google_fonts/EBGaramond-Italic-Variable.ttf'),
      );
    await Future.wait([
      fraunces.load(),
      inter.load(),
      mono.load(),
      garamond.load(),
    ]);
    // Load every complete room in this real-async setup phase. Individual
    // widget tests run on a fake clock; starting a codec there and awaiting it
    // later from runAsync can strand the same Future across two zones.
    await preloadHomeRoomAssets();
    GoogleFonts.config.allowRuntimeFetching = false; // no network in tests
  });
  tearDownAll(() {
    WidgetController.hitTestWarningShouldBeFatal = false;
    GameState.debugRandomFactory = null;
  });

  // A type specimen. Every Type style rendered with letters AND digits, so a
  // font that silently fails to resolve shows up as a row of filled boxes here
  // instead of being discovered by eye in some unrelated screenshot.
  testWidgets('type specimen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(560, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const sample = 'Handgloves +34 XP 0123';
    await _shoot(
      tester,
      _stage(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (name, style) in [
              ('numerals', Type.numerals),
              ('display', Type.display),
              ('body', Type.body),
              ('label', Type.label),
            ]) ...[
              Text(name, style: const TextStyle(color: Color(0xFF94887A))),
              Text(sample, style: style),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
      'type_specimen',
    );
  });

  testWidgets('about screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _shoot(
      tester,
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AboutScreen(reduceMotion: true),
      ),
      'about_screen_430x932',
    );
  });

  testWidgets('about screen iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _shoot(
        tester,
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: AboutScreen(reduceMotion: true),
        ),
        'about_screen_ios_430x932',
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('about screen narrow large text', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AboutScreen(reduceMotion: true),
      ),
    );
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(tester.takeException(), isNull);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/about_screen_narrow_320x568_2x.png'),
      );
    }

    final coffeeAction = find.byKey(const ValueKey('about-send-coffee'));
    final shareAction = find.byKey(const ValueKey('about-share-app'));
    expect(coffeeAction, findsOneWidget);
    expect(shareAction, findsOneWidget);
    await tester.scrollUntilVisible(
      coffeeAction,
      360,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 180));
    expect(coffeeAction.hitTestable(), findsOneWidget);
    await tester.scrollUntilVisible(
      shareAction,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 180));
    expect(shareAction.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);

    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/about_screen_narrow_scrolled_320x568_2x.png',
        ),
      );
    }
  });

  // the KEEP: no creature, the central hearth is the heart — fire LIT (a kept
  // streak) up top, banked to embers below.
  testWidgets('the keep', (tester) async {
    await tester.binding.setSurfaceSize(const Size(560, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const furn = {
      'rug',
      'lamp',
      'plant',
      'shelf',
      'picture',
      'garland',
      'chair',
      'cushion',
      'candles',
      'pet',
    };
    // Pass the REAL default flame hue rather than letting the painter fall
    // back to its own ember. The fallback is a more saturated orange than the
    // shipped Ember skin, so a golden that relies on it flatters the fire and
    // hides what players actually see.
    Widget keep(bool lit) => SizedBox(
      width: 500,
      child: HomeRoom(
        unlocked: furn,
        petAwake: lit,
        emberGlow: flameHueById(null),
      ),
    );
    await _shoot(
      tester,
      _stage(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [keep(true), const SizedBox(height: 16), keep(false)],
        ),
        pad: 16,
      ),
      'the_keep',
    );
  });

  testWidgets('keep: empty vs furnished', (tester) async {
    await tester.binding.setSurfaceSize(const Size(560, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _shoot(
      tester,
      _stage(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 500,
              child: HomeRoom(unlocked: const {}, petAwake: true),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 500,
              child: HomeRoom(
                unlocked: {for (final f in furniture) f.id},
                petAwake: true,
              ),
            ),
          ],
        ),
        pad: 16,
      ),
      'keep_empty_full',
    );
  });

  testWidgets('keep: level-three starter room', (tester) async {
    await tester.binding.setSurfaceSize(const Size(540, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _shoot(
      tester,
      _stage(
        const SizedBox(
          width: 500,
          child: HomeRoom(unlocked: {'rug', 'plant'}, level: 3, petAwake: true),
        ),
        pad: 16,
      ),
      'keep_starter_level3',
    );
  });

  testWidgets('keep: style variants', (tester) async {
    await tester.binding.setSurfaceSize(const Size(520, 940));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const furn = {
      'rug',
      'lamp',
      'plant',
      'shelf',
      'picture',
      'garland',
      'candles',
    };
    Widget keep(List<Color> wall, List<Color> floor) => SizedBox(
      width: 460,
      child: HomeRoom(unlocked: furn, wall: wall, floor: floor, petAwake: true),
    );
    await _shoot(
      tester,
      _stage(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            keep(
              const [Color(0xFF312339), Color(0xFF3E2E48)],
              const [Color(0xFF3C2C20), Color(0xFF2A1D14)],
            ), // plum / oak
            const SizedBox(height: 14),
            keep(
              const [Color(0xFF27302A), Color(0xFF333E36)],
              const [Color(0xFF4A2C1E), Color(0xFF31180E)],
            ), // sage / terra
            const SizedBox(height: 14),
            keep(
              const [Color(0xFF232A3C), Color(0xFF2F3A55)],
              const [Color(0xFF2C1E16), Color(0xFF1C120C)],
            ), // midnight / walnut
          ],
        ),
        pad: 16,
      ),
      'keep_styles',
    );
  });

  testWidgets('keep: new reward variants', (tester) async {
    await tester.binding.setSurfaceSize(const Size(520, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const furn = {
      'rug',
      'lamp',
      'plant',
      'shelf',
      'picture',
      'garland',
      'candles',
    };

    Widget rewardKeep(String wallId, String floorId, String flameId) {
      final flame = creatureSkinById(flameId)!;
      return SizedBox(
        width: 460,
        child: HomeRoom(
          unlocked: furn,
          wall: wallColorsById(wallId),
          floor: floorColorsById(floorId),
          emberGlow: asFlameHue(flame.colors[2]),
          petAwake: true,
        ),
      );
    }

    await _shoot(
      tester,
      _stage(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            rewardKeep('wall_amber', 'floor_maple', 'sunstone'),
            const SizedBox(height: 14),
            rewardKeep('wall_berry', 'floor_cherry', 'sea_glass'),
          ],
        ),
        pad: 16,
      ),
      'keep_new_rewards',
    );
  });

  // the HISTORY CONSTELLATION at three ages: a first week, a solid month with
  // gaps, and half a year of dense history — the three shapes a real save
  // passes through, so the spiral's turn-scaling can be eyeballed.
  testWidgets('history sky: three ages', (tester) async {
    await tester.binding.setSurfaceSize(const Size(560, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final start = DateTime(2026, 1, 6);
    Map<String, int> hist(
      int days,
      bool Function(int) lit,
      int Function(int) n,
    ) {
      final m = <String, int>{};
      for (var i = 0; i < days; i++) {
        if (lit(i)) m[Days.key(start.add(Duration(days: i)))] = n(i);
      }
      return m;
    }

    Widget sky(Map<String, int> h) => SizedBox(
      width: 380,
      child: HistorySky(history: h, ember: const Color(0xFFF2CD93)),
    );
    await _shoot(
      tester,
      _stage(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            sky(hist(6, (i) => true, (i) => 1 + i % 3)),
            const SizedBox(height: 12),
            // a month with two honest gaps in it
            sky(hist(34, (i) => i % 11 != 7 && i % 11 != 8, (i) => 1 + i % 5)),
            const SizedBox(height: 12),
            sky(hist(178, (i) => i % 9 != 4, (i) => 1 + (i * 7) % 6)),
          ],
        ),
        pad: 16,
      ),
      'history_sky',
    );
  });

  testWidgets('window scenes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(560, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _shoot(
      tester,
      _stage(
        bg: const Color(0xFF1C141A),
        pad: 14,
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final v in windowViews)
              SizedBox(
                width: 160,
                height: 120,
                child: CustomPaint(painter: _ScenePainter(v.id)),
              ),
          ],
        ),
      ),
      'window_scenes',
    );
  });

  testWidgets('hearth flame palette', (tester) async {
    await tester.binding.setSurfaceSize(const Size(560, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _shoot(
      tester,
      _stage(
        bg: const Color(0xFF1C141A),
        pad: 18,
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 14,
          children: [
            for (final skin in creatureSkins)
              SizedBox(
                width: 82,
                height: 82,
                child: CustomPaint(
                  painter: _FlamePalettePainter(asFlameHue(skin.colors[2])),
                ),
              ),
          ],
        ),
      ),
      'hearth_flame_palette',
    );
  });

  // the journal hub feed (search field, month headers, entry cards)
  testWidgets('journal hub: the feed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = GameState()..level = 8;
    state.setJournal([
      Note(
        at: DateTime(2026, 7, 7, 21, 30),
        text:
            'Long day, but I kept the fire going. Two quests done and a '
            'walk after dinner — small, but it counts.',
        context: 'Kindling',
        trace: const JournalTrace(
          day: '2026-07-07',
          level: 8,
          totalXp: 1360,
          todayXp: 96,
          streakDays: 5,
          questTitles: ['Walk after dinner', 'Clear the kitchen counter'],
          goalTitles: ['Build a walking habit'],
          statGains: {Stat.vit: 3, Stat.dis: 2},
          energy: EnergyWeather.steady,
        ),
      ),
      Note(
        at: DateTime(2026, 7, 2, 8, 15),
        text: 'Morning pages: what I want this week to feel like.',
      ),
      Note(
        at: DateTime(2026, 6, 24, 19),
        text: 'A quieter reflection from last month — looking back already.',
        context: 'Room of Days',
      ),
    ]);
    await _shoot(
      tester,
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: JournalHubScreen(
          state: state,
          quests: const [],
          onPersist: () {},
        ),
      ),
      'journal_hub',
    );
  });

  testWidgets('quest board: phone shell', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      Clock.reset();
    });
    Clock.freeze(DateTime(2026, 7, 7, 14));
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);
    final state = GameState()
      ..onboarded = true
      ..playerName = 'Mika'
      ..level = 7
      ..xp = 118
      ..totalXp = 980
      ..streakDays = 6
      ..bestStreak = 11
      ..streakFreezes = 3
      ..streakFreezeProgress = 2
      ..lastActiveDay = '2026-07-07'
      ..lastCompletionDay = '2026-07-07'
      ..soundEnabled = false;
    state.frozenStreakDays.add('2026-07-05');
    state.stats[Stat.str] = 42;
    state.stats[Stat.vit] = 35;
    state.stats[Stat.intl] = 58;
    state.stats[Stat.foc] = 26;
    state.stats[Stat.soc] = 18;
    state.stats[Stat.dis] = 31;
    final quests = [
      Quest(
        title: 'Read ten pages',
        stat: Stat.intl,
        difficulty: 4,
        priority: true,
      ),
      Quest(title: 'Walk after lunch', stat: Stat.vit, difficulty: 3),
      Quest(
        title: 'Clear the desk',
        stat: Stat.dis,
        difficulty: 5,
        dread: true,
      ),
      Quest(
        title: 'No caffeine after 2pm',
        stat: Stat.vit,
        difficulty: 7,
        allDay: true,
      ),
    ];
    SharedPreferences.setMockInitialValues({
      whatsNewSeenReleasePreferenceKey: currentRoomReleaseNotes.id,
      'liferpg_save_v1': jsonEncode({
        'app': 'emberkeep',
        'schema': Storage.schema,
        'state': state.toJson(),
        'quests': [for (final q in quests) q.toJson()],
      }),
    });

    await tester.pumpWidget(const LifeRpgApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/quest_board.png'),
      );
      await tester.tap(find.byType(StreakFreezeStatus));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('STREAK FREEZES'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/streak_freeze_sheet.png'),
      );
    }
  });

  testWidgets('quests daily field: crowded board visual contract', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      Clock.reset();
      Sfx.instance.soundEnabled = true;
    });
    final now = DateTime(2026, 8, 30, 10);
    final today = Days.key(now);
    SharedPreferences.setMockInitialValues({});
    Clock.freeze(now);
    Sfx.instance.soundEnabled = false;

    final commitment = Quest(
      title: 'Submit the housing form',
      stat: Stat.intl,
      difficulty: 3,
      custom: true,
      schedule: QuestSchedule.once,
      dueDate: now,
    );
    final first =
        Quest(
            title: 'Ten quiet minutes on the draft',
            stat: Stat.foc,
            difficulty: 2,
            custom: true,
          )
          ..priorityDay = today
          ..priorityRank = 1;
    final second =
        Quest(
            title: 'Put water beside the bed',
            stat: Stat.vit,
            difficulty: 1,
            custom: true,
          )
          ..priorityDay = today
          ..priorityRank = 2;
    final optionalSketch = Quest(
      title: 'Sketch if there is room',
      stat: Stat.intl,
      difficulty: 2,
      custom: true,
    );
    final optionalWalk = Quest(
      title: 'Walk if the evening has energy',
      stat: Stat.vit,
      difficulty: 2,
      custom: true,
    );
    final quests = <Quest>[
      commitment,
      first,
      second,
      optionalSketch,
      optionalWalk,
    ];
    final state = GameState()
      ..onboarded = true
      ..reduceMotion = true
      ..soundEnabled = false
      ..morningDoneDay = today
      ..emberSeenDay = today
      ..sparkSeenDay = today;

    Widget board({double textScale = 1}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        backgroundColor: Palette.parchment,
        body: WarmBackground(
          themeId: state.canvasTheme,
          tint: Palette.streak,
          reduceMotion: true,
          child: QuestsPage(
            state: state,
            quests: quests,
            onRefresh: () => 0,
            onPersist: () {},
            onAdd: (quest) {
              quests.add(quest);
              return true;
            },
            onRemove: quests.remove,
            onSnapshot: () => '{}',
            onRestore: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await _precacheQuestBoardArt(tester);
    await tester.pumpWidget(board());
    await tester.pump(const Duration(milliseconds: 500));
    final rail = find.byKey(const Key('daily-field-rail'));
    await tester.scrollUntilVisible(
      rail,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.text('OPEN IF IT FITS · 2'), findsOneWidget);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/quests_daily_field_collapsed_430x932.png'),
      );
    }

    await tester.tap(find.text('OPEN IF IT FITS · 2'));
    await tester.pump(const Duration(milliseconds: 180));
    await tester.scrollUntilVisible(
      find.text('Sketch if there is room'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/quests_daily_field_expanded_430x932.png'),
      );
    }
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('HIDE OPTIONAL QUESTS'));
    await tester.tap(find.text('HIDE OPTIONAL QUESTS'));
    commitment.lastDoneDay = today;
    first.lastDoneDay = today;
    second.lastDoneDay = today;
    await tester.pumpWidget(board());
    await tester.pump(const Duration(milliseconds: 350));
    await tester.scrollUntilVisible(
      rail,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('TODAY’S FIELD · ENOUGH'), findsOneWidget);
    expect(find.text('OPEN IF IT FITS · 2'), findsOneWidget);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/quests_daily_field_enough_430x932.png'),
      );
    }
    expect(tester.takeException(), isNull);

    // Detach the 430-point board before changing the simulated window. In the
    // real app text scale and window constraints arrive together; relaying out
    // the old 1.0x tree at 320 points creates a one-frame state no device sees.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    await tester.pump();
    commitment.lastDoneDay = null;
    first.lastDoneDay = null;
    second.lastDoneDay = null;
    await tester.pumpWidget(board(textScale: 1.5));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.scrollUntilVisible(
      rail,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 180));
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/quests_daily_field_collapsed_large_text_320x568.png',
        ),
      );
    }
    await tester.tap(find.text('OPEN IF IT FITS · 2'));
    await tester.pump(const Duration(milliseconds: 180));
    await tester.scrollUntilVisible(
      find.text('Sketch if there is room'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Sketch if there is room')),
      alignment: 0.45,
      duration: Duration.zero,
    );
    await tester.pump();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/quests_daily_field_expanded_large_text_320x568.png',
        ),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone audit: time-aware first run', (tester) async {
    tester.view.devicePixelRatio = 3;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      Clock.reset();
    });
    Clock.freeze(DateTime(2026, 7, 31, 20, 15));
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);
    final state = GameState()..reduceMotion = true;

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
              }) {},
        ),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/rooms/wall_walnut-clean-v2.webp'),
        tester.element(find.byType(MaterialApp)),
      );
    });
    await tester.pump(const Duration(milliseconds: 600));
    await _storeShot(tester, 'audit_00_welcome_1290x2796');
    await tester.tap(find.text('ENTER ROOM OF DAYS'));
    await tester.pump(const Duration(milliseconds: 500));
    await _storeShot(tester, 'audit_01_evening_name_1290x2796');
    await tester.tap(find.text('skip for now'));
    await tester.pump(const Duration(milliseconds: 500));
    await _storeShot(tester, 'audit_02_day_shape_1290x2796');
    await tester.tap(find.text('CONTINUE'));
    await tester.pump(const Duration(milliseconds: 500));
    await _storeShot(tester, 'audit_03_first_board_1290x2796');
  });

  testWidgets('phone audit: fresh Me, room identities, and Journal', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    Sfx.instance.soundEnabled = false;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      Clock.reset();
      Sfx.instance.soundEnabled = true;
    });
    Clock.freeze(DateTime(2026, 7, 31, 20, 15));
    final state = GameState()
      ..onboarded = true
      ..reduceMotion = true
      ..soundEnabled = false;
    SharedPreferences.setMockInitialValues({
      whatsNewSeenReleasePreferenceKey: currentRoomReleaseNotes.id,
      'liferpg_save_v1': jsonEncode({
        'app': 'emberkeep',
        'schema': Storage.schema,
        'state': state.toJson(),
        'quests': const [],
      }),
    });

    await tester.pumpWidget(const LifeRpgApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await _precacheSpaceThemeArt(tester);
    await _precachePageArt(tester);

    _activateDock(tester, Icons.emoji_emotions_outlined);
    await tester.pump(const Duration(milliseconds: 500));
    await _storeShot(tester, 'audit_10_fresh_me_1290x2796');
    await tester.tap(find.text('0 GLIMMERS'));
    await tester.pump(const Duration(milliseconds: 500));
    await _storeShot(tester, 'audit_11_space_themes_1290x2796');
    final conservatory = find.text('The Living Conservatory');
    await tester.ensureVisible(conservatory);
    await tester.pump(const Duration(milliseconds: 300));
    await _storeShot(tester, 'audit_11a_conservatory_choice_1290x2796');
    await tester.tap(conservatory);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await _storeShot(tester, 'audit_11b_conservatory_preview_1290x2796');
    expect(find.text('STEP INSIDE'), findsOneWidget);
    expect(find.text('280 MORE GLIMMERS'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pump(const Duration(milliseconds: 350));
    final archive = find.text('The Moonlit Archive');
    await tester.ensureVisible(archive);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(archive);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await _storeShot(tester, 'audit_11c_archive_preview_1290x2796');
    expect(find.text('STEP INSIDE'), findsOneWidget);
    expect(find.text('420 MORE GLIMMERS'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pump(const Duration(milliseconds: 350));
    Navigator.of(tester.element(find.text('Change your space'))).pop();
    await tester.pump(const Duration(milliseconds: 500));

    _activateDock(tester, Icons.menu_book_outlined);
    await tester.pump(const Duration(milliseconds: 500));
    await _storeShot(tester, 'audit_12_fresh_journal_1290x2796');
    await tester.tap(find.text('Your Journal'));
    await tester.pump(const Duration(milliseconds: 500));
    await _storeShot(tester, 'audit_13_empty_journal_hub_1290x2796');
    await tester.tap(find.text('Write a new entry'));
    await tester.pump(const Duration(milliseconds: 500));
    await _storeShot(tester, 'audit_14_journal_editor_1290x2796');
  });

  testWidgets('store screenshot story: Journal Quest doorway', (tester) async {
    tester.view.devicePixelRatio = 3;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      Clock.reset();
      Sfx.instance.soundEnabled = true;
    });
    final now = DateTime(2026, 8, 3, 14);
    Clock.freeze(now);
    Sfx.instance.soundEnabled = false;
    SharedPreferences.setMockInitialValues({});

    final state = GameState()
      ..onboarded = true
      ..playerName = 'Alex'
      ..level = 8
      ..totalXp = 1260
      ..totalCompletions = 42
      ..reduceMotion = true
      ..soundEnabled = false
      ..morningDoneDay = Days.key(now)
      ..weekRecapSeenWeek = Days.key(Days.weekStart(now))
      ..emberSeenDay = Days.key(now)
      ..sparkSeenDay = Days.key(now);
    final journalQuest = Quest(
      title: 'Name three good things',
      stat: Stat.intl,
      difficulty: 2,
      goalTitle: 'Keep a journal',
      journalPrompt: const JournalQuestPrompt(
        starter: 'Three things I’m thankful for:\n',
        hint: 'A person, place, moment, or tiny detail all count.',
      ),
    );
    final quests = <Quest>[
      journalQuest,
      Quest(title: 'Read ten pages', stat: Stat.intl, difficulty: 2),
      Quest(title: 'Clear one surface', stat: Stat.dis, difficulty: 2),
    ];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Palette.parchment,
          body: WarmBackground(
            themeId: state.canvasTheme,
            tint: Palette.streak,
            reduceMotion: true,
            child: QuestsPage(
              state: state,
              quests: quests,
              onRefresh: () => 0,
              onPersist: () {},
              onAdd: (quest) {
                quests.add(quest);
                return true;
              },
              onRemove: quests.remove,
              onSnapshot: () => '{}',
              onRestore: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final context = tester.element(find.byType(MaterialApp));
      await precacheImage(
        const AssetImage('assets/quest/category-mind-v2.webp'),
        context,
      );
      await precacheImage(
        const AssetImage('assets/pages/journal-desk-v3.webp'),
        context,
      );
    });
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Name three good things'), findsOneWidget);
    expect(find.text('JOURNAL'), findsOneWidget);
    expect(find.text('OPEN JOURNAL'), findsOneWidget);
    await _storeShot(tester, '13_journal_quest_1290x2796');

    final journalCard = find.byKey(ValueKey('card-${journalQuest.title}'));
    final journalAction = find.descendant(
      of: journalCard,
      matching: find.byType(Pressable),
    );
    tester
        .widget<Pressable>(journalAction)
        .onTapUp!
        .call(tester.getCenter(journalCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(JournalEntryScreen), findsOneWidget);
    expect(find.text('Name three good things'), findsWidgets);
    expect(find.text('Three things I’m thankful for:\n'), findsOneWidget);
    await _storeShot(tester, '13b_journal_quest_entry_1290x2796');

    final lookingBack = Note(
      at: DateTime(2026, 7, 18, 21, 10),
      text:
          'Three things I’m thankful for:\nMy sister calling. The rain. Starting again.',
    );
    // Reset the Navigator before swapping one JournalEntryScreen for another;
    // MaterialApp otherwise keeps the prior home route alive in this test.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: JournalEntryScreen(
          key: const ValueKey('looking-back-read-mode-shot'),
          initial: lookingBack,
          accent: Palette.xp,
          themeId: state.canvasTheme,
          reduceMotion: true,
          heading: 'Looking back',
          hint: 'A page from your journal',
          starter: 'Three things I’m thankful for:\n',
          initiallyEditing: false,
          commit: (payload, existing, markEdited) => existing!.copyWith(
            text: payload.text,
            rich: payload.rich,
            images: payload.images,
          ),
          onDelete: (_) {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await _storeShot(tester, '13c_journal_read_mode_1290x2796');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('store screenshot story: real production surfaces', (
    tester,
  ) async {
    // 430×932 logical points at 3× is Apple's 1290×2796 iPhone screenshot
    // class. Capturing the real widgets at native density avoids a blurry
    // post-upscale and keeps store art honest to the submitted binary.
    tester.view.devicePixelRatio = 3;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      Clock.reset();
    });

    Clock.freeze(DateTime(2026, 7, 26, 14));
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);
    final state = GameState()
      ..onboarded = true
      ..playerName = 'Alex'
      ..level = 18
      ..xp = 284
      ..totalXp = 4280
      ..totalCompletions = 138
      ..embers = 640
      ..streakDays = 12
      ..bestStreak = 19
      ..lastActiveDay = '2026-07-26'
      ..lastCompletionDay = '2026-07-26'
      ..weekRecapSeenWeek = Days.key(Days.weekStart(Clock.now()))
      ..soundEnabled = false
      ..reduceMotion = true
      // The free defaults. Capturing on a purchased skin meant every visual
      // review was judging a wall most players have never seen.
      ..wallStyle = 'wall_walnut'
      ..floorStyle = 'floor_oak'
      ..questDeskStyle = 'wall_indigo'
      ..windowScene = 'moon'
      ..creatureSkin = 'sunstone'
      ..roomCode = 'DAY234'
      ..roomDiscoverable = true
      ..roomDiscoveryName = 'Alex';
    final keptNote = Note(
      at: DateTime(2026, 7, 16, 20, 10),
      text: 'The first evening this room began to feel like mine.',
      context: 'Homey Homesteader',
      trace: const JournalTrace(
        day: '2026-07-16',
        level: 16,
        totalXp: 3670,
        todayXp: 72,
        streakDays: 4,
        questTitles: ['Clear the kitchen counter', 'Make the bed'],
        goalTitles: ['Make the apartment feel calm'],
        statGains: {Stat.dis: 4},
        energy: EnergyWeather.steady,
      ),
    );
    state.journal = [
      keptNote,
      Note(
        at: DateTime(2026, 7, 18, 9, 20),
        text: 'I showed up even though the day felt smaller than planned.',
        context: 'Homey Homesteader',
        trace: const JournalTrace(
          day: '2026-07-18',
          level: 17,
          totalXp: 3890,
          todayXp: 48,
          streakDays: 6,
          questTitles: ['Walk after lunch'],
          goalTitles: ['Build a walking habit'],
          statGains: {Stat.vit: 3},
          energy: EnergyWeather.low,
        ),
      ),
    ];
    state.memoryPins.add(keptNote.id);
    state.energyWeather = EnergyWeather.steady;
    state.energyWeatherDay = '2026-07-26';
    state.energyHistory.addAll({
      '2026-07-20': EnergyWeather.low,
      '2026-07-21': EnergyWeather.steady,
      '2026-07-23': EnergyWeather.bright,
      '2026-07-25': EnergyWeather.steady,
      '2026-07-26': EnergyWeather.steady,
    });
    state.stats[Stat.str] = 88;
    state.stats[Stat.vit] = 72;
    state.stats[Stat.intl] = 116;
    state.stats[Stat.foc] = 94;
    state.stats[Stat.soc] = 61;
    state.stats[Stat.dis] = 103;
    state.ownedSkins.add('sunstone');
    state.ownedStyles.addAll({
      'wall_conservatory',
      'wall_archive',
      'floor_maple',
    });
    state.ownedFurniture.addAll({
      'rug',
      'lamp',
      'plant',
      'shelf',
      'picture',
      'chair',
      'candles',
      'garland',
      'hearth',
      'pet',
    });
    state.unlockedAchievements.addAll({
      'well-rounded',
      'goal-getter',
      'perfect-day',
      'week-of-fire',
      'ascendant',
    });
    state.goals.addAll([
      Goal(
        title: 'Build a walking habit',
        stat: Stat.vit,
        target: 25,
        progress: 17,
        startedDay: '2026-07-08',
      ),
      Goal(
        title: 'Make the apartment feel calm',
        stat: Stat.dis,
        target: 25,
        progress: 11,
        startedDay: '2026-07-14',
      ),
    ]);
    state.setSpaceProfile(
      intro:
          'Building a calmer home, keeping my promises small, and making time '
          'for the people I love.',
      goals: {'Build a walking habit', 'Make the apartment feel calm'},
      shared: true,
    );
    state.setSpacePage(
      order: state.spaceCardOrder,
      hidden: state.hiddenSpaceCards,
      audiences: const {
        SpaceCardKind.about: SpaceAudience.anyone,
        SpaceCardKind.rightNow: SpaceAudience.mutuals,
        SpaceCardKind.pinnedMoments: SpaceAudience.onlyMe,
        SpaceCardKind.thisSeason: SpaceAudience.anyone,
      },
      intro: state.spaceIntro,
      featuredGoalTitles: state.featuredGoalTitles,
      seasonText: state.spaceSeasonText,
      profilePhotoNoteId: state.spaceProfilePhotoNoteId,
      seasonPhotoNoteId: state.spaceSeasonPhotoNoteId,
      shareProfilePhoto: false,
      shareSeasonPhoto: false,
      shareProfile: true,
    );
    for (var i = 0; i < 72; i++) {
      if (i % 9 == 4 || i % 13 == 7) continue;
      final day = DateTime(2026, 7, 26).subtract(Duration(days: i));
      state.history[Days.key(day)] = 1 + (i * 5) % 5;
    }

    final quests = [
      Quest(
        title: 'Read ten pages',
        stat: Stat.intl,
        difficulty: 4,
        priority: true,
      ),
      Quest(
        title: 'Walk after lunch',
        stat: Stat.vit,
        difficulty: 3,
        goalTitle: 'Build a walking habit',
        lastDoneDay: '2026-07-26',
      ),
      Quest(
        title: 'Clear the kitchen counter',
        stat: Stat.dis,
        difficulty: 5,
        dread: true,
        goalTitle: 'Make the apartment feel calm',
      ),
      Quest(title: 'Message someone I miss', stat: Stat.soc, difficulty: 4),
      Quest(
        title: 'Twenty-five focused minutes',
        stat: Stat.foc,
        difficulty: 6,
        verification: Verification.timer,
        timerMinutes: 25,
      ),
      workoutLauncherQuest(),
    ];
    SharedPreferences.setMockInitialValues({
      whatsNewSeenReleasePreferenceKey: currentRoomReleaseNotes.id,
      'liferpg_save_v1': jsonEncode({
        'app': 'emberkeep',
        'schema': Storage.schema,
        'state': state.toJson(),
        'quests': [for (final q in quests) q.toJson()],
      }),
    });

    await tester.pumpWidget(const LifeRpgApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await _precacheSpaceThemeArt(tester);
    await _precachePageArt(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
    );
    await tester.pump();
    await _storeShot(tester, '01_quests_1290x2796');
    await _playStoreShot(tester, '01_quests_1080x1920');

    // The Quest board is one continuous surface over a fixed room. Capture
    // the real scrolled state so the progressive blur and crisp foreground
    // hierarchy are judged, not just inferred from the resting frame.
    final questBoard = find.byKey(const ValueKey('quest-board-scroll'));
    await tester.drag(questBoard, const Offset(0, -335));
    await tester.pump(const Duration(milliseconds: 280));
    await _storeShot(tester, '01a_quests_scrolled_1290x2796');
    tester.widget<NestedScrollView>(questBoard).controller!.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 280));

    await tester.tap(find.byType(QuestDeskStyleButton));
    await tester.pump(const Duration(milliseconds: 450));
    await _storeShot(tester, '01b_quest_desk_1290x2796');
    Navigator.of(tester.element(find.text('QUEST DESK'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    // Store story beat two: one real quest becomes XP, Glimmers, and visible
    // permanent progress. Capture the production receipt while its reward
    // bubbles are fully readable, then let it clear before navigating.
    await tester.tap(find.text('Read ten pages'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 170));
    await _storeShotNow(tester, '02a_stitch_1290x2796');
    await tester.pump(const Duration(milliseconds: 730));
    await _storeShot(tester, '02_reward_1290x2796');
    await _playStoreShot(tester, '02_reward_1080x1920');

    // The optional ten-second Journal door is part of the production reward
    // path, not a disconnected mock. Keep one real line so the later Journal
    // capture can prove that completion context travelled with it.
    await tester.tap(find.textContaining('KEEP ONE LINE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));
    await _storeShot(tester, '02c_quick_reflection_1290x2796');
    await tester.enterText(
      find.byType(TextField).last,
      'Leaving the book open on my desk made starting almost automatic.',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('KEEP IN JOURNAL'));
    await tester.pump();
    await _storeShot(tester, '02d_quick_reflection_written_1290x2796');
    await tester.tap(find.text('KEEP IN JOURNAL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));
    await _storeShot(tester, '02e_reflection_kept_1290x2796');
    await tester.pump(const Duration(seconds: 4));

    _activateDock(tester, Icons.emoji_emotions_outlined);
    await tester.pump(const Duration(milliseconds: 450));
    await _storeShot(tester, '02_keep_1290x2796');
    await _playStoreShot(tester, '03_my_space_1080x1920');

    await tester.tap(find.text('CHANGE SPACE'));
    await tester.pump(const Duration(milliseconds: 450));
    await _storeShot(tester, '03_shop_1290x2796');
    final conservatory = find.text('The Living Conservatory');
    // The shop list builds lazily, so the card may not exist yet —
    // scrollUntilVisible builds it; ensureVisible alone throws No element.
    await tester.scrollUntilVisible(
      conservatory,
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(conservatory);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(conservatory);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 550));
    await _storeShot(tester, '03b_conservatory_preview_1290x2796');
    await _playStoreShot(tester, '04_change_space_1080x1920');
    await tester.tap(find.byTooltip('Close'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump(const Duration(milliseconds: 700));

    _activateDock(tester, Icons.explore_outlined);
    await tester.pump(const Duration(milliseconds: 450));
    await _storeShot(tester, '04_goals_1290x2796');

    final supportToggle = find.byKey(const ValueKey('goals-support-toggle'));
    await tester.scrollUntilVisible(
      supportToggle,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(supportToggle);
    await tester.pump(const Duration(milliseconds: 220));
    await tester.tap(find.byKey(const ValueKey('goals-unstick-me')));
    await tester.pump(const Duration(milliseconds: 600));
    await _storeShot(tester, '04b_momentum_kits_1290x2796');
    await tester.enterText(
      find.byKey(const ValueKey('momentum-kit-text')),
      'Open the next paragraph',
    );
    await tester.pump(const Duration(milliseconds: 450));
    await _storeShot(tester, '04c_low_flame_1290x2796');
    await tester.tap(find.text('PIN TO QUESTS'));
    await tester.pump(const Duration(milliseconds: 350));
    await _storeShot(tester, '04d_low_flame_lit_1290x2796');
    await tester.tap(find.text('OPEN THIS QUEST'));
    await tester.pump(const Duration(milliseconds: 800));
    await _storeShot(tester, '04e_kit_quests_1290x2796');

    _activateDock(tester, Icons.calendar_month_outlined);
    await tester.pump(const Duration(milliseconds: 450));
    await _storeShot(tester, '05_planner_1290x2796');
    final planAction = find.byKey(const ValueKey('calendar-plan-selected-day'));
    expect(planAction, findsOneWidget);
    await tester.ensureVisible(planAction);
    await tester.pump(const Duration(milliseconds: 180));
    expect(planAction.hitTestable(), findsOneWidget);
    await tester.tap(planAction);
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.text('START WITH A DAY SHAPE — OR NAME YOUR OWN'),
      findsOneWidget,
      reason: 'The planner-shapes capture must show the Plan creation surface.',
    );
    await _storeShot(tester, '05b_planner_shapes_1290x2796');
    Navigator.of(
      tester.element(find.text('START WITH A DAY SHAPE — OR NAME YOUR OWN')),
    ).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.text('START WITH A DAY SHAPE — OR NAME YOUR OWN'),
      findsNothing,
    );

    _activateDock(tester, Icons.menu_book_outlined);
    await tester.pump(const Duration(milliseconds: 450));
    await _storeShot(tester, '06_insights_1290x2796');
    await _playStoreShot(tester, '05_journal_1080x1920');

    await tester.tap(find.text('Your Journal'));
    await tester.pump(const Duration(milliseconds: 450));
    await _storeShot(tester, '07_journal_1290x2796');
    // This story has already completed a quest, so Journal offers a prompt
    // tied to that evidence rather than the generic fresh-day starter.
    await tester.tap(find.text('QUEST THREAD'));
    await tester.pump(const Duration(milliseconds: 450));
    await _storeShot(tester, '07b_journal_starter_1290x2796');
    await tester.tap(find.byIcon(Icons.chevron_left).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left).last);
    await tester.pump(const Duration(milliseconds: 450));

    _activateDock(tester, Icons.task_alt);
    await tester.pump(const Duration(milliseconds: 450));
    if (find.text('SHOW ALL').evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        find.text('SHOW ALL'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.text('SHOW ALL'));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.scrollUntilVisible(
      find.textContaining('Guided workout'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.textContaining('Guided workout').last);
    await tester.pump(const Duration(milliseconds: 450));
    await _storeShot(tester, '08_workout_picker_1290x2796');

    await tester.tap(find.text('Wake-Up Snack'));
    await tester.pump(const Duration(milliseconds: 450));
    await _storeShot(tester, '09_workout_preview_1290x2796');

    await tester.tap(find.text('LET’S BEGIN'));
    await tester.pump(const Duration(milliseconds: 450));
    await _storeShot(tester, '10_workout_active_1290x2796');

    // Dispose AppShell so its midnight rollover timer cannot escape the test.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('store screenshot story: keepsakes and sharing', (tester) async {
    tester.view.devicePixelRatio = 3;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      Clock.reset();
    });
    Clock.freeze(DateTime(2026, 7, 28, 14));
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);

    final note = Note(
      at: DateTime(2026, 7, 23, 20),
      text: 'The first evening this room began to feel like mine.',
      context: 'Homey Homesteader',
    );
    final state = GameState()
      ..onboarded = true
      ..playerName = 'Alex'
      ..level = 18
      ..totalXp = 4280
      ..streakDays = 12
      ..bestStreak = 19
      ..reduceMotion = true
      ..soundEnabled = false
      ..wallStyle = 'wall_walnut'
      ..floorStyle = 'floor_oak'
      ..windowScene = 'moon'
      ..creatureSkin = 'sunstone'
      ..journal = [note]
      ..memoryPins.add(note.id)
      ..unlockedAchievements.addAll({
        'first-step',
        'well-rounded',
        'week-of-fire',
        'goal-getter',
        'ascendant',
      });
    state.ownedFurniture.addAll({
      'rug',
      'plant',
      'shelf',
      'picture',
      'chair',
      'candles',
    });
    state.stats[Stat.str] = 88;
    state.stats[Stat.vit] = 72;
    state.stats[Stat.intl] = 116;
    state.stats[Stat.foc] = 94;
    state.stats[Stat.soc] = 61;
    state.stats[Stat.dis] = 103;
    state.goals.add(
      Goal(
        title: 'Make the apartment feel calm',
        stat: Stat.dis,
        target: 25,
        progress: 25,
      ),
    );
    state.history.addAll({
      '2026-07-20': 2,
      '2026-07-21': 1,
      '2026-07-23': 3,
      '2026-07-25': 2,
      '2026-07-26': 1,
    });

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: WeeklyChronicleScreen(state: state),
      ),
    );
    await _storeShot(tester, '06b_weekly_chronicle_1290x2796');

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MemoryCabinetScreen(state: state, quests: const []),
      ),
    );
    await _storeShot(tester, '07a_memory_cabinet_1290x2796');

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: HearthCircleScreen(state: state, onPersist: () {}),
      ),
    );
    await _storeShot(tester, '02b_hearth_circle_1290x2796');

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showShareSpaceDialog(
                  context,
                  code: 'DAY234',
                  ownerName: 'Alex',
                  onPreview: () {},
                  onStop: () async => true,
                ),
                child: const Text('Share my space'),
              ),
            ),
          ),
        ),
      ),
    );
    await _precacheGoldSurface(tester);
    await tester.tap(find.text('Share my space'));
    await tester.pumpAndSettle();
    await _storeShot(tester, '02e_share_dialog_1290x2796');
    Navigator.of(tester.element(find.text('DONE'))).pop();
    await tester.pumpAndSettle();

    final friend = GameState()
      ..playerName = 'Mara'
      ..level = 21
      ..totalXp = 5360
      ..wallStyle = 'wall_conservatory'
      ..floorStyle = 'floor_maple'
      ..windowScene = 'rain'
      ..creatureSkin = 'sunstone'
      ..reduceMotion = true
      ..ownedFurniture.addAll({
        'rug',
        'plant',
        'shelf',
        'picture',
        'chair',
        'candles',
        'garland',
      });
    friend.goals.addAll([
      Goal(
        title: 'Make mornings feel unhurried',
        stat: Stat.dis,
        target: 25,
        progress: 14,
      ),
      Goal(
        title: 'Grow a small kitchen garden',
        stat: Stat.vit,
        target: 25,
        progress: 9,
      ),
    ]);
    friend.stats[Stat.soc] = 61;
    friend.stats[Stat.dis] = 55;
    final sharedMoment = Note(
      at: DateTime(2026, 7, 26),
      text: 'The first tomato finally turned red. I almost missed it.',
    );
    friend.journal = [sharedMoment];
    friend.memoryPins.add(sharedMoment.id);
    friend.setSpacePage(
      order: const [
        SpaceCardKind.about,
        SpaceCardKind.rightNow,
        SpaceCardKind.pinnedMoments,
        SpaceCardKind.thisSeason,
      ],
      hidden: const [],
      visitorVisible: SpaceCardKind.values,
      intro:
          'I’m making a calmer home, growing things slowly, and leaving room '
          'for people I love.',
      featuredGoalTitles: const {
        'Make mornings feel unhurried',
        'Grow a small kitchen garden',
      },
      seasonText: 'A season for growing slowly and inviting people in.',
      profilePhotoNoteId: null,
      seasonPhotoNoteId: null,
      shareProfilePhoto: false,
      shareSeasonPhoto: false,
      shareProfile: true,
    );
    friend.history[Days.key(Clock.now())] = 2;
    friend.setEnergyWeather(EnergyWeather.steady);

    final circleState = GameState()
      ..reduceMotion = true
      ..addCircleCode('DAY234');
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: HearthCircleScreen(
          state: circleState,
          onPersist: () {},
          roomFetcher: (_) async => roomDisplay(friend),
          sparkSender: (_, _) async => true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    await tester.scrollUntilVisible(
      find.text('SEND A NOTE'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('SEND A NOTE'));
    await tester.pump(const Duration(milliseconds: 450));
    await _storeShot(tester, '02f_support_picker_1290x2796');
    Navigator.of(tester.element(find.text('Send support'))).pop();
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: VisitRoomScreen(
          room: roomDisplay(friend),
          code: 'DAY234',
          themeId: state.canvasTheme,
          lively: false,
          localState: state,
          onPersist: () {},
        ),
      ),
    );
    await _storeShot(tester, '02c_visitor_room_1290x2796');
    expect(find.text('PINNED MOMENTS'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('store screenshot story: capacity journeys', (tester) async {
    tester.view.devicePixelRatio = 3;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      Clock.reset();
    });
    SharedPreferences.setMockInitialValues({});
    final now = DateTime(2026, 7, 28, 10);
    Clock.freeze(now);
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);
    final state = GameState()
      ..onboarded = true
      ..level = 14
      ..totalXp = 2960
      ..totalCompletions = 86
      ..reduceMotion = true
      ..morningDoneDay = Days.key(now)
      ..weekRecapSeenWeek = Days.key(Days.weekStart(now))
      ..emberSeenDay = Days.key(now)
      ..sparkSeenDay = Days.key(now);
    final quests = [
      Quest(
        title: 'Reply to the apartment email',
        stat: Stat.dis,
        difficulty: 2,
        custom: true,
      ),
      Quest(
        title: 'Ten quiet minutes on the draft',
        stat: Stat.foc,
        difficulty: 2,
        custom: true,
      ),
      Quest(
        title: 'Put water beside the bed',
        stat: Stat.vit,
        difficulty: 1,
        custom: true,
      ),
      Quest(
        title: 'Finish the presentation',
        stat: Stat.foc,
        difficulty: 7,
        custom: true,
      ),
      Quest(
        title: 'Deep-clean the kitchen',
        stat: Stat.dis,
        difficulty: 8,
        custom: true,
      ),
      Quest(
        title: 'Book the appointment',
        stat: Stat.vit,
        difficulty: 5,
        dread: true,
        custom: true,
      ),
      Quest(
        title: 'Read the next chapter',
        stat: Stat.intl,
        difficulty: 4,
        custom: true,
      ),
      Quest(title: 'Call Dad', stat: Stat.soc, difficulty: 3, custom: true),
    ];
    state.setEnergyWeather(EnergyWeather.low);
    state.setLowFlameQuests(
      suggestedLowFlameQuests(quests, now).map((q) => q.title),
    );

    Widget capacityJourney() => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Palette.parchment,
        body: WarmBackground(
          themeId: state.canvasTheme,
          tint: Palette.streak,
          reduceMotion: true,
          child: QuestsPage(
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

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await _precacheQuestBoardArt(tester);
    await tester.pumpWidget(capacityJourney());
    await _storeShot(tester, '01b_low_flame_1290x2796');

    // At wind-down time, Quests grows one quiet, unmistakable door into the
    // nightly ledger even when the board still has work on it.
    Clock.freeze(DateTime(2026, 7, 28, 20, 30));
    state.setEnergyWeather(EnergyWeather.steady);
    await tester.pumpWidget(capacityJourney());
    await tester.pump(const Duration(milliseconds: 350));
    await _storeShot(tester, '01d_evening_close_1290x2796');

    showTopThreeWizard(
      tester.element(find.byType(QuestsPage)),
      title: 'Shape tomorrow',
      subtitle:
          'Pick up to three quests to lead the morning. This is a compass, not another obligation.',
      dayLabel: 'Tomorrow’s Three',
      candidates: quests,
      initialTitles: quests.take(2).map((q) => q.title),
      confirmLabel: 'SET TOMORROW’S THREE',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await _storeShot(tester, '01c_top_three_1290x2796');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  // The two daily bookends had NO render coverage at all — the only captures
  // that ever existed were from a one-off script that no longer exists, so the
  // most materially-detailed screens in the app were the two nobody could look
  // at. They drift precisely because of that.
  testWidgets('store screenshot story: the daily bookends', (tester) async {
    tester.view.devicePixelRatio = 3;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      Clock.reset();
    });
    Clock.freeze(DateTime(2026, 7, 30, 21, 40));
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);

    final today = Days.key(Clock.now());
    final state = GameState()
      ..onboarded = true
      ..playerName = 'Alex'
      ..level = 18
      ..totalXp = 4280
      ..streakDays = 12
      ..bestStreak = 19
      ..reduceMotion = true
      ..soundEnabled = false
      ..wallStyle = 'wall_walnut'
      ..floorStyle = 'floor_oak'
      ..windowScene = 'moon';
    state.stats[Stat.str] = 88;
    state.stats[Stat.vit] = 72;
    state.stats[Stat.intl] = 116;
    state.stats[Stat.foc] = 94;
    state.stats[Stat.soc] = 61;
    state.stats[Stat.dis] = 103;

    // The night ledger reads the live day-record (todayXp / todayStats /
    // todayQuestTitles), not each quest's lastDoneDay — stamping only the
    // quests captured the "nothing had to be proven today" empty state, which
    // is not the screen anyone needs to review.
    state.todayXp = 114;
    state.todayStats[Stat.foc] = 7;
    state.todayStats[Stat.intl] = 4;
    state.todayStats[Stat.dis] = 3;
    state.todayQuestTitles.addAll([
      'Finish the visual pass',
      'Read ten pages',
      'Clear the kitchen counter',
      'Take a ten-minute walk',
    ]);

    Quest done(String title, Stat stat, int difficulty) => Quest(
      title: title,
      stat: stat,
      difficulty: difficulty,
      lastDoneDay: today,
    );
    final quests = <Quest>[
      done('Finish the visual pass', Stat.foc, 5),
      done('Read ten pages', Stat.intl, 3),
      done('Clear the kitchen counter', Stat.dis, 3),
      done('Take a ten-minute walk', Stat.str, 2),
      Quest(title: 'Draft the chapter', stat: Stat.foc, difficulty: 4),
      Quest(title: 'Message someone I miss', stat: Stat.soc, difficulty: 2),
    ];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: NightFlow(
            state: state,
            quests: quests,
            onAdd: (_) => true,
            onPersist: () {},
            onClose: () {},
          ),
        ),
      ),
    );
    await _precacheRoutineArt(tester);
    await _storeShot(tester, '11_night_close_1290x2796');

    await tester.tap(find.text('reflect · optional'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));
    await _storeShot(tester, '11b_night_reflection_1290x2796');
    await tester.tap(find.byTooltip('Not now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    state.saveNightJournal(
      const NightJournalData(
        tomorrowMessage: 'Put the chapter first. The rest can wait.',
      ),
      state.todayJournalTrace(quests),
    );
    state.finalizeNightJournal(state.todayJournalTrace(quests));
    state.closeNight();

    Clock.reset();
    Clock.freeze(DateTime(2026, 7, 31, 7, 20));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: MorningFlow(state: state, quests: quests, onClose: () {}),
        ),
      ),
    );
    await _precacheRoutineArt(tester);
    await _storeShot(tester, '12_morning_open_1290x2796');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('store screenshot story: arrangeable My Space cards', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      Clock.reset();
    });
    Clock.freeze(DateTime(2026, 8, 3, 16, 20));
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);

    final firstMoment = Note(
      id: 'space-moment-first',
      at: DateTime(2026, 7, 29, 19),
      text: 'Dinner ran long because nobody wanted to leave the table.',
    );
    final secondMoment = Note(
      id: 'space-moment-second',
      at: DateTime(2026, 8, 2, 11),
      text: 'Found the first tiny tomato hiding under the leaves.',
    );
    final state = GameState()
      ..onboarded = true
      ..playerName = 'Mika'
      ..level = 14
      ..totalXp = 3180
      ..streakDays = 8
      ..reduceMotion = true
      ..soundEnabled = false
      ..roomCode = 'DAY234'
      ..roomDiscoverable = true
      ..roomDiscoveryName = 'Mika'
      ..journal = [firstMoment, secondMoment]
      ..memoryPins.addAll({firstMoment.id, secondMoment.id});
    state.stats[Stat.str] = 62;
    state.stats[Stat.vit] = 80;
    state.stats[Stat.intl] = 71;
    state.stats[Stat.foc] = 112;
    state.stats[Stat.soc] = 94;
    state.stats[Stat.dis] = 88;
    state.goals.addAll([
      Goal(
        title: 'Finish the room with care',
        stat: Stat.foc,
        target: 20,
        progress: 14,
      ),
      Goal(
        title: 'Make more time for family dinners',
        stat: Stat.soc,
        target: 12,
        progress: 5,
      ),
      Goal(
        title: 'Keep the little garden alive',
        stat: Stat.vit,
        target: 18,
        progress: 9,
      ),
    ]);
    state.setSpacePage(
      order: defaultSpaceCardOrder,
      hidden: const [],
      audiences: const {
        SpaceCardKind.about: SpaceAudience.anyone,
        SpaceCardKind.rightNow: SpaceAudience.mutuals,
        SpaceCardKind.pinnedMoments: SpaceAudience.onlyMe,
        SpaceCardKind.thisSeason: SpaceAudience.anyone,
      },
      intro:
          'I make things, care for people, and keep trying to notice the days while they are here.',
      featuredGoalTitles: state.goals.map((goal) => goal.title),
      seasonText:
          'Finishing one chapter slowly, keeping the windows open, and letting August be August.',
      profilePhotoNoteId: null,
      seasonPhotoNoteId: null,
      shareProfilePhoto: false,
      shareSeasonPhoto: false,
      shareProfile: true,
    );

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
        home: Scaffold(
          body: MePage(
            state: state,
            quests: const [],
            onPersist: () {},
            onPublishRoom: (_, {required code}) async =>
                RoomPublishResult.success(code),
            onAddQuest: (_) => true,
            onExport: () async => true,
            onImport: (_) async => true,
            onReset: () async => null,
            onNotifyChanged: () async {},
            onEnableCloud: () async => null,
            onLinkAccount: (_, _) async => null,
            onSignIn: (_, _) async => null,
            onSignOut: () async {},
            onDeleteAccount: (_) async => null,
            onRemovePrivateServiceIdentity: () async => null,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final pageScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('MY SPACE'),
      360,
      scrollable: pageScroll,
    );
    await tester.pump(const Duration(milliseconds: 250));
    await _storeShot(tester, '14_my_space_cards_1290x2796');

    await tester.scrollUntilVisible(
      find.text('THIS SEASON'),
      300,
      scrollable: pageScroll,
    );
    await tester.pump(const Duration(milliseconds: 250));
    await _storeShot(tester, '14b_my_space_season_1290x2796');

    await tester.scrollUntilVisible(
      find.text('ROOM GUIDE'),
      520,
      scrollable: pageScroll,
    );
    await tester.pump(const Duration(milliseconds: 250));
    await _storeShot(tester, '14d_room_guide_entry_1290x2796');

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('space-page-open-arranger')),
      -360,
      scrollable: pageScroll,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('space-page-open-arranger')));
    await tester.pumpAndSettle();
    await _storeShot(tester, '14c_my_space_arranger_1290x2796');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('store screenshot story: controlled primary-button light', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    await tester.binding.setSurfaceSize(const Size(430, 700));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });

    final states = <({String label, String note, Offset light, double scroll})>[
      (
        label: 'PHONE RESTING',
        note: 'tiny hand motion stays here',
        light: Offset.zero,
        scroll: 0,
      ),
      (
        label: 'INTENTIONAL LEFT TILT',
        note: 'the satin reflection rolls left',
        light: calmMotionTarget(const Offset(-0.84, 0.16)),
        scroll: 0,
      ),
      (
        label: 'INTENTIONAL RIGHT TILT',
        note: 'the same reflection rolls right',
        light: calmMotionTarget(const Offset(0.84, -0.16)),
        scroll: 0,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF100D0B),
          textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Inter'),
          useMaterial3: true,
        ),
        home: Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.72, -0.92),
                radius: 1.2,
                colors: [
                  Color(0xFF342416),
                  Color(0xFF17110D),
                  Color(0xFF0E0B09),
                ],
                stops: [0, 0.44, 1],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'ONE LIGHT · ONE PIECE OF METAL',
                      style: Type.label.copyWith(
                        color: Palette.xpLight,
                        fontSize: 11,
                        letterSpacing: 1.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The button does not shimmer on its own. It only answers '
                      'a deliberate tilt or the Quest page moving beneath it.',
                      style: Type.body.copyWith(
                        color: Palette.textMid,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (final state in states) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              state.label,
                              style: Type.label.copyWith(
                                color: Palette.textHi,
                                fontSize: 10.5,
                                letterSpacing: 1.25,
                              ),
                            ),
                          ),
                          Text(
                            state.note,
                            style: Type.body.copyWith(
                              color: Palette.textLo,
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      SizedBox(
                        height: 104,
                        child: GoldSurface(
                          cut: 10,
                          light: AlwaysStoppedAnimation(state.light),
                          scroll: AlwaysStoppedAnimation(state.scroll),
                          child: const GoldLabel(
                            text: 'MARK COMPLETE',
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.wb_sunny_outlined,
                          color: Palette.xpLight,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'The implied candlelight stays fixed above-left; '
                            'the metal changes angle beneath it.',
                            style: Type.body.copyWith(
                              color: Palette.textMid,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/quest/luminous-honey-gold-v2.webp'),
        tester.element(find.byType(MaterialApp)),
      );
    });
    await tester.pump(const Duration(milliseconds: 300));
    await _storeShot(tester, '15_button_light_angles_1290x2100');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('steward hidden encounter: authored scene and compact text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      Sfx.instance.soundEnabled = true;
    });
    Sfx.instance.soundEnabled = false;
    final state = GameState()
      ..reduceMotion = true
      ..soundEnabled = false;
    Future<void> mount({
      Size size = const Size(430, 932),
      double scale = 1,
    }) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(brightness: Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: size,
              disableAnimations: true,
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: StewardEncounterScreen(state: state),
        ),
      );
      await _precachePageArt(tester);
      await tester.pumpAndSettle();
    }

    final orderedPreview = <Map<String, Object?>>[];
    Future<void> shot(String name, {bool record = false}) async {
      expect(tester.takeException(), isNull);
      if (record) {
        final node = stewardEncounter[state.stewardMemory.nodeId]!;
        orderedPreview.add({
          'node': state.stewardMemory.nodeId,
          'speaker': node.speaker,
          'text': node.text,
          'aside': node.aside,
          'choices': [for (final reply in node.choices) reply.text],
          'image': 'test/goldens/$name.png',
        });
      }
      if (_capture) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
      }
    }

    Future<void> tap(String key) async {
      if (key.startsWith('steward-reply-') && orderedPreview.isNotEmpty) {
        final node = stewardEncounter[state.stewardMemory.nodeId]!;
        orderedPreview.last['playerReply'] = node.choices
            .firstWhere((reply) => key == 'steward-reply-${reply.id}')
            .text;
      }
      final control = find.byKey(Key(key));
      await tester.ensureVisible(control);
      await tester.pumpAndSettle();
      await tester.tap(control);
      await tester.pumpAndSettle();
    }

    await mount();
    await shot('steward_soup_01_hello_430x932', record: true);
    await tap('steward-reply-ask');
    await shot('steward_soup_02_setup_430x932', record: true);
    await tap('steward-continue');
    await shot('steward_soup_03_note_430x932', record: true);
    await tap('steward-continue');
    await shot('steward_soup_04_friends_430x932', record: true);
    await tap('steward-reply-cook');
    await shot('steward_soup_05_reply_430x932', record: true);
    await tap('steward-continue');
    await shot('steward_soup_06_bread_430x932', record: true);
    await tap('steward-reply-tell');
    await shot('steward_soup_07_admission_430x932', record: true);
    await tap('steward-continue');
    await shot('steward_soup_08_goodbye_430x932', record: true);
    if (_capture) {
      debugPrintSynchronously(
        'STEWARD_ORDERED_PREVIEW=${jsonEncode(orderedPreview)}',
      );
    }
    // A completed saved visit supplies the return callback independently of
    // navigation; the widget integration test drives actual finish and reopen.
    state.stewardMemory
      ..completed = true
      ..nodeId = null;
    await mount();
    await shot('steward_soup_09_callback_430x932');
    for (final scale in [1.5, 2.0]) {
      state.stewardMemory.nodeId = stewardFirstLine;
      await mount(size: const Size(320, 568), scale: scale);
      await shot('steward_soup_choices_${scale}x_top_320x568');
      await tester.ensureVisible(find.byKey(const Key('steward-reply-leave')));
      await tester.pumpAndSettle();
      await shot('steward_soup_choices_${scale}x_actions_320x568');
      state.stewardMemory.nodeId = 'soup-bread';
      await mount(size: const Size(320, 568), scale: scale);
      await shot('steward_soup_long_line_${scale}x_top_320x568');
      await tester.ensureVisible(find.byKey(const Key('steward-reply-knows')));
      await tester.pumpAndSettle();
      await shot('steward_soup_long_line_${scale}x_action_320x568');
    }
  });

  testWidgets('goals personal index: narrow large text', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      Clock.reset();
    });
    Clock.freeze(DateTime(2026, 8, 25, 10));
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);

    final state = GameState()
      ..reduceMotion = true
      ..soundEnabled = false;
    state.goals.addAll([
      Goal(
        title: 'Make the apartment feel calm',
        stat: Stat.dis,
        target: 25,
        progress: 11,
      ),
      Goal(
        title: 'Build a walking habit',
        stat: Stat.vit,
        target: 25,
        progress: 17,
      ),
    ]);
    final quests = <Quest>[
      Quest(
        title: 'Clear the kitchen counter',
        stat: Stat.dis,
        difficulty: 2,
        goalTitle: 'Make the apartment feel calm',
      ),
      Quest(
        title: 'Go for a ten-minute walk',
        stat: Stat.vit,
        difficulty: 2,
        goalTitle: 'Build a walking habit',
      ),
    ];

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
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
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
            onRemoveQuest: (_) {},
            onRemoveGoal: (_) {},
            onPersist: () {},
            onOpenQuest: (_) {},
          ),
        ),
      ),
    );
    await _precachePageArt(tester);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goals_personal_index_narrow_large_text_320x568.png',
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('goals-today-field')),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 120));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goals_today_field_narrow_large_text_320x568.png',
        ),
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('goals-workshop-entrance-label')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('goals-workshop-entrance-status')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('goals-open-workshop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-workshop-home')), findsOneWidget);
    expect(find.byKey(const Key('goal-workshop-tavern')), findsOneWidget);
    expect(find.byKey(const Key('goal-workshop-steward')), findsOneWidget);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goals_workshop_home_narrow_large_text_320x568.png',
        ),
      );
    }
    await tester.tap(find.byKey(const Key('steward-hidden-card')));
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goals_workshop_conversation_narrow_large_text_320x568.png',
        ),
      );
    }
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('steward-leave')));
    await tester.pumpAndSettle();
    final narrowOwnedRoute = find.byKey(
      const ValueKey<String>(
        'goal-workshop-home-goal-Make the apartment feel calm',
      ),
    );
    await tester.ensureVisible(narrowOwnedRoute);
    await tester.pumpAndSettle();
    await tester.tap(narrowOwnedRoute);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('goal-workshop-accept')));
    expect(find.text('Open this Quest'), findsOneWidget);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goals_workshop_owned_narrow_large_text_320x568.png',
        ),
      );
    }
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('goal-workshop-cancel')));
    await tester.tap(find.byKey(const Key('goal-workshop-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal-workshop-home-back')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('goals-new-goal')),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('goals-new-goal')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick-goal-create')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('goals personal index: 2x recovery text', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      Clock.reset();
    });
    Clock.freeze(DateTime(2026, 8, 27, 10));
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);

    final goal = Goal(
      title: 'Make the apartment feel calm enough to come home to',
      stat: Stat.dis,
      target: 25,
      progress: 11,
      why: 'Home should feel easier to return to, even after a long day.',
      fallbackCue: 'the whole apartment feels like too much',
      fallbackAction: 'clear one hand-sized surface and leave the rest',
    );
    final state = GameState()
      ..reduceMotion = true
      ..soundEnabled = false
      ..goals.add(goal);
    final quests = <Quest>[
      Quest(
        title: 'Clear the kitchen counter beside the sink',
        stat: Stat.dis,
        difficulty: 2,
        goalTitle: goal.title,
      ),
    ];

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
          ).copyWith(textScaler: const TextScaler.linear(2)),
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
            onRemoveQuest: (_) {},
            onRemoveGoal: (_) {},
            onPersist: () {},
            onOpenQuest: (_) {},
          ),
        ),
      ),
    );
    await _precachePageArt(tester);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goals_return_2x_text_top_320x568.png'),
      );
    }
    expect(tester.takeException(), isNull);

    final action = find.byKey(
      const Key('focus-goal-action'),
      skipOffstage: false,
    );
    await tester.scrollUntilVisible(
      action,
      210,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goals_return_2x_text_action_320x568.png'),
      );
    }
    expect(action, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('goals focused recovery: narrow large text', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      Clock.reset();
    });
    Clock.freeze(DateTime(2026, 8, 29, 10));
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);

    final plan = GoalPlanner.draft(
      GoalPlanInput(
        title: 'Make the apartment feel calm',
        stat: Stat.dis,
        type: GoalRouteType.reset,
        outcome: 'The kitchen is usable after ordinary days',
        startingPoint: 'The counter is crowded',
        successProof: 'One clear surface stays usable for a week',
        timeBudgetMinutes: 15,
        obstacleCue: 'the whole room feels too big after class',
        now: Clock.now(),
      ),
    );
    final goal = Goal(
      title: 'Make the apartment feel calm',
      stat: Stat.dis,
      target: plan.steps.fold(
        0,
        (total, step) => total + step.requiredCompletions,
      ),
      progress: 3,
      plan: plan,
      openingSeen: true,
    );
    final quest = GoalPlanner.questFor(
      goal,
      GoalPlanner.decide(goal, const [], Clock.now())!,
      Clock.now(),
    );
    final state = GameState()
      ..reduceMotion = true
      ..soundEnabled = false
      ..goals.add(goal);
    final quests = <Quest>[quest];

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
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: GoalsPage(
            state: state,
            quests: quests,
            onAdd: (created) {
              quests.add(created);
              return true;
            },
            onRemoveQuest: quests.remove,
            onRemoveGoal: (_) {},
            onPersist: () {},
            onOpenQuest: (_) {},
          ),
        ),
      ),
    );
    await _precachePageArt(tester);
    final recovery = find.byKey(const Key('focus-goal-fallback'));
    await tester.ensureVisible(recovery);
    await tester.tap(recovery);
    await tester.pumpAndSettle();

    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goals_recovery_choices_narrow_top_320x568.png',
        ),
      );
    }
    expect(find.text('What would help now?'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final leave = find.byKey(
      const ValueKey('goal-recovery-leaveTodayAlone'),
      skipOffstage: false,
    );
    final prepare = find.byKey(
      const ValueKey('goal-recovery-prepareReturn'),
      skipOffstage: false,
    );
    await Scrollable.ensureVisible(
      tester.element(prepare),
      alignment: 0.08,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goals_recovery_choices_narrow_bottom_320x568.png',
        ),
      );
    }
    expect(leave, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('goals focused recovery: leave and smaller results', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      Clock.reset();
    });
    Clock.freeze(DateTime(2026, 8, 29, 10));
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);

    final drafted = GoalPlanner.draft(
      GoalPlanInput(
        title: 'Make the apartment feel calm',
        stat: Stat.dis,
        type: GoalRouteType.reset,
        outcome: 'The kitchen is usable after ordinary days',
        startingPoint: 'The counter is crowded',
        successProof: 'One clear surface stays usable for a week',
        timeBudgetMinutes: 15,
        obstacleCue: 'the whole room feels too big after class',
        now: Clock.now(),
      ),
    );
    final firstStep = drafted.steps.first;
    final plan = drafted.copyWith(
      steps: [
        firstStep.copyWith(
          completions: firstStep.requiredCompletions,
          completedDay: '2026-08-27',
        ),
        ...drafted.steps.skip(1),
      ],
    );
    final goal = Goal(
      title: 'Make the apartment feel calm',
      stat: Stat.dis,
      target: plan.steps.fold(
        0,
        (total, step) => total + step.requiredCompletions,
      ),
      progress: firstStep.requiredCompletions,
      firstProofTitle: 'Cleared the table once',
      firstProofDay: '2026-08-27',
      plan: plan,
      openingSeen: true,
    );
    final oldQuest = GoalPlanner.questFor(
      goal,
      GoalPlanner.decide(goal, const [], Clock.now())!,
      Clock.now(),
    );
    final state = GameState()
      ..reduceMotion = true
      ..soundEnabled = false
      ..goals.add(goal);
    final quests = <Quest>[oldQuest];

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
        home: Scaffold(
          body: GoalsPage(
            state: state,
            quests: quests,
            onAdd: (created) {
              quests.add(created);
              return true;
            },
            onRemoveQuest: quests.remove,
            onRemoveGoal: (_) {},
            onPersist: () {},
            onOpenQuest: (_) {},
          ),
        ),
      ),
    );
    await _precachePageArt(tester);

    await tester.tap(find.byKey(const Key('focus-goal-fallback')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('goal-recovery-leaveTodayAlone')),
    );
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goals_recovery_leave_alone_430x932.png'),
      );
    }
    expect(quests.single, same(oldQuest));
    expect(tester.takeException(), isNull);
    ScaffoldMessenger.of(
      tester.element(find.byType(GoalsPage)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('focus-goal-fallback')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-recovery-smaller')));
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goals_recovery_smaller_workshop_430x932.png',
        ),
      );
    }
    expect(find.byKey(const Key('goal-workshop-screen')), findsOneWidget);
    expect(quests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('goal opening: desk, threshold, and arrival', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);
    final openingPlan = GoalPlanner.draft(
      GoalPlanInput(
        title: 'Make the apartment feel calm',
        stat: Stat.dis,
        type: GoalRouteType.reset,
        outcome: 'I can use the kitchen without feeling overwhelmed',
        startingPoint:
            'The counter is crowded and I avoid deciding where things go',
        successProof: 'The counter stays usable for a normal week',
        timeBudgetMinutes: 15,
        obstacleCue: 'this feels like too much today',
        now: DateTime(2026, 8, 25),
      ),
    );
    final goal = Goal(
      title: 'Make the apartment feel calm',
      stat: Stat.dis,
      kind: GoalKind.achieve,
      target: openingPlan.steps.fold(
        0,
        (total, step) => total + step.requiredCompletions,
      ),
      why: 'so coming home feels like an exhale',
      fallbackCue: openingPlan.obstacleCue,
      fallbackAction: openingPlan.fallbackAction,
      openingSeen: false,
      plan: openingPlan,
    );

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
        home: GoalOpeningScreen(
          goal: goal,
          actionTitle: openingPlan.currentStep!.actionTitle,
          fallbackAction: goal.fallbackAction,
          preparedByApp: true,
          reduceMotion: true,
          onBegin: () {},
          onEditAction: (_) async => true,
          onMakeSmaller: () async => openingPlan.fallbackAction,
          onReturn: () {},
        ),
      ),
    );
    await _precachePageArt(tester);
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goal_opening_01_desk_430x932.png'),
      );
    }

    await tester.tap(find.byKey(const Key('goal-opening-show-plan')));
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goal_opening_02_wide_room_430x932.png'),
      );
    }

    await tester.tap(find.byKey(const Key('goal-room-wide-continue')));
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goal_opening_03_threshold_430x932.png'),
      );
    }

    await tester.tap(find.byKey(const Key('goal-room-arch-step-in')));
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goal_opening_04_arrival_430x932.png'),
      );
    }
    expect(find.byKey(const Key('goal-workshop-screen')), findsOneWidget);
    expect(find.byKey(const Key('goal-workshop-accept')), findsOneWidget);
    expect(find.byKey(const Key('goal-workshop-edit-action')), findsOneWidget);
    expect(
      find.byKey(const Key('goal-workshop-smaller-action')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('goal-workshop-cancel')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('goal-workshop-cancel')));
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goal_opening_05_workshop_actions_430x932.png',
        ),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('goal workshop: 1.3 text keeps acceptance reachable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);
    final openingPlan = GoalPlanner.draft(
      GoalPlanInput(
        title: 'Make the apartment feel calm',
        stat: Stat.dis,
        type: GoalRouteType.reset,
        outcome: 'I can use the kitchen without feeling overwhelmed',
        startingPoint:
            'The counter is crowded and I avoid deciding where things go',
        successProof: 'The counter stays usable for a normal week',
        timeBudgetMinutes: 15,
        obstacleCue: 'the whole room feels too big after class',
        now: DateTime(2026, 8, 25),
      ),
    );
    final goal = Goal(
      title: 'Make the apartment feel calm',
      stat: Stat.dis,
      target: 25,
      why: 'so coming home feels like an exhale',
      fallbackAction: openingPlan.fallbackAction,
      openingSeen: false,
      plan: openingPlan,
    );

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
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: GoalOpeningScreen(
          goal: goal,
          actionTitle: openingPlan.currentStep!.actionTitle,
          fallbackAction: goal.fallbackAction,
          preparedByApp: true,
          reduceMotion: true,
          onBegin: () {},
          onEditAction: (_) async => true,
          onMakeSmaller: () async => openingPlan.fallbackAction,
          onReturn: () {},
        ),
      ),
    );
    await _precachePageArt(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('goal-opening-show-plan')));
    await tester.tap(find.byKey(const Key('goal-opening-show-plan')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('goal-room-wide-continue')),
    );
    await tester.tap(find.byKey(const Key('goal-room-wide-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal-room-arch-step-in')));
    await tester.pumpAndSettle();

    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goal_opening_workshop_130_text_top_430x932.png',
        ),
      );
    }
    final acceptRect = tester.getRect(
      find.byKey(const Key('goal-workshop-accept')),
    );
    expect(acceptRect.top, greaterThanOrEqualTo(0));
    expect(acceptRect.bottom, lessThanOrEqualTo(932));
    await tester.ensureVisible(find.byKey(const Key('goal-workshop-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-workshop-cancel')), findsOneWidget);
    final stickyAcceptRect = tester.getRect(
      find.byKey(const Key('goal-workshop-accept')),
    );
    expect(stickyAcceptRect.top, greaterThanOrEqualTo(0));
    expect(stickyAcceptRect.bottom, lessThanOrEqualTo(932));
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goal_opening_workshop_130_text_controls_430x932.png',
        ),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('goal opening: narrow large text remains reachable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);
    final openingPlan = GoalPlanner.draft(
      GoalPlanInput(
        title: 'Make home feel calm',
        stat: Stat.dis,
        type: GoalRouteType.reset,
        outcome: 'I can use the kitchen without feeling overwhelmed',
        startingPoint: 'The counter is crowded',
        successProof: 'The counter stays usable for a normal week',
        timeBudgetMinutes: 15,
        obstacleCue: 'the whole room feels too big after class',
        now: DateTime(2026, 8, 25),
      ),
    );
    final goal = Goal(
      title: 'Make home feel calm',
      stat: Stat.dis,
      kind: GoalKind.achieve,
      target: openingPlan.steps.fold(
        0,
        (total, step) => total + step.requiredCompletions,
      ),
      why: 'so coming home feels like an exhale',
      fallbackCue: openingPlan.obstacleCue,
      fallbackAction: openingPlan.fallbackAction,
      openingSeen: false,
      plan: openingPlan,
    );

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
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: GoalOpeningScreen(
          goal: goal,
          actionTitle: openingPlan.currentStep!.actionTitle,
          fallbackAction: goal.fallbackAction,
          preparedByApp: true,
          reduceMotion: true,
          onBegin: () {},
          onEditAction: (_) async => true,
          onMakeSmaller: () async => openingPlan.fallbackAction,
          onReturn: () {},
        ),
      ),
    );
    await _precachePageArt(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-opening-show-plan')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('goal-opening-show-plan')));
    await tester.tap(find.byKey(const Key('goal-opening-show-plan')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-room-wide-continue')), findsOneWidget);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goal_opening_narrow_wide_room_320x568.png'),
      );
    }
    await tester.ensureVisible(
      find.byKey(const Key('goal-room-wide-continue')),
    );
    await tester.tap(find.byKey(const Key('goal-room-wide-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-room-arch-step-in')), findsOneWidget);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goal_opening_narrow_threshold_320x568.png'),
      );
    }
    await tester.tap(find.byKey(const Key('goal-room-arch-step-in')));
    await tester.pumpAndSettle();
    final compactAction = tester.widget<Text>(
      find.byKey(const Key('goal-opening-action-title')),
    );
    expect(compactAction.style?.fontFamily, 'EBGaramond');
    expect(compactAction.style?.fontSize, 19);
    expect(compactAction.textScaler?.scale(1), closeTo(1.5, 0.01));
    expect(tester.widget<Text>(find.text(goal.title).last).maxLines, isNull);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goal_opening_narrow_workshop_top_320x568.png',
        ),
      );
    }
    final acceptRect = tester.getRect(
      find.byKey(const Key('goal-workshop-accept')),
    );
    expect(acceptRect.top, greaterThanOrEqualTo(0));
    expect(acceptRect.bottom, lessThanOrEqualTo(568));
    await tester.ensureVisible(find.byKey(const Key('goal-workshop-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-workshop-cancel')), findsOneWidget);
    final stickyAcceptRect = tester.getRect(
      find.byKey(const Key('goal-workshop-accept')),
    );
    expect(stickyAcceptRect.top, greaterThanOrEqualTo(0));
    expect(stickyAcceptRect.bottom, lessThanOrEqualTo(568));
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goal_opening_narrow_workshop_controls_320x568.png',
        ),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('goal opening: desk clasp at 1.15 text scale', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);
    final goal = Goal(
      title: 'Make the apartment feel calm',
      stat: Stat.dis,
      target: 25,
      why: 'so coming home feels like an exhale',
      fallbackAction: 'clear one hand-sized surface',
      openingSeen: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.15)),
          child: child!,
        ),
        home: GoalOpeningScreen(
          goal: goal,
          actionTitle: 'Clear the kitchen counter',
          fallbackAction: goal.fallbackAction,
          preparedByApp: true,
          reduceMotion: true,
          onBegin: () {},
          onChooseAnother: () {},
        ),
      ),
    );
    await _precachePageArt(tester);
    await tester.pumpAndSettle();

    expect(find.text('See the move'), findsOneWidget);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goal_opening_desk_115_text_430x932.png'),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('goal opening: 200 percent long copy remains reachable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);
    final goal = Goal(
      title:
          'Build a calmer homecoming ritual that still works after the hardest days',
      stat: Stat.dis,
      target: 25,
      why:
          'I want the first ten minutes at home to feel gentle even when I have no energy left.',
      fallbackAction:
          'put away one visible thing and leave the rest for tomorrow',
      openingSeen: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: GoalOpeningScreen(
          goal: goal,
          actionTitle:
              'Clear one hand-sized surface beside the door before putting anything else away',
          fallbackAction: goal.fallbackAction,
          preparedByApp: true,
          reduceMotion: true,
          onBegin: () {},
          onChooseAnother: () {},
        ),
      ),
    );
    await _precachePageArt(tester);
    await tester.pumpAndSettle();

    final showPlan = find.byKey(const Key('goal-opening-show-plan'));
    await tester.ensureVisible(showPlan);
    await tester.tap(showPlan);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final crossRoom = find.byKey(const Key('goal-room-wide-continue'));
    await tester.ensureVisible(crossRoom);
    await tester.tap(crossRoom);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final stepIn = find.byKey(const Key('goal-room-arch-step-in'));
    await tester.ensureVisible(stepIn);
    await tester.tap(stepIn);
    await tester.pumpAndSettle();
    final begin = find.byKey(const Key('goal-opening-begin'));
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goal_opening_long_copy_arrival_top_320x568.png',
        ),
      );
    }
    await tester.ensureVisible(begin);
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goal_opening_long_copy_arrival_action_320x568.png',
        ),
      );
    }
    expect(begin, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('goals personal index: active and quick create', (tester) async {
    final storeCapture = _captureStore && !_capture;
    tester.view.devicePixelRatio = storeCapture ? 3 : 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      Clock.reset();
    });
    Clock.freeze(DateTime(2026, 8, 25, 10));
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);

    final state = GameState()
      ..reduceMotion = true
      ..soundEnabled = false;
    final focusRoute = GoalPlanner.draft(
      GoalPlanInput(
        title: 'Make the apartment feel calm',
        stat: Stat.dis,
        type: GoalRouteType.reset,
        outcome: 'I can use the kitchen without feeling overwhelmed',
        startingPoint:
            'The counter is crowded and I avoid deciding where things go',
        successProof: 'The counter stays usable for a normal week',
        timeBudgetMinutes: 15,
        obstacleCue: 'the whole apartment feels like too much after class',
        horizon: 'Before the semester begins',
        now: Clock.now(),
      ),
    );
    final focus = Goal(
      title: 'Make the apartment feel calm',
      stat: Stat.dis,
      kind: GoalKind.achieve,
      target: focusRoute.steps.fold(
        0,
        (total, step) => total + step.requiredCompletions,
      ),
      why: 'Home should feel easier to return to.',
      fallbackCue: focusRoute.obstacleCue,
      fallbackAction: focusRoute.fallbackAction,
      plan: focusRoute,
    );
    state.goals.addAll([
      focus,
      Goal(
        title: 'Build a walking habit',
        stat: Stat.vit,
        target: 25,
        progress: 17,
      ),
      Goal(
        title: 'Read books that stay with me',
        stat: Stat.intl,
        target: 25,
        progress: 4,
      ),
      Goal(
        title: 'Finish the portfolio case study',
        stat: Stat.foc,
        target: 12,
        kind: GoalKind.achieve,
        progress: 12,
        achievedDay: Days.key(Clock.now()),
      ),
    ]);
    state.featuredGoalTitles.add(focus.title);
    final quests = <Quest>[
      Quest(
        title: focusRoute.currentStep!.actionTitle,
        stat: Stat.dis,
        difficulty: 2,
        schedule: QuestSchedule.once,
        dueDate: DateTime(2026, 8, 25),
        goalTitle: focus.title,
        goalPlanStepId: focusRoute.currentStep!.id,
        goalPlanRevision: focusRoute.revision,
        goalPlanAttempt: 1,
      ),
      Quest(
          title: 'Go for a ten-minute walk',
          stat: Stat.vit,
          difficulty: 2,
          goalTitle: 'Build a walking habit',
        )
        ..priorityDay = Days.key(Clock.now())
        ..priorityRank = 1,
      Quest(title: 'Read twenty pages', stat: Stat.intl, difficulty: 2)
        ..priorityDay = Days.key(Clock.now())
        ..priorityRank = 2,
      Quest(
        title: 'Call a friend if the evening has room',
        stat: Stat.soc,
        difficulty: 2,
      ),
    ];
    Quest? openedQuest;

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
        home: Scaffold(
          body: GoalsPage(
            state: state,
            quests: quests,
            onAdd: (quest) {
              quests.add(quest);
              return true;
            },
            onRemoveQuest: (_) {},
            onRemoveGoal: (_) {},
            onPersist: () {},
            onOpenQuest: (quest) => openedQuest = quest,
          ),
        ),
      ),
    );
    await _precachePageArt(tester);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goals_personal_index_active_430x932.png'),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('goals-today-field')),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 120));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goals_today_field_430x932.png'),
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
    }
    if (storeCapture) {
      await _storeShot(tester, 'goals_active_1290x2796');
    }
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('focus-goal-fallback')));
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goals_recovery_choices_430x932.png'),
      );
    }
    if (storeCapture) {
      await _storeShot(tester, 'goals_recovery_1290x2796');
    }
    expect(find.text('What would help now?'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('goals-open-workshop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-workshop-home')), findsOneWidget);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goals_workshop_home_430x932.png'),
      );
    }
    if (storeCapture) {
      await _storeShot(tester, 'goals_workshop_1290x2796');
    }
    await tester.tap(find.byKey(const Key('steward-hidden-card')));
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goals_workshop_conversation_430x932.png'),
      );
    }
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('steward-leave')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'goal-workshop-home-goal-Make the apartment feel calm',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CURRENT QUEST'), findsOneWidget);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goals_workshop_owned_430x932.png'),
      );
    }
    await tester.ensureVisible(find.byKey(const Key('goal-workshop-cancel')));
    await tester.tap(find.byKey(const Key('goal-workshop-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal-workshop-home-back')));
    await tester.pumpAndSettle();

    final support = find.byKey(const Key('goals-support-toggle'));
    await tester.scrollUntilVisible(
      support,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(support);
    await tester.pumpAndSettle();
    expect(find.text('Find a start'), findsOneWidget);
    expect(find.text('Guided Workouts'), findsOneWidget);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goals_personal_index_support_open_430x932.png',
        ),
      );
    }
    await tester.tap(support);
    await tester.pumpAndSettle();

    final primary = find.byKey(const Key('focus-goal-action'));
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollable.position.jumpTo(0);
    await tester.pumpAndSettle();
    final press = await tester.startGesture(tester.getCenter(primary));
    await tester.pump();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goals_personal_index_action_pressed_430x932.png',
        ),
      );
    }
    await press.cancel();
    await tester.pumpAndSettle();

    // A rapid second acceptance cannot hand the same Quest off twice. The
    // first accepted frame remains visibly pending before the route begins.
    await tester.tap(primary);
    await tester.tap(primary);
    await tester.pump();
    expect(openedQuest, isNull);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goals_personal_index_action_pending_430x932.png',
        ),
      );
    }
    await tester.pumpAndSettle();
    expect(find.byType(GoalDetailScreen), findsNothing);
    expect(identical(openedQuest, quests.first), isTrue);

    await tester.tap(find.byKey(const Key('goals-open-workshop')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'goal-workshop-home-goal-Make the apartment feel calm',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('goal-workshop-rework-route')),
    );
    await tester.tap(find.byKey(const Key('goal-workshop-rework-route')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal-plan-signal-tooBig')));
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goals_personal_index_repair_workshop_430x932.png',
        ),
      );
    }
    expect(focus.plan!.adjustments, hasLength(1));
    await tester.ensureVisible(find.byKey(const Key('goal-workshop-cancel')));
    await tester.tap(find.byKey(const Key('goal-workshop-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal-workshop-home-back')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('goals-new-goal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goals-new-goal')));
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goals_quick_create_430x932.png'),
      );
    }
    await tester.enterText(
      find.byKey(const Key('quick-goal-name')),
      'Make the kitchen easier to return to',
    );
    await tester.enterText(
      find.byKey(const Key('quick-goal-outcome')),
      'I can use the kitchen without feeling overwhelmed',
    );
    final resetType = find.byKey(const Key('quick-goal-type-reset'));
    await tester.ensureVisible(resetType);
    await tester.tap(resetType);
    await tester.tap(find.byKey(const Key('quick-goal-create')));
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goals_quick_create_reality_430x932.png'),
      );
    }
    await tester.enterText(
      find.byKey(const Key('quick-goal-starting-point')),
      'The counter is crowded and I avoid deciding where things go',
    );
    await tester.enterText(
      find.byKey(const Key('quick-goal-proof')),
      'The counter stays usable for a normal week',
    );
    await tester.enterText(
      find.byKey(const Key('quick-goal-obstacle')),
      'the whole apartment feels like too much after class',
    );
    await tester.enterText(
      find.byKey(const Key('quick-goal-horizon')),
      'Before the semester begins',
    );
    await tester.tap(find.byKey(const Key('quick-goal-create')));
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goals_quick_create_handoff_430x932.png'),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('goals personal index: hard-day return', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      Clock.reset();
    });
    Clock.freeze(DateTime(2026, 8, 25, 10));
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);
    final state = GameState()
      ..reduceMotion = true
      ..soundEnabled = false;
    final goal = Goal(
      title: 'Make mornings feel less sharp',
      stat: Stat.vit,
      target: 25,
      progress: 6,
      why: 'I want to arrive in the day without rushing.',
      fallbackCue: 'I wake up depleted',
      fallbackAction: 'open the curtains and drink water',
      firstProofTitle: 'Made breakfast before opening my inbox',
      firstProofDay: '2026-08-20',
    );
    state.goals.add(goal);
    final quests = <Quest>[
      Quest(
        title: 'Prepare tomorrow’s clothes',
        stat: Stat.vit,
        difficulty: 2,
        goalTitle: goal.title,
        snoozedDay: '2026-08-25',
      ),
    ];

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
        home: Scaffold(
          body: GoalsPage(
            state: state,
            quests: quests,
            onAdd: (_) => true,
            onRemoveQuest: (_) {},
            onRemoveGoal: (_) {},
            onPersist: () {},
            onOpenQuest: (_) {},
          ),
        ),
      ),
    );
    await _precachePageArt(tester);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goals_personal_index_hard_day_430x932.png'),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('goals personal index: dense scrolled', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);
    final state = GameState()
      ..reduceMotion = true
      ..soundEnabled = false;
    final goals = <Goal>[
      Goal(
        title: 'Tend the apartment',
        stat: Stat.dis,
        target: 25,
        progress: 9,
      ),
      Goal(
        title: 'Build a walking habit',
        stat: Stat.vit,
        target: 25,
        progress: 17,
      ),
      Goal(
        title: 'Read books that stay with me',
        stat: Stat.intl,
        target: 25,
        progress: 4,
      ),
      Goal(
        title: 'Keep a creative practice',
        stat: Stat.foc,
        target: 25,
        progress: 8,
      ),
      Goal(
        title: 'Reach out more often',
        stat: Stat.soc,
        target: 25,
        progress: 3,
      ),
      Goal(
        title: 'Finish the portfolio case study',
        stat: Stat.foc,
        kind: GoalKind.achieve,
        target: 12,
        progress: 12,
        achievedDay: '2026-08-24',
      ),
    ];
    state.goals.addAll(goals);
    state.featuredGoalTitles.add(goals.first.title);
    final quests = <Quest>[
      Quest(
        title: 'Put the shoes away',
        stat: Stat.dis,
        difficulty: 1,
        goalTitle: goals.first.title,
      ),
      Quest(
        title: 'Walk around the block',
        stat: Stat.vit,
        difficulty: 2,
        goalTitle: goals[1].title,
      ),
    ];

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
        home: Scaffold(
          body: GoalsPage(
            state: state,
            quests: quests,
            onAdd: (_) => true,
            onRemoveQuest: (_) {},
            onRemoveGoal: (_) {},
            onPersist: () {},
            onOpenQuest: (_) {},
          ),
        ),
      ),
    );
    await _precachePageArt(tester);
    final otherGoals = find.byKey(const Key('other-goals-disclosure'));
    await tester.scrollUntilVisible(
      otherGoals,
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(otherGoals),
      alignment: 0.35,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(otherGoals);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -420));
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goals_personal_index_dense_scrolled_430x932.png',
        ),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('goal detail: chosen support and proof', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);
    final state = GameState()
      ..reduceMotion = true
      ..soundEnabled = false;
    final draftedRoute = GoalPlanner.draft(
      GoalPlanInput(
        title: 'Make the apartment feel calm',
        stat: Stat.dis,
        type: GoalRouteType.reset,
        outcome: 'I can use the kitchen without feeling overwhelmed',
        startingPoint:
            'The counter is crowded and I avoid deciding where things go',
        successProof: 'The counter stays usable for a normal week',
        timeBudgetMinutes: 15,
        obstacleCue: 'the whole apartment feels like too much after class',
        now: DateTime(2026, 8, 25),
      ),
    );
    final detailRoutePlan = draftedRoute.copyWith(
      steps: [
        draftedRoute.steps.first.copyWith(
          completions: 1,
          completedDay: '2026-08-18',
        ),
        ...draftedRoute.steps.skip(1),
      ],
      adjustments: const [
        GoalPlanAdjustment(
          day: '2026-08-20',
          signal: GoalPlanSignal.tooBig,
          fromAction: 'Reset the whole kitchen after class',
          toAction: 'Clear one hand-sized surface',
        ),
      ],
    );
    final goal = Goal(
      title: 'Make the apartment feel calm',
      stat: Stat.dis,
      kind: GoalKind.achieve,
      target: detailRoutePlan.steps.fold(
        0,
        (total, step) => total + step.requiredCompletions,
      ),
      progress: 1,
      why: 'Home should feel easier to return to.',
      fallbackCue: detailRoutePlan.obstacleCue,
      fallbackAction: detailRoutePlan.fallbackAction,
      firstProofTitle: 'Cleared the entry table',
      firstProofDay: '2026-08-18',
      plan: detailRoutePlan,
    );
    state.goals.add(goal);
    final quests = <Quest>[
      Quest(
        title: detailRoutePlan.currentStep!.actionTitle,
        stat: Stat.dis,
        difficulty: 2,
        goalTitle: goal.title,
        goalPlanStepId: detailRoutePlan.currentStep!.id,
        goalPlanRevision: detailRoutePlan.revision,
        goalPlanAttempt: 1,
      ),
    ];

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
        home: GoalDetailScreen(
          goal: goal,
          state: state,
          quests: quests,
          onRemoveGoal: (_) {},
          onPersist: () {},
          onAddQuest: (_) => true,
          onOpenQuest: (_) {},
          onAdjustPlan: () {},
        ),
      ),
    );
    await _precachePageArt(tester);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goal_detail_entry_430x932.png'),
      );
    }
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -430));
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goal_detail_habit_support_430x932.png'),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('goal detail: 2x text keeps proof and return plan readable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);
    final state = GameState()
      ..reduceMotion = true
      ..soundEnabled = false;
    final goal = Goal(
      title: 'Make the apartment feel calm enough to come home to',
      stat: Stat.dis,
      target: 25,
      progress: 11,
      why: 'Home should feel easier to return to, even after a long day.',
      fallbackCue: 'the whole apartment feels like too much',
      fallbackAction: 'clear one hand-sized surface and leave the rest',
    );
    final quests = <Quest>[
      Quest(
        title: 'Clear the kitchen counter beside the sink',
        stat: Stat.dis,
        difficulty: 2,
        goalTitle: goal.title,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: GoalDetailScreen(
          goal: goal,
          state: state,
          quests: quests,
          onRemoveGoal: (_) {},
          onPersist: () {},
          onAddQuest: (_) => true,
          onOpenQuest: (_) {},
        ),
      ),
    );
    await _precachePageArt(tester);
    expect(tester.takeException(), isNull);

    final proof = find.text('Proof you’ve been here');
    await tester.scrollUntilVisible(
      proof,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(proof, findsOneWidget);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goal_detail_2x_proof_320x568.png'),
      );
    }

    final plan = find.byKey(const Key('goal-support-plan'));
    await tester.scrollUntilVisible(
      plan,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goal_detail_2x_support_320x568.png'),
      );
    }
    expect(find.text('When the day shrinks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('goal Quest handoff: room travel sequence', (tester) async {
    Clock.freeze(DateTime(2026, 8, 26, 10));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      Clock.reset();
    });
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);
    final state = GameState()..soundEnabled = false;
    final goal = Goal(
      title: 'Make the apartment feel calm',
      stat: Stat.dis,
      target: 25,
      progress: 11,
      why: 'Home should feel easier to return to.',
      fallbackCue: 'the whole apartment feels like too much',
      fallbackAction: 'clear one small surface',
    );
    state.goals.add(goal);
    final quests = <Quest>[
      Quest(
        title: 'Clear the kitchen counter',
        stat: Stat.dis,
        difficulty: 2,
        goalTitle: goal.title,
      ),
    ];
    Quest? openedQuest;

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
        home: Scaffold(
          body: GoalsPage(
            state: state,
            quests: quests,
            onAdd: (_) => true,
            onRemoveQuest: (_) {},
            onRemoveGoal: (_) {},
            onPersist: () {},
            onOpenQuest: (quest) => openedQuest = quest,
          ),
        ),
      ),
    );
    await _precachePageArt(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('focus-goal-action')));
    await tester.pump();
    expect(find.byKey(const Key('focus-goal-action')), findsOneWidget);
    expect(find.text('Opening'), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));

    expect(find.byKey(const Key('goal-room-travel-backdrop')), findsOneWidget);
    expect(find.byKey(const Key('goal-room-travel-master')), findsOneWidget);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goal_room_travel_01_departure_430x932.png'),
      );
    }
    await tester.pump(const Duration(milliseconds: 250));
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goal_room_travel_02_bridge_430x932.png'),
      );
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('goal-room-arch-invitation')), findsOneWidget);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goal_detail_transition_midpoint_430x932.png',
        ),
      );
    }
    await tester.pump(const Duration(milliseconds: 330));
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goal_room_travel_03_crossing_430x932.png'),
      );
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const Key('goal-room-travel-destination')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('goal-room-arch-invitation')), findsNothing);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goal_room_travel_04_arrival_430x932.png'),
      );
    }
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const Key('goal-quest-arrival')), findsOneWidget);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goal_room_travel_05_quest_arrival_430x932.png',
        ),
      );
    }
    await tester.pump(const Duration(milliseconds: 370));
    await tester.pumpAndSettle();
    expect(find.byType(GoalDetailScreen), findsNothing);
    expect(identical(openedQuest, quests.first), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('goals personal index: empty', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);
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
        home: Scaffold(
          body: GoalsPage(
            state: state,
            quests: const [],
            onAdd: (_) => true,
            onRemoveQuest: (_) {},
            onRemoveGoal: (_) {},
            onPersist: () {},
            onOpenQuest: (_) {},
          ),
        ),
      ),
    );
    await _precachePageArt(tester);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goals_personal_index_empty_430x932.png'),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('store screenshot story: share a moment', (tester) async {
    tester.view.devicePixelRatio = 3;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);

    final state = GameState()
      ..onboarded = true
      ..setPlayerName('Alex')
      ..level = 18
      ..streakDays = 12
      ..totalCompletions = 158
      ..wallStyle = 'wall_walnut'
      ..roomCode = 'ABC234';

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF14100D),
          body: ShareMomentSheet(state: state, level: 18),
        ),
      ),
    );
    // decode the room plate for real before capturing (same reason as the
    // routine art: the fake-async clock never finishes Image.asset on its own)
    final context = tester.element(find.byType(MaterialApp));
    await tester.runAsync(() async {
      await precacheImage(
        AssetImage(spaceThemeById(state.wallStyle)!.plateAsset),
        context,
      );
    });
    await _storeShot(tester, '13_share_moment_1290x2796');
  });

  testWidgets('store screenshot story: Discover', (tester) async {
    // Keep this in the canonical store harness: 430×932 logical points at 3×
    // produces Apple's required 1290×2796 submission class without upscaling.
    tester.view.devicePixelRatio = 3;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);

    final state = GameState()
      ..onboarded = true
      ..setPlayerName('Alex')
      ..level = 18
      ..totalXp = 4280
      ..embers = 340
      ..reduceMotion = true
      ..soundEnabled = false
      ..wallStyle = 'wall_walnut'
      ..floorStyle = 'floor_oak'
      ..windowScene = 'moon'
      ..creatureSkin = 'sunstone';
    final spaces = <DiscoverableSpaceSummary>[
      const DiscoverableSpaceSummary(
        code: 'ARC234',
        buildTitle: 'DEEP CURRENT',
        level: 21,
        wall: 'wall_archive',
        floor: 'floor_cherry',
        skin: 'moon_pearl',
        window: 'aurora',
        bucket: 1,
        ownerKey:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        publicName: 'Rowan',
      ),
      const DiscoverableSpaceSummary(
        code: 'GRN234',
        buildTitle: 'EVERGREEN',
        level: 14,
        wall: 'wall_conservatory',
        floor: 'floor_maple',
        skin: 'sea_glass',
        window: 'rain',
        bucket: 2,
        ownerKey:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        publicName: 'Juniper',
      ),
      const DiscoverableSpaceSummary(
        code: 'WRM234',
        buildTitle: 'STEADY HAND',
        level: 9,
        wall: 'wall_walnut',
        floor: 'floor_oak',
        skin: 'sunstone',
        window: 'moon',
        bucket: 3,
        ownerKey:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DiscoverSpacesScreen(
          state: state,
          onPersist: () {},
          fetchSpaces: () async => spaces,
          fetchRoom: (_) async => null,
          publicDiscoveryNamesEnabled: true,
        ),
      ),
    );
    await _storeShot(tester, '07_discover_1290x2796');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
