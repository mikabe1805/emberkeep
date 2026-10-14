// The quest timer's offer in the Doorway (2026-10-14): the glass card that
// leads Today's three offers "Start a 20-minute timer" under MARK COMPLETE
// when the leading Quest fits one, says what it is for, starts it in one tap,
// and shows the time left once it runs. MARK COMPLETE stays the one lit action.
import 'dart:math' as math;

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/day_planning.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/quest_timer.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime get _saturday => DateTime(2026, 10, 10, 11, 0);

class _NoLuck implements math.Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.999;
  @override
  int nextInt(int max) => 0;
}

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

const _titles = ['Read ten pages', 'Review one problem', 'Write for today'];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    QuestsPage.debugLegacyBoard = false;
    QuestsPage.debugAskTimerOnMark = true;
    SharedPreferences.setMockInitialValues({});
    GameState.debugRandomFactory = _NoLuck.new;
    Sfx.instance.soundEnabled = false;
  });
  tearDown(() {
    QuestsPage.debugLegacyBoard = true;
    QuestsPage.debugAskTimerOnMark = false;
    Clock.reset();
    GameState.debugRandomFactory = null;
    Sfx.instance.soundEnabled = true;
  });

  late List<Quest> quests;

  Future<QuestTimer> mount(
    WidgetTester tester, {
    double textScale = 1,
    bool readingKept = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    Clock.freeze(_saturday);
    final timer = QuestTimer(alerts: _Alerts());
    final state = GameState(rng: _NoLuck())
      ..onboarded = true
      ..playerName = 'Mika'
      ..soundEnabled = false
      ..reduceMotion = true
      ..lastActiveDay = Days.key(_saturday);
    quests = [
      Quest(title: _titles[0], stat: Stat.intl, difficulty: 4),
      Quest(title: _titles[1], stat: Stat.foc, difficulty: 3),
      Quest(title: _titles[2], stat: Stat.dis, difficulty: 2),
    ];
    applyDailyField(quests, _saturday, _titles);
    if (readingKept) quests[0].lastDoneDay = Days.key(_saturday);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(393, 852),
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: QuestTimerScope(
              timer: timer,
              child: QuestsPage(
                state: state,
                quests: quests,
                onRefresh: () => 0,
                onPersist: () {},
                onAdd: (_) => true,
                onRemove: (_) {},
                onSnapshot: () => 'snapshot',
                onRestore: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    return timer;
  }

  final offer = find.byKey(const ValueKey('quest-timer-offer-Read ten pages'));

  testWidgets('the leading reading Quest offers a timer under MARK COMPLETE, '
      'which stays the one lit action', (tester) async {
    final timer = await mount(tester);
    expect(find.byKey(const Key('quest-day-room')), findsOneWidget);
    expect(find.text('MARK COMPLETE'), findsOneWidget);
    expect(offer, findsOneWidget);
    expect(find.text('Start a 20-minute timer'), findsOneWidget);
    expect(
      find.text('Counts extra toward this week’s training'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('class-there-button')), findsOneWidget);
    // Under the button, not beside it.
    expect(
      tester.getTopLeft(offer).dy,
      greaterThan(tester.getBottomLeft(find.text('MARK COMPLETE')).dy),
    );
    expect(tester.getSize(offer).height, greaterThanOrEqualTo(44));
    await tester.pumpWidget(const SizedBox.shrink());
    timer.dispose();
  });

  testWidgets('one tap starts it and opens it running', (tester) async {
    final timer = await mount(tester);
    await tester.tap(offer);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(timer.session?.questKey, 'Read ten pages');
    expect(timer.session?.minutes, 20);
    expect(find.byKey(const Key('timer-clock')), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(quests[0].doneFor(Clock.now()), isFalse);

    await tester.ensureVisible(find.byKey(const Key('timer-back')));
    await tester.tap(find.byKey(const Key('timer-back')));
    await tester.pump();
    await tester.pump();
    // Back in the room, the card says so, and opens it again.
    expect(find.text('Timer running · 20:00'), findsOneWidget);
    expect(find.text('Start a 20-minute timer'), findsNothing);
    expect(timer.isRunning(), isTrue);

    await tester.tap(find.text('Timer running · 20:00'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('timer-clock')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('timer-stop')));
    await tester.tap(find.byKey(const Key('timer-stop')));
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    timer.dispose();
  });

  testWidgets('a leading Quest with nothing to time offers nothing', (
    tester,
  ) async {
    final timer = await mount(tester, readingKept: true);
    // Read ten pages is kept, so Review one problem leads.
    expect(find.byKey(const Key('quest-day-title')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('quest-day-title'))).data,
      'Review one problem',
    );
    expect(find.text('Start a 20-minute timer'), findsNothing);
    expect(find.byIcon(Icons.timer_outlined), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    timer.dispose();
  });

  testWidgets('at 200% text the offer is still there and nothing overflows', (
    tester,
  ) async {
    final timer = await mount(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(offer, findsOneWidget);
    expect(find.text('Start a 20-minute timer'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    timer.dispose();
  });
}
