// The Journal as the reading nook: the "Write for today" card and its four
// ways in, the last three entries, the Keepsakes label, the empty state, every
// older lens still reachable under it, large text, Reduce Motion, and the
// writing view itself left as it was.
import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/insights.dart';
import 'package:emberkeep/screens/journal_entry.dart';
import 'package:emberkeep/screens/journal_hub.dart';
import 'package:emberkeep/screens/memory_cabinet.dart';
import 'package:emberkeep/screens/weekly_chronicle.dart';
import 'package:emberkeep/widgets/house/house_light.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:emberkeep/widgets/house/journal/journal_nook.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

final _today = DateTime(2026, 10, 6, 12, 30);

Note _note(String text, DateTime at) => Note(at: at, text: text);

List<Note> _three() => [
  _note('A warm detail', DateTime(2026, 10, 2, 21)),
  _note('A small win', DateTime(2026, 10, 4, 20)),
  _note('After the quest', DateTime(2026, 10, 5, 21)),
  // older than the three: not in the nook
  _note('Long ago', DateTime(2026, 9, 20, 21)),
];

GameState _busy() {
  final state = GameState()
    ..reduceMotion = true
    ..totalCompletions = 40
    ..setJournal(_three());
  for (var i = 0; i < 9; i++) {
    state.history[Days.key(_today.subtract(Duration(days: i)))] = 1 + i % 3;
  }
  return state;
}

Future<void> _pump(
  WidgetTester tester,
  GameState state, {
  double textScale = 1,
  bool disableAnimations = false,
  List<Quest> quests = const [],
}) async {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
          padding: const EdgeInsets.only(bottom: 34),
        ),
        child: child!,
      ),
      home: Material(
        type: MaterialType.transparency,
        child: InsightsPage(state: state, quests: quests, onPersist: () {}),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

JournalEntryScreen _writer(WidgetTester tester) =>
    tester.widget<JournalEntryScreen>(find.byType(JournalEntryScreen));

/// Back out of the page on top, the way the back gesture does.
void _pop(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();

/// Scrolls the page until [target] is built and sits well inside the screen.
/// Drags from the left margin, clear of the Keepsakes label (which at large
/// text reaches the middle of the screen).
Future<void> _reveal(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 40 && target.evaluate().isEmpty; i++) {
    await tester.dragFrom(const Offset(8, 600), const Offset(0, -220));
    await tester.pump();
  }
  expect(target, findsWidgets, reason: 'the page scrolls to it');
  // bring it into the upper half, clear of the dock
  for (var i = 0; i < 20; i++) {
    final y = tester.getCenter(target.first).dy;
    if (y < 520) break;
    await tester.dragFrom(const Offset(8, 700), const Offset(0, -120));
    await tester.pump();
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    Sfx.instance.soundEnabled = false;
    Clock.freeze(_today);
  });

  tearDown(() {
    Sfx.instance.soundEnabled = true;
    Clock.reset();
  });

  group('the nook', () {
    testWidgets('dates the page and names the four ways in', (tester) async {
      await _pump(tester, GameState()..setJournal(_three()));
      expect(find.text('TUE · OCT 6'), findsOneWidget);
      expect(find.text('Write for today'), findsOneWidget);
      for (final label in [
        'After the quest',
        'A small win',
        'Set it down',
        'A warm detail',
      ]) {
        // the chip, not an entry row
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('journal-nook-prompts')),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: label,
        );
      }
      expect(find.text('KEEPSAKES'), findsOneWidget);
    });

    testWidgets('the four chips sit two by two', (tester) async {
      await _pump(tester, GameState()..setJournal(_three()));
      Offset at(String id) =>
          tester.getTopLeft(find.byKey(ValueKey('journal-nook-chip-$id')));
      expect(at('after-the-quest').dy, at('a-small-win').dy);
      expect(at('set-it-down').dy, at('a-warm-detail').dy);
      expect(at('set-it-down').dy, greaterThan(at('after-the-quest').dy));
      expect(at('a-small-win').dx, greaterThan(at('after-the-quest').dx));
      expect(at('a-warm-detail').dx, at('a-small-win').dx);
    });

    testWidgets('the Keepsakes label stays clear above the card', (
      tester,
    ) async {
      await _pump(tester, GameState()..setJournal(_three()));
      final card = tester.getRect(
        find.byKey(const ValueKey('journal-nook-card')),
      );
      final tag = tester.getRect(
        find.byKey(const ValueKey('journal-keepsakes-tag')),
      );
      expect(tag.bottom, lessThan(card.top));
      // and it hangs on the right, by the painted box
      expect(tag.right, closeTo(393 - 14, 1));
      expect(tag.top, closeTo(398, 1));
    });
  });

  group('the chips open the writing view', () {
    for (final (id, label, hint, starter) in [
      (
        'after-the-quest',
        'After the quest',
        'What made it easier, harder, or worth repeating?',
        'After the quest:\n',
      ),
      (
        'a-small-win',
        'A small win',
        'Start with something that counted, even if nobody saw it.',
        'One small win today:\n',
      ),
      (
        'set-it-down',
        'Set it down',
        'Name what felt heavy. You do not need to solve it here.',
        'What felt heavy:\n',
      ),
      (
        'a-warm-detail',
        'A warm detail',
        'Hold onto one person, place, or moment you are grateful for.',
        'Something I’m grateful for:\n',
      ),
    ]) {
      testWidgets('$label opens it with its prompt', (tester) async {
        await _pump(tester, GameState()..setJournal(_three()));
        await tester.tap(find.byKey(ValueKey('journal-nook-chip-$id')));
        await _settle(tester);
        final screen = _writer(tester);
        expect(screen.heading, label);
        expect(screen.hint, hint);
        expect(screen.starter, starter);
        expect(screen.initial, isNull);
        expect(screen.initiallyEditing, isTrue);
        expect(find.byType(JournalHubScreen), findsNothing);
      });
    }

    testWidgets('After the quest names the quest you did today', (
      tester,
    ) async {
      final state = GameState()
        ..setJournal(_three())
        ..todayQuestTitles.add('Read ten pages');
      await _pump(tester, state);
      await tester.tap(
        find.byKey(const ValueKey('journal-nook-chip-after-the-quest')),
      );
      await _settle(tester);
      expect(_writer(tester).starter, 'After “Read ten pages”:\n');
    });

    testWidgets('Write for today opens it blank', (tester) async {
      await _pump(tester, GameState()..setJournal(_three()));
      await tester.tap(find.byKey(const ValueKey('journal-nook-write')));
      await _settle(tester);
      final screen = _writer(tester);
      expect(screen.initial, isNull);
      expect(screen.starter, isNull);
      expect(screen.heading, 'Journal');
      expect(screen.hint, 'What’s on your mind today?');
    });

    testWidgets('a page written from the nook is saved and listed', (
      tester,
    ) async {
      final state = GameState()..setJournal(_three());
      await _pump(tester, state);
      await tester.tap(
        find.byKey(const ValueKey('journal-nook-chip-a-small-win')),
      );
      await _settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('journal-entry-body')),
        'One small win today:\nI called my sister.',
      );
      await tester.pump(const Duration(milliseconds: 750));
      await tester.tap(find.byKey(const ValueKey('journal-entry-done')));
      await _settle(tester);
      await tester.tap(find.byIcon(Icons.chevron_left).last);
      await _settle(tester);
      expect(state.journal, hasLength(5));
      final written = state.journal.last;
      expect(written.text, contains('I called my sister.'));
      expect(written.at, _today);
      // the same page the Journal hub writes: stamped with who you were, and
      // with what today carried
      expect(written.context, state.buildTitle);
      expect(written.trace, isNotNull);
      // back in the nook it is the newest of the recent entries
      expect(find.byType(JournalEntryScreen), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('journal-nook-recent')),
          matching: find.text('One small win today:'),
        ),
        findsOneWidget,
      );
    });
  });

  group('recent entries', () {
    testWidgets('list the last two with their dates, newest first', (
      tester,
    ) async {
      await _pump(tester, GameState()..setJournal(_three()));
      final recent = find.byKey(const ValueKey('journal-nook-recent'));
      expect(find.text('RECENT ENTRIES'), findsOneWidget);
      expect(
        find.descendant(of: recent, matching: find.text('MON · OCT 5')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: recent, matching: find.text('SUN · OCT 4')),
        findsOneWidget,
      );
      // Two rows of 44 pt: the older pages are one tap away under ALL.
      expect(find.text('FRI · OCT 2'), findsNothing);
      expect(find.text('Long ago'), findsNothing);
      final ys = [
        for (final d in ['MON · OCT 5', 'SUN · OCT 4'])
          tester.getTopLeft(find.text(d)).dy,
      ];
      expect(ys[0], lessThan(ys[1]));
    });

    testWidgets('every touch target in the nook is at least 44 pt', (
      tester,
    ) async {
      final notes = _three();
      await _pump(tester, GameState()..setJournal(notes));
      for (final id in [
        'after-the-quest',
        'a-small-win',
        'set-it-down',
        'a-warm-detail',
      ]) {
        final r = tester.getRect(
          find.byKey(ValueKey('journal-nook-chip-hit-$id')),
        );
        expect(r.height, greaterThanOrEqualTo(44), reason: id);
        expect(r.width, greaterThanOrEqualTo(44), reason: id);
      }
      for (final key in [
        'journal-nook-write',
        'journal-nook-all',
        'journal-keepsakes-tag',
      ]) {
        final r = tester.getRect(find.byKey(ValueKey(key)));
        expect(
          r.height + (key == 'journal-keepsakes-tag' ? 16 : 0),
          greaterThanOrEqualTo(44),
          reason: key,
        );
      }
      for (final n in [notes[2], notes[1]]) {
        final r = tester.getRect(
          find.byKey(ValueKey('journal-nook-entry-${n.id}')),
        );
        expect(r.height, greaterThanOrEqualTo(44), reason: n.text);
      }
    });

    testWidgets('a row opens its page to read first', (tester) async {
      final notes = _three();
      await _pump(tester, GameState()..setJournal(notes));
      await tester.tap(
        find.byKey(ValueKey('journal-nook-entry-${notes[1].id}')),
      );
      await _settle(tester);
      final screen = _writer(tester);
      expect(screen.initial?.id, notes[1].id);
      expect(screen.initiallyEditing, isFalse);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('journal-entry-body')))
            .readOnly,
        isTrue,
      );
    });

    testWidgets('a photo page and a long first line read sensibly', (
      tester,
    ) async {
      expect(
        journalEntryTitle(Note(at: _today, text: '', images: const ['a.jpg'])),
        'Photo entry',
      );
      expect(
        journalEntryTitle(_note('\n  First line\nsecond', _today)),
        'First line',
      );
      expect(journalEntryTitle(_note('', _today)), 'A page kept');
    });

    testWidgets('ALL opens the Journal hub', (tester) async {
      await _pump(tester, GameState()..setJournal(_three()));
      await tester.tap(find.byKey(const ValueKey('journal-nook-all')));
      await _settle(tester);
      expect(find.byType(JournalHubScreen), findsOneWidget);
    });
  });

  group('the first page', () {
    testWidgets('shows "Your first page is ready" when there are no entries', (
      tester,
    ) async {
      await _pump(tester, GameState());
      expect(find.text('Your first page is ready'), findsOneWidget);
      expect(find.text('RECENT ENTRIES'), findsNothing);
      // the chips and the blank page are still right there
      expect(find.text('Write for today'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('journal-nook-chip-set-it-down')),
        findsOneWidget,
      );
    });

    testWidgets('and goes once there is one', (tester) async {
      final state = GameState();
      await _pump(tester, state);
      state.setJournal([_note('Hello', _today)]);
      await tester.pump();
      expect(find.text('Your first page is ready'), findsNothing);
      expect(find.text('RECENT ENTRIES'), findsOneWidget);
    });
  });

  group('Keepsakes', () {
    testWidgets('the label on the painted box opens the memory cabinet', (
      tester,
    ) async {
      await _pump(tester, GameState()..setJournal(_three()));
      await tester.tap(find.byKey(const ValueKey('journal-keepsakes-tag')));
      await _settle(tester);
      expect(find.byType(MemoryCabinetScreen), findsOneWidget);
    });

    testWidgets('it is a labelled button for VoiceOver', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, GameState()..setJournal(_three()));
      final data = tester
          .getSemantics(find.byKey(const ValueKey('journal-keepsakes-tag')))
          .getSemanticsData();
      expect(data.label, startsWith('Keepsakes'));
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });
  });

  group('the lenses and everything below the nook', () {
    testWidgets('ENTRIES, PATTERNS and CHRONICLE open their pages', (
      tester,
    ) async {
      await _pump(tester, _busy());
      await _reveal(tester, find.text('PATTERNS'));
      expect(find.text('ENTRIES'), findsOneWidget);
      expect(find.text('CHRONICLE'), findsOneWidget);

      await tester.tap(find.text('ENTRIES'));
      await _settle(tester);
      expect(find.byType(JournalHubScreen), findsOneWidget);
      _pop(tester);
      await _settle(tester);

      await tester.tap(find.text('PATTERNS'));
      await _settle(tester);
      expect(find.text('Patterns'), findsOneWidget);
      _pop(tester);
      await _settle(tester);

      await tester.tap(find.text('CHRONICLE'));
      await _settle(tester);
      expect(find.byType(WeeklyChronicleScreen), findsOneWidget);
    });

    testWidgets('Your Journal and Your Week cards are still there', (
      tester,
    ) async {
      await _pump(tester, _busy());
      await _reveal(tester, find.text('Your Week'));
      expect(find.text('Your Journal'), findsOneWidget);
      await tester.tap(find.text('Your Journal'));
      await _settle(tester);
      expect(find.byType(JournalHubScreen), findsOneWidget);
    });

    testWidgets('the weather, stats, rhythm, weeks and sky are kept', (
      tester,
    ) async {
      await _pump(tester, _busy());
      for (final label in [
        'Energy Weather',
        'YOUR STATS',
        'YOUR RHYTHM',
        'LAST TWO WEEKS',
        'YOUR SKY',
      ]) {
        await _reveal(tester, find.text(label));
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('with no history the page says where to start', (tester) async {
      await _pump(tester, GameState());
      await _reveal(tester, find.text('Start with today'));
      expect(find.text('Start with today'), findsOneWidget);
    });

    testWidgets('the count of what you have kept is quiet and exact', (
      tester,
    ) async {
      await _pump(tester, _busy());
      await _reveal(tester, find.text('4 ENTRIES'));
      expect(find.text('MORE FROM YOUR JOURNAL'), findsOneWidget);
    });
  });

  group('large text', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets('${(scale * 100).round()}%: no overflow, still reachable', (
        tester,
      ) async {
        final notes = _three();
        await _pump(tester, GameState()..setJournal(notes), textScale: scale);
        expect(tester.takeException(), isNull);
        // the page scrolls to the last row and the lenses
        await _reveal(
          tester,
          find.byKey(ValueKey('journal-nook-entry-${notes[1].id}')),
        );
        expect(tester.takeException(), isNull);
        await _reveal(tester, find.text('PATTERNS'));
        expect(tester.takeException(), isNull);
      });

      testWidgets('${(scale * 100).round()}%: the empty page fits too', (
        tester,
      ) async {
        await _pump(tester, GameState(), textScale: scale);
        expect(find.text('Your first page is ready'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    for (final scale in [1.3, 2.0]) {
      testWidgets('${(scale * 100).round()}%: every card below the nook fits', (
        tester,
      ) async {
        await _pump(tester, _busy(), textScale: scale);
        for (final label in [
          'PATTERNS',
          'Your Week',
          'Energy Weather',
          'YOUR STATS',
          'YOUR RHYTHM',
          'LAST TWO WEEKS',
          'YOUR SKY',
        ]) {
          await _reveal(tester, find.text(label));
          expect(tester.takeException(), isNull, reason: label);
        }
      });
    }

    testWidgets('Keepsakes rides above the card and still opens', (
      tester,
    ) async {
      await _pump(tester, GameState()..setJournal(_three()), textScale: 1.3);
      final tag = find.byKey(const ValueKey('journal-keepsakes-tag'));
      final card = find.byKey(const ValueKey('journal-nook-card'));
      expect(tester.getRect(tag).bottom, lessThan(tester.getRect(card).top));
      expect(tester.getRect(tag).right, lessThanOrEqualTo(393));
      await tester.tap(tag);
      await _settle(tester);
      expect(find.byType(MemoryCabinetScreen), findsOneWidget);
    });

    testWidgets('a chip stays tappable at 200%', (tester) async {
      await _pump(tester, GameState()..setJournal(_three()), textScale: 2);
      final chip = find.byKey(const ValueKey('journal-nook-chip-a-small-win'));
      await _reveal(tester, chip);
      await tester.tap(chip);
      await _settle(tester);
      expect(_writer(tester).heading, 'A small win');
    });
  });

  group('Reduce Motion, VoiceOver and the painted light', () {
    testWidgets('with Reduce Motion the nook settles at once', (tester) async {
      final state = GameState()
        ..reduceMotion = true
        ..setJournal(_three());
      await _pump(tester, state, disableAnimations: true);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('every control has a label a screen reader can speak', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final notes = _three();
      await _pump(tester, GameState()..setJournal(notes));
      for (final label in [
        'Write for today',
        'Start journal prompt: After the quest',
        'Start journal prompt: A small win',
        'Start journal prompt: Set it down',
        'Start journal prompt: A warm detail',
        'All journal entries',
        'Keepsakes',
        'Read journal entry from MON · OCT 5: After the quest',
        'Read journal entry from SUN · OCT 4: A small win',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      handle.dispose();
    });

    testWidgets('at night the nook is its painted evening, never a tint', (
      tester,
    ) async {
      Clock.freeze(DateTime(2026, 10, 6, 21));
      await _pump(tester, GameState()..setJournal(_three()));
      final plates = [
        for (final image in tester.widgetList<Image>(find.byType(Image)))
          if (image.image is AssetImage) (image.image as AssetImage).assetName,
      ].where((a) => a.contains('plate-')).toList();
      expect(plates, [HousePlateSets.journal.evening]);
      expect(find.byType(ColorFiltered), findsNothing);
    });

    test('the nook has its evening: midday by day, the lamp lit at night', () {
      expect(HousePlateSets.journal.hasEvening, isTrue);
      final noon = housePlateLayersAt(
        HousePlateSets.journal,
        DateTime(2026, 10, 6, 12),
      );
      expect(noon.map((l) => l.asset), [HousePlateSets.journal.midday]);
      final night = housePlateLayersAt(
        HousePlateSets.journal,
        DateTime(2026, 10, 6, 21),
      );
      expect(night.map((l) => l.asset), [HousePlateSets.journal.evening]);
    });
  });

  group('the prompts', () {
    test('are the four the nook shows, in order', () {
      expect(journalNookPrompts(GameState()).map((p) => p.label), [
        'After the quest',
        'A small win',
        'Set it down',
        'A warm detail',
      ]);
    });

    test('recent entries are the newest two', () {
      final state = GameState()..setJournal(_three());
      expect(recentJournalEntries(state).map((n) => n.text), [
        'After the quest',
        'A small win',
      ]);
    });

    test('no copy uses an em dash or a loss word', () {
      final copy = [
        for (final p in journalNookPrompts(GameState())) ...[
          p.label,
          p.hint,
          p.starter,
        ],
      ].join(' ');
      expect(copy, isNot(contains('—')));
      for (final word in ['failed', 'missed', 'lost', 'broke']) {
        expect(copy.toLowerCase(), isNot(contains(word)));
      }
    });
  });
}
