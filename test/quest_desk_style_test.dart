import 'package:emberkeep/content/quest_desk_styles.dart';
import 'package:emberkeep/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Quest Desk follows the selected room identity', () {
    final state = GameState()
      ..wallStyle = 'wall_archive'
      ..ownedStyles.add('wall_archive')
      ..questDeskStyle = 'wall_walnut';

    expect(activeQuestDeskLook(state).roomStyleId, 'wall_archive');
    expect(activeQuestDeskLook(state).name, 'Archive Ledger');
  });

  test('free room identities remain available without an ownership entry', () {
    final walnut = GameState()..wallStyle = 'wall_walnut';
    final listening = GameState()..wallStyle = 'wall_listening';

    expect(isQuestDeskLookOwned(walnut, questDeskLookById('wall_walnut')), isTrue);
    expect(
      isQuestDeskLookOwned(listening, questDeskLookById('wall_listening')),
      isTrue,
    );
    expect(activeQuestDeskLook(listening).roomStyleId, 'wall_listening');
  });

  test('an unowned room falls back to the free walnut desk', () {
    final state = GameState()..wallStyle = 'wall_archive';

    expect(activeQuestDeskLook(state).roomStyleId, 'wall_walnut');
  });
}
