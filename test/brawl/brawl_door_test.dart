// The weekend door: Saturday and Sunday (by Clock) light "Join the fight!" on
// the Quests Doorway and its board; after the weekend's win it reads "Fight
// again"; during the week the Doorway only says what is coming. The loot a
// win leaves is saved once a weekend, survives a save round trip and shows in
// the Me trophy case.
import 'dart:convert';
import 'dart:math' as math;

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/brawl/brawl_loot.dart';
import 'package:emberkeep/brawl/core/brawl_core.dart';
import 'package:emberkeep/brawl/ui/brawl_flow.dart';
import 'package:emberkeep/brawl/weekly_training.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/cloud.dart';
import 'package:emberkeep/content/day_planning.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/me.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../house/me_sheet_support.dart';
import 'brawl_ui_support.dart';

class _NoLuck implements math.Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.999;
  @override
  int nextInt(int max) => 0;
}

const _titles = ['Read ten pages', 'Review one problem', 'Write for today'];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    QuestsPage.debugLegacyBoard = false;
    SharedPreferences.setMockInitialValues({});
    GameState.debugRandomFactory = _NoLuck.new;
    Sfx.instance.soundEnabled = false;
  });
  tearDown(() {
    QuestsPage.debugLegacyBoard = true;
    BrawlDebug.openAnyDay = false;
    Clock.reset();
    GameState.debugRandomFactory = null;
    Sfx.instance.soundEnabled = true;
  });

  group('the dates', () {
    test('Saturday and Sunday open the door; the week does not', () {
      // 2026-10-05 is a Monday.
      for (var day = 5; day <= 11; day++) {
        final noon = DateTime(2026, 10, day, 12);
        expect(
          isBrawlWeekend(noon),
          day >= 10,
          reason: 'weekday ${noon.weekday}',
        );
        expect(brawlDoorOpen(noon), day >= 10);
      }
    });

    test('the small hours still belong to the day before', () {
      // Friday night, still up at 01:30 on Saturday: it is still Friday.
      expect(isBrawlWeekend(DateTime(2026, 10, 10, 1, 30)), isFalse);
      expect(isBrawlWeekend(DateTime(2026, 10, 10, 3, 59)), isFalse);
      expect(isBrawlWeekend(DateTime(2026, 10, 10, 4)), isTrue);
      // Sunday's fight is still Sunday's at 02:00 on Monday.
      expect(isBrawlWeekend(DateTime(2026, 10, 12, 2)), isTrue);
      expect(isBrawlWeekend(DateTime(2026, 10, 12, 3, 59)), isTrue);
      expect(isBrawlWeekend(DateTime(2026, 10, 12, 4)), isFalse);
    });

    test('a debug seam opens the door on any day, and only a test sets it', () {
      final tuesday = DateTime(2026, 10, 6, 10);
      expect(brawlDoorOpen(tuesday), isFalse);
      BrawlDebug.openAnyDay = true;
      expect(brawlDoorOpen(tuesday), isTrue);
    });

    test('the monster of the week comes from the week number', () {
      expect(monsterOfTheWeek(trollSaturday).id, 'couch_troll');
      expect(monsterOfTheWeek(fogSaturday).id, 'fog');
      // The Sunday of the Troll week is still the Troll's.
      expect(monsterOfTheWeek(DateTime(2026, 10, 4, 21)).id, 'couch_troll');
    });
  });

  group('the loot', () {
    BrawlLoot? win(GameState s, DateTime at, {String loot = 'Porch Lantern'}) =>
        s.recordBrawlWin(
          monster: BrawlMonster.troll,
          chest: BrawlChest.steady,
          loot: loot,
          seconds: 41.3,
          now: at,
        );

    test('a weekend\'s first win keeps one piece; replays keep nothing', () {
      Clock.freeze(trollSaturday);
      final state = mikaState();
      expect(state.brawlWonThisWeek(), isFalse);
      final first = win(state, trollSaturday);
      expect(first, isNotNull);
      expect(first!.loot, 'Porch Lantern');
      expect(state.brawlLoot, hasLength(1));
      expect(state.brawlWonThisWeek(), isTrue);
      // Sunday of the same week: practice.
      final sunday = DateTime(2026, 10, 4, 15);
      expect(win(state, sunday, loot: 'Golden Doormat'), isNull);
      expect(state.brawlLoot, hasLength(1));
      expect(state.brawlLoot.single.loot, 'Porch Lantern');
      // The next weekend is a new week.
      final next = DateTime(2026, 10, 10, 11);
      expect(win(state, next, loot: 'Cloud Lamp'), isNotNull);
      expect(state.brawlLoot, hasLength(2));
    });

    test('the save is additive and round-trips', () {
      Clock.freeze(trollSaturday);
      final empty = mikaState();
      final plain = empty.toJson();
      expect(plain.containsKey('brawlLoot'), isFalse);
      expect(plain.containsKey('brawlEasy'), isFalse);

      final state = mikaState()..brawlEasy = true;
      win(state, trollSaturday);
      final copy = GameState.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
      );
      expect(copy.brawlEasy, isTrue);
      expect(copy.brawlLoot, hasLength(1));
      expect(copy.brawlLoot.single.loot, 'Porch Lantern');
      expect(copy.brawlLoot.single.chest, BrawlChest.steady);
      expect(copy.brawlLoot.single.monster, BrawlMonster.troll);
      expect(copy.brawlLoot.single.seconds, closeTo(41.3, 0.05));
      expect(copy.brawlWonThisWeek(trollSaturday), isTrue);
    });

    test('an older save without the fields loads, and a damaged one is kept '
        'minus the damage', () {
      final json = mikaState().toJson();
      json.remove('brawlLoot');
      json.remove('brawlEasy');
      final old = GameState.fromJson(json);
      expect(old.brawlLoot, isEmpty);
      expect(old.brawlEasy, isFalse);

      json['brawlLoot'] = [
        {
          'w': '2026-09-28',
          'm': 'troll',
          'c': 'swift',
          'l': 'Golden Doormat',
          't': 1,
        },
        {'w': 'nonsense', 'm': 'troll', 'c': 'swift', 'l': 'x', 't': 1},
        'garbage',
        {'w': '2026-10-05', 'm': 'fog', 'c': 'huge', 'l': 'x', 't': 1},
      ];
      final damaged = GameState.fromJson(json);
      expect(damaged.brawlLoot.map((l) => l.loot), ['Golden Doormat']);
    });

    test('the case keeps two years of weekends and no more', () {
      Clock.freeze(trollSaturday);
      final state = mikaState();
      for (var i = 0; i < brawlLootCap + 6; i++) {
        final at = DateTime(2026, 10, 3, 11).add(Duration(days: 7 * i));
        Clock.freeze(at);
        win(state, at);
      }
      expect(state.brawlLoot, hasLength(brawlLootCap));
    });
  });

  group('the Doorway', () {
    late GameState state;
    late List<Quest> quests;

    Future<void> mount(
      WidgetTester tester,
      DateTime at, {
      double textScale = 1,
      bool Function()? onPersist,
    }) async {
      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
      });
      Clock.freeze(at);
      state = GameState(rng: _NoLuck())
        ..onboarded = true
        ..playerName = 'Mika'
        ..level = 6
        ..soundEnabled = false
        ..reduceMotion = true
        ..lastActiveDay = Days.key(at);
      quests = [
        Quest(title: _titles[0], stat: Stat.intl, difficulty: 4),
        Quest(title: _titles[1], stat: Stat.foc, difficulty: 3),
        Quest(title: _titles[2], stat: Stat.dis, difficulty: 2),
      ];
      applyDailyField(quests, at, _titles);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(393, 852),
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: QuestsPage(
                state: state,
                quests: quests,
                onRefresh: () => 0,
                onPersist: () {},
                onAdd: (quest) {
                  quests.add(quest);
                  return true;
                },
                onRemove: quests.remove,
                onSnapshot: () => jsonEncode(state.toJson()),
                onRestore: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
    }

    final door = find.byKey(const Key('brawl-door'));
    final preview = find.byKey(const Key('brawl-preview'));
    String doorText(WidgetTester tester, String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data ?? '';

    testWidgets('Saturday lights "Join the fight!" with the Fog at the door', (
      tester,
    ) async {
      await mount(tester, fogSaturday);
      expect(find.byKey(const Key('quest-day-room')), findsOneWidget);
      expect(door, findsOneWidget);
      expect(doorText(tester, 'brawl-door-title'), 'Join the fight!');
      expect(doorText(tester, 'brawl-door-sub'), 'The Fog is at the door');
      expect(preview, findsNothing, reason: 'the door replaces the preview');
    });

    testWidgets('Sunday keeps it lit, and the Troll weeks say so', (
      tester,
    ) async {
      await mount(tester, DateTime(2026, 10, 4, 18));
      expect(door, findsOneWidget);
      expect(
        doorText(tester, 'brawl-door-sub'),
        'The Couch Troll is at the door',
      );
    });

    testWidgets('during the week the Doorway only says what is coming', (
      tester,
    ) async {
      await mount(tester, wednesday);
      expect(door, findsNothing);
      expect(preview, findsOneWidget);
      expect(
        tester.widget<Text>(preview).data,
        'This weekend: the Fog · weak to Intellect',
      );
      await mount(tester, DateTime(2026, 10, 14, 11));
      expect(
        tester.widget<Text>(preview).data,
        'This weekend: the Couch Troll · weak to Strength',
      );
    });

    testWidgets('after the weekend\'s win it reads "Fight again"', (
      tester,
    ) async {
      await mount(tester, fogSaturday);
      expect(doorText(tester, 'brawl-door-title'), 'Join the fight!');
      state.recordBrawlWin(
        monster: BrawlMonster.fog,
        chest: BrawlChest.swift,
        loot: 'Cloud Lamp',
        seconds: 21,
        now: fogSaturday,
      );
      await tester.pump();
      expect(doorText(tester, 'brawl-door-title'), 'Fight again');
      expect(doorText(tester, 'brawl-door-sub'), contains('practice'));
    });

    testWidgets(
      'the debug seam lights it on a weekday, and nothing else does',
      (tester) async {
        BrawlDebug.openAnyDay = true;
        await mount(tester, wednesday);
        expect(door, findsOneWidget);
        BrawlDebug.openAnyDay = false;
        await mount(tester, wednesday);
        expect(door, findsNothing);
      },
    );

    testWidgets('a tap opens the versus screen over the house', (tester) async {
      await mount(tester, fogSaturday);
      await tester.tap(door);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(BrawlFlowScreen), findsOneWidget);
      expect(find.byKey(const Key('brawl-fight')), findsOneWidget);
      expect(find.text('SATURDAY BRAWL'), findsOneWidget);
    });

    testWidgets('the door has words for a screen reader and a 44 pt target', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await mount(tester, fogSaturday);
      expect(
        find.bySemanticsLabel(
          RegExp(r'Join the fight!\. The Fog is at the door'),
        ),
        findsOneWidget,
      );
      final size = tester.getSize(door);
      expect(size.height, greaterThanOrEqualTo(44));
      expect(size.width, greaterThanOrEqualTo(44));
      handle.dispose();
    });

    testWidgets('large text keeps the door whole', (tester) async {
      await mount(tester, fogSaturday, textScale: 2);
      expect(tester.takeException(), isNull);
      expect(door, findsOneWidget);
    });
  });

  group('the Me trophy case', () {
    Widget page(GameState state) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(393, 852),
          padding: EdgeInsets.only(bottom: 34),
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

    testWidgets('keeps what the weekends won', (tester) async {
      phone(tester);
      Clock.freeze(trollSaturday);
      final state = mikaState();
      state.recordBrawlWin(
        monster: BrawlMonster.troll,
        chest: BrawlChest.steady,
        loot: 'Porch Lantern',
        seconds: 41,
        now: trollSaturday,
      );
      await tester.pumpWidget(page(state));
      await tester.pump();
      await openMantelSheet(tester, 'trophy');
      expect(find.byKey(const Key('me-brawl-loot')), findsOneWidget);
      expect(find.text('WEEKEND LOOT'), findsOneWidget);
      expect(find.text('Porch Lantern'), findsOneWidget);
      expect(find.text('Couch Troll · Steady chest'), findsOneWidget);
    });

    testWidgets('invites the first win while the case is empty', (
      tester,
    ) async {
      phone(tester);
      Clock.freeze(trollSaturday);
      await tester.pumpWidget(page(mikaState()));
      await tester.pump();
      await openMantelSheet(tester, 'trophy');
      expect(find.byKey(const Key('me-brawl-loot')), findsOneWidget);
      expect(
        find.textContaining('Win it on a Saturday or Sunday'),
        findsOneWidget,
      );
    });
  });
}
