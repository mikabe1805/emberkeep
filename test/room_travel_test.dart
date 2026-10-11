// Everyday movement on ordinary pushed pages (owner direction 2026-10-03): no
// blur and no rush. iOS pushes are the native Cupertino slide with nothing
// layered on; Reduced Motion is a plain fade that keeps the edge-swipe. The
// dock is not here: each room arrives through its own light (test/house/).
// The Goals walk (goalRoomRoute, GoalRoomTravelBackdrop, the opening) is not
// covered here.
import 'package:emberkeep/widgets/room_travel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _frame = Duration(microseconds: 16667);

double _fadeOf(WidgetTester tester, Key key) => tester
    .widgetList<FadeTransition>(
      find.ancestor(of: find.byKey(key), matching: find.byType(FadeTransition)),
    )
    .map((f) => f.opacity.value)
    .fold(1.0, (a, b) => a * b);

void main() {
  setUp(() {
    _Mounted.count.clear();
    RoomTravel.reduceMotion = false;
  });
  tearDown(() => RoomTravel.reduceMotion = false);

  group('pushed pages', () {
    const homeKey = Key('home-page');
    const detailKey = Key('detail-page');
    const theme = PageTransitionsTheme(
      builders: {
        TargetPlatform.android: RoomPageTransitionsBuilder(),
        TargetPlatform.iOS: RoomCupertinoPageTransitionsBuilder(),
      },
    );

    Future<void> pumpApp(WidgetTester tester, {bool fullscreen = false}) {
      return tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(pageTransitionsTheme: theme),
          home: Builder(
            builder: (context) => Scaffold(
              key: homeKey,
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: fullscreen,
                      builder: (_) => const Scaffold(
                        key: detailKey,
                        body: Center(child: _Mounted('detail')),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    ModalRoute<dynamic> topRoute(WidgetTester tester) => ModalRoute.of(
      tester.element(find.byKey(detailKey, skipOffstage: false)),
    )!;

    Future<void> withIOS(Future<void> Function() body) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await body();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    testWidgets('iOS: the native Cupertino slide, 500 ms, nothing layered on', (
      tester,
    ) async {
      await withIOS(() async {
        await pumpApp(tester);
        final width = tester.getSize(find.byKey(homeKey)).width;
        await tester.tap(find.text('open'));
        await tester.pump();
        final route = topRoute(tester) as TransitionRoute;
        expect(route.transitionDuration, const Duration(milliseconds: 500));
        expect(
          route.reverseTransitionDuration,
          const Duration(milliseconds: 500),
        );
        // Moving on the first frame after the tap.
        await tester.pump(_frame);
        expect(tester.getTopLeft(find.byKey(detailKey)).dx, lessThan(width));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(ImageFiltered), findsNothing);
        expect(
          tester.getTopLeft(find.byKey(detailKey)).dx,
          inExclusiveRange(0, width),
        );
        // The covered page slides part of the way under it (parallax).
        expect(tester.getTopLeft(find.byKey(homeKey)).dx, lessThan(0));
        expect(_fadeOf(tester, detailKey), 1);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byKey(detailKey)).dx, 0);
        expect(find.byType(ImageFiltered), findsNothing);
      });
    });

    testWidgets('iOS: the edge-swipe tracks the finger and pops', (
      tester,
    ) async {
      await withIOS(() async {
        await pumpApp(tester);
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final gesture = await tester.startGesture(const Offset(4, 300));
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(420, 0));
        await tester.pump();
        // Past half of the 800 px test surface, so release pops.
        expect(tester.getTopLeft(find.byKey(detailKey)).dx, closeTo(450, 2));
        expect(find.byType(ImageFiltered), findsNothing);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.byKey(detailKey), findsNothing);
        expect(tester.getTopLeft(find.byKey(homeKey)).dx, 0);
      });
    });

    testWidgets(
      'iOS Reduced Motion: push and pop fade in place; the swipe still works',
      (tester) async {
        await withIOS(() async {
          RoomTravel.reduceMotion = true;
          await pumpApp(tester);
          await tester.tap(find.text('open'));
          await tester.pump();
          expect(
            (topRoute(tester) as TransitionRoute).transitionDuration,
            RoomTravel.stillRouteIn,
          );
          await tester.pump(const Duration(milliseconds: 60));
          expect(tester.getTopLeft(find.byKey(detailKey)).dx, 0);
          expect(tester.getTopLeft(find.byKey(homeKey)).dx, 0);
          expect(_fadeOf(tester, detailKey), inExclusiveRange(0.2, 1));
          await tester.pumpAndSettle();
          expect(_fadeOf(tester, detailKey), 1);

          // The swipe follows the hand even here.
          final gesture = await tester.startGesture(const Offset(4, 300));
          await gesture.moveBy(const Offset(30, 0));
          await tester.pump();
          await gesture.moveBy(const Offset(420, 0));
          await tester.pump();
          expect(tester.getTopLeft(find.byKey(detailKey)).dx, closeTo(450, 2));
          expect(_fadeOf(tester, detailKey), 1);
          await gesture.up();
          await tester.pumpAndSettle();
          expect(find.byKey(detailKey), findsNothing);
          expect(tester.getTopLeft(find.byKey(homeKey)).dx, 0);

          // A button pop fades out in place.
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          Navigator.of(tester.element(find.byKey(detailKey))).pop();
          await tester.pump();
          expect(
            (topRoute(tester) as TransitionRoute).reverseTransitionDuration,
            RoomTravel.stillRouteOut,
          );
          await tester.pump(const Duration(milliseconds: 60));
          expect(tester.getTopLeft(find.byKey(detailKey)).dx, 0);
          expect(_fadeOf(tester, detailKey), inExclusiveRange(0, 1));
          await tester.pumpAndSettle();
          expect(find.byKey(detailKey), findsNothing);
        });
      },
    );

    testWidgets('iOS Reduced Motion: a cancelled swipe settles back opaque', (
      tester,
    ) async {
      await withIOS(() async {
        RoomTravel.reduceMotion = true;
        await pumpApp(tester);
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final gesture = await tester.startGesture(const Offset(4, 300));
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(90, 0));
        await tester.pump();
        expect(tester.getTopLeft(find.byKey(detailKey)).dx, closeTo(120, 2));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.byKey(detailKey), findsOneWidget);
        expect(tester.getTopLeft(find.byKey(detailKey)).dx, 0);
        expect(_fadeOf(tester, detailKey), 1);
      });
    });

    testWidgets(
      'iOS: switching Reduced Motion with a page open remounts nothing',
      (tester) async {
        await withIOS(() async {
          await pumpApp(tester);
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          Element transitionOf(Key key) => tester.element(
            find
                .ancestor(
                  of: find.byKey(key, skipOffstage: false),
                  matching: find.byType(
                    CupertinoPageTransition,
                    skipOffstage: false,
                  ),
                )
                .first,
          );
          final home = transitionOf(homeKey);
          final detail = transitionOf(detailKey);
          expect(_Mounted.count['detail'], 1);

          RoomTravel.reduceMotion = true;
          Navigator.of(tester.element(find.byKey(detailKey))).pop();
          await tester.pump();
          await tester.pump(_frame);
          expect(identical(transitionOf(homeKey), home), isTrue);
          expect(identical(transitionOf(detailKey), detail), isTrue);
          expect(_Mounted.count['detail'], 1);
          await tester.pumpAndSettle();
          expect(find.byKey(detailKey), findsNothing);
        });
      },
    );

    for (final reduced in [false, true]) {
      testWidgets(
        'iOS: a custom-route page under an ordinary push '
        '${reduced ? 'stays still with Reduced Motion' : 'takes the native parallax'}',
        (tester) async {
          await withIOS(() async {
            RoomTravel.reduceMotion = reduced;
            const roomKey = Key('custom-room');
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(pageTransitionsTheme: theme),
                home: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Navigator.of(context).push(
                      PageRouteBuilder<void>(
                        pageBuilder: (context, _, _) => Scaffold(
                          key: roomKey,
                          body: Center(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const Scaffold(
                                    key: detailKey,
                                    body: Text('detail'),
                                  ),
                                ),
                              ),
                              child: const Text('deeper'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('room'),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('room'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('deeper'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            final x = tester.getTopLeft(find.byKey(roomKey)).dx;
            if (reduced) {
              expect(x, 0);
            } else {
              expect(x, lessThan(0));
            }
            await tester.pumpAndSettle();
            expect(find.byKey(detailKey), findsOneWidget);
            expect(tester.getTopLeft(find.byKey(detailKey)).dx, 0);
          });
        },
      );
    }

    testWidgets('iOS: a full-screen sheet rises natively, or fades in place', (
      tester,
    ) async {
      await withIOS(() async {
        await pumpApp(tester, fullscreen: true);
        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.getTopLeft(find.byKey(detailKey)).dy, greaterThan(0));
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byKey(detailKey))).pop();
        await tester.pumpAndSettle();

        RoomTravel.reduceMotion = true;
        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        expect(tester.getTopLeft(find.byKey(detailKey)), Offset.zero);
        expect(_fadeOf(tester, detailKey), inExclusiveRange(0.2, 1));
        await tester.pumpAndSettle();
        expect(find.byKey(detailKey), findsOneWidget);
      });
    });

    testWidgets(
      'other platforms: 300 ms fade and short rise, no blur, the room beneath stays',
      (tester) async {
        await pumpApp(tester);
        await tester.tap(find.text('open'));
        await tester.pump();
        final route = topRoute(tester) as TransitionRoute;
        expect(route.transitionDuration, const Duration(milliseconds: 300));
        expect(
          route.reverseTransitionDuration,
          const Duration(milliseconds: 300),
        );
        await tester.pump(const Duration(milliseconds: 50));
        final y = tester.getTopLeft(find.byKey(detailKey)).dy;
        expect(y, inExclusiveRange(0, RoomPageTransitionsBuilder.rise));
        expect(_fadeOf(tester, detailKey), inExclusiveRange(0, 1));
        expect(find.byType(ImageFiltered), findsNothing);
        expect(tester.getTopLeft(find.byKey(homeKey)), Offset.zero);
        expect(_fadeOf(tester, homeKey), 1);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byKey(detailKey)), Offset.zero);
      },
    );

    testWidgets('other platforms, Reduced Motion: a quick fade with no rise', (
      tester,
    ) async {
      RoomTravel.reduceMotion = true;
      await pumpApp(tester);
      await tester.tap(find.text('open'));
      await tester.pump();
      expect(
        (topRoute(tester) as TransitionRoute).transitionDuration,
        RoomTravel.stillRouteIn,
      );
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.getTopLeft(find.byKey(detailKey)), Offset.zero);
      expect(_fadeOf(tester, detailKey), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(_fadeOf(tester, detailKey), 1);
    });
  });
}

/// Counts initState per label, so a remounted page is visible.
class _Mounted extends StatefulWidget {
  const _Mounted(this.label);
  final String label;

  static final Map<String, int> count = {};

  @override
  State<_Mounted> createState() => _MountedState();
}

class _MountedState extends State<_Mounted> {
  @override
  void initState() {
    super.initState();
    _Mounted.count.update(widget.label, (n) => n + 1, ifAbsent: () => 1);
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}
