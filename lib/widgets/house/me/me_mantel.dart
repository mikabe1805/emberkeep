// Me, the mantel: the house's room for who he is.
//
// The painted mantel is the room (the hearth is its light, the Woven Dawn
// hangs over it, three small earned objects sit on the shelf). Over it, live:
// the HUD at the top, two quiet tab pills (SETTINGS / SAVE on the right, YOUR
// SPACE / MORE on the left), the TROPHY CASE tag with its leader to the shelf,
// and the YOUR BUILD glass above the dock. Everything the old Me page held
// that is not on that first frame is one touch away, in a sheet of the same
// glass (see me.dart for what each opens).
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../academic_calendar/domain/academic_schedule.dart'
    show CivilDate;
import '../../../clock.dart';
import '../../../engine.dart';
import '../../../tokens.dart';
import '../../class_day/class_day_room.dart' show ClassDayHud, classStatusAbove;
import '../house_backdrop.dart';
import '../house_room.dart';
import 'mantel_glass.dart';
import 'mantel_model.dart';

class MeMantel extends StatelessWidget {
  const MeMantel({
    super.key,
    required this.state,
    required this.onStat,
    required this.onTrophy,
    required this.onSettings,
    required this.onSave,
    required this.onYourSpace,
    required this.onMore,
    this.parallax,
    this.reduceMotion,
  });

  final GameState state;

  /// A domain was touched (on the card or in the HUD): open its page.
  final ValueChanged<Stat> onStat;
  final VoidCallback onTrophy;
  final VoidCallback onSettings;
  final VoidCallback onSave;
  final VoidCallback onYourSpace;
  final VoidCallback onMore;

  /// The shell's tilt for the plate.
  final ValueListenable<Offset>? parallax;
  final bool? reduceMotion;

  @override
  Widget build(BuildContext context) {
    final big =
        MediaQuery.textScalerOf(context).scale(1) >= mantelStackedTabsFrom;
    return LayoutBuilder(
      builder: (context, box) {
        final above = classStatusAbove(context);
        final dock = 88 + MediaQuery.paddingOf(context).bottom;
        final frame = MantelFrame(page: box.biggest, above: above, dock: dock);
        final facts = MantelBuild.from(state);
        // The HUD grows a little with large text (it follows the phone's size up
        // to the cap), so the tabs sit a little lower with it.
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final tabsTop =
            frame.tabsMiddleY -
            MantelFrame.hit / 2 +
            (scale.clamp(1.0, mantelTabTextCap) - 1) * 26;
        final tagTop = frame.tagMiddleY - MantelFrame.hit / 2;
        final (leaderStart, leaderTurn, leaderEnd) = frame.leader;
        return HouseRoomBackdrop(
          room: HouseRoom.me,
          parallax: parallax,
          reduceMotion: reduceMotion,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: const Key('mantel-leader'),
                    painter: MantelLeaderPainter(
                      start: leaderStart,
                      corner: leaderTurn,
                      end: leaderEnd,
                    ),
                  ),
                ),
              ),
              // The level line and the six domains, over the room's top edge,
              // the same HUD the Doorway wears.
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 20,
                right: 20,
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: mantelTabTextCap,
                  child: ClassDayHud(
                    state: state,
                    date: CivilDate.fromDateTime(Clock.now()),
                    onExploreStat: onStat,
                  ),
                ),
              ),
              Positioned(
                top: tabsTop,
                right: 0,
                child: MantelTabs(
                  fromRight: true,
                  items: [
                    MantelTabItem(
                      label: 'SETTINGS',
                      keyName: 'settings',
                      spoken: 'Settings',
                      onTap: onSettings,
                    ),
                    MantelTabItem(
                      label: 'SAVE',
                      keyName: 'save',
                      spoken: 'Save and backup',
                      onTap: onSave,
                    ),
                  ],
                ),
              ),
              Positioned(
                // Large text stacks the two pills so neither meets the other.
                top: big ? tabsTop + MantelFrame.hit + 6 : tabsTop,
                left: 0,
                child: MantelTabs(
                  fromRight: false,
                  items: [
                    MantelTabItem(
                      label: 'YOUR SPACE',
                      keyName: 'space',
                      spoken: 'Your space, your own room and sharing',
                      onTap: onYourSpace,
                    ),
                    MantelTabItem(
                      label: 'MORE',
                      keyName: 'more',
                      spoken:
                          'More: milestones, circle, share, gains, '
                          'wardrobe and account',
                      onTap: onMore,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: tagTop,
                right: MantelFrame.tagRight * frame.plate,
                child: MantelTag(label: 'TROPHY CASE', onTap: onTrophy),
              ),
              Positioned(
                left: MantelFrame.glassInset,
                right: MantelFrame.glassInset,
                bottom: dock + MantelFrame.glassGap,
                child: MantelBuildCard(
                  facts: facts,
                  onStat: onStat,
                  maxHeight: frame.glassMaxHeight(
                    tagBottom: tagTop + MantelFrame.hit,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
