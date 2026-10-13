// The week: seven rows across both pages of the spread, one for each day,
// laid on the week plate's seven painted rows (PlansPlates.week). The left
// page names the day (and marks today); the right page holds that day's plans
// as small smoky-glass strips, side by side. Tapping a row opens that day.
//
// The paper's rows are painted; nothing here draws a row line. The rectangle
// is PlansCanvas.weekRows (the heading above it is PlansCanvas.weekHeading).
library;

import 'package:flutter/material.dart';

import '../../../academic_calendar/domain/academic_schedule.dart'
    show AcademicSchedule, CivilDate;
import '../../../audio.dart';
import '../../../daybook/presentation/daybook_range_projection.dart';
import '../../../tokens.dart';
import 'plans_dates.dart';
import 'plans_glass.dart';

/// "Oct 5 – 11", or "Sep 28 – Oct 4" across a month.
String plansWeekTitle(CivilDate first, CivilDate last) {
  String month(CivilDate d) => plansMonthLong[d.month - 1].substring(0, 3);
  return first.month == last.month
      ? '${month(first)} ${first.day}–${last.day}'
      : '${month(first)} ${first.day}–${month(last)} ${last.day}';
}

class PlansWeekStrip extends StatelessWidget {
  const PlansWeekStrip({
    super.key,
    required this.daybook,
    required this.schedule,
    required this.selected,
    required this.today,
    required this.onOpenDay,
  });

  final DaybookRange daybook;
  final AcademicSchedule schedule;
  final CivilDate selected;
  final CivilDate today;
  final ValueChanged<DateTime> onOpenDay;

  /// Where the strips start, as a fraction of the rows' width (the painted
  /// gutter holds the day's name), and the margin on the right.
  static const double gutterFraction = 0.358;
  static const double rightMargin = 7;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(11) / 11;
    final days = [
      for (var i = 0; i < 7; i++) daybook.dayOn(daybook.first.addDays(i)),
    ];
    // Seven rows of painted paper are a glance, not a place to read: the
    // words stop growing early (and shrink to the row past that), and the
    // day itself opens at the system's size.
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale.clamp(1.0, 1.15))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final day in days)
            Expanded(
              child: _Row(
                day: day,
                schedule: schedule,
                selected: day.date == selected,
                today: day.date == today,
                onTap: () => _open(day.date),
              ),
            ),
        ],
      ),
    );
  }

  void _open(CivilDate date) {
    Sfx.instance.playMaterial(MaterialSound.parchment);
    onOpenDay(DateTime(date.year, date.month, date.day));
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.day,
    required this.schedule,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final DaybookDay day;
  final AcademicSchedule schedule;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateTime(day.date.year, day.date.month, day.date.day);
    final entries = day.entries;
    final count = entries.where((e) => !e.cancelled).length;
    final spoken =
        '${plansSpokenDate(date, today: today)}, '
        '${count == 0 ? 'nothing held' : '$count ${count == 1 ? 'plan' : 'plans'}'}';
    return Semantics(
      key: ValueKey('daybook-day-control-${day.date}'),
      button: true,
      selected: selected,
      label: spoken,
      hint: 'Open this day',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, box) {
            final gutter = box.maxWidth * PlansWeekStrip.gutterFraction;
            final k = box.maxWidth / 367.7;
            final pad = box.maxHeight * 0.08;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Today is a warm catch on the page's edge, not a fill.
                if (today || selected)
                  Positioned(
                    left: 0,
                    top: pad,
                    bottom: pad,
                    width: gutter - 14 * k,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            today
                                ? const Color(0x4DE8AA5B)
                                : const Color(0x26BF9152),
                            const Color(0x00E8AA5B),
                          ],
                        ),
                        border: today
                            ? const Border(
                                left: BorderSide(
                                  color: Color(0xFFC98A3E),
                                  width: 2.5,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                Positioned(
                  left: 17 * k,
                  top: 0,
                  bottom: 0,
                  width: gutter - 22 * k,
                  child: _DayName(date: date, today: today),
                ),
                Positioned(
                  left: gutter,
                  right: PlansWeekStrip.rightMargin * k,
                  top: pad,
                  bottom: pad,
                  child: _Strips(entries: entries, schedule: schedule),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DayName extends StatelessWidget {
  const _DayName({required this.date, required this.today});

  final DateTime date;
  final bool today;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plansWeekdayShort[date.weekday - 1],
                style: const TextStyle(
                  fontFamily: PlansInk.serif,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  height: 1,
                  letterSpacing: 1.6,
                  color: PlansInk.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${plansMonthLong[date.month - 1].substring(0, 3).toUpperCase()} '
                '${date.day}',
                style: const TextStyle(
                  fontFamily: PlansInk.mono,
                  fontWeight: FontWeight.w600,
                  fontSize: Type.minLabel,
                  height: 1.1,
                  letterSpacing: 1.2,
                  color: PlansInk.muted,
                ),
              ),
            ],
          ),
          if (today) ...[
            const SizedBox(width: 16),
            const Text(
              'TODAY',
              style: TextStyle(
                fontFamily: PlansInk.mono,
                fontWeight: FontWeight.w600,
                fontSize: Type.minLabel,
                height: 1,
                letterSpacing: 1.2,
                color: PlansInk.brass,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A day's plans side by side: up to three as strips. A fuller day folds to a
/// two-by-two of one-line chips, and past four the last chip says how many more.
class _Strips extends StatelessWidget {
  const _Strips({required this.entries, required this.schedule});

  final List<DaybookEntry> entries;
  final AcademicSchedule schedule;

  static const int _strips = 3;
  static const int _chips = 4;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    if (entries.length > _strips) return _dense();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: _Strip(
              entry: entries[i],
              schedule: schedule,
              narrow: entries.length > 2,
            ),
          ),
        ],
      ],
    );
  }

  Widget _dense() {
    final shown = entries.length <= _chips
        ? entries
        : entries.take(_chips - 1).toList();
    final more = entries.length <= _chips ? 0 : entries.length - (_chips - 1);
    final cells = <Widget>[
      for (final e in shown) _Chip(entry: e, schedule: schedule),
      if (more > 0) _MoreStrip(more: more),
    ];
    Widget row(int from) => Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: from < cells.length ? cells[from] : const SizedBox()),
          const SizedBox(width: 4),
          Expanded(
            child: from + 1 < cells.length ? cells[from + 1] : const SizedBox(),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [row(0), const SizedBox(height: 3), row(2)],
    );
  }
}

/// One plan as a single line: its name (the day page holds its time).
class _Chip extends StatelessWidget {
  const _Chip({required this.entry, required this.schedule});

  final DaybookEntry entry;
  final AcademicSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final dim = entry.completed || entry.completedNow || entry.cancelled;
    return PlansGlass(
      radius: 5,
      shadow: false,
      soft: dim,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _nameOf(entry, schedule),
              maxLines: 1,
              style: TextStyle(
                fontFamily: PlansInk.serif,
                fontWeight: FontWeight.w500,
                fontSize: 12,
                height: 1,
                color: dim ? PlansInk.creamDim : PlansInk.cream,
                decoration: dim ? TextDecoration.lineThrough : null,
                decorationColor: PlansInk.creamDim,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What a plan is called: a class by its course's name (the entry carries
/// the code), everything else by its title.
String _nameOf(DaybookEntry entry, AcademicSchedule schedule) {
  final action = entry.action;
  if (action is AcademicOccurrenceAction) {
    final occurrence = schedule.occurrenceByKey(action.occurrenceKey);
    final course = occurrence == null
        ? null
        : schedule.courseById(occurrence.courseId);
    if (course != null) return course.title;
  }
  return entry.title;
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.entry,
    required this.schedule,
    this.narrow = false,
  });

  final DaybookEntry entry;
  final AcademicSchedule schedule;

  /// Three side by side: the name's size gives a little so a word is not cut.
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final dim = entry.completed || entry.completedNow || entry.cancelled;
    final timed = entry.section == DaybookSection.timed;
    final time = timed
        ? _short(entry.startMinute!)
        : switch (entry.section) {
            DaybookSection.allDay => 'ALL DAY',
            DaybookSection.focus => 'FOCUS',
            _ => 'DUE',
          };
    return PlansGlass(
      radius: 6,
      shadow: false,
      soft: dim,
      child: LayoutBuilder(
        builder: (context, box) {
          final width = (box.maxWidth - 10).clamp(20.0, 400.0);
          final name = _nameOf(entry, schedule);
          final size = _sizeForLongestWord(
            context,
            name,
            narrow ? 11.5 : 12.5,
            width,
          );
          return Padding(
            padding: const EdgeInsets.fromLTRB(6, 3, 4, 3),
            // The strip is as tall as the paper's row allows: past what fits
            // at the system's size the words shrink with it, never overflow.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontFamily: PlansInk.mono,
                        fontWeight: FontWeight.w600,
                        fontSize: Type.minLabel,
                        height: 1.1,
                        letterSpacing: 0,
                        color: dim ? PlansInk.creamDim : PlansInk.ringDone,
                      ),
                    ),
                    // Two lines at most, ending in an ellipsis; a long name
                    // never breaks in the middle of a word (see below).
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: PlansInk.serif,
                        fontWeight: FontWeight.w500,
                        fontSize: size,
                        height: 1.06,
                        color: dim ? PlansInk.creamDim : PlansInk.cream,
                        decoration: dim ? TextDecoration.lineThrough : null,
                        decorationColor: PlansInk.creamDim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// The name's size: [base], or smaller (never below 72% of it) when its
  /// longest word would not fit the strip, so "Introduction" is set small
  /// rather than broken into "Introducti / on" at large text.
  static double _sizeForLongestWord(
    BuildContext context,
    String name,
    double base,
    double width,
  ) {
    final inherited = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    var longest = 0.0;
    for (final word in name.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(
          text: word,
          style: inherited.merge(
            TextStyle(
              fontFamily: PlansInk.serif,
              fontWeight: FontWeight.w500,
              fontSize: base,
            ),
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      if (painter.width > longest) longest = painter.width;
      painter.dispose();
    }
    if (longest <= width || longest == 0) return base;
    return (base * width / longest * 0.97).clamp(base * 0.72, base);
  }

  /// "10:20", "2:00": the hour and minute, the day page says AM or PM.
  static String _short(int minute) {
    final hour = minute ~/ 60 % 12 == 0 ? 12 : minute ~/ 60 % 12;
    return '$hour:${(minute % 60).toString().padLeft(2, '0')}';
  }
}

class _MoreStrip extends StatelessWidget {
  const _MoreStrip({required this.more});

  final int more;

  @override
  Widget build(BuildContext context) => PlansGlass(
    radius: 6,
    shadow: false,
    soft: true,
    child: Center(
      child: Text(
        '+$more',
        style: const TextStyle(
          fontFamily: PlansInk.mono,
          fontWeight: FontWeight.w600,
          fontSize: Type.minLabel,
          color: PlansInk.creamSoft,
        ),
      ),
    ),
  );
}
