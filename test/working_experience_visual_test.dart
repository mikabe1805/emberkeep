// Opt-in render evidence for the working Goals and Quests journey. The fixture
// is an in-memory save-format snapshot; its daily proof and selected ranks are
// deliberate live state, never biography invented for a screenshot.
// flutter test --update-goldens --dart-define=CAPTURE_GOLDENS=true test/working_experience_visual_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/goal_planner.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/goals.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/storage.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/quest_depth_room.dart';
import 'package:emberkeep/widgets/timer_overlay.dart';
import 'package:emberkeep/widgets/top_three_wizard.dart';
import 'package:emberkeep/widgets/working_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _capture = bool.fromEnvironment('CAPTURE_GOLDENS');
const _boundary = Key('working-experience-capture');
final _day = DateTime(2026, 9, 6, 10);

class _WorkingFixture {
  _WorkingFixture()
    : state = GameState()..reduceMotion = true,
      quests = <Quest>[] {
    final plan = GoalPlanner.fromActions(
      title: 'Learn sketching',
      stat: Stat.foc,
      type: GoalRouteType.skill,
      actions: const ['Sketch one object'],
      now: _day,
    );
    final goal = Goal(
      title: 'Learn sketching',
      stat: Stat.foc,
      target: 8,
      openingSeen: true,
      plan: plan,
    );
    state.goals.add(goal);
    final step = plan.currentStep!;
    quests.addAll([
      Quest(
        title: 'Read ten pages',
        stat: Stat.intl,
        difficulty: 3,
        priorityDay: Days.key(_day),
        priorityRank: 1,
      ),
      Quest(
        title: 'Take a walk',
        stat: Stat.vit,
        difficulty: 2,
        verification: Verification.timer,
        timerMinutes: 10,
        priorityDay: Days.key(_day),
        priorityRank: 2,
      ),
      Quest(
        title: 'Sketch one object',
        stat: Stat.foc,
        difficulty: 4,
        verification: Verification.timer,
        timerMinutes: 10,
        goalTitle: goal.title,
        goalPlanStepId: step.id,
        goalPlanRevision: plan.revision,
        goalPlanAttempt: step.completions + 1,
      ),
      Quest(
        title: 'Clear the desk',
        stat: Stat.dis,
        difficulty: 2,
        verification: Verification.timer,
        timerMinutes: 5,
      ),
      Quest(title: 'Message a friend', stat: Stat.soc, difficulty: 2),
    ]);
  }

  final GameState state;
  final List<Quest> quests;
}

Future<void> _precacheWorkingArt(WidgetTester tester) async {
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    for (final asset in [workingRoomAsset, ...QuestDepthRoom.assets]) {
      await precacheImage(AssetImage(asset), context);
    }
  });
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _captureAt(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.devicePixelRatio = 2;
  addTearDown(() {
    tester.binding.setSurfaceSize(null);
    tester.view.resetDevicePixelRatio();
  });
}

Widget _app(Widget child, {required double textScale}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Palette.parchment),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: RepaintBoundary(
    key: _boundary,
    child: Scaffold(body: child),
  ),
);

Future<void> _writeFixture(_WorkingFixture fixture) async {
  if (!_capture) return;
  final output = File('design/audits/2026-09-06/working-preview-fixture.json');
  await output.parent.create(recursive: true);
  await output.writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'app': 'emberkeep',
      'schema': Storage.schema,
      'state': fixture.state.toJson(),
      'quests': [for (final quest in fixture.quests) quest.toJson()],
    }),
  );
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    final garamond = FontLoader('EBGaramond')
      ..addFont(rootBundle.load('assets/google_fonts/EBGaramond-Variable.ttf'));
    final fraunces = FontLoader('Fraunces')
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-Bold.ttf'));
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Regular.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Medium.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-SemiBold.ttf'));
    final mono = FontLoader('JetBrainsMono')
      ..addFont(
        rootBundle.load('assets/google_fonts/JetBrainsMono-SemiBold.ttf'),
      );
    await Future.wait([
      material.load(),
      garamond.load(),
      fraunces.load(),
      inter.load(),
      mono.load(),
    ]);
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Clock.freeze(_day);
    Sfx.instance.soundEnabled = false;
  });
  tearDown(Clock.reset);

  for (final view in [
    ('430x932', const Size(430, 932), 1.0),
    ('320x568', const Size(320, 568), 2.0),
  ]) {
    testWidgets('working Goals ${view.$1}', (tester) async {
      final fixture = _WorkingFixture();
      await _captureAt(tester, view.$2);
      await tester.pumpWidget(
        _app(
          GoalsPage(
            state: fixture.state,
            quests: fixture.quests,
            onAdd: (quest) {
              fixture.quests.add(quest);
              return true;
            },
            onRemoveQuest: fixture.quests.remove,
            onRemoveGoal: fixture.state.removeGoal,
            onPersist: () {},
            onOpenQuest: (_) {},
            onOpenQuests: _noop,
          ),
          textScale: view.$3,
        ),
      );
      await _precacheWorkingArt(tester);
      expect(find.text('Today’s three'), findsOneWidget);
      await tester.runAsync(() => _writeFixture(fixture));
      if (_capture) {
        await expectLater(
          find.byKey(_boundary),
          matchesGoldenFile('goldens/working_goals_${view.$1}.png'),
        );
      }
    });

    testWidgets('working chooser ${view.$1}', (tester) async {
      final fixture = _WorkingFixture();
      await _captureAt(tester, view.$2);
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showTopThreeWizard(
                context,
                title: 'Choose today',
                subtitle: 'Pick up to three quests to carry.',
                dayLabel: 'Today’s field',
                candidates: fixture.quests,
                initialTitles: const ['Read ten pages', 'Take a walk'],
                goals: fixture.state.goals,
                day: _day,
              ),
              child: const Text('Open chooser'),
            ),
          ),
          textScale: view.$3,
        ),
      );
      await _precacheWorkingArt(tester);
      await tester.tap(find.text('Open chooser'));
      await tester.pumpAndSettle();
      expect(find.text('Choose today'), findsOneWidget);
      if (_capture) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/working_chooser_${view.$1}.png'),
        );
      }
    });

    testWidgets('working Quests ${view.$1}', (tester) async {
      final fixture = _WorkingFixture();
      await _captureAt(tester, view.$2);
      await tester.pumpWidget(
        _app(
          QuestsPage(
            state: fixture.state,
            quests: fixture.quests,
            onRefresh: () => 0,
            onPersist: () {},
            onAdd: (quest) {
              fixture.quests.add(quest);
              return true;
            },
            onRemove: fixture.quests.remove,
            onSnapshot: () => '{}',
            onRestore: (_) {},
          ),
          textScale: view.$3,
        ),
      );
      await _precacheWorkingArt(tester);
      expect(find.text('Today’s three'), findsOneWidget);
      if (_capture) {
        await expectLater(
          find.byKey(_boundary),
          matchesGoldenFile('goldens/working_quests_${view.$1}.png'),
        );
        if (view.$3 > 1) {
          final heading = find.text('Today’s three');
          await tester.ensureVisible(heading);
          await tester.pumpAndSettle();
          await expectLater(
            find.byKey(_boundary),
            matchesGoldenFile('goldens/working_quests_field_${view.$1}.png'),
          );
        }
      }
    });

    testWidgets('working timer ${view.$1}', (tester) async {
      await _captureAt(tester, view.$2);
      await tester.pumpWidget(
        _app(
          const TimerOverlay(
            questTitle: 'Sketch one object',
            minutes: 10,
            goalTitle: 'Learn sketching',
            guidance: 'Sketch the whole object from a single viewpoint.',
            onFinished: _noop,
            onHonor: _noop,
            onCancel: _noop,
          ),
          textScale: view.$3,
        ),
      );
      await _precacheWorkingArt(tester);
      expect(find.text('Sketch one object'), findsOneWidget);
      if (_capture) {
        await expectLater(
          find.byKey(_boundary),
          matchesGoldenFile('goldens/working_timer_${view.$1}.png'),
        );
      }
    });
  }

  testWidgets('working chooser selected one filtered to ten minutes', (
    tester,
  ) async {
    final fixture = _WorkingFixture();
    await _captureAt(tester, const Size(430, 932));
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showTopThreeWizard(
              context,
              title: 'Choose today',
              subtitle: 'Pick up to three quests to carry.',
              dayLabel: 'Today’s field',
              candidates: fixture.quests,
              initialTitles: const ['Read ten pages'],
              goals: fixture.state.goals,
              day: _day,
            ),
            child: const Text('Open chooser'),
          ),
        ),
        textScale: 1,
      ),
    );
    await _precacheWorkingArt(tester);
    await tester.tap(find.text('Open chooser'));
    await tester.pumpAndSettle();
    final tenMinutes = find.text('10 min').first;
    await tester.ensureVisible(tenMinutes);
    await tester.tap(tenMinutes);
    await tester.pump();
    expect(find.text('Keep this 1'), findsOneWidget);
    expect(find.text('Your saved 10-minute session'), findsOneWidget);
    if (_capture) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/working_chooser_selected_10m_430x932.png'),
      );
    }
  });
}

void _noop() {}
