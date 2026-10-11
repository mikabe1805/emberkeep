// The mantel's facts and its geometry, as pure data.
//
// Me is the house's mantel room: the painted plate, and over it the YOUR BUILD
// glass, the quiet tabs and the trophy tag. Nothing here paints. [MantelBuild]
// reads the card's words and numbers out of the engine (so a test can pin them
// to the save), and [MantelFrame] says where things go on the screen: the tabs
// and the trophy tag are registered to the painted plate (the tag's leader
// ends on the medallion on the mantel), the glass is anchored above the dock.
library;

import 'dart:ui' show Offset, Rect, Size;

import '../../../engine.dart';
import '../../../tokens.dart';
import '../house_backdrop.dart' show housePlateOverscan;
import '../house_room.dart';

/// One of the six domains on the card.
class MantelStat {
  const MantelStat({required this.stat, required this.value});

  final Stat stat;
  final int value;

  /// "BODY".
  String get label => stat.abbr;

  /// "Body 88", what VoiceOver says on the cell.
  String get spoken => '${stat.label} $value';
}

/// What the YOUR BUILD card says, read from the engine.
class MantelBuild {
  const MantelBuild({
    required this.title,
    required this.level,
    required this.stats,
    required this.questsDone,
    required this.streakDays,
    required this.xp,
    required this.xpNeeded,
  });

  /// The build's own name in a word or two ("Steady Hand"), the way the
  /// engine names it, set in title case.
  final String title;
  final int level;

  /// The six domains in the engine's order: BODY, CARE, MIND, CRAFT, PEOPLE,
  /// HOME.
  final List<MantelStat> stats;
  final int questsDone;
  final int streakDays;

  /// XP into this level, and what the next level asks for.
  final int xp;
  final int xpNeeded;

  factory MantelBuild.from(GameState state) {
    final need = state.xpNeeded(state.level + 1);
    return MantelBuild(
      title: titleCase(state.buildTitle),
      level: state.level,
      stats: [
        for (final s in Stat.values)
          MantelStat(stat: s, value: state.stats[s] ?? 0),
      ],
      questsDone: state.totalCompletions,
      streakDays: state.streakDays,
      xp: state.xp < need ? state.xp : need,
      xpNeeded: need,
    );
  }

  /// "24 QUESTS DONE · 6 DAY STREAK".
  String get doneLine =>
      '$questsDone QUEST${questsDone == 1 ? '' : 'S'} DONE · '
      '$streakDays DAY STREAK';

  /// "369 / 870 XP".
  String get xpLine => '$xp / $xpNeeded XP';

  /// The card read aloud: the title, the level, the progress.
  String get spoken =>
      'Your build, $title. Level $level. $questsDone '
      'quest${questsDone == 1 ? '' : 's'} done, $streakDays day streak. '
      '$xp of $xpNeeded XP.';

  /// "LIONHEART" becomes "Lionheart"; "MIGHTY STEADY HAND" becomes "Mighty
  /// Steady Hand".
  static String titleCase(String s) => s
      .split(' ')
      .map(
        (w) => w.isEmpty
            ? w
            : '${w.substring(0, 1).toUpperCase()}${w.substring(1).toLowerCase()}',
      )
      .join(' ');
}

/// Text larger than this puts the two quiet tab pills on separate rows, so
/// neither runs into the other.
const double mantelStackedTabsFrom = 1.12;

/// Quiet glass labels (the tabs, the trophy tag) follow the phone's text size
/// up to this much; past it the sheets and the card, which scroll, carry the
/// full size. Everything a tab opens is also in a sheet that scales fully.
const double mantelTabTextCap = 1.3;

/// Where the mantel's pieces go on a screen.
///
/// The painted plate is 393 x 852 points wide-fit to the screen from the top
/// (under the status bar), then enlarged by [housePlateOverscan] about the
/// middle of its box. [plateToPage] follows that exactly, so a mark registered
/// to the painting lands on it at any size.
class MantelFrame {
  const MantelFrame({
    required this.page,
    required this.above,
    required this.dock,
  });

  /// The page: the shell's area, below the status bar and above nothing (the
  /// dock sits over its foot).
  final Size page;

  /// How far the screen reaches above the page (the status bar).
  final double above;

  /// The dock's height over the page's foot.
  final double dock;

  /// Screen points per plate point (the plate fits the screen's width).
  double get plate => page.width / houseCanvasWidth;

  /// Where a point of the 393 x 852 plate falls on the page.
  Offset plateToPage(Offset canvas) {
    final box = page.height + above;
    final cx = page.width / 2;
    final cy = box / 2 - above;
    final x = canvas.dx * plate;
    final y = canvas.dy * plate - above;
    return Offset(
      (x - cx) * housePlateOverscan + cx,
      (y - cy) * housePlateOverscan + cy,
    );
  }

  // ── The plate's own marks (plate points) ─────────────────────────────

  /// The tabs sit just under the HUD, on the timber: y of their middle.
  static const tabsMiddle = 150.0;

  /// The trophy tag's middle, and its right edge from the plate's right.
  static const tagMiddle = 266.0;
  static const tagRight = 19.0;

  /// The bronze medallion the leader ends on (plate points).
  static const medallion = Offset(236, 324);

  /// Where the leader's corner turns (plate points): from the tag's left
  /// edge along y = [tagMiddle] to x = [medallion].dx, then down.
  static const leaderFromX = 289.0;

  /// The quiet tabs' height, and the finger-sized area around them.
  static const tabHeight = 34.0;
  static const hit = 44.0;

  /// The glass sits this far above the dock.
  static const glassGap = 8.0;

  /// The side margin of the glass.
  static const glassInset = 20.0;

  /// The middle of the tabs row on the page.
  double get tabsMiddleY => plateToPage(const Offset(0, tabsMiddle)).dy;

  /// The tag's middle on the page.
  double get tagMiddleY => plateToPage(const Offset(0, tagMiddle)).dy;

  /// The leader's three points on the page: its start (under the tag), the
  /// corner, and the medallion where it ends.
  (Offset, Offset, Offset) get leader => (
    plateToPage(const Offset(leaderFromX, tagMiddle)),
    plateToPage(const Offset(236, tagMiddle)),
    plateToPage(medallion),
  );

  /// The room above the glass the tag must keep: the glass never climbs over
  /// the tag, so a tall card (large text) scrolls inside itself.
  double glassMaxHeight({required double tagBottom}) {
    final bottom = page.height - dock - glassGap;
    return (bottom - (tagBottom + 12)).clamp(160.0, bottom);
  }

  /// The glass's rect for a given height, anchored above the dock.
  Rect glassRect(double height) {
    final bottom = page.height - dock - glassGap;
    return Rect.fromLTWH(
      glassInset,
      bottom - height,
      page.width - glassInset * 2,
      height,
    );
  }
}
