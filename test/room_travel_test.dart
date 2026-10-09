// Everyday movement (owner direction 2026-10-03): no blur and no rush on the
// dock or on ordinary pushed pages. The dock is a 120 ms cross-dissolve that
// keeps every room mounted and redirects from the picture on screen; iOS
// pushes are the native Cupertino slide with nothing layered on; Reduced
// Motion is a plain fade that keeps the edge-swipe. The Goals walk
// (goalRoomRoute, GoalRoomTravelBackdrop, the opening) is not covered here.
import 'package:emberkeep/widgets/room_travel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _frame = Duration(microseconds: 16667);

/// initState count per room, so a remount is visible.
final Map<int, int> _mounts = {};
final List<int> _taps = [];

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
      child: Center(
        child: GestureDetector(
          onTap: () => _taps.add(widget.index),
          child: SizedBox(
            width: 200,
            height: 80,
            child: Text('room ${widget.index}'),
          ),
        ),
      ),
    );
  }
}

Future<ValueNotifier<int>> _pumpDock(
  WidgetTester tester, {
  bool disableAnimations = false,
}) async {
  final tab = ValueNotifier<int>(1);
  addTearDown(tab.dispose);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<int>(
          valueListenable: tab,
          builder: (context, index, _) => RoomTravelStack(
            index: index,
            children: [for (var i = 0; i < 5; i++) _Room(i)],
          ),
        ),
      ),
    ),
  );
  return tab;
}

/// Each staged room's opacity, keyed by room index (offstage rooms absent).
Map<int, double> _paneOpacities(WidgetTester tester) {
  final stack = tester.widget<Stack>(
    find
        .descendant(
          of: find.byType(RoomTravelStack),
          matching: find.byType(Stack),
        )
        .first,
  );
  final out = <int, double>{};
  for (final (i, child) in stack.children.indexed) {
    final offstage = child as Offstage;
    if (offstage.offstage) continue;
    Widget? w = offstage;
    while (w != null && w is! Opacity) {
      w = (w as dynamic).child as Widget?;
    }
    out[i] = (w! as Opacity).opacity;
  }
  return out;
}

/// What the eye sees: each room's share of the composited picture (higher
/// index paints on top), plus what shows through from behind the rooms.
({Map<int, double> rooms, double behind}) _picture(WidgetTester tester) {
  final opacities = _paneOpacities(tester);
  final rooms = <int, double>{};
  var remaining = 1.0;
  for (final room in opacities.keys.toList()..sort((a, b) => b.compareTo(a))) {
    rooms[room] = opacities[room]! * remaining;
    remaining *= 1 - opacities[room]!;
  }
  return (rooms: rooms, behind: remaining);
}

void _expectNoBlurOrTravel(WidgetTester tester) {
  expect(find.byType(ImageFiltered), findsNothing);
  expect(find.byType(BackdropFilter), findsNothing);
  expect(
    find.descendant(
      of: find.byType(RoomTravelStack),
      matching: find.byType(Transform),
    ),
    findsNothing,
  );
}

double _fadeOf(WidgetTester tester, Key key) => tester
    .widgetList<FadeTransition>(
      find.ancestor(of: find.byKey(key), matching: find.byType(FadeTransition)),
    )
    .map((f) => f.opacity.value)
    .fold(1.0, (a, b) => a * b);

void main() {
  setUp(() {
    _mounts.clear();
    _taps.clear();
    _Mounted.count.clear();
    RoomTravel.reduceMotion = false;
  });
  tearDown(() => RoomTravel.reduceMotion = false);

  group('dock rooms', () {
    testWidgets('change at once through a 120 ms dissolve, nothing moving', (
      tester,
    ) async {
      final tab = await _pumpDock(tester);
      for (final room in [0, 3, 1]) {
        tab.value = room;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(_paneOpacities(tester), {room: 1.0});
      }
      // Every room was built once; switching never builds them again.
      expect(_mounts, {0: 1, 1: 1, 2: 1, 3: 1, 4: 1});

      tab.value = 3;
      // The tap's own frame: the new room is built (a first visit lazily
      // builds it here) and staged at zero, so its first layout is unseen.
      await tester.pump();
      expect(_picture(tester).rooms, {1: 1.0, 3: 0.0});
      await tester.pump(_frame); // +17 ms: the first visible step
      final first = _picture(tester).rooms;
      expect(first[3], inInclusiveRange(0.45, 0.6));
      expect(first[1]! + first[3]!, closeTo(1, 1e-9));
      _expectNoBlurOrTravel(tester);
      await tester.pump(_frame); // +33 ms
      expect(_picture(tester).rooms[3], greaterThan(0.75));
      await tester.pump(_frame); // +50 ms: only a faint trace is left
      expect(_picture(tester).rooms[3], greaterThan(0.9));
      await tester.pump(const Duration(milliseconds: 70)); // +120 ms
      expect(_paneOpacities(tester), {3: 1.0});
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('room 1'), findsNothing);
      expect(find.text('room 1', skipOffstage: false), findsOneWidget);
      expect(_mounts, {0: 1, 1: 1, 2: 1, 3: 1, 4: 1});
    });

    testWidgets('never dips or flashes, in either direction or a redirect', (
      tester,
    ) async {
      final tab = await _pumpDock(tester);
      for (final step in [3, 0, 4]) {
        tab.value = step;
        for (var f = 0; f < 4; f++) {
          await tester.pump(f == 0 ? Duration.zero : _frame);
          final picture = _picture(tester);
          // The lowest staged room is opaque, so nothing shows through.
          expect(picture.behind, closeTo(0, 1e-9));
          expect(
            picture.rooms.values.fold(0.0, (a, b) => a + b),
            closeTo(1, 1e-9),
          );
        }
      }
    });

    testWidgets('a tap mid-dissolve redirects from the picture on screen', (
      tester,
    ) async {
      final tab = await _pumpDock(tester);
      tab.value = 3;
      await tester.pump();
      await tester.pump(_frame); // +17 ms, rooms 1 and 3 mixed
      final before = _picture(tester).rooms;
      expect(before.keys.toSet(), {1, 3});

      tab.value = 4; // redirect
      await tester.pump(); // same instant: the picture must not jump
      final at = _picture(tester).rooms;
      expect(at[1], closeTo(before[1]!, 1e-9));
      expect(at[3], closeTo(before[3]!, 1e-9));
      expect(at[4] ?? 0, closeTo(0, 1e-9));

      await tester.pump(_frame); // the new room arrives on the next frame,
      final next = _picture(tester).rooms; // exactly as it would from rest
      expect(next[4], inInclusiveRange(0.45, 0.6));
      // The rooms already on screen keep their proportions as they go.
      expect(next[1]! / next[3]!, closeTo(before[1]! / before[3]!, 1e-6));
      _expectNoBlurOrTravel(tester);

      await tester.pump(const Duration(milliseconds: 110));
      expect(_paneOpacities(tester), {4: 1.0});
      expect(_mounts.values.every((n) => n == 1), isTrue);
    });

    testWidgets('a tap back to the room being left reverses smoothly', (
      tester,
    ) async {
      final tab = await _pumpDock(tester);
      tab.value = 3;
      await tester.pump();
      await tester.pump(_frame);
      final before = _picture(tester).rooms;
      tab.value = 1;
      await tester.pump();
      final at = _picture(tester).rooms;
      expect(at[1], closeTo(before[1]!, 1e-9));
      expect(at[3], closeTo(before[3]!, 1e-9));
      await tester.pump(_frame);
      expect(_picture(tester).rooms[1], greaterThan(before[1]!));
      await tester.pump(const Duration(milliseconds: 120));
      expect(_paneOpacities(tester), {1: 1.0});
    });

    testWidgets(
      'only the room being entered takes a tap, from the first frame',
      (tester) async {
        final tab = await _pumpDock(tester);
        tab.value = 3;
        await tester.pump();
        await tester.tapAt(tester.getCenter(find.text('room 3')));
        await tester.pump(_frame);
        await tester.tapAt(tester.getCenter(find.text('room 3')));
        await tester.pump(const Duration(milliseconds: 200));
        expect(_taps, [3, 3]);
      },
    );

    testWidgets('Reduced Motion (in-app) switches in one frame', (
      tester,
    ) async {
      RoomTravel.reduceMotion = true;
      final tab = await _pumpDock(tester);
      tab.value = 3;
      await tester.pump();
      expect(_paneOpacities(tester), {3: 1.0});
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('Reduced Motion (system) switches in one frame', (
      tester,
    ) async {
      final tab = await _pumpDock(tester, disableAnimations: true);
      tab.value = 0;
      await tester.pump();
      expect(_paneOpacities(tester), {0: 1.0});
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

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
