// A visual harness: renders the code-painted widgets and primary shell
// window scenes, the journal hub) to PNGs via golden files, so I can actually
// SEE what the CustomPainters produce instead of shipping blind. Regenerate:
//   flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true \
//     test/screenshots_test.dart
// then open test/goldens/*.png. Not a pass/fail guard — purely a render dump.
// (round-62 pivot: the creature is gone; the keep + its hearth are the star.)
import 'dart:convert';

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/creature_skins.dart';
import 'package:emberkeep/content/furniture.dart';
import 'package:emberkeep/content/room_styles.dart';
import 'package:emberkeep/content/window_scenes.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/main.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/journal_hub.dart';
import 'package:emberkeep/storage.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/constellation.dart';
import 'package:emberkeep/widgets/home_room.dart';
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

Future<void> _shoot(WidgetTester tester, Widget w, String name) async {
  await tester.pumpWidget(w);
  await tester.pump(const Duration(milliseconds: 120));
  if (_capture) {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }
}

Future<void> _storeShot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 240));
  if (_captureStore) {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/store_$name.png'),
    );
  }
}

void _activateDock(WidgetTester tester, IconData icon) {
  final tapTarget = find
      .ancestor(of: find.byIcon(icon), matching: find.byType(GestureDetector))
      .first;
  tester.widget<GestureDetector>(tapTarget).onTap!.call();
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
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await loader.load();
    GoogleFonts.config.allowRuntimeFetching = false; // no network in tests
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
    const furn = {'rug', 'lamp', 'plant', 'shelf', 'picture', 'garland'};
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
    const furn = {'rug', 'lamp', 'plant', 'shelf', 'picture', 'garland'};

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
      ),
      Note(
        at: DateTime(2026, 7, 2, 8, 15),
        text: 'Morning pages: what I want this week to feel like.',
      ),
      Note(
        at: DateTime(2026, 6, 24, 19),
        text: 'A quieter reflection from last month — looking back already.',
        context: 'Emberkeeper',
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
      ..soundEnabled = false
      ..reduceMotion = true
      ..wallStyle = 'wall_plum'
      ..floorStyle = 'floor_maple'
      ..windowScene = 'moon'
      ..creatureSkin = 'sunstone';
    state.stats[Stat.str] = 88;
    state.stats[Stat.vit] = 72;
    state.stats[Stat.intl] = 116;
    state.stats[Stat.foc] = 94;
    state.stats[Stat.soc] = 61;
    state.stats[Stat.dis] = 103;
    state.ownedFurniture.addAll({
      'rug',
      'lamp',
      'plant',
      'shelf',
      'picture',
      'chair',
      'candles',
      'garland',
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
    await _storeShot(tester, '01_quests_1290x2796');

    _activateDock(tester, Icons.emoji_emotions_outlined);
    await tester.pump(const Duration(milliseconds: 450));
    await _storeShot(tester, '02_keep_1290x2796');

    await tester.tap(find.text('FURNISH'));
    await tester.pump(const Duration(milliseconds: 450));
    await _storeShot(tester, '03_shop_1290x2796');
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump(const Duration(milliseconds: 700));

    _activateDock(tester, Icons.explore_outlined);
    await tester.pump(const Duration(milliseconds: 450));
    await _storeShot(tester, '04_goals_1290x2796');

    _activateDock(tester, Icons.insights_outlined);
    await tester.pump(const Duration(milliseconds: 450));
    await _storeShot(tester, '05_insights_1290x2796');

    // Dispose AppShell so its midnight rollover timer cannot escape the test.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
