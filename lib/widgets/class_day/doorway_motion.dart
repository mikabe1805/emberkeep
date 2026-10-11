// The Doorway's motion, as pure functions of time.
//
// A ticket's trip from its holder to its hook, from the hook into the key
// bowl, and a week's bundle from the bowl to the shelf are each a pose that
// depends only on the milliseconds since the trip began. That is what makes
// an undo honest (it is the same function run backwards) and what lets a test
// ask where a ticket is at 420 ms without pumping a ticker.
//
// The timings are the approved prototype's, unchanged:
//
//   mark      0 ms the ticket unclips; 60 to 420 it lifts from behind the brass
//             lip and turns over (the face swaps at the half turn); the stamp
//             lands at 420; it arcs to its hook by 900, the strings growing
//             straight down from the hook; a damped pendulum then settles by
//             about 1.8 s. The air reacts from 100 to 700 ms.
//   day       about 1.9 s after the last counting ticket hung, the hanging
//             tickets unhook, clip together and arc down into the bowl (900
//             ms) while the beam warms for a breath.
//   week      the bowl's pairs are tied: a bundle rises from the bowl to the
//             shelf (1.1 s) and settles with a soft wooden bounce.
//
// Reduce Motion has none of the turn, the arc, the swing or the flight: every
// move is a cross-fade between the two places, in about a quarter second.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'doorway_art.dart';
import 'doorway_rail.dart';

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double _lerp(double a, double b, double t) => a + (b - a) * t;
double _eo(double t) => 1 - math.pow(1 - t, 3).toDouble();
double _eio(double t) =>
    t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3).toDouble() / 2;

/// The moves the room waits on, as the stage reports them.
enum DoorwayBeat {
  /// A marked ticket is on its hook.
  hung,

  /// Its swing has settled.
  settled,

  /// The day's tickets have landed in the bowl, and the beam has had its
  /// breath: the day's moment may show.
  dayDone,

  /// The week's bundle stands on the shelf: the week's moment may show.
  weekDone,
}

// ── Times (milliseconds) ─────────────────────────────────────────────────

/// The ticket leaves its holder (the rail closes the gap from here).
const double doorwayLeaveMs = 420;

/// The stamp lands (a medium detent).
const double doorwayStampMs = 420;

/// The ticket is on its hook and begins to swing.
const double doorwayHangMs = 900;

/// The pendulum has settled this long after the ticket hung.
const double doorwaySwingMs = 1900;

/// A completed day's tickets drop into the bowl this long after the mark that
/// completed it began.
const double doorwayDropAfterMs = 1900;

/// The drop's flight (unhook, clip, arc) and a week bundle's flight.
const double doorwayDropMs = 900;
const double doorwayBundleMs = 1100;

/// The day card waits this long after the tickets land in the bowl; the week
/// card, this long after the bundle settles on the shelf.
const double doorwayDayCardMs = 500;
const double doorwayWeekCardMs = 1100;

/// A Reduce Motion move: a cross-fade.
const double doorwayFadeMs = 260;

/// A shortcut that keeps several classes starts each ticket's mark this long
/// after the one before it.
const double doorwayShortcutStepMs = 180;

/// How long after a mark gesture the last class chime has finished hanging:
/// the earliest moment the room's music may answer without landing on it. The
/// hang is at [doorwayHangMs] (a cross-fade's [doorwayFadeMs] under Reduce
/// Motion), the shortcut's later tickets hang [doorwayShortcutStepMs] apart,
/// and 50 ms is left clear of the chime's attack.
Duration doorwayChimeDoneAfter({required bool reduceMotion, int tickets = 1}) =>
    Duration(
      milliseconds:
          ((reduceMotion ? doorwayFadeMs : doorwayHangMs) +
                  50 +
                  doorwayShortcutStepMs * (tickets < 1 ? 0 : tickets - 1))
              .round(),
    );

// ── Ease ─────────────────────────────────────────────────────────────────

/// Where a ticket is at one moment of a trip. Every number is in the stage's
/// own points and degrees.
final class DoorwayPose {
  const DoorwayPose({
    required this.center,
    this.degrees = 0,
    this.scale = 1,
    this.flip = 0,
    this.kx = 1,
    this.ky = 1,
    this.attended = false,
    this.stamp = 0,
    this.patch = false,
    this.grow = 0,
    this.follow = 0,
    this.stringOpacity = 0,
    this.opacity = 1,
    this.mini = 0,
    this.clipped = false,
  });

  final Offset center;

  /// The ticket's tilt on the wall (degrees).
  final double degrees;
  final double scale;

  /// The turn about the vertical axis (degrees, -90 to 90).
  final double flip;

  /// How the card's art is stretched from full size.
  final double kx;
  final double ky;

  /// Which face shows: the attended one once it has turned over.
  final bool attended;

  /// The stamp's progress (0 to 1) while it lands over a patch of paper.
  final double stamp;
  final bool patch;

  /// How far the strings have grown down from the hooks (0 to 1), how far
  /// their ends have joined the ticket's corners (0 to 1), and their opacity.
  final double grow;
  final double follow;
  final double stringOpacity;

  final double opacity;

  /// 0 (a full ticket) to 1 (a small one lying in the bowl: no words, shaded).
  final double mini;

  /// Clipped to its pair's front ticket (the brass clip is on).
  final bool clipped;
}

/// A hung ticket's swing (degrees) [tau] ms after it arrived: a damped
/// pendulum that starts at rest with velocity.
double doorwaySwing(double tau) {
  if (tau < 0) return 0;
  final t = tau / 1000;
  const w = 2 * math.pi / 0.95;
  const z = 0.3;
  final wd = w * math.sqrt(1 - z * z);
  return -11 * math.exp(-z * w * t) * math.sin(wd * t);
}

/// The center of a ticket hung on [hang] at [degrees] (the hang's own).
Offset _hangAt(DoorwayHang hang, double degrees) =>
    doorwayHangCenter(hang, degrees, doorwayTicketHeight);

/// A ticket hanging at rest or swinging, [sinceHung] ms after it arrived.
DoorwayPose doorwayHungPose(DoorwayHang hang, {double sinceHung = 1e9}) {
  final degrees = hang.rest + doorwaySwing(sinceHung);
  return DoorwayPose(
    center: _hangAt(hang, degrees),
    degrees: degrees,
    attended: true,
    stamp: 1,
    grow: 1,
    follow: 1,
    stringOpacity: 1,
  );
}

/// The mark: a ticket standing at [from] (with the stretch [fromKx] x
/// [fromKy] its holder gives it) becomes a ticket on [hang], [ms] after the
/// mark began. [dragOff] is how far a drag had already lifted it.
DoorwayPose doorwayMarkPose(
  double ms,
  DoorwayHang hang, {
  required Offset from,
  double fromKx = 1,
  double fromKy = 1,
  double dragOff = 0,
  bool reduce = false,
}) {
  final hc = _hangAt(hang, hang.rest);
  if (reduce) {
    // No turn, no arc, no swing: the ticket on its hook fades in as the one
    // in the holder fades out (see [doorwayMarkGhost]).
    final u = _clamp01(ms / doorwayFadeMs);
    return DoorwayPose(
      center: hc,
      degrees: hang.rest,
      attended: true,
      stamp: 1,
      grow: 1,
      follow: 1,
      stringOpacity: u,
      opacity: u,
    );
  }
  var x = from.dx;
  var y = from.dy;
  var rot = 0.0;
  var scale = 1.0;
  if (ms < 60) {
    final u = _eo(ms / 60);
    y = from.dy - 2 * u;
    rot = -3 * u;
  } else {
    final u = _eo(_clamp01((ms - 60) / 360));
    y = from.dy - 2 - 8 * u;
    scale = 1 + 0.04 * u;
    rot = -3 + 2 * u;
  }
  final ke = _eo(_clamp01((ms - 60) / 360));
  final kx = _lerp(fromKx, 1, ke);
  final ky = _lerp(fromKy, 1, ke);
  final turn = _clamp01((ms - 100) / 280);
  var flip = 0.0;
  var attended = false;
  if (turn > 0) {
    flip = turn < 0.5 ? 180 * turn : 180 * turn - 180;
    attended = turn >= 0.5;
  }
  final stamp = _clamp01((ms - 420) / 180);
  if (ms > 420) {
    final u = _clamp01((ms - 420) / 480);
    final e = _eio(u);
    x = _lerp(from.dx, hc.dx, e);
    y = _lerp(from.dy - 10, hc.dy, e) - 12 * math.sin(math.pi * u);
    rot = _lerp(-1, hang.rest, e);
    scale = _lerp(1.04, 1, e);
  }
  final grow = _eo(_clamp01((ms - 480) / 320));
  y += dragOff * (1 - _eo(_clamp01(ms / 220)));
  return DoorwayPose(
    center: Offset(x, y),
    degrees: rot,
    scale: scale,
    flip: flip,
    kx: kx,
    ky: ky,
    attended: attended,
    stamp: stamp,
    patch: attended && ms < 600,
    grow: grow,
    follow: _clamp01((ms - 760) / 140),
    stringOpacity: _clamp01((ms - 480) / 160),
  );
}

/// Under Reduce Motion, the ticket still in its holder while the one on the
/// hook fades in: its opacity [ms] after the mark began.
double doorwayMarkGhost(double ms) => 1 - _clamp01(ms / doorwayFadeMs);

/// Where the strings of a ticket in [pose] run, hook to corner (points):
/// they grow straight down from the hooks, then follow the ticket's top
/// corners. Empty before they show.
List<(Offset, Offset)> doorwayStringsFor(DoorwayHang hang, DoorwayPose pose) {
  final g = pose.grow;
  if (pose.stringOpacity < 0.01 || g < 0.01) return const [];
  final a = doorwayHookX[hang.hooks.$1];
  final b = doorwayHookX[hang.hooks.$2];
  final off = (b - a) / 2;
  const ly = -doorwayTicketHeight / 2 + 0.8;
  Offset corner(Offset c, double degrees, double lx) {
    final r = degrees * math.pi / 180;
    return Offset(
      c.dx + lx * math.cos(r) - ly * math.sin(r),
      c.dy + lx * math.sin(r) + ly * math.cos(r),
    );
  }

  final rc = _hangAt(hang, hang.rest);
  final ra = corner(rc, hang.rest, -off);
  final rb = corner(rc, hang.rest, off);
  final pa = corner(pose.center, pose.degrees, -off);
  final pb = corner(pose.center, pose.degrees, off);
  final gk = pose.follow;
  Offset end(double hookX, Offset rest, Offset live) => Offset(
    _lerp(hookX + g * (rest.dx - hookX), live.dx, gk),
    _lerp(doorwayHookY + g * (rest.dy - doorwayHookY), live.dy, gk),
  );
  return [
    (Offset(a, doorwayHookY), end(a, ra, pa)),
    (Offset(b, doorwayHookY), end(b, rb, pb)),
  ];
}

// ── Into the bowl ────────────────────────────────────────────────────────

/// Where a small ticket lies in the bowl: the pair [pair] (its place among
/// the week's days) and its [role] (0 the one behind, 1 the one in front,
/// which wears the clip). Degrees included.
(Offset, double) doorwayBowlSlot(int pair, int role) {
  final (offset, degrees) = doorwayBowlPairs[pair % doorwayBowlPairs.length];
  final r = degrees * math.pi / 180;
  final cs = math.cos(r);
  final sn = math.sin(r);
  final back = role == 0;
  final ox = back ? -1.4 : 0.0;
  final oy = back ? -1.7 : 0.0;
  return (
    Offset(
      doorwayBowl.dx + offset.dx + ox * cs - oy * sn,
      doorwayBowl.dy + offset.dy + ox * sn + oy * cs,
    ),
    degrees + (back ? -3.2 : 0),
  );
}

/// The drop: a hung ticket at [from] (at [fromDegrees]) unhooks, clips to its
/// pair and arcs into the bowl's [pair], its [index]th ticket of the day,
/// [ms] after it began. Under Reduce Motion it fades out where it hangs; the
/// one in the bowl fades in ([doorwayDropAppear]).
DoorwayPose doorwayDropPose(
  double ms,
  int index,
  int pair, {
  required Offset from,
  required double fromDegrees,
  bool reduce = false,
}) {
  final role = index == 0 ? 0 : 1;
  final (slot, slotDegrees) = doorwayBowlSlot(pair, role);
  if (reduce) {
    final u = _clamp01(ms / doorwayFadeMs);
    return DoorwayPose(
      center: from,
      degrees: fromDegrees,
      attended: true,
      stamp: 1,
      grow: 1,
      follow: 1,
      stringOpacity: 1 - u,
      opacity: 1 - u,
    );
  }
  final k = index % 2;
  final mx = 328.0 + k * 2;
  final my = 236.0 + k * 2.5;
  final tilt = k == 1 ? 0.8 : -0.8;
  if (ms < 260) {
    final u = _eo(ms / 260);
    return DoorwayPose(
      center: Offset(_lerp(from.dx, mx, u), _lerp(from.dy, my - 3, u)),
      degrees: _lerp(fromDegrees, tilt, u),
      attended: true,
      stamp: 1,
      grow: 1,
      follow: 1,
      stringOpacity: 1 - u,
      clipped: k == 1 && ms >= 170,
    );
  }
  final u = _clamp01((ms - 260) / 640);
  final ex = _eio(u);
  final ey = math.pow(u, 2.1).toDouble();
  final x = _lerp(mx, slot.dx, ex);
  final y =
      _lerp(my - 3, slot.dy, ey) -
      6 * math.sin(math.pi * math.min(1.0, u * 1.4)) * (1 - u);
  return DoorwayPose(
    center: Offset(x, y),
    degrees: _lerp(tilt, slotDegrees, _eio(u)),
    scale: _lerp(1, doorwayBowlScale, _eio(_clamp01(u * 1.15))),
    attended: true,
    stamp: 1,
    mini: _clamp01((u - 0.4) / 0.25),
    clipped: k == 1,
    // A ticket beyond the pair's two tucks in behind it as it lands.
    opacity: index >= 2 ? 1 - _clamp01((u - 0.7) / 0.3) : 1,
  );
}

/// Under Reduce Motion, the small ticket lying in the bowl, fading in
/// [ms] after the drop began.
DoorwayPose doorwayDropAppear(double ms, int index, int pair) {
  final role = index == 0 ? 0 : 1;
  final (slot, degrees) = doorwayBowlSlot(pair, role);
  return DoorwayPose(
    center: slot,
    degrees: degrees,
    scale: doorwayBowlScale,
    attended: true,
    stamp: 1,
    mini: 1,
    clipped: role == 1,
    opacity: index >= 2 ? 0 : _clamp01(ms / doorwayFadeMs),
  );
}

// ── Up to the shelf ──────────────────────────────────────────────────────

/// A week's bundle on its way up: where it is, [ms] after it set out.
final class DoorwayBundlePose {
  const DoorwayBundlePose({
    required this.center,
    this.scale = 1,
    this.degrees = 0,
    this.opacity = 1,
    this.landed = false,
  });

  final Offset center;
  final double scale;
  final double degrees;
  final double opacity;

  /// It has reached its place (the settle bounce follows).
  final bool landed;
}

/// The bundle's flight from the bowl to [target] (its center on the shelf).
DoorwayBundlePose doorwayBundlePose(
  double ms,
  Offset target, {
  bool reduce = false,
}) {
  if (reduce) {
    final u = _clamp01(ms / doorwayFadeMs);
    return DoorwayBundlePose(center: target, opacity: u, landed: u >= 1);
  }
  final u = _clamp01(ms / doorwayBundleMs);
  final e = _eio(u);
  return DoorwayBundlePose(
    center: Offset(
      _lerp(doorwayBowl.dx, target.dx, e) - 5 * math.sin(math.pi * e),
      _lerp(doorwayBowl.dy - 12, target.dy, e),
    ),
    scale: _lerp(0.8, 1, e),
    degrees: 3 * math.sin(2 * math.pi * u) * (1 - u),
    opacity: _clamp01(ms / 160),
    landed: u >= 1,
  );
}

/// How far a landed bundle bounces up (points) [ms] after it arrived: a soft
/// wooden settle.
double doorwayBundleSettle(double ms) {
  if (ms < 0 || ms >= 420) return 0;
  return 2.4 * math.sin(math.pi * ms / 170) * math.exp(-ms / 110);
}

// ── Light and dust ───────────────────────────────────────────────────────

/// A bump in the light: a half sine over [duration] ms from [start], of
/// height [amount].
double doorwayBump(double now, double start, double duration, double amount) {
  if (now < start || now > start + duration) return 0;
  return amount * math.sin(math.pi * (now - start) / duration);
}

/// The dust's one gust [ms] after it started (0 to 1): a quick rise and a slow
/// settle.
double doorwayGust(double ms) {
  if (ms < 0) return 0;
  final t = ms / 1000;
  if (t > 3) return 0;
  return math.exp(-t / 0.55) * math.min(1.0, t / 0.08);
}

/// How the door's air reacts to a mark that began at [start], [now] ms on:
/// the exterior and the glass brighten (up to 25%) and the beams brighten
/// (about 15%) and widen, from 100 to 700 ms, once.
double doorwayAirAt(double now, double start) =>
    doorwayBump(now, start + 100, 600, 1);
