// The weekly chronicle reads the app's Clock, counts class days so a week of
// classes never reads as quiet, and says "1 more quest", not "1 more quests".
import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/weekly_chronicle.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/weekly_chronicle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// His week of Sep 28 to Oct 4: twelve classes over five weekdays, kept on
/// each class's own night (local wall times, so any host zone works).
GameState _classWeek({Map<String, int> quests = const {}}) {
  const days = <int, List<(String, int)>>{
    28: [('14:332:361', 510), ('14:332:345', 840), ('14:332:345', 1060)],
    29: [('14:332:331', 620), ('01:198:206', 840)],
    30: [('14:332:333', 510), ('14:332:345', 840)],
    1: [('14:332:361', 510), ('01:198:206', 840), ('14:332:363', 950)],
    2: [('14:332:331', 620), ('01:198:206', 1075)],
  };
  final state = GameState()..reduceMotion = true;
  for (final entry in days.entries) {
    final day = DateTime(2026, entry.key >= 28 ? 9 : 10, entry.key);
    Clock.freeze(day.add(const Duration(hours: 21)));
    for (final (code, start) in entry.value) {
      final kept = state.keepClass(
        ClassFacts(
          courseCode: code,
          title: code,
          kind: 'lecture',
          dayKey: Days.key(day),
          startMinute: start,
        ),
      );
      expect(kept, isNotNull);
    }
  }
  state.history.addAll(quests);
  return state;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(Clock.reset);

  test('a week of classes and no Quests is not a quiet week', () {
    final state = _classWeek(quests: {'2026-09-21': 3, '2026-09-23': 1});
    // No `now`: the chronicle reads the app's Clock, not the wall clock.
    Clock.freeze(DateTime(2026, 10, 5, 9));
    final week = weeklyChronicleFor(state);

    expect(week.rangeLabel, 'SEP 28 – OCT 4');
    expect(week.total, 0);
    expect(week.delta, -4);
    expect(week.classCounts, [3, 2, 2, 3, 2, 0, 0]);
    expect(week.classesKept, 12);
    expect(week.classDays, 5);
    expect(week.litDays, 5);
    expect(week.headline, '12 classes kept');
    expect(week.deltaLine, isNot(contains('quieter')));
    expect(week.deltaLine, isEmpty);
    expect(
      week.shareText,
      'I showed up on 5 of 7 days and kept 12 classes this week.',
    );
  });

  test('classes and Quests share the line, with honest grammar', () {
    final state = _classWeek(
      quests: {'2026-09-29': 1, '2026-10-03': 1, '2026-09-22': 1},
    );
    Clock.freeze(DateTime(2026, 10, 5, 9));
    final week = weeklyChronicleFor(state);
    expect(week.total, 2);
    expect(week.delta, 1);
    expect(week.litDays, 6, reason: 'five class days plus a Saturday Quest');
    expect(week.headline, '2 quests became progress');
    expect(
      week.deltaLine,
      '12 classes kept · 1 more quest than the week before',
    );
    expect(
      week.shareText,
      'I showed up on 6 of 7 days, kept 12 classes and completed 2 quests '
      'this week.',
    );
  });

  test('a Quest-only week keeps its words, minus the em dash', () {
    final quieter = GameState()
      ..history.addAll({'2026-09-21': 3, '2026-09-29': 1});
    Clock.freeze(DateTime(2026, 10, 5, 9));
    expect(
      weeklyChronicleFor(quieter).deltaLine,
      'a quieter week, still part of the story',
    );
    final one = GameState()..history.addAll({'2026-09-29': 1});
    expect(
      weeklyChronicleFor(one).deltaLine,
      '1 more quest than the week before',
    );
    final steady = GameState()
      ..history.addAll({'2026-09-21': 1, '2026-09-29': 1});
    expect(weeklyChronicleFor(steady).deltaLine, 'steady with the week before');
    expect(weeklyChronicleFor(GameState()).headline, 'A quiet chapter');
  });

  testWidgets('the chronicle card tells a class week', (tester) async {
    Sfx.instance.soundEnabled = false;
    addTearDown(() => Sfx.instance.soundEnabled = true);
    final state = _classWeek();
    Clock.freeze(DateTime(2026, 10, 5, 9));
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: WeeklyChronicleScreen(state: state)),
    );
    await tester.pump();
    expect(find.text('12 classes kept'), findsOneWidget);
    expect(find.text('5 OF 7 DAYS ACTIVE'), findsOneWidget);
    expect(find.text('A quiet chapter'), findsNothing);
    expect(find.textContaining('QUESTS'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
