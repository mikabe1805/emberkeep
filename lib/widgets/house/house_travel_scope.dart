// What the dock's travel tells a room while it arrives or leaves.
//
// The travel stack (house_travel.dart) owns the arrival; a room only needs two
// things from it, and gets them here without being rebuilt:
//
//   ui     how much of the room's own UI shows (0..1). The departing room's UI
//          lets go first and the arriving room's comes up once its light has
//          reached it, so two cards never sit on top of each other. A room
//          wraps its live content in [HouseRoomUi] (HouseRoomBackdrop does).
//   glint  the glint that crosses Goals' glass sign last, a moment after the
//          lamp's cone has opened. The sign wraps itself in [HouseGlintSweep].
//
// Outside a travel stack (a room rendered on its own) there is no scope and
// both read as "at rest": the UI is fully there and no glint runs.
library;

import 'package:flutter/widgets.dart';

import 'house_room.dart';
import 'house_travel_model.dart' show HouseGlintFrame;

/// The live values the travel stack publishes, one UI value per room.
class HouseTravelSignals {
  /// How much of each room's UI shows, by dock index. 1 at rest.
  final List<ValueNotifier<double>> ui = [
    for (var i = 0; i < HouseRoom.values.length; i++) ValueNotifier<double>(1),
  ];

  /// The glint over Goals' sign, null when none is running.
  final ValueNotifier<HouseGlintFrame?> glint = ValueNotifier(null);

  /// How much of the house's one HUD shows (0..1): the most of any room's UI
  /// on stage, so it breathes through the hand-off (the departing UI lets go,
  /// the arriving one comes up) and is whole at rest.
  final ValueNotifier<double> hud = ValueNotifier<double>(1);

  void dispose() {
    for (final n in ui) {
      n.dispose();
    }
    glint.dispose();
    hud.dispose();
  }
}

/// Hands the travel's signals to the rooms under a travel stack.
class HouseTravelScope extends InheritedWidget {
  const HouseTravelScope({
    super.key,
    required this.signals,
    required super.child,
  });

  final HouseTravelSignals signals;

  /// The signals of the nearest travel stack, or null outside one.
  static HouseTravelSignals? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<HouseTravelScope>()?.signals;

  @override
  bool updateShouldNotify(HouseTravelScope oldWidget) =>
      oldWidget.signals != signals;
}

/// A room's live content, fading with the dock's travel: it lets go first when
/// the room is left and comes up once the room's light has reached it. At rest
/// (and outside a travel stack) it adds nothing.
class HouseRoomUi extends StatelessWidget {
  const HouseRoomUi({super.key, required this.room, required this.child});

  final HouseRoom room;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final signals = HouseTravelScope.maybeOf(context);
    if (signals == null) return child;
    // One chain at rest and in motion: only the value changes, so the room's
    // state is never remounted by a transition.
    return ValueListenableBuilder<double>(
      valueListenable: signals.ui[room.index],
      child: child,
      builder: (context, ui, child) => Opacity(opacity: ui, child: child),
    );
  }
}

/// The glint across Goals' glass sign: a soft diagonal catch of the lamp's light
/// that sweeps over [child] once, a moment after the lamp's cone has opened.
/// Draws nothing at rest.
class HouseGlintSweep extends StatelessWidget {
  const HouseGlintSweep({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final signals = HouseTravelScope.maybeOf(context);
    if (signals == null) return child;
    return ValueListenableBuilder<HouseGlintFrame?>(
      valueListenable: signals.glint,
      child: child,
      builder: (context, glint, child) => CustomPaint(
        foregroundPainter: glint == null ? null : _GlintPainter(glint),
        child: child,
      ),
    );
  }
}

class _GlintPainter extends CustomPainter {
  _GlintPainter(this.glint);

  final HouseGlintFrame glint;

  @override
  void paint(Canvas canvas, Size size) {
    if (glint.strength <= 0.003 || size.isEmpty) return;
    // -130..200 (percent) sweeps from just off the left edge to just off the
    // right edge.
    final centre = size.width * ((glint.x + 130) / 330 * 1.6 - 0.3);
    final half = size.width * 0.22;
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = LinearGradient(
        begin: const Alignment(-1, -0.4),
        end: const Alignment(1, 0.4),
        colors: [
          const Color(0x00FFE8B8),
          Color.fromRGBO(255, 232, 184, 0.34 * glint.strength),
          const Color(0x00FFE8B8),
        ],
      ).createShader(Rect.fromLTWH(centre - half, 0, half * 2, size.height));
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Rect.fromLTWH(centre - half, 0, half * 2, size.height),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlintPainter old) => old.glint != glint;
}
