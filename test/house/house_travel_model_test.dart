// The dock's travel as a pure model, stepped by hand: the stack of rooms, the
// dip, the drift and the dolly, the UI that lets go and comes up, a tap that
// re-aims from the state on screen, Reduce Motion and the Goals glint.
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:emberkeep/widgets/house/house_travel_model.dart';
import 'package:flutter_test/flutter_test.dart';

HouseLayerFrame _frameOf(HouseTravelModel m, int room) =>
    m.frames.firstWhere((f) => f.room == room);

void main() {
  test('at rest one room is on stage, whole, doing nothing', () {
    final m = HouseTravelModel(initial: 1);
    expect(m.stack, [1]);
    expect(m.busy, isFalse);
    expect(m.current, 1);
    final f = m.frames.single;
    expect(f.room, 1);
    expect(f.arriving, isFalse);
    expect(f.ui, 1);
    expect(f.dim, 0);
    expect(f.scale, 1);
    expect(f.dx, 0);
  });

  test('a tap stages the new room over the old one and arrives in its own '
      'time', () {
    for (final room in HouseRoom.values) {
      if (room == HouseRoom.quests) continue;
      final m = HouseTravelModel(initial: 1);
      m.goTo(room.index, 1000);
      expect(m.stack, [1, room.index]);
      expect(m.busy, isTrue);
      final ms = room.arrivalMs;
      m.update(1000 + ms / 2);
      expect(_frameOf(m, room.index).progress, closeTo(0.5, 1e-9));
      expect(m.busy, isTrue);
      m.update(1000 + ms - 1);
      expect(m.busy, isTrue);
      m.update(1000 + ms.toDouble());
      expect(m.stack, [room.index], reason: '${room.name} settled');
      expect(m.busy, isFalse);
      expect(m.frames.single.ui, 1);
    }
  });

  test('the arriving room drifts 14 pt from the tapped side and dollies '
      '1.03 to 1.0', () {
    final right = HouseTravelModel(initial: 1)..goTo(3, 0);
    final start = _frameOf(right, 3);
    expect(start.dx, closeTo(houseDriftPoints, 1e-9));
    expect(start.scale, closeTo(houseDollyFrom, 1e-9));
    right.update(410);
    final mid = _frameOf(right, 3);
    expect(mid.dx, lessThan(houseDriftPoints));
    expect(mid.dx, greaterThan(0));
    expect(mid.scale, lessThan(houseDollyFrom));
    expect(mid.scale, greaterThan(1));

    // From a tab to the left of it the room drifts in from the left.
    final left = HouseTravelModel(initial: 3)..goTo(0, 0);
    expect(_frameOf(left, 0).dx, closeTo(-houseDriftPoints, 1e-9));
    // The room it covers does not move.
    expect(_frameOf(left, 3).dx, 0);
    expect(_frameOf(left, 3).scale, 1);
  });

  test('the departing room dips 25% over 220 ms and never goes black', () {
    final m = HouseTravelModel(initial: 1)..goTo(3, 0);
    expect(_frameOf(m, 1).dim, 0);
    m.update(110);
    expect(_frameOf(m, 1).dim, closeTo(0.25 * 0.875, 1e-9));
    m.update(220);
    expect(_frameOf(m, 1).dim, closeTo(houseDipDepth, 1e-9));
    // It stays there while the new room finishes, never deeper.
    for (var t = 220.0; t < 820; t += 20) {
      m.update(t);
      expect(_frameOf(m, 1).dim, closeTo(0.25, 1e-9));
    }
    // The room arriving is never dimmed.
    expect(_frameOf(m, 3).dim, 0);
  });

  test('the departing UI lets go first and the arriving UI comes up once its '
      'light has reached it: two cards never overlap', () {
    final m = HouseTravelModel(initial: 1)..goTo(3, 0);
    expect(_frameOf(m, 1).ui, 1);
    expect(_frameOf(m, 3).ui, 0);
    var worst = 0.0;
    var leaving = 1.0;
    var arriving = 0.0;
    for (var t = 0.0; t <= 820; t += 8) {
      m.update(t);
      if (m.stack.length < 2) break;
      final a = _frameOf(m, 1).ui;
      final b = _frameOf(m, 3).ui;
      expect(a, lessThanOrEqualTo(leaving + 1e-9), reason: 'only lets go');
      expect(b, greaterThanOrEqualTo(arriving - 1e-9), reason: 'only comes up');
      leaving = a;
      arriving = b;
      if (a * b > worst) worst = a * b;
    }
    expect(worst, lessThan(0.1));
    m.update(820);
    expect(m.stack, [3]);
    expect(m.frames.single.ui, 1);
  });

  test('a tap mid-arrival re-aims from the state on screen', () {
    final m = HouseTravelModel(initial: 1)..goTo(3, 0);
    m.update(300);
    final before = _frameOf(m, 3).progress;
    m.goTo(4, 300);
    // Nothing snapped: the room already arriving is still where it was.
    expect(m.stack, [1, 3, 4]);
    expect(_frameOf(m, 3).progress, closeTo(before, 1e-9));
    expect(_frameOf(m, 4).progress, 0);
    expect(_frameOf(m, 4).depth, 2);
    // The new room arrives from nothing, over the others.
    m.update(300 + 450);
    expect(_frameOf(m, 4).progress, closeTo(0.5, 1e-9));
    m.update(300 + 900);
    expect(m.stack, [4]);
    expect(m.busy, isFalse);
  });

  test('a tap back to a room that is still underneath brings it back up and '
      'what is above it lets go', () {
    final m = HouseTravelModel(initial: 1)..goTo(3, 0);
    m.update(300);
    final above = _frameOf(m, 3).progress;
    m.goTo(1, 300);
    expect(m.stack, [1, 3]);
    expect(_frameOf(m, 3).progress, closeTo(above, 1e-9));
    m.update(330);
    // Room 3 lets go: it recedes, its light running backwards.
    expect(_frameOf(m, 3).progress, lessThan(above));
    m.update(300 + 1000);
    expect(m.stack, [1]);
    expect(m.busy, isFalse);
  });

  test('a tap to the room being left while it dips lifts the dip', () {
    final m = HouseTravelModel(initial: 1)..goTo(3, 0);
    m.update(110);
    final dipped = _frameOf(m, 1).dim;
    expect(dipped, greaterThan(0));
    m.goTo(1, 110);
    expect(_frameOf(m, 1).dim, closeTo(dipped, 1e-9));
    m.update(330);
    expect(_frameOf(m, 1).dim, closeTo(0, 1e-9));
  });

  test('Reduce Motion: a 200 ms cross-fade, no mask, no drift, no dip, no '
      'staggered UI', () {
    final m = HouseTravelModel(initial: 1, reduceMotion: true)..goTo(3, 0);
    for (var t = 0.0; t <= 200; t += 10) {
      m.update(t);
      if (m.stack.length < 2) break;
      final top = _frameOf(m, 3);
      expect(top.arriving, isFalse);
      expect(top.dx, 0);
      expect(top.scale, 1);
      expect(top.ui, 1);
      expect(top.dim, 0);
      expect(top.opacity, closeTo(t / 200, 1e-9));
      expect(_frameOf(m, 1).opacity, 1);
      expect(_frameOf(m, 1).dim, 0);
    }
    m.update(200);
    expect(m.stack, [3]);
    expect(m.frames.single.opacity, 1);
  });

  test('every tap to the same room is a no-op', () {
    final m = HouseTravelModel(initial: 2);
    m.goTo(2, 50);
    expect(m.busy, isFalse);
    expect(m.stack, [2]);
  });

  test('jumpTo parks on a room at once', () {
    final m = HouseTravelModel(initial: 1)..goTo(3, 0);
    m.jumpTo(0);
    expect(m.stack, [0]);
    expect(m.busy, isFalse);
    expect(m.current, 0);
  });

  group('the glint over the Goals sign', () {
    test('catches the light last: after the cone has opened, for 420 ms', () {
      final m = HouseTravelModel(initial: 1)..goTo(HouseRoom.goals.index, 0);
      final start = 740 * houseGlintDelayShare + houseGlintDelayMs;
      expect(m.glintAt(start - 1), isNull);
      final mid = m.glintAt(start + houseGlintMs / 2)!;
      expect(mid.strength, closeTo(1, 1e-6));
      expect(mid.x, closeTo(-130 + 330 * 0.5, 1e-6));
      expect(m.glintAt(start + houseGlintMs + 1), isNull);
      // And it is gone for good.
      expect(m.glintAt(start + 100), isNull);
    });

    test('only Goals has one, and Reduce Motion has none', () {
      final plans = HouseTravelModel(initial: 1)..goTo(3, 0);
      expect(plans.glintAt(700), isNull);
      final still = HouseTravelModel(initial: 1, reduceMotion: true)
        ..goTo(HouseRoom.goals.index, 0);
      expect(still.glintAt(600), isNull);
      // Leaving for another room cancels it.
      final m = HouseTravelModel(initial: 1)..goTo(HouseRoom.goals.index, 0);
      m.goTo(HouseRoom.plans.index, 100);
      expect(m.glintAt(600), isNull);
    });
  });
}
