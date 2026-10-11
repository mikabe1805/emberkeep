// The Doorway's stage: the light of day, the ticket rail for any number of
// events (none, one, two, three and five), the queue behind the wall, "Couldn't
// make it", optional events, the hooks, the bowl and the shelf, the evening
// and Reduce Motion. The stage is a painting with live text on it, so these
// read its structure (what is on the wall, where it hangs, what the clock's
// light is) rather than pixels; the renders in test/design_renders carry those.
//
// Instants only (New York wall times converted from UTC), so this holds on a
// host in any zone.
import 'dart:math' as math;

import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/widgets/class_day/doorway_art.dart';
import 'package:emberkeep/widgets/class_day/doorway_light.dart';
import 'package:emberkeep/widgets/class_day/doorway_model.dart';
import 'package:emberkeep/widgets/class_day/doorway_rail.dart';
import 'package:emberkeep/widgets/class_day/doorway_stage.dart';
import 'package:emberkeep/widgets/class_day/doorway_tickets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/crowded_friday_schedule.dart';
import 'support/rutgers_fall_2026_ics_fixture.dart';

DateTime _ny(int month, int day, int hour, int minute) =>
    DateTime.utc(2026, month, day, hour + 4, minute).toLocal();

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

GameState _state() => GameState(rng: _NoLuck())..soundEnabled = false;

DoorwayDay _doorway(AcademicSchedule schedule, GameState state, DateTime at) {
  Clock.freeze(at);
  return DoorwayDay.read(schedule, state, at);
}

/// A Friday (2026-10-09) of [kinds] meetings at 8:00, 9:00, 10:00...
AcademicSchedule _friday(List<String> kinds) => crowdedFridaySchedule(kinds);

DateTime _fri(int hour, int minute) => _ny(10, 9, hour, minute);

Future<void> _mount(
  WidgetTester tester,
  DoorwayDay day, {
  bool reduceMotion = false,
  ValueListenable<Offset>? parallax,
  DateTime? now,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SizedBox(
          width: 393,
          height: 852,
          child: DoorwayStage(
            day: day,
            reduceMotion: reduceMotion,
            parallax: parallax,
            now: now,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

DoorwayStageState _stage(WidgetTester tester) =>
    tester.state<DoorwayStageState>(find.byType(DoorwayStage));

Finder _ticket(DoorwayTicket t) =>
    find.byKey(ValueKey('doorway-ticket-${t.id}'));
Finder _hung(DoorwayTicket t) => find.byKey(ValueKey('doorway-hung-${t.id}'));

/// Lets the rail's chain (a gap closing, the next ticket clipping in; about
/// a second) and a ticket's trip to its hook (about 2.8 s with its swing)
/// finish.
Future<void> _glide(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => GameState.debugRandomFactory = _NoLuck.new);
  tearDown(() {
    Clock.reset();
    GameState.debugRandomFactory = null;
  });

  group('the light of day', () {
    test('midday, golden hour and dusk by the clock', () {
      expect(doorwayLightsAtMinute(12 * 60).midday, 1);
      expect(doorwayLightsAtMinute(17 * 60).golden, 1);
      for (final hour in [20, 23, 2, 5]) {
        expect(doorwayLightsAtMinute(hour * 60).evening, 1, reason: '$hour');
      }
    });

    test('each blend is forty minutes wide, centered on its boundary', () {
      // 06:00: dawn is half midday, half evening.
      final dawn = doorwayLightsAtMinute(6 * 60);
      expect(dawn.midday, closeTo(0.5, 1e-9));
      expect(dawn.evening, closeTo(0.5, 1e-9));
      expect(doorwayLightsAtMinute(6 * 60 - 20).evening, 1);
      expect(doorwayLightsAtMinute(6 * 60 + 20).midday, 1);
      // 15:30 and 18:30.
      final gold = doorwayLightsAtMinute(15 * 60 + 30);
      expect(gold.midday, closeTo(0.5, 1e-9));
      expect(gold.golden, closeTo(0.5, 1e-9));
      final dusk = doorwayLightsAtMinute(18 * 60 + 30);
      expect(dusk.golden, closeTo(0.5, 1e-9));
      expect(dusk.evening, closeTo(0.5, 1e-9));
      // Outside the blend there is only one light.
      expect(doorwayLightsAtMinute(15 * 60 + 9).midday, 1);
      expect(doorwayLightsAtMinute(15 * 60 + 51).golden, 1);
    });

    test('the weights always sum to one and never leave zero to one', () {
      for (var m = 0.0; m < 24 * 60; m += 3) {
        final w = doorwayLightsAtMinute(m);
        expect(w.midday + w.golden + w.evening, closeTo(1, 1e-9), reason: '$m');
        for (final x in w.weights) {
          expect(x, inInclusiveRange(0, 1));
        }
      }
    });

    test('cross-fade: the first live light opaque, the next over it', () {
      expect(doorwayCrossfade([1, 0, 0]), [1, 0, 0]);
      final mid = doorwayCrossfade([0.5, 0.5, 0]);
      expect(mid[0], 1);
      expect(mid[1], closeTo(0.5, 1e-9));
      expect(doorwayCrossfade([0, 0.25, 0.75]), [0, 1, closeTo(0.75, 1e-9)]);
    });

    testWidgets('the stage reads the app clock, never a tint', (tester) async {
      final day = _doorway(_fall2026, _state(), _ny(10, 6, 12, 51));
      // The light follows the phone's own clock, so these are its local
      // times, whatever zone the test machine is in.
      Clock.freeze(DateTime(2026, 10, 6, 12, 51));
      await _mount(tester, day);
      expect(_stage(tester).lights.midday, 1);

      Clock.freeze(DateTime(2026, 10, 6, 17, 0));
      await _mount(tester, day, now: DateTime(2026, 10, 6, 17, 0));
      expect(_stage(tester).lights.golden, 1);

      await _mount(tester, day, now: DateTime(2026, 10, 6, 15, 30));
      final blend = _stage(tester).lights;
      expect(blend.midday, closeTo(0.5, 0.01));
      expect(blend.golden, closeTo(0.5, 0.01));
    });
  });

  group('the rail, for any number of events', () {
    for (final (name, kinds, placed, queued) in [
      ('no events', <String>[], 0, 0),
      ('one event', ['lecture'], 1, 0),
      ('two events', ['lecture', 'lab'], 2, 0),
      ('three events', ['lecture', 'lab', 'recitation'], 3, 0),
      ('five events', List.filled(5, 'lecture'), 3, 2),
    ]) {
      testWidgets('$name: $placed on the wall, $queued waiting', (
        tester,
      ) async {
        // No events: a Saturday on the same timetable (the day has none).
        final day = kinds.isEmpty
            ? _doorway(_fall2026, _state(), _ny(10, 10, 12, 0))
            : _doorway(_friday(kinds), _state(), _fri(7, 0));
        await _mount(tester, day);
        expect(tester.takeException(), isNull);
        final stage = _stage(tester);
        expect(stage.placedTickets, hasLength(placed));
        expect(stage.queuedTickets, hasLength(queued));
        expect(find.byType(DoorwayTicketView), findsNWidgets(placed));
        // The wall always has a holder, and never more than three.
        final layout = DoorwayRailLayout.of(day);
        expect(layout.slots, math.max(1, math.min(3, kinds.length)));
        // Full size for one or two, about 89% height for three.
        final scale = layout.scale;
        if (kinds.length >= 3) {
          expect(scale, closeTo(0.894, 0.005));
        } else {
          expect(scale, 1);
        }
        // Nothing hangs or lies in the bowl on a morning with nothing kept.
        expect(find.byKey(const Key('doorway-bowl')), findsNothing);
        expect(find.textContaining('doorway-hung'), findsNothing);
      });
    }

    test(
      'the tickets stand in their holders, down the wall, never past it',
      () {
        final day = _doorway(
          _friday(List.filled(5, 'lecture')),
          _state(),
          _fri(7, 0),
        );
        final layout = DoorwayRailLayout.of(day);
        var lastBottom = 0.0;
        for (final placed in layout.placed) {
          expect(placed.center.dx, doorwayRailCenterX);
          expect(placed.rect.top, greaterThanOrEqualTo(doorwayWallTop - 0.5));
          expect(placed.rect.top, greaterThan(lastBottom - placed.size.height));
          expect(
            placed.rect.bottom,
            lessThanOrEqualTo(doorwayWallBottom + 0.5),
          );
          lastBottom = placed.rect.bottom;
        }
      },
    );

    testWidgets('the tickets carry live text: a label and a time', (
      tester,
    ) async {
      final day = _doorway(_fall2026, _state(), _ny(10, 6, 12, 51));
      await _mount(tester, day);
      // Computer Architecture ended 11:40 and waits; Discrete starts at 2:00.
      expect(find.text('ARCHITECTURE · 11:40'), findsOneWidget);
      expect(find.text('DISCRETE · 2:00'), findsOneWidget);
    });
  });

  group('the queue behind the wall', () {
    testWidgets('a kept class hangs, and the next one is clipped in', (
      tester,
    ) async {
      final schedule = _friday(List.filled(5, 'lecture'));
      final state = _state();
      var day = _doorway(schedule, state, _fri(7, 0));
      await _mount(tester, day);
      final all = day.tickets;
      expect(_stage(tester).placedTickets.map((p) => p.ticket.id), [
        for (final t in all.take(3)) t.id,
      ]);
      expect(_ticket(all[3]), findsNothing, reason: 'it waits off the wall');

      // The first class ends and is kept.
      final at = _fri(8, 55);
      Clock.freeze(at);
      expect(
        state.keepClass(
          all.first.facts,
          dayClassKeys: all.map((t) => t.facts.identity).toList(),
        ),
        isNotNull,
      );
      day = _doorway(schedule, state, at);
      await _mount(tester, day);
      // The kept ticket lifts out first; the next one clips in once the gap
      // has closed.
      await tester.pump(const Duration(milliseconds: 900));
      expect(_ticket(all[3]), findsOneWidget, reason: 'coming in from the lip');
      await _glide(tester);
      expect(_stage(tester).placedTickets.map((p) => p.ticket.id), [
        for (final t in all.skip(1).take(3)) t.id,
      ]);
      expect(_stage(tester).queuedTickets.map((t) => t.id), [all[4].id]);
      expect(
        _stage(tester).placedTickets.map((p) => p.ticket.id),
        isNot(contains(all.first.id)),
        reason: 'it left the holder',
      );
      expect(_hung(all.first), findsOneWidget, reason: 'it hangs on a hook');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the wall never holds more than three', (tester) async {
      final schedule = _friday(List.filled(8, 'lecture'));
      final state = _state();
      final day = _doorway(schedule, state, _fri(7, 0));
      await _mount(tester, day);
      expect(find.byType(DoorwayTicketView), findsNWidgets(3));
      expect(_stage(tester).queuedTickets, hasLength(5));
    });

    testWidgets('as the day empties the wall shrinks back to what waits', (
      tester,
    ) async {
      final schedule = _friday(List.filled(4, 'lecture'));
      final state = _state();
      final first = _doorway(schedule, state, _fri(7, 0));
      final keys = first.tickets.map((t) => t.facts.identity).toList();
      // Keep the first three, one after the other.
      for (var i = 0; i < 3; i++) {
        Clock.freeze(_fri(9 + i, 5));
        state.keepClass(first.tickets[i].facts, dayClassKeys: keys);
      }
      final day = _doorway(schedule, state, _fri(11, 30));
      await _mount(tester, day);
      final stage = _stage(tester);
      expect(stage.placedTickets, hasLength(1));
      expect(stage.queuedTickets, isEmpty);
      expect(DoorwayRailLayout.of(day).scale, 1);
    });
  });

  group("Couldn't make it", () {
    testWidgets('the class leaves the wall and its place is closed up', (
      tester,
    ) async {
      final schedule = _friday(List.filled(5, 'lecture'));
      final state = _state();
      var day = _doorway(schedule, state, _fri(7, 0));
      await _mount(tester, day);
      final all = day.tickets;
      expect(state.dismissClass(all[1].facts), isTrue);
      day = _doorway(schedule, state, _fri(7, 0));
      await _mount(tester, day);
      // Slipping out: still there a moment, fading.
      await tester.pump(const Duration(milliseconds: 150));
      await _glide(tester);
      expect(find.byKey(ValueKey('doorway-ticket-${all[1].id}')), findsNothing);
      expect(find.byKey(ValueKey('doorway-hung-${all[1].id}')), findsNothing);
      // Four left: still three on the wall and one in the queue.
      expect(_stage(tester).placedTickets.map((p) => p.ticket.id), [
        all[0].id,
        all[2].id,
        all[3].id,
      ]);
      expect(_stage(tester).queuedTickets.map((t) => t.id), [all[4].id]);
      // Nothing in the picture counts what was set aside.
      expect(find.textContaining('couldn'), findsNothing);
    });

    testWidgets('with one left the day is a one-ticket wall at full size', (
      tester,
    ) async {
      final schedule = _friday(['lecture', 'lecture']);
      final state = _state();
      final first = _doorway(schedule, state, _fri(7, 0));
      state.dismissClass(first.tickets.first.facts);
      final day = _doorway(schedule, state, _fri(7, 0));
      await _mount(tester, day);
      expect(_stage(tester).placedTickets, hasLength(1));
      expect(DoorwayRailLayout.of(day).slots, 1);
      expect(DoorwayRailLayout.of(day).scale, 1);
    });

    testWidgets('a day whose every class was set aside has an empty wall', (
      tester,
    ) async {
      final schedule = _friday(['lecture', 'lab']);
      final state = _state();
      final first = _doorway(schedule, state, _fri(7, 0));
      for (final t in first.tickets) {
        state.dismissClass(t.facts);
      }
      final day = _doorway(schedule, state, _fri(7, 0));
      await _mount(tester, day);
      expect(find.byType(DoorwayTicketView), findsNothing);
      expect(_stage(tester).placedTickets, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('optional events', () {
    testWidgets('office hours hang as a quieter, ringless ticket', (
      tester,
    ) async {
      final day = _doorway(
        _friday(['lecture', 'office hours', 'lecture']),
        _state(),
        _fri(7, 0),
      );
      await _mount(tester, day);
      final office = day.tickets[1];
      expect(office.counts, isFalse);
      final view = tester.widget<DoorwayTicketView>(
        find.descendant(
          of: find.byType(DoorwayStage),
          matching: find.byWidgetPredicate(
            (w) => w is DoorwayTicketView && w.ticket.id == office.id,
          ),
        ),
      );
      // Smaller than a class's ticket, and says so in words.
      expect(view.kx, lessThan(1));
      expect(
        view.ky,
        lessThan(DoorwayRailLayout.of(day).scale),
        reason: 'a little shorter than the others',
      );
      expect(find.textContaining('· optional'), findsOneWidget);
      // A class's ticket does not say it.
      expect(doorwayTicketText(day.tickets.first), isNot(contains('optional')));
    });
  });

  group('hooks, bowl and shelf', () {
    testWidgets('an attended ticket hangs; its holder stays', (tester) async {
      final state = _state();
      Clock.freeze(_ny(10, 6, 12, 40));
      final day0 = _doorway(_fall2026, state, _ny(10, 6, 12, 40));
      final arch = day0.tickets.first;
      state.keepClass(
        arch.facts,
        dayClassKeys: day0.tickets.map((t) => t.facts.identity).toList(),
      );
      final day = _doorway(_fall2026, state, _ny(10, 6, 12, 51));
      await _mount(tester, day);
      expect(_hung(arch), findsOneWidget);
      expect(_ticket(arch), findsOneWidget, reason: 'the card on its hook');
      // Its holder stays on the wall, empty; the other class waits in its own.
      final layout = DoorwayRailLayout.of(day);
      expect(layout.slots, 2);
      expect(layout.placed, hasLength(1));
      expect(layout.placed.single.slot, 1);
    });

    testWidgets('a finished day lies in the bowl, and hangs nothing', (
      tester,
    ) async {
      final state = _state();
      // Monday's three classes, all kept.
      final monday = _doorway(_fall2026, state, _ny(10, 5, 21, 0));
      for (final t in monday.tickets) {
        Clock.freeze(_ny(10, 5, 21, 0));
        state.keepClass(
          t.facts,
          dayClassKeys: monday.tickets.map((x) => x.facts.identity).toList(),
        );
      }
      final day = _doorway(_fall2026, state, _ny(10, 6, 12, 51));
      expect(day.bowlPairs, isNotEmpty);
      await _mount(tester, day);
      expect(find.byKey(const Key('doorway-bowl')), findsOneWidget);
      expect(find.byKey(const ValueKey('doorway-bowl-0-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('doorway-bowl-0-1')), findsOneWidget);
      // Today's own class is not there yet.
      expect(find.byKey(const ValueKey('doorway-bowl-1-0')), findsNothing);
    });

    testWidgets('weeks he went to class are tied on the shelf', (tester) async {
      final state = _state();
      for (final (month, d) in const [(9, 15), (9, 22), (9, 29)]) {
        Clock.freeze(_ny(month, d, 21, 0));
        final past = DoorwayDay.read(_fall2026, state, Clock.now());
        if (past.tickets.isEmpty) continue;
        state.keepClass(
          past.tickets.first.facts,
          dayClassKeys: [past.tickets.first.facts.identity],
        );
      }
      final day = _doorway(_fall2026, state, _ny(10, 6, 12, 51));
      expect(day.shelfBundles, hasLength(3));
      await _mount(tester, day);
      expect(find.byKey(const ValueKey('doorway-bundle-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('doorway-bundle-2')), findsOneWidget);
      expect(find.text('FALL TERM · 3 WEEKS'), findsOneWidget);
    });

    testWidgets('a bare shelf says nothing, never zero', (tester) async {
      final day = _doorway(_fall2026, _state(), _ny(10, 6, 12, 51));
      await _mount(tester, day);
      expect(find.byKey(const ValueKey('doorway-bundle-0')), findsNothing);
      expect(find.byKey(const Key('doorway-shelf-label')), findsNothing);
    });
  });

  group('the evening', () {
    testWidgets('the same Doorway under the evening light', (tester) async {
      final day = _doorway(_fall2026, _state(), _ny(10, 6, 20, 15));
      // The phone's own 20:15 (the light reads local time).
      await _mount(tester, day, now: DateTime(2026, 10, 6, 20, 15));
      final lights = _stage(tester).lights;
      expect(lights.evening, 1);
      expect(lights.sun, 0, reason: 'no sun, so no beams and no sun dust');
      expect(find.byKey(const Key('doorway-stage')), findsOneWidget);
    });

    testWidgets('after midnight it is still the evening, until dawn', (
      tester,
    ) async {
      final day = _doorway(_fall2026, _state(), _ny(10, 7, 2, 30));
      // The phone's own 02:30 (the light reads local time).
      await _mount(tester, day, now: DateTime(2026, 10, 7, 2, 30));
      expect(_stage(tester).lights.evening, 1);
    });
  });

  group('Reduce Motion', () {
    testWidgets('the ambient motion never starts', (tester) async {
      final day = _doorway(_fall2026, _state(), _ny(10, 6, 12, 51));
      await _mount(tester, day, reduceMotion: true);
      expect(_stage(tester).animating, isFalse);
      await tester.pump(const Duration(seconds: 3));
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'nothing breathes, drifts or follows tilt',
      );
      expect(_stage(tester).tilt, Offset.zero);
    });

    testWidgets('tilt is ignored', (tester) async {
      final tilt = ValueNotifier(const Offset(1, 1));
      addTearDown(tilt.dispose);
      final day = _doorway(_fall2026, _state(), _ny(10, 6, 12, 51));
      await _mount(tester, day, reduceMotion: true, parallax: tilt);
      await tester.pump(const Duration(seconds: 1));
      expect(_stage(tester).tilt, Offset.zero);
    });

    testWidgets('a ticket changes place at once, without a glide', (
      tester,
    ) async {
      final schedule = _friday(List.filled(5, 'lecture'));
      final state = _state();
      var day = _doorway(schedule, state, _fri(7, 0));
      await _mount(tester, day, reduceMotion: true);
      final all = day.tickets;
      state.dismissClass(all[0].facts);
      day = _doorway(schedule, state, _fri(7, 0));
      await _mount(tester, day, reduceMotion: true);
      await tester.pump(const Duration(milliseconds: 20));
      expect(_stage(tester).placedTickets.first.ticket.id, all[1].id);
      expect(find.byType(DoorwayTicketView), findsNWidgets(3));
    });

    testWidgets('motion on: it breathes and follows the tilt', (tester) async {
      final tilt = ValueNotifier(const Offset(1, 0));
      addTearDown(tilt.dispose);
      final day = _doorway(_fall2026, _state(), _ny(10, 6, 12, 51));
      await _mount(tester, day, parallax: tilt);
      expect(_stage(tester).animating, isTrue);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(_stage(tester).tilt.dx, greaterThan(0.6));
      // Back to rest: nothing stays scheduled once the stage is gone.
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  });

  group('the art', () {
    test('every plate the stage asks for is bundled', () {
      expect(DoorwayAssets.all, hasLength(greaterThan(15)));
      expect(DoorwayAssets.all.toSet(), hasLength(DoorwayAssets.all.length));
    });
  });
}
