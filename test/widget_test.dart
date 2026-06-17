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
    expect(find.text('TODAY · 8 QUESTS LEFT'), findsOneWidget);
  });

  testWidgets('completing a quest marks it done and grants XP', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Walk 10 minutes'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('TODAY · 7 QUESTS LEFT'), findsOneWidget);

    // let receipt/particle timers and bar fill finish so no timers leak
    // (pumpAndSettle would never settle: ambient animations repeat forever)
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('undo restores a quest completed by accident', (tester) async {
    await pumpApp(tester);
    expect(find.text('TODAY · 8 QUESTS LEFT'), findsOneWidget);

    await tester.tap(find.text('Walk 10 minutes'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('TODAY · 7 QUESTS LEFT'), findsOneWidget);

    // wait for the celebration to settle and the UNDO snackbar to appear
    await tester.pump(const Duration(milliseconds: 1400));
    final undo = find.text('UNDO');
    expect(undo, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800)); // settle snackbar
    await tester.tap(undo, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));

    // the quest is back on the board, the completion reverted
    expect(find.text('TODAY · 8 QUESTS LEFT'), findsOneWidget);

    // settle remaining timers
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('rapid double-complete then undo keeps the first quest\'s reward',
      (tester) async {
    await pumpApp(tester);
    expect(find.text('TODAY · 8 QUESTS LEFT'), findsOneWidget);

    // complete A, then complete B before A's deferred commit fires (~1s)
    await tester.tap(find.text('Walk 10 minutes'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.text('Read one page'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('TODAY · 6 QUESTS LEFT'), findsOneWidget);

    // wait for B's commit + the UNDO snackbar, then undo B
    await tester.pump(const Duration(milliseconds: 1400));
    final undo = find.text('UNDO');
    expect(undo, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(undo, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));

    // B reverted (back to 7), and A's reward was NOT destroyed
    expect(find.text('TODAY · 7 QUESTS LEFT'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('LEVEL 1 · 0 XP'), findsNothing,
        reason: 'quest A\'s XP must survive undoing quest B');

    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('nav dock switches to Me, Plans and Inspiration', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('YOUR BUILD'), findsOneWidget);

    // trophy case sits further down the lazy list
    await tester.drag(find.text('Me'), const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('TROPHY CASE'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Plans'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.local_florist_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Inspiration'), findsOneWidget);
  });

  testWidgets('goals page can take on a quest', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Take on quests!'), findsOneWidget);

    // expand "Become a reader" and adopt its first quest
    await tester.tap(find.text('Become a reader'));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 150));
    final takeOn = find.text('TAKE ON').first;
    await tester.ensureVisible(takeOn);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(takeOn);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.task_alt));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('TODAY · 9 QUESTS LEFT'), findsOneWidget);

    // the new quest is appended — scroll the lazy list to reach it
    await tester.drag(find.text('Do 2 push-ups'), const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Pick a book that excites you'), findsOneWidget);

    // settle the snackbar timer
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('oath wizard walks ambition → path → oath', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Begin a new goal'));
    await settle(tester);
    expect(find.text('THE AMBITION'), findsOneWidget);

    await tester.enterText(
        find.byType(TextField).first, 'Maintain healthy skin');
    await tester.tap(find.text('FORGE THE PATH →'));
    await settle(tester);
    expect(find.text('THE PATH'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('forge-title')), 'Morning skincare ritual');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 300));

    // the CTA is the lazy list's last child — scroll it into existence
    await tester.drag(find.byKey(const Key('forge-title')),
        const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('READY THE OATH →'), findsOneWidget);

    await tester.tap(find.text('READY THE OATH →'));
    await settle(tester);
    expect(find.text('THE OATH'), findsOneWidget);

    // same lazy-list situation on the oath step
    await tester.drag(find.text('THE OATH'), const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 300));
    final swear = find.text('⚔ SWEAR THE OATH');
    await tester.tap(swear);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('OATH SWORN'), findsOneWidget);
    // seal holds ~1.4s then pops back to the goals page; the new goal
    // shows up in YOUR GOALS (and its quests elsewhere) — at least once
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

    // "just sleep" sits at the bottom of the scrollable recap
    final sleep = find.text('just sleep');
    await tester.ensureVisible(sleep);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(sleep);
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
    expect(find.text('JUST FOR TODAY'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Do the laundry');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('TODAY · 9 QUESTS LEFT'), findsOneWidget);
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
    expect(find.text('TODAY · 9 QUESTS LEFT'), findsOneWidget);
    expect(find.text('Finish the essay draft'), findsOneWidget);
    expect(find.text('DUE TODAY'), findsOneWidget);
  });
}
