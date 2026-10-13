// A Journal page is saved, whether or not it is in Keepsakes (2026-10-12).
//
// The reading view said "Keep this", which read as: a page you do not keep is
// not saved. Now the page's top line says it is saved ("saved · 3m ago"), the
// button only adds it to a shelf ("Add to Keepsakes", then "In Keepsakes", tap
// again to take it off), the page says where every page can be found again,
// and the writing view is left exactly as it was.
//
// Everything runs through the nook, the way a person reaches a page, with
// pages invented for the tests.
import 'dart:ui' show Tristate;

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/insights.dart';
import 'package:emberkeep/screens/journal_entry.dart';
import 'package:emberkeep/screens/journal_hub.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

final _now = DateTime(2026, 10, 12, 11, 42);

/// A page written three minutes ago, one yesterday, one edited since, and one
/// that is old enough to be off the nook's short list.
final _threeMinutes = Note(
  at: _now.subtract(const Duration(minutes: 3)),
  text: 'Walked home the long way and the light was good.',
  context: 'Homey Homesteader',
);
final _yesterday = Note(
  at: DateTime(2026, 10, 11, 21, 5),
  text: 'A short one tonight.',
);
final _edited = Note(
  at: DateTime(2026, 10, 9, 21, 5),
  text: 'Cooked for the first time in a while.',
  editedAt: DateTime(2026, 10, 9, 21, 20),
);
final _old = Note(
  at: DateTime(2026, 8, 20, 18, 30),
  text: 'The first week back.',
);

GameState _state([List<Note>? pages]) => GameState()
  ..reduceMotion = true
  ..setJournal(pages ?? [_old, _edited, _yesterday, _threeMinutes]);

Future<void> _pump(
  WidgetTester tester,
  GameState state, {
  double textScale = 1,
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          padding: const EdgeInsets.only(bottom: 34),
        ),
        child: child!,
      ),
      home: Material(
        type: MaterialType.transparency,
        child: InsightsPage(state: state, quests: const [], onPersist: () {}),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

/// Opens a page from the nook's recent list.
Future<void> _read(WidgetTester tester, Note note) async {
  await tester.tap(find.byKey(ValueKey('journal-nook-entry-${note.id}')));
  await _settle(tester);
}

/// Opens any page the way a person finds an old one: ALL, then the page.
Future<void> _readViaAll(WidgetTester tester, Note note) async {
  await tester.tap(find.byKey(const ValueKey('journal-nook-all')));
  await _settle(tester);
  final card = find.byKey(ValueKey('journal-card-${note.id}'));
  await tester.scrollUntilVisible(
    card,
    200,
    scrollable: find
        .descendant(
          of: find.byType(JournalHubScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(card);
  await tester.pump();
  await tester.tap(card);
  await _settle(tester);
}

Finder get _keep => find.byKey(const ValueKey('journal-entry-keepsake'));
Finder get _saved => find.byKey(const ValueKey('journal-entry-saved'));
Finder get _findAgain => find.byKey(const ValueKey('journal-entry-find-again'));

String _text(WidgetTester tester, Finder finder) =>
    tester.widget<Text>(finder).data!;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    Sfx.instance.soundEnabled = false;
    Clock.freeze(_now);
  });

  tearDown(() {
    Sfx.instance.soundEnabled = true;
    Clock.reset();
  });

  group('a page says it is saved', () {
    testWidgets('"saved · 3m ago" on the top line, before anything else', (
      tester,
    ) async {
      await _pump(tester, _state());
      await _read(tester, _threeMinutes);

      expect(_text(tester, _saved), 'saved · 3m ago');
      // The line is the first thing on the page, above what it was written as.
      expect(
        tester.getTopLeft(_saved).dy,
        lessThan(
          tester.getTopLeft(find.text('written as Homey Homesteader')).dy,
        ),
      );
      expect(find.text('written as Homey Homesteader'), findsOneWidget);
    });

    testWidgets('an older page says when it was written', (tester) async {
      await _pump(tester, _state());
      await _read(tester, _yesterday);
      expect(_text(tester, _saved), 'saved · yesterday');
    });

    testWidgets('an edited page says so, after the time', (tester) async {
      // Off the nook's short list: through ALL.
      await _pump(tester, _state());
      await _readViaAll(tester, _edited);
      expect(_text(tester, _saved), 'saved · 3 days ago · edited');
    });

    testWidgets('a page just written reads saved the moment it is finished', (
      tester,
    ) async {
      final state = _state();
      await _pump(tester, state);
      await tester.tap(find.byKey(const ValueKey('journal-nook-write')));
      await _settle(tester);

      // The writing view: no saved line of its own, its status chip as ever.
      expect(_saved, findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('journal-entry-body')),
        'A line about today.',
      );
      await tester.pump(const Duration(milliseconds: 750));
      await tester.tap(find.byKey(const ValueKey('journal-entry-done')));
      await tester.pump();

      expect(state.journal, hasLength(5));
      expect(_text(tester, _saved), 'saved · just now');
      expect(find.text('Add to Keepsakes'), findsOneWidget);
    });

    testWidgets('and it is true: the page is in the journal, kept or not', (
      tester,
    ) async {
      final state = _state();
      await _pump(tester, state);
      await _read(tester, _yesterday);

      expect(state.journal, contains(_yesterday));
      expect(state.memoryPins, isNot(contains(_yesterday.id)));
      expect(_text(tester, _saved), startsWith('saved'));
    });
  });

  group('the button only adds the page to Keepsakes', () {
    testWidgets('Add to Keepsakes, then In Keepsakes, then off again', (
      tester,
    ) async {
      final state = _state();
      await _pump(tester, state);
      await _read(tester, _yesterday);

      expect(find.text('Add to Keepsakes'), findsOneWidget);
      expect(find.text('Keep this'), findsNothing);
      expect(find.text('Kept in Keepsakes'), findsNothing);

      await tester.tap(_keep);
      await tester.pump();
      expect(find.text('In Keepsakes'), findsOneWidget);
      expect(state.memoryPins, contains(_yesterday.id));

      await tester.tap(_keep);
      await tester.pump();
      expect(find.text('Add to Keepsakes'), findsOneWidget);
      expect(state.memoryPins, isNot(contains(_yesterday.id)));
    });

    testWidgets('the page stays saved through every tap', (tester) async {
      final state = _state();
      await _pump(tester, state);
      await _read(tester, _yesterday);

      for (var i = 0; i < 3; i++) {
        await tester.tap(_keep);
        await tester.pump();
        expect(_text(tester, _saved), 'saved · yesterday');
        expect(state.journal, contains(_yesterday));
      }
    });

    testWidgets(
      'VoiceOver hears the same words, and that it is already saved',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, _state());
        await _read(tester, _yesterday);

        var node = tester.getSemantics(_keep);
        expect(node.label, 'Add to Keepsakes');
        expect(node.hint, contains('already saved'));
        expect(
          node.getSemanticsData().flagsCollection.isToggled,
          Tristate.isFalse,
        );

        await tester.tap(_keep);
        await tester.pump();
        node = tester.getSemantics(_keep);
        expect(node.label, 'In Keepsakes');
        expect(node.hint, contains('stays saved'));
        expect(
          node.getSemanticsData().flagsCollection.isToggled,
          Tristate.isTrue,
        );
        handle.dispose();
      },
    );

    testWidgets('it is a 48 pt target, beside EDIT', (tester) async {
      await _pump(tester, _state());
      await _read(tester, _yesterday);

      final keep = tester.getRect(_keep);
      expect(keep.height, greaterThanOrEqualTo(48));
      expect(keep.width, greaterThanOrEqualTo(110));
      final edit = tester.getRect(
        find.byKey(const ValueKey('journal-entry-edit')),
      );
      expect(keep.right, lessThanOrEqualTo(edit.left + 1));
      expect(keep.center.dy, closeTo(edit.center.dy, 8));
    });

    testWidgets('the hub\'s bookmark says it the same way', (tester) async {
      final handle = tester.ensureSemantics();
      final state = _state([_yesterday]);
      await tester.pumpWidget(
        MaterialApp(
          home: JournalHubScreen(
            state: state,
            quests: const [],
            onPersist: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.bySemanticsLabel('Add to Keepsakes'), findsOneWidget);
      expect(find.bySemanticsLabel('Keep in Keepsakes'), findsNothing);
      handle.dispose();
    });
  });

  group('every page can be found again', () {
    testWidgets('the page says where: under ALL on the Journal tab', (
      tester,
    ) async {
      await _pump(tester, _state());
      await _read(tester, _yesterday);

      expect(
        _text(tester, _findAgain),
        'You can always find it under ALL on the Journal tab.',
      );
    });

    testWidgets('and ALL is there on the nook, under that name', (
      tester,
    ) async {
      await _pump(tester, _state());
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('journal-nook-all')),
          matching: find.text('ALL'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a page too old for the nook is two taps away through ALL', (
      tester,
    ) async {
      final state = _state();
      await _pump(tester, state);
      // The nook's short list holds the newest; this one is not on it.
      expect(
        find.byKey(ValueKey('journal-nook-entry-${_old.id}')),
        findsNothing,
      );

      await _readViaAll(tester, _old);

      expect(find.byType(JournalEntryScreen), findsOneWidget);
      expect(find.text('The first week back.'), findsOneWidget);
      expect(_text(tester, _saved), 'saved · Aug 20');
    });

    testWidgets('a page of photos only is listed in ALL too', (tester) async {
      final photos = Note(
        at: DateTime(2026, 10, 1, 9),
        text: '',
        images: const ['a.jpg'],
      );
      final state = _state([_yesterday, photos]);
      await tester.pumpWidget(
        MaterialApp(
          home: JournalHubScreen(
            state: state,
            quests: const [],
            onPersist: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(ValueKey('journal-card-${photos.id}')), findsOneWidget);
      expect(
        find.byKey(ValueKey('journal-card-${_yesterday.id}')),
        findsOneWidget,
      );
    });
  });

  group('the writing view is as it was', () {
    testWidgets('Edit opens it with its own top line and no saved line', (
      tester,
    ) async {
      await _pump(tester, _state());
      await _read(tester, _threeMinutes);
      expect(_saved, findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('journal-entry-edit')));
      await tester.pump();

      // The old line, exactly as it was written, and the old status chip.
      expect(_saved, findsNothing);
      expect(_findAgain, findsNothing);
      expect(
        find.text('3m ago  ·  written as Homey Homesteader'),
        findsOneWidget,
      );
      expect(find.text('Saved locally'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('journal-photo-action')),
        findsOneWidget,
      );
      expect(_keep, findsNothing);
      expect(find.textContaining('Keepsakes'), findsNothing);
    });

    testWidgets('a new page is still "New entry" until it is written', (
      tester,
    ) async {
      await _pump(tester, _state());
      await tester.tap(find.byKey(const ValueKey('journal-nook-write')));
      await _settle(tester);

      expect(find.text('New entry'), findsOneWidget);
      expect(find.text('Saves automatically'), findsOneWidget);
      expect(_saved, findsNothing);
      expect(_keep, findsNothing);
    });
  });

  group('large text', () {
    for (final scale in const [1.3, 2.0]) {
      testWidgets('the button reads in full at ${(scale * 100).round()}%', (
        tester,
      ) async {
        await _pump(tester, _state(), textScale: scale);
        // At large text the nook's rows may sit low; go through ALL.
        await _readViaAll(tester, _yesterday);

        final label = tester.renderObject<RenderParagraph>(
          find.text('Add to Keepsakes'),
        );
        expect(label.didExceedMaxLines, isFalse);
        // Every letter is on the button: no ellipsis, whatever the lines.
        final box = tester.getRect(_keep);
        final words = tester.getRect(find.text('Add to Keepsakes'));
        expect(words.right, lessThanOrEqualTo(box.right));
        expect(words.left, greaterThanOrEqualTo(box.left));
        expect(tester.takeException(), isNull);
        expect(_saved, findsOneWidget);
      });
    }
  });

  group('the words', () {
    test('no em dash and no loss word in what a page says about itself', () {
      const copy = [
        'saved',
        'Add to Keepsakes',
        'In Keepsakes',
        'Puts this page on your Keepsakes shelf. It is already saved.',
        'Takes this page off your Keepsakes shelf. It stays saved.',
        'You can always find it under ALL on the Journal tab.',
      ];
      final all = copy.join(' ').toLowerCase();
      expect(all, isNot(contains('—')));
      for (final word in ['failed', 'missed', 'lost', 'broke']) {
        expect(all, isNot(contains(word)), reason: word);
      }
      // "Keep this" was the wording that read as unkept pages not being saved.
      expect(all, isNot(contains('keep this')));
    });
  });
}
