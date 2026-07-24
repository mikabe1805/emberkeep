import 'dart:math';

import 'package:flutter/material.dart';

import 'home_room.dart' show hearthStageForLevel;

/// A small living hearth-flame for the daily HUD — the keep's heart, finally on
/// the screen you actually live in (round-65). It grows through six tiers with
/// your [level] (see [hearthStageForLevel]), burns full when the fire is kept
/// ([lit], a live streak) and banks to glowing embers when you've been away —
/// never cold, never-punish. On completion, bump [leap] and the flame surges
/// once, so a tap visibly changes your character on the current screen instead
/// of only firing a detached particle burst. Reduce-motion parks on a finished
/// still frame (t=0, no surge).
///
/// This is also the seam the Rive fire-spirit drops onto later: swap
/// [_HearthGlyphPainter] for a RivePortrait driven by the same
/// (stage, lit, glow) inputs and everything upstream keeps working.
class HearthGlyph extends StatefulWidget {
  const HearthGlyph({
    super.key,
    required this.level,
    required this.lit,
    required this.glow,
    this.leap = 0,
    this.reduceMotion = false,
    this.size = 40,
  });

  /// Drives the visual tier (0..5) via [hearthStageForLevel].
  final int level;

  /// The fire is kept (a live streak) → full flames; else banked embers.
  final bool lit;

  /// The flame's mid-tone hue (GameState's chosen ember colour).
  final Color glow;

  /// Change this — e.g. an incrementing completion counter — to fire a one-shot
  /// flame surge. The same value between builds means no surge.
  final int leap;

  final bool reduceMotion;
  final double size;

  @override
  State<HearthGlyph> createState() => _HearthGlyphState();
}

class _HearthGlyphState extends State<HearthGlyph>
    with TickerProviderStateMixin {
  /// The slow ambient flicker; null (and unpainted motion) under reduce-motion.
  AnimationController? _flicker;

  /// One-shot surge on completion — a brief height/brightness overshoot.
  late final AnimationController _surge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void initState() {
    super.initState();
    _syncFlicker();
  }

  void _syncFlicker() {
    final lively = !widget.reduceMotion;
    if (lively && _flicker == null) {
      _flicker = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3),
      )..repeat();
    } else if (!lively && _flicker != null) {
      _flicker!.dispose();
      _flicker = null;
    }
  }

  @override
  void didUpdateWidget(HearthGlyph old) {
    super.didUpdateWidget(old);
    if (old.reduceMotion != widget.reduceMotion) {
      setState(_syncFlicker);
    }
    if (old.leap != widget.leap && !widget.reduceMotion) {
      _surge.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flicker?.dispose();
    _surge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flicker = _flicker;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: flicker == null
            ? _surge
            : Listenable.merge([flicker, _surge]),
        builder: (_, _) {
          // quantize the ambient loop to ~12fps — alive to the eye, near-free
          // to paint; t=0 is the calm reduced-motion frame.
          final t = flicker == null ? 0.0 : (flicker.value * 36).round() / 36;
          // surge arc: 0→1→0 over the one-shot, eased to a soft rise-and-settle.
          final surge = _surge.value > 0 ? sin(_surge.value * pi) : 0.0;
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _HearthGlyphPainter(
              stage: hearthStageForLevel(widget.level),
              lit: widget.lit,
              glow: widget.glow,
              t: t,
              surge: surge,
            ),
          );
        },
      ),
    );
  }
}

class _HearthGlyphPainter extends CustomPainter {
  _HearthGlyphPainter({
    required this.stage,
    required this.lit,
    required this.glow,
    required this.t,
    required this.surge,
  });

  final int stage; // 0..5
  final bool lit;
  final Color glow;
  final double t; // 0..1 ambient loop (quantized upstream)
  final double surge; // 0..1 one-shot completion overshoot

  static const _cream = Color(0xFFFFF4D9);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final baseY = h * 0.82; // the ember bed sits low
    final flick = 1 + 0.10 * sin(t * 2 * pi * 2) + 0.06 * sin(t * 2 * pi * 3);
    final grow = 0.5 + stage * 0.10; // 0.5 (baseline) .. 1.0 (Everflame)
    final litK = lit ? 1.0 : 0.4; // banked, never cold

    // ── firelight halo (reactive to flicker + surge) ──
    final haloR =
        w *
        (0.30 + 0.05 * stage) *
        (0.9 + 0.14 * (flick - 1) * 5 + 0.5 * surge);
    canvas.drawCircle(
      Offset(cx, baseY - h * 0.14),
      haloR,
      Paint()
        ..color = glow.withValues(
          alpha: (0.30 + 0.16 * grow + 0.35 * surge) * litK,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // ── ember bed — always present, glowing even when banked ──
    for (final dx in const [-0.16, 0.0, 0.16]) {
      canvas.drawCircle(
        Offset(cx + dx * w, baseY),
        w * 0.05,
        Paint()
          ..color = Color.lerp(
            glow,
            _cream,
            0.35,
          )!.withValues(alpha: 0.5 + 0.4 * litK),
      );
    }

    // ── flame tongues (full when lit; a lick of flame during a surge) ──
    if (lit || surge > 0.02) {
      final tongueCount = 1 + (stage ~/ 2); // 1..3 tongues as you grow
      final maxH = h * (0.34 + 0.44 * grow) * litK + h * 0.30 * surge;
      const specs = <(double, double, double)>[
        (0.0, 1.0, 1.3),
        (-0.15, 0.66, 0.0),
        (0.15, 0.68, 2.4),
      ];
      for (var i = 0; i < tongueCount; i++) {
        final spec = specs[i];
        final fx = cx + spec.$1 * w;
        final f = 1 + 0.18 * sin(t * 2 * pi * 2 + spec.$3);
        final lean = w * 0.05 * sin(t * 2 * pi + spec.$3);
        final fh = maxH * spec.$2 * f;
        final fw = w * 0.14;
        final path = Path()
          ..moveTo(fx - fw, baseY)
          ..quadraticBezierTo(
            fx - fw + lean,
            baseY - fh * 0.6,
            fx + lean,
            baseY - fh,
          )
          ..quadraticBezierTo(fx + fw + lean, baseY - fh * 0.6, fx + fw, baseY)
          ..close();
        final rect = Rect.fromLTWH(fx - fw, baseY - fh, fw * 2, fh);
        canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              // hot at the base, cooling to the flame's own hue at the tip —
              // fire's real heat gradient. Running it the other way (cream on
              // top) reads as a white candle, not a flame.
              colors: [
                _cream,
                Color.lerp(glow, _cream, 0.5)!,
                glow,
                glow.withValues(alpha: 0.7),
              ],
              stops: const [0.0, 0.28, 0.76, 1.0],
            ).createShader(rect),
        );
      }
      // a hot bright heart low in the fire
      canvas.drawCircle(
        Offset(cx, baseY - h * 0.06),
        w * 0.10 * flick * (1 + 0.4 * surge),
        Paint()
          ..color = _cream.withValues(
            alpha: (0.7 + 0.3 * surge) * (lit ? 1.0 : surge),
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // ── Everflame gets a single drifting spark-mote at the top tier ──
    if (stage >= 5 && (lit || surge > 0)) {
      final my = baseY - h * (0.60 + 0.06 * sin(t * 2 * pi));
      canvas.drawCircle(
        Offset(cx + w * 0.10 * sin(t * 2 * pi * 1.5), my),
        w * 0.03,
        Paint()
          ..color = _cream.withValues(
            alpha: 0.4 + 0.5 * (0.5 + 0.5 * sin(t * 2 * pi * 3)),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_HearthGlyphPainter old) =>
      old.stage != stage ||
      old.lit != lit ||
      old.glow != glow ||
      old.t != t ||
      old.surge != surge;
}
