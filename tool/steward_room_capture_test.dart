import 'dart:async';

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/screens/goal_workshop.dart';
import 'package:emberkeep/screens/steward_encounter.dart';
import 'package:emberkeep/widgets/goal_world.dart';
import 'package:emberkeep/widgets/steward_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const _capture = bool.fromEnvironment('CAPTURE_GOLDENS');
const _auditGoldens = '../design/audits/2026-08-31/steward-supper/current';

Future<void> _pumpWorkshop(
  WidgetTester tester, {
  required GameState state,
  required Size size,
  required bool disableAnimations,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = Size(size.width * 2, size.height * 2);
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: GoalWorkshopScreen(
        state: state,
        quests: const [],
        onPersist: () {},
        onOpenGoal: (_) async {},
        onBuildRoute: (_) async {},
        onFocusGoal: (_) {},
        onNewGoal: () async {},
      ),
    ),
  );
  await tester.pump();
  unawaited(
    precacheStewardRoom(tester.element(find.byType(GoalWorkshopScreen))),
  );
  await tester.pump(const Duration(milliseconds: 1000));
  await tester.pump();
}

Future<void> _open(WidgetTester tester) async {
  expect(
    find.byKey(const Key('steward-hidden-card')).hitTestable(),
    findsOneWidget,
  );
  await tester.tap(find.byKey(const Key('steward-hidden-card')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
  expect(find.byKey(const Key('steward-encounter')), findsOneWidget);
  expect(find.byType(StewardEncounterScreen), findsOneWidget);
  expect(find.byType(GoalRoomTravelBackdrop), findsNothing);
}

Future<void> _golden(WidgetTester tester, String name) async {
  if (!_capture) return;
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('$_auditGoldens/$name.png'),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await Future.wait([
      (FontLoader('Fraunces')
            ..addFont(rootBundle.load('assets/google_fonts/Fraunces-Bold.ttf'))
            ..addFont(
              rootBundle.load('assets/google_fonts/Fraunces-SemiBold.ttf'),
            ))
          .load(),
      (FontLoader('Inter')
            ..addFont(rootBundle.load('assets/google_fonts/Inter-Regular.ttf'))
            ..addFont(rootBundle.load('assets/google_fonts/Inter-Medium.ttf'))
            ..addFont(rootBundle.load('assets/google_fonts/Inter-SemiBold.ttf'))
            ..addFont(rootBundle.load('assets/google_fonts/Inter-Bold.ttf')))
          .load(),
      (FontLoader('JetBrainsMono')..addFont(
            rootBundle.load('assets/google_fonts/JetBrainsMono-SemiBold.ttf'),
          ))
          .load(),
    ]);
  });
  setUp(() => Sfx.instance.soundEnabled = false);
  tearDown(() => Sfx.instance.soundEnabled = true);

  testWidgets('steward room doorway timing, settled opening, and reverse', (
    tester,
  ) async {
    final state = GameState();
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.binding.setSurfaceSize(null);
    });
    await _pumpWorkshop(
      tester,
      state: state,
      size: const Size(430, 932),
      disableAnimations: false,
    );
    await _open(tester);

    await _golden(tester, 'entrance_0000ms_430x932');
    var elapsed = 0;
    for (final mark in const [90, 180, 300, 480, 720, 900]) {
      await tester.pump(Duration(milliseconds: mark - elapsed));
      elapsed = mark;
      await _golden(tester, 'entrance_${mark}ms_430x932');
    }
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byKey(const Key('steward-dialogue-panel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('steward-text-soup-hello')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('What’s wrong with the soup?'),
      findsOneWidget,
    );
    await _golden(tester, 'opening_settled_430x932');

    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    unawaited(tester.binding.handlePopRoute());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await _golden(tester, 'reverse_0000ms_430x932');
    await tester.pump(const Duration(milliseconds: 220));
    await _golden(tester, 'reverse_220ms_430x932');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('steward-encounter')), findsNothing);
    expect(find.byKey(const Key('goal-workshop-talk')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid system back during arrival preserves goals and quests', (
    tester,
  ) async {
    final state = GameState();
    final beforeGoals = state.goals.map((goal) => goal.toJson()).toList();
    final beforeQuests = <Map<String, dynamic>>[];
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.binding.setSurfaceSize(null);
    });
    await _pumpWorkshop(
      tester,
      state: state,
      size: const Size(430, 932),
      disableAnimations: false,
    );
    await _open(tester);
    await tester.pump(const Duration(milliseconds: 90));
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    unawaited(tester.binding.handlePopRoute());
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byKey(const Key('goal-workshop-talk')), findsOneWidget);
    expect(state.goals.map((goal) => goal.toJson()).toList(), beforeGoals);
    expect(beforeQuests, isEmpty);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('goal-workshop-talk')));
    await tester.pump();
    expect(find.byKey(const Key('steward-encounter')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900));
    expect(
      find.byKey(const ValueKey<String>('steward-text-soup-hello')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final mode in const [
    (name: 'app', app: true, os: false),
    (name: 'os', app: false, os: true),
  ]) {
    testWidgets(
      'reduced motion ${mode.name} uses still fade and reachable choices',
      (tester) async {
        final state = GameState()..reduceMotion = mode.app;
        addTearDown(() {
          tester.view.resetDevicePixelRatio();
          tester.view.resetPhysicalSize();
          tester.binding.setSurfaceSize(null);
        });
        await _pumpWorkshop(
          tester,
          state: state,
          size: const Size(430, 932),
          disableAnimations: mode.os,
        );
        await _open(tester);
        expect(find.byKey(const Key('steward-arrival-still')), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 90));
        expect(
          find.bySemanticsLabel('What’s wrong with the soup?'),
          findsOneWidget,
        );
        expect(find.text('What did you do?'), findsOneWidget);
        expect(
          find.bySemanticsLabel('I’ll let you get back to it.'),
          findsOneWidget,
        );
        expect(
          find.textContaining('The cook has started putting instructions'),
          findsOneWidget,
        );
        await _golden(tester, 'reduced_${mode.name}_430x932');
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final fixture in const [
    (name: 'landscape_932x430', size: Size(932, 430)),
    (name: 'compact_320x568_2x', size: Size(320, 568)),
  ]) {
    testWidgets('${fixture.name} has readable reachable steward choices', (
      tester,
    ) async {
      final state = GameState()..reduceMotion = true;
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
      });
      await _pumpWorkshop(
        tester,
        state: state,
        size: fixture.size,
        disableAnimations: true,
        textScale: fixture.name == 'compact_320x568_2x' ? 2 : 1,
      );
      await _open(tester);
      await tester.pumpAndSettle();
      final choice = find.text('What’s wrong with the soup?');
      expect(choice, findsOneWidget);
      expect(
        find.textContaining('The cook has started', findRichText: true),
        findsOneWidget,
      );
      await _golden(tester, fixture.name);
      expect(tester.takeException(), isNull);
    });
  }
}
