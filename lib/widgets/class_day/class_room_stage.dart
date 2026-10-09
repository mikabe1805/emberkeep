// The depth room as the first frame of a class day (ported from concept B,
// "In the room", 2026-10-03).
//
// The real QuestDepthRoom planes (never re-cut) seen through a camera. A
// [RoomShot] says which part of the painting fills the stage and how far the
// planes have separated; moving between shots moves near planes more than far
// ones, so the room reads as a place, never a flat crop:
//
//   desk     a class day: the whole lamp, the chair, the desk and a sliver
//            of window, so the hour shows in the glass
//   kept     a mark: the camera eases back until the whole lamp and the
//            desk top are in frame, and the lamp's light opens on the desk
//   corner   the window and the armchair, the part of the room for resting
//
// The window glass shows the sky for the hour (morning, midday, afternoon,
// dusk); after dark it is the painting's own moonlit night. The fireplace
// stays outside every shot: it is ambient furniture and never answers
// progress. The lamp is the room's own light, and it answers a kept class.
//
// Other room styles are painted plates: [ClassRoomPlate] shows the plate held
// still behind the same layout.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../academic_calendar/domain/academic_schedule.dart'
    show OccurrenceMaterializer;
import '../../engine.dart';
import '../../content/quest_desk_styles.dart';
import '../home_room.dart';
import '../quest_depth_room.dart';

/// The hour the room is lit for.
enum RoomHour {
  morning,
  midday,
  afternoon,
  dusk,
  evening,
  night;

  /// The hour at [instant] on the timetable's own clock (so a phone or a
  /// test host in another zone still shows the class day's light).
  static RoomHour atInstant(DateTime instant, String? timeZoneId) {
    if (timeZoneId != null) {
      try {
        return at(OccurrenceMaterializer.localTime(instant, timeZoneId));
      } catch (_) {}
    }
    return at(instant.toLocal());
  }

  static RoomHour at(DateTime t) {
    final m = t.hour * 60 + t.minute;
    if (m < 6 * 60 + 40) return night;
    if (m < 10 * 60) return morning;
    if (m < 14 * 60) return midday;
    if (m < 17 * 60 + 50) return afternoon;
    if (m < 19 * 60 + 5) return dusk; // early October sunset ~18:35
    if (m < 22 * 60) return evening;
    return night;
  }

  bool get daylight => this == morning || this == midday || this == afternoon;
  bool get skyLit => daylight || this == dusk;
}

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

  /// The glass of the window (the frame and jambs stay painted).
  static const glass = Rect.fromLTRB(92, 58, 403, 586);

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
    // Far enough left that a strip of the window's glass shows the hour,
    // and the right edge short of the fireplace's stone (image x 1060).
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
    required this.hour,
    required this.shot,
    this.bloom = 0,
    this.warmth = 0,
    this.fadeStart,
    this.fadeEnd,
    this.scrim = 1,
    this.scrimHeight = classStatusScrimHeight,
  });

  final RoomHour hour;
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
      farOverlay: hour.skyLit ? ClassWindowSky(hour: hour) : null,
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
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix(_grade(hour)),
              child: room,
            ),
          ),
          if (hour.daylight)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _WindowLightPainter(shot, hour)),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _LampPainter(shot, hour, bloom: bloom, warmth: warmth),
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

  /// Colour matrices per hour. The painting is lamp-lit; daylight lifts the
  /// shadows and cools them toward the window, dusk warms, night deepens.
  static List<double> _grade(RoomHour hour) => switch (hour) {
    RoomHour.morning => _matrix(
      gain: [1.08, 1.12, 1.2],
      lift: [12, 13, 17],
      sat: 0.82,
    ),
    RoomHour.midday => _matrix(
      gain: [1.12, 1.14, 1.18],
      lift: [12, 12, 14],
      sat: 0.86,
    ),
    RoomHour.afternoon => _matrix(
      gain: [1.14, 1.09, 1.04],
      lift: [11, 8, 6],
      sat: 0.92,
    ),
    RoomHour.dusk => _matrix(
      gain: [1.06, 0.98, 0.94],
      lift: [4, 1, 2],
      sat: 0.96,
    ),
    RoomHour.evening => _matrix(
      gain: [1.02, 1.0, 0.98],
      lift: [0, 0, 0],
      sat: 1,
    ),
    RoomHour.night => _matrix(
      gain: [0.86, 0.84, 0.86],
      lift: [0, 0, 1],
      sat: 0.94,
    ),
  };

  static List<double> _matrix({
    required List<double> gain,
    required List<double> lift,
    required double sat,
  }) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final s = sat;
    final m = [
      [lr * (1 - s) + s, lg * (1 - s), lb * (1 - s)],
      [lr * (1 - s), lg * (1 - s) + s, lb * (1 - s)],
      [lr * (1 - s), lg * (1 - s), lb * (1 - s) + s],
    ];
    return [
      for (var r = 0; r < 3; r++) ...[
        m[r][0] * gain[r],
        m[r][1] * gain[r],
        m[r][2] * gain[r],
        0,
        lift[r],
      ],
      0,
      0,
      0,
      1,
      0,
    ];
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

/// The sky in the window for the hour, registered to the far plane of the
/// writer room (the class-day stage, and the board's room strip on a class
/// day).
///
/// The base painting's night glass is keyed out at runtime (its blue-black
/// sky and stars become transparent; the frame, mullions and nearer ridge
/// stay), and a painted sky sits behind it. No pixel of the plates is cut:
/// the same base raster is drawn again through a colour key, inside the
/// glass only, so it moves with the far plane exactly.
class ClassWindowSky extends StatelessWidget {
  const ClassWindowSky({super.key, required this.hour});

  final RoomHour hour;

  /// alpha' = A + 10R - 5G - 10B: blue-dark glass goes clear, warm-dark
  /// wood and the ridge stay. The colour passes through unchanged, so where
  /// the key keeps the wood the copy matches the painting under it and the
  /// edge of the glass leaves no seam.
  static const _key = ColorFilter.matrix([
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    10, -5, -10, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: 1635,
          height: 962,
          // Everything stays inside the glass as painted: its top runs down
          // to the right with the window's perspective, so the wall above it
          // is never keyed and the edge falls on the frame, where the copy
          // matches the painting under it.
          child: ClipPath(
            clipper: const _GlassClip(),
            child: Stack(
              children: [
                Positioned.fromRect(
                  rect: RoomMarks.glass,
                  child: CustomPaint(painter: _SkyPainter(hour)),
                ),
                Positioned.fill(
                  // A one-pixel softening in image space keeps the keyed
                  // mullions' edges from stair-stepping when the camera is
                  // close.
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 1.1, sigmaY: 1.1),
                    child: ColorFiltered(
                      colorFilter: _key,
                      child: Image.asset(
                        QuestDepthRoom.baseAsset,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
                // The painted crescent's warm rim survives the key; by day
                // the pane it sits in is simply sky.
                Positioned.fromRect(
                  rect: RoomMarks.glass,
                  child: CustomPaint(
                    painter: _SkyPainter(hour, moonPatch: true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The window's glass in image pixels: its top edge falls from the left
/// jamb to the right one (measured where the painting's night sky starts).
class _GlassClip extends CustomClipper<Path> {
  const _GlassClip();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(RoomMarks.glass.left, 54)
    ..lineTo(402, 166)
    ..lineTo(402, RoomMarks.glass.bottom)
    ..lineTo(RoomMarks.glass.left, RoomMarks.glass.bottom)
    ..close();

  @override
  bool shouldReclip(_GlassClip oldClipper) => false;
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.hour, {this.moonPatch = false});

  final RoomHour hour;

  /// Paint only a soft disc of the same sky over the painted moon.
  final bool moonPatch;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final colors = switch (hour) {
      RoomHour.morning => const [
        Color(0xFF8DA5BA),
        Color(0xFFB7C3C8),
        Color(0xFFE7D8BD),
      ],
      RoomHour.midday => const [
        Color(0xFF7E9DBA),
        Color(0xFFAABDCB),
        Color(0xFFDAD6C9),
      ],
      RoomHour.afternoon => const [
        Color(0xFF8A9EB0),
        Color(0xFFC0B6A4),
        Color(0xFFEBC793),
      ],
      _ => const [Color(0xFF3B3756), Color(0xFF8A5860), Color(0xFFE29A5C)],
    };
    final skyShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
      stops: const [0, 0.55, 0.86],
    ).createShader(rect);
    if (moonPatch) {
      final moon = RoomMarks.moon - RoomMarks.glass.topLeft;
      final patch = Paint()
        ..shader = skyShader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(moon, 38, patch);
      if (hour.daylight) {
        canvas.drawCircle(
          moon,
          38,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.08)
            ..blendMode = BlendMode.plus
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
      return;
    }
    canvas.drawRect(rect, Paint()..shader = skyShader);
    final day = hour.daylight;
    // A few soft clouds, still: the sky never loops.
    final cloud = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
      ..color = (day ? const Color(0xFFF4EEE4) : const Color(0xFFE7A777))
          .withValues(alpha: day ? 0.42 : 0.3);
    for (final c in const [
      (0.30, 0.20, 0.30, 0.045),
      (0.62, 0.30, 0.26, 0.035),
      (0.66, 0.50, 0.2, 0.03),
      (0.80, 0.14, 0.18, 0.03),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * c.$1, size.height * c.$2),
          width: size.width * c.$3 * 2,
          height: size.height * c.$4 * 2,
        ),
        cloud,
      );
    }
    // Far hills in haze behind the painting's own ridge.
    final hills = Path()
      ..moveTo(0, size.height * 0.80)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.70,
        size.width * 0.48,
        size.height * 0.77,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.68,
        size.width,
        size.height * 0.74,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      hills,
      Paint()
        ..color = day
            ? const Color(0xFF8E979C).withValues(alpha: 0.75)
            : const Color(0xFF4A3644).withValues(alpha: 0.9),
    );
    // Daylight blooms a little at the glass, the way a bright window does
    // in a dim room.
    if (day) {
      canvas.drawRect(
        rect,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.08)
          ..blendMode = BlendMode.plus,
      );
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.hour != hour || old.moonPatch != moonPatch;
}

class _WindowLightPainter extends CustomPainter {
  _WindowLightPainter(this.shot, this.hour);

  final RoomShot shot;
  final RoomHour hour;

  @override
  void paint(Canvas canvas, Size size) {
    final afternoon = hour == RoomHour.afternoon;
    final tint = afternoon ? const Color(0xFFFFD8A6) : const Color(0xFFF3EEE4);
    final strength = afternoon ? 0.16 : 0.13;

    // Light from the window lies across the wall behind the lamp and desk as
    // a tilted panel, with the mullion's shadow in it.
    final a = shot.toStage(Offset(410, afternoon ? 250 : 130));
    final b = shot.toStage(
      Offset(afternoon ? 1060 : 980, afternoon ? 390 : 300),
    );
    final c = shot.toStage(
      Offset(afternoon ? 1090 : 1020, afternoon ? 860 : 900),
    );
    final d = shot.toStage(Offset(430, afternoon ? 760 : 820));
    final panel = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..lineTo(d.dx, d.dy)
      ..close();
    final bounds = panel.getBounds();
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawPath(
      panel,
      Paint()
        ..blendMode = BlendMode.screen
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24)
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            tint.withValues(alpha: strength),
            tint.withValues(alpha: strength * 0.55),
            tint.withValues(alpha: 0),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(bounds),
    );
    final mid = Offset.lerp(a, b, 0.42)!;
    final midLow = Offset.lerp(d, c, 0.42)!;
    canvas.drawLine(
      mid,
      midLow,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..strokeWidth = 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..color = const Color(0xA0000000),
    );
    final l = Offset.lerp(a, d, 0.46)!;
    final r = Offset.lerp(b, c, 0.40)!;
    canvas.drawLine(
      l,
      r,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..color = const Color(0x90000000),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WindowLightPainter old) =>
      old.hour != hour || old.shot != shot;
}

/// The lamp: a resting pool that knows the hour, and the answer to a kept
/// class: the bulb brightens, a 420 pt halo opens around it, and its light
/// lands on the desk where the ring settles.
class _LampPainter extends CustomPainter {
  _LampPainter(
    this.shot,
    this.hour, {
    required this.bloom,
    required this.warmth,
  });

  final RoomShot shot;
  final RoomHour hour;
  final double bloom;
  final double warmth;

  @override
  void paint(Canvas canvas, Size size) {
    final lamp = shot.toStage(RoomMarks.bulb);
    final rest =
        switch (hour) {
          RoomHour.morning => 0.03,
          RoomHour.midday => 0.03,
          RoomHour.afternoon => 0.045,
          RoomHour.dusk => 0.07,
          RoomHour.evening => 0.085,
          RoomHour.night => 0.10,
        } +
        warmth * 0.045;
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
      old.bloom != bloom ||
      old.hour != hour ||
      old.warmth != warmth ||
      old.shot != shot;
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
