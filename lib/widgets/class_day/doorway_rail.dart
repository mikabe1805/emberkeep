// The Doorway's ticket rail: how many holders the wall has today, where each
// waiting ticket sits, and the painter that builds the rail from slices of the
// current light's own plate.
//
// The painted door-view plates carry two holders. The wall holds one to three
// tickets at a time (full size for one or two, about 89% height for three);
// every later ticket waits off the wall and is clipped in when a slot frees.
// So the rail is drawn live: each light's plate yields its end brackets, its
// holder unit, its plaster pocket and the brass front lip, and the same
// pieces are laid out for however many holders the day needs. All of it
// cross-fades with the light, like the plates, and the lip is drawn over the
// tickets so they tuck in behind the brass.
//
// Plate pixels are three per point (the plates are 1179 x 2556 for a
// 393 x 852 pt screen).
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'doorway_model.dart';

/// A full ticket's size in points (the sprite's own aspect).
const double doorwayTicketWidth = 96;
const double doorwayTicketHeight = 96 * 288 / 876;

/// The rail's ticket column: the tickets' centers sit at this x (points).
const double doorwayRailCenterX = 322;

/// The top edge of a full ticket in the first holder, and the lowest a
/// ticket on the wall may reach (points): the wall between the hook row and
/// the key bowl.
const double doorwayWallTop = 767 / 3;
const double doorwayWallBottom = 329;

/// The most tickets the wall holds at once.
const int doorwayRailSlots = 3;

/// The pixel box the rail is drawn in (plate pixels), and its place.
const double doorwayRailX0 = 806;
const double doorwayRailY0 = 744;
const double doorwayRailW = 336;
const double doorwayRailH = 224;

/// The holder's plate-pixel y for the first slot, and a full pocket's pitch.
const double _firstHolderY = 752;
const double _fullPitchPx = 122;

/// Which painted holder unit a holder uses: the upper one (end brackets and
/// the rod over a pocket), or the lower one (brackets, rod and plank).
enum DoorwayHolderKind { top, bottom }

/// One holder on the wall, in plate pixels.
final class DoorwayHolder {
  const DoorwayHolder({
    required this.key,
    required this.y,
    required this.kind,
    this.fromKind,
    this.mix = 1,
    this.alpha = 1,
  });

  final String key;

  /// The holder unit's top, in plate pixels.
  final double y;
  final DoorwayHolderKind kind;

  /// While one holder turns into another kind (the last holder when the day
  /// gains a slot), the kind it was and how far along the change is.
  final DoorwayHolderKind? fromKind;
  final double mix;

  /// Fades a holder in as the day gains a slot and out as it loses one.
  final double alpha;

  DoorwayHolder copyWith({
    double? y,
    DoorwayHolderKind? kind,
    DoorwayHolderKind? fromKind,
    double? mix,
    double? alpha,
  }) => DoorwayHolder(
    key: key,
    y: y ?? this.y,
    kind: kind ?? this.kind,
    fromKind: fromKind,
    mix: mix ?? this.mix,
    alpha: alpha ?? this.alpha,
  );

  @override
  bool operator ==(Object other) =>
      other is DoorwayHolder &&
      other.key == key &&
      other.y == y &&
      other.kind == kind &&
      other.fromKind == fromKind &&
      other.mix == mix &&
      other.alpha == alpha;

  @override
  int get hashCode => Object.hash(key, y, kind, fromKind, mix, alpha);
}

/// A waiting ticket's place on the wall (points), in its holder.
final class DoorwayPlacedTicket {
  const DoorwayPlacedTicket({
    required this.ticket,
    required this.slot,
    required this.center,
    required this.kx,
    required this.ky,
  });

  final DoorwayTicket ticket;
  final int slot;

  /// The ticket's center on the stage.
  final Offset center;

  /// How the sprite is stretched from its full size (an optional meeting's
  /// ticket is a little smaller; a third holder squeezes every ticket).
  final double kx;
  final double ky;

  Size get size => Size(doorwayTicketWidth * kx, doorwayTicketHeight * ky);

  /// The ticket's rect on the stage.
  Rect get rect => Rect.fromCenter(
    center: center,
    width: doorwayTicketWidth * kx,
    height: doorwayTicketHeight * ky,
  );
}

/// How today's tickets lay out on the wall.
final class DoorwayRailLayout {
  const DoorwayRailLayout({
    required this.slots,
    required this.holders,
    required this.placed,
    required this.queued,
    required this.scale,
  });

  /// The holders the wall has (never zero: an empty day keeps one).
  final int slots;
  final List<DoorwayHolder> holders;

  /// The tickets standing in their holders, in slot order.
  final List<DoorwayPlacedTicket> placed;

  /// Tickets waiting off the wall for a slot to free, in order.
  final List<DoorwayTicket> queued;

  /// How tall a full ticket is drawn (1, or about 0.89 for three slots).
  final double scale;

  /// The wall's layout for [day].
  ///
  /// Up to three classes a day, each has a holder of its own that stays when
  /// its ticket goes to a hook. From four, the holders follow the tickets
  /// still waiting (never more than three); the rest queue off the wall. A
  /// class that was set aside has no holder.
  factory DoorwayRailLayout.of(DoorwayDay day) {
    final visible = day.visibleTickets;
    final byDay = visible.length <= doorwayRailSlots;
    final waiting = [
      for (final ticket in visible)
        if (ticket.state != DoorwayTicketState.attended) ticket,
    ];
    final List<DoorwayTicket?> slotted;
    final List<DoorwayTicket> queued;
    if (byDay) {
      slotted = [
        for (final ticket in visible)
          ticket.state == DoorwayTicketState.attended ? null : ticket,
      ];
      queued = const [];
    } else {
      final shown = waiting.take(doorwayRailSlots).toList();
      slotted = [...shown];
      queued = waiting.skip(doorwayRailSlots).toList();
    }
    return DoorwayRailLayout.forSlots(slotted, queued);
  }

  /// A wall of [slotted].length holders ([slotted] holds null for an empty
  /// one), with [queued] waiting off it.
  factory DoorwayRailLayout.forSlots(
    List<DoorwayTicket?> slotted,
    List<DoorwayTicket> queued,
  ) {
    final n = slotted.length;
    final double scale;
    final double pitchPx;
    if (n <= 2) {
      scale = 1;
      pitchPx = _fullPitchPx;
    } else {
      // Three holders: the whole face of each ticket still shows, only the
      // empty paper at the bottom edge is covered by the next holder.
      const rho = 0.8;
      scale =
          (doorwayWallBottom - doorwayWallTop) /
          (doorwayTicketHeight * (1 + (n - 1) * rho));
      pitchPx = rho * doorwayTicketHeight * scale * 3;
    }
    final holderCount = math.max(1, n);
    final holders = [
      for (var k = 0; k < holderCount; k++)
        DoorwayHolder(
          key: 'h$k',
          y: _firstHolderY + k * pitchPx,
          kind: k == holderCount - 1 && holderCount >= 2
              ? DoorwayHolderKind.bottom
              : DoorwayHolderKind.top,
        ),
    ];
    final placed = <DoorwayPlacedTicket>[];
    for (var k = 0; k < n; k++) {
      final ticket = slotted[k];
      if (ticket == null) continue;
      final optional = !ticket.counts;
      final kx = optional ? 0.94 : 1.0;
      final ky = scale * (optional ? 0.9 : 1.0);
      final top = (_firstHolderY + k * pitchPx + 15) / 3;
      placed.add(
        DoorwayPlacedTicket(
          ticket: ticket,
          slot: k,
          center: Offset(
            doorwayRailCenterX,
            top + doorwayTicketHeight * ky / 2,
          ),
          kx: kx,
          ky: ky,
        ),
      );
    }
    return DoorwayRailLayout(
      slots: holderCount,
      holders: List.unmodifiable(holders),
      placed: List.unmodifiable(placed),
      queued: List.unmodifiable(queued),
      scale: scale,
    );
  }
}

/// The holders between two layouts at [u] (0 to 1): the ones both have glide,
/// a holder the day gains grows in, one it loses fades out, and a last
/// holder that changes unit crosses over.
List<DoorwayHolder> doorwayRailBlend(
  List<DoorwayHolder> from,
  List<DoorwayHolder> to,
  double u,
) {
  if (u >= 1 || from.isEmpty) return to;
  final e = Curves.easeInOut.transform(u.clamp(0.0, 1.0));
  final left = {for (final holder in from) holder.key: holder};
  final out = <DoorwayHolder>[];
  for (final holder in to) {
    final was = left.remove(holder.key);
    if (was == null) {
      out.add(holder.copyWith(alpha: e));
    } else {
      out.add(
        holder.copyWith(
          y: was.y + (holder.y - was.y) * e,
          fromKind: was.kind != holder.kind ? was.kind : null,
          mix: e,
          alpha: was.alpha + (1 - was.alpha) * e,
        ),
      );
    }
  }
  for (final gone in left.values) {
    out.add(gone.copyWith(alpha: gone.alpha * (1 - e), fromKind: null));
  }
  out.sort((a, b) => a.y.compareTo(b.y));
  return out;
}

// ── The painter ───────────────────────────────────────────────────────────

/// Where each piece sits in a rail atlas (assets/rooms/doorway/rail-*.webp,
/// 336 px wide, each piece four transparent rows apart so a smooth sample
/// never reads its neighbor): the plate crop of the rail, the upper and lower holder
/// slices, their brass front lips, the plaster pocket and the plant mask.
abstract final class DoorwayRailAtlas {
  static const crop = Rect.fromLTWH(0, 0, 336, 216);
  static const upper = Rect.fromLTWH(0, 220, 336, 63);
  static const lower = Rect.fromLTWH(0, 287, 336, 72);
  static const lipUpper = Rect.fromLTWH(0, 363, 336, 66);
  static const lipLower = Rect.fromLTWH(0, 433, 336, 68);
  static const pocket = Rect.fromLTWH(0, 505, 336, 146);
  static const plant = Rect.fromLTWH(0, 655, 139, 160);
}

/// What a rail painter reads each frame.
abstract interface class DoorwayRailSource implements Listenable {
  /// The holders to draw now.
  List<DoorwayHolder> get railHolders;

  /// Per light (midday, golden, evening): the opacity its rail is drawn at.
  List<double> get railFades;

  /// The three lights' atlases (null while one is still decoding).
  List<ui.Image?> get railAtlases;
}

/// Draws the rail's body (pocket, holders, plank and plaster) from the
/// current light's plate, or its brass front lip, which goes over the tickets.
class DoorwayRailPainter extends CustomPainter {
  DoorwayRailPainter({required this.source, required this.lip})
    : super(repaint: source);

  final DoorwayRailSource source;

  /// False: the body, under the tickets. True: the lip, over them.
  final bool lip;

  @override
  void paint(Canvas canvas, Size size) {
    final fades = source.railFades;
    final atlases = source.railAtlases;
    final holders = source.railHolders;
    canvas.save();
    canvas.scale(size.width / doorwayRailW, size.height / doorwayRailH);
    const box = Rect.fromLTWH(0, 0, doorwayRailW, doorwayRailH);
    for (var k = 0; k < 3; k++) {
      final fade = fades[k];
      final atlas = atlases[k];
      if (fade <= 0.0005 || atlas == null) continue;
      canvas.saveLayer(
        box,
        Paint()..color = Colors.white.withValues(alpha: fade),
      );
      if (lip) {
        _paintLip(canvas, atlas, holders);
      } else {
        _paintBody(canvas, atlas, holders);
      }
      canvas.restore();
    }
    canvas.restore();
  }

  static final Paint _quality = Paint()..filterQuality = FilterQuality.medium;

  void _piece(
    Canvas canvas,
    ui.Image atlas,
    Rect from,
    double dx,
    double dy,
    double alpha, {
    Rect? sub,
  }) {
    final src = sub == null
        ? from
        : Rect.fromLTWH(
            from.left + sub.left,
            from.top + sub.top,
            sub.width,
            sub.height,
          );
    final dst = Rect.fromLTWH(dx, dy, src.width, src.height);
    canvas.drawImageRect(
      atlas,
      src,
      dst,
      alpha >= 0.999
          ? _quality
          : (Paint()
              ..filterQuality = FilterQuality.medium
              ..color = Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0))),
    );
  }

  void _paintBody(Canvas canvas, ui.Image atlas, List<DoorwayHolder> holders) {
    const y0 = doorwayRailY0;
    // The plaster under the lower holder, with its painted holder and side
    // rods taken away (plate rows 812 to 958).
    _piece(canvas, atlas, DoorwayRailAtlas.pocket, 0, 812 - y0, 1);
    for (var i = 0; i < holders.length; i++) {
      final holder = holders[i];
      final next = i + 1 < holders.length ? holders[i + 1].y : null;
      final hasUpper =
          holder.kind == DoorwayHolderKind.top ||
          holder.fromKind == DoorwayHolderKind.top;
      if (hasUpper) {
        final top = holder.y + 60;
        if (next == null) {
          // Only the shadow the plank throws.
          _piece(
            canvas,
            atlas,
            DoorwayRailAtlas.crop,
            838 - doorwayRailX0,
            top - y0,
            holder.alpha,
            sub: const Rect.fromLTWH(838 - doorwayRailX0, 812 - y0, 262, 14),
          );
        } else {
          // The pocket's plaster and brass side rods, stretched to the gap
          // by repeating its middle rows.
          var rem = next - top + 4;
          var src = 812.0;
          var dy = top;
          while (rem > 0) {
            final ch = math.min(rem, src == 812 ? 62.0 : 44.0);
            _piece(
              canvas,
              atlas,
              DoorwayRailAtlas.crop,
              0,
              dy - y0,
              holder.alpha,
              sub: Rect.fromLTWH(0, src - y0, doorwayRailW, ch),
            );
            dy += ch;
            rem -= ch;
            src = 830;
          }
        }
      }
      void body(DoorwayHolderKind kind, double alpha) {
        if (kind == DoorwayHolderKind.top) {
          _piece(
            canvas,
            atlas,
            DoorwayRailAtlas.upper,
            0,
            holder.y - 3 - y0,
            alpha,
          );
        } else {
          _piece(
            canvas,
            atlas,
            DoorwayRailAtlas.lower,
            0,
            holder.y - y0,
            alpha,
          );
        }
      }

      final was = holder.fromKind;
      if (was != null) {
        body(was, holder.alpha);
        body(holder.kind, holder.alpha * holder.mix);
      } else {
        body(holder.kind, holder.alpha);
      }
    }
    // The plant's leaf stands in front of the rail's lower right corner, as
    // painted: punch it back out of the rail.
    canvas.drawImageRect(
      atlas,
      DoorwayRailAtlas.plant,
      const Rect.fromLTWH(1040 - doorwayRailX0, 880 - doorwayRailY0, 139, 160),
      Paint()
        ..blendMode = BlendMode.dstOut
        ..filterQuality = FilterQuality.medium,
    );
  }

  void _paintLip(Canvas canvas, ui.Image atlas, List<DoorwayHolder> holders) {
    const y0 = doorwayRailY0;
    for (final holder in holders) {
      void piece(DoorwayHolderKind kind, double alpha) {
        final from = kind == DoorwayHolderKind.top
            ? DoorwayRailAtlas.lipUpper
            : DoorwayRailAtlas.lipLower;
        final dy = holder.y - 2 - y0;
        // A thin shade under the brass, so the tickets read as tucked behind
        // it.
        canvas.save();
        canvas.translate(0, 1.35);
        canvas.drawImageRect(
          atlas,
          from,
          Rect.fromLTWH(0, dy, from.width, from.height),
          Paint()
            ..filterQuality = FilterQuality.medium
            ..colorFilter = ColorFilter.mode(
              const Color(0x99140800).withValues(alpha: 0.6 * alpha),
              BlendMode.srcIn,
            )
            ..imageFilter = ui.ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2),
        );
        canvas.restore();
        _piece(canvas, atlas, from, 0, dy, alpha);
      }

      final was = holder.fromKind;
      if (was != null) {
        piece(was, holder.alpha);
        piece(holder.kind, holder.alpha * holder.mix);
      } else {
        piece(holder.kind, holder.alpha);
      }
    }
  }

  @override
  bool shouldRepaint(DoorwayRailPainter old) =>
      old.source != source || old.lip != lip;
}
