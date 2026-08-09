import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/screens/shell.dart';
import 'package:emberkeep/storage.dart';
import 'package:emberkeep/widgets/routine_flows.dart';
import 'package:emberkeep/widgets/onboarding_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Sfx.instance.soundEnabled = false;
  });

  tearDown(() {
    Clock.reset();
    Sfx.instance.soundEnabled = true;
  });

  Future<void> saveMorning({required bool due, bool completed = false}) async {
    Clock.freeze(DateTime(2026, 8, 3, 22));
    final state = GameState()
      ..onboarded = true
      ..reduceMotion = true;
    state.closeNight();

    Clock.freeze(due ? DateTime(2026, 8, 4, 7) : DateTime(2026, 8, 4, 0, 30));
    if (completed) {
      state.closeMorning();
      // Model a legacy/cloud conflict where the old "armed" bit survived a
      // newer completion stamp. The day stamp must win and suppress launch.
      state.morningArmed = true;
    }
    await Storage.save(state, const []);
  }

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump();
  }

  Future<void> disposeShell(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('cold start automatically opens a due morning routine', (
    tester,
  ) async {
    await saveMorning(due: true);

    await pumpShell(tester);

    expect(find.byType(MorningFlow), findsOneWidget);
    expect(find.text('Open the day'), findsOneWidget);
    await disposeShell(tester);
  });

  testWidgets('resume re-evaluates a morning that became due while away', (
    tester,
  ) async {
    await saveMorning(due: false);
    await pumpShell(tester);
    expect(find.byType(MorningFlow), findsNothing);

    Clock.freeze(DateTime(2026, 8, 4, 7));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byType(MorningFlow), findsOneWidget);
    await disposeShell(tester);
  });

  testWidgets('resume cannot stack a second morning overlay', (tester) async {
    await saveMorning(due: true);
    await pumpShell(tester);
    expect(find.byType(MorningFlow), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byType(MorningFlow), findsOneWidget);
    await disposeShell(tester);
  });

  testWidgets('a morning completed today stays closed on start and resume', (
    tester,
  ) async {
    await saveMorning(due: true, completed: true);
    await pumpShell(tester);
    expect(find.byType(MorningFlow), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byType(MorningFlow), findsNothing);
    await disposeShell(tester);
  });

  testWidgets('first-run onboarding is never covered by a morning overlay', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 8, 3, 22));
    final state = GameState()..reduceMotion = true;
    state.closeNight();
    Clock.freeze(DateTime(2026, 8, 4, 7));
    await Storage.save(state, const []);

    await pumpShell(tester);

    expect(find.byType(OnboardingFlow), findsOneWidget);
    expect(find.byType(MorningFlow), findsNothing);
    await disposeShell(tester);
  });

  testWidgets('first-run onboarding owns semantics and keyboard focus', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpShell(tester);

      expect(find.byType(OnboardingFlow), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('ENTER ROOM OF DAYS')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('Quest Desk')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('QUESTS tab')), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(find.text('QUEST DESK'), findsNothing);
    } finally {
      semantics.dispose();
      await disposeShell(tester);
    }
  });
}
