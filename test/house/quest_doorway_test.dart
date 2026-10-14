// The Quests room on a day with no classes: Today's three at the Doorway.
//
// Model (pure): the rail's tickets from Today's three, their states and hooks,
// the rings, the foremost quest, the day's pair in the bowl, the shelf, the
// empty holders, the words a ticket and a screen reader say.
// Widgets (the real QuestsPage): tickets on the rail, the glass card, the
// ritual on a completion (button and ticket) and on an undo, the cleared day,
// the invitation, BOARD and ROOM, a class day left as it was, large text,
// Reduce Motion and screen-reader labels.
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
import 'package:emberkeep/widgets/class_day/doorway_model.dart';
import 'package:emberkeep/widgets/class_day/doorway_rail.dart';
import 'package:emberkeep/widgets/class_day/doorway_stage.dart';
import 'package:emberkeep/widgets/class_day/doorway_tickets.dart';
import 'package:emberkeep/widgets/house/quests/quest_doorway_model.dart';
import 'package:emberkeep/widgets/reward_receipt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/rutgers_fall_2026_ics_fixture.dart';

DateTime _ny(int day, int hour, int minute) =>
    DateTime.utc(2026, 10, day, hour + 4, minute).toLocal();

/// Saturday 10 October, late morning: no classes.
DateTime get _saturday => _ny(10, 11, 0);

final AcademicSchedule _fall2026 = AcademicScheduleIcsImporter.parse(
  rutgersFall2026IcsFixture(),
).applyTo(AcademicSchedule.empty(), updatedAt: DateTime.utc(2026, 8, 27));

class _NoLuck implements math.Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.999;
  @override
  int nextInt(int max) => 0;
}

const _titles = ['Read ten pages', 'Review one problem', 'Write for today'];

List<Quest> _quests({bool chosen = true, DateTime? at}) {
  final quests = [
    Quest(title: _titles[0], stat: Stat.intl, difficulty: 4),
    Quest(title: _titles[1], stat: Stat.foc, difficulty: 3),
    Quest(title: _titles[2], stat: Stat.dis, difficulty: 2),
    Quest(title: 'Walk after lunch', stat: Stat.vit, difficulty: 3),
  ];
  if (chosen) applyDailyField(quests, at ?? _saturday, _titles);
  return quests;
}

QuestDoorwayRead _read(
  List<Quest> quests,
  DateTime now, {
  String? preferred,
  DoorwayDay? base,
  bool weekFinished = false,
  Map<String, int>? shown,
}) {
  final hasField = hasDateScopedDailyField(quests, now);
  return readQuestDoorway(
    quests: quests,
    now: now,
    date: CivilDate.fromDateTime(now),
    field: hasField ? selectedDailyFieldForDay(quests, now) : const [],
    hasField: hasField,
    xp: (q) => shown?[q.title] ?? 10 + q.difficulty,
    preferredTitle: preferred,
    base: base,
    weekFinished: weekFinished,
  );
}

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

  group('the model', () {
    test('Today\'s three are three quest tickets, the first one ready', () {
      final now = _saturday;
      Clock.freeze(now);
      final read = _read(_quests(), now);
      final tickets = read.day.tickets;
      expect(tickets.map((t) => t.quest!.name), _titles);
      expect(tickets.every((t) => t.isQuest && t.entry == null), isTrue);
      expect(tickets.map((t) => t.state), [
        DoorwayTicketState.ready,
        DoorwayTicketState.upcoming,
        DoorwayTicketState.upcoming,
      ]);
      expect(tickets.map((t) => t.quest!.stat), [
        Stat.intl,
        Stat.foc,
        Stat.dis,
      ]);
      expect(tickets.map((t) => t.label), [
        'READ TEN PAGES',
        'REVIEW ONE PROBLEM',
        'WRITE FOR TODAY',
      ]);
      expect(doorwayTicketText(tickets.first), 'READ TEN PAGES\n+14 XP');
      // The rail holds at most three, as the class rail does.
      expect(DoorwayRailLayout.of(read.day).placed, hasLength(3));
      expect(read.foremost?.title, _titles[0]);
      expect(read.pips, [QuestPip.open, QuestPip.open, QuestPip.open]);
    });

    test('every stat has its own glyph, the one the HUD wears', () {
      expect({for (final s in Stat.values) s.icon}, hasLength(6));
    });

    test('a long name is one line of capitals ending in an ellipsis', () {
      final label = doorwayQuestLabel(
        'Write the first section of the lab report for Thursday',
      );
      expect(label.length, lessThanOrEqualTo(20));
      expect(label, endsWith('…'));
      expect(label, label.toUpperCase());
      expect(doorwayQuestLabel('Walk'), 'WALK');
    });

    test('a kept quest hangs on a hook and the next one leads', () {
      final now = _saturday;
      Clock.freeze(now);
      final quests = _quests();
      quests.first.lastDoneDay = Days.key(now);
      final read = _read(quests, now);
      final first = read.day.tickets.first;
      expect(first.state, DoorwayTicketState.attended);
      expect(first.hook, doorwayHooksFor(3).first);
      expect(read.foremost?.title, _titles[1]);
      expect(read.day.tickets[1].state, DoorwayTicketState.ready);
      expect(read.pips.first, QuestPip.kept);
      expect(read.keptCount, 1);
      expect(read.allKept, isFalse);
      expect(read.day.bowlPairs, isEmpty);
      // The rail keeps the holder of a ticket that went to its hook.
      expect(DoorwayRailLayout.of(read.day).slots, 3);
    });

    test('a kept ticket keeps the XP it said, or says its name alone', () {
      final now = _saturday;
      Clock.freeze(now);
      final quests = _quests();
      quests.first.lastDoneDay = Days.key(now);
      final read = _read(quests, now, shown: {_titles[0]: 28});
      expect(
        doorwayTicketText(read.day.tickets.first),
        'READ TEN PAGES\n+28 XP',
      );
      final unknown = readQuestDoorway(
        quests: quests,
        now: now,
        date: CivilDate.fromDateTime(now),
        field: selectedDailyFieldForDay(quests, now),
        hasField: true,
        xp: (q) => q.doneFor(now) ? null : 12,
      );
      expect(doorwayTicketText(unknown.day.tickets.first), 'READ TEN PAGES');
      expect(
        doorwayTicketSemantics(unknown.day.tickets.first),
        'Read ten pages, Intellect, kept',
      );
    });

    test('he can bring a waiting quest forward', () {
      final now = _saturday;
      Clock.freeze(now);
      final read = _read(_quests(), now, preferred: _titles[2]);
      expect(read.foremost?.title, _titles[2]);
      expect(read.day.tickets.map((t) => t.state), [
        DoorwayTicketState.upcoming,
        DoorwayTicketState.upcoming,
        DoorwayTicketState.ready,
      ]);
    });

    test('a quest set aside stays one of the three, quiet', () {
      final now = _saturday;
      Clock.freeze(now);
      final quests = _quests();
      quests[1].snoozedDay = Days.key(now);
      final read = _read(quests, now);
      expect(read.day.tickets[1].state, DoorwayTicketState.settled);
      expect(read.day.tickets[1].markable, isFalse);
      expect(read.pips[1], QuestPip.resting);
      expect(read.foremost?.title, _titles[0]);
      expect(read.restingCount, 1);
      // Setting a quest aside never clears the day.
      for (final q in quests.where((q) => q.title != _titles[1])) {
        q.lastDoneDay = Days.key(now);
      }
      expect(_read(quests, now).allKept, isFalse);
    });

    test('all three kept: the day\'s pair goes in the bowl', () {
      final now = _saturday;
      Clock.freeze(now);
      final quests = _quests();
      for (final q in quests.take(3)) {
        q.lastDoneDay = Days.key(now);
      }
      final read = _read(quests, now);
      expect(read.allKept, isTrue);
      expect(read.foremost, isNull);
      expect(read.day.bowlPairs, [CivilDate.fromDateTime(now)]);
      expect(read.day.tickets.map((t) => t.hook), [0, 2, 4]);
    });

    test('nothing is ever counted against him, nor said as "of three"', () {
      final now = _saturday;
      Clock.freeze(now);
      final quests = _quests();
      expect(_read(quests, now).semantics, 'Today’s three, none kept yet');
      quests.first.lastDoneDay = Days.key(now);
      expect(_read(quests, now).semantics, 'Today’s three, 1 kept');
      for (final q in quests.take(3)) {
        q.lastDoneDay = Days.key(now);
      }
      expect(_read(quests, now).semantics, 'Today’s three, all kept');
      for (final q in quests) {
        q.lastDoneDay = null;
      }
      expect(_read(quests, now).semantics, isNot(contains(' of ')));
      expect(
        _read(_quests(chosen: false), now).semantics,
        'Today’s three, not chosen yet',
      );
    });

    test('not chosen: three empty holders and no tickets', () {
      final now = _saturday;
      Clock.freeze(now);
      final read = _read(_quests(chosen: false), now);
      expect(read.hasField, isFalse);
      expect(read.day.tickets, isEmpty);
      expect(read.pips, everyElement(QuestPip.empty));
      final layout = DoorwayRailLayout.of(read.day);
      expect(layout.slots, 3);
      expect(layout.placed, isEmpty);
      // A class day's empty rail keeps its one.
      expect(
        DoorwayRailLayout.of(
          DoorwayDay.quiet(CivilDate.fromDateTime(now)),
        ).slots,
        1,
      );
    });

    test(
      'the week\'s pairs are a bundle on the shelf once classes are over',
      () {
        final now = _saturday;
        Clock.freeze(now);
        final date = CivilDate.fromDateTime(now);
        final base = DoorwayDay(
          date: date,
          tickets: const [],
          bowlPairs: [date.addDays(-1), date.addDays(-2)],
          shelfBundles: [
            DoorwayShelfBundle(weekStart: date.addDays(-12), attended: 4),
          ],
          termName: 'Fall 2026',
        );
        final over = _read(_quests(), now, base: base, weekFinished: true);
        expect(over.day.shelfCount, 2);
        expect(over.day.bowlPairs, isEmpty);
        expect(over.day.shelfLabel, 'FALL TERM · 2 WEEKS');
        final during = _read(_quests(), now, base: base);
        expect(during.day.shelfCount, 1);
        expect(during.day.bowlPairs, hasLength(2));
      },
    );

    test('the bar says what the press does', () {
      expect(
        questBarLabel(Quest(title: 'a', stat: Stat.str, difficulty: 2)),
        'MARK COMPLETE',
      );
      expect(
        questBarLabel(
          Quest(
            title: 'b',
            stat: Stat.foc,
            difficulty: 2,
            verification: Verification.timer,
            timerMinutes: 25,
          ),
        ),
        'OPEN 25-MINUTE SESSION',
      );
      expect(
        questBarLabel(
          Quest(title: 'c', stat: Stat.str, difficulty: 2, workout: true),
        ),
        'BEGIN SESSION',
      );
    });
  });

  group('the room', () {
    late GameState state;
    late List<Quest> quests;
    var restores = 0;

    Future<void> mount(
      WidgetTester tester, {
      DateTime? at,
      bool chosen = true,
      bool reduceMotion = false,
      double textScale = 1,
      bool classes = true,
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
      quests = _quests(chosen: chosen, at: now);
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
                  // An undo hands the quest back: the host does what the
                  // shell's restore does to the board.
                  onRestore: (_) {
                    restores++;
                    for (final q in quests) {
                      if (q.title == _titles[0]) q.lastDoneDay = null;
                    }
                    setHost(() {});
                  },
                  classDays: classes ? lookup : null,
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

    DoorwayStageState stage(WidgetTester tester) =>
        tester.state<DoorwayStageState>(find.byType(DoorwayStage));

    final title = find.byKey(const Key('quest-day-title'));
    final bar = find.byKey(const Key('class-there-button'));

    String titleText(WidgetTester tester) =>
        tester.widget<Text>(title).data ?? '';

    testWidgets('Saturday holds Today\'s three as quest tickets', (
      tester,
    ) async {
      await mount(tester);
      expect(find.byKey(const Key('quest-day-room')), findsOneWidget);
      expect(find.byKey(const Key('class-day-room')), findsNothing);
      expect(
        stage(tester).placedTickets.map((p) => p.ticket.quest!.name),
        _titles,
      );
      expect(find.text('TODAY’S THREE'), findsOneWidget);
      expect(titleText(tester), 'Read ten pages');
      expect(find.text('MARK COMPLETE'), findsOneWidget);
      for (final word in ['FOCUS', 'ADD', 'All quests']) {
        expect(find.text(word), findsOneWidget);
      }
      // The old mono word is gone: the way to the board says where it goes.
      expect(find.text('BOARD'), findsNothing);
      // Never a fraction.
      expect(
        find.textContaining(RegExp(r'\d OF \d', caseSensitive: false)),
        findsNothing,
      );
      expect(find.byKey(const Key('quest-day-rings')), findsOneWidget);
    });

    testWidgets('MARK COMPLETE runs the ritual in the scene, no card', (
      tester,
    ) async {
      await mount(tester);
      await tester.tap(bar);
      await tester.pump(const Duration(milliseconds: 120));
      expect(stage(tester).markingIds, ['quest:Read ten pages']);
      // The glass moves on at once.
      expect(titleText(tester), 'Review one problem');
      await pumpFor(tester, 3200);
      expect(stage(tester).markingIds, isEmpty);
      expect(
        find.byKey(const ValueKey('doorway-hung-quest:Read ten pages')),
        findsOneWidget,
      );
      // An ordinary completion is the scene's own: no receipt, no full-screen
      // card, and the Undo waits on the card.
      expect(find.byType(RewardReceipt), findsNothing);
      expect(find.byKey(const Key('quest-day-undo')), findsOneWidget);
      expect(quests.first.doneFor(Clock.now()), isTrue);
    });

    testWidgets('Undo hangs the ticket back in its holder', (tester) async {
      await mount(tester);
      await tester.tap(bar);
      await pumpFor(tester, 3200);
      await tester.tap(find.byKey(const Key('quest-day-undo')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(restores, 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(stage(tester).markingIds, ['quest:Read ten pages']);
      expect(titleText(tester), 'Read ten pages');
      await pumpFor(tester, 2500);
      expect(
        stage(tester).placedTickets.map((p) => p.ticket.quest!.name),
        contains('Read ten pages'),
      );
      expect(find.byKey(const Key('quest-day-undo')), findsNothing);
    });

    testWidgets('lifting a ticket up the wall marks it', (tester) async {
      await mount(tester);
      final ticket = find.byKey(
        const ValueKey('doorway-drag-quest:Read ten pages'),
      );
      expect(ticket, findsOneWidget);
      await tester.drag(ticket, const Offset(0, -60));
      await tester.pump(const Duration(milliseconds: 100));
      expect(quests.first.doneFor(Clock.now()), isTrue);
      expect(stage(tester).markingIds, ['quest:Read ten pages']);
      await pumpFor(tester, 3200);
    });

    testWidgets('tapping a waiting ticket brings its quest forward', (
      tester,
    ) async {
      await mount(tester);
      await tester.tap(
        find.byKey(const ValueKey('doorway-tap-quest:Write for today')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(titleText(tester), 'Write for today');
      expect(quests.every((q) => !q.doneFor(Clock.now())), isTrue);
    });

    testWidgets(
      'all three kept: the tickets go to the bowl, the day is enough',
      (tester) async {
        await mount(tester);
        for (var i = 0; i < 3; i++) {
          await tester.tap(bar);
          await pumpFor(tester, 3300);
          // A rare beat (a freeze banked) keeps its receipt until it leaves.
          for (var w = 0; w < 30; w++) {
            if (find.byType(RewardReceipt).evaluate().isEmpty) break;
            await pumpFor(tester, 500);
          }
        }
        expect(titleText(tester), 'Enough for today');
        expect(find.text('What you chose for today is kept.'), findsOneWidget);
        // The day's card ("SATURDAY, DONE.") holds the screen once the
        // tickets have landed; a tap closes it onto the room (its own tests
        // are in quest_day_card_test.dart).
        final dayCard = find.byKey(const Key('class-kept-celebration'));
        for (var w = 0; w < 80 && dayCard.evaluate().isEmpty; w++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(dayCard, findsOneWidget);
        await pumpFor(tester, 2600);
        await tester.tapAt(const Offset(196, 420));
        await pumpFor(tester, 800);
        expect(dayCard, findsNothing);
        expect(stage(tester).bowlShown, 1);
        // Closing the day is the one lamp.
        expect(find.text('CLOSE THE DAY'), findsOneWidget);
        // No loss words anywhere on the card.
        for (final bad in ['failed', 'missed', 'lost', 'broke']) {
          expect(find.textContaining(bad, findRichText: true), findsNothing);
        }
      },
    );

    testWidgets('not chosen: a quiet invitation that opens the wizard', (
      tester,
    ) async {
      await mount(tester, chosen: false);
      expect(find.text('Choose today’s three'), findsOneWidget);
      expect(find.text('MARK COMPLETE'), findsNothing);
      expect(stage(tester).placedTickets, isEmpty);
      expect(find.byKey(const Key('doorway-rail')), findsOneWidget);
      expect(find.byKey(const Key('quest-day-add')), findsOneWidget);
      expect(find.byKey(const Key('quest-day-board')), findsOneWidget);
      await tester.tap(find.byKey(const Key('quest-day-choose')));
      await pumpFor(tester, 800);
      expect(find.text('Choose today'), findsWidgets);
    });

    testWidgets('BOARD opens the full board and ROOM comes back', (
      tester,
    ) async {
      await mount(tester);
      await tester.tap(find.byKey(const Key('quest-day-board')));
      await pumpFor(tester, 800);
      expect(
        find.byKey(const ValueKey('quest-board-scroll')).hitTestable(),
        findsOneWidget,
      );
      // The board is whole: the day strip with its tools, every quest card.
      expect(
        find.byKey(const Key('quest-day-board-room-line')),
        findsOneWidget,
      );
      expect(find.text('Read ten pages'), findsWidgets);
      expect(
        find.text('Walk after lunch'),
        findsNothing,
      ); // a side quest, behind its divider
      await tester.tap(find.byKey(const Key('class-day-toggle-room')));
      await pumpFor(tester, 800);
      expect(
        find.byKey(const Key('quest-day-glass')).hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('a class day keeps the class room and its card row', (
      tester,
    ) async {
      await mount(tester, at: _ny(6, 12, 30));
      expect(find.byKey(const Key('class-day-room')), findsOneWidget);
      expect(find.byKey(const Key('quest-day-room')), findsNothing);
      expect(find.byKey(const Key('class-day-todays-three')), findsOneWidget);
    });

    testWidgets('large text: the card scrolls, the tickets keep their size', (
      tester,
    ) async {
      await mount(tester, textScale: 2);
      expect(tester.takeException(), isNull);
      expect(titleText(tester), 'Read ten pages');
      expect(bar.hitTestable(), findsOneWidget);
      expect(
        find.byKey(const Key('quest-day-board')).hitTestable(),
        findsOneWidget,
      );
      // The ticket's words are the painting's: they do not grow with the
      // reader's text.
      final words = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('doorway-ticket-quest:Read ten pages')),
          matching: find.textContaining('READ TEN PAGES'),
        ),
      );
      expect(words.style?.fontSize, 4.5);
      final scaler = MediaQuery.textScalerOf(
        tester.element(
          find.descendant(
            of: find.byKey(
              const ValueKey('doorway-ticket-quest:Read ten pages'),
            ),
            matching: find.textContaining('READ TEN PAGES'),
          ),
        ),
      );
      expect(scaler.scale(10), 10);
    });

    testWidgets('Reduce Motion: the move is a cross-fade and still completes', (
      tester,
    ) async {
      await mount(tester, reduceMotion: true);
      await tester.tap(bar);
      await tester.pump(const Duration(milliseconds: 100));
      expect(stage(tester).markingIds, ['quest:Read ten pages']);
      await pumpFor(tester, 800);
      expect(stage(tester).markingIds, isEmpty);
      expect(
        find.byKey(const ValueKey('doorway-hung-quest:Read ten pages')),
        findsOneWidget,
      );
    });

    testWidgets('tickets and the card are labelled for a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await mount(tester);
      final one = state.xpPreview(quests[0]);
      final two = state.xpPreview(quests[1]);
      expect(
        find.bySemanticsLabel('Read ten pages, Intellect, +$one XP, up next'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Review one problem, Focus, +$two XP, waiting'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Today’s three, none kept yet'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('MARK COMPLETE: Read ten pages')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
