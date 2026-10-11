// "SATURDAY, DONE.": the day's card on a day with no classes.
//
// It is the class day's own tier card, planned from the quests: the weekday,
// the quests kept today in the diamond, "QUESTS DONE TODAY" and "The rest of
// today is yours.", held for a tap. It plays once a day, after the last of
// Today's three is kept and the tickets have landed in the bowl, only in the
// Doorway room. It never shows XP the engine did not grant (nothing is paid
// for keeping Today's three), so there is no pill. Closing it leaves the
// room's own "Enough for today".
//
// Instants only (New York wall times converted from UTC).
import 'dart:convert';
import 'dart:math' as math;

import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/day_planning.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/class_day/class_day_model.dart';
import 'package:emberkeep/widgets/class_day/class_kept_celebration.dart';
import 'package:emberkeep/widgets/class_day/doorway_stage.dart';
import 'package:emberkeep/widgets/house/quests/quest_day_card.dart';
import 'package:emberkeep/widgets/levelup_overlay.dart';
import 'package:emberkeep/widgets/reward_receipt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/rutgers_fall_2026_ics_fixture.dart';

DateTime _ny(int day, int hour, int minute) =>
    DateTime.utc(2026, 10, day, hour + 4, minute).toLocal();

/// Saturday 10 October, late morning: no classes.
DateTime get _saturday => _ny(10, 11, 0);

/// Sunday 11 October: no classes either.
DateTime get _sunday => _ny(11, 11, 0);

final AcademicSchedule _fall2026 = AcademicScheduleIcsImporter.parse(
  rutgersFall2026IcsFixture(),
).applyTo(AcademicSchedule.empty(), updatedAt: DateTime.utc(2026, 8, 27));

/// Never a crit, never loot: the ordinary completion, which has no receipt.
class _NoLuck implements math.Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.999;
  @override
  int nextInt(int max) => 0;
}

const _titles = ['Read ten pages', 'Review one problem', 'Write for today'];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    QuestsPage.debugLegacyBoard = false;
    SharedPreferences.setMockInitialValues({});
    GameState.debugRandomFactory = _NoLuck.new;
    Sfx.instance.soundEnabled = false;
  });
  tearDown(() {
    QuestsPage.debugLegacyBoard = true;
    Clock.reset();
    GameState.debugRandomFactory = null;
    Sfx.instance.soundEnabled = true;
  });

  group('the plan', () {
    test('the weekday, the count, the label and the one line', () {
      final state = GameState(rng: _NoLuck());
      final plan = planQuestDay(
        date: CivilDate(2026, 10, 10),
        kept: 3,
        state: state,
      );
      expect(plan.tier, ClassCelebrationTier.dayDone);
      expect(plan.held, isTrue);
      expect(plan.headline, 'SATURDAY, DONE.');
      expect(plan.numeral, 3);
      expect(plan.numeralLabel, 'QUESTS DONE TODAY');
      expect(plan.closing, ['The rest of today is yours.']);
      expect(plan.rows, isEmpty);
      expect(plan.streakLine, isNull);
      expect(plan.autoReturn, isNull, reason: 'held for a tap');
    });

    test('the real weekday name, whatever the day', () {
      final state = GameState(rng: _NoLuck());
      String headline(CivilDate d) =>
          planQuestDay(date: d, kept: 3, state: state).headline;
      expect(headline(CivilDate(2026, 10, 11)), 'SUNDAY, DONE.');
      expect(headline(CivilDate(2026, 10, 9)), 'FRIDAY, DONE.');
      expect(headline(CivilDate(2026, 10, 7)), 'WEDNESDAY, DONE.');
    });

    test('the count is the count, and one quest is "quest"', () {
      final state = GameState(rng: _NoLuck());
      final one = planQuestDay(
        date: CivilDate(2026, 10, 10),
        kept: 1,
        state: state,
      );
      expect(one.numeral, 1);
      expect(one.numeralLabel, 'QUEST DONE TODAY');
      final two = planQuestDay(
        date: CivilDate(2026, 10, 10),
        kept: 2,
        state: state,
      );
      expect(two.numeral, 2);
      expect(two.numeralLabel, 'QUESTS DONE TODAY');
    });

    test('no XP of its own: no row, no rail, and no pill without a bonus', () {
      final state = GameState(rng: _NoLuck());
      final plan = planQuestDay(
        date: CivilDate(2026, 10, 10),
        kept: 3,
        state: state,
      );
      expect(plan.xpRail, isFalse);
      expect(plan.pillXp, 0);
      expect(plan.xpGained, 0);
      expect(plan.gains, isEmpty);
      expect(plan.semanticsLabel, isNot(contains('XP')));
    });

    test('a real bonus is shown at exactly its amount', () {
      final state = GameState(rng: _NoLuck());
      final plan = planQuestDay(
        date: CivilDate(2026, 10, 10),
        kept: 3,
        state: state,
        bonusXp: 12,
      );
      expect(plan.pillXp, 12);
      expect(plan.semanticsLabel, contains('Plus 12 XP.'));
    });

    test(
      'it says it once, as one label, with no fraction and no loss word',
      () {
        final state = GameState(rng: _NoLuck());
        final plan = planQuestDay(
          date: CivilDate(2026, 10, 10),
          kept: 3,
          state: state,
        );
        expect(
          plan.semanticsLabel,
          'Saturday, done. 3 quests done today. The rest of today is yours.',
        );
        final words = [
          plan.headline,
          plan.numeralLabel,
          ...plan.closing,
          plan.semanticsLabel,
        ].join(' ').toLowerCase();
        for (final bad in [
          'failed',
          'missed',
          'lost',
          'broke',
          'behind',
          'overdue',
          String.fromCharCode(0x2014),
          'of three',
        ]) {
          expect(words, isNot(contains(bad)));
        }
        expect(words, isNot(matches(RegExp(r'\d+ of \d+'))));
      },
    );
  });

  group('the card in the room', () {
    late GameState state;
    late List<Quest> quests;
    late void Function(Quest quest, Offset anchor) complete;
    var restores = 0;

    /// Mounts the real QuestsPage on [at] with the first [kept] of Today's
    /// three already kept (nothing is played for those).
    Future<void> mount(
      WidgetTester tester, {
      DateTime? at,
      bool reduceMotion = false,
      double textScale = 1,
      int kept = 0,
      List<String> field = _titles,
      bool gentle = false,
    }) async {
      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
      });
      final now = at ?? _saturday;
      Clock.freeze(now);
      state = GameState(rng: _NoLuck())
        ..onboarded = true
        ..playerName = 'Mika'
        ..level = 18
        ..xp = 284
        ..totalXp = 4280
        ..soundEnabled = false
        ..reduceMotion = reduceMotion
        ..lastActiveDay = Days.key(now);
      if (gentle) state.setEnergyWeather(EnergyWeather.low);
      quests = [
        Quest(title: _titles[0], stat: Stat.intl, difficulty: 4),
        Quest(title: _titles[1], stat: Stat.foc, difficulty: 3),
        Quest(title: _titles[2], stat: Stat.dis, difficulty: 2),
        Quest(title: 'Walk after lunch', stat: Stat.vit, difficulty: 3),
      ];
      applyDailyField(quests, now, field);
      for (final q in quests.take(kept)) {
        q.lastDoneDay = Days.key(now);
      }
      restores = 0;
      ClassDay lookup(DateTime when, {CivilDate? day}) =>
          projectClassDay(_fall2026, when, day: day);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(393, 852),
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reduceMotion,
            ),
            child: StatefulBuilder(
              builder: (context, setHost) => Scaffold(
                body: QuestsPage(
                  state: state,
                  quests: quests,
                  onRefresh: () => 0,
                  onPersist: () {},
                  onAdd: (quest) {
                    quests.add(quest);
                    return true;
                  },
                  onRemove: quests.remove,
                  onSnapshot: () => jsonEncode(state.toJson()),
                  // An undo hands the newest kept quest back: the host does
                  // what the shell's restore does to the board.
                  onRestore: (_) {
                    restores++;
                    for (final q in quests.take(3).toList().reversed) {
                      if (q.lastDoneDay != null) {
                        q.lastDoneDay = null;
                        break;
                      }
                    }
                    setHost(() {});
                  },
                  onBindComplete: (fn) => complete = fn,
                  classDays: lookup,
                  classTerm: _fall2026.termFor,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
    }

    Future<void> pumpFor(WidgetTester tester, int ms) async {
      for (var t = 0; t < ms; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    final bar = find.byKey(const Key('class-there-button'));
    final card = find.byKey(const Key('class-kept-celebration'));
    final headline = find.byKey(const Key('class-celebration-headline'));
    final title = find.byKey(const Key('quest-day-title'));

    /// One MARK COMPLETE, then the scene's own time (a rare beat's receipt
    /// is let go).
    Future<void> keepOne(WidgetTester tester, {int settle = 3300}) async {
      await tester.tap(bar);
      await pumpFor(tester, settle);
      for (var w = 0; w < 30; w++) {
        if (find.byType(RewardReceipt).evaluate().isEmpty) break;
        await pumpFor(tester, 500);
      }
    }

    /// Waits (up to [ms]) for the card to come up.
    Future<void> waitForCard(WidgetTester tester, {int ms = 9000}) async {
      for (var t = 0; t < ms && card.evaluate().isEmpty; t += 100) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> closeCard(WidgetTester tester) async {
      await tester.tapAt(const Offset(196, 420));
      await pumpFor(tester, 700);
    }

    String textOf(WidgetTester tester, Finder finder) =>
        tester.widget<Text>(finder).data ?? '';

    testWidgets('after the third keep, not after two', (tester) async {
      await mount(tester);
      await keepOne(tester);
      await keepOne(tester);
      // Two kept: the scene alone, nothing covers it, however long we wait.
      await pumpFor(tester, 6000);
      expect(card, findsNothing);
      expect(title, findsOneWidget);
      expect(textOf(tester, title), _titles[2]);
      // The third: the tickets drop into the bowl, then the day's card.
      await tester.tap(bar);
      await pumpFor(tester, 1200);
      expect(card, findsNothing, reason: 'the bowl comes first');
      await waitForCard(tester);
      expect(card, findsOneWidget);
    });

    testWidgets('it says the weekday, the count and the one line, no XP', (
      tester,
    ) async {
      await mount(tester);
      for (var i = 0; i < 3; i++) {
        await keepOne(tester, settle: i == 2 ? 100 : 3300);
      }
      await waitForCard(tester);
      await pumpFor(tester, 2600);
      expect(textOf(tester, headline), 'SATURDAY, DONE.');
      expect(
        textOf(tester, find.byKey(const Key('class-celebration-numeral'))),
        '3',
      );
      expect(
        textOf(
          tester,
          find.byKey(const Key('class-celebration-numeral-label')),
        ),
        'QUESTS DONE TODAY',
      );
      expect(
        textOf(tester, find.byKey(const Key('class-celebration-closing'))),
        'The rest of today is yours.',
      );
      // Nothing is paid for keeping Today's three: no XP row, no rail, no
      // pill, no stat chip.
      expect(find.byKey(const Key('class-celebration-xp')), findsNothing);
      expect(find.byKey(const Key('class-celebration-rail')), findsNothing);
      expect(find.byKey(const Key('class-celebration-pill')), findsNothing);
      expect(
        find.descendant(of: card, matching: find.textContaining('XP')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining(RegExp(r'\d+ of \d+|of three')),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Sunday is Sunday', (tester) async {
      await mount(tester, at: _sunday);
      for (var i = 0; i < 3; i++) {
        await keepOne(tester, settle: i == 2 ? 100 : 3300);
      }
      await waitForCard(tester);
      expect(textOf(tester, headline), 'SUNDAY, DONE.');
    });

    testWidgets('the count is what was kept: two chosen, two', (tester) async {
      await mount(tester, field: _titles.take(2).toList());
      await keepOne(tester);
      await tester.tap(bar);
      await waitForCard(tester);
      expect(card, findsOneWidget);
      expect(
        textOf(tester, find.byKey(const Key('class-celebration-numeral'))),
        '2',
      );
    });

    testWidgets('tap anywhere closes it and the room says Enough for today', (
      tester,
    ) async {
      await mount(tester);
      for (var i = 0; i < 3; i++) {
        await keepOne(tester, settle: i == 2 ? 100 : 3300);
      }
      await waitForCard(tester);
      await pumpFor(tester, 2600);
      await tester.tapAt(const Offset(40, 700));
      await pumpFor(tester, 800);
      expect(card, findsNothing);
      expect(textOf(tester, title), 'Enough for today');
      expect(find.text('What you chose for today is kept.'), findsOneWidget);
      expect(find.text('CLOSE THE DAY'), findsOneWidget);
      expect(
        find.byKey(const Key('quest-day-glass')).hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('once a day: undone and kept again, it does not come twice', (
      tester,
    ) async {
      await mount(tester);
      for (var i = 0; i < 3; i++) {
        await keepOne(tester, settle: i == 2 ? 100 : 3300);
      }
      await waitForCard(tester);
      await closeCard(tester);
      expect(card, findsNothing);
      // Take the last one back, then keep it again.
      await tester.tap(find.byKey(const Key('quest-day-undo')));
      await pumpFor(tester, 2800);
      expect(restores, 1);
      expect(find.byKey(const Key('class-there-button')), findsOneWidget);
      await tester.tap(bar);
      await pumpFor(tester, 9000);
      expect(card, findsNothing);
      expect(textOf(tester, title), 'Enough for today');
    });

    testWidgets('not on a revisit: a cleared day opens quietly', (
      tester,
    ) async {
      await mount(tester, kept: 3);
      await pumpFor(tester, 9000);
      expect(card, findsNothing);
      expect(textOf(tester, title), 'Enough for today');
      expect(find.text('CLOSE THE DAY'), findsOneWidget);
    });

    testWidgets('an Undo before the card shows cancels it', (tester) async {
      await mount(tester);
      await keepOne(tester);
      await keepOne(tester);
      await tester.tap(bar);
      // The third hangs (900 ms) and the tickets are on their way (1900 ms).
      await pumpFor(tester, 1500);
      expect(card, findsNothing);
      await tester.tap(find.byKey(const Key('quest-day-undo')));
      await pumpFor(tester, 9000);
      expect(restores, 1);
      expect(card, findsNothing);
      expect(textOf(tester, title), _titles[2]);
      // Keeping it again is the keep that clears the day: the card comes.
      await tester.tap(bar);
      await waitForCard(tester);
      expect(card, findsOneWidget);
    });

    testWidgets('not on the board: BOARD open, the card does not come', (
      tester,
    ) async {
      await mount(tester);
      await tester.tap(find.byKey(const Key('quest-day-board')));
      await pumpFor(tester, 900);
      for (final q in quests.take(3)) {
        complete(q, const Offset(196, 400));
        await pumpFor(tester, 1500);
      }
      await pumpFor(tester, 9000);
      expect(card, findsNothing);
      expect(find.byKey(const Key('quest-day-room')), findsNothing);
    });

    testWidgets('Gentle Mode keeps its own board: no room, no card', (
      tester,
    ) async {
      await mount(tester, gentle: true);
      expect(find.byKey(const Key('quest-day-room')), findsNothing);
      for (final q in quests.take(3)) {
        complete(q, const Offset(196, 400));
        await pumpFor(tester, 1500);
      }
      await pumpFor(tester, 9000);
      expect(card, findsNothing);
    });

    testWidgets('it holds the Doorway behind it, the tickets in the bowl', (
      tester,
    ) async {
      await mount(tester);
      for (var i = 0; i < 3; i++) {
        await keepOne(tester, settle: i == 2 ? 100 : 3300);
      }
      await waitForCard(tester);
      await pumpFor(tester, 2600);
      final stages = tester
          .stateList<DoorwayStageState>(find.byType(DoorwayStage))
          .toList();
      expect(stages, hasLength(2), reason: 'the room and the card behind it');
      expect(stages.every((s) => s.bowlShown == 1), isTrue);
    });

    testWidgets('the level-up waits for the card and follows it', (
      tester,
    ) async {
      // Two kept already, and one keep from the next level: the third quest
      // crosses it.
      await mount(tester, kept: 2);
      state.xp = state.xpNeeded(state.level + 1) - 1;
      await tester.tap(bar);
      await waitForCard(tester);
      await pumpFor(tester, 2600);
      // The card holds the screen; the full-screen level-up is not over it.
      expect(card, findsOneWidget);
      expect(find.byType(LevelUpOverlay), findsNothing);
      expect(state.level, 18);
      await closeCard(tester);
      await pumpFor(tester, 800);
      expect(card, findsNothing);
      expect(state.level, 19);
      expect(find.byType(LevelUpOverlay), findsOneWidget);
    });

    testWidgets('Reduce Motion: it fades, it does not slam', (tester) async {
      await mount(tester, reduceMotion: true);
      for (var i = 0; i < 3; i++) {
        await keepOne(tester, settle: i == 2 ? 100 : 1500);
      }
      await waitForCard(tester);
      expect(card, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 16));
      // The headline is already at full size on its first frame: no slam.
      final slam = tester.widget<Transform>(
        find.ancestor(of: headline, matching: find.byType(Transform)).first,
      );
      expect(slam.transform.storage[0], 1.0);
      expect(find.byType(CustomPaint).evaluate(), isNotEmpty);
      await pumpFor(tester, 400);
      await closeCard(tester);
      expect(card, findsNothing);
      expect(textOf(tester, title), 'Enough for today');
    });

    testWidgets('with motion, the headline slams in from small', (
      tester,
    ) async {
      await mount(tester);
      for (var i = 0; i < 3; i++) {
        await keepOne(tester, settle: i == 2 ? 100 : 3300);
      }
      await waitForCard(tester);
      await tester.pump(const Duration(milliseconds: 16));
      final slam = tester.widget<Transform>(
        find.ancestor(of: headline, matching: find.byType(Transform)).first,
      );
      expect(slam.transform.storage[0], lessThan(1.0));
    });

    testWidgets('a screen reader hears one label and can close it', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await mount(tester);
      for (var i = 0; i < 3; i++) {
        await keepOne(tester, settle: i == 2 ? 100 : 3300);
      }
      await waitForCard(tester);
      await pumpFor(tester, 2600);
      const label =
          'Saturday, done. 3 quests done today. The rest of today is yours.';
      expect(find.bySemanticsLabel(label), findsOneWidget);
      final node = tester.getSemantics(card);
      expect(node.label, label);
      expect(node.hint, 'Tap to continue');
      final data = node.getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      // The card's words are not read a second time, piece by piece.
      expect(find.bySemanticsLabel('SATURDAY, DONE.'), findsNothing);
      tester.semantics.tap(find.semantics.byLabel(label));
      await pumpFor(tester, 800);
      expect(card, findsNothing);
      handle.dispose();
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('text at ${(scale * 100).round()}%: it all fits, it still '
          'closes', (tester) async {
        await mount(tester, textScale: scale);
        for (var i = 0; i < 3; i++) {
          await keepOne(tester, settle: i == 2 ? 100 : 3300);
        }
        await waitForCard(tester);
        await pumpFor(tester, 2600);
        expect(tester.takeException(), isNull);
        const screen = Rect.fromLTWH(0, 0, 393, 852);
        for (final key in [
          'class-celebration-headline',
          'class-celebration-numeral',
          'class-celebration-numeral-label',
          'class-celebration-closing',
        ]) {
          final rect = tester.getRect(find.byKey(Key(key)));
          expect(
            screen.contains(rect.topLeft) && screen.contains(rect.bottomRight),
            isTrue,
            reason: '$key $rect',
          );
        }
        // The headline stays one line; the closing line wraps rather than
        // running off the card.
        final fitted = find.ancestor(
          of: headline,
          matching: find.byType(FittedBox),
        );
        expect(tester.getSize(fitted.first).width, lessThanOrEqualTo(393 - 40));
        await tester.tapAt(const Offset(30, 780));
        await pumpFor(tester, 800);
        expect(card, findsNothing);
        expect(textOf(tester, title), 'Enough for today');
      });
    }
  });

  group('the card by itself', () {
    testWidgets('a real bonus shows as one pill, at its amount', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
      });
      final state = GameState(rng: _NoLuck());
      var closed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ClassKeptCelebration(
            plan: planQuestDay(
              date: CivilDate(2026, 10, 10),
              kept: 3,
              state: state,
              bonusXp: 12,
            ),
            state: state,
            reduceMotion: true,
            backdrop: (context, top, scrim) =>
                const ColoredBox(color: Color(0xFF1B120C)),
            onDismiss: () => closed++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final pill = find.byKey(const Key('class-celebration-pill'));
      expect(pill, findsOneWidget);
      expect(
        find.descendant(of: pill, matching: find.text('+12 XP')),
        findsOneWidget,
      );
      // The rail and the XP count are the class card's: not here.
      expect(find.byKey(const Key('class-celebration-xp')), findsNothing);
      await tester.tapAt(const Offset(196, 100));
      await tester.pumpAndSettle();
      expect(closed, 1);
    });
  });
}
