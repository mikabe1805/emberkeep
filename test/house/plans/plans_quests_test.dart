// Quests on Plans, and the small things around them (2026-10-12).
//
// The ring on a Quest's card finishes it through the Quests page's own path, on
// any day's page: XP, stats, the completion sound and haptic, the reward, the
// undo, the Journal door. A chosen Quest says its own day ("CHOSEN FOR SUN",
// never "TODAY" on another day's page). A new day opens Plans on today in the
// view it was left in. BACK TO TODAY sits whole on the page, legible, 44 pt.
//
// The Quests page is mounted beside Plans, as the shell mounts it, and Plans is
// handed its completion the way the shell hands it over.
import 'dart:math' as math;
import 'dart:ui' show Tristate;

import 'package:emberkeep/academic_calendar/data/academic_calendar_preferences.dart';
import 'package:emberkeep/academic_calendar/data/academic_schedule_repository.dart';
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/services/notebook_handoff.dart';
import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/daybook/presentation/daybook_range_projection.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/calendar.dart';
import 'package:emberkeep/screens/journal_entry.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/house/plans/plans_cards.dart';
import 'package:emberkeep/widgets/house/plans/plans_dates.dart';
import 'package:emberkeep/widgets/house/plans/plans_day_view.dart'
    show PlansArrow;
import 'package:emberkeep/widgets/house/plans/plans_geometry.dart';
import 'package:emberkeep/widgets/quest_desk.dart' show QuestCompletionStitch;
import 'package:emberkeep/widgets/reward_receipt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Monday 12 October 2026, 11:42: the moment of the owner's screenshot.
final _monday = DateTime(2026, 10, 12, 11, 42);
final _sunday = DateTime(2026, 10, 11, 21, 30);

class _NoLuck implements math.Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.999;
  @override
  int nextInt(int max) => 0;
}

final class _Handoff implements NotebookHandoff {
  @override
  Future<NotebookHandoffResult> open(NotebookHandoffIntent intent) async =>
      NotebookHandoffResult.opened;
}

Quest _quest(
  String title, {
  String? chosenFor,
  QuestSchedule schedule = QuestSchedule.daily,
  String? doneOn,
  JournalQuestPrompt? prompt,
}) => Quest(
  title: title,
  stat: Stat.foc,
  difficulty: 2,
  schedule: schedule,
  priorityDay: chosenFor,
  lastDoneDay: doneOn,
  journalPrompt: prompt,
);

/// What the test holds on to: the live state, the Quests, and what the Quests
/// page was asked to do.
class _Rig {
  _Rig(this.state, this.quests);

  final GameState state;
  final List<Quest> quests;

  /// Whether Plans (true) or the Quests page (false) is the room on screen.
  final showPlans = ValueNotifier<bool>(true);

  /// Snapshots the Quests page was asked to restore (its undo).
  final restored = <String>[];

  /// The Quests Plans handed over to be finished.
  final handedOver = <Quest>[];
  int persisted = 0;
  void Function(Quest quest, Offset anchor)? complete;
}

Future<_Rig> _pump(
  WidgetTester tester, {
  required List<Quest> quests,
  DateTime? now,
  String? date,
  AcademicCalendarMode mode = AcademicCalendarMode.day,
  AcademicCalendarPreferences? preferences,
  AcademicSchedule? schedule,
  double textScale = 1,
  Size size = const Size(393, 852),
}) async {
  Clock.freeze(now ?? _monday);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.binding.setSurfaceSize(null);
  });
  final rig = _Rig(
    GameState(rng: _NoLuck())
      ..onboarded = true
      ..reduceMotion = true,
    quests,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: rig.showPlans,
          builder: (context, plans, _) => Stack(
            children: [
              // Each room stays alive and its tickers run only while it is
              // the one on screen, as in the shell.
              TickerMode(
                enabled: !plans,
                child: Offstage(
                  offstage: plans,
                  child: QuestsPage(
                    state: rig.state,
                    quests: quests,
                    onRefresh: () => 0,
                    onPersist: () => rig.persisted++,
                    onAdd: (_) => true,
                    onRemove: (_) {},
                    onSnapshot: () => 'snapshot-before',
                    // What the shell's restore does to the board.
                    onRestore: (snapshot) {
                      rig.restored.add(snapshot);
                      for (final q in quests) {
                        if (q.lastDoneDay == Days.key(Clock.now())) {
                          q.lastDoneDay = null;
                        }
                      }
                    },
                    onBindComplete: (complete) => rig.complete = complete,
                  ),
                ),
              ),
              TickerMode(
                enabled: plans,
                child: Offstage(
                  offstage: !plans,
                  child: CalendarPage(
                    state: rig.state,
                    quests: quests,
                    onAdd: (_) => true,
                    onCompleteQuest: (quest, anchor) {
                      rig.handedOver.add(quest);
                      rig.complete!(quest, anchor);
                    },
                    scheduleRepository: InMemoryAcademicScheduleRepository(
                      schedule,
                    ),
                    calendarPreferences:
                        preferences ??
                        InMemoryAcademicCalendarPreferences(
                          state: AcademicCalendarViewState(
                            mode: mode,
                            selectedDate: date,
                          ),
                        ),
                    notebookHandoff: _Handoff(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  return rig;
}

/// The ring on a Quest's card.
Finder _ring(String title) => find.byKey(ValueKey('quest-plan-toggle-$title'));

bool _ringDone(WidgetTester tester, String title) => tester
    .widget<PlansRing>(
      find.descendant(of: _ring(title), matching: find.byType(PlansRing)),
    )
    .done;

Finder get _back => find.byKey(const ValueKey('calendar-back-to-today'));

/// Sends the app to the background and back, as putting the phone down and
/// picking it up does.
Future<void> _reopen(WidgetTester tester) async {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump(const Duration(milliseconds: 100));
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

/// Lets the page turn and any reward that is flying finish.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(seconds: 6));
}

void main() {
  setUp(() {
    // The Quests room as the app leads with it: today's three at the Doorway.
    QuestsPage.debugLegacyBoard = false;
    Sfx.instance.soundEnabled = false;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    QuestsPage.debugLegacyBoard = true;
    Clock.reset();
    Sfx.instance.soundEnabled = true;
  });

  group('the words', () {
    final today = CivilDate(2026, 10, 12);

    test('a chosen Quest says its own day, and never "today" for another', () {
      expect(plansChosenFor(today, today), 'CHOSEN FOR TODAY');
      expect(
        plansChosenFor(CivilDate(2026, 10, 13), today),
        'CHOSEN FOR TOMORROW',
      );
      expect(plansChosenFor(CivilDate(2026, 10, 11), today), 'CHOSEN FOR SUN');
      expect(plansChosenFor(CivilDate(2026, 10, 5), today), 'CHOSEN FOR MON');
      expect(plansChosenFor(CivilDate(2026, 10, 22), today), 'CHOSEN FOR THU');
    });

    test(
      'the heading over them is TODAY’S FOCUS on today and FOCUS otherwise',
      () {
        expect(plansFocusHeading(today, today), 'TODAY’S FOCUS');
        expect(plansFocusHeading(CivilDate(2026, 10, 11), today), 'FOCUS');
        expect(plansFocusHeading(CivilDate(2026, 10, 13), today), 'FOCUS');
      },
    );

    test('a screen reader hears the same day', () {
      expect(plansChosenForSpoken(today, today), 'today’s focus');
      expect(
        plansChosenForSpoken(CivilDate(2026, 10, 13), today),
        'chosen for tomorrow',
      );
      expect(
        plansChosenForSpoken(CivilDate(2026, 10, 11), today),
        'chosen for Sunday',
      );
    });

    test('no loss word and no em dash in what a card says', () {
      final words = [
        for (var d = 0; d < 14; d++) ...[
          plansChosenFor(today.addDays(d - 7), today),
          plansChosenForSpoken(today.addDays(d - 7), today),
          plansFocusHeading(today.addDays(d - 7), today),
        ],
        'DONE TODAY',
        'Complete a Quest',
        'Counts as done today',
        'UNDO IN QUESTS',
        'BACK TO TODAY',
      ].join(' ').toLowerCase();
      for (final banned in ['—', 'fail', 'miss', 'lost', 'broke']) {
        expect(words, isNot(contains(banned)), reason: banned);
      }
    });
  });

  group('what a day holds for a Quest finished today', () {
    DaybookRange range(List<Quest> quests, {DateTime? now}) =>
        DaybookRangeProjection.build(
          schedule: AcademicSchedule.empty(),
          quests: quests,
          first: CivilDate(2026, 10, 10),
          last: CivilDate(2026, 10, 20),
          now: now ?? _monday,
        );

    test('on another day\'s row it reads done, and only there', () {
      final quest = _quest(
        'Do 5 push-ups',
        chosenFor: '2026-10-11',
        doneOn: '2026-10-12',
      );
      final sunday = range([quest]).dayOn(CivilDate(2026, 10, 11));
      final row = sunday.entries.single;
      // Not done on Sunday, which is the day's own truth ...
      expect(row.completed, isFalse);
      expect(sunday.summary.focusCount, 1);
      // ... but done today, so the ring has nothing left to do.
      expect(row.completedNow, isTrue);
      expect(row.completedToday, isTrue);
    });

    test('on today\'s own row the day\'s own answer is the answer', () {
      final quest = _quest(
        'Do 5 push-ups',
        chosenFor: '2026-10-12',
        doneOn: '2026-10-12',
      );
      final row = range([quest]).dayOn(CivilDate(2026, 10, 12)).entries.single;
      expect(row.completed, isTrue);
      expect(row.completedNow, isFalse);
      expect(row.completedToday, isFalse);
    });

    test('a Quest not finished is open on every day', () {
      final quest = _quest('Do 5 push-ups', chosenFor: '2026-10-13');
      final row = range([quest]).dayOn(CivilDate(2026, 10, 13)).entries.single;
      expect(row.completed, isFalse);
      expect(row.completedNow, isFalse);
      expect(row.completedToday, isFalse);
    });

    test('tomorrow\'s choice is still tomorrow\'s after it is done today', () {
      final quest = _quest(
        'Do 5 push-ups',
        chosenFor: '2026-10-13',
        doneOn: '2026-10-12',
      );
      final tomorrow = range([quest]).dayOn(CivilDate(2026, 10, 13));
      expect(tomorrow.summary.focusCount, 1);
      expect(tomorrow.entries.single.completedToday, isTrue);
    });

    test('a weekly Quest done earlier this week is done, but not "today"', () {
      final quest = _quest(
        'Long call',
        chosenFor: '2026-10-19',
        schedule: QuestSchedule.weekly,
        doneOn: '2026-10-12',
      );
      final row = range(
        [quest],
        now: DateTime(2026, 10, 14, 9),
      ).dayOn(CivilDate(2026, 10, 19)).entries.single;
      expect(row.completed, isFalse, reason: 'next week\'s own answer');
      expect(row.completedNow, isTrue);
      expect(row.completedToday, isFalse);
    });
  });

  group('a Quest\'s ring finishes it through the Quests page', () {
    testWidgets(
      'on today\'s page: reward, XP, history, and the row done at once',
      (tester) async {
        final quest = _quest('Do 5 push-ups', chosenFor: '2026-10-12');
        final rig = await _pump(tester, quests: [quest], date: '2026-10-12');

        expect(find.text('TODAY’S FOCUS'), findsOneWidget);
        expect(find.text('CHOSEN FOR TODAY'), findsOneWidget);
        expect(tester.getSize(_ring('Do 5 push-ups')), const Size(44, 44));
        expect(_ringDone(tester, 'Do 5 push-ups'), isFalse);
        final xp = rig.state.totalXp;

        await tester.tap(_ring('Do 5 push-ups'));
        await tester.pump();

        // The same path, so the same moment: the reward leaves the ring for the
        // XP, and the Quest is finished and shown finished at once.
        expect(rig.handedOver, [same(quest)]);
        final stitch = tester.widget<QuestCompletionStitch>(
          find.byType(QuestCompletionStitch),
        );
        expect(
          stitch.origin.dx,
          closeTo(tester.getCenter(_ring('Do 5 push-ups')).dx, 1),
        );
        expect(
          stitch.origin.dy,
          closeTo(tester.getCenter(_ring('Do 5 push-ups')).dy, 1),
        );
        expect(quest.doneFor(_monday), isTrue);
        expect(_ringDone(tester, 'Do 5 push-ups'), isTrue);
        // On its own day's page the row keeps saying what it was chosen for.
        expect(find.text('CHOSEN FOR TODAY'), findsOneWidget);
        expect(find.text('DONE TODAY'), findsNothing);

        await tester.pump(const Duration(milliseconds: 600));
        expect(rig.state.totalXp, greaterThan(xp));
        expect(rig.state.history['2026-10-12'], 1);
        expect(rig.persisted, 1);
        await _settle(tester);
      },
    );

    testWidgets('the sound and the haptic are the Quests page\'s, once', (
      tester,
    ) async {
      final quest = _quest('Do 5 push-ups', chosenFor: '2026-10-12');
      final sounds = <String>[];
      final haptics = <String>[];
      final sfx = Sfx.instance;
      sfx.debugResetForTesting();
      sfx.debugBypassPlayback = true;
      sfx.debugOnPlay = sounds.add;
      addTearDown(sfx.debugResetForTesting);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pump(tester, quests: [quest], date: '2026-10-12');

      await tester.tap(_ring('Do 5 push-ups'));
      await tester.pump();

      // One completion voice, and the completion's own haptic. The card adds
      // no selection click of its own on top.
      expect(sounds.where((s) => s == 'complete'), hasLength(1));
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      await _settle(tester);
    });

    testWidgets('on another day\'s page it counts today, and says so', (
      tester,
    ) async {
      final quests = [
        _quest('Clear the sink', chosenFor: '2026-10-11'),
        _quest('Do 5 push-ups', chosenFor: '2026-10-11'),
        _quest('Morning skincare', chosenFor: '2026-10-11'),
      ];
      final rig = await _pump(tester, quests: quests, date: '2026-10-11');

      // Sunday, seen on Monday: the heading and the cards name Sunday.
      expect(find.text('FOCUS'), findsOneWidget);
      expect(find.text('TODAY’S FOCUS'), findsNothing);
      expect(find.text('CHOSEN FOR SUN'), findsNWidgets(3));
      expect(find.text('CHOSEN FOR TODAY'), findsNothing);
      expect(tester.getSize(_ring('Do 5 push-ups')), const Size(44, 44));
      final xp = rig.state.totalXp;

      await tester.tap(_ring('Do 5 push-ups'));
      await tester.pump();

      // It is finished now, and it is finished today.
      expect(quests[1].lastDoneDay, '2026-10-12');
      expect(_ringDone(tester, 'Do 5 push-ups'), isTrue);
      expect(find.text('DONE TODAY'), findsOneWidget);
      expect(find.text('CHOSEN FOR SUN'), findsNWidgets(2));
      await tester.pump(const Duration(milliseconds: 600));
      expect(rig.state.totalXp, greaterThan(xp));
      expect(rig.state.history['2026-10-12'], 1);
      expect(rig.state.history['2026-10-11'], isNull);
      await _settle(tester);
    });

    testWidgets(
      'on tomorrow\'s page it counts today, and tomorrow\'s plan stays',
      (tester) async {
        final quest = _quest('Do 5 push-ups', chosenFor: '2026-10-13');
        final rig = await _pump(tester, quests: [quest], date: '2026-10-13');
        expect(find.text('CHOSEN FOR TOMORROW'), findsOneWidget);

        await tester.tap(_ring('Do 5 push-ups'));
        await tester.pump(const Duration(milliseconds: 600));

        expect(quest.lastDoneDay, '2026-10-12');
        expect(find.text('DONE TODAY'), findsOneWidget);
        expect(rig.state.history['2026-10-12'], 1);
        // Tomorrow's page still counts what was chosen for it.
        expect(find.text('1 focus'), findsOneWidget);
        await _settle(tester);
      },
    );

    testWidgets('a Quest already done today has nothing left to tap', (
      tester,
    ) async {
      final quest = _quest(
        'Do 5 push-ups',
        chosenFor: '2026-10-11',
        doneOn: '2026-10-12',
      );
      final rig = await _pump(tester, quests: [quest], date: '2026-10-11');

      expect(find.text('DONE TODAY'), findsOneWidget);
      expect(_ringDone(tester, 'Do 5 push-ups'), isTrue);
      final handle = tester.ensureSemantics();
      final node = tester.getSemantics(_ring('Do 5 push-ups'));
      expect(node.label, 'Do 5 push-ups complete');
      expect(
        node.getSemanticsData().flagsCollection.isEnabled,
        Tristate.isFalse,
      );
      handle.dispose();

      await tester.tap(_ring('Do 5 push-ups'));
      await tester.pump();
      expect(rig.handedOver, isEmpty);
      expect(rig.state.totalXp, 0);
    });

    testWidgets(
      'a weekly Quest done earlier this week reads DONE on next week\'s page',
      (tester) async {
        final quest = _quest(
          'Long call',
          chosenFor: '2026-10-19',
          schedule: QuestSchedule.weekly,
          doneOn: '2026-10-12',
        );
        final rig = await _pump(
          tester,
          quests: [quest],
          now: DateTime(2026, 10, 14, 9),
          date: '2026-10-19',
        );

        // Done for the week it is, which is not "today": the card says DONE.
        expect(find.text('DONE'), findsOneWidget);
        expect(find.text('DONE TODAY'), findsNothing);
        expect(_ringDone(tester, 'Long call'), isTrue);
        await tester.tap(_ring('Long call'));
        await tester.pump();
        expect(rig.handedOver, isEmpty);
      },
    );

    testWidgets('a Quest finished on its own day reads done on that day', (
      tester,
    ) async {
      final quest = _quest(
        'Do 5 push-ups',
        chosenFor: '2026-10-11',
        doneOn: '2026-10-11',
      );
      final rig = await _pump(tester, quests: [quest], date: '2026-10-11');

      expect(_ringDone(tester, 'Do 5 push-ups'), isTrue);
      expect(find.text('CHOSEN FOR SUN'), findsOneWidget);
      expect(find.text('DONE TODAY'), findsNothing);
      await tester.tap(_ring('Do 5 push-ups'));
      await tester.pump();
      expect(rig.handedOver, isEmpty);
    });

    testWidgets(
      'VoiceOver: "Complete <quest>", on any day, and what it counts for',
      (tester) async {
        final today = _quest('Do 5 push-ups', chosenFor: '2026-10-12');
        final sunday = _quest('Clear the sink', chosenFor: '2026-10-11');
        final handle = tester.ensureSemantics();

        await _pump(tester, quests: [today, sunday], date: '2026-10-12');
        var node = tester.getSemantics(_ring('Do 5 push-ups'));
        expect(node.label, 'Complete Do 5 push-ups');
        expect(node.hint, isEmpty, reason: 'today: nothing more to say');
        expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
        expect(
          find.bySemanticsLabel('Do 5 push-ups, today’s focus'),
          findsOneWidget,
        );

        // Another page of the same book: Sunday, with the hint.
        await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        node = tester.getSemantics(_ring('Clear the sink'));
        expect(node.label, 'Complete Clear the sink');
        expect(node.hint, 'Counts as done today');
        expect(
          find.bySemanticsLabel('Clear the sink, chosen for Sunday'),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets(
      'the undo is the Quests page\'s, armed by a finish from Plans',
      (tester) async {
        // Today's three, as the Quests room holds them.
        final quests = [
          _quest('Do 5 push-ups', chosenFor: '2026-10-12'),
          _quest('Clear the sink', chosenFor: '2026-10-12'),
          _quest('Morning skincare', chosenFor: '2026-10-12'),
        ];
        final rig = await _pump(tester, quests: quests, date: '2026-10-12');

        await tester.tap(_ring('Do 5 push-ups'));
        await tester.pump(const Duration(milliseconds: 700));
        expect(quests[0].doneFor(_monday), isTrue);

        // On the Quests page the same completion offers its undo.
        rig.showPlans.value = false;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 3200));
        final undo = find.byKey(const Key('quest-day-undo'));
        expect(undo, findsOneWidget);
        await tester.tap(undo);
        await tester.pump(const Duration(milliseconds: 200));
        expect(rig.restored, ['snapshot-before']);

        // Back on Plans the Quest is open again.
        rig.showPlans.value = true;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(quests[0].doneFor(_monday), isFalse);
        expect(_ringDone(tester, 'Do 5 push-ups'), isFalse);
        await _settle(tester);
      },
    );

    testWidgets('a Quest that is done by writing opens its page, not a tick', (
      tester,
    ) async {
      final quest = _quest(
        'Write it down',
        chosenFor: '2026-10-12',
        prompt: const JournalQuestPrompt(starter: 'Today I:\n'),
      );
      final rig = await _pump(tester, quests: [quest], date: '2026-10-12');

      await tester.tap(_ring('Write it down'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The Quests page's own rule: looking at the prompt earns nothing.
      expect(find.byType(JournalEntryScreen), findsOneWidget);
      expect(quest.doneFor(_monday), isFalse);
      expect(rig.state.totalXp, 0);
      await tester.tap(
        find.descendant(
          of: find.byType(JournalEntryScreen),
          matching: find.byIcon(Icons.chevron_left),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('a Quest without the Quests page behind it is a quiet ring', (
      tester,
    ) async {
      final quest = _quest('Do 5 push-ups', chosenFor: '2026-10-12');
      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
      });
      Clock.freeze(_monday);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarPage(
              state: GameState()..reduceMotion = true,
              quests: [quest],
              onAdd: (_) => true,
              scheduleRepository: InMemoryAcademicScheduleRepository(),
              calendarPreferences: InMemoryAcademicCalendarPreferences(
                state: const AcademicCalendarViewState(
                  mode: AcademicCalendarMode.day,
                  selectedDate: '2026-10-12',
                ),
              ),
              notebookHandoff: _Handoff(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(_ring('Do 5 push-ups'));
      await tester.pump();
      expect(quest.doneFor(_monday), isFalse);
    });
  });

  group('the receipt says where the undo is', () {
    Future<void> pumpReceipt(
      WidgetTester tester, {
      required bool onBoard,
    }) async {
      final state = GameState(rng: _NoLuck())..reduceMotion = true;
      final bundle = state.roll(
        Quest(title: 'Do 5 push-ups', stat: Stat.foc, difficulty: 2),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                RewardReceipt(
                  bundle: bundle,
                  anchor: const Offset(100, 100),
                  state: state,
                  undoOnBoard: onBoard,
                  onDone: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('with the board on screen: swipe the card', (tester) async {
      await pumpReceipt(tester, onBoard: true);
      expect(find.text('SWIPE TO UNDO'), findsOneWidget);
      expect(find.text('UNDO IN QUESTS'), findsNothing);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('finished from another room: where the undo is', (
      tester,
    ) async {
      await pumpReceipt(tester, onBoard: false);
      expect(find.text('UNDO IN QUESTS'), findsOneWidget);
      expect(find.text('SWIPE TO UNDO'), findsNothing);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  group('the week reads it the same way', () {
    testWidgets('a Quest finished today is struck on Sunday\'s ticket', (
      tester,
    ) async {
      final done = _quest(
        'Do 5 push-ups',
        chosenFor: '2026-10-11',
        doneOn: '2026-10-12',
      );
      final open = _quest('Clear the sink', chosenFor: '2026-10-11');
      await _pump(
        tester,
        quests: [done, open],
        date: '2026-10-11',
        mode: AcademicCalendarMode.week,
      );

      TextDecoration? struck(String name) =>
          tester.widget<Text>(find.text(name)).style!.decoration;
      expect(struck('Do 5 push-ups'), TextDecoration.lineThrough);
      expect(struck('Clear the sink'), isNull);
    });
  });

  group('a new day opens Plans on today', () {
    const modeKey = 'room_of_days_academic_calendar_mode_v1';
    const dateKey = 'room_of_days_academic_calendar_date_v1';
    const threeKey = 'room_of_days_academic_calendar_three_day_start_v1';
    const savedOnKey = 'room_of_days_academic_calendar_saved_on_v1';

    test('what Plans saves: the view for good, the day for that day', () async {
      final preferences = LocalAcademicCalendarPreferences();
      Clock.freeze(_sunday);
      await preferences.save(
        const AcademicCalendarViewState(
          mode: AcademicCalendarMode.week,
          selectedDate: '2026-10-11',
          threeDayStartDate: '2026-10-10',
        ),
      );

      // Later the same day, all of it comes back.
      var loaded = await preferences.load();
      expect(loaded.mode, AcademicCalendarMode.week);
      expect(loaded.selectedDate, '2026-10-11');
      expect(loaded.threeDayStartDate, '2026-10-10');

      // The next morning only the view does.
      Clock.freeze(_monday);
      loaded = await preferences.load();
      expect(loaded.mode, AcademicCalendarMode.week);
      expect(loaded.selectedDate, isNull);
      expect(loaded.threeDayStartDate, isNull);
    });

    test(
      'a save from before the day was stamped reads as an earlier day',
      () async {
        SharedPreferences.setMockInitialValues({
          modeKey: 'month',
          dateKey: '2026-10-11',
          threeKey: '2026-10-11',
        });
        Clock.freeze(_monday);
        final loaded = await LocalAcademicCalendarPreferences().load();
        expect(loaded.mode, AcademicCalendarMode.month);
        expect(loaded.selectedDate, isNull);
        expect(loaded.threeDayStartDate, isNull);
      },
    );

    testWidgets('a Sunday saved on Sunday does not greet Monday', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        modeKey: 'day',
        dateKey: '2026-10-11',
        savedOnKey: '2026-10-11',
      });
      await _pump(
        tester,
        quests: [_quest('Do 5 push-ups', chosenFor: '2026-10-11')],
        preferences: LocalAcademicCalendarPreferences(),
      );

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('MON · OCT 12'), findsOneWidget);
      expect(_back, findsNothing);
      expect(find.text('Sunday'), findsNothing);
    });

    testWidgets('the view it was left in stays: WEEK is still WEEK', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        modeKey: 'week',
        dateKey: '2026-10-07',
        savedOnKey: '2026-10-07',
      });
      await _pump(
        tester,
        quests: const [],
        preferences: LocalAcademicCalendarPreferences(),
      );

      expect(find.byKey(const ValueKey('academic-week-view')), findsOneWidget);
      expect(find.byKey(const ValueKey('academic-day-view')), findsNothing);
      // The week is this one, and today is in it.
      expect(_back, findsNothing);
    });

    testWidgets('a page chosen earlier the same day is still the page', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        modeKey: 'day',
        dateKey: '2026-10-14',
        savedOnKey: '2026-10-12',
      });
      await _pump(
        tester,
        quests: const [],
        preferences: LocalAcademicCalendarPreferences(),
      );

      expect(find.text('WED · OCT 14'), findsOneWidget);
      expect(_back, findsOneWidget);
    });

    testWidgets(
      'a book left on Sunday turns to Monday when the phone is picked up',
      (tester) async {
        await _pump(
          tester,
          quests: [_quest('Do 5 push-ups', chosenFor: '2026-10-11')],
          now: _sunday,
          date: '2026-10-11',
        );
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('SUN · OCT 11'), findsOneWidget);

        Clock.freeze(_monday);
        await _reopen(tester);

        expect(find.text('MON · OCT 12'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
        expect(_back, findsNothing);
      },
    );

    testWidgets('left in WEEK, it is still WEEK on the new day', (
      tester,
    ) async {
      await _pump(
        tester,
        quests: const [],
        now: _sunday,
        date: '2026-10-11',
        mode: AcademicCalendarMode.week,
      );
      expect(find.byKey(const ValueKey('academic-week-view')), findsOneWidget);

      Clock.freeze(_monday);
      await _reopen(tester);

      expect(find.byKey(const ValueKey('academic-week-view')), findsOneWidget);
      // Monday's week: the week of the 12th, with today in it.
      expect(_back, findsNothing);
    });

    testWidgets('coming back to the Plans tab on a new day does the same', (
      tester,
    ) async {
      final rig = await _pump(
        tester,
        quests: const [],
        now: _sunday,
        date: '2026-10-11',
      );
      expect(find.text('SUN · OCT 11'), findsOneWidget);

      // The dock turns to another room, the night passes, the dock turns back.
      rig.showPlans.value = false;
      await tester.pump();
      Clock.freeze(_monday);
      rig.showPlans.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('MON · OCT 12'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('a page browsed to today stays through the same day', (
      tester,
    ) async {
      final rig = await _pump(tester, quests: const [], date: '2026-10-12');
      await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('TUE · OCT 13'), findsOneWidget);

      await _reopen(tester);
      rig.showPlans.value = false;
      await tester.pump();
      rig.showPlans.value = true;
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('TUE · OCT 13'), findsOneWidget);
    });

    testWidgets('a page chosen after midnight is not undone by the next look', (
      tester,
    ) async {
      await _pump(tester, quests: const [], now: _sunday, date: '2026-10-11');
      // Midnight passes with the book still open; then a day is chosen.
      Clock.freeze(_monday);
      await tester.tap(
        find.byKey(const ValueKey('daybook-day-control-2026-10-10')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('SAT · OCT 10'), findsOneWidget);

      await _reopen(tester);

      expect(find.text('SAT · OCT 10'), findsOneWidget);
    });
  });

  group('BACK TO TODAY', () {
    // The day plate's page ends near 683 in the 393 x 852 canvas (measured from
    // the plate); the phone here is 393 wide, so a point is a point.
    const pageEdge = 683.0;

    Future<void> onSunday(
      WidgetTester tester, {
      double textScale = 1,
      Size size = const Size(393, 852),
    }) => _pump(
      tester,
      quests: [_quest('Do 5 push-ups', chosenFor: '2026-10-11')],
      date: '2026-10-11',
      textScale: textScale,
      size: size,
    );

    testWidgets('sits whole on the page, 44 pt, clear of its lower edge', (
      tester,
    ) async {
      await onSunday(tester);

      final target = tester.getRect(_back);
      expect(target.height, greaterThanOrEqualTo(44));
      expect(target.width, greaterThanOrEqualTo(44));
      expect(target.top, greaterThan(PlansCanvas.tabs.bottom));
      expect(target.bottom, lessThanOrEqualTo(pageEdge - 2));
      final pill = tester.getRect(
        find.descendant(of: _back, matching: find.byType(DecoratedBox)).first,
      );
      expect(pill.height, closeTo(30, 1));
      expect(pill.bottom, lessThanOrEqualTo(pageEdge - 8));
      // And it is on the left page, not over the gutter.
      expect(pill.left, greaterThanOrEqualTo(0));
      expect(pill.right, lessThanOrEqualTo(PlansCanvas.leftFoot.right));
      expect(tester.takeException(), isNull);
    });

    testWidgets('is cream on a dark pill, legible on any shade of the paper', (
      tester,
    ) async {
      await onSunday(tester);

      final pill = tester.widget<DecoratedBox>(
        find.descendant(of: _back, matching: find.byType(DecoratedBox)).first,
      );
      final fill = (pill.decoration as BoxDecoration).color!;
      final word = tester.widget<Text>(
        find.descendant(of: _back, matching: find.text('BACK TO TODAY')),
      );
      // The darkest paper under it is the shaded edge near the spine (measured
      // (110, 89, 68) on the phone); a pill that reads there reads anywhere.
      const darkestPaper = Color(0xFF6E5944);
      final under = Color.alphaBlend(fill, darkestPaper);
      double luminance(Color c) => c.computeLuminance();
      double contrast(Color a, Color b) {
        final hi = math.max(luminance(a), luminance(b));
        final lo = math.min(luminance(a), luminance(b));
        return (hi + 0.05) / (lo + 0.05);
      }

      expect(contrast(word.style!.color!, under), greaterThan(7));
      expect(word.style!.fontSize, greaterThanOrEqualTo(Type.minLabel));
    });

    testWidgets('a tap anywhere in its 44 pt target goes back to today', (
      tester,
    ) async {
      await onSunday(tester);
      final target = tester.getRect(_back);

      // The lower margin of the target, below the pill.
      await tester.tapAt(target.bottomLeft + const Offset(10, -3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Today'), findsOneWidget);
      expect(_back, findsNothing);
    });

    testWidgets('a press under the term\'s words is still a press on it', (
      tester,
    ) async {
      await onSunday(tester);
      final target = tester.getRect(_back);
      final words = tester.getRect(find.text('LOCAL TIME'));
      // The term and the clock ride up over the target's lower margin; a press
      // at the foot of the target, right under those words, is the way back's.
      final x = words.left + 8;
      final y = target.bottom - 2;
      expect(words.top, lessThan(y), reason: 'the words are over that spot');

      await tester.tapAt(Offset(x, y));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Today'), findsOneWidget);
      expect(_back, findsNothing);
    });

    testWidgets('has a name for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await onSunday(tester);
      final node = tester.getSemantics(_back);
      expect(node.label, 'Back to today');
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    for (final scale in const [1.3, 2.0]) {
      testWidgets('at ${(scale * 100).round()}% text it comes first, whole', (
        tester,
      ) async {
        await onSunday(tester, textScale: scale);

        final target = tester.getRect(_back);
        final arrows = tester.getRect(find.byType(PlansArrow).first);
        // Straight under the arrows, before the term and the clock that scroll.
        expect(target.top, closeTo(arrows.bottom, 1));
        expect(target.height, greaterThanOrEqualTo(44));
        expect(target.bottom, lessThanOrEqualTo(pageEdge - 2));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'in the week it has the short foot to itself, until today is in view',
      (tester) async {
        await _pump(
          tester,
          quests: const [],
          date: '2026-10-11',
          mode: AcademicCalendarMode.week,
        );
        // Last week: the way back, and no clock line cut through under it.
        expect(_back, findsOneWidget);
        expect(tester.getRect(_back).height, greaterThanOrEqualTo(44));
        expect(find.text('LOCAL TIME'), findsNothing);

        await tester.tap(_back);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        // This week: nothing to go back to, and the clock line is there.
        expect(_back, findsNothing);
        expect(find.text('LOCAL TIME'), findsOneWidget);
      },
    );

    testWidgets('on the 320 x 568 phone it is still on the page', (
      tester,
    ) async {
      await onSunday(tester, size: const Size(320, 568));

      final target = tester.getRect(_back);
      expect(target.height, greaterThanOrEqualTo(44));
      expect(target.right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });
  });
}
