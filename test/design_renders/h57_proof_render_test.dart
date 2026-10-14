// Proof made easy, through the real app (the shell, the HUD and the dock) at
// 393 x 852 and 3x (PNGs 1179 x 2556): the timer offered on a Quest, started
// with one tap, kept running over every room, finished from the finish moment,
// and the receipt that says so. Skipped unless asked for:
//
//   flutter test --dart-define=H57_PROOF=true \
//     test/design_renders/h57_proof_render_test.dart
//
// H57_ONLY=offer,running,rooms,finish,text picks groups; H57_OUT=<folder>
// writes somewhere else. Output: design/comparisons/2026-10-14/h57-proof/ in
// this checkout.
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/day_planning.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/quests.dart' show QuestsPage;
import 'package:emberkeep/tokens.dart' show Stat;
import 'package:emberkeep/widgets/class_day/doorway_art.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('H57_PROOF');
const _only = String.fromEnvironment('H57_ONLY');
bool _wants(String name) =>
    _only.isEmpty || _only.split(',').map((s) => s.trim()).contains(name);

const _out = String.fromEnvironment(
  'H57_OUT',
  defaultValue:
      'C:/Users/mikus/Downloads/experimentProject/app/.worktrees/house-journal/'
      'design/comparisons/2026-10-14/h57-proof',
);

DateTime _at(int day, int hour, int minute) =>
    DateTime(2026, 10, day, hour, minute);

final _schedule = mikaSchedule();

List<String> get _plates => {
  for (final set in [
    HousePlateSets.me,
    HousePlateSets.goals,
    HousePlateSets.plansDay,
    HousePlateSets.plansMonth,
    HousePlateSets.journal,
  ])
    ...set.all,
}.toList();

Future<void> _boot(
  WidgetTester tester,
  DateTime at, {
  bool chosen = true,
  bool reminders = false,
  List<String> field = const [
    'Read ten pages',
    'Review one problem',
    'Write for today',
  ],
}) async {
  final account = mikaAccount(renderAt: at);
  account.state.musicEnabled = false;
  account.state.notifyEnabled = reminders;
  if (chosen) {
    account.quests
      ..add(Quest(title: 'Practice guitar', stat: Stat.foc, difficulty: 2))
      ..add(Quest(title: 'Review one problem', stat: Stat.foc, difficulty: 3))
      ..add(Quest(title: 'Write for today', stat: Stat.dis, difficulty: 2));
    applyDailyField(account.quests, at, field);
  }
  Clock.freeze(at);
  await bootRoom(
    tester,
    account,
    schedule: _schedule,
    precache: [...RoomArt.everyday, ..._plates],
  );
  final context = tester.element(find.byType(MaterialApp).first);
  await tester.runAsync(() async {
    for (final asset in DoorwayAssets.all) {
      await precacheImage(DoorwayAssets.providerFor(asset), context);
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
  await tester.pump(const Duration(milliseconds: 200));
  await settle(tester, total: const Duration(milliseconds: 2800));
}

/// ALL QUESTS from the Doorway's card.
Future<void> _toBoard(WidgetTester tester) async {
  final toggle = find.byKey(const Key('class-day-toggle-board')).hitTestable();
  final quest = find.byKey(const Key('quest-day-board')).hitTestable();
  await tester.tap(toggle.evaluate().isNotEmpty ? toggle.first : quest.first);
  await tester.pump();
  await settle(tester, total: const Duration(milliseconds: 1400));
}

final Finder _offer = find.byKey(
  const ValueKey('quest-timer-offer-Read ten pages'),
);
final Finder _running = find.byKey(
  const ValueKey('quest-timer-running-Read ten pages'),
);

void main() {
  setUpAll(setUpRoomRenders);
  tearDownAll(tearDownRoomRenders);
  // The test config keeps the old board for the old tests; the room is real,
  // and the timer asks "Time it?" as it does on a phone.
  setUp(() {
    QuestsPage.debugLegacyBoard = false;
    QuestsPage.debugAskTimerOnMark = true;
  });
  tearDown(() {
    QuestsPage.debugLegacyBoard = true;
    QuestsPage.debugAskTimerOnMark = false;
  });
  final sheet = FrameSheet(_out);
  tearDownAll(() {
    if (_renders) sheet.writeManifest();
  });

  roomRenderTest('the offer on a Saturday', skip: !_renders, (tester) async {
    if (!_wants('offer')) return;
    final at = _at(10, 11, 0);
    await _boot(tester, at);
    expect(_offer, findsOneWidget);
    await sheet.shot(
      tester,
      'A_doorway_offer',
      at: at,
      surface: 'QUESTS',
      note: 'Saturday, Today\'s three: Read ten pages leads, with the timer',
    );
    await _toBoard(tester);
    await sheet.shot(
      tester,
      'A_board_offer',
      at: at,
      surface: 'QUESTS',
      note: 'the board: the leading card offers it in words, rows as a button',
    );
    await tester.drag(
      find.byKey(const ValueKey('quest-board-scroll')),
      const Offset(0, -260),
      warnIfMissed: false,
    );
    await settle(tester, total: const Duration(milliseconds: 900));
    await sheet.shot(
      tester,
      'A_board_offer_rows',
      at: at,
      surface: 'QUESTS',
      note:
          'the board scrolled: the rows that fit a timer wear the round button',
    );
  });

  roomRenderTest('rows wear the round button', skip: !_renders, (tester) async {
    if (!_wants('rows')) return;
    final at = _at(10, 11, 0);
    await _boot(
      tester,
      at,
      field: const ['Review one problem', 'Practice guitar', 'Read ten pages'],
    );
    await _toBoard(tester);
    await sheet.shot(
      tester,
      'F_board_rows',
      at: at,
      surface: 'QUESTS',
      note: 'the board: rows that fit a timer carry a small round button',
    );
    await tester.tap(
      find
          .byKey(const ValueKey('quest-timer-offer-Practice guitar'))
          .hitTestable(),
    );
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 600));
    await tester.ensureVisible(find.byKey(const Key('timer-back')));
    await tester.tap(find.byKey(const Key('timer-back')));
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 900));
    await sheet.shot(
      tester,
      'F_board_rows_running',
      at: at,
      surface: 'QUESTS',
      note: 'the same row while its timer runs: the clock beside the button',
    );
  });

  roomRenderTest('Plans offers it', skip: !_renders, (tester) async {
    if (!_wants('offer')) return;
    final at = _at(10, 11, 0);
    await _boot(tester, at);
    await openTab(tester, RoomTab.plans);
    await settle(tester, total: const Duration(milliseconds: 900));
    await sheet.shot(
      tester,
      'A_plans_offer',
      at: at,
      surface: 'PLANS',
      note: 'Plans, day: a chosen reading Quest carries the offer',
    );
  });

  roomRenderTest('mark asks, start, run, leave', skip: !_renders, (
    tester,
  ) async {
    if (!_wants('running')) return;
    final at = _at(10, 11, 0);
    await _boot(tester, at, reminders: true);

    // MARK COMPLETE asks "Time it?" first.
    await tester.tap(find.text('MARK COMPLETE').hitTestable());
    await settle(tester, total: const Duration(milliseconds: 900));
    await sheet.shot(
      tester,
      'B_time_it',
      at: at,
      surface: 'QUESTS',
      note: 'MARK COMPLETE on Read ten pages asks, never gates',
    );
    await tester.tap(find.byKey(const Key('quest-timer-sheet-start')));
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 900));
    await sheet.shot(
      tester,
      'B_running_overlay',
      at: at,
      surface: 'QUESTS',
      note: 'the timer running, opened by the one tap',
    );

    // Ten minutes in, leave to the house.
    Clock.freeze(at.add(const Duration(minutes: 10, seconds: 12)));
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.byKey(const Key('timer-back')));
    await tester.tap(find.byKey(const Key('timer-back')));
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 900));
    await sheet.shot(
      tester,
      'B_doorway_running',
      at: at,
      surface: 'QUESTS',
      note: 'back in the house: the card and the pill say 9:48 left',
    );
    for (final (tab, name) in [
      (RoomTab.plans, 'plans'),
      (RoomTab.journal, 'journal'),
      (RoomTab.goals, 'goals'),
      (RoomTab.me, 'me'),
    ]) {
      await openTab(tester, tab);
      await settle(tester, total: const Duration(milliseconds: 700));
      await sheet.shot(
        tester,
        'C_pill_$name',
        at: at,
        surface: tab.label,
        note: 'the running timer over ${tab.label}',
      );
    }
    await openTab(tester, RoomTab.quests);
  });

  roomRenderTest('it ends in another room', skip: !_renders, (tester) async {
    if (!_wants('finish')) return;
    final at = _at(10, 11, 0);
    await _boot(tester, at);
    await tester.tap(_offer);
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 600));
    await tester.ensureVisible(find.byKey(const Key('timer-back')));
    await tester.tap(find.byKey(const Key('timer-back')));
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 600));
    await openTab(tester, RoomTab.plans);

    // Twenty-one minutes on, in Plans.
    final later = at.add(const Duration(minutes: 21));
    Clock.freeze(later);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester, total: const Duration(milliseconds: 900));
    await sheet.shot(
      tester,
      'D_finish_moment',
      at: later,
      surface: 'PLANS',
      note: 'the timer ended while he was in Plans',
    );
    await tester.tap(find.byKey(const Key('quest-timer-finish')));
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 1300));
    await sheet.shot(
      tester,
      'D_receipt',
      at: later,
      surface: 'QUESTS',
      note: 'finished through the timer: the receipt says Timed',
    );
    await settle(tester, total: const Duration(milliseconds: 5000));
    await sheet.shot(
      tester,
      'D_after',
      at: later,
      surface: 'QUESTS',
      note: 'after the receipt: no pill, the card done',
    );
  });

  roomRenderTest('the offer at larger text', skip: !_renders, (tester) async {
    if (!_wants('text')) return;
    for (final scale in [1.3, 2.0]) {
      final label = (scale * 100).round();
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final at = _at(10, 11, 0);
      await _boot(tester, at);
      await sheet.shot(
        tester,
        'E_doorway_offer_$label',
        at: at,
        surface: 'QUESTS',
        note: 'the Doorway card with the offer at $label% text',
      );
      await _toBoard(tester);
      await sheet.shot(
        tester,
        'E_board_offer_$label',
        at: at,
        surface: 'QUESTS',
        note: 'the board with the offer at $label% text',
      );
      await tester.tap(_offer.hitTestable().first);
      await tester.pump();
      await settle(tester, total: const Duration(milliseconds: 600));
      await tester.ensureVisible(find.byKey(const Key('timer-back')));
      await tester.tap(find.byKey(const Key('timer-back')));
      await tester.pump();
      await settle(tester, total: const Duration(milliseconds: 600));
      await sheet.shot(
        tester,
        'E_pill_$label',
        at: at,
        surface: 'QUESTS',
        note: 'the pill at $label% text',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
    expect(_running, findsNothing);
  });
}
