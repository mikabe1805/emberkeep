// The Quest board in the house, and the way to it.
//
// In the shell the board is a sheet over the Doorway: its own plate, whole and
// dimmed, under the house's one HUD, with the work starting clear of the HUD
// and dissolving under it as it climbs. No second room is painted there and no
// room photo hangs there. On its own (no shell) the board keeps its old room.
// The way in is a real control in the Doorway's glass: "All quests", a 44 pt
// outlined pill, and the board's own foot has "Today" to come back.
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
import 'package:emberkeep/widgets/class_day/class_day_room.dart';
import 'package:emberkeep/widgets/home_room.dart';
import 'package:emberkeep/widgets/house/house_backdrop.dart';
import 'package:emberkeep/widgets/house/house_hud.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:emberkeep/widgets/quest_desk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/room_fonts.dart';
import '../support/rutgers_fall_2026_ics_fixture.dart';

DateTime _ny(int day, int hour, int minute) =>
    DateTime.utc(2026, 10, day, hour + 4, minute).toLocal();

/// Tuesday 6 October, 12:30: one class ended, one still to come.
DateTime get _tuesday => _ny(6, 12, 30);

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

List<Quest> _quests(DateTime at, {bool chosen = false}) {
  final quests = [
    Quest(title: _titles[0], stat: Stat.intl, difficulty: 4),
    Quest(title: _titles[1], stat: Stat.foc, difficulty: 3),
    Quest(title: _titles[2], stat: Stat.dis, difficulty: 2),
    Quest(title: 'Walk after lunch', stat: Stat.vit, difficulty: 3),
  ];
  if (chosen) applyDailyField(quests, at, _titles);
  return quests;
}

/// A phone: its size and its safe area (the status bar and the home bar).
typedef _Phone = ({double w, double h, double top, double bottom});

const _tall = (w: 393.0, h: 852.0, top: 59.0, bottom: 34.0);
const _se = (w: 375.0, h: 667.0, top: 20.0, bottom: 0.0);
const _small = (w: 320.0, h: 568.0, top: 20.0, bottom: 0.0);

class _Page {
  _Page(this.state, this.quests);
  final GameState state;
  final List<Quest> quests;
  final opened = <Stat>[];
}

/// The real QuestsPage, with or without the shell's HUD over it. In the shell
/// the page sits under a SafeArea (the painting runs up under the status bar)
/// with the house's HUD drawn over it, as the shell does.
Future<_Page> _mount(
  WidgetTester tester, {
  required DateTime at,
  _Phone phone = _tall,
  bool shell = true,
  bool legacy = false,
  bool chosen = false,
  double textScale = 1,
  bool classes = true,
}) async {
  QuestsPage.debugLegacyBoard = legacy;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(phone.w, phone.h);
  tester.view.padding = FakeViewPadding(top: phone.top, bottom: phone.bottom);
  tester.view.viewPadding = FakeViewPadding(
    top: phone.top,
    bottom: phone.bottom,
  );
  addTearDown(tester.view.reset);
  Clock.freeze(at);
  final state = GameState(rng: _NoLuck())
    ..onboarded = true
    ..playerName = 'Mika'
    ..level = 18
    ..xp = 284
    ..totalXp = 4280
    ..soundEnabled = false
    ..lastActiveDay = Days.key(at);
  state.stats[Stat.intl] = 116;
  final quests = _quests(at, chosen: chosen);
  final page = _Page(state, quests);
  final hudKey = GlobalKey();
  // Built inside the listener, as the shell builds it: a change to the save
  // (a closed night) reaches the page.
  Widget quest = ListenableBuilder(
    listenable: state,
    builder: (context, _) => QuestsPage(
      state: state,
      quests: quests,
      onRefresh: () => 0,
      onPersist: () {},
      onAdd: (q) {
        quests.add(q);
        return true;
      },
      onRemove: quests.remove,
      onSnapshot: () => jsonEncode(state.toJson()),
      onRestore: (_) {},
      classDays: classes
          ? (when, {CivilDate? day}) =>
                projectClassDay(_fall2026, when, day: day)
          : null,
      classTerm: _fall2026.termFor,
    ),
  );
  if (shell) {
    quest = Stack(
      children: [
        Positioned.fill(
          child: HouseHudScope(hudKey: hudKey, child: quest),
        ),
        Positioned.fill(
          child: HouseHud(
            state: state,
            hudKey: hudKey,
            onExploreStat: page.opened.add,
          ),
        ),
      ],
    );
  }
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(phone.w, phone.h),
          padding: EdgeInsets.only(top: phone.top, bottom: phone.bottom),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          backgroundColor: Palette.parchment,
          body: SafeArea(bottom: false, child: quest),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  return page;
}

Future<void> _pumpFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

final _toBoardPill = find.byKey(const Key('class-day-toggle-board'));
final _questBoardPill = find.byKey(const Key('quest-day-board'));
final _toRoomPill = find.byKey(const Key('class-day-toggle-room'));
final _boardScroll = find.byKey(const ValueKey('quest-board-scroll'));
final _dissolve = find.byKey(const Key('quest-board-hud-dissolve'));

/// BOARD, from whichever Doorway card is up.
Future<void> _openBoard(WidgetTester tester) async {
  final pill = _toBoardPill.evaluate().isNotEmpty
      ? _toBoardPill
      : _questBoardPill;
  await tester.tap(pill);
  await tester.pump();
  await _pumpFor(tester, 800);
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadHudFonts();
    await loadGoalsRoomFonts();
  });
  setUp(() {
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

  group('the board in the house', () {
    testWidgets('class day: the Doorway\'s plate, dimmed, and no room hero', (
      tester,
    ) async {
      await _mount(tester, at: _tuesday);
      await _openBoard(tester);
      expect(_boardScroll.hitTestable(), findsOneWidget);
      // No second room under the HUD: the old room (and so its photo) is not
      // built at all.
      expect(find.byType(HomeRoom), findsNothing);
      expect(find.byKey(const Key('quests-room')), findsNothing);
      // The Doorway's own plate stands behind the board, still, and dimmed.
      final backdrop = tester.widget<HouseRoomBackdrop>(
        find.byType(HouseRoomBackdrop),
      );
      expect(backdrop.room, HouseRoom.quests);
      expect(backdrop.reduceMotion, isTrue);
      expect(backdrop.plateHeight, isNull, reason: 'the whole page');
      expect(find.byKey(const Key('quest-board-dim')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a day with no classes: the same board, the same plate', (
      tester,
    ) async {
      await _mount(tester, at: _saturday, chosen: true);
      await _openBoard(tester);
      expect(find.byType(HomeRoom), findsNothing);
      expect(find.byType(HouseRoomBackdrop), findsOneWidget);
      expect(find.byKey(const Key('quest-board-dim')), findsOneWidget);
      expect(
        find.byKey(const Key('quest-day-board-room-line')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the board as the whole page (the old seam) is the same', (
      tester,
    ) async {
      await _mount(tester, at: _saturday, legacy: true, classes: false);
      expect(find.byType(HomeRoom), findsNothing);
      expect(find.byType(HouseRoomBackdrop), findsOneWidget);
      expect(find.byKey(const Key('quest-board-dim')), findsOneWidget);
    });

    testWidgets('without the shell the board keeps its old room and panel', (
      tester,
    ) async {
      await _mount(tester, at: _tuesday, shell: false);
      await _openBoard(tester);
      expect(find.byKey(const Key('quests-room')), findsOneWidget);
      expect(find.byKey(const Key('quest-board-dim')), findsNothing);
      expect(_dissolve, findsNothing);
      expect(find.byType(HouseRoomBackdrop), findsNothing);
      // Its own level and XP are there (the HUD is not).
      expect(find.textContaining('LEVEL'), findsWidgets);
    });

    for (final (label, phone, scale) in [
      ('393 x 852', _tall, 1.0),
      ('393 x 852 at 130%', _tall, 1.3),
      ('393 x 852 at 200%', _tall, 2.0),
      ('375 x 667', _se, 1.0),
      ('375 x 667 at 130%', _se, 1.3),
    ]) {
      testWidgets('$label: the work starts clear of the HUD', (tester) async {
        await _mount(tester, at: _tuesday, phone: phone, textScale: scale);
        await _openBoard(tester);
        final statsBottom = Stat.values
            .map(
              (s) => tester
                  .getRect(find.byKey(Key('class-day-stat-${s.name}')))
                  .bottom,
            )
            .reduce(math.max);
        final first = tester.getRect(find.byType(QuestDeskStyleButton));
        expect(
          first.top,
          greaterThanOrEqualTo(statsBottom - 0.5),
          reason: 'the first panel sits under the HUD, never over its numbers',
        );
        // The HUD's own promise to the rooms holds with the board over it.
        final page = tester.getTopLeft(find.byType(HouseHud)).dy;
        expect(
          statsBottom - page,
          lessThanOrEqualTo(houseHudBottom(textScale: scale) + 1),
        );
        // The stats are the top layer: a touch on one reaches it.
        await tester.tap(find.byKey(const Key('class-day-stat-foc')));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a card climbing under the HUD dissolves, and only then', (
      tester,
    ) async {
      await _mount(tester, at: _tuesday);
      await _openBoard(tester);
      double dissolveOpacity() => tester
          .widget<Opacity>(
            find.descendant(of: _dissolve, matching: find.byType(Opacity)),
          )
          .opacity;
      expect(dissolveOpacity(), 0, reason: 'not drawn at rest');
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .descendant(
                    of: _dissolve,
                    matching: find.byType(IgnorePointer),
                  )
                  .first,
            )
            .ignoring,
        isTrue,
      );
      await tester.drag(_boardScroll, const Offset(0, -260));
      await _pumpFor(tester, 600);
      expect(dissolveOpacity(), closeTo(1, 0.01));
      // It reaches from the top of the screen to just below the HUD.
      final box = tester.getRect(
        find
            .descendant(of: _dissolve, matching: find.byType(DecoratedBox))
            .first,
      );
      expect(box.top, closeTo(0, 0.5));
      expect(
        box.bottom,
        closeTo(59 + houseHudBottom() + 14, 0.5),
        reason: 'down past the HUD and 14 pt more',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('every board feature is still there and reachable', (
      tester,
    ) async {
      final page = await _mount(tester, at: _tuesday);
      await _openBoard(tester);
      // The desk, the two tools, Today's three, the quest and the way back.
      expect(find.byType(QuestDeskStyleButton).hitTestable(), findsOneWidget);
      expect(find.text('FOCUS').hitTestable(), findsOneWidget);
      expect(find.text('ADD').hitTestable(), findsOneWidget);
      expect(
        find.byKey(const Key('daily-field-rail')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('MARK COMPLETE').hitTestable(), findsOneWidget);
      expect(_toRoomPill.hitTestable(), findsOneWidget);
      // FOCUS answers.
      expect(page.state.focusMode, isFalse);
      await tester.tap(find.text('FOCUS'));
      await _pumpFor(tester, 400);
      expect(page.state.focusMode, isTrue);
      await tester.tap(find.text('ALL'));
      await _pumpFor(tester, 400);
      expect(page.state.focusMode, isFalse);
      // The desk opens its sheet.
      await tester.tap(find.byType(QuestDeskStyleButton));
      await _pumpFor(tester, 600);
      expect(find.text('YOUR ROOM'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the kept day: its word sits beside the desk, the strip is '
        'not repeated', (tester) async {
      final page = await _mount(tester, at: _saturday, chosen: true);
      await _openBoard(tester);
      page.state.closeNight();
      await _pumpFor(tester, 600);
      expect(find.text('THE DAY IS KEPT'), findsOneWidget);
      final desk = tester.getRect(find.byType(QuestDeskStyleButton));
      final word = tester.getRect(find.text('THE DAY IS KEPT'));
      expect(word.center.dy, closeTo(desk.center.dy, 12));
      expect(word.left, greaterThan(desk.right));
      expect(find.byKey(const Key('daily-field-rail')), findsNothing);
      expect(find.text('FOCUS'), findsNothing);
      expect(find.byType(QuestDeskStyleButton).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a short phone at 130%: the tools still share the desk\'s '
        'row, clear of the HUD', (tester) async {
      await _mount(tester, at: _tuesday, phone: _small, textScale: 1.3);
      await _openBoard(tester);
      expect(tester.takeException(), isNull);
      final statsBottom = Stat.values
          .map(
            (s) => tester
                .getRect(find.byKey(Key('class-day-stat-${s.name}')))
                .bottom,
          )
          .reduce(math.max);
      final desk = tester.getRect(find.byType(QuestDeskStyleButton));
      expect(desk.top, greaterThanOrEqualTo(statsBottom - 0.5));
      expect(find.text('FOCUS').hitTestable(), findsOneWidget);
      expect(find.text('ADD').hitTestable(), findsOneWidget);
      final focus = tester.getRect(find.text('FOCUS'));
      expect(focus.center.dy, closeTo(desk.center.dy, 14));
    });

    testWidgets('FOCUS and ADD sit beside the desk, Today\'s three is whole', (
      tester,
    ) async {
      await _mount(tester, at: _saturday, chosen: true);
      await _openBoard(tester);
      final desk = tester.getRect(find.byType(QuestDeskStyleButton));
      final focus = tester.getRect(find.text('FOCUS'));
      final rail = tester.getRect(find.byKey(const Key('daily-field-rail')));
      // The tools share the desk's row, at the right of it...
      expect(focus.center.dy, closeTo(desk.center.dy, 12));
      expect(focus.left, greaterThan(desk.right));
      // ...and the strip under them says its words in full.
      expect(find.text('ready when you are'), findsOneWidget);
      expect(rail.top, greaterThan(desk.bottom - 1));
      // Cut to an ellipsis it was, beside the tools; whole it is now.
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('ready when you are'))
            .didExceedMaxLines,
        isFalse,
      );
    });
  });

  group('the way to the board', () {
    for (final (label, scale) in [
      ('100%', 1.0),
      ('130%', 1.3),
      ('200%', 2.0),
    ]) {
      testWidgets('class day, $label: "All quests" is a real 44 pt control', (
        tester,
      ) async {
        await _mount(tester, at: _tuesday, textScale: scale);
        expect(find.text('All quests').hitTestable(), findsOneWidget);
        expect(find.text('BOARD'), findsNothing);
        final size = tester.getSize(_toBoardPill);
        expect(size.height, greaterThanOrEqualTo(44));
        expect(size.width, greaterThanOrEqualTo(44));
        expect(_toBoardPill.hitTestable(), findsOneWidget);
        // On the glass, within its padding, and clear of Today's three.
        final glass = tester.getRect(find.byKey(const Key('class-day-glass')));
        final pill = tester.getRect(_toBoardPill);
        expect(pill.right, lessThanOrEqualTo(glass.right));
        expect(pill.bottom, lessThanOrEqualTo(glass.bottom));
        final three = tester.getRect(
          find.byKey(const Key('class-day-todays-three')),
        );
        expect(three.right, lessThanOrEqualTo(pill.left + 0.5));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('rows that scroll past the foot go under it, not over it', (
      tester,
    ) async {
      await _mount(tester, at: _tuesday, phone: _small, textScale: 1.3);
      final clip = tester.widget<ClipRect>(
        find
            .ancestor(
              of: find.byKey(const Key('class-day-scroll')),
              matching: find.byType(ClipRect),
            )
            .first,
      );
      final rect = clip.clipper!.getClip(const Size(200, 300));
      expect(rect.bottom, 300, reason: 'cut at the foot');
      expect(rect.top, lessThan(0), reason: 'glows above still spill');
      expect(rect.left, lessThan(0));
      expect(rect.right, greaterThan(200));
      // The foot is whole and reachable on this phone.
      expect(_toBoardPill.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the pill does not compete with the one lit action', (
      tester,
    ) async {
      await _mount(tester, at: _tuesday);
      // One lit bar on the card; the pill is a different control.
      expect(find.byKey(const Key('class-there-button')), findsOneWidget);
      expect(
        find.descendant(
          of: _toBoardPill,
          matching: find.byType(ClassThereButton),
        ),
        findsNothing,
      );
      // It is outlined and carries no fill gradient of its own.
      final outlined = find.descendant(
        of: _toBoardPill,
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              ((w.decoration as BoxDecoration).border?.top.color.a ?? 0) > 0.3,
        ),
      );
      expect(outlined, findsOneWidget);
      final decoration =
          tester.widget<DecoratedBox>(outlined).decoration as BoxDecoration;
      expect(decoration.gradient, isNull);
      expect(decoration.color!.a, lessThan(0.1));
      // Its words are as readable as the glass's own: cream on dark walnut.
      final label = tester.widget<Text>(find.text('All quests'));
      expect(label.style!.color, Palette.textHi);
      expect(
        _contrast(Palette.textHi, const Color(0xFF2A1D14)),
        greaterThan(7),
      );
    });

    testWidgets('it opens the board, and Today comes back', (tester) async {
      await _mount(tester, at: _tuesday);
      await tester.tap(_toBoardPill);
      await tester.pump();
      await _pumpFor(tester, 800);
      expect(_boardScroll.hitTestable(), findsOneWidget);
      final today = tester.getSize(_toRoomPill);
      expect(today.height, greaterThanOrEqualTo(44));
      expect(find.text('Today').hitTestable(), findsOneWidget);
      expect(find.text('ROOM'), findsNothing);
      await tester.tap(_toRoomPill);
      await tester.pump();
      await _pumpFor(tester, 800);
      expect(
        find.byKey(const Key('class-day-glass')).hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('a day with no classes: the card has it too', (tester) async {
      await _mount(tester, at: _saturday, chosen: true);
      expect(find.byKey(const Key('quest-day-glass')), findsOneWidget);
      expect(find.text('All quests').hitTestable(), findsOneWidget);
      expect(find.text('BOARD'), findsNothing);
      final size = tester.getSize(_questBoardPill);
      expect(size.height, greaterThanOrEqualTo(44));
      // FOCUS and ADD stay, quiet, at its left; the lit action is the bar.
      expect(find.text('FOCUS'), findsOneWidget);
      expect(find.text('ADD'), findsOneWidget);
      expect(find.byKey(const Key('class-there-button')), findsOneWidget);
      final focus = tester.getRect(find.byKey(const Key('quest-day-focus')));
      final pill = tester.getRect(_questBoardPill);
      expect(focus.right, lessThanOrEqualTo(pill.left));
      await tester.tap(_questBoardPill);
      await tester.pump();
      await _pumpFor(tester, 800);
      expect(_boardScroll.hitTestable(), findsOneWidget);
    });

    testWidgets('nothing chosen: the invitation has it too', (tester) async {
      await _mount(tester, at: _saturday);
      expect(find.text('Choose today’s three'), findsOneWidget);
      expect(find.text('All quests').hitTestable(), findsOneWidget);
      expect(find.text('ADD'), findsOneWidget);
      expect(tester.getSize(_questBoardPill).height, greaterThanOrEqualTo(44));
    });

    testWidgets('at large text the pill, Today\'s three and the tools hold', (
      tester,
    ) async {
      await _mount(tester, at: _saturday, chosen: true, textScale: 2);
      expect(tester.takeException(), isNull);
      expect(_questBoardPill.hitTestable(), findsOneWidget);
      expect(find.text('FOCUS').hitTestable(), findsOneWidget);
      expect(find.text('ADD').hitTestable(), findsOneWidget);
    });

    testWidgets('it reads to a screen reader and carries no loss word', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _mount(tester, at: _tuesday);
      // Its name once, not its name and then its words again.
      expect(
        find.bySemanticsLabel('Show all quests, the full Quest board'),
        findsOneWidget,
      );
      for (final bad in ['failed', 'missed', 'lost', 'broke']) {
        expect(find.textContaining(bad, findRichText: true), findsNothing);
      }
      handle.dispose();
    });
  });
}

/// The WCAG contrast ratio of two opaque colors.
double _contrast(Color a, Color b) {
  double lum(Color c) {
    double chan(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * chan(c.r) + 0.7152 * chan(c.g) + 0.0722 * chan(c.b);
  }

  final la = lum(a), lb = lum(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}
