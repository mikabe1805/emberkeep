// A visual harness: renders the code-painted widgets and primary shell
// window scenes, the journal hub) to PNGs via golden files, so I can actually
// SEE what the CustomPainters produce instead of shipping blind. Regenerate:
//   flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true \
//     test/screenshots_test.dart
// then open test/goldens/*.png. Not a pass/fail guard — purely a render dump.
// (round-62 pivot: the creature is gone; the keep + its hearth are the star.)
import 'dart:convert';

import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/furniture.dart';
import 'package:emberkeep/content/window_scenes.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/main.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/journal_hub.dart';
import 'package:emberkeep/storage.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/home_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

const _capture = bool.fromEnvironment('CAPTURE_GOLDENS');

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

void main() {
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
    Widget keep(bool lit) => SizedBox(
      width: 500,
      child: HomeRoom(unlocked: furn, petAwake: lit),
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
}
