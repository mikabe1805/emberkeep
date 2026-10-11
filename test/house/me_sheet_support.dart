// Shared by the tests that reach the Me page's sections: they live in the
// mantel's sheets and on the "Your space" page now (see lib/widgets/house/me/).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The mantel's openers by name: the quiet tabs `settings`, `save`, `space`
/// and `more`, and the trophy tag `trophy`. `space` is a page, not a sheet:
/// it is the page YOUR SPACE opens ([yourSpacePageUp]).
String mantelSheetKey(String sheet) =>
    sheet == 'trophy' ? 'mantel-tag-trophy' : 'mantel-tab-$sheet';

/// Whether the "Your space" page is the page on top.
bool get yourSpacePageUp =>
    find.byKey(const Key('your-space-scroll')).evaluate().isNotEmpty;

/// Opens a mantel sheet, or the "Your space" page, and lets it arrive. The
/// page keeps its room alive, so this never waits for the frames to settle.
Future<void> openMantelSheet(WidgetTester tester, String sheet) async {
  await tester.tap(find.byKey(Key(mantelSheetKey(sheet))));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  if (sheet == 'space') await tester.pump(const Duration(milliseconds: 400));
}

/// Closes the open sheet with its CLOSE, or the page with its BACK.
Future<void> closeMantelSheet(WidgetTester tester) async {
  final back = find.byKey(const Key('your-space-back'));
  await tester.tap(
    back.evaluate().isNotEmpty
        ? back
        : find.byKey(const Key('mantel-sheet-close')),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// The scroll that is on top: the "Your space" page's when it is up, else the
/// open sheet's (the mantel behind keeps none of its own).
Finder get mantelSheetScrollable => find
    .descendant(
      of: find.byKey(
        yourSpacePageUp
            ? const Key('your-space-scroll')
            : const Key('mantel-sheet-scroll'),
      ),
      matching: find.byType(Scrollable),
    )
    .first;
