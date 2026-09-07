import 'package:emberkeep/models.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/quest_companion_copy.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/quest_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() => Clock.freeze(DateTime(2026, 8, 19, 14)));
  tearDown(Clock.reset);

  testWidgets(
    'an unpressed reduced-motion card disposes before and after motion toggles',
    (tester) async {
      final show = ValueNotifier(true);
      final reduceMotion = ValueNotifier(true);
      addTearDown(show.dispose);
      addTearDown(reduceMotion.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: show,
              builder: (context, visible, _) => visible
                  ? ValueListenableBuilder<bool>(
                      valueListenable: reduceMotion,
                      builder: (context, still, _) => QuestCard(
                        quest: Quest(
                          title: 'Put one book away',
                          stat: Stat.dis,
                          difficulty: 2,
                        ),
                        done: false,
                        reduceMotion: still,
                        xpPreview: 10,
                        onComplete: (_) {},
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();

      show.value = false;
      await tester.pump();
      expect(tester.takeException(), isNull);
      show.value = true;
      await tester.pump();

      reduceMotion.value = false;
      await tester.pump();
      reduceMotion.value = true;
      await tester.pump();
      show.value = false;
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('only the featured quest ring follows live light', (
    tester,
  ) async {
    final light = ValueNotifier(Offset.zero);
    final scroll = ValueNotifier(0.0);
    addTearDown(light.dispose);
    addTearDown(scroll.dispose);

    Widget card({required bool featured}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 390,
            child: QuestCard(
              quest: Quest(
                title: 'A quiet piece of work',
                stat: Stat.foc,
                difficulty: 3,
              ),
              done: false,
              featured: featured,
              xpPreview: 26,
              lightDirection: light,
              scrollPosition: scroll,
              onComplete: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(card(featured: false));
    await tester.pump();
    final ring = find.byKey(const ValueKey('quest-check-draw'));
    final parked = tester.widget<CustomPaint>(ring).painter;
    light.value = const Offset(0.8, -0.4);
    scroll.value = 180;
    await tester.pump();
    expect(tester.widget<CustomPaint>(ring).painter, same(parked));

    await tester.pumpWidget(card(featured: true));
    await tester.pump();
    final live = tester.widget<CustomPaint>(ring).painter;
    light.value = const Offset(-0.7, 0.3);
    await tester.pump();
    expect(tester.widget<CustomPaint>(ring).painter, isNot(same(live)));
  });

  testWidgets('completion resolves in place before the card banks', (
    tester,
  ) async {
    final done = ValueNotifier(false);
    addTearDown(done.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              child: ValueListenableBuilder<bool>(
                valueListenable: done,
                builder: (context, isDone, _) => QuestCard(
                  key: const ValueKey('settling-quest'),
                  quest: Quest(
                    title: 'Read ten pages',
                    stat: Stat.intl,
                    difficulty: 3,
                    priority: true,
                  ),
                  done: isDone,
                  featured: !isDone,
                  xpPreview: 26,
                  onComplete: (_) => done.value = true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('quest-primary-action')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('QUEST COMPLETE'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('QUEST COMPLETE'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'long completed names remain readable on a narrow large-text phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      const title = 'Finish the unusually long and detailed visual polish pass';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: QuestCard(
                quest: Quest(title: title, stat: Stat.foc, difficulty: 5),
                done: true,
                featured: false,
                xpPreview: 41,
                onComplete: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(title), findsOneWidget);
      expect(find.text('+41 XP'), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'featured Quest shows a muted generated companion when eligible',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 290,
                child: QuestCard(
                  quest: Quest(
                    title: 'Clear one surface',
                    stat: Stat.dis,
                    difficulty: 2,
                  ),
                  done: false,
                  featured: true,
                  xpPreview: 10,
                  onComplete: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final q = Quest(
        title: 'Clear one surface',
        stat: Stat.dis,
        difficulty: 2,
      );
      expect(
        find.text(questCompanionCopy(quest: q, day: Clock.now())!),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'featured Quest keeps a keeper note above generated companion copy',
    (tester) async {
      final now = Clock.now();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 290,
                child: QuestCard(
                  quest: Quest(
                    title: 'Clear one surface',
                    stat: Stat.dis,
                    difficulty: 2,
                    log: [Note(at: now, text: 'Start with the desk')],
                  ),
                  done: false,
                  featured: true,
                  xpPreview: 10,
                  onComplete: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Start with the desk'), findsOneWidget);
      expect(find.text('One corner is enough to begin.'), findsNothing);
    },
  );

  testWidgets(
    'overdue Quest names its factual open day without a narrow overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() {
        tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: QuestCard(
                quest: Quest(
                  title: 'Clear the desk',
                  stat: Stat.foc,
                  difficulty: 5,
                  schedule: QuestSchedule.once,
                  dueDate: DateTime(2026, 8, 17),
                ),
                done: false,
                featured: true,
                xpPreview: 41,
                onComplete: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('OPEN SINCE MON'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a carried weekly Quest uses neutral open language', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: QuestCard(
                quest: Quest(
                  title: 'Call home',
                  stat: Stat.soc,
                  difficulty: 2,
                  schedule: QuestSchedule.weekly,
                  weekdays: const [DateTime.monday],
                ),
                done: false,
                featured: true,
                xpPreview: 10,
                onComplete: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('OPEN THIS WEEK'), findsOneWidget);
    expect(find.text('STILL THIS WEEK'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timer Quest opens a Ready session instead of claiming proof', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              child: QuestCard(
                quest: Quest(
                  title: 'Sketch one object',
                  stat: Stat.foc,
                  difficulty: 3,
                  verification: Verification.timer,
                  timerMinutes: 10,
                ),
                done: false,
                featured: true,
                xpPreview: 26,
                onComplete: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Open 10-minute session'), findsOneWidget);
    expect(find.textContaining('BEGIN 10M'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('featured long title keeps readable Goal context and Manage', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    var managed = 0;
    const title = 'Finish the unusually detailed visual polish pass';
    const goal = 'Make the room feel deliberate and easy to return to';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: QuestCard(
              quest: Quest(title: title, stat: Stat.foc, difficulty: 5),
              done: false,
              featured: true,
              goalThreadLabel: goal,
              xpPreview: 41,
              onComplete: (_) {},
              onManage: () => managed++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final titleText = tester.widget<Text>(find.text(title));
    final goalText = tester.widget<Text>(find.text(goal));
    expect(titleText.maxLines, 3);
    expect(titleText.style?.fontFamily, 'EBGaramond');
    expect(goalText.maxLines, 2);
    expect(find.text('Manage'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('quest-manage-action'))).height,
      greaterThanOrEqualTo(44),
    );

    await tester.tap(find.byKey(const ValueKey('quest-manage-action')));
    await tester.pump();
    expect(managed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact Quest title wraps and remains directly selectable', (
    tester,
  ) async {
    var selected = 0;
    const title = 'Take a ten-minute walk around the quiet block';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 290,
              child: QuestCard(
                quest: Quest(title: title, stat: Stat.str, difficulty: 2),
                done: false,
                featured: false,
                xpPreview: 10,
                onSelect: () => selected++,
                onComplete: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.widget<Text>(find.text(title)).maxLines, 2);
    await tester.tap(find.text(title));
    await tester.pump();
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });
}
