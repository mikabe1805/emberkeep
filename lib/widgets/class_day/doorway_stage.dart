// The Doorway: the class-day room.
//
// A tall front door with the outside world in its panes, the day's tickets on
// a brass rail by the door, the hooks above them, a shelf of tied weeks and
// the key bowl on the cabinet. It is the same view on every class day and for
// every room style: the day's state is painted into it, and a mark answers by
// hanging a ticket up.
//
// Layers, back to front:
//   outdoor   the exterior behind the six glass panes, slow drift and the most
//             tilt parallax
//   plate     the interior, as the three painted lights (midday, golden hour,
//             dusk), cross-faded by the real clock. Never tinted
//   beams     live sunbeams laid additively over the painted ones, breathing
//             a few percent over eight seconds
//   shelf, strings, rail, tickets, brass lip, bowl
//   dust      a few dozen slow motes living in the beams (or near the lantern
//             at dusk)
//
// Reduce Motion stills all of it: no breathing, no drift, no dust, no tilt.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../clock.dart';
import 'class_room_stage.dart' show ClassStatusScrim, classStatusScrimHeight;
import 'doorway_art.dart';
import 'doorway_cues.dart';
import 'doorway_dust.dart';
import 'doorway_light.dart';
import 'doorway_model.dart';
import 'doorway_motion.dart';
import 'doorway_rail.dart';
import 'doorway_tickets.dart';

/// How far the tilt moves the interior and the exterior (points at full tilt):
/// the plate barely moves, the outdoors travels a few points.
const double _plateParallax = 1.7;
const double _outdoorParallax = 5.5;

/// The wall is drawn a hair over size so its parallax never shows an edge.
const double _plateOverscan = 1.015;

/// The rail's chain when a ticket leaves a holder: the gap closes (380 ms),
/// and 340 ms in, the next ticket in the queue is clipped in from behind the
/// brass lip (640 ms). One controller carries all of it.
const double _glideMs = 380;
const double _enterDelayMs = 340;
const double _enterMs = 640;
const double _chainMs = _enterDelayMs + _enterMs;

/// How long the whole chain takes when a class leaves or is kept.
const Duration doorwayGlide = Duration(milliseconds: 980);

/// How far a ticket must be dragged up (points) to be marked, and the most it
/// follows the finger.
const double _dragMark = 24;
const double _dragMax = 40;

/// The Doorway for [day].
class DoorwayStage extends StatefulWidget {
  const DoorwayStage({
    super.key,
    required this.day,
    this.parallax,
    this.reduceMotion = false,
    this.scrimHeight = classStatusScrimHeight,
    this.now,
    this.art,
    this.onMarkTicket,
    this.onSelectTicket,
    this.semanticTickets = false,
    this.onBeat,
    this.cues = const DoorwayCues(),
  });

  final DoorwayDay day;

  /// The shell's tilt (accelerometer) source, each axis -1 to 1.
  final ValueListenable<Offset>? parallax;

  /// Stills the ambient motion and the tilt, and turns every move into a
  /// cross-fade.
  final bool reduceMotion;

  /// How far down the soft dark under the status bar and the HUD reaches.
  final double scrimHeight;

  /// The moment the light is read at; the app's clock when null.
  final DateTime? now;

  /// A shared art loader (tests); the stage makes its own when null.
  final DoorwayArt? art;

  /// A waiting ticket was dragged up past the mark line: the room marks its
  /// class. Null: the tickets cannot be dragged.
  final ValueChanged<DoorwayTicket>? onMarkTicket;

  /// A ticket that waits (not the foremost) was tapped: the room brings it
  /// forward. Null: those tickets do not answer a tap.
  final ValueChanged<DoorwayTicket>? onSelectTicket;

  /// The tickets on the wall are announced to a screen reader (a quest's name,
  /// its stat and XP, and where it stands). Off for a class day, where the
  /// glass card says the same in words.
  final bool semanticTickets;

  /// The moves the room waits on (see [DoorwayBeat]).
  final ValueChanged<DoorwayBeat>? onBeat;

  /// What the moves say to the hand and the ear.
  final DoorwayCues cues;

  @override
  State<DoorwayStage> createState() => DoorwayStageState();
}

/// The per-frame values the plate, the beams and the dust draw from.
class _Frame extends ChangeNotifier {
  List<double> fades = const [0, 0, 1];
  DoorwayLights lights = const DoorwayLights(midday: 0, golden: 0, evening: 1);
  double seconds = 0;
  double beamK = 1;
  double air = 0;
  double warm = 0;
  Offset tilt = Offset.zero;
  bool still = false;

  void changed() => notifyListeners();
}

/// What the rail painters read; they repaint only when the rail changes.
class _RailFrame extends ChangeNotifier implements DoorwayRailSource {
  @override
  List<DoorwayHolder> railHolders = const [];

  @override
  List<double> railFades = const [0, 0, 1];

  @override
  List<ui.Image?> railAtlases = const [null, null, null];

  void changed() => notifyListeners();
}

/// Ticks the moving layer (the tickets in flight, their strings, the bundle).
class _Moving extends ChangeNotifier {
  void changed() => notifyListeners();
}

/// One ticket's trip between its holder and its hook.
class _Marking {
  _Marking({
    required this.ticket,
    required this.hang,
    required this.from,
    required this.fromKx,
    required this.fromKy,
    required this.start,
    this.dragOff = 0,
    this.reverse = false,
    this.position = 0,
  });

  /// The ticket as it stood in its holder (its words are what the card shows).
  final DoorwayTicket ticket;
  final DoorwayHang hang;

  /// Where the ticket stands in its holder, and the stretch it has there.
  final Offset from;
  final double fromKx;
  final double fromKy;

  /// When it began on the stage's clock (ms); later than now while it waits
  /// its turn behind another ticket.
  double start;

  /// How far a drag had lifted it when it let go.
  final double dragOff;

  /// An undo: the same trip, run backwards, into the holder.
  final bool reverse;

  /// How many classes are kept today with this one (the first is 1): the
  /// place its hang takes in the chime's rising line. Zero for an undo.
  final int position;
}

/// A ticket's flight from its hook into the bowl.
class _Flight {
  _Flight({
    required this.ticket,
    required this.hang,
    required this.index,
    required this.from,
    required this.fromDegrees,
  });

  final DoorwayTicket ticket;
  final DoorwayHang hang;

  /// Its place among the day's tickets (the first goes behind, the rest
  /// in front).
  final int index;
  final Offset from;
  final double fromDegrees;
}

/// The day's tickets dropping into the bowl.
class _Drop {
  _Drop({required this.start, required this.pair, required this.flights});

  final double start;

  /// The pair's place in the bowl.
  final int pair;
  final List<_Flight> flights;
}

/// The week's bundle rising from the bowl to the shelf.
class _Tie {
  _Tie({required this.start, required this.index, required this.pairs});

  final double start;

  /// Its place on the shelf (the number of bundles there before it).
  final int index;

  /// The pairs that were lying in the bowl.
  final int pairs;
  double? landedAt;
}

/// Something that happens when the stage's clock reaches [at].
class _Cue {
  _Cue(this.at, this.tag, this.run);

  final double at;
  final String tag;
  final VoidCallback run;
}

class DoorwayStageState extends State<DoorwayStage>
    with TickerProviderStateMixin {
  late DoorwayArt _art;
  bool _ownsArt = false;
  final _Frame _frame = _Frame();
  final _RailFrame _rail = _RailFrame();
  final _Moving _moving = _Moving();
  final DoorwayDust _dust = DoorwayDust();
  Ticker? _ticker;
  Timer? _minute;
  Duration _last = Duration.zero;
  Duration _lastPaint = Duration.zero;
  Duration _lastElapsed = Duration.zero;
  Offset _tilt = Offset.zero;

  /// The stage's own clock (ms), which every move is timed on. It runs while
  /// the stage animates, and while a move is under way even under Reduce
  /// Motion.
  double _ms = 0;

  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: doorwayGlide,
    value: 1,
  )..addListener(_onGlide);

  late DoorwayRailLayout _layout;
  late List<DoorwayHolder> _holdersFrom;
  Map<String, _Pose> _poseFrom = const {};
  List<_Leaving> _leaving = const [];

  // Choreography.
  final List<_Marking> _marks = [];
  final List<_Cue> _cues = [];
  final List<double> _airStarts = [];
  final List<double> _gustStarts = [];
  final List<double> _warmStarts = [];
  _Drop? _drop;
  _Tie? _tie;
  DoorwayRailLayout? _deferred;

  /// While the day's pair is about to drop, the hooks still hold the day's
  /// tickets and the bowl and the shelf still show what they did before.
  bool _holdHooks = false;
  int? _bowlHeld;
  int? _shelfHeld;

  /// A drag in progress, per ticket id: how far up (negative) it has gone.
  final Map<String, double> _dragY = {};
  final Map<String, double> _dragOff = {};
  final Map<String, double> _dragStart = {};
  final Set<String> _dragReleased = {};

  /// The tickets the wall holds now (for tests).
  List<DoorwayPlacedTicket> get placedTickets => _layout.placed;

  /// The tickets waiting off the wall (for tests).
  List<DoorwayTicket> get queuedTickets => _layout.queued;

  /// The lights the stage drew last (for tests).
  DoorwayLights get lights => _frame.lights;

  /// How far the tilt has moved the stage, each axis -1 to 1 (for tests).
  Offset get tilt => _frame.tilt;

  /// Whether the ambient motion runs (false under Reduce Motion).
  bool get animating => _ticker?.isActive ?? false;

  /// The tickets that are on their way between a holder and a hook, or
  /// swinging (for tests).
  List<String> get markingIds => [for (final m in _marks) m.ticket.id];

  /// Whether any move is under way (for tests).
  bool get moving => _choreoActive;

  /// The stage's clock (for tests), and the door's air and the beams' extra
  /// warmth at this moment.
  double get clockMs => _ms;
  double get air => _frame.air;
  double get warm => _frame.warm;

  /// How many pairs lie in the bowl and how many bundles stand on the shelf
  /// as drawn now (for tests).
  int get bowlShown => _bowlHeld ?? widget.day.bowlCount;
  int get shelfShown => _shelfHeld ?? widget.day.shelfCount;

  /// Whether the day's tickets are in flight to the bowl, and the week's
  /// bundle in flight to the shelf (for tests).
  bool get dropping => _drop != null;
  bool get tying => _tie != null;

  bool get _choreoActive =>
      _marks.isNotEmpty ||
      _cues.isNotEmpty ||
      _drop != null ||
      _tie != null ||
      _dragY.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _art = widget.art ?? DoorwayArt();
    _ownsArt = widget.art == null;
    _art.addListener(_onArt);
    _layout = DoorwayRailLayout.of(widget.day);
    _holdersFrom = _layout.holders;
    _rail.railHolders = _layout.holders;
    _syncMotion();
    _refresh(0, notify: false);
  }

  @override
  void didUpdateWidget(DoorwayStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reduceMotion != widget.reduceMotion ||
        oldWidget.parallax != widget.parallax) {
      _syncMotion();
    }
    final next = DoorwayRailLayout.of(widget.day);
    if (oldWidget.day.date != widget.day.date) {
      _resetMoves();
      if (!_sameLayout(_layout, next)) _relayout(next);
    } else {
      _follow(oldWidget.day, widget.day, next);
    }
    _refresh(_frame.seconds, notify: false);
    _rail.railHolders = doorwayRailBlend(
      _holdersFrom,
      _layout.holders,
      _glideU,
    );
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _minute?.cancel();
    _glide.dispose();
    _art.removeListener(_onArt);
    if (_ownsArt) _art.dispose();
    _frame.dispose();
    _rail.dispose();
    _moving.dispose();
    super.dispose();
  }

  // ── Motion ──────────────────────────────────────────────────────────────

  void _syncMotion() {
    final still = widget.reduceMotion;
    _frame.still = still;
    _glide.duration = still ? Duration.zero : doorwayGlide;
    if (still) {
      _tilt = Offset.zero;
      _minute ??= Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) _refresh(0);
      });
    } else {
      _minute?.cancel();
      _minute = null;
    }
    _syncTicker();
  }

  /// The one ticker runs while the stage breathes, and (under Reduce Motion)
  /// only while a move is under way.
  void _syncTicker() {
    final want = !widget.reduceMotion || _choreoActive;
    if (want) {
      final ticker = _ticker ??= createTicker(_onTick);
      if (!ticker.isActive) {
        _last = Duration.zero;
        _lastPaint = Duration.zero;
        _lastElapsed = Duration.zero;
        ticker.start();
      }
    } else {
      _ticker?.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final stepMs = (elapsed - _lastElapsed).inMicroseconds / 1000.0;
    _lastElapsed = elapsed;
    _ms += stepMs;
    _runCues();
    _decayDrags(stepMs);
    final still = widget.reduceMotion;
    if (!still) {
      final since = (elapsed - _lastPaint).inMilliseconds;
      // About thirty paints a second is plenty for light that breathes over
      // eight seconds and dust that drifts.
      if (since >= 30 || _lastPaint == Duration.zero) {
        final dt = math.min(60.0, (elapsed - _last).inMicroseconds / 1000.0);
        _last = elapsed;
        _lastPaint = elapsed;
        final t = elapsed.inMicroseconds / 1e6;
        final listened = widget.parallax?.value ?? Offset.zero;
        final sway = Offset(
          0.34 * math.sin(t * 1000 / 4200),
          0.2 * math.sin(t * 1000 / 5300 + 1.3),
        );
        final target = Offset(
          listened.dx.clamp(-1.0, 1.0) + sway.dx,
          listened.dy.clamp(-1.0, 1.0) + sway.dy,
        );
        final follow = math.min(1.0, dt / 170);
        _tilt = _tilt + (target - _tilt) * follow;
        _refresh(t, dt: dt);
      }
    }
    if (_choreoActive) {
      _moving.changed();
    } else if (still) {
      _ticker?.stop();
    }
  }

  /// The door's air and the beams' warmth at the stage's clock now.
  double _airNow() {
    var v = 0.0;
    for (final start in _airStarts) {
      v += doorwayAirAt(_ms, start);
    }
    return v.clamp(0.0, 1.2);
  }

  double _warmNow() {
    var v = 0.0;
    for (final start in _warmStarts) {
      v += doorwayBump(_ms, start, 1300, 0.22);
    }
    return v;
  }

  double _gustNow() {
    var v = 0.0;
    for (final start in _gustStarts) {
      v += doorwayGust(_ms - start);
    }
    return v.clamp(0.0, 1.5);
  }

  /// Recomputes what the painters draw: the light for the clock, the beams'
  /// breath, and (while moving) the dust.
  void _refresh(double seconds, {double dt = 0, bool notify = true}) {
    final moment = widget.now ?? Clock.now();
    final lights = doorwayLightsAt(moment);
    final still = widget.reduceMotion;
    _frame
      ..lights = lights
      ..fades = doorwayCrossfade(lights.weights)
      ..seconds = seconds
      ..tilt = still ? Offset.zero : _tilt
      ..beamK = still ? 1 : 1 + 0.04 * math.sin(2 * math.pi * seconds / 8)
      ..air = still ? 0 : _airNow()
      ..warm = still ? 0 : _warmNow()
      ..still = still;
    _wantArt(lights);
    if (!still && dt > 0) {
      _dust.step(dt, lights, _frame.beamK, gust: _gustNow());
    }
    final fadesChanged = !_listEq(_rail.railFades, _frame.fades);
    _rail
      ..railFades = _frame.fades
      ..railAtlases = [for (final path in DoorwayAssets.rail) _art[path]];
    if (!notify) return;
    _frame.changed();
    if (fadesChanged || _glide.isAnimating) _rail.changed();
  }

  bool _listEq(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 0.002) return false;
    }
    return true;
  }

  /// Asks for the art of the lights that show now (and the lantern's, the
  /// beams' and the objects'); the rest waits until its hour comes.
  void _wantArt(DoorwayLights lights) {
    final w = lights.weights;
    for (var k = 0; k < 3; k++) {
      if (w[k] <= 0.0005) continue;
      _art
        ..ensure(DoorwayAssets.view[k])
        ..ensure(DoorwayAssets.outdoor[k])
        ..ensure(DoorwayAssets.rail[k]);
      if (k < 2) {
        _art.ensure(DoorwayAssets.beam[k]);
        _readMask(k);
      }
    }
  }

  final List<bool> _maskRequested = [false, false];

  Future<void> _readMask(int k) async {
    if (_maskRequested[k]) return;
    final image = _art[DoorwayAssets.beam[k]];
    if (image == null) return;
    _maskRequested[k] = true;
    final mask = await DoorwayBeamMask.fromImage(image, math.Random(7 + k));
    if (!mounted || mask == null) return;
    _dust.masks[k] = mask;
  }

  void _onArt() {
    if (!mounted) return;
    _refresh(_frame.seconds);
  }

  // ── The timeline ────────────────────────────────────────────────────────

  void _at(double ms, String tag, VoidCallback run) {
    _cues.add(_Cue(ms, tag, run));
    _cues.sort((a, b) => a.at.compareTo(b.at));
  }

  void _cancel(String tag) => _cues.removeWhere((cue) => cue.tag == tag);

  void _runCues() {
    while (_cues.isNotEmpty && _cues.first.at <= _ms) {
      _cues.removeAt(0).run();
    }
  }

  void _beat(DoorwayBeat beat) => widget.onBeat?.call(beat);

  /// Everything a move started and has not finished goes; the scene is as the
  /// new day says it is.
  void _resetMoves() {
    _marks.clear();
    _cues.clear();
    _airStarts.clear();
    _gustStarts.clear();
    _warmStarts.clear();
    _drop = null;
    _tie = null;
    _deferred = null;
    _holdHooks = false;
    _bowlHeld = null;
    _shelfHeld = null;
    _dragY.clear();
    _dragOff.clear();
    _dragStart.clear();
    _dragReleased.clear();
  }

  // ── Following the day ───────────────────────────────────────────────────

  /// The hang of [ticket] among [day]'s attended tickets: its hook, and how
  /// many tickets already hang there.
  DoorwayHang _hangOf(DoorwayDay day, DoorwayTicket ticket) {
    final layers = <int, int>{};
    for (final other in day.tickets) {
      final hook = other.hook;
      if (hook == null) continue;
      final layer = layers[hook] ?? 0;
      layers[hook] = layer + 1;
      if (other.id == ticket.id) return doorwayHangFor(hook, layer: layer);
    }
    return doorwayHangFor(ticket.hook ?? 2);
  }

  /// A ticket's place in its holder now, or null when it has none.
  _Pose? _railPoseOf(String id) => _poseOf(id, _glideU, _glideNow);

  /// Reads what changed between [old] and [now]: a class marked begins its
  /// trip to its hook, a mark undone begins the trip back, a day completed
  /// schedules its tickets' drop into the bowl.
  void _follow(DoorwayDay old, DoorwayDay now, DoorwayRailLayout next) {
    final oldById = {for (final t in old.tickets) t.id: t};
    final forward = <(DoorwayTicket, DoorwayTicket)>[];
    final backward = <(DoorwayTicket, DoorwayTicket)>[];
    for (final ticket in now.tickets) {
      final was = oldById[ticket.id];
      if (was == null) continue;
      final wasAttended = was.state == DoorwayTicketState.attended;
      final isAttended = ticket.state == DoorwayTicketState.attended;
      if (!wasAttended && isAttended && ticket.hook != null) {
        forward.add((was, ticket));
      } else if (wasAttended && !isAttended && was.hook != null) {
        backward.add((was, ticket));
      }
    }
    final reduce = widget.reduceMotion;
    var lastStart = _ms;
    var any = false;
    var step = 0;
    // The hang's chime climbs with the day's kept classes: the ones kept before
    // this update, then these in turn (a class set aside is not among them, and
    // an undone one is no longer kept, so it takes the next free place).
    final keptBefore = old.keptCount;
    for (var k = 0; k < forward.length; k++) {
      final (was, ticket) = forward[k];
      final pose = _railPoseOf(ticket.id);
      DoorwayPlacedTicket? placed;
      for (final p in _layout.placed) {
        if (p.ticket.id == ticket.id) placed = p;
      }
      if (placed == null || pose == null) continue;
      final start = _ms + step * doorwayShortcutStepMs;
      step++;
      _startMark(
        _Marking(
          ticket: was,
          hang: _hangOf(now, ticket),
          from: pose.center,
          fromKx: pose.kx,
          fromKy: pose.ky,
          start: start,
          dragOff: _dragOff.remove(ticket.id) ?? 0,
          position: keptBefore + k + 1,
        ),
        reduce,
      );
      _dragY.remove(ticket.id);
      lastStart = math.max(lastStart, start);
      any = true;
    }
    for (final (was, ticket) in backward) {
      DoorwayPlacedTicket? target;
      for (final p in next.placed) {
        if (p.ticket.id == ticket.id) target = p;
      }
      if (target == null) continue;
      _undoMark(
        _Marking(
          ticket: ticket,
          hang: _hangOf(old, was),
          from: target.center,
          fromKx: target.kx,
          fromKy: target.ky,
          start: _ms,
          reverse: true,
        ),
        reduce,
      );
    }
    // The day's pair: complete now, or no longer.
    final wasPair = old.bowlPairs.contains(old.date);
    final isPair = now.bowlPairs.contains(now.date);
    if (!wasPair && isPair) {
      _scheduleDrop(
        old,
        now,
        math.max(
          any ? lastStart + (reduce ? 500 : doorwayDropAfterMs) : 0,
          _ms + (reduce ? 300 : 700),
        ),
      );
    } else if (wasPair && !isPair) {
      _cancel('drop');
      _cancel('land');
      _cancel('tie');
      _holdHooks = false;
      _bowlHeld = null;
      _shelfHeld = null;
      _drop = null;
      _tie = null;
    }
    // The rail: a ticket that went to its hook leaves its holder once it has
    // lifted out (the others close the gap from there); everything else is at
    // once.
    if (any) {
      _deferred = next;
      _cancel('relayout');
      _at(_ms + (reduce ? 0 : doorwayLeaveMs), 'relayout', () {
        final due = _deferred;
        _deferred = null;
        if (due != null && !_sameLayout(_layout, due)) _relayout(due);
        if (mounted) setState(() {});
      });
    } else if (_deferred != null) {
      // The wall is waiting for a ticket to clear its holder: it will lay out
      // for the latest day.
      _deferred = next;
    } else if (!_sameLayout(_layout, next)) {
      _relayout(next);
    }
  }

  void _startMark(_Marking m, bool reduce) {
    _marks.removeWhere((x) => x.ticket.id == m.ticket.id);
    _marks.add(m);
    final t0 = m.start;
    final tag = 'mark-${m.ticket.id}';
    _cancel(tag);
    // The ticket leaves the rail's drawing for the move's the moment it starts.
    if (t0 > _ms) {
      _at(t0, tag, () {
        if (mounted) setState(() {});
      });
    }
    if (reduce) {
      _at(t0, tag, widget.cues.lift);
      _at(t0 + doorwayFadeMs, tag, widget.cues.stamp);
      _at(t0 + doorwayFadeMs, tag, () {
        widget.cues.hang(m.position);
        _beat(DoorwayBeat.hung);
      });
      _at(t0 + doorwayFadeMs + 300, tag, () {
        _beat(DoorwayBeat.settled);
        _marks.removeWhere((x) => identical(x, m));
        if (mounted) setState(() {});
      });
      return;
    }
    _airStarts.add(t0);
    _gustStarts.add(t0 + 250);
    _at(t0 + 60, tag, widget.cues.lift);
    _at(t0 + doorwayStampMs, tag, widget.cues.stamp);
    _at(t0 + doorwayHangMs, tag, () {
      widget.cues.hang(m.position);
      _beat(DoorwayBeat.hung);
    });
    _at(t0 + doorwayHangMs + 1000, tag, () => _beat(DoorwayBeat.settled));
    _at(t0 + doorwayHangMs + doorwaySwingMs, tag, () {
      _marks.removeWhere((x) => identical(x, m));
      if (mounted) setState(() {});
    });
  }

  void _undoMark(_Marking m, bool reduce) {
    _marks.removeWhere((x) => x.ticket.id == m.ticket.id);
    _marks.add(m);
    final tag = 'mark-${m.ticket.id}';
    // Whatever the mark had still to do (a hang, a settle) is no more.
    _cancel(tag);
    final span = reduce ? doorwayFadeMs : doorwayHangMs;
    _at(m.start, tag, widget.cues.lift);
    _at(m.start + span, tag, () {
      _marks.removeWhere((x) => identical(x, m));
      if (mounted) setState(() {});
    });
  }

  /// The day's tickets drop into the bowl at [at].
  void _scheduleDrop(DoorwayDay old, DoorwayDay now, double at) {
    final reduce = widget.reduceMotion;
    _holdHooks = true;
    _bowlHeld = old.bowlCount;
    _shelfHeld = old.shelfCount;
    _cancel('drop');
    _cancel('land');
    _cancel('tie');
    _at(at, 'drop', () => _beginDrop(now, reduce));
  }

  void _beginDrop(DoorwayDay day, bool reduce) {
    final before = _bowlHeld ?? day.bowlCount;
    final pair = before;
    final flights = <_Flight>[];
    for (final ticket in day.tickets) {
      final hook = ticket.hook;
      if (hook == null) continue;
      final hang = _hangOf(day, ticket);
      var swing = 1e9;
      for (final m in _marks) {
        if (m.ticket.id == ticket.id && !m.reverse) {
          swing = _ms - m.start - doorwayHangMs;
        }
      }
      final pose = doorwayHungPose(hang, sinceHung: swing);
      flights.add(
        _Flight(
          ticket: ticket,
          hang: hang,
          index: flights.length,
          from: pose.center,
          fromDegrees: pose.degrees,
        ),
      );
    }
    // The flights take the tickets over from their hooks.
    _marks.removeWhere((m) => !m.reverse);
    _holdHooks = false;
    _drop = _Drop(start: _ms, pair: pair, flights: flights);
    if (!reduce) _warmStarts.add(_ms);
    final span = reduce ? doorwayFadeMs : doorwayDropMs;
    _at(_ms + span, 'land', () {
      widget.cues.bowl();
      _drop = null;
      _bowlHeld = before + 1;
      if (day.weekTied) {
        _beginTie(day, before + 1, reduce);
      } else {
        _bowlHeld = null;
        _shelfHeld = null;
        _at(
          _ms + (reduce ? 150 : doorwayDayCardMs),
          'card',
          () => _beat(DoorwayBeat.dayDone),
        );
      }
      if (mounted) setState(() {});
    });
    if (mounted) setState(() {});
  }

  void _beginTie(DoorwayDay day, int pairs, bool reduce) {
    final shelfBefore = _shelfHeld ?? day.shelfBundles.length;
    final start = _ms + (reduce ? 100 : 420);
    _tie = _Tie(start: start, index: shelfBefore, pairs: pairs);
    final flight = reduce ? doorwayFadeMs : doorwayBundleMs;
    _at(start + flight, 'tie', () {
      widget.cues.shelf();
      final tie = _tie;
      tie?.landedAt = _ms;
      _bowlHeld = null;
      _at(_ms + (reduce ? 200 : doorwayWeekCardMs), 'card', () {
        _beat(DoorwayBeat.weekDone);
      });
      _at(_ms + 450, 'tie', () {
        _tie = null;
        _shelfHeld = null;
        if (mounted) setState(() {});
      });
      if (mounted) setState(() {});
    });
  }

  // ── Dragging a ticket up ────────────────────────────────────────────────

  void _dragStarted(DoorwayTicket ticket, double y) {
    _dragStart[ticket.id] = y;
    _dragOff.remove(ticket.id);
  }

  void _dragUpdate(DoorwayTicket ticket, double y) {
    if (_dragReleased.contains(ticket.id)) return;
    final up = math.min(0.0, y - (_dragStart[ticket.id] ?? y));
    _dragY[ticket.id] = up;
    if (up < -_dragMark) {
      // Past the line: it is marked, and it keeps the lift it has.
      _dragOff[ticket.id] = math.max(up, -_dragMax) * 0.4;
      _dragReleased.add(ticket.id);
      widget.onMarkTicket?.call(ticket);
    }
    _syncTicker();
    _moving.changed();
  }

  void _dragEnd(DoorwayTicket ticket) {
    _dragReleased.remove(ticket.id);
    _dragStart.remove(ticket.id);
    // If the room took the mark, the move has already begun with this lift;
    // if it refused, the lift is forgotten and the ticket settles back.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _dragOff.remove(ticket.id),
    );
    _syncTicker();
  }

  void _decayDrags(double stepMs) {
    if (_dragY.isEmpty) return;
    final keep = math.pow(0.82, stepMs / 16.7).toDouble();
    for (final id in _dragY.keys.toList()) {
      if (_dragReleased.contains(id)) continue;
      final next = _dragY[id]! * keep;
      if (next > -0.3) {
        _dragY.remove(id);
      } else {
        _dragY[id] = next;
      }
    }
  }

  // ── Layout glide ────────────────────────────────────────────────────────

  bool _sameLayout(DoorwayRailLayout a, DoorwayRailLayout b) {
    if (a.slots != b.slots ||
        a.placed.length != b.placed.length ||
        a.queued.length != b.queued.length) {
      return false;
    }
    for (var i = 0; i < a.placed.length; i++) {
      final x = a.placed[i];
      final y = b.placed[i];
      if (x.ticket.id != y.ticket.id ||
          x.slot != y.slot ||
          x.ticket.state != y.ticket.state ||
          x.ky != y.ky) {
        return false;
      }
    }
    for (var i = 0; i < a.queued.length; i++) {
      if (a.queued[i].id != b.queued[i].id) return false;
    }
    return true;
  }

  /// How far the chain has run (ms), and how far its first part (the gap
  /// closing) has (0 to 1).
  double get _glideNow => _glide.value * _chainMs;
  double get _glideU => (_glideNow / _glideMs).clamp(0.0, 1.0);

  void _relayout(DoorwayRailLayout next) {
    final ms = _glideNow;
    final u = _glideU;
    // Where everything is drawn right now becomes where it glides from.
    _holdersFrom = doorwayRailBlend(_holdersFrom, _layout.holders, u);
    final from = <String, _Pose>{};
    for (final placed in _layout.placed) {
      final pose = _poseOf(placed.ticket.id, u, ms);
      if (pose != null) from[placed.ticket.id] = pose;
    }
    final nextIds = {for (final p in next.placed) p.ticket.id};
    final stillThere = {for (final t in widget.day.tickets) t.id: t};
    final leaving = <_Leaving>[];
    for (final placed in _layout.placed) {
      final id = placed.ticket.id;
      if (nextIds.contains(id)) continue;
      // A class that was kept goes to a hook (drawn there); only a class set
      // aside slips out of its holder.
      final now = stillThere[id];
      if (now != null && now.state == DoorwayTicketState.attended) continue;
      final pose = from[id];
      if (pose != null) leaving.add(_Leaving(placed.ticket, pose, placed));
    }
    // A ticket coming back from its hook (an undo) is already where it
    // belongs when it arrives: it neither glides nor clips in.
    for (final marking in _marks) {
      if (!marking.reverse) continue;
      for (final p in next.placed) {
        if (p.ticket.id == marking.ticket.id) {
          from[p.ticket.id] = _Pose(p.center, p.kx, p.ky, 1, 0, 0);
        }
      }
    }
    _layout = next;
    _poseFrom = from;
    _leaving = leaving;
    if (leaving.isNotEmpty) widget.cues.slip();
    if (widget.reduceMotion) {
      _glide.value = 1;
    } else {
      _glide.forward(from: 0);
    }
    _onGlide();
  }

  void _onGlide() {
    _rail
      ..railHolders = doorwayRailBlend(_holdersFrom, _layout.holders, _glideU)
      ..changed();
    if (_glide.isCompleted) {
      _holdersFrom = _layout.holders;
      _leaving = const [];
    }
  }

  /// Where [id]'s card is [ms] into the chain ([u] is the first part's
  /// progress), or null if it has none.
  _Pose? _poseOf(String id, double u, double ms) {
    DoorwayPlacedTicket? target;
    for (final placed in _layout.placed) {
      if (placed.ticket.id == id) target = placed;
    }
    if (target == null) return null;
    final to = _Pose(target.center, target.kx, target.ky, 1, 0, 0);
    final from = _poseFrom[id];
    if (ms >= _chainMs) return to;
    if (from == null) {
      // Clipped in from behind the brass lip once the gap has closed.
      return _Pose(
        target.center,
        target.kx,
        target.ky,
        1,
        0,
        0,
        enter: ((ms - _enterDelayMs) / _enterMs).clamp(0.0, 1.0),
      );
    }
    return _Pose.lerp(from, to, Curves.easeInOut.transform(u));
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final layout = _layout;
    return ExcludeSemantics(
      excluding: !widget.semanticTickets,
      child: ColoredBox(
        color: const Color(0xFF1A110B),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: FittedBox(
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  key: const Key('doorway-canvas'),
                  width: doorwayCanvasWidth,
                  height: doorwayCanvasHeight,
                  child: AnimatedBuilder(
                    animation: _frame,
                    builder: (context, child) {
                      final tilt = _frame.tilt;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.translationValues(
                          tilt.dx * _plateParallax,
                          tilt.dy,
                          0,
                        )..scaleByDouble(_plateOverscan, _plateOverscan, 1, 1),
                        child: child,
                      );
                    },
                    child: _wall(day, layout),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: widget.scrimHeight,
              child: const IgnorePointer(child: ClassStatusScrim()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wall(DoorwayDay day, DoorwayRailLayout layout) {
    return Stack(
      key: const Key('doorway-stage'),
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _PlatePainter(frame: _frame, art: _art),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: ExcludeSemantics(
            child: RepaintBoundary(child: _objects(day, layout)),
          ),
        ),
        Positioned.fill(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: DoorwayDustPainter(dust: _dust, repaint: _frame),
                ),
              ),
            ),
          ),
        ),
        // The tickets can be dragged up (above the dust, under nothing), and
        // a waiting quest ticket can be tapped to bring it forward.
        for (final placed in layout.placed)
          if (!_isMarking(placed.ticket.id))
            if (widget.onMarkTicket != null && placed.ticket.markable)
              _dragZone(placed)
            else if (widget.onSelectTicket != null &&
                placed.ticket.isQuest &&
                placed.ticket.state == DoorwayTicketState.upcoming)
              _tapZone(placed),
      ],
    );
  }

  bool _isMarking(String id) =>
      _marks.any((m) => m.ticket.id == id && _ms >= m.start);

  Widget _dragZone(DoorwayPlacedTicket placed) {
    final ticket = placed.ticket;
    final rect = placed.rect.inflate(2);
    final zone = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (d) => _dragStarted(ticket, d.localPosition.dy),
      onVerticalDragUpdate: (d) => _dragUpdate(ticket, d.localPosition.dy),
      onVerticalDragEnd: (_) => _dragEnd(ticket),
      onVerticalDragCancel: () => _dragEnd(ticket),
      child: const SizedBox.expand(),
    );
    return Positioned.fromRect(
      key: ValueKey('doorway-drag-${ticket.id}'),
      rect: rect,
      child: widget.semanticTickets
          ? Semantics(
              container: true,
              button: true,
              label: doorwayTicketSemantics(ticket),
              onTap: () => widget.onMarkTicket?.call(ticket),
              child: zone,
            )
          : zone,
    );
  }

  /// A waiting quest ticket: a tap brings it forward.
  Widget _tapZone(DoorwayPlacedTicket placed) {
    final ticket = placed.ticket;
    return Positioned.fromRect(
      key: ValueKey('doorway-tap-${ticket.id}'),
      rect: placed.rect.inflate(2),
      child: Semantics(
        container: true,
        button: true,
        excludeSemantics: true,
        label: doorwayTicketSemantics(ticket),
        onTap: () => widget.onSelectTicket?.call(ticket),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onSelectTicket?.call(ticket),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _objects(DoorwayDay day, DoorwayRailLayout layout) {
    final hung = _hungPoses(day);
    final inBowl = bowlShown;
    final railBox = Rect.fromLTWH(
      doorwayRailX0 / 3,
      doorwayRailY0 / 3,
      doorwayRailW / 3,
      doorwayRailH / 3,
    );
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The shelf: tied weeks on the clear stretch, and its small label.
          ..._shelf(day),
          // Strings, then the rail, the tickets and the brass over them.
          Positioned.fill(
            child: CustomPaint(
              key: const Key('doorway-strings'),
              painter: DoorwayStrings([for (final h in hung) ...h.strings]),
            ),
          ),
          Positioned.fromRect(
            rect: railBox,
            child: RepaintBoundary(
              child: CustomPaint(
                key: const Key('doorway-rail'),
                painter: DoorwayRailPainter(source: _rail, lip: false),
              ),
            ),
          ),
          for (final h in hung) h.widget,
          AnimatedBuilder(
            animation: Listenable.merge([_glide, _moving]),
            builder: (context, _) => Stack(
              clipBehavior: Clip.none,
              children: [
                for (final leaving in _leaving) _leavingTicket(leaving),
                for (final placed in layout.placed)
                  if (!_isMarking(placed.ticket.id)) _railTicket(placed),
              ],
            ),
          ),
          Positioned.fromRect(
            rect: railBox,
            child: RepaintBoundary(
              child: CustomPaint(
                key: const Key('doorway-rail-lip'),
                painter: DoorwayRailPainter(source: _rail, lip: true),
              ),
            ),
          ),
          if (inBowl > 0) _bowl(inBowl),
          // Everything in flight, over the lip and the bowl's rim.
          AnimatedBuilder(
            animation: _moving,
            builder: (context, _) => _inFlight(day),
          ),
        ],
      ),
    );
  }

  Widget _railTicket(DoorwayPlacedTicket placed) {
    final id = placed.ticket.id;
    var pose =
        _poseOf(id, _glideU, _glideNow) ??
        _Pose(placed.center, placed.kx, placed.ky, 1, 0, 0);
    final drag = _dragY[id];
    if (drag != null && drag < 0) {
      // Following the finger: a little lift, a little tilt.
      final k = (-drag / _dragMark).clamp(0.0, 1.3);
      pose = pose.dragged(
        math.max(drag, -_dragMax) * 0.4,
        widget.reduceMotion ? 0 : -3 * k,
        1 + 0.03 * k,
      );
    }
    return _placeTicket(
      DoorwayTicketView(
        ticket: placed.ticket,
        kx: pose.kx,
        ky: pose.ky,
        inRail: drag == null || drag > -2,
      ),
      pose,
    );
  }

  Widget _leavingTicket(_Leaving leaving) {
    final e = Curves.easeIn.transform(_glideU);
    final pose = leaving.from.faded(1 - e, 8 * e, 3.2 * e);
    return _placeTicket(
      DoorwayTicketView(
        key: ValueKey('doorway-leaving-${leaving.ticket.id}'),
        ticket: leaving.ticket,
        kx: pose.kx,
        ky: pose.ky,
        inRail: true,
      ),
      pose,
    );
  }

  Widget _placeTicket(Widget view, _Pose pose) {
    final width = doorwayTicketWidth * pose.kx;
    final height = doorwayTicketHeight * pose.ky;
    // A ticket clipping in comes out from behind the brass lip: its top edge
    // stays where the holder's lip is and the paper slides down out of it,
    // with a tiny press at the end.
    var lift = 0.0;
    var hidden = 0.0;
    if (pose.enter < 1) {
      final rise = _entering(pose.enter, height + 2.5);
      lift = rise;
      hidden = rise;
    }
    Widget child = pose.rotation == 0
        ? view
        : Transform.rotate(angle: pose.rotation * math.pi / 180, child: view);
    if (hidden > 0) {
      child = ClipRect(clipper: _TopInset(hidden), child: child);
    }
    return Positioned(
      left: pose.center.dx - width / 2,
      top: pose.center.dy - height / 2 + pose.dy - lift,
      width: width,
      height: height,
      child: Opacity(opacity: pose.opacity.clamp(0.0, 1.0), child: child),
    );
  }

  /// How far above its place a clipping-in ticket is ([travel] at the lip,
  /// then down and a hair past its place).
  double _entering(double p, double travel) {
    if (p >= 1) return 0;
    if (p <= 0) return travel;
    const a = 0.78;
    if (p < a) return travel * (1 - math.sin(p / a * math.pi / 2));
    return -1.25 * math.sin(math.pi * (p - a) / (1 - a));
  }

  List<Widget> _shelf(DoorwayDay day) {
    final count = _shelfHeld ?? day.shelfCount;
    final shown = math.min(count, doorwayBundleX.length);
    // The label counts the new week as the bundle lands.
    final counted = _tie?.landedAt != null ? day.shelfCount : count;
    final label = doorwayShelfLabel(day.termName, counted);
    return [
      for (var i = 0; i < shown; i++)
        Positioned(
          key: ValueKey('doorway-bundle-$i'),
          left: doorwayBundleX[i] - doorwayBundleSizes[i].width / 2,
          top: doorwayShelfTop - doorwayBundleSizes[i].height,
          width: doorwayBundleSizes[i].width,
          height: doorwayBundleSizes[i].height,
          child: _Bundle(kind: i),
        ),
      if (label != null)
        Positioned.fromRect(
          rect: doorwayShelfLabelRect,
          child: Text(
            label,
            key: const Key('doorway-shelf-label'),
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            // Painted on the shelf: it keeps the painting's size at any text
            // size (the tickets' words do the same), or it runs off the wood.
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontWeight: FontWeight.w500,
              fontSize: 5.4,
              height: 1,
              letterSpacing: 0.32,
              color: Color(0xCCEED296),
              shadows: [
                Shadow(offset: Offset(0, -0.5), color: Color(0x8C000000)),
                Shadow(offset: Offset(0, 0.5), color: Color(0x2EFFE1AA)),
              ],
            ),
          ),
        ),
    ];
  }

  /// The day's attended tickets, hung from the hooks. A day whose tickets
  /// have gone into the bowl hangs nothing, and a ticket on its way to or
  /// from its hook is drawn by the move.
  List<_Hung> _hungPoses(DoorwayDay day) {
    if (!_holdHooks && day.bowlPairs.contains(day.date)) return const [];
    final inMotion = {for (final m in _marks) m.ticket.id};
    final out = <_Hung>[];
    final layers = <int, int>{};
    for (final ticket in day.tickets) {
      final hook = ticket.hook;
      if (hook == null) continue;
      final layer = layers[hook] ?? 0;
      layers[hook] = layer + 1;
      if (inMotion.contains(ticket.id)) continue;
      final hang = doorwayHangFor(hook, layer: layer);
      final center = doorwayHangCenter(hang, hang.rest, doorwayTicketHeight);
      final rad = hang.rest * math.pi / 180;
      final off =
          (doorwayHookX[hang.hooks.$2] - doorwayHookX[hang.hooks.$1]) / 2;
      Offset corner(double lx) {
        const ly = -doorwayTicketHeight / 2 + 0.8;
        return Offset(
          center.dx + lx * math.cos(rad) - ly * math.sin(rad),
          center.dy + lx * math.sin(rad) + ly * math.cos(rad),
        );
      }

      out.add(
        _Hung(
          strings: [
            (Offset(doorwayHookX[hang.hooks.$1], doorwayHookY), corner(-off)),
            (Offset(doorwayHookX[hang.hooks.$2], doorwayHookY), corner(off)),
          ],
          widget: Positioned(
            key: ValueKey('doorway-hung-${ticket.id}'),
            left: center.dx - doorwayTicketWidth / 2,
            top: center.dy - doorwayTicketHeight / 2,
            width: doorwayTicketWidth,
            height: doorwayTicketHeight,
            child: Transform.rotate(
              angle: rad,
              child: DoorwayTicketView(ticket: ticket),
            ),
          ),
        ),
      );
    }
    return out;
  }

  /// The pairs of days lying low in the brass key bowl, their tops peeking
  /// over the rim.
  Widget _bowl(int pairs) {
    final shown = math.min(pairs, doorwayBowlPairs.length);
    final children = <Widget>[];
    final tone = doorwayTone(brightness: 0.8, saturation: 0.92);
    for (var q = 0; q < shown; q++) {
      for (var role = 0; role < 2; role++) {
        final back = role == 0;
        final (center, degrees) = doorwayBowlSlot(q, role);
        children.add(
          Positioned(
            key: ValueKey('doorway-bowl-$q-$role'),
            left: center.dx - doorwayTicketWidth / 2,
            top: center.dy - doorwayTicketHeight / 2,
            width: doorwayTicketWidth,
            height: doorwayTicketHeight,
            child: Transform.rotate(
              angle: degrees * math.pi / 180,
              child: Transform.scale(
                scale: doorwayBowlScale,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: ColorFiltered(
                        colorFilter: tone,
                        child: const DoorwaySprite(
                          asset: DoorwayAssets.ticketAttended,
                          shadow: Offset(0, 1.6),
                          blur: 1.2,
                          shadowColor: Color(0x8C140800),
                        ),
                      ),
                    ),
                    if (!back)
                      const Positioned(
                        left: -3.6,
                        top: -2.6,
                        child: DoorwayClip(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }
    // Only what shows above the rim: the bowl holds the rest.
    return Positioned(
      left: 0,
      top: 0,
      width: doorwayCanvasWidth,
      height: doorwayBowl.dy,
      child: Opacity(
        opacity: _tie == null ? 1 : _bowlOpacityNow(),
        child: ClipRect(
          key: const Key('doorway-bowl'),
          child: Stack(clipBehavior: Clip.none, children: children),
        ),
      ),
    );
  }

  /// The bowl's pairs fade out as the bundle that holds them rises.
  double _bowlOpacityNow() {
    final tie = _tie;
    if (tie == null) return 1;
    final reduce = widget.reduceMotion;
    final span = reduce ? doorwayFadeMs : 350.0;
    final from = tie.start - (reduce ? 100 : 420) + (reduce ? 0 : 150);
    return 1 - ((_ms - from) / span).clamp(0.0, 1.0);
  }

  // ── In flight ───────────────────────────────────────────────────────────

  Widget _inFlight(DoorwayDay day) {
    final reduce = widget.reduceMotion;
    final strings = <_MarkString>[];
    final tickets = <Widget>[];
    for (final m in _marks) {
      final age = _ms - m.start;
      if (age < 0) continue;
      final DoorwayPose pose;
      if (m.reverse) {
        final span = reduce ? doorwayFadeMs : doorwayHangMs;
        final back = (span - age).clamp(0.0, span);
        pose = doorwayMarkPose(
          reduce ? span : back,
          m.hang,
          from: m.from,
          fromKx: m.fromKx,
          fromKy: m.fromKy,
          reduce: reduce,
        );
        if (reduce) {
          final u = (1 - age / span).clamp(0.0, 1.0);
          tickets.add(
            _flyingTicket(m.ticket, pose, opacity: u, attended: true),
          );
          tickets.add(
            _flyingTicket(
              m.ticket,
              DoorwayPose(
                center: m.from,
                kx: m.fromKx,
                ky: m.fromKy,
                degrees: 0,
              ),
              opacity: 1 - u,
              rail: true,
            ),
          );
          continue;
        }
      } else if (age < doorwayHangMs || reduce) {
        pose = doorwayMarkPose(
          age,
          m.hang,
          from: m.from,
          fromKx: m.fromKx,
          fromKy: m.fromKy,
          dragOff: m.dragOff,
          reduce: reduce,
        );
        if (reduce) {
          tickets.add(
            _flyingTicket(
              m.ticket,
              DoorwayPose(center: m.from, kx: m.fromKx, ky: m.fromKy),
              opacity: doorwayMarkGhost(age),
              rail: true,
            ),
          );
        }
      } else {
        pose = doorwayHungPose(m.hang, sinceHung: age - doorwayHangMs);
      }
      for (final (a, b) in doorwayStringsFor(m.hang, pose)) {
        strings.add(_MarkString(a, b, pose.stringOpacity));
      }
      tickets.add(_flyingTicket(m.ticket, pose));
    }
    final drop = _drop;
    final bowlTickets = <Widget>[];
    if (drop != null) {
      final age = _ms - drop.start;
      for (final f in drop.flights) {
        final pose = doorwayDropPose(
          age,
          f.index,
          drop.pair,
          from: f.from,
          fromDegrees: f.fromDegrees,
          reduce: reduce,
        );
        if (pose.stringOpacity > 0.01) {
          for (final (a, b) in doorwayStringsFor(f.hang, pose)) {
            strings.add(_MarkString(a, b, pose.stringOpacity));
          }
        }
        if (reduce) {
          tickets.add(_flyingTicket(f.ticket, pose));
          bowlTickets.add(
            _flyingTicket(f.ticket, doorwayDropAppear(age, f.index, drop.pair)),
          );
        } else if (pose.mini > 0 || pose.center.dy > doorwayBowl.dy - 20) {
          bowlTickets.add(_flyingTicket(f.ticket, pose));
        } else {
          tickets.add(_flyingTicket(f.ticket, pose));
        }
      }
    }
    final tie = _tie;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (strings.isNotEmpty)
          Positioned.fill(
            child: CustomPaint(
              key: const Key('doorway-moving-strings'),
              painter: _MarkStrings(strings),
            ),
          ),
        ...tickets,
        if (bowlTickets.isNotEmpty)
          Positioned(
            left: 0,
            top: 0,
            width: doorwayCanvasWidth,
            height: doorwayBowl.dy,
            child: ClipRect(
              key: const Key('doorway-bowl-flight'),
              child: Stack(clipBehavior: Clip.none, children: bowlTickets),
            ),
          ),
        if (tie != null) _flyingBundle(tie, day),
      ],
    );
  }

  Widget _flyingTicket(
    DoorwayTicket ticket,
    DoorwayPose pose, {
    double? opacity,
    bool attended = false,
    bool rail = false,
  }) {
    final width = doorwayTicketWidth * pose.kx;
    final height = doorwayTicketHeight * pose.ky;
    Widget view = DoorwayTicketView(
      ticket: ticket,
      kx: pose.kx,
      ky: pose.ky,
      inRail: rail,
      attended: rail ? false : (pose.attended || attended),
      stamp: pose.patch ? pose.stamp : null,
      wordsOpacity: 1 - pose.mini,
      bowlShade: pose.mini,
    );
    if (pose.flip != 0) {
      view = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 1 / 300)
          ..rotateY(pose.flip * math.pi / 180),
        child: view,
      );
    }
    if (pose.clipped) {
      view = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: view),
          const Positioned(left: -3.6, top: -2.6, child: DoorwayClip()),
        ],
      );
    }
    final turn = Matrix4.identity()
      ..rotateZ(pose.degrees * math.pi / 180)
      ..scaleByDouble(pose.scale, pose.scale, 1, 1);
    final alpha = (opacity ?? pose.opacity).clamp(0.0, 1.0);
    return Positioned(
      key: ValueKey('doorway-moving-${ticket.id}-${rail ? 'rail' : 'wall'}'),
      left: pose.center.dx - width / 2,
      top: pose.center.dy - height / 2,
      width: width,
      height: height,
      child: Opacity(
        opacity: alpha,
        child: Transform(
          alignment: Alignment.center,
          transform: turn,
          child: view,
        ),
      ),
    );
  }

  /// The week's bundle rising from the bowl to the shelf, then its settle.
  Widget _flyingBundle(_Tie tie, DoorwayDay day) {
    final reduce = widget.reduceMotion;
    final kind = tie.index % doorwayBundleX.length;
    final size = doorwayBundleSizes[kind];
    final target = Offset(
      doorwayBundleX[kind],
      doorwayShelfTop - size.height / 2,
    );
    final age = _ms - tie.start;
    if (age < 0) return const SizedBox.shrink();
    final landedAt = tie.landedAt;
    double opacity;
    Offset center;
    double scale;
    double degrees;
    if (landedAt == null) {
      final pose = doorwayBundlePose(age, target, reduce: reduce);
      center = pose.center;
      scale = pose.scale;
      degrees = pose.degrees;
      opacity = pose.opacity;
    } else {
      final since = _ms - landedAt;
      center = target.translate(0, reduce ? 0 : -doorwayBundleSettle(since));
      scale = 1;
      degrees = 0;
      // A shelf that already stands full takes the bundle into its pile.
      opacity = tie.index >= doorwayBundleX.length
          ? 1 - (since / 420).clamp(0.0, 1.0)
          : 1;
    }
    return Positioned(
      key: const ValueKey('doorway-bundle-flight'),
      left: center.dx - size.width / 2,
      top: center.dy - size.height / 2,
      width: size.width,
      height: size.height,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: degrees * math.pi / 180,
          child: Transform.scale(
            scale: scale,
            child: _Bundle(kind: kind),
          ),
        ),
      ),
    );
  }
}

/// The painted week bundle (sprite chosen by its place on the shelf).
class _Bundle extends StatelessWidget {
  const _Bundle({this.kind = 0});

  final int kind;

  @override
  Widget build(BuildContext context) => DoorwaySprite(
    asset: DoorwayAssets.bundle[kind],
    tone: doorwayTone(brightness: 0.8, saturation: 0.92),
    shadow: const Offset(0, 1),
    blur: 0.5,
    shadowColor: const Color(0x80140800),
  );
}

/// Clips [top] points off the top of a ticket (the part still behind the
/// lip).
class _TopInset extends CustomClipper<Rect> {
  const _TopInset(this.top);

  final double top;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-8, top, size.width + 8, size.height + 8);

  @override
  bool shouldReclip(_TopInset old) => old.top != top;
}

/// A ticket's place on the wall at a moment of its glide.
class _Pose {
  const _Pose(
    this.center,
    this.kx,
    this.ky,
    this.opacity,
    this.dy,
    this.rotation, {
    this.enter = 1,
  });

  final Offset center;
  final double kx;
  final double ky;
  final double opacity;
  final double dy;
  final double rotation;

  /// 0 (still behind the lip) to 1 (clipped in).
  final double enter;

  _Pose faded(double opacity, double dy, double rotation) =>
      _Pose(center, kx, ky, opacity, dy, rotation);

  /// Under a finger: lifted by [dy], turned by [rotation], and a hair larger
  /// by [scale].
  _Pose dragged(double dy, double rotation, double scale) =>
      _Pose(center, kx * scale, ky * scale, opacity, this.dy + dy, rotation);

  static _Pose lerp(_Pose a, _Pose b, double t) => _Pose(
    Offset.lerp(a.center, b.center, t)!,
    a.kx + (b.kx - a.kx) * t,
    a.ky + (b.ky - a.ky) * t,
    a.opacity + (b.opacity - a.opacity) * t,
    a.dy + (b.dy - a.dy) * t,
    a.rotation + (b.rotation - a.rotation) * t,
  );
}

class _Leaving {
  const _Leaving(this.ticket, this.from, this.placed);

  final DoorwayTicket ticket;
  final _Pose from;
  final DoorwayPlacedTicket placed;
}

class _Hung {
  const _Hung({required this.strings, required this.widget});

  final List<(Offset, Offset)> strings;
  final Widget widget;
}

/// One string of a ticket in flight: hook to corner, and how visible.
class _MarkString {
  const _MarkString(this.from, this.to, this.opacity);

  final Offset from;
  final Offset to;
  final double opacity;
}

/// Draws the strings of the tickets in flight.
class _MarkStrings extends CustomPainter {
  const _MarkStrings(this.strings);

  final List<_MarkString> strings;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strings) {
      final a = s.opacity.clamp(0.0, 1.0);
      canvas.drawLine(
        s.from.translate(0.6, 1),
        s.to.translate(0.6, 1),
        Paint()
          ..color = const Color(0x731E0C02).withValues(alpha: 0.45 * a)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        s.from,
        s.to,
        Paint()
          ..color = const Color(0xFFE8D7AE).withValues(alpha: a)
          ..strokeWidth = 0.9
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_MarkStrings old) => true;
}

// ── Plate painter ─────────────────────────────────────────────────────────

/// The outdoors, the interior plate, the live beams and the lantern.
class _PlatePainter extends CustomPainter {
  _PlatePainter({required this.frame, required this.art})
    : super(repaint: Listenable.merge([frame, art]));

  final _Frame frame;
  final DoorwayArt art;

  static const _outdoorMatrix = <double>[
    // Saturate(.92): the exterior a touch softer than the painted interior.
    0.9378, 0.0572, 0.0050, 0, 0, //
    0.0170, 0.9780, 0.0050, 0, 0,
    0.0170, 0.0572, 0.9258, 0, 0,
    0, 0, 0, 1, 0,
  ];
  static const _outdoorTone = ColorFilter.matrix(_outdoorMatrix);

  /// The exterior's tone with its exposure raised by [air] (a mark opens the
  /// door's air: up to 25% brighter, then back).
  static ColorFilter _outdoorToneFor(double air) {
    if (air <= 0.001) return _outdoorTone;
    final k = 1 + 0.25 * air;
    return ColorFilter.matrix([
      for (var i = 0; i < _outdoorMatrix.length; i++)
        i % 5 < 3 ? _outdoorMatrix[i] * k : _outdoorMatrix[i],
    ]);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fades = frame.fades;
    final lights = frame.lights;
    final full =
        Offset.zero & const Size(doorwayCanvasWidth, doorwayCanvasHeight);
    // The exterior behind the panes: its own slow drift and the most tilt.
    final drift = frame.still
        ? 0.0
        : 2 * math.sin(2 * math.pi * frame.seconds / 120);
    final shift = Offset(
      frame.tilt.dx * _outdoorParallax + drift,
      frame.tilt.dy * 3.5,
    );
    final tone = _outdoorToneFor(frame.air);
    for (var k = 0; k < 3; k++) {
      final image = art[DoorwayAssets.outdoor[k]];
      if (fades[k] <= 0.0005 || image == null) continue;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        doorwayOutdoorRect.shift(shift),
        Paint()
          ..filterQuality = FilterQuality.medium
          ..colorFilter = tone
          ..color = Colors.white.withValues(alpha: fades[k]),
      );
    }
    for (var k = 0; k < 3; k++) {
      final image = art[DoorwayAssets.view[k]];
      if (fades[k] <= 0.0005 || image == null) continue;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        full,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Colors.white.withValues(alpha: fades[k]),
      );
    }
    // Live beams: laid over the painted shafts, additive and soft.
    final strength = [lights.midday * 0.68, lights.golden * 0.7];
    final grow = 1 + 0.012 * frame.air + 0.006 * frame.warm;
    for (var k = 0; k < 2; k++) {
      final image = art[DoorwayAssets.beam[k]];
      final opacity =
          (strength[k] * frame.beamK * (1 + 0.15 * frame.air + frame.warm))
              .clamp(0.0, 1.0);
      if (image == null || opacity <= 0.001) continue;
      canvas.save();
      canvas.translate(130, 230);
      canvas.scale(grow);
      canvas.translate(-130, -230);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        full,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..blendMode = BlendMode.screen
          ..color = Colors.white.withValues(alpha: opacity),
      );
      canvas.restore();
    }
    // The wall lantern at dusk: a small warm pool with a candle's flicker.
    if (lights.evening > 0.001) {
      final t = frame.seconds * 1000;
      final flick = frame.still
          ? 1.0
          : 1 + 0.03 * math.sin(t / 700) + 0.02 * math.sin(t / 230 + 1);
      final opacity = (lights.evening * 0.9 * flick * (1 + 0.2 * frame.air))
          .clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(doorwayLantern.dx, doorwayLantern.dy);
      canvas.scale(1, 90 / 70);
      canvas.drawCircle(
        Offset.zero,
        70,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = ui.Gradient.radial(
            Offset.zero,
            70,
            [
              const Color(0xFFFFC46E).withValues(alpha: 0.55 * opacity),
              const Color(0xFFFFAA50).withValues(alpha: 0.22 * opacity),
              const Color(0x00FF963C),
            ],
            const [0, 0.45, 1],
          ),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PlatePainter old) => old.frame != frame || old.art != art;
}
