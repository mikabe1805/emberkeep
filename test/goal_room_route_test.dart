import 'package:emberkeep/widgets/goal_room_route.dart';
import 'package:emberkeep/widgets/goal_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Goals dolly: the workshop, the kitchen and the quest handoff all travel
/// the same calm route, with no motion blur. (The kitchen walk through the lit
/// arch was retired with the house; this is the one route that is left.)
void main() {
  Future<NavigatorState> pumpHost(
    WidgetTester tester, {
    bool reduceMotion = false,
    VoidCallback? onArrival,
    Duration arrivalHold = Duration.zero,
  }) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    const room = ColoredBox(
      key: Key('route-host-room'),
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
                key: const Key('route-host-open'),
                onPressed: () => Navigator.of(context).push(
                  goalRoomRoute<void>(
                    context: context,
                    reduceMotion: reduceMotion,
                    onArrival: onArrival,
                    arrivalHold: arrivalHold,
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

  const frame = Duration(microseconds: 16667);

  testWidgets(
    'the workshop and quest handoff keep the calm dolly, with no blur',
    (tester) async {
      var arrived = 0;
      await pumpHost(
        tester,
        onArrival: () => arrived++,
        arrivalHold: const Duration(milliseconds: 360),
      );
      await tester.tap(find.byKey(const Key('route-host-open')));
      await tester.pump();
      for (var i = 0; i < 120; i++) {
        await tester.pump(frame);
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
      expect(find.byKey(const Key('route-host-room')), findsOneWidget);
      expect(arrived, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('information waits for the arrival, then the page is whole', (
    tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.byKey(const Key('route-host-open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final mid = tester.widget<Opacity>(
      find.byKey(const ValueKey('goal-room-travel-foreground')),
    );
    expect(mid.opacity, 0, reason: 'the page is not read while travelling');
    await tester.pumpAndSettle();
    final done = tester.widget<Opacity>(
      find.byKey(const ValueKey('goal-room-travel-foreground')),
    );
    expect(done.opacity, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced Motion is a plain fade with no dolly', (tester) async {
    await pumpHost(tester, reduceMotion: true);
    await tester.tap(find.byKey(const Key('route-host-open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      find.byKey(const ValueKey('goal-room-reduced-motion-fade')),
      findsOneWidget,
    );
    expect(find.byType(GoalRoomTravelBackdrop), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('route-host-room')), findsOneWidget);
  });

  testWidgets('leaving walks back to the desk and drops the room', (
    tester,
  ) async {
    final navigator = await pumpHost(tester);
    await tester.tap(find.byKey(const Key('route-host-open')));
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('route-host-room')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
