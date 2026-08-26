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
    // The archived Gen-1 palette (tap_*, tick*, complete, hearth_room) was
    // removed from the bundle on 2026-08-25; only live event voices remain
    // at the sfx root. Provenance stays in assets/sfx/SOURCES.md.
    for (final name in const [
      'boing',
      'crit',
      'hearth',
      'fire_ignite',
      'levelup',
      'loot',
      'stat_0',
      'stat_1',
      'stat_2',
      'stat_3',
      'stat_4',
      'stat_5',
      'streak',
    ]) {
      final data = await rootBundle.load('assets/sfx/$name.wav');
      expect(
        data.lengthInBytes,
        greaterThan(0),
        reason: 'assets/sfx/$name.wav is empty',
      );
    }

    for (final role in const ['open', 'select', 'navigate', 'place']) {
      for (var take = 1; take <= 5; take++) {
        final path = 'assets/sfx/room/ordinary/$role/$take.wav';
        final data = await rootBundle.load(path);
        expect(data.lengthInBytes, greaterThan(0), reason: '$path is empty');
      }
    }
    for (final token in const ['d5', 'a5', 'e5']) {
      for (final role in const ['open', 'select', 'navigate', 'place']) {
        for (var take = 1; take <= 5; take++) {
          final path = 'assets/sfx/room/paired_return/$token/$role/$take.wav';
          final data = await rootBundle.load(path);
          expect(data.lengthInBytes, greaterThan(0), reason: '$path is empty');
        }
      }
    }
    for (final name in const [
      'accepted-select-2',
      'answered-detent-natural',
      'completion-composite',
    ]) {
      final path = 'assets/sfx/room/completion/$name.wav';
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0), reason: '$path is empty');
    }
  });
}
