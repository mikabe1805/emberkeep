// The Doorway's moves: a class marked lifts out of its holder, turns over,
// takes its stamp and hangs on its hook with a swing; the air and the light
// answer; a completed day's tickets drop into the bowl; a week's bundle rises
// to the shelf; Reduce Motion fades all of it.
//
// The poses are pure functions of time (doorway_motion.dart), so they are
// tested as numbers. The stage is tested by what it draws and what it tells
// the hand and the ear at the moments the prototype fixed (the lift at 60 ms,
// the stamp at 420 ms, the hang at 900 ms, the swing's end near 1.8 s, the
// drop 1.9 s after the mark, the day's card half a second after the tickets
// land).
//
// Instants only (New York wall times converted from UTC), so this holds on a
// host in any zone.
import 'dart:math' as math;

import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/widgets/class_day/doorway_art.dart';
import 'package:emberkeep/widgets/class_day/doorway_cues.dart';
import 'package:emberkeep/widgets/class_day/doorway_model.dart';
import 'package:emberkeep/widgets/class_day/doorway_motion.dart';
import 'package:emberkeep/widgets/class_day/doorway_rail.dart';
import 'package:emberkeep/widgets/class_day/doorway_stage.dart';
import 'package:emberkeep/widgets/class_day/doorway_tickets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

DoorwayDay _read(GameState state, DateTime at) {
  Clock.freeze(at);
  return DoorwayDay.read(_fall2026, state, at);
}

/// Keeps [ticket]'s class at [at] through the engine, as the room's bar does.
void _keep(GameState state, DoorwayDay day, DoorwayTicket ticket, DateTime at) {
  Clock.freeze(at);
  state.keepClass(
    ticket.facts,
    dayClassKeys: [for (final t in day.tickets) t.facts.identity],
  );
}

class _Cues extends DoorwayCues {
  final log = <String>[];
  @override
  void lift() => log.add('lift');
  @override
  void stamp() => log.add('stamp');
  @override
  void hang() => log.add('hang');
  @override
  void bowl() => log.add('bowl');
  @override
  void shelf() => log.add('shelf');
  @override
  void slip() => log.add('slip');
}

/// A stage whose day the test swaps, with its cues and beats recorded.
class _Scene {
  _Scene(DoorwayDay day, {this.reduceMotion = false})
    : days = ValueNotifier(day);

  final ValueNotifier<DoorwayDay> days;
  final bool reduceMotion;
  final cues = _Cues();
  final beats = <(DoorwayBeat, double)>[];
  final marked = <String>[];
  final key = GlobalKey<DoorwayStageState>();

  DoorwayStageState get stage => key.currentState!;

  Future<void> mount(WidgetTester tester) async {
    addTearDown(days.dispose);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SizedBox(
            width: 393,
            height: 852,
            child: ValueListenableBuilder<DoorwayDay>(
              valueListenable: days,
              builder: (context, day, _) => DoorwayStage(
                key: key,
                day: day,
                reduceMotion: reduceMotion,
                cues: cues,
                onBeat: (beat) => beats.add((beat, stage.clockMs)),
                onMarkTicket: (ticket) => marked.add(ticket.id),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Swaps the day and lets the stage see it.
  Future<void> show(WidgetTester tester, DoorwayDay day) async {
    days.value = day;
    await tester.pump();
  }

  List<DoorwayBeat> get told => [for (final (beat, _) in beats) beat];
}

/// Pumps [ms] in 20 ms frames, so cues land close to their times.
Future<void> _run(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 20) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Finder _wall(DoorwayTicket t) =>
    find.byKey(ValueKey('doorway-moving-${t.id}-wall'));
Finder _railGhost(DoorwayTicket t) =>
    find.byKey(ValueKey('doorway-moving-${t.id}-rail'));
Finder _inRail(DoorwayTicket t) => find.byWidgetPredicate(
  (w) => w is DoorwayTicketView && w.ticket.id == t.id && w.inRail,
);
Finder _hung(DoorwayTicket t) => find.byKey(ValueKey('doorway-hung-${t.id}'));

/// The face the moving ticket shows.
bool _showsAttended(WidgetTester tester, DoorwayTicket t) {
  final view = tester.widget<DoorwayTicketView>(
    find.descendant(of: _wall(t), matching: find.byType(DoorwayTicketView)),
  );
  return view.attended ?? false;
}

void main() {
  setUp(() => GameState.debugRandomFactory = _NoLuck.new);
  tearDown(() {
    Clock.reset();
    GameState.debugRandomFactory = null;
  });

  group('the motion, as numbers', () {
    final hang = doorwayHangFor(2);
    const from = Offset(322, 262);

    DoorwayPose mark(double ms, {double drag = 0}) =>
        doorwayMarkPose(ms, hang, from: from, dragOff: drag);

    test('it unclips at 0, lifts from the lip and turns over', () {
      final start = mark(0);
      expect(start.center, from);
      expect(start.attended, isFalse);
      expect(start.flip, 0);
      final lifted = mark(60);
      expect(lifted.center.dy, lessThan(from.dy - 1.9));
      expect(lifted.degrees, closeTo(-3, 1e-9));
      final risen = mark(200);
      expect(risen.center.dy, lessThan(from.dy - 6));
      expect(risen.scale, greaterThan(1.02));
    });

    test(
      'the face swaps to the attended one at the half turn (90 degrees)',
      () {
        expect(mark(100).flip, 0, reason: 'the turn begins at 100 ms');
        final before = mark(239.9);
        expect(before.attended, isFalse);
        expect(before.flip, closeTo(90, 0.2));
        final after = mark(240.1);
        expect(after.attended, isTrue);
        expect(after.flip, closeTo(-90, 0.2));
        expect(
          mark(380).flip,
          closeTo(0, 1e-9),
          reason: 'the turn lasts 280 ms',
        );
      },
    );

    test('the stamp presses in from 420 ms over a patch of paper', () {
      expect(mark(419).stamp, 0);
      expect(mark(510).stamp, closeTo(0.5, 1e-9));
      expect(mark(600).stamp, 1);
      expect(mark(500).patch, isTrue);
      expect(mark(600).patch, isFalse, reason: 'the painted check shows');
    });

    test(
      'it arcs to its hook by 900 ms and its strings grow from the hooks',
      () {
        final hung = _hangCenter(hang);
        expect((mark(900).center - hung).distance, lessThan(1e-6));
        expect(mark(900).degrees, closeTo(hang.rest, 1e-9));
        // Midway it is above the straight line: an arc, not a slide.
        final mid = mark(660);
        final straightY =
            from.dy - 10 + (hung.dy - (from.dy - 10)) * 0.5; // eased half way
        expect(mid.center.dy, lessThan(straightY + 0.5));
        expect(mark(470).grow, 0);
        expect(mark(800).grow, 1);
        expect(mark(900).follow, 1);
        // The strings start at the hooks and are straight down at first.
        final strings = doorwayStringsFor(hang, mark(700));
        expect(strings, hasLength(2));
        for (final (hook, end) in strings) {
          expect(hook.dy, doorwayHookY);
          expect(end.dy, greaterThan(hook.dy));
        }
        expect(doorwayStringsFor(hang, mark(300)), isEmpty);
      },
    );

    test('a drag keeps the lift it had, then lets it go', () {
      expect(mark(0, drag: -16).center.dy, closeTo(from.dy - 16, 1e-9));
      expect(
        mark(400, drag: -16).center.dy,
        closeTo(mark(400).center.dy, 0.05),
      );
    });

    test('the pendulum swings about 9 degrees and settles by about 1.8 s', () {
      var peak = 0.0;
      for (var t = 0.0; t < 1900; t += 5) {
        peak = math.max(peak, doorwaySwing(t).abs());
      }
      expect(peak, inInclusiveRange(7, 11));
      expect(doorwaySwing(1800).abs(), lessThan(0.8));
      expect(doorwaySwing(1900 + 2000).abs(), lessThan(0.1));
      expect(doorwaySwing(-10), 0);
      final settled = doorwayHungPose(hang);
      expect(settled.degrees, closeTo(hang.rest, 1e-6));
    });

    test('the air opens at 100 ms, peaks near 400 and is gone by 700', () {
      expect(doorwayAirAt(50, 0), 0);
      expect(doorwayAirAt(400, 0), closeTo(1, 1e-9));
      expect(doorwayAirAt(700, 0), closeTo(0, 1e-9));
      expect(doorwayAirAt(900, 0), 0);
      expect(doorwayGust(0), 0);
      expect(doorwayGust(300), greaterThan(0.5));
      expect(doorwayGust(3500), 0);
    });

    test('the drop lands exactly on its place in the bowl', () {
      for (final index in [0, 1, 2]) {
        final land = doorwayDropPose(
          doorwayDropMs,
          index,
          1,
          from: const Offset(327, 225),
          fromDegrees: -2.5,
        );
        final (slot, degrees) = doorwayBowlSlot(1, index == 0 ? 0 : 1);
        expect((land.center - slot).distance, lessThan(1e-6));
        expect(land.degrees, closeTo(degrees, 1e-6));
        expect(land.scale, closeTo(doorwayBowlScale, 1e-6));
        expect(land.mini, 1);
      }
      // The second one wears the clip; the first does not.
      expect(
        doorwayDropPose(500, 1, 0, from: Offset.zero, fromDegrees: 0).clipped,
        isTrue,
      );
      expect(
        doorwayDropPose(500, 0, 0, from: Offset.zero, fromDegrees: 0).clipped,
        isFalse,
      );
    });

    test('the bundle rises from the bowl to the shelf and settles softly', () {
      const target = Offset(366, 150);
      final start = doorwayBundlePose(0, target);
      expect(start.opacity, 0);
      expect(start.scale, closeTo(0.8, 1e-9));
      final end = doorwayBundlePose(doorwayBundleMs, target);
      expect(end.center, target);
      expect(end.landed, isTrue);
      expect(doorwayBundleSettle(0), 0);
      expect(doorwayBundleSettle(60), greaterThan(0.2));
      expect(doorwayBundleSettle(420), 0);
    });

    test('Reduce Motion: no turn, no arc, no swing, no flight: fades', () {
      final a = doorwayMarkPose(130, hang, from: from, reduce: true);
      expect(a.flip, 0);
      expect(a.opacity, closeTo(0.5, 1e-9));
      expect(a.center, _hangCenter(hang), reason: 'it is at its hook');
      expect(doorwayMarkGhost(130), closeTo(0.5, 1e-9));
      expect(
        doorwayHungPose(hang, sinceHung: 100).degrees != hang.rest,
        isTrue,
      );
      final d = doorwayDropPose(
        130,
        0,
        0,
        from: const Offset(327, 225),
        fromDegrees: 2,
        reduce: true,
      );
      expect(d.center, const Offset(327, 225));
      expect(d.opacity, closeTo(0.5, 1e-9));
      expect(doorwayDropAppear(130, 0, 0).opacity, closeTo(0.5, 1e-9));
      final b = doorwayBundlePose(130, const Offset(366, 150), reduce: true);
      expect(b.center, const Offset(366, 150));
      expect(b.opacity, closeTo(0.5, 1e-9));
    });
  });

  group('one class: the mark in the scene', () {
    late GameState state;
    late DoorwayDay before;
    late DoorwayDay after;
    late DoorwayTicket arch;

    setUp(() {
      state = _state();
      before = _read(state, _ny(10, 6, 12, 51));
      arch = before.tickets.first;
      _keep(state, before, arch, _ny(10, 6, 12, 51));
      after = _read(state, _ny(10, 6, 12, 51));
    });

    testWidgets('lift, turn, stamp, hang and swing, at the prototype times', (
      tester,
    ) async {
      final scene = _Scene(before);
      await scene.mount(tester);
      expect(_inRail(arch), findsOneWidget);
      expect(scene.stage.markingIds, isEmpty);

      await scene.show(tester, after);
      final t0 = scene.stage.clockMs;
      expect(scene.stage.markingIds, [arch.id]);
      expect(scene.stage.moving, isTrue);
      expect(_wall(arch), findsOneWidget, reason: 'it is drawn by the move');
      expect(_inRail(arch), findsNothing, reason: 'and has left its holder');
      expect(_hung(arch), findsNothing);

      // 0 to 60 ms: unclipping; no cue yet.
      await _run(tester, 40);
      expect(scene.cues.log, isEmpty);
      expect(_showsAttended(tester, arch), isFalse);
      // 60 ms: the lift (a light tap and a paper sound).
      await _run(tester, 40);
      expect(scene.cues.log, ['lift']);
      // 120 ms: turning, still its blank face.
      await _run(tester, 40);
      expect(scene.stage.clockMs - t0, closeTo(120, 25));
      final turning = tester.widget<Transform>(
        find
            .descendant(of: _wall(arch), matching: find.byType(Transform))
            .first,
      );
      expect(turning.transform.storage.every((v) => v.isFinite), isTrue);
      // 300 ms: over, the attended face (the swap was at 240).
      await _run(tester, 180);
      expect(_showsAttended(tester, arch), isTrue);
      expect(scene.cues.log, ['lift']);
      // 420 ms: the stamp lands (a medium detent), and the ticket has left its
      // holder (the wall has not closed the gap before this).
      await _run(tester, 140);
      expect(scene.cues.log, ['lift', 'stamp']);
      expect(find.byKey(const Key('doorway-stamp')), findsOneWidget);
      // 700 ms: on its way to the hook, strings growing from it.
      await _run(tester, 280);
      expect(scene.stage.clockMs - t0, closeTo(700, 30));
      expect(find.byKey(const Key('doorway-moving-strings')), findsOneWidget);
      expect(scene.cues.log, ['lift', 'stamp']);
      expect(scene.told, isEmpty);
      // 900 ms: on its hook.
      await _run(tester, 220);
      expect(scene.cues.log, ['lift', 'stamp', 'hang']);
      expect(scene.told, [DoorwayBeat.hung]);
      // 1200 ms: swinging (off its resting angle).
      await _run(tester, 280);
      expect(scene.stage.markingIds, [arch.id]);
      // 2000 ms: the swing has settled (told at about 1.9 s).
      await _run(tester, 800);
      expect(scene.told, [DoorwayBeat.hung, DoorwayBeat.settled]);
      // After the swing the plain hung ticket takes over, seamlessly.
      await _run(tester, 1000);
      expect(scene.stage.markingIds, isEmpty);
      expect(_hung(arch), findsOneWidget);
      expect(_wall(arch), findsNothing);
      expect(scene.stage.moving, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the air and the light answer once, then return', (
      tester,
    ) async {
      final scene = _Scene(before);
      await scene.mount(tester);
      expect(scene.stage.air, 0);
      await scene.show(tester, after);
      final t0 = scene.stage.clockMs;
      var peak = 0.0;
      var warmPeak = 0.0;
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (scene.stage.clockMs - t0 < 90) expect(scene.stage.air, 0);
        peak = math.max(peak, scene.stage.air);
        warmPeak = math.max(warmPeak, scene.stage.warm);
      }
      expect(peak, greaterThan(0.9), reason: 'the glass and beams brighten');
      expect(warmPeak, 0, reason: 'a single class does not warm the beam');
      await _run(tester, 400);
      expect(scene.stage.air, 0, reason: 'and it returns, within 700 ms');
    });

    testWidgets('the wall closes the gap only after the ticket has lifted '
        'out (420 ms)', (tester) async {
      final schedule = _friday(5);
      final state = _state();
      final day0 = _fridayDay(schedule, state, 7, 0);
      final scene = _Scene(day0);
      await scene.mount(tester);
      expect(scene.stage.placedTickets, hasLength(3));
      final first = day0.tickets.first;
      Clock.freeze(_fri(8, 55));
      state.keepClass(
        first.facts,
        dayClassKeys: [for (final t in day0.tickets) t.facts.identity],
      );
      final day1 = _fridayDay(schedule, state, 8, 55);
      await scene.show(tester, day1);
      await _run(tester, 300);
      expect(
        scene.stage.placedTickets.map((p) => p.ticket.id),
        contains(first.id),
        reason: 'the holders have not moved yet',
      );
      await _run(tester, 300);
      expect(
        scene.stage.placedTickets.map((p) => p.ticket.id),
        isNot(contains(first.id)),
      );
      // The queued ticket clips in from behind the lip a little later still,
      // and the whole chain has settled within about 1.5 s of the mark.
      await _run(tester, 2400);
      expect(scene.stage.placedTickets, hasLength(3));
      expect(scene.stage.markingIds, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('undo mid-sequence turns back into the holder', (tester) async {
      final scene = _Scene(before);
      await scene.mount(tester);
      await scene.show(tester, after);
      await _run(tester, 500);
      expect(scene.cues.log, ['lift', 'stamp']);
      // The save is restored: the class is waiting again.
      await scene.show(tester, before);
      expect(scene.stage.markingIds, [arch.id]);
      expect(_wall(arch), findsOneWidget);
      await _run(tester, 400);
      expect(scene.stage.markingIds, [arch.id], reason: 'still on its way');
      expect(_inRail(arch), findsNothing, reason: 'not in the holder yet');
      await _run(tester, 700);
      expect(scene.stage.markingIds, isEmpty);
      expect(_inRail(arch), findsOneWidget, reason: 'back in its holder');
      expect(_hung(arch), findsNothing);
      expect(_wall(arch), findsNothing);
      expect(
        scene.stage.placedTickets.map((p) => p.ticket.id),
        contains(arch.id),
      );
      expect(scene.stage.moving, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('undo after it hung brings it back down the same way', (
      tester,
    ) async {
      final scene = _Scene(before);
      await scene.mount(tester);
      await scene.show(tester, after);
      await _run(tester, 3200);
      expect(_hung(arch), findsOneWidget);
      await scene.show(tester, before);
      expect(scene.stage.markingIds, [arch.id]);
      expect(_hung(arch), findsNothing, reason: 'drawn by the move now');
      await _run(tester, 1100);
      expect(scene.stage.markingIds, isEmpty);
      expect(_inRail(arch), findsOneWidget);
    });

    testWidgets('dragging a waiting ticket up past 24 pt marks its class', (
      tester,
    ) async {
      final scene = _Scene(before);
      await scene.mount(tester);
      final waiting = scene.stage.placedTickets.firstWhere(
        (p) => p.ticket.markable,
      );
      final canvas = tester.getRect(find.byKey(const Key('doorway-canvas')));
      final unit = canvas.width / 393;
      final from = canvas.topLeft + waiting.center * unit;
      final ticketView = find.byKey(
        ValueKey('doorway-ticket-${waiting.ticket.id}'),
      );
      final rest = tester.getRect(ticketView);
      // Short of the line: it follows the finger and settles back.
      final short = await tester.startGesture(from);
      await short.moveBy(Offset(0, -12 * unit));
      await tester.pump(const Duration(milliseconds: 16));
      expect(scene.marked, isEmpty);
      final lifted = tester.getRect(ticketView);
      expect(lifted.center.dy, lessThan(rest.center.dy - 3 * unit));
      await short.up();
      await _run(tester, 600);
      expect(
        tester.getRect(ticketView).center.dy,
        closeTo(rest.center.dy, 0.5),
        reason: 'and it settles back where it was',
      );
      // Past it: the room is told once.
      final long = await tester.startGesture(from);
      await long.moveBy(Offset(0, -20 * unit));
      await long.moveBy(Offset(0, -12 * unit));
      await tester.pump(const Duration(milliseconds: 16));
      expect(scene.marked, [waiting.ticket.id]);
      await long.moveBy(Offset(0, -10 * unit));
      await long.up();
      await tester.pump();
      expect(scene.marked, hasLength(1), reason: 'only once');
    });

    testWidgets('a ticket marked by a drag starts its move from the lift the '
        'finger gave it', (tester) async {
      final scene = _Scene(before);
      await scene.mount(tester);
      final waiting = scene.stage.placedTickets.firstWhere(
        (p) => p.ticket.markable,
      );
      final canvas = tester.getRect(find.byKey(const Key('doorway-canvas')));
      final unit = canvas.width / 393;
      final from = canvas.topLeft + waiting.center * unit;
      final restY = tester
          .getRect(find.byKey(ValueKey('doorway-ticket-${waiting.ticket.id}')))
          .center
          .dy;
      final finger = await tester.startGesture(from);
      await finger.moveBy(Offset(0, -34 * unit));
      await tester.pump(const Duration(milliseconds: 16));
      expect(scene.marked, [waiting.ticket.id]);
      // The room marks the class; the move begins where the drag left it:
      // about 14 points above its holder (40% of a 34 point pull), not at
      // the holder.
      await scene.show(tester, after);
      await tester.pump(const Duration(milliseconds: 16));
      final startY = tester.getRect(_wall(arch)).center.dy;
      expect(startY, lessThan(restY - 10 * unit));
      expect(startY, greaterThan(restY - 20 * unit));
      await finger.up();
      await _run(tester, 3200);
      expect(_hung(arch), findsOneWidget);
    });
  });

  group('the day: tickets into the bowl, then the day', () {
    late GameState state;
    late DoorwayDay one;
    late DoorwayDay both;
    late DoorwayTicket arch;
    late DoorwayTicket disc;

    setUp(() {
      state = _state();
      final start = _read(state, _ny(10, 6, 15, 35));
      arch = start.tickets[0];
      disc = start.tickets[1];
      _keep(state, start, arch, _ny(10, 6, 11, 53));
      one = _read(state, _ny(10, 6, 15, 35));
      _keep(state, start, disc, _ny(10, 6, 15, 36));
      both = _read(state, _ny(10, 6, 15, 36));
    });

    testWidgets('the last class hangs, then both unhook, clip and drop into '
        'the bowl; only then is the day told', (tester) async {
      final scene = _Scene(one);
      await scene.mount(tester);
      expect(scene.stage.bowlShown, 0);
      expect(_hung(arch), findsOneWidget);
      await scene.show(tester, both);
      final t0 = scene.stage.clockMs;
      expect(both.bowlPairs, contains(both.date));
      // The hooks hold the day's tickets (nothing has dropped yet), and the
      // bowl is as it was.
      expect(_hung(arch), findsOneWidget);
      expect(scene.stage.bowlShown, 0);
      await _run(tester, 1000);
      expect(scene.told, [DoorwayBeat.hung]);
      expect(scene.stage.dropping, isFalse);
      // 1.9 s after the mark: both unhook, together.
      await _run(tester, 1000);
      expect(scene.stage.clockMs - t0, closeTo(2000, 40));
      expect(scene.stage.dropping, isTrue);
      expect(_hung(arch), findsNothing);
      expect(_wall(arch), findsOneWidget);
      expect(_wall(disc), findsOneWidget);
      expect(scene.stage.warm, greaterThan(0), reason: 'the beam warms');
      // Mid-flight: the day is not told, the bowl has not taken them.
      await _run(tester, 500);
      expect(scene.told, [DoorwayBeat.hung, DoorwayBeat.settled]);
      expect(scene.cues.log, isNot(contains('bowl')));
      // Landed (about 2.8 s): the bowl holds the day's pair, the cue sounds.
      await _run(tester, 500);
      expect(scene.stage.dropping, isFalse);
      expect(scene.cues.log, contains('bowl'));
      expect(scene.stage.bowlShown, 1);
      expect(find.byKey(const ValueKey('doorway-bowl-0-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('doorway-bowl-0-1')), findsOneWidget);
      expect(scene.told, isNot(contains(DoorwayBeat.dayDone)));
      // Half a second after they land, the day may show.
      await _run(tester, 600);
      expect(scene.told.last, DoorwayBeat.dayDone);
      final (_, at) = scene.beats.last;
      expect(at - t0, closeTo(3300, 80));
      expect(scene.told.where((b) => b == DoorwayBeat.weekDone), isEmpty);
      expect(scene.stage.moving, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the flight is inside the bowl clip once it sinks below the '
        'rim, and the first ticket goes behind', (tester) async {
      final scene = _Scene(one);
      await scene.mount(tester);
      await scene.show(tester, both);
      await _run(tester, 1900 + 700);
      expect(find.byKey(const Key('doorway-bowl-flight')), findsOneWidget);
      await _run(tester, 400);
      expect(find.byKey(const Key('doorway-bowl-flight')), findsNothing);
    });

    testWidgets('undone before the drop, the day does not drop', (
      tester,
    ) async {
      final scene = _Scene(one);
      await scene.mount(tester);
      await scene.show(tester, both);
      await _run(tester, 1200);
      await scene.show(tester, one);
      await _run(tester, 4000);
      expect(scene.stage.dropping, isFalse);
      expect(scene.stage.bowlShown, 0);
      expect(scene.told, isNot(contains(DoorwayBeat.dayDone)));
      expect(_hung(arch), findsOneWidget);
      expect(_inRail(disc), findsOneWidget);
    });

    testWidgets('a day completed by setting a class aside drops its tickets '
        'too, with no mark', (tester) async {
      final state = _state();
      final start = _read(state, _ny(10, 6, 15, 35));
      _keep(state, start, start.tickets[0], _ny(10, 6, 11, 53));
      final waiting = _read(state, _ny(10, 6, 15, 35));
      final scene = _Scene(waiting);
      await scene.mount(tester);
      state.dismissClass(waiting.tickets[1].facts);
      final done = _read(state, _ny(10, 6, 15, 35));
      expect(done.bowlPairs, contains(done.date));
      await scene.show(tester, done);
      await _run(tester, 4000);
      expect(scene.stage.bowlShown, 1);
      expect(scene.cues.log, contains('bowl'));
    });
  });

  group('the week: the bundle rises to the shelf', () {
    late DoorwayDay one;
    late DoorwayDay both;

    setUp(() {
      final state = _state();
      final start = _read(state, _ny(10, 9, 18, 56));
      _keep(state, start, start.tickets[0], _ny(10, 9, 11, 45));
      one = _read(state, _ny(10, 9, 18, 56));
      _keep(state, start, start.tickets[1], _ny(10, 9, 18, 57));
      both = _read(state, _ny(10, 9, 18, 57));
    });

    test("Friday's last class is the week's: tied, the bowl empty", () {
      expect(one.weekTied, isFalse);
      expect(both.weekTied, isTrue);
      expect(both.bowlCount, 0);
      expect(both.shelfCount, one.shelfCount + 1);
      expect(
        both.shelfLabel,
        contains('${one.shelfCount + 1} WEEK'),
        reason: 'the shelf counts the week it just tied',
      );
    });

    testWidgets('after the day, the bundle rises, settles, and then the week '
        'is told', (tester) async {
      final scene = _Scene(one);
      await scene.mount(tester);
      await scene.show(tester, both);
      final t0 = scene.stage.clockMs;
      // The day's beat does not come on the week's last day: the week's does.
      await _run(tester, 3000);
      expect(scene.stage.bowlShown, 1, reason: 'the tickets are in the bowl');
      expect(scene.stage.shelfShown, 0);
      expect(scene.told, isNot(contains(DoorwayBeat.dayDone)));
      await _run(tester, 900);
      expect(scene.stage.tying, isTrue, reason: 'the bundle is rising');
      expect(
        find.byKey(const ValueKey('doorway-bundle-flight')),
        findsOneWidget,
      );
      expect(scene.cues.log, isNot(contains('shelf')));
      // Landed on the shelf (about 4.3 s): a soft wooden settle.
      await _run(tester, 600);
      expect(scene.cues.log, contains('shelf'));
      expect(scene.told, isNot(contains(DoorwayBeat.weekDone)));
      // Then the week (about 1.1 s later).
      await _run(tester, 1400);
      expect(scene.told.last, DoorwayBeat.weekDone);
      final (_, at) = scene.beats.last;
      expect(at - t0, closeTo(5400, 120));
      await _run(tester, 600);
      expect(scene.stage.tying, isFalse);
      expect(scene.stage.bowlShown, 0, reason: 'the bowl is empty');
      expect(scene.stage.shelfShown, 1);
      expect(find.byKey(const ValueKey('doorway-bundle-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('doorway-bowl-0-0')), findsNothing);
      expect(find.text('FALL TERM · 1 WEEK'), findsOneWidget);
      expect(scene.stage.moving, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('Reduce Motion: fades, no flip, no swing', () {
    late GameState state;
    late DoorwayDay before;
    late DoorwayDay after;
    late DoorwayTicket arch;

    setUp(() {
      state = _state();
      before = _read(state, _ny(10, 6, 12, 51));
      arch = before.tickets.first;
      _keep(state, before, arch, _ny(10, 6, 12, 51));
      after = _read(state, _ny(10, 6, 12, 51));
    });

    testWidgets('the ticket in the holder fades as the one on the hook fades '
        'in', (tester) async {
      final scene = _Scene(before, reduceMotion: true);
      await scene.mount(tester);
      expect(scene.stage.animating, isFalse);
      await scene.show(tester, after);
      await _run(tester, 120);
      expect(_wall(arch), findsOneWidget);
      expect(_railGhost(arch), findsOneWidget);
      double opacityOf(Finder f) => tester
          .widget<Opacity>(
            find.descendant(of: f, matching: find.byType(Opacity)).first,
          )
          .opacity;
      expect(opacityOf(_wall(arch)), inExclusiveRange(0.2, 0.8));
      expect(opacityOf(_railGhost(arch)), inExclusiveRange(0.2, 0.8));
      // No turn: no perspective transform anywhere on the ticket.
      for (final t in tester.widgetList<Transform>(
        find.descendant(of: _wall(arch), matching: find.byType(Transform)),
      )) {
        expect(t.transform.storage[11], 0, reason: 'no perspective');
      }
      // The air does not move either.
      expect(scene.stage.air, 0);
      // Done in about a quarter second, and the ticker has gone quiet.
      await _run(tester, 700);
      expect(scene.stage.markingIds, isEmpty);
      expect(_hung(arch), findsOneWidget);
      expect(scene.stage.animating, isFalse);
      expect(scene.cues.log, ['lift', 'stamp', 'hang']);
      expect(scene.told, [DoorwayBeat.hung, DoorwayBeat.settled]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the day and the week are fades too, and come sooner', (
      tester,
    ) async {
      final state = _state();
      final start = _read(state, _ny(10, 9, 18, 56));
      _keep(state, start, start.tickets[0], _ny(10, 9, 11, 45));
      final one = _read(state, _ny(10, 9, 18, 56));
      _keep(state, start, start.tickets[1], _ny(10, 9, 18, 57));
      final both = _read(state, _ny(10, 9, 18, 57));
      final scene = _Scene(one, reduceMotion: true);
      await scene.mount(tester);
      await scene.show(tester, both);
      await _run(tester, 3000);
      expect(scene.told, [
        DoorwayBeat.hung,
        DoorwayBeat.settled,
        DoorwayBeat.weekDone,
      ]);
      expect(scene.cues.log, containsAll(['bowl', 'shelf']));
      expect(scene.stage.bowlShown, 0);
      expect(scene.stage.shelfShown, 1);
      expect(scene.stage.animating, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('the hand and the ear', () {
    testWidgets('the real cues: a light tap as it lifts, a medium detent as '
        'the stamp lands', (tester) async {
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add('${call.arguments}');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final state = _state();
      final before = _read(state, _ny(10, 6, 12, 51));
      _keep(state, before, before.tickets.first, _ny(10, 6, 12, 51));
      final after = _read(state, _ny(10, 6, 12, 51));
      final days = ValueNotifier(before);
      addTearDown(days.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 393,
              height: 852,
              child: ValueListenableBuilder<DoorwayDay>(
                valueListenable: days,
                builder: (context, day, _) => DoorwayStage(day: day),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      days.value = after;
      await tester.pump();
      await _run(tester, 40);
      expect(haptics, isEmpty);
      await _run(tester, 60);
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      await _run(tester, 300);
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      await _run(tester, 60);
      expect(haptics, [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
      ]);
      await _run(tester, 3000);
      expect(haptics, hasLength(2), reason: 'nothing else taps');
    });
  });
}

Offset _hangCenter(DoorwayHang hang) =>
    doorwayHangCenter(hang, hang.rest, doorwayTicketHeight);

// A Friday of [n] lectures, as the stage tests use.
AcademicSchedule _friday(int n) =>
    crowdedFridaySchedule(List.filled(n, 'lecture'));

DateTime _fri(int hour, int minute) => _ny(10, 9, hour, minute);

DoorwayDay _fridayDay(
  AcademicSchedule schedule,
  GameState state,
  int hour,
  int minute,
) {
  Clock.freeze(_fri(hour, minute));
  return DoorwayDay.read(schedule, state, _fri(hour, minute));
}
