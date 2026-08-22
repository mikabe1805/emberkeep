import 'package:emberkeep/engine.dart';
import 'package:emberkeep/release_features.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('space discovery is absent from ordinary release builds', () {
    if (kSpaceDiscoveryEnabled) {
      expect(kPublicDiscoveryNamesEnabled, isFalse);
      return;
    }
    expect(kSpaceDiscoveryEnabled, isFalse);
    expect(kPublicDiscoveryNamesEnabled, isFalse);
  });

  test(
    'discoverability defaults private and round-trips only when enabled',
    () {
      final state = GameState();
      expect(state.roomDiscoverable, isFalse);

      state.setRoomCode('ABC234');
      state.setRoomDiscoverable(true);
      state.setRoomDiscoveryName('  Mika\n Days  ');
      final restored = GameState.fromJson(state.toJson());
      expect(restored.roomCode, 'ABC234');
      expect(restored.roomDiscoverable, kSpaceDiscoveryEnabled);
      expect(
        restored.roomDiscoveryName,
        kSpaceDiscoveryEnabled ? 'Mika Days' : isEmpty,
      );
      expect(restored.roomDiscoveryRemovalPending, !kSpaceDiscoveryEnabled);
      expect(
        restored.roomDiscoveryRemovalCodes,
        kSpaceDiscoveryEnabled ? isEmpty : {'ABC234'},
      );
      expect(restored.playerName, isNull);

      restored.setRoomCode(null);
      expect(restored.roomDiscoverable, isFalse);
      expect(restored.roomDiscoveryName, isEmpty);
      expect(restored.roomDiscoveryRemovalPending, isFalse);
      expect(restored.roomDiscoveryRemovalCodes, isEmpty);

      final malformed = GameState.fromJson({
        ...state.toJson(),
        'roomCode': null,
        'roomDiscoverable': true,
      });
      expect(malformed.roomDiscoverable, isFalse);
      expect(malformed.roomDiscoveryName, isEmpty);
      expect(malformed.roomDiscoveryRemovalPending, isFalse);
      expect(malformed.roomDiscoveryRemovalCodes, isEmpty);
    },
  );

  test(
    'disabled-build teardown survives saves until server acknowledgement',
    () {
      if (kSpaceDiscoveryEnabled) return;
      final restored = GameState.fromJson({
        'roomCode': 'ABC234',
        'roomDiscoverable': true,
        'roomDiscoveryName': 'Rowan',
      });

      expect(restored.roomDiscoverable, isFalse);
      expect(restored.roomDiscoveryName, isEmpty);
      expect(restored.roomDiscoveryRemovalPending, isTrue);
      expect(restored.roomDiscoveryRemovalCodes, {'ABC234'});
      expect(restored.toJson()['roomDiscoveryRemovalCodes'], ['ABC234']);

      restored.setRoomCode('DEF234');
      expect(restored.roomDiscoveryRemovalCodes, {'ABC234'});
      expect(restored.toJson()['roomDiscoveryRemovalCodes'], ['ABC234']);

      restored.confirmRoomDiscoveryRemoval('ABC234');
      expect(restored.roomDiscoveryRemovalPending, isFalse);
      expect(restored.roomDiscoveryRemovalCodes, isEmpty);
      expect(restored.toJson()['roomDiscoveryRemovalCodes'], isEmpty);
    },
  );

  test(
    'Circle remembers discovered names locally and blocking removes them',
    () {
      final state = GameState();
      expect(state.addCircleCode('DEF234', publicName: '  Rowan  '), isTrue);
      expect(state.hearthCircleNames, {'DEF234': 'Rowan'});

      final restored = GameState.fromJson(state.toJson());
      expect(restored.hearthCircleCodes, ['DEF234']);
      expect(restored.hearthCircleNames, {'DEF234': 'Rowan'});

      expect(restored.blockRoomCode('def234'), isTrue);
      expect(restored.hearthCircleCodes, isEmpty);
      expect(restored.hearthCircleNames, isEmpty);
      expect(restored.blockedRoomCodes, {'DEF234'});
      expect(restored.addCircleCode('DEF234'), isFalse);
    },
  );
}
