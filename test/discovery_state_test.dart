import 'package:emberkeep/engine.dart';
import 'package:emberkeep/discovery.dart';
import 'package:emberkeep/release_features.dart';
import 'package:emberkeep/social.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'space discovery is absent from ordinary release builds',
    () {
      expect(kSpaceDiscoveryEnabled, isFalse);
      expect(kPublicDiscoveryNamesEnabled, isFalse);
    },
    skip: kSpaceDiscoveryEnabled
        ? 'This invocation deliberately verifies the feature-on candidate.'
        : false,
  );

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

  test('failed relist after a room-code rotation clears the listed claim', () {
    final failed = GameState()
      ..setRoomCode('ABC234')
      ..setRoomDiscoverable(true)
      ..setRoomDiscoveryName('Rowan')
      ..setRoomCode('DEF234');

    expect(
      reconcileDiscoveryAfterRoomPublish(
        state: failed,
        roomCodeChanged: true,
        directoryRefreshed: false,
      ),
      isTrue,
    );
    expect(failed.roomDiscoverable, isFalse);
    expect(failed.roomDiscoveryName, isEmpty);
    expect(failed.roomDiscoveryRemovalPending, isTrue);
    expect(failed.roomDiscoveryRemovalCodes, {'DEF234'});

    final acknowledged = GameState()
      ..setRoomCode('ABC234')
      ..setRoomDiscoverable(true)
      ..setRoomCode('DEF234');
    expect(
      reconcileDiscoveryAfterRoomPublish(
        state: acknowledged,
        roomCodeChanged: true,
        directoryRefreshed: true,
      ),
      isFalse,
    );
    expect(acknowledged.roomDiscoverable, isTrue);
  });

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

  test('owner blocks survive code rotation and Circle learns owner keys', () {
    final ownerKey = discoveryOwnerKey('friend-uid');
    final state = GameState();
    expect(state.addCircleCode('DEF234'), isTrue);
    expect(state.rememberCircleOwnerKey('DEF234', ownerKey), isTrue);
    expect(state.blockDiscoveryOwner(ownerKey, 'DEF234'), isTrue);
    expect(state.hearthCircleCodes, isEmpty);
    expect(state.blockedDiscoveryOwners, {ownerKey: 'DEF234'});
    expect(state.addCircleCode('GHJ234', ownerKey: ownerKey), isFalse);

    final restored = GameState.fromJson(state.toJson());
    expect(restored.blockedDiscoveryOwners, {ownerKey: 'DEF234'});
    restored.unblockDiscoveryOwner(ownerKey);
    expect(restored.blockedDiscoveryOwners, isEmpty);
    expect(restored.addCircleCode('GHJ234', ownerKey: ownerKey), isTrue);
  });
}
