// Renders every view that used to carry a hand-built honey-gold plate, so the
// 2026-10-09 gold sweep can be judged by eye (one lamp per view at most, the
// rest quiet). Skipped unless asked for:
//
//   flutter test --dart-define=CLASS_DAY_RENDERS=true \
//     --dart-define=GS_OUT=<absolute folder> \
//     test/design_renders/gold_sweep_render_test.dart
//
// Run it on the commit before the sweep and on the sweep to get the before
// and after of each frame (same names).
import 'dart:io';

import 'package:emberkeep/clock.dart';
import 'package:emberkeep/screens/me.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/screens/about.dart';
import 'package:emberkeep/widgets/lamplight.dart';
import 'package:emberkeep/widgets/share_moment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('CLASS_DAY_RENDERS');
const _outOverride = String.fromEnvironment('GS_OUT');
const _only = String.fromEnvironment('GS_ONLY');
bool _wants(String group) =>
    _only.isEmpty || _only.split(',').map((s) => s.trim()).contains(group);

final _schedule = mikaSchedule();
DateTime _at(int day, int hour, int minute) =>
    DateTime(2026, 10, day, hour, minute);

Finder _key(String value) => find.byKey(ValueKey(value));

Future<void> _show(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) return;
  if (finder.hitTestable().evaluate().isNotEmpty) return;
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await settle(tester, total: const Duration(milliseconds: 600));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _show(tester, finder);
  final target = finder.hitTestable().evaluate().isEmpty
      ? finder.first
      : finder.hitTestable().first;
  await tester.tap(target, warnIfMissed: false);
  await tester.pump();
  await settle(tester, total: const Duration(milliseconds: 900));
}

/// Scrolls a lazy page until [finder] is built, then centres it.
Future<void> _reach(WidgetTester tester, Finder scope, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      320,
      maxScrolls: 60,
      scrollable: find
          .descendant(of: scope, matching: find.byType(Scrollable))
          .first,
    );
  }
  await Scrollable.ensureVisible(tester.element(finder.first), alignment: 0.5);
  await tester.pump();
  await settle(tester, total: const Duration(milliseconds: 600));
}

Future<void> _boot(WidgetTester tester, {int day = 10}) async {
  final at = _at(day, 10, 40);
  final account = mikaAccount(renderAt: _at(day - 1, 21, 0));
  Clock.freeze(at);
  await bootRoom(
    tester,
    account,
    schedule: _schedule,
    precache: RoomArt.everyday,
  );
}

void main() {
  final out = _outOverride.isNotEmpty
      ? _outOverride
      : '${Directory.current.path.replaceAll(r'\', '/')}/design/comparisons/2026-10-09/cohesion/sweep';
  final sheet = FrameSheet(out);
  final at = _at(10, 10, 40);

  setUpAll(() async {
    await setUpRoomRenders();
    await LampVellum.load();
  });
  const zoneChannel = MethodChannel('flutter_timezone');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(zoneChannel, (call) async {
          return call.method == 'getLocalTimezone' ? 'America/New_York' : null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(zoneChannel, null);
  });
  tearDownAll(() {
    if (_renders) {
      sheet.writeManifest();
      File('${sheet.directory}/render-log.txt')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          '${RenderIssues.lines.map((l) => 'LAYOUT $l').join('\n')}\n',
        );
    }
    tearDownRoomRenders();
  });

  roomRenderTest(
    'G: Goals starting points and a quest row',
    skip: !_renders || !_wants('goals'),
    (tester) async {
      await _boot(tester);
      await precacheArt(tester, RoomArt.goals);
      await openTab(tester, RoomTab.goals);
      await precacheArt(tester, RoomArt.goals);
      await sheet.shot(
        tester,
        'G0_goals_top',
        at: at,
        surface: 'Goals, as it opens',
      );
      await _tap(tester, find.text('New goal'));
      await _tap(tester, find.text('READY-MADE ROUTES'));
      await settle(tester, total: const Duration(milliseconds: 1500));
      final toggles = find.byWidgetPredicate((w) {
        final k = w.key;
        return k is ValueKey<String> &&
            k.value.startsWith('goal-catalog-toggle-');
      });
      await tester.tap(toggles.first, warnIfMissed: false);
      await settle(tester, total: const Duration(milliseconds: 1200));
      await sheet.shot(
        tester,
        'G1_goals_starting_point_open',
        at: at,
        surface: 'Goals, starting points, one open',
      );
      final adopt = find.textContaining('ADOPT WHOLE GOAL');
      if (adopt.evaluate().isNotEmpty) {
        await Scrollable.ensureVisible(
          tester.element(adopt.first),
          alignment: 0.5,
        );
        await tester.pump();
        await settle(tester, total: const Duration(milliseconds: 800));
        await sheet.shot(
          tester,
          'G2_goals_starting_point_actions',
          at: at,
          surface: 'Goals, starting point actions',
        );
      }
    },
  );

  roomRenderTest(
    'P: Plans day sheet and the add-a-plan dialog',
    skip: !_renders || !_wants('plans'),
    (tester) async {
      await _boot(tester);
      await precacheArt(tester, RoomArt.plans);
      await openTab(tester, RoomTab.plans);
      await precacheArt(tester, RoomArt.plans);
      await settle(tester, total: const Duration(milliseconds: 1500));
      await sheet.shot(
        tester,
        'P1_plans_day',
        at: at,
        surface: 'Plans, a day selected',
      );
      await _tap(tester, find.text('DAY'));
      await sheet.shot(
        tester,
        'P1b_plans_day_view',
        at: at,
        surface: 'Plans, DAY view',
      );
      await _tap(tester, _key('calendar-plan-selected-day'));
      await settle(tester, total: const Duration(milliseconds: 800));
      await sheet.shot(
        tester,
        'P2_plans_plan_it_dialog',
        at: at,
        surface: 'Plans, the PLAN IT dialog',
      );
    },
  );

  roomRenderTest(
    'M: Me, share card and account dialogs',
    skip: !_renders || !_wants('me'),
    (tester) async {
      await _boot(tester);
      await precacheArt(tester, RoomArt.everyday);
      await openTab(tester, RoomTab.me);
      await precacheArt(tester, RoomArt.everyday);
      await settle(tester, total: const Duration(milliseconds: 1500));
      await sheet.shot(tester, 'M1_me_top', at: at, surface: 'Me, as it opens');
      final mePage = find.byType(MePage);
      final share = find.text('SHARE MY BUILD');
      await _reach(tester, mePage, share);
      await sheet.shot(
        tester,
        'M1b_me_share_build',
        at: at,
        surface: 'Me, share my build',
      );
      {
        await _tap(tester, share);
        await sheet.shot(
          tester,
          'M2_me_share_card',
          at: at,
          surface: 'Me, the share card',
        );
        await tester.tap(find.text('COPY TEXT').hitTestable().first);
        await tester.pump();
        await tester.tapAt(const Offset(8, 8));
        await settle(tester, total: const Duration(milliseconds: 600));
      }
      final restore = find.text('RESTORE');
      {
        await _reach(tester, mePage, restore);
        await _tap(tester, restore);
        await sheet.shot(
          tester,
          'M3_me_restore',
          at: at,
          surface: 'Me, restore a backup',
        );
        await tester.tapAt(const Offset(8, 8));
        await settle(tester, total: const Duration(milliseconds: 600));
      }
    },
  );

  roomRenderTest(
    'A: About and the share-a-moment card',
    skip: !_renders || !_wants('about'),
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: AboutScreen(reduceMotion: true),
        ),
      );
      await settle(tester, total: const Duration(milliseconds: 800));
      await sheet.shot(tester, 'A1_about_top', at: at, surface: 'About, top');
      final scroll = find.byType(Scrollable).first;
      await tester.drag(scroll, const Offset(0, -520), warnIfMissed: false);
      await settle(tester, total: const Duration(milliseconds: 800));
      await sheet.shot(
        tester,
        'A2_about_scrolled',
        at: at,
        surface: 'About, scrolled to support',
      );

      final state = GameState()
        ..onboarded = true
        ..setPlayerName('Alex')
        ..level = 18
        ..streakDays = 12
        ..totalCompletions = 158
        ..wallStyle = 'wall_walnut'
        ..roomCode = 'ABC234';
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFF14100D),
            body: ShareMomentSheet(state: state, level: 18),
          ),
        ),
      );
      await settle(tester, total: const Duration(milliseconds: 800));
      await sheet.shot(
        tester,
        'S1_share_moment',
        at: at,
        surface: 'Share this moment',
      );
    },
  );

  roomRenderTest(
    'J: Journal, an entry being written',
    skip: !_renders || !_wants('journal'),
    (tester) async {
      await _boot(tester);
      await precacheArt(tester, RoomArt.journal);
      await openTab(tester, RoomTab.journal);
      await precacheArt(tester, RoomArt.journal);
      await settle(tester, total: const Duration(milliseconds: 1500));
      await sheet.shot(
        tester,
        'J0_journal',
        at: at,
        surface: 'Journal, as it opens',
      );
      await _tap(tester, find.text('WRITE FOR TODAY'));
      await sheet.shot(
        tester,
        'J1_journal_entry_writing',
        at: at,
        surface: 'Journal entry, writing',
      );
      final field = find.byKey(const ValueKey('journal-entry-body'));
      if (field.evaluate().isNotEmpty) {
        await tester.enterText(
          field.first,
          'Walked after lunch even though the afternoon felt crowded.',
        );
        await tester.pump();
        await settle(tester, total: const Duration(milliseconds: 600));
        await sheet.shot(
          tester,
          'J2_journal_entry_typed',
          at: at,
          surface: 'Journal entry, with words',
        );
      }
    },
  );

  roomRenderTest(
    'Q: Quests board, tune sheet, log and the encore',
    skip: !_renders || !_wants('quests'),
    (tester) async {
      await _boot(tester);
      await openTab(tester, RoomTab.quests);
      await showQuestBoard(tester);
      await scrollToTop(tester, questBoard);
      await settle(tester, total: const Duration(milliseconds: 900));
      final action = find.byKey(const ValueKey('quest-primary-action'));
      await sheet.shot(tester, 'Q0_board', at: at, surface: 'Quests board');
      // Long-press the card: the manage sheet.
      await tester.longPress(action.first, warnIfMissed: false);
      await settle(tester, total: const Duration(milliseconds: 900));
      await sheet.shot(
        tester,
        'Q1_manage_sheet',
        at: at,
        surface: 'Quests, manage sheet',
      );
      final tune = find.text('Tune difficulty & stat');
      if (tune.evaluate().isNotEmpty) {
        await _tap(tester, tune);
        await sheet.shot(
          tester,
          'Q2_tune_dialog',
          at: at,
          surface: 'Quests, tune dialog',
        );
        await tester.tapAt(const Offset(8, 8));
        await settle(tester, total: const Duration(milliseconds: 600));
      }
      await tester.longPress(action.first, warnIfMissed: false);
      await settle(tester, total: const Duration(milliseconds: 900));
      final log = find.textContaining('log');
      // ignore: avoid_print
      print('LOG rows ${log.evaluate().length}');
      final logRow = find.text('Keep a note / log');
      if (logRow.evaluate().isNotEmpty) {
        await _tap(tester, logRow);
        await sheet.shot(
          tester,
          'Q3_notes_sheet',
          at: at,
          surface: 'Quests, the quest log',
        );
        await tester.tapAt(const Offset(8, 8));
        await settle(tester, total: const Duration(milliseconds: 600));
      }
    },
  );

  roomRenderTest(
    'E: the encore sheet after a completion',
    skip: !_renders || !_wants('encore'),
    (tester) async {
      await _boot(tester);
      await openTab(tester, RoomTab.quests);
      await showQuestBoard(tester);
      await scrollToTop(tester, questBoard);
      await settle(tester, total: const Duration(milliseconds: 900));
      final action = find.byKey(const ValueKey('quest-primary-action'));
      await tester.tap(action.first, warnIfMissed: false);
      await settle(tester, total: const Duration(milliseconds: 5000));
      await sheet.shot(
        tester,
        'E0_after_complete',
        at: at,
        surface: 'Quests, after completing',
      );
      final bolt = find.byIcon(Icons.bolt);
      // ignore: avoid_print
      print('BOLT ${bolt.evaluate().length}');
      if (bolt.evaluate().isNotEmpty) {
        await _tap(tester, bolt.first);
        await sheet.shot(
          tester,
          'E1_encore_sheet',
          at: at,
          surface: 'Quests, the encore sheet',
        );
      }
    },
  );
}
