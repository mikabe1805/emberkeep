// The month: a flat glass month grid laid exactly onto the month plate's faint
// printed grid, today marked in a dark plate with a gold edge, and a few brass
// marks for how full a day is and what is due.
//
// The cells are registered to the plate's own lines (PlansCanvas.monthRows and
// monthColumns, measured from the plate), so the printed grid and the live one
// are one grid. The plate's grid has a weekday row and five date rows; a month
// that spans six weeks spreads its six rows over the same five.
library;

import 'package:flutter/material.dart';

import '../../../daybook/presentation/daybook_range_projection.dart';
import '../../../models.dart' show Days;
import '../../../tokens.dart';
import '../../../audio.dart';
import '../../../academic_calendar/domain/academic_schedule.dart'
    show CivilDate;
import 'plans_dates.dart';
import 'plans_geometry.dart';
import 'plans_glass.dart';

/// What a month cell needs besides the day's own summary.
typedef PlansMonthDayFacts = ({
  int completions,
  int journalEntries,
  int tightTransitions,
});

/// The month's numbers, for the left page.
final class PlansMonthSummary {
  const PlansMonthSummary({
    required this.tasks,
    required this.events,
    required this.classes,
    required this.weekPlans,
  });

  factory PlansMonthSummary.from(
    DaybookRange daybook, {
    required int firstWeekday,
    required int weekCount,
  }) {
    final tasks = <String>{};
    final events = <String>{};
    final classes = <String>{};
    final weekly = List.generate(weekCount, (_) => <String>{});
    for (final day in daybook.days.values) {
      final week = (firstWeekday - 1 + day.date.day - 1) ~/ 7;
      for (final entry in day.entries) {
        if (entry.cancelled) continue;
        switch (entry.sourceKind) {
          case DaybookSourceKind.task:
            tasks.add(entry.displayKey);
            weekly[week].add('task:${entry.displayKey}');
          case DaybookSourceKind.event:
            events.add(entry.displayKey);
            weekly[week].add('event:${entry.displayKey}');
          case DaybookSourceKind.classOccurrence:
            classes.add(entry.displayKey);
            weekly[week].add('class:${entry.displayKey}');
          case DaybookSourceKind.academicWork:
          case DaybookSourceKind.studyBlock:
          case DaybookSourceKind.questPlan:
            break;
        }
      }
    }
    return PlansMonthSummary(
      tasks: tasks.length,
      events: events.length,
      classes: classes.length,
      weekPlans: [for (final w in weekly) w.length],
    );
  }

  final int tasks;
  final int events;
  final int classes;
  final List<int> weekPlans;
}

/// The month's spoken label for a day.
String plansMonthDayLabel(
  DateTime date,
  DaybookDaySummary summary, {
  required bool isToday,
}) {
  final facts = <String>[
    '${plansMonthLong[date.month - 1]} ${date.day}, ${date.year}',
    if (isToday) 'today',
    summary.scheduledMinutes == 0
        ? 'no timed plans'
        : '${summary.scheduledMinutes} scheduled minutes',
  ];
  if (summary.fixedPlanCount == 0) {
    facts.add('no fixed plans');
  } else if (summary.scheduledMinutes == 0) {
    facts.add(
      '${summary.fixedPlanCount} all-day plan${summary.fixedPlanCount == 1 ? '' : 's'}',
    );
  } else {
    facts.add(
      '${summary.fixedPlanCount} fixed plan${summary.fixedPlanCount == 1 ? '' : 's'}',
    );
  }
  facts.add(
    summary.deadlineCount == 0
        ? 'no active deadlines'
        : '${summary.deadlineCount} active deadline${summary.deadlineCount == 1 ? '' : 's'}',
  );
  facts.add(
    summary.focusCount == 0
        ? 'no active focus choices'
        : '${summary.focusCount} active focus choice${summary.focusCount == 1 ? '' : 's'}',
  );
  return facts.join(', ');
}

/// The cells of one month, as canvas rectangles: [column] 0 to 6, [row] 0 to
/// [weeks] - 1. Five weeks stand on the plate's five date rows; six weeks
/// spread over the same height.
Rect plansMonthCell(PlansLayout layout, int column, int row, int weeks) {
  final left = PlansCanvas.monthColumns[column];
  final right = PlansCanvas.monthColumns[column + 1];
  final top0 = PlansCanvas.monthRows[1];
  final bottom0 = PlansCanvas.monthRows[6];
  final pitch = (bottom0 - top0) / weeks;
  return layout.rect(
    Rect.fromLTRB(left, top0 + row * pitch, right, top0 + (row + 1) * pitch),
  );
}

class PlansMonthGrid extends StatelessWidget {
  const PlansMonthGrid({
    super.key,
    required this.layout,
    required this.month,
    required this.selected,
    required this.now,
    required this.daybook,
    required this.facts,
    required this.onSelect,
    required this.evening,
  });

  final PlansLayout layout;
  final DateTime month;
  final DateTime selected;
  final DateTime now;
  final DaybookRange daybook;
  final PlansMonthDayFacts Function(DateTime day) facts;
  final ValueChanged<DateTime> onSelect;

  /// How lamplit the paper is (0 midday, 1 evening): the printed grid is only
  /// on the midday plate, so the live lines carry it at night.
  final double evening;

  @override
  Widget build(BuildContext context) {
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final weeks = (firstWeekday - 1 + daysInMonth + 6) ~/ 7;
    final lineAlpha = 0.10 + evening * 0.22;
    final line = Color.fromRGBO(80, 61, 46, lineAlpha);
    final cells = <Widget>[];

    // The weekday row.
    for (var c = 0; c < 7; c++) {
      final r = layout.rect(
        Rect.fromLTRB(
          PlansCanvas.monthColumns[c],
          PlansCanvas.monthRows[0],
          PlansCanvas.monthColumns[c + 1],
          PlansCanvas.monthRows[1],
        ),
      );
      cells.add(
        Positioned.fromRect(
          rect: r,
          child: Center(
            child: Text(
              plansWeekdayLetters[c],
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: PlansInk.mono,
                fontWeight: FontWeight.w600,
                fontSize: Type.minLabel,
                letterSpacing: 1.0,
                color: c >= 5 ? PlansInk.brass : PlansInk.muted,
              ),
            ),
          ),
        ),
      );
    }

    // The days, with the month before and after dimmed.
    for (var row = 0; row < weeks; row++) {
      for (var column = 0; column < 7; column++) {
        final index = row * 7 + column;
        final day = index - (firstWeekday - 1) + 1;
        final date = DateTime(month.year, month.month, day);
        final inMonth = day >= 1 && day <= daysInMonth;
        final rect = plansMonthCell(layout, column, row, weeks);
        cells.add(
          Positioned.fromRect(
            rect: rect,
            child: inMonth
                ? _Cell(
                    date: date,
                    now: now,
                    selected: selected,
                    summary: daybook
                        .dayOn(CivilDate.fromDateTime(date))
                        .summary,
                    facts: facts(date),
                    onSelect: onSelect,
                  )
                : _OutsideCell(day: date.day),
          ),
        );
      }
    }

    // Live lines on the same lines the plate prints (they carry the grid when
    // the plate has none, at evening, and when a month needs six rows).
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _GridLines(layout: layout, weeks: weeks, color: line),
            ),
          ),
        ),
        ...cells,
      ],
    );
  }
}

class _GridLines extends CustomPainter {
  const _GridLines({
    required this.layout,
    required this.weeks,
    required this.color,
  });

  final PlansLayout layout;
  final int weeks;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.6;
    final s = layout.scale;
    final cols = PlansCanvas.monthColumns;
    final top = PlansCanvas.monthRows[0] * s;
    final bottom = PlansCanvas.monthRows[6] * s;
    for (final x in cols) {
      canvas.drawLine(Offset(x * s, top), Offset(x * s, bottom), paint);
    }
    final dateTop = PlansCanvas.monthRows[1];
    final pitch = (PlansCanvas.monthRows[6] - dateTop) / weeks;
    final ys = <double>[
      PlansCanvas.monthRows[0],
      dateTop,
      for (var r = 1; r <= weeks; r++) dateTop + r * pitch,
    ];
    for (final y in ys) {
      canvas.drawLine(
        Offset(cols.first * s, y * s),
        Offset(cols.last * s, y * s),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GridLines old) =>
      old.layout.scale != layout.scale ||
      old.weeks != weeks ||
      old.color != color;
}

class _OutsideCell extends StatelessWidget {
  const _OutsideCell({required this.day});

  final int day;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(4, 5, 2, 2),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          '$day',
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            fontFamily: PlansInk.mono,
            fontWeight: FontWeight.w500,
            fontSize: 12,
            height: 1,
            color: Color(0x5C55473B),
          ),
        ),
      ),
    ),
  );
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.date,
    required this.now,
    required this.selected,
    required this.summary,
    required this.facts,
    required this.onSelect,
  });

  final DateTime date;
  final DateTime now;
  final DateTime selected;
  final DaybookDaySummary summary;
  final PlansMonthDayFacts facts;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final isToday = Days.sameDay(date, now);
    final isSelected = Days.sameDay(date, selected);
    final keyDate = CivilDate.fromDateTime(date).toString();
    final spoken = StringBuffer(
      plansMonthDayLabel(date, summary, isToday: isToday),
    );
    if (facts.completions > 0) {
      spoken.write(
        ', ${facts.completions} quest${facts.completions == 1 ? '' : 's'} completed',
      );
    }
    if (facts.tightTransitions > 0) {
      spoken.write(
        ', ${facts.tightTransitions} tight class transition${facts.tightTransitions == 1 ? '' : 's'}',
      );
    }
    if (facts.journalEntries > 0) {
      spoken.write(
        ', ${facts.journalEntries} journal entr${facts.journalEntries == 1 ? 'y' : 'ies'}',
      );
    }
    final dots = switch (summary.weight) {
      DaybookDayWeight.none => 0,
      DaybookDayWeight.light => 1,
      DaybookDayWeight.moderate => 2,
      DaybookDayWeight.full => 3,
    };
    final markColor = isToday ? const Color(0xFFFFD79E) : PlansInk.brass;
    final showWeight =
        summary.weight != DaybookDayWeight.none || summary.hasDeadline;
    final marks = (dots == 0 && !summary.hasDeadline && summary.focusCount == 0)
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showWeight)
                KeyedSubtree(
                  key: ValueKey('academic-month-weight-$keyDate'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < dots; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 2.5),
                          child: _Dot(color: markColor),
                        ),
                      if (summary.hasDeadline)
                        _Diamond(
                          key: ValueKey('academic-month-deadline-$keyDate'),
                          color: markColor,
                        ),
                    ],
                  ),
                ),
              if (summary.focusCount > 0)
                Padding(
                  padding: EdgeInsets.only(left: showWeight ? 3 : 0),
                  child: _FocusRing(
                    key: ValueKey('academic-month-focus-$keyDate'),
                    color: markColor,
                  ),
                ),
            ],
          );

    final body = Stack(
      children: [
        if (isToday)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(1),
              child: DecoratedBox(
                key: ValueKey('month-today-marker-$keyDate'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: const Color(0xCC2B1F18),
                  border: Border.all(
                    color: const Color(0xCCE8AA5B),
                    width: 0.9,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33311D0D),
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (isSelected)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(1),
              child: DecoratedBox(
                key: ValueKey('month-selected-wash-$keyDate'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: const Color(0x33BF9152),
                ),
              ),
            ),
          ),
        // A Stack, not a Column: the cell is a fixed place on the paper, and
        // a narrow phone or a six-week month never overflows it.
        Positioned(
          left: 4,
          top: 5,
          child: Text(
            '${date.day}',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: PlansInk.mono,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
              height: 1,
              color: isToday
                  ? const Color(0xFFFFF3DE)
                  : const Color(0xFF55473B),
            ),
          ),
        ),
        if (isToday)
          Positioned(
            left: 3,
            right: 1,
            top: 17.5,
            child: Text(
              'TODAY',
              key: ValueKey('month-today-clip-$keyDate'),
              maxLines: 1,
              overflow: TextOverflow.clip,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: PlansInk.mono,
                fontWeight: FontWeight.w700,
                fontSize: 7,
                height: 1,
                letterSpacing: 0.4,
                color: markColor,
              ),
            ),
          ),
        if (marks != null) Positioned(left: 4, bottom: 4, child: marks),
      ],
    );

    return Semantics(
      button: true,
      selected: isSelected,
      label: spoken.toString(),
      hint: 'Open this day',
      excludeSemantics: true,
      onTap: () => onSelect(date),
      child: GestureDetector(
        key: ValueKey('academic-month-day-$keyDate'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Sfx.instance.playMaterial(MaterialSound.parchment);
          onSelect(date);
        },
        child: body,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 3.6,
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.85),
      ),
    ),
  );
}

class _Diamond extends StatelessWidget {
  const _Diamond({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: 0.7853981633974483,
    child: SizedBox.square(
      dimension: 4.2,
      child: DecoratedBox(decoration: BoxDecoration(color: color)),
    ),
  );
}

class _FocusRing extends StatelessWidget {
  const _FocusRing({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 5,
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 0.9),
      ),
    ),
  );
}

/// The month's numbers, in ink on the left page.
class PlansMonthSummaryPage extends StatelessWidget {
  const PlansMonthSummaryPage({super.key, required this.summary});

  final PlansMonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final activeWeeks = summary.weekPlans.where((c) => c > 0).length;
    Widget metric(Key key, int value, String one, String many) {
      final label = value == 1 ? one : many;
      return Semantics(
        label: '$value ${label.toLowerCase()} this month',
        excludeSemantics: true,
        child: Padding(
          key: key,
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontFamily: PlansInk.serif,
                  fontWeight: FontWeight.w500,
                  fontSize: 26,
                  height: 1,
                  color: PlansInk.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: PlansInk.mono,
                  fontWeight: FontWeight.w600,
                  fontSize: Type.minLabel,
                  letterSpacing: 1.4,
                  color: PlansInk.muted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // The left page is a narrow margin: its words stop growing at 130%.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(plansTextScale(context).clamp(1.0, 1.3)),
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              key: const ValueKey('month-summary-rail'),
              padding: const EdgeInsets.fromLTRB(22, 4, 8, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Text(
                      'THIS MONTH',
                      style: TextStyle(
                        fontFamily: PlansInk.mono,
                        fontWeight: FontWeight.w600,
                        fontSize: Type.minLabel,
                        letterSpacing: 1.9,
                        color: PlansInk.muted,
                      ),
                    ),
                  ),
                  metric(
                    const ValueKey('month-summary-classes'),
                    summary.classes,
                    'CLASS',
                    'CLASSES',
                  ),
                  metric(
                    const ValueKey('month-summary-events'),
                    summary.events,
                    'EVENT',
                    'EVENTS',
                  ),
                  metric(
                    const ValueKey('month-summary-tasks'),
                    summary.tasks,
                    'TASK',
                    'TASKS',
                  ),
                  const SizedBox(height: 6),
                  Semantics(
                    key: const ValueKey('month-summary-rhythm'),
                    label:
                        '$activeWeeks of ${summary.weekPlans.length} calendar weeks contain plans this month',
                    excludeSemantics: true,
                    child: Row(
                      children: [
                        for (var i = 0; i < summary.weekPlans.length; i++) ...[
                          if (i > 0)
                            Expanded(
                              child: Container(
                                height: 0.75,
                                color: const Color(0x5976685B),
                              ),
                            ),
                          _WeekDot(on: summary.weekPlans[i] > 0),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDot extends StatelessWidget {
  const _WeekDot({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: on ? PlansInk.brass : Colors.transparent,
      border: Border.all(
        color: on ? PlansInk.brass : const Color(0x8076685B),
        width: 0.9,
      ),
    ),
  );
}
