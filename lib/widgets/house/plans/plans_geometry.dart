// Where the daybook's pages are, and which painted plate each view stands on.
//
// Plans is a near top-down open daybook: one painted spread (see the plates in
// assets/rooms/house/) and live glass laid onto its pages. The rectangles are
// measured from the plates (pixels of the 1179 x 2556 art, divided by three
// into the 393 x 852 pt canvas the house was painted for) and scale with the
// screen's width, because a plate is drawn to the screen's width and hangs from
// the top: the paper is where it is, so the glass goes where the paper is.
//
// Pure: no widgets here, so the registration can be tested without a screen.
library;

import 'dart:ui' show Rect, Size;

import '../../../academic_calendar/data/academic_calendar_preferences.dart'
    show AcademicCalendarMode;
import '../house_room.dart';

/// The daybook's rectangles in the 393 x 852 pt canvas.
abstract final class PlansCanvas {
  /// The MONTH / WEEK / DAY switch hangs from the top of the book, at the
  /// right: its top edge and its distance from the right edge.
  static const double modeSwitchTop = 123;
  static const double modeSwitchRight = 17.7;

  /// The left page's seven day rows, MON to SUN.
  static const Rect tabs = Rect.fromLTWH(8.7, 220.7, 116.3, 342);

  /// The left page under the rows: the arrows that turn the page, the term,
  /// and the way back to today.
  static const Rect leftFoot = Rect.fromLTWH(8.7, 566, 116.3, 124);

  /// The right page's live field: heading, ADD, the day's cards. It runs down
  /// to the page's lower margin; what does not fit scrolls inside it.
  static const Rect field = Rect.fromLTWH(143.3, 215.3, 232.7, 468);

  /// Where the page-curl shadow sweeps: the whole right page.
  static const Rect curl = Rect.fromLTWH(132, 187, 250, 490);

  /// The week strip across both pages of the spread (until the week plate
  /// lands this stands on the day plate).
  static const Rect weekStrip = Rect.fromLTWH(14, 216, 365, 350);

  /// The month plate's faint printed grid, measured from the plate itself:
  /// the x of its eight vertical lines and the y of its seven horizontal ones.
  /// Row 0 is the weekday row; rows 1 to 5 are the date rows.
  static const List<double> monthColumns = [
    150.7,
    180.3,
    209.6,
    239.0,
    268.5,
    297.8,
    327.4,
    357.5,
  ];
  static const List<double> monthRows = [
    257.8,
    305.8,
    355.3,
    404.4,
    454.0,
    503.4,
    555.0,
  ];

  /// The right page with its heading: month grid starts under the title.
  static const Rect monthHeading = Rect.fromLTWH(143.3, 215.3, 232.7, 40);
}

/// A canvas laid onto a screen: everything scales with the width.
final class PlansLayout {
  const PlansLayout(this.scale);

  /// The layout for a screen [width] wide.
  factory PlansLayout.forWidth(double width) => PlansLayout(width / 393);

  final double scale;

  Rect rect(Rect canvas) => Rect.fromLTWH(
    canvas.left * scale,
    canvas.top * scale,
    canvas.width * scale,
    canvas.height * scale,
  );

  double x(double canvas) => canvas * scale;

  Size size(Rect canvas) => Size(canvas.width * scale, canvas.height * scale);
}

/// The plate each view stands on.
abstract final class PlansPlates {
  /// The day spread: blank paper, ready for the seven rows and the cards.
  static const HousePlates day = HousePlateSets.plansDay;

  /// The month spread: the day spread with a faint printed month grid.
  static const HousePlates month = HousePlateSets.plansMonth;

  /// The week spread. The week plate is being painted; until it lands the
  /// week stands on the day plate with a glass week strip. When the plate is
  /// painted, drop it in assets/rooms/house/ and change this one line to
  ///
  ///   static const HousePlates week = HousePlates(
  ///     midday: 'assets/rooms/house/plate-plans-week-midday.webp',
  ///     evening: 'assets/rooms/house/plate-plans-week-evening.webp',
  ///   );
  ///
  /// (the evening is optional: a plate with no evening of its own keeps its
  /// painted light). The week strip's rectangle is [PlansCanvas.weekStrip];
  /// retune it if the new plate puts the paper elsewhere.
  static const HousePlates week = day;

  /// Whether the week has a plate of its own yet.
  static bool get weekHasOwnPlate => week != day;

  /// The plates for a view. Three days is the day spread.
  static HousePlates forMode(AcademicCalendarMode mode) => switch (mode) {
    AcademicCalendarMode.month => month,
    AcademicCalendarMode.week => week,
    AcademicCalendarMode.threeDay || AcademicCalendarMode.day => day,
  };
}

/// The order the views turn in: toward the month is forward, toward the day
/// is back. A change of view turns the page that way.
double plansViewOrder(AcademicCalendarMode mode) => switch (mode) {
  AcademicCalendarMode.day => 0,
  AcademicCalendarMode.threeDay => 1,
  AcademicCalendarMode.week => 2,
  AcademicCalendarMode.month => 3,
};
