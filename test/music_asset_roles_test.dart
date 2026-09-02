import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:emberkeep/main_room_music.dart';
import 'package:flutter_test/flutter_test.dart';

const _mainDigests = <String, String>{
  'take_01': '01af8c87ade76bbbfac6ee2f5d44fcaa0abdbb0e31dfd9b3716879c52e271060',
  'take_02': 'a4a79dec582678905981ebe5f7ba06e3256cc80c79b0536733b742a61daa3031',
  'take_03': 'd6f9cff4185f3246a90751b6039fefa7aad9400025ab584b9b96d13c62ffea44',
  'take_04': '605b22e0c1a644436d10ac36cb76689ce2ee945b9122554432fefffc905d757c',
  'take_05': 'ec809ba23db4591be2c2f8754091d347c059236ef25032c3a5309db4a83e6e83',
  'take_06': '7c54e66c31774e1f78ea2116d76edc226d13c84489f89380f99e34b98691e785',
  'take_07': '6e50ac28a2d11c4bc4deab32ebfd7c8ad679ee7999d1b9bbccfa24d3d6e438da',
  'take_08': 'da90a51fbd0f405b7e8901004420ecab028a159365c4989c8df709304b07aa77',
};

const _focusDigest =
    'e4162909e9a5063e5d087b267346a9bf4383fcdb47a38e91fae1843271534d9e';

String _digest(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString();

void main() {
  test('normal Room music is the eight approved umbrella-brush takes', () {
    expect(MainRoomMusic.takeAssets, hasLength(8));
    for (final entry in _mainDigests.entries) {
      final path = 'assets/music/${entry.key}.m4a';
      expect(File(path).existsSync(), isTrue, reason: 'missing $path');
      expect(
        _digest(path),
        entry.value,
        reason: '$path must remain the approved encoded take',
      );
      expect(MainRoomMusic.takeAssets, contains('music/${entry.key}.m4a'));
    }
  });

  test(
    'Focus owns a distinct meditation asset and no legacy alias remains',
    () {
      const focus = 'assets/music/focus-meditation.m4a';
      expect(File(focus).existsSync(), isTrue);
      expect(_digest(focus), _focusDigest);
      expect(File('assets/music/room-theme.m4a').existsSync(), isFalse);
      expect(_mainDigests.values, isNot(contains(_focusDigest)));

      final controller = File('lib/background_music.dart').readAsStringSync();
      expect(controller, contains("focusAsset = 'music/focus-meditation.m4a'"));
      expect(controller, isNot(contains("asset = 'music/room-theme.m4a'")));
    },
  );

  test('main rotation plays every take before a non-adjacent repeat', () {
    for (var seed = 0; seed < 32; seed++) {
      final rotation = MusicRotation(random: math.Random(seed));
      final draws = [for (var i = 0; i < 64; i++) rotation.next()];
      for (var i = 1; i < draws.length; i++) {
        expect(draws[i], isNot(draws[i - 1]));
      }
      for (var bag = 0; bag < 8; bag++) {
        expect(draws.sublist(bag * 8, bag * 8 + 8).toSet(), {
          1,
          2,
          3,
          4,
          5,
          6,
          7,
          8,
        });
      }
    }
  });

  test('all long-form music stays out of the web first-frame core', () {
    final offline = File('tool/prepare_web_offline.dart').readAsStringSync();
    expect(offline, contains('assets/assets/music/focus-meditation.m4a'));
    for (final name in _mainDigests.keys) {
      expect(offline, contains('assets/assets/music/$name.m4a'));
    }
    expect(
      offline.indexOf('if (_musicDeferred.contains(relative)) return false;'),
      greaterThanOrEqualTo(0),
    );
  });
}
