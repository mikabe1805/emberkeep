// The dock's travel between the house's rooms, played by the real widget:
// every room arrives through its own light, rooms stay mounted, a new tap
// re-aims from the picture on screen and Reduce Motion is a plain cross-fade.
import 'package:emberkeep/widgets/house/house_arrival.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:emberkeep/widgets/house/house_travel.dart';
import 'package:emberkeep/widgets/house/house_travel_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _frame = Duration(microseconds: 16667);

final Map<int, int> _mounts = {};
final List<int> _taps = [];

/// One room: a coloured field with a live card (HouseRoomUi) in its middle.
class _Room extends StatefulWidget {
  const _Room(this.index);
  final int index;

  @override
  State<_Room> createState() => _RoomState();
}

class _RoomState extends State<_Room> {
  @override
  void initState() {
    super.initState();
    _mounts.update(widget.index, (n) => n + 1, ifAbsent: () => 1);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Color(0xFF000000 + 0x202020 * (widget.index + 1)),
      child: HouseRoomUi(
        room: HouseRoom.values[widget.index],
        child: Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _taps.add(widget.index),
            child: SizedBox(
              width: 200,
              height: 80,
              child: Text('room ${widget.index}'),
            ),
          ),
        ),
      ),
    );
  }
}

Future<ValueNotifier<int>> _pump(
  WidgetTester tester, {
  bool? reduceMotion,
}) async {
  final tab = ValueNotifier<int>(1);
  addTearDown(tab.dispose);
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: ValueListenableBuilder<int>(
        valueListenable: tab,
        builder: (context, index, _) => HouseTravelStack(
          index: index,
          reduceMotion: reduceMotion,
          children: [for (var i = 0; i < 5; i++) _Room(i)],
        ),
      ),
    ),
  );
  return tab;
}

int? _roomOf(Element e) {
  int? room;
  e.visitAncestorElements((a) {
    final key = a.widget.key;
    if (key is ValueKey<String> && key.value.startsWith('house-room-')) {
      room = int.parse(key.value.substring('house-room-'.length));
      return false;
    }
    return true;
  });
  return room;
}

/// The mask each room on stage is under (null: painted directly), by room.
Map<int, List<HouseGradient>?> _masks(WidgetTester tester) {
  final out = <int, List<HouseGradient>?>{};
  for (final e in find.byType(HouseMask, skipOffstage: false).evaluate()) {
    final room = _roomOf(e);
    final offstage = e.findAncestorWidgetOfExactType<Offstage>()!.offstage;
    if (room != null && !offstage) {
      out[room] = (e.widget as HouseMask).gradients;
    }
  }
  return out;
}

/// How much of the room's own UI shows (its HouseRoomUi).
double _ui(WidgetTester tester, int room) => tester
    .widget<Opacity>(
      find.descendant(
        of: find.descendant(
          of: find.byKey(ValueKey('house-room-$room'), skipOffstage: false),
          matching: find.byType(HouseRoomUi, skipOffstage: false),
          skipOffstage: false,
        ),
        matching: find.byType(Opacity),
        skipOffstage: false,
      ),
    )
    .opacity;

void main() {
  setUp(() {
    _mounts.clear();
    _taps.clear();
  });

  testWidgets('at rest one room is on stage, painted directly, no mask', (
    tester,
  ) async {
    await _pump(tester);
    expect(_masks(tester), {1: null});
    expect(find.text('room 1'), findsOneWidget);
    expect(find.text('room 3'), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
    // Every room is built once, on stage or not.
    expect(_mounts, {0: 1, 1: 1, 2: 1, 3: 1, 4: 1});
  });

  testWidgets("a tap arrives through the room's light, then settles", (
    tester,
  ) async {
    final tab = await _pump(tester);
    for (final room in [
      HouseRoom.me,
      HouseRoom.goals,
      HouseRoom.plans,
      HouseRoom.journal,
      HouseRoom.quests,
    ]) {
      tab.value = room.index;
      await tester.pump();
      var masks = _masks(tester);
      expect(masks.length, 2, reason: '${room.name} over the old room');
      expect(masks[room.index], isNotNull);
      await tester.pump(room.arrivalDuration ~/ 2);
      masks = _masks(tester);
      // The mask is the room's own recipe: a reveal, drawn from its light.
      expect(masks[room.index], isNotEmpty);
      await tester.pump(room.arrivalDuration);
      await tester.pump(_frame);
      expect(_masks(tester), {room.index: null});
      expect(tester.hasRunningAnimations, isFalse);
    }
    expect(_mounts.values.every((n) => n == 1), isTrue);
  });

  testWidgets("each arrival takes its room's own time", (tester) async {
    final tab = await _pump(tester);
    for (final room in [
      HouseRoom.me,
      HouseRoom.goals,
      HouseRoom.plans,
      HouseRoom.journal,
      HouseRoom.quests,
    ]) {
      tab.value = room.index;
      await tester.pump();
      await tester.pump(
        room.arrivalDuration - const Duration(milliseconds: 40),
      );
      expect(_masks(tester).length, 2, reason: '${room.name} still arriving');
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(_frame);
      expect(_masks(tester), {room.index: null}, reason: '${room.name} done');
    }
  });

  testWidgets('the departing UI lets go first, the arriving UI waits for its '
      'light, and two cards never overlap', (tester) async {
    final tab = await _pump(tester);
    tab.value = 3;
    await tester.pump();
    expect(_ui(tester, 3), 0.0);
    var worst = 0.0;
    for (var ms = 0; ms < 900; ms += 17) {
      await tester.pump(_frame);
      if (_masks(tester).length < 2) break;
      final both = _ui(tester, 1) * _ui(tester, 3);
      if (both > worst) worst = both;
    }
    // Never both cards strongly on screen at once.
    expect(worst, lessThan(0.2));
    await tester.pump(const Duration(milliseconds: 900));
    expect(_ui(tester, 3), 1.0);
  });

  testWidgets('the departing room dips 25% and never goes black', (
    tester,
  ) async {
    final tab = await _pump(tester);
    tab.value = 0;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 230));
    final dim = tester
        .widgetList<ColoredBox>(
          find.descendant(
            of: find.byKey(const ValueKey('house-room-1')),
            matching: find.byType(ColoredBox),
          ),
        )
        // The dip is the house's own dark, not the room's colour.
        .where((c) => c.color.toARGB32() & 0xFFFFFF == 0x0B0603)
        .map((c) => c.color.a)
        .reduce((a, b) => a > b ? a : b);
    expect(dim, closeTo(0.25, 0.01));
  });

  testWidgets('a tap mid-arrival re-aims from the picture on screen', (
    tester,
  ) async {
    final tab = await _pump(tester);
    tab.value = 3;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_masks(tester).keys.toSet(), {1, 3});

    tab.value = 4; // redirect
    await tester.pump();
    // Room 3 is still on stage, under the new arrival; nothing snapped away.
    expect(_masks(tester).keys.toSet(), {1, 3, 4});
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(_frame);
    expect(_masks(tester), {4: null});
    expect(_mounts.values.every((n) => n == 1), isTrue);
  });

  testWidgets('a tap back to the room being left brings it back up', (
    tester,
  ) async {
    final tab = await _pump(tester);
    tab.value = 3;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    tab.value = 1;
    await tester.pump();
    // Room 1 never left: it is the base, and room 3 lets go above it.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(_frame);
    expect(_masks(tester), {1: null});
  });

  testWidgets('only the room being entered takes a tap, from the first '
      'frame', (tester) async {
    final tab = await _pump(tester);
    tab.value = 3;
    await tester.pump();
    await tester.pump(_frame);
    await tester.tapAt(tester.getCenter(find.text('room 3')));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(_taps, isNotEmpty);
    expect(_taps.toSet(), {3});
  });

  testWidgets('Reduce Motion is a 200 ms cross-fade: no mask, no drift', (
    tester,
  ) async {
    final tab = await _pump(tester, reduceMotion: true);
    tab.value = 3;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_masks(tester).keys.toSet(), {1, 3});
    expect(_masks(tester).values.every((m) => m == null), isTrue);
    final fade = tester
        .widgetList<Opacity>(
          find.descendant(
            of: find.byKey(const ValueKey('house-room-3')),
            matching: find.byType(Opacity),
          ),
        )
        .map((o) => o.opacity)
        .where((o) => o < 1);
    expect(fade, isNotEmpty);
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pump(_frame);
    expect(_masks(tester), {3: null});
  });
}
