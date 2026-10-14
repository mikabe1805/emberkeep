// Me, the mantel room: the YOUR BUILD card reads the engine, the quiet tabs
// open sheets that hold the page's own sections (YOUR SPACE opens a page of its
// own, see your_space_page_test.dart), every older feature of Me is still
// reachable, and the room holds up at large text, with Reduce Motion and for
// VoiceOver.
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
          find.descendant(of: cell, matching: find.text(stat.label)),
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

    testWidgets('the card opens a domain page, and the room has no HUD copy', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_page(_state()));
      await tester.pump();

      // The room draws no HUD of its own (the shell's one HUD is over every
      // room: test/house/house_hud_test.dart).
      expect(find.byType(ClassDayHud), findsNothing);
      // Touching a domain on the glass opens that domain's page.
      await tester.tap(find.byKey(const Key('mantel-stat-intl')));
      await tester.pumpAndSettle();
      expect(find.byType(DomainDetailScreen), findsOneWidget);
      expect(
        tester.widget<DomainDetailScreen>(find.byType(DomainDetailScreen)).stat,
        Stat.intl,
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
        ['STR', 'VIT', 'INT', 'FOC', 'SOC', 'DIS'],
      );
      expect(
        [for (final s in facts.stats) s.name],
        ['Strength', 'Vitality', 'Intellect', 'Focus', 'Social', 'Discipline'],
      );
      expect(MantelBuild.titleCase('MIGHTY STEADY HAND'), 'Mighty Steady Hand');
      expect(facts.spoken, contains('Level 18'));
    });
  });

  group('the six stats, drawn out', () {
    String text(WidgetTester tester, String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data!.replaceAll(' ', ' ');

    testWidgets('each row has its glyph, name, value, ability and next tier', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_page(_state()));
      await tester.pump();
      // _state(): STR 88, VIT 72, INT 125, FOC 94, SOC 61, DIS 103.
      const expected = {
        Stat.str: ('Power Slam · Tier 3', 'Tier 4 at 150'),
        Stat.vit: ('Second Wind · Tier 2', 'Tier 3 at 80'),
        Stat.intl: ('Spell Bolt · Tier 3', 'Tier 4 at 150'),
        Stat.foc: ('Focus · Tier 3', 'Tier 4 at 150'),
        Stat.soc: ('Call a Friend · Tier 2', 'Tier 3 at 80'),
        Stat.dis: ('Super · Tier 3', 'Tier 4 at 150'),
      };
      final glyphs = <IconData>{};
      for (final stat in Stat.values) {
        final icon = tester.widget<Icon>(
          find.byKey(Key('mantel-stat-icon-${stat.name}')),
        );
        expect(icon.icon, stat.icon);
        glyphs.add(icon.icon!);
        expect(text(tester, 'mantel-stat-name-${stat.name}'), stat.label);
        final (ability, next) = expected[stat]!;
        expect(text(tester, 'mantel-ability-${stat.name}'), ability);
        expect(text(tester, 'mantel-next-${stat.name}'), next);
      }
      expect(glyphs, hasLength(6), reason: 'six different marks');
    });

    testWidgets('a stat trained this week glows with its points; a quiet one '
        'shows nothing', (tester) async {
      _phone(tester);
      final state = _state();
      // The clock is Tue Oct 6 12:30: Monday 04:00 on is this week.
      state.markTraining(Stat.str, at: DateTime(2026, 10, 5, 9));
      state.markTraining(Stat.str, at: DateTime(2026, 10, 6, 8));
      state.markTraining(
        Stat.intl,
        at: DateTime(2026, 10, 5, 10),
        timerProven: true,
      );
      // Last week's does not count.
      state.markTraining(Stat.vit, at: DateTime(2026, 10, 5, 3, 59));
      await tester.pumpWidget(_page(state));
      await tester.pump();
      String chip(String key) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(Text),
            ),
          )
          .data!;
      expect(chip('mantel-training-str'), '+2 this week');
      expect(chip('mantel-training-intl'), '+1.5 this week');
      for (final stat in [Stat.vit, Stat.foc, Stat.soc, Stat.dis]) {
        expect(
          find.byKey(Key('mantel-training-${stat.name}')),
          findsNothing,
          reason: stat.label,
        );
      }
      final facts = MantelBuild.from(state);
      expect(facts.anyTrained, isTrue);
      expect(facts.stats.first.points, 2);
    });

    testWidgets('a quiet week is plain: no chips at all', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_page(_state()));
      await tester.pump();
      for (final stat in Stat.values) {
        expect(find.byKey(Key('mantel-training-${stat.name}')), findsNothing);
      }
      expect(MantelBuild.from(_state()).anyTrained, isFalse);
    });

    testWidgets('a locked ability is an aspiration, never a scold', (
      tester,
    ) async {
      _phone(tester);
      final state = _state()..stats[Stat.soc] = 5;
      await tester.pumpWidget(_page(state));
      await tester.pump();
      expect(
        text(tester, 'mantel-next-soc'),
        'Reach Social 10 to unlock Call a Friend',
      );
      expect(find.byKey(const Key('mantel-ability-soc')), findsNothing);
      // At 10 it opens at tier 1.
      state.stats[Stat.soc] = 10;
      await tester.pumpWidget(_page(state));
      await tester.pump();
      expect(text(tester, 'mantel-ability-soc'), 'Call a Friend · Tier 1');
      expect(text(tester, 'mantel-next-soc'), 'Tier 2 at 40');
    });

    testWidgets('the top tier says so', (tester) async {
      _phone(tester);
      final state = _state()..stats[Stat.str] = 150;
      await tester.pumpWidget(_page(state));
      await tester.pump();
      expect(text(tester, 'mantel-ability-str'), 'Power Slam · Tier 4');
      expect(text(tester, 'mantel-next-str'), 'Top tier');
    });

    testWidgets('the week previews its monster and what it is weak to', (
      tester,
    ) async {
      _phone(tester);
      // Tue Oct 6 2026 is ISO week 41 (odd): the Fog.
      await tester.pumpWidget(_page(_state()));
      await tester.pump();
      expect(
        find.text('This weekend: the Fog · weak to Intellect'),
        findsOneWidget,
      );
      // Wed Oct 14 is week 42 (even): the Couch Troll.
      Clock.freeze(DateTime(2026, 10, 14, 12, 30));
      await tester.pumpWidget(_page(_state()));
      await tester.pump();
      expect(
        find.text('This weekend: the Couch Troll · weak to Strength'),
        findsOneWidget,
      );
    });

    testWidgets('every row is a 44 point target at every text size', (
      tester,
    ) async {
      _phone(tester);
      for (final scale in [1.0, 1.3, 2.0]) {
        await tester.pumpWidget(_page(_state(), textScale: scale));
        await tester.pump();
        for (final stat in Stat.values) {
          final size = tester.getSize(
            find.byKey(Key('mantel-stat-${stat.name}')),
          );
          expect(size.height, greaterThanOrEqualTo(44), reason: '$stat $scale');
          expect(size.width, greaterThanOrEqualTo(44), reason: '$stat $scale');
        }
      }
    });

    testWidgets('at the phone size the footer stays pinned and the shelf '
        'stays in view', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_page(_state()));
      await tester.pump();
      // (Whether all six rows fit at 100% is a matter of the real fonts, which
      // a widget test does not load; the renders in design/comparisons show
      // it. Here: the footer is outside the scroll, and the glass never
      // climbs over the shelf.)
      final scroll = find.byKey(const Key('mantel-build-scroll'));
      expect(
        find.descendant(
          of: scroll,
          matching: find.byKey(const Key('mantel-footer')),
        ),
        findsNothing,
        reason: 'the footer stays pinned under the stats',
      );
      // The glass keeps below the mantel shelf, so the earned objects and the
      // trophy leader stay in the picture.
      const frame = MantelFrame(page: Size(393, 852), above: 0, dock: 122);
      final shelf = frame.plateToPage(const Offset(0, MantelFrame.shelfBottom));
      final card = tester.getRect(find.byKey(const Key('mantel-build-card')));
      expect(card.top, greaterThanOrEqualTo(shelf.dy - 1));
    });

    testWidgets('at large text the footer joins the scroll and the stats '
        'get the room', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_page(_state(), textScale: 2.0));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const Key('mantel-build-scroll')),
          matching: find.byKey(const Key('mantel-footer')),
        ),
        findsOneWidget,
      );
      // The first stat is on the glass and the last is one scroll away.
      expect(find.byKey(const Key('mantel-stat-str')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('mantel-stat-dis')),
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('mantel-build-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.byKey(const Key('mantel-stat-dis')), findsOneWidget);
    });

    testWidgets('no word says a stat was lost, missed or failed', (
      tester,
    ) async {
      _phone(tester);
      final state = GameState()
        ..reduceMotion = true
        ..stats.addAll({for (final s in Stat.values) s: 0});
      await tester.pumpWidget(_page(state));
      await tester.pump();
      final all = [
        for (final t in tester.widgetList<Text>(find.byType(Text))) t.data,
      ].whereType<String>().join(' ').toLowerCase();
      for (final word in [
        'lost',
        'missed',
        'failed',
        'broke',
        'behind',
        'overdue',
        '—',
      ]) {
        expect(all.contains(word), isFalse, reason: word);
      }
      // All six are locked and each says what it will unlock.
      for (final stat in Stat.values) {
        expect(
          text(tester, 'mantel-next-${stat.name}'),
          startsWith('Reach ${stat.label} 10 to unlock '),
        );
      }
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
          find.bySemanticsLabel(
            RegExp('^${stat.label} ${state.stats[stat]}[ .,]'),
          ),
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
