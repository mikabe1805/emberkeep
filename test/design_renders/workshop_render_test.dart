// Renders the Goals door, the Steward's workshop home, the new-goal flow and the
// arrival stage, before and after the 2026-10-09 workshop pass (same frame
// names, one folder per phase). Skipped unless asked for:
//
//   flutter test --dart-define=CLASS_DAY_RENDERS=true \
//     --dart-define=WS_PHASE=before|after \
//     --dart-define=WS_OUT=<absolute folder> \
//     test/design_renders/workshop_render_test.dart
//
// The state is built here (no account): three goals that cover the three
// workshop states, so each frame shows the real copy, not a mock.
import 'dart:io';

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/goal_planner.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/goals.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/lamplight.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('CLASS_DAY_RENDERS');
const _phase = String.fromEnvironment('WS_PHASE', defaultValue: 'after');
const _outOverride = String.fromEnvironment('WS_OUT');
const _only = String.fromEnvironment('WS_ONLY');
bool _wants(String group) =>
    _only.isEmpty || _only.split(',').map((s) => s.trim()).contains(group);

final _now = DateTime(2026, 10, 9, 10, 40);

const _art = <String>[
  ...[
    'assets/pages/goals-desk-v2.webp',
    'assets/pages/goals-living-backdrop-v2.webp',
    'assets/pages/goals-living-backdrop-soft-v2.webp',
    'assets/pages/goals-room-retreat-v1.webp',
    'assets/pages/goals-threshold-room-v1.webp',
    'assets/pages/goals-threshold-plate-flat-v1.png',
    'assets/pages/goals-return-bookcloth-v1.png',
    'assets/pages/working-room-v1.webp',
    'assets/pages/goals-workshop-tavern-back-v2.webp',
    'assets/pages/goals-workshop-tavern-counter-v2.webp',
    'assets/pages/goals-workshop-steward-welcome-v2.webp',
    'assets/pages/goals-workshop-steward-considering-v2.webp',
    'assets/pages/goals-workshop-steward-ready-v2.webp',
    'assets/pages/goals-workshop-steward-acknowledging-v2.webp',
    'assets/pages/goals-workshop-steward-closing-v2.webp',
    'assets/pages/goals-workshop-tavern-steward-v1.webp',
    'assets/pages/steward-supper-room-v2.webp',
    'assets/pages/steward-supper-offering-v2.webp',
    'assets/room/wall_grain.png',
  ],
];

GoalPlan _plan(
  String title,
  Stat stat,
  GoalRouteType type,
  String outcome,
  String start,
  String proof,
  String snag,
) => GoalPlanner.draft(
  GoalPlanInput(
    title: title,
    stat: stat,
    type: type,
    outcome: outcome,
    startingPoint: start,
    successProof: proof,
    timeBudgetMinutes: 15,
    obstacleCue: snag,
    now: _now,
  ),
);

({GameState state, List<Quest> quests}) _withGoals() {
  final state = GameState()..reduceMotion = true;
  final calm = Goal(
    title: 'Make the apartment feel calm',
    stat: Stat.dis,
    target: 4,
    openingSeen: true,
    plan: _plan(
      'Make the apartment feel calm',
      Stat.dis,
      GoalRouteType.reset,
      'I can come home and use the kitchen without feeling overwhelmed',
      'The counter is crowded and I avoid deciding where anything goes',
      'The counter stays usable for a normal week',
      'the whole thing feels too big after class',
    ),
  );
  final books = Goal(
    title: 'Read books that stay with me',
    stat: Stat.intl,
    target: 4,
    openingSeen: false,
    plan: _plan(
      'Read books that stay with me',
      Stat.intl,
      GoalRouteType.routine,
      'I finish a book a month and remember what it said',
      'I start books and drift off them after a few chapters',
      'One finished book with a note on each',
      'I reach for my phone instead',
    ),
  );
  final walk = Goal(title: 'Build a walking habit', stat: Stat.vit, target: 25);
  state.goals.addAll([calm, books, walk]);
  final decision = GoalPlanner.decide(calm, const <Quest>[], _now)!;
  final quests = <Quest>[GoalPlanner.questFor(calm, decision, _now)];
  return (state: state, quests: quests);
}

Future<void> _mount(
  WidgetTester tester,
  GameState state,
  List<Quest> quests, {
  double textScale = 1,
}) async {
  await pumpPhoneStudy(
    tester,
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: GoalsPage(
            state: state,
            quests: quests,
            onAdd: (quest) {
              if (quests.any((item) => item.title == quest.title)) return false;
              quests.add(quest);
              return true;
            },
            onRemoveQuest: quests.remove,
            onRemoveGoal: state.removeGoal,
            onPersist: () {},
            onOpenQuest: (_) {},
          ),
        ),
      ),
    ),
    precache: _art,
    settleFor: const Duration(milliseconds: 1200),
  );
}

Finder _key(String value) => find.byKey(Key(value));

Future<void> _tap(WidgetTester tester, Finder finder, {int ms = 1200}) async {
  if (finder.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(finder.first);
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 400));
  }
  final target = finder.hitTestable().evaluate().isEmpty
      ? finder.first
      : finder.hitTestable().first;
  await tester.tap(target, warnIfMissed: false);
  await tester.pump();
  await settle(tester, total: Duration(milliseconds: ms));
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(_key(key), text);
  await tester.pump();
}

void main() {
  final out = _outOverride.isNotEmpty
      ? _outOverride
      : '${Directory.current.path.replaceAll(r'\', '/')}/design/comparisons/2026-10-09/workshop/$_phase';
  final sheet = FrameSheet(out);

  setUpAll(() async {
    await setUpRoomRenders();
    await LampVellum.load();
  });
  const zoneChannel = MethodChannel('flutter_timezone');
  setUp(() {
    Clock.freeze(_now);
    Sfx.instance.soundEnabled = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(zoneChannel, (call) async {
          return call.method == 'getLocalTimezone' ? 'America/New_York' : null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(zoneChannel, null);
  });
  tearDownAll(() {
    if (_renders) sheet.writeManifest();
    tearDownRoomRenders();
  });

  roomRenderTest(
    'Goals page with goals, then the workshop home and an arrival',
    skip: !_renders || !_wants('goals'),
    (tester) async {
      final data = _withGoals();
      await _mount(tester, data.state, data.quests);
      await sheet.shot(
        tester,
        '01_goals_with_goals',
        at: _now,
        surface: 'Goals page, three goals',
      );
      await _tap(tester, _key('goals-open-workshop'), ms: 1800);
      await sheet.shot(
        tester,
        '03_workshop_home',
        at: _now,
        surface: 'Workshop home, three goals',
      );
      if (_phase == 'after') {
        // The whole home scrolls: the last goal, the new-goal button and the
        // quiet talk link are all reachable below the lead card.
        final list = find.byType(Scrollable).first;
        await tester.drag(list, const Offset(0, -2000));
        await tester.pump();
        await settle(tester, total: const Duration(milliseconds: 900));
        await sheet.shot(
          tester,
          '03c_workshop_home_scrolled',
          at: _now,
          surface: 'Workshop home, scrolled to the end',
        );
        await tester.drag(list, const Offset(0, 2000));
        await tester.pump();
        await settle(tester, total: const Duration(milliseconds: 900));
      }
      // The goal that has a next step ready but not on the board.
      await _tap(
        tester,
        find.byKey(
          const ValueKey<String>(
            'goal-workshop-home-goal-Read books that stay with me',
          ),
        ),
        ms: 2200,
      );
      await sheet.shot(
        tester,
        '05_arrival',
        at: _now,
        surface: 'Arrival stage, next step ready',
      );
    },
  );

  roomRenderTest(
    'Goals page with no goals',
    skip: !_renders || !_wants('empty'),
    (tester) async {
      await _mount(tester, GameState()..reduceMotion = true, <Quest>[]);
      await sheet.shot(
        tester,
        '02_goals_empty',
        at: _now,
        surface: 'Goals page, no goals',
      );
      await _tap(tester, _key('goals-open-workshop'), ms: 1800);
      await sheet.shot(
        tester,
        '03b_workshop_home_empty',
        at: _now,
        surface: 'Workshop home, no goals',
      );
    },
  );

  roomRenderTest('New goal flow', skip: !_renders || !_wants('flow'), (
    tester,
  ) async {
    final data = _withGoals();
    await _mount(tester, data.state, data.quests);
    await _tap(tester, _key('goals-new-goal'), ms: 1600);
    if (_phase == 'before') {
      await sheet.shot(
        tester,
        '04a_new_goal_1_aim',
        at: _now,
        surface: 'New goal, composer step 1',
      );
      await _type(tester, 'quick-goal-name', 'Learn to cook five dinners');
      await _type(
        tester,
        'quick-goal-outcome',
        'I can make dinner without ordering out',
      );
      await tester.pump();
      final type = _key('quick-goal-type-skill');
      await tester.ensureVisible(type);
      await tester.pump();
      await sheet.shot(
        tester,
        '04b_new_goal_1_aim_lower',
        at: _now,
        surface: 'New goal, composer step 1 (lower)',
      );
      await _tap(tester, _key('quick-goal-create'), ms: 900);
      await sheet.shot(
        tester,
        '04c_new_goal_2_reality',
        at: _now,
        surface: 'New goal, composer step 2',
      );
      await _type(
        tester,
        'quick-goal-starting-point',
        'I know two recipes and no staples',
      );
      await _type(tester, 'quick-goal-proof', 'Five different dinners cooked');
      await _type(tester, 'quick-goal-obstacle', 'tired after class');
      await _tap(tester, _key('quick-goal-create'), ms: 2200);
      await sheet.shot(
        tester,
        '04z_new_goal_end',
        at: _now,
        surface: 'New goal, where it lands',
      );
    } else {
      Future<void> frame(String name, String note) => sheet.shot(
        tester,
        name,
        at: _now,
        surface: 'New goal, the Steward asks',
        note: note,
      );
      await frame('04a_new_goal_1_name', 'question 1, name');
      await _type(tester, 'steward-ask-name', 'Learn to cook five dinners');
      await _tap(tester, _key('steward-ask-continue'), ms: 700);
      await frame('04b_new_goal_2_outcome', 'question 2, what is different');
      await _type(
        tester,
        'steward-ask-outcome',
        'I can make dinner without ordering out',
      );
      await _tap(tester, _key('steward-ask-continue'), ms: 700);
      await frame('04c_new_goal_3_kind', 'question 3, kind of goal');
      await _tap(tester, _key('steward-ask-type-skill'), ms: 400);
      await _tap(tester, _key('steward-ask-continue'), ms: 700);
      await frame('04d_new_goal_4_stat', 'question 4, part of life');
      await _tap(tester, _key('steward-ask-stat-vit'), ms: 400);
      await _tap(tester, _key('steward-ask-continue'), ms: 700);
      await frame('04e_new_goal_5_starting', 'question 5, starting point');
      await _type(
        tester,
        'steward-ask-starting-point',
        'I know two recipes and no staples',
      );
      await _tap(tester, _key('steward-ask-continue'), ms: 700);
      await frame('04f_new_goal_6_proof', 'question 6, what shows it worked');
      await _type(tester, 'steward-ask-proof', 'Five different dinners cooked');
      await _tap(tester, _key('steward-ask-continue'), ms: 700);
      await frame('04g_new_goal_7_minutes', 'question 7, time');
      await _tap(tester, _key('steward-ask-minutes-30'), ms: 400);
      await _tap(tester, _key('steward-ask-continue'), ms: 700);
      await frame('04h_new_goal_8_snag', 'question 8, what gets in the way');
      await _type(tester, 'steward-ask-snag', 'tired after class');
      await _tap(tester, _key('steward-ask-continue'), ms: 700);
      await frame('04i_new_goal_9_horizon', 'question 9, optional deadline');
      await _tap(tester, _key('steward-ask-continue'), ms: 2600);
      await sheet.shot(
        tester,
        '04z_new_goal_end',
        at: _now,
        surface: 'New goal, where it lands',
      );
    }
  });

  roomRenderTest(
    'Narrow phone at large text',
    skip: !_renders || !_wants('narrow') || _phase != 'after',
    (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.padding = const FakeViewPadding(top: 20 * 3);
      tester.view.viewPadding = const FakeViewPadding(top: 20 * 3);
      final data = _withGoals();
      await _mount(tester, data.state, data.quests, textScale: 1.5);
      await sheet.shot(
        tester,
        '06a_narrow_goals',
        at: _now,
        surface: 'Goals page, 320 wide at 1.5x text',
      );
      await _tap(tester, _key('goals-open-workshop'), ms: 1800);
      await sheet.shot(
        tester,
        '06b_narrow_workshop_home',
        at: _now,
        surface: 'Workshop home, 320 wide at 1.5x text',
      );
      final list = find.byType(Scrollable).first;
      await tester.drag(list, const Offset(0, -3000));
      await tester.pump();
      await settle(tester, total: const Duration(milliseconds: 900));
      await sheet.shot(
        tester,
        '06c_narrow_workshop_home_end',
        at: _now,
        surface: 'Workshop home scrolled to the end, 320 wide at 1.5x text',
      );
      await tester.drag(list, const Offset(0, 3000));
      await tester.pump();
      await settle(tester, total: const Duration(milliseconds: 900));
      await _tap(
        tester,
        find.byKey(
          const ValueKey<String>(
            'goal-workshop-home-goal-Build a walking habit',
          ),
        ),
        ms: 1200,
      );
      await sheet.shot(
        tester,
        '06d_narrow_intake',
        at: _now,
        surface: 'The Steward asks about a goal with no plan, 320 wide at 1.5x',
      );
      await _tap(tester, _key('goal-workshop-home-back'), ms: 600);
      await _tap(tester, _key('goal-workshop-home-back'), ms: 600);
      await _tap(tester, _key('goals-open-workshop'), ms: 1200);
      await _tap(
        tester,
        find.byKey(
          const ValueKey<String>(
            'goal-workshop-home-goal-Read books that stay with me',
          ),
        ),
        ms: 2200,
      );
      await sheet.shot(
        tester,
        '06e_narrow_arrival',
        at: _now,
        surface: 'Arrival stage, 320 wide at 1.5x text',
      );
      await _tap(tester, _key('goal-workshop-see-plan'), ms: 900);
      await sheet.shot(
        tester,
        '06f_narrow_arrival_plan',
        at: _now,
        surface: 'Arrival stage with the whole plan open, 320 wide at 1.5x',
      );
    },
  );

  roomRenderTest(
    'The Steward asks with the keyboard up',
    skip: !_renders || !_wants('keyboard') || _phase != 'after',
    (tester) async {
      final data = _withGoals();
      await _mount(tester, data.state, data.quests);
      await _tap(tester, _key('goals-new-goal'), ms: 1600);
      await _type(
        tester,
        'steward-ask-name',
        'Learn to cook five dinners without ordering out',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
      await tester.pump();
      await settle(tester, total: const Duration(milliseconds: 600));
      await sheet.shot(
        tester,
        '07a_keyboard_question_1',
        at: _now,
        surface: 'The Steward asks, keyboard up, question 1',
      );
      tester.view.resetViewInsets();
      await tester.pump();
      await _tap(tester, _key('steward-ask-continue'), ms: 700);
      await _type(
        tester,
        'steward-ask-outcome',
        'I can make a real dinner on a weeknight without ordering out, and I enjoy it enough that I want to do it again the next day',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
      await tester.pump();
      await settle(tester, total: const Duration(milliseconds: 600));
      await sheet.shot(
        tester,
        '07b_keyboard_question_2_long',
        at: _now,
        surface: 'The Steward asks, keyboard up, question 2 with a long answer',
      );
      tester.view.resetViewInsets();
    },
  );
}
