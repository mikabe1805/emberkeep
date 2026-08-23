import 'package:emberkeep/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ambient light validates choices and survives a save round trip', () {
    final locked = GameState();
    locked.setTheme('sea');
    expect(locked.canvasTheme, 'walnut');

    final state = GameState()..level = 5;
    state.setTheme('sea');
    expect(state.canvasTheme, 'sea');

    final restored = GameState.fromJson(state.toJson());
    expect(restored.canvasTheme, 'sea');

    state.setTheme('not-a-real-light');
    expect(state.canvasTheme, 'sea');

    final malformed = GameState.fromJson({
      ...state.toJson(),
      'canvasTheme': 'not-a-real-light',
    });
    expect(malformed.canvasTheme, 'walnut');

    final lockedPersisted = GameState.fromJson({
      ...state.toJson(),
      'level': 1,
      'canvasTheme': 'sea',
    });
    expect(lockedPersisted.canvasTheme, 'walnut');
  });
}
