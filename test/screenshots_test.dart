// A throwaway visual harness: renders the code-painted widgets (the character
// portrait, the home room) to PNGs via golden files, so I can actually SEE
// what the CustomPainters produce instead of shipping blind. Regenerate with:
//   flutter test --update-goldens test/screenshots_test.dart
// then open test/goldens/*.png. Not a pass/fail guard — purely a render dump.
import 'package:emberkeep/content/creature_skins.dart';
import 'package:emberkeep/content/furniture.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/home_room.dart';
import 'package:emberkeep/widgets/portrait.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _stage(Widget child, {Color bg = const Color(0xFF241A20), double pad = 28}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: bg,
      body: Center(child: Padding(padding: EdgeInsets.all(pad), child: child)),
    ),
  );
}

// Golden renders are platform-fragile, so the PNG capture is OFF by default:
// a normal `flutter test` run still pumps every widget (a real smoke test that
// they build), but skips the file compare so CI never breaks on font/AA drift.
// To regenerate the reference images locally:
//   flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true \
//     test/screenshots_test.dart
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
  testWidgets('portrait: level 1, neutral', (tester) async {
    await _shoot(tester, _stage(const Portrait(size: 240)), 'portrait_lvl1');
  });

  testWidgets('portrait: level 1, happy', (tester) async {
    await _shoot(
      tester,
      _stage(const Portrait(size: 240, mood: PortraitMood.happy)),
      'portrait_lvl1_happy',
    );
  });

  testWidgets('portrait: level 10 (frame)', (tester) async {
    await _shoot(
      tester,
      _stage(const Portrait(
          size: 240, level: 10, aura: Palette.verify, mood: PortraitMood.happy)),
      'portrait_lvl10',
    );
  });

  testWidgets('portrait: level 24 (more frame)', (tester) async {
    await _shoot(
      tester,
      _stage(const Portrait(
          size: 240, level: 24, aura: Palette.unlock, mood: PortraitMood.happy)),
      'portrait_lvl24',
    );
  });

  testWidgets('portrait: INT trait (glasses)', (tester) async {
    await _shoot(
      tester,
      _stage(const Portrait(
          size: 240, level: 8, trait: Stat.intl, mood: PortraitMood.happy)),
      'portrait_trait_int',
    );
  });

  testWidgets('portrait: evolution ladder', (tester) async {
    await _shoot(
      tester,
      _stage(
        bg: const Color(0xFF1C141A),
        pad: 14,
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Portrait(size: 104, level: 1, mood: PortraitMood.happy),
            SizedBox(width: 8),
            Portrait(size: 104, level: 6, aura: Palette.success),
            SizedBox(width: 8),
            Portrait(size: 104, level: 11, aura: Palette.verify),
            SizedBox(width: 8),
            Portrait(size: 104, level: 16, aura: Palette.streak),
            SizedBox(width: 8),
            Portrait(size: 104, level: 24, aura: Palette.unlock),
            SizedBox(width: 8),
            Portrait(size: 104, level: 34, aura: Palette.dread),
          ],
        ),
      ),
      'portrait_evolution',
    );
  });

  testWidgets('portrait: skins', (tester) async {
    await _shoot(
      tester,
      _stage(
        bg: const Color(0xFF1C141A),
        pad: 14,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final sk in creatureSkins) ...[
              Portrait(
                  size: 96,
                  level: 8,
                  mood: PortraitMood.happy,
                  skin: sk.colors),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
      'portrait_skins',
    );
  });

  testWidgets('portrait: small HUD sizes', (tester) async {
    await _shoot(
      tester,
      _stage(
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Portrait(size: 28),
            SizedBox(width: 20),
            Portrait(size: 40, mood: PortraitMood.happy),
            SizedBox(width: 20),
            Portrait(size: 56, level: 16, mood: PortraitMood.happy),
          ],
        ),
      ),
      'portrait_small',
    );
  });

  testWidgets('room: style variants', (tester) async {
    await tester.binding.setSurfaceSize(const Size(520, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const furn = {'rug', 'lamp', 'plant', 'shelf', 'picture', 'garland'};
    Widget room(List<Color> wall, List<Color> floor) => SizedBox(
          width: 460,
          child: HomeRoom(
            unlocked: furn,
            wall: wall,
            floor: floor,
            child: const Portrait(size: 96, level: 8, mood: PortraitMood.happy),
          ),
        );
    await _shoot(
      tester,
      _stage(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            room(const [Color(0xFF312339), Color(0xFF3E2E48)],
                const [Color(0xFF3C2C20), Color(0xFF2A1D14)]), // plum / oak
            const SizedBox(height: 14),
            room(const [Color(0xFF27302A), Color(0xFF333E36)],
                const [Color(0xFF4A2C1E), Color(0xFF31180E)]), // sage / terra
            const SizedBox(height: 14),
            room(const [Color(0xFF232A3C), Color(0xFF2F3A55)],
                const [Color(0xFF2C1E16), Color(0xFF1C120C)]), // midnight / walnut
          ],
        ),
        pad: 16,
      ),
      'room_styles',
    );
  });

  testWidgets('room: empty', (tester) async {
    await _shoot(
      tester,
      _stage(
        SizedBox(
          width: 460,
          child: HomeRoom(
            unlocked: const {},
            child: const Portrait(size: 110, level: 1),
          ),
        ),
      ),
      'room_empty',
    );
  });

  testWidgets('room: fully furnished', (tester) async {
    await _shoot(
      tester,
      _stage(
        SizedBox(
          width: 460,
          child: HomeRoom(
            unlocked: {for (final f in furniture) f.id},
            child: const Portrait(
                size: 110, level: 20, mood: PortraitMood.happy),
          ),
        ),
      ),
      'room_full',
    );
  });
}
