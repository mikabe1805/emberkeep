import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:emberkeep/screens/about.dart';

void main() {
  testWidgets('About states the promise and offers feedback', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AboutScreen(reduceMotion: true)),
    );
    await tester.pump();

    expect(find.text('About Room of Days'), findsOneWidget);
    // The free-forever promise is on the page in writing.
    expect(find.textContaining('no '), findsWidgets);
    expect(find.textContaining('shortcuts'), findsOneWidget);
    expect(find.byKey(const ValueKey('about-send-feedback')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('coffee section shows where store rules allow it', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
      const MaterialApp(
        home: AboutScreen(
          reduceMotion: true,
          coffeeUrlOverride: 'https://ko-fi.com/mikabe',
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('about-send-coffee')), findsOneWidget);
    expect(find.textContaining('your room never knows'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Must clear before the body ends — the framework checks foundation
    // debug vars ahead of addTearDown callbacks.
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('store build defaults to no external payment link', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
      const MaterialApp(home: AboutScreen(reduceMotion: true)),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('about-send-coffee')), findsNothing);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('coffee section stays off iOS builds (Apple 3.1.1)', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(
      const MaterialApp(
        home: AboutScreen(
          reduceMotion: true,
          coffeeUrlOverride: 'https://ko-fi.com/mikabe',
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('about-send-coffee')), findsNothing);
    expect(find.textContaining('coffee'), findsNothing);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('About survives a narrow large-text phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      const MaterialApp(home: AboutScreen(reduceMotion: true)),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('about-send-feedback')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
