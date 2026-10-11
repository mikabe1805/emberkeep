// The Goals tab as the Steward's workshop: a room, not a page.
//
// The painted plate (assets/rooms/house/plate-goals-midday.webp) is the whole
// screen. Three live things stand in it, all glass over the painting:
//
//   the sign        a glass sign on the pillar: the Steward's workshop. It is
//                   the way in (a new goal, or turning one into a first step)
//                   and the one thing the lamp's glint crosses on arrival.
//   the wall        the player's goals as small glass labels pinned on the
//                   sheets on the wall. The lit one is the current goal; a tap
//                   on another makes it the current goal (the card swaps and
//                   the lit edge moves), a tap on the lit one opens it. With
//                   more goals than sheets a quiet "+N" tag hangs below the
//                   lowest label and unrolls MORE at Other goals. A long
//                   name beside the sign stops short of it with an ellipsis.
//                   A label whose glass would sit under the card (or within
//                   8 pt of its top edge), or that would be too short to read
//                   beside the sign, is not drawn, as on a short phone; its
//                   goal stays in MORE, and the tag counts it.
//   the card        the current goal, its next thing, and its one action; or,
//                   with no goal yet, the Steward's invitation. A quiet "more"
//                   unrolls everything else Goals has (other and finished
//                   goals, the Steward's starting points, a smaller start,
//                   guided workouts).
//
// This file is presentation only: it takes plain data and callbacks, and the
// Goals page (lib/screens/goals.dart) owns every decision. Positions are the
// prototype's (v4 "Goals"), in the 393 x 852 canvas the plate was painted for:
// the plate is laid out by width, so a canvas point sits at `x * width / 393`.
//
// Large text (more than about 115 percent) leaves the calibrated layout for a
// scrolling one in which the same three things follow each other down the
// page, so nothing overlaps or is cut off. Reduce Motion removes the swap and
// the unrolling; it keeps every control.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../audio.dart';
import '../../../tokens.dart';
import '../../class_day/class_day_room.dart' show ClassGlass, classStatusAbove;
import '../../pressable.dart';
import '../house_backdrop.dart';
import '../house_hud.dart' show houseHudBottom;
import '../house_room.dart';
import '../house_travel_scope.dart';

// ── The room's measurements ──────────────────────────────────────────────

/// Where the sign hangs on the pillar (canvas points).
const double goalsSignLeft = 10;
const double goalsSignTop = 195;
const double goalsSignWidth = 128;

/// Where a goal's label is pinned, by slot: its top edge and its distance
/// from the right edge of the screen (canvas points). The three painted sheets
/// on the wall, from the prototype.
const List<({double top, double right})> goalsWallSlots = [
  (top: 178, right: 24),
  (top: 225, right: 35),
  (top: 320, right: 7),
];

/// How many goals the wall can hold.
int get goalsWallCapacity => goalsWallSlots.length;

/// The text size above which the room leaves the calibrated layout.
const double goalsRoomLargeText = 1.15;

/// The card's gap above the dock.
const double goalsCardGap = 20;

/// The shell's dock (88 pt plus the home indicator) sits over the page.
double goalsDockHeight(BuildContext context) =>
    88 + MediaQuery.paddingOf(context).bottom;

const Color _ink = Color(0xFFF6EAD3);
const Color _dim = Color(0xFFB8A784);
const Color _honey = Color(0xFFE0B66D);

TextStyle _serif(double size, {Color color = _ink, double height = 1.08}) =>
    TextStyle(
      fontFamily: 'EBGaramond',
      fontSize: size,
      height: height,
      fontWeight: FontWeight.w500,
      color: color,
    );

TextStyle _mono(
  double size, {
  Color color = _ink,
  double spacing = 0.4,
  FontWeight weight = FontWeight.w500,
  double height = 1.25,
}) => TextStyle(
  fontFamily: 'JetBrainsMono',
  fontSize: size,
  height: height,
  letterSpacing: spacing,
  fontWeight: weight,
  color: color,
);

/// [text] with its last two words bound, so a line never ends on one word.
String _keepEnd(String text) {
  final at = text.lastIndexOf(' ');
  return at < 0 ? text : '${text.substring(0, at)} ${text.substring(at + 1)}';
}

/// How long the card's content and the wall's lit edge take to change hands
/// when another goal becomes the current one.
const Duration goalsSwapDuration = Duration(milliseconds: 220);

bool goalsLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1) > goalsRoomLargeText;

bool goalsStill(BuildContext context, bool reduceMotion) =>
    reduceMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

// ── The data ─────────────────────────────────────────────────────────────

/// One goal's label on the wall.
class GoalsWallEntry {
  const GoalsWallEntry({
    required this.id,
    required this.title,
    required this.lit,
    required this.onTap,
  });

  /// A stable id (the goal's key), for the label's widget key.
  final String id;
  final String title;

  /// The current goal.
  final bool lit;

  /// What a tap does: the page decides (another goal becomes the current one,
  /// the current one opens its page).
  final VoidCallback onTap;
}

/// Picks the goals the wall shows, in the order they were made, at most
/// [capacity] of them. The current goal is always among them: when it would
/// fall past the last sheet it takes that sheet's place.
List<T> goalsOnTheWall<T>(List<T> goals, {required T? current, int? capacity}) {
  final cap = capacity ?? goalsWallCapacity;
  if (goals.length <= cap) return List<T>.of(goals);
  final shown = goals.take(cap).toList();
  if (current != null && !shown.contains(current)) {
    shown[cap - 1] = current;
  }
  return shown;
}

// ── The room ─────────────────────────────────────────────────────────────

/// A wall label (or the "+N" tag) is not drawn when its glass would sit under
/// the card, or nearer than this to the card's top edge, or to the sign.
const double _wallClearance = 8;

/// The least room a label's text gets beside the sign before its goal waits
/// in MORE instead (points): about eight capitals, a name you can still read.
const double _shortestWallText = 64;

/// How much scroll the dissolve under the HUD takes to come up over (points):
/// the Journal's.
const double _hudDissolveScroll = 60;

TextStyle _wallLabelStyle() => _mono(11, color: const Color(0xFFF1E4CD));

TextStyle _wallTagStyle() =>
    _mono(11, color: const Color(0xFFD9C9A8), spacing: 0.6);

TextStyle _signTitleStyle() => _serif(15.5);

TextStyle _signDetailStyle() => _mono(
  10.5,
  color: const Color(0xFFC9B99F),
  spacing: 0,
  weight: FontWeight.w400,
  height: 1.35,
);

/// The size [text] takes where a Text widget lays it out in [style]: at the
/// reader's text size, no wider than [maxWidth], on one line when [oneLine]
/// (the rest is cut with an ellipsis).
Size _measureText(
  BuildContext context,
  String text,
  TextStyle style,
  double maxWidth, {
  bool oneLine = true,
  TextAlign align = TextAlign.start,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    textAlign: align,
    maxLines: oneLine ? 1 : null,
    ellipsis: oneLine ? '…' : null,
  )..layout(maxWidth: maxWidth);
  final size = painter.size;
  painter.dispose();
  return size;
}

/// The height of the sign's glass at the reader's text size.
double _signGlassHeight(BuildContext context, String detail) {
  const inner = goalsSignWidth - 16;
  final title = _measureText(
    context,
    'The Steward’s workshop',
    _signTitleStyle(),
    inner,
    oneLine: false,
    align: TextAlign.center,
  );
  final body = _measureText(
    context,
    _keepEnd(detail),
    _signDetailStyle(),
    inner,
    oneLine: false,
    align: TextAlign.center,
  );
  return 20 + title.height + 5 + body.height;
}

/// What the calibrated wall draws at one size: the labels that are clear of the
/// card and the sign, the sign's own place, and the "+N" tag when there is
/// room for it.
class _WallPlan {
  const _WallPlan({
    required this.labels,
    required this.widths,
    required this.signTop,
    required this.tagTop,
    required this.more,
  });

  /// The labels that are drawn, by the slot (sheet) each hangs on.
  final Map<int, GoalsWallEntry> labels;

  /// How wide each drawn label's box may be (its text ends in an ellipsis
  /// past that), by slot: narrower beside the sign.
  final Map<int, double> widths;

  /// Where the sign hangs (points from the page's top).
  final double signTop;

  /// Where the "+N" tag's glass starts, or null when it is not drawn.
  final double? tagTop;

  /// The goals that are not on the wall: what the tag counts.
  final int more;
}

/// The Goals room: the plate with the sign, the wall and the card over it.
class HouseGoalsRoom extends StatefulWidget {
  const HouseGoalsRoom({
    super.key,
    required this.signDetail,
    required this.onSign,
    required this.wall,
    required this.card,
    this.moreGoals = 0,
    this.onMoreGoals,
    this.moreOpen = false,
    this.parallax,
    this.reduceMotion = false,
  });

  /// The sign's second line.
  final String signDetail;
  final VoidCallback onSign;
  final List<GoalsWallEntry> wall;

  /// The glass card (built by [GoalsFocusCard] or [GoalsEmptyCard]).
  final Widget card;

  /// How many goals have no sheet on the wall. With these, and any whose label
  /// would sit under the card or the sign, a "+N" tag hangs below the lowest
  /// label that is drawn and [onMoreGoals] answers it.
  final int moreGoals;
  final VoidCallback? onMoreGoals;

  /// MORE is unrolled: the "+N" has done its work and fades away (the unrolled
  /// card would cover half of it).
  final bool moreOpen;
  final ValueListenable<Offset>? parallax;
  final bool reduceMotion;

  @override
  State<HouseGoalsRoom> createState() => _HouseGoalsRoomState();
}

class _HouseGoalsRoomState extends State<HouseGoalsRoom> {
  /// The page's scroll at large text (the dissolve under the HUD follows it).
  final ScrollController _scroll = ScrollController();

  /// Where the card's top was at rest, and the room's size then: the wall is
  /// laid out by the card as it rests, so unrolling MORE does not take labels
  /// off the wall.
  Size? _restSize;
  double? _restCardTop;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = goalsStill(context, widget.reduceMotion);
    final large = goalsLargeText(context);
    final sign = GoalsRoomSign(detail: widget.signDetail, onTap: widget.onSign);
    return HouseRoomBackdrop(
      room: HouseRoom.goals,
      parallax: widget.parallax,
      reduceMotion: still,
      // The calibrated room needs no veil: its text is on glass. The scrolling
      // layout puts glass over the whole painting, so it gets a soft dark.
      veilFrom: large ? 90 : null,
      child: LayoutBuilder(
        builder: (context, box) {
          if (large) return _scrolling(context, box, sign);
          return _calibrated(context, box, sign);
        },
      ),
    );
  }

  Widget _calibrated(BuildContext context, BoxConstraints box, Widget sign) {
    final dock = goalsDockHeight(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The wall has what is left above the card, so it knows exactly where
        // the card's top is and draws only what is clear of it.
        Expanded(
          child: LayoutBuilder(
            builder: (context, space) {
              final size = Size(box.maxWidth, box.maxHeight);
              if (!widget.moreOpen ||
                  _restSize != size ||
                  _restCardTop == null) {
                _restSize = size;
                _restCardTop = space.maxHeight;
              }
              final plan = _plan(context, box.maxWidth, _restCardTop!);
              return _wallLayer(context, box.maxWidth, plan, sign);
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, dock + goalsCardGap),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (box.maxHeight - dock) * 0.52,
            ),
            child: widget.card,
          ),
        ),
      ],
    );
  }

  /// Which labels the wall can draw above a card whose top is [cardTop], where
  /// the sign hangs, and whether the "+N" tag has room.
  _WallPlan _plan(BuildContext context, double width, double cardTop) {
    final wall = widget.wall;
    final k = width / houseCanvasWidth;
    final above = classStatusAbove(context);
    double y(double canvas) => canvas * k - above;

    // The sign hangs where the plate was painted for it, a little higher when
    // the card would otherwise sit on its lower edge.
    final signHeight = _signGlassHeight(context, widget.signDetail);
    final hud = houseHudBottom(
      textScale: MediaQuery.textScalerOf(context).scale(1),
    );
    var signTop = y(goalsSignTop);
    final highest = cardTop - _wallClearance - signHeight;
    if (signTop > highest) signTop = math.max(highest, hud + 4);
    final sign = Rect.fromLTWH(
      goalsSignLeft * k,
      signTop,
      goalsSignWidth,
      signHeight,
    ).inflate(_wallClearance / 2);

    // A label's box is its text plus the glass's padding (21) and the tap
    // target's sides (12).
    final textRoom = width * 0.72 - 12 - 21;

    // Where a label's glass sits on [slot] with its text at most [room] wide.
    Rect glassFor(int slot, GoalsWallEntry entry, double room) {
      final text = _measureText(
        context,
        entry.title.toUpperCase(),
        _wallLabelStyle(),
        room,
      );
      final w = 21 + text.width;
      final h = 10 + math.max<double>(14, text.height);
      final right = width - goalsWallSlots[slot].right * k - 6;
      return Rect.fromLTWH(right - w, y(goalsWallSlots[slot].top), w, h);
    }

    // The label's glass and its text room on [slot], or null when it cannot
    // be drawn there. A long name beside the sign stops short of it and ends
    // in an ellipsis; only a label left too short to read waits in MORE.
    ({Rect glass, double room})? fit(int slot, GoalsWallEntry entry) {
      var room = textRoom;
      var g = glassFor(slot, entry, room);
      if (g.overlaps(sign)) {
        final right = width - goalsWallSlots[slot].right * k - 6;
        room = math.min(textRoom, right - sign.right - 21);
        if (room < _shortestWallText) return null;
        g = glassFor(slot, entry, room);
      }
      if (g.bottom + _wallClearance > cardTop || g.overlaps(sign)) return null;
      return (glass: g, room: room);
    }

    final slots = math.min(wall.length, goalsWallSlots.length);
    final labels = <int, GoalsWallEntry>{};
    final fits = <int, ({Rect glass, double room})>{};
    for (var i = 0; i < slots; i++) {
      final f = fit(i, wall[i]);
      if (f == null) continue;
      labels[i] = wall[i];
      fits[i] = f;
    }
    // The current goal keeps a lit label if any sheet can hold it: when its
    // own is covered it takes the lowest sheet that is clear.
    final lit = wall.indexWhere((e) => e.lit);
    if (lit >= 0 && !labels.containsKey(lit)) {
      for (var j = goalsWallSlots.length - 1; j >= 0; j--) {
        final f = fit(j, wall[lit]);
        if (f != null) {
          labels[j] = wall[lit];
          fits[j] = f;
          break;
        }
      }
    }

    final more = widget.moreGoals + wall.length - labels.length;
    double? tagTop;
    if (more > 0 && widget.onMoreGoals != null && labels.isNotEmpty) {
      final low = labels.keys.reduce(math.max);
      final under = fits[low]!.glass;
      final tagText = _measureText(
        context,
        '+$more',
        _wallTagStyle(),
        double.infinity,
      );
      final top = under.bottom + _tagGap;
      if (top + tagText.height + 5 + _wallClearance <= cardTop) tagTop = top;
    }
    return _WallPlan(
      labels: labels,
      widths: {for (final e in fits.entries) e.key: e.value.room + 12 + 21},
      signTop: signTop,
      tagTop: tagTop,
      more: more,
    );
  }

  Widget _wallLayer(
    BuildContext context,
    double width,
    _WallPlan plan,
    Widget sign,
  ) {
    final k = width / houseCanvasWidth;
    final above = classStatusAbove(context);
    double y(double canvas) => canvas * k - above;
    final lowest = plan.labels.isEmpty
        ? null
        : plan.labels.keys.reduce(math.max);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: goalsSignLeft * k,
          top: plan.signTop,
          width: goalsSignWidth,
          child: HouseGlintSweep(child: sign),
        ),
        for (final slot in plan.labels.keys)
          Positioned(
            key: ValueKey<int>(slot),
            top: y(goalsWallSlots[slot].top) - _hitPad,
            right: goalsWallSlots[slot].right * k,
            width: plan.widths[slot] ?? width * 0.72,
            child: Align(
              alignment: Alignment.centerRight,
              child: GoalsWallLabel(entry: plan.labels[slot]!, maxLines: 1),
            ),
          ),
        if (plan.tagTop != null && lowest != null)
          // Just below the lowest label's glass.
          Positioned(
            top: plan.tagTop,
            right: goalsWallSlots[lowest].right * k,
            child: GoalsWallMoreTag(
              count: plan.more,
              onTap: widget.onMoreGoals!,
              hidden: widget.moreOpen,
              reduceMotion: goalsStill(context, widget.reduceMotion),
            ),
          ),
      ],
    );
  }

  Widget _scrolling(BuildContext context, BoxConstraints box, Widget sign) {
    final above = classStatusAbove(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final wall = widget.wall;
    final showsTag =
        widget.moreGoals > 0 && widget.onMoreGoals != null && wall.isNotEmpty;
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        ListView(
          key: const Key('goals-threshold-scroll'),
          controller: _scroll,
          // The page starts under the shell's HUD, never behind it.
          padding: EdgeInsets.fromLTRB(
            16,
            houseHudBottom(textScale: textScale) + 10,
            16,
            goalsDockHeight(context) + 24,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: HouseGlintSweep(child: sign),
              ),
            ),
            if (wall.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final entry in wall)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: GoalsWallLabel(entry: entry, maxLines: 3),
                  ),
                ),
              if (showsTag)
                Align(
                  alignment: Alignment.centerRight,
                  child: GoalsWallMoreTag(
                    count: widget.moreGoals,
                    onTap: widget.onMoreGoals!,
                    hidden: widget.moreOpen,
                    reduceMotion: goalsStill(context, widget.reduceMotion),
                  ),
                ),
            ],
            SizedBox(height: showsTag ? 0 : 14),
            widget.card,
          ],
        ),
        // A card climbing under the HUD dissolves below its numbers instead of
        // crossing them: the Journal's dissolve, down past the HUD and up under
        // the status bar, coming up over the first points of scroll.
        Positioned(
          key: const Key('goals-hud-dissolve'),
          left: 0,
          right: 0,
          top: -above,
          height: above + houseHudBottom(textScale: textScale) + 14,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _scroll,
              builder: (context, _) => Opacity(
                opacity:
                    ((_scroll.hasClients ? _scroll.offset : 0) /
                            _hudDissolveScroll)
                        .clamp(0.0, 1.0),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF17100D), Color(0x0017100D)],
                      stops: [0.84, 1],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A label's tap target reaches this far above and below its glass.
const double _hitPad = 10.25;

/// The space between the lowest label's glass and the "+N" tag's.
const double _tagGap = 3;

// ── The sign ─────────────────────────────────────────────────────────────

/// The glass sign on the pillar: the Steward's workshop.
class GoalsRoomSign extends StatelessWidget {
  const GoalsRoomSign({super.key, required this.detail, required this.onTap});

  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget face(bool pressed, bool focused) => ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: pressed ? const Color(0xE6463425) : const Color(0xCC1E1611),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: focused ? Palette.textHi : const Color(0x42F6E2BF),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x660A0502),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'The Steward’s workshop',
                  textAlign: TextAlign.center,
                  style: _signTitleStyle(),
                ),
                const SizedBox(height: 5),
                Text(
                  _keepEnd(detail),
                  textAlign: TextAlign.center,
                  style: _signDetailStyle(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Pressable(
      key: const Key('goals-open-workshop'),
      material: MaterialSound.parchment,
      interactionSound: InteractionSound.navigate,
      pressDepth: 1,
      edgeColor: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      guardRapidReentry: true,
      semanticLabel: 'The Steward’s workshop. $detail',
      semanticHint:
          'Open the Steward’s workshop to start a goal or turn one into a first step.',
      onTapUp: (_) => onTap(),
      stateBuilder: (context, child, pressed, focused, hovered) =>
          ExcludeSemantics(child: face(pressed, focused)),
      child: ExcludeSemantics(child: face(false, false)),
    );
  }
}

// ── The wall ─────────────────────────────────────────────────────────────

/// One goal's glass label, pinned to a sheet on the wall. Its brass pin is at
/// its left end; the current goal's edge is lit, and the light moves from one
/// label to another over [goalsSwapDuration] when the current goal changes.
class GoalsWallLabel extends StatelessWidget {
  const GoalsWallLabel({super.key, required this.entry, this.maxLines = 1});

  final GoalsWallEntry entry;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final lit = entry.lit;
    Widget face(bool pressed, bool focused) => Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            // The lit edge fades in on the label that becomes current and
            // out on the one that stops being so: colour, not movement, so it
            // is the same under Reduce Motion.
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: lit ? 1 : 0),
              duration: goalsSwapDuration,
              curve: Curves.easeOut,
              builder: (context, glow, child) => DecoratedBox(
                decoration: BoxDecoration(
                  color: pressed
                      ? const Color(0xD1462F22)
                      : const Color(0xC21E1611),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: focused
                        ? Palette.textHi
                        : Color.lerp(
                            const Color(0x42F6E2BF),
                            const Color(0xE6EEC076),
                            glow,
                          )!,
                  ),
                  boxShadow: [
                    if (glow > 0)
                      BoxShadow(
                        color: const Color(
                          0x57E8B464,
                        ).withValues(alpha: 0x57 / 255 * glow),
                        blurRadius: 9,
                      ),
                    const BoxShadow(
                      color: Color(0x4D0A0502),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: child,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 5, 9, 5),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 14),
                  child: Text(
                    entry.title.toUpperCase(),
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: _wallLabelStyle(),
                  ),
                ),
              ),
            ),
          ),
        ),
        // The pin: a small brass head on the sheet, at the label's left end.
        Positioned(
          left: -2.6,
          top: 0,
          bottom: 0,
          child: Center(
            child: Container(
              width: 5.6,
              height: 5.6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.3, -0.3),
                  colors: [Color(0xFFF8E2AC), Color(0xFFA8793C)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x8C000000),
                    blurRadius: 1.2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    return Pressable(
      key: Key('goals-wall-${entry.id}'),
      material: MaterialSound.parchment,
      interactionSound: InteractionSound.navigate,
      // The page voices the tap itself (the parchment flick of choosing a
      // goal, or of opening one), so the label does not sound a second time.
      soundEnabled: false,
      pressDepth: 1,
      edgeColor: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      guardRapidReentry: true,
      semanticLabel: lit
          ? '${entry.title}, your current goal'
          : '${entry.title}, a goal',
      semanticHint: lit ? 'Open this goal.' : 'Make this your current goal.',
      onTapUp: (_) => entry.onTap(),
      stateBuilder: (context, child, pressed, focused, hovered) =>
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: _hitPad,
                horizontal: 6,
              ),
              child: face(pressed, focused),
            ),
          ),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: _hitPad, horizontal: 6),
          child: face(false, false),
        ),
      ),
    );
  }
}

/// The quiet "+N" that hangs below the lowest label when there are more goals
/// than sheets on the wall. It says that more exist and, pressed, unrolls MORE
/// at Other goals. Its glass is small and dimmer than a label's, so it never
/// reads as a fourth goal and leaves the painting under it be; its tap area
/// (44 pt) reaches down and left from the glass. It is drawn after the label
/// above it, so where the two areas meet the tag is the one pressed.
class GoalsWallMoreTag extends StatelessWidget {
  const GoalsWallMoreTag({
    super.key,
    required this.count,
    required this.onTap,
    this.hidden = false,
    this.reduceMotion = false,
  });

  final int count;
  final VoidCallback onTap;

  /// Faded out, out of reach and out of the screen reader's.
  final bool hidden;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    // The glass is small and sits at the top right of its 44 pt area; the
    // area reaches down and to the left of it.
    Widget face(bool pressed, bool focused) => ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      child: Align(
        alignment: Alignment.topRight,
        widthFactor: 1,
        heightFactor: 1,
        child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: pressed
                      ? const Color(0xB8462F22)
                      : const Color(0x991E1611),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: focused ? Palette.textHi : const Color(0x33F6E2BF),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  child: Text(
                    '+$count',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: _wallTagStyle(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final tag = Pressable(
      key: const Key('goals-wall-more'),
      material: MaterialSound.glass,
      interactionSound: InteractionSound.select,
      enabled: !hidden,
      pressDepth: 1,
      edgeColor: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      guardRapidReentry: true,
      semanticLabel: '$count more ${count == 1 ? 'goal' : 'goals'}',
      semanticHint: 'Show your other goals.',
      onTapUp: (_) => onTap(),
      stateBuilder: (context, child, pressed, focused, hovered) =>
          ExcludeSemantics(child: face(pressed, focused)),
      child: ExcludeSemantics(child: face(false, false)),
    );
    return IgnorePointer(
      ignoring: hidden,
      child: ExcludeSemantics(
        excluding: hidden,
        child: AnimatedOpacity(
          opacity: hidden ? 0 : 1,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 200),
          child: tag,
        ),
      ),
    );
  }
}

// ── The card ─────────────────────────────────────────────────────────────

/// The height of the card's top row (the caps line and MORE, whose tap area is
/// 44 pt).
const double _topRow = 44;

/// How far the current goal's name reaches up into that row: its 44 pt tap area
/// is its 27.5 pt line plus this much above and below. The caps line is short
/// and sits at the row's left, so the name's area can share the row's lower
/// edge; this is what keeps the card the height it was before the name opened
/// the goal.
const double _nameReach = 8.25;

/// The glass the card is made of, with its unrolling "more". [children] is
/// the card's own face (always shown); [more] is what unrolls. [nameReach]
/// lets the first child's tap area reach up under the top row (the current
/// goal's name does); the top row is drawn above it, so MORE keeps its corner.
class GoalsRoomGlass extends StatelessWidget {
  const GoalsRoomGlass({
    super.key,
    required this.eyebrow,
    required this.children,
    required this.more,
    required this.moreOpen,
    required this.onToggleMore,
    required this.reduceMotion,
    this.moreLabel = 'MORE',
    this.nameReach = 0,
  });

  /// The card's caps line ("CURRENT GOAL"); the unrolling "more" is on its
  /// row, at the right.
  final String eyebrow;
  final List<Widget> children;
  final List<Widget> more;
  final bool moreOpen;
  final VoidCallback onToggleMore;
  final bool reduceMotion;
  final String moreLabel;
  final double nameReach;

  @override
  Widget build(BuildContext context) {
    final still = goalsStill(context, reduceMotion);
    final large = goalsLargeText(context);
    final topRow = Row(
      children: [
        Expanded(child: GoalsRoomEyebrow(eyebrow)),
        _MoreHandle(open: moreOpen, label: moreLabel, onTap: onToggleMore),
      ],
    );
    // At large text the caps line may take two lines of its own row, so
    // nothing reaches up under it there.
    final reach = large ? 0.0 : nameReach;
    final rest = <Widget>[
      ...children,
      if (moreOpen)
        // The card takes its height at once; what unrolls comes up in light.
        TweenAnimationBuilder<double>(
          key: const Key('goals-room-unrolled'),
          tween: Tween(begin: still ? 1 : 0, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          builder: (context, t, child) => Opacity(opacity: t, child: child),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [const SizedBox(height: 4), ...more],
          ),
        ),
    ];
    final Widget body;
    if (reach > 0) {
      body = Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: _topRow - reach),
              ...rest,
            ],
          ),
          Positioned(top: 0, left: 0, right: 0, child: topRow),
        ],
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [topRow, ...rest],
      );
    }
    // In the scrolling layout the page scrolls and the card is its full
    // height; in the calibrated one the card keeps to its room and scrolls
    // inside when what it holds is longer. (Everything is built, so a "scroll
    // to" can find any row.)
    final inner = large
        ? body
        : SingleChildScrollView(
            key: const Key('goals-card-scroll'),
            padding: EdgeInsets.zero,
            child: body,
          );
    return ClassGlass(
      padding: const EdgeInsets.fromLTRB(20, 2, 14, 8),
      child: inner,
    );
  }
}

/// The card's quiet foot: one word that unrolls the rest of Goals.
class _MoreHandle extends StatelessWidget {
  const _MoreHandle({
    required this.open,
    required this.label,
    required this.onTap,
  });

  final bool open;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    key: const Key('goals-room-more'),
    material: MaterialSound.glass,
    pressDepth: 1,
    edgeColor: Colors.transparent,
    borderRadius: BorderRadius.circular(8),
    semanticLabel: open ? '$label. Open. Collapse.' : '$label. Collapsed.',
    semanticHint: open
        ? 'Roll the rest of Goals up.'
        : 'Show other goals, starting points and other ways in.',
    semanticToggled: open,
    onTapUp: (_) => onTap(),
    child: ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Padding(
          padding: const EdgeInsets.only(left: 10, right: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: _mono(11, color: _dim, spacing: 1.8)),
              const SizedBox(width: 6),
              Icon(
                open
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: _dim,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A small caps line of the card ("CURRENT GOAL").
class GoalsRoomEyebrow extends StatelessWidget {
  const GoalsRoomEyebrow(this.text, {super.key, this.maxLines = 2});

  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: _mono(11, color: _dim, spacing: 1.6, weight: FontWeight.w500),
  );
}

/// A glass button of the card: mono caps, a hairline edge; [lit] puts the
/// honey line under it (the card's one action).
class GoalsRoomButton extends StatelessWidget {
  const GoalsRoomButton({
    super.key,
    required this.label,
    required this.onTap,
    this.lit = false,
    this.semanticLabel,
    this.semanticHint,
  });

  final String label;
  final VoidCallback onTap;
  final bool lit;
  final String? semanticLabel;
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    Widget face(bool pressed, bool focused) => DecoratedBox(
      decoration: BoxDecoration(
        color: pressed ? const Color(0x80583E26) : const Color(0x4D0F0B09),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: focused ? Palette.textHi : const Color(0x38EFD8B3),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Stack(
          children: [
            if (lit)
              Positioned(
                left: 8,
                right: 8,
                bottom: 0,
                child: Container(
                  height: 1.4,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0x00ECAD58),
                        Color(0x99ECAD58),
                        Color(0x00ECAD58),
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Center(
                child: Text(
                  label.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  style: _mono(
                    11,
                    color: const Color(0xFFF1E4CD),
                    spacing: 0.3,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Pressable(
      material: MaterialSound.glass,
      pressDepth: 1,
      edgeColor: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      semanticLabel: semanticLabel ?? label,
      semanticHint: semanticHint,
      onTapUp: (_) => onTap(),
      stateBuilder: (context, child, pressed, focused, hovered) =>
          ExcludeSemantics(child: face(pressed, focused)),
      child: ExcludeSemantics(child: face(false, false)),
    );
  }
}

/// The two buttons of the card, side by side (one under the other at large
/// text, where a half-width button cannot hold its words).
class GoalsRoomButtonRow extends StatelessWidget {
  const GoalsRoomButtonRow({
    super.key,
    required this.first,
    required this.second,
  });

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    if (goalsLargeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [first, const SizedBox(height: 8), second],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: first),
          const SizedBox(width: 9),
          Expanded(child: second),
        ],
      ),
    );
  }
}

/// The current goal's card face: "CURRENT GOAL", its name (the way to open the
/// goal), the next thing and its two buttons. Everything else is in [more].
/// When another goal becomes the current one the face fades through to the new
/// goal's over [goalsSwapDuration] while the card eases to its height (the fade
/// alone under Reduce Motion).
class GoalsFocusCard extends StatelessWidget {
  const GoalsFocusCard({
    super.key,
    required this.goalId,
    required this.goalName,
    required this.onOpenGoal,
    required this.nextTitle,
    required this.primaryLabel,
    required this.onPrimary,
    required this.chooseTodayLabel,
    required this.onChooseToday,
    required this.more,
    required this.moreOpen,
    required this.onToggleMore,
    required this.reduceMotion,
    this.nextCaption = 'THE NEXT THING · CURRENT QUEST',
  });

  final String goalId;
  final String goalName;

  /// Opens the goal's own page (the name is its door).
  final VoidCallback onOpenGoal;
  final String nextTitle;
  final String nextCaption;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String chooseTodayLabel;
  final VoidCallback onChooseToday;
  final List<Widget> more;
  final bool moreOpen;
  final VoidCallback onToggleMore;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final still = goalsStill(context, reduceMotion);
    final large = goalsLargeText(context);
    final face = Column(
      key: ValueKey<String>('goals-card-face-$goalId'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _CardName(name: goalName, size: large ? 23 : 25, onTap: onOpenGoal),
        // The name's tap area has taken part of the gap below it.
        SizedBox(height: large ? 4 : 11 - _nameReach),
        _NextRow(caption: nextCaption, title: nextTitle, onTap: onPrimary),
        const SizedBox(height: 12),
        GoalsRoomButtonRow(
          first: GoalsRoomButton(
            key: const Key('goals-return-primary-action'),
            label: primaryLabel,
            lit: true,
            semanticLabel: '$primaryLabel. $nextTitle',
            onTap: onPrimary,
          ),
          second: GoalsRoomButton(
            key: const Key('goals-today-field-action'),
            label: chooseTodayLabel,
            semanticHint:
                'Choose up to three Quests to carry. Everything else stays optional.',
            onTap: onChooseToday,
          ),
        ),
      ],
    );
    // The old face leaves in the first half, the new one comes up in the
    // second, so two goals' words are never on top of each other. The old one
    // is out of the layout (the card eases to the new height), out of reach
    // and out of the screen reader's.
    final Widget switcher = AnimatedSwitcher(
      duration: goalsSwapDuration,
      switchInCurve: const Interval(0.35, 1, curve: Curves.easeOut),
      switchOutCurve: const Interval(0.55, 1),
      transitionBuilder: (child, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final leaving = animation.status == AnimationStatus.reverse;
          return IgnorePointer(
            ignoring: leaving,
            child: ExcludeSemantics(
              excluding: leaving,
              child: FadeTransition(opacity: animation, child: child),
            ),
          );
        },
        child: child,
      ),
      layoutBuilder: (current, previous) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          for (final leaving in previous)
            Positioned(top: 0, left: 0, right: 0, child: leaving),
          ?current,
        ],
      ),
      child: face,
    );
    return GoalsRoomGlass(
      key: const Key('goals-room-card'),
      eyebrow: 'CURRENT GOAL',
      reduceMotion: reduceMotion,
      moreOpen: moreOpen,
      onToggleMore: onToggleMore,
      more: more,
      nameReach: _nameReach,
      children: [
        still
            ? switcher
            : AnimatedSize(
                duration: goalsSwapDuration,
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: switcher,
              ),
      ],
    );
  }
}

/// The current goal's name, in the card's own serif, with a small quiet chevron
/// after it: pressing it opens the goal. Its tap area is at least 44 pt tall.
class _CardName extends StatelessWidget {
  const _CardName({
    required this.name,
    required this.size,
    required this.onTap,
  });

  final String name;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget face(bool pressed, bool focused) => ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _nameReach),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                name,
                key: const Key('goals-card-name'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: _serif(
                  size,
                  color: pressed ? const Color(0xFFD8C8AA) : _ink,
                  height: 1.1,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: pressed ? 5 : 3, bottom: 1.5),
              child: const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xA6B8A784),
              ),
            ),
          ],
        ),
      ),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: Pressable(
        key: const Key('goals-card-open-goal'),
        material: MaterialSound.parchment,
        // The page voices opening a goal itself.
        soundEnabled: false,
        pressDepth: 0.5,
        edgeColor: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        guardRapidReentry: true,
        semanticLabel: 'Open goal, $name',
        semanticHint: 'Open this goal’s route, progress and proof.',
        onTapUp: (_) => onTap(),
        stateBuilder: (context, child, pressed, focused, hovered) =>
            ExcludeSemantics(child: face(pressed, focused)),
        child: ExcludeSemantics(child: face(false, false)),
      ),
    );
  }
}

/// The next thing, as a row you can press: its caption and the Quest's name,
/// and the open ring at its end.
class _NextRow extends StatelessWidget {
  const _NextRow({
    required this.caption,
    required this.title,
    required this.onTap,
  });

  final String caption;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget face(bool pressed) => DecoratedBox(
      decoration: BoxDecoration(
        color: pressed ? const Color(0x26583E26) : Colors.transparent,
        border: const Border.symmetric(
          horizontal: BorderSide(color: Color(0x24E8C892)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GoalsRoomEyebrow(caption),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    key: const Key('goals-card-next'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: _serif(20, height: 1.12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _honey, width: 1.6),
              ),
            ),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
    return Pressable(
      material: MaterialSound.glass,
      pressDepth: 0.5,
      edgeColor: Colors.transparent,
      borderRadius: BorderRadius.zero,
      semanticLabel: '$title. $caption',
      onTapUp: (_) => onTap(),
      stateBuilder: (context, child, pressed, focused, hovered) =>
          ExcludeSemantics(child: face(pressed)),
      child: ExcludeSemantics(child: face(false)),
    );
  }
}

/// The card with no goal yet: the Steward's invitation.
class GoalsEmptyCard extends StatelessWidget {
  const GoalsEmptyCard({
    super.key,
    required this.afterArrivals,
    required this.onCreate,
    required this.onBrowse,
    required this.more,
    required this.moreOpen,
    required this.onToggleMore,
    required this.reduceMotion,
  });

  /// Some goals are already complete: the invitation says "a new direction".
  final bool afterArrivals;
  final VoidCallback onCreate;
  final VoidCallback onBrowse;
  final List<Widget> more;
  final bool moreOpen;
  final VoidCallback onToggleMore;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final large = goalsLargeText(context);
    return GoalsRoomGlass(
      key: const Key('goals-room-card'),
      eyebrow: afterArrivals ? 'A NEW DIRECTION' : 'MAKE ROOM FOR A DIRECTION',
      reduceMotion: reduceMotion,
      moreOpen: moreOpen,
      onToggleMore: onToggleMore,
      more: more,
      children: [
        Semantics(
          header: true,
          child: Text(
            afterArrivals
                ? 'What would you like to make different now?'
                : 'What would you like to make different?',
            style: _serif(large ? 22 : 25, height: 1.1),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A name is enough to begin. The Steward asks a few questions and '
          'leaves the first step small.',
          style: _mono(
            11,
            color: const Color(0xFFC9B99F),
            spacing: 0,
            weight: FontWeight.w400,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        GoalsRoomButtonRow(
          first: GoalsRoomButton(
            key: const Key('goals-create-first'),
            label: 'Create a goal',
            lit: true,
            semanticHint:
                'The Steward asks a few questions and drafts a first step.',
            onTap: onCreate,
          ),
          second: GoalsRoomButton(
            key: const Key('goals-browse-starting-points'),
            label: 'Browse starting points',
            semanticHint: 'Open ready-made goal ideas.',
            onTap: onBrowse,
          ),
        ),
      ],
    );
  }
}

// ── Rows for what unrolls ────────────────────────────────────────────────

/// A caps line that starts a group in the unrolled card.
class GoalsRoomGroup extends StatelessWidget {
  const GoalsRoomGroup(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
    child: Row(
      children: [
        Flexible(child: GoalsRoomEyebrow(label)),
        const SizedBox(width: 10),
        const Expanded(
          child: Divider(height: 1, thickness: 1, color: Color(0x24E8C892)),
        ),
      ],
    ),
  );
}

/// A door out of the unrolled card: a title and one line of what is behind it.
class GoalsRoomDoor extends StatelessWidget {
  const GoalsRoomDoor({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.semanticHint,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    Widget face(bool pressed, bool focused) => DecoratedBox(
      decoration: BoxDecoration(
        color: pressed ? const Color(0x33583E26) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: focused ? Border.all(color: Palette.textHi) : null,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: _honey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _serif(18, height: 1.1)),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: _mono(
                        11,
                        color: const Color(0xFFB8A784),
                        spacing: 0,
                        weight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: Color(0xFFB8A784),
              ),
            ],
          ),
        ),
      ),
    );
    return Pressable(
      material: MaterialSound.parchment,
      soundEnabled: false,
      pressDepth: 1,
      edgeColor: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      guardRapidReentry: true,
      semanticLabel: '$title. $detail',
      semanticHint: semanticHint,
      onTapUp: (_) => onTap(),
      stateBuilder: (context, child, pressed, focused, hovered) =>
          ExcludeSemantics(child: face(pressed, focused)),
      child: ExcludeSemantics(child: face(false, false)),
    );
  }
}
