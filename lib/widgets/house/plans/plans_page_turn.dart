// A soft page turn: the old page lets go, the new page comes up, and a
// page-curl shadow sweeps across the paper between them.
//
// No blur and no flip. The turn is a cross-fade (the old page is gone a little
// before the new one is whole, so two lines of text never sit on top of one
// another) with a few points of drift the way the paper moves, and a band of
// shade and light that runs across the page: right to left when the book turns
// forward (later days, toward the month), left to right when it turns back.
// With Reduce Motion the turn is a plain 200 ms cross-fade and no curl.
//
// The timings are the approved prototype's: 620 ms, the curl peaking in the
// middle of the turn.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../room_travel.dart' show RoomTravel;

/// How long a page turn takes, and a Reduce Motion cross-fade.
const plansTurnDuration = Duration(milliseconds: 620);
const plansTurnReducedDuration = Duration(milliseconds: 200);

/// How far a turning page drifts, in points.
const plansTurnDrift = 6.0;

/// How opaque the old page is at [u] (0 to 1 through the turn). The turn is
/// eased like the page itself: the old page is gone a little before the half
/// way, and the new one is not there yet, so for a moment the paper is bare
/// and two lines of text never sit on top of one another.
double plansTurnOut(double u) =>
    (1 - Curves.easeInOut.transform(u.clamp(0.0, 1.0)) * 2.2).clamp(0.0, 1.0);

/// How opaque the new page is at [u]: it begins just after the half way.
double plansTurnIn(double u) =>
    (Curves.easeInOut.transform(u.clamp(0.0, 1.0)) * 2.2 - 1.2).clamp(0.0, 1.0);

/// How strong the curl's shade is at [u]: nothing at the ends, strongest in
/// the middle.
double plansCurlStrength(double u) =>
    (math.pow(math.sin(math.pi * u.clamp(0.0, 1.0)), 0.8) * 0.95).toDouble();

/// Where the curl band's left edge is, relative to the curl rectangle, at [u]:
/// from the right edge to past the binding when [forward], the other way when
/// not (the band is 130 pt wide).
double plansCurlLeft(double u, {required bool forward}) {
  final eased = Curves.easeInOut.transform(u.clamp(0.0, 1.0));
  return forward ? 240 + (-92 - 240) * eased : -92 + (240 + 92) * eased;
}

/// The curl band's width in points.
const plansCurlBand = 130.0;

/// Whether this turn should be a still cross-fade.
bool plansStill(BuildContext context, bool? reduceMotion) =>
    reduceMotion ??
    (RoomTravel.reduceMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false));

/// Turns between pages. When [turnKey] changes the old page (the last [child]
/// it was given) turns away and the new one turns in; [order] says which way
/// (a larger order than before is forward).
class PlansPageTurn extends StatefulWidget {
  const PlansPageTurn({
    super.key,
    required this.turnKey,
    required this.order,
    required this.child,
    this.curl,
    this.reduceMotion,
    this.animate = true,
    this.duration = plansTurnDuration,
  });

  /// Identifies the page. A different key is a different page.
  final Object turnKey;

  /// The page's place in the book: larger is later.
  final double order;

  final Widget child;

  /// Where the curl runs (the part of the paper it sweeps), in this widget's
  /// own coordinates. Null: no curl.
  final Rect? curl;

  /// Null reads the app's and the system's Reduce Motion.
  final bool? reduceMotion;

  /// Whether a change of page turns. A change that arrives while this goes
  /// from false to true (the room finding its saved view as it opens) swaps
  /// the page without a turn.
  final bool animate;

  final Duration duration;

  @override
  State<PlansPageTurn> createState() => _PlansPageTurnState();
}

class _PlansPageTurnState extends State<PlansPageTurn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  Widget? _outgoing;
  Object? _outgoingKey;
  bool _forward = true;
  bool _stillTurn = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && _outgoing != null) {
        setState(() {
          _outgoing = null;
          _outgoingKey = null;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant PlansPageTurn old) {
    super.didUpdateWidget(old);
    if (old.turnKey == widget.turnKey) return;
    if (!(old.animate && widget.animate)) {
      _outgoing = null;
      _outgoingKey = null;
      return;
    }
    _outgoing = old.child;
    _outgoingKey = old.turnKey;
    _forward = widget.order >= old.order;
    _stillTurn = plansStill(context, widget.reduceMotion);
    _controller.duration = _stillTurn
        ? plansTurnReducedDuration
        : widget.duration;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _layer(Object key, double opacity, double dx, Widget child) =>
      KeyedSubtree(
        key: ValueKey(key),
        child: Opacity(
          opacity: opacity,
          child: Transform.translate(offset: Offset(dx, 0), child: child),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // On the frame the turn finishes the old page is already gone; the
        // state lets go of it a frame later.
        final turning = _outgoing != null && !_controller.isCompleted;
        final u = turning ? _controller.value : 1.0;
        final drift = _stillTurn ? 0.0 : plansTurnDrift;
        final toward = _forward ? -1.0 : 1.0;
        final outgoing = turning ? _outgoing : null;
        final children = <Widget>[
          if (outgoing != null)
            _layer(
              _outgoingKey!,
              _stillTurn ? 1 - u : plansTurnOut(u),
              toward * drift * u,
              ExcludeSemantics(child: IgnorePointer(child: outgoing)),
            ),
          _layer(
            widget.turnKey,
            !turning
                ? 1
                : _stillTurn
                ? u
                : plansTurnIn(u),
            !turning ? 0 : -toward * drift * (1 - u),
            widget.child,
          ),
          if (turning && !_stillTurn && widget.curl != null)
            Positioned.fromRect(
              rect: widget.curl!,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: PlansCurlPainter(u: u, forward: _forward),
                ),
              ),
            ),
        ];
        return Stack(clipBehavior: Clip.none, children: children);
      },
    );
  }
}

/// The page-curl shadow: a band that is shade on its leading side and a thin
/// catch of light behind it, the prototype's gradient.
class PlansCurlPainter extends CustomPainter {
  const PlansCurlPainter({required this.u, required this.forward});

  final double u;
  final bool forward;

  @override
  void paint(Canvas canvas, Size size) {
    final strength = plansCurlStrength(u);
    if (strength <= 0.001) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final left = plansCurlLeft(u, forward: forward);
    final band = Rect.fromLTRB(
      left,
      -10,
      left + plansCurlBand,
      size.height + 10,
    );
    // Shade first, then the light behind it (reversed when turning back, so
    // the light always trails the shade).
    final colors = <Color>[
      const Color(0x00281608),
      const Color(0x2B281608),
      const Color(0x85281608),
      const Color(0x52FFF8E6),
      const Color(0x0FFFF8E6),
      const Color(0x00281608),
    ];
    const stops = <double>[0, 0.22, 0.55, 0.66, 0.82, 1];
    final paint = Paint()
      ..shader = LinearGradient(
        begin: forward ? Alignment.centerLeft : Alignment.centerRight,
        end: forward ? Alignment.centerRight : Alignment.centerLeft,
        colors: [for (final c in colors) c.withValues(alpha: c.a * strength)],
        stops: stops,
      ).createShader(band);
    canvas.drawRect(band, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PlansCurlPainter old) =>
      old.u != u || old.forward != forward;
}
