// The depth room as the first frame of a class day (ported from concept B,
// "In the room", 2026-10-03).
//
// The real QuestDepthRoom planes (never re-cut) seen through a camera. A
// [RoomShot] says which part of the painting fills the stage and how far the
// planes have separated; moving between shots moves near planes more than far
// ones, so the room reads as a place, never a flat crop:
//
//   desk     a class day: the whole lamp, the chair, the desk and a sliver
//            of the window
//   kept     a mark: the camera eases back until the whole lamp and the
//            desk top are in frame, and the lamp's light opens on the desk
//   corner   the window and the armchair, the part of the room for resting
//
// The room is the night painting it was made as, at every hour: the window
// is the painted moonlit glass, and nothing here simulates the time of day.
// The fireplace stays outside every shot: it is ambient furniture and never
// answers progress. The lamp is the room's own light, and it answers a kept
// class.
//
// Other room styles are painted plates: [ClassRoomPlate] shows the plate held
// still behind the same layout.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine.dart';
import '../../content/quest_desk_styles.dart';
import '../home_room.dart';
import '../quest_depth_room.dart';

/// Image-pixel landmarks of the registered room camera (1635 x 962).
abstract final class RoomMarks {
  /// The glowing underside of the floor lamp's shade.
  static const bulb = Offset(526, 318);

  /// The left of the desk top, where the lamp's light falls.
  static const deskPatch = Offset(770, 446);

  /// Where a kept class's ring settles: on the desk, above the chair's back.
  static const ringRest = Offset(792, 386);

  /// The floor line, where the furniture's feet meet the boards.
  static const floor = 800.0;

  /// The top of the floor lamp's shade.
  static const shadeTop = 210.0;

  /// The painted crescent moon in the window.
  static const moon = Offset(160, 322);

  /// The lamp's pole, between the shade and the side table's books.
  static const pole = Offset(528, 446);
}

/// Which part of the painting fills the stage: [left]/[top] are the image
/// pixel at the stage's top-left, [scale] is points per image pixel, and
/// [tilt] is how far the planes have separated (near planes travel most).
@immutable
class RoomShot {
  const RoomShot({
    required this.left,
    required this.top,
    required this.scale,
    this.tilt = Offset.zero,
  });

  final double left;
  final double top;
  final double scale;
  final Offset tilt;

  Offset toStage(Offset px) =>
      Offset((px.dx - left) * scale, (px.dy - top) * scale);

  static RoomShot lerp(RoomShot a, RoomShot b, double t) => RoomShot(
    left: a.left + (b.left - a.left) * t,
    top: a.top + (b.top - a.top) * t,
    // Zoom moves evenly in log space, the way a lens does.
    scale: math.exp(
      math.log(a.scale) + (math.log(b.scale) - math.log(a.scale)) * t,
    ),
    tilt: Offset.lerp(a.tilt, b.tilt, t)!,
  );

  /// A class day: the floor line sits at [floorAt] on the stage, just above
  /// the glass, so the furniture stands on the boards and the glass lies in
  /// front of them. The whole lamp stays in frame below [headroom] (the HUD):
  /// a tall glass gives a wider, smaller room rather than a cropped one.
  static RoomShot desk({
    required double floorAt,
    double width = 393,
    double headroom = 92,
  }) {
    final byFloor = floorAt / 752;
    final byLamp =
        (floorAt - headroom) / (RoomMarks.floor - RoomMarks.shadeTop);
    // Never so wide that the fireplace comes into frame: it is ambient
    // furniture and never answers progress.
    final scale = math.min(byFloor, byLamp).clamp(0.44, 0.74).toDouble();
    final top = RoomMarks.floor - floorAt / scale;
    // Far enough left that a strip of the window's glass shows, and the
    // right edge short of the fireplace's stone (image x 1060).
    final left = math.min(scale <= 0.58 ? 336.0 : 372.0, 1060 - width / scale);
    return RoomShot(left: left, top: math.max(0, top), scale: scale);
  }

  /// A mark: the whole lamp and the desk top in frame.
  static RoomShot kept({double width = 393}) {
    const left = 418.0;
    const right = 1212.0;
    final scale = width / (right - left);
    return RoomShot(
      left: left,
      top: 26,
      scale: scale,
      tilt: const Offset(0.55, 0.12),
    );
  }

  /// The window, the armchair and the lamp.
  static const corner = RoomShot(left: 54, top: 30, scale: 0.56);

  /// The evening: the window, the armchair and the lamp, the part of the
  /// room for resting. The lamp's shade always stays below [headroom] (the
  /// HUD). With a short glass the floor line sits at [floorAt] on the
  /// glass's top edge, as at the desk; a taller glass (a class still to
  /// mark, large text) never shrinks the room into a band under the HUD:
  /// the camera holds the shade just under the HUD and lets the floor run on
  /// behind the glass. The armchair (image x 400) is the centre, the
  /// window's frame stays in on the left, and the fireplace stays out on
  /// the right.
  ///
  /// [closer] (0..1) eases the camera a little nearer the armchair and the
  /// lamp while the room's music plays, the shade held where it was.
  static RoomShot evening({
    required double floorAt,
    double width = 393,
    double headroom = 92,
    double closer = 0,
  }) {
    final byFloor = floorAt / 760;
    final byLamp =
        (floorAt - headroom) / (RoomMarks.floor - RoomMarks.shadeTop);
    var scale = math.min(byFloor, byLamp);
    var top = RoomMarks.floor - floorAt / scale;
    if (top < 0) {
      // The floor cannot reach the glass with the whole lamp under the HUD:
      // the painting's top meets the stage's, the shade sits at the HUD's
      // foot, and the floor goes on behind the glass.
      top = 0;
      scale = headroom / RoomMarks.shadeTop;
    }
    scale = scale.clamp(0.44, 0.8).toDouble();
    if (closer > 0) {
      final shade = (RoomMarks.shadeTop - top) * scale;
      scale *= 1 + 0.12 * closer;
      top = RoomMarks.shadeTop - shade / scale;
    }
    final span = width / scale;
    final centre = 400 + 46 * closer;
    final left = (centre - span / 2).clamp(
      coverLeft,
      math.max(coverLeft, 1060 - span),
    );
    return RoomShot(left: left.toDouble(), top: top, scale: scale);
  }

  /// The planes are drawn 8% over size about the painting's centre inside a
  /// box that clips them, so a shot whose left edge sits nearer the
  /// painting's edge than this leaves the stage uncovered at the left.
  static const coverLeft = 62.0;

  @override
  bool operator ==(Object other) =>
      other is RoomShot &&
      other.left == left &&
      other.top == top &&
      other.scale == scale &&
      other.tilt == tilt;

  @override
  int get hashCode => Object.hash(left, top, scale, tilt);
}

class ClassRoomStage extends StatelessWidget {
  const ClassRoomStage({
    super.key,
    required this.shot,
    this.bloom = 0,
    this.warmth = 0,
    this.fadeStart,
    this.fadeEnd,
    this.scrim = 1,
    this.scrimHeight = classStatusScrimHeight,
  });

  final RoomShot shot;

  /// 0..0.9: the lamp answering a kept class (driven by the celebration).
  final double bloom;

  /// 0..1: a quieter, lasting warmth once the day's classes are kept, or
  /// while the lamp's music plays.
  final double warmth;

  /// Stage y where the floor starts settling into the canvas, and where it
  /// is gone. Null keeps the whole painting.
  final double? fadeStart;
  final double? fadeEnd;

  /// 0..1: the soft dark at the top of the stage, under the status bar and
  /// the HUD (the celebration lets it go as the camera leaves the window).
  final double scrim;

  /// How far down the scrim reaches from the stage's top. The stage starts
  /// at the top of the screen, so this covers the status bar and the HUD.
  final double scrimHeight;

  static const assets = QuestDepthRoom.assets;

  @override
  Widget build(BuildContext context) {
    final s = shot.scale;
    const over = 1.08;
    final k = s / over;
    final boxLeft = 817.5 * s * (1 - 1 / over) - shot.left * s;
    final boxTop = 481 * s * (1 - 1 / over) - shot.top * s;
    final room = QuestDepthRoom(
      parallax: AlwaysStoppedAnimation<Offset>(shot.tilt),
      scrollPosition: const AlwaysStoppedAnimation<double>(0),
      flameHue: const Color(0xFFEC6007),
      lively: true,
      // The hearth is outside every shot; keep its loop parked.
      animateFire: false,
    );
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: boxLeft,
            top: boxTop,
            width: 1635 * k,
            height: 962 * k,
            child: room,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _LampPainter(shot, bloom: bloom, warmth: warmth),
              ),
            ),
          ),
          if (scrim > 0)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: scrimHeight,
              child: IgnorePointer(
                child: Opacity(
                  opacity: scrim.clamp(0.0, 1.0),
                  child: const ClassStatusScrim(),
                ),
              ),
            ),
          if (fadeStart != null)
            Positioned(
              left: 0,
              right: 0,
              top: fadeStart,
              bottom: 0,
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final span = (fadeEnd ?? fadeStart! + 90) - fadeStart!;
                    final stop = (span / math.max(1, box.maxHeight)).clamp(
                      0.05,
                      1.0,
                    );
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: const [
                            Color(0x00191210),
                            Color(0xB0191210),
                            Color(0xFF191210),
                          ],
                          stops: [0, stop * 0.6, stop],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// How far the status scrim reaches from the top of the screen: the status
/// bar (59 pt on his phone) and the HUD's two lines under it.
const classStatusScrimHeight = 150.0;

/// The soft dark the HUD reads on: deepest under the status bar, gone by the
/// lamp. The same at the top of the room and of the celebration.
class ClassStatusScrim extends StatelessWidget {
  const ClassStatusScrim({super.key});

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xE6120C09), Color(0xB3120C09), Color(0x00120C09)],
        stops: [0, 0.62, 1],
      ),
    ),
  );
}

/// The lamp: a resting pool, and the answer to a kept
/// class: the bulb brightens, a 420 pt halo opens around it, and its light
/// lands on the desk where the ring settles.
class _LampPainter extends CustomPainter {
  _LampPainter(this.shot, {required this.bloom, required this.warmth});

  final RoomShot shot;
  final double bloom;
  final double warmth;

  @override
  void paint(Canvas canvas, Size size) {
    final lamp = shot.toStage(RoomMarks.bulb);
    final rest = 0.085 + warmth * 0.045;
    final restRadius = 1000 * shot.scale * 0.42;
    canvas.drawCircle(
      lamp,
      restRadius,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFE9A85C).withValues(alpha: rest),
            const Color(0xFFB8742F).withValues(alpha: rest * 0.35),
            const Color(0x00B8742F),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: lamp, radius: restRadius)),
    );
    if (bloom <= 0) return;
    // The halo: 420 pt across, centred on the lamp (the level-up's halo,
    // with the lamp as its source).
    canvas.drawCircle(
      lamp,
      210,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFE0A865).withValues(alpha: 0.30 * bloom),
            const Color(0xFFB8742F).withValues(alpha: 0.11 * bloom),
            const Color(0x00B8742F),
          ],
          stops: const [0, 0.42, 1],
        ).createShader(Rect.fromCircle(center: lamp, radius: 210)),
    );
    // The bulb itself burns brighter under the shade.
    final core = 34 + 26 * bloom;
    canvas.drawCircle(
      lamp,
      core,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE6B8).withValues(alpha: 0.55 * bloom),
            const Color(0xFFE0A865).withValues(alpha: 0.16 * bloom),
            const Color(0x00E0A865),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: lamp, radius: core)),
    );
    // Its light falls on the desk: a wide, flat pool on the desk top, the
    // patch where the ring comes to rest.
    final desk = shot.toStage(RoomMarks.deskPatch);
    final rx = 330 * shot.scale;
    final ry = 46 * shot.scale;
    canvas.save();
    canvas.translate(desk.dx, desk.dy);
    canvas.scale(1, ry / rx);
    canvas.drawCircle(
      Offset.zero,
      rx,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFF2CD93).withValues(alpha: 0.42 * bloom),
            const Color(0xFFE0A865).withValues(alpha: 0.16 * bloom),
            const Color(0x00E0A865),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: rx)),
    );
    canvas.restore();
    // And a soft cone from the shade down toward it, so the pool is the
    // lamp's and not a spotlight from nowhere.
    final cone = Path()
      ..moveTo(lamp.dx - 46 * shot.scale, lamp.dy + 4)
      ..lineTo(lamp.dx + 46 * shot.scale, lamp.dy + 4)
      ..lineTo(desk.dx + rx * 0.9, desk.dy)
      ..lineTo(lamp.dx - 120 * shot.scale, desk.dy + 30)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..blendMode = BlendMode.plus
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22)
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF2CD93).withValues(alpha: 0.12 * bloom),
            const Color(0x00F2CD93),
          ],
        ).createShader(cone.getBounds()),
    );
  }

  @override
  bool shouldRepaint(_LampPainter old) =>
      old.bloom != bloom || old.warmth != warmth || old.shot != shot;
}

/// Whether the person's room is the layered depth room the camera can move
/// through (the walnut Writer's Hearth). Other rooms are painted plates.
bool classRoomIsLayered(GameState state) =>
    activeQuestDeskLook(state).roomStyleId == 'wall_walnut';

/// A painted room plate behind the class-day layout, held still: the same
/// composition (room above, glass at the floor line) without a camera.
class ClassRoomPlate extends StatelessWidget {
  const ClassRoomPlate({
    super.key,
    required this.state,
    this.fadeStart,
    this.fadeEnd,
    this.dim = 0,
    this.scrimHeight = classStatusScrimHeight,
  });

  final GameState state;
  final double? fadeStart;
  final double? fadeEnd;
  final double scrimHeight;

  /// 0..1: the celebration's walnut dim over the plate.
  final double dim;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            alignment: const Alignment(0, 0.35),
            child: SizedBox(
              width: 680,
              height: 400,
              child: IgnorePointer(
                child: HomeRoom(
                  key: const Key('class-day-room-plate'),
                  aspect: 1.7,
                  unlocked: state.ownedFurniture,
                  plateId: activeQuestDeskLook(state).roomStyleId,
                  lively: false,
                  level: state.level,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: scrimHeight,
            child: const IgnorePointer(child: ClassStatusScrim()),
          ),
          if (dim > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: const Color(0xFF140C07).withValues(alpha: 0.72 * dim),
                ),
              ),
            ),
          if (fadeStart != null)
            Positioned(
              left: 0,
              right: 0,
              top: fadeStart,
              bottom: 0,
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final span = (fadeEnd ?? fadeStart! + 90) - fadeStart!;
                    final stop = (span / math.max(1, box.maxHeight)).clamp(
                      0.05,
                      1.0,
                    );
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: const [
                            Color(0x00191210),
                            Color(0xB0191210),
                            Color(0xFF191210),
                          ],
                          stops: [0, stop * 0.6, stop],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
