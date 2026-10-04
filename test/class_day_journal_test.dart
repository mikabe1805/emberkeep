// Kept classes travel with the day's Journal page: a short line on the trace
// ("2 classes · Computer Architecture, Discrete Structures II"), threaded
// through every place the trace is rebuilt, and readable without the
// timetable (the labels are copied into the page).
import 'dart:math';

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/class_lines.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/journal_entry.dart';
import 'package:emberkeep/screens/journal_hub.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _tuesday = DateTime(2026, 10, 6, 20, 10);

ClassFacts _facts(String code, String title, int startMinute) => ClassFacts(
  courseCode: code,
  title: title,
  kind: 'lecture',
  dayKey: Days.key(_tuesday),
  startMinute: startMinute,
);

/// His Tuesday: both lectures kept (local facts, so any host zone works).
GameState _tuesdayKept() {
  Clock.freeze(_tuesday);
  final state = GameState()
    ..reduceMotion = true
    ..lastActiveDay = Days.key(_tuesday);
  final classes = [
    _facts('14:332:331', 'Computer Architecture & Assembly Language', 620),
    _facts('01:198:206', 'Introduction to Discrete Structures II', 840),
  ];
  final keys = [for (final facts in classes) facts.identity];
  for (final facts in classes) {
    expect(state.keepClass(facts, dayClassKeys: keys), isNotNull);
  }
  return state;
}

const _tuesdayLine =
    '2 classes · Computer Architecture, Discrete Structures II';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Sfx.instance.soundEnabled = false;
  });
  tearDown(() {
    Clock.reset();
    Sfx.instance.soundEnabled = true;
  });

  group('class words', () {
    test('times read like a timetable', () {
      expect(classTimeLabel(510), '8:30 AM');
      expect(classTimeLabel(620), '10:20 AM');
      expect(classTimeLabel(840), '2:00 PM');
      expect(classTimeLabel(1060), '5:40 PM');
      expect(classTimeLabel(0), '12:00 AM');
      expect(classTimeLabel(720), '12:00 PM');
    });

    test('long course titles shorten, short ones never change', () {
      expect(
        shortClassLabel('Computer Architecture & Assembly Language'),
        'Computer Architecture',
      );
      expect(
        shortClassLabel('Introduction to Discrete Structures II'),
        'Discrete Structures II',
      );
      expect(
        shortClassLabel('Linear Systems & Signals'),
        'Linear Systems & Signals',
      );
      expect(
        shortClassLabel('  Electronics   Devices '),
        'Electronics Devices',
      );
    });

    test('the trace line counts classes and names each course once', () {
      expect(classesKeptLine(const []), '');
      expect(
        classesKeptLine(const ['Electronics Devices']),
        '1 class · Electronics Devices',
      );
      expect(
        classesKeptLine(const [
          'Computer Architecture & Assembly Language',
          'Introduction to Discrete Structures II',
        ]),
        _tuesdayLine,
      );
      expect(
        classesKeptLine(const [
          'Electronics Devices',
          'Linear Systems & Signals',
          'Linear Systems & Signals',
        ]),
        '3 classes · Electronics Devices, Linear Systems & Signals',
      );
    });
  });

  test('the night trace copies one label per kept class', () {
    final state = _tuesdayKept();
    final trace = state.nightJournalTrace(const []);
    expect(trace.classTitles, [
      'Computer Architecture & Assembly Language',
      'Introduction to Discrete Structures II',
    ]);
    expect(trace.todayXp, 25 + 25 + ClassPay.fullDayBonusXp);
    expect(trace.hasDayEvidence, isTrue);
    final restored = JournalTrace.fromJson(trace.toJson())!;
    expect(restored.classTitles, trace.classTitles);
    // An older trace shape without the key reads as no classes.
    final legacy = JournalTrace.fromJson(
      trace.toJson()..remove('classTitles'),
    )!;
    expect(legacy.classTitles, isEmpty);
  });

  testWidgets('the Journal shows the class line live and on a saved page', (
    tester,
  ) async {
    final state = _tuesdayKept();
    await _pump(
      tester,
      JournalHubScreen(state: state, quests: const [], onPersist: () {}),
    );
    // Today's thread, before anything is written.
    expect(find.text(_tuesdayLine), findsOneWidget);

    state.setJournal([
      Note(
        id: 'tuesday-page',
        at: _tuesday,
        text: 'Two lectures, then home.',
        trace: state.nightJournalTrace(const []),
      ),
    ]);
    await _pump(
      tester,
      JournalHubScreen(state: state, quests: const [], onPersist: () {}),
    );
    // The thread and the saved card both carry it.
    expect(find.text(_tuesdayLine), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('journal-card-tuesday-page')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(JournalEntryScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(JournalEntryScreen),
        matching: find.text(_tuesdayLine),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Quest page rebuilt on the board keeps the day\'s classes', (
    tester,
  ) async {
    // A fixed roll: the Quest's reward (message, crit, loot) is the same on
    // every run, so anything its receipt does here reproduces.
    GameState.debugRandomFactory = () => Random(1);
    addTearDown(() => GameState.debugRandomFactory = null);
    final state = _tuesdayKept();
    final quest = Quest(
      title: 'Name three good things',
      stat: Stat.intl,
      difficulty: 2,
      journalPrompt: const JournalQuestPrompt(
        starter: 'Three good things:\n',
        hint: 'Anything counts.',
      ),
    );
    state.rollover([quest]);
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestsPage(
            state: state,
            quests: [quest],
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
    await tester.pump(const Duration(milliseconds: 200));
    final card = find.byKey(ValueKey('card-${quest.title}'));
    await tester.scrollUntilVisible(
      card,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    final action = find.descendant(
      of: card,
      matching: find.byKey(const ValueKey('quest-primary-action')),
    );
    await tester.ensureVisible(action);
    await tester.pump();
    await tester.tap(action);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    expect(find.byType(JournalEntryScreen), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      'Three good things:\nThe lab ran short.',
    );
    await tester.pump(const Duration(milliseconds: 700));

    final saved = state.journal.single;
    expect(saved.sourceQuestKey, quest.title);
    expect(saved.trace?.classTitles, [
      'Computer Architecture & Assembly Language',
      'Introduction to Discrete Structures II',
    ]);
    expect(find.text(_tuesdayLine), findsOneWidget);

    // The page's trace is what this test is about; leave before the Quest's
    // reward chain plays (journal_quest_entry_test covers it). Under the Ahem
    // test font some rolls (about 1 in 4 unseeded) grow that receipt's
    // column past its 0.34 x screen cap at 430 x 932; with the bundled
    // fonts no roll does, so it is a test-font artifact, not a phone one.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 8));
  });
}
