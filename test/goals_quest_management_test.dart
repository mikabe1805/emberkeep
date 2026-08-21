import 'package:emberkeep/audio.dart';
import 'package:emberkeep/content/goal_catalog.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/goals.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' show SemanticsAction;

const _capture = bool.fromEnvironment('CAPTURE_GOAL_QUEST_MANAGEMENT');

String _titleKey(String title) => title.trim().toLowerCase();

Finder _takeControl(String title) => find.byKey(
  ValueKey<String>('goal-quest-take-${_titleKey(title)}'),
  skipOffstage: false,
);

Finder _manageControl(String title) => find.byKey(
  ValueKey<String>('goal-quest-manage-${_titleKey(title)}'),
  skipOffstage: false,
);

Finder _semanticsLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);

GoalIdea get _keepYourSpace =>
    goalCatalog.firstWhere((idea) => idea.title == 'Keep your space');

QuestTemplate _template(String title) =>
    _keepYourSpace.quests.firstWhere((template) => template.title == title);

Future<void> _pumpGoals(
  WidgetTester tester, {
  required GameState state,
  required List<Quest> quests,
  required ValueChanged<StateSetter> captureSetState,
  required VoidCallback onPersist,
  Size size = const Size(430, 932),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            captureSetState(setState);
            return GoalsPage(
              state: state,
              quests: quests,
              onAdd: (quest) {
                final key = _titleKey(quest.title);
                if (quests.any((item) => _titleKey(item.title) == key)) {
                  return false;
                }
                setState(() => quests.add(quest));
                onPersist();
                return true;
              },
              onRemoveQuest: (quest) {
                setState(() => quests.remove(quest));
                onPersist();
              },
              onRemoveGoal: (_) {},
              onPersist: onPersist,
              onOpenQuests: () {},
            );
          },
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _openKeepYourSpace(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).first;
  final toggle = find.byKey(
    const ValueKey<String>('goal-catalog-toggle-keep your space'),
    skipOffstage: false,
  );
  await tester.scrollUntilVisible(toggle, 260, scrollable: scrollable);
  await tester.drag(scrollable, const Offset(0, 140));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(toggle);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 650));
  expect(find.text('Make your bed'), findsOneWidget);
}

Future<void> _revealControl(WidgetTester tester, Finder control) async {
  final scrollable = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(control, 180, scrollable: scrollable);
  // The page's cinematic heading occupies the very top edge; give controls
  // enough breathing room that the tap target is not merely clipped at y=0.
  await tester.drag(scrollable, const Offset(0, 140));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() => Sfx.instance.soundEnabled = false);

  tearDown(() => Sfx.instance.soundEnabled = true);

  testWidgets('taken quest can be taken back and selected again', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    state.goals.add(Goal(title: 'My room', stat: Stat.dis, target: 25));
    final quests = <Quest>[];
    var persisted = 0;
    StateSetter? hostSetState;

    await _pumpGoals(
      tester,
      state: state,
      quests: quests,
      captureSetState: (setState) => hostSetState = setState,
      onPersist: () => persisted++,
    );
    expect(hostSetState, isNotNull);
    await _openKeepYourSpace(tester);

    final take = _takeControl('Make your bed');
    await _revealControl(tester, take);
    await tester.tap(take);
    await tester.pump(const Duration(milliseconds: 250));

    expect(quests.map((quest) => quest.title), ['Make your bed']);
    expect(_manageControl('Make your bed'), findsOneWidget);

    await tester.tap(_manageControl('Make your bed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('ON YOUR QUEST BOARD'), findsOneWidget);
    expect(find.text('TAKE BACK'), findsOneWidget);

    await tester.tap(find.byKey(const Key('goal-quest-take-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(quests, isEmpty);
    expect(state.goals.single.title, 'My room');
    expect(_takeControl('Make your bed'), findsOneWidget);

    // Let the optional Undo snackbar clear, then use the catalog itself to
    // start a fresh copy — the exact delete → restore path that regressed.
    await tester.pump(const Duration(seconds: 5));
    await tester.tap(_takeControl('Make your bed'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(quests, hasLength(1));
    expect(quests.single.title, 'Make your bed');
    expect(_manageControl('Make your bed'), findsOneWidget);
    expect(persisted, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('take-back undo restores the same quest and its progress', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    state.goals.add(Goal(title: 'My room', stat: Stat.dis, target: 25));
    final original = _template('Make your bed').build()
      ..lastDoneDay = '2026-08-18'
      ..priority = true;
    final quests = <Quest>[original];

    await _pumpGoals(
      tester,
      state: state,
      quests: quests,
      captureSetState: (_) {},
      onPersist: () {},
    );
    await _openKeepYourSpace(tester);
    await _revealControl(tester, _manageControl('Make your bed'));

    await tester.tap(_manageControl('Make your bed'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal-quest-take-back')));
    await tester.pumpAndSettle();

    expect(quests, isEmpty);
    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();

    expect(quests, hasLength(1));
    expect(identical(quests.single, original), isTrue);
    expect(quests.single.lastDoneDay, '2026-08-18');
    expect(quests.single.priority, isTrue);
  });

  testWidgets('weekly day changes in place without losing quest history', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    state.goals.add(Goal(title: 'My room', stat: Stat.dis, target: 25));
    final weekly = _template('Fresh sheets').build(weekdays: [2])
      ..lastDoneDay = '2026-08-18'
      ..priority = true;
    final quests = <Quest>[weekly];
    var persisted = 0;

    await _pumpGoals(
      tester,
      state: state,
      quests: quests,
      captureSetState: (_) {},
      onPersist: () => persisted++,
    );
    await _openKeepYourSpace(tester);

    final scrollable = find.byType(Scrollable).first;
    // Walk down inside the now-open card. Targeting a descendant of a closed
    // AnimatedCrossFade can make ensureVisible follow its hidden layout copy.
    await tester.drag(scrollable, const Offset(0, -180));
    await tester.pump(const Duration(milliseconds: 100));
    final manage = find.byKey(
      const ValueKey<String>('goal-quest-manage-fresh sheets'),
    );
    expect(manage, findsOneWidget);
    if (_capture) {
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/goals_quest_taken_430x932.png'),
      );
    }
    await tester.tap(find.text('TAKEN · EDIT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('CHANGE WEEKLY DAY'), findsOneWidget);
    expect(find.text('Tuesdays'), findsOneWidget);
    if (_capture) {
      await expectLater(
        find.byType(Overlay).first,
        matchesGoldenFile('goldens/goals_quest_manage_weekly_430x932.png'),
      );
    }
    await tester.tap(find.byKey(const Key('goal-quest-change-day')));
    // The management sheet closes before the day picker opens, so let the
    // second route begin and finish before addressing its controls.
    await tester.pumpAndSettle();
    expect(find.text('WHICH DAY EACH WEEK?'), findsOneWidget);

    await tester.tap(_semanticsLabel('Thursday'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('PIN TO THURSDAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(quests, hasLength(1));
    expect(identical(quests.single, weekly), isTrue);
    expect(weekly.weekdays, [4]);
    expect(weekly.lastDoneDay, '2026-08-18');
    expect(weekly.priority, isTrue);
    expect(Quest.fromJson(weekly.toJson()).weekdays, [4]);
    expect(find.text('THURSDAYS'), findsOneWidget);
    expect(persisted, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('taken matching uses the stable title case-insensitively', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    state.goals.add(Goal(title: 'My room', stat: Stat.dis, target: 25));
    final quests = <Quest>[
      Quest(
        title: 'make YOUR bed',
        stat: Stat.dis,
        difficulty: 1,
        schedule: QuestSchedule.daily,
        verification: Verification.honor,
      ),
    ];

    await _pumpGoals(
      tester,
      state: state,
      quests: quests,
      captureSetState: (_) {},
      onPersist: () {},
    );
    await _openKeepYourSpace(tester);
    await _revealControl(tester, _manageControl('Make your bed'));

    expect(_manageControl('Make your bed'), findsOneWidget);
    expect(_takeControl('Make your bed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quest management stays usable on a narrow large-text phone', (
    tester,
  ) async {
    final state = GameState()..reduceMotion = true;
    state.goals.add(Goal(title: 'My room', stat: Stat.dis, target: 25));
    final quests = <Quest>[
      _template('Fresh sheets').build(weekdays: [2]),
    ];

    await _pumpGoals(
      tester,
      state: state,
      quests: quests,
      captureSetState: (_) {},
      onPersist: () {},
      size: const Size(320, 568),
      textScale: 1.5,
    );
    await _openKeepYourSpace(tester);

    final manage = _manageControl('Fresh sheets');
    await _revealControl(tester, manage);
    await tester.tap(manage);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('CHANGE WEEKLY DAY'), findsOneWidget);
    expect(find.text('TAKE BACK'), findsOneWidget);
    expect(find.text('KEEP IT'), findsOneWidget);
    final keepSemantics = tester.getSemantics(
      _semanticsLabel('Keep Fresh sheets on the quest board'),
    );
    expect(
      keepSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
