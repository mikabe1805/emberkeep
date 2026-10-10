// The Doorway's small objects: the ticket (live text over a painted card),
// the brass clip that joins a day's pair in the bowl, and the sprites' shared
// shade. Everything here is drawn at the stage's own scale (a full ticket is
// 96 x 31.56 pt) and sized by its caller.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../tokens.dart';
import 'class_day_model.dart';
import 'doorway_art.dart';
import 'doorway_model.dart';
import 'doorway_rail.dart';

/// A ticket's ink: warm brown letterpress on cream paper.
const _ink = Color(0xFF5A3C20);
const _inkQuiet = Color(0xFF6B5036);

/// The words on a ticket: a short capitals label and a time, in mono. Waiting
/// classes show their start, a class that has begun shows when it ends; an
/// optional meeting says so on a second line.
String doorwayTicketText(DoorwayTicket ticket) {
  final minute = ticket.state == DoorwayTicketState.upcoming
      ? ticket.startMinute
      : ticket.endMinute;
  final time = classClockShort(minute);
  if (!ticket.counts) return '${ticket.label}\n$time · optional';
  return '${ticket.label} · $time';
}

/// What a screen reader says for a ticket (the stage itself is a painting).
String doorwayTicketSemantics(DoorwayTicket ticket) =>
    '${classBriefTitle(ticket.entry.title)}, '
    '${classClock(ticket.startMinute)}';

/// A color matrix for [brightness] and [saturation] (1 leaves each alone).
ColorFilter doorwayTone({double brightness = 1, double saturation = 1}) {
  const lr = 0.2126;
  const lg = 0.7152;
  const lb = 0.0722;
  final sr = (1 - saturation) * lr;
  final sg = (1 - saturation) * lg;
  final sb = (1 - saturation) * lb;
  final k = brightness;
  return ColorFilter.matrix([
    (sr + saturation) * k, sg * k, sb * k, 0, 0, //
    sr * k, (sg + saturation) * k, sb * k, 0, 0,
    sr * k, sg * k, (sb + saturation) * k, 0, 0,
    0, 0, 0, 1, 0,
  ]);
}

/// A sprite with a soft shade under it, the way the painted objects sit on
/// the wall.
class DoorwaySprite extends StatelessWidget {
  const DoorwaySprite({
    super.key,
    required this.asset,
    this.tone,
    this.shadow = const Offset(0, 1.2),
    this.blur = 0.8,
    this.shadowColor = const Color(0x73140800),
  });

  final String asset;
  final ColorFilter? tone;
  final Offset shadow;

  /// The shade's blur (sigma, points).
  final double blur;
  final Color shadowColor;

  Widget _image(FilterQuality quality) => Image.asset(
    asset,
    fit: BoxFit.fill,
    filterQuality: quality,
    gaplessPlayback: true,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );

  @override
  Widget build(BuildContext context) {
    Widget art = _image(FilterQuality.medium);
    if (tone != null) art = ColorFiltered(colorFilter: tone!, child: art);
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Transform.translate(
          offset: shadow,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(shadowColor, BlendMode.srcIn),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: _image(FilterQuality.low),
            ),
          ),
        ),
        art,
      ],
    );
  }
}

/// One ticket: the painted card with its words and ring, in its holder, on a
/// hook, or in the bowl.
///
/// The card's states match the glass card's rings: a class that has ended
/// (or is in session) wears the plain brass ring; one still to come, the
/// dashed one; an attended one the checked face; and an optional meeting
/// (office hours) is quieter, with no ring at all. A squeezed ticket (a third
/// holder, an optional one) stretches its card, never its words.
class DoorwayTicketView extends StatelessWidget {
  const DoorwayTicketView({
    super.key,
    required this.ticket,
    this.kx = 1,
    this.ky = 1,
    this.inRail = false,
    this.attended,
    this.mini = false,
  });

  final DoorwayTicket ticket;

  /// How the card is stretched from its full size.
  final double kx;
  final double ky;

  /// Standing in a holder: it throws a contact shade and wears the rod's.
  final bool inRail;

  /// Whether to show the checked face (default: the ticket's own state).
  final bool? attended;

  /// A small ticket lying in the bowl: no words.
  final bool mini;

  @override
  Widget build(BuildContext context) {
    final att = attended ?? ticket.state == DoorwayTicketState.attended;
    final quiet = !ticket.counts || ticket.state == DoorwayTicketState.settled;
    final upcoming = ticket.state == DoorwayTicketState.upcoming;
    final ready = ticket.markable;
    final width = doorwayTicketWidth * kx;
    final height = doorwayTicketHeight * ky;
    final art = DoorwaySprite(
      asset: att ? DoorwayAssets.ticketAttended : DoorwayAssets.ticketBlank,
      tone: quiet && !att
          ? doorwayTone(brightness: 0.975, saturation: 0.8)
          : null,
      shadow: inRail ? const Offset(0, 1.2) : const Offset(1.6, 2.6),
      blur: inRail ? 0.8 : 1.2,
      shadowColor: Color(inRail ? 0x73140800 : 0x6B140800),
    );
    // The ring and the words keep their own size on a squeezed card; they
    // sit where the card's fractions put them.
    const ringSize = doorwayTicketWidth * 0.154;
    final ringAt = Offset(width * 0.856, height * 0.5275);
    return SizedBox(
      key: ValueKey('doorway-ticket-${ticket.id}'),
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: art),
          if (inRail) ...[
            // The contact shade on the wall under the card.
            Positioned(
              left: width * 0.04,
              right: -width * 0.01,
              top: height * 0.7,
              height: height * 0.42,
              child: const IgnorePointer(
                child: CustomPaint(painter: _ContactShade()),
              ),
            ),
          ],
          if (!mini) ...[
            if (!att && upcoming && !quiet)
              Positioned(
                left: ringAt.dx - ringSize / 2,
                top: ringAt.dy - ringSize / 2,
                width: ringSize,
                height: ringSize,
                child: const CustomPaint(painter: _DashedRing()),
              ),
            if (!att && quiet)
              Positioned(
                left: ringAt.dx - ringSize / 2,
                top: ringAt.dy - ringSize / 2,
                width: ringSize,
                height: ringSize,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE8D7BB),
                    boxShadow: [
                      BoxShadow(color: Color(0xFFE8D7BB), spreadRadius: 0.9),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: width * 0.074,
              top: 0,
              bottom: 0,
              width: doorwayTicketWidth * 0.69,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  doorwayTicketText(ticket),
                  maxLines: 2,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: Type.label.copyWith(
                    fontSize: 5.1,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.05,
                    height: ticket.counts ? 1 : 1.3,
                    color: ticket.counts ? _ink : _inkQuiet,
                    shadows: const [
                      Shadow(offset: Offset(0, 0.45), color: Color(0x99FFFAEC)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (inRail) ...[
            // The rod's shade across the card's top edge.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: height * 0.17,
              child: const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(2),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x8C1A0900),
                        Color(0x331A0900),
                        Color(0x001A0900),
                      ],
                      stops: [0, 0.55, 1],
                    ),
                  ),
                ),
              ),
            ),
            if (ready)
              // A class waiting to be marked catches the sunlight a touch,
              // never a glow.
              Positioned(
                left: 2,
                right: 2,
                top: 2,
                bottom: 2,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: const LinearGradient(
                        begin: Alignment(-0.9, -0.3),
                        end: Alignment(0.9, 0.3),
                        colors: [
                          Color(0x00FFE6AA),
                          Color(0x2EFFE2A0),
                          Color(0x0AFFE2A0),
                          Color(0x00FFE2A0),
                        ],
                        stops: [0.12, 0.4, 0.62, 0.78],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ContactShade extends CustomPainter {
  const _ContactShade();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.06,
        size.height * 0.1,
        size.width * 0.88,
        size.height * 0.62,
      ),
      Paint()
        ..color = const Color(0x6B160800)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );
  }

  @override
  bool shouldRepaint(_ContactShade old) => false;
}

/// The dashed ring of a class still to come.
class _DashedRing extends CustomPainter {
  const _DashedRing();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 0.55;
    canvas.drawCircle(c, r + 0.8, Paint()..color = const Color(0xFFE9D5B0));
    final paint = Paint()
      ..color = const Color(0xFFA47233)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.butt;
    const dashes = 10;
    const sweep = 6.283185307179586 / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        i * sweep,
        sweep * 0.55,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRing old) => false;
}

/// The brass clip that joins a day's two tickets in the bowl. Drawn in a
/// full-size ticket's own space (9 x 36.7 pt at its left edge); the caller
/// scales it with the ticket.
class DoorwayClip extends StatelessWidget {
  const DoorwayClip({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 9,
    height: 36.7,
    child: CustomPaint(painter: _ClipPainter()),
  );
}

class _ClipPainter extends CustomPainter {
  const _ClipPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: const Radius.circular(2),
      topRight: const Radius.circular(2),
      bottomLeft: const Radius.circular(1.5),
      bottomRight: const Radius.circular(1.5),
    );
    canvas.drawRRect(
      body.shift(const Offset(0, 1.3)),
      Paint()
        ..color = const Color(0x99140800)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.9),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF74511C),
            Color(0xFFE6BF68),
            Color(0xFFFBE2A0),
            Color(0xFFB98C3E),
            Color(0xFF7F5A22),
          ],
          stops: [0, 0.34, 0.48, 0.74, 1],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      body.deflate(0.35),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = const Color(0x8C3A2004),
    );
    final notch = Paint()..color = const Color(0x8C341C04);
    for (final y in const [11.0, 22.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1.6, y, size.width - 3.2, 1.1),
          const Radius.circular(1),
        ),
        notch,
      );
    }
    // The little loop over the top.
    final loop = Rect.fromLTWH(2.2, -3, 4.6, 4);
    canvas.drawPath(
      Path()
        ..moveTo(loop.left, loop.bottom)
        ..lineTo(loop.left, loop.top + 2.3)
        ..arcToPoint(
          Offset(loop.right, loop.top + 2.3),
          radius: const Radius.circular(2.3),
        )
        ..lineTo(loop.right, loop.bottom),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFFC9A050),
    );
  }

  @override
  bool shouldRepaint(_ClipPainter old) => false;
}

/// The strings a hung ticket's two corners hang by, from their hooks.
class DoorwayStrings extends CustomPainter {
  DoorwayStrings(this.strings);

  /// Each string: from a hook to the ticket's corner (points).
  final List<(Offset, Offset)> strings;

  @override
  void paint(Canvas canvas, Size size) {
    final shade = Paint()
      ..color = const Color(0x731E0C02)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final cord = Paint()
      ..color = const Color(0xFFE8D7AE)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    for (final (from, to) in strings) {
      canvas.drawLine(from.translate(0.6, 1), to.translate(0.6, 1), shade);
      canvas.drawLine(from, to, cord);
    }
  }

  @override
  bool shouldRepaint(DoorwayStrings old) => old.strings != strings;
}
