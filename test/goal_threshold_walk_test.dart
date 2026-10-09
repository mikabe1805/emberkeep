import 'package:emberkeep/widgets/goal_room_route.dart';
import 'package:emberkeep/widgets/goal_threshold_walk.dart';
import 'package:emberkeep/widgets/goal_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The kitchen walk through the lit arch (2026-10-03 "walk-threshold" pass,
/// shipped for the kitchen only). The workshop, the quest handoff and the
/// one-time opening keep the calm dolly.
void main() {
  group('gait', () {
    const gait = GoalWalkGait();

    test('starts moving at once, keeps a steady middle, arrives softly', () {
      expect(gait.transform(0), 0);
      expect(gait.transform(1), closeTo(1, 1e-9));
      var previous = 0.0;
      for (var i = 1; i <= 200; i++) {
        final t = i / 200;
        final value = gait.transform(t);
        expect(value, greaterThanOrEqualTo(previous));
        previous = value;
        // The closed-form speed is the true derivative (no strobing blur).
        if (i < 200) {
          const h = 1e-5;
          final numeric =
              (gait.transform(t + h) - gait.transform(t - h)) / (2 * h);
          expect(gait.velocity(t), closeTo(numeric, 1e-3));
        }
      }
      // Weight already moving when the finger lifts, but not a lunge.
      expect(gait.velocity(0), greaterThan(0));
      expect(gait.velocity(0), lessThan(gait.velocity(0.4) * 0.5));
      // A steady middle.
      expect(gait.velocity(0.3), closeTo(gait.velocity(0.5), 1e-9));
      // A soft arrival.
      expect(gait.velocity(1), closeTo(0, 1e-9));
    });

    test('the last creep onto the kitchen is about a third shorter', () {
      // "Creep" is the time spent covering the last 9% of the walk. The first
      // walk-threshold build (slowing from 56%) spent about 251 ms of a 963 ms
      // walk there; this one keeps it near 170 ms of an 830 ms walk.
      const walkMs = 830.0;
      var t = 1.0;
      while (gait.transform(t) > 0.91) {
        t -= 0.0005;
      }
      expect((1 - t) * walkMs, lessThan(251 * 0.72));
      expect((1 - t) * walkMs, greaterThan(120), reason: 'still a soft stop');
    });
  });

  group('geometry', () {
    const size = Size(393, 852);
    final box = GoalsKitchenFrame.heroBox(size, compact: false);
    final walk = GoalThresholdWalk(size: size, kitchenBox: box);

    test('the arch is near and the room beyond is far', () {
      var ratio = 1.0;
      for (final w in [0.25, 0.5, 0.75, 1.0]) {
        final next = walk.nearMag(w) / walk.farMag(w);
        expect(next, greaterThan(ratio));
        ratio = next;
      }
      expect(ratio, greaterThan(2.5));
      // The doorway accelerates out of frame as you near it.
      final early = walk.nearMag(0.25) - walk.nearMag(0);
      final late = walk.nearMag(1) - walk.nearMag(0.75);
      expect(late, greaterThan(early * 3));
    });

    test('the walk lands exactly on the goal page framing', () {
      final arrived = walk.kitchen(1);
      final page = GoalsKitchenFrame.forBox(box).affineIn(box);
      expect(arrived.s, closeTo(page.s, 1e-9));
      expect(arrived.o.dx, closeTo(page.o.dx, 1e-6));
      expect(arrived.o.dy, closeTo(page.o.dy, 1e-6));
    });

    test('the first walking frame is the resting Goals room', () {
      final desk = GoalRoomFraming.desk.masterAffine(size);
      expect(walk.near(0).s, closeTo(desk.s, 1e-9));
      expect(walk.bridge(0).o.dx, closeTo(desk.o.dx, 1e-9));
      expect(walk.bridge(0).o.dy, closeTo(desk.o.dy, 1e-9));
      expect(walk.bridgeOpacity(0), 1);
    });

    test('the arch only streaks while it is moving across the frame', () {
      expect(goalWalkStreakSigma(walk.edgeSpeed(0.5, 0)), Offset.zero);
      final moving = goalWalkStreakSigma(walk.edgeSpeed(0.5, 1.2));
      expect(moving.dx + moving.dy, greaterThan(0.2));
      expect(moving.dx, lessThanOrEqualTo(5));
      expect(moving.dy, lessThanOrEqualTo(5));
    });
  });

  group('route', () {
    Future<NavigatorState> pumpHost(
      WidgetTester tester, {
      bool reduceMotion = false,
      bool dolly = false,
      VoidCallback? onArrival,
      Duration arrivalHold = Duration.zero,
    }) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      const room = ColoredBox(
        key: Key('walk-host-room'),
        color: Color(0xFF221A14),
        child: SizedBox.expand(),
      );
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const Key('walk-host-open'),
                  onPressed: () => Navigator.of(context).push(
                    dolly
                        ? goalRoomRoute<void>(
                            context: context,
                            reduceMotion: reduceMotion,
                            onArrival: onArrival,
                            arrivalHold: arrivalHold,
                            builder: (_) => room,
                          )
                        : goalKitchenWalkRoute<void>(
                            context: context,
                            reduceMotion: reduceMotion,
                            builder: (_) => room,
                          ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      return navigatorKey.currentState!;
    }

    double walkNow(WidgetTester tester) {
      final backdrops = tester.widgetList<GoalKitchenWalkBackdrop>(
        find.byType(GoalKitchenWalkBackdrop),
      );
      return backdrops.isEmpty ? -1 : backdrops.last.progress;
    }

    double pageOpacity(WidgetTester tester) => tester
        .widget<Opacity>(
          find.byKey(const ValueKey('goal-room-travel-foreground')),
        )
        .opacity;

    const frame = Duration(microseconds: 16667);

    testWidgets('walks in at walking pace and shows the room only on arrival', (
      tester,
    ) async {
      await pumpHost(tester);
      await tester.tap(find.byKey(const Key('walk-host-open')));
      await tester.pump();

      var previous = 0.0;
      var maxStep = 0.0;
      var sawWalkWithoutPage = false;
      for (var i = 0; i < 50; i++) {
        await tester.pump(frame);
        final w = walkNow(tester);
        expect(w, greaterThanOrEqualTo(previous - 1e-9));
        maxStep = w - previous > maxStep ? w - previous : maxStep;
        previous = w;
        if (w > 0.2 && w < 0.9) {
          sawWalkWithoutPage |= pageOpacity(tester) == 0;
          expect(pageOpacity(tester), 0, reason: 'information on arrival only');
        }
      }
      expect(sawWalkWithoutPage, isTrue);
      // No lunge: the walk never covers more than ~3% of the way per frame.
      expect(maxStep, lessThan(0.03));
      await tester.pump(goalRoomWalkDuration);
      await tester.pump();
      expect(pageOpacity(tester), 1);
      expect(
        find.byKey(const ValueKey('goal-room-travel-motion-blur')),
        findsNothing,
        reason: 'the arrived room is completely crisp',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the walk takes under a second', (tester) async {
      await pumpHost(tester);
      await tester.tap(find.byKey(const Key('walk-host-open')));
      await tester.pump();
      expect(goalRoomWalkDuration.inMilliseconds, inInclusiveRange(700, 1000));
      await tester.pump(goalRoomWalkDuration * 0.5);
      expect(walkNow(tester), inExclusiveRange(0.3, 0.85));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('walk-host-room')), findsOneWidget);
    });

    testWidgets('the kitchen walk streaks the arch only while it moves', (
      tester,
    ) async {
      await pumpHost(tester);
      await tester.tap(find.byKey(const Key('walk-host-open')));
      await tester.pump();
      var sawStreak = false;
      for (var i = 0; i < 50; i++) {
        await tester.pump(frame);
        sawStreak |= find
            .byKey(const ValueKey('goal-room-travel-motion-blur'))
            .evaluate()
            .isNotEmpty;
      }
      expect(sawStreak, isTrue, reason: 'passing the doorway is felt');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('goal-room-travel-motion-blur')),
        findsNothing,
      );
    });

    testWidgets('back during the walk turns around without a jump', (
      tester,
    ) async {
      final navigator = await pumpHost(tester);
      await tester.tap(find.byKey(const Key('walk-host-open')));
      await tester.pump();
      for (var i = 0; i < 24; i++) {
        await tester.pump(frame);
      }
      final before = walkNow(tester);
      expect(before, greaterThan(0.15));
      navigator.pop();
      var previous = before;
      var maxJump = 0.0;
      var peak = before;
      var peakFrame = 0;
      for (var i = 0; i < 90; i++) {
        await tester.pump(frame);
        final w = walkNow(tester);
        if (w < 0) break;
        maxJump = (w - previous).abs() > maxJump
            ? (w - previous).abs()
            : maxJump;
        if (w > peak) {
          peak = w;
          peakFrame = i;
        }
        previous = w;
      }
      expect(maxJump, lessThan(0.04), reason: 'no position jump on turning');
      // The forward step eases out within about a tenth of a second (no
      // instant reversal, no long drift) before you walk back.
      expect(peak - before, lessThan(0.09), reason: 'momentum eases out');
      expect(peakFrame, lessThanOrEqualTo(8), reason: 'the turn is prompt');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(GoalKitchenWalkBackdrop), findsNothing);
      expect(find.byKey(const Key('walk-host-room')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('walking back out lifts the page, then returns to the desk', (
      tester,
    ) async {
      final navigator = await pumpHost(tester);
      await tester.tap(find.byKey(const Key('walk-host-open')));
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pump();
      // The first step comes as the page lifts: no dead hold.
      for (var i = 0; i < 9; i++) {
        await tester.pump(frame);
      }
      expect(walkNow(tester), lessThan(0.99));
      expect(pageOpacity(tester), lessThan(0.2));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('walk-host-room')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Reduced Motion is a plain fade with no walk', (tester) async {
      await pumpHost(tester, reduceMotion: true);
      await tester.tap(find.byKey(const Key('walk-host-open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(
        find.byKey(const ValueKey('goal-room-reduced-motion-fade')),
        findsOneWidget,
      );
      expect(find.byType(GoalKitchenWalkBackdrop), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('walk-host-room')), findsOneWidget);
    });

    testWidgets(
      'the workshop and quest handoff keep the calm dolly, with no blur',
      (tester) async {
        var arrived = 0;
        await pumpHost(
          tester,
          dolly: true,
          onArrival: () => arrived++,
          arrivalHold: const Duration(milliseconds: 360),
        );
        await tester.tap(find.byKey(const Key('walk-host-open')));
        await tester.pump();
        for (var i = 0; i < 120; i++) {
          await tester.pump(frame);
          expect(find.byType(GoalKitchenWalkBackdrop), findsNothing);
          expect(find.byType(GoalRoomTravelBackdrop), findsOneWidget);
          expect(
            find.byKey(const ValueKey('goal-room-travel-motion-blur')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('goal-room-travel-destination-blur')),
            findsNothing,
          );
        }
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('walk-host-room')), findsOneWidget);
        expect(arrived, 1);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
