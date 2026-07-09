import 'package:flutter/material.dart';

import 'stage_scene.dart';

/// A code-painted scene as a rounded stage behind a hero widget — the
/// character stops floating on flat glass and stands somewhere warm. Scenes are
/// drawn procedurally by [paintStageScene] (round-62, replacing the round-60
/// SDXL/FLUX webp backdrops the owner found "obviously AI"); every scene keeps
/// its lower-centre open so the hero has somewhere to stand. A slow loop drives
/// gentle ambient (candle flicker, fireflies, falling snow, twinkling stars),
/// quantized + repaint-bounded and honouring reduce-motion.
class PaintedBackdrop extends StatefulWidget {
  const PaintedBackdrop({
    super.key,
    required this.child,
    this.scene = 'hearthside',
    this.height = 190,
    this.radius = 20,
    this.scrim = 0.30,
    this.alignment = const Alignment(0, 0.45),
    this.lively = true,
  });

  final Widget child;

  /// Which scene to stand in (content/scenes.dart id).
  final String scene;
  final double height;
  final double radius;

  /// Strength of the darkening at the stage floor — grounds the character
  /// and keeps any caption below legible.
  final double scrim;

  /// Where the hero stands — a touch below centre by default.
  final Alignment alignment;

  /// The ambient-motion switch; pass `!state.reduceMotion`.
  final bool lively;

  @override
  State<PaintedBackdrop> createState() => _PaintedBackdropState();
}

class _PaintedBackdropState extends State<PaintedBackdrop>
    with SingleTickerProviderStateMixin {
  AnimationController? _life;

  @override
  void dispose() {
    _life?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lively = widget.lively &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (lively && _life == null) {
      _life = AnimationController(
          vsync: this, duration: const Duration(seconds: 9))
        ..repeat();
    } else if (!lively && _life != null) {
      _life!.dispose();
      _life = null;
    }
    final life = _life;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: life ?? const AlwaysStoppedAnimation(0.0),
                builder: (_, _) {
                  final t = life == null ? 0.0 : (life.value * 90).round() / 90;
                  return CustomPaint(painter: _ScenePainter(widget.scene, t));
                },
              ),
            ),
            // floor scrim — the hero glows, the scene sits back
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.45, 1.0],
                  colors: [
                    Colors.transparent,
                    Color.fromRGBO(20, 12, 6, widget.scrim),
                  ],
                ),
              ),
            ),
            Align(alignment: widget.alignment, child: widget.child),
          ],
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scene, this.t);
  final String scene;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    paintStageScene(canvas, scene, Offset.zero & size, t: t);
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.scene != scene || old.t != t;
}
