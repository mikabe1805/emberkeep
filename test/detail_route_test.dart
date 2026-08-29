import 'package:emberkeep/widgets/detail_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RouteObserver extends NavigatorObserver {
  Route<dynamic>? lastPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushed = route;
    super.didPush(route, previousRoute);
  }
}

Widget _host({
  required bool reduceMotion,
  required _RouteObserver observer,
  bool withBackdrop = false,
}) {
  return MaterialApp(
    navigatorObservers: [observer],
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).push<void>(
              detailRoute<void>(
                context: context,
                reduceMotion: reduceMotion,
                transitionBackdrop: withBackdrop
                    ? const ColoredBox(
                        key: Key('threshold-room-art'),
                        color: Color(0xFF24150E),
                      )
                    : null,
                builder: (_) => const Scaffold(body: Text('Detail')),
              ),
            ),
            child: const Text('Open detail'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('detail route uses the restrained shared-axis transition', (
    tester,
  ) async {
    final observer = _RouteObserver();
    await tester.pumpWidget(_host(reduceMotion: false, observer: observer));

    await tester.tap(find.text('Open detail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    final route = observer.lastPushed! as PageRoute<dynamic>;
    expect(route.transitionDuration, const Duration(milliseconds: 320));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 260));
    expect(find.byKey(const Key('detail-route-fade')), findsOneWidget);
    expect(find.byKey(const Key('detail-route-shared-axis')), findsOneWidget);
    expect(find.byKey(const Key('detail-route-scale')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsOneWidget);
  });

  testWidgets('detail route reduces to a short fade without spatial motion', (
    tester,
  ) async {
    final observer = _RouteObserver();
    await tester.pumpWidget(_host(reduceMotion: true, observer: observer));

    await tester.tap(find.text('Open detail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    final route = observer.lastPushed! as PageRoute<dynamic>;
    expect(route.transitionDuration, const Duration(milliseconds: 90));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 80));
    expect(find.byKey(const Key('detail-route-fade')), findsOneWidget);
    expect(find.byKey(const Key('detail-route-shared-axis')), findsNothing);
    expect(find.byKey(const Key('detail-route-scale')), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsOneWidget);
  });

  testWidgets('threshold route holds the room before detail resolves', (
    tester,
  ) async {
    final observer = _RouteObserver();
    await tester.pumpWidget(
      _host(reduceMotion: false, observer: observer, withBackdrop: true),
    );

    await tester.tap(find.text('Open detail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final route = observer.lastPushed! as PageRoute<dynamic>;
    expect(route.transitionDuration, const Duration(milliseconds: 420));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 360));
    expect(find.byKey(const Key('threshold-room-art')), findsOneWidget);
    expect(
      find.byKey(const Key('detail-route-threshold-travel')),
      findsOneWidget,
    );
    final fade = tester.widget<FadeTransition>(
      find.byKey(const Key('detail-route-fade')),
    );
    expect(fade.opacity.value, 0);

    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsOneWidget);
  });

  testWidgets('reduced-motion threshold is a short same-room fade', (
    tester,
  ) async {
    final observer = _RouteObserver();
    await tester.pumpWidget(
      _host(reduceMotion: true, observer: observer, withBackdrop: true),
    );

    await tester.tap(find.text('Open detail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    final route = observer.lastPushed! as PageRoute<dynamic>;
    expect(route.transitionDuration, const Duration(milliseconds: 180));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 150));
    expect(find.byKey(const Key('threshold-room-art')), findsOneWidget);
    expect(
      find.byKey(const Key('detail-route-threshold-travel')),
      findsNothing,
    );
    expect(find.byKey(const Key('detail-route-shared-axis')), findsNothing);
    expect(find.byKey(const Key('detail-route-scale')), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsOneWidget);
  });
}
