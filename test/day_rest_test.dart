import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/release_notes.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/main.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/release_notes_preferences.dart';
import 'package:emberkeep/storage.dart';

void main() {
  tearDown(Clock.reset);

  test('closing the night rests the board until morning', () {
    Clock.freeze(DateTime(2026, 8, 5, 21, 30));
    final state = GameState();
    expect(state.dayRestingNow, isFalse);

    state.closeNight();
    expect(state.dayRestingNow, isTrue);

    // "I'm not done yet" reopens tonight without disturbing the morning.
    state.liftRest();
    expect(state.dayRestingNow, isFalse);
    expect(state.morningArmed, isTrue);

    // Closing the day again rests it again — the ritual owns the state.
    state.closeNight();
    expect(state.dayRestingNow, isTrue);

    // Crossing 4am ends the night; the rest lifts on its own.
    Clock.freeze(DateTime(2026, 8, 6, 7, 0));
    expect(state.dayRestingNow, isFalse);
    expect(state.morningArmed, isTrue);

    // And the morning greeting fully opens the new day.
    state.closeMorning();
    expect(state.dayRestingNow, isFalse);
  });

  test('the lifted rest survives a save round-trip', () {
    Clock.freeze(DateTime(2026, 8, 5, 22, 0));
    final state = GameState()
      ..onboarded = true
      ..closeNight()
      ..liftRest();
    final restored = GameState.fromJson(state.toJson());
    expect(restored.dayRestingNow, isFalse);
    expect(restored.morningArmed, isTrue);

    restored.closeNight();
    expect(restored.dayRestingNow, isTrue);
  });

  testWidgets('the closed board shows the kept panel and can reopen', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 8, 5, 21, 45));
    final state = GameState()
      ..onboarded = true
      ..reduceMotion = true
      ..soundEnabled = false;
    state.history[Days.key(Clock.now())] = 3;
    state.closeNight();
    SharedPreferences.setMockInitialValues({
      whatsNewSeenReleasePreferenceKey: currentRoomReleaseNotes.id,
      'liferpg_save_v1': jsonEncode({
        'app': 'emberkeep',
        'schema': Storage.schema,
        'state': state.toJson(),
        'quests': const [],
      }),
    });

    await tester.pumpWidget(const LifeRpgApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    // Quests tab is the initial tab; the board should be resting.
    expect(find.byKey(const ValueKey('day-resting-panel')), findsOneWidget);
    expect(find.text('The day is kept.'), findsOneWidget);
    expect(find.textContaining('The rest can wait.'), findsOneWidget);

    final reopen = find.byKey(const ValueKey('day-resting-reopen'));
    await tester.ensureVisible(reopen);
    await tester.pump();
    await tester.tap(reopen);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('day-resting-panel')), findsNothing);
    expect(find.text('THE DAY IS KEPT'), findsNothing);
  });
}
