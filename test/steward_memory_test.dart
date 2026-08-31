import 'package:emberkeep/engine.dart';
import 'package:emberkeep/steward_memory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GameState round-trips the optional Steward encounter memory', () {
    final state = GameState()
      ..stewardMemory.discovered = true
      ..stewardMemory.completed = true
      ..stewardMemory.nodeId = 'steward.reflect'
      ..stewardMemory.choices.addAll({
        'first-question': 'honest',
        'future-choice': 'kept without story validation',
      });

    final restored = GameState.fromJson(state.toJson());

    expect(restored.stewardMemory.discovered, isTrue);
    expect(restored.stewardMemory.completed, isTrue);
    expect(restored.stewardMemory.nodeId, 'steward.reflect');
    expect(restored.stewardMemory.choices, {
      'first-question': 'honest',
      'future-choice': 'kept without story validation',
    });
  });

  test('legacy saves without Steward memory restore an empty memory', () {
    final saved = GameState().toJson()..remove('stewardMemory');

    final restored = GameState.fromJson(saved);

    expect(restored.stewardMemory.discovered, isFalse);
    expect(restored.stewardMemory.completed, isFalse);
    expect(restored.stewardMemory.nodeId, isNull);
    expect(restored.stewardMemory.choices, isEmpty);
  });

  test(
    'malformed Steward memory is safely reduced to valid bounded strings',
    () {
      final restored = StewardMemory.fromJson({
        'discovered': 'yes',
        'completed': true,
        'nodeId': 4,
        'choices': {
          'known-later': 'preserved',
          7: 'wrong key',
          'wrong value': 4,
          '': 'empty key',
          'oversized': 'x' * 513,
        },
      });

      expect(restored.discovered, isFalse);
      expect(restored.completed, isTrue);
      expect(restored.nodeId, isNull);
      expect(restored.choices, {'known-later': 'preserved'});
      expect(StewardMemory.fromJson(const ['not a map']).choices, isEmpty);

      restored
        ..nodeId = 'x' * 257
        ..choices['too-long'] = 'x' * 513;
      expect(restored.toJson(), {
        'discovered': false,
        'completed': true,
        'choices': {'known-later': 'preserved'},
      });
    },
  );

  test('replay reset preserves encounter history while clearing its path', () {
    final memory = StewardMemory(
      discovered: true,
      completed: true,
      nodeId: 'steward.ending',
      choices: {'answer': 'yes'},
    );

    memory.resetReplay();

    expect(memory.discovered, isTrue);
    expect(memory.completed, isTrue);
    expect(memory.nodeId, isNull);
    expect(memory.choices, isEmpty);
  });

  test('each GameState owns independent Steward memory', () {
    final first = GameState();
    final second = GameState();

    first.stewardMemory
      ..discovered = true
      ..choices['answer'] = 'first';

    expect(second.stewardMemory.discovered, isFalse);
    expect(second.stewardMemory.choices, isEmpty);
  });
}
