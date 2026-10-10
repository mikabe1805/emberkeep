// A room's backdrop: its plate for the real light of the day (never tinted),
// the slight tilt, Reduce Motion, the Doorway for Quests, and the room's UI
// that fades with the dock's travel.
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/widgets/class_day/doorway_stage.dart';
import 'package:emberkeep/widgets/house/house_backdrop.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:emberkeep/widgets/house/house_travel.dart';
import 'package:emberkeep/widgets/house/house_travel_model.dart';
import 'package:emberkeep/widgets/house/house_travel_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(size: Size(393, 852)),
    child: SizedBox(width: 393, height: 852, child: child),
  ),
);

/// The plate assets painted, in order.
List<String> _plates(WidgetTester tester) => [
  for (final image in tester.widgetList<Image>(find.byType(Image)))
    (image.image as AssetImage).assetName,
];

void main() {
  tearDown(Clock.reset);

  testWidgets('midday paints the midday plate, whole, with no tint over it', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 10, 6, 12, 30));
    await tester.pumpWidget(
      _host(const HouseRoomBackdrop(room: HouseRoom.me, child: Text('card'))),
    );
    expect(_plates(tester), [HousePlateSets.me.midday]);
    // Nothing is laid over the painting to change its light.
    expect(find.byType(ColorFiltered), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('card'), findsOneWidget);
  });

  testWidgets('evening paints the painted evening for Me and Plans', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 10, 6, 21));
    for (final (room, plates) in [
      (HouseRoom.me, HousePlateSets.me),
      (HouseRoom.plans, HousePlateSets.plansDay),
    ]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _host(HouseRoomBackdrop(room: room, child: const SizedBox())),
      );
      expect(_plates(tester), [plates.evening]);
    }
  });

  testWidgets('a room with no evening plate keeps its painted light at night', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 10, 6, 22));
    for (final (room, plates) in [
      (HouseRoom.goals, HousePlateSets.goals),
      (HouseRoom.journal, HousePlateSets.journal),
    ]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _host(HouseRoomBackdrop(room: room, child: const SizedBox())),
      );
      expect(_plates(tester), [plates.midday]);
      expect(find.byType(ColorFiltered), findsNothing);
      expect(find.byType(DecoratedBox), findsNothing);
    }
  });

  testWidgets('the hour turning cross-fades the two plates', (tester) async {
    var now = DateTime(2026, 10, 6, 18, 0);
    Clock.use(() => now);
    await tester.pumpWidget(
      _host(const HouseRoomBackdrop(room: HouseRoom.me, child: SizedBox())),
    );
    expect(_plates(tester), [HousePlateSets.me.midday]);
    now = DateTime(2026, 10, 6, 18, 30);
    await tester.pump(houseLightRefresh);
    expect(_plates(tester), [
      HousePlateSets.me.midday,
      HousePlateSets.me.evening,
    ]);
    final fade = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .map((o) => o.opacity);
    expect(fade, contains(closeTo(0.5, 0.01)));
    now = DateTime(2026, 10, 6, 19, 0);
    await tester.pump(houseLightRefresh);
    expect(_plates(tester), [HousePlateSets.me.evening]);
  });

  testWidgets('Plans changes plate set (day to month) with a cross-fade', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 10, 6, 12));
    Widget plans(HousePlates p) => _host(
      HouseRoomBackdrop(
        room: HouseRoom.plans,
        plates: p,
        reduceMotion: false,
        child: const SizedBox(),
      ),
    );
    await tester.pumpWidget(plans(HousePlateSets.plansDay));
    expect(_plates(tester), [HousePlateSets.plansDay.midday]);
    await tester.pumpWidget(plans(HousePlateSets.plansMonth));
    await tester.pump(housePlateSwap ~/ 2);
    expect(_plates(tester), [
      HousePlateSets.plansDay.midday,
      HousePlateSets.plansMonth.midday,
    ]);
    await tester.pump(housePlateSwap);
    expect(_plates(tester), [HousePlateSets.plansMonth.midday]);
  });

  testWidgets('the plate moves a hair with the tilt, and not at all under '
      'Reduce Motion', (tester) async {
    Clock.freeze(DateTime(2026, 10, 6, 12));
    final tilt = ValueNotifier(Offset.zero);
    addTearDown(tilt.dispose);
    Offset where() => tester.getTopLeft(find.byType(Image).first);
    Widget room({bool still = false}) => _host(
      HouseRoomBackdrop(
        room: HouseRoom.journal,
        parallax: tilt,
        reduceMotion: still,
        child: const SizedBox(),
      ),
    );
    await tester.pumpWidget(room());
    final rest = where();
    tilt.value = const Offset(1, 0);
    await tester.pump();
    expect((where() - rest).dx, closeTo(housePlateParallax, 0.01));
    tilt.value = const Offset(-1, 0);
    await tester.pump();
    expect((where() - rest).dx, closeTo(-housePlateParallax, 0.01));
    await tester.pumpWidget(room(still: true));
    tilt.value = const Offset(1, 0);
    await tester.pump();
    expect((where() - rest).dx.abs(), lessThan(0.01));
  });

  testWidgets('Quests is the Doorway, with the rail empty', (tester) async {
    Clock.freeze(DateTime(2026, 10, 10, 11));
    await tester.pumpWidget(
      _host(
        const HouseRoomBackdrop(
          room: HouseRoom.quests,
          reduceMotion: true,
          child: Text('board'),
        ),
      ),
    );
    final stage = tester.widget<DoorwayStage>(find.byType(DoorwayStage));
    expect(stage.day.tickets, isEmpty);
    expect(stage.day.bowlPairs, isEmpty);
    expect(stage.day.shelfBundles, isEmpty);
    expect(find.text('board'), findsOneWidget);
  });

  testWidgets('the plate runs up under the status bar', (tester) async {
    Clock.freeze(DateTime(2026, 10, 6, 12));
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 59);
    tester.view.viewPadding = const FakeViewPadding(top: 59);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(393, 852),
            padding: EdgeInsets.only(top: 0),
          ),
          child: const Padding(
            padding: EdgeInsets.only(top: 59),
            child: HouseRoomBackdrop(room: HouseRoom.me, child: SizedBox()),
          ),
        ),
      ),
    );
    // The plate starts at the top of the screen (a hair above it: the overscan
    // that keeps the tilt from showing an edge), not at the page's top.
    final top = tester.getTopLeft(find.byType(Image)).dy;
    expect(top, lessThanOrEqualTo(0));
    expect(top, greaterThan(-8));
  });

  group('the room\'s UI', () {
    testWidgets('outside a travel stack it is simply there', (tester) async {
      await tester.pumpWidget(
        _host(const HouseRoomUi(room: HouseRoom.goals, child: Text('card'))),
      );
      expect(find.byType(Opacity), findsNothing);
      expect(find.text('card'), findsOneWidget);
    });

    testWidgets('under the travel stack it fades with the dock, state kept', (
      tester,
    ) async {
      final tab = ValueNotifier(1);
      addTearDown(tab.dispose);
      var builds = 0;
      await tester.pumpWidget(
        _host(
          ValueListenableBuilder<int>(
            valueListenable: tab,
            builder: (context, index, _) => HouseTravelStack(
              index: index,
              reduceMotion: false,
              children: [
                for (final room in HouseRoom.values)
                  HouseRoomUi(
                    room: room,
                    child: Builder(
                      builder: (context) {
                        if (room == HouseRoom.plans) builds++;
                        return Text(room.label);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      final built = builds;
      tab.value = 3;
      await tester.pump();
      double plansUi() => tester
          .widget<Opacity>(
            find.descendant(
              of: find.ancestor(
                of: find.text('Plans'),
                matching: find.byType(HouseRoomUi),
              ),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;
      expect(plansUi(), 0);
      await tester.pump(const Duration(milliseconds: 900));
      expect(plansUi(), 1);
      // The room's own subtree was not rebuilt by the travel.
      expect(builds - built, lessThanOrEqualTo(2));
    });
  });

  group('the glint over the Goals sign', () {
    testWidgets('sweeps once, after the cone opens, then is gone', (
      tester,
    ) async {
      final tab = ValueNotifier(1);
      addTearDown(tab.dispose);
      await tester.pumpWidget(
        _host(
          ValueListenableBuilder<int>(
            valueListenable: tab,
            builder: (context, index, _) => HouseTravelStack(
              index: index,
              reduceMotion: false,
              children: [
                for (final room in HouseRoom.values)
                  room == HouseRoom.goals
                      ? const HouseGlintSweep(
                          child: SizedBox(
                            key: Key('sign'),
                            width: 120,
                            height: 60,
                          ),
                        )
                      : const SizedBox(),
              ],
            ),
          ),
        ),
      );
      CustomPaint sweep() => tester.widget<CustomPaint>(
        find
            .ancestor(
              of: find.byKey(const Key('sign'), skipOffstage: false),
              matching: find.byType(CustomPaint, skipOffstage: false),
            )
            .first,
      );
      expect(sweep().foregroundPainter, isNull);
      tab.value = HouseRoom.goals.index;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(sweep().foregroundPainter, isNull, reason: 'catches it last');
      final start = 740 * houseGlintDelayShare + houseGlintDelayMs;
      await tester.pump(
        Duration(milliseconds: (start + houseGlintMs / 2 - 300).round()),
      );
      expect(sweep().foregroundPainter, isNotNull);
      await tester.pump(const Duration(milliseconds: 700));
      expect(sweep().foregroundPainter, isNull);
    });
  });
}
