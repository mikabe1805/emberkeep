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

    test('holds a newer schema-22 remote against schema-23 local', () {
      expect(
        Storage.decideCloudMerge(
          localRaw: _save(schema: 23, modified: 100),
          remoteRaw: _save(schema: 22, modified: 200),
        ),
        CloudMergeDecision.hold,
      );
    });

    test('adopts a newer remote when both saves are schema 23', () {
      expect(
        Storage.decideCloudMerge(
          localRaw: _save(schema: 23, modified: 100),
          remoteRaw: _save(schema: 23, modified: 200),
        ),
        CloudMergeDecision.adoptRemote,
      );
    });

    test('pushes a newer local save when both saves are schema 23', () {
      expect(
        Storage.decideCloudMerge(
          localRaw: _save(schema: 23, modified: 300),
          remoteRaw: _save(schema: 23, modified: 200),
        ),
        CloudMergeDecision.pushLocal,
      );
    });

    test('holds instead of overwriting unreadable or future saves', () {
      expect(Storage.schema, 23);
      final local = _save(schema: 23, modified: 300);
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
