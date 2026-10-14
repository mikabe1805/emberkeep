// The quest timer across the whole house, through the real app: the small
// running indicator over every room, the true time after the app was away, the
// finish moment when it ends while the person is elsewhere, and finishing the
// Quest from it.
import 'dart:convert';

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/release_notes.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/main.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/quest_timer.dart';
import 'package:emberkeep/release_notes_preferences.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/storage.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Alerts implements QuestTimerAlerts {
  @override
  Future<void> schedule({
    required DateTime at,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancel() async {}
}

final _tuesday = DateTime(2026, 10, 13, 11, 0);

Quest _reading() => Quest(
  title: 'Read ten pages',
  stat: Stat.intl,
  difficulty: 2,
  schedule: QuestSchedule.daily,
);

Future<void> _seed() async {
  final state = GameState()
    ..onboarded = true
    ..playerName = 'Mika'
    ..reduceMotion = true
    ..lastActiveDay = Days.key(Clock.now());
  SharedPreferences.setMockInitialValues({
    whatsNewSeenReleasePreferenceKey: currentRoomReleaseNotes.id,
    'liferpg_save_v1': jsonEncode({
      'app': 'emberkeep',
      'schema': Storage.schema,
      'state': state.toJson(),
      'quests': [_reading().toJson()],
    }),
  });
}

/// A timer that began [ago] before the app was opened, for 20 minutes.
Future<void> _startedBefore(Duration ago) async {
  final earlier = QuestTimer(alerts: _Alerts());
  await earlier.start(
    quest: _reading(),
    minutes: 20,
    startedAt: Clock.now().subtract(ago),
  );
  earlier.dispose();
}

Future<void> _boot(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  await tester.binding.setSurfaceSize(const Size(393, 852));
  // The test font is wider than the shipped ones, so a room's own row may
  // overflow here. That is the rooms' business, not this file's: it is noted
  // and ignored, as the render harness does.
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed by')) return;
    previousOnError?.call(details);
  };
  addTearDown(() {
    FlutterError.onError = previousOnError;
    tester.view.resetDevicePixelRatio();
    tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(const LifeRpgApp());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pump(const Duration(milliseconds: 800));
}

/// A bottom sheet slides in over a few frames; give it them.
Future<void> _sheetIn(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

final Finder _pill = find.byKey(const Key('quest-timer-pill'));
final Finder _finishSheet = find.byKey(const Key('quest-timer-finish-sheet'));

QuestTimer _timer(WidgetTester tester) => QuestTimerScope.maybeRead(
  tester.element(find.byType(QuestsPage, skipOffstage: false)),
)!;

GameState _state(WidgetTester tester) => tester
    .widget<QuestsPage>(find.byType(QuestsPage, skipOffstage: false))
    .state;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    Clock.freeze(_tuesday);
    Sfx.instance.soundEnabled = false;
  });

  tearDown(() {
    Clock.reset();
    Sfx.instance.soundEnabled = true;
  });

  testWidgets('a timer started before the app was closed is still there, '
      'showing the true time, in every room', (tester) async {
    await _seed();
    await _startedBefore(const Duration(minutes: 6));
    await _boot(tester);

    expect(_pill, findsOneWidget);
    expect(find.text('14:00'), findsOneWidget);
    expect(find.text('Read ten pages'), findsWidgets);

    for (final room in ['PLANS', 'JOURNAL', 'GOALS', 'ME', 'QUESTS']) {
      await tester.tap(find.text(room).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1400));
      expect(_pill, findsOneWidget, reason: 'over $room');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('time passing while the app is away is read from the clock', (
    tester,
  ) async {
    await _seed();
    await _startedBefore(Duration.zero);
    await _boot(tester);
    expect(find.text('20:00'), findsOneWidget);

    // The phone is put down for nine minutes, then picked up.
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    Clock.freeze(_tuesday.add(const Duration(minutes: 9)));
    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('11:00'), findsOneWidget);
    expect(_finishSheet, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the pill opens the timer, running', (tester) async {
    await _seed();
    await _startedBefore(const Duration(minutes: 3));
    await _boot(tester);

    await tester.tap(_pill);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('timer-clock')), findsOneWidget);
    expect(find.text('17:00'), findsOneWidget);
    expect(find.text('IN SESSION'), findsOneWidget);
    expect(_pill, findsNothing, reason: 'the full screen timer has the room');

    await tester.ensureVisible(find.byKey(const Key('timer-back')));
    await tester.tap(find.byKey(const Key('timer-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_pill, findsOneWidget);
    expect(_timer(tester).isRunning(), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('it ends while the person is in Plans: the finish moment '
      'appears, and Finish it finishes the Quest as timed', (tester) async {
    await _seed();
    await _startedBefore(const Duration(minutes: 5));
    await _boot(tester);
    await tester.tap(find.text('PLANS').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));
    expect(_finishSheet, findsNothing);

    Clock.freeze(_tuesday.add(const Duration(minutes: 16)));
    await tester.pump(const Duration(seconds: 1));
    await _sheetIn(tester);
    expect(_finishSheet, findsOneWidget);
    expect(find.text('TIME’S UP'), findsOneWidget);
    expect(find.text('Finish it'), findsOneWidget);
    expect(find.text('Not yet'), findsOneWidget);
    expect(
      find.textContaining('counts extra toward this week’s training'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('quest-timer-finish')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 900));

    final state = _state(tester);
    expect(state.completionLog, hasLength(1));
    expect(state.completionLog.single.timerProven, isTrue);
    expect(state.completionLog.single.stat, Stat.intl);
    expect(state.verifiedCompletions, 1);
    expect(_timer(tester).hasSession, isFalse);
    expect(_pill, findsNothing);
    expect(_finishSheet, findsNothing);
    await tester.pump(const Duration(seconds: 12));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('"Not yet" leaves the finished timer waiting in the pill', (
    tester,
  ) async {
    await _seed();
    await _startedBefore(const Duration(minutes: 5));
    await _boot(tester);

    Clock.freeze(_tuesday.add(const Duration(minutes: 16)));
    await tester.pump(const Duration(seconds: 1));
    await _sheetIn(tester);
    expect(_finishSheet, findsOneWidget);

    await tester.tap(find.byKey(const Key('quest-timer-later')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_finishSheet, findsNothing);
    expect(_pill, findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Tap to finish'), findsOneWidget);
    expect(_timer(tester).hasSession, isTrue);

    // It does not come up again by itself.
    await tester.pump(const Duration(seconds: 3));
    expect(_finishSheet, findsNothing);

    // The pill finishes it.
    await tester.tap(_pill);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 900));
    expect(_state(tester).completionLog.single.timerProven, isTrue);
    expect(_timer(tester).hasSession, isFalse);
    await tester.pump(const Duration(seconds: 12));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('it ended while the app was closed: opening it shows the '
      'finish moment', (tester) async {
    await _seed();
    await _startedBefore(const Duration(minutes: 45));
    await _boot(tester);
    await _sheetIn(tester);

    expect(_finishSheet, findsOneWidget);
    expect(find.text('Read ten pages'), findsWidgets);
    expect(_timer(tester).isFinished(), isTrue);
    await tester.tap(find.byKey(const Key('quest-timer-later')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a timer that ended on an earlier day proves nothing today and '
      'ends quietly', (tester) async {
    await _seed();
    await _startedBefore(const Duration(hours: 30));
    await _boot(tester);
    await tester.pump(const Duration(milliseconds: 600));

    expect(_timer(tester).hasSession, isFalse);
    expect(_pill, findsNothing);
    expect(_finishSheet, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('no timer, no pill', (tester) async {
    await _seed();
    await _boot(tester);
    expect(_pill, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
