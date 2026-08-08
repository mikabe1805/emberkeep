import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/calendar.dart';
import 'package:emberkeep/screens/journal_entry.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Sfx.instance.soundEnabled = false;
  });

  tearDown(() {
    Sfx.instance.soundEnabled = true;
    Clock.reset();
  });

  group('space profile persistence', () {
    test('personal intro and selected goals survive a save round-trip', () {
      final state = GameState();
      state.goals.addAll([
        Goal(title: 'Build a walking habit', stat: Stat.vit, target: 25),
        Goal(title: 'Finish the essay', stat: Stat.intl, target: 5),
        Goal(title: 'Make the room feel calm', stat: Stat.dis, target: 25),
        Goal(title: 'Call family weekly', stat: Stat.soc, target: 25),
      ]);

      state.setSpaceProfile(
        intro: '  i make things,   care for people,\nand keep going.  ',
        goals: const [
          ' Build a walking habit ',
          'not one of my goals',
          'Build a walking habit',
          'Finish the essay',
          'Make the room feel calm',
          'Call family weekly',
        ],
        shared: true,
      );

      expect(
        state.spaceIntro,
        'i make things, care for people,\nand keep going.',
      );
      expect(state.featuredGoalTitles, const [
        'Build a walking habit',
        'Finish the essay',
        'Make the room feel calm',
      ]);

      final encoded = state.toJson();
      final restored = GameState.fromJson(encoded);

      expect(encoded['spaceIntro'], state.spaceIntro);
      expect(encoded['featuredGoalTitles'], state.featuredGoalTitles);
      expect(encoded['shareSpaceProfile'], isTrue);
      expect(restored.spaceIntro, state.spaceIntro);
      expect(restored.featuredGoalTitles, state.featuredGoalTitles);
      expect(restored.shareSpaceProfile, isTrue);
    });

    test(
      'profile edits preserve sharing unless consent is explicitly changed',
      () {
        final state = GameState();

        state.setSpaceProfile(intro: 'first', goals: const [], shared: true);
        state.setSpaceProfile(intro: 'second', goals: const []);
        expect(state.shareSpaceProfile, isTrue);

        state.setSpaceProfile(intro: 'third', goals: const [], shared: false);
        expect(state.shareSpaceProfile, isFalse);
      },
    );

    test('older saves restore with an empty space profile', () {
      final encoded = GameState().toJson()
        ..remove('spaceIntro')
        ..remove('featuredGoalTitles')
        ..remove('shareSpaceProfile');

      final restored = GameState.fromJson(encoded);

      expect(restored.spaceIntro, isEmpty);
      expect(restored.featuredGoalTitles, isEmpty);
      expect(restored.shareSpaceProfile, isFalse);
    });
  });

  testWidgets(
    'selected-day journal entry stays openable on a narrow phone at largest text',
    (tester) async {
      Clock.freeze(DateTime(2026, 8, 2, 10));
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      const starter = 'One small win today:\n';
      const entryText = '${starter}Mom and I walked by the river.';
      final quest = Quest(
        title: 'Notice a win',
        stat: Stat.intl,
        difficulty: 1,
        journalPrompt: const JournalQuestPrompt(
          starter: starter,
          hint: 'What went a little better?',
        ),
      );
      final state = GameState()
        ..reduceMotion = true
        ..journal = [
          Note(
            at: DateTime(2026, 8, 2, 8, 30),
            text: entryText,
            sourceQuestKey: quest.title,
          ),
        ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarPage(
              state: state,
              quests: [quest],
              onAdd: (_) => true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text(entryText),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      expect(find.text('JOURNAL'), findsOneWidget);
      expect(find.text(entryText), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.button == true &&
              widget.properties.label == 'Read journal entry. $entryText',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(entryText));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(JournalEntryScreen), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('journal-entry-body')),
      );
      expect(field.controller!.text, entryText);
      expect(field.readOnly, isTrue);
      expect(field.showCursor, isFalse);
      expect(find.byKey(const ValueKey('journal-entry-edit')), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      final span = field.controller!.buildTextSpan(
        context: tester.element(
          find.byKey(const ValueKey('journal-entry-body')),
        ),
        style: field.style,
        withComposing: false,
      );
      final pieces = span.children!.cast<TextSpan>();
      expect(pieces.first.text, starter);
      expect(pieces.first.style?.fontStyle, FontStyle.italic);
      expect(pieces.last.text, 'Mom and I walked by the river.');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('calendar night entry reads first and Edit opens night prompts', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 8, 2, 10));
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
      ..journal = [note];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarPage(
            state: state,
            quests: const [],
            onAdd: (_) => true,
          ),
        ),
      ),
    );
    await tester.pump();
    final card = find.byKey(ValueKey('calendar-journal-entry-${note.id}'));
    await tester.scrollUntilVisible(
      card,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    // scrollUntilVisible stops at partial visibility; bring the card fully
    // on-screen so the tap lands on it.
    await tester.ensureVisible(card);
    await tester.pump();
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(JournalEntryScreen), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('journal-entry-body')))
          .readOnly,
      isTrue,
    );
    expect(find.byKey(const Key('night-reflection-field')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('journal-entry-edit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('night-reflection-field')), findsOneWidget);
    expect(find.text('Optional reflection'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('calendar reveals every journal entry from the selected day', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    Clock.freeze(DateTime(2026, 8, 2, 10));
    final state = GameState()
      ..reduceMotion = true
      ..journal = [
        Note(at: DateTime(2026, 8, 2, 8), text: 'First page'),
        Note(at: DateTime(2026, 8, 2, 12), text: 'Second page'),
        Note(at: DateTime(2026, 8, 2, 20), text: 'Third page'),
      ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarPage(
            state: state,
            quests: const [],
            onAdd: (_) => true,
          ),
        ),
      ),
    );
    await tester.pump();
    final reveal = find.text('+ 1 MORE ON THIS DAY');
    await tester.ensureVisible(reveal);
    await tester.pump();

    expect(find.text('First page'), findsNothing);
    expect(find.text('Second page'), findsOneWidget);
    expect(find.text('Third page'), findsOneWidget);

    await tester.tap(reveal);
    await tester.pump();

    expect(find.text('First page'), findsOneWidget);
    expect(find.text('SHOW FEWER'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
