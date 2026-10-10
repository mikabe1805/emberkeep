// The house: five rooms of one painted place, in dock order.
//
// Every tab is a room of the same house. Each room has one light, painted in
// its own plate, and it always arrives the same way (see house_arrival.dart):
// the hearth for Me, the door glass for Quests, the brass work lamp for Goals,
// the window for Plans and the reading lamp for the Journal. The map below is
// the single place the rooms are described: their plates for each light of
// the day, where their light comes from (in the 393 x 852 pt canvas the plates
// were painted for), how their light arrives and for how long.
//
// A room that has no plate for a light keeps its painted light. Nothing is
// ever tinted to fake an evening over a daylight plate. When an evening plate
// for Goals or the Journal lands, it is one line in [HouseRoom] (the comment
// on each room says which).
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

/// The size of the canvas every plate was painted for, in points: a phone
/// screen, status bar to dock plane. Plates are 3x this (1179 x 2556).
const double houseCanvasWidth = 393;
const double houseCanvasHeight = 852;

/// How many screen points one canvas point is worth for laying out a room's
/// own content: a phone's width and height, whichever is tighter, so that a
/// wide or short screen never pushes the live glass off the page.
double houseContentScale(Size screen) => math.min(
  screen.width / houseCanvasWidth,
  screen.height / houseCanvasHeight,
);

/// How a room's light arrives.
enum HouseArrival {
  /// Embers first, then the room rises in firelight from the bottom up and
  /// the tapestry above the mantel catches the light last (Me).
  hearth,

  /// Day-glow blooms from the door's panes and the hall resolves out of the
  /// brightness, outward and downward (Quests).
  doorGlass,

  /// The lamp clicks on and a cone opens downward and outward from it (Goals).
  lampCone,

  /// A soft vertical band of daylight sweeps across from the window side,
  /// like curtains drawn on the day (Plans).
  daylightBand,

  /// The calmest: the nook warms up from a low glow, a slow radial rise
  /// around the reading lamp (Journal).
  readingLamp,
}

/// The painted lights of one room, as asset paths. The midday plate is the
/// room's own; the others exist only where they have been painted.
///
/// Which plate shows for which hour is [housePlateLayers] (house_light.dart):
/// a light with no plate of its own gives its share to the nearest painted
/// light, never to a tint.
final class HousePlates {
  const HousePlates({required this.midday, this.golden, this.evening});

  /// The daylight plate.
  final String midday;

  /// The golden-hour plate, when one is painted.
  final String? golden;

  /// The evening plate, when one is painted.
  final String? evening;

  /// Every painted plate of the room, in the order midday, golden, evening.
  List<String> get all => [midday, ?golden, ?evening];

  /// Whether the room has a painted evening of its own.
  bool get hasEvening => evening != null;

  @override
  bool operator ==(Object other) =>
      other is HousePlates &&
      other.midday == midday &&
      other.golden == golden &&
      other.evening == evening;

  @override
  int get hashCode => Object.hash(midday, golden, evening);
}

const _dir = 'assets/rooms/house/';

/// The plate sets of the house. A room's own set is [HouseRoom.plates]; Plans
/// also has its month spread.
abstract final class HousePlateSets {
  /// Me, the mantel.
  static const me = HousePlates(
    midday: '${_dir}plate-me-midday.webp',
    evening: '${_dir}plate-me-evening.webp',
  );

  /// Goals, the Steward's workshop. Midday only for now: when the evening
  /// plate is painted, add `evening: '${_dir}plate-goals-evening.webp'` here
  /// and nothing else changes.
  static const goals = HousePlates(midday: '${_dir}plate-goals-midday.webp');

  /// Plans, the day spread.
  static const plansDay = HousePlates(
    midday: '${_dir}plate-plans-day-midday.webp',
    evening: '${_dir}plate-plans-day-evening.webp',
  );

  /// Plans, the month spread. Its evening is the day spread's lamplit paper
  /// (pixel-registered with it; the month's grid lines are drawn live over
  /// it), not a tint over the midday month.
  static const plansMonth = HousePlates(
    midday: '${_dir}plate-plans-month-midday.webp',
    evening: '${_dir}plate-plans-day-evening.webp',
  );

  /// Journal, the reading nook. Midday only for now: when the evening plate
  /// is painted, add `evening: '${_dir}plate-journal-evening.webp'` here and
  /// nothing else changes.
  static const journal = HousePlates(
    midday: '${_dir}plate-journal-midday.webp',
  );
}

/// The five rooms, in dock order (the order of the tabs, and of
/// [HouseRoom.index]).
enum HouseRoom {
  /// The mantel. The hearth is the light; the tapestry catches it last.
  me(
    label: 'Me',
    plates: HousePlateSets.me,
    anchor: Offset(590 / 3, 1450 / 3),
    arrival: HouseArrival.hearth,
    arrivalMs: 860,
    contentTop: 540,
  ),

  /// The Doorway (the hall). The door glass is the light by day, the lantern
  /// at evening. Its plates are the Doorway's own (DoorwayStage), so it has
  /// no plate set here.
  quests(
    label: 'Quests',
    plates: null,
    anchor: Offset(589 / 3, 520 / 3),
    eveningAnchor: Offset(1112 / 3, 326 / 3),
    arrival: HouseArrival.doorGlass,
    arrivalMs: 700,
    contentTop: 456,
  ),

  /// The Steward's workshop. The brass work lamp's bulb is the light.
  goals(
    label: 'Goals',
    plates: HousePlateSets.goals,
    anchor: Offset(885 / 3, 897 / 3),
    arrival: HouseArrival.lampCone,
    arrivalMs: 740,
    contentTop: 530,
  ),

  /// The day table. The window beside it is the light.
  plans(
    label: 'Plans',
    plates: HousePlateSets.plansDay,
    anchor: Offset(42 / 3, 500 / 3),
    arrival: HouseArrival.daylightBand,
    arrivalMs: 820,
    contentTop: 190,
  ),

  /// The reading nook. The reading lamp is the light; the calmest arrival.
  journal(
    label: 'Journal',
    plates: HousePlateSets.journal,
    anchor: Offset(742 / 3, 1117 / 3),
    arrival: HouseArrival.readingLamp,
    arrivalMs: 900,
    contentTop: 480,
  );

  const HouseRoom({
    required this.label,
    required this.plates,
    required this.anchor,
    required this.arrival,
    required this.arrivalMs,
    required this.contentTop,
    this.eveningAnchor,
  });

  /// The dock's word for the room.
  final String label;

  /// The room's painted lights, or null where the room's stage paints its own
  /// (the Doorway).
  final HousePlates? plates;

  /// Where the room's light comes from, in the 393 x 852 pt canvas (the
  /// plate's pixel point divided by three).
  final Offset anchor;

  /// Where the light comes from at evening, when it is another source (the
  /// Doorway's lantern).
  final Offset? eveningAnchor;

  /// How the room's light arrives.
  final HouseArrival arrival;

  /// How long the arrival takes, in milliseconds.
  final int arrivalMs;

  /// Where the room's live glass starts, in canvas points from the top: the
  /// painted room above it stays clear. A hint for the rooms' own layouts.
  final double contentTop;

  /// The tab index in the dock (the same as [index]).
  int get dockIndex => index;

  /// How long the arrival takes.
  Duration get arrivalDuration => Duration(milliseconds: arrivalMs);

  /// The light's anchor for the light of the day.
  Offset anchorFor({required bool evening}) =>
      evening ? (eveningAnchor ?? anchor) : anchor;

  /// The room for dock tab [i].
  static HouseRoom fromDockIndex(int i) => HouseRoom.values[i];
}

/// How long a Reduce Motion arrival takes: a plain cross-fade.
const houseReducedArrival = Duration(milliseconds: 200);

/// How long the departing room's light dips, and how far (a share of black).
const houseDipDuration = Duration(milliseconds: 220);
const houseDipDepth = 0.25;

/// How far the arriving room drifts in from the side of the tapped tab (pt),
/// and how much larger it starts than it ends (a dolly in).
const houseDriftPoints = 14.0;
const houseDollyFrom = 1.03;
