import 'package:emberkeep/audio.dart';
import 'package:emberkeep/content/release_notes.dart';
import 'package:emberkeep/screens/whats_new.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const _capture = bool.fromEnvironment('CAPTURE_GOLDENS');

Future<void> _loadFonts() async {
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  final fraunces = FontLoader('Fraunces')
    ..addFont(rootBundle.load('assets/google_fonts/Fraunces-Bold.ttf'))
    ..addFont(rootBundle.load('assets/google_fonts/Fraunces-SemiBold.ttf'));
  final inter = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/google_fonts/Inter-Regular.ttf'))
    ..addFont(rootBundle.load('assets/google_fonts/Inter-Medium.ttf'))
    ..addFont(rootBundle.load('assets/google_fonts/Inter-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/google_fonts/Inter-Bold.ttf'));
  final mono = FontLoader('JetBrainsMono')
    ..addFont(rootBundle.load('assets/google_fonts/JetBrainsMono-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/google_fonts/JetBrainsMono-Bold.ttf'));
  await Future.wait([icons.load(), fraunces.load(), inter.load(), mono.load()]);
  GoogleFonts.config.allowRuntimeFetching = false;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  setUp(() {
    Sfx.instance.soundEnabled = false;
  });

  tearDown(() {
    Sfx.instance.soundEnabled = true;
  });

  testWidgets('automatic screen presents factual current-release content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WhatsNewScreen(
          automatic: true,
          reduceMotion: true,
          onDismiss: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('A few new things'), findsOneWidget);
    expect(find.text('More room for real life.'), findsOneWidget);
    expect(find.text('PLANS THAT BEND'), findsOneWidget);
    expect(find.text('A SOFTER LANDING'), findsOneWidget);
    expect(find.text('HELP FOR TODAY'), findsOneWidget);
    expect(find.text('KEEP GOING'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('whats-new-release-1.0.2+20')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('close and Keep Going each dismiss the automatic screen', (
    tester,
  ) async {
    var dismissals = 0;

    Future<void> pumpScreen() async {
      await tester.pumpWidget(
        MaterialApp(
          home: WhatsNewScreen(
            automatic: true,
            reduceMotion: true,
            onDismiss: () => dismissals++,
          ),
        ),
      );
      await tester.pump();
    }

    await pumpScreen();
    await tester.tap(find.byKey(const ValueKey('whats-new-close')));
    await tester.pump();
    expect(dismissals, 1);

    await pumpScreen();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('whats-new-keep-going')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('whats-new-keep-going')));
    await tester.pump();
    expect(dismissals, 2);
  });

  testWidgets('automatic screen is a named route with two clear exits', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: WhatsNewScreen(
            automatic: true,
            reduceMotion: true,
            onDismiss: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel("What's New"), findsAtLeastNWidgets(1));
      expect(find.bySemanticsLabel("Close What's New"), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('whats-new-keep-going')),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.bySemanticsLabel('Keep going'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('manual archive renders every supplied release newest first', (
    tester,
  ) async {
    const older = RoomReleaseNotes(
      id: '1.0.0+12',
      versionLabel: 'VERSION 1.0.0 · BUILD 12',
      dateLabel: 'JULY 2026',
      title: 'The room found its name.',
      introduction: 'Room of Days arrived.',
      highlights: <ReleaseHighlight>[],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: WhatsNewScreen(
          reduceMotion: true,
          releases: <RoomReleaseNotes>[...roomOfDaysReleaseNotes, older],
        ),
      ),
    );
    await tester.pump();

    final currentTop = tester.getTopLeft(
      find.byKey(const ValueKey('whats-new-release-1.0.2+20')),
    );
    final olderTop = tester.getTopLeft(
      find.byKey(const ValueKey('whats-new-release-1.0.0+12')),
    );
    expect(currentTop.dy, lessThan(olderTop.dy));
    expect(find.text('BACK TO YOUR ROOM'), findsOneWidget);
  });

  testWidgets('empty manual archive stays useful instead of crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WhatsNewScreen(
          reduceMotion: true,
          releases: <RoomReleaseNotes>[],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No release notes are kept here yet.'), findsOneWidget);
    expect(find.text('BACK TO YOUR ROOM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow large-text phone scrolls without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: WhatsNewScreen(
          automatic: true,
          reduceMotion: true,
          onDismiss: () {},
        ),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('whats-new-keep-going')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('KEEP GOING'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rendered release-card evidence', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    Widget screen() => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WhatsNewScreen(
        automatic: true,
        reduceMotion: true,
        onDismiss: () {},
      ),
    );

    await tester.pumpWidget(screen());
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../design/audits/2026-08-17/whats-new/whats_new_430x932.png',
        ),
      );
    }

    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    await tester.pumpWidget(screen());
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../design/audits/2026-08-17/whats-new/whats_new_320x568_text_2x.png',
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('whats-new-keep-going')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 180));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../design/audits/2026-08-17/whats-new/whats_new_320x568_text_2x_scrolled.png',
        ),
      );
    }
  });
}
