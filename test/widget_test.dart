import 'package:emberkeep/engine.dart';
import 'package:emberkeep/main.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/storage.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const LifeRpgApp());
  // let the async save-load resolve
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  // fresh saves get the first-run welcome — walk it
  if (tester.any(find.text('BEGIN'))) {
    await tester.tap(find.text('BEGIN'));
    await settle(tester);
    await tester.tap(find.text('rather not say'));
    await settle(tester);
    await tester.tap(find.text('I’ll explore first'));
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

    expect(find.text('LEVEL 1'), findsOneWidget);
    expect(find.text('Do 2 push-ups'), findsOneWidget);
    expect(find.text('TODAY · 9 LEFT'), findsOneWidget);
  });

  testWidgets('completing a quest marks it done and grants XP', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Walk 10 minutes'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('TODAY · 8 LEFT'), findsOneWidget);

    // let receipt/particle timers and bar fill finish so no timers leak
    // (pumpAndSettle would never settle: ambient animations repeat forever)
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('undo restores a quest completed by accident', (tester) async {
    await pumpApp(tester);
    expect(find.text('TODAY · 9 LEFT'), findsOneWidget);

    await tester.tap(find.text('Walk 10 minutes'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('TODAY · 8 LEFT'), findsOneWidget);

    // wait for the deferred commit, which arms swipe-to-undo on the card
    await tester.pump(const Duration(milliseconds: 1400));

    // swipe the finished card left to undo (the undo snackbar was removed).
    // Drive it as an explicit gesture — tester.drag doesn't reliably trip a
    // Dismissible's dismiss threshold.
    final card = find.byKey(const ValueKey('undo-Walk 10 minutes'));
    expect(card, findsOneWidget);
    await tester.ensureVisible(card);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.fling(card, const Offset(-500, 0), 1500);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    // the quest is back on the board, the completion reverted
    expect(find.text('TODAY · 9 LEFT'), findsOneWidget);

    // settle remaining timers
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('rapid double-complete then undo keeps the first quest\'s reward',
      (tester) async {
    // a tall surface so the full board (+ the Ember-of-the-Day card) fits and
    // both quests + the undo card stay built (no lazy-list scroll fragility)
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    expect(find.text('TODAY · 9 LEFT'), findsOneWidget);

    // complete A, then complete B before A's deferred commit fires (~1s)
    await tester.tap(find.text('Walk 10 minutes'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.text('Read one page'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('TODAY · 7 LEFT'), findsOneWidget);

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
    expect(find.text('TODAY · 8 LEFT'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('LEVEL 1 · 0 XP'), findsNothing,
        reason: 'quest A\'s XP must survive undoing quest B');

    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('nav dock switches to Me, Plans and Insights', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    // the Me page is a lazy ListView; the readability pass made the header
    // taller, so scroll the Me scrollable until each marker is built rather
    // than assuming a fixed position above the fold.
    final meList = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('YOUR BUILD'), 120,
        scrollable: meList);
    expect(find.text('YOUR BUILD'), findsOneWidget);

    // trophy case sits further down the lazy list
    await tester.scrollUntilVisible(find.text('TROPHY CASE'), 200,
        scrollable: meList);
    expect(find.text('TROPHY CASE'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Plans'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Insights'), findsOneWidget);
  });

  testWidgets('goals page can take on a quest', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Take on quests!'), findsOneWidget);

    // expand the first catalog goal (HOME & HEARTH → "Keep your space", near
    // the top so the lazy list already has it built) and adopt its first quest
    await tester.ensureVisible(find.text('Keep your space'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Keep your space'));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 150));
    final takeOn = find.text('TAKE ON').first;
    await tester.ensureVisible(takeOn);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(takeOn);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.task_alt));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('TODAY · 10 LEFT'), findsOneWidget);

    // the new quest is appended at the bottom — scroll the board to reach it.
    // (cards got taller in the mobile-readability pass; a big single drag
    // clamps at the list's end regardless of exact card height.)
    await tester.drag(find.text('Do 2 push-ups'), const Offset(0, -1000));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Make your bed'), findsOneWidget);

    // settle the snackbar timer
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('oath wizard: name, add a quest via the sheet, swear',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Begin a new goal'));
    await settle(tester);
    expect(find.text('A NEW OATH'), findsOneWidget);

    // name the oath (the only TextField until the sheet opens)
    await tester.enterText(
        find.byType(TextField).first, 'Maintain healthy skin');
    await tester.pump(const Duration(milliseconds: 100));

    // add a path-quest through the shared Ember Sheet
    await tester.ensureVisible(find.text('Add a quest'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Add a quest'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('NEW QUEST'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('ember-title')), 'Morning skincare');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.ensureVisible(find.text('Add →'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Add →'));
    await tester.pump(); // pop + add to the trail
    await tester.pump(const Duration(milliseconds: 500)); // sheet slides away
    await tester.pump(const Duration(milliseconds: 100));

    // swear the oath (the pinned footer button)
    await tester.tap(find.text('⚔ SWEAR THE OATH'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('OATH SWORN'), findsOneWidget);
    // seal holds ~1.4s then pops back to the goals page; the new goal shows up
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Maintain healthy skin'), findsWidgets);
  });

  testWidgets('night routine opens, recaps and closes', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.nightlight_round));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Goodnight'), findsOneWidget);
    expect(find.text('TODAY YOU EARNED'), findsOneWidget);

    // "just sleep" sits at the bottom of the recap's lazy ListView; the
    // random night-line length (+ taller readability type) can push it past
    // the build window, so ensureVisible would throw "No element". Scroll the
    // recap's own scrollable until it's built, then tap.
    final recapScroll = find.descendant(
        of: find.byKey(const ValueKey('recap')),
        matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(find.text('just sleep'), 200,
        scrollable: recapScroll);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('just sleep'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Goodnight'), findsNothing);

    // flush the Rest Earned achievement toast timers
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
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

  test('isValidSave gates what may be mirrored to the cloud', () async {
    SharedPreferences.setMockInitialValues({});
    // corrupt / foreign / empty must NOT be considered mirror-able
    expect(Storage.isValidSave('{ truncated'), isFalse);
    expect(Storage.isValidSave('{}'), isFalse);
    expect(Storage.isValidSave('{"state":{},"quests":[]}'), isFalse);
    expect(Storage.isValidSave('{"app":"other","state":{"stats":[]}}'),
        isFalse);

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
        find.byKey(const Key('ember-title')), 'Do the laundry');
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

    expect(find.text('TODAY · 10 LEFT'), findsOneWidget);
    expect(find.text('Do the laundry'), findsOneWidget);
    expect(find.text('DUE TODAY'), findsOneWidget);
  });

  testWidgets('plans page can add an event for today', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('+ PLAN'));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField), 'Finish the essay draft');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('PLAN IT'));
    await tester.pump(const Duration(milliseconds: 400));

    // due today → leads the quest list
    await tester.tap(find.byIcon(Icons.task_alt));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('TODAY · 10 LEFT'), findsOneWidget);
    expect(find.text('Finish the essay draft'), findsOneWidget);
    expect(find.text('DUE TODAY'), findsOneWidget);
  });

  test('embers: earned on completion, then spent in the shop with a gate',
      () async {
    final state = GameState();
    expect(state.embers, 0);
    expect(state.ownedFurniture, isEmpty);

    // earning: a completion adds embers alongside XP (~a third, min 1)
    final bundle =
        state.roll(Quest(title: 'Read', stat: Stat.intl, difficulty: 3));
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
  });

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
    state.setJournal(state.journal
        .withNote('first thought', DateTime(2026, 6, 28))
        .withNote('second thought', DateTime(2026, 6, 29)));
    expect(state.journal.length, 2);
    // a domain note coexists — the hub aggregates both
    state.setDomainNotes(
        Stat.vit, [Note(at: DateTime(2026, 6, 27), text: 'ran a 5k')]);

    await Storage.save(state, const []);
    final loaded = await Storage.load();
    expect(loaded, isNotNull);
    expect(loaded!.$1.journal.map((n) => n.text),
        containsAll(['first thought', 'second thought']));
    expect(loaded.$1.notesFor(Stat.vit).first.text, 'ran a 5k');

    // deleting a free entry sticks
    loaded.$1.setJournal(loaded.$1.journal.without(loaded.$1.journal.first));
    expect(loaded.$1.journal.length, 1);
    expect(loaded.$1.journal.first.text, 'second thought');
  });

  test('room styles: buy applies, apply switches, gate + persist', () async {
    SharedPreferences.setMockInitialValues({});
    final state = GameState()..embers = 500;
    expect(state.wallStyle, 'wall_walnut'); // free defaults
    expect(state.floorStyle, 'floor_oak');

    // buying a style owns it, puts it on, and deducts embers
    expect(state.buyStyle('wall_plum', 140, RoomStyleKind.wall), isTrue);
    expect(state.embers, 360);
    expect(state.ownedStyles, contains('wall_plum'));
    expect(state.wallStyle, 'wall_plum');
    expect(state.buyStyle('wall_plum', 140, RoomStyleKind.wall), isFalse);

    // switch back to the free default — owned, so no charge
    state.applyStyle('wall_walnut', RoomStyleKind.wall);
    expect(state.wallStyle, 'wall_walnut');
    expect(state.embers, 360);

    // an achievement-gated style stays unbuyable until allowed
    expect(
        state.buyStyle('wall_indigo', 220, RoomStyleKind.wall, allowed: false),
        isFalse);
    expect(state.ownedStyles, isNot(contains('wall_indigo')));

    await Storage.save(state, const []);
    final loaded = await Storage.load();
    expect(loaded, isNotNull);
    expect(loaded!.$1.ownedStyles, contains('wall_plum'));
    expect(loaded.$1.wallStyle, 'wall_walnut');
    expect(loaded.$1.floorStyle, 'floor_oak');
  });

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
}
