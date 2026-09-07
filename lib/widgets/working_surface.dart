import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../audio.dart';
import '../tokens.dart';
import 'gold_surface.dart';
import 'pressable.dart';

const workingRoomAsset = 'assets/pages/working-room-v1.webp';

abstract final class WorkingType {
  static const title = TextStyle(
    fontFamily: 'EBGaramond',
    fontWeight: FontWeight.w400,
    color: Palette.textHi,
    fontSize: 26,
    height: 1.12,
  );
}

/// A single intact room plate. Live working layers share this perspective;
/// neither user content nor progress is baked into the environment.
class WorkingScene extends StatelessWidget {
  const WorkingScene({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Palette.parchment,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            workingRoomAsset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            excludeFromSemantics: true,
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x3017100D),
                  Color(0x1017100D),
                  Color(0x8017100D),
                ],
                stops: [0, .35, 1],
              ),
            ),
          ),
        ),
        Padding(padding: padding, child: child),
      ],
    ),
  );
}

/// One coffee-smoked pane, with a lit upper lip and a darker contact edge.
/// Blur is bounded to this physical layer. Rows inside use spacing and rules.
class WorkingSurface extends StatelessWidget {
  const WorkingSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(24);
    final contrast = MediaQuery.highContrastOf(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0xA5090504),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
          BoxShadow(
            color: Color(0xB3090504),
            blurRadius: 2,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: CustomPaint(
            foregroundPainter: _WorkingRim(radius: radius),
            child: Container(
              padding: padding.add(const EdgeInsets.all(3)),
              decoration: BoxDecoration(
                borderRadius: radius,
                image: contrast
                    ? null
                    : const DecorationImage(
                        image: AssetImage('assets/room/wall_grain.png'),
                        repeat: ImageRepeat.repeat,
                        scale: 4,
                        opacity: .055,
                      ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: contrast
                      ? const [Color(0xFF2C211C), Color(0xFF17110F)]
                      : const [
                          Color(0x70302018),
                          Color(0x881C1411),
                          Color(0xA0100C0A),
                        ],
                  stops: contrast ? null : const [0, .42, 1],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The metal is only the rim. Painting a full gradient behind translucent glass
/// would replace the room with a flat brown fill.
class _WorkingRim extends CustomPainter {
  const _WorkingRim({required this.radius});
  final BorderRadius radius;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFF3C98D),
          Color(0x886C4829),
          Color(0xDDC69A62),
          Color(0x805B3C25),
        ],
        stops: [0, .34, .76, 1],
      ).createShader(rect);
    canvas.drawRRect(radius.toRRect(rect).deflate(.8), stroke);
    canvas.drawRRect(
      radius.toRRect(rect).deflate(3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .65
        ..color = const Color(0x62694A2D),
    );
  }

  @override
  bool shouldRepaint(_WorkingRim old) => old.radius != radius;
}

class WorkingRule extends StatelessWidget {
  const WorkingRule({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Divider(height: 1, thickness: .7, color: Color(0x756F5133)),
  );
}

/// Quiet navigation stays glass; a committed change owns the satin brass face.
class WorkingAction extends StatelessWidget {
  const WorkingAction({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.iconLeading = false,
    this.primary = false,
    this.enabled = true,
    this.sound = InteractionSound.navigate,
  });
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool iconLeading;
  final bool primary;
  final bool enabled;
  final InteractionSound sound;

  @override
  Widget build(BuildContext context) => Pressable(
    onTapUp: (_) => onTap(),
    enabled: enabled,
    interactionSound: sound,
    material: primary ? MaterialSound.brass : MaterialSound.glass,
    semanticLabel: label,
    pressDepth: primary ? 2 : 1,
    borderRadius: BorderRadius.circular(primary ? 14 : 10),
    edgeColor: Colors.transparent,
    stateBuilder: (context, child, pressed, focused, hovered) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(primary ? 14 : 10),
        border: Border.all(
          color: focused
              ? Palette.textHi
              : primary
              ? Palette.brassLit.withValues(alpha: .7)
              : Colors.transparent,
        ),
        color: primary && !enabled
            ? const Color(0xFF392C24)
            : hovered
            ? const Color(0x22F2CD93)
            : null,
        boxShadow: primary && enabled
            ? const [
                BoxShadow(
                  color: Color(0x60080503),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: primary && enabled
          ? GoldSurface(cut: 9, glow: false, child: child)
          : child,
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: primary ? 20 : 12,
          vertical: 12,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null && iconLeading) ...[
              Icon(
                icon,
                size: 20,
                color: primary && enabled ? Palette.onHoney : Palette.xpLight,
              ),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: (primary ? WorkingType.title : Type.body).copyWith(
                  fontSize: primary ? 22 : 15,
                  height: 1.15,
                  color: primary && enabled ? Palette.onHoney : Palette.textMid,
                ),
              ),
            ),
            if (icon != null && !iconLeading) ...[
              const SizedBox(width: 10),
              Icon(
                icon,
                size: 20,
                color: primary && enabled ? Palette.onHoney : Palette.xpLight,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
