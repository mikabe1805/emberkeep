// Renders the Journal as the reading nook, through the real app at iPhone size
// (393 x 852 at 3x, PNGs 1179 x 2556): with entries, with none, scrolled down
// to the lenses, and at 130% and 200% text. Skipped unless asked for:
//
//   flutter test --dart-define=HOUSE_RENDERS=true \
//     test/design_renders/house_journal_render_test.dart
//
// Output: design/comparisons/2026-10-10/house-rooms/journal/ in the
// class-day-journey checkout, beside the prototype's v4 frames.
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/widgets/class_day/doorway_art.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('HOUSE_RENDERS');

const _out =
    'C:/Users/mikus/Downloads/experimentProject/app/.worktrees/class-day-journey/'
    'design/comparisons/2026-10-10/house-rooms/journal';

final _at = DateTime(2026, 10, 6, 12, 30);
final _schedule = mikaSchedule();

List<String> get _plates => {
  for (final set in [HousePlateSets.journal]) ...set.all,
}.toList();

/// Mika's three most recent pages, as the approved v4 frame shows them.
List<Note> _entries() => [
  Note(at: DateTime(2026, 10, 2, 21, 5), text: 'A warm detail'),
  Note(at: DateTime(2026, 10, 4, 20, 40), text: 'A small win'),
  Note(at: DateTime(2026, 10, 5, 21, 30), text: 'After the quest'),
];

Future<void> _open(
  WidgetTester tester, {
  required bool entries,
  double text = 1,
}) async {
  tester.platformDispatcher.textScaleFactorTestValue = text;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final account = mikaAccount(renderAt: _at, withJournal: false);
  if (entries) account.state.setJournal(_entries());
  Clock.freeze(_at);
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
  await openTab(tester, RoomTab.journal);
}

void main() {
  setUpAll(setUpRoomRenders);
  tearDownAll(tearDownRoomRenders);
  final sheet = FrameSheet(_out);
  tearDownAll(() {
    if (_renders) sheet.writeManifest();
  });

  roomRenderTest('journal nook with entries', skip: !_renders, (tester) async {
    await _open(tester, entries: true);
    // with the real type the nook sits whole above the dock (88 pt plus the
    // home indicator) and clear under the Keepsakes label
    final card = tester.getRect(
      find.byKey(const ValueKey('journal-nook-card')),
    );
    final tag = tester.getRect(
      find.byKey(const ValueKey('journal-keepsakes-tag')),
    );
    expect(card.bottom, lessThanOrEqualTo(852 - 88 - 34));
    expect(tag.bottom, lessThan(card.top));
    await sheet.shot(
      tester,
      'J_entries',
      at: _at,
      surface: 'JOURNAL',
      note: 'at rest, three entries',
    );
    await tester.drag(
      find.byKey(const ValueKey('journal-nook-scroll')),
      const Offset(0, -420),
    );
    await settle(tester, total: const Duration(milliseconds: 600));
    await sheet.shot(
      tester,
      'J_lenses',
      at: _at,
      surface: 'JOURNAL',
      note: 'scrolled to the lenses and the cards below the nook',
    );
    await tester.drag(
      find.byKey(const ValueKey('journal-nook-scroll')),
      const Offset(0, -900),
    );
    await settle(tester, total: const Duration(milliseconds: 600));
    await sheet.shot(
      tester,
      'J_lower',
      at: _at,
      surface: 'JOURNAL',
      note: 'scrolled further: energy weather, domains, rhythm',
    );
  });

  roomRenderTest('journal nook, no entries', skip: !_renders, (tester) async {
    await _open(tester, entries: false);
    await sheet.shot(
      tester,
      'J_empty',
      at: _at,
      surface: 'JOURNAL',
      note: 'no entries: Your first page is ready',
    );
  });

  for (final scale in const [1.3, 2.0]) {
    roomRenderTest(
      'journal nook at ${(scale * 100).round()}% text',
      skip: !_renders,
      (tester) async {
        await _open(tester, entries: true, text: scale);
        await sheet.shot(
          tester,
          'J_text${(scale * 100).round()}',
          at: _at,
          surface: 'JOURNAL',
          note: '${(scale * 100).round()}% text',
        );
        await tester.drag(
          find.byKey(const ValueKey('journal-nook-scroll')),
          const Offset(0, -300),
        );
        await settle(tester, total: const Duration(milliseconds: 600));
        await sheet.shot(
          tester,
          'J_text${(scale * 100).round()}_scrolled',
          at: _at,
          surface: 'JOURNAL',
          note: '${(scale * 100).round()}% text, scrolled',
        );
      },
    );
  }
}
