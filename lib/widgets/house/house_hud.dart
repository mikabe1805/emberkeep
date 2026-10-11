// The house's one HUD.
//
// The level, the XP rail, the date and the six stats sit over the top of every
// room, the same in each (the prototype's v4 frames): the shell draws it once
// over the travel stack, so a room never owns a copy. A stat opens its domain
// page. The rooms leave it alone: they read only how much height it takes
// ([houseHudBottom]) and, for the XP that flies to it, its key
// ([HouseHudScope]).
//
//   * It follows the light. It is steady at rest and breathes through a
//     dock hand-off with the rooms' own UI (the travel stack publishes how
//     much UI is on stage), so it never snaps while a room's light arrives.
//   * It steps back (to 60%) behind the class-day evening's music, as the
//     Doorway's own HUD did, and stays pressable.
//   * Its soft dark is the prototype's: a warm scrim from the top of the
//     screen so the numerals read over any plate.
//   * Every stat is a button at least 44 pt tall and a sixth of the width.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../clock.dart';
import '../../engine.dart';
import '../../tokens.dart' show Stat;
import '../../academic_calendar/domain/academic_schedule.dart' show CivilDate;
import '../class_day/class_day_room.dart' show ClassDayHud, classStatusAbove;
import 'house_travel_scope.dart';

/// The HUD follows text size up to this, like the rooms' small quiet labels;
/// every room's content scrolls or stacks at larger sizes.
const double houseHudTextCap = 1.3;

/// Gap above the HUD's first line, under the page's top edge.
const double houseHudTop = 8;

/// How far down the page the HUD reaches (from the page's top edge) at
/// [textScale]: its top gap, the level line and the 44 pt stat row. Rooms keep
/// their own content clear of this.
double houseHudBottom({double textScale = 1}) {
  final s = math.min(math.max(textScale, 1.0), houseHudTextCap);
  return houseHudTop + 22 * s + 44;
}

/// Hands the shell's HUD key to the rooms (the XP that flies to the HUD).
class HouseHudScope extends InheritedWidget {
  const HouseHudScope({super.key, required this.hudKey, required super.child});

  /// The key on the HUD's content, in the shell.
  final GlobalKey hudKey;

  /// The shell's HUD scope, or null outside the shell (a room on its own).
  static HouseHudScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<HouseHudScope>();

  @override
  bool updateShouldNotify(HouseHudScope oldWidget) =>
      oldWidget.hudKey != hudKey;
}

/// The HUD, over the travel stack (its `overlay`).
class HouseHud extends StatelessWidget {
  const HouseHud({
    super.key,
    required this.state,
    required this.onExploreStat,
    this.stepBack = false,
    this.hudKey,
  });

  final GameState state;

  /// A stat was touched: open its domain page.
  final ValueChanged<Stat> onExploreStat;

  /// The class-day evening's music is on and the room has stepped back.
  final bool stepBack;

  /// Marks the HUD's content for the XP flight.
  final GlobalKey? hudKey;

  @override
  Widget build(BuildContext context) {
    final above = classStatusAbove(context);
    final still = MediaQuery.disableAnimationsOf(context) || state.reduceMotion;
    final signals = HouseTravelScope.maybeOf(context);
    final scale = math
        .min(MediaQuery.textScalerOf(context).scale(1), houseHudTextCap)
        .toDouble();
    final hud = MediaQuery.withClampedTextScaling(
      maxScaleFactor: houseHudTextCap,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => KeyedSubtree(
          key: hudKey,
          child: ClassDayHud(
            state: state,
            date: CivilDate.fromDateTime(Clock.now()),
            onExploreStat: onExploreStat,
          ),
        ),
      ),
    );
    final Widget body = Stack(
      key: const Key('house-hud'),
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        // The prototype's soft dark, from the top of the screen (under the
        // status bar) down past the stat row.
        Positioned(
          left: 0,
          right: 0,
          top: -above,
          height: above + houseHudBottom(textScale: scale) + 26,
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x99140B05),
                    Color(0x57140B05),
                    Color(0x00140B05),
                  ],
                  stops: [0, 0.58, 1],
                ),
              ),
            ),
          ),
        ),
        Positioned(top: houseHudTop, left: 20, right: 20, child: hud),
      ],
    );
    // The stack fills the page; only the HUD's own lines take touches.
    final stepped = AnimatedOpacity(
      opacity: stepBack ? 0.6 : 1,
      duration: Duration(milliseconds: still ? 360 : 1800),
      curve: Curves.easeInOutSine,
      child: body,
    );
    if (signals == null) return stepped;
    return ValueListenableBuilder<double>(
      valueListenable: signals.hud,
      child: stepped,
      builder: (context, level, child) =>
          Opacity(opacity: 0.6 + 0.4 * level, child: child),
    );
  }
}
