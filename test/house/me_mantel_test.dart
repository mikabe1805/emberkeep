// Me, the mantel room: the YOUR BUILD card reads the engine, the quiet tabs
// open sheets that hold the page's own sections, every older feature of Me is
// still reachable, and the room holds up at large text, with Reduce Motion
// and for VoiceOver.
import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/cloud.dart';
import 'package:emberkeep/content/achievements.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/screens/domain_detail.dart';
import 'package:emberkeep/screens/me.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/class_day/class_day_room.dart';
import 'package:emberkeep/widgets/glass_switch.dart';
import 'package:emberkeep/widgets/house/house_backdrop.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:emberkeep/widgets/house/me/mantel_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'me_sheet_support.dart';

Widget _page(GameState state, {double textScale = 1}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(393, 852),
      textScaler: TextScaler.linear(textScale),
      padding: const EdgeInsets.only(bottom: 34),
    ),
    child: Scaffold(
      body: MePage(
        state: state,
        quests: const [],
        onPersist: () {},
        onPublishRoom: (_, {required code}) async =>
            RoomPublishResult.success(code),
        onAddQuest: (_) => true,
        onExport: () async => true,
        onImport: (_) async => true,
        onReset: () async => null,
        onNotifyChanged: () async {},
        onEnableCloud: () async => null,
        onLinkAccount: (_, _) async => null,
        onSignIn: (_, _) async => null,
        onSignOut: () async {},
        onDeleteAccount: (_) async => null,
        onRemovePrivateServiceIdentity: () async => null,
        spaceDiscoveryEnabled: true,
      ),
    ),
  ),
);

/// A phone, 393 x 852 points.
void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(393, 852);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

GameState _state() => GameState()
  ..reduceMotion = true
  ..level = 18
  ..totalCompletions = 24
  ..stats.addAll({
    Stat.str: 88,
    Stat.vit: 72,
    Stat.intl: 125,
    Stat.foc: 94,
    Stat.soc: 61,
    Stat.dis: 103,
  });

void main() {
  setUp(() {
    Sfx.instance.soundEnabled = false;
    Clock.freeze(DateTime(2026, 10, 6, 12, 30));
  });
  tearDown(() {
    Sfx.instance.soundEnabled = true;
    Clock.reset();
  });

  group('the YOUR BUILD card', () {
    testWidgets('says what the engine says', (tester) async {
      _phone(tester);
      final state = _state();
      await tester.pumpWidget(_page(state));
      await tester.pump();

      expect(find.text('YOUR BUILD'), findsOneWidget);
      expect(find.text('LEVEL'), findsOneWidget);
      expect(find.byKey(const Key('mantel-level')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('mantel-level'))).data,
        '${state.level}',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('mantel-title'))).data,
        MantelBuild.titleCase(state.buildTitle),
      );
      for (final stat in Stat.values) {
        final cell = find.byKey(Key('mantel-stat-${stat.name}'));
        expect(cell, findsOneWidget);
        expect(
          find.descendant(of: cell, matching: find.text(stat.abbr)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: cell,
            matching: find.text('${state.stats[stat]}'),
          ),
          findsOneWidget,
        );
      }
      expect(
        tester.widget<Text>(find.byKey(const Key('mantel-done'))).data,
        '24 QUESTS DONE · ${state.streakDays} DAY STREAK',
      );
      final need = state.xpNeeded(state.level + 1);
      expect(
        tester.widget<Text>(find.byKey(const Key('mantel-xp'))).data,
        '${state.xp} / $need XP',
      );
    });

    testWidgets('a single quest and a fresh build read plainly', (
      tester,
    ) async {
      _phone(tester);
      final state = GameState()
        ..reduceMotion = true
        ..totalCompletions = 1;
      await tester.pumpWidget(_page(state));
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const Key('mantel-done'))).data,
        startsWith('1 QUEST DONE'),
      );
      // Nothing about it says what is missing or behind.
      final text = [
        for (final t in tester.widgetList<Text>(find.byType(Text))) t.data,
      ].whereType<String>().join(' ').toLowerCase();
      for (final word in ['lost', 'missed', 'failed', 'broke', 'behind']) {
        expect(text.contains(word), isFalse, reason: word);
      }
    });

    testWidgets('the HUD wears the same stats and a stat opens its page', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_page(_state()));
      await tester.pump();

      expect(find.byType(ClassDayHud), findsOneWidget);
      // Touching a domain on the glass opens that domain's page.
      await tester.tap(find.byKey(const Key('mantel-stat-intl')));
      await tester.pumpAndSettle();
      expect(find.byType(DomainDetailScreen), findsOneWidget);
      expect(
        tester.widget<DomainDetailScreen>(find.byType(DomainDetailScreen)).stat,
        Stat.intl,
      );
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      // And so does the HUD.
      await tester.tap(find.byKey(const Key('class-day-stat-soc')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<DomainDetailScreen>(find.byType(DomainDetailScreen)).stat,
        Stat.soc,
      );
    });

    testWidgets('Me is the house room: the mantel plate is the backdrop', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_page(_state()));
      await tester.pump();
      expect(
        tester.widget<HouseRoomBackdrop>(find.byType(HouseRoomBackdrop)).room,
        HouseRoom.me,
      );
    });

    test('the card is read from the save, in title case', () {
      final facts = MantelBuild.from(_state());
      expect(facts.level, 18);
      expect(
        [for (final s in facts.stats) s.value],
        [88, 72, 125, 94, 61, 103],
      );
      expect(
        [for (final s in facts.stats) s.label],
        ['BODY', 'CARE', 'MIND', 'CRAFT', 'PEOPLE', 'HOME'],
      );
      expect(MantelBuild.titleCase('MIGHTY STEADY HAND'), 'Mighty Steady Hand');
      expect(facts.spoken, contains('Level 18'));
    });
  });

  group('the sheets hold the existing sections', () {
    testWidgets('TROPHY CASE opens the trophy case', (tester) async {
      _phone(tester);
      final state = _state()..unlockedAchievements.add(achievements.first.id);
      await tester.pumpWidget(_page(state));
      await tester.pump();
      expect(find.byKey(const Key('mantel-sheet')), findsNothing);

      await openMantelSheet(tester, 'trophy');
      expect(find.byKey(const Key('mantel-sheet')), findsOneWidget);
      expect(find.text('Trophy case'), findsOneWidget);
      expect(find.text('TROPHY CASE'), findsWidgets);
      expect(
        find.text('1 / ${achievements.length}'),
        findsOneWidget,
        reason: 'the existing trophy case counts what is earned',
      );
      await tester.scrollUntilVisible(
        find.text(achievements.last.title).first,
        200,
        scrollable: mantelSheetScrollable,
      );
    });

    testWidgets('SETTINGS holds light, sound, reminders and the Room Guide', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_page(_state()));
      await tester.pump();
      await openMantelSheet(tester, 'settings');
      expect(find.text('Settings'), findsOneWidget);
      for (final label in [
        'AMBIENT LIGHT',
        'SOUND · MOTION · TEXT',
        'REMINDERS',
        'ROOM GUIDE',
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          200,
          scrollable: mantelSheetScrollable,
        );
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('a switch inside a sheet answers at once', (tester) async {
      _phone(tester);
      final state = _state()..musicEnabled = false;
      await tester.pumpWidget(_page(state));
      await tester.pump();
      await openMantelSheet(tester, 'settings');
      final music = find.byWidgetPredicate(
        (w) => w is GlassSwitch && w.semanticLabel == 'Background music',
      );
      await tester.scrollUntilVisible(
        music,
        200,
        scrollable: mantelSheetScrollable,
      );
      expect(tester.widget<GlassSwitch>(music).value, isFalse);
      tester.widget<GlassSwitch>(music).onChanged!(true);
      await tester.pump();
      expect(state.musicEnabled, isTrue);
      expect(
        tester.widget<GlassSwitch>(music).value,
        isTrue,
        reason: 'the open sheet follows the save',
      );
    });

    testWidgets('SAVE holds the stash, restore and data controls', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_page(_state()));
      await tester.pump();
      await openMantelSheet(tester, 'save');
      expect(find.text('YOUR SAVE IS YOURS'), findsOneWidget);
      for (final label in [
        'STASH A COPY',
        'RESTORE',
        'USAGE LOG',
        'PRIVACY',
        'DELETE HELP',
        "WHAT'S NEW",
        'ABOUT + FEEDBACK',
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          200,
          scrollable: mantelSheetScrollable,
        );
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await tester.scrollUntilVisible(
        find.text('start over'),
        200,
        scrollable: mantelSheetScrollable,
      );
    });

    testWidgets('CLOSE, the dimmed room and back all close a sheet', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_page(_state()));
      await tester.pump();
      for (final close in ['button', 'barrier', 'back']) {
        await openMantelSheet(tester, 'save');
        expect(find.byKey(const Key('mantel-sheet')), findsOneWidget);
        switch (close) {
          case 'button':
            await closeMantelSheet(tester);
          case 'barrier':
            await tester.tapAt(const Offset(196, 40));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          case 'back':
            await tester.binding.handlePopRoute();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
        }
        expect(
          find.byKey(const Key('mantel-sheet')),
          findsNothing,
          reason: close,
        );
      }
    });
  });

  group('everything Me held is still reachable', () {
    testWidgets('MORE: the name, milestones, circle, share, gains, wardrobe, '
        'the shape and the account', (tester) async {
      _phone(tester);
      final state = _state()..collectedLoot.add('Periwinkle Frost');
      await tester.pumpWidget(_page(state));
      await tester.pump();
      await openMantelSheet(tester, 'more');
      expect(find.text('More'), findsOneWidget);
      for (final label in [
        'MILESTONES',
        'BEGIN A CIRCLE',
        'SHARE MY BUILD',
        'RECENT GAINS',
        'WARDROBE',
        'THE SHAPE OF IT',
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          200,
          scrollable: mantelSheetScrollable,
        );
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(
        find.byKey(const ValueKey('wardrobe-skin-Periwinkle Frost')),
        findsOneWidget,
      );
      // The player's name can still be changed.
      expect(find.byTooltip('Change your name'), findsOneWidget);
      // The long view still opens each domain.
      await tester.scrollUntilVisible(
        find.text('DEVICE-ONLY BY DEFAULT'),
        300,
        scrollable: mantelSheetScrollable,
      );
      expect(find.text('DEVICE-ONLY BY DEFAULT'), findsOneWidget);
    });

    testWidgets('YOUR SPACE: change space, the room photo, the links, '
        'Discover, the page and its arranger', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_page(_state()..roomCode = 'ABC234'));
      await tester.pump();
      await openMantelSheet(tester, 'space');
      expect(find.text('Your space'), findsOneWidget);
      expect(find.text('CHANGE SPACE'), findsOneWidget);
      expect(
        find.byKey(const Key('preview-public-space')),
        findsOneWidget,
        reason: 'the public preview',
      );
      expect(find.textContaining('Shared'), findsWidgets);
      expect(find.text('Discover spaces'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('space-page-open-arranger')),
        200,
        scrollable: mantelSheetScrollable,
      );
      expect(find.text('MY SPACE'), findsOneWidget);
    });

    testWidgets('Visit a space stands in for Discover when it is off', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MePage(
              state: _state(),
              quests: const [],
              onPersist: () {},
              onPublishRoom: (_, {required code}) async =>
                  RoomPublishResult.success(code),
              onAddQuest: (_) => true,
              onExport: () async => true,
              onImport: (_) async => true,
              onReset: () async => null,
              onNotifyChanged: () async {},
              onEnableCloud: () async => null,
              onLinkAccount: (_, _) async => null,
              onSignIn: (_, _) async => null,
              onSignOut: () async {},
              onDeleteAccount: (_) async => null,
              onRemovePrivateServiceIdentity: () async => null,
              spaceDiscoveryEnabled: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await openMantelSheet(tester, 'space');
      expect(find.text('Visit a space'), findsOneWidget);
    });
  });

  group('large text, Reduce Motion and VoiceOver', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets('130% and 200% text do not overflow: rest and every sheet '
          '(at ${(scale * 100).round()}%)', (tester) async {
        _phone(tester);
        await tester.pumpWidget(_page(_state(), textScale: scale));
        await tester.pump();
        expect(tester.takeException(), isNull);
        // The card stays inside the page, above the dock, and the tag is
        // not covered by it.
        final card = tester.getRect(find.byKey(const Key('mantel-build-card')));
        expect(card.bottom, lessThanOrEqualTo(852 - 88 - 34 + 0.5));
        final tag = tester.getRect(find.byKey(const Key('mantel-tag-trophy')));
        expect(card.top, greaterThanOrEqualTo(tag.bottom - 0.5));
        final left = tester.getRect(find.byKey(const Key('mantel-tab-space')));
        final right = tester.getRect(
          find.byKey(const Key('mantel-tab-settings')),
        );
        expect(left.overlaps(right), isFalse);
        for (final sheet in ['settings', 'save', 'trophy', 'space', 'more']) {
          await openMantelSheet(tester, sheet);
          expect(tester.takeException(), isNull, reason: '$sheet at $scale');
          await closeMantelSheet(tester);
        }
      });
    }

    testWidgets('the quiet tabs and the tag keep 44 point targets', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_page(_state(), textScale: 1.3));
      await tester.pump();
      for (final key in [
        'mantel-tab-settings',
        'mantel-tab-save',
        'mantel-tab-space',
        'mantel-tab-more',
        'mantel-tag-trophy',
      ]) {
        final size = tester.getSize(find.byKey(Key(key)));
        expect(size.height, greaterThanOrEqualTo(44), reason: key);
        expect(size.width, greaterThanOrEqualTo(44), reason: key);
      }
    });

    testWidgets('Reduce Motion: a sheet is there on its first frame', (
      tester,
    ) async {
      _phone(tester);
      final state = _state()..reduceMotion = true;
      await tester.pumpWidget(_page(state));
      await tester.pump();
      await tester.tap(find.byKey(const Key('mantel-tab-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('YOUR SAVE IS YOURS'), findsOneWidget);
      final slide = find.descendant(
        of: find.byType(Overlay),
        matching: find.byType(SlideTransition),
      );
      expect(
        slide.evaluate().where((e) {
          final w = e.widget as SlideTransition;
          return w.position.value != Offset.zero;
        }),
        isEmpty,
      );
    });

    testWidgets('VoiceOver: the card, the cells, the tabs and the tag speak', (
      tester,
    ) async {
      _phone(tester);
      final handle = tester.ensureSemantics();
      final state = _state();
      await tester.pumpWidget(_page(state));
      await tester.pump();

      expect(
        find.bySemanticsLabel(RegExp(r'^Your build, .*Level 18')),
        findsOneWidget,
      );
      for (final stat in Stat.values) {
        expect(
          find.bySemanticsLabel('${stat.label} ${state.stats[stat]}'),
          findsWidgets,
          reason: stat.label,
        );
      }
      for (final label in [
        'Settings',
        'Save and backup',
        'Your space, your own room and sharing',
        'TROPHY CASE',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      expect(
        find.bySemanticsLabel(RegExp(r'^More: milestones')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'quests? done, \d+ day streak')),
        findsOneWidget,
      );
      // A sheet is a named route.
      await openMantelSheet(tester, 'settings');
      expect(find.bySemanticsLabel('Settings'), findsWidgets);
      handle.dispose();
    });
  });

  group('where things sit', () {
    test('the plate maps to the page, the leader ends on the medallion', () {
      // A 393 x 852 screen under a 59 point status bar: the page is the rest.
      const frame = MantelFrame(page: Size(393, 793), above: 59, dock: 122);
      expect(frame.plate, 1.0);
      final (start, turn, end) = frame.leader;
      // The line runs along, then down onto the medallion.
      expect(turn.dy, closeTo(start.dy, 0.001));
      expect(end.dx, closeTo(turn.dx, 0.001));
      expect(end.dy, greaterThan(turn.dy));
      // The medallion is 324 plate points from the top of the screen: 265
      // points into the page (less the overscan's small enlargement).
      expect(end.dy, closeTo(324 - 59, 3));
      expect(end.dx, closeTo(236, 3));
    });

    test('the glass sits above the dock and keeps clear of the tag', () {
      const frame = MantelFrame(page: Size(393, 793), above: 59, dock: 122);
      final rect = frame.glassRect(200);
      expect(rect.bottom, 793 - 122 - MantelFrame.glassGap);
      expect(rect.left, MantelFrame.glassInset);
      final tagBottom = frame.tagMiddleY + MantelFrame.hit / 2;
      final room = frame.glassMaxHeight(tagBottom: tagBottom);
      expect(rect.bottom - room, greaterThanOrEqualTo(tagBottom));
    });
  });
}
