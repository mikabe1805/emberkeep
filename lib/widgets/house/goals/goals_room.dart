// The Goals tab as the Steward's workshop: a room, not a page.
//
// The painted plate (assets/rooms/house/plate-goals-midday.webp) is the whole
// screen. Three live things stand in it, all glass over the painting:
//
//   the sign        a glass sign on the pillar: the Steward's workshop. It is
//                   the way in (a new goal, or turning one into a first step)
//                   and the one thing the lamp's glint crosses on arrival.
//   the wall        the player's goals as small glass labels pinned on the
//                   sheets on the wall. The lit one is the current goal.
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

/// The Goals room: the plate with the sign, the wall and the card over it.
class HouseGoalsRoom extends StatelessWidget {
  const HouseGoalsRoom({
    super.key,
    required this.signDetail,
    required this.onSign,
    required this.wall,
    required this.card,
    this.parallax,
    this.reduceMotion = false,
  });

  /// The sign's second line.
  final String signDetail;
  final VoidCallback onSign;
  final List<GoalsWallEntry> wall;

  /// The glass card (built by [GoalsFocusCard] or [GoalsEmptyCard]).
  final Widget card;
  final ValueListenable<Offset>? parallax;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final still = goalsStill(context, reduceMotion);
    final large = goalsLargeText(context);
    final sign = GoalsRoomSign(detail: signDetail, onTap: onSign);
    return HouseRoomBackdrop(
      room: HouseRoom.goals,
      parallax: parallax,
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
    final above = classStatusAbove(context);
    final k = box.maxWidth / houseCanvasWidth;
    double y(double canvas) => canvas * k - above;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: goalsSignLeft * k,
          top: y(goalsSignTop),
          width: goalsSignWidth,
          child: HouseGlintSweep(child: sign),
        ),
        for (var i = 0; i < wall.length && i < goalsWallSlots.length; i++)
          Positioned(
            top: y(goalsWallSlots[i].top) - _hitPad,
            right: goalsWallSlots[i].right * k,
            width: box.maxWidth * 0.72,
            child: Align(
              alignment: Alignment.centerRight,
              child: GoalsWallLabel(entry: wall[i], maxLines: 1),
            ),
          ),
        Positioned(
          left: 24,
          right: 24,
          bottom: goalsDockHeight(context) + goalsCardGap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (box.maxHeight - goalsDockHeight(context)) * 0.52,
            ),
            child: card,
          ),
        ),
      ],
    );
  }

  Widget _scrolling(BuildContext context, BoxConstraints box, Widget sign) {
    return ListView(
      key: const Key('goals-threshold-scroll'),
      // The page starts under the shell's HUD, never behind it.
      padding: EdgeInsets.fromLTRB(
        16,
        houseHudBottom(textScale: MediaQuery.textScalerOf(context).scale(1)) +
            10,
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
        ],
        const SizedBox(height: 14),
        card,
      ],
    );
  }
}

/// A label's tap target reaches this far above and below its glass.
const double _hitPad = 10;

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
                  style: _serif(15.5),
                ),
                const SizedBox(height: 5),
                Text(
                  _keepEnd(detail),
                  textAlign: TextAlign.center,
                  style: _mono(
                    10.5,
                    color: const Color(0xFFC9B99F),
                    spacing: 0,
                    weight: FontWeight.w400,
                    height: 1.35,
                  ),
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
/// its left end; the current goal's edge is lit.
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: pressed
                    ? const Color(0xD1462F22)
                    : const Color(0xC21E1611),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: focused
                      ? Palette.textHi
                      : lit
                      ? const Color(0xE6EEC076)
                      : const Color(0x42F6E2BF),
                ),
                boxShadow: [
                  if (lit)
                    const BoxShadow(color: Color(0x57E8B464), blurRadius: 9),
                  const BoxShadow(
                    color: Color(0x4D0A0502),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
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
                    style: _mono(11, color: const Color(0xFFF1E4CD)),
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
      pressDepth: 1,
      edgeColor: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      guardRapidReentry: true,
      semanticLabel: lit
          ? '${entry.title}, your current goal'
          : '${entry.title}, a goal',
      semanticHint: 'Open this goal.',
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

// ── The card ─────────────────────────────────────────────────────────────

/// The glass the card is made of, with its unrolling "more". [children] is
/// the card's own face (always shown); [more] is what unrolls.
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

  @override
  Widget build(BuildContext context) {
    final still = goalsStill(context, reduceMotion);
    final large = goalsLargeText(context);
    final body = <Widget>[
      Row(
        children: [
          Expanded(child: GoalsRoomEyebrow(eyebrow)),
          _MoreHandle(open: moreOpen, label: moreLabel, onTap: onToggleMore),
        ],
      ),
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
    // In the scrolling layout the page scrolls and the card is its full
    // height; in the calibrated one the card keeps to its room and scrolls
    // inside when what it holds is longer.
    final inner = large
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: body,
          )
        : ListView(
            key: const Key('goals-card-scroll'),
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: body,
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

/// The current goal's card face: "CURRENT GOAL", its name, the next thing and
/// its two buttons. Everything else is in [more].
class GoalsFocusCard extends StatelessWidget {
  const GoalsFocusCard({
    super.key,
    required this.goalId,
    required this.goalName,
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
        Semantics(
          header: true,
          child: Text(
            goalName,
            key: const Key('goals-card-name'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: _serif(large ? 23 : 25, height: 1.1),
          ),
        ),
        const SizedBox(height: 11),
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
    return GoalsRoomGlass(
      key: const Key('goals-room-card'),
      eyebrow: 'CURRENT GOAL',
      reduceMotion: reduceMotion,
      moreOpen: moreOpen,
      onToggleMore: onToggleMore,
      more: more,
      children: [
        AnimatedSwitcher(
          duration: still ? Duration.zero : const Duration(milliseconds: 170),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          child: face,
        ),
      ],
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
