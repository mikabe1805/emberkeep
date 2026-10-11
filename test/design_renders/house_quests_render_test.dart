// Renders the Quests room on a day with no classes: Saturday 10 October, the
// Doorway holding Today's three, through the real app at iPhone size (393 x
// 852 at 3x, PNGs 1179 x 2556). Skipped unless asked for:
//
//   flutter test --dart-define=QUEST_RENDERS=true \
//     test/design_renders/house_quests_render_test.dart
//
// Output: design/comparisons/2026-10-10/house-rooms/quests/ in the
// class-day-journey checkout. A sheet script puts the frames beside the
// prototype's own v4 frames.
import 'dart:convert';

import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart'
    show CivilDate;
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/day_planning.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/class_day/doorway_art.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('QUEST_RENDERS');
const _only = String.fromEnvironment('QUEST_ONLY');
const _seed = int.fromEnvironment('QUEST_SEED', defaultValue: 20261003);
bool _wants(String name) =>
    _only.isEmpty || _only.split(',').map((s) => s.trim()).contains(name);

const _out = String.fromEnvironment(
  'QUEST_OUT',
  defaultValue:
      'C:/Users/mikus/Downloads/experimentProject/app/.worktrees/class-day-journey/'
      'design/comparisons/2026-10-10/house-rooms/quests',
);

final _at = DateTime(2026, 10, 10, 11, 0);
final _schedule = mikaSchedule();

List<String> get _housePlates => {
  for (final set in [
    HousePlateSets.me,
    HousePlateSets.goals,
    HousePlateSets.plansDay,
    HousePlateSets.plansMonth,
    HousePlateSets.journal,
  ])
    ...set.all,
}.toList();

/// Saturday, with [chosen] as Today's three (none: not chosen yet).
Future<void> _boot(WidgetTester tester, {bool chosen = true}) async {
  final account = mikaAccount(renderAt: _at);
  account.quests
    ..add(Quest(title: 'Review one problem', stat: Stat.foc, difficulty: 3))
    ..add(Quest(title: 'Write for today', stat: Stat.dis, difficulty: 2));
  // His last active day's three are not today's: today starts unchosen.
  if (chosen) {
    applyDailyField(account.quests, _at, const [
      'Read ten pages',
      'Review one problem',
      'Write for today',
    ]);
  }
  // Six weeks of classes attended (the term began 1 September): the shelf
  // stands as in the prototype, and this week's pairs are tied in a bundle.
  // Kept on a state of their own and written into the save as day records, so
  // the account's XP, streak and ranks stay as they were.
  final seed = GameState();
  var day = CivilDate(2026, 9, 1);
  while (day.compareTo(CivilDate(2026, 10, 10)) < 0) {
    final projected = projectClassDay(
      _schedule,
      DateTime(day.year, day.month, day.day, 23),
      day: day,
    );
    for (final entry in projected.classes) {
      Clock.freeze(entry.endsAt.add(const Duration(minutes: 5)).toLocal());
      seed.keepClass(
        entry.facts,
        at: entry.endsAt.add(const Duration(minutes: 5)),
        dayClassKeys: [for (final c in projected.classes) c.facts.identity],
      );
    }
    day = day.addDays(1);
  }
  final records = seed.toJson()['dayRecords'];
  Clock.freeze(_at);
  await bootRoom(
    tester,
    _Seeded(account, records),
    schedule: _schedule,
    precache: [...RoomArt.everyday, ..._housePlates],
  );
  final context = tester.element(find.byType(MaterialApp).first);
  await tester.runAsync(() async {
    for (final asset in DoorwayAssets.all) {
      await precacheImage(DoorwayAssets.providerFor(asset), context);
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _pump(WidgetTester tester, int ms) async {
  var t = 0;
  while (t < ms) {
    final step = (ms - t) < 17 ? (ms - t) : 17;
    await tester.pump(Duration(milliseconds: step));
    t += step;
  }
}

Future<void> _mark(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('class-there-button')).hitTestable());
  await tester.pump();
}

/// Keeps Today's three and waits for the day card to settle.
Future<void> _keepThree(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await _mark(tester);
    await _pump(tester, i == 2 ? 100 : 3600);
  }
  final card = find.byKey(const Key('class-kept-celebration'));
  for (var t = 0; t < 12000 && card.evaluate().isEmpty; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await _pump(tester, 2800);
}

class _Seeded extends MikaAccount {
  _Seeded(MikaAccount from, this.records)
    : super(from.state, from.quests, lastActive: from.lastActive);

  final Object? records;

  @override
  String encodeSave() {
    final save = jsonDecode(super.encodeSave()) as Map<String, dynamic>;
    (save['state'] as Map<String, dynamic>)['dayRecords'] = records;
    return jsonEncode(save);
  }
}

void main() {
  setUpAll(() {
    QuestsPage.debugLegacyBoard = false;
    return setUpRoomRenders(randomSeed: _seed);
  });
  tearDownAll(tearDownRoomRenders);
  final sheet = FrameSheet(_out);
  tearDownAll(() {
    if (_renders) sheet.writeManifest();
  });

  roomRenderTest('Saturday with three', skip: !_renders, (tester) async {
    if (!_wants('three')) return;
    await _boot(tester);
    await sheet.shot(
      tester,
      'Q1_sat_three',
      at: _at,
      surface: 'QUESTS',
      note: 'Today\'s three on the rail, the first leads the glass',
    );
    await _mark(tester);
    await _pump(tester, 260);
    await sheet.shot(
      tester,
      'Q2a_mark_lift',
      at: _at,
      surface: 'QUESTS',
      note: 'MARK COMPLETE, 260 ms: the ticket lifts',
    );
    await _pump(tester, 340);
    await sheet.shot(
      tester,
      'Q2b_mark_flip',
      at: _at,
      surface: 'QUESTS',
      note: '600 ms: flip and stamp',
    );
    await _pump(tester, 700);
    await sheet.shot(
      tester,
      'Q2c_mark_hang',
      at: _at,
      surface: 'QUESTS',
      note: '1300 ms: the ticket hangs and swings',
    );
    await _pump(tester, 2800);
    await sheet.shot(
      tester,
      'Q3_sat_after_mark',
      at: _at,
      surface: 'QUESTS',
      note: 'one kept: the next quest leads, Undo waits',
    );
    await _mark(tester);
    await _pump(tester, 3600);
    await sheet.shot(
      tester,
      'Q4_two_kept',
      at: _at,
      surface: 'QUESTS',
      note: 'two kept, the third leads',
    );
    await _mark(tester);
    await _pump(tester, 1900);
    await sheet.shot(
      tester,
      'Q5a_all_hung',
      at: _at,
      surface: 'QUESTS',
      note: 'the third hangs, the bowl waits',
    );
    await _pump(tester, 900);
    await sheet.shot(
      tester,
      'Q5b_all_drop',
      at: _at,
      surface: 'QUESTS',
      note: 'the tickets drop into the bowl',
    );
    // The tickets have landed in the bowl; the day's card follows (about
    // 500 ms after the landing) and holds for a tap.
    await _pump(tester, 800);
    await sheet.shot(
      tester,
      'Q5c_day_card_in',
      at: _at,
      surface: 'QUESTS',
      note: 'the day card arrives over the Doorway',
    );
    await _pump(tester, 900);
    await sheet.shot(
      tester,
      'Q5d_day_card_mid',
      at: _at,
      surface: 'QUESTS',
      note: 'the day card, 1.2 s in',
    );
    await _pump(tester, 1700);
    await sheet.shot(
      tester,
      'Q5e_day_card',
      at: _at,
      surface: 'QUESTS',
      note: 'SATURDAY, DONE. settled, held for a tap',
    );
    await tester.tapAt(const Offset(196, 426));
    await _pump(tester, 900);
    await sheet.shot(
      tester,
      'Q5f_all_kept',
      at: _at,
      surface: 'QUESTS',
      note: 'closed: the day is enough, CLOSE THE DAY',
    );
  });

  roomRenderTest('Saturday, the day card at larger text', skip: !_renders, (
    tester,
  ) async {
    if (!_wants('cardtext')) return;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _boot(tester);
    await _keepThree(tester);
    await sheet.shot(
      tester,
      'Q10_day_card_130',
      at: _at,
      surface: 'QUESTS',
      note: 'the day card at 130% text',
    );
  });

  roomRenderTest('Saturday, the day card at 200% text', skip: !_renders, (
    tester,
  ) async {
    if (!_wants('cardtext200')) return;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _boot(tester);
    await _keepThree(tester);
    await sheet.shot(
      tester,
      'Q11_day_card_200',
      at: _at,
      surface: 'QUESTS',
      note: 'the day card at 200% text',
    );
  });

  roomRenderTest('Saturday, the day card with Reduce Motion', skip: !_renders, (
    tester,
  ) async {
    if (!_wants('cardreduce')) return;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _boot(tester);
    await _keepThree(tester);
    await sheet.shot(
      tester,
      'Q12_day_card_reduce',
      at: _at,
      surface: 'QUESTS',
      note: 'the day card with Reduce Motion (a fade, no slam)',
    );
  });

  roomRenderTest('Saturday, three not chosen', skip: !_renders, (tester) async {
    if (!_wants('none')) return;
    await _boot(tester, chosen: false);
    await sheet.shot(
      tester,
      'Q6_sat_none',
      at: _at,
      surface: 'QUESTS',
      note: 'a quiet invitation',
    );
  });

  roomRenderTest('Saturday, the board', skip: !_renders, (tester) async {
    if (!_wants('board')) return;
    await _boot(tester);
    await tester.tap(find.byKey(const Key('quest-day-board')).hitTestable());
    await tester.pump();
    await _pump(tester, 900);
    await sheet.shot(
      tester,
      'Q7_sat_board',
      at: _at,
      surface: 'QUESTS',
      note: 'BOARD: the full board, with its line back to the room',
    );
  });

  roomRenderTest('Saturday, large text', skip: !_renders, (tester) async {
    if (!_wants('large')) return;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _boot(tester);
    await sheet.shot(
      tester,
      'Q8_sat_large_text',
      at: _at,
      surface: 'QUESTS',
      note: 'text at 160%',
    );
  });

  roomRenderTest('Saturday, Reduce Motion', skip: !_renders, (tester) async {
    if (!_wants('reduce')) return;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _boot(tester);
    await _mark(tester);
    await _pump(tester, 900);
    await sheet.shot(
      tester,
      'Q9_sat_reduce_motion',
      at: _at,
      surface: 'QUESTS',
      note: 'Reduce Motion: a cross-fade, then the hung ticket',
    );
  });
}
