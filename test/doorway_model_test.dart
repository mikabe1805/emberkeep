// The Doorway's data: tickets by the front door, the hooks, the bowl, the
// shelf and the rail tier, from his real Fall 2026 timetable and from made-up
// days of any size. Instants only (New York wall times converted from UTC), so
// this holds on a host in any zone.
import 'dart:math' as math;

import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/widgets/class_day/doorway_model.dart';
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

DoorwayDay _doorway(
  AcademicSchedule schedule,
  GameState state,
  DateTime at, {
  CivilDate? day,
}) {
  Clock.freeze(at);
  return DoorwayDay.read(schedule, state, at, day: day);
}

void main() {
  tearDown(Clock.reset);

  group('the label on a small ticket', () {
    // His real course names, from the registrar's titles.
    const real = {
      'Electronics Devices': 'ELECTRONICS',
      'Electron Devices Lab': 'ELECTRON',
      'Computer Architecture & Assembly Language': 'ARCHITECTURE',
      'Computer Architecture Lab': 'ARCHITECTURE',
      'Linear Systems & Signals': 'LINEAR',
      'Introduction to Discrete Structures II': 'DISCRETE',
    };
    for (final MapEntry(key: title, value: label) in real.entries) {
      test(title, () => expect(doorwayTicketLabel(title), label));
    }

    test('every course in his timetable reads in twelve capitals or fewer', () {
      expect(_fall2026.courses, isNotEmpty);
      for (final course in _fall2026.courses) {
        final label = doorwayTicketLabel(course.title, courseCode: course.code);
        expect(
          label.length,
          lessThanOrEqualTo(doorwayLabelMax),
          reason: course.title,
        );
        expect(label, label.toUpperCase());
        expect(label, isNot(contains(RegExp(r'\s{2,}'))));
        expect(label.trim(), label);
        expect(real.containsKey(course.title), isTrue, reason: course.title);
        expect(label, real[course.title]);
      }
    });

    test('other names a student might add', () {
      expect(doorwayTicketLabel('Calculus II'), 'CALCULUS');
      expect(doorwayTicketLabel('Art History'), 'ART HISTORY');
      expect(doorwayTicketLabel('Data Structures'), 'STRUCTURES');
      expect(doorwayTicketLabel('Intro to Psychology'), 'PSYCHOLOGY');
      expect(doorwayTicketLabel('Organic Chemistry Lab'), 'ORGANIC');
      expect(doorwayTicketLabel('Physics: Mechanics'), 'PHYSICS');
      expect(doorwayTicketLabel('  spaced   out   title '), 'SPACED');
      expect(doorwayTicketLabel('Biology'), 'BIOLOGY');
    });

    test('never runs past the ticket, and never comes back empty', () {
      final long = doorwayTicketLabel('Electromagnetohydrodynamics');
      expect(long.length, doorwayLabelMax);
      expect(long, endsWith('…'));
      expect(doorwayTicketLabel('Lab'), 'LAB');
      expect(doorwayTicketLabel('II'), 'II');
      expect(doorwayTicketLabel('', courseCode: '14:332:361'), '14:332:361');
      expect(doorwayTicketLabel('   ', courseCode: ''), 'CLASS');
      expect(
        doorwayTicketLabel('Anything long', maxChars: 6).length,
        lessThanOrEqualTo(6),
      );
    });
  });

  group('the hooks', () {
    test('up to five tickets each take their own, spread across the five', () {
      expect(doorwayHooksFor(0), isEmpty);
      expect(doorwayHooksFor(1), [2]);
      expect(doorwayHooksFor(2), [1, 3]);
      expect(doorwayHooksFor(3), [0, 2, 4]);
      expect(doorwayHooksFor(4), [0, 1, 3, 4]);
      expect(doorwayHooksFor(5), [0, 1, 2, 3, 4]);
      for (var n = 1; n <= 5; n++) {
        expect(doorwayHooksFor(n).toSet(), hasLength(n), reason: '$n tickets');
      }
    });

    test('six and more share them by place, the same way every time', () {
      for (final n in [6, 7, 10, 11, 32]) {
        final hooks = doorwayHooksFor(n);
        expect(hooks, hasLength(n));
        expect(hooks, doorwayHooksFor(n));
        for (var i = 0; i < n; i++) {
          expect(hooks[i], i % doorwayHookCount);
          expect(hooks[i], inInclusiveRange(0, doorwayHookCount - 1));
        }
      }
    });
  });

  group('the rail tier', () {
    test('full to three, compact to five, a stack from six', () {
      expect(
        [for (var n = 0; n <= 8; n++) doorwayTierFor(n)],
        [
          DoorwayRailTier.full,
          DoorwayRailTier.full,
          DoorwayRailTier.full,
          DoorwayRailTier.full,
          DoorwayRailTier.compact,
          DoorwayRailTier.compact,
          DoorwayRailTier.stack,
          DoorwayRailTier.stack,
          DoorwayRailTier.stack,
        ],
      );
      expect(doorwayTierFor(32), DoorwayRailTier.stack);
      expect(doorwayTierFor(1000), DoorwayRailTier.stack);
    });
  });

  group('his real days', () {
    test('Thursday through its day: upcoming, in session, ready, attended', () {
      final state = _state();
      // Before anything: three tickets, none marked, none hung.
      var door = _doorway(_fall2026, state, _ny(10, 8, 7, 0));
      expect(door.tickets.map((t) => t.label), [
        'ELECTRONICS',
        'DISCRETE',
        'ELECTRON',
      ]);
      expect(door.tickets.map((t) => t.kind), [
        DoorwayKind.lecture,
        DoorwayKind.lecture,
        DoorwayKind.lab,
      ]);
      expect(
        door.tickets.map((t) => t.state),
        everyElement(DoorwayTicketState.upcoming),
      );
      expect(door.tickets.map((t) => t.hook), everyElement(isNull));
      expect(door.tickets.map((t) => t.startMinute), [
        8 * 60 + 30,
        14 * 60,
        15 * 60 + 50,
      ]);
      expect(door.tickets.first.room, 'SEC 111');
      expect(door.tickets.every((t) => t.counts), isTrue);
      expect(door.tier, DoorwayRailTier.full);
      expect(door.countingTickets, 3);

      door = _doorway(_fall2026, state, _ny(10, 8, 9, 0));
      expect(door.tickets.first.state, DoorwayTicketState.inSession);
      expect(door.tickets.first.markable, isTrue);
      expect(door.tickets.first.canSetAside, isFalse);

      door = _doorway(_fall2026, state, _ny(10, 8, 10, 30));
      expect(door.tickets.first.state, DoorwayTicketState.ready);
      expect(door.tickets.first.markable, isTrue);
      expect(door.tickets.first.canSetAside, isTrue);
      expect(door.tickets[1].canSetAside, isTrue);

      // Keep the first: it hangs on the hook the day gave it.
      expect(state.keepClass(door.tickets.first.facts), isNotNull);
      door = _doorway(_fall2026, state, _ny(10, 8, 10, 31));
      expect(door.tickets.first.state, DoorwayTicketState.attended);
      expect(door.tickets.first.hook, 0);
      expect(door.tickets.first.canSetAside, isFalse);
      expect(door.hung.keys, [0]);
    });

    test('a hook never moves when other classes are kept, in any order', () {
      final state = _state();
      final at = _ny(10, 8, 19, 5);
      Clock.freeze(at);
      final tickets = _doorway(_fall2026, state, at).tickets;
      // The last class first, then the first, then the middle one.
      final seen = <String, int?>{};
      for (final index in [2, 0, 1]) {
        state.keepClass(tickets[index].facts);
        final door = _doorway(_fall2026, state, at);
        final hung = {for (final t in door.tickets) t.id: t.hook};
        expect(hung[tickets[index].id], doorwayHooksFor(3)[index]);
        // Whatever hung earlier is where it was.
        for (final MapEntry(:key, :value) in seen.entries) {
          expect(hung[key], value, reason: key);
        }
        seen[tickets[index].id] = hung[tickets[index].id];
      }
      final done = _doorway(_fall2026, state, at);
      expect(done.tickets.map((t) => t.hook), [0, 2, 4]);
      expect(
        done.tickets.map((t) => t.state),
        everyElement(DoorwayTicketState.attended),
      );
    });

    test('a ticket that is set aside folds; undo puts it back unchanged', () {
      final state = _state();
      final at = _ny(10, 8, 13, 0);
      final before = _doorway(_fall2026, state, at);
      final lab = before.tickets.last;
      expect(lab.canSetAside, isTrue);

      expect(state.dismissClass(lab.facts), isTrue);
      final folded = _doorway(_fall2026, state, at);
      expect(
        folded.tickets,
        hasLength(3),
        reason: 'the ticket stays in the list',
      );
      expect(folded.tickets.last.state, DoorwayTicketState.dismissed);
      expect(folded.tickets.last.folded, isTrue);
      expect(folded.tickets.last.hook, isNull);
      expect(folded.visibleTickets, hasLength(2));
      expect(folded.countingTickets, 2);

      expect(state.undoDismiss(lab.facts), isTrue);
      final back = _doorway(_fall2026, state, at);
      expect(
        [
          for (final t in back.tickets)
            (t.id, t.state, t.hook, t.label, t.room),
        ],
        [
          for (final t in before.tickets)
            (t.id, t.state, t.hook, t.label, t.room),
        ],
      );
    });

    test(
      'a day with every class set aside leaves the rail empty of counts',
      () {
        final state = _state();
        final at = _ny(10, 6, 9, 0);
        Clock.freeze(at);
        for (final entry in projectClassDay(_fall2026, at).classes) {
          state.dismissClass(entry.facts);
        }
        final door = _doorway(_fall2026, state, at);
        expect(door.tickets.every((t) => t.folded), isTrue);
        expect(door.visibleTickets, isEmpty);
        expect(door.countingTickets, 0);
        expect(door.tier, DoorwayRailTier.full);
      },
    );

    test('a day with no classes yields no tickets', () {
      final state = _state();
      final door = _doorway(_fall2026, state, _ny(10, 10, 12, 0));
      expect(door.tickets, isEmpty);
      expect(door.visibleTickets, isEmpty);
      expect(door.hung, isEmpty);
      expect(door.countingTickets, 0);
      expect(door.tier, DoorwayRailTier.full);
      expect(door.bowlPairs, isEmpty);
    });

    test(
      'a schedule with nothing in it yields nothing, and does not throw',
      () {
        final state = _state();
        final door = _doorway(
          AcademicSchedule.empty(),
          state,
          _ny(10, 8, 12, 0),
        );
        expect(door.tickets, isEmpty);
        expect(door.bowlPairs, isEmpty);
        expect(door.shelfBundles, isEmpty);
      },
    );
  });

  group('the bowl: days this week that are all resolved', () {
    test(
      'a pair for a day whose counting classes are all kept or set aside',
      () {
        final state = _state();
        // Monday: all three kept.
        Clock.freeze(_ny(10, 5, 20, 0));
        for (final entry in projectClassDay(
          _fall2026,
          _ny(10, 5, 20, 0),
        ).classes) {
          state.keepClass(entry.facts);
        }
        // Tuesday: the morning lecture kept, the afternoon one set aside.
        Clock.freeze(_ny(10, 6, 12, 0));
        final tuesday = projectClassDay(_fall2026, _ny(10, 6, 12, 0)).classes;
        state.keepClass(tuesday.first.facts);
        state.dismissClass(tuesday.last.facts);
        // Wednesday: everything set aside (nothing attended: no pair).
        Clock.freeze(_ny(10, 7, 7, 0));
        for (final entry in projectClassDay(
          _fall2026,
          _ny(10, 7, 7, 0),
        ).classes) {
          state.dismissClass(entry.facts);
        }
        // Thursday: one kept, two still unresolved (no pair).
        Clock.freeze(_ny(10, 8, 10, 30));
        state.keepClass(
          projectClassDay(_fall2026, _ny(10, 8, 10, 30)).classes.first.facts,
        );

        final door = _doorway(_fall2026, state, _ny(10, 8, 10, 31));
        expect(door.bowlPairs, [
          CivilDate(2026, 10, 5),
          CivilDate(2026, 10, 6),
        ]);

        // Friday's two keep: the pair arrives with the last one.
        Clock.freeze(_ny(10, 9, 19, 30));
        for (final entry in projectClassDay(
          _fall2026,
          _ny(10, 9, 19, 30),
        ).classes) {
          state.keepClass(entry.facts);
        }
        final friday = _doorway(_fall2026, state, _ny(10, 9, 19, 31));
        expect(friday.bowlPairs.last, CivilDate(2026, 10, 9));
        expect(friday.bowlPairs, hasLength(3));
      },
    );

    test(
      'a class that ended unmarked keeps its day out of the bowl, quietly',
      () {
        final state = _state();
        Clock.freeze(_ny(10, 6, 12, 0));
        state.keepClass(
          projectClassDay(_fall2026, _ny(10, 6, 12, 0)).classes.first.facts,
        );
        // The next morning the afternoon class is long over and still unmarked.
        final door = _doorway(_fall2026, state, _ny(10, 7, 9, 0));
        expect(door.bowlPairs, isEmpty);
      },
    );

    test('a day with only an optional meeting kept is a pair too', () {
      final schedule = crowdedFridaySchedule(['office hours']);
      final state = _state();
      Clock.freeze(_ny(10, 9, 9, 30));
      final day = projectClassDay(schedule, _ny(10, 9, 9, 30));
      state.keepClass(day.classes.single.facts);
      final door = _doorway(schedule, state, _ny(10, 9, 9, 31));
      expect(door.bowlPairs, [CivilDate(2026, 10, 9)]);
      expect(door.tickets.single.kind, DoorwayKind.optional);
      expect(door.tickets.single.counts, isFalse);
      expect(door.countingTickets, 0);
      expect(door.tier, DoorwayRailTier.full);
    });
  });

  group('the shelf: past weeks of this term with a class attended', () {
    test('a bundle for each earlier week with at least one, oldest first', () {
      final state = _state();
      // Weeks of Sep 14 (two classes), Sep 21 (one) and Sep 28 (none).
      Clock.freeze(_ny(9, 15, 12, 0));
      for (final entry in projectClassDay(
        _fall2026,
        _ny(9, 15, 12, 0),
      ).classes.take(1)) {
        state.keepClass(entry.facts);
      }
      Clock.freeze(_ny(9, 17, 9, 30));
      state.keepClass(
        projectClassDay(_fall2026, _ny(9, 17, 9, 30)).classes.first.facts,
      );
      Clock.freeze(_ny(9, 22, 12, 0));
      state.keepClass(
        projectClassDay(_fall2026, _ny(9, 22, 12, 0)).classes.first.facts,
      );
      // This week: one attended, which is the bowl's business, not the shelf's.
      Clock.freeze(_ny(10, 6, 12, 0));
      state.keepClass(
        projectClassDay(_fall2026, _ny(10, 6, 12, 0)).classes.first.facts,
      );

      final door = _doorway(_fall2026, state, _ny(10, 8, 9, 0));
      expect(
        [for (final b in door.shelfBundles) (b.weekStart, b.attended)],
        [(CivilDate(2026, 9, 14), 2), (CivilDate(2026, 9, 21), 1)],
      );
      for (final bundle in door.shelfBundles) {
        expect(bundle.weekStart.weekday, DateTime.monday);
        expect(bundle.attended, greaterThanOrEqualTo(1));
      }
    });

    test('nothing on the shelf in the first week, or outside a term', () {
      final state = _state();
      expect(_doorway(_fall2026, state, _ny(9, 2, 9, 0)).shelfBundles, isEmpty);
      final summer = _doorway(
        _fall2026,
        state,
        _ny(10, 8, 9, 0),
        day: CivilDate(2027, 2, 1),
      );
      expect(summer.shelfBundles, isEmpty);
    });

    test('a set-aside class is no bundle, and counts nowhere', () {
      final state = _state();
      Clock.freeze(_ny(9, 15, 12, 0));
      for (final entry in projectClassDay(
        _fall2026,
        _ny(9, 15, 12, 0),
      ).classes) {
        state.dismissClass(entry.facts);
      }
      expect(
        _doorway(_fall2026, state, _ny(10, 8, 9, 0)).shelfBundles,
        isEmpty,
      );
    });
  });

  group('any number of events', () {
    const lecture = 'lecture';
    test('0 meetings (a Saturday in a term that has Fridays)', () {
      final door = _doorway(
        crowdedFridaySchedule(['lecture']),
        _state(),
        _ny(10, 10, 9, 0),
      );
      expect(door.tickets, isEmpty);
      expect(door.tier, DoorwayRailTier.full);
    });
    for (final n in [1, 2, 3, 4, 5, 6, 7, 9, 12, 20, 32]) {
      test('$n meetings', () {
        final schedule = crowdedFridaySchedule(List.filled(n, lecture));
        final state = _state();
        final door = _doorway(schedule, state, _ny(10, 9, 7, 0));
        expect(door.tickets, hasLength(n));
        expect(door.countingTickets, n);
        expect(door.tier, doorwayTierFor(n));
        expect(
          door.tier,
          n <= 3
              ? DoorwayRailTier.full
              : n <= 5
              ? DoorwayRailTier.compact
              : DoorwayRailTier.stack,
        );
        // In order, each with a label that fits and a room.
        final starts = door.tickets.map((t) => t.startMinute).toList();
        expect(starts, [...starts]..sort());
        for (final ticket in door.tickets) {
          expect(ticket.label.length, lessThanOrEqualTo(doorwayLabelMax));
          expect(ticket.room, isNotNull);
          expect(ticket.state, DoorwayTicketState.upcoming);
        }
        // Keep them all: every one hangs, on the hooks the count gave it.
        if (n > 0) {
          Clock.freeze(_ny(10, 9, 22, 0));
          for (final ticket in door.tickets) {
            expect(state.keepClass(ticket.facts), isNotNull, reason: ticket.id);
          }
          final done = _doorway(schedule, state, _ny(10, 9, 22, 1));
          expect(done.tickets.map((t) => t.hook), doorwayHooksFor(n));
          expect(done.hung.keys.length, math.min(n, doorwayHookCount));
          expect(
            done.hung.values.expand((tickets) => tickets),
            hasLength(n),
            reason: 'extras share a hook; none is lost',
          );
          expect(done.bowlPairs, [CivilDate(2026, 10, 9)]);
        }
      });
    }

    test('optional meetings ride the rail but do not set its tier', () {
      final schedule = crowdedFridaySchedule([
        'lecture',
        'lab',
        'recitation',
        'office hours',
        'office hours',
        'office hours',
      ]);
      final door = _doorway(schedule, _state(), _ny(10, 9, 7, 0));
      expect(door.tickets, hasLength(6));
      expect(door.tickets.map((t) => t.kind), [
        DoorwayKind.lecture,
        DoorwayKind.lab,
        DoorwayKind.recitation,
        DoorwayKind.optional,
        DoorwayKind.optional,
        DoorwayKind.optional,
      ]);
      expect(door.countingTickets, 3);
      expect(door.tier, DoorwayRailTier.full);
      expect(door.visibleTickets, hasLength(6));
    });

    test('a set-aside optional meeting just disappears', () {
      final schedule = crowdedFridaySchedule(['lecture', 'office hours']);
      final state = _state();
      final at = _ny(10, 9, 7, 0);
      final door = _doorway(schedule, state, at);
      final hours = door.tickets.last;
      expect(hours.canSetAside, isTrue);
      expect(state.dismissClass(hours.facts), isTrue);
      final after = _doorway(schedule, state, at);
      expect(after.visibleTickets, hasLength(1));
      expect(after.countingTickets, 1);
      expect(after.tickets.last.folded, isTrue);
    });

    test('a set-aside class drops the tier when the count crosses a line', () {
      final schedule = crowdedFridaySchedule(List.filled(6, 'lecture'));
      final state = _state();
      final at = _ny(10, 9, 7, 0);
      var door = _doorway(schedule, state, at);
      expect(door.tier, DoorwayRailTier.stack);
      state.dismissClass(door.tickets.first.facts);
      door = _doorway(schedule, state, at);
      expect(door.tier, DoorwayRailTier.compact);
      state.dismissClass(door.tickets[1].facts);
      state.dismissClass(door.tickets[2].facts);
      door = _doorway(schedule, state, at);
      expect(door.countingTickets, 3);
      expect(door.tier, DoorwayRailTier.full);
    });
  });
}
