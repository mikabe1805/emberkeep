import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/journal_doc.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/insights.dart';
import 'package:emberkeep/screens/journal_entry.dart';
import 'package:emberkeep/screens/journal_hub.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Note _note(String text, DateTime at) => Note(at: at, text: text);

Future<void> _pumpHub(
  WidgetTester tester,
  GameState state, {
  List<Quest> quests = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: JournalHubScreen(state: state, quests: quests, onPersist: () {}),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

TextField _journalField(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(const ValueKey('journal-entry-body')));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    Sfx.instance.soundEnabled = false;
  });

  tearDown(() {
    Sfx.instance.soundEnabled = true;
    Clock.reset();
  });

  test('Then & Now is occasional and rotates through older entries', () {
    final first = _note('first', DateTime(2026, 7, 1));
    final second = _note('second', DateTime(2026, 7, 2));
    final notes = [first, second];

    expect(thenAndNowEntry(notes, now: DateTime(2026, 8, 5))?.text, 'second');
    expect(thenAndNowEntry(notes, now: DateTime(2026, 8, 6)), isNull);
    expect(thenAndNowEntry(notes, now: DateTime(2026, 8, 8))?.text, 'first');
  });

  test('Then & Now does not turn a current-day entry into history', () {
    final today = _note('today', DateTime(2026, 8, 6, 9));
    expect(thenAndNowEntry([today], now: DateTime(2026, 8, 6)), isNull);
  });

  test('Then & Now rotation is stable when entries share a timestamp', () {
    final at = DateTime(2026, 7, 1, 9);
    final alpha = Note(id: 'alpha', at: at, text: 'alpha');
    final beta = Note(id: 'beta', at: at, text: 'beta');

    expect(
      thenAndNowEntry([beta, alpha], now: DateTime(2026, 8, 5))?.text,
      thenAndNowEntry([alpha, beta], now: DateTime(2026, 8, 5))?.text,
    );
  });

  testWidgets(
    'Journal archive cues appear only after there is history to show',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final empty = GameState()..reduceMotion = true;
      await tester.pumpWidget(
        MaterialApp(
          home: InsightsPage(state: empty, quests: const [], onPersist: () {}),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('journal-entry-count')), findsNothing);
      expect(
        find.byKey(const ValueKey('journal-entry-page-stack')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('journal-selected-lens-entries')),
        findsOneWidget,
      );

      final populated = GameState()
        ..reduceMotion = true
        ..setJournal([_note('A page worth keeping.', DateTime(2026, 7, 1))]);
      await tester.pumpWidget(
        MaterialApp(
          home: InsightsPage(
            state: populated,
            quests: const [],
            onPersist: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('journal-entry-count')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('journal-entry-page-stack')),
        findsOneWidget,
      );
      final pageStack = tester.getSize(
        find.byKey(const ValueKey('journal-entry-page-stack')),
      );
      expect(pageStack.width, 30);
      expect(pageStack.height, greaterThanOrEqualTo(72));
    },
  );

  testWidgets(
    'Your Journal pairs one immediate cue with its visible press bob',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final events = <String>[];
      final sfx = Sfx.instance;
      sfx.debugResetForTesting();
      sfx.debugBypassPlayback = true;
      sfx.debugOnPlay = events.add;
      addTearDown(sfx.debugResetForTesting);

      final state = GameState()..reduceMotion = true;
      await tester.pumpWidget(
        MaterialApp(
          home: InsightsPage(state: state, quests: const [], onPersist: () {}),
        ),
      );
      await tester.pump();

      final label = find.text('Your Journal');
      final pressable = find.ancestor(
        of: label,
        matching: find.byType(Pressable),
      );
      expect(pressable, findsOneWidget);
      final pressLayer = find
          .descendant(of: pressable, matching: find.byType(AnimatedContainer))
          .first;
      final gesture = await tester.startGesture(tester.getCenter(label));
      await tester.pump();
      expect(
        tester.widget<AnimatedContainer>(pressLayer).transform!.storage[13],
        2,
      );
      expect(events, ['open']);

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(JournalHubScreen), findsOneWidget);
      expect(events, ['open']);
    },
  );

  testWidgets('Journal feed opens an existing page read-first, then edits', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final note = Note(
      at: DateTime(2026, 8, 1, 18),
      text: 'One small win today:\nI called my sister.',
      sourceQuestKey: 'Notice a win',
    );
    final quest = Quest(
      title: 'Notice a win',
      stat: Stat.intl,
      difficulty: 1,
      journalPrompt: const JournalQuestPrompt(
        starter: 'One small win today:\n',
        hint: 'What went a little better?',
      ),
    );
    final state = GameState()
      ..reduceMotion = true
      ..setJournal([note]);

    await _pumpHub(tester, state, quests: [quest]);
    final card = find.byKey(ValueKey('journal-card-${note.id}'));
    await tester.scrollUntilVisible(
      card,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(JournalEntryScreen), findsOneWidget);
    expect(_journalField(tester).readOnly, isTrue);
    expect(_journalField(tester).showCursor, isFalse);
    expect(find.byKey(const ValueKey('journal-entry-edit')), findsOneWidget);
    expect(find.byKey(const ValueKey('journal-photo-action')), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    final field = _journalField(tester);
    final span = field.controller!.buildTextSpan(
      context: tester.element(find.byKey(const ValueKey('journal-entry-body'))),
      style: field.style,
      withComposing: false,
    );
    final pieces = span.children!.cast<TextSpan>();
    expect(pieces.first.text, 'One small win today:\n');
    expect(pieces.first.style?.fontStyle, FontStyle.italic);
    expect(pieces.last.text, 'I called my sister.');

    await tester.tap(find.byKey(const ValueKey('journal-entry-edit')));
    await tester.pump();

    expect(_journalField(tester).readOnly, isFalse);
    expect(_journalField(tester).showCursor, isTrue);
    expect(find.byKey(const ValueKey('journal-photo-action')), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('read Back is inert; Edit then Back still autosaves', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const originalText = 'The room felt quieter today.';
    final originalRich = JournalDoc.encode([
      const JournalBlock.text(originalText),
    ]);
    final originalEditedAt = DateTime(2026, 7, 30, 12);
    final original = Note(
      at: DateTime(2026, 7, 29, 20),
      text: originalText,
      rich: originalRich,
      editedAt: originalEditedAt,
    );
    final state = GameState()
      ..reduceMotion = true
      ..setJournal([original]);

    await _pumpHub(tester, state);
    final card = find.byKey(ValueKey('journal-card-${original.id}'));
    await tester.scrollUntilVisible(
      card,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_journalField(tester).readOnly, isTrue);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    await tester.tap(find.byIcon(Icons.chevron_left).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(JournalEntryScreen), findsNothing);
    expect(state.journal, hasLength(1));
    expect(identical(state.journal.single, original), isTrue);
    expect(state.journal.single.id, original.id);
    expect(state.journal.single.rich, originalRich);
    expect(state.journal.single.editedAt, originalEditedAt);

    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    await tester.tap(find.byKey(const ValueKey('journal-entry-edit')));
    await tester.pump();
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    const updatedText = '$originalText\nI want to keep that feeling.';
    await tester.enterText(
      find.byKey(const ValueKey('journal-entry-body')),
      updatedText,
    );
    await tester.tap(find.byIcon(Icons.chevron_left).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(JournalEntryScreen), findsNothing);
    expect(state.journal, hasLength(1));
    expect(state.journal.single.id, original.id);
    expect(state.journal.single.text, updatedText);
    expect(state.journal.single.rich, isNot(originalRich));
    expect(state.journal.single.editedAt, isNot(originalEditedAt));
  });

  testWidgets('Then & Now opens its journal entry in read mode', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Clock.freeze(DateTime(2026, 8, 5, 10));
    final note = Note(
      at: DateTime(2026, 7, 4, 9),
      text: 'I can see the difference now.',
      context: 'BEGINNER',
    );
    final state = GameState()
      ..reduceMotion = true
      ..setJournal([note]);

    await tester.pumpWidget(
      MaterialApp(
        home: InsightsPage(state: state, quests: const [], onPersist: () {}),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('then-and-now-read-entry')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(JournalEntryScreen), findsOneWidget);
    expect(find.text('Looking back'), findsOneWidget);
    expect(_journalField(tester).readOnly, isTrue);
    expect(find.byKey(const ValueKey('journal-entry-edit')), findsOneWidget);
  });

  testWidgets('night pages stay read-first and Edit opens night prompts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const night = NightJournalData(reflection: 'The walk home felt quiet.');
    final note = Note(
      at: DateTime(2026, 8, 2, 22),
      text: night.plainText,
      night: night,
    );
    final state = GameState()
      ..reduceMotion = true
      ..setJournal([note]);

    await _pumpHub(tester, state);
    final card = find.byKey(ValueKey('journal-card-${note.id}'));
    await tester.scrollUntilVisible(
      card,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_journalField(tester).readOnly, isTrue);
    await tester.tap(find.byKey(const ValueKey('journal-entry-edit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('night-reflection-field')), findsOneWidget);
    expect(find.text('Optional reflection'), findsOneWidget);
  });
}
