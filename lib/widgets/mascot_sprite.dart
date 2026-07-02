import 'dart:math' show pi, sin;

import 'package:flutter/material.dart';

import '../tokens.dart';
import 'portrait.dart';

/// Declares which pre-rendered ember sprite frame-sets have shipped. All seven
/// creature skins ship stages 0–5 in idle+happy, on one path convention:
/// `assets/mascot/<skinId>/s<stage>_<mood>_00.png`. Amber frames come from the
/// locked FLUX ember (SDXL per-stage, rembg cutout); the six paid skins are
/// deterministic palette-remaps of those (tools/remap_mascot_skins.py) so they
/// match creature_skins.dart colors exactly. Anything outside the shipped set
/// falls back to the procedural [Portrait]; a missing file also falls back via
/// the Image errorBuilder — nothing ever renders blank.
abstract final class MascotFrames {
  static const _skins = {
    'ember_amber', 'rose_quartz', 'mint_glass', 'periwinkle',
    'lilac', 'slate', 'gilded',
  };
  static const _moods = {'idle', 'happy'};

  static List<String>? framesFor(String skinId, int stage, String mood) {
    if (!_skins.contains(skinId) || stage < 0 || stage > 5) return null;
    // an undrawn mood plays the skin's idle set (the widget adds a happy pop)
    final m = _moods.contains(mood) ? mood : 'idle';
    return ['assets/mascot/$skinId/s${stage}_${m}_00.png'];
  }
}

/// The mascot as pre-rendered sprite frames when they exist, otherwise the
/// procedural [Portrait] (round-53, the sprite-set lane). Two rules bake in the
/// integration plan:
///  • Below [minSpriteSize] (tiny HUD dots, shop swatches) it ALWAYS uses the
///    procedural ember — the painterly frames don't read when small, the vector
///    one is built to.
///  • If no frame-set is declared/loads for this (skin, stage, mood), it falls
///    back to the procedural ember too. Nothing ever renders blank.
class MascotSprite extends StatefulWidget {
  const MascotSprite({
    super.key,
    required this.size,
    required this.skinId,
    this.mood = PortraitMood.idle,
    this.level = 1,
    this.aura,
    this.skin,
    this.badge = false,
    this.trait,
    this.fps = 7,
    this.minSpriteSize = 72,
  });

  final double size;

  /// Which skin's frame-set to use (creature_skins id, e.g. 'ember_amber').
  final String skinId;
  final PortraitMood mood;
  final int level;
  final Color? aura;

  /// The four body-gradient colours — used by the procedural fallback so a
  /// not-yet-drawn skin still recolours correctly.
  final List<Color>? skin;
  final bool badge;
  final Stat? trait;

  /// Idle-loop playback rate.
  final double fps;

  /// Sprites only kick in at/above this px size; smaller stays procedural.
  final double minSpriteSize;

  @override
  State<MascotSprite> createState() => _MascotSpriteState();
}

class _MascotSpriteState extends State<MascotSprite>
    with SingleTickerProviderStateMixin {
  // one slow loop drives the idle breath (+ flipbook when >1 frame). Repaint-
  // bounded and quantized so a still frame still feels alive for almost nothing.
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();
  List<String>? _frames;

  Widget _fallback() => Portrait(
        size: widget.size,
        mood: widget.mood,
        aura: widget.aura,
        level: widget.level,
        badge: widget.badge,
        trait: widget.trait,
        skin: widget.skin,
      );

  List<String>? _resolve() {
    if (widget.size < widget.minSpriteSize) return null; // tiny → procedural
    final stage = frameTierForLevel(widget.level);
    final mood = widget.mood == PortraitMood.happy ? 'happy' : 'idle';
    final f = MascotFrames.framesFor(widget.skinId, stage, mood);
    return (f != null && f.isNotEmpty) ? f : null;
  }

  @override
  void initState() {
    super.initState();
    _frames = _resolve();
  }

  @override
  void didUpdateWidget(MascotSprite old) {
    super.didUpdateWidget(old);
    if (old.level != widget.level ||
        old.mood != widget.mood ||
        old.skinId != widget.skinId ||
        old.size != widget.size) {
      setState(() => _frames = _resolve());
    }
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frames = _frames;
    if (frames == null || frames.isEmpty) return _fallback();
    final happy = widget.mood == PortraitMood.happy;
    final aura = widget.aura;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _life,
        builder: (_, _) {
          final t = (_life.value * 60).round() / 60; // ~20fps quantize
          final breathe = sin(t * 2 * pi);
          final bob = sin(t * 2 * pi + 1.2);
          // a gentle breath + bob; a happy beat sits a touch bigger + livelier
          final scale = (happy ? 1.05 : 1.0) * (1 + 0.022 * breathe);
          final dy = -bob * widget.size * (happy ? 0.028 : 0.016);
          // flipbook index in real SECONDS (t is the 0..1 loop fraction), so
          // [fps] means frames per second — not frames per loop
          final secs = t * _life.duration!.inMilliseconds / 1000;
          final i = frames.length < 2
              ? 0
              : (secs * widget.fps).floor() % frames.length;
          Widget sprite = _frameImage(frames[i]);
          if (aura != null) {
            // your build's colour pooling behind you — parity with the
            // procedural ember's aura (and what a cosmetic preview previews)
            sprite = Stack(children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.52,
                        colors: [
                          aura.withValues(alpha: happy ? 0.38 : 0.24),
                          aura.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              sprite,
            ]);
          }
          return Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(scale: scale, child: sprite),
          );
        },
      ),
    );
  }

  Widget _frameImage(String asset) => Image.asset(
        asset,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        gaplessPlayback: true, // no flicker on frame swap
        // a missing/broken asset can never blank the mascot — drop to procedural
        errorBuilder: (_, _, _) => _fallback(),
      );
}
