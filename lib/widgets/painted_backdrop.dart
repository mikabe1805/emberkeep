import 'package:flutter/material.dart';

/// A painterly generated scene as a rounded stage behind a hero widget —
/// the character stops floating on flat glass and stands somewhere warm.
/// Scenes are graded crops of the room concept paintings
/// (`assets/backdrops/&lt;scene&gt;.webp`, built by tools/gen_backdrops.py):
/// `hearthside` (fireplace), `candleglow` (candle bowl), `lamplight`
/// (armchair + lamp). A missing asset falls back to a warm gradient, so the
/// stage can never render blank.
class PaintedBackdrop extends StatelessWidget {
  const PaintedBackdrop({
    super.key,
    required this.child,
    this.scene = 'hearthside',
    this.height = 190,
    this.radius = 20,
    this.scrim = 0.30,
    this.alignment = const Alignment(0, 0.45),
  });

  final Widget child;

  /// Which painted scene to stand in (see class docs).
  final String scene;
  final double height;
  final double radius;

  /// Strength of the darkening at the stage floor — grounds the character
  /// and keeps any caption below legible.
  final double scrim;

  /// Where the hero stands — a touch below centre by default, so it reads
  /// as standing in the scene rather than floating over it.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/backdrops/$scene.webp',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF3A2C2A), Color(0xFF241A16)],
                  ),
                ),
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
                    Color.fromRGBO(20, 12, 6, scrim),
                  ],
                ),
              ),
            ),
            Align(alignment: alignment, child: child),
          ],
        ),
      ),
    );
  }
}
