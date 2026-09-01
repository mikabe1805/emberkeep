import 'dart:convert';

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/goal_catalog.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/journal_doc.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/journal_entry.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/storage.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prompt = JournalQuestPrompt(
  starter: 'Three things I’m thankful for:\n',
  hint: 'A person, place, moment, or tiny detail all count.',
);

Quest _journalQuest() => Quest(
  title: 'Name three good things',
  stat: Stat.intl,
  difficulty: 2,
  goalTitle: 'Keep a journal',
  journalPrompt: _prompt,
);

Future<void> _pumpBoard(
  WidgetTester tester, {
  required GameState state,
  required List<Quest> quests,
  double textScale = 1,
}) async {
  state.reduceMotion = true;
  state.rollover(quests);
  state.setEnergyWeather(EnergyWeather.steady);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: QuestsPage(
          state: state,
          quests: quests,
          onRefresh: () => 0,
          onPersist: () {},
          onAdd: (_) => false,
          onRemove: (_) {},
          onSnapshot: () => 'snapshot',
          onRestore: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _openJournalQuest(WidgetTester tester, Quest quest) async {
  final card = find.byKey(ValueKey('card-${quest.title}'));
  await tester.scrollUntilVisible(
    card,
    220,
    scrollable: find.byType(Scrollable).first,
  );
  expect(card, findsOneWidget);
  await Scrollable.ensureVisible(
    tester.element(card),
    alignment: 0.5,
    duration: Duration.zero,
  );
  await tester.pump();
  await tester.tap(card);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 650));
  expect(find.byType(JournalEntryScreen), findsOneWidget);
}

Future<void> _leaveEditor(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Clock.freeze(DateTime(2026, 8, 3, 13));
    Sfx.instance.soundEnabled = false;
  });

  tearDown(() {
    Clock.reset();
    Sfx.instance.soundEnabled = true;
  });

  test('Journal Quest metadata and draft link survive save round-trips', () {
    final authored = goalCatalog
        .firstWhere((goal) => goal.title == 'Keep a journal')
        .quests
        .firstWhere((quest) => quest.title == 'Name three good things')
        .build(goalTitle: 'Keep a journal');

    final restoredQuest = Quest.fromJson(authored.toJson());
    expect(restoredQuest.journalPrompt?.starter, _prompt.starter);
    expect(restoredQuest.journalPrompt?.hint, _prompt.hint);

    final note = Note(
      at: Clock.now(),
      text: '${_prompt.starter}Mom made me laugh.',
      sourceQuestKey: authored.title,
    );
    final restoredNote = Note.fromJson(note.toJson());
    expect(restoredNote.sourceQuestKey, authored.title);
    expect(
      restoredNote.copyWith(text: 'Edited').sourceQuestKey,
      authored.title,
    );

    // A title that happens to contain a writing word is still an ordinary
    // Quest unless its author explicitly attached Journal metadata.
    expect(
      Quest(
        title: 'Write an email',
        stat: Stat.foc,
        difficulty: 3,
      ).journalPrompt,
      isNull,
    );
  });

  test(
    'schema-19 adopted journal quests are enriched without touching lookalikes',
    () async {
      final journalGoal = goalCatalog.firstWhere(
        (goal) => goal.title == 'Keep a journal',
      );
      final legacyAuthored = [
        for (final template in journalGoal.quests)
          template.build(goalTitle: journalGoal.title).toJson()
            ..remove('journalPrompt'),
      ];
      final customLookalike = Quest(
        title: 'Name three good things',
        stat: Stat.intl,
        difficulty: 2,
        goalTitle: 'Keep a journal',
        custom: true,
      ).toJson();
      final otherGoalLookalike = Quest(
        title: 'One line a day',
        stat: Stat.intl,
        difficulty: 1,
        goalTitle: 'My private writing practice',
      ).toJson();
      final raw = jsonEncode({
        'app': 'emberkeep',
        'schema': 19,
        'state': GameState().toJson(),
        'quests': [...legacyAuthored, customLookalike, otherGoalLookalike],
      });

      expect(await Storage.importRaw(raw), isTrue);
      final loaded = await Storage.load();
      expect(loaded, isNotNull);
      final quests = loaded!.$2;

      for (final template in journalGoal.quests) {
        final restored = quests.firstWhere(
          (quest) =>
              !quest.custom &&
              quest.goalTitle == journalGoal.title &&
              quest.title == template.title,
        );
        expect(
          restored.journalPrompt,
          same(template.journalPrompt),
          reason: '${template.title} should regain its authored prompt',
        );
      }
      expect(
        quests
            .firstWhere(
              (quest) =>
                  quest.custom && quest.title == 'Name three good things',
            )
            .journalPrompt,
        isNull,
      );
      expect(
        quests
            .firstWhere(
              (quest) => quest.goalTitle == 'My private writing practice',
            )
            .journalPrompt,
        isNull,
      );
    },
  );

  test(
    'schema-19 individually adopted journal quest regains its prompt without a goal',
    () async {
      final journalGoal = goalCatalog.firstWhere(
        (goal) => goal.title == 'Keep a journal',
      );
      final template = journalGoal.quests.firstWhere(
        (quest) => quest.title == 'Name three good things',
      );
      final legacyQuest = template.build().toJson()..remove('journalPrompt');
      expect(legacyQuest['goalTitle'], isNull);
      final raw = jsonEncode({
        'app': 'emberkeep',
        'schema': 19,
        'state': GameState().toJson(),
        'quests': [legacyQuest],
      });

      expect(await Storage.importRaw(raw), isTrue);
      final loaded = await Storage.load();

      expect(loaded, isNotNull);
      expect(loaded!.$2.single.goalTitle, isNull);
      expect(loaded.$2.single.journalPrompt, same(template.journalPrompt));
    },
  );

  testWidgets('opening and leaving the prompt empty earns nothing', (
    tester,
  ) async {
    final state = GameState();
    final quest = _journalQuest();
    await _pumpBoard(tester, state: state, quests: [quest]);

    expect(find.text('OPEN JOURNAL'), findsOneWidget);
    await _openJournalQuest(tester, quest);

    expect(find.text(quest.title), findsWidgets);
    final editor = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(editor.controller.text, _prompt.starter);
    expect(state.journal, isEmpty);
    expect(quest.doneFor(Clock.now()), isFalse);

    await _leaveEditor(tester);

    expect(state.journal, isEmpty);
    expect(quest.doneFor(Clock.now()), isFalse);
    expect(state.totalXp, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a Journal quest stays silent and inactive on drag', (
    tester,
  ) async {
    final events = <String>[];
    final sfx = Sfx.instance;
    sfx.debugResetForTesting();
    sfx.debugBypassPlayback = true;
    sfx.debugOnPlay = events.add;
    addTearDown(sfx.debugResetForTesting);
    final state = GameState();
    final quest = _journalQuest();
    await _pumpBoard(tester, state: state, quests: [quest]);

    final card = find.byKey(ValueKey('card-${quest.title}'));
    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump(const Duration(milliseconds: 180));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.byType(JournalEntryScreen), findsNothing);
    expect(events, isEmpty);

    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(JournalEntryScreen), findsOneWidget);
    expect(events, ['open']);
  });

  testWidgets('catching a coasting quest board remains silent', (tester) async {
    final state = GameState();
    final quests = List<Quest>.generate(
      8,
      (i) => Quest(title: 'Quiet quest $i', stat: Stat.foc, difficulty: 2),
    );
    await _pumpBoard(tester, state: state, quests: quests);
    final board = find.byKey(const ValueKey('quest-board-scroll'));

    await tester.fling(board, const Offset(0, -500), 1200);
    await tester.pump(const Duration(milliseconds: 16));

    final events = <String>[];
    final sfx = Sfx.instance;
    sfx.debugResetForTesting();
    sfx.debugBypassPlayback = true;
    sfx.debugOnPlay = events.add;
    addTearDown(sfx.debugResetForTesting);
    final catchGesture = await tester.startGesture(tester.getCenter(board));
    await tester.pump();
    expect(events, isEmpty);
    await catchGesture.cancel();
  });

  testWidgets('an ordinary completion voices one accepted composite', (
    tester,
  ) async {
    final events = <String>[];
    final sfx = Sfx.instance;
    sfx.debugResetForTesting();
    sfx.debugBypassPlayback = true;
    sfx.debugOnPlay = events.add;
    addTearDown(sfx.debugResetForTesting);
    final state = GameState();
    final quest = Quest(
      title: 'Read ten pages',
      stat: Stat.intl,
      difficulty: 3,
    );
    await _pumpBoard(tester, state: state, quests: [quest]);

    await tester.tap(find.byKey(ValueKey('card-${quest.title}')));
    await tester.pump();
    expect(quest.doneFor(Clock.now()), isTrue);
    expect(events, ['complete']);

    // Drain the existing reward receipt/commit choreography before disposal;
    // this assertion is intentionally about the one accepted tap-time beat.
    sfx.soundEnabled = false;
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'saved writing keeps Quest context and completes through the normal reward once',
    (tester) async {
      final state = GameState();
      final quest = _journalQuest();
      await _pumpBoard(tester, state: state, quests: [quest]);
      await _openJournalQuest(tester, quest);

      final response = '${_prompt.starter}Mom. The late sunlight. Good coffee.';
      await tester.enterText(find.byType(TextField).first, response);
      await tester.pump(const Duration(milliseconds: 700));

      expect(state.journal, hasLength(1));
      expect(quest.doneFor(Clock.now()), isFalse);
      final saved = state.journal.single;
      expect(saved.sourceQuestKey, quest.title);
      expect(saved.context, state.buildTitle);
      expect(saved.trace?.day, Days.key(Clock.now()));
      expect(saved.trace?.questTitles, contains(quest.displayTitle));
      expect(saved.trace?.goalTitles, contains('Keep a journal'));

      await _leaveEditor(tester);
      expect(quest.doneFor(Clock.now()), isTrue);
      expect(state.journal, hasLength(1));

      // Let the normal deferred reward commit, then verify that the now-done
      // card cannot mint a second reward or a second page.
      await tester.pump(const Duration(milliseconds: 1600));
      final xp = state.totalXp;
      expect(xp, greaterThan(0));
      final card = find.byKey(ValueKey('card-${quest.title}'));
      if (tester.any(card)) {
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        await tester.tap(card);
      }
      await tester.pump(const Duration(milliseconds: 1800));
      expect(state.totalXp, xp);
      expect(state.journal, hasLength(1));

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('typing then immediately backing out still saves and completes', (
    tester,
  ) async {
    final state = GameState();
    final quest = _journalQuest();
    await _pumpBoard(tester, state: state, quests: [quest]);
    await _openJournalQuest(tester, quest);

    await tester.enterText(
      find.byType(TextField).first,
      '${_prompt.starter}Mom. The garden. A quiet cup of coffee.',
    );
    expect(state.journal, isEmpty, reason: 'the debounce has not fired yet');

    // PopScope flushes synchronously before the pushed route's Future resumes,
    // so the Quest completion check must see the last keystrokes immediately.
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(state.journal, hasLength(1));
    expect(quest.doneFor(Clock.now()), isTrue);

    await tester.pump(const Duration(seconds: 8));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a second tap that day resumes the linked draft', (tester) async {
    final state = GameState();
    final quest = _journalQuest();
    final draft = Note(
      at: Clock.now(),
      text: '${_prompt.starter}Mom.',
      rich: JournalDoc.encode([JournalBlock.text('${_prompt.starter}Mom.')]),
      sourceQuestKey: quest.title,
    );
    state.journal = [draft];

    await _pumpBoard(tester, state: state, quests: [quest]);
    await _openJournalQuest(tester, quest);

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('journal-entry-body')),
    );
    expect(field.controller!.text, draft.text);
    final span = field.controller!.buildTextSpan(
      context: tester.element(find.byKey(const ValueKey('journal-entry-body'))),
      style: field.style,
      withComposing: false,
    );
    final pieces = span.children!.cast<TextSpan>();
    expect(pieces.first.text, _prompt.starter);
    expect(pieces.first.style?.fontStyle, FontStyle.italic);
    expect(pieces.last.text, 'Mom.');
    await tester.enterText(
      find.byType(TextField).first,
      '${draft.text} The garden after rain.',
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(state.journal, hasLength(1));
    expect(state.journal.single.id, draft.id);
    await _leaveEditor(tester);
    expect(quest.doneFor(Clock.now()), isTrue);
    expect(state.journal, hasLength(1));

    await tester.pump(const Duration(seconds: 8));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Journal Quest and editor fit a 320px phone at 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final state = GameState();
    final quest = _journalQuest();
    await _pumpBoard(tester, state: state, quests: [quest], textScale: 2);

    await _openJournalQuest(tester, quest);
    expect(find.text(quest.title), findsWidgets);
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .controller
          .text,
      _prompt.starter,
    );
    expect(tester.takeException(), isNull);

    await _leaveEditor(tester);
    expect(quest.doneFor(Clock.now()), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
