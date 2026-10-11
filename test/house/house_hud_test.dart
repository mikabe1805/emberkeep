// The house's one HUD: the level, the XP, the date and the six stats, drawn
// once by the shell over every room (HouseTravelStack.overlay), never by a room.
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/class_day/class_day_room.dart';
import 'package:emberkeep/widgets/house/house_hud.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:emberkeep/widgets/house/house_travel.dart';
import 'package:emberkeep/widgets/house/house_travel_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/room_fonts.dart';

const _frame = Duration(microseconds: 16667);

class _Room extends StatelessWidget {
  const _Room(this.index);
  final int index;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Color(0xFF000000 + 0x202020 * (index + 1)),
    child: HouseRoomUi(
      room: HouseRoom.values[index],
      child: Center(child: Text('room $index')),
    ),
  );
}

GameState _state() => GameState()
  ..level = 18
  ..xp = 369
  ..stats[Stat.str] = 88
  ..stats[Stat.vit] = 72
  ..stats[Stat.intl] = 125
  ..stats[Stat.foc] = 94
  ..stats[Stat.soc] = 61
  ..stats[Stat.dis] = 103;

Future<ValueNotifier<int>> _pump(
  WidgetTester tester, {
  required List<Stat> opened,
  double text = 1,
  Size size = const Size(393, 852),
  bool stepBack = false,
  GameState? state,
}) async {
  Clock.freeze(DateTime(2026, 10, 6, 12, 30));
  addTearDown(Clock.reset);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final tab = ValueNotifier<int>(0);
  addTearDown(tab.dispose);
  final game = state ?? _state();
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(text)),
        child: Scaffold(
          body: ValueListenableBuilder<int>(
            valueListenable: tab,
            builder: (context, index, _) => HouseTravelStack(
              index: index,
              reduceMotion: false,
              overlay: HouseHud(
                state: game,
                stepBack: stepBack,
                onExploreStat: opened.add,
              ),
              children: [for (var i = 0; i < 5; i++) _Room(i)],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return tab;
}

double _opacityOfHud(WidgetTester tester) {
  var o = 1.0;
  for (final e
      in find
          .ancestor(
            of: find.byKey(const Key('house-hud')),
            matching: find.byType(Opacity),
          )
          .evaluate()) {
    o *= (e.widget as Opacity).opacity;
  }
  for (final e
      in find
          .ancestor(
            of: find.byKey(const Key('house-hud')),
            matching: find.byType(AnimatedOpacity),
          )
          .evaluate()) {
    o *= (e.widget as AnimatedOpacity).opacity;
  }
  return o;
}

void main() {
  // The HUD is measured in its own faces, not the stand-in a test paints with.
  setUpAll(loadHudFonts);

  group('one HUD over every room', () {
    testWidgets('the level, the XP, the date and the six stats', (
      tester,
    ) async {
      await _pump(tester, opened: []);
      expect(find.byType(ClassDayHud), findsOneWidget);
      expect(find.text('LV'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.textContaining('369'), findsWidgets);
      expect(find.textContaining('OCT 6'), findsOneWidget);
      for (final stat in Stat.values) {
        expect(find.byKey(Key('class-day-stat-${stat.name}')), findsOneWidget);
      }
      for (final v in ['88', '72', '125', '94', '61', '103']) {
        expect(find.text(v), findsOneWidget, reason: v);
      }
    });

    testWidgets('it is the same widget in every room, never remounted', (
      tester,
    ) async {
      final tab = await _pump(tester, opened: []);
      final first = tester.element(find.byType(ClassDayHud));
      for (var i = 1; i < 5; i++) {
        tab.value = i;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));
        expect(find.byType(ClassDayHud), findsOneWidget, reason: 'room $i');
        expect(tester.element(find.byType(ClassDayHud)), same(first));
      }
    });

    testWidgets('a stat opens its domain page, in any room', (tester) async {
      final opened = <Stat>[];
      final tab = await _pump(tester, opened: opened);
      for (var i = 0; i < 5; i++) {
        tab.value = i;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));
        await tester.tap(find.byKey(const Key('class-day-stat-foc')));
        await tester.pump();
      }
      expect(opened, List.filled(5, Stat.foc));
      for (final stat in Stat.values) {
        await tester.tap(find.byKey(Key('class-day-stat-${stat.name}')));
      }
      expect(opened.sublist(5), Stat.values);
    });

    testWidgets('every stat is a target of at least 44 pt', (tester) async {
      for (final scale in [1.0, 1.3, 2.0]) {
        await _pump(tester, opened: [], text: scale);
        for (final stat in Stat.values) {
          final r = tester.getRect(
            find.byKey(Key('class-day-stat-${stat.name}')),
          );
          expect(r.height, greaterThanOrEqualTo(44), reason: '$stat $scale');
          expect(r.width, greaterThanOrEqualTo(44), reason: '$stat $scale');
        }
      }
    });

    testWidgets('it reaches no further down than houseHudBottom promises', (
      tester,
    ) async {
      for (final scale in [1.0, 1.3, 2.0]) {
        await _pump(tester, opened: [], text: scale);
        final bottom = tester
            .getRect(find.byKey(const Key('class-day-stat-soc')))
            .bottom;
        expect(
          bottom,
          lessThanOrEqualTo(houseHudBottom(textScale: scale) + 1),
          reason: 'text $scale',
        );
        // A tall rule for the rooms: it stays in the top ninth of the screen
        // even at the largest text.
        expect(bottom, lessThan(852 / 9));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('an icon keeps its gap to its numeral at every text size', (
      tester,
    ) async {
      for (final (scale, size) in const [
        (1.0, Size(393, 852)),
        (1.3, Size(393, 852)),
        (2.0, Size(393, 852)),
        (1.0, Size(320, 568)),
        (1.3, Size(320, 568)),
        (2.0, Size(320, 568)),
      ]) {
        await _pump(tester, opened: [], text: scale, size: size);
        Rect? previousNumeral;
        for (final stat in Stat.values) {
          final cell = find.byKey(Key('class-day-stat-${stat.name}'));
          final icon = tester.getRect(
            find.descendant(of: cell, matching: find.byType(Icon)),
          );
          final numeral = tester.getRect(
            find.descendant(of: cell, matching: find.byType(Text)),
          );
          final where = '$stat at $scale on ${size.width.round()}';
          // The numeral starts after the icon with room to breathe: 5 pt at
          // 100% (4 pt before), growing with the text to 6.5 pt at 130% and
          // its cap. Only a cell too narrow for the pair (three digits at 130%
          // on a 320 wide phone) takes it down, and then no lower than before.
          final gap = numeral.left - icon.right;
          expect(
            gap,
            greaterThanOrEqualTo(size.width > 350 ? 5 : 4.5),
            reason: where,
          );
          // At 100% the row moved by no more than 2 pt (the gap was 4).
          if (scale == 1 && size.width > 350) {
            expect(gap, lessThanOrEqualTo(6), reason: where);
          }
          // The pair is whole in its cell: nothing is cut off.
          final box = tester.getRect(cell);
          expect(
            numeral.right,
            lessThanOrEqualTo(box.right + 0.5),
            reason: where,
          );
          expect(
            icon.left,
            greaterThanOrEqualTo(box.left - 0.5),
            reason: where,
          );
          expect(box.height, greaterThanOrEqualTo(44), reason: where);
          expect(box.width, greaterThanOrEqualTo(44), reason: where);
          // A numeral keeps clear of the next stat's icon.
          if (previousNumeral != null) {
            expect(
              icon.left - previousNumeral.right,
              greaterThanOrEqualTo(5),
              reason: '$where, from the stat before',
            );
          }
          previousNumeral = numeral;
        }
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('the gap grows with the text and stops at the cap', (
      tester,
    ) async {
      double gapAt(double scale) {
        final cell = find.byKey(const Key('class-day-stat-str'));
        final icon = tester.getRect(
          find.descendant(of: cell, matching: find.byType(Icon)),
        );
        final numeral = tester.getRect(
          find.descendant(of: cell, matching: find.byType(Text)),
        );
        return numeral.left - icon.right;
      }

      await _pump(tester, opened: [], text: 1);
      final at100 = gapAt(1);
      await _pump(tester, opened: [], text: 1.3);
      final at130 = gapAt(1.3);
      await _pump(tester, opened: [], text: 2.0);
      final at200 = gapAt(2);
      expect(at130, greaterThan(at100));
      expect(at200, closeTo(at130, 0.01));
    });

    testWidgets('it follows the text size up to 130% and no further', (
      tester,
    ) async {
      await _pump(tester, opened: [], text: 1.3);
      final at130 = tester
          .getSize(find.byKey(const Key('class-day-hud')))
          .height;
      await _pump(tester, opened: [], text: 2.0);
      final at200 = tester
          .getSize(find.byKey(const Key('class-day-hud')))
          .height;
      expect(at200, closeTo(at130, 0.5));
    });

    testWidgets('it holds on a small phone with no overflow', (tester) async {
      await _pump(tester, opened: [], text: 2.0, size: const Size(320, 568));
      expect(tester.takeException(), isNull);
    });

    testWidgets('it breathes through a hand-off and is whole again', (
      tester,
    ) async {
      final tab = await _pump(tester, opened: []);
      expect(_opacityOfHud(tester), closeTo(1, 1e-9));
      tab.value = 2;
      await tester.pump();
      var lowest = 1.0;
      for (var ms = 0; ms < 1400; ms += 16) {
        await tester.pump(_frame);
        final o = _opacityOfHud(tester);
        if (o < lowest) lowest = o;
        // It never goes dark: the numbers stay readable.
        expect(o, greaterThanOrEqualTo(0.6 - 1e-9));
      }
      expect(lowest, lessThan(1));
      expect(_opacityOfHud(tester), closeTo(1, 1e-9));
    });

    testWidgets('it steps back to 60% for the evening music, still pressable', (
      tester,
    ) async {
      final opened = <Stat>[];
      await _pump(tester, opened: opened, stepBack: true);
      await tester.pump(const Duration(milliseconds: 2000));
      expect(_opacityOfHud(tester), closeTo(0.6, 1e-6));
      await tester.tap(find.byKey(const Key('class-day-stat-str')));
      expect(opened, [Stat.str]);
    });

    testWidgets('the stats read to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, opened: []);
      expect(find.bySemanticsLabel('Level 18, 369 of 870 XP'), findsOneWidget);
      expect(find.bySemanticsLabel('Mind 125'), findsOneWidget);
      handle.dispose();
    });
  });
}
