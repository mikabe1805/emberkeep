// Renders for the fixes after build 55 (2026-10-12), through the real app at
// iPhone size (393 x 852 at 3x, PNGs 1179 x 2556):
//
//   * Plans, the day: today with its chosen Quests, one finished from the ring
//     (the reward in flight, then done), another day's page (Sunday, seen on
//     Monday) with its label and its BACK TO TODAY, a Quest finished from that
//     page, and a book left on yesterday's page that opens on today;
//   * the Journal's reading view: the saved line, Add to Keepsakes and In
//     Keepsakes, at 100%, 130% and 200% text.
//
// Skipped unless asked for:
//
//   flutter test --dart-define=H56_RENDERS=true \
//     test/design_renders/h56_plans_journal_render_test.dart
//
// H56_ONLY=plans,sunday,stale,journal,large picks tests. Output:
// design/comparisons/2026-10-12/h56-plans-journal/ in this checkout.
//
// The pages in the Journal frames are invented for the render; no real writing
// is used.
import 'dart:io';

import 'package:emberkeep/clock.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/journal_hub.dart' show JournalHubScreen;
import 'package:emberkeep/screens/quests.dart' show QuestsPage;
import 'package:emberkeep/tokens.dart' show Stat;
import 'package:emberkeep/widgets/class_day/doorway_art.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('H56_RENDERS');
const _only = String.fromEnvironment('H56_ONLY');

/// Added to every frame's name, so a run on the build-55 code (the 'before')
/// sits beside a run on this code in one folder.
const _suffix = String.fromEnvironment('H56_SUFFIX');
bool _wants(String name) =>
    _only.isEmpty || _only.split(',').map((s) => s.trim()).contains(name);

String get _out =>
    '${Directory.current.path.replaceAll(r'\', '/')}'
    '/design/comparisons/2026-10-12/h56-plans-journal';

/// Monday 12 October, 11:42: when the owner took his screenshot.
final _monday = DateTime(2026, 10, 12, 11, 42);

const _mondaysThree = [
  'Read ten pages',
  'Walk after lunch',
  'Message someone I miss',
];
const _sundaysThree = ['Clear the sink', 'Do 5 push-ups', 'Morning skincare'];

final _schedule = mikaSchedule();

List<String> get _plates => {
  for (final set in [
    HousePlateSets.me,
    HousePlateSets.goals,
    HousePlateSets.plansDay,
    HousePlateSets.plansMonth,
    HousePlateSets.plansWeek,
    HousePlateSets.journal,
  ])
    ...set.all,
}.toList();

/// Pages written for the render (not his).
List<Note> _pages(DateTime now) => [
  Note(
    at: now.subtract(const Duration(minutes: 3)),
    text:
        'Walked home the long way. The light on the river was good and I '
        'noticed I was not rushing.',
    context: 'Homey Homesteader',
  ),
  Note(
    at: DateTime(2026, 10, 9, 21, 5),
    text: 'A short one tonight. The week felt smaller than I planned.',
    context: 'Homey Homesteader',
    editedAt: DateTime(2026, 10, 9, 21, 20),
  ),
  Note(
    at: DateTime(2026, 10, 4, 20, 40),
    text: 'Cooked for the first time in a while.',
    context: 'Homey Homesteader',
  ),
];

Future<void> _boot(
  WidgetTester tester, {
  DateTime? at,
  bool journal = false,
  Map<String, Object> prefs = const {},
  double text = 1,
}) async {
  tester.platformDispatcher.textScaleFactorTestValue = text;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final now = at ?? _monday;
  final account = mikaAccount(renderAt: now, withJournal: false);
  account.quests
    ..clear()
    ..addAll([
      for (final (i, title) in [..._mondaysThree, ..._sundaysThree].indexed)
        Quest(
          title: title,
          stat: Stat.values[i % Stat.values.length],
          difficulty: 2 + i % 3,
        ),
    ]);
  for (final (i, title) in _mondaysThree.indexed) {
    account.quests.firstWhere((q) => q.title == title)
      ..priorityDay = Days.key(now)
      ..priorityRank = i + 1;
  }
  for (final (i, title) in _sundaysThree.indexed) {
    account.quests.firstWhere((q) => q.title == title)
      ..priorityDay = Days.key(now.subtract(const Duration(days: 1)))
      ..priorityRank = i + 1;
  }
  if (journal) account.state.setJournal(_pages(now));
  Clock.freeze(now);
  await bootRoom(
    tester,
    account,
    schedule: _schedule,
    extraPrefs: prefs,
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
}

/// Monday's book turned one page back, to Sunday (the left page then lists
/// the week before, Monday the 5th to Sunday the 11th).
Future<void> _toSunday(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
  await tester.pump();
  await settle(tester, total: const Duration(milliseconds: 1200));
}

Future<void> _mode(WidgetTester tester, String mode) async {
  await tester.tap(find.byKey(ValueKey('academic-mode-$mode')));
  await tester.pump();
  await settle(tester, total: const Duration(milliseconds: 900));
}

Finder _ring(String title) => find.byKey(ValueKey('quest-plan-toggle-$title'));

Future<void> _tapRing(WidgetTester tester, String title) async {
  final ring = _ring(title);
  await tester.ensureVisible(ring);
  await tester.pump();
  await tester.tap(ring);
}

/// The day list on the right page, scrolled so a quest row is on the page.
Future<void> _showRow(WidgetTester tester, String title) async {
  final list = find.descendant(
    of: find.byKey(const ValueKey('plans-day-list')),
    matching: find.byType(Scrollable),
  );
  if (_ring(title).hitTestable().evaluate().isNotEmpty) return;
  await tester.scrollUntilVisible(_ring(title), 120, scrollable: list);
  await settle(tester, total: const Duration(milliseconds: 400));
}

void main() {
  setUpAll(setUpRoomRenders);
  tearDownAll(tearDownRoomRenders);
  setUp(() => QuestsPage.debugLegacyBoard = false);
  tearDown(() => QuestsPage.debugLegacyBoard = true);
  final sheet = FrameSheet(_out);
  tearDownAll(() {
    if (_renders) sheet.writeManifest();
  });

  roomRenderTest(
    'Plans, today: a Quest finished from its ring',
    skip: !_renders,
    (tester) async {
      if (!_wants('plans')) return;
      await _boot(tester);
      await openTab(tester, RoomTab.plans);
      await settle(tester, total: const Duration(milliseconds: 900));
      await sheet.shot(
        tester,
        'P_today_open$_suffix',
        at: _monday,
        surface: 'PLANS',
        note: 'Monday 11:42, DAY: today with its three chosen Quests',
      );
      await _showRow(tester, 'Walk after lunch');
      await sheet.shot(
        tester,
        'P_today_rows$_suffix',
        at: _monday,
        surface: 'PLANS',
        note: 'the day list scrolled to the Quests',
      );
      final before = liveState(tester).totalXp;
      await _tapRing(tester, 'Walk after lunch');
      await tester.pump(const Duration(milliseconds: 260));
      await sheet.shot(
        tester,
        'P_today_flight$_suffix',
        at: _monday,
        surface: 'PLANS',
        note: 'the ring tapped: the reward leaves it for the XP',
      );
      await settle(tester, total: const Duration(milliseconds: 2400));
      await sheet.shot(
        tester,
        'P_today_receipt$_suffix',
        at: _monday,
        surface: 'PLANS',
        note: 'the Quests page\'s reward moment, over Plans: the receipt',
      );
      await settle(tester, total: const Duration(milliseconds: 6000));
      await sheet.shot(
        tester,
        'P_today_done$_suffix',
        at: _monday,
        surface: 'PLANS',
        note: 'settled: the ring gold, the title struck, the XP up',
      );
      expect(liveState(tester).totalXp, greaterThan(before));
      expect(
        liveQuests(
          tester,
        ).firstWhere((q) => q.title == 'Walk after lunch').doneFor(_monday),
        isTrue,
      );
    },
  );

  roomRenderTest('Plans, Sunday seen on Monday', skip: !_renders, (
    tester,
  ) async {
    if (!_wants('sunday')) return;
    await _boot(tester);
    await openTab(tester, RoomTab.plans);
    await settle(tester, total: const Duration(milliseconds: 900));
    await _toSunday(tester);
    await sheet.shot(
      tester,
      'P_sunday_open$_suffix',
      at: _monday,
      surface: 'PLANS',
      note: 'Sunday: FOCUS, CHOSEN FOR SUN, and BACK TO TODAY on the page',
    );
    await _showRow(tester, 'Do 5 push-ups');
    await _tapRing(tester, 'Do 5 push-ups');
    await tester.pump(const Duration(milliseconds: 260));
    await settle(tester, total: const Duration(milliseconds: 2400));
    await sheet.shot(
      tester,
      'P_sunday_receipt$_suffix',
      at: _monday,
      surface: 'PLANS',
      note: 'finished from Sunday\'s page: the receipt says where the undo is',
    );
    await settle(tester, total: const Duration(milliseconds: 6000));
    await sheet.shot(
      tester,
      'P_sunday_done$_suffix',
      at: _monday,
      surface: 'PLANS',
      note: 'it counts today: DONE TODAY, the ring gold, the title struck',
    );
    expect(
      liveQuests(
        tester,
      ).firstWhere((q) => q.title == 'Do 5 push-ups').lastDoneDay,
      '2026-10-12',
    );
    await tester.tap(find.byKey(const ValueKey('calendar-back-to-today')));
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 1200));
    await sheet.shot(
      tester,
      'P_back_today$_suffix',
      at: _monday,
      surface: 'PLANS',
      note: 'BACK TO TODAY tapped',
    );
  });

  roomRenderTest(
    'Plans, a book left on yesterday opens on today',
    skip: !_renders,
    (tester) async {
      if (!_wants('stale')) return;
      await _boot(
        tester,
        prefs: const {
          // What build 55 left on his phone: DAY, Sunday, no day stamp.
          'room_of_days_academic_calendar_mode_v1': 'day',
          'room_of_days_academic_calendar_date_v1': '2026-10-11',
        },
      );
      await openTab(tester, RoomTab.plans);
      await settle(tester, total: const Duration(milliseconds: 1200));
      await sheet.shot(
        tester,
        'P_stale_opens_today$_suffix',
        at: _monday,
        surface: 'PLANS',
        note: 'a Sunday saved by build 55: Plans opens on Monday, in DAY',
      );
      expect(find.text('Today'), findsOneWidget);
    },
  );

  roomRenderTest('Journal, the reading view', skip: !_renders, (tester) async {
    if (!_wants('journal')) return;
    await _boot(tester, journal: true);
    await openTab(tester, RoomTab.journal);
    await settle(tester, total: const Duration(milliseconds: 900));
    final first = liveState(tester).journal.first;
    await sheet.shot(
      tester,
      'J_nook$_suffix',
      at: _monday,
      surface: 'JOURNAL',
      note: 'the nook: the last pages, and ALL for every page',
    );
    await tester.tap(find.byKey(const ValueKey('journal-nook-all')));
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 1000));
    await sheet.shot(
      tester,
      'J_all_list$_suffix',
      at: _monday,
      surface: 'JOURNAL',
      note: 'ALL: every page, newest first',
    );
    Navigator.of(tester.element(find.byType(JournalHubScreen))).pop();
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 800));
    await tester.tap(find.byKey(ValueKey('journal-nook-entry-${first.id}')));
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 1000));
    await sheet.shot(
      tester,
      'J_read_top$_suffix',
      at: _monday,
      surface: 'JOURNAL',
      note: 'a page opened from the nook: saved, and Add to Keepsakes',
    );
    await tester.tap(find.byKey(const ValueKey('journal-entry-keepsake')));
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 600));
    await sheet.shot(
      tester,
      'J_read_kept$_suffix',
      at: _monday,
      surface: 'JOURNAL',
      note: 'added: In Keepsakes (tap again to take it off the shelf)',
    );
    expect(find.text('In Keepsakes'), findsOneWidget);
  });

  roomRenderTest('Journal, a page opened from Plans', skip: !_renders, (
    tester,
  ) async {
    if (!_wants('journal')) return;
    await _boot(tester, journal: true);
    await openTab(tester, RoomTab.plans);
    await settle(tester, total: const Duration(milliseconds: 900));
    final first = liveState(tester).journal.first;
    final line = find.byKey(ValueKey('calendar-journal-entry-${first.id}'));
    final list = find.descendant(
      of: find.byKey(const ValueKey('plans-day-list')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(line, 120, scrollable: list);
    await tester.ensureVisible(line);
    await settle(tester, total: const Duration(milliseconds: 400));
    await tester.tap(line);
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 1000));
    await sheet.shot(
      tester,
      'J_read_from_plans$_suffix',
      at: _monday,
      surface: 'JOURNAL',
      note: 'opened from Plans: a longer heading, Add to Keepsakes below it',
    );
  });

  for (final scale in const [1.3, 2.0]) {
    final label = (scale * 100).round();
    roomRenderTest('Journal reading view at $label% text', skip: !_renders, (
      tester,
    ) async {
      if (!_wants('large')) return;
      await _boot(tester, journal: true, text: scale);
      await openTab(tester, RoomTab.journal);
      await settle(tester, total: const Duration(milliseconds: 900));
      final first = liveState(tester).journal.first;
      // Through ALL, the way a page is found again.
      await tester.tap(find.byKey(const ValueKey('journal-nook-all')));
      await tester.pump();
      await settle(tester, total: const Duration(milliseconds: 1000));
      final card = find.byKey(ValueKey('journal-card-${first.id}'));
      await tester.scrollUntilVisible(
        card,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(card);
      await settle(tester, total: const Duration(milliseconds: 400));
      await tester.tap(card);
      await tester.pump();
      await settle(tester, total: const Duration(milliseconds: 1000));
      await sheet.shot(
        tester,
        'J_read_$label$_suffix',
        at: _monday,
        surface: 'JOURNAL',
        note: 'reading view, $label% text',
      );
    });
  }

  roomRenderTest(
    'Plans at 130% text: the way back stays reachable',
    skip: !_renders,
    (tester) async {
      if (!_wants('large')) return;
      await _boot(tester, text: 1.3);
      await openTab(tester, RoomTab.plans);
      await settle(tester, total: const Duration(milliseconds: 900));
      await _toSunday(tester);
      await sheet.shot(
        tester,
        'P_sunday_130$_suffix',
        at: _monday,
        surface: 'PLANS',
        note: 'Sunday at 130% text: BACK TO TODAY comes first under the arrows',
      );
    },
  );

  roomRenderTest('Plans, WEEK and MONTH away from today', skip: !_renders, (
    tester,
  ) async {
    if (!_wants('views')) return;
    await _boot(tester);
    await openTab(tester, RoomTab.plans);
    await settle(tester, total: const Duration(milliseconds: 900));
    await _toSunday(tester);
    await _mode(tester, 'week');
    await sheet.shot(
      tester,
      'P_week_back$_suffix',
      at: _monday,
      surface: 'PLANS',
      note: 'WEEK, last week: BACK TO TODAY on the week plate',
    );
    await _mode(tester, 'month');
    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 1200));
    await sheet.shot(
      tester,
      'P_month_back$_suffix',
      at: _monday,
      surface: 'PLANS',
      note: 'MONTH, September: BACK TO TODAY on the month plate',
    );
  });
}
