// Guards the remaining bundled art/audio assets. As of round-62 the character
// and the stage scenes are fully code-painted (no PNG mascot frames, no webp
// backdrops), so those guards are gone; what's left is the room grain textures
// and the SFX palette.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the room grain textures are bundled', () async {
    for (final path in const [
      'assets/room/wall_grain.png',
      'assets/room/floor_grain.png',
    ]) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0), reason: '$path is empty');
    }
  });

  test('the sound palette is bundled', () async {
    for (final name in const [
      'boing',
      'complete',
      'crit',
      'hearth',
      'fire_ignite',
      'hearth_room',
      'levelup',
      'loot',
      'stat_0',
      'stat_1',
      'stat_2',
      'stat_3',
      'stat_4',
      'stat_5',
      'streak',
      'tick',
      'tick_lift',
      'tick_warm',
      'tap_wood_1',
      'tap_wood_2',
      'tap_wood_3',
      'tap_stone_1',
      'tap_stone_2',
      'tap_stone_3',
      'tap_parchment_1',
      'tap_parchment_2',
      'tap_parchment_3',
      'tap_brass_1',
      'tap_brass_2',
      'tap_brass_3',
      'tap_glass_1',
      'tap_glass_2',
      'tap_glass_3',
    ]) {
      final data = await rootBundle.load('assets/sfx/$name.wav');
      expect(
        data.lengthInBytes,
        greaterThan(0),
        reason: 'assets/sfx/$name.wav is empty',
      );
    }
  });
}
