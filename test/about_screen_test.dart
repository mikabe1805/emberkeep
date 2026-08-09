import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:emberkeep/screens/about.dart';

void main() {
  testWidgets('About introduces the maker and preserves the free promise', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AboutScreen(reduceMotion: true)),
    );
    await tester.pump();

    expect(find.text('Room of Days'), findsOneWidget);
    expect(find.text('Made by Mika'), findsOneWidget);
    expect(find.textContaining('no paid shortcuts'), findsOneWidget);
    expect(find.byKey(const ValueKey('about-send-feedback')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android build includes the tip-only Ko-fi path', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        const MaterialApp(home: AboutScreen(reduceMotion: true)),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('about-send-coffee')), findsOneWidget);
      expect(find.textContaining('nothing unlocks'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('an empty support URL removes the entire Ko-fi path', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: AboutScreen(reduceMotion: true, coffeeUrlOverride: ''),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('about-send-coffee')), findsNothing);
      expect(find.textContaining('Ko-fi'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('coffee section stays off iOS builds (Apple 3.1.1)', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
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
      expect(find.textContaining('Ko-fi'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
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
