import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/journal_entry.dart';
import 'package:emberkeep/screens/journal_hub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

JournalTrace _creditTrace() => const JournalTrace(
  day: '2026-09-03',
  level: 4,
  totalXp: 120,
  todayXp: 8,
  streakDays: 2,
  extraCreditTitles: ['attended all my classes'],
);

Note _creditNote() => Note(
  id: 'extra-credit-page',
  at: DateTime(2026, 9, 3, 20),
  text: 'A full day, and I showed up for it.',
  trace: _creditTrace(),
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  tearDown(Clock.reset);

  test('old trace shape preserves an extra-credit title without quests', () {
    final raw = _creditTrace().toJson()..remove('questTitles');
    final restored = JournalTrace.fromJson(raw);

    expect(restored?.questTitles, isEmpty);
    expect(restored?.extraCreditTitles, ['attended all my classes']);
    expect(restored?.hasDayEvidence, isTrue);
  });

  testWidgets('saved page context labels extra credit separately from quests', (
    tester,
  ) async {
    final state = GameState()
      ..reduceMotion = true
      ..setJournal([_creditNote()]);
    await _pump(
      tester,
      JournalHubScreen(state: state, quests: const [], onPersist: () {}),
    );

    await tester.tap(
      find.byKey(const ValueKey('journal-card-extra-credit-page')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(JournalEntryScreen), findsOneWidget);
    expect(find.text('EXTRA CREDIT  ·  attended all my classes'), findsWidgets);
    expect(find.text('1 quest'), findsNothing);
    expect(find.text('QUEST THREAD'), findsNothing);
  });

  testWidgets('live day context can show extra credit with no quest titles', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 9, 3, 20));
    final state = GameState()..reduceMotion = true;
    expect(
      state.addExtraCredit(
        'attended all my classes',
        dayKey: Days.nightKey(Clock.now()),
      ),
      isNotNull,
    );
    await _pump(
      tester,
      JournalHubScreen(state: state, quests: const [], onPersist: () {}),
    );

    expect(
      find.text('EXTRA CREDIT  ·  attended all my classes'),
      findsOneWidget,
    );
  });
}
