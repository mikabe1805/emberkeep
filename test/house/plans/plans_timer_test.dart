// The quest timer's offer on Plans (2026-10-14): a chosen Quest that fits a
// timer carries "Start a 20-minute timer" under its card; one that does not
// carries nothing; once its timer runs the card says how long is left and
// opens it again.
import 'package:emberkeep/academic_calendar/data/academic_calendar_preferences.dart';
import 'package:emberkeep/academic_calendar/data/academic_schedule_repository.dart';
import 'package:emberkeep/academic_calendar/services/notebook_handoff.dart';
import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/quest_timer.dart';
import 'package:emberkeep/screens/calendar.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _monday = DateTime(2026, 10, 12, 11, 42);

final class _Handoff implements NotebookHandoff {
  @override
  Future<NotebookHandoffResult> open(NotebookHandoffIntent intent) async =>
      NotebookHandoffResult.opened;
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

Quest _chosen(String title, {String? doneOn}) => Quest(
  title: title,
  stat: Stat.intl,
  difficulty: 2,
  priorityDay: Days.key(_monday),
  lastDoneDay: doneOn,
);

Future<List<Quest>> _pump(
  WidgetTester tester, {
  required List<Quest> quests,
  required QuestTimer timer,
  required void Function(Quest quest) onStart,
  double textScale = 1,
}) async {
  Clock.freeze(_monday);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  await tester.binding.setSurfaceSize(const Size(393, 852));
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: QuestTimerScope(
          timer: timer,
          child: CalendarPage(
            state: GameState()
              ..onboarded = true
              ..reduceMotion = true,
            quests: quests,
            onAdd: (_) => true,
            onCompleteQuest: (quest, anchor) {},
            onStartQuestTimer: onStart,
            scheduleRepository: InMemoryAcademicScheduleRepository(null),
            calendarPreferences: InMemoryAcademicCalendarPreferences(
              state: AcademicCalendarViewState(
                mode: AcademicCalendarMode.day,
                selectedDate: null,
              ),
            ),
            notebookHandoff: _Handoff(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  return quests;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Sfx.instance.soundEnabled = false;
  });

  tearDown(() {
    Clock.reset();
    Sfx.instance.soundEnabled = true;
  });

  testWidgets('a chosen reading Quest offers a timer; push-ups, a timer '
      'Quest and a finished Quest do not', (tester) async {
    final timer = QuestTimer(alerts: _Alerts());
    final started = <Quest>[];
    final reading = _chosen('Read 20 pages');
    await _pump(
      tester,
      quests: [
        reading,
        _chosen('Do 5 push-ups'),
        Quest(
          title: 'Focus session',
          stat: Stat.foc,
          difficulty: 2,
          verification: Verification.timer,
          timerMinutes: 25,
          priorityDay: Days.key(_monday),
        ),
        _chosen('Practice guitar', doneOn: Days.key(_monday)),
      ],
      timer: timer,
      onStart: started.add,
    );

    expect(find.text('Start a 20-minute timer'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('quest-timer-offer-Read 20 pages')),
      findsOneWidget,
    );
    final pill = find.byKey(const ValueKey('quest-timer-offer-Read 20 pages'));
    expect(tester.getSize(pill).height, greaterThanOrEqualTo(44));

    await tester.ensureVisible(find.text('Start a 20-minute timer'));
    await tester.pump();
    await tester.tap(find.text('Start a 20-minute timer'));
    await tester.pump();
    expect(started, [reading]);
    await tester.pumpWidget(const SizedBox.shrink());
    timer.dispose();
  });

  testWidgets('once it runs, the card says how long is left and opens it', (
    tester,
  ) async {
    final timer = QuestTimer(alerts: _Alerts());
    final started = <Quest>[];
    final reading = _chosen('Read 20 pages');
    await timer.start(quest: reading, minutes: 20);
    await _pump(
      tester,
      quests: [reading, _chosen('Practice guitar')],
      timer: timer,
      onStart: started.add,
    );

    expect(find.text('Timer running · 20:00'), findsOneWidget);
    // One timer at a time: the other Quest's offer waits.
    expect(find.text('Start a 20-minute timer'), findsNothing);

    await tester.tap(find.text('Timer running · 20:00'));
    await tester.pump();
    expect(started, [reading]);
    await tester.pumpWidget(const SizedBox.shrink());
    timer.dispose();
  });

  testWidgets('the offer holds at 200% text', (tester) async {
    final timer = QuestTimer(alerts: _Alerts());
    await _pump(
      tester,
      quests: [_chosen('Read 20 pages')],
      timer: timer,
      onStart: (_) {},
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Start a 20-minute timer'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    timer.dispose();
  });
}
