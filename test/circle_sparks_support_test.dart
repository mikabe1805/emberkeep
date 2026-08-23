import 'dart:async';
import 'dart:io';

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/discovery.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/screens/hearth_circle.dart';
import 'package:emberkeep/screens/shell.dart';
import 'package:emberkeep/social.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preset Spark copy names the received kinds', () {
    expect(sparkSupportKinds, const ['kindle', 'steady', 'cheer']);
    expect(sparkSupportTitle('kindle'), 'A little warmth');
    expect(sparkSupportTitle('steady'), 'Keep steady');
    expect(sparkSupportTitle('cheer'), 'Cheering you on');
    expect(normalizedSparkKind('not-allowed'), 'kindle');

    expect(
      sparkSupportNoticeText(const ['kindle', 'cheer', 'cheer']),
      'Circle has a little warmth and 2 cheers waiting for you.',
    );
    expect(
      socialInboxNoticeText(sparkKinds: const ['steady'], circleAdds: 1),
      'Someone added your space to their Circle. '
      'Circle has a steady note waiting for you.',
    );
  });

  test('startup Spark and Circle receipts announce once per session', () {
    final tracker = SocialInboxSessionTracker();
    final first = tracker.takeFresh(
      sparks: const [
        {'id': 'same-sender', 'kind': 'kindle'},
        {'id': 'spark-two', 'kind': 'cheer'},
      ],
      circleAdds: const [
        {'id': 'same-sender', 'kind': 'circle_added'},
      ],
    );

    expect(first.sparkKinds, const ['kindle', 'cheer']);
    expect(first.circleAdds, 1);
    expect(first.isEmpty, isFalse);

    final repeated = tracker.takeFresh(
      sparks: const [
        {'id': 'same-sender', 'kind': 'kindle'},
        {'id': 'spark-two', 'kind': 'cheer'},
      ],
      circleAdds: const [
        {'id': 'same-sender', 'kind': 'circle_added'},
      ],
    );
    expect(repeated.isEmpty, isTrue);

    final resumed = tracker.takeFresh(
      sparks: const [
        {'id': 'spark-three', 'kind': 'steady'},
      ],
      circleAdds: const [
        {'id': 'circle-two', 'kind': 'circle_added'},
      ],
    );
    expect(resumed.sparkKinds, const ['steady']);
    expect(resumed.circleAdds, 1);
  });

  testWidgets('sender chooses one accessible fixed Spark kind', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    Sfx.instance.soundEnabled = false;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      Sfx.instance.soundEnabled = true;
    });

    final local = GameState()..addCircleCode('ABC234');
    final friend = GameState()..level = 8;
    final sent = <(String, String)>[];

    await tester.pumpWidget(
      MaterialApp(
        home: HearthCircleScreen(
          state: local,
          onPersist: () {},
          roomFetcher: (_) async => roomDisplay(friend),
          sparkSender: (code, kind) async {
            sent.add((code, kind));
            return true;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);

    final send = find.text('SEND A NOTE');
    await tester.scrollUntilVisible(
      send,
      500,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(send);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(send);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Send support'), findsOneWidget);
    expect(find.byKey(const ValueKey('spark-kind-kindle')), findsOneWidget);
    expect(find.byKey(const ValueKey('spark-kind-steady')), findsOneWidget);
    expect(find.byKey(const ValueKey('spark-kind-cheer')), findsOneWidget);
    expect(
      find.textContaining('No custom text, profile details'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const ValueKey('spark-kind-cheer')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('spark-kind-cheer')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(sent, const [('ABC234', 'cheer')]);
    expect(find.textContaining('A cheer is waiting'), findsOneWidget);
  });

  testWidgets('receiver inbox shows each pending Spark kind', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    Sfx.instance.soundEnabled = false;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      Sfx.instance.soundEnabled = true;
    });

    final state = GameState()
      ..setRoomCode('MYR234')
      ..addCircleCode('ABC234');
    final friend = GameState()..level = 8;

    await tester.pumpWidget(
      MaterialApp(
        home: HearthCircleScreen(
          state: state,
          onPersist: () {},
          roomFetcher: (_) async => roomDisplay(friend),
          socialInboxFetcher: (_) async => (
            sparks: const [
              {'id': 'one', 'kind': 'kindle'},
              {'id': 'two', 'kind': 'cheer'},
              {'id': 'three', 'kind': 'cheer'},
            ],
            circleAdds: const [
              {'id': 'four', 'kind': 'circle_added'},
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.textContaining('support is waiting too'), findsOneWidget);
    expect(find.text('A LITTLE WARMTH'), findsOneWidget);
    expect(find.text('2× CHEERING YOU ON'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Collect Circle support')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Circle refresh learns and persists a fetched keeper key', (
    tester,
  ) async {
    final state = GameState()..addCircleCode('DEF234');
    var persists = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HearthCircleScreen(
          state: state,
          onPersist: () => persists++,
          roomFetcher: (_) async => {
            ...roomDisplay(GameState()),
            'uid': 'circle-owner',
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(state.hearthCircleOwnerKeys, {
      'DEF234': discoveryOwnerKey('circle-owner'),
    });
    expect(persists, 1);
  });

  testWidgets(
    'a large Circle fetches progressively with bounded concurrency and lazy cards',
    (tester) async {
      final state = GameState();
      final pending = <String, Completer<Map<String, dynamic>?>>{};
      final calls = <String>[];
      final codes = [
        for (final suffix in 'BCDEFGHJKMNP'.split('')) 'AAA${suffix}22',
      ];
      for (final code in codes) {
        expect(state.addCircleCode(code), isTrue);
      }

      await tester.pumpWidget(
        MaterialApp(
          home: HearthCircleScreen(
            state: state,
            onPersist: () {},
            roomFetcher: (code) {
              calls.add(code);
              return (pending[code] ??= Completer<Map<String, dynamic>?>())
                  .future;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(calls, hasLength(4));
      expect(find.textContaining(codes.last), findsNothing);

      pending[codes.first]!.complete(roomDisplay(GameState()..level = 3));
      await tester.pump();
      await tester.pump();

      expect(calls, hasLength(5));
      expect(find.textContaining('${codes.first} ·'), findsOneWidget);
    },
  );

  test('social snackbar opens Circle directly', () {
    final shell = File('lib/screens/shell.dart').readAsStringSync();
    expect(shell, contains("label: 'OPEN CIRCLE'"));
    expect(shell, contains('builder: (_) => HearthCircleScreen('));
    expect(shell, contains('cloud.fetchSparks(code)'));
    expect(shell, contains('cloud.fetchCircleAdds(code)'));
  });
}
