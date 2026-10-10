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
import 'doorway_dust.dart';
import 'doorway_light.dart';
import 'doorway_model.dart';
import 'doorway_rail.dart';
import 'doorway_tickets.dart';

/// How far the tilt moves the interior and the exterior (points at full tilt):
/// the plate barely moves, the outdoors travels a few points.
const double _plateParallax = 1.7;
const double _outdoorParallax = 5.5;

/// The wall is drawn a hair over size so its parallax never shows an edge.
const double _plateOverscan = 1.015;

/// How long a ticket takes to glide to a new place on the wall.
const Duration doorwayGlide = Duration(milliseconds: 420);

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
  });

  final DoorwayDay day;

  /// The shell's tilt (accelerometer) source, each axis -1 to 1.
  final ValueListenable<Offset>? parallax;

  /// Stills the ambient motion and the tilt.
  final bool reduceMotion;

  /// How far down the soft dark under the status bar and the HUD reaches.
  final double scrimHeight;

  /// The moment the light is read at; the app's clock when null.
  final DateTime? now;

  /// A shared art loader (tests); the stage makes its own when null.
  final DoorwayArt? art;

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

class DoorwayStageState extends State<DoorwayStage>
    with TickerProviderStateMixin {
  late DoorwayArt _art;
  bool _ownsArt = false;
  final _Frame _frame = _Frame();
  final _RailFrame _rail = _RailFrame();
  final DoorwayDust _dust = DoorwayDust();
  Ticker? _ticker;
  Timer? _minute;
  Duration _last = Duration.zero;
  Duration _lastPaint = Duration.zero;
  Offset _tilt = Offset.zero;

  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: doorwayGlide,
    value: 1,
  )..addListener(_onGlide);

  late DoorwayRailLayout _layout;
  late List<DoorwayHolder> _holdersFrom;
  Map<String, _Pose> _poseFrom = const {};
  List<_Leaving> _leaving = const [];

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
    if (!_sameLayout(_layout, next)) _relayout(next);
    _refresh(_frame.seconds, notify: false);
    _rail.railHolders = doorwayRailBlend(
      _holdersFrom,
      _layout.holders,
      _glide.value,
    );
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
    super.dispose();
  }

  // ── Motion ──────────────────────────────────────────────────────────────

  void _syncMotion() {
    final still = widget.reduceMotion;
    _frame.still = still;
    _glide.duration = still ? Duration.zero : doorwayGlide;
    if (still) {
      _ticker?.stop();
      _ticker?.dispose();
      _ticker = null;
      _tilt = Offset.zero;
      _minute ??= Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) _refresh(0);
      });
    } else {
      _minute?.cancel();
      _minute = null;
      if (_ticker == null) {
        _last = Duration.zero;
        _lastPaint = Duration.zero;
        _ticker = createTicker(_onTick)..start();
      }
    }
  }

  void _onTick(Duration elapsed) {
    final since = (elapsed - _lastPaint).inMilliseconds;
    // About thirty paints a second is plenty for light that breathes over
    // eight seconds and dust that drifts.
    if (since < 30 && _lastPaint != Duration.zero) return;
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
      ..still = still;
    _wantArt(lights);
    if (!still && dt > 0) _dust.step(dt, lights, _frame.beamK);
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

  void _relayout(DoorwayRailLayout next) {
    final u = _glide.value;
    // Where everything is drawn right now becomes where it glides from.
    _holdersFrom = doorwayRailBlend(_holdersFrom, _layout.holders, u);
    final from = <String, _Pose>{};
    for (final placed in _layout.placed) {
      final pose = _poseOf(placed.ticket.id, u);
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
    _layout = next;
    _poseFrom = from;
    _leaving = leaving;
    if (widget.reduceMotion) {
      _glide.value = 1;
    } else {
      _glide.forward(from: 0);
    }
    _onGlide();
  }

  void _onGlide() {
    _rail
      ..railHolders = doorwayRailBlend(
        _holdersFrom,
        _layout.holders,
        _glide.value,
      )
      ..changed();
    if (_glide.isCompleted) {
      _holdersFrom = _layout.holders;
      _leaving = const [];
    }
  }

  /// Where [id]'s card is at glide value [u], or null if it has none.
  _Pose? _poseOf(String id, double u) {
    DoorwayPlacedTicket? target;
    for (final placed in _layout.placed) {
      if (placed.ticket.id == id) target = placed;
    }
    if (target == null) return null;
    final to = _Pose(target.center, target.kx, target.ky, 1, 0, 0);
    final from = _poseFrom[id];
    if (u >= 1) return to;
    final e = Curves.easeInOut.transform(u);
    if (from == null) {
      // Clipped in from just above the rail with a tiny settle.
      final slide = Curves.easeOutBack.transform(u);
      return _Pose(
        target.center,
        target.kx,
        target.ky,
        Curves.easeOut.transform(u),
        -10 * (1 - slide),
        0,
      );
    }
    return _Pose.lerp(from, to, e);
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final layout = _layout;
    return ExcludeSemantics(
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
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _PlatePainter(frame: _frame, art: _art),
            ),
          ),
        ),
        Positioned.fill(child: RepaintBoundary(child: _objects(day, layout))),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: DoorwayDustPainter(dust: _dust, repaint: _frame),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _objects(DoorwayDay day, DoorwayRailLayout layout) {
    final hung = _hungPoses(day);
    final inBowl = day.bowlPairs.length;
    final bundles = day.shelfBundles.length;
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
          ..._shelf(day, bundles),
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
            animation: _glide,
            builder: (context, _) => Stack(
              clipBehavior: Clip.none,
              children: [
                for (final leaving in _leaving) _leavingTicket(leaving),
                for (final placed in layout.placed) _railTicket(placed),
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
        ],
      ),
    );
  }

  Widget _railTicket(DoorwayPlacedTicket placed) {
    final pose =
        _poseOf(placed.ticket.id, _glide.value) ??
        _Pose(placed.center, placed.kx, placed.ky, 1, 0, 0);
    return _placeTicket(
      DoorwayTicketView(
        ticket: placed.ticket,
        kx: pose.kx,
        ky: pose.ky,
        inRail: true,
      ),
      pose,
    );
  }

  Widget _leavingTicket(_Leaving leaving) {
    final e = Curves.easeIn.transform(_glide.value);
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
    return Positioned(
      left: pose.center.dx - width / 2,
      top: pose.center.dy - height / 2 + pose.dy,
      width: width,
      height: height,
      child: Opacity(
        opacity: pose.opacity.clamp(0.0, 1.0),
        child: pose.rotation == 0
            ? view
            : Transform.rotate(
                angle: pose.rotation * math.pi / 180,
                child: view,
              ),
      ),
    );
  }

  List<Widget> _shelf(DoorwayDay day, int weeks) {
    final shown = math.min(weeks, doorwayBundleX.length);
    final label = day.shelfLabel;
    return [
      for (var i = 0; i < shown; i++)
        Positioned(
          key: ValueKey('doorway-bundle-$i'),
          left: doorwayBundleX[i] - doorwayBundleSizes[i].width / 2,
          top: doorwayShelfTop - doorwayBundleSizes[i].height,
          width: doorwayBundleSizes[i].width,
          height: doorwayBundleSizes[i].height,
          child: DoorwaySprite(
            asset: DoorwayAssets.bundle[i],
            tone: doorwayTone(brightness: 0.8, saturation: 0.92),
            shadow: const Offset(0, 1),
            blur: 0.5,
            shadowColor: const Color(0x80140800),
          ),
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
  /// have gone into the bowl hangs nothing.
  List<_Hung> _hungPoses(DoorwayDay day) {
    if (day.bowlPairs.contains(day.date)) return const [];
    final out = <_Hung>[];
    final layers = <int, int>{};
    for (final ticket in day.tickets) {
      final hook = ticket.hook;
      if (hook == null) continue;
      final layer = layers[hook] ?? 0;
      layers[hook] = layer + 1;
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

  /// The pairs of earlier days lying low in the brass key bowl, their tops
  /// peeking over the rim.
  Widget _bowl(int pairs) {
    final shown = math.min(pairs, doorwayBowlPairs.length);
    final children = <Widget>[];
    const tone = ColorFilter.matrix(<double>[
      0.8, 0, 0, 0, 0, //
      0, 0.8, 0, 0, 0,
      0, 0, 0.8, 0, 0,
      0, 0, 0, 1, 0,
    ]);
    for (var q = 0; q < shown; q++) {
      final (offset, degrees) = doorwayBowlPairs[q];
      final r = degrees * math.pi / 180;
      final cs = math.cos(r);
      final sn = math.sin(r);
      for (var role = 0; role < 2; role++) {
        final back = role == 0;
        final ox = back ? -1.4 : 0.0;
        final oy = back ? -1.7 : 0.0;
        final center = Offset(
          doorwayBowl.dx + offset.dx + ox * cs - oy * sn,
          doorwayBowl.dy + offset.dy + ox * sn + oy * cs,
        );
        final turn = r + (back ? -3.2 * math.pi / 180 : 0);
        children.add(
          Positioned(
            key: ValueKey('doorway-bowl-$q-$role'),
            left: center.dx - doorwayTicketWidth / 2,
            top: center.dy - doorwayTicketHeight / 2,
            width: doorwayTicketWidth,
            height: doorwayTicketHeight,
            child: Transform.rotate(
              angle: turn,
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
      child: ClipRect(
        key: const Key('doorway-bowl'),
        child: Stack(clipBehavior: Clip.none, children: children),
      ),
    );
  }
}

/// A ticket's place on the wall at a moment of its glide.
class _Pose {
  const _Pose(
    this.center,
    this.kx,
    this.ky,
    this.opacity,
    this.dy,
    this.rotation,
  );

  final Offset center;
  final double kx;
  final double ky;
  final double opacity;
  final double dy;
  final double rotation;

  _Pose faded(double opacity, double dy, double rotation) =>
      _Pose(center, kx, ky, opacity, dy, rotation);

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

// ── Plate painter ─────────────────────────────────────────────────────────

/// The outdoors, the interior plate, the live beams and the lantern.
class _PlatePainter extends CustomPainter {
  _PlatePainter({required this.frame, required this.art})
    : super(repaint: Listenable.merge([frame, art]));

  final _Frame frame;
  final DoorwayArt art;

  static const _outdoorTone = ColorFilter.matrix(<double>[
    // Saturate(.92): the exterior a touch softer than the painted interior.
    0.9378, 0.0572, 0.0050, 0, 0, //
    0.0170, 0.9780, 0.0050, 0, 0,
    0.0170, 0.0572, 0.9258, 0, 0,
    0, 0, 0, 1, 0,
  ]);

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
    for (var k = 0; k < 3; k++) {
      final image = art[DoorwayAssets.outdoor[k]];
      if (fades[k] <= 0.0005 || image == null) continue;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        doorwayOutdoorRect.shift(shift),
        Paint()
          ..filterQuality = FilterQuality.medium
          ..colorFilter = _outdoorTone
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
      final opacity = (lights.evening * 0.9 * flick).clamp(0.0, 1.0);
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
