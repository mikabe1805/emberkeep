import 'package:emberkeep/content/quest_companion_copy.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Quest quest({
    String title = 'Clear one surface',
    Stat stat = Stat.dis,
    DateTime? dueDate,
    bool priority = false,
    String? ladderHint,
    List<Note> log = const [],
  }) => Quest(
    title: title,
    stat: stat,
    difficulty: 2,
    dueDate: dueDate,
    priority: priority,
    ladderHint: ladderHint,
    log: log,
  );

  test('companion copy is stable for the same quest, day, and state', () {
    final day = DateTime(2026, 8, 19, 14);
    final q = quest();

    expect(
      questCompanionCopy(quest: q, day: day),
      questCompanionCopy(quest: q, day: day.add(const Duration(hours: 7))),
    );
  });

  test('a three-line companion pool rotates without repeating each day', () {
    final firstDay = DateTime(2026, 8, 19);
    final q = quest();
    final cycle = [
      for (var offset = 0; offset < 4; offset++)
        questCompanionCopy(
          quest: q,
          day: firstDay.add(Duration(days: offset)),
        ),
    ];

    expect(cycle.take(3).toSet(), hasLength(3));
    expect(cycle[3], cycle[0]);
  });

  test(
    'companion copy is state-aware and does not use fortune-copy for facts',
    () {
      final day = DateTime(2026, 8, 19);

      expect(
        questCompanionCopy(
          quest: quest(dueDate: DateTime(2026, 8, 18)),
          day: day,
        ),
        isIn([
          'Still yours when you have room.',
          'Pick it back up when the day allows.',
          'This can wait for a clearer moment.',
        ]),
      );
      expect(
        questCompanionCopy(
          quest: quest(dueDate: DateTime(2026, 8, 19)),
          day: day,
        ),
        isIn([
          'This is the day it belongs to.',
          'A place to land today.',
          'Keep this one in view.',
        ]),
      );
    },
  );

  test(
    'keeper notes and curated hints always win over generated companion copy',
    () {
      final day = DateTime(2026, 8, 19);

      expect(
        questCompanionCopy(
          quest: quest(ladderHint: 'PICK ONE ROOM · JUST ONE'),
          day: day,
        ),
        isNull,
      );
      expect(
        questCompanionCopy(
          quest: quest(
            log: [Note(at: day, text: 'Kitchen first')],
          ),
          day: day,
        ),
        isNull,
      );
    },
  );
}
