import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/memories.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/journal_hub.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const _questLabels = ['QUEST THREAD', 'UNLOAD', 'GRATEFUL', 'TOMORROW'];
const _quietLabels = ['SMALL WIN', 'UNLOAD', 'GRATEFUL', 'TOMORROW'];

GameState _state({required bool questToday}) {
  final s = GameState()..level = 6;
  s.lastActiveDay = Days.key(Clock.now());
  if (questToday) s.todayQuestTitles.add('Read ten pages of the lab manual');
  return s;
}

Future<void> _pumpHub(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  required bool questToday,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: JournalHubScreen(
        state: _state(questToday: questToday),
        quests: const [],
        onPersist: () {},
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    Sfx.instance.soundEnabled = false;
    Clock.freeze(DateTime(2026, 10, 6, 15, 35));
  });

  tearDown(() {
    Sfx.instance.soundEnabled = true;
    Clock.reset();
  });

  for (final (size, scale) in const [
    (Size(393, 852), 1.0),
    (Size(393, 852), 1.3),
    (Size(320, 568), 1.0),
    (Size(320, 568), 1.3),
  ]) {
    for (final questToday in const [true, false]) {
      testWidgets('every journal prompt chip reads in full at '
          '${size.width.toInt()} pt, ${(scale * 100).round()}% text '
          '(${questToday ? 'quest done today' : 'no quest yet'})', (
        tester,
      ) async {
        await _pumpHub(
          tester,
          size: size,
          textScale: scale,
          questToday: questToday,
        );

        // The hub list pads its content 16 pt from each screen edge.
        final contentLeft = 16.0 - 0.5;
        final contentRight = size.width - 16 + 0.5;
        for (final label in questToday ? _questLabels : _quietLabels) {
          final text = find.descendant(
            of: find.byKey(const ValueKey('journal-prompt-chips')),
            matching: find.text(label),
          );
          expect(text, findsOneWidget, reason: label);
          final rect = tester.getRect(text);
          expect(
            rect.left >= contentLeft && rect.right <= contentRight,
            isTrue,
            reason: '$label sits at $rect on a ${size.width} pt screen',
          );
          final paragraph = tester.renderObject<RenderParagraph>(text);
          expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('a prompt chip opens the editor with its starter line', (
    tester,
  ) async {
    await _pumpHub(
      tester,
      size: const Size(393, 852),
      textScale: 1,
      questToday: false,
    );
    await tester.tap(find.text('TOMORROW'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('Tomorrow’s first step:'), findsOneWidget);
  });

  testWidgets('Keepsakes counts read naturally at one', (tester) async {
    final state = _state(questToday: false); // level 6: one room milestone
    expect(memoryArtifactCount(state, const []), 1);
    await tester.pumpWidget(
      MaterialApp(
        home: JournalHubScreen(
          state: state,
          quests: const [],
          onPersist: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('1 artifact'), findsOneWidget);
    expect(find.textContaining('artifacts'), findsNothing);
    expect(find.textContaining('chosen by you'), findsNothing);

    final note = Note(at: DateTime(2026, 10, 5, 21), text: 'Kept this one.');
    state.setJournal([note]);
    state.memoryPins.add(note.id);
    await tester.pumpWidget(
      MaterialApp(
        home: JournalHubScreen(
          state: state,
          quests: const [],
          onPersist: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('2 artifacts · 1 moment chosen by you'), findsOneWidget);
  });
}
