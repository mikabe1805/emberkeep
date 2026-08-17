import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/widgets/streak_freeze_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;

const _capture = bool.fromEnvironment('CAPTURE_GOLDENS');

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    Future<void> load(String family, String asset) async {
      final data = await rootBundle.load(asset);
      await (FontLoader(family)..addFont(Future.value(data))).load();
    }

    await Future.wait([
      load('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      load('Fraunces', 'assets/google_fonts/Fraunces-SemiBold.ttf'),
      load('Inter', 'assets/google_fonts/Inter-Regular.ttf'),
      load('JetBrainsMono', 'assets/google_fonts/JetBrainsMono-SemiBold.ttf'),
    ]);
  });
  tearDown(Clock.reset);

  testWidgets('streak freeze details visual', (tester) async {
    Clock.freeze(DateTime(2026, 8, 13, 10));
    tester.view.devicePixelRatio = 3;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });

    final state = GameState()
      ..level = 7
      ..streakDays = 6
      ..bestStreak = 11
      ..lastCompletionDay = '2026-08-13'
      ..streakFreezes = 3
      ..streakFreezeProgress = 2;
    state.frozenStreakDays.add('2026-08-11');

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF120C0A),
          body: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF261712), Color(0xFF100B09)],
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: StreakFreezeStatus(state: state),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(StreakFreezeStatus));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('STREAK FREEZES'), findsOneWidget);

    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/streak_freeze_details.png'),
      );
    }
  });
}
