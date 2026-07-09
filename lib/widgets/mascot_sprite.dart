import 'dart:math' show cos, pi, sin;

import 'package:flutter/material.dart';

import '../content/creature_skins.dart' show creatureSkinById;
import '../tokens.dart';
import 'portrait.dart';

/// The companion, fully code-painted (round-62). Earlier rounds rendered
/// pre-generated SDXL/FLUX PNG frames here; the owner found the generated art
/// "obviously AI" and chose the clean procedural look everywhere. So this is
/// now a thin, lively wrapper around the procedural [Portrait]: it maps an
/// outfit skin to its painted costume and adds an occasional idle behaviour
/// (a hop, a curious tilt, a little shuffle) on top of the Portrait's own
/// breath/blink/flame-sway. Nothing loads from disk; nothing renders blank.
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
    this.fps = 7, // kept for call-site compatibility; unused now
    this.minSpriteSize = 72, // kept for call-site compatibility; unused now
    this.lively = true,
  });

  final double size;

  /// Which skin is worn (creature_skins id). Outfit ids (adventurer/healer/
  /// knight/wizard) paint a costume; every other id is a plain colour ember.
  final String skinId;
  final PortraitMood mood;
  final int level;
  final Color? aura;

  /// The four body-gradient colours for the worn skin.
  final List<Color>? skin;
  final bool badge;
  final Stat? trait;

  /// Retained so existing call sites compile; the procedural ember has no
  /// flipbook / pixel-size threshold, it just scales.
  final double fps;
  final double minSpriteSize;

  /// The idle behaviour loop — an occasional hop, tilt, and little shuffle.
  /// Pass `!state.reduceMotion`; the OS disable-animations switch is honoured
  /// regardless.
  final bool lively;

  @override
  State<MascotSprite> createState() => _MascotSpriteState();
}

class _MascotSpriteState extends State<MascotSprite>
    with SingleTickerProviderStateMixin {
  // a slow loop schedules the behaviours — hop, tilt, shuffle — so the creature
  // acts on its own rhythm. The Portrait runs its own breath/blink loop, so
  // this only drives the personality beats on top.
  late final AnimationController _behave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 11000),
  );

  var _lively = false;

  // per-instance phase so two mascots on screen never move in sync
  double get _phase =>
      ((widget.skinId.hashCode ^ (widget.level * 37)) % 997) / 997.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MascotSprite old) {
    super.didUpdateWidget(old);
    if (old.lively != widget.lively) _sync();
  }

  void _sync() {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _lively = widget.lively && !still;
    if (_lively) {
      if (!_behave.isAnimating) _behave.repeat();
    } else {
      _behave.stop();
      _behave.value = 0;
    }
  }

  @override
  void dispose() {
    _behave.dispose();
    super.dispose();
  }

  /// 0→1 progress through the [a]..[z] slice of the behaviour loop, else 0.
  static double _seg(double b, double a, double z) =>
      (b < a || b > z) ? 0.0 : (b - a) / (z - a);

  @override
  Widget build(BuildContext context) {
    final outfit = _outfitOf(widget.skinId);
    final portrait = Portrait(
      size: widget.size,
      mood: widget.mood,
      aura: widget.aura,
      level: widget.level,
      badge: widget.badge,
      trait: widget.trait,
      skin: widget.skin,
      outfit: outfit,
    );
    if (!_lively) return portrait;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _behave,
        builder: (_, child) {
          // once per ~11s the creature does a thing — phase-offset per instance
          final b = (((_behave.value * 220).round() / 220) + _phase) % 1.0;
          var dx = 0.0, dy = 0.0, lean = 0.0, squash = 1.0;
          final hop = _seg(b, 0.20, 0.26);
          if (hop > 0) {
            dy -= sin(hop * pi) * widget.size * 0.06;
            squash = 1.0 + 0.05 * sin(hop * 2 * pi);
          }
          final tilt = _seg(b, 0.42, 0.52);
          if (tilt > 0) lean += sin(tilt * 2 * pi) * 0.03;
          final walk = _seg(b, 0.60, 0.88);
          if (walk > 0) {
            final dir = _phase < 0.5 ? 1.0 : -1.0;
            dx = sin(walk * pi) * widget.size * 0.05 * dir;
            // windowed so the tilt eases in/out with the step (no edge snap)
            lean += cos(walk * pi) * sin(walk * pi) * 0.05 * dir;
          }
          return Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.rotate(
              angle: lean,
              child: Transform.scale(scaleX: 1.0, scaleY: squash, child: child),
            ),
          );
        },
        child: portrait,
      ),
    );
  }

  /// Map an outfit skin id to its painted costume; null for colour skins.
  static Outfit? _outfitOf(String skinId) {
    final sk = creatureSkinById(skinId);
    if (sk == null || !sk.outfit) return null;
    switch (skinId) {
      case 'adventurer':
        return Outfit.wayfarer;
      case 'healer':
        return Outfit.herbalist;
      case 'knight':
        return Outfit.knight;
      case 'wizard':
        return Outfit.wizard;
    }
    return null;
  }
}
