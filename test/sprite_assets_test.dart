// Guards the sprite manifest: every frame MascotFrames declares must actually
// be bundled — all 11 skins (7 recolors + 4 outfits) × 6 stages × 2 moods —
// so an asset rename, a pubspec slip, or a botched regeneration can never
// silently strand a skin on the procedural fallback again (the exact failure
// mode of round-53's mess).
import 'dart:io';

import 'package:emberkeep/content/creature_skins.dart';
import 'package:emberkeep/content/scenes.dart';
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
    // same stale-build-copy caveat as the mascot test: stat the source tree
    // too, so a deleted painting can't hide behind build/unit_test_assets
    final sourceTree = Directory('assets/backdrops').existsSync();
    for (final path in [
      'assets/room/wall_grain.png',
      'assets/room/floor_grain.png',
      // every purchasable stage must ship its painting — a missing file only
      // falls back to a gradient, which nobody should be paying embers for
      for (final s in stageScenes) 'assets/backdrops/${s.id}.webp',
    ]) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0), reason: '$path is empty');
      if (sourceTree) {
        expect(File(path).existsSync(), isTrue,
            reason: '$path is missing from the source tree');
      }
    }
  });

  test('the sound palette is bundled', () async {
    // the r53 VCSL sample set was once silently clobbered by a stray synth
    // script — guard the files so a regression at least fails loudly
    for (final name in const [
      'boing', 'complete', 'crit', 'levelup', 'loot',
      'stat_0', 'stat_1', 'stat_2', 'stat_3', 'stat_4', 'stat_5',
      'streak', 'tick',
    ]) {
      final data = await rootBundle.load('assets/sfx/$name.wav');
      expect(data.lengthInBytes, greaterThan(0),
          reason: 'assets/sfx/$name.wav is empty');
    }
  });
}
