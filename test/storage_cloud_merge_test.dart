import 'dart:convert';

import 'package:emberkeep/engine.dart';
import 'package:emberkeep/storage.dart';
import 'package:flutter_test/flutter_test.dart';

String _save({required int schema, required int modified}) {
  final state = GameState()..lastModified = modified;
  return jsonEncode({
    'app': 'emberkeep',
    'schema': schema,
    'state': state.toJson(),
    'quests': const <Object>[],
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
      expect(Storage.schema, 25);
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
