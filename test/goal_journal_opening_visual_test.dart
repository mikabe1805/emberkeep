import 'dart:io';

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/goal_catalog.dart';
import 'package:emberkeep/goal_planner.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/goal_opening.dart';
import 'package:emberkeep/widgets/goal_primary_button.dart';
import 'package:emberkeep/widgets/goal_steward.dart';
import 'package:emberkeep/widgets/goal_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/golden_platform_policy.dart';

const _verifyExactGoldens = bool.fromEnvironment('VERIFY_EXACT_GOLDENS');

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    final fraunces = FontLoader('Fraunces')
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-Bold.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Fraunces-SemiBold.ttf'));
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Regular.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-Medium.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/Inter-SemiBold.ttf'));
    final mono = FontLoader('JetBrainsMono')
      ..addFont(
        rootBundle.load('assets/google_fonts/JetBrainsMono-SemiBold.ttf'),
      );
    final garamond = FontLoader('EBGaramond')
      ..addFont(rootBundle.load('assets/google_fonts/EBGaramond-Variable.ttf'));
    await Future.wait([
      material.load(),
      fraunces.load(),
      inter.load(),
      mono.load(),
      garamond.load(),
    ]);
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Journal opening gives every room stop a useful job', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 8, 29, 10));
    Sfx.instance.soundEnabled = false;
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      Clock.reset();
      Sfx.instance.soundEnabled = true;
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });

    final idea = goalCatalog.firstWhere(
      (candidate) => candidate.title == 'Keep a journal',
    );
    final templates = idea.quests
        .map((template) => template.build(goalTitle: idea.title))
        .toList(growable: false);
    final plan = GoalPlanner.fromActions(
      title: idea.title,
      stat: idea.stat,
      type: GoalRouteType.routine,
      actions: templates.map((quest) => quest.displayTitle),
      questTemplates: templates,
      now: Clock.now(),
      outcome: idea.title,
      successProof: idea.finishLine,
      obstacleCue: idea.frictionCue,
      fallbackAction: idea.lighterMove,
    );
    final goal = Goal(
      title: idea.title,
      stat: idea.stat,
      kind: GoalKind.become,
      target: 25,
      openingSeen: false,
      plan: plan,
      fallbackCue: plan.obstacleCue,
      fallbackAction: plan.fallbackAction,
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: GoalOpeningScreen(
          goal: goal,
          actionTitle: plan.currentStep!.actionTitle,
          fallbackAction: goal.fallbackAction,
          preparedByApp: true,
          reduceMotion: true,
          onBegin: () {},
        ),
      ),
    );
    await tester.pump();

    final openingContext = tester.element(find.byType(GoalOpeningScreen));
    final failures = <String>[];
    await tester.runAsync(() async {
      for (final asset in <String>[
        goalsRoomContinuousAsset,
        goalsThresholdPlateAsset,
        ...goalStewardAssets,
        goalsWorkshopStewardFallbackAsset,
      ]) {
        await precacheImage(
          AssetImage(asset),
          openingContext,
          onError: (_, _) => failures.add(asset),
        );
      }
    });
    await tester.pump(const Duration(milliseconds: 250));
    expect(failures, isEmpty);

    await runExactGoldenCheck(
      operatingSystem: Platform.operatingSystem,
      explicitlyEnabled: _verifyExactGoldens,
      updatingGoldens: autoUpdateGoldenFiles,
      compare: () => expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/goal_journal_opening_01_desk_430x932.png'),
      ),
    );

    await tester.tap(find.byKey(const Key('goal-opening-show-plan')));
    await tester.pumpAndSettle();
    await runExactGoldenCheck(
      operatingSystem: Platform.operatingSystem,
      explicitlyEnabled: _verifyExactGoldens,
      updatingGoldens: autoUpdateGoldenFiles,
      compare: () => expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goal_journal_opening_02_finish_line_430x932.png',
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('goal-room-wide-continue')));
    await tester.pumpAndSettle();
    await runExactGoldenCheck(
      operatingSystem: Platform.operatingSystem,
      explicitlyEnabled: _verifyExactGoldens,
      updatingGoldens: autoUpdateGoldenFiles,
      compare: () => expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goal_journal_opening_03_resilience_430x932.png',
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('goal-room-arch-step-in')));
    await tester.pumpAndSettle();
    await runExactGoldenCheck(
      operatingSystem: Platform.operatingSystem,
      explicitlyEnabled: _verifyExactGoldens,
      updatingGoldens: autoUpdateGoldenFiles,
      compare: () => expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/goal_journal_opening_04_workshop_430x932.png',
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('every catalog friction cue reaches the threshold intact', (
    tester,
  ) async {
    Clock.freeze(DateTime(2026, 8, 29, 10));
    Sfx.instance.soundEnabled = false;
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      Clock.reset();
      Sfx.instance.soundEnabled = true;
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });

    for (final idea in goalCatalog) {
      final templates = idea.quests
          .map((template) => template.build(goalTitle: idea.title))
          .toList(growable: false);
      final plan = GoalPlanner.fromActions(
        title: idea.title,
        stat: idea.stat,
        type: GoalRouteType.routine,
        actions: templates.map((quest) => quest.displayTitle),
        questTemplates: templates,
        now: Clock.now(),
        outcome: idea.title,
        successProof: idea.finishLine,
        obstacleCue: idea.frictionCue,
        fallbackAction: idea.lighterMove,
      );
      final goal = Goal(
        title: idea.title,
        stat: idea.stat,
        kind: GoalKind.become,
        target: 25,
        openingSeen: false,
        plan: plan,
        fallbackCue: plan.obstacleCue,
        fallbackAction: plan.fallbackAction,
      );

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: GoalOpeningScreen(
            key: ValueKey('catalog-threshold-${idea.title}'),
            goal: goal,
            actionTitle: plan.currentStep!.actionTitle,
            fallbackAction: goal.fallbackAction,
            preparedByApp: true,
            reduceMotion: true,
            onBegin: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('goal-opening-show-plan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('goal-room-wide-continue')));
      await tester.pumpAndSettle();

      final titleFinder = find.byKey(
        const ValueKey('goal-room-arch-action-title'),
      );
      final title = tester.widget<Text>(titleFinder);
      expect(title.data, idea.frictionCue, reason: idea.title);
      final context = tester.element(titleFinder);
      final painter = TextPainter(
        text: TextSpan(text: title.data, style: title.style),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: title.maxLines,
        ellipsis: title.overflow == TextOverflow.ellipsis ? '…' : null,
      )..layout(maxWidth: tester.getSize(titleFinder).width);
      expect(
        painter.didExceedMaxLines,
        isFalse,
        reason: '${idea.title} should not truncate its threshold support',
      );
      expect(tester.takeException(), isNull, reason: idea.title);
    }
  });
}
