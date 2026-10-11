// Shared by the tests that reach the Me page's sections: they live in the
// mantel's sheets now (see lib/widgets/house/me/).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The mantel sheets by name: the quiet tabs `settings`, `save`, `space` and
/// `more`, and the trophy tag `trophy`.
String mantelSheetKey(String sheet) =>
    sheet == 'trophy' ? 'mantel-tag-trophy' : 'mantel-tab-$sheet';

/// Opens a mantel sheet and lets it rise.
Future<void> openMantelSheet(WidgetTester tester, String sheet) async {
  await tester.tap(find.byKey(Key(mantelSheetKey(sheet))));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Closes the open sheet with its CLOSE.
Future<void> closeMantelSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('mantel-sheet-close')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// The open sheet's own scroll (the page behind keeps its own).
Finder get mantelSheetScrollable => find
    .descendant(
      of: find.byKey(const Key('mantel-sheet-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;
