// The quest timer that keeps running: which Quests are offered one, how it
// survives leaving and restarting, the reminder at its end, and the proof it
// writes into the completion record.
import 'dart:convert';

import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/quest_timer.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAlerts implements QuestTimerAlerts {
  final scheduled = <({DateTime at, String title, String body})>[];
  int cancels = 0;

  @override
  Future<void> schedule({
    required DateTime at,
    required String title,
    required String body,
  }) async {
    scheduled.add((at: at, title: title, body: body));
  }

  @override
  Future<void> cancel() async => cancels++;
}

Quest _quest(
  String title, {
  Stat stat = Stat.intl,
  Verification verification = Verification.honor,
  int timerMinutes = 0,
  bool workout = false,
  bool allDay = false,
  JournalQuestPrompt? journalPrompt,
  DateTime? dueDate,
  QuestSchedule schedule = QuestSchedule.daily,
}) => Quest(
  title: title,
  stat: stat,
  difficulty: 3,
  verification: verification,
  timerMinutes: timerMinutes,
  workout: workout,
  allDay: allDay,
  journalPrompt: journalPrompt,
  dueDate: dueDate,
  schedule: schedule,
);

void main() {
  final start = DateTime(2026, 10, 14, 15, 0); // a Wednesday afternoon

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Clock.freeze(start);
  });

  tearDown(Clock.reset);

  group('which Quests are offered a timer', () {
    test('reading, studying, practice, meditation and workouts are', () {
      expect(timerOfferFor(_quest('Read 20 pages'))?.minutes, 20);
      expect(timerOfferFor(_quest('Study for the chem exam'))?.minutes, 20);
      expect(timerOfferFor(_quest('Practice guitar'))?.minutes, 20);
      expect(timerOfferFor(_quest('Meditate'))?.minutes, 10);
      expect(timerOfferFor(_quest('Full workout session'))?.minutes, 20);
      expect(timerOfferFor(_quest('Go for a run'))?.minutes, 20);
    });

    test('a Quest that names its minutes is offered exactly those', () {
      expect(timerOfferFor(_quest('Stretch for 15 minutes'))?.minutes, 15);
      expect(timerOfferFor(_quest('Tidy up, 12 min'))?.minutes, 12);
      expect(timerOfferFor(_quest('Walk the dog for an hour'))?.minutes, 60);
      expect(timerOfferFor(_quest('Read for 45 minutes'))?.minutes, 45);
    });

    test('the offer says how long, plainly', () {
      expect(
        timerOfferFor(_quest('Read 20 pages'))?.label,
        'Start a 20-minute timer',
      );
    });

    test('a Quest with nothing to time is not', () {
      expect(timerOfferFor(_quest('Do 5 push-ups')), isNull);
      expect(timerOfferFor(_quest('Take your pills')), isNull);
      expect(timerOfferFor(_quest('Make your bed')), isNull);
      expect(timerOfferFor(_quest('Water the plants')), isNull);
      expect(timerOfferFor(_quest('Run errands')), isNull);
    });

    test('a length in front of a moment is not a session', () {
      expect(
        timerOfferFor(_quest('Dim the lights an hour before bed')),
        isNull,
      );
      expect(timerOfferFor(_quest('Be in bed 30 minutes before 11')), isNull);
      expect(timerOfferFor(_quest('Leave 15 minutes early')), isNull);
    });

    test('a timer Quest offers its own saved session, marked inherent', () {
      final timed = _quest(
        'Focus session',
        verification: Verification.timer,
        timerMinutes: 25,
      );
      final offer = timerOfferFor(timed)!;
      expect(offer.minutes, 25);
      expect(offer.inherent, isTrue);
      expect(timerOfferFor(_quest('Read 20 pages'))!.inherent, isFalse);
    });

    test('a journal, an all-day line, a guided workout, a dated plan and a '
        'Quest already done are not', () {
      expect(
        timerOfferFor(
          _quest(
            'Read and write it down',
            journalPrompt: const JournalQuestPrompt(starter: 'Today I read'),
          ),
        ),
        isNull,
      );
      expect(timerOfferFor(_quest('Read all day', allDay: true)), isNull);
      expect(timerOfferFor(_quest('Full workout', workout: true)), isNull);
      expect(
        timerOfferFor(
          _quest(
            'Read the lease',
            schedule: QuestSchedule.once,
            dueDate: DateTime(2026, 10, 20),
          ),
        ),
        isNull,
      );
      final done = _quest('Read 20 pages')..lastDoneDay = Days.key(start);
      expect(timerOfferFor(done), isNull);
    });
  });

  group('one timer on a wall clock', () {
    test(
      'it begins and ends on the clock, and shows the true time left',
      () async {
        final timer = QuestTimer(alerts: _FakeAlerts());
        final quest = _quest('Read 20 pages');
        final session = await timer.start(quest: quest, minutes: 20);

        expect(session.startedAt, start);
        expect(session.endsAt, start.add(const Duration(minutes: 20)));
        expect(timer.isRunning(), isTrue);
        expect(timer.remaining(), const Duration(minutes: 20));

        Clock.freeze(start.add(const Duration(minutes: 7, seconds: 30)));
        expect(timer.remaining(), const Duration(minutes: 12, seconds: 30));
        expect(timer.isFinished(), isFalse);

        Clock.freeze(start.add(const Duration(minutes: 20)));
        expect(timer.isFinished(), isTrue);
        expect(timer.remaining(), Duration.zero);
        timer.dispose();
      },
    );

    test('a clock set back cannot stretch it past its length', () async {
      final timer = QuestTimer(alerts: _FakeAlerts());
      await timer.start(quest: _quest('Read 20 pages'), minutes: 20);
      Clock.freeze(start.subtract(const Duration(hours: 3)));
      expect(timer.remaining(), const Duration(minutes: 20));
      timer.dispose();
    });

    test(
      'it survives an app restart: a new timer reads the same one',
      () async {
        final first = QuestTimer(alerts: _FakeAlerts());
        final quest = _quest('Read 20 pages');
        await first.start(quest: quest, minutes: 20);
        first.dispose();

        // The app is closed for eleven minutes and opened again.
        Clock.freeze(start.add(const Duration(minutes: 11)));
        final reopened = QuestTimer(alerts: _FakeAlerts());
        expect(reopened.hasSession, isFalse);
        await reopened.load();

        expect(reopened.hasSession, isTrue);
        expect(reopened.sessionFor(quest), isNotNull);
        expect(reopened.session!.questTitle, 'Read 20 pages');
        expect(reopened.isRunning(), isTrue);
        expect(reopened.remaining(), const Duration(minutes: 9));
        reopened.dispose();
      },
    );

    test('closed past its end, it is finished and waiting, not lost', () async {
      final first = QuestTimer(alerts: _FakeAlerts());
      await first.start(quest: _quest('Read 20 pages'), minutes: 20);
      first.dispose();

      Clock.freeze(start.add(const Duration(minutes: 90)));
      final reopened = QuestTimer(alerts: _FakeAlerts());
      await reopened.load();
      expect(reopened.isFinished(), isTrue);
      expect(reopened.remaining(), Duration.zero);
      reopened.dispose();
    });

    test(
      'background time passing: nothing is counted, so nothing stops',
      () async {
        // No ticker runs anywhere: the only thing that moves is the clock.
        final timer = QuestTimer(alerts: _FakeAlerts());
        await timer.start(quest: _quest('Read 20 pages'), minutes: 20);
        for (final minutes in [1, 5, 13, 19]) {
          Clock.freeze(start.add(Duration(minutes: minutes)));
          expect(timer.remaining(), Duration(minutes: 20 - minutes));
          expect(timer.isRunning(), isTrue);
        }
        Clock.freeze(start.add(const Duration(minutes: 20, seconds: 1)));
        expect(timer.isFinished(), isTrue);
        timer.dispose();
      },
    );

    test('stopping it forgets it, even across a restart', () async {
      final timer = QuestTimer(alerts: _FakeAlerts());
      await timer.start(quest: _quest('Read 20 pages'), minutes: 20);
      await timer.clear();
      expect(timer.hasSession, isFalse);

      final reopened = QuestTimer(alerts: _FakeAlerts());
      await reopened.load();
      expect(reopened.hasSession, isFalse);
      timer.dispose();
      reopened.dispose();
    });

    test('a damaged save reads as no timer', () async {
      for (final bad in [
        'not json',
        '[]',
        jsonEncode({'questKey': 'x'}),
        jsonEncode({
          'questKey': 'x',
          'questTitle': 'x',
          'minutes': 0,
          'startedAt': 1,
          'endsAt': 2,
        }),
        jsonEncode({
          'questKey': 'x',
          'questTitle': 'x',
          'minutes': 20,
          'startedAt': 5,
          'endsAt': 5,
        }),
      ]) {
        SharedPreferences.setMockInitialValues({QuestTimer.storageKey: bad});
        final timer = QuestTimer(alerts: _FakeAlerts());
        await timer.load();
        expect(timer.hasSession, isFalse, reason: bad);
        timer.dispose();
      }
    });

    test('only one timer runs: a new one replaces the old', () async {
      final timer = QuestTimer(alerts: _FakeAlerts());
      final reading = _quest('Read 20 pages');
      final guitar = _quest('Practice guitar');
      await timer.start(quest: reading, minutes: 20);
      await timer.start(quest: guitar, minutes: 15);
      expect(timer.sessionFor(reading), isNull);
      expect(timer.sessionFor(guitar)?.minutes, 15);
      timer.dispose();
    });

    test(
      'the finish is announced once, and never behind the full screen',
      () async {
        final timer = QuestTimer(alerts: _FakeAlerts());
        await timer.start(quest: _quest('Read 20 pages'), minutes: 20);
        expect(timer.checkFinished(), isFalse);

        Clock.freeze(start.add(const Duration(minutes: 21)));
        timer.overlayOpen = true;
        expect(
          timer.checkFinished(),
          isFalse,
          reason: 'the overlay has its own',
        );
        timer.overlayOpen = false;
        expect(timer.checkFinished(), isTrue);
        expect(timer.checkFinished(), isFalse);
        timer.dispose();
      },
    );
  });

  group('the reminder at its end', () {
    test(
      'with Reminders on, one local notification is set for the end',
      () async {
        final alerts = _FakeAlerts();
        final timer = QuestTimer(alerts: alerts);
        await timer.start(
          quest: _quest('Read 20 pages'),
          minutes: 20,
          remindersOn: true,
        );

        expect(alerts.scheduled, hasLength(1));
        expect(
          alerts.scheduled.single.at,
          start.add(const Duration(minutes: 20)),
        );
        expect(alerts.scheduled.single.title, 'Time’s up');
        expect(alerts.scheduled.single.body, contains('Read 20 pages'));
        expect(alerts.scheduled.single.body, contains('20 minutes'));
        timer.dispose();
      },
    );

    test('with Reminders off, nothing is scheduled', () async {
      final alerts = _FakeAlerts();
      final timer = QuestTimer(alerts: alerts);
      await timer.start(quest: _quest('Read 20 pages'), minutes: 20);
      expect(alerts.scheduled, isEmpty);
      timer.dispose();
    });

    test('stopping it takes the reminder back', () async {
      final alerts = _FakeAlerts();
      final timer = QuestTimer(alerts: alerts);
      await timer.start(
        quest: _quest('Read 20 pages'),
        minutes: 20,
        remindersOn: true,
      );
      final before = alerts.cancels;
      await timer.clear();
      expect(alerts.cancels, greaterThan(before));
      timer.dispose();
    });

    test('a reminder that cannot be set never stops the timer', () async {
      final timer = QuestTimer(alerts: _ThrowingAlerts());
      await timer.start(
        quest: _quest('Read 20 pages'),
        minutes: 20,
        remindersOn: true,
      );
      expect(timer.isRunning(), isTrue);
      timer.dispose();
    });

    test('the words are plain: no dash, no loss word', () async {
      final alerts = _FakeAlerts();
      final timer = QuestTimer(alerts: alerts);
      await timer.start(
        quest: _quest('Read 20 pages'),
        minutes: 20,
        remindersOn: true,
      );
      final text =
          '${alerts.scheduled.single.title} '
          '${alerts.scheduled.single.body}';
      expect(text.contains('—'), isFalse);
      expect(text.contains('–'), isFalse);
      for (final word in [
        'failed',
        'missed',
        'lost',
        'broke',
        'behind',
        'overdue',
      ]) {
        expect(text.toLowerCase(), isNot(contains(word)));
      }
      timer.dispose();
    });
  });

  group('the proof in the completion record', () {
    test('a completion through a finished timer is marked timerProven', () {
      final state = GameState();
      final quest = _quest('Read 20 pages');
      final bundle = state.roll(quest, verified: true);
      state.commit(bundle);

      expect(state.completionLog, hasLength(1));
      expect(state.completionLog.single.timerProven, isTrue);
      expect(state.completionLog.single.stat, Stat.intl);
      expect(state.completionLog.single.at, start);
    });

    test('an ordinary completion is not', () {
      final state = GameState();
      state.commit(state.roll(_quest('Read 20 pages')));
      expect(state.completionLog.single.timerProven, isFalse);
    });

    test('the flag defaults to false and is written only when true', () {
      final plain = CompletionRecord(stat: Stat.str, at: start);
      expect(plain.timerProven, isFalse);
      expect(plain.toJson().containsKey('timerProven'), isFalse);

      final proven = CompletionRecord(
        stat: Stat.str,
        at: start,
        timerProven: true,
      );
      expect(proven.toJson()['timerProven'], isTrue);
      final back = CompletionRecord.fromJson(proven.toJson())!;
      expect(back.timerProven, isTrue);
      expect(back.stat, Stat.str);
      expect(back.at, start);
    });

    test('it saves and loads with the rest of the save', () {
      final state = GameState();
      state.commit(state.roll(_quest('Read 20 pages'), verified: true));
      state.commit(state.roll(_quest('Do 5 push-ups', stat: Stat.str)));

      final restored = GameState.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
      );
      expect(restored.completionLog, hasLength(2));
      expect(restored.completionLog[0].timerProven, isTrue);
      expect(restored.completionLog[0].stat, Stat.intl);
      expect(restored.completionLog[1].timerProven, isFalse);
      expect(restored.completionLog[1].stat, Stat.str);
    });

    test('a save from before the record reads with none', () {
      final json =
          jsonDecode(jsonEncode(GameState().toJson())) as Map<String, dynamic>;
      expect(json.containsKey('completionLog'), isFalse);
      expect(GameState.fromJson(json).completionLog, isEmpty);
    });

    test('damaged entries are dropped one by one', () {
      final json =
          jsonDecode(jsonEncode(GameState().toJson())) as Map<String, dynamic>;
      json['completionLog'] = [
        {'stat': 99, 'at': start.millisecondsSinceEpoch},
        'nonsense',
        {'stat': 1},
        {'stat': 1, 'at': start.millisecondsSinceEpoch, 'timerProven': true},
      ];
      final restored = GameState.fromJson(json);
      expect(restored.completionLog, hasLength(1));
      expect(restored.completionLog.single.timerProven, isTrue);
    });

    test('only the last two weeks are kept', () {
      final state = GameState();
      Clock.freeze(start.subtract(const Duration(days: 20)));
      state.commit(state.roll(_quest('Read 20 pages')));
      Clock.freeze(start);
      state.commit(state.roll(_quest('Practice guitar')));
      expect(state.completionLog, hasLength(1));
      expect(state.completionLog.single.at, start);
    });
  });

  test('the clock reads like a clock', () {
    expect(questTimerClock(const Duration(minutes: 19, seconds: 42)), '19:42');
    expect(questTimerClock(const Duration(seconds: 5)), '0:05');
    expect(questTimerClock(const Duration(hours: 1, minutes: 5)), '1:05:00');
    expect(questTimerClock(const Duration(seconds: -4)), '0:00');
  });
}

class _ThrowingAlerts implements QuestTimerAlerts {
  @override
  Future<void> schedule({
    required DateTime at,
    required String title,
    required String body,
  }) async => throw StateError('no notifications here');

  @override
  Future<void> cancel() async => throw StateError('no notifications here');
}
