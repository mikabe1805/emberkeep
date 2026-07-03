import 'dart:math' show pi, sin;

import 'package:flutter/material.dart';

import '../tokens.dart';
import 'portrait.dart';

/// Declares which pre-rendered ember sprite frame-sets have shipped. All seven
/// creature skins ship stages 0–5 in idle+happy, on one path convention:
/// `assets/mascot/<skinId>/s<stage>_<mood>_00.png`. The procedural [Portrait]
/// is the standard renderer; pre-rendered frames only activate at very large
/// display sizes (e.g. a profile preview).
abstract final class MascotFrames {
  static const _skins = {
    'ember_amber', 'rose_quartz', 'mint_glass', 'periwinkle',
    'lilac', 'slate', 'gilded',
  };
  static const _moods = {'idle', 'happy'};

  static List<String>? framesFor(String skinId, int stage, String mood) {
    if (!_skins.contains(skinId) || stage < 0 || stage > 5) return null;
    final m = _moods.contains(mood) ? mood : 'idle';
    return ['assets/mascot/$skinId/s${stage}_${m}_00.png'];
  }
}

/// The mascot as pre-rendered sprite frames when they exist, otherwise the
/// procedural [Portrait]. Two rules bake in the integration plan:
///  • Below [minSpriteSize] it ALWAYS uses the procedural ember — the
///    painterly frames don't read when small, the vector one is built to.
///  • If no frame-set is declared/loads for this (skin, stage, mood), it falls
///    back to the procedural ember too. Nothing ever renders blank.
///
/// The procedural Portrait is the default renderer for all normal display
/// sizes (animated breathing, blinking, glassy Flutter shading). Pre-rendered
/// sprite frames only kick in at very large sizes (minSpriteSize = 999).
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
    this.minSpriteSize = 999,
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

  /// Pre-rendered sprite frames only activate at/above this pixel size.
  /// Set to 999 so the procedural Portrait is the standard renderer.
  final double minSpriteSize;

  @override
  State<MascotSprite> createState() => _MascotSpriteState();
}

class _MascotSpriteState extends State<MascotSprite>
    with SingleTickerProviderStateMixin {
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
    if (widget.size < widget.minSpriteSize) return null;
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
          final t = (_life.value * 60).round() / 60;
          final breathe = sin(t * 2 * pi);
          final bob = sin(t * 2 * pi + 1.2);
          final scale = (happy ? 1.05 : 1.0) * (1 + 0.022 * breathe);
          final dy = -bob * widget.size * (happy ? 0.028 : 0.016);
          final secs = t * _life.duration!.inMilliseconds / 1000;
          final i = frames.length < 2
              ? 0
              : (secs * widget.fps).floor() % frames.length;
          Widget sprite = _frameImage(frames[i]);
          if (aura != null) {
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
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _fallback(),
      );
}
