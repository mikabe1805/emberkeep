// Guards the sprite manifest: every frame MascotFrames declares must actually
// be bundled — all 7 skins × 6 stages × 2 moods — so an asset rename, a
// pubspec slip, or a botched regeneration can never silently strand a skin on
// the procedural fallback again (the exact failure mode of round-53's mess).
import 'dart:io';

import 'package:emberkeep/content/creature_skins.dart';
import 'package:emberkeep/widgets/mascot_sprite.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every skin declares a frame-set for every stage and mood', () {
    for (final skin in creatureSkins) {
      for (var stage = 0; stage <= 5; stage++) {
        for (final mood in const ['idle', 'happy']) {
          final frames = MascotFrames.framesFor(skin.id, stage, mood);
          expect(frames, isNotNull,
              reason: '${skin.id} s$stage $mood has no declared frames');
          expect(frames, isNotEmpty,
              reason: '${skin.id} s$stage $mood declares an empty frame-set');
        }
      }
    }
  });

  test('every declared mascot frame is actually bundled', () async {
    // rootBundle alone can pass against a STALE build/unit_test_assets copy,
    // so also stat the source tree (tests run with CWD = the package root)
    final sourceTree = Directory('assets/mascot').existsSync();
    for (final skin in creatureSkins) {
      for (var stage = 0; stage <= 5; stage++) {
        for (final mood in const ['idle', 'happy']) {
          for (final path in MascotFrames.framesFor(skin.id, stage, mood) ??
              const <String>[]) {
            final data = await rootBundle.load(path);
            expect(data.lengthInBytes, greaterThan(0),
                reason: '$path is empty');
            if (sourceTree) {
              expect(File(path).existsSync(), isTrue,
                  reason: '$path is missing from the source tree');
            }
          }
        }
      }
    }
  });

  test('the room grain textures and painted backdrops are bundled', () async {
    for (final path in const [
      'assets/room/wall_grain.png',
      'assets/room/floor_grain.png',
      'assets/backdrops/hearthside.webp',
      'assets/backdrops/candleglow.webp',
      'assets/backdrops/lamplight.webp',
    ]) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0), reason: '$path is empty');
    }
  });
}
