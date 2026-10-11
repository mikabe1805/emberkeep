// The week: seven columns of glass across both pages of the spread, one for
// each day, with that day's plans as small tickets under its name. Today is
// marked in a dark plate; tapping a column opens that day.
//
// This stands on the day plate until the week's own plate is painted (see
// PlansPlates.week); its rectangle is PlansCanvas.weekStrip.
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

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(11) / 11;
    final days = [
      for (var i = 0; i < 7; i++) daybook.dayOn(daybook.first.addDays(i)),
    ];
    // Seven narrow columns are a glance, not a place to read: their words stop
    // growing early, and the day itself opens at the system's size.
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale.clamp(1.0, 1.15))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final day in days)
                Expanded(
                  child: _ColumnHead(
                    day: day,
                    selected: day.date == selected,
                    today: day.date == today,
                    onTap: () => _open(day.date),
                  ),
                ),
            ],
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0x42533E2D), width: 0.6),
              ),
            ),
            child: SizedBox(height: 0, width: double.infinity),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: 40),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final day in days)
                      Expanded(
                        child: _Column(
                          day: day,
                          schedule: schedule,
                          selected: day.date == selected,
                          onTap: () => _open(day.date),
                        ),
                      ),
                  ],
                ),
              ),
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

class _ColumnHead extends StatelessWidget {
  const _ColumnHead({
    required this.day,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final DaybookDay day;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateTime(day.date.year, day.date.month, day.date.day);
    final count = day.entries.where((e) => !e.cancelled).length;
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: today
                  ? const Color(0xCC2B1F18)
                  : selected
                  ? const Color(0x33BF9152)
                  : null,
              border: today
                  ? Border.all(color: const Color(0xCCE8AA5B), width: 0.9)
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    plansWeekdayShort[date.weekday - 1],
                    style: TextStyle(
                      fontFamily: PlansInk.serif,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1,
                      letterSpacing: 1.0,
                      color: today ? const Color(0xFFFFF3DE) : PlansInk.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontFamily: PlansInk.serif,
                      fontWeight: FontWeight.w500,
                      fontSize: 19,
                      height: 1,
                      color: today ? const Color(0xFFFFD79E) : PlansInk.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.day,
    required this.schedule,
    required this.selected,
    required this.onTap,
  });

  final DaybookDay day;
  final AcademicSchedule schedule;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? const Color(0x1ABF9152) : null,
            border: const Border(
              left: BorderSide(color: Color(0x26503D2E), width: 0.6),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in day.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _Ticket(entry: entry, schedule: schedule),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Ticket extends StatelessWidget {
  const _Ticket({required this.entry, required this.schedule});

  final DaybookEntry entry;
  final AcademicSchedule schedule;

  /// A class is named by its course number (the part after the last colon of
  /// a Rutgers code: 14:332:361 is 361), which is how a column this narrow can
  /// say it whole; everything else by its title.
  String get _name {
    if (entry.action is AcademicOccurrenceAction) {
      final occurrence = schedule.occurrenceByKey(
        (entry.action as AcademicOccurrenceAction).occurrenceKey,
      );
      final code = occurrence == null
          ? null
          : schedule.courseById(occurrence.courseId)?.code;
      if (code != null && code.contains(':')) return code.split(':').last;
      if (code != null) return code;
    }
    return entry.title;
  }

  @override
  Widget build(BuildContext context) {
    final dim = entry.completed || entry.cancelled;
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
      padding: const EdgeInsets.fromLTRB(4, 4, 3, 4),
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
          const SizedBox(height: 2),
          Text(
            _name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PlansInk.serif,
              fontWeight: FontWeight.w500,
              fontSize: 12.5,
              height: 1.08,
              color: dim ? PlansInk.creamDim : PlansInk.cream,
              decoration: dim ? TextDecoration.lineThrough : null,
              decorationColor: PlansInk.creamDim,
            ),
          ),
        ],
      ),
    );
  }

  /// "10:20", "2:00": the hour and minute, the day page says AM or PM.
  static String _short(int minute) {
    final hour = minute ~/ 60 % 12 == 0 ? 12 : minute ~/ 60 % 12;
    return '$hour:${(minute % 60).toString().padLeft(2, '0')}';
  }
}
