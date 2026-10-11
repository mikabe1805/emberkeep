// The fade above the dock shows only while a room's scroll is carrying content
// under the dock. A room at rest, and a room that does not scroll under the
// dock, is never dimmed by it.
import 'package:emberkeep/widgets/house/house_dock_fade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _dock = 88.0;
const _size = Size(393, 852);

/// The shell's arrangement in small: a room (one page, wrapped in the
/// listener), the fade, then the dock.
Future<HouseDockFadeController> _pump(
  WidgetTester tester, {
  required Widget room,
  int tab = 0,
  int? fadeTab,
  HouseDockFadeController? controller,
}) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  controller ??= HouseDockFadeController();
  final fade = controller;
  addTearDown(fade.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: HouseDockFadeListener(
                controller: controller,
                tab: tab,
                child: room,
              ),
            ),
            HouseDockFade(
              controller: controller,
              tab: fadeTab ?? tab,
              bottom: _dock,
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _dock,
              child: ColoredBox(color: Color(0xFF17120F)),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  return fade;
}

double _fade(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(find.byKey(const ValueKey('house-dock-fade')))
    .opacity;

Widget _longRoom() => ListView(
  key: const ValueKey('room-scroll'),
  children: [
    for (var i = 0; i < 40; i++)
      SizedBox(height: 60, child: Text('row $i', key: ValueKey('row-$i'))),
  ],
);

void main() {
  testWidgets('a room at rest is not dimmed, even when it can scroll', (
    tester,
  ) async {
    await _pump(tester, room: _longRoom());
    // Give the scroll a chance to report its metrics.
    await tester.pump(const Duration(milliseconds: 200));
    expect(_fade(tester), 0);
  });

  testWidgets('content carried under the dock raises the fade as it goes', (
    tester,
  ) async {
    await _pump(tester, room: _longRoom());
    final scroll = find.byKey(const ValueKey('room-scroll'));

    await tester.drag(scroll, const Offset(0, -12));
    await tester.pump(const Duration(milliseconds: 200));
    final little = _fade(tester);
    expect(little, greaterThan(0));
    expect(little, lessThan(1));

    await tester.drag(scroll, const Offset(0, -200));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_fade(tester), 1);
  });

  testWidgets('back at the top it lets go again', (tester) async {
    await _pump(tester, room: _longRoom());
    final scroll = find.byKey(const ValueKey('room-scroll'));
    await tester.drag(scroll, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_fade(tester), 1);

    await tester.drag(scroll, const Offset(0, 2000));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_fade(tester), 0);
  });

  testWidgets('at the end of the scroll the last of it rests clear', (
    tester,
  ) async {
    await _pump(tester, room: _longRoom());
    final scroll = find.byKey(const ValueKey('room-scroll'));
    await tester.drag(scroll, const Offset(0, -5000));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_fade(tester), 0, reason: 'the content ends; nothing is cut');
  });

  testWidgets('a scroll inside a page that ends above the dock never counts', (
    tester,
  ) async {
    // A list inside a book's page: its box ends well above the dock.
    await _pump(
      tester,
      room: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 300,
          height: 400,
          child: ListView(
            key: const ValueKey('inner-scroll'),
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(height: 60, child: Text('$i')),
            ],
          ),
        ),
      ),
    );
    await tester.drag(
      find.byKey(const ValueKey('inner-scroll')),
      const Offset(0, -300),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(_fade(tester), 0);
  });

  testWidgets('a horizontal scroll never counts', (tester) async {
    await _pump(
      tester,
      room: ListView(
        key: const ValueKey('sideways'),
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < 40; i++) SizedBox(width: 120, child: Text('$i')),
        ],
      ),
    );
    await tester.drag(
      find.byKey(const ValueKey('sideways')),
      const Offset(-300, 0),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(_fade(tester), 0);
  });

  testWidgets('the fade is for the room on stage, not one scrolled away', (
    tester,
  ) async {
    // The scrolling room is tab 1; the fade on stage was built for tab 0.
    final controller = await _pump(
      tester,
      room: _longRoom(),
      tab: 1,
      fadeTab: 0,
    );
    await tester.drag(
      find.byKey(const ValueKey('room-scroll')),
      const Offset(0, -300),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.levelFor(1), 1);
    expect(controller.levelFor(0), 0);
    expect(_fade(tester), 0);
  });

  testWidgets('a report made while the frame is laid out waits, then counts', (
    tester,
  ) async {
    BuildContext? room;
    final controller = HouseDockFadeController();
    final metrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 1000,
      pixels: 200,
      viewportDimension: _size.height,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );
    await _pump(
      tester,
      controller: controller,
      room: Stack(
        children: [
          Positioned.fill(
            child: Builder(
              builder: (context) {
                room = context;
                return const SizedBox.expand();
              },
            ),
          ),
          // A LayoutBuilder's builder runs inside layout, where no render
          // box's size may be read: a report made from it must not try.
          LayoutBuilder(
            builder: (context, constraints) {
              if (room != null) controller.report(0, room, metrics);
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
    // Lay the room out again, with the report made from inside that layout.
    tester.view.physicalSize = Size(_size.width, _size.height - 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(controller.levelFor(0), 1);
  });

  testWidgets('it never takes a touch', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      room: ListView(
        key: const ValueKey('room-scroll'),
        children: [
          for (var i = 0; i < 40; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: SizedBox(height: 60, child: Text('row $i')),
            ),
        ],
      ),
    );
    await tester.drag(
      find.byKey(const ValueKey('room-scroll')),
      const Offset(0, -300),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(_fade(tester), 1);
    // A tap in the middle of the fade's band reaches the row beneath it.
    await tester.tapAt(Offset(100, _size.height - _dock - 17));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
