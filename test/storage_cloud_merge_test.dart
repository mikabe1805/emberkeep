import 'dart:convert';

import 'package:emberkeep/engine.dart';
import 'package:emberkeep/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _save({
  required int schema,
  required int modified,
  bool omitRoomKeepsakes = false,
  bool omitDayRecords = false,
  bool freshBootstrap = false,
  List<String>? roomKeepsakes,
}) {
  final state = GameState()..lastModified = modified;
  if (roomKeepsakes != null) state.setRoomKeepsakes(roomKeepsakes);
  final encodedState = state.toJson();
  if (omitRoomKeepsakes) encodedState.remove('roomKeepsakes');
  if (omitDayRecords) encodedState.remove('dayRecords');
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

    test('holds a newer schema-28 remote against schema-29 day records', () {
      expect(
        Storage.decideCloudMerge(
          localRaw: _save(schema: Storage.schema, modified: 100),
          remoteRaw: _save(schema: 28, modified: 200, omitDayRecords: true),
        ),
        CloudMergeDecision.hold,
      );
    });

    test('holds a newer schema-27 remote against schema-28 keepsakes', () {
      expect(
        Storage.decideCloudMerge(
          localRaw: _save(schema: Storage.schema, modified: 100),
          remoteRaw: _save(
            schema: 27,
            modified: 200,
            omitRoomKeepsakes: true,
            omitDayRecords: true,
          ),
        ),
        CloudMergeDecision.hold,
      );
    });

    test('schema-28 keepsake protection remains after schema-29 migration', () {
      for (final schema in [28, Storage.schema]) {
        expect(
          Storage.isValidSave(
            _save(schema: schema, modified: 1, omitRoomKeepsakes: true),
          ),
          isFalse,
          reason: 'day records must not weaken the existing keepsake boundary',
        );
      }
      expect(
        Storage.isValidSave(
          _save(
            schema: 27,
            modified: 1,
            omitRoomKeepsakes: true,
            omitDayRecords: true,
          ),
        ),
        isTrue,
      );
    });

    test('a schema-28 save migrates to 29 with empty day records', () async {
      SharedPreferences.setMockInitialValues({
        'liferpg_save_v1': _save(schema: 28, modified: 1, omitDayRecords: true),
      });
      final loaded = await Storage.load();
      expect(loaded, isNotNull);
      final (state, quests) = loaded!;
      expect(state.dayRecords, isEmpty);
      expect(state.totalClassesKept, 0);
      expect(await Storage.save(state, quests), isTrue);
      final raw = await Storage.exportRaw();
      expect(Storage.schemaOf(raw!), 29);
      expect(Storage.isValidSave(raw), isTrue);
      final encoded = (jsonDecode(raw) as Map)['state'] as Map;
      expect(encoded['dayRecords'], isA<List>());
    });

    test('a schema-29 preview save with its own extra-credit key is read', () {
      final preview = jsonDecode(_save(schema: 29, modified: 1)) as Map;
      final state = (preview['state'] as Map)..remove('dayRecords');
      state['extraCredit'] = [
        {
          'dayKey': '2026-09-03',
          'title': 'Went to all classes',
          'xp': 10,
          'createdAt': 1,
        },
      ];
      final raw = jsonEncode(preview);
      expect(Storage.isValidSave(raw), isTrue);
      final restored = GameState.fromJson(state.cast<String, dynamic>());
      expect(
        restored.extraCreditForDay('2026-09-03')?.title,
        'Went to all classes',
      );
    });

    test(
      'fresh bootstrap adopts a valid schema-27 cloud save; local history pushes an older remote and holds a newer legacy one',
      () {
        final legacyRemote = _save(
          schema: 27,
          modified: 200,
          omitRoomKeepsakes: true,
          omitDayRecords: true,
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
              omitDayRecords: true,
            ),
          ),
          CloudMergeDecision.hold,
        );
      },
    );

    test(
      'schema-29 requires an explicit day-record list; schema 28 migrates it',
      () {
        final currentMissing = _save(
          schema: Storage.schema,
          modified: 1,
          omitDayRecords: true,
        );
        final explicitEmpty = _save(schema: Storage.schema, modified: 1);
        final legacyMissing = _save(
          schema: 28,
          modified: 1,
          omitDayRecords: true,
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
      'import rejects a truncated schema-29 state but accepts schema 28',
      () async {
        SharedPreferences.setMockInitialValues({});
        final currentMissing = _save(
          schema: Storage.schema,
          modified: 1,
          omitDayRecords: true,
        );
        final legacyMissing = _save(
          schema: 28,
          modified: 1,
          omitDayRecords: true,
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
            remoteRaw: _save(
              schema: 27,
              modified: 1,
              omitRoomKeepsakes: true,
              omitDayRecords: true,
            ),
          ),
          CloudMergeDecision.hold,
        );
      },
    );

    test(
      'load quarantines a truncated schema-29 state instead of inventing empty records',
      () async {
        final currentMissing = _save(
          schema: Storage.schema,
          modified: 1,
          omitDayRecords: true,
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
      expect(Storage.schema, 29);
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
