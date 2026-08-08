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

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/cloud.dart';
import 'package:emberkeep/content/creature_skins.dart';
import 'package:emberkeep/content/day_planning.dart';
import 'package:emberkeep/content/furniture.dart';
import 'package:emberkeep/content/routines.dart';
import 'package:emberkeep/content/space_themes.dart';
import 'package:emberkeep/widgets/routine_flows.dart';
import 'package:emberkeep/widgets/share_moment_card.dart';
import 'package:emberkeep/content/room_styles.dart';
import 'package:emberkeep/content/window_scenes.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/main.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/journal_entry.dart';
import 'package:emberkeep/screens/journal_hub.dart';
import 'package:emberkeep/screens/hearth_circle.dart';
import 'package:emberkeep/screens/memory_cabinet.dart';
import 'package:emberkeep/screens/me.dart';
import 'package:emberkeep/screens/quests.dart';
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

/// Decode the three primary desk plates before comparing their destinations.
/// Widget-test fake time does not complete image codecs reliably, which made
/// Goals, Plans, and a fresh Journal look like featureless black screens even
/// though production resolves the same bundled assets normally.
Future<void> _precachePageArt(WidgetTester tester) async {
  const assets = <String>[
    'assets/pages/goals-desk-v2.webp',
    'assets/pages/plans-desk-v2.webp',
    'assets/pages/journal-desk-v2.webp',
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
  tearDownAll(() => GameState.debugRandomFactory = null);

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
    final state = GameState()
      ..onboarded = true
      ..playerName = 'Mika'
      ..level = 7
      ..xp = 118
      ..totalXp = 980
      ..streakDays = 6
      ..bestStreak = 11
      ..lastActiveDay = '2026-07-07'
      ..lastCompletionDay = '2026-07-07';
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
    }
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
          onFinish: ({required forgeFirstGoal, required timeShape}) {},
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
        const AssetImage('assets/pages/journal-desk-v2.webp'),
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
      ..creatureSkin = 'sunstone';
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
      shared: false,
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

    await tester.tap(find.text('Help for this kind of day'));
    await tester.pump(const Duration(milliseconds: 600));
    await _storeShot(tester, '04b_momentum_kits_1290x2796');
    await tester.tap(find.text('Gentle Mode Day'));
    await tester.pump(const Duration(milliseconds: 450));
    await _storeShot(tester, '04c_low_flame_1290x2796');
    await tester.tap(find.text('CHOOSE 2 STEPS'));
    await tester.pump(const Duration(milliseconds: 350));
    await _storeShot(tester, '04d_low_flame_lit_1290x2796');
    await tester.tap(find.text('OPEN QUESTS'));
    await tester.pump(const Duration(milliseconds: 800));
    await _storeShot(tester, '04e_kit_quests_1290x2796');

    _activateDock(tester, Icons.calendar_month_outlined);
    await tester.pump(const Duration(milliseconds: 450));
    await _storeShot(tester, '05_planner_1290x2796');
    await tester.tap(find.text('+ PLAN'));
    await tester.pump(const Duration(milliseconds: 350));
    await _storeShot(tester, '05b_planner_shapes_1290x2796');
    await tester.tapAt(const Offset(12, 12));
    await tester.pump(const Duration(milliseconds: 350));

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
      ..journal = [firstMoment, secondMoment]
      ..memoryPins.addAll({firstMoment.id, secondMoment.id});
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
      intro:
          'I make things, care for people, and keep trying to notice the days while they are here.',
      featuredGoalTitles: state.goals.map((goal) => goal.title),
      seasonText:
          'Finishing one chapter slowly, keeping the windows open, and letting August be August.',
      profilePhotoNoteId: null,
      seasonPhotoNoteId: null,
      shareProfilePhoto: false,
      shareSeasonPhoto: false,
      shareProfile: false,
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
            onReset: () {},
            onNotifyChanged: () async {},
            onEnableCloud: () async => null,
            onLinkAccount: (_, _) async => null,
            onSignIn: (_, _) async => null,
            onSignOut: () async {},
            onDeleteAccount: (_) async => null,
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
}
