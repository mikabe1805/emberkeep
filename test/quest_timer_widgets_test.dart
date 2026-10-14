// The quest timer on screen: its offer on a Quest, the running indicator, the
// full screen timer that keeps running when you leave, and finishing a Quest
// through it on the real Quests page.
import 'dart:math';

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/quest_timer.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/quest_timer_widgets.dart';
import 'package:emberkeep/widgets/timer_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Alerts implements QuestTimerAlerts {
  final scheduled = <DateTime>[];
  int cancels = 0;

  @override
  Future<void> schedule({
    required DateTime at,
    required String title,
    required String body,
  }) async => scheduled.add(at);

  @override
  Future<void> cancel() async => cancels++;
}

Quest _reading() =>
    Quest(title: 'Read 20 pages', stat: Stat.intl, difficulty: 3);

Quest _pushups() =>
    Quest(title: 'Do 5 push-ups', stat: Stat.str, difficulty: 2);

Quest _timed() => Quest(
  title: 'Focus proof',
  stat: Stat.foc,
  difficulty: 3,
  verification: Verification.timer,
  timerMinutes: 12,
);

Future<void> _pumpBoard(
  WidgetTester tester, {
  required GameState state,
  required List<Quest> quests,
  required QuestTimer timer,
}) async {
  state.reduceMotion = true;
  state.rollover(quests);
  state.setEnergyWeather(EnergyWeather.steady);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: QuestTimerScope(
          timer: timer,
          child: QuestsPage(
            state: state,
            quests: quests,
            onRefresh: () => 0,
            onPersist: () {},
            onAdd: (_) => false,
            onRemove: (_) {},
            onSnapshot: () => 'pre-completion-snapshot',
            onRestore: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
}

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    260,
    scrollable: find
        .descendant(
          of: find.byType(QuestsPage),
          matching: find.byType(Scrollable),
        )
        .last,
  );
  await tester.pump();
}

Widget _host(QuestTimer timer, List<Widget> children) => MaterialApp(
  home: Scaffold(
    body: QuestTimerScope(
      timer: timer,
      child: Column(children: children),
    ),
  ),
);

void main() {
  final start = DateTime(2026, 10, 14, 15, 0);

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Clock.freeze(start);
    Sfx.instance.soundEnabled = false;
  });

  tearDown(() {
    Clock.reset();
    Sfx.instance.soundEnabled = true;
  });

  group('the full screen timer', () {
    testWidgets('a running timer opens with the true time left', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TimerOverlay(
            questTitle: 'Read 20 pages',
            minutes: 20,
            resumeEnd: start.add(const Duration(minutes: 12, seconds: 30)),
            onFinished: () {},
            onHonor: () {},
            onCancel: () {},
          ),
        ),
      );
      expect(find.text('12:30'), findsOneWidget);
      expect(find.text('IN SESSION'), findsOneWidget);
      expect(find.byKey(const Key('timer-start')), findsNothing);

      Clock.freeze(start.add(const Duration(minutes: 5)));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('7:30'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('it finishes when the saved end passes, even if it opened '
        'already late', (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: TimerOverlay(
            questTitle: 'Read 20 pages',
            minutes: 20,
            resumeEnd: start.add(const Duration(seconds: 3)),
            onFinished: () => finished++,
            onHonor: () {},
            onCancel: () {},
          ),
        ),
      );
      Clock.freeze(start.add(const Duration(minutes: 1)));
      await tester.pump(const Duration(seconds: 1));
      expect(finished, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Back leaves a saved timer running; only Stop stops it', (
      tester,
    ) async {
      var back = 0;
      var stop = 0;
      var honor = 0;
      var finished = 0;
      Widget overlay() => MaterialApp(
        home: TimerOverlay(
          questTitle: 'Read 20 pages',
          minutes: 20,
          resumeEnd: start.add(const Duration(minutes: 20)),
          onFinished: () => finished++,
          onHonor: () => honor++,
          onCancel: () => back++,
          onStop: () => stop++,
        ),
      );

      await tester.pumpWidget(overlay());
      expect(
        find.text(
          'It keeps running if you leave. We’ll tell you when the time '
          'is up.',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const Key('timer-back')));
      await tester.tap(find.byKey(const Key('timer-back')));
      await tester.pump();
      expect((back, stop, honor, finished), (1, 0, 0, 0));
      await tester.pumpWidget(const SizedBox.shrink());

      await tester.pumpWidget(overlay());
      await tester.ensureVisible(find.byKey(const Key('timer-stop')));
      await tester.tap(find.byKey(const Key('timer-stop')));
      await tester.pump();
      expect((back, stop, honor, finished), (1, 1, 0, 0));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a fresh Start tells its owner when it began and ends', (
      tester,
    ) async {
      DateTime? began;
      DateTime? ends;
      await tester.pumpWidget(
        MaterialApp(
          home: TimerOverlay(
            questTitle: 'Read 20 pages',
            minutes: 20,
            onFinished: () {},
            onHonor: () {},
            onCancel: () {},
            onStop: () {},
            onStarted: (startedAt, endsAt) {
              began = startedAt;
              ends = endsAt;
            },
          ),
        ),
      );
      expect(find.byKey(const Key('timer-stop')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('timer-start')));
      await tester.tap(find.byKey(const Key('timer-start')));
      await tester.pump();
      expect(began, start);
      expect(ends, start.add(const Duration(minutes: 20)));
      expect(find.byKey(const Key('timer-stop')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('without a saved timer behind it, the overlay is as it was', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TimerOverlay(
            questTitle: 'Read 20 pages',
            minutes: 1,
            onFinished: () {},
            onHonor: () {},
            onCancel: () {},
          ),
        ),
      );
      await tester.ensureVisible(find.byKey(const Key('timer-start')));
      await tester.tap(find.byKey(const Key('timer-start')));
      await tester.pump();
      expect(find.byKey(const Key('timer-stop')), findsNothing);
      expect(find.text('Leave session'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('the offer on a Quest', () {
    testWidgets('appears on the Quests that fit a timer and no others', (
      tester,
    ) async {
      final timer = QuestTimer(alerts: _Alerts());
      var started = 0;
      await tester.pumpWidget(
        _host(timer, [
          QuestTimerAction(
            quest: _reading(),
            onStart: () => started++,
            onOpen: () {},
          ),
          QuestTimerAction(quest: _pushups(), onStart: () {}, onOpen: () {}),
          QuestTimerAction(quest: _timed(), onStart: () {}, onOpen: () {}),
          QuestTimerAction(
            quest: _reading()..lastDoneDay = Days.key(start),
            onStart: () {},
            onOpen: () {},
          ),
        ]),
      );
      // Only the open reading Quest: not push-ups, not a timer Quest (it
      // opens its own session), not one already done.
      expect(find.text('Start a 20-minute timer'), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);

      await tester.tap(find.text('Start a 20-minute timer'));
      await tester.pump();
      expect(started, 1);
      timer.dispose();
    });

    testWidgets('is a 44 pt target with a plain spoken name', (tester) async {
      final semantics = tester.ensureSemantics();
      final timer = QuestTimer(alerts: _Alerts());
      await tester.pumpWidget(
        _host(timer, [
          QuestTimerAction(
            quest: _reading(),
            onStart: () {},
            onOpen: () {},
            caption: true,
          ),
        ]),
      );
      final pill = find.byKey(
        const ValueKey('quest-timer-offer-Read 20 pages'),
      );
      expect(tester.getSize(pill).height, greaterThanOrEqualTo(44));
      expect(
        find.bySemanticsLabel('Start a 20-minute timer for Read 20 pages'),
        findsOneWidget,
      );
      expect(
        find.text('Counts extra toward this week’s training'),
        findsOneWidget,
      );
      semantics.dispose();
      timer.dispose();
    });

    testWidgets('stays whole at 200% text', (tester) async {
      final timer = QuestTimer(alerts: _Alerts());
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: _host(timer, [
            SizedBox(
              width: 300,
              child: QuestTimerAction(
                quest: _reading(),
                onStart: () {},
                onOpen: () {},
              ),
            ),
          ]),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Start a 20-minute timer'), findsOneWidget);
      timer.dispose();
    });

    testWidgets('once its timer runs, the Quest shows the time left and '
        'opens it; no other Quest offers a second timer', (tester) async {
      final timer = QuestTimer(alerts: _Alerts());
      final reading = _reading();
      await timer.start(quest: reading, minutes: 20);
      var opened = 0;
      await tester.pumpWidget(
        _host(timer, [
          QuestTimerAction(
            quest: reading,
            onStart: () {},
            onOpen: () => opened++,
          ),
          QuestTimerAction(
            quest: Quest(
              title: 'Practice guitar',
              stat: Stat.foc,
              difficulty: 3,
            ),
            onStart: () {},
            onOpen: () {},
          ),
        ]),
      );
      expect(find.text('Timer running · 20:00'), findsOneWidget);
      expect(find.text('Start a 20-minute timer'), findsNothing);

      Clock.freeze(start.add(const Duration(minutes: 3)));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Timer running · 17:00'), findsOneWidget);

      await tester.tap(find.text('Timer running · 17:00'));
      await tester.pump();
      expect(opened, 1);

      Clock.freeze(start.add(const Duration(minutes: 21)));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Time’s up · finish it'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      timer.dispose();
    });
  });

  group('the running indicator', () {
    testWidgets('shows the clock and the Quest, ticks, and opens the timer', (
      tester,
    ) async {
      final timer = QuestTimer(alerts: _Alerts());
      await timer.start(quest: _reading(), minutes: 20);
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuestTimerPill(timer: timer, onOpen: () => opened++),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('quest-timer-pill')), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget);
      expect(find.text('Read 20 pages'), findsOneWidget);
      final size = tester.getSize(find.byKey(const Key('quest-timer-pill')));
      expect(size.height, greaterThanOrEqualTo(44));

      Clock.freeze(start.add(const Duration(minutes: 8, seconds: 15)));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('11:45'), findsOneWidget);

      await tester.tap(find.byKey(const Key('quest-timer-pill')));
      await tester.pump();
      expect(opened, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      timer.dispose();
    });

    testWidgets('is not there with no timer, and steps aside for the full '
        'screen timer', (tester) async {
      final timer = QuestTimer(alerts: _Alerts());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuestTimerPill(timer: timer, onOpen: () {}),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('quest-timer-pill')), findsNothing);

      await timer.start(quest: _reading(), minutes: 20);
      await tester.pump();
      expect(find.byKey(const Key('quest-timer-pill')), findsOneWidget);

      timer.overlayOpen = true;
      await tester.pump();
      expect(find.byKey(const Key('quest-timer-pill')), findsNothing);
      timer.overlayOpen = false;
      await tester.pump();
      expect(find.byKey(const Key('quest-timer-pill')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      timer.dispose();
    });

    testWidgets('notices the end by itself and says so', (tester) async {
      final timer = QuestTimer(alerts: _Alerts());
      await timer.start(quest: _reading(), minutes: 1);
      var heard = 0;
      timer.addListener(() {
        if (timer.finishAnnounced) heard++;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuestTimerPill(timer: timer, onOpen: () {}),
            ),
          ),
        ),
      );
      Clock.freeze(start.add(const Duration(minutes: 1, seconds: 1)));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(heard, greaterThanOrEqualTo(1));
      expect(timer.finishAnnounced, isTrue);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Tap to finish'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      timer.dispose();
    });
  });

  group('on the Quests page', () {
    setUp(() => QuestsPage.debugAskTimerOnMark = true);
    tearDown(() => QuestsPage.debugAskTimerOnMark = false);

    final heroOffer = find.byKey(
      const ValueKey('quest-timer-offer-Read 20 pages'),
    );

    testWidgets('the leading card offers it in words, with what it is for; '
        'a row offers a small round button; push-ups offer nothing', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final timer = QuestTimer(alerts: _Alerts());
      await _pumpBoard(
        tester,
        state: GameState(),
        quests: [_reading(), _pushups()],
        timer: timer,
      );
      expect(heroOffer, findsOneWidget);
      expect(find.text('Start a 20-minute timer'), findsOneWidget);
      expect(
        find.text('Counts extra toward this week’s training'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('quest-timer-offer-Do 5 push-ups')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());

      // The same Quest in a row, not leading.
      await _pumpBoard(
        tester,
        state: GameState(),
        quests: [_pushups(), _reading()],
        timer: timer,
      );
      await _show(tester, heroOffer);
      expect(find.text('Start a 20-minute timer'), findsNothing);
      expect(
        find.bySemanticsLabel('Start a 20-minute timer for Read 20 pages'),
        findsOneWidget,
      );
      expect(tester.getSize(heroOffer).shortestSide, greaterThanOrEqualTo(44));
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
      timer.dispose();
    });

    testWidgets('one tap starts it, opens it running, and leaving never '
        'stops it', (tester) async {
      final alerts = _Alerts();
      final timer = QuestTimer(alerts: alerts);
      final reading = _reading();
      final state = GameState()..notifyEnabled = true;
      await _pumpBoard(
        tester,
        state: state,
        quests: [reading, _pushups()],
        timer: timer,
      );
      await tester.tap(find.text('Start a 20-minute timer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // It is running at once, saved, with a reminder set for its end.
      expect(timer.sessionFor(reading), isNotNull);
      expect(timer.session!.minutes, 20);
      expect(alerts.scheduled, [start.add(const Duration(minutes: 20))]);
      expect(find.byKey(const Key('timer-clock')), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget);
      expect(find.text('IN SESSION'), findsOneWidget);
      expect(timer.overlayOpen, isTrue);

      // Leave the page: the timer goes on.
      await tester.ensureVisible(find.byKey(const Key('timer-back')));
      await tester.tap(find.byKey(const Key('timer-back')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('timer-clock')), findsNothing);
      expect(timer.overlayOpen, isFalse);
      expect(timer.isRunning(), isTrue);
      expect(reading.doneFor(Clock.now()), isFalse);

      // Eight minutes pass with the app away; coming back shows the true time.
      Clock.freeze(start.add(const Duration(minutes: 8)));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Timer running · 12:00'), findsOneWidget);

      // Open it again from the card: the same timer, not a new one.
      await tester.tap(find.text('Timer running · 12:00'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('12:00'), findsOneWidget);
      expect(timer.session!.startedAt, start);

      await tester.ensureVisible(find.byKey(const Key('timer-stop')));
      await tester.tap(find.byKey(const Key('timer-stop')));
      await tester.pump();
      await tester.pump();
      expect(timer.hasSession, isFalse);
      expect(alerts.cancels, greaterThan(0));
      await tester.pumpWidget(const SizedBox.shrink());
      timer.dispose();
    });

    testWidgets('a row shows the clock beside its round button while it '
        'runs', (tester) async {
      final timer = QuestTimer(alerts: _Alerts());
      final reading = _reading();
      await timer.start(quest: reading, minutes: 20);
      await _pumpBoard(
        tester,
        state: GameState(),
        quests: [_pushups(), reading],
        timer: timer,
      );
      await _show(
        tester,
        find.byKey(const ValueKey('quest-timer-running-Read 20 pages')),
      );
      expect(find.text('20:00'), findsOneWidget);
      Clock.freeze(start.add(const Duration(minutes: 5)));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('15:00'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      timer.dispose();
    });

    testWidgets('after a restart the finished timer is claimed as the proof '
        'it is: timerProven, and the receipt says so', (tester) async {
      // Started before the app was closed.
      final before = QuestTimer(alerts: _Alerts());
      final reading = _reading();
      await before.start(quest: reading, minutes: 20);
      before.dispose();

      // The app comes back twenty-five minutes later.
      Clock.freeze(start.add(const Duration(minutes: 25)));
      final timer = QuestTimer(alerts: _Alerts());
      await timer.load();
      expect(timer.isFinished(), isTrue);

      final state = GameState(rng: _NoLuck());
      await _pumpBoard(
        tester,
        state: state,
        quests: [reading, _pushups()],
        timer: timer,
      );
      expect(find.text('Time’s up · finish it'), findsOneWidget);

      await tester.tap(find.text('Time’s up · finish it'));
      await tester.pump();
      expect(reading.doneFor(Clock.now()), isTrue);
      // The receipt's lines rise one by one; watch for the Timed line.
      final timedLine = find.text(
        'Timed · counts extra toward this week’s training',
      );
      for (var step = 0; step < 60 && timedLine.evaluate().isEmpty; step++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(timedLine, findsOneWidget);
      await tester.pump(const Duration(seconds: 3));

      expect(state.completionLog, hasLength(1));
      expect(state.completionLog.single.timerProven, isTrue);
      expect(state.completionLog.single.stat, Stat.intl);
      expect(state.verifiedCompletions, 1);
      expect(timer.hasSession, isFalse);

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpWidget(const SizedBox.shrink());
      timer.dispose();
    });

    testWidgets('a timer that ends while its screen is open finishes the '
        'Quest there', (tester) async {
      final timer = QuestTimer(alerts: _Alerts());
      final reading = _reading();
      final state = GameState(rng: _NoLuck());
      await _pumpBoard(
        tester,
        state: state,
        quests: [reading, _pushups()],
        timer: timer,
      );
      await tester.tap(find.text('Start a 20-minute timer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      Clock.freeze(start.add(const Duration(minutes: 20, seconds: 1)));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(reading.doneFor(Clock.now()), isTrue);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(seconds: 3));
      expect(state.completionLog.single.timerProven, isTrue);
      expect(timer.hasSession, isFalse);

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpWidget(const SizedBox.shrink());
      timer.dispose();
    });

    testWidgets('"I already did it" still finishes the Quest without the '
        'proof, and ends the timer', (tester) async {
      final timer = QuestTimer(alerts: _Alerts());
      final reading = _reading();
      final state = GameState(rng: _NoLuck());
      await _pumpBoard(
        tester,
        state: state,
        quests: [reading, _pushups()],
        timer: timer,
      );
      await tester.tap(find.text('Start a 20-minute timer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.ensureVisible(find.byKey(const Key('timer-honor')));
      await tester.tap(find.byKey(const Key('timer-honor')));
      await tester.pump();
      expect(reading.doneFor(Clock.now()), isTrue);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(seconds: 3));
      expect(state.completionLog.single.timerProven, isFalse);
      expect(state.verifiedCompletions, 0);
      expect(timer.hasSession, isFalse);

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpWidget(const SizedBox.shrink());
      timer.dispose();
    });

    testWidgets('marking a Quest that fits a timer asks "Time it?" first; '
        '"Just mark it done" marks it, untimed', (tester) async {
      final timer = QuestTimer(alerts: _Alerts());
      final reading = _reading();
      final state = GameState(rng: _NoLuck());
      await _pumpBoard(
        tester,
        state: state,
        quests: [reading, _pushups()],
        timer: timer,
      );
      await tester.tap(find.byKey(const ValueKey('quest-primary-action')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('quest-timer-offer-sheet')), findsOneWidget);
      expect(find.text('TIME IT?'), findsOneWidget);
      expect(reading.doneFor(Clock.now()), isFalse);
      // Two ways on, both one tap, both plain.
      expect(find.byKey(const Key('quest-timer-sheet-start')), findsOneWidget);
      expect(find.byKey(const Key('quest-timer-sheet-skip')), findsOneWidget);
      expect(find.text('Just mark it done'), findsOneWidget);

      await tester.tap(find.byKey(const Key('quest-timer-sheet-skip')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(reading.doneFor(Clock.now()), isTrue);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(seconds: 3));
      expect(state.completionLog.single.timerProven, isFalse);
      expect(timer.hasSession, isFalse);
      expect(
        timer.shouldAsk(reading),
        isTrue,
        reason: 'asked once, not thrice',
      );

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpWidget(const SizedBox.shrink());
      timer.dispose();
    });

    testWidgets('the question can be answered with the timer', (tester) async {
      final timer = QuestTimer(alerts: _Alerts());
      final reading = _reading();
      await _pumpBoard(
        tester,
        state: GameState(),
        quests: [reading, _pushups()],
        timer: timer,
      );
      await tester.tap(find.byKey(const ValueKey('quest-primary-action')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('quest-timer-sheet-start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(timer.sessionFor(reading), isNotNull);
      expect(reading.doneFor(Clock.now()), isFalse);
      expect(find.byKey(const Key('timer-clock')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('timer-stop')));
      await tester.tap(find.byKey(const Key('timer-stop')));
      await tester.pump();
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      timer.dispose();
    });

    testWidgets('after three "just mark it done"s the question stops', (
      tester,
    ) async {
      final timer = QuestTimer(alerts: _Alerts());
      final reading = _reading();
      for (var i = 0; i < QuestTimer.askLimit; i++) {
        expect(timer.shouldAsk(reading), isTrue);
        await timer.recordDecline(reading);
      }
      expect(timer.shouldAsk(reading), isFalse);
      expect(timer.shouldAsk(_pushups()), isTrue, reason: 'per Quest');

      // It is remembered across a restart.
      final reopened = QuestTimer(alerts: _Alerts());
      await reopened.load();
      expect(reopened.shouldAsk(reading), isFalse);

      final state = GameState(rng: _NoLuck());
      await _pumpBoard(
        tester,
        state: state,
        quests: [reading, _pushups()],
        timer: reopened,
      );
      await tester.tap(find.byKey(const ValueKey('quest-primary-action')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('quest-timer-offer-sheet')), findsNothing);
      expect(reading.doneFor(Clock.now()), isTrue);
      await tester.pump(const Duration(seconds: 12));
      await tester.pumpWidget(const SizedBox.shrink());
      timer.dispose();
      reopened.dispose();
    });

    testWidgets('a timer Quest keeps its own session door and is not asked', (
      tester,
    ) async {
      final timer = QuestTimer(alerts: _Alerts());
      await _pumpBoard(
        tester,
        state: GameState(),
        quests: [_timed(), _pushups()],
        timer: timer,
      );
      expect(find.text('Open 12-minute session'), findsOneWidget);
      expect(find.text('Start a 12-minute timer'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('quest-primary-action')));
      await tester.pump();
      expect(find.byKey(const Key('quest-timer-offer-sheet')), findsNothing);
      expect(find.text('READY'), findsOneWidget);

      // Start there is saved too, so leaving does not stop it.
      await tester.ensureVisible(find.byKey(const Key('timer-start')));
      await tester.tap(find.byKey(const Key('timer-start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(timer.session?.questKey, 'Focus proof');
      expect(timer.session?.minutes, 12);
      await tester.ensureVisible(find.byKey(const Key('timer-back')));
      await tester.tap(find.byKey(const Key('timer-back')));
      await tester.pump();
      await tester.pump();
      expect(timer.isRunning(), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      timer.dispose();
    });
  });
}

class _NoLuck implements Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.999999;
  @override
  int nextInt(int max) => 0;
}
