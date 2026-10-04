// Ported from the goals-everyday-review Extra Credit work (Mika's idea,
// 2026-09-03) onto the Build 49 board: the night ledger is an owned route
// with its own Navigator, so the writing opens above the folio.
import 'dart:convert';

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/honey_button.dart';
import 'package:emberkeep/widgets/levelup_overlay.dart';
import 'package:emberkeep/widgets/routine_flows.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _entryKey = Key('extra-credit-entry');
const _sheetKey = Key('extra-credit-sheet');
const _fieldKey = Key('extra-credit-field');
const _saveKey = Key('extra-credit-save');
const _words = 'I went to all my classes';

GameState _state({bool empty = false}) {
  final state = GameState()
    ..onboarded = true
    ..playerName = 'Mika'
    ..reduceMotion = true
    ..lastActiveDay = Days.key(Clock.now());
  if (!empty) {
    state
      ..xp = 42
      ..totalXp = 42
      ..todayXp = 42
      ..todayStats[Stat.intl] = 3
      ..todayStats[Stat.foc] = 2
      ..todayQuestTitles.addAll(['Read the chapter', 'Send the email'])
      ..history[Days.key(Clock.now())] = 2;
  }
  return state;
}

Future<void> _mountBoard(
  WidgetTester tester,
  GameState state, {
  Size size = const Size(430, 932),
  double textScale = 1,
  VoidCallback? onPersist,
}) async {
  tester.view.devicePixelRatio = 1;
  await tester.binding.setSurfaceSize(size);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.binding.setSurfaceSize(null);
  });
  final quests = [
    Quest(
      title: 'Take a walk',
      stat: Stat.vit,
      difficulty: 2,
      schedule: QuestSchedule.daily,
    ),
  ];
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: QuestsPage(
          state: state,
          quests: quests,
          onRefresh: () => 0,
          onPersist: onPersist ?? () {},
          onAdd: (_) => true,
          onRemove: (_) {},
          onSnapshot: () => jsonEncode(state.toJson()),
          onRestore: (_) {},
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

/// Opens the ledger from whichever door the board shows at this hour: the
/// evening rail, else the footer's CLOSE DAY.
Future<void> _openLedger(WidgetTester tester) async {
  final rail = find.byKey(const Key('close-day-rail'));
  final footer = find.text('CLOSE DAY');
  final evening = Clock.now().hour >= 17 || Clock.now().hour < 4;
  if (rail.evaluate().isEmpty && footer.evaluate().isEmpty) {
    // The board builds lazily; on a short phone the door is further down.
    await tester.scrollUntilVisible(
      evening ? rail : footer,
      240,
      scrollable: find
          .descendant(
            of: find.byType(QuestsPage),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    await tester.pump(const Duration(milliseconds: 150));
  }
  final door = rail.evaluate().isNotEmpty ? rail : footer.first;
  await tester.ensureVisible(door);
  await tester.pump(const Duration(milliseconds: 150));
  await tester.tap(door);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byType(NightFlow), findsOneWidget);
}

Future<void> _openComposer(WidgetTester tester) async {
  final entry = find.byKey(_entryKey);
  await tester.ensureVisible(entry);
  await tester.pump(const Duration(milliseconds: 200));
  expect(entry.hitTestable(), findsOneWidget);
  await tester.tap(entry);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 240));
  expect(find.byKey(_sheetKey), findsOneWidget);
  await tester.ensureVisible(find.byKey(_fieldKey));
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.byKey(_fieldKey).hitTestable(), findsOneWidget);
}

Future<void> _save(WidgetTester tester, {String words = _words}) async {
  await tester.enterText(find.byKey(_fieldKey), words);
  await tester.pump();
  await tester.ensureVisible(find.byKey(_saveKey));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.byKey(_saveKey));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Finder _actionIn(String title) => find.descendant(
  of: find.byKey(ValueKey('card-$title')),
  matching: find.byKey(const ValueKey('quest-primary-action')),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Sfx.instance.soundEnabled = false;
    Clock.freeze(DateTime(2026, 9, 3, 21, 30));
  });

  tearDown(() {
    Clock.reset();
    Sfx.instance.soundEnabled = true;
  });

  testWidgets('real Quest board ledger claims, edits, and restores once', (
    tester,
  ) async {
    final state = _state();
    String? saved;
    await _mountBoard(
      tester,
      state,
      onPersist: () => saved = jsonEncode(state.toJson()),
    );
    await _openLedger(tester);
    await _openComposer(tester);
    expect(tester.widget<HoneyButton>(find.byKey(_saveKey)).enabled, isFalse);
    expect(state.xp, 42, reason: 'opening and writing do not award XP');
    expect(
      find.text('I went to all my classes'),
      findsOneWidget,
      reason: 'his own words stay as the example',
    );
    await tester.enterText(find.byKey(_fieldKey), _words);
    await tester.pump();
    expect(state.xp, 42);
    await _save(tester);

    expect(find.byKey(_sheetKey), findsNothing);
    expect(state.xp, 52);
    expect(state.totalXp, 52);
    expect(state.nightXp, 52);
    expect(state.nightCompletionCount, 2);
    expect(state.nightDoneDay, isNull);
    expect(state.journal, isEmpty);
    expect(state.extraCreditEntries.single.title, _words);
    expect(find.text(_words), findsOneWidget);

    await _openComposer(tester);
    expect(find.text('SAVE WORDING'), findsOneWidget);
    expect(find.text('ADD +10 XP'), findsNothing);
    await _save(tester, words: 'I went to class and helped a friend');
    expect(state.xp, 52);
    expect(state.extraCreditEntries, hasLength(1));
    expect(saved, isNotNull);

    final restored = GameState.fromJson(
      (jsonDecode(saved!) as Map).cast<String, dynamic>(),
    );
    expect(
      restored.extraCreditEntries.single.title,
      'I went to class and helped a friend',
    );
    expect(restored.nightXp, 52);
    expect(restored.addExtraCredit('One more', dayKey: '2026-09-03'), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty day stays optional and cancel or blank input is pure', (
    tester,
  ) async {
    final state = _state(empty: true);
    var persists = 0;
    await _mountBoard(tester, state, onPersist: () => persists++);
    await _openLedger(tester);
    expect(find.text('Nothing had to be proven today.'), findsOneWidget);
    expect(find.text('Something else counted?'), findsOneWidget);
    await _openComposer(tester);
    await tester.enterText(find.byKey(_fieldKey), '   ');
    await tester.pump();
    expect(tester.widget<HoneyButton>(find.byKey(_saveKey)).enabled, isFalse);
    await tester.enterText(find.byKey(_fieldKey), 'An unsaved thought');
    await tester.tap(find.byTooltip('Not now'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(state.extraCreditEntries, isEmpty);
    expect(state.xp, 0);
    expect(state.history, isEmpty);
    expect(state.nightDoneDay, isNull);
    expect(persists, 0);
    await _openComposer(tester);
    await _save(tester);
    expect(state.nightCompletionCount, 0);
    expect(state.streakDays, 0);
    expect(state.perfectDays, 0);
    expect(state.extraCreditEntries.single.title, _words);
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing night reflection receives the distinct receipt', (
    tester,
  ) async {
    final state = _state();
    state.saveNightJournal(
      const NightJournalData(reflection: 'Showing up mattered today.'),
      state.nightJournalTrace(const []),
    );
    final noteId = state.journal.single.id;
    await _mountBoard(tester, state);
    await _openLedger(tester);
    await _openComposer(tester);
    await _save(tester);

    expect(state.journal, hasLength(1));
    expect(state.journal.single.id, noteId);
    expect(state.journal.single.trace!.extraCreditTitles, [_words]);
    expect(state.journal.single.trace!.questTitles, hasLength(2));
    expect(state.journal.single.trace!.todayXp, 52);
    expect(tester.takeException(), isNull);
  });

  testWidgets('afternoon access does not require finishing all Quests', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 9, 3, 15, 30));
    final state = _state();
    await _mountBoard(tester, state);
    expect(find.byKey(const Key('close-day-rail')), findsNothing);
    await _openLedger(tester);
    await _openComposer(tester);
    await _save(tester);
    expect(state.xp, 52);
    expect(state.nightDoneDay, isNull);
    expect(state.dayRestingNow, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale editor keeps the words and never credits a new day', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 9, 4, 3, 59));
    final state = _state(empty: true);
    await _mountBoard(tester, state);
    await _openLedger(tester);
    await _openComposer(tester);
    Clock.freeze(DateTime(2026, 9, 4, 4));
    await _save(tester);

    expect(find.byKey(_sheetKey), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(_fieldKey)).controller!.text,
      _words,
    );
    expect(find.textContaining('A new day has started.'), findsOneWidget);
    expect(state.extraCreditEntries, isEmpty);
    expect(state.xp, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('extra-credit level threshold resolves on leaving the recap', (
    tester,
  ) async {
    final state = _state(empty: true);
    state.xp = state.xpNeeded(2) - 5;
    state.totalXp = state.xp;
    await _mountBoard(tester, state);
    await _openLedger(tester);
    await _openComposer(tester);
    await _save(tester);
    expect(state.level, 1, reason: 'let the person see the receipt first');
    expect(find.byType(LevelUpOverlay), findsNothing);
    await tester.tap(find.text('NOT YET'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    expect(state.level, 2);
    expect(state.xp, 5);
    expect(find.byType(LevelUpOverlay), findsOneWidget);
    expect(state.totalCompletions, 0);
    expect(state.history, isEmpty);
    expect(state.streakDays, 0);
    expect(state.nightDoneDay, isNull);
    expect(tester.takeException(), isNull);
    tester.widget<LevelUpOverlay>(find.byType(LevelUpOverlay)).onDismiss();
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('back closes the writing first, then the ledger without saving', (
    tester,
  ) async {
    final state = _state();
    await _mountBoard(tester, state);
    await _openLedger(tester);
    await _openComposer(tester);
    await tester.enterText(find.byKey(_fieldKey), 'Not kept yet');
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(_sheetKey), findsNothing);
    expect(find.byType(NightFlow), findsOneWidget);
    expect(state.extraCreditEntries, isEmpty);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(NightFlow), findsNothing);
    expect(state.nightDoneDay, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save replacement closes the whole private writing stack', (
    tester,
  ) async {
    final oldState = _state();
    await _mountBoard(tester, oldState);
    await _openLedger(tester);
    await _openComposer(tester);
    await tester.enterText(find.byKey(_fieldKey), 'Private unsaved words');

    final restored = _state(empty: true);
    await _mountBoard(tester, restored);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(_sheetKey), findsNothing);
    expect(find.byType(NightFlow), findsNothing);
    expect(oldState.extraCreditEntries, isEmpty);
    expect(restored.extraCreditEntries, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reflection opens above the board-owned ledger, not behind it', (
    tester,
  ) async {
    final state = _state();
    await _mountBoard(tester, state);
    await _openLedger(tester);
    final reflect = find.text('reflect · optional');
    await tester.ensureVisible(reflect);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(reflect);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Build 49 put this sheet on the root navigator, beneath the ledger's
    // overlay entry: in the tree, never hit-testable, and surfacing only
    // after CLOSE THE DAY.
    expect(
      find.byKey(const Key('night-reflection-sheet')).hitTestable(),
      findsOneWidget,
    );
    final field = find.byKey(const Key('night-reflection-field'));
    expect(field.hitTestable(), findsOneWidget);
    await tester.enterText(field, 'A day worth keeping.');
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('night-reflection-sheet')), findsNothing);
    expect(find.byType(NightFlow), findsOneWidget);
    expect(state.journal, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('earlier full-save Quest undo cannot erase new extra credit', (
    tester,
  ) async {
    final state = _state(empty: true);
    await _mountBoard(tester, state, size: const Size(430, 1400));
    final action = _actionIn('Take a walk');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pump(const Duration(milliseconds: 1400));
    final undo = find.byKey(const ValueKey('undo-Take a walk'));
    expect(undo, findsOneWidget);

    await _openLedger(tester);
    await _openComposer(tester);
    await _save(tester);
    final creditedXp = state.totalXp;
    await tester.tap(find.text('NOT YET'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(undo, findsNothing);
    expect(state.totalXp, creditedXp);
    expect(state.extraCreditEntries.single.title, _words);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('opening the ledger lands a Quest reward still settling', (
    tester,
  ) async {
    final state = _state(empty: true);
    await _mountBoard(tester, state, size: const Size(430, 1400));
    final action = _actionIn('Take a walk');
    await tester.ensureVisible(action);
    await tester.tap(action);
    // Inside the 520 ms staged commit: the reward is not in the state yet.
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.totalXp, 0);

    await _openLedger(tester);
    expect(state.totalXp, greaterThan(0));
    expect(state.nightQuestTitles, ['Take a walk']);
    expect(find.text('ONE THREAD FINISHED'), findsOneWidget);
    await tester.tap(find.text('NOT YET'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('rapid activation keeps one ledger, editor, and award', (
    tester,
  ) async {
    final state = _state();
    state.reduceMotion = false;
    await _mountBoard(tester, state);
    final rail = find.byKey(const Key('close-day-rail'));
    await tester.ensureVisible(rail);
    await tester.pump(const Duration(milliseconds: 150));
    final railPosition = tester.getCenter(rail);
    await tester.tapAt(railPosition);
    await tester.tapAt(railPosition);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.byType(NightFlow), findsOneWidget);
    final entry = find.byKey(_entryKey);
    await tester.ensureVisible(entry);
    await tester.pump(const Duration(milliseconds: 600));
    final entryPosition = tester.getCenter(entry);
    await tester.tapAt(entryPosition);
    await tester.tapAt(entryPosition);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(_sheetKey), findsOneWidget);
    await tester.enterText(find.byKey(_fieldKey), _words);
    await tester.pump();
    final save = tester.widget<HoneyButton>(find.byKey(_saveKey));
    save.onTap();
    save.onTap();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));
    expect(state.xp, 52);
    expect(state.extraCreditEntries, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  for (final scale in [1.5, 2.0]) {
    testWidgets('narrow ${scale}x text keeps keyboard and claim reachable', (
      tester,
    ) async {
      final state = _state();
      await _mountBoard(
        tester,
        state,
        size: const Size(320, 568),
        textScale: scale,
      );
      await _openLedger(tester);
      await _openComposer(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 230);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byKey(_fieldKey), _words);
      await tester.pump();
      await tester.ensureVisible(find.byKey(_saveKey));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(_saveKey).hitTestable(), findsOneWidget);
      expect(
        tester.getBottomRight(find.byKey(_saveKey)).dy,
        lessThanOrEqualTo(568 - 230),
      );
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('ADD +10 XP'))
            .didExceedMaxLines,
        isFalse,
      );
      await tester.tap(find.byKey(_saveKey));
      await tester.pump(const Duration(milliseconds: 300));
      tester.view.resetViewInsets();
      await tester.pump(const Duration(milliseconds: 250));
      expect(state.extraCreditEntries.single.title, _words);
      expect(state.xp, 52);
      await tester.ensureVisible(find.byKey(_entryKey));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('CLOSE THE DAY').last);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('CLOSE THE DAY').last.hitTestable(), findsOneWidget);
    });
  }
}
