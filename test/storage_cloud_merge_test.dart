import 'dart:convert';

import 'package:emberkeep/engine.dart';
import 'package:emberkeep/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _save({
  required int schema,
  required int modified,
  bool omitRoomKeepsakes = false,
  bool freshBootstrap = false,
  List<String>? roomKeepsakes,
}) {
  final state = GameState()..lastModified = modified;
  if (roomKeepsakes != null) state.setRoomKeepsakes(roomKeepsakes);
  final encodedState = state.toJson();
  if (omitRoomKeepsakes) encodedState.remove('roomKeepsakes');
  return jsonEncode({
    'app': 'emberkeep',
    'schema': schema,
    'state': encodedState,
    'quests': const <Object>[],
    if (freshBootstrap) 'freshBootstrap': true,
  });
}

void main() {
  group('schema-safe cloud merge', () {
    test('adopts a newer remote when both saves are legacy schema 18', () {
      expect(
        Storage.decideCloudMerge(
          localRaw: _save(schema: 18, modified: 100),
          remoteRaw: _save(schema: 18, modified: 200),
        ),
        CloudMergeDecision.adoptRemote,
      );
    });

    test('holds a newer schema-18 remote against schema-19 local', () {
      expect(
        Storage.decideCloudMerge(
          localRaw: _save(schema: 19, modified: 100),
          remoteRaw: _save(schema: 18, modified: 200),
        ),
        CloudMergeDecision.hold,
      );
    });

    test('holds a newer schema-19 remote against schema-20 local', () {
      expect(
        Storage.decideCloudMerge(
          localRaw: _save(schema: 20, modified: 100),
          remoteRaw: _save(schema: 19, modified: 200),
        ),
        CloudMergeDecision.hold,
      );
    });

    test('holds a newer schema-20 remote against schema-21 local', () {
      expect(
        Storage.decideCloudMerge(
          localRaw: _save(schema: 21, modified: 100),
          remoteRaw: _save(schema: 20, modified: 200),
        ),
        CloudMergeDecision.hold,
      );
    });

    test('holds a newer schema-23 remote against schema-24 local', () {
      expect(
        Storage.decideCloudMerge(
          localRaw: _save(schema: 24, modified: 100),
          remoteRaw: _save(schema: 23, modified: 200),
        ),
        CloudMergeDecision.hold,
      );
    });

    test('holds a newer schema-24 remote against schema-25 local', () {
      expect(
        Storage.decideCloudMerge(
          localRaw: _save(schema: 25, modified: 100),
          remoteRaw: _save(schema: 24, modified: 200),
        ),
        CloudMergeDecision.hold,
      );
    });

    test('holds a newer schema-27 remote against schema-28 keepsakes', () {
      expect(
        Storage.decideCloudMerge(
          localRaw: _save(schema: Storage.schema, modified: 100),
          remoteRaw: _save(schema: 27, modified: 200, omitRoomKeepsakes: true),
        ),
        CloudMergeDecision.hold,
      );
    });

    test(
      'fresh bootstrap adopts a valid schema-27 cloud save; local history pushes an older remote and holds a newer legacy one',
      () {
        final legacyRemote = _save(
          schema: 27,
          modified: 200,
          omitRoomKeepsakes: true,
        );
        final bootstrap = _save(
          schema: Storage.schema,
          modified: 0,
          freshBootstrap: true,
        );

        expect(
          Storage.decideInitialCloudMerge(
            localRaw: bootstrap,
            remoteRaw: legacyRemote,
          ),
          CloudMergeDecision.adoptRemote,
        );
        final realLocal = _save(
          schema: Storage.schema,
          modified: 250,
          roomKeepsakes: ['keepsake_books'],
        );
        expect(
          Storage.decideInitialCloudMerge(
            localRaw: realLocal,
            remoteRaw: legacyRemote,
          ),
          CloudMergeDecision.pushLocal,
        );
        expect(
          Storage.decideInitialCloudMerge(
            localRaw: realLocal,
            remoteRaw: _save(
              schema: 27,
              modified: 300,
              omitRoomKeepsakes: true,
            ),
          ),
          CloudMergeDecision.hold,
        );
      },
    );

    test(
      'schema-28 requires an explicit keepsake list; legacy saves do not',
      () {
        final currentMissing = _save(
          schema: Storage.schema,
          modified: 1,
          omitRoomKeepsakes: true,
        );
        final explicitEmpty = _save(schema: Storage.schema, modified: 1);
        final legacyMissing = _save(
          schema: 27,
          modified: 1,
          omitRoomKeepsakes: true,
        );

        expect(Storage.isValidSave(currentMissing), isFalse);
        expect(Storage.isValidSave(explicitEmpty), isTrue);
        expect(Storage.isValidSave(legacyMissing), isTrue);
        expect(
          Storage.decideCloudMerge(
            localRaw: explicitEmpty,
            remoteRaw: currentMissing,
          ),
          CloudMergeDecision.hold,
        );
      },
    );

    test(
      'import rejects a truncated schema-28 state but accepts a legacy save',
      () async {
        SharedPreferences.setMockInitialValues({});
        final currentMissing = _save(
          schema: Storage.schema,
          modified: 1,
          omitRoomKeepsakes: true,
        );
        final legacyMissing = _save(
          schema: 27,
          modified: 1,
          omitRoomKeepsakes: true,
        );

        expect(await Storage.importRaw(currentMissing), isFalse);
        expect(await Storage.importRaw(legacyMissing), isTrue);
        expect(
          Storage.isFreshBootstrapSave(await Storage.exportRaw()),
          isFalse,
        );
      },
    );

    test(
      'an offline ordinary save clears the bootstrap marker before cloud compare',
      () async {
        SharedPreferences.setMockInitialValues({});
        final state = GameState();
        expect(
          await Storage.save(state, const [], freshBootstrap: true),
          isTrue,
        );
        expect(Storage.isFreshBootstrapSave(await Storage.exportRaw()), isTrue);

        state.setRoomKeepsakes(['keepsake_cat']);
        expect(await Storage.save(state, const []), isTrue);
        final local = await Storage.exportRaw();
        expect(Storage.isFreshBootstrapSave(local), isFalse);
        expect(
          Storage.decideInitialCloudMerge(
            localRaw: local,
            remoteRaw: _save(schema: 27, modified: 1, omitRoomKeepsakes: true),
          ),
          CloudMergeDecision.hold,
        );
      },
    );

    test(
      'load quarantines a truncated schema-28 state instead of inventing an empty choice',
      () async {
        final currentMissing = _save(
          schema: Storage.schema,
          modified: 1,
          omitRoomKeepsakes: true,
        );
        SharedPreferences.setMockInitialValues({
          'liferpg_save_v1': currentMissing,
        });

        expect(await Storage.load(), isNull);
        expect(await Storage.corruptBackup(), currentMissing);
      },
    );
    test('adopts a newer remote when both saves use the current schema', () {
      expect(
        Storage.decideCloudMerge(
          localRaw: _save(schema: Storage.schema, modified: 100),
          remoteRaw: _save(schema: Storage.schema, modified: 200),
        ),
        CloudMergeDecision.adoptRemote,
      );
    });

    test('pushes a newer local save when both use the current schema', () {
      expect(
        Storage.decideCloudMerge(
          localRaw: _save(schema: Storage.schema, modified: 300),
          remoteRaw: _save(schema: Storage.schema, modified: 200),
        ),
        CloudMergeDecision.pushLocal,
      );
    });

    test('holds instead of overwriting unreadable or future saves', () {
      expect(Storage.schema, 28);
      final local = _save(schema: Storage.schema, modified: 300);
      expect(
        Storage.decideCloudMerge(localRaw: local, remoteRaw: '{not json'),
        CloudMergeDecision.hold,
      );
      final malformedSchema = jsonEncode({
        'app': 'emberkeep',
        'schema': 'unknown',
        'state': GameState().toJson(),
        'quests': const <Object>[],
      });
      expect(
        Storage.decideCloudMerge(localRaw: local, remoteRaw: malformedSchema),
        CloudMergeDecision.hold,
      );
      final unreadableQuest =
          jsonDecode(_save(schema: 19, modified: 200)) as Map<String, dynamic>;
      unreadableQuest['quests'] = [
        {'title': 42},
      ];
      expect(
        Storage.decideCloudMerge(
          localRaw: local,
          remoteRaw: jsonEncode(unreadableQuest),
        ),
        CloudMergeDecision.hold,
      );
      expect(
        Storage.decideCloudMerge(
          localRaw: local,
          remoteRaw: _save(schema: Storage.schema + 1, modified: 200),
        ),
        CloudMergeDecision.hold,
      );
      expect(
        Storage.decideCloudMerge(
          localRaw: '{not json',
          remoteRaw: _save(schema: 20, modified: 200),
        ),
        CloudMergeDecision.hold,
      );
    });
  });
}
