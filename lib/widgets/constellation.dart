import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../tokens.dart';

/// THE HISTORY CONSTELLATION — a persistent trace of lifetime effort
/// (ROADMAP Phase 2). Every active day becomes a star, laid down
/// on a slow spiral that winds outward as your history grows: the oldest night
/// you still hold is nearest the centre, tonight is out at the rim. Nights that
/// touch become threads, so a streak literally draws a line across your sky.
///
/// It only ever gains stars. There is no mark for a night you missed, no gap
/// picked out in red, nothing that reads as a hole — the never-punish rule
/// applies to the picture, not just the copy. A quiet week simply means the
/// thread pauses and picks up again further out.
///
/// Colour follows the mechanics: a light night is honey (XP), a big one burns
/// toward the keep's own flame (streak/ember). Everything is deterministic in
/// the day keys, so the same history always paints the same sky.
class HistorySky extends StatefulWidget {
  const HistorySky({
    super.key,
    required this.history,
    required this.ember,
    this.reduceMotion = false,
  });

  /// dateKey → completions that day. Only entries > 0 become stars.
  final Map<String, int> history;

  /// The keep's chosen flame colour — the hottest nights burn toward it.
  final Color ember;

  final bool reduceMotion;

  @override
  State<HistorySky> createState() => _HistorySkyState();
}

class _HistorySkyState extends State<HistorySky>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  /// The laid-out sky. Rebuilt only when the history actually changes — the
  /// spiral maths shouldn't run on every twinkle frame.
  late List<_Star> _stars = _layout(widget.history);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    if (!widget.reduceMotion && _c == null) {
      _c = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 24),
      )..repeat();
    } else if (widget.reduceMotion && _c != null) {
      _c!.dispose();
      _c = null;
    }
  }

  @override
  void didUpdateWidget(HistorySky old) {
    super.didUpdateWidget(old);
    if (old.reduceMotion != widget.reduceMotion) setState(_sync);
    if (old.history.length != widget.history.length) {
      _stars = _layout(widget.history);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  /// Places every lit night on the outward spiral.
  ///
  /// Two things are deliberate here. The turn count scales with how much
  /// history there is, so a first week reads as a gentle arc and half a year
  /// reads as a wound coil — a fixed turn count makes a new player's sky look
  /// like scattered debris. And the radius is measured against a floor of
  /// [_reachAt] nights rather than normalised to whatever you happen to have,
  /// so a six-night sky occupies a small bright knot near the centre and the
  /// disc visibly FILLS as the months accumulate. Normalising would make six
  /// nights look exactly as vast as six months, which is the one thing this
  /// picture must not say.
  static const _reachAt = 40;

  static List<_Star> _layout(Map<String, int> history) {
    final keys = history.keys.where((k) => (history[k] ?? 0) > 0).toList()
      ..sort();
    if (keys.isEmpty) return const [];

    final n = keys.length;
    final turns = (n / 22).clamp(0.35, 3.2);
    final step = n > 1 ? 2 * pi * turns / (n - 1) : 0.0;
    final span = max(n - 1, _reachAt);
    final out = <_Star>[];
    DateTime? prevDay;

    for (var i = 0; i < n; i++) {
      final day = Days.tryParse(keys[i]);
      // start at the top and wind clockwise, so "newest" ends up reading like
      // the hand of a clock rather than an arbitrary direction
      final theta = -pi / 2 + i * step;
      // the 0.78 exponent opens the innermost windings out; a straight linear
      // ramp crushes the oldest nights into an unreadable blob at the core
      final rFrac = 0.11 + 0.86 * pow(i / span, 0.78).toDouble();
      out.add(
        _Star(
          x: cos(theta) * rFrac,
          y: sin(theta) * rFrac,
          count: history[keys[i]] ?? 0,
          // a thread only forms between nights that actually touch
          linked:
              day != null && prevDay != null && Days.between(prevDay, day) == 1,
          phase: (i * 0.618) % 1.0,
        ),
      );
      if (day != null) prevDay = day;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 1.45,
        child: c == null
            ? CustomPaint(
                painter: _SkyPainter(stars: _stars, ember: widget.ember, t: 0),
                size: Size.infinite,
              )
            : AnimatedBuilder(
                animation: c,
                builder: (_, _) => CustomPaint(
                  // ~8 repaints/s is plenty for stars that only breathe
                  painter: _SkyPainter(
                    stars: _stars,
                    ember: widget.ember,
                    t: (c.value * 192).round() / 192,
                  ),
                  size: Size.infinite,
                ),
              ),
      ),
    );
  }
}

class _Star {
  const _Star({
    required this.x,
    required this.y,
    required this.count,
    required this.linked,
    required this.phase,
  });

  /// Position in −1..1 of the half-extent, before the ellipse fit.
  final double x, y;

  /// Completions that night — drives size and how far the colour burns.
  final int count;

  /// True when the previous star is the calendar day immediately before this
  /// one, i.e. the two nights are part of the same unbroken run.
  final bool linked;

  /// Twinkle offset, so the sky shimmers instead of pulsing in unison.
  final double phase;
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.stars, required this.ember, required this.t});

  final List<_Star> stars;
  final Color ember;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (stars.isEmpty) return;
    final cx = size.width / 2, cy = size.height / 2;
    final rx = cx * 0.90, ry = cy * 0.88;
    final unit = min(rx, ry);

    Offset at(_Star s) => Offset(cx + s.x * rx, cy + s.y * ry);

    // a faint dust of far stars behind the record — depth, and it keeps a
    // three-night-old sky from looking like an error state
    final dust = Random(11);
    for (var i = 0; i < 34; i++) {
      final a = dust.nextDouble() * 2 * pi;
      final r = sqrt(dust.nextDouble());
      canvas.drawCircle(
        Offset(cx + cos(a) * r * rx * 1.06, cy + sin(a) * r * ry * 1.06),
        0.6 + dust.nextDouble() * 0.7,
        Paint()
          ..color = Palette.textLo.withValues(
            alpha: 0.10 + 0.14 * dust.nextDouble(),
          ),
      );
    }

    // ── the threads first, so stars sit on top of their own lines ──
    for (var i = 1; i < stars.length; i++) {
      if (!stars[i].linked) continue;
      final a = at(stars[i - 1]), b = at(stars[i]);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round
          ..color = Palette.xp.withValues(alpha: 0.30),
      );
    }

    // ── the nights themselves ──
    for (var i = 0; i < stars.length; i++) {
      final s = stars[i];
      final p = at(s);
      final heat = (s.count.clamp(1, 6) - 1) / 5.0; // 0 light … 1 a big night
      final tone = Color.lerp(Palette.xpLight, ember, heat)!;
      final tw = 0.72 + 0.28 * sin(t * 2 * pi * 2 + s.phase * 2 * pi);
      final r = unit * (0.014 + 0.022 * heat) * (0.9 + 0.16 * tw);

      canvas.drawCircle(
        p,
        r * 3.4,
        Paint()
          ..color = tone.withValues(alpha: (0.13 + 0.17 * heat) * tw)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 2.2),
      );
      canvas.drawCircle(
        p,
        r,
        Paint()..color = Color.lerp(tone, Palette.specular, 0.35 * tw)!,
      );
    }

    // ── tonight: the newest night wears a ring, so "where am I now" is
    // answerable at a glance without a legend ──
    final last = at(stars.last);
    final pulse = 0.5 + 0.5 * sin(t * 2 * pi * 1.5);
    canvas.drawCircle(
      last,
      unit * (0.052 + 0.012 * pulse),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = ember.withValues(alpha: 0.35 + 0.30 * pulse),
    );
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.t != t || old.ember != ember || !identical(old.stars, stars);
}
