import 'dart:convert';

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/creature_skins.dart';
import 'package:emberkeep/content/room_styles.dart';
import 'package:emberkeep/content/space_themes.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/journal_doc.dart';
import 'package:emberkeep/main.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/goal_opening.dart';
import 'package:emberkeep/screens/shop.dart';
import 'package:emberkeep/social.dart';
import 'package:emberkeep/storage.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/glass_switch.dart';
import 'package:emberkeep/widgets/home_room.dart';
import 'package:emberkeep/widgets/pressable.dart';
import 'package:emberkeep/widgets/reward_receipt.dart';
import 'package:emberkeep/widgets/routine_flows.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpApp(
  WidgetTester tester, {
  String timeShape = 'FULL DAYS',
}) async {
  await tester.pumpWidget(const LifeRpgApp());
  // let the async save-load resolve
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  // fresh saves get the first-run welcome — walk it
  if (tester.any(find.text('ENTER ROOM OF DAYS'))) {
    await tester.tap(find.text('ENTER ROOM OF DAYS'));
    await settle(tester);
    await tester.tap(find.text('skip for now'));
    await settle(tester);
    // time-shape step (default FULL DAYS already selected)
    if (timeShape != 'FULL DAYS') {
      await tester.tap(find.text(timeShape));
      await settle(tester);
    }
    final cont = find.text('CONTINUE');
    await tester.ensureVisible(cont);
    await tester.pump();
    await tester.tap(cont);
    await settle(tester);
    await tester.tap(find.text('OPEN TODAY’S QUESTS'));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Settle a finite animation (route push, step switch): one frame to start
/// the ticker (epoch), then enough elapsed time to finish.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> returnQuestBoardToTop(WidgetTester tester) async {
  final board = tester.widget<NestedScrollView>(
    find.byKey(const ValueKey('quest-board-scroll')),
  );
  board.controller!.jumpTo(0);
  await tester.pump();
}

Future<void> revealQuest(WidgetTester tester, String title) async {
  final board = find.byKey(const ValueKey('quest-board-scroll'));
  for (
    var attempt = 0;
    attempt < 8 && !tester.any(find.text(title));
    attempt++
  ) {
    await tester.drag(board, const Offset(0, -260));
    await tester.pump(const Duration(milliseconds: 80));
  }
  expect(find.text(title), findsOneWidget);
  await tester.ensureVisible(find.text(title));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() {
    // no network in tests — fall back to system fonts silently
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('quests page renders header and quests', (tester) async {
    await pumpApp(tester);

    // The header carries LEVEL as a small caps label and the number as its own
    // display numeral, so they are two Texts rather than one string.
    expect(find.text('LEVEL'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('Do 2 push-ups'), findsOneWidget);
    expect(find.text('TODAY · 5 LEFT'), findsOneWidget);
  });

  for (final (shape, count) in const [
    ('LIGHT DAYS', 3),
    ('FULL DAYS', 5),
    ('PACKED DAYS', 7),
  ]) {
    testWidgets('$shape creates an honest $count-quest starter board', (
      tester,
    ) async {
      await pumpApp(tester, timeShape: shape);

      expect(find.text('TODAY · $count LEFT'), findsOneWidget);
    });
  }

  testWidgets('first-run Room Guide keeps the first Quest path available', (
    tester,
  ) async {
    await tester.pumpWidget(const LifeRpgApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('ENTER ROOM OF DAYS'));
    await settle(tester);
    await tester.tap(find.text('skip for now'));
    await settle(tester);
    await tester.tap(find.text('CONTINUE'));
    await settle(tester);
    expect(find.text('OPEN TODAY’S QUESTS'), findsOneWidget);

    await tester.tap(find.text('open the room guide'));
    await settle(tester);

    expect(find.text('Room Guide'), findsOneWidget);
    expect(find.text('Help for Today'), findsOneWidget);
    expect(find.textContaining('messy room'), findsOneWidget);
  });

  testWidgets('completing a quest marks it done and grants XP', (tester) async {
    await pumpApp(tester);

    await revealQuest(tester, 'Walk 10 minutes');
    await tester.tap(find.text('Walk 10 minutes'));
    await tester.pump(const Duration(milliseconds: 100));
    await returnQuestBoardToTop(tester);

    expect(find.text('TODAY · 4 LEFT'), findsOneWidget);

    // let receipt/particle timers and bar fill finish so no timers leak
    // (pumpAndSettle would never settle: ambient animations repeat forever)
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 3));
    // The optional Journal door keeps the receipt readable a little longer;
    // let the achievement queue behind it release its final toast timer too.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('compact reward receipt keeps an optional one-line reflection', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    String? kept;
    var done = false;
    final bundle = RewardBundle(
      xp: 12,
      stat: Stat.intl,
      statGain: 2,
      questTitle: 'Read ten pages',
      message: 'You made returning easier.',
      difficulty: 2,
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          body: Stack(
            children: [
              RewardReceipt(
                bundle: bundle,
                anchor: const Offset(160, 280),
                onReflect: (value) => kept = value,
                onDone: () => done = true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);

    await tester.tap(find.textContaining('KEEP ONE LINE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ONE LINE, IF YOU WANT'), findsOneWidget);
    expect(find.text('Read ten pages'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byType(TextField),
      'Leaving the book open made starting easy.',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('KEEP IN JOURNAL'));
    await tester.pump();
    await tester.tap(find.text('KEEP IN JOURNAL'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(kept, 'Leaving the book open made starting easy.');
    expect(find.text('ONE LINE KEPT IN JOURNAL'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 6));
    expect(done, isTrue);
  });

  testWidgets('pressable acknowledges an accepted tap after release', (
    tester,
  ) async {
    final events = <String>[];
    final sfx = Sfx.instance;
    sfx.debugResetForTesting();
    sfx.debugBypassPlayback = true;
    sfx.debugOnPlay = events.add;
    addTearDown(sfx.debugResetForTesting);
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Pressable(
              pressDepth: 3,
              onTapUp: (_) => tapped = true,
              child: const SizedBox(
                key: ValueKey('instant-touch-target'),
                width: 120,
                height: 52,
              ),
            ),
          ),
        ),
      ),
    );
    final target = find.byKey(const ValueKey('instant-touch-target'));
    final before = tester.getTopLeft(target).dy;
    final gesture = await tester.startGesture(tester.getCenter(target));
    await tester.pump();

    expect(tester.getTopLeft(target).dy, before + 3);
    expect(tapped, isFalse);
    expect(events, isEmpty);

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.getTopLeft(target).dy, before);
    expect(tapped, isTrue);
    expect(events, ['open']);
  });

  testWidgets('pressable keeps the bob for movement Flutter still accepts', (
    tester,
  ) async {
    final events = <String>[];
    final sfx = Sfx.instance;
    sfx.debugResetForTesting();
    sfx.debugBypassPlayback = true;
    sfx.debugOnPlay = events.add;
    addTearDown(sfx.debugResetForTesting);
    var activations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Pressable(
              pressDepth: 3,
              onTapUp: (_) => activations++,
              child: const SizedBox(
                key: ValueKey('tap-slop-target'),
                width: 120,
                height: 52,
              ),
            ),
          ),
        ),
      ),
    );

    final target = find.byKey(const ValueKey('tap-slop-target'));
    final pressLayer = find
        .descendant(
          of: find.byType(Pressable),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    double pressOffset() =>
        tester.widget<AnimatedContainer>(pressLayer).transform!.storage[13];

    final gesture = await tester.startGesture(tester.getCenter(target));
    await tester.pump();
    await gesture.moveBy(const Offset(8, 0));
    await tester.pump();
    expect(pressOffset(), 3);
    expect(events, isEmpty);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 180));
    expect(pressOffset(), 0);
    expect(activations, 1);
    expect(events, ['open']);
  });

  testWidgets('pressable cancels without sound when a bob becomes a scroll', (
    tester,
  ) async {
    final events = <String>[];
    final sfx = Sfx.instance;
    sfx.debugResetForTesting();
    sfx.debugBypassPlayback = true;
    sfx.debugOnPlay = events.add;
    addTearDown(sfx.debugResetForTesting);

    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var activations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: scroll,
            children: [
              const SizedBox(height: 80),
              Center(
                child: Pressable(
                  pressDepth: 3,
                  onTapUp: (_) => activations++,
                  child: const SizedBox(
                    key: ValueKey('scroll-touch-target'),
                    width: 120,
                    height: 52,
                  ),
                ),
              ),
              const SizedBox(height: 900),
            ],
          ),
        ),
      ),
    );

    final target = find.byKey(const ValueKey('scroll-touch-target'));
    final pressLayer = find
        .descendant(
          of: find.byType(Pressable),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    double pressOffset() =>
        tester.widget<AnimatedContainer>(pressLayer).transform!.storage[13];

    final gesture = await tester.startGesture(tester.getCenter(target));
    await tester.pump();
    expect(pressOffset(), 3);
    expect(events, isEmpty);

    await gesture.moveBy(const Offset(0, -50));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump(const Duration(milliseconds: 180));
    expect(pressOffset(), 0);
    expect(scroll.offset, greaterThan(0));
    expect(activations, 0);
    expect(events, isEmpty);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 180));
    expect(activations, 0);
    expect(events, isEmpty);
  });

  testWidgets('pressable pointer cancellation emits neither action nor sound', (
    tester,
  ) async {
    final events = <String>[];
    final sfx = Sfx.instance;
    sfx.debugResetForTesting();
    sfx.debugBypassPlayback = true;
    sfx.debugOnPlay = events.add;
    addTearDown(sfx.debugResetForTesting);
    var activations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Pressable(
              onTapUp: (_) => activations++,
              child: const SizedBox(
                key: ValueKey('cancelled-touch-target'),
                width: 120,
                height: 52,
              ),
            ),
          ),
        ),
      ),
    );

    final target = find.byKey(const ValueKey('cancelled-touch-target'));
    final gesture = await tester.startGesture(tester.getCenter(target));
    await tester.pump();
    expect(events, isEmpty);
    await gesture.cancel();
    await tester.pump();

    expect(activations, 0);
    expect(events, isEmpty);
  });

  testWidgets('pressable with no tap action never emits a sound', (
    tester,
  ) async {
    final events = <String>[];
    final sfx = Sfx.instance;
    sfx.debugResetForTesting();
    sfx.debugBypassPlayback = true;
    sfx.debugOnPlay = events.add;
    addTearDown(sfx.debugResetForTesting);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Pressable(
              child: const SizedBox(
                key: ValueKey('no-op-touch-target'),
                width: 120,
                height: 52,
              ),
            ),
          ),
        ),
      ),
    );

    final target = find.byKey(const ValueKey('no-op-touch-target'));
    final gesture = await tester.startGesture(tester.getCenter(target));
    await gesture.up();
    await tester.pump();

    expect(events, isEmpty);
  });

  testWidgets(
    'pressable semantic activation still completes without a pointer',
    (tester) async {
      final events = <String>[];
      final sfx = Sfx.instance;
      sfx.debugResetForTesting();
      sfx.debugBypassPlayback = true;
      sfx.debugOnPlay = events.add;
      addTearDown(sfx.debugResetForTesting);
      var activations = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Pressable(
              semanticLabel: 'Keyboard quest',
              onTapUp: (_) => activations++,
              child: const SizedBox(width: 120, height: 52),
            ),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(activations, 1);
      expect(events, ['open']);
    },
  );

  testWidgets('first trophy waits until the reward receipt clears', (
    tester,
  ) async {
    await pumpApp(tester);

    await revealQuest(tester, 'Walk 10 minutes');
    await tester.tap(find.text('Walk 10 minutes'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('First Step'), findsNothing);

    // The luxury receipt stays readable longer before trophy chrome is allowed
    // to arrive on top of it.
    // The receipt lifetime is followed by one stagger for every earned chip;
    // leave the full rail readable before the queued trophy's 200 ms entrance.
    await tester.pump(const Duration(milliseconds: 4300));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('First Step'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('undo restores a quest completed by accident', (tester) async {
    await pumpApp(tester);
    expect(find.text('TODAY · 5 LEFT'), findsOneWidget);

    await revealQuest(tester, 'Walk 10 minutes');
    await tester.tap(find.text('Walk 10 minutes'));
    await tester.pump(const Duration(milliseconds: 100));
    await returnQuestBoardToTop(tester);
    expect(find.text('TODAY · 4 LEFT'), findsOneWidget);

    // wait for the deferred commit, which arms swipe-to-undo on the card
    await tester.pump(const Duration(milliseconds: 1400));

    // swipe the finished card left to undo (the undo snackbar was removed).
    // Drive it as an explicit gesture — tester.drag doesn't reliably trip a
    // Dismissible's dismiss threshold.
    // Scroll it back into the built range first: returnQuestBoardToTop above
    // jumped to 0, and off-viewport list items are not in the tree for
    // find.byKey (ensureVisible is too late — the find has already failed).
    await revealQuest(tester, 'Walk 10 minutes');
    final card = find.byKey(const ValueKey('undo-Walk 10 minutes'));
    expect(card, findsOneWidget);
    await tester.ensureVisible(card);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.fling(card, const Offset(-500, 0), 1500);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    // the quest is back on the board, the completion reverted
    await returnQuestBoardToTop(tester);
    expect(find.text('TODAY · 5 LEFT'), findsOneWidget);

    // settle remaining timers
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets(
    'rapid double-complete then undo keeps the first quest\'s reward',
    (tester) async {
      // a tall surface so the full board (+ the Ember-of-the-Day card) fits and
      // both quests + the undo card stay built (no lazy-list scroll fragility)
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpApp(tester);
      expect(find.text('TODAY · 5 LEFT'), findsOneWidget);

      // complete A, then complete B before A's deferred commit fires (~1s)
      await tester.tap(find.text('Walk 10 minutes'));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.text('Read one page'));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('TODAY · 3 LEFT'), findsOneWidget);

      // wait for B's commit (arms swipe-to-undo on B's card), then undo B
      await tester.pump(const Duration(milliseconds: 1400));
      final cardB = find.byKey(const ValueKey('undo-Read one page'));
      expect(cardB, findsOneWidget);
      await tester.ensureVisible(cardB);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.fling(cardB, const Offset(-500, 0), 1500);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // B reverted (back to 8), and A's reward was NOT destroyed
      expect(find.byKey(const ValueKey('card-Read one page')), findsOneWidget);
      expect(find.byKey(const ValueKey('undo-Read one page')), findsNothing);
      final saved = (await Storage.load())!;
      expect(
        saved.$1.totalXp,
        greaterThan(0),
        reason: 'quest A\'s XP must survive undoing quest B',
      );
      expect(
        saved.$2.singleWhere((q) => q.title == 'Read one page').lastDoneDay,
        isNull,
      );

      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets('nav dock switches to Me, Plans and Journal', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    // the Me page is a lazy ListView; the readability pass made the header
    // taller, so scroll the Me scrollable until each marker is built rather
    // than assuming a fixed position above the fold.
    final meList = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('YOUR BUILD'),
      120,
      scrollable: meList,
    );
    expect(find.text('YOUR BUILD'), findsOneWidget);

    // trophy case sits further down the lazy list
    await tester.scrollUntilVisible(
      find.text('TROPHY CASE'),
      200,
      scrollable: meList,
    );
    expect(find.text('TROPHY CASE'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('PLANS'), findsWidgets);

    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('JOURNAL'), findsWidgets);
  });

  testWidgets('the full Me rail opens the complete-room chooser', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
    await tester.pump(const Duration(milliseconds: 500));

    // Preview toolbars can sit over the far-right edge on a phone. The whole
    // The whole Glimmers rail remains a real target when phone chrome crowds
    // the trailing button.
    await tester.tap(find.text('0 GLIMMERS'));
    await settle(tester);
    expect(find.text('Change your space'), findsOneWidget);
    expect(
      find.text('three finished rooms, each ready to live in'),
      findsOneWidget,
    );
  });

  testWidgets(
    'complete-room preview and purchase fit a small large-text phone',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
      });
      Sfx.instance.soundEnabled = false;
      addTearDown(() => Sfx.instance.soundEnabled = true);

      final state = GameState()
        ..embers = 500
        ..reduceMotion = true;
      var persists = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.3),
            ),
            child: ShopScreen(state: state, onPersist: () => persists++),
          ),
        ),
      );
      await tester.runAsync(() => preloadSpaceTheme('wall_conservatory'));
      await tester.pump(const Duration(milliseconds: 300));

      final list = find.byKey(const ValueKey('space-theme-list'));
      final conservatory = find.text('The Living Conservatory');
      for (
        var attempt = 0;
        attempt < 8 && !tester.any(conservatory);
        attempt++
      ) {
        await tester.drag(list, const Offset(0, -260));
        await tester.pump(const Duration(milliseconds: 80));
      }
      expect(conservatory, findsOneWidget);
      await tester.ensureVisible(conservatory);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(conservatory);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('STEP INSIDE'), findsOneWidget);
      expect(find.text('MAKE IT MINE · 280 GLIMMERS'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('MAKE IT MINE · 280 GLIMMERS'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(state.wallStyle, 'wall_conservatory');
      expect(state.questDeskStyle, 'wall_conservatory');
      expect(state.ownedStyles, contains('wall_conservatory'));
      expect(state.embers, 220);
      expect(persists, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Journal Patterns is a working lens, not decorative chrome', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('PATTERNS'));
    await settle(tester);

    expect(find.text('Patterns'), findsOneWidget);
    expect(
      find.text('what your own days are actually showing'),
      findsOneWidget,
    );
  });

  testWidgets('room milestone chips explain their unlock progress', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
    await tester.pump(const Duration(milliseconds: 500));

    // The seal carries the milestone's NAME whether or not it is earned; the
    // padlock carries its state and the sheet behind it carries the numbers.
    final milestone = find.text('FIRST FIVE');
    await tester.ensureVisible(milestone);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(milestone);
    await settle(tester);

    // the seal itself plus the opened sheet's title
    expect(find.text('FIRST FIVE'), findsNWidgets(2));
    expect(find.text('LEVEL 1 / 5 · 4 LEVELS TO GO'), findsOneWidget);
    expect(
      find.text('Complete quests, earn XP, and reach level 5.'),
      findsOneWidget,
    );
  });

  testWidgets('sound & reduce-motion toggles repaint the switch when tapped', (
    tester,
  ) async {
    // Regression: the handlers mutated state.soundEnabled / state.reduceMotion
    // directly (no notifyListeners) while the switch reads its value through a
    // ListenableBuilder — so the thumb never moved and the toggles felt dead
    // (worse once reminders were on and the panel had already repainted).
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
    await tester.pump(const Duration(milliseconds: 500));

    final meList = find.byType(Scrollable).first;
    // NB: this must track me.dart's section heading exactly — it was renamed
    // to add the text-size control, and a stale string here makes the scroll
    // run off the end of the lazy list and fail with an opaque "No element".
    await tester.scrollUntilVisible(
      find.text('SOUND · MOTION · TEXT'),
      160,
      scrollable: meList,
    );

    Finder switchFor(String label) => find.byWidgetPredicate(
      (w) => w is GlassSwitch && w.semanticLabel == label,
    );
    bool valueOf(String label) =>
        (tester.widget(switchFor(label)) as GlassSwitch).value;

    final sound0 = valueOf('Sound effects');
    await tester.ensureVisible(switchFor('Sound effects'));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(switchFor('Sound effects'));
    await settle(tester);
    expect(
      valueOf('Sound effects'),
      !sound0,
      reason: 'the sound switch must reflect the new value on screen',
    );

    final motion0 = valueOf('Reduce motion');
    await tester.ensureVisible(switchFor('Reduce motion'));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(switchFor('Reduce motion'));
    await settle(tester);
    expect(
      valueOf('Reduce motion'),
      !motion0,
      reason: 'the reduce-motion switch must reflect the new value',
    );
  });

  testWidgets('goals page can take on a quest', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('GOALS'), findsWidgets);

    // The real goals stay quiet until the person deliberately asks for
    // starting points; the catalog is no longer mixed into the main page.
    expect(find.text('Keep your space'), findsNothing);
    await tester.tap(find.byKey(const Key('goals-browse-starting-points')));
    await settle(tester);
    expect(find.text('STARTING POINTS'), findsOneWidget);

    // expand the first catalog goal (HOME & HEARTH → "Keep your space", near
    // the top) and adopt its first quest. The new cinematic goal header makes
    // the catalog genuinely lazy at this viewport, so reveal it by scrolling.
    await tester.scrollUntilVisible(
      find.text('Keep your space'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Keep your space'));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 150));
    final takeOn = find.text('TAKE ON').first;
    await tester.ensureVisible(takeOn);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(takeOn);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('TAKEN · EDIT'), findsOneWidget);

    // settle the snackbar timer
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('goal wizard: name, add a quest via the sheet, begin', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('goals-create-first')));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('quick-goal-advanced')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('quick-goal-advanced')));
    await settle(tester);
    expect(find.text('A NEW GOAL'), findsOneWidget);

    // Name the goal (the only TextField until the sheet opens).
    await tester.enterText(
      find.byType(TextField).first,
      'Maintain healthy skin',
    );
    await tester.pump(const Duration(milliseconds: 100));

    // add a path-quest through the shared Ember Sheet. The milestone chip row
    // made the wizard taller, so build the lazy list down to the button first.
    await tester.scrollUntilVisible(
      find.text('Add a quest'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Add a quest'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Add a quest'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('NEW QUEST'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('ember-title')),
      'Morning skincare',
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.ensureVisible(find.text('Add →'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Add →'));
    await tester.pump(); // pop + add to the trail
    await tester.pump(const Duration(milliseconds: 500)); // sheet slides away
    await tester.pump(const Duration(milliseconds: 100));

    // Draft the route from the pinned footer button. The workshop, not this
    // authoring form, owns the first Quest acceptance.
    await tester.tap(find.text('DRAFT THIS ROUTE'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ROUTE DRAFTED'), findsOneWidget);
    // The confirmation holds ~1.4s, then enters the one-time opening.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Maintain healthy skin'), findsWidgets);
    expect(find.byType(GoalOpeningScreen), findsOneWidget);
  });

  testWidgets('night routine opens, recaps and closes', (tester) async {
    await pumpApp(tester);

    // The board's four toolbar marks share one outline weight now; the moon
    // was the only solid glyph in the row.
    await tester.tap(find.byIcon(Icons.nightlight_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Close the ledger'), findsOneWidget);
    expect(find.text('WHAT MOVED'), findsOneWidget);

    // The quiet exit sits below the physical ledger on short test phones.
    // Scroll the routine stage until the link can receive the tap.
    final recapScroll = find.byKey(const ValueKey('recap')).hitTestable();
    var closeDay = find.text('CLOSE THE DAY').hitTestable();
    for (var i = 0; i < 5 && closeDay.evaluate().isEmpty; i++) {
      await tester.drag(recapScroll, const Offset(0, -200));
      await tester.pump();
      closeDay = find.text('CLOSE THE DAY').hitTestable();
    }
    await tester.pump(const Duration(milliseconds: 100));
    expect(closeDay, findsOneWidget);
    await tester.tap(closeDay);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Close the ledger'), findsNothing);

    // flush the Rest Earned achievement toast timers
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('night ledger can keep a day-attached line without closing', (
    tester,
  ) async {
    final now = DateTime(2026, 8, 1, 22, 15);
    Clock.freeze(now);
    addTearDown(Clock.reset);
    final state = GameState()..reduceMotion = true;
    state.todayQuestTitles.add('Read ten pages');
    final quests = [
      Quest(title: 'Read ten pages', stat: Stat.intl, difficulty: 2),
    ];
    var persisted = 0;
    var closed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: NightFlow(
          state: state,
          quests: quests,
          onAdd: (_) => true,
          onPersist: () => persisted++,
          onClose: () => closed = true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final recapScroll = find.descendant(
      of: find.byKey(const ValueKey('recap')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('reflect · optional'),
      200,
      scrollable: recapScroll,
    );
    await tester.tap(find.text('reflect · optional'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
      find.byKey(const Key('night-reflection-field')),
      'Reading before bed made the evening feel complete.',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('KEEP TONIGHT’S PAGE'));
    await tester.pump();
    await tester.tap(find.text('KEEP TONIGHT’S PAGE'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(closed, isFalse);
    expect(persisted, 1);
    expect(state.journal, hasLength(1));
    expect(
      state.journal.single.night?.reflection,
      'Reading before bed made the evening feel complete.',
    );
    expect(state.journal.single.trace?.questTitles, contains('Read ten pages'));
    expect(find.text('edit tonight’s page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('importRaw rejects garbage but accepts a real backup', () async {
    SharedPreferences.setMockInitialValues({});

    // garbage and structurally-valid-but-foreign JSON must NOT overwrite
    expect(await Storage.importRaw('not json at all'), isFalse);
    expect(await Storage.importRaw('{}'), isFalse);
    expect(await Storage.importRaw('{"state":{},"quests":[]}'), isFalse);
    expect(await Storage.importRaw('{"app":"something-else"}'), isFalse);

    // a genuine exported save round-trips
    final state = GameState()
      ..playerName = 'Mika'
      ..level = 4
      ..totalXp = 320;
    await Storage.save(state, [
      Quest(title: 'Read', stat: Stat.intl, difficulty: 3),
    ]);
    final backup = await Storage.exportRaw();
    expect(backup, isNotNull);
    expect(await Storage.importRaw(backup!), isTrue);

    final loaded = await Storage.load();
    expect(loaded, isNotNull);
    expect(loaded!.$1.playerName, 'Mika');
    expect(loaded.$1.level, 4);
    expect(loaded.$2.first.title, 'Read');
  });

  test(
    'importRaw keeps the current save when a backup needs a newer build',
    () async {
      final current = GameState()
        ..playerName = 'Mika'
        ..level = 4;
      expect(await Storage.save(current, const []), isTrue);
      final before = await Storage.exportRaw();
      expect(before, isNotNull);

      final futureBackup = jsonEncode({
        'app': 'emberkeep',
        'schema': Storage.schema + 1,
        'state':
            (GameState()
                  ..playerName = 'From the future'
                  ..level = 99)
                .toJson(),
        'quests': const <Object>[],
      });

      expect(await Storage.importRaw(futureBackup), isFalse);
      expect(await Storage.exportRaw(), before);
      expect((await Storage.load())!.$1.playerName, 'Mika');
    },
  );

  test('isValidSave gates what may be mirrored to the cloud', () async {
    SharedPreferences.setMockInitialValues({});
    // corrupt / foreign / empty must NOT be considered mirror-able
    expect(Storage.isValidSave('{ truncated'), isFalse);
    expect(Storage.isValidSave('{}'), isFalse);
    expect(Storage.isValidSave('{"state":{},"quests":[]}'), isFalse);
    expect(
      Storage.isValidSave('{"app":"other","state":{"stats":[]}}'),
      isFalse,
    );

    // a genuine save passes
    await Storage.save(GameState()..playerName = 'Mika', const []);
    final raw = await Storage.exportRaw();
    expect(Storage.isValidSave(raw!), isTrue);
  });

  test('a corrupt save is quarantined, the first copy is preserved', () async {
    SharedPreferences.setMockInitialValues({
      'liferpg_save_v1': '{ this is not valid json',
    });
    // load fails → quarantines, returns null (fresh start)
    expect(await Storage.load(), isNull);
    final quarantined = await Storage.corruptBackup();
    expect(quarantined, '{ this is not valid json');

    // a SECOND corruption must not clobber the first (better) quarantine
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('liferpg_save_v1', '{ different garbage');
    expect(await Storage.load(), isNull);
    expect(await Storage.corruptBackup(), '{ this is not valid json');
  });

  testWidgets('quick-add puts a one-time quest on today', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('NEW QUEST'), findsOneWidget);

    // the Ember Sheet: name it, pick "Just today", tap Add (keyboard "done"
    // no longer auto-creates).
    await tester.enterText(
      find.byKey(const Key('ember-title')),
      'Do the laundry',
    );
    await tester.pump(const Duration(milliseconds: 100));
    // "Just today" is the last chip in a horizontal scroll — bring it on-screen
    await tester.ensureVisible(find.text('Just today'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Just today'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.ensureVisible(find.text('Add to today →'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Add to today →'));
    await tester.pump(); // pop + onAdd
    await tester.pump(const Duration(milliseconds: 500)); // sheet slides away
    await tester.pump(const Duration(milliseconds: 100)); // route removed

    expect(find.text('TODAY · 6 LEFT'), findsOneWidget);
    expect(find.text('Do the laundry'), findsOneWidget);
    expect(find.text('DUE TODAY'), findsOneWidget);
  });

  testWidgets('plans page can add an event for today', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.scrollUntilVisible(
      find.text('+ PLAN'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.text('+ PLAN'));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField), 'Finish the essay draft');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('PLAN IT'));
    await tester.pump(const Duration(milliseconds: 400));

    // due today → leads the quest list
    await tester.tap(find.byIcon(Icons.task_alt));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('TODAY · 6 LEFT'), findsOneWidget);
    expect(find.text('Finish the essay draft'), findsOneWidget);
    expect(find.text('DUE TODAY'), findsOneWidget);
  });

  test(
    'embers: earned on completion, then spent in the shop with a gate',
    () async {
      final state = GameState();
      expect(state.embers, 0);
      expect(state.ownedFurniture, isEmpty);

      // earning: a completion adds embers alongside XP (~a third, min 1)
      final bundle = state.roll(
        Quest(title: 'Read', stat: Stat.intl, difficulty: 3),
      );
      state.commit(bundle);
      expect(state.embers, bundle.xp ~/ 3 < 1 ? 1 : bundle.xp ~/ 3);
      expect(state.embers, greaterThan(0));

      // spending: too poor → no buy; topped up → buys once, deducts, owns it
      state.embers = 30;
      expect(state.buyFurniture('rug', 40), isFalse); // can't afford
      expect(state.ownedFurniture, isEmpty);
      state.embers = 100;
      expect(state.buyFurniture('rug', 40), isTrue);
      expect(state.embers, 60);
      expect(state.ownedFurniture, contains('rug'));
      expect(state.buyFurniture('rug', 40), isFalse); // owned → no recharge
      expect(state.embers, 60);

      // gating: an achievement-locked piece stays unbuyable until allowed,
      // even with the embers in hand
      state.embers = 1000;
      expect(state.buyFurniture('hearth', 600, allowed: false), isFalse);
      expect(state.ownedFurniture, isNot(contains('hearth')));
      expect(state.buyFurniture('hearth', 600, allowed: true), isTrue);
      expect(state.ownedFurniture, contains('hearth'));
    },
  );

  test('embers and owned furniture survive a save/load round-trip', () async {
    SharedPreferences.setMockInitialValues({});
    final state = GameState()
      ..embers = 175
      ..playerName = 'Mika';
    state.ownedFurniture.addAll(['rug', 'lamp', 'plant']);
    await Storage.save(state, const []);

    final loaded = await Storage.load();
    expect(loaded, isNotNull);
    expect(loaded!.$1.embers, 175);
    expect(loaded.$1.ownedFurniture, containsAll(['rug', 'lamp', 'plant']));
  });

  test('journal: free entries persist alongside attached notes', () async {
    SharedPreferences.setMockInitialValues({});
    final state = GameState()..playerName = 'Mika';
    state.setJournal(
      state.journal
          .withNote('first thought', DateTime(2026, 6, 28))
          .withNote('second thought', DateTime(2026, 6, 29)),
    );
    expect(state.journal.length, 2);
    // a domain note coexists — the hub aggregates both
    state.setDomainNotes(Stat.vit, [
      Note(at: DateTime(2026, 6, 27), text: 'ran a 5k'),
    ]);

    await Storage.save(state, const []);
    final loaded = await Storage.load();
    expect(loaded, isNotNull);
    expect(
      loaded!.$1.journal.map((n) => n.text),
      containsAll(['first thought', 'second thought']),
    );
    expect(loaded.$1.notesFor(Stat.vit).first.text, 'ran a 5k');

    // deleting a free entry sticks
    loaded.$1.setJournal(loaded.$1.journal.without(loaded.$1.journal.first));
    expect(loaded.$1.journal.length, 1);
    expect(loaded.$1.journal.first.text, 'second thought');
  });

  test(
    'journal: an entry is editable in place (by id) and survives reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final state = GameState()..playerName = 'Mika';
      final original = Note(
        at: DateTime(2026, 6, 28),
        text: 'rough first draft',
        context: 'Frail',
      );
      state.setJournal([original]);

      // edit it — same identity, body changes, original timestamp + context kept
      final revised = original.copyWith(
        text: 'a fuller, edited reflection',
        editedAt: DateTime(2026, 6, 30),
      );
      state.setJournal(state.journal.replacing(revised));
      expect(
        state.journal.length,
        1,
        reason: 'edit replaces, never duplicates',
      );
      expect(state.journal.first.id, original.id, reason: 'identity is stable');
      expect(state.journal.first.text, 'a fuller, edited reflection');
      expect(state.journal.first.at, DateTime(2026, 6, 28));
      expect(state.journal.first.context, 'Frail');
      expect(state.journal.first.editedAt, isNotNull);

      // the edit (and the edited marker) round-trips through a save/load
      await Storage.save(state, const []);
      final loaded = await Storage.load();
      final back = loaded!.$1.journal.single;
      expect(back.text, 'a fuller, edited reflection');
      expect(back.id, original.id);
      expect(back.editedAt, DateTime(2026, 6, 30));
    },
  );

  test('journal: a rich entry (text + inline photos) round-trips', () async {
    SharedPreferences.setMockInitialValues({});
    // a page with a paragraph, a photo, then another paragraph
    final doc = [
      const JournalBlock.text('Morning walk by the river.'),
      const JournalBlock.image('jimg_1.jpg'),
      const JournalBlock.text('The light was unreal.'),
    ];
    expect(JournalDoc.images(doc), ['jimg_1.jpg']);
    expect(
      JournalDoc.plainText(doc),
      'Morning walk by the river.\n\nThe light was unreal.',
    );

    final state = GameState()..playerName = 'Mika';
    state.setJournal([
      Note(
        at: DateTime(2026, 6, 30),
        text: JournalDoc.plainText(doc),
        rich: JournalDoc.encode(doc),
        images: JournalDoc.images(doc),
      ),
    ]);

    await Storage.save(state, const []);
    final back = (await Storage.load())!.$1.journal.single;
    // text (for the feed) + the photo list + the structured doc all survive
    expect(back.text, contains('Morning walk'));
    expect(back.images, ['jimg_1.jpg']);
    final blocks = JournalDoc.decode(back.rich);
    expect(blocks.length, 3);
    expect(blocks[1].isImage, isTrue);
    expect(blocks[1].image, 'jimg_1.jpg');
    expect(blocks[2].text, 'The light was unreal.');

    // decode never throws on garbage — restore resilience
    expect(JournalDoc.decode('not json'), isEmpty);
    expect(JournalDoc.decode(null), isEmpty);
  });

  test(
    'journal: automatic day context survives save, edit, and migration',
    () async {
      SharedPreferences.setMockInitialValues({});
      final trace = JournalTrace(
        day: '2026-07-31',
        level: 8,
        totalXp: 1420,
        todayXp: 84,
        streakDays: 6,
        questTitles: const ['Walk after lunch', 'Clear the counter'],
        goalTitles: const ['Build a walking habit'],
        statGains: const {Stat.vit: 3, Stat.dis: 2},
        energy: EnergyWeather.steady,
      );
      final original = Note(
        at: DateTime(2026, 7, 31, 21),
        text: 'The walk made the rest of the evening easier.',
        trace: trace,
      );
      final state = GameState()..setJournal([original]);

      await Storage.save(state, const []);
      final restored = (await Storage.load())!.$1.journal.single;
      expect(restored.trace, isNotNull);
      expect(restored.trace!.questTitles, trace.questTitles);
      expect(restored.trace!.goalTitles, trace.goalTitles);
      expect(restored.trace!.statGains[Stat.vit], 3);
      expect(restored.trace!.energy, EnergyWeather.steady);

      final edited = restored.copyWith(text: 'The walk changed the evening.');
      expect(
        edited.trace!.todayXp,
        84,
        reason: 'editing must keep the old day',
      );

      final legacy = Note.fromJson({
        'at': '2026-07-01T09:00:00.000',
        'text': 'A page from before automatic context.',
      });
      expect(legacy.trace, isNull, reason: 'older saves still open cleanly');
    },
  );

  test(
    'complete room themes: buy applies, switch is free, and persist',
    () async {
      SharedPreferences.setMockInitialValues({});
      final state = GameState()..embers = 500;
      expect(state.wallStyle, 'wall_walnut'); // free defaults
      expect(state.floorStyle, 'floor_oak');

      // buying a style owns it, puts it on, and deducts embers
      expect(
        state.buyStyle('wall_conservatory', 280, RoomStyleKind.wall),
        isTrue,
      );
      expect(state.embers, 220);
      expect(state.ownedStyles, contains('wall_conservatory'));
      expect(state.wallStyle, 'wall_conservatory');
      expect(
        state.buyStyle('wall_conservatory', 280, RoomStyleKind.wall),
        isFalse,
      );

      // switch back to the free default — owned, so no charge
      state.applyStyle('wall_walnut', RoomStyleKind.wall);
      expect(state.wallStyle, 'wall_walnut');
      expect(state.embers, 220);

      // Another whole-room identity remains unavailable until affordable.
      expect(state.buyStyle('wall_archive', 420, RoomStyleKind.wall), isFalse);
      expect(state.ownedStyles, isNot(contains('wall_archive')));

      await Storage.save(state, const []);
      final loaded = await Storage.load();
      expect(loaded, isNotNull);
      expect(loaded!.$1.ownedStyles, contains('wall_conservatory'));
      expect(loaded.$1.wallStyle, 'wall_walnut');
      expect(loaded.$1.floorStyle, 'floor_oak');
    },
  );

  test('creature skins: buy wears, apply switches, gate + persist', () async {
    SharedPreferences.setMockInitialValues({});
    final state = GameState()..embers = 500;
    expect(state.creatureSkin, 'ember_amber'); // free default

    expect(state.buySkin('mint_glass', 180), isTrue);
    expect(state.embers, 320);
    expect(state.ownedSkins, contains('mint_glass'));
    expect(state.creatureSkin, 'mint_glass');
    expect(state.buySkin('mint_glass', 180), isFalse);

    // wear the free default again — no charge
    state.applySkin('ember_amber');
    expect(state.creatureSkin, 'ember_amber');
    expect(state.embers, 320);

    // a gated skin stays unbuyable until earned
    expect(state.buySkin('gilded', 320, allowed: false), isFalse);
    expect(state.ownedSkins, isNot(contains('gilded')));

    await Storage.save(state, const []);
    final loaded = await Storage.load();
    expect(loaded, isNotNull);
    expect(loaded!.$1.ownedSkins, contains('mint_glass'));
    expect(loaded.$1.creatureSkin, 'ember_amber');
  });

  test('shop expansion offers new completion-linked rewards', () async {
    SharedPreferences.setMockInitialValues({});
    final state = GameState()..embers = 2000;

    expect(
      creatureSkins.map((skin) => skin.id),
      containsAll(['sunstone', 'sea_glass', 'moon_pearl']),
    );
    expect(
      roomStyles.map((style) => style.id),
      containsAll(['wall_amber', 'wall_berry', 'floor_maple', 'floor_cherry']),
    );

    final seaGlass = creatureSkinById('sea_glass')!;
    expect(seaGlass.requires, 'proof-positive');
    expect(
      state.buySkin(
        seaGlass.id,
        seaGlass.price,
        allowed: skinUnlocked(seaGlass, state),
      ),
      isFalse,
      reason: 'the timer-proof reward stays trophy-linked',
    );
    state.unlockedAchievements.add('proof-positive');
    expect(
      state.buySkin(
        seaGlass.id,
        seaGlass.price,
        allowed: skinUnlocked(seaGlass, state),
      ),
      isTrue,
    );

    final maple = roomStyleById('floor_maple')!;
    expect(state.buyStyle(maple.id, maple.price, maple.kind), isTrue);
    await Storage.save(state, const []);
    final loaded = (await Storage.load())!.$1;
    expect(loaded.ownedSkins, contains('sea_glass'));
    expect(loaded.creatureSkin, 'sea_glass');
    expect(loaded.ownedStyles, contains('floor_maple'));
    expect(loaded.floorStyle, 'floor_maple');
  });

  test('window views: buy applies, apply switches, gate + persist', () async {
    SharedPreferences.setMockInitialValues({});
    final state = GameState()..embers = 500;
    expect(state.windowScene, 'moon'); // free default

    expect(state.buyWindow('city', 140), isTrue);
    expect(state.embers, 360);
    expect(state.ownedWindows, contains('city'));
    expect(state.windowScene, 'city');
    expect(state.buyWindow('city', 140), isFalse);

    state.applyWindow('moon'); // back to the free default, no charge
    expect(state.windowScene, 'moon');
    expect(state.embers, 360);

    expect(state.buyWindow('aurora', 280, allowed: false), isFalse);
    expect(state.ownedWindows, isNot(contains('aurora')));

    await Storage.save(state, const []);
    final loaded = await Storage.load();
    expect(loaded, isNotNull);
    expect(loaded!.$1.ownedWindows, contains('city'));
    expect(loaded.$1.windowScene, 'moon');
  });

  test('stage scenes: buy applies, apply switches, gate + persist', () async {
    SharedPreferences.setMockInitialValues({});
    final state = GameState()..embers = 900;
    expect(state.stageScene, 'hearthside'); // free default

    expect(state.buyScene('garden', 260), isTrue);
    expect(state.embers, 640);
    expect(state.ownedScenes, contains('garden'));
    expect(state.stageScene, 'garden');
    expect(state.buyScene('garden', 260), isFalse); // owned → no recharge

    state.applyScene('hearthside'); // back to the free default, no charge
    expect(state.stageScene, 'hearthside');

    // a gated scene stays unbuyable until allowed, even with embers in hand
    expect(state.buyScene('library', 400, allowed: false), isFalse);
    expect(state.ownedScenes, isNot(contains('library')));

    // an unowned id can't be equipped for free (apply is guarded now)
    state.applyScene('seaside');
    expect(state.stageScene, 'hearthside');

    await Storage.save(state, const []);
    final loaded = await Storage.load();
    expect(loaded, isNotNull);
    expect(loaded!.$1.ownedScenes, contains('garden'));
    expect(loaded.$1.stageScene, 'hearthside');
  });

  test('streak milestone chest is paid once per crossing, not per completion', () {
    final state = GameState()
      ..embers = 0
      ..streakDays = 6
      // last active YESTERDAY, so today's first completion increments to 7
      ..lastCompletionDay = Days.key(
        DateTime.now().subtract(const Duration(days: 1)),
      );

    // first completion of the day: streak crosses to 7 → +50 chest, queued once
    final b1 = state.roll(Quest(title: 'Read', stat: Stat.intl, difficulty: 3));
    state.commit(b1);
    expect(state.streakDays, 7);
    final afterFirst = state.embers;
    expect(afterFirst, b1.embers + 50); // quest embers + the week chest
    expect(state.takeJustStreakMilestone(), 7); // exactly one chest queued
    expect(state.takeJustStreakMilestone(), isNull);

    // a SECOND completion the SAME day must NOT re-pay the milestone (the bug:
    // the check sat outside the day-change guard, paying +50 every completion)
    final b2 = state.roll(Quest(title: 'Walk', stat: Stat.vit, difficulty: 2));
    state.commit(b2);
    expect(state.streakDays, 7); // unchanged — same day
    expect(state.embers, afterFirst + b2.embers); // only the quest embers
    expect(state.takeJustStreakMilestone(), isNull); // no second chest
  });

  test('shared space: roomDisplay is appearance-only (no private data)', () {
    final s = GameState()
      ..playerName = 'Mika'
      ..level = 9
      ..creatureSkin = 'mint_glass'
      ..wallStyle = 'wall_plum'
      ..windowScene = 'aurora';
    s.ownedFurniture.addAll(['rug', 'lamp']);
    s.setJournal(
      s.journal.withNote('a private thought', DateTime(2026, 6, 28)),
    );

    final d = roomDisplay(s);
    expect(d['name'], 'Fellow keeper');
    expect(d['level'], 9);
    expect(d['skin'], 'mint_glass');
    expect(d['wall'], 'wall_plum');
    expect(d['window'], 'aurora');
    expect((d['furniture'] as List), containsAll(['rug', 'lamp']));
    // Crucial: never leak names or unselected writing into a public room doc.
    // Profile-card writing is included only behind its explicit audience bit.
    expect(d.toString().contains('Mika'), isFalse);
    expect(d.containsKey('journal'), isFalse);
    expect(d.toString().contains('private thought'), isFalse);
  });

  test('shared space: roomCode persists', () async {
    SharedPreferences.setMockInitialValues({});
    final s = GameState()..roomCode = 'AB23CD';
    await Storage.save(s, const []);
    final loaded = await Storage.load();
    expect(loaded, isNotNull);
    expect(loaded!.$1.roomCode, 'AB23CD');
  });

  test(
    'retired wall paints all grandfather into a room they can still use',
    () {
      // Every paid wall style from the old model must land its owner in a real
      // room. Rose Clay and Amber Limewash previously fell through every branch
      // and their owners lost 180-200 Glimmers with nothing back.
      for (final retired in const {
        'wall_sage': 'wall_conservatory',
        'wall_clay': 'wall_conservatory',
        'wall_amber': 'wall_conservatory',
        'wall_plum': 'wall_archive',
        'wall_indigo': 'wall_archive',
        'wall_berry': 'wall_archive',
      }.entries) {
        final old = GameState()
          ..wallStyle = retired.key
          ..ownedStyles.add(retired.key);
        final revived = GameState.fromJson(
          jsonDecode(jsonEncode(old.toJson())),
        );
        expect(
          isSpaceThemeId(revived.wallStyle),
          isTrue,
          reason: '${retired.key} left the player on a non-existent room',
        );
        expect(
          revived.ownedStyles,
          contains(retired.value),
          reason: '${retired.key} owner was not granted ${retired.value}',
        );
      }
    },
  );
}
