import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/release_notes.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/release_notes_preferences.dart';
import 'package:emberkeep/screens/room_guide.dart';
import 'package:emberkeep/screens/shell.dart';
import 'package:emberkeep/screens/whats_new.dart';
import 'package:emberkeep/social.dart';
import 'package:emberkeep/storage.dart';
import 'package:emberkeep/widgets/onboarding_flow.dart';
import 'package:emberkeep/widgets/routine_flows.dart';
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
    SharedPreferences.setMockInitialValues({
      whatsNewSeenReleasePreferenceKey: currentRoomReleaseNotes.id,
    });
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

  testWidgets('existing install opens an unseen release exactly once', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    Clock.freeze(DateTime(2026, 8, 17, 12));
    await Storage.save(
      GameState()
        ..onboarded = true
        ..reduceMotion = true,
      const [],
    );

    await pumpShell(tester);

    expect(find.byType(WhatsNewScreen), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(whatsNewSeenReleasePreferenceKey),
      currentRoomReleaseNotes.id,
    );

    await disposeShell(tester);
    await pumpShell(tester);
    expect(find.byType(WhatsNewScreen), findsNothing);
    await disposeShell(tester);
  });

  testWidgets('fresh install records the release but leaves onboarding alone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await pumpShell(tester);

    expect(find.byType(OnboardingFlow), findsOneWidget);
    expect(find.byType(WhatsNewScreen), findsNothing);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(whatsNewSeenReleasePreferenceKey),
      currentRoomReleaseNotes.id,
    );
    await disposeShell(tester);
  });

  testWidgets('What\'s New waits for onboarding on an older unfinished save', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Storage.save(GameState()..reduceMotion = true, const []);

    await pumpShell(tester);

    expect(find.byType(OnboardingFlow), findsOneWidget);
    expect(find.byType(WhatsNewScreen), findsNothing);
    await disposeShell(tester);
  });

  testWidgets('older unfinished install sees What\'s New after onboarding', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Storage.save(GameState()..reduceMotion = true, const []);
    await pumpShell(tester);

    await tester.tap(find.text('ENTER ROOM OF DAYS'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('skip for now'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('CONTINUE').last);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('OPEN TODAY’S QUESTS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byType(OnboardingFlow), findsNothing);
    expect(find.byType(WhatsNewScreen), findsOneWidget);
    await disposeShell(tester);
  });

  testWidgets('Room Guide finishes before deferred What\'s New', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Storage.save(GameState()..reduceMotion = true, const []);
    await pumpShell(tester);

    await tester.tap(find.text('ENTER ROOM OF DAYS'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('skip for now'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('CONTINUE').last);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('open the room guide'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(RoomGuideScreen), findsOneWidget);
    expect(find.byType(WhatsNewScreen), findsNothing);

    Navigator.of(tester.element(find.byType(RoomGuideScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byType(RoomGuideScreen), findsNothing);
    expect(find.byType(WhatsNewScreen), findsOneWidget);
    await disposeShell(tester);
  });

  testWidgets('What\'s New precedes a due Morning Flow then hands it off', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await saveMorning(due: true);

    await pumpShell(tester);

    expect(find.byType(WhatsNewScreen), findsOneWidget);
    expect(find.byType(MorningFlow), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('whats-new-keep-going')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('whats-new-keep-going')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byType(WhatsNewScreen), findsNothing);
    expect(find.byType(MorningFlow), findsOneWidget);
    await disposeShell(tester);
  });

  testWidgets('resume cannot stack a second What\'s New overlay', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Storage.save(
      GameState()
        ..onboarded = true
        ..reduceMotion = true,
      const [],
    );
    await pumpShell(tester);
    expect(find.byType(WhatsNewScreen), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byType(WhatsNewScreen), findsOneWidget);
    await disposeShell(tester);
  });

  testWidgets('automatic release screen owns shell semantics and focus', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      SharedPreferences.setMockInitialValues({});
      await Storage.save(
        GameState()
          ..onboarded = true
          ..reduceMotion = true,
        const [],
      );

      await pumpShell(tester);

      expect(find.bySemanticsLabel("Close What's New"), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Quest Desk')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('QUESTS tab')), findsNothing);
    } finally {
      semantics.dispose();
      await disposeShell(tester);
    }
  });

  testWidgets('queued room link is handled before What\'s New appears', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Storage.save(
      GameState()
        ..onboarded = true
        ..reduceMotion = true,
      const [],
    );
    final inbox = RoomLinkInbox()..enqueuePrompt();

    await tester.pumpWidget(MaterialApp(home: AppShell(roomLinks: inbox)));
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (!inbox.isNotEmpty) break;
    }
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(WhatsNewScreen).evaluate().isNotEmpty) break;
    }

    expect(inbox.isNotEmpty, isFalse);
    expect(
      find.text('Visiting needs a connection — try again in a moment.'),
      findsWidgets,
    );
    expect(find.byType(WhatsNewScreen), findsOneWidget);

    await disposeShell(tester);
    inbox.dispose();
  });
}
