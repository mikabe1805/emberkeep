// Helpers for tests of the Goals room (the Steward's workshop).
//
// The room keeps one card: the current goal, its next thing and its two
// buttons. Everything else Goals has sits behind the card's MORE (the
// `goals-room-more` handle), in a list that scrolls inside the card
// (`goals-card-scroll`), or in the page's own scroll at large text
// (`goals-threshold-scroll`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final Finder goalsRoomMore = find.byKey(const Key('goals-room-more'));
final Finder goalsRoomUnrolled = find.byKey(const Key('goals-room-unrolled'));

/// The scroll view that holds the card's unrolled rows.
Finder goalsRoomScroll() {
  final page = find.byKey(const Key('goals-threshold-scroll'));
  if (page.evaluate().isNotEmpty) return page;
  return find.byKey(const Key('goals-card-scroll'));
}

/// Unrolls the card's MORE if it is not already.
Future<void> openGoalsMore(WidgetTester tester) async {
  if (goalsRoomUnrolled.evaluate().isNotEmpty) return;
  expect(goalsRoomMore, findsOneWidget);
  await tester.ensureVisible(goalsRoomMore);
  await tester.tap(goalsRoomMore);
  await tester.pumpAndSettle();
}

/// Brings [target] into view: unrolls MORE when it is not on the card's face,
/// then scrolls the card (or the page, at large text) until it shows.
Future<void> revealOnGoalsPage(
  WidgetTester tester,
  Finder target, {
  int maxScrolls = 14,
}) async {
  if (target.evaluate().isEmpty) {
    if (goalsRoomMore.evaluate().isNotEmpty) await openGoalsMore(tester);
  }
  if (target.evaluate().isEmpty) {
    // Rows that have scrolled away are not built: start again from the top.
    final scrollable = find.descendant(
      of: goalsRoomScroll(),
      matching: find.byType(Scrollable),
    );
    if (scrollable.evaluate().isNotEmpty) {
      tester.state<ScrollableState>(scrollable.first).position.jumpTo(0);
      await tester.pumpAndSettle();
    }
  }
  for (
    var attempt = 0;
    target.evaluate().isEmpty && attempt < maxScrolls;
    attempt++
  ) {
    await tester.drag(goalsRoomScroll(), const Offset(0, -220));
    await tester.pumpAndSettle();
  }
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pump();
}
