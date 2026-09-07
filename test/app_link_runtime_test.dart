import 'package:emberkeep/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:emberkeep/content/release_notes.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/release_notes_preferences.dart';
import 'package:emberkeep/screens/goals.dart';
import 'package:emberkeep/screens/shell.dart';
import 'package:emberkeep/storage.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'the root Goals deep link is recognized without changing other routes',
    () {
      expect(
        wantsGoalsPage(Uri.parse('https://roomofdays.com/?page=goals')),
        isTrue,
      );
      expect(wantsGoalsPage(Uri.parse('https://roomofdays.com/')), isFalse);
      expect(
        wantsGoalsPage(
          Uri.parse('https://roomofdays.com/introduction?page=goals'),
        ),
        isFalse,
      );
    },
  );

  testWidgets('Goals deep link opens the actual tab with saved progress', (
    tester,
  ) async {
    final state = GameState()
      ..onboarded = true
      ..reduceMotion = true
      ..soundEnabled = false;
    await Storage.save(state, const []);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      whatsNewSeenReleasePreferenceKey,
      currentRoomReleaseNotes.id,
    );

    await tester.pumpWidget(
      const MaterialApp(home: AppShell(initialPage: AppShellInitialPage.goals)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(GoalsPage), findsOneWidget);
    expect(find.byKey(const ValueKey('app-bottom-dock-tab-2')), findsOneWidget);
    expect(find.text('Room of Days'), findsNothing);
  });

  testWidgets('Goals deep link keeps first run behind onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppShell(initialPage: AppShellInitialPage.goals)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('a quest ledger for the life you’re actually living'),
      findsOneWidget,
    );
  });

  testWidgets('root app consumes a warm native room link before Navigator', (
    tester,
  ) async {
    await tester.pumpWidget(const LifeRpgApp());
    await tester.pump();

    final ByteData message = const JSONMethodCodec().encodeMethodCall(
      const MethodCall('pushRouteInformation', <String, dynamic>{
        'location': 'https://roomofdays.com/space/ABC234',
        'state': null,
      }),
    );
    final result = (await tester.binding.defaultBinaryMessenger
        .handlePlatformMessage('flutter/navigation', message, (_) {}))!;

    expect(const JSONMethodCodec().decodeEnvelope(result), isTrue);

    // The room is queued until storage/cloud startup settles; dispose now so
    // this routing test stays independent of any live Firebase response.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
