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
  'take_09': 'cf2bed4bdec77502b1b0f8846774585e6c896d5c652b86af5a407d1243ca9aa7',
  'take_10': '931e1ebea56474a35c2c0df7b621b2356dfdeb07895fe4131c4a60fc211f202d',
  'take_11': '4b759e1b06f88212d01e2946ded3f1be4ac272cfca1acbaadee99deb630ffed6',
  'take_12': '5591454bcad778635fad984d769a906fbb8a97b512ca9cb17b006af05f13091a',
  'take_13': '1ce6d7ec435fa6131509b3f497db820a02da5987db135c4f9f8b7a77ca7a0cf4',
  'take_14': '5fef299dd0bc802ea9ee11c5c0407fc81680e7fa5fe687a0842172cd9809de57',
  'take_15': '0a2fe545443ef4aaa95841245a817df8cf93ad5ed16501cabeb15258cfc993c1',
  'take_16': 'b445f79dc863ffbcc3471a47531157becf097db27d0e2393cc9cb7668f2b4383',
  'take_17': 'f5d91102c290e7fd1029b4e9bfa236f1b868454193d37d9de1fd8e4440082b99',
  'take_18': '7e77e233ba981336ee7120ec7d312c3677312b692da0a9bc7ddb3c251dbd1e38',
  'take_19': '2bcc4e80025f1a37a7e7e9b643d352d06d8b312441ea39135570b6c2b8c814d4',
  'take_20': '1813f0cc8dbe465b7039e8f87022b1490d46873deef290d886c361cc67abf8de',
  'take_21': 'b2456693e5b7d7787c2305521791f2977dd2b3460cd86ba50f01d951b572f3b7',
  'take_22': 'd62a28549b4c98edb19b8949853a509e491976905e2d6da13c48c69f7c8b4f7c',
};

const _focusDigest =
    'e4162909e9a5063e5d087b267346a9bf4383fcdb47a38e91fae1843271534d9e';
const _lampLeftOnDigest =
    'a1b84c0b850e03131e5a22269cac7aa2532ad6a0fce5a31dea21e17d40078cc3';

String _digest(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString();

void main() {
  test('the approved dry rotation takes retain their approved encodes', () {
    expect(MainRoomMusic.dryTakeCount, 22);
    expect(MainRoomMusic.takeAssets, hasLength(23));
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

  test('Lamp left on stays the approved distinct normal-room composition', () {
    const asset = 'music/lamp-left-on.m4a';
    const path = 'assets/$asset';
    expect(File(path).existsSync(), isTrue, reason: 'missing $path');
    expect(_digest(path), _lampLeftOnDigest);
    expect(MainRoomMusic.takeCount, 23);
    expect(MainRoomMusic.assetForTake(MainRoomMusic.lampLeftOnTake), asset);
    expect(MainRoomMusic.takeAssets, contains(asset));
    expect(MainRoomMusic.takeAssets, [
      for (var take = 1; take <= MainRoomMusic.takeCount; take++)
        MainRoomMusic.assetForTake(take),
    ]);
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/music/'),
    );
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

  test('an explicit dry rotation plays every take before a repeat', () {
    for (var seed = 0; seed < 32; seed++) {
      final rotation = MusicRotation(
        random: math.Random(seed),
        takeCount: MainRoomMusic.dryTakeCount,
      );
      final draws = [for (var i = 0; i < 88; i++) rotation.next()];
      for (var i = 1; i < draws.length; i++) {
        expect(draws[i], isNot(draws[i - 1]));
      }
      for (var bag = 0; bag < 4; bag++) {
        expect(draws.sublist(bag * 22, bag * 22 + 22).toSet(), {
          for (var take = 1; take <= MainRoomMusic.dryTakeCount; take++) take,
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
    expect(offline, contains('assets/assets/music/lamp-left-on.m4a'));
    expect(
      offline.indexOf('if (_musicDeferred.contains(relative)) return false;'),
      greaterThanOrEqualTo(0),
    );
  });
}
