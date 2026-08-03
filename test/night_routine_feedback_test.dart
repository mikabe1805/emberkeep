import 'dart:ui' show SemanticsAction;

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/routines.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/night_reflection_sheet.dart';
import 'package:emberkeep/widgets/routine_flows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    Sfx.instance.soundEnabled = false;
  });

  tearDown(() {
    Clock.reset();
    Sfx.instance.soundEnabled = true;
  });

  test('wind-down window crosses midnight without gating the routine', () {
    expect(isWindDownTime(DateTime(2026, 8, 3, 16, 59)), isFalse);
    expect(isWindDownTime(DateTime(2026, 8, 3, 17)), isTrue);
    expect(isWindDownTime(DateTime(2026, 8, 4, 3, 59)), isTrue);
    expect(isWindDownTime(DateTime(2026, 8, 4, 4)), isFalse);
    expect(Days.nightKey(DateTime(2026, 8, 4, 3, 59)), '2026-08-03');
    expect(Days.nightKey(DateTime(2026, 8, 4, 4)), '2026-08-04');
    expect(Days.afterNight(DateTime(2026, 8, 4, 3)), DateTime(2026, 8, 4));
  });

  test('night reminder defaults off and survives a save round trip', () {
    final fresh = GameState();
    expect(fresh.nightReminderEnabled, isFalse);
    expect(fresh.nightReminderHour, 21);
    expect(fresh.nightReminderMinute, 0);

    fresh.setNightReminder(enabled: true, hour: 22, minute: 35);
    final restored = GameState.fromJson(fresh.toJson());
    expect(restored.nightReminderEnabled, isTrue);
    expect(restored.nightReminderHour, 22);
    expect(restored.nightReminderMinute, 35);

    final damaged = GameState.fromJson({
      'nightReminderEnabled': true,
      'nightReminderHour': 90,
      'nightReminderMinute': -4,
    });
    expect(damaged.nightReminderHour, 23);
    expect(damaged.nightReminderMinute, 0);
  });

  test('one structured night page updates in place and arms one message', () {
    final now = DateTime(2026, 8, 3, 22, 10);
    Clock.freeze(now);
    final state = GameState()..playerName = 'Mika';
    final trace = state.todayJournalTrace(const []);

    final first = state.saveNightJournal(
      const NightJournalData(
        reflection: '  The walk helped.  ',
        gratitudes: ['Mom', '', 'Cold water', 'ignored'],
        tomorrowMessage: '  Start with the email.  ',
      ),
      trace,
    );
    expect(first, isNotNull);
    expect(state.journal, hasLength(1));
    expect(first!.text, contains('Grateful for'));
    expect(first.text, contains('• Mom'));

    final id = first.id;
    state.saveNightJournal(
      const NightJournalData(
        reflection: 'The walk helped.',
        discovery: 'I focus better after dinner.',
        tomorrowMessage: 'Start with the email.',
      ),
      trace,
    );
    expect(state.journal, hasLength(1));
    expect(state.journal.single.id, id);

    state.finalizeNightJournal(trace);
    state.closeNight();
    expect(state.nightDraftNoteId, isNull);
    expect(state.pendingMorningNoteId, id);
    expect(state.morningSelfMessage, 'Start with the email.');

    state.finalizeNightJournal(trace);
    expect(
      state.pendingMorningNoteId,
      id,
      reason: 'a duplicate finalize must not consume tomorrow’s message',
    );

    final restored = GameState.fromJson(state.toJson());
    expect(restored.journal, hasLength(1));
    expect(restored.pendingMorningNoteId, id);
    expect(restored.morningSelfMessage, 'Start with the email.');

    restored.closeMorning();
    expect(restored.morningSelfMessage, isNull);
    expect(restored.journal.single.night?.discovery, isNotEmpty);
    restored.updateNightJournalEntry(
      restored.journal.single,
      const NightJournalData(),
    );
    expect(restored.journal, isEmpty);
  });

  test('a 3am close owns the prior day and preserves its rolled-over haul', () {
    Clock.freeze(DateTime(2026, 8, 3, 23, 50));
    final state = GameState()
      ..lastActiveDay = '2026-08-03'
      ..todayXp = 42;
    state.todayStats[Stat.foc] = 3;
    state.todayQuestTitles.add('Finish the chapter');
    state.history['2026-08-03'] = 1;

    Clock.freeze(DateTime(2026, 8, 4, 0, 1));
    expect(state.rollover([]), isTrue);
    Clock.freeze(DateTime(2026, 8, 4, 3));
    final trace = state.nightJournalTrace(const []);
    expect(trace.day, '2026-08-03');
    expect(trace.todayXp, 42);
    expect(trace.questTitles, ['Finish the chapter']);
    expect(state.nightCompletionCount, 1);

    state.saveNightJournal(
      const NightJournalData(reflection: 'Monday, finally closed.'),
      trace,
    );
    state.finalizeNightJournal(trace);
    state.closeNight();
    expect(state.nightDoneDay, '2026-08-03');

    Clock.freeze(DateTime(2026, 8, 4, 20));
    expect(state.activeNightDayKey, '2026-08-04');
    expect(state.nightDoneDay, isNot(state.activeNightDayKey));

    final restored = GameState.fromJson(state.toJson());
    expect(restored.previousDayKey, '2026-08-03');
    expect(restored.previousDayXp, 42);
  });

  test('an unfinished page cannot become a later night’s draft', () {
    Clock.freeze(DateTime(2026, 8, 3, 21));
    final state = GameState();
    final first = state.saveNightJournal(
      const NightJournalData(reflection: 'Monday note'),
      state.nightJournalTrace(const []),
    )!;

    Clock.freeze(DateTime(2026, 8, 4, 21));
    expect(state.nightDraftNote, isNull);
    final second = state.saveNightJournal(
      const NightJournalData(reflection: 'Tuesday note'),
      state.nightJournalTrace(const []),
    )!;
    expect(second.id, isNot(first.id));
    expect(state.journal, hasLength(2));
    expect(state.journal.first.trace?.day, '2026-08-03');
    expect(state.journal.last.trace?.day, '2026-08-04');
  });

  testWidgets('night prompts are optional, composite, and returned tomorrow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    final night = DateTime(2026, 8, 3, 22, 15);
    Clock.freeze(night);
    final state = GameState()..reduceMotion = true;
    state.todayQuestTitles.add('Read ten pages');
    var closed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: NightFlow(
          state: state,
          quests: [
            Quest(title: 'Read ten pages', stat: Stat.intl, difficulty: 2),
          ],
          onAdd: (_) => true,
          onPersist: () {},
          onClose: () => closed = true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    final recapScroll = find.descendant(
      of: find.byKey(const ValueKey('recap')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('reflect · optional'),
      180,
      scrollable: recapScroll,
    );
    await tester.tap(find.text('reflect · optional'));
    await tester.pump(const Duration(milliseconds: 600));

    final integratedSheet = find.byKey(const Key('night-reflection-sheet'));
    expect(tester.getSize(integratedSheet).height, greaterThanOrEqualTo(900));
    expect(tester.getTopLeft(integratedSheet).dy, lessThanOrEqualTo(12));
    expect(find.text('Optional reflection'), findsOneWidget);
    expect(find.text('3 GRATEFUL'), findsOneWidget);
    expect(find.text('DISCOVERED'), findsOneWidget);
    expect(find.text('TOMORROW'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('night-reflection-field')),
      'Reading made the night quieter.',
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('3 GRATEFUL'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(
      find.byKey(const Key('night-gratitude-0')),
      'Dinner together',
    );
    await tester.enterText(
      find.byKey(const Key('night-gratitude-1')),
      'The rain',
    );
    await tester.enterText(
      find.byKey(const Key('night-gratitude-2')),
      'A good book',
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('DISCOVERED'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(
      find.byKey(const Key('night-discovery-field')),
      'I sleep better when I read first.',
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.ensureVisible(find.text('TOMORROW'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.text('TOMORROW'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(
      find.byKey(const Key('night-tomorrow-field')),
      'Put the book beside the bed again.',
    );
    await tester.ensureVisible(find.text('KEEP TONIGHT’S PAGE'));
    await tester.tap(find.text('KEEP TONIGHT’S PAGE'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(state.journal, hasLength(1));
    expect(state.journal.single.night?.normalizedGratitudes, hasLength(3));
    expect(state.journal.single.text, contains('I discovered'));
    expect(closed, isFalse, reason: 'writing must not close the night');

    await tester.scrollUntilVisible(
      find.text('CLOSE THE DAY'),
      180,
      scrollable: recapScroll,
    );
    await tester.tap(find.text('CLOSE THE DAY'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(closed, isTrue);
    expect(state.morningSelfMessage, 'Put the book beside the bed again.');

    Clock.freeze(DateTime(2026, 8, 4, 8));
    var later = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MorningFlow(
          state: state,
          quests: const [],
          onDismiss: () => later = true,
          onClose: state.closeMorning,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('FROM LAST NIGHT'), findsOneWidget);
    expect(find.text('Put the book beside the bed again.'), findsOneWidget);
    await tester.tap(find.text('LATER'));
    expect(later, isTrue);
    expect(
      state.morningSelfMessage,
      isNotNull,
      reason: 'Later must keep the morning note for the next opening.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('evening Quest board gives the ledger one labeled 52px rail', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 8, 3, 20, 30));
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    final state = GameState()
      ..onboarded = true
      ..reduceMotion = true;
    final quests = [
      Quest(
        title: 'Call Mom',
        stat: Stat.soc,
        difficulty: 2,
        schedule: QuestSchedule.daily,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestsPage(
            state: state,
            quests: quests,
            onRefresh: () => 0,
            onPersist: () {},
            onAdd: (_) => true,
            onRemove: (_) {},
            onSnapshot: () => '',
            onRestore: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    final rail = find.byKey(const Key('close-day-rail'));
    expect(rail, findsOneWidget);
    expect(tester.getSize(rail).height, greaterThanOrEqualTo(52));
    expect(find.text('CLOSE THE DAY'), findsOneWidget);
    expect(find.byIcon(Icons.nightlight_outlined), findsOneWidget);
    final railSemantics = tester.getSemantics(
      find.bySemanticsLabel(RegExp('Close the day')),
    );
    expect(
      railSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(rail);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Close the ledger'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('night prompt sheet reflows at 320x568 and 1.5x text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showNightReflectionSheet(context),
                child: const Text('Reflect'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Reflect'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Keep what matters'), findsOneWidget);
    expect(find.text('Optional reflection'), findsOneWidget);
    expect(find.text('3 GRATEFUL'), findsOneWidget);
    expect(find.text('DISCOVERED'), findsOneWidget);
    expect(find.text('TOMORROW'), findsOneWidget);
    final compactSheet = find.byKey(const Key('night-reflection-sheet'));
    expect(tester.getSize(compactSheet).height, greaterThanOrEqualTo(540));
    expect(tester.getTopLeft(compactSheet).dy, lessThanOrEqualTo(12));
    expect(find.text('KEEP TONIGHT’S PAGE'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('3 GRATEFUL'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const Key('night-gratitude-0')), findsOneWidget);
    expect(find.byKey(const Key('night-gratitude-2')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('night-gratitude-2')));
    await tester.pump(const Duration(milliseconds: 150));
    expect(
      tester.getBottomRight(find.byKey(const Key('night-gratitude-2'))).dy,
      lessThanOrEqualTo(568),
    );
    await tester.ensureVisible(find.text('KEEP TONIGHT’S PAGE'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('KEEP TONIGHT’S PAGE').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('night prompt sheet immerses a normal phone', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showNightReflectionSheet(context),
                child: const Text('Reflect'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Reflect'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final sheet = find.byKey(const Key('night-reflection-sheet'));
    expect(sheet, findsOneWidget);
    expect(
      tester.getSize(sheet).height,
      greaterThanOrEqualTo(900),
      reason: 'the optional ledger is a full-screen evening ritual',
    );
    expect(
      tester.getTopLeft(sheet).dy,
      lessThanOrEqualTo(12),
      reason: 'only the faceted edge should reveal the ledger behind it',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('clearing an existing night page offers an explicit removal', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    NightJournalData? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showNightReflectionSheet(
                  context,
                  initial: const NightJournalData(reflection: 'Keep me'),
                );
              },
              child: const Text('Edit night page'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit night page'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byKey(const Key('night-reflection-field')), '');
    await tester.pump();
    expect(find.text('REMOVE TONIGHT’S PAGE'), findsOneWidget);
    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('REMOVE TONIGHT’S PAGE'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(result?.isEmpty, isTrue);
  });

  testWidgets('tomorrow-self note fits a small morning at 1.5x text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    Clock.freeze(DateTime(2026, 8, 3, 22, 15));
    final state = GameState()..reduceMotion = true;
    final trace = state.todayJournalTrace(const []);
    state.saveNightJournal(
      const NightJournalData(
        tomorrowMessage:
            'Begin with the chapter that matters, then let the rest wait.',
      ),
      trace,
    );
    state.finalizeNightJournal(trace);
    state.closeNight();
    Clock.freeze(DateTime(2026, 8, 4, 7, 30));

    await tester.pumpWidget(
      MaterialApp(
        home: MorningFlow(
          state: state,
          quests: const [],
          onDismiss: () {},
          onClose: state.closeMorning,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('FROM LAST NIGHT'), findsOneWidget);
    expect(find.textContaining('Begin with the chapter'), findsOneWidget);
    expect(find.text('LATER'), findsOneWidget);
    await tester.tap(find.textContaining('Begin with the chapter'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('CLOSE'), findsOneWidget);
    expect(
      find.text('Begin with the chapter that matters, then let the rest wait.'),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
}
