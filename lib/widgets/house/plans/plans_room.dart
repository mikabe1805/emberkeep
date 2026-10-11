// The Plans room: the daybook on the day table.
//
// A near top-down open book on a walnut table, the window's light across it.
// Code owns every date, word, card and control; the plates own paper, leather
// and light. The left page holds the week's days (or the month's numbers), the
// right page the chosen day; swiping anywhere on the book turns the page.
// MONTH, WEEK and DAY are three spreads of the same book: the month plate with
// its printed grid, the week (a glass strip across both pages), the day.
//
// Everything is registered to the plate: it is drawn to the screen's width and
// hangs from the top, so a point of the 393 x 852 canvas is `scale` screen
// points down and across, and the live layer moves with the plate's tilt so
// glass never slides off the paper.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';

import '../../../academic_calendar/data/academic_calendar_preferences.dart'
    show AcademicCalendarMode;
import '../../../academic_calendar/domain/academic_schedule.dart';
import '../../../audio.dart';
import '../../../daybook/presentation/daybook_range_projection.dart';
import '../../../models.dart' show Note;
import '../../class_day/class_day_room.dart' show classStatusAbove;
import '../../class_day/doorway_light.dart';
import '../house_backdrop.dart'
    show HouseRoomBackdrop, housePlateOverscan, housePlateParallax;
import '../house_room.dart';
import 'plans_actions.dart';
import 'plans_dates.dart';
import 'plans_day_view.dart';
import 'plans_geometry.dart';
import 'plans_glass.dart';
import 'plans_mode_switch.dart';
import 'plans_month_view.dart';
import 'plans_page_turn.dart';
import 'plans_week_view.dart';

class PlansRoom extends StatelessWidget {
  const PlansRoom({
    super.key,
    required this.mode,
    required this.selected,
    required this.month,
    required this.now,
    required this.schedule,
    required this.daybook,
    required this.termName,
    required this.zoneLabel,
    required this.loading,
    required this.actions,
    required this.completionsOn,
    required this.reflectionsOn,
    required this.journalOn,
    required this.classStatus,
    this.parallax,
    this.reduceMotion,
  });

  final AcademicCalendarMode mode;
  final DateTime selected;

  /// The month in view (the first of it).
  final DateTime month;
  final DateTime now;
  final AcademicSchedule schedule;

  /// The days the view needs: the month, or the week the chosen day is in, or
  /// the three days in view.
  final DaybookRange daybook;
  final String? termName;

  /// "LOCAL TIME" or "CAMPUS TIME".
  final String zoneLabel;
  final bool loading;
  final PlansActions actions;
  final int Function(DateTime day) completionsOn;
  final int Function(DateTime day) reflectionsOn;
  final List<Note> Function(DateTime day) journalOn;

  /// "NOW" / "IN 12 MIN" / "NEXT" for the class in session or coming, by
  /// occurrence key.
  final Map<String, ({String label, bool active})> classStatus;

  /// The shell's tilt; the plate and the glass on it move together.
  final ValueListenable<Offset>? parallax;
  final bool? reduceMotion;

  @override
  Widget build(BuildContext context) {
    // The painted book is registered to the plate, and a plate is drawn to
    // its width and hangs from the top. On a phone that is the whole screen.
    // On a screen wider than a phone (a tablet, a window) the plate would
    // grow until the book ran off the bottom, so the book keeps a phone's
    // proportions and stands in the middle, on the dark of the house.
    return LayoutBuilder(
      builder: (context, box) {
        final above = classStatusAbove(context);
        final height = box.maxHeight + above;
        final phone = height * houseCanvasWidth / houseCanvasHeight;
        // (Under 340 wide is a screen no current phone has: it keeps the full
        // width and scrolls what does not fit.)
        final wide = box.maxWidth >= 340 && box.maxWidth / height > 0.52;
        final width = wide ? phone : box.maxWidth;
        return ColoredBox(
          color: const Color(0xFF100D0B),
          child: Center(
            child: SizedBox(width: width, child: _room(context)),
          ),
        );
      },
    );
  }

  Widget _room(BuildContext context) {
    return HouseRoomBackdrop(
      room: HouseRoom.plans,
      plates: PlansPlates.forMode(mode),
      parallax: parallax,
      reduceMotion: reduceMotion,
      child: LayoutBuilder(
        builder: (context, box) {
          final above = classStatusAbove(context);
          final layout = PlansLayout.forWidth(box.maxWidth);
          final still = plansStill(context, reduceMotion);
          final lights = doorwayLightsAt(now);
          final evening = (lights.evening + lights.golden * 0.35).clamp(
            0.0,
            1.0,
          );
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: -above,
                height: box.maxHeight + above,
                child: _OnThePlate(
                  parallax: parallax,
                  still: still,
                  child: _Book(
                    layout: layout,
                    mode: mode,
                    selected: selected,
                    month: month,
                    now: now,
                    schedule: schedule,
                    daybook: daybook,
                    termName: termName,
                    zoneLabel: zoneLabel,
                    loading: loading,
                    actions: actions,
                    completionsOn: completionsOn,
                    reflectionsOn: reflectionsOn,
                    journalOn: journalOn,
                    classStatus: classStatus,
                    evening: evening,
                    still: still,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The live layer rides with the plate: the same overscan and tilt, so glass
/// stays on the paper it was laid on.
class _OnThePlate extends StatelessWidget {
  const _OnThePlate({
    required this.parallax,
    required this.still,
    required this.child,
  });

  final ValueListenable<Offset>? parallax;
  final bool still;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final listenable = parallax;
    if (still || listenable == null) {
      return Transform.scale(scale: housePlateOverscan, child: child);
    }
    return AnimatedBuilder(
      animation: listenable,
      child: child,
      builder: (context, child) {
        final tilt = listenable.value;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.translationValues(
            tilt.dx.clamp(-1.0, 1.0) * housePlateParallax,
            tilt.dy.clamp(-1.0, 1.0) * housePlateParallax,
            0,
          )..scaleByDouble(housePlateOverscan, housePlateOverscan, 1, 1),
          child: child,
        );
      },
    );
  }
}

class _Book extends StatefulWidget {
  const _Book({
    required this.layout,
    required this.mode,
    required this.selected,
    required this.month,
    required this.now,
    required this.schedule,
    required this.daybook,
    required this.termName,
    required this.zoneLabel,
    required this.loading,
    required this.actions,
    required this.completionsOn,
    required this.reflectionsOn,
    required this.journalOn,
    required this.classStatus,
    required this.evening,
    required this.still,
  });

  final PlansLayout layout;
  final AcademicCalendarMode mode;
  final DateTime selected;
  final DateTime month;
  final DateTime now;
  final AcademicSchedule schedule;
  final DaybookRange daybook;
  final String? termName;
  final String zoneLabel;
  final bool loading;
  final PlansActions actions;
  final int Function(DateTime day) completionsOn;
  final int Function(DateTime day) reflectionsOn;
  final List<Note> Function(DateTime day) journalOn;
  final Map<String, ({String label, bool active})> classStatus;
  final double evening;
  final bool still;

  @override
  State<_Book> createState() => _BookState();
}

class _BookState extends State<_Book> {
  double _drag = 0;

  PlansLayout get _l => widget.layout;
  CivilDate get _selectedCivil => CivilDate.fromDateTime(widget.selected);
  CivilDate get _today => CivilDate.fromDateTime(widget.now);

  /// Whether the book is already on today: the way back to today shows when
  /// it is not.
  bool get _todayVisible {
    if (widget.mode == AcademicCalendarMode.month) {
      return widget.month.year == widget.now.year &&
          widget.month.month == widget.now.month;
    }
    return _selectedCivil == _today;
  }

  void _turn(int direction) {
    Sfx.instance.playMaterial(MaterialSound.parchment);
    HapticFeedback.selectionClick();
    widget.actions.onMoveSpan(direction);
  }

  void _dragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final distance = _drag;
    _drag = 0;
    if (distance < -64 || velocity < -380) {
      _turn(1);
    } else if (distance > 64 || velocity > 380) {
      _turn(-1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final spoken = switch (mode) {
      AcademicCalendarMode.month => 'Daybook, month view',
      AcademicCalendarMode.week => 'Daybook, week view',
      AcademicCalendarMode.threeDay => 'Daybook, three day view',
      AcademicCalendarMode.day => 'Daybook, day view',
    };
    final next = switch (mode) {
      AcademicCalendarMode.month => 'Next month',
      AcademicCalendarMode.week => 'Next week',
      AcademicCalendarMode.threeDay => 'Next 3 days',
      AcademicCalendarMode.day => 'Next day',
    };
    final previous = switch (mode) {
      AcademicCalendarMode.month => 'Previous month',
      AcademicCalendarMode.week => 'Previous week',
      AcademicCalendarMode.threeDay => 'Previous 3 days',
      AcademicCalendarMode.day => 'Previous day',
    };
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: spoken,
      customSemanticsActions: {
        CustomSemanticsAction(label: next): () => widget.actions.onMoveSpan(1),
        CustomSemanticsAction(label: previous): () =>
            widget.actions.onMoveSpan(-1),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => _drag = 0,
        onHorizontalDragUpdate: (d) => _drag += d.delta.dx,
        onHorizontalDragEnd: _dragEnd,
        onHorizontalDragCancel: () => _drag = 0,
        child: SizedBox.expand(
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              PlansPageTurn(
                // One page per view: a change of view turns the whole book.
                turnKey: 'view-${mode.name}',
                animate: !widget.loading,
                order: plansViewOrder(mode),
                curl: _l.rect(PlansCanvas.curl),
                reduceMotion: widget.still,
                child: SizedBox.expand(
                  child: KeyedSubtree(
                    key: ValueKey('academic-${mode.name}-view'),
                    child: _spread(context),
                  ),
                ),
              ),
              Positioned(
                top: _l.x(PlansCanvas.modeSwitchTop),
                right: _l.x(PlansCanvas.modeSwitchRight),
                child: PlansModeSwitch(
                  mode: mode,
                  onChanged: widget.actions.onMode,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _spread(BuildContext context) {
    switch (widget.mode) {
      case AcademicCalendarMode.month:
        return _month();
      case AcademicCalendarMode.week:
        return _week();
      case AcademicCalendarMode.threeDay:
      case AcademicCalendarMode.day:
        return _day();
    }
  }

  // ── day ───────────────────────────────────────────────────────────────

  Widget _day() {
    final daybook = widget.daybook;
    final days = [
      for (
        var d = daybook.first;
        d.compareTo(daybook.last) <= 0;
        d = d.addDays(1)
      )
        d,
    ];
    final field = _l.rect(PlansCanvas.field);
    final dayDate = DateTime(
      _selectedCivil.year,
      _selectedCivil.month,
      _selectedCivil.day,
    );
    final isToday = _selectedCivil == _today;
    final dayData = daybook.dayOn(_selectedCivil);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(
          rect: _l.rect(PlansCanvas.tabs),
          child: PlansDayTabs(
            days: days,
            selected: _selectedCivil,
            today: _today,
            onSelect: (d) =>
                widget.actions.onSelectDay(DateTime(d.year, d.month, d.day)),
          ),
        ),
        _foot(),
        Positioned.fromRect(
          rect: field,
          child: PlansPageTurn(
            turnKey: 'day-$_selectedCivil',
            animate: !widget.loading,
            order:
                _selectedCivil.dateArithmeticValue.millisecondsSinceEpoch /
                Duration.millisecondsPerDay,
            reduceMotion: widget.still,
            curl: _l.rect(PlansCanvas.curl).shift(-field.topLeft),
            child: SizedBox.expand(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PlansPageHeading(
                    eyebrow:
                        '${plansWeekdayShort[dayDate.weekday - 1]} · '
                        '${plansMonthShort[dayDate.month - 1]} ${dayDate.day}',
                    title: isToday
                        ? 'Today'
                        : plansWeekdayLong[dayDate.weekday - 1],
                    spoken:
                        '${isToday ? 'Today' : plansWeekdayLong[dayDate.weekday - 1]}, '
                        '${plansDayShape(dayData.summary)}',
                    onAdd: widget.actions.onAdd,
                  ),
                  Expanded(
                    child: PlansDayPage(
                      day: dayData,
                      now: widget.now,
                      schedule: widget.schedule,
                      actions: widget.actions,
                      completions: widget.completionsOn(dayDate),
                      reflections: widget.reflectionsOn(dayDate),
                      journalEntries: widget.journalOn(dayDate),
                      classStatus: widget.classStatus,
                      loading: widget.loading,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── week ──────────────────────────────────────────────────────────────

  Widget _week() {
    final daybook = widget.daybook;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(
          rect: _l.rect(PlansCanvas.weekStrip),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PlansPageHeading(
                eyebrow: 'WEEK OF',
                title: plansWeekTitle(daybook.first, daybook.last),
                onAdd: widget.actions.onAdd,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: PlansWeekStrip(
                  daybook: daybook,
                  schedule: widget.schedule,
                  selected: _selectedCivil,
                  today: _today,
                  onOpenDay: (day) {
                    widget.actions.onSelectDay(day);
                    widget.actions.onMode(AcademicCalendarMode.day);
                  },
                ),
              ),
            ],
          ),
        ),
        _foot(),
      ],
    );
  }

  // ── month ─────────────────────────────────────────────────────────────

  Widget _month() {
    final month = widget.month;
    final daybook = widget.daybook;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final weeks = (firstWeekday - 1 + daysInMonth + 6) ~/ 7;
    final summary = PlansMonthSummary.from(
      daybook,
      firstWeekday: firstWeekday,
      weekCount: weeks,
    );
    final headingRect = Rect.fromLTRB(
      PlansCanvas.monthHeading.left,
      PlansCanvas.monthHeading.top - 24,
      PlansCanvas.monthHeading.right,
      PlansCanvas.monthHeading.bottom,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(
          rect: _l.rect(PlansCanvas.tabs),
          child: PlansMonthSummaryPage(summary: summary),
        ),
        _foot(),
        Positioned.fromRect(
          rect: _l.rect(headingRect),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(
                  (plansTextScale(context)).clamp(1.0, 1.15),
                ),
              ),
              child: PlansPageHeading(
                eyebrow: plansMonthLong[month.month - 1].toUpperCase(),
                title: '${month.year}',
                compact: true,
                onAdd: widget.actions.onAdd,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: PlansMonthGrid(
            layout: _l,
            month: month,
            selected: widget.selected,
            now: widget.now,
            daybook: daybook,
            evening: widget.evening,
            facts: (day) => (
              completions: widget.completionsOn(day),
              journalEntries: widget.journalOn(day).length,
              tightTransitions: widget.schedule
                  .transitionPressuresOn(CivilDate.fromDateTime(day))
                  .length,
            ),
            onSelect: (day) {
              widget.actions.onSelectDay(day);
              widget.actions.onMode(AcademicCalendarMode.day);
            },
          ),
        ),
      ],
    );
  }

  Widget _foot() => Positioned.fromRect(
    rect: _l.rect(PlansCanvas.leftFoot),
    child: PlansLeftFoot(
      arrows: _arrows(),
      termName: widget.termName,
      zoneLabel: widget.zoneLabel,
      loading: widget.loading,
      showToday: !_todayVisible,
      onToday: widget.actions.onToday,
    ),
  );

  Widget _arrows() {
    final mode = widget.mode;
    final unit = switch (mode) {
      AcademicCalendarMode.month => 'month',
      AcademicCalendarMode.week => 'week',
      AcademicCalendarMode.threeDay => '3 days',
      AcademicCalendarMode.day => 'day',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlansArrow(
          icon: Icons.chevron_left_rounded,
          label: 'Previous $unit',
          onTap: () => _turn(-1),
        ),
        PlansArrow(
          icon: Icons.chevron_right_rounded,
          label: 'Next $unit',
          onTap: () => _turn(1),
        ),
      ],
    );
  }
}
