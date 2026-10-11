// The dock's travel between rooms, as a pure model: no widgets, no clock of
// its own. Ported from the approved prototype (v4, goto/updateTr).
//
// Tapping a room in the dock turns toward it: that room's own light brings it
// up. The model keeps a stack of rooms, bottom to top; the room being headed
// for is on top and arrives over the ones under it, each with its own progress.
// A tap while another arrival is still running re-aims from the state on
// screen: a room that is still underneath simply comes back up, and whatever
// is above it lets go; a room that is not on the stack is pushed and arrives
// from nothing.
//
//   * the departing room dips 25% over 220 ms (it never goes black);
//   * the arriving room drifts in 14 pt from the side of the tapped tab and
//     dollies 1.03 to 1.0, on cubic-bezier(.3, .1, .2, 1);
//   * the departing room's own UI lets go first and the arriving room's UI
//     comes up once its light has reached it, so two cards never overlap;
//   * Reduce Motion is a plain 200 ms cross-fade of the arriving room.
//
// Everything is a function of the times it is given, so it can be stepped
// frame by frame.
library;

import 'dart:math' as math;

import 'package:flutter/animation.dart' show Cubic;

import 'house_arrival.dart' show houseSmoothstep;
import 'house_room.dart';

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double _lerp(double a, double b, double t) => a + (b - a) * t;

/// The arrival's easing.
const houseArrivalCurve = Cubic(0.3, 0.1, 0.2, 1.0);

/// How the progress fed to a room's light recipe differs from time: 88% of
/// the linear progress and 12% of its easing, so the light grows nearly
/// steadily while the drift and the dolly settle.
double houseLightProgress(double p) =>
    _lerp(p, houseArrivalCurve.transform(p), 0.12);

/// The glint that crosses Goals' glass sign last: it starts a little after the
/// lamp's cone has opened (62% of the arrival and 120 ms) and sweeps for 420 ms.
const houseGlintDelayShare = 0.62;
const houseGlintDelayMs = 120.0;
const houseGlintMs = 420.0;

/// One staged room's state on a frame.
final class HouseLayerFrame {
  const HouseLayerFrame({
    required this.room,
    required this.depth,
    required this.progress,
    required this.light,
    required this.arriving,
    required this.dx,
    required this.scale,
    required this.dim,
    required this.ui,
    required this.opacity,
  });

  /// The room's dock index.
  final int room;

  /// Its place in the stack (0 is the bottom).
  final int depth;

  /// How far the room has arrived in time (0..1).
  final double progress;

  /// The progress its light recipe takes (see [houseLightProgress]).
  final double light;

  /// Whether the room is under a reveal mask (an arriving layer above the
  /// bottom one). Never true under Reduce Motion.
  final bool arriving;

  /// The drift (pt) and the dolly the room is at.
  final double dx;
  final double scale;

  /// How far the room has dipped (0..0.25).
  final double dim;

  /// How much of the room's own UI shows (0..1).
  final double ui;

  /// The room's whole-room opacity: 1 except in a Reduce Motion cross-fade.
  final double opacity;
}

/// The glint over Goals' sign: how far across it is (percent of its width, from
/// -130 to 200) and how strong (0..1); null when none is running.
final class HouseGlintFrame {
  const HouseGlintFrame({required this.x, required this.strength});

  final double x;
  final double strength;
}

class _Layer {
  _Layer(this.room);

  final int room;
  double p0 = 0;
  double t0 = 0;
  double dir = 1;
  double dur = 0;
  double side = 1;
  double p = 0;
  double dim0 = 0;
  double dimT0 = 0;
  double dimTo = 0;
}

/// The model. Times are milliseconds on any monotonic clock the caller keeps.
class HouseTravelModel {
  HouseTravelModel({int initial = 1, this.reduceMotion = false})
    : _current = initial {
    for (var i = 0; i < HouseRoom.values.length; i++) {
      _layers.add(_Layer(i)..dur = HouseRoom.values[i].arrivalMs.toDouble());
    }
    _layers[initial]
      ..p = 1
      ..p0 = 1;
    _stack.add(initial);
    _frames = [_restFrame(initial)];
  }

  /// Reduce Motion: the arrival is a 200 ms cross-fade, no mask, no drift, no
  /// dip and no staggered UI.
  bool reduceMotion;

  final List<_Layer> _layers = [];
  final List<int> _stack = [];
  int _current;
  bool _busy = false;
  double? _glintStart;
  List<HouseLayerFrame> _frames = const [];

  /// The room being shown or headed for.
  int get current => _current;

  /// Whether anything is still arriving or leaving.
  bool get busy => _busy;

  /// Whether the Goals glint is yet to run or still running (frames are
  /// needed for it even after the rooms have settled).
  bool get glintPending => _glintStart != null;

  /// The rooms on stage, bottom to top (one at rest).
  List<int> get stack => List.unmodifiable(_stack);

  /// Each staged room's state as of the last [update], bottom to top.
  List<HouseLayerFrame> get frames => _frames;

  double _durOf(int room) => reduceMotion
      ? houseReducedArrival.inMilliseconds.toDouble()
      : HouseRoom.values[room].arrivalMs.toDouble();

  double _pOf(_Layer l, double t) =>
      _clamp01(l.p0 + l.dir * (t - l.t0) / l.dur);

  double _dimOf(_Layer l, double t) {
    final u = _clamp01((t - l.dimT0) / houseDipDuration.inMilliseconds);
    final eased = 1 - math.pow(1 - u, 3).toDouble();
    return _lerp(l.dim0, l.dimTo, eased);
  }

  /// Turns toward room [target] at time [now]. Re-aims from the state on
  /// screen when an arrival is already running.
  void goTo(int target, double now) {
    if (target == _current) return;
    final from = _current;
    _current = target;
    final side = target > from ? 1.0 : -1.0;
    for (final r in _stack) {
      final l = _layers[r];
      l.p = l.p0 = _pOf(l, now);
      l.t0 = now;
    }
    final ix = _stack.indexOf(target);
    if (ix >= 0) {
      // It is still there underneath: whatever is above it lets go.
      for (var k = ix + 1; k < _stack.length; k++) {
        _layers[_stack[k]].dir = -1;
      }
      _layers[target].dir = 1;
    } else {
      _stack.add(target);
      _layers[target]
        ..p = 0
        ..p0 = 0
        ..t0 = now
        ..dir = 1
        ..dur = _durOf(target)
        ..side = side
        ..dim0 = 0
        ..dimTo = 0
        ..dimT0 = now;
    }
    for (final r in _stack) {
      final l = _layers[r];
      l.dur = _durOf(r);
      final want = r == target ? 0.0 : houseDipDepth;
      if (l.dimTo != want) {
        l.dim0 = _dimOf(l, now);
        l.dimTo = want;
        l.dimT0 = now;
      }
    }
    _glintStart = (target == HouseRoom.goals.index && !reduceMotion)
        ? now + _durOf(target) * houseGlintDelayShare + houseGlintDelayMs
        : null;
    _busy = true;
    update(now);
  }

  /// Settles on [room] with nothing running (no arrival).
  void jumpTo(int room) {
    for (final l in _layers) {
      l
        ..p = 0
        ..p0 = 0
        ..dir = 1
        ..dim0 = 0
        ..dimTo = 0;
    }
    _layers[room]
      ..p = 1
      ..p0 = 1;
    _stack
      ..clear()
      ..add(room);
    _current = room;
    _busy = false;
    _glintStart = null;
    _frames = [_restFrame(room)];
  }

  HouseLayerFrame _restFrame(int room) => HouseLayerFrame(
    room: room,
    depth: 0,
    progress: 1,
    light: 1,
    arriving: false,
    dx: 0,
    scale: 1,
    dim: 0,
    ui: 1,
    opacity: 1,
  );

  /// Advances to time [now]: drops what has let go, parks when everything has
  /// settled, and computes each staged room's frame.
  void update(double now) {
    final st = _stack;
    for (final r in st) {
      _layers[r].p = _pOf(_layers[r], now);
    }
    // A layer that has let go completely is gone; once the room we are heading
    // for is fully in, everything under it is gone.
    for (var k = st.length - 1; k >= 0; k--) {
      final l = _layers[st[k]];
      if (l.dir < 0 && l.p <= 0) st.removeAt(k);
    }
    var top = -1;
    for (var k = st.length - 1; k >= 0; k--) {
      if (_layers[st[k]].dir > 0) {
        top = k;
        break;
      }
    }
    if (top >= 0 && _layers[st[top]].p >= 1) {
      st.removeRange(0, top);
    }
    if (st.length == 1 && _layers[st[0]].p >= 1) {
      _busy = false;
      _frames = [_restFrame(st[0])];
      return;
    }
    _busy = true;
    final g = [for (final r in st) houseLightProgress(_layers[r].p)];
    final out = <HouseLayerFrame>[];
    for (var k = 0; k < st.length; k++) {
      final l = _layers[st[k]];
      final dim = _dimOf(l, now);
      if (reduceMotion) {
        out.add(
          HouseLayerFrame(
            room: st[k],
            depth: k,
            progress: l.p,
            light: g[k],
            arriving: false,
            dx: 0,
            scale: 1,
            dim: 0,
            ui: 1,
            opacity: k == 0 ? 1 : l.p,
          ),
        );
        continue;
      }
      final arriving = l.p < 1 || l.dir < 0;
      var ui = 1.0;
      var masked = false;
      var dx = 0.0;
      var scale = 1.0;
      if (arriving && k > 0) {
        final e = houseArrivalCurve.transform(l.p);
        masked = true;
        dx = l.side * houseDriftPoints * (1 - e);
        scale = 1 + (houseDollyFrom - 1) * (1 - e);
        // The new room's own UI comes up once its light has reached it.
        ui = houseSmoothstep((g[k] - 0.45) / 0.4);
      } else if (k < st.length - 1) {
        // The room being left lets go of its UI first, so two cards never sit
        // on top of each other.
        ui = 1 - houseSmoothstep(g[k + 1] / 0.35);
      }
      out.add(
        HouseLayerFrame(
          room: st[k],
          depth: k,
          progress: l.p,
          light: g[k],
          arriving: masked,
          dx: dx,
          scale: scale,
          dim: dim,
          ui: ui,
          opacity: 1,
        ),
      );
    }
    _frames = out;
  }

  /// The glint over Goals' sign at time [now], or null when none is running.
  HouseGlintFrame? glintAt(double now) {
    final start = _glintStart;
    if (start == null) return null;
    final u = (now - start) / houseGlintMs;
    if (u >= 1) {
      _glintStart = null;
      return null;
    }
    if (u <= 0) return null;
    final eio = u < 0.5
        ? 4 * u * u * u
        : 1 - math.pow(-2 * u + 2, 3).toDouble() / 2;
    return HouseGlintFrame(
      x: -130 + 330 * eio,
      strength: math.sin(math.pi * u),
    );
  }
}
